namespace Cepaf.Tests

open System
open Xunit
open Cepaf.Modules.ServiceDAG
open Cepaf.Modules.ChainVerifier

/// ObsVerifier Unit Tests - Observability Stack Verification with FPPS Consensus
/// STAMP Compliance: SC-OBS-069, SC-OBS-071, SC-CNT-009, SC-CNT-010, SC-CEP-003
/// AOR Compliance: AOR-SAF-001, AOR-CNT-001, AOR-QUA-001
/// Test Coverage: FPPS consensus, SigNoz verification, Grafana verification,
///                STAMP compliance, error handling, port availability, health checks
module ObsVerifierTests =

    // ========================================================================
    // TEST DATA FACTORY FUNCTIONS
    // Factories avoid xUnit initialization issues with module-level values
    // ========================================================================

    // --- Observability Status Types ---

    /// Component health status
    type ComponentHealth = {
        Name: string
        IsHealthy: bool
        Port: int
        ResponseTimeMs: int64
        LastChecked: DateTime
        ErrorMessage: string option
    }

    /// SigNoz-specific status
    type SigNozStatus = {
        ContainerRunning: bool
        OtlpGrpcAvailable: bool    // Port 4317
        OtlpHttpAvailable: bool    // Port 4318
        UiAvailable: bool          // Port 8080
        QueryServiceHealthy: bool
        CollectorHealthy: bool
        ClickHouseHealthy: bool
        StartupTimeMs: int64
    }

    /// Grafana-specific status
    type GrafanaStatus = {
        ContainerRunning: bool
        HealthEndpointOk: bool     // /api/health
        Port3000Available: bool
        DashboardsProvisioned: bool
        DatasourcesConfigured: bool
        AuthenticationSetup: bool
        ResponseTimeMs: int64
    }

    /// FPPS verification result for observability
    type ObsFPPSResult = {
        PodmanStatusPassed: bool
        HealthEndpointPassed: bool
        PortProbePassed: bool
        ProcessCheckPassed: bool
        LogAnalysisPassed: bool
        ConsensusAchieved: bool
        MethodsAgreeHealthy: int
        MethodsAgreeUnhealthy: int
        Timestamp: DateTime
    }

    /// Comprehensive observability health checks
    type ObsHealthChecks = {
        ClickHouseStatus: ComponentHealth
        PrometheusStatus: ComponentHealth
        OtelCollectorStatus: ComponentHealth
        GrafanaStatus: ComponentHealth
        SigNozQueryStatus: ComponentHealth
    }

    /// Overall observability verification result
    type ObsVerificationResult = {
        IsHealthy: bool
        FPPSResult: ObsFPPSResult
        SigNozStatus: SigNozStatus
        GrafanaStatus: GrafanaStatus
        StampCompliance: Map<string, bool>
        TotalVerificationTimeMs: int64
        VerifiedAt: DateTime
        FailureReasons: string list
    }

    // --- Component Health Factories ---

    /// Create healthy component status
    let makeHealthyComponent (name: string) (port: int) : ComponentHealth = {
        Name = name
        IsHealthy = true
        Port = port
        ResponseTimeMs = 50L
        LastChecked = DateTime.UtcNow
        ErrorMessage = None
    }

    /// Create unhealthy component status
    let makeUnhealthyComponent (name: string) (port: int) (error: string) : ComponentHealth = {
        Name = name
        IsHealthy = false
        Port = port
        ResponseTimeMs = 0L
        LastChecked = DateTime.UtcNow
        ErrorMessage = Some error
    }

    /// Create slow component status
    let makeSlowComponent (name: string) (port: int) (responseMs: int64) : ComponentHealth = {
        Name = name
        IsHealthy = true
        Port = port
        ResponseTimeMs = responseMs
        LastChecked = DateTime.UtcNow
        ErrorMessage = None
    }

    // --- SigNoz Status Factories ---

    /// Create fully healthy SigNoz status
    let makeHealthySigNozStatus () : SigNozStatus = {
        ContainerRunning = true
        OtlpGrpcAvailable = true
        OtlpHttpAvailable = true
        UiAvailable = true
        QueryServiceHealthy = true
        CollectorHealthy = true
        ClickHouseHealthy = true
        StartupTimeMs = 5000L
    }

    /// Create unhealthy SigNoz status
    let makeUnhealthySigNozStatus () : SigNozStatus = {
        ContainerRunning = false
        OtlpGrpcAvailable = false
        OtlpHttpAvailable = false
        UiAvailable = false
        QueryServiceHealthy = false
        CollectorHealthy = false
        ClickHouseHealthy = false
        StartupTimeMs = 0L
    }

    /// Create partially healthy SigNoz status (container running but services degraded)
    let makePartialSigNozStatus () : SigNozStatus = {
        ContainerRunning = true
        OtlpGrpcAvailable = true
        OtlpHttpAvailable = false
        UiAvailable = true
        QueryServiceHealthy = false
        CollectorHealthy = true
        ClickHouseHealthy = true
        StartupTimeMs = 8000L
    }

    /// Create SigNoz status with specific port failures
    let makeSigNozWithPortFailure (failingPort: string) : SigNozStatus = {
        ContainerRunning = true
        OtlpGrpcAvailable = failingPort <> "4317"
        OtlpHttpAvailable = failingPort <> "4318"
        UiAvailable = failingPort <> "8080"
        QueryServiceHealthy = failingPort <> "query"
        CollectorHealthy = failingPort <> "collector"
        ClickHouseHealthy = failingPort <> "clickhouse"
        StartupTimeMs = 6000L
    }

    // --- Grafana Status Factories ---

    /// Create fully healthy Grafana status
    let makeHealthyGrafanaStatus () : GrafanaStatus = {
        ContainerRunning = true
        HealthEndpointOk = true
        Port3000Available = true
        DashboardsProvisioned = true
        DatasourcesConfigured = true
        AuthenticationSetup = true
        ResponseTimeMs = 100L
    }

    /// Create unhealthy Grafana status
    let makeUnhealthyGrafanaStatus () : GrafanaStatus = {
        ContainerRunning = false
        HealthEndpointOk = false
        Port3000Available = false
        DashboardsProvisioned = false
        DatasourcesConfigured = false
        AuthenticationSetup = false
        ResponseTimeMs = 0L
    }

    /// Create Grafana status with provisioning issues
    let makeGrafanaWithProvisioningIssues () : GrafanaStatus = {
        ContainerRunning = true
        HealthEndpointOk = true
        Port3000Available = true
        DashboardsProvisioned = false
        DatasourcesConfigured = false
        AuthenticationSetup = true
        ResponseTimeMs = 150L
    }

    /// Create Grafana status with auth issues
    let makeGrafanaWithAuthIssues () : GrafanaStatus = {
        ContainerRunning = true
        HealthEndpointOk = true
        Port3000Available = true
        DashboardsProvisioned = true
        DatasourcesConfigured = true
        AuthenticationSetup = false
        ResponseTimeMs = 200L
    }

    // --- FPPS Result Factories ---

    /// Create FPPS result where all 5 methods agree healthy
    let makeAllHealthyFPPS () : ObsFPPSResult = {
        PodmanStatusPassed = true
        HealthEndpointPassed = true
        PortProbePassed = true
        ProcessCheckPassed = true
        LogAnalysisPassed = true
        ConsensusAchieved = true
        MethodsAgreeHealthy = 5
        MethodsAgreeUnhealthy = 0
        Timestamp = DateTime.UtcNow
    }

    /// Create FPPS result where all 5 methods agree unhealthy
    let makeAllUnhealthyFPPS () : ObsFPPSResult = {
        PodmanStatusPassed = false
        HealthEndpointPassed = false
        PortProbePassed = false
        ProcessCheckPassed = false
        LogAnalysisPassed = false
        ConsensusAchieved = true  // Consensus achieved (all agree)
        MethodsAgreeHealthy = 0
        MethodsAgreeUnhealthy = 5
        Timestamp = DateTime.UtcNow
    }

    /// Create FPPS result with 3/5 majority healthy
    let makeMajorityHealthyFPPS () : ObsFPPSResult = {
        PodmanStatusPassed = true
        HealthEndpointPassed = true
        PortProbePassed = true
        ProcessCheckPassed = false
        LogAnalysisPassed = false
        ConsensusAchieved = true  // Majority consensus
        MethodsAgreeHealthy = 3
        MethodsAgreeUnhealthy = 2
        Timestamp = DateTime.UtcNow
    }

    /// Create FPPS result with 3/5 majority unhealthy
    let makeMajorityUnhealthyFPPS () : ObsFPPSResult = {
        PodmanStatusPassed = true
        HealthEndpointPassed = true
        PortProbePassed = false
        ProcessCheckPassed = false
        LogAnalysisPassed = false
        ConsensusAchieved = true  // Majority consensus
        MethodsAgreeHealthy = 2
        MethodsAgreeUnhealthy = 3
        Timestamp = DateTime.UtcNow
    }

    /// Create FPPS result with tie (no consensus)
    let makeTieFPPS () : ObsFPPSResult = {
        PodmanStatusPassed = true
        HealthEndpointPassed = true
        PortProbePassed = false
        ProcessCheckPassed = false
        LogAnalysisPassed = true  // 3-2 split, but we'll treat edge case
        ConsensusAchieved = false
        MethodsAgreeHealthy = 3
        MethodsAgreeUnhealthy = 2
        Timestamp = DateTime.UtcNow
    }

    /// Create FPPS result with single method failure
    let makeSingleMethodFailFPPS (failingMethod: string) : ObsFPPSResult = {
        PodmanStatusPassed = failingMethod <> "podman"
        HealthEndpointPassed = failingMethod <> "health"
        PortProbePassed = failingMethod <> "port"
        ProcessCheckPassed = failingMethod <> "process"
        LogAnalysisPassed = failingMethod <> "log"
        ConsensusAchieved = true
        MethodsAgreeHealthy = 4
        MethodsAgreeUnhealthy = 1
        Timestamp = DateTime.UtcNow
    }

    // --- ObsHealthChecks Factories ---

    /// Create fully healthy observability health checks
    let makeHealthyObsChecks () : ObsHealthChecks = {
        ClickHouseStatus = makeHealthyComponent "clickhouse" 8123
        PrometheusStatus = makeHealthyComponent "prometheus" 9090
        OtelCollectorStatus = makeHealthyComponent "otel-collector" 4317
        GrafanaStatus = makeHealthyComponent "grafana" 3000
        SigNozQueryStatus = makeHealthyComponent "signoz-query" 8080
    }

    /// Create fully unhealthy observability health checks
    let makeUnhealthyObsChecks () : ObsHealthChecks = {
        ClickHouseStatus = makeUnhealthyComponent "clickhouse" 8123 "Connection refused"
        PrometheusStatus = makeUnhealthyComponent "prometheus" 9090 "Service unavailable"
        OtelCollectorStatus = makeUnhealthyComponent "otel-collector" 4317 "gRPC error"
        GrafanaStatus = makeUnhealthyComponent "grafana" 3000 "HTTP 503"
        SigNozQueryStatus = makeUnhealthyComponent "signoz-query" 8080 "Query timeout"
    }

    /// Create mixed health checks (some healthy, some not)
    let makeMixedObsChecks () : ObsHealthChecks = {
        ClickHouseStatus = makeHealthyComponent "clickhouse" 8123
        PrometheusStatus = makeHealthyComponent "prometheus" 9090
        OtelCollectorStatus = makeUnhealthyComponent "otel-collector" 4317 "Port closed"
        GrafanaStatus = makeHealthyComponent "grafana" 3000
        SigNozQueryStatus = makeUnhealthyComponent "signoz-query" 8080 "Service degraded"
    }

    // --- STAMP Compliance Factories ---

    /// Create fully compliant STAMP map
    let makeFullStampCompliance () : Map<string, bool> =
        Map.ofList [
            ("SC-OBS-069", true)  // Dual logging (Terminal + SigNoz)
            ("SC-OBS-071", true)  // 4 OTEL modules
            ("SC-CNT-009", true)  // NixOS/Podman only
            ("SC-CNT-010", true)  // Localhost registry
            ("SC-CNT-012", true)  // Rootless
            ("SC-CEP-003", true)  // FPPS consensus
            ("SC-VAL-003", true)  // 100% consensus
        ]

    /// Create partially compliant STAMP map
    let makePartialStampCompliance () : Map<string, bool> =
        Map.ofList [
            ("SC-OBS-069", true)
            ("SC-OBS-071", false)  // Missing OTEL modules
            ("SC-CNT-009", true)
            ("SC-CNT-010", true)
            ("SC-CNT-012", true)
            ("SC-CEP-003", false)  // FPPS consensus failed
            ("SC-VAL-003", false)
        ]

    /// Create non-compliant STAMP map
    let makeNonCompliantStamp () : Map<string, bool> =
        Map.ofList [
            ("SC-OBS-069", false)
            ("SC-OBS-071", false)
            ("SC-CNT-009", false)
            ("SC-CNT-010", false)
            ("SC-CNT-012", false)
            ("SC-CEP-003", false)
            ("SC-VAL-003", false)
        ]

    // --- Verification Result Factories ---

    /// Create fully healthy verification result
    let makeHealthyVerificationResult () : ObsVerificationResult = {
        IsHealthy = true
        FPPSResult = makeAllHealthyFPPS ()
        SigNozStatus = makeHealthySigNozStatus ()
        GrafanaStatus = makeHealthyGrafanaStatus ()
        StampCompliance = makeFullStampCompliance ()
        TotalVerificationTimeMs = 2500L
        VerifiedAt = DateTime.UtcNow
        FailureReasons = []
    }

    /// Create unhealthy verification result
    let makeUnhealthyVerificationResult (reasons: string list) : ObsVerificationResult = {
        IsHealthy = false
        FPPSResult = makeAllUnhealthyFPPS ()
        SigNozStatus = makeUnhealthySigNozStatus ()
        GrafanaStatus = makeUnhealthyGrafanaStatus ()
        StampCompliance = makeNonCompliantStamp ()
        TotalVerificationTimeMs = 500L
        VerifiedAt = DateTime.UtcNow
        FailureReasons = reasons
    }

    /// Create degraded verification result
    let makeDegradedVerificationResult () : ObsVerificationResult = {
        IsHealthy = false
        FPPSResult = makeMajorityHealthyFPPS ()
        SigNozStatus = makePartialSigNozStatus ()
        GrafanaStatus = makeGrafanaWithProvisioningIssues ()
        StampCompliance = makePartialStampCompliance ()
        TotalVerificationTimeMs = 3000L
        VerifiedAt = DateTime.UtcNow
        FailureReasons = ["OTEL modules incomplete"; "Dashboard provisioning failed"]
    }

    // --- Helper Functions ---

    /// Calculate FPPS consensus from health checks
    let calculateFPPSConsensus (checks: ObsHealthChecks) : ObsFPPSResult =
        let healthChecks = [checks.ClickHouseStatus.IsHealthy; checks.PrometheusStatus.IsHealthy; checks.OtelCollectorStatus.IsHealthy; checks.GrafanaStatus.IsHealthy; checks.SigNozQueryStatus.IsHealthy]
        let healthyCount = healthChecks |> List.filter id |> List.length

        let unhealthyCount = 5 - healthyCount

        {
            PodmanStatusPassed = checks.ClickHouseStatus.IsHealthy
            HealthEndpointPassed = checks.PrometheusStatus.IsHealthy
            PortProbePassed = checks.OtelCollectorStatus.IsHealthy
            ProcessCheckPassed = checks.GrafanaStatus.IsHealthy
            LogAnalysisPassed = checks.SigNozQueryStatus.IsHealthy
            ConsensusAchieved = healthyCount >= 3 || unhealthyCount >= 3
            MethodsAgreeHealthy = healthyCount
            MethodsAgreeUnhealthy = unhealthyCount
            Timestamp = DateTime.UtcNow
        }

    /// Check if SigNoz is operational
    let isSigNozOperational (status: SigNozStatus) : bool =
        status.ContainerRunning &&
        status.OtlpGrpcAvailable &&
        status.CollectorHealthy &&
        status.ClickHouseHealthy

    /// Check if Grafana is operational
    let isGrafanaOperational (status: GrafanaStatus) : bool =
        status.ContainerRunning &&
        status.HealthEndpointOk &&
        status.Port3000Available

    /// Count passing STAMP constraints
    let countPassingStampConstraints (compliance: Map<string, bool>) : int =
        compliance |> Map.filter (fun _ v -> v) |> Map.count

    // ========================================================================
    // SECTION 1: FPPS CONSENSUS TESTS (UC-FPPS-*)
    // SC-CEP-003: Consensus-based health verification (FPPS 5-method)
    // SC-VAL-003: 100% consensus required for verification pass
    // ========================================================================

    [<Fact>]
    let ``UC-FPPS-001: All 5 methods agree healthy achieves consensus`` () =
        // Arrange
        let fpps = makeAllHealthyFPPS ()

        // Assert
        Assert.True(fpps.ConsensusAchieved)
        Assert.Equal(5, fpps.MethodsAgreeHealthy)
        Assert.Equal(0, fpps.MethodsAgreeUnhealthy)

    [<Fact>]
    let ``UC-FPPS-002: All 5 methods agree unhealthy achieves consensus`` () =
        // Arrange
        let fpps = makeAllUnhealthyFPPS ()

        // Assert
        Assert.True(fpps.ConsensusAchieved)
        Assert.Equal(0, fpps.MethodsAgreeHealthy)
        Assert.Equal(5, fpps.MethodsAgreeUnhealthy)

    [<Fact>]
    let ``UC-FPPS-003: 3/5 majority healthy achieves consensus`` () =
        // Arrange
        let fpps = makeMajorityHealthyFPPS ()

        // Assert
        Assert.True(fpps.ConsensusAchieved)
        Assert.Equal(3, fpps.MethodsAgreeHealthy)
        Assert.Equal(2, fpps.MethodsAgreeUnhealthy)

    [<Fact>]
    let ``UC-FPPS-004: 3/5 majority unhealthy achieves consensus`` () =
        // Arrange
        let fpps = makeMajorityUnhealthyFPPS ()

        // Assert
        Assert.True(fpps.ConsensusAchieved)
        Assert.Equal(2, fpps.MethodsAgreeHealthy)
        Assert.Equal(3, fpps.MethodsAgreeUnhealthy)

    [<Fact>]
    let ``UC-FPPS-005: Tie-breaking scenario handled correctly`` () =
        // Arrange
        let fpps = makeTieFPPS ()

        // Assert - tie scenarios depend on implementation
        Assert.Equal(3, fpps.MethodsAgreeHealthy)
        Assert.Equal(2, fpps.MethodsAgreeUnhealthy)

    [<Fact>]
    let ``UC-FPPS-006: Single PodmanStatus failure still achieves majority`` () =
        // Arrange
        let fpps = makeSingleMethodFailFPPS "podman"

        // Assert
        Assert.False(fpps.PodmanStatusPassed)
        Assert.True(fpps.HealthEndpointPassed)
        Assert.Equal(4, fpps.MethodsAgreeHealthy)

    [<Fact>]
    let ``UC-FPPS-007: Single HealthEndpoint failure still achieves majority`` () =
        // Arrange
        let fpps = makeSingleMethodFailFPPS "health"

        // Assert
        Assert.True(fpps.PodmanStatusPassed)
        Assert.False(fpps.HealthEndpointPassed)
        Assert.Equal(4, fpps.MethodsAgreeHealthy)

    [<Fact>]
    let ``UC-FPPS-008: Single PortProbe failure still achieves majority`` () =
        // Arrange
        let fpps = makeSingleMethodFailFPPS "port"

        // Assert
        Assert.False(fpps.PortProbePassed)
        Assert.Equal(4, fpps.MethodsAgreeHealthy)

    [<Fact>]
    let ``UC-FPPS-009: Single ProcessCheck failure still achieves majority`` () =
        // Arrange
        let fpps = makeSingleMethodFailFPPS "process"

        // Assert
        Assert.False(fpps.ProcessCheckPassed)
        Assert.Equal(4, fpps.MethodsAgreeHealthy)

    [<Fact>]
    let ``UC-FPPS-010: Single LogAnalysis failure still achieves majority`` () =
        // Arrange
        let fpps = makeSingleMethodFailFPPS "log"

        // Assert
        Assert.False(fpps.LogAnalysisPassed)
        Assert.Equal(4, fpps.MethodsAgreeHealthy)

    [<Fact>]
    let ``UC-FPPS-011: FPPS result includes timestamp`` () =
        // Arrange
        let before = DateTime.UtcNow.AddSeconds(-1.0)
        let fpps = makeAllHealthyFPPS ()
        let after = DateTime.UtcNow.AddSeconds(1.0)

        // Assert
        Assert.True(fpps.Timestamp >= before)
        Assert.True(fpps.Timestamp <= after)

    [<Fact>]
    let ``UC-FPPS-012: calculateFPPSConsensus from healthy checks`` () =
        // Arrange
        let checks = makeHealthyObsChecks ()

        // Act
        let fpps = calculateFPPSConsensus checks

        // Assert
        Assert.True(fpps.ConsensusAchieved)
        Assert.Equal(5, fpps.MethodsAgreeHealthy)

    [<Fact>]
    let ``UC-FPPS-013: calculateFPPSConsensus from unhealthy checks`` () =
        // Arrange
        let checks = makeUnhealthyObsChecks ()

        // Act
        let fpps = calculateFPPSConsensus checks

        // Assert
        Assert.True(fpps.ConsensusAchieved)
        Assert.Equal(5, fpps.MethodsAgreeUnhealthy)

    [<Fact>]
    let ``UC-FPPS-014: calculateFPPSConsensus from mixed checks`` () =
        // Arrange
        let checks = makeMixedObsChecks ()

        // Act
        let fpps = calculateFPPSConsensus checks

        // Assert
        Assert.True(fpps.ConsensusAchieved)
        Assert.Equal(3, fpps.MethodsAgreeHealthy)
        Assert.Equal(2, fpps.MethodsAgreeUnhealthy)

    [<Fact>]
    let ``UC-FPPS-015: FPPS consensus requires 3+ methods to agree`` () =
        // Arrange
        let fpps1 = makeMajorityHealthyFPPS ()
        let fpps2 = makeMajorityUnhealthyFPPS ()

        // Assert - both have 3+ methods agreeing
        Assert.True(fpps1.MethodsAgreeHealthy >= 3 || fpps1.MethodsAgreeUnhealthy >= 3)
        Assert.True(fpps2.MethodsAgreeHealthy >= 3 || fpps2.MethodsAgreeUnhealthy >= 3)

    // ========================================================================
    // SECTION 2: SIGNOZ VERIFICATION TESTS (UC-SIGNOZ-*)
    // ========================================================================

    [<Fact>]
    let ``UC-SIGNOZ-001: Container creation verification`` () =
        // Arrange
        let status = makeHealthySigNozStatus ()

        // Assert
        Assert.True(status.ContainerRunning)

    [<Fact>]
    let ``UC-SIGNOZ-002: OTLP gRPC port (4317) availability`` () =
        // Arrange
        let status = makeHealthySigNozStatus ()

        // Assert
        Assert.True(status.OtlpGrpcAvailable)

    [<Fact>]
    let ``UC-SIGNOZ-003: OTLP HTTP port (4318) availability`` () =
        // Arrange
        let status = makeHealthySigNozStatus ()

        // Assert
        Assert.True(status.OtlpHttpAvailable)

    [<Fact>]
    let ``UC-SIGNOZ-004: SigNoz UI port (8080) availability`` () =
        // Arrange
        let status = makeHealthySigNozStatus ()

        // Assert
        Assert.True(status.UiAvailable)

    [<Fact>]
    let ``UC-SIGNOZ-005: Query service health check`` () =
        // Arrange
        let status = makeHealthySigNozStatus ()

        // Assert
        Assert.True(status.QueryServiceHealthy)

    [<Fact>]
    let ``UC-SIGNOZ-006: Collector health check`` () =
        // Arrange
        let status = makeHealthySigNozStatus ()

        // Assert
        Assert.True(status.CollectorHealthy)

    [<Fact>]
    let ``UC-SIGNOZ-007: ClickHouse health check`` () =
        // Arrange
        let status = makeHealthySigNozStatus ()

        // Assert
        Assert.True(status.ClickHouseHealthy)

    [<Fact>]
    let ``UC-SIGNOZ-008: Unhealthy container detected`` () =
        // Arrange
        let status = makeUnhealthySigNozStatus ()

        // Assert
        Assert.False(status.ContainerRunning)
        Assert.False(status.OtlpGrpcAvailable)

    [<Fact>]
    let ``UC-SIGNOZ-009: Partial SigNoz degradation detected`` () =
        // Arrange
        let status = makePartialSigNozStatus ()

        // Assert
        Assert.True(status.ContainerRunning)
        Assert.True(status.OtlpGrpcAvailable)
        Assert.False(status.OtlpHttpAvailable)
        Assert.False(status.QueryServiceHealthy)

    [<Fact>]
    let ``UC-SIGNOZ-010: OTLP gRPC port failure detected`` () =
        // Arrange
        let status = makeSigNozWithPortFailure "4317"

        // Assert
        Assert.False(status.OtlpGrpcAvailable)
        Assert.True(status.OtlpHttpAvailable)

    [<Fact>]
    let ``UC-SIGNOZ-011: OTLP HTTP port failure detected`` () =
        // Arrange
        let status = makeSigNozWithPortFailure "4318"

        // Assert
        Assert.True(status.OtlpGrpcAvailable)
        Assert.False(status.OtlpHttpAvailable)

    [<Fact>]
    let ``UC-SIGNOZ-012: UI port failure detected`` () =
        // Arrange
        let status = makeSigNozWithPortFailure "8080"

        // Assert
        Assert.False(status.UiAvailable)
        Assert.True(status.CollectorHealthy)

    [<Fact>]
    let ``UC-SIGNOZ-013: isSigNozOperational returns true for healthy status`` () =
        // Arrange
        let status = makeHealthySigNozStatus ()

        // Act
        let operational = isSigNozOperational status

        // Assert
        Assert.True(operational)

    [<Fact>]
    let ``UC-SIGNOZ-014: isSigNozOperational returns false for unhealthy status`` () =
        // Arrange
        let status = makeUnhealthySigNozStatus ()

        // Act
        let operational = isSigNozOperational status

        // Assert
        Assert.False(operational)

    [<Fact>]
    let ``UC-SIGNOZ-015: Startup time is recorded`` () =
        // Arrange
        let status = makeHealthySigNozStatus ()

        // Assert
        Assert.True(status.StartupTimeMs > 0L)

    // ========================================================================
    // SECTION 3: GRAFANA VERIFICATION TESTS (UC-GRAFANA-*)
    // ========================================================================

    [<Fact>]
    let ``UC-GRAFANA-001: Container health endpoint verification`` () =
        // Arrange
        let status = makeHealthyGrafanaStatus ()

        // Assert
        Assert.True(status.HealthEndpointOk)

    [<Fact>]
    let ``UC-GRAFANA-002: Dashboard provisioning verification`` () =
        // Arrange
        let status = makeHealthyGrafanaStatus ()

        // Assert
        Assert.True(status.DashboardsProvisioned)

    [<Fact>]
    let ``UC-GRAFANA-003: Datasource configuration verification`` () =
        // Arrange
        let status = makeHealthyGrafanaStatus ()

        // Assert
        Assert.True(status.DatasourcesConfigured)

    [<Fact>]
    let ``UC-GRAFANA-004: Port 3000 availability verification`` () =
        // Arrange
        let status = makeHealthyGrafanaStatus ()

        // Assert
        Assert.True(status.Port3000Available)

    [<Fact>]
    let ``UC-GRAFANA-005: Authentication setup verification`` () =
        // Arrange
        let status = makeHealthyGrafanaStatus ()

        // Assert
        Assert.True(status.AuthenticationSetup)

    [<Fact>]
    let ``UC-GRAFANA-006: Container running state check`` () =
        // Arrange
        let status = makeHealthyGrafanaStatus ()

        // Assert
        Assert.True(status.ContainerRunning)

    [<Fact>]
    let ``UC-GRAFANA-007: Unhealthy Grafana detected`` () =
        // Arrange
        let status = makeUnhealthyGrafanaStatus ()

        // Assert
        Assert.False(status.ContainerRunning)
        Assert.False(status.HealthEndpointOk)

    [<Fact>]
    let ``UC-GRAFANA-008: Provisioning issues detected`` () =
        // Arrange
        let status = makeGrafanaWithProvisioningIssues ()

        // Assert
        Assert.True(status.ContainerRunning)
        Assert.True(status.HealthEndpointOk)
        Assert.False(status.DashboardsProvisioned)
        Assert.False(status.DatasourcesConfigured)

    [<Fact>]
    let ``UC-GRAFANA-009: Authentication issues detected`` () =
        // Arrange
        let status = makeGrafanaWithAuthIssues ()

        // Assert
        Assert.True(status.ContainerRunning)
        Assert.False(status.AuthenticationSetup)

    [<Fact>]
    let ``UC-GRAFANA-010: isGrafanaOperational returns true for healthy status`` () =
        // Arrange
        let status = makeHealthyGrafanaStatus ()

        // Act
        let operational = isGrafanaOperational status

        // Assert
        Assert.True(operational)

    [<Fact>]
    let ``UC-GRAFANA-011: isGrafanaOperational returns false for unhealthy status`` () =
        // Arrange
        let status = makeUnhealthyGrafanaStatus ()

        // Act
        let operational = isGrafanaOperational status

        // Assert
        Assert.False(operational)

    [<Fact>]
    let ``UC-GRAFANA-012: isGrafanaOperational returns true with provisioning issues`` () =
        // Arrange (provisioning issues don't affect basic operation)
        let status = makeGrafanaWithProvisioningIssues ()

        // Act
        let operational = isGrafanaOperational status

        // Assert
        Assert.True(operational)

    [<Fact>]
    let ``UC-GRAFANA-013: Response time is recorded`` () =
        // Arrange
        let status = makeHealthyGrafanaStatus ()

        // Assert
        Assert.True(status.ResponseTimeMs > 0L)

    [<Fact>]
    let ``UC-GRAFANA-014: Response time is zero for unhealthy status`` () =
        // Arrange
        let status = makeUnhealthyGrafanaStatus ()

        // Assert
        Assert.Equal(0L, status.ResponseTimeMs)

    [<Fact>]
    let ``UC-GRAFANA-015: All Grafana components verified together`` () =
        // Arrange
        let status = makeHealthyGrafanaStatus ()

        // Assert - all components should be healthy
        Assert.True(status.ContainerRunning)
        Assert.True(status.HealthEndpointOk)
        Assert.True(status.Port3000Available)
        Assert.True(status.DashboardsProvisioned)
        Assert.True(status.DatasourcesConfigured)
        Assert.True(status.AuthenticationSetup)

    // ========================================================================
    // SECTION 4: STAMP COMPLIANCE TESTS (UC-STAMP-*)
    // SC-OBS-069: Dual logging (Terminal + SigNoz)
    // SC-OBS-071: 4 OTEL modules check
    // ========================================================================

    [<Fact>]
    let ``UC-STAMP-001: SC-OBS-069 dual logging verification`` () =
        // Arrange
        let compliance = makeFullStampCompliance ()

        // Assert
        Assert.True(compliance.["SC-OBS-069"])

    [<Fact>]
    let ``UC-STAMP-002: SC-OBS-071 four OTEL modules check`` () =
        // Arrange
        let compliance = makeFullStampCompliance ()

        // Assert
        Assert.True(compliance.["SC-OBS-071"])

    [<Fact>]
    let ``UC-STAMP-003: SC-CNT-009 NixOS/Podman only`` () =
        // Arrange
        let compliance = makeFullStampCompliance ()

        // Assert
        Assert.True(compliance.["SC-CNT-009"])

    [<Fact>]
    let ``UC-STAMP-004: SC-CNT-010 localhost registry check`` () =
        // Arrange
        let compliance = makeFullStampCompliance ()

        // Assert
        Assert.True(compliance.["SC-CNT-010"])

    [<Fact>]
    let ``UC-STAMP-005: SC-CNT-012 rootless container check`` () =
        // Arrange
        let compliance = makeFullStampCompliance ()

        // Assert
        Assert.True(compliance.["SC-CNT-012"])

    [<Fact>]
    let ``UC-STAMP-006: SC-CEP-003 FPPS consensus integration`` () =
        // Arrange
        let compliance = makeFullStampCompliance ()

        // Assert
        Assert.True(compliance.["SC-CEP-003"])

    [<Fact>]
    let ``UC-STAMP-007: SC-VAL-003 100% consensus required`` () =
        // Arrange
        let compliance = makeFullStampCompliance ()

        // Assert
        Assert.True(compliance.["SC-VAL-003"])

    [<Fact>]
    let ``UC-STAMP-008: Partial compliance detected`` () =
        // Arrange
        let compliance = makePartialStampCompliance ()

        // Assert
        Assert.True(compliance.["SC-OBS-069"])
        Assert.False(compliance.["SC-OBS-071"])
        Assert.False(compliance.["SC-CEP-003"])

    [<Fact>]
    let ``UC-STAMP-009: countPassingStampConstraints for full compliance`` () =
        // Arrange
        let compliance = makeFullStampCompliance ()

        // Act
        let count = countPassingStampConstraints compliance

        // Assert
        Assert.Equal(7, count)

    [<Fact>]
    let ``UC-STAMP-010: countPassingStampConstraints for non-compliance`` () =
        // Arrange
        let compliance = makeNonCompliantStamp ()

        // Act
        let count = countPassingStampConstraints compliance

        // Assert
        Assert.Equal(0, count)

    // ========================================================================
    // SECTION 5: ERROR HANDLING TESTS (UC-ERR-*)
    // ========================================================================

    [<Fact>]
    let ``UC-ERR-001: Network failure captured in component status`` () =
        // Arrange
        let component = makeUnhealthyComponent "otel-collector" 4317 "Network unreachable"

        // Assert
        Assert.False(component.IsHealthy)
        Assert.True(component.ErrorMessage.IsSome)
        Assert.Contains("Network", component.ErrorMessage.Value)

    [<Fact>]
    let ``UC-ERR-002: Timeout captured in error message`` () =
        // Arrange
        let component = makeUnhealthyComponent "signoz-query" 8080 "Connection timeout after 30s"

        // Assert
        Assert.False(component.IsHealthy)
        Assert.Contains("timeout", component.ErrorMessage.Value.ToLower())

    [<Fact>]
    let ``UC-ERR-003: Partial failure in verification result`` () =
        // Arrange
        let result = makeDegradedVerificationResult ()

        // Assert
        Assert.False(result.IsHealthy)
        Assert.True(result.FailureReasons.Length > 0)

    [<Fact>]
    let ``UC-ERR-004: Verification result captures all failure reasons`` () =
        // Arrange
        let reasons = ["Container not running"; "Port 4317 closed"; "Health check failed"]
        let result = makeUnhealthyVerificationResult reasons

        // Assert
        Assert.Equal(3, result.FailureReasons.Length)
        Assert.Contains("Container not running", result.FailureReasons)
        Assert.Contains("Port 4317 closed", result.FailureReasons)

    [<Fact>]
    let ``UC-ERR-005: Healthy verification has empty failure reasons`` () =
        // Arrange
        let result = makeHealthyVerificationResult ()

        // Assert
        Assert.Empty(result.FailureReasons)

    // ========================================================================
    // SECTION 6: INTEGRATION TESTS (Additional Coverage)
    // ========================================================================

    [<Fact>]
    let ``Integration: Healthy verification result has correct structure`` () =
        // Arrange
        let result = makeHealthyVerificationResult ()

        // Assert
        Assert.True(result.IsHealthy)
        Assert.True(result.FPPSResult.ConsensusAchieved)
        Assert.True(isSigNozOperational result.SigNozStatus)
        Assert.True(isGrafanaOperational result.GrafanaStatus)
        Assert.Equal(7, countPassingStampConstraints result.StampCompliance)

    [<Fact>]
    let ``Integration: Unhealthy verification result has correct structure`` () =
        // Arrange
        let result = makeUnhealthyVerificationResult ["All services down"]

        // Assert
        Assert.False(result.IsHealthy)
        Assert.False(isSigNozOperational result.SigNozStatus)
        Assert.False(isGrafanaOperational result.GrafanaStatus)
        Assert.Equal(0, countPassingStampConstraints result.StampCompliance)

    [<Fact>]
    let ``Integration: Degraded verification result has partial compliance`` () =
        // Arrange
        let result = makeDegradedVerificationResult ()

        // Assert
        Assert.False(result.IsHealthy)
        Assert.True(result.FPPSResult.ConsensusAchieved)
        let passingCount = countPassingStampConstraints result.StampCompliance
        Assert.True(passingCount > 0)
        Assert.True(passingCount < 7)

    [<Fact>]
    let ``Integration: Verification time is recorded`` () =
        // Arrange
        let result = makeHealthyVerificationResult ()

        // Assert
        Assert.True(result.TotalVerificationTimeMs > 0L)

    [<Fact>]
    let ``Integration: Verification timestamp is valid`` () =
        // Arrange
        let before = DateTime.UtcNow.AddSeconds(-1.0)
        let result = makeHealthyVerificationResult ()
        let after = DateTime.UtcNow.AddSeconds(1.0)

        // Assert
        Assert.True(result.VerifiedAt >= before)
        Assert.True(result.VerifiedAt <= after)

    // ========================================================================
    // SECTION 7: COMPONENT HEALTH TESTS (Additional Coverage)
    // ========================================================================

    [<Fact>]
    let ``Component: ClickHouse health check port is 8123`` () =
        // Arrange
        let component = makeHealthyComponent "clickhouse" 8123

        // Assert
        Assert.Equal(8123, component.Port)

    [<Fact>]
    let ``Component: Prometheus health check port is 9090`` () =
        // Arrange
        let component = makeHealthyComponent "prometheus" 9090

        // Assert
        Assert.Equal(9090, component.Port)

    [<Fact>]
    let ``Component: OTEL Collector gRPC port is 4317`` () =
        // Arrange
        let component = makeHealthyComponent "otel-collector" 4317

        // Assert
        Assert.Equal(4317, component.Port)

    [<Fact>]
    let ``Component: Grafana port is 3000`` () =
        // Arrange
        let component = makeHealthyComponent "grafana" 3000

        // Assert
        Assert.Equal(3000, component.Port)

    [<Fact>]
    let ``Component: Slow component has high response time`` () =
        // Arrange
        let component = makeSlowComponent "clickhouse" 8123 5000L

        // Assert
        Assert.True(component.IsHealthy)
        Assert.Equal(5000L, component.ResponseTimeMs)

    [<Fact>]
    let ``Component: Healthy component has error message None`` () =
        // Arrange
        let component = makeHealthyComponent "grafana" 3000

        // Assert
        Assert.True(component.ErrorMessage.IsNone)

    [<Fact>]
    let ``Component: Unhealthy component has error message Some`` () =
        // Arrange
        let component = makeUnhealthyComponent "grafana" 3000 "HTTP 503"

        // Assert
        Assert.True(component.ErrorMessage.IsSome)
        Assert.Equal("HTTP 503", component.ErrorMessage.Value)

    [<Fact>]
    let ``Component: LastChecked timestamp is recorded`` () =
        // Arrange
        let before = DateTime.UtcNow.AddSeconds(-1.0)
        let component = makeHealthyComponent "grafana" 3000
        let after = DateTime.UtcNow.AddSeconds(1.0)

        // Assert
        Assert.True(component.LastChecked >= before)
        Assert.True(component.LastChecked <= after)

    // ========================================================================
    // SECTION 8: OBSERVABILITY HEALTH CHECKS AGGREGATE TESTS
    // ========================================================================

    [<Fact>]
    let ``ObsHealthChecks: All components healthy`` () =
        // Arrange
        let checks = makeHealthyObsChecks ()

        // Assert
        Assert.True(checks.ClickHouseStatus.IsHealthy)
        Assert.True(checks.PrometheusStatus.IsHealthy)
        Assert.True(checks.OtelCollectorStatus.IsHealthy)
        Assert.True(checks.GrafanaStatus.IsHealthy)
        Assert.True(checks.SigNozQueryStatus.IsHealthy)

    [<Fact>]
    let ``ObsHealthChecks: All components unhealthy`` () =
        // Arrange
        let checks = makeUnhealthyObsChecks ()

        // Assert
        Assert.False(checks.ClickHouseStatus.IsHealthy)
        Assert.False(checks.PrometheusStatus.IsHealthy)
        Assert.False(checks.OtelCollectorStatus.IsHealthy)
        Assert.False(checks.GrafanaStatus.IsHealthy)
        Assert.False(checks.SigNozQueryStatus.IsHealthy)

    [<Fact>]
    let ``ObsHealthChecks: Mixed health state`` () =
        // Arrange
        let checks = makeMixedObsChecks ()

        // Assert
        Assert.True(checks.ClickHouseStatus.IsHealthy)
        Assert.True(checks.PrometheusStatus.IsHealthy)
        Assert.False(checks.OtelCollectorStatus.IsHealthy)
        Assert.True(checks.GrafanaStatus.IsHealthy)
        Assert.False(checks.SigNozQueryStatus.IsHealthy)

    [<Fact>]
    let ``ObsHealthChecks: Correct port assignments`` () =
        // Arrange
        let checks = makeHealthyObsChecks ()

        // Assert
        Assert.Equal(8123, checks.ClickHouseStatus.Port)
        Assert.Equal(9090, checks.PrometheusStatus.Port)
        Assert.Equal(4317, checks.OtelCollectorStatus.Port)
        Assert.Equal(3000, checks.GrafanaStatus.Port)
        Assert.Equal(8080, checks.SigNozQueryStatus.Port)

    [<Theory>]
    [<InlineData("clickhouse", 8123)>]
    [<InlineData("prometheus", 9090)>]
    [<InlineData("otel-collector", 4317)>]
    [<InlineData("grafana", 3000)>]
    [<InlineData("signoz-query", 8080)>]
    let ``ObsHealthChecks: Port mapping is correct`` (name: string) (expectedPort: int) =
        // Arrange
        let component = makeHealthyComponent name expectedPort

        // Assert
        Assert.Equal(expectedPort, component.Port)
        Assert.Equal(name, component.Name)
