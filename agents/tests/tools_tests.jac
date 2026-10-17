import from services.scenarios { fault_node }
import from agents.tools {
    get_asset, list_scenarios, trace_downstream_ids, impact_totals, incident_evidence,
    find_restoration_path, plan_recovery, check_option, is_isolation, path_links, donor_of
}
import from agents.tests.fixtures { faulted, incident_for, option_by_id, check_named, all_passed }

test "read tools wrap the graph services" {
    assets = faulted("transformer");
    asset = get_asset(assets, "FAC-01");
    assert asset is not None and asset.display_name == "Civic Hospital";
    assert get_asset(assets, "NOPE") is None;
    assert [d.identifier for d in trace_downstream_ids(assets, "TR-01")] == ["J-01", "FAC-01", "FAC-02", "ZONE-01"];
    assert [s.identifier for s in list_scenarios()] == ["transformer", "substation", "line"];
    snap = impact_totals(assets);
    assert snap.interrupted_load_mw == 45.0 and snap.critical_interrupted == 1;
    records = incident_evidence(incident_for(assets, "transformer"));
    assert [r.identifier for r in records][0] == "INC-0001/EV-01";
    assert [r.asset_id for r in records] == ["TR-01", "J-01", "FAC-01", "FAC-02", "ZONE-01"];
}

test "restoration path back-feeds through the alternate-fed asset and avoids the fault" {
    assets = faulted("transformer");
    path = find_restoration_path(assets, "FAC-01", "TR-01");
    assert path.found and path.donor_id == "FAC-02";
    assert [h.link_id for h in path.hops] == ["L-09", "L-10"];
    assert not find_restoration_path(faulted("line"), "FAC-01", "J-01").found;
}

test "transformer plan uses the services recovery contract" {
    assets = faulted("transformer");
    plan = plan_recovery(assets, incident_for(assets, "transformer"));
    assert plan.fault_id == "TR-01";
    assert [o.identifier for o in plan.options] == ["OPT-1", "OPT-2", "OPT-3"];
    all_opt = option_by_id(plan, "OPT-1");
    assert all_opt.restored_assets == ["FAC-01", "ZONE-01"];
    assert all_opt.restored_load_mw == 45.0 and all_opt.critical_restored == 1;
    assert donor_of(all_opt) == "FAC-02";
    assert path_links(all_opt) == ["L-09", "L-10", "L-11"];
    assert [a.transfer_mw for a in all_opt.actions] == [18.0, 27.0];
    assert not all_opt.feasible and all_opt.checks == [];
    assert option_by_id(plan, "OPT-2").restored_assets == ["FAC-01"];
    assert is_isolation(option_by_id(plan, "OPT-3"));
}

test "restoring West Junction loads exceeds the alternate path capacity" {
    assets = faulted("transformer");
    plan = plan_recovery(assets, incident_for(assets, "transformer"));
    checks = check_option(assets, option_by_id(plan, "OPT-1"));
    assert not all_passed(checks);
    l10 = check_named(checks, "link_capacity:L-10");
    assert not l10.passed and l10.detail == "L-10 headroom: 45 MW needed, 24 MW available";
    assert check_named(checks, "link_capacity:L-09").passed;
    assert not check_named(checks, "supply_link_capacity:L-14").passed;
    assert check_named(checks, "donor_capacity:FAC-02").detail.endswith("10 MW available");
    pri = check_option(assets, option_by_id(plan, "OPT-2"));
    assert not all_passed(pri);
    assert check_named(pri, "link_capacity:L-10").passed;
}

test "isolate-only passes for every scenario" {
    for sid in ["transformer", "substation", "line"] {
        assets = faulted(sid);
        plan = plan_recovery(assets, incident_for(assets, sid));
        assert all_passed(check_option(assets, option_by_id(plan, "OPT-3"))), sid;
    }
}

test "line fault leaves no restoration path" {
    assets = faulted("line");
    plan = plan_recovery(assets, incident_for(assets, "line"));
    assert [o.identifier for o in plan.options] == ["OPT-3"];
}

test "substation plan only targets loads with a path around the fault" {
    assets = faulted("substation");
    plan = plan_recovery(assets, incident_for(assets, "substation"));
    assert option_by_id(plan, "OPT-1").restored_assets == ["FAC-01", "ZONE-01"];
    assert option_by_id(plan, "OPT-2").restored_assets == ["FAC-01"];
}

test "planning is deterministic" {
    a = faulted("transformer");
    b = faulted("transformer");
    pa = plan_recovery(a, incident_for(a, "transformer"));
    pb = plan_recovery(b, incident_for(b, "transformer"));
    assert [(o.identifier, o.restored_assets, path_links(o), o.restored_load_mw) for o in pa.options] == [(o.identifier, o.restored_assets, path_links(o), o.restored_load_mw) for o in pb.options];
}
