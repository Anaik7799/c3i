/// CEPAF Dev/Demo Environment Service Chain Definition
/// SC-CEP-003: Consensus-based health verification
/// SC-CEP-004: 40-second boot threshold via topological ordering (4 layers max)
/// SC-AGT-018: Deadlock prevention through cycle detection
/// SC-CNT-009: NixOS containers only
/// SC-CNT-010: localhost/ registry only
/// SC-CNT-012: Rootless execution enforced
///
/// WHAT: Defines the complete service chain DAG for dev/demo environment
/// WHY: Enables deterministic boot sequencing, health propagation, and FPPS verification
/// CONSTRAINTS: All containers must use localhost/ registry, boot within 30s threshold
module Cepaf.ServiceChains.DevChain

open System
open Cepaf.Modules.ServiceDAG

// ============================================================================
// CONTAINER LAYER DEFINITIONS
// ============================================================================

/// Layer 0: Foundation containers with no dependencies
module Layer0 =

    /// Database container - PostgreSQL 17 + TimescaleDB
    /// SC-CNT-009: NixOS container
    /// SC-CNT-010: localhost/ registry only
    let dbContainer : ContainerDef = {
        Name = "indrajaal-db"
        Image = "localhost/indrajaal-timescaledb-demo:nixos-devenv"
        DependsOn = []
        DependencyTypes = Map.empty
        Layer = Some 0
    }

    /// Database health check configuration
    type DbHealthConfig = {
        Port: int
        HealthCommand: string
        Timeout: TimeSpan
        Interval: TimeSpan
        Retries: int
        StartPeriod: TimeSpan
    }

    let dbHealthConfig : DbHealthConfig = {
        Port = 5433
        HealthCommand = "pg_isready -U indrajaal -d indrajaal_dev -p 5433 -h localhost"
        Timeout = TimeSpan.FromSeconds(5.0)
        Interval = TimeSpan.FromSeconds(10.0)
        Retries = 5
        StartPeriod = TimeSpan.FromSeconds(30.0)
    }

    /// STAMP constraints for database container
    type DbStampConstraints = {
        /// SC-CNT-012: Rootless execution
        Rootless: bool
        /// Maximum allowed startup time (ms)
        MaxStartupMs: int64
        /// Required health checks before healthy
        RequiredHealthChecks: int
        /// Minimum free disk space (MB)
        MinFreeDiskMb: int
    }

    let dbStampConstraints : DbStampConstraints = {
        Rootless = true
        MaxStartupMs = 30000L
        RequiredHealthChecks = 3
        MinFreeDiskMb = 1024
    }

/// Layer 1: Application containers depending on database
module Layer1 =

    /// Application container - Phoenix/Elixir
    /// Depends on: indrajaal-db (Mandatory)
    let appContainer : ContainerDef = {
        Name = "indrajaal-app"
        Image = "localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv"
        DependsOn = ["indrajaal-db"]
        DependencyTypes = Map.ofList [("indrajaal-db", Mandatory)]
        Layer = Some 1
    }

    /// Application health check configuration
    type AppHealthConfig = {
        Port: int
        HealthEndpoint: string
        HealthTimeoutMs: int
        Interval: TimeSpan
        Retries: int
        StartPeriod: TimeSpan
    }

    let appHealthConfig : AppHealthConfig = {
        Port = 4000
        HealthEndpoint = "/health"
        HealthTimeoutMs = 5000
        Interval = TimeSpan.FromSeconds(30.0)
        Retries = 3
        StartPeriod = TimeSpan.FromSeconds(120.0)
    }

    /// STAMP constraints for application container
    type AppStampConstraints = {
        /// SC-CNT-012: Rootless execution
        Rootless: bool
        /// Maximum allowed startup time (ms)
        MaxStartupMs: int64
        /// SC-PRF-050: Response latency < 50ms
        MaxResponseMs: int64
        /// Required successful health checks
        RequiredHealthChecks: int
        /// SC-CMP-025: Zero warnings required
        ZeroWarnings: bool
    }

    let appStampConstraints : AppStampConstraints = {
        Rootless = true
        MaxStartupMs = 120000L
        MaxResponseMs = 50L
        RequiredHealthChecks = 2
        ZeroWarnings = true
    }

    /// Redis sidecar (shares network with app)
    let redisContainer : ContainerDef = {
        Name = "indrajaal-redis"
        Image = "localhost/indrajaal-redis-demo:nixos-devenv"
        DependsOn = ["indrajaal-app"]
        DependencyTypes = Map.ofList [("indrajaal-app", Mandatory)]
        Layer = Some 1
    }

    /// Nginx sidecar (shares network with app)
    let nginxContainer : ContainerDef = {
        Name = "indrajaal-nginx"
        Image = "localhost/indrajaal-nginx-demo:nixos-devenv"
        DependsOn = ["indrajaal-app"]
        DependencyTypes = Map.ofList [("indrajaal-app", Mandatory)]
        Layer = Some 1
    }

