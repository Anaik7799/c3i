/// Cepaf.Podman Runtime Integration Tests
/// Tests all runtime modes against live Podman socket
module Cepaf.Podman.Tests.Program

open System
open System.Threading
open Cepaf.Podman.Domain
open Cepaf.Podman.Client
open Cepaf.Podman.Api
open Cepaf.Podman.Health
open Cepaf.Podman.Safety
open Cepaf.Podman.Compose
open Cepaf.Podman.Events

// ============================================================================
// Test Infrastructure
// ============================================================================

let containerStatusToString (status: ContainerStatus) =
    match status with
    | ContainerStatus.Created -> "created"
    | ContainerStatus.Running -> "running"
    | ContainerStatus.Paused -> "paused"
    | ContainerStatus.Restarting -> "restarting"
    | ContainerStatus.Removing -> "removing"
    | ContainerStatus.Exited code -> sprintf "exited(%d)" code
    | ContainerStatus.Dead reason -> sprintf "dead(%s)" reason
    | ContainerStatus.Unknown s -> sprintf "unknown(%s)" s

type TestResult =
    | Pass of testName: string * duration: TimeSpan
    | Fail of testName: string * error: string * duration: TimeSpan
    | Skip of testName: string * reason: string

type TestStats = {
    Passed: int
    Failed: int
    Skipped: int
    TotalDuration: TimeSpan
}

let mutable testResults: TestResult list = []

let runTest (name: string) (test: unit -> Async<Result<unit, string>>) =
    let startTime = DateTime.UtcNow
    try
        let result = test() |> Async.RunSynchronously
        let duration = DateTime.UtcNow - startTime
        match result with
        | Ok () ->
            printfn "  [PASS] %s (%.2fms)" name duration.TotalMilliseconds
            testResults <- Pass(name, duration) :: testResults
        | Error msg ->
            printfn "  [FAIL] %s: %s (%.2fms)" name msg duration.TotalMilliseconds
            testResults <- Fail(name, msg, duration) :: testResults
    with ex ->
        let duration = DateTime.UtcNow - startTime
        printfn "  [FAIL] %s: %s (%.2fms)" name ex.Message duration.TotalMilliseconds
        testResults <- Fail(name, ex.Message, duration) :: testResults

let skipTest (name: string) (reason: string) =
    printfn "  [SKIP] %s: %s" name reason
    testResults <- Skip(name, reason) :: testResults

let printSummary () =
    let stats =
        testResults |> List.fold (fun acc r ->
            match r with
            | Pass(_, d) -> { acc with Passed = acc.Passed + 1; TotalDuration = acc.TotalDuration + d }
            | Fail(_, _, d) -> { acc with Failed = acc.Failed + 1; TotalDuration = acc.TotalDuration + d }
            | Skip _ -> { acc with Skipped = acc.Skipped + 1 }
        ) { Passed = 0; Failed = 0; Skipped = 0; TotalDuration = TimeSpan.Zero }

    printfn ""
    printfn "============================================================"
    printfn "TEST SUMMARY"
    printfn "============================================================"
    printfn "  Passed:  %d" stats.Passed
    printfn "  Failed:  %d" stats.Failed
    printfn "  Skipped: %d" stats.Skipped
    printfn "  Total:   %d" (stats.Passed + stats.Failed + stats.Skipped)
    printfn "  Duration: %.2fs" stats.TotalDuration.TotalSeconds
    printfn "============================================================"

    if stats.Failed > 0 then
        printfn ""
        printfn "FAILED TESTS:"
        testResults
        |> List.rev
        |> List.iter (function
            | Fail(name, error, _) -> printfn "  - %s: %s" name error
            | _ -> ())

    stats.Failed

// ============================================================================
// Test Suite 1: Client Connection
// ============================================================================

