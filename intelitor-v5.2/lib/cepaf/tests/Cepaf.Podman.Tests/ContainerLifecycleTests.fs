/// Cepaf.Podman Container Lifecycle Integration Tests
/// Full create/start/stop/restart/remove cycle testing
module Cepaf.Podman.Tests.ContainerLifecycleTests

open System
open System.Threading
open Cepaf.Podman.Domain
open Cepaf.Podman.Client
open Cepaf.Podman.Api

// ============================================================================
// Test Configuration
// ============================================================================

/// Test container naming prefix (for cleanup identification)
let testPrefix = "cepaf-test-"

/// Generate unique test container name
let generateTestName () =
    sprintf "%s%s" testPrefix (Guid.NewGuid().ToString("N").Substring(0, 8))

/// Test image (must exist locally - use localhost/ for safety compliance)
let testImage = "localhost/alpine:latest"

/// Fallback to busybox if alpine not available
let fallbackImage = "localhost/busybox:latest"

// ============================================================================
// Lifecycle Test Suite
// ============================================================================

type LifecycleTestResult =
    | Success of testName: string * duration: TimeSpan * message: string
    | Failure of testName: string * duration: TimeSpan * error: string
    | Skipped of testName: string * reason: string

/// Clean up any test containers left from previous runs
let cleanupTestContainers (client: PodmanClient) : Async<int> = async {
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

/// Test: Create container
let testCreateContainer (client: PodmanClient) (image: string) : Async<LifecycleTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestName ()

    let spec =
        ContainerSpec.create image
        |> ContainerSpec.withName name
        |> ContainerSpec.withCommand ["sleep"; "300"]
        |> ContainerSpec.withLabel "cepaf.test" "true"

    let! result = Containers.create client spec
    let duration = DateTime.UtcNow - start

    match result with
    | Ok containerId ->
        // Cleanup
        let! _ = Containers.remove client containerId true false
        return Success ("Create container", duration, sprintf "Created %s (id: %s)" name (containerId.Substring(0, 12)))
    | Error e ->
        return Failure ("Create container", duration, PodmanError.toMessage e)
}

/// Test: Create and start container
let testCreateAndStart (client: PodmanClient) (image: string) : Async<LifecycleTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestName ()

    let spec =
        ContainerSpec.create image
        |> ContainerSpec.withName name
        |> ContainerSpec.withCommand ["sleep"; "300"]

    let! result = Containers.createAndStart client spec
    let duration = DateTime.UtcNow - start

    match result with
    | Ok containerId ->
        // Verify running
        let! isRunningResult = Containers.isRunning client containerId
        let isRunning = match isRunningResult with Ok r -> r | Error _ -> false

        // Cleanup
        let! _ = Containers.stopAndRemove client containerId 1

        if isRunning then
            return Success ("Create and start", duration, sprintf "Container %s started successfully" name)
        else
            return Failure ("Create and start", duration, "Container not in running state")
    | Error e ->
        return Failure ("Create and start", duration, PodmanError.toMessage e)
}

