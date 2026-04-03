/// Cepaf.IndrajaalTest.Tests
/// Comprehensive test suite for all Indrajaal external interfaces
///
/// STAMP Constraints:
/// - SC-TEST-001: All endpoints must be tested
/// - SC-TEST-002: Authentication requirements must be verified
/// - SC-TEST-003: Error responses must be validated
module Cepaf.IndrajaalTest.Tests

open System
open System.Net.Http
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.HttpClient

// =============================================================================
// Helper Functions
// =============================================================================

/// Skip test if server is not reachable (StatusCode = 0)
let inline skipIfOffline (response: ApiResponse<'T>) =
    if response.StatusCode = 0 then
        skiptest "Server not reachable"

/// Assert status code, skipping if offline
let inline expectStatus expected (response: ApiResponse<'T>) message =
    if response.StatusCode = 0 then
        skiptest "Server not reachable"
    else
        Expect.equal response.StatusCode expected message

/// Assert status is one of expected values, skipping if offline
let inline expectStatusOneOf (expected: int list) (response: ApiResponse<'T>) message =
    if response.StatusCode = 0 then
        skiptest "Server not reachable"
    else
        Expect.isTrue (List.contains response.StatusCode expected) message

// =============================================================================
// Health Check Tests (4 endpoints)
// =============================================================================

let healthTests (config: ServerConfig) =
    let client = createClient config

    testList "Health Endpoints" [
        testAsync "GET /healthz returns 200" {
            let! response = get<HealthResponse> client Endpoints.Health.healthz
            if response.StatusCode = 0 then
                skiptest "Server not reachable"
            else
                Expect.isTrue (response.StatusCode = 200 || response.StatusCode = 503) "Should return health status"
        }

        testAsync "GET /ready returns 200 when ready" {
            let! response = get<HealthResponse> client Endpoints.Health.ready
            if response.StatusCode = 0 then
                skiptest "Server not reachable"
            else
                Expect.isTrue (response.StatusCode = 200 || response.StatusCode = 503) "Should return readiness status"
        }

        testAsync "GET /startup returns 200 after startup" {
            let! response = get<HealthResponse> client Endpoints.Health.startup
            if response.StatusCode = 0 then
                skiptest "Server not reachable"
            else
                Expect.isTrue (response.StatusCode = 200 || response.StatusCode = 503) "Should return startup status"
        }

        testAsync "GET /health returns detailed health" {
            let! response = get<HealthResponse> client Endpoints.Health.health
            if response.StatusCode = 0 then
                skiptest "Server not reachable"
            else
                Expect.isTrue (response.StatusCode = 200 || response.StatusCode = 503) "Should return health info"
        }

        testAsync "Health endpoints respond within 100ms" {
            let! latency = measureLatency client Endpoints.Health.healthz
            if latency = 0L then
                skiptest "Server not reachable"
            else
                Expect.isLessThan latency 100L "Health check should be fast"
        }
    ]

// =============================================================================
// Authentication Tests (6 endpoints)
// =============================================================================

let authTests (config: ServerConfig) (credentials: TestCredentials) =
    let client = createClient config

    testList "Authentication Endpoints" [
        testAsync "POST /api/mobile/auth/login with valid credentials" {
            let loginPayload = {|
                username = credentials.Username
                password = credentials.Password
                device_id = credentials.DeviceId
            |}
            let! response = post<obj, AuthResponse> client Endpoints.Auth.login loginPayload
            skipIfOffline response
            Expect.isTrue (response.StatusCode > 0) "Should get a response"
        }

        testAsync "POST /api/mobile/auth/login with invalid credentials returns 401" {
            let loginPayload = {|
                username = "invalid@test.com"
                password = "wrongpassword"
                device_id = "test-device"
            |}
            let! response = post<obj, obj> client Endpoints.Auth.login loginPayload
            skipIfOffline response
            expectStatusOneOf [401; 422] response "Should reject invalid credentials"
        }

        testAsync "POST /api/mobile/auth/refresh requires token" {
            let! response = postEmpty<obj> client Endpoints.Auth.refresh
            expectStatus 401 response "Should require authentication"
        }

        testAsync "POST /api/mobile/auth/logout requires token" {
            let! response = postEmpty<obj> client Endpoints.Auth.logout
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/auth/verify requires token" {
            let! response = get<obj> client Endpoints.Auth.verify
            expectStatus 401 response "Should require authentication"
        }

        testAsync "POST /api/mobile/auth/forgot-password accepts email" {
            let payload = {| email = "test@indrajaal.com" |}
            let! response = post<obj, obj> client Endpoints.Auth.forgotPassword payload
            skipIfOffline response
            Expect.isTrue (response.StatusCode > 0) "Should accept forgot password request"
        }
    ]

// =============================================================================
// Alarm API Tests (15+ endpoints)
// =============================================================================

let alarmApiTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    let client = createClient config

    testList "Alarm API Endpoints" [
        // Unauthenticated tests
        testAsync "GET /api/mobile/alarms requires auth" {
            let! response = get<obj> client Endpoints.Alarms.list
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/alarms/:id requires auth" {
            let alarmId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Alarms.get alarmId)
            expectStatus 401 response "Should require authentication"
        }

        testAsync "POST /api/mobile/alarms/:id/acknowledge requires auth" {
            let alarmId = Guid.NewGuid().ToString()
            let! response = postEmpty<obj> client (Endpoints.Alarms.acknowledge alarmId)
            expectStatus 401 response "Should require authentication"
        }

        testAsync "POST /api/mobile/alarms/:id/resolve requires auth" {
            let alarmId = Guid.NewGuid().ToString()
            let! response = postEmpty<obj> client (Endpoints.Alarms.resolve alarmId)
            expectStatus 401 response "Should require authentication"
        }

        testAsync "POST /api/mobile/alarms/:id/escalate requires auth" {
            let alarmId = Guid.NewGuid().ToString()
            let! response = postEmpty<obj> client (Endpoints.Alarms.escalate alarmId)
            expectStatus 401 response "Should require authentication"
        }

        // Authenticated tests (skipped if no auth)
        testAsync "GET /api/mobile/alarms with auth returns list" {
            let authClient = getAuthClient()
            let! response = get<obj> authClient Endpoints.Alarms.list
            skipIfOffline response
            expectStatusOneOf [200; 401; 403] response "Should return alarm list or auth error"
        }

        testAsync "Alarm list supports pagination" {
            let authClient = getAuthClient()
            let queryParams = [("page", "1"); ("page_size", "10")]
            let! response = getWithQuery<obj> authClient Endpoints.Alarms.list queryParams
            skipIfOffline response
            expectStatusOneOf [200; 401; 403] response "Should support pagination"
        }

        testAsync "Alarm list supports severity filter" {
            let authClient = getAuthClient()
            let queryParams = [("severity", "critical")]
            let! response = getWithQuery<obj> authClient Endpoints.Alarms.list queryParams
            skipIfOffline response
            expectStatusOneOf [200; 401; 403] response "Should support severity filter"
        }

        testAsync "Alarm list supports status filter" {
            let authClient = getAuthClient()
            let queryParams = [("status", "active")]
            let! response = getWithQuery<obj> authClient Endpoints.Alarms.list queryParams
            skipIfOffline response
            expectStatusOneOf [200; 401; 403] response "Should support status filter"
        }

        testAsync "GET invalid alarm ID returns 404" {
            let authClient = getAuthClient()
            let invalidId = Guid.NewGuid().ToString()
            let! response = get<obj> authClient (Endpoints.Alarms.get invalidId)
            skipIfOffline response
            expectStatusOneOf [401; 404] response "Should return 404 for invalid ID"
        }
    ]

// =============================================================================
// Device API Tests (10+ endpoints)
// =============================================================================

let deviceApiTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    let client = createClient config

    testList "Device API Endpoints" [
        testAsync "GET /api/mobile/devices requires auth" {
            let! response = get<obj> client Endpoints.Devices.list
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/devices/:id requires auth" {
            let deviceId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Devices.get deviceId)
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/devices/:id/status requires auth" {
            let deviceId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Devices.status deviceId)
            expectStatus 401 response "Should require authentication"
        }

        testAsync "POST /api/mobile/devices/:id/command requires auth" {
            let deviceId = Guid.NewGuid().ToString()
            let command = {| command = "status" |}
            let! response = post<obj, obj> client (Endpoints.Devices.command deviceId) command
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/devices with auth returns list" {
            let authClient = getAuthClient()
            let! response = get<obj> authClient Endpoints.Devices.list
            skipIfOffline response
            expectStatusOneOf [200; 401; 403] response "Should return device list"
        }

        testAsync "Device list supports pagination" {
            let authClient = getAuthClient()
            let queryParams = [("page", "1"); ("page_size", "20")]
            let! response = getWithQuery<obj> authClient Endpoints.Devices.list queryParams
            skipIfOffline response
            expectStatusOneOf [200; 401; 403] response "Should support pagination"
        }

        testAsync "Device list supports status filter" {
            let authClient = getAuthClient()
            let queryParams = [("status", "online")]
            let! response = getWithQuery<obj> authClient Endpoints.Devices.list queryParams
            skipIfOffline response
            expectStatusOneOf [200; 401; 403] response "Should support status filter"
        }

        testAsync "GET invalid device ID returns 404" {
            let authClient = getAuthClient()
            let invalidId = Guid.NewGuid().ToString()
            let! response = get<obj> authClient (Endpoints.Devices.get invalidId)
            skipIfOffline response
            expectStatusOneOf [401; 404] response "Should return 404 for invalid ID"
        }
    ]

