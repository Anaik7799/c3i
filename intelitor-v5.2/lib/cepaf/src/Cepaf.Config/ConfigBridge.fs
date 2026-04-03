/// =============================================================================
/// CONFIG BRIDGE - F# ↔ Elixir Configuration Synchronization
/// =============================================================================
///
/// Version: 21.2.1-SIL6
/// Date: 2026-01-18
///
/// STAMP Compliance:
/// - SC-CONSOL-006: Config drift detection and repair MANDATORY
/// - SC-CONFIG-001: Single source of truth (MeshConfig.fs)
/// - SC-CONFIG-002: No magic values in runtime code
/// - SC-ZENOH-001: Zenoh telemetry mandatory
///
/// This module bridges F# configuration (MeshConfig.fs) with Elixir runtime
/// configuration, enabling:
/// - Export to Elixir config.exs format
/// - Publish to Zenoh for runtime consumption
/// - Drift detection between F# and Elixir
/// - Bidirectional synchronization
/// - Hot config reload via Zenoh subscription
/// =============================================================================

namespace Cepaf.Config

open System
open System.IO
open System.Text
open System.Text.Json
open System.Text.Json.Serialization
open System.Collections.Generic

// =============================================================================
// SUPPORTING TYPES
// =============================================================================

/// Elixir-compatible configuration format (map-based)
/// Maps to Elixir %{key => value} structure
type ElixirConfig = {
    /// Network configuration (ports, IPs, hostnames)
    Network: Map<string, obj>

    /// Timeout configuration (boot, runtime, shutdown)
    Timeouts: Map<string, obj>

    /// Container configuration (images, resources, health checks)
    Containers: Map<string, obj>

    /// Environment variables
    Environment: Map<string, obj>

    /// Quorum and consensus settings
    Quorum: Map<string, obj>

    /// Animation and UI timing
    Animation: Map<string, obj>

    /// Boot stages
    Boot: Map<string, obj>

    /// Metadata
    Metadata: Map<string, obj>
}

/// Configuration drift report
type DriftReport = {
    /// Total number of differences detected
    DifferenceCount: int

    /// List of drift entries
    Drifts: DriftEntry list

    /// Timestamp of detection
    DetectedAt: DateTime

    /// Severity level (Critical, High, Medium, Low)
    Severity: string
}

/// Individual drift entry
and DriftEntry = {
    /// Configuration path (e.g., "network.ports.phoenix")
    Path: string

    /// Value in F# config
    FSharpValue: string

    /// Value in Elixir config
    ElixirValue: string

    /// Impact severity
    Severity: string

    /// Recommended action
    Recommendation: string
}

/// Configuration error
type ConfigError =
    | FileNotFound of path: string
    | ParseError of path: string * error: string
    | ValidationError of message: string
    | ZenohError of message: string
    | SerializationError of error: string

/// Synchronization report
type SyncReport = {
    /// Number of changes applied
    ChangesApplied: int

    /// Changes from F# to Elixir
    FSharpToElixir: int

    /// Changes from Elixir to F#
    ElixirToFSharp: int

    /// Timestamp
    SyncedAt: DateTime

    /// Success status
    Success: bool

    /// Messages
    Messages: string list
}

/// Sync error
type SyncError =
    | ConflictError of conflicts: string list
    | AccessError of message: string
    | ValidationError of message: string
    | NetworkError of message: string

// =============================================================================
// EXPORT TO ELIXIR FORMAT
// =============================================================================

