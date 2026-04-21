# Root Repo Workspace Drift — Pass 3
**Mathematical + STAMP + RETE-UL + Ruliological + Biomorphic Multiverse Plan**

---

## 0. Notation and base set

Let `D = {d_1 ... d_N}` be the set of dirty entries reported by `git status --porcelain`. Currently:
- `N = 436`

Categories `C = {governance, core_code, docs_text, binary_media, runtime_state, dup_nested, local_env, submodule_ptr, other}` partition `D` via `cat: D → C`.

Per-class counts `n_c` and probability `p_c = n_c / N`.

---

## 1. Mathematical Drift Profile

### 1.1 Distribution
| Category | Count `n_c` | Share `p_c` |
|---|---:|---:|
| governance      | 130 | 0.298 |
| docs_text       | 93  | 0.213 |
| core_code       | 92  | 0.211 |
| dup_nested      | 87  | 0.200 |
| local_env       | 15  | 0.034 |
| other           | 15  | 0.034 |
| runtime_state   | 2   | 0.005 |
| binary_media    | 2   | 0.005 |

### 1.2 Information-theoretic indices
- **Shannon entropy of drift distribution:** `H(D) = 2.339 bits` (target ≥ 2.5 bits ⇒ slightly underdiverse, but **dominated by 4 high-mass classes** ⇒ concentrated risk)
- **Mutation Load Index (modified+deleted / total):** `MLI = 0.404`
- **Untracked Load Index:** `ULI = 0.596`
- **Duplicate Nesting Ratio:** `DRI = 0.200`
- **Binary Media Ratio in docs subtree:** `BMR = 0.970`
- **Weighted Complexity Index:** `WCI = 1.137`

### 1.3 Composite scores
- **Composite Systemic Drift Index (CSI):**
  `CSI = 0.30·MLI + 0.25·(WCI/2) + 0.20·DRI + 0.15·BMR + 0.10·(SI/9) = 0.497`
- **System Confidence Score (SCS):** `SCS = 1 - CSI = 0.503`
- **Durability/Safety Index (DSI):** `DSI = 1 - WRPN/700 = 0.694`
  where `WRPN = (Σ_c n_c · RPN_c)/N = 214.5` (weighted RPN per entry)

These say: **systemic drift health is borderline (~0.50 confidence)**, with **safety durability at ~0.69**, both below the safe operational threshold (`≥0.85` for production-grade mainline integrity).

### 1.4 FMEA per category
| Category | Count | S | O | D | RPN | Weighted RPN |
|---|---:|---:|---:|---:|---:|---:|
| governance      | 130 | 8 | 8 | 4 | **256** | 33,280 |
| core_code       | 92  | 9 | 7 | 4 | **252** | 23,184 |
| docs_text       | 93  | 5 | 8 | 5 | **200** | 18,600 |
| dup_nested      | 87  | 6 | 9 | 3 | 162    | 14,094 |
| runtime_state   | 2   | 8 | 7 | 3 | 168    | 336    |
| local_env       | 15  | 4 | 8 | 4 | 128    | 1,920  |
| binary_media    | 2   | 5 | 6 | 4 | 120    | 240    |
| other           | 15  | 5 | 5 | 5 | 125    | 1,875  |

P0 zones (RPN ≥ 200):
- governance, core_code, docs_text.

P1 zones (RPN ≥ 100):
- dup_nested, runtime_state, local_env, binary_media, other.

---

## 2. STAMP analysis (Systems-Theoretic Accident Model)

### 2.1 Hierarchical control structure (drift-relevant)
- **Operator/Agent (Claude/Gemini)** ──control──▶ **Workspace (root repo)** ──feedback──▶ **`git status` ledger** ──telemetry──▶ **Operator**
- Side controllers:
  - **Sub-project repo (`sub-projects/c3i`)**: separate authoritative repo; coupling via gitlink pointer.
  - **Smriti runtime (`Smriti.db`)**: side-effect emitter; never a controlled merge artifact.
  - **CI/CD policy (.gitignore + governance rules)**: declared boundary controller.

