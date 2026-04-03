/// Cepaf.IndrajaalTest.Program
/// Main entry point for Indrajaal External Interface Test Suite
///
/// STAMP Constraints:
/// - SC-TEST-001: All tests must be executed
/// - SC-TEST-002: Results must be reported
module Cepaf.IndrajaalTest.Program

open System
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Tests
open Cepaf.IndrajaalTest.ZenohClient
open Cepaf.IndrajaalTest.ZenohTests

// =============================================================================
// Banner and Output
// =============================================================================

/// Print banner
let printBanner () =
    printfn ""
    printfn "============================================================"
    printfn "  CEPAF Indrajaal External Interface Test Suite"
    printfn "  Version: 1.0.0"
    printfn "  Framework: Expecto"
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

// =============================================================================
// Main Entry Point
// =============================================================================

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

    // Load Zenoh configuration
    let zenohConfig =
        if Array.contains "--zenoh-dev" argv then
            printfn "Using default Zenoh configuration"
            defaultZenohConfig
        else
            printfn "Loading Zenoh configuration from environment"
            zenohConfigFromEnvironment ()

    printfn "Zenoh Router: %s" zenohConfig.RouterEndpoint
    printfn ""

    // Create test suites
    let httpTests = allTests config credentials
    let zenohTests = allZenohTests zenohConfig

    let allTestSuites =
        testList "Indrajaal Complete Test Suite" [
            httpTests
            zenohTests
        ]

    // Run tests
    printfn "Starting test execution..."
    printfn ""

    let result = runTestsWithCLIArgs [] argv allTestSuites

    // Print summary
    printfn ""
    printfn "============================================================"
    match result with
    | 0 -> printfn "  ALL TESTS PASSED"
    | _ -> printfn "  SOME TESTS FAILED (exit code: %d)" result
    printfn "============================================================"
    printfn ""

    result
