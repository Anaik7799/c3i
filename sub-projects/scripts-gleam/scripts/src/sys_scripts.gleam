//// Entry point for `gleam run -m sys_scripts -- <subcommand> [args...]`.
////
//// Per AGENTS.md, all workspace automation (build / test / fmt / deploy /
//// codegen / file munging) lives in this module tree. No bash, no
//// PowerShell, no ad-hoc Python. Shell invocations happen via `shellout`
//// at the edges; the dispatcher and command logic stay pure.

import argv
import gleam/io
import gleam/string
import sys_scripts/commands/check
import sys_scripts/commands/deploy
import sys_scripts/commands/doctor
import sys_scripts/commands/fmt
import sys_scripts/commands/inventory
import sys_scripts/commands/secrets
import sys_scripts/commands/tests as test_cmd

pub type Command {
  Doctor
  Fmt
  Test
  Deploy
  Check
  Inventory
  Secrets
  Help
  Unknown(String)
}

pub fn parse(args: List(String)) -> #(Command, List(String)) {
  case args {
    [] -> #(Help, [])
    ["doctor", ..rest] -> #(Doctor, rest)
    ["fmt", ..rest] -> #(Fmt, rest)
    ["test", ..rest] -> #(Test, rest)
    ["deploy", ..rest] -> #(Deploy, rest)
    ["check", ..rest] -> #(Check, rest)
    ["inventory", ..rest] -> #(Inventory, rest)
    ["secrets", ..rest] -> #(Secrets, rest)
    ["help", ..rest] | ["--help", ..rest] | ["-h", ..rest] -> #(Help, rest)
    [other, ..rest] -> #(Unknown(other), rest)
  }
}

pub fn main() {
  let #(cmd, rest) = parse(argv.load().arguments)
  case cmd {
    Doctor -> doctor.run(rest)
    Fmt -> fmt.run(rest)
    Test -> test_cmd.run(rest)
    Deploy -> deploy.run(rest)
    Check -> check.run(rest)
    Inventory -> inventory.run(rest)
    Secrets -> secrets.run(rest)
    Help -> {
      print_help()
      Ok(Nil)
    }
    Unknown(name) -> {
      io.println_error("error: unknown subcommand: " <> name)
      print_help()
      Error(Nil)
    }
  }
  |> exit_with
}

fn print_help() -> Nil {
  [
    "sys-scripts — workspace automation (pure Gleam)",
    "",
    "USAGE:",
    "  gleam run -m sys_scripts -- <command> [args...]",
    "",
    "COMMANDS:",
    "  doctor     Print environment diagnostics (tool versions, PATH, etc.)",
    "  fmt        Format all source trees (gleam, rust, ts)",
    "  test       Run all test suites",
    "  deploy     Workspace deployment commands (nixos, k8s)",
    "  check      Run every validation (fmt, lint, test, flake check)",
    "  inventory  Read-only view of nix-configs/inventory.nix",
    "  secrets    Manage sops-encrypted secrets under secrets/",
    "  help       Show this help",
    "",
    "All commands are Gleam modules under scripts/src/sys_scripts/commands/.",
  ]
  |> string.join("\n")
  |> io.println
}

fn exit_with(result: Result(Nil, Nil)) -> Nil {
  case result {
    Ok(Nil) -> Nil
    Error(Nil) -> halt(1)
  }
}

// Call erlang:halt/1 directly so the process exits with a non-zero code.
@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil
