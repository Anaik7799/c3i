# PRAJNA Digital Twin Mapping
**Version**: 1.0.0 | **Date**: 2025-12-27 | **Status**: ACTIVE
**Principle**: TUI = Graphical + State Representation of Complete Indrajaal System

## Executive Summary

The PRAJNA TUI system is a **complete digital twin** of the Indrajaal security monitoring platform. Every system element, state, process, and relationship is represented through visual components that maintain real-time synchronization with the actual system.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     DIGITAL TWIN ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   PHYSICAL SYSTEM                        DIGITAL TWIN (TUI)                 │
│   ══════════════                         ═════════════════                  │
│                                                                             │
│   ┌─────────────┐     Bidirectional     ┌─────────────────┐                │
│   │  Indrajaal  │ ◄═══════════════════► │  PRAJNA Cockpit │                │
│   │   System    │    State Sync via     │   TUI System    │                │
│   │             │       Zenoh           │                 │                │
│   └─────────────┘                       └─────────────────┘                │
│         │                                       │                          │
│         │ Contains                              │ Represents               │
│         ▼                                       ▼                          │
│   ┌─────────────┐                       ┌─────────────────┐                │
│   │ 50 Agents   │ ◄════════════════════►│ Agent Dashboard │                │
│   │ 30 Domains  │                       │ Domain Screens  │                │
│   │ 3 Containers│                       │ Container Cards │                │
│   │ 242 SC      │                       │ Safety Monitor  │                │
│   └─────────────┘                       └─────────────────┘                │
│                                                                             │
│   State Changes    ───────────────────►  Visual Updates                    │
│   Commands         ◄───────────────────  User Actions                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Part I: System Dimension Mapping

### 1.1 Complete System Inventory

| Dimension | Count | TUI Representation |
|-----------|-------|-------------------|
| **Agents** | 50 | Agent Grid, Status Cards, Workflow Monitor |
| **Domains** | 30+ | Domain Panels, CRUD Screens, Analytics |
| **Containers** | 3 | Container Dashboard, Health Cards |
| **Safety Constraints** | 242 | Safety Monitor, Violation Alerts |
| **API Endpoints** | 2,280+ | API Dashboard, Request Monitor |
| **Ash Resources** | 19 | Resource Browser, Schema Viewer |
| **Test Suites** | 286 | Test Dashboard, Coverage Map |
| **Observability** | 4 modules | Telemetry Dashboard, Trace Viewer |
| **FLAME Pools** | 3 | Pool Monitor, Scaling Controls |
| **Cluster Nodes** | Variable | Mesh Topology, Node Cards |
| **Zenoh Channels** | 50+ | Data Flow Diagram, Channel Monitor |

---

## Part II: Agent Architecture Digital Twin

### 2.1 Agent Hierarchy Mapping

```
PHYSICAL AGENTS ($\mathcal{A}_{50}$)              TUI REPRESENTATION
══════════════════════════════                   ═══════════════════

┌────────────────────────┐                      ┌────────────────────────┐
│   EXECUTIVE AGENT      │ ──────────────────► │   Executive Dashboard   │
│   (1 agent)            │                      │   - System Overview     │
│                        │                      │   - Authority Controls  │
│   • Supreme authority  │                      │   - Decision Log        │
│   • Strategy decisions │                      │   - Performance KPIs    │
│   • Resource allocation│                      │                        │
└────────────────────────┘                      └────────────────────────┘
         │
         ▼
┌────────────────────────┐                      ┌────────────────────────┐
│   DOMAIN AGENTS        │ ──────────────────► │   Domain Agent Grid     │
│   (10 agents)          │                      │   - Per-domain cards    │
│                        │                      │   - Workload meters     │
│   • Access Control     │                      │   - Queue depths        │
│   • Alarms             │                      │   - Health status       │
│   • Analytics          │                      │   - Active tasks        │
│   • Authentication     │                      │                        │
│   • Compliance         │                      │                        │
│   • Devices            │                      │                        │
│   • Integration        │                      │                        │
│   • Observability      │                      │                        │
│   • Sites              │                      │                        │
│   • Video              │                      │                        │
└────────────────────────┘                      └────────────────────────┘
         │
         ▼
┌────────────────────────┐                      ┌────────────────────────┐
│   FUNCTIONAL AGENTS    │ ──────────────────► │   Functional Monitor    │
│   (15 agents)          │                      │   - Capability status   │
│                        │                      │   - Processing rates    │
│   • Coordinator        │                      │   - Error counts        │
│   • Scheduler          │                      │   - Latency metrics     │
│   • Validator          │                      │   - Dependencies        │
│   • Transformer        │                      │                        │
│   • Aggregator         │                      │                        │
│   • Router             │                      │                        │
│   • Cache              │                      │                        │
│   • Queue              │                      │                        │
│   • Logger             │                      │                        │
│   • Monitor            │                      │                        │
│   • Alerter            │                      │                        │
│   • Notifier           │                      │                        │
│   • Reporter           │                      │                        │
│   • Backup             │                      │                        │
│   • Recovery           │                      │                        │
└────────────────────────┘                      └────────────────────────┘
         │
         ▼
┌────────────────────────┐                      ┌────────────────────────┐
│   WORKER AGENTS        │ ──────────────────► │   Worker Pool Monitor   │
│   (24 agents)          │                      │   - Pool utilization    │
│                        │                      │   - Task distribution   │
│   • W01-W24            │                      │   - Queue backlog       │
│   • Task execution     │                      │   - Processing times    │
│   • Parallel processing│                      │   - Scaling status      │
└────────────────────────┘                      └────────────────────────┘
```

