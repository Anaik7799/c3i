# Journal: System Connectors, Use Cases & Fractal Coverage — Full Inventory
**Date**: 2026-04-18 14:00 CEST
**Version**: v22.9.0-AGENTIC-UI-COMPLETE

---

## 1. Scope & Trigger
Operator requested a detailed inventory of all system connectors, supported use cases, and fractal layer coverage. This documents the complete communication surface of the C3I mesh.

## 2. Pre-State Assessment
System is at peak health: 8,112 tests (0 failures), 30/30 pages 8/8 C1-C8 perfect, 120/120 responsive viewport tests, Zenoh connected (12 topics), Fitness A (0.978), 141 tasks completed.

## 3. Execution Detail — Complete Connector Inventory

### 3.1 Elixir Integration Layer (9,451 LOC across 15 modules)

| Connector | Module | LOC | Protocol | Use Case |
|-----------|--------|-----|----------|----------|
| External Connectors Hub | `ExternalConnectors` | 1,147 | REST/GraphQL/gRPC/DB | Universal external API integration |
| Authentication Manager | `AuthenticationManager` | 273 | OAuth2/API Key/JWT | Multi-provider auth for external services |
| Data Mapper | `DataMapper` | 403 | Transform | Schema translation between systems |
| Enterprise API Gateway | `EnterpriseApiGateway` | — | REST + Auth | Rate-limited API proxy |
| Enterprise Gateway (sub) | `gateway.ex, rate_limit.ex, route.ex` | — | HTTP | Request routing + rate limiting |
| Event Streaming | `EventStreaming` | — | Pub/Sub | Real-time event processing pipeline |
| Event Consumer | `event_consumer.ex, stream_processor.ex` | — | Stream | Event consumption + transformation |
| GraphQL Federation | `GraphqlFederation` | — | GraphQL | Federated schema stitching |
| GraphQL Resolver/Schema | `resolver.ex, schema.ex` | — | GraphQL | Query resolution |
| Microservices Orchestrator | `MicroservicesOrchestrator` | — | gRPC/REST | Service mesh coordination |
| Service Discovery | `service_discovery.ex` | — | DNS/Registry | Dynamic service location |
| Load Balancer | `load_balancer.ex` | — | L7 | Traffic distribution |
| Health Checker | `health_checker.ex` | — | HTTP/TCP | Probe + circuit breaker |
| Monitoring Dashboard | `MonitoringDashboard` | 1,291 | Metrics | Observability aggregation |
| OAuth | `OAuth` | 69 | OAuth2 | Token management |
| Zapier | `Zapier` | 28 | Webhook | No-code automation bridge |

### 3.2 Internal Bridges (Elixir ↔ F#/Rust)

| Bridge | Module | Protocol | Direction | Use Case |
|--------|--------|----------|-----------|----------|
| CEPAF Client | `CepafClient` | Erlang Port | Elixir → F# | F# CEPAF function invocation |
| CEPAF Port | `CepafPort` | stdin/stdout | Elixir → F# | Process-level F# bridge |
| CEPAF Zenoh Bridge | `CepafZenohBridge` | Zenoh TCP | F# ↔ Zenoh | Mesh telemetry from F# |
| Cortex Bridge | `CortexBridge` | NIF/Port | Elixir → Rust | Rust cortex daemon access |

### 3.3 Gleam Gateway Layer (719 LOC across 6 modules)

| Gateway | Module | Protocol | Direction | Use Case |
|---------|--------|----------|-----------|----------|
| Telegram | `gateway/telegram.gleam` | Bot API HTTPS | Bidirectional | Chat commands + alerts |
| Google Chat | `gateway/gchat.gleam` | Webhook | Bidirectional | Enterprise chat integration |
| WhatsApp | `gateway/whatsapp.gleam` | Cloud API | Outbound | Mobile notifications |
| MoZ Client | `moz/client.gleam` | Zenoh JSON-RPC | Bidirectional | MCP tool invocation over mesh |
| MoZ Planning | `moz/planning.gleam` | Zenoh JSON-RPC | Request | Task management tools |
| MoZ System | `moz/system.gleam` | Zenoh JSON-RPC | Request | System health tools |

### 3.4 Rust Cortex Connectors (2,572 LOC across 8 modules)

