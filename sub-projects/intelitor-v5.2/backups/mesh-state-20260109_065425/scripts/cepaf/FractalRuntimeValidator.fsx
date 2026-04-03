#!/usr/bin/env dotnet fsi
// FractalRuntimeValidator.fsx - v1.1.0
// WHAT: Fractal criticality-based runtime validation with mathematical KPIs
// WHY: Dimensional, multidimensional, and full envelope testing with agent monitoring
// ARCHITECTURE: 3-container (db, obs, app) with Cortex evolution tracking
// CONSTRAINTS: Requires OpenRouter API, Podman 5.4.1+, .NET SDK 8.0+
// SOPv5.11 Compliance: SC-OODA-001, SC-SWARM-001, SC-UX-001, SC-CNT-009, SC-METRICS-003
// ELIXIR_ERL_OPTIONS: "+S 16:16 +SDio 16" for 16 schedulers, 16 dirty I/O schedulers

#r "nuget: FSharp.Data, 6.3.0"
#r "nuget: FSharp.SystemTextJson, 1.2.42"
#r "nuget: MathNet.Numerics, 5.0.0"
#r "nuget: MathNet.Numerics.FSharp, 5.0.0"

open System
open System.IO
open System.Net.Http
open System.Text
open System.Text.Json
open System.Diagnostics
open System.Collections.Concurrent
open MathNet.Numerics
open MathNet.Numerics.Statistics
open MathNet.Numerics.LinearAlgebra

// =============================================================================
// MATHEMATICAL FRAMEWORK
// =============================================================================

module MathKPI =
    /// Criticality levels based on FMEA RPN (Risk Priority Number)
    type CriticalityLevel =
        | C1_Critical    // RPN > 200 - System failure, data loss
        | C2_High        // RPN 100-200 - Major functionality impact
        | C3_Medium      // RPN 50-100 - Moderate impact
        | C4_Low         // RPN 25-50 - Minor impact
        | C5_Negligible  // RPN < 25 - Cosmetic only

    /// Test dimension for fractal coverage
    type TestDimension =
        | Functional       // Business logic correctness
        | Performance      // Response time, throughput
        | Reliability      // Uptime, error rates
        | Security         // Auth, authorization, encryption
        | Usability        // UX heuristics, accessibility
        | Maintainability  // Code quality, documentation
        | Scalability      // Load handling, resource usage
        | Observability    // Logging, metrics, tracing

    /// Coverage envelope definition
    type CoverageEnvelope = {
        Dimensions: TestDimension list
        CriticalityWeights: Map<CriticalityLevel, float>
        MinCoverage: float  // 0.0 - 1.0
        TargetCoverage: float
        ActualCoverage: float
    }

    /// Mathematical KPIs for runtime testing
    type RuntimeKPIs = {
        // Core metrics
        MTBF: float             // Mean Time Between Failures (hours)
        MTTR: float             // Mean Time To Recovery (minutes)
        Availability: float     // % uptime (target: 99.9%)
        ErrorRate: float        // Errors per 1000 requests

        // Performance metrics
        P50Latency: float       // 50th percentile response time (ms)
        P95Latency: float       // 95th percentile response time (ms)
        P99Latency: float       // 99th percentile response time (ms)
        Throughput: float       // Requests per second

        // Quality metrics
        DefectDensity: float    // Defects per KLOC
        TestCoverage: float     // % code coverage
        TechnicalDebt: float    // Hours of remediation

        // Fractal metrics
        DimensionalCoverage: Map<TestDimension, float>
        CriticalityCoverage: Map<CriticalityLevel, float>
        EnvelopeCoverage: float // Overall coverage envelope score
    }

    /// Calculate RPN (Risk Priority Number)
    let calculateRPN (severity: int) (occurrence: int) (detection: int) : int =
        severity * occurrence * detection

    /// Map RPN to criticality level
    let rpnToCriticality (rpn: int) : CriticalityLevel =
        match rpn with
        | r when r > 200 -> C1_Critical
        | r when r > 100 -> C2_High
        | r when r > 50 -> C3_Medium
        | r when r > 25 -> C4_Low
        | _ -> C5_Negligible

    /// Calculate coverage envelope score using weighted dimensions
    let calculateEnvelopeCoverage (coverage: Map<TestDimension, float>) (weights: Map<TestDimension, float>) : float =
        let totalWeight = weights |> Map.fold (fun acc _ w -> acc + w) 0.0
        let weightedSum =
            coverage
            |> Map.fold (fun acc dim cov ->
                let weight = weights |> Map.tryFind dim |> Option.defaultValue 1.0
                acc + (cov * weight)) 0.0
        weightedSum / totalWeight

    /// Calculate statistical confidence interval
    let confidenceInterval (data: float array) (confidence: float) : float * float =
        if data.Length = 0 then (0.0, 0.0)
        else
            let mean = Statistics.Mean(data)
            let stdDev = Statistics.StandardDeviation(data)
            let n = float data.Length
            let z = 1.96 // 95% confidence
            let margin = z * (stdDev / sqrt n)
            (mean - margin, mean + margin)

