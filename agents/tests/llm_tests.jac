# Model configuration and output validators. No model is called here.

import os;
import from agents.contracts { AgentEvidence }
import from agents.llm {
    provider_key_name, configured_from_env, current_status, use_env_model, disable_model,
    numbers_in, validate_text, inline_citations
}

test "provider keys map from model names" {
    assert provider_key_name("gpt-4o-mini") == "OPENAI_API_KEY";
    assert provider_key_name("claude-sonnet-4-6") == "ANTHROPIC_API_KEY";
    assert provider_key_name("gemini/gemini-2.0-flash") == "GOOGLE_API_KEY";
    assert provider_key_name("ollama/llama3") == "";
}

test "configured only when the matching key is non-empty" {
    assert not configured_from_env("gpt-4o-mini", {});
    assert not configured_from_env("gpt-4o-mini", {"OPENAI_API_KEY": "  "});
    assert not configured_from_env("gpt-4o-mini", {"ANTHROPIC_API_KEY": "x"});
    assert configured_from_env("gpt-4o-mini", {"OPENAI_API_KEY": "x"});
    assert configured_from_env("claude-sonnet-4-6", {"ANTHROPIC_API_KEY": "x"});
}

test "keyless local models need an explicit opt-in" {
    assert not configured_from_env("ollama/llama3", {});
    assert configured_from_env("ollama/llama3", {"PULSEGRID_ALLOW_KEYLESS_MODEL": "1"});
    assert not configured_from_env("mystery-model", {"PULSEGRID_ALLOW_KEYLESS_MODEL": "1"});
}

test "status never exposes the key" {
    previous = os.environ.get("OPENAI_API_KEY", "");
    os.environ["OPENAI_API_KEY"] = "sk-test-secret-value";
    os.environ["LLM_MODEL"] = "gpt-4o-mini";
    use_env_model();
    status = current_status();
    assert status.configured;
    assert status.model == "gpt-4o-mini";
    assert "sk-test-secret-value" not in str(status.__dict__);
    os.environ["OPENAI_API_KEY"] = previous;
    disable_model();
    assert not current_status().configured;
}

test "numbers inside IDs are ignored" {
    assert numbers_in("TR-01 feeds J-01 and FAC-02 [AE-03] via OPT-1-A2 and INC-0001/EV-02") == [];
    assert numbers_in("45 MW across 2 links, 9.5%") == [45.0, 2.0, 9.5];
}

test "inline citations are collected" {
    assert inline_citations("Loads drop [AE-03]; see AE-11 and INC-0001/EV-02.") == ["AE-03", "AE-11"];
}

test "unsupported numbers and unknown citations are reported" {
    ev = [AgentEvidence(id="AE-01", source_tool="t", label="x", value=45.0, unit="MW")];
    assert validate_text(["45 MW interrupted [AE-01]"], ["AE-01"], ev, [45.0]) == [];
    problems = validate_text(["99 MW interrupted"], ["AE-07"], ev, [45.0]);
    assert len(problems) == 2;
    assert "AE-07" in problems[0];
    assert "99" in problems[1];
    assert validate_text(["No numbers"], [], ev, [45.0]) == ["no evidence cited"];
}
