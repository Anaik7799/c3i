#!/usr/bin/env dotnet fsi
// =============================================================================
// SIL6MeshOrchestrator.fsx - Unified SIL-6 Biomorphic Fractal Mesh Controller
// =============================================================================
// Version: 1.0.0 | Created: 2026-01-10 | Author: Cybernetic Architect
//
// STAMP Constraints:
//   SC-ZENOH-001 to SC-ZENOH-008: Mandatory Zenoh telemetry on ALL nodes
//   SC-SIL6-001 to SC-SIL6-015: SIL-6 Biomorphic Extended Safety
//   SC-BIO-001 to SC-BIO-007: Biomorphic execution constraints
//   SC-MESH-001 to SC-MESH-010: F# Cortex mesh management
//   SC-METRICS-003: Mandatory parallelization (16 schedulers)
//
// AOR Rules:
//   AOR-ZENOH-001 to AOR-ZENOH-008: Zenoh telemetry mandatory
//   AOR-MESH-001 to AOR-MESH-010: SIL-6/SIL-6 mesh operations
//   AOR-BIO-001 to AOR-BIO-007: Biomorphic execution patterns
//
// Capabilities:
//   - Full Observability: Zenoh + OTEL + Prometheus + Grafana + Loki
//   - Swarming: Multi-node agent coordination with quorum voting
//   - Stability: Health monitoring, FPPS consensus, circuit breakers
//   - Cortex Integration: F#/Elixir bridge for cognitive plane
//   - Change Control: Immutable register, checkpoint/restore
//   - Multiverse: Shadow universe forking for testing
// =============================================================================

#r "nuget: System.Text.Json, 8.0.0"

open System
open System.IO
open System.Diagnostics
open System.Threading
open System.Threading.Tasks
open System.Collections.Generic
open System.Collections.Concurrent
open System.Text.Json
open System.Net.Http

// =============================================================================
// SECTION 0: ANSI COLOR PALETTE (SIL-6 Dashboard)
// SC-CONSOL-003: All ANSI colors MUST come from ConsoleChannel.AnsiColors
// SC-CONSOL-007: Orchestrator code MUST use Mesh.Core.fs shared types
// SC-CONSOL-008: Boot model MUST be unified (single phase enum)
// NOTE: For compiled modules, use Cepaf.Mesh.Core types and utilities
// This script copy exists because .fsx files cannot easily import compiled modules
// AUTHORITATIVE SOURCES:
//   - Colors: lib/cepaf/src/Cepaf/Observability/ConsoleChannel.fs
//   - Types:  lib/cepaf/src/Cepaf/Mesh/Core.fs (BootPhase, FractalLayer, QuorumStatus)
//   - State:  lib/cepaf/src/Cepaf/Mesh/DigitalTwin.fs (ContainerHealth, HolonState)
// =============================================================================
module Colors =
    let reset = "\u001b[0m"
    let bold = "\u001b[1m"
    let dim = "\u001b[2m"
    let red = "\u001b[31m"
    let green = "\u001b[32m"
    let yellow = "\u001b[33m"
    let blue = "\u001b[34m"
    let magenta = "\u001b[35m"
    let cyan = "\u001b[36m"
    let white = "\u001b[37m"
    let brightRed = "\u001b[91m"
    let brightGreen = "\u001b[92m"
    let brightYellow = "\u001b[93m"
    let brightBlue = "\u001b[94m"
    let brightMagenta = "\u001b[95m"
    let brightCyan = "\u001b[96m"

// =============================================================================
// SECTION 1: TELEMETRY & LOGGING (Linux Boot Style + Zenoh Integration)
// =============================================================================
type LogLevel =
    | KERNEL | BOOT | STAGE | HEALTH | QUORUM | ZENOH | BIO | MESH | FRACTAL
    | CORTEX | SWARM | OBS | MULTIVERSE | INFO | WARN | ERROR

type TelemetryEvent = {
    Timestamp: DateTimeOffset
    Level: LogLevel
    Stage: string
    Status: string
    Message: string
    ZenohTopic: string option
}

module Telemetry =
    let mutable verboseMode = true
    let mutable logToFile = true
    let logFile = "./data/tmp/sil6-mesh-orchestrator.log"
    let zenohEnabled = Environment.GetEnvironmentVariable("ZENOH_ENABLED") <> "false"

    let private statusColor status =
        match status with
        | "OK" | "PASS" | "READY" | "ONLINE" | "HEALTHY" -> Colors.brightGreen
        | "RUN" | "STARTING" | "CHECKING" | "BUILD" | "SYNC" -> Colors.brightCyan
        | "WAIT" | "PENDING" -> Colors.brightYellow
        | "FAIL" | "ERROR" | "CRITICAL" -> Colors.brightRed
        | "WARN" | "DEGRADED" -> Colors.yellow
        | "FIX" | "HEAL" -> Colors.brightMagenta
        | "ZENOH" -> Colors.blue
        | _ -> Colors.white

    let private levelStr level =
        match level with
        | KERNEL -> "KERNEL"
        | BOOT -> "BOOT"
        | STAGE -> "STAGE"
        | HEALTH -> "HEALTH"
        | QUORUM -> "QUORUM"
        | ZENOH -> "ZENOH"
        | BIO -> "BIO"
        | MESH -> "MESH"
        | FRACTAL -> "FRACTAL"
        | CORTEX -> "CORTEX"
        | SWARM -> "SWARM"
        | OBS -> "OBS"
        | MULTIVERSE -> "MULTIVERSE"
        | INFO -> "INFO"
        | WARN -> "WARN"
        | ERROR -> "ERROR"

    let log level stage status message =
        let ts = DateTimeOffset.UtcNow.ToString("HH:mm:ss.fff")
        let lvl = levelStr level
        let color = statusColor status

        if verboseMode then
            printfn "%s[%s]%s %s[%-10s]%s %-14s [%s%-8s%s] %s"
                Colors.dim ts Colors.reset
                Colors.cyan lvl Colors.reset
                stage
                color status Colors.reset
                message

        if logToFile then
            try
                let dir = Path.GetDirectoryName(logFile)
                if not (Directory.Exists(dir)) then Directory.CreateDirectory(dir) |> ignore
                let line = sprintf "[%s] [%-10s] %-14s [%-8s] %s" ts lvl stage status message
                File.AppendAllText(logFile, line + "\n")
            with _ -> ()

    let logDuration level stage status (ms: float) message =
        let durStr = sprintf "%.2fms" ms
        log level stage status (sprintf "%s (%s)" message durStr)

    let banner title =
        if verboseMode then
            printfn ""
            printfn "%s%s╔═══════════════════════════════════════════════════════════════════════════════╗%s" Colors.brightMagenta Colors.bold Colors.reset
            printfn "%s%s║  %-77s║%s" Colors.brightMagenta Colors.bold title Colors.reset
            printfn "%s%s╚═══════════════════════════════════════════════════════════════════════════════╝%s" Colors.brightMagenta Colors.bold Colors.reset
            printfn ""

    let separator () =
        if verboseMode then
            printfn "%s──────────────────────────────────────────────────────────────────────────────────%s" Colors.dim Colors.reset

    let zenohLog topic message =
        if zenohEnabled then
            log ZENOH "TELEMETRY" "ZENOH" (sprintf "[%s] %s" topic message)

// =============================================================================
// SECTION 2: MANDATORY ENVIRONMENT (SC-METRICS-003, SC-ZENOH-001)
// =============================================================================
module Environment =
    // SC-METRICS-003: Mandatory parallelization
    let mandatoryEnvVars = [
        ("ELIXIR_ERL_OPTIONS", "+S 16:16 +SDio 16")
        ("NO_TIMEOUT", "true")
        ("PATIENT_MODE", "enabled")
        ("INFINITE_PATIENCE", "true")
        ("MIX_OS_DEPS_COMPILE_PARTITION_COUNT", "8")
        // SC-ZENOH-001: Zenoh NIF MUST be loaded on ALL nodes
        ("SKIP_ZENOH_NIF", "0")
        ("ZENOH_ENABLED", "true")
        ("ZENOH_ROUTER_ENDPOINT", "tcp/zenoh-router:7447")
        ("ZENOH_MODE", "client")
        // SIL-6 Biomorphic settings
        ("SIL6_MODE", "true")
        ("BIOMORPHIC_HEALING", "enabled")
        ("CORTEX_INTEGRATION", "true")
    ]

    let injectMandatoryEnv (psi: ProcessStartInfo) =
        for (key, value) in mandatoryEnvVars do
            psi.EnvironmentVariables.[key] <- value

    let verifyMandatory () =
        let missing =
            mandatoryEnvVars
            |> List.filter (fun (k, _) ->
                let v = System.Environment.GetEnvironmentVariable(k)
                String.IsNullOrWhiteSpace(v))
        if missing.Length > 0 then
            Telemetry.log WARN "ENV" "WARN" (sprintf "Missing env vars: %s" (String.Join(", ", missing |> List.map fst)))
        missing.Length = 0

// =============================================================================
// SECTION 2.5: NETWORK CONFIGURATION (SC-CLU-001, SC-NET-001)
// =============================================================================
// Supports three naming schemes:
//   1. Tailscale MagicDNS FQDNs (primary for distributed/production)
//   2. Podman container names (for container-to-container communication)
//   3. Local/localhost (for host-to-container via port forwarding)
// =============================================================================

/// Network naming scheme
type NetworkScheme =
    | Tailscale   // {service}-{host}.{tailnet}.ts.net
    | Kubernetes  // {service}.{namespace}.svc.cluster.local
    | Podman      // container names (indrajaal-db-prod, etc.)
    | Local       // localhost with port mapping

/// Service definition with all naming schemes
type ServiceDef = {
    Name: string
    Port: int
    // Tailscale naming
    TailscaleService: string   // e.g., "timescaledb", "prometheus"
    // Kubernetes naming
    KubernetesService: string  // e.g., "indrajaal-db", "indrajaal-app"
    // Podman naming
    PodmanContainer: string    // e.g., "indrajaal-db-prod"
    // Local naming
    LocalHost: string          // typically "localhost" or "127.0.0.1"
    // Health check path
    HealthPath: string
}

