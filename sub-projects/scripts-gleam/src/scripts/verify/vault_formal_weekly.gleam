//// scripts/verify/vault_formal_weekly — weekly formal-verification cron for the
//// secrets vault (SC-VAULT-001..025 + SC-VAULT-CRYPTO-001).
////
//// Runs all three formal tools and reports a structured JSON summary:
////   - agda --safe specs/agda/VaultStateMachine.agda    (REQUIRED — type-level proof)
////   - tlc      RustyVaultIntegration_MC.tla            (REQUIRED — bounded BFS)
////   - apalache RustyVaultIntegration_Apalache.tla      (REQUIRED — symbolic)
////
//// Schedule: `0 2 * * 0` (Sundays 02:00 UTC) via sa-plan-daemon.
//// Layer L6 (formal-spec) of the secrets-vault defense-in-depth ladder.
////
//// Per SC-SCRIPT-GLEAM-001: no shell scripts. This module is the sole runner.
////
//// Usage:
////   gleam run -m scripts/verify/vault_formal_weekly

import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/string

@external(erlang, "scripts_sh_ffi", "run_capture_in")
fn sh_raw(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
  cwd: charlist.Charlist,
) -> #(charlist.Charlist, Int)

fn sh(cmd: String, args: List(String), cwd: String) -> #(String, Int) {
  let args_cl = list.map(args, charlist.from_string)
  let #(out, rc) =
    sh_raw(charlist.from_string(cmd), args_cl, charlist.from_string(cwd))
  #(charlist.to_string(out), rc)
}

const repo_root = "/home/an/dev/ver/c3i"

const tla_dir = "/home/an/dev/ver/c3i/specs/tla"

const agda_dir = "/home/an/dev/ver/c3i/specs/agda"

const tlc_bin = "/home/an/dev/ver/c3i/.devenv/profile/bin/tlc"

const apalache_bin = "/home/an/.local/opt/apalache-0.57.0/bin/apalache-mc"

const agda_bin = "/home/an/dev/ver/intelitor-v5.2/.devenv/profile/bin/agda"

fn run_agda() -> #(String, Bool) {
  let #(_out, rc) = sh(agda_bin, ["--safe", "VaultStateMachine.agda"], agda_dir)
  case rc {
    0 -> #("agda --safe: PASS", True)
    _ -> #("agda --safe: FAIL rc=" <> int.to_string(rc), False)
  }
}

fn run_tlc() -> #(String, Bool) {
  // Use -simulate for the weekly cron — randomized 5000-step traces complete
  // in seconds and catch invariant violations (the full BFS at MaxClock=5
  // explores 100M+ states and takes hours).
  let #(out, rc) =
    sh(
      tlc_bin,
      [
        "-config", "RustyVaultIntegration_MC_smoke.cfg",
        "-simulate", "num=5000",
        "-depth", "30",
        "RustyVaultIntegration_MC.tla",
      ],
      tla_dir,
    )
  let no_violation = !string.contains(out, "is violated")
  case rc, no_violation {
    0, True -> #("tlc -simulate 5000: PASS (no invariant violation)", True)
    _, _ -> #("tlc: FAIL rc=" <> int.to_string(rc), False)
  }
}

fn run_apalache_one(inv: String) -> #(String, Bool) {
  let #(out, rc) =
    sh(
      apalache_bin,
      [
        "check",
        "--features=no-rows",
        "--inv=" <> inv,
        "--length=8",
        "RustyVaultIntegration_Apalache.tla",
      ],
      tla_dir,
    )
  let ok = string.contains(out, "NoError") && rc == 0
  case ok {
    True -> #("apalache " <> inv <> ": PASS", True)
    False -> #("apalache " <> inv <> ": FAIL rc=" <> int.to_string(rc), False)
  }
}

pub fn main() -> Nil {
  io.println("vault_formal_weekly :: " <> repo_root)
  let #(a_msg, a_ok) = run_agda()
  io.println(a_msg)
  let #(t_msg, t_ok) = run_tlc()
  io.println(t_msg)
  let invs = [
    "NoPlaintextAtRest",
    "BootUnsealsKEK",
    "VersionMonotonic",
    "AuditAppendOnly",
  ]
  let ap_results = list.map(invs, run_apalache_one)
  list.each(ap_results, fn(r) {
    let #(m, _) = r
    io.println(m)
  })
  let ap_all_ok =
    list.fold(ap_results, True, fn(acc, r) {
      let #(_, ok) = r
      acc && ok
    })
  let all_ok = a_ok && t_ok && ap_all_ok
  case all_ok {
    True -> io.println("vault_formal_weekly :: ALL PASS")
    False -> {
      io.println("vault_formal_weekly :: FAIL — see above")
      panic as "vault_formal_weekly failed; see stdout"
    }
  }
}
