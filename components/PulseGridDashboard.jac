sv import from ..services.graphService { Infrastructure, LinkView, DownstreamAsset, GraphSnapshot, read_graph, apply_fault, reset_graph }


def:pub PulseGridDashboard() -> JsxElement {
    has snapshot: GraphSnapshot = {"nodes": [], "links": [], "fault_active": False, "fault_label": "", "fault_id": "", "scenario_id": "", "scenario_title": "", "downstream": [], "interrupted_load_mw": 0.0, "critical_interrupted": 0} as GraphSnapshot;
    has scenario_id: str = "transformer";
    has loading: bool = True;
    has error_message: str = "";

    async can with entry {
        try {
            snapshot = await read_graph();
            if snapshot.scenario_id != "" { scenario_id = snapshot.scenario_id; }
            loading = False;
        }
        except Exception { error_message = "Could not load the synthetic network."; loading = False; }
    }

    def handle_scenario(e: ChangeEvent) { scenario_id = e.target.value; }
    async def handle_fault {
        loading = True;
        try { snapshot = await apply_fault(scenario_id); error_message = ""; }
        except Exception { error_message = "Fault simulation failed. Try again."; }
        loading = False;
    }
    async def handle_reset {
        loading = True;
        try { snapshot = await reset_graph(); error_message = ""; }
        except Exception { error_message = "Reset failed. Try again."; }
        loading = False;
    }

    # Illustrative diagram coordinates (viewBox 0 0 640 320); not geographic.
    layout: dict[str, list[int]] = {
        "SRC-01": [40, 165], "SUB-01": [160, 100], "SUB-02": [160, 270],
        "TR-01": [290, 55], "TR-02": [290, 145], "TR-03": [290, 290],
        "J-01": [420, 55], "J-02": [420, 145], "J-03": [420, 290],
        "FAC-01": [580, 20], "ZONE-01": [580, 65], "FAC-03": [580, 125], "ZONE-02": [580, 170], "FAC-02": [580, 235]
    };
    status_text: dict[str, str] = {"normal": "text-primary", "fault": "text-red-500", "de-energized": "text-amber-500", "alternate-feed": "text-sky-500"};
    status_dot: dict[str, str] = {"normal": "bg-primary", "fault": "bg-red-500", "de-energized": "bg-amber-500", "alternate-feed": "bg-sky-500"};
    status_label: dict[str, str] = {"normal": "Normal", "fault": "Fault", "de-energized": "De-energized", "alternate-feed": "Alternate feed"};

    total_load: float = 0.0;
    critical_count: int = 0;
    active_faults: int = 0;
    for n in snapshot.nodes {
        total_load = total_load + n.load_mw;
        if n.criticality >= 4 { critical_count = critical_count + 1; }
        if n.operational_status == "fault" { active_faults = active_faults + 1; }
    }
    health = "Nominal" if active_faults == 0 else "Degraded";
    de_energized_count: int = 0;
    for d in snapshot.downstream { if not d.alternate_feed { de_energized_count = de_energized_count + 1; } }
    alternate_count = len(snapshot.downstream) - de_energized_count;

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
                <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Network nodes</div><div className="mt-3 text-3xl font-semibold tabular-nums">{str(len(snapshot.nodes))}</div><div className="mt-1 text-xs text-muted-foreground">Connected assets</div></div>
                <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Active incidents</div><div className="mt-3 text-3xl font-semibold tabular-nums">{str(active_faults)}</div><div className="mt-1 text-xs text-muted-foreground">Deterministic simulation</div></div>
                <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Critical facilities</div><div className="mt-3 text-3xl font-semibold tabular-nums">{str(critical_count)}</div><div className="mt-1 text-xs text-muted-foreground">Priority-rated assets</div></div>
                <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Network health</div><div className="mt-3 text-3xl font-semibold">{health}</div><div className="mt-1 text-xs text-muted-foreground">{f"{total_load:.0f}"} MW modeled load</div></div>
            </section>
            <section className="grid grid-cols-1 items-start gap-5 2xl:grid-cols-[minmax(0,1fr)_300px]">
                <div className="flex min-w-0 flex-col gap-5">
                    <section className="overflow-hidden rounded-xl border border-border bg-card shadow-sm"><header className="border-b border-border px-5 py-4"><h2 className="font-semibold">Distribution network</h2><p className="mt-1 text-sm text-muted-foreground">{f"Deterministic infrastructure graph · {len(snapshot.nodes)} assets · {len(snapshot.links)} links"}</p></header>
                        <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_245px]">
                            <div className="relative flex flex-col justify-center overflow-hidden border-b border-border bg-[radial-gradient(circle_at_center,color-mix(in_oklch,var(--primary)_8%,transparent),transparent_70%)] p-4 lg:border-b-0 lg:border-r sm:p-6">
                                <div className="absolute inset-0 opacity-30 [background-image:radial-gradient(color-mix(in_oklch,var(--foreground)_22%,transparent)_1px,transparent_1px)] [background-size:22px_22px]"/>
                                <svg className="relative z-10 h-auto w-full" viewBox="0 0 640 320" role="img" aria-label="Synthetic electrical network: assets coloured by simulated status">
                                    {for l in snapshot.links {
                                        <line key={l.identifier} x1={layout[l.source][0]} y1={layout[l.source][1]} x2={layout[l.target][0]} y2={layout[l.target][1]} stroke="currentColor" strokeWidth={3 if l.operational_status == "fault" else 2} strokeDasharray={"6 4" if l.operational_status == "de-energized" else "none"} className={status_text[l.operational_status] + (" opacity-60" if l.operational_status == "normal" else "")}><title>{f"{l.identifier} · {l.source} → {l.target} · {l.capacity_mw:.0f} MW · {status_label[l.operational_status]}"}</title></line>
                                    }}
                                    {for n in snapshot.nodes {
                                        <g key={n.identifier} className={status_text[n.operational_status]}>
                                            <title>{f"{n.display_name} ({n.identifier}) · {n.category} · {status_label[n.operational_status]}"}</title>
                                            {n.operational_status == "fault" and <circle cx={layout[n.identifier][0]} cy={layout[n.identifier][1]} r="15" fill="none" stroke="currentColor" strokeWidth="2" opacity="0.5"/>}
                                            <circle cx={layout[n.identifier][0]} cy={layout[n.identifier][1]} r="9" fill="currentColor" stroke="var(--background)" strokeWidth="2"/>
                                            <text x={layout[n.identifier][0]} y={layout[n.identifier][1] + 22} textAnchor="middle" fontSize="10" className="fill-foreground font-medium">{n.identifier}</text>
                                        </g>
                                    }}
                                </svg>
                                <div className="relative z-10 mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-[10px] text-muted-foreground"><span className="flex items-center gap-1.5"><span className="size-2 rounded-full bg-primary"/>Normal</span><span className="flex items-center gap-1.5"><span className="size-2 rounded-full bg-red-500"/>Fault</span><span className="flex items-center gap-1.5"><span className="size-2 rounded-full bg-amber-500"/>De-energized</span><span className="flex items-center gap-1.5"><span className="size-2 rounded-full bg-sky-500"/>Alternate feed</span><span className="ml-auto">Illustrative layout · not geographically accurate</span></div>
                            </div>
                            <div className="flex flex-col gap-1 p-4"><div className="mb-2 flex items-center justify-between"><span className="text-xs font-semibold tracking-wide">ASSET REGISTER</span><span className="text-[10px] text-muted-foreground">{str(len(snapshot.nodes))} NODES</span></div>{if loading { <p className="py-5 text-xs text-muted-foreground">Loading network data…</p> }}{for n in snapshot.nodes { <div key={n.identifier} className="flex items-center gap-2 border-b border-border/70 py-2"><span className={"size-1.5 shrink-0 rounded-full " + status_dot[n.operational_status]}/><div className="min-w-0 flex-1"><div className="truncate text-xs font-medium">{n.display_name}</div><div className="text-[10px] text-muted-foreground">{n.category if n.operational_status == "normal" else n.category + " · " + status_label[n.operational_status]}</div></div><span className="text-[10px] tabular-nums text-muted-foreground">{f"{n.load_mw:.0f}"} MW</span></div> }}</div>
                        </div>
                    </section>
                    <section className="rounded-xl border border-border bg-card p-5 shadow-sm" aria-live="polite">
                        <div className="flex flex-wrap items-start justify-between gap-2"><div><h2 className="font-semibold">Downstream impact</h2><p className="mt-1 text-sm text-muted-foreground">{f"Assets reachable from {snapshot.fault_label} ({snapshot.fault_id}) over directed power links" if snapshot.fault_active else "Assets reachable from the faulted node over directed power links"}</p></div>{snapshot.fault_active and <span className="rounded-full border border-red-500/40 bg-red-500/10 px-2 py-1 text-[10px] text-red-500">{snapshot.scenario_title if snapshot.scenario_title != "" else "Fault active"}</span>}</div>
                        {if not snapshot.fault_active {
                            <p className="mt-4 rounded-lg border border-dashed border-border p-4 text-sm text-muted-foreground">No active fault. Simulate a scenario to trace downstream assets from the faulted node.</p>
                        } else {
                            <div>
                                <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
                                    <div className="rounded-lg border border-border bg-background p-3"><div className="text-xl font-semibold tabular-nums">{str(len(snapshot.downstream))}</div><div className="text-[11px] text-muted-foreground">Downstream assets</div></div>
                                    <div className="rounded-lg border border-border bg-background p-3"><div className="text-xl font-semibold tabular-nums text-amber-500">{str(de_energized_count)}</div><div className="text-[11px] text-muted-foreground">De-energized</div></div>
                                    <div className="rounded-lg border border-border bg-background p-3"><div className="text-xl font-semibold tabular-nums text-sky-500">{str(alternate_count)}</div><div className="text-[11px] text-muted-foreground">Alternate feed path</div></div>
                                    <div className="rounded-lg border border-border bg-background p-3"><div className="text-xl font-semibold tabular-nums">{f"{snapshot.interrupted_load_mw:.0f}"} MW</div><div className="text-[11px] text-muted-foreground">{f"End-use load interrupted · {snapshot.critical_interrupted} critical"}</div></div>
                                </div>
                                {if len(snapshot.downstream) == 0 {
                                    <p className="mt-4 text-sm text-muted-foreground">The faulted asset has no downstream links.</p>
                                } else {
                                    <div className="mt-4 overflow-x-auto"><table className="w-full min-w-[480px] text-left text-xs"><thead className="text-[10px] uppercase tracking-wide text-muted-foreground"><tr><th className="py-2 pr-3 font-medium">Hops</th><th className="py-2 pr-3 font-medium">Asset</th><th className="py-2 pr-3 font-medium">Category</th><th className="py-2 pr-3 font-medium">Status</th><th className="py-2 text-right font-medium">Load</th></tr></thead><tbody>
                                        {for d in snapshot.downstream {
                                            <tr key={d.identifier} className="border-t border-border/70"><td className="py-2 pr-3 tabular-nums text-muted-foreground">{str(d.hops)}</td><td className="py-2 pr-3"><span className="font-medium">{d.display_name}</span> <span className="text-muted-foreground">{d.identifier}</span>{d.criticality >= 4 and <span className="ml-1.5 rounded border border-border px-1 text-[9px] text-muted-foreground">CRITICAL</span>}</td><td className="py-2 pr-3 text-muted-foreground">{d.category}</td><td className={"py-2 pr-3 " + ("text-sky-500" if d.alternate_feed else "text-amber-500")}>{"Alternate feed" if d.alternate_feed else "De-energized"}</td><td className="py-2 text-right tabular-nums text-muted-foreground">{f"{d.load_mw:.0f}"} MW</td></tr>
                                        }}
                                    </tbody></table></div>
                                }}
                            </div>
                        }}
                        <p className="mt-4 text-[11px] leading-relaxed text-muted-foreground">Topology-only breadth-first trace over the synthetic graph. "Alternate feed" means another source path exists in the graph; link capacity and load flow are not modeled. Interrupted load counts de-energized end-use assets only.</p>
                    </section>
                    <div className="grid grid-cols-1 gap-5 xl:grid-cols-2">
                        <section className="rounded-xl border border-border bg-card p-5 shadow-sm"><h2 className="mb-3 font-semibold">Incident timeline</h2><div className="flex items-start gap-3 border-l border-border pl-4"><span className={"-ml-[21px] mt-1 size-2.5 rounded-full border-2 border-background " + ("bg-red-500" if active_faults > 0 else "bg-primary")}/><div><div className="text-sm font-medium">{(snapshot.scenario_title + " · " + snapshot.fault_label if snapshot.scenario_title != "" else snapshot.fault_label) if active_faults > 0 else "Baseline network loaded"}</div><div className="mt-1 text-xs text-muted-foreground">{(f"Fault applied at {snapshot.fault_id} · {len(snapshot.downstream)} downstream assets traced" if active_faults > 0 else "Synthetic topology initialized · ready for simulation")}</div></div></div></section>
                        <section className="rounded-xl border border-border bg-card p-5 shadow-sm"><h2 className="font-semibold">Simulation controls</h2><p className="mb-4 mt-1 text-sm text-muted-foreground">Run reproducible faults against the synthetic graph</p><label htmlFor="scenario" className="text-xs font-medium">Incident scenario</label><select id="scenario" value={scenario_id} onChange={handle_scenario} className="my-2 h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="transformer">Transformer Overheating · TR-01</option><option value="substation">Substation Failure · SUB-01</option><option value="line">Distribution Line Overload · J-01</option></select><div className="flex flex-wrap gap-2"><button onClick={handle_fault} disabled={loading} className="h-9 flex-1 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground disabled:opacity-50">Simulate fault</button><button onClick={handle_reset} disabled={loading} className="h-9 rounded-md border border-border bg-background px-4 text-sm font-medium disabled:opacity-50">Reset simulation</button></div><p className="mt-3 text-[11px] leading-relaxed text-muted-foreground">Reachability uses deterministic graph logic. No switching recommendations are produced.</p></section>
                    </div>
                </div>
                <section className="rounded-xl border border-border bg-card p-5 shadow-sm"><div className="flex items-center justify-between"><h2 className="font-semibold">Agent activity</h2><span className="rounded-full border border-border px-2 py-1 text-[10px]">UPCOMING</span></div><p className="mb-4 mt-1 text-sm text-muted-foreground">Multi-agent workflows planned for Phase 2</p><div className="flex flex-col gap-3"><div className="rounded-lg border border-border bg-background p-3"><div className="text-sm font-medium">Monitoring Agent</div><p className="mt-1 text-xs text-muted-foreground">Inactive · no runs</p></div><div className="rounded-lg border border-border bg-background p-3"><div className="text-sm font-medium">Impact Investigator</div><p className="mt-1 text-xs text-muted-foreground">Inactive · no runs</p></div><div className="rounded-lg border border-border bg-background p-3"><div className="text-sm font-medium">Recovery Planner</div><p className="mt-1 text-xs text-muted-foreground">Inactive · no runs</p></div><div className="rounded-lg border border-border bg-background p-3"><div className="text-sm font-medium">Verification Agent</div><p className="mt-1 text-xs text-muted-foreground">Inactive · no runs</p></div><div className="rounded-lg border border-border bg-background p-3"><div className="text-sm font-medium">Coordinator Agent</div><p className="mt-1 text-xs text-muted-foreground">Inactive · no runs</p></div></div><p className="mt-4 rounded-lg border border-dashed border-primary/30 bg-primary/5 p-3 text-xs leading-relaxed text-muted-foreground">Agent evidence, decisions, verification and replanning are not simulated in Phase 1.</p></section>
            </section>
            <footer className="mt-7 border-t border-border pt-4 text-[11px] leading-relaxed text-muted-foreground">Synthetic educational simulator, not an operational grid-control system. No real infrastructure is connected. No claims about actual Sri Lankan grid topology.</footer>
        </main>
    </div>;
}
