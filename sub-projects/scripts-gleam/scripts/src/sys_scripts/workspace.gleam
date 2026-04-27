//// Resolve the workspace repo root. Used by every command that needs
//// an absolute path (nix eval, cargo invocation, discovery of
//// subprojects). Two strategies, tried in order:
////
////   1. `git rev-parse --show-toplevel` — works anywhere inside the
////      git worktree.
////   2. Walk the current working directory upward looking for a
////      `flake.nix` sibling. Covers detached checkouts and CI
////      scenarios where `.git` may be missing.
////
//// Never hardcode `/mnt/c/dev/elixir/sys` anywhere else — use this.

import filepath
import gleam/result
import gleam/string
import shellout
import simplifile

pub type ResolutionError {
  NotInGitRepo
  NoFlakeMarker(searched_from: String)
}

/// Public entry point. Always returns an absolute path, or an error
/// explaining why it couldn't be resolved.
pub fn repo_root() -> Result(String, ResolutionError) {
  use _ <- result.try_recover(via_git())
  via_walk_up()
}

fn via_git() -> Result(String, ResolutionError) {
  case
    shellout.command(
      run: "git",
      with: ["rev-parse", "--show-toplevel"],
      in: ".",
      opt: [],
    )
  {
    Ok(out) -> Ok(string.trim(out))
    Error(_) -> Error(NotInGitRepo)
  }
}

fn via_walk_up() -> Result(String, ResolutionError) {
  let start = case simplifile.current_directory() {
    Ok(d) -> d
    Error(_) -> "."
  }
  case walk(start) {
    Ok(found) -> Ok(found)
    Error(Nil) -> Error(NoFlakeMarker(searched_from: start))
  }
}

fn walk(dir: String) -> Result(String, Nil) {
  let marker = filepath.join(dir, "flake.nix")
  case simplifile.is_file(marker) {
    Ok(True) -> Ok(dir)
    _ -> {
      let parent = filepath.directory_name(dir)
      case parent == dir || parent == "" {
        True -> Error(Nil)
        False -> walk(parent)
      }
    }
  }
}

pub fn format_error(err: ResolutionError) -> String {
  case err {
    NotInGitRepo -> "not inside a git working tree"
    NoFlakeMarker(searched_from:) ->
      "no flake.nix found walking up from " <> searched_from
  }
}
