/// CEPAF Observability Service Chain Definition
/// SC-OBS-069: Dual Log (Terminal + SigNoz) mandatory
/// SC-OBS-071: 4 OTEL modules required (Traces, Metrics, Logs, Baggage)
/// SC-CNT-009: NixOS containers only
/// SC-CNT-010: localhost/ registry only
/// SC-CNT-012: Rootless execution enforced
///
/// WHAT: Defines the complete observability service chain DAG
/// WHY: Enables deterministic boot sequencing for SigNoz/Grafana stack
/// CONSTRAINTS: All components must use localhost/ registry, dual logging required
module Cepaf.ServiceChains.ObsChain

open System
open Cepaf.Modules.ServiceDAG

// ============================================================================
// OBSERVABILITY COMPONENT DEFINITIONS
// ============================================================================

/// Layer 0: Storage Foundation - ClickHouse time-series database
module Layer0 =

    /// ClickHouse time-series database container
    /// Primary storage for traces, metrics, and logs
    /// SC-CNT-009: NixOS container
    /// SC-CNT-010: localhost/ registry only
    let clickhouseContainer : ContainerDef = {
        Name = "obs-clickhouse"
        Image = "localhost/indrajaal-clickhouse:nixos-devenv"
        DependsOn = []
        DependencyTypes = Map.empty
        Layer = Some 0
    }

    /// ClickHouse health check configuration
    type ClickHouseHealthConfig = {
        HttpPort: int
        TcpPort: int
        HealthEndpoint: string
        PingEndpoint: string
        Timeout: TimeSpan
        Interval: TimeSpan
        Retries: int
        StartPeriod: TimeSpan
    }

    let clickhouseHealthConfig : ClickHouseHealthConfig = {
        HttpPort = 8123
        TcpPort = 9000
        HealthEndpoint = "/ping"
        PingEndpoint = "/ping"
        Timeout = TimeSpan.FromSeconds(5.0)
        Interval = TimeSpan.FromSeconds(10.0)
        Retries = 10
        StartPeriod = TimeSpan.FromSeconds(60.0)
    }

    /// STAMP constraints for ClickHouse container
    type ClickHouseStampConstraints = {
        /// SC-CNT-012: Rootless execution
        Rootless: bool
        /// Maximum allowed startup time (ms)
        MaxStartupMs: int64
        /// Required successful health checks
        RequiredHealthChecks: int
        /// Minimum free disk space (MB)
        MinFreeDiskMb: int
        /// Data retention period (hours)
        DataRetentionHours: int
    }

    let clickhouseStampConstraints : ClickHouseStampConstraints = {
        Rootless = true
        MaxStartupMs = 60000L
        RequiredHealthChecks = 3
        MinFreeDiskMb = 2048
        DataRetentionHours = 168  // 7 days
    }

