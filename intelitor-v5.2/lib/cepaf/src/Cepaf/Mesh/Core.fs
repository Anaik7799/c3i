// =============================================================================
// Core.fs - SIL-6 Mesh Shared Types and Utilities
// =============================================================================
// STAMP: SC-CONSOL-007, SC-CONSOL-008, SC-MESH-001
// AOR: AOR-MESH-001 to AOR-MESH-010
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-18 |
// | Author | Claude Opus 4.5 |
// | Reference | ENHANCED_SIL6_STARTUP_PLAN.md |
//
// ## Purpose
// This module consolidates shared types and utilities used across:
// - SIL6MeshOrchestrator.fsx
// - ComprehensiveStartupOrchestrator.fsx
// - RuntimeTestOrchestrator.fsx
// - All compiled Mesh/*.fs modules
//
// ## STAMP Compliance
// - SC-CONSOL-007: Orchestrator code MUST use Mesh.Core.fs
// - SC-CONSOL-008: Boot model MUST be unified (single phase enum)
// =============================================================================

namespace Cepaf.Mesh

open System
open Cepaf.Observability.ConsoleChannel

/// <summary>
/// Unified boot phase enum for all orchestrators
/// SC-CONSOL-008: Single phase enum across all boot models
/// </summary>
/// <remarks>
/// Unifies:
/// - SIL6Mesh: S0_Preflight, S1_Infrastructure, S2_ZenohMesh, S3_AppSeed, S4_Homeostasis
/// - CompStart: G0-G7 gates
/// - RuntimeTest: Phases
/// </remarks>
type BootPhase =
    /// Environment validation, port scouring, cleanup
    | Preflight
    /// Database + Observability containers
    | Foundation
    /// Zenoh routers (2oo3 quorum)
    | Mesh
    /// CEPAF Bridge + Cortex
    | Cognitive
    /// Application nodes
    | Application
    /// Health verification, quorum check
    | Homeostasis
    /// HA replicas + satellites
    | Swarm

/// <summary>
/// Mesh operation mode
/// </summary>
type MeshMode =
    | Dev       // db + obs + app-1
    | Cluster   // db + obs + app-1 + app-2
    | Fractal   // db + obs + app-1 + app-2 + app-3 (Full)
    | SIL6      // 16-container SIL-6 biomorphic full mesh

module MeshMode =
    let fromString (s: string) =
        match s.ToLowerInvariant() with
        | "dev" -> Dev
        | "cluster" -> Cluster
        | "fractal" -> Fractal
        | "sil6" | "sil-6" | "full" | "biomorphic" -> SIL6
        | _ -> Fractal // Default to full mesh

/// <summary>
/// Fractal layer for verification hierarchy (L0-L7)
/// SC-FUNC-000: Fractal consistency rule enforcement
/// </summary>
type FractalLayer =
    /// Runtime: System compiles and boots
    | L0_Runtime
    /// Function: I/O contracts valid
    | L1_Function
    /// Component: Module cohesion
    | L2_Component
    /// Holon: Agent logic sound
    | L3_Holon
    /// Container: Isolation maintained
    | L4_Container
    /// Node: Runtime stable
    | L5_Node
    /// Cluster: Consensus holds
    | L6_Cluster
    /// Federation: Global invariants
    | L7_Federation

/// <summary>
/// Quorum status for distributed consensus
/// SC-SIL4-006: 2oo3 voting MANDATORY
/// </summary>
type QuorumStatus =
    /// Quorum achieved: (healthy count, total count)
    | Achieved of healthy: int * total: int
    /// Quorum not achieved: (healthy count, total count)
    | NotAchieved of healthy: int * total: int
    /// Not enough nodes to form quorum
    | InsufficientNodes of count: int

/// <summary>
/// Boot-style log levels for Linux-style startup output
/// </summary>
type BootLogLevel =
    | KERNEL
    | BOOT
    | STAGE
    | HEALTH
    | QUORUM
    | ZENOH
    | BIO
    | MESH
    | FRACTAL
    | CORTEX
    | SWARM
    | OBS
    | MULTIVERSE
    | INFO
    | WARN
    | ERROR

/// <summary>
/// Network naming scheme for multi-environment deployments
/// </summary>
type NetworkScheme =
    /// Tailscale MagicDNS: {service}-{host}.{tailnet}.ts.net
    | Tailscale
    /// Kubernetes: {service}.{namespace}.svc.cluster.local
    | Kubernetes
    /// Podman: container names
    | Podman
    /// Local: localhost with port mapping
    | Local