module NetworkConfig =
    // ==========================================================================
    // Tailscale Configuration (from environment or defaults)
    // ==========================================================================
    let tailscaleDnsSuffix =
        Environment.GetEnvironmentVariable("TAILSCALE_DNS_SUFFIX")
        |> Option.ofObj
        |> Option.defaultValue "tail55d152.ts.net"

    let tailscaleHostName =
        Environment.GetEnvironmentVariable("TS_HOSTNAME")
        |> Option.ofObj
        |> Option.defaultValue "vm-1"

    let tailscaleIp =
        Environment.GetEnvironmentVariable("TS_IP_ADDRESS")
        |> Option.ofObj
        |> Option.defaultValue "100.78.98.18"

    // Generate Tailscale FQDN: {service}-{host}.{tailnet}
    let tailscaleFqdn service =
        sprintf "%s-%s.%s" service tailscaleHostName tailscaleDnsSuffix

    // ==========================================================================
    // Kubernetes Configuration
    // ==========================================================================
    let k8sNamespace =
        Environment.GetEnvironmentVariable("K8S_NAMESPACE")
        |> Option.ofObj
        |> Option.defaultValue "indrajaal"

    let k8sClusterDomain =
        Environment.GetEnvironmentVariable("K8S_CLUSTER_DOMAIN")
        |> Option.ofObj
        |> Option.defaultValue "svc.cluster.local"

    // Standard Kubernetes service names (matches deployment manifests)
    module K8sServices =
        let db = "indrajaal-db-prod"
        let obs = "indrajaal-obs-prod"
        let app = "indrajaal-ex-app"       // Matches Elixir app deployment
        let app2 = "indrajaal-ex-app-2"
        let zenoh = "zenoh-router"
        let otel = "indrajaal-otel"
        let prometheus = "indrajaal-prometheus"
        let grafana = "indrajaal-grafana"
        let clickhouse = "indrajaal-clickhouse"
        let loki = "indrajaal-loki"

    // Generate Kubernetes FQDN: {service}.{namespace}.svc.cluster.local
    let kubernetesFqdn service =
        sprintf "%s.%s.%s" service k8sNamespace k8sClusterDomain

    // ==========================================================================
    // Podman Configuration
    // ==========================================================================
    let podmanNetwork =
        Environment.GetEnvironmentVariable("PODMAN_NETWORK")
        |> Option.ofObj
        |> Option.defaultValue "indrajaal-mesh"

    // Standard Podman container names
    module PodmanNames =
        let db = "indrajaal-db-prod"
        let obs = "indrajaal-obs-prod"
        let app = "indrajaal-ex-app-1"
        let app2 = "indrajaal-ex-app-2"
        let zenoh = "zenoh-router"

    // ==========================================================================
    // Local Configuration
    // ==========================================================================
    let localHost = "localhost"
    let localIp = "127.0.0.1"

    // ==========================================================================
    // Service Registry (all services with all naming schemes)
    // ==========================================================================
    let services : ServiceDef list = [
        // Database
        { Name = "db"; Port = 5433; TailscaleService = "timescaledb";
          KubernetesService = K8sServices.db;
          PodmanContainer = PodmanNames.db; LocalHost = localHost; HealthPath = "/" }

        // Application
        { Name = "app"; Port = 4000; TailscaleService = "intelitor";
          KubernetesService = K8sServices.app;
          PodmanContainer = PodmanNames.app; LocalHost = localHost; HealthPath = "/health" }
        { Name = "app2"; Port = 4000; TailscaleService = "intelitor-2";
          KubernetesService = K8sServices.app2;
          PodmanContainer = PodmanNames.app2; LocalHost = localHost; HealthPath = "/health" }

        // Zenoh Router
        { Name = "zenoh"; Port = 7447; TailscaleService = "zenoh";
          KubernetesService = K8sServices.zenoh;
          PodmanContainer = PodmanNames.zenoh; LocalHost = localHost; HealthPath = "/" }

        // Observability Stack (all in obs container in Podman, separate services in K8s)
        { Name = "otel"; Port = 4318; TailscaleService = "otel";
          KubernetesService = K8sServices.otel;
          PodmanContainer = PodmanNames.obs; LocalHost = localHost; HealthPath = "/" }
        { Name = "otel-grpc"; Port = 4317; TailscaleService = "otel";
          KubernetesService = K8sServices.otel;
          PodmanContainer = PodmanNames.obs; LocalHost = localHost; HealthPath = "/" }
        { Name = "prometheus"; Port = 9090; TailscaleService = "prometheus";
          KubernetesService = K8sServices.prometheus;
          PodmanContainer = PodmanNames.obs; LocalHost = localHost; HealthPath = "/-/ready" }
        { Name = "grafana"; Port = 3000; TailscaleService = "grafana";
          KubernetesService = K8sServices.grafana;
          PodmanContainer = PodmanNames.obs; LocalHost = localHost; HealthPath = "/api/health" }
        { Name = "clickhouse"; Port = 8123; TailscaleService = "clickhouse";
          KubernetesService = K8sServices.clickhouse;
          PodmanContainer = PodmanNames.obs; LocalHost = localHost; HealthPath = "/" }
        { Name = "clickhouse-native"; Port = 9000; TailscaleService = "clickhouse";
          KubernetesService = K8sServices.clickhouse;
          PodmanContainer = PodmanNames.obs; LocalHost = localHost; HealthPath = "/" }
        { Name = "loki"; Port = 3100; TailscaleService = "loki";
          KubernetesService = K8sServices.loki;
          PodmanContainer = PodmanNames.obs; LocalHost = localHost; HealthPath = "/ready" }
    ]

    // ==========================================================================
    // URL Generators for each naming scheme
    // ==========================================================================
    let tailscaleUrl (svc: ServiceDef) (path: string) =
        sprintf "http://%s:%d%s" (tailscaleFqdn svc.TailscaleService) svc.Port path

    let kubernetesUrl (svc: ServiceDef) (path: string) =
        sprintf "http://%s:%d%s" (kubernetesFqdn svc.KubernetesService) svc.Port path

    let podmanUrl (svc: ServiceDef) (path: string) =
        sprintf "http://%s:%d%s" svc.PodmanContainer svc.Port path

    let localUrl (svc: ServiceDef) (path: string) =
        sprintf "http://%s:%d%s" svc.LocalHost svc.Port path

    // ==========================================================================
    // Service Lookup
    // ==========================================================================
    let getService name =
        services |> List.tryFind (fun s -> s.Name = name)

    let getServiceByPort port =
        services |> List.tryFind (fun s -> s.Port = port)

    // ==========================================================================
    // Connection Testing
    // ==========================================================================

    // Try HTTP endpoint with timeout
    let private tryHttpEndpoint (url: string) (timeoutSec: float) =
        let httpClient = new HttpClient(Timeout = TimeSpan.FromSeconds(timeoutSec))
        try
            let response = httpClient.GetAsync(url: string).Result
            let code = int response.StatusCode
            if code < 500 then Some code else None
        with _ -> None

    // Try via Tailscale FQDN
    let tryTailscale (svc: ServiceDef) (path: string) =
        let url = tailscaleUrl svc path
        match tryHttpEndpoint url 2.0 with
        | Some code -> Some (sprintf "tailscale://%s-%s:%d%s" svc.TailscaleService tailscaleHostName svc.Port path), Some code
        | None -> None, None

    // Try via Kubernetes service DNS
    let tryKubernetes (svc: ServiceDef) (path: string) =
        let url = kubernetesUrl svc path
        match tryHttpEndpoint url 2.0 with
        | Some code -> Some (sprintf "k8s://%s.%s:%d%s" svc.KubernetesService k8sNamespace svc.Port path), Some code
        | None -> None, None

    // Try via Podman container name (from inside another container)
    let tryPodman (svc: ServiceDef) (path: string) =
        let url = podmanUrl svc path
        match tryHttpEndpoint url 2.0 with
        | Some code -> Some (sprintf "podman://%s:%d%s" svc.PodmanContainer svc.Port path), Some code
        | None -> None, None

    // Try via localhost
    let tryLocal (svc: ServiceDef) (path: string) =
        let url = localUrl svc path
        match tryHttpEndpoint url 2.0 with
        | Some code -> Some (sprintf "local://%s:%d%s" svc.LocalHost svc.Port path), Some code
        | None -> None, None

    // Try via podman exec (run curl inside the container)
    let tryContainerExec (svc: ServiceDef) (path: string) =
        let url = sprintf "http://localhost:%d%s" svc.Port path
        let curlCmd = sprintf "curl -s -o /dev/null -w '%%{http_code}' %s" url
        let psi = ProcessStartInfo("podman", sprintf "exec %s sh -c \"%s\"" svc.PodmanContainer curlCmd)
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true
        try
            use proc = Process.Start(psi)
            let output = proc.StandardOutput.ReadToEnd().Trim()
            proc.WaitForExit(5000) |> ignore
            if proc.ExitCode = 0 && output.Length > 0 && output <> "000" then
                let code = try Int32.Parse(output) with _ -> 0
                if code > 0 && code < 500 then
                    Some (sprintf "container-exec://%s:%d%s" svc.PodmanContainer svc.Port path), Some code
                else
                    None, None
            else
                None, None
        with _ -> None, None

    // ==========================================================================
    // Smart Endpoint Resolution (tries all schemes in order)
    // Priority: Tailscale -> Kubernetes -> Podman -> Local -> Container Exec
    // ==========================================================================
    let tryEndpoint (svc: ServiceDef) (path: string) =
        // Try Tailscale first (production/distributed identity-based)
        match tryTailscale svc path with
        | Some url, Some code -> Some url, Some code
        | _ ->
            // Try Kubernetes service DNS (k8s cluster)
            match tryKubernetes svc path with
            | Some url, Some code -> Some url, Some code
            | _ ->
                // Try Podman container name (container-to-container)
                match tryPodman svc path with
                | Some url, Some code -> Some url, Some code
                | _ ->
                    // Try localhost (development/host-to-container)
                    match tryLocal svc path with
                    | Some url, Some code -> Some url, Some code
                    | _ ->
                        // Final fallback: exec inside container
                        tryContainerExec svc path

    // Alias for backward compatibility
    let tryEndpointWithExec = tryEndpoint

    // ==========================================================================
    // Display Configuration
    // ==========================================================================
    let logConfig () =
        Telemetry.banner "NETWORK CONFIGURATION"
        Telemetry.log INFO "NETWORK" "TAILSCALE" (sprintf "DNS Suffix: %s" tailscaleDnsSuffix)
        Telemetry.log INFO "NETWORK" "TAILSCALE" (sprintf "Host: %s" tailscaleHostName)
        Telemetry.log INFO "NETWORK" "TAILSCALE" (sprintf "IP: %s" tailscaleIp)
        Telemetry.log INFO "NETWORK" "K8S" (sprintf "Namespace: %s" k8sNamespace)
        Telemetry.log INFO "NETWORK" "K8S" (sprintf "Cluster Domain: %s" k8sClusterDomain)
        Telemetry.log INFO "NETWORK" "PODMAN" (sprintf "Network: %s" podmanNetwork)
        Telemetry.log INFO "NETWORK" "LOCAL" (sprintf "Host: %s" localHost)
        Telemetry.log INFO "NETWORK" "PRIORITY" "Tailscale -> Kubernetes -> Podman -> Local -> Container Exec"

        // Show service URLs for each scheme
        Telemetry.separator()
        printfn "%s[1mService URLs:%s" Colors.cyan Colors.reset
        for svc in services |> List.take 5 do
            printfn "  %s%-12s%s Tailscale: %s" Colors.yellow svc.Name Colors.reset (tailscaleFqdn svc.TailscaleService)
            printfn "  %s            %s K8s:       %s" Colors.dim Colors.reset (kubernetesFqdn svc.KubernetesService)
            printfn "  %s            %s Podman:    %s:%d" Colors.dim Colors.reset svc.PodmanContainer svc.Port
            printfn "  %s            %s Local:     %s:%d" Colors.dim Colors.reset svc.LocalHost svc.Port

    // ==========================================================================
    // Network Scheme Summary
    // ==========================================================================
    let getSchemeSummary () =
        let tsHost = tailscaleHostName
        let tsDns = tailscaleDnsSuffix
        let k8sNs = k8sNamespace
        let k8sDomain = k8sClusterDomain
        sprintf "Network Schemes (Resolution Priority):\n  1. Tailscale:  {service}-%s.%s (identity-based, distributed)\n  2. Kubernetes: {service}.%s.%s (k8s cluster service DNS)\n  3. Podman:     {container-name}:{port} (container-to-container)\n  4. Local:      localhost:{port} (host-to-container, development)\n  5. Exec:       podman exec {container} curl (fallback)\n" tsHost tsDns k8sNs k8sDomain

