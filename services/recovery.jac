# Deterministic recovery planning over the synthetic graph: restoration paths
# around the faulted asset, candidate options, independent constraint checks,
# verification and ranking. Every number comes from the graph; no model is
# involved. Moved here from agents/tools.jac (written by Member 2), which
# re-exports these names for the agents.

import from .models {
    Infrastructure, PowerLink, Incident,
    RecoveryAction, ConstraintCheck, RecoveryOption, RecoveryPlan,
    STATUS_NORMAL, STATUS_FAULT, STATUS_ALTERNATE_FEED, STATUS_DE_ENERGIZED,
    ACTION_BACKFEED, ACTION_ISOLATE
}
import from .scenarios { find_asset, fault_node }

glob PRIORITY_CRITICALITY: int = 4;

def _energized(n: Infrastructure) -> bool {
    return n.operational_status == STATUS_NORMAL or n.operational_status == STATUS_ALTERNATE_FEED;
}

def _is_leaf(n: Infrastructure) -> bool {
    return len([n ->:PowerLink:->]) == 0;
}

def _key(n: Infrastructure) -> str { return n.identifier; }

obj Hop {
    has asset_id: str;
    has link_id: str;
}

obj RestorationPath {
    has target_id: str;
    has donor_id: str = "";
    has hops: list[Hop] = [];
    has found: bool = False;
}

# Neighbours over PowerLinks in either direction, in identifier order.
def _neighbours(n: Infrastructure) -> list[Hop] {
    out: list[Hop] = [];
    for nb in sorted([n ->:PowerLink:->], key=_key) {
        for e in [edge n ->:PowerLink:-> nb] { out.append(Hop(asset_id=nb.identifier, link_id=e.identifier)); }
    }
    for nb in sorted([n <-:PowerLink:<-], key=_key) {
        for e in [edge nb ->:PowerLink:-> n] { out.append(Hop(asset_id=nb.identifier, link_id=e.identifier)); }
    }
    return out;
}

# Shortest undirected path from an interrupted asset to the nearest energized
# asset, never passing through the faulted asset. Hops run target -> donor.
def find_restoration_path(assets: list[Infrastructure], target_id: str, fault_id: str) -> RestorationPath {
    result = RestorationPath(target_id=target_id);
    parent: dict[str, Hop] = {};
    queue: list[str] = [target_id];
    seen: list[str] = [target_id];
    while len(queue) > 0 {
        current_id = queue.pop(0);
        current = find_asset(assets, current_id);
        if current is None { continue; }
        if current_id != target_id and _energized(current) {
            result.found = True;
            result.donor_id = current_id;
            chain: list[Hop] = [];
            walk_id = current_id;
            while walk_id != target_id {
                step = parent[walk_id];
                chain.append(Hop(asset_id=walk_id, link_id=step.link_id));
                walk_id = step.asset_id;
            }
            chain.reverse();
            result.hops = chain;
            return result;
        }
        for nb in _neighbours(current) {
            if nb.asset_id == fault_id or nb.asset_id in seen { continue; }
            seen.append(nb.asset_id);
            parent[nb.asset_id] = Hop(asset_id=current_id, link_id=nb.link_id);
            queue.append(nb.asset_id);
        }
    }
    return result;
}

def _interrupted_leaves(assets: list[Infrastructure]) -> list[Infrastructure] {
    leaves = [n for n in assets if n.operational_status == STATUS_DE_ENERGIZED and _is_leaf(n)];
    return sorted(leaves, key=_key);
}

def is_isolation(option: RecoveryOption) -> bool {
    return any([a.kind == ACTION_ISOLATE for a in option.actions]);
}

def path_links(option: RecoveryOption) -> list[str] {
    links: list[str] = [];
    for a in option.actions {
        for l in a.link_id.split(",") { if l != "" and l not in links { links.append(l); } }
    }
    return links;
}

def donor_of(option: RecoveryOption) -> str {
    return option.actions[0].from_asset if len(option.actions) > 0 else "";
}

