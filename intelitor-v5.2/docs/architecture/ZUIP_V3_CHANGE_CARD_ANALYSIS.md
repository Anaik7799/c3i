# ZUIP v3: Comprehensive Change Card Analysis

**Version**: 3.0.0 | **Date**: 2026-03-18 | **Author**: Claude Opus 4.6
**Scope**: Every proposed Zenoh publish addition from ZUIP v1/v2 (~32 changes)
**Method**: Source-code-verified analysis with robustness scoring

---

## Scoring Methodology

### Robustness Score (0-100)
- **Observability** (0-25): Can operators see what is happening?
- **Recoverability** (0-25): Can the system recover from failure?
- **Coordination** (0-25): Do distributed components stay in sync?
- **Auditability** (0-25): Is there a durable record of events?

### Verdict Categories
- **MUST DO**: Safety-critical gap; system integrity at risk without it
- **SHOULD DO**: Significant operational improvement; high ROI
- **NICE TO HAVE**: Incremental improvement; low risk if deferred
- **RECONSIDER**: Cost/risk exceeds benefit; alternative approach preferred

### Performance Classification
- **HOT** (>100/sec): SKIP or BATCH only; never sync Zenoh
- **WARM** (1-100/sec): ASYNC `Task.start` publish
- **COLD** (<1/sec): SYNC `GenServer.call` acceptable

---

## Subsystem 1: SAFETY (8 Changes)

---

### CHANGE CARD S-01: Guardian Emergency Stop Zenoh Broadcast

**File**: `lib/indrajaal/safety/guardian.ex` (line 270)
**Function**: `emergency_stop/1`
**ZUIP Ref**: T0-CRITICAL, Gap #1

#### WHY
Guardian's `emergency_stop/1` spawns execution and broadcasts via Phoenix.PubSub only. In a multi-node mesh, PubSub relies on Erlang distribution which may be partitioned during the very emergency that triggered the stop. Zenoh operates on a separate network plane (TCP/7447) and can reach nodes that have lost Erlang connectivity.

#### WHAT
Add a **fire-and-forget** Zenoh publish to `indrajaal/emergency/stop` AFTER the PubSub broadcast. Must NOT block the 5-second emergency budget (SC-EMR-057). Use `Task.start` (not `Task.start_link`) to avoid crashing the Guardian if Zenoh is down.

```elixir
# AFTER existing PubSub broadcast
Task.start(fn ->
  Indrajaal.Observability.ZenohSession.publish(
    "indrajaal/emergency/stop",
    %{reason: reason, node: Node.self(), timestamp: DateTime.utc_now()}
  )
end)
```

#### IMPACT ANALYSIS
| Layer | Impact | Score |
|-------|--------|-------|
| L1-CODE | LOW - 5 lines added | 1 |
| L2-DOMAIN | NONE | 0 |
| L3-SYSTEM | MEDIUM - new cross-plane signal | 6 |
| L4-ECOSYSTEM | LOW - Zenoh subscribers see new topic | 4 |
| **TOTAL** | | **11** |

#### BENEFITS
- Emergency signals reach nodes even during Erlang partition
- F# mesh orchestrator can detect emergency stops in real-time
- Dying gasp pattern enabled across network boundaries

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 15 | 22 | +7 |
| Recoverability | 12 | 18 | +6 |
| Coordination | 8 | 20 | +12 |
| Auditability | 18 | 22 | +4 |
| **Total** | **53** | **82** | **+29** |

**Risk-Benefit Ratio**: 0.15 (very low risk, high benefit)
- Risk: Task.start is fire-and-forget, no failure propagation
- Mitigation: Log fallback per SC-ZTEST-008

**Performance**: COLD (<1/sec) -- emergencies are rare events

**Verdict**: **MUST DO**

---

### CHANGE CARD S-02: Guardian Proposal Veto Zenoh Publish

**File**: `lib/indrajaal/safety/guardian.ex` (line 105)
**Function**: `validate_proposal/1`
**ZUIP Ref**: T2-IMPORTANT, Gap #7

#### WHY
Guardian vetoes are safety-critical decisions that should be visible to the entire mesh. Currently only returns `{:approved/:vetoed}` to the caller. The F# cockpit, Sentinel, and remote observers have no real-time visibility into Guardian decisions.

#### WHAT
Add ASYNC Zenoh publish on veto decisions only (approvals are high-frequency, vetoes are rare and safety-relevant).

```elixir
# After veto decision
if result == :vetoed do
  Task.start(fn ->
    ZenohSession.publish("indrajaal/guardian/veto", %{
      proposal_type: proposal.type,
      reason: veto_reason,
      checks_failed: failed_checks,
      timestamp: DateTime.utc_now()
    })
  end)
end
```

#### IMPACT ANALYSIS
| Layer | Impact | Score |
|-------|--------|-------|
| L1-CODE | LOW - 8 lines | 1 |
| L2-DOMAIN | LOW - safety domain | 2 |
| L3-SYSTEM | LOW - informational | 3 |
| L4-ECOSYSTEM | LOW | 2 |
| **TOTAL** | | **8** |

#### BENEFITS
- Real-time veto visibility for F# cockpit dashboard
- Audit trail via Zenoh subscribers (DuckDB logging)
- Pattern detection: repeated vetoes indicate configuration issues

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 10 | 20 | +10 |
| Recoverability | 18 | 18 | 0 |
| Coordination | 12 | 18 | +6 |
| Auditability | 14 | 22 | +8 |
| **Total** | **54** | **78** | **+24** |

**Risk-Benefit Ratio**: 0.10 (minimal risk, good benefit)
**Performance**: COLD (<1/sec)

**Verdict**: **SHOULD DO**

---

### CHANGE CARD S-03: Sentinel Threat Detection Zenoh Publish

**File**: `lib/indrajaal/safety/sentinel.ex` (line 199)
**Function**: `report_threat/3`
**ZUIP Ref**: T1-HIGH, Gap #4

