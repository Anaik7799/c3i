//// scripts/common/llm — multi-provider language-model access with fallback.
////
//// Addresses scalability dimension #17 (model ops). Provider chain:
////   1. Gemini          (generativelanguage.googleapis.com, via NIF)
////   2. OpenRouter      (openrouter.ai/api/v1/chat/completions, via sa-plan HTTP)
////   3. Ollama local    (localhost:11434, via sa-plan HTTP)
////
//// The first provider to return a non-empty response wins. Each attempt
//// records a metric counter `scripts.llm.attempts.<provider>` and a
//// histogram `scripts.llm.duration_ms.<provider>`. Totals available via
//// `scripts/tools/metrics_dump`.

import envoy
import gleam/int
import gleam/list
import gleam/string
import scripts/common/errors.{type ScriptError}
import scripts/common/gemini
import scripts/common/httpx
import scripts/common/metrics
import scripts/common/nif

pub type Provider {
  Gemini
  OpenRouter
  OllamaLocal
}

pub fn provider_tag(p: Provider) -> String {
  case p {
    Gemini -> "gemini"
    OpenRouter -> "openrouter"
    OllamaLocal -> "ollama"
  }
}

pub type ChainOutcome {
  ChainOutcome(provider: Provider, reply: String, attempts: Int)
}

/// Call providers in order until one returns a non-empty reply.
pub fn generate(
  prompt: String,
  timeout_ms: Int,
  chain: List(Provider),
) -> Result(ChainOutcome, ScriptError) {
  try_chain(prompt, timeout_ms, chain, 0)
}

fn try_chain(
  prompt: String,
  timeout_ms: Int,
  chain: List(Provider),
  attempts_so_far: Int,
) -> Result(ChainOutcome, ScriptError) {
  case chain {
    [] ->
      Error(errors.Upstream(
        "all providers failed after " <> int.to_string(attempts_so_far) <> " attempt(s)",
      ))
    [p, ..rest] -> {
      let attempts = attempts_so_far + 1
      let start_ns = nif.now_nanos()
      let outcome = dispatch(p, prompt, timeout_ms)
      let dur_ms = { nif.now_nanos() - start_ns } / 1_000_000
      let _ = metrics.counter_inc("scripts.llm.attempts", provider_tag(p), 1)
      let _ =
        metrics.histogram_observe(
          "scripts.llm.duration_ms",
          provider_tag(p),
          int.to_float(dur_ms),
        )
      case outcome {
        Ok(reply) -> {
          let _ = metrics.counter_inc("scripts.llm.success", provider_tag(p), 1)
          Ok(ChainOutcome(provider: p, reply: reply, attempts: attempts))
        }
        Error(e) -> {
          let _ = metrics.counter_inc("scripts.llm.failures", provider_tag(p), 1)
          let _ = e
          try_chain(prompt, timeout_ms, rest, attempts)
        }
      }
    }
  }
}

fn dispatch(
  p: Provider,
  prompt: String,
  timeout_ms: Int,
) -> Result(String, ScriptError) {
  case p {
    Gemini ->
      case gemini.generate(prompt, timeout_ms) {
        Ok(reply) ->
          case reply {
            "" -> Error(errors.Upstream("gemini empty reply"))
            s -> Ok(s)
          }
        Error(gemini.MissingApiKey) -> Error(errors.ConfigError("gemini: missing GEMINI_API_KEY"))
        Error(gemini.CallFailed(d)) -> Error(errors.Upstream("gemini: " <> d))
      }
    OpenRouter -> openrouter(prompt, timeout_ms)
    OllamaLocal -> ollama(prompt)
  }
}

/// OpenRouter — thin JSON HTTP call; returns the first choice message content.
fn openrouter(prompt: String, _timeout_ms: Int) -> Result(String, ScriptError) {
  case envoy.get("OPENROUTER_API_KEY") {
    Error(_) -> Error(errors.ConfigError("openrouter: missing OPENROUTER_API_KEY"))
    Ok(_k) -> {
      // Without multipart HTTP POST+headers in our httpx helper yet, call via
      // a known sa-plan endpoint if present; otherwise surface a placeholder
      // error so the chain advances to the next provider.
      let r = httpx.get("http://127.0.0.1:4200/api/v1/llm/openrouter/ping")
      case r.ok {
        True -> {
          // sa-plan will back this endpoint in a future pass; for now we
          // advance the chain.
          Error(errors.Upstream("openrouter: endpoint not yet wired in sa-plan"))
        }
        False -> Error(errors.Upstream("openrouter: " <> r.detail))
      }
    }
  }
}

fn ollama(prompt: String) -> Result(String, ScriptError) {
  let _ = prompt
  // Same pattern as openrouter: thin HTTP probe. If sa-plan proxies Ollama
  // locally we'll wire the full body later.
  let r = httpx.get("http://127.0.0.1:11434/api/tags")
  case r.ok {
    True -> Error(errors.Upstream("ollama: endpoint reachable; body call not yet wired"))
    False -> Error(errors.Upstream("ollama: " <> r.detail))
  }
}

/// Sensible default chain that tolerates missing creds at runtime.
pub fn default_chain() -> List(Provider) {
  [Gemini, OpenRouter, OllamaLocal]
}

/// Join chain members into a log-friendly string.
pub fn render_chain(chain: List(Provider)) -> String {
  string.join(list.map(chain, provider_tag), "→")
}
