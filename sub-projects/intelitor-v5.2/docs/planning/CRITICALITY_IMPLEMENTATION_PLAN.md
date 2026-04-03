# Criticality-Based Implementation Plan

## Indrajaal Planning & Task Execution System

**Version:** 1.0.0 | **Date:** January 2026 | **Methodology:** Criticality-First Development

---

## Overview

This plan organizes implementation into 7 criticality levels, from foundational (must work first) to polish (nice to have). Each level builds on the previous, ensuring a stable, testable system at every stage.

```
Level 1 [CRITICAL]     ████████████████████  Foundation - Nothing works without this
Level 2 [ESSENTIAL]    ████████████████░░░░  Persistence - Data must survive
Level 3 [IMPORTANT]    ████████████░░░░░░░░  Domain Logic - Business value
Level 4 [REQUIRED]     ████████░░░░░░░░░░░░  Integration - Connect to ecosystem
Level 5 [STANDARD]     ████░░░░░░░░░░░░░░░░  Interfaces - User interaction
Level 6 [ENHANCED]     ██░░░░░░░░░░░░░░░░░░  Intelligence - AI augmentation
Level 7 [POLISH]       █░░░░░░░░░░░░░░░░░░░  Optimization - Production ready
```

---

## Level 1: CRITICAL - Foundation [Blocks Everything]

**Risk if Missing:** System cannot start, compile, or function at all.
**Effort:** 2-3 days | **Dependencies:** None

### 1.1 Project Structure

```
lib/cepaf/src/Cepaf.Planning/
├── Cepaf.Planning.fsproj           # Project file (net10.0)
├── Core/
│   ├── Types.fs                    # Fundamental types
│   ├── Ids.fs                      # ID generation (ULID/UUID)
│   ├── Result.fs                   # Railway-oriented programming
│   └── Validation.fs               # Input validation
├── Domain/
│   ├── Task.fs                     # Task entity
│   ├── Priority.fs                 # Priority enum
│   ├── Status.fs                   # Status enum
│   └── Events.fs                   # Domain events
└── AssemblyInfo.fs
```

### 1.2 Files to Create

| File | Purpose | STAMP | Lines |
|------|---------|-------|-------|
| `Cepaf.Planning.fsproj` | Project definition | SC-NET-001 | ~50 |
| `Core/Types.fs` | Base types, Result<T>, Option<T> | SC-PLAN-001 | ~150 |
| `Core/Ids.fs` | TaskId, ProjectId, HolonId generation | SC-PLAN-002 | ~80 |
| `Core/Result.fs` | ROP bind, map, mapError | SC-PLAN-003 | ~100 |
| `Core/Validation.fs` | Validate inputs, constraints | SC-PLAN-004 | ~120 |
| `Domain/Task.fs` | Task record, create, update | SC-PLAN-005 | ~200 |
| `Domain/Priority.fs` | P0-P4 priority levels | SC-PLAN-006 | ~50 |
| `Domain/Status.fs` | Todo/InProgress/Done/Blocked | SC-PLAN-007 | ~60 |
| `Domain/Events.fs` | TaskCreated, TaskUpdated, etc. | SC-PLAN-008 | ~150 |

### 1.3 Acceptance Criteria

- [ ] `dotnet build` succeeds with 0 errors, 0 warnings
- [ ] All types compile and are usable
- [ ] Unit tests for ID generation pass
- [ ] Result monad operations work correctly

### 1.4 Code Specifications

```fsharp
// Core/Types.fs - Fundamental types
namespace Cepaf.Planning.Core

open System

/// Timestamp with timezone awareness
type Timestamp = DateTimeOffset

/// Non-empty string validation
type NonEmptyString = private NonEmptyString of string

module NonEmptyString =
    let create (s: string) =
        if String.IsNullOrWhiteSpace(s) then
            Error "String cannot be empty"
        else
            Ok (NonEmptyString s)

    let value (NonEmptyString s) = s

/// Positive integer validation
type PositiveInt = private PositiveInt of int

module PositiveInt =
    let create (n: int) =
        if n > 0 then Ok (PositiveInt n)
        else Error "Integer must be positive"

    let value (PositiveInt n) = n

/// Percentage (0-100)
type Percentage = private Percentage of float

module Percentage =
    let create (p: float) =
        if p >= 0.0 && p <= 100.0 then Ok (Percentage p)
        else Error "Percentage must be between 0 and 100"

    let value (Percentage p) = p
```

```fsharp
// Core/Ids.fs - ID generation
namespace Cepaf.Planning.Core

open System

/// ULID-based identifiers for lexicographic sorting
module Ids =

    type TaskId = TaskId of string
    type ProjectId = ProjectId of string
    type SprintId = SprintId of string
    type UserId = UserId of string
    type HolonId = HolonId of string

    /// Generate new ULID
    let private generateUlid () =
        let timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        let random = Random.Shared.NextInt64()
        sprintf "%010X%016X" timestamp random

    let newTaskId () = TaskId (generateUlid ())
    let newProjectId () = ProjectId (generateUlid ())
    let newSprintId () = SprintId (generateUlid ())
    let newUserId () = UserId (generateUlid ())
    let newHolonId () = HolonId (generateUlid ())

    let taskIdValue (TaskId id) = id
    let projectIdValue (ProjectId id) = id
```

