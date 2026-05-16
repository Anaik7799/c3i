# FY27 ZK Peer Optional Protocol (SC-FY27-PEER-OPTIONAL)

## Mandate

**The `fy27-zettelkasten` binary is a PERMANENTLY OPTIONAL peer of the OODA Learn loop.** C3I-ZK ingestion is required; FY27-ZK is best-effort. This rule formalizes the graceful-absence handling already shipped in Phase A.2 (perf-bench-20260516) so future maintainers do not "fix" the absence and reintroduce the BEAM-crash class.

Disposition rationale (audited 2026-05-16):
- `sub-projects/work/fy27-zk-build/` does **not exist** on the canonical dev host (mechanically verified via `ls`)
- The binary is a sales-only peer (semiconductor sales / FY27 EMEA plan) — orthogonal to engineering OODA
- Rebuild requires a separate build environment + gdrive mount which is not always available
- Cost of permanent absence: zero — the engineering loop runs unaffected
- Cost of unprotected absence: BEAM SIGSEGV (the pre-Phase-A.2 failure mode)

ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies (RPN 729 — verify before claiming), [zk-c14e1d23afff486c] implicit-invariant family, [zk-f8f40cb7e63db61a] next-pass roadmap, perf-bench-20260516 § 10 (Remaining Gaps).

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-FY27-PEER-OPTIONAL-001 | Stop-hook MUST treat `rc=127` from fy27-zettelkasten as `fy27=absent` (not error) | CRITICAL |
| SC-FY27-PEER-OPTIONAL-002 | Stop-hook MUST treat `rc=124` (FFI timeout) as `fy27=timeout` (not error) | HIGH |
| SC-FY27-PEER-OPTIONAL-003 | `fy27=absent` MUST NOT block the systemMessage JSON emission | CRITICAL |
| SC-FY27-PEER-OPTIONAL-004 | `fy27=absent` MUST NOT raise SC-CPIG-CONSISTENCY violations for FY27-related gates | HIGH |
| SC-FY27-PEER-OPTIONAL-005 | Any attempt to make FY27-ZK ingest *required* MUST first re-verify the binary builds on the dev host AND update this rule | CRITICAL |
| SC-FY27-PEER-OPTIONAL-006 | The systemMessage MUST surface the FY27 status (`ok`/`absent`/`timeout`/`degraded`) so absence is observable, not hidden | HIGH |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-FY27-OPT-001 | NEVER hard-code an `assert fy27_rc == 0` style check anywhere downstream of stop-hook |
| AOR-FY27-OPT-002 | NEVER alter the rc=127 / rc=124 branches in `stop_hook.gleam` without amending this rule |
| AOR-FY27-OPT-003 | When the FY27 binary is rebuilt and present, this rule still stands — peer remains *optional*, just observed as `fy27=ok` |

## Reference implementation

`sub-projects/scripts-gleam/src/scripts/sysd/stop_hook.gleam` lines 94-108:

```gleam
let #(_, fy27_rc) =
  sh_in(cl(fy27_zk), cls(["import", ".."]), cl(fy27_zk_dir))
// ...
let fy27_status = case fy27_rc {
  0 -> "ok"
  127 -> "absent"
  124 -> "timeout"
  _ -> "degraded"
}
```

Current observed status (5 consecutive passes through 2026-05-16): `fy27=absent` — expected, healthy.

## Cross-references

- `.claude/rules/stop-hook-telemetry.md` (SC-STOP-HOOK-TELE) — captures fy27_rc per run
- `.claude/rules/stop-hook-lyapunov.md` (SC-STOP-HOOK-LYAPUNOV) — does NOT alert on fy27_rc=127
- `.claude/rules/nif-ffi-panic-guard.md` (SC-NIF-LOAD-006..010) — sibling rule for the BEAM panic class this avoids
- `docs/journal/perf-bench-20260516/journal.md` § 10 — origin of the disposition decision

## Governance parity

Mirror at `.gemini/rules/fy27-peer-optional.md` per SC-SYNC-DOC-007.
