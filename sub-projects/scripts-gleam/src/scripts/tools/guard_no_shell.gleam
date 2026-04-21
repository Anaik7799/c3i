//// scripts/tools/guard_no_shell — enforce SC-SCRIPT-GLEAM-001 hard rule.
////
//// Walks the c3i workspace and fails (panic → non-zero exit) if any newly
//// introduced `.sh`/`.py`/`.mjs` file exists outside an explicit allowlist.
////
//// Intended to run as a pre-commit hook and in CI; the gleam implementation
//// replaces the need for a shell-based linter.
////
//// Usage:
////   gleam run -m scripts/tools/guard_no_shell
////   gleam run -m scripts/tools/guard_no_shell -- --roots sub-projects/scripts-gleam

import argv
import gleam/int
import gleam/list
import gleam/string
import scripts/common/args as cargs
import scripts/common/fractal
import scripts/common/fsx
import scripts/common/logx
import scripts/common/manifest as mfst
import scripts/common/paths
import simplifile

const scope = "tools/guard_no_shell"

pub fn manifest() -> mfst.Manifest {
  mfst.Manifest(
    name: "tools/guard_no_shell",
    category: mfst.Tools,
    fractal_layer: fractal.L4,
    summary: "Fail if new .sh/.py/.mjs are introduced outside the documented allowlist.",
    inputs: [
      mfst.FlagSpec("roots", "Comma-separated roots to walk (relative to repo)", "", False),
    ],
    outputs_schema: "{stamp,violations:[path],allowed_violations:[path]}",
    retention_days: 30,
    auth_level: mfst.L2Normal,
    sc_id: "SC-SCRIPT-GRD-001",
  )
}

/// Files/directories we intentionally tolerate (legacy trees pending migration).
/// Each entry is a substring check against the absolute path.
///
/// IMPORTANT: migrated legacy scripts MUST be removed from the repo and from
/// this allowlist (migration.md tracks the status).
fn allowlist() -> List(String) {
  [
    // Build/vendor artefacts — not repo-authored code.
    "/build/",
    "/target/",
    "/.devenv/",
    "/node_modules/",
    // Deps we vendor under lib/cepaf_gleam but do not maintain.
    "/lib/cepaf_gleam/test/playwright/",
    // Legacy script trees pending migration (tracked in migration.md).
    "/sub-projects/c3i/scripts/",
    "/scripts/",
  ]
}

fn is_tracked_shell(name: String) -> Bool {
  string.ends_with(name, ".sh")
  || string.ends_with(name, ".py")
  || string.ends_with(name, ".mjs")
}

fn walk(root: String, acc: List(String)) -> List(String) {
  case simplifile.read_directory(root) {
    Error(_) -> acc
    Ok(entries) ->
      list.fold(entries, acc, fn(a, entry) {
        let full = root <> "/" <> entry
        case simplifile.is_directory(full) {
          Ok(True) -> walk(full, a)
          _ ->
            case is_tracked_shell(entry) {
              True -> [full, ..a]
              False -> a
            }
        }
      })
  }
}

fn is_allowed(path: String) -> Bool {
  list.any(allowlist(), fn(pat) { string.contains(path, pat) })
}

pub fn main() -> Nil {
  let a = cargs.parse(argv.load().arguments)
  let stamp = logx.stamp()
  let roots_s = cargs.flag(a, "roots", "")
  let roots =
    case roots_s {
      "" -> [paths.repo_root()]
      s ->
        string.split(s, ",")
        |> list.map(fn(r) {
          case string.starts_with(r, "/") {
            True -> r
            False -> paths.repo_root() <> "/" <> r
          }
        })
    }
  logx.info(
    scope,
    "start stamp=" <> stamp <> " roots=" <> string.join(roots, ","),
  )

  let found =
    list.fold(roots, [], fn(acc, r) { walk(r, acc) })

  let #(violations, allowed_violations) =
    list.partition(found, fn(p) { !is_allowed(p) })

  list.each(allowed_violations, fn(p) {
    logx.info(scope, "  allowed  " <> p)
  })
  list.each(violations, fn(p) {
    logx.error(scope, "  BLOCKED  " <> p)
  })

  let summary =
    "{\"stamp\":\"" <> stamp
      <> "\",\"roots\":[" <> string.join(list.map(roots, fn(r) { "\"" <> r <> "\"" }), ",")
      <> "],\"violations\":" <> int.to_string(list.length(violations))
      <> ",\"allowed_violations\":" <> int.to_string(list.length(allowed_violations))
      <> "}"

  case fsx.run_dir("tools", "guard_no_shell", stamp) {
    Error(e) -> logx.error(scope, "run_dir: " <> e)
    Ok(dir) -> {
      let _ = fsx.write_file(dir, "result.json", summary)
      let _ =
        fsx.write_file(
          dir,
          "stdout.log",
          "Violations:\n"
            <> string.join(list.map(violations, fn(v) { "  " <> v }), "\n")
            <> "\nAllowed:\n"
            <> string.join(list.map(allowed_violations, fn(v) { "  " <> v }), "\n")
            <> "\n",
        )
      logx.info(scope, "outputs " <> paths.join(dir, "result.json"))
    }
  }

  case list.is_empty(violations) {
    True -> logx.info(scope, "PASS " <> summary)
    False -> {
      logx.error(
        scope,
        "FAIL "
          <> int.to_string(list.length(violations))
          <> " forbidden file(s) found outside allowlist",
      )
      panic as "SC-SCRIPT-GLEAM-001 violation: shell/python files found"
    }
  }
}
