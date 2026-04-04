/// =============================================================================
/// CEPAF MESH CONFIGURATION - CENTRALIZED SINGLE SOURCE OF TRUTH
/// =============================================================================
///
/// Version: 21.2.1-SIL6
/// Date: 2026-01-17
///
/// STAMP Compliance:
/// - SC-BOOT-001: State vector MUST be verified before each stage
/// - SC-BOOT-008: DAG MUST be acyclic (verified by Kahn)
/// - SC-CONFIG-001: All configuration MUST be in single location
/// - SC-CONFIG-002: NO magic values in boot/runtime code
/// - SC-CONFIG-003: Change ONE location for system-wide updates
///
/// This module is the AUTHORITATIVE source for all mesh configuration.
/// All other modules MUST reference this config - NO hardcoded values allowed.
/// =============================================================================

namespace Cepaf.Config

open System

/// Mathematical Foundation: State Vector Definition
/// $\vec{S}(t) = (s_{compile}, s_{migrations}, s_{containers}, s_{zenoh}, s_{health}, s_{quorum})$
module StateVector =
    /// State vector component (0 = invalid, 1 = valid)
    type StateComponent = Invalid | Valid

    /// Full state vector per startup specification
    type StateVector = {
        Compile: StateComponent       // s_compile: Elixir compiled
        Migrations: StateComponent    // s_migrations: DB migrations applied
        Containers: StateComponent    // s_containers: Infrastructure up
        Zenoh: StateComponent         // s_zenoh: Mesh formed
        Health: StateComponent        // s_health: App healthy
        Quorum: StateComponent        // s_quorum: Cluster consensus
    }

    let empty = {
        Compile = Invalid
        Migrations = Invalid
        Containers = Invalid
        Zenoh = Invalid
        Health = Invalid
        Quorum = Invalid
    }

    /// Valid startup predicate: $\text{ValidStartup}(t) \iff \prod_{i=1}^{6} s_i(t) = 1$
    let isValidStartup (state: StateVector) : bool =
        state.Compile = Valid &&
        state.Migrations = Valid &&
        state.Containers = Valid &&
        state.Zenoh = Valid &&
        state.Health = Valid &&
        state.Quorum = Valid

    /// Verify state for specific stage
    let verifyForStage (stage: int) (state: StateVector) : Result<unit, string> =
        match stage with
        | 0 -> Ok () // S0_PREFLIGHT has no pre-conditions
        | 1 when state.Compile = Valid -> Ok ()
        | 2 when state.Compile = Valid && state.Migrations = Valid && state.Containers = Valid -> Ok ()
        | 3 when state.Compile = Valid && state.Migrations = Valid && state.Containers = Valid && state.Zenoh = Valid -> Ok ()
        | 4 when state.Compile = Valid && state.Migrations = Valid && state.Containers = Valid && state.Zenoh = Valid && state.Health = Valid -> Ok ()
        | n -> Error $"State vector invalid for stage S{n}: {state}"

    /// Print state vector as [c,m,co,z,h,q]
    let print (state: StateVector) : string =
        let b v = if v = Valid then "1" else "0"
        $"[{b state.Compile},{b state.Migrations},{b state.Containers},{b state.Zenoh},{b state.Health},{b state.Quorum}]"


/// =============================================================================
/// NETWORK CONFIGURATION - ALL PORTS, IPS, HOSTNAMES
/// =============================================================================
module NetworkConfig =

    /// Port definitions - SINGLE SOURCE OF TRUTH
    /// Change here, changes everywhere in the system
    module Ports =
        // Application Tier
        let phoenixPrimary = 4000       // Primary Phoenix HTTP
        let phoenixHealth = 4001        // Health endpoint
        let phoenixChaya = 4002         // Digital Twin
        let phoenixApp2 = 4003          // HA Node 2
        let phoenixApp2Health = 4004    // HA Node 2 Health
        let phoenixApp3 = 4005          // HA Node 3
        let phoenixApp3Health = 4006    // HA Node 3 Health
        let redis = 6379                // Embedded Redis
        let prometheusMetrics = 9568    // Prometheus exporter

        // Database Tier
        let postgres = 5433             // PostgreSQL (dev offset from 5432)
        let postgresInternal = 5432     // Container internal

        // Zenoh Control Plane (2oo3 Quorum)
        let zenohRouter1Tcp = 7447      // Primary router TCP/QUIC
        let zenohRouter1Ws = 8448       // Primary router WebSocket
        let zenohRouter1Rest = 8000     // Primary router REST API
        let zenohRouter2Tcp = 7448      // Secondary router TCP/QUIC
        let zenohRouter2Ws = 8449       // Secondary router WebSocket
        let zenohRouter2Rest = 8001     // Secondary router REST API
        let zenohRouter3Tcp = 7449      // Tertiary router TCP/QUIC
        let zenohRouter3Ws = 8450       // Tertiary router WebSocket
        let zenohRouter3Rest = 8002     // Tertiary router REST API

        // Cognitive Plane
        let cepafBridge = 9876          // F# CEPAF bridge
        let cortex = 9877               // F# Cortex AI brain

        // Observability Stack
        let otelGrpc = 4317             // OTEL Collector gRPC
        let otelHttp = 4318             // OTEL Collector HTTP
        let otelMetrics = 8888          // OTEL exporter metrics
        let prometheus = 9090           // Prometheus
        let grafana = 3000              // Grafana
        let loki = 3100                 // Loki log aggregation
        let signozFrontend = 3301       // SigNoz frontend
        let signozQuery = 8080          // SigNoz query service
        let signozAlert = 9093          // SigNoz alert manager
        let clickhouseHttp = 8123       // ClickHouse HTTP
        let clickhouseNative = 9000     // ClickHouse native protocol

        /// Get all ports as list for port scouring
        let allPorts = [
            phoenixPrimary; phoenixHealth; phoenixChaya; phoenixApp2; phoenixApp2Health
            phoenixApp3; phoenixApp3Health; redis; prometheusMetrics; postgres
            zenohRouter1Tcp; zenohRouter1Ws; zenohRouter1Rest
            zenohRouter2Tcp; zenohRouter2Ws; zenohRouter2Rest
            zenohRouter3Tcp; zenohRouter3Ws; zenohRouter3Rest
            cepafBridge; cortex
            otelGrpc; otelHttp; otelMetrics; prometheus; grafana; loki
            signozFrontend; signozQuery; signozAlert
            clickhouseHttp; clickhouseNative
        ]

    /// IP Address assignments - 172.28.0.0/16 subnet
    module IpAddresses =
        let subnet = "172.28.0.0/16"
        let gateway = "172.28.0.1"
        let internalSubnet = "172.29.0.0/16"

        // Application Tier
        let appPrimary = "172.28.0.10"      // indrajaal-ex-app-1
        let appNode2 = "172.28.0.11"        // indrajaal-ex-app-2
        let appNode3 = "172.28.0.12"        // indrajaal-ex-app-3

        // Data Tier
        let database = "172.28.0.20"        // indrajaal-db-prod

        // Observability Tier
        let observability = "172.28.0.30"   // indrajaal-obs-prod

        // Zenoh Control Plane
        let zenohRouter1 = "172.28.0.40"    // Primary
        let zenohRouter2 = "172.28.0.41"    // Secondary
        let zenohRouter3 = "172.28.0.42"    // Tertiary
        let zenohProxy = "172.28.0.43"      // Proxy

        // Cognitive Plane
        let cepafBridge = "172.28.0.50"
        let cortex = "172.28.0.60"

        // Digital Twin Plane
        let chaya = "172.28.0.70"

        // Satellite Plane (FLAME runners)
        let mlRunner1 = "172.28.0.80"
        let mlRunner2 = "172.28.0.81"

    /// Hostname definitions
    module Hostnames =
        let dbProd = "indrajaal-db-prod"
        let obsProd = "indrajaal-obs-prod"
        let appPrimary = "indrajaal-ex-app-1"
        let appNode2 = "indrajaal-ex-app-2"
        let appNode3 = "indrajaal-ex-app-3"
        let zenohRouter1 = "zenoh-router-1"
        let zenohRouter2 = "zenoh-router-2"
        let zenohRouter3 = "zenoh-router-3"
        let zenohProxy = "zenoh-router"
        let cepafBridge = "cepaf-bridge"
        let cortex = "indrajaal-cortex"
        let chaya = "indrajaal-chaya"
        let mlRunner1 = "indrajaal-ml-runner-1"
        let mlRunner2 = "indrajaal-ml-runner-2"

    /// Network names
    module NetworkNames =
        let sil6Mesh = "indrajaal-sil6-mesh"
        let internalNet = "indrajaal-internal"
        let clusterNet = "indrajaal-cluster-net"
        let dbStandalone = "db-standalone-net"
        let obsStandalone = "obs-standalone-net"


