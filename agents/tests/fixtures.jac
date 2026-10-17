# Shared helpers for agent tests. Graph tools run for real on a transient
# network from build_network(); MockLLM supplies every model output.

import from jaclang.byllm.lib { MockLLM }
import from services.models { Infrastructure, Incident, RecoveryOption, RecoveryPlan, ConstraintCheck }
import from services.seed { build_network }
import from services.scenarios { apply_scenario, find_scenario }
import from services.incidents { build_incident }
import from agents.contracts { ImpactNarrative, PlanChoice, Recommendation, AgentRun, AgentStep }
import from agents.llm { use_model }

def faulted(scenario_id: str) -> list[Infrastructure] {
    assets = build_network();
    apply_scenario(assets, scenario_id);
    return assets;
}

def incident_for(assets: list[Infrastructure], scenario_id: str) -> Incident {
    scenario = find_scenario(scenario_id);
    if scenario is None { raise AssertionError(f"unknown scenario {scenario_id}"); }
    for n in assets {
        if n.identifier == scenario.target_id { return build_incident(assets, scenario, n, 1); }
    }
    raise AssertionError(f"missing target {scenario.target_id}");
}

def option_by_id(plan: RecoveryPlan, option_id: str) -> RecoveryOption {
    for o in plan.options { if o.identifier == option_id { return o; } }
    raise AssertionError(f"missing option {option_id}");
}

def check_named(checks: list[ConstraintCheck], name: str) -> ConstraintCheck {
    for c in checks { if c.name == name { return c; } }
    raise AssertionError(f"missing check {name}");
}

def all_passed(checks: list[ConstraintCheck]) -> bool {
    return all([c.passed for c in checks]);
}

def mock(outputs: list[ImpactNarrative | PlanChoice | Recommendation]) -> None {
    use_model(MockLLM(model_name="mockllm", config={"outputs": outputs}));
}

def narrative() -> ImpactNarrative {
    return ImpactNarrative(summary="The simulated fault interrupts downstream supply [AE-01].", key_points=[], cited_evidence_ids=["AE-01"]);
}

def pick(option_id: str) -> PlanChoice {
    return PlanChoice(option_id=option_id, rationale=f"Choosing {option_id} based on the evidence [AE-01].", cited_evidence_ids=["AE-01"]);
}

def recommendation() -> Recommendation {
    return Recommendation(text="Keep the faulted section isolated in the simulation [AE-01].", cited_evidence_ids=["AE-01"]);
}

def steps_of(run: AgentRun, agent: str) -> list[AgentStep] {
    return [s for s in run.steps if s.agent == agent];
}

def evidence_value(run: AgentRun, prefix: str) -> float {
    for e in run.evidence { if e.label.startswith(prefix) { return e.value; } }
    raise AssertionError(f"no evidence starting with {prefix}");
}
