#!/usr/bin/env -S dotnet fsi
// sa-down.fsx - Biomorphic SIL-6 Mesh Shutdown (UNIFIED)
// Version: 3.1.0
// Compliance: SC-METRICS-003 (Mandatory Parallelization)
// ELIXIR_ERL_OPTIONS: "+S 16:16 +SDio 16" for 16 schedulers, 16 dirty I/O schedulers

open System.Diagnostics

let cliArgs = fsi.CommandLineArgs |> Array.skip 1
let isDev = cliArgs |> Array.contains "--dev"
let isCluster = cliArgs |> Array.contains "--cluster"

let composeFile =
    if isDev then "podman-compose-dev.yml"
    elif isCluster then "podman-compose-cluster.yml"
    else "podman-compose-fractal-mesh.yml"

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

printfn ">>> [SA-DOWN] INITIATING SHUTDOWN (%s)..." composeFile

// 1. Drain Traffic
printfn ">>> [SA-DOWN] DRAINING CONTROL PLANE..."

// 2. Stop Containers
let exitCode = exec "podman-compose" ("-f " + composeFile + " down")

if exitCode = 0 then
    printfn ">>> [SA-DOWN] SYSTEM STOPPED GRACEFULLY."
else
    printfn ">>> [SA-DOWN] SHUTDOWN ERROR: %d" exitCode

System.Environment.Exit(exitCode)