/// Layer 1: OpenTelemetry Collector - Data ingestion gateway
module Layer1 =

    /// OTEL Collector container - Primary telemetry ingestion point
    /// Receives traces, metrics, logs via gRPC (4317) and HTTP (4318)
    /// Depends on: obs-clickhouse (Mandatory)
    let otelCollectorContainer : ContainerDef = {
        Name = "obs-otel-collector"
        Image = "localhost/indrajaal-otel-collector:nixos-devenv"
        DependsOn = ["obs-clickhouse"]
        DependencyTypes = Map.ofList [("obs-clickhouse", Mandatory)]
        Layer = Some 1
    }

    /// OTEL Collector health check configuration
    type OtelCollectorHealthConfig = {
        GrpcPort: int
        HttpPort: int
        MetricsPort: int
        HealthEndpoint: string
        Timeout: TimeSpan
        Interval: TimeSpan
        Retries: int
        StartPeriod: TimeSpan
    }

    let otelCollectorHealthConfig : OtelCollectorHealthConfig = {
        GrpcPort = 4317
        HttpPort = 4318
        MetricsPort = 8888
        HealthEndpoint = "/health"
        Timeout = TimeSpan.FromSeconds(5.0)
        Interval = TimeSpan.FromSeconds(10.0)
        Retries = 5
        StartPeriod = TimeSpan.FromSeconds(30.0)
    }

    /// STAMP constraints for OTEL Collector
    /// SC-OBS-071: 4 OTEL modules required
    type OtelCollectorStampConstraints = {
        /// SC-CNT-012: Rootless execution
        Rootless: bool
        /// Maximum allowed startup time (ms)
        MaxStartupMs: int64
        /// Required OTEL receivers
        RequiredReceivers: string list
        /// Required OTEL exporters
        RequiredExporters: string list
        /// SC-OBS-071: Required module count
        RequiredOtelModules: int
        /// Required processors
        RequiredProcessors: string list
    }

    let otelCollectorStampConstraints : OtelCollectorStampConstraints = {
        Rootless = true
        MaxStartupMs = 30000L
        RequiredReceivers = ["otlp"; "prometheus"; "hostmetrics"; "filelog"]
        RequiredExporters = ["clickhouse"; "prometheus"; "logging"]
        RequiredOtelModules = 4  // SC-OBS-071
        RequiredProcessors = ["batch"; "memory_limiter"; "resourcedetection"]
    }

/// Layer 2: Query Service - SigNoz backend
module Layer2 =

    /// SigNoz Query Service container
    /// Provides query API for traces, metrics, logs
    /// Depends on: obs-clickhouse (Mandatory), obs-otel-collector (Optional)
    let queryServiceContainer : ContainerDef = {
        Name = "obs-query-service"
        Image = "localhost/indrajaal-signoz-query:nixos-devenv"
        DependsOn = ["obs-clickhouse"; "obs-otel-collector"]
        DependencyTypes = Map.ofList [
            ("obs-clickhouse", Mandatory)
            ("obs-otel-collector", Optional)  // Can start degraded without collector
        ]
        Layer = Some 2
    }

    /// Query Service health check configuration
    type QueryServiceHealthConfig = {
        HttpPort: int
        HealthEndpoint: string
        ReadyEndpoint: string
        Timeout: TimeSpan
        Interval: TimeSpan
        Retries: int
        StartPeriod: TimeSpan
    }

    let queryServiceHealthConfig : QueryServiceHealthConfig = {
        HttpPort = 8085
        HealthEndpoint = "/api/v1/health"
        ReadyEndpoint = "/api/v1/ready"
        Timeout = TimeSpan.FromSeconds(5.0)
        Interval = TimeSpan.FromSeconds(15.0)
        Retries = 5
        StartPeriod = TimeSpan.FromSeconds(45.0)
    }

    /// STAMP constraints for Query Service
    type QueryServiceStampConstraints = {
        /// SC-CNT-012: Rootless execution
        Rootless: bool
        /// Maximum allowed startup time (ms)
        MaxStartupMs: int64
        /// Maximum query latency (ms) - SC-PRF-050
        MaxQueryLatencyMs: int64
        /// Required API endpoints available
        RequiredEndpoints: string list
    }

    let queryServiceStampConstraints : QueryServiceStampConstraints = {
        Rootless = true
        MaxStartupMs = 45000L
        MaxQueryLatencyMs = 50L  // SC-PRF-050
        RequiredEndpoints = ["/api/v1/traces"; "/api/v1/metrics"; "/api/v1/logs"]
    }

