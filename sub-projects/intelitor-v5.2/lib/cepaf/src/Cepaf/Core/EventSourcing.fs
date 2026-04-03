namespace Cepaf.Core

open System

/// Event Sourcing primitives for building event-sourced aggregates.
/// Provides infrastructure for events, aggregates, commands, and projections.
///
/// WHAT: Event sourcing infrastructure with aggregates, events, commands, projections
/// WHY: Enables audit trails, temporal queries, and eventual consistency patterns
/// CONSTRAINTS:
///   - SC-FSH-060: Events are immutable facts
///   - SC-FSH-061: Aggregates are derived from event stream
///   - SC-FSH-062: Commands must be validated before producing events
///
/// TDG Compliance:
///   - TDG-FSH-060: Event apply functions tested for all event types
///   - TDG-FSH-061: Aggregate reconstitution tested
///
/// AOR Compliance:
///   - AOR-FSH-030: Use event sourcing for audit-critical operations
module EventSourcing =

    // =========================================================================
    // EVENT INFRASTRUCTURE
    // =========================================================================

    /// Event metadata common to all events
    type EventMetadata = {
        EventId: Guid
        Timestamp: DateTimeOffset
        CorrelationId: Guid option
        CausationId: Guid option
        UserId: string option
        Version: int64
    }

    /// Create event metadata
    let createMetadata (version: int64) =
        {
            EventId = Guid.NewGuid()
            Timestamp = DateTimeOffset.UtcNow
            CorrelationId = None
            CausationId = None
            UserId = None
            Version = version
        }

    /// Event envelope wrapping an event with metadata
    type EventEnvelope<'Event> = {
        AggregateId: string
        AggregateType: string
        Event: 'Event
        Metadata: EventMetadata
    }

    /// Create an event envelope
    let envelope aggregateId aggregateType event version = {
        AggregateId = aggregateId
        AggregateType = aggregateType
        Event = event
        Metadata = createMetadata version
    }

    // =========================================================================
    // AGGREGATE INFRASTRUCTURE
    // =========================================================================

    /// Aggregate state with version tracking
    type AggregateState<'State> = {
        Id: string
        State: 'State
        Version: int64
        CreatedAt: DateTimeOffset
        UpdatedAt: DateTimeOffset
    }

    /// Aggregate root interface
    type IAggregate<'State, 'Event, 'Command> =
        abstract member Apply: 'State -> 'Event -> 'State
        abstract member Execute: 'State -> 'Command -> Result<'Event list, string>
        abstract member InitialState: 'State

    /// Create initial aggregate state
    let createAggregateState (id: string) (initial: 'State) = {
        Id = id
        State = initial
        Version = 0L
        CreatedAt = DateTimeOffset.UtcNow
        UpdatedAt = DateTimeOffset.UtcNow
    }

    /// Apply an event to aggregate state
    let applyEvent (apply: 'State -> 'Event -> 'State) (state: AggregateState<'State>) (event: 'Event) =
        {
            state with
                State = apply state.State event
                Version = state.Version + 1L
                UpdatedAt = DateTimeOffset.UtcNow
        }

    /// Apply multiple events to aggregate state
    let applyEvents (apply: 'State -> 'Event -> 'State) (state: AggregateState<'State>) (events: 'Event list) =
        events |> List.fold (applyEvent apply) state

    /// Reconstitute aggregate from event stream
    let reconstitute (id: string) (initial: 'State) (apply: 'State -> 'Event -> 'State) (events: 'Event list) =
        let state = createAggregateState id initial
        applyEvents apply state events

    // =========================================================================
    // COMMAND HANDLING
    // =========================================================================

    /// Command envelope with metadata
    type CommandEnvelope<'Command> = {
        CommandId: Guid
        AggregateId: string
        Command: 'Command
        Timestamp: DateTimeOffset
        UserId: string option
        CorrelationId: Guid option
    }

    /// Create a command envelope
    let command aggregateId cmd = {
        CommandId = Guid.NewGuid()
        AggregateId = aggregateId
        Command = cmd
        Timestamp = DateTimeOffset.UtcNow
        UserId = None
        CorrelationId = None
    }

    /// Command handler result
    type CommandResult<'Event> =
        | Accepted of 'Event list
        | Rejected of string
        | Conflict of string
        | NotFound of string

    /// Handle a command against aggregate state
    let handleCommand
        (execute: 'State -> 'Command -> Result<'Event list, string>)
        (state: AggregateState<'State>)
        (cmd: 'Command)
        : CommandResult<'Event> =
        match execute state.State cmd with
        | Ok events -> Accepted events
        | Error err -> Rejected err

    // =========================================================================
    // PROJECTION INFRASTRUCTURE
    // =========================================================================

    /// Projection state
    type ProjectionState<'S> = {
        State: 'S
        LastProcessedVersion: int64
        ProcessedCount: int64
        LastProcessedAt: DateTimeOffset option
    }

    /// Create initial projection state
    let createProjectionState initial = {
        State = initial
        LastProcessedVersion = -1L
        ProcessedCount = 0L
        LastProcessedAt = None
    }

    /// Projection handler function
    type ProjectionHandler<'S, 'E> = 'S -> EventEnvelope<'E> -> 'S

    /// Apply event to projection
    let projectEvent (handler: ProjectionHandler<'S, 'E>) (state: ProjectionState<'S>) (envelope: EventEnvelope<'E>) =
        {
            State = handler state.State envelope
            LastProcessedVersion = envelope.Metadata.Version
            ProcessedCount = state.ProcessedCount + 1L
            LastProcessedAt = Some DateTimeOffset.UtcNow
        }

    /// Apply multiple events to projection
    let projectEvents handler state envelopes =
        envelopes |> List.fold (projectEvent handler) state

    // =========================================================================
    // EVENT STORE ABSTRACTION
    // =========================================================================

    /// Event store operations (abstract interface)
    type IEventStore<'Event> =
        abstract member Append: string -> 'Event list -> int64 -> Async<Result<int64, string>>
        abstract member Read: string -> int64 -> int -> Async<EventEnvelope<'Event> list>
        abstract member ReadAll: string -> Async<EventEnvelope<'Event> list>

    /// In-memory event store for testing
    module InMemoryEventStore =
        type Store<'Event>() =
            let mutable streams = Map.empty<string, EventEnvelope<'Event> list>

            interface IEventStore<'Event> with
                member _.Append aggregateId events expectedVersion = async {
                    let stream = streams |> Map.tryFind aggregateId |> Option.defaultValue []
                    let currentVersion = int64 stream.Length

                    if expectedVersion >= 0L && currentVersion <> expectedVersion then
                        return Error $"Concurrency conflict: expected {expectedVersion}, actual {currentVersion}"
                    else
                        let envelopes =
                            events
                            |> List.mapi (fun i e ->
                                envelope aggregateId "Aggregate" e (currentVersion + int64 i + 1L))
                        streams <- Map.add aggregateId (stream @ envelopes) streams
                        return Ok (currentVersion + int64 events.Length)
                }

                member _.Read aggregateId fromVersion count = async {
                    let stream = streams |> Map.tryFind aggregateId |> Option.defaultValue []
                    return stream
                           |> List.filter (fun e -> e.Metadata.Version >= fromVersion)
                           |> List.truncate count
                }

                member _.ReadAll aggregateId = async {
                    return streams |> Map.tryFind aggregateId |> Option.defaultValue []
                }

    // =========================================================================
    // AGGREGATE REPOSITORY
    // =========================================================================

    /// Repository for loading and saving aggregates
    type Repository<'State, 'Event>(
        store: IEventStore<'Event>,
        initialState: 'State,
        apply: 'State -> 'Event -> 'State) =

        /// Load aggregate from event stream
        member _.Load(aggregateId: string) = async {
            let! events = store.ReadAll aggregateId
            let eventData = events |> List.map (fun e -> e.Event)
            return reconstitute aggregateId initialState apply eventData
        }

        /// Save new events to aggregate
        member _.Save(state: AggregateState<'State>, events: 'Event list) = async {
            return! store.Append state.Id events state.Version
        }

        /// Load, execute command, save result
        member this.Execute(aggregateId: string, execute: 'State -> Result<'Event list, string>) = async {
            let! state = this.Load(aggregateId)
            match execute state.State with
            | Ok [] -> return Ok (state, [])
            | Ok events ->
                let! result = this.Save(state, events)
                match result with
                | Ok version ->
                    let newState = applyEvents apply state events
                    return Ok (newState, events)
                | Error err -> return Error err
            | Error err -> return Error err
        }

    // =========================================================================
    // SNAPSHOT SUPPORT
    // =========================================================================

    /// Snapshot of aggregate state
    type Snapshot<'State> = {
        AggregateId: string
        State: 'State
        Version: int64
        TakenAt: DateTimeOffset
    }

    /// Create a snapshot
    let createSnapshot (state: AggregateState<'State>) = {
        AggregateId = state.Id
        State = state.State
        Version = state.Version
        TakenAt = DateTimeOffset.UtcNow
    }

    /// Load from snapshot and replay events since
    let loadFromSnapshot
        (snapshot: Snapshot<'State>)
        (apply: 'State -> 'Event -> 'State)
        (eventsSinceSnapshot: 'Event list) =
        let state = {
            Id = snapshot.AggregateId
            State = snapshot.State
            Version = snapshot.Version
            CreatedAt = snapshot.TakenAt // Approximation
            UpdatedAt = snapshot.TakenAt
        }
        applyEvents apply state eventsSinceSnapshot

    // =========================================================================
    // DOMAIN-SPECIFIC: AGENT AGGREGATE
    // =========================================================================

    module AgentAggregate =

        /// Agent events
        type AgentEvent =
            | AgentCreated of name: string * level: string
            | AgentActivated of taskId: string
            | AgentDeactivated of reason: string
            | AgentEfficiencyUpdated of efficiency: float
            | AgentTaskCompleted of taskId: string * success: bool
            | AgentBlocked of reason: string
            | AgentUnblocked

        /// Agent state
        type AgentState = {
            Name: string
            Level: string
            IsActive: bool
            CurrentTaskId: string option
            Efficiency: float
            CompletedTasks: int
            FailedTasks: int
            IsBlocked: bool
            BlockReason: string option
        }

        /// Initial agent state
        let initialState = {
            Name = ""
            Level = ""
            IsActive = false
            CurrentTaskId = None
            Efficiency = 100.0
            CompletedTasks = 0
            FailedTasks = 0
            IsBlocked = false
            BlockReason = None
        }

        /// Apply event to agent state
        let apply state event =
            match event with
            | AgentCreated (name, level) ->
                { state with Name = name; Level = level }
            | AgentActivated taskId ->
                { state with IsActive = true; CurrentTaskId = Some taskId }
            | AgentDeactivated _ ->
                { state with IsActive = false; CurrentTaskId = None }
            | AgentEfficiencyUpdated eff ->
                { state with Efficiency = eff }
            | AgentTaskCompleted (_, success) ->
                if success then
                    { state with CompletedTasks = state.CompletedTasks + 1; CurrentTaskId = None }
                else
                    { state with FailedTasks = state.FailedTasks + 1; CurrentTaskId = None }
            | AgentBlocked reason ->
                { state with IsBlocked = true; BlockReason = Some reason }
            | AgentUnblocked ->
                { state with IsBlocked = false; BlockReason = None }

        /// Agent commands
        type AgentCommand =
            | CreateAgent of name: string * level: string
            | ActivateAgent of taskId: string
            | DeactivateAgent of reason: string
            | UpdateEfficiency of efficiency: float
            | CompleteTask of taskId: string * success: bool
            | BlockAgent of reason: string
            | UnblockAgent

        /// Execute command
        let execute state command =
            match command with
            | CreateAgent (name, level) when state.Name = "" ->
                Ok [AgentCreated (name, level)]
            | CreateAgent _ ->
                Error "Agent already created"
            | ActivateAgent taskId when not state.IsActive && not state.IsBlocked ->
                Ok [AgentActivated taskId]
            | ActivateAgent _ when state.IsBlocked ->
                Error "Cannot activate blocked agent"
            | ActivateAgent _ ->
                Error "Agent already active"
            | DeactivateAgent reason when state.IsActive ->
                Ok [AgentDeactivated reason]
            | DeactivateAgent _ ->
                Error "Agent not active"
            | UpdateEfficiency eff when eff >= 0.0 && eff <= 100.0 ->
                Ok [AgentEfficiencyUpdated eff]
            | UpdateEfficiency _ ->
                Error "Efficiency must be between 0 and 100"
            | CompleteTask (taskId, success) when state.CurrentTaskId = Some taskId ->
                Ok [AgentTaskCompleted (taskId, success)]
            | CompleteTask _ ->
                Error "No matching task in progress"
            | BlockAgent reason when not state.IsBlocked ->
                Ok [AgentBlocked reason]
            | BlockAgent _ ->
                Error "Agent already blocked"
            | UnblockAgent when state.IsBlocked ->
                Ok [AgentUnblocked]
            | UnblockAgent ->
                Error "Agent not blocked"

    // =========================================================================
    // DOMAIN-SPECIFIC: CONTAINER AGGREGATE
    // =========================================================================

    module ContainerAggregate =

        /// Container events
        type ContainerEvent =
            | ContainerCreated of name: string * image: string
            | ContainerStarted
            | ContainerStopped of exitCode: int
            | ContainerHealthChecked of healthy: bool
            | ContainerRestarted of reason: string
            | ContainerRemoved

        /// Container state
        type ContainerState = {
            Name: string
            Image: string
            IsRunning: bool
            StartCount: int
            LastExitCode: int option
            IsHealthy: bool
            IsRemoved: bool
        }

        /// Initial container state
        let initialState = {
            Name = ""
            Image = ""
            IsRunning = false
            StartCount = 0
            LastExitCode = None
            IsHealthy = false
            IsRemoved = false
        }

        /// Apply event to container state
        let apply state event =
            match event with
            | ContainerCreated (name, image) ->
                { state with Name = name; Image = image }
            | ContainerStarted ->
                { state with IsRunning = true; StartCount = state.StartCount + 1 }
            | ContainerStopped exitCode ->
                { state with IsRunning = false; LastExitCode = Some exitCode }
            | ContainerHealthChecked healthy ->
                { state with IsHealthy = healthy }
            | ContainerRestarted _ ->
                { state with IsRunning = true; StartCount = state.StartCount + 1 }
            | ContainerRemoved ->
                { state with IsRemoved = true }

        /// Container commands
        type ContainerCommand =
            | CreateContainer of name: string * image: string
            | StartContainer
            | StopContainer of exitCode: int
            | HealthCheck of healthy: bool
            | RestartContainer of reason: string
            | RemoveContainer

        /// Execute command
        let execute state command =
            match command with
            | CreateContainer (name, image) when state.Name = "" ->
                Ok [ContainerCreated (name, image)]
            | CreateContainer _ ->
                Error "Container already created"
            | StartContainer when not state.IsRunning && not state.IsRemoved ->
                Ok [ContainerStarted]
            | StartContainer when state.IsRemoved ->
                Error "Cannot start removed container"
            | StartContainer ->
                Error "Container already running"
            | StopContainer exitCode when state.IsRunning ->
                Ok [ContainerStopped exitCode]
            | StopContainer _ ->
                Error "Container not running"
            | HealthCheck healthy when state.IsRunning ->
                Ok [ContainerHealthChecked healthy]
            | HealthCheck _ ->
                Error "Cannot health check stopped container"
            | RestartContainer reason when not state.IsRemoved ->
                if state.IsRunning then
                    Ok [ContainerStopped 0; ContainerRestarted reason]
                else
                    Ok [ContainerRestarted reason]
            | RestartContainer _ ->
                Error "Cannot restart removed container"
            | RemoveContainer when not state.IsRemoved ->
                if state.IsRunning then
                    Ok [ContainerStopped 137; ContainerRemoved]
                else
                    Ok [ContainerRemoved]
            | RemoveContainer ->
                Error "Container already removed"
