sv import from ..services.graphService { Infrastructure, LinkView }

glob LAYOUT: dict[str, list[int]] = {
    "SRC-01": [40, 165], "SUB-01": [160, 100], "SUB-02": [160, 270],
    "TR-01": [290, 55], "TR-02": [290, 145], "TR-03": [290, 290],
    "J-01": [420, 55], "J-02": [420, 145], "J-03": [420, 290],
    "FAC-01": [580, 20], "ZONE-01": [580, 65], "FAC-03": [580, 125], "ZONE-02": [580, 170], "FAC-02": [580, 235]
};
glob STATUS_TEXT: dict[str, str] = {"normal": "text-primary", "fault": "text-red-500", "de-energized": "text-amber-500", "alternate-feed": "text-sky-500"};
glob STATUS_DOT: dict[str, str] = {"normal": "bg-primary", "fault": "bg-red-500", "de-energized": "bg-amber-500", "alternate-feed": "bg-sky-500"};
glob STATUS_LABEL: dict[str, str] = {"normal": "Normal", "fault": "Fault", "de-energized": "De-energized", "alternate-feed": "Alternate feed"};

# Offsets (dx, dy) for a regular N-gon centered at the origin, one shape per
# category so assets are distinguishable without relying on color alone.
glob SHAPE_OFFSETS: dict[str, list[list[float]]] = {
    "diamond": [[0.0, -10.0], [10.0, 0.0], [0.0, 10.0], [-10.0, 0.0]],
    "triangle": [[0.0, -9.0], [7.79, 4.5], [-7.79, 4.5]],
    "pentagon": [[0.0, -8.0], [7.61, -2.47], [4.70, 6.47], [-4.70, 6.47], [-7.61, -2.47]],
    "hexagon": [[0.0, -8.0], [6.93, -4.0], [6.93, 4.0], [0.0, 8.0], [-6.93, 4.0], [-6.93, -4.0]],
    "heptagon": [[0.0, -8.5], [6.65, -5.3], [8.29, 1.89], [3.69, 7.66], [-3.69, 7.66], [-8.29, 1.89], [-6.65, -5.3]],
    "octagon": [[0.0, -8.5], [6.01, -6.01], [8.5, 0.0], [6.01, 6.01], [0.0, 8.5], [-6.01, 6.01], [-8.5, 0.0], [-6.01, -6.01]],
};
glob CATEGORY_SHAPE: dict[str, str] = {
    "Power source": "diamond",
    "Substation": "square",
    "Transformer": "triangle",
    "Distribution junction": "hexagon",
    "Hospital": "pentagon",
    "Water pumping station": "octagon",
    "Residential zone": "circle",
    "Industrial facility": "heptagon",
};

def _polygon_points(cx: int, cy: int, shape: str) -> str {
    offsets: list[list[float]] = SHAPE_OFFSETS[shape];
    cx_f: float = float(cx);
    cy_f: float = float(cy);
    parts: list[str] = [];
    for offset in offsets {
        dx: float = offset[0];
        dy: float = offset[1];
        parts.append(str(cx_f + dx) + "," + str(cy_f + dy));
    }
    return " ".join(parts);
}

