# Zenoh Telemetry Mandatory Rule (SC-ZENOH)

## SUPREME REQUIREMENT

**Zenoh-based telemetry MUST be running at ALL times on ALL nodes.**

This is a MUST-HAVE requirement for:
- Real-time observability
- Cluster coordination
- Distributed state synchronization
- SIL-6 compliance monitoring

## STAMP Constraints (Zenoh Telemetry)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-ZENOH-001 | Zenoh NIF MUST be loaded on ALL nodes | CRITICAL | SKIP_ZENOH_NIF=0 |
| SC-ZENOH-002 | Zenoh router MUST be reachable from ALL app nodes | CRITICAL | Health check |
| SC-ZENOH-003 | ZenohTelemetrySubscriber MUST be connected | CRITICAL | Startup validation |
| SC-ZENOH-004 | Telemetry publishing latency < 100ms | HIGH | Metrics monitoring |
| SC-ZENOH-005 | Zenoh session reconnect on failure | HIGH | Auto-reconnect |
| SC-ZENOH-006 | All fractal layers (L1-L7) publish to Zenoh | HIGH | Layer verification |
| SC-ZENOH-007 | Zenoh health included in /health endpoint | CRITICAL | HTTP probe |
| SC-ZENOH-008 | Container MUST NOT start if Zenoh unavailable | CRITICAL | Startup gate |

## AOR Rules (Zenoh Telemetry)

| ID | Rule |
|----|------|
| AOR-ZENOH-001 | NEVER set SKIP_ZENOH_NIF=1 in production or staging |
| AOR-ZENOH-002 | ALWAYS verify Zenoh router is running before app startup |
| AOR-ZENOH-003 | ALWAYS include zenoh-router in compose dependencies |
| AOR-ZENOH-004 | LOG all Zenoh connection state changes |
| AOR-ZENOH-005 | ALERT on Zenoh disconnection > 30 seconds |
| AOR-ZENOH-006 | RETRY Zenoh connection with exponential backoff |
| AOR-ZENOH-007 | PUBLISH node health to zenoh every 10 seconds |
| AOR-ZENOH-008 | SUBSCRIBE to cluster coordination topics on startup |

## Environment Variables

```yaml
# MANDATORY - Zenoh NIF must be active
SKIP_ZENOH_NIF: "0"
SKIP_LINEAGE_NIF: "0"  # Optional, can remain 1
RUSTLER_SKIP_COMPILE: "false"

# Zenoh Router Connection
ZENOH_ENABLED: "true"
ZENOH_ROUTER_ENDPOINT: "tcp/zenoh-router:7447"
ZENOH_MODE: "client"

# Telemetry Topics
QUADPLEX_ZENOH: "true"
QUADPLEX_ZENOH_TOPIC: "indrajaal/logs/cluster/node-{N}"
```

## Container Dependencies

```yaml
services:
  indrajaal-ex-app-1:
    depends_on:
      zenoh-router:
        condition: service_healthy
```

## Health Check Integration

The `/health` endpoint MUST include Zenoh status:

```json
{
  "node": "indrajaal@indrajaal-ex-app-1",
  "status": "healthy",
  "zenoh": {
    "status": "connected",
    "router": "tcp/zenoh-router:7447",
    "session_id": "abc123",
    "subscriptions": 5,
    "publications_per_sec": 10
  }
}
```

## Telemetry Topics (Key Expressions)

| Topic | Direction | Purpose |
|-------|-----------|---------|
| `indrajaal/health/{node}` | Publish | Node health status |
| `indrajaal/metrics/{node}/**` | Publish | Performance metrics |
| `indrajaal/logs/{node}/**` | Publish | Structured logs |
| `indrajaal/cluster/events` | Pub/Sub | Cluster events |
| `indrajaal/sentinel/threats` | Publish | Security alerts |
| `indrajaal/prajna/kpi` | Publish | Cockpit KPIs |

## Startup Sequence

```
1. zenoh-router starts (port 7447)
2. zenoh-router health check passes
3. App container starts
4. Zenoh NIF loads (SKIP_ZENOH_NIF=0)
5. ZenohTelemetrySubscriber connects
6. Health endpoint reports zenoh: connected
7. Node joins cluster with Zenoh coordination
```

## Failure Modes (FMEA)

| Failure Mode | Severity | Detection | RPN | Mitigation |
|--------------|----------|-----------|-----|------------|
| Zenoh router down | 9 | Health check | 81 | depends_on + restart |
| NIF not loaded | 9 | Startup log | 72 | SKIP_ZENOH_NIF=0 enforcement |
| Network partition | 7 | Timeout | 56 | Reconnect with backoff |
| Topic mismatch | 5 | No data | 40 | Topic validation |

## Verification Commands

```bash
# Check Zenoh router
curl -s http://localhost:8000/status

# Check app Zenoh connection
curl -s http://localhost:4000/health | jq '.zenoh'

# Monitor Zenoh traffic
podman exec zenoh-router zenoh --mode peer --connect tcp/127.0.0.1:7447 --subscribe "indrajaal/**"
```

## Integration with Existing Constraints

This rule integrates with:
- SC-OBS-069: Dual Log (Term+Zenoh)
- SC-OBS-071: 4 OTEL modules
- SC-BRIDGE-005: PubSub topics
- SC-MESH-009: Zenoh for real-time telemetry
- SC-UCR-013: Zenoh mesh state via vector clocks

## Violation Response

If Zenoh telemetry is not running:
1. **CRITICAL ALERT** to Prajna Cockpit
2. **BLOCK** new deployments
3. **ESCALATE** to on-call engineer
4. **LOG** to Immutable Register
5. **ATTEMPT** auto-remediation (restart Zenoh session)
