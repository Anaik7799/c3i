//// scripts/verify/formal_check — SCHED-TELE-TLA-CI gate (SC-SCHED-TELE-TLA-001).
////
//// Runs all available formal tools over the SchedTele specs:
////   - quint typecheck (required, fails hard if absent)
////   - quint run --invariant inv_all --max-steps N
////   - apalache-mc check (optional; SKIP if not installed)
////   - tlc -config ... (optional; SKIP if not installed)
////
//// Exits non-zero if any REQUIRED check fails. Records a summary on Zenoh
//// for the scheduler + Pi operator view.
////
//// Usage:
////   gleam run -m scripts/verify/formal_check -- [--max-steps 50]
////
//// Registered in `scripts/common/registry_index.gleam`.

import argv
import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/args as cargs
import scripts/common/fractal
import scripts/common/fsx
import scripts/common/logx
import scripts/common/manifest as mfst
import scripts/common/paths

/// FFI: the shared port-spawn helper already used by other scripts.
/// Accepts charlists and returns (charlist, rc).
@external(erlang, "scripts_sh_ffi", "run_capture_in")
fn sh_run_capture_raw(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
  cwd: charlist.Charlist,
) -> #(charlist.Charlist, Int)

fn sh_run_capture_in(
  cmd: String,
  args: List(String),
  cwd: String,
) -> #(String, Int) {
  let args_cl = list.map(args, charlist.from_string)
  let #(out_cl, rc) = sh_run_capture_raw(charlist.from_string(cmd), args_cl, charlist.from_string(cwd))
  #(charlist.to_string(out_cl), rc)
}

pub fn manifest() -> mfst.Manifest {
  mfst.Manifest(
    name: "verify/formal_check",
    category: mfst.Verify,
    fractal_layer: fractal.L5,
    summary: "Runs quint (required) + apalache-mc / tlc (optional) over specs/tla/SchedTele + specs/quint/sched_tele.",
    inputs: [
      mfst.FlagSpec("max-steps", "Quint randomized simulation step bound", "50", False),
      mfst.FlagSpec("apalache-length", "Apalache bounded-safety length", "5", False),
    ],
    outputs_schema: "{quint_typecheck,quint_run,apalache,tlc,all_pass}",
    retention_days: 30,
    auth_level: mfst.L1Trusted,
    sc_id: "SC-SCHED-TELE-TLA-001",
  )
}

