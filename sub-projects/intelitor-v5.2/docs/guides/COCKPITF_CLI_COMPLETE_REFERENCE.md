# CockpitF CLI Complete Command Reference
**Version**: 21.3.0-SIL6
**Date**: 2026-01-11
**Compliance**: SC-CTRL-*, SC-MON-*, SC-SIL6-*, SIL-6 Biomorphic Fractal Mesh
**Status**: FULL CONTROL & MONITORING SPECIFICATION

---

## 0.0 CLI Philosophy

CockpitF provides **FULL control and monitoring** of the entire Indrajaal system through an intuitive F# CLI. Every capability accessible through Prajna dashboards MUST also be accessible via CockpitF commands.

### Design Principles
1. **Completeness**: Every system capability has a CLI command
2. **Consistency**: Commands follow `category-action` naming
3. **Composability**: Commands can be piped and chained
4. **Telemetry**: All commands emit 5-order effects telemetry
5. **Safety**: Destructive commands require Guardian approval

---

## 1.0 Current Commands (Implemented)

### 1.1 Mesh Lifecycle (sa-* prefix)

| Command | F# Module | Description | STAMP |
|---------|-----------|-------------|-------|
| `sa-up` | SIL6MeshCLI | Start mesh with 5-stage boot | SC-SIL6-001 |
| `sa-down` | SIL6MeshCLI | Graceful shutdown with checkpoint | SC-SIL6-002 |
| `sa-status` | SIL6MeshCLI | Show container health & quorum | SC-SIL6-004 |
| `sa-health` | HealthCoordinator | FPPS 5-method validation | SC-SIL6-005 |
| `sa-clean` | SIL6MeshCLI | Remove containers, preserve data/kms | SC-SIL6-003 |
| `sa-scour` | SIL6MeshCLI | Nuclear clean (all volumes) | SC-SIL6-007 |
| `sa-emergency` | Apoptosis | Emergency stop < 5s | SC-EMR-057 |
| `sa-verify` | HealthCoordinator | 2oo3 voting verification | SC-SIL6-006 |
| `sa-logs [svc]` | MeshCli | Stream container logs | - |
| `sa-test` | MeshCli | Run F# runtime tests | - |
| `sa-dashboard` | MeshDashboard | Interactive TUI dashboard | - |
| `sa-supervisor` | OodaSupervisor | OODA biomorphic supervisor with real ScaleUp/ScaleDown [Updated Sprint 51] | SC-BIO-001 |

---

## 2.0 Required Commands (To Be Implemented)

### 2.1 Domain Control Commands

| Command | Purpose | Target Module | Priority |
|---------|---------|---------------|----------|
| `domain-list` | List all 65 domains | Domain.fs | P0 |
| `domain-status <name>` | Domain health status | Domain.fs | P0 |
| `domain-metrics <name>` | Domain-specific metrics | MetricsCollector.fs | P1 |
| `domain-circuit <name>` | Circuit breaker status | Domain.fs | P1 |
| `domain-enable <name>` | Enable disabled domain | Domain.fs | P2 |
| `domain-disable <name>` | Disable domain (Guardian required) | Domain.fs | P2 |

### 2.2 Safety & Guardian Commands

| Command | Purpose | Target Module | Priority |
|---------|---------|---------------|----------|
| `guardian-status` | Guardian operational status | SentinelBridge.fs | P0 |
| `guardian-propose <action>` | Submit proposal for approval | SentinelBridge.fs | P0 |
| `guardian-pending` | List pending approvals | SentinelBridge.fs | P1 |
| `guardian-approve <id>` | Approve proposal (human) | SentinelBridge.fs | P1 |
| `guardian-reject <id>` | Reject proposal (human) | SentinelBridge.fs | P1 |
| `sentinel-health` | Sentinel threat assessment | SentinelBridge.fs | P0 |
| `sentinel-threats` | List active threats | SentinelBridge.fs | P0 |
| `sentinel-patterns` | PatternHunter detections | SentinelBridge.fs | P1 |

### 2.3 Constitutional & Core Commands

