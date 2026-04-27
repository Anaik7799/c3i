//// scripts/pass9/p9_symbiosis_monitor — closed-loop OODA monitor for
//// ZK/Pi/Agent symbiosis.
////
//// Fractal TPS. One tick = Observe → Orient → Decide → Act.
////
//// Writes a JSON snapshot the dashboard consumes, and publishes a Zenoh span
//// so the live web panel can subscribe. Single-shot (--once) or loop.
////
//// ENV:
////   INTERVAL_MS — tick period in loop mode (default 5000)
////   OUT_JSON — dashboard snapshot path (default data/monitor/symbiosis.json)

import envoy
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/kms
import scripts/common/nif

const default_out = "/home/an/dev/ver/c3i/docs/journal/monitor/symbiosis.json"

const default_history = "/home/an/dev/ver/c3i/docs/journal/monitor/history.ndjson"

const default_agents = "/home/an/dev/ver/c3i/docs/journal/monitor/agents.json"

const default_interval = 5_000

pub fn main() -> Nil {
  let out = envoy.get("OUT_JSON") |> or(default_out)
  let interval = envoy.get("INTERVAL_MS") |> or_int(default_interval)
  let once = case envoy.get("ONCE") {
    Ok(_) -> True
    Error(_) -> False
  }
  io.println("=== pass9/symbiosis_monitor · OODA ===")
  io.println("snapshot: " <> out)
  case once {
    True -> {
      tick(out)
      Nil
    }
    False -> {
      io.println("interval: " <> int.to_string(interval) <> " ms (loop)")
      loop(out, interval)
    }
  }
}

fn loop(out: String, interval: Int) -> Nil {
  tick(out)
  sleep_ms(interval)
  loop(out, interval)
}

fn tick(out: String) -> Nil {
  let t0 = nif.now_nanos()
  let obs = observe()
  let or_ = orient(obs)
  let al = alarms(obs, or_)
  let snap = render_json(obs, or_, al, t0)
  write_file(out, snap)
  // append a compact line to history ring (trim to newest N in a
  // separate rotate step; for now append-only, dashboard slices tail).
  let hist = envoy.get("HISTORY_JSON") |> or(default_history)
  append_line(hist, compact_history_line(obs, or_, al, t0))
  // per-agent rollup written whole every tick (small file, simpler)
  let agents_path = envoy.get("AGENTS_JSON") |> or(default_agents)
  write_file(agents_path, per_agent_rollup())
  let _ =
    nif.zenoh_put(
      "indrajaal/l5/ooda/symbiosis",
      "{\"ts\":" <> int.to_string(t0)
        <> ",\"holons\":" <> int.to_string(obs.holons)
        <> ",\"turns\":" <> int.to_string(obs.turns)
        <> ",\"alarms\":" <> int.to_string(list.length(al)) <> "}",
    )
  let dt_ms = { nif.now_nanos() - t0 } / 1_000_000
  io.println(
    int.to_string(dt_ms) <> "ms · holons="
    <> int.to_string(obs.holons) <> " embeds="
    <> int.to_string(obs.embeddings) <> " sess="
    <> int.to_string(obs.sessions) <> " turns="
    <> int.to_string(obs.turns) <> " tokens="
    <> int.to_string(obs.tokens_total) <> " cost=$"
    <> f2(obs.cost_total, 4) <> " alarms="
    <> int.to_string(list.length(al)),
  )
}

// ── OBSERVE ─────────────────────────────────────────────────────────────

pub type Obs {
  Obs(
    holons: Int,
    edges: Int,
    embeddings: Int,
    sessions: Int,
    turns: Int,
    pi_sessions: Int,
    prompt_cache: Int,
    semantic_cache: Int,
    pipeline_stages: Int,
    tokens_total: Int,
    cost_total: Float,
    last_id: String,
    last_agent: String,
    last_provider: String,
    last_model: String,
    last_in: Int,
    last_out: Int,
    last_cache_read: Int,
    last_cost: Float,
    last_zk: Int,
    last_hit: Float,
  )
}

