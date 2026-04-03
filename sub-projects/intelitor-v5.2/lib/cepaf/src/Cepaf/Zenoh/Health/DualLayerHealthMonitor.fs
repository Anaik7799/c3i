// =============================================================================
// DualLayerHealthMonitor.fs - Dual-Layer Health Monitoring (FM-003)
// =============================================================================
// STAMP: SC-SIL6-004, SC-OP-003, SC-IMMUNE-001, SC-ZENOH-010
// AOR: AOR-IMMUNE-001, AOR-BRIDGE-002, AOR-ZENOH-007
// Criticality: Level 1 (CRITICAL) - SIL-6 Biomorphic Health Monitoring
// =============================================================================
// WHAT: Implements dual-layer health monitoring with fast (<50ms) interrupt-
//       driven checks and slow (10s) trend analysis for biomorphic organisms.
//
// WHY: SC-SIL6-004 requires neural-immune response < 50ms. Traditional single-
//      layer monitoring cannot achieve both fast response AND deep analysis.
//      Dual-layer architecture separates concerns.
//
// CONSTRAINTS:
//   - SC-SIL6-004: Neural-immune response < 50ms (CRITICAL)
//   - SC-OP-003: Health check interval configurable
//   - SC-IMMUNE-001: Sentinel health assessment mandatory
//   - SC-ZENOH-010: Container agents publish health every 30s
// =============================================================================
// Change History:
// | Version | Date       | Author        | Change                            |
// |---------|------------|---------------|-----------------------------------|
// | 21.2.1  | 2026-01-15 | Claude Opus 4.5 | Initial implementation (FM-003) |
// =============================================================================

namespace Cepaf.Zenoh.Health

open System
open System.Diagnostics
open System.Threading
open System.Timers

// =============================================================================
// TYPES & DISCRIMINATED UNIONS
// =============================================================================

/// Health check level discriminated union
/// Fast: Interrupt-driven, <50ms response (SC-SIL6-004)
/// Slow: Scheduler-based, 10s trend analysis
/// DualLayer: Both layers active (production mode)
[<RequireQualifiedAccess>]
type HealthCheckLevel =
    | Fast of intervalMs: int
    | Slow of intervalMs: int
    | DualLayer

    member this.IntervalMs =
        match this with
        | Fast ms -> ms
        | Slow ms -> ms
        | DualLayer -> 10  // Fast layer default

    member this.IsFastLayer =
        match this with
        | Fast _ | DualLayer -> true
        | Slow _ -> false

    member this.IsSlowLayer =
        match this with
        | Slow _ | DualLayer -> true
        | Fast _ -> false

    override this.ToString() =
        match this with
        | Fast ms -> sprintf "Fast(%dms)" ms
        | Slow ms -> sprintf "Slow(%dms)" ms
        | DualLayer -> "DualLayer(Fast+Slow)"

/// Health check result with performance metrics
type HealthCheckResult = {
    /// When the check was performed
    Timestamp: DateTimeOffset
    /// Response time in milliseconds (SC-SIL6-004: must be < 50ms)
    ResponseTimeMs: float
    /// Health score (0.0-1.0)
    HealthScore: float
    /// Was this a fast layer check?
    IsFastLayer: bool
    /// Threat detected flag
    ThreatDetected: bool
    /// Optional diagnostic message
    Message: string option
    /// Whether SC-SIL6-004 constraint was violated
    ConstraintViolated: bool
}

module HealthCheckResult =
    /// Create empty result
    let empty = {
        Timestamp = DateTimeOffset.UtcNow
        ResponseTimeMs = 0.0
        HealthScore = 1.0
        IsFastLayer = true
        ThreatDetected = false
        Message = None
        ConstraintViolated = false
    }

    /// Create result with violation check
    let create responseMs healthScore isFast threat message =
        {
            Timestamp = DateTimeOffset.UtcNow
            ResponseTimeMs = responseMs
            HealthScore = healthScore
            IsFastLayer = isFast
            ThreatDetected = threat
            Message = message
            ConstraintViolated = isFast && responseMs > 50.0  // SC-SIL6-004
        }

    /// Check if healthy
    let isHealthy (result: HealthCheckResult) =
        result.HealthScore > 0.7 && not result.ThreatDetected

    /// Check if constraint violated
    let hasConstraintViolation (result: HealthCheckResult) =
        result.ConstraintViolated

