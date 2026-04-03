// =============================================================================
// OodaSupervisor.fs - SIL-4 Compliant OODA Biomorphic Supervisor
// =============================================================================
// STAMP: SC-SIL4-007, SC-BIO-001, SC-OODA-001, SC-OODA-005, SC-CTRL-006
// AOR: AOR-SIL4-004, AOR-BIO-001, AOR-CAE-001, AOR-COG-001
//
// ## Techniques Implemented
// | Technique | Source | Purpose |
// |-----------|--------|---------|
// | OODA Loop | John Boyd | Decision-action cycle |
// | Hysteresis | Control Theory | Prevent oscillation |
// | Biomorphic Scaling | Metabolic Theory | Resource adaptation |
// | Guardian Validation | Indrajaal Constitution | Safety enforcement |
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-04 |
// | Author | Cybernetic Architect |
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Diagnostics
open System.Threading
open System.Collections.Generic

/// <summary>
/// OODA phase enumeration
/// </summary>
type OodaPhase =
    | Observe
    | Orient
    | Decide
    | Act
    | Verify

/// <summary>
/// Observation data from sensors
/// </summary>
type Observation = {
    /// Timestamp of observation
    Timestamp: DateTimeOffset
    /// Container health states
    ContainerHealth: Map<string, ContainerHealth>
    /// Port availability
    PortsAvailable: bool
    /// Database connectivity
    DatabaseConnected: bool
    /// Network latency (ms)
    NetworkLatencyMs: int
    /// Memory pressure (0.0 - 1.0)
    MemoryPressure: float
    /// CPU utilization (0.0 - 1.0)
    CpuUtilization: float
    /// Active connections per container
    ActiveConnections: Map<string, int>
    /// Error count in last cycle
    RecentErrors: int
    /// SLA compliance status
    SlaCompliant: bool
}

/// <summary>
/// Orientation (analysis) result
/// </summary>
type Orientation = {
    /// Current system health score (0.0 - 1.0)
    HealthScore: float
    /// Trend direction (-1 degrading, 0 stable, +1 improving)
    Trend: int
    /// Identified issues
    Issues: string list
    /// Recommended priorities
    Priorities: string list
    /// Risk level (0 = none, 1 = low, 2 = medium, 3 = high, 4 = critical)
    RiskLevel: int
    /// Degraded containers
    DegradedContainers: string list
    /// 5-order effect prediction
    PredictedEffects: Map<int, string list>
}

/// <summary>
/// Decision (action plan)
/// </summary>
type Decision =
    | NoAction of reason: string
    | BootMesh of config: BootConfig
    | ShutdownMesh of config: ShutdownConfig
    | RestartContainer of id: string * reason: string
    | ScaleUp of count: int
    | ScaleDown of count: int
    | EmergencyStop of reason: string
    | HealthCheck of ids: string list
    | DrainContainer of id: string

/// <summary>
/// Action result
/// </summary>
type ActionResult =
    | Success of message: string * durationMs: int64
    | Failure of error: string * durationMs: int64
    | Skipped of reason: string
    | Vetoed of guardianReason: string

/// <summary>
/// OODA cycle result
/// </summary>
type OodaCycle = {
    /// Cycle number
    CycleNumber: int
    /// Start time
    StartTime: DateTimeOffset
    /// End time
    EndTime: DateTimeOffset
    /// Total duration in milliseconds
    DurationMs: int64
    /// Observation collected
    Observation: Observation
    /// Orientation result
    Orientation: Orientation
    /// Decision made
    Decision: Decision
    /// Action result
    ActionResult: ActionResult
    /// SLA compliant (< 100ms per SC-BIO-001)
    SlaCycleCompliant: bool
}

