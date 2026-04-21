# Root Repo Workspace Drift Analysis — Pass 2 (Safety/FEMA/Complexity/Criticality/Durability)

## Objective
Second-pass deep analysis focused on:
1. **Safety** (mainline integrity, accidental regressions)
2. **FEMA/FMEA risk profile**
3. **Complexity and coupling drift**
4. **Criticality-ranked remediation**
5. **Durability strategy**
6. **Biomorphic evolutionary plan** with **multiverse pre-merge testing**

---

## A. Quantified Drift Snapshot
- Drift entries: **434**
  - Untracked: **258**
  - Deleted: **89**
  - Modified: **87**
- Dominant zones:
  - `.gemini` governance surface: **162** entries
  - `docs` artifacts: **93** entries
  - `lib/cepaf_gleam`: **92** entries
  - `.claude`: **55** entries

### Core code drift detail (`lib/cepaf_gleam`)
- Total entries: **92**
  - Modified tracked: **17**
  - Deleted tracked: **1** (`claude_compute.gleam`)
  - Untracked: **74** (68 `.gleam`, plus html/other)
- Tracked delta: **+394 / -174** across 18 files
- Estimated new untracked text LOC: **~19,256**

### Artifact drift detail (`docs`)
- Binary-like content: **~29.86 MB**
- Text content: **~1.26 MB**
- Journal drift count: **58** (17 task-specific)

### Critical tracked files currently drifting
- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `PROJECT_TODOLIST.md`
- `data/smriti/Smriti.db`
- `data/logs/ignition_capture.log`

---

## B. Safety Analysis (Mainline Operational Risk)

### Safety findings
1. **Mainline contamination risk (HIGH)**
   - Runtime state files (`Smriti.db`, logs) are dirty in working tree.
   - These can silently alter behavior across sessions and make rollback non-deterministic.

2. **Governance/content split risk (HIGH)**
   - Large `.gemini` drift + nested path normalization deletions (`agents/agents`, `rules/rules`, `commands/commands`) is logically valid but operationally noisy.
   - If merged as one lump, post-incident forensic traceability is degraded.

3. **Code + policy + media coupling risk (HIGH)**
   - Core code, policy docs, generated media, and runtime data are simultaneously dirty.
   - This violates clean-layer deployment principles and impairs safe hotfixes.

4. **Sub-repo / submodule ambiguity (MEDIUM-HIGH)**
   - Root shows `sub-projects/c3i` pointer drift (expected) but historical nested-repo residue causes `git submodule status` anomaly.
   - Potential supply-chain and reproducibility concern unless normalized.

---

## C. FEMA/FMEA Risk Matrix (workspace drift)

| Drift Class | S | O | D | RPN | Criticality | Failure Mode |
|---|---:|---:|---:|---:|---|---|
| Governance drift (`.gemini/.claude`) | 8 | 8 | 4 | **256** | **P0** | Constraint mismatch, operator confusion, invalid automation routing |
| Core code drift (`lib/cepaf_gleam`) | 9 | 7 | 4 | **252** | **P0** | Runtime regressions, compile/test failures, interface drift |
| Docs/media drift | 5 | 8 | 5 | **200** | **P1** | Repo bloat, slow CI, impaired code review signal |
| Runtime state tracked drift | 8 | 7 | 3 | 168 | P1 | Non-deterministic behavior, irreproducible incidents |
| Duplicate nesting cleanup | 6 | 9 | 3 | 162 | P1 | Accidental deletion perception, migration confusion |
| Local env artifacts | 4 | 8 | 4 | 128 | P2 | Noise and accidental commit risk |

**Priority directive**: handle P0 classes before any functional expansion.

---

## D. Complexity Analysis

### Structural complexity increases
- High breadth, low cohesion commit pressure:
  - 400+ drift entries across governance, code, docs, state, binaries.
- Implicit coupling across layers:
  - `.claude/.gemini` policy changes influence tooling behavior.
  - `lib/cepaf_gleam` changes alter runtime correctness.
  - `docs` artifacts inflate review surface without improving runtime confidence.

