# SC-C3I-ARCH-001: The Zenoh-MCP-OTel Fractal Backplane (ZMOF)
**Version**: 1.0.0 | **Status**: MANDATORY | **Date**: 2026-04-04

## 1. The Unified Fractal Namespace
All system communication MUST utilize Zenoh Key Expressions mapped to the L0-L7 fractal layers. Point-to-point HTTP/gRPC is PROHIBITED for internal mesh control.

| Layer | Zenoh Key Expression Prefix | Domain Responsibility |
|:---|:---|:---|
| **L0** | `indrajaal/l0/const/**` | Constitutional, Safety Kernel, Guardian |
| **L1** | `indrajaal/l1/atomic/**` | NIFs, Substrate, Hardware Probes |
| **L2** | `indrajaal/l2/health/**` | FPPS Consensus, 2oo3 Voting, Quorum |
| **L3** | `indrajaal/l3/trans/**` | Persistence, SQLite, Ledger, Build History |
| **L4** | `indrajaal/l4/system/**` | Podman, Container Ops, Ignition, Mesh State |
| **L5** | `indrajaal/l5/cog/**` | OODA Loop, Rule Engine (GRL), AI Reasoning |
| **L6** | `indrajaal/l6/mesh/**` | Zenoh Topology, Routing, Network Partitions |
| **L7** | `indrajaal/l7/fed/**` | Peer Discovery, Attestation, Multi-Mesh |

## 2. OTel-over-Zenoh Protocol (OoZ)
Standard OTel exporters (gRPC/HTTP) are deprecated. All components MUST publish spans to Zenoh.

- **Topic**: `indrajaal/otel/span/{layer}/{entity_id}`
- **Payload**: Canonical JSON-serialized OTel Span.
- **Ingestion**: `indrajaal-obs-prod` runs a `zenoh-otel-ingestor` that bridges to Prometheus/Jaeger.
- **Benefit**: Trace persistence during network partitions; zero-configuration observability for new nodes.

## 3. MCP-over-Zenoh (MoZ) for Agentic Mesh
Model Context Protocol (JSON-RPC) is layered over Zenoh Pub/Sub to create a decentralized tool network.

- **Tool Request**: `indrajaal/mcp/req/{tool_name}/{request_id}`
- **Tool Response**: `indrajaal/mcp/res/{request_id}`
- **Discovery**: `indrajaal/mcp/catalog/{node_id}` (Published on heartbeat)
- **Constraint**: Every `sa-up` action (Launch, Restart, Drain) MUST be exposed as an MoZ tool.

## 4. Fractal Messaging Constraints
- **SC-MSG-001**: Every state change in the OODA loop MUST publish a Zenoh message.
- **SC-MSG-002**: UI components (Lustre/TUI) SHALL be stateless subscribers to `indrajaal/**/state`.
- **SC-MSG-003**: All high-salience Rule Engine decisions MUST include a `trace_id` for OTel correlation.
- **SC-MSG-004**: Heartbeats MUST be published to `indrajaal/{layer}/{entity}/heartbeat` every 1000ms.

## 5. Compliance Verification
1. `sa-up observer` MUST show a unified stream of Spans, Tool Calls, and State changes.
2. `zenoh-bridge-mcp` MUST register in the Gemini/Cortex tool catalog automatically.
3. 2oo3 consensus (L2) MUST be achieved via Zenoh broadcast to be valid.
