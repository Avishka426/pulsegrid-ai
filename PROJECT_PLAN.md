# PulseGrid AI project plan

## Phase 1 — Foundation (implemented)

- Jac 0.34.23 web application and dark operational dashboard.
- Native Jac `Infrastructure` node and typed `PowerLink` edge model.
- Deterministic synthetic 14-node, 14-link distribution network and three named scenarios.
- Jac server endpoints to seed/read graph, apply a selected scenario fault and restore baseline state.
- Dashboard with asset register, synthetic network visualization, status metrics, timeline, controls and explicitly inactive agent capability panel.
- Local run instructions and no-secret synthetic-data configuration.

## Phase 2 — Evidence-based investigation

- Add tested deterministic reachability and affected-facility traversal from faulted node through energized links.
- Represent scenarios and incident evidence as typed graph entities; add walker endpoints for real graph traversal.
- Surface affected nodes and link outages with capacity/criticality context; make scenario targets explicit and stable.

## Phase 3 — Constrained recovery planning

- Generate deterministic candidate recovery actions from graph evidence, respecting link capacity and facility priority.
- Add independent constraint verification and rejection reasons before presenting recommendations.
- Keep all actions simulated, reversible, and clearly separated from physical control.

## Phase 4 — Real agent collaboration

- Add Jac walkers for Monitoring, Impact Investigation, Recovery Planning, Verification and Coordination.
- Use structured byLLM outputs only where language reasoning is useful; keep graph mathematics deterministic.
- Require user-configured provider credentials, evidence-linked decisions, iteration limits and replanning records. Never fabricate runs or tool calls.

## Phase 5 — Demonstration hardening

- Add automated graph and endpoint tests, scenario-flow tests, accessibility/mobile checks and export/run validation from a clean GitHub checkout.
- Version graph schema and seed data; document supported Jac toolchain and safe reset procedure.

## Safety boundary

The system is a synthetic educational simulator, not an operational grid-control product. No live grid, infrastructure topology or switching interface is connected. No claim is made about actual Sri Lankan network structure.