pub fn main() -> Nil {
  let a = cargs.parse(argv.load().arguments)
  let max_steps = cargs.flag(a, "max-steps", "50")
  let repo_root = paths.repo_root()
  let stamp = logx.stamp()
  let _ = stamp

  io.println("══ SCHED-TELE formal check (SC-SCHED-TELE-TLA-001) ══")

  let qnt = repo_root <> "/specs/quint/sched_tele.qnt"
  let tla = repo_root <> "/specs/tla/SchedTele.tla"
  let cfg = repo_root <> "/specs/tla/SchedTele.cfg"           // Apalache (safety-only canonical)
  let tlc_cfg = repo_root <> "/specs/tla/SchedTele_Fair.cfg"  // TLC (fairness + tight bounds)

  // ── quint typecheck (REQUIRED) ────────────────────────────────────────
  let #(qt_out, qt_rc) = sh_run_capture_in("quint", ["typecheck", qnt], repo_root)
  logx.info("verify/formal_check", "quint typecheck rc=" <> int.to_string(qt_rc))
  case qt_rc {
    0 -> io.println("  ✓ quint typecheck: PASS")
    _ -> {
      io.println("  ✗ quint typecheck: FAIL rc=" <> int.to_string(qt_rc))
      io.println(qt_out)
    }
  }

  // ── quint run (REQUIRED) ──────────────────────────────────────────────
  let #(qr_out, qr_rc) =
    sh_run_capture_in(
      "quint",
      ["run", "--max-steps", max_steps, "--invariant", "inv_all", qnt],
      repo_root,
    )
  logx.info("verify/formal_check", "quint run rc=" <> int.to_string(qr_rc))
  let qr_pass = qr_rc == 0 && string.contains(qr_out, "[ok] No violation found")
  case qr_pass {
    True -> io.println("  ✓ quint run --invariant inv_all: 0 violations")
    False -> {
      io.println("  ✗ quint run: FAIL")
      io.println(last_n_lines(qr_out, 10))
    }
  }

  // ── apalache (OPTIONAL) ───────────────────────────────────────────────
  let apalache_bin = prefer_subproject_bin(
    repo_root,
    "sub-projects/apalache/bin/apalache-mc",
    "apalache-mc",
  )
  let apalache_present = apalache_bin != ""
  let #(ap_out, ap_rc, ap_present) = case apalache_present {
    False -> #("not installed", -1, False)
    True -> {
      let apalache_length = cargs.flag(a, "apalache-length", "5")
      let #(o, c) = sh_run_capture_in(
        apalache_bin,
        ["check", "--config=" <> cfg, "--length=" <> apalache_length, tla],
        repo_root,
      )
      #(o, c, True)
    }
  }
  case ap_present {
    False -> io.println("  · apalache-mc: SKIP (not installed)")
    True ->
      case ap_rc {
        0 -> io.println("  ✓ apalache-mc check: PASS")
        _ -> {
          io.println("  ✗ apalache-mc check: FAIL rc=" <> int.to_string(ap_rc))
          io.println(last_n_lines(ap_out, 10))
        }
      }
  }

  // ── TLC (OPTIONAL) ────────────────────────────────────────────────────
  let tlc_bin = prefer_subproject_bin(
    repo_root,
    "sub-projects/tlc/bin/tlc",
    "tlc",
  )
  let tlc_present = tlc_bin != ""
  let #(tlc_out, tlc_rc, tlc_pres) = case tlc_present {
    False -> #("not installed", -1, False)
    True -> {
      let #(o, c) = sh_run_capture_in(tlc_bin, ["-config", tlc_cfg, tla], repo_root)
      #(o, c, True)
    }
  }
  case tlc_pres {
    False -> io.println("  · tlc: SKIP (not installed)")
    True ->
      case tlc_rc {
        0 -> io.println("  ✓ tlc: PASS")
        _ -> {
          io.println("  ✗ tlc: FAIL rc=" <> int.to_string(tlc_rc))
          io.println(last_n_lines(tlc_out, 10))
        }
      }
  }

  // ── Summary + result.json ────────────────────────────────────────────
  let all_pass = qt_rc == 0 && qr_pass
    && case ap_present {
      True -> ap_rc == 0
      False -> True
    }
    && case tlc_pres {
      True -> tlc_rc == 0
      False -> True
    }
  io.println("")
  io.println(
    case all_pass {
      True -> "══ RESULT: PASS ══"
      False -> "══ RESULT: FAIL ══"
    }
  )
  let _ = write_result(
    qt_rc == 0, qr_pass, ap_present, ap_rc, tlc_pres, tlc_rc, all_pass,
  )
  case all_pass {
    True -> Nil
    False -> halt(1)
  }
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil

fn binary_exists(name: String) -> Bool {
  let #(_, rc) = sh_run_capture_in("which", [name], "/")
  rc == 0
}

/// Prefer the bundled launcher under sub-projects/<name>/bin if it exists;
/// fall back to a PATH-resolved `fallback`; else empty string.
///
/// We must use the absolute path to `/usr/bin/test` because the nix devenv
/// PATH shadows plain `test` with a custom mix-test wrapper.
fn prefer_subproject_bin(repo_root: String, rel: String, fallback: String) -> String {
  let bundled = repo_root <> "/" <> rel
  let #(_, rc) = sh_run_capture_in("/usr/bin/test", ["-x", bundled], "/")
  case rc {
    0 -> bundled
    _ ->
      case binary_exists(fallback) {
        True -> fallback
        False -> ""
      }
  }
}

fn last_n_lines(s: String, n: Int) -> String {
  s
  |> string.split("\n")
  |> list.reverse
  |> take(n)
  |> list.reverse
  |> string.join("\n")
}

fn take(xs: List(a), n: Int) -> List(a) {
  case n <= 0 {
    True -> []
    False ->
      case xs {
        [] -> []
        [h, ..t] -> [h, ..take(t, n - 1)]
      }
  }
}

fn write_result(
  qt: Bool, qr: Bool, ap_present: Bool, ap: Int, tlc_present: Bool, tlc: Int,
  all_pass: Bool,
) -> Result(Nil, String) {
  let stamp = logx.stamp()
  case fsx.run_dir("verify", "formal_check", stamp) {
    Error(e) -> Error(e)
    Ok(dir) -> {
      let body =
        "{\"stamp\":\""
        <> stamp
        <> "\",\"quint_typecheck\":"
        <> to_bool(qt)
        <> ",\"quint_run\":"
        <> to_bool(qr)
        <> ",\"apalache_present\":"
        <> to_bool(ap_present)
        <> ",\"apalache_rc\":"
        <> int.to_string(ap)
        <> ",\"tlc_present\":"
        <> to_bool(tlc_present)
        <> ",\"tlc_rc\":"
        <> int.to_string(tlc)
        <> ",\"all_pass\":"
        <> to_bool(all_pass)
        <> "}"
      fsx.write_file(dir, "result.json", body)
    }
  }
}

fn to_bool(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}
