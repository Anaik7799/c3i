# PRAJNA Fractal Design System
**Version**: 1.0.0 | **Date**: 2025-12-27 | **Status**: ACTIVE
**Principle**: Self-Similarity Across ALL Scales - Visual, Data, Operational

## Executive Summary

The PRAJNA Intelligent Cockpit implements a **Fractal Design System** where the same structural patterns repeat at every scale of the system - from the highest-level architecture down to individual UI components. This creates:

- **Cognitive Coherence**: Operators learn patterns once, apply everywhere
- **Predictable Behavior**: Same structure = same interaction model
- **Scalable Complexity**: Zoom in/out without losing structure
- **Maintainable Codebase**: Patterns replicate, don't reinvent

```
FRACTAL SELF-SIMILARITY PRINCIPLE
══════════════════════════════════

                    ┌───────────────────────────────────┐
                    │         SYSTEM LEVEL              │
                    │   ┌───────────────────────────┐   │
                    │   │      DOMAIN LEVEL         │   │
                    │   │   ┌───────────────────┐   │   │
                    │   │   │   ENTITY LEVEL    │   │   │
                    │   │   │   ┌───────────┐   │   │   │
                    │   │   │   │ COMPONENT │   │   │   │
                    │   │   │   │ ┌───────┐ │   │   │   │
                    │   │   │   │ │ELEMENT│ │   │   │   │
                    │   │   │   │ └───────┘ │   │   │   │
                    │   │   │   └───────────┘   │   │   │
                    │   │   └───────────────────┘   │   │
                    │   └───────────────────────────┘   │
                    └───────────────────────────────────┘

Each level exhibits the SAME structural patterns:
• Header / Summary / Detail / Actions
• Status indicator / Trend / Value / Threshold
• Health score / Sub-scores / Metrics
• L0 → L1 → L2 → L3 → L4 drill-down
```

---

## Part I: Fractal Levels (L0-L4)

### 1.1 The Five Fractal Levels

The 5-level hierarchy applies EVERYWHERE in the system:

```
LEVEL     SYSTEM VIEW          DOMAIN VIEW           ENTITY VIEW          COMPONENT VIEW
═════     ═══════════          ═══════════           ═══════════          ══════════════

L0        System Health: 94%   Domain Health: 96%    Entity Status: ●     Component: ●
          (Single Score)       (Single Score)        (Single Icon)        (Single Token)

L1        3 Containers ✓       12 Entities ✓         3 Key Metrics        3 Properties
          7 Active Alarms      2 Active Issues       2 Relationships      1 Value + Trend
          50 Agents Online     5 Recent Events       1 Primary Action

L2        Container List       Entity Grid/List      Metric Cards         Property List
          Alarm Feed           Issue Timeline        Relationship Map     Value History
          Agent Grid           Event Log             Action Menu          Validation

L3        Container Detail     Entity Full View      Metric Detail        Property Editor
          Alarm Investigation  Issue Resolution      Graph + Analysis     Full Configuration
          Agent Configuration  Event Correlation     History + Predict    Constraints

L4        Container Logs       Entity Raw Data       Metric Telemetry     Property JSON
          Alarm Events         Entity State Dump     Raw Data Points      Schema Definition
          Agent Traces         Database Records      Statistical Model    Type System
```

### 1.2 Fractal Level Components

```fsharp
/// Fractal level-aware component wrapper
type FractalComponent<'T> = {
    l0: 'T -> Element    // Single token representation
    l1: 'T -> Element    // Summary with key facts
    l2: 'T -> Element    // List item / grid cell
    l3: 'T -> Element    // Full detail view
    l4: 'T -> Element    // Raw / atomic data
}

/// Create a fractal component
let fractal (spec: FractalSpec<'T>) : FractalComponent<'T> = {
    l0 = fun data -> spec.token data
    l1 = fun data -> Panel spec.name [ spec.summary data ]
    l2 = fun data -> Card { padding = 8 } [ spec.listItem data ]
    l3 = fun data -> VBox [ spec.header data; spec.detail data; spec.actions data ]
    l4 = fun data -> Pre (Json.serialize data)
}

/// Render at appropriate level
let renderFractal (level: int) (component: FractalComponent<'T>) (data: 'T) : Element =
    match level with
    | 0 -> component.l0 data
    | 1 -> component.l1 data
    | 2 -> component.l2 data
    | 3 -> component.l3 data
    | 4 -> component.l4 data
    | _ -> component.l2 data
```