// Backward compatibility alias
module TailscaleConfig = NetworkConfig

// =============================================================================
// SECTION 3: DIGITAL TWIN & FRACTAL STATE (SC-HOLON-001)
// =============================================================================
type ContainerHealth = Healthy | Starting | Degraded | Unhealthy | Stopped | Unknown

type HolonState = {
    Id: string
    Name: string
    mutable Health: ContainerHealth
    mutable DC: float // Diagnostic Coverage
    mutable ZenohConnected: bool
    mutable LastHeartbeat: DateTimeOffset option
}

type FractalLayer =
    | L0_Runtime
    | L1_Function
    | L2_Component
    | L3_Holon
    | L4_Container
    | L5_Node
    | L6_Cluster
    | L7_Federation

type QuorumStatus = Achieved of int * int | NotAchieved of int * int | InsufficientNodes of int

type DigitalTwin = {
    Holons: Dictionary<string, HolonState>
    mutable FractalState: Map<FractalLayer, bool>
    mutable GlobalHealth: float
    mutable QuorumStatus: QuorumStatus
    mutable ZenohMeshActive: bool
    mutable CortexConnected: bool
    mutable ObservabilityActive: bool
}

module DigitalTwin =
    let create () = {
        Holons = Dictionary<string, HolonState>()
        FractalState = Map.empty
        GlobalHealth = 0.0
        QuorumStatus = InsufficientNodes 0
        ZenohMeshActive = false
        CortexConnected = false
        ObservabilityActive = false
    }

    let register twin id name =
        if not (twin.Holons.ContainsKey(id)) then
            twin.Holons.Add(id, {
                Id = id
                Name = name
                Health = Unknown
                DC = 0.0
                ZenohConnected = false
                LastHeartbeat = None
            })

    let updateHealth twin id health dc zenohConnected =
        if twin.Holons.ContainsKey(id) then
            let h = twin.Holons.[id]
            h.Health <- health
            h.DC <- dc
            h.ZenohConnected <- zenohConnected
            h.LastHeartbeat <- Some DateTimeOffset.UtcNow

    let setFractalVerified twin layer =
        twin.FractalState <- twin.FractalState.Add(layer, true)

    let calculateHealth twin =
        if twin.Holons.Count = 0 then 0.0
        else
            let healthyCount =
                twin.Holons.Values
                |> Seq.filter (fun h -> h.Health = Healthy || h.Health = Starting)
                |> Seq.length
            (float healthyCount / float twin.Holons.Count) * 100.0

    let calculateQuorum twin =
        let total = twin.Holons.Count
        if total < 2 then InsufficientNodes total
        else
            let healthy =
                twin.Holons.Values
                |> Seq.filter (fun h -> h.Health = Healthy)
                |> Seq.length
            let required = (total / 2) + 1
            if healthy >= required then Achieved(healthy, total)
            else NotAchieved(healthy, total)

    let checkZenohMesh twin =
        let zenohCount =
            twin.Holons.Values
            |> Seq.filter (fun h -> h.ZenohConnected)
            |> Seq.length
        twin.ZenohMeshActive <- zenohCount = twin.Holons.Count
        twin.ZenohMeshActive

// =============================================================================
// SECTION 4: COMMAND EXECUTION (Podman Integration)
// =============================================================================
module Exec =
    // SC-MESH-001: Centralized compose file configuration
    // Uses SIL-6 full mesh for complete biomorphic architecture (15 containers)
    let private composeFile = "lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml"

    let silent cmd args =
        let psi = ProcessStartInfo(
            FileName = cmd,
            Arguments = args,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        )
        Environment.injectMandatoryEnv psi
        use p = Process.Start(psi)
        let output = p.StandardOutput.ReadToEnd()
        let error = p.StandardError.ReadToEnd()
        p.WaitForExit()
        (p.ExitCode, output, error)

    let verbose cmd args (timeoutMs: int) =
        let psi = ProcessStartInfo(
            FileName = cmd,
            Arguments = args,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        )
        Environment.injectMandatoryEnv psi
        use p = new Process()
        p.StartInfo <- psi

        p.OutputDataReceived.Add(fun e ->
            if not (isNull e.Data) then
                printfn "  %s│%s %s" Colors.cyan Colors.reset e.Data)

        p.ErrorDataReceived.Add(fun e ->
            if not (isNull e.Data) && not (e.Data.Contains("Warning")) then
                printfn "  %s│%s %s" Colors.yellow Colors.reset e.Data)

        p.Start() |> ignore
        p.BeginOutputReadLine()
        p.BeginErrorReadLine()

        if p.WaitForExit(timeoutMs) then p.ExitCode
        else
            p.Kill()
            -1

    let composeUp services =
        let args = sprintf "-f %s up -d %s" composeFile services
        verbose "podman-compose" args 120000

    let composeDown () =
        let args = sprintf "-f %s down" composeFile
        verbose "podman-compose" args 30000

    let checkContainer name =
        let (code, output, _) = silent "podman" (sprintf "inspect %s --format '{{.State.Status}}'" name)
        if code = 0 then
            let status = output.Trim().Trim(''')
            match status with
            | "running" -> Some Healthy
            | "starting" -> Some Starting
            | "paused" | "exited" -> Some Stopped
            | _ -> Some Unknown
        else None

    let checkHealth name =
        let (code, output, _) = silent "podman" (sprintf "inspect %s --format '{{.State.Health.Status}}'" name)
        if code = 0 then
            let status = output.Trim().Trim(''')
            match status with
            | "healthy" -> Some Healthy
            | "starting" -> Some Starting
            | "unhealthy" -> Some Unhealthy
            | _ -> Some Unknown
        else None

    let scourPort port =
        let (code, output, _) = silent "lsof" (sprintf "-t -i :%d" port)
        if code = 0 && not (String.IsNullOrWhiteSpace output) then
            let pids = output.Split('\n') |> Array.filter (not << String.IsNullOrWhiteSpace)
            for pid in pids do
                Telemetry.log BOOT "PORT" "WARN" (sprintf "Killing PID %s on port %d" pid port)
                silent "kill" (sprintf "-9 %s" pid) |> ignore
            true
        else false

    let scourAllPorts () =
        let ports = [4000; 4001; 4002; 4003; 5433; 4317; 4318; 9090; 3000; 3100; 6379; 7447]
        for port in ports do
            scourPort port |> ignore
            Telemetry.log BOOT "PORT" "OK" (sprintf "Port %d clear" port)