def _restore_option(assets: list[Infrastructure], fault_id: str, option_id: str, targets: list[Infrastructure]) -> RecoveryOption | None {
    option = RecoveryOption(identifier=option_id);
    for t in targets {
        path = find_restoration_path(assets, t.identifier, fault_id);
        if not path.found { continue; }
        links = [h.link_id for h in path.hops];
        option.actions.append(RecoveryAction(
            identifier=f"{option_id}-A{len(option.actions) + 1}", kind=ACTION_BACKFEED,
            description=f"Simulate back-feeding {t.identifier} from {path.donor_id} over {', '.join(links)}",
            from_asset=path.donor_id, to_asset=t.identifier, link_id=",".join(links),
            restores=[t.identifier], transfer_mw=t.load_mw
        ));
        option.restored_assets.append(t.identifier);
        option.restored_load_mw = option.restored_load_mw + t.load_mw;
        if t.criticality >= PRIORITY_CRITICALITY { option.critical_restored = option.critical_restored + 1; }
    }
    if len(option.actions) == 0 { return None; }
    return option;
}

# Options: restore every reachable interrupted end-use load (OPT-1), restore
# priority loads only (OPT-2, when that is a strict subset), keep the fault
# isolated (OPT-3). Options are unverified: checks and feasibility are filled
# by the Verification Agent.
def plan_recovery(assets: list[Infrastructure], incident: Incident) -> RecoveryPlan {
    plan = RecoveryPlan(fault_id=incident.fault_id);
    leaves = _interrupted_leaves(assets);
    all_opt = _restore_option(assets, incident.fault_id, "OPT-1", leaves);
    if all_opt is not None { plan.options.append(all_opt); }
    priority = [n for n in leaves if n.criticality >= PRIORITY_CRITICALITY];
    if len(priority) > 0 and len(priority) < len(leaves) {
        pri_opt = _restore_option(assets, incident.fault_id, "OPT-2", priority);
        if pri_opt is not None { plan.options.append(pri_opt); }
    }
    plan.options.append(RecoveryOption(identifier="OPT-3", actions=[
        RecoveryAction(identifier="OPT-3-A1", kind=ACTION_ISOLATE, description=f"Keep {incident.fault_id} isolated; interrupted loads stay unserved in the simulation", from_asset=incident.fault_id)
    ]));
    return plan;
}

def _link_ends(assets: list[Infrastructure], link_id: str) -> list[Infrastructure] {
    for n in assets {
        for nb in [n ->:PowerLink:->] {
            for e in [edge n ->:PowerLink:-> nb] { if e.identifier == link_id { return [n, nb]; } }
        }
    }
    return [];
}

def _link_by_id(assets: list[Infrastructure], link_id: str) -> PowerLink | None {
    for n in assets { for e in [edge n ->:PowerLink:->] { if e.identifier == link_id { return e; } } }
    return None;
}

# Load a link already carries: its downstream asset's load, while both ends are energized.
def _existing_flow(assets: list[Infrastructure], link_id: str) -> float {
    ends = _link_ends(assets, link_id);
    if len(ends) != 2 or not _energized(ends[0]) or not _energized(ends[1]) { return 0.0; }
    return ends[1].load_mw;
}

def _supply_link(donor: Infrastructure) -> PowerLink | None {
    for parent in sorted([donor <-:PowerLink:<-], key=_key) {
        if not _energized(parent) { continue; }
        for e in [edge parent ->:PowerLink:-> donor] { return e; }
    }
    return None;
}

def _limit_check(name: str, observed: float, limit: float, what: str) -> ConstraintCheck {
    return ConstraintCheck(name=name, passed=observed <= limit, detail=f"{what}: {observed:g} MW needed, {limit:g} MW available");
}

