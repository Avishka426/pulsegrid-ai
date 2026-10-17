# The five PulseGrid agents and the coordinator loop.
#
# Monitoring and Impact are walkers that traverse the infrastructure graph.
# Planner and Verifier work on RecoveryOption objs, so they are plain functions
# (see agents/DESIGN.md, Q1). The coordinator sequences them, bounds re-planning
# at MAX_ITERATIONS and records every step with the evidence it produced.

import from services.models { Infrastructure, PowerLink, Incident, RecoveryOption, RecoveryPlan, STATUS_FAULT, STATUS_DE_ENERGIZED }
import from services.scenarios { apply_scenario, find_scenario }
import from services.incidents { build_incident, open_incident }
import from agents.contracts {
    AgentEvidence, RejectionNote, ImpactAssessment, AgentStep, AgentRun,
    AGENT_MONITORING, AGENT_IMPACT, AGENT_PLANNER, AGENT_VERIFIER, AGENT_COORDINATOR,
    STEP_OK, STEP_REJECTED, STEP_ERROR, RUN_COMPLETED, RUN_FAILED, RUN_NOT_CONFIGURED,
    MODE_LLM, MODE_NOT_CONFIGURED
}
import from agents.tools {
    get_asset, list_scenarios, trace_downstream_ids, impact_totals, incident_evidence,
    plan_recovery, check_option, is_isolation, path_links, donor_of
}
import from agents.llm {
    narrate_impact, choose_option, write_recommendation, validate_text, inline_citations,
    numbers_in, is_configured, model_name
}

glob MAX_ITERATIONS: int = 3;
glob LOAD_WARN_RATIO: float = 0.8;
glob LLM_RETRIES: int = 1;

# Mutable state shared by the agents during one run.
obj RunContext {
    has run_id: str;
    has scenario_id: str;
    has incident_id: str = "";
    has evidence: list[AgentEvidence] = [];
    has facts: list[float] = [];
    has steps: list[AgentStep] = [];

    def add_evidence(source_tool: str, label: str, asset_ids: list[str], value: float, unit: str, ref_id: str = "") -> AgentEvidence {
        ev = AgentEvidence(id=f"AE-{len(self.evidence) + 1:02d}", source_tool=source_tool, label=label, asset_ids=asset_ids, value=value, unit=unit, ref_id=ref_id);
        self.evidence.append(ev);
        self.add_fact(value);
        return ev;
    }

    def add_fact(value: float) -> None {
        if value not in self.facts { self.facts.append(value); }
    }

    def add_step(agent: str, action: str, tool: str, input_summary: str, output_summary: str, evidence_ids: list[str], status: str) -> AgentStep {
        step = AgentStep(index=len(self.steps), agent=agent, action=action, tool=tool, input_summary=input_summary, output_summary=output_summary, evidence_ids=evidence_ids, status=status);
        self.steps.append(step);
        return step;
    }
}

# Monitoring Agent: walks every asset reachable from a power source and records
# the active fault, de-energized assets and assets at or above the load warning ratio.
walker MonitoringScan {
    has warn_ratio: float = 0.8;
    has seen: list[str] = [];
    has faults: list[Infrastructure] = [];
    has de_energized: list[Infrastructure] = [];
    has high_load: list[Infrastructure] = [];

    can scan with Infrastructure entry {
        if here.identifier in self.seen { skip; }
        self.seen.append(here.identifier);
        if here.operational_status == STATUS_FAULT { self.faults.append(here); }
        if here.operational_status == STATUS_DE_ENERGIZED { self.de_energized.append(here); }
        if here.capacity_mw > 0.0 and here.load_mw / here.capacity_mw >= self.warn_ratio { self.high_load.append(here); }
        visit [here ->:PowerLink:->];
    }
}

