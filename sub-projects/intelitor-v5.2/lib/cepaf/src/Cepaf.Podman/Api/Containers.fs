namespace Cepaf.Podman.Api

open System
open System.Text.Json
open Cepaf.Podman.Domain
open Cepaf.Podman.Client

/// Container management operations
module Containers =

    // ========================================================================
    // List Operations
    // ========================================================================

    /// Container list filters
    type ListFilters = {
        All: bool
        Limit: int option
        Status: ContainerStatus list
        Label: string list
        Name: string list
        Id: string list
    }

    module ListFilters =
        let empty = {
            All = false
            Limit = None
            Status = []
            Label = []
            Name = []
            Id = []
        }

        let all filters = { filters with All = true }
        let withLimit limit filters = { filters with Limit = Some limit }
        let withStatus status filters = { filters with Status = status :: filters.Status }
        let withLabel label filters = { filters with Label = label :: filters.Label }
        let withName name filters = { filters with Name = name :: filters.Name }
        let withId id filters = { filters with Id = id :: filters.Id }

        let toQueryString (filters: ListFilters) : string =
            let parts = [
                if filters.All then yield "all=true"
                match filters.Limit with
                | Some l -> yield sprintf "limit=%d" l
                | None -> ()
                if not filters.Status.IsEmpty then
                    for s in filters.Status do
                        yield sprintf "filters={\"status\":[\"%s\"]}"
                            (match s with
                             | ContainerStatus.Running -> "running"
                             | ContainerStatus.Exited _ -> "exited"
                             | ContainerStatus.Created -> "created"
                             | ContainerStatus.Paused -> "paused"
                             | _ -> "")
                for l in filters.Label do
                    yield sprintf "filters={\"label\":[\"%s\"]}" (HttpClient.urlEncode l)
                for n in filters.Name do
                    yield sprintf "filters={\"name\":[\"%s\"]}" (HttpClient.urlEncode n)
            ]
            if parts.IsEmpty then ""
            else "?" + String.concat "&" parts

    /// List containers
    let list (client: PodmanClient) (filters: ListFilters) : AsyncPodmanResult<ContainerSummary list> = async {
        let query = ListFilters.toQueryString filters
        let! result = HttpClient.getRaw client (sprintf "/containers/json%s" query)
        return result |> Result.bind Serialization.parseContainerList
    }

    /// List all containers (running and stopped)
    let listAll (client: PodmanClient) : AsyncPodmanResult<ContainerSummary list> =
        list client { ListFilters.empty with All = true }

    /// List running containers
    let listRunning (client: PodmanClient) : AsyncPodmanResult<ContainerSummary list> =
        list client ListFilters.empty

    /// Check if container exists
    let exists (client: PodmanClient) (id: string) : AsyncPodmanResult<bool> = async {
        let! result = HttpClient.getRaw client (sprintf "/containers/%s/exists" id)
        match result with
        | Ok _ -> return Ok true
        | Error (PodmanError.NotFound _) -> return Ok false
        | Error e -> return Error e
    }

    // ========================================================================
    // Inspect Operations
    // ========================================================================

    /// Inspect container
    let inspect (client: PodmanClient) (id: string) : AsyncPodmanResult<ContainerInspect> = async {
        let! result = HttpClient.getRaw client (sprintf "/containers/%s/json" id)
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                Ok (Serialization.parseContainerInspect doc.RootElement)
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    /// Get container state
    let getState (client: PodmanClient) (id: string) : AsyncPodmanResult<ContainerStatus> = async {
        let! result = inspect client id
        return result |> Result.map (fun c -> c.State.Status)
    }

    /// Check if container is running
    let isRunning (client: PodmanClient) (id: string) : AsyncPodmanResult<bool> = async {
        let! result = inspect client id
        return result |> Result.map (fun c -> c.State.Running)
    }

    // ========================================================================
    // Lifecycle Operations
    // ========================================================================

    /// Create container
    let create (client: PodmanClient) (spec: ContainerSpec) : AsyncPodmanResult<string> = async {
        let json = Serialization.serializeContainerSpec spec
        let query =
            match spec.Name with
            | Some name -> sprintf "?name=%s" (HttpClient.urlEncode name)
            | None -> ""
        let! result = HttpClient.postJson client (sprintf "/containers/create%s" query) json
        return result |> Result.bind Serialization.parseCreateResponse
    }

    /// Start container
    let start (client: PodmanClient) (id: string) : AsyncPodmanResult<unit> = async {
        let! result = HttpClient.postEmpty client (sprintf "/containers/%s/start" id)
        return result |> Result.map ignore
    }

    /// Stop container
    let stop (client: PodmanClient) (id: string) (timeout: int option) : AsyncPodmanResult<unit> = async {
        let query =
            match timeout with
            | Some t -> sprintf "?timeout=%d" t
            | None -> ""
        let! result = HttpClient.postEmpty client (sprintf "/containers/%s/stop%s" id query)
        return result |> Result.map ignore
    }

    /// Restart container
    let restart (client: PodmanClient) (id: string) (timeout: int option) : AsyncPodmanResult<unit> = async {
        let query =
            match timeout with
            | Some t -> sprintf "?timeout=%d" t
            | None -> ""
        let! result = HttpClient.postEmpty client (sprintf "/containers/%s/restart%s" id query)
        return result |> Result.map ignore
    }

    /// Kill container with signal
    let kill (client: PodmanClient) (id: string) (signal: string option) : AsyncPodmanResult<unit> = async {
        let query =
            match signal with
            | Some s -> sprintf "?signal=%s" s
            | None -> ""
        let! result = HttpClient.postEmpty client (sprintf "/containers/%s/kill%s" id query)
        return result |> Result.map ignore
    }

    /// Pause container
    let pause (client: PodmanClient) (id: string) : AsyncPodmanResult<unit> = async {
        let! result = HttpClient.postEmpty client (sprintf "/containers/%s/pause" id)
        return result |> Result.map ignore
    }

    /// Unpause container
    let unpause (client: PodmanClient) (id: string) : AsyncPodmanResult<unit> = async {
        let! result = HttpClient.postEmpty client (sprintf "/containers/%s/unpause" id)
        return result |> Result.map ignore
    }

    /// Remove container
    let remove (client: PodmanClient) (id: string) (force: bool) (volumes: bool) : AsyncPodmanResult<unit> = async {
        let query = sprintf "?force=%b&v=%b" force volumes
        return! HttpClient.delete client (sprintf "/containers/%s%s" id query)
    }

    /// Rename container
    let rename (client: PodmanClient) (id: string) (newName: string) : AsyncPodmanResult<unit> = async {
        let query = sprintf "?name=%s" (HttpClient.urlEncode newName)
        let! result = HttpClient.postEmpty client (sprintf "/containers/%s/rename%s" id query)
        return result |> Result.map ignore
    }

    // ========================================================================
    // Wait Operations
    // ========================================================================

    /// Wait condition
    [<RequireQualifiedAccess>]
    type WaitCondition =
        | NotRunning
        | NextExit
        | Removed
        | Stopped

    module WaitCondition =
        let toString = function
            | WaitCondition.NotRunning -> "not-running"
            | WaitCondition.NextExit -> "next-exit"
            | WaitCondition.Removed -> "removed"
            | WaitCondition.Stopped -> "stopped"

    /// Wait for container
    let wait (client: PodmanClient) (id: string) (condition: WaitCondition) : AsyncPodmanResult<int> = async {
        let query = sprintf "?condition=%s" (WaitCondition.toString condition)
        let! result = HttpClient.postEmpty client (sprintf "/containers/%s/wait%s" id query)
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                Ok (Serialization.getInt "StatusCode" 0 doc.RootElement)
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    /// Wait for container to stop
    let waitForStop (client: PodmanClient) (id: string) : AsyncPodmanResult<int> =
        wait client id WaitCondition.Stopped

    // ========================================================================
    // Logs Operations
    // ========================================================================

    /// Log options
    type LogOptions = {
        Follow: bool
        Stdout: bool
        Stderr: bool
        Timestamps: bool
        Tail: int option
        Since: DateTimeOffset option
        Until: DateTimeOffset option
    }

    module LogOptions =
        let defaults = {
            Follow = false
            Stdout = true
            Stderr = true
            Timestamps = false
            Tail = None
            Since = None
            Until = None
        }

        let follow opts = { opts with Follow = true }
        let withTail n opts = { opts with Tail = Some n }
        let withTimestamps opts = { opts with Timestamps = true }
        let since dt opts = { opts with Since = Some dt }

        let toQueryString (opts: LogOptions) : string =
            let parts = [
                sprintf "follow=%b" opts.Follow
                sprintf "stdout=%b" opts.Stdout
                sprintf "stderr=%b" opts.Stderr
                sprintf "timestamps=%b" opts.Timestamps
                match opts.Tail with Some t -> sprintf "tail=%d" t | None -> ()
                match opts.Since with Some s -> sprintf "since=%d" (s.ToUnixTimeSeconds()) | None -> ()
                match opts.Until with Some u -> sprintf "until=%d" (u.ToUnixTimeSeconds()) | None -> ()
            ]
            "?" + String.concat "&" parts

    /// Get container logs
    let logs (client: PodmanClient) (id: string) (options: LogOptions) : AsyncPodmanResult<string> = async {
        let query = LogOptions.toQueryString options
        return! HttpClient.getRaw client (sprintf "/containers/%s/logs%s" id query)
    }

    /// Get last N lines of container logs
    let logsLast (client: PodmanClient) (id: string) (lines: int) : AsyncPodmanResult<string> =
        logs client id { LogOptions.defaults with Tail = Some lines }

    // ========================================================================
    // Exec Operations
    // ========================================================================

    /// Execute command in container
    let exec (client: PodmanClient) (id: string) (cmd: string list) (detach: bool) : AsyncPodmanResult<string> = async {
        let cmdJson = cmd |> List.map (sprintf "\"%s\"") |> String.concat ","
        let execBody = sprintf "{\"Cmd\":[%s],\"AttachStdout\":%b,\"AttachStderr\":%b,\"Detach\":%b}" cmdJson (not detach) (not detach) detach

        let! createResult = HttpClient.postJson client (sprintf "/containers/%s/exec" id) execBody
        match createResult |> Result.bind Serialization.parseCreateResponse with
        | Error e -> return Error e
        | Ok execId ->
            let startBody = sprintf "{\"Detach\":%b}" detach
            let! startResult = HttpClient.postJson client (sprintf "/exec/%s/start" execId) startBody
            return startResult
    }

    /// Execute command and wait for output
    let execWait (client: PodmanClient) (id: string) (cmd: string list) : AsyncPodmanResult<string> =
        exec client id cmd false

    /// Execute command detached
    let execDetached (client: PodmanClient) (id: string) (cmd: string list) : AsyncPodmanResult<unit> = async {
        let! result = exec client id cmd true
        return result |> Result.map ignore
    }

    // ========================================================================
    // Stats Operations
    // ========================================================================

    /// Container stats
    type ContainerStats = {
        Id: string
        Name: string
        CpuPercent: float
        MemoryUsage: int64
        MemoryLimit: int64
        MemoryPercent: float
        NetworkRx: int64
        NetworkTx: int64
        BlockRead: int64
        BlockWrite: int64
        Pids: int
    }

    /// Get container stats (one-shot)
    let stats (client: PodmanClient) (id: string) : AsyncPodmanResult<ContainerStats> = async {
        let! result = HttpClient.getRaw client (sprintf "/containers/%s/stats?stream=false" id)
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                let root = doc.RootElement

                let cpuStats =
                    match root.TryGetProperty("cpu_stats") with
                    | true, cs -> cs
                    | false, _ -> root

                let memStats =
                    match root.TryGetProperty("memory_stats") with
                    | true, ms -> ms
                    | false, _ -> root

                Ok {
                    Id = Serialization.getString "id" "" root
                    Name = Serialization.getString "name" "" root
                    CpuPercent = 0.0  // Calculated from cpu_stats
                    MemoryUsage = Serialization.getInt64 "usage" 0L memStats
                    MemoryLimit = Serialization.getInt64 "limit" 0L memStats
                    MemoryPercent = 0.0
                    NetworkRx = 0L
                    NetworkTx = 0L
                    BlockRead = 0L
                    BlockWrite = 0L
                    Pids = Serialization.getInt "current" 0
                        (match root.TryGetProperty("pids_stats") with true, ps -> ps | false, _ -> root)
                }
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    // ========================================================================
    // Health Check Operations
    // ========================================================================

    /// Run health check on container
    let healthCheck (client: PodmanClient) (id: string) : AsyncPodmanResult<HealthStatus> = async {
        let! result = HttpClient.getRaw client (sprintf "/containers/%s/healthcheck" id)
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                let status = Serialization.getString "Status" "unknown" doc.RootElement
                Ok (HealthStatus.parse status)
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    // ========================================================================
    // Convenience Operations
    // ========================================================================

    /// Create and start container
    let createAndStart (client: PodmanClient) (spec: ContainerSpec) : AsyncPodmanResult<string> = async {
        let! createResult = create client spec
        match createResult with
        | Error e -> return Error e
        | Ok id ->
            let! startResult = start client id
            match startResult with
            | Error e ->
                // Clean up on failure
                let! _ = remove client id true false
                return Error e
            | Ok () -> return Ok id
    }

    /// Stop and remove container
    let stopAndRemove (client: PodmanClient) (id: string) (timeout: int) : AsyncPodmanResult<unit> = async {
        let! _ = stop client id (Some timeout)
        return! remove client id true false
    }

    /// Find container by name
    let findByName (client: PodmanClient) (name: string) : AsyncPodmanResult<ContainerSummary option> = async {
        let! result = list client { ListFilters.empty with All = true; Name = [name] }
        return result |> Result.map (fun containers ->
            containers
            |> List.tryFind (fun c -> c.Names |> List.exists (fun n -> n = name || n = "/" + name))
        )
    }
