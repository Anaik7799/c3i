/// =============================================================================
/// COMPOSE GENERATOR - PODMAN-COMPOSE.YML GENERATION FROM CONFIG
/// =============================================================================
///
/// Version: 21.2.1-SIL6
/// Date: 2026-01-18
///
/// WHAT: Generates podman-compose.yml files from MeshConfig
/// WHY: Single source of truth for container orchestration
///
/// STAMP Compliance:
/// - SC-CONSOL-004: Generated files MUST be deterministic
/// - SC-CONFIG-001: All configuration from single source
/// - SC-CONFIG-002: NO magic values in generated files
/// - SC-MESH-001: Support all 15 SIL-6 containers
/// - SC-BOOT-009: Wave-based dependency ordering
///
/// =============================================================================

namespace Cepaf.Config

open System
open System.Text

/// Types for container specification
module ComposeTypes =

    /// Health check configuration
    type HealthCheck = {
        Test: string list           // ["CMD-SHELL", "command"]
        Interval: string            // "5s"
        Timeout: string             // "5s"
        Retries: int                // 10
        StartPeriod: string         // "15s"
    }

    /// Resource limits
    type Resources = {
        MemoryLimit: string         // "4G"
        CpuLimit: string            // "4.0"
        MemoryReservation: string option
        CpuReservation: string option
    }

    /// Network configuration
    type NetworkAttachment = {
        Name: string
        IpAddress: string option
    }

    /// Volume mount
    type VolumeMount = {
        Source: string              // "db_prod_data" or "./data"
        Target: string              // "/var/lib/postgresql/pgdata"
        Options: string option      // "z" for SELinux relabeling
    }

    /// Port mapping
    type PortMapping = {
        Host: int
        Container: int
        Protocol: string            // "tcp" | "udp"
    }

    /// Dependency configuration
    type Dependency = {
        Service: string
        Condition: string           // "service_healthy" | "service_started"
    }

    /// Container specification
    type ContainerSpec = {
        Name: string
        Hostname: string
        Image: string
        Networks: NetworkAttachment list
        Environment: Map<string, string>
        Ports: PortMapping list
        Volumes: VolumeMount list
        HealthCheck: HealthCheck option
        Resources: Resources option
        DependsOn: Dependency list
        Restart: string             // "unless-stopped" | "always" | "on-failure"
        Labels: Map<string, string>
        Wave: int                   // Boot wave (1-5)
    }

    /// Network specification
    type NetworkSpec = {
        Name: string
        Driver: string              // "bridge"
        Internal: bool
        Subnet: string option       // "172.28.0.0/16"
        Gateway: string option      // "172.28.0.1"
    }

    /// Volume specification
    type VolumeSpec = {
        Name: string
        Driver: string              // "local"
        Labels: Map<string, string>
    }

    /// Complete mesh configuration
    type MeshConfig = {
        Version: string             // "3.8"
        Networks: NetworkSpec list
        Volumes: VolumeSpec list
        Services: ContainerSpec list
    }

    /// Validation error
    type ValidationError =
        | MissingService of string
        | InvalidDependency of string * string
        | PortConflict of int
        | NetworkNotDefined of string
        | VolumeNotDefined of string


/// YAML generation utilities
module YamlGen =

    /// Generate indentation
    let indent (level: int) : string =
        String(' ', level * 2)

    /// Quote string if contains special characters
    let quoteIfNeeded (s: string) : string =
        if s.Contains(":") || s.Contains("#") || s.Contains("@") then
            $"\"{s}\""
        else
            s

    /// Generate key-value pair
    let kvPair (level: int) (key: string) (value: string) : string =
        $"{indent level}{key}: {quoteIfNeeded value}"

    /// Generate list item
    let listItem (level: int) (value: string) : string =
        $"{indent level}- {quoteIfNeeded value}"

    /// Generate environment variable
    let envVar (level: int) (key: string) (value: string) : string =
        $"{indent level}{key}: {quoteIfNeeded value}"

    /// Generate comment
    let comment (level: int) (text: string) : string =
        $"{indent level}# {text}"