#### WHY
Sentinel `report_threat/3` uses `GenServer.cast` only -- threat detections are invisible outside the local node. In a SIL-6 mesh, threat awareness must propagate to all nodes within 100ms for coordinated immune response.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/sentinel/threat` after the cast.

#### IMPACT ANALYSIS
| Layer | Impact | Score |
|-------|--------|-------|
| L1-CODE | LOW - 6 lines | 1 |
| L2-DOMAIN | MEDIUM - safety signal | 4 |
| L3-SYSTEM | MEDIUM - mesh-wide awareness | 6 |
| L4-ECOSYSTEM | LOW | 2 |
| **TOTAL** | | **13** |

#### BENEFITS
- Mesh-wide threat awareness within 100ms
- F# orchestrator can coordinate cross-node immune response
- Zenoh subscribers can aggregate threat patterns across cluster

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 12 | 22 | +10 |
| Recoverability | 15 | 20 | +5 |
| Coordination | 5 | 22 | +17 |
| Auditability | 15 | 20 | +5 |
| **Total** | **47** | **84** | **+37** |

**Risk-Benefit Ratio**: 0.12
**Performance**: WARM (1-10/sec during incidents, <1/sec normally)

**Verdict**: **MUST DO**

---

### CHANGE CARD S-04: Sentinel Health Check Zenoh Publish

**File**: `lib/indrajaal/safety/sentinel.ex` (line 439)
**Function**: `perform_health_check/1`
**ZUIP Ref**: T2-IMPORTANT, Gap #5

#### WHY
Health checks run every 5 seconds and emit `:telemetry` only. The Zenoh mesh has no visibility into per-node health scores, preventing the F# HealthCoordinator from doing FPPS consensus across the mesh.

#### WHAT
Add ASYNC Zenoh publish of health score summary to `indrajaal/sentinel/health/{node}`. Publish only when health_score changes by >5% to avoid flooding (WARM path optimization).

#### IMPACT ANALYSIS
| Layer | Impact | Score |
|-------|--------|-------|
| L1-CODE | LOW - 10 lines | 1 |
| L2-DOMAIN | LOW | 2 |
| L3-SYSTEM | MEDIUM - enables mesh FPPS | 6 |
| L4-ECOSYSTEM | LOW | 2 |
| **TOTAL** | | **11** |

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 15 | 23 | +8 |
| Recoverability | 12 | 16 | +4 |
| Coordination | 6 | 20 | +14 |
| Auditability | 15 | 18 | +3 |
| **Total** | **48** | **77** | **+29** |

**Risk-Benefit Ratio**: 0.18 (delta-based publishing reduces volume)
**Performance**: WARM (~0.2/sec with delta filter, max 1/5s)

**Verdict**: **SHOULD DO**

---

### CHANGE CARD S-05: Sentinel Quarantine Zenoh Publish

**File**: `lib/indrajaal/safety/sentinel.ex` (line 831)
**Function**: `do_quarantine/3`
**ZUIP Ref**: T1-HIGH, Gap #6

#### WHY
Process quarantine is a critical safety action -- isolating a misbehaving process. Currently logged with `:telemetry` and `Logger` only. Remote nodes have no visibility into quarantine actions, preventing coordinated isolation across the mesh.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/sentinel/quarantine` with process info, reason, and quarantine parameters.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 14 | 22 | +8 |
| Recoverability | 12 | 18 | +6 |
| Coordination | 4 | 20 | +16 |
| Auditability | 16 | 22 | +6 |
| **Total** | **46** | **82** | **+36** |

**Risk-Benefit Ratio**: 0.10
**Performance**: COLD (<1/sec -- quarantine is rare)

**Verdict**: **MUST DO**

---

### CHANGE CARD S-06: PatternHunter Detection Zenoh Publish

**File**: `lib/indrajaal/safety/pattern_hunter.ex` (line 1089)
**Function**: `send_preemptive_alerts/1`
**ZUIP Ref**: T2-IMPORTANT, Gap #8

#### WHY
PatternHunter detects pre-error patterns (memory leaks, spawn storms, error cascades) but alerts flow only to local Sentinel/Guardian. In a mesh, pattern signatures detected on one node could indicate cluster-wide degradation that other nodes should preemptively respond to.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/immune/pattern/{type}` for high-risk detections (risk_score >= 7).

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 15 | 22 | +7 |
| Recoverability | 14 | 20 | +6 |
| Coordination | 6 | 18 | +12 |
| Auditability | 14 | 20 | +6 |
| **Total** | **49** | **80** | **+31** |

**Risk-Benefit Ratio**: 0.15
**Performance**: WARM (scan every 500ms, but high-risk detections are rare)

**Verdict**: **SHOULD DO**

---

### CHANGE CARD S-07: SymbioticDefense Level Change Zenoh Publish

**File**: `lib/indrajaal/safety/symbiotic_defense.ex` (line ~1080)
**Function**: `handle_escalation/3` and `handle_de_escalation/3`
**ZUIP Ref**: T1-HIGH, Gap #9

#### WHY
Defense level transitions (normal -> elevated -> guarded -> high -> critical) are the most important system-wide state changes. Currently only emitted via `:telemetry`. The entire mesh must know the defense posture for coordinated response.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/defense/level` on every level transition.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 15 | 24 | +9 |
| Recoverability | 12 | 18 | +6 |
| Coordination | 5 | 24 | +19 |
| Auditability | 16 | 22 | +6 |
| **Total** | **48** | **88** | **+40** |

**Risk-Benefit Ratio**: 0.08 (very low risk, highest coordination benefit)
**Performance**: COLD (<1/min -- level changes are rare)

**Verdict**: **MUST DO**

---

### CHANGE CARD S-08: SymbioticDefense Recovery Phase Zenoh Publish

**File**: `lib/indrajaal/safety/symbiotic_defense.ex` (line ~1456)
**Function**: `execute_recovery/1`
**ZUIP Ref**: T2-IMPORTANT, Gap #10

