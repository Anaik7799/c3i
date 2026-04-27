//// `deploy` — workspace deployment commands.
////
//// This is a *stub* with the full parsing + dispatch wiring in place but
//// no actual deployment logic yet. The intent is that adding a real
//// target (NixOS host, k8s manifest, container image, etc.) means adding
//// a new `Target` variant and a pure `plan/1` / effectful `apply/2` pair.
////
//// Design rules:
////   * parsing is pure, lives in `parse/1`, returns `Result(Plan, ParseError)`
////   * `--dry-run` defaults to TRUE. Pass `--execute` to actually run.
////   * side-effects only in `run/1`.

import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import shellout
import sys_scripts/workspace

/// What we're deploying. Extend this as real targets come online.
pub type Target {
  /// `deploy nixos <host>` — rebuild a NixOS host (future: via SSH).
  Nixos(host: String)
  /// `deploy k8s <namespace>` — apply kubernetes manifests to a namespace.
  K8s(namespace: String)
}

/// Which phase of deployment to run.
pub type Phase {
  /// Print what would change.
  Plan
  /// Actually perform the change (requires `--execute`).
  Apply
  /// Undo the last successful apply.
  Rollback
}

pub type DeployPlan {
  DeployPlan(target: Target, phase: Phase, dry_run: Bool)
}

pub type ParseError {
  MissingSubcommand
  UnknownSubcommand(String)
  MissingTarget(String)
  UnknownTarget(String)
  MissingArgument(target: String, name: String)
  UnknownFlag(String)
}

// ---------------------------------------------------------------------------
// Entry point wired from sys_scripts.main
// ---------------------------------------------------------------------------

pub fn run(args: List(String)) -> Result(Nil, Nil) {
  case parse(args) {
    Ok(plan) -> execute(plan)
    Error(err) -> {
      io.println_error("deploy: " <> format_error(err))
      io.println_error("")
      io.println_error(usage())
      Error(Nil)
    }
  }
}

fn execute(plan: DeployPlan) -> Result(Nil, Nil) {
  let header = case plan.dry_run {
    True -> "[dry-run]"
    False -> "[EXECUTE]"
  }
  io.println(header <> " " <> describe(plan))
  case plan.phase, plan.target, plan.dry_run {
    // --- plan: real backend for NixOS hosts ---
    Plan, Nixos(host), _ -> plan_nixos(host)

    // --- plan: stub for other targets ---
    Plan, K8s(_), _ -> {
      io.println(
        "  k8s plan backend not yet implemented (Phase 3 — see docs/nixos-k8s-plan.md)",
      )
      Ok(Nil)
    }

    // --- apply nixos: real ssh backend (dry-run by default) ---
    Apply, Nixos(host), dry_run -> apply_nixos(host, dry_run)

    // --- apply k8s: still stubbed ---
    Apply, K8s(_), _ -> {
      io.println("  k8s apply not yet implemented")
      Ok(Nil)
    }

    // --- rollback: not yet wired for any target ---
    Rollback, _, _ -> {
      io.println(
        "  rollback not yet implemented (use `nixos-rebuild --rollback` on the target for now)",
      )
      Ok(Nil)
    }
  }
}

/// `deploy plan nixos <host>` — evaluate the flake's nixosConfiguration
/// and print a summary of what's in it. Never builds store paths;
/// purely evaluation-time.
///
/// Implementation note: we do a single `nix eval --json --expr` that
/// projects the flake's nixosConfiguration down to just the fields we
/// need. Multiple `nix eval` invocations work but (a) re-emit the
/// `Git tree '...' is dirty` warning for each call and (b) are 5×
/// slower on a cold cache. One call, one warning, one JSON blob.
fn plan_nixos(host: String) -> Result(Nil, Nil) {
  use repo <- resolve_repo()

  io.println("  evaluating flake attribute: .#nixosConfigurations." <> host)

  let expr =
    "let f = builtins.getFlake (toString "
    <> repo
    <> "); "
    <> "c = f.nixosConfigurations."
    <> host
    <> ".config; "
    <> "p = f.nixosConfigurations."
    <> host
    <> ".pkgs; in {"
    <> "hostName = c.networking.hostName;"
    <> "system = p.system;"
    <> "stateVersion = c.system.stateVersion;"
    <> "k3sRole = c.services.k3s.role;"
    <> "tcpPorts = c.networking.firewall.allowedTCPPorts;"
    <> "udpPorts = c.networking.firewall.allowedUDPPorts;"
    <> "}"

  case nix_eval_expr(repo, expr) {
    Error(_) -> {
      io.println_error("  failed to evaluate host: " <> host)
      io.println_error("  (hint: run `nix flake show` to list available hosts)")
      io.println_error(
        "  for full diagnostics, re-run manually: nix eval --impure --json --expr '<expr>'",
      )
      Error(Nil)
    }
    Ok(json) -> {
      // Indent each line of the pretty-printed JSON for readability.
      json
      |> string.trim
      |> string.split("\n")
      |> list.each(fn(line) { io.println("  " <> line) })
      io.println(
        "  (plan complete — no closure was built; add --execute + an SSH target to deploy)",
      )
      Ok(Nil)
    }
  }
}

