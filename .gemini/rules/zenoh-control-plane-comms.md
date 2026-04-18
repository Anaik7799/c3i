# Zenoh Control & Data Plane Communications (SC-ZMOF-COMMS)
# ज़ीनो नियंत्रण एवं आंकड़ा तल संचार

## Mandate (आदेश)
**ALL inter-component communication MUST use Zenoh pub/sub as the SOLE transport.**
No direct HTTP between internal components. No file-based IPC. No shared memory.
Zenoh IS the nervous system (नाड़ी तन्त्र) of the mesh.

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ZMOF-COMMS-001 | Internal component comms MUST use Zenoh pub/sub | CRITICAL |
| SC-ZMOF-COMMS-002 | External API (browser/client) MAY use HTTP/WS | HIGH |
| SC-ZMOF-COMMS-003 | OTel spans MUST be transported over Zenoh (OoZ) | CRITICAL |
| SC-ZMOF-COMMS-004 | MCP tool calls MUST use Zenoh JSON-RPC (MoZ) | HIGH |
| SC-ZMOF-COMMS-005 | Hot reload notifications MUST be published to Zenoh | HIGH |
| SC-ZMOF-COMMS-006 | Health checks MUST be published to Zenoh every 10s | HIGH |

## Architecture (वास्तुकला)

### Communication Layers
```
┌─────────────────────────────────────────────────┐
│                EXTERNAL (बाह्य)                  │
│  Browser ──HTTP/WS──▶ Mist (port 4100)          │
│  CLI ──────stdin──▶ TUI ANSI                     │
│  Telegram ─webhook──▶ Gateway (L7)               │
├─────────────────────────────────────────────────┤
│             ZENOH BACKPLANE (मेरुदण्ड)           │
│                                                   │
│  indrajaal/otel/spans/{page}/{op}    ← OoZ       │
│  indrajaal/mcp/req/{tool}/{id}       ← MoZ req   │
│  indrajaal/mcp/res/{id}              ← MoZ res   │
│  indrajaal/health/{node}             ← Health     │
│  indrajaal/ha/reload/{module}        ← Hot reload │
│  indrajaal/l0/const/**               ← L0 safety │
│  indrajaal/l5/cog/trace/{id}         ← Pipeline  │
│  indrajaal/cluster/events            ← Cluster    │
│  indrajaal/sentinel/threats          ← Immune     │
│  indrajaal/agent/results/{id}        ← Agent out  │
│                                                   │
│  TCP 7447 — 4 Zenoh routers (quorum mesh)        │
├─────────────────────────────────────────────────┤
│              INTERNAL (आंतरिक)                    │
│  sa-plan-daemon ──Zenoh──▶ Gleam cortex          │
│  Rule engine ────Zenoh──▶ OODA supervisor        │
│  NIF bridge ─────Zenoh──▶ Telemetry collector    │
│  Health probe ───Zenoh──▶ Dashboard WS           │
└─────────────────────────────────────────────────┘
```

### Hot Reload via Zenoh (उष्ण पुनःलोड)
When hot reload completes, publish to Zenoh:
```
Topic: indrajaal/ha/reload/{timestamp}
Payload: { "modules": ["page_views", "router"], "count": 2, "md5_verified": true }
```
All subscribers (dashboard WS, TUI, monitoring) receive notification instantly.

## Mathematical Properties (गणितीय गुण)
```
Latency: O(1) pub/sub vs O(n) polling
  Zenoh pub/sub: ~1ms delivery to all subscribers
  HTTP polling: n × interval_ms (where n = subscriber count)
  
Bandwidth: O(1) per message vs O(n) per poll cycle
  Zenoh: 1 publish → N subscribers (multicast)
  HTTP: N separate request-response cycles

Reliability: Zenoh provides:
  - At-most-once (default, lowest latency)
  - At-least-once (with reliability: reliable)
  - Exactly-once (with transactional semantics)
```

## Agent Communication Pattern (एजेंट संचार)
```
Agent A publishes result:
  zenoh.put("indrajaal/agent/results/A", result_json)

Dashboard subscribes:
  zenoh.subscribe("indrajaal/agent/results/**", callback)

No polling. No HTTP. No file watching.
The Zenoh mesh IS the communication fabric.
```
