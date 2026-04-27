//// scripts/pass10/p10_robustness_gate — durability/perf/correctness gate.
////
//// SC-P10-ROBUST-001 · STAMP/FMEA/RETE-lite.
////
//// Runs a continuous "can Pi start from zero and still operate" audit:
////   - Control plane: sa-plan availability, Zenoh, fastembed, KMS pool
////   - Correctness: DB integrity_check, foreign_key_check, WAL mode
////   - Utility: customer URLs reachable via /c3i path
////   - Stability: session/turn traces present
////   - Performance: lightweight URL fetch latencies
////
//// Outputs:
////   docs/journal/monitor/robustness.json
////   docs/journal/monitor/robustness.md
////
//// ENV
////   INTERVAL_MS   loop cadence (default 60000)
////   OUT_JSON      default docs/journal/monitor/robustness.json
////   OUT_MD        default docs/journal/monitor/robustness.md
////   ONCE          set to any value for one-shot

import envoy
import gleam/erlang/atom
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/httpx
import scripts/common/kms
import scripts/common/nif
import scripts/common/saplan

const default_interval = 60_000
const default_out_json = "/home/an/dev/ver/c3i/docs/journal/monitor/robustness.json"
const default_out_md = "/home/an/dev/ver/c3i/docs/journal/monitor/robustness.md"

pub fn main() -> Nil {
  let interval_ms = envoy.get("INTERVAL_MS") |> env_int(default_interval)
  let out_json = envoy.get("OUT_JSON") |> env_str(default_out_json)
  let out_md = envoy.get("OUT_MD") |> env_str(default_out_md)
  let once = case envoy.get("ONCE") {
    Ok(_) -> True
    Error(_) -> False
  }

  io.println("=== pass10/robustness_gate (STAMP/FMEA/RETE-lite) ===")
  io.println("interval=" <> int.to_string(interval_ms) <> "ms")
  io.println("json=" <> out_json)
  io.println("md=" <> out_md)

  case once {
    True -> tick(out_json, out_md)
    False -> loop(interval_ms, out_json, out_md)
  }
}

fn loop(interval_ms: Int, out_json: String, out_md: String) -> Nil {
  tick(out_json, out_md)
  sleep_ms(interval_ms)
  loop(interval_ms, out_json, out_md)
}

pub type Audit {
  Audit(
    ts_nanos: Int,
    // core checks
    saplan_ok: Bool,
    kms_ok: Bool,
    db_integrity_ok: Bool,
    foreign_keys_ok: Bool,
    wal_ok: Bool,
    zenoh_ok: Bool,
    fastembed_ok: Bool,
    // counts
    holons: Int,
    embeddings: Int,
    edges: Int,
    sessions: Int,
    pi_sessions: Int,
    turns: Int,
    prompt_cache: Int,
    semantic_cache: Int,
    // economics
    tokens_total: Int,
    cost_total: Float,
    embed_cov: Float,
    cost_per_session: Float,
    // utility
    u_html_ms: Int,
    u_json_ms: Int,
    u_agents_ms: Int,
    u_hist_ms: Int,
    u_html_ok: Bool,
    u_json_ok: Bool,
    u_agents_ok: Bool,
    u_hist_ok: Bool,
    // score
    score: Int,
    grade: String,
    alarms: List(String),
    actions: List(String),
    fmea: List(FmeaItem),
  )
}

pub type FmeaItem {
  FmeaItem(mode: String, s: Int, o: Int, d: Int, rpn: Int, note: String)
}