```fsharp
// Core/Result.fs - Railway-oriented programming
namespace Cepaf.Planning.Core

/// Railway-oriented programming primitives
[<RequireQualifiedAccess>]
module Result =

    let bind f result =
        match result with
        | Ok x -> f x
        | Error e -> Error e

    let map f result =
        match result with
        | Ok x -> Ok (f x)
        | Error e -> Error e

    let mapError f result =
        match result with
        | Ok x -> Ok x
        | Error e -> Error (f e)

    let apply fResult xResult =
        match fResult, xResult with
        | Ok f, Ok x -> Ok (f x)
        | Error e, _ -> Error e
        | _, Error e -> Error e

    /// Combine multiple results
    let sequence results =
        let folder state result =
            match state, result with
            | Ok acc, Ok x -> Ok (x :: acc)
            | Error e, _ -> Error e
            | _, Error e -> Error e
        results |> List.fold folder (Ok []) |> Result.map List.rev

    /// Try-catch wrapper
    let tryWith f =
        try Ok (f ())
        with ex -> Error ex.Message

/// Computation expression for Result
type ResultBuilder() =
    member _.Bind(m, f) = Result.bind f m
    member _.Return(x) = Ok x
    member _.ReturnFrom(m) = m
    member _.Zero() = Ok ()

let result = ResultBuilder()
```

```fsharp
// Domain/Task.fs - Core task entity
namespace Cepaf.Planning.Domain

open System
open Cepaf.Planning.Core

/// Task priority levels (military-style)
type Priority =
    | P0_Critical   // Immediate action required
    | P1_High       // Same day
    | P2_Medium     // This week
    | P3_Low        // This month
    | P4_Backlog    // When possible

/// Task status
type TaskStatus =
    | Todo
    | InProgress
    | Done
    | Blocked of reason: string
    | Cancelled of reason: string

/// Core task entity
type Task = {
    Id: Ids.TaskId
    Title: NonEmptyString
    Description: string option
    Status: TaskStatus
    Priority: Priority
    CreatedAt: Timestamp
    UpdatedAt: Timestamp
    DueDate: Timestamp option
    AssigneeId: Ids.UserId option
    ProjectId: Ids.ProjectId option
    ParentTaskId: Ids.TaskId option
    Tags: Set<string>
    EstimatedMinutes: PositiveInt option
    ActualMinutes: PositiveInt option
}

module Task =

    /// Create a new task
    let create (title: string) (priority: Priority) : Result<Task, string> =
        result {
            let! validTitle = NonEmptyString.create title
            let now = DateTimeOffset.UtcNow
            return {
                Id = Ids.newTaskId ()
                Title = validTitle
                Description = None
                Status = Todo
                Priority = priority
                CreatedAt = now
                UpdatedAt = now
                DueDate = None
                AssigneeId = None
                ProjectId = None
                ParentTaskId = None
                Tags = Set.empty
                EstimatedMinutes = None
                ActualMinutes = None
            }
        }

    /// Update task status
    let updateStatus (newStatus: TaskStatus) (task: Task) : Task =
        { task with
            Status = newStatus
            UpdatedAt = DateTimeOffset.UtcNow }

    /// Assign task to user
    let assign (userId: Ids.UserId option) (task: Task) : Task =
        { task with
            AssigneeId = userId
            UpdatedAt = DateTimeOffset.UtcNow }

    /// Set priority
    let setPriority (priority: Priority) (task: Task) : Task =
        { task with
            Priority = priority
            UpdatedAt = DateTimeOffset.UtcNow }

    /// Add tag
    let addTag (tag: string) (task: Task) : Task =
        { task with
            Tags = task.Tags |> Set.add tag
            UpdatedAt = DateTimeOffset.UtcNow }

    /// Check if task is complete
    let isComplete (task: Task) : bool =
        match task.Status with
        | Done | Cancelled _ -> true
        | _ -> false

    /// Check if task is blocked
    let isBlocked (task: Task) : bool =
        match task.Status with
        | Blocked _ -> true
        | _ -> false
```

```fsharp
// Domain/Events.fs - Domain events for event sourcing
namespace Cepaf.Planning.Domain

open System
open Cepaf.Planning.Core

/// Domain events (immutable facts)
type TaskEvent =
    | TaskCreated of {|
        TaskId: Ids.TaskId
        Title: string
        Priority: Priority
        CreatedBy: Ids.UserId option
        Timestamp: Timestamp
      |}
    | TaskUpdated of {|
        TaskId: Ids.TaskId
        Field: string
        OldValue: string
        NewValue: string
        UpdatedBy: Ids.UserId option
        Timestamp: Timestamp
      |}
    | TaskStatusChanged of {|
        TaskId: Ids.TaskId
        OldStatus: TaskStatus
        NewStatus: TaskStatus
        ChangedBy: Ids.UserId option
        Timestamp: Timestamp
      |}
    | TaskAssigned of {|
        TaskId: Ids.TaskId
        OldAssignee: Ids.UserId option
        NewAssignee: Ids.UserId option
        AssignedBy: Ids.UserId option
        Timestamp: Timestamp
      |}
    | TaskCompleted of {|
        TaskId: Ids.TaskId
        CompletedBy: Ids.UserId option
        ActualMinutes: int option
        Timestamp: Timestamp
      |}
    | TaskDeleted of {|
        TaskId: Ids.TaskId
        DeletedBy: Ids.UserId option
        Reason: string option
        Timestamp: Timestamp
      |}

/// Event metadata
type EventMetadata = {
    EventId: Guid
    AggregateId: string
    AggregateType: string
    Version: int64
    Timestamp: Timestamp
    CorrelationId: Guid option
    CausationId: Guid option
}

/// Envelope for events
type EventEnvelope<'T> = {
    Metadata: EventMetadata
    Event: 'T
}

module Events =

    let createMetadata aggregateId aggregateType version =
        {
            EventId = Guid.NewGuid()
            AggregateId = aggregateId
            AggregateType = aggregateType
            Version = version
            Timestamp = DateTimeOffset.UtcNow
            CorrelationId = None
            CausationId = None
        }

    let wrap event metadata =
        { Metadata = metadata; Event = event }
```

---

## Level 2: ESSENTIAL - Persistence [Data Survival]

**Risk if Missing:** Data is lost on restart, no history, no recovery.
**Effort:** 3-4 days | **Dependencies:** Level 1

### 2.1 Files to Create

