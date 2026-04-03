/// CEPAF Standalone Distributed Mode Service Chain
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Full mesh cluster configuration for standalone distributed mode with:
/// - Erlang distribution enabled for Tailnet mesh
/// - Livebook remote attachment support
/// - CEPAF bridge connectivity
/// - Zenoh pub/sub mesh
/// - API access from network nodes
///
/// STAMP Compliance: SC-CLU-001 to SC-CLU-005, SC-OBS-069, SC-VAL-003
///
/// ═══════════════════════════════════════════════════════════════════════════════
module Cepaf.ServiceChains.StandaloneChain

open System
open Cepaf
open Cepaf.Modules.ServiceDAG

// ════════════════════════════════════════════════════════════════════════════
// STAMP CONSTRAINTS (SC-CLU-*)
// ════════════════════════════════════════════════════════════════════════════

/// SC-CLU-001: Distributed mode requires name-based distribution
let stampSC_CLU_001 = {
    Id = "SC-CLU-001"
    Category = "CLU"
    Description = "Distributed mode requires name-based Erlang distribution"
    Compliance = None
}

/// SC-CLU-002: EPMD must bind to 0.0.0.0 for network visibility
let stampSC_CLU_002 = {
    Id = "SC-CLU-002"
    Category = "CLU"
    Description = "EPMD must bind to 0.0.0.0:4369 for network visibility"
    Compliance = None
}

/// SC-CLU-003: Distribution port range 9100-9105
let stampSC_CLU_003 = {
    Id = "SC-CLU-003"
    Category = "CLU"
    Description = "Erlang distribution ports must be 9100-9105"
    Compliance = None
}

/// SC-CLU-004: Cookie must be synchronized across all nodes
let stampSC_CLU_004 = {
    Id = "SC-CLU-004"
    Category = "CLU"
    Description = "Erlang cookie must be synchronized across cluster"
    Compliance = None
}

/// SC-CLU-005: Tailscale DNS integration for MagicDNS
let stampSC_CLU_005 = {
    Id = "SC-CLU-005"
    Category = "CLU"
    Description = "Tailscale MagicDNS integration for cluster discovery"
    Compliance = None
}

/// All STAMP constraints for standalone mode
let stampConstraints = [
    stampSC_CLU_001
    stampSC_CLU_002
    stampSC_CLU_003
    stampSC_CLU_004
    stampSC_CLU_005
]

// ════════════════════════════════════════════════════════════════════════════
// PORT CONFIGURATION
// ════════════════════════════════════════════════════════════════════════════

/// Standalone mode port configuration
type StandalonePortConfig = {
    DbPort: int
    PhxPort: int
    PhxSslPort: int
    EpmdPort: int
    DistMinPort: int
    DistMaxPort: int
    PrometheusPort: int
    RedisPort: int
    OtlpGrpcPort: int
    OtlpHttpPort: int
    ClickHousePort: int
    GrafanaPort: int
    SigNozPort: int
}

/// Default port configuration
let defaultPortConfig : StandalonePortConfig = {
    DbPort = 5433
    PhxPort = 4000
    PhxSslPort = 4001
    EpmdPort = 4369
    DistMinPort = 9100
    DistMaxPort = 9105
    PrometheusPort = 9090
    RedisPort = 6379
    OtlpGrpcPort = 4317
    OtlpHttpPort = 4318
    ClickHousePort = 8123
    GrafanaPort = 3000
    SigNozPort = 3301
}

// ════════════════════════════════════════════════════════════════════════════
// LAYER 0: DATABASE (Foundation)
// ════════════════════════════════════════════════════════════════════════════

module Layer0 =
    /// Database container with TimescaleDB
    let dbStandalone : ContainerDef = {
        Name = "indrajaal-db-standalone"
        Image = "localhost/indrajaal-timescaledb-demo:nixos-devenv"
        DependsOn = []
        DependencyTypes = Map.empty
        Layer = Some 0
    }

    /// Database health configuration
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
        HealthCommand = "pg_isready -h 127.0.0.1 -p 5433 -U postgres"
        Timeout = TimeSpan.FromSeconds(5.0)
        Interval = TimeSpan.FromSeconds(10.0)
        Retries = 10
        StartPeriod = TimeSpan.FromSeconds(30.0)
    }

// ════════════════════════════════════════════════════════════════════════════
// LAYER 1: CACHE (Redis)
// ════════════════════════════════════════════════════════════════════════════

