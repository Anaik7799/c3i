namespace Cepaf.Podman.Telemetry

open System
open System.Diagnostics
open System.Diagnostics.Metrics
open Cepaf.Podman.Domain

// ============================================================================
// OpenTelemetry Semantic Conventions for Containers
// Based on: https://opentelemetry.io/docs/specs/semconv/resource/container/
// ============================================================================

/// Semantic attribute keys for container observability
[<RequireQualifiedAccess>]
module SemanticConventions =
    // Container Resource Attributes
    let containerName = "container.name"
    let containerId = "container.id"
    let containerImageName = "container.image.name"
    let containerImageId = "container.image.id"
    let containerImageTag = "container.image.tag"
    let containerRuntime = "container.runtime"

    // Podman-specific Attributes
    let podmanSocketPath = "podman.socket.path"
    let podmanApiVersion = "podman.api.version"
    let podmanRootless = "podman.rootless"

    // Pod Attributes
    let podName = "pod.name"
    let podId = "pod.id"

    // Operation Attributes
    let operationType = "cepaf.operation.type"
    let operationStatus = "cepaf.operation.status"
    let operationDurationMs = "cepaf.operation.duration_ms"

    // Error Attributes
    let errorType = "error.type"
    let errorMessage = "error.message"

    // Network Attributes
    let networkName = "network.name"
    let networkDriver = "network.driver"

    // Volume Attributes
    let volumeName = "volume.name"
    let volumeDriver = "volume.driver"

    // Health Check Attributes
    let healthStatus = "container.health.status"
    let healthFailingStreak = "container.health.failing_streak"

// ============================================================================
// Instrumentation Constants
// ============================================================================

[<RequireQualifiedAccess>]
module InstrumentationInfo =
    let serviceName = "Cepaf.Podman"
    let serviceVersion = "1.0.0"
    let meterName = "Cepaf.Podman.Metrics"
    let activitySourceName = "Cepaf.Podman.Tracing"

// ============================================================================
// ActivitySource for Distributed Tracing
// ============================================================================

