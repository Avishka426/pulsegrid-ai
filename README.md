# PulseGrid AI

**Agentic Power Grid Incident Intelligence & Recovery Simulator**

PulseGrid AI is a Jac full-stack, synthetic educational distribution-grid simulator. Phase 1 provides a persistent graph model and a dashboard for a deterministic incident demonstration. It is not an operational grid-control system.

## Current phase

- Jac 0.34.23 web-app; Jac owns the graph model, server operations and browser UI.
- A deterministic 14-asset, 14-link example network is initialized on first graph read.
- The dashboard reads graph state through Jac server functions and can apply a reproducible demo fault or reset the network.
- The three scenario definitions are Transformer Overheating, Substation Failure and Distribution Line Overload.
- Agent activity is explicitly inactive. No AI investigation, agent runs, switching recommendations, or real-world topology are claimed.

All data is synthetic. There are no real infrastructure connections or automatic switching actions, and the network does not represent actual Sri Lankan grid topology. Use only for educational demonstration.

## Requirements

Install the Jac toolchain matching Jac 0.34.23 and Bun (used by Jac's client dependency installer). No API keys or paid services are needed for Phase 1.

## Run locally

```sh
jac install
jac start --dev main.jac
```

Open the app URL printed by the CLI (normally http://localhost:8000). Graph persistence is local to the Jac runtime by default; `.jac/` is generated runtime data and should not be committed. To check source:

```sh
jac check main.jac
```

## Project map

- `main.jac` — Jac application entry, endpoint registration and client mount.
- `services/graphService.jac` — native Jac node/edge graph, deterministic seed and server operations.
- `components/PulseGridDashboard.jac` — Jac client dashboard and simulation controls.
- `styles/global.css` — Tailwind v4 and themed shadcn design tokens.
- `PROJECT_PLAN.md` — delivered phase and next phase boundaries.

## Portability and configuration

The project uses standard Jac web-app tooling and project-local source. Do not commit credentials, generated dependencies or `.jac/` runtime state. `.env.example` lists optional future LLM configuration; Phase 1 does not read or require those values. JacHammer-specific project identifiers in `jac.toml` are hosting metadata and are not required for local execution.

## Hackathon implementation boundary

Core executable application logic is written in Jac. Phase 2 can add graph-evidence walkers, tested reachability/impact calculations, constraint-checked recovery strategies, and only then actual byLLM coordination with explicit provider configuration and human-readable evidence. Do not describe planned capabilities as operational until implemented and verified.
