/// Cepaf.IndrajaalTest.ConfigApiTests
/// Configuration API tests for all domains
///
/// STAMP Constraints:
/// - SC-CONFIG-001: Configuration changes must be authorized
/// - SC-CONFIG-002: Configuration must be tenant-isolated
module Cepaf.IndrajaalTest.ConfigApiTests

open System
open System.Net.Http
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Config
open Cepaf.IndrajaalTest.HttpClient

// =============================================================================
// Configuration Domain Endpoints
// =============================================================================

let configDomains = [
    ("/api/mobile/config/access_control", "Access Control")
    ("/api/mobile/config/visitor_management", "Visitor Management")
    ("/api/mobile/config/guard_tours", "Guard Tours")
    ("/api/mobile/config/maintenance", "Maintenance")
    ("/api/mobile/config/shifts", "Shifts")
    ("/api/mobile/config/analytics", "Analytics")
    ("/api/mobile/config/intelligence", "Intelligence")
    ("/api/mobile/config/integration", "Integration")
    ("/api/mobile/config/communication", "Communication")
    ("/api/mobile/config/fleet", "Fleet")
    ("/api/mobile/config/environmental", "Environmental")
    ("/api/mobile/config/compliance", "Compliance")
    ("/api/mobile/config/training", "Training")
    ("/api/mobile/config/accounts", "Accounts")
]

// =============================================================================
// Config API Tests
// =============================================================================

/// Create config API tests for a domain
let createDomainConfigTests (config: ServerConfig) (endpoint: string, domainName: string) =
    testList (sprintf "%s Config" domainName) [

        testAsync (sprintf "GET %s requires authentication" endpoint) {
            let client = createClient config
            let! response = get<obj> client endpoint

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync (sprintf "POST %s requires authentication" endpoint) {
            let client = createClient config
            let! response = post<obj, obj> client endpoint {| name = "test" |}

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync (sprintf "POST %s/bulk requires authentication" endpoint) {
            let client = createClient config
            let bulkEndpoint = endpoint + "/bulk"
            let! response = post<obj list, obj> client bulkEndpoint [{| name = "test" |}]

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }
    ]

/// Create all config domain tests
let createAllConfigTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Configuration API" [
        for domain in configDomains do
            yield createDomainConfigTests config domain
    ]

/// STAMP constraint tests for config
let createStampConfigTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "STAMP Config Constraints" [

        testAsync "SC-CONFIG-001: All config endpoints require auth" {
            let client = createClient config

            for (endpoint, _) in configDomains do
                let! response = get<obj> client endpoint
                Expect.equal response.StatusCode 401
                    (sprintf "Endpoint %s should require auth" endpoint)
        }
    ]

/// All config tests
let allConfigTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Config API Tests" [
        createAllConfigTests config getAuthClient
        createStampConfigTests config getAuthClient
    ]
