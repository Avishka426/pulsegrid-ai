# Status colours and labels shared by the pages. Exposed as functions: on Jac
# 0.34 a module-level glob in a client module is not exported to other
# client modules (the import compiles but fails in the browser).

glob _TEXT: dict[str, str] = {"normal": "text-primary", "fault": "text-red-500", "de-energized": "text-amber-500", "alternate-feed": "text-sky-500"};
glob _DOT: dict[str, str] = {"normal": "bg-primary", "fault": "bg-red-500", "de-energized": "bg-amber-500", "alternate-feed": "bg-sky-500"};
glob _LABEL: dict[str, str] = {"normal": "Normal", "fault": "Fault", "de-energized": "De-energized", "alternate-feed": "Alternate feed"};

def:pub status_text(status: str) -> str {
    return _TEXT.get(status, "text-muted-foreground");
}

def:pub status_dot(status: str) -> str {
    return _DOT.get(status, "bg-muted-foreground");
}

def:pub status_label(status: str) -> str {
    return _LABEL.get(status, status);
}