/// <summary>
/// Service definition with all naming schemes
/// </summary>
type ServiceDef = {
    Name: string
    Port: int
    TailscaleService: string
    KubernetesService: string
    PodmanContainer: string
    LocalHost: string
    HealthPath: string
}

/// <summary>
/// Test criticality levels
/// </summary>
type TestCriticality =
    | P0_Critical
    | P1_High
    | P2_Medium
    | P3_Low

/// <summary>
/// Test status for smoke tests
/// </summary>
type TestStatus =
    | Passed
    | Failed of reason: string
    | Skipped of reason: string
    | Timeout

/// <summary>
/// Test category for enhanced smoke tests
/// </summary>
type TestCategory =
    | API
    | Database
    | Zenoh
    | Performance
    | Security
    | Resilience
    | Integration

/// <summary>
/// Enhanced test result with metrics
/// </summary>
type EnhancedTestResult = {
    TestId: string
    TestName: string
    Category: TestCategory
    Criticality: TestCriticality
    Status: TestStatus
    Duration: TimeSpan
    Details: string
    Metrics: Map<string, obj>
    Evidence: string list
}

// =============================================================================
// PHASE 5: Enhanced Logging Types (SC-LOG-001 to SC-LOG-010)
// =============================================================================

/// <summary>
/// Verbosity level for configurable output
/// SC-LOG-001: Configurable verbosity for different use cases
/// </summary>
type VerbosityLevel =
    /// [OK]/[FAIL] only - for CI/CD pipelines
    | Minimal
    /// Name + result + duration (default) - for development
    | Standard
    /// Full details + metrics - for debugging
    | Verbose
    /// All internal state + stack traces - for deep debugging
    | Debug

/// <summary>
/// Test evidence for failure debugging
/// SC-LOG-002: Evidence collection for failure analysis
/// </summary>
type TestEvidence = {
    Timestamp: DateTimeOffset
    TestId: string
    Request: string option
    Response: string option
    StackTrace: string option
    EnvironmentVars: Map<string, string>
    SystemState: Map<string, string>
    ContainerLogs: Map<string, string>
}

/// <summary>
/// Captured metrics for performance tracking
/// SC-LOG-003: Metrics capture for performance analysis
/// </summary>
type CapturedMetrics = {
    TestId: string
    StartTime: DateTimeOffset
    EndTime: DateTimeOffset
    DurationMs: int64
    MemoryUsageMB: float
    CpuPercent: float
    NetworkBytesIn: int64
    NetworkBytesOut: int64
    DiskIOReads: int64
    DiskIOWrites: int64
    CustomMetrics: Map<string, obj>
}

/// <summary>
/// Boot metrics summary
/// SC-LOG-004: Boot performance metrics
/// </summary>
type BootMetrics = {
    TotalDurationMs: int64
    PhaseDurations: Map<string, int64>
    ContainerStartTimes: Map<string, int64>
    HealthCheckLatencies: Map<string, int64>
    QuorumAchievedAt: DateTimeOffset option
    TestsRun: int
    TestsPassed: int
    TestsFailed: int
    CriticalPathDuration: int64
}

/// <summary>
/// Structured log entry for enhanced logging
/// SC-LOG-005: Structured log entries
/// </summary>
type StructuredLogEntry = {
    Timestamp: DateTimeOffset
    Level: BootLogLevel
    Phase: BootPhase option
    Container: string option
    Message: string
    Metrics: Map<string, obj>
    CorrelationId: string option
}

/// <summary>
/// Colors module - alias to centralized AnsiColors
/// SC-CONSOL-003: All ANSI colors MUST come from ConsoleChannel.AnsiColors
/// </summary>
module Colors =
    // Re-export from ConsoleChannel.AnsiColors for convenience
    let reset = AnsiColors.reset
    let bold = AnsiColors.bold
    let dim = AnsiColors.dim
    let italic = AnsiColors.italic
    let underline = AnsiColors.underline
    let red = AnsiColors.red
    let green = AnsiColors.green
    let yellow = AnsiColors.yellow
    let blue = AnsiColors.blue
    let magenta = AnsiColors.magenta
    let cyan = AnsiColors.cyan
    let white = AnsiColors.white
    let brightRed = AnsiColors.brightRed
    let brightGreen = AnsiColors.brightGreen
    let brightYellow = AnsiColors.brightYellow
    let brightBlue = AnsiColors.brightBlue
    let brightMagenta = AnsiColors.brightMagenta
    let brightCyan = AnsiColors.brightCyan
    let brightWhite = AnsiColors.brightWhite
    let bgRed = AnsiColors.bgRed
    let bgGreen = AnsiColors.bgGreen
    let bgYellow = AnsiColors.bgYellow
    let bgBlue = AnsiColors.bgBlue