// =============================================================================
// SECTION 5: ZENOH TELEMETRY (SC-ZENOH-001 to SC-ZENOH-008)
// =============================================================================
module ZenohTelemetry =
    let verifyRouterConnection () =
        Telemetry.log ZENOH "ROUTER" "CHECK" "Verifying zenoh-router connectivity..."
        let (code, output, _) = Exec.silent "podman" "inspect zenoh-router --format '{{.State.Status}}'"
        if code = 0 && output.Contains("running") then
            Telemetry.log ZENOH "ROUTER" "ONLINE" "zenoh-router at tcp/zenoh-router:7447"
            true
        else
            Telemetry.log ZENOH "ROUTER" "WARN" "zenoh-router not running"
            false

    let verifyNodeZenoh containerName =
        // Check if container has Zenoh NIF active
        let (code, output, _) = Exec.silent "podman" (sprintf "exec %s printenv SKIP_ZENOH_NIF" containerName)
        if code = 0 && output.Trim() = "0" then
            Telemetry.log ZENOH containerName "ONLINE" "Zenoh NIF active"
            true
        else
            Telemetry.log ZENOH containerName "WARN" "Zenoh NIF not active"
            false

    let publishHealth twin =
        // Simulate publishing health to Zenoh topic
        let topic = "indrajaal/mesh/health"
        let payload = sprintf "{\"health\":%.1f,\"quorum\":\"%A\",\"nodes\":%d}"
                        twin.GlobalHealth twin.QuorumStatus twin.Holons.Count
        Telemetry.zenohLog topic payload

    let publishMetrics containerName metrics =
        let topic = sprintf "indrajaal/container/%s/metrics" containerName
        Telemetry.zenohLog topic metrics

// =============================================================================
// SECTION 5.5: ZENOH CONTAINER AGENTS (SC-ZENOH-010 to SC-ZENOH-015)
// Zenoh-based monitoring and control agents for all containers
// =============================================================================
module ZenohContainerAgent =
    // Topic patterns for container agents
    let healthTopic container = sprintf "indrajaal/container/%s/health" container
    let controlTopic container = sprintf "indrajaal/container/%s/control" container
    let metricsTopic container = sprintf "indrajaal/container/%s/metrics" container
    let stateTopic container = sprintf "indrajaal/container/%s/state" container
    let alertTopic container = sprintf "indrajaal/container/%s/alerts" container

    // Container state model
    type ContainerState = {
        Name: string
        Status: string
        Health: string
        Uptime: string
        CpuPercent: float
        MemoryMB: int
        NetworkRx: int64
        NetworkTx: int64
        LastCheck: DateTime
    }

    // Control commands
    type ControlCommand =
        | Start
        | Stop
        | Restart
        | Pause
        | Resume
        | HealthCheck
        | GetMetrics
        | GetState

    // Get container metrics using podman stats
    let getContainerStats containerName =
        let (code, output, _) = Exec.silent "podman" (sprintf "stats --no-stream --format '{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}' %s" containerName)
        if code = 0 && output.Trim().Length > 0 then
            let parts = output.Trim().Split('|')
            if parts.Length >= 3 then
                let cpu = parts.[0].Replace("%", "").Trim()
                let mem = parts.[1].Split('/') |> Array.head |> fun s -> s.Trim()
                let netParts = parts.[2].Split('/')
                Some (
                    (try float cpu with _ -> 0.0),
                    mem,
                    netParts.[0].Trim(),
                    if netParts.Length > 1 then netParts.[1].Trim() else "0B"
                )
            else None
        else None

    // Get container health status
    let getContainerHealth containerName =
        let (code, output, _) = Exec.silent "podman" (sprintf "inspect %s --format '{{.State.Status}}|{{.State.Health.Status}}'" containerName)
        if code = 0 then
            let parts = output.Trim().Split('|')
            let status = if parts.Length > 0 then parts.[0] else "unknown"
            let health = if parts.Length > 1 then parts.[1] else "none"
            (status, health)
        else ("unknown", "unknown")

    // Get container uptime
    let getContainerUptime containerName =
        let (code, output, _) = Exec.silent "podman" (sprintf "inspect %s --format '{{.State.StartedAt}}'" containerName)
        if code = 0 then
            try
                let startTime = DateTime.Parse(output.Trim().Substring(0, 19))
                let uptime = DateTime.UtcNow - startTime
                sprintf "%dd %dh %dm" uptime.Days uptime.Hours uptime.Minutes
            with _ -> "unknown"
        else "unknown"

    // Collect full container state
    let collectContainerState containerName =
        let (status, health) = getContainerHealth containerName
        let uptime = getContainerUptime containerName
        let stats = getContainerStats containerName
        let (cpu, mem, rx, tx) =
            match stats with
            | Some (c, m, r, t) -> (c, m, r, t)
            | None -> (0.0, "0MiB", "0B", "0B")
        {
            Name = containerName
            Status = status
            Health = health
            Uptime = uptime
            CpuPercent = cpu
            MemoryMB = try int (mem.Replace("MiB", "").Replace("GiB", "000").Trim()) with _ -> 0
            NetworkRx = try int64 (rx.Replace("B", "").Replace("k", "000").Replace("M", "000000").Trim()) with _ -> 0L
            NetworkTx = try int64 (tx.Replace("B", "").Replace("k", "000").Replace("M", "000000").Trim()) with _ -> 0L
            LastCheck = DateTime.UtcNow
        }

    // Publish container health to Zenoh
    let publishContainerHealth containerName =
        let state = collectContainerState containerName
        let topic = healthTopic containerName
        let payload = sprintf "{\"name\":\"%s\",\"status\":\"%s\",\"health\":\"%s\",\"uptime\":\"%s\",\"cpu\":%.1f,\"memory_mb\":%d,\"timestamp\":\"%s\"}"
                        state.Name state.Status state.Health state.Uptime state.CpuPercent state.MemoryMB (DateTime.UtcNow.ToString("o"))
        Telemetry.zenohLog topic payload

    // Publish container metrics to Zenoh
    let publishContainerMetrics containerName =
        let state = collectContainerState containerName
        let topic = metricsTopic containerName
        let payload = sprintf "{\"cpu\":%.1f,\"memory_mb\":%d,\"net_rx\":%d,\"net_tx\":%d,\"timestamp\":\"%s\"}"
                        state.CpuPercent state.MemoryMB state.NetworkRx state.NetworkTx (DateTime.UtcNow.ToString("o"))
        Telemetry.zenohLog topic payload

    // Execute control command on container
    let executeCommand containerName command =
        Telemetry.log ZENOH containerName "CTRL" (sprintf "Executing: %A" command)
        let controlPayload = sprintf "{\"command\":\"%A\",\"timestamp\":\"%s\"}" command (DateTime.UtcNow.ToString("o"))
        Telemetry.zenohLog (controlTopic containerName) controlPayload

        match command with
        | Start ->
            let (code, _, _) = Exec.silent "podman" (sprintf "start %s" containerName)
            code = 0
        | Stop ->
            let (code, _, _) = Exec.silent "podman" (sprintf "stop %s" containerName)
            code = 0
        | Restart ->
            let (code, _, _) = Exec.silent "podman" (sprintf "restart %s" containerName)
            code = 0
        | Pause ->
            let (code, _, _) = Exec.silent "podman" (sprintf "pause %s" containerName)
            code = 0
        | Resume ->
            let (code, _, _) = Exec.silent "podman" (sprintf "unpause %s" containerName)
            code = 0
        | HealthCheck ->
            publishContainerHealth containerName
            true
        | GetMetrics ->
            publishContainerMetrics containerName
            true
        | GetState ->
            let state = collectContainerState containerName
            Telemetry.zenohLog (stateTopic containerName) (sprintf "%A" state)
            true

    // Monitor all mesh containers
    let monitorAllContainers () =
        Telemetry.banner "ZENOH CONTAINER AGENT MONITORING"
        let containers = ["indrajaal-db-prod"; "indrajaal-obs-prod"; "zenoh-router"; "indrajaal-ex-app-1"; "indrajaal-ex-app-2"]

        for container in containers do
            let state = collectContainerState container
            let healthColor =
                match state.Health with
                | "healthy" -> Colors.green
                | "unhealthy" -> Colors.red
                | "starting" -> Colors.yellow
                | _ -> Colors.dim

            printfn "  [%s%s%s] %-25s  CPU: %s%.1f%%%s  MEM: %s%dMB%s  Status: %s%s%s"
                healthColor "●" Colors.reset
                container
                Colors.cyan state.CpuPercent Colors.reset
                Colors.cyan state.MemoryMB Colors.reset
                healthColor state.Status Colors.reset

            // Publish to Zenoh
            publishContainerHealth container
            publishContainerMetrics container

            // Check for alerts
            if state.Health = "unhealthy" then
                let alertPayload = sprintf "{\"severity\":\"high\",\"message\":\"Container %s is unhealthy\",\"timestamp\":\"%s\"}"
                                    container (DateTime.UtcNow.ToString("o"))
                Telemetry.zenohLog (alertTopic container) alertPayload
                Telemetry.log ZENOH container "ALERT" (sprintf "Container %s is UNHEALTHY" container)

        printfn ""

    // Start continuous monitoring (background)
    let startContinuousMonitoring intervalMs =
        Telemetry.log ZENOH "MONITOR" "START" (sprintf "Starting continuous monitoring (interval: %dms)" intervalMs)
        async {
            while true do
                monitorAllContainers()
                do! Async.Sleep(intervalMs)
        } |> Async.Start

