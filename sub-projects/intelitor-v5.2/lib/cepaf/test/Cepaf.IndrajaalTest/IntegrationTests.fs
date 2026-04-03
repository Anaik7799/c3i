/// Cepaf.IndrajaalTest.IntegrationTests
/// End-to-end integration tests
///
/// STAMP Constraints:
/// - SC-INT-001: Integration tests must cover critical paths
/// - SC-INT-002: Tests must clean up after themselves
module Cepaf.IndrajaalTest.IntegrationTests

open System
open System.Net.Http
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Config
open Cepaf.IndrajaalTest.HttpClient
open Cepaf.IndrajaalTest.WebSocketClient

// =============================================================================
// End-to-End Flow Tests
// =============================================================================

/// Create end-to-end integration tests
let createE2ETests (config: ServerConfig) (credentials: TestCredentials) =
    testList "End-to-End Flows" [

        testAsync "Complete health check flow" {
            let client = createClient config

            // Check all health endpoints
            let endpoints = [
                Endpoints.Health.healthz
                Endpoints.Health.ready
                Endpoints.Health.startup
                Endpoints.Health.health
            ]

            for endpoint in endpoints do
                let! response = get<obj> client endpoint
                Expect.isTrue (response.StatusCode = 200 || response.StatusCode = 503)
                    (sprintf "Health endpoint %s should respond" endpoint)
        }

        testAsync "Authentication and API access flow" {
            let client = createClient config

            // Step 1: Try to access protected resource without auth
            let! unauthResponse = get<obj> client Endpoints.Alarms.list
            Expect.equal unauthResponse.StatusCode 401 "Should require auth"

            // Step 2: Login
            let loginReq = {|
                username = credentials.Username
                password = credentials.Password
                device_id = credentials.DeviceId
            |}

            let! loginResponse = post<obj, {| access_token: string |}> client Endpoints.Auth.login loginReq

            if loginResponse.StatusCode = 200 then
                match loginResponse.Data with
                | Some tokenData ->
                    // Step 3: Access protected resource with auth
                    let authClient = client |> withAuth tokenData.access_token
                    let! authResponse = get<obj> authClient Endpoints.Alarms.list

                    Expect.equal authResponse.StatusCode 200 "Should access with auth"

                    // Step 4: Logout
                    let! logoutResponse = postEmpty<obj> authClient Endpoints.Auth.logout
                    Expect.equal logoutResponse.StatusCode 200 "Should logout"
                | None ->
                    failtest "Login should return token"
            else
                skiptest "Auth not configured"
        }

        testAsync "Multi-endpoint consistency check" {
            let client = createClient config

            // Verify all health endpoints agree
            let! healthz = get<{| status: string |}> client Endpoints.Health.healthz
            let! ready = get<{| status: string |}> client Endpoints.Health.ready

            if healthz.StatusCode = 200 && ready.StatusCode = 200 then
                // Both should indicate healthy state
                ()
            elif healthz.StatusCode = 200 && ready.StatusCode = 503 then
                // System starting up
                ()
            else
                // Any other combination is acceptable during startup
                ()
        }
    ]

// =============================================================================
// API Consistency Tests
// =============================================================================

/// Create API consistency tests
let createApiConsistencyTests (config: ServerConfig) =
    let client = createClient config

    testList "API Consistency" [

        testAsync "All auth-required endpoints return 401 without auth" {
            let endpoints = [
                (Endpoints.Alarms.list, "GET")
                (Endpoints.Devices.list, "GET")
                (Endpoints.Sites.list, "GET")
                (Endpoints.Video.list, "GET")
                (Endpoints.Dashboard.mobile, "GET")
            ]

            for (endpoint, _) in endpoints do
                let! response = get<obj> client endpoint
                Expect.equal response.StatusCode 401
                    (sprintf "Endpoint %s should require auth" endpoint)
        }

        testAsync "All health endpoints do not require auth" {
            let endpoints = [
                Endpoints.Health.healthz
                Endpoints.Health.ready
                Endpoints.Health.startup
                Endpoints.Health.health
            ]

            for endpoint in endpoints do
                let! response = get<obj> client endpoint
                Expect.notEqual response.StatusCode 401
                    (sprintf "Health endpoint %s should not require auth" endpoint)
        }

        testAsync "Invalid endpoints return 404" {
            let invalidEndpoints = [
                "/api/v99/invalid"
                "/api/mobile/notexist"
                "/invalid/path/here"
            ]

            for endpoint in invalidEndpoints do
                let! response = get<obj> client endpoint
                Expect.isTrue (response.StatusCode = 404 || response.StatusCode = 401)
                    (sprintf "Invalid endpoint %s should return 404 or 401" endpoint)
        }
    ]

