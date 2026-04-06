// STAMP: SC-PLAN-006, SC-FUNC-001
// AOR: AOR-PLAN-006
// Criticality: Level 2 (HIGH) - Task Management Logic
//
// This module provides business logic for managing tasks, including state
// transitions and searches. It acts as a bridge between the domain and
// the repository.

import cepaf_gleam/core/ids
import cepaf_gleam/core/types
import cepaf_gleam/db/sqlite
import cepaf_gleam/planning/domain.{
  type PlanningError, type Task, InvalidTransition, TaskNotFound,
}
import cepaf_gleam/planning/parser
import cepaf_gleam/planning/repository
import cepaf_gleam/planning/task
import gleam/bit_array
import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/set

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

/// Retrieves all tasks from the database (DuckDB).
pub fn list_tasks() -> Result(List(Task), String) {
  repository.get_all_tasks()
}

/// Retrieves all tasks from a specific SQLite database file.
pub fn list_tasks_sqlite(path: String) -> Result(List(Task), String) {
  // 1. Try NIF first
  case sqlite.open(path) {
    Ok(conn) -> {
      let res = repository.get_all_tasks_sqlite(conn)
      sqlite.close(conn)
      case res {
        Ok(tasks) -> Ok(tasks)
        Error(_) -> list_tasks_sqlite_cli(path)
      }
    }
    Error(_) -> list_tasks_sqlite_cli(path)
  }
}

@external(erlang, "cepaf_gleam_ffi", "os_cmd")
fn erl_os_cmd(cmd: String) -> Result(BitArray, String)

fn list_tasks_sqlite_cli(path: String) -> Result(List(Task), String) {
  let sql =
    "SELECT Id, Title, Status, Priority, Created, ParentId, Owner FROM Tasks"
  // Use default pipe separator, no header
  let cmd = "sqlite3 " <> path <> " \"" <> sql <> "\""
  case erl_os_cmd(cmd) {
    Ok(output_binary) -> {
      case bit_array.to_string(output_binary) {
        Ok(output_str) -> {
          let tasks = parser.parse_todolist_sqlite_output(output_str)
          Ok(tasks)
        }
        Error(_) -> Error("Failed to read sqlite3 output as UTF-8")
      }
    }
    Error(e) -> Error("os_cmd failed: " <> e)
  }
}

/// Retrieves a specific task by its strongly-typed ID.
pub fn get_task(id: ids.TaskId) -> Result(Task, String) {
  repository.get_task(id)
}

/// Deletes a task by its string ID.
pub fn delete_task(id: String) -> Result(Int, String) {
  repository.delete_task(ids.task_id_from_string(id))
}

/// Creates a new task with the given title and priority.
pub fn create_task(
  title: String,
  priority: types.Priority,
) -> Result(Task, String) {
  let input =
    domain.CreateTaskInput(
      title: title,
      description: None,
      priority: priority,
      due_date: None,
      project_id: None,
      parent_task_id: None,
      tags: set.new(),
      estimated_minutes: None,
    )
  task.create(input)
}

/// Dispatches a task for execution (placeholder).
pub fn dispatch_task(id: String) -> Result(Nil, String) {
  // Placeholder for task dispatching logic (SC-AGUI-001)
  io.println("🚀 Dispatching task: " <> id)
  Ok(Nil)
}
