# Server endpoints for the synthetic network. Graph logic lives in the sibling
# modules; the archetypes are re-exported here for client imports.

import from .models { Infrastructure, PowerLink, LinkView, DownstreamAsset, GraphSnapshot }
import from .seed { network_assets }
import from .scenarios { fault_node, mark_fault, apply_scenario, reset_assets }
import from .views { snapshot }

def:pub read_graph() -> GraphSnapshot {
    assets = network_assets();
    fault = fault_node(assets);
    # Re-derive downstream statuses so state saved by earlier versions stays consistent.
    if fault is not None { mark_fault(assets, fault); }
    return snapshot(assets);
}

def:pub apply_fault(scenario_id: str) -> GraphSnapshot {
    assets = network_assets();
    apply_scenario(assets, scenario_id);
    return snapshot(assets);
}

def:pub reset_graph() -> GraphSnapshot {
    assets = network_assets();
    reset_assets(assets);
    return snapshot(assets);
}
