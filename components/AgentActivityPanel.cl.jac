sv import from ..agents.endpoints { AgentStatus }

glob AGENT_NAMES: list[str] = ["Monitoring Agent", "Impact Investigator", "Recovery Planner", "Verification Agent", "Coordinator Agent"];

# Shows the real agent configuration from agent_status(); `status` is None
# until it loads. Runs are started through the run_investigation endpoint;
# dashboard controls for them are not built yet.
def:pub AgentActivityPanel(status: AgentStatus | None, run_count: int, failed: bool) -> JsxElement {
    configured = status is not None and status.configured;
    badge = "CHECKING" if status is None and not failed else ("READY" if configured else "NOT CONFIGURED");
    agent_line = "Checking configuration…" if status is None and not failed else ("Ready" if configured else "Not configured · add a model token (see README)");
    summary = "Could not read the agent configuration." if failed else ("Checking the agent configuration…" if status is None else (f"Model {status.model} · {run_count} stored run" + ("" if run_count == 1 else "s") if configured else "Five backend agents are available once a model token is configured."));
    return <section className="rounded-xl border border-border bg-card p-5 shadow-sm"><div className="flex items-center justify-between"><h2 className="font-semibold">Agent activity</h2><span className="rounded-full border border-border px-2 py-1 text-[10px]">{badge}</span></div><p className="mb-4 mt-1 text-sm text-muted-foreground">{summary}</p><div className="flex flex-col gap-3">{for name in AGENT_NAMES {
        <div key={name} className="rounded-lg border border-border bg-background p-3"><div className="text-sm font-medium">{name}</div><p className="mt-1 text-xs text-muted-foreground">{agent_line}</p></div>
    }}</div><p className="mt-4 rounded-lg border border-dashed border-primary/30 bg-primary/5 p-3 text-xs leading-relaxed text-muted-foreground">Agents run on the backend through the run_investigation endpoint and cite graph evidence. Starting and viewing runs from the dashboard is upcoming. Nothing shown here is fabricated.</p></section>;
}
