import from ".ui.sidebar" {
    SidebarProvider, Sidebar as SidebarRoot, SidebarHeader, SidebarContent,
    SidebarGroup, SidebarGroupLabel, SidebarMenu, SidebarMenuItem, SidebarMenuButton,
    SidebarFooter, SidebarInset, SidebarTrigger
}
import from ".ui.separator" { Separator }
import from "@jac/runtime" { Link, useLocation }

obj NavItem {
    has path: str;
    has label: str;
}

glob NAV_ITEMS: list[NavItem] = [
    NavItem(path="/", label="Overview"),
    NavItem(path="/network", label="Network Explorer"),
    NavItem(path="/incidents", label="Incident Center"),
    NavItem(path="/agents", label="Agent Intelligence"),
    NavItem(path="/simulation", label="Simulation Lab"),
    NavItem(path="/reports", label="Reports"),
];

def:pub Sidebar(children: any = None) -> JsxElement {
    location: any = useLocation();
    current_path = location.pathname;

    # Dark is the only theme. It goes on <html> so <body> and every page
    # inherit the dark tokens; a class on an inner element leaves text that
    # inherits <body>'s light-theme colour dark-on-dark.
    can with entry {
        document.documentElement.classList.add("dark");
    }

    # No className on the ui primitives: they spread every prop after their
    # own merged className, so a passed className replaces their layout classes.
    return <SidebarProvider>
        <SidebarRoot collapsible="offcanvas">
            <SidebarHeader>
                <div className="flex items-center gap-3 px-2 py-1">
                    <div className="flex size-10 items-center justify-center rounded-xl bg-primary text-primary-foreground"><span className="text-lg font-bold">P</span></div>
                    <div><div className="font-semibold tracking-tight">PulseGrid <span className="text-primary">AI</span></div><div className="text-xs text-muted-foreground">GRID INTELLIGENCE</div></div>
                </div>
            </SidebarHeader>
            <SidebarContent>
                <SidebarGroup>
                    <SidebarGroupLabel>Workspace</SidebarGroupLabel>
                    <SidebarMenu>
                        {for item in NAV_ITEMS {
                            <SidebarMenuItem key={item.path}>
                                <SidebarMenuButton asChild={True} isActive={current_path == item.path}>
                                    <Link to={item.path}>{item.label}</Link>
                                </SidebarMenuButton>
                            </SidebarMenuItem>
                        }}
                    </SidebarMenu>
                </SidebarGroup>
            </SidebarContent>
            <SidebarFooter>
                <div className="rounded-xl border border-border bg-background p-3"><div className="mb-1 flex items-center gap-2 text-xs font-medium"><span className="size-2 rounded-full bg-primary"/>DEMO ENVIRONMENT</div><p className="text-xs leading-relaxed text-muted-foreground">Synthetic educational network. No live infrastructure.</p></div>
            </SidebarFooter>
        </SidebarRoot>
        <SidebarInset>
            <header className="flex h-14 items-center gap-2 border-b border-border pl-4 pr-4">
                <SidebarTrigger />
                <div className="mr-2 flex h-4 items-stretch"><Separator orientation="vertical" /></div>
                <span className="text-xs font-medium tracking-[0.15em] text-primary">PULSEGRID OPERATIONS</span>
            </header>
            <main className="flex flex-1 flex-col gap-5 pt-5 pb-5 pl-4 pr-4 sm:pl-7 sm:pr-7 xl:pl-9 xl:pr-9">
                {children}
            </main>
        </SidebarInset>
    </SidebarProvider>;
}
