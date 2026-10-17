sv import from ...services.graphService { ScenarioInfo, list_scenarios }
sv import from ...agents.endpoints { AgentStatus, AgentRun, agent_status, list_agent_runs, run_investigation }
import from ..Sidebar { Sidebar }
import from ..Header { Header }

obj AgentRole {
    has name: str;
    has role: str;
}

# What each backend agent does (see agents/DESIGN.md); these describe the
# design, not any run.
glob AGENT_ROLES: list[AgentRole] = [
    AgentRole(name="Monitoring Agent", role="MonitoringScan walker: finds the faulted asset, de-energized assets and assets at or above 80% load."),
    AgentRole(name="Impact Investigator", role="DownstreamWalk walker: cites the incident's Evidence records, cross-checks them against the trace tool, and has the model narrate the impact."),
    AgentRole(name="Recovery Planner", role="Gets deterministic options from plan_recovery and has the model choose one."),
    AgentRole(name="Verification Agent", role="Re-runs check_option independently; a failed check sends the choice back to the planner."),
    AgentRole(name="Coordinator Agent", role="Applies the scenario, opens the incident, sequences the agents, caps re-planning at 3 iterations and writes the final recommendation.")
];

glob STEP_STATUS_CLASS: dict[str, str] = {"ok": "text-primary", "rejected": "text-amber-500", "error": "text-red-500"};
glob RUN_STATUS_CLASS: dict[str, str] = {"completed": "border-primary/40 bg-primary/10 text-primary", "failed": "border-red-500/40 bg-red-500/10 text-red-500", "not_configured": "border-border text-muted-foreground"};

