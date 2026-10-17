import from services.graphService { read_graph, apply_fault, reset_graph, list_incidents, list_scenarios, preview_scenario, get_incident, recovery_plan }
import from agents.endpoints { agent_status, run_investigation, list_agent_runs, get_agent_run }

cl {
    import ".styles.global.css";
    import from .components.pages.OverviewPage { OverviewPage }
    import from .components.pages.NetworkExplorerPage { NetworkExplorerPage }
    import from .components.pages.IncidentCenterPage { IncidentCenterPage }
    import from .components.pages.AgentIntelligencePage { AgentIntelligencePage }
    import from .components.pages.SimulationLabPage { SimulationLabPage }
    import from .components.pages.ReportsPage { ReportsPage }
    import from "@jac/runtime" { Router, Routes, Route }

    def:pub app() -> JsxElement {
        return <Router><Routes>
            <Route path="/" element={<OverviewPage />} />
            <Route path="/network" element={<NetworkExplorerPage />} />
            <Route path="/incidents" element={<IncidentCenterPage />} />
            <Route path="/agents" element={<AgentIntelligencePage />} />
            <Route path="/simulation" element={<SimulationLabPage />} />
            <Route path="/reports" element={<ReportsPage />} />
        </Routes></Router>;
    }
}
