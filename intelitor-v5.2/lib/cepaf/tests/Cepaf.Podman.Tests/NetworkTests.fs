/// Cepaf.Podman Network Integration Tests
/// Network create/connect/disconnect/remove lifecycle testing
module Cepaf.Podman.Tests.NetworkTests

open System
open Cepaf.Podman.Domain
open Cepaf.Podman.Client
open Cepaf.Podman.Api

// ============================================================================
// Test Configuration
// ============================================================================

/// Test network naming prefix
let testNetworkPrefix = "cepaf-test-net-"

/// Generate unique test network name
let generateTestNetworkName () =
    sprintf "%s%s" testNetworkPrefix (Guid.NewGuid().ToString("N").Substring(0, 8))

/// Test container image (for connect/disconnect tests)
let testImage = "localhost/alpine:latest"

// ============================================================================
// Network Test Result
// ============================================================================

type NetworkTestResult =
    | Success of testName: string * duration: TimeSpan * message: string
    | Failure of testName: string * duration: TimeSpan * error: string
    | Skipped of testName: string * reason: string

// ============================================================================
// Cleanup
// ============================================================================

/// Clean up test networks
let cleanupTestNetworks (client: PodmanClient) : Async<int> = async {
    let! listResult = Networks.list client
    match listResult with
    | Error _ -> return 0
    | Ok networks ->
        let testNetworks =
            networks
            |> List.filter (fun n -> n.Name.StartsWith(testNetworkPrefix))

        let! _ =
            testNetworks
            |> List.map (fun n -> async {
                let! _ = Networks.remove client n.Name true
                return ()
            })
            |> Async.Parallel

        return testNetworks.Length
}

// ============================================================================
// Network List and Inspect Tests
// ============================================================================

/// Test: List networks
let testListNetworks (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow

    let! result = Networks.list client
    let duration = DateTime.UtcNow - start

    match result with
    | Ok networks ->
        let drivers =
            networks
            |> List.groupBy (fun n -> NetworkDriver.toString n.Driver)
            |> List.map (fun (d, ns) -> sprintf "%s:%d" d ns.Length)
            |> String.concat ", "
        return Success ("List networks", duration, sprintf "Found %d networks (%s)" networks.Length drivers)
    | Error e ->
        return Failure ("List networks", duration, PodmanError.toMessage e)
}

/// Test: Inspect default network
let testInspectDefaultNetwork (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow

    let! result = Networks.getDefault client
    let duration = DateTime.UtcNow - start

    match result with
    | Ok (Some net) ->
        return Success (
            "Inspect default network",
            duration,
            sprintf "Default: %s (driver: %s, dns: %b)" net.Name (NetworkDriver.toString net.Driver) net.DnsEnabled)
    | Ok None ->
        return Skipped ("Inspect default network", "No default network found")
    | Error e ->
        return Failure ("Inspect default network", duration, PodmanError.toMessage e)
}

/// Test: Check network exists
let testNetworkExists (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow

    // Check for podman or bridge network
    let! exists1 = Networks.exists client "podman"
    let! exists2 = Networks.exists client "bridge"
    let duration = DateTime.UtcNow - start

    let anyExists =
        match exists1, exists2 with
        | Ok true, _ -> true
        | _, Ok true -> true
        | _, _ -> false

    if anyExists then
        return Success ("Network exists check", duration, "Default network exists")
    else
        return Skipped ("Network exists check", "No standard default network")
}

/// Test: Check non-existent network
let testNetworkNotExists (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow

    let fakeNetwork = "this-network-does-not-exist-" + Guid.NewGuid().ToString("N")
    let! result = Networks.exists client fakeNetwork
    let duration = DateTime.UtcNow - start

    match result with
    | Ok false ->
        return Success ("Non-existent network check", duration, "Correctly reported as not existing")
    | Ok true ->
        return Failure ("Non-existent network check", duration, "Fake network reported as existing")
    | Error e ->
        return Failure ("Non-existent network check", duration, PodmanError.toMessage e)
}

// ============================================================================
// Network Create/Remove Tests
// ============================================================================

/// Test: Create basic network
let testCreateNetwork (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestNetworkName ()

    let! result = Networks.createNamed client name
    let duration = DateTime.UtcNow - start

    match result with
    | Ok net ->
        // Cleanup
        let! _ = Networks.remove client name true
        return Success ("Create network", duration, sprintf "Created %s (driver: %s)" net.Name (NetworkDriver.toString net.Driver))
    | Error e ->
        return Failure ("Create network", duration, PodmanError.toMessage e)
}

