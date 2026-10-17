sv import from ..services.graphService { DownstreamAsset }

def:pub DownstreamImpactPanel(
    fault_active: bool, fault_label: str, fault_id: str, scenario_title: str,
    downstream: list[DownstreamAsset], interrupted_load_mw: float, critical_interrupted: int,
    selected_id: str, onSelect: Callable[[str], None]
) -> JsxElement {
    de_energized_count: int = 0;
    for d in downstream { if not d.alternate_feed { de_energized_count = de_energized_count + 1; } }
    alternate_count: int = len(downstream) - de_energized_count;

    def handle_row_key(e: KeyboardEvent, identifier: str) {
        if e.key == "Enter" or e.key == " " {
            e.preventDefault();
            onSelect(identifier);
        }
    }

    return <section className="rounded-xl border border-border bg-card p-5 shadow-sm" aria-live="polite">
        <div className="flex flex-wrap items-start justify-between gap-2"><div><h2 className="font-semibold">Downstream impact</h2><p className="mt-1 text-sm text-muted-foreground">{f"Assets reachable from {fault_label} ({fault_id}) over directed power links" if fault_active else "Assets reachable from the faulted node over directed power links"}</p></div>{fault_active and <span className="rounded-full border border-red-500/40 bg-red-500/10 px-2 py-1 text-[10px] text-red-500">{scenario_title if scenario_title != "" else "Fault active"}</span>}</div>
        {if not fault_active {
            <p className="mt-4 rounded-lg border border-dashed border-border p-4 text-sm text-muted-foreground">No active fault. Simulate a scenario to trace downstream assets from the faulted node.</p>
        } else {
            <div>
                <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
                    <div className="rounded-lg border border-border bg-background p-3"><div className="text-xl font-semibold tabular-nums">{str(len(downstream))}</div><div className="text-[11px] text-muted-foreground">Downstream assets</div></div>
                    <div className="rounded-lg border border-border bg-background p-3"><div className="text-xl font-semibold tabular-nums text-amber-500">{str(de_energized_count)}</div><div className="text-[11px] text-muted-foreground">De-energized</div></div>
                    <div className="rounded-lg border border-border bg-background p-3"><div className="text-xl font-semibold tabular-nums text-sky-500">{str(alternate_count)}</div><div className="text-[11px] text-muted-foreground">Alternate feed path</div></div>
                    <div className="rounded-lg border border-border bg-background p-3"><div className="text-xl font-semibold tabular-nums">{f"{interrupted_load_mw:.0f}"} MW</div><div className="text-[11px] text-muted-foreground">{f"End-use load interrupted · {critical_interrupted} critical"}</div></div>
                </div>
                {if len(downstream) == 0 {
                    <p className="mt-4 text-sm text-muted-foreground">The faulted asset has no downstream links.</p>
                } else {
                    <div className="mt-4 overflow-x-auto"><table className="w-full min-w-[480px] text-left text-xs"><thead className="text-[10px] uppercase tracking-wide text-muted-foreground"><tr><th className="py-2 pr-3 font-medium">Hops</th><th className="py-2 pr-3 font-medium">Asset</th><th className="py-2 pr-3 font-medium">Category</th><th className="py-2 pr-3 font-medium">Status</th><th className="py-2 text-right font-medium">Load</th></tr></thead><tbody>
                        {for d in downstream {
                            <tr key={d.identifier}
                                className={"cursor-pointer border-t border-border/70 " + ("bg-primary/10" if d.identifier == selected_id else "")}
                                tabIndex={0}
                                role="button"
                                aria-pressed={d.identifier == selected_id}
                                onClick={lambda (e: MouseEvent) { onSelect(d.identifier); }}
                                onKeyDown={lambda (e: KeyboardEvent) { handle_row_key(e, d.identifier); }}
                            >
                                <td className="py-2 pr-3 tabular-nums text-muted-foreground">{str(d.hops)}</td><td className="py-2 pr-3"><span className="font-medium">{d.display_name}</span> <span className="text-muted-foreground">{d.identifier}</span>{d.criticality >= 4 and <span className="ml-1.5 rounded border border-border px-1 text-[9px] text-muted-foreground">CRITICAL</span>}</td><td className="py-2 pr-3 text-muted-foreground">{d.category}</td><td className={"py-2 pr-3 " + ("text-sky-500" if d.alternate_feed else "text-amber-500")}>{"Alternate feed" if d.alternate_feed else "De-energized"}</td><td className="py-2 text-right tabular-nums text-muted-foreground">{f"{d.load_mw:.0f}"} MW</td>
                            </tr>
                        }}
                    </tbody></table></div>
                }}
            </div>
        }}
        <p className="mt-4 text-[11px] leading-relaxed text-muted-foreground">Topology-only breadth-first trace over the synthetic graph. "Alternate feed" means another source path exists in the graph; link capacity and load flow are not modeled. Interrupted load counts de-energized end-use assets only.</p>
    </section>;
}
