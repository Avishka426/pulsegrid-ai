sv import from ...services.graphService { ScenarioInfo, ScenarioPreview, list_scenarios, preview_scenario, read_graph, apply_fault, reset_graph }
import from "@jac/runtime" { useNavigate }
import from ..Sidebar { Sidebar }
import from ..Header { Header }

def:pub SimulationLabPage() -> JsxElement {
    has scenarios: list[ScenarioInfo] = [];
    has previews: list[ScenarioPreview] = [];
    has active_scenario: str = "";
    has busy: bool = False;
    has loading: bool = True;
    has error_message: str = "";
    navigate: any = useNavigate();

    async can with entry {
        try {
            found = await list_scenarios();
            scenarios = found;
            collected: list[ScenarioPreview] = [];
            for s in found {
                p = await preview_scenario(s.identifier);
                collected = collected + [p];
            }
            previews = collected;
            snap = await read_graph();
            active_scenario = snap.scenario_id;
        }
        except Exception { error_message = "Could not load the scenarios."; }
        loading = False;
    }

    async def apply(scenario_id: str) -> None {
        busy = True;
        try {
            await apply_fault(scenario_id);
            navigate("/");
        }
        except Exception { error_message = "Could not apply the scenario."; busy = False; }
    }

    async def handle_reset -> None {
        busy = True;
        try {
            await reset_graph();
            active_scenario = "";
        }
        except Exception { error_message = "Reset failed."; }
        busy = False;
    }

    return <Sidebar>
        <Header eyebrow="PULSEGRID OPERATIONS / SIMULATION LAB" title="Simulation Lab" subtitle="Compare every scenario's impact before applying one. Previews run on a copy of the network.">
            <button onClick={handle_reset} disabled={busy or active_scenario == ""} className="h-9 rounded-md border border-border bg-background px-4 text-sm font-medium disabled:opacity-50">Reset network</button>
        </Header>
        {error_message != "" and <div className="rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive">{error_message}</div>}
        <p className="text-sm text-muted-foreground">{("Active on the network: " + active_scenario + ".") if active_scenario != "" else "No scenario is applied to the network right now."}</p>
        {loading and <p className="text-sm text-muted-foreground">Computing scenario previews…</p>}
        <div className="grid grid-cols-1 items-stretch gap-5 xl:grid-cols-3">
            {for p in previews {
                <section key={p.scenario_id} className={"flex flex-col rounded-xl border bg-card p-5 shadow-sm " + ("border-red-500/50" if p.scenario_id == active_scenario else "border-border")}>
                    <div className="flex items-start justify-between gap-2"><h2 className="font-semibold">{p.title}</h2>{p.scenario_id == active_scenario and <span className="rounded-full border border-red-500/40 bg-red-500/10 px-2 py-0.5 text-[10px] text-red-500">Active</span>}</div>
                    <p className="mt-1 text-sm text-muted-foreground">{f"Faults {p.target_name} ({p.target_id})"}</p>
                    <dl className="mt-4 grid grid-cols-2 gap-3 text-xs">
                        <div className="rounded-lg border border-border bg-background p-3"><dt className="text-muted-foreground">Downstream assets</dt><dd className="mt-1 text-lg font-semibold tabular-nums">{str(len(p.downstream))}</dd></div>
                        <div className="rounded-lg border border-border bg-background p-3"><dt className="text-muted-foreground">End-use load lost</dt><dd className="mt-1 text-lg font-semibold tabular-nums">{f"{p.interrupted_load_mw:.0f} MW"}</dd></div>
                        <div className="rounded-lg border border-border bg-background p-3"><dt className="text-muted-foreground">De-energized</dt><dd className="mt-1 text-lg font-semibold tabular-nums text-amber-500">{str(p.de_energized)}</dd></div>
                        <div className="rounded-lg border border-border bg-background p-3"><dt className="text-muted-foreground">Alternate feed</dt><dd className="mt-1 text-lg font-semibold tabular-nums text-sky-500">{str(p.alternate_feed)}</dd></div>
                    </dl>
                    <p className="mt-3 text-xs text-muted-foreground">{f"{p.critical_interrupted} critical facility interrupted" if p.critical_interrupted == 1 else f"{p.critical_interrupted} critical facilities interrupted"}</p>
                    <ul className="mt-3 flex flex-1 flex-col gap-1 text-xs">
                        {for d in p.downstream {
                            <li key={d.identifier} className="flex items-center justify-between gap-2 border-t border-border/60 pt-1"><span>{d.display_name} <span className="text-muted-foreground">{d.identifier}</span></span><span className={"text-sky-500" if d.alternate_feed else "text-amber-500"}>{f"{d.hops} hop" + ("" if d.hops == 1 else "s")}</span></li>
                        }}
                    </ul>
                    <button onClick={lambda (e: MouseEvent) { apply(p.scenario_id); }} disabled={busy} className="mt-4 h-9 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground disabled:opacity-50">Apply to network</button>
                </section>
            }}
        </div>
        <footer className="border-t border-border pt-4 text-[11px] leading-relaxed text-muted-foreground">Topology-only reachability on a synthetic network; link capacity and load flow are not modeled. Applying a scenario changes only the simulation.</footer>
    </Sidebar>;
}