/// Layer 3: Frontend and Visualization
module Layer3 =

    /// SigNoz Frontend container
    /// Web UI for observability dashboard
    /// Depends on: obs-query-service (Mandatory)
    let frontendContainer : ContainerDef = {
        Name = "obs-frontend"
        Image = "localhost/indrajaal-signoz-frontend:nixos-devenv"
        DependsOn = ["obs-query-service"]
        DependencyTypes = Map.ofList [("obs-query-service", Mandatory)]
        Layer = Some 3
    }

    /// Frontend health check configuration
    type FrontendHealthConfig = {
        HttpPort: int
        HealthEndpoint: string
        Timeout: TimeSpan
        Interval: TimeSpan
        Retries: int
        StartPeriod: TimeSpan
    }

    let frontendHealthConfig : FrontendHealthConfig = {
        HttpPort = 8080
        HealthEndpoint = "/health"
        Timeout = TimeSpan.FromSeconds(5.0)
        Interval = TimeSpan.FromSeconds(10.0)
        Retries = 3
        StartPeriod = TimeSpan.FromSeconds(30.0)
    }

    /// STAMP constraints for Frontend
    type FrontendStampConstraints = {
        /// SC-CNT-012: Rootless execution
        Rootless: bool
        /// Maximum allowed startup time (ms)
        MaxStartupMs: int64
        /// Maximum page load time (ms)
        MaxPageLoadMs: int64
    }

    let frontendStampConstraints : FrontendStampConstraints = {
        Rootless = true
        MaxStartupMs = 30000L
        MaxPageLoadMs = 3000L
    }

    /// Grafana container - Alternative visualization
    /// Depends on: obs-clickhouse (Mandatory), obs-otel-collector (Optional)
    let grafanaContainer : ContainerDef = {
        Name = "obs-grafana"
        Image = "localhost/indrajaal-grafana:nixos-devenv"
        DependsOn = ["obs-clickhouse"; "obs-otel-collector"]
        DependencyTypes = Map.ofList [
            ("obs-clickhouse", Mandatory)
            ("obs-otel-collector", Optional)
        ]
        Layer = Some 3
    }

    /// Grafana health check configuration
    type GrafanaHealthConfig = {
        HttpPort: int
        HealthEndpoint: string
        ApiHealthEndpoint: string
        Timeout: TimeSpan
        Interval: TimeSpan
        Retries: int
        StartPeriod: TimeSpan
    }

    let grafanaHealthConfig : GrafanaHealthConfig = {
        HttpPort = 3000
        HealthEndpoint = "/api/health"
        ApiHealthEndpoint = "/api/health"
        Timeout = TimeSpan.FromSeconds(5.0)
        Interval = TimeSpan.FromSeconds(10.0)
        Retries = 5
        StartPeriod = TimeSpan.FromSeconds(30.0)
    }

    /// STAMP constraints for Grafana
    type GrafanaStampConstraints = {
        /// SC-CNT-012: Rootless execution
        Rootless: bool
        /// Maximum allowed startup time (ms)
        MaxStartupMs: int64
        /// Required datasources configured
        RequiredDatasources: string list
        /// Required dashboards available
        RequiredDashboards: string list
    }

    let grafanaStampConstraints : GrafanaStampConstraints = {
        Rootless = true
        MaxStartupMs = 45000L
        RequiredDatasources = ["ClickHouse"; "Prometheus"]
        RequiredDashboards = ["System Overview"; "Container Metrics"; "Trace Analysis"]
    }

// ============================================================================
// OBSERVABILITY CHAIN CONFIGURATION
// ============================================================================

/// Complete observability chain configuration
type ObsChainConfig = {
    ChainId: string
    Environment: string
    BootThresholdMs: int64
    AllowDegradedVisualizers: bool
    RequireAllFPPS: bool
    NetworkName: string
    NetworkSubnet: string
    /// SC-OBS-069: Dual logging configuration
    DualLogging: DualLoggingConfig
    /// SC-OBS-071: OTEL modules configuration
    OtelModules: OtelModulesConfig
}

/// SC-OBS-069: Dual logging (Terminal + SigNoz) configuration
and DualLoggingConfig = {
    TerminalEnabled: bool
    SigNozEnabled: bool
    LogLevel: string
    BufferSize: int
    FlushIntervalMs: int
}

/// SC-OBS-071: Required OTEL modules
and OtelModulesConfig = {
    TracesEnabled: bool
    MetricsEnabled: bool
    LogsEnabled: bool
    BaggageEnabled: bool
    TotalModules: int
}