| Connector | Module | LOC | Protocol | Use Case |
|-----------|--------|-----|----------|----------|
| Gateway Broadcast | `gateway.rs` | 198 | HTTPS | Telegram + GChat parallel broadcast |
| Gemini Direct | `mcp_inference.rs` | 663 | HTTPS | LLM Tier 1 (gemini-3.1-flash-lite) |
| OpenRouter | `mcp_inference.rs` | — | HTTPS | LLM Tier 2 (gemini-3-flash) |
| Ollama gemma4 | `mcp_inference.rs` | — | HTTP 11435 | LLM Tier 3 (local 9.6GB) |
| Ollama gemma3 | `mcp_inference.rs` | — | HTTP 11434 | LLM Tier 4 (local 3.3GB) |
| Gemini Live Voice | `gemini_live.rs` | 307 | WebSocket | Real-time voice (250ms latency) |
| SMTP Email | `mcp_gworkspace.rs` | 380 | SMTP + OAuth2 | Email with attachments |
| Google Drive | `mcp_gworkspace.rs` | — | REST API | File upload/backup |
| Web Fetch | `mcp_web.rs` | 45 | HTTPS | Semantic web extraction |
| Browser | `mcp_browser.rs` | 28 | CDP | Playwright browser automation |
| File I/O | `mcp_file.rs` | 59 | Filesystem | Workspace-constrained file ops |
| System Exec | `mcp_sys.rs` | 49 | Shell | Sandboxed command execution |
| Ingress Polling | `ingress_polling.rs` | 331 | HTTPS | Dark cockpit secure outbound |

### 3.5 UI Connectors (Gleam Wisp — port 4100/4101)

| Connector | Protocol | Port | Direction | Use Case |
|-----------|----------|------|-----------|----------|
| HTTP Server | HTTP/1.1 | 4100 | Request/Response | 30 SSR pages + 50+ REST endpoints |
| HTTPS Server | TLS 1.3 | 4101 | Request/Response | Encrypted access |
| WebSocket /ws/planning | WS | 4100 | Bidirectional | Planning real-time push (1s) |
| WebSocket /ws/dashboard | WS | 4100 | Bidirectional | Dashboard real-time push (1s) |
| SSE /ag-ui/run | SSE | 4100 | Server→Client | AG-UI 32-event stream |
| Hot Reload | HTTP POST | 4100 | Request | BEAM bytecode swap |

### 3.6 Mesh Backbone (Zenoh — port 7447)

| Topic Pattern | Protocol | Direction | Use Case |
|---------------|----------|-----------|----------|
| `indrajaal/otel/spans/**` | Zenoh Pub/Sub | Publish | OTel span transport (OoZ) |
| `indrajaal/mcp/req/{tool}/{id}` | Zenoh Pub/Sub | Request | MCP tool invocation (MoZ) |
| `indrajaal/mcp/res/{id}` | Zenoh Pub/Sub | Response | MCP tool result |
| `indrajaal/health/{node}` | Zenoh Pub/Sub | Publish | Node health every 10s |
| `indrajaal/ha/reload/{ts}` | Zenoh Pub/Sub | Publish | Hot reload notification |
| `indrajaal/l0/const/**` | Zenoh Pub/Sub | Publish | L0 Constitutional events |
| `indrajaal/l5/cog/trace/{id}` | Zenoh Pub/Sub | Publish | Pipeline trace |
| `indrajaal/cluster/events` | Zenoh Pub/Sub | Pub/Sub | Cluster coordination |
| `indrajaal/sentinel/threats` | Zenoh Pub/Sub | Publish | Immune system threats |
| `indrajaal/agent/results/{id}` | Zenoh Pub/Sub | Publish | Agent output |
| `indrajaal/plan/spans/**` | Zenoh Pub/Sub | Publish | Task mutation audit |
| `indrajaal/ignition/**` | Zenoh Pub/Sub | Publish | Boot sequence telemetry |

## 4. Root Cause Analysis
**Why 30+ connectors?** The C3I system is a mesh orchestrator — it must talk to everything: chat platforms (Telegram/GChat/WhatsApp), LLMs (4-tier cascade), databases (SQLite/DuckDB/PostgreSQL), containers (Podman), observability (OTel/Prometheus/Grafana), file systems, email, cloud storage, and the Zenoh mesh backbone. Each connector serves a specific fractal layer.

## 5. Fix Taxonomy — Connector Classification

