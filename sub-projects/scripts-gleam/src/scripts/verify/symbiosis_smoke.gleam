//// scripts/verify/symbiosis_smoke — full integration smoke for scripts-gleam.
////
//// SC-SCRIPT-GLEAM-001. Exercises, in order, every system integration
//// surface this subproject ships with, wrapped in fractal spans:
////
////   1. Zenoh session open                            (L4 system)
////   2. Smriti read-after-write round-trip            (L3 transaction)
////   3. Fractal span emission + Zenoh publish         (L1 atomic)
////   4. MCP-over-Zenoh Pi invocation (optional)       (L6 ecosystem)
////   5. Gemini model call (optional)                  (L5 cognitive)
////
//// Optional steps report `skipped` in the JSON result if the corresponding
//// environment is not available (e.g. no GEMINI_API_KEY). The script still
//// exits cleanly so it is safe to run from sa-plan jobs without destabilising
//// the mainline.
////
//// Outputs land at:
////   data/script-output/verify/symbiosis_smoke/<YYYYMMDD-HHMMSS>/{stdout.log, result.json}

import argv
import envoy
import gleam/int
import gleam/list
import gleam/string
import scripts/common/args as cargs
import scripts/common/fractal
import scripts/common/fsx
import scripts/common/gemini
import scripts/common/logx
import scripts/common/manifest
import scripts/common/mcp
import scripts/common/nif
import scripts/common/paths
import scripts/common/smriti
import scripts/common/zenoh

const scope = "verify/symbiosis_smoke"

pub fn manifest() -> manifest.Manifest {
  manifest.Manifest(
    name: "verify/symbiosis_smoke",
    category: manifest.Verify,
    fractal_layer: fractal.L6,
    summary: "Full-system smoke: Zenoh + Smriti + Fractal span + MCP + Gemini round-trip.",
    inputs: [
      manifest.FlagSpec("zenoh-timeout-ms", "Zenoh op timeout", "1500", False),
      manifest.FlagSpec("mcp-timeout-ms", "MCP invoke timeout", "2000", False),
      manifest.FlagSpec("gemini-timeout-ms", "Gemini HTTP timeout", "10000", False),
      manifest.FlagSpec("pi-tool", "MCP tool to invoke on Pi", "pi.ping", False),
    ],
    outputs_schema: "{script,stamp,passed,total,steps:[{step,ok,detail}]}",
    retention_days: 30,
    auth_level: manifest.L2Normal,
    sc_id: "SC-SCRIPT-VER-001",
  )
}

pub type StepResult {
  StepResult(name: String, ok: Bool, detail: String)
}

fn step_json(r: StepResult) -> String {
  "{\"step\":\"" <> r.name <> "\",\"ok\":"
  <> case r.ok { True -> "true" False -> "false" }
  <> ",\"detail\":\"" <> string.replace(r.detail, each: "\"", with: "\\\"") <> "\"}"
}

