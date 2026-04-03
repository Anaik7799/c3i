namespace Cepaf.Podman.Api

open System
open System.Text.Json
open Cepaf.Podman.Domain
open Cepaf.Podman.Client

/// Pod management operations
module Pods =

    // ========================================================================
    // List Operations
    // ========================================================================

    /// List pods
    let list (client: PodmanClient) (all: bool) : AsyncPodmanResult<PodSummary list> = async {
        let query = if all then "?all=true" else ""
        let! result = HttpClient.getRaw client (sprintf "/pods/json%s" query)
        return result |> Result.bind Serialization.parsePodList
    }

    /// List all pods
    let listAll (client: PodmanClient) : AsyncPodmanResult<PodSummary list> =
        list client true

    /// Check if pod exists
    let exists (client: PodmanClient) (name: string) : AsyncPodmanResult<bool> = async {
        let! result = HttpClient.getRaw client (sprintf "/pods/%s/exists" name)
        match result with
        | Ok _ -> return Ok true
        | Error (PodmanError.NotFound _) -> return Ok false
        | Error e -> return Error e
    }

    // ========================================================================
    // Inspect Operations
    // ========================================================================

    /// Inspect pod
    let inspect (client: PodmanClient) (name: string) : AsyncPodmanResult<PodInspect> = async {
        let! result = HttpClient.getRaw client (sprintf "/pods/%s/json" name)
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                let root = doc.RootElement

                let containers =
                    Serialization.getArray "Containers" root
                    |> List.map (fun c -> {
                        Id = Serialization.getString "Id" "" c
                        Name = Serialization.getString "Name" "" c
                        Status = ContainerStatus.parse (Serialization.getString "State" "unknown" c)
                    })

                Ok {
                    Id = Serialization.getString "Id" "" root
                    Name = Serialization.getString "Name" "" root
                    Created = Serialization.tryGetString "Created" root
                        |> Option.bind Serialization.parseDateTimeOffset
                        |> Option.defaultValue DateTimeOffset.MinValue
                    State = PodStatus.parse (Serialization.getString "State" "unknown" root)
                    Hostname = Serialization.tryGetString "Hostname" root
                    Labels = Serialization.getStringMap "Labels" root
                    Containers = containers
                    InfraContainerId = Serialization.tryGetString "InfraContainerID" root
                    CgroupParent = Serialization.tryGetString "CgroupParent" root
                    SharedNamespaces = Serialization.getStringArray "SharedNamespaces" root
                }
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    // ========================================================================
    // Lifecycle Operations
    // ========================================================================

    /// Create pod
    let create (client: PodmanClient) (spec: PodSpec) : AsyncPodmanResult<string> = async {
        let json = Serialization.serializePodSpec spec
        let! result = HttpClient.postJson client "/pods/create" json
        return result |> Result.bind Serialization.parseCreateResponse
    }

    /// Start pod
    let start (client: PodmanClient) (name: string) : AsyncPodmanResult<unit> = async {
        let! result = HttpClient.postEmpty client (sprintf "/pods/%s/start" name)
        return result |> Result.map ignore
    }

    /// Stop pod
    let stop (client: PodmanClient) (name: string) (timeout: int option) : AsyncPodmanResult<unit> = async {
        let query =
            match timeout with
            | Some t -> sprintf "?timeout=%d" t
            | None -> ""
        let! result = HttpClient.postEmpty client (sprintf "/pods/%s/stop%s" name query)
        return result |> Result.map ignore
    }

    /// Restart pod
    let restart (client: PodmanClient) (name: string) : AsyncPodmanResult<unit> = async {
        let! result = HttpClient.postEmpty client (sprintf "/pods/%s/restart" name)
        return result |> Result.map ignore
    }

    /// Pause pod
    let pause (client: PodmanClient) (name: string) : AsyncPodmanResult<unit> = async {
        let! result = HttpClient.postEmpty client (sprintf "/pods/%s/pause" name)
        return result |> Result.map ignore
    }

    /// Unpause pod
    let unpause (client: PodmanClient) (name: string) : AsyncPodmanResult<unit> = async {
        let! result = HttpClient.postEmpty client (sprintf "/pods/%s/unpause" name)
        return result |> Result.map ignore
    }

    /// Kill pod
    let kill (client: PodmanClient) (name: string) (signal: string option) : AsyncPodmanResult<unit> = async {
        let query =
            match signal with
            | Some s -> sprintf "?signal=%s" s
            | None -> ""
        let! result = HttpClient.postEmpty client (sprintf "/pods/%s/kill%s" name query)
        return result |> Result.map ignore
    }

    /// Remove pod
    let remove (client: PodmanClient) (name: string) (force: bool) : AsyncPodmanResult<unit> = async {
        let query = sprintf "?force=%b" force
        return! HttpClient.delete client (sprintf "/pods/%s%s" name query)
    }

    // ========================================================================
    // Process Operations
    // ========================================================================

    /// Get processes in pod
    let top (client: PodmanClient) (name: string) : AsyncPodmanResult<string> =
        HttpClient.getRaw client (sprintf "/pods/%s/top" name)

    // ========================================================================
    // Stats Operations
    // ========================================================================

    /// Pod stats
    type PodStats = {
        Name: string
        Id: string
        CpuPercent: float
        MemoryUsage: int64
        MemoryLimit: int64
        ContainerCount: int
    }

    /// Get pod stats
    let stats (client: PodmanClient) (name: string) : AsyncPodmanResult<PodStats> = async {
        let! result = HttpClient.getRaw client (sprintf "/pods/%s/stats" name)
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                let root = doc.RootElement
                Ok {
                    Name = Serialization.getString "Name" "" root
                    Id = Serialization.getString "Id" "" root
                    CpuPercent = 0.0
                    MemoryUsage = 0L
                    MemoryLimit = 0L
                    ContainerCount = 0
                }
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    // ========================================================================
    // Convenience Operations
    // ========================================================================

    /// Create and start pod
    let createAndStart (client: PodmanClient) (spec: PodSpec) : AsyncPodmanResult<string> = async {
        let! createResult = create client spec
        match createResult with
        | Error e -> return Error e
        | Ok id ->
            let name = spec.Name |> Option.defaultValue id
            let! startResult = start client name
            match startResult with
            | Error e ->
                let! _ = remove client name true
                return Error e
            | Ok () -> return Ok id
    }

    /// Stop and remove pod
    let stopAndRemove (client: PodmanClient) (name: string) (timeout: int) : AsyncPodmanResult<unit> = async {
        let! _ = stop client name (Some timeout)
        return! remove client name true
    }

    /// Find pod by name
    let findByName (client: PodmanClient) (name: string) : AsyncPodmanResult<PodSummary option> = async {
        let! result = listAll client
        return result |> Result.map (fun pods ->
            pods |> List.tryFind (fun p -> p.Name = name)
        )
    }