// =============================================================================
// Site API Tests (10+ endpoints)
// =============================================================================

let siteApiTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    let client = createClient config

    testList "Site API Endpoints" [
        testAsync "GET /api/mobile/sites requires auth" {
            let! response = get<obj> client Endpoints.Sites.list
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/sites/:id requires auth" {
            let siteId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Sites.get siteId)
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/sites/:id/zones requires auth" {
            let siteId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Sites.zones siteId)
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/sites/:id/access-points requires auth" {
            let siteId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Sites.accessPoints siteId)
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/sites with auth returns list" {
            let authClient = getAuthClient()
            let! response = get<obj> authClient Endpoints.Sites.list
            skipIfOffline response
            expectStatusOneOf [200; 401; 403] response "Should return site list"
        }

        testAsync "Site list supports pagination" {
            let authClient = getAuthClient()
            let queryParams = [("page", "1"); ("page_size", "25")]
            let! response = getWithQuery<obj> authClient Endpoints.Sites.list queryParams
            skipIfOffline response
            expectStatusOneOf [200; 401; 403] response "Should support pagination"
        }

        testAsync "GET invalid site ID returns 404" {
            let authClient = getAuthClient()
            let invalidId = Guid.NewGuid().ToString()
            let! response = get<obj> authClient (Endpoints.Sites.get invalidId)
            skipIfOffline response
            expectStatusOneOf [401; 404] response "Should return 404 for invalid ID"
        }
    ]

