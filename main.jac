cl {
    import ".styles.global.css";
    import from .components.PulseGridDashboard { PulseGridDashboard }
    import from "@jac/runtime" { Router, Routes, Route }

    def:pub app() -> JsxElement {
        return <Router><Routes><Route path="/" element={<PulseGridDashboard />} /></Routes></Router>;
    }
}