# Recomputes the option's paths and flows from the graph and checks every limit.
# Check names are "<rule>:<subject>", e.g. "link_capacity:L-10".
def check_option(assets: list[Infrastructure], option: RecoveryOption) -> list[ConstraintCheck] {
    checks: list[ConstraintCheck] = [];
    fault = fault_node(assets);
    fault_id = fault.identifier if fault is not None else "";
    if is_isolation(option) {
        isolated = fault is not None and all([e.operational_status == STATUS_FAULT for e in [edge fault ->:PowerLink:->]]);
        checks.append(ConstraintCheck(name=f"fault_isolated:{fault_id}", passed=isolated, detail="Faulted asset's outgoing links are open in the simulation" if isolated else "Faulted asset is not isolated"));
        return checks;
    }
    link_flow: dict[str, float] = {};
    asset_flow: dict[str, float] = {};
    donor_id = "";
    total = 0.0;
    for target_id in option.restored_assets {
        target = find_asset(assets, target_id);
        path = find_restoration_path(assets, target_id, fault_id);
        found = path.found and target is not None;
        checks.append(ConstraintCheck(name=f"path_available:{target_id}", passed=found, detail="Alternate path avoids the faulted asset" if found else "No path that avoids the faulted asset"));
        if not found or target is None { continue; }
        donor_id = path.donor_id;
        total = total + target.load_mw;
        for h in path.hops {
            link_flow[h.link_id] = link_flow.get(h.link_id, 0.0) + target.load_mw;
            if h.asset_id != path.donor_id {
                asset_flow[h.asset_id] = asset_flow.get(h.asset_id, 0.0) + target.load_mw;
            }
        }
    }
    for link_id in sorted(link_flow.keys()) {
        link = _link_by_id(assets, link_id);
        if link is None { continue; }
        checks.append(_limit_check(f"link_capacity:{link_id}", link_flow[link_id], link.capacity_mw - _existing_flow(assets, link_id), f"{link_id} headroom"));
    }
    for asset_id in sorted(asset_flow.keys()) {
        asset = find_asset(assets, asset_id);
        if asset is None { continue; }
        checks.append(_limit_check(f"asset_capacity:{asset_id}", asset_flow[asset_id], asset.capacity_mw, f"{asset_id} capacity"));
    }
    donor = find_asset(assets, donor_id);
    if donor is not None {
        checks.append(_limit_check(f"donor_capacity:{donor_id}", total, donor.capacity_mw - donor.load_mw, f"{donor_id} headroom"));
        supply = _supply_link(donor);
        if supply is not None {
            checks.append(_limit_check(f"supply_link_capacity:{supply.identifier}", total, supply.capacity_mw - donor.load_mw, f"{supply.identifier} headroom"));
        }
    }
    return checks;
}

# Runs check_option on every option and records the outcome on it: an option is
# feasible only if every check passes; the first failed check is the reason.
def verify_plan(assets: list[Infrastructure], plan: RecoveryPlan) -> RecoveryPlan {
    for option in plan.options {
        option.checks = check_option(assets, option);
        failed = [c for c in option.checks if not c.passed];
        option.feasible = len(option.checks) > 0 and len(failed) == 0;
        option.rejection_reason = "" if option.feasible else (f"{failed[0].name}: {failed[0].detail}" if len(failed) > 0 else "No checks could be run");
    }
    return plan;
}

# Picks the feasible restoring option that restores the most priority
# facilities, then the most load; falls back to keeping the fault isolated.
def recommend(plan: RecoveryPlan) -> RecoveryPlan {
    restoring = [o for o in plan.options if o.feasible and not is_isolation(o)];
    if len(restoring) > 0 {
        best = restoring[0];
        for o in restoring {
            if (o.critical_restored, o.restored_load_mw) > (best.critical_restored, best.restored_load_mw) { best = o; }
        }
        plan.recommended_id = best.identifier;
        return plan;
    }
    for o in plan.options {
        if o.feasible and is_isolation(o) { plan.recommended_id = o.identifier; return plan; }
    }
    plan.recommended_id = "";
    return plan;
}

# Candidate options for the incident, each verified, with a recommendation.
def build_recovery_plan(assets: list[Infrastructure], incident: Incident) -> RecoveryPlan {
    return recommend(verify_plan(assets, plan_recovery(assets, incident)));
}