def:pub AgentIntelligencePage() -> JsxElement {
    has status: AgentStatus | None = None;
    has runs: list[AgentRun] = [];
    has selected: AgentRun | None = None;
    has scenarios: list[ScenarioInfo] = [];
    has scenario_id: str = "transformer";
    has running: bool = False;
    has message: str = "";
    has error_message: str = "";

    async can with entry {
        try {
            st = await agent_status();
            status = st;
            found = await list_agent_runs();
            runs = found;
            if len(found) > 0 { selected = found[0]; }
            sc = await list_scenarios();
            scenarios = sc;
        }
        except Exception { error_message = "Could not load the agent configuration."; }
    }

    def handle_scenario(e: ChangeEvent) { scenario_id = e.target.value; }
    def select_run(run: AgentRun) { selected = run; }

    async def handle_run -> None {
        running = True;
        message = "";
        error_message = "";
        try {
            run = await run_investigation(scenario_id);
            found = await list_agent_runs();
            runs = found;
            selected = run;
            message = "Run completed." if run.status == "completed" else f"Run ended with status {run.status}.";
        }
        except Exception { error_message = "The investigation failed. Check the model token and try again."; }
        running = False;
    }

    configured = status is not None and status.configured;

    return <Sidebar>
        <Header eyebrow="PULSEGRID OPERATIONS / AGENT INTELLIGENCE" title="Agent Intelligence" subtitle="Five backend agents investigate a simulated fault; graph tools compute every number.">
            <span className={"rounded-full border px-3 py-1.5 text-xs " + ("border-primary/40 text-primary" if configured else "border-border")}>{"Checking…" if status is None and error_message == "" else ("Ready" if configured else "Not configured")}</span>
        </Header>
        {error_message != "" and <div className="rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive">{error_message}</div>}
        {message != "" and <div className="rounded-lg border border-primary/30 bg-primary/10 px-4 py-3 text-sm text-primary">{message}</div>}
        <div className="grid grid-cols-1 items-start gap-5 xl:grid-cols-2">
            <section className="rounded-xl border border-border bg-card p-5 shadow-sm">
                <h2 className="font-semibold">Run an investigation</h2>
                <p className="mt-1 text-sm text-muted-foreground">{(f"Model: {status.model}." if status is not None else "") + (" A run applies the scenario to the network, opens an incident and makes several model calls (uses your Hugging Face credit)." if configured else " Set HUGGINGFACE_API_KEY and restart the app to enable runs (see README).")}</p>
                <label htmlFor="agent-scenario" className="mt-4 block text-xs font-medium">Scenario</label>
                <select id="agent-scenario" value={scenario_id} onChange={handle_scenario} className="my-2 h-10 w-full rounded-md border border-input bg-background px-3 text-sm">
                    {for s in scenarios { <option key={s.identifier} value={s.identifier}>{s.title + " · " + s.target_id}</option> }}
                </select>
                <button onClick={handle_run} disabled={not configured or running} className="h-9 w-full rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground disabled:opacity-50">{"Running investigation…" if running else ("Run investigation" if configured else "Run investigation (not configured)")}</button>
            </section>
            <section className="rounded-xl border border-border bg-card p-5 shadow-sm">
                <h2 className="font-semibold">Agents</h2>
                <ul className="mt-3 flex flex-col gap-2">
                    {for a in AGENT_ROLES {
                        <li key={a.name} className="rounded-lg border border-border bg-background p-3"><div className="text-sm font-medium">{a.name}</div><p className="mt-1 text-xs text-muted-foreground">{a.role}</p></li>
                    }}
                </ul>
                <p className="mt-3 text-xs text-muted-foreground">Model output that cites unknown evidence or states numbers no tool produced is rejected.</p>
            </section>
        </div>
        <div className="grid grid-cols-1 items-start gap-5 xl:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)]">
            <section className="rounded-xl border border-border bg-card p-5 shadow-sm">
                <h2 className="font-semibold">Stored runs</h2>
                {if len(runs) == 0 {
                    <p className="mt-3 text-sm text-muted-foreground">No runs yet. Runs are stored only when a configured model completes or fails an investigation.</p>
                } else {
                    <ul className="mt-3 flex flex-col gap-2">
                        {for r in runs {
                            <li key={r.run_id}><button onClick={lambda (e: MouseEvent) { select_run(r); }} className={"w-full rounded-lg border p-3 text-left " + ("border-primary/50 bg-primary/10" if selected is not None and selected.run_id == r.run_id else "border-border bg-background")}>
                                <div className="flex items-center justify-between gap-2 text-xs"><span className="font-medium">{r.scenario_id + " · " + r.incident_id}</span><span className={"rounded-full border px-2 py-0.5 text-[10px] " + RUN_STATUS_CLASS.get(r.status, "border-border")}>{r.status}</span></div>
                                <p className="mt-1 text-[11px] text-muted-foreground">{f"{len(r.steps)} steps · {r.iterations} planning iterations · {r.model}"}</p>
                            </button></li>
                        }}
                    </ul>
                }}
            </section>
            <section className="rounded-xl border border-border bg-card p-5 shadow-sm" aria-live="polite">
                {if selected is None {
                    <p className="text-sm text-muted-foreground">Select a stored run to see its steps.</p>
                } else {
                    <div>
                        <h2 className="font-semibold">{"Run " + selected.run_id}</h2>
                        <p className="mt-1 text-sm text-muted-foreground">{f"{selected.scenario_id} · incident {selected.incident_id} · {selected.status}"}</p>
                        {selected.final_recommendation != "" and <div className="mt-4 rounded-lg border border-primary/30 bg-primary/5 p-3 text-sm leading-relaxed"><div className="mb-1 text-[10px] font-semibold uppercase tracking-wide text-primary">Recommendation (simulated, advisory)</div>{selected.final_recommendation}</div>}
                        <ol className="mt-4 flex flex-col gap-2">
                            {for step in selected.steps {
                                <li key={str(step.index)} className="rounded-lg border border-border bg-background p-3 text-xs">
                                    <div className="flex flex-wrap items-center justify-between gap-2"><span className="font-medium">{f"{step.index + 1}. {step.agent} · {step.action}"}</span><span className={STEP_STATUS_CLASS.get(step.status, "text-muted-foreground")}>{step.status}</span></div>
                                    <p className="mt-1 text-muted-foreground">{"Tool: " + step.tool}</p>
                                    {step.output_summary != "" and <p className="mt-1">{step.output_summary}</p>}
                                    {len(step.evidence_ids) > 0 and <p className="mt-1 text-muted-foreground">{"Evidence: " + ", ".join(step.evidence_ids)}</p>}
                                </li>
                            }}
                        </ol>
                    </div>
                }}
            </section>
        </div>
        <footer className="border-t border-border pt-4 text-[11px] leading-relaxed text-muted-foreground">Recommendations are simulated and advisory. No real-world switching or control actions exist in this system.</footer>
    </Sidebar>;
}
