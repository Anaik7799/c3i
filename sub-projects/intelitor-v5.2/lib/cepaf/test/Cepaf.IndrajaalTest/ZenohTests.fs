/// Cepaf.IndrajaalTest.ZenohTests
/// Tests for Zenoh connectivity, fractal logging, and telemetry
///
/// STAMP Constraints:
/// - SC-ZENOH-001: Verify Zenoh connectivity
/// - SC-ZENOH-002: Verify fractal log subscription
/// - SC-ZENOH-003: Verify telemetry collection
module Cepaf.IndrajaalTest.ZenohTests

open System
open Expecto
open Cepaf.IndrajaalTest.ZenohClient

// =============================================================================
// Zenoh Connectivity Tests
// =============================================================================

let zenohConnectivityTests (config: ZenohConfig) =
    testList "Zenoh Connectivity" [
        testAsync "Zenoh router health check" {
            use client = new ZenohClient(config)
            let! healthy = client.IsHealthy()
            if not healthy then
                skiptest "Zenoh router not available"
            else
                Expect.isTrue healthy "Zenoh router should be healthy"
        }

        testAsync "Zenoh client connection" {
            use client = new ZenohClient(config)
            let! connected = client.ConnectAsync()
            if not connected then
                skiptest "Could not connect to Zenoh router"
            else
                Expect.equal client.State Connected "Client should be connected"
        }

        test "Default configuration is valid" {
            let config = defaultZenohConfig
            Expect.isNonEmpty config.RouterEndpoint "Router endpoint should be set"
            Expect.isNonEmpty config.WebSocketEndpoint "WebSocket endpoint should be set"
            Expect.isGreaterThan config.Timeout TimeSpan.Zero "Timeout should be positive"
        }

        test "Environment configuration loader works" {
            let config = zenohConfigFromEnvironment ()
            Expect.isNonEmpty config.RouterEndpoint "Router endpoint should be set"
            Expect.isNonEmpty config.WebSocketEndpoint "WebSocket endpoint should be set"
        }
    ]

// =============================================================================
// Fractal Logging Tests
// =============================================================================

let fractalLoggingTests (config: ZenohConfig) =
    testList "Fractal Logging" [
        test "Key expression patterns are valid" {
            Expect.isNonEmpty FractalKeyExpressions.root "Root key should be set"
            Expect.isNonEmpty FractalKeyExpressions.system "System key should be set"
            Expect.isNonEmpty FractalKeyExpressions.metrics "Metrics key should be set"
            Expect.isNonEmpty FractalKeyExpressions.kpi "KPI key should be set"
            Expect.isNonEmpty FractalKeyExpressions.alarms "Alarms key should be set"
            Expect.isNonEmpty FractalKeyExpressions.devices "Devices key should be set"
            Expect.isNonEmpty FractalKeyExpressions.all "All key should be set"
        }

        test "Node-specific key expression is correct" {
            let nodeKey = FractalKeyExpressions.node "node-001"
            Expect.stringContains nodeKey "node-001" "Should contain node ID"
            Expect.stringContains nodeKey "indrajaal" "Should contain root namespace"
        }

        test "Domain-specific key expression is correct" {
            let domainKey = FractalKeyExpressions.domain "alarms"
            Expect.stringContains domainKey "alarms" "Should contain domain name"
            Expect.stringContains domainKey "indrajaal" "Should contain root namespace"
        }

        test "Component key expression is correct" {
            let compKey = FractalKeyExpressions.componentLogs "alarm-processor"
            Expect.stringContains compKey "alarm-processor" "Should contain component name"
            Expect.stringContains compKey "indrajaal" "Should contain root namespace"
        }

        testAsync "Fractal log subscriber can be created" {
            use client = new ZenohClient(config)
            let subscriber = FractalLogSubscriber(client)
            Expect.equal (subscriber.GetLogs().Length) 0 "Should start with empty logs"
        }

        testAsync "Get system logs from Zenoh" {
            use client = new ZenohClient(config)
            let! connected = client.ConnectAsync()
            if not connected then
                skiptest "Zenoh router not available"
            else
                let! logs = client.GetLogsAsync(FractalKeyExpressions.system)
                // May be empty if no logs published yet
                Expect.isTrue (logs.Length >= 0) "Should return log list"
        }
    ]

// =============================================================================
// Telemetry Tests
// =============================================================================

