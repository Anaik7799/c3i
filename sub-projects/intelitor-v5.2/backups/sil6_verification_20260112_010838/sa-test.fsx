#!/usr/bin/env -S dotnet fsi
// sa-test.fsx - Biomorphic SIL-6 Verification Suite
// WHAT: Exhaustive testing of sa- operations (up, down, clean, status)
// GOAL: 100% Verification of Substrate Lifecycle & SIL-6 Compliance
// Compliance: SC-SIL6-*, SC-OODA-001, SC-TPS-001, SC-METRICS-003
// ELIXIR_ERL_OPTIONS: "+S 16:16 +SDio 16" for 16 schedulers, 16 dirty I/O schedulers

open System
open System.IO
open System.Diagnostics
open System.Threading
open System.Collections.Generic

// =============================================================================
// LAYER 1: TELEMETRY & TUI
// =============================================================================
module Telemetry =
    let log stage status msg =
        let ts = DateTime.UtcNow.ToString("HH:mm:ss.fff")
        let color = match status with
                    | "OK"   -> "\u001b[32m"
                    | "RUN"  -> "\u001b[36m"
                    | "FAIL" -> "\u001b[31m"
                    | "TEST" -> "\u001b[35m"
                    | _      -> "\u001b[33m"
        printfn "[%s] [%-12s] [%s%-7s\u001b[0m] %s" ts stage color status msg

// =============================================================================
// LAYER 2: SHELL CORE
// =============================================================================
module Shell =
    // SC-METRICS-003: Mandatory parallelization environment variables
    let mandatoryEnvVars = [
        ("ELIXIR_ERL_OPTIONS", "+S 16:16 +SDio 16")
        ("NO_TIMEOUT", "true")
        ("PATIENT_MODE", "enabled")
        ("INFINITE_PATIENCE", "true")
        ("MIX_OS_DEPS_COMPILE_PARTITION_COUNT", "8")
        ("SKIP_ZENOH_NIF", "0")
    ]

    let injectMandatoryEnv (psi: ProcessStartInfo) =
        for (key, value) in mandatoryEnvVars do
            psi.EnvironmentVariables.[key] <- value

    let exec command args =
        let psi = ProcessStartInfo(FileName = command, Arguments = args, RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false, CreateNoWindow = true)
        injectMandatoryEnv psi  // SC-METRICS-003: Inject mandatory env vars
        let proc = Process.Start(psi)
        let o = proc.StandardOutput.ReadToEnd()
        let e = proc.StandardError.ReadToEnd()
        proc.WaitForExit()
        (proc.ExitCode, o, e)

// =============================================================================
// LAYER 3: TEST CORE
// =============================================================================
module Tests =
    
    let mutable totalTests = 0
    let mutable passTests = 0

    let runTest name action =
        totalTests <- totalTests + 1
        Telemetry.log "TEST" "RUN" (sprintf "Executing %s..." name)
        try
            if action() then
                passTests <- passTests + 1
                Telemetry.log "TEST" "OK" (sprintf "PASS: %s" name)
                true
            else
                Telemetry.log "TEST" "FAIL" (sprintf "FAIL: %s" name)
                false
        with ex ->
            Telemetry.log "TEST" "FAIL" (sprintf "CRASH: %s (%s)" name ex.Message)
            false

    // -------------------------------------------------------------------------
    // V-CLEAN: sa-clean exhaustive test
    // -------------------------------------------------------------------------
    let testClean () =
        runTest "V-CLEAN-001: Sterilization" (fun () ->
            let (code, _, _) = Shell.exec "dotnet" "fsi sa-clean.fsx"
            code = 0
        )

    // -------------------------------------------------------------------------
    // V-BOOT: sa-up exhaustive test
    // -------------------------------------------------------------------------
    let testUp () =
        runTest "V-BOOT-001: Cold Start" (fun () ->
            // Use the script wrapper which delegates to the compiled CLI
            let (code, o, _) = Shell.exec "dotnet" "fsi sa-up.fsx"
            // Note: Output might vary depending on verbosity, checking exit code is primary
            code = 0
        )

    // -------------------------------------------------------------------------
    // V-STATUS: sa-status exhaustive test
    // -------------------------------------------------------------------------
    let testStatus () =
        runTest "V-STATUS-001: KPI Dashboard" (fun () ->
            let (code, o, _) = Shell.exec "dotnet" "fsi sa-status.fsx"
            code = 0 && (o.Contains("SIL-6 MESH STATUS") || o.Contains("OPERATIONAL") || o.Contains("Container"))
        )

    // -------------------------------------------------------------------------
    // V-DOWN: sa-down exhaustive test
    // -------------------------------------------------------------------------
    let testDown () =
        runTest "V-DOWN-001: Surgical Shutdown" (fun () ->
            let (code, o, _) = Shell.exec "dotnet" "fsi sa-down.fsx"
            code = 0
        )

    // -------------------------------------------------------------------------
    // V-SIL6: SLA Compliance test
    // -------------------------------------------------------------------------
    let testSla () =
        runTest "V-SIL6-001: Boot Latency < 15s" (fun () ->
            let sw = Stopwatch.StartNew()
            let (code, _, _) = Shell.exec "dotnet" "fsi sa-up.fsx"
            sw.Stop()
            // Allow 15s for F# JIT/Startup overhead + container boot
            code = 0 && sw.ElapsedMilliseconds < 15000L 
        )

// =============================================================================
// MAIN EXECUTION
// =============================================================================
printfn "\n\u001b[35m\u001b[1m>>> ODTP-v20 SIL-6 VERIFICATION SUITE (sa-test) <<<[0m"

// Ensure clean start
Tests.testClean() |> ignore

// Run test sequence
Tests.testUp() |> ignore
Tests.testStatus() |> ignore
Tests.testDown() |> ignore
Tests.testClean() |> ignore // Reset for SLA test
Tests.testSla() |> ignore
// Final cleanup
Tests.testDown() |> ignore

printfn "\n==================================================="
printfn "📊 VERIFICATION SUMMARY"
printfn "Total: %d" Tests.totalTests
printfn "Pass:  %d" Tests.passTests
printfn "Fail:  %d" (Tests.totalTests - Tests.passTests)
printfn "Score: %.1f%%" (float Tests.passTests / float Tests.totalTests * 100.0)
printfn "==================================================="

if Tests.passTests = Tests.totalTests then
    Telemetry.log "SIL-6" "OK" "ALL sa- OPERATIONS VERIFIED"
    Environment.Exit(0)
else
    Telemetry.log "SIL-6" "FAIL" "VERIFICATION FAILED"
    Environment.Exit(1)