fn tick(out_json: String, out_md: String) -> Nil {
  let t0 = nif.now_nanos()

  // Core liveness checks
  let saplan_ok = saplan.available()
  let kms_ok = case kms.health() { Ok(_) -> True _ -> False }
  let db_integrity_ok = scalar("PRAGMA integrity_check", "") == "ok"
  let fk_rows = row_count("PRAGMA foreign_key_check")
  let foreign_keys_ok = fk_rows == 0
  let wal_ok = string.contains(string.lowercase(scalar("PRAGMA journal_mode", "")), "wal")

  let #(z_tag, _z_msg) = nif.zenoh_session_info()
  let zenoh_ok = atom.to_string(z_tag) == "ok"
  let #(f_tag, _f_msg) = nif.fastembed_info()
  let fastembed_ok = atom.to_string(f_tag) == "ok"

  // KMS counts
  let holons = count_of("holons")
  let embeddings = count_of("holon_embeddings")
  let edges = count_of("holon_edges")
  let sessions = count_of("session_metrics")
  let pi_sessions = count_of("pi_sessions")
  let turns = count_of("session_turn_spans")
  let prompt_cache = count_of("prompt_cache")
  let semantic_cache = count_of("semantic_cache")

  let tokens_total = int_scalar("SELECT COALESCE(SUM(tokens_total),0) FROM session_metrics")
  let cost_total = float_scalar("SELECT COALESCE(SUM(cost_usd),0.0) FROM session_metrics")

  let embed_cov = case holons {
    0 -> 0.0
    _ -> int.to_float(embeddings) /. int.to_float(holons)
  }
  let cost_per_session = case sessions {
    0 -> 0.0
    _ -> cost_total /. int.to_float(sessions)
  }

  // Utility path checks (customer-facing)
  let #(u_html_ok, u_html_ms) = check_url("https://vm-1.tail55d152.ts.net/c3i/task-id/any/monitor/symbiosis.html")
  let #(u_json_ok, u_json_ms) = check_url("https://vm-1.tail55d152.ts.net/c3i/task-id/any/monitor/symbiosis.json")
  let #(u_agents_ok, u_agents_ms) = check_url("https://vm-1.tail55d152.ts.net/c3i/task-id/any/monitor/agents.json")
  let #(u_hist_ok, u_hist_ms) = check_url("https://vm-1.tail55d152.ts.net/c3i/task-id/any/monitor/history.ndjson")

  let alarms =
    []
    |> add_if(!saplan_ok, "SAPLAN_DOWN")
    |> add_if(!kms_ok, "KMS_HEALTH_FAIL")
    |> add_if(!db_integrity_ok, "DB_INTEGRITY_FAIL")
    |> add_if(!foreign_keys_ok, "DB_FOREIGN_KEY_FAIL")
    |> add_if(!wal_ok, "DB_NOT_WAL")
    |> add_if(!zenoh_ok, "ZENOH_DOWN")
    |> add_if(!fastembed_ok, "FASTEMBED_DOWN")
    |> add_if(!u_html_ok || !u_json_ok || !u_agents_ok || !u_hist_ok, "CUSTOMER_URL_FAIL")
    |> add_if(embed_cov <. 0.5, "EMBED_LOW")
    |> add_if(cost_per_session >. 5.0, "COST_HIGH")
    |> add_if(pi_sessions > 0 && turns == 0, "PI_NO_TURN_TRACE")

  let actions =
    []
    // RETE-lite action routing
    |> add_if_s(embed_cov <. 0.5, "run scripts/pass8/p8_04_embed_backfill (MAX=2000)")
    |> add_if_s(cost_per_session >. 5.0, "tighten p8_06_budget_middleware and route via p8_13_moe_router")
    |> add_if_s(pi_sessions > 0 && turns == 0, "wire p8_19_per_turn_spans into Pi startup middleware")
    |> add_if_s(!u_html_ok || !u_json_ok || !u_agents_ok || !u_hist_ok, "restart c3i-sa-plan-http + validate /c3i proxy")
    |> add_if_s(!db_integrity_ok || !foreign_keys_ok, "freeze writes, backup smriti.db, run integrity remediation")

  let score =
    100
    |> penalty(!saplan_ok, 20)
    |> penalty(!kms_ok, 20)
    |> penalty(!db_integrity_ok, 30)
    |> penalty(!foreign_keys_ok, 20)
    |> penalty(!wal_ok, 10)
    |> penalty(!zenoh_ok, 15)
    |> penalty(!fastembed_ok, 10)
    |> penalty(!u_html_ok, 10)
    |> penalty(!u_json_ok, 10)
    |> penalty(!u_agents_ok, 10)
    |> penalty(!u_hist_ok, 10)
    |> penalty(embed_cov <. 0.5, 10)
    |> penalty(cost_per_session >. 5.0, 10)
    |> penalty(pi_sessions > 0 && turns == 0, 10)
    |> clamp_0_100

  let grade = case score {
    n if n >= 90 -> "A"
    n if n >= 75 -> "B"
    n if n >= 60 -> "C"
    _ -> "D"
  }

  let fmea =
    fmea_items(
      saplan_ok,
      kms_ok,
      db_integrity_ok,
      foreign_keys_ok,
      wal_ok,
      u_html_ok && u_json_ok && u_agents_ok && u_hist_ok,
      embed_cov,
      cost_per_session,
      pi_sessions,
      turns,
    )

  let audit =
    Audit(
      ts_nanos: t0,
      saplan_ok: saplan_ok,
      kms_ok: kms_ok,
      db_integrity_ok: db_integrity_ok,
      foreign_keys_ok: foreign_keys_ok,
      wal_ok: wal_ok,
      zenoh_ok: zenoh_ok,
      fastembed_ok: fastembed_ok,
      holons: holons,
      embeddings: embeddings,
      edges: edges,
      sessions: sessions,
      pi_sessions: pi_sessions,
      turns: turns,
      prompt_cache: prompt_cache,
      semantic_cache: semantic_cache,
      tokens_total: tokens_total,
      cost_total: cost_total,
      embed_cov: embed_cov,
      cost_per_session: cost_per_session,
      u_html_ms: u_html_ms,
      u_json_ms: u_json_ms,
      u_agents_ms: u_agents_ms,
      u_hist_ms: u_hist_ms,
      u_html_ok: u_html_ok,
      u_json_ok: u_json_ok,
      u_agents_ok: u_agents_ok,
      u_hist_ok: u_hist_ok,
      score: score,
      grade: grade,
      alarms: alarms,
      actions: actions,
      fmea: fmea,
    )

  let json = to_json(audit)
  let md = to_md(audit)

  write_file(out_json, json)
  write_file(out_md, md)

  let _ =
    nif.zenoh_put(
      "indrajaal/l5/ooda/robustness",
      "{\"ts\":" <> int.to_string(t0)
      <> ",\"score\":" <> int.to_string(score)
      <> ",\"grade\":\"" <> grade <> "\""
      <> ",\"alarms\":" <> int.to_string(list.length(alarms)) <> "}",
    )

  let dt = { nif.now_nanos() - t0 } / 1_000_000
  io.println(
    "robustness score=" <> int.to_string(score)
    <> " grade=" <> grade
    <> " alarms=" <> int.to_string(list.length(alarms))
    <> " dt=" <> int.to_string(dt) <> "ms",
  )
}

