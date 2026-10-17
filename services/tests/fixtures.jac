# Shared test helpers. Tests build their own transient network with
# build_network() and never touch root, so they are isolated from persisted
# dashboard state and from each other.

import from services.models { Infrastructure, DownstreamAsset, GraphSnapshot, STATUS_NORMAL }
import from services.scenarios { find_asset }
import from services.views { link_views }

def ids_of(items: list[DownstreamAsset]) -> list[str] {
    return [i.identifier for i in items];
}

def asset_by_id(assets: list[Infrastructure], identifier: str) -> Infrastructure {
    n = find_asset(assets, identifier);
    if n is None { raise AssertionError(f"missing asset {identifier}"); }
    return n;
}

def status_of(assets: list[Infrastructure], identifier: str) -> str {
    return asset_by_id(assets, identifier).operational_status;
}

def link_status(snap: GraphSnapshot, identifier: str) -> str {
    for l in snap.links { if l.identifier == identifier { return l.operational_status; } }
    raise AssertionError(f"missing link {identifier}");
}

def all_normal(assets: list[Infrastructure]) -> bool {
    for l in link_views(assets) { if l.operational_status != STATUS_NORMAL { return False; } }
    for n in assets { if n.operational_status != STATUS_NORMAL { return False; } }
    return True;
}