### 2.2 Agent TUI Components

```fsharp
/// Agent state representation
type AgentState = {
    id: AgentId
    agentType: AgentType
    status: AgentStatus
    workload: float  // 0.0 - 1.0
    queueDepth: int
    processedCount: int64
    errorCount: int
    lastActivity: DateTime
    currentTask: string option
    efficiency: float  // SC-AGT-017: >90%
}

/// Agent card component (L2 view)
let AgentCard (agent: AgentState) =
    Card { elevation = 2 } [
        // Header
        HBox [
            StatusDot agent.status
            Spacer 4
            Text agent.id { bold = true }
            Flex 1
            Badge (agentTypeLabel agent.agentType) { variant = Outlined }
        ]

        // Metrics
        Grid 2 2 [
            MetricMini "Workload" agent.workload TrendFromHistory
            MetricMini "Queue" (float agent.queueDepth) NoTrend
            MetricMini "Processed" (float agent.processedCount) NoTrend
            MetricMini "Efficiency" agent.efficiency
                (if agent.efficiency >= 0.9 then Stable else Falling)
        ]

        // Current task
        match agent.currentTask with
        | Some task -> Text task { fg = Gray; truncate = 30 }
        | None -> Text "Idle" { fg = DarkGray }

        // Actions
        HBox [
            IconButton Pause (PauseAgent agent.id)
            IconButton Restart (RestartAgent agent.id)
            IconButton Logs (ViewAgentLogs agent.id)
        ]
    ]
    |> when' (agent.status = Degraded) (Border { color = Amber })
    |> when' (agent.status = Failed) (Pulse 500<ms>)

/// Agent grid component (L1 view)
let AgentGrid (agents: AgentState list) =
    let byType = agents |> List.groupBy (fun a -> a.agentType)

    VBox [
        for (agentType, typeAgents) in byType do
            Panel (agentTypeLabel agentType) [
                Grid 4 (List.length typeAgents / 4 + 1) [
                    for agent in typeAgents do
                        AgentMiniCard agent
                ]
            ]
    ]

/// Agent detail component (L3 view)
let AgentDetail (agent: AgentState) (history: AgentHistory) =
    VBox [
        // Header
        HBox [
            StatusDot agent.status
            Heading H2 agent.id
            Badge (agent.agentType.ToString()) {}
        ]

        Divider Horizontal

        // Metrics with history
        Grid 2 2 [
            MetricCard "Workload" agent.workload history.workload
            MetricCard "Efficiency" agent.efficiency history.efficiency
            MetricCard "Queue Depth" (float agent.queueDepth) history.queue
            MetricCard "Error Rate" (float agent.errorCount / float agent.processedCount) history.errors
        ]

        // Timeline
        Panel "Activity Timeline" [
            Timeline history.events
        ]

        // Configuration
        Panel "Configuration" [
            ConfigEditor agent.config
        ]

        // Actions
        HBox [
            Button "Pause" (PauseAgent agent.id)
            Button "Restart" (RestartAgent agent.id)
            Button "Scale" (ScaleAgent agent.id)
            Button "View Logs" (ViewAgentLogs agent.id)
        ]
    ]
```

---

## Part III: Domain Architecture Digital Twin

### 3.1 Domain Mapping (30+ Domains)