| Command | Purpose | Target Module | Priority |
|---------|---------|---------------|----------|
| `constitution-verify` | Verify Ψ₀-Ψ₅ invariants | ElixirBridge.fs | P0 |
| `constitution-status` | Show constitutional state | ElixirBridge.fs | P0 |
| `holon-state` | Current holon state | Holon.fs | P0 |
| `holon-tree` | Holon hierarchy tree | HolonTree.fs | P1 |
| `holon-history` | Evolution history (DuckDB) | Holon.fs | P1 |
| `vsm-layers` | VSM S1-S5 layer health | ElixirBridge.fs | P1 |
| `register-browse` | Browse Immutable Register | ElixirBridge.fs | P1 |
| `register-verify` | Verify register chain integrity | ElixirBridge.fs | P0 |

### 2.4 Observability Commands

| Command | Purpose | Target Module | Priority |
|---------|---------|---------------|----------|
| `metrics-all` | All system metrics | MetricsCollector.fs | P0 |
| `metrics-domain <name>` | Domain-specific metrics | MetricsCollector.fs | P1 |
| `metrics-containers` | Container resource metrics | MetricsCollector.fs | P1 |
| `traces-list` | Recent distributed traces | TelemetryChannel.fs | P1 |
| `traces-show <id>` | Show trace detail | TelemetryChannel.fs | P2 |
| `logs-query <pattern>` | Query structured logs | QuadplexLogger.fs | P1 |
| `zenoh-topics` | List active Zenoh topics | ZenohSession.fs | P1 |
| `zenoh-publish <topic>` | Publish to Zenoh topic | ZenohSession.fs | P2 |
| `zenoh-subscribe <topic>` | Subscribe to Zenoh topic | ZenohSession.fs | P2 |

### 2.5 AI & Copilot Commands

| Command | Purpose | Target Module | Priority |
|---------|---------|---------------|----------|
| `copilot-query <prompt>` | Ask AI Copilot | AiCopilot.fs | P0 |
| `copilot-analyze <domain>` | Domain analysis | AiCopilot.fs | P1 |
| `copilot-recommend` | Get recommendations | AiCopilot.fs | P1 |
| `knowledge-search <query>` | RAG knowledge search | ElixirBridge.fs | P1 |
| `knowledge-ingest <file>` | Ingest document | ElixirBridge.fs | P2 |

### 2.6 Cluster & Federation Commands

| Command | Purpose | Target Module | Priority |
|---------|---------|---------------|----------|
| `cluster-nodes` | List cluster nodes | ElixirBridge.fs | P0 |
| `cluster-health` | Cluster health status | ElixirBridge.fs | P0 |
| `cluster-quorum` | Quorum voting status | HealthCoordinator.fs | P0 |
| `federation-peers` | List federation peers | ElixirBridge.fs | P1 |
| `federation-sync` | Sync status with peers | ElixirBridge.fs | P1 |
| `federation-announce` | Announce to federation | ElixirBridge.fs | P2 |

### 2.7 Alarm & Dispatch Commands

| Command | Purpose | Target Module | Priority |
|---------|---------|---------------|----------|
| `alarms-list` | List active alarms | ElixirBridge.fs | P0 |
| `alarms-stats` | Alarm statistics | ElixirBridge.fs | P1 |
| `alarms-acknowledge <id>` | Acknowledge alarm | ElixirBridge.fs | P1 |
| `dispatch-status` | Dispatch unit status | ElixirBridge.fs | P2 |

### 2.8 Device & Site Commands

| Command | Purpose | Target Module | Priority |
|---------|---------|---------------|----------|
| `devices-list` | List all devices | ElixirBridge.fs | P0 |
| `devices-health` | Device health matrix | ElixirBridge.fs | P0 |
| `devices-offline` | List offline devices | ElixirBridge.fs | P1 |
| `sites-list` | List all sites | ElixirBridge.fs | P1 |
| `sites-health <id>` | Site health status | ElixirBridge.fs | P1 |

### 2.9 Compliance & Audit Commands

