namespace Cepaf.Cockpit

open System

// =============================================================================
// PRAJNA C3I Mesh Cockpit - Domain Types
// =============================================================================
// Ported from: lib/indrajaal/cockpit/prajna/domain.ex
// Compliance: NASA-STD-3000, NUREG-0700, MIL-STD-1472H
// =============================================================================

module Domain =

    // -------------------------------------------------------------------------
    // TYPE ALIASES (Backward Compatibility)
    // -------------------------------------------------------------------------
    type NodeId = string
    type ZoneId = string
    type AlarmId = string
    type CommandId = string

    // -------------------------------------------------------------------------
    // TREND VECTORS
    // -------------------------------------------------------------------------

    type Trend =
        | Rising
        | RisingFast
        | Falling
        | FallingFast
        | Stable

        member this.Icon =
            match this with
            | Rising -> "↑"
            | RisingFast -> "↑↑"
            | Falling -> "↓"
            | FallingFast -> "↓↓"
            | Stable -> "→"

    // -------------------------------------------------------------------------
    // CONNECTION STATUS
    // -------------------------------------------------------------------------

    type ConnectionStatus =
        | Connected
        | Stale
        | Degraded
        | Disconnected

        member this.Icon =
            match this with
            | Connected -> "●"
            | Stale -> "◐"
            | Degraded -> "◐"
            | Disconnected -> "○"

    // Alias for backward compatibility if needed, though ConnectionStatus is better
    type ConnStatus = ConnectionStatus

    // -------------------------------------------------------------------------
    // ALARM LEVELS
    // -------------------------------------------------------------------------

    type AlarmLevel =
        | Normal
        | Advisory
        | Caution
        | Warning
        | Critical

        member this.Icon =
            match this with
            | Normal -> "·"
            | Advisory -> "ℹ"
            | Caution -> "⚠"
            | Warning -> "⛔"
            | Critical -> "☢"

        member this.Abbrev =
            match this with
            | Critical -> "CRIT"
            | Warning -> "WARN"
            | Caution -> "CAUT"
            | Advisory -> "ADVS"
            | Normal -> "NORM"

    // -------------------------------------------------------------------------
    // COMMAND STATE
    // -------------------------------------------------------------------------

    type CommandState =
        | Idle
        | Armed
        | Executing
        | Acknowledged
        | Failed

        member this.Icon =
            match this with
            | Idle -> "○"
            | Armed -> "◎"
            | Executing -> "●"
            | Acknowledged -> "✓"
            | Failed -> "✗"

    // -------------------------------------------------------------------------
    // NODE ROLE
    // -------------------------------------------------------------------------

    type NodeRole =
        | Supervisor
        | Controller
        | Worker
        | Observer
        | Gateway

    // -------------------------------------------------------------------------
    // AI INSIGHT TYPES
    // -------------------------------------------------------------------------

    type InsightType =
        | Anomaly
        | Prediction
        | Recommendation
        | Correlation
        | RootCause
        | Summary

    // -------------------------------------------------------------------------
    // VIEW MODES
    // -------------------------------------------------------------------------

    type ViewMode =
        | Overview
        | Mesh
        | Alarms
        | Commands
        | AI
        | Dashboard
        | NodeDetail
        | AlarmCenter
        | Topology
        | Timeline
        | AiAssistant
        | Federation
        | Economics

    // -------------------------------------------------------------------------
    // SMART METRIC
    // -------------------------------------------------------------------------

    // Renamed back to Thresholds to match usage, but kept generic signature for compat
    // though we primarily use float.
    type Thresholds<'T> = {
        AdvisoryLow: 'T option
        AdvisoryHigh: 'T option
        CautionLow: 'T option
        CautionHigh: 'T option
        WarningLow: 'T option
        WarningHigh: 'T option
    }

    type MetricThresholds = Thresholds<float>

    type SmartMetric = {
        Value: float
        PreviousValue: float option
        LastUpdated: DateTime
        Trend: Trend
        Level: AlarmLevel
        Thresholds: MetricThresholds option
        Unit: string
        Label: string
        Sparkline: float list
    } with
        static member Create(label: string, unit: string, value: float) = {
            Value = value
            PreviousValue = None
            LastUpdated = DateTime.UtcNow
            Trend = Stable
            Level = Normal
            Thresholds = None
            Unit = unit
            Label = label
            Sparkline = []
        }

        static member EvaluateLevel(value: float, thresholds: MetricThresholds option) =
            match thresholds with
            | None -> Normal
            | Some t ->
                if t.WarningHigh.IsSome && value >= t.WarningHigh.Value then Warning
                elif t.WarningLow.IsSome && value <= t.WarningLow.Value then Warning
                elif t.CautionHigh.IsSome && value >= t.CautionHigh.Value then Caution
                elif t.CautionLow.IsSome && value <= t.CautionLow.Value then Caution
                elif t.AdvisoryHigh.IsSome && value >= t.AdvisoryHigh.Value then Advisory
                elif t.AdvisoryLow.IsSome && value <= t.AdvisoryLow.Value then Advisory
                else Normal

    // -------------------------------------------------------------------------
    // MESH NODE
    // -------------------------------------------------------------------------

    type MeshNode = {
        Id: NodeId
        Name: string
        Zone: ZoneId
        Role: NodeRole
        Status: ConnectionStatus
        Cpu: SmartMetric
        Memory: SmartMetric
        Battery: SmartMetric option
        NetworkLatency: SmartMetric
        Capabilities: string list
        HealthScore: SmartMetric
        Location: (float * float) option
        AiInsight: string option
        AiInsightUpdatedAt: DateTime option
    }

    // -------------------------------------------------------------------------
    // ALARM
    // -------------------------------------------------------------------------

    type Alarm = {
        Id: AlarmId
        NodeId: NodeId
        Level: AlarmLevel
        Category: string
        Message: string
        Details: string option
        OccurredAt: DateTime
        AcknowledgedAt: DateTime option
        AcknowledgedBy: string option
        AutoClearable: bool
    }

    // -------------------------------------------------------------------------
    // COMMANDS
    // -------------------------------------------------------------------------

    type MeshCommand =
        | PowerOff
        | PowerOn
        | Restart
        | Hibernate
        | IsolateNetwork
        | ResumeNetwork
        | SetLoadBalancer of int
        | ForceHealthCheck
        | ClearAlarms
        | Custom of string * byte[]

    type CommandRecord = {
        Id: CommandId
        TargetNodeId: NodeId
        Command: MeshCommand
        State: CommandState
        ArmedAt: DateTime option
        ExecutedAt: DateTime option
        AcknowledgedAt: DateTime option
        ErrorMessage: string option
        RequiresConfirmation: bool
    }

    // -------------------------------------------------------------------------
    // AI INSIGHT
    // -------------------------------------------------------------------------

    type AiInsight = {
        Id: string
        Type: InsightType
        Level: AlarmLevel
        Title: string
        Description: string
        RelatedNodes: NodeId list
        RelatedAlarms: AlarmId list
        Confidence: float
        GeneratedAt: DateTime
        ExpiresAt: DateTime option
        ActionItems: string list
    }

    // -------------------------------------------------------------------------
    // AUTOMATION STATE
    // -------------------------------------------------------------------------

    type AutomationState =
        | NormalOps
        | AutoHealing
        | AutoScaling
        | ManualOverride
        | DegradedMode
        | EmergencyStop
        | Executing

        member this.Label =
            match this with
            | NormalOps -> "NOMINAL"
            | AutoHealing -> "AUTO-HEALING"
            | AutoScaling -> "AUTO-SCALING"
            | ManualOverride -> "MANUAL"
            | DegradedMode -> "DEGRADED"
            | EmergencyStop -> "EMERGENCY STOP"
            | Executing -> "EXECUTING"

    // -------------------------------------------------------------------------
    // ECONOMIC STATE (Phase 8 - L10 Singularity)
    // -------------------------------------------------------------------------

    type ResourceCredit = {
        HolonId: string
        Balance: float
        TotalConsumed: float
        LastMeteredAt: DateTime
    }

    type EconomicLedger = {
        TotalSwarmEnergy: float
        SystemCredits: float
        EfficiencyScore: float
        Ledger: Map<string, ResourceCredit>
    }

    // -------------------------------------------------------------------------
    // FEDERATION STATE (Phase 7 - L7 Federation)
    // -------------------------------------------------------------------------

    type FederationMemberInfo = {
        Id: string
        Name: string
        Status: string
        TrustScore: float
        LastSeen: DateTime
        Version: string
        Capabilities: string list
    }

    type FederationHealth = {
        LocalHolonId: string
        TotalMembers: int
        ActiveMembers: int
        AverageTrust: float
        ProtocolVersion: string
        Members: Map<string, FederationMemberInfo>
    }

    // -------------------------------------------------------------------------
    // GIT EVOLUTION STATE (Phase 10 - Singularity Feed)
    // -------------------------------------------------------------------------

    type GitCommit = {
        Hash: string
        Message: string
        Author: string
        Timestamp: DateTime
    }

    // -------------------------------------------------------------------------
    // COCKPIT STATE
    // -------------------------------------------------------------------------

    type CockpitState = {
        OperatorId: string
        SessionId: string
        StartedAt: DateTime
        Nodes: Map<NodeId, MeshNode>
        Zones: Map<ZoneId, obj> // Placeholder for Zone details
        Alarms: Map<AlarmId, Alarm>
        PendingCommands: Map<CommandId, CommandRecord>
        CommandHistory: CommandRecord list
        Insights: AiInsight list
        AiEnabled: bool
        LastAiUpdate: DateTime option
        CurrentView: ViewMode
        SelectedNodeId: NodeId option
        SelectedZoneId: ZoneId option
        FilterLevel: AlarmLevel option
        MessagesReceived: int
        LastMessageAt: DateTime option
        UiRefreshRate: int
        MonitorOnly: bool
        SimulationMode: bool
        ShowHelp: bool
        Federation: FederationHealth option
        Economics: EconomicLedger option
        RecentCommits: GitCommit list
    }

    // -------------------------------------------------------------------------
    // LOGIC
    // -------------------------------------------------------------------------

    let computeTrend (oldValue: float) (newValue: float) =
        let diff = newValue - oldValue
        let percentChange = if oldValue <> 0.0 then abs(diff / oldValue) * 100.0 else 0.0

        if diff > 0.0 && percentChange > 10.0 then RisingFast
        elif diff > 0.0 then Rising
        elif diff < 0.0 && percentChange > 10.0 then FallingFast
        elif diff < 0.0 then Falling
        else Stable

    let updateMetric (metric: SmartMetric) (newValue: float) =
        let trend = computeTrend metric.Value newValue
        let sparkline = (newValue :: metric.Sparkline) |> List.truncate 60
        let level = SmartMetric.EvaluateLevel(newValue, metric.Thresholds)

        { metric with
            Value = newValue
            PreviousValue = Some metric.Value
            LastUpdated = DateTime.UtcNow
            Trend = trend
            Level = level
            Sparkline = sparkline
        }

    let isStale (metric: SmartMetric) (timeoutSeconds: int) =
        (DateTime.UtcNow - metric.LastUpdated).TotalSeconds > float timeoutSeconds

    let isCriticalCommand (cmd: MeshCommand) =
        match cmd with
        | PowerOff | Restart | IsolateNetwork | Hibernate -> true
        | _ -> false

    let generateId () =
        Guid.NewGuid().ToString("N").Substring(0, 8)

    let createCockpitState (operatorId: string) = {
        OperatorId = operatorId
        SessionId = generateId()
        StartedAt = DateTime.UtcNow
        Nodes = Map.empty
        Zones = Map.empty
        Alarms = Map.empty
        PendingCommands = Map.empty
        CommandHistory = []
        Insights = []
        AiEnabled = true
        LastAiUpdate = None
        CurrentView = Overview
        SelectedNodeId = None
        SelectedZoneId = None
        FilterLevel = None
        MessagesReceived = 0
        LastMessageAt = None
        UiRefreshRate = 1000
        MonitorOnly = false
        SimulationMode = false
        ShowHelp = false
        Federation = None
        Economics = None
        RecentCommits = []
    }

    // -------------------------------------------------------------------------
    // DISCRIMINABLE NAMING
    // -------------------------------------------------------------------------

    let discriminableName (type': string) (zone: string) (indexOrId: obj) =
        let idStr =
            match indexOrId with
            | :? int as i -> i.ToString().PadLeft(2, '0')
            | :? string as s -> s
            | _ -> indexOrId.ToString()
        sprintf "%s.%s-%s" zone type' idStr

    let typeAbbreviation (t: string) =
        match t.ToLower() with
        | "app" -> "A"
        | "database" | "db" -> "D"
        | "observability" | "obs" -> "O"
        | "sensor" -> "S"
        | "camera" -> "C"
        | "gateway" -> "G"
        | "controller" -> "CTL"
        | "worker" -> "W"
        | _ -> t.Substring(0, 1).ToUpper()

    let shortName (type': string) (zone: string) (index: int) =
        let zoneAbbrev = if zone.Length >= 3 then zone.Substring(0, 3).ToUpper() else zone.ToUpper()
        let typeAbbrev = typeAbbreviation type'
        sprintf "%s:%s%d" zoneAbbrev typeAbbrev index

    let discriminableAlarmId (level: AlarmLevel) (source: string) =
        let timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds() % 10000L
        sprintf "ALM-%s-%s-%d" level.Abbrev source timestamp

    // -------------------------------------------------------------------------
    // PHASE 6: IMMUNE SYSTEM - CONTAINER HEALTH EVENTS (SC-IMMUNE-001)
    // -------------------------------------------------------------------------

    /// Container health event types for the healing reflex
    type ContainerHealthEvent =
        | ContainerStarted of containerId: string * timestamp: DateTime
        | ContainerStopped of containerId: string * timestamp: DateTime * exitCode: int
        | ContainerDied of containerId: string * timestamp: DateTime * reason: string
        | ContainerHealthy of containerId: string * timestamp: DateTime
        | ContainerUnhealthy of containerId: string * timestamp: DateTime * checkOutput: string
        | ContainerRestarted of containerId: string * timestamp: DateTime * attemptNumber: int

    /// High-Availability set configuration
    type HaConfig = {
        /// Containers that should be auto-restarted on failure
        HaSet: Set<string>
        /// Maximum restart attempts before giving up
        MaxRestartAttempts: int
        /// Cooldown period between restarts in milliseconds
        RestartCooldownMs: int
        /// Whether healing is enabled
        HealingEnabled: bool
    }

    /// Default HA configuration for production
    let defaultHaConfig = {
        HaSet = Set.ofList [
            "indrajaal-db-prod"
            "indrajaal-ex-app-1"
            "indrajaal-obs-prod"
            "zenoh-router"
        ]
        MaxRestartAttempts = 3
        RestartCooldownMs = 5000
        HealingEnabled = true
    }

    /// Tracks restart attempts per container for healing reflex
    type RestartTracker = {
        ContainerId: string
        AttemptCount: int
        LastAttemptAt: DateTime
        FailureReasons: string list
    }

    /// Healing state maintained by the orchestrator
    type HealingState = {
        Config: HaConfig
        RestartTrackers: Map<string, RestartTracker>
        AutomationMode: AutomationState
        LastHealingAction: DateTime option
    }

    let createHealingState config = {
        Config = config
        RestartTrackers = Map.empty
        AutomationMode = NormalOps
        LastHealingAction = None
    }

    // -------------------------------------------------------------------------
    // PHASE 6: IMMUNE SYSTEM - FAILURE PATTERN TRACKING (SC-IMMUNE-004)
    // -------------------------------------------------------------------------

    /// Failure pattern for antibody generation
    type FailurePattern = {
        PatternId: Guid
        SourceComponent: string
        FailureType: string
        OccurrenceCount: int
        FirstSeen: DateTime
        LastSeen: DateTime
        Signatures: string list
    }

    /// Create a failure pattern from an event
    let createFailurePattern source failureType signature = {
        PatternId = Guid.NewGuid()
        SourceComponent = source
        FailureType = failureType
        OccurrenceCount = 1
        FirstSeen = DateTime.UtcNow
        LastSeen = DateTime.UtcNow
        Signatures = [signature]
    }

    /// Threshold for triggering antibody synthesis
    let antibodySynthesisThreshold = 3

    // -------------------------------------------------------------------------
    // TELEMETRY EVENTS
    // -------------------------------------------------------------------------

    type TelemetryEvent =
        | MetricLogged of metricName: string * value: float
        | AlarmRaised of alarm: Alarm
        | CommandExecuted of command: CommandRecord
        | AnomalyDetected of description: string * severity: string
        | InsightGenerated of insight: AiInsight
        | ContainerHealth of ContainerHealthEvent
        | HealingTriggered of containerId: string * action: string
        | AntibodySynthesized of patternId: string * targetPattern: string