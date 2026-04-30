# Cross-Pass Invariant Gate Protocol (SC-CPIG)

## Supreme Mandate
**Every C3I subsystem MUST satisfy 5 CPIG gates before being considered "production-verified". The gate count tracks each subsystem's maturity from green-field (0/5) to fully-verified (5/5). System-wide CPIG score = mean(per-subsystem-score) across the 12 registered subsystems.**

ZK: [zk-bb4de67d97f807ac] selector-guessing anti-pattern · [zk-c14e1d23afff486c] pass-meta-pattern · [zk-d88a58e54ef8a08f] sa-plan-daemon Pass 12 baseline.

## 1. Pattern Origin

The CPIG meta-pattern was proven across **sa-plan-daemon Passes 1-12** (2026-04-08 → 2026-04-27). Every successful pass executed the same 5-step ritual:

1. **Formal-spec-first** — TLA+ + Agda specs authored before/with code (SchedTele.tla, ChatPipeline.tla, InferenceCascade.tla, Dispatcher.agda)
2. **Parallel sub-agent dispatch** — max-concurrency execution across formal/code/test/diagram tracks
3. **Wiring Guard analogue** — compile-time integration test catching cross-module drift (e.g. workers.rs registry vs match arms; Gleam Model fields vs init constructors)
4. **sa-plan tracking** — every change is a task with completion gate
5. **ZK ingestion + email closure** — institutional memory + operator notification per pass

This protocol generalises that ritual to **all 12 C3I subsystems**.

## 2. The 5 CPIG Gates

| Gate | Name | Verifier | Required artefact |
|---|---|---|---|
| G1 | Formal Spec | TLC / Apalache / Agda / Allium | `specs/<subsystem>/*.{tla,agda,allium}` model-checks the primary state machine |
| G2 | Wiring Guard | native test framework | One file per subsystem that fails-to-compile when any cross-module interface drifts |
| G3 | sa-plan Tracking | sa-plan-daemon | Every evolving change has `urn:c3i:task:<subsystem>:<id>` and reaches `completed` |
| G4 | ZK Ingestion | sa-plan-daemon ingest-docs | Journal + spec + diagrams ingested with `subsystem:<name>` tag within same session |
| G5 | Email Closure | sa-plan-daemon send-email | Operator notified with attachments per SC-NOTIFY-JOURNAL-001 |

A subsystem **score** = number of gates currently passing (0..5).

## 3. STAMP Constraints — SC-CPIG-001..015

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-CPIG-001 | Every subsystem MUST have a formal spec (TLA+ or Agda or Allium) covering its primary state machine | CRITICAL |
| SC-CPIG-002 | Every subsystem MUST have a Wiring Guard test in its native test framework | CRITICAL |
| SC-CPIG-003 | Every subsystem-evolving change MUST go through sa-plan task lifecycle | HIGH |
| SC-CPIG-004 | Every subsystem-evolving change MUST be ingested to ZK on completion | HIGH |
| SC-CPIG-005 | Every subsystem-evolving change MUST trigger email closure with attachments | HIGH |
| SC-CPIG-006 | Wiring Guard tests MUST run on every PR (CI gate) | CRITICAL |
| SC-CPIG-007 | Formal specs MUST be model-checked (TLC/Apalache) at least weekly | HIGH |
| SC-CPIG-008 | "Cross-pass invariant" = an invariant that must hold across N successive evolution passes — track via cumulative test passes | CRITICAL |
| SC-CPIG-009 | Every subsystem MUST register in the CPIG matrix at `docs/journal/task-116480247290237220/cpig-matrix.json` | HIGH |
| SC-CPIG-010 | Subsystems with CPIG < 3/5 MUST NOT receive new features (only invariant-gate work) until score reaches 3/5 | CRITICAL |
| SC-CPIG-011 | Parallel sub-agent dispatch MUST be used for >2 independent tracks | HIGH |
| SC-CPIG-012 | em-dash commit messages MUST cite SC-CPIG-* family | HIGH |
| SC-CPIG-013 | Drift detector agent MUST run hourly per subsystem | MEDIUM |
| SC-CPIG-014 | "unknown / mismatch / divergence" errors in production trigger P0 sa-plan task within 60s | CRITICAL |
| SC-CPIG-015 | CPIG score MUST be visible on the operator dashboard with 30s refresh | HIGH |

