namespace Cepaf.Tests

open System
open Xunit
open Cepaf.Modules.ServiceDAG
open Cepaf.ServiceChains.ObsChain

/// ObsChain Unit Tests - Observability Service Chain
/// STAMP Compliance: SC-OBS-069, SC-OBS-071, SC-CNT-009, SC-CNT-010, SC-CNT-012, SC-AGT-018
/// Test Coverage: Boot sequence, component dependencies, health propagation, STAMP compliance
/// Total Tests: 40 (15 boot + 10 dependency + 10 health + 5 STAMP)
module ObsChainTests =

    // ========================================================================
    // SECTION 1: BOOT SEQUENCE TESTS (UC-BOOT-*) - 15 tests
    // ========================================================================

    [<Fact>]
    let ``UC-BOOT-001: Minimal obs chain produces valid DAG with 3 containers`` () =
        // Arrange & Act
        let dag = buildMinimalObsDAG ()

        // Assert
        Assert.Equal(3, nodeCount dag)
        Assert.True(hasNode "obs-clickhouse" dag)
        Assert.True(hasNode "obs-otel-collector" dag)
        Assert.True(hasNode "obs-query-service" dag)

    [<Fact>]
    let ``UC-BOOT-002: Full obs chain produces valid DAG with 5 containers`` () =
        // Arrange & Act
        let dag = buildFullObsDAG ()

        // Assert
        Assert.Equal(5, nodeCount dag)
        Assert.True(hasNode "obs-clickhouse" dag)
        Assert.True(hasNode "obs-otel-collector" dag)
        Assert.True(hasNode "obs-query-service" dag)
        Assert.True(hasNode "obs-frontend" dag)
        Assert.True(hasNode "obs-grafana" dag)

    [<Fact>]
    let ``UC-BOOT-003: SigNoz-only chain has 4 containers`` () =
        // Arrange & Act
        let dag = buildSignozDAG ()

        // Assert
        Assert.Equal(4, nodeCount dag)
        Assert.True(hasNode "obs-frontend" dag)
        Assert.False(hasNode "obs-grafana" dag)

    [<Fact>]
    let ``UC-BOOT-004: Grafana-only chain has 3 containers`` () =
        // Arrange & Act
        let dag = buildGrafanaDAG ()

        // Assert
        Assert.Equal(3, nodeCount dag)
        Assert.True(hasNode "obs-grafana" dag)
        Assert.False(hasNode "obs-frontend" dag)

    [<Fact>]
    let ``UC-BOOT-005: Boot sequence has correct order - ClickHouse first`` () =
        // Arrange & Act
        let sequence = getFullObsBootSequence ()

        // Assert - ClickHouse must be first
        let chIdx = List.findIndex ((=) "obs-clickhouse") sequence.Order
        Assert.Equal(0, chIdx)

    [<Fact>]
    let ``UC-BOOT-006: Boot sequence - OTEL after ClickHouse`` () =
        // Arrange & Act
        let sequence = getFullObsBootSequence ()

        // Assert
        let chIdx = List.findIndex ((=) "obs-clickhouse") sequence.Order
        let otelIdx = List.findIndex ((=) "obs-otel-collector") sequence.Order
        Assert.True(chIdx < otelIdx, "ClickHouse should start before OTEL Collector")

    [<Fact>]
    let ``UC-BOOT-007: Boot sequence - Query after OTEL`` () =
        // Arrange & Act
        let sequence = getFullObsBootSequence ()

        // Assert
        let otelIdx = List.findIndex ((=) "obs-otel-collector") sequence.Order
        let queryIdx = List.findIndex ((=) "obs-query-service") sequence.Order
        Assert.True(otelIdx < queryIdx, "OTEL should start before Query Service")

    [<Fact>]
    let ``UC-BOOT-008: Boot sequence - Frontend after Query`` () =
        // Arrange & Act
        let sequence = getFullObsBootSequence ()

        // Assert
        let queryIdx = List.findIndex ((=) "obs-query-service") sequence.Order
        let frontendIdx = List.findIndex ((=) "obs-frontend") sequence.Order
        Assert.True(queryIdx < frontendIdx, "Query should start before Frontend")

    [<Fact>]
    let ``UC-BOOT-009: Boot sequence includes all containers`` () =
        // Arrange & Act
        let sequence = getFullObsBootSequence ()

        // Assert
        Assert.Equal(5, sequence.Order.Length)
        Assert.Contains("obs-clickhouse", sequence.Order)
        Assert.Contains("obs-otel-collector", sequence.Order)
        Assert.Contains("obs-query-service", sequence.Order)
        Assert.Contains("obs-frontend", sequence.Order)
        Assert.Contains("obs-grafana", sequence.Order)

    [<Fact>]
    let ``UC-BOOT-010: Boot sequence has positive estimated time`` () =
        // Arrange & Act
        let sequence = getFullObsBootSequence ()

        // Assert
        Assert.True(sequence.EstimatedTimeMs > 0L)

    [<Fact>]
    let ``UC-BOOT-011: Estimated boot time is reasonable`` () =
        // Arrange & Act
        let estimatedMs = estimateObsBootTimeMs ()

        // Assert - Should be based on layer count (4 layers * 30s = 120s)
        Assert.True(estimatedMs > 0L)
        Assert.True(estimatedMs <= 180000L)  // Max 3 minutes

    [<Fact>]
    let ``UC-BOOT-012: Partial start with ClickHouse only is valid`` () =
        // Arrange
        let chOnly = [Layer0.clickhouseContainer]

        // Act
        let dag = buildDAG chOnly

        // Assert
        Assert.Equal(1, nodeCount dag)
        Assert.True(hasNode "obs-clickhouse" dag)
        Assert.False(hasCycles dag)

    [<Fact>]
    let ``UC-BOOT-013: Boot layers map has correct layer count`` () =
        // Arrange & Act
        let sequence = getFullObsBootSequence ()

        // Assert - 4 layers (0, 1, 2, 3)
        Assert.True(sequence.Layers.Count >= 4)

    [<Fact>]
    let ``UC-BOOT-014: getObsContainersAtLayer returns correct containers`` () =
        // Act
        let layer0 = getObsContainersAtLayer 0
        let layer1 = getObsContainersAtLayer 1
        let layer2 = getObsContainersAtLayer 2
        let layer3 = getObsContainersAtLayer 3

        // Assert
        Assert.True(layer0 |> List.exists (fun c -> c.Name = "obs-clickhouse"))
        Assert.True(layer1 |> List.exists (fun c -> c.Name = "obs-otel-collector"))
        Assert.True(layer2 |> List.exists (fun c -> c.Name = "obs-query-service"))
        Assert.True(layer3 |> List.exists (fun c -> c.Name = "obs-frontend"))

    [<Fact>]
    let ``UC-BOOT-015: Maximum layer is 3 for full chain`` () =
        // Arrange
        let dag = buildFullObsDAG () |> assignLayers

        // Act
        let maxLayer = getMaxLayer dag

        // Assert
        Assert.Equal(3, maxLayer)

    // ========================================================================
    // SECTION 2: COMPONENT DEPENDENCY TESTS (UC-DEP-*) - 10 tests
    // ========================================================================

    [<Fact>]
    let ``UC-DEP-001: ClickHouse has no dependencies`` () =
        // Arrange
        let ch = Layer0.clickhouseContainer

        // Assert
        Assert.Empty(ch.DependsOn)
        Assert.Equal(Some 0, ch.Layer)

    [<Fact>]
    let ``UC-DEP-002: OTEL Collector depends on ClickHouse (Mandatory)`` () =
        // Arrange
        let otel = Layer1.otelCollectorContainer
        let dag = buildMinimalObsDAG ()

        // Act
        let depType = getDependencyType "obs-clickhouse" "obs-otel-collector" dag

        // Assert
        Assert.Single(otel.DependsOn) |> ignore
        Assert.Contains("obs-clickhouse", otel.DependsOn)
        Assert.Equal(Some Mandatory, depType)

    [<Fact>]
    let ``UC-DEP-003: Query Service depends on ClickHouse (Mandatory)`` () =
        // Arrange
        let dag = buildMinimalObsDAG ()

        // Act
        let depType = getDependencyType "obs-clickhouse" "obs-query-service" dag

        // Assert
        Assert.Equal(Some Mandatory, depType)

    [<Fact>]
    let ``UC-DEP-004: Query Service depends on OTEL (Optional)`` () =
        // Arrange
        let dag = buildMinimalObsDAG ()

        // Act
        let depType = getDependencyType "obs-otel-collector" "obs-query-service" dag

        // Assert
        Assert.Equal(Some Optional, depType)

    [<Fact>]
    let ``UC-DEP-005: Frontend depends on Query Service (Mandatory)`` () =
        // Arrange
        let dag = buildFullObsDAG ()

        // Act
        let depType = getDependencyType "obs-query-service" "obs-frontend" dag

        // Assert
        Assert.Equal(Some Mandatory, depType)

    [<Fact>]
    let ``UC-DEP-006: Grafana depends on ClickHouse (Mandatory)`` () =
        // Arrange
        let dag = buildFullObsDAG ()

        // Act
        let depType = getDependencyType "obs-clickhouse" "obs-grafana" dag

        // Assert
        Assert.Equal(Some Mandatory, depType)

    [<Fact>]
    let ``UC-DEP-007: No cyclic dependencies in obs chain`` () =
        // Arrange
        let dag = buildFullObsDAG ()

        // Act
        let hasCycle = hasCycles dag

        // Assert (SC-AGT-018)
        Assert.False(hasCycle)

    [<Fact>]
    let ``UC-DEP-008: All dependency targets exist`` () =
        // Arrange
        let dag = buildFullObsDAG ()

        // Act & Assert
        fullContainers
        |> List.iter (fun c ->
            c.DependsOn
            |> List.iter (fun dep ->
                Assert.True(hasNode dep dag, sprintf "Dependency %s not found" dep)))

    [<Fact>]
    let ``UC-DEP-009: No self-dependencies`` () =
        // Arrange & Assert
        fullContainers
        |> List.iter (fun c ->
            Assert.DoesNotContain(c.Name, c.DependsOn))

    [<Fact>]
    let ``UC-DEP-010: Transitive dependencies for frontend include ClickHouse`` () =
        // Arrange
        let dag = buildFullObsDAG ()

        // Act
        let deps = getTransitiveDependencies "obs-frontend" dag

        // Assert - frontend -> query -> clickhouse/otel -> clickhouse
        Assert.Contains("obs-query-service", deps)
        Assert.Contains("obs-clickhouse", deps)

    // ========================================================================
    // SECTION 3: HEALTH PROPAGATION TESTS (UC-HEALTH-*) - 10 tests
    // ========================================================================

    [<Fact>]
    let ``UC-HEALTH-001: ClickHouse health config has correct HTTP port`` () =
        // Act
        let config = Layer0.clickhouseHealthConfig

        // Assert
        Assert.Equal(8123, config.HttpPort)

    [<Fact>]
    let ``UC-HEALTH-002: OTEL Collector health config has correct gRPC port`` () =
        // Act
        let config = Layer1.otelCollectorHealthConfig

        // Assert
        Assert.Equal(4317, config.GrpcPort)
        Assert.Equal(4318, config.HttpPort)

    [<Fact>]
    let ``UC-HEALTH-003: Query Service health config has correct port`` () =
        // Act
        let config = Layer2.queryServiceHealthConfig

        // Assert
        Assert.Equal(8085, config.HttpPort)

    [<Fact>]
    let ``UC-HEALTH-004: Frontend health config has correct port`` () =
        // Act
        let config = Layer3.frontendHealthConfig

        // Assert
        Assert.Equal(8080, config.HttpPort)

    [<Fact>]
    let ``UC-HEALTH-005: Grafana health config has correct port`` () =
        // Act
        let config = Layer3.grafanaHealthConfig

        // Assert
        Assert.Equal(3000, config.HttpPort)

    [<Fact>]
    let ``UC-HEALTH-006: Health state transitions are valid`` () =
        // Arrange
        let dag = buildMinimalObsDAG ()

        // Act - Update health states
        let dag1 = updateHealthState "obs-clickhouse" HealthState.Starting dag
        let dag2 = updateHealthState "obs-clickhouse" HealthState.Healthy dag1
        let dag3 = updateHealthState "obs-clickhouse" HealthState.Degraded dag2

        // Assert
        Assert.Equal(Some HealthState.Starting, getHealthState "obs-clickhouse" dag1)
        Assert.Equal(Some HealthState.Healthy, getHealthState "obs-clickhouse" dag2)
        Assert.Equal(Some HealthState.Degraded, getHealthState "obs-clickhouse" dag3)

    [<Fact>]
    let ``UC-HEALTH-007: Dependencies satisfied when ClickHouse healthy`` () =
        // Arrange
        let healthySet = Set.ofList ["obs-clickhouse"]

        // Act
        let satisfied = areObsDependenciesSatisfied "obs-otel-collector" healthySet

        // Assert
        Assert.True(satisfied)

    [<Fact>]
    let ``UC-HEALTH-008: Dependencies not satisfied when ClickHouse missing`` () =
        // Arrange
        let healthySet = Set.empty

        // Act
        let satisfied = areObsDependenciesSatisfied "obs-otel-collector" healthySet

        // Assert
        Assert.False(satisfied)

    [<Fact>]
    let ``UC-HEALTH-009: Health config includes retry settings`` () =
        // Assert
        Assert.True(Layer0.clickhouseHealthConfig.Retries > 0)
        Assert.True(Layer1.otelCollectorHealthConfig.Retries > 0)
        Assert.True(Layer2.queryServiceHealthConfig.Retries > 0)
        Assert.True(Layer3.frontendHealthConfig.Retries > 0)
        Assert.True(Layer3.grafanaHealthConfig.Retries > 0)

    [<Fact>]
    let ``UC-HEALTH-010: Health config includes timeout`` () =
        // Assert
        Assert.True(Layer0.clickhouseHealthConfig.Timeout > TimeSpan.Zero)
        Assert.True(Layer1.otelCollectorHealthConfig.Timeout > TimeSpan.Zero)
        Assert.True(Layer2.queryServiceHealthConfig.Timeout > TimeSpan.Zero)
        Assert.True(Layer3.frontendHealthConfig.Timeout > TimeSpan.Zero)
        Assert.True(Layer3.grafanaHealthConfig.Timeout > TimeSpan.Zero)

    // ========================================================================
    // SECTION 4: STAMP COMPLIANCE TESTS (UC-STAMP-*) - 5 tests
    // ========================================================================

    [<Fact>]
    let ``UC-STAMP-001: SC-OBS-069 - Dual logging compliance check`` () =
        // Arrange
        let config = defaultObsConfig

        // Act
        let compliance = checkDualLoggingCompliance config

        // Assert
        Assert.Equal("SC-OBS-069", compliance.ConstraintId)
        Assert.True(compliance.TerminalLoggingActive)
        Assert.True(compliance.SigNozLoggingActive)
        Assert.True(compliance.IsCompliant)

    [<Fact>]
    let ``UC-STAMP-002: SC-OBS-071 - OTEL modules compliance check`` () =
        // Arrange
        let config = defaultObsConfig

        // Act
        let compliance = checkOtelModulesCompliance config

        // Assert
        Assert.Equal("SC-OBS-071", compliance.ConstraintId)
        Assert.True(compliance.TracesEnabled)
        Assert.True(compliance.MetricsEnabled)
        Assert.True(compliance.LogsEnabled)
        Assert.True(compliance.BaggageEnabled)
        Assert.Equal(4, compliance.TotalActive)
        Assert.True(compliance.IsCompliant)

    [<Fact>]
    let ``UC-STAMP-003: All images use localhost registry (SC-CNT-010)`` () =
        // Assert
        fullContainers
        |> List.iter (fun c ->
            Assert.True(c.Image.StartsWith("localhost/"),
                sprintf "Container %s uses non-localhost registry: %s" c.Name c.Image))

    [<Fact>]
    let ``UC-STAMP-004: All images are NixOS-based (SC-CNT-009)`` () =
        // Assert
        fullContainers
        |> List.iter (fun c ->
            Assert.True(c.Image.Contains("nixos"),
                sprintf "Container %s image does not contain 'nixos': %s" c.Name c.Image))

    [<Fact>]
    let ``UC-STAMP-005: All STAMP constraints pass for obs chain`` () =
        // Act
        let compliance = checkObsStampCompliance ()

        // Assert
        compliance |> Map.iter (fun constraint passed ->
            Assert.True(passed, sprintf "STAMP constraint %s failed" constraint))

    // ========================================================================
    // SECTION 5: CHAIN CONFIG & HELPER TESTS - 10 additional tests
    // ========================================================================

    [<Fact>]
    let ``Default obs config has correct chain ID`` () =
        // Arrange
        let config = defaultObsConfig

        // Assert
        Assert.Equal("indrajaal-obs-chain", config.ChainId)

    [<Fact>]
    let ``Default obs config has correct environment`` () =
        // Arrange
        let config = defaultObsConfig

        // Assert
        Assert.Equal("obs", config.Environment)

    [<Fact>]
    let ``Default obs config allows degraded visualizers`` () =
        // Arrange
        let config = defaultObsConfig

        // Assert
        Assert.True(config.AllowDegradedVisualizers)

    [<Fact>]
    let ``Default obs config has correct network`` () =
        // Arrange
        let config = defaultObsConfig

        // Assert
        Assert.Equal("indrajaal-obs-net", config.NetworkName)
        Assert.Equal("172.31.0.0/24", config.NetworkSubnet)

    [<Fact>]
    let ``Port map has all containers`` () =
        // Act
        let ports = obsPortMap

        // Assert
        Assert.True(ports.ContainsKey("obs-clickhouse"))
        Assert.True(ports.ContainsKey("obs-otel-collector"))
        Assert.True(ports.ContainsKey("obs-query-service"))
        Assert.True(ports.ContainsKey("obs-frontend"))
        Assert.True(ports.ContainsKey("obs-grafana"))

    [<Fact>]
    let ``Primary port map has correct assignments`` () =
        // Assert
        Assert.Equal(8123, obsPrimaryPortMap.["obs-clickhouse"])
        Assert.Equal(4317, obsPrimaryPortMap.["obs-otel-collector"])
        Assert.Equal(8085, obsPrimaryPortMap.["obs-query-service"])
        Assert.Equal(8080, obsPrimaryPortMap.["obs-frontend"])
        Assert.Equal(3000, obsPrimaryPortMap.["obs-grafana"])

    [<Fact>]
    let ``IP map has correct assignments`` () =
        // Assert
        Assert.Equal("172.31.0.10", obsIpMap.["obs-clickhouse"])
        Assert.Equal("172.31.0.20", obsIpMap.["obs-otel-collector"])
        Assert.Equal("172.31.0.30", obsIpMap.["obs-query-service"])
        Assert.Equal("172.31.0.40", obsIpMap.["obs-frontend"])
        Assert.Equal("172.31.0.50", obsIpMap.["obs-grafana"])

    [<Fact>]
    let ``getObsContainer finds existing containers`` () =
        // Assert
        Assert.True((getObsContainer "obs-clickhouse").IsSome)
        Assert.True((getObsContainer "obs-otel-collector").IsSome)
        Assert.True((getObsContainer "obs-query-service").IsSome)
        Assert.True((getObsContainer "obs-frontend").IsSome)
        Assert.True((getObsContainer "obs-grafana").IsSome)
        Assert.True((getObsContainer "non-existent").IsNone)

    [<Fact>]
    let ``isObsCoreContainer identifies core correctly`` () =
        // Assert
        Assert.True(isObsCoreContainer "obs-clickhouse")
        Assert.True(isObsCoreContainer "obs-otel-collector")
        Assert.True(isObsCoreContainer "obs-query-service")
        Assert.False(isObsCoreContainer "obs-frontend")
        Assert.False(isObsCoreContainer "obs-grafana")

    [<Fact>]
    let ``isVisualizerContainer identifies visualizers correctly`` () =
        // Assert
        Assert.False(isVisualizerContainer "obs-clickhouse")
        Assert.False(isVisualizerContainer "obs-otel-collector")
        Assert.False(isVisualizerContainer "obs-query-service")
        Assert.True(isVisualizerContainer "obs-frontend")
        Assert.True(isVisualizerContainer "obs-grafana")

    // ========================================================================
    // SECTION 6: SHUTDOWN & STATE TESTS - 5 additional tests
    // ========================================================================

    [<Fact>]
    let ``Shutdown order is reverse of boot order`` () =
        // Arrange
        let bootOrder = getFullObsBootSequence().Order
        let shutdownOrder = getObsShutdownOrder ()

        // Assert
        Assert.Equal<string list>(bootOrder |> List.rev, shutdownOrder)

    [<Fact>]
    let ``Initial boot progress has correct state`` () =
        // Arrange
        let progress = initialObsBootProgress

        // Assert
        Assert.Equal(NotStarted, progress.State)
        Assert.Equal(-1, progress.CurrentLayer)
        Assert.Empty(progress.StartedContainers)
        Assert.Empty(progress.HealthyContainers)
        Assert.Empty(progress.FailedContainers)
        Assert.Equal(0L, progress.ElapsedMs)
        Assert.True(progress.EstimatedRemainingMs > 0L)
        Assert.False(progress.DualLoggingActive)
        Assert.Equal(0, progress.OtelModulesActive)

    [<Fact>]
    let ``ObsChainState has all expected states`` () =
        // Arrange
        let states = [
            NotStarted
            BootingStorage
            BootingIngestion
            BootingQuery
            BootingVisualization
            Running
            DegradedNoFrontend "test"
            DegradedNoGrafana "test"
            Failed "test"
            ShuttingDown
        ]

        // Assert
        Assert.Equal(10, states.Length)

    [<Fact>]
    let ``ObsShutdownMode has all expected modes`` () =
        // Arrange
        let modes = [
            Graceful
            Emergency
            RetainStorage
            Partial ["obs-grafana"]
        ]

        // Assert
        Assert.Equal(4, modes.Length)

    [<Fact>]
    let ``getAllObsPorts returns all unique ports sorted`` () =
        // Act
        let ports = getAllObsPorts ()

        // Assert
        Assert.True(ports.Length > 0)
        Assert.Contains(4317, ports)  // OTEL gRPC
        Assert.Contains(4318, ports)  // OTEL HTTP
        Assert.Contains(8123, ports)  // ClickHouse
        Assert.Contains(8080, ports)  // SigNoz
        Assert.Contains(3000, ports)  // Grafana
        // Verify sorted
        Assert.Equal<int list>(ports, ports |> List.sort)

    // ========================================================================
    // SECTION 7: VALIDATION & FPPS TESTS - 5 additional tests
    // ========================================================================

    [<Fact>]
    let ``validateObsChain returns Ok for valid config`` () =
        // Act
        let result = validateObsChain ()

        // Assert
        match result with
        | Ok dag ->
            Assert.True(dag.IsValid)
            Assert.Equal(5, nodeCount dag)
        | Error errs ->
            Assert.Fail(sprintf "Expected Ok, got Error: %s" (String.concat "; " errs))

    [<Fact>]
    let ``buildValidatedObsDAG returns Ok for valid containers`` () =
        // Act
        let result = buildValidatedObsDAG coreContainers

        // Assert
        match result with
        | Ok dag ->
            Assert.True(dag.IsValid)
            Assert.Equal(3, nodeCount dag)
        | Error errs ->
            Assert.Fail(sprintf "Expected Ok, got Error: %s" (String.concat "; " errs))

    [<Fact>]
    let ``Default FPPS config enables all methods`` () =
        // Act
        let config = defaultObsFPPSConfig

        // Assert
        Assert.True(config.EnablePodmanStatus)
        Assert.True(config.EnableHealthEndpoint)
        Assert.True(config.EnablePortProbe)
        Assert.True(config.EnableProcessCheck)
        Assert.True(config.EnableLogAnalysis)

    [<Fact>]
    let ``FPPS config has OTEL-specific error patterns`` () =
        // Act
        let config = defaultObsFPPSConfig

        // Assert
        Assert.True(config.OtelErrorPatterns.Length > 0)
        Assert.Contains("failed to export", config.OtelErrorPatterns)
        Assert.Contains("connection refused", config.OtelErrorPatterns)

    [<Fact>]
    let ``FPPS config has ClickHouse-specific error patterns`` () =
        // Act
        let config = defaultObsFPPSConfig

        // Assert
        Assert.True(config.ClickHouseErrorPatterns.Length > 0)
        Assert.Contains("DB::Exception", config.ClickHouseErrorPatterns)

    // ========================================================================
    // SECTION 8: ELIXIR INTEGRATION TESTS - 5 additional tests
    // ========================================================================

    [<Fact>]
    let ``Default Elixir telemetry config has correct OTLP endpoint`` () =
        // Act
        let config = defaultElixirTelemetryConfig

        // Assert
        Assert.Equal("http://localhost:4317", config.OtlpTraceEndpoint)
        Assert.Equal("http://localhost:4317", config.OtlpMetricsEndpoint)
        Assert.Equal("http://localhost:4317", config.OtlpLogsEndpoint)

    [<Fact>]
    let ``Default Elixir telemetry config has correct service name`` () =
        // Act
        let config = defaultElixirTelemetryConfig

        // Assert
        Assert.Equal("indrajaal", config.ServiceName)
        Assert.Equal("indrajaal-ns", config.ServiceNamespace)

    [<Fact>]
    let ``Default Elixir telemetry config has valid sampling rate`` () =
        // Act
        let config = defaultElixirTelemetryConfig

        // Assert
        Assert.True(config.SamplingRate >= 0.0)
        Assert.True(config.SamplingRate <= 1.0)

    [<Fact>]
    let ``generateElixirOtlpConfig produces valid config`` () =
        // Arrange
        let config = defaultElixirTelemetryConfig

        // Act
        let elixirConfig = generateElixirOtlpConfig config

        // Assert
        Assert.False(String.IsNullOrEmpty(elixirConfig))
        Assert.Contains("opentelemetry", elixirConfig)
        Assert.Contains(config.OtlpTraceEndpoint, elixirConfig)
        Assert.Contains(config.ServiceName, elixirConfig)

    [<Fact>]
    let ``generateObsChainSummary returns non-empty string`` () =
        // Act
        let summary = generateObsChainSummary ()

        // Assert
        Assert.False(String.IsNullOrEmpty(summary))
        Assert.Contains("INTELITOR OBSERVABILITY CHAIN SUMMARY", summary)
        Assert.Contains("COMPONENTS:", summary)
        Assert.Contains("BOOT SEQUENCE:", summary)
        Assert.Contains("PORT MAPPING:", summary)
        Assert.Contains("STAMP COMPLIANCE:", summary)
        Assert.Contains("LAYER STRUCTURE:", summary)
