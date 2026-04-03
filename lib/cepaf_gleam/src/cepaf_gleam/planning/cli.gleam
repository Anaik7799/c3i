import cepaf_gleam/core/ids
import cepaf_gleam/core/types
import cepaf_gleam/planning/manager
import cepaf_gleam/planning/parser
import cepaf_gleam/substrate/file_system
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/result

// =============================================================================
// Task Management CLI Entrypoint
// =============================================================================

pub fn run(args: List(String)) -> Nil {
  case args {
    ["status"] -> show_status()
    ["start", id] -> start_task(id)
    ["complete", id] -> complete_task(id)
    ["sync"] -> sync_todolist()
    _ -> io.println("Usage: sa-plan [status|start|complete|sync]")
  }
}

fn show_status() {
  let _ = manager.init_db()
  case manager.list_tasks() {
    Ok(tasks) -> {
      io.println("📋 TASK STATUS:")
      list.each(tasks, fn(t) {
        let status = types.task_status_to_string(t.status)
        let id = ids.task_id_to_string(t.id)
        let title = types.non_empty_string_value(t.title)
        io.println("  - [" <> status <> "] " <> id <> ": " <> title)
      })
    }
    Error(e) -> io.println("Error listing tasks: " <> e)
  }
}

fn start_task(id: String) {
  let _ = manager.init_db()
  case manager.list_tasks() {
    Ok(tasks) -> {
      case manager.find_task(tasks, id) {
        Ok(task) -> {
          case manager.update_task_status(task, types.InProgress) {
            Ok(updated) -> {
              let _ = manager.upsert_task(updated)
              io.println("✅ Task started: " <> id)
            }
            Error(_) -> io.println("❌ Invalid transition for task: " <> id)
          }
        }
        Error(_) -> io.println("❌ Task not found: " <> id)
      }
    }
    Error(e) -> io.println("Error reading tasks: " <> e)
  }
}

fn complete_task(id: String) {
  let _ = manager.init_db()
  case manager.list_tasks() {
    Ok(tasks) -> {
      case manager.find_task(tasks, id) {
        Ok(task) -> {
          case manager.update_task_status(task, types.Completed) {
            Ok(updated) -> {
              let _ = manager.upsert_task(updated)
              io.println("✅ Task completed: " <> id)
            }
            Error(_) -> io.println("❌ Invalid transition for task: " <> id)
          }
        }
        Error(_) -> io.println("❌ Task not found: " <> id)
      }
    }
    Error(e) -> io.println("Error reading tasks: " <> e)
  }
}

fn sync_todolist() {
  io.println("Syncing with PROJECT_TODOLIST.md...")
  let _ = manager.init_db()
  case file_system.read_file("PROJECT_TODOLIST.md") {
    Ok(content) -> {
      let tasks = parser.parse_todolist(content)
      list.each(tasks, fn(t) {
        let _ = manager.upsert_task(t)
      })
      io.println(
        "✅ Sync complete. "
        <> int.to_string(list.length(tasks))
        <> " tasks processed.",
      )
    }
    Error(e) -> io.println("Error reading todolist: " <> e)
  }
}
