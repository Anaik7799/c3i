# NIF/FFI Panic Guard Protocol (SC-NIF-LOAD-006)

## Mandate
**Every NIF or extern-C FFI crate that depends on `zenoh = "*"` AND `tokio` MUST wrap every entry-point body in `catch_unwind(AssertUnwindSafe(...))`.** Unwinding across an FFI boundary is undefined behavior in Rust; without this guard, panics inside zenoh-rs / tokio internals (e.g. `tracing::set_global_default` second-call, nested runtime init, ring/glibc TLS interaction) surface to BEAM as **SIGSEGV (signal 11)**, tearing the supervisor restart budget instead of producing a recoverable Elixir `{:error, _}` term.

ZK lineage: [zk-c14e1d23afff486c] async-block-in-tokio::select! anti-pattern · [zk-bd82645aedcb5ef4] no-Stub-That-Lies (RPN 729) · [zk-48121207f7d4fd36] mechanically-verified-right-now mandate · [zk-d6ab97006d3bbc88] max-parallelization continuation pattern. Pass-3+Pass-4 closure: `docs/journal/task-116503330407891617/journal.md` §§ A-J.

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-NIF-LOAD-006 | Every `#[rustler::nif]` body in a crate that pulls `zenoh` + `tokio` MUST route through a `ffi_guard_*` helper that calls `std::panic::catch_unwind(AssertUnwindSafe(...))` | CRITICAL |
| SC-NIF-LOAD-007 | Every `extern "C" fn` body in a crate that pulls `zenoh` + `tokio` MUST route through an `ffi_guard!` macro that calls `std::panic::catch_unwind(AssertUnwindSafe(...))` and returns a sentinel/default value (C-ABI cannot encode `Result`) | CRITICAL |
| SC-NIF-LOAD-008 | The FFI guard MUST extract the panic payload (`String` / `&'static str` / fallback) and emit a `log::error!("[<crate>] PANIC caught in <fn>: <msg>")` line BEFORE returning the error term/sentinel | HIGH |
| SC-NIF-LOAD-009 | The FFI guard MUST live in **one file per crate** (single source of truth — usually `lib.rs`) — inline duplicates are forbidden | HIGH |
| SC-NIF-LOAD-010 | Pure-CPU NIF crates (no `tokio`, no `zenoh`, no `reqwest`, no `hyper`, no FFI to C libraries that may abort) are EXEMPT — the panic surface is only the user data they receive, which Rust handles via `Result`/`NifResult` cleanly | INFO |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-NIF-LOAD-001 | NEVER add a new `#[rustler::nif]` to `zenoh_nif` without routing it through `lib::ffi_guard_term` or `lib::ffi_guard_atom` |
| AOR-NIF-LOAD-002 | NEVER add a new `extern "C" fn` to `zenoh_ffi` without wrapping its body in the existing `ffi_guard!` macro |
| AOR-NIF-LOAD-003 | NEVER let `panic="unwind"` (workspace default) silently bypass the guard — always assume zenoh-rs / tokio internals can panic |
| AOR-NIF-LOAD-004 | ALWAYS test new guarded NIFs with a live BEAM probe (image rebuild + `podman run` + capture exit code) — exit 0 confirms guard, exit 139 confirms regression |
| AOR-NIF-LOAD-005 | NEVER introduce `DISABLE_*_NIF` env-var bypasses to "work around" the panic — the operator mandate is NIF-always-on; the FFI guard is the only acceptable mitigation |

## Reference Implementations (proven prior art)

| Surface | Crate | Mechanism | Source |
|---|---|---|---|
| C-ABI (`extern "C" fn`) for F# DllImport | `sub-projects/c3i/native/zenoh_ffi/` | `ffi_guard!` macro returning a sentinel default | `zenoh_ffi/src/lib.rs:438` (since SC-ZENOH-FFI-001) |
| BEAM-ABI (`#[rustler::nif]`) | `sub-projects/c3i/native/zenoh_nif/` | `ffi_guard_term` + `ffi_guard_atom` helpers returning `NifResult<{:error, "<nif> panic: <msg>"}>` | `zenoh_nif/src/lib.rs:51` (Pass-4, 2026-05-02) |

## CI gate (proposed)

A `scripts-gleam` verifier under `sub-projects/scripts-gleam/src/scripts/verify/` SHOULD enforce SC-NIF-LOAD-006/007 on every PR touching the two zenoh-using crates:

```
# pseudocode (Gleam-only per SC-SCRIPT-GLEAM-001 — DO NOT shell-script)
for each crate in {zenoh_nif, zenoh_ffi}:
  src/lib.rs MUST contain "catch_unwind" OR "ffi_guard"
  for each function annotated #[rustler::nif] in src/lib.rs (zenoh_nif):
    body MUST start with `ffi_guard_term(` or `ffi_guard_atom(`
    OR be on the SC-NIF-LOAD-010 exempt list (close_session, unsubscribe, classifier-only)
  for each `extern "C" fn` in src/lib.rs (zenoh_ffi):
    body MUST contain `ffi_guard!`
exit 1 with offending file:line list if any violation
```

## Empirical evidence (Pass-4 mechanical verification, 2026-05-02)

| Layer | Before Pass-3 | After Pass-3 | After Pass-4 |
|---|---|---|---|
| Guarded zenoh_nif entry points | 0 | 1 (`zenoh_open_session` only) | **11** |
| BEAM exit code on rebuilt image | 139 (SIGSEGV) | 0 (open path only) | **0 (open + publish path live-exercised)** |
| `Indrajaal.Boot.ZenohBootPublisher.do_publish/2` checkpoint accepted by router | n/a | n/a | **YES** (`indrajaal/boot/preflight/start`) |
| Operator NIF-always-on mandate | satisfied | satisfied | satisfied |

## Cross-references

- `.claude/rules/wiring-guard.md` — SC-WIRE-001..007 sibling for type-domain (this rule covers FFI-domain)
- `.claude/rules/secrets-vault.md` — SC-VAULT-005 sibling (hot path no network calls — same "FFI safety" family)
- `.claude/rules/cross-pass-invariant-gate.md` — SC-CPIG-001..015 (CPI-Z-001 belongs here)
- `.claude/rules/sched-telemetry-mandatory.md` — SC-SCHED-TELE-MANDATORY (sibling — telemetry every subprocess)
- `sub-projects/c3i/native/zenoh_nif/src/lib.rs` — Pass-4 reference implementation
- `sub-projects/c3i/native/zenoh_ffi/src/lib.rs:438` — original `ffi_guard!` macro (prior art)
- `docs/journal/task-116503330407891617/journal.md` §§ H-J — workspace-wide audit + parity invariant proposal

## Governance parity

Mirrored at `.gemini/rules/nif-ffi-panic-guard.md` per SC-SYNC-DOC-007.
