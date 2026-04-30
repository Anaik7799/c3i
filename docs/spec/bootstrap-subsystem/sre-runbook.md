# Bootstrap Subsystem — SRE Runbook

**Task**: 116486929469430710  **STAMP**: SC-BOOTSTRAP, SC-FUNC, SC-DMS
**On-call escalation**: operator (Abhijit.Naik@bountytek.com)

## 1. Service overview

**Service**: Bootstrap Hook Subsystem
**SLO**: hook success ≥ 99.9966%, daemon availability ≥ 99.95%, p99 < 100µs (data plane)
**Error budget**: 3.4 × 10⁻⁶ failures per hook fire = 10 failures/year at 3M ops/year
**Failure budget per month**: ~0.83 failures

## 2. Alarms (5 rules — RPN-prioritised)

### 2.1 ALARM-1: Daemon Down (RPN 504)
**Trigger**: 1Hz heartbeat absent on `indrajaal/l4/system/bootstrap/health` for 30s
**Severity**: P0
**Action**:
1. Check systemd: `systemctl status sa-plan-daemon`
2. If `inactive`: `journalctl -u sa-plan-daemon --since "5 min ago"` for crash cause
3. Manual restart: `systemctl restart sa-plan-daemon`
4. Verify recovery: heartbeat returns within 10s
5. If recurrent: file P0 sa-plan task with crash details

### 2.2 ALARM-2: Hook Silent Failure (RPN 576)
**Trigger**: ratio of `Failed` outcomes without `error_explicit=true` > 0% over 5min window
**Severity**: P0 — **safety-critical, never expected**
**Action**:
1. Read latest 100 outcomes: `sqlite3 smriti.db "SELECT * FROM telemetry ORDER BY ts DESC LIMIT 100"`
2. Identify failure cluster (kind, agent, error type)
3. Verify telemetry pipeline isn't dropping `error_explicit` field — bug in TelemetryReader?
4. Audit Rust code for any `.ok()` or `.unwrap_or_default()` swallowing errors
5. P0 sa-plan task; halt deployments

### 2.3 ALARM-3: Entropy Spike (RPN 280, chaos detection)
**Trigger**: Shannon H(50-window outcome distribution) > 0.5 bits sustained 5min
**Severity**: P1
**Action**:
1. Examine recent outcomes — what's the entropy source?
2. If daemon transitioning Up↔Hung: ALARM-1 likely upstream
3. If novel error type appearing: rule induction may need to fire (run `sa-plan-daemon ga-induce`)
4. Snapshot ring buffer to disk for forensics: `sa-plan-daemon dump-ring /tmp/ring-$(date +%s).bin`
5. P1 sa-plan task with snapshot

### 2.4 ALARM-4: GA Fitness Regression (RPN 175)
**Trigger**: best_fitness drops by > 20% vs prior week's median
**Severity**: P2
**Action**:
1. Roll back to previous generation: `sa-plan-daemon ga-rollback --generation N-1`
2. Investigate workload shift — did Claude/Pi/Gemini change patterns?
3. Re-run shadow A/B with previous params
4. P2 sa-plan task; document workload change

### 2.5 ALARM-5: Smriti Write Failure (RPN 144)
**Trigger**: `session_metrics` insert fails (rc != 0) for > 1 attempt
**Severity**: P1
**Action**:
1. Check disk: `df -h /home/an/dev/ver/c3i/sub-projects/c3i/data/kms`
2. If full: rotate logs, gc telemetry: `sa-plan-daemon telem-gc --keep-days 7`
3. Check WAL state: `sqlite3 smriti.db "PRAGMA wal_checkpoint(TRUNCATE)"`
4. If lock contention: `lsof | grep smriti.db`
5. Daemon falls back to RAM-only mode automatically — drain ring buffer to file when disk recovers

## 3. Postmortem template

### Incident summary
- **When**: <UTC timestamp range>
- **Severity**: P0 / P1 / P2
- **Duration**: <minutes>
- **User-visible impact**: <description>

### Timeline
- T+0: detection (alarm name, telemetry source)
- T+N: response actions
- T+M: resolution

