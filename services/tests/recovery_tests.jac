import from services.models { PowerLink, RecoveryPlan, RecoveryOption }
import from services.seed { build_network }
import from services.scenarios { SCENARIOS, apply_scenario, find_scenario }
import from services.incidents { build_incident }
import from services.recovery { build_recovery_plan, is_isolation }
import from services.tests.fixtures { asset_by_id }

def _plan_for(scenario_id: str, water_capacity: float = 0.0) -> RecoveryPlan {
    assets = build_network();
    if water_capacity > 0.0 {
        water = asset_by_id(assets, "FAC-02");
        water.capacity_mw = water_capacity;
        for e in [edge asset_by_id(assets, "J-03") ->:PowerLink:->] { e.capacity_mw = water_capacity; }
    }
    target = apply_scenario(assets, scenario_id);
    scenario = find_scenario(scenario_id);
    assert scenario is not None;
    return build_recovery_plan(assets, build_incident(assets, scenario, target, 1));
}

test "every option is verified and the seed network recommends isolation" {
    for s in SCENARIOS {
        plan = _plan_for(s.identifier);
        assert len(plan.options) > 0, s.identifier;
        for o in plan.options { assert len(o.checks) > 0 and o.feasible == all([c.passed for c in o.checks]), (s.identifier, o.identifier); }
        recommended = [o for o in plan.options if o.identifier == plan.recommended_id];
        assert len(recommended) == 1 and is_isolation(recommended[0]) and recommended[0].feasible, s.identifier;
    }
}

test "transformer restore options are rejected with the failing check" {
    plan = _plan_for("transformer");
    by_id: dict[str, RecoveryOption] = {o.identifier: o for o in plan.options};
    assert [o.identifier for o in plan.options] == ["OPT-1", "OPT-2", "OPT-3"];
    assert not by_id["OPT-1"].feasible and not by_id["OPT-2"].feasible;
    assert by_id["OPT-2"].rejection_reason.startswith("donor_capacity:FAC-02");
    assert "18 MW needed" in by_id["OPT-2"].rejection_reason;
    assert by_id["OPT-3"].rejection_reason == "";
}

test "a feasible restoring option is recommended over isolation" {
    plan = _plan_for("transformer", water_capacity=60.0);
    by_id: dict[str, RecoveryOption] = {o.identifier: o for o in plan.options};
    assert by_id["OPT-2"].feasible and by_id["OPT-2"].restored_assets == ["FAC-01"];
    assert not by_id["OPT-1"].feasible;
    assert plan.recommended_id == "OPT-2";
}

test "recovery plans are deterministic" {
    a = _plan_for("substation");
    b = _plan_for("substation");
    assert [(o.identifier, o.feasible, o.rejection_reason) for o in a.options] == [(o.identifier, o.feasible, o.rejection_reason) for o in b.options];
    assert a.recommended_id == b.recommended_id;
}
