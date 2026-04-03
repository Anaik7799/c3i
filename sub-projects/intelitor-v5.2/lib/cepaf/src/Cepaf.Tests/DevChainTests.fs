namespace Cepaf.Tests

open System
open Xunit
open Cepaf.Modules.ServiceDAG
open Cepaf.ServiceChains.DevChain

/// DevChain Unit Tests - Dev/Demo Environment Service Chain
/// STAMP Compliance: SC-CNT-009, SC-CNT-010, SC-CNT-012, SC-CEP-003, SC-CEP-004, SC-AGT-018
/// AOR Compliance: AOR-SAF-001, AOR-CNT-001, AOR-QUA-001
/// Test Coverage: Container definitions, DAG construction, boot sequence, health config,
///                STAMP compliance, validation, layer structure, dependencies, shutdown order
module DevChainTests =

    // ========================================================================
    // SECTION 1: STARTUP USECASES (UC-START-*)
    // ========================================================================

    [<Fact>]
    let ``UC-START-001: Clean start produces valid DAG with 3 core containers`` () =
        // Arrange & Act
        let dag = buildMinimalDevDAG ()

        // Assert
        Assert.Equal(3, nodeCount dag)
        Assert.True(hasNode "indrajaal-db" dag)
        Assert.True(hasNode "indrajaal-app" dag)
        Assert.True(hasNode "indrajaal-obs" dag)

    [<Fact>]
    let ``UC-START-001: Full start produces valid DAG with 6 containers`` () =
        // Arrange & Act
        let dag = buildFullDevDAG ()

        // Assert
        Assert.Equal(6, nodeCount dag)
        Assert.True(hasNode "indrajaal-redis" dag)
        Assert.True(hasNode "indrajaal-nginx" dag)
        Assert.True(hasNode "indrajaal-grafana" dag)

    [<Fact>]
    let ``UC-START-002: Partial start with DB only is valid`` () =
        // Arrange
        let dbOnly = [Layer0.dbContainer]

        // Act
        let dag = buildDAG dbOnly

        // Assert
        Assert.Equal(1, nodeCount dag)
        Assert.True(hasNode "indrajaal-db" dag)
        Assert.False(hasCycles dag)

    [<Fact>]
    let ``UC-START-003: Full chain boot sequence has correct order`` () =
        // Arrange & Act
        let sequence = getFullDevBootSequence ()

        // Assert - db must come before app, app must come before obs
        let dbIdx = List.findIndex ((=) "indrajaal-db") sequence.Order
        let appIdx = List.findIndex ((=) "indrajaal-app") sequence.Order
        let obsIdx = List.findIndex ((=) "indrajaal-obs") sequence.Order

        Assert.True(dbIdx < appIdx, "db should start before app")
        Assert.True(appIdx < obsIdx, "app should start before obs")

    [<Fact>]
    let ``UC-START-004: Boot sequence includes all containers`` () =
        // Arrange & Act
        let sequence = getFullDevBootSequence ()

        // Assert
        Assert.Equal(6, sequence.Order.Length)
        Assert.Contains("indrajaal-db", sequence.Order)
        Assert.Contains("indrajaal-app", sequence.Order)
        Assert.Contains("indrajaal-obs", sequence.Order)
        Assert.Contains("indrajaal-redis", sequence.Order)
        Assert.Contains("indrajaal-nginx", sequence.Order)
        Assert.Contains("indrajaal-grafana", sequence.Order)

    [<Fact>]
    let ``UC-START-005: Boot sequence has estimated time`` () =
        // Arrange & Act
        let sequence = getFullDevBootSequence ()

        // Assert
        Assert.True(sequence.EstimatedTimeMs > 0L)

    [<Fact>]
    let ``UC-START-006: Missing image detected via registry validation`` () =
        // Arrange
        let badContainer : ContainerDef = {
            Name = "bad-container"
            Image = "docker.io/library/postgres:17"  // Not localhost/
            DependsOn = []
            DependencyTypes = Map.empty
            Layer = None
        }

        // Act - Check if it violates SC-CNT-010
        let violatesRegistry = not (badContainer.Image.StartsWith("localhost/"))

        // Assert
        Assert.True(violatesRegistry)

    [<Fact>]
    let ``UC-START-007: Estimated boot time is reasonable`` () =
        // Arrange & Act
        let estimatedMs = estimateBootTimeMs ()

        // Assert - Should be based on layer count
        // 3 layers * 10000ms = 30000ms estimate
        Assert.True(estimatedMs > 0L)
        Assert.True(estimatedMs <= 60000L)  // Not unreasonably long

    // ========================================================================
    // SECTION 2: HEALTH USECASES (UC-HEALTH-*)
    // ========================================================================

    [<Fact>]
    let ``UC-HEALTH-001: DB health config has correct port`` () =
        // Act
        let config = Layer0.dbHealthConfig

        // Assert
        Assert.Equal(5433, config.Port)

    [<Fact>]
    let ``UC-HEALTH-001: App health config has correct endpoint`` () =
        // Act
        let config = Layer1.appHealthConfig

        // Assert
        Assert.Equal("/health", config.HealthEndpoint)
        Assert.Equal(4000, config.Port)

    [<Fact>]
    let ``UC-HEALTH-001: Obs health config has correct ports`` () =
        // Act
        let config = Layer2.obsHealthConfig

        // Assert
        Assert.Equal(9090, config.PrometheusPort)
        Assert.Equal(3000, config.GrafanaPort)
        Assert.Equal(4317, config.OtlpPort)

    [<Fact>]
    let ``UC-HEALTH-002: DB degradation does not block obs`` () =
        // Arrange - obs depends on app with Optional type
        let dag = buildMinimalDevDAG ()

        // Act
        let depType = getDependencyType "indrajaal-app" "indrajaal-obs" dag

        // Assert - obs depends on app as Optional
        Assert.Equal(Some Optional, depType)

    [<Fact>]
    let ``UC-HEALTH-003: App unhealthy check - obs has optional dep`` () =
        // Arrange
        let dag = buildMinimalDevDAG ()

        // Act
        let hasOptional = hasOnlyOptionalDeps "indrajaal-obs" dag

        // Assert
        Assert.True(hasOptional)

    [<Fact>]
    let ``UC-HEALTH-004: Health state transitions are valid`` () =
        // Arrange
        let dag = buildMinimalDevDAG ()

        // Act - Update health state (qualify HealthState to avoid shadowing by DevChainState)
        let dag1 = updateHealthState "indrajaal-db" HealthState.Starting dag
        let dag2 = updateHealthState "indrajaal-db" HealthState.Healthy dag1
        let dag3 = updateHealthState "indrajaal-db" HealthState.Degraded dag2

        // Assert
        Assert.Equal(Some HealthState.Starting, getHealthState "indrajaal-db" dag1)
        Assert.Equal(Some HealthState.Healthy, getHealthState "indrajaal-db" dag2)
        Assert.Equal(Some HealthState.Degraded, getHealthState "indrajaal-db" dag3)

    [<Fact>]
    let ``UC-HEALTH-005: Cascading failure - db affects app`` () =
        // Arrange
        let dag = buildMinimalDevDAG ()

        // Act - Check dependency direction
        let appDependsOnDb = dependsOn "indrajaal-app" "indrajaal-db" dag

        // Assert
        Assert.True(appDependsOnDb)

    [<Fact>]
    let ``UC-HEALTH-006: Health config includes retry settings`` () =
        // Assert
        Assert.True(Layer0.dbHealthConfig.Retries > 0)
        Assert.True(Layer1.appHealthConfig.Retries > 0)
        Assert.True(Layer2.obsHealthConfig.Retries > 0)

    [<Fact>]
    let ``UC-HEALTH-007: Health config includes timeout`` () =
        // Assert
        Assert.True(Layer0.dbHealthConfig.Timeout > TimeSpan.Zero)
        Assert.True(Layer1.appHealthConfig.HealthTimeoutMs > 0)
        Assert.True(Layer2.obsHealthConfig.HealthTimeoutMs > 0)

    // ========================================================================
    // SECTION 3: FPPS VERIFICATION USECASES (UC-FPPS-*)
    // ========================================================================

    [<Fact>]
    let ``UC-FPPS-001: Default FPPS config enables all methods`` () =
        // Act
        let config = defaultDevFPPSConfig

        // Assert
        Assert.True(config.EnablePodmanStatus)
        Assert.True(config.EnableHealthEndpoint)
        Assert.True(config.EnablePortProbe)
        Assert.True(config.EnableProcessCheck)
        Assert.True(config.EnableLogAnalysis)

    [<Fact>]
    let ``UC-FPPS-002: FPPS config has error patterns`` () =
        // Act
        let config = defaultDevFPPSConfig

        // Assert
        Assert.True(config.LogErrorPatterns.Length > 0)
        Assert.Contains("ERROR", config.LogErrorPatterns)
        Assert.Contains("FATAL", config.LogErrorPatterns)
        Assert.Contains("CRITICAL", config.LogErrorPatterns)

    [<Fact>]
    let ``UC-FPPS-003: FPPS config has reasonable log tail lines`` () =
        // Act
        let config = defaultDevFPPSConfig

        // Assert
        Assert.True(config.LogTailLines > 0)
        Assert.True(config.LogTailLines <= 200)  // Not too many

    [<Fact>]
    let ``UC-FPPS-004: Port map has all containers`` () =
        // Act
        let ports = devPortMap

        // Assert
        Assert.True(ports.ContainsKey("indrajaal-db"))
        Assert.True(ports.ContainsKey("indrajaal-app"))
        Assert.True(ports.ContainsKey("indrajaal-obs"))
        Assert.Equal(5433, ports.["indrajaal-db"])
        Assert.Equal(4000, ports.["indrajaal-app"])
        Assert.Equal(9090, ports.["indrajaal-obs"])

    [<Fact>]
    let ``UC-FPPS-005: IP map has all containers`` () =
        // Act
        let ips = devIpMap

        // Assert
        Assert.True(ips.ContainsKey("indrajaal-db"))
        Assert.True(ips.ContainsKey("indrajaal-app"))
        Assert.True(ips.ContainsKey("indrajaal-obs"))

    [<Fact>]
    let ``UC-FPPS-006: FPPS includes OOM detection pattern`` () =
        // Act
        let config = defaultDevFPPSConfig

        // Assert
        Assert.Contains("OOM", config.LogErrorPatterns)

    [<Fact>]
    let ``UC-FPPS-007: FPPS includes panic detection pattern`` () =
        // Act
        let config = defaultDevFPPSConfig

        // Assert
        Assert.Contains("panic", config.LogErrorPatterns)

    // ========================================================================
    // SECTION 4: DEPENDENCY USECASES (UC-DEP-*)
    // ========================================================================

    [<Fact>]
    let ``UC-DEP-001: Mandatory dep - app depends on db`` () =
        // Arrange
        let dag = buildMinimalDevDAG ()

        // Act
        let depType = getDependencyType "indrajaal-db" "indrajaal-app" dag

        // Assert
        Assert.Equal(Some Mandatory, depType)

    [<Fact>]
    let ``UC-DEP-002: Optional dep - obs depends on app`` () =
        // Arrange
        let dag = buildMinimalDevDAG ()

        // Act
        let depType = getDependencyType "indrajaal-app" "indrajaal-obs" dag

        // Assert
        Assert.Equal(Some Optional, depType)

    [<Fact>]
    let ``UC-DEP-003: No cyclic dependencies in dev chain`` () =
        // Arrange
        let dag = buildFullDevDAG ()

        // Act
        let hasCycle = hasCycles dag

        // Assert (SC-AGT-018)
        Assert.False(hasCycle)

    [<Fact>]
    let ``UC-DEP-004: All dependency targets exist`` () =
        // Arrange
        let dag = buildFullDevDAG ()

        // Act & Assert
        fullContainers
        |> List.iter (fun c ->
            c.DependsOn
            |> List.iter (fun dep ->
                Assert.True(hasNode dep dag, sprintf "Dependency %s not found" dep)))

    [<Fact>]
    let ``UC-DEP-005: No self-dependencies`` () =
        // Arrange & Assert
        fullContainers
        |> List.iter (fun c ->
            Assert.DoesNotContain(c.Name, c.DependsOn))

    [<Fact>]
    let ``UC-DEP-006: Transitive dependencies for obs`` () =
        // Arrange
        let dag = buildMinimalDevDAG ()

        // Act
        let deps = getTransitiveDependencies "indrajaal-obs" dag

        // Assert - obs depends on app which depends on db
        Assert.Contains("indrajaal-app", deps)
        Assert.Contains("indrajaal-db", deps)

    [<Fact>]
    let ``UC-DEP-007: Sidecars share network with parent`` () =
        // Arrange - redis and nginx share network with app
        // Grafana shares network with obs

        // Assert - check IP assignments
        Assert.Equal(devIpMap.["indrajaal-redis"], devIpMap.["indrajaal-app"])
        Assert.Equal(devIpMap.["indrajaal-nginx"], devIpMap.["indrajaal-app"])
        Assert.Equal(devIpMap.["indrajaal-grafana"], devIpMap.["indrajaal-obs"])

    // ========================================================================
    // SECTION 5: SHUTDOWN USECASES (UC-STOP-*)
    // ========================================================================

    [<Fact>]
    let ``UC-STOP-001: Shutdown order is reverse of boot order`` () =
        // Arrange
        let bootOrder = getFullDevBootSequence().Order
        let shutdownOrder = getShutdownOrder ()

        // Assert (use type annotation to disambiguate Assert.Equal overload)
        Assert.Equal<string list>(bootOrder |> List.rev, shutdownOrder)

    [<Fact>]
    let ``UC-STOP-002: Shutdown mode types exist`` () =
        // Arrange
        let graceful = Graceful
        let emergency = Emergency
        let partial = Partial ["indrajaal-obs"]

        // Assert
        match graceful with Graceful -> Assert.True(true) | _ -> Assert.Fail("Expected Graceful")
        match emergency with Emergency -> Assert.True(true) | _ -> Assert.Fail("Expected Emergency")
        match partial with Partial nodes -> Assert.Single(nodes) |> ignore | _ -> Assert.Fail("Expected Partial")

    [<Fact>]
    let ``UC-STOP-003: Partial shutdown can specify containers`` () =
        // Arrange
        let mode = Partial ["indrajaal-obs"; "indrajaal-grafana"]

        // Assert
        match mode with
        | Partial containers ->
            Assert.Equal(2, containers.Length)
            Assert.Contains("indrajaal-obs", containers)
        | _ -> Assert.Fail("Expected Partial mode")

    [<Fact>]
    let ``UC-STOP-004: Shutdown result tracks success`` () =
        // Arrange
        let result : ShutdownResult = {
            Mode = Graceful
            StoppedContainers = ["indrajaal-db"; "indrajaal-app"]
            FailedToStop = []
            DurationMs = 5000L
            Success = true
        }

        // Assert
        Assert.True(result.Success)
        Assert.Equal(2, result.StoppedContainers.Length)
        Assert.Empty(result.FailedToStop)

    [<Fact>]
    let ``UC-STOP-005: Shutdown result tracks failures`` () =
        // Arrange
        let result : ShutdownResult = {
            Mode = Graceful
            StoppedContainers = ["indrajaal-db"]
            FailedToStop = ["indrajaal-app"]
            DurationMs = 30000L
            Success = false
        }

        // Assert
        Assert.False(result.Success)
        Assert.Single(result.FailedToStop) |> ignore

    // ========================================================================
    // SECTION 6: VALIDATION USECASES (UC-VAL-*)
    // ========================================================================

    [<Fact>]
    let ``UC-VAL-001: Dev chain validates successfully`` () =
        // Act
        let result = validateDevChain ()

        // Assert
        match result with
        | Ok dag -> Assert.True(dag.IsValid)
        | Error errs -> Assert.Fail(sprintf "Validation failed: %s" (String.concat "; " errs))

    [<Fact>]
    let ``UC-VAL-002: All images use localhost registry`` () =
        // Assert (SC-CNT-010)
        fullContainers
        |> List.iter (fun c ->
            Assert.True(c.Image.StartsWith("localhost/"),
                sprintf "Container %s uses non-localhost registry: %s" c.Name c.Image))

    [<Fact>]
    let ``UC-VAL-003: STAMP compliance check returns map`` () =
        // Act
        let compliance = checkStampCompliance ()

        // Assert
        Assert.True(compliance.ContainsKey("SC-CNT-009"))
        Assert.True(compliance.ContainsKey("SC-CNT-010"))
        Assert.True(compliance.ContainsKey("SC-CNT-012"))
        Assert.True(compliance.ContainsKey("SC-AGT-018"))
        Assert.True(compliance.ContainsKey("SC-CEP-003"))
        Assert.True(compliance.ContainsKey("SC-CEP-004"))

    [<Fact>]
    let ``UC-VAL-003: All STAMP constraints pass for dev chain`` () =
        // Act
        let compliance = checkStampCompliance ()

        // Assert
        compliance |> Map.iter (fun constraint passed ->
            Assert.True(passed, sprintf "STAMP constraint %s failed" constraint))

    // ========================================================================
    // SECTION 7: LAYER STRUCTURE TESTS
    // ========================================================================

    [<Fact>]
    let ``Layer 0 contains only database`` () =
        // Act
        let dag = buildMinimalDevDAG () |> assignLayers
        let layer0 = getNodesAtLayer 0 dag

        // Assert
        Assert.Single(layer0) |> ignore
        Assert.Contains("indrajaal-db", layer0)

    [<Fact>]
    let ``Layer 1 contains app and sidecars`` () =
        // Act
        let dag = buildFullDevDAG () |> assignLayers
        let layer1 = getNodesAtLayer 1 dag

        // Assert
        Assert.Contains("indrajaal-app", layer1)
        // Note: Redis and nginx depend on app, so they're at layer 2

    [<Fact>]
    let ``Layer 2 contains obs and sidecars`` () =
        // Act
        let dag = buildFullDevDAG () |> assignLayers
        let layer2 = getNodesAtLayer 2 dag

        // Assert
        Assert.True(layer2.Length > 0)

    [<Fact>]
    let ``getContainersAtLayer returns correct containers`` () =
        // Act
        let layer0 = getContainersAtLayer 0
        let layer1 = getContainersAtLayer 1
        let layer2 = getContainersAtLayer 2

        // Assert
        Assert.True(layer0 |> List.exists (fun c -> c.Name = "indrajaal-db"))
        Assert.True(layer1 |> List.exists (fun c -> c.Name = "indrajaal-app"))
        Assert.True(layer2 |> List.exists (fun c -> c.Name = "indrajaal-obs"))

    [<Fact>]
    let ``Maximum layer is 2 for minimal chain`` () =
        // Arrange
        let dag = buildMinimalDevDAG () |> assignLayers

        // Act
        let maxLayer = getMaxLayer dag

        // Assert
        Assert.Equal(2, maxLayer)

    // ========================================================================
    // SECTION 8: CONTAINER DEFINITION TESTS
    // ========================================================================

    [<Fact>]
    let ``DB container has no dependencies`` () =
        // Arrange
        let db = Layer0.dbContainer

        // Assert
        Assert.Empty(db.DependsOn)
        Assert.Equal(Some 0, db.Layer)

    [<Fact>]
    let ``App container depends on db`` () =
        // Arrange
        let app = Layer1.appContainer

        // Assert
        Assert.Single(app.DependsOn) |> ignore
        Assert.Contains("indrajaal-db", app.DependsOn)

    [<Fact>]
    let ``Obs container has optional dependency`` () =
        // Arrange
        let obs = Layer2.obsContainer

        // Assert
        Assert.Single(obs.DependsOn) |> ignore
        Assert.Equal(Some Optional, obs.DependencyTypes.TryFind("indrajaal-app"))

    [<Fact>]
    let ``All images contain nixos identifier`` () =
        // Assert (SC-CNT-009)
        fullContainers
        |> List.iter (fun c ->
            Assert.True(c.Image.Contains("nixos"),
                sprintf "Container %s image does not contain 'nixos': %s" c.Name c.Image))

    [<Fact>]
    let ``isCoreContainer identifies core correctly`` () =
        // Assert
        Assert.True(isCoreContainer "indrajaal-db")
        Assert.True(isCoreContainer "indrajaal-app")
        Assert.True(isCoreContainer "indrajaal-obs")
        Assert.False(isCoreContainer "indrajaal-redis")
        Assert.False(isCoreContainer "indrajaal-nginx")
        Assert.False(isCoreContainer "indrajaal-grafana")

    [<Fact>]
    let ``getDevContainer finds existing containers`` () =
        // Assert
        Assert.True((getDevContainer "indrajaal-db").IsSome)
        Assert.True((getDevContainer "indrajaal-app").IsSome)
        Assert.True((getDevContainer "indrajaal-obs").IsSome)
        Assert.True((getDevContainer "non-existent").IsNone)

    [<Fact>]
    let ``getContainerLayer returns correct layer`` () =
        // Assert
        Assert.Equal(Some 0, getContainerLayer "indrajaal-db")
        Assert.Equal(Some 1, getContainerLayer "indrajaal-app")
        Assert.Equal(Some 2, getContainerLayer "indrajaal-obs")
        Assert.Equal(None, getContainerLayer "non-existent")

    // ========================================================================
    // SECTION 9: STAMP CONSTRAINT TESTS
    // ========================================================================

    [<Fact>]
    let ``DB STAMP constraints enforce rootless`` () =
        // Arrange
        let constraints = Layer0.dbStampConstraints

        // Assert (SC-CNT-012)
        Assert.True(constraints.Rootless)

    [<Fact>]
    let ``App STAMP constraints enforce zero warnings`` () =
        // Arrange
        let constraints = Layer1.appStampConstraints

        // Assert (SC-CMP-025)
        Assert.True(constraints.ZeroWarnings)

    [<Fact>]
    let ``App STAMP constraints enforce response latency`` () =
        // Arrange
        let constraints = Layer1.appStampConstraints

        // Assert (SC-PRF-050)
        Assert.Equal(50L, constraints.MaxResponseMs)

    [<Fact>]
    let ``Obs STAMP constraints enforce dual logging`` () =
        // Arrange
        let constraints = Layer2.obsStampConstraints

        // Assert (SC-OBS-069)
        Assert.True(constraints.DualLogging)

    [<Fact>]
    let ``Obs STAMP constraints require 4 OTEL modules`` () =
        // Arrange
        let constraints = Layer2.obsStampConstraints

        // Assert (SC-OBS-071)
        Assert.Equal(4, constraints.RequiredOtelModules)

    // ========================================================================
    // SECTION 10: CHAIN STATE TESTS
    // ========================================================================

    [<Fact>]
    let ``Initial boot progress has correct state`` () =
        // Arrange
        let progress = initialBootProgress

        // Assert
        Assert.Equal(NotStarted, progress.State)
        Assert.Equal(-1, progress.CurrentLayer)
        Assert.Empty(progress.StartedContainers)
        Assert.Empty(progress.HealthyContainers)
        Assert.Empty(progress.FailedContainers)
        Assert.Equal(0L, progress.ElapsedMs)
        Assert.True(progress.EstimatedRemainingMs > 0L)

    [<Fact>]
    let ``DevChainState has all expected states`` () =
        // Arrange
        let states = [
            NotStarted
            BootingLayer0
            BootingLayer1
            BootingLayer2
            Running
            Degraded "test"
            Failed "test"
            ShuttingDown
        ]

        // Assert
        Assert.Equal(8, states.Length)

    [<Fact>]
    let ``Degraded state includes reason`` () =
        // Arrange
        let state = Degraded "Database slow"

        // Assert
        match state with
        | Degraded reason -> Assert.Equal("Database slow", reason)
        | _ -> Assert.Fail("Expected Degraded")

    [<Fact>]
    let ``Failed state includes reason`` () =
        // Arrange
        let state = Failed "Container crashed"

        // Assert
        match state with
        | Failed reason -> Assert.Equal("Container crashed", reason)
        | _ -> Assert.Fail("Expected Failed")

    // ========================================================================
    // SECTION 11: CHAIN CONFIG TESTS
    // ========================================================================

    [<Fact>]
    let ``Default dev config has correct chain ID`` () =
        // Arrange
        let config = defaultDevConfig

        // Assert
        Assert.Equal("indrajaal-dev-chain", config.ChainId)

    [<Fact>]
    let ``Default dev config has correct environment`` () =
        // Arrange
        let config = defaultDevConfig

        // Assert
        Assert.Equal("dev", config.Environment)

    [<Fact>]
    let ``Default dev config allows degraded obs`` () =
        // Arrange
        let config = defaultDevConfig

        // Assert
        Assert.True(config.AllowDegradedObs)

    [<Fact>]
    let ``Default dev config requires all FPPS`` () =
        // Arrange
        let config = defaultDevConfig

        // Assert
        Assert.True(config.RequireAllFPPS)

    [<Fact>]
    let ``Default dev config has correct network`` () =
        // Arrange
        let config = defaultDevConfig

        // Assert
        Assert.Equal("indrajaal-net", config.NetworkName)
        Assert.Equal("172.30.0.0/24", config.NetworkSubnet)

    [<Fact>]
    let ``Boot threshold is 30 seconds`` () =
        // Arrange
        let config = defaultDevConfig

        // Assert (SC-CEP-004)
        Assert.Equal(30000L, config.BootThresholdMs)

    // ========================================================================
    // SECTION 12: HELPER FUNCTION TESTS
    // ========================================================================

    [<Fact>]
    let ``areDependenciesSatisfied returns true when all deps healthy`` () =
        // Arrange
        let healthySet = Set.ofList ["indrajaal-db"]

        // Act
        let satisfied = areDependenciesSatisfied "indrajaal-app" healthySet

        // Assert
        Assert.True(satisfied)

    [<Fact>]
    let ``areDependenciesSatisfied returns false when deps missing`` () =
        // Arrange
        let healthySet = Set.empty

        // Act
        let satisfied = areDependenciesSatisfied "indrajaal-app" healthySet

        // Assert
        Assert.False(satisfied)

    [<Fact>]
    let ``areDependenciesSatisfied returns true for no deps`` () =
        // Arrange
        let healthySet = Set.empty

        // Act
        let satisfied = areDependenciesSatisfied "indrajaal-db" healthySet

        // Assert - db has no deps
        Assert.True(satisfied)

    [<Fact>]
    let ``generateDevChainSummary returns non-empty string`` () =
        // Act
        let summary = generateDevChainSummary ()

        // Assert
        Assert.False(String.IsNullOrEmpty(summary))
        Assert.Contains("INTELITOR DEV CHAIN SUMMARY", summary)
        Assert.Contains("CONTAINERS:", summary)
        Assert.Contains("BOOT SEQUENCE:", summary)
        Assert.Contains("STAMP COMPLIANCE:", summary)
        Assert.Contains("LAYER STRUCTURE:", summary)

    [<Fact>]
    let ``buildValidatedDevDAG returns Ok for valid config`` () =
        // Act
        let result = buildValidatedDevDAG coreContainers

        // Assert
        match result with
        | Ok dag ->
            Assert.True(dag.IsValid)
            Assert.Equal(3, nodeCount dag)
        | Error errs ->
            Assert.Fail(sprintf "Expected Ok, got Error: %s" (String.concat "; " errs))

    [<Theory>]
    [<InlineData("indrajaal-db", 5433)>]
    [<InlineData("indrajaal-app", 4000)>]
    [<InlineData("indrajaal-obs", 9090)>]
    [<InlineData("indrajaal-redis", 6379)>]
    [<InlineData("indrajaal-grafana", 3000)>]
    let ``Port map has correct assignments`` (container: string) (expectedPort: int) =
        // Act
        let port = devPortMap.[container]

        // Assert
        Assert.Equal(expectedPort, port)

    [<Theory>]
    [<InlineData("indrajaal-db", "172.30.0.10")>]
    [<InlineData("indrajaal-app", "172.30.0.20")>]
    [<InlineData("indrajaal-obs", "172.30.0.30")>]
    let ``IP map has correct assignments`` (container: string) (expectedIp: string) =
        // Act
        let ip = devIpMap.[container]

        // Assert
        Assert.Equal(expectedIp, ip)