### Root cause (5-Why per SC-RCA)
1. Why X? Because Y.
2. Why Y? Because Z.
3. ...
4. ...
5. ...

### Lessons (per SC-ZETTEL-002 — ingest as atomic holon)
- Pattern detected: ...
- Anti-pattern observed: ...
- Mitigation taken: ...
- Future prevention: ...

### Action items
- [ ] Update runbook section
- [ ] Add property test for failure mode
- [ ] Add RETE-UL rule
- [ ] Update FMEA RPN
- [ ] Ingest postmortem to ZK

## 4. Operational procedures

### 4.1 Deploy new daemon version
```
1. Build new binary:
   CARGO_TARGET_DIR=/home/an/dev/ver/c3i/sub-projects/work/ \
     cargo build --release -p planning_daemon
2. Stage binary:
   cp target/release/sa-plan-daemon /usr/local/bin/sa-plan-daemon.new
3. Hot reload (preferred — zero downtime):
   systemctl reload-or-restart sa-plan-daemon
4. Verify within 60s:
   curl --unix-socket /run/c3i/sa-plan-hook.sock \
     -X POST -d '{"op":"health_ping"}' http://localhost/
5. Monitor heartbeat for 5 min; rollback if regression
```

### 4.2 Rollback
```
1. systemctl stop sa-plan-daemon
2. mv /usr/local/bin/sa-plan-daemon.bak /usr/local/bin/sa-plan-daemon
3. systemctl start sa-plan-daemon
4. File P0 sa-plan task with rollback reason
```

### 4.3 Snapshot inspection (debugging)
```
$ sa-plan-daemon snapshot-dump
{
  "version": 1,
  "written_at_ns": 1234567890,
  "daemon_health_bp": 998,
  "cache_ttl_ms": 5000,
  "active_tasks": 49,
  "pending_tasks": 1831,
  ...
}
```

### 4.4 Force snapshot refresh
```
$ sa-plan-daemon snapshot-refresh
ok: snapshot rewritten, age_ms=0
```

### 4.5 Clear stuck lock manually
```
$ sa-plan-daemon clear-stale-lock --max-age-sec 0
ok: cleared 1 lock(s)
```

## 5. Chaos drills (quarterly)

Run the 10 chaos scenarios from test-plan.md against staging:
```
$ sa-plan-daemon chaos-suite run --target=staging
Scenario 1/10: kill -9 daemon mid-hook ......... PASS (degraded fallback)
Scenario 2/10: stale lock 600s ................. PASS (dead-man cleared)
[... 8 more ...]
$ sa-plan-daemon chaos-suite report
✓ 10/10 scenarios passed
```

Failure → P1 sa-plan task; ship fix before quarterly review.

## 6. Capacity planning

| Metric | Current | At limit | Action |
|---|---|---|---|
| Daemon RSS | ~50MB | 100MB | restart if approaching limit |
| Hooks/min | ~30 peak | 600 | data plane handles 200k/sec; not a real limit |
| Telemetry/day | ~80MB raw | 1GB | gc + downsample |
| /dev/shm size | 4KB+256KB | 1MB | not a concern |
| Concurrent UDS clients | ~3 | 100 | TCP_LISTEN backlog 128 |

## 7. Disaster recovery

### Total data loss (Smriti.db corruption)
1. Stop daemon: `systemctl stop sa-plan-daemon`
2. Restore from latest gcs backup: `sa-plan-daemon restore --bucket gs://c3i-backup --as-of "1 hour ago"`
3. Verify: `sa-plan-daemon status` returns expected counts
4. Restart daemon
5. ZK ingestions resume; in-progress hooks emit degraded fallback during recovery

### Cluster-wide failure
Bootstrap subsystem is single-host; no cluster mode in v1.0.
Future: SC-CPIG-FED federation provides cross-mesh failover.

## 8. References

- Design: `docs/spec/bootstrap-subsystem/design.md`
- Requirements: `docs/spec/bootstrap-subsystem/requirements.md`
- Test plan: `docs/spec/bootstrap-subsystem/test-plan.md`
- Matrix: `docs/analysis/bootstrap-subsystem/fractal-criticality-matrix.md`
- Incidents: `docs/journal/incidents/bootstrap-*.md`
