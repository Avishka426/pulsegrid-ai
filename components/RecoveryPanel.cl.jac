sv import from ..services.graphService { RecoveryPlan, RecoveryOption }

# The verified recovery plan for the active fault, from recovery_plan(). Every
# option, check and reason comes from deterministic graph logic.
def:pub RecoveryPanel(plan: RecoveryPlan | None, fault_active: bool) -> JsxElement {
    has open_id: str = "";

    def toggle(identifier: str) { open_id = "" if open_id == identifier else identifier; }

    options: list[RecoveryOption] = [];
    recommended_id = "";
    if plan is not None {
        options = plan.options;
        recommended_id = plan.recommended_id;
    }
    feasible_count = 0;
    for o in options { if o.feasible { feasible_count = feasible_count + 1; } }

    return <section className="rounded-xl border border-border bg-card p-5 shadow-sm">
        <div className="flex items-center justify-between gap-2"><h2 className="font-semibold">Recovery plan</h2><span className="rounded-full border border-border px-2 py-1 text-[10px]">{"VERIFIED" if len(options) > 0 else "IDLE"}</span></div>
        <p className="mb-4 mt-1 text-sm text-muted-foreground">Candidate options are generated from the graph and each one is checked against link capacity, asset capacity and donor headroom. Simulated and advisory; nothing is switched.</p>
        {if not fault_active or len(options) == 0 {
            <p className="rounded-lg border border-dashed border-border p-4 text-sm text-muted-foreground">{"No active fault, so there is nothing to plan recovery for." if not fault_active else "Computing recovery options…"}</p>
        } else {
            <div>
                <p className="mb-3 text-xs text-muted-foreground">{f"{len(options)} options · {feasible_count} pass every check · recommended: " + (recommended_id if recommended_id != "" else "none")}</p>
                <ul className="flex flex-col gap-2">
                    {for o in options {
                        <li key={o.identifier} className={"rounded-lg border p-3 " + ("border-primary/50 bg-primary/10" if o.identifier == recommended_id else "border-border bg-background")}>
                            <div className="flex flex-wrap items-center justify-between gap-2 text-xs">
                                <span className="font-medium">{o.identifier + (" · recommended" if o.identifier == recommended_id else "")}</span>
                                <span className={"rounded-full border px-2 py-0.5 text-[10px] " + ("border-primary/40 text-primary" if o.feasible else "border-red-500/40 text-red-500")}>{"passes all checks" if o.feasible else "rejected"}</span>
                            </div>
                            <ul className="mt-1 text-xs">{for a in o.actions { <li key={a.identifier}>{a.description}</li> }}</ul>
                            {len(o.restored_assets) > 0 and <p className="mt-1 text-[11px] text-muted-foreground">{f"Would restore {', '.join(o.restored_assets)} · {o.restored_load_mw:.0f} MW · {o.critical_restored} priority"}</p>}
                            {o.rejection_reason != "" and <p className="mt-1 text-[11px] text-red-500">{"Rejected by " + o.rejection_reason}</p>}
                            <button onClick={lambda (e: MouseEvent) { toggle(o.identifier); }} className="mt-2 text-[11px] text-primary hover:underline" aria-expanded={open_id == o.identifier}>{("Hide" if open_id == o.identifier else "Show") + f" {len(o.checks)} constraint checks"}</button>
                            {open_id == o.identifier and <ul className="mt-1 flex flex-col gap-0.5 text-[11px]">{for c in o.checks { <li key={c.name} className={"text-primary" if c.passed else "text-red-500"}>{("✓ " if c.passed else "✗ ") + c.name + " — " + c.detail}</li> }}</ul>}
                        </li>
                    }}
                </ul>
            </div>
        }}
    </section>;
}
