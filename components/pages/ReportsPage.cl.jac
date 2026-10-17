sv import from ...services.graphService { GraphSnapshot, Incident, IncidentDetail, ScenarioPreview, read_graph, list_incidents, get_incident, list_scenarios, preview_scenario }
sv import from ...agents.endpoints { AgentStatus, AgentRun, agent_status, list_agent_runs }
import from ..Sidebar { Sidebar }
import from ..Header { Header }
import from ..status_style { status_text, status_dot, status_label }

def:pub ReportsPage() -> JsxElement {
    has snapshot: GraphSnapshot = {"nodes": [], "links": [], "fault_active": False, "fault_label": "", "fault_id": "", "scenario_id": "", "scenario_title": "", "downstream": [], "interrupted_load_mw": 0.0, "critical_interrupted": 0} as GraphSnapshot;
    has incidents: list[Incident] = [];
    has active: IncidentDetail | None = None;
    has previews: list[ScenarioPreview] = [];
    has agents: AgentStatus | None = None;
    has runs: list[AgentRun] = [];
    has loading: bool = True;
    has error_message: str = "";

    async can with entry {
        try {
            snap = await read_graph();
            snapshot = snap;
            found = await list_incidents();
            incidents = found;
            if snap.incident_id != "" {
                detail = await get_incident(snap.incident_id);
                active = detail;
            }
            scenarios = await list_scenarios();
            collected: list[ScenarioPreview] = [];
            for s in scenarios {
                p = await preview_scenario(s.identifier);
                collected = collected + [p];
            }
            previews = collected;
            st = await agent_status();
            agents = st;
            stored = await list_agent_runs();
            runs = stored;
        }
        except Exception { error_message = "Could not assemble the report."; }
        loading = False;
    }

    # The browser typings lack window.print, so call it through any.
    def handle_print {
        browser_window: any = window;
        browser_window.print();
    }

    by_status: dict[str, int] = {"active": 0, "superseded": 0, "resolved": 0};
    by_scenario: dict[str, int] = {};
    for i in incidents {
        by_status[i.status] = by_status.get(i.status, 0) + 1;
        by_scenario[i.scenario_title] = by_scenario.get(i.scenario_title, 0) + 1;
    }
    scenario_titles: list[str] = list(by_scenario.keys());
    completed_runs = len([r for r in runs if r.status == "completed"]);
    fault_count = len([n for n in snapshot.nodes if n.operational_status == "fault"]);

    return <Sidebar>
        <Header eyebrow="PULSEGRID OPERATIONS / REPORTS" title="Incident report" subtitle="A printable summary of the current simulation, built from live graph data.">
            <button onClick={handle_print} disabled={loading} className="h-9 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground disabled:opacity-50">Print report</button>
        </Header>
        {error_message != "" and <div className="rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive">{error_message}</div>}
        {loading and <p className="text-sm text-muted-foreground">Assembling the report…</p>}
        <section className="rounded-xl border border-border bg-card p-5 shadow-sm">
            <h2 className="font-semibold">1. Network status</h2>
            <dl className="mt-3 grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
                <div><dt className="text-xs text-muted-foreground">Assets / links</dt><dd className="mt-1 font-medium tabular-nums">{f"{len(snapshot.nodes)} / {len(snapshot.links)}"}</dd></div>
                <div><dt className="text-xs text-muted-foreground">Health</dt><dd className="mt-1 font-medium">{"Degraded" if fault_count > 0 else "Nominal"}</dd></div>
                <div><dt className="text-xs text-muted-foreground">Active fault</dt><dd className="mt-1 font-medium">{(snapshot.fault_label + " (" + snapshot.fault_id + ")") if snapshot.fault_active else "None"}</dd></div>
                <div><dt className="text-xs text-muted-foreground">End-use load interrupted</dt><dd className="mt-1 font-medium tabular-nums">{f"{snapshot.interrupted_load_mw:.0f} MW · {snapshot.critical_interrupted} critical"}</dd></div>
            </dl>
        </section>
        <section className="rounded-xl border border-border bg-card p-5 shadow-sm">
            <h2 className="font-semibold">2. Active incident</h2>
            {if active is None {
                <p className="mt-2 text-sm text-muted-foreground">No incident is active.</p>
            } else {
                <div>
                    <p className="mt-2 text-sm">{f"{active.incident.identifier} · {active.incident.scenario_title} · fault at {active.incident.fault_id} · {len(snapshot.downstream)} downstream assets"}</p>
                    <div className="mt-3 overflow-x-auto"><table className="w-full min-w-[520px] text-left text-xs">
                        <thead className="text-[10px] uppercase tracking-wide text-muted-foreground"><tr><th className="py-2 pr-3 font-medium">Evidence</th><th className="py-2 pr-3 font-medium">Kind</th><th className="py-2 pr-3 font-medium">Detail</th><th className="py-2 text-right font-medium">Load</th></tr></thead>
                        <tbody>
                            {for ev in active.evidence {
                                <tr key={ev.identifier} className="border-t border-border/70"><td className="py-2 pr-3 font-medium">{ev.identifier}</td><td className={"py-2 pr-3 " + status_text(ev.kind)}>{status_label(ev.kind)}</td><td className="py-2 pr-3 text-muted-foreground">{ev.detail}</td><td className="py-2 text-right tabular-nums">{f"{ev.value_mw:.0f} MW"}</td></tr>
                            }}
                        </tbody>
                    </table></div>
                </div>
            }}
        </section>
        <section className="rounded-xl border border-border bg-card p-5 shadow-sm">
            <h2 className="font-semibold">3. Incident history</h2>
            <p className="mt-2 text-sm text-muted-foreground">{f"{len(incidents)} recorded (newest 20 kept): {by_status['active']} active, {by_status['superseded']} superseded, {by_status['resolved']} resolved."}</p>
            {len(scenario_titles) > 0 and <ul className="mt-2 flex flex-col gap-1 text-sm">{for t in scenario_titles { <li key={t} className="flex justify-between border-t border-border/60 pt-1"><span>{t}</span><span className="tabular-nums">{str(by_scenario[t])}</span></li> }}</ul>}
        </section>
        <section className="rounded-xl border border-border bg-card p-5 shadow-sm">
            <h2 className="font-semibold">4. Scenario impact comparison</h2>
            <div className="mt-3 overflow-x-auto"><table className="w-full min-w-[560px] text-left text-xs">
                <thead className="text-[10px] uppercase tracking-wide text-muted-foreground"><tr><th className="py-2 pr-3 font-medium">Scenario</th><th className="py-2 pr-3 font-medium">Target</th><th className="py-2 pr-3 text-right font-medium">Downstream</th><th className="py-2 pr-3 text-right font-medium">De-energized</th><th className="py-2 pr-3 text-right font-medium">Alternate feed</th><th className="py-2 pr-3 text-right font-medium">Load lost</th><th className="py-2 text-right font-medium">Critical</th></tr></thead>
                <tbody>
                    {for p in previews {
                        <tr key={p.scenario_id} className="border-t border-border/70"><td className="py-2 pr-3 font-medium">{p.title}</td><td className="py-2 pr-3 text-muted-foreground">{p.target_id}</td><td className="py-2 pr-3 text-right tabular-nums">{str(len(p.downstream))}</td><td className="py-2 pr-3 text-right tabular-nums">{str(p.de_energized)}</td><td className="py-2 pr-3 text-right tabular-nums">{str(p.alternate_feed)}</td><td className="py-2 pr-3 text-right tabular-nums">{f"{p.interrupted_load_mw:.0f} MW"}</td><td className="py-2 text-right tabular-nums">{str(p.critical_interrupted)}</td></tr>
                    }}
                </tbody>
            </table></div>
        </section>
        <section className="rounded-xl border border-border bg-card p-5 shadow-sm">
            <h2 className="font-semibold">5. Agent investigations</h2>
            <p className="mt-2 text-sm text-muted-foreground">{("Agents ready on " + agents.model + ". " if agents is not None and agents.configured else "Agents not configured (no model token). ") + f"{len(runs)} stored runs, {completed_runs} completed."}</p>
            {len(runs) > 0 and runs[0].final_recommendation != "" and <p className="mt-2 rounded-lg border border-primary/30 bg-primary/5 p-3 text-sm"><span className="font-medium">{"Latest recommendation (" + runs[0].incident_id + ", simulated): "}</span>{runs[0].final_recommendation}</p>}
        </section>
        <footer className="border-t border-border pt-4 text-[11px] leading-relaxed text-muted-foreground">Synthetic educational simulator. All figures come from the synthetic graph; no real infrastructure is connected and no real-world control actions are recommended.</footer>
    </Sidebar>;
}