// =============================================================================
// FRACTAL TEST FRAMEWORK
// =============================================================================

module FractalTests =
    open MathKPI

    /// Fractal test level (self-similar at each scale)
    type FractalLevel =
        | L1_System      // Full system integration
        | L2_Container   // Container-level tests
        | L3_Component   // Component-level tests
        | L4_Module      // Module-level tests
        | L5_Unit        // Unit-level tests

    /// Test case with fractal properties
    type FractalTestCase = {
        Id: string
        Name: string
        Level: FractalLevel
        Dimension: TestDimension
        Criticality: CriticalityLevel
        RPN: int
        Dependencies: string list
        SubTests: FractalTestCase list  // Fractal recursion
        Execute: unit -> Async<TestResult>
    }

    and TestResult = {
        TestId: string
        Passed: bool
        Duration: TimeSpan
        Metrics: Map<string, float>
        SubResults: TestResult list
        Error: string option
        Timestamp: DateTime
    }

    /// Test suite organized by criticality
    type CriticalityTestSuite = {
        Level: CriticalityLevel
        Tests: FractalTestCase list
        RequiredPassRate: float
        Weight: float
    }

    /// Create default dimension weights
    let defaultDimensionWeights : Map<TestDimension, float> =
        Map.ofList [
            (Functional, 2.0)
            (Performance, 1.5)
            (Reliability, 2.0)
            (Security, 2.5)
            (Usability, 1.0)
            (Maintainability, 0.5)
            (Scalability, 1.5)
            (Observability, 1.0)
        ]

    /// Create default criticality weights
    let defaultCriticalityWeights : Map<CriticalityLevel, float> =
        Map.ofList [
            (C1_Critical, 10.0)
            (C2_High, 5.0)
            (C3_Medium, 2.0)
            (C4_Low, 1.0)
            (C5_Negligible, 0.5)
        ]

// =============================================================================
// CORTEX AGENT MONITORING
// =============================================================================

module CortexMonitor =
    open MathKPI
    open FractalTests

    /// Agent observation state
    type AgentObservation = {
        AgentId: string
        Timestamp: DateTime
        TestId: string
        Metrics: RuntimeKPIs
        Anomalies: string list
        Recommendations: string list
    }

    /// Cortex evolution state
    type CortexState = {
        Generation: int
        Observations: AgentObservation list
        LearningRate: float
        EvolutionHistory: Map<int, RuntimeKPIs>
        CurrentFitness: float
        TargetFitness: float
    }

    /// Initialize cortex state
    let initCortex () : CortexState = {
        Generation = 0
        Observations = []
        LearningRate = 0.1
        EvolutionHistory = Map.empty
        CurrentFitness = 0.0
        TargetFitness = 0.95
    }

    /// Agent observes test execution
    let observe (state: CortexState) (result: TestResult) (kpis: RuntimeKPIs) : AgentObservation =
        let anomalies =
            [
                if kpis.P99Latency > 500.0 then "High P99 latency detected"
                if kpis.ErrorRate > 1.0 then "Error rate exceeds threshold"
                if kpis.Availability < 0.999 then "Availability below 99.9%"
                if kpis.EnvelopeCoverage < 0.80 then "Coverage envelope below 80%"
            ]

        let recommendations =
            [
                if kpis.P99Latency > 200.0 then "Consider caching or query optimization"
                if kpis.TestCoverage < 0.80 then "Increase test coverage"
                if kpis.TechnicalDebt > 100.0 then "Address technical debt"
            ]

        {
            AgentId = $"agent-{Guid.NewGuid().ToString().Substring(0, 8)}"
            Timestamp = DateTime.UtcNow
            TestId = result.TestId
            Metrics = kpis
            Anomalies = anomalies
            Recommendations = recommendations
        }

    /// Evolve cortex based on observations
    let evolve (state: CortexState) : CortexState =
        if state.Observations.Length = 0 then state
        else
            let latestKPIs = state.Observations |> List.head |> fun o -> o.Metrics
            let fitness = latestKPIs.EnvelopeCoverage

            { state with
                Generation = state.Generation + 1
                EvolutionHistory = state.EvolutionHistory |> Map.add state.Generation latestKPIs
                CurrentFitness = fitness
                LearningRate =
                    if fitness < state.TargetFitness
                    then min 0.5 (state.LearningRate * 1.1)
                    else max 0.01 (state.LearningRate * 0.9)
            }

