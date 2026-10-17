# Tests build their own transient network with _build_network() and never touch
# root, so they are isolated from persisted dashboard state and from each other.

def _ids(items: list[DownstreamAsset]) -> list[str] {
    return [i.identifier for i in items];
}

def _asset(assets: list[Infrastructure], identifier: str) -> Infrastructure {
    n = _find_asset(assets, identifier);
    if n is None { raise AssertionError(f"missing asset {identifier}"); }
    return n;
}

def _status_of(assets: list[Infrastructure], identifier: str) -> str {
    return _asset(assets, identifier).operational_status;
}

def _link_status(snap: GraphSnapshot, identifier: str) -> str {
    for l in snap.links { if l.identifier == identifier { return l.operational_status; } }
    assert False, f"missing link {identifier}";
    return "";
}

def _all_normal(assets: list[Infrastructure]) -> bool {
    for l in _link_views(assets) { if l.operational_status != STATUS_NORMAL { return False; } }
    for n in assets { if n.operational_status != STATUS_NORMAL { return False; } }
    return True;
}

test "seed network has 14 unique assets and 14 unique links" {
    assets = _build_network();
    links = _link_views(assets);
    assert len(assets) == 14;
    assert len(set([n.identifier for n in assets])) == 14;
    assert len(links) == 14;
    assert [l.identifier for l in links] == [f"L-{i:02d}" for i in range(1, 15)];
}

test "link views pair each link with its own endpoints" {
    links = _link_views(_build_network());
    pairs = [f"{l.identifier}:{l.source}>{l.target}" for l in links];
    assert "L-03:SUB-01>TR-01" in pairs;
    assert "L-04:SUB-01>TR-02" in pairs;
    assert "L-10:J-01>FAC-02" in pairs;
    assert "L-14:J-03>FAC-02" in pairs;
}

test "transformer trace reaches its junction and facilities in BFS order" {
    assets = _build_network();
    impact = compute_downstream(assets, _asset(assets, "TR-01"));
    assert _ids(impact) == ["J-01", "FAC-01", "FAC-02", "ZONE-01"];
    assert [i.hops for i in impact] == [1, 2, 2, 2];
}

test "substation trace reaches both transformer branches" {
    assets = _build_network();
    impact = compute_downstream(assets, _asset(assets, "SUB-01"));
    assert _ids(impact) == ["TR-01", "TR-02", "J-01", "J-02", "FAC-01", "FAC-02", "ZONE-01", "FAC-03", "ZONE-02"];
    assert [i.hops for i in impact] == [1, 1, 2, 2, 3, 3, 3, 3, 3];
    for i in impact { assert "SUB-02" != i.identifier and "J-03" != i.identifier; }
}

test "source trace visits every asset with two feeders once" {
    assets = _build_network();
    trace = trace_downstream(_asset(assets, "SRC-01"), []);
    ids = [n.identifier for n in trace.reached];
    assert len(ids) == 13;
    assert len(set(ids)) == 13;
    assert ids.count("FAC-02") == 1;
    assert "SRC-01" not in ids;
}

test "end-use asset has no downstream assets" {
    assets = _build_network();
    assert compute_downstream(assets, _asset(assets, "FAC-01")) == [];
}

test "blocked assets stop the traversal" {
    assets = _build_network();
    trace = trace_downstream(_asset(assets, "SRC-01"), ["SUB-01"]);
    ids = [n.identifier for n in trace.reached];
    assert ids == ["SUB-02", "TR-03", "J-03", "FAC-02"];
}

test "traversal is deterministic across runs and fresh networks" {
    a = _build_network();
    b = _build_network();
    first = _ids(compute_downstream(a, _asset(a, "SUB-01")));
    assert len(first) == 9;
    assert _ids(compute_downstream(a, _asset(a, "SUB-01"))) == first;
    assert _ids(compute_downstream(b, _asset(b, "SUB-01"))) == first;
}

test "faulted end-use asset counts its own load as interrupted" {
    assets = _build_network();
    _mark_fault(assets, _asset(assets, "FAC-01"));
    snap = _snapshot(assets);
    assert snap.downstream == [];
    assert snap.interrupted_load_mw == 18.0;
    assert snap.critical_interrupted == 1;
}