```
BUSINESS DOMAINS                              TUI SCREENS
════════════════                              ═══════════

┌─ OPERATIONS ──────────────────────────────────────────────────────────────┐
│                                                                            │
│  Access Control ────────────────────►  AccessControlScreen                 │
│    • Credentials                        - Credential Manager               │
│    • Access Rules                       - Rule Editor                      │
│    • Access Logs                        - Audit Log Viewer                 │
│    • Door Controllers                   - Device Status Grid               │
│                                                                            │
│  Alarms ────────────────────────────►  AlarmCenterScreen                   │
│    • Active Alarms                      - Live Alarm Feed                  │
│    • Alarm History                      - Historical Search                │
│    • Alarm Rules                        - Rule Configuration               │
│    • Alarm Analytics                    - Pattern Analysis                 │
│                                                                            │
│  Video ─────────────────────────────►  VideoSurveillanceScreen             │
│    • Cameras                            - Camera Grid                      │
│    • Streams                            - Live Video Wall                  │
│    • Recordings                         - Recording Browser                │
│    • Analytics                          - Video Analytics                  │
│                                                                            │
│  Dispatch ──────────────────────────►  DispatchConsoleScreen               │
│    • Assignments                        - Assignment Board                 │
│    • Officers                           - Officer Status                   │
│    • Teams                              - Team Manager                     │
│    • Vehicles                           - Fleet Tracker                    │
│                                                                            │
│  Guard Tours ───────────────────────►  GuardToursScreen                    │
│    • Routes                             - Route Designer                   │
│    • Checkpoints                        - Checkpoint Map                   │
│    • Tours                              - Active Tours                     │
│    • Verification                       - Verification Log                 │
│                                                                            │
│  Visitors ──────────────────────────►  VisitorManagementScreen             │
│    • Visitor Registration               - Check-in Kiosk                   │
│    • Visitor Passes                     - Pass Manager                     │
│    • Contractor Management              - Contractor Portal                │
│    • Screening                          - Screening Workflow               │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘

┌─ ASSETS ──────────────────────────────────────────────────────────────────┐
│                                                                            │
│  Sites ─────────────────────────────►  SiteManagementScreen                │
│    • Buildings                          - Building Hierarchy               │
│    • Floors                             - Floor Plans                      │
│    • Zones                              - Zone Editor                      │
│    • Maps                               - Interactive Maps                 │
│                                                                            │
│  Devices ───────────────────────────►  DeviceManagementScreen              │
│    • Cameras                            - Camera Configuration             │
│    • Sensors                            - Sensor Status Grid               │
│    • Readers                            - Reader Management                │
│    • Panels                             - Panel Dashboard                  │
│                                                                            │
│  Fleet ─────────────────────────────►  FleetManagementScreen               │
│    • Vehicles                           - Vehicle Inventory                │
│    • Tracking                           - GPS Tracker                      │
│    • Maintenance                        - Maintenance Schedule             │
│                                                                            │
│  Equipment ─────────────────────────►  EquipmentScreen                     │
│    • Inventory                          - Equipment List                   │
│    • Work Orders                        - Work Order Board                 │
│    • Maintenance                        - PM Calendar                      │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘

┌─ INTELLIGENCE ────────────────────────────────────────────────────────────┐
│                                                                            │
│  Analytics ─────────────────────────►  AnalyticsDashboardScreen            │
│    • KPIs                               - KPI Dashboard                    │
│    • Reports                            - Report Builder                   │
│    • Trends                             - Trend Analysis                   │
│    • Predictions                        - Predictive Models                │
│                                                                            │
│  Compliance ────────────────────────►  ComplianceScreen                    │
│    • Frameworks                         - Framework Browser                │
│    • Assessments                        - Assessment Tracker               │
│    • Audits                             - Audit Log                        │
│    • Certifications                     - Certification Status             │
│                                                                            │
│  Risk ──────────────────────────────►  RiskManagementScreen                │
│    • Assessments                        - Risk Matrix                      │
│    • Mitigations                        - Mitigation Plans                 │
│    • Scoring                            - Risk Scores                      │
│                                                                            │
│  Intelligence ──────────────────────►  ThreatIntelligenceScreen            │
│    • Threats                            - Threat Feed                      │
│    • Alerts                             - Intelligence Alerts              │
│    • Correlations                       - Event Correlation                │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘

┌─ ADMINISTRATION ──────────────────────────────────────────────────────────┐
│                                                                            │
│  Accounts ──────────────────────────►  UserManagementScreen                │
│    • Users                              - User Directory                   │
│    • Roles                              - Role Editor                      │
│    • Permissions                        - Permission Matrix                │
│    • Sessions                           - Active Sessions                  │
│                                                                            │
│  Configuration ─────────────────────►  SystemConfigScreen                  │
│    • System Settings                    - Settings Editor                  │
│    • Feature Flags                      - Feature Toggles                  │
│    • Integrations                       - Integration Manager              │
│                                                                            │
│  Billing ───────────────────────────►  BillingScreen                       │
│    • Subscriptions                      - Subscription Status              │
│    • Invoices                           - Invoice History                  │
│    • Usage                              - Usage Metrics                    │
│                                                                            │
│  Communication ─────────────────────►  CommunicationScreen                 │
│    • Channels                           - Channel Configuration            │
│    • Templates                          - Template Editor                  │
│    • Campaigns                          - Campaign Manager                 │
│                                                                            │
│  Training ──────────────────────────►  TrainingScreen                      │
│    • Courses                            - Course Catalog                   │
│    • Certifications                     - Certification Tracker            │
│    • Progress                           - Progress Dashboard               │
│                                                                            │
│  Shifts ────────────────────────────►  ShiftManagementScreen               │
│    • Schedules                          - Schedule Calendar                │
│    • Coverage                           - Coverage Map                     │
│    • Time Tracking                      - Time Entry                       │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Domain Screen Template

```fsharp
/// Standard domain screen structure
let DomainScreen (domain: Domain) (state: DomainState) =
    VBox [
        // L1: Domain Summary Header
        DomainSummaryBar domain state.summary

        // L2: Entity List with Filters
        HBox [
            // Filter sidebar
            Panel "Filters" [
                DomainFilters domain state.filters
            ] |> Width 250

            // Main content area
            VBox [
                // Actions toolbar
                DomainToolbar domain state.selectedItems

                // Entity list/grid
                match state.viewMode with
                | ListView -> DomainList domain state.entities
                | GridView -> DomainGrid domain state.entities
                | MapView -> DomainMap domain state.entities
                | TreeView -> DomainTree domain state.entities

                // Pagination
                Pagination state.page state.totalPages (SetPage domain)
            ] |> Flex 1

            // Detail sidebar (when entity selected)
            match state.selectedEntity with
            | Some entity ->
                Panel "Details" [
                    EntityDetail domain entity
                ] |> Width 400
            | None -> Empty
        ]
    ]

/// Domain summary bar (L1 level)
let DomainSummaryBar (domain: Domain) (summary: DomainSummary) =
    HBox [
        // Domain icon and name
        HBox [
            DomainIcon domain
            Heading H3 (domainName domain)
        ]

        Flex 1

        // Key metrics
        for metric in summary.keyMetrics do
            MetricChip metric.name metric.value metric.trend
            Spacer 8

        // Quick actions
        ButtonGroup [
            Button "Add" (AddEntity domain)
            Button "Import" (ImportEntities domain)
            Button "Export" (ExportEntities domain)
        ]
    ]
```

---

## Part IV: Container & Infrastructure Digital Twin

### 4.1 Container Mapping

```
CONTAINERS ($\mathcal{C}_{3}$)                   TUI REPRESENTATION
═══════════════════════                         ═══════════════════

┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│  indrajaal-app (Phoenix)                ContainerCard "APP"                │
│  ━━━━━━━━━━━━━━━━━━━━━━                ━━━━━━━━━━━━━━━━━━                  │
│                                                                            │
│  ┌─ Port: 4000 ──────────┐             ┌─ APP CONTAINER ─────────────┐   │
│  │ Phoenix Endpoint      │             │ Status: ● RUNNING           │   │
│  │ LiveView Sockets      │             │ Uptime: 25d 14h 32m         │   │
│  │ API Endpoints         │ ──────────► │                             │   │
│  │ WebSocket Channels    │             │ CPU:  ████████░░ 42%        │   │
│  └───────────────────────┘             │ MEM:  ██████████ 68%        │   │
│                                        │ NET:  ██░░░░░░░░ 18 Mbps    │   │
│  Processes:                            │                             │   │
│  • beam.smp (BEAM VM)                  │ Requests: 142/s             │   │
│  • cowboy (HTTP)                       │ Latency:  23ms p99          │   │
│  • phoenix_pubsub                      │ Errors:   0.02%             │   │
│  • oban (jobs)                         │                             │   │
│  • telemetry_poller                    │ [RESTART] [LOGS] [SHELL]    │   │
│                                        └─────────────────────────────┘   │
│                                                                            │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  indrajaal-db (PostgreSQL 17)          ContainerCard "DB"                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━            ━━━━━━━━━━━━━━━━━                    │
│                                                                            │
│  ┌─ Port: 5433 ──────────┐             ┌─ DB CONTAINER ──────────────┐   │
│  │ PostgreSQL 17         │             │ Status: ● RUNNING           │   │
│  │ TimescaleDB           │             │ Uptime: 30d 2h 15m          │   │
│  │ Connection Pool       │ ──────────► │                             │   │
│  └───────────────────────┘             │ CPU:  ███░░░░░░░ 31%        │   │
│                                        │ MEM:  █████░░░░░ 52%        │   │
│  Metrics:                              │ DISK: ██████░░░░ 62%        │   │
│  • Connections: 23/100                 │                             │   │
│  • Transactions/s: 145                 │ Conns:   23/100             │   │
│  • Query latency: 2.3ms                │ TPS:     145                │   │
│  • Cache hit: 99.2%                    │ Latency: 2.3ms              │   │
│  • WAL size: 256MB                     │                             │   │
│                                        │ [RESTART] [LOGS] [PSQL]     │   │
│                                        └─────────────────────────────┘   │
│                                                                            │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  indrajaal-obs (SigNoz/OTEL)           ContainerCard "OBS"                 │
│  ━━━━━━━━━━━━━━━━━━━━━━━━             ━━━━━━━━━━━━━━━━━                    │
│                                                                            │
│  ┌─ Port: 8123 ──────────┐             ┌─ OBS CONTAINER ─────────────┐   │
│  │ SigNoz UI             │             │ Status: ⚠ DEGRADED          │   │
│  │ OTEL Collector        │             │ Uptime: 25d 14h 32m         │   │
│  │ ClickHouse            │ ──────────► │                             │   │
│  └───────────────────────┘             │ CPU:  ██░░░░░░░░ 22%        │   │
│                                        │ MEM:  ████████░░ 78%        │   │
│  Metrics:                              │                             │   │
│  • Traces/min: 1,234                   │ ⚠ Trace latency: 2.3s       │   │
│  • Spans/min: 45,678                   │   (target: <1s)             │   │
│  • Metrics/min: 12,345                 │                             │   │
│  • Logs/min: 5,678                     │ Traces: 1,234/min           │   │
│  • Ingestion latency: 2.3s ⚠           │ Spans:  45,678/min          │   │
│                                        │                             │   │
│                                        │ [RESTART] [LOGS] [SIGNOZ]   │   │
│                                        └─────────────────────────────┘   │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Infrastructure Components

```fsharp
/// Container health monitor
let ContainerHealthMonitor (containers: ContainerState list) =
    HBox [
        for container in containers do
            ContainerMiniCard container
            Spacer 8
    ]

/// Container detail view (L3)
let ContainerDetail (container: ContainerState) (metrics: ContainerMetrics) =
    VBox [
        // Header
        HBox [
            ContainerIcon container.type'
            Heading H2 container.name
            StatusBadge container.status
        ]

        // Metrics Grid
        Grid 3 2 [
            GaugeChart "CPU" metrics.cpu { max = 100; warning = 75; critical = 90 }
            GaugeChart "Memory" metrics.memory { max = 100; warning = 80; critical = 95 }
            GaugeChart "Disk" metrics.disk { max = 100; warning = 70; critical = 85 }

            Sparkline "CPU History" metrics.cpuHistory
            Sparkline "Memory History" metrics.memoryHistory
            Sparkline "Network I/O" metrics.networkHistory
        ]

        // Container-specific metrics
        match container.type' with
        | App ->
            Panel "Application Metrics" [
                MetricCard "Requests/s" metrics.requestsPerSecond
                MetricCard "P99 Latency" metrics.latencyP99
                MetricCard "Error Rate" metrics.errorRate
                MetricCard "Active Connections" (float metrics.connections)
            ]
        | Database ->
            Panel "Database Metrics" [
                MetricCard "Connections" (float metrics.dbConnections)
                MetricCard "TPS" (float metrics.transactionsPerSecond)
                MetricCard "Cache Hit" metrics.cacheHitRate
                MetricCard "Replication Lag" metrics.replicationLag
            ]
        | Observability ->
            Panel "Observability Metrics" [
                MetricCard "Traces/min" (float metrics.tracesPerMinute)
                MetricCard "Ingestion Latency" metrics.ingestionLatency
                MetricCard "Storage Used" metrics.storageUsed
                MetricCard "Retention" (float metrics.retentionDays)
            ]

        // Processes
        Panel "Processes" [
            Table
                [ "PID"; "Name"; "CPU"; "Memory" ]
                [ for proc in metrics.processes ->
                    [ string proc.pid; proc.name; sprintf "%.1f%%" proc.cpu; sprintf "%.1f%%" proc.memory ]
                ]
        ]

        // Actions
        HBox [
            TwoStepButton "Restart" (RestartContainer container.id)
            Button "View Logs" (ViewContainerLogs container.id)
            Button "Open Shell" (OpenContainerShell container.id)
        ]
    ]
```