// =============================================================================
// HTTP & SHELL UTILITIES
// =============================================================================

module Http =
    let private client = new HttpClient(Timeout = TimeSpan.FromSeconds(30.0))

    let get (url: string) : Async<Result<string, string>> = async {
        try
            let! response = client.GetAsync(url) |> Async.AwaitTask
            if response.IsSuccessStatusCode then
                let! content = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                return Ok content
            else
                return Error $"HTTP {int response.StatusCode}: {response.ReasonPhrase}"
        with ex ->
            return Error ex.Message
    }

module Shell =
    // SC-METRICS-003: Mandatory parallelization environment variables
    let mandatoryEnvVars = [
        ("ELIXIR_ERL_OPTIONS", "+S 16:16 +SDio 16")
        ("NO_TIMEOUT", "true")
        ("PATIENT_MODE", "enabled")
        ("INFINITE_PATIENCE", "true")
        ("MIX_OS_DEPS_COMPILE_PARTITION_COUNT", "8")
        ("SKIP_ZENOH_NIF", "0")
    ]

    let injectMandatoryEnv (psi: ProcessStartInfo) =
        for (key, value) in mandatoryEnvVars do
            psi.EnvironmentVariables.[key] <- value

    let exec (command: string) (args: string) : Async<Result<string, string>> = async {
        try
            let psi = ProcessStartInfo(
                FileName = command,
                Arguments = args,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            )
            injectMandatoryEnv psi  // SC-METRICS-003: Inject mandatory env vars
            use proc = new Process(StartInfo = psi)
            proc.Start() |> ignore
            let! output = proc.StandardOutput.ReadToEndAsync() |> Async.AwaitTask
            let! error = proc.StandardError.ReadToEndAsync() |> Async.AwaitTask
            proc.WaitForExit()
            if proc.ExitCode = 0 then return Ok output
            else return Error (if String.IsNullOrEmpty error then output else error)
        with ex ->
            return Error ex.Message
    }

// =============================================================================
// TEST CASE DEFINITIONS
// =============================================================================

