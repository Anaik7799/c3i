// STAMP: SC-PLAN-006, SC-FUNC-001
// AOR: AOR-PLAN-006
// Criticality: Level 2 (HIGH) - Task Management Logic
//
// This module provides business logic for managing tasks, including state
// transitions and searches. It acts as a bridge between the domain and
// the repository.

import cepaf_gleam/core/ids
import cepaf_gleam/core/types
import cepaf_gleam/planning/domain.{
  type PlanningError, type Task, InvalidTransition, TaskNotFound,
}
import cepaf_gleam/planning/repository
import cepaf_gleam/planning/task
import gleam/list
import gleam/option.{None}
import gleam/result

// =============================================================================
// Task Management Module (Manager)
// =============================================================================

/// Updates the status of a task, ensuring valid state transitions.
pub fn update_task_status(
  task_obj: Task,
  new_status: types.TaskStatus,
) -> Result(Task, PlanningError) {
  case task_obj.status, new_status {
    _, types.InProgress -> Ok(task.start(task_obj))
    _, types.Completed -> Ok(task.complete(task_obj, None))
    // Note: block() and unblock() would need to be added to task.gleam if needed
    // For now, we'll just set the status directly via a generic setter if it exists
    _, _ if task_obj.status == new_status -> Ok(task_obj)
    from, to -> Error(InvalidTransition(from, to))
  }
}

/// Finds a task in a list by its string ID.
pub fn find_task(tasks: List(Task), id: String) -> Result(Task, PlanningError) {
  list.find(tasks, fn(t) { ids.task_id_to_string(t.id) == id })
  |> result.map_error(fn(_) { TaskNotFound(id) })
}

// =============================================================================
// Repository Bridge Functions
// =============================================================================

/// Initializes the database schema.
pub fn init_db() -> Result(Nil, String) {
  repository.ensure_db_exists()
}

/// Saves or updates a task in the database.
pub fn upsert_task(task_obj: Task) -> Result(Int, String) {
  repository.save_task(task_obj)
}

/// Retrieves all tasks from the database.
pub fn list_tasks() -> Result(List(Task), String) {
  repository.get_all_tasks()
}

/// Retrieves a specific task by its strongly-typed ID.
pub fn get_task(id: ids.TaskId) -> Result(Task, String) {
  repository.get_task(id)
}