### 1.3 Fractal Application Examples

```fsharp
/// Alarm as a fractal component
let alarmFractal : FractalComponent<Alarm> = fractal {
    name = "Alarm"

    token = fun alarm ->
        AlarmIcon alarm.severity
        |> when' (alarm.severity >= Warning) (Pulse 500<ms>)

    summary = fun alarm ->
        HBox [
            AlarmIcon alarm.severity
            Text (sprintf "%d %s" (countBySeverity alarm.severity) (alarm.severity.ToString()))
        ]

    listItem = fun alarm ->
        HBox [
            AlarmIcon alarm.severity
            Spacer 4
            VBox [
                Text alarm.message { bold = true }
                Text (sprintf "%s | %s ago" alarm.source (formatAge alarm.timestamp)) { fg = Gray }
            ]
            Flex 1
            Button "ACK" (AckAlarm alarm.id)
        ]

    header = fun alarm ->
        VBox [
            HBox [ AlarmIcon alarm.severity; Heading H2 alarm.message ]
            Text (sprintf "Source: %s | ID: %s" alarm.source alarm.id) { fg = Gray }
        ]

    detail = fun alarm ->
        VBox [
            // Timeline
            Panel "Timeline" [ AlarmTimeline alarm.events ]
            // Correlations
            Panel "Related Events" [ CorrelationList alarm.correlations ]
            // AI Analysis
            Panel "AI Analysis" [ CopilotInsight alarm.aiAnalysis ]
        ]

    actions = fun alarm ->
        HBox [
            Button "Acknowledge" (AckAlarm alarm.id)
            Button "Silence" (SilenceAlarm alarm.id)
            Button "Escalate" (EscalateAlarm alarm.id)
            Button "View Source" (NavigateTo alarm.sourceEntity)
        ]
}

/// Container as a fractal component
let containerFractal : FractalComponent<Container> = fractal {
    name = "Container"

    token = fun container ->
        StatusDot container.status

    summary = fun container ->
        HBox [
            StatusDot container.status
            Text container.name { bold = true }
            Spacer 8
            Text (sprintf "CPU: %.0f%%" container.cpu) {}
            Text (sprintf "MEM: %.0f%%" container.memory) {}
        ]

    listItem = fun container ->
        Card { elevation = 2 } [
            HBox [
                StatusDot container.status
                VBox [
                    Text container.name { bold = true }
                    Text (sprintf "Port: %d" container.port) { fg = Gray }
                ]
                Flex 1
                VBox [
                    ProgressBar container.cpu { max = 100; label = "CPU" }
                    ProgressBar container.memory { max = 100; label = "MEM" }
                ]
            ]
        ]

    header = fun container ->
        VBox [
            HBox [ ContainerIcon container.type'; Heading H2 container.name ]
            Text (sprintf "Image: %s | Port: %d" container.image container.port) { fg = Gray }
        ]

    detail = fun container ->
        VBox [
            // Resource usage
            Panel "Resources" [
                Grid 2 2 [
                    GaugeChart "CPU" container.cpu
                    GaugeChart "Memory" container.memory
                    GaugeChart "Disk" container.disk
                    GaugeChart "Network" container.network
                ]
            ]
            // Processes
            Panel "Processes" [ ProcessTable container.processes ]
            // Logs
            Panel "Recent Logs" [ LogTail container.logs 10 ]
        ]

    actions = fun container ->
        HBox [
            TwoStepButton "Restart" (RestartContainer container.id)
            Button "View Logs" (ViewContainerLogs container.id)
            Button "Open Shell" (OpenContainerShell container.id)
        ]
}

/// Agent as a fractal component
let agentFractal : FractalComponent<Agent> = fractal {
    name = "Agent"

    token = fun agent ->
        StatusDot agent.status

    summary = fun agent ->
        HBox [
            StatusDot agent.status
            Text agent.id { bold = true }
            Spacer 8
            Badge (agent.agentType.ToString()) {}
            Text (sprintf "Eff: %.0f%%" (agent.efficiency * 100.0)) {}
        ]

    listItem = fun agent ->
        HBox [
            StatusDot agent.status
            VBox [
                Text agent.id { bold = true }
                Text (agent.currentTask |> Option.defaultValue "Idle") { fg = Gray; truncate = 30 }
            ]
            Flex 1
            MetricMini "Queue" (float agent.queueDepth) NoTrend
            MetricMini "Eff" agent.efficiency (if agent.efficiency >= 0.9 then Stable else Falling)
        ]

    header = fun agent ->
        VBox [
            HBox [
                StatusDot agent.status
                Heading H2 agent.id
                Badge (agent.agentType.ToString()) { variant = Filled }
            ]
            Text (sprintf "Type: %s | Status: %s" (agent.agentType.ToString()) (agent.status.ToString())) { fg = Gray }
        ]

    detail = fun agent ->
        VBox [
            // Metrics
            Panel "Performance" [
                Grid 2 2 [
                    MetricCard "Workload" agent.workload agent.workloadHistory
                    MetricCard "Efficiency" agent.efficiency agent.efficiencyHistory
                    MetricCard "Queue" (float agent.queueDepth) agent.queueHistory
                    MetricCard "Errors" (float agent.errorCount) agent.errorHistory
                ]
            ]
            // Task history
            Panel "Task History" [ TaskTimeline agent.taskHistory ]
            // Configuration
            Panel "Configuration" [ ConfigEditor agent.config ]
        ]

    actions = fun agent ->
        HBox [
            Button "Pause" (PauseAgent agent.id)
            Button "Resume" (ResumeAgent agent.id)
            Button "Restart" (RestartAgent agent.id)
            Button "View Logs" (ViewAgentLogs agent.id)
        ]
}
```

