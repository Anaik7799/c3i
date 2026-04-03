# Comprehensive System Catalog Exploration
**Date**: 2026-01-10
**Session**: System Documentation Sprint
**Author**: Claude Opus 4.5
**Duration**: ~45 minutes
**Artifacts Created**: 1 master document (SYSTEM_CATALOG_MASTER.md)

---

## Executive Summary

Conducted a comprehensive 4-agent parallel exploration of the entire Indrajaal v21.3.0 SIL-6 Biomorphic Fractal Mesh codebase to create a master system catalog documenting:
- All systems and their features
- Lifecycle phase usage
- Setup and usage procedures
- System interactions
- SOP impacts and new protocols required
- Data and knowledge management requirements

---

## Exploration Methodology

### Agents Deployed

| Agent ID | Focus Area | Files Analyzed | Duration |
|----------|------------|----------------|----------|
| ad19046 | Elixir Systems | 1,294 files | ~8 min |
| a74b456 | F# Cortex & Infrastructure | 300+ files | ~10 min |
| a09db36 | Scripts & SOPs | 1,634 scripts | ~12 min |
| a8f1ccf | Data & KMS | 25 directories | ~8 min |

---

## DETAILED FINDINGS

---

## 1. ELIXIR SYSTEMS INVENTORY (Agent ad19046)

### 1.1 Scale Metrics