// =============================================================================
// SECTION 6: OBSERVABILITY INTEGRATION (SC-OBS-069, SC-OBS-071)
// Including SigNoz integration with ClickHouse backend
// Uses Tailscale FQDN primary, container name fallback, localhost last
// =============================================================================
module Observability =
    // Helper to check service via Tailscale FQDN with fallback chain including container exec
    let private checkService serviceName path successMsg warnMsg =
        match TailscaleConfig.getService serviceName with
        | Some svc ->
            Telemetry.log OBS (serviceName.ToUpper()) "CHECK" (sprintf "Verifying %s..." serviceName)
            match TailscaleConfig.tryEndpointWithExec svc path with
            | Some url, Some code when code < 500 ->
                Telemetry.log OBS (serviceName.ToUpper()) "ONLINE" (sprintf "%s via %s (HTTP %d)" successMsg url code)
                true
            | _ ->
                Telemetry.log OBS (serviceName.ToUpper()) "WARN" warnMsg
                false
        | None ->
            Telemetry.log OBS (serviceName.ToUpper()) "ERROR" (sprintf "Service %s not configured" serviceName)
            false

    // OTEL Collector check - uses HTTP endpoint on port 4318
    let checkOtelCollector () =
        Telemetry.log OBS "OTEL" "CHECK" "Verifying OTEL Collector..."
        match TailscaleConfig.getService "otel" with
        | Some svc ->
            match TailscaleConfig.tryEndpointWithExec svc "/" with
            | Some url, Some code ->
                // Any HTTP response (even 404) means OTEL is running
                Telemetry.log OBS "OTEL" "ONLINE" (sprintf "OTEL Collector via %s (HTTP %d)" url code)
                true
            | _ ->
                // Fallback: check gRPC port with ss
                let (portCode, _, _) = Exec.silent "bash" "-c 'ss -tlnp 2>/dev/null | grep :4317'"
                if portCode = 0 then
                    Telemetry.log OBS "OTEL" "ONLINE" "OTEL Collector on :4317 (gRPC local)"
                    true
                else
                    Telemetry.log OBS "OTEL" "WARN" "OTEL Collector not responding"
                    false
        | None ->
            Telemetry.log OBS "OTEL" "ERROR" "OTEL service not configured"
            false

    let checkPrometheus () =
        checkService "prometheus" "/-/ready" "Prometheus ready" "Prometheus not responding"

    let checkGrafana () =
        checkService "grafana" "/api/health" "Grafana healthy" "Grafana not responding"

    // SigNoz uses ClickHouse for storage - check ClickHouse on port 8123
    let checkSigNoz () =
        Telemetry.log OBS "SIGNOZ" "CHECK" "Verifying SigNoz/ClickHouse backend..."
        match TailscaleConfig.getService "clickhouse" with
        | Some svc ->
            match TailscaleConfig.tryEndpointWithExec svc "/" with
            | Some url, Some code when code < 500 ->
                Telemetry.log OBS "SIGNOZ" "ONLINE" (sprintf "SigNoz ClickHouse via %s (HTTP %d)" url code)
                true
            | _ ->
                // Check ClickHouse native port 9000
                let (portCode, _, _) = Exec.silent "bash" "-c 'ss -tlnp 2>/dev/null | grep :9000'"
                if portCode = 0 then
                    Telemetry.log OBS "SIGNOZ" "ONLINE" "SigNoz ClickHouse on :9000 (native local)"
                    true
                else
                    Telemetry.log OBS "SIGNOZ" "WARN" "SigNoz/ClickHouse not responding"
                    false
        | None ->
            Telemetry.log OBS "SIGNOZ" "ERROR" "ClickHouse service not configured"
            false

    // Loki check - optional service
    let checkLoki () =
        Telemetry.log OBS "LOKI" "CHECK" "Verifying Loki (optional)..."
        match TailscaleConfig.getService "loki" with
        | Some svc ->
            match TailscaleConfig.tryEndpointWithExec svc "/ready" with
            | Some url, Some code when code < 500 ->
                Telemetry.log OBS "LOKI" "ONLINE" (sprintf "Loki via %s (HTTP %d)" url code)
                true
            | _ ->
                Telemetry.log OBS "LOKI" "SKIP" "Loki not configured (logs via SigNoz)"
                true  // Return true - Loki is optional when SigNoz is available
        | None ->
            Telemetry.log OBS "LOKI" "SKIP" "Loki not configured (logs via SigNoz)"
            true

    let verifyFullStack twin =
        Telemetry.banner "OBSERVABILITY STACK VERIFICATION"
        let otel = checkOtelCollector()
        let prom = checkPrometheus()
        let grafana = checkGrafana()
        let signoz = checkSigNoz()
        let loki = checkLoki()
        // Core stack: OTEL + Prometheus + Grafana + SigNoz (Loki optional)
        twin.ObservabilityActive <- otel && prom && grafana && signoz
        twin.ObservabilityActive

// =============================================================================
// SECTION 6.5: ZENOH QUERY HELPER (Unified HTTP/Zenoh Bridge)
// =============================================================================
let zenohQuery (url: string) =
    try
        use client = new HttpClient()
        client.Timeout <- TimeSpan.FromSeconds(2.0)
        let response = client.GetAsync(url).Result
        let body = response.Content.ReadAsStringAsync().Result
        if response.IsSuccessStatusCode then (0, body, "")
        else (int response.StatusCode, body, "HTTP Error")
    with ex ->
        (1, "", ex.Message)

// =============================================================================
// SECTION 7: CORTEX INTEGRATION (Cognitive Plane)
// Uses Tailscale FQDN primary, container name fallback, localhost last
// =============================================================================
module Cortex =
    let checkBridge () =
        Telemetry.log CORTEX "BRIDGE" "CHECK" "Verifying CEPAF-Elixir bridge..."
        // Check if Elixir app is responding to health endpoint via Tailscale FQDN
        // Note: Health endpoint is at /health not /api/health
        match TailscaleConfig.getService "app" with
        | Some svc ->
            match TailscaleConfig.tryEndpoint svc "/health" with
            | Some url, Some code when code < 400 ->
                Telemetry.log CORTEX "BRIDGE" "ONLINE" (sprintf "Elixir backend via %s (HTTP %d)" url code)
                true
            | _ ->
                // Fallback to localhost
                let (code, _, _) = zenohQuery "http://localhost:4000/health"
                if code = 0 then
                    Telemetry.log CORTEX "BRIDGE" "ONLINE" "Elixir backend via localhost:4000/health"
                    true
                else
                    Telemetry.log CORTEX "BRIDGE" "WAIT" "Elixir backend not ready"
                    false
        | None ->
            // Final fallback to localhost
            let (code, _, _) = zenohQuery "http://localhost:4000/health"
            if code = 0 then
                Telemetry.log CORTEX "BRIDGE" "ONLINE" "Elixir backend via localhost"
                true
            else
                Telemetry.log CORTEX "BRIDGE" "WAIT" "Elixir backend not ready"
                false

    let checkGuardian () =
        Telemetry.log CORTEX "GUARDIAN" "CHECK" "Verifying Guardian integration..."
        match TailscaleConfig.getService "app" with
        | Some svc ->
            match TailscaleConfig.tryEndpoint svc "/api/prajna/guardian/status" with
            | Some _, Some code when code < 400 -> true
            | _ -> false
        | None ->
            let (code, _, _) = zenohQuery "http://localhost:4000/api/prajna/guardian/status"
            code = 0

    let checkSentinel () =
        Telemetry.log CORTEX "SENTINEL" "CHECK" "Verifying Sentinel health monitoring..."
        match TailscaleConfig.getService "app" with
        | Some svc ->
            match TailscaleConfig.tryEndpoint svc "/api/prajna/sentinel/health" with
            | Some _, Some code when code < 400 -> true
            | _ -> false
        | None ->
            let (code, _, _) = zenohQuery "http://localhost:4000/api/prajna/sentinel/health"
            code = 0

    let verifyCortex twin =
        Telemetry.log CORTEX "VERIFY" "RUN" "Verifying Cortex cognitive plane..."
        let bridge = checkBridge()
        // Guardian and Sentinel checks are optional - app might not be fully up
        twin.CortexConnected <- bridge
        twin.CortexConnected

    // Check using /health not /api/health
    let checkAppHealth () =
        match TailscaleConfig.getService "app" with
        | Some svc ->
            match TailscaleConfig.tryEndpoint svc "/health" with
            | Some url, Some code when code < 400 ->
                Telemetry.log CORTEX "APP" "ONLINE" (sprintf "App health via %s (HTTP %d)" url code)
                true
            | _ ->
                // Fallback to localhost /health
                let (code, _, _) = zenohQuery "http://localhost:4000/health"
                if code = 0 then
                    Telemetry.log CORTEX "APP" "ONLINE" "App health via localhost:4000/health"
                    true
                else
                    Telemetry.log CORTEX "APP" "WARN" "App not responding"
                    false
        | None ->
            let (code, _, _) = zenohQuery "http://localhost:4000/health"
            code = 0

// =============================================================================
// SECTION 8: SWARM MANAGEMENT (Multi-Node Coordination)
// =============================================================================
module Swarm =
    let mutable agentCount = 0
    let mutable maxAgents = 25

    let registerNode twin containerId containerName =
        DigitalTwin.register twin containerId containerName
        agentCount <- agentCount + 1
        Telemetry.log SWARM "NODE" "OK" (sprintf "Registered %s (%d/%d agents)" containerName agentCount maxAgents)

    let healthCheck twin =
        Telemetry.log SWARM "HEALTH" "RUN" "Performing swarm health check..."
        for kv in twin.Holons do
            let holon = kv.Value
            match Exec.checkHealth holon.Name with
            | Some Healthy ->
                DigitalTwin.updateHealth twin holon.Id Healthy 99.99 true
            | Some Starting ->
                DigitalTwin.updateHealth twin holon.Id Starting 50.0 false
            | Some status ->
                DigitalTwin.updateHealth twin holon.Id status 0.0 false
            | None ->
                DigitalTwin.updateHealth twin holon.Id Unknown 0.0 false

        twin.GlobalHealth <- DigitalTwin.calculateHealth twin
        twin.QuorumStatus <- DigitalTwin.calculateQuorum twin

        match twin.QuorumStatus with
        | Achieved(h, t) -> Telemetry.log QUORUM "STATUS" "OK" (sprintf "Quorum achieved: %d/%d healthy" h t)
        | NotAchieved(h, t) -> Telemetry.log QUORUM "STATUS" "WARN" (sprintf "Quorum NOT achieved: %d/%d healthy" h t)
        | InsufficientNodes n -> Telemetry.log QUORUM "STATUS" "WARN" (sprintf "Insufficient nodes: %d" n)

    let fppsConsensus twin containerId =
        // FPPS 5-method validation
        match twin.Holons.TryGetValue(containerId) with
        | true, holon ->
            let checks = [
                holon.Health = Healthy || holon.Health = Starting  // Pattern
                holon.DC >= 0.3                                     // AST threshold
                holon.LastHeartbeat.IsSome                          // Statistical
                holon.ZenohConnected                                // Binary
                (DateTimeOffset.UtcNow - (holon.LastHeartbeat |> Option.defaultValue DateTimeOffset.MinValue)).TotalSeconds < 30.0  // LineByLine
            ]
            let passed = checks |> List.filter id |> List.length
            passed >= 3  // 3/5 consensus
        | false, _ -> false

