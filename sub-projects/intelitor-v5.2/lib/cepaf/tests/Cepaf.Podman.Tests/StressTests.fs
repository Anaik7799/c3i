/// Cepaf.Podman Stress Tests
/// Concurrent operations, large lists, rapid polling
module Cepaf.Podman.Tests.StressTests

open System
open System.Diagnostics
open System.Threading
open Cepaf.Podman.Domain
open Cepaf.Podman.Client
open Cepaf.Podman.Api
open Cepaf.Podman.Health

// ============================================================================
// Test Configuration
// ============================================================================

/// Test container prefix
let testPrefix = "cepaf-stress-"

/// Test image
let testImage = "localhost/alpine:latest"

/// Number of concurrent operations
let defaultConcurrency = 5

/// Number of rapid iterations
let rapidIterations = 20

/// Large list size threshold
let largeListThreshold = 50

// ============================================================================
// Stress Test Result
// ============================================================================

type StressTestResult =
    | Success of testName: string * duration: TimeSpan * message: string * metrics: Map<string, float>
    | Failure of testName: string * duration: TimeSpan * error: string
    | Skipped of testName: string * reason: string

// ============================================================================
// Cleanup
// ============================================================================

/// Clean up stress test containers
let cleanupStressContainers (client: PodmanClient) : Async<int> = async {
    let! listResult = Containers.listAll client
    match listResult with
    | Error _ -> return 0
    | Ok containers ->
        let testContainers =
            containers
            |> List.filter (fun c ->
                c.Names |> List.exists (fun n -> n.StartsWith(testPrefix) || n.StartsWith("/" + testPrefix)))

        let! _ =
            testContainers
            |> List.map (fun c -> async {
                let! _ = Containers.stop client c.Id (Some 1)
                let! _ = Containers.remove client c.Id true false
                return ()
            })
            |> Async.Parallel

        return testContainers.Length
}

// ============================================================================
// Concurrent Operation Tests
// ============================================================================

/// Test: Concurrent container creation
let testConcurrentCreation (client: PodmanClient) (count: int) : Async<StressTestResult> = async {
    let start = DateTime.UtcNow
    let sw = Stopwatch.StartNew()

    let! imageExists = Images.exists client testImage
    match imageExists with
    | Error _ | Ok false ->
        return Skipped ("Concurrent creation", "Test image not available")
    | Ok true ->
        let prefix = testPrefix + "create-" + Guid.NewGuid().ToString("N").Substring(0, 8) + "-"

        let createTasks =
            [1..count]
            |> List.map (fun i -> async {
                let name = sprintf "%s%d" prefix i
                let spec =
                    ContainerSpec.create testImage
                    |> ContainerSpec.withName name
                    |> ContainerSpec.withCommand ["sleep"; "10"]

                let taskStart = sw.Elapsed.TotalMilliseconds
                let! result = Containers.create client spec
                let taskEnd = sw.Elapsed.TotalMilliseconds
                let taskDuration = taskEnd - taskStart

                match result with
                | Ok id -> return Some (id, taskDuration)
                | Error _ -> return None
            })

        let! results = Async.Parallel createTasks
        let duration = DateTime.UtcNow - start

        let successful = results |> Array.choose id
        let containerIds = successful |> Array.map fst |> Array.toList

        // Calculate metrics
        let durations = successful |> Array.map snd
        let avgDuration = if durations.Length > 0 then Array.average durations else 0.0
        let maxDuration = if durations.Length > 0 then Array.max durations else 0.0
        let minDuration = if durations.Length > 0 then Array.min durations else 0.0
        let throughput = if duration.TotalSeconds > 0.0 then float successful.Length / duration.TotalSeconds else 0.0

        // Cleanup
        for id in containerIds do
            let! _ = Containers.remove client id true false
            ()

        let metrics = Map.ofList [
            ("count", float successful.Length)
            ("avg_ms", avgDuration)
            ("max_ms", maxDuration)
            ("min_ms", minDuration)
            ("throughput_ops", throughput)
        ]

        if successful.Length = count then
            return Success (
                "Concurrent creation",
                duration,
                sprintf "Created %d containers concurrently (avg: %.1fms, throughput: %.1f/s)" count avgDuration throughput,
                metrics)
        else
            return Failure (
                "Concurrent creation",
                duration,
                sprintf "Only created %d/%d containers" successful.Length count)
}

