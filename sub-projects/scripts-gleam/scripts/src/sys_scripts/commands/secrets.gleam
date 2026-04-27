//// `secrets` — manage sops-encrypted secrets under secrets/.
////
//// Wraps the `sops` CLI (nixpkgs#sops) to list/validate/edit encrypted
//// yaml files. Age keys are expected at ~/.config/sops/age/keys.txt
//// (workstation) or derived from the host's ssh host key (on targets).
////
//// See plans/implementation.md P3.W4 for usage.

import gleam/io
import gleam/list
import gleam/result
import gleam/string
import shellout
import simplifile
import sys_scripts/workspace

pub type Action {
  List
  Validate
  Edit(path: String)
  GetKubeconfig
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
    ["list"] -> Ok(List)
    ["validate"] -> Ok(Validate)
    ["edit", path] -> Ok(Edit(path))
    ["get", "kubeconfig"] -> Ok(GetKubeconfig)
    _ -> Error(Nil)
  }
}

fn execute(action: Action) -> Result(Nil, Nil) {
  use repo <- resolve_repo()
  case action {
    List -> list_files(repo)
    Validate -> validate_all(repo)
    Edit(path) -> edit_file(repo, path)
    GetKubeconfig -> get_kubeconfig(repo)
  }
}

fn list_files(repo: String) -> Result(Nil, Nil) {
  let secrets_dir = repo <> "/secrets"
  case simplifile.read_directory(secrets_dir) {
    Error(_) -> {
      io.println_error("  secrets/ does not exist (P3 not started)")
      Error(Nil)
    }
    Ok(entries) -> {
      entries
      |> list.filter(fn(e) { string.ends_with(e, ".yaml") })
      |> list.sort(string.compare)
      |> list.each(fn(e) { io.println("  " <> e) })
      Ok(Nil)
    }
  }
}

fn validate_all(repo: String) -> Result(Nil, Nil) {
  let secrets_dir = repo <> "/secrets"
  case simplifile.read_directory(secrets_dir) {
    Error(_) -> {
      io.println_error("  secrets/ does not exist")
      Error(Nil)
    }
    Ok(entries) -> {
      let yamls =
        entries
        |> list.filter(fn(e) { string.ends_with(e, ".yaml") })
        |> list.sort(string.compare)
      let results = list.map(yamls, fn(f) { #(f, validate_one(repo, f)) })
      let failures = list.filter(results, fn(r) { result.is_error(r.1) })
      case failures {
        [] -> {
          io.println(
            "  all " <> string.inspect(list.length(yamls)) <> " secrets valid",
          )
          Ok(Nil)
        }
        _ -> {
          io.println_error(
            "  " <> string.inspect(list.length(failures)) <> " failures:",
          )
          list.each(failures, fn(pair) {
            let #(name, _) = pair
            io.println_error("    ✗ " <> name)
          })
          Error(Nil)
        }
      }
    }
  }
}

fn validate_one(repo: String, filename: String) -> Result(Nil, Nil) {
  let path = repo <> "/secrets/" <> filename
  case
    shellout.command(
      run: "bash",
      with: ["-c", "sops -d '" <> path <> "' >/dev/null 2>&1"],
      in: repo,
      opt: [],
    )
  {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(Nil)
  }
}

fn edit_file(repo: String, rel_path: String) -> Result(Nil, Nil) {
  let path = repo <> "/secrets/" <> rel_path
  io.println("  editing " <> path)
  case shellout.command(run: "sops", with: [path], in: repo, opt: []) {
    Ok(_) -> Ok(Nil)
    Error(#(code, err)) -> {
      io.println_error("  sops exited " <> string.inspect(code))
      io.println_error("  " <> string.trim(err))
      Error(Nil)
    }
  }
}

fn get_kubeconfig(repo: String) -> Result(Nil, Nil) {
  io.println("  fetching kubeconfig from nix-k8s-master...")
  case
    shellout.command(
      run: "bash",
      with: [
        "-c",
        "ssh nix-k8s-master sudo cat /etc/rancher/k3s/k3s.yaml 2>/dev/null | sed 's|https://127.0.0.1:6443|https://TAILSCALE_ADDR_PLACEHOLDER:6443|'",
      ],
      in: repo,
      opt: [],
    )
  {
    Ok(out) -> {
      io.println(
        "# Replace TAILSCALE_ADDR_PLACEHOLDER with the master's real tailscale IP before use.",
      )
      io.println(out)
      Ok(Nil)
    }
    Error(#(code, err)) -> {
      io.println_error("  ssh/cat failed, exit " <> string.inspect(code))
      io.println_error("  " <> string.trim(err))
      Error(Nil)
    }
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
    "secrets — manage sops-encrypted secrets under secrets/",
    "",
    "USAGE:",
    "  gleam run -m sys_scripts -- secrets <action>",
    "",
    "ACTIONS:",
    "  list            List every *.yaml file in secrets/",
    "  validate        Decrypt every secrets/*.yaml (asserts no corruption)",
    "  edit <file>     Open <file> in sops editor (creates if absent)",
    "  get kubeconfig  Extract /etc/rancher/k3s/k3s.yaml from the master,",
    "                  rewrite server URL, print to stdout",
    "",
    "EXAMPLES:",
    "  gleam run -m sys_scripts -- secrets list",
    "  gleam run -m sys_scripts -- secrets validate",
    "  gleam run -m sys_scripts -- secrets edit cluster.yaml",
    "  gleam run -m sys_scripts -- secrets get kubeconfig > ~/.kube/configs/nas1.yaml",
  ]
  |> string.join("\n")
}
