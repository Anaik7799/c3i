//// scripts/verify/effect_ts_guard — Gleam port of effect-ts-guard.sh.
////
//// SC-EFFECT-TS-001..007 enforcement. Scans
//// `lib/cepaf_gleam/priv/static/*.js` and refuses any non-bundled, non-allowlisted
//// browser JS. New JS MUST be authored as TypeScript under
//// `lib/cepaf_gleam/priv/web-build/src/` using Effect-TS, then bundled via esbuild
//// (`*.bundled.js`).
////
//// Per SC-SCRIPT-GLEAM-001 + operator directive (2026-04-30): no shell scripts.
//// This module is the sole authoritative guard; .claude/scripts/effect-ts-guard.sh
//// has been removed.
////
//// Exit codes:
////   0 — compliant
////   1 — violation (lists offending files on stderr)
////
//// Usage:
////   gleam run -m scripts/verify/effect_ts_guard
////
//// Hook invocation (.claude/settings.json PreToolUse):
////   cd sub-projects/scripts-gleam && gleam run -m scripts/verify/effect_ts_guard

import argv
import envoy
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import simplifile

const legacy_allow: List(String) = [
  "agents-grid.js", "allium-grid.js", "bicameral-grid.js", "biomorphic-grid.js",
  "bridge-grid.js", "cockpit-grid.js", "component-demo-grid.js", "config-grid.js",
  "dashboard-grid.js", "database-grid.js", "evolution-grid.js", "federation-grid.js",
  "git-grid.js", "healthgrid-grid.js", "holon-grid.js", "homeostasis-grid.js",
  "immune-grid.js", "integrity-grid.js", "kms-grid.js", "knowledge-grid.js",
  "mcp-grid.js", "metabolic-grid.js", "planning-dashboard-grid.js",
  "planning-grid.js", "podman-grid.js", "prajna-grid.js", "singularity-grid.js",
  "smriti-grid.js", "substrate-grid.js", "telemetry-grid.js", "verification-grid.js",
  "zenoh-grid.js",
  "planning-chips-handler.js", "planning-utils.js",
  "sw-register.js", "sw.js", "health-grid-grid.js",
]

pub fn main() -> Nil {
  let _ = argv.load().arguments
  let root = case envoy.get("C3I_REPO_ROOT") {
    Ok(r) -> r
    Error(_) -> "/home/an/dev/ver/c3i"
  }
  let static_dir = root <> "/lib/cepaf_gleam/priv/static"
  let build_src = root <> "/lib/cepaf_gleam/priv/web-build/src"
  let build_pkg = root <> "/lib/cepaf_gleam/priv/web-build/package.json"

  let entries = case simplifile.read_directory(static_dir) {
    Ok(es) -> es
    Error(_) -> []
  }

  let violators =
    entries
    |> list.filter(fn(name) { string.ends_with(name, ".js") })
    |> list.filter(fn(name) { !string.ends_with(name, ".bundled.js") })
    |> list.filter(fn(name) { !list.contains(legacy_allow, name) })
    |> list.map(fn(name) { static_dir <> "/" <> name })

  // If any TS sources exist, package.json must exist too.
  let ts_sources =
    simplifile.read_directory(build_src)
    |> result.unwrap([])
    |> list.filter(fn(n) { string.ends_with(n, ".ts") })
  let pkg_missing = case ts_sources, simplifile.is_file(build_pkg) {
    [], _ -> False
    _, Ok(True) -> False
    _, _ -> True
  }

  let pkg_violations = case pkg_missing {
    True -> [build_pkg <> " (missing — TS sources present without package.json)"]
    False -> []
  }

  let all = list.append(violators, pkg_violations)

  case all {
    [] -> Nil
    vs -> {
      io.println_error(
        "[SC-EFFECT-TS-001 VIOLATION] Non-compliant browser JS detected:",
      )
      list.each(vs, fn(v) { io.println_error("  - " <> v) })
      io.println_error("")
      io.println_error(
        "Per .claude/rules/effect-ts-only-js.md, all NEW browser JS MUST be",
      )
      io.println_error(
        "authored as TypeScript under priv/web-build/src/ using Effect-TS,",
      )
      io.println_error("and bundled via esbuild --format=iife.")
      halt(1)
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil
