//// scripts/public_interface_probe — gleam run replacement for a
//// subset of `scripts/public_interface_test_suite.sh`.
////
//// SC-SCRIPT-GLEAM-001: gleam-only scripting mandate.
////
//// Usage:
////   gleam run -m scripts/public_interface_probe
////   gleam run -m scripts/public_interface_probe -- --base https://vm-1.tail55d152.ts.net:8443 --insecure
////
//// Exit code 0 on all-green, 1 on any failure.

import argv
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

pub type ProbeCfg {
  ProbeCfg(base: String, insecure: Bool)
}

pub type ProbeResult {
  ProbeResult(name: String, ok: Bool, code: Int, detail: String)
}

/// Parse a minimal --base/--insecure argument pair.
pub fn parse_args(args: List(String)) -> ProbeCfg {
  let default = ProbeCfg(base: "http://vm-1.tail55d152.ts.net:4200", insecure: False)
  parse_loop(args, default)
}

fn parse_loop(args: List(String), acc: ProbeCfg) -> ProbeCfg {
  case args {
    [] -> acc
    ["--base", v, ..rest] -> parse_loop(rest, ProbeCfg(..acc, base: v))
    ["--insecure", ..rest] -> parse_loop(rest, ProbeCfg(..acc, insecure: True))
    [_, ..rest] -> parse_loop(rest, acc)
  }
}

fn probe(cfg: ProbeCfg, name: String, path: String, want_substr: String) -> ProbeResult {
  let url = cfg.base <> path
  case request.to(url) {
    Error(_) ->
      ProbeResult(name: name, ok: False, code: 0, detail: "invalid url: " <> url)
    Ok(req) -> {
      let req = request.set_method(req, http.Get)
      case httpc.send(req) {
        Error(_) ->
          ProbeResult(name: name, ok: False, code: 0, detail: "send error: " <> url)
        Ok(resp) -> {
          let r: Response(String) = resp
          let ok_code = r.status == 200
          let body_ok = case want_substr {
            "" -> True
            s -> string.contains(r.body, s)
          }
          ProbeResult(
            name: name,
            ok: ok_code && body_ok,
            code: r.status,
            detail: string.slice(r.body, 0, 80),
          )
        }
      }
    }
  }
}

pub fn probes(cfg: ProbeCfg) -> List(ProbeResult) {
  [
    probe(cfg, "health.root", "/health", "\"status\":\"ok\""),
    probe(cfg, "api.v1.status", "/api/v1/status", "\"total\""),
    probe(cfg, "api.v1.health", "/api/v1/health", "\"system\""),
    probe(cfg, "api.v1.dashboard", "/api/v1/dashboard", "\"tasks\""),
    probe(cfg, "page.index", "/", "<html"),
    probe(cfg, "page.kpi", "/kpi", "<html"),
    probe(cfg, "page.session", "/session", "<html"),
    probe(cfg, "page.pi-symbiosis", "/pi-symbiosis", "<html"),
    probe(cfg, "page.ferriskey", "/ferriskey", "<html"),
    probe(cfg, "page.task.1a92520c", "/task-id/1a92520c", "<html"),
  ]
}

fn render(r: ProbeResult) -> String {
  let mark = case r.ok {
    True -> "OK "
    False -> "FAIL"
  }
  "  " <> mark <> " " <> r.name <> " code=" <> int.to_string(r.code) <> " " <> r.detail
}

pub fn main() -> Nil {
  let cfg = parse_args(argv.load().arguments)
  io.println("Gleam Public Interface Probe (SC-SCRIPT-GLEAM-001)")
  io.println("  base:     " <> cfg.base)
  io.println("  insecure: " <> case cfg.insecure {
    True -> "true"
    False -> "false"
  })
  let results = probes(cfg)
  list.each(results, fn(r) { io.println(render(r)) })
  let passed = list.count(results, fn(r) { r.ok })
  let total = list.length(results)
  io.println(
    "\nSUMMARY: pass=" <> int.to_string(passed)
    <> "/" <> int.to_string(total)
    <> " base=" <> cfg.base,
  )
  case passed == total {
    True -> Nil
    False -> {
      io.println("FAILED: some probes did not pass")
      // Non-zero exit so gleam run surfaces failure to the caller.
      // We rely on panic to trip a non-zero exit.
      let _ = result.try(Error("probe_failed"), fn(_) { Ok(Nil) })
      panic as "probe failures"
    }
  }
}
