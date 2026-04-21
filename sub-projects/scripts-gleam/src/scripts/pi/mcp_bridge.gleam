//// scripts/pi/mcp_bridge — reverse-direction Pi↔gleam MCP server.
////
//// SC-SCRIPT-GLEAM-001 + Pi symbiosis.
////
//// Subscribes to `indrajaal/mcp/request/scripts.*` on the shared Zenoh mesh
//// and translates incoming MCP requests into local dispatches against the
//// manifest registry. Responses are published back to the caller's
//// `reply_to` topic.
////
//// Tool contract:
////   scripts.list                              → enumerate registered manifests
////   scripts.describe   {name}                 → return one manifest
////   scripts.metrics                           → metrics snapshot JSON
////   scripts.smriti.get_pref  {key}            → Smriti pref read
////   scripts.smriti.set_pref  {category,key,value}  → Smriti pref write
////   scripts.health                            → smoke diagnostic
////
//// Usage:
////   gleam run -m scripts/pi/mcp_bridge
////   gleam run -m scripts/pi/mcp_bridge -- --loop-timeout-ms 60000 --max-iterations 0

import argv
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import scripts/common/args as cargs
import scripts/common/errors
import scripts/common/fractal
import scripts/common/fsx
import scripts/common/logx
import scripts/common/manifest as mfst
import scripts/common/metrics
import scripts/common/nif
import scripts/common/paths
import scripts/common/registry_index
import scripts/common/smriti
import scripts/common/zenoh

const scope = "pi/mcp_bridge"

pub fn manifest() -> mfst.Manifest {
  mfst.Manifest(
    name: "pi/mcp_bridge",
    category: mfst.Pi,
    fractal_layer: fractal.L6,
    summary: "Reverse MCP bridge: serves scripts.* tools invoked by Pi/others via Zenoh.",
    inputs: [
      mfst.FlagSpec("loop-timeout-ms", "Per-iteration wait for a request", "60000", False),
      mfst.FlagSpec("max-iterations", "0 = loop forever; otherwise cap", "0", False),
      mfst.FlagSpec("pattern", "Zenoh key-expr under indrajaal/mcp/request/ (use * for any single segment)", "*", False),
      mfst.FlagSpec("tool-prefix", "Only serve tools whose name starts with this", "scripts.", False),
    ],
    outputs_schema: "{stamp,served,errors}",
    retention_days: 30,
    auth_level: mfst.L1Trusted,
    sc_id: "SC-SCRIPT-PI-001",
  )
}

pub type Request {
  Request(id: String, tool: String, args: String, reply_to: String)
}

