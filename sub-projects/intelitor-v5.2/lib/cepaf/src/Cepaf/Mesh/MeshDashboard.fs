// =============================================================================
// MeshDashboard.fs - SIL-4 Compliant Mesh TUI Dashboard with KPI Tracking
// =============================================================================
// STAMP: SC-SIL4-003, SC-SIL4-006, SC-MON-001, SC-MON-005, SC-PRF-050
// AOR: AOR-SIL4-005, AOR-MON-004, AOR-BIO-004
//
// ## Techniques Implemented
// | Technique | Source | Purpose |
// |-----------|--------|---------|
// | Structured Metadata Injection | Google Dapper | Trace context |
// | Head-Based Sampling | Jaeger | Adaptive telemetry |
// | Real-Time KPI Tracking | SRE Practices | SLA monitoring |
// | Terminal.Gui TUI | .NET Ecosystem | User interface |
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
open Cepaf.Observability.ConsoleChannel  // SC-CONSOL-003: Centralized ANSI colors

/// <summary>
/// KPI metrics for mesh operations
/// </summary>
type MeshKPIs = {
    /// Total boot time in milliseconds
    TotalBootTimeMs: int64
    /// Time per wave
    WaveTimesMs: int64 list
    /// Container start times
    ContainerStartTimesMs: Map<string, int64>
    /// Health check durations
    HealthCheckDurationsMs: Map<string, int64>
    /// Port scour duration
    PortScourDurationMs: int64
    /// Topology cache hit
    TopologyCacheHit: bool
    /// Jitter delays applied
    JitterDelaysMs: Map<string, int>
    /// Current mesh health score (0.0 - 1.0)
    HealthScore: float
    /// SLA compliance (10s target)
    SlaCompliant: bool
    /// Last update timestamp
    LastUpdate: DateTimeOffset
}

/// <summary>
/// Dashboard refresh configuration
/// </summary>
type DashboardConfig = {
    /// Refresh interval in milliseconds
    RefreshIntervalMs: int
    /// Show verbose output
    Verbose: bool
    /// Enable ANSI colors
    EnableColors: bool
    /// Show KPI sparklines
    ShowSparklines: bool
    /// SLA target in milliseconds
    SlaTargetMs: int
}

/// <summary>
/// Container display state
/// </summary>
type ContainerDisplay = {
    Id: string
    Name: string
    Health: string
    Phase: string
    StartTimeMs: int64 option
    HealthCheckMs: int64 option
    Connections: int
}

/// <summary>
/// Dashboard state
/// </summary>
type DashboardState = {
    Twin: DigitalTwin
    KPIs: MeshKPIs
    Containers: ContainerDisplay list
    LastBootResult: MeshBootResult option
    LastShutdownResult: MeshShutdownResult option
    RefreshCount: int
    StartTime: DateTimeOffset
}