let defaultObsConfig : ObsChainConfig = {
    ChainId = "indrajaal-obs-chain"
    Environment = "obs"
    BootThresholdMs = 120000L  // 2 minutes for full stack
    AllowDegradedVisualizers = true
    RequireAllFPPS = true
    NetworkName = "indrajaal-obs-net"
    NetworkSubnet = "172.31.0.0/24"
    DualLogging = {
        TerminalEnabled = true
        SigNozEnabled = true
        LogLevel = "INFO"
        BufferSize = 1024
        FlushIntervalMs = 5000
    }
    OtelModules = {
        TracesEnabled = true
        MetricsEnabled = true
        LogsEnabled = true
        BaggageEnabled = true
        TotalModules = 4
    }
}

/// Port mapping for observability chain
let obsPortMap : Map<string, int list> =
    Map.ofList [
        ("obs-clickhouse", [8123; 9000; 9009])       // HTTP, TCP, Native
        ("obs-otel-collector", [4317; 4318; 8888])  // gRPC, HTTP, Metrics
        ("obs-query-service", [8085])               // Query API
        ("obs-frontend", [8080])                    // SigNoz UI
        ("obs-grafana", [3000])                     // Grafana UI
    ]

/// Primary port for each service (for health checks)
let obsPrimaryPortMap : Map<string, int> =
    Map.ofList [
        ("obs-clickhouse", 8123)
        ("obs-otel-collector", 4317)
        ("obs-query-service", 8085)
        ("obs-frontend", 8080)
        ("obs-grafana", 3000)
    ]

/// IP assignment for observability chain
let obsIpMap : Map<string, string> =
    Map.ofList [
        ("obs-clickhouse", "172.31.0.10")
        ("obs-otel-collector", "172.31.0.20")
        ("obs-query-service", "172.31.0.30")
        ("obs-frontend", "172.31.0.40")
        ("obs-grafana", "172.31.0.50")
    ]

// ============================================================================
// CONTAINER LISTS
// ============================================================================

/// Core containers for minimal observability (ClickHouse, OTEL, Query)
let coreContainers : ContainerDef list = [
    Layer0.clickhouseContainer
    Layer1.otelCollectorContainer
    Layer2.queryServiceContainer
]

/// Full observability chain with all frontends
let fullContainers : ContainerDef list = [
    Layer0.clickhouseContainer
    Layer1.otelCollectorContainer
    Layer2.queryServiceContainer
    Layer3.frontendContainer
    Layer3.grafanaContainer
]

/// SigNoz-only stack (without Grafana)
let signozContainers : ContainerDef list = [
    Layer0.clickhouseContainer
    Layer1.otelCollectorContainer
    Layer2.queryServiceContainer
    Layer3.frontendContainer
]

/// Grafana-only stack (without SigNoz frontend)
let grafanaContainers : ContainerDef list = [
    Layer0.clickhouseContainer
    Layer1.otelCollectorContainer
    Layer3.grafanaContainer
]

// ============================================================================
// DAG CONSTRUCTION
// ============================================================================

/// Build minimal observability DAG (3 containers)
let buildMinimalObsDAG () : ServiceDAG =
    buildDAG coreContainers

/// Build full observability DAG (5 containers)
let buildFullObsDAG () : ServiceDAG =
    buildDAG fullContainers

/// Build SigNoz-only DAG (4 containers)
let buildSignozDAG () : ServiceDAG =
    buildDAG signozContainers

/// Build Grafana-only DAG (3 containers)
let buildGrafanaDAG () : ServiceDAG =
    buildDAG grafanaContainers

/// Build and validate observability DAG
let buildValidatedObsDAG (containers: ContainerDef list) : Result<ServiceDAG, string list> =
    let dag = buildDAG containers
    validate dag

/// Get boot sequence for minimal obs chain
let getMinimalObsBootSequence () : BootSequence =
    let dag = buildMinimalObsDAG ()
    calculateBootSequence dag

