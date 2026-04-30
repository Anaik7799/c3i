# Bootstrap Subsystem — Design Document

**Version**: 1.0.0  **Date**: 2026-04-29  **Task**: 116486929469430710
**STAMP**: SC-BOOTSTRAP-001..005, SC-FRAC-RRF-001..010, SC-ARCH-SPLIT-001..004, SC-ZMOF-001
**ZK**: [zk-3cfe58417d733208], [zk-f827023c0af598b7], [zk-d1190ab5bbbc6398]

## 1. Architecture

### 1.1 Data plane / control plane split

```
┌──────────────────────────────────────────────────────────────────┐
│                    DATA PLANE — hot, lockless                     │
│                                                                    │
│  Claude hook → c3i-hook → mmap read seqlock'd snapshot → emit JSON │
│  Pi hook    → c3i-hook → mmap read same snapshot       → emit JSON │
│  Gemini hook → c3i-hook → mmap read same snapshot       → emit JSON│
│                                                                    │
│  Latency p99: < 100µs    Allocations: 0    Syscalls: 1 (write)    │
└─────────────────────────┬────────────────────────────────────────┘
                          │  /dev/shm/c3i-hook-state.bin (4KB)
                          │  /dev/shm/c3i-hook-telem.bin (256KB ring)
┌─────────────────────────┴────────────────────────────────────────┐
│                  CONTROL PLANE — cool, daemon-resident            │
│                                                                    │
│  sa-plan-daemon worker threads:                                   │
│    SnapshotWriter   1Hz   → seqlock-write 4KB                     │
│    TelemetryReader  100Hz → drain ring → Smriti.db + OTel + Zenoh │
│    Bayesian          0.5Hz → posterior update on ping             │
│    PID                1Hz → cache TTL self-tune                    │
│    GeneticEvolver    1/day → population evaluation (shadow)       │
│    MDPSolver        1/10k  → Bellman re-iteration                  │
│    RuleInductor       1/d  → propose new RETE-UL rule              │
│    Watchdog          0.5Hz → self-ping UDS, suicide if hung       │
│    MoZSubscriber     cont. → indrajaal/mcp/req/bootstrap_*        │
└──────────────────────────────────────────────────────────────────┘
```

### 1.2 Module layout (Rust, in `sub-projects/c3i/native/planning_daemon/src/`)

| Module | Lines | Purpose |
|---|---:|---|
| `bootstrap.rs` | 250 | State collection, snapshot construction, citation count |
| `bootstrap_snapshot.rs` | 150 | Seqlock writer/reader, mmap layout, NUMA pinning |
| `mcp_bootstrap.rs` | 120 | MCP tool handlers (4 tools) |
| `bootstrap_uds.rs` | 180 | UDS server (control plane), thin client lib |
| `bootstrap_watchdog.rs` | 100 | Self-ping watchdog + Bayesian estimator |
| `bootstrap_pid.rs` | 80 | PID controller for cache TTL |
| `bootstrap_ga.rs` | 220 | Genetic algorithm with Wilson-score A/B |
| `bootstrap_mdp.rs` | 180 | Markov decision process value iteration |
| `bootstrap_rete.rs` | 150 | Hook-domain RETE-UL evaluator |
| `cli.rs` (edit) | +40 | bootstrap, stop-hook, count-citations, clear-stale-lock subs |
| `cortex.rs` (edit) | +30 | Register MCP tools + MoZ topics |

Total new Rust: ~1500 LOC.

### 1.3 Tiny client binary

| Binary | Source | Purpose |
|---|---|---|
| `c3i-hook` | `sub-projects/c3i/native/c3i_hook/` (new crate) | 50KB no-deps Rust binary that mmaps, seqlock-reads, emits JSON, exits |

Crate `Cargo.toml`:
```toml
[package]
name = "c3i_hook"
edition = "2021"

[dependencies]
# Intentionally NONE. Use only std::os::unix::net + std::fs.
# Do NOT add tokio, serde, anyhow — they bloat cold-start.

[profile.release]
opt-level = 3
lto = "fat"
codegen-units = 1
strip = true
panic = "abort"  # remove unwinding tables
```

Binary size target: < 50KB stripped. Cold start: < 5ms.

## 2. Seqlock layout

