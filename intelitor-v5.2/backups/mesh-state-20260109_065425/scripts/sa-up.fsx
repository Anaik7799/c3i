#!/usr/bin/env -S dotnet fsi
// sa-up.fsx - Panopticon SIL6 Mode
// Version: 6.1.0
// Compliance: SC-METRICS-003 (Mandatory Parallelization)
// ELIXIR_ERL_OPTIONS: "+S 16:16 +SDio 16" for 16 schedulers, 16 dirty I/O schedulers

open System.Diagnostics

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
    let psi = ProcessStartInfo(FileName = command, Arguments = args, UseShellExecute = false)
    injectMandatoryEnv psi  // SC-METRICS-003: Inject mandatory env vars
    let proc = Process.Start(psi)
    proc.WaitForExit()
    proc.ExitCode

printfn "================================================================================"
printfn "   INDRAJAAL PANOPTICON  ::  SIL6 DIRECTED TELESCOPE"
printfn "   MODE: fail-safe Parallel Control Plane (2oo3 Voting)"
printfn "================================================================================"

// 1. Start Substrate
printfn ">>> [PHASE 1] INITIALIZING FRACTAL MESH SUBSTRATE..."
let code = exec "podman-compose" "-f podman-compose-fractal-mesh.yml up -d"

if code = 0 then
    printfn ">>> [PHASE 2] LAUNCHING DIRECTED TELESCOPE..."
    exec "dotnet" "fsi lib/cepaf/scripts/fractal-tui.fsx" |> ignore
else
    printfn ">>> [FATAL] SUBSTRATE FAILURE. SIL6 INVARIANT VIOLATION."
    System.Environment.Exit(1)