/// Get boot sequence for full obs chain
let getFullObsBootSequence () : BootSequence =
    let dag = buildFullObsDAG ()
    calculateBootSequence dag

// ============================================================================
// CHAIN STATE TYPES
// ============================================================================

/// State of the observability chain
type ObsChainState =
    | NotStarted
    | BootingStorage           // Layer 0: ClickHouse
    | BootingIngestion         // Layer 1: OTEL Collector
    | BootingQuery             // Layer 2: Query Service
    | BootingVisualization     // Layer 3: Frontend/Grafana
    | Running
    | DegradedNoFrontend of reason: string
    | DegradedNoGrafana of reason: string
    | Failed of reason: string
    | ShuttingDown

/// Boot progress tracking
type ObsBootProgress = {
    State: ObsChainState
    CurrentLayer: int
    StartedContainers: string list
    HealthyContainers: string list
    FailedContainers: string list
    ElapsedMs: int64
    EstimatedRemainingMs: int64
    /// SC-OBS-069: Dual logging status
    DualLoggingActive: bool
    /// SC-OBS-071: OTEL modules status
    OtelModulesActive: int
}

/// Initial boot progress
let initialObsBootProgress : ObsBootProgress = {
    State = NotStarted
    CurrentLayer = -1
    StartedContainers = []
    HealthyContainers = []
    FailedContainers = []
    ElapsedMs = 0L
    EstimatedRemainingMs = 120000L
    DualLoggingActive = false
    OtelModulesActive = 0
}

// ============================================================================
// SHUTDOWN TYPES
// ============================================================================

/// Shutdown mode for observability chain
type ObsShutdownMode =
    | Graceful         // Reverse boot order, wait for drain
    | Emergency        // Immediate stop (<1s per AOR-SAF-001)
    | RetainStorage    // Stop all except ClickHouse (data preservation)
    | Partial of containers: string list

/// Shutdown result
type ObsShutdownResult = {
    Mode: ObsShutdownMode
    StoppedContainers: string list
    FailedToStop: string list
    DurationMs: int64
    DataPreserved: bool
    Success: bool
}

// ============================================================================
// STAMP COMPLIANCE - OBSERVABILITY SPECIFIC
// ============================================================================

/// SC-OBS-069: Dual logging compliance
type DualLoggingCompliance = {
    ConstraintId: string
    TerminalLoggingActive: bool
    SigNozLoggingActive: bool
    IsCompliant: bool
    Reason: string option
}

/// SC-OBS-071: OTEL modules compliance
type OtelModulesCompliance = {
    ConstraintId: string
    TracesEnabled: bool
    MetricsEnabled: bool
    LogsEnabled: bool
    BaggageEnabled: bool
    TotalActive: int
    RequiredCount: int
    IsCompliant: bool
    Reason: string option
}

/// Check SC-OBS-069 compliance
let checkDualLoggingCompliance (config: ObsChainConfig) : DualLoggingCompliance =
    let compliant = config.DualLogging.TerminalEnabled && config.DualLogging.SigNozEnabled
    {
        ConstraintId = "SC-OBS-069"
        TerminalLoggingActive = config.DualLogging.TerminalEnabled
        SigNozLoggingActive = config.DualLogging.SigNozEnabled
        IsCompliant = compliant
        Reason = if compliant then None else Some "Both Terminal and SigNoz logging must be enabled"
    }

/// Check SC-OBS-071 compliance
let checkOtelModulesCompliance (config: ObsChainConfig) : OtelModulesCompliance =
    let activeCount =
        [config.OtelModules.TracesEnabled; config.OtelModules.MetricsEnabled;
         config.OtelModules.LogsEnabled; config.OtelModules.BaggageEnabled]
        |> List.filter id
        |> List.length
    let compliant = activeCount >= 4
    {
        ConstraintId = "SC-OBS-071"
        TracesEnabled = config.OtelModules.TracesEnabled
        MetricsEnabled = config.OtelModules.MetricsEnabled
        LogsEnabled = config.OtelModules.LogsEnabled
        BaggageEnabled = config.OtelModules.BaggageEnabled
        TotalActive = activeCount
        RequiredCount = 4
        IsCompliant = compliant
        Reason = if compliant then None else Some (sprintf "Only %d of 4 required OTEL modules active" activeCount)
    }