---

## Part II: Fractal Visual Design

### 2.1 Fractal Visual Structure

Every visual element follows the same structural pattern:

```
FRACTAL VISUAL STRUCTURE
════════════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│ HEADER: Identity + Status                                                   │
│ ───────────────────────────────────────────────────────────────────────────│
│ [Icon] [Name]                                    [Status] [Primary Action] │
├─────────────────────────────────────────────────────────────────────────────┤
│ SUMMARY: Key Metrics (Fractal L1)                                           │
│ ───────────────────────────────────────────────────────────────────────────│
│ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐                   │
│ │  Metric 1 │ │  Metric 2 │ │  Metric 3 │ │  Metric 4 │                   │
│ │   Value   │ │   Value   │ │   Value   │ │   Value   │                   │
│ │   Trend   │ │   Trend   │ │   Trend   │ │   Trend   │                   │
│ └───────────┘ └───────────┘ └───────────┘ └───────────┘                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ DETAIL: Expanded Content (Fractal L2-L3)                                    │
│ ───────────────────────────────────────────────────────────────────────────│
│ ┌─────────────────────────────────────────────────────────────────────────┐│
│ │ [Sub-component 1 - follows same fractal pattern]                        ││
│ └─────────────────────────────────────────────────────────────────────────┘│
│ ┌─────────────────────────────────────────────────────────────────────────┐│
│ │ [Sub-component 2 - follows same fractal pattern]                        ││
│ └─────────────────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────────────────┤
│ ACTIONS: Available Operations                                               │
│ ───────────────────────────────────────────────────────────────────────────│
│ [Primary Action] [Secondary Action] [Secondary Action] [Tertiary Action]   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Fractal Color System

```fsharp
/// Fractal color palette - same semantics at all scales
module FractalColors =

    /// Status colors (fractal - same meaning everywhere)
    type StatusColor =
        | Healthy of string     // Green variants
        | Degraded of string    // Amber variants
        | Failing of string     // Red variants
        | Unknown of string     // Gray variants
        | Neutral of string     // Blue variants

    /// Status color at different intensity levels (fractal depth)
    let statusColorAtDepth (status: Status) (depth: int) : string =
        let baseColor = match status with
            | Healthy -> "#22C55E"   // Green-500
            | Degraded -> "#F59E0B" // Amber-500
            | Failing -> "#EF4444"  // Red-500
            | Unknown -> "#6B7280"  // Gray-500
            | Neutral -> "#06B6D4"  // Cyan-500

        // Fractal depth affects intensity
        match depth with
        | 0 -> saturate baseColor 1.0     // Full saturation for L0
        | 1 -> saturate baseColor 0.85    // Slightly less for L1
        | 2 -> saturate baseColor 0.70    // Medium for L2
        | 3 -> saturate baseColor 0.55    // Lower for L3
        | 4 -> saturate baseColor 0.40    // Minimum for L4
        | _ -> baseColor

    /// Severity colors (fractal - same across alarms, metrics, status)
    let severityColor (severity: Severity) : string =
        match severity with
        | Critical -> "#DC2626"  // Red-600
        | Warning -> "#EF4444"   // Red-500
        | Caution -> "#F59E0B"   // Amber-500
        | Advisory -> "#06B6D4"  // Cyan-500
        | Normal -> "#374151"    // Gray-700

    /// Trend colors (fractal - same for all trend indicators)
    let trendColor (trend: Trend) : string =
        match trend with
        | RisingFast -> "#EF4444"   // Red (bad if rising)
        | Rising -> "#F59E0B"       // Amber
        | Stable -> "#22C55E"       // Green
        | Falling -> "#F59E0B"      // Amber
        | FallingFast -> "#22C55E"  // Green (good if falling)
