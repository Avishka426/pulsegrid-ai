def:pub Header(eyebrow: str, title: str, subtitle: str, children: any = None) -> JsxElement {
    return <header className="mb-2 flex flex-wrap items-center justify-between gap-4">
        <div>
            <div className="mb-1 flex items-center gap-2 text-xs font-medium tracking-[0.15em] text-primary">{eyebrow}</div>
            <h1 className="text-2xl font-semibold tracking-tight sm:text-3xl">{title}</h1>
            <p className="mt-1 text-sm text-muted-foreground">{subtitle}</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
            {children}
        </div>
    </header>;
}
