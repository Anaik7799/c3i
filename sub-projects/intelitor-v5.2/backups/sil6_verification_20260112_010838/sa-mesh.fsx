#!/usr/bin/env -S dotnet fsi
// sa-mesh.fsx - SIL-6 Biomorphic Fractal Full Mesh Orchestrator
// Version: 1.0.0
// STAMP: SC-SIL6-001, SC-MESH-001, SC-SYNC-001
// Compliance: SC-METRICS-003 (Mandatory Parallelization)
// Purpose: Orchestrate the full 9-service SIL-6 mesh (Zenoh, CEPAF Bridge, Cortex)
//
// CONTAINERS: 14 Defined, 11+ Running
// 1. indrajaal-db-prod
// 2. indrajaal-obs-prod
// 3. zenoh-router-1
// 4. zenoh-router-2
// 5. zenoh-router-3
// 6. zenoh-router (proxy)
// 7. cepaf-bridge
// 8. indrajaal-cortex
// 9. indrajaal-ex-app-1
// 10. indrajaal-ex-app-2
// 11. indrajaal-ex-app-3
// 12. indrajaal-chaya (Digital Twin)
// 13. indrajaal-ml-runner-1 (Satellite 1)
// 14. indrajaal-ml-runner-2 (Satellite 2)
//
// ARTIFACT: lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml

open System
open System.Diagnostics
open System.Threading

// =============================================================================
// Configuration
// =============================================================================

let projectRoot = "/home/an/dev/ver/intelitor-v5.2"
let composeFile = "lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml"
let cepafBridgeDockerfile = "Dockerfile.cepaf-bridge"
let cortexDockerfile = "Dockerfile.cortex"

// Container names (in boot order)
let containers = [
    "indrajaal-db-prod"
    "indrajaal-obs-prod"
    "zenoh-router"
    "cepaf-bridge"
    "indrajaal-cortex"
    "indrajaal-ex-app-1"
    "indrajaal-ex-app-2"
    "indrajaal-ex-app-3"
    "indrajaal-chaya"
    "indrajaal-ml-runner-1"
    "indrajaal-ml-runner-2"
]

// Health endpoints
let healthEndpoints = [
    ("zenoh-router", "http://localhost:8000/@/router/local")
    ("cepaf-bridge", "http://localhost:9876/health")
    ("indrajaal-cortex", "http://localhost:9877/health")
    ("indrajaal-app-1", "http://localhost:4001/health")
    ("indrajaal-app-2", "http://localhost:4004/health")
    ("indrajaal-app-3", "http://localhost:4006/health")
    ("indrajaal-chaya", "http://localhost:4002/health")
]

// SC-METRICS-003: Mandatory parallelization environment variables
let mandatoryEnvVars = [
    ("ELIXIR_ERL_OPTIONS", "+S 16:16 +SDio 16")
    ("NO_TIMEOUT", "true")
    ("PATIENT_MODE", "enabled")
    ("INFINITE_PATIENCE", "true")
    ("MIX_OS_DEPS_COMPILE_PARTITION_COUNT", "8")
    ("SKIP_ZENOH_NIF", "0")
]

// =============================================================================
// Helpers
// =============================================================================

let injectMandatoryEnv (psi: ProcessStartInfo) =
    for (key, value) in mandatoryEnvVars do
        psi.EnvironmentVariables.[key] <- value

let exec command args =
    let psi = ProcessStartInfo(
        FileName = command,
        Arguments = args,
        UseShellExecute = false,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        WorkingDirectory = projectRoot
    )
    injectMandatoryEnv psi
    let proc = Process.Start(psi)
    proc.WaitForExit()
    (proc.ExitCode, proc.StandardOutput.ReadToEnd(), proc.StandardError.ReadToEnd())

let execQuiet command args =
    let (code, _, _) = exec command args
    code

