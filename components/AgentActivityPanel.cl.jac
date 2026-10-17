glob AGENT_NAMES: list[str] = ["Monitoring Agent", "Impact Investigator", "Recovery Planner", "Verification Agent", "Coordinator Agent"];

def:pub AgentActivityPanel() -> JsxElement {
    return <section className="rounded-xl border border-border bg-card p-5 shadow-sm"><div className="flex items-center justify-between"><h2 className="font-semibold">Agent activity</h2><span className="rounded-full border border-border px-2 py-1 text-[10px]">UPCOMING</span></div><p className="mb-4 mt-1 text-sm text-muted-foreground">Multi-agent workflows are planned for Phase 4 (see PROJECT_PLAN.md)</p><div className="flex flex-col gap-3">{for name in AGENT_NAMES {
        <div key={name} className="rounded-lg border border-border bg-background p-3"><div className="text-sm font-medium">{name}</div><p className="mt-1 text-xs text-muted-foreground">Not configured · no runs</p></div>
    }}</div><p className="mt-4 rounded-lg border border-dashed border-primary/30 bg-primary/5 p-3 text-xs leading-relaxed text-muted-foreground">Agent evidence, decisions, verification and replanning are not simulated yet. No fabricated agent output is shown.</p></section>;
}
