/// Cepaf.IndrajaalTest.HealthTests
/// Kubernetes probe and health endpoint tests
///
/// STAMP Constraints:
/// - SC-HEALTH-001: Health endpoints must respond within 100ms
/// - SC-HEALTH-002: Liveness probe must always succeed if BEAM is running
module Cepaf.IndrajaalTest.HealthTests

open System
open System.Net.Http
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Config
open Cepaf.IndrajaalTest.HttpClient

// =============================================================================
// Health Check Test Helpers
// =============================================================================

/// Check that endpoint responds with success
let checkEndpointResponds (client: HttpClient) (endpoint: string) (expectedStatus: int) =
    async {
        let! response = get<HealthCheckResponse> client endpoint
        return response.StatusCode = expectedStatus && response.Success
    }

/// Check response time is within limit
let checkResponseTime (client: HttpClient) (endpoint: string) (maxMs: float) =
    async {
        let! response = get<HealthCheckResponse> client endpoint
        return response.Duration.TotalMilliseconds <= maxMs
    }

// =============================================================================
// Health Tests
// =============================================================================

/// Create health tests for a given server config
let createHealthTests (config: ServerConfig) =
    let client = createClient config

    testList "Health Endpoints" [

        testAsync "GET /healthz returns 200 (Liveness Probe)" {
            let! response = get<HealthCheckResponse> client Endpoints.Health.healthz

            Expect.equal response.StatusCode 200 "Should return 200 OK"
            Expect.isTrue response.Success "Should be successful"

            match response.Data with
            | Some data ->
                Expect.equal data.status "healthy" "Status should be healthy"
            | None ->
                failtest "Response body should not be empty"
        }

        testAsync "GET /healthz responds within 100ms (SC-HEALTH-001)" {
            let! response = get<HealthCheckResponse> client Endpoints.Health.healthz

            Expect.isLessThan response.Duration.TotalMilliseconds 100.0
                "Health check should respond within 100ms"
        }

        testAsync "GET /ready returns 200 (Readiness Probe)" {
            let! response = get<HealthCheckResponse> client Endpoints.Health.ready

            Expect.equal response.StatusCode 200 "Should return 200 OK"
            Expect.isTrue response.Success "Should be successful"

            match response.Data with
            | Some data ->
                Expect.isTrue (data.status = "ready" || data.status = "ok")
                    "Status should be ready or ok"
            | None ->
                failtest "Response body should not be empty"
        }

        testAsync "GET /startup returns 200 (Startup Probe)" {
            let! response = get<HealthCheckResponse> client Endpoints.Health.startup

            Expect.equal response.StatusCode 200 "Should return 200 OK"
            Expect.isTrue response.Success "Should be successful"

            match response.Data with
            | Some data ->
                Expect.isTrue (data.status = "started" || data.status = "ok")
                    "Status should be started or ok"
            | None ->
                failtest "Response body should not be empty"
        }

        testAsync "GET /health returns comprehensive status" {
            let! response = get<HealthCheckResponse> client Endpoints.Health.health

            Expect.equal response.StatusCode 200 "Should return 200 OK"
            Expect.isTrue response.Success "Should be successful"

            match response.Data with
            | Some data ->
                Expect.isTrue
                    (data.status = "healthy" || data.status = "ok" || data.status = "ready")
                    "Status should indicate healthy state"
            | None ->
                failtest "Response body should not be empty"
        }

        testAsync "Health endpoints include timestamp" {
            let! response = get<HealthCheckResponse> client Endpoints.Health.health

            Expect.isTrue response.Success "Should be successful"

            match response.Data with
            | Some data ->
                match data.timestamp with
                | Some ts ->
                    // Verify it's a valid timestamp
                    let parsed = DateTime.TryParse(ts) |> fst
                    Expect.isTrue parsed "Timestamp should be valid"
                | None -> () // Optional field
            | None ->
                failtest "Response body should not be empty"
        }

        testAsync "Health check includes proper headers" {
            let! response = get<HealthCheckResponse> client Endpoints.Health.healthz

            Expect.isTrue (response.Headers.ContainsKey("content-type"))
                "Should include Content-Type header"

            let contentType = response.Headers.["content-type"]
            Expect.stringContains contentType "application/json"
                "Content-Type should be JSON"
        }

        testAsync "Multiple sequential health checks succeed" {
            for _ in 1..5 do
                let! response = get<HealthCheckResponse> client Endpoints.Health.healthz
                Expect.isTrue response.Success
                    "All health checks should succeed"
        }

        testAsync "Parallel health checks succeed" {
            let checks =
                [1..10]
                |> List.map (fun _ -> get<HealthCheckResponse> client Endpoints.Health.healthz)

            let! results = Async.Parallel checks

            for response in results do
                Expect.isTrue response.Success "All parallel checks should succeed"
        }

        testAsync "Health endpoints handle rapid requests" {
            // Rapid fire 50 requests
            let checks =
                [1..50]
                |> List.map (fun _ -> get<HealthCheckResponse> client Endpoints.Health.healthz)

            let! results = Async.Parallel checks

            let successCount = results |> Array.filter (fun r -> r.Success) |> Array.length
            Expect.isGreaterThan successCount 45
                "At least 90% of rapid requests should succeed"
        }
    ]