/// Network YAML generation
module NetworkGen =
    open ComposeTypes
    open YamlGen

    /// Generate single network
    let generateNetwork (network: NetworkSpec) : string =
        let sb = StringBuilder()

        sb.AppendLine($"  {network.Name}:") |> ignore
        sb.AppendLine($"    driver: {network.Driver}") |> ignore

        if network.Internal then
            sb.AppendLine("    internal: true") |> ignore

        match network.Subnet, network.Gateway with
        | Some subnet, Some gateway ->
            sb.AppendLine("    ipam:") |> ignore
            sb.AppendLine("      config:") |> ignore
            sb.AppendLine($"        - subnet: {subnet}") |> ignore
            sb.AppendLine($"          gateway: {gateway}") |> ignore
        | Some subnet, None ->
            sb.AppendLine("    ipam:") |> ignore
            sb.AppendLine("      config:") |> ignore
            sb.AppendLine($"        - subnet: {subnet}") |> ignore
        | _ -> ()

        sb.ToString()

    /// Generate all networks
    let generateNetworksSection (networks: NetworkSpec list) : string =
        let sb = StringBuilder()
        sb.AppendLine("networks:") |> ignore
        networks |> List.iter (fun net -> sb.Append(generateNetwork net) |> ignore)
        sb.ToString()


/// Volume YAML generation
module VolumeGen =
    open ComposeTypes
    open YamlGen

    /// Generate single volume
    let generateVolume (volume: VolumeSpec) : string =
        let sb = StringBuilder()

        sb.AppendLine($"  {volume.Name}:") |> ignore
        sb.AppendLine($"    driver: {volume.Driver}") |> ignore

        if not (Map.isEmpty volume.Labels) then
            sb.AppendLine("    labels:") |> ignore
            volume.Labels
            |> Map.iter (fun k v -> sb.AppendLine(kvPair 3 k v) |> ignore)

        sb.ToString()

    /// Generate all volumes
    let generateVolumesSection (volumes: VolumeSpec list) : string =
        let sb = StringBuilder()
        sb.AppendLine("volumes:") |> ignore
        volumes |> List.iter (fun vol -> sb.Append(generateVolume vol) |> ignore)
        sb.ToString()