/// Evaluate an inline Nix expression against the repo and return the
/// JSON result. Stderr is sent to /dev/null — the only things `nix eval`
/// ever emits there in normal operation are the "Git tree is dirty"
/// warning and a trace of fetched inputs, neither of which belongs in
/// our summary. If the call fails, shellout surfaces the non-zero exit
/// and we print a generic hint pointing the user at raw `nix eval` for
/// diagnostics.
fn nix_eval_expr(cwd: String, expr: String) -> Result(String, String) {
  case
    shellout.command(
      run: "bash",
      with: [
        "-c",
        // pipefail makes the pipeline's exit reflect nix's exit rather
        // than jq's (jq on empty input succeeds with empty output, which
        // would mask a nix evaluation failure).
        "set -o pipefail; nix eval --no-write-lock-file --impure --json --expr '"
          <> expr
          <> "' 2>/dev/null | jq --indent 2",
      ],
      in: cwd,
      opt: [],
    )
  {
    Ok(out) -> Ok(out)
    Error(#(_code, _err)) -> Error("nix evaluation failed")
  }
}

/// `use`-style helper: resolves the workspace root or short-circuits
/// with a human-readable error. Intended for callers inside `plan_*`
/// functions that return `Result(Nil, Nil)`.
fn resolve_repo(
  continuation: fn(String) -> Result(Nil, Nil),
) -> Result(Nil, Nil) {
  case workspace.repo_root() {
    Ok(path) -> continuation(path)
    Error(err) -> {
      io.println_error(
        "  could not locate workspace root: " <> workspace.format_error(err),
      )
      Error(Nil)
    }
  }
}

/// `deploy apply nixos <host>` — push the host's NixOS configuration
/// to the target via `nixos-rebuild switch --flake ...#<host>
/// --target-host <user@addr>`. Unless `--execute` is passed, this
/// runs the tool with `--dry-run` so you see the diff without
/// activating.
///
/// Preconditions validated before shelling out:
///   * The host exists in the flake (via workspace-level plan).
///   * sys.deploy.targetHost is set to a non-null value.
///
/// Secrets: assumes SSH + sudo is already configured on the target.
/// `nixos-rebuild --use-remote-sudo` forwards sudo prompts; key-only
/// SSH keeps this compatible with CI keys.
fn apply_nixos(host: String, dry_run: Bool) -> Result(Nil, Nil) {
  use repo <- resolve_repo()

  io.println("  target host   : " <> host)
  io.println("  flake attr    : .#nixosConfigurations." <> host)

  case read_target_host(repo, host) {
    Error(msg) -> {
      io.println_error("  " <> msg)
      Error(Nil)
    }
    Ok(target) -> {
      io.println("  ssh target    : " <> target)
      let mode = case dry_run {
        True -> "dry-run"
        False -> "switch"
      }
      io.println("  mode          : " <> mode)
      run_nixos_rebuild(repo, host, target, dry_run)
    }
  }
}

/// Read sys.deploy.targetHost out of the host's nixosConfiguration.
/// Returns a human-readable error if the attribute is missing or null.
fn read_target_host(repo: String, host: String) -> Result(String, String) {
  let attr = "nixosConfigurations." <> host <> ".config.sys.deploy.targetHost"
  case nix_eval_json(repo, attr) {
    Error(_) ->
      Error(
        "host "
        <> host
        <> " does not expose sys.deploy.targetHost — make sure the deploy module is imported",
      )
    Ok(json) -> {
      let trimmed = string.trim(json)
      case trimmed {
        "null" ->
          Error(
            "host "
            <> host
            <> " has sys.deploy.targetHost = null; set it (e.g. \"root@10.0.0.10\") before applying",
          )
        quoted -> Ok(strip_json_quotes(quoted))
      }
    }
  }
}

fn strip_json_quotes(s: String) -> String {
  case string.starts_with(s, "\"") && string.ends_with(s, "\"") {
    True -> string.slice(s, 1, string.length(s) - 2)
    False -> s
  }
}

fn nix_eval_json(cwd: String, attr: String) -> Result(String, String) {
  case
    shellout.command(
      run: "bash",
      with: [
        "-c",
        "set -o pipefail; nix eval --no-write-lock-file --json .#"
          <> attr
          <> " 2>/dev/null",
      ],
      in: cwd,
      opt: [],
    )
  {
    Ok(out) -> Ok(out)
    Error(#(_, _)) -> Error("nix eval failed")
  }
}

fn run_nixos_rebuild(
  repo: String,
  host: String,
  target: String,
  dry_run: Bool,
) -> Result(Nil, Nil) {
  let action = case dry_run {
    True -> "dry-run"
    False -> "switch"
  }
  let args = [
    action,
    "--flake",
    repo <> "#" <> host,
    "--target-host",
    target,
    "--use-remote-sudo",
  ]
  io.println("  → nixos-rebuild " <> string.join(args, " "))
  case shellout.command(run: "nixos-rebuild", with: args, in: repo, opt: []) {
    Ok(out) -> {
      io.println(out)
      Ok(Nil)
    }
    Error(#(code, err)) -> {
      io.println_error(
        "  nixos-rebuild exited "
        <> int.to_string(code)
        <> ": "
        <> string.trim(err),
      )
      Error(Nil)
    }
  }
}

// ---------------------------------------------------------------------------
// Pure parser — 100% unit-testable
// ---------------------------------------------------------------------------

pub fn parse(args: List(String)) -> Result(DeployPlan, ParseError) {
  case args {
    [] -> Error(MissingSubcommand)
    [phase_str, ..rest] -> {
      use phase <- result.try(parse_phase(phase_str))
      use #(target, flags) <- result.try(parse_target(rest))
      use dry_run <- result.try(parse_flags(flags))
      Ok(DeployPlan(target:, phase:, dry_run:))
    }
  }
}

fn parse_phase(s: String) -> Result(Phase, ParseError) {
  case s {
    "plan" -> Ok(Plan)
    "apply" -> Ok(Apply)
    "rollback" -> Ok(Rollback)
    other -> Error(UnknownSubcommand(other))
  }
}

fn parse_target(
  args: List(String),
) -> Result(#(Target, List(String)), ParseError) {
  case args {
    [] -> Error(MissingTarget("deploy"))
    ["nixos", host, ..rest] -> Ok(#(Nixos(host), rest))
    ["nixos"] -> Error(MissingArgument("nixos", "<host>"))
    ["k8s", ns, ..rest] -> Ok(#(K8s(ns), rest))
    ["k8s"] -> Error(MissingArgument("k8s", "<namespace>"))
    [other, ..] -> Error(UnknownTarget(other))
  }
}

/// Parses remaining flags. The only supported flag today is `--execute`
/// (turns off dry-run). Unknown flags are rejected.
fn parse_flags(flags: List(String)) -> Result(Bool, ParseError) {
  flags
  // Fold left-to-right; each recognised flag overwrites the running value
  // (last-write-wins). Unknown flags abort parsing.
  |> list.try_fold(True, fn(_acc, flag) {
    case flag {
      "--execute" -> Ok(False)
      "--dry-run" -> Ok(True)
      other -> Error(UnknownFlag(other))
    }
  })
}

// ---------------------------------------------------------------------------
// Rendering helpers
// ---------------------------------------------------------------------------

pub fn describe(plan: DeployPlan) -> String {
  let phase = case plan.phase {
    Plan -> "plan"
    Apply -> "apply"
    Rollback -> "rollback"
  }
  let target = case plan.target {
    Nixos(host) -> "nixos:" <> host
    K8s(ns) -> "k8s:" <> ns
  }
  phase <> " " <> target
}

pub fn format_error(err: ParseError) -> String {
  case err {
    MissingSubcommand -> "no subcommand given (expected plan|apply|rollback)"
    UnknownSubcommand(s) ->
      "unknown subcommand: " <> s <> " (expected plan|apply|rollback)"
    MissingTarget(cmd) ->
      "subcommand `" <> cmd <> "` requires a target (nixos|k8s)"
    UnknownTarget(t) -> "unknown target: " <> t <> " (expected nixos|k8s)"
    MissingArgument(target, arg) ->
      "target `" <> target <> "` requires argument " <> arg
    UnknownFlag(f) -> "unknown flag: " <> f
  }
}

pub fn usage() -> String {
  [
    "deploy — workspace deployment commands",
    "",
    "USAGE:",
    "  gleam run -m sys_scripts -- deploy <phase> <target> [flags]",
    "",
    "PHASES:",
    "  plan         Preview changes without touching anything",
    "  apply        Apply changes (requires --execute)",
    "  rollback     Revert the last apply (requires --execute)",
    "",
    "TARGETS:",
    "  nixos <host>       A NixOS host (rebuilt via SSH; not yet implemented)",
    "  k8s <namespace>    A kubernetes namespace (kubectl apply; not yet implemented)",
    "",
    "FLAGS:",
    "  --dry-run   (default) Print plan without executing",
    "  --execute   Actually perform changes (only meaningful for apply/rollback)",
    "",
    "EXAMPLES:",
    "  gleam run -m sys_scripts -- deploy plan nixos nas1",
    "  gleam run -m sys_scripts -- deploy apply k8s prod --execute",
  ]
  |> string.join("\n")
}
