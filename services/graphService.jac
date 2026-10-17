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

obj GraphSnapshot {
    has nodes: list[Infrastructure] = [];
    has links: list[dict] = [];
    has fault_active: bool = False;
    has fault_label: str = "";
}

obj Scenario {
    has identifier: str;
    has title: str;
    has target_category: str;
}

glob SCENARIOS: list[Scenario] = [
    Scenario(identifier="transformer", title="Transformer Overheating", target_category="Transformer"),
    Scenario(identifier="substation", title="Substation Failure", target_category="Substation"),
    Scenario(identifier="line", title="Distribution Line Overload", target_category="Distribution junction")
];

def _ensure_network() -> None {
    existing = [root -->][?:Infrastructure];
    if len(existing) >= 14 { return; }
    if len(existing) > 0 { for n in existing { del n; } }
    source = root ++> Infrastructure(identifier="SRC-01", display_name="North Generation", category="Power source", capacity_mw=240.0, load_mw=162.0, criticality=5);
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
    root ++> [source, sub_a, sub_b, tr_a, tr_b, tr_c, junction_a, junction_b, junction_c, hospital, water, homes, industry, homes_east];
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
}

def:pub read_graph() -> GraphSnapshot {
    _ensure_network();
    nodes = [root -->][?:Infrastructure];
    link_views: list[dict] = [];
    for n in nodes {
        for e in [edge n ->:PowerLink:->] {
            targets = [n ->:PowerLink:->];
            for target in targets {
                if e.operational_status == "normal" or e.operational_status == "fault" {
                    link_views = link_views + [{"id": e.identifier, "source": n.identifier, "target": target.identifier, "capacity": e.capacity_mw, "status": e.operational_status}];
                }
            }
        }
    }
    fault = "";
    for n in nodes { if n.operational_status == "fault" { fault = n.display_name; } }
    return GraphSnapshot(nodes=nodes, links=link_views, fault_active=(len(fault) > 0), fault_label=fault);
}

def:pub apply_fault(scenario_id: str) -> GraphSnapshot {
    _ensure_network();
    reset_graph();
    category = "Transformer" if scenario_id == "transformer" else "Substation" if scenario_id == "substation" else "Distribution junction";
    nodes = [root -->][?:Infrastructure];
    selected = False;
    for n in nodes {
        if n.category == category and not selected {
            n.operational_status = "fault";
            selected = True;
            for e in [edge n ->:PowerLink:->] { e.operational_status = "fault"; }
        }
    }
    return read_graph();
}

def:pub reset_graph() -> GraphSnapshot {
    _ensure_network();
    for n in [root -->][?:Infrastructure] { n.operational_status = "normal"; }
    for n in [root -->][?:Infrastructure] { for e in [edge n ->:PowerLink:->] { e.operational_status = "normal"; } }
    return read_graph();
}
