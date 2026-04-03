namespace Cepaf.Podman.Compose

open System
open System.IO
open YamlDotNet.Serialization
open YamlDotNet.Serialization.NamingConventions
open Cepaf.Podman.Domain

/// Compose file parser for podman-compose YAML files
module Parser =

    // ========================================================================
    // Compose File Types
    // ========================================================================

    /// Compose file version
    type ComposeVersion =
        | V2
        | V3
        | V3_8
        | Unknown of string

    module ComposeVersion =
        let parse (v: string) =
            match v with
            | "2" | "2.0" | "2.1" | "2.2" | "2.3" | "2.4" -> V2
            | "3" | "3.0" | "3.1" | "3.2" | "3.3" | "3.4" | "3.5" | "3.6" | "3.7" -> V3
            | "3.8" | "3.9" -> V3_8
            | other -> Unknown other

    /// Port mapping in compose
    type ComposePort = {
        Published: int
        Target: int
        Protocol: string
    }

    /// Volume mount in compose
    type ComposeVolume = {
        Source: string
        Target: string
        ReadOnly: bool
        Type: string  // "bind", "volume", "tmpfs"
    }

    /// Environment variable
    type ComposeEnv =
        | Value of string * string
        | File of string

    /// Healthcheck configuration
    type ComposeHealthCheck = {
        Test: string list
        Interval: TimeSpan option
        Timeout: TimeSpan option
        Retries: int option
        StartPeriod: TimeSpan option
    }

    /// Deploy configuration (swarm/replicas)
    type ComposeDeploy = {
        Replicas: int option
        Resources: ComposeResources option
        RestartPolicy: ComposeRestartPolicy option
    }

    and ComposeResources = {
        Limits: ComposeResourceLimits option
        Reservations: ComposeResourceLimits option
    }

    and ComposeResourceLimits = {
        Cpus: string option
        Memory: string option
        Pids: int option
    }

    and ComposeRestartPolicy = {
        Condition: string
        Delay: TimeSpan option
        MaxAttempts: int option
        Window: TimeSpan option
    }

    /// Network configuration for service
    type ComposeServiceNetwork = {
        Aliases: string list
        IPv4Address: string option
        IPv6Address: string option
    }

    /// Service definition
    type ComposeService = {
        Name: string
        Image: string option
        Build: ComposeBuild option
        Command: string list
        Entrypoint: string list
        Environment: ComposeEnv list
        Ports: ComposePort list
        Volumes: ComposeVolume list
        Networks: Map<string, ComposeServiceNetwork>
        DependsOn: string list
        HealthCheck: ComposeHealthCheck option
        Deploy: ComposeDeploy option
        Restart: string option
        Labels: Map<string, string>
        WorkingDir: string option
        User: string option
        Privileged: bool
        CapAdd: string list
        CapDrop: string list
        SecurityOpt: string list
    }

    and ComposeBuild = {
        Context: string
        Dockerfile: string option
        Args: Map<string, string>
        Target: string option
    }

    /// Network definition
    type ComposeNetwork = {
        Name: string
        Driver: string option
        DriverOpts: Map<string, string>
        External: bool
        Internal: bool
        Labels: Map<string, string>
        Ipam: ComposeIpam option
    }

    and ComposeIpam = {
        Driver: string option
        Config: ComposeIpamConfig list
    }

    and ComposeIpamConfig = {
        Subnet: string option
        Gateway: string option
    }

    /// Volume definition
    type ComposeVolumeConfig = {
        Name: string
        Driver: string option
        DriverOpts: Map<string, string>
        External: bool
        Labels: Map<string, string>
    }

    /// Complete compose file
    type ComposeFile = {
        Version: ComposeVersion
        Services: Map<string, ComposeService>
        Networks: Map<string, ComposeNetwork>
        Volumes: Map<string, ComposeVolumeConfig>
    }

    // ========================================================================
    // YAML Parsing Helpers
    // ========================================================================

    /// Parse duration string (e.g., "30s", "1m", "2h")
    let parseDuration (s: string) : TimeSpan option =
        if String.IsNullOrWhiteSpace(s) then None
        else
            try
                let s = s.Trim()
                if s.EndsWith("ms") then
                    let ms = Int32.Parse(s.TrimEnd('m', 's'))
                    Some (TimeSpan.FromMilliseconds(float ms))
                elif s.EndsWith("s") then
                    let sec = Int32.Parse(s.TrimEnd('s'))
                    Some (TimeSpan.FromSeconds(float sec))
                elif s.EndsWith("m") then
                    let min = Int32.Parse(s.TrimEnd('m'))
                    Some (TimeSpan.FromMinutes(float min))
                elif s.EndsWith("h") then
                    let hr = Int32.Parse(s.TrimEnd('h'))
                    Some (TimeSpan.FromHours(float hr))
                else
                    None
            with _ -> None

    /// Parse memory string (e.g., "512M", "2G")
    let parseMemory (s: string) : int64 option =
        if String.IsNullOrWhiteSpace(s) then None
        else
            try
                let s = s.Trim().ToUpperInvariant()
                if s.EndsWith("B") then
                    let s = s.TrimEnd('B')
                    if s.EndsWith("K") then
                        Some (Int64.Parse(s.TrimEnd('K')) * 1024L)
                    elif s.EndsWith("M") then
                        Some (Int64.Parse(s.TrimEnd('M')) * 1024L * 1024L)
                    elif s.EndsWith("G") then
                        Some (Int64.Parse(s.TrimEnd('G')) * 1024L * 1024L * 1024L)
                    else
                        Some (Int64.Parse(s))
                elif s.EndsWith("K") then
                    Some (Int64.Parse(s.TrimEnd('K')) * 1024L)
                elif s.EndsWith("M") then
                    Some (Int64.Parse(s.TrimEnd('M')) * 1024L * 1024L)
                elif s.EndsWith("G") then
                    Some (Int64.Parse(s.TrimEnd('G')) * 1024L * 1024L * 1024L)
                else
                    Some (Int64.Parse(s))
            with _ -> None

    /// Parse port string (e.g., "8080:80", "8080:80/tcp")
    let parsePort (s: string) : ComposePort option =
        try
            let parts = s.Split(':')
            if parts.Length = 2 then
                let targetParts = parts.[1].Split('/')
                let protocol = if targetParts.Length > 1 then targetParts.[1] else "tcp"
                Some {
                    Published = Int32.Parse(parts.[0])
                    Target = Int32.Parse(targetParts.[0])
                    Protocol = protocol
                }
            elif parts.Length = 1 then
                let targetParts = parts.[0].Split('/')
                let port = Int32.Parse(targetParts.[0])
                let protocol = if targetParts.Length > 1 then targetParts.[1] else "tcp"
                Some {
                    Published = port
                    Target = port
                    Protocol = protocol
                }
            else None
        with _ -> None

    /// Parse volume string (e.g., "./data:/app/data:ro")
    let parseVolume (s: string) : ComposeVolume option =
        try
            let parts = s.Split(':')
            if parts.Length >= 2 then
                let readOnly = parts.Length > 2 && parts.[2].Contains("ro")
                let volType =
                    if parts.[0].StartsWith("/") || parts.[0].StartsWith("./") || parts.[0].StartsWith("~") then "bind"
                    else "volume"
                Some {
                    Source = parts.[0]
                    Target = parts.[1]
                    ReadOnly = readOnly
                    Type = volType
                }
            else None
        with _ -> None

    // ========================================================================
    // YAML Deserialization
    // ========================================================================

    /// Raw YAML structure (before typed parsing)
    type private RawComposeFile = System.Collections.Generic.Dictionary<string, obj>

    /// Try to get a dictionary from an object
    let private tryAsDict (obj: obj) : System.Collections.Generic.IDictionary<obj, obj> option =
        match obj with
        | :? System.Collections.Generic.IDictionary<obj, obj> as d -> Some d
        | _ -> None

    /// Parse compose file from YAML string
    let rec parse (yaml: string) : PodmanResult<ComposeFile> =
        try
            let deserializer =
                DeserializerBuilder()
                    .WithNamingConvention(UnderscoredNamingConvention.Instance)
                    .Build()

            let raw = deserializer.Deserialize<RawComposeFile>(yaml)

            // Parse version
            let version =
                match raw.TryGetValue("version") with
                | true, v -> ComposeVersion.parse (string v)
                | false, _ -> V3  // Default

            // Parse services
            let services =
                match raw.TryGetValue("services") with
                | true, s ->
                    match tryAsDict s with
                    | Some serviceDict ->
                        serviceDict
                        |> Seq.map (fun kvp ->
                            let name = string kvp.Key
                            let svc = parseService name kvp.Value
                            (name, svc))
                        |> Map.ofSeq
                    | None -> Map.empty
                | false, _ -> Map.empty

            // Parse networks
            let networks =
                match raw.TryGetValue("networks") with
                | true, n ->
                    match tryAsDict n with
                    | Some netDict ->
                        netDict
                        |> Seq.map (fun kvp ->
                            let name = string kvp.Key
                            let net = parseNetwork name kvp.Value
                            (name, net))
                        |> Map.ofSeq
                    | None -> Map.empty
                | false, _ -> Map.empty

            // Parse volumes
            let volumes =
                match raw.TryGetValue("volumes") with
                | true, v ->
                    match tryAsDict v with
                    | Some volDict ->
                        volDict
                        |> Seq.map (fun kvp ->
                            let name = string kvp.Key
                            let vol = parseVolumeConfig name kvp.Value
                            (name, vol))
                        |> Map.ofSeq
                    | None -> Map.empty
                | false, _ -> Map.empty

            Ok {
                Version = version
                Services = services
                Networks = networks
                Volumes = volumes
            }
        with ex ->
            Error (PodmanError.JsonParseError (sprintf "Compose parse error: %s" ex.Message))

    /// Parse a service definition
    and private parseService (name: string) (obj: obj) : ComposeService =
        let defaultService = {
            Name = name
            Image = None
            Build = None
            Command = []
            Entrypoint = []
            Environment = []
            Ports = []
            Volumes = []
            Networks = Map.empty
            DependsOn = []
            HealthCheck = None
            Deploy = None
            Restart = None
            Labels = Map.empty
            WorkingDir = None
            User = None
            Privileged = false
            CapAdd = []
            CapDrop = []
            SecurityOpt = []
        }

        match obj with
        | :? System.Collections.Generic.IDictionary<obj, obj> as dict ->
            let getString key = dict |> Seq.tryFind (fun kvp -> string kvp.Key = key) |> Option.map (fun kvp -> string kvp.Value)
            let getBool key = getString key |> Option.map (fun s -> s.ToLower() = "true") |> Option.defaultValue false
            let getList key =
                dict |> Seq.tryFind (fun kvp -> string kvp.Key = key)
                |> Option.bind (fun kvp ->
                    match kvp.Value with
                    | :? System.Collections.Generic.IList<obj> as list ->
                        Some (list |> Seq.map string |> Seq.toList)
                    | _ -> None
                )
                |> Option.defaultValue []

            { defaultService with
                Image = getString "image"
                Command = getList "command"
                Entrypoint = getList "entrypoint"
                Ports = getList "ports" |> List.choose parsePort
                Volumes = getList "volumes" |> List.choose parseVolume
                DependsOn = getList "depends_on"
                Restart = getString "restart"
                WorkingDir = getString "working_dir"
                User = getString "user"
                Privileged = getBool "privileged"
                CapAdd = getList "cap_add"
                CapDrop = getList "cap_drop"
                SecurityOpt = getList "security_opt"
            }
        | _ -> defaultService

    /// Parse a network definition
    and private parseNetwork (name: string) (obj: obj) : ComposeNetwork =
        let defaultNetwork = {
            Name = name
            Driver = None
            DriverOpts = Map.empty
            External = false
            Internal = false
            Labels = Map.empty
            Ipam = None
        }

        match obj with
        | :? System.Collections.Generic.IDictionary<obj, obj> as dict ->
            let getString key = dict |> Seq.tryFind (fun kvp -> string kvp.Key = key) |> Option.map (fun kvp -> string kvp.Value)
            let getBool key = getString key |> Option.map (fun s -> s.ToLower() = "true") |> Option.defaultValue false

            { defaultNetwork with
                Driver = getString "driver"
                External = getBool "external"
                Internal = getBool "internal"
            }
        | null -> { defaultNetwork with External = true }  // Shorthand external network
        | _ -> defaultNetwork

    /// Parse a volume config
    and private parseVolumeConfig (name: string) (obj: obj) : ComposeVolumeConfig =
        let defaultVolume = {
            Name = name
            Driver = None
            DriverOpts = Map.empty
            External = false
            Labels = Map.empty
        }

        match obj with
        | :? System.Collections.Generic.IDictionary<obj, obj> as dict ->
            let getString key = dict |> Seq.tryFind (fun kvp -> string kvp.Key = key) |> Option.map (fun kvp -> string kvp.Value)
            let getBool key = getString key |> Option.map (fun s -> s.ToLower() = "true") |> Option.defaultValue false

            { defaultVolume with
                Driver = getString "driver"
                External = getBool "external"
            }
        | null -> { defaultVolume with External = true }  // Shorthand external volume
        | _ -> defaultVolume

    // ========================================================================
    // File Operations
    // ========================================================================

    /// Parse compose file from path
    let parseFile (path: string) : PodmanResult<ComposeFile> =
        try
            let yaml = File.ReadAllText(path)
            parse yaml
        with ex ->
            Error (PodmanError.InternalError (sprintf "Failed to read file: %s" ex.Message))

    /// Find compose file in directory
    let findComposeFile (directory: string) : string option =
        let candidates = [
            "podman-compose.yml"
            "podman-compose.yaml"
            "docker-compose.yml"
            "docker-compose.yaml"
            "compose.yml"
            "compose.yaml"
        ]
        candidates
        |> List.map (fun f -> Path.Combine(directory, f))
        |> List.tryFind File.Exists

    // ========================================================================
    // Conversion to Domain Types
    // ========================================================================

    /// Convert compose service to container spec
    let toContainerSpec (service: ComposeService) : ContainerSpec option =
        service.Image |> Option.map (fun image ->
            let spec =
                ContainerSpec.create image
                |> fun s -> { s with Name = Some service.Name }

            let spec =
                service.Ports
                |> List.fold (fun s p ->
                    ContainerSpec.withPort (uint16 p.Published) (uint16 p.Target) s
                ) spec

            let spec =
                service.Volumes
                |> List.fold (fun s v ->
                    if v.Type = "bind" then
                        let mount =
                            Mount.createBind v.Source v.Target
                            |> fun m -> if v.ReadOnly then Mount.withReadOnly m else m
                        ContainerSpec.withMount mount s
                    else
                        ContainerSpec.withVolume v.Source v.Target s
                ) spec

            let spec =
                match service.Restart with
                | Some "always" -> { spec with RestartPolicy = Some RestartPolicy.always }
                | Some "unless-stopped" -> { spec with RestartPolicy = Some RestartPolicy.unlessStopped }
                | Some "on-failure" -> { spec with RestartPolicy = Some (RestartPolicy.onFailure 5) }
                | _ -> spec

            spec
        )

    /// Convert compose network to network spec
    let toNetworkSpec (network: ComposeNetwork) : NetworkSpec =
        let spec = NetworkSpec.create network.Name
        match network.Driver with
        | Some d -> NetworkSpec.withDriver (NetworkDriver.parse d) spec
        | None -> spec

    /// Convert compose volume to volume spec
    let toVolumeSpec (volume: ComposeVolumeConfig) : VolumeSpec =
        let spec = VolumeSpec.create volume.Name
        match volume.Driver with
        | Some d -> VolumeSpec.withDriver (VolumeDriver.parse d) spec
        | None -> spec

    /// Get service dependency order (topological sort)
    let getDeploymentOrder (compose: ComposeFile) : string list =
        let deps =
            compose.Services
            |> Map.toList
            |> List.map (fun (name, svc) -> (name, svc.DependsOn))
            |> Map.ofList

        let rec visit (visited: Set<string>) (order: string list) (name: string) =
            if visited.Contains(name) then (visited, order)
            else
                let visited = visited.Add(name)
                let serviceDeps = deps |> Map.tryFind name |> Option.defaultValue []
                let (visited, order) =
                    serviceDeps |> List.fold (fun (v, o) d -> visit v o d) (visited, order)
                (visited, name :: order)

        let (_, order) =
            compose.Services
            |> Map.toList
            |> List.map fst
            |> List.fold (fun (v, o) name -> visit v o name) (Set.empty, [])

        order |> List.rev

