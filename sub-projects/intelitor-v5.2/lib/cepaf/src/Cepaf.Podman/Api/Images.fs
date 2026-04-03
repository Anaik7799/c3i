namespace Cepaf.Podman.Api

open System
open System.Text.Json
open Cepaf.Podman.Domain
open Cepaf.Podman.Client

/// Image management operations
module Images =

    // ========================================================================
    // List Operations
    // ========================================================================

    /// List images
    let list (client: PodmanClient) (all: bool) : AsyncPodmanResult<ImageSummary list> = async {
        let query = if all then "?all=true" else ""
        let! result = HttpClient.getRaw client (sprintf "/images/json%s" query)
        return result |> Result.bind Serialization.parseImageList
    }

    /// List all images (including intermediate)
    let listAll (client: PodmanClient) : AsyncPodmanResult<ImageSummary list> =
        list client true

    /// Check if image exists
    let exists (client: PodmanClient) (reference: string) : AsyncPodmanResult<bool> = async {
        let! result = HttpClient.getRaw client (sprintf "/images/%s/exists" (HttpClient.urlEncode reference))
        match result with
        | Ok _ -> return Ok true
        | Error (PodmanError.NotFound _) -> return Ok false
        | Error e -> return Error e
    }

    // ========================================================================
    // Inspect Operations
    // ========================================================================

    /// Inspect image
    let inspect (client: PodmanClient) (reference: string) : AsyncPodmanResult<ImageInspect> = async {
        let! result = HttpClient.getRaw client (sprintf "/images/%s/json" (HttpClient.urlEncode reference))
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                let root = doc.RootElement

                let history =
                    Serialization.getArray "History" root
                    |> List.map (fun h -> {
                        Id = Serialization.getString "Id" "" h
                        Created = Serialization.getInt64 "Created" 0L h |> Serialization.parseUnixTimestamp
                        CreatedBy = Serialization.getString "CreatedBy" "" h
                        Size = Serialization.getInt64 "Size" 0L h
                        Comment = Serialization.getString "Comment" "" h
                    })

                Ok {
                    Id = Serialization.getString "Id" "" root
                    RepoTags = Serialization.getStringArray "RepoTags" root
                    RepoDigests = Serialization.getStringArray "RepoDigests" root
                    Parent = Serialization.tryGetString "Parent" root
                    Comment = Serialization.getString "Comment" "" root
                    Created = Serialization.tryGetString "Created" root
                        |> Option.bind Serialization.parseDateTimeOffset
                        |> Option.defaultValue DateTimeOffset.MinValue
                    Author = Serialization.getString "Author" "" root
                    Architecture = Serialization.getString "Architecture" "" root
                    Os = Serialization.getString "Os" "linux" root
                    Size = Serialization.getInt64 "Size" 0L root
                    VirtualSize = Serialization.getInt64 "VirtualSize" 0L root
                    Labels = Serialization.getStringMap "Labels" root
                    History = history
                }
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    /// Get image history
    let history (client: PodmanClient) (reference: string) : AsyncPodmanResult<ImageHistoryLayer list> = async {
        let! result = HttpClient.getRaw client (sprintf "/images/%s/history" (HttpClient.urlEncode reference))
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                let layers =
                    [ for item in doc.RootElement.EnumerateArray() ->
                        {
                            Id = Serialization.getString "Id" "" item
                            Created = Serialization.getInt64 "Created" 0L item |> Serialization.parseUnixTimestamp
                            CreatedBy = Serialization.getString "CreatedBy" "" item
                            Size = Serialization.getInt64 "Size" 0L item
                            Comment = Serialization.getString "Comment" "" item
                        }
                    ]
                Ok layers
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    // ========================================================================
    // Pull Operations
    // ========================================================================

    /// Pull image from registry
    let pull (client: PodmanClient) (reference: string) : AsyncPodmanResult<string> = async {
        // Safety constraint: Only allow localhost/ registry
        if not (reference.StartsWith("localhost/")) then
            return Error (PodmanError.RegistryNotAllowed reference)
        else
            let query = sprintf "?reference=%s" (HttpClient.urlEncode reference)
            let! result = HttpClient.postEmpty client (sprintf "/images/pull%s" query)
            return result |> Result.bind (fun json ->
                try
                    // Parse streaming response - last line contains the ID
                    let lines = json.Split([| '\n' |], StringSplitOptions.RemoveEmptyEntries)
                    let lastLine = lines |> Array.tryLast |> Option.defaultValue "{}"
                    let doc = JsonDocument.Parse(lastLine)
                    Ok (Serialization.getString "id" reference doc.RootElement)
                with ex ->
                    Error (PodmanError.JsonParseError ex.Message)
            )
    }

    /// Pull image with policy
    let pullWithPolicy (client: PodmanClient) (reference: string) (policy: string) : AsyncPodmanResult<string> = async {
        if not (reference.StartsWith("localhost/")) then
            return Error (PodmanError.RegistryNotAllowed reference)
        else
            let query = sprintf "?reference=%s&policy=%s" (HttpClient.urlEncode reference) policy
            let! result = HttpClient.postEmpty client (sprintf "/images/pull%s" query)
            return result |> Result.bind (fun _ -> Ok reference)
    }

    // ========================================================================
    // Push Operations
    // ========================================================================

    /// Push image to registry
    let push (client: PodmanClient) (reference: string) (destination: string option) : AsyncPodmanResult<unit> = async {
        let dest = destination |> Option.defaultValue reference
        if not (dest.StartsWith("localhost/")) then
            return Error (PodmanError.RegistryNotAllowed dest)
        else
            let query =
                match destination with
                | Some d -> sprintf "?destination=%s" (HttpClient.urlEncode d)
                | None -> ""
            let! result = HttpClient.postEmpty client (sprintf "/images/%s/push%s" (HttpClient.urlEncode reference) query)
            return result |> Result.map ignore
    }

    // ========================================================================
    // Tag Operations
    // ========================================================================

    /// Tag image
    let tag (client: PodmanClient) (reference: string) (repo: string) (tag: string) : AsyncPodmanResult<unit> = async {
        let query = sprintf "?repo=%s&tag=%s" (HttpClient.urlEncode repo) (HttpClient.urlEncode tag)
        let! result = HttpClient.postEmpty client (sprintf "/images/%s/tag%s" (HttpClient.urlEncode reference) query)
        return result |> Result.map ignore
    }

    /// Untag image
    let untag (client: PodmanClient) (reference: string) : AsyncPodmanResult<unit> = async {
        let! result = HttpClient.postEmpty client (sprintf "/images/%s/untag" (HttpClient.urlEncode reference))
        return result |> Result.map ignore
    }

    // ========================================================================
    // Remove Operations
    // ========================================================================

    /// Remove image
    let remove (client: PodmanClient) (reference: string) (force: bool) : AsyncPodmanResult<unit> = async {
        let query = sprintf "?force=%b" force
        return! HttpClient.delete client (sprintf "/images/%s%s" (HttpClient.urlEncode reference) query)
    }

    /// Prune unused images
    let prune (client: PodmanClient) (all: bool) : AsyncPodmanResult<string list> = async {
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

    // ========================================================================
    // Build Operations
    // ========================================================================

    /// Build options
    type BuildOptions = {
        Dockerfile: string
        Tags: string list
        NoCache: bool
        Pull: bool
        Squash: bool
        Labels: Map<string, string>
        BuildArgs: Map<string, string>
    }

    module BuildOptions =
        let defaults = {
            Dockerfile = "Dockerfile"
            Tags = []
            NoCache = false
            Pull = false
            Squash = false
            Labels = Map.empty
            BuildArgs = Map.empty
        }

        let withTag tag opts = { opts with Tags = tag :: opts.Tags }
        let withNoCache opts = { opts with NoCache = true }
        let withPull opts = { opts with Pull = true }
        let withLabel key value opts = { opts with Labels = opts.Labels |> Map.add key value }
        let withBuildArg key value opts = { opts with BuildArgs = opts.BuildArgs |> Map.add key value }

    // Note: Full build implementation requires tar streaming which is complex
    // This is a placeholder for the API structure
    let build (client: PodmanClient) (contextPath: string) (options: BuildOptions) : AsyncPodmanResult<string> = async {
        // In a full implementation, this would:
        // 1. Create a tar archive of the context
        // 2. POST to /build with tar content
        // 3. Stream the build output
        // 4. Return the final image ID
        return Error (PodmanError.InternalError "Build not implemented - use podman build CLI")
    }

    // ========================================================================
    // Import/Export Operations
    // ========================================================================

    /// Import image from tar archive
    let import (client: PodmanClient) (tarPath: string) (reference: string option) : AsyncPodmanResult<string> = async {
        // Placeholder - requires file streaming
        return Error (PodmanError.InternalError "Import not implemented - use podman import CLI")
    }

    /// Export image to tar archive
    let export (client: PodmanClient) (reference: string) (outputPath: string) : AsyncPodmanResult<unit> = async {
        // Placeholder - requires file streaming
        return Error (PodmanError.InternalError "Export not implemented - use podman save CLI")
    }

    // ========================================================================
    // Search Operations
    // ========================================================================

    /// Search result
    type SearchResult = {
        Name: string
        Description: string
        Stars: int
        Official: bool
        Automated: bool
    }

    /// Search for images (only works with remote registries)
    let search (client: PodmanClient) (term: string) (limit: int option) : AsyncPodmanResult<SearchResult list> = async {
        let query =
            match limit with
            | Some l -> sprintf "?term=%s&limit=%d" (HttpClient.urlEncode term) l
            | None -> sprintf "?term=%s" (HttpClient.urlEncode term)
        let! result = HttpClient.getRaw client (sprintf "/images/search%s" query)
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                let results =
                    [ for item in doc.RootElement.EnumerateArray() ->
                        {
                            Name = Serialization.getString "Name" "" item
                            Description = Serialization.getString "Description" "" item
                            Stars = Serialization.getInt "Stars" 0 item
                            Official = Serialization.getBool "Official" false item
                            Automated = Serialization.getBool "Automated" false item
                        }
                    ]
                Ok results
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    // ========================================================================
    // Convenience Operations
    // ========================================================================

    /// Find image by reference (partial match)
    let findByReference (client: PodmanClient) (reference: string) : AsyncPodmanResult<ImageSummary option> = async {
        let! result = listAll client
        return result |> Result.map (fun images ->
            images |> List.tryFind (fun i ->
                i.RepoTags |> List.exists (fun t -> t.Contains(reference)) ||
                i.Id.StartsWith(reference)
            )
        )
    }

    /// Ensure image exists, pull if not
    let ensureExists (client: PodmanClient) (reference: string) : AsyncPodmanResult<string> = async {
        let! existsResult = exists client reference
        match existsResult with
        | Error e -> return Error e
        | Ok true -> return Ok reference
        | Ok false -> return! pull client reference
    }