fn observe() -> Obs {
  let holons = scalar_int("SELECT COUNT(*) FROM holons")
  let edges = scalar_int("SELECT COUNT(*) FROM holon_edges")
  let embs = scalar_int("SELECT COUNT(*) FROM holon_embeddings")
  let sess = scalar_int("SELECT COUNT(*) FROM session_metrics")
  let turns = scalar_int("SELECT COUNT(*) FROM session_turn_spans")
  let pi = scalar_int("SELECT COUNT(*) FROM pi_sessions")
  let pc = scalar_int("SELECT COUNT(*) FROM prompt_cache")
  let sc = scalar_int("SELECT COUNT(*) FROM semantic_cache")
  let pl = scalar_int("SELECT COUNT(*) FROM pipeline_stage_metrics")
  let tokens =
    scalar_int("SELECT COALESCE(SUM(tokens_total),0) FROM session_metrics")
  let cost =
    scalar_float("SELECT COALESCE(SUM(cost_usd),0) FROM session_metrics")
  let last_cols = [
    "session_id", "agent", "provider", "model",
    "tokens_input", "tokens_output", "tokens_cache_read",
    "cost_usd", "zk_recalls", "cache_hit_ratio",
  ]
  let _ = last_cols
  case
    kms.query(
      "SELECT session_id, agent, provider, model,\n              tokens_input, tokens_output, tokens_cache_read,\n              cost_usd, zk_recalls, cache_hit_ratio\n         FROM session_metrics\n         ORDER BY started_at DESC LIMIT 1",
      [],
    )
  {
    Ok(qr) ->
      case qr.rows {
        [row, ..] ->
          Obs(
            holons, edges, embs, sess, turns, pi, pc, sc, pl, tokens, cost,
            at(row, 0), at(row, 1), at(row, 2), at(row, 3),
            i(at(row, 4)), i(at(row, 5)), i(at(row, 6)),
            f(at(row, 7)), i(at(row, 8)), f(at(row, 9)),
          )
        _ -> empty(holons, edges, embs, sess, turns, pi, pc, sc, pl, tokens, cost)
      }
    _ -> empty(holons, edges, embs, sess, turns, pi, pc, sc, pl, tokens, cost)
  }
}

fn empty(
  h: Int, e: Int, em: Int, s: Int, t: Int, p: Int, pc: Int, sc: Int, pl: Int,
  tk: Int, c: Float,
) -> Obs {
  Obs(h, e, em, s, t, p, pc, sc, pl, tk, c, "-", "-", "-", "-", 0, 0, 0, 0.0, 0, 0.0)
}

// ── ORIENT ──────────────────────────────────────────────────────────────

pub type Orient {
  Orient(
    embed_coverage: Float,
    tokens_per_session: Int,
    cost_per_session: Float,
    cache_hit: Float,
    cache_entries: Int,
  )
}

fn orient(o: Obs) -> Orient {
  let ec = case o.holons {
    0 -> 0.0
    _ -> int.to_float(o.embeddings) /. int.to_float(o.holons)
  }
  let tps = case o.sessions {
    0 -> 0
    n -> o.tokens_total / n
  }
  let cps = case o.sessions {
    0 -> 0.0
    n -> o.cost_total /. int.to_float(n)
  }
  Orient(ec, tps, cps, o.last_hit, o.prompt_cache + o.semantic_cache)
}

// ── DECIDE ──────────────────────────────────────────────────────────────

fn alarms(o: Obs, or_: Orient) -> List(String) {
  []
  |> maybe_add(or_.embed_coverage <. 0.5, "EMBED_LOW · " <> pct(or_.embed_coverage))
  |> maybe_add(o.turns == 0, "TURN_SPANS_EMPTY · per-turn tracking inactive")
  |> maybe_add(
    or_.cache_hit <. 0.3 && o.last_in > 1000,
    "CACHE_HIT_LOW · " <> pct(or_.cache_hit),
  )
  |> maybe_add(
    or_.cost_per_session >. 5.0,
    "COST_HIGH · $" <> f2(or_.cost_per_session, 2) <> "/session",
  )
  |> maybe_add(
    o.pi_sessions > 0 && o.turns == 0,
    "PI_NO_TURN_TRACE · " <> int.to_string(o.pi_sessions) <> " sessions 0 spans",
  )
}

