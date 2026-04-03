namespace Cepaf.Zenoh

open System
open System.Text.Json
open Cepaf.Zenoh.ZenohSession

/// Zenoh publisher for F# smoke test results.
///
/// ## STAMP Constraints
/// - SC-ZTEST-001: All checkpoints have unique topics
/// - SC-ZTEST-002: Messages include checkpoint ID
/// - SC-ZTEST-003: Publish latency < 10ms per message
///
/// ## Topics Published
/// - indrajaal/smoke/batch/{batch_id}/start
/// - indrajaal/smoke/batch/{batch_id}/progress
/// - indrajaal/smoke/batch/{batch_id}/complete
/// - indrajaal/smoke/node/{node_id}/result
/// - indrajaal/smoke/category/{category}/complete
/// - indrajaal/smoke/summary
///
/// ## Usage
/// ```fsharp
/// SmokeTestPublisher.batchStarted "batch-001" 10
/// SmokeTestPublisher.testResult { TestId = "API-001"; Status = Passed; ... }
/// SmokeTestPublisher.batchFinished "batch-001" { Total = 10; Passed = 9; ... }
/// ```
module SmokeTestPublisher =

    // ========================================================================
    // TYPES
    // ========================================================================

    /// Test criticality levels
    type Criticality =
        | P0_Critical
        | P1_High
        | P2_Medium
        | P3_Low

    /// Test result status
    type TestStatus =
        | Passed
        | Failed
        | Skipped
        | TimedOut

    /// Smoke test result
    type SmokeTestResult = {
        TestId: string
        Category: string
        Criticality: Criticality
        Status: TestStatus
        DurationMs: int
        Metrics: Map<string, float>
        Evidence: string list
        FailureDetails: string option
    }

    /// Batch summary
    type BatchSummary = {
        BatchId: string
        NodeId: string
        Total: int
        Passed: int
        Failed: int
        Skipped: int
        DurationMs: int
        Failures: string list
    }

    /// Category summary
    type CategorySummary = {
        Category: string
        Total: int
        Passed: int
        Failed: int
        PassRate: float
        DurationMs: int
    }

    // ========================================================================
    // CONSTANTS
    // ========================================================================

    let private schemaVersion = "1.0.0"

    let private nodeId () =
        Environment.MachineName

    // ========================================================================
    // MESSAGE BUILDERS
    // ========================================================================

    /// Build smoke test result message (CP-SMOKE-TX-01)
    let private buildTestResultMessage (result: SmokeTestResult) =
        {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "smoke_result"
            checkpoint = "CP-SMOKE-TX-01"
            test_id = result.TestId
            category = result.Category
            criticality = result.Criticality.ToString()
            status = result.Status.ToString()
            duration_ms = result.DurationMs
            metrics = result.Metrics |> Map.toSeq |> Seq.map (fun (k, v) -> k, box v) |> dict
            evidence = result.Evidence
            failure_details = result.FailureDetails |> Option.defaultValue ""
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}

    /// Build batch started message
    let private buildBatchStartedMessage (batchId: string) (testCount: int) =
        {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "smoke_batch_started"
            checkpoint = "CP-SMOKE-01"
            batch_id = batchId
            test_count = testCount
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}

    /// Build batch progress message
    let private buildBatchProgressMessage (batchId: string) (completed: int) (total: int) (passed: int) (failed: int) =
        {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "smoke_batch_progress"
            checkpoint = "CP-SMOKE-TX-03"
            batch_id = batchId
            completed = completed
            total = total
            passed = passed
            failed = failed
            progress_percent = if total > 0 then float completed / float total * 100.0 else 0.0
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}

    /// Build batch finished message
    let private buildBatchFinishedMessage (summary: BatchSummary) =
        {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "smoke_batch_finished"
            checkpoint = "CP-SMOKE-08"
            batch_id = summary.BatchId
            node_id = summary.NodeId
            total = summary.Total
            passed = summary.Passed
            failed = summary.Failed
            skipped = summary.Skipped
            pass_rate = if summary.Total > 0 then float summary.Passed / float summary.Total else 0.0
            duration_ms = summary.DurationMs
            failures = summary.Failures
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
        |}

    /// Build node summary message (CP-SMOKE-TX-02)
    let private buildNodeSummaryMessage (summary: BatchSummary) =
        {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "smoke_node_summary"
            checkpoint = "CP-SMOKE-TX-02"
            node_id = summary.NodeId
            tests_run = summary.Total
            tests_passed = summary.Passed
            tests_failed = summary.Failed
            pass_rate = if summary.Total > 0 then float summary.Passed / float summary.Total else 0.0
            duration_ms = summary.DurationMs
            failures = summary.Failures
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
        |}

    /// Build category summary message
    let private buildCategorySummaryMessage (summary: CategorySummary) =
        let checkpoint =
            match summary.Category.ToLowerInvariant() with
            | "api" -> "CP-SMOKE-02"
            | "db" | "database" -> "CP-SMOKE-03"
            | "zenoh" -> "CP-SMOKE-04"
            | "perf" | "performance" -> "CP-SMOKE-05"
            | "security" -> "CP-SMOKE-06"
            | "resilience" -> "CP-SMOKE-07"
            | _ -> "CP-SMOKE-TX-01"

        {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "smoke_category_complete"
            checkpoint = checkpoint
            category = summary.Category
            total = summary.Total
            passed = summary.Passed
            failed = summary.Failed
            pass_rate = summary.PassRate
            duration_ms = summary.DurationMs
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}

    // ========================================================================
    // PUBLISHING API
    // ========================================================================

    /// Publish batch started event
    let batchStarted (batchId: string) (testCount: int) =
        let message = buildBatchStartedMessage batchId testCount
        let json = JsonSerializer.Serialize(message)
        let topic = sprintf "indrajaal/smoke/batch/%s/start" batchId
        publishJson topic json

    /// Publish batch progress update
    let batchProgress (batchId: string) (completed: int) (total: int) (passed: int) (failed: int) =
        let message = buildBatchProgressMessage batchId completed total passed failed
        let json = JsonSerializer.Serialize(message)
        let topic = sprintf "indrajaal/smoke/batch/%s/progress" batchId
        publishJson topic json

    /// Publish individual test result
    let testResult (result: SmokeTestResult) =
        let message = buildTestResultMessage result
        let json = JsonSerializer.Serialize(message)

        // Publish to test-specific topic
        let testTopic = sprintf "indrajaal/smoke/test/%s" result.TestId
        let _ = publishJson testTopic json

        // Also publish to category topic for aggregation
        let categoryTopic = sprintf "indrajaal/smoke/category/%s/result" result.Category
        publishJson categoryTopic json

    /// Publish batch finished event
    let batchFinished (summary: BatchSummary) =
        let message = buildBatchFinishedMessage summary
        let json = JsonSerializer.Serialize(message)
        let topic = sprintf "indrajaal/smoke/batch/%s/complete" summary.BatchId
        publishJson topic json

    /// Publish node summary
    let nodeSummary (summary: BatchSummary) =
        let message = buildNodeSummaryMessage summary
        let json = JsonSerializer.Serialize(message)
        let topic = sprintf "indrajaal/smoke/node/%s/result" summary.NodeId
        publishJson topic json

    /// Publish category summary
    let categorySummary (summary: CategorySummary) =
        let message = buildCategorySummaryMessage summary
        let json = JsonSerializer.Serialize(message)
        let topic = sprintf "indrajaal/smoke/category/%s/complete" summary.Category
        publishJson topic json

    // ========================================================================
    // CONVENIENCE FUNCTIONS
    // ========================================================================

    /// Quick publish for passed test
    let testPassed (testId: string) (category: string) (durationMs: int) =
        testResult {
            TestId = testId
            Category = category
            Criticality = P2_Medium
            Status = Passed
            DurationMs = durationMs
            Metrics = Map.empty
            Evidence = ["Test completed successfully"]
            FailureDetails = None
        }

    /// Quick publish for failed test
    let testFailed (testId: string) (category: string) (durationMs: int) (reason: string) =
        testResult {
            TestId = testId
            Category = category
            Criticality = P2_Medium
            Status = Failed
            DurationMs = durationMs
            Metrics = Map.empty
            Evidence = []
            FailureDetails = Some reason
        }

    /// Publish telemetry event for orchestrator integration
    let emitTelemetry (testId: string) (status: TestStatus) (durationMs: int) =
        // Emit telemetry event that will be picked up by orchestrator
        let eventData = {|
            test_id = testId
            status = status.ToString()
            duration_ms = durationMs
            timestamp = DateTimeOffset.UtcNow.ToString("o")
        |}
        let json = JsonSerializer.Serialize(eventData)
        publishJson "indrajaal/smoke/result/published" json
