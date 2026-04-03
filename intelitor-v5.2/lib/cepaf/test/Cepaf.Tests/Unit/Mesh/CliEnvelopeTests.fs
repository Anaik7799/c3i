// =============================================================================
// CliEnvelopeTests.fs - TDG-compliant tests for CliEnvelope
// =============================================================================
// STAMP: SC-TEST-001 (TDG compliance), SC-CLI-001 (CLI interface),
//        SC-ZENOH-007 (Zenoh health in envelope)
//
// ## Test Coverage
// - getSystemMetrics: success path, JSON shape, metric names, status values
// - getContainerMetrics: 15-container mesh, containers_healthy summary
// - getZenohMetrics: zenoh_connected metric present, JSON parseable
// - formatEnvelope: ANSI output, ok/warn/crit coloring, invalid JSON graceful error
// - renderDashboard: Ok result, non-empty output, zenoh/container sections present
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-03-30 |
// | Author | Code Evolution Agent v21.3.0-SIL6 |
// | STAMP | SC-TEST-001, SC-CLI-001, SC-ZENOH-007 |
// =============================================================================

module Cepaf.Tests.Unit.Mesh.CliEnvelopeTests

open Expecto
open Cepaf.Mesh
open System.Text.Json

// Helper: deserialise a JSON array of SystemMetric from a Result<string,string>
let private parseMetrics (result: Result<string, string>) : SystemMetric list =
    match result with
    | Error e -> failtest $"Expected Ok JSON, got Error: {e}"
    | Ok json ->
        let opts = JsonSerializerOptions()
        JsonSerializer.Deserialize<SystemMetric list>(json, opts)