fn maybe_add(xs: List(String), cond: Bool, msg: String) -> List(String) {
  case cond {
    True -> [msg, ..xs]
    False -> xs
  }
}

// ── ACT ──────────────────────────────────────────────────────────────────

fn render_json(o: Obs, or_: Orient, al: List(String), t0: Int) -> String {
  let alarms_arr =
    al |> list.map(fn(a) { "\"" <> a <> "\"" }) |> string.join(",")
  "{"
  <> "\"ts_nanos\":" <> int.to_string(t0)
  <> ",\"observe\":{"
    <> "\"holons\":" <> int.to_string(o.holons)
    <> ",\"edges\":" <> int.to_string(o.edges)
    <> ",\"embeddings\":" <> int.to_string(o.embeddings)
    <> ",\"embed_coverage_pct\":" <> f2(or_.embed_coverage *. 100.0, 2)
    <> ",\"sessions\":" <> int.to_string(o.sessions)
    <> ",\"turn_spans\":" <> int.to_string(o.turns)
    <> ",\"pi_sessions\":" <> int.to_string(o.pi_sessions)
    <> ",\"prompt_cache\":" <> int.to_string(o.prompt_cache)
    <> ",\"semantic_cache\":" <> int.to_string(o.semantic_cache)
    <> ",\"pipeline_stages\":" <> int.to_string(o.pipeline_stages)
    <> ",\"tokens_total\":" <> int.to_string(o.tokens_total)
    <> ",\"cost_total_usd\":" <> f2(o.cost_total, 4)
  <> "},\"last_session\":{"
    <> "\"id\":\"" <> esc(o.last_id) <> "\""
    <> ",\"agent\":\"" <> esc(o.last_agent) <> "\""
    <> ",\"provider\":\"" <> esc(o.last_provider) <> "\""
    <> ",\"model\":\"" <> esc(o.last_model) <> "\""
    <> ",\"tokens_in\":" <> int.to_string(o.last_in)
    <> ",\"tokens_out\":" <> int.to_string(o.last_out)
    <> ",\"cache_read\":" <> int.to_string(o.last_cache_read)
    <> ",\"cost_usd\":" <> f2(o.last_cost, 4)
    <> ",\"zk_recalls\":" <> int.to_string(o.last_zk)
    <> ",\"cache_hit_ratio\":" <> f2(o.last_hit, 3)
  <> "},\"orient\":{"
    <> "\"embed_coverage\":" <> f2(or_.embed_coverage, 4)
    <> ",\"tokens_per_session\":" <> int.to_string(or_.tokens_per_session)
    <> ",\"cost_per_session_usd\":" <> f2(or_.cost_per_session, 4)
    <> ",\"cache_hit_ratio\":" <> f2(or_.cache_hit, 3)
    <> ",\"cache_entries\":" <> int.to_string(or_.cache_entries)
  <> "},\"alarms\":[" <> alarms_arr <> "]}"
}

// ── helpers ─────────────────────────────────────────────────────────────

fn scalar_int(sql: String) -> Int {
  case kms.query(sql, []) {
    Ok(qr) ->
      case qr.rows {
        [row, ..] -> i(at(row, 0))
        _ -> 0
      }
    _ -> 0
  }
}

fn scalar_float(sql: String) -> Float {
  case kms.query(sql, []) {
    Ok(qr) ->
      case qr.rows {
        [row, ..] -> f(at(row, 0))
        _ -> 0.0
      }
    _ -> 0.0
  }
}