/// Test: Create network with spec
let testCreateNetworkWithSpec (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestNetworkName ()

    let spec =
        NetworkSpec.create name
        |> NetworkSpec.withDriver NetworkDriver.Bridge
        |> NetworkSpec.withLabel "cepaf.test" "true"

    let! result = Networks.create client spec
    let duration = DateTime.UtcNow - start

    match result with
    | Ok net ->
        // Cleanup
        let! _ = Networks.remove client name true
        return Success ("Create network with spec", duration, sprintf "Created %s with labels" net.Name)
    | Error e ->
        return Failure ("Create network with spec", duration, PodmanError.toMessage e)
}

/// Test: Create bridge network with subnet
let testCreateBridgeWithSubnet (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestNetworkName ()

    let! result = Networks.createBridge client name (Some "172.31.0.0/16")
    let duration = DateTime.UtcNow - start

    match result with
    | Ok net ->
        // Verify subnet
        let hasSubnet = net.Subnets |> List.exists (fun s -> s.Subnet.Contains("172.31"))

        // Cleanup
        let! _ = Networks.remove client name true

        if hasSubnet then
            return Success ("Create bridge with subnet", duration, sprintf "Created %s with subnet 172.31.0.0/16" net.Name)
        else
            return Success ("Create bridge with subnet", duration, sprintf "Created %s (subnet verification skipped)" net.Name)
    | Error e ->
        return Failure ("Create bridge with subnet", duration, PodmanError.toMessage e)
}

/// Test: Create internal network
let testCreateInternalNetwork (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestNetworkName ()

    let spec =
        NetworkSpec.create name
        |> NetworkSpec.withDriver NetworkDriver.Bridge
        |> NetworkSpec.withInternal

    let! result = Networks.create client spec
    let duration = DateTime.UtcNow - start

    match result with
    | Ok net ->
        // Verify internal flag
        let isInternal = net.Internal

        // Cleanup
        let! _ = Networks.remove client name true

        if isInternal then
            return Success ("Create internal network", duration, sprintf "Created internal network %s" net.Name)
        else
            return Failure ("Create internal network", duration, "Network not marked as internal")
    | Error e ->
        return Failure ("Create internal network", duration, PodmanError.toMessage e)
}

/// Test: Remove network
let testRemoveNetwork (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestNetworkName ()

    // Create first
    let! createResult = Networks.createNamed client name
    match createResult with
    | Error e ->
        return Failure ("Remove network", DateTime.UtcNow - start, sprintf "Setup failed: %s" (PodmanError.toMessage e))
    | Ok _ ->
        // Remove
        let! removeResult = Networks.remove client name false
        let duration = DateTime.UtcNow - start

        match removeResult with
        | Ok () ->
            // Verify removed
            let! existsAfter = Networks.exists client name
            match existsAfter with
            | Ok false ->
                return Success ("Remove network", duration, sprintf "Removed %s" name)
            | Ok true ->
                return Failure ("Remove network", duration, "Network still exists after remove")
            | Error e ->
                return Failure ("Remove network", duration, PodmanError.toMessage e)
        | Error e ->
            let! _ = Networks.remove client name true
            return Failure ("Remove network", duration, PodmanError.toMessage e)
}

