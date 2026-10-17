sv import from ...services.graphService { Incident, IncidentDetail, list_incidents, get_incident }
import from "@jac/runtime" { Link }
import from ..Sidebar { Sidebar }
import from ..Header { Header }
import from ..status_style { status_text, status_dot, status_label }

glob INCIDENT_STATUS_CLASS: dict[str, str] = {"active": "border-red-500/40 bg-red-500/10 text-red-500", "superseded": "border-border text-muted-foreground", "resolved": "border-primary/40 bg-primary/10 text-primary"};

def:pub IncidentCenterPage() -> JsxElement {
    has incidents: list[Incident] = [];
    has detail: IncidentDetail | None = None;
    has selected_id: str = "";
    has loading: bool = True;
    has error_message: str = "";

    async def open_incident(identifier: str) -> None {
        selected_id = identifier;
        try { detail = await get_incident(identifier); }
        except Exception { error_message = "Could not load that incident."; }
    }

    async can with entry {
        try {
            found = await list_incidents();
            incidents = found;
            if len(found) > 0 { await open_incident(found[0].identifier); }
        }
        except Exception { error_message = "Could not load the incident history."; }
        loading = False;
    }

    counts: dict[str, int] = {"active": 0, "superseded": 0, "resolved": 0};
    for i in incidents { counts[i.status] = counts.get(i.status, 0) + 1; }

    return <Sidebar>
        <Header eyebrow="PULSEGRID OPERATIONS / INCIDENT CENTER" title="Incident Center" subtitle="Every simulated fault recorded on the graph, with the evidence traced for it.">
            <span className="rounded-full border border-border px-3 py-1.5 text-xs">{f"{len(incidents)} recorded · newest 20 kept"}</span>
        </Header>
        {error_message != "" and <div className="rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive">{error_message}</div>}
        <section className="grid grid-cols-3 gap-3">
            <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Active</div><div className="mt-2 text-2xl font-semibold tabular-nums text-red-500">{str(counts["active"])}</div></div>
            <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Superseded</div><div className="mt-2 text-2xl font-semibold tabular-nums">{str(counts["superseded"])}</div></div>
            <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Resolved</div><div className="mt-2 text-2xl font-semibold tabular-nums text-primary">{str(counts["resolved"])}</div></div>
        </section>
        {if len(incidents) == 0 and not loading {
            <section className="rounded-xl border border-dashed border-border bg-card/40 p-8 text-center">
                <h2 className="font-semibold">No incidents recorded yet</h2>
                <p className="mt-2 text-sm text-muted-foreground">Apply a scenario in the <Link to="/simulation" className="text-primary underline">Simulation Lab</Link> or on the <Link to="/" className="text-primary underline">Overview</Link> to record one.</p>
            </section>
        } else {
            <div className="grid grid-cols-1 items-start gap-5 xl:grid-cols-[minmax(0,1fr)_minmax(0,1.3fr)]">
                <section className="rounded-xl border border-border bg-card p-5 shadow-sm">
                    <h2 className="font-semibold">History</h2>
                    <div className="mt-3 overflow-x-auto"><table className="w-full min-w-[420px] text-left text-xs">
                        <thead className="text-[10px] uppercase tracking-wide text-muted-foreground"><tr><th className="py-2 pr-3 font-medium">Incident</th><th className="py-2 pr-3 font-medium">Scenario</th><th className="py-2 pr-3 font-medium">Fault</th><th className="py-2 font-medium">Status</th></tr></thead>
                        <tbody>
                            {for i in incidents {
                                <tr key={i.identifier} className={"border-t border-border/70 " + ("bg-primary/10" if i.identifier == selected_id else "")}>
                                    <td className="py-2 pr-3"><button className="font-medium hover:underline" onClick={lambda (e: MouseEvent) { open_incident(i.identifier); }}>{i.identifier}</button></td>
                                    <td className="py-2 pr-3">{i.scenario_title}</td>
                                    <td className="py-2 pr-3 text-muted-foreground">{i.fault_id}</td>
                                    <td className="py-2"><span className={"rounded-full border px-2 py-0.5 text-[10px] " + INCIDENT_STATUS_CLASS.get(i.status, "border-border")}>{i.status}</span></td>
                                </tr>
                            }}
                        </tbody>
                    </table></div>
                </section>
                <section className="rounded-xl border border-border bg-card p-5 shadow-sm" aria-live="polite">
                    {if detail is None {
                        <p className="text-sm text-muted-foreground">Select an incident to see its evidence.</p>
                    } else {
                        <div>
                            <div className="flex flex-wrap items-start justify-between gap-2">
                                <div><h2 className="font-semibold">{detail.incident.identifier + " · " + detail.incident.scenario_title}</h2><p className="mt-1 text-sm text-muted-foreground">{f"Fault at {detail.incident.fault_id} · {len(detail.evidence)} evidence records · sequence {detail.incident.sequence}"}</p></div>
                                <span className={"rounded-full border px-2 py-0.5 text-[10px] " + INCIDENT_STATUS_CLASS.get(detail.incident.status, "border-border")}>{detail.incident.status}</span>
                            </div>
                            <ol className="mt-4 flex flex-col gap-2">
                                {for ev in detail.evidence {
                                    <li key={ev.identifier} className="rounded-lg border border-border bg-background p-3">
                                        <div className="flex flex-wrap items-center justify-between gap-2 text-xs"><span className="font-medium">{ev.identifier}</span><span className={status_text(ev.kind)}>{status_label(ev.kind)}</span></div>
                                        <p className="mt-1 text-xs text-muted-foreground">{ev.detail}</p>
                                        <p className="mt-1 text-[11px] tabular-nums text-muted-foreground">{f"{ev.asset_id} · {ev.hops} " + ("hop" if ev.hops == 1 else "hops") + f" · {ev.value_mw:.0f} MW"}</p>
                                    </li>
                                }}
                            </ol>
                        </div>
                    }}
                </section>
            </div>
        }}
        <footer className="border-t border-border pt-4 text-[11px] leading-relaxed text-muted-foreground">Evidence is computed deterministically from the synthetic graph when a fault is applied. No real infrastructure is connected.</footer>
    </Sidebar>;
}