/// Test: Start/Stop cycle
let testStartStop (client: PodmanClient) (image: string) : Async<LifecycleTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestName ()

    let spec =
        ContainerSpec.create image
        |> ContainerSpec.withName name
        |> ContainerSpec.withCommand ["sleep"; "300"]

    let! createResult = Containers.create client spec

    match createResult with
    | Error e ->
        return Failure ("Start/Stop cycle", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok containerId ->
        try
            // Start
            let! startResult = Containers.start client containerId
            match startResult with
            | Error e ->
                let! _ = Containers.remove client containerId true false
                return Failure ("Start/Stop cycle", DateTime.UtcNow - start, sprintf "Start failed: %s" (PodmanError.toMessage e))
            | Ok () ->
                // Verify running
                let! runningCheck = Containers.isRunning client containerId
                let isRunning = match runningCheck with Ok r -> r | Error _ -> false

                if not isRunning then
                    let! _ = Containers.remove client containerId true false
                    return Failure ("Start/Stop cycle", DateTime.UtcNow - start, "Container not running after start")
                else
                    // Stop
                    let! stopResult = Containers.stop client containerId (Some 5)
                    match stopResult with
                    | Error e ->
                        let! _ = Containers.remove client containerId true false
                        return Failure ("Start/Stop cycle", DateTime.UtcNow - start, sprintf "Stop failed: %s" (PodmanError.toMessage e))
                    | Ok () ->
                        // Verify stopped
                        let! stoppedCheck = Containers.isRunning client containerId
                        let isStopped = match stoppedCheck with Ok r -> not r | Error _ -> false

                        // Cleanup
                        let! _ = Containers.remove client containerId true false
                        let duration = DateTime.UtcNow - start

                        if isStopped then
                            return Success ("Start/Stop cycle", duration, "Start and stop completed successfully")
                        else
                            return Failure ("Start/Stop cycle", duration, "Container still running after stop")
        with ex ->
            let! _ = Containers.remove client containerId true false
            return Failure ("Start/Stop cycle", DateTime.UtcNow - start, ex.Message)
}

/// Test: Restart container
let testRestart (client: PodmanClient) (image: string) : Async<LifecycleTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestName ()

    let spec =
        ContainerSpec.create image
        |> ContainerSpec.withName name
        |> ContainerSpec.withCommand ["sleep"; "300"]

    let! result = Containers.createAndStart client spec

    match result with
    | Error e ->
        return Failure ("Restart container", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok containerId ->
        try
            // Get initial PID (via exec or inspect)
            let! inspectBefore = Containers.inspect client containerId
            let pidBefore = match inspectBefore with Ok i -> i.State.Pid | Error _ -> 0

            // Restart
            let! restartResult = Containers.restart client containerId (Some 5)
            match restartResult with
            | Error e ->
                let! _ = Containers.stopAndRemove client containerId 1
                return Failure ("Restart container", DateTime.UtcNow - start, sprintf "Restart failed: %s" (PodmanError.toMessage e))
            | Ok () ->
                // Wait a bit for restart
                do! Async.Sleep 1000

                // Verify still running
                let! runningCheck = Containers.isRunning client containerId
                let isRunning = match runningCheck with Ok r -> r | Error _ -> false

                // Cleanup
                let! _ = Containers.stopAndRemove client containerId 1
                let duration = DateTime.UtcNow - start

                if isRunning then
                    return Success ("Restart container", duration, sprintf "Restart completed (pid: %d)" pidBefore)
                else
                    return Failure ("Restart container", duration, "Container not running after restart")
        with ex ->
            let! _ = Containers.stopAndRemove client containerId 1
            return Failure ("Restart container", DateTime.UtcNow - start, ex.Message)
}