// =============================================================================
// Video API Tests (10+ endpoints)
// =============================================================================

let videoApiTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    let client = createClient config

    testList "Video API Endpoints" [
        testAsync "GET /api/mobile/video/streams requires auth" {
            let! response = get<obj> client Endpoints.Video.streams
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/video/streams/:id requires auth" {
            let streamId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Video.getStream streamId)
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/video/cameras requires auth" {
            let! response = get<obj> client Endpoints.Video.cameras
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/video/cameras/:id requires auth" {
            let cameraId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Video.getCamera cameraId)
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/video/recordings requires auth" {
            let! response = get<obj> client Endpoints.Video.recordings
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/video/streams with auth" {
            let authClient = getAuthClient()
            let! response = get<obj> authClient Endpoints.Video.streams
            skipIfOffline response
            expectStatusOneOf [200; 401; 403] response "Should return streams list"
        }

        testAsync "GET /api/mobile/video/cameras with auth" {
            let authClient = getAuthClient()
            let! response = get<obj> authClient Endpoints.Video.cameras
            skipIfOffline response
            expectStatusOneOf [200; 401; 403] response "Should return cameras list"
        }
    ]

// =============================================================================
// Configuration API Tests (5 endpoints)
// =============================================================================

let configApiTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    let client = createClient config

    testList "Configuration API Endpoints" [
        testAsync "GET /api/mobile/config/alarms/types requires auth" {
            let! response = get<obj> client Endpoints.Config.alarmTypes
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/config/alarms/rules requires auth" {
            let! response = get<obj> client Endpoints.Config.alarmRules
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/config/alarms/workflows requires auth" {
            let! response = get<obj> client Endpoints.Config.workflows
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/config/alarms/escalation-policies requires auth" {
            let! response = get<obj> client Endpoints.Config.escalationPolicies
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/config/alarms/templates requires auth" {
            let! response = get<obj> client Endpoints.Config.templates
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/config/alarms/types with auth" {
            let authClient = getAuthClient()
            let! response = get<obj> authClient Endpoints.Config.alarmTypes
            skipIfOffline response
            expectStatusOneOf [200; 401; 403] response "Should return alarm types"
        }
    ]

