# CEPAF Service Chain Usecases - Dev/Demo Environment

**Version**: 1.0.0
**Date**: 2025-12-24
**Status**: Active
**STAMP Compliance**: SC-CEP-003, SC-CEP-004, SC-AGT-018, SC-VAL-003

## Overview

This document defines exhaustive usecases for the Indrajaal dev/demo service chain.
The chain consists of three layers:

```
Layer 0: indrajaal-db (PostgreSQL 17 + TimescaleDB)
         - No dependencies
         - Port 5433
         - Health: pg_isready

Layer 1: indrajaal-app (Phoenix/Elixir)
         - Depends on: indrajaal-db (Mandatory)
         - Port 4000
         - Health: /health endpoint
         - Sidecars: localhost:6379 (integrated Redis), indrajaal-nginx

Layer 2: indrajaal-obs (SigNoz/Grafana)
         - Depends on: indrajaal-app (Optional)
         - Ports: 9090 (Prometheus), 3000 (Grafana), 4317 (OTLP)
         - Health: /-/healthy
         - Sidecars: indrajaal-grafana
```

---

## 1. Startup Usecases

### UC-START-001: Clean Start (No Containers)

**Preconditions:**
- No containers exist
- All images available in localhost/ registry
- Network `indrajaal-net` does not exist

**Steps:**
1. Create network `indrajaal-net` with subnet 172.30.0.0/24
2. Start Layer 0 containers (indrajaal-db)
3. Wait for db health check (pg_isready)
4. Start Layer 1 containers (indrajaal-app, sidecars)
5. Wait for app health check (/health returns 200)
6. Start Layer 2 containers (indrajaal-obs, grafana)
7. Wait for obs health check

**Expected Results:**
- All containers running
- FPPS 5/5 consensus for each container
- Boot time < 30s (SC-CEP-004)
- Chain status: `ChainHealthy`

**STAMP Constraints:**
- SC-CNT-009: All containers are NixOS-based
- SC-CNT-010: All images from localhost/ registry
- SC-CNT-012: Rootless execution enforced

---

### UC-START-002: Partial Start (DB Only)

**Preconditions:**
- No containers exist
- Only database is requested to start

**Steps:**
1. Create network if not exists
2. Start indrajaal-db only
3. Verify db health
4. Do NOT start dependent containers

**Expected Results:**
- Only indrajaal-db running
- App and obs remain unstarted
- Chain status: `ChainDegraded ["indrajaal-app", "indrajaal-obs"]`
- Partial boot allowed for debugging

**Use Case:**
- Database-only operations
- Schema migrations
- Data restoration

---

### UC-START-003: Full Chain Start

**Preconditions:**
- All containers in stopped state
- Network exists
- Data volumes mounted

**Steps:**
1. Verify network connectivity
2. Start containers in topological order: db -> app -> obs
3. Run FPPS consensus for each container
4. Verify boot sequence < 30s

**Expected Results:**
- All 6 containers (3 core + 3 sidecars) running
- Boot sequence: [db, app, redis, nginx, obs, grafana]
- Chain status: `ChainHealthy`

**STAMP Constraints:**
- SC-CEP-004: 30-second boot threshold enforced

---

### UC-START-004: Boot with Pre-existing Data

**Preconditions:**
- Database volume contains existing data
- App has cached dependencies in _build/
- Previous logs exist

**Steps:**
1. Start containers in order
2. Database should recover existing data
3. App should use cached deps (faster boot)
4. Verify data integrity post-boot

**Expected Results:**
- Data preserved across restarts
- Faster startup due to caches
- No data corruption detected
- Chain status: `ChainHealthy`

---

### UC-START-005: Boot After Crash Recovery

**Preconditions:**
- Previous container crashed unexpectedly
- Possible orphaned resources (networks, volumes)

**Steps:**
1. Clean up orphaned resources
2. Verify volume integrity
3. Start chain with standard boot sequence
4. Verify data consistency

**Expected Results:**
- Orphaned resources cleaned
- Chain recovers cleanly
- No data loss

---

### UC-START-006: Boot with Missing Image

**Preconditions:**
- One or more container images not in local registry

**Steps:**
1. Attempt chain start
2. Detect missing image
3. Report error with SC-CNT-010 violation

**Expected Results:**
- Chain start blocked
- Error: "Image not found in localhost/ registry"
- Chain status: `ChainFailed`

---

### UC-START-007: Boot with Insufficient Resources

**Preconditions:**
- System has insufficient memory/CPU for containers

**Steps:**
1. Attempt chain start
2. Container fails to allocate resources
3. Report resource constraint error