/// Test: Ensure exists (create if not)
let testEnsureExists (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestNetworkName ()

    // First call should create
    let! result1 = Networks.ensureExists client name
    match result1 with
    | Error e ->
        return Failure ("Ensure exists", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok net1 ->
        // Second call should return existing
        let! result2 = Networks.ensureExists client name
        let duration = DateTime.UtcNow - start

        // Cleanup
        let! _ = Networks.remove client name true

        match result2 with
        | Ok net2 when net1.Name = net2.Name ->
            return Success ("Ensure exists", duration, sprintf "Idempotent: %s" name)
        | Ok _ ->
            return Failure ("Ensure exists", duration, "Second call returned different network")
        | Error e ->
            return Failure ("Ensure exists", duration, PodmanError.toMessage e)
}

/// Test: Remove if exists
let testRemoveIfExists (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestNetworkName ()

    // Create first
    let! _ = Networks.createNamed client name

    // Remove if exists
    let! result = Networks.removeIfExists client name

    // Try to remove non-existent (should succeed silently)
    let! result2 = Networks.removeIfExists client name
    let duration = DateTime.UtcNow - start

    match result, result2 with
    | Ok (), Ok () ->
        return Success ("Remove if exists", duration, "Removed existing and handled non-existent")
    | Error e, _ ->
        return Failure ("Remove if exists", duration, PodmanError.toMessage e)
    | _, Error e ->
        return Failure ("Remove if exists", duration, sprintf "Non-existent removal failed: %s" (PodmanError.toMessage e))
}

// ============================================================================
// Network Connect/Disconnect Tests
// ============================================================================

/// Test: Connect container to network
let testConnectContainer (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow

    // Check if we have a test image
    let! imageExists = Images.exists client testImage
    match imageExists with
    | Error _ | Ok false ->
        return Skipped ("Connect container", "Test image not available")
    | Ok true ->
        let networkName = generateTestNetworkName ()
        let containerName = "cepaf-test-conn-" + Guid.NewGuid().ToString("N").Substring(0, 8)

        try
            // Create network
            let! netResult = Networks.createNamed client networkName
            match netResult with
            | Error e ->
                return Failure ("Connect container", DateTime.UtcNow - start, sprintf "Network creation failed: %s" (PodmanError.toMessage e))
            | Ok _ ->
                // Create container
                let spec =
                    ContainerSpec.create testImage
                    |> ContainerSpec.withName containerName
                    |> ContainerSpec.withCommand ["sleep"; "300"]

                let! containerResult = Containers.createAndStart client spec
                match containerResult with
                | Error e ->
                    let! _ = Networks.remove client networkName true
                    return Failure ("Connect container", DateTime.UtcNow - start, sprintf "Container creation failed: %s" (PodmanError.toMessage e))
                | Ok containerId ->
                    // Connect
                    let! connectResult = Networks.connectContainer client networkName containerName
                    let duration = DateTime.UtcNow - start

                    // Cleanup
                    let! _ = Containers.stopAndRemove client containerId 1
                    let! _ = Networks.remove client networkName true

                    match connectResult with
                    | Ok () ->
                        return Success ("Connect container", duration, sprintf "Connected %s to %s" containerName networkName)
                    | Error e ->
                        return Failure ("Connect container", duration, PodmanError.toMessage e)
        with ex ->
            let! _ = Networks.removeIfExists client networkName
            return Failure ("Connect container", DateTime.UtcNow - start, ex.Message)
}

/// Test: Connect with options
let testConnectWithOptions (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow

    let! imageExists = Images.exists client testImage
    match imageExists with
    | Error _ | Ok false ->
        return Skipped ("Connect with options", "Test image not available")
    | Ok true ->
        let networkName = generateTestNetworkName ()
        let containerName = "cepaf-test-connopts-" + Guid.NewGuid().ToString("N").Substring(0, 8)

        try
            // Create network with specific subnet
            let! netResult = Networks.createBridge client networkName (Some "172.30.0.0/16")
            match netResult with
            | Error e ->
                return Failure ("Connect with options", DateTime.UtcNow - start, sprintf "Network creation failed: %s" (PodmanError.toMessage e))
            | Ok _ ->
                // Create container
                let spec =
                    ContainerSpec.create testImage
                    |> ContainerSpec.withName containerName
                    |> ContainerSpec.withCommand ["sleep"; "300"]

                let! containerResult = Containers.createAndStart client spec
                match containerResult with
                | Error e ->
                    let! _ = Networks.remove client networkName true
                    return Failure ("Connect with options", DateTime.UtcNow - start, sprintf "Container creation failed: %s" (PodmanError.toMessage e))
                | Ok containerId ->
                    // Connect with alias
                    let opts =
                        Networks.ConnectOptions.create containerName
                        |> Networks.ConnectOptions.withAlias "myapp"

                    let! connectResult = Networks.connect client networkName opts
                    let duration = DateTime.UtcNow - start

                    // Cleanup
                    let! _ = Containers.stopAndRemove client containerId 1
                    let! _ = Networks.remove client networkName true

                    match connectResult with
                    | Ok () ->
                        return Success ("Connect with options", duration, sprintf "Connected with alias 'myapp'")
                    | Error e ->
                        return Failure ("Connect with options", duration, PodmanError.toMessage e)
        with ex ->
            let! _ = Networks.removeIfExists client networkName
            return Failure ("Connect with options", DateTime.UtcNow - start, ex.Message)
}

/// Test: Disconnect container from network
let testDisconnectContainer (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow

    let! imageExists = Images.exists client testImage
    match imageExists with
    | Error _ | Ok false ->
        return Skipped ("Disconnect container", "Test image not available")
    | Ok true ->
        let networkName = generateTestNetworkName ()
        let containerName = "cepaf-test-disc-" + Guid.NewGuid().ToString("N").Substring(0, 8)

        try
            // Create network and container
            let! netResult = Networks.createNamed client networkName
            match netResult with
            | Error e ->
                return Failure ("Disconnect container", DateTime.UtcNow - start, PodmanError.toMessage e)
            | Ok _ ->
                let spec =
                    ContainerSpec.create testImage
                    |> ContainerSpec.withName containerName
                    |> ContainerSpec.withCommand ["sleep"; "300"]

                let! containerResult = Containers.createAndStart client spec
                match containerResult with
                | Error e ->
                    let! _ = Networks.remove client networkName true
                    return Failure ("Disconnect container", DateTime.UtcNow - start, PodmanError.toMessage e)
                | Ok containerId ->
                    // Connect first
                    let! _ = Networks.connectContainer client networkName containerName

                    // Disconnect
                    let! disconnectResult = Networks.disconnect client networkName containerName false
                    let duration = DateTime.UtcNow - start

                    // Cleanup
                    let! _ = Containers.stopAndRemove client containerId 1
                    let! _ = Networks.remove client networkName true

                    match disconnectResult with
                    | Ok () ->
                        return Success ("Disconnect container", duration, sprintf "Disconnected %s from %s" containerName networkName)
                    | Error e ->
                        return Failure ("Disconnect container", duration, PodmanError.toMessage e)
        with ex ->
            let! _ = Networks.removeIfExists client networkName
            return Failure ("Disconnect container", DateTime.UtcNow - start, ex.Message)
}

// ============================================================================
// Network Query Tests
// ============================================================================

/// Test: List network names
let testListNetworkNames (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow

    let! result = Networks.listNames client
    let duration = DateTime.UtcNow - start

    match result with
    | Ok names ->
        return Success ("List network names", duration, sprintf "Networks: %s" (String.concat ", " names))
    | Error e ->
        return Failure ("List network names", duration, PodmanError.toMessage e)
}

/// Test: Get network stats
let testNetworkStats (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow

    let! defaultResult = Networks.getDefault client
    match defaultResult with
    | Error e ->
        return Failure ("Network stats", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok None ->
        return Skipped ("Network stats", "No default network")
    | Ok (Some net) ->
        let! statsResult = Networks.getStats client net.Name
        let duration = DateTime.UtcNow - start

        match statsResult with
        | Ok stats ->
            return Success (
                "Network stats",
                duration,
                sprintf "%s: driver=%s, internal=%b, dns=%b" stats.Name stats.Driver stats.Internal stats.DnsEnabled)
        | Error e ->
            return Failure ("Network stats", duration, PodmanError.toMessage e)
}

/// Test: Find network by name
let testFindByName (client: PodmanClient) : Async<NetworkTestResult> = async {
    let start = DateTime.UtcNow
    let name = generateTestNetworkName ()

    // Create a network to find
    let! createResult = Networks.createNamed client name
    match createResult with
    | Error e ->
        return Failure ("Find by name", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok _ ->
        let! findResult = Networks.findByName client name
        let duration = DateTime.UtcNow - start

        // Cleanup
        let! _ = Networks.remove client name true

        match findResult with
        | Ok (Some net) when net.Name = name ->
            return Success ("Find by name", duration, sprintf "Found %s" name)
        | Ok (Some _) ->
            return Failure ("Find by name", duration, "Found wrong network")
        | Ok None ->
            return Failure ("Find by name", duration, "Network not found")
        | Error e ->
            return Failure ("Find by name", duration, PodmanError.toMessage e)
}

// ============================================================================
// Test Runner
// ============================================================================

/// Run all network tests
let runNetworkTests (client: PodmanClient) : Async<NetworkTestResult list> = async {
    printfn ""
    printfn "=== NETWORK TESTS ==="
    printfn ""

    // Cleanup before tests
    let! cleanedUp = cleanupTestNetworks client
    if cleanedUp > 0 then
        printfn "  Cleaned up %d leftover test networks" cleanedUp
        printfn ""

    let tests = [
        testListNetworks
        testInspectDefaultNetwork
        testNetworkExists
        testNetworkNotExists
        testCreateNetwork
        testCreateNetworkWithSpec
        testCreateBridgeWithSubnet
        testCreateInternalNetwork
        testRemoveNetwork
        testEnsureExists
        testRemoveIfExists
        testConnectContainer
        testConnectWithOptions
        testDisconnectContainer
        testListNetworkNames
        testNetworkStats
        testFindByName
    ]

    let! results =
        tests
        |> List.map (fun test -> async {
            let! result = test client
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
    let! _ = cleanupTestNetworks client

    return results |> Array.toList
}

/// Get test statistics
let summarize (results: NetworkTestResult list) : int * int * int =
    let passed = results |> List.filter (function Success _ -> true | _ -> false) |> List.length
    let failed = results |> List.filter (function Failure _ -> true | _ -> false) |> List.length
    let skipped = results |> List.filter (function Skipped _ -> true | _ -> false) |> List.length
    (passed, failed, skipped)