let testClientConnection (socketPath: string) =
    printfn ""
    printfn "=== TEST SUITE: Client Connection ==="

    runTest "Create client with socket path" (fun () -> async {
        match HttpClient.createWithSocket socketPath with
        | Ok _ -> return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Ping Podman API" (fun () -> async {
        match HttpClient.createWithSocket socketPath with
        | Error e -> return Error (PodmanError.toMessage e)
        | Ok client ->
            let! result = HttpClient.ping client
            HttpClient.dispose client
            match result with
            | Ok true -> return Ok ()
            | Ok false -> return Error "Ping returned false"
            | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Get API version" (fun () -> async {
        match HttpClient.createWithSocket socketPath with
        | Error e -> return Error (PodmanError.toMessage e)
        | Ok client ->
            let! result = HttpClient.version client
            HttpClient.dispose client
            match result with
            | Ok v ->
                printfn "       Podman version: %s, API: %s" v.Version v.ApiVersion
                return Ok ()
            | Error e -> return Error (PodmanError.toMessage e)
    })

// ============================================================================
// Test Suite 2: System Info
// ============================================================================

let testSystemInfo (client: PodmanClient) =
    printfn ""
    printfn "=== TEST SUITE: System Info ==="

    runTest "Get system info" (fun () -> async {
        let! result = System.info client
        match result with
        | Ok info ->
            printfn "       Host: %s, OS: %s, Arch: %s" info.Host.Hostname info.Host.Os info.Host.Arch
            printfn "       Containers: %d, Images: %d" info.Storage.ContainerCount info.Storage.ImageCount
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Get disk usage" (fun () -> async {
        let! result = System.diskUsage client
        match result with
        | Ok usage ->
            printfn "       Containers: %d total, Images: %d total, Volumes: %d total"
                usage.Containers.Total usage.Images.Total usage.Volumes.Total
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

// ============================================================================
// Test Suite 3: Container Operations
// ============================================================================

let testContainerOperations (client: PodmanClient) =
    printfn ""
    printfn "=== TEST SUITE: Container Operations ==="

    runTest "List all containers" (fun () -> async {
        let! result = Containers.listAll client
        match result with
        | Ok containers ->
            printfn "       Found %d containers" containers.Length
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "List running containers" (fun () -> async {
        let! result = Containers.listRunning client
        match result with
        | Ok containers ->
            printfn "       Running: %d containers" containers.Length
            for c in containers do
                let name = c.Names |> List.tryHead |> Option.defaultValue "unnamed"
                printfn "         - %s (%s)" name (c.Id.Substring(0, 12))
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Inspect running container" (fun () -> async {
        let! listResult = Containers.listRunning client
        match listResult with
        | Error e -> return Error (PodmanError.toMessage e)
        | Ok [] ->
            printfn "       (no running containers to inspect)"
            return Ok ()
        | Ok (c :: _) ->
            let! inspectResult = Containers.inspect client c.Id
            match inspectResult with
            | Ok container ->
                printfn "       Name: %s, Image: %s" container.Name container.Image
                printfn "       State: %s, Created: %s"
                    (containerStatusToString container.State.Status)
                    (container.Created.ToString("yyyy-MM-dd HH:mm:ss"))
                return Ok ()
            | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Check container exists" (fun () -> async {
        let! listResult = Containers.listRunning client
        match listResult with
        | Error e -> return Error (PodmanError.toMessage e)
        | Ok [] ->
            printfn "       (no running containers)"
            return Ok ()
        | Ok (c :: _) ->
            let! existsResult = Containers.exists client c.Id
            match existsResult with
            | Ok true -> return Ok ()
            | Ok false -> return Error "Container should exist"
            | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Check container is running" (fun () -> async {
        let! listResult = Containers.listRunning client
        match listResult with
        | Error e -> return Error (PodmanError.toMessage e)
        | Ok [] ->
            printfn "       (no running containers)"
            return Ok ()
        | Ok (c :: _) ->
            let! runningResult = Containers.isRunning client c.Id
            match runningResult with
            | Ok true -> return Ok ()
            | Ok false -> return Error "Container should be running"
            | Error e -> return Error (PodmanError.toMessage e)
    })

// ============================================================================
// Test Suite 4: Image Operations
// ============================================================================

let testImageOperations (client: PodmanClient) =
    printfn ""
    printfn "=== TEST SUITE: Image Operations ==="

    runTest "List images" (fun () -> async {
        let! result = Images.list client false
        match result with
        | Ok images ->
            printfn "       Found %d images" images.Length
            for img in images |> List.take (min 3 images.Length) do
                let tag = img.RepoTags |> List.tryHead |> Option.defaultValue "<none>"
                printfn "         - %s (%.2fMB)" tag (float img.Size / 1024.0 / 1024.0)
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Check localhost images" (fun () -> async {
        let! result = Images.list client false
        match result with
        | Error e -> return Error (PodmanError.toMessage e)
        | Ok images ->
            let localhostImages =
                images
                |> List.filter (fun i ->
                    i.RepoTags |> List.exists (fun t -> t.StartsWith("localhost/")))
            printfn "       Found %d localhost/ images" localhostImages.Length
            return Ok ()
    })

    runTest "Inspect image" (fun () -> async {
        let! listResult = Images.list client false
        match listResult with
        | Error e -> return Error (PodmanError.toMessage e)
        | Ok [] ->
            printfn "       (no images to inspect)"
            return Ok ()
        | Ok (img :: _) ->
            let! inspectResult = Images.inspect client img.Id
            match inspectResult with
            | Ok imageInfo ->
                printfn "       ID: %s" (imageInfo.Id.Substring(0, min 12 imageInfo.Id.Length))
                printfn "       Arch: %s, OS: %s" imageInfo.Architecture imageInfo.Os
                return Ok ()
            | Error e -> return Error (PodmanError.toMessage e)
    })

// ============================================================================
// Test Suite 5: Network Operations
// ============================================================================

let testNetworkOperations (client: PodmanClient) =
    printfn ""
    printfn "=== TEST SUITE: Network Operations ==="

    runTest "List networks" (fun () -> async {
        let! result = Networks.list client
        match result with
        | Ok networks ->
            printfn "       Found %d networks" networks.Length
            for net in networks do
                printfn "         - %s (driver: %s)" net.Name (NetworkDriver.toString net.Driver)
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Inspect default network" (fun () -> async {
        let! result = Networks.inspect client "podman"
        match result with
        | Ok net ->
            printfn "       Name: %s, Driver: %s" net.Name (NetworkDriver.toString net.Driver)
            return Ok ()
        | Error (PodmanError.NotFound _) ->
            printfn "       (podman network not found - checking others)"
            let! listResult = Networks.list client
            match listResult with
            | Ok nets when nets.Length > 0 ->
                printfn "       Using: %s" nets.[0].Name
                return Ok ()
            | _ -> return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

// ============================================================================
// Test Suite 6: Volume Operations
// ============================================================================

let testVolumeOperations (client: PodmanClient) =
    printfn ""
    printfn "=== TEST SUITE: Volume Operations ==="

    runTest "List volumes" (fun () -> async {
        let! result = Volumes.list client
        match result with
        | Ok volumes ->
            printfn "       Found %d volumes" volumes.Length
            for vol in volumes |> List.take (min 3 volumes.Length) do
                printfn "         - %s (driver: %s)" vol.Name (VolumeDriver.toString vol.Driver)
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

// ============================================================================
// Test Suite 7: Health Probes
// ============================================================================

let testHealthProbes (client: PodmanClient) =
    printfn ""
    printfn "=== TEST SUITE: Health Probes ==="

    runTest "Check all container health" (fun () -> async {
        let! result = Probes.checkAll client
        match result with
        | Ok probes ->
            printfn "       Checked %d containers" probes.Length
            for p in probes do
                let status =
                    match p.Status with
                    | HealthStatus.Healthy -> "healthy"
                    | HealthStatus.Unhealthy n -> sprintf "unhealthy (%d)" n
                    | HealthStatus.Starting -> "starting"
                    | HealthStatus.NoHealthcheck -> "no healthcheck"
                    | HealthStatus.Unknown s -> sprintf "unknown (%s)" s
                printfn "         - %s: %s" p.ContainerName status
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Get health summary" (fun () -> async {
        let! result = Probes.getSummary client
        match result with
        | Ok summary ->
            printfn "       Total: %d, Healthy: %d, Unhealthy: %d, Starting: %d"
                summary.Total summary.Healthy summary.Unhealthy summary.Starting
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Check all healthy" (fun () -> async {
        let! result = Probes.allHealthy client
        match result with
        | Ok healthy ->
            printfn "       All healthy: %b" healthy
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Liveness probe on running container" (fun () -> async {
        let! listResult = Containers.listRunning client
        match listResult with
        | Error e -> return Error (PodmanError.toMessage e)
        | Ok [] ->
            printfn "       (no running containers)"
            return Ok ()
        | Ok (c :: _) ->
            let! livenessResult = Probes.livenessProbe client c.Id
            match livenessResult with
            | Ok alive ->
                printfn "       Container %s alive: %b" (c.Id.Substring(0, 12)) alive
                return Ok ()
            | Error e -> return Error (PodmanError.toMessage e)
    })

// ============================================================================
// Test Suite 8: Safety Constraints
// ============================================================================

let testSafetyConstraints (client: PodmanClient) =
    printfn ""
    printfn "=== TEST SUITE: Safety Constraints ==="

    runTest "Validate rootless mode" (fun () -> async {
        let! result = Constraints.validateRootless client
        match result with
        | Ok validation ->
            match validation with
            | Constraints.Valid ->
                printfn "       Rootless validation: PASS"
                return Ok ()
            | Constraints.Invalid violations ->
                printfn "       Rootless validation: %d violations" violations.Length
                return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Validate all containers" (fun () -> async {
        let! result = Constraints.validateAllContainers client
        match result with
        | Ok validation ->
            let summary = Constraints.violationSummary validation
            printfn "       %s" summary
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Validate container spec (compliant)" (fun () -> async {
        let healthConfig =
            HealthCheckConfig.create (HealthCheckTest.Cmd ["echo"; "ok"])
            |> HealthCheckConfig.withInterval (TimeSpan.FromSeconds(30.0))
            |> HealthCheckConfig.withRetries 3
        let spec =
            ContainerSpec.create "localhost/test:latest"
            |> ContainerSpec.withName "indrajaal-test"
            |> ContainerSpec.withMemoryLimit (512L * 1024L * 1024L)
            |> ContainerSpec.withHealthCheck healthConfig
            |> ContainerSpec.withRestartAlways

        let validation = Constraints.validateContainerSpec spec
        let summary = Constraints.violationSummary validation
        printfn "       %s" summary
        return Ok ()
    })

    runTest "Validate container spec (non-compliant image)" (fun () -> async {
        let spec = ContainerSpec.create "docker.io/nginx:latest"
        let validation = Constraints.validateContainerSpec spec
        match validation with
        | Constraints.Invalid violations ->
            let critical = violations |> List.filter (fun v -> v.Severity = Constraints.Critical)
            printfn "       Expected violations: %d critical" critical.Length
            if critical.Length > 0 then return Ok ()
            else return Error "Should have critical violation for non-localhost image"
        | Constraints.Valid ->
            return Error "Should have violations for docker.io image"
    })

    runTest "Validate image reference (localhost)" (fun () -> async {
        let validation = Constraints.validateImageReference "localhost/myapp:v1.0"
        match validation with
        | Constraints.Valid ->
            printfn "       localhost/myapp:v1.0 - VALID"
            return Ok ()
        | Constraints.Invalid _ -> return Error "localhost/ image should be valid"
    })

    runTest "Validate image reference (external)" (fun () -> async {
        let validation = Constraints.validateImageReference "docker.io/nginx:latest"
        match validation with
        | Constraints.Invalid violations ->
            printfn "       docker.io/nginx:latest - %d violations (expected)" violations.Length
            return Ok ()
        | Constraints.Valid -> return Error "External image should have violations"
    })

// ============================================================================
// Test Suite 9: Compose Parser
// ============================================================================

let testComposeParser () =
    printfn ""
    printfn "=== TEST SUITE: Compose Parser ==="

    runTest "Parse simple compose YAML" (fun () -> async {
        let yaml = """
version: '3.8'
services:
  app:
    image: localhost/myapp:latest
    ports:
      - "8080:80"
    restart: always
  db:
    image: localhost/postgres:15
    volumes:
      - ./data:/var/lib/postgresql/data
"""
        match Parser.parse yaml with
        | Ok compose ->
            printfn "       Version: %A" compose.Version
            printfn "       Services: %d" compose.Services.Count
            for kvp in compose.Services do
                printfn "         - %s: %s" kvp.Key (kvp.Value.Image |> Option.defaultValue "none")
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Parse compose with networks" (fun () -> async {
        let yaml = """
version: '3'
services:
  web:
    image: localhost/web:latest
networks:
  frontend:
    driver: bridge
  backend:
    internal: true
"""
        match Parser.parse yaml with
        | Ok compose ->
            printfn "       Networks: %d" compose.Networks.Count
            for kvp in compose.Networks do
                printfn "         - %s (driver: %s)" kvp.Key (kvp.Value.Driver |> Option.defaultValue "default")
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Parse compose with volumes" (fun () -> async {
        let yaml = """
version: '3'
services:
  db:
    image: localhost/db:latest
volumes:
  db-data:
    driver: local
  cache:
    external: true
"""
        match Parser.parse yaml with
        | Ok compose ->
            printfn "       Volumes: %d" compose.Volumes.Count
            for kvp in compose.Volumes do
                printfn "         - %s (external: %b)" kvp.Key kvp.Value.External
            return Ok ()
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Convert compose service to ContainerSpec" (fun () -> async {
        let yaml = """
version: '3'
services:
  myapp:
    image: localhost/myapp:v1.0
    ports:
      - "3000:3000"
    restart: unless-stopped
"""
        match Parser.parse yaml with
        | Ok compose ->
            match compose.Services.TryFind "myapp" with
            | Some service ->
                match Parser.toContainerSpec service with
                | Some spec ->
                    printfn "       Image: %s" spec.Image
                    printfn "       Name: %s" (spec.Name |> Option.defaultValue "none")
                    printfn "       Ports: %d" spec.PortMappings.Length
                    printfn "       RestartPolicy: %A" spec.RestartPolicy
                    return Ok ()
                | None -> return Error "Failed to convert service"
            | None -> return Error "Service not found"
        | Error e -> return Error (PodmanError.toMessage e)
    })

    runTest "Get deployment order (topological sort)" (fun () -> async {
        let yaml = """
version: '3'
services:
  web:
    image: localhost/web:latest
    depends_on:
      - api
      - cache
  api:
    image: localhost/api:latest
    depends_on:
      - db
  db:
    image: localhost/db:latest
  cache:
    image: localhost/cache:latest
"""
        match Parser.parse yaml with
        | Ok compose ->
            let order = Parser.getDeploymentOrder compose
            printfn "       Deployment order: %s" (String.Join(" -> ", order))
            // db and cache should come before api, api before web
            let dbIdx = order |> List.findIndex ((=) "db")
            let apiIdx = order |> List.findIndex ((=) "api")
            let webIdx = order |> List.findIndex ((=) "web")
            if dbIdx < apiIdx && apiIdx < webIdx then return Ok ()
            else return Error (sprintf "Invalid order: %A" order)
        | Error e -> return Error (PodmanError.toMessage e)
    })

// ============================================================================
// Main Entry Point
// ============================================================================

/// Test mode selection
type TestMode =
    | All       // Run all tests
    | Quick     // Run quick tests only (no stress, no lifecycle)
    | Stress    // Run only stress tests
    | Lifecycle // Run only lifecycle tests
    | Compose   // Run only compose tests

let parseTestMode (args: string array) : TestMode =
    match args |> Array.tryFind (fun a -> a.StartsWith("--mode=")) with
    | Some m ->
        match m.Substring(7).ToLower() with
        | "quick" -> Quick
        | "stress" -> Stress
        | "lifecycle" -> Lifecycle
        | "compose" -> Compose
        | _ -> All
    | None -> All

[<EntryPoint>]
let main argv =
    printfn "============================================================"
    printfn "Cepaf.Podman Comprehensive Integration Tests"
    printfn "============================================================"
    printfn "Started: %s" (DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"))

    let socketPath =
        match argv |> Array.tryFind (fun a -> not (a.StartsWith("--"))) with
        | Some path -> path
        | None -> "/run/user/1000/podman/podman.sock"

    let testMode = parseTestMode argv

    printfn "Socket: %s" socketPath
    printfn "Mode: %A" testMode
    printfn ""

    // Run test suites
    testClientConnection socketPath

    // Create client for remaining tests
    match HttpClient.createWithSocket socketPath with
    | Error e ->
        printfn "FATAL: Failed to create client: %s" (PodmanError.toMessage e)
        1
    | Ok client ->
        try
            // Track extended test results
            let mutable extendedPassed = 0
            let mutable extendedFailed = 0
            let mutable extendedSkipped = 0

            // Core tests (always run unless stress-only mode)
            if testMode <> Stress then
                testSystemInfo client
                testContainerOperations client
                testImageOperations client
                testNetworkOperations client
                testVolumeOperations client
                testHealthProbes client
                testSafetyConstraints client
                testComposeParser ()

            // Container Lifecycle Tests
            if testMode = All || testMode = Lifecycle then
                printfn ""
                printfn "Running Container Lifecycle Tests..."
                let lifecycleResults = ContainerLifecycleTests.runLifecycleTests client |> Async.RunSynchronously
                let (lp, lf, ls) = ContainerLifecycleTests.summarize lifecycleResults
                extendedPassed <- extendedPassed + lp
                extendedFailed <- extendedFailed + lf
                extendedSkipped <- extendedSkipped + ls

            // Image Build Tests
            if testMode = All || testMode = Quick then
                printfn ""
                printfn "Running Image Build Tests..."
                let imageResults = ImageBuildTests.runImageTests client |> Async.RunSynchronously
                let (ip, if', is) = ImageBuildTests.summarize imageResults
                extendedPassed <- extendedPassed + ip
                extendedFailed <- extendedFailed + if'
                extendedSkipped <- extendedSkipped + is

            // Network Tests
            if testMode = All || testMode = Quick then
                printfn ""
                printfn "Running Network Tests..."
                let networkResults = NetworkTests.runNetworkTests client |> Async.RunSynchronously
                let (np, nf, ns) = NetworkTests.summarize networkResults
                extendedPassed <- extendedPassed + np
                extendedFailed <- extendedFailed + nf
                extendedSkipped <- extendedSkipped + ns

            // Volume Tests
            if testMode = All || testMode = Quick then
                printfn ""
                printfn "Running Volume Tests..."
                let volumeResults = VolumeTests.runVolumeTests client |> Async.RunSynchronously
                let (vp, vf, vs) = VolumeTests.summarize volumeResults
                extendedPassed <- extendedPassed + vp
                extendedFailed <- extendedFailed + vf
                extendedSkipped <- extendedSkipped + vs

            // Compose Integration Tests
            if testMode = All || testMode = Compose then
                printfn ""
                printfn "Running Compose Integration Tests..."
                let composeResults = ComposeIntegrationTests.runComposeTests client |> Async.RunSynchronously
                let (cp, cf, cs) = ComposeIntegrationTests.summarize composeResults
                extendedPassed <- extendedPassed + cp
                extendedFailed <- extendedFailed + cf
                extendedSkipped <- extendedSkipped + cs

            // Stress Tests
            if testMode = All || testMode = Stress then
                printfn ""
                printfn "Running Stress Tests..."
                let stressResults = StressTests.runStressTests client |> Async.RunSynchronously
                let (sp, sf, ss) = StressTests.summarize stressResults
                extendedPassed <- extendedPassed + sp
                extendedFailed <- extendedFailed + sf
                extendedSkipped <- extendedSkipped + ss

            HttpClient.dispose client

            let coreFailCount = printSummary ()

            // Run property-based tests (always)
            let (propPassed, propFailed) = PropertyTests.runPropertyTests ()

            printfn ""
            printfn "============================================================"
            printfn "COMPREHENSIVE TEST SUMMARY"
            printfn "============================================================"
            let coreTotal = testResults.Length
            let corePassed = coreTotal - coreFailCount
            let propTotal = propPassed + propFailed

            printfn "  Core Integration:    %d passed, %d failed" corePassed coreFailCount
            printfn "  Property Tests:      %d passed, %d failed" propPassed propFailed
            printfn "  Extended Tests:      %d passed, %d failed, %d skipped" extendedPassed extendedFailed extendedSkipped
            printfn "  --------------------------------------------------------"
            let totalPassed = corePassed + propPassed + extendedPassed
            let totalFailed = coreFailCount + propFailed + extendedFailed
            let totalSkipped = extendedSkipped
            printfn "  TOTAL:               %d passed, %d failed, %d skipped" totalPassed totalFailed totalSkipped
            printfn "============================================================"
            printfn ""
            printfn "Finished: %s" (DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"))

            if totalFailed > 0 then 1 else 0
        with ex ->
            HttpClient.dispose client
            printfn "FATAL ERROR: %s" ex.Message
            printfn "%s" ex.StackTrace
            1
