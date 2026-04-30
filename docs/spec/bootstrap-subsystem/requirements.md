# Bootstrap Subsystem — Requirements (IEEE 830 / ISO 29148)

**Version**: 1.0.0  **Date**: 2026-04-29  **Task**: 116486929469430710
**STAMP**: SC-BOOTSTRAP-001..005, SC-FRAC-RRF-001..010, SC-BIO-EVO-001..007, SC-ZMOF-001
**ZK**: [zk-d1190ab5bbbc6398], [zk-3cfe58417d733208], [zk-f827023c0af598b7]

## 1. Introduction

### 1.1 Purpose
Define functional, non-functional, interface, performance, and safety requirements for the
**Bootstrap Subsystem** — the L4-system shared substrate that serves SessionStart / UserPromptSubmit /
PostToolUse / Stop hooks for Claude Code, Pi, and Gemini agents.

### 1.2 Scope
- IN: hook execution, daemon orchestration, dead-man, cache, OODA, telemetry, formal specs.
- OUT: ZK ingestion logic (delegated to existing `scripts/sysd/stop_hook.gleam`); LLM inference
  (delegated to `mcp_inference.rs`).

### 1.3 Glossary
| Term | Definition |
|---|---|
| Hook | Subprocess invoked by Claude/Pi/Gemini at lifecycle event |
| Snapshot | mmap'd 4KB struct in /dev/shm holding current bootstrap state |
| Seqlock | Linux-kernel-style sequence lock for lockless reads |
| Data plane | Hot path: hook reads snapshot, emits JSON (target <100µs) |
| Control plane | Cool path: daemon updates snapshot, runs OODA (target <10ms) |
| RPN | FMEA Risk Priority Number = Severity × Occurrence × Detection |

## 2. Overall Description

### 2.1 Product perspective
sa-plan-daemon (Rust, persistent) is extended with bootstrap functionality. A new tiny
`c3i-hook` no-deps Rust binary (50KB) is the data-plane reader. Existing `scripts/sysd/stop_hook.gleam`
is preserved (SC-SCRIPT-GLEAM-001) and orchestrated by the new daemon stop-hook subcommand.

### 2.2 Users
- Claude Code (interactive AI agent)
- Pi-mono (interactive AI agent, 15 LLM providers)
- Gemini CLI (interactive AI agent)
- Operators (via MoZ tool calls + dashboard)

### 2.3 Constraints
- Linux x86_64 only (mmap + seqlock semantics)
- Daemon must be running for full feature set; degraded mode supported when down
- Total CPU budget for hooks: <5% steady state, <20% peak

## 3. Functional Requirements

### FR-001 SessionStart hook
The system shall provide bootstrap state (active/pending/completed task counts, ZK holon counts,
daemon health, recommended-next-task) at session start in <100ms p99.

### FR-002 UserPromptSubmit hook
The system shall provide ZK recall context (cited holons + anti-pattern alerts) per prompt in <500ms p99.

### FR-003 PostToolUse hook
The system shall verify Gleam build status after every Edit/Write in <5s p99 (existing — preserved).

### FR-004 Stop hook
The system shall trigger ZK ingestion via existing `scripts/sysd/stop_hook.gleam` with bounded
timeout (50s), explicit error reporting, and dead-man on stale lock.

### FR-005 Tri-agent uniformity
Claude, Pi, and Gemini hooks shall call the same daemon endpoints with `agent_id` as the only
distinguishing parameter.

### FR-006 Embedded fallback
When daemon is unreachable or hung, hooks shall emit a degraded systemMessage rather than failing
silently or hanging.

### FR-007 Citation tracking
Stop hook shall count `zk-[0-9a-f]{16}` citations in the latest assistant transcript and persist
to `session_metrics.zk_citations`.

### FR-008 Dead-man on stale locks
Locks older than 300s shall be cleared automatically before any operation requiring them.

### FR-009 Gleam binary resolution
The system shall resolve the gleam executable via PATH first, then known fallback locations,
emitting a SessionStart warning if none found.

### FR-010 MoZ exposure
All bootstrap operations shall be exposed as MCP tools dispatched over Zenoh (SC-ZMOF-001) at
topics `indrajaal/mcp/req/bootstrap_*/<id>`.

### FR-011..030 Continued (see test plan for full enumeration)

## 4. Non-Functional Requirements

### NFR-001 Reliability
Hook success rate ≥ 99.9966% (Six Sigma, < 3.4 failures per million).

### NFR-002 Availability
Daemon availability ≥ 99.95% (max 4.4h downtime/year, including planned maintenance).

### NFR-003 Performance — data plane
| Operation | p50 | p99 | Max |
|---|---:|---:|---:|
| Snapshot read | 30µs | 80µs | 200µs |
| Embedded fallback | 50µs | 120µs | 300µs |
| UDS RPC | 0.5ms | 2ms | 5ms |
| Zenoh RPC | 5ms | 15ms | 50ms |

### NFR-004 Performance — control plane
| Operation | p50 | p99 |
|---|---:|---:|
| Snapshot write (1Hz) | 100µs | 500µs |
| Bayesian update | 10µs | 50µs |
| PID tick | 5µs | 20µs |
| GA generation (daily) | 5min | 15min |
| MDP value iteration | 30s | 120s |

