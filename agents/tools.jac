# Deterministic tools the agents call. Every number an agent reports comes from here.
#
# get_asset, list_scenarios, trace_downstream_ids, impact_totals and
# incident_evidence wrap services/. The recovery planner (plan_recovery,
# check_option and helpers) now lives in services/recovery.jac and is
# re-exported here unchanged.

import from services.models {
    Infrastructure, PowerLink, DownstreamAsset, GraphSnapshot, Scenario, Incident, Evidence,
    RecoveryAction, ConstraintCheck, RecoveryOption, RecoveryPlan,
    STATUS_NORMAL, STATUS_FAULT, STATUS_ALTERNATE_FEED, STATUS_DE_ENERGIZED
}
import from services.scenarios { SCENARIOS, find_asset, fault_node }
import from services.walkers { compute_downstream }
import from services.views { snapshot }
import from services.incidents { evidence_of }
import from services.recovery {
    Hop, RestorationPath, PRIORITY_CRITICALITY, find_restoration_path, is_isolation, path_links, donor_of,
    plan_recovery, check_option
}


def get_asset(assets: list[Infrastructure], asset_id: str) -> Infrastructure | None {
    return find_asset(assets, asset_id);
}

def list_scenarios() -> list[Scenario] {
    return SCENARIOS;
}

def trace_downstream_ids(assets: list[Infrastructure], origin_id: str) -> list[DownstreamAsset] {
    origin = find_asset(assets, origin_id);
    if origin is None { raise ValueError(f"Unknown asset: {origin_id}"); }
    return compute_downstream(assets, origin);
}

def impact_totals(assets: list[Infrastructure]) -> GraphSnapshot {
    return snapshot(assets);
}

def incident_evidence(incident: Incident) -> list[Evidence] {
    return evidence_of(incident);
}