```

### 2.3 Fractal Typography

```fsharp
/// Fractal typography system
module FractalTypography =

    /// Font sizes at fractal levels
    let fontSizeAtLevel (level: int) : int =
        match level with
        | 0 -> 48   // L0: Giant, single score
        | 1 -> 24   // L1: Large headers
        | 2 -> 16   // L2: Standard body
        | 3 -> 14   // L3: Detailed text
        | 4 -> 12   // L4: Monospace, raw data

    /// Font weight at fractal levels
    let fontWeightAtLevel (level: int) : FontWeight =
        match level with
        | 0 -> ExtraBold  // L0: Maximum emphasis
        | 1 -> Bold       // L1: Strong headers
        | 2 -> Medium     // L2: Normal emphasis
        | 3 -> Regular    // L3: Standard weight
        | 4 -> Light      // L4: De-emphasized

    /// Apply fractal typography
    let applyFractalTypography (level: int) (element: Element) : Element =
        element
        |> Style { fontSize = fontSizeAtLevel level }
        |> Style { fontWeight = fontWeightAtLevel level }
```

### 2.4 Fractal Spacing & Layout

```fsharp
/// Fractal spacing system (8px base unit)
module FractalSpacing =

    /// Base unit
    let baseUnit = 8

    /// Spacing at fractal levels
    let spacingAtLevel (level: int) : int =
        match level with
        | 0 -> baseUnit * 8  // 64px - L0: Maximum breathing room
        | 1 -> baseUnit * 4  // 32px - L1: Large spacing
        | 2 -> baseUnit * 2  // 16px - L2: Standard spacing
        | 3 -> baseUnit * 1  // 8px  - L3: Compact spacing
        | 4 -> baseUnit / 2  // 4px  - L4: Minimal spacing

    /// Padding at fractal levels
    let paddingAtLevel (level: int) : Padding =
        let space = spacingAtLevel level
        { top = space; right = space; bottom = space; left = space }

    /// Gap between items at fractal levels
    let gapAtLevel (level: int) : int =
        spacingAtLevel level / 2

    /// Maximum content width at fractal levels
    let maxWidthAtLevel (level: int) (screenWidth: int) : int =
        match level with
        | 0 -> screenWidth * 80 / 100   // L0: 80% of screen
        | 1 -> screenWidth * 90 / 100   // L1: 90% of screen
        | 2 -> screenWidth               // L2: Full width
        | 3 -> screenWidth               // L3: Full width
        | 4 -> screenWidth               // L4: Full width (monospace)
```

---

## Part III: Fractal Data Structures

### 3.1 Fractal State Model

Every piece of state follows the same fractal structure:

```fsharp
/// Fractal state structure - applies to ALL state types
type FractalState<'T> = {
    // L0: Single summary value
    summary: 'T -> float  // Health score, status, etc.

    // L1: Key aggregates
    aggregates: 'T -> Map<string, Aggregate>

    // L2: Entity collection
    entities: 'T -> EntityList

    // L3: Entity details with history
    details: string -> 'T -> EntityDetail

    // L4: Raw data access
    raw: string -> 'T -> JsonValue
}

/// Aggregate type (L1 level data)
type Aggregate = {
    count: int
    sum: float option
    avg: float option
    min: float option
    max: float option
    trend: Trend
}

/// Entity list (L2 level data)
type EntityList = {
    items: EntitySummary list
    total: int
    filtered: int
    page: int
    pageSize: int
}

/// Entity detail (L3 level data)
type EntityDetail = {
    core: EntityCore
    metrics: MetricHistory list
    relationships: Relationship list
    events: Event list
    configuration: Configuration
}