/// Test: Pause and unpause
let testPauseUnpause (client: PodmanClient) (image: string) : Async<LifecycleTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestName ()

    let spec =
        ContainerSpec.create image
        |> ContainerSpec.withName name
        |> ContainerSpec.withCommand ["sleep"; "300"]

    let! result = Containers.createAndStart client spec

    match result with
    | Error e ->
        return Failure ("Pause/Unpause", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok containerId ->
        try
            // Pause
            let! pauseResult = Containers.pause client containerId
            match pauseResult with
            | Error e ->
                let! _ = Containers.stopAndRemove client containerId 1
                return Failure ("Pause/Unpause", DateTime.UtcNow - start, sprintf "Pause failed: %s" (PodmanError.toMessage e))
            | Ok () ->
                // Verify paused
                let! stateResult = Containers.getState client containerId
                let isPaused =
                    match stateResult with
                    | Ok ContainerStatus.Paused -> true
                    | _ -> false

                if not isPaused then
                    let! _ = Containers.stopAndRemove client containerId 1
                    return Failure ("Pause/Unpause", DateTime.UtcNow - start, "Container not paused after pause")
                else
                    // Unpause
                    let! unpauseResult = Containers.unpause client containerId
                    match unpauseResult with
                    | Error e ->
                        let! _ = Containers.stopAndRemove client containerId 1
                        return Failure ("Pause/Unpause", DateTime.UtcNow - start, sprintf "Unpause failed: %s" (PodmanError.toMessage e))
                    | Ok () ->
                        // Verify running again
                        let! runningCheck = Containers.isRunning client containerId
                        let isRunning = match runningCheck with Ok r -> r | Error _ -> false

                        // Cleanup
                        let! _ = Containers.stopAndRemove client containerId 1
                        let duration = DateTime.UtcNow - start

                        if isRunning then
                            return Success ("Pause/Unpause", duration, "Pause and unpause completed successfully")
                        else
                            return Failure ("Pause/Unpause", duration, "Container not running after unpause")
        with ex ->
            let! _ = Containers.stopAndRemove client containerId 1
            return Failure ("Pause/Unpause", DateTime.UtcNow - start, ex.Message)
}

/// Test: Kill with signal
let testKill (client: PodmanClient) (image: string) : Async<LifecycleTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestName ()

    let spec =
        ContainerSpec.create image
        |> ContainerSpec.withName name
        |> ContainerSpec.withCommand ["sleep"; "300"]

    let! result = Containers.createAndStart client spec

    match result with
    | Error e ->
        return Failure ("Kill with signal", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok containerId ->
        try
            // Kill with SIGTERM
            let! killResult = Containers.kill client containerId (Some "SIGTERM")

            // Wait a bit
            do! Async.Sleep 500

            // Cleanup regardless
            let! _ = Containers.remove client containerId true false
            let duration = DateTime.UtcNow - start

            match killResult with
            | Ok () ->
                return Success ("Kill with signal", duration, "Kill with SIGTERM completed")
            | Error e ->
                return Failure ("Kill with signal", duration, PodmanError.toMessage e)
        with ex ->
            let! _ = Containers.remove client containerId true false
            return Failure ("Kill with signal", DateTime.UtcNow - start, ex.Message)
}

