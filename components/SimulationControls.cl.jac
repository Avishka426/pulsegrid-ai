def:pub SimulationControls(
    scenario_id: str, loading: bool,
    onScenarioChange: Callable[[ChangeEvent], None],
    onFault: Callable[[], None],
    onReset: Callable[[], None]
) -> JsxElement {
    return <section className="rounded-xl border border-border bg-card p-5 shadow-sm"><h2 className="font-semibold">Simulation controls</h2><p className="mb-4 mt-1 text-sm text-muted-foreground">Run reproducible faults against the synthetic graph</p><label htmlFor="scenario" className="text-xs font-medium">Incident scenario</label><select id="scenario" value={scenario_id} onChange={onScenarioChange} className="my-2 h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="transformer">Transformer Overheating · TR-01</option><option value="substation">Substation Failure · SUB-01</option><option value="line">Distribution Line Overload · J-01</option></select><div className="flex flex-wrap gap-2"><button onClick={onFault} disabled={loading} className="h-9 flex-1 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground disabled:opacity-50">Simulate fault</button><button onClick={onReset} disabled={loading} className="h-9 rounded-md border border-border bg-background px-4 text-sm font-medium disabled:opacity-50">Reset simulation</button></div><p className="mt-3 text-[11px] leading-relaxed text-muted-foreground">Reachability uses deterministic graph logic. No switching recommendations are produced.</p></section>;
}