/// Service YAML generation
module ServiceGen =
    open ComposeTypes
    open YamlGen

    /// Generate health check
    let generateHealthCheck (level: int) (hc: HealthCheck) : string =
        let sb = StringBuilder()
        sb.AppendLine($"{indent level}healthcheck:") |> ignore

        // Test command
        sb.Append($"{indent (level + 1)}test: [") |> ignore
        hc.Test |> List.iteri (fun i cmd ->
            if i > 0 then sb.Append(", ") |> ignore
            sb.Append($"\"{cmd}\"") |> ignore
        )
        sb.AppendLine("]") |> ignore

        sb.AppendLine(kvPair (level + 1) "interval" hc.Interval) |> ignore
        sb.AppendLine(kvPair (level + 1) "timeout" hc.Timeout) |> ignore
        sb.AppendLine(kvPair (level + 1) "retries" (string hc.Retries)) |> ignore
        sb.AppendLine(kvPair (level + 1) "start_period" hc.StartPeriod) |> ignore

        sb.ToString()

    /// Generate resources
    let generateResources (level: int) (res: Resources) : string =
        let sb = StringBuilder()
        sb.AppendLine($"{indent level}deploy:") |> ignore
        sb.AppendLine($"{indent (level + 1)}resources:") |> ignore
        sb.AppendLine($"{indent (level + 2)}limits:") |> ignore
        sb.AppendLine(kvPair (level + 3) "memory" res.MemoryLimit) |> ignore
        sb.AppendLine(kvPair (level + 3) "cpus" $"'{res.CpuLimit}'") |> ignore

        match res.MemoryReservation, res.CpuReservation with
        | Some memRes, Some cpuRes ->
            sb.AppendLine($"{indent (level + 2)}reservations:") |> ignore
            sb.AppendLine(kvPair (level + 3) "memory" memRes) |> ignore
            sb.AppendLine(kvPair (level + 3) "cpus" $"'{cpuRes}'") |> ignore
        | _ -> ()

        sb.ToString()

    /// Generate networks section
    let generateNetworks (level: int) (networks: NetworkAttachment list) : string =
        let sb = StringBuilder()
        sb.AppendLine($"{indent level}networks:") |> ignore

        networks |> List.iter (fun net ->
            match net.IpAddress with
            | Some ip ->
                sb.AppendLine($"{indent (level + 1)}{net.Name}:") |> ignore
                sb.AppendLine(kvPair (level + 2) "ipv4_address" ip) |> ignore
            | None ->
                sb.AppendLine(listItem (level + 1) net.Name) |> ignore
        )

        sb.ToString()

    /// Generate environment section
    let generateEnvironment (level: int) (env: Map<string, string>) : string =
        let sb = StringBuilder()
        sb.AppendLine($"{indent level}environment:") |> ignore

        env
        |> Map.toList
        |> List.sortBy fst
        |> List.iter (fun (k, v) -> sb.AppendLine(envVar (level + 1) k v) |> ignore)

        sb.ToString()

    /// Generate ports section
    let generatePorts (level: int) (ports: PortMapping list) : string =
        let sb = StringBuilder()
        sb.AppendLine($"{indent level}ports:") |> ignore

        ports
        |> List.sortBy (fun p -> p.Host)
        |> List.iter (fun p ->
            sb.AppendLine(listItem (level + 1) $"{p.Host}:{p.Container}") |> ignore
        )

        sb.ToString()

    /// Generate volumes section
    let generateVolumes (level: int) (volumes: VolumeMount list) : string =
        let sb = StringBuilder()
        sb.AppendLine($"{indent level}volumes:") |> ignore

        volumes |> List.iter (fun v ->
            let mountStr =
                match v.Options with
                | Some opts -> $"{v.Source}:{v.Target}:{opts}"
                | None -> $"{v.Source}:{v.Target}"
            sb.AppendLine(listItem (level + 1) mountStr) |> ignore
        )

        sb.ToString()

    /// Generate depends_on section
    let generateDependsOn (level: int) (deps: Dependency list) : string =
        let sb = StringBuilder()
        if not (List.isEmpty deps) then
            sb.AppendLine($"{indent level}depends_on:") |> ignore
            deps |> List.iter (fun dep ->
                sb.AppendLine($"{indent (level + 1)}{dep.Service}:") |> ignore
                sb.AppendLine(kvPair (level + 2) "condition" dep.Condition) |> ignore
            )
        sb.ToString()

    /// Generate labels section
    let generateLabels (level: int) (labels: Map<string, string>) : string =
        let sb = StringBuilder()
        if not (Map.isEmpty labels) then
            sb.AppendLine($"{indent level}labels:") |> ignore
            labels
            |> Map.toList
            |> List.sortBy fst
            |> List.iter (fun (k, v) -> sb.AppendLine(kvPair (level + 1) k v) |> ignore)
        sb.ToString()

    /// Generate single service
    let generateService (container: ContainerSpec) : string =
        let sb = StringBuilder()

        // Service header with wave annotation
        sb.AppendLine() |> ignore
        sb.AppendLine(comment 1 $"Wave {container.Wave}: {container.Name}") |> ignore
        sb.AppendLine($"  {container.Name}:") |> ignore
        sb.AppendLine(kvPair 2 "image" container.Image) |> ignore
        sb.AppendLine(kvPair 2 "container_name" container.Name) |> ignore
        sb.AppendLine(kvPair 2 "hostname" container.Hostname) |> ignore

        // Networks
        if not (List.isEmpty container.Networks) then
            sb.Append(generateNetworks 2 container.Networks) |> ignore

        // Environment
        if not (Map.isEmpty container.Environment) then
            sb.Append(generateEnvironment 2 container.Environment) |> ignore

        // Ports
        if not (List.isEmpty container.Ports) then
            sb.Append(generatePorts 2 container.Ports) |> ignore

        // Volumes
        if not (List.isEmpty container.Volumes) then
            sb.Append(generateVolumes 2 container.Volumes) |> ignore

        // Health check
        match container.HealthCheck with
        | Some hc -> sb.Append(generateHealthCheck 2 hc) |> ignore
        | None -> ()

        // Resources
        match container.Resources with
        | Some res -> sb.Append(generateResources 2 res) |> ignore
        | None -> ()

        // Dependencies
        sb.Append(generateDependsOn 2 container.DependsOn) |> ignore

        // Restart policy
        sb.AppendLine(kvPair 2 "restart" container.Restart) |> ignore

        // Labels
        sb.Append(generateLabels 2 container.Labels) |> ignore

        sb.ToString()