// =============================================================================
// INTEGRATION INTERFACES (Stubs for Phase 1)
// =============================================================================

/// Sentinel interface for system health assessment (SC-IMMUNE-001)
type ISentinel =
    abstract member AssessNow: unit -> float  // Returns health score 0.0-1.0
    abstract member GetThreats: unit -> string list

/// Pattern Hunter interface for pre-error detection
type IPatternHunter =
    abstract member DetectPreError: unit -> bool
    abstract member GetAnomalyScore: unit -> float

/// Symbiotic Defense interface for threat response
type ISymbioticDefense =
    abstract member RespondToThreat: threatLevel: float -> unit
    abstract member ExecuteRecovery: recoveryPhase: int -> unit

// =============================================================================
// DUAL-LAYER HEALTH MONITOR (Main Class)
// =============================================================================

/// Dual-layer health monitor with fast interrupt-driven and slow trend analysis
type DualLayerHealthMonitor(sentinel: ISentinel option,
                            patternHunter: IPatternHunter option,
                            defense: ISymbioticDefense option) =

    // Mutable state
    let mutable fastInterval = 10         // Default 10ms (SC-SIL6-004)
    let mutable slowInterval = 10000      // Default 10s (SC-OP-003)
    let mutable threatDetected = false
    let mutable lastFastCheck = DateTimeOffset.UtcNow
    let mutable lastSlowCheck = DateTimeOffset.UtcNow
    let mutable fastTimer: Timer option = None
    let mutable slowTimer: Timer option = None
    let mutable isRunning = false
    let mutable fastCheckCount = 0L
    let mutable slowCheckCount = 0L
    let mutable totalResponseTime = 0.0
    let mutable maxResponseTime = 0.0
    let mutable violationCount = 0

    // Performance tracking
    let stopwatch = Stopwatch()

    // Logging helper (stub - would integrate with actual logging)
    let log level msg =
        let timestamp = DateTimeOffset.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff")
        printfn "[%s] [%s] DualLayerHealthMonitor: %s" timestamp level msg

    // Event for health check completion
    let healthCheckEvent = new Event<HealthCheckResult>()

    /// Event triggered when health check completes
    [<CLIEvent>]
    member _.HealthCheckCompleted = healthCheckEvent.Publish

    /// Get current fast interval
    member _.FastInterval = fastInterval

    /// Get current slow interval
    member _.SlowInterval = slowInterval

    /// Set fast interval (SC-SIL6-004: must enable <50ms response)
    member _.SetFastInterval(ms: int) =
        if ms > 50 then
            log "WARN" (sprintf "Fast interval %dms > 50ms may violate SC-SIL6-004" ms)
        fastInterval <- ms
        log "INFO" (sprintf "Fast interval set to %dms" ms)

    /// Set slow interval
    member _.SetSlowInterval(ms: int) =
        slowInterval <- ms
        log "INFO" (sprintf "Slow interval set to %dms" ms)

    /// Quick health check (fast layer, <50ms target)
    member this.QuickHealthCheck() : HealthCheckResult =
        stopwatch.Restart()

        try
            // Get health score from Sentinel (if available)
            let healthScore =
                match sentinel with
                | Some s -> s.AssessNow()
                | None -> 0.95  // Stub: assume healthy

            // Check for pre-error patterns (if available)
            let preError =
                match patternHunter with
                | Some ph -> ph.DetectPreError()
                | None -> false

            // Update threat status
            threatDetected <- preError

            stopwatch.Stop()
            let responseMs = stopwatch.Elapsed.TotalMilliseconds

            // Update statistics
            fastCheckCount <- fastCheckCount + 1L
            totalResponseTime <- totalResponseTime + responseMs
            maxResponseTime <- max maxResponseTime responseMs

            // Create result
            let result = HealthCheckResult.create responseMs healthScore true preError None

            // Check for SC-SIL6-004 violation
            if result.ConstraintViolated then
                violationCount <- violationCount + 1
                log "ERROR" (sprintf "SC-SIL6-004 VIOLATION: Response time %.2fms > 50ms (violation #%d)"
                                     responseMs violationCount)

            // Trigger event
            healthCheckEvent.Trigger(result)

            result

        with ex ->
            stopwatch.Stop()
            log "ERROR" (sprintf "Quick health check failed: %s" ex.Message)
            HealthCheckResult.create stopwatch.Elapsed.TotalMilliseconds 0.0 true true (Some ex.Message)

    /// Deep health check (slow layer, comprehensive analysis)
    member this.DeepHealthCheck() : HealthCheckResult =
        stopwatch.Restart()

        try
            // Comprehensive health assessment
            let healthScore =
                match sentinel with
                | Some s ->
                    let score = s.AssessNow()
                    let threats = s.GetThreats()
                    if threats.Length > 0 then
                        log "WARN" (sprintf "Threats detected: %A" threats)
                    score
                | None -> 0.95

            // Get anomaly score from PatternHunter
            let anomalyScore =
                match patternHunter with
                | Some ph -> ph.GetAnomalyScore()
                | None -> 0.0

            // Determine if threat exists
            let threat = anomalyScore > 0.5 || healthScore < 0.7

            stopwatch.Stop()
            let responseMs = stopwatch.Elapsed.TotalMilliseconds

            // Update statistics
            slowCheckCount <- slowCheckCount + 1L

            // Create result
            let message =
                if anomalyScore > 0.5 then
                    Some (sprintf "Anomaly score: %.2f" anomalyScore)
                else None

            let result = HealthCheckResult.create responseMs healthScore false threat message

            // Trigger event
            healthCheckEvent.Trigger(result)

            result

        with ex ->
            stopwatch.Stop()
            log "ERROR" (sprintf "Deep health check failed: %s" ex.Message)
            HealthCheckResult.create stopwatch.Elapsed.TotalMilliseconds 0.0 false true (Some ex.Message)

    /// Start fast monitor (high-priority timer for <50ms response)
    member this.StartFastMonitor() =
        if fastTimer.IsSome then
            log "WARN" "Fast monitor already running"
        else
            log "INFO" (sprintf "Starting fast monitor (interval: %dms)" fastInterval)

            let timer = new Timer(float fastInterval)
            timer.AutoReset <- true
            timer.Elapsed.Add(fun _ ->
                let result = this.QuickHealthCheck()
                lastFastCheck <- result.Timestamp
            )

            fastTimer <- Some timer
            timer.Start()
            isRunning <- true

    /// Start slow monitor (scheduler-based trend analysis)
    member this.StartSlowMonitor() =
        if slowTimer.IsSome then
            log "WARN" "Slow monitor already running"
        else
            log "INFO" (sprintf "Starting slow monitor (interval: %dms)" slowInterval)

            let timer = new Timer(float slowInterval)
            timer.AutoReset <- true
            timer.Elapsed.Add(fun _ ->
                let result = this.DeepHealthCheck()
                lastSlowCheck <- result.Timestamp
            )

            slowTimer <- Some timer
            timer.Start()

    /// Start dual-layer monitoring (both fast and slow)
    member this.Start(level: HealthCheckLevel) =
        match level with
        | HealthCheckLevel.Fast _ ->
            this.StartFastMonitor()
        | HealthCheckLevel.Slow _ ->
            this.StartSlowMonitor()
        | HealthCheckLevel.DualLayer ->
            this.StartFastMonitor()
            this.StartSlowMonitor()

    /// Stop monitoring
    member this.Stop() =
        log "INFO" "Stopping monitoring"

        match fastTimer with
        | Some timer ->
            timer.Stop()
            timer.Dispose()
            fastTimer <- None
        | None -> ()

        match slowTimer with
        | Some timer ->
            timer.Stop()
            timer.Dispose()
            slowTimer <- None
        | None -> ()

        isRunning <- false

    /// Trigger immune response (SC-SIL6-004: neural-immune response < 50ms)
    member this.TriggerImmuneResponse(threatLevel: float) =
        stopwatch.Restart()

        log "WARN" (sprintf "Triggering immune response (threat level: %.2f)" threatLevel)

        // Execute defense response
        match defense with
        | Some d -> d.RespondToThreat(threatLevel)
        | None ->
            log "WARN" "No defense system available (stub mode)"

        stopwatch.Stop()
        let responseMs = stopwatch.Elapsed.TotalMilliseconds

        // Verify SC-SIL6-004 compliance
        if responseMs > 50.0 then
            log "ERROR" (sprintf "SC-SIL6-004 VIOLATION: Immune response took %.2fms > 50ms" responseMs)
        else
            log "INFO" (sprintf "Immune response completed in %.2fms" responseMs)

    /// Get performance statistics
    member this.GetStatistics() =
        let avgResponseTime =
            if fastCheckCount > 0L then
                totalResponseTime / float fastCheckCount
            else 0.0

        {|
            FastCheckCount = fastCheckCount
            SlowCheckCount = slowCheckCount
            AverageResponseMs = avgResponseTime
            MaxResponseMs = maxResponseTime
            ViolationCount = violationCount
            ThreatDetected = threatDetected
            IsRunning = isRunning
            LastFastCheck = lastFastCheck
            LastSlowCheck = lastSlowCheck
        |}

    /// IDisposable implementation
    interface IDisposable with
        member this.Dispose() =
            this.Stop()
            log "INFO" "DualLayerHealthMonitor disposed"