def:pub NetworkDiagram(nodes: list[Infrastructure], links: list[LinkView], selected_id: str, onSelect: Callable[[str], None], loading: bool) -> JsxElement {
    def handle_select(identifier: str) {
        onSelect(identifier);
    }
    def handle_key(e: KeyboardEvent, identifier: str) {
        if e.key == "Enter" or e.key == " " {
            e.preventDefault();
            onSelect(identifier);
        }
    }

    return <section className="overflow-hidden rounded-xl border border-border bg-card shadow-sm">
        <header className="border-b border-border px-5 py-4"><h2 className="font-semibold">Distribution network</h2><p className="mt-1 text-sm text-muted-foreground">{f"Deterministic infrastructure graph · {len(nodes)} assets · {len(links)} links"}</p></header>
        <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_245px]">
            <div className="relative flex flex-col justify-center overflow-hidden border-b border-border bg-[radial-gradient(circle_at_center,color-mix(in_oklch,var(--primary)_8%,transparent),transparent_70%)] p-4 lg:border-b-0 lg:border-r sm:p-6">
                <div className="absolute inset-0 opacity-30 [background-image:radial-gradient(color-mix(in_oklch,var(--foreground)_22%,transparent)_1px,transparent_1px)] [background-size:22px_22px]"/>
                <svg className="relative z-10 h-auto w-full" viewBox="0 0 640 320" role="img" aria-label="Synthetic electrical network: assets coloured by simulated status, shaped by category">
                    {for l in links {
                        <line key={l.identifier} x1={LAYOUT[l.source][0]} y1={LAYOUT[l.source][1]} x2={LAYOUT[l.target][0]} y2={LAYOUT[l.target][1]} stroke="currentColor" strokeWidth={3 if l.operational_status == "fault" else 2} strokeDasharray={"6 4" if l.operational_status == "de-energized" else "none"} className={STATUS_TEXT[l.operational_status] + (" opacity-60" if l.operational_status == "normal" else "")}><title>{f"{l.identifier} · {l.source} → {l.target} · {l.capacity_mw:.0f} MW · " + STATUS_LABEL[l.operational_status]}</title></line>
                    }}
                    {for n in nodes {
                        <g key={n.identifier}
                            className={"group " + STATUS_TEXT[n.operational_status] + (" opacity-100" if n.identifier == selected_id else " opacity-90")}
                            tabIndex={0}
                            role="button"
                            aria-label={f"{n.display_name} ({n.identifier}), {n.category}, " + STATUS_LABEL[n.operational_status]}
                            aria-pressed={n.identifier == selected_id}
                            onClick={lambda (e: MouseEvent) { handle_select(n.identifier); }}
                            onKeyDown={lambda (e: KeyboardEvent) { handle_key(e, n.identifier); }}
                            style={{"cursor": "pointer", "outline": "none"}}
                        >
                            <title>{f"{n.display_name} ({n.identifier}) · {n.category} · " + STATUS_LABEL[n.operational_status]}</title>
                            <circle cx={LAYOUT[n.identifier][0]} cy={LAYOUT[n.identifier][1]} r="19" strokeWidth="2" className="fill-none stroke-foreground opacity-0 group-focus-visible:opacity-100"/>
                            {n.identifier == selected_id and <circle cx={LAYOUT[n.identifier][0]} cy={LAYOUT[n.identifier][1]} r="15" fill="none" stroke="currentColor" strokeWidth="2" strokeDasharray="3 2"/>}
                            {n.operational_status == "fault" and <circle cx={LAYOUT[n.identifier][0]} cy={LAYOUT[n.identifier][1]} r="15" fill="none" stroke="currentColor" strokeWidth="2" opacity="0.5"/>}
                            {CATEGORY_SHAPE[n.category] == "circle" and <circle cx={LAYOUT[n.identifier][0]} cy={LAYOUT[n.identifier][1]} r="9" fill="currentColor" stroke="var(--background)" strokeWidth="2"/>}
                            {CATEGORY_SHAPE[n.category] == "square" and <rect x={LAYOUT[n.identifier][0] - 8} y={LAYOUT[n.identifier][1] - 8} width="16" height="16" fill="currentColor" stroke="var(--background)" strokeWidth="2"/>}
                            {CATEGORY_SHAPE[n.category] not in ["circle", "square"] and <polygon points={_polygon_points(LAYOUT[n.identifier][0], LAYOUT[n.identifier][1], CATEGORY_SHAPE[n.category])} fill="currentColor" stroke="var(--background)" strokeWidth="2"/>}
                            <text x={LAYOUT[n.identifier][0]} y={LAYOUT[n.identifier][1] + 22} textAnchor="middle" fontSize="10" className="fill-foreground font-medium">{n.identifier}</text>
                        </g>
                    }}
                </svg>
                <div className="relative z-10 mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-[10px] text-muted-foreground"><span className="flex items-center gap-1.5"><span className="size-2 rounded-full bg-primary"/>Normal</span><span className="flex items-center gap-1.5"><span className="size-2 rounded-full bg-red-500"/>Fault</span><span className="flex items-center gap-1.5"><span className="size-2 rounded-full bg-amber-500"/>De-energized</span><span className="flex items-center gap-1.5"><span className="size-2 rounded-full bg-sky-500"/>Alternate feed</span><span className="ml-auto">Shape = category · Illustrative layout, not geographic</span></div>
            </div>
            <div className="flex flex-col gap-1 p-4"><div className="mb-2 flex items-center justify-between"><span className="text-xs font-semibold tracking-wide">ASSET REGISTER</span><span className="text-[10px] text-muted-foreground">{str(len(nodes))} NODES</span></div>{if loading { <p className="py-5 text-xs text-muted-foreground">Loading network data…</p> }}{for n in nodes {
                <div key={n.identifier}
                    className={"flex items-center gap-2 border-b border-border/70 py-2 rounded-sm px-1 " + ("bg-primary/10" if n.identifier == selected_id else "")}
                    tabIndex={0}
                    role="button"
                    aria-pressed={n.identifier == selected_id}
                    aria-label={f"Select {n.display_name}"}
                    onClick={lambda (e: MouseEvent) { handle_select(n.identifier); }}
                    onKeyDown={lambda (e: KeyboardEvent) { handle_key(e, n.identifier); }}
                    style={{"cursor": "pointer"}}
                >
                    <span className={"size-1.5 shrink-0 rounded-full " + STATUS_DOT[n.operational_status]}/><div className="min-w-0 flex-1"><div className="truncate text-xs font-medium">{n.display_name}</div><div className="text-[10px] text-muted-foreground">{n.category if n.operational_status == "normal" else n.category + " · " + STATUS_LABEL[n.operational_status]}</div></div><span className="text-[10px] tabular-nums text-muted-foreground">{f"{n.load_mw:.0f}"} MW</span>
                </div>
            }}</div>
        </div>
    </section>;
}