module TestCases =
    open MathKPI
    open FractalTests

    /// Create a test result
    let makeResult id passed duration metrics error : TestResult = {
        TestId = id
        Passed = passed
        Duration = duration
        Metrics = metrics
        SubResults = []
        Error = error
        Timestamp = DateTime.UtcNow
    }

    // =========================================================================
    // C1 CRITICAL TESTS (RPN > 200)
    // =========================================================================

    let c1_database_connectivity : FractalTestCase = {
        Id = "C1-DB-001"
        Name = "Database Connectivity"
        Level = L2_Container
        Dimension = Reliability
        Criticality = C1_Critical
        RPN = 240  // Sev:8 x Occ:5 x Det:6
        Dependencies = []
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Shell.exec "podman" "exec indrajaal-db-prod pg_isready -U postgres -d indrajaal_prod -p 5433" with
            | Ok _ ->
                sw.Stop()
                return makeResult "C1-DB-001" true sw.Elapsed
                    (Map.ofList [("connection_ms", sw.Elapsed.TotalMilliseconds)]) None
            | Error e ->
                sw.Stop()
                return makeResult "C1-DB-001" false sw.Elapsed Map.empty (Some e)
        }
    }

    let c1_app_health : FractalTestCase = {
        Id = "C1-APP-001"
        Name = "Application Health"
        Level = L2_Container
        Dimension = Reliability
        Criticality = C1_Critical
        RPN = 280  // Sev:10 x Occ:4 x Det:7
        Dependencies = ["C1-DB-001"]
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Http.get "http://localhost:4001/health" with
            | Ok _ ->
                sw.Stop()
                return makeResult "C1-APP-001" true sw.Elapsed
                    (Map.ofList [("health_check_ms", sw.Elapsed.TotalMilliseconds)]) None
            | Error e ->
                sw.Stop()
                return makeResult "C1-APP-001" false sw.Elapsed Map.empty (Some e)
        }
    }

    let c1_redis_embedded : FractalTestCase = {
        Id = "C1-REDIS-001"
        Name = "Embedded Redis"
        Level = L2_Container
        Dimension = Reliability
        Criticality = C1_Critical
        RPN = 210  // Sev:7 x Occ:5 x Det:6
        Dependencies = ["C1-APP-001"]
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Shell.exec "podman" "exec indrajaal-app-prod redis-cli ping" with
            | Ok output when output.Trim() = "PONG" ->
                sw.Stop()
                return makeResult "C1-REDIS-001" true sw.Elapsed
                    (Map.ofList [("ping_ms", sw.Elapsed.TotalMilliseconds)]) None
            | Ok _ | Error _ as result ->
                sw.Stop()
                let error = match result with Error e -> e | _ -> "Invalid response"
                return makeResult "C1-REDIS-001" false sw.Elapsed Map.empty (Some error)
        }
    }

    // =========================================================================
    // C2 HIGH TESTS (RPN 100-200)
    // =========================================================================

    let c2_otel_health : FractalTestCase = {
        Id = "C2-OTEL-001"
        Name = "OTEL Collector (obs container)"
        Level = L2_Container
        Dimension = Observability
        Criticality = C2_High
        RPN = 150  // Sev:6 x Occ:5 x Det:5
        Dependencies = []
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Http.get "http://localhost:8888/health" with
            | Ok _ ->
                sw.Stop()
                return makeResult "C2-OTEL-001" true sw.Elapsed
                    (Map.ofList [("otel_ms", sw.Elapsed.TotalMilliseconds)]) None
            | Error e ->
                sw.Stop()
                return makeResult "C2-OTEL-001" false sw.Elapsed Map.empty (Some e)
        }
    }

    let c2_prometheus_health : FractalTestCase = {
        Id = "C2-PROM-001"
        Name = "Prometheus (obs container)"
        Level = L2_Container
        Dimension = Observability
        Criticality = C2_High
        RPN = 120  // Sev:6 x Occ:4 x Det:5
        Dependencies = ["C2-OTEL-001"]
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Http.get "http://localhost:9090/-/healthy" with
            | Ok _ ->
                sw.Stop()
                return makeResult "C2-PROM-001" true sw.Elapsed
                    (Map.ofList [("prometheus_ms", sw.Elapsed.TotalMilliseconds)]) None
            | Error e ->
                sw.Stop()
                return makeResult "C2-PROM-001" false sw.Elapsed Map.empty (Some e)
        }
    }

    let c2_prajna_dashboard : FractalTestCase = {
        Id = "C2-PRAJNA-001"
        Name = "Prajna Cockpit Dashboard"
        Level = L3_Component
        Dimension = Usability
        Criticality = C2_High
        RPN = 140  // Sev:7 x Occ:4 x Det:5
        Dependencies = ["C1-APP-001"]
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Http.get "http://localhost:4000/prajna" with
            | Ok response when response.Length > 500 ->
                sw.Stop()
                return makeResult "C2-PRAJNA-001" true sw.Elapsed
                    (Map.ofList [("load_ms", sw.Elapsed.TotalMilliseconds); ("page_size", float response.Length)]) None
            | Ok _ | Error _ as result ->
                sw.Stop()
                let error = match result with Error e -> e | _ -> "Insufficient response"
                return makeResult "C2-PRAJNA-001" false sw.Elapsed Map.empty (Some error)
        }
    }

    let c2_flame_enabled : FractalTestCase = {
        Id = "C2-FLAME-001"
        Name = "FLAME Distributed Processing"
        Level = L3_Component
        Dimension = Scalability
        Criticality = C2_High
        RPN = 160  // Sev:8 x Occ:4 x Det:5
        Dependencies = ["C1-APP-001"]
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Shell.exec "podman" "exec indrajaal-app-prod printenv FLAME_ENABLED" with
            | Ok output when output.Trim() = "true" ->
                sw.Stop()
                return makeResult "C2-FLAME-001" true sw.Elapsed Map.empty None
            | Ok _ | Error _ ->
                sw.Stop()
                return makeResult "C2-FLAME-001" false sw.Elapsed Map.empty (Some "FLAME not enabled")
        }
    }

    let c2_clustering_enabled : FractalTestCase = {
        Id = "C2-CLUSTER-001"
        Name = "Elixir Clustering"
        Level = L3_Component
        Dimension = Scalability
        Criticality = C2_High
        RPN = 160  // Sev:8 x Occ:4 x Det:5
        Dependencies = ["C1-APP-001"]
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Shell.exec "podman" "exec indrajaal-app-prod printenv CLUSTERING_ENABLED" with
            | Ok output when output.Trim() = "true" ->
                sw.Stop()
                return makeResult "C2-CLUSTER-001" true sw.Elapsed Map.empty None
            | Ok _ | Error _ ->
                sw.Stop()
                return makeResult "C2-CLUSTER-001" false sw.Elapsed Map.empty (Some "Clustering not enabled")
        }
    }

    // =========================================================================
    // C3 MEDIUM TESTS (RPN 50-100)
    // =========================================================================

    let c3_grafana_health : FractalTestCase = {
        Id = "C3-GRAFANA-001"
        Name = "Grafana (obs container)"
        Level = L3_Component
        Dimension = Observability
        Criticality = C3_Medium
        RPN = 75  // Sev:5 x Occ:3 x Det:5
        Dependencies = ["C2-PROM-001"]
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Http.get "http://localhost:3000/api/health" with
            | Ok _ ->
                sw.Stop()
                return makeResult "C3-GRAFANA-001" true sw.Elapsed
                    (Map.ofList [("grafana_ms", sw.Elapsed.TotalMilliseconds)]) None
            | Error e ->
                sw.Stop()
                return makeResult "C3-GRAFANA-001" false sw.Elapsed Map.empty (Some e)
        }
    }

    let c3_loki_health : FractalTestCase = {
        Id = "C3-LOKI-001"
        Name = "Loki (obs container)"
        Level = L3_Component
        Dimension = Observability
        Criticality = C3_Medium
        RPN = 60  // Sev:4 x Occ:3 x Det:5
        Dependencies = ["C2-OTEL-001"]
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Http.get "http://localhost:3100/ready" with
            | Ok _ ->
                sw.Stop()
                return makeResult "C3-LOKI-001" true sw.Elapsed
                    (Map.ofList [("loki_ms", sw.Elapsed.TotalMilliseconds)]) None
            | Error e ->
                sw.Stop()
                return makeResult "C3-LOKI-001" false sw.Elapsed Map.empty (Some e)
        }
    }

    let c3_ai_copilot : FractalTestCase = {
        Id = "C3-COPILOT-001"
        Name = "AI Copilot Interface"
        Level = L3_Component
        Dimension = Usability
        Criticality = C3_Medium
        RPN = 80  // Sev:4 x Occ:4 x Det:5
        Dependencies = ["C2-PRAJNA-001"]
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Http.get "http://localhost:4000/prajna/copilot" with
            | Ok _ ->
                sw.Stop()
                return makeResult "C3-COPILOT-001" true sw.Elapsed
                    (Map.ofList [("copilot_ms", sw.Elapsed.TotalMilliseconds)]) None
            | Error e ->
                sw.Stop()
                return makeResult "C3-COPILOT-001" false sw.Elapsed Map.empty (Some e)
        }
    }

    let c3_dark_mode : FractalTestCase = {
        Id = "C3-DARKMODE-001"
        Name = "Dark Mode Enabled"
        Level = L4_Module
        Dimension = Usability
        Criticality = C3_Medium
        RPN = 50  // Sev:2 x Occ:5 x Det:5
        Dependencies = ["C1-APP-001"]
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Shell.exec "podman" "exec indrajaal-app-prod printenv PRAJNA_DARK_MODE" with
            | Ok output when output.Trim() = "true" ->
                sw.Stop()
                return makeResult "C3-DARKMODE-001" true sw.Elapsed Map.empty None
            | Ok _ | Error _ ->
                sw.Stop()
                return makeResult "C3-DARKMODE-001" false sw.Elapsed Map.empty (Some "Dark mode not enabled")
        }
    }

    // =========================================================================
    // C4 LOW TESTS (RPN 25-50)
    // =========================================================================

    let c4_response_time : FractalTestCase = {
        Id = "C4-PERF-001"
        Name = "Response Time < 50ms"
        Level = L3_Component
        Dimension = Performance
        Criticality = C4_Low
        RPN = 40  // Sev:2 x Occ:4 x Det:5
        Dependencies = ["C1-APP-001"]
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Http.get "http://localhost:4000/prajna" with
            | Ok _ ->
                sw.Stop()
                let passed = sw.Elapsed.TotalMilliseconds < 50.0
                return makeResult "C4-PERF-001" passed sw.Elapsed
                    (Map.ofList [("response_ms", sw.Elapsed.TotalMilliseconds)]) None
            | Error e ->
                sw.Stop()
                return makeResult "C4-PERF-001" false sw.Elapsed Map.empty (Some e)
        }
    }

    let c4_mesh_network : FractalTestCase = {
        Id = "C4-NET-001"
        Name = "Mesh Network Configured"
        Level = L2_Container
        Dimension = Reliability
        Criticality = C4_Low
        RPN = 30  // Sev:2 x Occ:3 x Det:5
        Dependencies = []
        SubTests = []
        Execute = fun () -> async {
            let sw = Stopwatch.StartNew()
            match! Shell.exec "podman" "network inspect indrajaal-mesh" with
            | Ok output when output.Contains("indrajaal-mesh") ->
                sw.Stop()
                return makeResult "C4-NET-001" true sw.Elapsed Map.empty None
            | Ok _ | Error _ ->
                sw.Stop()
                return makeResult "C4-NET-001" false sw.Elapsed Map.empty (Some "Mesh network not found")
        }
    }

    // =========================================================================
    // ALL TEST SUITES
    // =========================================================================

    let allTests : FractalTestCase list = [
        // C1 Critical
        c1_database_connectivity
        c1_app_health
        c1_redis_embedded
        // C2 High
        c2_otel_health
        c2_prometheus_health
        c2_prajna_dashboard
        c2_flame_enabled
        c2_clustering_enabled
        // C3 Medium
        c3_grafana_health
        c3_loki_health
        c3_ai_copilot
        c3_dark_mode
        // C4 Low
        c4_response_time
        c4_mesh_network
    ]

    let testsByCriticality : Map<MathKPI.CriticalityLevel, FractalTestCase list> =
        allTests
        |> List.groupBy (fun t -> t.Criticality)
        |> Map.ofList

