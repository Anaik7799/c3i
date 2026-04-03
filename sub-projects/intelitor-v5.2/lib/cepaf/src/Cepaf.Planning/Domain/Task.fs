// =============================================================================
// Task.fs - Task Entity for Planning System
// =============================================================================
// STAMP: SC-PLAN-005, SC-FUNC-001
// AOR: AOR-PLAN-005
// Criticality: Level 1 (CRITICAL) - Foundation
// =============================================================================

namespace Cepaf.Planning.Domain

open System
open Cepaf.Planning.Core
open Cepaf.Planning.Core.Ids

/// Task entity - the core work unit
type Task = {
    Id: TaskId
    Title: NonEmptyString
    Description: string option
    Status: TaskStatus
    Priority: Priority
    CreatedAt: Timestamp
    UpdatedAt: Timestamp
    DueDate: Timestamp option
    CompletedAt: Timestamp option
    AssigneeId: UserId option
    ProjectId: ProjectId option
    SprintId: SprintId option
    ParentTaskId: TaskId option
    Tags: Set<string>
    Dependencies: Set<TaskId>      // Tasks this task depends on
    EstimatedMinutes: int option
    ActualMinutes: int option
    Version: int64
}

/// Task creation input
type CreateTaskInput = {
    Title: string
    Description: string option
    Priority: Priority
    DueDate: Timestamp option
    ProjectId: ProjectId option
    ParentTaskId: TaskId option
    Tags: Set<string>
    EstimatedMinutes: int option
}

