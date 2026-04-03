namespace Cepaf.Podman.Api

open System
open System.Text.Json
open Cepaf.Podman.Domain
open Cepaf.Podman.Client

/// Podman system operations
module System =

    // ========================================================================
    // Info Operations
    // ========================================================================

    /// Get system information
    let info (client: PodmanClient) : AsyncPodmanResult<SystemInfo> = async {
        let! result = HttpClient.getRaw client "/info"
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                let root = doc.RootElement

                let hostElement =
                    match root.TryGetProperty("host") with
                    | true, h -> h
                    | false, _ -> root

                let storeElement =
                    match root.TryGetProperty("store") with
                    | true, s -> s
                    | false, _ -> root

                let versionElement =
                    match root.TryGetProperty("version") with
                    | true, v -> v
                    | false, _ -> root

                let host = {
                    Hostname = Serialization.getString "hostname" "" hostElement
                    Os = Serialization.getString "os" "linux" hostElement
                    Arch = Serialization.getString "arch" "" hostElement
                    Kernel = Serialization.getString "kernel" "" hostElement
                    Uptime = Serialization.getString "uptime" "" hostElement
                    MemTotal = Serialization.getInt64 "memTotal" 0L hostElement
                    MemFree = Serialization.getInt64 "memFree" 0L hostElement
                    SwapTotal = Serialization.getInt64 "swapTotal" 0L hostElement
                    SwapFree = Serialization.getInt64 "swapFree" 0L hostElement
                    CpuCount = Serialization.getInt "cpus" 1 hostElement
                }

                let storage = {
                    Driver = Serialization.getString "graphDriverName" "overlay" storeElement
                    GraphRoot = Serialization.getString "graphRoot" "" storeElement
                    RunRoot = Serialization.getString "runRoot" "" storeElement
                    ImageCount = Serialization.getInt "imageCount" 0 storeElement
                    ContainerCount = Serialization.getInt "containerCount" 0 storeElement
                }

                let runtimeElement =
                    match hostElement.TryGetProperty("ociRuntime") with
                    | true, r -> r
                    | false, _ -> hostElement

                let runtime = {
                    Name = Serialization.getString "name" "crun" runtimeElement
                    Path = Serialization.getString "path" "" runtimeElement
                    Version = Serialization.tryGetString "version" runtimeElement
                }

                let version = {
                    Version = Serialization.getString "Version" "" versionElement
                    ApiVersion = Serialization.getString "APIVersion" "" versionElement
                    GoVersion = Serialization.getString "GoVersion" "" versionElement
                    GitCommit = Serialization.getString "GitCommit" "" versionElement
                    Built = Serialization.tryGetString "Built" versionElement |> Option.bind Serialization.parseDateTimeOffset
                    OsArch = Serialization.getString "OsArch" "" versionElement
                }

                Ok {
                    Host = host
                    Storage = storage
                    Runtime = runtime
                    Version = version
                }
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    /// Get version information
    let version (client: PodmanClient) : AsyncPodmanResult<VersionInfo> =
        HttpClient.version client

    /// Ping API to check connectivity
    let ping (client: PodmanClient) : AsyncPodmanResult<bool> =
        HttpClient.ping client

    // ========================================================================
    // Disk Usage
    // ========================================================================

    /// Get disk usage information
    let diskUsage (client: PodmanClient) : AsyncPodmanResult<DiskUsage> = async {
        let! result = HttpClient.getRaw client "/system/df"
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                let root = doc.RootElement

                let parseEntry (name: string) (element: JsonElement) : DiskUsageEntry =
                    match element.TryGetProperty(name) with
                    | true, arr when arr.ValueKind = JsonValueKind.Array ->
                        let items = [ for item in arr.EnumerateArray() -> item ]
                        {
                            Type = name
                            Total = items.Length
                            Active = items |> List.filter (fun i -> Serialization.getBool "Active" false i) |> List.length
                            Size = items |> List.sumBy (fun i -> Serialization.getInt64 "Size" 0L i)
                            Reclaimable = items |> List.sumBy (fun i -> Serialization.getInt64 "ReclaimableSize" 0L i)
                        }
                    | _ ->
                        { Type = name; Total = 0; Active = 0; Size = 0L; Reclaimable = 0L }

                Ok {
                    Containers = parseEntry "Containers" root
                    Images = parseEntry "Images" root
                    Volumes = parseEntry "Volumes" root
                }
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    // ========================================================================
    // Prune Operations
    // ========================================================================

    /// Prune unused containers
    let pruneContainers (client: PodmanClient) : AsyncPodmanResult<string list> = async {
        let! result = HttpClient.postEmpty client "/containers/prune"
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                Ok (Serialization.getStringArray "ContainersDeleted" doc.RootElement)
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    /// Prune unused images
    let pruneImages (client: PodmanClient) (all: bool) : AsyncPodmanResult<string list> = async {
        let query = if all then "?all=true" else ""
        let! result = HttpClient.postEmpty client (sprintf "/images/prune%s" query)
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                Ok (Serialization.getStringArray "ImagesDeleted" doc.RootElement)
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    /// Prune unused volumes
    let pruneVolumes (client: PodmanClient) : AsyncPodmanResult<string list> = async {
        let! result = HttpClient.postEmpty client "/volumes/prune"
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                Ok (Serialization.getStringArray "VolumesDeleted" doc.RootElement)
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    /// Prune unused networks
    let pruneNetworks (client: PodmanClient) : AsyncPodmanResult<string list> = async {
        let! result = HttpClient.postEmpty client "/networks/prune"
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                Ok (Serialization.getStringArray "NetworksDeleted" doc.RootElement)
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    /// Prune all unused resources (system prune)
    let pruneAll (client: PodmanClient) (volumes: bool) : AsyncPodmanResult<unit> = async {
        let query = if volumes then "?volumes=true" else ""
        let! result = HttpClient.postEmpty client (sprintf "/system/prune%s" query)
        return result |> Result.map ignore
    }
