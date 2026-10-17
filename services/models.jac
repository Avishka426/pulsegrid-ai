# Graph archetypes, view objects and shared constants for the synthetic network.

# Aliases keep graphs persisted before the services/ split loadable.
@archetype_alias("jac:[\"pulsegrid-ai\",\"services.graphService\"].Infrastructure")
node Infrastructure {
    has identifier: str;
    has display_name: str;
    has category: str;
    has capacity_mw: float = 0.0;
    has load_mw: float = 0.0;
    has operational_status: str = "normal";
    has criticality: int = 1;
}

@archetype_alias("jac:[\"pulsegrid-ai\",\"services.graphService\"].PowerLink")
edge PowerLink: Infrastructure --> Infrastructure {
    has identifier: str;
    has capacity_mw: float = 0.0;
    has operational_status: str = "normal";
}

# One fault-simulation run. Identifiers come from a per-graph sequence counter,
# never the wall clock, so runs are reproducible.
node Incident {
    has identifier: str;
    has sequence: int;
    has scenario_id: str;
    has scenario_title: str;
    has fault_id: str;
    has status: str = "active";
    has applied_option_id: str = "";
}

# A fact recorded from deterministic graph analysis, citable by identifier.
# `kind` reuses the asset status values: fault, de-energized, alternate-feed.
node Evidence {
    has identifier: str;
    has kind: str;
    has asset_id: str;
    has detail: str;
    has hops: int = 0;
    has value_mw: float = 0.0;
}

edge HasEvidence: Incident --> Evidence {}

# Recovery-planning contract. Producers arrive with deterministic recovery
# planning; nothing returns these objects yet.
obj RecoveryAction {
    has identifier: str;
    has kind: str;
    has description: str;
    has from_asset: str = "";
    has to_asset: str = "";
    has link_id: str = "";
    has restores: list[str] = [];
    has transfer_mw: float = 0.0;
}

obj ConstraintCheck {
    has name: str;
    has passed: bool;
    has detail: str = "";
}

obj RecoveryOption {
    has identifier: str;
    has actions: list[RecoveryAction] = [];
    has restored_assets: list[str] = [];
    has restored_load_mw: float = 0.0;
    has critical_restored: int = 0;
    has checks: list[ConstraintCheck] = [];
    has feasible: bool = False;
    has rejection_reason: str = "";
}

obj RecoveryPlan {
    has fault_id: str;
    has options: list[RecoveryOption] = [];
    has recommended_id: str = "";
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
    has incident_id: str = "";
    has evidence: list[Evidence] = [];
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
glob INCIDENT_ACTIVE: str = "active";
glob INCIDENT_SUPERSEDED: str = "superseded";
glob INCIDENT_RESOLVED: str = "resolved";
glob INCIDENT_HISTORY_LIMIT: int = 20;
glob SOURCE_CATEGORY: str = "Power source";
glob NETWORK_SIZE: int = 14;