/// <summary>
/// Shared constants for mesh orchestration
/// </summary>
module MeshConstants =
    /// Default Zenoh router port
    let zenohPort = 7447

    /// Default Phoenix port
    let phoenixPort = 4000

    /// Default PostgreSQL port
    let postgresPort = 5433

    /// Default OTEL gRPC port
    let otelGrpcPort = 4317

    /// Default OTEL HTTP port
    let otelHttpPort = 4318

    /// Default Prometheus port
    let prometheusPort = 9090

    /// Default Grafana port
    let grafanaPort = 3000

    /// Default Loki port
    let lokiPort = 3100

    /// Quorum threshold (2oo3)
    let quorumThreshold nodes = (nodes / 2) + 1

    /// Health check timeout (ms)
    let healthCheckTimeout = 5000

    /// Boot timeout (ms) - SC-OPT-001: < 60s
    let bootTimeout = 60_000

    /// Exponential backoff intervals (ms)
    let backoffIntervals = [| 100; 200; 400; 800; 1600; 3200; 5000 |]

/// <summary>
/// Utility functions for mesh operations
/// </summary>
module MeshUtils =
    /// Calculate quorum status from node health counts
    let calculateQuorum (healthyCount: int) (totalCount: int) : QuorumStatus =
        if totalCount < 2 then
            InsufficientNodes totalCount
        else
            let required = MeshConstants.quorumThreshold totalCount
            if healthyCount >= required then
                Achieved (healthyCount, totalCount)
            else
                NotAchieved (healthyCount, totalCount)

    /// Check if quorum is achieved
    let isQuorumAchieved (status: QuorumStatus) : bool =
        match status with
        | Achieved _ -> true
        | _ -> false

    /// Get human-readable status string
    let quorumStatusString (status: QuorumStatus) : string =
        match status with
        | Achieved (h, t) -> sprintf "✓ Quorum achieved: %d/%d healthy" h t
        | NotAchieved (h, t) -> sprintf "✗ Quorum NOT achieved: %d/%d healthy (need %d)" h t (MeshConstants.quorumThreshold t)
        | InsufficientNodes n -> sprintf "⚠ Insufficient nodes: %d" n

    /// Get color for boot log level
    let levelColor (level: BootLogLevel) : string =
        match level with
        | KERNEL | BOOT -> Colors.brightCyan
        | STAGE -> Colors.cyan
        | HEALTH -> Colors.green
        | QUORUM -> Colors.brightGreen
        | ZENOH -> Colors.blue
        | BIO -> Colors.magenta
        | MESH -> Colors.brightMagenta
        | FRACTAL -> Colors.yellow
        | CORTEX -> Colors.brightBlue
        | SWARM -> Colors.cyan
        | OBS -> Colors.white
        | MULTIVERSE -> Colors.magenta
        | INFO -> Colors.white
        | WARN -> Colors.yellow
        | ERROR -> Colors.brightRed

    /// Get color for status string
    let statusColor (status: string) : string =
        match status.ToUpperInvariant() with
        | "OK" | "PASS" | "READY" | "ONLINE" | "HEALTHY" -> Colors.brightGreen
        | "RUN" | "STARTING" | "CHECKING" | "BUILD" | "SYNC" -> Colors.brightCyan
        | "WAIT" | "PENDING" -> Colors.brightYellow
        | "FAIL" | "ERROR" | "CRITICAL" -> Colors.brightRed
        | "WARN" | "DEGRADED" -> Colors.yellow
        | "FIX" | "HEAL" -> Colors.brightMagenta
        | "ZENOH" -> Colors.blue
        | _ -> Colors.white

    /// Format timestamp for console output
    let formatTimestamp () : string =
        DateTimeOffset.UtcNow.ToString("HH:mm:ss.fff")

    /// Print a banner for section headers
    let printBanner (title: string) : unit =
        printfn ""
        printfn "%s%s╔═══════════════════════════════════════════════════════════════════════════════╗%s" Colors.brightMagenta Colors.bold Colors.reset
        printfn "%s%s║  %-77s║%s" Colors.brightMagenta Colors.bold title Colors.reset
        printfn "%s%s╚═══════════════════════════════════════════════════════════════════════════════╝%s" Colors.brightMagenta Colors.bold Colors.reset
        printfn ""

    /// Print a separator line
    let printSeparator () : unit =
        printfn "%s──────────────────────────────────────────────────────────────────────────────────%s" Colors.dim Colors.reset

    /// Log a boot-style message
    let logBoot (level: BootLogLevel) (stage: string) (status: string) (message: string) : unit =
        let ts = formatTimestamp()
        let lvl =
            match level with
            | KERNEL -> "KERNEL"
            | BOOT -> "BOOT"
            | STAGE -> "STAGE"
            | HEALTH -> "HEALTH"
            | QUORUM -> "QUORUM"
            | ZENOH -> "ZENOH"
            | BIO -> "BIO"
            | MESH -> "MESH"
            | FRACTAL -> "FRACTAL"
            | CORTEX -> "CORTEX"
            | SWARM -> "SWARM"
            | OBS -> "OBS"
            | MULTIVERSE -> "MULTIVERSE"
            | INFO -> "INFO"
            | WARN -> "WARN"
            | ERROR -> "ERROR"
        let color = statusColor status
        printfn "%s[%s]%s %s[%-10s]%s %-14s [%s%-8s%s] %s"
            Colors.dim ts Colors.reset
            Colors.cyan lvl Colors.reset
            stage
            color status Colors.reset
            message

