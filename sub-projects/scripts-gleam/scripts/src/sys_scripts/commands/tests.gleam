//// `test` — run all test suites across the workspace.
////
//// Today: Gleam (this project's tests) + Rust (workspace `cargo nextest`)
//// when a Cargo.toml is present at the repo root. TS will slot in the same
//// way once there's a subproject that declares a test script.

import gleam/io
import gleam/list
import gleam/result
import shellout
import simplifile
import sys_scripts/workspace

pub type Suite {
  Suite(name: String, dir: String, cmd: String, args: List(String))
}

pub fn run(_args: List(String)) -> Result(Nil, Nil) {
  case workspace.repo_root() {
    Error(err) -> {
      io.println_error("test: " <> workspace.format_error(err))
      Error(Nil)
    }
    Ok(repo_root) ->
      suites(repo_root)
      |> list.try_each(run_suite)
      |> result.replace_error(Nil)
  }
}

/// Enumerate suites that exist in the current workspace.
/// Each suite is gated on the presence of its manifest file.
fn suites(repo_root: String) -> List(Suite) {
  let all = [
    #(
      "gleam",
      repo_root <> "/scripts/gleam.toml",
      Suite(
        name: "gleam (scripts/)",
        dir: repo_root <> "/scripts",
        cmd: "gleam",
        args: ["test"],
      ),
    ),
    #(
      "rust",
      repo_root <> "/Cargo.toml",
      Suite(name: "rust (cargo nextest)", dir: repo_root, cmd: "cargo", args: [
        "nextest",
        "run",
        "--workspace",
      ]),
    ),
  ]
  all
  |> list.filter(fn(entry) {
    let #(_label, manifest, _suite) = entry
    case simplifile.is_file(manifest) {
      Ok(True) -> True
      _ -> False
    }
  })
  |> list.map(fn(entry) {
    let #(_label, _manifest, suite) = entry
    suite
  })
}

fn run_suite(suite: Suite) -> Result(Nil, Nil) {
  io.println("\n=== " <> suite.name <> " ===")
  case
    shellout.command(run: suite.cmd, with: suite.args, in: suite.dir, opt: [])
  {
    Ok(out) -> {
      io.println(out)
      Ok(Nil)
    }
    Error(#(_code, err)) -> {
      io.println_error(err)
      Error(Nil)
    }
  }
}
