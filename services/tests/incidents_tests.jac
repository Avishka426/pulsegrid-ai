import from services.models { STATUS_FAULT, STATUS_DE_ENERGIZED, STATUS_ALTERNATE_FEED }
import from services.seed { build_network }
import from services.scenarios { SCENARIOS, find_scenario, apply_scenario }
import from services.walkers { compute_downstream }
import from services.incidents { build_incident, evidence_of }
import from services.tests.fixtures { asset_by_id }

test "transformer incident records fault and downstream evidence in BFS order" {
    assets = build_network();
    scenario = find_scenario("transformer");
    assert scenario is not None;
    incident = build_incident(assets, scenario, asset_by_id(assets, "TR-01"), 7);
    assert incident.identifier == "INC-0007";
    assert incident.sequence == 7 and incident.status == "active";
    assert incident.scenario_id == "transformer" and incident.fault_id == "TR-01";
    evidence = evidence_of(incident);
    assert [e.identifier for e in evidence] == [f"INC-0007/EV-{i:02d}" for i in range(1, 6)];
    assert [e.asset_id for e in evidence] == ["TR-01", "J-01", "FAC-01", "FAC-02", "ZONE-01"];
    assert [e.kind for e in evidence] == [STATUS_FAULT, STATUS_DE_ENERGIZED, STATUS_DE_ENERGIZED, STATUS_ALTERNATE_FEED, STATUS_DE_ENERGIZED];
    assert [e.hops for e in evidence] == [0, 1, 2, 2, 2];
    assert [e.value_mw for e in evidence] == [72.0, 38.0, 18.0, 14.0, 27.0];
    assert "another supply path" in evidence[3].detail;
}

test "every scenario incident has one fault record plus one per downstream asset" {
    for s in SCENARIOS {
        assets = build_network();
        target = apply_scenario(assets, s.identifier);
        incident = build_incident(assets, s, target, 1);
        evidence = evidence_of(incident);
        downstream = compute_downstream(assets, target);
        assert len(evidence) == 1 + len(downstream);
        assert evidence[0].kind == STATUS_FAULT and evidence[0].asset_id == s.target_id;
        assert [e.asset_id for e in evidence[1:]] == [d.identifier for d in downstream];
    }
}

test "incident records are deterministic for the same inputs" {
    a = build_network();
    b = build_network();
    scenario = find_scenario("substation");
    assert scenario is not None;
    first = evidence_of(build_incident(a, scenario, asset_by_id(a, "SUB-01"), 3));
    second = evidence_of(build_incident(b, scenario, asset_by_id(b, "SUB-01"), 3));
    assert [(e.identifier, e.kind, e.asset_id, e.detail, e.hops, e.value_mw) for e in first] == [(e.identifier, e.kind, e.asset_id, e.detail, e.hops, e.value_mw) for e in second];
    assert len(first) == 10;
}