/// =============================================================================
/// ANIMATION & UI TIMING CONFIGURATION
/// =============================================================================
/// Per SC-CONFIG-005: Thread.Sleep MUST reference config, no magic values
module AnimationConfig =

    /// Dashboard refresh intervals (milliseconds)
    module Dashboard =
        let refreshMs = 100             // Main dashboard refresh
        let sparklineUpdateMs = 250     // Sparkline animation update
        let progressBarUpdateMs = 50    // Progress bar animation
        let statusRefreshMs = 1000      // Status panel refresh
        let metricsRefreshMs = 500      // Metrics display refresh

    /// Boot sequence delays (milliseconds)
    module Boot =
        let stageDelayMs = 1000         // Delay between stages
        let healthCheckWaitMs = 2000    // Wait before health check
        let containerStartDelayMs = 500 // Small delay after container start
        let postBootStabilizeMs = 1000  // Stabilization after boot
        let waveCompletionDelayMs = 500 // Delay between waves

    /// OODA loop timings (milliseconds) - 30s total cycle
    module OodaLoop =
        let observeMs = 5000            // Observe phase
        let orientMs = 5000             // Orient phase
        let decideMs = 5000             // Decide phase
        let actMs = 15000               // Act phase (longest)
        let totalCycleMs = 30000        // Full OODA cycle (SC-OODA-001)
        let heartbeatMs = 1000          // Heartbeat check

    /// Retry configuration
    module Retry =
        let maxRetries = 3              // Max retry attempts
        let baseBackoffMs = 1000        // Base backoff delay
        let maxBackoffMs = 10000        // Maximum backoff
        let jitterMaxMs = 500           // Random jitter (0-500ms)

    /// Telemetry timing
    module Telemetry =
        let flushIntervalMs = 5000      // Telemetry flush interval
        let metricsPublishMs = 10000    // Metrics publish interval
        let traceSpanMaxMs = 30000      // Max trace span duration


/// =============================================================================
/// TIMEOUT CONFIGURATION - ALL TIMING VALUES
/// =============================================================================
module TimeoutConfig =

    /// Boot sequence timeouts (milliseconds)
    /// SC-OPT-001: Boot time MUST be < 60s
    /// SC-OPT-002: Health check poll MUST use exponential backoff
    module Boot =
        let totalTimeout = 60_000           // Overall boot timeout (reduced from 15s)
        let containerTimeout = 30_000       // Per-container timeout
        let healthCheckTimeout = 5_000      // Health check timeout
        let healthCheckInterval = 100       // Initial poll interval (reduced from 500ms)
        let maxHealthRetries = 30           // Max retries with backoff

        // Exponential backoff intervals for health checks (SC-OPT-002)
        // [100, 200, 400, 800, 1600, 3200, 5000, 5000, ...] ms
        let backoffIntervals = [| 100; 200; 400; 800; 1600; 3200; 5000 |]

        // Stage-specific waits (optimized for faster boot)
        let dbInitWait = 3_000              // Wait for DB after start (reduced from 5s)
        let obsInitWait = 2_000             // Wait for OBS after DB (reduced from 3s)
        let zenohInitWait = 1_000           // Wait for Zenoh mesh (reduced from 2s)
        let appHealthMaxWait = 120_000      // Max wait for app health (reduced from 5 min to 2 min)
        let appHealthRetries = 30           // 30 retries with backoff (reduced from 60)
        let appHealthRetryInterval = 2_000  // 2 second retry interval (reduced from 5s)

    /// Runtime timeouts (milliseconds)
    module Runtime =
        let oodaCycleMax = 100              // SC-OODA-001: Max OODA cycle time
        let healthHeartbeat = 10_000        // Health check interval
        let sentinelSync = 30_000           // Sentinel sync interval
        let circuitBreakerThreshold = 3     // Consecutive failures before trip
        let quorumTimeout = 5_000           // Quorum voting timeout
        let zenohReconnect = 5_000          // Zenoh reconnection delay
        let compactTrigger = 75             // Context compact at 75%

    /// Graceful shutdown timeouts
    module Shutdown =
        let lameduckPeriod = 5_000          // Pre-shutdown drain
        let drainTimeout = 30_000           // Connection drain
        let stopTimeout = 10_000            // podman stop timeout
        let killTimeout = 5_000             // podman kill timeout
        let checkpointTimeout = 10_000      // State checkpoint

    /// Jitter configuration for preventing thundering herd
    module Jitter =
        let seedDelay = 0                   // Primary seed: no delay
        let satelliteBaseDelay = 500        // Satellites: 500ms base
        let satelliteMaxJitter = 200        // Satellites: 0-200ms random


