namespace Cepaf.Podman.Api

open System
open System.Text.Json
open Cepaf.Podman.Domain
open Cepaf.Podman.Client

/// Volume management operations
module Volumes =

    // ========================================================================
    // List Operations
    // ========================================================================

    /// List volumes
    let list (client: PodmanClient) : AsyncPodmanResult<Volume list> = async {
        let! result = HttpClient.getRaw client "/volumes/json"
        return result |> Result.bind Serialization.parseVolumeList
    }

    /// Check if volume exists
    let exists (client: PodmanClient) (name: string) : AsyncPodmanResult<bool> = async {
        let! result = HttpClient.getRaw client (sprintf "/volumes/%s/exists" (HttpClient.urlEncode name))
        match result with
        | Ok _ -> return Ok true
        | Error (PodmanError.NotFound _) -> return Ok false
        | Error e -> return Error e
    }

    // ========================================================================
    // Inspect Operations
    // ========================================================================

    /// Inspect volume
    let inspect (client: PodmanClient) (name: string) : AsyncPodmanResult<Volume> = async {
        let! result = HttpClient.getRaw client (sprintf "/volumes/%s/json" (HttpClient.urlEncode name))
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                Ok (Serialization.parseVolume doc.RootElement)
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    // ========================================================================
    // Lifecycle Operations
    // ========================================================================

    /// Create volume
    let create (client: PodmanClient) (spec: VolumeSpec) : AsyncPodmanResult<Volume> = async {
        let json = Serialization.serializeVolumeSpec spec
        let! result = HttpClient.postJson client "/volumes/create" json
        return result |> Result.bind (fun responseJson ->
            try
                let doc = JsonDocument.Parse(responseJson)
                Ok (Serialization.parseVolume doc.RootElement)
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    /// Create volume with name only
    let createNamed (client: PodmanClient) (name: string) : AsyncPodmanResult<Volume> =
        let spec = VolumeSpec.create name
        create client spec

    /// Remove volume
    let remove (client: PodmanClient) (name: string) (force: bool) : AsyncPodmanResult<unit> = async {
        let query = sprintf "?force=%b" force
        return! HttpClient.delete client (sprintf "/volumes/%s%s" (HttpClient.urlEncode name) query)
    }

    /// Prune unused volumes
    let prune (client: PodmanClient) : AsyncPodmanResult<string list> = async {
        let! result = HttpClient.postEmpty client "/volumes/prune"
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                Ok (Serialization.getStringArray "VolumesDeleted" doc.RootElement)
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    // ========================================================================
    // Update Operations
    // ========================================================================

    /// Volume usage info
    type VolumeUsage = {
        Name: string
        Size: int64
        RefCount: int
        Links: string list
    }

    /// Get volume usage
    let usage (client: PodmanClient) (name: string) : AsyncPodmanResult<VolumeUsage> = async {
        let! result = inspect client name
        return result |> Result.map (fun v -> {
            Name = v.Name
            Size = 0L  // Would need to calculate from mountpoint
            RefCount = 0
            Links = []
        })
    }

    // ========================================================================
    // Convenience Operations
    // ========================================================================

    /// Find volume by name
    let findByName (client: PodmanClient) (name: string) : AsyncPodmanResult<Volume option> = async {
        let! result = list client
        return result |> Result.map (fun volumes ->
            volumes |> List.tryFind (fun v -> v.Name = name)
        )
    }

    /// Ensure volume exists, create if not
    let ensureExists (client: PodmanClient) (name: string) : AsyncPodmanResult<Volume> = async {
        let! existsResult = exists client name
        match existsResult with
        | Error e -> return Error e
        | Ok true -> return! inspect client name
        | Ok false -> return! createNamed client name
    }

    /// Create volume with driver options
    let createWithDriver (client: PodmanClient) (name: string) (driver: string) (options: Map<string, string>) : AsyncPodmanResult<Volume> =
        let spec =
            VolumeSpec.create name
            |> VolumeSpec.withDriver (VolumeDriver.parse driver)
            |> fun s -> { s with Options = options }
        create client spec

    /// Create tmpfs volume
    let createTmpfs (client: PodmanClient) (name: string) (size: string) : AsyncPodmanResult<Volume> =
        let options = Map.ofList [("size", size); ("type", "tmpfs")]
        createWithDriver client name "tmpfs" options

    /// Remove volume if exists
    let removeIfExists (client: PodmanClient) (name: string) : AsyncPodmanResult<unit> = async {
        let! existsResult = exists client name
        match existsResult with
        | Error e -> return Error e
        | Ok false -> return Ok ()
        | Ok true -> return! remove client name true
    }

    /// List volumes with label filter
    let listWithLabel (client: PodmanClient) (label: string) : AsyncPodmanResult<Volume list> = async {
        let query = sprintf "?filters={\"label\":[\"%s\"]}" (HttpClient.urlEncode label)
        let! result = HttpClient.getRaw client (sprintf "/volumes/json%s" query)
        return result |> Result.bind Serialization.parseVolumeList
    }

    /// Get all volume names
    let listNames (client: PodmanClient) : AsyncPodmanResult<string list> = async {
        let! result = list client
        return result |> Result.map (List.map (fun v -> v.Name))
    }

    // ========================================================================
    // Backup Operations
    // ========================================================================

    /// Export volume to tar (placeholder - requires streaming)
    let export (client: PodmanClient) (name: string) (outputPath: string) : AsyncPodmanResult<unit> = async {
        // Note: Full implementation requires tar streaming
        return Error (PodmanError.InternalError "Export not implemented - use podman volume export CLI")
    }

    /// Import volume from tar (placeholder - requires streaming)
    let import (client: PodmanClient) (name: string) (tarPath: string) : AsyncPodmanResult<unit> = async {
        // Note: Full implementation requires tar streaming
        return Error (PodmanError.InternalError "Import not implemented - use podman volume import CLI")
    }