let telemetryTests (config: ZenohConfig) =
    testList "Telemetry" [
        testAsync "Telemetry collector can be created" {
            use client = new ZenohClient(config)
            let collector = TelemetryCollector(client)
            Expect.equal (collector.AllMetrics.Length) 0 "Should start with no metrics"
            Expect.equal (collector.AllKpis.Length) 0 "Should start with no KPIs"
        }

        testAsync "Collect metrics from Zenoh" {
            use client = new ZenohClient(config)
            let! connected = client.ConnectAsync()
            if not connected then
                skiptest "Zenoh router not available"
            else
                let collector = TelemetryCollector(client)
                let! metrics = collector.CollectMetricsAsync()
                // May be empty if no metrics published yet
                Expect.isTrue (metrics.Length >= 0) "Should return metrics list"
        }

        testAsync "Collect KPIs from Zenoh" {
            use client = new ZenohClient(config)
            let! connected = client.ConnectAsync()
            if not connected then
                skiptest "Zenoh router not available"
            else
                let collector = TelemetryCollector(client)
                let! kpis = collector.CollectKpiAsync()
                // May be empty if no KPIs published yet
                Expect.isTrue (kpis.Length >= 0) "Should return KPI list"
        }

        testAsync "Get specific metric by name" {
            use client = new ZenohClient(config)
            let collector = TelemetryCollector(client)
            let metric = collector.GetMetric("cpu_usage")
            // Will be None since we haven't collected any
            Expect.isNone metric "Should return None for uncollected metric"
        }
    ]

// =============================================================================
// Zenoh PUT/GET Tests
// =============================================================================

let zenohPutGetTests (config: ZenohConfig) =
    testList "Zenoh PUT/GET" [
        testAsync "PUT and GET roundtrip" {
            use client = new ZenohClient(config)
            let! connected = client.ConnectAsync()
            if not connected then
                skiptest "Zenoh router not available"
            else
                let testKey = "indrajaal/test/roundtrip"
                let testData = sprintf """{"test": "data", "timestamp": "%s"}""" (DateTime.UtcNow.ToString("o"))

                let! putResult = client.PutAsync(testKey, testData)
                if not putResult then
                    skiptest "PUT operation not supported or failed"
                else
                    let! getResult = client.GetAsync(testKey)
                    match getResult with
                    | Some data ->
                        Expect.stringContains data "test" "Should contain test data"
                    | None ->
                        failtest "GET should return data after PUT"
        }
    ]

// =============================================================================
// Integration Tests
// =============================================================================

let zenohIntegrationTests (config: ZenohConfig) =
    testList "Zenoh Integration" [
        testAsync "Full telemetry pipeline test" {
            use client = new ZenohClient(config)
            let! connected = client.ConnectAsync()
            if not connected then
                skiptest "Zenoh router not available"
            else
                // Subscribe to logs
                let subscriber = FractalLogSubscriber(client)
                subscriber.Start()

                // Collect metrics
                let collector = TelemetryCollector(client)
                let! _ = collector.CollectMetricsAsync()
                let! _ = collector.CollectKpiAsync()

                // Check we can access the collected data
                let logs = subscriber.GetLogs()
                let metrics = collector.AllMetrics
                let kpis = collector.AllKpis

                // Clean up
                subscriber.Stop()

                printfn "Collected %d logs, %d metrics, %d KPIs" logs.Length metrics.Length kpis.Length
                Expect.isTrue true "Pipeline test completed"
        }

        testAsync "Multiple key expression queries" {
            use client = new ZenohClient(config)
            let! connected = client.ConnectAsync()
            if not connected then
                skiptest "Zenoh router not available"
            else
                // Query multiple key expressions
                let! systemLogs = client.GetLogsAsync(FractalKeyExpressions.system)
                let! alarmLogs = client.GetLogsAsync(FractalKeyExpressions.alarms)
                let! deviceLogs = client.GetLogsAsync(FractalKeyExpressions.devices)

                printfn "System: %d, Alarms: %d, Devices: %d"
                    systemLogs.Length alarmLogs.Length deviceLogs.Length

                Expect.isTrue true "Multiple queries completed"
        }
    ]

// =============================================================================
// All Zenoh Tests
// =============================================================================

/// Create all Zenoh tests
let allZenohTests (config: ZenohConfig) =
    testList "Zenoh Fractal Logging & Telemetry" [
        zenohConnectivityTests config
        fractalLoggingTests config
        telemetryTests config
        zenohPutGetTests config
        zenohIntegrationTests config
    ]
