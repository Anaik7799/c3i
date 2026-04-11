# Journal: Microservice Split Operational Impact — 2026-04-11 05:45 CEST

**Date**: 2026-04-11
**Duration**: ~15 minutes
**Author**: Claude Opus 4.6
**Version**: v22.5.0-CORTEX
**STAMP**: SC-ARCH-SPLIT-001, SC-HA-001, SC-FUNC-002

---

## 1. Scope & Trigger

Follow-up to the microservice decomposition analysis. Operator asked: "what is the operational impact of this split" — requiring honest cost-benefit analysis of splitting the 9,104 LOC monolith into 6 services.

---

## 2. Pre-State Assessment

### Current Operational Metrics

| Metric | Value |
|--------|-------|
| Binary size | 18MB (single sa-plan-daemon) |
| Smriti.db size | 5.6MB (all 6 tables) |
| Startup time | 103ms (status command) |
| Intent throughput | ~12/day (85 over ~7 days) |
| Pipeline avg latency | 3,582ms end-to-end |
| Trace stages per intent | 5.9 average |
| Cache entries | 293 (42 new/day) |
| Conversation messages | 32 (4.6/day) |

### Data Volume by Table

| Table | Rows | Bytes |
|-------|------|-------|
| Tasks | 2,710 | 227KB |
| SemanticCache | 293 | 128KB |
| TransactionTrace | 500 | 46KB |
| UserPreferences | 137 | 11KB |
| ConversationHistory | 32 | 12KB |
| TransactionSummary | 85 | 8KB |
| **Total** | **3,757** | **432KB** |

---

## 3. Execution Detail

### 3.1 What Gets Better (4 dimensions)

**Fault Isolation (+++)**
- Today: inference OOM kills tasks, gateway, tracing — total outage
- After: only sa-infer restarts, other 5 services unaffected
- Critical because inference cascade (3-8s LLM calls) is the most failure-prone component

**Independent Scaling (++)**
- sa-infer: can run multiple instances for parallel LLM requests
- sa-gateway: can split Telegram and GChat into separate processes
- Today: can't scale inference without scaling everything

**Deploy Velocity (++)**
- Today: every change = recompile 9,104 LOC + restart entire daemon
- After: recompile only affected service (700-2,300 LOC) + restart that service only
- Inference model config change: restart sa-infer (< 100ms), zero downtime for tasks

**Observability (++)**
- Per-service memory, CPU, latency attribution
- Granular health: "sa-infer degraded, sa-plan healthy" instead of "daemon degraded"
- Each service publishes own Zenoh heartbeat

### 3.2 What Gets Worse (4 dimensions)

**Operational Complexity (--)**
- 6 processes to manage instead of 1
- 6 systemd units, 6 log streams, 6 config files
- Startup ordering required: Zenoh → sa-infra → sa-plan → sa-gateway → sa-observe → sa-cortex
- Mitigation: `sa-mesh-up` launcher script or `sa-supervisor` parent process

**Latency Overhead (Negligible)**
- +2ms total (4 Zenoh hops × 0.5ms each)
- On a 3,582ms pipeline: +0.06% — unmeasurable
- Zenoh pub/sub on localhost is sub-millisecond

**Debugging Distributed Flows (-)**
- Intent failure requires correlating across 6 log streams
- Mitigation: PipelineTracer already publishes to Zenoh centrally; add intent_id correlation header to all messages

**Disk Usage (-)**
- 5 SQLite files instead of 1 (~same total size, more file handles)
- ~35MB binaries total instead of 18MB (shared deps compiled per service)
- Mitigation: Cargo workspace shares compiled dependencies

### 3.3 What Doesn't Change

| Unchanged | Why |
|-----------|-----|
| Gleam UI (49 Lustre pages) | Calls NIFs → doesn't care about Rust process count |
| Telegram Mini App (14 pages) | Hits Wisp on 4100 → backend invisible |
| MCP tools (47) | Zenoh MoZ dispatch → same topic, different subscriber |
| RETE-UL rules (52) | Pure computation in sa-infra |
| Test suite (3,641 tests) | Tests call init()/update() → independent of Rust |
| Operator experience | Three Voices work identically |
| Consistency model | Already eventual consistent via Zenoh async pub/sub |

---

## 4. Root Cause Analysis

### Why the split matters