# Impact Investigator: walks the faulted asset's downstream subgraph so the
# trace tool and the incident evidence can be cross-checked against an
# independent traversal.
walker DownstreamWalk {
    has visited: list[str] = [];

    can step with Infrastructure entry {
        if here.identifier in self.visited { skip; }
        self.visited.append(here.identifier);
        visit [here ->:PowerLink:->];
    }
}

def _key(n: Infrastructure) -> str { return n.identifier; }

def _ids(items: list[Infrastructure]) -> list[str] {
    return [n.identifier for n in sorted(items, key=_key)];
}

def _merge(a: list[str], b: list[str]) -> list[str] {
    out = list(a);
    for x in b { if x not in out { out.append(x); } }
    return out;
}

# Returns the single faulted asset the scan found, or None (recorded as an error step).
def run_monitoring(ctx: RunContext, assets: list[Infrastructure]) -> Infrastructure | None {
    sources = [n for n in assets if len([n <-:PowerLink:<-]) == 0];
    scan = MonitoringScan(warn_ratio=LOAD_WARN_RATIO);
    for src in sorted(sources, key=_key) { src spawn scan; }
    ev_ids: list[str] = [];
    for n in sorted(scan.faults, key=_key) {
        ev_ids.append(ctx.add_evidence("MonitoringScan", f"{n.identifier} {n.display_name} is in fault state; modeled load {n.load_mw:g} MW", [n.identifier], n.load_mw, "MW").id);
    }
    for n in sorted(scan.high_load, key=_key) {
        pct = round(n.load_mw / n.capacity_mw * 100.0, 1);
        ev_ids.append(ctx.add_evidence("MonitoringScan", f"{n.identifier} {n.display_name} load is {pct:g}% of capacity", [n.identifier], pct, "%").id);
    }
    if len(scan.de_energized) > 0 {
        ev_ids.append(ctx.add_evidence("MonitoringScan", f"{len(scan.de_energized)} assets de-energized: {', '.join(_ids(scan.de_energized))}", _ids(scan.de_energized), float(len(scan.de_energized)), "assets").id);
    }
    ctx.add_fact(float(len(scan.seen)));
    summary = f"Scanned {len(scan.seen)} assets: {len(scan.faults)} faulted, {len(scan.de_energized)} de-energized, {len(scan.high_load)} at or above {LOAD_WARN_RATIO * 100:.0f}% load";
    if len(scan.faults) != 1 {
        ctx.add_step(AGENT_MONITORING, "Scan network state", "MonitoringScan", "walk from power sources", summary + " (expected exactly one fault)", ev_ids, STEP_ERROR);
        return None;
    }
    ctx.add_step(AGENT_MONITORING, "Scan network state", "MonitoringScan", "walk from power sources", summary, ev_ids, STEP_OK);
    return scan.faults[0];
}

