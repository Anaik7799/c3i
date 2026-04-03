namespace Cepaf.Tests

open Xunit
open Cepaf.Modules.ServiceDAG

/// ServiceDAG Unit Tests
/// STAMP Compliance: SC-CEP-003, SC-CEP-004, SC-AGT-018
/// AOR Compliance: AOR-SAF-001, AOR-CNT-001
/// Test Coverage: DAG construction, cycle detection, topological sort,
///                layer assignment, dependency resolution, boot sequence, health state
module ServiceDAGTests =

    // ========================================================================
    // TEST DATA FACTORY FUNCTIONS
    // Factories avoid xUnit initialization issues with module-level values
    // ========================================================================

    /// Database container - Layer 0 (no dependencies)
    let makeDbContainer () : ContainerDef = {
        Name = "indrajaal-db"
        Image = "localhost/indrajaal-db:nixos"
        DependsOn = []
        DependencyTypes = Map.empty
        Layer = Some 0
    }

    /// Application container - Layer 1 (depends on db)
    let makeAppContainer () : ContainerDef = {
        Name = "indrajaal-app"
        Image = "localhost/indrajaal-app:nixos"
        DependsOn = ["indrajaal-db"]
        DependencyTypes = Map.ofList [("indrajaal-db", Mandatory)]
        Layer = Some 1
    }

    /// Observability container - Layer 2 (depends on app)
    let makeObsContainer () : ContainerDef = {
        Name = "indrajaal-obs"
        Image = "localhost/indrajaal-obs:nixos"
        DependsOn = ["indrajaal-app"]
        DependencyTypes = Map.ofList [("indrajaal-app", Optional)]
        Layer = Some 2
    }

    /// Container A in a cycle (a -> b)
    let makeCyclicContainerA () : ContainerDef = {
        Name = "container-a"
        Image = "localhost/container-a:nixos"
        DependsOn = ["container-b"]
        DependencyTypes = Map.ofList [("container-b", Mandatory)]
        Layer = None
    }

    /// Container B in a cycle (b -> c)
    let makeCyclicContainerB () : ContainerDef = {
        Name = "container-b"
        Image = "localhost/container-b:nixos"
        DependsOn = ["container-c"]
        DependencyTypes = Map.ofList [("container-c", Mandatory)]
        Layer = None
    }

    /// Container C in a cycle (c -> a) - completes the cycle
    let makeCyclicContainerC () : ContainerDef = {
        Name = "container-c"
        Image = "localhost/container-c:nixos"
        DependsOn = ["container-a"]
        DependencyTypes = Map.ofList [("container-a", Mandatory)]
        Layer = None
    }

    /// Isolated container - no dependencies
    let makeIsolatedContainer () : ContainerDef = {
        Name = "isolated"
        Image = "localhost/isolated:nixos"
        DependsOn = []
        DependencyTypes = Map.empty
        Layer = None
    }

    /// Multi-dependency container - depends on db and cache
    let makeMultiDepContainer () : ContainerDef = {
        Name = "multi-dep"
        Image = "localhost/multi-dep:nixos"
        DependsOn = ["indrajaal-db"; "cache"]
        DependencyTypes = Map.ofList [
            ("indrajaal-db", Mandatory)
            ("cache", Optional)
        ]
        Layer = None
    }

    /// Cache container - no dependencies
    let makeCacheContainer () : ContainerDef = {
        Name = "cache"
        Image = "localhost/cache:nixos"
        DependsOn = []
        DependencyTypes = Map.empty
        Layer = None
    }

    /// Build standard 3-container chain DAG (db -> app -> obs)
    let makeStandardChainDAG () : ServiceDAG =
        let containers = [
            makeDbContainer ()
            makeAppContainer ()
            makeObsContainer ()
        ]
        buildDAG containers

    /// Build cyclic DAG (a -> b -> c -> a)
    let makeCyclicDAG () : ServiceDAG =
        let containers = [
            makeCyclicContainerA ()
            makeCyclicContainerB ()
            makeCyclicContainerC ()
        ]
        buildDAG containers

    /// Build complex multi-layer DAG
    let makeComplexDAG () : ServiceDAG =
        let containers = [
            makeDbContainer ()
            makeCacheContainer ()
            makeMultiDepContainer ()
            makeAppContainer ()
            makeObsContainer ()
        ]
        buildDAG containers

    // ========================================================================
    // DAG CONSTRUCTION TESTS
    // ========================================================================

    [<Fact>]
    let ``buildDAG creates valid DAG from containers`` () =
        // Arrange
        let containers = [
            makeDbContainer ()
            makeAppContainer ()
            makeObsContainer ()
        ]

        // Act
        let dag = buildDAG containers

        // Assert
        Assert.Equal(3, nodeCount dag)
        Assert.True(hasNode "indrajaal-db" dag)
        Assert.True(hasNode "indrajaal-app" dag)
        Assert.True(hasNode "indrajaal-obs" dag)

    [<Fact>]
    let ``buildDAG calculates correct edge count`` () =
        // Arrange & Act
        let dag = makeStandardChainDAG ()

        // Assert - db->app and app->obs = 2 edges
        Assert.Equal(2, edgeCount dag)

    [<Fact>]
    let ``addNode adds new node to existing DAG`` () =
        // Arrange
        let dag = makeStandardChainDAG ()
        let newContainer = makeCacheContainer ()

        // Act
        let updatedDag = addNode newContainer dag

        // Assert
        Assert.Equal(4, nodeCount updatedDag)
        Assert.True(hasNode "cache" updatedDag)

    [<Fact>]
    let ``addNode preserves existing nodes`` () =
        // Arrange
        let dag = makeStandardChainDAG ()
        let newContainer = makeCacheContainer ()

        // Act
        let updatedDag = addNode newContainer dag

        // Assert
        Assert.True(hasNode "indrajaal-db" updatedDag)
        Assert.True(hasNode "indrajaal-app" updatedDag)
        Assert.True(hasNode "indrajaal-obs" updatedDag)

    [<Fact>]
    let ``removeNode removes node from DAG`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let updatedDag = removeNode "indrajaal-obs" dag

        // Assert
        Assert.Equal(2, nodeCount updatedDag)
        Assert.False(hasNode "indrajaal-obs" updatedDag)

    [<Fact>]
    let ``removeNode removes associated edges`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let updatedDag = removeNode "indrajaal-app" dag

        // Assert
        Assert.Equal(0, edgeCount updatedDag)

    [<Fact>]
    let ``empty creates DAG with no nodes`` () =
        // Act
        let dag = empty

        // Assert
        Assert.Equal(0, nodeCount dag)
        Assert.Equal(0, edgeCount dag)
        Assert.True(dag.IsValid)

    // ========================================================================
    // CYCLE DETECTION TESTS
    // ========================================================================

    [<Fact>]
    let ``detectCycles returns NoCycle for valid DAG`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = detectCycles dag

        // Assert
        Assert.Equal(NoCycle, result)

    [<Fact>]
    let ``detectCycles detects cycle a -> b -> c -> a`` () =
        // Arrange
        let dag = makeCyclicDAG ()

        // Act
        let result = detectCycles dag

        // Assert
        match result with
        | NoCycle -> Assert.Fail("Expected CycleDetected, got NoCycle")
        | CycleDetected nodes ->
            Assert.True(nodes.Length > 0)
            Assert.Contains("container-a", nodes)
            Assert.Contains("container-b", nodes)
            Assert.Contains("container-c", nodes)

    [<Fact>]
    let ``hasCycles returns false for acyclic DAG`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = hasCycles dag

        // Assert
        Assert.False(result)

    [<Fact>]
    let ``hasCycles returns true for cyclic DAG`` () =
        // Arrange
        let dag = makeCyclicDAG ()

        // Act
        let result = hasCycles dag

        // Assert
        Assert.True(result)

    [<Fact>]
    let ``detectCycles returns NoCycle for empty DAG`` () =
        // Act
        let result = detectCycles empty

        // Assert
        Assert.Equal(NoCycle, result)

    [<Fact>]
    let ``detectCycles returns NoCycle for single node`` () =
        // Arrange
        let dag = buildDAG [makeDbContainer ()]

        // Act
        let result = detectCycles dag

        // Assert
        Assert.Equal(NoCycle, result)

    // ========================================================================
    // TOPOLOGICAL SORT TESTS
    // ========================================================================

    [<Fact>]
    let ``topologicalSort returns correct order for chain`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = topologicalSort dag

        // Assert
        match result with
        | Error msg -> Assert.Fail($"Expected Ok, got Error: {msg}")
        | Ok order ->
            Assert.Equal(3, order.Length)
            // db must come before app, app must come before obs
            let dbIdx = List.findIndex ((=) "indrajaal-db") order
            let appIdx = List.findIndex ((=) "indrajaal-app") order
            let obsIdx = List.findIndex ((=) "indrajaal-obs") order
            Assert.True(dbIdx < appIdx, "db should come before app")
            Assert.True(appIdx < obsIdx, "app should come before obs")

    [<Fact>]
    let ``topologicalSort returns Error for cyclic DAG`` () =
        // Arrange
        let dag = makeCyclicDAG ()

        // Act
        let result = topologicalSort dag

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error msg -> Assert.Contains("Cycle", msg)

    [<Fact>]
    let ``getBootOrder returns correct order`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let order = getBootOrder dag

        // Assert
        Assert.Equal(3, order.Length)

    [<Fact>]
    let ``getBootOrder returns empty for cyclic DAG`` () =
        // Arrange
        let dag = makeCyclicDAG ()

        // Act
        let order = getBootOrder dag

        // Assert
        Assert.Empty(order)

    [<Fact>]
    let ``topologicalSort handles complex multi-dependency DAG`` () =
        // Arrange
        let dag = makeComplexDAG ()

        // Act
        let result = topologicalSort dag

        // Assert
        match result with
        | Error msg -> Assert.Fail($"Expected Ok, got Error: {msg}")
        | Ok order ->
            Assert.Equal(5, order.Length)
            // db and cache must come before multi-dep
            let dbIdx = List.findIndex ((=) "indrajaal-db") order
            let cacheIdx = List.findIndex ((=) "cache") order
            let multiIdx = List.findIndex ((=) "multi-dep") order
            Assert.True(dbIdx < multiIdx, "db should come before multi-dep")
            Assert.True(cacheIdx < multiIdx, "cache should come before multi-dep")

    // ========================================================================
    // LAYER ASSIGNMENT TESTS
    // ========================================================================

    [<Fact>]
    let ``assignLayers assigns layer 0 to nodes with no dependencies`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let layeredDag = assignLayers dag

        // Assert
        let dbNode = getNode "indrajaal-db" layeredDag
        match dbNode with
        | None -> Assert.Fail("db node not found")
        | Some node -> Assert.Equal(0, node.Layer)

    [<Fact>]
    let ``assignLayers assigns increasing layers for chain`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let layeredDag = assignLayers dag

        // Assert
        let dbLayer = (getNode "indrajaal-db" layeredDag).Value.Layer
        let appLayer = (getNode "indrajaal-app" layeredDag).Value.Layer
        let obsLayer = (getNode "indrajaal-obs" layeredDag).Value.Layer

        Assert.Equal(0, dbLayer)
        Assert.Equal(1, appLayer)
        Assert.Equal(2, obsLayer)

    [<Fact>]
    let ``getNodesAtLayer returns correct nodes`` () =
        // Arrange
        let dag = assignLayers (makeStandardChainDAG ())

        // Act
        let layer0Nodes = getNodesAtLayer 0 dag
        let layer1Nodes = getNodesAtLayer 1 dag
        let layer2Nodes = getNodesAtLayer 2 dag

        // Assert
        Assert.Contains("indrajaal-db", layer0Nodes)
        Assert.Contains("indrajaal-app", layer1Nodes)
        Assert.Contains("indrajaal-obs", layer2Nodes)

    [<Fact>]
    let ``getNodesAtLayer returns empty for non-existent layer`` () =
        // Arrange
        let dag = assignLayers (makeStandardChainDAG ())

        // Act
        let result = getNodesAtLayer 99 dag

        // Assert
        Assert.Empty(result)

    [<Fact>]
    let ``getMaxLayer returns correct max layer`` () =
        // Arrange
        let dag = assignLayers (makeStandardChainDAG ())

        // Act
        let maxLayer = getMaxLayer dag

        // Assert
        Assert.Equal(2, maxLayer)

    [<Fact>]
    let ``getMaxLayer returns 0 for empty DAG`` () =
        // Act
        let maxLayer = getMaxLayer empty

        // Assert
        Assert.Equal(0, maxLayer)

    [<Fact>]
    let ``assignLayers sets IsValid to false for cyclic DAG`` () =
        // Arrange
        let dag = makeCyclicDAG ()

        // Act
        let layeredDag = assignLayers dag

        // Assert
        Assert.False(layeredDag.IsValid)

    [<Theory>]
    [<InlineData(0, 1)>]  // Layer 0 should have 1 node (db)
    [<InlineData(1, 1)>]  // Layer 1 should have 1 node (app)
    [<InlineData(2, 1)>]  // Layer 2 should have 1 node (obs)
    let ``layer contains expected number of nodes`` (layer: int) (expectedCount: int) =
        // Arrange
        let dag = assignLayers (makeStandardChainDAG ())

        // Act
        let nodes = getNodesAtLayer layer dag

        // Assert
        Assert.Equal(expectedCount, nodes.Length)

    // ========================================================================
    // DEPENDENCY RESOLUTION TESTS
    // ========================================================================

    [<Fact>]
    let ``getDependencies returns direct dependencies`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let deps = getDependencies "indrajaal-app" dag

        // Assert
        Assert.Single(deps) |> ignore
        Assert.Contains("indrajaal-db", deps)

    [<Fact>]
    let ``getDependencies returns empty for node with no dependencies`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let deps = getDependencies "indrajaal-db" dag

        // Assert
        Assert.Empty(deps)

    [<Fact>]
    let ``getDependencies returns empty for non-existent node`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let deps = getDependencies "non-existent" dag

        // Assert
        Assert.Empty(deps)

    [<Fact>]
    let ``getDependents returns nodes that depend on this node`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let dependents = getDependents "indrajaal-db" dag

        // Assert
        Assert.Single(dependents) |> ignore
        Assert.Contains("indrajaal-app", dependents)

    [<Fact>]
    let ``getDependents returns empty for leaf node`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let dependents = getDependents "indrajaal-obs" dag

        // Assert
        Assert.Empty(dependents)

    [<Fact>]
    let ``getTransitiveDependencies returns all dependencies`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let deps = getTransitiveDependencies "indrajaal-obs" dag

        // Assert
        Assert.Equal(2, deps.Length)
        Assert.Contains("indrajaal-app", deps)
        Assert.Contains("indrajaal-db", deps)

    [<Fact>]
    let ``getTransitiveDependencies returns empty for root node`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let deps = getTransitiveDependencies "indrajaal-db" dag

        // Assert
        Assert.Empty(deps)

    [<Fact>]
    let ``dependsOn returns true for direct dependency`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = dependsOn "indrajaal-app" "indrajaal-db" dag

        // Assert
        Assert.True(result)

    [<Fact>]
    let ``dependsOn returns true for transitive dependency`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = dependsOn "indrajaal-obs" "indrajaal-db" dag

        // Assert
        Assert.True(result)

    [<Fact>]
    let ``dependsOn returns false when no dependency exists`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = dependsOn "indrajaal-db" "indrajaal-obs" dag

        // Assert
        Assert.False(result)

    [<Fact>]
    let ``getDependencyType returns correct type for Mandatory`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = getDependencyType "indrajaal-db" "indrajaal-app" dag

        // Assert
        Assert.Equal(Some Mandatory, result)

    [<Fact>]
    let ``getDependencyType returns correct type for Optional`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = getDependencyType "indrajaal-app" "indrajaal-obs" dag

        // Assert
        Assert.Equal(Some Optional, result)

    [<Fact>]
    let ``getDependencyType returns None for non-existent edge`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = getDependencyType "indrajaal-obs" "indrajaal-db" dag

        // Assert
        Assert.Equal(None, result)

    // ========================================================================
    // BOOT SEQUENCE CALCULATION TESTS
    // ========================================================================

    [<Fact>]
    let ``calculateBootSequence returns correct order`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let sequence = calculateBootSequence dag

        // Assert
        Assert.Equal(3, sequence.Order.Length)
        Assert.True(sequence.EstimatedTimeMs > 0L)

    [<Fact>]
    let ``calculateBootSequence populates layers`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let sequence = calculateBootSequence dag

        // Assert
        Assert.True(sequence.Layers.Count > 0)

    [<Fact>]
    let ``calculateBootSequence returns empty for cyclic DAG`` () =
        // Arrange
        let dag = makeCyclicDAG ()

        // Act
        let sequence = calculateBootSequence dag

        // Assert
        Assert.Empty(sequence.Order)
        Assert.Equal(0L, sequence.EstimatedTimeMs)

    [<Fact>]
    let ``getReadyToStart returns nodes with all deps started`` () =
        // Arrange
        let dag = makeStandardChainDAG ()
        let startedNodes = Set.ofList ["indrajaal-db"]

        // Act
        let ready = getReadyToStart startedNodes dag

        // Assert
        Assert.Contains("indrajaal-app", ready)
        Assert.DoesNotContain("indrajaal-obs", ready)

    [<Fact>]
    let ``getReadyToStart returns root nodes when nothing started`` () =
        // Arrange
        let dag = makeStandardChainDAG ()
        let startedNodes = Set.empty

        // Act
        let ready = getReadyToStart startedNodes dag

        // Assert
        Assert.Single(ready) |> ignore
        Assert.Contains("indrajaal-db", ready)

    [<Fact>]
    let ``getReadyToStart returns empty when all started`` () =
        // Arrange
        let dag = makeStandardChainDAG ()
        let startedNodes = Set.ofList ["indrajaal-db"; "indrajaal-app"; "indrajaal-obs"]

        // Act
        let ready = getReadyToStart startedNodes dag

        // Assert
        Assert.Empty(ready)

    [<Fact>]
    let ``getMustStartBefore returns transitive dependencies`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let before = getMustStartBefore "indrajaal-obs" dag

        // Assert
        Assert.Equal(2, before.Length)
        Assert.Contains("indrajaal-app", before)
        Assert.Contains("indrajaal-db", before)

    [<Fact>]
    let ``getMustStartAfter returns transitive dependents`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let after = getMustStartAfter "indrajaal-db" dag

        // Assert
        Assert.Equal(2, after.Length)
        Assert.Contains("indrajaal-app", after)
        Assert.Contains("indrajaal-obs", after)

    // ========================================================================
    // HEALTH STATE MANAGEMENT TESTS
    // ========================================================================

    [<Fact>]
    let ``updateHealthState updates node state`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let updatedDag = updateHealthState "indrajaal-db" Healthy dag

        // Assert
        let state = getHealthState "indrajaal-db" updatedDag
        Assert.Equal(Some Healthy, state)

    [<Fact>]
    let ``updateHealthState preserves other nodes`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let updatedDag = updateHealthState "indrajaal-db" Healthy dag

        // Assert
        let appState = getHealthState "indrajaal-app" updatedDag
        Assert.Equal(Some Absent, appState)

    [<Fact>]
    let ``updateHealthState returns unchanged DAG for non-existent node`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let updatedDag = updateHealthState "non-existent" Healthy dag

        // Assert
        Assert.Equal(nodeCount dag, nodeCount updatedDag)

    [<Fact>]
    let ``getHealthState returns None for non-existent node`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let state = getHealthState "non-existent" dag

        // Assert
        Assert.Equal(None, state)

    [<Theory>]
    [<InlineData("Absent")>]
    [<InlineData("Created")>]
    [<InlineData("Starting")>]
    [<InlineData("Healthy")>]
    [<InlineData("Degraded")>]
    [<InlineData("Failed")>]
    let ``updateHealthState handles all health states`` (stateStr: string) =
        // Arrange
        let dag = makeStandardChainDAG ()
        let state =
            match stateStr with
            | "Absent" -> Absent
            | "Created" -> Created
            | "Starting" -> Starting
            | "Healthy" -> Healthy
            | "Degraded" -> Degraded
            | "Failed" -> Failed
            | _ -> Absent

        // Act
        let updatedDag = updateHealthState "indrajaal-db" state dag

        // Assert
        let result = getHealthState "indrajaal-db" updatedDag
        Assert.Equal(Some state, result)

    [<Fact>]
    let ``areMandatoryDepsHealthy returns true when deps are healthy`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Healthy

        // Act
        let result = areMandatoryDepsHealthy "indrajaal-app" dag

        // Assert
        Assert.True(result)

    [<Fact>]
    let ``areMandatoryDepsHealthy returns false when deps are not healthy`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Failed

        // Act
        let result = areMandatoryDepsHealthy "indrajaal-app" dag

        // Assert
        Assert.False(result)

    [<Fact>]
    let ``areMandatoryDepsHealthy ignores optional dependencies`` () =
        // Arrange - obs depends on app with Optional type
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-app" Failed  // Optional dep is failed

        // Act
        let result = areMandatoryDepsHealthy "indrajaal-obs" dag

        // Assert - should still be true because the dep is optional
        Assert.True(result)

    [<Fact>]
    let ``areMandatoryDepsHealthy returns true for node with no dependencies`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = areMandatoryDepsHealthy "indrajaal-db" dag

        // Assert
        Assert.True(result)

    [<Fact>]
    let ``areMandatoryDepsHealthy returns false for non-existent node`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = areMandatoryDepsHealthy "non-existent" dag

        // Assert
        Assert.False(result)

    [<Fact>]
    let ``getHealthyNodes returns all healthy nodes`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Healthy
            |> updateHealthState "indrajaal-app" Healthy

        // Act
        let healthy = getHealthyNodes dag

        // Assert
        Assert.Equal(2, healthy.Length)
        Assert.Contains("indrajaal-db", healthy)
        Assert.Contains("indrajaal-app", healthy)

    [<Fact>]
    let ``getHealthyNodes returns empty when no healthy nodes`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let healthy = getHealthyNodes dag

        // Assert
        Assert.Empty(healthy)

    [<Fact>]
    let ``getFailedNodes returns all failed nodes`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Failed
            |> updateHealthState "indrajaal-obs" Failed

        // Act
        let failed = getFailedNodes dag

        // Assert
        Assert.Equal(2, failed.Length)
        Assert.Contains("indrajaal-db", failed)
        Assert.Contains("indrajaal-obs", failed)

    [<Fact>]
    let ``getFailedNodes returns empty when no failed nodes`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let failed = getFailedNodes dag

        // Assert
        Assert.Empty(failed)

    // ========================================================================
    // VALIDATION TESTS
    // ========================================================================

    [<Fact>]
    let ``validate returns Ok for valid DAG`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = validate dag

        // Assert
        match result with
        | Error errs ->
            let errMsg = String.concat "; " errs
            Assert.Fail(sprintf "Expected Ok, got Error: %s" errMsg)
        | Ok validatedDag ->
            Assert.True(validatedDag.IsValid)

    [<Fact>]
    let ``validate returns Error for cyclic DAG`` () =
        // Arrange
        let dag = makeCyclicDAG ()

        // Act
        let result = validate dag

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error errors ->
            Assert.True(errors.Length > 0)
            Assert.True(errors |> List.exists (fun e -> e.Contains("Circular") || e.Contains("cycle")))

    [<Fact>]
    let ``validate detects missing dependencies`` () =
        // Arrange
        let containerWithMissingDep : ContainerDef = {
            Name = "orphan"
            Image = "localhost/orphan:nixos"
            DependsOn = ["non-existent-container"]
            DependencyTypes = Map.empty
            Layer = None
        }
        let dag = buildDAG [containerWithMissingDep]

        // Act
        let result = validate dag

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error errors ->
            Assert.True(errors.Length > 0)
            Assert.True(errors |> List.exists (fun e -> e.Contains("non-existent")))

    [<Fact>]
    let ``validate detects self-dependencies`` () =
        // Arrange
        let selfDepContainer : ContainerDef = {
            Name = "self-dep"
            Image = "localhost/self-dep:nixos"
            DependsOn = ["self-dep"]
            DependencyTypes = Map.empty
            Layer = None
        }
        let dag = buildDAG [selfDepContainer]

        // Act
        let result = validate dag

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error errors ->
            Assert.True(errors.Length > 0)
            Assert.True(errors |> List.exists (fun e -> e.Contains("itself")))

    [<Fact>]
    let ``validate assigns layers on success`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = validate dag

        // Assert
        match result with
        | Error errs ->
            let errMsg = String.concat "; " errs
            Assert.Fail(sprintf "Expected Ok, got Error: %s" errMsg)
        | Ok validatedDag ->
            Assert.True(validatedDag.Layers.Count > 0)

    // ========================================================================
    // QUERY TESTS
    // ========================================================================

    [<Fact>]
    let ``hasNode returns true for existing node`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act & Assert
        Assert.True(hasNode "indrajaal-db" dag)
        Assert.True(hasNode "indrajaal-app" dag)
        Assert.True(hasNode "indrajaal-obs" dag)

    [<Fact>]
    let ``hasNode returns false for non-existing node`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act & Assert
        Assert.False(hasNode "non-existent" dag)

    [<Fact>]
    let ``getAllNodeIds returns all node IDs`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let ids = getAllNodeIds dag

        // Assert
        Assert.Equal(3, ids.Length)
        Assert.Contains("indrajaal-db", ids)
        Assert.Contains("indrajaal-app", ids)
        Assert.Contains("indrajaal-obs", ids)

    [<Fact>]
    let ``getNode returns Some for existing node`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = getNode "indrajaal-db" dag

        // Assert
        Assert.True(result.IsSome)
        Assert.Equal("indrajaal-db", result.Value.Id)

    [<Fact>]
    let ``getNode returns None for non-existing node`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = getNode "non-existent" dag

        // Assert
        Assert.True(result.IsNone)

    [<Fact>]
    let ``nodeCount returns correct count`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act & Assert
        Assert.Equal(3, nodeCount dag)

    [<Fact>]
    let ``edgeCount returns correct count`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act & Assert
        Assert.Equal(2, edgeCount dag)

    // ========================================================================
    // EDGE CASE TESTS
    // ========================================================================

    [<Fact>]
    let ``empty DAG has no cycles`` () =
        // Assert
        Assert.False(hasCycles empty)

    [<Fact>]
    let ``empty DAG validates successfully`` () =
        // Act
        let result = validate empty

        // Assert
        match result with
        | Error _ -> Assert.Fail("Expected Ok")
        | Ok dag -> Assert.True(dag.IsValid)

    [<Fact>]
    let ``single node DAG validates successfully`` () =
        // Arrange
        let dag = buildDAG [makeDbContainer ()]

        // Act
        let result = validate dag

        // Assert
        match result with
        | Error _ -> Assert.Fail("Expected Ok")
        | Ok validatedDag -> Assert.True(validatedDag.IsValid)

    [<Fact>]
    let ``formatAsText returns non-empty string`` () =
        // Arrange
        let dag = assignLayers (makeStandardChainDAG ())

        // Act
        let text = formatAsText dag

        // Assert
        Assert.False(System.String.IsNullOrEmpty(text))
        Assert.Contains("Service DAG", text)
        Assert.Contains("Nodes:", text)

    [<Fact>]
    let ``formatEdges returns edge descriptions`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let edges = formatEdges dag

        // Assert
        Assert.Equal(2, edges.Length)

    [<Fact>]
    let ``formatEdges includes dependency type`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let edges = formatEdges dag

        // Assert
        Assert.True(edges |> List.exists (fun e -> e.Contains("[M]")))
        Assert.True(edges |> List.exists (fun e -> e.Contains("[O]")))

    // ========================================================================
    // COMPLEX SCENARIO TESTS
    // ========================================================================

    [<Fact>]
    let ``complex DAG with parallel dependencies assigns correct layers`` () =
        // Arrange - db and cache at layer 0, multi-dep at layer 1
        let dag = assignLayers (makeComplexDAG ())

        // Act
        let dbLayer = (getNode "indrajaal-db" dag).Value.Layer
        let cacheLayer = (getNode "cache" dag).Value.Layer
        let multiDepLayer = (getNode "multi-dep" dag).Value.Layer

        // Assert
        Assert.Equal(0, dbLayer)
        Assert.Equal(0, cacheLayer)
        Assert.Equal(1, multiDepLayer)

    [<Fact>]
    let ``getReadyToStart handles parallel container starts`` () =
        // Arrange
        let dag = makeComplexDAG ()
        let startedNodes = Set.empty

        // Act
        let ready = getReadyToStart startedNodes dag

        // Assert - should include both db and cache
        Assert.True(ready.Length >= 2)
        Assert.Contains("indrajaal-db", ready)
        Assert.Contains("cache", ready)

    [<Fact>]
    let ``boot sequence respects all dependencies`` () =
        // Arrange
        let dag = makeComplexDAG ()

        // Act
        let sequence = calculateBootSequence dag

        // Assert
        let dbIdx = List.findIndex ((=) "indrajaal-db") sequence.Order
        let cacheIdx = List.findIndex ((=) "cache") sequence.Order
        let multiIdx = List.findIndex ((=) "multi-dep") sequence.Order

        Assert.True(dbIdx < multiIdx)
        Assert.True(cacheIdx < multiIdx)

    [<Fact>]
    let ``adding duplicate node updates existing`` () =
        // Arrange
        let dag = makeStandardChainDAG ()
        let updatedDb : ContainerDef = {
            Name = "indrajaal-db"
            Image = "localhost/indrajaal-db:updated"
            DependsOn = []
            DependencyTypes = Map.empty
            Layer = None
        }

        // Act
        let updatedDag = addNode updatedDb dag

        // Assert
        Assert.Equal(3, nodeCount updatedDag)
        let node = getNode "indrajaal-db" updatedDag
        Assert.Equal("localhost/indrajaal-db:updated", node.Value.Container.Image)

    [<Fact>]
    let ``getTransitiveDependents handles diamond dependency`` () =
        // Arrange - Create diamond: db -> [app, cache] -> aggregator
        let aggregator : ContainerDef = {
            Name = "aggregator"
            Image = "localhost/aggregator:nixos"
            DependsOn = ["indrajaal-app"; "cache"]
            DependencyTypes = Map.empty
            Layer = None
        }
        let dbDepCache : ContainerDef = {
            Name = "cache"
            Image = "localhost/cache:nixos"
            DependsOn = ["indrajaal-db"]
            DependencyTypes = Map.empty
            Layer = None
        }
        let containers = [
            makeDbContainer ()
            makeAppContainer ()
            dbDepCache
            aggregator
        ]
        let dag = buildDAG containers

        // Act
        let dependents = getTransitiveDependents "indrajaal-db" dag

        // Assert
        Assert.Contains("indrajaal-app", dependents)
        Assert.Contains("cache", dependents)
        Assert.Contains("aggregator", dependents)