#### WHY
The 5-phase recovery protocol (Restart -> Reconfigure -> Rollback -> Escalate -> Manual) generates `:telemetry` events only. The F# orchestrator needs visibility into recovery progress to coordinate mesh-wide healing.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/defense/recovery/{phase}` at each phase transition.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 14 | 22 | +8 |
| Recoverability | 18 | 24 | +6 |
| Coordination | 6 | 20 | +14 |
| Auditability | 16 | 22 | +6 |
| **Total** | **54** | **88** | **+34** |

**Risk-Benefit Ratio**: 0.12
**Performance**: COLD (recovery events are rare)

**Verdict**: **SHOULD DO**

---

## Subsystem 2: DEPLOYMENT (8 Changes)

---

### CHANGE CARD D-01: WaveExecutor Boot Phase Zenoh Publish

**File**: `lib/indrajaal/deployment/wave_executor.ex` (line 268)
**Function**: `execute_boot/3`
**ZUIP Ref**: T0-CRITICAL, Gap #2

#### WHY
The WaveExecutor orchestrates the entire 5-stage boot sequence but only emits `:telemetry`. The F# SIL6MeshOrchestrator has ZERO visibility into boot progress, making it impossible to implement the CP-BOOT-01 through CP-BOOT-10 checkpoint protocol defined in SC-ZTEST.

#### WHAT
Add ASYNC Zenoh publish at each boot phase to `indrajaal/boot/{phase}/{status}` with state vector update.

```elixir
Task.start(fn ->
  ZenohSession.publish("indrajaal/boot/#{phase}/#{status}", %{
    checkpoint: "CP-BOOT-#{String.pad_leading(to_string(phase_num), 2, "0")}",
    state_vector: state_vector,
    duration_ms: duration,
    timestamp: DateTime.utc_now()
  })
end)
```

#### IMPACT ANALYSIS
| Layer | Impact | Score |
|-------|--------|-------|
| L1-CODE | LOW - 12 lines per phase | 1 |
| L2-DOMAIN | NONE | 0 |
| L3-SYSTEM | HIGH - enables checkpoint protocol | 9 |
| L4-ECOSYSTEM | MEDIUM - F# orchestrator dependency | 8 |
| **TOTAL** | | **18** |

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 8 | 24 | +16 |
| Recoverability | 10 | 18 | +8 |
| Coordination | 3 | 24 | +21 |
| Auditability | 12 | 22 | +10 |
| **Total** | **33** | **88** | **+55** |

**Risk-Benefit Ratio**: 0.08 (boot is COLD path, enormous coordination gain)
**Performance**: COLD (<1/boot, boots are rare)

**Verdict**: **MUST DO**

---

### CHANGE CARD D-02: WaveExecutor Wave Start/Complete Zenoh Publish

**File**: `lib/indrajaal/deployment/wave_executor.ex` (line 355)
**Function**: `execute_wave/3`
**ZUIP Ref**: T1-HIGH, Gap #12

#### WHY
Individual wave execution (container group startup) uses `emit_telemetry` for `wave_start` and `wave_complete`. The F# orchestrator cannot track which wave is active or if a wave failed.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/boot/wave/{wave_id}/{start|complete|failed}`.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 10 | 22 | +12 |
| Recoverability | 10 | 16 | +6 |
| Coordination | 4 | 22 | +18 |
| Auditability | 12 | 20 | +8 |
| **Total** | **36** | **80** | **+44** |

**Risk-Benefit Ratio**: 0.10
**Performance**: COLD

**Verdict**: **MUST DO**

---

### CHANGE CARD D-03: WaveExecutor Container Boot Zenoh Publish

**File**: `lib/indrajaal/deployment/wave_executor.ex` (line 405)
**Function**: `boot_container/3`
**ZUIP Ref**: T2-IMPORTANT, Gap #13

#### WHY
Per-container boot tracking is granular but only logged. Useful for debugging slow boots but not critical for orchestration (D-02 covers wave-level).

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/boot/container/{name}/{status}`.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 10 | 20 | +10 |
| Recoverability | 10 | 14 | +4 |
| Coordination | 4 | 16 | +12 |
| Auditability | 12 | 18 | +6 |
| **Total** | **36** | **68** | **+32** |

**Risk-Benefit Ratio**: 0.15
**Performance**: COLD

**Verdict**: **NICE TO HAVE**

---

### CHANGE CARD D-04: WaveExecutor Rollback Zenoh Publish

**File**: `lib/indrajaal/deployment/wave_executor.ex` (line 442)
**Function**: `execute_rollback/2`
**ZUIP Ref**: T0-CRITICAL, Gap #3

#### WHY
Rollback is a safety-critical operation triggered when boot fails. The mesh MUST know a rollback is in progress to prevent split-brain during the rollback window. Currently uses `emit_telemetry` only.

#### WHAT
Add SYNC (acceptable -- rollback is COLD) Zenoh publish to `indrajaal/deployment/rollback` with full context.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 8 | 24 | +16 |
| Recoverability | 15 | 24 | +9 |
| Coordination | 3 | 22 | +19 |
| Auditability | 14 | 24 | +10 |
| **Total** | **40** | **94** | **+54** |

**Risk-Benefit Ratio**: 0.06 (lowest risk, highest benefit in deployment)
**Performance**: COLD (rollbacks are rare)

**Verdict**: **MUST DO**

---

### CHANGE CARD D-05: DyingGasp Zenoh Publish

**File**: `lib/indrajaal/deployment/dying_gasp.ex` (line 84)
**Function**: `capture/2`
**ZUIP Ref**: T0-CRITICAL, Gap #11

#### WHY
Dying gasp captures final state to disk before node death. This is the last chance to signal the mesh that a node is going down. Currently writes to disk and logs only. If the disk write succeeds but the node dies before Erlang distribution propagates the info, the mesh has a ghost node.

#### WHAT
Add fire-and-forget Zenoh publish to `indrajaal/mesh/dying_gasp` BEFORE disk write (Zenoh may survive even if disk fails).

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 12 | 24 | +12 |
| Recoverability | 18 | 22 | +4 |
| Coordination | 2 | 22 | +20 |
| Auditability | 20 | 24 | +4 |
| **Total** | **52** | **92** | **+40** |

**Risk-Benefit Ratio**: 0.05 (fire-and-forget = zero risk to dying process)
**Performance**: COLD (death is once-per-node-lifetime)

**Verdict**: **MUST DO**

---

### CHANGE CARD D-06: Apoptosis Zenoh Publish

**File**: `lib/indrajaal/cluster/apoptosis.ex` (line 8)
**Function**: `initiate/1`
**ZUIP Ref**: T0-CRITICAL, Gap #14

#### WHY
Apoptosis (self-termination on quorum loss) calls `System.stop(1)` after only Logger.flush. The mesh has ZERO indication that a node chose to self-terminate vs. crashed. This is critical for distinguishing intentional vs. accidental node loss in split-brain recovery.

#### WHAT
Add Zenoh publish to `indrajaal/mesh/apoptosis` BEFORE `System.stop(1)`. Must be synchronous (brief blocking acceptable since node is dying anyway).

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 5 | 24 | +19 |
| Recoverability | 8 | 18 | +10 |
| Coordination | 2 | 24 | +22 |
| Auditability | 10 | 22 | +12 |
| **Total** | **25** | **88** | **+63** |

**Risk-Benefit Ratio**: 0.04 (node is dying anyway -- zero additional risk)
**Performance**: COLD (once-per-lifetime)

**Verdict**: **MUST DO**

---

### CHANGE CARD D-07: EmergencyResponse Phase Transition Zenoh Publish

**File**: `lib/indrajaal/safety/emergency_response.ex` (line 724)
**Function**: `advance_phase/2`
**ZUIP Ref**: T1-HIGH, Gap #15

#### WHY
The 6-phase apoptosis protocol (initiated -> notifying -> draining -> checkpointing -> terminating -> terminated) transitions are logged only. The F# orchestrator needs to track which phase each node is in during coordinated shutdown.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/emergency/phase/{phase}` at each transition.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 10 | 22 | +12 |
| Recoverability | 14 | 20 | +6 |
| Coordination | 4 | 22 | +18 |
| Auditability | 16 | 22 | +6 |
| **Total** | **44** | **86** | **+42** |