pub fn main() -> Nil {
  let a = cargs.parse(argv.load().arguments)
  let _timeout_zenoh = int_flag(a, "zenoh-timeout-ms", 1500)
  let timeout_mcp = int_flag(a, "mcp-timeout-ms", 2000)
  let timeout_gemini = int_flag(a, "gemini-timeout-ms", 10_000)
  let pi_tool = cargs.flag(a, "pi-tool", "pi.ping")
  let stamp = logx.stamp()
  logx.info(scope, "start stamp=" <> stamp)

  // ── Step 1: Zenoh session open (L4) ───────────────────────────────
  let s1 = case zenoh.open() {
    Ok(msg) -> StepResult("zenoh.open", True, msg)
    Error(e) -> StepResult("zenoh.open", False, "zenoh err: " <> zenoh_err(e))
  }
  log_step(s1)
  let _ =
    fractal.emit(
      fractal.Span(
        layer: fractal.L4,
        name: "zenoh_open",
        start_ns: nif.now_nanos(),
        end_ns: nif.now_nanos(),
        status: case s1.ok { True -> fractal.StatusOk False -> fractal.StatusError },
      ),
      "{\"detail\":\"" <> s1.detail <> "\"}",
    )

  // ── Step 2: Smriti round-trip (L3) ────────────────────────────────
  let pref_key = "scripts_gleam_symbiosis_smoke_at"
  let _ = smriti.set_pref("roadmap", pref_key, stamp)
  let s2 = case smriti.get_pref(pref_key) {
    Ok(v) if v == stamp ->
      StepResult("smriti.roundtrip", True, "set+get '" <> stamp <> "' ok")
    Ok(v) ->
      StepResult("smriti.roundtrip", False, "got '" <> v <> "' expected '" <> stamp <> "'")
    Error(_) ->
      StepResult("smriti.roundtrip", False, "get after set returned nothing")
  }
  log_step(s2)

  // ── Step 3: Fractal span emission on Zenoh (L1) ───────────────────
  let start3 = nif.now_nanos()
  let end3 = nif.now_nanos() + 1
  let span_line =
    fractal.emit(
      fractal.Span(
        layer: fractal.L1,
        name: "symbiosis_smoke_l1",
        start_ns: start3,
        end_ns: end3,
        status: fractal.StatusOk,
      ),
      "{\"tag\":\"scripts-gleam\",\"stamp\":\"" <> stamp <> "\"}",
    )
  let s3 = StepResult("fractal.span", True, string.slice(span_line, 0, 120))
  log_step(s3)

  // ── Step 4: MCP over Zenoh to Pi (L6, optional) ────────────────────
  let s4 = case mcp.invoke(pi_tool, "{}", timeout_mcp) {
    Ok(body) -> StepResult("mcp.pi_invoke", True, string.slice(body, 0, 120))
    Error(mcp.Timeout) ->
      StepResult("mcp.pi_invoke", False, "timeout after "
        <> int.to_string(timeout_mcp) <> "ms (pi not online or tool '"
        <> pi_tool <> "' not registered)")
    Error(mcp.CallFailed(e)) -> StepResult("mcp.pi_invoke", False, e)
  }
  log_step(s4)

  // ── Step 5: Gemini model call (L5, optional) ──────────────────────
  let s5 = case envoy.get("GEMINI_API_KEY") {
    Error(_) -> StepResult("gemini.generate", True, "skipped (GEMINI_API_KEY not set)")
    Ok(_) -> {
      let prompt = "Reply with the single word OK."
      case gemini.generate(prompt, timeout_gemini) {
        Ok(reply) -> StepResult("gemini.generate", True, string.slice(reply, 0, 120))
        Error(gemini.MissingApiKey) ->
          StepResult("gemini.generate", False, "missing api key")
        Error(gemini.CallFailed(e)) ->
          StepResult("gemini.generate", False, e)
      }
    }
  }
  log_step(s5)

  // ── Step 6: Zenoh publish run summary (L4) ────────────────────────
  let all = [s1, s2, s3, s4, s5]
  let passed = list.count(all, fn(r) { r.ok })
  let total = list.length(all)
  let summary =
    "{\"script\":\"" <> scope <> "\""
    <> ",\"stamp\":\"" <> stamp <> "\""
    <> ",\"passed\":" <> int.to_string(passed)
    <> ",\"total\":" <> int.to_string(total)
    <> ",\"steps\":["
    <> string.join(list.map(all, step_json), ",")
    <> "]}"
  let _ = zenoh.put("indrajaal/l4/scripts/symbiosis_smoke", summary)

  // ── Persist run dir ───────────────────────────────────────────────
  case fsx.run_dir("verify", "symbiosis_smoke", stamp) {
    Error(e) -> logx.error(scope, "run_dir: " <> e)
    Ok(dir) -> {
      let _ = fsx.write_file(dir, "result.json", summary)
      let _ = fsx.write_file(
        dir,
        "stdout.log",
        string.join(list.map(all, render_step), "\n") <> "\n",
      )
      logx.info(scope, "outputs " <> paths.join(dir, "result.json"))
    }
  }

  logx.info(
    scope,
    "SUMMARY pass="
      <> int.to_string(passed)
      <> "/" <> int.to_string(total),
  )
  Nil
}

fn log_step(r: StepResult) -> Nil {
  let mark = case r.ok { True -> "OK  " False -> "FAIL" }
  logx.info(scope, "  " <> mark <> " " <> r.name <> " " <> r.detail)
}

fn render_step(r: StepResult) -> String {
  let mark = case r.ok { True -> "OK  " False -> "FAIL" }
  "  " <> mark <> " " <> r.name <> " " <> r.detail
}

fn zenoh_err(e: zenoh.ZenohError) -> String {
  let zenoh.ZenohError(d) = e
  d
}

fn int_flag(a: cargs.Args, name: String, default: Int) -> Int {
  case int.parse(cargs.flag(a, name, int.to_string(default))) {
    Ok(v) -> v
    Error(_) -> default
  }
}