The monolith has a **single point of failure.** The inference cascade is the most crash-prone component (external HTTP calls to Gemini/OpenRouter, 3-8s timeouts, potential OOM on large responses). When it crashes, it takes down:
- Task management (operators can't query/update tasks)
- Pipeline tracing (observability goes blind)
- Gateway (no messages delivered)
- Heartbeat (proactive monitoring stops)

At 12 intents/day and growing, this is an increasing risk.

### Why the split can wait

The system is currently in dev/staging. There is one operator. Downtime is measured in seconds (daemon auto-restarts). The complexity cost of 6 processes is real. **The split becomes worth it when production operators depend on continuous availability.**

---

## 5. Fix Taxonomy

| Category | Impact |
|----------|--------|
| Fault isolation | Transforms single-point-of-failure into graceful degradation |
| Scaling | Enables horizontal scaling of bottleneck (inference) |
| Deployment | Enables zero-downtime rolling updates per service |
| Complexity | Adds 6x process management overhead |

---

## 6. Patterns & Anti-Patterns Discovered

### Patterns
- **Zenoh absorbs distribution cost:** Sub-millisecond localhost pub/sub means splitting adds negligible latency (+0.06%)
- **Already eventual consistent:** System was designed for async messaging — the split doesn't change the consistency model, just makes it explicit
- **PipelineTracer solves distributed tracing:** Intent correlation already works across stages — extending it across services is trivial

### Anti-Patterns
- **Premature decomposition:** Splitting before production traffic exists adds complexity without immediate benefit
- **6 processes for 12 intents/day:** The throughput doesn't justify the operational overhead yet

---

## 7. Verification Matrix

| Analysis | Method | Result |
|----------|--------|--------|
| Latency overhead | Zenoh localhost pub/sub measurement | ~0.5ms per hop, 2ms total |
| Pipeline impact | 2ms / 3,582ms avg | +0.06% (negligible) |
| Binary size impact | Shared deps estimate | ~35MB total vs 18MB monolith |
| Startup order | Dependency graph analysis | 6-step ordered sequence |
| Consistency impact | Existing async patterns audit | No change to consistency model |
| Fault blast radius | Per-module crash analysis | Monolith: total, Split: per-service |

---

## 8. Files Modified

No files modified — pure analysis. Output in this journal entry.

---

## 9. Architectural Observations

### The Decision Framework

| Condition | Recommendation |
|-----------|---------------|
| Dev/staging, single operator | Keep monolith — complexity cost not justified |
| Production, 1-3 operators, < 100 intents/day | Extract sa-gateway + sa-infer only (2 services + remaining monolith) |
| Production, 3+ operators, > 100 intents/day | Full 6-service split |
| Multi-node deployment (federation) | Full split mandatory — services distributed across nodes |

### The Incremental Path

The monolith doesn't need to become 6 services overnight. The recommended path:

1. **Now:** Keep monolith for dev velocity
2. **First production deploy:** Extract sa-gateway (clean I/O boundary, proves Zenoh RPC pattern)
3. **When inference becomes bottleneck:** Extract sa-infer (enables scaling)
4. **When operating multiple nodes:** Full decomposition

Each step is independently valuable and reversible.

---

## 10. Remaining Gaps

| Gap | When needed |
|-----|------------|
| `sa-mesh-up` launcher script for multi-service startup | Phase 2 (first extraction) |
| Per-service Zenoh heartbeat protocol | Phase 2 |
| Distributed log aggregation (intent_id correlation) | Phase 3 |
| Service health dashboard in Gleam UI | Phase 3 |
| Cargo workspace setup with shared types crate | Phase 2 |

---

## 11. Metrics Summary

| Metric | Monolith | 6 Services | Verdict |
|--------|----------|-----------|---------|
| Fault blast radius | Total | Per-service | **Better** |
| Inference scaling | Impossible | Horizontal | **Better** |
| Deploy granularity | All-or-nothing | Per-service | **Better** |
| Observability | Aggregate | Per-service | **Better** |
| Processes to manage | 1 | 6 | **Worse** |
| Latency overhead | 0ms | +2ms (0.06%) | **Negligible** |
| Debug complexity | Single log | 6 logs (correlated) | **Slightly worse** |
| Disk usage | 18MB + 5.6MB | ~35MB + ~5.6MB | **Slightly worse** |
| Consistency model | Eventual | Eventual (same) | **Unchanged** |
| Operator experience | N/A | N/A | **Unchanged** |

---

## 12. STAMP & Constitutional Alignment

| Constraint | Assessment |
|-----------|-----------|
| SC-FUNC-002 | Core services operational — split improves by isolating failures |
| SC-HA-001 | SIL-6 availability — split enables per-service failover |
| SC-SIL4-007 | Dying gasp — each service gets independent checkpoint |
| SC-ZENOH-001 | Zenoh mandatory — split enforces all communication via Zenoh |
| SC-XHOLON-001 | Holon sovereignty — each service owns its own SQLite |
| SC-FUNC-003 | Rollback — incremental extraction, revert to monolith at any phase |
| Psi-0 (Existence) | Partial failure no longer threatens total existence |

---

## 13. Conclusion

The split is **architecturally sound** (clean boundaries, negligible latency, unchanged consistency) but **operationally premature** for the current single-operator dev environment. The recommended path is incremental: keep the monolith now, extract sa-gateway first when approaching production, then sa-infer when inference becomes the bottleneck. Full decomposition when operating multiple federated nodes.

**Net assessment:** The split is worth it for fault isolation. The question is not "should we split" but "when." The answer is: when a crash in the inference cascade would page a real operator at 3 AM.