| File | Purpose | STAMP | Lines |
|------|---------|-------|-------|
| `Infrastructure/EventStore.fs` | Append-only event storage | SC-PLAN-010 | ~300 |
| `Infrastructure/SQLiteStore.fs` | SQLite implementation | SC-PLAN-011 | ~250 |
| `Infrastructure/DuckDBStore.fs` | DuckDB for analytics | SC-PLAN-012 | ~200 |
| `Infrastructure/Projections.fs` | Event to read model | SC-PLAN-013 | ~200 |
| `Infrastructure/Repository.fs` | Aggregate persistence | SC-PLAN-014 | ~150 |

### 2.2 Code Specifications

```fsharp
// Infrastructure/EventStore.fs - Event sourcing storage
namespace Cepaf.Planning.Infrastructure

open System
open Cepaf.Planning.Core
open Cepaf.Planning.Domain

/// Event store interface (SMRITI-compatible)
type IEventStore =
    /// Append events to stream
    abstract AppendToStream:
        streamId: string ->
        expectedVersion: int64 ->
        events: EventEnvelope<TaskEvent> list ->
        Async<Result<int64, string>>

    /// Read events from stream
    abstract ReadStream:
        streamId: string ->
        fromVersion: int64 ->
        maxCount: int ->
        Async<Result<EventEnvelope<TaskEvent> list, string>>

    /// Read all events (for projections)
    abstract ReadAllEvents:
        fromPosition: int64 ->
        maxCount: int ->
        Async<Result<EventEnvelope<TaskEvent> list, string>>

/// In-memory event store (for testing)
module InMemoryEventStore =

    type State = {
        Events: Map<string, EventEnvelope<TaskEvent> list>
        GlobalPosition: int64
    }

    let empty = { Events = Map.empty; GlobalPosition = 0L }

    let appendToStream streamId expectedVersion events state =
        let currentEvents =
            state.Events
            |> Map.tryFind streamId
            |> Option.defaultValue []

        let currentVersion = int64 currentEvents.Length

        if expectedVersion >= 0L && expectedVersion <> currentVersion then
            Error (sprintf "Concurrency conflict: expected %d, got %d" expectedVersion currentVersion)
        else
            let newEvents = currentEvents @ events
            let newState = {
                Events = state.Events |> Map.add streamId newEvents
                GlobalPosition = state.GlobalPosition + int64 events.Length
            }
            Ok (int64 newEvents.Length, newState)
```

```fsharp
// Infrastructure/SQLiteStore.fs - SQLite event store
namespace Cepaf.Planning.Infrastructure

open System
open System.Data
open Microsoft.Data.Sqlite
open Cepaf.Planning.Core
open Cepaf.Planning.Domain

/// SQLite-based event store (SMRITI-compatible)
module SQLiteEventStore =

    /// Connection string builder
    let connectionString (dbPath: string) =
        sprintf "Data Source=%s;Mode=ReadWriteCreate;Cache=Shared" dbPath

    /// Initialize database schema
    let initializeSchema (conn: SqliteConnection) =
        let sql = """
            CREATE TABLE IF NOT EXISTS events (
                global_position INTEGER PRIMARY KEY AUTOINCREMENT,
                stream_id TEXT NOT NULL,
                version INTEGER NOT NULL,
                event_id TEXT NOT NULL UNIQUE,
                event_type TEXT NOT NULL,
                event_data TEXT NOT NULL,
                metadata TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                UNIQUE(stream_id, version)
            );

            CREATE INDEX IF NOT EXISTS idx_events_stream ON events(stream_id, version);
            CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);

            CREATE TABLE IF NOT EXISTS snapshots (
                stream_id TEXT PRIMARY KEY,
                version INTEGER NOT NULL,
                snapshot_data TEXT NOT NULL,
                timestamp TEXT NOT NULL
            );

            -- Enable WAL mode for better concurrency
            PRAGMA journal_mode=WAL;
            PRAGMA synchronous=NORMAL;
            PRAGMA cache_size=10000;
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.ExecuteNonQuery() |> ignore

    /// Serialize event to JSON
    let serializeEvent (event: TaskEvent) : string =
        System.Text.Json.JsonSerializer.Serialize(event)

    /// Deserialize event from JSON
    let deserializeEvent (json: string) : Result<TaskEvent, string> =
        try
            Ok (System.Text.Json.JsonSerializer.Deserialize<TaskEvent>(json))
        with ex ->
            Error (sprintf "Failed to deserialize event: %s" ex.Message)

    /// Append events to stream
    let appendToStream
        (conn: SqliteConnection)
        (streamId: string)
        (expectedVersion: int64)
        (events: EventEnvelope<TaskEvent> list)
        : Async<Result<int64, string>> =
        async {
            try
                use transaction = conn.BeginTransaction()

                // Check current version
                let versionSql = "SELECT COALESCE(MAX(version), -1) FROM events WHERE stream_id = @streamId"
                use versionCmd = new SqliteCommand(versionSql, conn, transaction)
                versionCmd.Parameters.AddWithValue("@streamId", streamId) |> ignore
                let currentVersion = versionCmd.ExecuteScalar() :?> int64

                if expectedVersion >= 0L && expectedVersion <> currentVersion then
                    return Error (sprintf "Concurrency conflict: expected %d, got %d" expectedVersion currentVersion)
                else
                    // Insert events
                    let insertSql = """
                        INSERT INTO events (stream_id, version, event_id, event_type, event_data, metadata, timestamp)
                        VALUES (@streamId, @version, @eventId, @eventType, @eventData, @metadata, @timestamp)
                    """

                    let mutable newVersion = currentVersion
                    for envelope in events do
                        newVersion <- newVersion + 1L
                        use insertCmd = new SqliteCommand(insertSql, conn, transaction)
                        insertCmd.Parameters.AddWithValue("@streamId", streamId) |> ignore
                        insertCmd.Parameters.AddWithValue("@version", newVersion) |> ignore
                        insertCmd.Parameters.AddWithValue("@eventId", envelope.Metadata.EventId.ToString()) |> ignore
                        insertCmd.Parameters.AddWithValue("@eventType", envelope.Event.GetType().Name) |> ignore
                        insertCmd.Parameters.AddWithValue("@eventData", serializeEvent envelope.Event) |> ignore
                        insertCmd.Parameters.AddWithValue("@metadata", "{}") |> ignore
                        insertCmd.Parameters.AddWithValue("@timestamp", envelope.Metadata.Timestamp.ToString("O")) |> ignore
                        insertCmd.ExecuteNonQuery() |> ignore

                    transaction.Commit()
                    return Ok newVersion
            with ex ->
                return Error (sprintf "Failed to append events: %s" ex.Message)
        }

    /// Read events from stream
    let readStream
        (conn: SqliteConnection)
        (streamId: string)
        (fromVersion: int64)
        (maxCount: int)
        : Async<Result<EventEnvelope<TaskEvent> list, string>> =
        async {
            try
                let sql = """
                    SELECT event_id, event_type, event_data, metadata, timestamp, version
                    FROM events
                    WHERE stream_id = @streamId AND version > @fromVersion
                    ORDER BY version
                    LIMIT @maxCount
                """
                use cmd = new SqliteCommand(sql, conn)
                cmd.Parameters.AddWithValue("@streamId", streamId) |> ignore
                cmd.Parameters.AddWithValue("@fromVersion", fromVersion) |> ignore
                cmd.Parameters.AddWithValue("@maxCount", maxCount) |> ignore

                use reader = cmd.ExecuteReader()
                let events = ResizeArray<EventEnvelope<TaskEvent>>()

                while reader.Read() do
                    let eventData = reader.GetString(2)
                    match deserializeEvent eventData with
                    | Ok event ->
                        let envelope = {
                            Metadata = {
                                EventId = Guid.Parse(reader.GetString(0))
                                AggregateId = streamId
                                AggregateType = "Task"
                                Version = reader.GetInt64(5)
                                Timestamp = DateTimeOffset.Parse(reader.GetString(4))
                                CorrelationId = None
                                CausationId = None
                            }
                            Event = event
                        }
                        events.Add(envelope)
                    | Error _ -> ()

                return Ok (events |> Seq.toList)
            with ex ->
                return Error (sprintf "Failed to read events: %s" ex.Message)
        }
```