### Complexity reducers available
1. **Stratified change sets** by concern:
   - policy/governance
   - runtime code
   - generated docs/media
   - runtime state (never versioned)
2. **Multiverse worktree gating** to isolate risk by stream.
3. **RPN-threshold merge policy**: no direct merge for RPN >= 200 streams.

---

## E. Durability Analysis

Durability means reproducibility + recoverability + rollback clarity.
Current blockers:
- Runtime DB/log tracked as drift (violates reproducibility)
- Large generated binaries mixed with code streams
- Ambiguous nested `.gemini/*/*` migration history not codified as a one-time migration commit

Durability controls required:
1. **State segregation**: runtime state excluded from VCS or isolated in explicit snapshot commits.
2. **Artifact policy**: media in release artifacts/object storage, not routine code commits.
3. **Migration ledger**: single auditable commit for path normalization with mapping table.
4. **Mainline protection**: merge only from verified multiverse branches.

---

## F. Biomorphic Evolutionary Plan (with Multiverse pre-merge)

## L0 Constitutional (P0)
- Freeze mainline mutation.
- Establish gate: no direct `main` edits for drift cleanup.
- Define merge contract: RPN<200 and full test pass required.

## L1 Sensory (P0)
- Generate continuous drift telemetry:
  - `git status --porcelain` census
  - category counts and delta trends
  - binary footprint trend
- Publish to `docs/analysis/root-drift-ledger-*.txt`.

## L2 Immune Classification (P0)
- Classify each file into buckets: governance/code/docs/state/local.
- Auto-tag danger buckets (`RPN>=200`).

## L3 Metabolic Routing (P0/P1)
Create **multiverse worktrees** (one stream per concern):
```bash
git worktree add /tmp/mv-governance -b multiverse/drift-governance main
git worktree add /tmp/mv-corecode   -b multiverse/drift-corecode   main
git worktree add /tmp/mv-docs       -b multiverse/drift-docs       main
git worktree add /tmp/mv-hygiene    -b multiverse/drift-hygiene    main
```

## L4 Homeostasis (P0)
In each worktree:
- run deterministic checks
- prevent cross-stream contamination
- maintain strict commit boundaries

Required baseline gate per stream:
```bash
# governance stream
./sa-plan sync && ./sa-plan status

# core code stream
cd lib/cepaf_gleam && gleam build && gleam test

# sub-project stream
cd sub-projects/c3i && cargo build --release --jobs 10
```

## L5 Cognitive (P0)
Risk-adaptive merge order:
1. `multiverse/drift-governance`
2. `multiverse/drift-corecode`
3. `multiverse/drift-hygiene` (ignore rules, local artifacts)
4. `multiverse/drift-docs`

Enforce ff-only integration:
```bash
git checkout main
git merge --ff-only multiverse/drift-governance
```

## L6 Federation (P1)
- Mirror `.claude`/`.gemini` parity checks pre-merge.
- Validate no orphaned path remaps.
- Ensure sub-project pointer updates are intentional and synchronized.

## L7 Evolution/Audit (P1)
- Produce post-merge audit packet:
  - drift delta before/after
  - RPN reductions
  - remaining risk backlog
  - rollback references per stream commit

---

## G. Mainline Functional Assurance Policy

**Invariant**: mainline always buildable and testable.

1. All experimental cleanup done in multiverse branches/worktrees.
2. Merge only after passing stream-specific mandatory gates.
3. No runtime DB/log artifacts in merge payload.
4. Any docs/media bulk merges must be decoupled from runtime code merges.
5. If any gate fails, branch is quarantined, not merged.

---

## H. Immediate Actions (next 1-2 hours)
1. Create the 4 multiverse worktrees.
2. Move P0 classes (governance + core code) into separate branches.
3. Add/update ignore policy for local artifacts and runtime state.
4. Run full gates in each stream.
5. Merge ff-only in risk order.

---

## I. Success Criteria
- Drift entries reduced from 434 to near-zero (excluding intentional in-flight stream).
- No `data/smriti/*.db` or runtime logs in staged changes.
- No mixed concern commits (policy+code+media in same commit).
- `main` passes required build/tests after each merge.
- Documented RPN drop for P0/P1 classes.
