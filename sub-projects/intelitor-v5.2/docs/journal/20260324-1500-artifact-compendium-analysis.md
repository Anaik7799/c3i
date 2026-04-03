# Artifact Compendium Analysis & Criticality-Based Recreation Plan

**Date**: 2026-03-25 15:00 CEST
**Author**: Claude Opus 4.6 (Cybernetic Architect)
**Context**: Recovery from Phase 1 deletion incident — ~30 untracked files lost
**Source**: `docs/journal/20260325-1200-artifact-compendium-for-recreation.md` (Gemini)
**Branch**: `multiverse/claude-opus-fractal-tests` (738 ahead of main)

---

## 1. Executive Summary

On 2026-03-25, Phase 1 of the recovery plan discarded ~30 untracked files via `git checkout --` and manual `rm`. These files were never committed to git and are not recoverable from version control. This analysis cross-references Gemini's artifact compendium (13 items) with the full deletion list (~30 items) to produce a criticality-ranked recreation plan.

**Key findings**:
- 5 of 13 compendium artifacts are SAFE (committed to git, still present)
- 4 of 13 compendium artifacts were ALREADY RECREATED from CLAUDE.md specs
- 4 of 13 compendium artifacts are GONE and need evaluation
- 15 additional deleted items not in the compendium are all GONE
- 5 items are classified DANGEROUS and MUST NOT be recreated

---

## 2. Complete Artifact Status Table

### 2.1 Compendium Artifacts (13 items from Gemini's list)