| Category | Count | Protocols |
|----------|-------|-----------|
| Chat/Messaging | 4 | Telegram Bot API, GChat Webhook, WhatsApp Cloud, SMTP |
| LLM Inference | 5 | Gemini HTTPS, OpenRouter HTTPS, Ollama HTTP ×2, Gemini Live WS |
| Database | 3 | SQLite WAL, DuckDB, PostgreSQL |
| Mesh Transport | 1 | Zenoh TCP Pub/Sub (12 topic patterns) |
| Web/API | 5 | REST, GraphQL, gRPC, OAuth2, Webhook |
| UI Transport | 4 | HTTP, HTTPS, WebSocket, SSE |
| Infrastructure | 4 | Podman UDS, Erlang Port, NIF FFI, Shell Exec |
| File/Storage | 2 | Filesystem, Google Drive |
| Observability | 3 | OTel gRPC, Prometheus, Zenoh OoZ |
| **TOTAL** | **~31** | **15 distinct protocols** |

## 6. Patterns & Anti-Patterns Discovered

### Pattern: 6-Tier Hedged Inference
```
Tier 1+2: Gemini Direct || OpenRouter (parallel, first wins)
Tier 3: Ollama gemma4 (local fallback)
Tier 4: Ollama gemma3 (lighter fallback)
Tier 5: RETE-UL rule engine (<1ms, no network)
Tier 6: Static ack (guaranteed response)
```
**No-Blackhole Guarantee**: 7 mechanisms ensure every message gets a response.

### Pattern: Dark Cockpit Outbound Polling
Ingress polling uses secure outbound HTTPS (not inbound webhooks) — no open ports needed for Telegram/GChat. The system reaches out to fetch messages.

### Anti-Pattern: Three MCP Ecosystems
(From [zk-70225384857f4059]) Both Gleam c3i_nif and sa-plan-daemon have overlapping `plan_*` methods. Should be unified via MoZ.

## 7. Verification Matrix — Use Cases Supported

### 7.1 Operator Use Cases (via Agentic UI)

| Use Case | Pages | Connectors Used |
|----------|-------|-----------------|
| **Monitor system health** | Dashboard, Cockpit, Health-Grid | NIF → SSR, WebSocket, Guard Grid |
| **View task pipeline** | Planning, Planning-Dashboard | NIF plan_status, WebSocket |
| **Manage containers** | Podman | NIF, Podman UDS, Action Buttons |
| **Emergency stop** | Cockpit, Dashboard | POST /api/v1/emergency-stop, Guardian |
| **Hot reload code** | Dashboard, Config | POST /api/v1/reload, BEAM code server |
| **Create tasks** | Planning | POST form → NIF plan_add |
| **Search knowledge** | Knowledge, Smriti | NIF plan_search, ZK FTS5 |
| **View Zenoh mesh** | Zenoh | NIF system_zenoh, TCP 7447 probe |
| **Check immune system** | Immune | NIF system_immune, Psi invariants |
| **Approve L0 actions** | Bicameral, Immune | Guardian 2oo3 consensus |
| **Acknowledge alarms** | Cockpit | POST alarm/acknowledge |
| **View OODA cycle** | Agents, Prajna | system_ooda API, OODA trace |
| **Check federation** | Federation | system health, peer list |
| **Debug NIF latency** | Telemetry, Substrate | NIF latency panel |
| **View guard grid** | Health-Grid, Verification | Guard grid API, 24 cells |
| **Inspect Zenoh messages** | Zenoh | Zenoh inspector panel |

### 7.2 Agent Use Cases (via Cortex + MoZ)

| Use Case | Connector | Protocol |
|----------|-----------|----------|
| **Process chat intent** | Telegram/GChat → Cortex | Polling + Hedged Inference |
| **Voice command** | Gemini Live WebSocket | Real-time audio transcription |
| **RAG knowledge lookup** | Smriti FTS5 | SQLite full-text search |
| **Send email** | SMTP (lettre) | OAuth2 app password |
| **Upload to Drive** | Google Drive REST | File backup |
| **Browse web** | Playwright CDP | Semantic extraction |
| **Execute command** | mcp_sys | Sandboxed shell |
| **Publish to Zenoh** | Zenoh NIF | Topic publish |
| **MCP tool invocation** | MoZ JSON-RPC | Request/Response over Zenoh |

### 7.3 Autonomous Use Cases (via OODA + Guard Grid)

