//// scripts/common/nif — raw bindings to scripts_nif Rust NIF.
////
//// SC-SCRIPT-GLEAM-001, SC-NIF-001. Low-level only; prefer the typed
//// modules under `scripts/common/{zenoh,smriti,gemini,fractal,mcp}`.

import gleam/erlang/atom.{type Atom}

// ─── Utilities ───────────────────────────────────────────────────────────────

@external(erlang, "scripts_nif", "now_nanos")
pub fn now_nanos() -> Int

@external(erlang, "scripts_nif", "uuid_v7")
pub fn uuid_v7() -> String

@external(erlang, "scripts_nif", "sha256_hex")
pub fn sha256_hex(input: String) -> String

// ─── Smriti ──────────────────────────────────────────────────────────────────

/// Empty string means "not found".
@external(erlang, "scripts_nif", "smriti_get_pref")
pub fn smriti_get_pref(db_path: String, key: String) -> #(Atom, String)

@external(erlang, "scripts_nif", "smriti_set_pref")
pub fn smriti_set_pref(
  db_path: String,
  category: String,
  key: String,
  value: String,
) -> #(Atom, String)

/// Empty string means "not found".
@external(erlang, "scripts_nif", "smriti_get_task")
pub fn smriti_get_task(db_path: String, id: String) -> #(Atom, String)

// ─── Zenoh ───────────────────────────────────────────────────────────────────

@external(erlang, "scripts_nif", "zenoh_open_session")
pub fn zenoh_open_session() -> #(Atom, String)

@external(erlang, "scripts_nif", "zenoh_put")
pub fn zenoh_put(key: String, payload: String) -> #(Atom, String)

@external(erlang, "scripts_nif", "zenoh_get")
pub fn zenoh_get(selector: String, timeout_ms: Int) -> #(Atom, List(String))

@external(erlang, "scripts_nif", "zenoh_session_info")
pub fn zenoh_session_info() -> #(Atom, String)

// ─── Fractal ─────────────────────────────────────────────────────────────────

@external(erlang, "scripts_nif", "fractal_span_emit")
pub fn fractal_span_emit(
  layer: String,
  name: String,
  start_ns: Int,
  end_ns: Int,
  status: String,
  attrs_json: String,
) -> #(Atom, String)

// ─── Gemini ──────────────────────────────────────────────────────────────────

@external(erlang, "scripts_nif", "gemini_generate")
pub fn gemini_generate(
  model: String,
  api_key: String,
  prompt: String,
  timeout_ms: Int,
) -> #(Atom, String)

// ─── MCP over Zenoh ──────────────────────────────────────────────────────────

@external(erlang, "scripts_nif", "mcp_invoke_moz")
pub fn mcp_invoke_moz(
  tool: String,
  args_json: String,
  timeout_ms: Int,
) -> #(Atom, String)

// ─── Metrics (SC-SCRIPT-MET-001) ─────────────────────────────────────────────

@external(erlang, "scripts_nif", "metrics_counter_inc")
pub fn metrics_counter_inc(metric: String, label: String, by: Int) -> #(Atom, Int)

@external(erlang, "scripts_nif", "metrics_histogram_observe")
pub fn metrics_histogram_observe(metric: String, label: String, value: Float) -> #(Atom, Int)

@external(erlang, "scripts_nif", "metrics_snapshot")
pub fn metrics_snapshot() -> #(Atom, String)
