# PulseGrid AI project plan

## Phase 1 — Foundation (implemented)

- Jac 0.34.23 web application and dark operational dashboard.
- Native Jac `Infrastructure` node and typed `PowerLink` edge model.
- Deterministic synthetic 14-node, 14-link distribution network and three named scenarios.
- Jac server endpoints to seed/read graph, apply a selected scenario fault and restore baseline state.
- Dashboard with asset register, synthetic network visualization, status metrics, timeline, controls and explicitly inactive agent capability panel.
- Local run instructions and no-secret synthetic-data configuration.

## Phase 2 — Evidence-based investigation

- Done: tested deterministic downstream reachability from the faulted node (`DownstreamTrace` walker), with hop counts, alternate-feed detection and interrupted end-use load.
- Done: explicit, stable scenario targets (`TR-01`, `SUB-01`, `J-01`).
- Done: dashboard shows affected assets and link outages from graph data with criticality context.
- Done: incidents and evidence as typed graph entities (`Incident`, `Evidence`, `HasEvidence`) with lifecycle and history; endpoint-level tests.
- Done: typed recovery-planning contracts (`RecoveryAction`, `ConstraintCheck`, `RecoveryOption`, `RecoveryPlan`), not yet produced.
- Done: tool-friendly query endpoints (`list_scenarios`, `preview_scenario`, `get_incident`) and dashboard pages for every sidebar item.
- Remaining: capacity checks on the alternate feed itself (the alternate-feed status is topology-only).

## Phase 3 — Constrained recovery planning

- Done: `services/recovery.jac` generates deterministic candidate options (back-feed paths around the fault, priority-only, isolate), checks each against path, link, asset and donor/supply capacity, records rejection reasons, and recommends the best feasible option; `recovery_plan()` endpoint and Overview/Reports UI. The planner logic was first written by Member 2 in `agents/tools.jac` and moved here.
- Remaining: applying a recommended option to the simulation (reversible "apply recovery"), and normally-open tie switches so some scenarios have a feasible restoration.

- Generate deterministic candidate recovery actions from graph evidence, respecting link capacity and facility priority.
- Add independent constraint verification and rejection reasons before presenting recommendations.
- Keep all actions simulated, reversible, and clearly separated from physical control.

## Phase 4 — Real agent collaboration

- In progress (Member 2, `agents/`): five agents with deterministic tools, evidence-cited byLLM output on services incidents/evidence, a bounded verify/re-plan loop, run persistence, a not-configured mode, and MockLLM tests. `plan_recovery`/`check_option` now come from `services/recovery.jac`, re-exported by `agents/tools.jac`.

- Add Jac walkers for Monitoring, Impact Investigation, Recovery Planning, Verification and Coordination.
- Use structured byLLM outputs only where language reasoning is useful; keep graph mathematics deterministic.
- Require user-configured provider credentials, evidence-linked decisions, iteration limits and replanning records. Never fabricate runs or tool calls.

## Phase 5 — Demonstration hardening

- Add automated graph and endpoint tests, scenario-flow tests, accessibility/mobile checks and export/run validation from a clean GitHub checkout.
- Version graph schema and seed data; document supported Jac toolchain and safe reset procedure.

## Safety boundary

The system is a synthetic educational simulator, not an operational grid-control product. No live grid, infrastructure topology or switching interface is connected. No claim is made about actual Sri Lankan network structure.
