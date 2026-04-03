// =============================================================================
// SmokeTestPublisher.fs - Zenoh Checkpoint Publishing for Smoke Tests
// =============================================================================
// STAMP: SC-ZTEST-001 to SC-ZTEST-008 (Zenoh test messaging constraints)
// AOR: AOR-ZENOH-007 (Publish node health every 10s), AOR-ZENOH-008
//
// ## Purpose
// Implements Zenoh checkpoint messaging for smoke tests to provide <100ms
// real-time feedback during boot verification. Replaces log-based verification
// with structured pub/sub messages.
//
// ## Checkpoint IDs
// - CP-SMOKE-01: Smoke test batch starting
// - CP-SMOKE-02: API endpoint tests complete
// - CP-SMOKE-03: Database consistency complete
// - CP-SMOKE-04: Zenoh connectivity complete
// - CP-SMOKE-05: Performance baseline complete
// - CP-SMOKE-06: Security validation complete
// - CP-SMOKE-07: Resilience tests complete
// - CP-SMOKE-08: All smoke tests finished
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-18 |
// | Author | Claude Opus 4.5 |
// | Reference | 20260118-1615-sil6-biomorphic-startup-master-specification.md |
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Text.Json
open System.Text.Json.Serialization

/// Test category for smoke tests
type SmokeTestCategory =
    | API
    | Database
    | Zenoh
    | Performance
    | Security
    | Resilience
    | Integration

/// Test criticality levels
type SmokeCriticality =
    | P0_Critical
    | P1_High
    | P2_Medium
    | P3_Low

/// Smoke test status
type SmokeTestStatus =
    | Passed
    | Failed
    | Skipped
    | Timeout

/// Individual smoke test result
type SmokeTestResult = {
    [<JsonPropertyName("test_id")>]
    TestId: string

    [<JsonPropertyName("category")>]
    Category: string

    [<JsonPropertyName("criticality")>]
    Criticality: string

    [<JsonPropertyName("status")>]
    Status: string

    [<JsonPropertyName("duration_ms")>]
    DurationMs: int64

    [<JsonPropertyName("timestamp")>]
    Timestamp: string

    [<JsonPropertyName("details")>]
    Details: string

    [<JsonPropertyName("evidence")>]
    Evidence: string list

    [<JsonPropertyName("metrics")>]
    Metrics: Map<string, float> option
}

/// Smoke test batch message
type SmokeBatchMessage = {
    [<JsonPropertyName("type")>]
    Type: string

    [<JsonPropertyName("checkpoint")>]
    Checkpoint: string

    [<JsonPropertyName("batch_id")>]
    BatchId: string

    [<JsonPropertyName("node_id")>]
    NodeId: string

    [<JsonPropertyName("timestamp")>]
    Timestamp: string

    [<JsonPropertyName("total_tests")>]
    TotalTests: int

    [<JsonPropertyName("tests_passed")>]
    TestsPassed: int

    [<JsonPropertyName("tests_failed")>]
    TestsFailed: int

    [<JsonPropertyName("pass_rate")>]
    PassRate: float

    [<JsonPropertyName("duration_ms")>]
    DurationMs: int64

    [<JsonPropertyName("categories")>]
    Categories: Map<string, int>

    [<JsonPropertyName("failures")>]
    Failures: string list
}

/// Node-level smoke test summary
type NodeSmokeResult = {
    [<JsonPropertyName("type")>]
    Type: string

    [<JsonPropertyName("checkpoint")>]
    Checkpoint: string

    [<JsonPropertyName("node_id")>]
    NodeId: string

    [<JsonPropertyName("tests_run")>]
    TestsRun: int

    [<JsonPropertyName("tests_passed")>]
    TestsPassed: int

    [<JsonPropertyName("tests_failed")>]
    TestsFailed: int

    [<JsonPropertyName("pass_rate")>]
    PassRate: float

    [<JsonPropertyName("duration_ms")>]
    DurationMs: int64

    [<JsonPropertyName("failures")>]
    Failures: string list

    [<JsonPropertyName("timestamp")>]
    Timestamp: string
}