/// Main compose generator
module ComposeGenerator =
    open ComposeTypes
    open NetworkGen
    open VolumeGen
    open ServiceGen

    /// Generate complete podman-compose.yml from config
    let generateFromConfig (config: MeshConfig) : string =
        let sb = StringBuilder()

        // Header
        let timestamp = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
        sb.AppendLine("# Generated by Cepaf.Config.ComposeGenerator") |> ignore
        sb.AppendLine($"# Version: {config.Version}") |> ignore
        sb.AppendLine($"# Generated: {timestamp} UTC") |> ignore
        sb.AppendLine("# STAMP: SC-CONSOL-004, SC-CONFIG-001, SC-CONFIG-002") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine($"version: '{config.Version}'") |> ignore
        sb.AppendLine() |> ignore

        // Networks
        sb.Append(NetworkGen.generateNetworksSection config.Networks) |> ignore
        sb.AppendLine() |> ignore

        // Volumes
        sb.Append(VolumeGen.generateVolumesSection config.Volumes) |> ignore
        sb.AppendLine() |> ignore

        // Services (grouped by wave)
        sb.AppendLine("services:") |> ignore
        config.Services
        |> List.sortBy (fun s -> s.Wave, s.Name)
        |> List.iter (fun svc -> sb.Append(generateService svc) |> ignore)

        sb.ToString()

    /// Validate generated compose against config
    let validateCompose (yaml: string) (config: MeshConfig) : Result<unit, ValidationError list> =
        let errors = ResizeArray<ValidationError>()

        // Check all services are present
        config.Services |> List.iter (fun svc ->
            if not (yaml.Contains(svc.Name)) then
                errors.Add(MissingService svc.Name)
        )

        // Check dependencies are valid
        let serviceNames = config.Services |> List.map (fun s -> s.Name) |> Set.ofList
        config.Services |> List.iter (fun svc ->
            svc.DependsOn |> List.iter (fun dep ->
                if not (serviceNames.Contains dep.Service) then
                    errors.Add(InvalidDependency(svc.Name, dep.Service))
            )
        )

        // Check port conflicts
        let ports =
            config.Services
            |> List.collect (fun s -> s.Ports |> List.map (fun p -> p.Host))
        let duplicatePorts =
            ports
            |> List.groupBy id
            |> List.filter (fun (_, group) -> List.length group > 1)
            |> List.map fst
        duplicatePorts |> List.iter (fun port -> errors.Add(PortConflict port))

        // Check networks are defined
        let definedNetworks = config.Networks |> List.map (fun n -> n.Name) |> Set.ofList
        config.Services |> List.iter (fun svc ->
            svc.Networks |> List.iter (fun net ->
                if not (definedNetworks.Contains net.Name) then
                    errors.Add(NetworkNotDefined net.Name)
            )
        )

        if errors.Count = 0 then
            Ok ()
        else
            Error (errors |> Seq.toList)


