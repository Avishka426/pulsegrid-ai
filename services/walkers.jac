# Deterministic graph traversal over PowerLinks.

import from .models { Infrastructure, PowerLink, DownstreamAsset, SOURCE_CATEGORY }

# Breadth-first walk along outgoing PowerLinks. Each asset is recorded once with
# its minimum hop count, so assets with several feeders are not double counted.
# Assets listed in blocked_ids are never entered.
walker DownstreamTrace {
    has blocked_ids: list[str] = [];
    has hops: dict[str, int] = {};
    has reached: list[Infrastructure] = [];

    can trace with Infrastructure entry {
        if here.identifier not in self.hops { self.hops[here.identifier] = 0; }
        depth = self.hops[here.identifier];
        for nxt in [here ->:PowerLink:->] {
            if nxt.identifier in self.hops or nxt.identifier in self.blocked_ids { continue; }
            self.hops[nxt.identifier] = depth + 1;
            self.reached.append(nxt);
            visit nxt;
        }
    }
}

def trace_downstream(origin: Infrastructure, blocked_ids: list[str]) -> DownstreamTrace {
    return origin spawn DownstreamTrace(blocked_ids=blocked_ids);
}

# Identifiers of assets that a power source can still reach without passing
# through the faulted asset.
def supplied_ids(assets: list[Infrastructure], fault_id: str) -> list[str] {
    supplied: list[str] = [];
    for src in assets {
        if src.category != SOURCE_CATEGORY or src.identifier == fault_id { continue; }
        if src.identifier not in supplied { supplied.append(src.identifier); }
        for n in trace_downstream(src, [fault_id]).reached {
            if n.identifier not in supplied { supplied.append(n.identifier); }
        }
    }
    return supplied;
}

def compute_downstream(assets: list[Infrastructure], fault: Infrastructure) -> list[DownstreamAsset] {
    trace = trace_downstream(fault, []);
    supplied = supplied_ids(assets, fault.identifier);
    impact: list[DownstreamAsset] = [];
    for n in trace.reached {
        impact.append(DownstreamAsset(identifier=n.identifier, display_name=n.display_name, category=n.category, hops=trace.hops[n.identifier], load_mw=n.load_mw, criticality=n.criticality, alternate_feed=(n.identifier in supplied)));
    }
    return impact;
}