fn at(row: kms.Row, idx: Int) -> String {
  // Row is List(#(column, value))
  case list.drop(row, idx) {
    [#(_, v), ..] -> v
    _ -> ""
  }
}

fn i(s: String) -> Int {
  case int.parse(s) {
    Ok(n) -> n
    Error(_) -> 0
  }
}

fn f(s: String) -> Float {
  case float.parse(s) {
    Ok(x) -> x
    Error(_) ->
      case int.parse(s) {
        Ok(n) -> int.to_float(n)
        Error(_) -> 0.0
      }
  }
}

fn f2(x: Float, _decimals: Int) -> String {
  // Trim to keep JSON compact; simpler than building erlang opts.
  case float.to_string(x) {
    s -> s
  }
}

fn pct(x: Float) -> String {
  f2(x *. 100.0, 1) <> "%"
}

fn esc(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", " ")
}

fn or(res: Result(String, Nil), d: String) -> String {
  case res {
    Ok(v) -> v
    Error(_) -> d
  }
}

fn or_int(res: Result(String, Nil), d: Int) -> Int {
  case res {
    Ok(v) ->
      case int.parse(v) {
        Ok(n) -> n
        Error(_) -> d
      }
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

@external(erlang, "file", "write_file")
fn write_file_opts(path: String, body: String, opts: List(a)) -> anything

fn append_line(path: String, line: String) -> Nil {
  let _ = write_file_opts(path, line <> "\n", [append_atom()])
  Nil
}

@external(erlang, "erlang", "binary_to_atom")
fn bin_to_atom(s: String) -> a

fn append_atom() -> a {
  bin_to_atom("append")
}

// ── compact one-line history entry ────────────────────────────────────
fn compact_history_line(o: Obs, or_: Orient, al: List(String), t0: Int) -> String {
  "{\"ts\":" <> int.to_string(t0)
  <> ",\"h\":" <> int.to_string(o.holons)
  <> ",\"e\":" <> int.to_string(o.embeddings)
  <> ",\"ec\":" <> f2(or_.embed_coverage *. 100.0, 2)
  <> ",\"s\":" <> int.to_string(o.sessions)
  <> ",\"ts_\":" <> int.to_string(o.turns)
  <> ",\"tok\":" <> int.to_string(o.tokens_total)
  <> ",\"cost\":" <> f2(o.cost_total, 4)
  <> ",\"cps\":" <> f2(or_.cost_per_session, 4)
  <> ",\"al\":" <> int.to_string(list.length(al))
  <> "}"
}

// ── per-agent rollup ───────────────────────────────────────────────────
fn per_agent_rollup() -> String {
  case
    kms.query(
      "SELECT COALESCE(NULLIF(agent,''),'unknown') as ag,
              COUNT(*) as sessions,
              COALESCE(SUM(tokens_total),0) as tokens,
              COALESCE(SUM(cost_usd),0.0)  as cost,
              COALESCE(SUM(zk_recalls),0)  as zk,
              COALESCE(AVG(cache_hit_ratio),0.0) as hit
         FROM session_metrics
         GROUP BY ag
         ORDER BY tokens DESC",
      [],
    )
  {
    Ok(qr) -> {
      let rows_json =
        qr.rows
        |> list.map(fn(r) {
          "{\"agent\":\"" <> esc(at(r, 0)) <> "\""
          <> ",\"sessions\":" <> int.to_string(i(at(r, 1)))
          <> ",\"tokens\":" <> int.to_string(i(at(r, 2)))
          <> ",\"cost_usd\":" <> f2(f(at(r, 3)), 4)
          <> ",\"zk_recalls\":" <> int.to_string(i(at(r, 4)))
          <> ",\"cache_hit\":" <> f2(f(at(r, 5)), 3)
          <> "}"
        })
        |> string.join(",")
      "{\"ts_nanos\":" <> int.to_string(nif.now_nanos())
      <> ",\"agents\":[" <> rows_json <> "]}"
    }
    _ -> "{\"agents\":[]}"
  }
}
