# PulseGrid AI agents: design (Member 2)

Status: **implemented and integrated with `main`**, now on Jac 0.34.23 (the stable line; briefly built on 0.37.25): the the `services/` module split, and Member 1's incident/evidence/recovery contracts. Sections 1–9 below are the original design; this section records what was actually built and where it differs.

## 0. As built

| File | Contents |
|---|---|
| `agents/contracts.jac` | `AgentEvidence` (the run's evidence log, IDs `AE-01`…), model-facing outputs, the published `AgentStep` / `AgentRun` / `AgentStatus` contract, and the `AgentRunRecord` / `AgentStepRecord` storage nodes |
| `agents/tools.jac` | `get_asset`, `list_scenarios`, `trace_downstream_ids`, `impact_totals`, `incident_evidence` (wrap `services/`), plus `plan_recovery` and `check_option` (now in `services/recovery.jac`, re-exported here unchanged), which produce `RecoveryPlan` / `RecoveryOption` / `RecoveryAction` / `ConstraintCheck` |
| `agents/llm.jac` | Model selection and key detection, the three `by llm` calls with `sem` prompts, and the citation/number validators |
| `agents/investigation.jac` | `MonitoringScan` and `DownstreamWalk` walkers, the agent stages and the coordinator loop (`investigate`) |
| `agents/endpoints.jac` | The `def:pub` endpoints and run persistence |
| `agents/tests/*_tests.jac` | 30 tests (8 tools, 7 config/validators, 12 agents/coordinator, 3 endpoints), all with MockLLM; shared helpers in `fixtures.jac` |

Integration with Member 1's `services/`:

- **Incident and Evidence are Member 1's nodes.** The coordinator applies the scenario, then opens an `Incident`: `open_incident` on the live root (so it appears in `list_incidents` like a dashboard fault), or `build_incident` on a transient network in tests. The Impact Investigator turns each incident `Evidence` record into an `AgentEvidence` whose `ref_id` is the services ID (e.g. `INC-0003/EV-02`). The model cites the `AE-` IDs.
- **Recovery types are Member 1's.** `plan_recovery` returns `RecoveryPlan(fault_id, options)`. Each option holds one `RecoveryAction` per restored asset (`kind` is `backfeed` or `isolate`; `link_id` is the comma-joined path). The Verification Agent fills `option.checks`, `option.feasible` and `option.rejection_reason`, and the coordinator sets `plan.recommended_id`. `ConstraintCheck.name` is `"<rule>:<subject>"`, e.g. `link_capacity:L-10`.
- `AgentRun` and `AgentRunRecord` carry `incident_id`.

Other differences from the design below:

- Tools take the asset list first (`get_asset(assets, id)`, `plan_recovery(assets, incident)`, `check_option(assets, option)`), following `services/`, so tests run on a transient network.
- `run_id` is a 12-character `uuid4` hex, because it is needed before the record exists.
- Planner, Verifier and Coordinator are functions, because options are `obj`s (Q1). Monitoring and Impact are walkers. The Impact Investigator requires its own `DownstreamWalk`, the trace tool and the incident evidence to agree; any mismatch is an `error` step.
- Unknown scenarios fail with one step; they are not stored and no incident is opened.
- `jac.toml` pins `agents.*` to the server, like `services.*`.

**Recovery logic** (written here, then moved unchanged to `services/recovery.jac`, which adds `verify_plan` / `recommend` for the dashboard). Options are: restore all reachable interrupted end-use loads (`OPT-1`), restore priority loads only (`OPT-2`), and keep the fault isolated (`OPT-3`). A restoration path is the shortest undirected path from an interrupted asset to the nearest energized asset that avoids the faulted asset (back-feed). Checks cover path availability, link headroom (capacity minus the load already carried while both ends are energized), capacity of each pass-through asset, donor headroom, and donor supply-link headroom. In the seed network every restoration fails at the Water Works back-feed (`L-10`, `L-14`, `FAC-02`), so the verifier always rejects a planner that picks restoration first. That is the re-planning demonstration.

**Spike result, verified on 0.34.23.** A module-level `glob agent_llm: Model | MockLLM` with a setter passes `jac check`, and `MockLLM(model_name="mockllm", config={"outputs": [...]})` returns typed objs in order (0.37's `MockLLM(outputs=...)` form is not accepted on 0.34). byLLM calls need litellm in `.jac/venv`, which `jac install` provides from the `[byllm]` table in `jac.toml`; MockLLM tests also need it.

## 1. Principles

1. **Numbers come from tools, never from the model.** Every count, MW figure, hop distance, asset ID and constraint result is computed by Jac graph code and stored in typed fields. The LLM writes prose and makes a choice between options that deterministic code already generated.
2. **Every claim cites evidence.** Each tool call produces `Evidence` records with stable IDs. LLM outputs must cite IDs from that run's evidence set, and code validates this.
3. **No key, no run.** Without a configured model, `run_investigation` returns `mode = "not_configured"` with zero steps and nothing is persisted. No fake steps and no canned narrative.
4. **Advisory and simulated.** Recommendations describe changes to the synthetic model ("simulate transferring West Residential to the Harbor feed"). Never switching or control language, and never claims about real topology.
5. **Bounded.** Planner and verifier loop at most `MAX_ITERATIONS = 3` times. Each ReAct-style call has its own small iteration cap.

## 2. Pipeline

```
run_investigation(scenario_id)
  └─ Coordinator  (walker, spawned on a new AgentRunRecord node)
       1. Monitoring       deterministic   → Incident + anomaly Evidence
       2. Impact           tools + LLM     → ImpactAssessment (numbers: tools; narrative: LLM)
       3. Planning ◄──┐    tools + LLM     → PlanChoice (option chosen from plan_recovery output)
       4. Verification │   deterministic   → ConstraintCheck results
             fail ─────┘   (feedback → planner, at most 3 iterations)
       5. Recommendation   LLM             → final text + cited evidence IDs
```

Each numbered stage appends one or more `AgentStep`s. The coordinator stops early on `error`, on success, or when the iteration cap is reached.

### 2.1 Monitoring Agent: `walker MonitoringScan` (no LLM)

- Spawned on `root`; visits every `Infrastructure` node.
- Detects the active fault (`operational_status == "fault"`), de-energized assets, and load anomalies (`load_mw / capacity_mw >= LOAD_WARN_RATIO`). The ratio is a named glob, and its value must be agreed, because TR-01 sits at exactly 0.80.
- Emits `Evidence` (one per finding) and an `Incident`.
- No active fault → step `status = "error"`, run `status = "failed"` ("no active fault to investigate"). The coordinator applies the scenario first (see §5), so this only fires if that step failed.

### 2.2 Impact Investigation Agent: `walker ImpactInvestigator`

- Spawned on the faulted asset. It calls `trace_downstream_ids` and `get_asset` (Member 1 tools) and collects one `Evidence` per downstream asset (hops, load, criticality, alternate feed).
- `ImpactAssessment` numeric fields (`downstream_count`, `interrupted_load_mw`, `critical_interrupted`, `asset_ids`) are filled **by code** from tool results.
- The LLM fills only `ImpactNarrative`:

  ```jac
  obj ImpactNarrative { has summary: str; has key_points: list[str]; has cited_evidence_ids: list[str]; }
  def narrate_impact(incident: Incident, evidence: list[Evidence]) -> ImpactNarrative by agent_llm(temperature=0.0);
  ```
- **Validation.** Cited IDs must be a subset of the run's evidence IDs. Every number in `summary`/`key_points` must appear in the evidence values: extract numeric tokens and compare them to the evidence fact set. On failure the step is `rejected`, the narrative is retried once, and if it fails again the step is `error`. There is no template fallback that pretends to be LLM output.

### 2.3 Recovery Planning Agent: `walker RecoveryPlanner`

- Calls `plan_recovery(incident)` (Member 1) to get deterministic `RecoveryOption`s. The model never invents options.
- The LLM chooses:

  ```jac
  obj PlanChoice { has option_id: str; has rationale: str; has cited_evidence_ids: list[str]; }
  def choose_option(assessment: ImpactAssessment, options: list[RecoveryOption],
                    rejected: list[RejectionNote]) -> PlanChoice by agent_llm(temperature=0.0);
  ```
- **Validation.** `option_id` must be in `options` and not in `rejected`, and cited IDs must be in the evidence set. A choice that fails validation counts as an iteration with step status `rejected`.

### 2.4 Verification Agent: `walker ConstraintVerifier` (no LLM)

- Independently calls `check_option(option)` (Member 1). It does not reuse any check result the planner saw.
- All checks pass → `ok`. Any check fails → `rejected`, and a `RejectionNote { option_id, failed_check_ids, reasons }` goes back to the planner.

### 2.5 Coordinator Agent: `walker Coordinator`

- Spawned on a fresh `AgentRunRecord` node. It runs the stages, enforces `MAX_ITERATIONS`, and attaches an `AgentStepRecord` node per step (`AgentRunRecord ─[HasStep]→ AgentStepRecord`) so the run lives on the graph.
- Final step: `write_recommendation(...) -> Recommendation { text, cited_evidence_ids }` by LLM, with the same citation and number validation as §2.2.
- Outcomes:
  - verified → `completed`, `recommended_option_id` set
  - iteration cap reached → `failed`, `recommended_option_id = ""`, text written by code: "No option passed verification within 3 iterations"
  - provider error → `failed`, step `error` with the exception class name (never the key or raw headers)

**Walker results.** Nested spawns route reports to the outer stream, so sub-agents return results through `has` fields that the coordinator reads after `here spawn X()`, not through `report` (see `jac guide jac-walker-patterns`).

**Shape note.** Monitoring, Impact and Coordinator genuinely traverse (assets, the downstream subgraph, the step chain). Planner and Verifier only traverse if `RecoveryOption` is a **node** linked from the incident. If Member 1 makes options plain `obj`s, those two become `def` functions called by the coordinator rather than walkers that never `visit`. See open question Q1.

## 3. Contract for Member 3 (UI)

As specified in the team brief, plus two read endpoints.

```jac
obj AgentStep {
    has index: int; has agent: str; has action: str; has tool: str;
    has input_summary: str; has output_summary: str;
    has evidence_ids: list[str] = [];
    has status: str;            # "ok" | "rejected" | "error"
}
obj AgentRun {
    has run_id: str; has scenario_id: str;
    has mode: str;              # "llm" | "not_configured"
    has model: str;
    has steps: list[AgentStep] = [];
    has iterations: int = 0;
    has final_recommendation: str = "";
    has recommended_option_id: str = "";
    has status: str;            # "completed" | "failed" | "not_configured"
}
obj AgentStatus { has configured: bool; has model: str; }

def:pub agent_status() -> AgentStatus;               # never returns or logs the key
def:pub run_investigation(scenario_id: str) -> AgentRun;
def:pub list_agent_runs() -> list[AgentRun];          # newest first, persisted runs only
def:pub get_agent_run(run_id: str) -> AgentRun | None;
```

- `agent_status` returns a typed `obj` rather than a bare `dict`, which gives the client typed fields.
- `agent` values: `"Monitoring Agent" | "Impact Investigator" | "Recovery Planner" | "Verification Agent" | "Coordinator Agent"`. These match the existing dashboard cards.
- `tool` is the tool function name (`trace_downstream_ids`, `check_option`, …) or `"llm:narrate_impact"` / `"llm:choose_option"` / `"llm:write_recommendation"` for model calls.
- UI states Member 3 must render:
  - `configured = false`: show "Agents not configured: set a model key to enable", with the run button disabled. Do not show placeholder steps.
  - running: `run_investigation` is synchronous; show a spinner. Expect 5–20 s with a real model.
  - `completed` / `failed`: list the steps in order, color-coding `rejected` and `error` steps. Show the cited evidence IDs and link each one to its asset.
- Endpoints are registered via one import line in `main.jac` (agreed with Member 3): `import from agents.endpoints { agent_status, run_investigation, list_agent_runs, get_agent_run }`.

## 4. What Member 2 needs from Member 1

The current names on `main` are `trace_downstream(origin, blocked_ids) -> DownstreamTrace`, `compute_downstream(...)`, `DownstreamAsset`, and `Scenario { identifier, title, target_id }`. The agents need these on top of them. Proposed signatures follow; the final ones are Member 1's call.

| Tool | Proposed signature | Used by |
|---|---|---|
| `get_asset` | `def get_asset(asset_id: str) -> Infrastructure \| None` | Impact, Recommendation |
| `trace_downstream_ids` | `def trace_downstream_ids(origin_id: str) -> list[DownstreamAsset]`, ordered by (hops, id) | Impact |
| `list_scenarios` | `def list_scenarios() -> list[Scenario]` | Coordinator (validate input) |
| `plan_recovery` | `def plan_recovery(incident: Incident) -> RecoveryPlan` | Planner |
| `check_option` | `def check_option(option: RecoveryOption) -> list[ConstraintCheck]` | Verifier |

Contract objects. The fields the agents rely on are listed; Member 1 can add more.

- `Evidence { id, source_tool, asset_ids: list[str], label, value: float, unit }`. IDs are stable within a run (e.g. `EV-<run>-<n>`), or Member 1 provides a deterministic ID scheme the agents can reuse.
- `Incident { id, scenario_id, fault_id, detected_status }`
- `RecoveryOption { id, title, actions: list[str], transferred_load_mw, via_link_ids }`
- `ConstraintCheck { id, option_id, rule, passed: bool, observed: float, limit: float, reason }`
- `RecoveryPlan { incident_id, options: list[RecoveryOption] }`

**Needed for tests:** at least one scenario where `plan_recovery` returns an option that `check_option` deterministically rejects. That lets the re-planning loop be tested against real graph logic instead of a stub. The seed data already has a natural case: transferring all of West Junction's load (18 + 14 + 27 = 59 MW) onto `L-14` (25 MW).

## 5. Run lifecycle and persistence

1. Validate `scenario_id` against `list_scenarios()`. Unknown → `failed` run, not persisted.
2. Not configured → return `AgentRun(mode="not_configured", status="not_configured", steps=[])`. **Not persisted**; it is not a run.
3. Create `AgentRunRecord` (node) on `root`, call `apply_fault(scenario_id)` (recorded as step 0, tool `apply_fault`), then spawn the `Coordinator`.
4. Convert node records to the `AgentRun` obj for the response. The LLM fills `obj`s only; nodes are the storage schema.

`run_id` is `jid(record)`, which is unique and safe to expose.

**Graph scope.** Anonymous `def:pub` callers run on the shared guest root (`jac guide jac-sv-endpoints`), so every visitor sees every run, the same as the simulation state today. This is acceptable for the demo, and it is documented as a limitation.

## 6. Model configuration

- `jac.toml` has `[byllm.model] default_model = "${LLM_MODEL:-huggingface/openai/gpt-oss-120b}"` and no `api_key`, so each provider reads its own variable. `agents/llm.jac` `DEFAULT_MODEL` must match (a test checks it). `.env.example` keeps blank values.
- `agents/llm.jac` holds `glob agent_llm: Model | MockLLM` built from `LLM_MODEL`, plus `def use_model(m: Model | MockLLM)` for tests.
- "Configured" means the provider key for the model's prefix is non-empty in the environment:
  - `huggingface/*` → `HUGGINGFACE_API_KEY` (or `HF_TOKEN`, which LiteLLM also reads); this is the default
  - `gpt-*` → `OPENAI_API_KEY`
  - `claude-*` → `ANTHROPIC_API_KEY`
  - `gemini/*` → `GOOGLE_API_KEY`
  - `ollama/*` and `local:*` → configured only if `PULSEGRID_ALLOW_KEYLESS_MODEL=1`, since there is no key to detect
- The key is never echoed, logged, stored on the graph, or returned.

**Spike result (Jac 0.34.23, see §0).** Typing the glob as plain `Model` fails `jac check` (E1053) when a `MockLLM` is assigned.

## 7. Tests (`agents/*.test.jac`, all MockLLM, no key)

| Area | Test |
|---|---|
| Monitoring | detects the faulted asset per scenario; flags anomalies at the threshold; no fault → error step |
| Impact | `downstream_count` / `interrupted_load_mw` equal the `trace_downstream_ids` results for all 3 scenarios; narrative citing an unknown evidence ID → rejected; narrative containing a number not in the evidence → rejected |
| Planner | choice outside the options → rejected; previously rejected option re-chosen → rejected |
| Verifier | passes a known-good option; rejects the known-bad option with the failing check IDs |
| Coordinator | happy path for all 3 scenarios; forced verification failure → re-plan → success; MockLLM always picks the bad option → stops at `iterations == 3`, `status == "failed"` |
| Config | no key → `not_configured`, zero steps, nothing persisted; `agent_status` contains no key material |
| Persistence | completed run appears in `list_agent_runs`; `get_agent_run` round-trips steps in order |
| Numbers | every numeric field in the final `AgentRun` equals a freshly computed tool result |

Tests share the persisted root (`jac guide jac-testing`), so each test resets the graph and filters runs by its own `run_id`.

## 8. Risks and limitations

- **LLM non-determinism.** Runs are reproducible in tests (MockLLM) but not with a real model. Only the choice and the prose vary; the numbers do not.
- **Latency and cost.** 3–7 model calls per run. A synchronous endpoint is acceptable for the demo; streaming progress (`jac-sv-streaming`) is a later improvement.
- **The number check is lexical.** It catches invented figures, not wrong reasoning about correct figures.
- **No ReAct tool calls in v1.** Walkers call the tools deterministically and pass the results to the model. Letting the model call read-only tools itself (`tools=[get_asset]`) is possible later, but each tool call would need recording as an `AgentStep`, and MockLLM support for simulated tool calls is untested (**spike before relying on it**).
- **Shared guest graph** (§5).

## 9. Open questions

- **Q1 (Member 1):** Should `RecoveryOption` be a node linked from the incident, so the Planner and Verifier walk it, or an `obj`, so they are functions?
- **Q2 (Member 1):** Who issues evidence IDs: the tools or the agents? A single scheme avoids collisions.
- **Q3 (Member 3):** Is a synchronous `run_investigation` acceptable for the demo, or should it stream step updates?
- **Q4 (team):** In not-configured mode, should Monitoring and Impact still run, since they are deterministic and show real data, or should agents stay fully inactive as the brief says? This design follows the brief: fully inactive.
- **Q5 (team):** Which model to demo with, and who holds the key for the manual live run?
