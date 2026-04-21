//// scripts/tools/build_nif_cross — cross-compile the scripts_nif for Pi (arm64).
////
//// SC-SCRIPT-GLEAM-001. Attempts `cargo build --target <triple> --release`
//// using a linker from `.cargo/config.toml`. On success, installs the .so as
//// `priv/scripts_nif-<cpu>.so` so the loader in `src/scripts_nif.erl` picks
//// it up when the BEAM runs on a matching host.
////
//// Usage:
////   gleam run -m scripts/tools/build_nif_cross
////   gleam run -m scripts/tools/build_nif_cross -- --target aarch64-unknown-linux-musl
////
//// If the target toolchain is missing this script prints the exact install
//// commands (rustup, apt, nix, docker/cross) and exits non-zero.

import argv
import gleam/erlang/charlist
import gleam/int
import gleam/list
import gleam/string
import scripts/common/args as cargs
import scripts/common/fractal
import scripts/common/fsx
import scripts/common/logx
import scripts/common/manifest as mfst
import scripts/common/paths

const scope = "tools/build_nif_cross"

pub fn manifest() -> mfst.Manifest {
  mfst.Manifest(
    name: "tools/build_nif_cross",
    category: mfst.Tools,
    fractal_layer: fractal.L4,
    summary: "Cross-compile scripts_nif for arm64/musl targets; install per-arch .so.",
    inputs: [
      mfst.FlagSpec("target", "Rust target triple", "aarch64-unknown-linux-gnu", False),
    ],
    outputs_schema: "{script,stamp,target,cargo_rc,install_rc,priv_so,ok,hint}",
    retention_days: 14,
    auth_level: mfst.L2Normal,
    sc_id: "SC-SCRIPT-TOOL-003",
  )
}

@external(erlang, "scripts_sh_ffi", "run_capture")
fn sh_run_capture(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
) -> #(charlist.Charlist, Int)

fn to_cl(s: String) -> charlist.Charlist {
  charlist.from_string(s)
}

fn run(cmd: String, args: List(String)) -> #(String, Int) {
  let #(out, rc) = sh_run_capture(to_cl(cmd), list.map(args, to_cl))
  #(charlist.to_string(out), rc)
}

fn crate_dir() -> String {
  paths.repo_root() <> "/sub-projects/scripts-gleam/native/scripts_nif"
}

fn target_so(target: String) -> String {
  crate_dir() <> "/target/" <> target <> "/release/libscripts_nif.so"
}

fn priv_dir() -> String {
  paths.repo_root() <> "/sub-projects/scripts-gleam/priv"
}

fn cpu_of(target: String) -> String {
  case string.split_once(target, on: "-") {
    Ok(#(cpu, _)) -> cpu
    Error(_) -> target
  }
}

fn hint_for(target: String) -> String {
  "To install the " <> target <> " toolchain, run ONE of:\n"
  <> "  # rustup + apt\n"
  <> "  rustup target add " <> target <> "\n"
  <> "  sudo apt install gcc-" <> cpu_of(target) <> "-linux-gnu\n"
  <> "  # nix devenv\n"
  <> "  # add pkgs.pkgsCross.aarch64-multiplatform.stdenv.cc to devshell\n"
  <> "  # docker (no host changes)\n"
  <> "  cargo install cross && cross build --manifest-path "
  <> crate_dir() <> "/Cargo.toml --target " <> target <> " --release"
}

pub fn main() -> Nil {
  let a = cargs.parse(argv.load().arguments)
  let target = cargs.flag(a, "target", "aarch64-unknown-linux-gnu")
  let stamp = logx.stamp()
  logx.info(scope, "start stamp=" <> stamp <> " target=" <> target)

  let cargo_args = [
    "build",
    "--release",
    "--manifest-path",
    crate_dir() <> "/Cargo.toml",
    "--target",
    target,
  ]
  let #(cargo_out, cargo_rc) = run("cargo", cargo_args)
  let built_ok = cargo_rc == 0

  let install_out_pair = case built_ok {
    False -> #("", -1)
    True -> {
      let dst = priv_dir() <> "/scripts_nif-" <> cpu_of(target) <> ".so"
      let #(out, rc) = run("install", ["-m", "0755", target_so(target), dst])
      #(out, rc)
    }
  }
  let #(install_out, install_rc) = install_out_pair
  let installed_ok = install_rc == 0
  let priv_path = case built_ok && installed_ok {
    True -> priv_dir() <> "/scripts_nif-" <> cpu_of(target) <> ".so"
    False -> ""
  }
  let hint = case built_ok {
    True -> ""
    False -> hint_for(target)
  }

  case fsx.run_dir("tools", "build_nif_cross", stamp) {
    Error(e) -> logx.error(scope, "run_dir: " <> e)
    Ok(dir) -> {
      let log =
        "== cargo (rc=" <> int.to_string(cargo_rc) <> ") ==\n" <> cargo_out
        <> "\n== install (rc=" <> int.to_string(install_rc) <> ") ==\n" <> install_out
        <> "\n== hint ==\n" <> hint
      let _ = fsx.write_file(dir, "stdout.log", log)
      let json =
        "{\"script\":\"" <> scope <> "\""
        <> ",\"stamp\":\"" <> stamp <> "\""
        <> ",\"target\":\"" <> target <> "\""
        <> ",\"cargo_rc\":" <> int.to_string(cargo_rc)
        <> ",\"install_rc\":" <> int.to_string(install_rc)
        <> ",\"priv_so\":\"" <> priv_path <> "\""
        <> ",\"ok\":" <> case built_ok && installed_ok { True -> "true" False -> "false" }
        <> ",\"hint\":\"" <> string.replace(hint, each: "\"", with: "'") <> "\""
        <> "}"
      let _ = fsx.write_file(dir, "result.json", json)
      logx.info(scope, "outputs " <> paths.join(dir, "result.json"))
    }
  }

  case built_ok, installed_ok {
    True, True ->
      logx.info(scope, "INSTALLED " <> priv_path)
    False, _ -> {
      logx.error(scope, "cargo rc=" <> int.to_string(cargo_rc) <> " — toolchain missing?")
      logx.info(scope, hint)
    }
    True, False ->
      logx.error(scope, "install rc=" <> int.to_string(install_rc))
  }
}