/// =============================================================================
/// CONTAINER CONFIGURATION - IMAGES, RESOURCES, HEALTH CHECKS
/// =============================================================================
module ContainerConfig =

    /// Image registry and names
    module Images =
        let registry = "localhost"
        let appUnified = $"{registry}/indrajaal-app-unified:nixos-devenv"
        let dbTimescale = $"{registry}/indrajaal-timescaledb-demo:nixos-devenv"
        let obsUnified = $"{registry}/indrajaal-obs-unified:nixos-devenv"
        let zenoh = "eclipse/zenoh:1.0.0"
        let cepafBridge = $"{registry}/cepaf-bridge:latest"
        let cortex = $"{registry}/indrajaal-cortex:latest"

    /// Resource limits
    module Resources =
        // Database
        let dbMemoryMb = 4096
        let dbCpuLimit = 4.0
        let dbMemoryReservationMb = 2048
        let dbCpuReservation = 2.0

        // Observability
        let obsMemoryMb = 10240
        let obsCpuLimit = 6.0
        let obsMemoryReservationMb = 5120
        let obsCpuReservation = 3.0

        // Application (Primary)
        let appMemoryMb = 10240
        let appCpuLimit = 8.0
        let appMemoryReservationMb = 5120
        let appCpuReservation = 4.0

        // Zenoh Routers
        let zenohMemoryMb = 512
        let zenohCpuLimit = 1.0
        let zenohMemoryReservationMb = 256
        let zenohCpuReservation = 0.5

        // Zenoh Proxy
        let zenohProxyMemoryMb = 256
        let zenohProxyCpuLimit = 0.5

        // Cognitive Plane
        let cognitiveMemoryMb = 1024
        let cognitiveCpuLimit = 2.0
        let cognitiveMemoryReservationMb = 512
        let cognitiveCpuReservation = 1.0

    /// Health check configurations
    module HealthChecks =
        // Database
        let dbTest = "pg_isready -U postgres -d indrajaal_prod -p 5433"
        let dbInterval = 5
        let dbTimeout = 5
        let dbRetries = 10
        let dbStartPeriod = 15

        // Application (SC-OPT-001: Boot time < 60s, SC-OPT-005: Pre-compiled BEAM)
        // Note: appStartPeriod reduced from 900s - assumes pre-compiled BEAM in image
        let appTest = "curl -sf http://localhost:4000/ > /dev/null || exit 1"
        let appInterval = 10         // Reduced from 30s for faster detection
        let appTimeout = 10          // Reduced from 30s for faster failure
        let appRetries = 12          // 12 × 10s = 120s max (reduced from 30 × 30s = 900s)
        let appStartPeriod = 60      // Reduced from 900s (SC-OPT-001)

        // Observability
        let obsTest = "wget -q --spider http://localhost:9090/-/healthy && wget -q --spider http://localhost:3000/api/health"
        let obsInterval = 15
        let obsTimeout = 10
        let obsRetries = 5
        let obsStartPeriod = 45

        // Zenoh
        let zenohTest = "nc -z localhost 8000"
        let zenohInterval = 10
        let zenohTimeout = 5
        let zenohRetries = 5
        let zenohStartPeriod = 10


