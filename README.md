# PulseGrid AI

**Agentic Power Grid Incident Intelligence & Recovery Simulator**

PulseGrid AI is a Jac full-stack, synthetic educational distribution-grid simulator. Phase 1 provides a persistent graph model and a dashboard for a deterministic incident demonstration. It is not an operational grid-control system.

## Current phase

- Jac 0.16.7 full-stack app (`jaclang` + `jac-client`); Jac owns the graph model, server operations and browser UI.
- A deterministic 14-asset, 14-link example network is initialized on first graph read.
- The dashboard reads graph state through Jac server functions and can apply a reproducible demo fault or reset the network.
- The three scenarios fault one explicit asset each: Transformer Overheating → `TR-01`, Substation Failure → `SUB-01`, Distribution Line Overload → `J-01` (modelled as a fault at the West Junction distribution node).
- Fault simulation computes downstream impact with a `DownstreamTrace` walker: a deterministic breadth-first traversal of outgoing `PowerLink` edges from the faulted node, recording each reachable asset once with its hop count. The same walker, run from the power source with the faulted node blocked, identifies downstream assets that still have an alternate supply path in the graph (for example Water Works, which is also fed from Harbor Junction).
- The dashboard draws the network from graph data, colouring each asset and link as normal, fault, de-energized or alternate feed, shaping each node by category (diamond/square/triangle/hexagon/pentagon/octagon/heptagon/circle), and lists downstream assets with hops, status, load and interrupted end-use load.
- Clicking or keyboard-selecting (Enter/Space) a node in the diagram, the asset register or the downstream-impact table shows its details — category, capacity, load, criticality, status, connected links and downstream hops when faulted — in the Asset Details panel.
- The dashboard is split into reusable Jac components (`Sidebar`, `Header`, `MetricCards`, `NetworkDiagram`, `AssetDetails`, `DownstreamImpactPanel`, `IncidentTimeline`, `SimulationControls`, `AgentActivityPanel`, `RecoveryPanel`) composed by page-level shells under `components/pages/`, with sidebar navigation to real routes; routes without built content (`Network Explorer`, `Incident Center`, `Agent Intelligence`, `Simulation Lab`, `Reports`) show an explicit "not built yet" state rather than placeholder or fabricated data.
- Renders in dark mode by default (the theme toggle described in an earlier draft was never built, so this is the only mode today).
- Agent activity and recovery planning are explicitly inactive. No AI investigation, agent runs, switching recommendations, recovery options, or real-world topology are claimed.

All data is synthetic. There are no real infrastructure connections or automatic switching actions, and the network does not represent actual Sri Lankan grid topology. Use only for educational demonstration.

## Requirements

Install the Jac toolchain matching Jac 0.16.7 (`pip install jaclang jac-client`). `jac install` provisions a project-local Bun automatically for client dependencies; no separate Bun install is required. No API keys or paid services are needed for Phase 1.

## Run locally

```sh
jac install
jac start --dev main.jac
```