---

## Part V: Safety System Digital Twin

### 5.1 Safety Systems Mapping

```
SAFETY SYSTEMS                                TUI REPRESENTATION
══════════════                                ═══════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│                        SAFETY MONITORING DASHBOARD                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─ GUARDIAN ────────────────────────────────────────────────────────────┐  │
│  │ Simplex Gatekeeper (SC-SAF-001 to SC-SAF-010)                         │  │
│  │                                                                        │  │
│  │ Status: ● ACTIVE   Violations Today: 0   Blocked Commands: 2          │  │
│  │                                                                        │  │
│  │ Pre-Flight Checks:                                                    │  │
│  │ ✓ State consistency     ✓ Resource bounds      ✓ Safety invariants    │  │
│  │ ✓ Command authorization ✓ Rate limiting        ✓ Envelope compliance │  │
│  │                                                                        │  │
│  │ [View Blocked Commands] [Configure Limits] [View Audit Log]           │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌─ DEAD MAN'S SWITCH ───────────────────────────────────────────────────┐  │
│  │ Heartbeat Monitor (SC-SAF-011 to SC-SAF-020)                          │  │
│  │                                                                        │  │
│  │ Status: ● HEALTHY   Heartbeats: 4,285   Missed: 0   Threshold: 10s    │  │
│  │                                                                        │  │
│  │ Last Heartbeat: 0.3s ago                                              │  │
│  │ ████████████████████████████████████████████░░░░░░░░ 0.3s / 10s       │  │
│  │                                                                        │  │
│  │ Nodes: app-01 ✓ 0.2s | app-02 ✓ 0.3s | app-03 ✓ 0.5s                │  │
│  │                                                                        │  │
│  │ [Configure Threshold] [View Heartbeat Log] [Test Failover]            │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌─ ENVELOPE ────────────────────────────────────────────────────────────┐  │
│  │ Safety Bounds (SC-SAF-021 to SC-SAF-030)                              │  │
│  │                                                                        │  │
│  │ CPU Utilization:  ████████████░░░░░░░░ 60% (limit: 90%)              │  │
│  │ Memory Usage:     ██████████████░░░░░░ 68% (limit: 85%)              │  │
│  │ FLAME Nodes:      ████░░░░░░░░░░░░░░░░ 4/10 (limit: 10)              │  │
│  │ Request Rate:     ████████░░░░░░░░░░░░ 142/s (limit: 500/s)          │  │
│  │                                                                        │  │
│  │ [Modify Envelope] (requires two-key authorization)                    │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌─ SENTINEL ────────────────────────────────────────────────────────────┐  │
│  │ Quorum Monitor (SC-SAF-031 to SC-SAF-040)                             │  │
│  │                                                                        │  │
│  │ Quorum: 3/3 ✓    Strategy: distributed    Split-Brain: NO            │  │
│  │                                                                        │  │
│  │ Nodes:                                                                │  │
│  │ ★ indrajaal-1 (LEADER)  ● 100.64.1.1  Last: 0.2s  Votes: 3           │  │
│  │ ● indrajaal-2           ● 100.64.1.2  Last: 0.3s  Votes: 3           │  │
│  │ ● indrajaal-3           ● 100.64.1.3  Last: 0.5s  Votes: 3           │  │
│  │                                                                        │  │
│  │ [Force Election] [View Gossip Log] [Configure Quorum]                 │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌─ STAMP CONSTRAINT MONITOR ────────────────────────────────────────────┐  │
│  │ 242 Safety Constraints                                                 │  │
│  │                                                                        │  │
│  │ ✓ Validated: 240/242 (99.2%)   ⚠ Warning: 2   ☢ Violated: 0          │  │
│  │                                                                        │  │
│  │ Categories:                                                            │  │
│  │ SC-VAL (Validation):    ✓ 15/15    SC-CNT (Container):  ✓ 12/12      │  │
│  │ SC-AGT (Agents):        ✓ 20/20    SC-CMP (Compile):    ✓ 10/10      │  │
│  │ SC-SEC (Security):      ✓ 25/25    SC-PRF (Performance): ⚠ 18/20     │  │
│  │ SC-EMR (Emergency):     ✓ 10/10    SC-OBS (Observability): ✓ 15/15   │  │
│  │ ... and 117 more                                                      │  │
│  │                                                                        │  │
│  │ [View All Constraints] [Run Validation] [View Violations]             │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Safety Components

```fsharp
/// Safety system state
type SafetyState = {
    guardian: GuardianState
    deadMansSwitch: DMSState
    envelope: EnvelopeState
    sentinel: SentinelState
    stampConstraints: ConstraintState list
}

