# Endpoint tests through the app's HTTP surface. Each test gets its own
# temporary store, so none of them read or modify the dev graph.

import tempfile;
import from pathlib { Path }
import from jaclang.testing.testing { JacTestClient }

def _client() -> JacTestClient {
    app_entry = Path(__file__).resolve().parents[2] / "main.jac";
    return JacTestClient.from_file(str(app_entry), base_path=tempfile.mkdtemp());
}

def _call(client: JacTestClient, name: str, body: dict[str, any]) -> any {
    resp = client.post(f"/function/{name}", json=body);
    if not resp.ok { raise AssertionError(f"{name} failed with {resp.status_code}: {resp.text[:300]}"); }
    return resp.data["result"];
}

def _statuses(incidents: list[dict[str, any]]) -> list[str] {
    return [f"{i['identifier']}:{i['status']}" for i in incidents];
}

test "fault, read and reset drive the incident lifecycle" {
    client = _client();
    try {
        snap = _call(client, "apply_fault", {"scenario_id": "transformer"});
        assert snap["fault_id"] == "TR-01" and snap["incident_id"] == "INC-0001";
        assert [e["identifier"] for e in snap["evidence"]] == [f"INC-0001/EV-{i:02d}" for i in range(1, 6)];
        read = _call(client, "read_graph", {});
        assert read["incident_id"] == "INC-0001" and len(read["evidence"]) == 5;
        assert len(read["downstream"]) == 4;
        reset = _call(client, "reset_graph", {});
        assert not reset["fault_active"] and reset["incident_id"] == "" and reset["evidence"] == [];
        assert _statuses(_call(client, "list_incidents", {})) == ["INC-0001:resolved"];
    } finally {
        client.close();
    }
}

test "a new fault supersedes the active incident" {
    client = _client();
    try {
        _call(client, "apply_fault", {"scenario_id": "transformer"});
        snap = _call(client, "apply_fault", {"scenario_id": "line"});
        assert snap["fault_id"] == "J-01" and snap["incident_id"] == "INC-0002";
        assert len(snap["evidence"]) == 4;
        assert _statuses(_call(client, "list_incidents", {})) == ["INC-0002:active", "INC-0001:superseded"];
    } finally {
        client.close();
    }
}

test "unknown scenario is rejected over HTTP without recording an incident" {
    client = _client();
    try {
        _call(client, "apply_fault", {"scenario_id": "substation"});
        resp = client.post("/function/apply_fault", json={"scenario_id": "meteor"});
        assert not resp.ok;
        assert _statuses(_call(client, "list_incidents", {})) == ["INC-0001:active"];
        assert _call(client, "read_graph", {})["fault_id"] == "SUB-01";
    } finally {
        client.close();
    }
}

test "incident history keeps the newest twenty" {
    client = _client();
    try {
        for i in range(22) {
            _call(client, "apply_fault", {"scenario_id": ["transformer", "substation", "line"][i % 3]});
        }
        incidents = _call(client, "list_incidents", {});
        assert len(incidents) == 20;
        assert incidents[0]["identifier"] == "INC-0022" and incidents[0]["status"] == "active";
        assert incidents[-1]["identifier"] == "INC-0003";
        assert len([i for i in incidents if i["status"] == "active"]) == 1;
    } finally {
        client.close();
    }
}

test "a fresh store seeds the baseline network with no incidents" {
    client = _client();
    try {
        snap = _call(client, "read_graph", {});
        assert len(snap["nodes"]) == 14 and len(snap["links"]) == 14;
        assert not snap["fault_active"] and snap["incident_id"] == "";
        assert _call(client, "list_incidents", {}) == [];
    } finally {
        client.close();
    }
}