/// Test: Concurrent container start/stop
let testConcurrentStartStop (client: PodmanClient) (count: int) : Async<StressTestResult> = async {
    let start = DateTime.UtcNow
    let sw = Stopwatch.StartNew()

    let! imageExists = Images.exists client testImage
    match imageExists with
    | Error _ | Ok false ->
        return Skipped ("Concurrent start/stop", "Test image not available")
    | Ok true ->
        let prefix = testPrefix + "startstop-" + Guid.NewGuid().ToString("N").Substring(0, 8) + "-"

        // Create containers first
        let! createResults =
            [1..count]
            |> List.map (fun i -> async {
                let name = sprintf "%s%d" prefix i
                let spec =
                    ContainerSpec.create testImage
                    |> ContainerSpec.withName name
                    |> ContainerSpec.withCommand ["sleep"; "300"]

                let! result = Containers.create client spec
                return match result with Ok id -> Some id | Error _ -> None
            })
            |> Async.Parallel

        let containerIds = createResults |> Array.choose id |> Array.toList

        if containerIds.Length < count then
            // Cleanup
            for id in containerIds do
                let! _ = Containers.remove client id true false
                ()
            return Failure ("Concurrent start/stop", DateTime.UtcNow - start, sprintf "Could only create %d containers" containerIds.Length)
        else
            // Start all concurrently
            let startStart = sw.Elapsed.TotalMilliseconds
            let! startResults =
                containerIds
                |> List.map (fun id -> Containers.start client id)
                |> Async.Parallel
            let startDuration = sw.Elapsed.TotalMilliseconds - startStart

            let startSuccessful = startResults |> Array.filter (function Ok _ -> true | _ -> false) |> Array.length

            // Stop all concurrently
            let stopStart = sw.Elapsed.TotalMilliseconds
            let! stopResults =
                containerIds
                |> List.map (fun id -> Containers.stop client id (Some 1))
                |> Async.Parallel
            let stopDuration = sw.Elapsed.TotalMilliseconds - stopStart

            let stopSuccessful = stopResults |> Array.filter (function Ok _ -> true | _ -> false) |> Array.length

            let duration = DateTime.UtcNow - start

            // Cleanup
            for id in containerIds do
                let! _ = Containers.remove client id true false
                ()

            let metrics = Map.ofList [
                ("start_count", float startSuccessful)
                ("stop_count", float stopSuccessful)
                ("start_total_ms", startDuration)
                ("stop_total_ms", stopDuration)
                ("start_avg_ms", startDuration / float count)
                ("stop_avg_ms", stopDuration / float count)
            ]

            if startSuccessful = count && stopSuccessful = count then
                return Success (
                    "Concurrent start/stop",
                    duration,
                    sprintf "Started and stopped %d containers (start: %.1fms, stop: %.1fms)" count startDuration stopDuration,
                    metrics)
            else
                return Failure (
                    "Concurrent start/stop",
                    duration,
                    sprintf "Start: %d/%d, Stop: %d/%d" startSuccessful count stopSuccessful count)
}