/// <summary>
/// Fractal layer utilities
/// </summary>
module FractalUtils =
    /// Get layer name
    let layerName (layer: FractalLayer) : string =
        match layer with
        | L0_Runtime -> "L0_Runtime"
        | L1_Function -> "L1_Function"
        | L2_Component -> "L2_Component"
        | L3_Holon -> "L3_Holon"
        | L4_Container -> "L4_Container"
        | L5_Node -> "L5_Node"
        | L6_Cluster -> "L6_Cluster"
        | L7_Federation -> "L7_Federation"

    /// Get layer description
    let layerDescription (layer: FractalLayer) : string =
        match layer with
        | L0_Runtime -> "System compiles and boots without error"
        | L1_Function -> "I/O contracts are valid"
        | L2_Component -> "Modules are cohesive"
        | L3_Holon -> "Agent logic is sound"
        | L4_Container -> "Isolation is maintained"
        | L5_Node -> "Runtime environment is stable"
        | L6_Cluster -> "Consensus holds"
        | L7_Federation -> "Global invariants hold"

    /// Get all layers in order
    let allLayers : FractalLayer list = [
        L0_Runtime
        L1_Function
        L2_Component
        L3_Holon
        L4_Container
        L5_Node
        L6_Cluster
        L7_Federation
    ]

    /// Print fractal state
    let printFractalState (verifiedLayers: Set<FractalLayer>) : unit =
        printfn ""
        printfn "%s%sFRACTAL STATE:%s" Colors.cyan Colors.bold Colors.reset
        for layer in allLayers do
            let status =
                if Set.contains layer verifiedLayers then
                    sprintf "%s✓ VERIFIED%s" Colors.green Colors.reset
                else
                    sprintf "%s✗ PENDING%s" Colors.red Colors.reset
            printfn "  %-20s: %s" (layerName layer) status

/// <summary>
/// Boot phase utilities
/// </summary>
module BootPhaseUtils =
    /// Get phase name
    let phaseName (phase: BootPhase) : string =
        match phase with
        | Preflight -> "Preflight"
        | Foundation -> "Foundation"
        | Mesh -> "Mesh"
        | Cognitive -> "Cognitive"
        | Application -> "Application"
        | Homeostasis -> "Homeostasis"
        | Swarm -> "Swarm"

    /// Get phase description
    let phaseDescription (phase: BootPhase) : string =
        match phase with
        | Preflight -> "Environment validation, port scouring, cleanup"
        | Foundation -> "Database + Observability containers"
        | Mesh -> "Zenoh routers (2oo3 quorum)"
        | Cognitive -> "CEPAF Bridge + Cortex"
        | Application -> "Application nodes"
        | Homeostasis -> "Health verification, quorum check"
        | Swarm -> "HA replicas + satellites"

    /// Get all phases in order
    let allPhases : BootPhase list = [
        Preflight
        Foundation
        Mesh
        Cognitive
        Application
        Homeostasis
        Swarm
    ]

    /// Map old SIL6Mesh stages to unified phases
    let fromSIL6Stage (stage: string) : BootPhase option =
        match stage with
        | "S0_PREFLIGHT" -> Some Preflight
        | "S1_INFRASTRUCTURE" -> Some Foundation
        | "S2_ZENOH_MESH" -> Some Mesh
        | "S3_APP_SEED" -> Some Application
        | "S4_HOMEOSTASIS" -> Some Homeostasis
        | _ -> None

    /// Map old CompStart gates to unified phases
    let fromCompStartGate (gate: string) : BootPhase option =
        match gate with
        | "G0-Environment" | "G1-Environment" -> Some Preflight
        | "G2-Build" -> Some Preflight
        | "G3-Migrations" -> Some Foundation
        | "G4-Infrastructure" -> Some Foundation
        | "G5-Quorum" -> Some Mesh
        | "G6-AppHealth" -> Some Application
        | "G7-FPPS" -> Some Homeostasis
        | _ -> None