### 2.2 STAMP unsafe control actions (UCAs)
| UCA-ID | Description | Hazard | Constraint |
|---|---|---|---|
| UCA-1 | Operator commits `runtime_state` to mainline | Non-deterministic behavior, irreproducible regressions | `H1: mainline must be reproducible` |
| UCA-2 | Operator merges `core_code` without isolated build/test | Latent runtime regression on `main` | `H2: mainline must be buildable & testable post-merge` |
| UCA-3 | Operator merges `governance` and `core_code` together | Reviewability collapse, blast radius unbounded | `H3: separation of concerns at merge boundary` |
| UCA-4 | Operator pushes `docs_text` + `binary_media` without artifact policy | Repo bloat, slow CI, signal loss | `H4: artifact policy enforced before merge` |
| UCA-5 | Operator merges `dup_nested` deletions without migration ledger | Forensic audit gap | `H5: migrations must be auditable & reversible` |
| UCA-6 | Operator advances submodule pointer without verification | Cross-repo desync | `H6: submodule pointer integrity` |

### 2.3 Safety constraints (target STAMP set, SC-DRIFT-*)
| ID | Constraint | Severity |
|---|---|---|
| SC-DRIFT-001 | Runtime state files MUST NOT be committed | CRITICAL |
| SC-DRIFT-002 | Core code merges MUST pass full build+test in isolated worktree | CRITICAL |
| SC-DRIFT-003 | Governance and core_code merges MUST be separated by commit boundary | HIGH |
| SC-DRIFT-004 | Binary media bulk MUST be committed as a single artifact-only commit | HIGH |
| SC-DRIFT-005 | Path-normalization deletions MUST ship with mapping ledger | HIGH |
| SC-DRIFT-006 | Submodule pointer changes MUST verify both repos are clean | HIGH |
| SC-DRIFT-007 | Mainline `main` MUST remain buildable after every merge | CRITICAL |
| SC-DRIFT-008 | Multiverse worktree MUST be used for high-RPN merges | HIGH |

### 2.4 STAMP control loops to add
- **Loop A (Pre-merge gate):** worktree-local build/test → green → ff-only merge.
- **Loop B (State firewall):** ignore runtime artifacts + runtime path quarantine.
- **Loop C (Audit ledger):** generate before/after drift telemetry, ingest to ZK.

---

## 3. RETE-UL analysis (production rule engine view)

### 3.1 Working memory facts
For each `d ∈ D`:
- `Fact(file=d, status, category, RPN, layer, blast_radius)`

### 3.2 Production rules (high-RPN sample)
```
R1 (governance high mass):
   IF count(category='governance') ≥ 100 AND mainline.changed(governance, core_code) WITHIN 1 commit
   THEN block_merge AND open_stream(multiverse/drift-governance) AND open_stream(multiverse/drift-corecode)

R2 (core_code split by domain):
   IF category='core_code' AND domain ∈ {bridge/, ha/, ui/} AND blast_radius='cross-cutting'
   THEN require_split_commits BY domain

R3 (runtime_state quarantine):
   IF category='runtime_state'
   THEN reject_from_merge AND ensure_gitignore(path)

R4 (binary media gating):
   IF category='binary_media' OR (category='docs_text' AND BMR ≥ 0.9)
   THEN route_to_artifact_only_commit

R5 (dup_nested cleanup):
   IF category='dup_nested'
   THEN require_migration_ledger AND tag_commit(scope='migration')

R6 (submodule integrity):
   IF category='submodule_ptr'
   THEN require_subproject_clean AND record_target_sha

R7 (mainline invariant):
   IF stream_to_merge='*' AND build_or_test_failed
   THEN refuse_ff_only AND open_quarantine_branch

R8 (entropy diversification):
   IF H(D) < 2.5 AND high_mass_classes ≥ 3
   THEN serialize_merge_order BY RPN DESC

R9 (safety floor):
   IF DSI < 0.7
   THEN escalate_to_P0 AND require_human_intent_protection
```

### 3.3 Rule evaluation outcome (current state)
- All of `R1..R8` fire.  
- `R9` fires (DSI 0.694 < 0.7).  
- Required action set:
  - block direct mainline merges
  - open 4 multiverse streams
  - quarantine runtime state
  - require migration ledger for `.gemini/*/*` cleanup
  - serialize merges by RPN descending

---

## 4. Ruliological analysis (rule-system evolutionary view)

### 4.1 State automaton
States: `S = {Drifted, Stratified, Multiversed, Gated, Mainlined, Quarantined}`
Transitions:
- `Drifted → Stratified` (apply categorization)
- `Stratified → Multiversed` (split into worktree streams)
- `Multiversed → Gated` (run safety/build/test gates)
- `Gated → Mainlined` (ff-only merge if green)
- `Gated → Quarantined` (if any gate red)
- `Quarantined → Multiversed` (after fix iteration)

### 4.2 Update rule (per stream `s`)
```
next(s) =
  if not gates(s): Quarantined
  else if rpn(s) ≥ 200: Multiversed → Gated → Mainlined (sequential)
  else: Multiversed → Gated → Mainlined (parallel safe)
```

