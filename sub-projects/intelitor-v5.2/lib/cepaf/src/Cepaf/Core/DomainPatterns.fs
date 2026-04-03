namespace Cepaf.Core

open System

/// Domain-wide Active Patterns for semantic classification across all CEPAF modules.
/// Provides consistent pattern matching for errors, health states, containers, agents, and logs.
///
/// WHAT: Comprehensive Active Patterns for domain type classification
/// WHY: Enables semantic matching across all subsystems without coupling
/// CONSTRAINTS:
///   - SC-FSH-003: Active Patterns for classification (error/health/container)
///   - SC-FSH-012: Domain patterns must be exhaustive
///   - SC-FSH-013: Patterns must not throw exceptions
///
/// TDG Compliance:
///   - TDG-FSH-003: Each pattern tested for all branches
///   - TDG-FSH-012: Edge cases covered (empty, null, boundary)
///
/// AOR Compliance:
///   - AOR-FSH-001: Patterns used in all match expressions
///   - AOR-FSH-002: No raw string matching for classifications
module DomainPatterns =

    // =========================================================================
    // ERROR CLASSIFICATION PATTERNS (SC-FSH-003)
    // =========================================================================

    /// Classify error by recoverability - determines retry strategy
    /// Recoverable: Can retry automatically
    /// NonRecoverable: Requires human intervention
    /// Transient: Temporary, retry after delay
    let (|Recoverable|NonRecoverable|Transient|) (error: obj) =
        match error with
        | :? TimeoutException -> Transient
        | :? System.Net.Sockets.SocketException -> Transient
        | :? System.IO.IOException -> Transient
        | :? InvalidOperationException -> NonRecoverable
        | :? ArgumentException -> NonRecoverable
        | :? NotSupportedException -> NonRecoverable
        | :? NullReferenceException -> NonRecoverable
        | _ -> Recoverable

    /// Classify error by domain - determines handling module
    let (|NetworkError|StorageError|SecurityError|ValidationError|SystemError|) (errorMsg: string) =
        let msg = errorMsg.ToLowerInvariant()
        if msg.Contains("connection") || msg.Contains("socket") || msg.Contains("network") || msg.Contains("timeout") then
            NetworkError
        elif msg.Contains("disk") || msg.Contains("file") || msg.Contains("storage") || msg.Contains("database") then
            StorageError
        elif msg.Contains("permission") || msg.Contains("auth") || msg.Contains("security") || msg.Contains("credential") then
            SecurityError
        elif msg.Contains("invalid") || msg.Contains("validation") || msg.Contains("format") || msg.Contains("parse") then
            ValidationError
        else
            SystemError

    /// Classify error by severity for alerting
    let (|CriticalSeverity|HighSeverity|MediumSeverity|LowSeverity|) (severity: string) =
        match severity.ToUpperInvariant() with
        | "CRITICAL" | "EMERGENCY" | "FATAL" -> CriticalSeverity
        | "HIGH" | "ERROR" | "SEVERE" -> HighSeverity
        | "MEDIUM" | "WARNING" | "WARN" -> MediumSeverity
        | _ -> LowSeverity

    // =========================================================================
    // HEALTH CLASSIFICATION PATTERNS (SC-FSH-003)
    // =========================================================================

    /// Health status classification for monitoring decisions
    /// Operational: Normal operation, no action needed
    /// Degraded: Partially functioning, monitor closely
    /// Failed: Not functioning, requires intervention
    /// Unknown: Cannot determine state
    let (|Operational|Degraded|Failed|Unknown|) (status: string) =
        match status.ToLowerInvariant() with
        | "healthy" | "ok" | "running" | "ready" -> Operational
        | "starting" | "warming" | "degraded" | "partial" -> Degraded
        | "unhealthy" | "failed" | "error" | "dead" | "exited" -> Failed
        | _ -> Unknown

    /// Health check result pattern for probe handling
    let (|HealthPassed|HealthWarning|HealthFailed|HealthSkipped|) (exitCode: int, output: string) =
        match exitCode with
        | 0 -> HealthPassed
        | 1 -> HealthFailed
        | _ when String.IsNullOrWhiteSpace(output) -> HealthSkipped
        | _ -> HealthWarning

    /// Failing streak pattern for alerting thresholds
    let (|NoFailures|MinorFailures|MajorFailures|CriticalFailures|) (failingStreak: int) =
        match failingStreak with
        | 0 -> NoFailures
        | n when n < 3 -> MinorFailures
        | n when n < 5 -> MajorFailures
        | _ -> CriticalFailures

    // =========================================================================
    // CONTAINER STATE PATTERNS (SC-FSH-003)
    // =========================================================================

    /// Container lifecycle state classification
    let (|ContainerActive|ContainerInactive|ContainerTransitional|ContainerTerminal|) (status: string) =
        match status.ToLowerInvariant() with
        | "running" -> ContainerActive
        | "paused" | "stopped" -> ContainerInactive
        | "created" | "restarting" | "removing" -> ContainerTransitional
        | "exited" | "dead" -> ContainerTerminal
        | _ -> ContainerTransitional

    /// Container exit code classification
    let (|NormalExit|ErrorExit|SignalExit|OOMKilled|) (exitCode: int) =
        match exitCode with
        | 0 -> NormalExit
        | 137 -> OOMKilled           // Killed by OOM (128 + 9)
        | c when c >= 128 -> SignalExit  // Killed by signal
        | _ -> ErrorExit

    /// Container resource state pattern
    let (|ResourcesNormal|ResourcesWarning|ResourcesCritical|) (cpuPercent: float, memPercent: float) =
        if cpuPercent > 90.0 || memPercent > 90.0 then ResourcesCritical
        elif cpuPercent > 70.0 || memPercent > 70.0 then ResourcesWarning
        else ResourcesNormal

    // =========================================================================
    // AGENT CLASSIFICATION PATTERNS (SC-AGT-017, SC-AGT-018)
    // =========================================================================

    /// Agent operational state pattern
    let (|AgentIdle|AgentBusy|AgentBlocked|AgentFailed|) (status: string) =
        match status.ToLowerInvariant() with
        | "idle" | "ready" | "waiting" -> AgentIdle
        | "active" | "busy" | "processing" | "working" -> AgentBusy
        | "blocked" | "suspended" | "paused" -> AgentBlocked
        | "failed" | "error" | "terminated" | "dead" -> AgentFailed
        | _ -> AgentIdle

    /// Agent hierarchy level pattern
    let (|ExecutiveLevel|SupervisorLevel|WorkerLevel|) (level: string) =
        match level.ToLowerInvariant() with
        | "executive" | "exec" -> ExecutiveLevel
        | "supervisor" | "domain" | "functional" -> SupervisorLevel
        | "worker" | "task" -> WorkerLevel
        | _ -> WorkerLevel

    /// Agent efficiency compliance pattern (SC-AGT-017: >90% required)
    let (|EfficiencyCompliant|EfficiencyWarning|EfficiencyViolation|) (efficiency: float) =
        if efficiency >= 90.0 then EfficiencyCompliant
        elif efficiency >= 80.0 then EfficiencyWarning
        else EfficiencyViolation

    // =========================================================================
    // FRACTAL LOG PATTERNS (SC-LOG-*)
    // =========================================================================

    /// Fractal level classification for routing
    let (|AtomicLevel|ComponentLevel|TransactionLevel|SystemLevel|CognitiveLevel|) (level: int) =
        match level with
        | 1 -> AtomicLevel
        | 2 -> ComponentLevel
        | 3 -> TransactionLevel
        | 4 -> SystemLevel
        | _ -> CognitiveLevel  // Default to highest for safety

    /// Priority routing pattern
    let (|NeverDrop|Sample10Percent|Sample1Percent|DebugOnly|) (priority: int) =
        match priority with
        | 0 -> NeverDrop        // P0: Critical (L4/L5)
        | 1 -> Sample10Percent  // P1: High (L3)
        | 2 -> Sample1Percent   // P2: Medium (L2)
        | _ -> DebugOnly        // P3: Low (L1)

    /// Boost state pattern (SC-LOG-005: TTL required)
    let (|BoostActive|BoostExpired|BoostInvalid|) (createdAt: DateTimeOffset, expiresAt: DateTimeOffset) =
        let now = DateTimeOffset.UtcNow
        if expiresAt <= createdAt then BoostInvalid
        elif now >= expiresAt then BoostExpired
        else BoostActive

    // =========================================================================
    // VALIDATION PATTERNS (SC-VAL-*)
    // =========================================================================

    /// Validation result classification
    let (|ValidationPassed|ValidationWarnings|ValidationFailed|) (errors: string list, warnings: string list) =
        match errors, warnings with
        | [], [] -> ValidationPassed
        | [], _ -> ValidationWarnings
        | _, _ -> ValidationFailed

    /// STAMP constraint validation pattern
    let (|ConstraintMet|ConstraintViolated|ConstraintSkipped|) (passed: bool option) =
        match passed with
        | Some true -> ConstraintMet
        | Some false -> ConstraintViolated
        | None -> ConstraintSkipped

    // =========================================================================
    // SAFETY PATTERNS (SC-EMR-*, SC-SEC-*)
    // =========================================================================

    /// Emergency action pattern (SC-EMR-057: Stop <5s)
    let (|EmergencyStop|GracefulStop|ScheduledStop|) (urgency: string) =
        match urgency.ToLowerInvariant() with
        | "emergency" | "immediate" | "critical" -> EmergencyStop
        | "graceful" | "normal" | "standard" -> GracefulStop
        | "scheduled" | "planned" | "maintenance" -> ScheduledStop
        | _ -> GracefulStop

    /// Security action pattern
    let (|SecurityBlock|SecurityAllow|SecurityAudit|) (action: string) =
        match action.ToLowerInvariant() with
        | "block" | "deny" | "reject" -> SecurityBlock
        | "allow" | "permit" | "accept" -> SecurityAllow
        | "audit" | "log" | "monitor" -> SecurityAudit
        | _ -> SecurityAudit

    // =========================================================================
    // NETWORK PATTERNS
    // =========================================================================

    /// Connection state pattern
    let (|Connected|Connecting|Disconnected|Reconnecting|) (state: string) =
        match state.ToLowerInvariant() with
        | "connected" | "established" | "open" -> Connected
        | "connecting" | "opening" | "handshaking" -> Connecting
        | "disconnected" | "closed" | "terminated" -> Disconnected
        | "reconnecting" | "retrying" | "recovering" -> Reconnecting
        | _ -> Disconnected

    /// Latency classification pattern (SC-PRF-050: <50ms)
    let (|LowLatency|MediumLatency|HighLatency|CriticalLatency|) (latencyMs: float) =
        if latencyMs < 10.0 then LowLatency
        elif latencyMs < 50.0 then MediumLatency
        elif latencyMs < 200.0 then HighLatency
        else CriticalLatency

    // =========================================================================
    // BUILD/TEST PATTERNS (SC-CMP-*)
    // =========================================================================

    /// Compilation outcome pattern (SC-CMP-025: 0 warnings)
    let (|CompileSuccess|CompileWarnings|CompileErrors|) (errorCount: int, warningCount: int) =
        match errorCount, warningCount with
        | 0, 0 -> CompileSuccess
        | 0, _ -> CompileWarnings
        | _, _ -> CompileErrors

    /// Test outcome pattern
    let (|AllTestsPassed|SomeTestsFailed|TestsSkipped|TestsNotRun|) (passed: int, failed: int, skipped: int) =
        match passed, failed, skipped with
        | _, 0, 0 when passed > 0 -> AllTestsPassed
        | _, f, _ when f > 0 -> SomeTestsFailed
        | _, 0, s when s > 0 -> TestsSkipped
        | _ -> TestsNotRun