// ──────────────────────────────────────────────────────────────────────────
// FMEA
// ──────────────────────────────────────────────────────────────────────────

fn fmea_items(
  saplan_ok: Bool,
  kms_ok: Bool,
  db_integrity_ok: Bool,
  foreign_keys_ok: Bool,
  wal_ok: Bool,
  utility_ok: Bool,
  embed_cov: Float,
  cost_per_session: Float,
  pi_sessions: Int,
  turns: Int,
) -> List(FmeaItem) {
  [
    risk("control-plane down", 9, bool_to_occ(!saplan_ok), 3, "sa-plan unavailable"),
    risk("kms health fail", 10, bool_to_occ(!kms_ok), 3, "smriti pool unhealthy"),
    risk("db integrity failure", 10, bool_to_occ(!db_integrity_ok), 2, "integrity_check != ok"),
    risk("foreign key drift", 8, bool_to_occ(!foreign_keys_ok), 4, "foreign_key_check rows > 0"),
    risk("wal disabled", 7, bool_to_occ(!wal_ok), 5, "journal_mode not wal"),
    risk("customer path fail", 8, bool_to_occ(!utility_ok), 4, "one or more /c3i URLs failed"),
    risk("embedding coverage low", 7, scale_occ_lt(embed_cov, 0.5), 6, "coverage below 50%"),
    risk("cost per session high", 8, scale_occ_gt(cost_per_session, 5.0), 6, "cost/session above $5"),
    risk("pi no turn trace", 6, bool_to_occ(pi_sessions > 0 && turns == 0), 5, "pi sessions without turn spans"),
  ]
  |> sort_fmea_desc
}

fn risk(mode: String, s: Int, o: Int, d: Int, note: String) -> FmeaItem {
  FmeaItem(mode: mode, s: s, o: o, d: d, rpn: s * o * d, note: note)
}

fn bool_to_occ(flag: Bool) -> Int {
  case flag {
    True -> 8
    False -> 1
  }
}

fn scale_occ_lt(value: Float, thr: Float) -> Int {
  case value <. thr {
    True -> 7
    False -> 2
  }
}

fn scale_occ_gt(value: Float, thr: Float) -> Int {
  case value >. thr {
    True -> 7
    False -> 2
  }
}