// =============================================================================
// STAMP Constraint Tests
// =============================================================================

/// STAMP constraint validation tests
let createStampConstraintTests (config: ServerConfig) =
    let client = createClient config

    testList "STAMP Health Constraints" [

        testAsync "SC-HEALTH-001: All health endpoints respond within 100ms" {
            let endpoints = [
                Endpoints.Health.healthz
                Endpoints.Health.ready
                Endpoints.Health.startup
                Endpoints.Health.health
            ]

            for endpoint in endpoints do
                let! response = get<HealthCheckResponse> client endpoint
                Expect.isLessThan response.Duration.TotalMilliseconds 100.0
                    (sprintf "Endpoint %s should respond within 100ms" endpoint)
        }

        testAsync "SC-HEALTH-002: Liveness probe succeeds consistently" {
            // Run 10 liveness checks
            for i in 1..10 do
                let! response = get<HealthCheckResponse> client Endpoints.Health.healthz
                Expect.isTrue response.Success
                    (sprintf "Liveness check %d should succeed" i)
                do! Async.Sleep 100 // Small delay between checks
        }

        testAsync "SC-HEALTH-003: Readiness probe validates dependencies" {
            let! response = get<HealthCheckResponse> client Endpoints.Health.ready

            Expect.isTrue response.Success "Readiness should succeed"

            // If checks are included, verify structure
            match response.Data with
            | Some data ->
                match data.checks with
                | Some checks ->
                    // Verify checks is not empty if present
                    Expect.isNonEmpty (Map.toList checks)
                        "If checks are present, they should not be empty"
                | None -> () // Checks are optional
            | None -> ()
        }
    ]

// =============================================================================
// Performance Tests
// =============================================================================

/// Performance benchmark tests
let createPerformanceTests (config: ServerConfig) =
    let client = createClient config

    testList "Health Performance" [

        testAsync "Average response time under 50ms" {
            let mutable totalMs = 0.0
            let count = 20

            for _ in 1..count do
                let! response = get<HealthCheckResponse> client Endpoints.Health.healthz
                totalMs <- totalMs + response.Duration.TotalMilliseconds

            let avgMs = totalMs / float count
            Expect.isLessThan avgMs 50.0
                (sprintf "Average response time %.2fms should be under 50ms" avgMs)
        }

        testAsync "99th percentile under 100ms" {
            let checks =
                [1..100]
                |> List.map (fun _ -> get<HealthCheckResponse> client Endpoints.Health.healthz)

            let! results = Async.Parallel checks

            let times =
                results
                |> Array.map (fun r -> r.Duration.TotalMilliseconds)
                |> Array.sort

            let p99Index = int (0.99 * float times.Length)
            let p99 = times.[p99Index]

            Expect.isLessThan p99 100.0
                (sprintf "99th percentile %.2fms should be under 100ms" p99)
        }
    ]

// =============================================================================
// All Health Tests
// =============================================================================

/// All health tests combined
let allHealthTests (config: ServerConfig) =
    testList "Health Endpoint Tests" [
        createHealthTests config
        createStampConstraintTests config
        createPerformanceTests config
    ]