## 4. The 12 Registered Subsystems (baseline 2026-04-28)

| # | Subsystem | G1 spec | G2 wiring | G3 sa-plan | G4 ZK | G5 email | Score |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|
| 1 | sa-plan-daemon (scheduler+oban+cortex) | ✓ | ✓ | ✓ | ✓ | ✓ | **5/5** |
| 2 | Pi-mono symbiosis (bridge+runtime) | – | ✓ | ✓ | ✓ | – | **3/5** |
| 3 | Zenoh OTel ZMOF backplane | partial | – | ✓ | ✓ | – | **2/5** |
| 4 | FerrisKey IAM | – | – | ✓ | – | – | **1/5** |
| 5 | F# CEPAF bridge | ✓ Allium | – | ✓ | – | – | **2/5** |
| 6 | scripts-gleam userspace | – | ✓ | ✓ | ✓ | – | **3/5** |
| 7 | Marionette MCP integration | ✓ | ✓ | ✓ | ✓ | – | **4/5** |
| 8 | Patrol MCP | – | ✓ schema | ✓ | ✓ | – | **3/5** |
| 9 | Dart MCP server | – | – | ✓ | ✓ | – | **2/5** |
| 10 | Gleam UI Triple-Interface (Lustre+Wisp+TUI) | – | ✓ SC-WIRE-001 | ✓ | ✓ | ✓ | **4/5** |
| 11 | Cortex 6-tier hedged inference | ✓ | – | ✓ | – | – | **2/5** |
| 12 | Fractal widgets L0-L7 | – | – | ✓ | – | – | **1/5** |

**System-wide CPIG mean: 32/60 = 53%.**

### Pass Roadmap