/// Safety dashboard component
let SafetyDashboard (state: SafetyState) =
    VBox [
        // Overall safety status
        SafetyStatusBar state

        // Individual system panels
        Grid 2 2 [
            GuardianPanel state.guardian
            DMSPanel state.deadMansSwitch
            EnvelopePanel state.envelope
            SentinelPanel state.sentinel
        ]

        // STAMP Constraint Summary
        STAMPConstraintSummary state.stampConstraints
    ]

/// Guardian panel
let GuardianPanel (guardian: GuardianState) =
    Panel "GUARDIAN" [
        HBox [
            StatusDot guardian.status
            Text "Simplex Gatekeeper" { bold = true }
            Flex 1
            Badge (sprintf "%d violations" guardian.violationsToday) { variant = if guardian.violationsToday = 0 then Success else Warning }
        ]

        Divider Horizontal

        Grid 3 1 [
            MetricMini "Pre-flight Checks" (float guardian.checksRun) NoTrend
            MetricMini "Blocked" (float guardian.blockedCommands) NoTrend
            MetricMini "Approved" (float guardian.approvedCommands) NoTrend
        ]

        // Check status
        Wrap 8 [
            for check in guardian.checks do
                Chip (checkName check.type') { color = if check.passed then Green else Red }
        ]

        HBox [
            Button "View Blocked" (ViewBlockedCommands)
            Button "Audit Log" (ViewGuardianLog)
        ]
    ]

/// STAMP constraint viewer
let STAMPConstraintViewer (constraints: ConstraintState list) =
    let byCategory = constraints |> List.groupBy (fun c -> c.category)

    VBox [
        // Summary bar
        HBox [
            let passed = constraints |> List.filter (fun c -> c.status = Passed) |> List.length
            let warned = constraints |> List.filter (fun c -> c.status = Warning) |> List.length
            let failed = constraints |> List.filter (fun c -> c.status = Violated) |> List.length

            Badge (sprintf "✓ %d" passed) { color = Green }
            Badge (sprintf "⚠ %d" warned) { color = Amber }
            Badge (sprintf "☢ %d" failed) { color = Red }
        ]

        // Category breakdown
        VBox [
            for (category, catConstraints) in byCategory do
                let allPassed = catConstraints |> List.forall (fun c -> c.status = Passed)
                Panel category [
                    VBox [
                        for constraint in catConstraints do
                            HBox [
                                StatusDot constraint.status
                                Text constraint.id {}
                                Flex 1
                                Text constraint.description { fg = Gray; truncate = 40 }
                            ]
                    ]
                ] |> Border { color = if allPassed then Green else Amber }
        ]
    ]
```

---

## Part VI: Observability Digital Twin

### 6.1 Observability System Mapping

```
OBSERVABILITY ($\mathcal{O}_{4}$)               TUI REPRESENTATION
════════════════════════                        ═══════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│                       OBSERVABILITY DASHBOARD                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─ TELEMETRY ───────────────────────────────────────────────────────────┐  │
│  │ OpenTelemetry Pipeline                                                 │  │
│  │                                                                        │  │
│  │  Phoenix ─────► OTLP ─────► SigNoz                                    │  │
│  │  Ecto    ─────► Collector ─► ClickHouse                               │  │
│  │  Oban    ─────►           ─► TimescaleDB                              │  │
│  │  Finch   ─────►           ─► Local (Fallback)                         │  │
│  │                                                                        │  │
│  │  Traces:  1,234/min ✓     Spans:   45,678/min ✓                       │  │
│  │  Metrics: 12,345/min ✓    Logs:    5,678/min ✓                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌─ TRACING ─────────────────────────────────────────────────────────────┐  │
│  │ Distributed Trace Viewer                                               │  │
│  │                                                                        │  │
│  │  Recent Traces (slowest first):                                       │  │
│  │  ────────────────────────────────────────────────────────────────────  │  │
│  │  abc123 │ POST /api/alarms   │ 234ms │ 12 spans │ ⚠ slow              │  │
│  │  ├─ Phoenix.Endpoint        │   2ms │                                 │  │
│  │  ├─ AlarmController.create  │   5ms │                                 │  │
│  │  ├─ Ecto.Repo.insert        │ 180ms │ ⚠ slow query                    │  │
│  │  └─ PubSub.broadcast        │   3ms │                                 │  │
│  │                                                                        │  │
│  │  [Open in SigNoz] [Export] [Search Traces]                            │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌─ METRICS ─────────────────────────────────────────────────────────────┐  │
│  │ System Metrics                                                         │  │
│  │                                                                        │  │
│  │  Request Rate       Error Rate           P99 Latency                  │  │
│  │  ┌────────────┐     ┌────────────┐      ┌────────────┐               │  │
│  │  │   142/s    │     │   0.02%    │      │    23ms    │               │  │
│  │  │ ▁▂▃▄▅▆▅▄▃▄ │     │ ▁▁▁▁▁▂▁▁▁ │      │ ▂▂▃▂▂▃▄▃▂ │               │  │
│  │  └────────────┘     └────────────┘      └────────────┘               │  │
│  │                                                                        │  │
│  │  [Configure Metrics] [Create Alert] [Export Dashboard]                │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌─ LOGGING ─────────────────────────────────────────────────────────────┐  │
│  │ Fractal Log Viewer (5-Level)                                          │  │
│  │                                                                        │  │
│  │  Level: [Spine ▼] [Thorax] [Segment] [Fiber] [Gossamer]              │  │
│  │                                                                        │  │
│  │  14:32:45.123 INFO  [Prajna.SmartMetrics] Recorded metric: cpu.app-03 │  │
│  │  14:32:45.234 WARN  [Prajna.AiCopilot] Anomaly detected: high CPU     │  │
│  │  14:32:45.345 INFO  [Prajna.Orchestrator] Insight published           │  │
│  │  14:32:46.123 DEBUG [Phoenix.PubSub] Broadcast: prajna:metrics        │  │
│  │  14:32:46.234 INFO  [Sentinel] Heartbeat received from indrajaal-2    │  │
│  │                                                                        │  │
│  │  [Live Tail: ON] [Search] [Filter by Module] [Export]                 │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Zenoh Data Flow Twin

```
ZENOH CHANNELS                                 TUI REPRESENTATION
══════════════                                 ═══════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│                          ZENOH DATA FLOW DIAGRAM                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   PUBLISHERS                    TOPICS                    SUBSCRIBERS        │
│   ══════════                    ══════                    ═══════════       │
│                                                                              │
│   ┌─────────┐                                             ┌─────────────┐   │
│   │ Sensors │────►c3i/sensors/*/telemetry────────────────►│ SmartMetrics│   │
│   └─────────┘     ████████░░ 142 msg/s                    └─────────────┘   │
│                                                                              │
│   ┌─────────┐                                             ┌─────────────┐   │
│   │ Alarms  │────►c3i/alarms/*/events────────────────────►│ AlarmProc   │   │
│   └─────────┘     ██░░░░░░░░ 12 msg/s                     └─────────────┘   │
│                                                                              │
│   ┌─────────┐                                             ┌─────────────┐   │
│   │ Copilot │────►c3i/ai/insights────────────────────────►│ UI/PubSub   │   │
│   └─────────┘     █░░░░░░░░░ 2 msg/s                      └─────────────┘   │
│                                                                              │
│   ┌─────────┐                                             ┌─────────────┐   │
│   │Commands │◄───c3i/commands/*/ctrl─────────────────────►│ Guardian    │   │
│   └─────────┘     ██░░░░░░░░ 8 msg/s                      └─────────────┘   │
│                                                                              │
│   ┌─────────┐                                             ┌─────────────┐   │
│   │ OODA    │────►c3i/ooda/cycle────────────────────────►│ Controller  │   │
│   └─────────┘     █████████░ 10 msg/s                     └─────────────┘   │
│                                                                              │
│   Message Flow: Total 174 msg/s │ Latency: 2.3ms avg │ Buffer: 2%          │
│                                                                              │
│   [View All Channels] [Inspect Message] [Create Subscription]               │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Part VII: State Synchronization

### 7.1 Real-Time State Sync

```fsharp
/// State synchronization between physical system and digital twin
module StateSynchronization =

    /// State change event
    type StateChange =
        | AgentStateChanged of AgentId * AgentState
        | ContainerStateChanged of ContainerId * ContainerState
        | AlarmStateChanged of AlarmId * AlarmState
        | NodeStateChanged of NodeId * NodeState
        | MetricUpdated of MetricKey * MetricValue
        | ConstraintViolation of ConstraintId * ViolationDetails

    /// Subscription to system state via Zenoh
    let subscribeToSystemState () =
        async {
            // Subscribe to all state change topics
            let! subscription = Zenoh.subscribe "c3i/**"

            return subscription
            |> Observable.choose parseStateChange
            |> Observable.bufferTime (TimeSpan.FromMilliseconds(100))
            |> Observable.map batchUpdates
        }

    /// Update TUI state from system state
    let applyStateChange (tuiState: TUIState) (change: StateChange) : TUIState =
        match change with
        | AgentStateChanged (id, state) ->
            { tuiState with agents = Map.add id state tuiState.agents }

        | ContainerStateChanged (id, state) ->
            { tuiState with containers = Map.add id state tuiState.containers }

        | AlarmStateChanged (id, state) ->
            let alarms =
                match state.status with
                | Active -> Map.add id state tuiState.alarms
                | Resolved -> Map.remove id tuiState.alarms
            { tuiState with alarms = alarms }

        | NodeStateChanged (id, state) ->
            { tuiState with nodes = Map.add id state tuiState.nodes }

        | MetricUpdated (key, value) ->
            let metrics = tuiState.metrics |> updateMetric key value
            { tuiState with metrics = metrics }

        | ConstraintViolation (id, details) ->
            let violations = (id, details) :: tuiState.violations
            { tuiState with violations = violations }

    /// Command from TUI to physical system
    let sendCommand (cmd: SystemCommand) : Result<unit, string> Async =
        async {
            // Validate via Guardian
            let! guardianResult = Guardian.preFlightCheck cmd

            match guardianResult with
            | Ok () ->
                // Publish command to Zenoh
                let topic = commandTopic cmd
                let payload = serializeCommand cmd
                do! Zenoh.publish topic payload
                return Ok ()

            | Error violation ->
                return Error (sprintf "Guardian blocked: %s" violation.reason)
        }
```

### 7.2 Bidirectional Binding

```fsharp
/// Bidirectional state binding for real-time synchronization
module BidirectionalBinding =

    /// Bound value that syncs with system state
    type BoundValue<'T> = {
        localValue: 'T
        remoteValue: 'T
        lastSync: DateTime
        dirty: bool
        syncing: bool
    }

    /// Create a bound value
    let bind (key: string) (initial: 'T) : BoundValue<'T> Agent =
        Agent.Start(fun inbox ->
            let rec loop state = async {
                let! msg = inbox.Receive()

                match msg with
                | LocalUpdate value ->
                    // Update local, mark dirty
                    let newState = { state with localValue = value; dirty = true }
                    do! syncToRemote key value
                    return! loop { newState with dirty = false; lastSync = DateTime.UtcNow }

                | RemoteUpdate value ->
                    // Update from remote
                    let newState = { state with remoteValue = value; localValue = value; lastSync = DateTime.UtcNow }
                    return! loop newState

                | GetValue reply ->
                    reply.Reply(state.localValue)
                    return! loop state
            }
            loop { localValue = initial; remoteValue = initial; lastSync = DateTime.UtcNow; dirty = false; syncing = false }
        )

    /// Component that automatically binds to system state
    let BoundComponent (key: string) (render: 'T -> Element) : Element =
        let bound = bind key (defaultValue key)

        // Subscribe to remote changes
        Zenoh.subscribe (sprintf "c3i/state/%s" key)
        |> Observable.subscribe (fun value -> bound.Post(RemoteUpdate value))
        |> ignore

        // Render with current value
        let currentValue = bound.PostAndReply(GetValue)
        render currentValue
```

---

## Part VIII: Complete System Representation

### 8.1 System Overview Screen

```fsharp
/// Complete system overview at L0
let SystemOverview (state: SystemState) =
    VBox [
        // Health Score (giant, center)
        Center [
            VBox [
                Text (sprintf "%.0f%%" (state.healthScore * 100.0)) { fontSize = 72; fg = healthColor state.healthScore }
                Text (healthLabel state.healthScore) { fontSize = 24 }
            ]
        ]

        // Critical metrics bar
        HBox [
            Flex 1
            MetricBadge "Agents" (sprintf "%d/%d" state.activeAgents state.totalAgents)
            MetricBadge "Containers" (containerStatusBadge state.containers)
            MetricBadge "Alarms" (alarmSummaryBadge state.alarms)
            MetricBadge "Safety" (safetyStatusBadge state.safety)
            Flex 1
        ]

        // Level indicator
        Center [
            Text "Press SPACE or TAP to drill down" { fg = Gray }
        ]
    ]
    |> when' (state.healthScore < 0.5) (Pulse 1000<ms>)
    |> when' (state.criticalAlarms > 0) (Border { color = Red })

/// Complete system at L1
let SystemSummary (state: SystemState) =
    Grid 3 2 [
        // Agents summary
        Panel "Agents (50)" [
            AgentSummaryGrid state.agents
        ]

        // Domains summary
        Panel "Domains (30+)" [
            DomainSummaryGrid state.domains
        ]

        // Containers
        Panel "Containers (3)" [
            ContainerSummaryBar state.containers
        ]

        // Safety systems
        Panel "Safety (242 SC)" [
            SafetySummaryBar state.safety
        ]

        // Observability
        Panel "Observability" [
            ObservabilitySummaryBar state.observability
        ]

        // AI Copilot
        Panel "AI Copilot" [
            CopilotSummaryBar state.copilot
        ]
    ]
```

### 8.2 Dimension Navigator

```fsharp
/// Navigate all system dimensions
let DimensionNavigator (currentDimension: SystemDimension) =
    VBox [
        Text "SYSTEM DIMENSIONS" { bold = true }
        Divider Horizontal

        NavigationList [
            NavItem "Agents" (icon = AgentIcon) (badge = "50") (NavigateTo Agents)
            NavItem "Domains" (icon = DomainIcon) (badge = "30+") (NavigateTo Domains)
            NavItem "Containers" (icon = ContainerIcon) (badge = "3") (NavigateTo Containers)
            NavItem "Safety" (icon = SafetyIcon) (badge = "242") (NavigateTo Safety)
            NavItem "Observability" (icon = ObsIcon) (badge = "4") (NavigateTo Observability)
            NavItem "Cluster" (icon = ClusterIcon) (badge = "var") (NavigateTo Cluster)
            NavItem "FLAME" (icon = FlameIcon) (badge = "3") (NavigateTo FLAME)
            NavItem "Zenoh" (icon = ZenohIcon) (badge = "50+") (NavigateTo Zenoh)
            NavItem "AI/ML" (icon = AIIcon) (badge = "6") (NavigateTo AIML)
            NavItem "STAMP" (icon = STAMPIcon) (badge = "242") (NavigateTo STAMP)
        ]
    ]
```

---

## Summary

## 3.0 The Biological Layer (v2.0)

PRAJNA v2.0 extends the Digital Twin concept to include **Biological Isomorphism**. The digital representation now mirrors the *organic* function of the system, not just its mechanical structure.

### 3.1 Mapping Physiology to Telemetry

| Biological Function | Digital Implementation | Metric Source |
|---------------------|------------------------|---------------|
| **Pulse** | Heartbeat / Liveness | `node_up` events |
| **Metabolism** | Resource Consumption | CPU / RAM / Disk I/O |
| **Stress** | Load / Saturation | Queue Lengths / Latency |
| **Immunity** | Anomaly Defense | Antibody Activity / Blocked IPs |

### 3.2 The Holon State Vector

The Digital Twin state is no longer a bag of metrics but a structured **Vital Signs** vector.

```json
{
  "id": "uuid-node-01",
  "bio": {
    "health": 0.98,
    "stress": 0.12,
    "energy": 0.45
  },
  "intent": "processing_batch",
  "prediction": "health_stable"
}
```

This vector is computed recursively. The `Health` of a Cluster is the aggregate `Health` of its Nodes. This allows the Digital Twin to be queried at any resolution.