/// OpenTelemetry tracing infrastructure for Podman operations
module Tracing =

    /// Singleton ActivitySource for all Podman operations
    /// ActivitySource is meant to be created once and reused
    let activitySource =
        new ActivitySource(
            InstrumentationInfo.activitySourceName,
            InstrumentationInfo.serviceVersion
        )

    /// Activity (span) kinds for different operation types
    [<RequireQualifiedAccess>]
    type SpanKind =
        | Client      // Outgoing calls to Podman socket
        | Internal    // Internal processing
        | Producer    // Async operations (container start)
        | Consumer    // Event processing

    /// Tags for container operations
    type ContainerTags = {
        ContainerId: string option
        ContainerName: string option
        ImageName: string option
        OperationType: string
    }

    module ContainerTags =
        let empty operationType = {
            ContainerId = None
            ContainerName = None
            ImageName = None
            OperationType = operationType
        }

        let withContainer id name tags = {
            tags with ContainerId = Some id; ContainerName = Some name
        }

        let withImage name tags = { tags with ImageName = Some name }

    /// Start a new activity (span) for a container operation
    let startActivity (name: string) (kind: ActivityKind) (tags: ContainerTags) : Activity option =
        let activity = activitySource.StartActivity(name, kind)
        match activity with
        | null -> None
        | act ->
            // Set semantic convention attributes
            act.SetTag(SemanticConventions.containerRuntime, "podman") |> ignore
            act.SetTag(SemanticConventions.operationType, tags.OperationType) |> ignore

            tags.ContainerId |> Option.iter (fun id ->
                act.SetTag(SemanticConventions.containerId, id) |> ignore)

            tags.ContainerName |> Option.iter (fun name ->
                act.SetTag(SemanticConventions.containerName, name) |> ignore)

            tags.ImageName |> Option.iter (fun name ->
                act.SetTag(SemanticConventions.containerImageName, name) |> ignore)

            Some act

    /// Start activity for container list operation
    let startListActivity (filters: string) : Activity option =
        let tags = ContainerTags.empty "list"
        let activity = startActivity "container.list" ActivityKind.Client tags
        activity |> Option.iter (fun act ->
            act.SetTag("filters", filters) |> ignore)
        activity

    /// Start activity for container inspect operation
    let startInspectActivity (containerId: string) : Activity option =
        let tags = { ContainerTags.empty "inspect" with ContainerId = Some containerId }
        startActivity "container.inspect" ActivityKind.Client tags

    /// Start activity for container create operation
    let startCreateActivity (imageName: string) (containerName: string option) : Activity option =
        let tags =
            { ContainerTags.empty "create" with ImageName = Some imageName }
            |> fun t -> match containerName with Some n -> { t with ContainerName = Some n } | None -> t
        startActivity "container.create" ActivityKind.Client tags

    /// Start activity for container start operation
    let startStartActivity (containerId: string) : Activity option =
        let tags = { ContainerTags.empty "start" with ContainerId = Some containerId }
        startActivity "container.start" ActivityKind.Client tags

    /// Start activity for container stop operation
    let startStopActivity (containerId: string) (timeout: int option) : Activity option =
        let tags = { ContainerTags.empty "stop" with ContainerId = Some containerId }
        let activity = startActivity "container.stop" ActivityKind.Client tags
        activity |> Option.iter (fun act ->
            timeout |> Option.iter (fun t -> act.SetTag("timeout_seconds", t) |> ignore))
        activity

    /// Start activity for container remove operation
    let startRemoveActivity (containerId: string) (force: bool) : Activity option =
        let tags = { ContainerTags.empty "remove" with ContainerId = Some containerId }
        let activity = startActivity "container.remove" ActivityKind.Client tags
        activity |> Option.iter (fun act ->
            act.SetTag("force", force) |> ignore)
        activity

    /// Start activity for health check operation
    let startHealthCheckActivity (containerId: string) : Activity option =
        let tags = { ContainerTags.empty "healthcheck" with ContainerId = Some containerId }
        startActivity "container.healthcheck" ActivityKind.Client tags

    /// Start activity for pod operations
    let startPodActivity (operation: string) (podId: string option) (podName: string option) : Activity option =
        let activity = activitySource.StartActivity(sprintf "pod.%s" operation, ActivityKind.Client)
        match activity with
        | null -> None
        | act ->
            act.SetTag(SemanticConventions.containerRuntime, "podman") |> ignore
            act.SetTag(SemanticConventions.operationType, operation) |> ignore
            podId |> Option.iter (fun id -> act.SetTag(SemanticConventions.podId, id) |> ignore)
            podName |> Option.iter (fun name -> act.SetTag(SemanticConventions.podName, name) |> ignore)
            Some act

    /// Start activity for image operations
    let startImageActivity (operation: string) (imageName: string option) : Activity option =
        let activity = activitySource.StartActivity(sprintf "image.%s" operation, ActivityKind.Client)
        match activity with
        | null -> None
        | act ->
            act.SetTag(SemanticConventions.containerRuntime, "podman") |> ignore
            act.SetTag(SemanticConventions.operationType, operation) |> ignore
            imageName |> Option.iter (fun name ->
                act.SetTag(SemanticConventions.containerImageName, name) |> ignore)
            Some act

    /// Start activity for network operations
    let startNetworkActivity (operation: string) (networkName: string option) : Activity option =
        let activity = activitySource.StartActivity(sprintf "network.%s" operation, ActivityKind.Client)
        match activity with
        | null -> None
        | act ->
            act.SetTag(SemanticConventions.containerRuntime, "podman") |> ignore
            act.SetTag(SemanticConventions.operationType, operation) |> ignore
            networkName |> Option.iter (fun name ->
                act.SetTag(SemanticConventions.networkName, name) |> ignore)
            Some act

    /// Start activity for volume operations
    let startVolumeActivity (operation: string) (volumeName: string option) : Activity option =
        let activity = activitySource.StartActivity(sprintf "volume.%s" operation, ActivityKind.Client)
        match activity with
        | null -> None
        | act ->
            act.SetTag(SemanticConventions.containerRuntime, "podman") |> ignore
            act.SetTag(SemanticConventions.operationType, operation) |> ignore
            volumeName |> Option.iter (fun name ->
                act.SetTag(SemanticConventions.volumeName, name) |> ignore)
            Some act

    /// Start activity for system operations
    let startSystemActivity (operation: string) : Activity option =
        let activity = activitySource.StartActivity(sprintf "system.%s" operation, ActivityKind.Client)
        match activity with
        | null -> None
        | act ->
            act.SetTag(SemanticConventions.containerRuntime, "podman") |> ignore
            act.SetTag(SemanticConventions.operationType, operation) |> ignore
            Some act

    /// Record success on an activity
    let recordSuccess (activity: Activity option) =
        activity |> Option.iter (fun act ->
            act.SetTag(SemanticConventions.operationStatus, "success") |> ignore
            act.SetStatus(ActivityStatusCode.Ok) |> ignore)

    /// Record error on an activity
    let recordError (activity: Activity option) (error: PodmanError) =
        activity |> Option.iter (fun act ->
            act.SetTag(SemanticConventions.operationStatus, "error") |> ignore
            act.SetStatus(ActivityStatusCode.Error) |> ignore

            let (errorType, errorMessage) =
                match error with
                | PodmanError.NotFound (resourceType, id) -> ("not_found", sprintf "%s: %s" resourceType id)
                | PodmanError.Conflict (resourceType, reason) -> ("conflict", sprintf "%s: %s" resourceType reason)
                | PodmanError.BadRequest msg -> ("bad_request", msg)
                | PodmanError.InternalError msg -> ("internal_error", msg)
                | PodmanError.SocketNotFound path -> ("socket_not_found", path)
                | PodmanError.ConnectionRefused endpoint -> ("connection_refused", endpoint)
                | PodmanError.ConnectionTimeout (op, ms) -> ("connection_timeout", sprintf "%s after %dms" op ms)
                | PodmanError.JsonParseError msg -> ("json_parse_error", msg)
                | PodmanError.ApiError (code, msg) -> (sprintf "api_error_%d" code, msg)
                | _ -> ("unknown", PodmanError.toMessage error)

            act.SetTag(SemanticConventions.errorType, errorType) |> ignore
            act.SetTag(SemanticConventions.errorMessage, errorMessage) |> ignore

            // Add exception event for better observability
            let tagsCollection = ActivityTagsCollection()
            tagsCollection.Add("exception.type", errorType)
            tagsCollection.Add("exception.message", errorMessage)
            act.AddEvent(ActivityEvent("exception", tags = tagsCollection)) |> ignore)

    /// Record health status on an activity
    let recordHealthStatus (activity: Activity option) (status: HealthStatus) =
        activity |> Option.iter (fun act ->
            let statusStr =
                match status with
                | HealthStatus.Starting -> "starting"
                | HealthStatus.Healthy -> "healthy"
                | HealthStatus.Unhealthy streak -> sprintf "unhealthy (streak: %d)" streak
                | HealthStatus.NoHealthcheck -> "no_healthcheck"
                | HealthStatus.Unknown s -> s

            act.SetTag(SemanticConventions.healthStatus, statusStr) |> ignore

            match status with
            | HealthStatus.Unhealthy streak ->
                act.SetTag(SemanticConventions.healthFailingStreak, streak) |> ignore
            | _ -> ())

    /// Stop an activity with duration
    let stopActivity (activity: Activity option) =
        activity |> Option.iter (fun act ->
            let duration = act.Duration.TotalMilliseconds
            act.SetTag(SemanticConventions.operationDurationMs, duration) |> ignore
            act.Stop())

    /// Execute an async operation with tracing
    let traceAsync<'T> (activity: Activity option) (operation: Async<Result<'T, PodmanError>>) : Async<Result<'T, PodmanError>> = async {
        try
            let! result = operation
            match result with
            | Ok value ->
                recordSuccess activity
                return Ok value
            | Error err ->
                recordError activity err
                return Error err
        finally
            stopActivity activity
    }