/// =============================================================================
/// ENVIRONMENT VARIABLE CONFIGURATION
/// =============================================================================
module EnvironmentConfig =

    /// Mandatory environment variables (SC-METRICS-003)
    module Mandatory =
        let elixirErlOptions = "+fnu +S 16:16 +SDio 16"
        let noTimeout = "true"
        let patientMode = "enabled"
        let infinitePatience = "true"
        let mixPartitionCount = "8"
        let skipZenohNif = "0"  // NIF MUST be active (SC-ZENOH-001)
        let zenohEnabled = "true"
        let zenohMode = "client"
        let sil6Mode = "true"
        let biomorphicHealing = "enabled"
        let cortexIntegration = "true"

    /// Get Zenoh router endpoint for primary router
    let zenohRouterEndpoint = $"tcp://{NetworkConfig.Hostnames.zenohProxy}:{NetworkConfig.Ports.zenohRouter1Tcp}"

    /// Get database URL for specified environment
    let getDatabaseUrl (env: string) (host: string) (port: int) (db: string) =
        $"ecto://postgres:postgres@{host}:{port}/{db}_{env}"

    /// Default database URLs
    let databaseUrlDev = getDatabaseUrl "dev" "localhost" NetworkConfig.Ports.postgres "indrajaal"
    let databaseUrlProd = getDatabaseUrl "prod" NetworkConfig.Hostnames.dbProd NetworkConfig.Ports.postgres "indrajaal"
    let databaseUrlTest = getDatabaseUrl "test" "localhost" NetworkConfig.Ports.postgres "indrajaal"

    /// OTEL endpoint
    let otelEndpoint = $"http://{NetworkConfig.Hostnames.obsProd}:{NetworkConfig.Ports.otelGrpc}"

    /// CEPAF endpoints
    let cepafBridgeUrl = $"http://{NetworkConfig.Hostnames.cepafBridge}:{NetworkConfig.Ports.cepafBridge}"
    let cortexUrl = $"http://{NetworkConfig.Hostnames.cortex}:{NetworkConfig.Ports.cortex}"

    /// Build complete environment variable map for container
    let buildAppEnvironment (nodeName: string) (isSeed: bool) (env: string) : Map<string, string> =
        Map.ofList [
            ("ELIXIR_ERL_OPTIONS", Mandatory.elixirErlOptions)
            ("NO_TIMEOUT", Mandatory.noTimeout)
            ("PATIENT_MODE", Mandatory.patientMode)
            ("INFINITE_PATIENCE", Mandatory.infinitePatience)
            ("MIX_OS_DEPS_COMPILE_PARTITION_COUNT", Mandatory.mixPartitionCount)
            ("SKIP_ZENOH_NIF", Mandatory.skipZenohNif)
            ("ZENOH_ENABLED", Mandatory.zenohEnabled)
            ("ZENOH_ROUTER_ENDPOINT", zenohRouterEndpoint)
            ("ZENOH_MODE", Mandatory.zenohMode)
            ("SIL6_MODE", Mandatory.sil6Mode)
            ("BIOMORPHIC_HEALING", Mandatory.biomorphicHealing)
            ("CORTEX_INTEGRATION", Mandatory.cortexIntegration)
            ("DATABASE_URL", if env = "prod" then databaseUrlProd else databaseUrlDev)
            ("REDIS_EMBEDDED", "true")
            ("REDIS_URL", $"redis://localhost:{NetworkConfig.Ports.redis}")
            ("OTEL_EXPORTER_OTLP_ENDPOINT", otelEndpoint)
            ("CEPAF_BRIDGE_URL", cepafBridgeUrl)
            ("CORTEX_URL", cortexUrl)
            ("CLUSTERING_ENABLED", "true")
            ("RELEASE_NODE", $"indrajaal@{nodeName}")
            ("RELEASE_COOKIE", "indrajaal_prod_cookie")
            ("CLUSTER_SEED", if isSeed then "true" else "false")
            ("FLAME_ENABLED", "true")
            ("FLAME_BACKEND", "local")
            ("FLAME_MIN_POOL", "2")
            ("FLAME_MAX_POOL", "10")
            ("PRAJNA_COCKPIT_ENABLED", "true")
            ("PRAJNA_DARK_MODE", "true")
            ("PRAJNA_AI_COPILOT_ENABLED", "true")
            ("SIL_LEVEL", "6")
        ]


/// =============================================================================
/// COMPOSE FILE PATHS
/// =============================================================================
module ComposeConfig =
    let artifactsDir = "lib/cepaf/artifacts"
    let sil6FullMesh = $"{artifactsDir}/podman-compose-sil6-full-mesh.yml"
    let fractalCluster = $"{artifactsDir}/podman-compose-fractal-cluster.yml"
    let standaloneFulll = $"{artifactsDir}/podman-compose-standalone-full.yml"
    let dbStandalone = $"{artifactsDir}/podman-compose-db-standalone.yml"
    let obsStandalone = $"{artifactsDir}/podman-compose-obs-standalone.yml"
    let appStandalone = $"{artifactsDir}/podman-compose-app-standalone.yml"
    let prodStandalone = $"{artifactsDir}/podman-compose-prod-standalone.yml"


/// =============================================================================
/// QUORUM AND CONSENSUS CONFIGURATION
/// =============================================================================
module QuorumConfig =

    /// Calculate quorum requirement: Q = floor(N/2) + 1
    let calculateQuorum (nodeCount: int) : int =
        (nodeCount / 2) + 1

    /// Zenoh 2oo3 configuration
    let zenohNodeCount = 3
    let zenohQuorum = calculateQuorum zenohNodeCount  // = 2

    /// FPPS 5-point consensus
    let fppsValidatorCount = 5
    let fppsQuorum = calculateQuorum fppsValidatorCount  // = 3

    /// Circuit breaker threshold
    let circuitBreakerThreshold = 3


