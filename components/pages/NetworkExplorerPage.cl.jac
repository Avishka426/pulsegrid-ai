sv import from ...services.graphService { Infrastructure, GraphSnapshot, read_graph }
import from ..Sidebar { Sidebar }
import from ..Header { Header }
import from ..NetworkDiagram { NetworkDiagram }
import from ..status_style { status_text, status_dot, status_label }
import from ..AssetDetails { AssetDetails }

def:pub NetworkExplorerPage() -> JsxElement {
    has snapshot: GraphSnapshot = {"nodes": [], "links": [], "fault_active": False, "fault_label": "", "fault_id": "", "scenario_id": "", "scenario_title": "", "downstream": [], "interrupted_load_mw": 0.0, "critical_interrupted": 0} as GraphSnapshot;
    has loading: bool = True;
    has error_message: str = "";
    has query: str = "";
    has category: str = "all";
    has status: str = "all";
    has selected_id: str = "";

    async can with entry {
        try { snapshot = await read_graph(); }
        except Exception { error_message = "Could not load the synthetic network."; }
        loading = False;
    }

    def handle_query(e: ChangeEvent) { query = e.target.value; }
    def handle_category(e: ChangeEvent) { category = e.target.value; }
    def handle_status(e: ChangeEvent) { status = e.target.value; }
    def handle_select(identifier: str) { selected_id = identifier; }

    categories: list[str] = [];
    for n in snapshot.nodes { if n.category not in categories { categories = categories + [n.category]; } }
    needle = query.strip().lower();
    visible: list[Infrastructure] = [];
    for n in snapshot.nodes {
        text_ok = needle == "" or needle in n.identifier.lower() or needle in n.display_name.lower();
        if text_ok and (category == "all" or n.category == category) and (status == "all" or n.operational_status == status) {
            visible = visible + [n];
        }
    }
    selected_asset: Infrastructure | None = None;
    for n in snapshot.nodes { if n.identifier == selected_id { selected_asset = n; } }
    names: dict[str, str] = {};
    for n in snapshot.nodes { names[n.identifier] = n.display_name; }

    return <Sidebar>
        <Header eyebrow="PULSEGRID OPERATIONS / NETWORK EXPLORER" title="Network Explorer" subtitle="Search, filter and inspect every asset and link in the synthetic network.">
            <span className="rounded-full border border-border px-3 py-1.5 text-xs">{f"{len(snapshot.nodes)} assets · {len(snapshot.links)} links"}</span>
        </Header>
        {error_message != "" and <div className="rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive">{error_message}</div>}
        <section className="flex flex-wrap items-end gap-3 rounded-xl border border-border bg-card p-4 shadow-sm">
            <label className="flex min-w-[200px] flex-1 flex-col gap-1 text-xs font-medium">Search
                <input value={query} onChange={handle_query} placeholder="ID or name, e.g. TR-01" className="h-9 rounded-md border border-input bg-background px-3 text-sm font-normal"/>
            </label>
            <label className="flex flex-col gap-1 text-xs font-medium">Category
                <select value={category} onChange={handle_category} className="h-9 rounded-md border border-input bg-background px-3 text-sm font-normal">
                    <option value="all">All categories</option>
                    {for c in categories { <option key={c} value={c}>{c}</option> }}
                </select>
            </label>
            <label className="flex flex-col gap-1 text-xs font-medium">Status
                <select value={status} onChange={handle_status} className="h-9 rounded-md border border-input bg-background px-3 text-sm font-normal">
                    <option value="all">All statuses</option>
                    <option value="normal">Normal</option>
                    <option value="fault">Fault</option>
                    <option value="de-energized">De-energized</option>
                    <option value="alternate-feed">Alternate feed</option>
                </select>
            </label>
            <p className="pb-2 text-xs text-muted-foreground" aria-live="polite">{f"{len(visible)} of {len(snapshot.nodes)} assets shown"}</p>
        </section>
        <div className="grid grid-cols-1 items-start gap-5 2xl:grid-cols-[minmax(0,1fr)_380px]">
            <NetworkDiagram nodes={snapshot.nodes} links={snapshot.links} selected_id={selected_id} onSelect={handle_select} loading={loading} />
            <AssetDetails asset={selected_asset} links={snapshot.links} downstream={snapshot.downstream} />
        </div>
        <section className="rounded-xl border border-border bg-card p-5 shadow-sm">
            <h2 className="font-semibold">Assets</h2>
            <div className="mt-3 overflow-x-auto"><table className="w-full min-w-[640px] text-left text-xs">
                <thead className="text-[10px] uppercase tracking-wide text-muted-foreground"><tr><th className="py-2 pr-3 font-medium">Asset</th><th className="py-2 pr-3 font-medium">Category</th><th className="py-2 pr-3 font-medium">Status</th><th className="py-2 pr-3 text-right font-medium">Capacity</th><th className="py-2 pr-3 text-right font-medium">Load</th><th className="py-2 pr-3 text-right font-medium">Utilisation</th><th className="py-2 text-right font-medium">Criticality</th></tr></thead>
                <tbody>
                    {for n in visible {
                        <tr key={n.identifier} className={"border-t border-border/70 " + ("bg-primary/10" if n.identifier == selected_id else "")}>
                            <td className="py-2 pr-3"><button className="text-left hover:underline" onClick={lambda (e: MouseEvent) { handle_select(n.identifier); }}><span className="font-medium">{n.display_name}</span> <span className="text-muted-foreground">{n.identifier}</span></button></td>
                            <td className="py-2 pr-3 text-muted-foreground">{n.category}</td>
                            <td className="py-2 pr-3"><span className="flex items-center gap-1.5"><span className={"size-1.5 rounded-full " + status_dot(n.operational_status)}/>{status_label(n.operational_status)}</span></td>
                            <td className="py-2 pr-3 text-right tabular-nums">{f"{n.capacity_mw:.0f} MW"}</td>
                            <td className="py-2 pr-3 text-right tabular-nums">{f"{n.load_mw:.0f} MW"}</td>
                            <td className="py-2 pr-3 text-right tabular-nums">{f"{(n.load_mw / n.capacity_mw * 100.0 if n.capacity_mw > 0 else 0.0):.0f}%"}</td>
                            <td className="py-2 text-right tabular-nums">{str(n.criticality) + " / 5"}</td>
                        </tr>
                    }}
                </tbody>
            </table></div>
            {len(visible) == 0 and not loading and <p className="mt-3 text-sm text-muted-foreground">No assets match these filters.</p>}
        </section>
        <section className="rounded-xl border border-border bg-card p-5 shadow-sm">
            <h2 className="font-semibold">Power links</h2>
            <div className="mt-3 overflow-x-auto"><table className="w-full min-w-[520px] text-left text-xs">
                <thead className="text-[10px] uppercase tracking-wide text-muted-foreground"><tr><th className="py-2 pr-3 font-medium">Link</th><th className="py-2 pr-3 font-medium">From</th><th className="py-2 pr-3 font-medium">To</th><th className="py-2 pr-3 text-right font-medium">Capacity</th><th className="py-2 font-medium">Status</th></tr></thead>
                <tbody>
                    {for l in snapshot.links {
                        <tr key={l.identifier} className="border-t border-border/70">
                            <td className="py-2 pr-3 font-medium">{l.identifier}</td>
                            <td className="py-2 pr-3">{names.get(l.source, l.source)} <span className="text-muted-foreground">{l.source}</span></td>
                            <td className="py-2 pr-3">{names.get(l.target, l.target)} <span className="text-muted-foreground">{l.target}</span></td>
                            <td className="py-2 pr-3 text-right tabular-nums">{f"{l.capacity_mw:.0f} MW"}</td>
                            <td className="py-2"><span className="flex items-center gap-1.5"><span className={"size-1.5 rounded-full " + status_dot(l.operational_status)}/>{status_label(l.operational_status)}</span></td>
                        </tr>
                    }}
                </tbody>
            </table></div>
        </section>
        <footer className="border-t border-border pt-4 text-[11px] leading-relaxed text-muted-foreground">Synthetic educational simulator, not an operational grid-control system. No real infrastructure is connected.</footer>
    </Sidebar>;
}