/// Extract a top-level string field from a raw JSON object by substring
/// scan. We keep this deliberately minimal to avoid a JSON-parse dep in this
/// hot path (rustler-backed parsing can be added later).
fn field(json: String, key: String) -> String {
  let needle = "\"" <> key <> "\":\""
  case string.split_once(json, on: needle) {
    Error(_) -> ""
    Ok(#(_, rest)) ->
      case string.split_once(rest, on: "\"") {
        Error(_) -> ""
        Ok(#(v, _)) -> v
      }
  }
}

/// Extract a nested `args` object as a raw JSON fragment (naive balancer).
fn args_field(json: String) -> String {
  let needle = "\"args\":"
  case string.split_once(json, on: needle) {
    Error(_) -> "{}"
    Ok(#(_, rest)) -> string.slice(rest, 0, 400)
  }
}

pub fn parse_request(body: String) -> Result(Request, errors.ScriptError) {
  let id = field(body, "id")
  let tool = field(body, "tool")
  let reply_to = field(body, "reply_to")
  case tool == "" || reply_to == "" {
    True -> Error(errors.Permanent("malformed request: " <> string.slice(body, 0, 120)))
    False -> Ok(Request(id: id, tool: tool, args: args_field(body), reply_to: reply_to))
  }
}

pub fn dispatch(req: Request) -> String {
  case req.tool {
    "scripts.list" -> handle_list()
    "scripts.describe" -> handle_describe(field(req.args, "name"))
    "scripts.metrics" -> metrics.snapshot()
    "scripts.health" -> handle_health()
    "scripts.smriti.get_pref" -> handle_get_pref(field(req.args, "key"))
    "scripts.smriti.set_pref" ->
      handle_set_pref(
        field(req.args, "category"),
        field(req.args, "key"),
        field(req.args, "value"),
      )
    other ->
      "{\"error\":\"unknown tool: " <> other <> "\"}"
  }
}

fn handle_list() -> String {
  let ms = registry_index.all()
  "{\"count\":" <> int.to_string(list.length(ms))
  <> ",\"scripts\":[" <> string.join(list.map(ms, mfst.to_json), ",") <> "]}"
}

fn handle_describe(name: String) -> String {
  case list.find(registry_index.all(), fn(m) { m.name == name }) {
    Ok(m) -> mfst.to_json(m)
    Error(_) -> "{\"error\":\"not found: " <> name <> "\"}"
  }
}

fn handle_health() -> String {
  let _ = zenoh.open()
  "{\"ok\":true,\"zenoh\":" <> zenoh.session_info()
  <> ",\"smriti_pool\":" <> smriti.pool_stats() <> "}"
}

fn handle_get_pref(key: String) -> String {
  case smriti.get_pref(key) {
    Ok(v) -> "{\"ok\":true,\"key\":\"" <> key <> "\",\"value\":\"" <> v <> "\"}"
    Error(_) -> "{\"ok\":true,\"key\":\"" <> key <> "\",\"value\":null}"
  }
}

fn handle_set_pref(category: String, key: String, value: String) -> String {
  let msg = smriti.set_pref(category, key, value)
  "{\"ok\":true,\"msg\":\"" <> msg <> "\"}"
}

fn serve_once(pattern: String, timeout_ms: Int) -> Result(Request, errors.ScriptError) {
  let #(_, body) = nif.mcp_serve_one(pattern, timeout_ms)
  case body {
    "" -> Error(errors.Timeout("no request in " <> int.to_string(timeout_ms) <> "ms"))
    _ -> parse_request(body)
  }
}

fn should_serve(req: Request, prefix: String) -> Bool {
  case prefix {
    "" -> True
    p -> string.starts_with(req.tool, p)
  }
}

fn reply(req: Request, body: String) -> Nil {
  let _ =
    zenoh.put_with(req.reply_to, body, zenoh.InteractiveHigh, zenoh.Block)
  Nil
}

pub type Stats {
  Stats(served: Int, errors: Int)
}

fn loop_iter(
  pattern: String,
  prefix: String,
  timeout_ms: Int,
  max_iter: Int,
  i: Int,
  acc: Stats,
) -> Stats {
  case max_iter > 0 && i >= max_iter {
    True -> acc
    False ->
      case serve_once(pattern, timeout_ms) {
        Ok(req) -> {
          case should_serve(req, prefix) {
            False ->
              loop_iter(pattern, prefix, timeout_ms, max_iter, i + 1, acc)
            True -> {
              logx.info(
                scope,
                "serve id=" <> req.id <> " tool=" <> req.tool
                  <> " reply_to=" <> req.reply_to,
              )
              let out = dispatch(req)
              reply(req, out)
              let _ = metrics.counter_inc("scripts.pi.mcp.served", req.tool, 1)
              loop_iter(
                pattern,
                prefix,
                timeout_ms,
                max_iter,
                i + 1,
                Stats(acc.served + 1, acc.errors),
              )
            }
          }
        }
        Error(errors.Timeout(_)) ->
          loop_iter(pattern, prefix, timeout_ms, max_iter, i + 1, acc)
        Error(e) -> {
          logx.error(scope, "serve err " <> errors.render(e))
          let _ = metrics.counter_inc("scripts.pi.mcp.errors", errors.tag(e), 1)
          loop_iter(
            pattern,
            prefix,
            timeout_ms,
            max_iter,
            i + 1,
            Stats(acc.served, acc.errors + 1),
          )
        }
      }
  }
}

pub fn main() -> Nil {
  let a = cargs.parse(argv.load().arguments)
  let stamp = logx.stamp()
  let timeout_ms =
    result.unwrap(int.parse(cargs.flag(a, "loop-timeout-ms", "60000")), 60_000)
  let max_iter =
    result.unwrap(int.parse(cargs.flag(a, "max-iterations", "0")), 0)
  let pattern = cargs.flag(a, "pattern", "*")
  let prefix = cargs.flag(a, "tool-prefix", "scripts.")

  logx.info(
    scope,
    "start stamp=" <> stamp <> " pattern=" <> pattern
      <> " prefix=" <> prefix
      <> " timeout_ms=" <> int.to_string(timeout_ms)
      <> " max_iter=" <> int.to_string(max_iter),
  )

  let _ = zenoh.open()
  let stats = loop_iter(pattern, prefix, timeout_ms, max_iter, 0, Stats(0, 0))

  let summary =
    "{\"stamp\":\"" <> stamp
      <> "\",\"served\":" <> int.to_string(stats.served)
      <> ",\"errors\":" <> int.to_string(stats.errors) <> "}"
  case fsx.run_dir("pi", "mcp_bridge", stamp) {
    Error(e) -> logx.error(scope, "run_dir: " <> e)
    Ok(dir) -> {
      let _ = fsx.write_file(dir, "result.json", summary)
      logx.info(scope, "outputs " <> paths.join(dir, "result.json"))
    }
  }
  logx.info(scope, "SUMMARY " <> summary)
}
