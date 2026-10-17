# PulseGrid AI

**Agentic Power Grid Incident Intelligence & Recovery Simulator**

PulseGrid AI is a Jac full-stack, synthetic educational distribution-grid simulator. Phase 1 provides a persistent graph model and a dashboard for a deterministic incident demonstration. It is not an operational grid-control system.

## Current phase

- Jac 0.34.23 web-app (the stable 0.34 line); Jac owns the graph model, server operations and browser UI.
- A deterministic 14-asset, 14-link example network is initialized on first graph read.
- The dashboard reads graph state through Jac server functions and can apply a reproducible demo fault or reset the network.
- The three scenarios fault one explicit asset each: Transformer Overheating → `TR-01`, Substation Failure → `SUB-01`, Distribution Line Overload → `J-01` (modelled as a fault at the West Junction distribution node).
- Fault simulation computes downstream impact with a `DownstreamTrace` walker: a deterministic breadth-first traversal of outgoing `PowerLink` edges from the faulted node, recording each reachable asset once with its hop count. The same walker, run from the power source with the faulted node blocked, identifies downstream assets that still have an alternate supply path in the graph (for example Water Works, which is also fed from Harbor Junction).
- Each simulated fault records an `Incident` node (`INC-0001`, `INC-0002`, … from a per-graph counter, not the clock) linked by `HasEvidence` edges to `Evidence` nodes: one for the faulted asset and one per downstream asset, in breadth-first order, with stable IDs such as `INC-0001/EV-03`. A new fault marks the previous incident `superseded`, reset marks it `resolved`, and the newest 20 incidents are kept. `GraphSnapshot` carries the active `incident_id` and its `evidence`; `list_incidents` returns the history, newest first.
- Typed recovery-planning contracts (`RecoveryAction`, `ConstraintCheck`, `RecoveryOption`, `RecoveryPlan`) are defined in `services/models.jac` for upcoming work. Nothing produces them yet, and no recovery plan is generated or shown.
- The dashboard draws the network from graph data, colouring each asset and link as normal, fault, de-energized or alternate feed, shaping each node by category (diamond/square/triangle/hexagon/pentagon/octagon/heptagon/circle), and lists downstream assets with hops, status, load and interrupted end-use load.
- Clicking or keyboard-selecting (Enter/Space) a node in the diagram, the asset register or the downstream-impact table shows its details — category, capacity, load, criticality, status, connected links and downstream hops when faulted — in the Asset Details panel.
- The dashboard is split into reusable Jac components (`Sidebar`, `Header`, `MetricCards`, `NetworkDiagram`, `AssetDetails`, `DownstreamImpactPanel`, `IncidentTimeline`, `SimulationControls`, `AgentActivityPanel`, `RecoveryPanel`) composed by page-level shells under `components/pages/`, with sidebar navigation to real routes; routes without built content (`Network Explorer`, `Incident Center`, `Agent Intelligence`, `Simulation Lab`, `Reports`) show an explicit "not built yet" state rather than placeholder or fabricated data.
- Renders in dark mode by default (the theme toggle described in an earlier draft was never built, so this is the only mode today).
- Five investigation agents run through backend endpoints when a model token is configured (see [Agents](#agents)). The dashboard's Agent activity panel shows the real state from `agent_status` and `list_agent_runs` (not configured, or ready with the model name and stored run count). Starting and viewing runs from the dashboard is upcoming. No real-world switching or real topology is claimed.

All data is synthetic. There are no real infrastructure connections or automatic switching actions, and the network does not represent actual Sri Lankan grid topology. Use only for educational demonstration.

## Requirements

Install the Jac CLI 0.34.23 (the official native binary):

```sh
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash -s -- --version 0.34.23
```

No API keys or paid services are needed to run the simulator. The agents need a free Hugging Face token (see [AI model configuration](#ai-model-configuration)).

## Run locally

```sh
jac install
jac start --dev main.jac
```

Open the app URL printed by the CLI (normally http://localhost:8000; use `--port` to change it). Graph persistence is local to the Jac runtime by default; `.jac/` is generated runtime data and should not be committed. To check source and run the graph tests:

```sh
jac check main.jac
jac test
```

Tests live in `services/tests/` (`*_tests.jac`, with shared helpers in `fixtures.jac`), plus HTTP endpoint tests in `services/tests/test_endpoints.py`, a pytest file because Jac 0.34 runs `JacTestClient` from Python (`jac guide jac-testing`). `jac.toml` sets `[test] directory = "."` so `jac test` collects all of them. If tests are slow on a poor connection, `export LITELLM_LOCAL_MODEL_COST_MAP=True` stops LiteLLM fetching its price list at import. They build their own transient copy of the synthetic network and never touch `root`, so they do not read or modify the dashboard's persisted graph. They cover traversal order and hop counts, shared-feeder de-duplication, alternate-feed detection, each scenario's target and resulting statuses, scenario replacement, unknown-scenario rejection, reset and incident evidence. `services/tests/endpoints_tests.jac` exercises the HTTP endpoints through `JacTestClient`, each test with its own temporary store, so it never touches the dev graph either.

## Project map

- `main.jac` — Jac application entry, endpoint registration and client mount.
- `services/models.jac` — `Infrastructure` node, `PowerLink` edge, view objects and status constants.
- `services/seed.jac` — deterministic 14-asset network and first-use seeding on `root`.
- `services/walkers.jac` — `DownstreamTrace` walker and downstream/alternate-feed analysis.
- `services/scenarios.jac` — scenario definitions and fault/reset state transitions.
- `services/incidents.jac` — incident records, evidence and history.
- `services/views.jac` — link views and the `GraphSnapshot` returned to clients.
- `services/graphService.jac` — server endpoints (`read_graph`, `apply_fault`, `reset_graph`, `list_incidents`); re-exports the types clients import.
- `services/tests/` — traversal, scenario, view, reset, incident and endpoint tests.
- `components/pages/OverviewPage.cl.jac` — the stateful dashboard page; owns graph state, scenario selection and node selection, and composes the section components below.
- `components/pages/UpcomingPage.cl.jac` — shared "not built yet" page for sidebar routes with no content in this phase.
- `components/Sidebar.cl.jac`, `components/Header.cl.jac` — shared navigation shell and page header, used by every page.
- `components/MetricCards.cl.jac`, `components/NetworkDiagram.cl.jac`, `components/AssetDetails.cl.jac`, `components/DownstreamImpactPanel.cl.jac`, `components/IncidentTimeline.cl.jac`, `components/SimulationControls.cl.jac`, `components/AgentActivityPanel.cl.jac`, `components/RecoveryPanel.cl.jac` — dashboard sections.
- `components/ui/`, `lib/utils.jac` — shadcn primitives and the `cn()` helper, managed by `jac install --shadcn`; never hand-edited.
- `styles/global.css` — Tailwind v4 and themed shadcn design tokens.
- `PROJECT_PLAN.md` — delivered phase and next phase boundaries.

## Agents

`agents/` adds five agents that investigate a simulated fault. Graph tools compute every number; the model only writes prose and chooses among options that code generated.

1. **Monitoring Agent** (`MonitoringScan` walker): finds the faulted asset, de-energized assets and assets at or above 80% load.
2. **Impact Investigator** (`DownstreamWalk` walker): cites the incident's `Evidence` records, cross-checks them against the trace tool and its own walk, and has the model narrate the impact.
3. **Recovery Planner**: gets deterministic options from `plan_recovery` and has the model choose one.
4. **Verification Agent**: re-runs `check_option` independently and records the checks on the option. A failure goes back to the planner.
5. **Coordinator Agent**: applies the scenario, opens the `Incident`, sequences the agents, caps re-planning at 3 iterations, and has the model write the final recommendation.

Model output is rejected if it cites evidence IDs that don't exist or states numbers no tool produced.

**Configuration.** By default the agents use `huggingface/openai/gpt-oss-120b` with a free Hugging Face token; see [AI model configuration](#ai-model-configuration) and `.env.example`. Run `jac install` so byLLM's dependencies are in `.jac/venv`. Without a key, `agent_status()` reports `configured: false` and `run_investigation` returns `not_configured` with no steps. Nothing is faked, stored, or applied to the graph.

**Endpoints:** `agent_status`, `run_investigation(scenario_id)`, `list_agent_runs`, `get_agent_run(run_id)`. Completed and failed runs are stored on the graph as `AgentRunRecord` nodes with their steps, linked by `incident_id` to the incident they opened.

**Tests:** `agents/tests/*_tests.jac` (run with `jac test`) use MockLLM, so no key is needed.

`plan_recovery` and `check_option` in `agents/tools.jac` are provisional implementations of the `services/models.jac` recovery contract until the services planner lands. Design and status: `agents/DESIGN.md`.

## Known limitations

- macOS 26: if `jac install` fails with `ensurepip is not available` (the bundled Python's `pyexpat` cannot find `_XML_SetAllocTrackerActivationThreshold` in the system libexpat), run `brew install expat`, then `DYLD_LIBRARY_PATH=/opt/homebrew/opt/expat/lib jac install` once.

- Agents: with a real model, the choice and wording vary between runs (the numbers do not). The number check is lexical: it catches invented figures, not flawed reasoning about real ones. Runs are synchronous (several model calls). Runs from anonymous users share one guest graph.

- Impact is topology-only reachability over directed links. There is no load-flow, voltage, protection or capacity modelling; "alternate feed" means a source path exists in the graph, not that it can carry the load.
- Only one fault is active at a time; applying a scenario first resets the network.
- The "end-use load" headline and interrupted-load figure both sum only assets with no outgoing links, so pass-through equipment (substations, transformers, junctions) is not double counted.
- The diagram layout coordinates for the 14 synthetic asset IDs are fixed in `components/NetworkDiagram.cl.jac`; new assets would need a layout entry.
- Category shapes are a fixed lookup over the network's 8 known categories; a new category would need a `CATEGORY_SHAPE` entry in `components/NetworkDiagram.cl.jac`.
- The registry-managed `components/ui/` primitives spread every prop onto the DOM after their own merged `className`. Passing `className` to a primitive replaces its built-in classes, so components wrap primitives instead; and `SidebarMenuButton`'s `asChild`/`isActive` props trigger React development-only "unknown prop" console warnings. Both come from the upstream registry (identical when regenerated with `jac install --shadcn`); `components/ui/` is not hand-edited.
- Endpoint tests run through `JacTestClient` with a temporary store per test. The one-time upgrade of graphs stored before the `services/` split (see `services/seed.jac`) was verified manually, not by an automated test.
- Scenarios are static definitions (`obj`), not graph entities; only incidents and evidence are stored on the graph.

## AI model configuration

The agents use byLLM with an open-weight model served through Hugging Face Inference Providers.

The default model is `huggingface/openai/gpt-oss-120b` (Apache-2.0, not gated, served by several providers). Create a free Hugging Face access token at huggingface.co/settings/tokens (fine-grained, with "Make calls to Inference Providers"), then export it before starting the app:

```sh
export HUGGINGFACE_API_KEY=hf_...
jac start --dev main.jac
```

- Jac does not load `.env` for `jac start`, so export the variable in your shell or shell profile. Never commit a real token.
- Free Hugging Face accounts get a small monthly inference credit, so heavy use may need a paid plan. Check usage at huggingface.co/settings/billing.
- To use another model, set `LLM_MODEL`, for example `huggingface/groq/openai/gpt-oss-120b` to pin a provider, or `huggingface/Qwen/Qwen3-235B-A22B-Instruct-2507`. Other providers byLLM supports (OpenAI, Anthropic, Ollama, local models) read their own key variables.
- Without a token, `agent_status()` reports `configured: false` and `run_investigation` returns `not_configured`; nothing is faked.

## Demo script (about 3 minutes)

1. **Baseline** — open the app; point out the Overview metrics (14 nodes, 0 incidents, Nominal health) and the synthetic-data badge.
2. **Fault** — in Simulation Controls, pick "Transformer Overheating" and click Simulate fault; the diagram recolors `TR-01` and its downstream links, and the incident timeline updates.
3. **Downstream impact** — scroll to Downstream Impact: show the hop-counted table, the de-energized vs. alternate-feed split (Water Works stays fed from Harbor Junction), and the interrupted end-use load.
4. **Node selection** — click `TR-01` in the diagram (or press Tab to it and hit Enter); Asset Details shows its category, capacity, load, criticality and connected links. Click a downstream row to inspect that asset instead.
5. **Recovery plan** — point out the Recovery panel's honest "not implemented yet" state — no fabricated recovery options.
6. **Agent activity** — the Agent activity panel reads the real configuration: "Not configured" with no token, or "Ready" with the model name and stored run count once `HUGGINGFACE_API_KEY` is set. The sidebar's other routes show an explicit "not built yet" state rather than placeholder data.
7. **Reset** — click Reset simulation to return to baseline.

## Jac language share

Handwritten executable source is about **97% Jac** (2,610 lines of `.jac` across `main.jac`, `services/`, `agents/` and `components/`, excluding the registry-managed `components/ui/` and `lib/`, `.jac/` runtime state and `node_modules/`). The only non-Jac handwritten file is the 76-line pytest endpoint test `services/tests/test_endpoints.py`, which Jac 0.34 requires for `JacTestClient`. There is no handwritten JavaScript or TypeScript.

## Portability and configuration

The project uses standard Jac web-app tooling and project-local source. Do not commit credentials, generated dependencies or `.jac/` runtime state. `.env.example` lists the optional AI agent configuration (see below); the current app does not read or require it. JacHammer-specific project identifiers in `jac.toml` (`[jachammer]`, `[jacpack]`) are hosting metadata and are not required for local execution. **Jac version:** the project is pinned to **0.34.23**. The hackathon organisers recommend the stable 0.34 line over the newer 0.37 line, and 0.34.23 is also what JacHammer runs. Do not use 0.37 syntax here: 0.37 changed `jac.toml` keys, replaced `sv import` with inferred placement and moved `JacTestClient`. The 0.34.23 release ships native binaries for macOS (Apple silicon) and Linux (arm64) only. On an Intel Mac, Windows or x86 Linux, use the official Docker image `jaseci/jaclang:0.34.23` (amd64 and arm64), for example `docker run --rm -it -p 8000:8000 -v "$(pwd):/app" -w /app --entrypoint bash jaseci/jaclang:0.34.23`, then `jac install` and `jac start --dev main.jac` inside it (not yet tested by the team).

## Hackathon implementation boundary

Core executable application logic is written in Jac. Phase 2 can add graph-evidence walkers, tested reachability/impact calculations, constraint-checked recovery strategies, and only then actual byLLM coordination with explicit provider configuration and human-readable evidence. Do not describe planned capabilities as operational until implemented and verified.