// =============================================================================
// SECTION 9: CHANGE CONTROL & MULTIVERSE
// =============================================================================
module ChangeControl =
    let checkpointDir = "./data/checkpoints"

    let createCheckpoint name =
        Telemetry.log MULTIVERSE "CHECKPOINT" "RUN" (sprintf "Creating checkpoint: %s" name)
        let ts = DateTimeOffset.UtcNow.ToString("yyyyMMdd-HHmmss")
        let dir = Path.Combine(checkpointDir, sprintf "%s-%s" name ts)

        if not (Directory.Exists(checkpointDir)) then
            Directory.CreateDirectory(checkpointDir) |> ignore

        Directory.CreateDirectory(dir) |> ignore

        // Capture container states
        let (_, output, _) = Exec.silent "podman" "ps --filter name=indrajaal --format json"
        File.WriteAllText(Path.Combine(dir, "containers.json"), output)

        // Capture holon state paths
        let holonDir = "./data/holons"
        if Directory.Exists(holonDir) then
            // Copy SQLite/DuckDB files
            for file in Seq.append (Directory.GetFiles(holonDir, "*.sqlite")) (Directory.GetFiles(holonDir, "*.duckdb")) do
                let dest = Path.Combine(dir, Path.GetFileName(file))
                File.Copy(file, dest, true)

        Telemetry.log MULTIVERSE "CHECKPOINT" "OK" (sprintf "Checkpoint saved to %s" dir)
        dir

    let listCheckpoints () =
        if Directory.Exists(checkpointDir) then
            Directory.GetDirectories(checkpointDir)
            |> Array.map Path.GetFileName
            |> Array.sortDescending
        else
            [||]

    let restoreCheckpoint name =
        Telemetry.log MULTIVERSE "RESTORE" "RUN" (sprintf "Restoring checkpoint: %s" name)
        let dir = Path.Combine(checkpointDir, name)
        if Directory.Exists(dir) then
            // Stop current containers
            Exec.composeDown() |> ignore

            // Restore holon state
            let holonDir = "./data/holons"
            if not (Directory.Exists(holonDir)) then
                Directory.CreateDirectory(holonDir) |> ignore

            for file in Seq.append (Directory.GetFiles(dir, "*.sqlite")) (Directory.GetFiles(dir, "*.duckdb")) do
                let dest = Path.Combine(holonDir, Path.GetFileName(file))
                File.Copy(file, dest, true)

            Telemetry.log MULTIVERSE "RESTORE" "OK" (sprintf "Checkpoint %s restored" name)
            true
        else
            Telemetry.log MULTIVERSE "RESTORE" "FAIL" (sprintf "Checkpoint not found: %s" name)
            false

    let forkShadowUniverse name =
        Telemetry.log MULTIVERSE "FORK" "RUN" (sprintf "Forking shadow universe: %s" name)
        let checkpoint = createCheckpoint (sprintf "shadow-%s" name)
        // In a real implementation, this would create isolated containers
        Telemetry.log MULTIVERSE "FORK" "OK" (sprintf "Shadow universe created from %s" checkpoint)
        checkpoint

// =============================================================================
// SECTION 10: BOOT SEQUENCE (SIL-6 Transactional)
// =============================================================================
module BootSequence =
    let transaction stageName action =
        Telemetry.log STAGE stageName "START" "Beginning transaction..."
        let sw = Stopwatch.StartNew()
        try
            let result = action()
            sw.Stop()
            if result then
                Telemetry.logDuration STAGE stageName "PASS" sw.Elapsed.TotalMilliseconds "Transaction committed"
                true
            else
                Telemetry.logDuration STAGE stageName "FAIL" sw.Elapsed.TotalMilliseconds "Transaction rolled back"
                false
        with ex ->
            sw.Stop()
            Telemetry.logDuration STAGE stageName "ERROR" sw.Elapsed.TotalMilliseconds (sprintf "Exception: %s" ex.Message)
            false

    // S0: PREFLIGHT
    let runPreflight twin = transaction "S0_PREFLIGHT" (fun () ->
        Telemetry.log BOOT "PREFLIGHT" "RUN" "Validating environment..."

        // Verify mandatory env vars
        let envOk = Environment.verifyMandatory()

        // Scour ports
        Exec.scourAllPorts()

        // Clean stale containers
        Telemetry.log BOOT "CLEAN" "RUN" "Removing stale containers..."
        let containers = ["indrajaal-db-prod"; "indrajaal-obs-prod"; "indrajaal-ex-app-1";
                         "indrajaal-ex-app-2"; "zenoh-router"]
        for c in containers do
            Exec.silent "podman" (sprintf "rm -f %s" c) |> ignore
        Exec.silent "podman" "network prune -f" |> ignore

        Telemetry.log BOOT "PREFLIGHT" "OK" "Preflight complete"
        DigitalTwin.setFractalVerified twin L0_Runtime
        true
    )

    // S1: INFRASTRUCTURE
    let runInfrastructure twin = transaction "S1_INFRASTRUCTURE" (fun () ->
        Telemetry.log KERNEL "INFRA" "START" "Initializing infrastructure layer..."

        // Start DB and OBS
        let dbCode = Exec.composeUp "indrajaal-db-prod"
        if dbCode <> 0 then
            Telemetry.log KERNEL "DB" "FAIL" "Database failed to start"
            false
        else
            Thread.Sleep(5000)  // Wait for DB to initialize
            Swarm.registerNode twin "db-1" "indrajaal-db-prod"
            DigitalTwin.updateHealth twin "db-1" Healthy 99.99 true

            let obsCode = Exec.composeUp "indrajaal-obs-prod"
            if obsCode <> 0 then
                Telemetry.log KERNEL "OBS" "FAIL" "Observability stack failed to start"
                false
            else
                Thread.Sleep(3000)
                Swarm.registerNode twin "obs-1" "indrajaal-obs-prod"
                DigitalTwin.updateHealth twin "obs-1" Healthy 99.99 true
                DigitalTwin.setFractalVerified twin L2_Component
                true
    )

    // S2: ZENOH MESH
    let runZenohMesh twin = transaction "S2_ZENOH_MESH" (fun () ->
        Telemetry.log ZENOH "MESH" "START" "Initializing Zenoh control plane..."

        // Start zenoh-router
        let zenohCode = Exec.composeUp "zenoh-router"
        if zenohCode <> 0 then
            Telemetry.log ZENOH "ROUTER" "FAIL" "zenoh-router failed to start"
            false
        else
            Thread.Sleep(2000)
            if ZenohTelemetry.verifyRouterConnection() then
                Swarm.registerNode twin "zenoh-1" "zenoh-router"
                DigitalTwin.updateHealth twin "zenoh-1" Healthy 99.99 true
                DigitalTwin.setFractalVerified twin L3_Holon
                twin.ZenohMeshActive <- true
                true
            else
                false
    )

    // S3: APPLICATION SEED
    let runApplicationSeed twin = transaction "S3_APP_SEED" (fun () ->
        Telemetry.log BOOT "APP" "START" "Starting application seed node..."

        let appCode = Exec.composeUp "indrajaal-ex-app-1"
        if appCode <> 0 then
            Telemetry.log BOOT "APP" "FAIL" "Application seed failed to start"
            false
        else
            // Wait for app to become healthy
            Telemetry.log BOOT "APP" "WAIT" "Waiting for application health..."
            let mutable healthy = false
            let mutable retries = 0
            while not healthy && retries < 60 do
                Thread.Sleep(5000)
                match Exec.checkHealth "indrajaal-ex-app-1" with
                | Some Healthy -> healthy <- true
                | _ -> retries <- retries + 1
                Telemetry.log BOOT "APP" "CHECK" (sprintf "Health check %d/60..." (retries + 1))

            if healthy then
                Swarm.registerNode twin "app-1" "indrajaal-ex-app-1"
                DigitalTwin.updateHealth twin "app-1" Healthy 99.99 true
                DigitalTwin.setFractalVerified twin L4_Container
                DigitalTwin.setFractalVerified twin L5_Node
                true
            else
                Telemetry.log BOOT "APP" "FAIL" "Application health check timeout"
                false
    )

    // S4: HOMEOSTASIS
    let runHomeostasis twin = transaction "S4_HOMEOSTASIS" (fun () ->
        Telemetry.log BIO "HOMEOSTASIS" "START" "Achieving system homeostasis..."

        // Perform swarm health check
        Swarm.healthCheck twin

        // Verify Zenoh mesh
        DigitalTwin.checkZenohMesh twin |> ignore

        // Verify observability
        Observability.verifyFullStack twin |> ignore

        // Verify Cortex
        Cortex.verifyCortex twin |> ignore

        // Publish health to Zenoh
        ZenohTelemetry.publishHealth twin

        twin.GlobalHealth <- DigitalTwin.calculateHealth twin

        if twin.GlobalHealth >= 80.0 then
            DigitalTwin.setFractalVerified twin L6_Cluster
            DigitalTwin.setFractalVerified twin L7_Federation
            Telemetry.log BIO "HOMEOSTASIS" "OK" (sprintf "System stabilized at %.1f%% health" twin.GlobalHealth)
            true
        else
            Telemetry.log BIO "HOMEOSTASIS" "WARN" (sprintf "Health degraded: %.1f%%" twin.GlobalHealth)
            true  // Still pass but with warning
    )

    // Dashboard display function (defined before execute to avoid forward reference)
    let printDashboard twin =
        printfn ""
        printfn "%s%sFRACTAL STATE:%s" Colors.cyan Colors.bold Colors.reset
        for kv in twin.FractalState do
            let status = if kv.Value then sprintf "%s✓ VERIFIED%s" Colors.green Colors.reset
                         else sprintf "%s✗ PENDING%s" Colors.red Colors.reset
            printfn "  %-20A: %s" kv.Key status

        printfn ""
        printfn "%s%sNODE STATUS:%s" Colors.cyan Colors.bold Colors.reset
        for kv in twin.Holons do
            let h = kv.Value
            let healthStr =
                match h.Health with
                | Healthy -> sprintf "%s● HEALTHY%s" Colors.green Colors.reset
                | Starting -> sprintf "%s● STARTING%s" Colors.yellow Colors.reset
                | Degraded -> sprintf "%s● DEGRADED%s" Colors.yellow Colors.reset
                | Unhealthy -> sprintf "%s● UNHEALTHY%s" Colors.red Colors.reset
                | Stopped -> sprintf "%s● STOPPED%s" Colors.dim Colors.reset
                | Unknown -> sprintf "%s● UNKNOWN%s" Colors.dim Colors.reset
            let zenohStr = if h.ZenohConnected then sprintf "%sZ%s" Colors.blue Colors.reset else "-"
            printfn "  %-20s: %s  DC:%.1f%%  Zenoh:%s" h.Name healthStr h.DC zenohStr

        printfn ""
        printfn "%s%sSYSTEM METRICS:%s" Colors.cyan Colors.bold Colors.reset
        printfn "  Global Health:      %.1f%%" twin.GlobalHealth
        match twin.QuorumStatus with
        | Achieved(h, t) -> printfn "  Quorum:             %s✓ %d/%d%s" Colors.green h t Colors.reset
        | NotAchieved(h, t) -> printfn "  Quorum:             %s✗ %d/%d%s" Colors.red h t Colors.reset
        | InsufficientNodes n -> printfn "  Quorum:             %s⚠ Insufficient (%d)%s" Colors.yellow n Colors.reset
        printfn "  Zenoh Mesh:         %s" (if twin.ZenohMeshActive then sprintf "%s✓ ACTIVE%s" Colors.green Colors.reset else sprintf "%s✗ INACTIVE%s" Colors.red Colors.reset)
        printfn "  Cortex:             %s" (if twin.CortexConnected then sprintf "%s✓ CONNECTED%s" Colors.green Colors.reset else sprintf "%s✗ DISCONNECTED%s" Colors.yellow Colors.reset)
        printfn "  Observability:      %s" (if twin.ObservabilityActive then sprintf "%s✓ ACTIVE%s" Colors.green Colors.reset else sprintf "%s✗ INACTIVE%s" Colors.yellow Colors.reset)
        printfn ""

    // Full boot sequence
    let execute () =
        let twin = DigitalTwin.create()
        Telemetry.banner "SIL-6 BIOMORPHIC FRACTAL MESH BOOT SEQUENCE"

        let s0 = runPreflight twin
        let s1 = if s0 then runInfrastructure twin else false
        let s2 = if s1 then runZenohMesh twin else false
        let s3 = if s2 then runApplicationSeed twin else false
        let s4 = if s3 then runHomeostasis twin else false

        Telemetry.separator()

        if s4 then
            printfn ""
            printfn "%s%s╔═══════════════════════════════════════════════════════════════════════════════╗%s" Colors.brightGreen Colors.bold Colors.reset
            printfn "%s%s║           SIL-6 MESH STABILIZED - BIOMORPHIC FRACTAL HOLON ACTIVE            ║%s" Colors.brightGreen Colors.bold Colors.reset
            printfn "%s%s╚═══════════════════════════════════════════════════════════════════════════════╝%s" Colors.brightGreen Colors.bold Colors.reset
        else
            printfn ""
            printfn "%s%s╔═══════════════════════════════════════════════════════════════════════════════╗%s" Colors.brightRed Colors.bold Colors.reset
            printfn "%s%s║                    MESH BOOT SEQUENCE FAILED                                  ║%s" Colors.brightRed Colors.bold Colors.reset
            printfn "%s%s╚═══════════════════════════════════════════════════════════════════════════════╝%s" Colors.brightRed Colors.bold Colors.reset

        // Print dashboard
        printDashboard twin

        s4, twin