// =============================================================================
// FRACTAL TEST EXECUTOR
// =============================================================================

module FractalExecutor =
    open MathKPI
    open FractalTests
    open CortexMonitor
    open TestCases

    type ExecutionMode =
        | Dimensional of TestDimension  // Single dimension
        | MultiDimensional of TestDimension list  // Multiple dimensions
        | FullEnvelope  // All dimensions, all criticalities

    type ExecutionResult = {
        Mode: ExecutionMode
        Results: TestResult list
        KPIs: RuntimeKPIs
        CortexState: CortexState
        Duration: TimeSpan
        Timestamp: DateTime
    }

    let private calculateKPIs (results: TestResult list) : RuntimeKPIs =
        let latencies = results |> List.map (fun r -> r.Duration.TotalMilliseconds) |> List.toArray
        let passed = results |> List.filter (fun r -> r.Passed) |> List.length
        let total = results.Length

        // Calculate dimensional coverage
        let dimCoverage =
            allTests
            |> List.groupBy (fun t -> t.Dimension)
            |> List.map (fun (dim, tests) ->
                let testIds = tests |> List.map (fun t -> t.Id) |> Set.ofList
                let passedInDim =
                    results
                    |> List.filter (fun r -> testIds.Contains(r.TestId) && r.Passed)
                    |> List.length
                (dim, float passedInDim / float tests.Length))
            |> Map.ofList

        // Calculate criticality coverage
        let critCoverage =
            testsByCriticality
            |> Map.map (fun _ tests ->
                let testIds = tests |> List.map (fun t -> t.Id) |> Set.ofList
                let passedInCrit =
                    results
                    |> List.filter (fun r -> testIds.Contains(r.TestId) && r.Passed)
                    |> List.length
                float passedInCrit / float tests.Length)

        {
            MTBF = if passed > 0 then 720.0 else 24.0  // Simplified
            MTTR = 15.0  // Simplified
            Availability = float passed / float (max total 1)
            ErrorRate = float (total - passed) / float (max total 1) * 1000.0

            P50Latency = if latencies.Length > 0 then Statistics.Percentile(latencies, 50) else 0.0
            P95Latency = if latencies.Length > 0 then Statistics.Percentile(latencies, 95) else 0.0
            P99Latency = if latencies.Length > 0 then Statistics.Percentile(latencies, 99) else 0.0
            Throughput = float total / (results |> List.sumBy (fun r -> r.Duration.TotalSeconds) |> max 1.0)

            DefectDensity = 0.5  // Simplified
            TestCoverage = float passed / float (max total 1)
            TechnicalDebt = 50.0  // Simplified

            DimensionalCoverage = dimCoverage
            CriticalityCoverage = critCoverage
            EnvelopeCoverage = calculateEnvelopeCoverage dimCoverage defaultDimensionWeights
        }

    let execute (mode: ExecutionMode) (cortex: CortexState) : Async<ExecutionResult> = async {
        let sw = Stopwatch.StartNew()

        // Filter tests based on mode
        let testsToRun =
            match mode with
            | Dimensional dim ->
                allTests |> List.filter (fun t -> t.Dimension = dim)
            | MultiDimensional dims ->
                allTests |> List.filter (fun t -> dims |> List.contains t.Dimension)
            | FullEnvelope ->
                allTests

        // Execute tests (respecting dependencies)
        let completedIds = ConcurrentDictionary<string, bool>()
        let results = ConcurrentBag<TestResult>()

        // Simple sequential execution respecting dependencies
        let rec executeWithDeps (tests: FractalTestCase list) = async {
            for test in tests do
                let depsReady = test.Dependencies |> List.forall (fun d -> completedIds.ContainsKey(d))
                if depsReady then
                    let! result = test.Execute()
                    results.Add(result)
                    completedIds.TryAdd(test.Id, result.Passed) |> ignore
        }

        // Execute by criticality order (C1 first, then C2, etc.)
        let sortedTests =
            testsToRun
            |> List.sortBy (fun t ->
                match t.Criticality with
                | C1_Critical -> 1
                | C2_High -> 2
                | C3_Medium -> 3
                | C4_Low -> 4
                | C5_Negligible -> 5)

        do! executeWithDeps sortedTests

        sw.Stop()

        let resultList = results |> Seq.toList
        let kpis = calculateKPIs resultList

        // Update cortex with observation
        let observation = observe cortex (resultList |> List.head) kpis
        let updatedCortex =
            { cortex with Observations = observation :: cortex.Observations }
            |> evolve

        return {
            Mode = mode
            Results = resultList
            KPIs = kpis
            CortexState = updatedCortex
            Duration = sw.Elapsed
            Timestamp = DateTime.UtcNow
        }
    }