/// Apply fractal structure to system state
let systemStateFractal : FractalState<SystemState> = {
    summary = fun state ->
        state.healthScore

    aggregates = fun state ->
        Map.ofList [
            ("agents", aggregateAgents state.agents)
            ("containers", aggregateContainers state.containers)
            ("alarms", aggregateAlarms state.alarms)
            ("nodes", aggregateNodes state.nodes)
        ]

    entities = fun state ->
        {
            items = state.allEntities |> List.map summarizeEntity
            total = List.length state.allEntities
            filtered = List.length state.allEntities
            page = 1
            pageSize = 50
        }

    details = fun entityId state ->
        state.allEntities
        |> List.find (fun e -> e.id = entityId)
        |> entityToDetail

    raw = fun entityId state ->
        state.allEntities
        |> List.find (fun e -> e.id = entityId)
        |> Json.serialize
}
```

### 3.2 Fractal Event Structure

```fsharp
/// Fractal event structure - same pattern for all events
type FractalEvent<'T> = {
    // Identity
    id: EventId
    timestamp: DateTime
    source: string

    // L0: Event type and severity
    eventType: string
    severity: Severity

    // L1: Summary
    summary: string

    // L2: Key-value data
    data: Map<string, obj>

    // L3: Full payload
    payload: 'T

    // L4: Raw bytes
    raw: byte[]

    // Relationships
    correlationId: CorrelationId option
    causedBy: EventId option
    causes: EventId list
}

/// Create fractal event
let createFractalEvent (payload: 'T) (spec: EventSpec) : FractalEvent<'T> = {
    id = EventId.generate()
    timestamp = DateTime.UtcNow
    source = spec.source
    eventType = spec.eventType
    severity = spec.severity
    summary = spec.summarize payload
    data = spec.extractData payload
    payload = payload
    raw = Json.serializeBytes payload
    correlationId = spec.correlationId
    causedBy = spec.causedBy
    causes = []
}
```

### 3.3 Fractal Message Structure

```fsharp
/// Fractal message structure for Zenoh pub/sub
type FractalMessage<'T> = {
    // Routing
    topic: string
    key: string

    // L0: Message type
    messageType: MessageType

    // L1: Envelope
    envelope: MessageEnvelope

    // L2: Headers
    headers: Map<string, string>

    // L3: Payload
    payload: 'T

    // L4: Raw encoding
    encoding: Encoding
    raw: byte[]
}

/// Message envelope (L1 level)
type MessageEnvelope = {
    id: MessageId
    timestamp: DateTime
    source: NodeId
    destination: NodeId option
    ttl: TimeSpan
    priority: Priority
    correlationId: CorrelationId option
}

/// Fractal Zenoh topic structure
/// c3i/{domain}/{entity}/{level}/{operation}
let buildFractalTopic (domain: string) (entity: string) (level: int) (operation: string) : string =
    sprintf "c3i/%s/%s/L%d/%s" domain entity level operation

/// Examples:
/// c3i/alarms/*/L0/summary        → Alarm count by severity
/// c3i/alarms/*/L1/aggregates     → Alarm statistics
/// c3i/alarms/*/L2/list           → Alarm list
/// c3i/alarms/{id}/L3/detail      → Alarm detail
/// c3i/alarms/{id}/L4/raw         → Raw alarm data
```

---

## Part IV: Fractal Logging (5-Level)

### 4.1 Fractal Log Levels

The logging system uses the same 5-level fractal structure:

```
FRACTAL LOGGING HIERARCHY
═════════════════════════

LEVEL       NAME         PURPOSE                    RETENTION    DESTINATION
═════       ════         ═══════                    ═════════    ═══════════

L0          SPINE        Critical system events     Forever      Immutable + Alert
            (Critical)   Startup, shutdown, errors
                        Safety violations

L1          THORAX       Important state changes    30 days      TimescaleDB
            (Warning)    Configuration changes
                        Health transitions

L2          SEGMENT      Operational events         7 days       ClickHouse
            (Info)       Request lifecycle
                        Agent activities

L3          FIBER        Detailed tracing           24 hours     Local + OTEL
            (Debug)      Method calls
                        State transitions

L4          GOSSAMER     Verbose telemetry          1 hour       Buffer only
            (Trace)      Every data point
                        Performance micro-metrics