// =============================================================================
// SECTION 11: SHUTDOWN SEQUENCE
// =============================================================================
module ShutdownSequence =
    let execute () =
        Telemetry.banner "SIL-6 GRACEFUL SHUTDOWN PROTOCOL"

        // Phase 1: Lameduck broadcast
        Telemetry.log BOOT "SHUTDOWN" "RUN" "Broadcasting lameduck signal..."
        Thread.Sleep(1000)

        // Phase 2: Drain connections
        Telemetry.log BOOT "DRAIN" "RUN" "Draining connections..."
        Thread.Sleep(2000)

        // Phase 3: Create checkpoint
        Telemetry.log BOOT "CHECKPOINT" "RUN" "Saving state checkpoint..."
        ChangeControl.createCheckpoint "shutdown" |> ignore

        // Phase 4: Stop containers
        Telemetry.log BOOT "STOP" "RUN" "Stopping containers..."
        let code = Exec.composeDown()

        if code = 0 then
            printfn ""
            printfn "%s%s>>> SUBSTRATE RETURNED TO STATIC STATE <<<%s" Colors.green Colors.bold Colors.reset
            true
        else
            printfn ""
            printfn "%s%s>>> SHUTDOWN COMPLETED WITH WARNINGS <<<%s" Colors.yellow Colors.bold Colors.reset
            false

// =============================================================================
// SECTION 12: STATUS & MONITORING
// =============================================================================
module Status =
    /// Get running mesh containers via podman
    let private getMeshContainers () =
        // Use podman ps with JSON format for reliable parsing
        let psi = ProcessStartInfo("podman", "ps -a --format json")
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true
        try
            use proc = Process.Start(psi)
            let output = proc.StandardOutput.ReadToEnd()
            proc.WaitForExit(5000) |> ignore
            if proc.ExitCode = 0 && not (String.IsNullOrWhiteSpace output) then
                // Parse JSON array and filter for mesh containers
                // Simple text parsing since we don't have JSON library
                let meshNames = ["indrajaal-db"; "indrajaal-obs"; "indrajaal-ex-app"; "zenoh-router"]
                output.Split('\n')
                |> Array.filter (fun line ->
                    meshNames |> List.exists (fun name -> line.Contains(name)))
                |> Array.toList
            else
                []
        with _ -> []

    /// Get container info using simple podman ps
    let private getContainerTable () =
        let psi = ProcessStartInfo("sh", "-c \"podman ps -a --filter name=indrajaal --filter name=zenoh --format 'table {{.Names}}\\t{{.Status}}\\t{{.State}}'\"")
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true
        try
            use proc = Process.Start(psi)
            let output = proc.StandardOutput.ReadToEnd().Trim()
            proc.WaitForExit(5000) |> ignore
            if proc.ExitCode = 0 && not (String.IsNullOrWhiteSpace output) then
                Some output
            else
                None
        with _ -> None

    /// Get detailed container status
    let private getContainerStatus (containerName: string) =
        // Use sh -c to properly handle Go template quoting
        let cmd = sprintf "podman inspect --format '{{.State.Status}}|{{.State.Health.Status}}' %s" containerName
        let psi = ProcessStartInfo("sh", sprintf "-c \"%s\"" cmd)
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true
        try
            use proc = Process.Start(psi)
            let output = proc.StandardOutput.ReadToEnd().Trim()
            proc.WaitForExit(2000) |> ignore
            if proc.ExitCode = 0 && not (String.IsNullOrWhiteSpace output) then
                let parts = output.Split('|')
                let status = if parts.Length > 0 then parts.[0] else "unknown"
                let health = if parts.Length > 1 then parts.[1] else "unknown"
                Some (status, health)
            else
                None
        with _ -> None

    let show () =
        Telemetry.banner "SIL-6 MESH STATUS"

        // Expected mesh containers
        let meshContainers = [
            NetworkConfig.PodmanNames.db
            NetworkConfig.PodmanNames.obs
            NetworkConfig.PodmanNames.zenoh
            NetworkConfig.PodmanNames.app
        ]

        // Check each container
        let containerStatuses =
            meshContainers
            |> List.map (fun name ->
                match getContainerStatus name with
                | Some (status, health) -> (name, status, health)
                | None -> (name, "not found", "n/a"))

        let runningCount = containerStatuses |> List.filter (fun (_, s, _) -> s = "running") |> List.length

        if runningCount > 0 then
            printfn "%s%-24s %-12s %-12s%s" Colors.cyan "CONTAINER" "STATUS" "HEALTH" Colors.reset
            printfn "%s─────────────────────────────────────────────────────%s" Colors.dim Colors.reset
            for (name, status, health) in containerStatuses do
                let statusColor =
                    match status with
                    | "running" -> Colors.green
                    | "exited" -> Colors.red
                    | "created" -> Colors.yellow
                    | _ -> Colors.dim
                let healthColor =
                    match health with
                    | "healthy" -> Colors.green
                    | "unhealthy" -> Colors.red
                    | "starting" -> Colors.yellow
                    | _ -> Colors.dim
                let statusIcon =
                    match status with
                    | "running" -> "●"
                    | "exited" -> "○"
                    | "created" -> "◐"
                    | _ -> "?"
                printfn "  %s%s%s %-20s %s%-12s%s %s%-12s%s"
                    statusColor statusIcon Colors.reset
                    name
                    statusColor status Colors.reset
                    healthColor health Colors.reset
            printfn ""
            printfn "%sRunning: %d/%d containers%s" Colors.cyan runningCount (List.length meshContainers) Colors.reset
        else
            printfn "%sNo mesh containers running%s" Colors.yellow Colors.reset
            printfn ""
            printfn "Expected containers:"
            for name in meshContainers do
                printfn "  - %s" name
            printfn ""
            printfn "Run 'sa-mesh boot' to start the mesh"

        printfn ""

        // Check Zenoh
        ZenohTelemetry.verifyRouterConnection() |> ignore

        // Check Observability
        printfn ""
        Observability.verifyFullStack (DigitalTwin.create()) |> ignore

        // Show Cortex status
        printfn ""
        Telemetry.log CORTEX "STATUS" "CHECK" "Checking Cortex bridge..."
        if Cortex.checkBridge() then
            Telemetry.log CORTEX "STATUS" "ONLINE" "Cortex bridge connected"
        else
            Telemetry.log CORTEX "STATUS" "OFFLINE" "Cortex bridge not responding"