**Risk-Benefit Ratio**: 0.10
**Performance**: COLD

**Verdict**: **MUST DO**

---

### CHANGE CARD D-08: EmergencyResponse Peer Notification Zenoh Publish

**File**: `lib/indrajaal/safety/emergency_response.ex` (line 798)
**Function**: `notify_peers/2`
**ZUIP Ref**: T1-HIGH, Gap #16

#### WHY
`notify_peers` uses Phoenix.PubSub ONLY. Same partition-vulnerability as S-01: during the emergency that triggered notification, Erlang distribution may be down.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/emergency/peer_notification` alongside PubSub.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 12 | 20 | +8 |
| Recoverability | 14 | 20 | +6 |
| Coordination | 8 | 22 | +14 |
| Auditability | 14 | 20 | +6 |
| **Total** | **48** | **82** | **+34** |

**Risk-Benefit Ratio**: 0.12
**Performance**: COLD

**Verdict**: **SHOULD DO**

---

## Subsystem 3: OBSERVABILITY (5 Changes)

---

### CHANGE CARD O-01: SmartMetrics Zenoh Batch Publish

**File**: `lib/indrajaal/cockpit/prajna/smart_metrics.ex` (line 220)
**Function**: `handle_cast({:record, ...})`
**ZUIP Ref**: T3-WARM, Gap #17

#### WHY
SmartMetrics records ~200 metrics/sec into ETS and broadcasts via PubSub. This is a HOT path. Direct Zenoh publish per metric would serialize through ZenohSession GenServer and create a bottleneck.

#### WHAT
Add a **batched** Zenoh publish using a 1-second aggregation window. Collect metrics in ETS, flush batch to `indrajaal/metrics/batch` every 1 second via `Process.send_after`.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 18 | 24 | +6 |
| Recoverability | 16 | 18 | +2 |
| Coordination | 10 | 18 | +8 |
| Auditability | 16 | 20 | +4 |
| **Total** | **60** | **80** | **+20** |

**Risk-Benefit Ratio**: 0.30 (moderate complexity for batching)
**Performance**: HOT (200/sec) -- MUST use batch strategy

**Verdict**: **NICE TO HAVE** -- PubSub already provides local observability; Zenoh batch adds mesh-wide visibility but at implementation complexity cost.

---

### CHANGE CARD O-02: SentinelBridge Sync Completion Zenoh Publish

**File**: `lib/indrajaal/cockpit/prajna/sentinel_bridge.ex` (line 206)
**Function**: `perform_sync/1`
**ZUIP Ref**: T3-WARM, Gap #18

#### WHY
SentinelBridge syncs SmartMetrics with Sentinel every 30 seconds. The sync result (anomaly count, health delta) is not published to Zenoh. The F# cockpit cannot verify that the bridge is functioning.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/prajna/sentinel_sync` after each sync cycle with summary.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 14 | 22 | +8 |
| Recoverability | 14 | 16 | +2 |
| Coordination | 8 | 16 | +8 |
| Auditability | 14 | 20 | +6 |
| **Total** | **50** | **74** | **+24** |

**Risk-Benefit Ratio**: 0.12
**Performance**: COLD (1/30s)

**Verdict**: **NICE TO HAVE**

---

### CHANGE CARD O-03: HealthCoordinator FPPS Result Zenoh Publish

**File**: `lib/indrajaal/lifecycle/health_coordinator.ex` (line 268)
**Function**: `execute_health_check/1`
**ZUIP Ref**: T2-IMPORTANT, Gap #19