/// =============================================================================
/// VOLUME CONFIGURATION
/// =============================================================================
module VolumeConfig =

    /// Named volumes
    module Named =
        let dbProdData = "db_prod_data"
        let otelProdData = "otel_prod_data"
        let prometheusProdData = "prometheus_prod_data"
        let grafanaProdData = "grafana_prod_data"
        let lokiProdData = "loki_prod_data"
        let signozProdData = "signoz_prod_data"
        let clickhouseProdData = "clickhouse_prod_data"
        let appProdData = "app_prod_data"
        let redisProdData = "redis_prod_data"
        let appBuildCache = "app_build_cache"
        let appDepsCache = "app_deps_cache"

    /// Mount paths
    module Paths =
        let postgresData = "/var/lib/postgresql/pgdata"
        let otelLogs = "/var/log/otel"
        let prometheus = "/prometheus"
        let grafana = "/var/lib/grafana"
        let loki = "/loki"
        let signoz = "/var/lib/signoz"
        let clickhouse = "/var/lib/clickhouse"
        let appData = "/app/data"
        let redis = "/var/lib/redis"
        let workspace = "/workspace"
        let build = "/workspace/_build"
        let deps = "/workspace/deps"


/// =============================================================================
/// BOOT STAGE DEFINITIONS
/// =============================================================================
module BootStages =

    /// Boot stage enumeration
    type Stage =
        | S0_PREFLIGHT = 0
        | S1_INFRASTRUCTURE = 1
        | S2_ZENOH_MESH = 2
        | S3_APP_SEED = 3
        | S4_HOMEOSTASIS = 4

    /// Stage metadata
    type StageInfo = {
        Stage: Stage
        Name: string
        Description: string
        Timeout: int
        StateVectorRequired: string
        StateVectorAfter: string
    }

    let stages = [|
        { Stage = Stage.S0_PREFLIGHT
          Name = "PREFLIGHT"
          Description = "Environment validation, port scouring, container cleanup"
          Timeout = 5000
          StateVectorRequired = "[_,_,_,_,_,_]"
          StateVectorAfter = "[1,_,_,_,_,_]" }

        { Stage = Stage.S1_INFRASTRUCTURE
          Name = "INFRASTRUCTURE"
          Description = "DB + Observability containers"
          Timeout = 30000
          StateVectorRequired = "[1,_,_,_,_,_]"
          StateVectorAfter = "[1,1,1,_,_,_]" }

        { Stage = Stage.S2_ZENOH_MESH
          Name = "ZENOH_MESH"
          Description = "Zenoh router + quorum verification"
          Timeout = 5000
          StateVectorRequired = "[1,1,1,_,_,_]"
          StateVectorAfter = "[1,1,1,1,_,_]" }

        { Stage = Stage.S3_APP_SEED
          Name = "APP_SEED"
          Description = "Application boot with health wait"
          Timeout = 300000  // 5 minutes for compilation
          StateVectorRequired = "[1,1,1,1,_,_]"
          StateVectorAfter = "[1,1,1,1,1,_]" }

        { Stage = Stage.S4_HOMEOSTASIS
          Name = "HOMEOSTASIS"
          Description = "Health verification, quorum, Cortex verify"
          Timeout = 10000
          StateVectorRequired = "[1,1,1,1,1,_]"
          StateVectorAfter = "[1,1,1,1,1,1]" }
    |]

    let getStageInfo (stage: Stage) : StageInfo =
        stages.[int stage]