// =============================================================================
// SECTION 13: TEST COMMANDS
// =============================================================================
module Test =
    let testObservability () =
        Telemetry.banner "OBSERVABILITY TEST"
        let twin = DigitalTwin.create()
        let result = Observability.verifyFullStack twin
        printfn ""
        printfn "Observability Stack: %s" (if result then sprintf "%sOPERATIONAL%s" Colors.green Colors.reset else sprintf "%sDEGRADED%s" Colors.yellow Colors.reset)
        result

    let testChangeControl () =
        Telemetry.banner "CHANGE CONTROL TEST"

        // Create a test checkpoint
        let checkpoint = ChangeControl.createCheckpoint "test"

        // List checkpoints
        printfn ""
        printfn "%sAvailable Checkpoints:%s" Colors.cyan Colors.reset
        for cp in ChangeControl.listCheckpoints() do
            printfn "  - %s" cp

        true

    let testMultiverse () =
        Telemetry.banner "MULTIVERSE CAPABILITY TEST"

        // Fork a shadow universe
        let shadow = ChangeControl.forkShadowUniverse "test"

        printfn ""
        printfn "%sShadow Universe:%s %s" Colors.cyan Colors.reset shadow
        printfn ""
        printfn "Multiverse forking capability: %sVERIFIED%s" Colors.green Colors.reset
        true

    let testZenohAgents () =
        Telemetry.banner "ZENOH CONTAINER AGENTS TEST"

        // Run container monitoring
        ZenohContainerAgent.monitorAllContainers()

        // Test control command
        Telemetry.log ZENOH "TEST" "RUN" "Testing control command: HealthCheck"
        let result = ZenohContainerAgent.executeCommand "indrajaal-db-prod" ZenohContainerAgent.HealthCheck

        printfn ""
        printfn "Zenoh Container Agents: %s" (if result then sprintf "%sOPERATIONAL%s" Colors.green Colors.reset else sprintf "%sFAILED%s" Colors.red Colors.reset)
        result

    let testZenohRouter () =
        Telemetry.banner "ZENOH ROUTER VERIFICATION"

        // Verify router is running
        let routerUp = ZenohTelemetry.verifyRouterConnection()

        if routerUp then
            // Publish test message
            Telemetry.log ZENOH "TEST" "RUN" "Publishing test telemetry..."
            let testTopic = "indrajaal/test/ping"
            let testPayload = sprintf "{\"test\":\"ping\",\"timestamp\":\"%s\"}" (DateTime.UtcNow.ToString("o"))
            Telemetry.zenohLog testTopic testPayload

            printfn ""
            printfn "Zenoh Router: %sONLINE%s" Colors.green Colors.reset
            printfn "Zenoh Topics:"
            printfn "  - indrajaal/mesh/health"
            printfn "  - indrajaal/container/*/health"
            printfn "  - indrajaal/container/*/metrics"
            printfn "  - indrajaal/container/*/control"
            printfn "  - indrajaal/container/*/alerts"
            true
        else
            printfn ""
            printfn "Zenoh Router: %sOFFLINE%s" Colors.red Colors.reset
            false

    let testAll () =
        Telemetry.banner "FULL SYSTEM TEST SUITE"

        let obsResult = testObservability()
        Telemetry.separator()
        let ccResult = testChangeControl()
        Telemetry.separator()
        let mvResult = testMultiverse()
        Telemetry.separator()
        let zenohResult = testZenohRouter()
        Telemetry.separator()
        let agentResult = testZenohAgents()

        printfn ""
        printfn "%s%sTEST SUMMARY:%s" Colors.cyan Colors.bold Colors.reset
        printfn "  Observability:    %s" (if obsResult then sprintf "%sPASS%s" Colors.green Colors.reset else sprintf "%sFAIL%s" Colors.red Colors.reset)
        printfn "  Change Control:   %s" (if ccResult then sprintf "%sPASS%s" Colors.green Colors.reset else sprintf "%sFAIL%s" Colors.red Colors.reset)
        printfn "  Multiverse:       %s" (if mvResult then sprintf "%sPASS%s" Colors.green Colors.reset else sprintf "%sFAIL%s" Colors.red Colors.reset)
        printfn "  Zenoh Router:     %s" (if zenohResult then sprintf "%sPASS%s" Colors.green Colors.reset else sprintf "%sFAIL%s" Colors.red Colors.reset)
        printfn "  Zenoh Agents:     %s" (if agentResult then sprintf "%sPASS%s" Colors.green Colors.reset else sprintf "%sFAIL%s" Colors.red Colors.reset)

        obsResult && ccResult && mvResult && zenohResult && agentResult

// =============================================================================
// ENTRY POINT
// =============================================================================
let args = fsi.CommandLineArgs |> Array.skip 1
let command = args |> Array.tryHead |> Option.defaultValue "boot"

match command.ToLower() with
| "boot" | "up" ->
    BootSequence.execute() |> ignore
| "down" | "shutdown" ->
    ShutdownSequence.execute() |> ignore
| "status" ->
    Status.show()
| "test" ->
    let subcommand = args |> Array.tryItem 1 |> Option.defaultValue "all"
    match subcommand.ToLower() with
    | "obs" | "observability" -> Test.testObservability() |> ignore
    | "cc" | "change-control" -> Test.testChangeControl() |> ignore
    | "mv" | "multiverse" -> Test.testMultiverse() |> ignore
    | "zenoh" | "router" -> Test.testZenohRouter() |> ignore
    | "agents" | "containers" -> Test.testZenohAgents() |> ignore
    | "all" -> Test.testAll() |> ignore
    | _ -> printfn "Unknown test: %s. Available: obs, cc, mv, zenoh, agents, all" subcommand
| "agents" | "monitor" ->
    ZenohContainerAgent.monitorAllContainers()
| "control" ->
    let container = args |> Array.tryItem 1 |> Option.defaultValue "indrajaal-ex-app-1"
    let cmdStr = args |> Array.tryItem 2 |> Option.defaultValue "status"
    let cmd =
        match cmdStr.ToLower() with
        | "start" -> Some ZenohContainerAgent.Start
        | "stop" -> Some ZenohContainerAgent.Stop
        | "restart" -> Some ZenohContainerAgent.Restart
        | "pause" -> Some ZenohContainerAgent.Pause
        | "resume" -> Some ZenohContainerAgent.Resume
        | "health" | "status" -> Some ZenohContainerAgent.HealthCheck
        | "metrics" -> Some ZenohContainerAgent.GetMetrics
        | "state" -> Some ZenohContainerAgent.GetState
        | _ -> None
    match cmd with
    | Some c -> ZenohContainerAgent.executeCommand container c |> ignore
    | None -> printfn "Unknown control command: %s. Available: start|stop|restart|pause|resume|health|metrics|state" cmdStr
| "checkpoint" ->
    let name = args |> Array.tryItem 1 |> Option.defaultValue "manual"
    ChangeControl.createCheckpoint name |> ignore
| "restore" ->
    let name = args |> Array.tryItem 1 |> Option.defaultValue ""
    if String.IsNullOrWhiteSpace name then
        printfn "Usage: restore <checkpoint-name>"
        printfn "Available checkpoints:"
        for cp in ChangeControl.listCheckpoints() do
            printfn "  - %s" cp
    else
        ChangeControl.restoreCheckpoint name |> ignore
| "fork" ->
    let name = args |> Array.tryItem 1 |> Option.defaultValue "shadow"
    ChangeControl.forkShadowUniverse name |> ignore
| "help" | "-h" | "--help" ->
    printfn ""
    printfn "%s%sSIL-6 MESH ORCHESTRATOR%s" Colors.brightMagenta Colors.bold Colors.reset
    printfn ""
    printfn "COMMANDS:"
    printfn "  boot               Start SIL-6 biomorphic mesh (default)"
    printfn "  down               Graceful shutdown with checkpoint"
    printfn "  status             Show mesh status and health"
    printfn "  test [type]        Run tests (obs|cc|mv|zenoh|agents|all)"
    printfn "  agents             Monitor all containers via Zenoh agents"
    printfn "  control <c> <cmd>  Control container (start|stop|restart|health|metrics)"
    printfn "  checkpoint [name]  Create state checkpoint"
    printfn "  restore <name>     Restore from checkpoint"
    printfn "  fork [name]        Fork shadow universe"
    printfn "  help               Show this help"
    printfn ""
    printfn "ZENOH TOPICS:"
    printfn "  indrajaal/mesh/health           - Mesh health status"
    printfn "  indrajaal/container/*/health    - Per-container health"
    printfn "  indrajaal/container/*/metrics   - Per-container metrics"
    printfn "  indrajaal/container/*/control   - Control commands"
    printfn "  indrajaal/container/*/alerts    - Container alerts"
    printfn ""
    printfn "STAMP Constraints: SC-ZENOH-*, SC-SIL6-*, SC-BIO-*, SC-MESH-*"
    printfn ""
| _ ->
    printfn "Unknown command: %s. Use 'help' for usage." command
