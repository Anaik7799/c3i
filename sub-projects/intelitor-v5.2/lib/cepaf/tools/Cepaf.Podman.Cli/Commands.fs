namespace Cepaf.Podman.Cli

open System
open System.Text.Json
open Cepaf.Podman.Domain
open Cepaf.Podman.Client
open Cepaf.Podman.Api
open Cepaf.Podman.Health
open Cepaf.Podman.Safety

/// CLI command implementations for CepafPort integration
/// Supports JSON output format for Elixir port communication
module Commands =

    // ========================================================================
    // Client Creation
    // ========================================================================

    /// Create Podman client with error handling
    let private createClient (socketPath: string option) : PodmanResult<PodmanClient> =
        match socketPath with
        | Some path -> HttpClient.createWithSocket path
        | None -> HttpClient.createDefault ()

    // ========================================================================
    // JSON Response Types
    // ========================================================================

    /// Container summary for JSON output
    type ContainerJsonSummary = {
        Id: string
        Names: string list
        Image: string
        Status: string
        State: string
        Created: string
        Ports: obj list
        Labels: Map<string, string>
    }

    /// Container inspect for JSON output
    type ContainerJsonInspect = {
        Id: string
        Name: string
        Image: string
        State: {|
            Status: string
            Running: bool
            Paused: bool
            Pid: int
            ExitCode: int
            StartedAt: string option
            FinishedAt: string option
            Health: string option
        |}
        Config: {|
            Env: Map<string, string>
            Labels: Map<string, string>
            Cmd: string list
        |}
        Mounts: obj list
        NetworkSettings: obj
    }

    /// Health summary for JSON output
    type HealthJsonSummary = {
        Total: int
        Healthy: int
        Unhealthy: int
        Starting: int
        NoHealthcheck: int
        Timestamp: string
    }

    /// Health check result for JSON output
    type HealthJsonCheck = {
        ContainerId: string
        ContainerName: string
        Status: string
        Message: string option
        Timestamp: string
        DurationMs: int64
    }

    /// System info for JSON output
    type SystemJsonInfo = {
        Version: {|
            Version: string
            ApiVersion: string
            GoVersion: string
            GitCommit: string
            OsArch: string
        |}
        Host: {|
            Hostname: string
            Os: string
            Arch: string
            Kernel: string
            CpuCount: int
            MemTotal: int64
            MemFree: int64
        |}
        Storage: {|
            Driver: string
            GraphRoot: string
            RunRoot: string
            ImageCount: int
            ContainerCount: int
        |}
        Runtime: {|
            Name: string
            Path: string
            Version: string option
        |}
    }

    /// Container stats for JSON output
    type ContainerJsonStats = {
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

    // ========================================================================
    // Conversion Helpers
    // ========================================================================

    let private containerStatusToString (status: ContainerStatus) : string =
        match status with
        | ContainerStatus.Running -> "running"
        | ContainerStatus.Exited code -> sprintf "exited(%d)" code
        | ContainerStatus.Created -> "created"
        | ContainerStatus.Paused -> "paused"
        | ContainerStatus.Dead _ -> "dead"
        | ContainerStatus.Restarting -> "restarting"
        | ContainerStatus.Removing -> "removing"
        | ContainerStatus.Unknown s -> s

    let private healthStatusToString (status: HealthStatus) : string =
        match status with
        | HealthStatus.Healthy -> "healthy"
        | HealthStatus.Unhealthy _ -> "unhealthy"
        | HealthStatus.Starting -> "starting"
        | HealthStatus.NoHealthcheck -> "none"
        | HealthStatus.Unknown s -> s

    let private toContainerJsonSummary (c: ContainerSummary) : ContainerJsonSummary =
        {
            Id = c.Id
            Names = c.Names
            Image = c.Image
            Status = containerStatusToString c.State
            State = containerStatusToString c.State
            Created = c.Created.ToString("o")
            Ports = []  // Simplified for now
            Labels = c.Labels
        }

    let private toContainerJsonInspect (c: ContainerInspect) : ContainerJsonInspect =
        {
            Id = c.Id
            Name = c.Name
            Image = c.Image
            State = {|
                Status = containerStatusToString c.State.Status
                Running = c.State.Running
                Paused = c.State.Paused
                Pid = c.State.Pid
                ExitCode = c.State.ExitCode
                StartedAt = c.State.StartedAt |> Option.map (fun d -> d.ToString("o"))
                FinishedAt = c.State.FinishedAt |> Option.map (fun d -> d.ToString("o"))
                Health = c.State.Health |> Option.map (fun h -> healthStatusToString h.Status)
            |}
            Config = {|
                Env = c.Env
                Labels = c.Labels
                Cmd = c.Args
            |}
            Mounts = []  // Simplified
            NetworkSettings = {| Networks = Map.empty |}
        }

    let private toHealthJsonSummary (s: Probes.HealthSummary) : HealthJsonSummary =
        {
            Total = s.Total
            Healthy = s.Healthy
            Unhealthy = s.Unhealthy
            Starting = s.Starting
            NoHealthcheck = s.NoHealthCheck
            Timestamp = s.Timestamp.ToString("o")
        }

    let private toHealthJsonCheck (p: Probes.ProbeResult) : HealthJsonCheck =
        {
            ContainerId = p.ContainerId
            ContainerName = p.ContainerName
            Status = healthStatusToString p.Status
            Message = p.Message
            Timestamp = p.Timestamp.ToString("o")
            DurationMs = int64 p.Duration.TotalMilliseconds
        }

    let private toSystemJsonInfo (info: SystemInfo) : SystemJsonInfo =
        {
            Version = {|
                Version = info.Version.Version
                ApiVersion = info.Version.ApiVersion
                GoVersion = info.Version.GoVersion
                GitCommit = info.Version.GitCommit
                OsArch = info.Version.OsArch
            |}
            Host = {|
                Hostname = info.Host.Hostname
                Os = info.Host.Os
                Arch = info.Host.Arch
                Kernel = info.Host.Kernel
                CpuCount = info.Host.CpuCount
                MemTotal = info.Host.MemTotal
                MemFree = info.Host.MemFree
            |}
            Storage = {|
                Driver = info.Storage.Driver
                GraphRoot = info.Storage.GraphRoot
                RunRoot = info.Storage.RunRoot
                ImageCount = info.Storage.ImageCount
                ContainerCount = info.Storage.ContainerCount
            |}
            Runtime = {|
                Name = info.Runtime.Name
                Path = info.Runtime.Path
                Version = info.Runtime.Version
            |}
        }

    let private toContainerJsonStats (s: Containers.ContainerStats) : ContainerJsonStats =
        {
            Id = s.Id
            Name = s.Name
            CpuPercent = s.CpuPercent
            MemoryUsage = s.MemoryUsage
            MemoryLimit = s.MemoryLimit
            MemoryPercent = s.MemoryPercent
            NetworkRx = s.NetworkRx
            NetworkTx = s.NetworkTx
            BlockRead = s.BlockRead
            BlockWrite = s.BlockWrite
            Pids = s.Pids
        }

    // ========================================================================
    // Container Commands
    // ========================================================================

    /// List containers (containers list)
    let containersListJson (socketPath: string option) (all: bool) (labels: string list) : int =
        match createClient socketPath with
        | Error e ->
            Console.writeJsonError (PodmanError.toMessage e) 1
            1
        | Ok client ->
            try
                let filters =
                    let base' = if all then Containers.ListFilters.empty |> Containers.ListFilters.all else Containers.ListFilters.empty
                    labels |> List.fold (fun f l -> Containers.ListFilters.withLabel l f) base'

                let result = Containers.list client filters |> Async.RunSynchronously

                match result with
                | Error e ->
                    Console.writeJsonError (PodmanError.toMessage e) 1
                    1
                | Ok containers ->
                    let jsonContainers = containers |> List.map toContainerJsonSummary
                    Console.writeJson jsonContainers
                    0
            finally
                HttpClient.dispose client

    /// List containers with text output
    let containersList (socketPath: string option) (all: bool) (labels: string list) (format: Console.OutputFormat) : int =
        match format with
        | Console.OutputFormat.Json -> containersListJson socketPath all labels
        | Console.OutputFormat.Text ->
            match createClient socketPath with
            | Error e ->
                Console.error (PodmanError.toMessage e)
                1
            | Ok client ->
                try
                    let filters =
                        let base' = if all then Containers.ListFilters.empty |> Containers.ListFilters.all else Containers.ListFilters.empty
                        labels |> List.fold (fun f l -> Containers.ListFilters.withLabel l f) base'

                    let result = Containers.list client filters |> Async.RunSynchronously

                    match result with
                    | Error e ->
                        Console.error (PodmanError.toMessage e)
                        1
                    | Ok containers ->
                        if containers.IsEmpty then
                            Console.info "No containers found"
                        else
                            Console.header "CONTAINERS"
                            Console.WriteLine("")

                            let columns = [
                                Console.col "CONTAINER ID" 14
                                Console.col "IMAGE" 30
                                Console.col "COMMAND" 20
                                Console.col "CREATED" 15
                                Console.col "STATUS" 12
                                Console.col "NAMES" 20
                            ]

                            Console.printTableHeader columns

                            for c in containers do
                                let status = Console.printContainerStatus (containerStatusToString c.State)

                                let values = [
                                    Console.truncateId c.Id
                                    if c.Image.Length > 30 then c.Image.Substring(0, 27) + "..." else c.Image
                                    if c.Command.Length > 20 then c.Command.Substring(0, 17) + "..." else c.Command
                                    Console.formatRelativeTime c.Created
                                    status
                                    Console.formatNames c.Names
                                ]

                                Console.printTableRow columns values

                            Console.WriteLine("")
                            Console.dim (sprintf "Total: %d container(s)" containers.Length)
                        0
                finally
                    HttpClient.dispose client

    /// Inspect container (containers inspect)
    let containersInspect (socketPath: string option) (containerId: string) (format: Console.OutputFormat) : int =
        match createClient socketPath with
        | Error e ->
            match format with
            | Console.OutputFormat.Json -> Console.writeJsonError (PodmanError.toMessage e) 1
            | Console.OutputFormat.Text -> Console.error (PodmanError.toMessage e)
            1
        | Ok client ->
            try
                let result = Containers.inspect client containerId |> Async.RunSynchronously

                match result with
                | Error e ->
                    match format with
                    | Console.OutputFormat.Json -> Console.writeJsonError (PodmanError.toMessage e) 1
                    | Console.OutputFormat.Text -> Console.error (PodmanError.toMessage e)
                    1
                | Ok container ->
                    match format with
                    | Console.OutputFormat.Json ->
                        Console.writeJson (toContainerJsonInspect container)
                        0
                    | Console.OutputFormat.Text ->
                        Console.header "CONTAINER DETAILS"
                        Console.WriteLine("")
                        Console.info (sprintf "ID: %s" container.Id)
                        Console.info (sprintf "Name: %s" container.Name)
                        Console.info (sprintf "Image: %s" container.Image)
                        Console.info (sprintf "Status: %s" (containerStatusToString container.State.Status))
                        Console.info (sprintf "Running: %b" container.State.Running)
                        0
            finally
                HttpClient.dispose client

    /// Get container logs (containers logs)
    let containersLogs (socketPath: string option) (containerId: string) (tail: int option) (timestamps: bool) : int =
        match createClient socketPath with
        | Error e ->
            Console.error (PodmanError.toMessage e)
            1
        | Ok client ->
            try
                let options =
                    Containers.LogOptions.defaults
                    |> (match tail with Some n -> Containers.LogOptions.withTail n | None -> id)
                    |> (if timestamps then Containers.LogOptions.withTimestamps else id)

                let result = Containers.logs client containerId options |> Async.RunSynchronously

                match result with
                | Error e ->
                    Console.error (PodmanError.toMessage e)
                    1
                | Ok logs ->
                    // Output logs directly (not JSON formatted for logs)
                    Console.WriteLine(logs)
                    0
            finally
                HttpClient.dispose client

    /// Get container stats (containers stats)
    let containersStats (socketPath: string option) (containerId: string) (format: Console.OutputFormat) : int =
        match createClient socketPath with
        | Error e ->
            match format with
            | Console.OutputFormat.Json -> Console.writeJsonError (PodmanError.toMessage e) 1
            | Console.OutputFormat.Text -> Console.error (PodmanError.toMessage e)
            1
        | Ok client ->
            try
                let result = Containers.stats client containerId |> Async.RunSynchronously

                match result with
                | Error e ->
                    match format with
                    | Console.OutputFormat.Json -> Console.writeJsonError (PodmanError.toMessage e) 1
                    | Console.OutputFormat.Text -> Console.error (PodmanError.toMessage e)
                    1
                | Ok stats ->
                    match format with
                    | Console.OutputFormat.Json ->
                        Console.writeJson (toContainerJsonStats stats)
                        0
                    | Console.OutputFormat.Text ->
                        Console.header "CONTAINER STATS"
                        Console.WriteLine("")
                        Console.info (sprintf "ID: %s" stats.Id)
                        Console.info (sprintf "Name: %s" stats.Name)
                        Console.info (sprintf "CPU: %.2f%%" stats.CpuPercent)
                        Console.info (sprintf "Memory: %s / %s" (Console.formatBytes stats.MemoryUsage) (Console.formatBytes stats.MemoryLimit))
                        Console.info (sprintf "PIDs: %d" stats.Pids)
                        0
            finally
                HttpClient.dispose client

    // ========================================================================
    // Health Commands
    // ========================================================================

    /// Health summary (health summary)
    let healthSummary (socketPath: string option) (format: Console.OutputFormat) : int =
        match createClient socketPath with
        | Error e ->
            match format with
            | Console.OutputFormat.Json -> Console.writeJsonError (PodmanError.toMessage e) 1
            | Console.OutputFormat.Text -> Console.error (PodmanError.toMessage e)
            1
        | Ok client ->
            try
                let result = Probes.getSummary client |> Async.RunSynchronously

                match result with
                | Error e ->
                    match format with
                    | Console.OutputFormat.Json -> Console.writeJsonError (PodmanError.toMessage e) 1
                    | Console.OutputFormat.Text -> Console.error (PodmanError.toMessage e)
                    1
                | Ok summary ->
                    match format with
                    | Console.OutputFormat.Json ->
                        Console.writeJson (toHealthJsonSummary summary)
                        0
                    | Console.OutputFormat.Text ->
                        Console.header "HEALTH SUMMARY"
                        Console.WriteLine("")
                        Console.printStatus "ok" (sprintf "Healthy: %d" summary.Healthy)
                        Console.printStatus (if summary.Unhealthy > 0 then "error" else "ok")
                            (sprintf "Unhealthy: %d" summary.Unhealthy)
                        Console.printStatus (if summary.Starting > 0 then "warning" else "ok")
                            (sprintf "Starting: %d" summary.Starting)
                        Console.printStatus "warning" (sprintf "No healthcheck: %d" summary.NoHealthCheck)
                        Console.WriteLine("")
                        Console.dim (sprintf "Total containers: %d" summary.Total)
                        if summary.Unhealthy > 0 then 1 else 0
            finally
                HttpClient.dispose client

    /// Health check for specific container (health check ID)
    let healthCheck (socketPath: string option) (containerId: string) (format: Console.OutputFormat) : int =
        match createClient socketPath with
        | Error e ->
            match format with
            | Console.OutputFormat.Json -> Console.writeJsonError (PodmanError.toMessage e) 1
            | Console.OutputFormat.Text -> Console.error (PodmanError.toMessage e)
            1
        | Ok client ->
            try
                let result = Probes.check client containerId |> Async.RunSynchronously

                match result with
                | Error e ->
                    match format with
                    | Console.OutputFormat.Json -> Console.writeJsonError (PodmanError.toMessage e) 1
                    | Console.OutputFormat.Text -> Console.error (PodmanError.toMessage e)
                    1
                | Ok probe ->
                    match format with
                    | Console.OutputFormat.Json ->
                        Console.writeJson (toHealthJsonCheck probe)
                        0
                    | Console.OutputFormat.Text ->
                        Console.header "CONTAINER HEALTH"
                        Console.WriteLine("")

                        let statusStr = healthStatusToString probe.Status
                        let statusType =
                            match probe.Status with
                            | HealthStatus.Healthy -> "ok"
                            | HealthStatus.Unhealthy _ -> "error"
                            | HealthStatus.Starting -> "warning"
                            | _ -> "warning"

                        Console.printStatus statusType (sprintf "%s: %s" probe.ContainerName statusStr)
                        Console.dim (sprintf "  Duration: %s" (Console.formatDuration probe.Duration))
                        match probe.Message with
                        | Some msg -> Console.dim (sprintf "  Message: %s" msg)
                        | None -> ()

                        match probe.Status with
                        | HealthStatus.Healthy -> 0
                        | _ -> 1
            finally
                HttpClient.dispose client

    // ========================================================================
    // System Commands
    // ========================================================================

    /// System info (system info)
    let systemInfo (socketPath: string option) (format: Console.OutputFormat) : int =
        match createClient socketPath with
        | Error e ->
            match format with
            | Console.OutputFormat.Json -> Console.writeJsonError (PodmanError.toMessage e) 1
            | Console.OutputFormat.Text -> Console.error (PodmanError.toMessage e)
            1
        | Ok client ->
            try
                let result = Cepaf.Podman.Api.System.info client |> Async.RunSynchronously

                match result with
                | Error e ->
                    match format with
                    | Console.OutputFormat.Json -> Console.writeJsonError (PodmanError.toMessage e) 1
                    | Console.OutputFormat.Text -> Console.error (PodmanError.toMessage e)
                    1
                | Ok info ->
                    match format with
                    | Console.OutputFormat.Json ->
                        Console.writeJson (toSystemJsonInfo info)
                        0
                    | Console.OutputFormat.Text ->
                        Console.header "PODMAN SYSTEM INFO"
                        Console.WriteLine("")

                        Console.subheader "Version:"
                        Console.info (sprintf "  Podman: %s" info.Version.Version)
                        Console.dim (sprintf "  API Version: %s" info.Version.ApiVersion)
                        Console.dim (sprintf "  Go Version: %s" info.Version.GoVersion)
                        Console.dim (sprintf "  Git Commit: %s" info.Version.GitCommit)
                        Console.dim (sprintf "  OS/Arch: %s" info.Version.OsArch)

                        Console.WriteLine("")
                        Console.subheader "Host:"
                        Console.info (sprintf "  Hostname: %s" info.Host.Hostname)
                        Console.dim (sprintf "  OS: %s" info.Host.Os)
                        Console.dim (sprintf "  Arch: %s" info.Host.Arch)
                        Console.dim (sprintf "  Kernel: %s" info.Host.Kernel)
                        Console.dim (sprintf "  CPUs: %d" info.Host.CpuCount)
                        Console.dim (sprintf "  Memory: %s" (Console.formatBytes info.Host.MemTotal))
                        Console.dim (sprintf "  Memory Free: %s" (Console.formatBytes info.Host.MemFree))

                        Console.WriteLine("")
                        Console.subheader "Storage:"
                        Console.dim (sprintf "  Driver: %s" info.Storage.Driver)
                        Console.dim (sprintf "  Graph Root: %s" info.Storage.GraphRoot)
                        Console.dim (sprintf "  Run Root: %s" info.Storage.RunRoot)
                        Console.dim (sprintf "  Images: %d" info.Storage.ImageCount)
                        Console.dim (sprintf "  Containers: %d" info.Storage.ContainerCount)

                        Console.WriteLine("")
                        Console.subheader "Runtime:"
                        Console.dim (sprintf "  Name: %s" info.Runtime.Name)
                        Console.dim (sprintf "  Path: %s" info.Runtime.Path)
                        match info.Runtime.Version with
                        | Some v -> Console.dim (sprintf "  Version: %s" v)
                        | None -> ()

                        0
            finally
                HttpClient.dispose client

    /// System ping (system ping)
    let systemPing (socketPath: string option) : int =
        match createClient socketPath with
        | Error e ->
            Console.writeJsonError (PodmanError.toMessage e) 1
            1
        | Ok client ->
            try
                let result = HttpClient.ping client |> Async.RunSynchronously
                match result with
                | Ok true ->
                    Console.writeJson {| status = "ok"; message = "Podman daemon is running" |}
                    0
                | Ok false ->
                    Console.writeJsonError "Podman daemon is not responding" 1
                    1
                | Error e ->
                    Console.writeJsonError (PodmanError.toMessage e) 1
                    1
            finally
                HttpClient.dispose client

    // ========================================================================
    // Legacy Commands (for backward compatibility)
    // ========================================================================

    /// List containers command handler (legacy)
    let listContainers (socketPath: string option) (all: bool) (quiet: bool) : int =
        containersList socketPath all [] Console.OutputFormat.Text

    /// List images command handler
    let listImages (socketPath: string option) (all: bool) (quiet: bool) : int =
        match createClient socketPath with
        | Error e ->
            Console.error (PodmanError.toMessage e)
            1
        | Ok client ->
            try
                let result = Images.list client all |> Async.RunSynchronously

                match result with
                | Error e ->
                    Console.error (PodmanError.toMessage e)
                    1
                | Ok images ->
                    if quiet then
                        for img in images do
                            Console.WriteLine(Console.truncateId img.Id)
                    elif images.IsEmpty then
                        Console.info "No images found"
                    else
                        Console.header "IMAGES"
                        Console.WriteLine("")

                        let columns = [
                            Console.col "REPOSITORY" 35
                            Console.col "TAG" 15
                            Console.col "IMAGE ID" 14
                            Console.col "CREATED" 15
                            Console.colRight "SIZE" 10
                        ]

                        Console.printTableHeader columns

                        for img in images do
                            let repoTag =
                                match img.RepoTags with
                                | tag :: _ ->
                                    let parts = tag.Split(':')
                                    if parts.Length >= 2 then
                                        (parts.[0], parts.[1])
                                    else
                                        (tag, "latest")
                                | [] -> ("<none>", "<none>")

                            let repo, tag = repoTag
                            let values = [
                                if repo.Length > 35 then repo.Substring(0, 32) + "..." else repo
                                if tag.Length > 15 then tag.Substring(0, 12) + "..." else tag
                                Console.truncateId img.Id
                                Console.formatRelativeTime img.Created
                                Console.formatBytes img.Size
                            ]

                            Console.printTableRow columns values

                        Console.WriteLine("")
                        Console.dim (sprintf "Total: %d image(s)" images.Length)
                    0
            finally
                HttpClient.dispose client

    /// Validate image against STAMP constraints
    let validateImage (socketPath: string option) (imageRef: string) (verbose: bool) : int =
        Console.header "IMAGE VALIDATION"
        Console.WriteLine("")
        Console.info (sprintf "Validating: %s" imageRef)
        Console.WriteLine("")

        // Validate image reference
        let refResult = Constraints.validateImageReference imageRef
        match refResult with
        | Constraints.ValidationResult.Invalid violations ->
            Console.subheader "Reference Violations:"
            for v in violations do
                let severityStatus =
                    match v.Severity with
                    | Constraints.ViolationSeverity.Critical -> "error"
                    | Constraints.ViolationSeverity.Warning -> "warning"
                    | Constraints.ViolationSeverity.Info -> "ok"
                Console.printStatus severityStatus (Constraints.formatViolation v)

            let hasCritical =
                violations
                |> List.exists (fun v -> v.Severity = Constraints.ViolationSeverity.Critical)

            if hasCritical then
                Console.WriteLine("")
                Console.error "Validation FAILED: Critical violations found"
                1
            else
                Console.WriteLine("")
                Console.warning "Validation passed with warnings"
                0

        | Constraints.ValidationResult.Valid ->
            Console.success "Reference validation: PASSED"

            // Now check if image exists and validate further
            match createClient socketPath with
            | Error e ->
                Console.warning (sprintf "Could not connect to Podman: %s" (PodmanError.toMessage e))
                Console.info "Reference validation passed, but could not verify image existence"
                0
            | Ok client ->
                try
                    let existsResult = Images.exists client imageRef |> Async.RunSynchronously
                    match existsResult with
                    | Error e ->
                        Console.warning (sprintf "Could not check image: %s" (PodmanError.toMessage e))
                        0
                    | Ok exists ->
                        if exists then
                            Console.success "Image exists: YES"

                            if verbose then
                                // Get image details
                                let inspectResult = Images.inspect client imageRef |> Async.RunSynchronously
                                match inspectResult with
                                | Ok img ->
                                    Console.WriteLine("")
                                    Console.subheader "Image Details:"
                                    Console.dim (sprintf "  ID: %s" (Console.truncateId img.Id))
                                    Console.dim (sprintf "  Created: %s" (Console.formatRelativeTime img.Created))
                                    Console.dim (sprintf "  Size: %s" (Console.formatBytes img.Size))
                                    Console.dim (sprintf "  Arch: %s" img.Architecture)
                                    Console.dim (sprintf "  OS: %s" img.Os)

                                    if not (Map.isEmpty img.Labels) then
                                        Console.dim "  Labels:"
                                        for KeyValue(k, v) in img.Labels do
                                            Console.dim (sprintf "    %s: %s" k v)
                                | Error _ -> ()

                            Console.WriteLine("")
                            Console.success "Validation PASSED"
                            0
                        else
                            Console.warning "Image exists: NO"
                            Console.info "Image reference is valid but image not found locally"
                            0
                finally
                    HttpClient.dispose client

    /// Ping command to test connectivity (legacy)
    let ping (socketPath: string option) : int =
        match createClient socketPath with
        | Error e ->
            Console.error (PodmanError.toMessage e)
            1
        | Ok client ->
            try
                let result = HttpClient.ping client |> Async.RunSynchronously
                match result with
                | Ok true ->
                    Console.success "Podman daemon is running"
                    0
                | Ok false ->
                    Console.error "Podman daemon is not responding"
                    1
                | Error e ->
                    Console.error (PodmanError.toMessage e)
                    1
            finally
                HttpClient.dispose client
