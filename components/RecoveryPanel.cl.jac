def:pub RecoveryPanel(fault_active: bool) -> JsxElement {
    return <section className="rounded-xl border border-border bg-card p-5 shadow-sm"><div className="flex items-center justify-between"><h2 className="font-semibold">Recovery plan</h2><span className="rounded-full border border-border px-2 py-1 text-[10px]">UPCOMING</span></div><p className="mb-4 mt-1 text-sm text-muted-foreground">Constrained recovery planning is planned for Phase 3 (see PROJECT_PLAN.md)</p>
        {if not fault_active {
            <p className="rounded-lg border border-dashed border-border p-4 text-sm text-muted-foreground">No active fault, so there is nothing to plan recovery for.</p>
        } else {
            <p className="rounded-lg border border-dashed border-border p-4 text-sm text-muted-foreground">Recovery planning is not implemented yet. No candidate actions, constraint checks, or recommendations are generated for this fault.</p>
        }}
        <div className="mt-4 flex flex-wrap gap-2"><button disabled={True} className="h-9 flex-1 rounded-md border border-border bg-background px-4 text-sm font-medium text-muted-foreground opacity-50" aria-disabled="true">Simulate recovery (not available)</button></div>
    </section>;
}