// =============================================================================
// REPORT GENERATOR
// =============================================================================

module ReportGenerator =
    open MathKPI
    open FractalTests
    open FractalExecutor

    let generateReport (result: ExecutionResult) : string =
        let sb = StringBuilder()

        sb.AppendLine("# Fractal Runtime Validation Report") |> ignore
        sb.AppendLine(sprintf "**Generated**: %s UTC" (result.Timestamp.ToString("yyyy-MM-dd HH:mm:ss"))) |> ignore
        sb.AppendLine(sprintf "**Duration**: %.2fs" result.Duration.TotalSeconds) |> ignore
        sb.AppendLine(sprintf "**Mode**: %A" result.Mode) |> ignore
        sb.AppendLine() |> ignore

        // Summary
        let passed = result.Results |> List.filter (fun r -> r.Passed) |> List.length
        let total = result.Results.Length
        sb.AppendLine("## Summary") |> ignore
        sb.AppendLine($"- **Total Tests**: {total}") |> ignore
        sb.AppendLine(sprintf "- **Passed**: %d (%.1f%%)" passed (float passed / float total * 100.0)) |> ignore
        sb.AppendLine(sprintf "- **Failed**: %d" (total - passed)) |> ignore
        sb.AppendLine() |> ignore

        // KPIs
        sb.AppendLine("## Mathematical KPIs") |> ignore
        sb.AppendLine("| Metric | Value | Target |") |> ignore
        sb.AppendLine("|--------|-------|--------|") |> ignore
        sb.AppendLine(sprintf "| Availability | %.2f%% | 99.9%% |" (result.KPIs.Availability * 100.0)) |> ignore
        sb.AppendLine(sprintf "| P50 Latency | %.1fms | <50ms |" result.KPIs.P50Latency) |> ignore
        sb.AppendLine(sprintf "| P95 Latency | %.1fms | <100ms |" result.KPIs.P95Latency) |> ignore
        sb.AppendLine(sprintf "| P99 Latency | %.1fms | <200ms |" result.KPIs.P99Latency) |> ignore
        sb.AppendLine(sprintf "| Error Rate | %.2f/1000 | <1/1000 |" result.KPIs.ErrorRate) |> ignore
        sb.AppendLine(sprintf "| Envelope Coverage | %.1f%% | >80%% |" (result.KPIs.EnvelopeCoverage * 100.0)) |> ignore
        sb.AppendLine() |> ignore

        // Dimensional Coverage
        sb.AppendLine("## Dimensional Coverage") |> ignore
        sb.AppendLine("| Dimension | Coverage |") |> ignore
        sb.AppendLine("|-----------|----------|") |> ignore
        for KeyValue(dim, cov) in result.KPIs.DimensionalCoverage do
            sb.AppendLine(sprintf "| %A | %.1f%% |" dim (cov * 100.0)) |> ignore
        sb.AppendLine() |> ignore

        // Criticality Coverage
        sb.AppendLine("## Criticality Coverage") |> ignore
        sb.AppendLine("| Level | Coverage |") |> ignore
        sb.AppendLine("|-------|----------|") |> ignore
        for KeyValue(crit, cov) in result.KPIs.CriticalityCoverage do
            sb.AppendLine(sprintf "| %A | %.1f%% |" crit (cov * 100.0)) |> ignore
        sb.AppendLine() |> ignore

        // Cortex Evolution
        sb.AppendLine("## Cortex Evolution") |> ignore
        sb.AppendLine(sprintf "- **Generation**: %d" result.CortexState.Generation) |> ignore
        sb.AppendLine(sprintf "- **Current Fitness**: %.1f%%" (result.CortexState.CurrentFitness * 100.0)) |> ignore
        sb.AppendLine(sprintf "- **Target Fitness**: %.1f%%" (result.CortexState.TargetFitness * 100.0)) |> ignore
        sb.AppendLine(sprintf "- **Learning Rate**: %.3f" result.CortexState.LearningRate) |> ignore
        sb.AppendLine() |> ignore

        // Recommendations
        if result.CortexState.Observations.Length > 0 then
            let latest = result.CortexState.Observations |> List.head
            if latest.Recommendations.Length > 0 then
                sb.AppendLine("## Recommendations") |> ignore
                for recommendation in latest.Recommendations do
                    sb.AppendLine($"- {recommendation}") |> ignore
                sb.AppendLine() |> ignore

            if latest.Anomalies.Length > 0 then
                sb.AppendLine("## Anomalies Detected") |> ignore
                for anomaly in latest.Anomalies do
                    sb.AppendLine($"- ⚠️ {anomaly}") |> ignore
                sb.AppendLine() |> ignore

        sb.ToString()

    let saveReport (result: ExecutionResult) =
        let dir = "reports"
        if not (Directory.Exists(dir)) then Directory.CreateDirectory(dir) |> ignore
        let filename = sprintf "%s/fractal_validation_%s.md" dir (DateTime.UtcNow.ToString("yyyy-MM-dd_HHmmss"))
        File.WriteAllText(filename, generateReport result)
        printfn $"📄 Report saved: {filename}"

