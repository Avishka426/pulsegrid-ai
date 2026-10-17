# Agent and coordinator tests. MockLLM supplies every model output; graph tools
# run for real on a transient network, never on root.

import from services.models { STATUS_NORMAL }
import from services.seed { build_network }
import from services.views { snapshot }
import from agents.contracts {
    ImpactNarrative, Recommendation, AGENT_PLANNER, AGENT_VERIFIER,
    STEP_OK, STEP_REJECTED, STEP_ERROR, RUN_COMPLETED, RUN_FAILED, RUN_NOT_CONFIGURED,
    MODE_LLM, MODE_NOT_CONFIGURED
}
import from agents.llm { disable_model }
import from agents.investigation { RunContext, run_monitoring, run_impact, investigate }
import from agents.tests.fixtures {
    faulted, incident_for, mock, narrative, pick, recommendation, steps_of, evidence_value
}

test "monitoring walker finds the fault and high-load asset" {
    assets = faulted("transformer");
    ctx = RunContext(run_id="t-mon-000", scenario_id="transformer");
    fault = run_monitoring(ctx, assets);
    assert fault is not None and fault.identifier == "TR-01";
    labels = [e.label for e in ctx.evidence];
    assert labels[0].startswith("TR-01 Central Transformer A is in fault state");
    assert "TR-01 Central Transformer A load is 80% of capacity" in labels;
    assert ctx.steps[0].status == STEP_OK and "Scanned 14 assets" in ctx.steps[0].output_summary;
}

test "monitoring reports an error when no fault is active" {
    ctx = RunContext(run_id="t-mon-001", scenario_id="transformer");
    assert run_monitoring(ctx, build_network()) is None;
    assert ctx.steps[-1].status == STEP_ERROR;
}

test "impact numbers equal the tool results for all scenarios" {
    for sid in ["transformer", "substation", "line"] {
        mock([narrative()]);
        assets = faulted(sid);
        incident = incident_for(assets, sid);
        ctx = RunContext(run_id="t-imp-000", scenario_id=sid);
        a = run_impact(ctx, assets, incident);
        assert a is not None, sid;
        snap = snapshot(assets);
        assert a.downstream_count == len(snap.downstream), sid;
        assert a.interrupted_load_mw == snap.interrupted_load_mw, sid;
        assert a.critical_interrupted == snap.critical_interrupted, sid;
        assert a.alternate_feed_ids == [d.identifier for d in snap.downstream if d.alternate_feed], sid;
        assert a.incident_id == incident.identifier;
        refs = [e.ref_id for e in ctx.evidence if e.ref_id != ""];
        assert refs[0] == "INC-0001/EV-01", sid;
        assert len(refs) == len(snap.downstream) + 1, sid;
    }
}

test "narrative with an invented number is rejected then retried" {
    bad = ImpactNarrative(summary="About 99 MW is lost [AE-01].", cited_evidence_ids=["AE-01"]);
    mock([bad, narrative()]);
    assets = faulted("transformer");
    ctx = RunContext(run_id="t-imp-001", scenario_id="transformer");
    assert run_impact(ctx, assets, incident_for(assets, "transformer")) is not None;
    narr = [s for s in ctx.steps if s.tool == "llm:narrate_impact"];
    assert [s.status for s in narr] == [STEP_REJECTED, STEP_OK];
    assert "99" in narr[0].output_summary;
}

test "narrative citing unknown evidence fails after retries" {
    bad = ImpactNarrative(summary="Impact noted [AE-99].", cited_evidence_ids=["AE-99"]);
    mock([bad, bad]);
    assets = faulted("transformer");
    ctx = RunContext(run_id="t-imp-002", scenario_id="transformer");
    assert run_impact(ctx, assets, incident_for(assets, "transformer")) is None;
    assert ctx.steps[-1].status == STEP_ERROR;
}

