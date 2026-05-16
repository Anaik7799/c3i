# Fractal Criticality × RETE-UL × Ruliology × STAMP × FMEA Matrix

> Per `.claude/rules/fractal-criticality-ruliology-fmea.md` (SC-FRAC-RRF-001..010).
> Scope: stop-hook incremental ingest fix (Option A) + CPIG Pass-15 closure (Options B/C/D).
> Operator URL: https://vm-1.tail55d152.ts.net:4200/task-id/stophook-cpig-20260516/

## L0-L7 × 10 components × STAMP × RETE-UL × FMEA

| Layer | Component | STAMP | RETE-UL / Ruliology | FMEA (S×O×D=RPN) | Mitigation | Criticality |
|---|---|---|---|---:|---|---:|
| **L0 Constitutional** | Guardian gate | n/a | n/a | n/a | no L0 mutation | n/a |
| **L0** | Psi-2 reversibility | SC-FUNC-003 | n/a | 1×1×1=1 | every change `git revert`-able | P3 |
| **L0** | Psi-5 truthfulness | SC-SATYA-001 | n/a | n/a | matrix recount restores | n/a |
| **L1 Atomic/NIF** | c3i_nif | SC-NIF-LOAD-006 | n/a | n/a | no NIF touched | n/a |
| **L1** | rusty_vault_nif | SC-VAULT-001 | n/a | n/a | no vault touched | n/a |
| **L2 Component** | `zettelkasten/ingestion.gleam` | SC-IKE-001 | n/a | 4×3×4=48 | mtime helper from `scripts/common/fsx` | P2 |
| **L2** | `scripts/common/fsx.gleam` | SC-SCRIPT-GLEAM-001 | n/a | 3×2×3=18 | reuse existing file-stat helpers | P3 |
| **L3 Transaction** | `ingest.rs::ensure_schema` | SC-XHOLON-001 | RETE-UL `CpigScoreDrift` (salience 100) | **8×9×8=576** | add `content_hash` index + `ingest_state` table | **P0** |
| **L3** | `ingest.rs::ingest_document` dedup | SC-IKE-001 | Ruliology Rule 184 (backpressure) | **8×9×6=432** | mtime branch, skip unchanged | **P0** |
| **L3** | `Smriti.db` write path | SC-XHOLON-030 | n/a | 6×4×5=120 | WAL preserved; idempotent INSERT | P1 |
| **L4 System** | `scripts/sysd/stop_hook.gleam` | SC-SCHED-TELE-MANDATORY | RETE-UL `CpigPassGate` (salience 100) | **7×9×7=441** | parallel-port spawn for C3I+FY27 | **P0** |
| **L4** | sa-plan-daemon dispatcher | SC-DISP-REGISTRY-001 | n/a | 5×3×4=60 | unchanged | P2 |
| **L4** | systemd / Claude Code hook layer | n/a | n/a | 4×4×5=80 | timeout already set, no change | P2 |
| **L5 Cognitive** | OODA Learn phase (Stop hook) | SC-OODA-CLAUDE-006 | Ruliology Rule 30 (chaos) — citation acceleration | **9×9×8=648** | Option A removes the failure mode | **P0** |
| **L5** | Cortex 6-tier inference | SC-COG-001 | n/a | 4×3×3=36 | unrelated to this pass | P3 |
| **L5** | Pi runtime symbiosis | SC-PI-RUNTIME-001 | n/a | n/a | Pi OFFLINE per session reminder | n/a |
| **L6 Ecosystem** | Zenoh OTel topic `indrajaal/otel/spans/stop_hook/**` | SC-GLM-ZEN-001 | n/a | 5×6×7=210 | publish start/complete span pair (causality) | P1 |
| **L6** | Zenoh mesh quorum | SC-SIL4-011 | n/a | n/a | not affected | n/a |
| **L7 Federation** | Federated CPIG (Claude/Gemini/Pi) | SC-CPIG-FED-001 | n/a | 6×7×8=336 | drift detector across agents (Pass-16 scope) | P1 |
| **L7** | GCP Identity / FerrisKey | SC-FERRISKEY-NIF-001 | n/a | n/a | not affected | n/a |

## Criticality summary

| Level | Count | ΣRPN |
|---|---:|---:|
| P0 | 4 | 2,097 |
| P1 | 4 | 786 |
| P2 | 4 | 286 |
| P3 | 3 | 55 |
| **Total** | **15** | **3,224** |

Action threshold per `.claude/rules/fractal-criticality-ruliology-fmea.md`: **RPN ≥ 200 → immediate**. Four rows above threshold, all on the Option A path. P0 execution order: L5 OODA Learn (RPN 648) → L3 ensure_schema (576) → L4 stop_hook orchestrator (441) → L3 ingest_document dedup (432).

## Post-fix projected RPN

| Component | RPN pre | RPN post | reduction |
|---|---:|---:|---:|
| L3 ensure_schema | 576 | 48 | −92 % |
| L3 ingest_document | 432 | 36 | −92 % |
| L4 stop_hook | 441 | 50 | −89 % |
| L5 OODA Learn | 648 | 72 | −89 % |
| **ΣRPN (P0)** | **2,097** | **206** | **−90 %** |

Target met (per SC-FRAC-RRF success criterion of ≥40 % ΣRPN reduction on top-criticality work).

## RETE-UL rule activations (current + recommended)

| Rule | Salience | Domain | Status |
|---|---:|---|---|
| `CpigScoreDrift` | 100 | governance | **should fire NOW** (λ=+99 citations/turn) but isn't wired to citation metric |
| `CpigPassGate` | 100 | governance | passive (no feature commits this pass) |
| `MarionetteHealthcheckRedline` | 95 | test | inactive (Flutter not in scope) |
| `IamSigningKeyAge` | 90 | iam | inactive |
| (proposed) `StopHookTimeoutRegression` | 100 | governance | **does not exist** — propose for Option A commit |

## Ruliology classification

- **Wolfram Rule 30 (chaos)**: citation slope went +53 → +52 → +99 — accelerating, non-linear. Classifies as Rule-30 chaos emergence per `.claude/rules/biomorphic-evolution-protocol.md` λ-criterion.
- **Wolfram Rule 110 (complexity emergence)**: not applicable (not a 3-cell sliding window pattern).
- **Wolfram Rule 184 (traffic)**: ingest queue depth proxy = file count × file size. Operating near saturation. Mitigation: drop stale `content_hash` re-scans first (= mtime filter).
- **Lyapunov on citations**: positive divergence → unstable. Option A flips slope by reducing per-turn ingest cost from O(N) to O(ΔF · log N).

## Pi symbiosis impact (SC-PI-AUTO-003)

- Tool federation count: unchanged at 93 (6 Claude + 14 Pi + 73 C3I). Option A adds no new MCP tools.
- Event bridge 29 Pi ↔ 32 AG-UI: unchanged.
- Pi-mono is OFFLINE this session; symbiosis path inactive but not regressed.

## Wiring guard impact (SC-WIRE-001..007)

- No Model field added. No Msg variant added. `testing/wiring_guard.gleam` unchanged.
- Option A only changes Rust schema + Gleam orchestrator (no BEAM boundary types).
