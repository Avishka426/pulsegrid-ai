sv import from ...services.graphService { Infrastructure, GraphSnapshot, read_graph, apply_fault, reset_graph }
import from ..Sidebar { Sidebar }
import from ..Header { Header }
import from ..MetricCards { MetricCards }
import from ..NetworkDiagram { NetworkDiagram }
import from ..AssetDetails { AssetDetails }
import from ..DownstreamImpactPanel { DownstreamImpactPanel }
import from ..IncidentTimeline { IncidentTimeline }
import from ..SimulationControls { SimulationControls }
import from ..AgentActivityPanel { AgentActivityPanel }
import from ..RecoveryPanel { RecoveryPanel }
sv import from ...agents.endpoints { AgentStatus, agent_status, list_agent_runs }

def:pub OverviewPage() -> JsxElement {
    has snapshot: GraphSnapshot = {"nodes": [], "links": [], "fault_active": False, "fault_label": "", "fault_id": "", "scenario_id": "", "scenario_title": "", "downstream": [], "interrupted_load_mw": 0.0, "critical_interrupted": 0} as GraphSnapshot;
    has scenario_id: str = "transformer";
    has loading: bool = True;
    has error_message: str = "";
    has selected_id: str = "";
    has agents: AgentStatus | None = None;
    has agent_runs: int = 0;
    has agents_failed: bool = False;

    async can with entry {
        try {
            snapshot = await read_graph();
            if snapshot.scenario_id != "" { scenario_id = snapshot.scenario_id; }
            loading = False;
        }
        except Exception { error_message = "Could not load the synthetic network."; loading = False; }
        try {
            agents = await agent_status();
            runs = await list_agent_runs();
            agent_runs = len(runs);
        }
        except Exception { agents_failed = True; }
    }

    def handle_scenario(e: ChangeEvent) { scenario_id = e.target.value; }
    def handle_select(identifier: str) { selected_id = identifier; }
    async def handle_fault {
        loading = True;
        try { snapshot = await apply_fault(scenario_id); error_message = ""; }
        except Exception { error_message = "Fault simulation failed. Try again."; }
        loading = False;
    }
    async def handle_reset {
        loading = True;
        try { snapshot = await reset_graph(); error_message = ""; selected_id = ""; }
        except Exception { error_message = "Reset failed. Try again."; }
        loading = False;
    }

    critical_count: int = 0;
    active_faults: int = 0;
    for n in snapshot.nodes {
        if n.criticality >= 4 { critical_count = critical_count + 1; }
        if n.operational_status == "fault" { active_faults = active_faults + 1; }
    }
    health = "Nominal" if active_faults == 0 else "Degraded";

    # End-use load only: assets with no outgoing PowerLink, so pass-through
    # equipment (substations, transformers, junctions) is not double counted.
    sources: list[str] = [l.source for l in snapshot.links];
    end_use_load_mw: float = 0.0;
    for n in snapshot.nodes { if n.identifier not in sources { end_use_load_mw = end_use_load_mw + n.load_mw; } }

    selected_asset: Infrastructure | None = None;
    for n in snapshot.nodes { if n.identifier == selected_id { selected_asset = n; } }

    return <Sidebar>
        <Header eyebrow="PULSEGRID OPERATIONS / PHASE 02" title="Grid Intelligence Overview" subtitle="Monitor. Investigate. Recover.">
            <span className="rounded-full border border-primary/30 bg-primary/5 px-3 py-1.5 text-xs text-primary">Synthetic Data</span>
            <span className="rounded-full border border-border px-3 py-1.5 text-xs">{"Simulation " + health}</span>
        </Header>
        {error_message != "" and <div className="rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive">{error_message}</div>}
        <MetricCards node_count={len(snapshot.nodes)} active_faults={active_faults} critical_count={critical_count} health={health} end_use_load_mw={end_use_load_mw} />
        <div className="grid grid-cols-1 items-start gap-5 2xl:grid-cols-[minmax(0,1fr)_300px]">
            <div className="flex min-w-0 flex-col gap-5">
                <NetworkDiagram nodes={snapshot.nodes} links={snapshot.links} selected_id={selected_id} onSelect={handle_select} loading={loading} />
                <AssetDetails asset={selected_asset} links={snapshot.links} downstream={snapshot.downstream} />
                <DownstreamImpactPanel
                    fault_active={snapshot.fault_active} fault_label={snapshot.fault_label} fault_id={snapshot.fault_id}
                    scenario_title={snapshot.scenario_title} downstream={snapshot.downstream}
                    interrupted_load_mw={snapshot.interrupted_load_mw} critical_interrupted={snapshot.critical_interrupted}
                    selected_id={selected_id} onSelect={handle_select}
                />
                <RecoveryPanel fault_active={snapshot.fault_active} />
                <div className="grid grid-cols-1 gap-5 xl:grid-cols-2">
                    <IncidentTimeline scenario_title={snapshot.scenario_title} fault_label={snapshot.fault_label} fault_id={snapshot.fault_id} active_faults={active_faults} downstream_count={len(snapshot.downstream)} />
                    <SimulationControls scenario_id={scenario_id} loading={loading} onScenarioChange={handle_scenario} onFault={handle_fault} onReset={handle_reset} />
                </div>
            </div>
            <AgentActivityPanel status={agents} run_count={agent_runs} failed={agents_failed} />
        </div>
        <footer className="border-t border-border pt-4 text-[11px] leading-relaxed text-muted-foreground">Synthetic educational simulator, not an operational grid-control system. No real infrastructure is connected. No claims about actual Sri Lankan grid topology.</footer>
    </Sidebar>;
}
