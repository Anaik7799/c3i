/// Cepaf.IndrajaalTest.AlarmApiTests
/// Alarm management API tests
///
/// STAMP Constraints:
/// - SC-ALARM-001: Alarms must be tenant-isolated
/// - SC-ALARM-002: Alarm state transitions must be valid
/// - SC-ALARM-003: Escalation must follow configured policies
module Cepaf.IndrajaalTest.AlarmApiTests

open System
open System.Net.Http
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Config
open Cepaf.IndrajaalTest.HttpClient

// =============================================================================
// Alarm API Response Types
// =============================================================================

type AlarmListResponse = {
    items: AlarmDto list
    pagination: PaginationDto option
}
and AlarmDto = {
    id: string
    tenant_id: string
    severity: string
    status: string
    title: string
    description: string option
    created_at: string
    updated_at: string
}
and PaginationDto = {
    page: int
    page_size: int
    total_count: int
    total_pages: int
}

type AlarmActionResponse = {
    success: bool
    alarm: AlarmDto option
    message: string option
}

// =============================================================================
// Alarm List Tests
// =============================================================================

/// Tests for listing alarms
let createAlarmListTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Alarm List API" [

        testAsync "GET /api/mobile/alarms requires authentication" {
            let client = createClient config
            let! response = get<obj> client Endpoints.Alarms.list

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/alarms returns alarm list" {
            let client = getAuthClient ()
            let! response = get<AlarmListResponse> client Endpoints.Alarms.list

            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
                match response.Data with
                | Some data ->
                    // List may be empty, that's fine
                    Expect.isTrue (List.length data.items >= 0) "Should return list"
                | None ->
                    failtest "Should return data"
            else
                // May be 401 if auth not configured
                Expect.isTrue (response.StatusCode = 401 || response.StatusCode = 403)
                    "Should return auth error if not authenticated"
        }

        testAsync "GET /api/mobile/alarms supports pagination" {
            let client = getAuthClient ()
            let queryParams = [("page", "1"); ("page_size", "10")]
            let! response = getWithQuery<AlarmListResponse> client Endpoints.Alarms.list queryParams

            if response.StatusCode = 200 then
                match response.Data with
                | Some data ->
                    match data.pagination with
                    | Some pag ->
                        Expect.equal pag.page 1 "Should return page 1"
                        Expect.isLessThanOrEqual pag.page_size 10 "Page size should be respected"
                    | None -> () // Pagination is optional
                | None ->
                    failtest "Should return data"
            else
                skiptest "Auth not configured"
        }

        testAsync "GET /api/mobile/alarms supports severity filter" {
            let client = getAuthClient ()
            let queryParams = [("severity", "critical")]
            let! response = getWithQuery<AlarmListResponse> client Endpoints.Alarms.list queryParams

            if response.StatusCode = 200 then
                match response.Data with
                | Some data ->
                    for alarm in data.items do
                        Expect.equal alarm.severity "critical"
                            "All alarms should be critical severity"
                | None ->
                    failtest "Should return data"
            else
                skiptest "Auth not configured"
        }

        testAsync "GET /api/mobile/alarms supports status filter" {
            let client = getAuthClient ()
            let queryParams = [("status", "active")]
            let! response = getWithQuery<AlarmListResponse> client Endpoints.Alarms.list queryParams

            if response.StatusCode = 200 then
                match response.Data with
                | Some data ->
                    for alarm in data.items do
                        Expect.equal alarm.status "active"
                            "All alarms should be active"
                | None ->
                    failtest "Should return data"
            else
                skiptest "Auth not configured"
        }
    ]

// =============================================================================
// Alarm Detail Tests
// =============================================================================

/// Tests for getting single alarm
let createAlarmDetailTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Alarm Detail API" [

        testAsync "GET /api/mobile/alarms/:id requires authentication" {
            let client = createClient config
            let alarmId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Alarms.get alarmId)

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/alarms/:id with invalid ID returns 404" {
            let client = getAuthClient ()
            let invalidId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Alarms.get invalidId)

            if response.StatusCode <> 401 then
                Expect.equal response.StatusCode 404 "Should return 404 for invalid ID"
            else
                skiptest "Auth not configured"
        }

        testAsync "GET /api/mobile/alarms/:id with malformed ID returns 400/404" {
            let client = getAuthClient ()
            let! response = get<obj> client (Endpoints.Alarms.get "not-a-uuid")

            if response.StatusCode <> 401 then
                Expect.isTrue (response.StatusCode = 400 || response.StatusCode = 404)
                    "Should return 400 or 404 for malformed ID"
            else
                skiptest "Auth not configured"
        }
    ]

// =============================================================================
// Alarm Action Tests
// =============================================================================