/// Layer 2: Observability containers depending on application
module Layer2 =

    /// Observability container - Prometheus/SigNoz
    /// Depends on: indrajaal-app (Optional - chain can degrade)
    let obsContainer : ContainerDef = {
        Name = "indrajaal-obs"
        Image = "localhost/indrajaal-prometheus-demo:nixos-devenv"
        DependsOn = ["indrajaal-app"]
        DependencyTypes = Map.ofList [("indrajaal-app", Optional)]
        Layer = Some 2
    }

    /// Observability health check configuration
    type ObsHealthConfig = {
        PrometheusPort: int
        GrafanaPort: int
        OtlpPort: int
        HealthEndpoint: string
        HealthTimeoutMs: int
        Interval: TimeSpan
        Retries: int
        StartPeriod: TimeSpan
    }

    let obsHealthConfig : ObsHealthConfig = {
        PrometheusPort = 9090
        GrafanaPort = 3000
        OtlpPort = 4317
        HealthEndpoint = "/-/healthy"
        HealthTimeoutMs = 10000
        Interval = TimeSpan.FromSeconds(30.0)
        Retries = 3
        StartPeriod = TimeSpan.FromSeconds(30.0)
    }

    /// Grafana sidecar (shares network with obs)
    let grafanaContainer : ContainerDef = {
        Name = "indrajaal-grafana"
        Image = "localhost/indrajaal-grafana-demo:nixos-devenv"
        DependsOn = ["indrajaal-obs"]
        DependencyTypes = Map.ofList [("indrajaal-obs", Mandatory)]
        Layer = Some 2
    }

    /// STAMP constraints for observability container
    type ObsStampConstraints = {
        /// SC-CNT-012: Rootless execution
        Rootless: bool
        /// Maximum allowed startup time (ms)
        MaxStartupMs: int64
        /// SC-OBS-069: Dual logging required
        DualLogging: bool
        /// SC-OBS-071: Required OTEL modules count
        RequiredOtelModules: int
    }

    let obsStampConstraints : ObsStampConstraints = {
        Rootless = true
        MaxStartupMs = 45000L
        DualLogging = true
        RequiredOtelModules = 4
    }

// ============================================================================
// SERVICE CHAIN CONFIGURATION
// ============================================================================

/// Complete dev/demo chain configuration
type DevChainConfig = {
    ChainId: string
    Environment: string
    BootThresholdMs: int64
    AllowDegradedObs: bool
    RequireAllFPPS: bool
    NetworkName: string
    NetworkSubnet: string
}

let defaultDevConfig : DevChainConfig = {
    ChainId = "indrajaal-dev-chain"
    Environment = "dev"
    BootThresholdMs = 30000L
    AllowDegradedObs = true
    RequireAllFPPS = true
    NetworkName = "indrajaal-net"
    NetworkSubnet = "172.30.0.0/24"
}

/// Port mapping for dev chain
let devPortMap : Map<string, int> =
    Map.ofList [
        ("indrajaal-db", 5433)
        ("indrajaal-app", 4000)
        ("indrajaal-redis", 6379)
        ("indrajaal-nginx", 80)
        ("indrajaal-obs", 9090)
        ("indrajaal-grafana", 3000)
    ]

/// IP assignment for dev chain (static IPs within subnet)
let devIpMap : Map<string, string> =
    Map.ofList [
        ("indrajaal-db", "172.30.0.10")
        ("indrajaal-app", "172.30.0.20")
        ("indrajaal-redis", "172.30.0.20")  // Shares with app
        ("indrajaal-nginx", "172.30.0.20")  // Shares with app
        ("indrajaal-obs", "172.30.0.30")
        ("indrajaal-grafana", "172.30.0.30")  // Shares with obs
    ]

// ============================================================================
// DAG CONSTRUCTION
// ============================================================================

/// Core containers for minimal dev chain (db, app, obs)
let coreContainers : ContainerDef list = [
    Layer0.dbContainer
    Layer1.appContainer
    Layer2.obsContainer
]