fn sort_fmea_desc(xs: List(FmeaItem)) -> List(FmeaItem) {
  list.sort(xs, fn(a, b) {
    case a.rpn > b.rpn {
      True -> order.Lt
      False -> case a.rpn < b.rpn {
        True -> order.Gt
        False -> order.Eq
      }
    }
  })
}

// ──────────────────────────────────────────────────────────────────────────
// Rendering
// ──────────────────────────────────────────────────────────────────────────

fn to_json(a: Audit) -> String {
  let alarms =
    a.alarms
    |> list.map(fn(x) { "\"" <> esc(x) <> "\"" })
    |> string.join(",")
  let actions =
    a.actions
    |> list.map(fn(x) { "\"" <> esc(x) <> "\"" })
    |> string.join(",")
  let fmea =
    a.fmea
    |> list.map(fn(r) {
      "{\"mode\":\"" <> esc(r.mode) <> "\""
      <> ",\"s\":" <> int.to_string(r.s)
      <> ",\"o\":" <> int.to_string(r.o)
      <> ",\"d\":" <> int.to_string(r.d)
      <> ",\"rpn\":" <> int.to_string(r.rpn)
      <> ",\"note\":\"" <> esc(r.note) <> "\"}"
    })
    |> string.join(",")

  "{"
  <> "\"ts_nanos\":" <> int.to_string(a.ts_nanos)
  <> ",\"score\":" <> int.to_string(a.score)
  <> ",\"grade\":\"" <> a.grade <> "\""
  <> ",\"checks\":{"
    <> "\"saplan_ok\":" <> bool(a.saplan_ok)
    <> ",\"kms_ok\":" <> bool(a.kms_ok)
    <> ",\"db_integrity_ok\":" <> bool(a.db_integrity_ok)
    <> ",\"foreign_keys_ok\":" <> bool(a.foreign_keys_ok)
    <> ",\"wal_ok\":" <> bool(a.wal_ok)
    <> ",\"zenoh_ok\":" <> bool(a.zenoh_ok)
    <> ",\"fastembed_ok\":" <> bool(a.fastembed_ok)
    <> ",\"u_html_ok\":" <> bool(a.u_html_ok)
    <> ",\"u_json_ok\":" <> bool(a.u_json_ok)
    <> ",\"u_agents_ok\":" <> bool(a.u_agents_ok)
    <> ",\"u_hist_ok\":" <> bool(a.u_hist_ok)
  <> "},\"counts\":{"
    <> "\"holons\":" <> int.to_string(a.holons)
    <> ",\"embeddings\":" <> int.to_string(a.embeddings)
    <> ",\"edges\":" <> int.to_string(a.edges)
    <> ",\"sessions\":" <> int.to_string(a.sessions)
    <> ",\"pi_sessions\":" <> int.to_string(a.pi_sessions)
    <> ",\"turns\":" <> int.to_string(a.turns)
    <> ",\"prompt_cache\":" <> int.to_string(a.prompt_cache)
    <> ",\"semantic_cache\":" <> int.to_string(a.semantic_cache)
  <> "},\"economics\":{"
    <> "\"tokens_total\":" <> int.to_string(a.tokens_total)
    <> ",\"cost_total\":" <> f2(a.cost_total)
    <> ",\"embed_cov\":" <> f2(a.embed_cov)
    <> ",\"cost_per_session\":" <> f2(a.cost_per_session)
  <> "},\"latency_ms\":{"
    <> "\"symbiosis_html\":" <> int.to_string(a.u_html_ms)
    <> ",\"symbiosis_json\":" <> int.to_string(a.u_json_ms)
    <> ",\"agents_json\":" <> int.to_string(a.u_agents_ms)
    <> ",\"history_ndjson\":" <> int.to_string(a.u_hist_ms)
  <> "},\"alarms\":[" <> alarms <> "]"
  <> ",\"actions\":[" <> actions <> "]"
  <> ",\"fmea\":[" <> fmea <> "]"
  <> "}"
}