// ============================================================================
// Metrics for Container Operations
// ============================================================================

/// OpenTelemetry metrics infrastructure for Podman operations
module Metrics =

    /// Singleton Meter for all Podman metrics
    let meter = new Meter(InstrumentationInfo.meterName, InstrumentationInfo.serviceVersion)

    // ========================================================================
    // Counter Metrics
    // ========================================================================

    /// Total container operations performed
    let containerOperationsCounter =
        meter.CreateCounter<int64>(
            "cepaf.podman.container.operations.total",
            unit = "{operations}",
            description = "Total number of container operations performed"
        )

    /// Total container lifecycle events
    let containerEventsCounter =
        meter.CreateCounter<int64>(
            "cepaf.podman.container.events.total",
            unit = "{events}",
            description = "Total number of container lifecycle events"
        )

    /// Total API errors
    let apiErrorsCounter =
        meter.CreateCounter<int64>(
            "cepaf.podman.api.errors.total",
            unit = "{errors}",
            description = "Total number of API errors"
        )

    /// Total health check executions
    let healthCheckCounter =
        meter.CreateCounter<int64>(
            "cepaf.podman.healthcheck.total",
            unit = "{checks}",
            description = "Total number of health checks executed"
        )

    // ========================================================================
    // Histogram Metrics
    // ========================================================================

    /// Container operation latency histogram
    let operationDurationHistogram =
        meter.CreateHistogram<double>(
            "cepaf.podman.operation.duration",
            unit = "ms",
            description = "Duration of Podman operations in milliseconds"
        )

    /// Container startup time histogram
    let containerStartupHistogram =
        meter.CreateHistogram<double>(
            "cepaf.podman.container.startup.duration",
            unit = "ms",
            description = "Time taken to start containers in milliseconds"
        )

    /// API response time histogram
    let apiResponseHistogram =
        meter.CreateHistogram<double>(
            "cepaf.podman.api.response.duration",
            unit = "ms",
            description = "Podman API response time in milliseconds"
        )

    // ========================================================================
    // UpDownCounter Metrics (Gauges)
    // ========================================================================

    /// Current number of containers by status
    let containersGauge =
        meter.CreateUpDownCounter<int64>(
            "cepaf.podman.containers.current",
            unit = "{containers}",
            description = "Current number of containers by status"
        )

    /// Current number of pods
    let podsGauge =
        meter.CreateUpDownCounter<int64>(
            "cepaf.podman.pods.current",
            unit = "{pods}",
            description = "Current number of pods"
        )

    /// Current number of images
    let imagesGauge =
        meter.CreateUpDownCounter<int64>(
            "cepaf.podman.images.current",
            unit = "{images}",
            description = "Current number of images"
        )

    /// Current number of volumes
    let volumesGauge =
        meter.CreateUpDownCounter<int64>(
            "cepaf.podman.volumes.current",
            unit = "{volumes}",
            description = "Current number of volumes"
        )

    /// Current number of networks
    let networksGauge =
        meter.CreateUpDownCounter<int64>(
            "cepaf.podman.networks.current",
            unit = "{networks}",
            description = "Current number of networks"
        )

    // ========================================================================
    // Helper Functions
    // ========================================================================

    /// Create tags for container operations
    let containerTags (operation: string) (status: string) =
        let mutable tags = TagList()
        tags.Add("operation", operation :> obj)
        tags.Add("status", status :> obj)
        tags.Add("runtime", "podman" :> obj)
        tags

    /// Create tags for container status
    let statusTags (status: ContainerStatus) =
        let statusStr =
            match status with
            | ContainerStatus.Created -> "created"
            | ContainerStatus.Running -> "running"
            | ContainerStatus.Paused -> "paused"
            | ContainerStatus.Restarting -> "restarting"
            | ContainerStatus.Removing -> "removing"
            | ContainerStatus.Exited _ -> "exited"
            | ContainerStatus.Dead _ -> "dead"
            | ContainerStatus.Unknown s -> s
        let mutable tags = TagList()
        tags.Add("status", statusStr :> obj)
        tags

    /// Create tags for health status
    let healthTags (status: HealthStatus) =
        let statusStr =
            match status with
            | HealthStatus.Starting -> "starting"
            | HealthStatus.Healthy -> "healthy"
            | HealthStatus.Unhealthy _ -> "unhealthy"
            | HealthStatus.NoHealthcheck -> "none"
            | HealthStatus.Unknown s -> s
        let mutable tags = TagList()
        tags.Add("health_status", statusStr :> obj)
        tags

    /// Create tags for error type
    let errorTags (error: PodmanError) =
        let errorType =
            match error with
            | PodmanError.NotFound _ -> "not_found"
            | PodmanError.Conflict _ -> "conflict"
            | PodmanError.BadRequest _ -> "bad_request"
            | PodmanError.InternalError _ -> "internal_error"
            | PodmanError.SocketNotFound _ -> "socket_not_found"
            | PodmanError.ConnectionRefused _ -> "connection_refused"
            | PodmanError.ConnectionTimeout _ -> "connection_timeout"
            | PodmanError.JsonParseError _ -> "json_parse_error"
            | PodmanError.ApiError (code, _) -> sprintf "api_error_%d" code
            | _ -> "unknown_error"
        let mutable tags = TagList()
        tags.Add("error_type", errorType :> obj)
        tags

    // ========================================================================
    // Recording Functions
    // ========================================================================

    /// Record a container operation
    let recordOperation (operation: string) (success: bool) =
        let mutable tags = containerTags operation (if success then "success" else "error")
        containerOperationsCounter.Add(1L, &tags)

    /// Record a container lifecycle event
    let recordContainerEvent (event: string) (containerId: string) =
        let mutable tags = TagList()
        tags.Add("event", event :> obj)
        tags.Add("container_id", containerId :> obj)
        containerEventsCounter.Add(1L, &tags)

    /// Record an API error
    let recordApiError (error: PodmanError) =
        let mutable tags = errorTags error
        apiErrorsCounter.Add(1L, &tags)

    /// Record a health check result
    let recordHealthCheck (containerId: string) (status: HealthStatus) =
        let healthStatusStr =
            match status with
            | HealthStatus.Healthy -> "healthy"
            | HealthStatus.Unhealthy _ -> "unhealthy"
            | HealthStatus.Starting -> "starting"
            | HealthStatus.NoHealthcheck -> "none"
            | HealthStatus.Unknown s -> s
        let mutable tags = TagList()
        tags.Add("container_id", containerId :> obj)
        tags.Add("health_status", healthStatusStr :> obj)
        healthCheckCounter.Add(1L, &tags)

    /// Record operation duration
    let recordDuration (operation: string) (durationMs: double) (success: bool) =
        let mutable tags = containerTags operation (if success then "success" else "error")
        operationDurationHistogram.Record(durationMs, &tags)

    /// Record container startup time
    let recordStartupTime (containerId: string) (durationMs: double) =
        let mutable tags = TagList()
        tags.Add("container_id", containerId :> obj)
        containerStartupHistogram.Record(durationMs, &tags)

    /// Record API response time
    let recordApiResponse (endpoint: string) (durationMs: double) =
        let mutable tags = TagList()
        tags.Add("endpoint", endpoint :> obj)
        apiResponseHistogram.Record(durationMs, &tags)

    /// Update container count by status
    let updateContainerCount (status: ContainerStatus) (delta: int64) =
        let mutable tags = statusTags status
        containersGauge.Add(delta, &tags)

    /// Update pod count
    let updatePodCount (delta: int64) =
        podsGauge.Add(delta)

    /// Update image count
    let updateImageCount (delta: int64) =
        imagesGauge.Add(delta)

    /// Update volume count
    let updateVolumeCount (delta: int64) =
        volumesGauge.Add(delta)

    /// Update network count
    let updateNetworkCount (delta: int64) =
        networksGauge.Add(delta)

    /// Measure and record async operation duration
    let measureAsync<'T> (operation: string) (work: Async<Result<'T, PodmanError>>) : Async<Result<'T, PodmanError>> = async {
        let stopwatch = Stopwatch.StartNew()
        let! result = work
        stopwatch.Stop()
        let durationMs = stopwatch.Elapsed.TotalMilliseconds

        match result with
        | Ok _ ->
            recordOperation operation true
            recordDuration operation durationMs true
        | Error err ->
            recordOperation operation false
            recordDuration operation durationMs false
            recordApiError err

        return result
    }