module Layer1 =
    /// Redis cache container
    let redisStandalone : ContainerDef = {
        Name = "indrajaal-redis-standalone"
        Image = "localhost/indrajaal-redis-demo:nixos-devenv"
        DependsOn = []
        DependencyTypes = Map.empty
        Layer = Some 1
    }

    /// Redis health configuration
    type RedisHealthConfig = {
        Port: int
        HealthCommand: string
        Timeout: TimeSpan
        Interval: TimeSpan
        Retries: int
    }

    let redisHealthConfig : RedisHealthConfig = {
        Port = 6379
        HealthCommand = "redis-cli ping"
        Timeout = TimeSpan.FromSeconds(5.0)
        Interval = TimeSpan.FromSeconds(10.0)
        Retries = 5
    }

// ════════════════════════════════════════════════════════════════════════════
// LAYER 2: OBSERVABILITY (OBS Stack)
// ════════════════════════════════════════════════════════════════════════════

module Layer2 =
    /// Observability stack with OTEL, Prometheus, Grafana, ClickHouse
    let obsStandalone : ContainerDef = {
        Name = "indrajaal-obs-standalone"
        Image = "localhost/indrajaal-obs-standalone:latest"
        DependsOn = ["indrajaal-db-standalone"]
        DependencyTypes = Map.ofList [("indrajaal-db-standalone", Optional)]
        Layer = Some 2
    }

    /// OBS health configuration
    type ObsHealthConfig = {
        GrafanaPort: int
        OtlpGrpcPort: int
        OtlpHttpPort: int
        ClickHousePort: int
        PrometheusPort: int
        HealthEndpoint: string
        Timeout: TimeSpan
        Interval: TimeSpan
        Retries: int
        StartPeriod: TimeSpan
    }

    let obsHealthConfig : ObsHealthConfig = {
        GrafanaPort = 3000
        OtlpGrpcPort = 4317
        OtlpHttpPort = 4318
        ClickHousePort = 8123
        PrometheusPort = 9090
        HealthEndpoint = "/api/health"
        Timeout = TimeSpan.FromSeconds(10.0)
        Interval = TimeSpan.FromSeconds(30.0)
        Retries = 5
        StartPeriod = TimeSpan.FromSeconds(60.0)
    }

// ════════════════════════════════════════════════════════════════════════════
// LAYER 3: APPLICATION (Phoenix + Erlang Distribution)
// ════════════════════════════════════════════════════════════════════════════

module Layer3 =
    /// Phoenix application with Erlang distribution enabled
    let appStandalone : ContainerDef = {
        Name = "indrajaal-ex-app-1"
        Image = "localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv"
        DependsOn = ["indrajaal-db-standalone"; "indrajaal-redis-standalone"]
        DependencyTypes = Map.ofList [
            ("indrajaal-db-standalone", Mandatory)
            ("indrajaal-redis-standalone", Mandatory)
        ]
        Layer = Some 3
    }

    /// App health configuration
    type AppHealthConfig = {
        PhxPort: int
        EpmdPort: int
        DistPorts: int list
        HealthEndpoint: string
        Timeout: TimeSpan
        Interval: TimeSpan
        Retries: int
        StartPeriod: TimeSpan
    }

    let appHealthConfig : AppHealthConfig = {
        PhxPort = 4000
        EpmdPort = 4369
        DistPorts = [9100; 9101; 9102; 9103; 9104; 9105]
        HealthEndpoint = "/api/v1/health"
        Timeout = TimeSpan.FromSeconds(10.0)
        Interval = TimeSpan.FromSeconds(30.0)
        Retries = 5
        StartPeriod = TimeSpan.FromSeconds(120.0)
    }

// ════════════════════════════════════════════════════════════════════════════
// SERVICE CHAIN DEFINITION
// ════════════════════════════════════════════════════════════════════════════

/// All containers for standalone distributed mode
let standaloneContainers : ContainerDef list = [
    Layer0.dbStandalone
    Layer1.redisStandalone
    Layer2.obsStandalone
    Layer3.appStandalone
]

/// Build the ServiceDAG for standalone mode
let buildStandaloneDAG () : ServiceDAG =
    buildDAG standaloneContainers

/// Get boot order based on topological sort
let getBootOrder () : Result<string list, string> =
    let dag = buildStandaloneDAG ()
    topologicalSort dag

/// Get containers grouped by layer for parallel startup
let getLayeredContainers () : ContainerDef list list =
    standaloneContainers
    |> List.groupBy (fun c -> c.Layer |> Option.defaultValue 0)
    |> List.sortBy fst
    |> List.map snd

// ════════════════════════════════════════════════════════════════════════════
// NETWORK CONFIGURATION
// SC-CONSOL-001: NetworkConfig MUST have single definition (MeshConfig.fs)
// This type renamed to MeshNetworkDef to avoid collision with MeshConfig.NetworkConfig
// ════════════════════════════════════════════════════════════════════════════

/// Network definition for standalone mesh (local to this chain)
/// For port/hostname config, use Cepaf.Config.MeshConfig.NetworkConfig
type MeshNetworkDef = {
    Name: string
    Driver: string
    Subnet: string
    Gateway: string
}