```fsharp
// Infrastructure/Projections.fs - Read model projections
namespace Cepaf.Planning.Infrastructure

open Cepaf.Planning.Core
open Cepaf.Planning.Domain

/// Task read model (denormalized for queries)
type TaskReadModel = {
    Id: string
    Title: string
    Description: string option
    Status: string
    Priority: string
    CreatedAt: string
    UpdatedAt: string
    DueDate: string option
    AssigneeId: string option
    ProjectId: string option
    Tags: string list
    IsComplete: bool
    IsBlocked: bool
}

/// Project events to read model
module TaskProjection =

    let empty : TaskReadModel option = None

    let apply (state: TaskReadModel option) (event: TaskEvent) : TaskReadModel option =
        match event with
        | TaskCreated data ->
            Some {
                Id = Ids.taskIdValue data.TaskId
                Title = data.Title
                Description = None
                Status = "Todo"
                Priority = sprintf "%A" data.Priority
                CreatedAt = data.Timestamp.ToString("O")
                UpdatedAt = data.Timestamp.ToString("O")
                DueDate = None
                AssigneeId = None
                ProjectId = None
                Tags = []
                IsComplete = false
                IsBlocked = false
            }

        | TaskStatusChanged data ->
            state |> Option.map (fun s ->
                { s with
                    Status = sprintf "%A" data.NewStatus
                    UpdatedAt = data.Timestamp.ToString("O")
                    IsComplete = match data.NewStatus with Done | Cancelled _ -> true | _ -> false
                    IsBlocked = match data.NewStatus with Blocked _ -> true | _ -> false
                })

        | TaskAssigned data ->
            state |> Option.map (fun s ->
                { s with
                    AssigneeId = data.NewAssignee |> Option.map Ids.userIdValue
                    UpdatedAt = data.Timestamp.ToString("O")
                })

        | TaskCompleted data ->
            state |> Option.map (fun s ->
                { s with
                    Status = "Done"
                    IsComplete = true
                    UpdatedAt = data.Timestamp.ToString("O")
                })

        | TaskDeleted _ ->
            None

        | TaskUpdated data ->
            state |> Option.map (fun s ->
                { s with UpdatedAt = data.Timestamp.ToString("O") })

    /// Rebuild read model from events
    let rebuild (events: TaskEvent list) : TaskReadModel option =
        events |> List.fold apply empty
```

### 2.3 Acceptance Criteria

- [ ] Events persist to SQLite and survive restart
- [ ] Event versioning prevents conflicts
- [ ] Projections rebuild state from events
- [ ] WAL mode enabled for concurrency

---

## Level 3: IMPORTANT - Domain Logic [Business Value]

**Risk if Missing:** System stores data but provides no planning functionality.
**Effort:** 4-5 days | **Dependencies:** Level 1, 2

### 3.1 Files to Create

| File | Purpose | STAMP | Lines |
|------|---------|-------|-------|
| `Domain/Project.fs` | Project aggregate | SC-PLAN-020 | ~200 |
| `Domain/Sprint.fs` | Sprint entity | SC-PLAN-021 | ~180 |
| `Domain/OODA.fs` | OODA loop engine | SC-PLAN-022 | ~350 |
| `Domain/Priority.fs` | Eisenhower matrix | SC-PLAN-023 | ~150 |
| `Domain/Dependencies.fs` | Task dependencies | SC-PLAN-024 | ~200 |
| `Application/Commands.fs` | Command handlers | SC-PLAN-025 | ~300 |
| `Application/Queries.fs` | Query handlers | SC-PLAN-026 | ~250 |

### 3.2 Code Specifications