// ============================================================================
// Instrumentation Configuration
// ============================================================================

/// Configuration and setup for OpenTelemetry instrumentation
module Configuration =

    /// Resource attributes for the Cepaf.Podman service
    type ServiceAttributes = {
        ServiceName: string
        ServiceVersion: string
        Environment: string
        PodmanSocketPath: string option
        PodmanApiVersion: string option
        IsRootless: bool option
    }

    module ServiceAttributes =
        let defaults = {
            ServiceName = InstrumentationInfo.serviceName
            ServiceVersion = InstrumentationInfo.serviceVersion
            Environment = "production"
            PodmanSocketPath = None
            PodmanApiVersion = None
            IsRootless = None
        }

        let withSocket path attrs = { attrs with PodmanSocketPath = Some path }
        let withApiVersion version attrs = { attrs with PodmanApiVersion = Some version }
        let withRootless isRootless attrs = { attrs with IsRootless = Some isRootless }
        let withEnvironment env attrs = { attrs with Environment = env }

    /// Get the ActivitySource for external configuration
    let getActivitySource () = Tracing.activitySource

    /// Get the Meter for external configuration
    let getMeter () = Metrics.meter

    /// Check if tracing is enabled (activities are being recorded)
    let isTracingEnabled () =
        Tracing.activitySource.HasListeners()

    /// Check if metrics are enabled (meter has listeners)
    let isMetricsEnabled () =
        // Meters always accept recordings; listeners determine if they're exported
        true

    /// Dispose telemetry resources
    let dispose () =
        Tracing.activitySource.Dispose()
        Metrics.meter.Dispose()