// =============================================================================
// PHASE 5: Enhanced Logging Modules (SC-LOG-001 to SC-LOG-010)
// =============================================================================

/// <summary>
/// Verbosity utilities for configurable output formatting
/// SC-LOG-006: Output formatting based on verbosity level
/// </summary>
module VerbosityUtils =
    open System.Text.Json

    /// Mutable verbosity level (set via CLI)
    let mutable currentVerbosity = Standard

    /// Set the global verbosity level
    let setVerbosity (level: VerbosityLevel) : unit =
        currentVerbosity <- level

    /// Parse verbosity from CLI argument
    let parseVerbosity (arg: string) : VerbosityLevel =
        match arg.ToLowerInvariant() with
        | "minimal" | "min" | "m" | "0" -> Minimal
        | "standard" | "std" | "s" | "1" -> Standard
        | "verbose" | "verb" | "v" | "2" -> Verbose
        | "debug" | "dbg" | "d" | "3" -> Debug
        | _ -> Standard

    /// Format test result based on verbosity
    let formatTestResult (result: EnhancedTestResult) : string =
        match currentVerbosity with
        | Minimal ->
            let status = match result.Status with
                         | Passed -> "[OK]"
                         | Failed _ -> "[FAIL]"
                         | Skipped _ -> "[SKIP]"
                         | Timeout -> "[TIMEOUT]"
            sprintf "%s %s" status result.TestId

        | Standard ->
            let status = match result.Status with
                         | Passed -> sprintf "%s[✓]%s" Colors.green Colors.reset
                         | Failed r -> sprintf "%s[✗]%s %s" Colors.red Colors.reset r
                         | Skipped r -> sprintf "%s[⊘]%s %s" Colors.yellow Colors.reset r
                         | Timeout -> sprintf "%s[⏱]%s" Colors.yellow Colors.reset
            sprintf "  [%s] %-40s %s %dms" result.TestId result.TestName status (int result.Duration.TotalMilliseconds)

        | Verbose ->
            let status = match result.Status with
                         | Passed -> sprintf "%s[✓ PASSED]%s" Colors.green Colors.reset
                         | Failed r -> sprintf "%s[✗ FAILED]%s %s" Colors.red Colors.reset r
                         | Skipped r -> sprintf "%s[⊘ SKIPPED]%s %s" Colors.yellow Colors.reset r
                         | Timeout -> sprintf "%s[⏱ TIMEOUT]%s" Colors.yellow Colors.reset
            let sb = System.Text.StringBuilder()
            sb.AppendLine(sprintf "  ┌─ %s: %s" result.TestId result.TestName) |> ignore
            sb.AppendLine(sprintf "  │  Status:      %s" status) |> ignore
            sb.AppendLine(sprintf "  │  Category:    %A" result.Category) |> ignore
            sb.AppendLine(sprintf "  │  Criticality: %A" result.Criticality) |> ignore
            sb.AppendLine(sprintf "  │  Duration:    %d ms" (int result.Duration.TotalMilliseconds)) |> ignore
            sb.AppendLine(sprintf "  │  Details:     %s" result.Details) |> ignore
            if not (Map.isEmpty result.Metrics) then
                sb.AppendLine("  │  Metrics:") |> ignore
                for kvp in result.Metrics do
                    sb.AppendLine(sprintf "  │    %s: %A" kvp.Key kvp.Value) |> ignore
            sb.AppendLine("  └──────────────────────────────────────────") |> ignore
            sb.ToString()

        | Debug ->
            let status = match result.Status with
                         | Passed -> sprintf "%s[✓ PASSED]%s" Colors.green Colors.reset
                         | Failed r -> sprintf "%s[✗ FAILED]%s %s" Colors.red Colors.reset r
                         | Skipped r -> sprintf "%s[⊘ SKIPPED]%s %s" Colors.yellow Colors.reset r
                         | Timeout -> sprintf "%s[⏱ TIMEOUT]%s" Colors.yellow Colors.reset
            let sb = System.Text.StringBuilder()
            sb.AppendLine(sprintf "╔══════════════════════════════════════════════════════════════════════════════") |> ignore
            sb.AppendLine(sprintf "║ TEST: %s" result.TestId) |> ignore
            sb.AppendLine("╠══════════════════════════════════════════════════════════════════════════════") |> ignore
            sb.AppendLine(sprintf "║ Name:        %s" result.TestName) |> ignore
            sb.AppendLine(sprintf "║ Status:      %s" status) |> ignore
            sb.AppendLine(sprintf "║ Category:    %A" result.Category) |> ignore
            sb.AppendLine(sprintf "║ Criticality: %A" result.Criticality) |> ignore
            sb.AppendLine(sprintf "║ Duration:    %d ms" (int result.Duration.TotalMilliseconds)) |> ignore
            sb.AppendLine(sprintf "║ Details:     %s" result.Details) |> ignore
            sb.AppendLine("║") |> ignore
            sb.AppendLine("║ Metrics:") |> ignore
            for kvp in result.Metrics do
                sb.AppendLine(sprintf "║   %s: %A" kvp.Key kvp.Value) |> ignore
            sb.AppendLine("║") |> ignore
            sb.AppendLine("║ Evidence:") |> ignore
            for e in result.Evidence do
                sb.AppendLine(sprintf "║   - %s" e) |> ignore
            sb.AppendLine("╚══════════════════════════════════════════════════════════════════════════════") |> ignore
            sb.ToString()

    /// Format boot metrics based on verbosity
    let formatBootMetrics (metrics: BootMetrics) : string =
        match currentVerbosity with
        | Minimal ->
            sprintf "[BOOT] %dms %d/%d tests" metrics.TotalDurationMs metrics.TestsPassed metrics.TestsRun

        | Standard ->
            sprintf "Boot: %dms | Tests: %d/%d passed | Critical Path: %dms"
                metrics.TotalDurationMs metrics.TestsPassed metrics.TestsRun metrics.CriticalPathDuration

        | Verbose | Debug ->
            let sb = System.Text.StringBuilder()
            sb.AppendLine("") |> ignore
            sb.AppendLine(sprintf "%s%sBOOT METRICS SUMMARY%s" Colors.cyan Colors.bold Colors.reset) |> ignore
            sb.AppendLine(sprintf "  Total Duration:     %d ms" metrics.TotalDurationMs) |> ignore
            sb.AppendLine(sprintf "  Critical Path:      %d ms" metrics.CriticalPathDuration) |> ignore
            sb.AppendLine(sprintf "  Tests Run:          %d" metrics.TestsRun) |> ignore
            sb.AppendLine(sprintf "  Tests Passed:       %s%d%s" Colors.green metrics.TestsPassed Colors.reset) |> ignore
            sb.AppendLine(sprintf "  Tests Failed:       %s%d%s" (if metrics.TestsFailed > 0 then Colors.red else Colors.green) metrics.TestsFailed Colors.reset) |> ignore
            sb.AppendLine("") |> ignore
            sb.AppendLine("  Phase Durations:") |> ignore
            for kvp in metrics.PhaseDurations do
                sb.AppendLine(sprintf "    %-15s: %6d ms" kvp.Key kvp.Value) |> ignore
            if currentVerbosity = Debug then
                sb.AppendLine("") |> ignore
                sb.AppendLine("  Container Start Times:") |> ignore
                for kvp in metrics.ContainerStartTimes do
                    sb.AppendLine(sprintf "    %-25s: %6d ms" kvp.Key kvp.Value) |> ignore
                sb.AppendLine("") |> ignore
                sb.AppendLine("  Health Check Latencies:") |> ignore
                for kvp in metrics.HealthCheckLatencies do
                    sb.AppendLine(sprintf "    %-25s: %6d ms" kvp.Key kvp.Value) |> ignore
            sb.ToString()