/// Smoke test publisher operations
module SmokeTestPublisher =

    /// Checkpoint IDs for smoke tests
    module CheckpointIds =
        let SMOKE_01 = "CP-SMOKE-01"  // Batch starting
        let SMOKE_02 = "CP-SMOKE-02"  // API complete
        let SMOKE_03 = "CP-SMOKE-03"  // Database complete
        let SMOKE_04 = "CP-SMOKE-04"  // Zenoh complete
        let SMOKE_05 = "CP-SMOKE-05"  // Performance complete
        let SMOKE_06 = "CP-SMOKE-06"  // Security complete
        let SMOKE_07 = "CP-SMOKE-07"  // Resilience complete
        let SMOKE_08 = "CP-SMOKE-08"  // All complete

    /// Topic patterns for smoke test pub/sub
    module Topics =
        let smokeBase = "indrajaal/smoke"

        let batchStart batchId = $"{smokeBase}/batch/{batchId}/start"
        let batchProgress batchId = $"{smokeBase}/batch/{batchId}/progress"
        let batchComplete batchId = $"{smokeBase}/batch/{batchId}/complete"

        let nodeResult nodeId = $"{smokeBase}/node/{nodeId}/result"

        let categoryComplete category = $"{smokeBase}/category/{category}/complete"

        let testResult testId = $"{smokeBase}/test/{testId}/result"

        let summary = $"{smokeBase}/summary"

    /// Convert category to string
    let categoryToString (category: SmokeTestCategory) : string =
        match category with
        | API -> "API"
        | Database -> "Database"
        | Zenoh -> "Zenoh"
        | Performance -> "Performance"
        | Security -> "Security"
        | Resilience -> "Resilience"
        | Integration -> "Integration"

    /// Convert criticality to string
    let criticalityToString (criticality: SmokeCriticality) : string =
        match criticality with
        | P0_Critical -> "P0_Critical"
        | P1_High -> "P1_High"
        | P2_Medium -> "P2_Medium"
        | P3_Low -> "P3_Low"

    /// Convert status to string
    let statusToString (status: SmokeTestStatus) : string =
        match status with
        | Passed -> "Passed"
        | Failed -> "Failed"
        | Skipped -> "Skipped"
        | Timeout -> "Timeout"

    /// Create a smoke test result message
    let createTestResult
        (testId: string)
        (category: SmokeTestCategory)
        (criticality: SmokeCriticality)
        (status: SmokeTestStatus)
        (durationMs: int64)
        (details: string)
        (evidence: string list)
        (metrics: Map<string, float> option)
        : SmokeTestResult =
        {
            TestId = testId
            Category = categoryToString category
            Criticality = criticalityToString criticality
            Status = statusToString status
            DurationMs = durationMs
            Timestamp = DateTime.UtcNow.ToString("o")
            Details = details
            Evidence = evidence
            Metrics = metrics
        }

    /// Create a batch start message
    let createBatchStartMessage
        (batchId: string)
        (nodeId: string)
        (totalTests: int)
        : SmokeBatchMessage =
        {
            Type = "smoke_batch_start"
            Checkpoint = CheckpointIds.SMOKE_01
            BatchId = batchId
            NodeId = nodeId
            Timestamp = DateTime.UtcNow.ToString("o")
            TotalTests = totalTests
            TestsPassed = 0
            TestsFailed = 0
            PassRate = 0.0
            DurationMs = 0L
            Categories = Map.empty
            Failures = []
        }

    /// Create a batch progress message
    let createBatchProgressMessage
        (batchId: string)
        (nodeId: string)
        (totalTests: int)
        (testsPassed: int)
        (testsFailed: int)
        (durationMs: int64)
        (categories: Map<string, int>)
        : SmokeBatchMessage =
        let passRate = if totalTests > 0 then float testsPassed / float totalTests else 0.0
        {
            Type = "smoke_batch_progress"
            Checkpoint = CheckpointIds.SMOKE_01
            BatchId = batchId
            NodeId = nodeId
            Timestamp = DateTime.UtcNow.ToString("o")
            TotalTests = totalTests
            TestsPassed = testsPassed
            TestsFailed = testsFailed
            PassRate = passRate
            DurationMs = durationMs
            Categories = categories
            Failures = []
        }

    /// Create a batch complete message
    let createBatchCompleteMessage
        (batchId: string)
        (nodeId: string)
        (totalTests: int)
        (testsPassed: int)
        (testsFailed: int)
        (durationMs: int64)
        (categories: Map<string, int>)
        (failures: string list)
        : SmokeBatchMessage =
        let passRate = if totalTests > 0 then float testsPassed / float totalTests else 0.0
        {
            Type = "smoke_batch_complete"
            Checkpoint = CheckpointIds.SMOKE_08
            BatchId = batchId
            NodeId = nodeId
            Timestamp = DateTime.UtcNow.ToString("o")
            TotalTests = totalTests
            TestsPassed = testsPassed
            TestsFailed = testsFailed
            PassRate = passRate
            DurationMs = durationMs
            Categories = categories
            Failures = failures
        }

    /// Create a node result message
    let createNodeResultMessage
        (nodeId: string)
        (testsRun: int)
        (testsPassed: int)
        (testsFailed: int)
        (durationMs: int64)
        (failures: string list)
        : NodeSmokeResult =
        let passRate = if testsRun > 0 then float testsPassed / float testsRun else 0.0
        {
            Type = "smoke_node_summary"
            Checkpoint = "CP-SMOKE-TX-02"
            NodeId = nodeId
            TestsRun = testsRun
            TestsPassed = testsPassed
            TestsFailed = testsFailed
            PassRate = passRate
            DurationMs = durationMs
            Failures = failures
            Timestamp = DateTime.UtcNow.ToString("o")
        }

    /// Serialize message to JSON
    let toJson<'T> (msg: 'T) : string =
        let options = JsonSerializerOptions(WriteIndented = false)
        options.DefaultIgnoreCondition <- JsonIgnoreCondition.WhenWritingNull
        JsonSerializer.Serialize(msg, options)

    /// Get checkpoint for category
    let getCategoryCheckpoint (category: SmokeTestCategory) : string =
        match category with
        | API -> CheckpointIds.SMOKE_02
        | Database -> CheckpointIds.SMOKE_03
        | Zenoh -> CheckpointIds.SMOKE_04
        | Performance -> CheckpointIds.SMOKE_05
        | Security -> CheckpointIds.SMOKE_06
        | Resilience -> CheckpointIds.SMOKE_07
        | Integration -> CheckpointIds.SMOKE_08

    /// Print smoke test result (for console/logging)
    let printTestResult (result: SmokeTestResult) : unit =
        let color =
            match result.Status with
            | "Passed" -> "\u001b[32m"      // Green
            | "Failed" -> "\u001b[31m"      // Red
            | "Skipped" -> "\u001b[33m"     // Yellow
            | "Timeout" -> "\u001b[33m"     // Yellow
            | _ -> "\u001b[36m"             // Cyan

        printfn "%s[SMOKE]%s [%s] %s: %s (%dms)"
            color "\u001b[0m"
            result.Category result.TestId result.Status result.DurationMs

    /// Print batch summary
    let printBatchSummary (batch: SmokeBatchMessage) : unit =
        let passColor = if batch.PassRate >= 1.0 then "\u001b[32m"
                        elif batch.PassRate >= 0.8 then "\u001b[33m"
                        else "\u001b[31m"

        printfn ""
        printfn "╔═══════════════════════════════════════════════════════════════════╗"
        printfn "║                    SMOKE TEST SUMMARY                              ║"
        printfn "╠═══════════════════════════════════════════════════════════════════╣"
        printfn "║ Batch:     %-56s ║" batch.BatchId
        printfn "║ Node:      %-56s ║" batch.NodeId
        printfn "╠═══════════════════════════════════════════════════════════════════╣"
        printfn "║ Total:     %-6d                                                  ║" batch.TotalTests
        printfn "║ Passed:    %s%-6d\u001b[0m                                                  ║" "\u001b[32m" batch.TestsPassed
        printfn "║ Failed:    %s%-6d\u001b[0m                                                  ║" (if batch.TestsFailed > 0 then "\u001b[31m" else "\u001b[32m") batch.TestsFailed
        printfn "║ Pass Rate: %s%.1f%%\u001b[0m                                                   ║" passColor (batch.PassRate * 100.0)
        printfn "║ Duration:  %d ms                                                   ║" batch.DurationMs
        printfn "╠═══════════════════════════════════════════════════════════════════╣"

        if not batch.Failures.IsEmpty then
            printfn "║ FAILURES:                                                          ║"
            for failure in batch.Failures |> List.truncate 5 do
                printfn "║   - %-62s ║" failure
            if batch.Failures.Length > 5 then
                printfn "║   ... and %d more                                                 ║" (batch.Failures.Length - 5)

        printfn "╚═══════════════════════════════════════════════════════════════════╝"
        printfn ""

    /// Publish a test result via SC-ZTEST-008 dual-write pattern.
    let publishTestResult (result: SmokeTestResult) : unit =
        let checkpointId =
            match result.Category.ToLowerInvariant() with
            | "api" -> CheckpointIds.SMOKE_02
            | "database" -> CheckpointIds.SMOKE_03
            | "zenoh" -> CheckpointIds.SMOKE_04
            | "performance" -> CheckpointIds.SMOKE_05
            | "security" -> CheckpointIds.SMOKE_06
            | "resilience" -> CheckpointIds.SMOKE_07
            | _ -> CheckpointIds.SMOKE_08
        let topic = sprintf "indrajaal/smoke/test/%s/result" result.TestId
        let payload = sprintf """{"test_id":"%s","category":"%s","status":"%s","duration_ms":%d,"details":"%s"}"""
                        result.TestId result.Category result.Status result.DurationMs
                        (result.Details.Replace("\"", "\\\""))
        ZenohPublish.publish checkpointId topic result.Status payload
        printTestResult result

    /// Publish batch completion via SC-ZTEST-008 dual-write pattern.
    let publishBatchComplete (batch: SmokeBatchMessage) : unit =
        let topic = sprintf "indrajaal/smoke/batch/%s/complete" batch.BatchId
        let payload = sprintf """{"batch_id":"%s","total":%d,"passed":%d,"failed":%d,"pass_rate":%.3f,"duration_ms":%d}"""
                        batch.BatchId batch.TotalTests batch.TestsPassed batch.TestsFailed
                        batch.PassRate batch.DurationMs
        ZenohPublish.publish CheckpointIds.SMOKE_08 topic "Smoke batch complete" payload
        printBatchSummary batch