**Expected Results:**
- Chain start fails gracefully
- Error message indicates resource constraint
- Partial containers cleaned up

---

## 2. Health Usecases

### UC-HEALTH-001: All Containers Healthy

**Preconditions:**
- Chain fully started
- All services responding normally

**FPPS Verification:**
1. PodmanStatus: All containers show "running"
2. HealthEndpoint: All /health endpoints return 200
3. PortProbe: All ports accepting connections
4. ProcessCheck: Main processes running in each container
5. LogAnalysis: No ERROR/FATAL patterns in recent logs

**Expected Results:**
- 5/5 FPPS consensus for all nodes
- Chain status: `ChainHealthy`
- All layers healthy: {0: true, 1: true, 2: true}

---

### UC-HEALTH-002: DB Degraded, Chain Impact

**Preconditions:**
- Chain running
- Database becomes degraded (high latency, disk pressure)

**Scenario:**
1. DB health check returns slow but successful
2. App queries start timing out
3. FPPS detects LogAnalysis failures (timeout errors)

**Expected Results:**
- Chain status: `ChainDegraded ["indrajaal-db"]`
- App may be affected (depends on timeout settings)
- Obs continues unaffected (optional dep)
- Alert triggered for db degradation

**Impact Propagation:**
- L0 (db): Degraded
- L1 (app): May degrade if queries timeout
- L2 (obs): Unaffected (independent of db)

---

### UC-HEALTH-003: App Unhealthy, Obs Optional Continues

**Preconditions:**
- Chain running
- App crashes or becomes unresponsive

**Scenario:**
1. App container stops responding to /health
2. FPPS HealthEndpoint check fails
3. Obs has Optional dependency on app

**Expected Results:**
- App marked unhealthy
- Obs continues running (optional dep)
- Chain status: `ChainDegraded ["indrajaal-app"]` (if AllowDegradedOptional=true)
- OR `ChainFailed ["indrajaal-app"]` (if AllowDegradedOptional=false)

**Key Point:** Optional dependencies allow graceful degradation

---

### UC-HEALTH-004: Recovery from Failure

**Preconditions:**
- Container previously failed
- Issue has been resolved

**Scenario:**
1. Container restarts automatically (restart policy)
2. Health checks start passing
3. FPPS consensus re-achieved

**Expected Results:**
- Container transitions: Failed -> Starting -> Healthy
- Chain status recovers: ChainDegraded -> ChainHealthy
- Recovery time tracked in metrics

---

### UC-HEALTH-005: Cascading Failure Prevention

**Preconditions:**
- Chain healthy
- L0 (db) fails suddenly

**Scenario:**
1. DB crashes
2. App detects db connection failure
3. App circuit breaker activates
4. Obs continues collecting what metrics it can

**Expected Results:**
- Failure contained to db and direct dependents
- Obs not crashed (optional dep)
- Chain status: `ChainFailed ["indrajaal-db"]`
- App status determined by circuit breaker behavior

---

### UC-HEALTH-006: Intermittent Health Flapping

**Preconditions:**
- Container alternating between healthy/unhealthy

**Scenario:**
1. Health check passes
2. Health check fails
3. Health check passes
4. Pattern repeats

**Expected Results:**
- Flapping detected after N cycles
- Status stabilization delay applied
- Alert for unstable container
- Not counted as healthy until stable

---

### UC-HEALTH-007: Health Check Timeout

**Preconditions:**
- Container running but very slow

**Scenario:**
1. Health check sent
2. Response takes longer than timeout (5s default)
3. Check marked as failed

**Expected Results:**
- Timeout treated as failure
- FPPS HealthEndpoint: false
- Details: "HTTP timeout after 5000ms"

---

## 3. FPPS Verification Usecases

### UC-FPPS-001: All 5 Methods Pass

**Preconditions:**
- Container fully operational

**Verification:**
1. PodmanStatus: "running" state confirmed
2. HealthEndpoint: HTTP 200 from /health
3. PortProbe: TCP connection successful
4. ProcessCheck: podman top shows processes
5. LogAnalysis: No error patterns found

**Expected Results:**
- ConsensusAchieved: true
- Consensus: 5/5
- Node status: Healthy

---

### UC-FPPS-002: PodmanStatus Fail, Others Pass

**Preconditions:**
- Container running but podman reports stale state

**Scenario:**
1. PodmanStatus: "exited" (stale)
2. HealthEndpoint: 200 OK
3. PortProbe: Connection successful
4. ProcessCheck: Processes found
5. LogAnalysis: Clean