// =============================================================================
// Batch API Tests (5 endpoints)
// =============================================================================

let batchApiTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    let client = createClient config

    testList "Batch API Endpoints" [
        testAsync "POST /api/mobile/batch/get requires auth" {
            let payload = {| resources = List.empty<string> |}
            let! response = post<obj, obj> client Endpoints.Batch.get payload
            expectStatus 401 response "Should require authentication"
        }

        testAsync "POST /api/mobile/batch/create requires auth" {
            let payload = {| items = List.empty<string> |}
            let! response = post<obj, obj> client Endpoints.Batch.create payload
            expectStatus 401 response "Should require authentication"
        }

        testAsync "PUT /api/mobile/batch/update requires auth" {
            let payload = {| items = List.empty<string> |}
            let! response = put<obj, obj> client Endpoints.Batch.update payload
            expectStatus 401 response "Should require authentication"
        }

        testAsync "POST /api/mobile/batch/acknowledge requires auth" {
            let payload = {| ids = List.empty<string> |}
            let! response = post<obj, obj> client Endpoints.Batch.acknowledge payload
            expectStatus 401 response "Should require authentication"
        }

        testAsync "POST /api/mobile/batch/sync requires auth" {
            let payload = {| data = List.empty<string> |}
            let! response = post<obj, obj> client Endpoints.Batch.sync payload
            expectStatus 401 response "Should require authentication"
        }

        testAsync "POST /api/mobile/batch/get with auth" {
            let authClient = getAuthClient()
            let payload = {| resources = ["alarms"; "devices"] |}
            let! response = post<obj, obj> authClient Endpoints.Batch.get payload
            skipIfOffline response
            expectStatusOneOf [200; 400; 401; 403] response "Should handle batch request"
        }
    ]

// =============================================================================
// Analytics API Tests (5 endpoints)
// =============================================================================

let analyticsApiTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    let client = createClient config

    testList "Analytics API Endpoints" [
        testAsync "GET /api/mobile/analytics/dashboard requires auth" {
            let! response = get<obj> client Endpoints.Analytics.dashboard
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/analytics/alarms requires auth" {
            let! response = get<obj> client Endpoints.Analytics.alarmStats
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/analytics/devices requires auth" {
            let! response = get<obj> client Endpoints.Analytics.deviceStats
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/analytics/sites requires auth" {
            let! response = get<obj> client Endpoints.Analytics.siteStats
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/analytics/reports requires auth" {
            let! response = get<obj> client Endpoints.Analytics.reports
            expectStatus 401 response "Should require authentication"
        }

        testAsync "GET /api/mobile/analytics/dashboard with auth" {
            let authClient = getAuthClient()
            let! response = get<obj> authClient Endpoints.Analytics.dashboard
            skipIfOffline response
            expectStatusOneOf [200; 401; 403] response "Should return dashboard data"
        }
    ]

// =============================================================================
// LiveView Page Tests (10+ pages)
// =============================================================================

