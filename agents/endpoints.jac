# Agent endpoints and run persistence.
#
# Completed and failed runs are stored on the caller's root as AgentRunRecord
# nodes with one AgentStepRecord per step, next to the Incident the run opened.
# Not-configured responses and unknown scenarios are never stored: they are not runs.

import uuid;
import from datetime { datetime, timezone }
import from services.seed { network_assets }
import from services.scenarios { find_scenario }
import from agents.contracts {
    AgentRun, AgentStep, AgentStatus, AgentRunRecord, AgentStepRecord, HasStep, MODE_LLM
}
import from agents.llm { current_status }
import from agents.investigation { investigate }

def _new_run_id() -> str {
    return uuid.uuid4().hex[:12];
}

def save_run(run: AgentRun) -> AgentRunRecord {
    record = AgentRunRecord(
        run_id=run.run_id, scenario_id=run.scenario_id, mode=run.mode, status=run.status,
        model=run.model, incident_id=run.incident_id, iterations=run.iterations, final_recommendation=run.final_recommendation,
        recommended_option_id=run.recommended_option_id, evidence=run.evidence,
        created_at=datetime.now(timezone.utc).isoformat()
    );
    root ++> record;
    for s in run.steps {
        record +>:HasStep:+> AgentStepRecord(index=s.index, agent=s.agent, action=s.action, tool=s.tool, input_summary=s.input_summary, output_summary=s.output_summary, evidence_ids=s.evidence_ids, status=s.status);
    }
    return record;
}

def _step_index(s: AgentStepRecord) -> int { return s.index; }

def to_run(record: AgentRunRecord) -> AgentRun {
    steps: list[AgentStep] = [];
    for s in sorted([record ->:HasStep:->], key=_step_index) {
        steps.append(AgentStep(index=s.index, agent=s.agent, action=s.action, tool=s.tool, input_summary=s.input_summary, output_summary=s.output_summary, evidence_ids=s.evidence_ids, status=s.status));
    }
    return AgentRun(
        run_id=record.run_id, scenario_id=record.scenario_id, mode=record.mode, status=record.status,
        model=record.model, incident_id=record.incident_id, steps=steps, iterations=record.iterations,
        final_recommendation=record.final_recommendation, recommended_option_id=record.recommended_option_id,
        evidence=record.evidence
    );
}

def _created(r: AgentRunRecord) -> str { return r.created_at; }

def _records() -> list[AgentRunRecord] {
    return sorted([root -->][?:AgentRunRecord], key=_created, reverse=True);
}

def:pub agent_status() -> AgentStatus {
    return current_status();
}

def:pub run_investigation(scenario_id: str) -> AgentRun {
    known = find_scenario(scenario_id) is not None;
    run = investigate(network_assets(), scenario_id, _new_run_id(), persist_incident=known);
    if run.mode == MODE_LLM and known { save_run(run); }
    return run;
}

def:pub list_agent_runs() -> list[AgentRun] {
    return [to_run(r) for r in _records()];
}

def:pub get_agent_run(run_id: str) -> AgentRun | None {
    for r in _records() { if r.run_id == run_id { return to_run(r); } }
    return None;
}
