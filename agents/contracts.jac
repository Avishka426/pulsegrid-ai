# Typed contracts for the PulseGrid agents.
#
# Incident, Evidence, RecoveryOption, RecoveryAction, ConstraintCheck and
# RecoveryPlan come from services/models.jac (Member 1). The types here are the
# agents' own: their evidence log, the model-facing outputs, and the published
# AgentRun contract for the UI.

# Action kinds are defined with the recovery contract in services/models.jac.
import from services.models { ACTION_BACKFEED, ACTION_ISOLATE }

# A fact an agent recorded during a run, citable by id (AE-01, AE-02, ...).
# `ref_id` links to a services Evidence record (e.g. INC-0003/EV-02) when the
# fact came from the incident's evidence.
obj AgentEvidence {
    has id: str;
    has source_tool: str;
    has label: str;
    has asset_ids: list[str] = [];
    has value: float = 0.0;
    has unit: str = "";
    has ref_id: str = "";
}
sem AgentEvidence = "A fact produced by a deterministic tool call over the synthetic grid graph.";
sem AgentEvidence.id = "Stable evidence identifier to cite, e.g. AE-03.";
sem AgentEvidence.label = "Human-readable description of the fact.";
sem AgentEvidence.value = "The numeric value computed by the tool.";
sem AgentEvidence.unit = "Unit of value (MW, %, assets, hops).";

obj RejectionNote {
    has option_id: str;
    has failed_checks: list[str] = [];
    has reasons: list[str] = [];
}
sem RejectionNote = "Why a previously chosen option was rejected. Do not choose it again.";

obj ImpactAssessment {
    has incident_id: str;
    has downstream_count: int = 0;
    has interrupted_load_mw: float = 0.0;
    has critical_interrupted: int = 0;
    has interrupted_asset_ids: list[str] = [];
    has alternate_feed_ids: list[str] = [];
    has evidence_ids: list[str] = [];
}
sem ImpactAssessment = "Deterministic impact totals. Every number here was computed by graph tools.";

obj ImpactNarrative {
    has summary: str;
    has key_points: list[str] = [];
    has cited_evidence_ids: list[str] = [];
}
sem ImpactNarrative.summary = "Two or three plain sentences describing the simulated impact. Use only numbers that appear in the evidence values.";
sem ImpactNarrative.key_points = "Short bullet sentences, each grounded in cited evidence.";
sem ImpactNarrative.cited_evidence_ids = "IDs (AE-..) of the evidence items supporting the summary. Only IDs from the provided evidence.";

obj PlanChoice {
    has option_id: str;
    has rationale: str;
    has cited_evidence_ids: list[str] = [];
}
sem PlanChoice.option_id = "The identifier of exactly one provided option that has not been rejected.";
sem PlanChoice.rationale = "One or two sentences explaining the choice. Use only numbers present in the evidence.";
sem PlanChoice.cited_evidence_ids = "Evidence IDs (AE-..) supporting the rationale.";

obj Recommendation {
    has text: str;
    has cited_evidence_ids: list[str] = [];
}
sem Recommendation.text = "Advisory recommendation for the simulated network, citing evidence IDs inline like [AE-03]. No real-world switching or control instructions.";
sem Recommendation.cited_evidence_ids = "All evidence IDs cited in the text.";

# Published contract for the UI.

obj AgentStep {
    has index: int;
    has agent: str;
    has action: str;
    has tool: str;
    has input_summary: str = "";
    has output_summary: str = "";
    has evidence_ids: list[str] = [];
    has status: str = "ok";
}

obj AgentRun {
    has run_id: str;
    has scenario_id: str;
    has mode: str;
    has status: str;
    has model: str = "";
    has incident_id: str = "";
    has steps: list[AgentStep] = [];
    has iterations: int = 0;
    has final_recommendation: str = "";
    has recommended_option_id: str = "";
    has evidence: list[AgentEvidence] = [];
}

obj AgentStatus {
    has configured: bool;
    has model: str;
}

# Graph storage for completed and failed runs.

node AgentRunRecord {
    has run_id: str;
    has scenario_id: str;
    has mode: str;
    has status: str;
    has model: str = "";
    has incident_id: str = "";
    has iterations: int = 0;
    has final_recommendation: str = "";
    has recommended_option_id: str = "";
    has created_at: str = "";
    has evidence: list[AgentEvidence] = [];
}

node AgentStepRecord {
    has index: int;
    has agent: str;
    has action: str;
    has tool: str;
    has input_summary: str = "";
    has output_summary: str = "";
    has evidence_ids: list[str] = [];
    has status: str = "ok";
}

edge HasStep: AgentRunRecord --> AgentStepRecord {}

glob AGENT_MONITORING: str = "Monitoring Agent";
glob AGENT_IMPACT: str = "Impact Investigator";
glob AGENT_PLANNER: str = "Recovery Planner";
glob AGENT_VERIFIER: str = "Verification Agent";
glob AGENT_COORDINATOR: str = "Coordinator Agent";

glob STEP_OK: str = "ok";
glob STEP_REJECTED: str = "rejected";
glob STEP_ERROR: str = "error";

glob RUN_COMPLETED: str = "completed";
glob RUN_FAILED: str = "failed";
glob RUN_NOT_CONFIGURED: str = "not_configured";

glob MODE_LLM: str = "llm";
glob MODE_NOT_CONFIGURED: str = "not_configured";

