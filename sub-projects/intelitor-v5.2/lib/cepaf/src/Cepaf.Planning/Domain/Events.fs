// =============================================================================
// Events.fs - Domain Events for Event Sourcing
// =============================================================================
// STAMP: SC-PLAN-008, SC-REG-001
// AOR: AOR-PLAN-008, AOR-REG-001
// Criticality: Level 1 (CRITICAL) - Foundation
// =============================================================================

namespace Cepaf.Planning.Domain

open System
open Cepaf.Planning.Core
open Cepaf.Planning.Core.Ids

/// Task priority levels (military-style)
type Priority =
    | P0_Critical   // Immediate action required (FLASH)
    | P1_High       // Same day (IMMEDIATE)
    | P2_Medium     // This week (PRIORITY)
    | P3_Low        // This month (ROUTINE)
    | P4_Backlog    // When possible (DEFERRED)

module Priority =
    let toString = function
        | P0_Critical -> "P0"
        | P1_High -> "P1"
        | P2_Medium -> "P2"
        | P3_Low -> "P3"
        | P4_Backlog -> "P4"

    let parse = function
        | "P0" | "p0" -> Ok P0_Critical
        | "P1" | "p1" -> Ok P1_High
        | "P2" | "p2" -> Ok P2_Medium
        | "P3" | "p3" -> Ok P3_Low
        | "P4" | "p4" -> Ok P4_Backlog
        | s -> Error (sprintf "Invalid priority: %s" s)

    let toInt = function
        | P0_Critical -> 0
        | P1_High -> 1
        | P2_Medium -> 2
        | P3_Low -> 3
        | P4_Backlog -> 4

    let compare p1 p2 = compare (toInt p1) (toInt p2)

/// Task status
type TaskStatus =
    | Todo
    | InProgress
    | Done
    | Blocked of reason: string
    | Cancelled of reason: string

module TaskStatus =
    let toString = function
        | Todo -> "todo"
        | InProgress -> "in_progress"
        | Done -> "done"
        | Blocked r -> sprintf "blocked:%s" r
        | Cancelled r -> sprintf "cancelled:%s" r

    let parse (s: string) =
        match s.ToLowerInvariant() with
        | "todo" -> Ok Todo
        | "in_progress" | "inprogress" -> Ok InProgress
        | "done" | "completed" -> Ok Done
        | s when s.StartsWith("blocked:") -> Ok (Blocked (s.Substring(8)))
        | s when s.StartsWith("cancelled:") -> Ok (Cancelled (s.Substring(10)))
        | "blocked" -> Ok (Blocked "")
        | "cancelled" -> Ok (Cancelled "")
        | _ -> Error (sprintf "Invalid status: %s" s)

    let isComplete = function
        | Done | Cancelled _ -> true
        | _ -> false

    let isBlocked = function
        | Blocked _ -> true
        | _ -> false

/// OODA phase
type OODAPhase =
    | Observe
    | Orient
    | Decide
    | Act
    | Complete

module OODAPhase =
    let toString = function
        | Observe -> "OBSERVE"
        | Orient -> "ORIENT"
        | Decide -> "DECIDE"
        | Act -> "ACT"
        | Complete -> "COMPLETE"

    let next = function
        | Observe -> Orient
        | Orient -> Decide
        | Decide -> Act
        | Act -> Complete
        | Complete -> Complete

/// Event metadata
type EventMetadata = {
    EventId: EventId
    AggregateId: string
    AggregateType: string
    Version: int64
    Timestamp: Timestamp
    CorrelationId: CorrelationId option
    CausationId: EventId option
    Actor: UserId option
}

module EventMetadata =
    let create aggregateId aggregateType version =
        {
            EventId = newEventId ()
            AggregateId = aggregateId
            AggregateType = aggregateType
            Version = version
            Timestamp = DateTimeOffset.UtcNow
            CorrelationId = None
            CausationId = None
            Actor = None
        }

    let withCorrelation correlationId metadata =
        { metadata with CorrelationId = Some correlationId }

    let withCausation eventId metadata =
        { metadata with CausationId = Some eventId }

    let withActor userId metadata =
        { metadata with Actor = Some userId }

