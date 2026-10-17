node Infrastructure {
    has identifier: str;
    has display_name: str;
    has category: str;
    has capacity_mw: float = 0.0;
    has load_mw: float = 0.0;
    has operational_status: str = "normal";
    has criticality: int = 1;
}

edge PowerLink: Infrastructure --> Infrastructure {
    has identifier: str;
    has capacity_mw: float = 0.0;
    has operational_status: str = "normal";
}

obj LinkView {
    has identifier: str;
    has source: str;
    has target: str;
    has capacity_mw: float = 0.0;
    has operational_status: str = "normal";
}

obj DownstreamAsset {
    has identifier: str;
    has display_name: str;
    has category: str;
    has hops: int = 0;
    has load_mw: float = 0.0;
    has criticality: int = 1;
    has alternate_feed: bool = False;
}

obj GraphSnapshot {
    has nodes: list[Infrastructure] = [];
    has links: list[LinkView] = [];
    has fault_active: bool = False;
    has fault_label: str = "";
    has fault_id: str = "";
    has scenario_id: str = "";
    has scenario_title: str = "";
    has downstream: list[DownstreamAsset] = [];
    has interrupted_load_mw: float = 0.0;
    has critical_interrupted: int = 0;
}

obj Scenario {
    has identifier: str;
    has title: str;
    has target_id: str;
}

glob STATUS_NORMAL: str = "normal";
glob STATUS_FAULT: str = "fault";
glob STATUS_DE_ENERGIZED: str = "de-energized";
glob STATUS_ALTERNATE_FEED: str = "alternate-feed";
glob SOURCE_CATEGORY: str = "Power source";
glob NETWORK_SIZE: int = 14;

# Each scenario faults one explicit, stable asset of the synthetic network.
glob SCENARIOS: list[Scenario] = [
    Scenario(identifier="transformer", title="Transformer Overheating", target_id="TR-01"),
    Scenario(identifier="substation", title="Substation Failure", target_id="SUB-01"),
    Scenario(identifier="line", title="Distribution Line Overload", target_id="J-01")
];

# Breadth-first walk along outgoing PowerLinks. Each asset is recorded once with
# its minimum hop count, so assets with several feeders are not double counted.
# Assets listed in blocked_ids are never entered.
walker DownstreamTrace {
    has blocked_ids: list[str] = [];
    has hops: dict[str, int] = {};
    has reached: list[Infrastructure] = [];

    can trace with Infrastructure entry {
        if here.identifier not in self.hops { self.hops[here.identifier] = 0; }
        depth = self.hops[here.identifier];
        for nxt in [here ->:PowerLink:->] {
            if nxt.identifier in self.hops or nxt.identifier in self.blocked_ids { continue; }
            self.hops[nxt.identifier] = depth + 1;
            self.reached.append(nxt);
            visit nxt;
        }
    }
}