test "verification failure triggers re-planning and the verified option wins" {
    rec = Recommendation(text="Restoring 18 MW to FAC-01 failed verification, so keep TR-01 isolated in the simulation [AE-01].", cited_evidence_ids=["AE-01"]);
    mock([narrative(), pick("OPT-2"), pick("OPT-3"), rec]);
    run = investigate(build_network(), "transformer", "t-coord-001");
    assert run.status == RUN_COMPLETED, [s.output_summary for s in run.steps];
    assert run.mode == MODE_LLM;
    assert run.incident_id == "INC-0001";
    assert run.recommended_option_id == "OPT-3";
    assert run.iterations == 2;
    verifier = steps_of(run, AGENT_VERIFIER);
    assert [s.status for s in verifier] == [STEP_REJECTED, STEP_OK];
    assert "L-14" in verifier[0].output_summary;
    assert run.final_recommendation == rec.text;
    assert [s.index for s in run.steps] == list(range(len(run.steps)));
}

test "invalid and repeated choices are rejected and count toward the cap" {
    mock([narrative(), pick("OPT-9"), pick("OPT-1"), pick("OPT-1")]);
    run = investigate(build_network(), "transformer", "t-coord-002");
    assert run.status == RUN_FAILED;
    assert run.iterations == 3;
    assert run.recommended_option_id == "";
    planner = [s for s in steps_of(run, AGENT_PLANNER) if s.tool == "llm:choose_option"];
    assert [s.status for s in planner] == [STEP_REJECTED, STEP_OK, STEP_REJECTED];
    assert "not one of the provided options" in planner[0].output_summary;
    assert "already rejected" in planner[2].output_summary;
    assert run.steps[-1].status == STEP_ERROR and "within 3 iterations" in run.steps[-1].output_summary;
}

test "iteration cap stops a planner that keeps choosing failing options" {
    mock([narrative(), pick("OPT-1"), pick("OPT-2"), pick("OPT-1")]);
    run = investigate(build_network(), "transformer", "t-coord-003");
    assert run.status == RUN_FAILED and run.iterations == 3;
    assert len([s for s in run.steps if s.tool == "llm:choose_option"]) == 3;
    assert len([s for s in run.steps if s.tool == "llm:write_recommendation"]) == 0;
}

test "every scenario completes with numbers matching the graph" {
    for sid in ["transformer", "substation", "line"] {
        mock([narrative(), pick("OPT-3"), recommendation()]);
        assets = build_network();
        run = investigate(assets, sid, f"t-all-{sid}");
        assert run.status == RUN_COMPLETED, sid;
        snap = snapshot(assets);
        assert evidence_value(run, "Interrupted end-use load") == snap.interrupted_load_mw, sid;
        assert evidence_value(run, f"{len(snap.downstream)} assets downstream") == float(len(snap.downstream)), sid;
        known = [e.id for e in run.evidence];
        for step in run.steps { for ev_id in step.evidence_ids { assert ev_id in known, ev_id; } }
    }
}

test "not configured returns no steps and leaves the graph untouched" {
    disable_model();
    assets = build_network();
    run = investigate(assets, "transformer", "t-off-000");
    assert run.mode == MODE_NOT_CONFIGURED and run.status == RUN_NOT_CONFIGURED;
    assert run.steps == [] and run.evidence == [] and run.final_recommendation == "";
    assert all([n.operational_status == STATUS_NORMAL for n in assets]);
}

test "unknown scenario fails without applying a fault" {
    mock([]);
    assets = build_network();
    run = investigate(assets, "volcano", "t-bad-000");
    assert run.status == RUN_FAILED and len(run.steps) == 1;
    assert all([n.operational_status == STATUS_NORMAL for n in assets]);
}

test "a model error ends the run as failed without leaking details" {
    mock([]);
    run = investigate(build_network(), "transformer", "t-err-000");
    assert run.status == RUN_FAILED;
    assert run.steps[-1].status == STEP_ERROR;
    assert run.steps[-1].output_summary.endswith("the run stopped before completion");
}