**Expected Results:**
- If RequireAllMethods=true: Consensus not achieved
- If RequireAllMethods=false: Consensus achieved (4/5)
- Investigation needed for podman state inconsistency

---

### UC-FPPS-003: HealthEndpoint Timeout

**Preconditions:**
- Container running but app slow

**Scenario:**
1. PodmanStatus: "running"
2. HealthEndpoint: Timeout (5000ms exceeded)
3. PortProbe: Connection successful (TCP level)
4. ProcessCheck: Process running
5. LogAnalysis: May show warnings

**Expected Results:**
- HealthEndpoint: false
- Details: "HTTP error: The operation was canceled"
- Consensus may still pass if majority (3/5) and lenient mode

---

### UC-FPPS-004: Consensus Failure (3/5)

**Preconditions:**
- Container in degraded state

**Scenario:**
1. PodmanStatus: pass
2. HealthEndpoint: pass
3. PortProbe: pass
4. ProcessCheck: fail (zombie process)
5. LogAnalysis: fail (errors detected)

**Expected Results:**
- If RequireAllMethods=true: ConsensusAchieved=false
- If RequireAllMethods=false: ConsensusAchieved=true (3/5 majority)
- Node considered degraded either way

---

### UC-FPPS-005: Log Error Pattern Detection

**Preconditions:**
- Container running with recent errors in logs

**Scenario:**
1. podman logs shows: "[ERROR] Connection refused"
2. LogAnalysis scans for patterns: ["ERROR", "FATAL", "CRITICAL"]
3. Match found

**Expected Results:**
- LogAnalysis: false
- Details: "Found error patterns: ERROR"
- Alert raised for log errors

---

### UC-FPPS-006: Empty Container (Just Started)

**Preconditions:**
- Container just started, no logs yet

**Scenario:**
1. PodmanStatus: "running"
2. HealthEndpoint: timeout (app initializing)
3. PortProbe: fail (port not bound yet)
4. ProcessCheck: pass (entrypoint running)
5. LogAnalysis: pass (no errors, no logs)

**Expected Results:**
- Expected during startup grace period
- Wait for StartPeriod before failing
- Container status: Starting

---

### UC-FPPS-007: All Methods Fail

**Preconditions:**
- Container crashed or stopped

**Scenario:**
1. PodmanStatus: "exited"
2. HealthEndpoint: connection refused
3. PortProbe: port closed
4. ProcessCheck: no processes
5. LogAnalysis: error reading logs

**Expected Results:**
- ConsensusAchieved: false
- Node status: Failed
- FailureReason: "All FPPS methods failed"

---

## 4. Dependency Usecases

### UC-DEP-001: Mandatory Dependency Failure Blocks Chain

**Preconditions:**
- Chain starting
- indrajaal-db (mandatory dep for app) fails to start

**Scenario:**
1. Attempt to start db
2. DB fails (port conflict, volume permission, etc.)
3. App cannot start without db

**Expected Results:**
- DB status: Failed
- App status: NotStarted (blocked by dependency)
- Chain status: `ChainFailed ["indrajaal-db"]`
- Boot sequence aborted

**STAMP Constraint:**
- Mandatory dependencies must be healthy before dependent starts

---

### UC-DEP-002: Optional Dependency Failure Degrades Chain

**Preconditions:**
- Chain starting
- indrajaal-obs (optional dep) fails to start

**Scenario:**
1. DB starts successfully
2. App starts successfully
3. Obs fails to start

**Expected Results:**
- DB status: Healthy
- App status: Healthy
- Obs status: Failed
- Chain status: `ChainDegraded ["indrajaal-obs"]`
- Chain continues operating (degraded mode)

**Key Point:** Optional dependencies don't block the chain

---

### UC-DEP-003: Cyclic Dependency Detection

**Preconditions:**
- Invalid DAG configuration with cycle

**Scenario:**
1. Container A depends on B
2. Container B depends on C
3. Container C depends on A

**Expected Results:**
- Cycle detected during DAG validation
- Error: "[SC-AGT-018] Circular dependency detected"
- Chain status: `ChainFailed []`
- Boot sequence: empty (cannot compute)

**STAMP Constraint:**
- SC-AGT-018: Deadlock prevention through cycle detection

---

### UC-DEP-004: Missing Dependency Detection

**Preconditions:**
- Container depends on non-existent container

**Scenario:**
1. Container "worker" depends on "queue"
2. "queue" container not defined

**Expected Results:**
- Validation error: "depends on non-existent node"
- Chain status: Failed
- Boot blocked until config fixed

---

