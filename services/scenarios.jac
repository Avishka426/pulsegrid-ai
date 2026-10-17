# Scenario definitions and the fault/reset state transitions they drive.

import from .models {
    Infrastructure, PowerLink, Scenario,
    STATUS_NORMAL, STATUS_FAULT, STATUS_DE_ENERGIZED, STATUS_ALTERNATE_FEED
}
import from .walkers { compute_downstream }

# Each scenario faults one explicit, stable asset of the synthetic network.
glob SCENARIOS: list[Scenario] = [
    Scenario(identifier="transformer", title="Transformer Overheating", target_id="TR-01"),
    Scenario(identifier="substation", title="Substation Failure", target_id="SUB-01"),
    Scenario(identifier="line", title="Distribution Line Overload", target_id="J-01")
];

def find_scenario(scenario_id: str) -> Scenario | None {
    for s in SCENARIOS { if s.identifier == scenario_id { return s; } }
    return None;
}

def scenario_for_target(target_id: str) -> Scenario | None {
    for s in SCENARIOS { if s.target_id == target_id { return s; } }
    return None;
}

def find_asset(assets: list[Infrastructure], identifier: str) -> Infrastructure | None {
    for n in assets { if n.identifier == identifier { return n; } }
    return None;
}

def fault_node(assets: list[Infrastructure]) -> Infrastructure | None {
    for n in assets { if n.operational_status == STATUS_FAULT { return n; } }
    return None;
}

def reset_assets(assets: list[Infrastructure]) -> None {
    for n in assets {
        n.operational_status = STATUS_NORMAL;
        for e in [edge n ->:PowerLink:->] { e.operational_status = STATUS_NORMAL; }
    }
}

# Resets the network, faults `target`, then marks every downstream asset as
# de-energized or alternate-feed and the links leaving de-energized assets.
def mark_fault(assets: list[Infrastructure], target: Infrastructure) -> None {
    reset_assets(assets);
    target.operational_status = STATUS_FAULT;
    for e in [edge target ->:PowerLink:->] { e.operational_status = STATUS_FAULT; }
    for item in compute_downstream(assets, target) {
        n = find_asset(assets, item.identifier);
        if n is None { continue; }
        if item.alternate_feed {
            n.operational_status = STATUS_ALTERNATE_FEED;
        } else {
            n.operational_status = STATUS_DE_ENERGIZED;
            for e in [edge n ->:PowerLink:->] { e.operational_status = STATUS_DE_ENERGIZED; }
        }
    }
}

def apply_scenario(assets: list[Infrastructure], scenario_id: str) -> Infrastructure {
    scenario = find_scenario(scenario_id);
    if scenario is None { raise ValueError(f"Unknown scenario: {scenario_id}"); }
    target = find_asset(assets, scenario.target_id);
    if target is None { raise ValueError(f"Scenario target {scenario.target_id} is not in the network"); }
    mark_fault(assets, target);
    return target;
}