/// =============================================================================
/// STAMP CONSTRAINT DEFINITIONS FOR BOOT
/// =============================================================================
module StampConstraints =

    type Constraint = {
        Id: string
        Description: string
        Severity: string
        Enforcement: string
    }

    let bootConstraints = [|
        { Id = "SC-BOOT-001"; Description = "State vector MUST be verified before each stage"; Severity = "CRITICAL"; Enforcement = "Pre-stage gate" }
        { Id = "SC-BOOT-002"; Description = "Migration status MUST be checked before S3"; Severity = "CRITICAL"; Enforcement = "Migration gate" }
        { Id = "SC-BOOT-003"; Description = "Quorum MUST be achieved before S3"; Severity = "CRITICAL"; Enforcement = "Quorum gate" }
        { Id = "SC-BOOT-004"; Description = "Boot MUST be transactional (rollback on fail)"; Severity = "CRITICAL"; Enforcement = "Rollback handler" }
        { Id = "SC-BOOT-005"; Description = "Boot time MUST be < 120s (target 60s)"; Severity = "HIGH"; Enforcement = "Timeout enforcement" }
        { Id = "SC-BOOT-006"; Description = "All containers MUST pass health check"; Severity = "HIGH"; Enforcement = "Health gate" }
        { Id = "SC-BOOT-007"; Description = "Ports MUST be scoured before boot"; Severity = "HIGH"; Enforcement = "Port isolation" }
        { Id = "SC-BOOT-008"; Description = "DAG MUST be acyclic (verified by Kahn)"; Severity = "CRITICAL"; Enforcement = "Topology validation" }
        { Id = "SC-BOOT-009"; Description = "Waves MUST boot in parallel within wave"; Severity = "HIGH"; Enforcement = "Parallelization" }
        { Id = "SC-BOOT-010"; Description = "Checkpoints MUST be created at each stage"; Severity = "HIGH"; Enforcement = "Dying gasp" }
    |]

    let configConstraints = [|
        { Id = "SC-CONFIG-001"; Description = "All configuration MUST be in single location"; Severity = "CRITICAL"; Enforcement = "Code review" }
        { Id = "SC-CONFIG-002"; Description = "NO magic values in boot/runtime code"; Severity = "CRITICAL"; Enforcement = "Static analysis" }
        { Id = "SC-CONFIG-003"; Description = "Change ONE location for system-wide updates"; Severity = "HIGH"; Enforcement = "Architecture rule" }
    |]


/// =============================================================================
/// FMEA RISK DEFINITIONS
/// =============================================================================
module FmeaConfig =

    type FailureMode = {
        Id: string
        Failure: string
        Effect: string
        Severity: int
        Occurrence: int
        Detection: int
        Rpn: int
        Mitigation: string
    }

    let bootFailureModes = [|
        { Id = "FM-BOOT-001"; Failure = "Port conflict"; Effect = "Container fails to start"; Severity = 7; Occurrence = 5; Detection = 4; Rpn = 140; Mitigation = "Port scouring in S0" }
        { Id = "FM-BOOT-002"; Failure = "DB not running"; Effect = "Commands fail"; Severity = 8; Occurrence = 4; Detection = 6; Rpn = 192; Mitigation = "Pre-check with pg_isready" }
        { Id = "FM-BOOT-003"; Failure = "NIF disabled"; Effect = "Tests skip Zenoh"; Severity = 7; Occurrence = 6; Detection = 6; Rpn = 252; Mitigation = "Force SKIP_ZENOH_NIF=0" }
        { Id = "FM-BOOT-004"; Failure = ".NET missing"; Effect = "CEPAF fails"; Severity = 6; Occurrence = 9; Detection = 54; Rpn = 54; Mitigation = "Check dotnet version" }
        { Id = "FM-BOOT-005"; Failure = "F# build fails"; Effect = "Cockpit unavailable"; Severity = 8; Occurrence = 10; Detection = 8; Rpn = 80; Mitigation = "Dedicated fix sprint" }
        { Id = "FM-BOOT-006"; Failure = "Migrations missing"; Effect = "Oban tables undefined"; Severity = 9; Occurrence = 3; Detection = 8; Rpn = 216; Mitigation = "Migration gate in S1" }
        { Id = "FM-BOOT-007"; Failure = "Quorum lost"; Effect = "Cluster unstable"; Severity = 8; Occurrence = 4; Detection = 5; Rpn = 160; Mitigation = "2oo3 Zenoh voting" }
        { Id = "FM-BOOT-008"; Failure = "Health check timeout"; Effect = "Container marked unhealthy"; Severity = 6; Occurrence = 5; Detection = 3; Rpn = 90; Mitigation = "Patient mode + 900s start" }
    |]

    /// Get all failure modes with RPN > threshold
    let getHighRiskFailures (threshold: int) =
        bootFailureModes |> Array.filter (fun fm -> fm.Rpn >= threshold)