let execWithOutput command args =
    let psi = ProcessStartInfo(
        FileName = command,
        Arguments = args,
        UseShellExecute = false,
        WorkingDirectory = projectRoot
    )
    injectMandatoryEnv psi
    let proc = Process.Start(psi)
    proc.WaitForExit()
    proc.ExitCode

let printHeader title =
    printfn ""
    printfn "================================================================================"
    printfn "   %s" title
    printfn "================================================================================"

let printPhase num title =
    printfn ""
    printfn ">>> [PHASE %d] %s..." num title

let printSuccess msg = printfn "    ✓ %s" msg
let printError msg = printfn "    ✗ %s" msg
let printInfo msg = printfn "    → %s" msg

let checkImageExists imageName =
    let (code, output, _) = exec "podman" $"image exists {imageName}"
    code = 0

let checkContainerRunning containerName =
    let (code, output, _) = exec "podman" $"ps --filter name={containerName} --format \"{{{{.Status}}}}\""
    code = 0 && output.Contains("Up")

let waitForHealthy containerName (maxWait: int) =
    let mutable healthy = false
    let mutable waited = 0
    while not healthy && waited < maxWait do
        Thread.Sleep(2000)
        waited <- waited + 2
        let (code, output, _) = exec "podman" $"inspect --format \"{{{{.State.Health.Status}}}}\" {containerName}"
        healthy <- output.Trim() = "healthy"
        if not healthy then
            printInfo $"Waiting for {containerName}... ({waited}s)"
    healthy

// =============================================================================
// Commands
// =============================================================================

let buildImages () =
    printPhase 1 "BUILDING CONTAINER IMAGES"

    // Build CEPAF Bridge
    if not (checkImageExists "localhost/cepaf-bridge:latest") then
        printInfo "Building CEPAF Bridge image..."
        let code = execWithOutput "podman" $"build -f {cepafBridgeDockerfile} -t localhost/cepaf-bridge:latest ."
        if code <> 0 then
            printError "Failed to build CEPAF Bridge image"
            1
        else
            printSuccess "CEPAF Bridge image built"
            0
    else
        printSuccess "CEPAF Bridge image already exists"
        0
    |> fun code1 ->
        // Build Cortex
        if code1 = 0 then
            if not (checkImageExists "localhost/indrajaal-cortex:latest") then
                printInfo "Building Cortex image..."
                let code = execWithOutput "podman" $"build -f {cortexDockerfile} -t localhost/indrajaal-cortex:latest ."
                if code <> 0 then
                    printError "Failed to build Cortex image"
                    1
                else
                    printSuccess "Cortex image built"
                    0
            else
                printSuccess "Cortex image already exists"
                0
        else
            code1

let startMesh () =
    printHeader "INDRAJAAL SIL-6 BIOMORPHIC FRACTAL MESH"
    printfn "   MODE: Full 14-Service HA Mesh with Cognitive Plane"
    printfn "   STAMP: SC-SIL6-001, SC-MESH-001, SC-SYNC-001"

    // Phase 1: Build images if needed
    let buildCode = buildImages ()
    if buildCode <> 0 then
        printError "Image build failed. Aborting."
        1
    else
        // Phase 2: Start compose stack
        printPhase 2 "STARTING MESH CONTAINERS"
        let code = execWithOutput "podman-compose" $"-f {composeFile} up -d"

        if code <> 0 then
            printError "Failed to start mesh containers"
            1
        else
            printSuccess "Compose stack started"

            // Phase 3: Wait for containers to be healthy
            printPhase 3 "WAITING FOR CONTAINER HEALTH"
            let mutable allHealthy = true
            for container in containers do
                let healthy = waitForHealthy container 120
                if healthy then
                    printSuccess $"{container} is healthy"
                else
                    printError $"{container} failed to become healthy"
                    allHealthy <- false

            if allHealthy then
                // Phase 4: Verify endpoints
                printPhase 4 "VERIFYING SERVICE ENDPOINTS"
                for (name, url) in healthEndpoints do
                    let (code, _, _) = exec "curl" $"-sf {url}"
                    if code = 0 then
                        printSuccess $"{name}: {url} OK"
                    else
                        printError $"{name}: {url} FAILED"

                printHeader "SIL-6 MESH READY"
                printfn ""
                printfn "   Access Points:"
                printfn "   ├─ Phoenix:       http://localhost:4000"
                printfn "   ├─ Prajna:        http://localhost:4000/prajna"
                printfn "   ├─ AI Copilot:    http://localhost:4000/prajna/copilot"
                printfn "   ├─ Grafana:       http://localhost:3000 (admin/indrajaal)"
                printfn "   ├─ Prometheus:    http://localhost:9090"
                printfn "   ├─ Zenoh REST:    http://localhost:8000"
                printfn "   ├─ CEPAF Bridge:  http://localhost:9876/health"
                printfn "   └─ Cortex:        http://localhost:9877/health"
                printfn ""
                0
            else
                printError "Some containers failed to become healthy"
                1