```fsharp
// Domain/OODA.fs - OODA Loop Engine
namespace Cepaf.Planning.Domain

open System
open Cepaf.Planning.Core

/// OODA Loop phases
type OODAPhase =
    | Observe
    | Orient
    | Decide
    | Act

/// Observation data
type Observation = {
    Id: Guid
    Source: string
    Content: string
    Timestamp: Timestamp
    Confidence: float
    Tags: Set<string>
}

/// Orientation analysis
type Orientation = {
    Observations: Observation list
    Patterns: string list
    Threats: string list
    Opportunities: string list
    Constraints: string list
    Analysis: string
}

/// Decision option (Course of Action)
type CourseOfAction = {
    Id: Guid
    Name: string
    Description: string
    Pros: string list
    Cons: string list
    Risk: float
    Effort: float
    Impact: float
    Score: float
}

/// Action to execute
type OODAAction = {
    Id: Guid
    COAId: Guid
    Description: string
    TaskIds: Ids.TaskId list
    StartedAt: Timestamp option
    CompletedAt: Timestamp option
    Result: string option
}

/// OODA cycle state
type OODACycle = {
    Id: Guid
    ContextId: string  // Task, Project, or Sprint ID
    Phase: OODAPhase
    Observations: Observation list
    Orientation: Orientation option
    COAs: CourseOfAction list
    SelectedCOA: Guid option
    Actions: OODAAction list
    StartedAt: Timestamp
    CompletedAt: Timestamp option
    CycleTimeMs: int64 option
}

module OODA =

    /// Create new OODA cycle
    let startCycle (contextId: string) : OODACycle =
        {
            Id = Guid.NewGuid()
            ContextId = contextId
            Phase = Observe
            Observations = []
            Orientation = None
            COAs = []
            SelectedCOA = None
            Actions = []
            StartedAt = DateTimeOffset.UtcNow
            CompletedAt = None
            CycleTimeMs = None
        }

    /// Add observation
    let observe (source: string) (content: string) (confidence: float) (cycle: OODACycle) : OODACycle =
        let observation = {
            Id = Guid.NewGuid()
            Source = source
            Content = content
            Timestamp = DateTimeOffset.UtcNow
            Confidence = confidence
            Tags = Set.empty
        }
        { cycle with
            Observations = observation :: cycle.Observations
            Phase = Observe }

    /// Perform orientation analysis
    let orient (analysis: string) (patterns: string list) (threats: string list) (opportunities: string list) (cycle: OODACycle) : OODACycle =
        let orientation = {
            Observations = cycle.Observations
            Patterns = patterns
            Threats = threats
            Opportunities = opportunities
            Constraints = []
            Analysis = analysis
        }
        { cycle with
            Orientation = Some orientation
            Phase = Orient }

    /// Add course of action
    let addCOA (name: string) (description: string) (pros: string list) (cons: string list) (risk: float) (effort: float) (impact: float) (cycle: OODACycle) : OODACycle =
        let score = (impact * (1.0 - risk)) / (effort + 0.1)  // Simple scoring formula
        let coa = {
            Id = Guid.NewGuid()
            Name = name
            Description = description
            Pros = pros
            Cons = cons
            Risk = risk
            Effort = effort
            Impact = impact
            Score = score
        }
        { cycle with
            COAs = coa :: cycle.COAs
            Phase = Decide }

    /// Select best COA
    let decide (coaId: Guid) (cycle: OODACycle) : OODACycle =
        { cycle with
            SelectedCOA = Some coaId
            Phase = Decide }

    /// Auto-select best COA by score
    let autoDecide (cycle: OODACycle) : OODACycle =
        let bestCOA =
            cycle.COAs
            |> List.sortByDescending (fun c -> c.Score)
            |> List.tryHead
        { cycle with
            SelectedCOA = bestCOA |> Option.map (fun c -> c.Id)
            Phase = Decide }

    /// Execute action
    let act (description: string) (taskIds: Ids.TaskId list) (cycle: OODACycle) : OODACycle =
        let action = {
            Id = Guid.NewGuid()
            COAId = cycle.SelectedCOA |> Option.defaultValue Guid.Empty
            Description = description
            TaskIds = taskIds
            StartedAt = Some DateTimeOffset.UtcNow
            CompletedAt = None
            Result = None
        }
        { cycle with
            Actions = action :: cycle.Actions
            Phase = Act }

    /// Complete cycle
    let completeCycle (cycle: OODACycle) : OODACycle =
        let now = DateTimeOffset.UtcNow
        let cycleTime = (now - cycle.StartedAt).TotalMilliseconds |> int64
        { cycle with
            CompletedAt = Some now
            CycleTimeMs = Some cycleTime }

    /// Get cycle duration in ms
    let getCycleTime (cycle: OODACycle) : int64 =
        match cycle.CycleTimeMs with
        | Some ms -> ms
        | None ->
            let now = DateTimeOffset.UtcNow
            (now - cycle.StartedAt).TotalMilliseconds |> int64
```

