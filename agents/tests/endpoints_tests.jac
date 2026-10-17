# Endpoint and persistence tests. Records are written to root, so every test uses
# its own run_id and deletes what it created.

import from agents.contracts { AgentRun, AgentStep, AgentRunRecord, HasStep, MODE_LLM }
import from agents.llm { disable_model }
import from agents.endpoints { save_run, get_agent_run, list_agent_runs, run_investigation, agent_status }

def _sample(run_id: str) -> AgentRun {
    return AgentRun(
        run_id=run_id, scenario_id="transformer", mode=MODE_LLM, status="completed", model="mockllm",
        incident_id="INC-0001", iterations=2, final_recommendation="Keep TR-01 isolated [AE-01].", recommended_option_id="OPT-3",
        steps=[
            AgentStep(index=0, agent="Coordinator Agent", action="Apply simulated fault", tool="apply_fault", status="ok"),
            AgentStep(index=1, agent="Verification Agent", action="Verify constraints", tool="check_option", evidence_ids=["AE-01"], status="rejected"),
            AgentStep(index=2, agent="Verification Agent", action="Verify constraints", tool="check_option", status="ok")
        ]
    );
}

def _cleanup(run_id: str) -> None {
    for r in [root -->][?:AgentRunRecord] {
        if r.run_id == run_id {
            for s in [r ->:HasStep:->] { del s; }
            del r;
        }
    }
}

test "saved runs round-trip with ordered steps" {
    run_id = "t-ep-roundtrip";
    save_run(_sample(run_id));
    loaded = get_agent_run(run_id);
    assert loaded is not None;
    assert loaded.status == "completed" and loaded.iterations == 2 and loaded.recommended_option_id == "OPT-3";
    assert loaded.incident_id == "INC-0001";
    assert [s.index for s in loaded.steps] == [0, 1, 2];
    assert loaded.steps[1].status == "rejected" and loaded.steps[1].evidence_ids == ["AE-01"];
    assert run_id in [r.run_id for r in list_agent_runs()];
    _cleanup(run_id);
    assert get_agent_run(run_id) is None;
}

test "list is newest first" {
    save_run(_sample("t-ep-older"));
    save_run(_sample("t-ep-newer"));
    ids = [r.run_id for r in list_agent_runs() if r.run_id.startswith("t-ep-")];
    assert ids.index("t-ep-newer") < ids.index("t-ep-older");
    _cleanup("t-ep-older");
    _cleanup("t-ep-newer");
}

test "not configured endpoint call stores nothing" {
    disable_model();
    before = len([root -->][?:AgentRunRecord]);
    run = run_investigation("transformer");
    assert run.mode == "not_configured" and run.status == "not_configured" and run.steps == [];
    assert len([root -->][?:AgentRunRecord]) == before;
    assert not agent_status().configured;
}