/// Test: Concurrent list operations
let testConcurrentLists (client: PodmanClient) (count: int) : Async<StressTestResult> = async {
    let start = DateTime.UtcNow
    let sw = Stopwatch.StartNew()

    let listTasks =
        [1..count]
        |> List.map (fun _ -> async {
            let taskStart = sw.Elapsed.TotalMilliseconds
            let! result = Containers.listAll client
            let taskEnd = sw.Elapsed.TotalMilliseconds
            return (taskEnd - taskStart, match result with Ok c -> Some c.Length | Error _ -> None)
        })

    let! results = Async.Parallel listTasks
    let duration = DateTime.UtcNow - start

    let successful = results |> Array.filter (fun (_, r) -> r.IsSome) |> Array.length
    let durations = results |> Array.map fst

    let avgDuration = Array.average durations
    let maxDuration = Array.max durations
    let minDuration = Array.min durations
    let containerCounts = results |> Array.choose snd
    let avgContainers = if containerCounts.Length > 0 then Array.average (containerCounts |> Array.map float) else 0.0

    let metrics = Map.ofList [
        ("successful", float successful)
        ("avg_ms", avgDuration)
        ("max_ms", maxDuration)
        ("min_ms", minDuration)
        ("avg_containers", avgContainers)
    ]

    if successful = count then
        return Success (
            "Concurrent lists",
            duration,
            sprintf "%d concurrent list operations (avg: %.1fms, max: %.1fms)" count avgDuration maxDuration,
            metrics)
    else
        return Failure ("Concurrent lists", duration, sprintf "Only %d/%d succeeded" successful count)
}