```fsharp
// Application/Commands.fs - Command handlers
namespace Cepaf.Planning.Application

open System
open Cepaf.Planning.Core
open Cepaf.Planning.Domain
open Cepaf.Planning.Infrastructure

/// Command types
type Command =
    | CreateTask of title: string * priority: Priority * projectId: Ids.ProjectId option
    | UpdateTaskStatus of taskId: Ids.TaskId * newStatus: TaskStatus
    | AssignTask of taskId: Ids.TaskId * assigneeId: Ids.UserId option
    | SetTaskPriority of taskId: Ids.TaskId * priority: Priority
    | AddTaskTag of taskId: Ids.TaskId * tag: string
    | DeleteTask of taskId: Ids.TaskId * reason: string option
    | StartOODACycle of contextId: string
    | AddObservation of cycleId: Guid * source: string * content: string
    | SelectCOA of cycleId: Guid * coaId: Guid
    | ExecuteAction of cycleId: Guid * description: string

/// Command result
type CommandResult =
    | TaskCreated of Ids.TaskId
    | TaskUpdated of Ids.TaskId
    | TaskDeleted of Ids.TaskId
    | OODACycleStarted of Guid
    | OODACycleUpdated of Guid
    | CommandFailed of string

/// Command handler
module CommandHandler =

    /// Handle create task command
    let handleCreateTask
        (store: IEventStore)
        (title: string)
        (priority: Priority)
        (projectId: Ids.ProjectId option)
        (userId: Ids.UserId option)
        : Async<Result<CommandResult, string>> =
        async {
            match Task.create title priority with
            | Ok task ->
                let event = TaskCreated {|
                    TaskId = task.Id
                    Title = NonEmptyString.value task.Title
                    Priority = priority
                    CreatedBy = userId
                    Timestamp = DateTimeOffset.UtcNow
                |}
                let metadata = Events.createMetadata (Ids.taskIdValue task.Id) "Task" 0L
                let envelope = Events.wrap event metadata

                let streamId = sprintf "task-%s" (Ids.taskIdValue task.Id)
                let! result = store.AppendToStream streamId -1L [envelope]

                match result with
                | Ok _ -> return Ok (TaskCreated task.Id)
                | Error e -> return Error e
            | Error e ->
                return Error e
        }

    /// Handle update status command
    let handleUpdateStatus
        (store: IEventStore)
        (taskId: Ids.TaskId)
        (newStatus: TaskStatus)
        (userId: Ids.UserId option)
        : Async<Result<CommandResult, string>> =
        async {
            let streamId = sprintf "task-%s" (Ids.taskIdValue taskId)
            let! eventsResult = store.ReadStream streamId 0L 1000

            match eventsResult with
            | Ok events when events.Length > 0 ->
                // Get current state
                let currentState =
                    events
                    |> List.map (fun e -> e.Event)
                    |> TaskProjection.rebuild

                match currentState with
                | Some state ->
                    let oldStatus =
                        match state.Status with
                        | "Todo" -> Todo
                        | "InProgress" -> InProgress
                        | "Done" -> Done
                        | s when s.StartsWith("Blocked") -> Blocked ""
                        | _ -> Todo

                    let event = TaskStatusChanged {|
                        TaskId = taskId
                        OldStatus = oldStatus
                        NewStatus = newStatus
                        ChangedBy = userId
                        Timestamp = DateTimeOffset.UtcNow
                    |}

                    let version = int64 events.Length
                    let metadata = Events.createMetadata (Ids.taskIdValue taskId) "Task" version
                    let envelope = Events.wrap event metadata

                    let! appendResult = store.AppendToStream streamId (version - 1L) [envelope]

                    match appendResult with
                    | Ok _ -> return Ok (TaskUpdated taskId)
                    | Error e -> return Error e
                | None ->
                    return Error "Task not found"
            | Ok _ ->
                return Error "Task not found"
            | Error e ->
                return Error e
        }

    /// Dispatch command to appropriate handler
    let dispatch
        (store: IEventStore)
        (userId: Ids.UserId option)
        (command: Command)
        : Async<Result<CommandResult, string>> =
        async {
            match command with
            | CreateTask (title, priority, projectId) ->
                return! handleCreateTask store title priority projectId userId
            | UpdateTaskStatus (taskId, newStatus) ->
                return! handleUpdateStatus store taskId newStatus userId
            | _ ->
                return Error "Command not implemented"
        }
```

### 3.3 Acceptance Criteria

- [ ] OODA cycle completes in <100ms
- [ ] Tasks can be created, updated, deleted
- [ ] Dependencies track blocking relationships
- [ ] Eisenhower matrix categorizes correctly

---

## Level 4: REQUIRED - Integration [Ecosystem Connection]

**Risk if Missing:** System works in isolation, no real-world connectivity.
**Effort:** 4-5 days | **Dependencies:** Level 1, 2, 3

### 4.1 Files to Create

| File | Purpose | STAMP | Lines |
|------|---------|-------|-------|
| `Integration/ZenohBridge.fs` | Zenoh pub/sub | SC-PLAN-030 | ~300 |
| `Integration/CortexClient.fs` | OpenRouter AI | SC-PLAN-031 | ~250 |
| `Integration/ElixirBridge.fs` | Prajna interop | SC-PLAN-032 | ~200 |
| `Integration/GuardianClient.fs` | Approval flow | SC-PLAN-033 | ~150 |

### 4.2 Code Specifications

```fsharp
// Integration/ZenohBridge.fs - Zenoh messaging
namespace Cepaf.Planning.Integration

open System
open System.Text.Json

/// Zenoh topic patterns
module ZenohTopics =
    let taskCreated = "indrajaal/planning/tasks/created"
    let taskUpdated = "indrajaal/planning/tasks/updated"
    let oodaCycle = "indrajaal/planning/ooda/cycle"
    let commands = "indrajaal/planning/commands"
    let queries = "indrajaal/planning/queries"

/// Zenoh message envelope
type ZenohMessage<'T> = {
    Topic: string
    Payload: 'T
    Timestamp: DateTimeOffset
    CorrelationId: Guid option
}

/// Zenoh bridge interface
type IZenohBridge =
    abstract Publish: topic: string -> payload: 'T -> Async<Result<unit, string>>
    abstract Subscribe: topic: string -> handler: (string -> unit) -> Async<Result<unit, string>>

/// Mock Zenoh bridge (for development without Zenoh)
module MockZenohBridge =

    let mutable subscribers : Map<string, (string -> unit) list> = Map.empty

    let publish (topic: string) (payload: 'T) : Async<Result<unit, string>> =
        async {
            let json = JsonSerializer.Serialize(payload)
            printfn "[Zenoh] Publishing to %s: %s" topic json

            // Notify subscribers
            match subscribers |> Map.tryFind topic with
            | Some handlers ->
                handlers |> List.iter (fun h -> h json)
            | None -> ()

            return Ok ()
        }

    let subscribe (topic: string) (handler: string -> unit) : Async<Result<unit, string>> =
        async {
            let existing = subscribers |> Map.tryFind topic |> Option.defaultValue []
            subscribers <- subscribers |> Map.add topic (handler :: existing)
            printfn "[Zenoh] Subscribed to %s" topic
            return Ok ()
        }
```