def _build_network() -> list[Infrastructure] {
    source = Infrastructure(identifier="SRC-01", display_name="North Generation", category=SOURCE_CATEGORY, capacity_mw=240.0, load_mw=162.0, criticality=5);
    sub_a = Infrastructure(identifier="SUB-01", display_name="Central Substation", category="Substation", capacity_mw=180.0, load_mw=128.0, criticality=5);
    sub_b = Infrastructure(identifier="SUB-02", display_name="Harbor Substation", category="Substation", capacity_mw=140.0, load_mw=92.0, criticality=4);
    tr_a = Infrastructure(identifier="TR-01", display_name="Central Transformer A", category="Transformer", capacity_mw=90.0, load_mw=72.0, criticality=4);
    tr_b = Infrastructure(identifier="TR-02", display_name="Central Transformer B", category="Transformer", capacity_mw=80.0, load_mw=51.0, criticality=3);
    tr_c = Infrastructure(identifier="TR-03", display_name="Harbor Transformer", category="Transformer", capacity_mw=75.0, load_mw=49.0, criticality=3);
    junction_a = Infrastructure(identifier="J-01", display_name="West Junction", category="Distribution junction", capacity_mw=65.0, load_mw=38.0, criticality=2);
    junction_b = Infrastructure(identifier="J-02", display_name="East Junction", category="Distribution junction", capacity_mw=70.0, load_mw=43.0, criticality=2);
    junction_c = Infrastructure(identifier="J-03", display_name="Harbor Junction", category="Distribution junction", capacity_mw=55.0, load_mw=31.0, criticality=2);
    hospital = Infrastructure(identifier="FAC-01", display_name="Civic Hospital", category="Hospital", capacity_mw=30.0, load_mw=18.0, criticality=5);
    water = Infrastructure(identifier="FAC-02", display_name="Water Works", category="Water pumping station", capacity_mw=24.0, load_mw=14.0, criticality=5);
    homes = Infrastructure(identifier="ZONE-01", display_name="West Residential", category="Residential zone", capacity_mw=48.0, load_mw=27.0, criticality=2);
    industry = Infrastructure(identifier="FAC-03", display_name="Industrial Park", category="Industrial facility", capacity_mw=42.0, load_mw=29.0, criticality=3);
    homes_east = Infrastructure(identifier="ZONE-02", display_name="East Residential", category="Residential zone", capacity_mw=46.0, load_mw=26.0, criticality=2);
    source +>:PowerLink(identifier="L-01", capacity_mw=180.0):+> sub_a;
    source +>:PowerLink(identifier="L-02", capacity_mw=140.0):+> sub_b;
    sub_a +>:PowerLink(identifier="L-03", capacity_mw=90.0):+> tr_a;
    sub_a +>:PowerLink(identifier="L-04", capacity_mw=80.0):+> tr_b;
    sub_b +>:PowerLink(identifier="L-05", capacity_mw=75.0):+> tr_c;
    tr_a +>:PowerLink(identifier="L-06", capacity_mw=65.0):+> junction_a;
    tr_b +>:PowerLink(identifier="L-07", capacity_mw=70.0):+> junction_b;
    tr_c +>:PowerLink(identifier="L-08", capacity_mw=55.0):+> junction_c;
    junction_a +>:PowerLink(identifier="L-09", capacity_mw=30.0):+> hospital;
    junction_a +>:PowerLink(identifier="L-10", capacity_mw=24.0):+> water;
    junction_a +>:PowerLink(identifier="L-11", capacity_mw=48.0):+> homes;
    junction_b +>:PowerLink(identifier="L-12", capacity_mw=42.0):+> industry;
    junction_b +>:PowerLink(identifier="L-13", capacity_mw=46.0):+> homes_east;
    junction_c +>:PowerLink(identifier="L-14", capacity_mw=25.0):+> water;
    return [source, sub_a, sub_b, tr_a, tr_b, tr_c, junction_a, junction_b, junction_c, hospital, water, homes, industry, homes_east];
}

def _ensure_network() -> None {
    existing = [root -->][?:Infrastructure];
    if len(existing) >= NETWORK_SIZE { return; }
    for n in existing { del n; }
    root ++> _build_network();
}

def _assets() -> list[Infrastructure] {
    _ensure_network();
    return [root -->][?:Infrastructure];
}

def _find_asset(assets: list[Infrastructure], identifier: str) -> Infrastructure | None {
    for n in assets { if n.identifier == identifier { return n; } }
    return None;
}

def _find_scenario(scenario_id: str) -> Scenario | None {
    for s in SCENARIOS { if s.identifier == scenario_id { return s; } }
    return None;
}

def _scenario_for_target(target_id: str) -> Scenario | None {
    for s in SCENARIOS { if s.target_id == target_id { return s; } }
    return None;
}

def _fault_node(assets: list[Infrastructure]) -> Infrastructure | None {
    for n in assets { if n.operational_status == STATUS_FAULT { return n; } }
    return None;
}

def trace_downstream(origin: Infrastructure, blocked_ids: list[str]) -> DownstreamTrace {
    return origin spawn DownstreamTrace(blocked_ids=blocked_ids);
}

# Identifiers of assets that a power source can still reach without passing
# through the faulted asset.
def _supplied_ids(assets: list[Infrastructure], fault_id: str) -> list[str] {
    supplied: list[str] = [];
    for src in assets {
        if src.category != SOURCE_CATEGORY or src.identifier == fault_id { continue; }
        if src.identifier not in supplied { supplied.append(src.identifier); }
        for n in trace_downstream(src, [fault_id]).reached {
            if n.identifier not in supplied { supplied.append(n.identifier); }
        }
    }
    return supplied;
}