| Metric | Count |
|--------|-------|
| **Total Elixir Files** | 1,294 |
| **lib/indrajaal/** | 1,158 modules |
| **lib/indrajaal_web/** | 136 modules |
| **Major Domains** | ~30 |
| **Fractal Layers** | 7 (Function → Federation) |

### 1.2 Distributed Systems (`lib/indrajaal/distributed/`)

#### 1.2.1 Agents (`distributed/agents/`)
**Path**: `lib/indrajaal/distributed/agents/`

**8 Agent Types Discovered**:
1. `base_agent.ex` - Common agent functionality, callbacks, state publishing
2. `ooda_agent.ex` - OODA loop agent (Observe-Orient-Decide-Act) - 642 lines
3. `sentinel_agent.ex` - Health monitoring agent
4. `cortex_agent.ex` - AI/cognitive agent
5. `cepaf_agent.ex` - F# bridge agent
6. `kpi_dashboard_agent.ex` - KPI visualization agent
7. `fractal_agent.ex` - Fractal layer coordinator
8. `ace_agent.ex` - ACE (Autonomous Cybernetic Evolution) agent

**Key APIs**:
```elixir
BaseAgent.start_link/1
BaseAgent.get_state/0
BaseAgent.get_metrics/0
handle_command/3 # callback
```

**Lifecycle Phase**: Operations + Monitoring
**Dependencies**: Zenoh NIF, UnifiedBus, FQUN registry
**STAMP Constraints**: SC-AGT-017, SC-AGT-018, SC-AGT-019

#### 1.2.2 Mesh (`distributed/mesh/`)
**Path**: `lib/indrajaal/distributed/mesh/`

**Modules Discovered**:
- `discovery.ex` - Node discovery via Zenoh
- `gossip.ex` - State synchronization protocol
- `holography.ex` - Holographic state replication
- `mycelium.ex` - Mesh network coordination
- `partition.ex` - Network partition handling
- `routing.ex` - Message routing in mesh

**Key APIs**:
```elixir
Discovery.announce_node/1
Gossip.sync_state/2
Holography.replicate/2
Routing.route_message/3
```

**Lifecycle Phase**: Deployment + Operations
**Setup Requirements**: Zenoh router (port 7447), DuckDB

#### 1.2.3 Other Distributed
- `distributed/gravity/` - Work distribution and load balancing
- `distributed/workers/` - Distributed worker pool management

### 1.3 Control Systems (`lib/indrajaal/control/`)

#### 1.3.1 UnifiedBus (`control/unified_bus.ex`)
**Features**:
- High-performance async event bus (<50ms latency)
- Couples all cybernetic control loops (OODA, FastOODA, ACE, Homeostasis, GDE)
- Circuit breaker protection (>1000 events/sec triggers breaker)
- Guaranteed FIFO event ordering per topic
- Non-blocking message delivery

**STAMP Constraints**: SC-BUS-001 to SC-BUS-005

**Key APIs**:
```elixir
UnifiedBus.publish/2
UnifiedBus.subscribe/2
UnifiedBus.broadcast/2
UnifiedBus.get_circuit_state/0
```

**Dependencies**: None (foundational)
**Dependents**: All control loops

#### 1.3.2 LoopCoupling (`control/loop_coupling.ex`)
- Coordinates multiple OODA loops to prevent oscillation

### 1.4 Cortex Systems (`lib/indrajaal/cortex/`)

#### 1.4.1 FastOODA (`cortex/fast_ooda.ex`)
**Features**:
- High-frequency OODA loop targeting <50ms cycle time (300x faster than standard)
- Autonomous evolution capability
- Hysteresis mode to prevent decision oscillation (10% margin, 3-cycle hold)
- AI-assisted orientation with 20ms timeout
- Latency tracking (p50, p95, p99)

**STAMP Constraints**: SC-OODA-001 to SC-OODA-006

**Key APIs**:
```elixir
FastOODA.start_link/1
FastOODA.observe/0  # Async observation
FastOODA.orient/1   # Fast pattern analysis
FastOODA.decide/1   # Rule-based decision
FastOODA.act/1      # Execute via UnifiedBus
```

**Dependencies**: UnifiedBus, OpenRouter (AI), Guardian, Sensors

#### 1.4.2 Other Cortex Modules
- `controller.ex` - Standard 30-second OODA loop for strategic decisions
- `digital_twin.ex` - Real-time system state mirror for simulation
- `homeostasis.ex` - Self-regulating system balance
- `synapse.ex` - Neural-inspired message passing

**Subdirectories**:
- `cortex/ai/` - AI model integration
- `cortex/analysis/` - System analysis tools
- `cortex/evolution/` - Self-modifying code (GDE)
- `cortex/gde/` - Goal-Directed Evolution
- `cortex/homeostasis/` - Homeostatic controllers
- `cortex/reflexes/` - Fast reaction patterns
- `cortex/sensors/` - System sensors (CPU, memory, containers)

### 1.5 Core Systems (`lib/indrajaal/core/`)

#### 1.5.1 Holon System (`core/holon/`)
**Features**:
- Fractal architecture (7 layers: Function → Federation)
- VSM (Viable System Model) implementation (S1-S5)
- Founder's Directive (supreme goal alignment)
- Immutable Register (blockchain-style state)
- SQLite/DuckDB-based state (portable, regenerative)

**Key Modules**:
- `holon.ex` - Core holon behavior (5 systems: S1-S5)
- `state.ex` - Holon state management
- `supervisor.ex` - Holon lifecycle
- `immutable_register.ex` - Append-only state log with Ed25519 signatures
- `founder_directive.ex` - Ω₀ Supreme Directive implementation
- `founder_wealth_redirect.ex` - Resource acquisition for founder
- `capability_token.ex` - Unforgeable capability-based security
- `health.ex` - Health propagation
- `metrics.ex` - Holon metrics
- `fractal.ex` - Fractal layer coordination

**STAMP Constraints**: SC-HOLON-001 to SC-HOLON-020, SC-REG-001 to SC-REG-015

**Key APIs**:
```elixir
Holon.system1_operations/1  # Business logic
Holon.system2_coordination/1 # Peer balance
Holon.system3_control/1      # Resource limits
Holon.system4_intelligence/1 # Planning
Holon.system5_policy/0       # Constitution
ImmutableRegister.append/2   # State mutation
FounderDirective.validate/1  # Goal alignment
```

#### 1.5.2 Constitution (`core/constitution/`)
- `constitution.ex` - Constitution definition
- `verifier.ex` - Verification logic
- `hash.ex` - Constitution hash
- `dead_mans_switch.ex` - Founder protection

**STAMP Constraints**: SC-CONST-001 to SC-CONST-010

#### 1.5.3 VSM (`core/vsm/`)
- `system1_operations.ex` - Operations layer
- `system2_coordination.ex` - Coordination layer
- `system3_control.ex` - Control layer
- `system4_intelligence.ex` - Intelligence layer
- `system5_policy.ex` - Policy layer

### 1.6 KMS System (`lib/indrajaal/kms/`)

#### 1.6.1 KMS Service (`kms/service.ex`)
**Features**:
- Fractal Holonic Knowledge Management
- SQLite for OLTP (real-time state, WAL mode)
- DuckDB for OLAP (analytics, history, append-only)
- Cross-runtime access (Elixir + F# share databases)
- Portable holons via directory copy
- OODA cycle <100ms on SQLite hot path

**Data Directory**: `data/kms/{node_id}/`
**Files**: `holons.db` (SQLite), `analytics.duckdb` (DuckDB)

**STAMP Constraints**: SC-KMS-001 to SC-KMS-004

**Key APIs**:
```elixir
KMS.Service.create_holon/1
KMS.Service.get_holon/1
KMS.Service.query_analytics/1
KMS.SQLite.execute/2
KMS.Analytics.aggregate/2
```

#### 1.6.2 KMS Modules
- `sqlite.ex` - SQLite interface
- `analytics.ex` - DuckDB analytics
- `graphiti_bridge.ex` - Knowledge graph integration
- `zenoh_kms_publisher.ex` - Publish KMS events to Zenoh
- `federation.ex` - Cross-node knowledge sharing
- `mcp_server.ex` - Model Context Protocol server
- `integrity_monitor.ex` - Data integrity checks

**Resources** (`kms/resources/`):
- `todo.ex` - Task management Ash resource
- `todo_dependency.ex` - Task dependency graph

### 1.7 Safety & Immune System (`lib/indrajaal/safety/`)

#### 1.7.1 Guardian (`safety/guardian.ex`)
**Features**:
- Simplex Architecture Decision Module
- Validates all AI/autonomic decisions against safety envelope
- Absolute veto authority (cannot be overridden)
- SIL-2 certified, no dynamic dispatch
- Founder's Directive enforcement (Ω₀)

**STAMP Constraints**: SC-GUARD-001 to SC-GUARD-003, SC-FOUNDER-001

**Key APIs**:
```elixir
Guardian.validate_proposal/1
# Returns {:ok, proposal} | {:veto, reason, safe_fallback}
Guardian.check_safety_envelope/1
Guardian.get_fallback_action/1
```

#### 1.7.2 Sentinel (`safety/sentinel.ex`)
**Features**:
- Digital Immune System (T-Cell active hunter)
- Proactive pre-error signature detection
- Health scoring (0-100 scale, multi-dimensional)
- Quarantine protocol (surgical suspension via `:sys.suspend/1`)
- Threat escalation to Guardian

**Health Score Dimensions**:
- Memory pressure: 30% weight
- CPU utilization: 20% weight
- Error rate: 25% weight
- Process anomalies: 15% weight
- Quarantine status: 10% weight

**STAMP Constraints**: SC-IMMUNE-001 to SC-IMMUNE-003, SC-PRIME-001

**Key APIs**:
```elixir
Sentinel.start_monitoring/1
Sentinel.get_health_score/1
Sentinel.quarantine/2
Sentinel.initiate_recovery/2
Sentinel.assess_now/0
```

#### 1.7.3 PatternHunter (`safety/pattern_hunter.ex`)
**Features**:
- Memory leak detection (10+ samples with monotonic increase)
- CPU spike detection (>90% for >60 seconds)
- Message queue growth analysis (>1000 messages with growth rate >100/sec)
- Pre-error pattern recognition
- Threat scoring with RPN (Risk Priority Number)

**STAMP Constraints**: SC-IMMUNE-004, SC-IMMUNE-009

**Key APIs**:
```elixir
PatternHunter.hunt_patterns/0
PatternHunter.analyze_memory/1
PatternHunter.calculate_threat_score/1
```

#### 1.7.4 SymbioticDefense (`safety/symbiotic_defense.ex`)
**Features**:
- Coordinated multi-module defense response
- Threat-level-based escalation (Green → Yellow → Orange → Red → Black)
- Response time by severity:
  - Black (Founder threat): 100ms
  - Red (Critical): 500ms
  - Orange (High): 2000ms
- Threat classification: Lineage > Existential > Financial > Reputational > Operational

**STAMP Constraints**: SC-IMMUNE-007, SC-IMMUNE-008, SC-FOUNDER-007

#### 1.7.5 Other Safety Modules
- `envelope.ex` - Safety constraint envelope definition
- `dead_mans_switch.ex` - Heartbeat monitoring
- `incident_coordinator.ex` - Incident response orchestration
- `monitor.ex` - Safety monitoring
- `pattern_database.ex` - Known pattern database
- `stamp_registry.ex` - STAMP constraint registry
- `antibody.ex` - Auto-generated threat antibodies
- `mara.ex` - Chaos engineering for resilience testing
- `error_pattern_engine.ex` - Error pattern analysis

### 1.8 Observability Systems (`lib/indrajaal/observability/`)

#### 1.8.1 Zenoh Bridges
**Modules**:
- `zenoh_liveview_bridge.ex` - Real-time UI updates (<50ms latency)
- `zenoh_kpi_publisher.ex` - KPI publishing
- `zenoh_domain_publisher.ex` - Domain-specific events
- `zenoh_container_publisher.ex` - Container telemetry
- `zenoh_agent_mesh_publisher.ex` - Agent mesh state
- `zenoh_biomorphic_publisher.ex` - Biomorphic evolution events
- `zenoh_evolution_publisher.ex` - Evolution tracking
- `zenoh_fractal_publisher.ex` - Fractal layer telemetry
- `zenoh_neural_stream.ex` - Neural telemetry streaming
- `zenoh_polyglot_bridge.ex` - Cross-language bridge
- `zenoh_time_travel.ex` - Time-travel debugging

**Bridged Topics**:
- `zenoh:kpi` - Key Performance Indicators
- `zenoh:metrics` - System metrics
- `zenoh:agents` - Agent status
- `zenoh:alerts` - Alerts
- `zenoh:health` - Health status
- `zenoh:evolution` - Evolution events
- `zenoh:fractal` - Fractal telemetry
- `zenoh:safety` - Safety events

**STAMP Constraints**: SC-BRIDGE-001 to SC-BRIDGE-003, SC-PRF-050

#### 1.8.2 Fractal Logger (`observability/fractal/`)
**Features**:
- 5-level fractal logging (L5-SPINE to L1-GOSSAMER)
- Hybrid Logical Clock for distributed ordering
- PII masking and data classification
- Batch encoding for performance
- OTEL integration
- Zenoh publishing

**Modules**:
- `logger.ex` - Main fractal logger
- `hlc.ex` - Hybrid Logical Clock
- `pii_masker.ex` - PII scrubbing
- `batch_encoder.ex` - Efficient batch encoding
- `content_router.ex` - Route logs to destinations
- `otel_integration.ex` - OpenTelemetry integration
- `cybernetic_controller.ex` - Logging rate control
- `decorator.ex` - Log decoration
- `supervisor.ex` - Fractal logger supervision

#### 1.8.3 Telemetry & Monitoring
- `telemetry.ex` - System telemetry
- `telemetry_handlers.ex` - Telemetry event handlers
- `metrics.ex` - Metrics collection
- `health_check.ex` - System health checks
- `instrumentation_base.ex` - Instrumentation framework
- `performance_analytics.ex` - Performance analysis
- `progress_tracker.ex` - Progress tracking
- `dashboard_templates.ex` - Dashboard templates
- `enhanced_dashboard.ex` - Enhanced observability UI

**Domain Instrumentation** (`observability/domains/`):
26 domain-specific instrumentation modules

#### 1.8.4 OTEL Integration
- `otel_sdk.ex` - OpenTelemetry SDK integration
- `otlp_exporter.ex` - OTLP export
- `otel_logger.ex` - OTEL-compatible logger
- `tracing.ex` - Distributed tracing
- `context_propagation.ex` - Trace context propagation

### 1.9 AI & ML Systems (`lib/indrajaal/ai/`)

#### 1.9.1 OpenRouter Integration
**Modules**:
- `open_router_client.ex` - OpenRouter API client
- `cost_monitor.ex` - AI cost tracking
- `pricing.ex` - Model pricing
- `pricing_cache.ex` - Pricing cache
- `pricing_metrics.ex` - Pricing analytics
- `pricing_verification.ex` - Price validation
- `provider_dispatcher.ex` - Multi-provider dispatch
- `token_bucket.ex` - Rate limiting
- `intent_router.ex` - Intent-based routing
- `local_model.ex` - Local model support

**STAMP Constraints**: SC-OPENROUTER-001 to SC-OPENROUTER-005

#### 1.9.2 Other AI Subdirectories
- `providers/` - Provider adapters
- `consensus/` - Multi-model consensus
- `security/` - AI security controls
- `simplex/` - Simplex architecture
- `graphiti/` - Knowledge graph AI
- `resources/` - Ash resources for AI

### 1.10 Prajna Cockpit (`lib/indrajaal/cockpit/prajna/`)

**Backend Modules**:
- `smart_metrics.ex` - Intelligent metrics with Sentinel sync
- `domain.ex` - Domain-specific logic
- `circuit_breaker.ex` - Command protection
- `salience.ex` - Attention prioritization
- `dark_cockpit.ex` - Exception-based monitoring
- `telemetry_display.ex` - Telemetry visualization
- `bridge/holon_adapter.ex` - Holon state adapter
- `neuro/spine.ex` - Neural spine integration
- `bio/holon.ex` - Biomorphic holon state
- `sentinel_integration.ex` - Sentinel bridge

**STAMP Constraints**: SC-PRAJNA-001 to SC-PRAJNA-005

### 1.11 Prajna LiveViews (`lib/indrajaal_web/live/prajna/`)

**24 Real-time LiveView Dashboards**:
1. `access_control_live.ex` - Access control monitoring
2. `alarms_live.ex` - Alarm management (43KB, most complex)
3. `analytics_live.ex` - Analytics dashboard
4. `cluster_live.ex` - Cluster health
5. `commands_live.ex` - Command execution
6. `compliance_live.ex` - Compliance monitoring
7. `containers_live.ex` - Container management
8. `copilot_live.ex` - AI Copilot assistant
9. `devices_live.ex` - Device monitoring
10. `diagnostics_live.ex` - System diagnostics
11. `guardian_dashboard_live.ex` - Guardian status
12. `knowledge_live.ex` - Knowledge graph
13. `mesh_live.ex` - Mesh topology
14. `observability_live.ex` - Observability dashboard
15. `prometheus_live.ex` - PROMETHEUS verification dashboard
16. `register_live.ex` - Immutable register viewer
17. `sentinel_dashboard_live.ex` - Sentinel health
18. `settings_live.ex` - System settings
19. `shutdown_live.ex` - Graceful shutdown
20. `startup_live.ex` - Startup sequence
21. `test_cockpit_live.ex` - Test orchestration
22. `topology_live.ex` - System topology
23. `video_live.ex` - Video monitoring

### 1.12 Business Domains (30 Total)

| Domain | Path | Ash Resources | Features |
|--------|------|---------------|----------|
| AccessControl | `lib/indrajaal/access_control/` | 16 | Badge readers, policies, logs |
| Alarms | `lib/indrajaal/alarms/` | 23 | Processing, correlation, SLA |
| Video | `lib/indrajaal/video/` | 6 | Cameras, streams, recordings |
| Analytics | `lib/indrajaal/analytics/` | Multiple | BI, reporting, aggregation |
| Accounts | `lib/indrajaal/accounts/` | | User management, profiles |
| Authentication | `lib/indrajaal/authentication/` | | JWT, MFA, tokens |
| Authorization | `lib/indrajaal/authorization/` | | RBAC, permissions |
| Billing | `lib/indrajaal/billing/` | | Subscriptions, invoices |
| Compliance | `lib/indrajaal/compliance/` | | Audit trails, forensics |
| Communication | `lib/indrajaal/communication/` | | Messaging, notifications |
| Devices | `lib/indrajaal/devices/` | | Cameras, panels, sensors |
| Dispatch | `lib/indrajaal/dispatch/` | | Security response |
| GuardTours | `lib/indrajaal/guard_tours/` | | Patrol management |
| Integration | `lib/indrajaal/integration/` | | External connectors |
| Intelligence | `lib/indrajaal/intelligence/` | | Security intelligence |
| Maintenance | `lib/indrajaal/maintenance/` | | Preventive maintenance |
| Policy | `lib/indrajaal/policy/` | | Policy engine |
| Shifts | `lib/indrajaal/shifts/` | | Shift scheduling |
| Sites | `lib/indrajaal/sites/` | | Buildings, floors, zones |
| VisitorManagement | `lib/indrajaal/visitor_management/` | | Visitor tracking |
| FleetManagement | `lib/indrajaal/fleet_management/` | | Vehicle tracking |
| AssetManagement | `lib/indrajaal/asset_management/` | | Asset inventory |
| RiskManagement | `lib/indrajaal/risk_management/` | | Risk assessment |
| Contacts | `lib/indrajaal/contacts/` | | Contact management |
| AgentComments | `lib/indrajaal/agent_comments/` | | Comment system |
| *+5 more domains* | | | |

### 1.13 Phoenix Web Layer (`lib/indrajaal_web/`)

#### 1.13.1 Controllers
- `health_controller.ex` - Health check endpoint
- `auth_controller.ex` - Authentication
- `mobile_api_controller.ex` - Mobile API
- `analytics_api_controller.ex` - Analytics API
- `fallback_controller.ex` - Error fallback
- **Mobile API** (`controllers/api/mobile/`): 40+ mobile API controllers

#### 1.13.2 Other LiveViews
- `system_status_live.ex` - System overview
- `performance_dashboard_live.ex` - Performance metrics
- `monitoring_dashboard_live.ex` - Monitoring
- `stamp_tdg_gde_dashboard_live.ex` - STAMP/TDG/GDE dashboard
- `config_management_live.ex` - Configuration

#### 1.13.3 Channels
- `alarm_channel.ex` - Alarm notifications
- `video_channel.ex` - Video streaming
- `device_channel.ex` - Device updates
- `notification_channel.ex` - Notifications
- `sync_channel.ex` - Data synchronization
- `patrol_channel.ex` - Patrol tracking
- `site_channel.ex` - Site updates
- `config_channel.ex` - Config changes
- `mobile_socket.ex` - Mobile app socket

#### 1.13.4 Plugs
- `authenticate_api.ex` - API authentication
- `rate_limit_plug.ex` - Rate limiting
- `health_plug.ex` - Health check
- `opentelemetry_context.ex` - OTEL context propagation
- `performance_optimizer.ex` - Performance optimization

### 1.14 Specialized Systems

| System | Path | Features |
|--------|------|----------|
| FLAME | `lib/indrajaal/flame/` | Distributed compute pooling |
| Compute | `lib/indrajaal/compute/` | Compute auctions, pricing |
| Validation | `lib/indrajaal/validation/` | FPPS 5-method validation |
| TDG | `lib/indrajaal/tdg/` | Test-Driven Generation |
| Compilation | `lib/indrajaal/compilation/` | Patient Mode, metrics |
| Container | `lib/indrajaal/container/` | Podman integration |
| CEPAF Bridge | `lib/indrajaal/cepaf/` | Elixir ↔ F# bridge |
| Time | `lib/indrajaal/time/` | Hybrid Logical Clock |
| Economy | `lib/indrajaal/economy/` | Resource economy |
| Treasury | `lib/indrajaal/treasury/` | Founder's financial management |
| Training | `lib/indrajaal/training/` | AI model training gym |
| Upgrade | `lib/indrajaal/upgrade/` | Rolling updates, snapshots |
| Deployment | `lib/indrajaal/deployment/` | Deployment automation |
| Cluster | `lib/indrajaal/cluster/` | Multi-node coordination |
| Federation | `lib/indrajaal/federation/` | Cross-cluster coordination |

---

## 2. F# CORTEX & INFRASTRUCTURE (Agent a74b456)

### 2.1 Scale Metrics

| Metric | Count |
|--------|-------|
| **F# Projects** | 18 |
| **F# Modules (.fs)** | 300+ |
| **F# Scripts (.fsx)** | 100+ |
| **Total F# LOC** | ~25,000 |

### 2.2 Core F# Projects

#### 2.2.1 Cepaf Main (`lib/cepaf/src/Cepaf/`)
**Project**: `Cepaf.fsproj` (net10.0)
**Entry Point**: `Program.fs`
**Modules**: 254

**Core Computational Patterns (43 modules)**:
- Units of Measure, Composition, Active Patterns
- Parser Combinators, Category Theory, Tagless Final
- Recursion Schemes, Streaming, Comonads, Arrows
- Concurrency Patterns, Free Effects, Optics

**SIL-6 Mesh Orchestration (11 modules)**:
- FractalLogger, DigitalTwin, ContainerLifecycleManager
- HealthCoordinator, Apoptosis, MeshStartup/Shutdown
- OodaSupervisor, MeshCli, SIL6MeshCLI

**SIL-6 Lifecycle Management (6 modules)**:
- VtoUpgradeOrchestrator, RollingUpdate, StateSnapshot
- RollbackManager, ReedSolomon, FederationProtocol

**Prajna Cockpit (26 modules)**:
- ThemeSystem, Material3, SignalArrows, UiComonads
- AiCopilot, GuardianIntegration, AiCopilotFounder
- SentinelBridge, ImmutableState, ElixirBridge
- TestCockpit, JenkinsIntegration, FractalTestRunner

**Observability (15 modules)**:
- Fractal Logging (5-level Zenoh-style)
- OTEL/SigNoz Integration
- QuadplexLogger, MetricsCollector

**Zenoh Integration (3 modules)**:
- ZenohSession, ZenohChannel, KmsSubscriber

#### 2.2.2 Indrajaal.Cortex (`lib/cortex/src/Indrajaal.Cortex/`)
**Features**:
- MetabolicGovernor: Agent scaling based on API rate limits
- TokenBucket: Rate limiting with backpressure
- TopologyEngine: Mesh topology management
- VectorStore: DuckDB-backed embeddings
- GCPCloudKMS: Secret management integration

#### 2.2.3 Cepaf.KmsCatalog (`lib/cepaf/src/Cepaf.KmsCatalog/`)
**29 Modules for Backstage Integration**:
- CatalogDomain.fs, CheckpointDomain.fs, TechDocs.fs
- Scorecard.fs, Search.fs, ApiAndCost.fs
- HolonMapper.fs, CatalogIngestor.fs, RuntimeBinder.fs
- MeshCatalog.fs, SafeCatalog.fs, CatalogCLI.fs

#### 2.2.4 Cepaf.Podman (`lib/cepaf/src/Cepaf.Podman/`)
- Podman API Client (rootless 5.4.1+)
- Container, Image, Network management

#### 2.2.5 Cepaf.Podman.Grpc (`lib/cepaf/services/Cepaf.Podman.Grpc/`)
- gRPC Server for remote Podman access
- Port 5000 (gRPC)

#### 2.2.6 Other F# Projects
- Cepaf.Cockpit - MVVM for Prajna UI
- Cepaf.Bridge - Elixir ↔ F# Port protocol
- Cepaf.Knowledge - Knowledge graph
- Cepaf.Knowledge.CLI - Knowledge CLI
- Cepaf.KmsCatalog.Daemon - Background catalog sync
- Cepaf.Cockpit.Avalonia - Desktop GUI
- Test projects (773+ tests)

### 2.3 F# Scripts (Root-Level sa-*)

| Script | Purpose | STAMP |
|--------|---------|-------|
| `sa-up.fsx` | 5-stage mesh boot | SC-SIL6-001 |
| `sa-down.fsx` | 6-phase graceful shutdown | SC-SIL6-002 |
| `sa-status.fsx` | Digital Twin report | SC-SIL6-004 |
| `sa-health.fsx` | FPPS 5-method consensus | SC-SIL6-005 |
| `sa-emergency.fsx` | Force stop <5s | SC-EMR-057 |
| `sa-verify.fsx` | 2oo3 voting verification | SC-SIL6-006 |
| `sa-checkpoint.fsx` | UCR 4-phase checkpoint | SC-UCR-001 |
| `sa-test.fsx` | Runtime test orchestration | - |
| `sa-deploy.fsx` | Production deployment | - |
| `sa-sil6-boot.fsx` | SIL-6 biomorphic boot | SC-SIL6-* |
| `sa-multiverse.fsx` | Multiverse checkpoint fork | SC-UCR-011 |

### 2.4 CEPAF Scripts (`lib/cepaf/scripts/`)

| Script | Purpose |
|--------|---------|
| `SIL6Orchestrator.fsx` | SIL-6 mesh orchestration |
| `SIL6HomeostasisOrchestrator.fsx` | SIL-6 homeostatic control |
| `RuntimeTestOrchestrator.fsx` | Runtime test execution |
| `ComprehensiveRuntimeTests.fsx` | Comprehensive test suite |
| `ProductionDeploymentOrchestrator.fsx` | Production deploy |
| `FractalRuntimeValidator.fsx` | Fractal validation |
| `CockpitOperations.fsx` | Cockpit operations |
| `CockpitUXEvaluator.fsx` | UX evaluation |
| `FractalDocumentIngestion.fsx` | Document ingestion |
| `KmsSil4Verification.fsx` | KMS SIL-6 verification |
| `fractal-tui.fsx` | Fractal TUI dashboard |

### 2.5 Container Architecture

**4-Container Production Stack**:

| Container | IP | Ports | Resources |
|-----------|-----|-------|-----------|
| indrajaal-ex-app-1 | 172.28.0.10 | 4000, 4001, 6379 | 10GB/8CPU |
| indrajaal-db-prod | 172.28.0.20 | 5433 | 4GB/4CPU |
| indrajaal-obs-prod | 172.28.0.30 | 4317, 4318, 9090, 3000, 3100, 3301, 8080, 8123 | 10GB/6CPU |
| zenoh-router | 172.28.0.40 | 7447, 8000 | 512MB/1CPU |

**Compose Files** (15 total in `lib/cepaf/artifacts/`):
- `podman-compose-prod-standalone.yml` - Primary production
- `podman-compose-sil6-full-mesh.yml` - SIL-6 mesh
- `podman-compose-fractal-cluster.yml` - Fractal cluster
- `podman-compose-ha-full-mesh.yml` - HA mesh
- Various verification and standalone configs

### 2.6 Integration Points with Elixir

#### 2.6.1 Zenoh Pub/Sub (Primary)
**Protocol**: Zenoh 1.0 TCP (port 7447)

**F# Publishers**:
```fsharp
ZenohFractalPublisher.publish session "indrajaal/logs/cluster/node-1" logEntry
TelemetryPublisher.publish session "prajna/kpi/health" healthMetrics
DigitalTwin.publishState session twin
```

**F# Subscribers**:
```fsharp
KmsSubscriber.subscribe session "kms/holons/+/state" handleHolonUpdate
SentinelBridge.subscribe session "sentinel/alerts/+" handleAlert
```

#### 2.6.2 HTTP Bridge (Synchronous)
**Endpoint**: `http://localhost:4000/api/prajna/*`

```fsharp
ElixirBridge.post "http://localhost:4000/api/prajna/guardian/validate" payload
ElixirBridge.get "http://localhost:4000/api/prajna/sentinel/health"
```

#### 2.6.3 Shared State (SQLite/DuckDB)
**Location**: `data/holons/{holon_id}/`
- F# writes via DigitalTwin
- Elixir reads via KMS

---

## 3. SCRIPTS & SOPs (Agent a09db36)

### 3.1 Scale Metrics

| Category | Count |
|----------|-------|
| **Total Scripts** | 1,634 |
| **Devenv Commands** | 32 |
| **Testing Scripts** | 424 |
| **Demo Scripts** | 240 |
| **Validation Scripts** | 355 |
| **SOPv5.11 Scripts** | 148 |
| **Performance Scripts** | 99 |
| **CEPAF Scripts** | 20 |
| **Infrastructure Scripts** | 18 |
| **Existing SOPs** | 7 |
| **STAMP Constraints** | 600+ |
| **AOR Rules** | 200+ |

### 3.2 Devenv Commands (32)

#### App & Server (3)
| Command | Purpose | Dependencies |
|---------|---------|--------------|
| `app` | Start Phoenix server | compile, sa-db |
| `app-start` | Containers + Phoenix | sa-up |
| `app-iex` | Phoenix with IEx | compile |

#### Compilation & Quality (7)
| Command | Purpose | STAMP |
|---------|---------|-------|
| `compile` | Patient Mode, 16 schedulers | SC-METRICS-003 |
| `compile-strict` | Warnings as errors | SC-CMP-025 |
| `compile-profile` | Profiled timing | - |
| `compile-xref` | Dependency graph | - |
| `quality` | Format + Credo | SC-GEM-003 |
| `quality-full` | + Dialyzer + Sobelow | SC-SEC-044 |

#### Testing (2)
| Command | Purpose | STAMP |
|---------|---------|-------|
| `test` | Tests with Zenoh NIF | SC-TEST-NIF-001 |
| `test-cover` | Coverage report | SC-COV-001 |

#### SIL-6 Mesh (15)
| Command | Purpose | STAMP |
|---------|---------|-------|
| `sa-up` | 5-stage boot | SC-SIL6-001 |
| `sa-down` | Graceful shutdown | SC-SIL6-002 |
| `sa-status` | Container status | SC-SIL6-004 |
| `sa-health` | FPPS consensus | SC-SIL6-005 |
| `sa-verify` | 2oo3 voting | SC-SIL6-006 |
| `sa-emergency` | Force stop <5s | SC-EMR-057 |
| `sa-clean` | Remove containers | SC-SIL6-003 |
| `sa-scour` | Nuclear clean | - |
| `sa-logs` | Stream logs | SC-OBS-069 |
| `sa-db` | DB only | - |
| `sa-obs` | Obs only | - |
| `sa-app` | App only | - |
| `sa-test` | Runtime tests | - |
| `sa-ux` | UX evaluation | - |
| `sa-orchestrate` | Test orchestration | - |

#### UCR Checkpoint (4)
| Command | Purpose | STAMP |
|---------|---------|-------|
| `sa-checkpoint [phase]` | Create checkpoint | SC-UCR-001 |
| `sa-checkpoint-verify` | 46-test verification | SC-UCR-007 |
| `sa-checkpoint-restore` | Restore archive | SC-UCR-015 |
| `sa-checkpoint-list` | List checkpoints | - |

#### Database (4)
| Command | Purpose |
|---------|---------|
| `db-setup` | Create + migrate + seed |
| `db-reset` | Drop + recreate |
| `db-migrate` | Apply migrations |
| `db-console` | psql console |

#### CEPAF (2)
| Command | Purpose |
|---------|---------|
| `cockpitf [cmd]` | F# Cockpit ops |
| `cepaf-build` | Build F# projects |

#### Reporting (4)
- `envelope`, `envelope-json`, `envelope-journal`, `todo`, `help`

### 3.3 Script Categories

#### SOPv5.11 Deployment (148 scripts)
**7 Phases**:
1. `phase_1_environment_setup.exs` - Environment validation
2. `phase_2_container_deployment.exs` - Container setup
3. `phase_3_agent_architecture.exs` - 50 agents deployment
4. `phase_4_phics_integration.exs` - PHICS setup
5. `phase_5_compilation_setup.exs` - Compilation environment
6. `phase_6_monitoring_observability.exs` - Observability
7. `phase_7_security_compliance.exs` - Security gates

#### Testing Scripts (424)
- TDG (Test-Driven Gen): 100+
- Integration: 80+
- Unit: 120+
- Soak: 5 (12-hour tests)
- ACE Verification: 20+

#### Demo Scripts (240)
- Access Control: 30+
- Accounts: 25+
- Alarms: 35+
- Analytics: 20+
- Devices: 18+
- Video: 15+
- *+17 domains*

#### Validation Scripts (355)
- Fractal Analysis: 50+
- STAMP Validation: 80+
- TDG Compliance: 60+
- FPPS Consensus: 30+
- GDE Framework: 40+

#### Performance Scripts (99)
- Artillery load tests: 10+
- Custom benchmarks: 50+
- Profiling: 20+
- Podman performance: 15+

#### AEE (Autonomous Execution Engine) (35)
- `aee_autonomous_engine.exs` - Main engine
- `deploy_aee_agents.exs` - 50 agents
- `supervisor_agent.exs`, `worker_agent.exs`, `helper_agent.exs`

### 3.4 Existing SOPs (7)

| Document | Purpose | Status |
|----------|---------|--------|
| OPERATIONAL_RUNBOOK.md | Daily operations | Active |
| DEVENV_COMMAND_OPERATIONS_GUIDE.md | Command reference | GA Ready |
| ZENOH_FULL_INTEGRATION_RULES.md | Zenoh integration | Active |
| ZENOH_CEPAF_INTEGRATION.md | CEPAF-Zenoh bridge | Active |
| CEPAF_DASHBOARD_RULES.md | Dashboard operations | Active |
| PASS5_CHANGE_MANAGEMENT_RUNBOOKS.md | Change management | Active |
| remote-livebook-connection.md | Livebook setup | Deprecated |

### 3.5 STAMP Constraints Summary (600+)

**Critical Categories**:
- SC-VAL (Validation): 10 rules
- SC-CNT (Container): 15 rules
- SC-TEST (Testing): 10 rules
- SC-HOLON (Biomorphic State): 20 rules
- SC-SIL6 (Panopticon Mesh): 20 rules
- SC-SIL6 (Biomorphic Extended): 15 rules
- SC-METRICS (Compilation): 7 rules
- SC-UCR (Unified Checkpoint): 15 rules

**Most Referenced**:
| ID | Constraint | References |
|----|------------|------------|
| SC-METRICS-003 | 16 schedulers | 47 scripts |
| SC-TEST-NIF-001 | SKIP_ZENOH_NIF=0 | 38 scripts |
| SC-HOLON-001 | SQLite/DuckDB | 32 scripts |
| SC-VAL-001 | Patient Mode | 28 scripts |
| SC-SIL6-005 | FPPS consensus | 24 scripts |

### 3.6 AOR Rules Summary (200+)

**Critical Categories**:
- AOR-HOLON: 20 rules
- AOR-TEST: 10 rules
- AOR-MESH: 10 rules
- AOR-UCR: 10 rules
- AOR-CMD: 8 rules

---

## 4. DATA & KMS (Agent a8f1ccf)

### 4.1 Data Directory Structure

**Total**: 25 subdirectories, ~218MB

| Directory | Size | Purpose |
|-----------|------|---------|
| data/kms/ | 152MB | Knowledge Management System |
| data/checkpoints/ | 46MB | Unified Checkpoint Registry |
| data/holons/ | 13MB | Holon state (AUTHORITATIVE) |
| data/training_gym/ | 5.9MB | Test evolution episodes |
| data/logs/ | 2.4MB | Runtime verification logs |
| data/tmp/ | 368KB | Temporary artifacts |
| data/knowledge/ | 272KB | Fractal Holon Knowledge Base |
| data/agents/ | 264KB | Agent coordination state |
| data/coverage/ | 244KB | Test coverage reports |
| data/security/ | 84KB | Audit, compliance, certificates |

### 4.2 KMS Storage (data/kms/)

**Architecture**: Each BEAM node gets its own subdirectory

**Node-Specific Directories**:
- app-1_indrajaal/
- app-2_indrajaal/
- indrajaal-app-prod/
- indrajaal-ex-app-1/
- indrajaal-ex-app-2/
- nonode_nohost/
- *+2 more nodes*

**Database Files (21+)**:

| File | Size | Type | Purpose | Retention |
|------|------|------|---------|-----------|
| analytics.duckdb | 12KB | DuckDB | Root analytics | Permanent |
| telemetry.duckdb | 268KB | DuckDB | OTEL telemetry | 90 days |
| core.db | 6.6MB | SQLite | Core KMS state | Permanent |
| holons.db | 20MB | SQLite | Holon metadata | Permanent |
| test_manager.db | 48KB | SQLite | Test coordination | 30 days |
| test_tracking.db | 28KB | SQLite | Test metrics | 30 days |
| todos.db | 24KB | SQLite | Task tracking | Permanent |
| fractal_execution.log | 124MB | Text | Execution trace | 7 days |

**Per-Node**: analytics.duckdb + holons.db × 8 nodes = 16 files

### 4.3 Holon State (data/holons/) - AUTHORITATIVE

**Founder Directive Holon**:
- `data/holons/founder_directive/state.sqlite` (512KB)
- `data/holons/founder_directive/state.sqlite-wal` (32KB)
- `data/holons/founder_directive/wealth/` - Buffett Wealth Framework

**Immutable Register**:
- `data/holons/prajna_register.duckdb` (2.3MB)
- Ed25519 keypair: `data/holons/prajna_keypair.bin`

**Schema**:
```sql
CREATE TABLE founder_state (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  payload BLOB NOT NULL,         -- CBOR encoded
  checksum TEXT NOT NULL         -- SHA-256 integrity
);
```

### 4.4 Git-Tracked Knowledge (32MB)

**Core Specifications**:
- CLAUDE.md: 1,295 lines (~50KB)
- GEMINI.md: 9,425 lines (~380KB)
- AGENT_BOOTSTRAP.md: ~200 lines (9KB)

**Documentation Tree** (docs/):
- 1,585 markdown files
- 32MB total

**Key Directories**:
- docs/architecture/ - 200+ files
- docs/compliance/ - ISO/GDPR/SIL-6
- docs/domain-docs/ - 19 business domains
- docs/formal_specs/ - Agda/Quint proofs
- docs/testing/ - Test specifications
- docs/verification/ - GA verification

### 4.5 Configuration State

**Environment Files**:
- `.env` - Active config (untracked)
- `.env.example` - Template (364 lines, 121 variables)
- `.env.sopv51`, `.env.standalone.template`, `.envrc`, `.envrc.patient`

**Config Directory** (config/):
- config.exs (16.5KB)
- dev.exs (4.8KB)
- demo.exs (2.9KB)
- parallelization.exs (9KB)
- otel-config-fractal.yaml (1.1KB)

### 4.6 Unified Checkpoint Registry (data/checkpoints/)

**4-Phase Architecture**:
1. **Phase 1**: File/KMS/Git state capture
2. **Phase 2**: CRIU container memory snapshots
3. **Phase 3**: Chandy-Lamport distributed Zenoh snapshot
4. **Phase 4**: 8-level verification hash tree

**Latest Checkpoint**: `20260109_122132/`
```
├── artifacts/     # Build artifacts
├── kms/           # Database snapshots
├── container-manifest.txt
└── git-diff.patch
```

**Retention**: 7 days

### 4.7 Data Usage Matrix

#### By Lifecycle Phase

**Development**:
| Data | Access | Purpose |
|------|--------|---------|
| CLAUDE.md | Read (every session) | Agent guidance |
| data/coverage/ | Write (each test) | Coverage |
| data/compilation/ | Write (each compile) | Metrics |

**Operations**:
| Data | Access | Purpose |
|------|--------|---------|
| data/kms/*.db | Heavy R/W | Runtime state |
| data/holons/*.sqlite | Heavy R/W | Holon operations |
| PostgreSQL | Heavy R/W | Business transactions |

**SRE**:
| Data | Access | Purpose |
|------|--------|---------|
| data/checkpoints/ | Read (recovery) | Disaster recovery |
| data/kms/analytics.duckdb | Read | Trend analysis |
| ImmutableRegister | Read | Compliance audit |

### 4.8 Data Sovereignty Rules

**MUST Store in KMS**:
- Holon genotype/phenotype (SC-HOLON-013)
- Version vectors (SC-HOLON-010)
- Evolution lineage (SC-HOLON-014)
- Block hashes (SC-REG-002)
- Ed25519 signatures (SC-REG-003)
- Capability tokens (SC-REG-015)

**MUST Store in Git**:
- CLAUDE.md, GEMINI.md (AOR-CONST-001)
- STAMP constraints, AOR rules (SC-PRIME-002)
- Formal specs (SC-SIL6-013)
- Architecture docs, Source code

**PostgreSQL = Business Data ONLY**:
- SC-HOLON-002: PostgreSQL MUST NOT contain holon state
- SC-HOLON-005: No holon state in PostgreSQL

### 4.9 Retention Policies

| Type | Retention | Backup | Compliance |
|------|-----------|--------|------------|
| Holon SQLite | Permanent | Daily | SC-HOLON-011 |
| Immutable Register | Permanent | Daily | SC-REG-002 |
| KMS core.db | Permanent | Daily | Business |
| Analytics DuckDB | 90 days | Weekly | Storage |
| Telemetry DuckDB | 30 days | None | Observability |
| Compilation logs | 7 days | None | Debug |
| Checkpoints | 7 days | None | Recovery |
| Audit logs | 7 years | Weekly | Compliance |
| Documentation | Permanent | Git | Knowledge |

---

## 5. SYNTHESIS & RECOMMENDATIONS

### 5.1 New SOPs Required

| SOP | Purpose | Priority |
|-----|---------|----------|
| SOP-SWARM-001 | 50-Agent Swarm Operations | P0 |
| SOP-SIL6-001 | SIL-6 Biomorphic Safety | P0 |
| SOP-GUARDIAN-001 | Guardian Approval Workflow | P0 |
| SOP-UCR-001 | Unified Checkpoint Registry | P1 |
| SOP-IMMUNE-001 | Digital Immune Operations | P1 |
| SOP-EVOLUTION-001 | Goal-Directed Evolution | P1 |
| SOP-FEDERATION-001 | Cross-Holon Federation | P2 |

### 5.2 New Protocols Required

1. **Guardian Approval Protocol**
   - Proposal → Constitutional Check → Safety Envelope → Decision → Audit

2. **Swarm Coordination Protocol**
   - Grey Wolf hierarchy (Alpha/Beta/Delta/Omega)
   - Algorithm selection (GWO, PSO, ACO, Bee, Firefly)

3. **FPPS Health Consensus Protocol**
   - 5-method validation (Pattern, AST, Statistical, Binary, LineByLine)
   - 2oo3 voting (Live Node ↔ Shadow Node ↔ Formal Model)

### 5.3 Existing SOP Updates Required

| SOP | Changes |
|-----|---------|
| OPERATIONAL_RUNBOOK.md | +SIL-6 procedures, +swarm monitoring, +2oo3 voting |
| DEVENV_COMMAND_OPERATIONS_GUIDE.md | +50-agent architecture, +UCR commands |
| ZENOH_FULL_INTEGRATION_RULES.md | +mesh boot stages, +health consensus |
| ZENOH_CEPAF_INTEGRATION.md | +F# Cortex sync protocols |
| CEPAF_DASHBOARD_RULES.md | +DigitalTwin state display |
| PASS5_CHANGE_MANAGEMENT_RUNBOOKS.md | +Guardian approval workflow |

### 5.4 Data Management Summary

**Critical Data Locations**:
```
data/holons/              → AUTHORITATIVE (SQLite/DuckDB)
data/kms/                 → Node KMS state
data/checkpoints/         → UCR recovery
PostgreSQL 5433           → Business data ONLY
```

**Backup Priorities**:
1. Tier 1 (Daily): data/holons/, data/kms/core.db, CLAUDE.md
2. Tier 2 (Weekly): data/kms/analytics.duckdb, docs/architecture/
3. Tier 3 (None): data/tmp/, data/coverage/, _build/

---

## 6. ARTIFACTS CREATED

### 6.1 Primary Document

| File | Path | Lines | Size |
|------|------|-------|------|
| SYSTEM_CATALOG_MASTER.md | docs/architecture/ | ~1,200 | ~60KB |

### 6.2 Document Structure

1. Executive Summary
2. System Inventory (2.1-2.9)
3. System Features by Category (3.1-3.5)
4. Lifecycle Phase Matrix (4.1-4.4)
5. Setup and Usage Guide (5.1-5.5)
6. System Interactions (6.1-6.3)
7. SOP Impact Analysis (7.1-7.2)
8. New SOPs and Protocols (8.1-8.3)
9. Data and Knowledge Management (9.1-9.5)
10. Process Integration Matrix (10.1-10.4)
11. Appendices A-C

---

## 7. LESSONS LEARNED

### 7.1 Codebase Complexity

The Indrajaal system is highly complex:
- 7 fractal layers
- Dual-language (Elixir + F#)
- 30 business domains
- 50 agents
- 600+ safety constraints
- Blockchain-type immutable state

### 7.2 Documentation Gaps Identified

1. No inline README.md in data/ subdirectories
2. Immutable Register: Spec complete, implementation pending
3. Reed-Solomon ECC: Spec complete, code missing
4. L7 Federation: Not operational

### 7.3 Key Constraints

**Most Critical**:
- SC-HOLON-001: SQLite/DuckDB for holon state
- SC-METRICS-003: 16 schedulers mandatory
- SC-TEST-NIF-001: SKIP_ZENOH_NIF=0
- SC-FOUNDER-001: All actions serve Founder

---

## 8. NEXT STEPS

1. **Create new SOPs** (7 documents, P0-P2)
2. **Update existing SOPs** (6 documents)
3. **Implement missing components**:
   - Immutable Register code
   - Reed-Solomon ECC
   - L7 Federation
4. **Add data/ README files**
5. **Validate against 600+ STAMP constraints**

---

## APPENDIX: AGENT OUTPUTS

The full outputs from all 4 agents are preserved in:
- Agent ad19046: Elixir systems (~50KB output)
- Agent a74b456: F# & infrastructure (~45KB output)
- Agent a09db36: Scripts & SOPs (~55KB output)
- Agent a8f1ccf: Data & KMS (~40KB output)

Total exploration output: ~190KB of detailed findings

---

**End of Journal Entry**

*Session completed: 2026-01-10*
*Artifacts: SYSTEM_CATALOG_MASTER.md, this journal*
*Total documentation: ~70KB new content*