fn to_md(a: Audit) -> String {
  let fmea_rows =
    a.fmea
    |> list.take(6)
    |> list.map(fn(r) {
      "| " <> r.mode <> " | " <> int.to_string(r.s) <> " | "
      <> int.to_string(r.o) <> " | " <> int.to_string(r.d)
      <> " | " <> int.to_string(r.rpn) <> " | " <> r.note <> " |"
    })
    |> string.join("\n")

  let alarms = case a.alarms {
    [] -> "- none"
    xs -> xs |> list.map(fn(x) { "- " <> x }) |> string.join("\n")
  }
  let actions = case a.actions {
    [] -> "- none"
    xs -> xs |> list.map(fn(x) { "- " <> x }) |> string.join("\n")
  }

  "# Robustness Gate\n\n"
  <> "- score: **" <> int.to_string(a.score) <> "**\n"
  <> "- grade: **" <> a.grade <> "**\n"
  <> "- ts_nanos: `" <> int.to_string(a.ts_nanos) <> "`\n\n"
  <> "## Checks\n"
  <> "- saplan_ok: " <> yes(a.saplan_ok) <> "\n"
  <> "- kms_ok: " <> yes(a.kms_ok) <> "\n"
  <> "- db_integrity_ok: " <> yes(a.db_integrity_ok) <> "\n"
  <> "- foreign_keys_ok: " <> yes(a.foreign_keys_ok) <> "\n"
  <> "- wal_ok: " <> yes(a.wal_ok) <> "\n"
  <> "- zenoh_ok: " <> yes(a.zenoh_ok) <> "\n"
  <> "- fastembed_ok: " <> yes(a.fastembed_ok) <> "\n"
  <> "- utility_urls_ok: " <> yes(a.u_html_ok && a.u_json_ok && a.u_agents_ok && a.u_hist_ok) <> "\n\n"
  <> "## Alarms\n" <> alarms <> "\n\n"
  <> "## RETE-lite actions\n" <> actions <> "\n\n"
  <> "## FMEA Top Risks\n"
  <> "| mode | S | O | D | RPN | note |\n"
  <> "|---|---:|---:|---:|---:|---|\n"
  <> fmea_rows <> "\n"
}

// ──────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────

fn check_url(url: String) -> #(Bool, Int) {
  let t0 = nif.now_nanos()
  let res = httpx.head(url, 3_000)
  let dt = { nif.now_nanos() - t0 } / 1_000_000
  #(res.ok, dt)
}

fn count_of(table: String) -> Int {
  int_scalar("SELECT COUNT(*) FROM " <> table)
}

fn int_scalar(sql: String) -> Int {
  case kms.scalar(sql, []) {
    Ok(v) -> case int.parse(v) {
      Ok(n) -> n
      Error(_) -> 0
    }
    Error(_) -> 0
  }
}

fn float_scalar(sql: String) -> Float {
  case kms.scalar(sql, []) {
    Ok(v) -> case float.parse(v) {
      Ok(n) -> n
      Error(_) -> 0.0
    }
    Error(_) -> 0.0
  }
}

fn scalar(sql: String, default: String) -> String {
  case kms.scalar(sql, []) {
    Ok(v) -> v
    Error(_) -> default
  }
}

fn row_count(sql: String) -> Int {
  case kms.query(sql, []) {
    Ok(qr) -> list.length(qr.rows)
    Error(_) -> 999_999
  }
}

fn add_if(xs: List(String), cond: Bool, msg: String) -> List(String) {
  case cond {
    True -> [msg, ..xs]
    False -> xs
  }
}

fn add_if_s(xs: List(String), cond: Bool, msg: String) -> List(String) {
  case cond {
    True -> [msg, ..xs]
    False -> xs
  }
}

fn penalty(score: Int, cond: Bool, by: Int) -> Int {
  case cond {
    True -> score - by
    False -> score
  }
}

fn clamp_0_100(n: Int) -> Int {
  case n < 0 {
    True -> 0
    False -> case n > 100 {
      True -> 100
      False -> n
    }
  }
}

fn esc(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", " ")
}

fn bool(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}

fn yes(b: Bool) -> String {
  case b {
    True -> "yes"
    False -> "no"
  }
}

fn f2(x: Float) -> String {
  float.to_string(x)
}

fn env_int(v: Result(String, Nil), d: Int) -> Int {
  case v {
    Ok(s) -> case int.parse(s) {
      Ok(n) -> n
      Error(_) -> d
    }
    Error(_) -> d
  }
}

fn env_str(v: Result(String, Nil), d: String) -> String {
  case v {
    Ok(s) -> s
    Error(_) -> d
  }
}

@external(erlang, "timer", "sleep")
fn sleep_ms(ms: Int) -> Nil

@external(erlang, "file", "write_file")
fn write_file_raw(path: String, body: String) -> anything

fn write_file(path: String, body: String) -> Nil {
  let _ = write_file_raw(path, body)
  Nil
}

import gleam/order