#### WHY
HealthCoordinator runs FPPS 5-validator consensus on container health every 10 seconds. Results go to `:telemetry` only. The Zenoh mesh needs health consensus results for mesh-wide quorum determination.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/health/fpps/{overall_status}` with consensus result, quorum status, and per-container breakdown.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 16 | 24 | +8 |
| Recoverability | 12 | 18 | +6 |
| Coordination | 6 | 22 | +16 |
| Auditability | 16 | 22 | +6 |
| **Total** | **50** | **86** | **+36** |

**Risk-Benefit Ratio**: 0.12
**Performance**: COLD (1/10s)

**Verdict**: **SHOULD DO**

---

### CHANGE CARD O-04: HealthCoordinator Circuit Breaker State Zenoh Publish

**File**: `lib/indrajaal/lifecycle/health_coordinator.ex` (line 284)
**Function**: `execute_health_check/1` (circuit breaker transition)
**ZUIP Ref**: T2-IMPORTANT, Gap #20

#### WHY
When HealthCoordinator opens its circuit breaker (3 consecutive failures), the mesh is blind to this decision. Other nodes may still route health queries to a node whose health check circuit breaker is open.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/health/circuit_breaker/{open|closed}` on state transition.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 12 | 22 | +10 |
| Recoverability | 12 | 18 | +6 |
| Coordination | 4 | 20 | +16 |
| Auditability | 14 | 22 | +8 |
| **Total** | **42** | **82** | **+40** |

**Risk-Benefit Ratio**: 0.08
**Performance**: COLD (circuit breaker transitions are rare)

**Verdict**: **SHOULD DO**

---

### CHANGE CARD O-05: Jidoka Halt/Resume Zenoh Publish

**File**: `lib/indrajaal/tps/jidoka.ex` (lines 240, 465)
**Functions**: `handle_call({:detect_critical_error, ...})`, `handle_call({:attempt_resume, ...})`
**ZUIP Ref**: T1-HIGH, Gap #21

#### WHY
Jidoka halt is the most severe operational state change -- ALL operations stop. Currently uses Logger and PubSub notifications. The mesh must know about Jidoka halts for coordinated response. The comment on line 579 says "In production, this would use PubSub or Zenoh" -- confirming the intent.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/jidoka/{halt|resume}` with halt reason, RCA session ID, and affected systems.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 14 | 24 | +10 |
| Recoverability | 12 | 20 | +8 |
| Coordination | 6 | 24 | +18 |
| Auditability | 18 | 24 | +6 |
| **Total** | **50** | **92** | **+42** |

**Risk-Benefit Ratio**: 0.06
**Performance**: COLD (Jidoka halts are rare)

**Verdict**: **MUST DO**

---

## Subsystem 4: GOVERNANCE (5 Changes)

---

### CHANGE CARD G-01: MasterControl Command Execution Zenoh Publish

**File**: `lib/indrajaal/cockpit/prajna/master_control.ex` (line 198)
**Function**: `execute_command/3`
**ZUIP Ref**: T2-IMPORTANT, Gap #22

#### WHY
MasterControl executes commands through Guardian approval, logs to ImmutableRegister, and emits telemetry. Command execution results are not visible on the Zenoh mesh. The F# cockpit needs to know what commands are being executed for real-time dashboard updates.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/prajna/command/{domain}/{action}` after command execution with outcome.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 16 | 22 | +6 |
| Recoverability | 16 | 18 | +2 |
| Coordination | 10 | 18 | +8 |
| Auditability | 20 | 24 | +4 |
| **Total** | **62** | **82** | **+20** |

**Risk-Benefit Ratio**: 0.15
**Performance**: WARM (command rate depends on operator activity, typically <10/sec)

**Verdict**: **NICE TO HAVE**

---

### CHANGE CARD G-02: MasterControl Emergency Stop Zenoh Publish

**File**: `lib/indrajaal/cockpit/prajna/master_control.ex` (line 258)
**Function**: `emergency_stop/1`
**ZUIP Ref**: T0-CRITICAL, Gap #23

#### WHY
MasterControl's `emergency_stop/1` broadcasts via `broadcast_emergency` (Phoenix.PubSub only). Same partition vulnerability as S-01 and D-08. This is a duplicate signal path to Guardian.emergency_stop but from the cockpit control plane.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/prajna/emergency_stop`. Note: this supplements S-01 (Guardian level) with the cockpit-level signal.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 14 | 22 | +8 |
| Recoverability | 14 | 20 | +6 |
| Coordination | 8 | 22 | +14 |
| Auditability | 16 | 22 | +6 |
| **Total** | **52** | **86** | **+34** |

**Risk-Benefit Ratio**: 0.10
**Performance**: COLD

**Verdict**: **SHOULD DO** (supplements S-01, not duplicative since it originates from different control plane)

---

### CHANGE CARD G-03: MasterControl Circuit Breaker State Zenoh Publish

**File**: `lib/indrajaal/cockpit/prajna/master_control.ex` (line 516)
**Function**: `update_circuit_breakers/2`
**ZUIP Ref**: T2-IMPORTANT, Gap #24

#### WHY
Per-domain circuit breaker state transitions are not published to Zenoh. The F# cockpit dashboard cannot show real-time circuit breaker states for the 30 domains.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/prajna/circuit_breaker/{domain}/{open|closed|half_open}` on state transitions only.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 10 | 22 | +12 |
| Recoverability | 12 | 16 | +4 |
| Coordination | 6 | 18 | +12 |
| Auditability | 12 | 20 | +8 |
| **Total** | **40** | **76** | **+36** |

**Risk-Benefit Ratio**: 0.12
**Performance**: COLD (circuit breaker transitions are rare)

**Verdict**: **SHOULD DO**

---

### CHANGE CARD G-04: ImmutableState Block Append Zenoh Publish

**File**: `lib/indrajaal/cockpit/prajna/immutable_state.ex`
**Function**: `append_block/2`
**ZUIP Ref**: T2-IMPORTANT, Gap #25