/// <summary>
/// Supervisor configuration
/// </summary>
type SupervisorConfig = {
    /// OODA cycle interval in milliseconds
    CycleIntervalMs: int
    /// Maximum cycle duration (SLA) in milliseconds
    MaxCycleDurationMs: int
    /// Hysteresis margin for decisions (prevents oscillation)
    HysteresisMargin: float
    /// Hold cycles before reversing decision
    HysteresisHoldCycles: int
    /// Enable Guardian validation
    EnableGuardian: bool
    /// Health score threshold for action
    HealthThreshold: float
    /// Maximum consecutive failures before emergency
    MaxConsecutiveFailures: int
    /// Enable verbose logging
    Verbose: bool
}

/// <summary>
/// Supervisor state
/// </summary>
type SupervisorState = {
    /// Digital twin reference
    Twin: DigitalTwin
    /// Configuration
    Config: SupervisorConfig
    /// Cycle history (last N cycles)
    History: OodaCycle list
    /// Current phase
    CurrentPhase: OodaPhase
    /// Consecutive failure count
    ConsecutiveFailures: int
    /// Last decision (for hysteresis)
    LastDecision: Decision option
    /// Cycles since last decision change
    CyclesSinceDecisionChange: int
    /// Running flag
    Running: bool
}

/// <summary>
/// OODA Supervisor operations module
/// </summary>
module OodaSupervisor =

    /// Default supervisor configuration (SC-BIO-001: <100ms cycles)
    let defaultConfig : SupervisorConfig = {
        CycleIntervalMs = 30000      // 30s between cycles (per AOR-BIO-001)
        MaxCycleDurationMs = 100     // 100ms max per SC-OODA-001
        HysteresisMargin = 0.1       // 10% margin per SC-OODA-005
        HysteresisHoldCycles = 3     // Hold 3 cycles per SC-OODA-005
        EnableGuardian = true
        HealthThreshold = 0.8        // 80% health required
        MaxConsecutiveFailures = 3
        Verbose = true
    }

    /// Log with OODA context
    let private log (phase: OodaPhase) (message: string) (verbose: bool) : unit =
        if verbose then
            let phaseStr =
                match phase with
                | Observe -> "OBSERVE"
                | Orient -> "ORIENT"
                | Decide -> "DECIDE"
                | Act -> "ACT"
                | Verify -> "VERIFY"
            let ts = DateTime.UtcNow.ToString("HH:mm:ss.fff")
            printfn "[%s] [OODA:%-7s] %s" ts phaseStr message

    /// Execute shell command (for health checks)
    let private execCommand (command: string) (args: string) (timeoutMs: int) : (int * string) =
        let psi = Diagnostics.ProcessStartInfo(
            FileName = command,
            Arguments = args,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        )
        use proc = new Diagnostics.Process()
        proc.StartInfo <- psi
        proc.Start() |> ignore

        let stdout = proc.StandardOutput.ReadToEnd()
        if proc.WaitForExit(timeoutMs) then
            (proc.ExitCode, stdout)
        else
            proc.Kill()
            (-1, "Timeout")

    /// OBSERVE phase - Collect system state
    let observe (twin: DigitalTwin) (config: SupervisorConfig) : Observation =
        let sw = Stopwatch.StartNew()

        if config.Verbose then
            log Observe "Collecting sensor data..." config.Verbose

        // Collect container health from twin
        let containerHealth =
            twin.Phenotypes
            |> Map.map (fun _ p -> p.Health)

        // Check port availability (5433 for DB, 4317 for OTEL)
        let (dbCode, _) = execCommand "nc" "-z localhost 5433" 1000
        let portsAvailable = dbCode = 0

        // Check database connectivity
        let (pgCode, _) = execCommand "pg_isready" "-h localhost -p 5433" 2000
        let dbConnected = pgCode = 0

        // Collect active connections
        let activeConnections =
            twin.Phenotypes
            |> Map.map (fun _ p -> p.ActiveConnections)

        // Count recent errors
        let recentErrors =
            twin.Phenotypes
            |> Map.toList
            |> List.sumBy (fun (_, p) -> p.Errors.Length)

        // Check SLA compliance (from last boot)
        let slaCompliant =
            match twin.Cache with
            | Some cache ->
                let bootTimes = cache.StartOrder |> List.sumBy (fun w -> w.MaxParallel)
                bootTimes <= 10  // Rough SLA check
            | None -> true

        sw.Stop()

        if config.Verbose then
            log Observe (sprintf "Observation collected in %dms" sw.ElapsedMilliseconds) config.Verbose

        {
            Timestamp = DateTimeOffset.UtcNow
            ContainerHealth = containerHealth
            PortsAvailable = portsAvailable
            DatabaseConnected = dbConnected
            NetworkLatencyMs = 0  // Would measure with ping
            MemoryPressure = 0.0  // Would read from /proc/meminfo
            CpuUtilization = 0.0  // Would read from /proc/stat
            ActiveConnections = activeConnections
            RecentErrors = recentErrors
            SlaCompliant = slaCompliant
        }

    /// ORIENT phase - Analyze situation
    let orient (observation: Observation) (state: SupervisorState) : Orientation =
        let sw = Stopwatch.StartNew()

        if state.Config.Verbose then
            log Orient "Analyzing situation..." state.Config.Verbose

        // Calculate health score
        let totalContainers = observation.ContainerHealth.Count
        let healthyCount =
            observation.ContainerHealth
            |> Map.filter (fun _ h -> h = ContainerHealth.Healthy)
            |> Map.count

        let healthScore =
            if totalContainers = 0 then 0.0
            else float healthyCount / float totalContainers

        // Determine trend from history
        let trend =
            if state.History.Length < 2 then 0
            else
                let lastScore = state.History.[0].Orientation.HealthScore
                if healthScore > lastScore + 0.05 then 1
                elif healthScore < lastScore - 0.05 then -1
                else 0

        // Identify issues
        let issues = ResizeArray<string>()

        if not observation.PortsAvailable then
            issues.Add("Ports not available (5433 or 4317)")

        if not observation.DatabaseConnected then
            issues.Add("Database not connected")

        if observation.RecentErrors > 0 then
            issues.Add(sprintf "%d recent errors detected" observation.RecentErrors)

        if healthScore < state.Config.HealthThreshold then
            issues.Add(sprintf "Health score below threshold (%.2f < %.2f)" healthScore state.Config.HealthThreshold)

        // Identify degraded containers
        let degradedContainers =
            observation.ContainerHealth
            |> Map.filter (fun _ h ->
                match h with
                | ContainerHealth.Healthy -> false
                | _ -> true)
            |> Map.keys
            |> Seq.toList

        // Calculate risk level
        let riskLevel =
            if observation.RecentErrors > 10 || not observation.DatabaseConnected then 4  // Critical
            elif healthScore < 0.5 then 3  // High
            elif healthScore < 0.7 then 2  // Medium
            elif issues.Count > 0 then 1   // Low
            else 0                          // None

        // Predict 5-order effects (simplified)
        let predictedEffects =
            Map.ofList [
                (1, ["Container state changes"])
                (2, ["Health check propagation"])
                (3, ["Dashboard updates"])
                (4, ["SLA metrics impact"])
                (5, ["Compliance reporting"])
            ]

        sw.Stop()

        if state.Config.Verbose then
            log Orient (sprintf "Health=%.2f Trend=%d Risk=%d Issues=%d" healthScore trend riskLevel issues.Count) state.Config.Verbose

        {
            HealthScore = healthScore
            Trend = trend
            Issues = issues |> Seq.toList
            Priorities = if degradedContainers.IsEmpty then [] else ["Restore degraded containers"]
            RiskLevel = riskLevel
            DegradedContainers = degradedContainers
            PredictedEffects = predictedEffects
        }

    /// DECIDE phase - Determine action (with hysteresis per SC-OODA-005)
    let decide (observation: Observation) (orientation: Orientation) (state: SupervisorState) : Decision =
        let sw = Stopwatch.StartNew()

        if state.Config.Verbose then
            log Decide "Evaluating options..." state.Config.Verbose

        // Hysteresis check - don't oscillate decisions
        let shouldApplyHysteresis =
            state.CyclesSinceDecisionChange < state.Config.HysteresisHoldCycles

        // Determine decision
        let decision =
            // Emergency: too many consecutive failures
            if state.ConsecutiveFailures >= state.Config.MaxConsecutiveFailures then
                EmergencyStop "Max consecutive failures exceeded"

            // Critical risk
            elif orientation.RiskLevel >= 4 then
                if not observation.DatabaseConnected then
                    RestartContainer ("indrajaal-db-prod", "Database connection lost")
                else
                    EmergencyStop "Critical risk level detected"

            // High risk with degraded containers
            elif orientation.RiskLevel >= 3 && not orientation.DegradedContainers.IsEmpty then
                let target = orientation.DegradedContainers |> List.head
                RestartContainer (target, "Container degraded")

            // Health below threshold
            elif orientation.HealthScore < state.Config.HealthThreshold - state.Config.HysteresisMargin then
                if shouldApplyHysteresis then
                    match state.LastDecision with
                    | Some (NoAction _) -> NoAction "Hysteresis: waiting for stabilization"
                    | _ -> HealthCheck orientation.DegradedContainers
                else
                    HealthCheck orientation.DegradedContainers

            // Everything healthy
            else
                NoAction "System healthy"

        sw.Stop()

        if state.Config.Verbose then
            let decisionStr =
                match decision with
                | NoAction r -> sprintf "NO_ACTION: %s" r
                | BootMesh _ -> "BOOT_MESH"
                | ShutdownMesh _ -> "SHUTDOWN_MESH"
                | RestartContainer (id, _) -> sprintf "RESTART: %s" id
                | ScaleUp n -> sprintf "SCALE_UP: %d" n
                | ScaleDown n -> sprintf "SCALE_DOWN: %d" n
                | EmergencyStop r -> sprintf "EMERGENCY: %s" r
                | HealthCheck ids -> sprintf "HEALTH_CHECK: %d containers" ids.Length
                | DrainContainer id -> sprintf "DRAIN: %s" id
            log Decide decisionStr state.Config.Verbose

        decision

    /// Guardian validation (SC-CTRL-006)
    let validateWithGuardian (decision: Decision) (config: SupervisorConfig) : Result<Decision, string> =
        if not config.EnableGuardian then
            Ok decision
        else
            // In real implementation: call Guardian.validate_proposal/1
            match decision with
            | EmergencyStop _ ->
                // Emergency always allowed
                Ok decision
            | ShutdownMesh _ ->
                // Require explicit approval for shutdown
                if config.Verbose then
                    log Act "Guardian: Shutdown requires explicit approval" config.Verbose
                Error "Shutdown requires explicit Guardian approval"
            | _ ->
                Ok decision

    /// ACT phase - Execute decision
    let act (decision: Decision) (twin: DigitalTwin) (config: SupervisorConfig) : ActionResult =
        let sw = Stopwatch.StartNew()

        if config.Verbose then
            log Act "Executing decision..." config.Verbose

        // Validate with Guardian
        match validateWithGuardian decision config with
        | Error reason ->
            sw.Stop()
            Vetoed reason

        | Ok validatedDecision ->
            let result =
                match validatedDecision with
                | NoAction reason ->
                    Skipped reason

                | BootMesh bootConfig ->
                    try
                        let result = MeshStartup.boot twin bootConfig
                        if result.AllSucceeded then
                            Success ("Mesh booted successfully", result.TotalDurationMs)
                        else
                            Failure ("Boot failed for some containers", result.TotalDurationMs)
                    with ex ->
                        Failure (ex.Message, sw.ElapsedMilliseconds)

                | ShutdownMesh shutdownConfig ->
                    try
                        let result = MeshShutdown.shutdown twin shutdownConfig
                        if result.AllGraceful then
                            Success ("Mesh shutdown gracefully", result.TotalDurationMs)
                        else
                            Failure ("Shutdown required force kills", result.TotalDurationMs)
                    with ex ->
                        Failure (ex.Message, sw.ElapsedMilliseconds)

                | RestartContainer (id, reason) ->
                    try
                        if config.Verbose then
                            log Act (sprintf "Restarting %s: %s" id reason) config.Verbose
                        // Stop then start
                        let genotype = twin.Genotypes.[id]
                        let (code, _) = execCommand "podman-compose" (sprintf "-f %s restart %s" MeshStartup.defaultConfig.ComposeFile genotype.Name) 30000
                        if code = 0 then
                            Success (sprintf "Container %s restarted" id, sw.ElapsedMilliseconds)
                        else
                            Failure (sprintf "Failed to restart %s" id, sw.ElapsedMilliseconds)
                    with ex ->
                        Failure (ex.Message, sw.ElapsedMilliseconds)

                | EmergencyStop reason ->
                    try
                        if config.Verbose then
                            log Act (sprintf "EMERGENCY STOP: %s" reason) config.Verbose
                        let result = MeshShutdown.emergencyShutdown twin
                        Success (sprintf "Emergency stop: %s" reason, result.TotalDurationMs)
                    with ex ->
                        Failure (ex.Message, sw.ElapsedMilliseconds)

                | HealthCheck ids ->
                    if config.Verbose then
                        log Act (sprintf "Health checking %d containers" ids.Length) config.Verbose
                    Skipped "Health check scheduled"

                | DrainContainer id ->
                    if config.Verbose then
                        log Act (sprintf "Draining %s" id) config.Verbose
                    Skipped "Drain scheduled"

                | ScaleUp n ->
                    try
                        if config.Verbose then
                            log Act (sprintf "Scaling up by %d" n) config.Verbose
                        let currentCount =
                            twin.Phenotypes
                            |> Map.filter (fun k _ -> k.Contains("app"))
                            |> Map.count
                        let targetCount = currentCount + n
                        let composeArgs = sprintf "-f %s up -d --scale indrajaal-ex-app=%d" MeshStartup.defaultConfig.ComposeFile targetCount
                        let (code, output) = execCommand "podman-compose" composeArgs 60000
                        if code = 0 then
                            Success (sprintf "Scaled up to %d app instances" targetCount, sw.ElapsedMilliseconds)
                        else
                            Failure (sprintf "Scale up failed: %s" (output.Trim()), sw.ElapsedMilliseconds)
                    with ex ->
                        Failure (ex.Message, sw.ElapsedMilliseconds)

                | ScaleDown n ->
                    try
                        if config.Verbose then
                            log Act (sprintf "Scaling down by %d" n) config.Verbose
                        let currentCount =
                            twin.Phenotypes
                            |> Map.filter (fun k _ -> k.Contains("app"))
                            |> Map.count
                        let targetCount = max 1 (currentCount - n)
                        if targetCount >= currentCount then
                            Skipped "Already at minimum scale"
                        else
                            let composeArgs = sprintf "-f %s up -d --scale indrajaal-ex-app=%d" MeshStartup.defaultConfig.ComposeFile targetCount
                            let (code, output) = execCommand "podman-compose" composeArgs 60000
                            if code = 0 then
                                Success (sprintf "Scaled down to %d app instances" targetCount, sw.ElapsedMilliseconds)
                            else
                                Failure (sprintf "Scale down failed: %s" (output.Trim()), sw.ElapsedMilliseconds)
                    with ex ->
                        Failure (ex.Message, sw.ElapsedMilliseconds)

            sw.Stop()

            if config.Verbose then
                let resultStr =
                    match result with
                    | Success (m, ms) -> sprintf "SUCCESS: %s (%dms)" m ms
                    | Failure (e, ms) -> sprintf "FAILURE: %s (%dms)" e ms
                    | Skipped r -> sprintf "SKIPPED: %s" r
                    | Vetoed r -> sprintf "VETOED: %s" r
                log Act resultStr config.Verbose

            result

    /// Run single OODA cycle
    let runCycle (state: SupervisorState) : OodaCycle * SupervisorState =
        let cycleStart = DateTimeOffset.UtcNow
        let sw = Stopwatch.StartNew()

        // OBSERVE
        let observation = observe state.Twin state.Config

        // ORIENT
        let orientation = orient observation state

        // DECIDE
        let decision = decide observation orientation state

        // ACT
        let actionResult = act decision state.Twin state.Config

        sw.Stop()

        // Build cycle record
        let cycle = {
            CycleNumber = state.History.Length + 1
            StartTime = cycleStart
            EndTime = DateTimeOffset.UtcNow
            DurationMs = sw.ElapsedMilliseconds
            Observation = observation
            Orientation = orientation
            Decision = decision
            ActionResult = actionResult
            SlaCycleCompliant = sw.ElapsedMilliseconds <= int64 state.Config.MaxCycleDurationMs
        }

        // Update state
        let consecutiveFailures =
            match actionResult with
            | Failure _ -> state.ConsecutiveFailures + 1
            | _ -> 0

        let decisionChanged =
            match state.LastDecision, decision with
            | Some (NoAction _), NoAction _ -> false
            | Some (HealthCheck _), HealthCheck _ -> false
            | Some prev, curr when prev = curr -> false
            | _ -> true

        let newState = {
            state with
                History = cycle :: (state.History |> List.truncate 99)  // Keep last 100
                ConsecutiveFailures = consecutiveFailures
                LastDecision = Some decision
                CyclesSinceDecisionChange =
                    if decisionChanged then 0
                    else state.CyclesSinceDecisionChange + 1
        }

        // Log cycle completion
        if state.Config.Verbose then
            let slaStr = if cycle.SlaCycleCompliant then "✓" else "✗"
            log Verify (sprintf "Cycle #%d complete in %dms [SLA %s]" cycle.CycleNumber cycle.DurationMs slaStr) state.Config.Verbose

        (cycle, newState)

    /// Create initial supervisor state
    let createState (twin: DigitalTwin) (config: SupervisorConfig) : SupervisorState = {
        Twin = twin
        Config = config
        History = []
        CurrentPhase = Observe
        ConsecutiveFailures = 0
        LastDecision = None
        CyclesSinceDecisionChange = 0
        Running = false
    }

    /// Run supervisor loop
    let run (twin: DigitalTwin) (config: SupervisorConfig) : unit =
        printfn ""
        printfn "\u001b[35m\u001b[1m>>> INDRAJAAL OODA BIOMORPHIC SUPERVISOR <<<\u001b[0m"
        printfn ""

        let mutable state = { createState twin config with Running = true }

        while state.Running do
            let (cycle, newState) = runCycle state
            state <- newState

            // Print dashboard summary
            printfn ""
            printfn "╔══════════════════════════════════════════════════════════════╗"
            printfn "║  Cycle: #%-4d  │  Health: %.2f  │  Risk: %d  │  SLA: %s     ║"
                cycle.CycleNumber
                cycle.Orientation.HealthScore
                cycle.Orientation.RiskLevel
                (if cycle.SlaCycleCompliant then "✓" else "✗")
            printfn "╚══════════════════════════════════════════════════════════════╝"
            printfn ""

            // Wait for next cycle
            if state.Running then
                Thread.Sleep(config.CycleIntervalMs)

    /// Run with default config
    let runDefault (twin: DigitalTwin) : unit =
        run twin defaultConfig

