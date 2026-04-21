# Fractal Criticality × RETE-UL × Ruliology × STAMP × FMEA/FEMA Protocol

## Supreme Mandate
All feature, rule, skill, agent, hook, and flow changes MUST be evaluated across:
- **All fractal layers L0-L7**
- **All core fractal components**
- **RETE-UL + ruliology decision paths**
- **STAMP constraints**
- **FMEA/FEMA risk controls**
- **Criticality-based execution policy (P0..P3)**

No change is considered complete until this matrix is produced and archived.

## STAMP Constraints (SC-FRAC-RRF)
| ID | Constraint | Severity |
|---|---|---|
| SC-FRAC-RRF-001 | Every change MUST publish a L0-L7 × component coverage matrix | CRITICAL |
| SC-FRAC-RRF-002 | Every matrix row MUST include RETE-UL/ruliology decision evidence | HIGH |
| SC-FRAC-RRF-003 | Every matrix row MUST include STAMP references (SC-*) | CRITICAL |
| SC-FRAC-RRF-004 | Every matrix row MUST include FMEA score (S,O,D,RPN) | HIGH |
| SC-FRAC-RRF-005 | P0/P1 rows MUST include FEMA-style incident response note | HIGH |
| SC-FRAC-RRF-006 | Execution order MUST be criticality-sorted (P0→P1→P2→P3) | CRITICAL |
| SC-FRAC-RRF-007 | Flow artifacts MUST be generated via sa-plan system scripts only | CRITICAL |
| SC-FRAC-RRF-008 | Hooks MUST enforce governance parity across .claude/.gemini | HIGH |
| SC-FRAC-RRF-009 | Matrix + summary MUST be ingested to ZK and linked from task-id page | HIGH |
| SC-FRAC-RRF-010 | Pi symbiosis bridge checks are mandatory for post-feature closure | CRITICAL |

## Core Fractal Components (required columns)
1. State management
2. Health monitoring
3. Recovery mechanism
4. Boundary/interface definition
5. Parent/child communication
6. Zenoh + OTel observability
7. AG-UI/A2UI compliance (where UI-touching)
8. STAMP control constraints
9. RETE-UL/ruliology decision evidence
10. FMEA/FEMA risk evidence

## Criticality Policy
- **P0**: constitutional/safety/security/guardian/scheduler integrity. Must include rollback, guardian gate, FEMA response note.
- **P1**: core orchestration/interop paths. Must include retry/backoff + operational runbook.
- **P2**: domain capabilities. Must include detection + mitigation test.
- **P3**: style/non-functional improvements. Must include non-regression proof.

## Required Artifact Outputs
- `docs/analysis/task-<task-id>/fractal-criticality-matrix.md`
- `docs/analysis/task-<task-id>/fractal-criticality-summary.json`
- task page link with tailscale URL at top of generated MD/HTML.

## Execution Flow
1. Build matrix skeleton for L0..L7.
2. Fill component evidence for each row.
3. Evaluate RETE-UL/ruliology decisions for impacted rows.
4. Attach STAMP constraints and FMEA/FEMA values.
5. Sort by criticality and execute P0→P3.
6. Run mandatory suites and Pi verification.
7. Ingest and publish links via sa-plan.

---

## Workspace Drift Constraints (SC-DRIFT-*) — promoted from drift Pass-3 (2026-04-21)
| ID | Constraint | Severity |
|---|---|---|
| SC-DRIFT-001 | Runtime state files (Smriti.db, logs) MUST NOT be committed | CRITICAL |
| SC-DRIFT-002 | Core code merges MUST pass full build+test in isolated worktree | CRITICAL |
| SC-DRIFT-003 | Governance and core_code merges MUST be separated by commit boundary | HIGH |
| SC-DRIFT-004 | Binary media bulk MUST be a single artifact-only commit | HIGH |
| SC-DRIFT-005 | Path-normalization deletions MUST ship with mapping ledger | HIGH |
| SC-DRIFT-006 | Submodule pointer changes MUST verify both repos clean | HIGH |
| SC-DRIFT-007 | Mainline `main` MUST remain buildable after every merge | CRITICAL |
| SC-DRIFT-008 | Multiverse worktree MUST be used for high-RPN merges | HIGH |

## Journal Corpus Integrity (SC-JNL-*) — promoted from corpus ultrathink (2026-04-21)
| ID | Constraint | Severity |
|---|---|---|
| SC-JNL-001 | Every journal MUST include accurate access URL (HTTP for `:4200`, HTTPS for `:8443` / `/c3i`) | CRITICAL |
| SC-JNL-002 | Journal duplicates across repos MUST be marked `mirror:` or symlinked | HIGH |
| SC-JNL-003 | Engineering closure changes MUST update prior journals with closure addendum | HIGH |
| SC-JNL-004 | Governance-bearing journals MUST be promoted to `.claude/.gemini/rules` within 24h | HIGH |
| SC-JNL-005 | Each task ID MUST appear in a canonical INDEX with supersedes/parent links | MEDIUM |
| SC-JNL-006 | Visual-evidence files MUST carry `role: visual-evidence` flag | MEDIUM |

## Multiverse pre-merge gate (canonical pattern)
```bash
git worktree add ../mv-governance -b multiverse/drift-governance main
git worktree add ../mv-corecode   -b multiverse/drift-corecode   main
git worktree add ../mv-docs       -b multiverse/drift-docs       main
git worktree add ../mv-hygiene    -b multiverse/drift-hygiene    main
# per-stream gates run; ff-only merges in RPN-descending order
```

## Mainline functional invariants (always)
1. `git checkout main && git pull` produces clean tree.
2. `gleam build && gleam test` in `lib/cepaf_gleam` passes.
3. `cargo build --release -p planning_daemon` passes.
4. `sa-plan status` returns valid output.
5. No runtime DB/log artifacts on `main`.
6. Only ff-only merges from verified multiverse branches.