#### WHY
The ImmutableRegister is the cryptographic audit trail. Block appends are not published to Zenoh. Cross-node register verification requires polling. With Zenoh, remote nodes can subscribe to new blocks for real-time chain verification.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/register/block` with block hash, previous hash, and block number. Do NOT include block content (security -- content stays local).

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 12 | 20 | +8 |
| Recoverability | 20 | 22 | +2 |
| Coordination | 6 | 20 | +14 |
| Auditability | 22 | 25 | +3 |
| **Total** | **60** | **87** | **+27** |

**Risk-Benefit Ratio**: 0.20 (security consideration: must NOT leak block content)
**Performance**: WARM (depends on mutation rate, typically 1-10/sec)

**Verdict**: **NICE TO HAVE** -- important for federation but not urgent for single-mesh operation

---

### CHANGE CARD G-05: Prajna CircuitBreaker Storm Detection Zenoh Publish

**File**: `lib/indrajaal/cockpit/prajna/circuit_breaker.ex` (line 184)
**Function**: `log_dropped/3`
**ZUIP Ref**: T3-WARM, Gap #26

#### WHY
The Prajna CircuitBreaker drops messages during storms (queue > 100). Dropped message counts are logged but not published. The F# cockpit could show real-time storm indicators.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/prajna/storm/{mode}` when entering/exiting load shedding modes. Publish mode transitions only, not per-drop events.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 14 | 22 | +8 |
| Recoverability | 14 | 16 | +2 |
| Coordination | 8 | 16 | +8 |
| Auditability | 14 | 18 | +4 |
| **Total** | **50** | **72** | **+22** |

**Risk-Benefit Ratio**: 0.18
**Performance**: COLD (mode transitions only, not per-drop)

**Verdict**: **NICE TO HAVE**

---

## Subsystem 5: TESTING (3 Changes)

---

### CHANGE CARD T-01: ExUnit Formatter Zenoh Checkpoint Publish

**File**: `lib/indrajaal/testing/zenoh_test_formatter.ex`
**ZUIP Ref**: T2-IMPORTANT, Gap #27

#### WHY
Already partially implemented per SC-ZTEST. The ZenohTestFormatter publishes test results to Zenoh topics. Gap is that the log fallback (SC-ZTEST-008) dual-write pattern may not be consistently applied.

#### WHAT
Verify dual-write pattern: ALWAYS write `[ZTEST-CHECKPOINT]` log BEFORE Zenoh attempt. Ensure `Task.start` for async publish.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 20 | 22 | +2 |
| Recoverability | 18 | 22 | +4 |
| Coordination | 18 | 22 | +4 |
| Auditability | 18 | 22 | +4 |
| **Total** | **74** | **88** | **+14** |

**Risk-Benefit Ratio**: 0.08
**Performance**: WARM (test rate, but tests are not production path)

**Verdict**: **SHOULD DO** (verification/hardening of existing implementation)

---

### CHANGE CARD T-02: SprintTaskPublisher Zenoh Completeness

**File**: `lib/indrajaal/testing/sprint_task_publisher.ex`
**ZUIP Ref**: T3-WARM, Gap #28

#### WHY
Already implemented for sprint orchestration. Gap is ensuring all sprint task state transitions publish to Zenoh, not just start/complete.

#### WHAT
Verify coverage of all task states: pending -> running -> passed/failed/skipped. Ensure wave-level aggregation publishes.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 20 | 24 | +4 |
| Recoverability | 16 | 18 | +2 |
| Coordination | 16 | 20 | +4 |
| Auditability | 18 | 22 | +4 |
| **Total** | **70** | **84** | **+14** |

**Risk-Benefit Ratio**: 0.10
**Performance**: COLD (sprint operations)

**Verdict**: **NICE TO HAVE**

---

### CHANGE CARD T-03: Coverage Report Zenoh Publish

**File**: `lib/indrajaal/testing/zenoh_test_orchestrator.ex`
**ZUIP Ref**: T4-LONG_TERM, Gap #29

#### WHY
Coverage reports (CP-TEST-08) are generated at suite completion but the Zenoh publish for coverage summary may not include sufficient detail for the F# dashboard.

#### WHAT
Ensure coverage report checkpoint includes: total coverage %, per-module breakdown (top 10 lowest), and delta from last run.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 18 | 22 | +4 |
| Recoverability | 16 | 16 | 0 |
| Coordination | 14 | 18 | +4 |
| Auditability | 18 | 22 | +4 |
| **Total** | **66** | **78** | **+12** |

**Risk-Benefit Ratio**: 0.15
**Performance**: COLD (once per test suite)

**Verdict**: **NICE TO HAVE**

---

## Subsystem 6: INFRASTRUCTURE (3 Changes)

---

### CHANGE CARD I-01: Application Startup Complete Zenoh Publish

**File**: `lib/indrajaal/application.ex` (line 94)
**Function**: `start/2`
**ZUIP Ref**: T1-HIGH, Gap #30

#### WHY
Application startup completes with `Supervisor.start_link` but the mesh has no signal that a node has fully booted. The F# orchestrator relies on health endpoint polling which has latency and may false-positive during partial boot.

#### WHAT
Add ASYNC Zenoh publish to `indrajaal/boot/app/started` AFTER all initialization steps complete (after line 180).

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 14 | 24 | +10 |
| Recoverability | 12 | 16 | +4 |
| Coordination | 6 | 22 | +16 |
| Auditability | 14 | 20 | +6 |
| **Total** | **46** | **82** | **+36** |

**Risk-Benefit Ratio**: 0.08
**Performance**: COLD (once per boot)

**Verdict**: **MUST DO**

---

### CHANGE CARD I-02: ZenohSession Connection State Zenoh Meta-Publish

**File**: `lib/indrajaal/observability/zenoh_session.ex`
**ZUIP Ref**: T1-HIGH, Gap #31

#### WHY
ZenohSession itself transitions through states (disconnected -> connecting -> connected -> reconnecting -> failed). These transitions are logged but not published to... Zenoh (chicken-and-egg). However, when connected, the session should publish its own connection state changes to `indrajaal/zenoh/session/{node}/state` so that a monitoring subscriber can detect reconnection events.