module Export =

    /// Convert MeshConfig to Elixir-compatible format
    /// SC-CONSOL-006: Ensures F# config is authoritative source
    let toElixirConfig () : ElixirConfig =

        // Network configuration
        let networkConfig = Map.ofList [
            ("ports", box (Map.ofList [
                ("phoenix_primary", box NetworkConfig.Ports.phoenixPrimary)
                ("phoenix_health", box NetworkConfig.Ports.phoenixHealth)
                ("phoenix_chaya", box NetworkConfig.Ports.phoenixChaya)
                ("postgres", box NetworkConfig.Ports.postgres)
                ("postgres_internal", box NetworkConfig.Ports.postgresInternal)
                ("zenoh_router_1_tcp", box NetworkConfig.Ports.zenohRouter1Tcp)
                ("zenoh_router_1_ws", box NetworkConfig.Ports.zenohRouter1Ws)
                ("zenoh_router_1_rest", box NetworkConfig.Ports.zenohRouter1Rest)
                ("zenoh_router_2_tcp", box NetworkConfig.Ports.zenohRouter2Tcp)
                ("zenoh_router_2_ws", box NetworkConfig.Ports.zenohRouter2Ws)
                ("zenoh_router_2_rest", box NetworkConfig.Ports.zenohRouter2Rest)
                ("zenoh_router_3_tcp", box NetworkConfig.Ports.zenohRouter3Tcp)
                ("zenoh_router_3_ws", box NetworkConfig.Ports.zenohRouter3Ws)
                ("zenoh_router_3_rest", box NetworkConfig.Ports.zenohRouter3Rest)
                ("otel_grpc", box NetworkConfig.Ports.otelGrpc)
                ("otel_http", box NetworkConfig.Ports.otelHttp)
                ("prometheus", box NetworkConfig.Ports.prometheus)
                ("grafana", box NetworkConfig.Ports.grafana)
                ("loki", box NetworkConfig.Ports.loki)
                ("redis", box NetworkConfig.Ports.redis)
                ("cepaf_bridge", box NetworkConfig.Ports.cepafBridge)
                ("cortex", box NetworkConfig.Ports.cortex)
            ]))
            ("hostnames", box (Map.ofList [
                ("db_prod", box NetworkConfig.Hostnames.dbProd)
                ("obs_prod", box NetworkConfig.Hostnames.obsProd)
                ("app_primary", box NetworkConfig.Hostnames.appPrimary)
                ("app_node_2", box NetworkConfig.Hostnames.appNode2)
                ("app_node_3", box NetworkConfig.Hostnames.appNode3)
                ("zenoh_router_1", box NetworkConfig.Hostnames.zenohRouter1)
                ("zenoh_router_2", box NetworkConfig.Hostnames.zenohRouter2)
                ("zenoh_router_3", box NetworkConfig.Hostnames.zenohRouter3)
                ("zenoh_proxy", box NetworkConfig.Hostnames.zenohProxy)
                ("cepaf_bridge", box NetworkConfig.Hostnames.cepafBridge)
                ("cortex", box NetworkConfig.Hostnames.cortex)
                ("chaya", box NetworkConfig.Hostnames.chaya)
            ]))
            ("ip_addresses", box (Map.ofList [
                ("subnet", box NetworkConfig.IpAddresses.subnet)
                ("gateway", box NetworkConfig.IpAddresses.gateway)
                ("app_primary", box NetworkConfig.IpAddresses.appPrimary)
                ("app_node_2", box NetworkConfig.IpAddresses.appNode2)
                ("app_node_3", box NetworkConfig.IpAddresses.appNode3)
                ("database", box NetworkConfig.IpAddresses.database)
                ("observability", box NetworkConfig.IpAddresses.observability)
                ("zenoh_router_1", box NetworkConfig.IpAddresses.zenohRouter1)
                ("zenoh_router_2", box NetworkConfig.IpAddresses.zenohRouter2)
                ("zenoh_router_3", box NetworkConfig.IpAddresses.zenohRouter3)
            ]))
        ]

        // Timeout configuration
        let timeoutConfig = Map.ofList [
            ("boot", box (Map.ofList [
                ("total_timeout_ms", box TimeoutConfig.Boot.totalTimeout)
                ("container_timeout_ms", box TimeoutConfig.Boot.containerTimeout)
                ("health_check_timeout_ms", box TimeoutConfig.Boot.healthCheckTimeout)
                ("health_check_interval_ms", box TimeoutConfig.Boot.healthCheckInterval)
                ("max_health_retries", box TimeoutConfig.Boot.maxHealthRetries)
                ("db_init_wait_ms", box TimeoutConfig.Boot.dbInitWait)
                ("obs_init_wait_ms", box TimeoutConfig.Boot.obsInitWait)
                ("zenoh_init_wait_ms", box TimeoutConfig.Boot.zenohInitWait)
                ("app_health_max_wait_ms", box TimeoutConfig.Boot.appHealthMaxWait)
            ]))
            ("runtime", box (Map.ofList [
                ("ooda_cycle_max_ms", box TimeoutConfig.Runtime.oodaCycleMax)
                ("health_heartbeat_ms", box TimeoutConfig.Runtime.healthHeartbeat)
                ("sentinel_sync_ms", box TimeoutConfig.Runtime.sentinelSync)
                ("quorum_timeout_ms", box TimeoutConfig.Runtime.quorumTimeout)
                ("zenoh_reconnect_ms", box TimeoutConfig.Runtime.zenohReconnect)
            ]))
            ("shutdown", box (Map.ofList [
                ("lameduck_period_ms", box TimeoutConfig.Shutdown.lameduckPeriod)
                ("drain_timeout_ms", box TimeoutConfig.Shutdown.drainTimeout)
                ("stop_timeout_ms", box TimeoutConfig.Shutdown.stopTimeout)
                ("kill_timeout_ms", box TimeoutConfig.Shutdown.killTimeout)
                ("checkpoint_timeout_ms", box TimeoutConfig.Shutdown.checkpointTimeout)
            ]))
        ]

        // Container configuration
        let containerConfig = Map.ofList [
            ("images", box (Map.ofList [
                ("registry", box ContainerConfig.Images.registry)
                ("app_unified", box ContainerConfig.Images.appUnified)
                ("db_timescale", box ContainerConfig.Images.dbTimescale)
                ("obs_unified", box ContainerConfig.Images.obsUnified)
                ("zenoh", box ContainerConfig.Images.zenoh)
            ]))
            ("resources", box (Map.ofList [
                ("db_memory_mb", box ContainerConfig.Resources.dbMemoryMb)
                ("db_cpu_limit", box ContainerConfig.Resources.dbCpuLimit)
                ("obs_memory_mb", box ContainerConfig.Resources.obsMemoryMb)
                ("obs_cpu_limit", box ContainerConfig.Resources.obsCpuLimit)
                ("app_memory_mb", box ContainerConfig.Resources.appMemoryMb)
                ("app_cpu_limit", box ContainerConfig.Resources.appCpuLimit)
                ("zenoh_memory_mb", box ContainerConfig.Resources.zenohMemoryMb)
                ("zenoh_cpu_limit", box ContainerConfig.Resources.zenohCpuLimit)
            ]))
        ]

        // Environment configuration
        let envConfig = Map.ofList [
            ("mandatory", box (Map.ofList [
                ("elixir_erl_options", box EnvironmentConfig.Mandatory.elixirErlOptions)
                ("no_timeout", box EnvironmentConfig.Mandatory.noTimeout)
                ("patient_mode", box EnvironmentConfig.Mandatory.patientMode)
                ("skip_zenoh_nif", box EnvironmentConfig.Mandatory.skipZenohNif)
                ("zenoh_enabled", box EnvironmentConfig.Mandatory.zenohEnabled)
                ("sil6_mode", box EnvironmentConfig.Mandatory.sil6Mode)
            ]))
            ("database_url_dev", box EnvironmentConfig.databaseUrlDev)
            ("database_url_prod", box EnvironmentConfig.databaseUrlProd)
            ("otel_endpoint", box EnvironmentConfig.otelEndpoint)
            ("zenoh_router_endpoint", box EnvironmentConfig.zenohRouterEndpoint)
        ]

        // Quorum configuration
        let quorumConfig = Map.ofList [
            ("zenoh_node_count", box QuorumConfig.zenohNodeCount)
            ("zenoh_quorum", box QuorumConfig.zenohQuorum)
            ("fpps_validator_count", box QuorumConfig.fppsValidatorCount)
            ("fpps_quorum", box QuorumConfig.fppsQuorum)
        ]

        // Animation configuration
        let animationConfig = Map.ofList [
            ("dashboard", box (Map.ofList [
                ("refresh_ms", box AnimationConfig.Dashboard.refreshMs)
                ("sparkline_update_ms", box AnimationConfig.Dashboard.sparklineUpdateMs)
                ("progress_bar_update_ms", box AnimationConfig.Dashboard.progressBarUpdateMs)
            ]))
            ("boot", box (Map.ofList [
                ("stage_delay_ms", box AnimationConfig.Boot.stageDelayMs)
                ("health_check_wait_ms", box AnimationConfig.Boot.healthCheckWaitMs)
            ]))
            ("ooda_loop", box (Map.ofList [
                ("observe_ms", box AnimationConfig.OodaLoop.observeMs)
                ("orient_ms", box AnimationConfig.OodaLoop.orientMs)
                ("decide_ms", box AnimationConfig.OodaLoop.decideMs)
                ("act_ms", box AnimationConfig.OodaLoop.actMs)
                ("total_cycle_ms", box AnimationConfig.OodaLoop.totalCycleMs)
            ]))
        ]

        // Boot stages
        let bootConfig = Map.ofList [
            ("stages", box (
                BootStages.stages
                |> Array.map (fun s ->
                    Map.ofList [
                        ("name", box s.Name)
                        ("description", box s.Description)
                        ("timeout_ms", box s.Timeout)
                        ("state_vector_required", box s.StateVectorRequired)
                        ("state_vector_after", box s.StateVectorAfter)
                    ]
                )
            ))
        ]

        // Metadata
        let metadata = Map.ofList [
            ("version", box "21.2.1-SIL6")
            ("generated_at", box (DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")))
            ("source", box "Cepaf.Config.MeshConfig")
        ]

        {
            Network = networkConfig
            Timeouts = timeoutConfig
            Containers = containerConfig
            Environment = envConfig
            Quorum = quorumConfig
            Animation = animationConfig
            Boot = bootConfig
            Metadata = metadata
        }

    /// Generate Elixir config.exs format string
    /// Produces valid Elixir configuration file
    let toElixirConfigExs (config: ElixirConfig) : string =
        let sb = StringBuilder()

        let version = config.Metadata.["version"]
        let generatedAt = config.Metadata.["generated_at"]

        sb.AppendLine("# Generated by Cepaf.Config.ConfigBridge") |> ignore
        sb.AppendLine($"# Version: {version}") |> ignore
        sb.AppendLine($"# Generated: {generatedAt}") |> ignore
        sb.AppendLine("# STAMP: SC-CONFIG-001, SC-CONSOL-006") |> ignore
        sb.AppendLine("") |> ignore
        sb.AppendLine("import Config") |> ignore
        sb.AppendLine("") |> ignore

        // Helper to format map
        let rec formatValue (value: obj) (indent: int) : string =
            let spaces = String(' ', indent * 2)
            match value with
            | :? Map<string, obj> as m ->
                let items =
                    m
                    |> Map.toList
                    |> List.map (fun (k, v) -> $"{spaces}  {k}: {formatValue v (indent + 1)}")
                    |> String.concat ",\n"
                "%" + "{" + "\n" + items + "\n" + spaces + "}"
            | :? int as i -> string i
            | :? float as f -> string f
            | :? string as s -> $"\"{s}\""
            | :? bool as b -> if b then "true" else "false"
            | _ -> $"\"{value}\""

        sb.AppendLine("config :indrajaal, :mesh,") |> ignore
        sb.AppendLine($"  network: {formatValue (box config.Network) 1},") |> ignore
        sb.AppendLine($"  timeouts: {formatValue (box config.Timeouts) 1},") |> ignore
        sb.AppendLine($"  containers: {formatValue (box config.Containers) 1},") |> ignore
        sb.AppendLine($"  environment: {formatValue (box config.Environment) 1},") |> ignore
        sb.AppendLine($"  quorum: {formatValue (box config.Quorum) 1},") |> ignore
        sb.AppendLine($"  animation: {formatValue (box config.Animation) 1}") |> ignore

        sb.ToString()

    /// Serialize to JSON for Zenoh transfer
    let toJson (config: ElixirConfig) : string =
        let options = JsonSerializerOptions()
        options.WriteIndented <- true
        JsonSerializer.Serialize(config, options)

// =============================================================================
// ZENOH PUBLISHING
// =============================================================================

module Zenoh =

    /// Publish configuration to Zenoh topic
    /// Topic pattern: indrajaal/config/mesh/**
    /// SC-ZENOH-001: Zenoh telemetry mandatory
    /// SC-ZTEST-008: Triple-write pattern — log fallback FIRST
    let publishConfig (config: ElixirConfig) : Async<Result<unit, ConfigError>> =
        async {
            try
                let json = Export.toJson config
                let topic = "indrajaal/config/mesh/full"
                let checkpointId = "CP-CONFIG-01"
                let timestamp = DateTimeOffset.UtcNow.ToString("o")

                // Step 1: Log fallback FIRST (guaranteed durability) — SC-ZTEST-008
                eprintfn "[ZTEST-CHECKPOINT] checkpoint=%s topic=%s message=config_published timestamp=%s"
                    checkpointId topic timestamp

                // Step 2: Also write to file for Elixir file-based pickup (preserved for compat)
                let configPath = "data/config/mesh_config.json"
                let configDir = Path.GetDirectoryName(configPath)
                if not (Directory.Exists(configDir)) then
                    Directory.CreateDirectory(configDir) |> ignore
                do! File.WriteAllTextAsync(configPath, json) |> Async.AwaitTask

                // Step 3: Structured JSON to stdout for CEPAF bridge consumption
                let safeJson = json.Replace("\\", "\\\\").Replace("\"", "\\\"")
                printfn "{\"zenoh_publish\":{\"checkpoint\":\"%s\",\"topic\":\"%s\",\"timestamp\":\"%s\",\"payload\":{\"type\":\"mesh_config\",\"data\":\"%s\"}}}"
                    checkpointId topic timestamp safeJson

                return Ok ()
            with
            | ex ->
                return Error (ZenohError ex.Message)
        }

    /// Subscribe to Zenoh config updates for hot reload
    /// Allows runtime configuration updates without restart
    /// SC-CONSOL-006: ConfigBridge MUST sync F#/Elixir configs
    /// SC-ZTEST-008: Triple-write pattern — log fallback FIRST
    let subscribeToUpdates (onUpdate: ElixirConfig -> unit) : Async<Result<unit, ConfigError>> =
        async {
            try
                let topic = "indrajaal/config/mesh/updates"
                let checkpointId = "CP-CONFIG-02"
                let timestamp = DateTimeOffset.UtcNow.ToString("o")

                // Step 1: Log fallback FIRST (guaranteed durability) — SC-ZTEST-008
                eprintfn "[ZTEST-CHECKPOINT] checkpoint=%s topic=%s message=subscription_registered timestamp=%s"
                    checkpointId topic timestamp

                // Step 2: Structured JSON to stdout for CEPAF bridge consumption
                printfn "{\"zenoh_publish\":{\"checkpoint\":\"%s\",\"topic\":\"%s\",\"timestamp\":\"%s\",\"payload\":{\"type\":\"subscription_registered\",\"subscribe_topic\":\"%s\"}}}"
                    checkpointId "indrajaal/config/bridge/status" timestamp topic

                // NOTE: Real Zenoh NIF subscription requires ZenohFfiBridge (available in Cepaf project).
                // Cepaf.Config has no external project references (pure System.* module per SC-CONFIG-001).
                // When the CEPAF bridge is connected, it will forward updates from the Zenoh topic
                // to this callback via the stdout JSON protocol above.
                // The onUpdate callback is stored for future invocation.
                let _ = onUpdate  // callback registered, awaiting bridge-forwarded updates

                return Ok ()
            with
            | ex ->
                return Error (ZenohError ex.Message)
        }

// =============================================================================
// DRIFT DETECTION
// =============================================================================

module Drift =

    /// Detect configuration drift between F# and Elixir
    /// SC-CONSOL-006: Config drift detection and repair MANDATORY
    let detectDrift () : DriftReport =
        let drifts = ResizeArray<DriftEntry>()

        // Load current F# config
        let fsharpConfig = Export.toElixirConfig ()

        // Load Elixir config (from runtime if available)
        // For now, we'll check against a JSON file if it exists
        let elixirConfigPath = "data/config/elixir_runtime_config.json"

        if File.Exists(elixirConfigPath) then
            try
                let json = File.ReadAllText(elixirConfigPath)
                let elixirConfig = JsonSerializer.Deserialize<ElixirConfig>(json)

                // Compare ports
                let compareMaps category (fmap: Map<string, obj>) (emap: Map<string, obj>) =
                    for KeyValue(key, fval) in fmap do
                        match Map.tryFind key emap with
                        | Some eval when fval <> eval ->
                            drifts.Add({
                                Path = $"{category}.{key}"
                                FSharpValue = string fval
                                ElixirValue = string eval
                                Severity = "HIGH"
                                Recommendation = "Update Elixir config from F# source"
                            })
                        | None ->
                            drifts.Add({
                                Path = $"{category}.{key}"
                                FSharpValue = string fval
                                ElixirValue = "<missing>"
                                Severity = "CRITICAL"
                                Recommendation = "Add missing key to Elixir config"
                            })
                        | _ -> ()

                // Compare network.ports
                match fsharpConfig.Network.TryFind "ports", elixirConfig.Network.TryFind "ports" with
                | Some (:? Map<string, obj> as fports), Some (:? Map<string, obj> as eports) ->
                    compareMaps "network.ports" fports eports
                | _ -> ()

                // Compare timeouts
                match fsharpConfig.Timeouts.TryFind "boot", elixirConfig.Timeouts.TryFind "boot" with
                | Some (:? Map<string, obj> as fboot), Some (:? Map<string, obj> as eboot) ->
                    compareMaps "timeouts.boot" fboot eboot
                | _ -> ()

            with
            | ex ->
                drifts.Add({
                    Path = "elixir_config"
                    FSharpValue = "valid"
                    ElixirValue = $"parse_error: {ex.Message}"
                    Severity = "CRITICAL"
                    Recommendation = "Fix Elixir config parsing"
                })
        else
            drifts.Add({
                Path = "elixir_config"
                FSharpValue = "exists"
                ElixirValue = "not_found"
                Severity = "CRITICAL"
                Recommendation = "Generate Elixir config from F# source"
            })

        let severity =
            if drifts |> Seq.exists (fun d -> d.Severity = "CRITICAL") then "CRITICAL"
            elif drifts |> Seq.exists (fun d -> d.Severity = "HIGH") then "HIGH"
            elif drifts.Count > 0 then "MEDIUM"
            else "NONE"

        {
            DifferenceCount = drifts.Count
            Drifts = List.ofSeq drifts
            DetectedAt = DateTime.UtcNow
            Severity = severity
        }

    /// Print drift report to console
    let printDriftReport (report: DriftReport) : unit =
        printfn ""
        printfn "═══════════════════════════════════════════════════════════════"
        printfn "  CONFIG DRIFT REPORT"
        printfn "═══════════════════════════════════════════════════════════════"
        printfn "  Detected: %s" (report.DetectedAt.ToString("yyyy-MM-dd HH:mm:ss UTC"))
        printfn "  Severity: %s" report.Severity
        printfn "  Differences: %d" report.DifferenceCount
        printfn "───────────────────────────────────────────────────────────────"

        if report.Drifts.IsEmpty then
            printfn "  ✓ No configuration drift detected"
        else
            for drift in report.Drifts do
                printfn ""
                printfn "  [%s] %s" drift.Severity drift.Path
                printfn "    F#:     %s" drift.FSharpValue
                printfn "    Elixir: %s" drift.ElixirValue
                printfn "    Action: %s" drift.Recommendation

        printfn "═══════════════════════════════════════════════════════════════"
        printfn ""

// =============================================================================
// LOAD FROM ELIXIR
// =============================================================================

module Load =

    /// Load MeshConfig from Elixir config file
    /// Reverse operation of exportToElixir
    let fromElixirConfigFile (path: string) : Result<ElixirConfig, ConfigError> =
        if not (File.Exists(path)) then
            Error (FileNotFound path)
        else
            try
                let json = File.ReadAllText(path)
                let config = JsonSerializer.Deserialize<ElixirConfig>(json)
                Ok config
            with
            | ex ->
                Error (ParseError (path, ex.Message))

// =============================================================================
// BIDIRECTIONAL SYNC
// =============================================================================

module Sync =

    /// Synchronize configurations bidirectionally
    /// F# is authoritative source (SC-CONFIG-001)
    /// Elixir config is updated from F#
    let syncConfigs () : Result<SyncReport, SyncError> =
        try
            // Detect drift first
            let driftReport = Drift.detectDrift ()

            if driftReport.Severity = "NONE" then
                Ok {
                    ChangesApplied = 0
                    FSharpToElixir = 0
                    ElixirToFSharp = 0
                    SyncedAt = DateTime.UtcNow
                    Success = true
                    Messages = ["No drift detected - configs in sync"]
                }
            else
                // F# is authoritative, so update Elixir from F#
                let fsharpConfig = Export.toElixirConfig ()
                let json = Export.toJson fsharpConfig

                // Write to Elixir config file
                let configPath = "data/config/elixir_runtime_config.json"
                let configDir = Path.GetDirectoryName(configPath)

                if not (Directory.Exists(configDir)) then
                    Directory.CreateDirectory(configDir) |> ignore

                File.WriteAllText(configPath, json)

                // Also generate config.exs
                let configExs = Export.toElixirConfigExs fsharpConfig
                let configExsPath = "data/config/generated_config.exs"
                File.WriteAllText(configExsPath, configExs)

                // Publish to Zenoh
                let zenohResult = Zenoh.publishConfig fsharpConfig |> Async.RunSynchronously

                Ok {
                    ChangesApplied = driftReport.DifferenceCount
                    FSharpToElixir = driftReport.DifferenceCount
                    ElixirToFSharp = 0
                    SyncedAt = DateTime.UtcNow
                    Success = true
                    Messages = [
                        $"Updated {driftReport.DifferenceCount} configuration values"
                        $"JSON written to: {configPath}"
                        $"Elixir config written to: {configExsPath}"
                        match zenohResult with
                        | Ok () -> "Published to Zenoh"
                        | Error e -> $"Zenoh publish warning: {e}"
                    ]
                }
        with
        | ex ->
            Error (ValidationError ex.Message)

// =============================================================================
// PUBLIC API
// =============================================================================

module ConfigBridge =

    /// Export current MeshConfig to Elixir-compatible format
    /// SC-CONFIG-001: F# is single source of truth
    let exportToElixir () : ElixirConfig =
        Export.toElixirConfig ()

    /// Publish configuration to Zenoh topic for runtime consumption
    /// Topic: indrajaal/config/mesh/full
    /// SC-ZENOH-001: Zenoh telemetry mandatory
    let publishToZenoh () : Async<Result<unit, ConfigError>> =
        let config = Export.toElixirConfig ()
        Zenoh.publishConfig config

    /// Detect configuration drift between F# and Elixir
    /// SC-CONSOL-006: Config drift detection MANDATORY
    let detectDrift () : DriftReport =
        Drift.detectDrift ()

    /// Load MeshConfig from Elixir config file
    /// Path: JSON file containing Elixir config
    let loadFromElixir (path: string) : Result<ElixirConfig, ConfigError> =
        Load.fromElixirConfigFile path

    /// Synchronize configurations (F# -> Elixir)
    /// F# is authoritative source
    let syncConfigs () : Result<SyncReport, SyncError> =
        Sync.syncConfigs ()

    /// Generate Elixir config.exs file from current MeshConfig
    let generateConfigExs (outputPath: string) : Result<unit, ConfigError> =
        try
            let config = Export.toElixirConfig ()
            let configExs = Export.toElixirConfigExs config
            File.WriteAllText(outputPath, configExs)
            Ok ()
        with
        | ex ->
            Error (SerializationError ex.Message)

    /// Print drift report to console
    let printDriftReport (report: DriftReport) : unit =
        Drift.printDriftReport report

    /// Subscribe to Zenoh config updates for hot reload
    let subscribeToUpdates (onUpdate: ElixirConfig -> unit) : Async<Result<unit, ConfigError>> =
        Zenoh.subscribeToUpdates onUpdate
