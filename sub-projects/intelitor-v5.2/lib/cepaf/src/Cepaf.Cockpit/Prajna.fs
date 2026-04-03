namespace Cepaf.Cockpit

open System
// open Cepaf.Core.Units  // SC-FSH-004: Units of Measure for type safety
// open Cepaf.Core.Composition  // SC-FSH-010: Function composition
// open Cepaf.Core.ActivePatterns  // SC-FSH-003: Active Patterns

/// Prajna Cockpit - Bio-Inspired Safety-Critical TUI
/// Full implementation with Bio, Immune, and Neuro layers
/// STAMP: SC-PRAJNA-001 to SC-PRAJNA-007
module Prajna =

    // ═══════════════════════════════════════════════════════════════════════════
    // SHARED TYPES - Core Prajna Types
    // ═══════════════════════════════════════════════════════════════════════════

    /// Holon identifier
    type HolonId = HolonId of string

    /// Holon type classification
    type HolonType =
        | Agent of string
        | Worker of string
        | Service of string
        | Container of string

    /// Vital signs for health monitoring
    type VitalSigns = {
        HealthIndex: float      // 0.0 to 1.0
        StressIndex: float      // 0.0 to 1.0
        LastUpdate: DateTimeOffset
    }

    /// Create default vital signs
    let defaultVitals () = {
        HealthIndex = 1.0
        StressIndex = 0.0
        LastUpdate = DateTimeOffset.UtcNow
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BIO LAYER - Life-Like Structures
    // ═══════════════════════════════════════════════════════════════════════════

    module Bio =
        /// Membrane permeability levels
        type Permeability =
            | Closed      // No messages pass
            | Selective   // Only approved messages
            | Open        // All messages pass
            | Emergency   // Only emergency messages

        /// Membrane configuration
        type MembraneConfig = {
            Permeability: Permeability
            AllowedTypes: Set<string>
            BlockedSources: Set<string>
            RateLimit: int  // messages per second
        }

        /// Create default membrane config
        let defaultMembraneConfig = {
            Permeability = Selective
            AllowedTypes = Set.ofList ["status"; "health"; "alert"; "command"]
            BlockedSources = Set.empty
            RateLimit = 100
        }

        /// Check if message can pass through membrane
        let canPass (config: MembraneConfig) (msgType: string) (source: string) : bool =
            match config.Permeability with
            | Closed -> false
            | Emergency -> msgType = "emergency"
            | Open -> not (Set.contains source config.BlockedSources)
            | Selective ->
                Set.contains msgType config.AllowedTypes &&
                not (Set.contains source config.BlockedSources)

        /// Holon state machine states
        type HolonState =
            | Dormant     // Not yet activated
            | Awakening   // Starting up
            | Active      // Fully operational
            | Stressed    // Under load
            | Healing     // Recovering
            | Apoptotic   // Shutting down

        /// Holon with full lifecycle
        type HolonInstance = {
            Id: HolonId
            Type: HolonType
            State: HolonState
            Vitals: VitalSigns
            Membrane: MembraneConfig
            Children: HolonId list
            Parent: HolonId option
            CreatedAt: DateTimeOffset
            LastHeartbeat: DateTimeOffset
        }

        /// Create a new holon instance
        let createHolon (id: HolonId) (holonType: HolonType) (parent: HolonId option) : HolonInstance =
            {
                Id = id
                Type = holonType
                State = Dormant
                Vitals = defaultVitals()
                Membrane = defaultMembraneConfig
                Children = []
                Parent = parent
                CreatedAt = DateTimeOffset.UtcNow
                LastHeartbeat = DateTimeOffset.UtcNow
            }

        /// Transition holon to new state
        let transition (holon: HolonInstance) (newState: HolonState) : HolonInstance =
            { holon with
                State = newState
                LastHeartbeat = DateTimeOffset.UtcNow }

        /// Check if holon is healthy
        let isHealthy (holon: HolonInstance) : bool =
            match holon.State with
            | Apoptotic | Dormant -> false
            | _ -> holon.Vitals.HealthIndex > 0.5 && holon.Vitals.StressIndex < 0.8

    // ═══════════════════════════════════════════════════════════════════════════
    // IMMUNE LAYER - Threat Detection & Response
    // ═══════════════════════════════════════════════════════════════════════════

    module Immune =
        /// Threat level
        type ThreatLevel =
            | Critical
            | High
            | Medium
            | Low
            | Safe

        /// Threat type
        type ThreatType =
            | Intrusion
            | Malware
            | DataExfiltration
            | DenialOfService
            | Anomaly

        /// Threat definition
        type Threat = {
            Id: Guid
            Type: ThreatType
            Level: ThreatLevel
            Source: string
            Target: string
            DetectedAt: DateTimeOffset
            Description: string
        }

        /// Antibody action types
        type AntibodyAction =
            | Ignore
            | Log
            | Alert
            | Isolate
            | Terminate
            | Escalate

        /// Antibody response
        type AntibodyResponse = {
            ThreatId: Guid
            Action: AntibodyAction
            Reason: string
            ExecutedAt: DateTimeOffset
        }

        /// Detect threat level from vitals
        let assessThreat (vitals: VitalSigns) : ThreatLevel =
            let healthScore = vitals.HealthIndex
            let stressScore = vitals.StressIndex

            if healthScore < 0.1 || stressScore > 0.95 then Critical
            elif healthScore < 0.3 || stressScore > 0.8 then High
            elif healthScore < 0.5 || stressScore > 0.6 then Medium
            elif healthScore < 0.7 || stressScore > 0.4 then Low
            else Safe

        /// Recommend action based on threat level
        let recommendAction (level: ThreatLevel) : AntibodyAction =
            match level with
            | Safe -> Ignore
            | Low -> Log
            | Medium -> Alert
            | High -> Isolate
            | Critical -> Escalate

        /// Create a threat from anomaly
        let createThreat (threatType: ThreatType) (source: string) (target: string) (description: string) : Threat =
            {
                Id = Guid.NewGuid()
                Type = threatType
                Level = High
                Source = source
                Target = target
                DetectedAt = DateTimeOffset.UtcNow
                Description = description
            }

        /// Create antibody response
        let respond (threat: Threat) (action: AntibodyAction) (reason: string) : AntibodyResponse =
            {
                ThreatId = threat.Id
                Action = action
                Reason = reason
                ExecutedAt = DateTimeOffset.UtcNow
            }

        /// MARA - Modular Adaptive Response Architecture
        module MARA =
            /// Response strategy
            type Strategy =
                | Defensive  // Protect and isolate
                | Offensive  // Actively counter
                | Adaptive   // Learn and adjust
                | Passive    // Monitor only

            /// MARA recommendation
            type Recommendation = {
                Strategy: Strategy
                Actions: AntibodyAction list
                Confidence: float
                Rationale: string
            }

            /// Generate recommendation based on threat history
            let recommend (threats: Threat list) : Recommendation =
                let criticalCount = threats |> List.filter (fun t -> t.Level = Critical) |> List.length
                let highCount = threats |> List.filter (fun t -> t.Level = High) |> List.length

                if criticalCount > 0 then
                    {
                        Strategy = Defensive
                        Actions = [Escalate; Isolate; Alert]
                        Confidence = 0.95
                        Rationale = sprintf "Critical threats detected: %d" criticalCount
                    }
                elif highCount > 2 then
                    {
                        Strategy = Adaptive
                        Actions = [Alert; Isolate]
                        Confidence = 0.8
                        Rationale = sprintf "Multiple high threats: %d" highCount
                    }
                else
                    {
                        Strategy = Passive
                        Actions = [Log]
                        Confidence = 0.6
                        Rationale = "Normal threat levels"
                    }

    // ═══════════════════════════════════════════════════════════════════════════
    // NEURO LAYER - Message Routing & Coordination
    // ═══════════════════════════════════════════════════════════════════════════

    module Neuro =
        /// Message priority
        type Priority =
            | Background
            | Normal
            | High
            | Urgent
            | Emergency

        /// Spine message
        type SpineMessage = {
            Id: Guid
            Priority: Priority
            Source: string
            Destination: string
            Payload: string
            Timestamp: DateTimeOffset
            TTL: int  // Time to live in hops
        }

        /// Routing decision
        type RoutingDecision =
            | Deliver of string
            | Forward of string
            | Drop of string
            | Broadcast

        /// Create spine message
        let createMessage (priority: Priority) (source: string) (dest: string) (payload: string) : SpineMessage =
            {
                Id = Guid.NewGuid()
                Priority = priority
                Source = source
                Destination = dest
                Payload = payload
                Timestamp = DateTimeOffset.UtcNow
                TTL = 10
            }

        /// Route message based on priority and destination
        let route (msg: SpineMessage) (localNodes: string list) : RoutingDecision =
            if msg.TTL <= 0 then
                Drop "TTL expired"
            elif msg.Destination = "*" then
                Broadcast
            elif List.contains msg.Destination localNodes then
                Deliver msg.Destination
            else
                Forward msg.Destination

        /// Decrement TTL
        let decrementTTL (msg: SpineMessage) : SpineMessage =
            { msg with TTL = msg.TTL - 1 }

        /// Check if message is expired
        let isExpired (msg: SpineMessage) : bool =
            msg.TTL <= 0 ||
            (DateTimeOffset.UtcNow - msg.Timestamp).TotalMinutes > 5.0

    // ═══════════════════════════════════════════════════════════════════════════
    // DARK COCKPIT - Minimal UI with Attention-Based Alerts
    // ═══════════════════════════════════════════════════════════════════════════

    module DarkCockpit =
        /// Alert severity for display
        type AlertSeverity =
            | Info
            | Warning
            | Error
            | Critical

        /// Alert for dark cockpit display
        type Alert = {
            Id: Guid
            Severity: AlertSeverity
            Title: string
            Message: string
            Source: string
            Timestamp: DateTimeOffset
            Acknowledged: bool
        }

        /// Cockpit mode
        type CockpitMode =
            | Dark      // Minimal - only critical alerts
            | Dim       // Low activity display
            | Normal    // Standard operation
            | Bright    // Full visibility
            | Emergency // All alerts prominent

        /// Cockpit state
        type CockpitState = {
            Mode: CockpitMode
            Alerts: Alert list
            LastModeChange: DateTimeOffset
            ActiveHolons: int
            HealthySystems: int
            TotalSystems: int
            ShowHelp: bool
        }

        /// Create initial cockpit state
        let initialState () = {
            Mode = Dark
            Alerts = []
            LastModeChange = DateTimeOffset.UtcNow
            ActiveHolons = 0
            HealthySystems = 0
            TotalSystems = 0
            ShowHelp = false
        }

        /// Toggle help display
        let toggleHelp (state: CockpitState) : CockpitState =
            { state with ShowHelp = not state.ShowHelp }

        /// Add alert to cockpit
        let addAlert (state: CockpitState) (alert: Alert) : CockpitState =
            let newAlerts = alert :: state.Alerts |> List.take (min 100 (List.length state.Alerts + 1))
            { state with Alerts = newAlerts }

        /// Determine cockpit mode based on system health
        let determineMode (healthRatio: float) (criticalAlerts: int) : CockpitMode =
            if criticalAlerts > 0 then Emergency
            elif healthRatio < 0.3 then Bright
            elif healthRatio < 0.6 then Normal
            elif healthRatio < 0.9 then Dim
            else Dark

        /// Update cockpit state
        let update (state: CockpitState) (activeHolons: int) (healthyCount: int) (totalCount: int) : CockpitState =
            let healthRatio = if totalCount > 0 then float healthyCount / float totalCount else 1.0
            let criticalCount = state.Alerts |> List.filter (fun a -> a.Severity = Critical && not a.Acknowledged) |> List.length
            let newMode = determineMode healthRatio criticalCount

            { state with
                Mode = newMode
                ActiveHolons = activeHolons
                HealthySystems = healthyCount
                TotalSystems = totalCount
                LastModeChange = if newMode <> state.Mode then DateTimeOffset.UtcNow else state.LastModeChange
            }

        /// Acknowledge alert
        let acknowledgeAlert (state: CockpitState) (alertId: Guid) : CockpitState =
            let newAlerts =
                state.Alerts
                |> List.map (fun a -> if a.Id = alertId then { a with Acknowledged = true } else a)
            { state with Alerts = newAlerts }

        /// Get unacknowledged alerts by severity
        let getUnacknowledgedBySeverity (state: CockpitState) (severity: AlertSeverity) : Alert list =
            state.Alerts |> List.filter (fun a -> a.Severity = severity && not a.Acknowledged)

    // ═══════════════════════════════════════════════════════════════════════════
    // CIRCUIT BREAKER - Safety Cutoffs
    // ═══════════════════════════════════════════════════════════════════════════

    module CircuitBreaker =
        /// Circuit breaker states
        type BreakerState =
            | Closed   // Normal operation
            | Open     // Tripped - blocking
            | HalfOpen // Testing recovery

        /// Circuit breaker
        type Breaker = {
            Name: string
            State: BreakerState
            FailureCount: int
            SuccessCount: int
            LastStateChange: DateTimeOffset
            Threshold: int
            ResetTimeout: TimeSpan
        }

        /// Create a new breaker
        let create (name: string) (threshold: int) (resetTimeout: TimeSpan) : Breaker =
            {
                Name = name
                State = Closed
                FailureCount = 0
                SuccessCount = 0
                LastStateChange = DateTimeOffset.UtcNow
                Threshold = threshold
                ResetTimeout = resetTimeout
            }

        /// Record failure
        let recordFailure (breaker: Breaker) : Breaker =
            let newFailureCount = breaker.FailureCount + 1
            if newFailureCount >= breaker.Threshold then
                { breaker with
                    State = Open
                    FailureCount = newFailureCount
                    LastStateChange = DateTimeOffset.UtcNow }
            else
                { breaker with FailureCount = newFailureCount }

        /// Record success
        let recordSuccess (breaker: Breaker) : Breaker =
            match breaker.State with
            | HalfOpen ->
                { breaker with
                    State = Closed
                    FailureCount = 0
                    SuccessCount = breaker.SuccessCount + 1
                    LastStateChange = DateTimeOffset.UtcNow }
            | _ ->
                { breaker with SuccessCount = breaker.SuccessCount + 1 }

        /// Check if breaker should attempt reset
        let shouldAttemptReset (breaker: Breaker) : bool =
            match breaker.State with
            | Open ->
                (DateTimeOffset.UtcNow - breaker.LastStateChange) >= breaker.ResetTimeout
            | _ -> false

        /// Attempt to transition to half-open
        let attemptHalfOpen (breaker: Breaker) : Breaker =
            if shouldAttemptReset breaker then
                { breaker with
                    State = HalfOpen
                    LastStateChange = DateTimeOffset.UtcNow }
            else
                breaker

        /// Check if operation is allowed
        let isAllowed (breaker: Breaker) : bool =
            match breaker.State with
            | Closed -> true
            | HalfOpen -> true  // Allow one test request
            | Open -> false

    // ═══════════════════════════════════════════════════════════════════════════
    // SMART METRICS - Intelligent Monitoring
    // ═══════════════════════════════════════════════════════════════════════════

    module SmartMetrics =
        /// Metric type
        type MetricType =
            | Counter
            | Gauge
            | Histogram
            | Summary

        /// Metric value
        type MetricValue = {
            Name: string
            Type: MetricType
            Value: float
            Labels: Map<string, string>
            Timestamp: DateTimeOffset
        }

        /// Anomaly detection result
        type AnomalyResult = {
            MetricName: string
            IsAnomaly: bool
            ZScore: float
            Threshold: float
            Message: string
        }

        /// Create metric value
        let createMetric (name: string) (metricType: MetricType) (value: float) (labels: Map<string, string>) : MetricValue =
            {
                Name = name
                Type = metricType
                Value = value
                Labels = labels
                Timestamp = DateTimeOffset.UtcNow
            }

        /// Simple z-score anomaly detection
        let detectAnomaly (values: float list) (current: float) (threshold: float) : AnomalyResult =
            if List.length values < 2 then
                { MetricName = ""; IsAnomaly = false; ZScore = 0.0; Threshold = threshold; Message = "Insufficient data" }
            else
                let mean = List.average values
                let variance = values |> List.map (fun x -> (x - mean) ** 2.0) |> List.average
                let stdDev = sqrt variance
                let zScore = if stdDev > 0.0 then (current - mean) / stdDev else 0.0
                let isAnomaly = abs zScore > threshold
                {
                    MetricName = ""
                    IsAnomaly = isAnomaly
                    ZScore = zScore
                    Threshold = threshold
                    Message = if isAnomaly then sprintf "Z-score %.2f exceeds threshold" zScore else "Normal"
                }

        /// Moving average calculation
        let movingAverage (window: int) (values: float list) : float =
            values
            |> List.rev
            |> List.take (min window (List.length values))
            |> List.average

    // ═══════════════════════════════════════════════════════════════════════════
    // ORCHESTRATOR - Command Coordination
    // ═══════════════════════════════════════════════════════════════════════════

    module Orchestrator =
        /// Command types
        type CommandType =
            | Status
            | Start
            | Stop
            | Restart
            | Scale of int
            | Configure of string

        /// Command status
        type CommandStatus =
            | Pending
            | Armed
            | Executing
            | Completed
            | Failed of string

        /// Command with audit trail
        type Command = {
            Id: Guid
            Type: CommandType
            Status: CommandStatus
            IssuedBy: string
            Target: string
            IssuedAt: DateTimeOffset
            CompletedAt: DateTimeOffset option
            RequiresTwoKey: bool
            SecondKey: string option
        }

        /// Check if command requires two-key-turn
        let requiresTwoKey (cmdType: CommandType) : bool =
            match cmdType with
            | Stop | Restart | Scale _ -> true
            | _ -> false

        /// Create a new command
        let createCommand (cmdType: CommandType) (issuedBy: string) (target: string) : Command =
            {
                Id = Guid.NewGuid()
                Type = cmdType
                Status = Pending
                IssuedBy = issuedBy
                Target = target
                IssuedAt = DateTimeOffset.UtcNow
                CompletedAt = None
                RequiresTwoKey = requiresTwoKey cmdType
                SecondKey = None
            }

        /// Arm command (first key)
        let arm (cmd: Command) : Command =
            { cmd with Status = Armed }

        /// Confirm command (second key if required)
        let confirm (cmd: Command) (secondKey: string option) : Command =
            if cmd.RequiresTwoKey && secondKey.IsNone then
                { cmd with Status = Failed "Second key required" }
            else
                { cmd with
                    Status = Executing
                    SecondKey = secondKey }

        /// Complete command
        let complete (cmd: Command) (success: bool) (message: string) : Command =
            { cmd with
                Status = if success then Completed else Failed message
                CompletedAt = Some DateTimeOffset.UtcNow }

        /// Audit log entry
        type AuditEntry = {
            CommandId: Guid
            Action: string
            Actor: string
            Timestamp: DateTimeOffset
            Details: string
        }

        /// Create audit entry
        let audit (cmd: Command) (action: string) (details: string) : AuditEntry =
            {
                CommandId = cmd.Id
                Action = action
                Actor = cmd.IssuedBy
                Timestamp = DateTimeOffset.UtcNow
                Details = details
            }
