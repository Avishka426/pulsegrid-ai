import from services.graphService { read_graph, apply_fault, reset_graph, list_incidents }
import from .components.PulseGridDashboard { PulseGridDashboard }
import ".styles.global.css";
import from "@jac/runtime" { Router, Routes, Route }

def:pub app() -> JsxElement {
    return <Router><Routes><Route path="/" element={<PulseGridDashboard />} /></Routes></Router>;
}
