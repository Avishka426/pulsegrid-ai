"""Endpoint tests through the app's HTTP surface.

Jac 0.34 runs JacTestClient from Python pytest files (see `jac guide
jac-testing`); inside Jac `test` blocks the in-process server shares the test
runner's context. Each test gets its own temporary store, so none of them
read or modify the dev graph.
"""

from pathlib import Path

import pytest
from jaclang.runtimelib.testing import JacTestClient

APP_ENTRY = Path(__file__).resolve().parents[2] / "main.jac"


@pytest.fixture
def client(tmp_path):
    c = JacTestClient.from_file(str(APP_ENTRY), base_path=str(tmp_path))
    yield c
    c.close()


def call(client, name, body):
    resp = client.post(f"/function/{name}", json=body)
    assert resp.ok, f"{name} failed with {resp.status_code}: {resp.text[:300]}"
    return resp.data["result"]


def statuses(incidents):
    return [f"{i['identifier']}:{i['status']}" for i in incidents]


def test_fault_read_and_reset_drive_the_incident_lifecycle(client):
    snap = call(client, "apply_fault", {"scenario_id": "transformer"})
    assert (snap["fault_id"], snap["incident_id"]) == ("TR-01", "INC-0001")
    assert [e["identifier"] for e in snap["evidence"]] == [f"INC-0001/EV-{i:02d}" for i in range(1, 6)]
    read = call(client, "read_graph", {})
    assert (read["incident_id"], len(read["evidence"]), len(read["downstream"])) == ("INC-0001", 5, 4)
    reset = call(client, "reset_graph", {})
    assert (reset["fault_active"], reset["incident_id"], reset["evidence"]) == (False, "", [])
    assert statuses(call(client, "list_incidents", {})) == ["INC-0001:resolved"]


def test_a_new_fault_supersedes_the_active_incident(client):
    call(client, "apply_fault", {"scenario_id": "transformer"})
    snap = call(client, "apply_fault", {"scenario_id": "line"})
    assert (snap["fault_id"], snap["incident_id"], len(snap["evidence"])) == ("J-01", "INC-0002", 4)
    assert statuses(call(client, "list_incidents", {})) == ["INC-0002:active", "INC-0001:superseded"]


def test_unknown_scenario_is_rejected_without_recording_an_incident(client):
    call(client, "apply_fault", {"scenario_id": "substation"})
    resp = client.post("/function/apply_fault", json={"scenario_id": "meteor"})
    # The real server answers 500; Jac 0.34's in-process client reports the
    # error in the envelope with status 200, so check for the error itself.
    assert "Unknown scenario: meteor" in resp.text, resp.text[:300]
    assert statuses(call(client, "list_incidents", {})) == ["INC-0001:active"]
    assert call(client, "read_graph", {})["fault_id"] == "SUB-01"


def test_incident_history_keeps_the_newest_twenty(client):
    for i in range(22):
        call(client, "apply_fault", {"scenario_id": ["transformer", "substation", "line"][i % 3]})
    incidents = call(client, "list_incidents", {})
    assert len(incidents) == 20
    assert (incidents[0]["identifier"], incidents[0]["status"]) == ("INC-0022", "active")
    assert incidents[-1]["identifier"] == "INC-0003"
    assert len([i for i in incidents if i["status"] == "active"]) == 1


def test_a_fresh_store_seeds_the_baseline_network_with_no_incidents(client):
    snap = call(client, "read_graph", {})
    assert (len(snap["nodes"]), len(snap["links"])) == (14, 14)
    assert (snap["fault_active"], snap["incident_id"]) == (False, "")
    assert call(client, "list_incidents", {}) == []