def compute_downstream(assets: list[Infrastructure], fault: Infrastructure) -> list[DownstreamAsset] {
    trace = trace_downstream(fault, []);
    supplied = _supplied_ids(assets, fault.identifier);
    impact: list[DownstreamAsset] = [];
    for n in trace.reached {
        impact.append(DownstreamAsset(identifier=n.identifier, display_name=n.display_name, category=n.category, hops=trace.hops[n.identifier], load_mw=n.load_mw, criticality=n.criticality, alternate_feed=(n.identifier in supplied)));
    }
    return impact;
}

def _reset_assets(assets: list[Infrastructure]) -> None {
    for n in assets {
        n.operational_status = STATUS_NORMAL;
        for e in [edge n ->:PowerLink:->] { e.operational_status = STATUS_NORMAL; }
    }
}

# Resets the network, faults `target`, then marks every downstream asset as
# de-energized or alternate-feed and the links leaving de-energized assets.
def _mark_fault(assets: list[Infrastructure], target: Infrastructure) -> None {
    _reset_assets(assets);
    target.operational_status = STATUS_FAULT;
    for e in [edge target ->:PowerLink:->] { e.operational_status = STATUS_FAULT; }
    for item in compute_downstream(assets, target) {
        n = _find_asset(assets, item.identifier);
        if n is None { continue; }
        if item.alternate_feed {
            n.operational_status = STATUS_ALTERNATE_FEED;
        } else {
            n.operational_status = STATUS_DE_ENERGIZED;
            for e in [edge n ->:PowerLink:->] { e.operational_status = STATUS_DE_ENERGIZED; }
        }
    }
}

def _apply_scenario(assets: list[Infrastructure], scenario_id: str) -> Infrastructure {
    scenario = _find_scenario(scenario_id);
    if scenario is None { raise ValueError(f"Unknown scenario: {scenario_id}"); }
    target = _find_asset(assets, scenario.target_id);
    if target is None { raise ValueError(f"Scenario target {scenario.target_id} is not in the network"); }
    _mark_fault(assets, target);
    return target;
}

def _link_views(assets: list[Infrastructure]) -> list[LinkView] {
    views: list[LinkView] = [];
    for n in assets {
        for target in [n ->:PowerLink:->] {
            for e in [edge n ->:PowerLink:-> target] {
                views.append(LinkView(identifier=e.identifier, source=n.identifier, target=target.identifier, capacity_mw=e.capacity_mw, operational_status=e.operational_status));
            }
        }
    }
    return views;
}

def _snapshot(assets: list[Infrastructure]) -> GraphSnapshot {
    snap = GraphSnapshot(nodes=assets, links=_link_views(assets));
    fault = _fault_node(assets);
    if fault is None { return snap; }
    snap.fault_active = True;
    snap.fault_label = fault.display_name;
    snap.fault_id = fault.identifier;
    scenario = _scenario_for_target(fault.identifier);
    if scenario is not None {
        snap.scenario_id = scenario.identifier;
        snap.scenario_title = scenario.title;
    }
    snap.downstream = compute_downstream(assets, fault);
    if len([fault ->:PowerLink:->]) == 0 {
        snap.interrupted_load_mw = fault.load_mw;
        if fault.criticality >= 4 { snap.critical_interrupted = 1; }
    }
    for item in snap.downstream {
        n = _find_asset(assets, item.identifier);
        # Only end-use assets (no outgoing links) count toward interrupted load,
        # so pass-through equipment load is not double counted.
        if item.alternate_feed or n is None or len([n ->:PowerLink:->]) > 0 { continue; }
        snap.interrupted_load_mw = snap.interrupted_load_mw + item.load_mw;
        if item.criticality >= 4 { snap.critical_interrupted = snap.critical_interrupted + 1; }
    }
    return snap;
}

def:pub read_graph() -> GraphSnapshot {
    assets = _assets();
    fault = _fault_node(assets);
    # Re-derive downstream statuses so state saved by earlier versions stays consistent.
    if fault is not None { _mark_fault(assets, fault); }
    return _snapshot(assets);
}

def:pub apply_fault(scenario_id: str) -> GraphSnapshot {
    assets = _assets();
    _apply_scenario(assets, scenario_id);
    return _snapshot(assets);
}

def:pub reset_graph() -> GraphSnapshot {
    assets = _assets();
    _reset_assets(assets);
    return _snapshot(assets);
}