| # | Artifact | Status | In Git? | Action |
|---|----------|--------|---------|--------|
| 1 | `docs/OPERATING_INSTRUCTIONS_SIL6.md` | EXISTS | Committed | SAFE — no action |
| 2 | `docs/architecture/NIF_STABILITY_FRAMEWORK.md` | EXISTS | Committed | SAFE — no action |
| 3 | `docs/architecture/AUTONOMIC_DRIFT_CONTROL.md` | GONE | Never committed | P2 — recreate from CLAUDE.md §113.0 |
| 4 | `docs/safety/BICAMERAL_RELEASE_PROTOCOL.md` | GONE | Never committed | P2 — recreate from CLAUDE.md §114.0 |
| 5 | `lib/indrajaal/native/zenoh.ex` | EXISTS (different) | Committed | SAFE — existing NIF wrapper is correct; compendium's "Substrate Safety Proxy" variant is DANGEROUS |
| 6 | `lib/indrajaal/cortex/drift_monitor.ex` | EXISTS | UNTRACKED | RECREATED — needs commit |
| 7 | `lib/indrajaal/safety/consensus_aggregator.ex` | EXISTS | UNTRACKED | RECREATED — needs commit |
| 8 | `lib/cepaf/src/Cepaf.Planning/EvolutionObservability.fs` | GONE | Never committed | P2 — recreate from CLAUDE.md §112.0 |
| 9 | `scripts/automation/sil6_autonomous_evolution.exs` | GONE | Never committed | DANGEROUS — do NOT recreate |
| 10 | `test/indrajaal/native/nif_stability_test.exs` | EXISTS | Committed | SAFE — no action |
| 11 | `test/indrajaal_web/live/prajna_gui_test.exs` | EXISTS | UNTRACKED | Needs commit (F# Canopy GUI test) |
| 12 | `docs/credentials_audit_report.md` | GONE | Never committed | DANGEROUS — do NOT recreate |
| 13 | `docs/STATE_RECREATION_INSTRUCTIONS.md` | EXISTS | Committed | SAFE — no action |

### 2.2 Additional Deleted Items (not in compendium, all GONE)

| # | Artifact | Category | Action |
|---|----------|----------|--------|
| 14 | `docs/architecture/EVOLUTIONARY_GOAL_VECTORS.md` | Architecture doc | P3 — content in CLAUDE.md §110.0 |
| 15 | `docs/architecture/EXISTENTIAL_MANDATE_HYBRID_INTELLIGENCE.md` | Architecture doc | P3 — speculative, low value |
| 16 | `docs/architecture/FRACTAL_EVOLUTION_OBSERVABILITY.md` | Architecture doc | P3 — content in CLAUDE.md §112.0 |
| 17 | `docs/architecture/MOJO_MAX_HYBRID_IMPLEMENTATION_SPEC.md` | Architecture doc | DANGEROUS — no Mojo infrastructure |
| 18 | `lib/cepaf/src/Cepaf.Evolution.Monitor/` | F# project | DANGEROUS — caused 654 empty commits |
| 19 | `lib/cepaf/src/Cepaf.Metabolic/` | F# project | P3 — incomplete, no callers |
| 20 | `lib/cepaf/src/Cepaf.Sentinel.MCP/Tools/EvolutionTools.fs` | F# MCP tool | P2 — recreatable from MCP pattern |
| 21 | `lib/cepaf/src/Cepaf.Sentinel.MCP/Tools/MetabolicTools.fs` | F# MCP tool | P3 — depends on Cepaf.Metabolic |
| 22 | `lib/mojo_compute/` | Mojo stubs | DANGEROUS — no infrastructure |
| 23 | `lib/ollama/` | Ollama stubs | DANGEROUS — no infrastructure |
| 24 | `lib/cepaf/src/Cepaf.Planning/EvolutionObservability.fs` | F# bridge | P2 — see item #8 |
| 25 | `lib/cepaf/test/Cepaf.Tests/GuiFeedbackTests.fs` | F# test | P3 — GUI test without UI |
| 26 | `scripts/testing/run_gui_feedback_tests.fsx` | F# script | P3 — depends on GUI tests |
| 27 | `lib/indrajaal/cortex/semantic_router.ex` | Elixir module | RECREATED — needs commit |
| 28 | `lib/indrajaal/safety/consensus_integrity.ex` | Elixir module | RECREATED — needs commit |

### 2.3 Journal & Documentation Files (GONE, not individually critical)

These journal files from 2026-03-25 were all untracked and lost. They document the day's evolution session but are not code-critical:

- `docs/journal/20260325-0900-nif-stability-framework-integration.md`
- `docs/journal/20260325-0930-production-hardening-roadmap.md`
- `docs/journal/20260325-1000-sentinel-alignment-and-yolo.md`
- `docs/journal/20260325-1015-evolution-rate-increase.md`
- `docs/journal/20260325-1020-sil6-full-spectrum-integrity-audit.md`
- `docs/journal/20260325-1030-fractal-evolution-observability.md`
- `docs/journal/20260325-1100-final-ga-readiness-audit.md`
- `docs/journal/20260325-1115-ui-ux-readiness-audit.md`
- `docs/journal/20260325-1316-evolution-burst-detected.md`
- `docs/journal/20260325-1317-immune-response-escalation.md`
- `docs/journal/20260325-1317-morphogenic-saturation-warning.md`
- `docs/journal/20260325-1318-direct-immune-intervention.md`
- `docs/journal/20260325-1319-mcp-native-halt.md`
- `docs/journal/20260325-1320-hydra-scheduler-throttling.md`
- `docs/journal/20260325-1345-aar-morphogenic-overload.md`
- `docs/journal/20260325-1400-homeostasis-setup-ops-manual.md`
- `docs/journal/20260325-1415-metabolic-reporting-loop.md`
- `docs/journal/20260325-1445-substrate-native-intelligence-evaluation.md`
- `docs/journal/20260325-1500-survival-mandate-cognitive-sovereignty.md`
- `docs/journal/20260325-1530-existential-pivot-hybrid-intelligence.md`
- `docs/journal/20260325-1630-session-synthesis.md`
- `docs/journal/20260325-1645-symbiotic-dual-mode-fine-tuning.md`

**Action**: P3 — these are historical records. If ingested into SMRITI before deletion, they may be recoverable from the knowledge database. Otherwise, they are permanently lost narrative context.

---

## 3. DANGEROUS Functionality — MUST NOT Recreate

### 3.1 `scripts/automation/sil6_autonomous_evolution.exs`
**Why dangerous**: This is the autonomous evolution orchestrator that caused the morphogenic overload incident (documented in `20260325-1345-aar-morphogenic-overload.md`). It:
- Runs 50-task batches without human oversight
- Auto-discovers, claims, fixes, and merges tasks
- Generated 654 empty "Auto-release: SIL6-EVO-*" commits
- Caused system instability requiring emergency intervention
- Violates SC-GIT-006 (Guardian merge approval)

**Alternative**: If evolution automation is needed in the future, implement with:
- Maximum 5-task batches (not 50)
- Mandatory human approval gate before merge
- DriftMonitor integration (SC-DRIFT-002: halt if D_KL >= 0.05)
- Rate limiting: max 1 evolution cycle per 5 minutes

### 3.2 `docs/credentials_audit_report.md`
**Why dangerous**: Contains plaintext credentials for postgres and indrajaal_dev databases. Violates:
- SC-SEC-047 (Encryption)
- OWASP credential exposure guidelines
- GDPR data protection requirements

**Alternative**: Store credentials in environment variables or a secrets manager, never in markdown files.

### 3.3 `lib/mojo_compute/` and Mojo Integration
**Why dangerous**: No Mojo infrastructure exists. The deleted compose files specified a 16GB RAM container (`indrajaal-mojo`) with no actual implementation. This is pure infrastructure bloat.

**When to revisit**: Only when Mojo SDK is installed, a real compute kernel exists, and benchmarks show a concrete performance advantage over Nx/EXLA.

### 3.4 `lib/ollama/` and Local LLM Integration
**Why dangerous**: Incomplete stubs with no integration points. Adds dead code and unused dependencies.

**When to revisit**: When a concrete use case requires local LLM inference (not through OpenRouter/Cortex).

### 3.5 `lib/cepaf/src/Cepaf.Evolution.Monitor/`
**Why dangerous**: This F# project was responsible for the auto-release heartbeat system that generated 654 empty commits polluting git history. Its monitoring pattern is useful but the implementation was flawed.

**Alternative**: Evolution monitoring should be handled by the existing `DriftMonitor.ex` (Elixir) and `MathematicalSystemMonitor.fs` (F#), both of which already exist and are tested.

### 3.6 `lib/indrajaal/native/zenoh.ex` — "Substrate Safety Proxy" Variant
**Why dangerous**: The compendium describes wrapping ALL NIF publish calls in a ProofToken verification layer. This would:
- Add latency to every Zenoh publish (violating SC-ZENOH-004: < 100ms)
- Break real-time telemetry (SC-BRIDGE-003: 50ms budget)
- Create a single point of failure in the NIF layer

**The existing `lib/indrajaal/native/zenoh.ex`** is the correct Rustler NIF wrapper and MUST NOT be replaced with this proxy variant.

---

## 4. Criticality-Based Recreation Plan

### P0 — CRITICAL (Commit existing recreated modules)

These modules already exist as untracked files and MUST be committed:

| Module | Source | Lines | Status |
|--------|--------|-------|--------|
| `lib/indrajaal/cortex/drift_monitor.ex` | CLAUDE.md §113.0 | ~190 | Recreated, compiles, needs commit |
| `lib/indrajaal/safety/consensus_aggregator.ex` | CLAUDE.md §114.0 | ~200 | Recreated, compiles, needs commit |
| `lib/indrajaal/safety/consensus_integrity.ex` | CLAUDE.md §111.0 | ~300 | Recreated, compiles, needs commit |
| `lib/indrajaal/cortex/semantic_router.ex` | Cortex architecture | ~246 | Recreated, compiles, needs commit |

**Action**: Commit all 4 modules in a single commit.

### P1 — HIGH (Supervisor Wiring)

These modules need to be wired into the OTP supervisor tree. **Requires manual approval** as it changes runtime behavior:

| Change | File | Risk |
|--------|------|------|
| Add DriftMonitor to Cortex supervisor | `lib/indrajaal/cortex/supervisor.ex` | MEDIUM — new GenServer in hot path |
| Add SemanticRouter to Cortex supervisor | `lib/indrajaal/cortex/supervisor.ex` | LOW — stateless routing |
| Add ConsensusAggregator to Safety supervisor | `lib/indrajaal/safety/supervisor.ex` | MEDIUM — touches safety system |

**Note**: ConsensusIntegrity is a stateless module with ETS backing — it initializes via `init/0` call, not via supervisor child spec.

### P2 — MEDIUM (Documentation & F# Recreation)

| Item | Recreation Source | Effort |
|------|-------------------|--------|
| `docs/architecture/AUTONOMIC_DRIFT_CONTROL.md` | CLAUDE.md §113.0 + DriftMonitor source | ~1 hour |
| `docs/safety/BICAMERAL_RELEASE_PROTOCOL.md` | CLAUDE.md §114.0 + ConsensusAggregator source | ~1 hour |
| `lib/cepaf/src/Cepaf.Planning/EvolutionObservability.fs` | CLAUDE.md §112.0 + existing MathematicalSystemMonitor.fs patterns | ~2 hours |
| `lib/cepaf/src/Cepaf.Sentinel.MCP/Tools/EvolutionTools.fs` | Existing MCP tool pattern in Cepaf.Sentinel.MCP | ~1 hour |

### P3 — LOW (Nice-to-have, defer to future sprint)

| Item | Notes |
|------|-------|
| `docs/architecture/EVOLUTIONARY_GOAL_VECTORS.md` | Content exists in CLAUDE.md §110.0 |
| `docs/architecture/FRACTAL_EVOLUTION_OBSERVABILITY.md` | Content exists in CLAUDE.md §112.0 |
| `lib/cepaf/src/Cepaf.Metabolic/` | Incomplete, no callers |
| `lib/cepaf/src/Cepaf.Sentinel.MCP/Tools/MetabolicTools.fs` | Depends on Cepaf.Metabolic |
| `lib/cepaf/test/Cepaf.Tests/GuiFeedbackTests.fs` | GUI test without UI framework |
| `scripts/testing/run_gui_feedback_tests.fsx` | Depends on GUI tests |
| 22 journal files | Historical narrative, not code-critical |

---

## 5. SMRITI Ingestion Note

**User directive (stated 3 times)**: All journal files, .md files, and system docs must be loaded into SMRITI dual-store (SQLite + DuckDB) to prevent future data loss incidents like this one.

If the 22 deleted journal files had been ingested into SMRITI before the Phase 1 deletion, they would be recoverable from the database. This underscores the urgency of implementing the SMRITI ingestion pipeline.

**Existing ingestion tools**: `scripts/kms/` contains 5 ingestion scripts. The pipeline pattern is: Content -> Gatekeeper -> Extractor -> Curator -> Storage.

---

## 6. Prevention Measures Implemented

1. **SC-DELETE-001 to SC-DELETE-007**: Deletion safeguard protocol created in `.claude/rules/deletion-safeguard.md`
2. **AOR-DELETE-001 to AOR-DELETE-007**: Agent operating rules requiring backup before deletion
3. **Recovery plan Phase 6**: Evolution HOLD — no new morphogenic tasks
4. **SMRITI mandate**: All agents must consult SMRITI before proceeding (feedback memory saved)

---

## 7. Verification Checklist

- [x] All 13 compendium artifacts status-checked
- [x] All 15 additional deleted items status-checked
- [x] 22 journal files catalogued
- [x] 5 DANGEROUS items identified with rationale
- [x] 4 modules already recreated from CLAUDE.md specs
- [x] P0-P3 recreation plan created
- [ ] P0 modules committed to git
- [ ] P1 supervisor wiring (requires approval)
- [ ] P2 documentation recreation
- [ ] SMRITI ingestion pipeline implemented