```rust
#[repr(C)]
#[repr(align(64))]  // cacheline-align to prevent false sharing
pub struct HookStateSnapshot {
    seq: AtomicU64,                    // 0-7    seqlock counter
    _pad1: [u8; 56],                   // 8-63   prevent false sharing
    payload: HookStatePayload,         // 64-...
}

#[repr(C)]
pub struct HookStatePayload {
    version: u32,                      // schema version
    written_at_ns: u64,                // CLOCK_MONOTONIC at write
    daemon_health_bp: u16,             // Bayesian ‰
    daemon_state: u8,                  // 0=Up, 1=Hung, 2=Down, 3=Restarting
    cache_ttl_ms: u16,
    _pad2: [u8; 7],
    // Counts
    active_tasks: u32,
    pending_tasks: u32,
    completed_tasks: u32,
    c3i_zk_holons: u32,
    fy27_zk_holons: u32,
    // Recommended next task (URN length-prefixed)
    next_task_urn: [u8; 64],
    // Lock state
    stop_lock_holder: [u8; 32],
    stop_lock_age_ms: u32,
    // Resolved binary paths (cached at daemon start)
    gleam_path: [u8; 256],
    sa_plan_path: [u8; 256],
    // Reserved for future use
    _reserved: [u8; 256],
}
// Total: ~1.3 KB. Fits one page; mmaps cleanly to 4KB.
```

## 3. UDS protocol

### 3.1 Endpoint
`/run/c3i/sa-plan-hook.sock` — owned by the c3i user, mode 0660.

### 3.2 Wire format
4-byte length prefix + JSON body:
```
> [0x00 0x00 0x00 0x42]  // 66 bytes
> {"op":"bootstrap_status","agent_id":"claude","session_id":"abc"}
< [0x00 0x00 0x00 0x4e]
< {"ok":true,"msg":"...","snapshot_age_ms":1234,"agent_telemetry_tag":"claude"}
```

### 3.3 Operations
| op | Request body | Response body |
|---|---|---|
| `bootstrap_status` | `{agent_id, session_id}` | `{ok, msg, snapshot_age_ms, tag}` |
| `stop_hook_ingest` | `{agent_id, session_id, transcript_path}` | `{ok, citations, duration_ms}` |
| `count_citations` | `{transcript_path}` | `{ok, count}` |
| `clear_stale_lock` | `{lock_path, max_age_sec}` | `{ok, cleared}` |
| `health_ping` | `{}` | `{ok, pong_ts}` |

## 4. MoZ exposure

Same 5 operations also available over Zenoh per SC-ZMOF-001:
```
indrajaal/mcp/req/bootstrap_status/<uuid>     ← request
indrajaal/mcp/req/stop_hook_ingest/<uuid>     ← request
indrajaal/mcp/req/count_citations/<uuid>      ← request
indrajaal/mcp/req/clear_stale_lock/<uuid>     ← request
indrajaal/mcp/req/health_ping/<uuid>          ← request
indrajaal/mcp/res/<uuid>                      ← response
```

Telemetry topics:
```
indrajaal/l5/cog/hook/<kind>/<run_id>         ← OTel span per fire
indrajaal/l4/system/bootstrap/health          ← 1Hz daemon heartbeat
indrajaal/l4/system/bootstrap/lock/<id>       ← lock state changes
indrajaal/l4/system/bootstrap/snapshot_age    ← staleness gauge
indrajaal/l5/cog/hook/entropy_alarm           ← Shannon entropy chaos
indrajaal/l5/cog/hook/ga_fitness              ← evolution trajectory
indrajaal/l5/cog/hook/mdp_value               ← MDP convergence
```

## 5. Tri-agent symbiosis

### 5.1 Claude integration
`.claude/settings.json` hooks call `c3i-hook --kind=session-start --agent=claude` (etc).
The hook binary mmaps the snapshot, reads, and emits.

### 5.2 Pi integration
`.pi/extensions/zk-recall.ts` rewrite — replace its current sqlite3 + sa-plan shell-out with:
```typescript
import { execFileSync } from 'child_process';
function bootstrap_status(agent_id: string): string {
  return execFileSync('/usr/local/bin/c3i-hook',
    ['--kind=session-start', `--agent=${agent_id}`],
    { encoding: 'utf-8' });
}
```

### 5.3 Gemini integration
`.gemini/extensions/c3i-bootstrap.gemini` analogous to Pi extension. Same `c3i-hook` binary.

### 5.4 Cross-agent learning
The MDP transition matrix sees fires from all three agents. Telemetry tagged with agent_id but
pooled for value iteration. Result: 3× faster convergence than per-agent silos.

## 6. Data flow