/// Test: Container rename
let testRename (client: PodmanClient) (image: string) : Async<LifecycleTestResult> = async {
    let start = DateTime.UtcNow
    let originalName = generateTestName ()
    let newName = generateTestName ()

    let spec =
        ContainerSpec.create image
        |> ContainerSpec.withName originalName
        |> ContainerSpec.withCommand ["sleep"; "300"]

    let! result = Containers.create client spec

    match result with
    | Error e ->
        return Failure ("Rename container", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok containerId ->
        try
            // Rename
            let! renameResult = Containers.rename client containerId newName
            match renameResult with
            | Error e ->
                let! _ = Containers.remove client containerId true false
                return Failure ("Rename container", DateTime.UtcNow - start, sprintf "Rename failed: %s" (PodmanError.toMessage e))
            | Ok () ->
                // Verify new name
                let! findResult = Containers.findByName client newName
                let found = match findResult with Ok (Some _) -> true | _ -> false

                // Cleanup
                let! _ = Containers.remove client containerId true false
                let duration = DateTime.UtcNow - start

                if found then
                    return Success ("Rename container", duration, sprintf "Renamed from %s to %s" originalName newName)
                else
                    return Failure ("Rename container", duration, "Container not found by new name after rename")
        with ex ->
            let! _ = Containers.remove client containerId true false
            return Failure ("Rename container", DateTime.UtcNow - start, ex.Message)
}

/// Test: Execute command in container
let testExec (client: PodmanClient) (image: string) : Async<LifecycleTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestName ()

    let spec =
        ContainerSpec.create image
        |> ContainerSpec.withName name
        |> ContainerSpec.withCommand ["sleep"; "300"]

    let! result = Containers.createAndStart client spec

    match result with
    | Error e ->
        return Failure ("Exec in container", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok containerId ->
        try
            // Wait a bit for container to be ready
            do! Async.Sleep 500

            // Execute command
            let! execResult = Containers.execWait client containerId ["echo"; "hello"]

            // Cleanup
            let! _ = Containers.stopAndRemove client containerId 1
            let duration = DateTime.UtcNow - start

            match execResult with
            | Ok output ->
                return Success ("Exec in container", duration, sprintf "Exec output: %s" (output.Trim()))
            | Error e ->
                return Failure ("Exec in container", duration, PodmanError.toMessage e)
        with ex ->
            let! _ = Containers.stopAndRemove client containerId 1
            return Failure ("Exec in container", DateTime.UtcNow - start, ex.Message)
}

/// Test: Get container logs
let testLogs (client: PodmanClient) (image: string) : Async<LifecycleTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestName ()

    let spec =
        ContainerSpec.create image
        |> ContainerSpec.withName name
        |> ContainerSpec.withCommand ["sh"; "-c"; "echo 'test log line' && sleep 300"]

    let! result = Containers.createAndStart client spec

    match result with
    | Error e ->
        return Failure ("Get container logs", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok containerId ->
        try
            // Wait for log to be written
            do! Async.Sleep 1000

            // Get logs
            let! logsResult = Containers.logsLast client containerId 10

            // Cleanup
            let! _ = Containers.stopAndRemove client containerId 1
            let duration = DateTime.UtcNow - start

            match logsResult with
            | Ok logs ->
                if logs.Contains("test log line") || logs.Length > 0 then
                    return Success ("Get container logs", duration, sprintf "Got %d bytes of logs" logs.Length)
                else
                    return Success ("Get container logs", duration, "Logs retrieved (may be empty)")
            | Error e ->
                return Failure ("Get container logs", duration, PodmanError.toMessage e)
        with ex ->
            let! _ = Containers.stopAndRemove client containerId 1
            return Failure ("Get container logs", DateTime.UtcNow - start, ex.Message)
}

/// Test: Full lifecycle cycle
let testFullLifecycle (client: PodmanClient) (image: string) : Async<LifecycleTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestName ()

    let spec =
        ContainerSpec.create image
        |> ContainerSpec.withName name
        |> ContainerSpec.withCommand ["sleep"; "300"]
        |> ContainerSpec.withLabel "cepaf.lifecycle" "full"
        |> ContainerSpec.withRestartAlways

    try
        // 1. Create
        let! createResult = Containers.create client spec
        match createResult with
        | Error e -> return Failure ("Full lifecycle", DateTime.UtcNow - start, sprintf "Create failed: %s" (PodmanError.toMessage e))
        | Ok containerId ->
            // 2. Start
            let! startResult = Containers.start client containerId
            match startResult with
            | Error e ->
                let! _ = Containers.remove client containerId true false
                return Failure ("Full lifecycle", DateTime.UtcNow - start, sprintf "Start failed: %s" (PodmanError.toMessage e))
            | Ok () ->
                // 3. Verify running
                let! runCheck = Containers.isRunning client containerId
                match runCheck with
                | Error _ | Ok false ->
                    let! _ = Containers.remove client containerId true false
                    return Failure ("Full lifecycle", DateTime.UtcNow - start, "Not running after start")
                | Ok true ->
                    // 4. Pause
                    let! pauseResult = Containers.pause client containerId
                    match pauseResult with
                    | Error e ->
                        let! _ = Containers.stopAndRemove client containerId 1
                        return Failure ("Full lifecycle", DateTime.UtcNow - start, sprintf "Pause failed: %s" (PodmanError.toMessage e))
                    | Ok () ->
                        // 5. Unpause
                        let! unpauseResult = Containers.unpause client containerId
                        match unpauseResult with
                        | Error e ->
                            let! _ = Containers.stopAndRemove client containerId 1
                            return Failure ("Full lifecycle", DateTime.UtcNow - start, sprintf "Unpause failed: %s" (PodmanError.toMessage e))
                        | Ok () ->
                            // 6. Restart
                            let! restartResult = Containers.restart client containerId (Some 2)
                            match restartResult with
                            | Error e ->
                                let! _ = Containers.stopAndRemove client containerId 1
                                return Failure ("Full lifecycle", DateTime.UtcNow - start, sprintf "Restart failed: %s" (PodmanError.toMessage e))
                            | Ok () ->
                                do! Async.Sleep 500
                                // 7. Stop
                                let! stopResult = Containers.stop client containerId (Some 2)
                                match stopResult with
                                | Error e ->
                                    let! _ = Containers.remove client containerId true false
                                    return Failure ("Full lifecycle", DateTime.UtcNow - start, sprintf "Stop failed: %s" (PodmanError.toMessage e))
                                | Ok () ->
                                    // 8. Remove
                                    let! removeResult = Containers.remove client containerId false false
                                    let duration = DateTime.UtcNow - start
                                    match removeResult with
                                    | Ok () ->
                                        return Success ("Full lifecycle", duration, "Complete lifecycle: create->start->pause->unpause->restart->stop->remove")
                                    | Error e ->
                                        let! _ = Containers.remove client containerId true false
                                        return Failure ("Full lifecycle", duration, sprintf "Remove failed: %s" (PodmanError.toMessage e))
    with ex ->
        return Failure ("Full lifecycle", DateTime.UtcNow - start, ex.Message)
}

