import from ..Sidebar { Sidebar }
import from ..Header { Header }

def:pub UpcomingPage(nav_label: str, description: str) -> JsxElement {
    return <Sidebar>
        <Header eyebrow="PULSEGRID OPERATIONS" title={nav_label} subtitle="Not built in this phase yet.">
            <span className="rounded-full border border-border px-3 py-1.5 text-xs">Upcoming</span>
        </Header>
        <div className="flex min-h-[320px] flex-1 items-center justify-center">
            <div className="max-w-md rounded-xl border border-dashed border-border bg-card/40 p-8 text-center">
                <h2 className="font-semibold">{nav_label} is not built yet</h2>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{description}</p>
            </div>
        </div>
        <footer className="mt-2 border-t border-border pt-4 text-[11px] leading-relaxed text-muted-foreground">Synthetic educational simulator, not an operational grid-control system. No real infrastructure is connected.</footer>
    </Sidebar>;
}
