/// Cepaf.IndrajaalTest.Program
/// Main entry point for Indrajaal External Interface Test Suite
///
/// STAMP Constraints:
/// - SC-TEST-001: All tests must be executed
/// - SC-TEST-002: Results must be reported
module Cepaf.IndrajaalTest.Program

open System
open System.Net.Http
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Config
open Cepaf.IndrajaalTest.HttpClient
open Cepaf.IndrajaalTest.TestReporter
open Cepaf.IndrajaalTest.HealthTests
open Cepaf.IndrajaalTest.AuthTests
open Cepaf.IndrajaalTest.AlarmApiTests
open Cepaf.IndrajaalTest.DeviceApiTests
open Cepaf.IndrajaalTest.SiteApiTests
open Cepaf.IndrajaalTest.VideoApiTests
open Cepaf.IndrajaalTest.ConfigApiTests
open Cepaf.IndrajaalTest.BatchApiTests
open Cepaf.IndrajaalTest.AnalyticsApiTests
open Cepaf.IndrajaalTest.WebSocketTests
open Cepaf.IndrajaalTest.ChannelTests
open Cepaf.IndrajaalTest.LiveViewTests
open Cepaf.IndrajaalTest.IntegrationTests

// =============================================================================
// Test Configuration
// =============================================================================

/// Mutable token storage for authenticated tests
let mutable currentToken: string option = None

/// Get authenticated HTTP client
let getAuthClient (config: ServerConfig) () : HttpClient =
    let client = createClient config
    match currentToken with
    | Some token -> client |> withAuth token
    | None -> client

/// Get current token
let getToken () = currentToken

/// Attempt to login and store token
let tryLogin (config: ServerConfig) (credentials: TestCredentials) =
    async {
        let client = createClient config
        let loginReq = {|
            username = credentials.Username
            password = credentials.Password
            device_id = credentials.DeviceId
        |}

        let! response = post<obj, {| access_token: string; refresh_token: string |}> client Endpoints.Auth.login loginReq

        if response.StatusCode = 200 then
            match response.Data with
            | Some data ->
                currentToken <- Some data.access_token
                printfn "Successfully authenticated as %s" credentials.Username
                return true
            | None ->
                printfn "Login succeeded but no token returned"
                return false
        else
            printfn "Authentication failed (status %d) - some tests will be skipped" response.StatusCode
            return false
    }

// =============================================================================
// Test Suite Assembly
// =============================================================================

/// Create all test suites
let createAllTests (config: ServerConfig) (credentials: TestCredentials) =
    let authClient = getAuthClient config

    testList "Indrajaal External Interface Tests" [
        // Health & Connectivity
        allHealthTests config

        // Authentication
        allAuthTests config credentials

        // REST APIs
        allAlarmTests config authClient
        allDeviceTests config authClient
        allSiteTests config authClient
        allVideoTests config authClient
        allConfigTests config authClient
        allBatchTests config authClient
        allAnalyticsTests config authClient

        // WebSocket & Channels
        allWebSocketTests config
        allChannelTests config getToken

        // LiveView Pages
        allLiveViewTests config

        // Integration
        allIntegrationTests config credentials
    ]

// =============================================================================
// Main Entry Point
// =============================================================================

/// Print banner
let printBanner () =
    printfn ""
    printfn "============================================================"
    printfn "  CEPAF Indrajaal External Interface Test Suite"
    printfn "  Version: 1.0.0"
    printfn "  Framework: Expecto + FsCheck"
    printfn "============================================================"
    printfn ""

/// Print configuration
let printConfig (config: ServerConfig) =
    printfn "Configuration:"
    printfn "  Base URL:      %s" config.BaseUrl
    printfn "  WebSocket URL: %s" config.WebSocketUrl
    printfn "  Port:          %d" config.Port
    printfn "  SSL:           %b" config.UseSsl
    printfn "  Timeout:       %A" config.Timeout
    printfn "  Environment:   %A" config.Environment
    printfn ""

[<EntryPoint>]
let main argv =
    printBanner ()

    // Load configuration
    let config =
        if Array.contains "--dev" argv then
            printfn "Using development configuration"
            defaultDevConfig
        elif Array.contains "--staging" argv then
            printfn "Using staging configuration"
            defaultStagingConfig
        else
            printfn "Loading configuration from environment"
            fromEnvironment ()

    let credentials =
        if Array.contains "--default-creds" argv then
            defaultTestCredentials
        else
            credentialsFromEnvironment ()

    printConfig config

    // Configure logging
    let logPath =
        if Array.contains "--log" argv then
            Some "./indrajaal-test.log"
        else
            None
    configureLogger logPath

    // Attempt authentication
    printfn "Attempting authentication..."
    let authResult = tryLogin config credentials |> Async.RunSynchronously

    if not authResult then
        printfn "Warning: Running in unauthenticated mode"
        printfn "         Some tests will be skipped"
    printfn ""

    // Create test suite
    let tests = createAllTests config credentials

    // Configure Expecto
    let expectoConfig =
        { defaultConfig with
            verbosity = Logging.LogLevel.Info
            ``parallel`` = true
            parallelWorkers = 4
            stress = None
            stressTimeout = TimeSpan.FromMinutes(5.0)
            stressMemoryLimit = 0.8
            filter =
                if Array.contains "--filter" argv then
                    let idx = Array.findIndex ((=) "--filter") argv
                    if idx + 1 < argv.Length then
                        Expecto.Impl.TestFilter.ofString argv.[idx + 1]
                    else
                        Expecto.Impl.TestFilter.ofString "*"
                else
                    Expecto.Impl.TestFilter.ofString "*"
        }

    // Run tests
    printfn "Starting test execution..."
    printfn ""

    let cliArgs = [CLIArguments.Summary; CLIArguments.Printer (TestPrinters.summaryPrinter expectoConfig.printer)]
    let result = runTestsWithCLIArgs cliArgs argv tests

    // Print summary
    printfn ""
    printfn "============================================================"
    match result with
    | 0 -> printfn "  ALL TESTS PASSED"
    | _ -> printfn "  SOME TESTS FAILED (exit code: %d)" result
    printfn "============================================================"
    printfn ""

    result
