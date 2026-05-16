# Execution Plan — Stop-hook fix + CPIG Pass-15 closure

> Operator URL: https://vm-1.tail55d152.ts.net:4200/task-id/stophook-cpig-20260516/
> Plan author: Claude Opus 4.7 · 2026-05-16 07:29 UTC
> ZK: [zk-07a7b11c0c967be4] pass5-auto pattern · [zk-36207658083c03b2] email-attachment rule · [zk-a8c972e82774fae8] fractal-autopilot

This plan codifies the next-session work proposed in `journal.md` §5 with concrete
commits, verification steps, sa-plan task IDs, and rollback paths. Honoring SC-CHG-INLINE
(one logical change per commit) and SC-DISP-REGISTRY parity (Wiring-Guard analogue).

---

## Phase 0 — This session (DONE this pass)

| Step | Action | Status |
|---|---|:---:|
| 0.1 | Plan-mode investigation × 3 Explore agents | ✓ |
| 0.2 | Mechanical Smriti.db verification (37,828 holons, no `content_hash` idx) | ✓ |
| 0.3 | CPIG matrix recount (62→60/65) | ✓ |
| 0.4 | Build 7-artefact deliverable pack under `docs/journal/stophook-cpig-20260516/` | ✓ |
| 0.5 | Send email closure (this turn) | ⏳ executing |
| 0.6 | Open sa-plan tasks for Options A/E/B/C/D (this turn) | ⏳ executing |
| 0.7 | `sa-plan-daemon ingest-docs` to register this pack in ZK (this turn) | ⏳ executing (with timeout risk) |

---

## Phase A — Stop-hook incremental ingest (P0, ~2-3h, NEXT SESSION)

**Goal**: hook warm-run < 5s, no more `STOP-HOOK ✗ TIMEOUT` reminders.
**Layer**: L2-L3 only · **Risk**: LOW · **Reversibility**: full `git revert`

### A.1 — Add `content_hash` index + `ingest_state` table

**File**: `sub-projects/c3i/native/planning_daemon/src/ingest.rs::ensure_schema`

```rust
// Add after existing CREATE TABLE holons block:
CREATE INDEX IF NOT EXISTS idx_holons_content_hash ON holons(content_hash);
CREATE TABLE IF NOT EXISTS ingest_state (
    path        TEXT PRIMARY KEY,
    mtime_unix  INTEGER NOT NULL,
    sha256      TEXT NOT NULL,
    ingested_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_ingest_state_mtime ON ingest_state(mtime_unix);
```

**Verification**:

```bash
sqlite3 sub-projects/c3i/data/kms/smriti.db \
  "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='holons';"
# expect: idx_holons_cluster, idx_holons_level, idx_holons_entropy,
#         idx_holons_updated, idx_holons_content_hash  ← new

EXPLAIN QUERY PLAN
  SELECT content_hash FROM holons WHERE content_hash = 'abc';
# expect: SEARCH holons USING INDEX idx_holons_content_hash (content_hash=?)
# NOT: SCAN holons
```

**Commit message** (ICP v2.0):

```
perf(plan,smriti): index content_hash + add ingest_state — stop-hook 50s→<5s

WHY: ingest.rs:192 dedup queries unindexed column on 272 MB DB → 4× session timeouts
WHAT: btree index + mtime/sha state table for incremental scan

Layer: L3-SYSTEM(2)
STAMP: SC-XHOLON-001, SC-IKE-001, SC-CPIG-014
Task: <A.1 task id>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

### A.2 — mtime branch in `cmd_ingest_docs`

**File**: `sub-projects/c3i/native/planning_daemon/src/ingest.rs::cmd_ingest_docs`

Add per-file check before `read_to_string`:

```rust
let mtime_now = entry.metadata()?.modified()?.duration_since(UNIX_EPOCH)?.as_secs() as i64;
let cached: Option<i64> = conn.query_row(
    "SELECT mtime_unix FROM ingest_state WHERE path = ?1",
    params![&path_str], |r| r.get(0)).ok();
if cached == Some(mtime_now) {
    total_skipped += 1;
    continue;  // unchanged file, skip read+hash+ingest
}
// existing read + ingest logic
// AFTER successful ingest:
conn.execute("INSERT OR REPLACE INTO ingest_state(path, mtime_unix, sha256, ingested_at)
              VALUES(?1, ?2, ?3, datetime('now'))",
              params![&path_str, mtime_now, &hash])?;