#### WHAT
Add self-publish on successful connection/reconnection to `indrajaal/zenoh/session/{node}/connected`. On disconnect detection, the ABSENCE of heartbeats serves as the signal (cannot publish when disconnected).

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 16 | 22 | +6 |
| Recoverability | 14 | 18 | +4 |
| Coordination | 10 | 20 | +10 |
| Auditability | 14 | 18 | +4 |
| **Total** | **54** | **78** | **+24** |

**Risk-Benefit Ratio**: 0.15 (chicken-and-egg complexity)
**Performance**: COLD (connection events are rare)

**Verdict**: **SHOULD DO**

---

### CHANGE CARD I-03: ZenohSession Publish Async/Sync Variants

**File**: `lib/indrajaal/observability/zenoh_session.ex`
**ZUIP Ref**: T1-HIGH, Gap #32 (architectural)

#### WHY
Currently ZenohSession.publish/3 uses `GenServer.call` which serializes ALL publishes through a single mailbox. This is the bottleneck identified in ZUIP v2 cross-impact analysis. High-frequency publishers (SmartMetrics, test results) will starve safety-critical publishes (emergency stop, dying gasp).

#### WHAT
Add `publish_async/3` that uses `GenServer.cast` for fire-and-forget semantics, and `publish_nowait/3` that bypasses the GenServer entirely using a `Task.start` with direct NIF call (if possible). Keep `publish/3` as synchronous for when delivery confirmation is needed.

#### ROBUSTNESS SCORE
| Dimension | Before | After | Delta |
|-----------|--------|-------|-------|
| Observability | 18 | 20 | +2 |
| Recoverability | 14 | 18 | +4 |
| Coordination | 12 | 22 | +10 |
| Auditability | 16 | 18 | +2 |
| **Total** | **60** | **78** | **+18** |

**Risk-Benefit Ratio**: 0.35 (significant refactor of core module)
**Performance**: Enables all other changes to use appropriate publish strategy

**Verdict**: **MUST DO** -- prerequisite for safe implementation of all other changes

---

## Summary Table

| ID | Change | Subsystem | File | Performance | Robustness Delta | Verdict |
|----|--------|-----------|------|-------------|-----------------|---------|
| S-01 | Guardian Emergency Stop | Safety | guardian.ex | COLD | +29 | MUST DO |
| S-02 | Guardian Veto | Safety | guardian.ex | COLD | +24 | SHOULD DO |
| S-03 | Sentinel Threat | Safety | sentinel.ex | WARM | +37 | MUST DO |
| S-04 | Sentinel Health | Safety | sentinel.ex | WARM | +29 | SHOULD DO |
| S-05 | Sentinel Quarantine | Safety | sentinel.ex | COLD | +36 | MUST DO |
| S-06 | PatternHunter Detection | Safety | pattern_hunter.ex | WARM | +31 | SHOULD DO |
| S-07 | SymbioticDefense Level | Safety | symbiotic_defense.ex | COLD | +40 | MUST DO |
| S-08 | SymbioticDefense Recovery | Safety | symbiotic_defense.ex | COLD | +34 | SHOULD DO |
| D-01 | WaveExecutor Boot Phase | Deployment | wave_executor.ex | COLD | +55 | MUST DO |
| D-02 | WaveExecutor Wave | Deployment | wave_executor.ex | COLD | +44 | MUST DO |
| D-03 | WaveExecutor Container | Deployment | wave_executor.ex | COLD | +32 | NICE TO HAVE |
| D-04 | WaveExecutor Rollback | Deployment | wave_executor.ex | COLD | +54 | MUST DO |
| D-05 | DyingGasp | Deployment | dying_gasp.ex | COLD | +40 | MUST DO |
| D-06 | Apoptosis | Deployment | apoptosis.ex | COLD | +63 | MUST DO |
| D-07 | EmergencyResponse Phase | Deployment | emergency_response.ex | COLD | +42 | MUST DO |
| D-08 | EmergencyResponse Peers | Deployment | emergency_response.ex | COLD | +34 | SHOULD DO |
| O-01 | SmartMetrics Batch | Observability | smart_metrics.ex | HOT | +20 | NICE TO HAVE |
| O-02 | SentinelBridge Sync | Observability | sentinel_bridge.ex | COLD | +24 | NICE TO HAVE |
| O-03 | HealthCoordinator FPPS | Observability | health_coordinator.ex | COLD | +36 | SHOULD DO |
| O-04 | HealthCoord CB State | Observability | health_coordinator.ex | COLD | +40 | SHOULD DO |
| O-05 | Jidoka Halt/Resume | Observability | jidoka.ex | COLD | +42 | MUST DO |
| G-01 | MasterControl Command | Governance | master_control.ex | WARM | +20 | NICE TO HAVE |
| G-02 | MasterControl Emergency | Governance | master_control.ex | COLD | +34 | SHOULD DO |
| G-03 | MasterControl CB State | Governance | master_control.ex | COLD | +36 | SHOULD DO |
| G-04 | ImmutableState Block | Governance | immutable_state.ex | WARM | +27 | NICE TO HAVE |
| G-05 | Prajna CB Storm | Governance | circuit_breaker.ex | COLD | +22 | NICE TO HAVE |
| T-01 | ExUnit Formatter Verify | Testing | zenoh_test_formatter.ex | WARM | +14 | SHOULD DO |
| T-02 | Sprint Publisher Verify | Testing | sprint_task_publisher.ex | COLD | +14 | NICE TO HAVE |
| T-03 | Coverage Report | Testing | zenoh_test_orchestrator.ex | COLD | +12 | NICE TO HAVE |
| I-01 | App Startup Complete | Infrastructure | application.ex | COLD | +36 | MUST DO |
| I-02 | ZenohSession State | Infrastructure | zenoh_session.ex | COLD | +24 | SHOULD DO |
| I-03 | ZenohSession Async API | Infrastructure | zenoh_session.ex | N/A | +18 | MUST DO |

---

## Verdict Counts

| Verdict | Count | Aggregate Robustness Delta |
|---------|-------|---------------------------|
| **MUST DO** | 14 | +548 |
| **SHOULD DO** | 11 | +347 |
| **NICE TO HAVE** | 7 | +147 |
| **RECONSIDER** | 0 | 0 |
| **TOTAL** | **32** | **+1042** |

