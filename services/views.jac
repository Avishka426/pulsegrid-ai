# Read models returned to clients: link views and the graph snapshot.

import from .models { Infrastructure, PowerLink, LinkView, GraphSnapshot }
import from .walkers { compute_downstream }
import from .scenarios { find_asset, fault_node, scenario_for_target }

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