```

### 4.2 Fractal Logger Implementation

```fsharp
/// Fractal logger module
module FractalLogger =

    /// Log level enum
    type FractalLogLevel =
        | Spine     // L0: Critical
        | Thorax    // L1: Warning
        | Segment   // L2: Info
        | Fiber     // L3: Debug
        | Gossamer  // L4: Trace

    /// Fractal log entry
    type FractalLogEntry = {
        level: FractalLogLevel
        timestamp: DateTime
        source: string
        message: string
        data: Map<string, obj>
        correlationId: CorrelationId option
        spanId: SpanId option
    }

    /// Log at fractal level
    let log (level: FractalLogLevel) (source: string) (message: string) (data: Map<string, obj>) =
        let entry = {
            level = level
            timestamp = DateTime.UtcNow
            source = source
            message = message
            data = data
            correlationId = CorrelationContext.current()
            spanId = SpanContext.current()
        }

        // Route based on level
        match level with
        | Spine ->
            // L0: Immutable storage + immediate alert
            ImmutableStore.append entry
            AlertChannel.send entry
            Console.write entry

        | Thorax ->
            // L1: TimescaleDB + console
            TimescaleDB.insert entry
            Console.write entry

        | Segment ->
            // L2: ClickHouse + OTEL
            ClickHouse.insert entry
            OTEL.emitLog entry

        | Fiber ->
            // L3: OTEL trace + local file
            OTEL.emitSpan entry
            LocalFile.append entry

        | Gossamer ->
            // L4: Buffer only (for debugging)
            RingBuffer.push entry

    /// Convenience methods
    let spine source message data = log Spine source message data
    let thorax source message data = log Thorax source message data
    let segment source message data = log Segment source message data
    let fiber source message data = log Fiber source message data
    let gossamer source message data = log Gossamer source message data

    /// Query logs at fractal level
    let queryAtLevel (level: FractalLogLevel) (filter: LogFilter) : FractalLogEntry list =
        match level with
        | Spine -> ImmutableStore.query filter
        | Thorax -> TimescaleDB.query filter
        | Segment -> ClickHouse.query filter
        | Fiber -> OTEL.querySpans filter |> List.map spanToLogEntry
        | Gossamer -> RingBuffer.query filter
```

---

## Part V: Fractal Operations

### 5.1 Fractal OODA Cycle

The OODA cycle operates fractally at every level:

```
FRACTAL OODA CYCLES
═══════════════════

SYSTEM LEVEL OODA (1s cycle)
────────────────────────────
Observe: Aggregate all domain health → System health score
Orient:  Correlate cross-domain events → System-wide patterns
Decide:  Prioritize system-level actions → Resource allocation
Act:     Execute system commands → Scaling, failover

    ↓ Contains ↓

DOMAIN LEVEL OODA (500ms cycle)
─────────────────────────────────
Observe: Aggregate entity metrics → Domain health
Orient:  Detect domain-specific patterns → Anomalies
Decide:  Prioritize domain actions → Incident response
Act:     Execute domain commands → Entity operations

    ↓ Contains ↓

ENTITY LEVEL OODA (100ms cycle)
─────────────────────────────────
Observe: Collect entity telemetry → Entity state
Orient:  Analyze entity trends → Predictions
Decide:  Determine entity actions → Thresholds
Act:     Execute entity commands → Configuration

    ↓ Contains ↓

COMPONENT LEVEL OODA (50ms cycle)
────────────────────────────────────
Observe: Read sensor/metric → Current value
Orient:  Compare to baseline → Delta
Decide:  Check threshold → Alert?
Act:     Emit event → Notification
```

### 5.2 Fractal Command Structure

```fsharp
/// Fractal command structure - same pattern at all levels
type FractalCommand<'T> = {
    // Identity
    id: CommandId
    type': string

    // L0: Command intent (single verb)
    intent: CommandIntent

    // L1: Target scope
    scope: CommandScope

    // L2: Parameters
    parameters: Map<string, obj>

    // L3: Full payload
    payload: 'T

    // L4: Validation rules
    validation: ValidationRule list

    // Safety
    twoStepRequired: bool
    guardianApproved: bool
    auditTrail: AuditEntry list
}

/// Command intent (L0 level)
type CommandIntent =
    | Start | Stop | Restart | Scale
    | Create | Update | Delete
    | Enable | Disable
    | Acknowledge | Escalate

/// Command scope (L1 level)
type CommandScope =
    | System
    | Domain of string
    | Entity of EntityId
    | Component of ComponentId