| Command | Purpose | Target Module | Priority |
|---------|---------|---------------|----------|
| `compliance-status` | Compliance dashboard | ElixirBridge.fs | P1 |
| `compliance-gaps` | Compliance gaps | ElixirBridge.fs | P1 |
| `audit-trail <entity>` | Audit trail for entity | ElixirBridge.fs | P2 |
| `audit-export <format>` | Export audit log | ElixirBridge.fs | P2 |

### 2.10 Chaos & Testing Commands

| Command | Purpose | Target Module | Priority |
|---------|---------|---------------|----------|
| `mara-inject <fault>` | Inject chaos fault | ElixirBridge.fs | P2 |
| `mara-status` | Chaos testing status | ElixirBridge.fs | P2 |
| `antibody-deploy <threat>` | Deploy antibody | ElixirBridge.fs | P2 |
| `test-property <module>` | Run property tests | Tester.fs | P1 |
| `test-coverage` | Coverage report | Tester.fs | P1 |

---

## 3.0 Command Implementation Architecture

### 3.1 Category Module Mapping

```
Commands                    F# Module                    Elixir Module
─────────────────────────────────────────────────────────────────────
sa-*                        SIL6MeshCLI.fs              (direct Podman)
domain-*                    Domain.fs                   Indrajaal.*
guardian-*, sentinel-*      SentinelBridge.fs           Indrajaal.Safety.*
constitution-*, holon-*     ElixirBridge.fs             Indrajaal.Core.*
metrics-*, traces-*, logs-* TelemetryChannel.fs         Indrajaal.Observability.*
copilot-*, knowledge-*      AiCopilot.fs                Indrajaal.AI.*
cluster-*, federation-*     ElixirBridge.fs             Indrajaal.Cluster.*
alarms-*, dispatch-*        ElixirBridge.fs             Indrajaal.Alarms.*
devices-*, sites-*          ElixirBridge.fs             Indrajaal.Devices.*
compliance-*, audit-*       ElixirBridge.fs             Indrajaal.Compliance.*
mara-*, antibody-*, test-*  ElixirBridge.fs             Indrajaal.Safety.*
```

### 3.2 ElixirBridge Protocol

```fsharp
// All commands calling Elixir use HTTP API bridge
module ElixirBridge =
    let private baseUrl = "http://localhost:4000/api/prajna"

    let callEndpoint (endpoint: string) (payload: obj option) =
        async {
            let! response = Http.AsyncRequest(baseUrl + endpoint, ?body = payload)
            return response.Body
        }

    // Example: Guardian status
    let guardianStatus () =
        callEndpoint "/guardian/status" None
```

### 3.3 5-Order Effects Telemetry

Every command MUST emit 5-order effects:

```fsharp
type CommandEffect = {
    Command: string
    Order1: string  // Immediate
    Order2: string  // Seconds
    Order3: string  // Seconds-Minutes
    Order4: string  // Minutes
    Order5: string  // Minutes-Hours
    Timestamp: DateTime
}

// Example for domain-status
let domainStatusEffects domain = {
    Command = $"domain-status {domain}"
    Order1 = $"Query {domain} state"
    Order2 = "Aggregate module health"
    Order3 = "Update dashboard data"
    Order4 = "Sync with federation"
    Order5 = "Historical trend analysis"
    Timestamp = DateTime.UtcNow
}
```

---

## 4.0 Implementation Plan

### Phase 1: Core Control (Week 1)

```
4.1.0.0: Core Control Commands
├── 4.1.1.0: Domain Commands
│   ├── 4.1.1.1: domain-list
│   ├── 4.1.1.2: domain-status
│   └── 4.1.1.3: domain-metrics
├── 4.1.2.0: Guardian Commands
│   ├── 4.1.2.1: guardian-status
│   ├── 4.1.2.2: guardian-propose
│   └── 4.1.2.3: guardian-pending
└── 4.1.3.0: Constitution Commands
    ├── 4.1.3.1: constitution-verify
    ├── 4.1.3.2: constitution-status
    └── 4.1.3.3: holon-state
```

### Phase 2: Monitoring (Week 2)