- **Pass 13**: lift the 4 lowest (FerrisKey, fractal widgets, F# CEPAF, Dart MCP) to ≥ 3/5. Target mean: 40/60 (67%).
- **Pass 14**: lift all 12 to ≥ 4/5. Target mean: **48/60 (80%)**.
- **Pass 15**: full **60/60 (100%)** parity.

## 5. RETE-UL Rules (4 new, salience 95-100)

| Rule | Salience | Domain | When | Then |
|---|---:|---|---|---|
| `CpigScoreDrift` | 100 | governance | subsystem score regresses vs cpig-matrix.json baseline | open P0 sa-plan task; halt feature commits to that subsystem |
| `CpigPassGate` | 100 | governance | subsystem at < 3/5 receives a feature commit (not invariant-gate work) | BLOCK commit; emit `[SC-CPIG-010 VIOLATION]` |
| `CpigCrossSubsystemDrift` | 95 | governance | invariant in subsystem A references subsystem B not in registry | open P1 task; auto-register or remove reference |
| `CpigWeeklyRecheck` | 95 | scheduler | Sunday 02:00 UTC | run TLC + Agda + Allium tend on every G1 artefact; update matrix |

These rules join the existing 52 GRL rules in `lib/cepaf_gleam/src/cepaf_gleam/rules/engine.gleam` (governance domain).

## 6. Ruliology

- **Wolfram Rule 110** (complexity emergence): per-pass CPIG score increase is **monotonic only if all 5 gates fire per pass**. A pass that skips even one gate causes regression on at least one cross-pass invariant within ≤ 3 passes.
- **Wolfram Rule 30** (chaos): subsystem score regressions are **correlated** — when one subsystem drops, the probability another drops within 7 days is ≥ 0.4. Causal graph edges = shared formal spec + shared Wiring Guard target.
- **Lyapunov on score**: `λ = d(score) / d(pass)` — must be ≥ 0 averaged over 3-pass window; `λ < 0` triggers `CpigScoreDrift`.

## 7. FMEA — Top failure modes per gate gap

| Gate gap | Failure mode | S | O | D | RPN | Mitigation |
|---|---|---:|---:|---:|---:|---|
| G1 missing | State-machine drift unnoticed in production | 9 | 7 | 8 | **504** | TLC weekly + Allium tend |
| G2 missing | Cross-module integration breaks scattered across N test files | 8 | 8 | 7 | **448** | one-file Wiring Guard per subsystem |
| G3 missing | Untracked changes; lost provenance | 7 | 6 | 6 | 252 | sa-plan pre-commit hook |
| G4 missing | Institutional amnesia; pattern repeats | 7 | 7 | 5 | 245 | Stop hook ingests automatically |
| G5 missing | Operator unaware of subsystem state changes | 6 | 5 | 4 | 120 | SC-NOTIFY-JOURNAL-001 enforcement |
| G1+G2 missing | Production divergence + no detection | 10 | 7 | 9 | **630** | block all feature work (SC-CPIG-010) |

**Pre-CPIG ΣRPN ≈ 5400** (12 subsystems × avg 450). **Target post-CPIG ΣRPN ≈ 600** (89% reduction) once all subsystems reach 4/5.

Action threshold: RPN ≥ 200 → P0/P1 sa-plan task per `CpigScoreDrift`.

## 8. Mathematical Gates

```
score(s)     = |{g ∈ {G1..G5} : passing(s, g)}|              ; 0..5 per subsystem
CPIG_total   = (Σ score(s) for s in registry) / (5 * |registry|)
             ≥ 0.80 for Pass-14 close                        ; mean gate coverage
H(scores)    = −Σ p_i log2(p_i) over score histogram          ; entropy
             ≥ 1.5 bits                                       ; broad maturity
λ_pass       = (CPIG_total[t] − CPIG_total[t−3]) / 3          ; 3-pass slope
             ≥ 0 (no regression)
D_baseline   = max(0, baseline(s) − score(s))                 ; per subsystem
             = 0 ∀ s                                          ; no regressions
```

## 9. Cross-Pass Invariant Examples

A "cross-pass invariant" is a property that must hold across **N successive evolution passes**, not just within one pass. Examples already verified across Passes 1-12:

- **CPI-1**: `workers::dispatch` registry size ≥ match-arm count (caught at Pass 6, held through Pass 12)
- **CPI-2**: every Gleam `Model` field has a corresponding entry in `wiring_guard.gleam` (caught at Pass 4)
- **CPI-3**: every Zenoh topic published has at least one declared subscriber across the mesh (caught at Pass 9)
- **CPI-4**: every sa-plan task transitions through `pending → in_progress → completed` (no skips) (caught at Pass 2)
- **CPI-5**: Pi tool federation count = 6 Claude + 14 Pi + 73 C3I MCP = 93 (caught at Pass 7)

## 10. Parallel Sub-Agent Dispatch (SC-CPIG-011)

When a CPIG pass touches > 2 independent tracks, dispatch in parallel:

```
fractal-architect       → G1 formal-spec authoring
code-reviewer           → G2 wiring-guard authoring
coverage-audit-agent    → G3+G4 sa-plan + ZK ingestion
cpig-validator          → G5 closure verification + matrix update
```

Each agent runs in its own conversation with a slice of the pass plan; the main thread merges results.

## 11. Cross-References

- Pass 1-12 deliverables: `docs/journal/task-116480247290237220/`
- SC-WIRE-001 (Gleam Wiring Guard): `.claude/rules/wiring-guard.md`
- SC-DISP-REGISTRY-001..010 (Rust dispatcher integrity): workers.rs registry
- SC-SCRIPT-GLEAM-001 (scripts-gleam isolation): `.claude/rules/gleam-only-scripting-mandate.md`
- SC-PI-AUTO-001..008 (Pi symbiosis automation): `.claude/rules/pi-symbiosis-automation.md`
- SC-ZMOF-001 (Zenoh transport): GEMINI.md §2.6
- SC-NOTIFY-JOURNAL-001 (email closure): `.claude/rules/journal-email-attachment.md`
- SC-MARIONETTE-JIDOKA-001..010: `.claude/rules/marionette-fractal-jidoka.md` (the prototype that proved CPIG-style hourly validation)
- Allium spec template: `specs/allium/TEMPLATE.allium`

## 12. Governance Parity

Mirror at `.gemini/rules/cross-pass-invariant-gate.md` per SC-SYNC-DOC-007.

## 13. Operator Surface

```bash
# Show current matrix
cat docs/journal/task-116480247290237220/cpig-matrix.json | jq '.subsystems[] | {name, score}'

# Compute system-wide score
cat docs/journal/task-116480247290237220/cpig-matrix.json | \
  jq '[.subsystems[].score] | add / (length * 5) * 100' \
  # → 53.0  (Pass-12 baseline)

# Run validator on demand
.claude/agents/cpig-validator.md  # via Task tool

# Weekly recheck (cron)
0 2 * * 0 cd /home/an/dev/ver/c3i && ./tool/cpig-weekly-recheck.sh
```
