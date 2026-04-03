/// Cepaf.IndrajaalTest.VideoApiTests
/// Video management API tests
///
/// STAMP Constraints:
/// - SC-VIDEO-001: Video streams must be tenant-isolated
/// - SC-VIDEO-002: Privacy masks must be enforced
module Cepaf.IndrajaalTest.VideoApiTests

open System
open System.Net.Http
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Config
open Cepaf.IndrajaalTest.HttpClient

// =============================================================================
// Video API Tests
// =============================================================================

/// Create video API tests
let createVideoApiTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Video API" [

        testAsync "GET /api/mobile/config/video requires authentication" {
            let client = createClient config
            let! response = get<obj> client Endpoints.Video.list

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/config/video/streams requires auth" {
            let client = createClient config
            let! response = get<obj> client Endpoints.Video.streams

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/config/video/analytics requires auth" {
            let client = createClient config
            let! response = get<obj> client Endpoints.Video.analytics

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/config/video/recording-policies requires auth" {
            let client = createClient config
            let! response = get<obj> client Endpoints.Video.recordingPolicies

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/config/video/retention-policies requires auth" {
            let client = createClient config
            let! response = get<obj> client Endpoints.Video.retentionPolicies

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/config/video returns video list with auth" {
            let client = getAuthClient ()
            let! response = get<obj list> client Endpoints.Video.list

            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
            elif response.StatusCode = 401 then
                skiptest "Auth not configured"
            else
                failtest (sprintf "Unexpected status: %d" response.StatusCode)
        }
    ]

/// All video tests
let allVideoTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Video API Tests" [
        createVideoApiTests config getAuthClient
    ]