### 6.1 SessionStart hook (cold start)
```
1. Claude Code spawns c3i-hook --kind=session-start --agent=claude
2. c3i-hook opens /dev/shm/c3i-hook-state.bin (mmap, PROT_READ)
3. seqlock_read(snapshot)
4. write(stdout, json) — single write syscall
5. _exit(0)
Total time: ~50µs
```

### 6.2 PostToolUse hook (hot path, burst)
```
Same as 6.1, but mmap is already cached after first fire (page cache hit)
Total time: ~30µs
```

### 6.3 Stop hook (slow path with daemon orchestration)
```
1. Claude Code spawns c3i-hook --kind=stop --agent=claude
2. c3i-hook reads snapshot for cited holons count
3. c3i-hook connects /run/c3i/sa-plan-hook.sock
4. Send {"op":"stop_hook_ingest", ...}
5. Daemon orchestrates:
   - clear_stale_lock(/tmp/c3i-stop-hook.lock, 300s)
   - acquire flock
   - spawn `gleam run -m scripts/sysd/stop_hook` (timeout 50s)
   - count zk-citations from transcript
   - persist session_metrics row to Smriti
   - release flock
   - return outcome
6. c3i-hook receives response
7. write(stdout, json)
8. _exit(0)
Total time: ~5-50s (gleam ingest dominates)
```

### 6.4 Daemon down (degraded mode)
```
1. c3i-hook connects UDS — fails (ENOENT or ECONNREFUSED)
2. c3i-hook reads snapshot (still in mmap, may be stale)
3. If snapshot.age_ms < 60s → emit cached + flag stale
4. Else → emit embedded fallback "C3I BOOTSTRAP: daemon offline · cite ZK"
5. write(stdout, json)
6. _exit(0)
Total time: ~80µs
```

## 7. Failure modes & recovery

| Mode | Detection | Recovery |
|---|---|---|
| Daemon panic | systemd notices, Restart=on-failure | systemd restarts; snapshot persists in mmap; hooks degrade to cached |
| Daemon hung | Watchdog self-ping fails 3× | Watchdog kills self with kill -9; systemd restarts |
| /dev/shm corruption | Snapshot CRC fails | Daemon recreates from Smriti.db on startup |
| UDS socket gone | ENOENT on connect | Hook falls back to mmap-only mode |
| Stale lock | Age > 300s | Dead-man clears at next operation |
| Disk full | Smriti write fails | RAM-only mode + alarm on Zenoh |
| Hook process panic | Per-process | No effect on other hooks or daemon |

## 8. Observability

| Stream | Rate | Destination | Cost |
|---|---:|---|---|
| OTel spans per hook | 90/min peak | Zenoh + Smriti | ~70MB/day raw |
| 1Hz heartbeat | 86400/day | Zenoh | ~3MB/day |
| Lock state changes | ~5/day | Zenoh + audit log | <1MB/day |
| Entropy alarm | rare | Zenoh + email | <1KB/event |
| GA fitness updates | 1/day | Zenoh + dashboard | ~10KB/day |
| Bayesian posterior | 0.5Hz | dashboard | ~5MB/day |

Total: ~80MB/day raw, ~15MB/day after gzip.

## 9. Phased rollout

Each phase ships a working subset with rollback path:

| Phase | Ships | Rollback |
|---|---|---|
| P0 Spec | 9 docs (this is one of them) | Delete files, no system change |
| P1 Hot path | Rust subcommands + dead-man, settings.json updated | Revert settings.json, daemon unchanged |
| P2 UDS+watchdog | UDS endpoint added | Disable systemd unit; client falls through to subcommand |
| P2.5 Data plane | mmap snapshot + c3i-hook binary | Don't install binary; settings.json keeps subcommand calls |
| P3 RETE+observability | Rules + entropy + OTel | Comment out rule registration |
| P4 Living/learning | Bayesian + PID + GA + MDP | Disable in config |
| P5 Verification | Agda + Apalache + chaos suite | n/a (read-only verification) |

## 10. Cross-references

- Requirements: `docs/spec/bootstrap-subsystem/requirements.md`
- Test plan: `docs/spec/bootstrap-subsystem/test-plan.md`
- SRE runbook: `docs/spec/bootstrap-subsystem/sre-runbook.md`
- Fractal-criticality matrix: `docs/analysis/bootstrap-subsystem/fractal-criticality-matrix.md`
- Agda: `specs/agda/HookSubsystem.agda`
- TLA+: `specs/tla/HookSubsystem.tla`
- Allium: `specs/allium/hook_subsystem.allium`
- Journal: `docs/journal/20260429-bootstrap-subsystem-design.md`