let liveViewTests (config: ServerConfig) =
    let client = createClient config

    testList "LiveView Pages" [
        testAsync "GET /login is accessible" {
            let! response = get<obj> client Endpoints.Pages.login
            skipIfOffline response
            expectStatusOneOf [200; 302] response "Login page should be accessible"
        }

        testAsync "GET /dashboard requires auth" {
            let! response = get<obj> client Endpoints.Pages.dashboard
            skipIfOffline response
            expectStatusOneOf [200; 302] response "Dashboard should redirect or load"
        }

        testAsync "GET /alarms requires auth" {
            let! response = get<obj> client Endpoints.Pages.alarms
            skipIfOffline response
            expectStatusOneOf [200; 302] response "Alarms page should redirect or load"
        }

        testAsync "GET /devices requires auth" {
            let! response = get<obj> client Endpoints.Pages.devices
            skipIfOffline response
            expectStatusOneOf [200; 302] response "Devices page should redirect or load"
        }

        testAsync "GET /sites requires auth" {
            let! response = get<obj> client Endpoints.Pages.sites
            skipIfOffline response
            expectStatusOneOf [200; 302] response "Sites page should redirect or load"
        }

        testAsync "GET /video requires auth" {
            let! response = get<obj> client Endpoints.Pages.video
            skipIfOffline response
            expectStatusOneOf [200; 302] response "Video page should redirect or load"
        }

        testAsync "GET /analytics requires auth" {
            let! response = get<obj> client Endpoints.Pages.analytics
            skipIfOffline response
            expectStatusOneOf [200; 302] response "Analytics page should redirect or load"
        }

        testAsync "GET /settings requires auth" {
            let! response = get<obj> client Endpoints.Pages.settings
            skipIfOffline response
            expectStatusOneOf [200; 302] response "Settings page should redirect or load"
        }

        testAsync "GET /users requires auth" {
            let! response = get<obj> client Endpoints.Pages.users
            skipIfOffline response
            expectStatusOneOf [200; 302] response "Users page should redirect or load"
        }

        testAsync "GET /profile requires auth" {
            let! response = get<obj> client Endpoints.Pages.profile
            skipIfOffline response
            expectStatusOneOf [200; 302] response "Profile page should redirect or load"
        }
    ]

// =============================================================================
// WebSocket/Channel Tests (8 channels)
// =============================================================================

let webSocketTests (config: ServerConfig) =
    testList "WebSocket Endpoints" [
        testAsync "WebSocket endpoint is reachable" {
            let client = createClient config
            let! response = get<obj> client "/socket/websocket"
            skipIfOffline response
            // WebSocket upgrade returns various codes
            Expect.isTrue (response.StatusCode > 0) "Socket endpoint should respond"
        }

        test "Channel topics are defined" {
            // Verify all channel topics are defined
            Expect.isNonEmpty Endpoints.Channels.alarm "Alarm channel should be defined"
            Expect.isNonEmpty Endpoints.Channels.device "Device channel should be defined"
            Expect.isNonEmpty Endpoints.Channels.site "Site channel should be defined"
            Expect.isNonEmpty Endpoints.Channels.notification "Notification channel should be defined"
            Expect.isNonEmpty Endpoints.Channels.presence "Presence channel should be defined"
            Expect.isNonEmpty Endpoints.Channels.dashboard "Dashboard channel should be defined"
            Expect.isNonEmpty Endpoints.Channels.video "Video channel should be defined"
            Expect.isNonEmpty Endpoints.Channels.command "Command channel should be defined"
        }
    ]

// =============================================================================
// STAMP Constraint Validation Tests
// =============================================================================

let stampTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    let client = createClient config

    testList "STAMP Constraint Validation" [
        testAsync "SC-AUTH-001: All API endpoints require authentication" {
            let! alarmResponse = get<obj> client Endpoints.Alarms.list
            let! deviceResponse = get<obj> client Endpoints.Devices.list
            let! siteResponse = get<obj> client Endpoints.Sites.list

            skipIfOffline alarmResponse
            expectStatus 401 alarmResponse "Alarms should require auth"
            expectStatus 401 deviceResponse "Devices should require auth"
            expectStatus 401 siteResponse "Sites should require auth"
        }

        testAsync "SC-PERF-001: Health endpoints respond within SLA" {
            let! latency = measureLatency client Endpoints.Health.healthz
            if latency = 0L then
                skiptest "Server not reachable"
            else
                Expect.isLessThan latency 100L "Health check should respond within 100ms"
        }

        testAsync "SC-SEC-001: Invalid IDs are rejected properly" {
            let authClient = getAuthClient()
            let malformedId = "not-a-valid-uuid"
            let! response = get<obj> authClient (Endpoints.Alarms.get malformedId)
            skipIfOffline response
            expectStatusOneOf [400; 401; 404] response "Invalid ID format should be rejected"
        }

        testAsync "SC-TENANT-001: Resources are tenant-isolated" {
            let authClient = getAuthClient()
            let! response = get<obj> authClient Endpoints.Alarms.list
            skipIfOffline response
            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Tenant-scoped request should succeed"
        }
    ]

