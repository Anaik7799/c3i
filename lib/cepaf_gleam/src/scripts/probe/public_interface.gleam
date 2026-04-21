//// scripts/probe/public_interface — replacement for the HTTP subset of
//// `sub-projects/c3i/scripts/public_interface_test_suite.sh`.
////
//// SC-SCRIPT-GLEAM-001. Canonical area: lib/cepaf_gleam/src/scripts/probe/.
////
//// Usage:
////   gleam run -m scripts/probe/public_interface
////   gleam run -m scripts/probe/public_interface -- --base http://vm-1.tail55d152.ts.net:4200
////
//// Exit: success on all-green, panic (non-zero) on any probe failure.

import argv
import gleam/int
import gleam/list
import gleam/string
import scripts/common/args as cargs
import scripts/common/fsx
import scripts/common/httpx
import scripts/common/logx
import scripts/common/paths

pub type Case {
  Case(name: String, path: String, want: String)
}

pub type Outcome {
  Outcome(name: String, ok: Bool, code: Int, detail: String)
}

pub fn cases() -> List(Case) {
  [
    Case("health.root", "/health", "\"status\":\"ok\""),
    Case("api.v1.status", "/api/v1/status", "\"total\""),
    Case("api.v1.health", "/api/v1/health", "\"system\""),
    Case("api.v1.dashboard", "/api/v1/dashboard", "\"tasks\""),
    Case("page.index", "/", "<html"),
    Case("page.kpi", "/kpi", "<html"),
    Case("page.session", "/session", "<html"),
    Case("page.pi-symbiosis", "/pi-symbiosis", "<html"),
    Case("page.ferriskey", "/ferriskey", "<html"),
    Case("page.task.1a92520c", "/task-id/1a92520c", "<html"),
  ]
}

fn run_case(base: String, c: Case) -> Outcome {
  let url = base <> c.path
  let r = httpx.get(url)
  let ok = r.ok && httpx.body_contains(r, c.want)
  Outcome(c.name, ok, r.code, string.slice(r.body, 0, 80))
}

fn render(o: Outcome) -> String {
  let mark = case o.ok {
    True -> "OK  "
    False -> "FAIL"
  }
  "  " <> mark <> " " <> o.name <> " code=" <> int.to_string(o.code) <> " " <> o.detail
}

fn as_json_line(o: Outcome) -> String {
  "{\"name\":\"" <> o.name
  <> "\",\"ok\":" <> case o.ok {
    True -> "true"
    False -> "false"
  }
  <> ",\"code\":" <> int.to_string(o.code)
  <> ",\"detail\":\"" <> string.replace(o.detail, "\"", "\\\"") <> "\"}"
}

pub fn main() -> Nil {
  let a = cargs.parse(argv.load().arguments)
  let base = cargs.flag(a, "base", "http://vm-1.tail55d152.ts.net:4200")
  let stamp = logx.stamp()
  let scope = "probe/public_interface"
  logx.info(scope, "base=" <> base <> " stamp=" <> stamp)

  let results = list.map(cases(), run_case(base, _))
  let passed = list.count(results, fn(o) { o.ok })
  let total = list.length(results)
  let summary =
    "SUMMARY: pass=" <> int.to_string(passed)
    <> "/" <> int.to_string(total)
    <> " base=" <> base

  list.each(results, fn(o) { logx.info(scope, render(o)) })
  logx.info(scope, summary)

  // Persist under data/script-output/probe/public_interface/<stamp>/
  case fsx.run_dir("probe", "public_interface", stamp) {
    Error(e) -> logx.error(scope, "run_dir: " <> e)
    Ok(dir) -> {
      let lines = list.map(results, as_json_line) |> string.join("\n")
      let _ = fsx.write_file(dir, "result.json", "{\"base\":\"" <> base
        <> "\",\"stamp\":\"" <> stamp
        <> "\",\"passed\":" <> int.to_string(passed)
        <> ",\"total\":" <> int.to_string(total)
        <> ",\"results\":[" <> string.join(list.map(results, as_json_line), ",") <> "]}")
      let _ = fsx.write_file(dir, "stdout.log",
        list.map(results, render) |> string.join("\n") <> "\n" <> summary <> "\n")
      logx.info(scope, "outputs written to " <> paths.join(dir, "result.json"))
      // silence unused warning for lines
      let _ = lines
      Nil
    }
  }

  case passed == total {
    True -> Nil
    False -> {
      logx.error(scope, "probes failed: " <> int.to_string(total - passed))
      panic as "public_interface probes failed"
    }
  }
}