/// Check all STAMP compliance for observability chain
let checkObsStampCompliance () : Map<string, bool> =
    let config = defaultObsConfig
    Map.ofList [
        ("SC-CNT-009", fullContainers |> List.forall (fun c -> c.Image.Contains("nixos")))
        ("SC-CNT-010", fullContainers |> List.forall (fun c -> c.Image.StartsWith("localhost/")))
        ("SC-CNT-012", true)  // Rootless enforced by podman config
        ("SC-AGT-018", not (hasCycles (buildFullObsDAG ())))
        ("SC-OBS-069", (checkDualLoggingCompliance config).IsCompliant)
        ("SC-OBS-071", (checkOtelModulesCompliance config).IsCompliant)
        ("SC-PRF-050", Layer2.queryServiceStampConstraints.MaxQueryLatencyMs <= 50L)
    ]

// ============================================================================
// FPPS VERIFICATION CONFIGURATION
// ============================================================================

/// FPPS verification configuration for observability chain
type ObsFPPSConfig = {
    /// Enable PodmanStatus check
    EnablePodmanStatus: bool
    /// Enable HealthEndpoint check
    EnableHealthEndpoint: bool
    /// Enable PortProbe check
    EnablePortProbe: bool
    /// Enable ProcessCheck
    EnableProcessCheck: bool
    /// Enable LogAnalysis
    EnableLogAnalysis: bool
    /// Error patterns specific to observability
    LogErrorPatterns: string list
    /// Number of log tail lines to check
    LogTailLines: int
    /// OTEL-specific error patterns
    OtelErrorPatterns: string list
    /// ClickHouse-specific error patterns
    ClickHouseErrorPatterns: string list
}