/// Builder for creating mesh configurations
module MeshConfigBuilder =
    open ComposeTypes
    open Cepaf.Config.NetworkConfig
    open Cepaf.Config.ContainerConfig
    open Cepaf.Config.EnvironmentConfig
    open Cepaf.Config.VolumeConfig

    /// Create database container
    let createDbContainer () : ContainerSpec =
        {
            Name = Hostnames.dbProd
            Hostname = Hostnames.dbProd
            Image = Images.dbTimescale
            Networks = [
                { Name = NetworkNames.sil6Mesh; IpAddress = Some IpAddresses.database }
                { Name = NetworkNames.internalNet; IpAddress = None }
            ]
            Environment = Map.ofList [
                ("POSTGRES_DB", "indrajaal_prod")
                ("POSTGRES_USER", "postgres")
                ("POSTGRES_PASSWORD", "postgres")
                ("PGPORT", "5433")
                ("TS_TUNE_MEMORY", "4GB")
                ("TS_TUNE_NUM_CPUS", "4")
                ("PHICS_ENABLED", "true")
                ("NO_TIMEOUT", "true")
                ("PGDATA", "/var/lib/postgresql/pgdata")
            ]
            Ports = [
                { Host = Ports.postgres; Container = Ports.postgresInternal; Protocol = "tcp" }
            ]
            Volumes = [
                { Source = Named.dbProdData; Target = Paths.postgresData; Options = Some "z" }
            ]
            HealthCheck = Some {
                Test = ["CMD-SHELL"; "pg_isready -U postgres -d indrajaal_prod -p 5433"]
                Interval = "5s"
                Timeout = "5s"
                Retries = 10
                StartPeriod = "15s"
            }
            Resources = Some {
                MemoryLimit = $"{Resources.dbMemoryMb}M"
                CpuLimit = string Resources.dbCpuLimit
                MemoryReservation = Some $"{Resources.dbMemoryReservationMb}M"
                CpuReservation = Some (string Resources.dbCpuReservation)
            }
            DependsOn = []
            Restart = "unless-stopped"
            Labels = Map.ofList [
                ("project", "indrajaal")
                ("component", "database")
                ("environment", "sil6-mesh")
                ("sil.level", "6")
            ]
            Wave = 1
        }

    /// Create observability container
    let createObsContainer () : ContainerSpec =
        {
            Name = Hostnames.obsProd
            Hostname = Hostnames.obsProd
            Image = Images.obsUnified
            Networks = [
                { Name = NetworkNames.sil6Mesh; IpAddress = Some IpAddresses.observability }
            ]
            Environment = Map.ofList [
                ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")
                ("OTEL_SERVICE_NAME", "indrajaal-obs-prod")
                ("LOG_LEVEL", "info")
                ("PROMETHEUS_RETENTION_TIME", "15d")
                ("GF_SECURITY_ADMIN_USER", "admin")
                ("GF_SECURITY_ADMIN_PASSWORD", "indrajaal")
            ]
            Ports = [
                { Host = Ports.otelGrpc; Container = Ports.otelGrpc; Protocol = "tcp" }
                { Host = Ports.otelHttp; Container = Ports.otelHttp; Protocol = "tcp" }
                { Host = Ports.prometheus; Container = Ports.prometheus; Protocol = "tcp" }
                { Host = Ports.grafana; Container = Ports.grafana; Protocol = "tcp" }
                { Host = Ports.loki; Container = Ports.loki; Protocol = "tcp" }
            ]
            Volumes = []
            HealthCheck = Some {
                Test = ["CMD-SHELL"; "wget -q --spider http://localhost:9090/-/healthy"]
                Interval = "15s"
                Timeout = "10s"
                Retries = 5
                StartPeriod = "45s"
            }
            Resources = Some {
                MemoryLimit = $"{Resources.obsMemoryMb}M"
                CpuLimit = string Resources.obsCpuLimit
                MemoryReservation = Some $"{Resources.obsMemoryReservationMb}M"
                CpuReservation = Some (string Resources.obsCpuReservation)
            }
            DependsOn = [
                { Service = Hostnames.dbProd; Condition = "service_healthy" }
            ]
            Restart = "unless-stopped"
            Labels = Map.ofList [
                ("project", "indrajaal")
                ("component", "observability")
                ("sil.level", "6")
            ]
            Wave = 1
        }

    /// Create Zenoh router container
    let createZenohRouter (routerNum: int) : ContainerSpec =
        let name = if routerNum = 1 then Hostnames.zenohRouter1
                   elif routerNum = 2 then Hostnames.zenohRouter2
                   else Hostnames.zenohRouter3
        let ip = if routerNum = 1 then IpAddresses.zenohRouter1
                 elif routerNum = 2 then IpAddresses.zenohRouter2
                 else IpAddresses.zenohRouter3
        let tcpPort = if routerNum = 1 then Ports.zenohRouter1Tcp
                      elif routerNum = 2 then Ports.zenohRouter2Tcp
                      else Ports.zenohRouter3Tcp
        let wsPort = if routerNum = 1 then Ports.zenohRouter1Ws
                     elif routerNum = 2 then Ports.zenohRouter2Ws
                     else Ports.zenohRouter3Ws
        let restPort = if routerNum = 1 then Ports.zenohRouter1Rest
                       elif routerNum = 2 then Ports.zenohRouter2Rest
                       else Ports.zenohRouter3Rest

        {
            Name = name
            Hostname = name
            Image = Images.zenoh
            Networks = [
                { Name = NetworkNames.sil6Mesh; IpAddress = Some ip }
            ]
            Environment = Map.ofList [
                ("ZENOH_MODE", "router")
                ("ZENOH_LISTEN", $"tcp/0.0.0.0:{tcpPort}")
            ]
            Ports = [
                { Host = tcpPort; Container = 7447; Protocol = "tcp" }
                { Host = wsPort; Container = 8000; Protocol = "tcp" }
                { Host = restPort; Container = 8000; Protocol = "tcp" }
            ]
            Volumes = []
            HealthCheck = Some {
                Test = ["CMD-SHELL"; "nc -z localhost 8000"]
                Interval = "10s"
                Timeout = "5s"
                Retries = 5
                StartPeriod = "10s"
            }
            Resources = Some {
                MemoryLimit = $"{Resources.zenohMemoryMb}M"
                CpuLimit = string Resources.zenohCpuLimit
                MemoryReservation = Some $"{Resources.zenohMemoryReservationMb}M"
                CpuReservation = Some (string Resources.zenohCpuReservation)
            }
            DependsOn = [
                { Service = Hostnames.dbProd; Condition = "service_healthy" }
                { Service = Hostnames.obsProd; Condition = "service_healthy" }
            ]
            Restart = "unless-stopped"
            Labels = Map.ofList [
                ("project", "indrajaal")
                ("component", "zenoh-control-plane")
                ("router", $"router-{routerNum}")
                ("sil.level", "6")
            ]
            Wave = 2
        }

    /// Create application container
    let createAppContainer (appNum: int) : ContainerSpec =
        let name = if appNum = 1 then Hostnames.appPrimary
                   elif appNum = 2 then Hostnames.appNode2
                   else Hostnames.appNode3
        let ip = if appNum = 1 then IpAddresses.appPrimary
                 elif appNum = 2 then IpAddresses.appNode2
                 else IpAddresses.appNode3
        let httpPort = if appNum = 1 then Ports.phoenixPrimary
                       elif appNum = 2 then Ports.phoenixApp2
                       else Ports.phoenixApp3
        let healthPort = if appNum = 1 then Ports.phoenixHealth
                         elif appNum = 2 then Ports.phoenixApp2Health
                         else Ports.phoenixApp3Health
        let isSeed = appNum = 1

        {
            Name = name
            Hostname = name
            Image = Images.appUnified
            Networks = [
                { Name = NetworkNames.sil6Mesh; IpAddress = Some ip }
            ]
            Environment = buildAppEnvironment name isSeed "prod"
            Ports = [
                { Host = httpPort; Container = 4000; Protocol = "tcp" }
                { Host = healthPort; Container = 4001; Protocol = "tcp" }
                { Host = Ports.redis; Container = Ports.redis; Protocol = "tcp" }
            ]
            Volumes = [
                { Source = "./"; Target = Paths.workspace; Options = None }
                { Source = Named.appBuildCache; Target = Paths.build; Options = None }
                { Source = Named.appDepsCache; Target = Paths.deps; Options = None }
            ]
            HealthCheck = Some {
                Test = ["CMD-SHELL"; "curl -sf http://localhost:4000/ > /dev/null || exit 1"]
                Interval = "10s"
                Timeout = "10s"
                Retries = 12
                StartPeriod = "60s"
            }
            Resources = Some {
                MemoryLimit = $"{Resources.appMemoryMb}M"
                CpuLimit = string Resources.appCpuLimit
                MemoryReservation = Some $"{Resources.appMemoryReservationMb}M"
                CpuReservation = Some (string Resources.appCpuReservation)
            }
            DependsOn = [
                { Service = Hostnames.dbProd; Condition = "service_healthy" }
                { Service = Hostnames.obsProd; Condition = "service_healthy" }
                { Service = Hostnames.zenohRouter1; Condition = "service_healthy" }
            ]
            Restart = "unless-stopped"
            Labels = Map.ofList [
                ("project", "indrajaal")
                ("component", "application")
                ("node", $"app-{appNum}")
                ("seed", if isSeed then "true" else "false")
                ("sil.level", "6")
            ]
            Wave = 3
        }

    /// Create default SIL-6 full mesh configuration
    let createSil6FullMesh () : MeshConfig =
        {
            Version = "3.8"
            Networks = [
                {
                    Name = NetworkNames.sil6Mesh
                    Driver = "bridge"
                    Internal = false
                    Subnet = Some IpAddresses.subnet
                    Gateway = Some IpAddresses.gateway
                }
                {
                    Name = NetworkNames.internalNet
                    Driver = "bridge"
                    Internal = true
                    Subnet = Some IpAddresses.internalSubnet
                    Gateway = None
                }
            ]
            Volumes = [
                { Name = Named.dbProdData; Driver = "local"; Labels = Map.empty }
                { Name = Named.appBuildCache; Driver = "local"; Labels = Map.empty }
                { Name = Named.appDepsCache; Driver = "local"; Labels = Map.empty }
            ]
            Services = [
                // Wave 1: Infrastructure
                createDbContainer ()
                createObsContainer ()

                // Wave 2: Zenoh Control Plane
                createZenohRouter 1
                createZenohRouter 2
                createZenohRouter 3

                // Wave 3: Application Nodes
                createAppContainer 1
                createAppContainer 2
                createAppContainer 3
            ]
        }
