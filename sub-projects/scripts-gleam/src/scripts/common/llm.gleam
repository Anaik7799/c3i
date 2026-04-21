//// scripts/common/llm — multi-provider language-model access with fallback.
////
//// Backed by real NIF HTTP calls for every provider. Chain:
////   1. Gemini       (generativelanguage.googleapis.com, via gemini_generate NIF)
////   2. OpenRouter   (openrouter.ai/api/v1/chat/completions, via openrouter_generate NIF)
////   3. Ollama local (http://127.0.0.1:11434, via ollama_generate NIF)
////
//// Credentials + model names come from env. The first provider to return a
//// non-empty reply wins. Metrics counters + histograms are emitted per attempt
//// on Zenoh topic `indrajaal/metrics/scripts/scripts.llm.*`.
////
//// Env vars:
////   GEMINI_API_KEY       required for Gemini
////   GEMINI_MODEL         default: gemini-1.5-flash-8b
////   OPENROUTER_API_KEY   required for OpenRouter
////   OPENROUTER_MODEL     default: openrouter/auto
////   OLLAMA_ENDPOINT      default: http://127.0.0.1:11434
////   OLLAMA_MODEL         default: llama3.2

import envoy
import gleam/int
import gleam/list
import gleam/string
import scripts/common/errors.{type ScriptError}
import scripts/common/gemini
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
        Error(_) -> {
          let _ = metrics.counter_inc("scripts.llm.failures", provider_tag(p), 1)
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
    Gemini -> dispatch_gemini(prompt, timeout_ms)
    OpenRouter -> dispatch_openrouter(prompt, timeout_ms)
    OllamaLocal -> dispatch_ollama(prompt, timeout_ms)
  }
}

fn dispatch_gemini(prompt: String, timeout_ms: Int) -> Result(String, ScriptError) {
  case gemini.generate(prompt, timeout_ms) {
    Ok("") -> Error(errors.Upstream("gemini empty reply"))
    Ok(s) -> Ok(s)
    Error(gemini.MissingApiKey) -> Error(errors.ConfigError("gemini: missing GEMINI_API_KEY"))
    Error(gemini.CallFailed(d)) -> Error(errors.Upstream("gemini: " <> d))
  }
}

fn dispatch_openrouter(prompt: String, timeout_ms: Int) -> Result(String, ScriptError) {
  case envoy.get("OPENROUTER_API_KEY") {
    Error(_) -> Error(errors.ConfigError("openrouter: missing OPENROUTER_API_KEY"))
    Ok(key) -> {
      let model = case envoy.get("OPENROUTER_MODEL") {
        Ok(m) -> m
        Error(_) -> "openrouter/auto"
      }
      let #(_, body) = nif.openrouter_generate(key, model, prompt, timeout_ms)
      case body {
        "" -> Error(errors.Upstream("openrouter empty reply"))
        s ->
          case string.starts_with(s, "http ") {
            True -> Error(errors.Upstream("openrouter: " <> s))
            False -> Ok(s)
          }
      }
    }
  }
}

fn dispatch_ollama(prompt: String, timeout_ms: Int) -> Result(String, ScriptError) {
  let endpoint = case envoy.get("OLLAMA_ENDPOINT") {
    Ok(v) -> v
    Error(_) -> "http://127.0.0.1:11434"
  }
  let model = case envoy.get("OLLAMA_MODEL") {
    Ok(m) -> m
    Error(_) -> "llama3.2"
  }
  let #(_, body) = nif.ollama_generate(endpoint, model, prompt, timeout_ms)
  case body {
    "" -> Error(errors.Upstream("ollama empty reply"))
    s ->
      case string.starts_with(s, "http ") {
        True -> Error(errors.Upstream("ollama: " <> s))
        False -> Ok(s)
      }
  }
}

/// Sensible default chain that tolerates missing creds at runtime.
pub fn default_chain() -> List(Provider) {
  [Gemini, OpenRouter, OllamaLocal]
}

/// Join chain members into a log-friendly string.
pub fn render_chain(chain: List(Provider)) -> String {
  string.join(list.map(chain, provider_tag), "->")
}