# Deterministic part of the Impact Investigator: incident evidence, trace tool
# and an independent walk must all agree on the downstream assets.
def assess_impact(ctx: RunContext, assets: list[Infrastructure], incident: Incident) -> ImpactAssessment | None {
    downstream = trace_downstream_ids(assets, incident.fault_id);
    fault = get_asset(assets, incident.fault_id);
    if fault is None { return None; }
    walk = fault spawn DownstreamWalk();
    walked = sorted([i for i in walk.visited if i != incident.fault_id]);
    traced = sorted([d.identifier for d in downstream]);
    records = incident_evidence(incident);
    recorded = sorted([r.asset_id for r in records if r.asset_id != incident.fault_id]);
    ev_ids: list[str] = [];
    for r in records {
        ev_ids.append(ctx.add_evidence("incident_evidence", r.detail, [r.asset_id], r.value_mw, "MW", r.identifier).id);
        ctx.add_fact(float(r.hops));
    }
    for d in downstream { ctx.add_fact(float(d.criticality)); }
    totals = impact_totals(assets);
    interrupted = [d.identifier for d in downstream if not d.alternate_feed];
    alternate = [d.identifier for d in downstream if d.alternate_feed];
    ev_ids.append(ctx.add_evidence("trace_downstream_ids", f"{len(downstream)} assets downstream of {incident.fault_id}", traced, float(len(downstream)), "assets").id);
    ev_ids.append(ctx.add_evidence("impact_totals", f"Interrupted end-use load {totals.interrupted_load_mw:g} MW", interrupted, totals.interrupted_load_mw, "MW").id);
    ev_ids.append(ctx.add_evidence("impact_totals", f"{totals.critical_interrupted} priority asset(s) without supply", interrupted, float(totals.critical_interrupted), "assets").id);
    ctx.add_fact(float(len(interrupted)));
    ctx.add_fact(float(len(alternate)));
    agrees = walked == traced and recorded == traced;
    ctx.add_step(AGENT_IMPACT, "Trace downstream assets", "trace_downstream_ids", incident.fault_id,
        f"{len(downstream)} downstream, {len(interrupted)} without supply path, {totals.interrupted_load_mw:g} MW interrupted; walk and incident evidence {'agree' if agrees else 'DISAGREE'}",
        ev_ids, STEP_OK if agrees else STEP_ERROR);
    if not agrees { return None; }
    return ImpactAssessment(incident_id=incident.identifier, downstream_count=len(downstream), interrupted_load_mw=totals.interrupted_load_mw, critical_interrupted=totals.critical_interrupted, interrupted_asset_ids=interrupted, alternate_feed_ids=alternate, evidence_ids=ev_ids);
}

def run_impact(ctx: RunContext, assets: list[Infrastructure], incident: Incident) -> ImpactAssessment | None {
    assessment = assess_impact(ctx, assets, incident);
    if assessment is None { return None; }
    for attempt in range(LLM_RETRIES + 1) {
        narrative = narrate_impact(incident, assessment, ctx.evidence);
        texts = [narrative.summary] + narrative.key_points;
        cited = _merge(narrative.cited_evidence_ids, inline_citations(" ".join(texts)));
        problems = validate_text(texts, cited, ctx.evidence, ctx.facts);
        if len(problems) == 0 {
            ctx.add_step(AGENT_IMPACT, "Narrate impact", "llm:narrate_impact", f"{len(ctx.evidence)} evidence items", narrative.summary, cited, STEP_OK);
            return assessment;
        }
        ctx.add_step(AGENT_IMPACT, "Narrate impact", "llm:narrate_impact", f"attempt {attempt + 1}", "Rejected: " + "; ".join(problems), cited, STEP_REJECTED);
    }
    ctx.add_step(AGENT_IMPACT, "Narrate impact", "llm:narrate_impact", "", "No valid narrative after retries", [], STEP_ERROR);
    return None;
}

def option_label(o: RecoveryOption) -> str {
    if is_isolation(o) { return f"{o.identifier}: {o.actions[0].description}"; }
    return f"{o.identifier}: restore {', '.join(o.restored_assets)} ({o.restored_load_mw:g} MW, {o.critical_restored} priority) from {donor_of(o)} over {', '.join(path_links(o))}";
}

def run_planning(ctx: RunContext, assets: list[Infrastructure], incident: Incident) -> RecoveryPlan {
    plan = plan_recovery(assets, incident);
    ev_ids: list[str] = [];
    for o in plan.options {
        ev_ids.append(ctx.add_evidence("plan_recovery", option_label(o), o.restored_assets, o.restored_load_mw, "MW").id);
        ctx.add_fact(float(o.critical_restored));
    }
    ctx.add_step(AGENT_PLANNER, "Generate candidate options", "plan_recovery", incident.fault_id, f"{len(plan.options)} deterministic options: {', '.join([o.identifier for o in plan.options])}", ev_ids, STEP_OK);
    return plan;
}

def _find_option(plan: RecoveryPlan, option_id: str) -> RecoveryOption | None {
    for o in plan.options { if o.identifier == option_id { return o; } }
    return None;
}

