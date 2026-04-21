//// scripts/tools/build_nif — rebuild the scripts_nif Rust NIF.
////
//// SC-SCRIPT-GLEAM-001. Runs `cargo build --release` via the port-spawn FFI
//// (no shell), copies the produced shared library into `priv/scripts_nif.so`,
//// and writes a build report under
//// `data/script-output/tools/build_nif/<stamp>/result.json`.
////
//// Usage:
////   cd sub-projects/scripts-gleam
////   gleam run -m scripts/tools/build_nif
////
//// Hard path invariants: every path resolved by this script lies under
//// `/home/an/dev/ver/c3i/`.

import gleam/erlang/charlist
import gleam/int
import gleam/list
import gleam/string
import scripts/common/fsx
import scripts/common/logx
import scripts/common/paths

const scope = "tools/build_nif"

// ── Minimal port-spawn helper (reuses scripts_sh_ffi) ────────────────────────

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

// ── Paths ────────────────────────────────────────────────────────────────────

fn crate_dir() -> String {
  paths.repo_root() <> "/sub-projects/scripts-gleam/native/scripts_nif"
}

fn crate_target_so() -> String {
  crate_dir() <> "/target/release/libscripts_nif.so"
}

fn priv_so() -> String {
  paths.repo_root() <> "/sub-projects/scripts-gleam/priv/scripts_nif.so"
}

// ── Build + install ──────────────────────────────────────────────────────────

pub fn main() -> Nil {
  let stamp = logx.stamp()
  logx.info(scope, "start stamp=" <> stamp)
  logx.info(scope, "crate_dir=" <> crate_dir())

  // `cargo` is a project tool allowed as a thin binary invocation.
  let cargo_args = [
    "build",
    "--release",
    "--manifest-path",
    crate_dir() <> "/Cargo.toml",
  ]
  logx.info(scope, "cargo " <> string.join(cargo_args, " "))
  let #(stdout, rc) = run("cargo", cargo_args)

  let built_ok = rc == 0
  case built_ok {
    False -> logx.error(scope, "cargo rc=" <> int.to_string(rc))
    True -> logx.info(scope, "cargo ok")
  }

  // Install: copy libscripts_nif.so → priv/scripts_nif.so using `install`
  // (a plain POSIX binary, NOT a shell script).
  let install_args = ["-m", "0755", crate_target_so(), priv_so()]
  let #(install_out, install_rc) = run("install", install_args)
  let installed_ok = install_rc == 0
  case installed_ok {
    True -> logx.info(scope, "installed " <> priv_so())
    False -> logx.error(scope, "install rc=" <> int.to_string(install_rc))
  }

  // Persist build report.
  case fsx.run_dir("tools", "build_nif", stamp) {
    Error(e) -> logx.error(scope, "run_dir: " <> e)
    Ok(dir) -> {
      let log =
        "== cargo (rc=" <> int.to_string(rc) <> ") ==\n" <> stdout
        <> "\n== install (rc=" <> int.to_string(install_rc) <> ") ==\n" <> install_out
      let _ = fsx.write_file(dir, "stdout.log", log)
      let json =
        "{\"script\":\"" <> scope <> "\""
        <> ",\"stamp\":\"" <> stamp <> "\""
        <> ",\"cargo_rc\":" <> int.to_string(rc)
        <> ",\"install_rc\":" <> int.to_string(install_rc)
        <> ",\"priv_so\":\"" <> priv_so() <> "\""
        <> ",\"ok\":" <> case built_ok && installed_ok { True -> "true" False -> "false" }
        <> "}"
      let _ = fsx.write_file(dir, "result.json", json)
      logx.info(scope, "outputs " <> paths.join(dir, "result.json"))
    }
  }

  case built_ok && installed_ok {
    True -> Nil
    False -> panic as "build_nif failed (see result.json)"
  }
}
