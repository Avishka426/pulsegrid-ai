import from services.models { STATUS_NORMAL, STATUS_FAULT, STATUS_DE_ENERGIZED, STATUS_ALTERNATE_FEED }
import from services.seed { build_network }
import from services.scenarios { SCENARIOS, apply_scenario, reset_assets }
import from services.views { snapshot, link_views }
import from services.tests.fixtures { ids_of, asset_by_id, status_of, link_status, all_normal }

test "each scenario targets its explicit asset" {
    expected = {"transformer": "TR-01", "substation": "SUB-01", "line": "J-01"};
    for s in SCENARIOS {
        assets = build_network();
        target = apply_scenario(assets, s.identifier);
        assert target.identifier == expected[s.identifier];
        snap = snapshot(assets);
        assert snap.fault_id == expected[s.identifier];
        assert snap.scenario_id == s.identifier;
        assert snap.scenario_title == s.title;
    }
}

test "transformer scenario marks fault, downstream and untouched assets" {
    assets = build_network();
    apply_scenario(assets, "transformer");
    snap = snapshot(assets);
    assert snap.fault_active and snap.fault_label == "Central Transformer A";
    assert status_of(assets, "TR-01") == STATUS_FAULT;
    for i in ["J-01", "FAC-01", "ZONE-01"] { assert status_of(assets, i) == STATUS_DE_ENERGIZED; }
    assert status_of(assets, "FAC-02") == STATUS_ALTERNATE_FEED;
    for i in ["SRC-01", "SUB-01", "SUB-02", "TR-02", "TR-03", "J-02", "J-03", "FAC-03", "ZONE-02"] { assert status_of(assets, i) == STATUS_NORMAL; }
    assert link_status(snap, "L-03") == STATUS_NORMAL;
    assert link_status(snap, "L-06") == STATUS_FAULT;
    for l in ["L-09", "L-10", "L-11"] { assert link_status(snap, l) == STATUS_DE_ENERGIZED; }
    assert link_status(snap, "L-14") == STATUS_NORMAL;
    assert len(snap.downstream) == 4;
    assert snap.interrupted_load_mw == 45.0;
    assert snap.critical_interrupted == 1;
}

test "substation scenario interrupts both central branches" {
    assets = build_network();
    apply_scenario(assets, "substation");
    snap = snapshot(assets);
    assert len(snap.downstream) == 9;
    assert len([n for n in assets if n.operational_status == STATUS_DE_ENERGIZED]) == 8;
    assert status_of(assets, "FAC-02") == STATUS_ALTERNATE_FEED;
    assert status_of(assets, "SUB-02") == STATUS_NORMAL;
    assert snap.interrupted_load_mw == 100.0;
    assert snap.critical_interrupted == 1;
}

test "line scenario faults the west junction only" {
    assets = build_network();
    apply_scenario(assets, "line");
    snap = snapshot(assets);
    assert snap.fault_id == "J-01";
    assert ids_of(snap.downstream) == ["FAC-01", "FAC-02", "ZONE-01"];
    assert status_of(assets, "TR-01") == STATUS_NORMAL;
    assert snap.interrupted_load_mw == 45.0;
}

test "applying a second scenario clears the first" {
    assets = build_network();
    apply_scenario(assets, "substation");
    apply_scenario(assets, "line");
    assert len([n for n in assets if n.operational_status == STATUS_FAULT]) == 1;
    assert status_of(assets, "SUB-01") == STATUS_NORMAL;
    assert status_of(assets, "J-02") == STATUS_NORMAL;
    assert status_of(assets, "J-01") == STATUS_FAULT;
}

test "unknown scenario is rejected without changing state" {
    assets = build_network();
    apply_scenario(assets, "transformer");
    raised = False;
    try { apply_scenario(assets, "meteor"); } except ValueError { raised = True; }
    assert raised;
    assert status_of(assets, "TR-01") == STATUS_FAULT;
}

test "reset restores the full baseline" {
    assets = build_network();
    apply_scenario(assets, "substation");
    assert not all_normal(assets);
    reset_assets(assets);
    assert all_normal(assets);
    snap = snapshot(assets);
    assert not snap.fault_active;
    assert snap.fault_label == "" and snap.fault_id == "" and snap.scenario_id == "";
    assert snap.downstream == [];
    assert snap.interrupted_load_mw == 0.0;
}

test "reset on a baseline network is a no-op" {
    assets = build_network();
    reset_assets(assets);
    assert all_normal(assets);
    assert len(link_views(assets)) == 14;
}
