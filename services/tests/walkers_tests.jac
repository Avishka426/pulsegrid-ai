import from services.seed { build_network }
import from services.walkers { trace_downstream, compute_downstream }
import from services.tests.fixtures { ids_of, asset_by_id }

test "transformer trace reaches its junction and facilities in BFS order" {
    assets = build_network();
    impact = compute_downstream(assets, asset_by_id(assets, "TR-01"));
    assert ids_of(impact) == ["J-01", "FAC-01", "FAC-02", "ZONE-01"];
    assert [i.hops for i in impact] == [1, 2, 2, 2];
}

test "substation trace reaches both transformer branches" {
    assets = build_network();
    impact = compute_downstream(assets, asset_by_id(assets, "SUB-01"));
    assert ids_of(impact) == ["TR-01", "TR-02", "J-01", "J-02", "FAC-01", "FAC-02", "ZONE-01", "FAC-03", "ZONE-02"];
    assert [i.hops for i in impact] == [1, 1, 2, 2, 3, 3, 3, 3, 3];
    for i in impact { assert "SUB-02" != i.identifier and "J-03" != i.identifier; }
}

test "source trace visits every asset with two feeders once" {
    assets = build_network();
    trace = trace_downstream(asset_by_id(assets, "SRC-01"), []);
    ids = [n.identifier for n in trace.reached];
    assert len(ids) == 13;
    assert len(set(ids)) == 13;
    assert ids.count("FAC-02") == 1;
    assert "SRC-01" not in ids;
}

test "end-use asset has no downstream assets" {
    assets = build_network();
    assert compute_downstream(assets, asset_by_id(assets, "FAC-01")) == [];
}

test "blocked assets stop the traversal" {
    assets = build_network();
    trace = trace_downstream(asset_by_id(assets, "SRC-01"), ["SUB-01"]);
    ids = [n.identifier for n in trace.reached];
    assert ids == ["SUB-02", "TR-03", "J-03", "FAC-02"];
}

test "traversal is deterministic across runs and fresh networks" {
    a = build_network();
    b = build_network();
    first = ids_of(compute_downstream(a, asset_by_id(a, "SUB-01")));
    assert len(first) == 9;
    assert ids_of(compute_downstream(a, asset_by_id(a, "SUB-01"))) == first;
    assert ids_of(compute_downstream(b, asset_by_id(b, "SUB-01"))) == first;
}

test "alternate feed is detected only where another supply path exists" {
    assets = build_network();
    tr = compute_downstream(assets, asset_by_id(assets, "TR-01"));
    assert [i.identifier for i in tr if i.alternate_feed] == ["FAC-02"];
    src = compute_downstream(assets, asset_by_id(assets, "SRC-01"));
    assert [i.identifier for i in src if i.alternate_feed] == [];
}
