# Read models returned to clients: link views and the graph snapshot.

import from .models { Infrastructure, PowerLink, LinkView, GraphSnapshot, ScenarioInfo, ScenarioPreview }
import from .walkers { compute_downstream }
import from .seed { build_network }
import from .scenarios { SCENARIOS, find_asset, fault_node, scenario_for_target, apply_scenario }

def link_views(assets: list[Infrastructure]) -> list[LinkView] {
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

def snapshot(assets: list[Infrastructure]) -> GraphSnapshot {
    snap = GraphSnapshot(nodes=assets, links=link_views(assets));
    fault = fault_node(assets);
    if fault is None { return snap; }
    snap.fault_active = True;
    snap.fault_label = fault.display_name;
    snap.fault_id = fault.identifier;
    scenario = scenario_for_target(fault.identifier);
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
        n = find_asset(assets, item.identifier);
        # Only end-use assets (no outgoing links) count toward interrupted load,
        # so pass-through equipment load is not double counted.
        if item.alternate_feed or n is None or len([n ->:PowerLink:->]) > 0 { continue; }
        snap.interrupted_load_mw = snap.interrupted_load_mw + item.load_mw;
        if item.criticality >= 4 { snap.critical_interrupted = snap.critical_interrupted + 1; }
    }
    return snap;
}

def scenario_infos() -> list[ScenarioInfo] {
    assets = build_network();
    infos: list[ScenarioInfo] = [];
    for s in SCENARIOS {
        target = find_asset(assets, s.target_id);
        name = target.display_name if target is not None else "";
        category = target.category if target is not None else "";
        infos.append(ScenarioInfo(identifier=s.identifier, title=s.title, target_id=s.target_id, target_name=name, target_category=category));
    }
    return infos;
}

# Applies the scenario to a transient copy of the network, so the stored graph
# is left untouched. Raises ValueError for an unknown scenario.
def preview(scenario_id: str) -> ScenarioPreview {
    assets = build_network();
    target = apply_scenario(assets, scenario_id);
    snap = snapshot(assets);
    alternate = 0;
    for d in snap.downstream { if d.alternate_feed { alternate = alternate + 1; } }
    return ScenarioPreview(scenario_id=snap.scenario_id, title=snap.scenario_title, target_id=target.identifier, target_name=target.display_name, downstream=snap.downstream, de_energized=len(snap.downstream) - alternate, alternate_feed=alternate, interrupted_load_mw=snap.interrupted_load_mw, critical_interrupted=snap.critical_interrupted);
}