```

**Property test** (`sub-projects/c3i/native/planning_daemon/tests/ingest_incremental.rs`):

```rust
#[test]
fn unchanged_files_are_skipped() {
    // 1. ingest 10 fixture files
    // 2. snapshot count
    // 3. ingest again with NO mtime changes
    // 4. assert: 0 new holons, 10 skipped, 0 INSERTs to holons table
}

#[test]
fn one_touched_file_is_reingested() {
    // 1. ingest 10 fixture files
    // 2. touch 1 file (mtime change but content same)
    // 3. ingest
    // 4. assert: 0 new holons (content hash dedup), 1 mtime update
}
```

### A.3 — Parallel C3I + FY27 spawn in `stop_hook.gleam`

**File**: `sub-projects/scripts-gleam/src/scripts/sysd/stop_hook.gleam`

Replace lines 80-84 (sequential calls) with parallel-spawn pattern using existing
`scripts_sh_ffi` helper:

```gleam
// 2+3. C3I-ZK + FY27-ZK ingest IN PARALLEL
// Each call runs in its own erlang port; main process awaits both.
let pid_c3i  = sh_async_in(cl(sa_plan), cls(["ingest-docs"]), cl(repo_root))
let pid_fy27 = sh_async_in(cl(fy27_zk), cls(["import", ".."]), cl(fy27_zk_dir))
let _ = await_pid(pid_c3i, 45_000)
let _ = await_pid(pid_fy27, 45_000)
```

(May require adding `sh_async_in` + `await_pid` to `scripts_sh_ffi.erl` — keep
Gleam-only-scripting mandate SC-SCRIPT-GLEAM-001.)

### A.4 — Verification (E2E)

```bash
# baseline
time /home/an/dev/ver/c3i/sub-projects/c3i/target/release/sa-plan-daemon ingest-docs
# expect: warm-run < 5s after A.1+A.2 land

# Stop-hook live test
touch lib/cepaf_gleam/test/_dummy.gleam     # 1-file change
# trigger Claude Stop hook (end session)
# expect: STOP-HOOK ✓ (no TIMEOUT), citations growth ≤ +5
```

### A.5 — Sentinel rule

Add to `sub-projects/c3i/native/planning_daemon/src/rule_engine.rs` (RETE-UL):

```grl
rule "StopHookTimeoutRegression" salience 100 {
  when StopHookMetrics.consecutive_timeouts >= 1
  then Decision = "P0Task";
       Reason = "SC-CPIG-014 violation; stop_hook exceeded 50s budget";
       OpenTask = "stop-hook-incremental-ingest-followup";
}
```

---

## Phase E — CPIG matrix recount (P1, ~10 min, INDEPENDENT)

**Goal**: matrix honesty restored.

**File**: `docs/journal/task-116480247290237220/cpig-matrix.json`

Edits:
- `subsystems[].id="fractal-widgets-l0-l7"`.gates.zk_ingestion.score: `1` → `0`
- same.gates.email_closure.score: `1` → `0`
- recompute `system_score_mean`: 62 → 60
- recompute `system_score_pct`: 95.4 → 92.3
- add `pass15_revision.audit_2026_05_16` block with evidence link to
  this journal pack

**Verification**:

```bash
jq '.system_score_mean, .system_score_pct' \
   docs/journal/task-116480247290237220/cpig-matrix.json
# expect: 60, 92.3
```

**Commit message**:

```
docs(plan): cpig matrix recount — fractal G4/G5 score 1→0 per evidence

WHY: SQL query showed 0 holons tagged 'fractal'; matrix score conflicted with evidence string "gap"
WHAT: honest recount, system 62/65→60/65 (95.4%→92.3%)