### UC-DEP-005: Self-Dependency Detection

**Preconditions:**
- Container misconfigured to depend on itself

**Scenario:**
1. Container "service" depends on ["service"]

**Expected Results:**
- Validation error: "depends on itself"
- Chain status: Failed
- Boot blocked

---

### UC-DEP-006: Transitive Dependency Resolution

**Preconditions:**
- Complex dependency chain: obs -> app -> db

**Scenario:**
1. Query all dependencies of obs
2. Should include direct (app) and transitive (db)

**Expected Results:**
- getTransitiveDependencies "indrajaal-obs" = ["indrajaal-app", "indrajaal-db"]
- Boot sequence respects full dependency chain

---

### UC-DEP-007: Diamond Dependency Pattern

**Preconditions:**
- Diamond: db -> [app, cache] -> aggregator

**Scenario:**
1. aggregator depends on both app and cache
2. Both app and cache depend on db

**Expected Results:**
- No cycle detected (valid DAG)
- Boot order: db -> (app, cache) -> aggregator
- Layer assignment: db=0, app=1, cache=1, aggregator=2

---

## 5. Shutdown Usecases

### UC-STOP-001: Graceful Shutdown (Reverse Order)

**Preconditions:**
- Chain fully running

**Steps:**
1. Calculate reverse boot order: obs, grafana, app, redis, nginx, db
2. Stop obs layer first (allow drain time)
3. Stop app layer (wait for requests to complete)
4. Stop db layer last

**Expected Results:**
- All containers stopped cleanly
- No orphaned connections
- Data flushed to disk
- Shutdown time reasonable (not instant)

---

### UC-STOP-002: Emergency Stop (<1s)

**Preconditions:**
- Chain running
- Critical issue requires immediate stop

**Steps:**
1. Send SIGKILL to all containers simultaneously
2. Do not wait for graceful drain
3. Verify all stopped within 1s

**Expected Results:**
- All containers terminated
- Shutdown time < 1 second
- Possible data loss (expected in emergency)
- AOR-SAF-001 compliance: Halt <1s on STAMP violation

**STAMP Constraint:**
- SC-EMR-057: Stop <5s
- AOR-SAF-001: Emergency halt capability

---

### UC-STOP-003: Partial Shutdown

**Preconditions:**
- Chain running
- Need to restart only specific containers

**Steps:**
1. Stop specified containers only
2. Leave others running
3. Restart stopped containers

**Expected Results:**
- Only specified containers affected
- Chain may be degraded temporarily
- Recovery after restart

---

### UC-STOP-004: Shutdown with Drain

**Preconditions:**
- Chain running with active connections

**Steps:**
1. Mark containers for shutdown (no new requests)
2. Wait for active requests to complete (drain period)
3. Stop containers after drain or timeout

**Expected Results:**
- Active requests complete before shutdown
- No connection resets
- Graceful termination

---

### UC-STOP-005: Shutdown Timeout Exceeded

**Preconditions:**
- Container stuck, not responding to SIGTERM

**Steps:**
1. Send SIGTERM
2. Wait for graceful stop timeout (30s)
3. Escalate to SIGKILL

**Expected Results:**
- Container forcefully terminated
- Warning logged about forced termination
- Potential data loss flagged

---

## 6. Recovery Usecases

### UC-RECV-001: Auto-Restart on Crash

**Preconditions:**
- Container has restart policy: unless-stopped
- Container crashes

**Steps:**
1. Container exits unexpectedly
2. Podman detects exit
3. Container automatically restarted
4. Health checks resume

**Expected Results:**
- Container recovers automatically
- Brief degradation during restart
- No manual intervention required

---

### UC-RECV-002: Manual Recovery after Multiple Failures

**Preconditions:**
- Container failing repeatedly
- Restart policy exhausted

**Steps:**
1. Investigate failure cause
2. Fix underlying issue
3. Manually restart container
4. Verify health

**Expected Results:**
- Root cause identified
- Container stabilized
- Chain returns to healthy state

---

### UC-RECV-003: Data Recovery from Backup

**Preconditions:**
- Database corrupted
- Backup available

**Steps:**
1. Stop chain
2. Restore database volume from backup
3. Start chain
4. Verify data integrity

**Expected Results:**
- Data restored successfully
- Chain operational with restored data
- Minimal data loss (since last backup)

---

### UC-RECV-004: Network Partition Recovery

**Preconditions:**
- Network connectivity lost between containers
- Network restored

**Steps:**
1. Containers detect connectivity issues
2. Health checks fail during partition
3. Network restored
4. Connections re-established
5. Health checks pass

