# Incident records and the evidence gathered from each fault simulation.

import from .models {
    Infrastructure, Scenario, Incident, Evidence, HasEvidence,
    STATUS_FAULT, STATUS_DE_ENERGIZED, STATUS_ALTERNATE_FEED,
    INCIDENT_ACTIVE, INCIDENT_SUPERSEDED, INCIDENT_RESOLVED, INCIDENT_HISTORY_LIMIT
}
import from .walkers { compute_downstream }

def new_incident(scenario: Scenario, fault: Infrastructure, sequence: int) -> Incident {
    return Incident(identifier=f"INC-{sequence:04d}", sequence=sequence, scenario_id=scenario.identifier, scenario_title=scenario.title, fault_id=fault.identifier);
}

# Links one fault Evidence plus one per downstream asset, in breadth-first
# order, to `incident`. Identifiers depend only on the sequence number and the
# graph, so the same inputs give the same records.
def record_evidence(incident: Incident, assets: list[Infrastructure], scenario: Scenario, fault: Infrastructure) -> None {
    records: list[Evidence] = [
        Evidence(identifier="", kind=STATUS_FAULT, asset_id=fault.identifier, detail=f"{fault.display_name} ({fault.identifier}) faulted in scenario {scenario.title}", value_mw=fault.load_mw)
    ];
    for d in compute_downstream(assets, fault) {
        hop_word = "hop" if d.hops == 1 else "hops";
        if d.alternate_feed {
            records.append(Evidence(identifier="", kind=STATUS_ALTERNATE_FEED, asset_id=d.identifier, detail=f"{d.display_name} ({d.identifier}) is {d.hops} {hop_word} downstream of {fault.identifier}; another supply path exists in the graph", hops=d.hops, value_mw=d.load_mw));
        } else {
            records.append(Evidence(identifier="", kind=STATUS_DE_ENERGIZED, asset_id=d.identifier, detail=f"{d.display_name} ({d.identifier}) is {d.hops} {hop_word} downstream of {fault.identifier} with no other supply path", hops=d.hops, value_mw=d.load_mw));
        }
    }
    for (i, ev) in enumerate(records) {
        ev.identifier = f"{incident.identifier}/EV-{i + 1:02d}";
        incident +>:HasEvidence:+> ev;
    }
}

# A transient incident with its evidence, for tests and analysis.
def build_incident(assets: list[Infrastructure], scenario: Scenario, fault: Infrastructure, sequence: int) -> Incident {
    incident = new_incident(scenario, fault, sequence);
    record_evidence(incident, assets, scenario, fault);
    return incident;
}

def evidence_of(incident: Incident) -> list[Evidence] {
    return [incident ->:HasEvidence:->];
}

# Incidents on the caller's root, newest first.
def stored_incidents() -> list[Incident] {
    return sorted([root -->][?:Incident], key=_by_sequence, reverse=True);
}

def _by_sequence(incident: Incident) -> int {
    return incident.sequence;
}

def active_incident() -> Incident | None {
    for incident in stored_incidents() {
        if incident.status == INCIDENT_ACTIVE { return incident; }
    }
    return None;
}

# Supersedes any active incident, records a new one on root and trims history.
def open_incident(assets: list[Infrastructure], scenario: Scenario, fault: Infrastructure) -> Incident {
    history = stored_incidents();
    for old in history {
        if old.status == INCIDENT_ACTIVE { old.status = INCIDENT_SUPERSEDED; }
    }
    sequence = history[0].sequence + 1 if len(history) > 0 else 1;
    # Attach before linking evidence (see ensure_network in seed.jac).
    incident = new_incident(scenario, fault, sequence);
    root ++> incident;
    record_evidence(incident, assets, scenario, fault);
    _trim_history(INCIDENT_HISTORY_LIMIT);
    return incident;
}

def resolve_active_incident() -> None {
    incident = active_incident();
    if incident is not None { incident.status = INCIDENT_RESOLVED; }
}

def _trim_history(limit: int) -> None {
    history = stored_incidents();
    if len(history) <= limit { return; }
    for old in history[limit:] {
        for ev in evidence_of(old) { del ev; }
        del old;
    }
}
