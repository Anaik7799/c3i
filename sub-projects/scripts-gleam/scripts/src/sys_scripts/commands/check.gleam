//// `check` — run every validation in order and report a consolidated
//// result. Intended as a pre-commit gate and a one-line CI target.
////
//// Each check is a `Check { name, dir, cmd, args }` record. They run
//// sequentially (parallel would be nicer but shellout + stdout mixing
//// would make the output unreadable). Failures are accumulated so the
//// user sees every problem, not just the first.

import gleam/int
import gleam/io
import gleam/list
import gleam/string
import shellout
import simplifile
import sys_scripts/workspace

pub type Check {
  Check(
    name: String,
    dir: String,
    cmd: String,
    args: List(String),
    /// If true, this check is skipped in `--fast` mode (used by the
    /// pre-commit hook). Reserve True for checks that take more than
    /// ~5 seconds on a warm cache.
    slow: Bool,
  )
}

pub type Outcome {
  Pass(check: Check)
  Fail(check: Check, message: String)
}

pub fn run(args: List(String)) -> Result(Nil, Nil) {
  let fast = list.contains(args, "--fast")
  case workspace.repo_root() {
    Error(err) -> {
      io.println_error("check: " <> workspace.format_error(err))
      Error(Nil)
    }
    Ok(repo_root) -> {
      let checks =
        enumerate(repo_root)
        |> list.filter(fn(c) { !fast || !c.slow })
      let banner = case fast {
        True -> " (fast mode — skipping slow checks)"
        False -> ""
      }
      io.println(
        "running " <> int.to_string(list.length(checks)) <> " checks" <> banner,
      )
      let outcomes = list.map(checks, run_check)
      summarize(outcomes)
    }
  }
}

/// The set of checks applicable to the current workspace. Entries
/// whose manifest doesn't exist are filtered out.
pub fn enumerate(repo_root: String) -> List(Check) {
  let candidates = [
    #(
      repo_root <> "/scripts/gleam.toml",
      Check(
        name: "gleam format --check",
        dir: repo_root <> "/scripts",
        cmd: "gleam",
        args: ["format", "--check", "src", "test"],
        slow: False,
      ),
    ),
    #(
      repo_root <> "/scripts/gleam.toml",
      Check(
        name: "gleam test",
        dir: repo_root <> "/scripts",
        cmd: "gleam",
        args: ["test"],
        slow: False,
      ),
    ),
    #(
      repo_root <> "/Cargo.toml",
      Check(
        name: "cargo fmt --check",
        dir: repo_root,
        cmd: "cargo",
        args: ["fmt", "--all", "--", "--check"],
        slow: False,
      ),
    ),
    #(
      repo_root <> "/Cargo.toml",
      Check(
        name: "cargo clippy -D warnings",
        dir: repo_root,
        cmd: "cargo",
        args: [
          "clippy", "--workspace", "--all-targets", "--all-features", "--", "-D",
          "warnings",
        ],
        slow: True,
      ),
    ),
    #(
      repo_root <> "/Cargo.toml",
      Check(
        name: "cargo nextest run",
        dir: repo_root,
        cmd: "cargo",
        args: ["nextest", "run", "--workspace", "--no-fail-fast"],
        slow: False,
      ),
    ),
    #(
      repo_root <> "/flake.nix",
      // `nix flake check` forces `system.build.toplevel` on every
      // nixosConfiguration, which errors until we have real
      // hardware-configuration.nix + SSH keys. Instead, targeted evals
      // confirm every host and the x86_64-linux devShell parse.
      Check(
        name: "nix eval (devShell + nixosConfigurations)",
        dir: repo_root,
        cmd: "sh",
        args: [
          "-c",
          "set -e; "
            <> "nix eval --no-write-lock-file "
            <> ".#devShells.x86_64-linux.default.name >/dev/null && "
            <> "for h in $(nix eval --no-write-lock-file --apply 'x: builtins.concatStringsSep \" \" (builtins.attrNames x)' .#nixosConfigurations --raw); do "
            <> "  nix eval --no-write-lock-file \".#nixosConfigurations.$h.config.networking.hostName\" >/dev/null; "
            <> "done",
        ],
        slow: True,
      ),
    ),
  ]
  candidates
  |> list.filter(fn(entry) {
    let #(manifest, _) = entry
    case simplifile.is_file(manifest) {
      Ok(True) -> True
      _ -> False
    }
  })
  |> list.map(fn(entry) {
    let #(_, check) = entry
    check
  })
}

fn run_check(check: Check) -> Outcome {
  io.println("  → " <> check.name)
  case
    shellout.command(run: check.cmd, with: check.args, in: check.dir, opt: [])
  {
    Ok(_) -> Pass(check)
    Error(#(code, err)) ->
      Fail(check, "exit " <> int.to_string(code) <> ": " <> string.trim(err))
  }
}

fn summarize(outcomes: List(Outcome)) -> Result(Nil, Nil) {
  let failures = list.filter(outcomes, is_fail)
  let pass_count = list.length(outcomes) - list.length(failures)
  io.println("")
  io.println(
    "summary: "
    <> int.to_string(pass_count)
    <> " passed, "
    <> int.to_string(list.length(failures))
    <> " failed",
  )
  case failures {
    [] -> Ok(Nil)
    _ -> {
      io.println("")
      io.println("failures:")
      list.each(failures, print_failure)
      Error(Nil)
    }
  }
}

fn is_fail(o: Outcome) -> Bool {
  case o {
    Fail(_, _) -> True
    Pass(_) -> False
  }
}

fn print_failure(o: Outcome) -> Nil {
  case o {
    Fail(check, message) -> {
      io.println("  ✗ " <> check.name)
      io.println("    " <> truncate(message, 200))
    }
    Pass(_) -> Nil
  }
}

fn truncate(s: String, max: Int) -> String {
  case string.length(s) > max {
    True -> string.slice(s, 0, max) <> "..."
    False -> s
  }
}