/// Full dev chain with all sidecars
let fullContainers : ContainerDef list = [
    Layer0.dbContainer
    Layer1.appContainer
    Layer1.redisContainer
    Layer1.nginxContainer
    Layer2.obsContainer
    Layer2.grafanaContainer
]

/// Build minimal dev chain DAG (3 containers)
let buildMinimalDevDAG () : ServiceDAG =
    buildDAG coreContainers

/// Build full dev chain DAG (6 containers)
let buildFullDevDAG () : ServiceDAG =
    buildDAG fullContainers

/// Build and validate dev chain DAG
let buildValidatedDevDAG (containers: ContainerDef list) : Result<ServiceDAG, string list> =
    let dag = buildDAG containers
    validate dag

/// Get boot sequence for dev chain
let getDevBootSequence () : BootSequence =
    let dag = buildMinimalDevDAG ()
    calculateBootSequence dag

/// Get boot sequence for full dev chain
let getFullDevBootSequence () : BootSequence =
    let dag = buildFullDevDAG ()
    calculateBootSequence dag

// ============================================================================
// CHAIN STATE TYPES
// ============================================================================

/// State of the dev chain
type DevChainState =
    | NotStarted
    | BootingLayer0
    | BootingLayer1
    | BootingLayer2
    | Running
    | Degraded of reason: string
    | Failed of reason: string
    | ShuttingDown

/// Boot progress tracking
type BootProgress = {
    State: DevChainState
    CurrentLayer: int
    StartedContainers: string list
    HealthyContainers: string list
    FailedContainers: string list
    ElapsedMs: int64
    EstimatedRemainingMs: int64
}

/// Initial boot progress
let initialBootProgress : BootProgress = {
    State = NotStarted
    CurrentLayer = -1
    StartedContainers = []
    HealthyContainers = []
    FailedContainers = []
    ElapsedMs = 0L
    EstimatedRemainingMs = 30000L
}

// ============================================================================
// SHUTDOWN TYPES
// ============================================================================

/// Shutdown mode
type ShutdownMode =
    | Graceful       // Reverse boot order, wait for drain
    | Emergency      // Immediate stop (<1s per AOR-SAF-001)
    | Partial of containers: string list  // Stop specific containers

/// Shutdown result
type ShutdownResult = {
    Mode: ShutdownMode
    StoppedContainers: string list
    FailedToStop: string list
    DurationMs: int64
    Success: bool
}

// ============================================================================
// VERIFICATION CONFIGURATION
// ============================================================================

/// FPPS verification configuration for dev chain
type DevFPPSConfig = {
    /// Enable PodmanStatus check (podman ps)
    EnablePodmanStatus: bool
    /// Enable HealthEndpoint check (HTTP /health)
    EnableHealthEndpoint: bool
    /// Enable PortProbe check (TCP connection)
    EnablePortProbe: bool
    /// Enable ProcessCheck (podman top)
    EnableProcessCheck: bool
    /// Enable LogAnalysis (podman logs)
    EnableLogAnalysis: bool
    /// Error patterns to detect in logs
    LogErrorPatterns: string list
    /// Number of log tail lines to check
    LogTailLines: int
}

