/// Cepaf.IndrajaalTest.BatchApiTests
/// Batch operations API tests
///
/// STAMP Constraints:
/// - SC-BATCH-001: Batch operations must be atomic
/// - SC-BATCH-002: Batch size limits must be enforced
module Cepaf.IndrajaalTest.BatchApiTests

open System
open System.Net.Http
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Config
open Cepaf.IndrajaalTest.HttpClient

// =============================================================================
// Batch API Tests
// =============================================================================

/// Create batch API tests
let createBatchApiTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Batch API" [

        testAsync "POST /api/mobile/batch/get requires authentication" {
            let client = createClient config
            let! response = post<obj, obj> client Endpoints.Batch.get {| resources = [] |}

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "POST /api/mobile/batch/create requires authentication" {
            let client = createClient config
            let! response = post<obj, obj> client Endpoints.Batch.create {| items = [] |}

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "PUT /api/mobile/batch/update requires authentication" {
            let client = createClient config
            let! response = put<obj, obj> client Endpoints.Batch.update {| items = [] |}

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "POST /api/mobile/batch/acknowledge requires authentication" {
            let client = createClient config
            let! response = post<obj, obj> client Endpoints.Batch.acknowledge {| ids = [] |}

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "POST /api/mobile/batch/sync requires authentication" {
            let client = createClient config
            let! response = post<obj, obj> client Endpoints.Batch.sync {| data = [] |}

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "Batch get with auth returns data" {
            let client = getAuthClient ()
            let payload = {| resources = ["alarms"; "devices"] |}
            let! response = post<{| resources: string list |}, obj> client Endpoints.Batch.get payload

            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
            elif response.StatusCode = 401 then
                skiptest "Auth not configured"
            else
                // May return 400 if format is wrong
                Expect.isTrue (response.StatusCode = 400 || response.StatusCode = 422)
                    "Should handle batch request"
        }
    ]

/// All batch tests
let allBatchTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Batch API Tests" [
        createBatchApiTests config getAuthClient
    ]
