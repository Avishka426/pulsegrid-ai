sv import from ..services.graphService { Infrastructure, LinkView, DownstreamAsset }

glob STATUS_LABEL: dict[str, str] = {"normal": "Normal", "fault": "Fault", "de-energized": "De-energized", "alternate-feed": "Alternate feed"};
glob STATUS_TEXT: dict[str, str] = {"normal": "text-primary", "fault": "text-red-500", "de-energized": "text-amber-500", "alternate-feed": "text-sky-500"};

def:pub AssetDetails(asset: Infrastructure | None, links: list[LinkView], downstream: list[DownstreamAsset]) -> JsxElement {
    if asset is None {
        return <section className="rounded-xl border border-dashed border-border bg-card/40 p-5 text-sm text-muted-foreground" aria-live="polite">
            Select a node in the diagram or the asset register to see its details.
        </section>;
    }

    asset_id: str = asset.identifier;
    connected: list[LinkView] = [];
    for l in links { if l.source == asset_id or l.target == asset_id { connected.append(l); } }
    hops_text: str = "—";
    for d in downstream { if d.identifier == asset_id { hops_text = str(d.hops); } }

    return <section className="rounded-xl border border-border bg-card p-5 shadow-sm" aria-live="polite">
        <div className="flex items-start justify-between gap-2">
            <div>
                <h2 className="font-semibold">{asset.display_name}</h2>
                <p className="mt-0.5 text-xs text-muted-foreground">{asset.identifier + " · " + asset.category}</p>
            </div>
            <span className={"text-xs font-medium " + STATUS_TEXT[asset.operational_status]}>{STATUS_LABEL[asset.operational_status]}</span>
        </div>
        <dl className="mt-4 grid grid-cols-2 gap-3 text-xs sm:grid-cols-4">
            <div><dt className="text-muted-foreground">Capacity</dt><dd className="mt-1 font-medium tabular-nums">{f"{asset.capacity_mw:.0f} MW"}</dd></div>
            <div><dt className="text-muted-foreground">Load</dt><dd className="mt-1 font-medium tabular-nums">{f"{asset.load_mw:.0f} MW"}</dd></div>
            <div><dt className="text-muted-foreground">Criticality</dt><dd className="mt-1 font-medium tabular-nums">{str(asset.criticality) + " / 5"}</dd></div>
            <div><dt className="text-muted-foreground">Downstream hops</dt><dd className="mt-1 font-medium tabular-nums">{hops_text}</dd></div>
        </dl>
        <div className="mt-4">
            <div className="mb-2 text-[10px] font-semibold tracking-wide text-muted-foreground">CONNECTED LINKS · {str(len(connected))}</div>
            {if len(connected) == 0 {
                <p className="text-xs text-muted-foreground">No connected links.</p>
            }}
            {for l in connected {
                <div key={l.identifier} className="flex items-center justify-between border-b border-border/70 py-1.5 text-xs last:border-b-0">
                    <span>{l.source + " → " + l.target}</span>
                    <span className={"tabular-nums " + STATUS_TEXT[l.operational_status]}>{f"{l.capacity_mw:.0f} MW · " + STATUS_LABEL[l.operational_status]}</span>
                </div>
            }}
        </div>
    </section>;
}