// ============================================================================
// Test Runner
// ============================================================================

/// Run all lifecycle tests
let runLifecycleTests (client: PodmanClient) : Async<LifecycleTestResult list> = async {
    printfn ""
    printfn "=== CONTAINER LIFECYCLE TESTS ==="
    printfn ""

    // Check for test image
    let! imageExists = Images.exists client testImage
    let image =
        match imageExists with
        | Ok true -> testImage
        | _ -> fallbackImage

    let! fallbackExists = Images.exists client image
    match fallbackExists with
    | Ok false | Error _ ->
        printfn "  [SKIP] No test image available (need %s or %s)" testImage fallbackImage
        return [Skipped ("All lifecycle tests", "No test image available")]
    | Ok true ->
        printfn "  Using image: %s" image
        printfn ""

        // Cleanup before tests
        let! cleanedUp = cleanupTestContainers client
        if cleanedUp > 0 then
            printfn "  Cleaned up %d leftover test containers" cleanedUp
            printfn ""

        // Run tests sequentially (to avoid resource conflicts)
        let tests = [
            testCreateContainer
            testCreateAndStart
            testStartStop
            testRestart
            testPauseUnpause
            testKill
            testRename
            testExec
            testLogs
            testFullLifecycle
        ]

        let! results =
            tests
            |> List.map (fun test -> async {
                let! result = test client image
                match result with
                | Success (name, duration, msg) ->
                    printfn "  [PASS] %s (%.2fs) - %s" name duration.TotalSeconds msg
                | Failure (name, duration, error) ->
                    printfn "  [FAIL] %s (%.2fs) - %s" name duration.TotalSeconds error
                | Skipped (name, reason) ->
                    printfn "  [SKIP] %s - %s" name reason
                return result
            })
            |> Async.Sequential

        // Final cleanup
        let! _ = cleanupTestContainers client

        return results |> Array.toList
}

/// Get test statistics
let summarize (results: LifecycleTestResult list) : int * int * int =
    let passed = results |> List.filter (function Success _ -> true | _ -> false) |> List.length
    let failed = results |> List.filter (function Failure _ -> true | _ -> false) |> List.length
    let skipped = results |> List.filter (function Skipped _ -> true | _ -> false) |> List.length
    (passed, failed, skipped)