/// Apply fractal command structure
let createFractalCommand (intent: CommandIntent) (scope: CommandScope) (payload: 'T) : FractalCommand<'T> = {
    id = CommandId.generate()
    type' = sprintf "%s_%s" (intent.ToString()) (scopeToString scope)
    intent = intent
    scope = scope
    parameters = extractParameters payload
    payload = payload
    validation = getValidationRules intent scope
    twoStepRequired = requiresTwoStep intent
    guardianApproved = false
    auditTrail = []
}
```

### 5.3 Fractal Agent Architecture

```fsharp
/// Fractal agent structure - same pattern for all agents
type FractalAgent = {
    // Identity
    id: AgentId
    agentType: AgentType
    level: AgentLevel

    // L0: Status
    status: AgentStatus

    // L1: Metrics
    metrics: AgentMetrics

    // L2: Task queue
    taskQueue: Task list

    // L3: Configuration
    config: AgentConfig

    // L4: Internal state
    internalState: AgentState

    // Hierarchy
    supervisor: AgentId option
    subordinates: AgentId list
}

/// Agent levels (fractal hierarchy)
type AgentLevel =
    | Executive     // L0: 1 agent, supreme authority
    | Domain        // L1: 10 agents, domain control
    | Functional    // L2: 15 agents, cross-cutting functions
    | Worker        // L3: 24 agents, task execution
    | Sensor        // L4: Variable, telemetry collection

/// Agent communication follows fractal patterns
module AgentCommunication =

    /// Message routing based on agent level
    let routeMessage (from: FractalAgent) (to': FractalAgent) (message: AgentMessage) =
        match from.level, to'.level with
        // Same level: Peer-to-peer
        | l1, l2 when l1 = l2 ->
            PeerChannel.send message

        // Higher to lower: Command
        | l1, l2 when l1 < l2 ->
            CommandChannel.send message

        // Lower to higher: Report
        | l1, l2 when l1 > l2 ->
            ReportChannel.send message

        | _ -> failwith "Invalid routing"
```

---

## Part VI: Fractal Component Library

### 6.1 Base Fractal Component

```fsharp
/// Base fractal component that all others inherit from
type FractalComponentBase<'T> = {
    // Data
    data: 'T

    // Fractal level renderers
    renderers: FractalRenderers<'T>

    // State
    level: int
    expanded: bool
    selected: bool

    // Behavior
    onLevelChange: int -> unit
    onSelect: 'T -> unit
    onExpand: bool -> unit
}

/// Standard fractal renderers
type FractalRenderers<'T> = {
    token: 'T -> Element       // L0: Single icon/badge
    summary: 'T -> Element     // L1: Summary line
    card: 'T -> Element        // L2: Card view
    detail: 'T -> Element      // L3: Full detail
    raw: 'T -> Element         // L4: Raw data
}

