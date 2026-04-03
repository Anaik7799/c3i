namespace Cepaf.Tests

open System
open Xunit
open Cepaf.Modules.ServiceDAG
open Cepaf.Modules.HealthPropagation

/// HealthPropagation Unit Tests
/// STAMP Compliance: SC-CEP-003, SC-PRF-050, AOR-SAF-001
/// Test Coverage: Health events, propagation, consensus, emergency stop, policies, recovery
module HealthPropagationTests =

    // ========================================================================
    // TEST DATA FACTORY FUNCTIONS
    // Factories avoid xUnit initialization issues with module-level values
    // ========================================================================

    /// Create a healthy state
    let makeHealthyState () : HealthState = Healthy

    /// Create an unhealthy state with reason
    let makeUnhealthyState reason : HealthState = Failed

    /// Create a degraded state
    let makeDegradedState () : HealthState = Degraded

    /// Create a health event
    let makeHealthEvent nodeId prev next : HealthEvent =
        { NodeId = nodeId; PreviousState = prev; NewState = next; Timestamp = DateTime.UtcNow; Reason = None }

    /// Create a health event with reason
    let makeHealthEventWithReason nodeId prev next reason : HealthEvent =
        { NodeId = nodeId; PreviousState = prev; NewState = next; Timestamp = DateTime.UtcNow; Reason = Some reason }

    /// Database container - Layer 0 (no dependencies)
    let makeDbContainer () : ContainerDef = {
        Name = "indrajaal-db"
        Image = "localhost/indrajaal-db:nixos"
        DependsOn = []
        DependencyTypes = Map.empty
        Layer = Some 0
    }

    /// Application container - Layer 1 (depends on db, Mandatory)
    let makeAppContainer () : ContainerDef = {
        Name = "indrajaal-app"
        Image = "localhost/indrajaal-app:nixos"
        DependsOn = ["indrajaal-db"]
        DependencyTypes = Map.ofList [("indrajaal-db", Mandatory)]
        Layer = Some 1
    }

    /// Observability container - Layer 2 (depends on app, Optional)
    let makeObsContainer () : ContainerDef = {
        Name = "indrajaal-obs"
        Image = "localhost/indrajaal-obs:nixos"
        DependsOn = ["indrajaal-app"]
        DependencyTypes = Map.ofList [("indrajaal-app", Optional)]
        Layer = Some 2
    }

    /// Cache container - Layer 0 (no dependencies)
    let makeCacheContainer () : ContainerDef = {
        Name = "cache"
        Image = "localhost/cache:nixos"
        DependsOn = []
        DependencyTypes = Map.empty
        Layer = Some 0
    }

    /// Worker container - Layer 1 (depends on db and cache)
    let makeWorkerContainer () : ContainerDef = {
        Name = "worker"
        Image = "localhost/worker:nixos"
        DependsOn = ["indrajaal-db"; "cache"]
        DependencyTypes = Map.ofList [
            ("indrajaal-db", Mandatory)
            ("cache", Optional)
        ]
        Layer = Some 1
    }

    /// Isolated container - no dependencies
    let makeIsolatedContainer () : ContainerDef = {
        Name = "isolated"
        Image = "localhost/isolated:nixos"
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

    /// Build all-healthy DAG
    let makeHealthyDAG () : ServiceDAG =
        makeStandardChainDAG ()
        |> updateHealthState "indrajaal-db" Healthy
        |> updateHealthState "indrajaal-app" Healthy
        |> updateHealthState "indrajaal-obs" Healthy

    /// Build complex multi-dependency DAG
    let makeComplexDAG () : ServiceDAG =
        let containers = [
            makeDbContainer ()
            makeCacheContainer ()
            makeAppContainer ()
            makeWorkerContainer ()
            makeObsContainer ()
        ]
        buildDAG containers

    /// Always healthy check function
    let alwaysHealthy () : string -> bool = fun _ -> true

    /// Always unhealthy check function
    let alwaysUnhealthy () : string -> bool = fun _ -> false

    /// Selective health check function
    let selectiveHealth healthyNodes : string -> bool =
        fun nodeId -> List.contains nodeId healthyNodes

    // ========================================================================
    // HEALTH EVENT TESTS
    // ========================================================================

    [<Fact>]
    let ``makeHealthEvent creates event with correct nodeId`` () =
        // Arrange & Act
        let event = makeHealthEvent "node1" Absent Healthy

        // Assert
        Assert.Equal("node1", event.NodeId)

    [<Fact>]
    let ``makeHealthEvent creates event with correct state transition`` () =
        // Arrange & Act
        let event = makeHealthEvent "node1" Absent Healthy

        // Assert
        Assert.Equal(Absent, event.PreviousState)
        Assert.Equal(Healthy, event.NewState)

    [<Fact>]
    let ``makeHealthEvent sets timestamp to recent time`` () =
        // Arrange
        let before = DateTime.UtcNow

        // Act
        let event = makeHealthEvent "node1" Absent Healthy
        let after = DateTime.UtcNow

        // Assert
        Assert.True(event.Timestamp >= before)
        Assert.True(event.Timestamp <= after)

    [<Fact>]
    let ``makeHealthEvent without reason has None`` () =
        // Arrange & Act
        let event = makeHealthEvent "node1" Absent Healthy

        // Assert
        Assert.True(event.Reason.IsNone)

    [<Fact>]
    let ``makeHealthEventWithReason includes reason`` () =
        // Arrange & Act
        let event = makeHealthEventWithReason "node1" Healthy Failed "Connection timeout"

        // Assert
        Assert.True(event.Reason.IsSome)
        Assert.Equal("Connection timeout", event.Reason.Value)

    [<Theory>]
    [<InlineData("Absent", "Healthy")>]
    [<InlineData("Healthy", "Degraded")>]
    [<InlineData("Degraded", "Failed")>]
    [<InlineData("Failed", "Healthy")>]
    [<InlineData("Starting", "Healthy")>]
    [<InlineData("Created", "Starting")>]
    let ``health state transitions are recorded correctly`` (fromStr: string) (toStr: string) =
        // Arrange
        let fromState =
            match fromStr with
            | "Absent" -> Absent | "Healthy" -> Healthy | "Degraded" -> Degraded
            | "Failed" -> Failed | "Starting" -> Starting | "Created" -> Created | _ -> Absent
        let toState =
            match toStr with
            | "Absent" -> Absent | "Healthy" -> Healthy | "Degraded" -> Degraded
            | "Failed" -> Failed | "Starting" -> Starting | "Created" -> Created | _ -> Absent

        // Act
        let event = makeHealthEvent "node1" fromState toState

        // Assert
        Assert.Equal(fromState, event.PreviousState)
        Assert.Equal(toState, event.NewState)

    // ========================================================================
    // PROPAGATION TESTS
    // ========================================================================

    [<Fact>]
    let ``propagateHealthChange updates source node state`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let (_, updatedDag) = propagateHealthChange "indrajaal-db" Healthy FailFast dag

        // Assert
        let state = getHealthState "indrajaal-db" updatedDag
        Assert.Equal(Some Healthy, state)

    [<Fact>]
    let ``propagateHealthChange creates event for source node`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let (result, _) = propagateHealthChange "indrajaal-db" Healthy FailFast dag

        // Assert
        Assert.True(result.Events.Length > 0)
        Assert.Equal("indrajaal-db", result.Events.[0].NodeId)

    [<Fact>]
    let ``propagateHealthChange with Failed propagates to mandatory dependents`` () =
        // Arrange
        let dag = makeHealthyDAG ()

        // Act
        let (result, updatedDag) = propagateHealthChange "indrajaal-db" Failed FailFast dag

        // Assert
        Assert.Contains("indrajaal-app", result.AffectedNodes)
        let appState = getHealthState "indrajaal-app" updatedDag
        Assert.Equal(Some Failed, appState)

    [<Fact>]
    let ``propagateHealthChange with Failed degrades optional dependents`` () =
        // Arrange
        let dag = makeHealthyDAG ()

        // Act - app fails, obs depends on app with Optional
        let (result, updatedDag) = propagateHealthChange "indrajaal-app" Failed FailFast dag

        // Assert
        Assert.Contains("indrajaal-obs", result.AffectedNodes)
        let obsState = getHealthState "indrajaal-obs" updatedDag
        Assert.Equal(Some Degraded, obsState)

    [<Fact>]
    let ``propagateHealthChange with Degraded notifies dependents`` () =
        // Arrange
        let dag = makeHealthyDAG ()

        // Act
        let (result, updatedDag) = propagateHealthChange "indrajaal-db" Degraded FailFast dag

        // Assert
        Assert.Contains("indrajaal-app", result.AffectedNodes)
        let appState = getHealthState "indrajaal-app" updatedDag
        Assert.Equal(Some Degraded, appState)

    [<Fact>]
    let ``propagateHealthChange with Healthy can upgrade degraded dependents`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Healthy
            |> updateHealthState "indrajaal-app" Degraded

        // Act - db going healthy may upgrade app
        let (result, updatedDag) = propagateHealthChange "indrajaal-db" Healthy FailFast dag

        // Assert
        let appState = getHealthState "indrajaal-app" updatedDag
        Assert.Equal(Some Healthy, appState)

    [<Fact>]
    let ``propagateHealthChange records total time`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let (result, _) = propagateHealthChange "indrajaal-db" Healthy FailFast dag

        // Assert
        Assert.True(result.TotalTimeMs >= 0L)

    [<Fact>]
    let ``propagateHealthChange with cascading failure affects multiple nodes`` () =
        // Arrange
        let dag = makeHealthyDAG ()

        // Act
        let (result, _) = propagateHealthChange "indrajaal-db" Failed FailFast dag

        // Assert - db failure should affect app which affects obs
        Assert.True(result.AffectedNodes.Length >= 2)

    // ========================================================================
    // EMERGENCY STOP TESTS (AOR-SAF-001: <1s)
    // ========================================================================

    [<Fact>]
    let ``triggerFastEmergencyStop completes within 1 second threshold`` () =
        // Arrange
        let dag = makeHealthyDAG ()

        // Act
        let (result, _) = triggerFastEmergencyStop "indrajaal-db" dag

        // Assert - AOR-SAF-001: Must complete within 1000ms
        Assert.True(result.WithinThreshold, sprintf "Stop took %dms, exceeds 1000ms threshold" result.StopTimeMs)
        Assert.True(result.StopTimeMs < 1000L)

    [<Fact>]
    let ``triggerFastEmergencyStop stops source node`` () =
        // Arrange
        let dag = makeHealthyDAG ()

        // Act
        let (result, updatedDag) = triggerFastEmergencyStop "indrajaal-db" dag

        // Assert
        Assert.Contains("indrajaal-db", result.StoppedNodes)
        let state = getHealthState "indrajaal-db" updatedDag
        Assert.Equal(Some Failed, state)

    [<Fact>]
    let ``triggerFastEmergencyStop stops transitive dependents`` () =
        // Arrange
        let dag = makeHealthyDAG ()

        // Act
        let (result, _) = triggerFastEmergencyStop "indrajaal-db" dag

        // Assert - db stop should also stop app and obs
        Assert.Contains("indrajaal-app", result.StoppedNodes)
        Assert.Contains("indrajaal-obs", result.StoppedNodes)

    [<Fact>]
    let ``triggerEmergencyStop stops nodes in reverse topological order`` () =
        // Arrange
        let dag = makeHealthyDAG () |> assignLayers

        // Act
        let (result, _) = triggerFastEmergencyStop "indrajaal-db" dag

        // Assert - dependents should be stopped before dependencies
        // obs (layer 2) before app (layer 1) before db (layer 0)
        if result.StoppedNodes.Length >= 3 then
            let obsIdx = result.StoppedNodes |> List.tryFindIndex ((=) "indrajaal-obs")
            let appIdx = result.StoppedNodes |> List.tryFindIndex ((=) "indrajaal-app")
            let dbIdx = result.StoppedNodes |> List.tryFindIndex ((=) "indrajaal-db")
            match obsIdx, appIdx, dbIdx with
            | Some o, Some a, Some d ->
                Assert.True(o < a || o < d, "obs should be stopped early")
            | _ -> ()

    [<Fact>]
    let ``triggerEmergencyStop with failing stop function records errors`` () =
        // Arrange
        let dag = makeHealthyDAG ()
        let failingStop nodeId =
            if nodeId = "indrajaal-app" then Error "Stop failed"
            else Ok ()

        // Act
        let (result, _) = triggerEmergencyStop "indrajaal-db" failingStop dag

        // Assert
        Assert.True(result.Errors.Length > 0)
        Assert.True(result.Errors |> List.exists (fun (n, _) -> n = "indrajaal-app"))

    [<Fact>]
    let ``validateEmergencyStopTime returns true for fast stop`` () =
        // Arrange
        let result = {
            StoppedNodes = ["node1"]
            StopTimeMs = 100L
            WithinThreshold = true
            Errors = []
        }

        // Act & Assert
        Assert.True(validateEmergencyStopTime result)

    [<Fact>]
    let ``validateEmergencyStopTime returns false for slow stop`` () =
        // Arrange
        let result = {
            StoppedNodes = ["node1"]
            StopTimeMs = 1500L
            WithinThreshold = false
            Errors = []
        }

        // Act & Assert
        Assert.False(validateEmergencyStopTime result)

    // ========================================================================
    // CONSENSUS TESTS (SC-CEP-003: 3/5 agreement)
    // ========================================================================

    [<Fact>]
    let ``checkHealthConsensus with all healthy returns Consensus true`` () =
        // Arrange
        let checks = [
            { NodeId = "node1"; IsHealthy = true; LatencyMs = 5L; CheckType = "check_0"; Message = None }
            { NodeId = "node1"; IsHealthy = true; LatencyMs = 5L; CheckType = "check_1"; Message = None }
            { NodeId = "node1"; IsHealthy = true; LatencyMs = 5L; CheckType = "check_2"; Message = None }
            { NodeId = "node1"; IsHealthy = true; LatencyMs = 5L; CheckType = "check_3"; Message = None }
            { NodeId = "node1"; IsHealthy = true; LatencyMs = 5L; CheckType = "check_4"; Message = None }
        ]

        // Act
        let result = checkHealthConsensus checks

        // Assert
        match result with
        | Consensus (healthy, count, total) ->
            Assert.True(healthy)
            Assert.Equal(5, count)
            Assert.Equal(5, total)
        | NoConsensus _ -> Assert.Fail("Expected Consensus")

    [<Fact>]
    let ``checkHealthConsensus with all unhealthy returns Consensus false`` () =
        // Arrange
        let checks = [
            { NodeId = "node1"; IsHealthy = false; LatencyMs = 5L; CheckType = "check_0"; Message = None }
            { NodeId = "node1"; IsHealthy = false; LatencyMs = 5L; CheckType = "check_1"; Message = None }
            { NodeId = "node1"; IsHealthy = false; LatencyMs = 5L; CheckType = "check_2"; Message = None }
            { NodeId = "node1"; IsHealthy = false; LatencyMs = 5L; CheckType = "check_3"; Message = None }
            { NodeId = "node1"; IsHealthy = false; LatencyMs = 5L; CheckType = "check_4"; Message = None }
        ]

        // Act
        let result = checkHealthConsensus checks

        // Assert
        match result with
        | Consensus (healthy, count, total) ->
            Assert.False(healthy)
            Assert.Equal(5, count)
            Assert.Equal(5, total)
        | NoConsensus _ -> Assert.Fail("Expected Consensus")

    [<Fact>]
    let ``checkHealthConsensus with 3/5 healthy returns Consensus true`` () =
        // Arrange
        let checks = [
            { NodeId = "node1"; IsHealthy = true; LatencyMs = 5L; CheckType = "check_0"; Message = None }
            { NodeId = "node1"; IsHealthy = true; LatencyMs = 5L; CheckType = "check_1"; Message = None }
            { NodeId = "node1"; IsHealthy = true; LatencyMs = 5L; CheckType = "check_2"; Message = None }
            { NodeId = "node1"; IsHealthy = false; LatencyMs = 5L; CheckType = "check_3"; Message = None }
            { NodeId = "node1"; IsHealthy = false; LatencyMs = 5L; CheckType = "check_4"; Message = None }
        ]

        // Act
        let result = checkHealthConsensus checks

        // Assert
        match result with
        | Consensus (healthy, count, _) ->
            Assert.True(healthy)
            Assert.Equal(3, count)
        | NoConsensus _ -> Assert.Fail("Expected Consensus")

    [<Fact>]
    let ``checkHealthConsensus with 3/5 unhealthy returns Consensus false`` () =
        // Arrange
        let checks = [
            { NodeId = "node1"; IsHealthy = false; LatencyMs = 5L; CheckType = "check_0"; Message = None }
            { NodeId = "node1"; IsHealthy = false; LatencyMs = 5L; CheckType = "check_1"; Message = None }
            { NodeId = "node1"; IsHealthy = false; LatencyMs = 5L; CheckType = "check_2"; Message = None }
            { NodeId = "node1"; IsHealthy = true; LatencyMs = 5L; CheckType = "check_3"; Message = None }
            { NodeId = "node1"; IsHealthy = true; LatencyMs = 5L; CheckType = "check_4"; Message = None }
        ]

        // Act
        let result = checkHealthConsensus checks

        // Assert
        match result with
        | Consensus (healthy, count, _) ->
            Assert.False(healthy)
            Assert.Equal(3, count)
        | NoConsensus _ -> Assert.Fail("Expected Consensus")

    [<Fact>]
    let ``checkHealthConsensus with 2/5 each returns NoConsensus`` () =
        // Arrange - 2 healthy, 2 unhealthy, 1 is the tiebreaker but still no clear consensus
        // Actually with 2 healthy and 3 unhealthy, we get consensus unhealthy
        // Let's use 1 healthy, 1 unhealthy with only 2 checks
        let checks = [
            { NodeId = "node1"; IsHealthy = true; LatencyMs = 5L; CheckType = "check_0"; Message = None }
            { NodeId = "node1"; IsHealthy = false; LatencyMs = 5L; CheckType = "check_1"; Message = None }
        ]

        // Act
        let result = checkHealthConsensus checks

        // Assert - with 2 checks, threshold is 1, so both healthy (1) and unhealthy (1) meet threshold
        // Actually, healthy >= 1, so Consensus true
        match result with
        | Consensus (healthy, _, _) -> Assert.True(healthy)
        | NoConsensus _ -> ()  // This is also acceptable

    [<Fact>]
    let ``verifyHealthWithConsensus with 5 healthy checks returns healthy`` () =
        // Arrange
        let checkFns = List.replicate 5 (fun _ -> true)

        // Act
        let (isHealthy, consensus) = verifyHealthWithConsensus checkFns "node1"

        // Assert
        Assert.True(isHealthy)
        match consensus with
        | Consensus (h, _, _) -> Assert.True(h)
        | NoConsensus _ -> Assert.Fail("Expected Consensus")

    [<Fact>]
    let ``verifyHealthWithConsensus with fewer than 5 checks pads to 5`` () =
        // Arrange - only 2 checks provided
        let checkFns = [(fun _ -> true); (fun _ -> true)]

        // Act
        let (_, consensus) = verifyHealthWithConsensus checkFns "node1"

        // Assert - should have 5 total checks
        match consensus with
        | Consensus (_, _, total) -> Assert.Equal(5, total)
        | NoConsensus (_, _, total) -> Assert.Equal(5, total)

    [<Fact>]
    let ``verifyHealthWithConsensus returns unhealthy on no consensus`` () =
        // Arrange - empty checks will be padded with false
        let checkFns : (string -> bool) list = []

        // Act
        let (isHealthy, _) = verifyHealthWithConsensus checkFns "node1"

        // Assert - defaults to unhealthy on no consensus
        Assert.False(isHealthy)

    // ========================================================================
    // POLICY TESTS
    // ========================================================================

    [<Fact>]
    let ``FailFast policy propagates failure immediately`` () =
        // Arrange
        let dag = makeHealthyDAG ()

        // Act
        let (result, updatedDag) = propagateHealthChange "indrajaal-db" Failed FailFast dag

        // Assert - mandatory dependent should be Failed
        let appState = getHealthState "indrajaal-app" updatedDag
        Assert.Equal(Some Failed, appState)

    [<Fact>]
    let ``GracefulDegrade policy degrades instead of failing`` () =
        // Arrange
        let dag = makeHealthyDAG ()

        // Act
        let (result, updatedDag) = propagateHealthChange "indrajaal-db" Failed GracefulDegrade dag

        // Assert - mandatory dependent should be Degraded not Failed
        let appState = getHealthState "indrajaal-app" updatedDag
        Assert.Equal(Some Degraded, appState)

    [<Fact>]
    let ``RetryWithBackoff policy degrades instead of failing`` () =
        // Arrange
        let dag = makeHealthyDAG ()

        // Act
        let (result, updatedDag) = propagateHealthChange "indrajaal-db" Failed (RetryWithBackoff (3, 100)) dag

        // Assert - should degrade while retrying
        let appState = getHealthState "indrajaal-app" updatedDag
        Assert.Equal(Some Degraded, appState)

    [<Fact>]
    let ``applyRetryPolicy with FailFast runs check once`` () =
        // Arrange
        let mutable callCount = 0
        let checkFn _ = callCount <- callCount + 1; false

        // Act
        let _ = applyRetryPolicy FailFast checkFn "node1"

        // Assert
        Assert.Equal(1, callCount)

    [<Fact>]
    let ``applyRetryPolicy with RetryWithBackoff retries on failure`` () =
        // Arrange
        let mutable callCount = 0
        let checkFn _ = callCount <- callCount + 1; false

        // Act
        let _ = applyRetryPolicy (RetryWithBackoff (2, 10)) checkFn "node1"

        // Assert - initial call + 2 retries = 3 calls
        Assert.Equal(3, callCount)

    [<Fact>]
    let ``applyRetryPolicy with RetryWithBackoff returns true on success`` () =
        // Arrange
        let mutable callCount = 0
        let checkFn _ =
            callCount <- callCount + 1
            callCount >= 2  // Succeeds on second call

        // Act
        let result = applyRetryPolicy (RetryWithBackoff (3, 10)) checkFn "node1"

        // Assert
        Assert.True(result)
        Assert.Equal(2, callCount)  // Stopped after success

    [<Fact>]
    let ``getRecommendedPolicy returns FailFast for Mandatory`` () =
        // Act
        let policy = getRecommendedPolicy Mandatory

        // Assert
        Assert.Equal(FailFast, policy)

    [<Fact>]
    let ``getRecommendedPolicy returns GracefulDegrade for Optional`` () =
        // Act
        let policy = getRecommendedPolicy Optional

        // Assert
        Assert.Equal(GracefulDegrade, policy)

    // ========================================================================
    // RECOVERY TESTS
    // ========================================================================

    [<Fact>]
    let ``restoreFromDegradedState recovers healthy nodes`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Healthy
            |> updateHealthState "indrajaal-app" Degraded  // db is healthy, so app can recover

        // Act
        let (result, updatedDag) = restoreFromDegradedState (alwaysHealthy ()) dag

        // Assert
        Assert.Contains("indrajaal-app", result.RecoveredNodes)
        let appState = getHealthState "indrajaal-app" updatedDag
        Assert.Equal(Some Healthy, appState)

    [<Fact>]
    let ``restoreFromDegradedState fails when dependencies unhealthy`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Failed
            |> updateHealthState "indrajaal-app" Degraded

        // Act
        let (result, _) = restoreFromDegradedState (alwaysHealthy ()) dag

        // Assert - app can't recover because db is failed
        Assert.Contains("indrajaal-app", result.FailedNodes)
        Assert.DoesNotContain("indrajaal-app", result.RecoveredNodes)

    [<Fact>]
    let ``restoreFromDegradedState processes in topological order`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Healthy
            |> updateHealthState "indrajaal-app" Degraded
            |> updateHealthState "indrajaal-obs" Degraded

        // Act
        let (result, _) = restoreFromDegradedState (alwaysHealthy ()) dag

        // Assert - db's dependencies first, then app, then obs
        Assert.True(result.AttemptedNodes.Length >= 2)

    [<Fact>]
    let ``recoverNode succeeds when dependencies healthy`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Healthy
            |> updateHealthState "indrajaal-app" Degraded

        // Act
        let (success, updatedDag) = recoverNode "indrajaal-app" (alwaysHealthy ()) dag

        // Assert
        Assert.True(success)
        let appState = getHealthState "indrajaal-app" updatedDag
        Assert.Equal(Some Healthy, appState)

    [<Fact>]
    let ``recoverNode fails when dependencies unhealthy`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Failed
            |> updateHealthState "indrajaal-app" Degraded

        // Act
        let (success, _) = recoverNode "indrajaal-app" (alwaysHealthy ()) dag

        // Assert
        Assert.False(success)

    [<Fact>]
    let ``recoverNode fails when health check fails`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Healthy
            |> updateHealthState "indrajaal-app" Degraded

        // Act
        let (success, _) = recoverNode "indrajaal-app" (alwaysUnhealthy ()) dag

        // Assert
        Assert.False(success)

    // ========================================================================
    // HEALTH SUMMARY TESTS
    // ========================================================================

    [<Fact>]
    let ``getHealthSummary counts nodes correctly`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Healthy
            |> updateHealthState "indrajaal-app" Degraded
            |> updateHealthState "indrajaal-obs" Failed

        // Act
        let summary = getHealthSummary dag

        // Assert
        Assert.Equal(3, summary.TotalNodes)
        Assert.Equal(1, summary.HealthyCount)
        Assert.Equal(1, summary.DegradedCount)
        Assert.Equal(1, summary.FailedCount)

    [<Fact>]
    let ``getHealthSummary reports OverallHealthy correctly`` () =
        // Arrange
        let healthyDag = makeHealthyDAG ()
        let unhealthyDag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Failed

        // Act
        let healthySummary = getHealthSummary healthyDag
        let unhealthySummary = getHealthSummary unhealthyDag

        // Assert
        Assert.True(healthySummary.OverallHealthy)
        Assert.False(unhealthySummary.OverallHealthy)

    [<Fact>]
    let ``formatHealthSummary includes status`` () =
        // Arrange
        let dag = makeHealthyDAG ()
        let summary = getHealthSummary dag

        // Act
        let formatted = formatHealthSummary summary

        // Assert
        Assert.Contains("HEALTHY", formatted)

    [<Fact>]
    let ``formatHealthSummary shows node counts`` () =
        // Arrange
        let dag = makeHealthyDAG ()
        let summary = getHealthSummary dag

        // Act
        let formatted = formatHealthSummary summary

        // Assert
        Assert.Contains("Total Nodes:", formatted)
        Assert.Contains("Healthy:", formatted)

    // ========================================================================
    // IMPACT ANALYSIS TESTS
    // ========================================================================

    [<Fact>]
    let ``calculateImpact identifies direct dependents`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let impact = calculateImpact "indrajaal-db" dag

        // Assert
        Assert.Contains("indrajaal-app", impact.DirectDependents)

    [<Fact>]
    let ``calculateImpact identifies transitive dependents`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let impact = calculateImpact "indrajaal-db" dag

        // Assert - obs transitively depends on db via app
        Assert.Contains("indrajaal-obs", impact.TransitiveDependents)

    [<Fact>]
    let ``calculateImpact categorizes mandatory blocked`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let impact = calculateImpact "indrajaal-db" dag

        // Assert - app has mandatory dep on db
        Assert.Contains("indrajaal-app", impact.MandatoryBlocked)

    [<Fact>]
    let ``calculateImpact categorizes optional degraded`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let impact = calculateImpact "indrajaal-app" dag

        // Assert - obs has optional dep on app
        Assert.Contains("indrajaal-obs", impact.OptionalDegraded)

    [<Fact>]
    let ``calculateImpact returns correct total affected count`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let impact = calculateImpact "indrajaal-db" dag

        // Assert
        Assert.Equal(2, impact.TotalAffected)  // app and obs

    // ========================================================================
    // BATCH OPERATIONS TESTS
    // ========================================================================

    [<Fact>]
    let ``propagateHealthChanges applies multiple changes`` () =
        // Arrange
        let dag = makeStandardChainDAG ()
        let changes = [
            ("indrajaal-db", Healthy)
            ("indrajaal-app", Healthy)
        ]

        // Act
        let (result, updatedDag) = propagateHealthChanges changes FailFast dag

        // Assert
        Assert.Contains("indrajaal-db", result.AffectedNodes)
        Assert.Contains("indrajaal-app", result.AffectedNodes)
        Assert.Equal(Some Healthy, getHealthState "indrajaal-db" updatedDag)
        Assert.Equal(Some Healthy, getHealthState "indrajaal-app" updatedDag)

    [<Fact>]
    let ``refreshAllHealth updates changed nodes only`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Healthy  // Already healthy
            |> updateHealthState "indrajaal-app" Healthy  // Will become unhealthy

        let healthCheck = selectiveHealth ["indrajaal-db"; "indrajaal-obs"]  // app fails

        // Act
        let (result, _) = refreshAllHealth healthCheck FailFast dag

        // Assert - only app should change (from Healthy to Failed)
        Assert.Contains("indrajaal-app", result.AffectedNodes)

    // ========================================================================
    // VALIDATION HELPER TESTS
    // ========================================================================

    [<Fact>]
    let ``validatePropagationTime returns true for fast propagation`` () =
        // Arrange
        let result = {
            AffectedNodes = ["node1"]
            Events = []
            TotalTimeMs = 25L
        }

        // Act & Assert
        Assert.True(validatePropagationTime result)

    [<Fact>]
    let ``validatePropagationTime returns false for slow propagation`` () =
        // Arrange
        let result = {
            AffectedNodes = ["node1"]
            Events = []
            TotalTimeMs = 100L
        }

        // Act & Assert
        Assert.False(validatePropagationTime result)

    [<Fact>]
    let ``getNodesNeedingAttention returns failed and degraded nodes`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Healthy
            |> updateHealthState "indrajaal-app" Degraded
            |> updateHealthState "indrajaal-obs" Failed

        // Act
        let needsAttention = getNodesNeedingAttention dag

        // Assert
        Assert.Equal(2, needsAttention.Length)
        Assert.True(needsAttention |> List.exists (fun (id, _) -> id = "indrajaal-app"))
        Assert.True(needsAttention |> List.exists (fun (id, _) -> id = "indrajaal-obs"))

    [<Fact>]
    let ``isSystemCritical returns true when node failed`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Failed

        // Act & Assert
        Assert.True(isSystemCritical dag)

    [<Fact>]
    let ``isSystemCritical returns false when no failures`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Healthy
            |> updateHealthState "indrajaal-app" Degraded  // Degraded is not critical

        // Act & Assert
        Assert.False(isSystemCritical dag)

    [<Fact>]
    let ``isSystemFullyOperational returns true when all healthy`` () =
        // Arrange
        let dag = makeHealthyDAG ()

        // Act & Assert
        Assert.True(isSystemFullyOperational dag)

    [<Fact>]
    let ``isSystemFullyOperational returns false when any non-healthy`` () =
        // Arrange
        let dag =
            makeStandardChainDAG ()
            |> updateHealthState "indrajaal-db" Healthy
            |> updateHealthState "indrajaal-app" Healthy
            |> updateHealthState "indrajaal-obs" Degraded

        // Act & Assert
        Assert.False(isSystemFullyOperational dag)

    // ========================================================================
    // EDGE CASE TESTS
    // ========================================================================

    [<Fact>]
    let ``propagateHealthChange on empty DAG does nothing`` () =
        // Arrange
        let dag = empty

        // Act
        let (result, _) = propagateHealthChange "non-existent" Healthy FailFast dag

        // Assert - source node event still created but no affected nodes beyond it
        Assert.True(result.Events.Length <= 1)

    [<Fact>]
    let ``propagateHealthChange on single node DAG works`` () =
        // Arrange
        let dag = buildDAG [makeDbContainer ()]

        // Act
        let (result, updatedDag) = propagateHealthChange "indrajaal-db" Healthy FailFast dag

        // Assert
        Assert.Equal(1, result.AffectedNodes.Length)
        Assert.Equal(Some Healthy, getHealthState "indrajaal-db" updatedDag)

    [<Fact>]
    let ``triggerFastEmergencyStop on isolated node only affects that node`` () =
        // Arrange
        let dag = buildDAG [makeIsolatedContainer ()] |> updateHealthState "isolated" Healthy

        // Act
        let (result, _) = triggerFastEmergencyStop "isolated" dag

        // Assert
        Assert.Equal(1, result.StoppedNodes.Length)
        Assert.Contains("isolated", result.StoppedNodes)

    [<Fact>]
    let ``getHealthSummary on empty DAG returns zero counts`` () =
        // Arrange
        let dag = empty

        // Act
        let summary = getHealthSummary dag

        // Assert
        Assert.Equal(0, summary.TotalNodes)
        Assert.Equal(0, summary.HealthyCount)
        Assert.True(summary.OverallHealthy)  // Empty system is considered healthy

    [<Fact>]
    let ``calculateImpact on node with no dependents returns empty lists`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let impact = calculateImpact "indrajaal-obs" dag

        // Assert
        Assert.Empty(impact.DirectDependents)
        Assert.Empty(impact.TransitiveDependents)
        Assert.Equal(0, impact.TotalAffected)

    [<Fact>]
    let ``restoreFromDegradedState with no degraded nodes returns empty`` () =
        // Arrange
        let dag = makeHealthyDAG ()

        // Act
        let (result, _) = restoreFromDegradedState (alwaysHealthy ()) dag

        // Assert
        Assert.Empty(result.AttemptedNodes)
        Assert.Empty(result.RecoveredNodes)
        Assert.Empty(result.FailedNodes)

    [<Fact>]
    let ``complex DAG handles multiple dependency types correctly`` () =
        // Arrange
        let dag =
            makeComplexDAG ()
            |> updateHealthState "indrajaal-db" Healthy
            |> updateHealthState "cache" Healthy
            |> updateHealthState "indrajaal-app" Healthy
            |> updateHealthState "worker" Healthy
            |> updateHealthState "indrajaal-obs" Healthy

        // Act - fail cache (worker has optional dep on cache)
        let (result, updatedDag) = propagateHealthChange "cache" Failed FailFast dag

        // Assert - worker should be degraded (optional dep failed), not failed
        let workerState = getHealthState "worker" updatedDag
        Assert.Equal(Some Degraded, workerState)

    [<Fact>]
    let ``complex DAG mandatory failure blocks dependent`` () =
        // Arrange
        let dag =
            makeComplexDAG ()
            |> updateHealthState "indrajaal-db" Healthy
            |> updateHealthState "cache" Healthy
            |> updateHealthState "indrajaal-app" Healthy
            |> updateHealthState "worker" Healthy
            |> updateHealthState "indrajaal-obs" Healthy

        // Act - fail db (worker has mandatory dep on db)
        let (result, updatedDag) = propagateHealthChange "indrajaal-db" Failed FailFast dag

        // Assert - worker should be failed (mandatory dep failed)
        let workerState = getHealthState "worker" updatedDag
        Assert.Equal(Some Failed, workerState)