/// =============================================================================
/// CONFIGURATION VALIDATION
/// =============================================================================
module ConfigValidation =

    /// Validate all ports are unique
    let validateUniquePorts () : Result<unit, string> =
        let ports = NetworkConfig.Ports.allPorts
        let duplicates =
            ports
            |> List.groupBy id
            |> List.filter (fun (_, group) -> List.length group > 1)
            |> List.map fst
        if List.isEmpty duplicates then
            Ok ()
        else
            Error $"Duplicate ports found: {duplicates}"

    /// Validate IP addresses are in correct subnet
    let validateIpSubnet (ip: string) (subnet: string) : bool =
        // Simple validation - real implementation would parse CIDR
        ip.StartsWith("172.28.0.") || ip.StartsWith("172.29.0.")

    /// Validate all configuration
    let validateAll () : Result<unit, string list> =
        let errors = ResizeArray<string>()

        // Validate ports
        match validateUniquePorts () with
        | Ok () -> ()
        | Error e -> errors.Add(e)

        // Validate quorum
        if QuorumConfig.zenohQuorum < 2 then
            errors.Add("Zenoh quorum must be at least 2 for 2oo3 voting")

        // Validate timeouts
        if TimeoutConfig.Boot.totalTimeout > TimeoutConfig.Boot.appHealthMaxWait then
            errors.Add("Total timeout must be less than app health max wait")

        if errors.Count = 0 then
            Ok ()
        else
            Error (errors |> Seq.toList)

    /// SC-CONSOL-005: Validate configuration at boot, fail fast on errors
    /// Call this at the start of boot sequence before any container operations
    let validateAtBoot () : unit =
        match validateAll () with
        | Ok () ->
            printfn "[CONFIG] ✓ Configuration validation passed"
        | Error errors ->
            printfn "[CONFIG] ✗ FATAL: Configuration validation failed!"
            errors |> List.iter (printfn "[CONFIG]   - %s")
            failwith $"Configuration validation failed with {List.length errors} error(s). Boot aborted per SC-CONSOL-005."

    /// Check if configuration is valid (non-throwing version)
    let isValid () : bool =
        match validateAll () with
        | Ok () -> true
        | Error _ -> false


/// =============================================================================
/// CONFIGURATION EXPORT
/// =============================================================================
module ConfigExport =

    /// Export configuration as JSON for Elixir consumption
    let toJson () : string =
        // This would serialize the configuration for cross-language use
        let config = {|
            Ports = {|
                Phoenix = NetworkConfig.Ports.phoenixPrimary
                Health = NetworkConfig.Ports.phoenixHealth
                Postgres = NetworkConfig.Ports.postgres
                ZenohTcp = NetworkConfig.Ports.zenohRouter1Tcp
                OtelGrpc = NetworkConfig.Ports.otelGrpc
                Grafana = NetworkConfig.Ports.grafana
            |}
            Timeouts = {|
                TotalBoot = TimeoutConfig.Boot.totalTimeout
                HealthCheck = TimeoutConfig.Boot.healthCheckTimeout
                OodaCycle = TimeoutConfig.Runtime.oodaCycleMax
            |}
            Quorum = {|
                ZenohNodes = QuorumConfig.zenohNodeCount
                ZenohQuorum = QuorumConfig.zenohQuorum
                FppsQuorum = QuorumConfig.fppsQuorum
            |}
        |}
        System.Text.Json.JsonSerializer.Serialize(config)

    /// Print configuration summary
    let printSummary () =
        printfn "=== CEPAF MESH CONFIGURATION SUMMARY ==="
        printfn ""
        printfn "=== PORTS ==="
        printfn "  Phoenix Primary: %d" NetworkConfig.Ports.phoenixPrimary
        printfn "  PostgreSQL: %d" NetworkConfig.Ports.postgres
        printfn "  Zenoh Router: %d" NetworkConfig.Ports.zenohRouter1Tcp
        printfn "  OTEL Collector: %d" NetworkConfig.Ports.otelGrpc
        printfn "  Grafana: %d" NetworkConfig.Ports.grafana
        printfn ""
        printfn "=== TIMEOUTS ==="
        printfn "  Total Boot: %dms" TimeoutConfig.Boot.totalTimeout
        printfn "  Container: %dms" TimeoutConfig.Boot.containerTimeout
        printfn "  Health Check: %dms" TimeoutConfig.Boot.healthCheckTimeout
        printfn "  OODA Cycle: %dms" TimeoutConfig.Runtime.oodaCycleMax
        printfn ""
        printfn "=== QUORUM ==="
        printfn "  Zenoh Nodes: %d" QuorumConfig.zenohNodeCount
        printfn "  Zenoh Quorum: %d" QuorumConfig.zenohQuorum
        printfn "  FPPS Quorum: %d" QuorumConfig.fppsQuorum
        printfn ""
        printfn "=== VALIDATION ==="
        match ConfigValidation.validateAll () with
        | Ok () -> printfn "  ✓ All configuration valid"
        | Error errors ->
            printfn "  ✗ Configuration errors:"
            errors |> List.iter (printfn "    - %s")