```fsharp
// Integration/CortexClient.fs - OpenRouter AI client
namespace Cepaf.Planning.Integration

open System
open System.Net.Http
open System.Text.Json

/// OpenRouter model selection
type AIModel =
    | ClaudeSonnet
    | GeminiFlash
    | Grok
    | LocalLlama

/// AI request
type AIRequest = {
    Model: AIModel
    Prompt: string
    MaxTokens: int
    Temperature: float
}

/// AI response
type AIResponse = {
    Content: string
    Model: string
    TokensUsed: int
    Latency: TimeSpan
}

/// Cortex AI client (via OpenRouter)
module CortexClient =

    let private modelToString = function
        | ClaudeSonnet -> "anthropic/claude-3.5-sonnet"
        | GeminiFlash -> "google/gemini-flash-1.5"
        | Grok -> "x-ai/grok-beta"
        | LocalLlama -> "meta-llama/llama-3.1-8b-instruct:free"

    /// Send request to OpenRouter
    let complete (httpClient: HttpClient) (apiKey: string) (request: AIRequest) : Async<Result<AIResponse, string>> =
        async {
            try
                let startTime = DateTime.UtcNow

                let requestBody = {|
                    model = modelToString request.Model
                    messages = [| {| role = "user"; content = request.Prompt |} |]
                    max_tokens = request.MaxTokens
                    temperature = request.Temperature
                |}

                let json = JsonSerializer.Serialize(requestBody)
                use content = new StringContent(json, System.Text.Encoding.UTF8, "application/json")

                httpClient.DefaultRequestHeaders.Clear()
                httpClient.DefaultRequestHeaders.Add("Authorization", sprintf "Bearer %s" apiKey)
                httpClient.DefaultRequestHeaders.Add("HTTP-Referer", "https://indrajaal.io")

                let! response = httpClient.PostAsync("https://openrouter.ai/api/v1/chat/completions", content) |> Async.AwaitTask
                let! responseBody = response.Content.ReadAsStringAsync() |> Async.AwaitTask

                if response.IsSuccessStatusCode then
                    let parsed = JsonDocument.Parse(responseBody)
                    let content =
                        parsed.RootElement
                            .GetProperty("choices").[0]
                            .GetProperty("message")
                            .GetProperty("content")
                            .GetString()

                    let endTime = DateTime.UtcNow

                    return Ok {
                        Content = content
                        Model = modelToString request.Model
                        TokensUsed = request.MaxTokens  // Approximate
                        Latency = endTime - startTime
                    }
                else
                    return Error (sprintf "API error: %s" responseBody)
            with ex ->
                return Error (sprintf "Request failed: %s" ex.Message)
        }

    /// Parse natural language task
    let parseTaskFromNL (httpClient: HttpClient) (apiKey: string) (input: string) : Async<Result<string * Priority, string>> =
        async {
            let prompt = sprintf """
Parse this natural language input into a task:
Input: "%s"

Extract:
1. Task title (clear, actionable)
2. Priority (P0=Critical, P1=High, P2=Medium, P3=Low, P4=Backlog)

Respond in JSON format:
{"title": "...", "priority": "P2"}
""" input

            let! result = complete httpClient apiKey {
                Model = GeminiFlash  // Fast and cheap
                Prompt = prompt
                MaxTokens = 100
                Temperature = 0.1
            }

            match result with
            | Ok response ->
                try
                    let parsed = JsonDocument.Parse(response.Content)
                    let title = parsed.RootElement.GetProperty("title").GetString()
                    let priorityStr = parsed.RootElement.GetProperty("priority").GetString()
                    let priority =
                        match priorityStr with
                        | "P0" -> P0_Critical
                        | "P1" -> P1_High
                        | "P2" -> P2_Medium
                        | "P3" -> P3_Low
                        | _ -> P4_Backlog
                    return Ok (title, priority)
                with ex ->
                    return Error (sprintf "Failed to parse response: %s" ex.Message)
            | Error e ->
                return Error e
        }
```

```fsharp
// Integration/ElixirBridge.fs - Elixir interop via HTTP
namespace Cepaf.Planning.Integration

open System
open System.Net.Http
open System.Text.Json

/// Elixir API endpoints
module ElixirEndpoints =
    let baseUrl = "http://localhost:4000"
    let guardian = sprintf "%s/api/prajna/guardian" baseUrl
    let sentinel = sprintf "%s/api/prajna/sentinel" baseUrl
    let health = sprintf "%s/api/health" baseUrl

/// Guardian approval request
type GuardianRequest = {
    Action: string
    Resource: string
    Actor: string
    Justification: string
}

/// Guardian response
type GuardianResponse = {
    Approved: bool
    Reason: string option
    ProofToken: string option
}

/// Elixir bridge client
module ElixirBridge =

    /// Check system health
    let checkHealth (httpClient: HttpClient) : Async<Result<bool, string>> =
        async {
            try
                let! response = httpClient.GetAsync(ElixirEndpoints.health) |> Async.AwaitTask
                return Ok response.IsSuccessStatusCode
            with ex ->
                return Error ex.Message
        }

    /// Request Guardian approval
    let requestApproval (httpClient: HttpClient) (request: GuardianRequest) : Async<Result<GuardianResponse, string>> =
        async {
            try
                let json = JsonSerializer.Serialize(request)
                use content = new StringContent(json, System.Text.Encoding.UTF8, "application/json")

                let! response = httpClient.PostAsync(ElixirEndpoints.guardian + "/propose", content) |> Async.AwaitTask
                let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask

                if response.IsSuccessStatusCode then
                    let parsed = JsonSerializer.Deserialize<GuardianResponse>(body)
                    return Ok parsed
                else
                    return Error (sprintf "Guardian rejected: %s" body)
            with ex ->
                return Error ex.Message
        }
```

