sv import from ..services.graphService { Infrastructure, GraphSnapshot, read_graph, apply_fault, reset_graph }


def:pub PulseGridDashboard() -> JsxElement {
    has graph: GraphSnapshot = {"nodes": [], "links": [], "fault_active": False, "fault_label": ""} as GraphSnapshot;
    has scenario_id: str = "transformer";
    has loading: bool = True;
    has error_message: str = "";

    async can with entry {
        try { graph = await read_graph(); loading = False; }
        except Exception { error_message = "Could not load the synthetic network."; loading = False; }
    }

    def handle_scenario(e: ChangeEvent) { scenario_id = e.target.value; }
    async def handle_fault {
        loading = True;
        try { graph = await apply_fault(scenario_id); error_message = ""; }
        except Exception { error_message = "Fault simulation failed. Try again."; }
        loading = False;
    }
    async def handle_reset {
        loading = True;
        try { graph = await reset_graph(); error_message = ""; }
        except Exception { error_message = "Reset failed. Try again."; }
        loading = False;
    }

    total_load: float = 0.0;
    critical_count: int = 0;
    active_faults: int = 0;
    for n in graph.nodes {
        total_load = total_load + n.load_mw;
        if n.criticality >= 4 { critical_count = critical_count + 1; }
        if n.operational_status == "fault" { active_faults = active_faults + 1; }
    }
    health = "Nominal" if active_faults == 0 else "Degraded";

    return <div className="flex min-h-screen bg-background text-foreground">
        <aside className="hidden w-60 shrink-0 flex-col border-r border-border bg-card/80 px-5 py-6 lg:flex">
            <div className="mb-10 flex items-center gap-3"><div className="flex size-10 items-center justify-center rounded-xl bg-primary text-primary-foreground"><span className="text-lg font-bold">P</span></div><div><div className="font-semibold tracking-tight">PulseGrid <span className="text-primary">AI</span></div><div className="text-xs text-muted-foreground">GRID INTELLIGENCE</div></div></div>
            <div className="mb-3 px-2 text-[10px] font-semibold tracking-[0.18em] text-muted-foreground">WORKSPACE</div>
            <nav className="flex flex-col gap-1"><div className="rounded-lg bg-primary/10 px-3 py-2.5 text-sm font-medium text-primary">Overview</div><div className="rounded-lg px-3 py-2.5 text-sm text-muted-foreground">Network Explorer</div><div className="rounded-lg px-3 py-2.5 text-sm text-muted-foreground">Incident Center</div><div className="rounded-lg px-3 py-2.5 text-sm text-muted-foreground">Agent Intelligence</div><div className="rounded-lg px-3 py-2.5 text-sm text-muted-foreground">Simulation Lab</div><div className="rounded-lg px-3 py-2.5 text-sm text-muted-foreground">Reports</div></nav>
            <div className="mt-auto rounded-xl border border-border bg-background p-3"><div className="mb-1 flex items-center gap-2 text-xs font-medium"><span className="size-2 rounded-full bg-primary"/>DEMO ENVIRONMENT</div><p className="text-xs leading-relaxed text-muted-foreground">Synthetic educational network. No live infrastructure.</p></div>
        </aside>
        <main className="min-w-0 flex-1 px-4 py-5 sm:px-7 sm:py-7 xl:px-9">
            <header className="mb-7 flex flex-wrap items-center justify-between gap-4"><div><div className="mb-1 flex items-center gap-2 text-xs font-medium tracking-[0.15em] text-primary">PULSEGRID OPERATIONS <span className="text-border">/</span> PHASE 01</div><h1 className="text-2xl font-semibold tracking-tight sm:text-3xl">Grid Intelligence Overview</h1><p className="mt-1 text-sm text-muted-foreground">Monitor. Investigate. Recover.</p></div><div className="flex flex-wrap items-center gap-2"><span className="rounded-full border border-primary/30 bg-primary/5 px-3 py-1.5 text-xs text-primary">Synthetic Data</span><span className="rounded-full border border-border px-3 py-1.5 text-xs">Simulation {health}</span></div></header>
            {error_message != "" and <div className="mb-4 rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive">{error_message}</div>}
            <section className="mb-5 grid grid-cols-2 gap-3 xl:grid-cols-4">
                <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Network nodes</div><div className="mt-3 text-3xl font-semibold tabular-nums">{str(len(graph.nodes))}</div><div className="mt-1 text-xs text-muted-foreground">Connected assets</div></div>
                <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Active incidents</div><div className="mt-3 text-3xl font-semibold tabular-nums">{str(active_faults)}</div><div className="mt-1 text-xs text-muted-foreground">Deterministic simulation</div></div>
                <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Critical facilities</div><div className="mt-3 text-3xl font-semibold tabular-nums">{str(critical_count)}</div><div className="mt-1 text-xs text-muted-foreground">Priority-rated assets</div></div>
                <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Network health</div><div className="mt-3 text-3xl font-semibold">{health}</div><div className="mt-1 text-xs text-muted-foreground">{f"{total_load:.0f}"} MW modeled load</div></div>
            </section>
            <section className="grid grid-cols-1 items-start gap-5 2xl:grid-cols-[minmax(0,1fr)_300px]">
                <div className="flex min-w-0 flex-col gap-5">
                    <section className="overflow-hidden rounded-xl border border-border bg-card shadow-sm"><header className="border-b border-border px-5 py-4"><h2 className="font-semibold">Distribution network</h2><p className="mt-1 text-sm text-muted-foreground">Deterministic infrastructure graph · 14 assets · 14 links</p></header>
                        <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_245px]">
                            <div className="relative min-h-[350px] overflow-hidden border-b border-border bg-[radial-gradient(circle_at_center,color-mix(in_oklch,var(--primary)_8%,transparent),transparent_70%)] p-4 lg:border-b-0 lg:border-r sm:p-6">
                                <div className="absolute inset-0 opacity-30 [background-image:radial-gradient(color-mix(in_oklch,var(--foreground)_22%,transparent)_1px,transparent_1px)] [background-size:22px_22px]"/>
                                <svg className="absolute inset-0 h-full w-full" viewBox="0 0 660 360" preserveAspectRatio="none" aria-label="Synthetic electrical network links"><line x1="74" y1="180" x2="190" y2="100" stroke="currentColor" stroke-width="2" className="text-primary/60"/><line x1="74" y1="180" x2="190" y2="260" stroke="currentColor" stroke-width="2" className="text-primary/60"/><line x1="190" y1="100" x2="320" y2="72" stroke="currentColor" stroke-width="2" className="text-primary/60"/><line x1="190" y1="100" x2="320" y2="142" stroke="currentColor" stroke-width="2" className="text-primary/60"/><line x1="320" y1="72" x2="445" y2="65" stroke="currentColor" stroke-width="2" className="text-primary/60"/><line x1="320" y1="142" x2="445" y2="180" stroke="currentColor" stroke-width="2" className="text-primary/60"/><line x1="445" y1="65" x2="570" y2="55" stroke="currentColor" stroke-width="2" className={"text-primary/60" if active_faults == 0 else "text-red-500"}/><line x1="445" y1="65" x2="570" y2="130" stroke="currentColor" stroke-width="2" className="text-primary/60"/><line x1="445" y1="65" x2="570" y2="205" stroke="currentColor" stroke-width="2" className="text-primary/60"/><line x1="320" y1="260" x2="445" y2="285" stroke="currentColor" stroke-width="2" className="text-primary/60"/></svg>
                                <div className="relative z-10 grid min-h-[310px] grid-cols-4 grid-rows-4 items-center justify-items-center gap-1 sm:gap-2">
                                    <div className="col-start-1 row-span-4 flex flex-col items-center gap-2"><div className="rounded-xl border border-primary/50 bg-background px-3 py-2 text-center shadow-lg"><span className="text-lg text-primary">GRID</span><span className="block text-[10px] font-semibold">GENERATION</span></div><span className="text-[9px] text-muted-foreground">North · 240 MW</span></div>
                                    <div className="col-start-2 row-start-2 rounded-lg border border-primary/40 bg-card px-2 py-2 text-center shadow-md"><span className="text-[9px] font-medium">CENTRAL SUB</span></div><div className="col-start-2 row-start-4 rounded-lg border border-primary/40 bg-card px-2 py-2 text-center shadow-md"><span className="text-[9px] font-medium">HARBOR SUB</span></div>
                                    <div className={"col-start-3 row-start-1 rounded-lg border bg-card px-2 py-2 text-center shadow-md " + ("border-red-500 bg-red-500/10" if active_faults > 0 else "border-primary/40")}><span className="text-[9px] font-medium">TRANSFORMER A</span></div><div className="col-start-3 row-start-2 rounded-lg border border-primary/40 bg-card px-2 py-2 text-center"><span className="text-[9px] font-medium">TRANSFORMER B</span></div><div className="col-start-3 row-start-4 rounded-lg border border-primary/40 bg-card px-2 py-2 text-center"><span className="text-[9px] font-medium">TRANSFORMER C</span></div>
                                    <div className="col-start-4 row-start-1 flex flex-col gap-2"><span className="rounded-lg border border-primary/40 bg-card px-2 py-1.5 text-[9px]">WEST JUNCTION</span><span className="rounded-lg border border-primary/40 bg-card px-2 py-1.5 text-[9px]">EAST JUNCTION</span><span className="rounded-lg border border-primary/40 bg-card px-2 py-1.5 text-[9px]">HARBOR JUNCTION</span></div>
                                </div><div className="absolute bottom-3 left-4 text-[10px] text-muted-foreground">Illustrative topology · not geographically accurate</div>
                            </div>
                            <div className="flex flex-col gap-1 p-4"><div className="mb-2 flex items-center justify-between"><span className="text-xs font-semibold tracking-wide">ASSET REGISTER</span><span className="text-[10px] text-muted-foreground">{str(len(graph.nodes))} NODES</span></div>{if loading { <p className="py-5 text-xs text-muted-foreground">Loading network data…</p> }}{for n in graph.nodes { <div key={n.identifier} className="flex items-center gap-2 border-b border-border/70 py-2"><span className={"size-1.5 shrink-0 rounded-full " + ("bg-red-500" if n.operational_status == "fault" else "bg-primary")}/><div className="min-w-0 flex-1"><div className="truncate text-xs font-medium">{n.display_name}</div><div className="text-[10px] text-muted-foreground">{n.category}</div></div><span className="text-[10px] tabular-nums text-muted-foreground">{f"{n.load_mw:.0f}"} MW</span></div> }}</div>
                        </div>
                    </section>
                    <div className="grid grid-cols-1 gap-5 xl:grid-cols-2">
                        <section className="rounded-xl border border-border bg-card p-5 shadow-sm"><h2 className="mb-3 font-semibold">Incident timeline</h2><div className="flex items-start gap-3 border-l border-border pl-4"><span className={"-ml-[21px] mt-1 size-2.5 rounded-full border-2 border-background " + ("bg-red-500" if active_faults > 0 else "bg-primary")}/><div><div className="text-sm font-medium">{graph.fault_label if active_faults > 0 else "Baseline network loaded"}</div><div className="mt-1 text-xs text-muted-foreground">{("Fault applied · downstream assets flagged" if active_faults > 0 else "Synthetic topology initialized · ready for simulation")}</div></div></div></section>
                        <section className="rounded-xl border border-border bg-card p-5 shadow-sm"><h2 className="font-semibold">Simulation controls</h2><p className="mb-4 mt-1 text-sm text-muted-foreground">Run reproducible faults against the synthetic graph</p><label htmlFor="scenario" className="text-xs font-medium">Incident scenario</label><select id="scenario" value={scenario_id} onChange={handle_scenario} className="my-2 h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="transformer">Transformer Overheating</option><option value="substation">Substation Failure</option><option value="line">Distribution Line Overload</option></select><div className="flex flex-wrap gap-2"><button onClick={handle_fault} disabled={loading} className="h-9 flex-1 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground disabled:opacity-50">Simulate fault</button><button onClick={handle_reset} disabled={loading} className="h-9 rounded-md border border-border bg-background px-4 text-sm font-medium disabled:opacity-50">Reset simulation</button></div><p className="mt-3 text-[11px] leading-relaxed text-muted-foreground">Reachability uses deterministic graph logic. No switching recommendations are produced.</p></section>
                    </div>
                </div>
                <section className="rounded-xl border border-border bg-card p-5 shadow-sm"><div className="flex items-center justify-between"><h2 className="font-semibold">Agent activity</h2><span className="rounded-full border border-border px-2 py-1 text-[10px]">UPCOMING</span></div><p className="mb-4 mt-1 text-sm text-muted-foreground">Multi-agent workflows planned for Phase 2</p><div className="flex flex-col gap-3"><div className="rounded-lg border border-border bg-background p-3"><div className="text-sm font-medium">Monitoring Agent</div><p className="mt-1 text-xs text-muted-foreground">Inactive · no runs</p></div><div className="rounded-lg border border-border bg-background p-3"><div className="text-sm font-medium">Impact Investigator</div><p className="mt-1 text-xs text-muted-foreground">Inactive · no runs</p></div><div className="rounded-lg border border-border bg-background p-3"><div className="text-sm font-medium">Recovery Planner</div><p className="mt-1 text-xs text-muted-foreground">Inactive · no runs</p></div><div className="rounded-lg border border-border bg-background p-3"><div className="text-sm font-medium">Verification Agent</div><p className="mt-1 text-xs text-muted-foreground">Inactive · no runs</p></div><div className="rounded-lg border border-border bg-background p-3"><div className="text-sm font-medium">Coordinator Agent</div><p className="mt-1 text-xs text-muted-foreground">Inactive · no runs</p></div></div><p className="mt-4 rounded-lg border border-dashed border-primary/30 bg-primary/5 p-3 text-xs leading-relaxed text-muted-foreground">Agent evidence, decisions, verification and replanning are not simulated in Phase 1.</p></section>
            </section>
            <footer className="mt-7 border-t border-border pt-4 text-[11px] leading-relaxed text-muted-foreground">Synthetic educational simulator, not an operational grid-control system. No real infrastructure is connected. No claims about actual Sri Lankan grid topology.</footer>
        </main>
    </div>;
}
