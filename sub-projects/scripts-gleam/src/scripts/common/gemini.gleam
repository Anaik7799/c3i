//// scripts/common/gemini — typed Gemini model access.
////
//// SC-SCRIPT-GLEAM-001. Backed by the `scripts_nif` Rust NIF which performs
//// a blocking HTTPS POST to `generativelanguage.googleapis.com`. Credentials
//// come from env so no secrets ever sit in a script file.
////
//// Env:
////   GEMINI_API_KEY  — required
////   GEMINI_MODEL    — optional (default "gemini-1.5-flash")

import envoy
import scripts/common/nif

pub type GeminiError {
  MissingApiKey
  CallFailed(String)
}

fn model() -> String {
  case envoy.get("GEMINI_MODEL") {
    Ok(v) -> v
    Error(_) -> "gemini-2.0-flash"
  }
}

fn api_key() -> Result(String, GeminiError) {
  case envoy.get("GEMINI_API_KEY") {
    Ok(v) -> Ok(v)
    Error(_) -> Error(MissingApiKey)
  }
}

/// Generate a completion. `timeout_ms` caps the HTTP call.
pub fn generate(prompt: String, timeout_ms: Int) -> Result(String, GeminiError) {
  case api_key() {
    Error(e) -> Error(e)
    Ok(k) -> {
      let #(_, out) = nif.gemini_generate(model(), k, prompt, timeout_ms)
      case out {
        "" -> Error(CallFailed("empty reply"))
        s -> Ok(s)
      }
    }
  }
}