/// Domain events for Task aggregate
type TaskEvent =
    | TaskCreated of {|
        TaskId: TaskId
        Title: string
        Description: string option
        Priority: Priority
        ProjectId: ProjectId option
        ParentTaskId: TaskId option
        DueDate: Timestamp option
        EstimatedMinutes: int option
        Tags: Set<string>
      |}

    | TaskTitleChanged of {|
        TaskId: TaskId
        OldTitle: string
        NewTitle: string
      |}

    | TaskDescriptionChanged of {|
        TaskId: TaskId
        OldDescription: string option
        NewDescription: string option
      |}

    | TaskStatusChanged of {|
        TaskId: TaskId
        OldStatus: TaskStatus
        NewStatus: TaskStatus
      |}

    | TaskPriorityChanged of {|
        TaskId: TaskId
        OldPriority: Priority
        NewPriority: Priority
      |}

    | TaskAssigned of {|
        TaskId: TaskId
        OldAssignee: UserId option
        NewAssignee: UserId option
      |}

    | TaskDueDateChanged of {|
        TaskId: TaskId
        OldDueDate: Timestamp option
        NewDueDate: Timestamp option
      |}

    | TaskTagAdded of {|
        TaskId: TaskId
        Tag: string
      |}

    | TaskTagRemoved of {|
        TaskId: TaskId
        Tag: string
      |}

    | TaskDependencyAdded of {|
        TaskId: TaskId
        DependsOn: TaskId
      |}

    | TaskDependencyRemoved of {|
        TaskId: TaskId
        DependsOn: TaskId
      |}

    | TaskCompleted of {|
        TaskId: TaskId
        ActualMinutes: int option
        CompletedAt: Timestamp
      |}

    | TaskDeleted of {|
        TaskId: TaskId
        Reason: string option
        DeletedAt: Timestamp
      |}

/// Domain events for OODA Cycle aggregate
type OODAEvent =
    | OODACycleStarted of {|
        CycleId: OODACycleId
        ContextType: string  // "task", "project", "sprint"
        ContextId: string
        StartedAt: Timestamp
      |}

    | ObservationAdded of {|
        CycleId: OODACycleId
        ObservationId: Guid
        Source: string
        Content: string
        Confidence: float
        Tags: Set<string>
      |}

    | OrientationCompleted of {|
        CycleId: OODACycleId
        Analysis: string
        Patterns: string list
        Threats: string list
        Opportunities: string list
        Constraints: string list
      |}

    | COAProposed of {|
        CycleId: OODACycleId
        COAId: Guid
        Name: string
        Description: string
        Pros: string list
        Cons: string list
        Risk: float
        Effort: float
        Impact: float
      |}

    | COASelected of {|
        CycleId: OODACycleId
        SelectedCOAId: Guid
        Rationale: string option
      |}

    | ActionExecuted of {|
        CycleId: OODACycleId
        ActionId: Guid
        Description: string
        TaskIds: TaskId list
        StartedAt: Timestamp
      |}

    | ActionCompleted of {|
        CycleId: OODACycleId
        ActionId: Guid
        Result: string
        Success: bool
        CompletedAt: Timestamp
      |}

    | OODACycleCompleted of {|
        CycleId: OODACycleId
        CycleTimeMs: int64
        CompletedAt: Timestamp
      |}

/// Domain events for Project aggregate
type ProjectEvent =
    | ProjectCreated of {|
        ProjectId: ProjectId
        Name: string
        Description: string option
        OwnerId: UserId option
        StartDate: Timestamp option
        TargetDate: Timestamp option
      |}

    | ProjectRenamed of {|
        ProjectId: ProjectId
        OldName: string
        NewName: string
      |}

    | ProjectArchived of {|
        ProjectId: ProjectId
        ArchivedAt: Timestamp
      |}

    | TaskAddedToProject of {|
        ProjectId: ProjectId
        TaskId: TaskId
      |}

    | TaskRemovedFromProject of {|
        ProjectId: ProjectId
        TaskId: TaskId
      |}

/// Domain events for Sprint aggregate
type SprintEvent =
    | SprintCreated of {|
        SprintId: SprintId
        ProjectId: ProjectId option
        Name: string
        StartDate: Timestamp
        EndDate: Timestamp
        Goal: string option
      |}

    | SprintStarted of {|
        SprintId: SprintId
        StartedAt: Timestamp
      |}

    | SprintCompleted of {|
        SprintId: SprintId
        CompletedAt: Timestamp
        Velocity: int
      |}

    | TaskAddedToSprint of {|
        SprintId: SprintId
        TaskId: TaskId
        StoryPoints: int option
      |}

    | TaskRemovedFromSprint of {|
        SprintId: SprintId
        TaskId: TaskId
      |}

/// Event envelope with metadata
type EventEnvelope<'TEvent> = {
    Metadata: EventMetadata
    Event: 'TEvent
}

module EventEnvelope =
    let create metadata event = { Metadata = metadata; Event = event }

    let map f envelope = { Metadata = envelope.Metadata; Event = f envelope.Event }

    let getEventId envelope = envelope.Metadata.EventId
    let getTimestamp envelope = envelope.Metadata.Timestamp
    let getVersion envelope = envelope.Metadata.Version

/// All domain events (discriminated union for serialization)
type DomainEvent =
    | TaskEvt of TaskEvent
    | OODAEvt of OODAEvent
    | ProjectEvt of ProjectEvent
    | SprintEvt of SprintEvent

module DomainEvent =
    let getAggregateType = function
        | TaskEvt _ -> "Task"
        | OODAEvt _ -> "OODACycle"
        | ProjectEvt _ -> "Project"
        | SprintEvt _ -> "Sprint"
