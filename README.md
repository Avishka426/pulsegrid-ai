# PulseGrid AI

**Agentic Power Grid Incident Intelligence & Recovery Simulator**

PulseGrid AI is a Jac full-stack, synthetic educational distribution-grid simulator. Phase 1 provides a persistent graph model and a dashboard for a deterministic incident demonstration. It is not an operational grid-control system.

## Current phase

- Jac 0.37.x web-app; Jac owns the graph model, server operations and browser UI.
- A deterministic 14-asset, 14-link example network is initialized on first graph read.
- The dashboard reads graph state through Jac server functions and can apply a reproducible demo fault or reset the network.
- The three scenarios fault one explicit asset each: Transformer Overheating → `TR-01`, Substation Failure → `SUB-01`, Distribution Line Overload → `J-01` (modelled as a fault at the West Junction distribution node).
- Fault simulation computes downstream impact with a `DownstreamTrace` walker: a deterministic breadth-first traversal of outgoing `PowerLink` edges from the faulted node, recording each reachable asset once with its hop count. The same walker, run from the power source with the faulted node blocked, identifies downstream assets that still have an alternate supply path in the graph (for example Water Works, which is also fed from Harbor Junction).
- The dashboard draws the network from graph data, colouring each asset and link as normal, fault, de-energized or alternate feed, and lists downstream assets with hops, status, load and interrupted end-use load.
- Agent activity is explicitly inactive. No AI investigation, agent runs, switching recommendations, or real-world topology are claimed.

All data is synthetic. There are no real infrastructure connections or automatic switching actions, and the network does not represent actual Sri Lankan grid topology. Use only for educational demonstration.

## Requirements

Install the Jac CLI, version 0.37.x (verified with 0.37.25). No API keys or paid services are needed for Phase 1.

## Run locally

```sh
jac install
jac run --dev
```

Open the app URL printed by the CLI (normally http://localhost:8000; use `--port` to change it). `jac run --show` prints what will be served without starting it. Graph persistence is local to the Jac runtime by default; `.jac/` is generated runtime data and should not be committed. To check source and run the graph tests:

```sh
jac check main.jac
jac test
```

Tests live in `services/graphService.test.jac` (an annex of the service module). They build their own transient copy of the synthetic network and never touch `root`, so they do not read or modify the dashboard's persisted graph. They cover traversal order and hop counts, shared-feeder de-duplication, alternate-feed detection, each scenario's target and resulting statuses, scenario replacement, unknown-scenario rejection and reset.

## Project map

- `main.jac` — Jac application entry, endpoint registration and client mount.
- `services/graphService.jac` — native Jac node/edge graph, deterministic seed, downstream-trace walker and server operations.
- `services/graphService.test.jac` — traversal, scenario and reset tests.
- `components/PulseGridDashboard.jac` — Jac client dashboard and simulation controls.
- `styles/global.css` — Tailwind v4 and themed shadcn design tokens.
- `PROJECT_PLAN.md` — delivered phase and next phase boundaries.

## Known limitations

- Impact is topology-only reachability over directed links. There is no load-flow, voltage, protection or capacity modelling; "alternate feed" means a source path exists in the graph, not that it can carry the load.
- Only one fault is active at a time; applying a scenario first resets the network.
- Interrupted load sums de-energized end-use assets (assets with no outgoing links) to avoid double counting. The "modeled load" headline figure still sums every asset's `load_mw`, including pass-through equipment, so it overstates total demand.
- The diagram layout coordinates for the 14 synthetic asset IDs are fixed in the dashboard component; new assets would need a layout entry.
- Endpoints are not covered by automated tests; server functions were exercised manually against a running app.

## Portability and configuration

The project uses standard Jac web-app tooling and project-local source. Do not commit credentials, generated dependencies or `.jac/` runtime state. `.env.example` lists optional future LLM configuration; Phase 1 does not read or require those values. JacHammer-specific project identifiers in `jac.toml` (`[jachammer]`, `[jacpack]`) are hosting metadata and are not required for local execution. The project moved from Jac 0.34.23 to 0.37.x so it can be installed and run from a fresh clone; a JacHammer workspace still on 0.34.23 may not run it (0.37 changed `jac.toml` keys and removed `sv import`).

## Hackathon implementation boundary

Core executable application logic is written in Jac. Phase 2 can add graph-evidence walkers, tested reachability/impact calculations, constraint-checked recovery strategies, and only then actual byLLM coordination with explicit provider configuration and human-readable evidence. Do not describe planned capabilities as operational until implemented and verified.