test "alternate feed is detected only where another supply path exists" {
    assets = _build_network();
    tr = compute_downstream(assets, _asset(assets, "TR-01"));
    assert [i.identifier for i in tr if i.alternate_feed] == ["FAC-02"];
    src = compute_downstream(assets, _asset(assets, "SRC-01"));
    assert [i.identifier for i in src if i.alternate_feed] == [];
}

test "each scenario targets its explicit asset" {
    expected = {"transformer": "TR-01", "substation": "SUB-01", "line": "J-01"};
    for s in SCENARIOS {
        assets = _build_network();
        target = _apply_scenario(assets, s.identifier);
        assert target.identifier == expected[s.identifier];
        snap = _snapshot(assets);
        assert snap.fault_id == expected[s.identifier];
        assert snap.scenario_id == s.identifier;
        assert snap.scenario_title == s.title;
    }
}

test "transformer scenario marks fault, downstream and untouched assets" {
    assets = _build_network();
    _apply_scenario(assets, "transformer");
    snap = _snapshot(assets);
    assert snap.fault_active and snap.fault_label == "Central Transformer A";
    assert _status_of(assets, "TR-01") == STATUS_FAULT;
    for i in ["J-01", "FAC-01", "ZONE-01"] { assert _status_of(assets, i) == STATUS_DE_ENERGIZED; }
    assert _status_of(assets, "FAC-02") == STATUS_ALTERNATE_FEED;
    for i in ["SRC-01", "SUB-01", "SUB-02", "TR-02", "TR-03", "J-02", "J-03", "FAC-03", "ZONE-02"] { assert _status_of(assets, i) == STATUS_NORMAL; }
    assert _link_status(snap, "L-03") == STATUS_NORMAL;
    assert _link_status(snap, "L-06") == STATUS_FAULT;
    for l in ["L-09", "L-10", "L-11"] { assert _link_status(snap, l) == STATUS_DE_ENERGIZED; }
    assert _link_status(snap, "L-14") == STATUS_NORMAL;
    assert len(snap.downstream) == 4;
    assert snap.interrupted_load_mw == 45.0;
    assert snap.critical_interrupted == 1;
}

test "substation scenario interrupts both central branches" {
    assets = _build_network();
    _apply_scenario(assets, "substation");
    snap = _snapshot(assets);
    assert len(snap.downstream) == 9;
    assert len([n for n in assets if n.operational_status == STATUS_DE_ENERGIZED]) == 8;
    assert _status_of(assets, "FAC-02") == STATUS_ALTERNATE_FEED;
    assert _status_of(assets, "SUB-02") == STATUS_NORMAL;
    assert snap.interrupted_load_mw == 100.0;
    assert snap.critical_interrupted == 1;
}

test "line scenario faults the west junction only" {
    assets = _build_network();
    _apply_scenario(assets, "line");
    snap = _snapshot(assets);
    assert snap.fault_id == "J-01";
    assert _ids(snap.downstream) == ["FAC-01", "FAC-02", "ZONE-01"];
    assert _status_of(assets, "TR-01") == STATUS_NORMAL;
    assert snap.interrupted_load_mw == 45.0;
}

test "applying a second scenario clears the first" {
    assets = _build_network();
    _apply_scenario(assets, "substation");
    _apply_scenario(assets, "line");
    assert len([n for n in assets if n.operational_status == STATUS_FAULT]) == 1;
    assert _status_of(assets, "SUB-01") == STATUS_NORMAL;
    assert _status_of(assets, "J-02") == STATUS_NORMAL;
    assert _status_of(assets, "J-01") == STATUS_FAULT;
}

test "unknown scenario is rejected without changing state" {
    assets = _build_network();
    _apply_scenario(assets, "transformer");
    raised = False;
    try { _apply_scenario(assets, "meteor"); } except ValueError { raised = True; }
    assert raised;
    assert _status_of(assets, "TR-01") == STATUS_FAULT;
}

test "reset restores the full baseline" {
    assets = _build_network();
    _apply_scenario(assets, "substation");
    assert not _all_normal(assets);
    _reset_assets(assets);
    assert _all_normal(assets);
    snap = _snapshot(assets);
    assert not snap.fault_active;
    assert snap.fault_label == "" and snap.fault_id == "" and snap.scenario_id == "";
    assert snap.downstream == [];
    assert snap.interrupted_load_mw == 0.0;
}

test "reset on a baseline network is a no-op" {
    assets = _build_network();
    _reset_assets(assets);
    assert _all_normal(assets);
    assert len(_link_views(assets)) == 14;
}
