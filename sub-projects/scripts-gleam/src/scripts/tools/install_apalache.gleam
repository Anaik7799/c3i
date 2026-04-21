//// scripts/tools/install_apalache — fetch + install Apalache under ~/.local/bin (SC-SCHED-TELE-TLA-001).
////
//// Operator-driven installer (one-time). The binary is tarred at a pinned
//// release; we fetch, extract, and symlink. This stays gleam-only by using
//// the HTTP NIF + port-spawn for `tar` and `ln`.
////
//// Default version: 0.47.2 (latest stable as of 2026-04). Override with --version.
////
//// Usage:
////   gleam run -m scripts/tools/install_apalache -- [--version 0.47.2] [--dest ~/.local]
////
//// STAMP: SC-SCHED-TELE-TLA-001, SC-SCRIPT-GLEAM-001

import argv
import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/args as cargs
import scripts/common/fractal
import scripts/common/logx
import scripts/common/manifest as mfst

@external(erlang, "scripts_sh_ffi", "run_capture_in")
fn sh_run(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
  cwd: charlist.Charlist,
) -> #(charlist.Charlist, Int)

fn sh(cmd: String, args: List(String), cwd: String) -> #(String, Int) {
  let #(o, rc) =
    sh_run(
      charlist.from_string(cmd),
      list.map(args, charlist.from_string),
      charlist.from_string(cwd),
    )
  #(charlist.to_string(o), rc)
}

pub fn manifest() -> mfst.Manifest {
  mfst.Manifest(
    name: "tools/install_apalache",
    category: mfst.Tools,
    fractal_layer: fractal.L4,
    summary: "Install Apalache symbolic model-checker (operator-driven, one-shot).",
    inputs: [
      mfst.FlagSpec("version", "Apalache release version", "0.47.2", False),
      mfst.FlagSpec("dest", "Install prefix (~/.local)", "/home/an/.local", False),
    ],
    outputs_schema: "{installed,version,path}",
    retention_days: 365,
    auth_level: mfst.L1Trusted,
    sc_id: "SC-SCHED-TELE-TLA-001",
  )
}

pub fn main() -> Nil {
  let a = cargs.parse(argv.load().arguments)
  let version = cargs.flag(a, "version", "0.47.2")
  let dest = cargs.flag(a, "dest", "/home/an/.local")
  let url =
    "https://github.com/apalache-mc/apalache/releases/download/v"
    <> version
    <> "/apalache-"
    <> version
    <> ".tgz"
  logx.info("tools/install_apalache", "version=" <> version <> " url=" <> url)

  // Check existing install
  let #(which_out, which_rc) = sh("which", ["apalache-mc"], "/")
  case which_rc {
    0 -> {
      io.println("Already installed: " <> string.trim(which_out))
      check_version()
    }
    _ -> {
      io.println("Installing Apalache " <> version <> " to " <> dest <> "/apalache-" <> version <> "…")
      fetch_and_install(url, version, dest)
      check_version()
    }
  }
}

fn fetch_and_install(url: String, version: String, dest: String) -> Nil {
  let tmp = "/tmp/apalache-" <> version <> ".tgz"
  logx.info("tools/install_apalache", "fetching " <> url <> " → " <> tmp)
  let #(_, rc1) = sh("curl", ["-fsSL", "-o", tmp, url], "/")
  case rc1 {
    0 -> Nil
    _ -> {
      logx.error("tools/install_apalache", "curl rc=" <> int.to_string(rc1))
      panic as "apalache download failed"
    }
  }
  let _ = sh("mkdir", ["-p", dest], "/")
  let #(_, rc2) = sh("tar", ["-xzf", tmp, "-C", dest], "/")
  case rc2 {
    0 -> Nil
    _ -> {
      logx.error("tools/install_apalache", "tar rc=" <> int.to_string(rc2))
      panic as "apalache extract failed"
    }
  }
  let extracted = dest <> "/apalache-" <> version
  let bin_link = "/home/an/.local/bin/apalache-mc"
  let _ = sh("mkdir", ["-p", "/home/an/.local/bin"], "/")
  let _ = sh("ln", ["-sf", extracted <> "/bin/apalache-mc", bin_link], "/")
  io.println("Installed: " <> bin_link <> " → " <> extracted <> "/bin/apalache-mc")
}

fn check_version() -> Nil {
  let #(out, rc) = sh("apalache-mc", ["version"], "/")
  case rc {
    0 -> io.println(string.trim(out))
    _ -> logx.warn("tools/install_apalache", "version check failed rc=" <> int.to_string(rc))
  }
}