let stopMesh () =
    printHeader "STOPPING SIL-6 MESH"
    printPhase 1 "GRACEFUL SHUTDOWN"
    let code = execWithOutput "podman-compose" $"-f {composeFile} down"
    if code = 0 then
        printSuccess "Mesh stopped gracefully"
        0
    else
        printError "Failed to stop mesh"
        1

let statusMesh () =
    printHeader "SIL-6 MESH STATUS"

    printPhase 1 "CONTAINER STATUS"
    execWithOutput "podman-compose" $"-f {composeFile} ps" |> ignore

    printPhase 2 "HEALTH ENDPOINTS"
    for (name, url) in healthEndpoints do
        let (code, _, _) = exec "curl" $"-sf {url}"
        if code = 0 then
            printSuccess $"{name}: HEALTHY"
        else
            printError $"{name}: UNHEALTHY"

    0

let cleanMesh () =
    printHeader "CLEANING SIL-6 MESH"
    printPhase 1 "STOPPING AND REMOVING CONTAINERS + VOLUMES"
    let code = execWithOutput "podman-compose" $"-f {composeFile} down -v"
    if code = 0 then
        printSuccess "Mesh cleaned"
        0
    else
        printError "Failed to clean mesh"
        1

let logsMesh (service: string option) =
    let svc = defaultArg service "indrajaal-app-prod"
    printHeader $"STREAMING LOGS: {svc}"
    execWithOutput "podman-compose" $"-f {composeFile} logs -f {svc}"

let buildOnly () =
    printHeader "BUILDING SIL-6 MESH IMAGES"
    buildImages ()

// =============================================================================
// Main
// =============================================================================

let args = fsi.CommandLineArgs |> Array.skip 1 |> Array.toList

match args with
| [] | ["up"] ->
    let code = startMesh ()
    Environment.Exit(code)
| ["down"] ->
    let code = stopMesh ()
    Environment.Exit(code)
| ["status"] ->
    let code = statusMesh ()
    Environment.Exit(code)
| ["clean"] ->
    let code = cleanMesh ()
    Environment.Exit(code)
| ["build"] ->
    let code = buildOnly ()
    Environment.Exit(code)
| ["logs"] ->
    logsMesh None |> ignore
| ["logs"; service] ->
    logsMesh (Some service) |> ignore
| _ ->
    printfn "Usage: dotnet fsi sa-mesh.fsx [command]"
    printfn ""
    printfn "Commands:"
    printfn "  up       Start full SIL-6 mesh (default)"
    printfn "  down     Stop mesh gracefully"
    printfn "  status   Show mesh status"
    printfn "  clean    Stop mesh and remove volumes"
    printfn "  build    Build images only"
    printfn "  logs     Stream logs (default: indrajaal-app-prod)"
    printfn ""
    Environment.Exit(0)