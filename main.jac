cl {
    import ".styles.global.css";
    import from .components.pages.OverviewPage { OverviewPage }
    import from .components.pages.UpcomingPage { UpcomingPage }
    import from "@jac/runtime" { Router, Routes, Route }

    def:pub app() -> JsxElement {
        return <Router><Routes>
            <Route path="/" element={<OverviewPage />} />
            <Route path="/network" element={<UpcomingPage nav_label="Network Explorer" description="A dedicated topology browser (filter, search, zoom) is planned for a later phase. Use the asset register on Overview for now." />} />
            <Route path="/incidents" element={<UpcomingPage nav_label="Incident Center" description="A full incident log across past simulations is planned for a later phase. The current incident appears in the Overview timeline." />} />
            <Route path="/agents" element={<UpcomingPage nav_label="Agent Intelligence" description="Multi-agent monitoring, investigation and recovery coordination is planned for Phase 4 and requires a configured LLM provider key. See the Agent Activity panel on Overview." />} />
            <Route path="/simulation" element={<UpcomingPage nav_label="Simulation Lab" description="A dedicated scenario authoring workspace is planned for a later phase. Use Simulation Controls on Overview to run the three built-in scenarios." />} />
            <Route path="/reports" element={<UpcomingPage nav_label="Reports" description="Exportable incident and recovery reports are planned for a later phase." />} />
        </Routes></Router>;
    }
}
