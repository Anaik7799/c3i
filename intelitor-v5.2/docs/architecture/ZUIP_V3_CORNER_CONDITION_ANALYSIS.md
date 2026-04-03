# ZUIP v3: Corner Condition, Race Condition & Cascading Failure Analysis

**Version**: 3.0.0 | **Date**: 2026-03-18 | **Status**: ANALYSIS COMPLETE
**Compliance**: IEC 61508 SIL-6, SC-FMEA-001 | **Scope**: All 32 ZUIP Mutation Points
**Author**: Cybernetic Architect (Claude Opus 4.6)

---

## Table of Contents

1. [Race Conditions (RC-ZUIP-001 to RC-ZUIP-018)](#1-race-conditions)
2. [Edge Cases (EC-ZUIP-001 to EC-ZUIP-020)](#2-edge-cases)
3. [Cascading Failure Scenarios (CF-ZUIP-001 to CF-ZUIP-012)](#3-cascading-failure-scenarios)
4. [Stale State Windows](#4-stale-state-windows)
5. [Failure Mode Enumeration (FM-ZUIP-001 to FM-ZUIP-035)](#5-failure-mode-enumeration)

---

## 1. Race Conditions

### RC-ZUIP-001: ZenohSession GenServer Mailbox Serialization Bottleneck

**Description**: `ZenohSession.publish/3` (line 101 of `zenoh_session.ex`) uses `GenServer.call(pid, {:publish, key, payload})` -- a synchronous, blocking call. All 32 new ZUIP publish points funnel through this single GenServer mailbox. Under load, the mailbox queue grows, and callers block waiting for their turn.

**ZUIP Changes Creating This**: Every single ZUIP mutation point. All 32 proposed publish locations call `ZenohSession.publish/3`.

**Timing Window**: The window is the sum of all concurrent publish durations queued ahead. With NIF-backed Zenoh, each `safe_publish/3` (line 525) takes ~0.5-2ms including NIF call overhead. With 32 publishers firing within a 5-second health check cycle, the tail latency for the last queued message approaches 32 * 2ms = 64ms in the worst case. Under burst conditions (e.g., emergency stop triggering simultaneous publishes from Guardian, EmergencyResponse, MasterControl, Sentinel, SymbioticDefense, DyingGasp), the queue can exceed 50 messages, pushing tail latency above 100ms.

**Probability**: HIGH (>70%). Any scenario where multiple ZUIP publishers activate simultaneously creates this condition. Health check cycles (10s from HealthCoordinator, 5s from Sentinel, 30s from MasterControl) naturally align periodically.

**Severity**: HIGH. Exceeding 100ms violates SC-ZTEST-005. More critically, blocking the emergency stop publisher behind a queue of non-critical health publishes risks violating SC-EMR-057 (5s deadline).

**Mitigation**:
1. Add `publish_async/3` to ZenohSession using `GenServer.cast` for fire-and-forget telemetry.
2. Implement priority lanes: `:critical` (emergency stop, apoptosis), `:high` (threats, health), `:normal` (metrics, state).
3. Use `GenServer.call` with explicit short timeouts (500ms) for non-critical publishes, falling back to log on timeout.
4. Consider a pool of ZenohSession workers for non-critical publishes (ETS-based routing by topic prefix).

---

### RC-ZUIP-002: Emergency Stop + Synchronous Zenoh Publish SLA Violation

**Description**: `EmergencyResponse.emergency_stop/2` (line 268) must complete in <4500ms (`@default_config.emergency_stop_ms`, line 182). Adding a synchronous Zenoh publish to this path introduces a blocking call to ZenohSession. If ZenohSession is itself stuck (reconnecting, NIF crash, or behind a queue), the `GenServer.call` default timeout is 5000ms -- already exceeding the entire emergency stop budget.

**ZUIP Changes Creating This**: Any proposal to add Zenoh publish to `emergency_stop/2`, `Guardian.emergency_stop/1` (line 270), or `MasterControl.emergency_stop/1` (line 258).

**Timing Window**: Between emergency stop initiation and `GenServer.call` timeout for Zenoh publish. If Zenoh is disconnected (status `:failed` at line 466), the `handle_call` on line 282 returns `{:error, :not_connected}` immediately -- this is safe. The dangerous case is when status is `:connected` but the NIF call hangs (Zenoh router unresponsive, network partition), consuming up to 5000ms of the GenServer.call timeout.

**Probability**: MEDIUM (30-50%). Zenoh router failure during an emergency is exactly the correlated failure mode one should expect -- emergencies are often caused by infrastructure degradation that also affects Zenoh.

**Severity**: CRITICAL. Violates SC-EMR-057 (emergency stop <5s). A system that cannot stop in time is a SIL-6 compliance failure.

**Mitigation**:
1. Emergency stop path MUST use fire-and-forget (`GenServer.cast` or `spawn` + `ZenohSession.publish`) with zero blocking.
2. Add a dedicated `publish_emergency/3` API to ZenohSession that bypasses the GenServer entirely by calling the NIF directly with a 50ms hard timeout.
3. Emergency stop Zenoh publish MUST be wrapped in `Task.async` with `Task.yield(task, 200)` and killed if it doesn't complete.
4. Dual-write pattern (SC-ZTEST-008): log FIRST, Zenoh attempt second. Never let Zenoh failure block the stop path.

---

### RC-ZUIP-003: Split-Brain Detection Oscillation (Dual Apoptosis)

**Description**: Two nodes in a partition both detect split-brain via `HealthCoordinator.fs:DetectSplitBrain()` (line 288). Both call `ShouldTriggerApoptosis()` (line 393), which has NO grace period. Both nodes simultaneously publish apoptosis events to Zenoh AND initiate `Cluster.Apoptosis.initiate/1` (line 8 of `apoptosis.ex`). The Zenoh publishes cross the partition boundary (if partially healed), causing each node to see the other's apoptosis event and potentially abort their own -- or both proceed and the cluster loses all nodes.

**ZUIP Changes Creating This**: Any ZUIP publish added to `Cluster.Apoptosis.initiate/1` or to the F# `HealthCoordinator.fs:ShouldTriggerApoptosis()` path.

**Timing Window**: Between split-brain detection on Node A and split-brain detection on Node B. Since both run the same 10s health check cycle, the window is <10s. If health checks align (both fire within 500ms of each other), the race is virtually guaranteed.

**Probability**: MEDIUM-HIGH (40-60%). The 10s health check interval is identical on all nodes; without jitter, checks naturally synchronize via NTP-synchronized clocks.

**Severity**: CRITICAL (RPN 252 per ZUIP v2). Complete cluster loss is the worst-case outcome.

**Mitigation**:
1. Add configurable grace period (30-60s) to `ShouldTriggerApoptosis()` in `HealthCoordinator.fs`.
2. Use Zenoh-published "apoptosis intent" messages with leader election -- only the minority partition self-terminates.
3. Add random jitter (0-5s) to the health check interval to de-synchronize detection across nodes.
4. Implement a "I'm dying" Zenoh tombstone that surviving nodes can read to prevent dual apoptosis.

---

### RC-ZUIP-004: Circuit Breaker State Transition During Publish

**Description**: `CircuitBreaker.handle_call({:call, fun}, _from, state)` (line 179 of `circuit_breaker.ex`) dispatches based on `state.state` (:closed, :open, :half_open). If ZUIP adds a Zenoh publish inside the function `fun` passed to the circuit breaker, AND the Zenoh publish triggers a timeout that counts as a failure, the circuit breaker may transition from :closed to :open mid-publish. Subsequent publishes from the same module then receive `{:error, :circuit_open}` -- silently dropping all telemetry for that domain.

**ZUIP Changes Creating This**: ZUIP changes that wrap Zenoh publishes inside circuit-breaker-protected paths (MasterControl.execute_command/3 at line 198, any domain action with circuit breaker protection).

**Timing Window**: During the `handle_closed_call/2` execution when `failure_count` approaches `failure_threshold` (default 5, line 26). The window is the duration of the circuit breaker's `execute_function/1` call -- typically 0-5000ms depending on the function's timeout.

**Probability**: MEDIUM (25-40%). Zenoh timeouts under load can produce 5 consecutive failures within a 60s window.

**Severity**: MEDIUM. Loss of telemetry is not safety-critical, but creates observability blind spots precisely when the system is degraded.

**Mitigation**:
1. Zenoh publishes should NEVER be inside circuit-breaker-protected paths. Use a separate, unprotected channel for telemetry.
2. If circuit-breaker protection is desired, use a dedicated circuit breaker for Zenoh with higher thresholds (e.g., 20 failures).
3. Log fallback (SC-ZTEST-008) must activate when circuit breaker opens for Zenoh.

---

### RC-ZUIP-005: FPPS Consensus During Health State Publish

**Description**: `HealthCoordinator.execute_health_check/1` runs FPPS 5-validator consensus via `Task.async_stream` with parallel `podman inspect/logs` commands (lines 246-260). The consensus result determines the health status. ZUIP proposes publishing this status to Zenoh. If the Zenoh publish occurs BETWEEN the consensus vote and the state update, a subscriber reads stale/incomplete health. Worse: if one of the 5 validators queries Zenoh for the "current" health during its own validation, it reads the previous cycle's result, creating a feedback loop.

**ZUIP Changes Creating This**: Any ZUIP publish of FPPS consensus results from HealthCoordinator.

**Timing Window**: Between `Task.async_stream` result collection and GenServer state update (the window for FPPS consensus itself is up to `@health_check_timeout_ms` = 5000ms, line 38).

**Probability**: LOW-MEDIUM (15-25%). Only occurs if FPPS validators themselves subscribe to Zenoh health topics.

**Severity**: MEDIUM. Stale health data is misleading but not immediately dangerous. The feedback loop (reading your own stale output) could cause health oscillation.

**Mitigation**:
1. Publish to Zenoh ONLY after the full FPPS consensus cycle completes and GenServer state is updated.
2. Use a sequence number or epoch counter in published health messages so subscribers can detect stale data.
3. FPPS validators MUST NOT read Zenoh topics as input -- they should use only direct container inspection.

---

### RC-ZUIP-006: Guardian Proposal Validation + Concurrent Zenoh Publish

**Description**: `Guardian.validate_proposal/2` (line 132) uses `GenServer.call(__MODULE__, {:validate, proposal}, timeout)` with a 5000ms default timeout. If ZUIP adds Zenoh publish to the validation path (e.g., publishing the proposal for audit), and that Zenoh publish blocks (ZenohSession mailbox full), the Guardian validation timeout may fire. The caller (MasterControl.execute_command/3 at line 217) receives a timeout exception, but the proposal may have already passed validation internally -- it just failed to publish the audit trail.

**ZUIP Changes Creating This**: ZUIP changes adding Zenoh publish inside `Guardian.do_validate_proposal/1` (line 611) or `log_violation/2` (line 873).

**Timing Window**: The full 5000ms Guardian timeout window. If ZenohSession is under load (RC-ZUIP-001), the Zenoh publish could consume 50-200ms, which is normally fine. But if ZenohSession is reconnecting (status `:reconnecting`), the `GenServer.call` to ZenohSession hangs until timeout.

**Probability**: LOW (10-20%). Guardian validation and Zenoh failure are weakly correlated.

**Severity**: HIGH. A blocked Guardian means all MasterControl commands stall, and the system loses its safety gatekeeper.

**Mitigation**:
1. Zenoh publish in Guardian MUST be fire-and-forget (cast, not call).
2. Guardian timeout should be shorter than ZenohSession timeout (e.g., Guardian 3000ms, Zenoh publish attempt 500ms).
3. `log_violation/2` (line 873) already uses `ZenohNeuralStream.stream_state` with a try/rescue -- this pattern should be the template for all Guardian Zenoh integration.

---

### RC-ZUIP-007: SmartMetrics ETS Write + PubSub + Zenoh Triple-Write Race

**Description**: `SmartMetrics.handle_cast({:record, ...})` (line 220) performs: (1) ETS insert (line 238), (2) PubSub broadcast (line 241), (3) proposed ZUIP Zenoh publish. These three writes are not atomic. A subscriber reading via ETS `SmartMetrics.get/1` may see the new value before the PubSub/Zenoh message arrives, or may see a PubSub notification before ETS has the new value (if execution order changes).

**ZUIP Changes Creating This**: ZUIP change adding Zenoh publish to SmartMetrics record path.

**Timing Window**: Nanoseconds between the three writes. ETS write is ~1us, PubSub broadcast is ~10-50us, Zenoh publish is ~0.5-2ms. Total spread: up to 2ms between first (ETS) and last (Zenoh) write.

**Probability**: HIGH (>60%). At 200 records/second, temporal inconsistency between the three stores is routine.

**Severity**: LOW. Temporary inconsistency between ETS, PubSub, and Zenoh is acceptable for metrics -- eventual consistency is sufficient. However, if any consumer relies on Zenoh metrics for safety decisions, this becomes MEDIUM.

**Mitigation**:
1. Use `TelemetryBatcher` pattern: accumulate SmartMetrics updates for 5 seconds, then publish a single batch to Zenoh.
2. Include a monotonic sequence number in all three write targets so consumers can detect ordering.
3. Never use SmartMetrics-sourced Zenoh data for safety decisions (those should come from Sentinel directly).

---

### RC-ZUIP-008: Sentinel Health Check + Zenoh Publish Interleaving

**Description**: `Sentinel.handle_info(:health_check, state)` (triggered every 5000ms per line 76) collects system metrics, calculates health score, and updates GenServer state. If ZUIP adds Zenoh publish of the health score, and the publish blocks (GenServer.call to ZenohSession), the Sentinel's 5s health check interval drifts. With enough drift, two consecutive health checks stack up, and the Sentinel's own mailbox grows.

**ZUIP Changes Creating This**: ZUIP changes adding Zenoh publish in Sentinel's health check cycle.

**Timing Window**: The Zenoh publish blocking duration (0-5000ms). If ZenohSession mailbox has 10 messages queued, each taking 2ms, the Sentinel publish waits 20ms -- acceptable. But if ZenohSession is reconnecting, the wait could be up to 5000ms (GenServer.call default timeout), causing the Sentinel to skip a health check cycle.

**Probability**: MEDIUM (25-40%). Sentinel and ZenohSession failures are moderately correlated (both degrade under system stress).

**Severity**: MEDIUM. Sentinel skipping a health check means threats go undetected for an extra 5-10 seconds.

**Mitigation**:
1. Sentinel Zenoh publish MUST use `GenServer.cast` or `spawn_link` with an independent timeout.
2. Health check scheduling should use `Process.send_after(self(), :health_check, interval)` AFTER the check completes (current pattern), not before -- this prevents drift accumulation.
3. Add a "last publish timestamp" check: if last successful Zenoh publish was >30s ago, skip Zenoh and log only.

---

### RC-ZUIP-009: PatternHunter Scan + Report + Publish Feedback Loop

**Description**: `PatternHunter` runs on a 500ms scan interval (line 102). It collects system metrics (memory, CPU, process count, run queue) and matches against patterns. If ZUIP adds Zenoh publish of detection results, and the Zenoh publish itself causes observable system effects (CPU spike from NIF call, memory allocation for payload serialization), the NEXT PatternHunter scan may detect these effects as anomalies -- triggering more detections, more publishes, more anomalies.

**ZUIP Changes Creating This**: ZUIP changes adding Zenoh publish in PatternHunter's `report_detection/1` or scan result path.

**Timing Window**: 500ms between scans. The feedback takes one full scan cycle to manifest, so the oscillation period is 500ms-1s.

**Probability**: LOW (10-15%). The Zenoh publish overhead (0.5-2ms) is unlikely to be detected as an anomaly by PatternHunter's heuristics unless thresholds are very tight.

**Severity**: MEDIUM. A feedback loop could cause a cascade of false-positive detections, flooding Zenoh with spurious alerts and desensitizing operators.

**Mitigation**:
1. PatternHunter MUST exclude its own Zenoh publish activity from metrics collection (self-awareness).
2. Implement a cooldown: if the same pattern fires 3 times in 5 seconds, suppress further Zenoh publishes for 30s.
3. Rate-limit PatternHunter Zenoh publishes to max 1 per pattern per 10 seconds.

---

### RC-ZUIP-010: DyingGasp Checkpoint + Zenoh Publish Under SIGTERM

**Description**: `DyingGasp.capture/2` (line 84) is called during shutdown. It gathers state, serializes, compresses, hashes, and writes to disk. If ZUIP adds a Zenoh publish to announce the dying gasp, and the Zenoh publish arrives AFTER the BEAM has started shutting down (`:init.stop/1` called by Guardian at line 520), the ZenohSession GenServer may already be terminated. The publish call returns `{:error, :noproc}` or crashes the calling process.

**ZUIP Changes Creating This**: Any ZUIP change adding Zenoh publish to DyingGasp or the EmergencyResponse checkpointing path (line 712).

**Timing Window**: Between DyingGasp invocation and BEAM termination. `Guardian.execute_emergency_stop/2` calls `:init.stop(1)` at line 520 after a 100ms sleep (line 356). If DyingGasp is invoked in the same stop sequence, it has at most ~4300ms (4500ms budget - 100ms sleep - 100ms for earlier phases) to complete. The Zenoh publish must complete within this window.

**Probability**: HIGH (>60%). DyingGasp is explicitly called during shutdown sequences. The race between "publish checkpoint notification" and "BEAM stopping" is inherent.

**Severity**: MEDIUM. The dying gasp data is already written to disk; the Zenoh publish is a best-effort notification. Failure to publish means survivors don't learn about the checkpoint until they scan the disk -- a delay, not a data loss.

**Mitigation**:
1. DyingGasp Zenoh publish MUST be fire-and-forget with zero timeout.
2. Use `spawn(fn -> ZenohSession.publish(...) end)` -- if the process dies due to BEAM shutdown, no harm done.
3. The disk checkpoint is authoritative; the Zenoh message is advisory.

---

### RC-ZUIP-011: Apoptosis Phase Advancement + Zenoh Publish Ordering

**Description**: `EmergencyResponse.advance_phase/2` (line 724) uses `GenServer.cast` (line 728) to update state. The apoptosis sequence runs in a spawned process (line 510). If ZUIP adds Zenoh publish for each phase transition, the Zenoh messages may arrive at subscribers out of order: the Zenoh network has no guaranteed ordering across different publish calls from different processes. A subscriber could receive `:terminating` before `:draining`.

**ZUIP Changes Creating This**: ZUIP changes publishing apoptosis phase transitions to Zenoh.

**Timing Window**: Between consecutive `advance_phase/2` calls within `execute_apoptosis_sequence/3` (lines 701-721). Each phase has a `Process.sleep` (notification: 2000ms, drain: 1000ms, checkpoint: variable), so phases are separated by seconds. However, the Zenoh publishes for phases are issued by the same spawned process, and Zenoh guarantees FIFO within a single publisher for a single topic -- so ordering IS preserved if the same topic is used.

**Probability**: LOW (5-10%) if same topic and same publisher process. MEDIUM (20-30%) if different topics or if the Zenoh publish is done from the GenServer process (which interleaves with other messages).

**Severity**: LOW. Out-of-order phase messages are confusing but not dangerous -- the authoritative state is in the GenServer, not Zenoh.

**Mitigation**:
1. All apoptosis phase messages MUST use the same Zenoh topic to leverage FIFO ordering (SC-ZTEST-012).
2. Include a phase sequence number (1-6) in each message so subscribers can re-order if needed.
3. Publish from the spawned process, not the GenServer, to avoid interleaving with other messages.

---

### RC-ZUIP-012: MasterControl Health Publish + Domain Command Interleaving

**Description**: `MasterControl.handle_info(:health_check, state)` (line 281) computes health for all 30 domains, updates circuit breakers, and publishes to Zenoh via `ZenohCoordinator.publish` (line 293). This runs every 30s. Meanwhile, `handle_call({:execute_command, ...})` (line 198) can arrive mid-health-check. Since `handle_info` is not interruptible by `handle_call`, the command waits in the mailbox until the health check completes. If the health check includes 30 Zenoh publishes (one per domain), each taking 2ms, the command waits 60ms+ before being processed.

**ZUIP Changes Creating This**: ZUIP changes adding per-domain Zenoh health publishes inside MasterControl's health check cycle.

**Timing Window**: Duration of the health check handler (~60-300ms for 30 domain health evaluations + Zenoh publishes). Any `execute_command` arriving during this window is delayed.

**Probability**: MEDIUM (20-30%). The 30s health check cycle has a small duty cycle (~300ms/30000ms = 1%), but commands during maintenance windows or incident response cluster around health check times.

**Severity**: MEDIUM. Delayed command execution during emergencies is problematic but not catastrophic -- the emergency stop path uses `GenServer.call` with a 60s timeout (line 110).

**Mitigation**:
1. Batch all 30 domain health scores into a single Zenoh publish (one message, not 30).
2. Move Zenoh publish to a `Task.async` so it doesn't block the GenServer mailbox.
3. Health check should use `GenServer.cast` for Zenoh publish so it returns immediately.

---

### RC-ZUIP-013: Concurrent SymbioticDefense Escalation + De-escalation

**Description**: `SymbioticDefense` manages defense levels (`:normal` through `:critical`) with transitions defined in `@level_transitions` (line 97). If ZUIP adds Zenoh publish for level changes, and two concurrent threats trigger escalation while a third thread triggers de-escalation, the published Zenoh messages may show oscillating levels (:normal -> :elevated -> :normal -> :guarded) even though the actual state transition is (:normal -> :elevated -> :guarded). This is because the GenServer serializes all state changes, but the Zenoh messages reflect each intermediate state.

**ZUIP Changes Creating This**: ZUIP changes publishing defense level transitions from SymbioticDefense.

**Timing Window**: Between consecutive threat reports arriving at SymbioticDefense's GenServer mailbox. Typically 0-500ms for concurrent threats.

**Probability**: LOW (5-10%). Requires concurrent escalation and de-escalation signals within the same GenServer mailbox batch.

**Severity**: LOW. Zenoh subscribers see the correct final state; intermediate states are technically correct (they did happen, transiently).

**Mitigation**:
1. Debounce defense level Zenoh publishes: only publish if the level has been stable for 5 seconds.
2. Include a "transition reason" field so subscribers can distinguish intermediate from final states.

---

### RC-ZUIP-014: PubSub-to-Zenoh Bridge Message Amplification

**Description**: ZUIP v2 proposes a PubSub-to-Zenoh bridge for 35+ Phoenix.PubSub broadcasts. `SmartMetrics.safe_broadcast/2` (line 379) publishes to `"prajna:metrics"` on every metric record. `EmergencyResponse.notify_peers/3` (line 798) broadcasts to `"emergency_response:cluster"`. If a bridge subscribes to ALL PubSub topics and re-publishes to Zenoh, a single SmartMetrics update (200/sec) triggers: (1) ETS write, (2) PubSub broadcast, (3) Bridge receives PubSub, (4) Bridge publishes to Zenoh, (5) ZenohSession processes the publish. This amplification turns 200 metrics/sec into 200 Zenoh publishes/sec, which at 2ms each consumes 400ms/sec of ZenohSession time -- 40% of its capacity.

**ZUIP Changes Creating This**: The PubSub-to-Zenoh bridge proposal in ZUIP v2.

**Timing Window**: Continuous. The amplification occurs for every PubSub message while the bridge is active.

**Probability**: HIGH (>80%) if a naive bridge is implemented without filtering or batching.

**Severity**: HIGH. 40% ZenohSession utilization just from SmartMetrics leaves insufficient capacity for safety-critical publishes.

**Mitigation**:
1. Bridge MUST implement topic filtering -- only bridge safety-critical PubSub topics, not metrics.
2. Use `TelemetryBatcher` for metrics: accumulate 200 records over 5 seconds, publish 1 batch.
3. Rate-limit the bridge to max 10 Zenoh publishes/second.
4. Separate ZenohSession instances for metrics vs. safety telemetry.

---

### RC-ZUIP-015: ZenohSession Reconnection + Publish During Status Transition

**Description**: `ZenohSession.handle_info(:reconnect, state)` (line 428) checks reconnection conditions and sends `:connect` to self (line 451). During the reconnection attempt (status `:reconnecting`), any `publish` call hits `handle_call({:publish, _key, _payload}, _from, state)` on line 282, which returns `{:error, :not_connected}`. If the reconnection succeeds between the caller's publish attempt and the `handle_call` dispatch, the publish still fails because the status was `:reconnecting` (not `:connected`) at dispatch time.

**ZUIP Changes Creating This**: All 32 ZUIP publish points are affected during ZenohSession reconnection windows.

**Timing Window**: Duration of reconnection attempt. With exponential backoff (line 621), reconnect delays are 1s, 2s, 4s, 8s, 16s, 32s. During each attempt, status is `:reconnecting` for ~100-500ms (the time to establish a TCP connection to the router).

**Probability**: MEDIUM (20-30%). Zenoh reconnections are expected during network glitches, router restarts, or container updates.

**Severity**: MEDIUM. All publishes fail during reconnection, creating a telemetry gap. The dual-write pattern (SC-ZTEST-008) provides log fallback, but only if callers implement it.

**Mitigation**:
1. All ZUIP publish callers MUST implement dual-write (log first, Zenoh second) per SC-ZTEST-008.
2. Add a message queue to ZenohSession that buffers publishes during reconnection and drains on reconnect.
3. Increase `@max_reconnect_attempts` from 5 to 10 for production deployments.

---

### RC-ZUIP-016: Sentinel Quarantine + PatternHunter Detection Publish Race

**Description**: When Sentinel quarantines a process via `:erlang.suspend_process(pid)` and ZUIP adds a Zenoh publish of the quarantine event, PatternHunter (scanning every 500ms) may detect the quarantine as a "process anomaly" and publish its own detection event. The two Zenoh messages arrive at subscribers nearly simultaneously, creating duplicate alerts for the same underlying event.

**ZUIP Changes Creating This**: ZUIP changes adding Zenoh publish to both Sentinel quarantine actions and PatternHunter detection reports.

**Timing Window**: 0-500ms (PatternHunter scan interval).

**Probability**: HIGH (>60%). Every quarantine action will be detected by PatternHunter's next scan.

**Severity**: LOW. Duplicate alerts are noisy but not dangerous.

**Mitigation**:
1. Use a shared "event deduplication ID" (the quarantined PID + timestamp) across Sentinel and PatternHunter Zenoh messages.
2. PatternHunter should check Sentinel's quarantine list before reporting process anomalies.

---

### RC-ZUIP-017: F# Wire Gap -- stderr Publish vs. Zenoh Wire

**Description**: `ZenohPublish.fs` writes checkpoint messages to stderr/stdout, NOT to the actual Zenoh wire protocol. F# safety events (split-brain detection in `HealthCoordinator.fs`, apoptosis in `Apoptosis.fs`) are invisible to Elixir-side Zenoh subscribers. ZUIP proposes Zenoh integration for F# modules, but the implementation gap means F# "publishes" are log messages, not network messages.

**ZUIP Changes Creating This**: All F#-side ZUIP changes (HealthCoordinator.fs, Apoptosis.fs, SIL6BiomorphicOrchestrator.fs).

**Timing Window**: Always. The gap is architectural, not temporal.

**Probability**: 100%. This is not a race condition but a permanent gap until F# gets real Zenoh client bindings.

**Severity**: CRITICAL (RPN 216 per ZUIP v2). F# safety events (split-brain, apoptosis) are the most critical telemetry in the system, and they are completely invisible to Zenoh subscribers.

**Mitigation**:
1. SHORT-TERM: Implement an F#-to-Elixir HTTP bridge that accepts F# events and re-publishes to Zenoh.
2. SHORT-TERM: Parse F# stderr output with a sidecar process that publishes to Zenoh.
3. LONG-TERM: Integrate the Zenoh Rust client with F# via .NET P/Invoke or the Zenoh Python bindings.
4. Add an Elixir GenServer (`FSharpZenohBridge`) that polls F# health state and publishes it.

---

### RC-ZUIP-018: Guardian Emergency Stop Double-Execution Race

**Description**: `Guardian.emergency_stop/1` (line 270) spawns `execute_emergency_stop/2` in a separate process (line 276) AND casts to the GenServer (line 281), which also spawns `execute_emergency_stop/2` (line 584). This means EVERY emergency stop runs the 7-phase sequence TWICE in parallel. If ZUIP adds Zenoh publish to the emergency stop sequence, subscribers receive two copies of every emergency stop phase message. More dangerously, both sequences call `:init.stop(1)` (line 520), and both try to terminate supervised children (line 468), creating resource contention on the supervision tree.

**ZUIP Changes Creating This**: Any ZUIP change to the Guardian emergency stop path.

**Timing Window**: Both sequences start within microseconds of each other and run concurrently for the full 4500ms budget.

**Probability**: 100%. This is by design (redundancy for reliability), but it creates predictable race conditions.

**Severity**: MEDIUM. The double execution is intentional but causes duplicate Zenoh messages and potential resource contention.

**Mitigation**:
1. Use an AtomicBoolean (`:persistent_term` or `:atomics`) to ensure only the first execution path runs the full sequence.
2. Zenoh publish should include a "execution_id" UUID so subscribers can deduplicate.
3. Document that emergency stop Zenoh messages may be duplicated and subscribers should idempotently handle them.

---

## 2. Edge Cases

### EC-ZUIP-001: ZenohNIF Not Loaded (SKIP_ZENOH_NIF=1)

**Condition**: When `SKIP_ZENOH_NIF=1`, `Code.ensure_loaded?(ZenohNIF)` returns false. `safe_publish/3` (line 525) falls through to the stub branch (line 530), which logs and returns `:ok`. All 32 ZUIP publish points silently succeed without actually publishing anything.

**Affected ZUIP Changes**: All 32 publish points.

**Likelihood**: LOW in production (SKIP_ZENOH_NIF=0 enforced by SC-ZENOH-001). HIGH in development/test environments.

**Impact**: Complete telemetry blackout with no error signals. The system appears healthy (all publishes return `:ok`) but no data flows to subscribers.

**Handling Strategy**:
1. In stub mode, increment a "stub publish count" metric that can be queried via SmartMetrics.
2. Log a WARNING (not DEBUG) on the first stub publish per session, so operators notice the gap.
3. Add a health check endpoint that reports whether Zenoh is in stub mode.

---

### EC-ZUIP-002: Zero-Length Payload Published to Zenoh

**Condition**: A ZUIP publish call where the payload serializes to `<<>>` (empty binary). `safe_publish/3` (line 525) passes this to `ZenohNIF.publish/3`, which may accept or reject it depending on the Rust NIF implementation.

**Affected ZUIP Changes**: Any ZUIP publish where the source data map is empty (e.g., `%{}` serialized to `"{}"` -- valid JSON but semantically empty).

**Likelihood**: LOW (5%). Most publish locations construct non-empty payloads from system state.

**Impact**: LOW. Empty messages are wasteful but harmless. Subscribers that deserialize to empty maps may skip processing.

**Handling Strategy**:
1. Add a guard to `ZenohSession.publish/3`: reject payloads with `byte_size(payload) == 0`.
2. Log a warning for zero-length publishes to identify source modules.

---

### EC-ZUIP-003: Payload Exceeds 64KB (SC-ZTEST-016)

**Condition**: A ZUIP publish where the payload exceeds 64KB. The DyingGasp checkpoint (captured by `DyingGasp.capture/2`) includes ETS table dumps and process state, which can easily exceed 64KB for large systems. If ZUIP publishes the checkpoint content to Zenoh, it violates SC-ZTEST-016.

**Affected ZUIP Changes**: DyingGasp checkpoint publish, SmartMetrics bulk publish, HealthCoordinator full system health dump.

**Likelihood**: MEDIUM (20-30%). Production systems with many ETS tables can produce 100KB+ state snapshots.

**Impact**: MEDIUM. Zenoh may reject or fragment the message. Subscribers may fail to deserialize oversized messages.

**Handling Strategy**:
1. Add payload size check before publish: `if byte_size(payload) > 65_536, do: {:error, :payload_too_large}`.
2. For large payloads, publish a reference (checkpoint_id + path) instead of the full content.
3. Use zlib compression for payloads >32KB.

---

### EC-ZUIP-004: Clock Skew Between Elixir and F# Timestamps

**Condition**: Elixir uses `DateTime.utc_now()` (NTP-synchronized). F# uses `DateTimeOffset.UtcNow` (also NTP-synchronized, but potentially on a different container with different NTP drift). If ZUIP publishes timestamps from both runtimes, subscribers comparing timestamps may see non-monotonic sequences.

**Affected ZUIP Changes**: All F#-origin publishes compared with Elixir-origin publishes.

**Likelihood**: LOW (5-10%). NTP drift on modern systems is typically <100ms.

**Impact**: LOW. Timestamp ordering inconsistencies confuse log analysis but don't affect safety.

**Handling Strategy**:
1. Use monotonic clocks (`System.monotonic_time`) for ordering, wall clocks for display only.
2. Include a `source_runtime` field (:elixir or :fsharp) in all Zenoh messages so subscribers know the clock source.

---

### EC-ZUIP-005: Hot Code Upgrade During Active Zenoh Publish

**Condition**: During a hot code reload (`mix compile` while the system is running), a module's GenServer state may be upgraded. If the Zenoh publish path is mid-execution when the module is reloaded, the old code continues running but references to module-level constants (`@scan_interval_ms`, `@thresholds`) may resolve to new values.

**Affected ZUIP Changes**: All ZUIP publish points in modules that may be hot-reloaded (all Elixir modules).

**Likelihood**: LOW (5%). Hot code reload is rare in production. In development, it's common but the impact is low.

**Impact**: LOW. The worst case is a single publish with mixed old/new constants, which produces one anomalous message.

**Handling Strategy**:
1. No special handling needed -- the BEAM handles hot code upgrade gracefully for GenServers with `code_change/3`.
2. Include a `module_version` field in Zenoh messages to detect mixed-version publishes.

---

### EC-ZUIP-006: ETS Table Not Created During SmartMetrics Startup

**Condition**: `SmartMetrics.init/1` creates ETS tables at line 201. If another module calls `SmartMetrics.get/1` (line 76) before `init/1` completes, the `:ets.lookup(@table, metric_id)` call crashes with `ArgumentError` because the table doesn't exist. ZUIP adding Zenoh publish to SmartMetrics doesn't create this bug but exacerbates it: the crash happens more frequently because the Zenoh publish path may trigger SmartMetrics reads during startup.

**Affected ZUIP Changes**: ZUIP changes that read SmartMetrics during initialization of other modules.

**Likelihood**: LOW (5-10%). Only during application startup, when module init ordering is non-deterministic.

**Impact**: MEDIUM. A crash during startup can cascade through the supervision tree.

**Handling Strategy**:
1. `SmartMetrics.get/1` should check `:ets.whereis(@table)` before `:ets.lookup`, returning `nil` if the table doesn't exist.
2. ZUIP publish callers should handle `nil` return from SmartMetrics gracefully.

---

### EC-ZUIP-007: Zenoh Router Process Crash (Not Network Failure)

**Condition**: The Zenoh router process (`zenoh-router` container) crashes but the container remains "running" (zombie state). ZenohSession health check (line 470, every 10s) calls `safe_session_status/1` which may return `{:ok, _}` because the session reference is still valid locally, even though the router is dead. Publishes succeed at the NIF level (buffered) but never reach subscribers.

**Affected ZUIP Changes**: All 32 publish points -- silent data loss.

**Likelihood**: LOW (5-10%). Zenoh router crash without container restart is rare but possible (e.g., OOM killer, segfault).

**Impact**: HIGH. Silent data loss for all telemetry. No error returned to callers. System appears healthy.

**Handling Strategy**:
1. ZenohSession health check should include an end-to-end probe: publish to a self-subscribed topic and verify receipt within 1s.
2. Add a "last successful subscriber ACK" timestamp to ZenohSession stats.
3. Trip circuit breaker on ZenohSession if health probe fails 3 consecutive times.

---

### EC-ZUIP-008: Unicode/Invalid UTF-8 in Zenoh Key Expressions

**Condition**: ZUIP key expressions like `"indrajaal/container/{name}/health"` interpolate container names. If a container name contains non-ASCII characters, reserved Zenoh characters (*, ?, #), or raw bytes, the key expression is malformed. `ZenohNIF.publish/3` may reject it or crash.

**Affected ZUIP Changes**: Any ZUIP publish with interpolated container names, domain names, or user-supplied data.

**Likelihood**: LOW (2-5%). Container names are typically ASCII alphanumeric. But programmatic names from tests or CI might contain special characters.

**Impact**: MEDIUM. A crash in the NIF propagates as an error to ZenohSession, which logs but continues. However, the specific publish fails silently.

**Handling Strategy**:
1. Sanitize all key expression components: `String.replace(name, ~r/[^a-zA-Z0-9\-_.]/, "_")`.
2. Validate key expressions against Zenoh syntax before publishing.

---

### EC-ZUIP-009: Jason.encode! Crash on Non-Serializable Data

**Condition**: Several ZUIP publish locations serialize GenServer state to JSON. If the state contains PIDs, references, functions, or tuples (all non-JSON-serializable), `Jason.encode!` raises `Jason.EncodeError`. `EmergencyResponse.create_dying_gasp/3` (line 845) is particularly vulnerable because it captures `gather_state_snapshot/0` (line 1010) which includes `Node.self()` (an atom) and process counts.

**Affected ZUIP Changes**: Any ZUIP publish that serializes GenServer state or system metrics.

**Likelihood**: MEDIUM (20-30%). GenServer states commonly contain PIDs and references. `DyingGasp.capture/2` explicitly captures process state which may include non-serializable terms.

**Impact**: MEDIUM. A crash in the publish path may propagate to the calling GenServer depending on error handling. In the emergency stop path, this could delay the stop sequence.

**Handling Strategy**:
1. Wrap all serialization in `try/rescue` and fall back to `inspect/1` for non-serializable terms.
2. Add a `sanitize_for_json/1` function that recursively converts PIDs to strings, references to inspect strings, etc.
3. Use `Jason.encode/1` (not `encode!`) and handle `{:error, _}` gracefully.

---

### EC-ZUIP-010: Zenoh Session Reference Becomes Stale After NIF Reload

**Condition**: The `session_ref` stored in ZenohSession state (line 48) is a NIF reference. If the Zenoh NIF is reloaded (hot code upgrade of the native module), the old reference may become invalid. `safe_publish/3` (line 525) passes the stale reference to `ZenohNIF.publish/3`, which may crash the NIF or return garbage.

**Affected ZUIP Changes**: All 32 publish points after a NIF reload.

**Likelihood**: VERY LOW (1-2%). NIF hot reload is extremely rare and usually requires a full application restart.

**Impact**: HIGH. A NIF crash takes down the entire BEAM VM.

**Handling Strategy**:
1. After any NIF reload, ZenohSession must reconnect (discard old session_ref, create new session).
2. Add NIF version tracking to ZenohSession and reconnect on version change.

---

### EC-ZUIP-011: Zenoh Publish With Nil Key or Nil Payload

**Condition**: A bug in ZUIP publish code passes `nil` for key or payload. `ZenohSession.publish/3` (line 93) has argument-dispatching logic that checks `is_binary(key_or_payload)` -- if key is nil, the dispatch may misroute the call, treating nil as the PID argument.

**Affected ZUIP Changes**: Any ZUIP publish where the key or payload is conditionally computed and may be nil.

**Likelihood**: LOW (5%). Code review should catch nil arguments.

**Impact**: MEDIUM. Either a crash in the GenServer or a malformed message to the NIF.

**Handling Strategy**:
1. Add explicit guard clauses to `publish/3`: `when is_binary(key) and is_binary(payload)`.
2. Add dialyzer specs that forbid nil.

---

### EC-ZUIP-012: Multiple ZenohSession Instances (Name Conflict)

**Condition**: `ZenohSession.start_link/1` (line 75) defaults to registering as `__MODULE__`. If two supervisors accidentally start ZenohSession, the second start fails with `{:error, {:already_started, pid}}`. However, if they use different names, two sessions connect to the router, and publishes may go through different sessions with different connection states.

**Affected ZUIP Changes**: ZUIP changes that create separate ZenohSession instances for different publish categories (e.g., one for metrics, one for safety).

**Likelihood**: LOW (5%). Intentional multi-session is a design choice, not a bug.

**Impact**: MEDIUM. Messages published on different sessions may have different ordering guarantees and different connection states.

**Handling Strategy**:
1. Document that the system uses a single ZenohSession instance per node.
2. If multiple sessions are needed, use a named registry and ensure all modules reference the correct session.

---

### EC-ZUIP-013: Zenoh Topic Depth Exceeds 6 Levels (SC-ZTEST-017)

**Condition**: ZUIP v2 proposes topics like `indrajaal/boot/cognitive/cortex/health/detailed` (7 levels). This violates SC-ZTEST-017 (topic depth <= 6 levels).

**Affected ZUIP Changes**: ZUIP topics with deeply nested hierarchies.

**Likelihood**: MEDIUM (20-30%). Easy to violate during topic design.

**Impact**: LOW. Zenoh does not enforce topic depth limits, but subscribers using wildcard patterns may not match deeply nested topics as expected.

**Handling Strategy**:
1. Validate all ZUIP topic strings against `depth(topic) <= 6` during code review.
2. Flatten deep hierarchies using compound key segments: `indrajaal/boot/cognitive-cortex/health`.

---

### EC-ZUIP-014: Concurrent ZenohSession `status/1` Calls During State Transition

**Condition**: `ZenohSession.status/1` (line 210) reads state atomically via `GenServer.call`. But multiple callers calling `ZenohSession.connected?/1` (line 199) between state transitions may get inconsistent results: one caller sees `:connected`, the next sees `:reconnecting`, even though no actual state change occurred (just mailbox ordering).

**Affected ZUIP Changes**: ZUIP changes that gate Zenoh publish on `ZenohSession.connected?()` checks.

**Likelihood**: LOW (5%). Status checks are fast and state transitions are rare.

**Impact**: LOW. A publish attempt after a false-positive connected? check results in `{:error, :not_connected}` from the actual publish handler.

**Handling Strategy**:
1. Do not pre-check `connected?()` before publishing. Just publish and handle the error.

---

### EC-ZUIP-015: System Memory Pressure During Zenoh Payload Construction

**Condition**: Constructing a Zenoh payload via `Jason.encode!/1` allocates memory for the JSON string. Under memory pressure (memory_usage > 85%, which triggers PatternHunter alerts), constructing large payloads (HealthCoordinator system health with 30 domain statuses, SmartMetrics bulk dumps) may push memory over the threshold, causing OOM or triggering Sentinel quarantine of the publishing process itself.

**Affected ZUIP Changes**: ZUIP changes constructing large payloads (system health, bulk metrics, dying gasp snapshots).

**Likelihood**: LOW (5-10%). Memory pressure severe enough to make JSON encoding fail is rare.

**Impact**: HIGH. OOM-killed processes lose state and create cascading failures.

**Handling Strategy**:
1. Set a maximum payload size limit (64KB per SC-ZTEST-016) and truncate large payloads.
2. Under memory pressure (detected by Sentinel), reduce payload detail level (summary instead of full).
3. Pre-allocate IO buffers for common publish paths to avoid dynamic allocation.

---

### EC-ZUIP-016: Zenoh Publish From Non-BEAM Process (F# Port)

**Condition**: F# modules run in a separate .NET runtime, communicating with Elixir via ports or HTTP. A Zenoh publish from F# code goes through ZenohPublish.fs which writes to stderr -- it never enters the Elixir ZenohSession. The F# "publish" and the Elixir "publish" have completely different codepaths, guarantees, and monitoring.

**Affected ZUIP Changes**: All F#-side ZUIP changes.

**Likelihood**: 100%. This is the current architecture.

**Impact**: HIGH. F# safety events are invisible to Zenoh infrastructure monitoring, dashboards, and alert systems that subscribe to Zenoh topics.

**Handling Strategy**: See RC-ZUIP-017 mitigation.

---

### EC-ZUIP-017: ZenohSession Terminate Callback + Pending Publishes

**Condition**: `ZenohSession.terminate/2` (line 490) calls `safe_close/1` (line 609) to close the Zenoh session. Any publishes queued in the GenServer mailbox at this point are dropped -- they never get processed. If the supervision tree is shutting down in order, ZenohSession may terminate before other GenServers that have pending Zenoh publishes in their shutdown handlers.

**Affected ZUIP Changes**: All ZUIP publish points in module terminate/shutdown handlers.

**Likelihood**: MEDIUM (20-30%). During shutdown, many modules publish final state simultaneously.

**Impact**: MEDIUM. Lost final-state messages reduce post-mortem analysis capability.

**Handling Strategy**:
1. ZenohSession should be the LAST supervised child to terminate (lowest restart order in the supervision tree).
2. Add a drain period in `terminate/2`: process remaining mailbox messages with a 1s deadline before closing.

---

### EC-ZUIP-018: Zenoh Message Schema Version Mismatch

**Condition**: ZUIP v2 specifies `schema_version: "2.0.0"` in messages. If a rolling upgrade changes the schema (e.g., v3.0.0 with different field names), subscribers running old code receive messages they can't parse. During the upgrade window, both schema versions coexist on the same topics.

**Affected ZUIP Changes**: All ZUIP publish points that include schema version fields.

**Likelihood**: MEDIUM (15-25%) during upgrades.

**Impact**: MEDIUM. Subscribers crash or silently ignore new-format messages.

**Handling Strategy**:
1. Use additive-only schema evolution: never remove fields, only add new ones.
2. Subscribers should `Map.get` with defaults, not pattern-match on exact shapes.
3. Include `schema_version` in every message and route to version-appropriate deserializers.

---

### EC-ZUIP-019: Telemetry Handler Crash Propagation to Publisher

**Condition**: `EmergencyResponse.emit_telemetry/2` (line 1116) calls `:telemetry.execute/3`. If a telemetry handler crashes (e.g., a handler that publishes to Zenoh), the crash propagates to the calling process. The `rescue` on line 1122 catches this, but other modules (MasterControl.publish_control_telemetry at line 602) may not have rescue handlers.

**Affected ZUIP Changes**: ZUIP changes that attach Zenoh publish as telemetry handlers.

**Likelihood**: LOW (5-10%). Telemetry handlers should not crash, but Zenoh NIF crashes are possible.

**Impact**: MEDIUM. A crash in a telemetry handler can take down the GenServer that called `:telemetry.execute`.

**Handling Strategy**:
1. All `:telemetry.execute` calls MUST be wrapped in `try/rescue`.
2. Zenoh-publishing telemetry handlers must use `try/rescue` internally.
3. Use `:telemetry.attach_many` with `:handle_event_exception` option to log rather than propagate handler crashes.

---

### EC-ZUIP-020: Zombie ZenohSession After Max Reconnect Attempts

**Condition**: After 5 failed reconnection attempts (line 449), ZenohSession enters `:failed` status (line 465). It stays in this state permanently -- there's no periodic retry or recovery mechanism. All subsequent publishes return `{:error, :not_connected}` forever until the application is restarted. This is by design (to prevent reconnection storms), but it means a transient Zenoh router failure that recovers after 30s leaves the system permanently disconnected.

**Affected ZUIP Changes**: All 32 publish points -- permanent failure after 5 reconnect attempts.

**Likelihood**: MEDIUM (15-25%). Zenoh router restarts during container updates exceed the 5-attempt budget.

**Impact**: HIGH. Permanent loss of all Zenoh telemetry until application restart.

**Handling Strategy**:
1. Add a slow-retry mechanism: after entering `:failed` state, retry every 60s (not aggressive).
2. Expose a `ZenohSession.force_reconnect/0` API that resets the counter and attempts reconnection.
3. Health endpoint should report `:failed` status prominently so operators can trigger manual reconnection.

---

## 3. Cascading Failure Scenarios

### CF-ZUIP-001: ZenohSession Crash Cascade

**Trigger**: ZenohNIF segfault during `ZenohNIF.publish/3` (called from `safe_publish/3`, line 527).

**Cascade Chain**:
1. **T+0ms**: NIF crash terminates the ZenohSession GenServer process (BEAM kills the owning process on NIF crash).
2. **T+1ms**: Supervisor restarts ZenohSession. New instance has status `:disconnected`, starts connection attempt.
3. **T+10ms**: All in-flight `GenServer.call` to ZenohSession receive `{:EXIT, pid, :killed}`, which manifests as `** (EXIT) no process` exceptions in calling GenServers (Sentinel, MasterControl, PatternHunter).
4. **T+11ms**: If callers don't handle `EXIT` signals, THEY crash. Sentinel crash means health monitoring stops. MasterControl crash means no domain control.
5. **T+50ms**: Sentinel's supervisor restarts Sentinel. New Sentinel has empty state (no threat history, no quarantine list).
6. **T+100ms**: ZenohSession reconnects. But all callers have been restarted with fresh state.
7. **T+1s**: System is running but with amnesia -- all accumulated health metrics, threat history, and quarantine state is lost.

**Blast Radius**: 3-7 GenServers (ZenohSession, Sentinel, MasterControl, PatternHunter, SymbioticDefense + any module making a synchronous Zenoh publish call at crash time).

**Time to Total Failure**: <100ms for individual GenServer crashes. ~1s for full supervision tree restart. System recovers but with state loss.

**Circuit Breaker Effectiveness**: NONE. The circuit breaker (in `circuit_breaker.ex`) protects function calls, not GenServer lifecycle. The NIF crash bypasses all circuit breaker logic.

**Mitigation**:
1. All ZUIP callers MUST use `try/catch :exit` when calling `ZenohSession.publish/3`.
2. Sentinel and MasterControl should persist critical state (quarantine list, health scores) to ETS (survives GenServer restart) or SQLite (survives node restart).
3. Add a NIF crash counter to ZenohSession. After 3 NIF crashes in 60s, disable NIF and switch to stub mode permanently.

---

### CF-ZUIP-002: Zenoh Router Down -- Total Telemetry Blackout

**Trigger**: `zenoh-router` container stops (OOM, operator error, disk full).

**Cascade Chain**:
1. **T+0s**: Zenoh router stops accepting connections.
2. **T+1s**: ZenohSession health check (every 10s) hasn't fired yet. Publishes succeed at NIF level (buffered in Zenoh client library).
3. **T+5s**: NIF buffer fills. Next publish blocks or returns error.
4. **T+10s**: ZenohSession health check fires (line 470). `safe_session_status/1` returns `{:error, reason}`. ZenohSession enters `:reconnecting` (line 480).
5. **T+10s-42s**: Reconnection attempts with exponential backoff (1s, 2s, 4s, 8s, 16s, 32s). Each attempt fails.
6. **T+42s**: Max reconnect attempts (5) reached. ZenohSession enters `:failed` (line 465). All publishes return `{:error, :not_connected}`.
7. **T+42s+**: ALL ZUIP publish points fail silently. No telemetry data flows. System operates blind.
8. **T+∞**: State persists until application restart. Even if Zenoh router is restored, ZenohSession stays `:failed`.

**Blast Radius**: All Zenoh-dependent monitoring. Prajna dashboard goes dark. Alert systems receive no data. F# orchestrator loses visibility.

**Time to Total Failure**: 42 seconds to permanent telemetry blackout.

**Circuit Breaker Effectiveness**: PARTIAL. The DegradedModeCoordinator (line 660) can suppress reconnection spam, but it doesn't restore connectivity.

**Mitigation**:
1. Log fallback (SC-ZTEST-008) MUST be active for ALL ZUIP publish points -- not just test checkpoints.
2. Add slow-retry mechanism (1 attempt every 60s) after `:failed` state.
3. Health endpoint MUST prominently report Zenoh `:failed` status.
4. Grafana dashboard should have a "Zenoh connectivity" panel that alerts on `:failed`.

---

### CF-ZUIP-003: Split-Brain Dual Apoptosis -- Complete Cluster Loss

**Trigger**: Network partition splits 3-node cluster into [1] and [2] partitions.

**Cascade Chain**:
1. **T+0s**: Network partition occurs.
2. **T+10s**: Both partitions detect partition via HealthCoordinator (10s check interval).
3. **T+10.1s**: Node in partition [1] runs `DetectSplitBrain()` (HealthCoordinator.fs line 288). Finds seed node in other partition. Returns true.
4. **T+10.1s**: Nodes in partition [2] also detect split-brain.
5. **T+10.2s**: `ShouldTriggerApoptosis()` (line 393) fires on ALL nodes. No grace period. All nodes decide to self-terminate.
6. **T+10.3s**: All nodes call `Cluster.Apoptosis.initiate/1` (line 8). `System.stop(1)` called.
7. **T+10.4s**: ZUIP Zenoh publish of "apoptosis initiated" -- but Zenoh router is in one partition. Nodes in the other partition can't reach it. Publish fails silently.
8. **T+11s**: All nodes are stopped. Cluster is completely dead. No survivor to receive clients.

**Blast Radius**: 100% -- complete cluster loss.

**Time to Total Failure**: ~11 seconds from network partition to total cluster death.

**Circuit Breaker Effectiveness**: NONE. Apoptosis bypasses all circuit breakers by design.

**Mitigation**:
1. Only the MINORITY partition should self-terminate. Majority partition survives.
2. Add 60s grace period before apoptosis. Re-check partition status after grace period.
3. Use Zenoh-published "I'm alive" heartbeats to avoid false split-brain detection.
4. Implement "fencing" instead of mutual apoptosis: the partition without the Zenoh router shuts down, the one with the router survives.

---

### CF-ZUIP-004: SmartMetrics Publish Storm Saturates ZenohSession

**Trigger**: A monitoring dashboard subscribes to SmartMetrics updates. An operator enables high-frequency polling (100ms instead of 1s). SmartMetrics records 200 metrics/second.

**Cascade Chain**:
1. **T+0s**: 200 metrics/sec enter SmartMetrics via `record/4` (line 69, GenServer.cast).
2. **T+0s**: With ZUIP Zenoh publish added, each record triggers a `ZenohSession.publish/3` call.
3. **T+0.5s**: ZenohSession mailbox has 100 pending publish calls. Each takes 2ms to process. Tail latency: 200ms.
4. **T+1s**: ZenohSession mailbox reaches 200 messages. GenServer.call callers start timing out (default 5000ms).
5. **T+5s**: First timeout. Callers receive `{:EXIT, :timeout}`. If not handled, calling GenServers crash.
6. **T+5.1s**: Sentinel's Zenoh publish times out. Sentinel crashes. Health monitoring stops.
7. **T+5.2s**: Guardian can't publish violations. MasterControl can't publish health. The system loses all safety telemetry because SmartMetrics consumed ZenohSession's capacity.

**Blast Radius**: All Zenoh-dependent modules. Safety-critical telemetry displaced by non-critical metrics.

**Time to Total Failure**: ~5 seconds from publish storm onset to safety telemetry loss.

**Circuit Breaker Effectiveness**: NONE for ZenohSession (no circuit breaker on the session itself). PARTIAL for individual callers (their own circuit breakers may trip).

**Mitigation**:
1. SmartMetrics MUST use TelemetryBatcher: accumulate updates for 5s, publish 1 batch.
2. ZenohSession MUST implement priority queuing: safety publishes jump ahead of metrics.
3. Add back-pressure: if ZenohSession mailbox exceeds 50 messages, drop non-critical publishes.
4. Rate-limit SmartMetrics Zenoh publishes to max 1/second.

---

### CF-ZUIP-005: PatternHunter False-Positive Feedback Loop

**Trigger**: ZUIP adds Zenoh publish to PatternHunter detection reports. The publish causes a brief CPU spike.

**Cascade Chain**:
1. **T+0ms**: PatternHunter scan detects elevated CPU (from previous Zenoh publish overhead).
2. **T+0.5ms**: PatternHunter publishes "CPU spike detected" to Zenoh. This takes 2ms and causes a micro-CPU-spike.
3. **T+500ms**: Next scan detects continued CPU elevation (from the publish at T+0.5ms).
4. **T+500.5ms**: PatternHunter publishes another "CPU spike detected".
5. **T+1000ms**: Cycle repeats. After 10 cycles (5s), PatternHunter has published 10 alerts.
6. **T+5s**: SymbioticDefense receives 10 threat reports and escalates defense level from :normal to :guarded.
7. **T+5.1s**: :guarded level triggers throttling and resource limits, which ACTUALLY degrades performance.
8. **T+10s**: Real performance degradation triggers more PatternHunter alerts. Self-reinforcing loop.
9. **T+30s**: Defense level reaches :critical. System enters recovery mode unnecessarily.

**Blast Radius**: SymbioticDefense, Sentinel, all modules affected by throttling.

**Time to Total Failure**: ~30 seconds from false positive to unnecessary recovery mode.

**Circuit Breaker Effectiveness**: NONE. The feedback loop operates through the normal threat reporting path.

**Mitigation**:
1. PatternHunter MUST implement self-exclusion: filter out its own publish activity from metrics.
2. Implement a "same pattern, same source" cooldown: max 1 alert per pattern per 30 seconds.
3. SymbioticDefense should require sustained elevation (>60s of threats) before escalating past :elevated.

---

### CF-ZUIP-006: Guardian Validation Timeout Cascade

**Trigger**: ZenohSession mailbox full (from SmartMetrics storm, CF-ZUIP-004). A Guardian validation includes a Zenoh publish that blocks.

**Cascade Chain**:
1. **T+0ms**: MasterControl calls `Guardian.validate_proposal/2` (line 132) for a domain command.
2. **T+0.1ms**: Guardian's `do_validate_proposal/1` includes a ZUIP Zenoh publish (e.g., audit logging).
3. **T+0.1ms**: Zenoh publish blocks -- ZenohSession mailbox has 200 messages.
4. **T+5000ms**: Guardian's internal GenServer.call to ZenohSession times out.
5. **T+5000ms**: Guardian's validate handler crashes with timeout.
6. **T+5001ms**: MasterControl receives `{:EXIT, :timeout}` from Guardian. If unhandled, MasterControl crashes.
7. **T+5002ms**: Without MasterControl, no domain commands can execute. Emergency stop via MasterControl.emergency_stop/1 fails.
8. **T+5003ms**: Operator must use Guardian.emergency_stop/1 directly, but Guardian is also restarting after crash.

**Blast Radius**: Guardian + MasterControl + all domain command execution.

**Time to Total Failure**: ~5 seconds from Zenoh blockage to complete control plane loss.

**Circuit Breaker Effectiveness**: MasterControl's domain circuit breakers don't protect the Guardian path.

**Mitigation**:
1. Guardian MUST NEVER make synchronous Zenoh calls. All Guardian Zenoh integration must be fire-and-forget.
2. Guardian's existing `log_violation/2` (line 873) pattern is correct -- use `try/rescue` with no blocking.
3. Add a separate audit log path (ETS + periodic Zenoh batch) instead of inline Zenoh publish.

---

### CF-ZUIP-007: DyingGasp + EmergencyResponse + Guardian Triple Stop Race

**Trigger**: Constitutional violation detected. Three modules simultaneously initiate emergency stop.

**Cascade Chain**:
1. **T+0ms**: `EmergencyResponse.do_emergency_response/2` (line 911) detects `{:constitutional_violation, _}`. Calls `emergency_stop/2` (line 934).
2. **T+0.1ms**: `emergency_stop/2` calls `Guardian.emergency_stop(reason)` (line 275).
3. **T+0.2ms**: Guardian spawns `execute_emergency_stop/2` (line 276) AND casts to GenServer (line 281). Two parallel stop sequences.
4. **T+0.3ms**: EmergencyResponse creates emergency checkpoint (line 278). Calls `DyingGasp.capture/2` implicitly.
5. **T+0.5ms**: ZUIP adds Zenoh publish to all three stop paths. Three concurrent Zenoh publish attempts.
6. **T+0.5ms**: ZenohSession processes publishes sequentially. Guardian's stop sequence waits behind EmergencyResponse's publish.
7. **T+2ms**: First `:init.stop(1)` call (from Guardian, line 520). BEAM begins shutdown.
8. **T+2.1ms**: EmergencyResponse's Zenoh publish completes, but the BEAM is already stopping. The publish result is discarded.
9. **T+2.2ms**: DyingGasp's Zenoh publish attempt receives `{:error, :noproc}` -- ZenohSession already terminated.

**Blast Radius**: N/A -- the system is intentionally terminating. But the telemetry is incomplete.

**Time to Total Failure**: 2ms to BEAM halt (intentional).

**Circuit Breaker Effectiveness**: N/A -- circuit breakers are irrelevant during intentional termination.

**Mitigation**:
1. Emergency stop Zenoh publishes MUST be fire-and-forget with zero blocking (spawn + publish + ignore result).
2. Disk checkpoint (DyingGasp) is authoritative; Zenoh publish is best-effort advisory.
3. Use `:persistent_term.put({:emergency_stop_in_progress, true})` to signal other modules to skip Zenoh.

---

### CF-ZUIP-008: Supervision Tree Restart Storm

**Trigger**: ZenohNIF crash during startup causes ZenohSession crash. Supervisor restarts it. It crashes again (same NIF bug). Supervisor restarts again. After `max_restarts` (default 3 in 5s), supervisor gives up and crashes.

**Cascade Chain**:
1. **T+0s**: ZenohSession crashes (NIF bug). Supervisor restarts it.
2. **T+1s**: ZenohSession crashes again. Supervisor restarts.
3. **T+2s**: ZenohSession crashes again. Supervisor restarts.
4. **T+3s**: ZenohSession crashes again. Supervisor has exceeded `max_restarts`.
5. **T+3s**: Supervisor crashes. If ZenohSession is under the main application supervisor, ALL supervised children terminate.
6. **T+3.1s**: Guardian, Sentinel, MasterControl, SmartMetrics all terminate.
7. **T+3.2s**: Application supervisor may restart the entire subtree, but ZenohSession will crash again.
8. **T+3.3s**: Application terminates.

**Blast Radius**: Potentially the entire application if ZenohSession is under a top-level supervisor.

**Time to Total Failure**: ~3 seconds from first NIF crash to application termination.

**Circuit Breaker Effectiveness**: NONE. Supervision tree restart limits are the only protection.

**Mitigation**:
1. ZenohSession should be in its own supervisor with `:rest_for_one` or `:one_for_one` strategy, NOT under the main supervisor.
2. After 3 consecutive NIF crashes, ZenohSession should disable the NIF and run in stub mode permanently.
3. The supervisor's `max_restarts` should be set high (10 in 60s) to avoid cascading shutdown.

---

### CF-ZUIP-009: Zenoh Message Storm from External Subscriber

**Trigger**: A malicious or misconfigured external Zenoh subscriber publishes high-volume messages to topics that Indrajaal subscribes to.

**Cascade Chain**:
1. **T+0s**: External publisher floods `indrajaal/control/**` at 10,000 msg/sec.
2. **T+0.1s**: ZenohSession receives messages via subscriber callbacks. Each message is delivered to registered `callback_pid` processes.
3. **T+0.5s**: Callback process mailboxes fill up. GenServer processes (Sentinel, MasterControl) that subscribed to control topics become unresponsive.
4. **T+1s**: Sentinel's mailbox is full. Health checks can't be processed. Health monitoring stops.
5. **T+5s**: GenServer.call timeouts cascade. MasterControl, Guardian become unreachable.
6. **T+10s**: System is functionally dead despite no internal failure -- all GenServers are choked by incoming messages.

**Blast Radius**: All Zenoh-subscribing modules.

**Time to Total Failure**: ~5-10 seconds.

**Circuit Breaker Effectiveness**: NONE. The attack bypasses all internal circuit breakers.

**Mitigation**:
1. Rate-limit incoming Zenoh messages per topic: max 100 msg/sec per subscriber.
2. Use bounded mailboxes (process dictionary flag + selective receive) for GenServers that subscribe to Zenoh.
3. Zenoh subscriber callbacks should deposit messages in a bounded queue (`:queue` module, max 1000), not directly to GenServer mailbox.
4. Authentication/authorization on Zenoh router to prevent unauthorized publishers.

---

### CF-ZUIP-010: Cascading Circuit Breaker Avalanche

**Trigger**: A single domain failure (e.g., `:alarms` database connection lost) trips the alarms circuit breaker in MasterControl.

**Cascade Chain**:
1. **T+0s**: Alarms domain health check returns `:failed`. Circuit breaker `failure_count` increments.
2. **T+30s**: After 3 consecutive failures (line 525), alarms circuit breaker opens.
3. **T+30s**: ZUIP publishes "circuit breaker opened for :alarms" to Zenoh.
4. **T+30.1s**: Downstream domains (:communication, :dispatch, :analytics -- adjacent to :alarms per line 471) detect alarms is unavailable. Their operations that depend on alarms start failing.
5. **T+60s**: Communication domain failures reach threshold. Communication circuit breaker opens.
6. **T+60s**: ZUIP publishes "circuit breaker opened for :communication".
7. **T+90s**: Dispatch and analytics breakers open. Cascade has propagated to 4 domains.
8. **T+120s**: Half the system is circuit-breaker-protected. Operators see a wall of open breakers.

**Blast Radius**: 4-10 domains depending on dependency graph.

**Time to Total Failure**: 60-120 seconds for full cascade.

**Circuit Breaker Effectiveness**: IRONIC -- the circuit breakers ARE the cascade mechanism in this scenario. They protect individual domains but the cascade of "circuit breaker open" events overwhelms operators.

**Mitigation**:
1. Circuit breaker opening should NOT trigger dependent domain failures. Breakers should isolate, not cascade.
2. Add a "system-level circuit breaker" that detects when >3 domain breakers are open simultaneously and enters system-wide degraded mode.
3. ZUIP Zenoh messages for breaker state changes should include dependency information.

---

### CF-ZUIP-011: Memory Exhaustion from Unbounded Zenoh Payload Accumulation

**Trigger**: ZenohSession is disconnected. ZUIP callers construct payloads but publishes return `{:error, :not_connected}`. The callers may buffer payloads for retry.

**Cascade Chain**:
1. **T+0s**: ZenohSession enters `:reconnecting` state.
2. **T+0-42s**: All ZUIP publishes fail with `{:error, :not_connected}`.
3. **T+0-42s**: If callers buffer payloads for retry (common pattern), each failed publish adds payload to a buffer.
4. **T+10s**: SmartMetrics has buffered 2000 payloads (200/sec * 10s). At ~1KB each = 2MB.
5. **T+42s**: SmartMetrics buffer: 8400 payloads = 8.4MB. HealthCoordinator buffer: 4 payloads = 400KB. MasterControl: 1 payload = 10KB. Sentinel: 8 payloads = 80KB.
6. **T+42s**: ZenohSession enters `:failed`. Buffers never drain.
7. **T+300s (5 min)**: If SmartMetrics continues buffering: 60,000 payloads = 60MB.
8. **T+3600s (1 hour)**: 720,000 payloads = 720MB. Memory pressure triggers Sentinel alerts.

**Blast Radius**: Memory consumption affects all processes on the node.

**Time to Total Failure**: 1-24 hours depending on buffer growth rate and total system memory.

**Circuit Breaker Effectiveness**: NONE. Buffering happens in the caller, not in a circuit-breaker-protected path.

**Mitigation**:
1. ZUIP callers MUST NOT buffer failed publishes. Drop on failure after logging.
2. If buffering is desired, use a bounded ring buffer (max 100 messages, oldest dropped first).
3. Add a "Zenoh connected" health check to callers: if disconnected for >60s, stop constructing payloads entirely.

---

### CF-ZUIP-012: Telemetry Handler + ZUIP Publish Infinite Recursion

**Trigger**: A telemetry handler attached to `[:zenoh, :session, :connected]` (line 405) publishes a "Zenoh connected" message to Zenoh. This publish triggers the same telemetry event, which triggers the handler again.

**Cascade Chain**:
1. **T+0ms**: ZenohSession connects. Emits `[:zenoh, :session, :connected]` telemetry (line 405).
2. **T+0.1ms**: Telemetry handler receives event. Publishes "session_connected" to Zenoh.
3. **T+0.2ms**: Publication succeeds. ZenohSession emits `[:zenoh, :publish, :success]` telemetry (if ZUIP adds this).
4. **T+0.3ms**: Another handler on `[:zenoh, :publish, :success]` logs to Zenoh. Triggers another publish.
5. **T+0.4ms**: Stack overflow or infinite GenServer.call chain.

**Blast Radius**: ZenohSession + calling process.

**Time to Total Failure**: <1ms (stack overflow) or ~5s (GenServer.call chain timeout).

**Circuit Breaker Effectiveness**: NONE. Recursion happens synchronously before any circuit breaker can act.

**Mitigation**:
1. NEVER attach Zenoh publish as a handler for Zenoh-related telemetry events.
2. Add a re-entrancy guard: `Process.put(:zenoh_publishing, true)` before publish, check before re-entering.
3. Use `Process.get(:zenoh_publish_depth, 0)` and abort if depth > 1.

---

## 4. Stale State Windows

For each ZUIP mutation point, the stale state window is the time between the state mutation and the Zenoh publish completing. During this window, Zenoh subscribers see the OLD state.

| ZUIP Change Location | Module | Mutation | Zenoh Publish Point | Window (ms) | Classification |
|---|---|---|---|---|---|
| Sentinel health score update | `sentinel.ex` | GenServer state update | After `calculate_health/1` | 0.5-2 | SAFE (<10ms) |
| Sentinel quarantine action | `sentinel.ex` | `:erlang.suspend_process/1` | After quarantine | 1-5 | SAFE (<10ms) |
| Sentinel threat detection | `sentinel.ex` | Threat list append | After `report_threat/3` | 1-5 | SAFE (<10ms) |
| PatternHunter detection | `pattern_hunter.ex` | Detection list append | After pattern match | 0.5-2 | SAFE (<10ms) |
| PatternHunter learned pattern | `pattern_hunter.ex` | Pattern DB update | After learning | 2-10 | SAFE (<10ms) |
| SymbioticDefense level change | `symbiotic_defense.ex` | Defense level state | After escalation decision | 1-5 | SAFE (<10ms) |
| SymbioticDefense recovery | `symbiotic_defense.ex` | Recovery state | After recovery attempt | 50-500 | CONCERNING (>100ms) |
| Guardian proposal validation | `guardian.ex` | Validation counter | After `do_validate_proposal/1` | 1-5 | SAFE (<10ms) |
| Guardian emergency stop | `guardian.ex` | Emergency state | After `emergency_stop/1` | 0-100 | ACCEPTABLE (<100ms) |
| Guardian threat report | `guardian.ex` | Threat log append | After `report_threat/1` | 1-5 | SAFE (<10ms) |
| EmergencyResponse activation | `emergency_response.ex` | Apoptosis state init | After activation | 0-50 | ACCEPTABLE (<100ms) |
| EmergencyResponse phase advance | `emergency_response.ex` | Phase field update | After `advance_phase/2` | 1-5 | SAFE (<10ms) |
| EmergencyResponse dying gasp | `emergency_response.ex` | Checkpoint save | After `create_dying_gasp/3` | 50-3000 | DANGEROUS (>1s) |
| EmergencyResponse emergency stop | `emergency_response.ex` | Stop state | After `emergency_stop/2` | 0-200 | CONCERNING (>100ms) |
| MasterControl health check | `master_control.ex` | Health scores map | After domain health eval | 10-300 | CONCERNING (>100ms) |
| MasterControl command execution | `master_control.ex` | Effect tracker | After `execute_domain_action` | 5-50 | ACCEPTABLE (<100ms) |
| MasterControl circuit breaker | `master_control.ex` | Breaker state | After threshold check | 1-5 | SAFE (<10ms) |
| MasterControl emergency stop | `master_control.ex` | Status field | After broadcast to domains | 10-100 | ACCEPTABLE (<100ms) |
| SmartMetrics record | `smart_metrics.ex` | ETS table entry | After ETS insert | 0.5-2 | SAFE (<10ms) |
| SmartMetrics staleness check | `smart_metrics.ex` | Stale detection | After staleness eval | 1-5 | SAFE (<10ms) |
| HealthCoordinator check | `health_coordinator.ex` | Health reports map | After FPPS consensus | 100-5000 | DANGEROUS (>1s) |
| HealthCoordinator quorum | `health_coordinator.ex` | Quorum status | After quorum calculation | 1-10 | SAFE (<10ms) |
| CircuitBreaker state transition | `circuit_breaker.ex` | FSM state | After transition logic | 1-5 | SAFE (<10ms) |
| DyingGasp capture | `dying_gasp.ex` | Checkpoint file | After disk write | 50-3000 | DANGEROUS (>1s) |
| Apoptosis initiation | `apoptosis.ex` | Terminal state | After Logger.flush | 0-100 | ACCEPTABLE (<100ms) |
| HealthCoordinator.fs boot | `HealthCoordinator.fs` | F# state | After health eval | N/A (F# wire gap) | DANGEROUS (infinite) |
| Apoptosis.fs initiation | `Apoptosis.fs` | F# state | After phase execution | N/A (F# wire gap) | DANGEROUS (infinite) |

**Summary**:
- **SAFE** (<10ms): 14 mutation points
- **ACCEPTABLE** (<100ms): 5 mutation points
- **CONCERNING** (100ms-1s): 3 mutation points
- **DANGEROUS** (>1s or infinite): 5 mutation points

**DANGEROUS classifications require mitigation before ZUIP implementation.**

---

## 5. Failure Mode Enumeration

| ID | Description | Trigger Condition | Severity | Occurrence | Detection | RPN | Existing Mitigation | Required New Mitigation |
|---|---|---|---|---|---|---|---|---|
| FM-ZUIP-001 | ZenohSession mailbox overflow | >50 concurrent publish calls | 7 | 5 | 4 | 140 | None | Priority queue, async publish API |
| FM-ZUIP-002 | Emergency stop SLA violation | Sync Zenoh publish in stop path | 9 | 3 | 7 | 189 | SC-EMR-057 deadline | Fire-and-forget publish, 200ms hard timeout |
| FM-ZUIP-003 | Dual apoptosis (cluster loss) | Split-brain + no grace period | 10 | 2 | 8 | 160 | None | Grace period, leader election, jitter |
| FM-ZUIP-004 | NIF crash cascade | ZenohNIF segfault | 9 | 2 | 8 | 144 | NIF isolation (BEAM kills process) | NIF crash counter, stub mode fallback |
| FM-ZUIP-005 | SmartMetrics publish storm | 200 records/sec * Zenoh publish | 7 | 6 | 3 | 126 | None | TelemetryBatcher, rate limit |
| FM-ZUIP-006 | Guardian validation timeout | Zenoh publish blocks Guardian | 8 | 3 | 6 | 144 | try/rescue in log_violation | No sync Zenoh in Guardian, fire-and-forget only |
| FM-ZUIP-007 | PatternHunter feedback loop | Publish overhead detected as anomaly | 6 | 4 | 4 | 96 | None | Self-exclusion, cooldown, rate limit |
| FM-ZUIP-008 | Permanent Zenoh disconnection | 5 failed reconnects | 7 | 4 | 3 | 84 | DegradedModeCoordinator | Slow-retry (60s), manual reconnect API |
| FM-ZUIP-009 | F# Wire Gap (silent failure) | All F#-side publishes | 9 | 10 | 2 | 180 | stderr fallback | HTTP bridge, sidecar parser |
| FM-ZUIP-010 | Jason.encode! crash | Non-serializable state data | 6 | 4 | 5 | 120 | Partial (try/rescue in some modules) | Universal sanitize_for_json/1 helper |
| FM-ZUIP-011 | DyingGasp publish during BEAM halt | `:init.stop(1)` called | 5 | 7 | 3 | 105 | Disk checkpoint is authoritative | Fire-and-forget, skip if stopping |
| FM-ZUIP-012 | Telemetry handler crash propagation | `:telemetry.execute` handler crashes | 7 | 3 | 5 | 105 | Partial (rescue in EmergencyResponse) | Universal try/rescue on all telemetry calls |
| FM-ZUIP-013 | PubSub-to-Zenoh amplification | Naive bridge, 200 msg/sec | 7 | 5 | 3 | 105 | None | Topic filtering, rate limit, batching |
| FM-ZUIP-014 | Stale state in FPPS consensus | Publish before consensus complete | 5 | 4 | 4 | 80 | None | Publish after consensus, epoch counter |
| FM-ZUIP-015 | Supervision tree restart storm | Repeated NIF crashes | 9 | 2 | 5 | 90 | Supervisor max_restarts | Isolate ZenohSession supervisor, stub mode |
| FM-ZUIP-016 | Circuit breaker cascade avalanche | Multi-domain failure propagation | 6 | 3 | 4 | 72 | Individual domain breakers | System-level breaker, dependency-aware isolation |
| FM-ZUIP-017 | Memory leak from payload buffering | Caller buffers during disconnection | 7 | 4 | 3 | 84 | None | Bounded ring buffer, drop on failure |
| FM-ZUIP-018 | Telemetry publish infinite recursion | Handler publishes to same topic | 8 | 2 | 6 | 96 | None | Re-entrancy guard, depth check |
| FM-ZUIP-019 | Unicode key expression crash | Special chars in container name | 5 | 2 | 5 | 50 | None | Key sanitization before publish |
| FM-ZUIP-020 | Zombie ZenohSession (connected but dead router) | Router crash, container alive | 8 | 2 | 2 | 32 | Health check every 10s | E2E probe (self-subscribe + verify) |
| FM-ZUIP-021 | Schema version mismatch | Rolling upgrade | 5 | 4 | 4 | 80 | None | Additive-only evolution, version routing |
| FM-ZUIP-022 | ZenohSession terminate drops queued messages | Shutdown ordering | 5 | 5 | 3 | 75 | None | Drain period in terminate, last-to-stop ordering |
| FM-ZUIP-023 | Payload exceeds 64KB (SC-ZTEST-016) | Large state snapshot | 6 | 3 | 5 | 90 | None | Size check, reference-based publish |
| FM-ZUIP-024 | Topic depth exceeds 6 (SC-ZTEST-017) | Deeply nested topic design | 3 | 4 | 3 | 36 | None | Topic validation in code review |
| FM-ZUIP-025 | Concurrent ETS + PubSub + Zenoh inconsistency | Triple-write non-atomicity | 3 | 8 | 2 | 48 | None | Sequence numbers, batching |
| FM-ZUIP-026 | External Zenoh message flood (DoS) | Malicious publisher | 8 | 2 | 4 | 64 | None | Rate limiting, auth, bounded queues |
| FM-ZUIP-027 | Guardian double-execution duplicate messages | spawn + cast both run | 4 | 10 | 2 | 80 | Intentional redundancy | AtomicBoolean, execution_id dedup |
| FM-ZUIP-028 | Sentinel + PatternHunter duplicate alerts | Same event, two detectors | 3 | 8 | 2 | 48 | None | Deduplication ID |
| FM-ZUIP-029 | ZenohSession reconnect race | Publish during status transition | 5 | 5 | 4 | 100 | Returns {:error, :not_connected} | Message queue during reconnection |
| FM-ZUIP-030 | Hot code upgrade stale NIF reference | NIF reload invalidates session_ref | 9 | 1 | 7 | 63 | Rare occurrence | NIF version tracking, auto-reconnect |
| FM-ZUIP-031 | Apoptosis phase message out-of-order | Different topics or processes | 4 | 3 | 4 | 48 | None | Same topic, sequence numbers |
| FM-ZUIP-032 | MasterControl health check blocks commands | 30-domain evaluation + publish | 5 | 4 | 3 | 60 | None | Batch publish, Task.async |
| FM-ZUIP-033 | ETS table not created race during startup | Module init ordering | 7 | 2 | 5 | 70 | None | Pre-check :ets.whereis before lookup |
| FM-ZUIP-034 | System memory pressure during payload construction | Low memory + large payloads | 7 | 2 | 4 | 56 | None | Max payload size, truncation under pressure |
| FM-ZUIP-035 | nil key or payload to ZenohSession | Bug in publish call site | 6 | 2 | 6 | 72 | Argument dispatching logic | Explicit guard clauses, dialyzer |

---

## Summary Statistics

| Category | Count | Highest RPN | Critical Items |
|----------|-------|-------------|----------------|
| Race Conditions | 18 | RC-ZUIP-002 (Emergency Stop SLA) | RC-ZUIP-002, RC-ZUIP-003, RC-ZUIP-017 |
| Edge Cases | 20 | EC-ZUIP-007 (Zombie Router) | EC-ZUIP-016 (F# Wire Gap), EC-ZUIP-020 (Zombie Session) |
| Cascading Failures | 12 | CF-ZUIP-003 (Dual Apoptosis) | CF-ZUIP-001, CF-ZUIP-003, CF-ZUIP-006 |
| Stale State Windows | 27 | N/A | 5 DANGEROUS, 3 CONCERNING |
| Failure Modes | 35 | FM-ZUIP-002 (RPN 189) | FM-ZUIP-002, FM-ZUIP-009, FM-ZUIP-003 |

### Top 5 Risks by RPN

1. **FM-ZUIP-002** (RPN 189): Emergency stop SLA violation from sync Zenoh publish
2. **FM-ZUIP-009** (RPN 180): F# Wire Gap -- safety events invisible to Zenoh
3. **FM-ZUIP-003** (RPN 160): Dual apoptosis causing complete cluster loss
4. **FM-ZUIP-001** (RPN 140): ZenohSession mailbox overflow under load
5. **FM-ZUIP-004** (RPN 144): NIF crash cascade taking down multiple GenServers

### Mandatory Pre-Implementation Actions

Before any ZUIP change is implemented:

1. **Add `publish_async/3` to ZenohSession** (fire-and-forget API using GenServer.cast)
2. **Implement priority queue in ZenohSession** (:critical > :high > :normal)
3. **Add TelemetryBatcher** for high-frequency publishers (SmartMetrics, PatternHunter)
4. **Close the F# Wire Gap** (HTTP bridge or sidecar parser at minimum)
5. **Add grace period to `ShouldTriggerApoptosis()`** in HealthCoordinator.fs (minimum 30s)
6. **Wrap ALL emergency stop Zenoh publishes** in fire-and-forget with zero blocking
7. **Add slow-retry mechanism** to ZenohSession after `:failed` state (1 attempt/60s)
8. **Universal `sanitize_for_json/1`** helper for all Zenoh payload construction
9. **Isolate ZenohSession** in its own supervisor (not under main application supervisor)
10. **Add re-entrancy guard** for telemetry handlers that publish to Zenoh

---

## Document Control

| Field | Value |
|-------|-------|
| Version | 3.0.0 |
| Created | 2026-03-18 |
| Author | Cybernetic Architect (Claude Opus 4.6) |
| STAMP | SC-FMEA-001, SC-ZTEST-001 to SC-ZTEST-020, SC-EMR-057, SC-SIL6-015 |
| SIL | SIL-6 (Biomorphic Extended) |
| Reviewed | Pending |
| Approved | Pending |

## Related Documents

| Document | Location |
|----------|----------|
| ZUIP v1 | `docs/architecture/ZENOH_UNIVERSAL_INTEGRATION_PLAN.md` |
| ZUIP v2 | `docs/architecture/ZENOH_UNIVERSAL_INTEGRATION_PLAN_V2.md` |
| Zenoh Test Messaging Rules | `.claude/rules/zenoh-test-messaging.md` |
| Immune System Rules | `.claude/rules/immune-system.md` |
| F# SIL-6 Mesh Rules | `.claude/rules/fsharp-sil6-mesh.md` |
