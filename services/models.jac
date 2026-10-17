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
