# Deterministic seed for the 14-asset synthetic distribution network.

import from .models { Infrastructure, PowerLink, SOURCE_CATEGORY, NETWORK_SIZE, STATUS_FAULT }

def build_network() -> list[Infrastructure] {
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

# Seeds the network on first use. Assets stored before the services/ split
# keep their old type name: the aliases in models.jac let them load, but typed
# queries skip them, so a legacy network is replaced once (keeping any
# simulated fault) instead of being left unreachable.
def ensure_network() -> None {
    stored = [n for n in [root -->] if isinstance(n, Infrastructure)];
    current = [root -->][?:Infrastructure];
    if len(current) >= NETWORK_SIZE and len(stored) == len(current) { return; }
    fault_id = "";
    for n in stored { if fault_id == "" and n.operational_status == STATUS_FAULT { fault_id = n.identifier; } }
    for n in stored { del n; }
    fresh = build_network();
    root ++> fresh;
    for n in fresh { if n.identifier == fault_id { n.operational_status = STATUS_FAULT; } }
}

# The persisted network on the caller's root, seeding it on first use.
def network_assets() -> list[Infrastructure] {
    ensure_network();
    return [root -->][?:Infrastructure];
}