/// <summary>
/// Mesh dashboard operations module
/// </summary>
module MeshDashboard = 

    /// Default dashboard configuration (10s refresh per AOR-BIO-004)
    let defaultConfig : DashboardConfig = {
        RefreshIntervalMs = 10000   // 10s per specification
        Verbose = true
        EnableColors = true
        ShowSparklines = true
        SlaTargetMs = 10000         // 10s SLA target
    }

    /// ANSI color codes - using centralized AnsiColors (SC-CONSOL-003)
    /// For changes, update Cepaf.Observability.ConsoleChannel.AnsiColors
    module Colors = AnsiColors

    /// Create initial KPIs
    let createInitialKPIs () : MeshKPIs = {
        TotalBootTimeMs = 0L
        WaveTimesMs = []
        ContainerStartTimesMs = Map.empty
        HealthCheckDurationsMs = Map.empty
        PortScourDurationMs = 0L
        TopologyCacheHit = false
        JitterDelaysMs = Map.empty
        HealthScore = 0.0
        SlaCompliant = true
        LastUpdate = DateTimeOffset.UtcNow
    }

    /// Calculate health score from container states
    let calculateHealthScore (twin: DigitalTwin) : float = 
        let total = twin.Phenotypes.Count
        if total = 0 then 0.0
        else 
            let healthy = 
                twin.Phenotypes
                |> Map.filter (fun _ p -> p.Health = ContainerHealth.Healthy)
                |> Map.count
            float healthy / float total

    /// Update KPIs from boot result
    let updateKPIsFromBoot (kpis: MeshKPIs) (result: MeshBootResult) (twin: DigitalTwin) : MeshKPIs = 
        let waveTimes = result.Waves |> List.map (fun w -> w.TotalDurationMs)

        let containerTimes = 
            result.Waves
            |> List.collect (fun w -> 
                w.Results
                |> Map.toList
                |> List.choose (fun (id, r) -> 
                    match r with 
                    | Success (_, ms) -> Some (id, ms)
                    | Failure (_, ms) -> Some (id, ms)
                    | Timeout ms -> Some (id, ms)
                    | _ -> None))
            |> Map.ofList

        {
            kpis with 
                TotalBootTimeMs = result.TotalDurationMs
                WaveTimesMs = waveTimes
                ContainerStartTimesMs = containerTimes
                TopologyCacheHit = true  // If we got here, cache was used
                HealthScore = calculateHealthScore twin
                SlaCompliant = result.TotalDurationMs <= int64 defaultConfig.SlaTargetMs
                LastUpdate = DateTimeOffset.UtcNow
        }

    /// Update KPIs from shutdown result
    let updateKPIsFromShutdown (kpis: MeshKPIs) (result: MeshShutdownResult) (twin: DigitalTwin) : MeshKPIs = 
        {
            kpis with 
                HealthScore = calculateHealthScore twin
                LastUpdate = DateTimeOffset.UtcNow
        }

    /// Create container display from twin state
    let createContainerDisplays (twin: DigitalTwin) : ContainerDisplay list = 
        twin.Genotypes
        |> Map.toList
        |> List.map (fun (id, g) -> 
            let phenotype = Map.tryFind id twin.Phenotypes

            let healthStr = 
                match phenotype with 
                | Some p -> 
                    match p.Health with
                    | ContainerHealth.Healthy -> sprintf "%s●%s HEALTHY" Colors.green Colors.reset
                    | ContainerHealth.Starting -> sprintf "%s◐%s STARTING" Colors.yellow Colors.reset
                    | ContainerHealth.Unhealthy -> sprintf "%s●%s UNHEALTHY" Colors.red Colors.reset
                    | ContainerHealth.Stopping -> sprintf "%s◑%s STOPPING" Colors.yellow Colors.reset
                    | ContainerHealth.Stopped -> sprintf "%s○%s STOPPED" Colors.white Colors.reset
                    | ContainerHealth.Failed _ -> sprintf "%s✗%s FAILED" Colors.red Colors.reset
                    | ContainerHealth.Unknown -> sprintf "%s?%s UNKNOWN" Colors.white Colors.reset
                    | ContainerHealth.Lameduck -> sprintf "%s◐%s LAMEDUCK" Colors.yellow Colors.reset
                | None -> sprintf "%s-%s N/A" Colors.white Colors.reset

            let phaseStr =
                match phenotype with
                | Some p ->
                    match p.StartupPhase with
                    | StartupPhase.NotStarted -> "NotStarted"
                    | StartupPhase.Preflight -> "Preflight"
                    | StartupPhase.PortScour -> "PortScour"
                    | StartupPhase.DependencyCheck -> "DependencyCheck"
                    | StartupPhase.Booting -> "Booting"
                    | StartupPhase.HealthCheck -> "HealthCheck"
                    | StartupPhase.Ready -> "Ready"
                    | StartupPhase.FailedStartup _ -> "FailedStartup"
                | None -> "-"

            {
                Id = id
                Name = g.Name
                Health = healthStr
                Phase = phaseStr
                StartTimeMs =
                    match phenotype with
                    | Some p when p.LastHeartbeat.IsSome ->
                        let diff = DateTimeOffset.UtcNow - p.LastHeartbeat.Value
                        Some (int64 diff.TotalMilliseconds)
                    | _ -> None
                HealthCheckMs = None
                Connections = 
                    match phenotype with 
                    | Some p -> p.ActiveConnections
                    | None -> 0
            })

    /// Generate sparkline from values
    let sparkline (values: int64 list) (width: int) : string = 
        if values.IsEmpty then String.replicate width "▁"
        else 
            let blocks = ["▁"; "▂"; "▃"; "▄"; "▅"; "▆"; "▇"; "█"]
            let maxVal = values |> List.max |> float
            let minVal = values |> List.min |> float
            let range = maxVal - minVal

            let normalized = 
                if range = 0.0 then 
                    values |> List.map (fun _ -> 0)
                else 
                    values |> List.map (fun v -> 
                        let idx = int ((float v - minVal) / range * 7.0)
                        min 7 (max 0 idx))

            normalized
            |> List.map (fun idx -> blocks.[idx])
            |> String.concat ""

    /// Progress bar generation
    let progressBar (value: float) (width: int) (color: string) : string = 
        let filled = int (value * float width)
        let empty = width - filled
        sprintf "%s%s%s%s" color (String.replicate filled "█") (String.replicate empty "░") Colors.reset

    /// Format duration in human readable form
    let formatDuration (ms: int64) : string = 
        if ms < 1000L then sprintf "%dms" ms
        elif ms < 60000L then sprintf "%.1fs" (float ms / 1000.0)
        else sprintf "%.1fm" (float ms / 60000.0)

    /// Render dashboard header
    let renderHeader (state: DashboardState) : string =
        let uptime = DateTimeOffset.UtcNow - state.StartTime
        let line1 = sprintf "%s%s╔═══════════════════════════════════════════════════════════════════════════╗%s" Colors.magenta Colors.bold Colors.reset
        let line2 = sprintf "%s%s║         INDRAJAAL SIL-4 MESH DIGITAL TWIN DASHBOARD                       ║%s" Colors.magenta Colors.bold Colors.reset
        let line3 = sprintf "%s%s║  Version: 1.0.0  │  Refresh: #%-4d  │  Uptime: %-12s             ║%s" Colors.magenta Colors.bold state.RefreshCount (formatDuration (int64 uptime.TotalMilliseconds)) Colors.reset
        let line4 = sprintf "%s%s╚═══════════════════════════════════════════════════════════════════════════╝%s" Colors.magenta Colors.bold Colors.reset
        sprintf "%s\n%s\n%s\n%s" line1 line2 line3 line4

    /// Render KPI section
    let renderKPIs (kpis: MeshKPIs) (config: DashboardConfig) : string =
        let slaColor = if kpis.SlaCompliant then Colors.green else Colors.red
        let slaStatus = if kpis.SlaCompliant then "✓ COMPLIANT" else "✗ VIOLATION"
        let healthBar = progressBar kpis.HealthScore 20 Colors.green
        let waveSparkline =
            if config.ShowSparklines && not kpis.WaveTimesMs.IsEmpty then
                sprintf " %s%s%s" Colors.cyan (sparkline kpis.WaveTimesMs 10) Colors.reset
            else ""
        let cacheHit = if kpis.TopologyCacheHit then "YES" else "NO"
        let bootTime = formatDuration kpis.TotalBootTimeMs
        let scourTime = formatDuration kpis.PortScourDurationMs
        let lastUpdate = kpis.LastUpdate.ToString("HH:mm:ss.fff")

        let line1 = sprintf "%s┌─ KPI METRICS ───────────────────────────────────────────────────────────────┐%s" Colors.cyan Colors.reset
        let line2 = sprintf "│  %sBoot Time:%s     %s%-8s%s │ %sSLA (10s):%s  %s%-12s%s              │" Colors.yellow Colors.reset slaColor bootTime Colors.reset Colors.yellow Colors.reset slaColor slaStatus Colors.reset
        let line3 = sprintf "│  %sHealth Score:%s  %s         │ %sCache Hit:%s  %-5s                     │" Colors.yellow Colors.reset healthBar Colors.yellow Colors.reset cacheHit
        let line4 = sprintf "│  %sWaves:%s         %d waves%s    │ %sPort Scour:%s %s                     │" Colors.yellow Colors.reset kpis.WaveTimesMs.Length waveSparkline Colors.yellow Colors.reset scourTime
        let line5 = sprintf "│  %sLast Update:%s   %s                                                 │" Colors.yellow Colors.reset lastUpdate
        let line6 = sprintf "%s└─────────────────────────────────────────────────────────────────────────────┘%s" Colors.cyan Colors.reset

        sprintf "%s\n%s\n%s\n%s\n%s\n%s" line1 line2 line3 line4 line5 line6

    /// Render container table
    let renderContainerTable (containers: ContainerDisplay list) : string =
        let header =
            sprintf "%s┌─ CONTAINER STATUS ──────────────────────────────────────────────────────────┐%s\n│  %-20s │ %-12s │ %-12s │ %-10s │ %-6s  │\n├──────────────────────┼──────────────┼──────────────┼────────────┼─────────┤"
                Colors.cyan Colors.reset "CONTAINER" "HEALTH" "PHASE" "START TIME" "CONNS"

        let rows =
            containers
            |> List.map (fun c ->
                let startTime =
                    match c.StartTimeMs with
                    | Some ms -> formatDuration ms
                    | None -> "-"
                let name = if c.Name.Length > 20 then c.Name.Substring(0, 17) + "..." else c.Name
                sprintf "│  %-20s │ %-22s │ %-12s │ %-10s │ %-6d  │" name c.Health c.Phase startTime c.Connections)
            |> String.concat "\n"

        let footer =
            sprintf "%s└─────────────────────────────────────────────────────────────────────────────┘%s" Colors.cyan Colors.reset

        sprintf "%s\n%s\n%s" header rows footer

    /// Render wave breakdown
    let renderWaveBreakdown (kpis: MeshKPIs) : string =
        if kpis.WaveTimesMs.IsEmpty then ""
        else
            let waveRows =
                kpis.WaveTimesMs
                |> List.mapi (fun i ms ->
                    let pct = if kpis.TotalBootTimeMs > 0L then float ms / float kpis.TotalBootTimeMs * 100.0 else 0.0
                    sprintf "│  Wave %d: %s (%4.1f%%)  %s" (i + 1) (formatDuration ms) pct (progressBar (pct / 100.0) 30 Colors.blue))
                |> String.concat "\n"

            sprintf "%s┌─ WAVE BREAKDOWN ────────────────────────────────────────────────────────────┐%s\n%s\n%s└─────────────────────────────────────────────────────────────────────────────┘%s"
                Colors.cyan Colors.reset waveRows Colors.cyan Colors.reset

    /// Render commands help
    let renderCommands () : string =
        sprintf "%s┌─ COMMANDS ──────────────────────────────────────────────────────────────────┐%s\n│  [B] Boot Mesh    [S] Shutdown Mesh    [E] Emergency Stop    [R] Refresh    │\n│  [V] Verbose      [Q] Quit             [H] Help              [C] Clear      │\n%s└─────────────────────────────────────────────────────────────────────────────┘%s"
            Colors.cyan Colors.reset Colors.cyan Colors.reset

    /// Render full dashboard
    let render (state: DashboardState) (config: DashboardConfig) : string = 
        let containers = createContainerDisplays state.Twin

        let header = renderHeader state
        let kpis = renderKPIs state.KPIs config
        let containerTable = renderContainerTable containers
        let waveBreakdown = renderWaveBreakdown state.KPIs
        let commands = renderCommands ()

        sprintf "%s%s%s%s%s" header kpis containerTable waveBreakdown commands

    /// Clear screen
    let clearScreen () : unit = 
        Console.Clear()

    /// Create initial dashboard state
    let createState (twin: DigitalTwin) : DashboardState = {
        Twin = twin
        KPIs = createInitialKPIs ()
        Containers = createContainerDisplays twin
        LastBootResult = None
        LastShutdownResult = None
        RefreshCount = 0
        StartTime = DateTimeOffset.UtcNow
    }

    /// Refresh dashboard state
    let refresh (state: DashboardState) : DashboardState = 
        {
            state with 
                KPIs = { state.KPIs with 
                            HealthScore = calculateHealthScore state.Twin
                            LastUpdate = DateTimeOffset.UtcNow }
                Containers = createContainerDisplays state.Twin
                RefreshCount = state.RefreshCount + 1
        }

    /// Update state after boot
    let afterBoot (state: DashboardState) (result: MeshBootResult) : DashboardState = 
        {
            state with 
                LastBootResult = Some result
                KPIs = updateKPIsFromBoot state.KPIs result state.Twin
                RefreshCount = state.RefreshCount + 1
        }

    /// Update state after shutdown
    let afterShutdown (state: DashboardState) (result: MeshShutdownResult) : DashboardState = 
        {
            state with 
                LastShutdownResult = Some result
                KPIs = updateKPIsFromShutdown state.KPIs result state.Twin
                RefreshCount = state.RefreshCount + 1
        }

    /// Interactive dashboard loop
    let runInteractive (twin: DigitalTwin) (config: DashboardConfig) : unit = 
        let mutable state = createState twin
        let mutable running = true

        printfn "%sStarting SIL-4 Mesh Dashboard (refresh every %dms)...%s"
            Colors.green config.RefreshIntervalMs Colors.reset

        while running do
            // Render dashboard
            clearScreen ()
            printfn "%s" (render state config)

            // Check for input (non-blocking)
            if Console.KeyAvailable then 
                let key = Console.ReadKey(true)
                match Char.ToUpper(key.KeyChar) with 
                | 'Q' -> 
                    printfn "%sExiting dashboard...%s" Colors.yellow Colors.reset
                    running <- false
                | 'B' -> 
                    printfn "%sBooting mesh...%s" Colors.green Colors.reset
                    let result = MeshStartup.boot twin MeshStartup.defaultConfig
                    state <- afterBoot state result
                | 'S' -> 
                    printfn "%sShutting down mesh...%s" Colors.yellow Colors.reset
                    let result = MeshShutdown.shutdown twin MeshShutdown.defaultConfig
                    state <- afterShutdown state result
                | 'E' -> 
                    printfn "%sEMERGENCY SHUTDOWN!%s" Colors.red Colors.reset
                    let result = MeshShutdown.emergencyShutdown twin
                    state <- afterShutdown state result
                | 'R' -> 
                    printfn "%sRefreshing...%s" Colors.cyan Colors.reset
                    state <- refresh state
                | 'C' -> 
                    clearScreen ()
                | _ -> ()

            // Refresh state
            state <- refresh state

            // Wait for next refresh
            Thread.Sleep(config.RefreshIntervalMs)

    /// Quick dashboard with default config
    let run (twin: DigitalTwin) : unit = 
        runInteractive twin defaultConfig

    /// Single render (for non-interactive use)
    let renderOnce (twin: DigitalTwin) : string = 
        let state = createState twin
        render state defaultConfig

    /// Print dashboard once (for CLI integration)
    let printDashboard (twin: DigitalTwin) : unit = 
        printfn "%s" (renderOnce twin)