---
name: zenoh
description: Zenoh mesh control — session, publish, subscribe, query via native FFI MCP
---
---

# Zenoh Mesh Control (SC-ZENOH-001 to SC-ZENOH-008)

Real-time Zenoh pub/sub mesh control via native FFI MCP bridge (libzenoh_ffi.so → F# DllImport → MCP).

## Usage
```
/zenoh session open              # Open Zenoh session to router
/zenoh session stats             # Get session metrics + invariant verification
/zenoh pub indrajaal/test/hello "world"   # Publish message
/zenoh sub indrajaal/**          # Subscribe to all topics
/zenoh query get indrajaal/health/*       # Query key expressions
/zenoh monitor                   # Full mesh monitoring cycle
/zenoh verify                    # Run formal invariant verification
```

## Commands

### Session Management
1. **open**: `zenoh_session(action: "open", mode: "client", endpoints: "tcp/localhost:7447")`
2. **close**: `zenoh_session(action: "close")`
3. **stats**: `zenoh_session(action: "stats")` — returns 27 atomic counters + 4 latency histograms

### Publish (SC-ZTEST-003: latency < 10ms)
`zenoh_pub(key: "indrajaal/{domain}/{topic}", payload: "{json}")`

### Subscribe (SC-ZTEST-012: FIFO ordering)
1. `zenoh_sub(action: "subscribe", key: "indrajaal/**")` — returns subscription ID
2. `zenoh_sub(action: "poll", id: "{sub_id}", limit: 50)` — poll messages
3. `zenoh_sub(action: "unsubscribe", id: "{sub_id}")` — cleanup

### Query (SC-ZENOH-004: latency < 100ms)
1. `zenoh_query(action: "get", key: "indrajaal/health/*")` — GET on key expression
2. `zenoh_query(action: "metrics")` — FFI bridge metrics (27 counters)
3. `zenoh_query(action: "verify")` — 12 formal invariants (INV-1 through INV-12)

## Monitor Workflow (Full Mesh Cycle)
1. Open session: `zenoh_session(action: "open")`
2. Subscribe: `zenoh_sub(action: "subscribe", key: "indrajaal/health/**")`
3. Poll health: `zenoh_sub(action: "poll", id: "{id}", limit: 20)`
4. Query metrics: `zenoh_query(action: "metrics")`
5. Verify invariants: `zenoh_query(action: "verify")`
6. Report mesh status with topology map

## Key Topic Hierarchy (SC-ZEN-003)
```
indrajaal/
├── health/{node}           # Node health (10s interval)
├── metrics/{node}/**       # Performance metrics
├── logs/{node}/**          # Structured logs
├── cluster/events          # Cluster coordination
├── sentinel/threats        # Security alerts
├── prajna/kpi              # Cockpit KPIs
├── control/**              # Imperative commands (Ω₁₀)
├── cepaf/cmd/*             # F# commands
├── cepaf/evt/*             # F# events
├── cepaf/query/*           # F# queries
├── container/{name}/health # Container health (30s)
├── container/{name}/metrics # Container metrics
├── smoke/batch/{id}/**     # Smoke test checkpoints
├── planning/events         # Task management events
├── math/health             # Mathematical discipline health
├── test/evolution          # Test evolution metrics
└── db/{uhi}/{operation}    # Cross-holon DB access
```

## STAMP Constraints
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-ZENOH-001 | NIF loaded on all nodes | session stats |
| SC-ZENOH-002 | Router reachable | session open |
| SC-ZENOH-004 | Telemetry < 100ms | query metrics |
| SC-ZTEST-003 | Publish < 10ms | query metrics |
| SC-ZEN-001 | ALL Elixir↔F# via Zenoh | verify |

## Mathematical Foundation

**Pub/Sub Latency**: $L_{p2p} = L_{pub} + L_{route} + L_{sub} < 100ms$ (SC-ZENOH-004)

**Throughput**: $T = \frac{N_{msg}}{t_{window}}$ messages/sec

**Topic Fanout**: $F(k) = |\{s \mid s \text{ subscribes to } k\}|$ — subscribers per key expression

**FIFO Ordering** (SC-ZTEST-012): $\forall m_1, m_2 \in topic: send(m_1) < send(m_2) \implies recv(m_1) < recv(m_2)$

**Session Reliability**: $R_{session} = \frac{t_{connected}}{t_{total}}$ — uptime fraction

## FFI Invariants (12 formal, all verified)
INV-1: Session handle non-null after open
INV-2: Publish returns success for valid key
INV-3: Subscribe returns unique subscription ID
INV-4: Metrics counters monotonically increase
INV-5 through INV-12: See ZenohFfiBridgeTests.fs