[<Tests>]
let tests = testList "CliEnvelope" [

    // =========================================================================
    // getSystemMetrics Tests
    // =========================================================================
    testList "getSystemMetrics" [

        test "getSystemMetrics returns Ok" {
            let result = CliEnvelope.getSystemMetrics ()
            Expect.isOk result "getSystemMetrics should succeed in stub mode"
        }

        test "getSystemMetrics returns valid JSON" {
            let result = CliEnvelope.getSystemMetrics ()
            match result with
            | Ok json ->
                Expect.isTrue (json.TrimStart().StartsWith("["))
                    "System metrics should be a JSON array"
            | Error e -> failtest $"getSystemMetrics failed: {e}"
        }

        test "getSystemMetrics returns at least 5 metrics" {
            let metrics = parseMetrics (CliEnvelope.getSystemMetrics ())
            Expect.isGreaterThanOrEqual (List.length metrics) 5
                "Should include cpu, memory_used, memory_total, disk_free, disk_total at minimum"
        }

        test "getSystemMetrics includes cpu_utilization metric" {
            let metrics = parseMetrics (CliEnvelope.getSystemMetrics ())
            let hasCpu = metrics |> List.exists (fun m -> m.Name = "cpu_utilization")
            Expect.isTrue hasCpu "Metrics should include cpu_utilization"
        }

        test "getSystemMetrics includes memory_utilization metric" {
            let metrics = parseMetrics (CliEnvelope.getSystemMetrics ())
            let hasMem = metrics |> List.exists (fun m -> m.Name = "memory_utilization")
            Expect.isTrue hasMem "Metrics should include memory_utilization"
        }

        test "getSystemMetrics all status values are ok/warn/crit" {
            let metrics = parseMetrics (CliEnvelope.getSystemMetrics ())
            let validStatuses = Set.ofList ["ok"; "warn"; "crit"]
            for m in metrics do
                Expect.isTrue
                    (Set.contains m.Status validStatuses)
                    $"Metric '{m.Name}' status '{m.Status}' must be ok/warn/crit"
        }

        test "getSystemMetrics all Value fields are non-negative" {
            let metrics = parseMetrics (CliEnvelope.getSystemMetrics ())
            for m in metrics do
                Expect.isGreaterThanOrEqual m.Value 0.0
                    $"Metric '{m.Name}' value {m.Value} must be >= 0"
        }

        test "getSystemMetrics all Name fields are non-empty" {
            let metrics = parseMetrics (CliEnvelope.getSystemMetrics ())
            for m in metrics do
                Expect.isNotEmpty m.Name
                    "Every SystemMetric must have a non-empty Name"
        }
    ]

    // =========================================================================
    // getContainerMetrics Tests
    // =========================================================================
    testList "getContainerMetrics" [

        test "getContainerMetrics returns Ok" {
            let result = CliEnvelope.getContainerMetrics ()
            Expect.isOk result "getContainerMetrics should succeed in stub mode"
        }

        test "getContainerMetrics includes containers_healthy summary metric" {
            let metrics = parseMetrics (CliEnvelope.getContainerMetrics ())
            let hasSummary = metrics |> List.exists (fun m -> m.Name = "containers_healthy")
            Expect.isTrue hasSummary "Should include containers_healthy summary metric"
        }

        test "getContainerMetrics containers_healthy value is non-negative" {
            let metrics = parseMetrics (CliEnvelope.getContainerMetrics ())
            match metrics |> List.tryFind (fun m -> m.Name = "containers_healthy") with
            | Some m -> Expect.isGreaterThanOrEqual m.Value 0.0 "containers_healthy should be >= 0"
            | None   -> failtest "containers_healthy metric not found"
        }

        test "getContainerMetrics returns at least 1 metric (summary)" {
            let metrics = parseMetrics (CliEnvelope.getContainerMetrics ())
            Expect.isGreaterThanOrEqual (List.length metrics) 1
                "Should have at least the containers_healthy summary metric"
        }

        test "getContainerMetrics with running containers includes per-container metrics" {
            let metrics = parseMetrics (CliEnvelope.getContainerMetrics ())
            let containerMetrics = metrics |> List.filter (fun m -> m.Name.StartsWith("container_"))
            let summary = metrics |> List.tryFind (fun m -> m.Name = "containers_healthy")
            match summary with
            | Some s when s.Value > 0.0 ->
                Expect.isGreaterThan (List.length containerMetrics) 0
                    "When containers are running, per-container metrics should be present"
            | _ ->
                // No containers running — only summary metric expected
                Expect.equal (List.length containerMetrics) 0
                    "When no containers running, no per-container metrics expected"
        }

        test "getContainerMetrics all container metrics have status ok in stub" {
            let metrics = parseMetrics (CliEnvelope.getContainerMetrics ())
            let containerMetrics =
                metrics |> List.filter (fun m -> m.Name.StartsWith("container_"))
            for m in containerMetrics do
                Expect.equal m.Status "ok"
                    $"Container '{m.Name}' should be ok in healthy stub"
        }

        test "getContainerMetrics all container Value is 1.0 for healthy containers" {
            let metrics = parseMetrics (CliEnvelope.getContainerMetrics ())
            let containerMetrics =
                metrics |> List.filter (fun m -> m.Name.StartsWith("container_"))
            for m in containerMetrics do
                Expect.equal m.Value 1.0
                    $"Healthy container '{m.Name}' should have Value 1.0"
        }
    ]

    // =========================================================================
    // getZenohMetrics Tests
    // =========================================================================
    testList "getZenohMetrics" [

        test "getZenohMetrics returns Ok" {
            let result = CliEnvelope.getZenohMetrics ()
            Expect.isOk result "getZenohMetrics should succeed in stub mode"
        }

        test "getZenohMetrics includes zenoh_connected metric" {
            let metrics = parseMetrics (CliEnvelope.getZenohMetrics ())
            let hasConnected = metrics |> List.exists (fun m -> m.Name = "zenoh_connected")
            Expect.isTrue hasConnected "Zenoh metrics should include zenoh_connected (SC-ZENOH-007)"
        }

        test "getZenohMetrics zenoh_connected is 1.0 in stub (healthy)" {
            let metrics = parseMetrics (CliEnvelope.getZenohMetrics ())
            match metrics |> List.tryFind (fun m -> m.Name = "zenoh_connected") with
            | Some m -> Expect.equal m.Value 1.0 "zenoh_connected should be 1.0 in healthy stub"
            | None   -> failtest "zenoh_connected metric not found"
        }

        test "getZenohMetrics includes zenoh_publications metric" {
            let metrics = parseMetrics (CliEnvelope.getZenohMetrics ())
            let hasPubs = metrics |> List.exists (fun m -> m.Name = "zenoh_publications")
            Expect.isTrue hasPubs "Zenoh metrics should include zenoh_publications"
        }

        test "getZenohMetrics includes zenoh_pub_latency_ms metric" {
            let metrics = parseMetrics (CliEnvelope.getZenohMetrics ())
            let hasLatency = metrics |> List.exists (fun m -> m.Name = "zenoh_pub_latency_ms")
            Expect.isTrue hasLatency "Zenoh metrics should include zenoh_pub_latency_ms (SC-ZENOH-004)"
        }

        test "getZenohMetrics latency_ms is below 100.0 in stub" {
            let metrics = parseMetrics (CliEnvelope.getZenohMetrics ())
            match metrics |> List.tryFind (fun m -> m.Name = "zenoh_pub_latency_ms") with
            | Some m ->
                Expect.isLessThan m.Value 100.0
                    $"zenoh_pub_latency_ms {m.Value} should be < 100ms (SC-ZENOH-004)"
            | None -> failtest "zenoh_pub_latency_ms not found"
        }

        test "getZenohMetrics returns at least 4 metrics" {
            let metrics = parseMetrics (CliEnvelope.getZenohMetrics ())
            Expect.isGreaterThanOrEqual (List.length metrics) 4
                "Should include connected, publications, subscriptions, latency at minimum"
        }
    ]

    // =========================================================================
    // formatEnvelope Tests
    // =========================================================================
    testList "formatEnvelope" [

        test "formatEnvelope with valid JSON returns non-empty string" {
            match CliEnvelope.getSystemMetrics () with
            | Error e -> failtest $"getSystemMetrics failed: {e}"
            | Ok json ->
                let output = CliEnvelope.formatEnvelope json
                Expect.isNotEmpty output "formatEnvelope should produce non-empty output"
        }

        test "formatEnvelope output contains metric names" {
            match CliEnvelope.getSystemMetrics () with
            | Error e -> failtest $"getSystemMetrics failed: {e}"
            | Ok json ->
                let output = CliEnvelope.formatEnvelope json
                Expect.isTrue
                    (output.Contains("cpu_utilization"))
                    "Formatted output should contain cpu_utilization metric name"
        }

        test "formatEnvelope with invalid JSON returns error indicator string" {
            let output = CliEnvelope.formatEnvelope "not valid json {"
            Expect.isTrue
                (output.Contains("?") || output.Contains("error") || output.Contains("Error"))
                "formatEnvelope with invalid JSON should return an error indicator"
        }

        test "formatEnvelope with ok status includes '+' icon" {
            // Craft a single ok metric
            let singleOk = """[{"Name":"cpu_utilization","Value":30.0,"Unit":"%","Status":"ok"}]"""
            let output = CliEnvelope.formatEnvelope singleOk
            Expect.isTrue (output.Contains("+"))
                "ok status should render as '+' icon"
        }

        test "formatEnvelope with warn status includes '!' icon" {
            let singleWarn = """[{"Name":"mem","Value":80.0,"Unit":"%","Status":"warn"}]"""
            let output = CliEnvelope.formatEnvelope singleWarn
            Expect.isTrue (output.Contains("!"))
                "warn status should render as '!' icon"
        }

        test "formatEnvelope with crit status includes 'X' icon" {
            let singleCrit = """[{"Name":"disk","Value":95.0,"Unit":"%","Status":"crit"}]"""
            let output = CliEnvelope.formatEnvelope singleCrit
            Expect.isTrue (output.Contains("X"))
                "crit status should render as 'X' icon"
        }

        test "formatEnvelope with empty JSON array returns empty or whitespace output" {
            let output = CliEnvelope.formatEnvelope "[]"
            // Empty list means no lines appended — output is either empty or just newlines
            Expect.isTrue
                (output.Trim() = "" || output = "")
                "Empty metric list should produce empty/whitespace output"
        }
    ]

    // =========================================================================
    // renderDashboard Tests
    // =========================================================================
    testList "renderDashboard" [

        test "renderDashboard returns Ok" {
            let result = CliEnvelope.renderDashboard ()
            Expect.isOk result "renderDashboard should return Ok in stub mode"
        }

        test "renderDashboard output is non-empty" {
            match CliEnvelope.renderDashboard () with
            | Ok output -> Expect.isNotEmpty output "Dashboard output should not be empty"
            | Error e   -> failtest $"renderDashboard failed: {e}"
        }

        test "renderDashboard output contains INDRAJAAL header" {
            match CliEnvelope.renderDashboard () with
            | Ok output ->
                Expect.isTrue (output.Contains("INDRAJAAL"))
                    "Dashboard should contain INDRAJAAL header"
            | Error e -> failtest $"renderDashboard failed: {e}"
        }

        test "renderDashboard output contains System section" {
            match CliEnvelope.renderDashboard () with
            | Ok output ->
                Expect.isTrue (output.Contains("System"))
                    "Dashboard should contain System section"
            | Error e -> failtest $"renderDashboard failed: {e}"
        }

        test "renderDashboard output contains Zenoh section" {
            match CliEnvelope.renderDashboard () with
            | Ok output ->
                Expect.isTrue (output.Contains("Zenoh"))
                    "Dashboard should contain Zenoh section (SC-ZENOH-007)"
            | Error e -> failtest $"renderDashboard failed: {e}"
        }

        test "renderDashboard output contains Containers section" {
            match CliEnvelope.renderDashboard () with
            | Ok output ->
                Expect.isTrue (output.Contains("Containers") || output.Contains("container"))
                    "Dashboard should contain Containers section"
            | Error e -> failtest $"renderDashboard failed: {e}"
        }

        test "renderDashboard output contains node identifier" {
            match CliEnvelope.renderDashboard () with
            | Ok output ->
                Expect.isTrue (output.Contains("indrajaal@"))
                    "Dashboard should contain node identifier (FQUN format)"
            | Error e -> failtest $"renderDashboard failed: {e}"
        }
    ]
]
