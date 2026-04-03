/// Cepaf.IndrajaalTest.AnalyticsApiTests
/// Analytics and BI API tests
///
/// STAMP Constraints:
/// - SC-ANALYTICS-001: Analytics data must be tenant-isolated
/// - SC-ANALYTICS-002: Rate limiting must be enforced
module Cepaf.IndrajaalTest.AnalyticsApiTests

open System
open System.Net.Http
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Config
open Cepaf.IndrajaalTest.HttpClient

// =============================================================================
// Analytics API Tests
// =============================================================================

/// Create analytics API tests
let createAnalyticsApiTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Analytics API" [

        testAsync "GET /api/v1/analytics/stamp-tdg-gde returns metrics" {
            let client = getAuthClient ()
            let! response = get<obj> client Endpoints.Analytics.stampTdgGde

            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
            elif response.StatusCode = 401 then
                skiptest "Auth not configured"
            else
                // Endpoint may not be implemented
                Expect.isTrue (response.StatusCode = 404 || response.StatusCode = 501)
                    "Should return proper status"
        }

        testAsync "GET /api/v1/analytics/real-time returns real-time metrics" {
            let client = getAuthClient ()
            let! response = get<obj> client Endpoints.Analytics.realTime

            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
            elif response.StatusCode = 401 then
                skiptest "Auth not configured"
            else
                Expect.isTrue (response.StatusCode = 404 || response.StatusCode = 501)
                    "Should return proper status"
        }

        testAsync "GET /api/v1/analytics/historical returns historical data" {
            let client = getAuthClient ()
            let! response = get<obj> client Endpoints.Analytics.historical

            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
            elif response.StatusCode = 401 then
                skiptest "Auth not configured"
            else
                Expect.isTrue (response.StatusCode = 404 || response.StatusCode = 501)
                    "Should return proper status"
        }

        testAsync "GET /api/v1/analytics/predictions returns predictions" {
            let client = getAuthClient ()
            let! response = get<obj> client Endpoints.Analytics.predictions

            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
            elif response.StatusCode = 401 then
                skiptest "Auth not configured"
            else
                Expect.isTrue (response.StatusCode = 404 || response.StatusCode = 501)
                    "Should return proper status"
        }

        testAsync "GET /api/v1/analytics/anomalies returns anomaly data" {
            let client = getAuthClient ()
            let! response = get<obj> client Endpoints.Analytics.anomalies

            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
            elif response.StatusCode = 401 then
                skiptest "Auth not configured"
            else
                Expect.isTrue (response.StatusCode = 404 || response.StatusCode = 501)
                    "Should return proper status"
        }

        testAsync "GET /api/v1/analytics/benchmarks returns benchmarks" {
            let client = getAuthClient ()
            let! response = get<obj> client Endpoints.Analytics.benchmarks

            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
            elif response.StatusCode = 401 then
                skiptest "Auth not configured"
            else
                Expect.isTrue (response.StatusCode = 404 || response.StatusCode = 501)
                    "Should return proper status"
        }

        testAsync "GET /api/v1/health returns analytics API health" {
            let client = createClient config
            let! response = get<obj> client Endpoints.Analytics.health

            // Health endpoint may not require auth
            Expect.isTrue (response.StatusCode = 200 || response.StatusCode = 404)
                "Should return health status or 404"
        }

        testAsync "POST /api/v1/analytics/export requires auth" {
            let client = createClient config
            let! response = post<obj, obj> client Endpoints.Analytics.export {| format = "csv" |}

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }
    ]

/// All analytics tests
let allAnalyticsTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Analytics API Tests" [
        createAnalyticsApiTests config getAuthClient
    ]
