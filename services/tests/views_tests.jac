import from services.seed { build_network }
import from services.scenarios { mark_fault, apply_scenario }
import from services.views { link_views, snapshot, scenario_infos, preview }
import from services.tests.fixtures { asset_by_id }

test "link views pair each link with its own endpoints" {
    links = link_views(build_network());
    pairs = [f"{l.identifier}:{l.source}>{l.target}" for l in links];
    assert "L-03:SUB-01>TR-01" in pairs;
    assert "L-04:SUB-01>TR-02" in pairs;
    assert "L-10:J-01>FAC-02" in pairs;
    assert "L-14:J-03>FAC-02" in pairs;
}

test "faulted end-use asset counts its own load as interrupted" {
    assets = build_network();
    mark_fault(assets, asset_by_id(assets, "FAC-01"));
    snap = snapshot(assets);
    assert snap.downstream == [];
    assert snap.interrupted_load_mw == 18.0;
    assert snap.critical_interrupted == 1;
}

test "scenario list resolves each target asset" {
    infos = scenario_infos();
    assert [(i.identifier, i.target_id) for i in infos] == [("transformer", "TR-01"), ("substation", "SUB-01"), ("line", "J-01")];
    assert [i.target_name for i in infos] == ["Central Transformer A", "Central Substation", "West Junction"];
    assert infos[1].target_category == "Substation";
}

test "scenario preview matches the applied snapshot for every scenario" {
    for (sid, downstream, de_energized, mw) in [("transformer", 4, 3, 45.0), ("substation", 9, 8, 100.0), ("line", 3, 2, 45.0)] {
        p = preview(sid);
        assert p.scenario_id == sid and len(p.downstream) == downstream;
        assert (p.de_energized, p.alternate_feed) == (de_energized, 1);
        assert p.interrupted_load_mw == mw and p.critical_interrupted == 1;
        assets = build_network();
        apply_scenario(assets, sid);
        snap = snapshot(assets);
        assert [d.identifier for d in p.downstream] == [d.identifier for d in snap.downstream];
    }
}

test "scenario preview rejects an unknown scenario" {
    raised = False;
    try { preview("meteor"); } except ValueError { raised = True; }
    assert raised;
}
