//// `inventory` — read-only view of nix-configs/inventory.nix.
////
//// Implementation is a thin wrapper over `nix eval --json`: Nix is
//// the source of truth for addresses; the CLI just formats and
//// filters. Per plans/design.md P2.W2, inventory is a Nix attrset
//// (not YAML) so it composes naturally with the rest of the flake.

import gleam/io
import gleam/string
import shellout
import sys_scripts/workspace

pub type Action {
  List
  Show(name: String)
  Ping
}

pub fn run(args: List(String)) -> Result(Nil, Nil) {
  case parse(args) {
    Ok(action) -> execute(action)
    Error(Nil) -> {
      io.println_error(usage())
      Error(Nil)
    }
  }
}

pub fn parse(args: List(String)) -> Result(Action, Nil) {
  case args {
    [] | ["list"] -> Ok(List)
    ["show", name] -> Ok(Show(name))
    ["ping"] -> Ok(Ping)
    _ -> Error(Nil)
  }
}

fn execute(action: Action) -> Result(Nil, Nil) {
  use repo <- resolve_repo()
  case action {
    List -> list_hosts(repo)
    Show(name) -> show_host(repo, name)
    Ping -> ping_all(repo)
  }
}

fn list_hosts(repo: String) -> Result(Nil, Nil) {
  io.println("reading inventory from flake...")
  case read_inventory(repo) {
    Error(err) -> {
      io.println_error("  " <> err)
      Error(Nil)
    }
    Ok(json) -> {
      // Just print raw JSON for now; pretty table formatting is a
      // polish pass after we have real data.
      io.println(json)
      Ok(Nil)
    }
  }
}

fn show_host(repo: String, name: String) -> Result(Nil, Nil) {
  io.println("showing " <> name <> "...")
  case read_host(repo, name) {
    Error(err) -> {
      io.println_error("  " <> err)
      Error(Nil)
    }
    Ok(json) -> {
      io.println(json)
      Ok(Nil)
    }
  }
}

fn ping_all(repo: String) -> Result(Nil, Nil) {
  io.println("pinging every host with a tailscaleAddr...")
  case read_inventory(repo) {
    Error(err) -> {
      io.println_error("  " <> err)
      Error(Nil)
    }
    Ok(_json) -> {
      // Parse JSON to extract hosts with non-null tailscaleAddr,
      // then `tailscale ping <addr>`. For now: stub until P2 lands
      // and we have real tailscale addresses to test against.
      io.println("  (ping stub — implement when hosts have tailscaleAddr)")
      Ok(Nil)
    }
  }
}

fn read_inventory(repo: String) -> Result(String, String) {
  case
    shellout.command(
      run: "bash",
      with: [
        "-c",
        "set -o pipefail; nix eval --no-write-lock-file --json .#lib.inventory 2>/dev/null | jq --indent 2",
      ],
      in: repo,
      opt: [],
    )
  {
    Ok(out) -> Ok(out)
    Error(#(_, _)) -> Error("nix eval failed (is inventory.nix valid?)")
  }
}

fn read_host(repo: String, name: String) -> Result(String, String) {
  case
    shellout.command(
      run: "bash",
      with: [
        "-c",
        "set -o pipefail; nix eval --no-write-lock-file --json .#lib.inventory.hosts."
          <> name
          <> " 2>/dev/null | jq --indent 2",
      ],
      in: repo,
      opt: [],
    )
  {
    Ok(out) -> Ok(out)
    Error(#(_, _)) -> Error("host not found in inventory: " <> name)
  }
}

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

pub fn usage() -> String {
  [
    "inventory — read-only view of nix-configs/inventory.nix",
    "",
    "USAGE:",
    "  gleam run -m sys_scripts -- inventory <action>",
    "",
    "ACTIONS:",
    "  list        Print the full inventory (JSON)",
    "  show <name> Print a single host's entry (JSON)",
    "  ping        Ping every host's tailscaleAddr (if set)",
  ]
  |> string.join("\n")
}