def choose(ctx: RunContext, assessment: ImpactAssessment, plan: RecoveryPlan, rejected: list[RejectionNote]) -> RecoveryOption | RejectionNote {
    choice = choose_option(assessment, plan.options, rejected, ctx.evidence);
    cited = _merge(choice.cited_evidence_ids, inline_citations(choice.rationale));
    problems = validate_text([choice.rationale], cited, ctx.evidence, ctx.facts);
    option = _find_option(plan, choice.option_id);
    if option is None { problems.append(f"{choice.option_id} is not one of the provided options"); }
    if choice.option_id in [r.option_id for r in rejected] { problems.append(f"{choice.option_id} was already rejected"); }
    if len(problems) > 0 or option is None {
        ctx.add_step(AGENT_PLANNER, "Choose option", "llm:choose_option", f"{len(plan.options)} options, {len(rejected)} rejected", f"Rejected choice {choice.option_id}: " + "; ".join(problems), cited, STEP_REJECTED);
        return RejectionNote(option_id=choice.option_id, reasons=problems);
    }
    ctx.add_step(AGENT_PLANNER, "Choose option", "llm:choose_option", f"{len(plan.options)} options, {len(rejected)} rejected", f"Chose {option.identifier}: {choice.rationale}", cited, STEP_OK);
    return option;
}

# Verification Agent: recomputes the checks independently of the planner and
# records them on the option (Member 1's checks / feasible / rejection_reason).
def verify(ctx: RunContext, assets: list[Infrastructure], option: RecoveryOption) -> RejectionNote | None {
    checks = check_option(assets, option);
    option.checks = checks;
    ev_ids: list[str] = [];
    for c in checks {
        nums = numbers_in(c.detail);
        ev_ids.append(ctx.add_evidence("check_option", f"{c.name}: {'pass' if c.passed else 'FAIL'} - {c.detail}", [c.name.split(":")[-1]], nums[0] if len(nums) > 0 else 0.0, "MW").id);
        for n in nums { ctx.add_fact(n); }
    }
    failed = [c for c in checks if not c.passed];
    option.feasible = len(failed) == 0;
    if option.feasible {
        ctx.add_step(AGENT_VERIFIER, "Verify constraints", "check_option", option.identifier, f"All {len(checks)} checks passed", ev_ids, STEP_OK);
        return None;
    }
    option.rejection_reason = "; ".join([c.detail for c in failed]);
    ctx.add_step(AGENT_VERIFIER, "Verify constraints", "check_option", option.identifier, f"{len(failed)} of {len(checks)} checks failed: {option.rejection_reason}", ev_ids, STEP_REJECTED);
    return RejectionNote(option_id=option.identifier, failed_checks=[c.name for c in failed], reasons=[c.detail for c in failed]);
}

def recommend(ctx: RunContext, incident: Incident, assessment: ImpactAssessment, chosen: RecoveryOption, rejected: list[RejectionNote]) -> str {
    for attempt in range(LLM_RETRIES + 1) {
        rec = write_recommendation(incident, assessment, chosen, rejected, ctx.evidence);
        cited = _merge(rec.cited_evidence_ids, inline_citations(rec.text));
        problems = validate_text([rec.text], cited, ctx.evidence, ctx.facts);
        if len(problems) == 0 {
            ctx.add_step(AGENT_COORDINATOR, "Write recommendation", "llm:write_recommendation", chosen.identifier, rec.text, cited, STEP_OK);
            return rec.text;
        }
        ctx.add_step(AGENT_COORDINATOR, "Write recommendation", "llm:write_recommendation", f"attempt {attempt + 1}", "Rejected: " + "; ".join(problems), cited, STEP_REJECTED);
    }
    ctx.add_step(AGENT_COORDINATOR, "Write recommendation", "llm:write_recommendation", chosen.identifier, "No valid recommendation after retries", [], STEP_ERROR);
    return "";
}