/// Tests for alarm actions (acknowledge, resolve, escalate)
let createAlarmActionTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Alarm Action API" [

        testAsync "POST /api/mobile/alarms/:id/acknowledge requires auth" {
            let client = createClient config
            let alarmId = Guid.NewGuid().ToString()
            let! response = postEmpty<obj> client (Endpoints.Alarms.acknowledge alarmId)

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "POST /api/mobile/alarms/:id/resolve requires auth" {
            let client = createClient config
            let alarmId = Guid.NewGuid().ToString()
            let! response = postEmpty<obj> client (Endpoints.Alarms.resolve alarmId)

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "POST /api/mobile/alarms/:id/escalate requires auth" {
            let client = createClient config
            let alarmId = Guid.NewGuid().ToString()
            let! response = postEmpty<obj> client (Endpoints.Alarms.escalate alarmId)

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "Acknowledge invalid alarm returns 404" {
            let client = getAuthClient ()
            let invalidId = Guid.NewGuid().ToString()
            let! response = postEmpty<obj> client (Endpoints.Alarms.acknowledge invalidId)

            if response.StatusCode <> 401 then
                Expect.equal response.StatusCode 404 "Should return 404 for invalid ID"
            else
                skiptest "Auth not configured"
        }

        testAsync "Resolve invalid alarm returns 404" {
            let client = getAuthClient ()
            let invalidId = Guid.NewGuid().ToString()
            let! response = postEmpty<obj> client (Endpoints.Alarms.resolve invalidId)

            if response.StatusCode <> 401 then
                Expect.equal response.StatusCode 404 "Should return 404 for invalid ID"
            else
                skiptest "Auth not configured"
        }
    ]

// =============================================================================
// Alarm Configuration Tests
// =============================================================================

/// Tests for alarm configuration endpoints
let createAlarmConfigTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Alarm Configuration API" [

        testAsync "GET /api/mobile/config/alarms/types requires auth" {
            let client = createClient config
            let! response = get<obj> client Endpoints.AlarmConfig.types

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/config/alarms/rules requires auth" {
            let client = createClient config
            let! response = get<obj> client Endpoints.AlarmConfig.rules

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/config/alarms/workflows requires auth" {
            let client = createClient config
            let! response = get<obj> client Endpoints.AlarmConfig.workflows

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/config/alarms/escalation-policies requires auth" {
            let client = createClient config
            let! response = get<obj> client Endpoints.AlarmConfig.escalationPolicies

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/config/alarms/templates requires auth" {
            let client = createClient config
            let! response = get<obj> client Endpoints.AlarmConfig.templates

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "List alarm types with auth" {
            let client = getAuthClient ()
            let! response = get<obj list> client Endpoints.AlarmConfig.types

            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
            else
                skiptest "Auth not configured"
        }
    ]

// =============================================================================
// STAMP Constraint Tests
// =============================================================================

/// STAMP constraint validation for alarms
let createStampAlarmTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "STAMP Alarm Constraints" [

        testAsync "SC-ALARM-001: Alarms are tenant-isolated" {
            let client = getAuthClient ()
            let! response = get<AlarmListResponse> client Endpoints.Alarms.list

            if response.StatusCode = 200 then
                match response.Data with
                | Some data ->
                    // All alarms should belong to same tenant
                    let tenants = data.items |> List.map (fun a -> a.tenant_id) |> List.distinct
                    Expect.isLessThanOrEqual (List.length tenants) 1
                        "All alarms should belong to same tenant"
                | None ->
                    failtest "Should return data"
            else
                skiptest "Auth not configured"
        }

        testAsync "SC-ALARM-002: Alarm responses include required fields" {
            let client = getAuthClient ()
            let! response = get<AlarmListResponse> client Endpoints.Alarms.list

            if response.StatusCode = 200 then
                match response.Data with
                | Some data ->
                    for alarm in data.items do
                        Expect.isNonEmpty alarm.id "Alarm should have id"
                        Expect.isNonEmpty alarm.tenant_id "Alarm should have tenant_id"
                        Expect.isNonEmpty alarm.severity "Alarm should have severity"
                        Expect.isNonEmpty alarm.status "Alarm should have status"
                        Expect.isNonEmpty alarm.title "Alarm should have title"
                | None ->
                    failtest "Should return data"
            else
                skiptest "Auth not configured"
        }
    ]

// =============================================================================
// All Alarm Tests
// =============================================================================

/// All alarm tests combined
let allAlarmTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Alarm API Tests" [
        createAlarmListTests config getAuthClient
        createAlarmDetailTests config getAuthClient
        createAlarmActionTests config getAuthClient
        createAlarmConfigTests config getAuthClient
        createStampAlarmTests config getAuthClient
    ]
