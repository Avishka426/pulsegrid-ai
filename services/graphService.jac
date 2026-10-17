# Server endpoints for the synthetic network. Graph logic lives in the sibling
# modules; the archetypes are re-exported here for client imports.

import from .models {
    Infrastructure, PowerLink, LinkView, DownstreamAsset, GraphSnapshot, Incident, Evidence,
    RecoveryAction, ConstraintCheck, RecoveryOption, RecoveryPlan,
    ScenarioInfo, ScenarioPreview, IncidentDetail
}
import from .seed { network_assets }
import from .scenarios { find_scenario, fault_node, mark_fault, apply_scenario, reset_assets }
import from .views { snapshot, scenario_infos, preview }
import from .incidents { stored_incidents, active_incident, open_incident, resolve_active_incident, evidence_of, incident_detail }

# Snapshot of the network plus the active incident, if any.
def _current_snapshot(assets: list[Infrastructure]) -> GraphSnapshot {
    snap = snapshot(assets);
    incident = active_incident();
    if incident is not None and snap.fault_active {
        snap.incident_id = incident.identifier;
        snap.evidence = evidence_of(incident);
    }
    return snap;
}

def:pub read_graph() -> GraphSnapshot {
    assets = network_assets();
    fault = fault_node(assets);
    # Re-derive downstream statuses so state saved by earlier versions stays consistent.
    if fault is not None { mark_fault(assets, fault); }
    return _current_snapshot(assets);
}

def:pub apply_fault(scenario_id: str) -> GraphSnapshot {
    assets = network_assets();
    target = apply_scenario(assets, scenario_id);
    scenario = find_scenario(scenario_id);
    if scenario is not None { open_incident(assets, scenario, target); }
    return _current_snapshot(assets);
}

def:pub reset_graph() -> GraphSnapshot {
    assets = network_assets();
    reset_assets(assets);
    resolve_active_incident();
    return _current_snapshot(assets);
}

# Recorded incidents, newest first (at most INCIDENT_HISTORY_LIMIT).
def:pub list_incidents() -> list[Incident] {
    return stored_incidents();
}

# The three scenarios with their target assets.
def:pub list_scenarios() -> list[ScenarioInfo] {
    return scenario_infos();
}

# A scenario's impact without applying it; the stored graph is not changed.
def:pub preview_scenario(scenario_id: str) -> ScenarioPreview {
    return preview(scenario_id);
}

# One recorded incident with its evidence, or None if it is not stored.
def:pub get_incident(identifier: str) -> IncidentDetail | None {
    return incident_detail(identifier);
}
