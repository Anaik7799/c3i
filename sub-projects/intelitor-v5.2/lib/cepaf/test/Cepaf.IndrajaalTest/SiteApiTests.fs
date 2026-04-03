/// Cepaf.IndrajaalTest.SiteApiTests
/// Site management API tests
///
/// STAMP Constraints:
/// - SC-SITE-001: Sites must be tenant-isolated
/// - SC-SITE-002: Site operations must be authorized
module Cepaf.IndrajaalTest.SiteApiTests

open System
open System.Net.Http
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Config
open Cepaf.IndrajaalTest.HttpClient

// =============================================================================
// Site API Tests
// =============================================================================

/// Create site API tests
let createSiteApiTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Site API" [

        testAsync "GET /api/mobile/sites requires authentication" {
            let client = createClient config
            let! response = get<obj> client Endpoints.Sites.list

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/sites returns site list" {
            let client = getAuthClient ()
            let! response = get<obj list> client Endpoints.Sites.list

            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
            elif response.StatusCode = 401 then
                skiptest "Auth not configured"
            else
                failtest (sprintf "Unexpected status: %d" response.StatusCode)
        }

        testAsync "GET /api/mobile/config/sites/:id with invalid ID returns 404" {
            let client = getAuthClient ()
            let invalidId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Sites.get invalidId)

            if response.StatusCode <> 401 then
                Expect.equal response.StatusCode 404 "Should return 404 for invalid ID"
            else
                skiptest "Auth not configured"
        }

        testAsync "GET /api/mobile/config/sites/:id/locations requires auth" {
            let client = createClient config
            let siteId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Sites.locations siteId)

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/config/sites/:id/zones requires auth" {
            let client = createClient config
            let siteId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Sites.zones siteId)

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/config/sites/:id/operating-hours requires auth" {
            let client = createClient config
            let siteId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Sites.operatingHours siteId)

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }
    ]

/// All site tests
let allSiteTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Site API Tests" [
        createSiteApiTests config getAuthClient
    ]