### NFR-005 Memory
Daemon resident memory <100MB. Per-hook process <10MB. Shared mmap 4KB + 256KB ring buffer.

### NFR-006 Maintainability
- All code adheres to SC-RUST-TOOL-001..003 (Rust subcommands, no shell)
- All scripts adhere to SC-SCRIPT-GLEAM-001 (Gleam, not bash)
- Wiring Guard updated per SC-WIRE-001..007

### NFR-007 Observability
Every hook fire publishes one OTel span on `indrajaal/l5/cog/hook/<kind>/<run_id>`.
Daemon publishes 1Hz heartbeat on `indrajaal/l4/system/bootstrap/health`.
Shannon entropy alarm published on threshold breach.

### NFR-008 Crash isolation
Data plane shall remain functional through daemon crash (snapshot persists in mmap).
Hook process crash shall not corrupt daemon state or other hooks.

### NFR-009 Backward compatibility
Existing `.claude/settings.json` hook commands continue to work during phased rollout (P1 first
ships Rust subcommands; settings.json updated as final step).

## 5. Interface Requirements

### IR-001 CLI
```
sa-plan-daemon bootstrap [--agent claude|pi|gemini]
sa-plan-daemon stop-hook [--agent claude|pi|gemini]
sa-plan-daemon count-citations [--transcript-path PATH]
sa-plan-daemon clear-stale-lock [--lock-path PATH] [--max-age-sec N]
```

### IR-002 UDS protocol
Length-prefixed JSON over `/run/c3i/sa-plan-hook.sock`:
```
> { "op": "bootstrap_status", "agent_id": "claude", "session_id": "..." }
< { "ok": true, "msg": "C3I BOOTSTRAP: ...", "snapshot_age_ms": 1234 }
```

### IR-003 MoZ topics
```
indrajaal/mcp/req/bootstrap_status/<uuid>     ← request
indrajaal/mcp/req/stop_hook_ingest/<uuid>     ← request
indrajaal/mcp/req/count_citations/<uuid>      ← request
indrajaal/mcp/req/clear_stale_lock/<uuid>     ← request
indrajaal/mcp/res/<uuid>                      ← response
indrajaal/l5/cog/hook/<kind>/<run_id>         ← OTel span
indrajaal/l4/system/bootstrap/health          ← 1Hz heartbeat
indrajaal/l4/system/bootstrap/lock/<id>       ← lock telemetry
```

### IR-004 Shared memory layout
```
/dev/shm/c3i-hook-state.bin    (4KB, seqlock-protected, daemon writes, hooks read)
/dev/shm/c3i-hook-telem.bin    (256KB, multi-producer ring, hooks write, daemon drains)
```

### IR-005 Hook contract
Hook stdin: Claude Code's hook event JSON.
Hook stdout: `{"systemMessage":"..."}` or `{"hookSpecificOutput":{...}}`.
Hook exit code: 0 on success/degraded, non-zero only on unrecoverable failure (rare).

## 6. Performance Requirements

### PR-001 Throughput
Aggregate across three agents: 90 hooks/min sustained, 300 hooks/min burst.

### PR-002 Latency budget per hook kind
| Hook | p50 | p99 | Hard timeout |
|---|---:|---:|---:|
| SessionStart | 50ms | 100ms | 20s |
| UserPromptSubmit | 200ms | 500ms | 12s |
| PostToolUse | 200ms | 5s (gleam build) | 30s |
| Stop | 5s | 50s | 60s |

### PR-003 Cache hit rate
Target ≥92% hit rate via PID-tuned 5s TTL.

### PR-004 Telemetry budget
≤ 200MB/day raw, ≤ 30MB/day after gzip rollover.

## 7. Safety Requirements

### SR-001 No silent failure (SC-AVP-007)
Every hook outcome shall emit either a success or explicit error message.

### SR-002 Fail-closed (SC-FUNC-001)
Adding error evidence shall never improve outcome rank
(Success → Degraded → Failed monotonic).

### SR-003 Bounded recovery (SC-FUNC-005)
Daemon hang shall trigger watchdog kill within 600ms (3 × 200ms ping timeout).

### SR-004 Atomic state writes (SC-FUNC-004)
Snapshot writes shall be atomic via seqlock; readers shall observe either old or new payload,
never torn intermediate state.

### SR-005 PII scrubbing (SC-SEC-003)
All telemetry shall pass through PII scrubber before persistence.

### SR-006 Refusal authority (VSM S5)
The system shall refuse new hook invocations when:
- Disk free < 5%, or
- CPU > 95% sustained 30s, or
- Bayesian daemon health < 0.1

## 8. Verification Matrix

Maps each requirement to verification artifact. See `test-plan.md` for full mapping.
Total: 30 functional + 9 non-functional + 5 interface + 4 performance + 6 safety = **54 requirements**.

## 9. Traceability

| Req prefix | Source |
|---|---|
| FR-* | Operator mandate + ZK [zk-d1190ab5bbbc6398] |
| NFR-* | SC-BOOTSTRAP-001..005 + SC-FRAC-RRF |
| IR-* | SC-ZMOF-001..005 |
| PR-* | Mathematical SLO model (matrix §8) |
| SR-* | SC-SAFETY-001..022, SC-FUNC-001 |