/// Smoke test orchestrator state
type SmokeTestState = {
    mutable BatchId: string
    mutable NodeId: string
    mutable TotalTests: int
    mutable TestsPassed: int
    mutable TestsFailed: int
    mutable TestsSkipped: int
    mutable Results: SmokeTestResult list
    mutable StartTime: DateTime
    mutable Categories: Map<string, int>
    mutable Failures: string list
}

/// Smoke test orchestrator
module SmokeTestOrchestrator =

    /// Create initial state
    let createState (nodeId: string) : SmokeTestState =
        let timestamp = DateTime.UtcNow.ToString("yyyyMMdd-HHmmss")
        let guidShort = Guid.NewGuid().ToString().[..7]
        let batchId = $"smoke-{timestamp}-{guidShort}"
        {
            BatchId = batchId
            NodeId = nodeId
            TotalTests = 0
            TestsPassed = 0
            TestsFailed = 0
            TestsSkipped = 0
            Results = []
            StartTime = DateTime.UtcNow
            Categories = Map.empty
            Failures = []
        }

    /// Record a test result
    let recordResult (state: SmokeTestState) (result: SmokeTestResult) : unit =
        state.TotalTests <- state.TotalTests + 1
        state.Results <- result :: state.Results

        // Update category count
        let categoryCount =
            state.Categories
            |> Map.tryFind result.Category
            |> Option.defaultValue 0
        state.Categories <- state.Categories |> Map.add result.Category (categoryCount + 1)

        // Update pass/fail counts
        match result.Status with
        | "Passed" -> state.TestsPassed <- state.TestsPassed + 1
        | "Failed" ->
            state.TestsFailed <- state.TestsFailed + 1
            state.Failures <- $"{result.TestId}: {result.Details}" :: state.Failures
        | "Skipped" -> state.TestsSkipped <- state.TestsSkipped + 1
        | _ -> ()

        // Print result
        SmokeTestPublisher.printTestResult result

    /// Get elapsed time in milliseconds
    let getElapsedMs (state: SmokeTestState) : int64 =
        int64 (DateTime.UtcNow - state.StartTime).TotalMilliseconds

    /// Create progress message
    let getProgressMessage (state: SmokeTestState) : SmokeBatchMessage =
        SmokeTestPublisher.createBatchProgressMessage
            state.BatchId
            state.NodeId
            state.TotalTests
            state.TestsPassed
            state.TestsFailed
            (getElapsedMs state)
            state.Categories

    /// Create completion message
    let getCompletionMessage (state: SmokeTestState) : SmokeBatchMessage =
        SmokeTestPublisher.createBatchCompleteMessage
            state.BatchId
            state.NodeId
            state.TotalTests
            state.TestsPassed
            state.TestsFailed
            (getElapsedMs state)
            state.Categories
            (state.Failures |> List.rev)

    /// Print final summary
    let printSummary (state: SmokeTestState) : unit =
        let msg = getCompletionMessage state
        SmokeTestPublisher.printBatchSummary msg