/// Task operations
module Task =

    /// Create a new task from input
    let create (input: CreateTaskInput) : Result<Task, string> =
        result {
            let! validTitle = NonEmptyString.create input.Title
            let now = DateTimeOffset.UtcNow
            return {
                Id = newTaskId ()
                Title = validTitle
                Description = input.Description
                Status = Todo
                Priority = input.Priority
                CreatedAt = now
                UpdatedAt = now
                DueDate = input.DueDate
                CompletedAt = None
                AssigneeId = None
                ProjectId = input.ProjectId
                SprintId = None
                ParentTaskId = input.ParentTaskId
                Tags = input.Tags
                Dependencies = Set.empty
                EstimatedMinutes = input.EstimatedMinutes
                ActualMinutes = None
                Version = 0L
            }
        }

    /// Create a simple task with just title and priority
    let createSimple (title: string) (priority: Priority) : Result<Task, string> =
        create {
            Title = title
            Description = None
            Priority = priority
            DueDate = None
            ProjectId = None
            ParentTaskId = None
            Tags = Set.empty
            EstimatedMinutes = None
        }

    /// Update task, incrementing version
    let private update (f: Task -> Task) (task: Task) : Task =
        let updated = f task
        { updated with
            UpdatedAt = DateTimeOffset.UtcNow
            Version = task.Version + 1L }

    /// Change task title
    let setTitle (title: NonEmptyString) (task: Task) : Task =
        update (fun t -> { t with Title = title }) task

    /// Change task description
    let setDescription (description: string option) (task: Task) : Task =
        update (fun t -> { t with Description = description }) task

    /// Change task status
    let setStatus (status: TaskStatus) (task: Task) : Task =
        let task' = update (fun t -> { t with Status = status }) task
        match status with
        | Done ->
            { task' with CompletedAt = Some DateTimeOffset.UtcNow }
        | _ -> task'

    /// Change task priority
    let setPriority (priority: Priority) (task: Task) : Task =
        update (fun t -> { t with Priority = priority }) task

    /// Set due date
    let setDueDate (dueDate: Timestamp option) (task: Task) : Task =
        update (fun t -> { t with DueDate = dueDate }) task

    /// Assign task to user
    let assign (userId: UserId option) (task: Task) : Task =
        update (fun t -> { t with AssigneeId = userId }) task

    /// Add to project
    let setProject (projectId: ProjectId option) (task: Task) : Task =
        update (fun t -> { t with ProjectId = projectId }) task

    /// Add to sprint
    let setSprint (sprintId: SprintId option) (task: Task) : Task =
        update (fun t -> { t with SprintId = sprintId }) task

    /// Add a tag
    let addTag (tag: string) (task: Task) : Task =
        update (fun t -> { t with Tags = t.Tags |> Set.add tag }) task

    /// Remove a tag
    let removeTag (tag: string) (task: Task) : Task =
        update (fun t -> { t with Tags = t.Tags |> Set.remove tag }) task

    /// Add a dependency
    let addDependency (dependsOn: TaskId) (task: Task) : Task =
        update (fun t -> { t with Dependencies = t.Dependencies |> Set.add dependsOn }) task

    /// Remove a dependency
    let removeDependency (dependsOn: TaskId) (task: Task) : Task =
        update (fun t -> { t with Dependencies = t.Dependencies |> Set.remove dependsOn }) task

    /// Set estimated minutes
    let setEstimate (minutes: int option) (task: Task) : Task =
        update (fun t -> { t with EstimatedMinutes = minutes }) task

    /// Set actual minutes (typically on completion)
    let setActual (minutes: int option) (task: Task) : Task =
        update (fun t -> { t with ActualMinutes = minutes }) task

    /// Start working on task
    let start (task: Task) : Task =
        setStatus InProgress task

    /// Block task with reason
    let block (reason: string) (task: Task) : Task =
        setStatus (Blocked reason) task

    /// Unblock task (return to In Progress)
    let unblock (task: Task) : Task =
        setStatus InProgress task

    /// Complete task
    let complete (actualMinutes: int option) (task: Task) : Task =
        task
        |> setStatus Done
        |> setActual actualMinutes

    /// Cancel task
    let cancel (reason: string) (task: Task) : Task =
        setStatus (Cancelled reason) task

    // === Query helpers ===

    /// Check if task is complete
    let isComplete (task: Task) : bool =
        TaskStatus.isComplete task.Status

    /// Check if task is blocked
    let isBlocked (task: Task) : bool =
        TaskStatus.isBlocked task.Status

    /// Check if task is overdue
    let isOverdue (task: Task) : bool =
        match task.DueDate with
        | None -> false
        | Some due -> due < DateTimeOffset.UtcNow && not (isComplete task)

    /// Check if task has dependencies
    let hasDependencies (task: Task) : bool =
        not task.Dependencies.IsEmpty

    /// Check if task has a specific tag
    let hasTag (tag: string) (task: Task) : bool =
        task.Tags |> Set.contains tag

    /// Get title as string
    let getTitle (task: Task) : string =
        NonEmptyString.value task.Title

    /// Get time since creation
    let getAge (task: Task) : TimeSpan =
        DateTimeOffset.UtcNow - task.CreatedAt

    /// Get time remaining until due (negative if overdue)
    let getTimeRemaining (task: Task) : TimeSpan option =
        task.DueDate |> Option.map (fun due -> due - DateTimeOffset.UtcNow)

    /// Calculate completion percentage based on subtasks (placeholder)
    let getCompletionPercent (_task: Task) : float =
        // This would need subtask information
        0.0

/// Task list operations
module TaskList =

    /// Filter by status
    let filterByStatus (status: TaskStatus) (tasks: Task list) : Task list =
        tasks |> List.filter (fun t -> t.Status = status)

    /// Filter by priority
    let filterByPriority (priority: Priority) (tasks: Task list) : Task list =
        tasks |> List.filter (fun t -> t.Priority = priority)

    /// Filter by assignee
    let filterByAssignee (userId: UserId option) (tasks: Task list) : Task list =
        tasks |> List.filter (fun t -> t.AssigneeId = userId)

    /// Filter by project
    let filterByProject (projectId: ProjectId option) (tasks: Task list) : Task list =
        tasks |> List.filter (fun t -> t.ProjectId = projectId)

    /// Filter by tag
    let filterByTag (tag: string) (tasks: Task list) : Task list =
        tasks |> List.filter (Task.hasTag tag)

    /// Filter overdue tasks
    let filterOverdue (tasks: Task list) : Task list =
        tasks |> List.filter Task.isOverdue

    /// Filter blocked tasks
    let filterBlocked (tasks: Task list) : Task list =
        tasks |> List.filter Task.isBlocked

    /// Sort by priority (highest first)
    let sortByPriority (tasks: Task list) : Task list =
        tasks |> List.sortBy (fun t -> Priority.toInt t.Priority)

    /// Sort by due date (earliest first)
    let sortByDueDate (tasks: Task list) : Task list =
        tasks |> List.sortBy (fun t -> t.DueDate |> Option.defaultValue DateTimeOffset.MaxValue)

    /// Sort by creation date (newest first)
    let sortByCreated (tasks: Task list) : Task list =
        tasks |> List.sortByDescending (fun t -> t.CreatedAt)

    /// Sort by update date (most recent first)
    let sortByUpdated (tasks: Task list) : Task list =
        tasks |> List.sortByDescending (fun t -> t.UpdatedAt)

    /// Get incomplete tasks
    let getIncomplete (tasks: Task list) : Task list =
        tasks |> List.filter (Task.isComplete >> not)

    /// Get task count by status
    let countByStatus (tasks: Task list) : Map<string, int> =
        tasks
        |> List.groupBy (fun t -> TaskStatus.toString t.Status)
        |> List.map (fun (status, ts) -> status, ts.Length)
        |> Map.ofList

    /// Get task count by priority
    let countByPriority (tasks: Task list) : Map<Priority, int> =
        tasks
        |> List.groupBy (fun t -> t.Priority)
        |> List.map (fun (priority, ts) -> priority, ts.Length)
        |> Map.ofList
