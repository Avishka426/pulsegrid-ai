# Deterministic seed for the 14-asset synthetic distribution network.

import from .models { Infrastructure, PowerLink, SOURCE_CATEGORY, NETWORK_SIZE, STATUS_FAULT }

# Links as (identifier, from, to, capacity_mw), in creation order.
glob LINKS: list[tuple[str, str, str, float]] = [
    ("L-01", "SRC-01", "SUB-01", 180.0),
    ("L-02", "SRC-01", "SUB-02", 140.0),
    ("L-03", "SUB-01", "TR-01", 90.0),
    ("L-04", "SUB-01", "TR-02", 80.0),
    ("L-05", "SUB-02", "TR-03", 75.0),
    ("L-06", "TR-01", "J-01", 65.0),
    ("L-07", "TR-02", "J-02", 70.0),
    ("L-08", "TR-03", "J-03", 55.0),
    ("L-09", "J-01", "FAC-01", 30.0),
    ("L-10", "J-01", "FAC-02", 24.0),
    ("L-11", "J-01", "ZONE-01", 48.0),
    ("L-12", "J-02", "FAC-03", 42.0),
    ("L-13", "J-02", "ZONE-02", 46.0),
    ("L-14", "J-03", "FAC-02", 25.0)
];

def build_assets() -> list[Infrastructure] {
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
    return [source, sub_a, sub_b, tr_a, tr_b, tr_c, junction_a, junction_b, junction_c, hospital, water, homes, industry, homes_east];
}

def connect_network(assets: list[Infrastructure]) -> None {
    by_id: dict[str, Infrastructure] = {};
    for n in assets { by_id[n.identifier] = n; }
    for (link_id, src, dst, capacity) in LINKS {
        by_id[src] +>:PowerLink(identifier=link_id, capacity_mw=capacity):+> by_id[dst];
    }
}

# A transient copy of the network, for tests and analysis.
def build_network() -> list[Infrastructure] {
    assets = build_assets();
    connect_network(assets);
    return assets;
}

# Seeds the network on first use. Nodes are attached to root before they are
# linked: on Jac 0.34, links made between transient nodes that are attached
# afterwards are stored but cannot be traversed. A network that is incomplete
# (missing nodes or untraversable links) or stored under an older type name,
# which typed queries skip, is replaced once, keeping any simulated fault.
def ensure_network() -> None {
    stored = [n for n in [root -->] if isinstance(n, Infrastructure)];
    current = [root -->][?:Infrastructure];
    links = 0;
    for n in current { links = links + len([n ->:PowerLink:->]); }
    if len(current) >= NETWORK_SIZE and len(stored) == len(current) and links >= len(LINKS) { return; }
    fault_id = "";
    for n in stored { if fault_id == "" and n.operational_status == STATUS_FAULT { fault_id = n.identifier; } }
    for n in stored { del n; }
    fresh = build_assets();
    root ++> fresh;
    connect_network(fresh);
    for n in fresh { if n.identifier == fault_id { n.operational_status = STATUS_FAULT; } }
}

# The persisted network on the caller's root, seeding it on first use.
def network_assets() -> list[Infrastructure] {
    ensure_network();
    return [root -->][?:Infrastructure];
}
