# Validators Meta-Test Protocol (SC-VALIDATORS-META-TEST)

## Mandate

**The Lyapunov detectors themselves MUST be proven to trip on synthetic bad input.** A detector observed only in the ✓ state is itself a Stub-That-Lies risk [zk-bd82645aedcb5ef4] — its silence could mean either "actually healthy" or "broken parsing that always returns 0".

This rule mandates a meta-test that feeds known-bad data through the detectors and verifies they produce the expected P0 classification.

ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies (RPN 729), [zk-c14e1d23afff486c] implicit-invariant family, [zk-426c4adf07d076ad] SC-STOP-HOOK-TELE, perf-bench-20260516 closure pack.

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-VALIDATORS-META-TEST-001 | Meta-test MUST save real logs to `.bak`, write synthetic bad input, run detector, restore | CRITICAL |
| SC-VALIDATORS-META-TEST-002 | Meta-test MUST verify each detector emits the expected classification token | HIGH |
| SC-VALIDATORS-META-TEST-003 | Substring matches MUST be ASCII-safe — Erlang charlist→string decodes as Latin-1, mangling `✗` and `—` | CRITICAL |
| SC-VALIDATORS-META-TEST-004 | Meta-test MUST restore real logs even on failure path | CRITICAL |
| SC-VALIDATORS-META-TEST-005 | Exit non-zero on ANY detector failing to trip | HIGH |

## Anti-pattern caught mid-pass (Pass 11)

The first version of this meta-test searched for the UTF-8 string `"✗ P0"` in detector stdout. It returned `false` on inputs that *should* have tripped the detector. Diagnostic output revealed the detector was correctly emitting `✗ P0 — runtime hazard`, but `charlist.to_string()` decoded the bytes as Latin-1, producing `â P0 â runtime hazard` — the multi-byte UTF-8 of `✗` (E2 9C 97) became three separate Latin-1 characters. The substring `"✗ P0"` (also UTF-8 in Gleam source) could not match the mangled bytes.

**Fix**: match on the ASCII-only hint line substring `"--priority P0"` (or `"--priority P1"`), which the detector always emits alongside the verdict. SC-VALIDATORS-META-TEST-003 codifies this pattern.

## Reference implementation

`sub-projects/scripts-gleam/src/scripts/verify/validators_meta_test.gleam` (~135 LOC) — tests stop_hook_lyapunov and disk_lyapunov.

```
$ gleam run -m scripts/verify/validators_meta_test
══ Validators Meta-Test (SC-VALIDATORS-META-TEST) ══
anti-Stub-That-Lies: proving detectors actually trip on bad input

── stop_hook_lyapunov · synthetic elapsed_s=99 → expect ✗ P0 ──
  → contains '✗ P0': true
── disk_lyapunov · synthetic pct=96 → expect ✗ P0 ──
  → contains '✗ P0': true

── summary ──
  ✓  stop_hook_lyapunov · synthetic elapsed_s=99 → expect ✗ P0
  ✓  disk_lyapunov · synthetic pct=96 → expect ✗ P0

✓ all meta-tests pass — validators are not Stub-That-Lies
```

## Cross-references

- `.claude/rules/stop-hook-lyapunov.md` (SC-STOP-HOOK-LYAPUNOV) — detector under test
- `.claude/rules/disk-lyapunov.md` (SC-DISK-LYAPUNOV) — detector under test
- `.claude/rules/learn-loop-healthcheck.md` (SC-LEARN-LOOP-HEALTHCHECK) — sibling aggregator
- `docs/journal/learn-loop-hardening-20260516/journal.md` — 8-pass arc closure

## Governance parity

Mirror at `.gemini/rules/validators-meta-test.md` per SC-SYNC-DOC-007.