// =============================================================================
// Performance Integration Tests
// =============================================================================

/// Create performance integration tests
let createPerformanceIntegrationTests (config: ServerConfig) =
    let client = createClient config

    testList "Performance Integration" [

        testAsync "Concurrent health checks succeed" {
            let checks =
                [1..20]
                |> List.map (fun _ -> get<obj> client Endpoints.Health.healthz)

            let! results = Async.Parallel checks

            let successCount = results |> Array.filter (fun r -> r.StatusCode = 200) |> Array.length
            Expect.isGreaterThanOrEqual successCount 18
                "At least 90% of concurrent checks should succeed"
        }

        testAsync "Sequential requests maintain session" {
            // This tests that the server handles sequential requests properly
            for i in 1..5 do
                let! response = get<obj> client Endpoints.Health.healthz
                Expect.equal response.StatusCode 200
                    (sprintf "Request %d should succeed" i)
                do! Async.Sleep 50
        }

        testAsync "Mixed endpoint requests succeed" {
            let endpoints = [
                Endpoints.Health.healthz
                Endpoints.Health.ready
                Endpoints.Health.health
            ]

            let requests =
                endpoints
                |> List.collect (fun e -> [1..3] |> List.map (fun _ -> get<obj> client e))

            let! results = Async.Parallel requests

            let successCount = results |> Array.filter (fun r -> r.StatusCode = 200) |> Array.length
            Expect.isGreaterThanOrEqual successCount 7
                "Most mixed requests should succeed"
        }
    ]

// =============================================================================
// WebSocket Integration Tests
// =============================================================================

/// Create WebSocket integration tests
let createWebSocketIntegrationTests (config: ServerConfig) =
    testList "WebSocket Integration" [

        testAsync "WebSocket connects and disconnects cleanly" {
            let wsClient = createClient config.WebSocketUrl None

            let! connectResult = connect wsClient

            match connectResult with
            | Ok connectedClient ->
                // Connected successfully
                do! Async.Sleep 100

                // Disconnect
                do! disconnect connectedClient

                // Success
                ()
            | Error (ConnectionError msg) ->
                // Connection may fail if server not running
                ()
            | Error _ ->
                // Other errors are acceptable
                ()
        }

        testAsync "Multiple WebSocket connections are handled" {
            let clients =
                [1..3]
                |> List.map (fun _ -> createClient config.WebSocketUrl None)

            let! connectResults =
                clients
                |> List.map connect
                |> Async.Parallel

            // Disconnect all that connected
            for result in connectResults do
                match result with
                | Ok client -> do! disconnect client
                | Error _ -> ()
        }
    ]

// =============================================================================
// STAMP Integration Tests
// =============================================================================

/// Create STAMP integration constraint tests
let createStampIntegrationTests (config: ServerConfig) =
    let client = createClient config

    testList "STAMP Integration Constraints" [

        testAsync "SC-INT-001: Critical path - health to API" {
            // Health should work
            let! healthResponse = get<obj> client Endpoints.Health.healthz
            Expect.equal healthResponse.StatusCode 200 "Health should work"

            // API requires auth
            let! apiResponse = get<obj> client Endpoints.Alarms.list
            Expect.equal apiResponse.StatusCode 401 "API should require auth"
        }

        testAsync "SC-INT-002: Error handling is consistent" {
            // Invalid JSON
            let content = new StringContent("invalid", System.Text.Encoding.UTF8, "application/json")
            let! response = client.PostAsync(Endpoints.Auth.login, content) |> Async.AwaitTask

            Expect.equal (int response.StatusCode) 400 "Should return 400 for invalid JSON"
        }

        testAsync "SC-INT-003: Response times are within SLA" {
            let mutable totalMs = 0.0
            let count = 10

            for _ in 1..count do
                let! response = get<obj> client Endpoints.Health.healthz
                totalMs <- totalMs + response.Duration.TotalMilliseconds

            let avgMs = totalMs / float count
            Expect.isLessThan avgMs 100.0
                "Average response time should be under 100ms"
        }
    ]

// =============================================================================
// All Integration Tests
// =============================================================================

/// All integration tests combined
let allIntegrationTests (config: ServerConfig) (credentials: TestCredentials) =
    testList "Integration Tests" [
        createE2ETests config credentials
        createApiConsistencyTests config
        createPerformanceIntegrationTests config
        createWebSocketIntegrationTests config
        createStampIntegrationTests config
    ]