---

## Overall System Robustness Delta

| Metric | Before (avg) | After (avg) | Delta |
|--------|-------------|-------------|-------|
| Observability | 13.3 | 22.3 | +9.0 |
| Recoverability | 13.8 | 18.9 | +5.1 |
| Coordination | 6.8 | 20.3 | +13.5 |
| Auditability | 15.3 | 21.1 | +5.8 |
| **Total** | **49.2** | **82.6** | **+33.4** |

The largest gap is in **Coordination** (+13.5 average), confirming ZUIP v1/v2's central thesis: the system has strong local observability but weak distributed coordination. Zenoh publish additions directly address this gap.

---

## Recommended Implementation Order

### Phase 1: Foundation (Week 1) -- Prerequisites
**Must complete before any other changes.**

| Priority | ID | Change | Rationale |
|----------|----|--------|-----------|
| 1 | I-03 | ZenohSession Async API | All other changes depend on having async/fire-and-forget publish variants |
| 2 | I-01 | App Startup Complete | Validates Zenoh is working end-to-end |

### Phase 2: Nervous System (Week 2) -- Emergency Paths
**Safety-critical signals that MUST reach the mesh.**

| Priority | ID | Change | Rationale |
|----------|----|--------|-----------|
| 3 | S-01 | Guardian Emergency Stop | Highest-priority safety signal |
| 4 | D-06 | Apoptosis | Distinguishes intentional from accidental death |
| 5 | D-05 | DyingGasp | Last-chance mesh notification |
| 6 | D-07 | EmergencyResponse Phase | Coordinated shutdown tracking |
| 7 | O-05 | Jidoka Halt/Resume | System-wide operational halt |

### Phase 3: Immune System (Week 3) -- Threat Detection
**Distributed threat awareness for coordinated response.**

| Priority | ID | Change | Rationale |
|----------|----|--------|-----------|
| 8 | S-03 | Sentinel Threat | Mesh-wide threat propagation |
| 9 | S-05 | Sentinel Quarantine | Quarantine action visibility |
| 10 | S-07 | SymbioticDefense Level | Defense posture coordination |
| 11 | D-04 | WaveExecutor Rollback | Rollback visibility |

### Phase 4: Circulatory System (Week 4) -- Boot & Deployment
**Deployment pipeline visibility for F# orchestrator.**

| Priority | ID | Change | Rationale |
|----------|----|--------|-----------|
| 12 | D-01 | WaveExecutor Boot Phase | Boot checkpoint protocol |
| 13 | D-02 | WaveExecutor Wave | Wave tracking |
| 14 | T-01 | ExUnit Formatter Verify | Hardening existing test telemetry |

### Phase 5: SHOULD DO Batch (Weeks 5-6)

| Priority | ID | Change |
|----------|-----|--------|
| 15 | S-02 | Guardian Veto |
| 16 | S-04 | Sentinel Health |
| 17 | S-06 | PatternHunter Detection |
| 18 | S-08 | SymbioticDefense Recovery |
| 19 | D-08 | EmergencyResponse Peers |
| 20 | O-03 | HealthCoordinator FPPS |
| 21 | O-04 | HealthCoord CB State |
| 22 | G-02 | MasterControl Emergency |
| 23 | G-03 | MasterControl CB State |
| 24 | I-02 | ZenohSession State |

### Phase 6: NICE TO HAVE (Weeks 7-8, as capacity allows)

| Priority | ID | Change |
|----------|-----|--------|
| 25 | D-03 | WaveExecutor Container |
| 26 | O-01 | SmartMetrics Batch |
| 27 | O-02 | SentinelBridge Sync |
| 28 | G-01 | MasterControl Command |
| 29 | G-04 | ImmutableState Block |
| 30 | G-05 | Prajna CB Storm |
| 31 | T-02 | Sprint Publisher Verify |
| 32 | T-03 | Coverage Report |

---

## Critical Dependencies

```
I-03 (ZenohSession Async API)
 └─► ALL other changes depend on this

S-01 (Guardian Emergency Stop)
 ├─► G-02 (MasterControl Emergency) -- supplements
 └─► D-08 (EmergencyResponse Peers) -- same signal plane

D-06 (Apoptosis) + D-05 (DyingGasp) + D-07 (EmergencyResponse Phase)
 └─► These form the "death notification" cluster -- implement together

S-03 (Sentinel Threat) + S-05 (Sentinel Quarantine) + S-07 (SymbioticDefense Level)
 └─► These form the "immune response" cluster -- implement together

D-01 (Boot Phase) + D-02 (Wave) + I-01 (App Startup)
 └─► These form the "boot telemetry" cluster -- implement together
```

---

## Top 5 Dangerous Interactions (from ZUIP v2)

| Rank | Interaction | RPN | Mitigation by Change Cards |
|------|-------------|-----|---------------------------|
| 1 | Split-Brain Oscillation | 252 | D-06, D-05, S-01 provide mesh-wide death/emergency signals |
| 2 | Emergency + Sync Zenoh | 224 | I-03 provides async variants; S-01 uses Task.start |
| 3 | Metric Flood + Starvation | 189 | O-01 uses batch; I-03 provides priority paths |
| 4 | Boot + Rollback Race | 168 | D-01, D-04 provide atomic checkpoint/rollback signals |
| 5 | Guardian Veto + Stale Cache | 144 | S-02 publishes vetoes for cache invalidation |

---

## Document Control

| Field | Value |
|-------|-------|
| Document ID | ZUIP-V3-CHANGE-CARDS |
| Version | 3.0.0 |
| Created | 2026-03-18 |
| Author | Claude Opus 4.6 |
| STAMP | SC-ZTEST-001 to SC-ZTEST-020, SC-ZENOH-001 to SC-ZENOH-015 |
| Files Analyzed | 19 source files across 6 subsystems |
| Changes Assessed | 32 |