// =============================================================================
// MAIN
// =============================================================================

open FractalExecutor
open ReportGenerator
open CortexMonitor

let printBanner () =
    printfn "╔══════════════════════════════════════════════════════════════════════════╗"
    printfn "║          FRACTAL RUNTIME VALIDATOR v1.0.0                                 ║"
    printfn "║          3-Container Architecture | Mathematical KPIs | Cortex Monitor   ║"
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"
    printfn "║  Architecture: indrajaal-db-prod | indrajaal-obs-prod | indrajaal-app-prod║"
    printfn "║  Framework: SOPv5.11 + STAMP + OODA + Fractal Testing                    ║"
    printfn "╚══════════════════════════════════════════════════════════════════════════╝"
    printfn ""

let runTests () =
    printBanner ()

    let args = fsi.CommandLineArgs |> Array.skip 1

    let mode =
        args
        |> Array.tryFindIndex (fun a -> a = "--mode")
        |> Option.bind (fun i -> args |> Array.tryItem (i + 1))
        |> Option.defaultValue "full"

    let executionMode =
        match mode.ToLower() with
        | "dimensional" ->
            let dim =
                args
                |> Array.tryFindIndex (fun a -> a = "--dimension")
                |> Option.bind (fun i -> args |> Array.tryItem (i + 1))
                |> Option.map (fun d ->
                    match d.ToLower() with
                    | "functional" -> MathKPI.Functional
                    | "performance" -> MathKPI.Performance
                    | "reliability" -> MathKPI.Reliability
                    | "security" -> MathKPI.Security
                    | "usability" -> MathKPI.Usability
                    | "observability" -> MathKPI.Observability
                    | _ -> MathKPI.Functional)
                |> Option.defaultValue MathKPI.Functional
            Dimensional dim
        | "multi" ->
            MultiDimensional [MathKPI.Reliability; MathKPI.Performance; MathKPI.Observability]
        | "full" | _ ->
            FullEnvelope

    printfn "Execution Mode: %A" executionMode
    printfn ""

    let cortex = initCortex ()
    let result = execute executionMode cortex |> Async.RunSynchronously

    // Print results
    printfn "═══════════════════════════════════════════════════════════════════════════"
    printfn "                           EXECUTION COMPLETE                               "
    printfn "═══════════════════════════════════════════════════════════════════════════"

    let passed = result.Results |> List.filter (fun r -> r.Passed) |> List.length
    let total = result.Results.Length

    printfn "  Total: %d | Passed: %d ✅ | Failed: %d ❌" total passed (total - passed)
    printfn "  Duration: %.2fs" result.Duration.TotalSeconds
    printfn "  Envelope Coverage: %.1f%%" (result.KPIs.EnvelopeCoverage * 100.0)
    printfn "  Cortex Generation: %d" result.CortexState.Generation
    printfn ""

    // Save report
    saveReport result

    if passed = total then
        printfn "🎉 ALL TESTS PASSED!"
    else
        printfn "⚠️ %d test(s) failed" (total - passed)

// Run tests
runTests ()
