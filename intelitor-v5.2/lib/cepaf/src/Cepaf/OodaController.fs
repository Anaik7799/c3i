namespace Cepaf

open System
open System.Threading
open Cepaf.Podman.Domain
open Cepaf.Podman.Client
open Cepaf.Podman.Events
open Cepaf.Podman.Safety
open Cepaf.Core.Units  // SC-FSH-004: Units of Measure
open Cepaf.Core.ActivePatterns  // SC-FSH-003: Active Patterns for classification
open Cepaf.Core.Composition  // SC-FSH-010: Function composition

/// OODA Loop Controller for Cybernetic Container Management
/// Reference: GEMINI.md Section 3.0 - OODA Operational Model
module OodaController =

    // ========================================================================
    // OODA Phase Types (ordered for F# type dependency)
    // ========================================================================

    /// Observation severity levels
    type ObservationSeverity =
        | Info
        | Warning
        | Critical
        | Emergency

    /// Action from the Decide/Act phases (defined first for forward reference)
    type OodaAction =
        | RestartContainer of containerId: string
        | StopContainer of containerId: string
        | EmergencyStop of containerId: string * timeoutSeconds: int
        | ScaleUp of service: string * instances: int
        | ScaleDown of service: string * instances: int
        | HealthCheck of containerId: string
        | WaitAndRetry of reason: string * delayMs: int
        | AlertHuman of message: string * severity: ObservationSeverity
        | ApplyPatch of file: string * oldStr: string * newStr: string
        | NoAction of reason: string

    /// Orientation pattern classification
    type OrientationPattern =
        | ContainerStartup
        | ContainerFailure
        | HealthDegradation
        | ResourceExhaustion
        | NetworkIssue
        | SecurityViolation
        | PerformanceAnomaly
        | DependencyFailure
        | UnknownPattern

    /// Impact scope
    type ImpactScope =
        | SingleContainer
        | Pod
        | System

    /// Impact assessment
    type ImpactAssessment = {
        Scope: ImpactScope
        ServicesAffected: string list
        EstimatedRecoveryMs: int64
    }

    /// Orientation result from the Orient phase
    type Orientation = {
        Pattern: OrientationPattern
        RootCause: string option
        Impact: ImpactAssessment
        RecommendedActions: OodaAction list
    }

    /// Observation source
    type ObservationSource =
        | ContainerEvent of containerId: string
        | HealthProbe of containerId: string
        | MetricAlert of metricName: string
        | UserAction of action: string
        | SystemEvent of event: string

    /// Observation data
    type ObservationData =
        | EventData of PodmanEvent
        | HealthData of HealthStatus
        | MetricData of name: string * value: float
        | TextData of string

    /// Observation from the Observe phase
    type Observation = {
        Timestamp: DateTimeOffset
        Source: ObservationSource
        Data: ObservationData
        Severity: ObservationSeverity
    }

    /// OODA Loop State
    type OodaState = {
        LastObservation: Observation option
        LastOrientation: Orientation option
        ActionHistory: (DateTimeOffset * OodaAction * bool) list
        LoopCount: int64
        IsHealthy: bool
    }

    let initialState = {
        LastObservation = None
        LastOrientation = None
        ActionHistory = []
        LoopCount = 0L
        IsHealthy = true
    }

    // ========================================================================
    // Observe Phase - Collect environmental data
    // ========================================================================

    module Observe =
        /// Convert PodmanEvent to Observation
        let fromEvent (event: PodmanEvent) : Observation =
            let severity =
                match event.Action with
                | "die" | "kill" -> Critical
                | "stop" -> Warning
                | "start" | "create" -> Info
                | _ -> Info

            {
                Timestamp = PodmanEvent.getTimestamp event
                Source = ContainerEvent event.Actor.ID
                Data = EventData event
                Severity = severity
            }

        /// Create observation from health check
        let fromHealthCheck (containerId: string) (status: HealthStatus) : Observation =
            let severity =
                match status with
                | HealthStatus.Healthy -> Info
                | HealthStatus.Starting -> Info
                | HealthStatus.Unhealthy _ -> Critical
                | HealthStatus.NoHealthcheck -> Warning
                | HealthStatus.Unknown _ -> Warning

            {
                Timestamp = DateTimeOffset.UtcNow
                Source = HealthProbe containerId
                Data = HealthData status
                Severity = severity
            }

        /// Create observation from metric
        let fromMetric (name: string) (value: float) (threshold: float) : Observation =
            let severity = if value > threshold then Warning else Info
            {
                Timestamp = DateTimeOffset.UtcNow
                Source = MetricAlert name
                Data = MetricData(name, value)
                Severity = severity
            }

    // ========================================================================
    // Orient Phase - Analyze and classify observations
    // ========================================================================

    module Orient =
        /// Error pattern classification based on GEMINI.md EP-AGT patterns
        let classifyError (stderr: string) : OrientationPattern =
            if stderr.Contains("RUNN") then ContainerStartup
            elif stderr.Contains("address already in use") then NetworkIssue
            elif stderr.Contains("database system is starting up") then DependencyFailure
            elif stderr.Contains("out of memory") then ResourceExhaustion
            elif stderr.Contains("connection refused") then NetworkIssue
            elif stderr.Contains("permission denied") then SecurityViolation
            elif stderr.Contains("health check failed") then HealthDegradation
            elif stderr.Contains("timeout") then PerformanceAnomaly
            elif stderr.Contains("container not found") then ContainerFailure
            else UnknownPattern

        /// Orient based on observation
        let orient (observation: Observation) : Orientation =
            let (pattern, rootCause, actions) =
                match observation.Data with
                | EventData event ->
                    match event.Action with
                    | "die" | "kill" ->
                        (ContainerFailure,
                         Some (sprintf "Container %s terminated unexpectedly" event.Actor.ID),
                         [RestartContainer event.Actor.ID; AlertHuman("Container died", Critical)])
                    | "stop" ->
                        (ContainerFailure,
                         Some (sprintf "Container %s stopped" event.Actor.ID),
                         [NoAction "Normal stop"])
                    | "start" ->
                        (ContainerStartup,
                         None,
                         [HealthCheck event.Actor.ID])
                    | _ ->
                        (UnknownPattern, None, [NoAction "No action needed"])

                | HealthData status ->
                    // SC-FSH-003: Using Active Patterns for health classification
                    match status with
                    | HealthClassification.Failed ->
                        let failingStreak = match status with HealthStatus.Unhealthy n -> n | _ -> 0
                        let reason = sprintf "Container unhealthy - failing streak: %d" failingStreak
                        (HealthDegradation,
                         Some reason,
                         [AlertHuman(reason, Critical)])
                    | HealthClassification.Degraded ->
                        (ContainerStartup,
                         None,
                         [WaitAndRetry("Container starting", Timeout.toRawMs Timeout.normal)])  // SC-FSH-004
                    | HealthClassification.Operational ->
                        (UnknownPattern, None, [NoAction "Healthy"])
                    | HealthClassification.Unknown ->
                        (UnknownPattern, None, [NoAction "Health status unknown"])

                | MetricData(name, value) ->
                    if value > 90.0 then
                        (ResourceExhaustion,
                         Some (sprintf "%s at %.1f%%" name value),
                         [AlertHuman(sprintf "High %s: %.1f%%" name value, Warning)])
                    else
                        (UnknownPattern, None, [NoAction "Normal metrics"])

                | TextData text ->
                    let pattern = classifyError text
                    (pattern, Some text, [NoAction "Manual intervention may be needed"])

            let scope =
                match pattern with
                | ContainerFailure | HealthDegradation -> SingleContainer
                | DependencyFailure | NetworkIssue -> Pod
                | ResourceExhaustion | SecurityViolation -> System
                | _ -> SingleContainer

            {
                Pattern = pattern
                RootCause = rootCause
                Impact = {
                    Scope = scope
                    ServicesAffected = []
                    EstimatedRecoveryMs =
                        match pattern with
                        | ContainerStartup -> 5000L
                        | ContainerFailure -> 30000L
                        | ResourceExhaustion -> 60000L
                        | _ -> 10000L
                }
                RecommendedActions = actions
            }

    // ========================================================================
    // Decide Phase - Select best action
    // ========================================================================

    module Decide =
        /// Select the best action from recommendations
        let decide (orientation: Orientation) (state: OodaState) : OodaAction =
            match orientation.RecommendedActions with
            | [] -> NoAction "No actions recommended"
            | [single] -> single
            | actions ->
                // Prioritize based on severity and state
                let prioritized =
                    actions
                    |> List.sortBy (function
                        | EmergencyStop _ -> 0
                        | RestartContainer _ -> 1
                        | StopContainer _ -> 2
                        | AlertHuman(_, Critical) -> 3
                        | AlertHuman(_, Emergency) -> 2
                        | HealthCheck _ -> 4
                        | WaitAndRetry _ -> 5
                        | _ -> 10
                    )
                List.head prioritized

    // ========================================================================
    // Act Phase - Execute chosen action
    // ========================================================================

    module Act =
        open Cepaf.Podman.Api

        /// Execute an OODA action
        let execute (client: PodmanClient) (action: OodaAction) : Async<Result<unit, string>> = async {
            match action with
            | RestartContainer containerId ->
                let! stopResult = Containers.stop client containerId (Some 10)
                match stopResult with
                | Error e -> return Error (sprintf "Failed to stop: %A" e)
                | Ok () ->
                    let! startResult = Containers.start client containerId
                    return startResult |> Result.mapError (sprintf "Failed to start: %A")

            | StopContainer containerId ->
                let! result = Containers.stop client containerId (Some 10)
                return result |> Result.mapError (sprintf "Failed to stop: %A")

            | EmergencyStop (containerId, timeout) ->
                let! result = Constraints.emergencyStop client containerId timeout
                return result |> Result.mapError (sprintf "Emergency stop failed: %A")

            | HealthCheck containerId ->
                let! result = Containers.healthCheck client containerId
                match result with
                | Ok (HealthStatus.Healthy) -> return Ok ()
                | Ok status -> return Error (sprintf "Unhealthy: %A" status)
                | Error e -> return Error (sprintf "Health check failed: %A" e)

            | WaitAndRetry (_, delayMs) ->
                do! Async.Sleep delayMs
                return Ok ()

            | AlertHuman (message, severity) ->
                // Log alert (in production would send to alerting system)
                printfn "[ALERT][%A] %s" severity message
                return Ok ()

            | NoAction _ ->
                return Ok ()

            | _ ->
                return Error "Action not implemented"
        }

    // ========================================================================
    // OODA Loop Controller
    // ========================================================================

    type OodaLoop = {
        Client: PodmanClient
        State: OodaState
        CancellationToken: CancellationToken
    }

    /// Run a single OODA iteration
    let runIteration (loop: OodaLoop) (observation: Observation) : Async<OodaLoop> = async {
        // Orient
        let orientation = Orient.orient observation

        // Decide
        let action = Decide.decide orientation loop.State

        // Act
        let! result = Act.execute loop.Client action
        let success = Result.isOk result

        // Update state
        let newState = {
            loop.State with
                LastObservation = Some observation
                LastOrientation = Some orientation
                ActionHistory = (DateTimeOffset.UtcNow, action, success) :: loop.State.ActionHistory |> List.truncate 100
                LoopCount = loop.State.LoopCount + 1L
                IsHealthy = success
        }

        return { loop with State = newState }
    }

    /// Start continuous OODA loop monitoring
    let startMonitoring (client: PodmanClient) (cts: CancellationTokenSource) : Async<unit> = async {
        let mutable loop = {
            Client = client
            State = initialState
            CancellationToken = cts.Token
        }

        // Subscribe to container events
        let filter = EventFilter.empty |> EventFilter.containerEvents
        let events = Stream.stream client filter cts.Token

        let enumerator = events.GetAsyncEnumerator(cts.Token)

        try
            while not cts.Token.IsCancellationRequested do
                let! hasNext = enumerator.MoveNextAsync().AsTask() |> Async.AwaitTask
                if hasNext then
                    match enumerator.Current with
                    | Ok event ->
                        let observation = Observe.fromEvent event
                        let! newLoop = runIteration loop observation
                        loop <- newLoop
                    | Error _ -> ()  // Skip errors
        finally
            enumerator.DisposeAsync().AsTask() |> Async.AwaitTask |> Async.RunSynchronously
    }

    /// OODA metrics record type
    type OodaMetrics = {
        LoopCount: int64
        IsHealthy: bool
        LastObservationTime: DateTimeOffset option
        LastPattern: string option
        RecentActionCount: int
    }

    /// Get current OODA state metrics
    let getMetrics (state: OodaState) : OodaMetrics =
        {
            LoopCount = state.LoopCount
            IsHealthy = state.IsHealthy
            LastObservationTime = state.LastObservation |> Option.map (fun o -> o.Timestamp)
            LastPattern = state.LastOrientation |> Option.map (fun o -> sprintf "%A" o.Pattern)
            RecentActionCount = state.ActionHistory |> List.length |> min 10
        }