```
4.2.0.0: Monitoring Commands
├── 4.2.1.0: Metrics Commands
│   ├── 4.2.1.1: metrics-all
│   ├── 4.2.1.2: metrics-domain
│   └── 4.2.1.3: metrics-containers
├── 4.2.2.0: Sentinel Commands
│   ├── 4.2.2.1: sentinel-health
│   ├── 4.2.2.2: sentinel-threats
│   └── 4.2.2.3: sentinel-patterns
└── 4.2.3.0: Observability Commands
    ├── 4.2.3.1: traces-list
    ├── 4.2.3.2: logs-query
    └── 4.2.3.3: zenoh-topics
```

### Phase 3: AI & Knowledge (Week 3)

```
4.3.0.0: AI & Knowledge Commands
├── 4.3.1.0: Copilot Commands
│   ├── 4.3.1.1: copilot-query
│   ├── 4.3.1.2: copilot-analyze
│   └── 4.3.1.3: copilot-recommend
└── 4.3.2.0: Knowledge Commands
    ├── 4.3.2.1: knowledge-search
    └── 4.3.2.2: knowledge-ingest
```

### Phase 4: Domain-Specific (Week 4)

```
4.4.0.0: Domain Commands
├── 4.4.1.0: Alarm Commands
│   ├── 4.4.1.1: alarms-list
│   ├── 4.4.1.2: alarms-stats
│   └── 4.4.1.3: alarms-acknowledge
├── 4.4.2.0: Device Commands
│   ├── 4.4.2.1: devices-list
│   ├── 4.4.2.2: devices-health
│   └── 4.4.2.3: devices-offline
└── 4.4.3.0: Compliance Commands
    ├── 4.4.3.1: compliance-status
    └── 4.4.3.2: compliance-gaps
```

---

## 5.0 STAMP Constraints (CLI)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-CLI-001 | All Prajna capabilities have CLI equivalent | CRITICAL |
| SC-CLI-002 | Commands emit 5-order telemetry | HIGH |
| SC-CLI-003 | Destructive commands require Guardian | CRITICAL |
| SC-CLI-004 | ElixirBridge timeout < 5s | HIGH |
| SC-CLI-005 | CLI accessible without web browser | CRITICAL |
| SC-CLI-006 | Commands use consistent naming | MEDIUM |
| SC-CLI-007 | Help available for all commands | MEDIUM |
| SC-CLI-008 | Error messages include recovery steps | HIGH |

---

## 6.0 AOR Rules (CLI)

| ID | Rule |
|----|------|
| AOR-CLI-001 | New Prajna capability MUST have CLI command |
| AOR-CLI-002 | Test CLI commands in CI pipeline |
| AOR-CLI-003 | Document all commands in this reference |
| AOR-CLI-004 | Log all command invocations |
| AOR-CLI-005 | Use Guardian for state-mutating commands |

---

## 7.0 Usage Examples

### Quick System Check
```bash
cockpitf domain-list          # List all domains
cockpitf sentinel-health      # Check threat status
cockpitf guardian-status      # Check approval system
cockpitf constitution-verify  # Verify invariants
```

### AI-Assisted Operations
```bash
cockpitf copilot-query "What alarms need attention?"
cockpitf copilot-analyze alarms
cockpitf copilot-recommend
```

### Monitoring Flow
```bash
cockpitf metrics-all                    # Full metrics
cockpitf domain-status observability    # Domain health
cockpitf logs-query "ERROR"             # Find errors
cockpitf traces-list                    # Recent traces
```

### Guardian Workflow
```bash
cockpitf guardian-propose "disable-device camera-1"
cockpitf guardian-pending   # View pending
cockpitf guardian-approve <id>
```

---

## 8.0 Related Documents

- USER_OPERATIONS_GUIDE.md - Daily operations and command reference
- AGENT_BOOTSTRAP.md - Agent onboarding
- SIL6_MESH_CLI_USER_GUIDE.md - Current sa-* commands
- OPERATIONAL_RUNBOOK.md - Operating procedures
- FRACTAL_CAPABILITY_SYNC_IMPLEMENTATION_PLAN.md - Full sync plan