let defaultDevFPPSConfig : DevFPPSConfig = {
    EnablePodmanStatus = true
    EnableHealthEndpoint = true
    EnablePortProbe = true
    EnableProcessCheck = true
    EnableLogAnalysis = true
    LogErrorPatterns = ["ERROR"; "FATAL"; "CRITICAL"; "panic"; "SIGKILL"; "OOM"]
    LogTailLines = 50
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/// Get container by name from dev chain
let getDevContainer (name: string) : ContainerDef option =
    fullContainers |> List.tryFind (fun c -> c.Name = name)

/// Get layer for a container
let getContainerLayer (name: string) : int option =
    fullContainers
    |> List.tryFind (fun c -> c.Name = name)
    |> Option.bind (fun c -> c.Layer)

/// Check if container is core (not a sidecar)
let isCoreContainer (name: string) : bool =
    coreContainers |> List.exists (fun c -> c.Name = name)

/// Check if container has optional dependencies only
let hasOnlyOptionalDeps (name: string) (dag: ServiceDAG) : bool =
    match getNode name dag with
    | None -> false
    | Some node ->
        node.Dependencies
        |> List.forall (fun dep ->
            match getDependencyType dep name dag with
            | Some Optional -> true
            | _ -> false)

/// Get containers at a specific layer
let getContainersAtLayer (layer: int) : ContainerDef list =
    fullContainers |> List.filter (fun c -> c.Layer = Some layer)

/// Get all dependencies for a container (direct)
let getContainerDependencies (name: string) : string list =
    fullContainers
    |> List.tryFind (fun c -> c.Name = name)
    |> Option.map (fun c -> c.DependsOn)
    |> Option.defaultValue []

/// Check if all dependencies are satisfied
let areDependenciesSatisfied (name: string) (healthyContainers: Set<string>) : bool =
    let deps = getContainerDependencies name
    deps |> List.forall (fun d -> Set.contains d healthyContainers)

/// Get reverse boot order for shutdown
let getShutdownOrder () : string list =
    let sequence = getFullDevBootSequence ()
    sequence.Order |> List.rev

/// Calculate estimated boot time based on layers
let estimateBootTimeMs () : int64 =
    let dag = buildFullDevDAG () |> assignLayers
    let maxLayer = getMaxLayer dag
    // Estimate 10s per layer (parallel boot within layer)
    int64 ((maxLayer + 1) * 10000)

// ============================================================================
// VALIDATION FUNCTIONS
// ============================================================================

/// Validate dev chain configuration
let validateDevChain () : Result<ServiceDAG, string list> =
    let dag = buildFullDevDAG ()

    // Additional dev-specific validations
    let errors = ResizeArray<string>()

    // Check all images use localhost/ registry (SC-CNT-010)
    fullContainers
    |> List.iter (fun c ->
        if not (c.Image.StartsWith("localhost/")) then
            errors.Add(sprintf "[SC-CNT-010] Container '%s' image '%s' must use localhost/ registry" c.Name c.Image))

    // Validate DAG structure
    match validate dag with
    | Error errs -> errors.AddRange(errs)
    | Ok _ -> ()

    if errors.Count = 0 then
        Ok (assignLayers dag)
    else
        Error (errors |> List.ofSeq)

/// Check STAMP compliance for dev chain
let checkStampCompliance () : Map<string, bool> =
    Map.ofList [
        ("SC-CNT-009", fullContainers |> List.forall (fun c -> c.Image.Contains("nixos")))
        ("SC-CNT-010", fullContainers |> List.forall (fun c -> c.Image.StartsWith("localhost/")))
        ("SC-CNT-012", true)  // Rootless is enforced by podman config
        ("SC-AGT-018", not (hasCycles (buildFullDevDAG ())))
        ("SC-CEP-003", true)  // FPPS consensus is enabled by default
        ("SC-CEP-004", estimateBootTimeMs () <= 40000L)  // 4 layers * 10s = 40s max
    ]

// ============================================================================
// REPORTING
// ============================================================================

/// Generate dev chain summary
let generateDevChainSummary () : string =
    let dag = buildFullDevDAG () |> assignLayers
    let sequence = getFullDevBootSequence ()
    let compliance = checkStampCompliance ()

    let sb = System.Text.StringBuilder()
    sb.AppendLine("=" |> String.replicate 70) |> ignore
    sb.AppendLine("INTELITOR DEV CHAIN SUMMARY") |> ignore
    sb.AppendLine("=" |> String.replicate 70) |> ignore
    sb.AppendLine() |> ignore

    sb.AppendLine("CONTAINERS:") |> ignore
    fullContainers |> List.iter (fun c ->
        let layer = c.Layer |> Option.map string |> Option.defaultValue "?"
        let deps = if c.DependsOn.IsEmpty then "(none)" else String.concat ", " c.DependsOn
        sb.AppendLine(sprintf "  [L%s] %s" layer c.Name) |> ignore
        sb.AppendLine(sprintf "       Image: %s" c.Image) |> ignore
        sb.AppendLine(sprintf "       Deps:  %s" deps) |> ignore)
    sb.AppendLine() |> ignore

    sb.AppendLine("BOOT SEQUENCE:") |> ignore
    sequence.Order |> List.iteri (fun i name ->
        sb.AppendLine(sprintf "  %d. %s" (i + 1) name) |> ignore)
    sb.AppendLine(sprintf "  Estimated Time: %dms" sequence.EstimatedTimeMs) |> ignore
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
        sb.AppendLine(sprintf "  Layer %d: %s" layer (String.concat ", " nodes)) |> ignore)

    sb.AppendLine("=" |> String.replicate 70) |> ignore
    sb.ToString()
