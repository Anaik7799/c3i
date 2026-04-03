namespace Cepaf.Podman.Health

open System
open System.Threading
open System.Threading.Tasks
open Cepaf.Podman.Domain
open Cepaf.Podman.Client
open Cepaf.Podman.Api

/// Health probe operations
module Probes =

    // ========================================================================
    // Health Check Types
    // ========================================================================

    /// Probe result
    type ProbeResult = {
        ContainerId: string
        ContainerName: string
        Status: HealthStatus
        Message: string option
        Timestamp: DateTimeOffset
        Duration: TimeSpan
    }

    /// Probe configuration
    type ProbeConfig = {
        Interval: TimeSpan
        Timeout: TimeSpan
        Retries: int
        StartPeriod: TimeSpan
    }

    module ProbeConfig =
        let defaults = {
            Interval = TimeSpan.FromSeconds(30.0)
            Timeout = TimeSpan.FromSeconds(30.0)
            Retries = 3
            StartPeriod = TimeSpan.Zero
        }

        let withInterval interval cfg = { cfg with Interval = interval }
        let withTimeout timeout cfg = { cfg with Timeout = timeout }
        let withRetries retries cfg = { cfg with Retries = retries }
        let withStartPeriod period cfg = { cfg with StartPeriod = period }

    // ========================================================================
    // Single Health Check
    // ========================================================================

    /// Run health check on a container
    let check (client: PodmanClient) (containerId: string) : AsyncPodmanResult<ProbeResult> = async {
        let startTime = DateTimeOffset.UtcNow
        let! inspectResult = Containers.inspect client containerId

        match inspectResult with
        | Error e -> return Error e
        | Ok container ->
            let! healthResult = Containers.healthCheck client containerId
            let endTime = DateTimeOffset.UtcNow
            let duration = endTime - startTime

            match healthResult with
            | Ok status ->
                return Ok {
                    ContainerId = container.Id
                    ContainerName = container.Name
                    Status = status
                    Message = None
                    Timestamp = endTime
                    Duration = duration
                }
            | Error (PodmanError.NotFound _) ->
                // Container doesn't have health check configured
                return Ok {
                    ContainerId = container.Id
                    ContainerName = container.Name
                    Status = HealthStatus.NoHealthcheck
                    Message = Some "No health check configured"
                    Timestamp = endTime
                    Duration = duration
                }
            | Error e ->
                return Ok {
                    ContainerId = container.Id
                    ContainerName = container.Name
                    Status = HealthStatus.Unhealthy 0
                    Message = Some (PodmanError.toMessage e)
                    Timestamp = endTime
                    Duration = duration
                }
    }

    /// Check health of all running containers
    let checkAll (client: PodmanClient) : AsyncPodmanResult<ProbeResult list> = async {
        let! containersResult = Containers.listRunning client
        match containersResult with
        | Error e -> return Error e
        | Ok containers ->
            let! results =
                containers
                |> List.map (fun c -> check client c.Id)
                |> Async.Parallel

            let probeResults =
                results
                |> Array.toList
                |> List.choose (function Ok r -> Some r | Error _ -> None)

            return Ok probeResults
    }

    /// Check health of containers with specific label
    let checkByLabel (client: PodmanClient) (label: string) : AsyncPodmanResult<ProbeResult list> = async {
        let filters = Containers.ListFilters.empty |> Containers.ListFilters.withLabel label
        let! containersResult = Containers.list client filters
        match containersResult with
        | Error e -> return Error e
        | Ok containers ->
            let! results =
                containers
                |> List.map (fun c -> check client c.Id)
                |> Async.Parallel

            let probeResults =
                results
                |> Array.toList
                |> List.choose (function Ok r -> Some r | Error _ -> None)

            return Ok probeResults
    }

    // ========================================================================
    // Health Monitoring
    // ========================================================================

    /// Health monitor state
    type MonitorState = {
        Running: bool
        LastCheck: DateTimeOffset option
        Results: Map<string, ProbeResult>
        Failures: Map<string, int>
    }

    /// Health monitor
    type HealthMonitor = {
        Client: PodmanClient
        Config: ProbeConfig
        CancellationTokenSource: CancellationTokenSource
        mutable State: MonitorState
        OnHealthChange: (ProbeResult -> unit) option
        OnUnhealthy: (ProbeResult -> unit) option
    }

    /// Create health monitor
    let createMonitor (client: PodmanClient) (config: ProbeConfig) : HealthMonitor =
        {
            Client = client
            Config = config
            CancellationTokenSource = new CancellationTokenSource()
            State = { Running = false; LastCheck = None; Results = Map.empty; Failures = Map.empty }
            OnHealthChange = None
            OnUnhealthy = None
        }

    /// Set health change callback
    let onHealthChange (handler: ProbeResult -> unit) (monitor: HealthMonitor) : HealthMonitor =
        { monitor with OnHealthChange = Some handler }

    /// Set unhealthy callback
    let onUnhealthy (handler: ProbeResult -> unit) (monitor: HealthMonitor) : HealthMonitor =
        { monitor with OnUnhealthy = Some handler }

    /// Start monitoring
    let startMonitor (monitor: HealthMonitor) : unit =
        monitor.State <- { monitor.State with Running = true }

        Task.Run(fun () ->
            task {
                let ct = monitor.CancellationTokenSource.Token

                // Wait for start period
                if monitor.Config.StartPeriod > TimeSpan.Zero then
                    do! Task.Delay(monitor.Config.StartPeriod, ct)

                while not ct.IsCancellationRequested && monitor.State.Running do
                    try
                        let! results = checkAll monitor.Client |> Async.StartAsTask

                        match results with
                        | Ok probeResults ->
                            for result in probeResults do
                                let previousResult = monitor.State.Results |> Map.tryFind result.ContainerId

                                // Update state
                                monitor.State <- {
                                    monitor.State with
                                        LastCheck = Some result.Timestamp
                                        Results = monitor.State.Results |> Map.add result.ContainerId result
                                }

                                // Check for status change
                                match previousResult with
                                | Some prev when prev.Status <> result.Status ->
                                    match monitor.OnHealthChange with
                                    | Some handler -> handler result
                                    | None -> ()
                                | _ -> ()

                                // Check for unhealthy
                                let isUnhealthy = match result.Status with HealthStatus.Unhealthy _ -> true | _ -> false
                                if isUnhealthy then
                                    let failures =
                                        monitor.State.Failures
                                        |> Map.tryFind result.ContainerId
                                        |> Option.defaultValue 0
                                        |> (+) 1

                                    monitor.State <- {
                                        monitor.State with
                                            Failures = monitor.State.Failures |> Map.add result.ContainerId failures
                                    }

                                    if failures >= monitor.Config.Retries then
                                        match monitor.OnUnhealthy with
                                        | Some handler -> handler result
                                        | None -> ()
                                else
                                    // Reset failure count on healthy
                                    monitor.State <- {
                                        monitor.State with
                                            Failures = monitor.State.Failures |> Map.remove result.ContainerId
                                    }
                        | Error _ -> ()

                        do! Task.Delay(monitor.Config.Interval, ct)
                    with
                    | :? OperationCanceledException -> ()
                    | _ -> ()
            } :> Task
        ) |> ignore

    /// Stop monitoring
    let stopMonitor (monitor: HealthMonitor) : unit =
        monitor.State <- { monitor.State with Running = false }
        monitor.CancellationTokenSource.Cancel()

    /// Get current monitor state
    let getMonitorState (monitor: HealthMonitor) : MonitorState =
        monitor.State

    /// Dispose monitor
    let disposeMonitor (monitor: HealthMonitor) : unit =
        stopMonitor monitor
        monitor.CancellationTokenSource.Dispose()

    // ========================================================================
    // Liveness and Readiness Probes
    // ========================================================================

    /// Liveness probe - is container alive
    let livenessProbe (client: PodmanClient) (containerId: string) : AsyncPodmanResult<bool> = async {
        let! result = Containers.isRunning client containerId
        return result
    }

    /// Readiness probe - is container ready for traffic
    let readinessProbe (client: PodmanClient) (containerId: string) : AsyncPodmanResult<bool> = async {
        let! result = check client containerId
        match result with
        | Error _ -> return Ok false
        | Ok probe ->
            match probe.Status with
            | HealthStatus.Healthy -> return Ok true
            | HealthStatus.Starting -> return Ok false
            | HealthStatus.Unhealthy _ -> return Ok false
            | HealthStatus.Unknown _ -> return Ok false
            | HealthStatus.NoHealthcheck ->
                // No health check - consider ready if running
                return! Containers.isRunning client containerId
    }

    /// Startup probe - has container started successfully
    let startupProbe (client: PodmanClient) (containerId: string) (timeout: TimeSpan) : AsyncPodmanResult<bool> = async {
        let startTime = DateTimeOffset.UtcNow
        let endTime = startTime + timeout

        let rec loop () = async {
            if DateTimeOffset.UtcNow > endTime then
                return Ok false
            else
                let! ready = readinessProbe client containerId
                match ready with
                | Ok true -> return Ok true
                | Ok false ->
                    do! Async.Sleep 1000
                    return! loop ()
                | Error e -> return Error e
        }

        return! loop ()
    }

    // ========================================================================
    // Health Summary
    // ========================================================================

    /// Health summary
    type HealthSummary = {
        Total: int
        Healthy: int
        Unhealthy: int
        Starting: int
        NoHealthCheck: int
        Timestamp: DateTimeOffset
    }

    /// Get health summary for all containers
    let getSummary (client: PodmanClient) : AsyncPodmanResult<HealthSummary> = async {
        let! results = checkAll client
        match results with
        | Error e -> return Error e
        | Ok probes ->
            let healthy = probes |> List.filter (fun p -> p.Status = HealthStatus.Healthy) |> List.length
            let unhealthy = probes |> List.filter (fun p -> match p.Status with HealthStatus.Unhealthy _ -> true | _ -> false) |> List.length
            let starting = probes |> List.filter (fun p -> p.Status = HealthStatus.Starting) |> List.length
            let none = probes |> List.filter (fun p -> p.Status = HealthStatus.NoHealthcheck) |> List.length

            return Ok {
                Total = probes.Length
                Healthy = healthy
                Unhealthy = unhealthy
                Starting = starting
                NoHealthCheck = none
                Timestamp = DateTimeOffset.UtcNow
            }
    }

    /// Check if all containers are healthy
    let allHealthy (client: PodmanClient) : AsyncPodmanResult<bool> = async {
        let! summary = getSummary client
        return summary |> Result.map (fun s -> s.Unhealthy = 0 && s.Starting = 0)
    }

    /// Get unhealthy containers
    let getUnhealthy (client: PodmanClient) : AsyncPodmanResult<ProbeResult list> = async {
        let! results = checkAll client
        return results |> Result.map (List.filter (fun p -> match p.Status with HealthStatus.Unhealthy _ -> true | _ -> false))
    }