/// <summary>
/// Metrics capture utilities
/// SC-LOG-007: Capture and export performance metrics
/// </summary>
module MetricsCapture =
    open System.IO
    open System.Text.Json

    /// Mutable collection for boot metrics
    let mutable private bootStartTime = DateTimeOffset.MinValue
    let mutable private phaseDurations = Map.empty<string, int64>
    let mutable private containerStartTimes = Map.empty<string, int64>
    let mutable private healthCheckLatencies = Map.empty<string, int64>
    let mutable private testsRun = 0
    let mutable private testsPassed = 0
    let mutable private testsFailed = 0

    /// Start boot metrics capture
    let startBoot () : unit =
        bootStartTime <- DateTimeOffset.UtcNow
        phaseDurations <- Map.empty
        containerStartTimes <- Map.empty
        healthCheckLatencies <- Map.empty
        testsRun <- 0
        testsPassed <- 0
        testsFailed <- 0

    /// Record phase duration
    let recordPhase (phase: string) (durationMs: int64) : unit =
        phaseDurations <- Map.add phase durationMs phaseDurations

    /// Record container start time
    let recordContainerStart (container: string) (durationMs: int64) : unit =
        containerStartTimes <- Map.add container durationMs containerStartTimes

    /// Record health check latency
    let recordHealthCheck (endpoint: string) (latencyMs: int64) : unit =
        healthCheckLatencies <- Map.add endpoint latencyMs healthCheckLatencies

    /// Record test result
    let recordTest (passed: bool) : unit =
        testsRun <- testsRun + 1
        if passed then testsPassed <- testsPassed + 1
        else testsFailed <- testsFailed + 1

    /// Get current boot metrics
    let getBootMetrics () : BootMetrics =
        let now = DateTimeOffset.UtcNow
        let totalMs = int64 (now - bootStartTime).TotalMilliseconds
        let criticalPath =
            phaseDurations
            |> Map.toSeq
            |> Seq.sumBy snd
        {
            TotalDurationMs = totalMs
            PhaseDurations = phaseDurations
            ContainerStartTimes = containerStartTimes
            HealthCheckLatencies = healthCheckLatencies
            QuorumAchievedAt = None
            TestsRun = testsRun
            TestsPassed = testsPassed
            TestsFailed = testsFailed
            CriticalPathDuration = criticalPath
        }

    /// Export metrics to JSON file
    let exportToJson (filePath: string) : unit =
        let metrics = getBootMetrics()
        let options = JsonSerializerOptions(WriteIndented = true)
        let json = JsonSerializer.Serialize(metrics, options)
        File.WriteAllText(filePath, json)

    /// Export metrics to Zenoh topic (SC-ZTEST-008: dual-write)
    let publishToZenoh (topic: string) : unit =
        let metrics = getBootMetrics()
        let options = JsonSerializerOptions(WriteIndented = false)
        let payload = JsonSerializer.Serialize(metrics, options)
        ZenohPublish.publish
            "CP-BOOT-METRICS"
            topic
            (sprintf "Boot metrics: %d tests, %dms total" metrics.TestsRun metrics.TotalDurationMs)
            payload

