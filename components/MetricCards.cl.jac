def:pub MetricCards(node_count: int, active_faults: int, critical_count: int, health: str, end_use_load_mw: float) -> JsxElement {
    return <section className="grid grid-cols-2 gap-3 xl:grid-cols-4">
        <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Network nodes</div><div className="mt-3 text-3xl font-semibold tabular-nums">{str(node_count)}</div><div className="mt-1 text-xs text-muted-foreground">Connected assets</div></div>
        <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Active incidents</div><div className="mt-3 text-3xl font-semibold tabular-nums">{str(active_faults)}</div><div className="mt-1 text-xs text-muted-foreground">Deterministic simulation</div></div>
        <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Critical facilities</div><div className="mt-3 text-3xl font-semibold tabular-nums">{str(critical_count)}</div><div className="mt-1 text-xs text-muted-foreground">Priority-rated assets</div></div>
        <div className="rounded-xl border border-border bg-card p-4 shadow-sm"><div className="text-sm text-muted-foreground">Network health</div><div className="mt-3 text-3xl font-semibold">{health}</div><div className="mt-1 text-xs text-muted-foreground">{f"{end_use_load_mw:.0f}"} MW end-use load</div></div>
    </section>;
}