/// Render at current level
let render (component: FractalComponentBase<'T>) : Element =
    match component.level with
    | 0 -> component.renderers.token component.data
    | 1 -> component.renderers.summary component.data
    | 2 -> component.renderers.card component.data
    | 3 -> component.renderers.detail component.data
    | 4 -> component.renderers.raw component.data
    | _ -> component.renderers.card component.data

/// Create fractal component factory
let createFractalComponent<'T> (renderers: FractalRenderers<'T>) (data: 'T) : FractalComponentBase<'T> =
    {
        data = data
        renderers = renderers
        level = 2  // Default to L2 (card view)
        expanded = false
        selected = false
        onLevelChange = fun _ -> ()
        onSelect = fun _ -> ()
        onExpand = fun _ -> ()
    }
```

### 6.2 Fractal Component Catalog

```fsharp
/// All components follow fractal pattern
module FractalComponents =

    // System-level components
    let SystemHealth = createFractalComponent systemHealthRenderers
    let SystemDashboard = createFractalComponent dashboardRenderers

    // Domain-level components
    let AlarmDomain = createFractalComponent alarmDomainRenderers
    let AccessDomain = createFractalComponent accessDomainRenderers
    let VideoDomain = createFractalComponent videoDomainRenderers

    // Entity-level components
    let Alarm = createFractalComponent alarmRenderers
    let Container = createFractalComponent containerRenderers
    let Agent = createFractalComponent agentRenderers
    let Node = createFractalComponent nodeRenderers
    let Device = createFractalComponent deviceRenderers

    // Metric components
    let Metric = createFractalComponent metricRenderers
    let Gauge = createFractalComponent gaugeRenderers
    let Sparkline = createFractalComponent sparklineRenderers

    // Action components
    let Command = createFractalComponent commandRenderers
    let TwoStepButton = createFractalComponent twoStepRenderers

    // Composite components
    let Dashboard = createFractalComponent dashboardRenderers
    let Panel = createFractalComponent panelRenderers
    let Grid = createFractalComponent gridRenderers
```

---

## Part VII: Fractal Navigation

### 7.1 Fractal Navigation Model

```fsharp
/// Navigation follows fractal drill-down pattern
type FractalNavigation = {
    // Current position
    currentLevel: int
    currentScope: string
    currentEntity: string option

    // Path (breadcrumb)
    path: NavigationStep list

    // Available directions
    drillDown: NavigationOption list
    drillUp: NavigationOption option
    siblings: NavigationOption list
}

/// Navigation step in path
type NavigationStep = {
    level: int
    scope: string
    entity: string option
    label: string
}

/// Navigation always follows L0 → L1 → L2 → L3 → L4 pattern
let navigate (nav: FractalNavigation) (action: NavigationAction) : FractalNavigation =
    match action with
    | DrillDown entityId ->
        // Move deeper: L0 → L1 → L2 → L3 → L4
        let newLevel = min 4 (nav.currentLevel + 1)
        { nav with
            currentLevel = newLevel
            currentEntity = Some entityId
            path = nav.path @ [{ level = newLevel; scope = nav.currentScope; entity = Some entityId; label = entityId }]
        }

    | DrillUp ->
        // Move shallower: L4 → L3 → L2 → L1 → L0
        let newLevel = max 0 (nav.currentLevel - 1)
        { nav with
            currentLevel = newLevel
            currentEntity = if newLevel <= 1 then None else nav.currentEntity
            path = nav.path |> List.take (max 0 (List.length nav.path - 1))
        }

    | JumpToLevel level ->
        // Direct jump to level
        { nav with
            currentLevel = level
            path = nav.path |> List.filter (fun s -> s.level <= level)
        }

    | SwitchScope scope ->
        // Change scope at same level
        { nav with
            currentScope = scope
            currentEntity = None
            path = [{ level = nav.currentLevel; scope = scope; entity = None; label = scope }]
        }
```

### 7.2 Fractal Breadcrumb

```fsharp
/// Fractal breadcrumb component
let FractalBreadcrumb (nav: FractalNavigation) =
    HBox [
        // Level indicator
        Badge (sprintf "L%d" nav.currentLevel) { variant = Filled; color = levelColor nav.currentLevel }
        Spacer 8

        // Path items (fractal drill-down path)
        for (i, step) in List.indexed nav.path do
            if i > 0 then
                Text " › " { fg = Gray }

            HBox [
                LevelDot step.level
                Link step.label (NavigateToStep step)
            ]

        // Drill-up indicator
        if nav.currentLevel > 0 then
            Spacer 8
            IconButton ChevronUp DrillUp { tooltip = sprintf "Back to L%d" (nav.currentLevel - 1) }
    ]
```

---

## Summary: Fractal Principle Application

| Dimension | L0 | L1 | L2 | L3 | L4 |
|-----------|----|----|----|----|-----|
| **Visual** | Token | Summary | Card | Detail | Raw |
| **Data** | Score | Aggregates | List | Full | JSON |
| **Logging** | Spine | Thorax | Segment | Fiber | Gossamer |
| **OODA** | System | Domain | Entity | Component | Sensor |
| **Agents** | Executive | Domain | Functional | Worker | Sensor |
| **Commands** | Intent | Scope | Parameters | Payload | Validation |
| **Navigation** | System | Domain | Entity | Detail | Raw |
| **Typography** | 48px | 24px | 16px | 14px | 12px |
| **Spacing** | 64px | 32px | 16px | 8px | 4px |
| **Color** | 100% | 85% | 70% | 55% | 40% |
| **Retention** | Forever | 30d | 7d | 24h | 1h |

The fractal principle ensures:
- **Consistency**: Same patterns everywhere
- **Learnability**: Learn once, apply everywhere
- **Scalability**: Works at any zoom level
- **Maintainability**: Patterns replicate, don't reinvent

---

*Document Version: 1.0.0*
*STAMP Compliance: SC-FRAC-001 through SC-FRAC-015*
*Framework: SOPv5.11 + PRAJNA + Fractal Design System*