/// <summary>
/// Evidence collection utilities
/// SC-LOG-008: Collect and save evidence for failure analysis
/// </summary>
module EvidenceCollection =
    open System.IO
    open System.Text.Json

    /// Create evidence for a test
    let createEvidence (testId: string) (request: string option) (response: string option) (stackTrace: string option) : TestEvidence =
        let envVars =
            Environment.GetEnvironmentVariables()
            |> Seq.cast<System.Collections.DictionaryEntry>
            |> Seq.filter (fun de ->
                let key = string de.Key
                key.StartsWith("INDRAJAAL") || key.StartsWith("ZENOH") || key.StartsWith("MIX") || key.StartsWith("ELIXIR"))
            |> Seq.map (fun de -> string de.Key, string de.Value)
            |> Map.ofSeq
        {
            Timestamp = DateTimeOffset.UtcNow
            TestId = testId
            Request = request
            Response = response
            StackTrace = stackTrace
            EnvironmentVars = envVars
            SystemState = Map.empty
            ContainerLogs = Map.empty
        }

    /// Add system state to evidence
    let addSystemState (evidence: TestEvidence) (state: Map<string, string>) : TestEvidence =
        { evidence with SystemState = state }

    /// Add container logs to evidence
    let addContainerLogs (evidence: TestEvidence) (logs: Map<string, string>) : TestEvidence =
        { evidence with ContainerLogs = logs }

    /// Save evidence to JSON file
    let saveEvidence (evidence: TestEvidence) (directory: string) : string =
        let fileName = sprintf "%s_%s.json" evidence.TestId (evidence.Timestamp.ToString("yyyyMMdd_HHmmss"))
        let filePath = Path.Combine(directory, fileName)
        Directory.CreateDirectory(directory) |> ignore
        let options = JsonSerializerOptions(WriteIndented = true)
        let json = JsonSerializer.Serialize(evidence, options)
        File.WriteAllText(filePath, json)
        filePath

    /// Load evidence from JSON file
    let loadEvidence (filePath: string) : TestEvidence option =
        if File.Exists(filePath) then
            let json = File.ReadAllText(filePath)
            Some (JsonSerializer.Deserialize<TestEvidence>(json))
        else
            None