| Use Case | Trigger | Connector | Action |
|----------|---------|-----------|--------|
| **Health monitoring** | 10s OODA cycle | Guard grid actor + ETS | 85 rules evaluated |
| **Self-observation** | 60s truth audit | Self-observer actor | 12 invariant checks |
| **Cascade detection** | Wolfram Rule 110 | Guard grid CA | Classify failure pattern |
| **Auto-heal NIF** | 3 consecutive failures | GR-007 rule | Trigger hot reload |
| **Emergency escalation** | Health < 30% | GR-002 rule | Cockpit → Emergency mode |
| **Proactive alerting** | Health declining | GR-020 rule | Predict emergency in ~70s |
| **Jidoka halt** | L0 Constitutional threat | GR-003 rule | Immediate stop |

## 8. Files Referenced
| Category | Files | LOC |
|----------|-------|-----|
| Elixir Integration | 15 modules + 13 sub-modules | 22,266 |
| Gleam Gateway + MoZ | 6 modules | 719 |
| Rust Connectors | 8 modules | 2,572 |
| Gleam UI (Wisp) | 25 API modules | 2,278+ |
| Zenoh OTel | 1 module | — |
| **TOTAL** | **~68 modules** | **~27,835** |

## 9. Architectural Observations
1. **15 distinct protocols**: The system speaks REST, GraphQL, gRPC, WebSocket, SSE, SMTP, OAuth2, Zenoh Pub/Sub, SQLite FTS5, CDP, Erlang Port, NIF FFI, Shell, HTTP, TLS.
2. **4-language connector surface**: Elixir (integration), Gleam (gateway/UI), Rust (cortex/inference), F# (CEPAF bridge) — each language handles what it's best at.
3. **No-Blackhole Guarantee**: 7 fallback mechanisms in the 6-tier inference cascade ensure 100% response rate.
4. **Dark Cockpit pattern**: Outbound polling (not webhooks) means zero inbound ports for chat — maximum security.
5. **Zenoh is the universal backplane**: 12 topic patterns cover health, OTel, MCP, cluster, sentinel, agent, plan, and ignition.

## 10. Remaining Gaps
- **WebSocket on 28 more pages**: Only /ws/planning and /ws/dashboard have WS — 28 pages need push
- **gRPC stub**: External connector gRPC path exists but isn't fully implemented
- **Zapier stub**: 28 lines — webhook bridge is minimal
- **WhatsApp**: Outbound only — no inbound message processing yet

## 11. Metrics Summary
| Metric | Value |
|--------|-------|
| Total connectors | ~31 distinct |
| Protocols supported | 15 |
| Connector LOC | ~27,835 |
| Languages | 4 (Elixir, Gleam, Rust, F#) |
| Zenoh topics | 12 patterns |
| LLM tiers | 6 (hedged parallel) |
| Chat gateways | 3 (Telegram, GChat, WhatsApp) |
| API endpoints | 50+ (Wisp REST) |
| MCP tools | 73 (26 NIF + 47 sa-plan-daemon) |
| Operator UI use cases | 16 |
| Agent use cases | 9 |
| Autonomous use cases | 7 |

## 12. STAMP & Constitutional Alignment
- **SC-ZMOF-001**: Zenoh is SOLE internal transport — all 12 topic patterns active
- **SC-ZMOF-COMMS-001**: Internal comms via Zenoh, external via HTTP/WS
- **SC-OPENCLAW-001**: Voice (5-tier), Tools (6 MCP), Skills (skill loader), Context (isolated actors)
- **SC-COG-001**: 6-tier hedged inference with circuit breakers
- **SC-HA-001**: Zero-downtime hot reload, leader election via Zenoh lease
- **SC-ZENOH-001**: Zenoh NIF loaded on all nodes, health published every 10s
- **Psi-0 (Existence)**: No-Blackhole guarantee — system always responds

## 13. Conclusion
The C3I system has 31 distinct connectors speaking 15 protocols across 4 programming languages, serving 32 use cases (16 operator, 9 agent, 7 autonomous). The Zenoh mesh backbone unifies internal communication with 12 topic patterns, while the 6-tier hedged inference cascade guarantees 100% response rate. The connector surface area totals ~27,835 LOC across 68 modules. Every connector maps to a specific fractal layer, and every use case is accessible through the Agentic UI's 30 pages with live NIF data.