/// Default mesh network
let meshNetwork : MeshNetworkDef = {
    Name = "indrajaal-mesh"
    Driver = "bridge"
    Subnet = "172.30.0.0/24"
    Gateway = "172.30.0.1"
}

// ════════════════════════════════════════════════════════════════════════════
// ERLANG DISTRIBUTION CONFIGURATION
// ════════════════════════════════════════════════════════════════════════════

/// Erlang distribution configuration
type ErlangDistConfig = {
    NodeName: string
    Cookie: string
    EpmdPort: int
    DistPortMin: int
    DistPortMax: int
}

/// Create Erlang distribution config from environment
let createErlangConfig (ip: string) (cookie: string) : ErlangDistConfig = {
    NodeName = sprintf "indrajaal@%s" ip
    Cookie = cookie
    EpmdPort = 4369
    DistPortMin = 9100
    DistPortMax = 9105
}

/// Get ERL_AFLAGS for distribution
let getErlAflags (config: ErlangDistConfig) : string =
    sprintf "-kernel inet_dist_listen_min %d inet_dist_listen_max %d"
        config.DistPortMin config.DistPortMax

// ════════════════════════════════════════════════════════════════════════════
// VERIFICATION TASKS
// ════════════════════════════════════════════════════════════════════════════

/// Get verification protocol tasks for standalone mode
let getVerificationTasks () : ProtocolTask list =
    [
        { Id = "STANDALONE_NET_001"
          Description = "Create mesh network with subnet 172.30.0.0/24"
          EntryCriteria = "No conflicts with existing networks"
          ExitCriteria = "Network created and inspectable"
          StartState = "Absent"
          EndState = "Created"
          Status = Pending
          EstimatedDurationMs = 5000L
          ActualDurationMs = None }

        { Id = "STANDALONE_DB_001"
          Description = "Start and verify PostgreSQL/TimescaleDB"
          EntryCriteria = "Network created"
          ExitCriteria = "pg_isready returns success"
          StartState = "Created"
          EndState = "Healthy"
          Status = Pending
          EstimatedDurationMs = 30000L
          ActualDurationMs = None }

        { Id = "STANDALONE_DB_002"
          Description = "Create indrajaal_dev database if not exists"
          EntryCriteria = "PostgreSQL healthy"
          ExitCriteria = "Database exists and accessible"
          StartState = "Healthy"
          EndState = "Verified"
          Status = Pending
          EstimatedDurationMs = 10000L
          ActualDurationMs = None }

        { Id = "STANDALONE_REDIS_001"
          Description = "Start and verify Redis cache"
          EntryCriteria = "Network created"
          ExitCriteria = "redis-cli ping returns PONG"
          StartState = "Created"
          EndState = "Healthy"
          Status = Pending
          EstimatedDurationMs = 15000L
          ActualDurationMs = None }

        { Id = "STANDALONE_OBS_001"
          Description = "Start observability stack"
          EntryCriteria = "Network created"
          ExitCriteria = "Container running"
          StartState = "Absent"
          EndState = "Created"
          Status = Pending
          EstimatedDurationMs = 20000L
          ActualDurationMs = None }

        { Id = "STANDALONE_OBS_002"
          Description = "Verify OTEL Collector (gRPC 4317, HTTP 4318)"
          EntryCriteria = "OBS container running"
          ExitCriteria = "OTEL ports responding"
          StartState = "Created"
          EndState = "OTEL_Ready"
          Status = Pending
          EstimatedDurationMs = 15000L
          ActualDurationMs = None }

        { Id = "STANDALONE_EPMD_001"
          Description = "Verify EPMD running on 4369 (SC-CLU-002)"
          EntryCriteria = "Host system ready"
          ExitCriteria = "epmd -names returns success"
          StartState = "Unknown"
          EndState = "Running"
          Status = Pending
          EstimatedDurationMs = 5000L
          ActualDurationMs = None }

        { Id = "STANDALONE_FPPS_001"
          Description = "5-Point FPPS Consensus Verification"
          EntryCriteria = "All services healthy"
          ExitCriteria = "5/5 FPPS probes pass"
          StartState = "Accessible"
          EndState = "SIL-Ready"
          Status = Pending
          EstimatedDurationMs = 30000L
          ActualDurationMs = None }
    ]

// ════════════════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════════════════

/// Generate compose file path
let getComposeFilePath () : string =
    "podman-compose-standalone-distributed.yml"

/// Get container by name
let getContainer (name: string) : ContainerDef option =
    standaloneContainers |> List.tryFind (fun c -> c.Name = name)

/// Get all container names in boot order
let getContainerNames () : string list =
    match getBootOrder () with
    | Ok order -> order
    | Error _ -> standaloneContainers |> List.map (fun c -> c.Name)
