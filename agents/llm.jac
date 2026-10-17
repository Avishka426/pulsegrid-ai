# Model configuration, the three language-reasoning calls, and their validators.
#
# The model is only asked to write prose and to choose among deterministic
# options. Validators reject output that cites unknown evidence or states a
# number that no tool produced.

import os;
import re;
import from jaclang.byllm.lib { Model, MockLLM }
import from services.models { Incident, RecoveryOption }
import from agents.contracts {
    AgentEvidence, RejectionNote, ImpactAssessment,
    ImpactNarrative, PlanChoice, Recommendation, AgentStatus
}

glob DEFAULT_MODEL: str = "gpt-4o-mini";
glob KEYLESS_OPT_IN: str = "PULSEGRID_ALLOW_KEYLESS_MODEL";
glob NUMBER_TOLERANCE: float = 0.05;

# "env": configured from the environment; "mock": a test model is installed;
# "off": forced not-configured (tests).
glob model_mode: str = "env";
glob agent_llm: Model | MockLLM = Model(model_name=(os.environ.get("LLM_MODEL", "") or DEFAULT_MODEL));

def model_name() -> str {
    if model_mode == "mock" { return "mockllm"; }
    return os.environ.get("LLM_MODEL", "") or DEFAULT_MODEL;
}

# Environment variable holding the key for a model, or "" for keyless/unknown models.
def provider_key_name(name: str) -> str {
    if name.startswith("gpt-") or name.startswith("o1") or name.startswith("o3") or name.startswith("o4") or name.startswith("openai/") { return "OPENAI_API_KEY"; }
    if name.startswith("claude-") or name.startswith("anthropic/") { return "ANTHROPIC_API_KEY"; }
    if name.startswith("gemini/") { return "GOOGLE_API_KEY"; }
    return "";
}

def configured_from_env(name: str, env: dict[str, str]) -> bool {
    key_name = provider_key_name(name);
    if key_name != "" { return env.get(key_name, "").strip() != ""; }
    keyless = name.startswith("ollama/") or name.startswith("local:");
    return keyless and env.get(KEYLESS_OPT_IN, "") == "1";
}

def is_configured() -> bool {
    if model_mode == "mock" { return True; }
    if model_mode == "off" { return False; }
    return configured_from_env(model_name(), dict(os.environ));
}

def current_status() -> AgentStatus {
    return AgentStatus(configured=is_configured(), model=model_name());
}

def use_model(m: Model | MockLLM) -> None {
    agent_llm = m;
    model_mode = "mock";
}

def disable_model() -> None {
    model_mode = "off";
}

def use_env_model() -> None {
    agent_llm = Model(model_name=model_name());
    model_mode = "env";
}

# Language-reasoning calls.

def narrate_impact(incident: Incident, assessment: ImpactAssessment, evidence: list[AgentEvidence]) -> ImpactNarrative by agent_llm(temperature=0.0);
sem narrate_impact = "You are the Impact Investigator for an educational, fully synthetic power-grid simulator. Describe the simulated impact of the incident for a non-expert. Use only facts and numbers present in the evidence and assessment. Cite evidence IDs. Never imply a real grid, real location or real-world control action.";
sem narrate_impact.incident = "The simulated incident.";
sem narrate_impact.assessment = "Deterministic impact totals computed by graph tools.";
sem narrate_impact.evidence = "Evidence items you may cite by id.";

def choose_option(assessment: ImpactAssessment, options: list[RecoveryOption], rejected: list[RejectionNote], evidence: list[AgentEvidence]) -> PlanChoice by agent_llm(temperature=0.0);
sem choose_option = "You are the Recovery Planner for a synthetic power-grid simulator. Choose exactly one option from the provided list that is not in the rejected list. Prefer restoring priority facilities (hospital, water) when feasible, but heed every rejection reason. Use only numbers from the evidence and cite evidence IDs. Options are simulated and advisory only.";
sem choose_option.assessment = "Deterministic impact totals.";
sem choose_option.options = "The only options you may choose from.";
sem choose_option.rejected = "Options already rejected by the Verification Agent, with reasons.";
sem choose_option.evidence = "Evidence items you may cite by id.";

def write_recommendation(incident: Incident, assessment: ImpactAssessment, chosen: RecoveryOption, rejected: list[RejectionNote], evidence: list[AgentEvidence]) -> Recommendation by agent_llm(temperature=0.0);
sem write_recommendation = "You are the Coordinator for a synthetic, educational power-grid simulator. Write a short advisory recommendation (at most 4 sentences) for the verified option, mention briefly why rejected options failed, and cite evidence IDs inline like [AE-03]. Use only numbers from the evidence. Say the action is simulated. Never give real-world switching or control instructions.";
sem write_recommendation.chosen = "The option that passed verification.";
sem write_recommendation.rejected = "Options that failed verification, with reasons.";
sem write_recommendation.evidence = "Evidence items you may cite by id.";

# Validators.

glob ID_PATTERN: str = r"\b[A-Za-z]+-\d+(?:-[A-Za-z]+\d+)*\b";
glob CITATION_PATTERN: str = r"\bAE-\d+\b";
glob NUMBER_PATTERN: str = r"\d+(?:\.\d+)?";

# Numbers stated in text, ignoring digits that are part of IDs such as TR-01, AE-03 or OPT-1-A1.
def numbers_in(text: str) -> list[float] {
    stripped = re.sub(ID_PATTERN, " ", text);
    return [float(tok) for tok in re.findall(NUMBER_PATTERN, stripped)];
}

def unsupported_numbers(texts: list[str], facts: list[float]) -> list[float] {
    bad: list[float] = [];
    for t in texts {
        for n in numbers_in(t) {
            if not any([abs(n - f) <= NUMBER_TOLERANCE for f in facts]) and n not in bad { bad.append(n); }
        }
    }
    return bad;
}

def inline_citations(text: str) -> list[str] {
    return re.findall(CITATION_PATTERN, text);
}

def unknown_citations(cited: list[str], evidence: list[AgentEvidence]) -> list[str] {
    known = [e.id for e in evidence];
    return [c for c in cited if c not in known];
}

# Empty list when the output is acceptable, otherwise human-readable problems.
def validate_text(texts: list[str], cited: list[str], evidence: list[AgentEvidence], facts: list[float]) -> list[str] {
    problems: list[str] = [];
    if len(cited) == 0 { problems.append("no evidence cited"); }
    unknown = unknown_citations(cited, evidence);
    if len(unknown) > 0 { problems.append(f"cites unknown evidence {', '.join(unknown)}"); }
    bad = unsupported_numbers(texts, facts);
    if len(bad) > 0 { problems.append(f"states numbers not produced by tools: {', '.join([f'{b:g}' for b in bad])}"); }
    return problems;
}
