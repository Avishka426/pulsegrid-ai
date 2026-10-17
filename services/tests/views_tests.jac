import from services.seed { build_network }
import from services.scenarios { mark_fault }
import from services.views { link_views, snapshot }
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
