namespace Cepaf.Cockpit

open System
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.BridgeAgent
open Cepaf.Cockpit.AiCopilot
open Cepaf.Cockpit.DarkCockpitUI
open Cepaf.Cockpit.SituationalAwareness
open Cepaf.Cockpit.MessagingIntegration

/// ═══════════════════════════════════════════════════════════════════════════════
/// C3I MESH COCKPIT - MAIN ORCHESTRATOR
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// WHAT: The main entry point for the C3I Mesh Cockpit system.
///       Orchestrates the Bridge Agent, AI Copilot, and Dark Cockpit UI.
///
/// WHY: Provides a unified interface for safety-critical distributed control
///      with AI-enhanced intelligence and human-in-the-loop design.
///
/// USAGE:
///   let cockpit = Cockpit.create "operator-1" false false
///   Cockpit.start cockpit
///   // ... system runs ...
///   Cockpit.shutdown cockpit
///
/// STAMP Compliance:
///   - SC-C3I-001: Data-centric architecture (Zenoh)
///   - SC-C3I-002: Safety-critical HMI standards (NASA-STD-3000)
///   - SC-C3I-003: AI advisory mode (human in the loop)
///   - SC-C3I-004: Audit logging for all commands
///
/// ═══════════════════════════════════════════════════════════════════════════════
module Cockpit =

    // ═══════════════════════════════════════════════════════════════════════════
    // COCKPIT INSTANCE
    // ═══════════════════════════════════════════════════════════════════════════

    type CockpitInstance = {
        Agent: MailboxProcessor<SystemMsg>
        AuditLog: string list ref
        StartedAt: DateTime
        MonitorOnly: bool
        SimulationMode: bool
        mutable Running: bool
        mutable Situational: SituationalState
        mutable Messaging: MessagingState
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AUDIT LOGGING
    // ═══════════════════════════════════════════════════════════════════════════

    let private createAuditLogger (logRef: string list ref) : string -> unit =
        fun message ->
            let entry = sprintf "[%s] %s" (DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff")) message
            logRef.Value <- entry :: logRef.Value |> List.truncate 1000
            // In production, also write to immutable file
            try
                System.IO.File.AppendAllText(
                    "lib/cepaf/artifacts/cockpit-audit.log",
                    entry + Environment.NewLine
                )
            with _ -> ()

    // ═══════════════════════════════════════════════════════════════════════════
    // COMMAND EXECUTION (Stub - would connect to Zenoh)
    // ═══════════════════════════════════════════════════════════════════════════

    let private createCommandSender () : NodeId -> MeshCommand -> Async<Result<string, string>> =
        fun nodeId cmd -> async {
            // Simulate command execution
            // In production, this would send a Zenoh Query to c3i/ctrl/{nodeId}/{subsystem}/set
            do! Async.Sleep 500
            if nodeId.Contains("fail") then
                return Error "Node refused command"
            else
                return Ok "ACK"
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // SIMULATION MODE
    // ═══════════════════════════════════════════════════════════════════════════

    let private startSimulation (agent: MailboxProcessor<SystemMsg>) =
        let rnd = Random()
        async {
            let zones = [| "zone-alpha"; "zone-beta"; "zone-gamma" |]
            let nodes = [| "node-01"; "node-02"; "node-03"; "node-04"; "node-05" |]

            while true do
                // Simulate telemetry from random node
                let zone = zones.[rnd.Next(zones.Length)]
                let node = nodes.[rnd.Next(nodes.Length)]
                let key = sprintf "c3i/units/%s/%s/telemetry" zone node

                let cpu = 20.0 + rnd.NextDouble() * 60.0 + (if rnd.Next(10) = 0 then 30.0 else 0.0)
                let memory = 30.0 + rnd.NextDouble() * 50.0
                let latency = 10.0 + rnd.NextDouble() * 100.0

                let payload = sprintf """{"cpu":%.1f,"memory":%.1f,"latency":%.1f}""" cpu memory latency
                let bytes = System.Text.Encoding.UTF8.GetBytes(payload)

                agent.Post(TelemetryReceived(key, bytes, DateTime.UtcNow))

                // Occasionally generate alarms
                if rnd.Next(50) = 0 then
                    let alarmPayload = sprintf "High CPU on %s in %s" node zone
                    agent.Post(AlarmReceived("c3i/alarms/caution/sim", System.Text.Encoding.UTF8.GetBytes(alarmPayload)))

                do! Async.Sleep (50 + rnd.Next(100))
        }
        |> Async.Start

    // ═══════════════════════════════════════════════════════════════════════════
    // AI INTEGRATION
    // ═══════════════════════════════════════════════════════════════════════════

    let private startAiAnalysis (agent: MailboxProcessor<SystemMsg>) =
        async {
            while true do
                // Periodically request AI analysis
                do! Async.Sleep 10000  // Every 10 seconds

                // Get current state and generate insights
                let state = getState agent
                let insights = getQuickInsights state
                for insight in insights do
                    agent.Post(AiInsightReceived insight)
        }
        |> Async.Start

    // ═══════════════════════════════════════════════════════════════════════════
    // PUBLIC API
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a new cockpit instance
    let create (operatorId: string) (monitorOnly: bool) (simulationMode: bool) : CockpitInstance =
        let auditLog = ref []
        let auditLogger = createAuditLogger auditLog
        let commandSender = createCommandSender()
        let aiConfig = { defaultConfig with Enabled = true }
        let aiRequester = createAiRequestFunction aiConfig

        let agent = createCockpitAgent render commandSender aiRequester auditLogger

        // Initialize situational awareness with terminal size
        let termSize = getTerminalSize()
        let situational = SituationalAwareness.initialize termSize.Cols termSize.Rows

        auditLogger (sprintf "COCKPIT CREATED: Operator=%s, MonitorOnly=%b, Simulation=%b" operatorId monitorOnly simulationMode)
        auditLogger (sprintf "SITUATIONAL AWARENESS: Sound=%b, ColorMode=%A, ScreenSize=%dx%d"
                        situational.Sound.Enabled situational.ColorMode termSize.Cols termSize.Rows)

        // Initialize messaging state
        let messaging = defaultMessagingState

        // Log cockpit creation at Spine level (critical infrastructure)
        let messaging =
            FractalLogging.logSpine
                "Cockpit"
                (sprintf "Cockpit created for operator %s" operatorId)
                (Map.ofList [("operator", operatorId); ("mode", if simulationMode then "simulation" else "production")])
                messaging.Log
            |> fun log -> { messaging with Log = log }

        {
            Agent = agent
            AuditLog = auditLog
            StartedAt = DateTime.UtcNow
            MonitorOnly = monitorOnly
            SimulationMode = simulationMode
            Running = false
            Situational = situational
            Messaging = messaging
        }

    /// Start the cockpit
    let start (cockpit: CockpitInstance) =
        DarkCockpitUI.initialize()
        cockpit.Running <- true

        // Start UI tick loop (10 Hz)
        startTickLoop cockpit.Agent 10

        // Start AI analysis loop
        startAiAnalysis cockpit.Agent

        // Start simulation if enabled
        if cockpit.SimulationMode then
            startSimulation cockpit.Agent

        (createAuditLogger cockpit.AuditLog) "COCKPIT STARTED"

    /// Shutdown the cockpit
    let shutdown (cockpit: CockpitInstance) =
        cockpit.Running <- false
        cockpit.Agent.Post Shutdown
        (createAuditLogger cockpit.AuditLog) "COCKPIT SHUTDOWN INITIATED"
        DarkCockpitUI.shutdown()

    /// Post telemetry from external source (Zenoh callback)
    let postTelemetry (cockpit: CockpitInstance) key payload =
        postTelemetry cockpit.Agent key payload

    /// Get current state
    let getState (cockpit: CockpitInstance) : CockpitState =
        BridgeAgent.getState cockpit.Agent

    /// Arm a command (two-step commit step 1)
    let armCommand (cockpit: CockpitInstance) (nodeId: NodeId) (cmd: MeshCommand) =
        if not cockpit.MonitorOnly then
            cockpit.Agent.Post(ArmCommand(nodeId, cmd))

    /// Confirm an armed command (two-step commit step 2)
    let confirmCommand (cockpit: CockpitInstance) (cmdId: CommandId) =
        if not cockpit.MonitorOnly then
            cockpit.Agent.Post(ConfirmCommand cmdId)

    /// Cancel an armed command
    let cancelCommand (cockpit: CockpitInstance) (cmdId: CommandId) =
        cockpit.Agent.Post(CancelCommand cmdId)

    /// Acknowledge an alarm
    let acknowledgeAlarm (cockpit: CockpitInstance) (alarmId: AlarmId) (operator: string) =
        cockpit.Agent.Post(AcknowledgeAlarm(alarmId, operator))

    /// Change view
    let changeView (cockpit: CockpitInstance) (view: ViewMode) =
        cockpit.Agent.Post(ChangeView view)

    /// Select a node
    let selectNode (cockpit: CockpitInstance) (nodeId: NodeId option) =
        cockpit.Agent.Post(SelectNode nodeId)

    /// Get audit log
    let getAuditLog (cockpit: CockpitInstance) : string list =
        cockpit.AuditLog.Value

    // ═══════════════════════════════════════════════════════════════════════════
    // DEMO MODE
    // ═══════════════════════════════════════════════════════════════════════════

    // ═══════════════════════════════════════════════════════════════════════════
    // OODA CYCLE INTEGRATION (SC-C3I-005)
    // ═══════════════════════════════════════════════════════════════════════════

    /// OODA cycle timing targets (milliseconds)
    module OodaTargets =
        let ObserveTarget = 100    // Data collection
        let OrientTarget = 200     // Analysis
        let DecideTarget = 500     // Recommendation
        let ActTarget = 200        // Command execution
        let TotalTarget = 1000     // Complete cycle

    /// OODA cycle measurement
    type OodaCycleMetrics = {
        ObserveMs: float
        OrientMs: float
        DecideMs: float
        ActMs: float
        TotalMs: float
        Quality: float       // 0.0-1.0 based on data freshness
        CycleCount: int64
        Violations: int      // Cycles exceeding target
    }

    let private emptyOodaMetrics = {
        ObserveMs = 0.0
        OrientMs = 0.0
        DecideMs = 0.0
        ActMs = 0.0
        TotalMs = 0.0
        Quality = 1.0
        CycleCount = 0L
        Violations = 0
    }

    /// Execute OODA cycle with timing
    let private executeOodaCycle (cockpit: CockpitInstance) (state: CockpitState) : OodaCycleMetrics =
        let sw = System.Diagnostics.Stopwatch.StartNew()

        // OBSERVE: Collect telemetry data
        let observeStart = sw.ElapsedMilliseconds
        cockpit.Situational <- SituationalAwareness.advanceOodaPhase cockpit.Situational
        let state = getState cockpit
        let observeMs = float (sw.ElapsedMilliseconds - observeStart)

        // ORIENT: Analyze and correlate data
        let orientStart = sw.ElapsedMilliseconds
        cockpit.Situational <- SituationalAwareness.advanceOodaPhase cockpit.Situational
        cockpit.Situational <- SituationalAwareness.updateAnimations cockpit.Situational
        cockpit.Situational <- SituationalAwareness.updateColorMode cockpit.Situational
        let orientMs = float (sw.ElapsedMilliseconds - orientStart)

        // DECIDE: Generate recommendations (AI Copilot)
        let decideStart = sw.ElapsedMilliseconds
        cockpit.Situational <- SituationalAwareness.advanceOodaPhase cockpit.Situational
        // AI insights are generated asynchronously, timing is estimated
        let decideMs = float (sw.ElapsedMilliseconds - decideStart)

        // ACT: Ready for operator commands
        let actStart = sw.ElapsedMilliseconds
        cockpit.Situational <- SituationalAwareness.advanceOodaPhase cockpit.Situational
        let actMs = float (sw.ElapsedMilliseconds - actStart)

        let totalMs = float sw.ElapsedMilliseconds

        // Calculate quality based on data staleness
        let quality =
            let maxStaleness =
                state.Nodes
                |> Map.toSeq
                |> Seq.map (fun (_, node) ->
                    (DateTime.UtcNow - node.Cpu.LastUpdated).TotalSeconds)
                |> Seq.fold max 0.0
            max 0.0 (1.0 - maxStaleness / 30.0)  // Decay over 30s

        {
            ObserveMs = observeMs
            OrientMs = orientMs
            DecideMs = decideMs
            ActMs = actMs
            TotalMs = totalMs
            Quality = quality
            CycleCount = 1L
            Violations = if totalMs > float OodaTargets.TotalTarget then 1 else 0
        }

    /// Start the OODA cycle loop
    let private startOodaLoop (cockpit: CockpitInstance) (intervalMs: int) =
        async {
            let mutable metrics = emptyOodaMetrics

            while cockpit.Running do
                let state = getState cockpit
                let cycleMetrics = executeOodaCycle cockpit state

                // Accumulate metrics
                metrics <- {
                    ObserveMs = (metrics.ObserveMs * 0.9) + (cycleMetrics.ObserveMs * 0.1)
                    OrientMs = (metrics.OrientMs * 0.9) + (cycleMetrics.OrientMs * 0.1)
                    DecideMs = (metrics.DecideMs * 0.9) + (cycleMetrics.DecideMs * 0.1)
                    ActMs = (metrics.ActMs * 0.9) + (cycleMetrics.ActMs * 0.1)
                    TotalMs = (metrics.TotalMs * 0.9) + (cycleMetrics.TotalMs * 0.1)
                    Quality = cycleMetrics.Quality
                    CycleCount = metrics.CycleCount + 1L
                    Violations = metrics.Violations + cycleMetrics.Violations
                }

                // Log if cycle violates target
                if cycleMetrics.TotalMs > float OodaTargets.TotalTarget then
                    (createAuditLogger cockpit.AuditLog)
                        (sprintf "OODA VIOLATION: Cycle took %.0fms (target: %dms)"
                            cycleMetrics.TotalMs OodaTargets.TotalTarget)

                do! Async.Sleep intervalMs
        }
        |> Async.Start

    // ═══════════════════════════════════════════════════════════════════════════
    // SITUATIONAL AWARENESS INTEGRATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Process alarm with full situational awareness
    let processAlarmWithAwareness (cockpit: CockpitInstance) (alarm: Alarm) =
        cockpit.Situational <- SituationalAwareness.processAlarm alarm cockpit.Situational
        cockpit.Agent.Post(AlarmReceived("alarm", System.Text.Encoding.UTF8.GetBytes(alarm.Message)))
        (createAuditLogger cockpit.AuditLog)
            (sprintf "ALARM [%A]: %s" alarm.Level alarm.Message)

    /// Get current OODA indicator for display
    let getOodaIndicator (cockpit: CockpitInstance) (cycleMs: float) (quality: float) : string =
        SituationalAwareness.getOodaIndicator cockpit.Situational cycleMs quality

    /// Render element with situational awareness
    let renderWithAwareness
        (cockpit: CockpitInstance)
        (elementId: string)
        (content: string)
        (alarmLevel: AlarmLevel)
        (stalenessSeconds: float) : string =
        SituationalAwareness.renderWithAwareness elementId content alarmLevel stalenessSeconds cockpit.Situational

    /// Play sound for alarm (respects mute settings)
    let playAlarmSound (cockpit: CockpitInstance) (level: AlarmLevel) =
        let newSound = Sound.playAlarmSound level cockpit.Situational.Sound
        cockpit.Situational <- { cockpit.Situational with Sound = newSound }

    /// Mute sounds for duration
    let muteSounds (cockpit: CockpitInstance) (duration: TimeSpan) =
        let newSound = Sound.muteSounds duration cockpit.Situational.Sound
        cockpit.Situational <- { cockpit.Situational with Sound = newSound }
        (createAuditLogger cockpit.AuditLog)
            (sprintf "SOUNDS MUTED for %.0f seconds" duration.TotalSeconds)

    /// Update layout for new terminal size
    let updateLayout (cockpit: CockpitInstance) (width: int) (height: int) =
        let newLayout = ScreenSpace.createAdaptiveLayout width height
        cockpit.Situational <- { cockpit.Situational with Layout = newLayout }

    // ═══════════════════════════════════════════════════════════════════════════
    // DEMO MODE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Run the cockpit in demo/simulation mode
    let demo () =
        printfn "%s[C3I Mesh Cockpit] Starting in SIMULATION mode...%s" Ansi.advisory Ansi.reset
        let cockpit = create "demo-operator" false true
        start cockpit

        // Start OODA loop (100ms interval = 10 Hz)
        startOodaLoop cockpit 100

        // Run until Ctrl+C
        Console.CancelKeyPress.Add(fun args ->
            args.Cancel <- true
            shutdown cockpit
        )

        // Keep running
        while cockpit.Running do
            System.Threading.Thread.Sleep(100)