/// Test: Concurrent inspect operations
let testConcurrentInspects (client: PodmanClient) (count: int) : Async<StressTestResult> = async {
    let start = DateTime.UtcNow
    let sw = Stopwatch.StartNew()

    // Get a running container to inspect
    let! listResult = Containers.listRunning client
    match listResult with
    | Error e ->
        return Failure ("Concurrent inspects", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok [] ->
        return Skipped ("Concurrent inspects", "No running containers")
    | Ok (c :: _) ->
        let inspectTasks =
            [1..count]
            |> List.map (fun _ -> async {
                let taskStart = sw.Elapsed.TotalMilliseconds
                let! result = Containers.inspect client c.Id
                let taskEnd = sw.Elapsed.TotalMilliseconds
                return (taskEnd - taskStart, match result with Ok _ -> true | Error _ -> false)
            })

        let! results = Async.Parallel inspectTasks
        let duration = DateTime.UtcNow - start

        let successful = results |> Array.filter snd |> Array.length
        let durations = results |> Array.map fst

        let avgDuration = Array.average durations
        let maxDuration = Array.max durations

        let metrics = Map.ofList [
            ("successful", float successful)
            ("avg_ms", avgDuration)
            ("max_ms", maxDuration)
        ]

        if successful = count then
            return Success (
                "Concurrent inspects",
                duration,
                sprintf "%d concurrent inspect operations (avg: %.1fms)" count avgDuration,
                metrics)
        else
            return Failure ("Concurrent inspects", duration, sprintf "Only %d/%d succeeded" successful count)
}

// ============================================================================
// Large List Handling Tests
// ============================================================================

/// Test: List large number of containers
let testLargeContainerList (client: PodmanClient) : Async<StressTestResult> = async {
    let start = DateTime.UtcNow

    let! result = Containers.listAll client
    let duration = DateTime.UtcNow - start

    match result with
    | Error e ->
        return Failure ("Large container list", duration, PodmanError.toMessage e)
    | Ok containers ->
        let isLarge = containers.Length >= largeListThreshold

        let metrics = Map.ofList [
            ("count", float containers.Length)
            ("duration_ms", duration.TotalMilliseconds)
            ("per_item_ms", if containers.Length > 0 then duration.TotalMilliseconds / float containers.Length else 0.0)
        ]

        return Success (
            "Large container list",
            duration,
            sprintf "Listed %d containers in %.1fms%s" containers.Length duration.TotalMilliseconds (if isLarge then " (large)" else ""),
            metrics)
}

/// Test: List large number of images
let testLargeImageList (client: PodmanClient) : Async<StressTestResult> = async {
    let start = DateTime.UtcNow

    let! result = Images.listAll client
    let duration = DateTime.UtcNow - start

    match result with
    | Error e ->
        return Failure ("Large image list", duration, PodmanError.toMessage e)
    | Ok images ->
        let isLarge = images.Length >= largeListThreshold
        let totalSize = images |> List.sumBy (fun i -> i.Size)

        let metrics = Map.ofList [
            ("count", float images.Length)
            ("total_size_mb", float totalSize / 1024.0 / 1024.0)
            ("duration_ms", duration.TotalMilliseconds)
        ]

        return Success (
            "Large image list",
            duration,
            sprintf "Listed %d images (%.1fMB total) in %.1fms%s"
                images.Length
                (float totalSize / 1024.0 / 1024.0)
                duration.TotalMilliseconds
                (if isLarge then " (large)" else ""),
            metrics)
}

/// Test: List with pagination simulation
let testListPagination (client: PodmanClient) : Async<StressTestResult> = async {
    let start = DateTime.UtcNow

    // Simulate pagination by limiting results
    let pageSize = 10
    let mutable totalFetched = 0
    let mutable pages = 0

    let rec fetchPages () = async {
        let filters = { Containers.ListFilters.empty with All = true; Limit = Some pageSize }
        let! result = Containers.list client filters
        match result with
        | Error _ -> return ()
        | Ok containers ->
            totalFetched <- totalFetched + containers.Length
            pages <- pages + 1
            // In a real pagination scenario, we'd use offset
            return ()
    }

    // Fetch one page
    do! fetchPages ()

    let duration = DateTime.UtcNow - start

    let metrics = Map.ofList [
        ("pages", float pages)
        ("total_fetched", float totalFetched)
        ("page_size", float pageSize)
        ("duration_ms", duration.TotalMilliseconds)
    ]

    return Success (
        "List pagination",
        duration,
        sprintf "Fetched %d containers in %d page(s)" totalFetched pages,
        metrics)
}

// ============================================================================
// Rapid Polling Tests
// ============================================================================

/// Test: Rapid health check polling
let testRapidHealthPolling (client: PodmanClient) (iterations: int) : Async<StressTestResult> = async {
    let start = DateTime.UtcNow
    let sw = Stopwatch.StartNew()
    let mutable durations: float list = []
    let mutable successful = 0

    for _ in 1..iterations do
        let taskStart = sw.Elapsed.TotalMilliseconds
        let! result = Probes.checkAll client
        let taskEnd = sw.Elapsed.TotalMilliseconds
        durations <- (taskEnd - taskStart) :: durations
        match result with
        | Ok _ -> successful <- successful + 1
        | Error _ -> ()
        // Small delay to avoid overwhelming
        do! Async.Sleep 10

    let duration = DateTime.UtcNow - start

    let durationsArr = durations |> List.toArray
    let avgDuration = Array.average durationsArr
    let maxDuration = Array.max durationsArr
    let minDuration = Array.min durationsArr

    let metrics = Map.ofList [
        ("iterations", float iterations)
        ("successful", float successful)
        ("avg_ms", avgDuration)
        ("max_ms", maxDuration)
        ("min_ms", minDuration)
        ("polling_rate_hz", 1000.0 / avgDuration)
    ]

    if successful = iterations then
        return Success (
            "Rapid health polling",
            duration,
            sprintf "%d health polls (avg: %.1fms, rate: %.1f/s)" iterations avgDuration (1000.0 / avgDuration),
            metrics)
    else
        return Failure ("Rapid health polling", duration, sprintf "Only %d/%d succeeded" successful iterations)
}

/// Test: Rapid container status polling
let testRapidStatusPolling (client: PodmanClient) (iterations: int) : Async<StressTestResult> = async {
    let start = DateTime.UtcNow
    let sw = Stopwatch.StartNew()
    let mutable durations: float list = []
    let mutable successful = 0

    // Get a container to poll
    let! listResult = Containers.listRunning client
    match listResult with
    | Error e ->
        return Failure ("Rapid status polling", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok [] ->
        return Skipped ("Rapid status polling", "No running containers")
    | Ok (c :: _) ->
        for _ in 1..iterations do
            let taskStart = sw.Elapsed.TotalMilliseconds
            let! result = Containers.isRunning client c.Id
            let taskEnd = sw.Elapsed.TotalMilliseconds
            durations <- (taskEnd - taskStart) :: durations
            match result with
            | Ok _ -> successful <- successful + 1
            | Error _ -> ()

        let duration = DateTime.UtcNow - start

        let durationsArr = durations |> List.toArray
        let avgDuration = Array.average durationsArr
        let maxDuration = Array.max durationsArr

        let metrics = Map.ofList [
            ("iterations", float iterations)
            ("successful", float successful)
            ("avg_ms", avgDuration)
            ("max_ms", maxDuration)
            ("polling_rate_hz", 1000.0 / avgDuration)
        ]

        if successful = iterations then
            return Success (
                "Rapid status polling",
                duration,
                sprintf "%d status polls (avg: %.1fms, max: %.1fms)" iterations avgDuration maxDuration,
                metrics)
        else
            return Failure ("Rapid status polling", duration, sprintf "Only %d/%d succeeded" successful iterations)
}

/// Test: Rapid API ping
let testRapidPing (client: PodmanClient) (iterations: int) : Async<StressTestResult> = async {
    let start = DateTime.UtcNow
    let sw = Stopwatch.StartNew()
    let mutable durations: float list = []
    let mutable successful = 0

    for _ in 1..iterations do
        let taskStart = sw.Elapsed.TotalMilliseconds
        let! result = HttpClient.ping client
        let taskEnd = sw.Elapsed.TotalMilliseconds
        durations <- (taskEnd - taskStart) :: durations
        match result with
        | Ok true -> successful <- successful + 1
        | _ -> ()

    let duration = DateTime.UtcNow - start

    let durationsArr = durations |> List.toArray
    let avgDuration = Array.average durationsArr
    let maxDuration = Array.max durationsArr
    let minDuration = Array.min durationsArr

    let metrics = Map.ofList [
        ("iterations", float iterations)
        ("successful", float successful)
        ("avg_ms", avgDuration)
        ("max_ms", maxDuration)
        ("min_ms", minDuration)
        ("ping_rate_hz", 1000.0 / avgDuration)
    ]

    if successful = iterations then
        return Success (
            "Rapid ping",
            duration,
            sprintf "%d pings (avg: %.1fms, rate: %.0f/s)" iterations avgDuration (1000.0 / avgDuration),
            metrics)
    else
        return Failure ("Rapid ping", duration, sprintf "Only %d/%d succeeded" successful iterations)
}

// ============================================================================
// Resource Stress Tests
// ============================================================================

/// Test: System info under load
let testSystemInfoUnderLoad (client: PodmanClient) (iterations: int) : Async<StressTestResult> = async {
    let start = DateTime.UtcNow
    let sw = Stopwatch.StartNew()
    let mutable durations: float list = []
    let mutable successful = 0

    for _ in 1..iterations do
        let taskStart = sw.Elapsed.TotalMilliseconds
        let! result = System.info client
        let taskEnd = sw.Elapsed.TotalMilliseconds
        durations <- (taskEnd - taskStart) :: durations
        match result with
        | Ok _ -> successful <- successful + 1
        | Error _ -> ()

    let duration = DateTime.UtcNow - start

    let durationsArr = durations |> List.toArray
    let avgDuration = Array.average durationsArr

    let metrics = Map.ofList [
        ("iterations", float iterations)
        ("successful", float successful)
        ("avg_ms", avgDuration)
    ]

    if successful = iterations then
        return Success (
            "System info under load",
            duration,
            sprintf "%d system info calls (avg: %.1fms)" iterations avgDuration,
            metrics)
    else
        return Failure ("System info under load", duration, sprintf "Only %d/%d succeeded" successful iterations)
}

/// Test: Disk usage under load
let testDiskUsageUnderLoad (client: PodmanClient) (iterations: int) : Async<StressTestResult> = async {
    let start = DateTime.UtcNow
    let sw = Stopwatch.StartNew()
    let mutable durations: float list = []
    let mutable successful = 0

    for _ in 1..iterations do
        let taskStart = sw.Elapsed.TotalMilliseconds
        let! result = System.diskUsage client
        let taskEnd = sw.Elapsed.TotalMilliseconds
        durations <- (taskEnd - taskStart) :: durations
        match result with
        | Ok _ -> successful <- successful + 1
        | Error _ -> ()

    let duration = DateTime.UtcNow - start

    let durationsArr = durations |> List.toArray
    let avgDuration = Array.average durationsArr

    let metrics = Map.ofList [
        ("iterations", float iterations)
        ("successful", float successful)
        ("avg_ms", avgDuration)
    ]

    if successful = iterations then
        return Success (
            "Disk usage under load",
            duration,
            sprintf "%d disk usage calls (avg: %.1fms)" iterations avgDuration,
            metrics)
    else
        return Failure ("Disk usage under load", duration, sprintf "Only %d/%d succeeded" successful iterations)
}

// ============================================================================
// Test Runner
// ============================================================================

/// Run all stress tests
let runStressTests (client: PodmanClient) : Async<StressTestResult list> = async {
    printfn ""
    printfn "=== STRESS TESTS ==="
    printfn ""

    // Cleanup before tests
    let! cleanedUp = cleanupStressContainers client
    if cleanedUp > 0 then
        printfn "  Cleaned up %d leftover stress test containers" cleanedUp
        printfn ""

    let tests = [
        // Concurrent operations
        (fun c -> testConcurrentCreation c defaultConcurrency)
        (fun c -> testConcurrentStartStop c defaultConcurrency)
        (fun c -> testConcurrentLists c 10)
        (fun c -> testConcurrentInspects c 10)

        // Large list handling
        testLargeContainerList
        testLargeImageList
        testListPagination

        // Rapid polling
        (fun c -> testRapidHealthPolling c rapidIterations)
        (fun c -> testRapidStatusPolling c rapidIterations)
        (fun c -> testRapidPing c rapidIterations)

        // Resource stress
        (fun c -> testSystemInfoUnderLoad c 10)
        (fun c -> testDiskUsageUnderLoad c 10)
    ]

    let! results =
        tests
        |> List.map (fun test -> async {
            let! result = test client
            match result with
            | Success (name, duration, msg, metrics) ->
                printfn "  [PASS] %s (%.2fs) - %s" name duration.TotalSeconds msg
                // Print key metrics
                let keyMetrics =
                    metrics
                    |> Map.filter (fun k _ -> k.Contains("avg") || k.Contains("throughput") || k.Contains("rate"))
                    |> Map.toList
                    |> List.map (fun (k, v) -> sprintf "%s=%.1f" k v)
                    |> String.concat ", "
                if keyMetrics.Length > 0 then
                    printfn "         Metrics: %s" keyMetrics
            | Failure (name, duration, error) ->
                printfn "  [FAIL] %s (%.2fs) - %s" name duration.TotalSeconds error
            | Skipped (name, reason) ->
                printfn "  [SKIP] %s - %s" name reason
            return result
        })
        |> Async.Sequential

    // Final cleanup
    let! _ = cleanupStressContainers client

    return results |> Array.toList
}

/// Get test statistics
let summarize (results: StressTestResult list) : int * int * int =
    let passed = results |> List.filter (function Success _ -> true | _ -> false) |> List.length
    let failed = results |> List.filter (function Failure _ -> true | _ -> false) |> List.length
    let skipped = results |> List.filter (function Skipped _ -> true | _ -> false) |> List.length
    (passed, failed, skipped)

/// Get aggregate metrics from all tests
let getAggregateMetrics (results: StressTestResult list) : Map<string, float> =
    results
    |> List.choose (function Success (_, _, _, m) -> Some m | _ -> None)
    |> List.fold (fun acc m ->
        m |> Map.fold (fun a k v ->
            match Map.tryFind k a with
            | Some existing -> Map.add k ((existing + v) / 2.0) a  // Average
            | None -> Map.add k v a
        ) acc
    ) Map.empty