### 4.3 Acceptance Criteria

- [ ] Zenoh messages publish/subscribe works
- [ ] OpenRouter AI responds to queries
- [ ] Elixir health check passes
- [ ] Guardian approval flow completes

---

## Level 5: STANDARD - Interfaces [User Interaction]

**Risk if Missing:** System works but users cannot interact with it.
**Effort:** 3-4 days | **Dependencies:** Level 1, 2, 3, 4

### 5.1 Files to Create

| File | Purpose | STAMP | Lines |
|------|---------|-------|-------|
| `CLI/Program.fs` | CLI entry point | SC-PLAN-040 | ~200 |
| `CLI/Commands.fs` | CLI command parsing | SC-PLAN-041 | ~300 |
| `CLI/Display.fs` | Output formatting | SC-PLAN-042 | ~200 |
| `API/Server.fs` | HTTP API server | SC-PLAN-043 | ~300 |
| `API/Routes.fs` | API route handlers | SC-PLAN-044 | ~250 |

### 5.2 CLI Application

```fsharp
// CLI/Program.fs - CLI entry point
namespace Cepaf.Planning.CLI

open System
open Cepaf.Planning.Core
open Cepaf.Planning.Domain
open Cepaf.Planning.Application

module Program =

    [<EntryPoint>]
    let main args =
        printfn "Indrajaal Planning System v1.0.0"
        printfn "================================"

        match args |> Array.toList with
        | [] | ["help"] ->
            printfn ""
            printfn "Usage: planning <command> [options]"
            printfn ""
            printfn "Commands:"
            printfn "  add <title>          Create a new task"
            printfn "  list [filter]        List tasks"
            printfn "  done <id>            Mark task complete"
            printfn "  ooda <id>            Start OODA cycle"
            printfn "  status               Show system status"
            printfn ""
            0

        | ["add"; title] ->
            printfn "Creating task: %s" title
            match Task.create title P2_Medium with
            | Ok task ->
                printfn "Created: %s" (Ids.taskIdValue task.Id)
                0
            | Error e ->
                printfn "Error: %s" e
                1

        | ["list"] ->
            printfn "Tasks:"
            printfn "  (No tasks yet - persistence not connected)"
            0

        | ["status"] ->
            printfn "System Status:"
            printfn "  Database: SQLite (not connected)"
            printfn "  Zenoh: Not connected"
            printfn "  Cortex: Not connected"
            0

        | cmd :: _ ->
            printfn "Unknown command: %s" cmd
            printfn "Run 'planning help' for usage"
            1
```

### 5.3 Acceptance Criteria

- [ ] CLI creates tasks
- [ ] CLI lists tasks
- [ ] API responds to HTTP requests
- [ ] JSON serialization works

---

## Level 6: ENHANCED - Intelligence [AI Augmentation]

**Risk if Missing:** System works but lacks AI-powered features.
**Effort:** 3-4 days | **Dependencies:** Level 1-5

### 6.1 Files to Create

| File | Purpose | STAMP | Lines |
|------|---------|-------|-------|
| `AI/NLParser.fs` | Natural language parsing | SC-PLAN-050 | ~250 |
| `AI/Recommendations.fs` | AI recommendations | SC-PLAN-051 | ~300 |
| `AI/OODA.fs` | AI-assisted OODA | SC-PLAN-052 | ~250 |
| `AI/Tricameral.fs` | Multi-AI consensus | SC-PLAN-053 | ~300 |

### 6.2 Acceptance Criteria

- [ ] Natural language task creation works
- [ ] AI provides priority recommendations
- [ ] OODA Orient phase uses AI analysis
- [ ] Tricameral consensus reaches agreement

---

## Level 7: POLISH - Production Ready [Optimization]

**Risk if Missing:** System works but not production-grade.
**Effort:** 2-3 days | **Dependencies:** Level 1-6

### 7.1 Files to Create

| File | Purpose | STAMP | Lines |
|------|---------|-------|-------|
| `Telemetry/Metrics.fs` | Performance metrics | SC-PLAN-060 | ~200 |
| `Telemetry/Logging.fs` | Structured logging | SC-PLAN-061 | ~150 |
| `Health/Checks.fs` | Health endpoints | SC-PLAN-062 | ~150 |
| `Config/Settings.fs` | Configuration | SC-PLAN-063 | ~100 |

### 7.2 Acceptance Criteria

- [ ] Metrics exported to Prometheus
- [ ] Structured logging to Loki
- [ ] Health checks pass
- [ ] Configuration is externalized

---

## Execution Schedule

| Level | Name | Effort | Cumulative | Milestone |
|-------|------|--------|------------|-----------|
| 1 | Critical | 2-3 days | 3 days | Compiles |
| 2 | Essential | 3-4 days | 7 days | Persists |
| 3 | Important | 4-5 days | 12 days | Plans |
| 4 | Required | 4-5 days | 17 days | Integrates |
| 5 | Standard | 3-4 days | 21 days | Usable |
| 6 | Enhanced | 3-4 days | 25 days | Intelligent |
| 7 | Polish | 2-3 days | 28 days | Production |

---

## STAMP Constraints Summary

| Level | Constraints |
|-------|-------------|
| 1 | SC-PLAN-001 to SC-PLAN-009 |
| 2 | SC-PLAN-010 to SC-PLAN-019 |
| 3 | SC-PLAN-020 to SC-PLAN-029 |
| 4 | SC-PLAN-030 to SC-PLAN-039 |
| 5 | SC-PLAN-040 to SC-PLAN-049 |
| 6 | SC-PLAN-050 to SC-PLAN-059 |
| 7 | SC-PLAN-060 to SC-PLAN-069 |

---

**Document Version:** 1.0.0
**Created:** January 2026
**Methodology:** Criticality-First Development
