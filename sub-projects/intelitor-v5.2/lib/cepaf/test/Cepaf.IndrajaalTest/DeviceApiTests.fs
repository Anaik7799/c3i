/// Cepaf.IndrajaalTest.DeviceApiTests
/// Device management API tests
///
/// STAMP Constraints:
/// - SC-DEVICE-001: Devices must be tenant-isolated
/// - SC-DEVICE-002: Device commands must be authorized
module Cepaf.IndrajaalTest.DeviceApiTests

open System
open System.Net.Http
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Config
open Cepaf.IndrajaalTest.HttpClient

// =============================================================================
// Device API Tests
// =============================================================================

/// Create device API tests
let createDeviceApiTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Device API" [

        testAsync "GET /api/mobile/devices requires authentication" {
            let client = createClient config
            let! response = get<obj> client Endpoints.Devices.list

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/devices returns device list" {
            let client = getAuthClient ()
            let! response = get<obj list> client Endpoints.Devices.list

            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
            elif response.StatusCode = 401 then
                skiptest "Auth not configured"
            else
                failtest (sprintf "Unexpected status: %d" response.StatusCode)
        }

        testAsync "GET /api/mobile/config/devices/types returns device types" {
            let client = getAuthClient ()
            let! response = get<obj list> client Endpoints.Devices.types

            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
            elif response.StatusCode = 401 then
                skiptest "Auth not configured"
            else
                failtest (sprintf "Unexpected status: %d" response.StatusCode)
        }

        testAsync "GET /api/mobile/config/devices/:id with invalid ID returns 404" {
            let client = getAuthClient ()
            let invalidId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Devices.get invalidId)

            if response.StatusCode <> 401 then
                Expect.equal response.StatusCode 404 "Should return 404 for invalid ID"
            else
                skiptest "Auth not configured"
        }

        testAsync "POST /api/mobile/config/devices/register requires auth" {
            let client = createClient config
            let! response = post<obj, obj> client Endpoints.Devices.register {| name = "test" |}

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/config/devices/:id/parameters requires auth" {
            let client = createClient config
            let deviceId = Guid.NewGuid().ToString()
            let! response = get<obj> client (Endpoints.Devices.parameters deviceId)

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "POST /api/mobile/config/devices/:id/firmware-update requires auth" {
            let client = createClient config
            let deviceId = Guid.NewGuid().ToString()
            let! response = postEmpty<obj> client (Endpoints.Devices.firmwareUpdate deviceId)

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }
    ]

/// All device tests
let allDeviceTests (config: ServerConfig) (getAuthClient: unit -> HttpClient) =
    testList "Device API Tests" [
        createDeviceApiTests config getAuthClient
    ]