/// <summary>
/// Enhanced logger with verbosity support
/// SC-LOG-009: Unified logging with verbosity levels
/// </summary>
module EnhancedLogger =
    open System.Collections.Concurrent

    /// Log buffer for structured logs
    let private logBuffer = ConcurrentQueue<StructuredLogEntry>()

    /// Maximum buffer size
    let private maxBufferSize = 10000

    /// Create a log entry
    let log (level: BootLogLevel) (phase: BootPhase option) (container: string option) (message: string) (metrics: Map<string, obj>) : unit =
        let entry = {
            Timestamp = DateTimeOffset.UtcNow
            Level = level
            Phase = phase
            Container = container
            Message = message
            Metrics = metrics
            CorrelationId = None
        }

        // Add to buffer
        if logBuffer.Count >= maxBufferSize then
            logBuffer.TryDequeue() |> ignore
        logBuffer.Enqueue(entry)

        // Print based on verbosity
        match VerbosityUtils.currentVerbosity with
        | Minimal ->
            match level with
            | ERROR -> printfn "[ERROR] %s" message
            | WARN -> printfn "[WARN] %s" message
            | _ -> ()
        | Standard ->
            MeshUtils.logBoot level
                (phase |> Option.map BootPhaseUtils.phaseName |> Option.defaultValue "")
                (match level with ERROR -> "ERROR" | WARN -> "WARN" | _ -> "OK")
                message
        | Verbose | Debug ->
            let ts = MeshUtils.formatTimestamp()
            let phaseStr = phase |> Option.map BootPhaseUtils.phaseName |> Option.defaultValue "-"
            let containerStr = container |> Option.defaultValue "-"
            printfn "[%s] [%-10s] [%-12s] [%-20s] %s" ts (sprintf "%A" level) phaseStr containerStr message
            if VerbosityUtils.currentVerbosity = Debug && not (Map.isEmpty metrics) then
                for kvp in metrics do
                    printfn "           %s: %A" kvp.Key kvp.Value

    /// Get all log entries
    let getLogs () : StructuredLogEntry list =
        logBuffer.ToArray() |> Array.toList

    /// Clear log buffer
    let clearLogs () : unit =
        while not logBuffer.IsEmpty do
            logBuffer.TryDequeue() |> ignore

    /// Export logs to JSON
    let exportLogs (filePath: string) : unit =
        let options = System.Text.Json.JsonSerializerOptions(WriteIndented = true)
        let json = System.Text.Json.JsonSerializer.Serialize(getLogs(), options)
        System.IO.File.WriteAllText(filePath, json)

    /// Shorthand logging functions
    let info msg = log INFO None None msg Map.empty
    let warn msg = log WARN None None msg Map.empty
    let error msg = log ERROR None None msg Map.empty
    let boot phase msg = log BOOT (Some phase) None msg Map.empty
    let container name msg = log INFO None (Some name) msg Map.empty

/// Mathematical Correctness and Information Theory utilities (SC-MATH-001 to SC-MATH-003)
module MathematicalCorrectness =
    /// Proves the Quorum Invariant: floor(N/2) + 1
    let proveQuorum total healthy =
        let required = (total / 2) + 1
        healthy >= required

    /// Calculates Shannon Entropy (H) of the system state vector
    let calculateEntropy (states: float list) =
        states 
        |> List.filter (fun p -> p > 0.0)
        |> List.map (fun p -> p * Math.Log2(p))
        |> List.sum
        |> (*) -1.0

    /// Calculates KL Divergence D_KL(P || Q) to verify intent (P) vs outcome (Q)
    let klDivergence (p: float list) (q: float list) =
        List.zip p q
        |> List.filter (fun (px, qx) -> px > 0.0 && qx > 0.0)
        |> List.map (fun (px, qx) -> px * Math.Log2(px / qx))
        |> List.sum