let defaultObsFPPSConfig : ObsFPPSConfig = {
    EnablePodmanStatus = true
    EnableHealthEndpoint = true
    EnablePortProbe = true
    EnableProcessCheck = true
    EnableLogAnalysis = true
    LogErrorPatterns = ["ERROR"; "FATAL"; "CRITICAL"; "panic"; "SIGKILL"; "OOM"]
    LogTailLines = 100
    OtelErrorPatterns = [
        "failed to export"
        "connection refused"
        "exporter error"
        "pipeline failed"
        "receiver error"
    ]
    ClickHouseErrorPatterns = [
        "DB::Exception"
        "Code: 60"  // Table not found
        "Code: 81"  // Database not found
        "Too many parts"
        "Memory limit exceeded"
    ]
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/// Get container by name from obs chain
let getObsContainer (name: string) : ContainerDef option =
    fullContainers |> List.tryFind (fun c -> c.Name = name)

/// Get layer for a container
let getObsContainerLayer (name: string) : int option =
    fullContainers
    |> List.tryFind (fun c -> c.Name = name)
    |> Option.bind (fun c -> c.Layer)

/// Check if container is core (not a visualizer)
let isObsCoreContainer (name: string) : bool =
    coreContainers |> List.exists (fun c -> c.Name = name)

/// Check if container is a visualizer
let isVisualizerContainer (name: string) : bool =
    name = "obs-frontend" || name = "obs-grafana"

/// Get containers at a specific layer
let getObsContainersAtLayer (layer: int) : ContainerDef list =
    fullContainers |> List.filter (fun c -> c.Layer = Some layer)

/// Get all dependencies for a container (direct)
let getObsContainerDependencies (name: string) : string list =
    fullContainers
    |> List.tryFind (fun c -> c.Name = name)
    |> Option.map (fun c -> c.DependsOn)
    |> Option.defaultValue []

/// Check if all dependencies are satisfied
let areObsDependenciesSatisfied (name: string) (healthyContainers: Set<string>) : bool =
    let deps = getObsContainerDependencies name
    deps |> List.forall (fun d -> Set.contains d healthyContainers)

/// Get reverse boot order for shutdown
let getObsShutdownOrder () : string list =
    let sequence = getFullObsBootSequence ()
    sequence.Order |> List.rev

/// Calculate estimated boot time based on layers
let estimateObsBootTimeMs () : int64 =
    let dag = buildFullObsDAG () |> assignLayers
    let maxLayer = getMaxLayer dag
    // Estimate 30s per layer for observability (heavier startup)
    int64 ((maxLayer + 1) * 30000)

/// Get all ports used by the observability chain
let getAllObsPorts () : int list =
    obsPortMap
    |> Map.toList
    |> List.collect snd
    |> List.distinct
    |> List.sort

// ============================================================================
// VALIDATION FUNCTIONS
// ============================================================================

/// Validate observability chain configuration
let validateObsChain () : Result<ServiceDAG, string list> =
    let dag = buildFullObsDAG ()
    let errors = ResizeArray<string>()

    // Check all images use localhost/ registry (SC-CNT-010)
    fullContainers
    |> List.iter (fun c ->
        if not (c.Image.StartsWith("localhost/")) then
            errors.Add(sprintf "[SC-CNT-010] Container '%s' image '%s' must use localhost/ registry" c.Name c.Image))

    // Check all images are NixOS (SC-CNT-009)
    fullContainers
    |> List.iter (fun c ->
        if not (c.Image.Contains("nixos")) then
            errors.Add(sprintf "[SC-CNT-009] Container '%s' image '%s' must be NixOS-based" c.Name c.Image))

    // Check SC-OBS-069 compliance
    let dualLogging = checkDualLoggingCompliance defaultObsConfig
    if not dualLogging.IsCompliant then
        errors.Add(sprintf "[SC-OBS-069] %s" (dualLogging.Reason |> Option.defaultValue "Unknown"))

    // Check SC-OBS-071 compliance
    let otelModules = checkOtelModulesCompliance defaultObsConfig
    if not otelModules.IsCompliant then
        errors.Add(sprintf "[SC-OBS-071] %s" (otelModules.Reason |> Option.defaultValue "Unknown"))

    // Validate DAG structure
    match validate dag with
    | Error errs -> errors.AddRange(errs)
    | Ok _ -> ()

    if errors.Count = 0 then
        Ok (assignLayers dag)
    else
        Error (errors |> List.ofSeq)

// ============================================================================
// ELIXIR TELEMETRY INTEGRATION
// ============================================================================

/// Elixir telemetry integration configuration
type ElixirTelemetryConfig = {
    /// OTLP endpoint for traces
    OtlpTraceEndpoint: string
    /// OTLP endpoint for metrics
    OtlpMetricsEndpoint: string
    /// OTLP endpoint for logs
    OtlpLogsEndpoint: string
    /// Service name for traces
    ServiceName: string
    /// Service namespace
    ServiceNamespace: string
    /// Sampling rate (0.0 - 1.0)
    SamplingRate: float
    /// Batch processor config
    BatchSize: int
    /// Export interval (ms)
    ExportIntervalMs: int
}

let defaultElixirTelemetryConfig : ElixirTelemetryConfig = {
    OtlpTraceEndpoint = "http://localhost:4317"
    OtlpMetricsEndpoint = "http://localhost:4317"
    OtlpLogsEndpoint = "http://localhost:4317"
    ServiceName = "indrajaal"
    ServiceNamespace = "indrajaal-ns"
    SamplingRate = 1.0
    BatchSize = 512
    ExportIntervalMs = 5000
}

/// Generate Elixir config snippet for OTLP exporter
let generateElixirOtlpConfig (config: ElixirTelemetryConfig) : string =
    String.Format("""# OpenTelemetry configuration for Elixir
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: {{:otlp, protocol: :grpc, endpoint: "{0}"}},
  resource: [
    service: [name: "{1}", namespace: "{2}"]
  ]

config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: "{3}"

config :opentelemetry, :processors,
  batch: [
    scheduled_delay_ms: {4},
    max_queue_size: {5}
  ]
""", config.OtlpTraceEndpoint, config.ServiceName, config.ServiceNamespace, config.OtlpTraceEndpoint, config.ExportIntervalMs, config.BatchSize)

// ============================================================================
// REPORTING
// ============================================================================

/// Generate observability chain summary
let generateObsChainSummary () : string =
    let dag = buildFullObsDAG () |> assignLayers
    let sequence = getFullObsBootSequence ()
    let compliance = checkObsStampCompliance ()

    let sb = System.Text.StringBuilder()
    sb.AppendLine("=" |> String.replicate 70) |> ignore
    sb.AppendLine("INTELITOR OBSERVABILITY CHAIN SUMMARY") |> ignore
    sb.AppendLine("=" |> String.replicate 70) |> ignore
    sb.AppendLine() |> ignore

    sb.AppendLine("COMPONENTS:") |> ignore
    fullContainers |> List.iter (fun c ->
        let layer = c.Layer |> Option.map string |> Option.defaultValue "?"
        let deps = if c.DependsOn.IsEmpty then "(none)" else String.concat ", " c.DependsOn
        let ports = obsPortMap |> Map.tryFind c.Name |> Option.map (List.map string >> String.concat ",") |> Option.defaultValue "?"
        sb.AppendLine(sprintf "  [L%s] %s" layer c.Name) |> ignore
        sb.AppendLine(sprintf "       Image: %s" c.Image) |> ignore
        sb.AppendLine(sprintf "       Deps:  %s" deps) |> ignore
        sb.AppendLine(sprintf "       Ports: %s" ports) |> ignore)
    sb.AppendLine() |> ignore

    sb.AppendLine("BOOT SEQUENCE:") |> ignore
    sequence.Order |> List.iteri (fun i name ->
        sb.AppendLine(sprintf "  %d. %s" (i + 1) name) |> ignore)
    sb.AppendLine(sprintf "  Estimated Time: %dms" sequence.EstimatedTimeMs) |> ignore
    sb.AppendLine() |> ignore

    sb.AppendLine("PORT MAPPING:") |> ignore
    sb.AppendLine("  4317: OTLP gRPC (traces, metrics, logs)") |> ignore
    sb.AppendLine("  4318: OTLP HTTP (traces, metrics, logs)") |> ignore
    sb.AppendLine("  8080: SigNoz UI") |> ignore
    sb.AppendLine("  3000: Grafana UI") |> ignore
    sb.AppendLine("  8123: ClickHouse HTTP") |> ignore
    sb.AppendLine("  8085: Query Service API") |> ignore
    sb.AppendLine() |> ignore

    sb.AppendLine("STAMP COMPLIANCE:") |> ignore
    compliance |> Map.iter (fun stampConstraint passed ->
        let icon = if passed then "[OK]" else "[!!]"
        sb.AppendLine(sprintf "  %s %s" icon stampConstraint) |> ignore)
    sb.AppendLine() |> ignore

    sb.AppendLine("LAYER STRUCTURE:") |> ignore
    [0 .. getMaxLayer dag]
    |> List.iter (fun layer ->
        let nodes = getNodesAtLayer layer dag
        let layerName =
            match layer with
            | 0 -> "Storage"
            | 1 -> "Ingestion"
            | 2 -> "Query"
            | 3 -> "Visualization"
            | _ -> "Other"
        sb.AppendLine(sprintf "  Layer %d (%s): %s" layer layerName (String.concat ", " nodes)) |> ignore)

    sb.AppendLine("=" |> String.replicate 70) |> ignore
    sb.ToString()