// ============================================================================
// Instrumented Operations (Convenience Wrappers)
// ============================================================================

/// Pre-instrumented async operations with full tracing and metrics
module InstrumentedOps =

    /// Execute a container list operation with full instrumentation
    let listContainers<'T>
        (filters: string)
        (operation: Async<Result<'T, PodmanError>>)
        : Async<Result<'T, PodmanError>> = async {
        let activity = Tracing.startListActivity filters
        return! Metrics.measureAsync "list" (Tracing.traceAsync activity operation)
    }

    /// Execute a container inspect operation with full instrumentation
    let inspectContainer<'T>
        (containerId: string)
        (operation: Async<Result<'T, PodmanError>>)
        : Async<Result<'T, PodmanError>> = async {
        let activity = Tracing.startInspectActivity containerId
        return! Metrics.measureAsync "inspect" (Tracing.traceAsync activity operation)
    }

    /// Execute a container create operation with full instrumentation
    let createContainer<'T>
        (imageName: string)
        (containerName: string option)
        (operation: Async<Result<'T, PodmanError>>)
        : Async<Result<'T, PodmanError>> = async {
        let activity = Tracing.startCreateActivity imageName containerName
        return! Metrics.measureAsync "create" (Tracing.traceAsync activity operation)
    }

    /// Execute a container start operation with full instrumentation
    let startContainer
        (containerId: string)
        (operation: Async<Result<unit, PodmanError>>)
        : Async<Result<unit, PodmanError>> = async {
        let stopwatch = Stopwatch.StartNew()
        let activity = Tracing.startStartActivity containerId
        let! result = Metrics.measureAsync "start" (Tracing.traceAsync activity operation)
        stopwatch.Stop()

        match result with
        | Ok () ->
            Metrics.recordStartupTime containerId stopwatch.Elapsed.TotalMilliseconds
            Metrics.recordContainerEvent "started" containerId
            Metrics.updateContainerCount ContainerStatus.Running 1L
        | Error _ -> ()

        return result
    }

    /// Execute a container stop operation with full instrumentation
    let stopContainer
        (containerId: string)
        (timeout: int option)
        (operation: Async<Result<unit, PodmanError>>)
        : Async<Result<unit, PodmanError>> = async {
        let activity = Tracing.startStopActivity containerId timeout
        let! result = Metrics.measureAsync "stop" (Tracing.traceAsync activity operation)

        match result with
        | Ok () ->
            Metrics.recordContainerEvent "stopped" containerId
            Metrics.updateContainerCount ContainerStatus.Running -1L
            Metrics.updateContainerCount (ContainerStatus.Exited 0) 1L
        | Error _ -> ()

        return result
    }

    /// Execute a container remove operation with full instrumentation
    let removeContainer
        (containerId: string)
        (force: bool)
        (operation: Async<Result<unit, PodmanError>>)
        : Async<Result<unit, PodmanError>> = async {
        let activity = Tracing.startRemoveActivity containerId force
        let! result = Metrics.measureAsync "remove" (Tracing.traceAsync activity operation)

        match result with
        | Ok () ->
            Metrics.recordContainerEvent "removed" containerId
        | Error _ -> ()

        return result
    }

    /// Execute a health check operation with full instrumentation
    let healthCheck
        (containerId: string)
        (operation: Async<Result<HealthStatus, PodmanError>>)
        : Async<Result<HealthStatus, PodmanError>> = async {
        let activity = Tracing.startHealthCheckActivity containerId
        let! result = Metrics.measureAsync "healthcheck" (Tracing.traceAsync activity operation)

        match result with
        | Ok status ->
            Tracing.recordHealthStatus activity status
            Metrics.recordHealthCheck containerId status
        | Error _ -> ()

        return result
    }

    /// Execute a pod operation with full instrumentation
    let podOperation<'T>
        (operation: string)
        (podId: string option)
        (podName: string option)
        (work: Async<Result<'T, PodmanError>>)
        : Async<Result<'T, PodmanError>> = async {
        let activity = Tracing.startPodActivity operation podId podName
        return! Metrics.measureAsync (sprintf "pod.%s" operation) (Tracing.traceAsync activity work)
    }

    /// Execute an image operation with full instrumentation
    let imageOperation<'T>
        (operation: string)
        (imageName: string option)
        (work: Async<Result<'T, PodmanError>>)
        : Async<Result<'T, PodmanError>> = async {
        let activity = Tracing.startImageActivity operation imageName
        return! Metrics.measureAsync (sprintf "image.%s" operation) (Tracing.traceAsync activity work)
    }

    /// Execute a network operation with full instrumentation
    let networkOperation<'T>
        (operation: string)
        (networkName: string option)
        (work: Async<Result<'T, PodmanError>>)
        : Async<Result<'T, PodmanError>> = async {
        let activity = Tracing.startNetworkActivity operation networkName
        return! Metrics.measureAsync (sprintf "network.%s" operation) (Tracing.traceAsync activity work)
    }

    /// Execute a volume operation with full instrumentation
    let volumeOperation<'T>
        (operation: string)
        (volumeName: string option)
        (work: Async<Result<'T, PodmanError>>)
        : Async<Result<'T, PodmanError>> = async {
        let activity = Tracing.startVolumeActivity operation volumeName
        return! Metrics.measureAsync (sprintf "volume.%s" operation) (Tracing.traceAsync activity work)
    }

    /// Execute a system operation with full instrumentation
    let systemOperation<'T>
        (operation: string)
        (work: Async<Result<'T, PodmanError>>)
        : Async<Result<'T, PodmanError>> = async {
        let activity = Tracing.startSystemActivity operation
        return! Metrics.measureAsync (sprintf "system.%s" operation) (Tracing.traceAsync activity work)
    }
