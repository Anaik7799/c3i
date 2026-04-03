namespace Cepaf.Planning

open System

/// Zenoh adapter for Planning system events using SC-ZTEST-008 dual-write pattern.
///
/// All Planning mutations MUST publish events through this adapter for:
/// - Real-time state sync observability (SC-SYNC-PLAN-011)
/// - Mesh-wide event propagation (SC-ZTEST-001)
/// - Log-based fallback durability (SC-ZTEST-008)
///
/// STAMP: SC-ZTEST-008, SC-ZTEST-003, SC-SYNC-PLAN-011, SC-SYNC-PLAN-020
/// AOR: AOR-ZTEST-008 (log fallback first), AOR-ZTEST-004 (async/non-blocking)
module ZenohAdapter =

    let private planningTopic = "indrajaal/planning/events"
    let private syncTopic = "indrajaal/planning/sync"

    type PlanningEvent =
        | TaskCreated of TaskItem
        | TaskUpdated of TaskItem
        | TaskCompleted of TaskId
        | SyncStarted of taskCount: int
        | SyncCompleted of synced: int * errors: int * mismatches: int
        | SyncFailed of reason: string

    /// Serialize a PlanningEvent to JSON payload
    let private toJson (event: PlanningEvent) : string =
        match event with
        | TaskCreated task ->
            sprintf """{"type":"TaskCreated","id":"%s","title":"%s","status":"%s","priority":"%s"}"""
                task.Id task.Title (task.Status.ToString()) (task.Priority.ToString())
        | TaskUpdated task ->
            sprintf """{"type":"TaskUpdated","id":"%s","status":"%s","priority":"%s"}"""
                task.Id (task.Status.ToString()) (task.Priority.ToString())
        | TaskCompleted id ->
            sprintf """{"type":"TaskCompleted","id":"%s"}""" id
        | SyncStarted count ->
            sprintf """{"type":"SyncStarted","task_count":%d}""" count
        | SyncCompleted (synced, errors, mismatches) ->
            sprintf """{"type":"SyncCompleted","synced":%d,"errors":%d,"mismatches":%d,"success":%s}"""
                synced errors mismatches (if errors = 0 && mismatches = 0 then "true" else "false")
        | SyncFailed reason ->
            sprintf """{"type":"SyncFailed","reason":"%s"}""" (reason.Replace("\"", "\\\""))

    /// Derive checkpoint ID from event type
    let private toCheckpointId (event: PlanningEvent) : string =
        match event with
        | TaskCreated _ -> "CP-PLAN-01"
        | TaskUpdated _ -> "CP-PLAN-02"
        | TaskCompleted _ -> "CP-PLAN-03"
        | SyncStarted _ -> "CP-PLAN-SYNC-01"
        | SyncCompleted _ -> "CP-PLAN-SYNC-02"
        | SyncFailed _ -> "CP-PLAN-SYNC-03"

    /// Derive topic from event type
    let private toTopic (event: PlanningEvent) : string =
        match event with
        | TaskCreated _ | TaskUpdated _ | TaskCompleted _ -> planningTopic
        | SyncStarted _ | SyncCompleted _ | SyncFailed _ -> syncTopic

    /// Derive human-readable message from event
    let private toMessage (event: PlanningEvent) : string =
        match event with
        | TaskCreated task -> sprintf "Task created: %s" task.Id
        | TaskUpdated task -> sprintf "Task updated: %s -> %s" task.Id (task.Status.ToString())
        | TaskCompleted id -> sprintf "Task completed: %s" id
        | SyncStarted count -> sprintf "Sync started: %d tasks" count
        | SyncCompleted (synced, errors, _) -> sprintf "Sync completed: %d synced, %d errors" synced errors
        | SyncFailed reason -> sprintf "Sync failed: %s" reason

    /// Publish a Planning event using SC-ZTEST-008 dual-write pattern.
    /// 1. Log fallback written FIRST (guaranteed durability)
    /// 2. Structured JSON for CEPAF bridge consumption
    /// Non-blocking per AOR-ZTEST-004.
    let publish (event: PlanningEvent) : unit =
        let checkpointId = toCheckpointId event
        let topic = toTopic event
        let message = toMessage event
        let json = toJson event
        Cepaf.Mesh.ZenohPublish.publish checkpointId topic message json

    /// Publish with Result return for callers that need error awareness.
    let tryPublish (event: PlanningEvent) : Result<unit, string> =
        let checkpointId = toCheckpointId event
        let topic = toTopic event
        let message = toMessage event
        let json = toJson event
        Cepaf.Mesh.ZenohPublish.tryPublish checkpointId topic message json

    /// Convenience: serialize event to JSON (for tests and logging)
    let serializeEvent (event: PlanningEvent) : string = toJson event

    /// Convenience: get checkpoint ID for event (for tests)
    let getCheckpointId (event: PlanningEvent) : string = toCheckpointId event

    /// Convenience: get topic for event (for tests)
    let getTopic (event: PlanningEvent) : string = toTopic event