Open the app URL printed by the CLI (normally http://localhost:8000). Graph persistence is local to the Jac runtime by default; `.jac/` is generated runtime data and should not be committed. To check source and run the graph tests:

```sh
jac check main.jac
jac test services/graphService.jac
```

Tests live in `services/graphService.test.jac` (an annex of the service module). They build their own transient copy of the synthetic network and never touch `root`, so they do not read or modify the dashboard's persisted graph. They cover traversal order and hop counts, shared-feeder de-duplication, alternate-feed detection, each scenario's target and resulting statuses, scenario replacement, unknown-scenario rejection and reset.

## Project map

- `main.jac` — Jac application entry; defines the client routes and mounts the app.
- `services/graphService.jac` — native Jac node/edge graph, deterministic seed, downstream-trace walker and server operations.
- `services/graphService.test.jac` — traversal, scenario and reset tests.
- `components/pages/OverviewPage.cl.jac` — the stateful dashboard page; owns graph state, scenario selection and node selection, and composes the section components below.
- `components/pages/UpcomingPage.cl.jac` — shared "not built yet" page for sidebar routes with no content in this phase.
- `components/Sidebar.cl.jac`, `components/Header.cl.jac` — shared navigation shell and page header, used by every page.
- `components/MetricCards.cl.jac`, `components/NetworkDiagram.cl.jac`, `components/AssetDetails.cl.jac`, `components/DownstreamImpactPanel.cl.jac`, `components/IncidentTimeline.cl.jac`, `components/SimulationControls.cl.jac`, `components/AgentActivityPanel.cl.jac`, `components/RecoveryPanel.cl.jac` — dashboard sections.
- `components/ui/`, `lib/utils.cl.jac` — shadcn primitives and the `cn()` helper, managed by `jac add --shadcn`; never hand-edited.
- `styles/global.css` — Tailwind v4 and themed shadcn design tokens.
- `PROJECT_PLAN.md` — delivered phase and next phase boundaries.

## Known limitations

- Impact is topology-only reachability over directed links. There is no load-flow, voltage, protection or capacity modelling; "alternate feed" means a source path exists in the graph, not that it can carry the load.
- Only one fault is active at a time; applying a scenario first resets the network.
- The "end-use load" headline and interrupted-load figure both sum only assets with no outgoing links, so pass-through equipment (substations, transformers, junctions) is not double counted.
- The diagram layout coordinates for the 14 synthetic asset IDs are fixed in `components/NetworkDiagram.cl.jac`; new assets would need a layout entry.
- Category shapes are a fixed lookup over the network's 8 known categories; a new category would need a `CATEGORY_SHAPE` entry in `components/NetworkDiagram.cl.jac`.
- Endpoints are not covered by automated tests; server functions were exercised manually against a running app.

## Demo script (about 3 minutes)

1. **Baseline** — open the app; point out the Overview metrics (14 nodes, 0 incidents, Nominal health) and the synthetic-data badge.
2. **Fault** — in Simulation Controls, pick "Transformer Overheating" and click Simulate fault; the diagram recolors `TR-01` and its downstream links, and the incident timeline updates.
3. **Downstream impact** — scroll to Downstream Impact: show the hop-counted table, the de-energized vs. alternate-feed split (Water Works stays fed from Harbor Junction), and the interrupted end-use load.
4. **Node selection** — click `TR-01` in the diagram (or press Tab to it and hit Enter); Asset Details shows its category, capacity, load, criticality and connected links. Click a downstream row to inspect that asset instead.
5. **Recovery plan** — point out the Recovery panel's honest "not implemented yet" state — no fabricated recovery options.
6. **Agent activity** — point out the Agent Activity panel's "Not configured · no runs" state, and the sidebar's other routes showing an explicit "not built yet" state rather than placeholder data.
7. **Reset** — click Reset simulation to return to baseline.

## Jac language share

Handwritten executable source (`.jac` files, excluding the registry-managed `components/ui/` and `lib/utils.cl.jac`, `.jac/` runtime state, and `node_modules/`) is **100% Jac** — there is no handwritten JavaScript or TypeScript application logic. As of this phase: ~1,000 lines across `main.jac`, `services/` and `components/`, plus `styles/global.css` for Tailwind/shadcn design tokens.

## Portability and configuration

The project uses standard Jac web-app tooling and project-local source. Do not commit credentials, generated dependencies or `.jac/` runtime state. `.env.example` lists optional future LLM configuration; Phase 1 does not read or require those values. JacHammer-specific project identifiers in `jac.toml` are hosting metadata and are not required for local execution.

## Hackathon implementation boundary

Core executable application logic is written in Jac. Phase 2 can add graph-evidence walkers, tested reachability/impact calculations, constraint-checked recovery strategies, and only then actual byLLM coordination with explicit provider configuration and human-readable evidence. Do not describe planned capabilities as operational until implemented and verified.