def _finish(ctx: RunContext, status: str, iterations: int, text: str, option_id: str) -> AgentRun {
    return AgentRun(run_id=ctx.run_id, scenario_id=ctx.scenario_id, mode=MODE_LLM, model=model_name(), status=status, incident_id=ctx.incident_id, steps=ctx.steps, iterations=iterations, final_recommendation=text, recommended_option_id=option_id, evidence=ctx.evidence);
}

def not_configured_run(run_id: str, scenario_id: str) -> AgentRun {
    return AgentRun(run_id=run_id, scenario_id=scenario_id, mode=MODE_NOT_CONFIGURED, model=model_name(), status=RUN_NOT_CONFIGURED);
}

# Coordinator Agent. Applies the scenario to `assets` and opens an Incident
# (recorded on root when persist_incident is True, transient otherwise), then
# runs monitoring -> impact -> (plan -> verify) x <= MAX_ITERATIONS -> recommendation.
def investigate(assets: list[Infrastructure], scenario_id: str, run_id: str, persist_incident: bool = False) -> AgentRun {
    if not is_configured() { return not_configured_run(run_id, scenario_id); }
    ctx = RunContext(run_id=run_id, scenario_id=scenario_id);
    scenario = find_scenario(scenario_id);
    if scenario is None {
        ctx.add_step(AGENT_COORDINATOR, "Validate scenario", "list_scenarios", scenario_id, "Unknown scenario", [], STEP_ERROR);
        return _finish(ctx, RUN_FAILED, 0, "", "");
    }
    target = apply_scenario(assets, scenario_id);
    incident = open_incident(assets, scenario, target) if persist_incident else build_incident(assets, scenario, target, 1);
    ctx.incident_id = incident.identifier;
    ctx.add_step(AGENT_COORDINATOR, "Apply simulated fault", "apply_fault", scenario_id, f"Fault applied to {target.identifier} {target.display_name}; incident {incident.identifier}", [], STEP_OK);
    try {
        fault = run_monitoring(ctx, assets);
        if fault is None { return _finish(ctx, RUN_FAILED, 0, "", ""); }
        if fault.identifier != incident.fault_id {
            ctx.add_step(AGENT_MONITORING, "Confirm incident", "MonitoringScan", incident.identifier, f"Scan found {fault.identifier}, incident names {incident.fault_id}", [], STEP_ERROR);
            return _finish(ctx, RUN_FAILED, 0, "", "");
        }
        assessment = run_impact(ctx, assets, incident);
        if assessment is None { return _finish(ctx, RUN_FAILED, 0, "", ""); }
        plan = run_planning(ctx, assets, incident);
        rejected: list[RejectionNote] = [];
        for iteration in range(1, MAX_ITERATIONS + 1) {
            ctx.add_fact(float(iteration));
            picked = choose(ctx, assessment, plan, rejected);
            if isinstance(picked, RejectionNote) { rejected.append(picked); continue; }
            note = verify(ctx, assets, picked);
            if note is not None { rejected.append(note); continue; }
            text = recommend(ctx, incident, assessment, picked, rejected);
            if text == "" { return _finish(ctx, RUN_FAILED, iteration, "", ""); }
            plan.recommended_id = picked.identifier;
            ctx.add_step(AGENT_COORDINATOR, "Complete run", "coordinator", "", f"Verified {picked.identifier} after {iteration} iteration(s)", [], STEP_OK);
            return _finish(ctx, RUN_COMPLETED, iteration, text, picked.identifier);
        }
        message = f"No option passed verification within {MAX_ITERATIONS} iterations.";
        ctx.add_step(AGENT_COORDINATOR, "Stop re-planning", "coordinator", "", message, [], STEP_ERROR);
        return _finish(ctx, RUN_FAILED, MAX_ITERATIONS, message, "");
    } except Exception as e {
        ctx.add_step(AGENT_COORDINATOR, "Model call failed", "coordinator", "", f"{type(e).__name__}: the run stopped before completion", [], STEP_ERROR);
        return _finish(ctx, RUN_FAILED, 0, "", "");
    }
}
