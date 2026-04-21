//// scripts/common/paths — canonical path resolution for gleam-run scripts.
////
//// SC-SCRIPT-GLEAM-001. Scripts MUST write outputs under the conventional
//// `data/script-output/<category>/<name>/<timestamp>/` tree.

import envoy
import gleam/int
import gleam/result
import gleam/string

/// Repo root resolved from env (`C3I_REPO_ROOT`) or a sensible default.
///
/// Convention: developer shell sets `C3I_REPO_ROOT` to the absolute repo root
/// (the directory containing `lib/cepaf_gleam/`). If unset, default to the
/// known absolute path used in this project.
pub fn repo_root() -> String {
  case envoy.get("C3I_REPO_ROOT") {
    Ok(v) -> v
    Error(_) -> "/home/an/dev/ver/c3i"
  }
}

/// Base directory for all script outputs.
pub fn output_root() -> String {
  repo_root() <> "/data/script-output"
}

/// Compute the output directory for a specific invocation.
///
///   output_dir("probe", "public_interface", "20260421-095500")
///   → "/<root>/data/script-output/probe/public_interface/20260421-095500"
pub fn output_dir(category: String, name: String, stamp: String) -> String {
  output_root() <> "/" <> category <> "/" <> name <> "/" <> stamp
}

/// Deterministic filesystem-safe timestamp string (caller supplies).
/// Provided as a pure helper; scripts typically call `scripts/common/logx.stamp()`.
pub fn pad2(n: Int) -> String {
  let s = int.to_string(n)
  case string.length(s) {
    1 -> "0" <> s
    _ -> s
  }
}

/// Join two path segments with a single `/`.
pub fn join(a: String, b: String) -> String {
  case string.ends_with(a, "/") {
    True -> a <> b
    False -> a <> "/" <> b
  }
}

/// Guarantee a string is a valid filesystem segment (no `/` or `:`).
pub fn safe_segment(s: String) -> String {
  s
  |> string.replace(each: "/", with: "_")
  |> string.replace(each: ":", with: "-")
  |> string.replace(each: "\\", with: "_")
}

/// Attempt to resolve a relative path against repo root; absolute paths
/// pass through unchanged.
pub fn resolve(p: String) -> Result(String, String) {
  case string.starts_with(p, "/") {
    True -> Ok(p)
    False -> Ok(repo_root() <> "/" <> p)
  }
  |> result.map_error(fn(_) { "path resolve failed" })
}