Layer: L0 governance
STAMP: SC-CPIG-008, SC-SATYA-001 (truthfulness)
Task: <E task id>
```

---

## Phase B — Dart MCP G4 ZK ingest (P2, ~30 min, requires A)

**Source of truth**: `.claude/rules/dart-flutter-ai-mcp.md` lists 16 MCP tools.

**Files**:
1. `docs/journal/task-116480247290237220/dart-mcp-catalog.md` — 16-tool catalog with
   purpose, anti-pattern blocked, layer mapping
2. Run `sa-plan-daemon ingest-docs` (now incremental, fast)
3. Verify: `SELECT COUNT(*) FROM holons WHERE tags LIKE '%dart%' OR tags LIKE '%mcp%'`
   ≥ 16

**Matrix update**: Dart MCP G4 score 0 → 1; system 60/65 → 61/65 (93.8 %).

---

## Phase C — Fractal L0-L7 G4+G5 (P2, ~1.5h, requires A)

**Source**: `lib/cepaf_gleam/src/cepaf_gleam/fractal/l{0..7}_*.gleam` (8 modules, 1,107 LOC).

**Files**:
1. `docs/journal/task-116480247290237220/fractal-widgets-catalog.md` — per-layer widget
   spec + HITL requirement + STAMP refs
2. Re-ingest (catalog enters holons table)
3. Verify: `SELECT COUNT(*) FROM holons WHERE tags LIKE '%fractal%'` ≥ 8

**G5 (email closure)**:

```bash
sa-plan-daemon send-email \
  --to Abhijit.Naik@bountytek.com \
  --subject "CPIG Pass-15 Phase C: Fractal L0-L7 closure" \
  --body "..." \
  -a docs/journal/task-116480247290237220/fractal-widgets-catalog.md \
  -a specs/tla/FractalWidgets.tla \
  -a lib/cepaf_gleam/test/fractal_widgets_wiring_test.gleam
```

**Matrix update**: Fractal G4 + G5: 0 → 1 each; system 61/65 → 63/65 (96.9 %).

---

## Phase D — Cortex 6-tier G4+G5 (P3, ~4h, requires A)

**Source**: `sub-projects/c3i/native/planning_daemon/src/{cortex,mcp_inference}.rs` —
6-tier hedged cascade (Gemini Direct · OpenRouter · mistral.rs gemma4 · Ollama gemma4 ·
Ollama gemma3 · RETE rules · static ack).

**Files**:
1. `docs/journal/task-116480247290237220/cortex-cascade-catalog.md` — per-tier latency
   target, cost, circuit-breaker config, transport
2. Re-ingest
3. G5 email with cortex_cascade_wiring_test.rs as attachment

**Matrix update**: Cortex G4 + G5: 0 → 1 each; system 63/65 → **65/65 (100 %)**.

---

## Phase F — Generalisation (P3, post-Pass-15)

The patterns discovered this pass deserve their own STAMP family:

| Family | Constraint | Detector |
|---|---|---|
| **SC-CPIG-CONSISTENCY** | score ↔ evidence MUST agree | cpig-validator agent |
| **SC-CORPUS-INDEX** | every column queried in hot path MUST have an index when corpus > 10k rows | Gleam guard module |
| **SC-HOOK-LATENCY** | every hook with timeout MUST publish duration metric to Zenoh `indrajaal/l4/hook/{name}/duration` | scheduler telemetry |

Author rules in `.claude/rules/` + `.gemini/rules/` parity per SC-SYNC-DOC-007.

---

## Rollback path

Any phase fails:
- A: `git revert <sha>` removes index + table; ingest reverts to O(N) but otherwise works
- E: `git revert <sha>` restores matrix to claimed scores (less honest, not less safe)
- B/C/D: `sa-plan task ... blocked`; matrix scores remain at pre-phase values
- F: optional, skip if scope explodes

---

## sa-plan tasks created this turn

| ID | Title | Priority | Phase |
|---|---|---|---|
| (assigned by daemon) | stop-hook-incremental-ingest | P0 | A |
| (assigned by daemon) | cpig-matrix-recount-fractal-gates | P1 | E |
| (assigned by daemon) | dart-mcp-g4-zk-ingest | P2 | B |
| (assigned by daemon) | fractal-widgets-g4-g5-closure | P2 | C |
| (assigned by daemon) | cortex-6tier-g4-g5-closure | P3 | D |

---

## Total budget

| Phase | Effort | Cumulative | CPIG outcome |
|---|---:|---:|---|
| A | 2-3h | 3h | (matrix unchanged, hook fixed) |
| E | 10 min | 3.2h | 60/65 (honest) |
| B | 30 min | 3.7h | 61/65 |
| C | 1.5h | 5.2h | 63/65 |
| D | 4h | 9.2h | **65/65 (100 %)** |

Next-session realistic ceiling: A+E+B = 3.7h → CPIG 61/65 (93.8 %) honest baseline.
Full 100 % needs a follow-on session.