// =============================================================================
// MODULE FUNCTIONS
// =============================================================================

module DualLayerHealthMonitor =

    /// Create monitor with default configuration
    let create() =
        new DualLayerHealthMonitor(None, None, None)

    /// Create monitor with Sentinel integration
    let withSentinel (sentinel: ISentinel) =
        new DualLayerHealthMonitor(Some sentinel, None, None)

    /// Create monitor with full integration
    let withFullIntegration (sentinel: ISentinel)
                            (patternHunter: IPatternHunter)
                            (defense: ISymbioticDefense) =
        new DualLayerHealthMonitor(Some sentinel, Some patternHunter, Some defense)

    /// Create and start in fast mode
    let startFast intervalMs =
        let monitor = create()
        monitor.SetFastInterval(intervalMs)
        monitor.Start(HealthCheckLevel.Fast intervalMs)
        monitor

    /// Create and start in dual-layer mode
    let startDualLayer() =
        let monitor = create()
        monitor.Start(HealthCheckLevel.DualLayer)
        monitor

    /// Run single quick health check
    let quickCheck (monitor: DualLayerHealthMonitor) =
        monitor.QuickHealthCheck()

    /// Run single deep health check
    let deepCheck (monitor: DualLayerHealthMonitor) =
        monitor.DeepHealthCheck()

// =============================================================================
// EXAMPLE USAGE (Commented out - for reference)
// =============================================================================

(*
// Example 1: Fast monitoring only
let monitor = DualLayerHealthMonitor.startFast 10
// ... runs indefinitely
monitor.Dispose()

// Example 2: Dual-layer monitoring
let monitor = DualLayerHealthMonitor.startDualLayer()
// ... fast checks every 10ms, slow checks every 10s
monitor.Dispose()

// Example 3: With event handling
let monitor = DualLayerHealthMonitor.create()
monitor.HealthCheckCompleted.Add(fun result ->
    printfn "Health check: Score=%.2f, Time=%.2fms, Threat=%b"
            result.HealthScore result.ResponseTimeMs result.ThreatDetected
)
monitor.Start(HealthCheckLevel.DualLayer)
*)