### 4.3 Convergence condition
A converged trajectory satisfies:
- `∀ s: gates(s) = green`
- `∀ s: ledger(s) recorded`
- `∀ s: ff-only merged into main`
- `H(D_post) ≈ 0` (residual drift = 0 except policy-pinned items)
- `DSI_post ≥ 0.85`

### 4.4 Lyapunov-style drift score
`L(t) = α·CSI(t) + β·(1 - DSI(t))`, α=0.6, β=0.4
- Current `L = 0.6·0.497 + 0.4·(1 - 0.694) = 0.298 + 0.122 = 0.420`
- Target `L_⋆ ≤ 0.15` for clean steady-state mainline.

---

## 5. Biomorphic Evolutionary Plan with Multiverse pre-merge

### 5.1 L0 Constitutional
- Adopt SC-DRIFT-001..008.
- Enforce no direct mainline edits for cleanup; only ff-only merges from multiverse.

### 5.2 L1 Sensory (continuous telemetry)
- Capture drift census every action:
  - `git status --porcelain | wc -l`
  - per-category counters
  - binary footprint
- Persist `docs/analysis/root-drift-ledger-<TS>.txt`.

### 5.3 L2 Immune (classification + quarantine)
- Auto-classify into 4 streams:
  - `multiverse/drift-governance`
  - `multiverse/drift-corecode`
  - `multiverse/drift-docs`
  - `multiverse/drift-hygiene` (runtime_state, local_env, dup_nested, binary_media)
- Reject runtime_state into never-commit set.

### 5.4 L3 Metabolic (worktree-based execution)
```bash
git worktree add ../mv-governance -b multiverse/drift-governance main
git worktree add ../mv-corecode   -b multiverse/drift-corecode   main
git worktree add ../mv-docs       -b multiverse/drift-docs       main
git worktree add ../mv-hygiene    -b multiverse/drift-hygiene    main
```

### 5.5 L4 Homeostasis (per-stream gates)
- governance: rules/hooks/skills lint + parity check (.claude vs .gemini)
- corecode: `cd lib/cepaf_gleam && gleam build && gleam test`
- docs: HTML/MD validation + size policy
- hygiene: `.gitignore` and quarantine validation

### 5.6 L5 Cognitive (RPN-ordered merge)
1. governance (RPN 256)
2. corecode (RPN 252)
3. docs (RPN 200)
4. hygiene (RPN < 200)

Merge command pattern:
```bash
git checkout main
git merge --ff-only multiverse/drift-governance
git merge --ff-only multiverse/drift-corecode
git merge --ff-only multiverse/drift-docs
git merge --ff-only multiverse/drift-hygiene
```

### 5.7 L6 Federation
- Verify `.claude` ↔ `.gemini` parity (basename match).
- Verify sub-project pointer aligns with the latest sub-project HEAD on main.

### 5.8 L7 Audit/Evolution
- Generate post-merge audit:
  - `H_before, H_after`
  - `WRPN_before, WRPN_after`
  - `CSI_before, CSI_after`
  - `DSI_before, DSI_after`
- Ingest to ZK with link registry.

---

## 6. Mainline functional invariants (NEVER break)
1. `git checkout main && git pull` → always clean tree.
2. `gleam build && gleam test` in `lib/cepaf_gleam` → green.
3. `cargo build --release` in `sub-projects/c3i/native/planning_daemon` → green.
4. `sa-plan status` → working.
5. No runtime DB/log artifacts on `main`.
6. ff-only merges from verified multiverse branches only.

---

## 7. Convergence & success criteria
- `H(D_post) ≈ 0` modulo intentionally-tracked policy paths
- `DSI_post ≥ 0.85`
- `CSI_post ≤ 0.15`
- `L_post ≤ 0.15`
- Zero entries in `runtime_state` and `binary_media` waiting on mainline
- `.gemini/*/agents` and `.gemini/*/rules` no longer have `*/agents/agents` or `*/rules/rules` artifacts
- Submodule pointer verified against sub-project HEAD

---

## 8. Immediate operational steps (this pass)
1. Create the 4 multiverse worktrees.
2. Move per-category drift into respective worktrees with `git checkout -b` then `git add -p`/restore.
3. Execute per-stream safety gates.
4. Merge ff-only into `main` in RPN-descending order.
5. Re-measure `(H, MLI, DRI, BMR, WCI, CSI, DSI, L)` and publish post-merge audit.
6. Update `.gitignore` to prevent regressions for runtime/local-env classes.
