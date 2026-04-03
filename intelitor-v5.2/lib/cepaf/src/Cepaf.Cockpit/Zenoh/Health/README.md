# Dual-Layer Health Monitoring (FM-003)

## Overview

The Dual-Layer Health Monitor implements a biomorphic health monitoring system with:
- **Fast Layer**: Interrupt-driven checks (<50ms response time)
- **Slow Layer**: Scheduler-based trend analysis (10s intervals)
- **Performance Tracking**: Response time monitoring with SC-SIL6-004 compliance

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SIL6-004 | Neural-immune response < 50ms | CRITICAL |
| SC-OP-003 | Health check interval configurable | HIGH |
| SC-IMMUNE-001 | Sentinel health assessment mandatory | CRITICAL |
| SC-ZENOH-010 | Container agents publish health every 30s | HIGH |

## Quick Start

### 1. Fast Monitoring Only

```fsharp
open Cepaf.Zenoh.Health

// Start fast monitor with 10ms interval
let monitor = DualLayerHealthMonitor.startFast 10

// Monitor runs automatically, triggering QuickHealthCheck every 10ms
// Stop when done
monitor.Dispose()
```

### 2. Dual-Layer Monitoring (Production Mode)

```fsharp
open Cepaf.Zenoh.Health

// Start both fast and slow monitoring
let monitor = DualLayerHealthMonitor.startDualLayer()

// Fast checks: every 10ms (default)
// Slow checks: every 10s (default)

// Subscribe to health check events
monitor.HealthCheckCompleted.Add(fun result ->
    printfn "Health: %.2f%%, Response: %.2fms, Threat: %b"
            (result.HealthScore * 100.0)
            result.ResponseTimeMs
            result.ThreatDetected
)

// Stop when done
monitor.Dispose()
```

### 3. Manual Health Checks

```fsharp
let monitor = DualLayerHealthMonitor.create()

// Quick check (<50ms target)
let quickResult = monitor.QuickHealthCheck()
if quickResult.ConstraintViolated then
    printfn "WARNING: SC-SIL6-004 violated! Response: %.2fms" quickResult.ResponseTimeMs

// Deep check (comprehensive analysis)
let deepResult = monitor.DeepHealthCheck()
printfn "Health Score: %.2f" deepResult.HealthScore
```

### 4. With Integration Components

```fsharp
// When Sentinel, PatternHunter, and SymbioticDefense are available:
let monitor = DualLayerHealthMonitor.withFullIntegration sentinel patternHunter defense

monitor.Start(HealthCheckLevel.DualLayer)

// Monitor will use real components instead of stubs
```

## Architecture

### HealthCheckLevel

```fsharp
type HealthCheckLevel =
    | Fast of intervalMs: int           // Fast layer only
    | Slow of intervalMs: int           // Slow layer only
    | DualLayer                         // Both layers active (production)
```

### HealthCheckResult

```fsharp
type HealthCheckResult = {
    Timestamp: DateTimeOffset
    ResponseTimeMs: float               // Actual response time
    HealthScore: float                  // 0.0-1.0
    IsFastLayer: bool                   // Fast or slow layer?
    ThreatDetected: bool                // Threat flag
    Message: string option              // Diagnostic message
    ConstraintViolated: bool            // SC-SIL6-004 violation?
}
```

## Performance Tracking

```fsharp
// Get statistics
let stats = monitor.GetStatistics()
printfn "Fast checks: %d" stats.FastCheckCount
printfn "Slow checks: %d" stats.SlowCheckCount
printfn "Average response: %.2fms" stats.AverageResponseMs
printfn "Max response: %.2fms" stats.MaxResponseMs
printfn "Violations: %d" stats.ViolationCount
```

## Integration Interfaces (Phase 1 - Stubs)

### ISentinel
```fsharp
type ISentinel =
    abstract member AssessNow: unit -> float      // Health score 0.0-1.0
    abstract member GetThreats: unit -> string list
```

### IPatternHunter
```fsharp
type IPatternHunter =
    abstract member DetectPreError: unit -> bool
    abstract member GetAnomalyScore: unit -> float
```

### ISymbioticDefense
```fsharp
type ISymbioticDefense =
    abstract member RespondToThreat: threatLevel: float -> unit
    abstract member ExecuteRecovery: recoveryPhase: int -> unit
```

## Immune Response

```fsharp
// Trigger neural-immune response (<50ms requirement)
monitor.TriggerImmuneResponse(0.8)  // threat level 0.0-1.0

// Response time is automatically logged
// If > 50ms, SC-SIL6-004 violation is logged
```

## Event Handling

```fsharp
monitor.HealthCheckCompleted.Add(fun result ->
    // Log to telemetry
    if result.ConstraintViolated then
        // Alert: SC-SIL6-004 violation
        logCriticalAlert result

    if result.ThreatDetected then
        // Trigger immune response
        monitor.TriggerImmuneResponse(1.0 - result.HealthScore)
)
```

## Customizing Intervals

```fsharp
let monitor = DualLayerHealthMonitor.create()

// Change fast interval (default 10ms)
monitor.SetFastInterval(5)   // 5ms for ultra-fast response

// Change slow interval (default 10000ms)
monitor.SetSlowInterval(30000)  // 30s for deep analysis

monitor.Start(HealthCheckLevel.DualLayer)
```

## Integration with SIL-6 Mesh

```fsharp
// In mesh startup sequence:
let healthMonitor = DualLayerHealthMonitor.startDualLayer()

// Subscribe to health events and publish to Zenoh
healthMonitor.HealthCheckCompleted.Add(fun result ->
    publishToZenoh "indrajaal/health/monitor" result
)

// In mesh shutdown:
healthMonitor.Dispose()
```

## Testing

```fsharp
// Unit test for SC-SIL6-004 compliance
let testFastResponse() =
    use monitor = DualLayerHealthMonitor.create()

    // Run 100 quick checks
    let results =
        [1..100]
        |> List.map (fun _ -> monitor.QuickHealthCheck())

    // Verify all < 50ms
    let violations = results |> List.filter (fun r -> r.ConstraintViolated)
    assert (violations.Length = 0)

    // Verify average < 25ms
    let avgTime = results |> List.averageBy (fun r -> r.ResponseTimeMs)
    assert (avgTime < 25.0)
```

## Files

| File | Purpose |
|------|---------|
| `DualLayerHealthMonitor.fs` | Main implementation |
| `README.md` | This documentation |

## Dependencies

- `System.Timers` - For timer-based monitoring
- `System.Diagnostics` - For stopwatch performance tracking

## Version

| Version | Date | Author | Change |
|---------|------|--------|--------|
| 21.3.0 | 2026-01-15 | Claude Opus 4.5 | Initial implementation (FM-003) |

## Related Documents

- CLAUDE.md - SC-SIL6-004, SC-OP-003 constraints
- zenoh-telemetry-mandatory.md - SC-ZENOH-010
- fsharp-sil6-mesh.md - Mesh integration

## Next Steps (Phase 2)

1. Implement actual ISentinel integration with Elixir backend
2. Implement IPatternHunter with pre-error pattern detection
3. Implement ISymbioticDefense with 5-phase recovery
4. Add Zenoh telemetry publishing for health events
5. Add DuckDB persistence for health history
6. Add Grafana dashboard visualization