**Expected Results:**
- Chain recovers after network restoration
- Transient failures during partition
- Full recovery after connectivity restored

---

## 7. Validation Usecases

### UC-VAL-001: Pre-Boot Validation Pass

**Preconditions:**
- Valid configuration

**Checks:**
1. All images exist in localhost/ registry
2. No cyclic dependencies
3. All dependency targets exist
4. Port conflicts checked
5. Volume mounts valid

**Expected Results:**
- Validation: PASS
- Chain cleared for boot

---

### UC-VAL-002: Pre-Boot Validation Fail (Invalid Registry)

**Preconditions:**
- Image uses non-localhost registry

**Scenario:**
1. Container image: "docker.io/library/postgres:17"
2. Validation checks registry prefix

**Expected Results:**
- Validation: FAIL
- Error: "[SC-CNT-010] Image must use localhost/ registry"

---

### UC-VAL-003: STAMP Compliance Check

**Preconditions:**
- Chain configuration ready

**Checks:**
1. SC-CNT-009: All images contain "nixos"
2. SC-CNT-010: All images start with "localhost/"
3. SC-CNT-012: Rootless enabled (podman config)
4. SC-AGT-018: No cycles in DAG
5. SC-CEP-004: Estimated boot time < 30s

**Expected Results:**
- Compliance map returned
- Any failures flagged with specific constraint ID

---

## 8. Edge Case Usecases

### UC-EDGE-001: Empty Chain (No Containers)

**Preconditions:**
- No containers defined

**Expected Results:**
- DAG valid but empty
- Boot sequence: empty
- Chain status: NotStarted (nothing to start)

---

### UC-EDGE-002: Single Container Chain

**Preconditions:**
- Only database container defined

**Expected Results:**
- DAG valid with single node
- Boot sequence: [db]
- Chain status: Healthy (if db healthy)

---

### UC-EDGE-003: Very Long Dependency Chain

**Preconditions:**
- Chain: A -> B -> C -> D -> E -> F (6 levels)

**Expected Results:**
- DAG valid (no cycles)
- Boot time may exceed threshold
- Warning if SC-CEP-004 violated

---

### UC-EDGE-004: Parallel Containers at Same Layer

**Preconditions:**
- Multiple containers with no dependencies between them

**Scenario:**
- db1, db2, cache all at Layer 0

**Expected Results:**
- All can start in parallel
- Boot time optimized
- Layer structure: {0: [db1, db2, cache]}

---

### UC-EDGE-005: Container Name with Special Characters

**Preconditions:**
- Container named "indrajaal-app_v2.0"

**Expected Results:**
- Name handled correctly
- No issues with podman commands
- DAG node ID matches container name

---

## 9. Performance Usecases

### UC-PERF-001: Boot Time Within Threshold

**Preconditions:**
- Standard dev chain (3 core + 3 sidecars)

**Measurement:**
1. Start time recorded
2. All containers healthy
3. End time recorded

**Expected Results:**
- Total boot time < 30s (SC-CEP-004)
- Each layer boots in parallel where possible
- Metrics recorded for trending

---

### UC-PERF-002: Health Check Latency

**Preconditions:**
- Chain healthy

**Measurement:**
1. Time each FPPS method
2. Total verification time per node

**Expected Results:**
- Individual checks < 5s
- Total verification < 30s for all nodes
- SC-PRF-050: Response latency < 50ms

---

### UC-PERF-003: Concurrent Health Checks

**Preconditions:**
- Multiple containers to verify

**Scenario:**
1. Run FPPS for all containers in parallel
2. Aggregate results

**Expected Results:**
- Parallel execution faster than sequential
- No race conditions
- All results collected correctly

---

## Summary

| Category | Usecase Count | STAMP Constraints |
|----------|---------------|-------------------|
| Startup | 7 | SC-CNT-009, SC-CNT-010, SC-CNT-012, SC-CEP-004 |
| Health | 7 | SC-CEP-003, SC-VAL-003 |
| FPPS | 7 | SC-CEP-003, SC-VAL-003 |
| Dependency | 7 | SC-AGT-018 |
| Shutdown | 5 | SC-EMR-057, AOR-SAF-001 |
| Recovery | 4 | - |
| Validation | 3 | SC-CNT-009, SC-CNT-010, SC-CEP-004 |
| Edge Cases | 5 | - |
| Performance | 3 | SC-CEP-004, SC-PRF-050 |
| **Total** | **48** | |

All usecases are designed to validate STAMP safety constraints and ensure
robust operation of the Indrajaal dev/demo service chain.