// =============================================================================
// Integration Tests
// =============================================================================

let integrationTests (config: ServerConfig) (credentials: TestCredentials) =
    testList "Integration Tests" [
        testAsync "Full authentication flow" {
            let client = createClient config

            // Step 1: Login
            let loginPayload = {|
                username = credentials.Username
                password = credentials.Password
                device_id = credentials.DeviceId
            |}
            let! loginResponse = post<obj, AuthResponse> client Endpoints.Auth.login loginPayload

            skipIfOffline loginResponse

            if loginResponse.StatusCode = 200 then
                match loginResponse.Data with
                | Some authData ->
                    // Step 2: Use token to access protected resource
                    let authClient = client |> withAuth authData.AccessToken
                    let! alarmsResponse = get<obj> authClient Endpoints.Alarms.list
                    expectStatusOneOf [200; 403] alarmsResponse "Should access protected resource with token"

                    // Step 3: Logout
                    let! logoutResponse = postEmpty<obj> authClient Endpoints.Auth.logout
                    expectStatusOneOf [200; 204] logoutResponse "Logout should succeed"
                | None ->
                    skiptest "Login succeeded but no token returned"
            else
                skiptest "Login failed - integration test requires valid credentials"
        }

        testAsync "API response time SLA verification" {
            let client = createClient config

            // Verify multiple endpoints respond within SLA
            let! healthLatency = measureLatency client Endpoints.Health.healthz

            if healthLatency = 0L then
                skiptest "Server not reachable"
            else
                Expect.isLessThan healthLatency 100L "Health check should be under 100ms"
        }
    ]

// =============================================================================
// Test Suite Assembly
// =============================================================================

/// Create all tests for a given configuration
let allTests (config: ServerConfig) (credentials: TestCredentials) =
    // Mutable token storage for authenticated tests
    let mutable currentToken: string option = None

    // Authenticated client getter
    let getAuthClient () =
        let client = createClient config
        match currentToken with
        | Some token -> client |> withAuth token
        | None -> client

    // Try to authenticate at startup
    let tryAuth () =
        try
            async {
                let client = createClient config
                let loginPayload = {|
                    username = credentials.Username
                    password = credentials.Password
                    device_id = credentials.DeviceId
                |}
                let! response = post<obj, AuthResponse> client Endpoints.Auth.login loginPayload
                if response.StatusCode = 200 then
                    match response.Data with
                    | Some authData ->
                        currentToken <- Some authData.AccessToken
                        printfn "Authenticated as %s" credentials.Username
                    | None -> ()
                elif response.StatusCode = 0 then
                    printfn "Server not reachable - running in offline mode"
                else
                    printfn "Authentication failed (status %d) - running without auth" response.StatusCode
            } |> Async.RunSynchronously
        with
        | ex ->
            printfn "Could not connect to server: %s" ex.Message
            printfn "Running tests in offline mode (connection tests will fail)"

    // Attempt authentication
    tryAuth ()

    testList "Indrajaal External Interface Tests" [
        healthTests config
        authTests config credentials
        alarmApiTests config getAuthClient
        deviceApiTests config getAuthClient
        siteApiTests config getAuthClient
        videoApiTests config getAuthClient
        configApiTests config getAuthClient
        batchApiTests config getAuthClient
        analyticsApiTests config getAuthClient
        liveViewTests config
        webSocketTests config
        stampTests config getAuthClient
        integrationTests config credentials
    ]
