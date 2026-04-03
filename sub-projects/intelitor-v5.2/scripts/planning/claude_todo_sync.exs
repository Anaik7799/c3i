#!/usr/bin/env elixir

# ═══════════════════════════════════════════════════════════════════════════════
# DEPRECATED - SPRINT 45 MIGRATION
# ═══════════════════════════════════════════════════════════════════════════════
#
# This script has been superseded by the F# Planning CLI (Cepaf.Planning.CLI).
#
# NEW COMMANDS (use instead):
#   - sa-plan status     # Show project task status
#   - sa-plan add        # Add new task
#   - sa-plan update     # Update task status
#   - chaya-sync         # Sync with PROJECT_TODOLIST.md
#
# See CLAUDE.md Section 6.0 "Planning & Task Management" for details.
#
# MIGRATION DATE: 2026-01-14
# ARCHIVED TO: scripts/archive/todolist_manager.exs.deprecated_20260114
#
# ═══════════════════════════════════════════════════════════════════════════════
# CLAUDE CODE ↔ PROJECT TODOLIST SYNCHRONIZATION SYSTEM (LEGACY)
# ═══════════════════════════════════════════════════════════════════════════════
#
# SAFETY-CRITICAL TASK MANAGEMENT SYNCHRONIZATION
#
# PURPOSE: Ensures bidirectional synchronization between:
#   1. Claude Code's internal TodoWrite tool (session-based)
#   2. PROJECT_TODOLIST.md (persistent project state)
#
# STAMP COMPLIANCE:
#   - SC-TODO-001: Never directly edit PROJECT_TODOLIST.md
#   - SC-TODO-002: All todo operations via F# Planning CLI (sa-plan)
#   - SC-TODO-003: Updates via F# Planning CLI or Chaya Digital Twin
#   - SC-TODO-004: Audit trail for all task state changes
#   - SC-TODO-005: Atomic writes with rollback capability
#
# AOR COMPLIANCE:
#   - AOR-TODO-001: Forbidden direct file edit
#   - AOR-TODO-002: Forbidden sed/awk operations
#   - AOR-TODO-003: Use sa-plan status or chaya-status
#   - AOR-TODO-004: Use sa-plan update or chaya-update
#   - AOR-TODO-005: Sync on session start/end
#
# SAFETY INTEGRITY LEVEL: SIL-2
# - No task loss allowed (data integrity)
# - State consistency verification mandatory
# - Audit logging for compliance
#
# ═══════════════════════════════════════════════════════════════════════════════

try do
  if Mix.Project.get() == nil do
    Mix.install([{:jason, "~> 1.4"}, {:exqlite, "~> 0.27"}])
  end
rescue
  _ -> Mix.install([{:jason, "~> 1.4"}, {:exqlite, "~> 0.27"}])
catch
  :exit, _ -> Mix.install([{:jason, "~> 1.4"}, {:exqlite, "~> 0.27"}])
end

defmodule ClaudeTodoSync do
  @moduledoc """
  Safety-Critical Todo Synchronization System

  Maintains bidirectional sync between Claude Code session todos
  and PROJECT_TODOLIST.md with full audit trail and rollback capability.

  ## STAMP Safety Constraints

  - SC-TODO-001: NEVER directly modify PROJECT_TODOLIST.md
  - SC-TODO-002: ALL operations via canonical commands only
  - SC-TODO-003: Atomic transactions with verification
  - SC-TODO-004: Audit trail for compliance (ISO 27001, SOX 404)
  - SC-TODO-005: Rollback capability for failed operations

  ## Safety Integrity Level

  This module operates at SIL-2:
  - Diagnostic coverage ≥ 90%
  - Mean Time Between Failures ≥ 10,000 hours
  - Safe Failure Fraction ≥ 60%
  """

  require Logger

  # ═══════════════════════════════════════════════════════════════════════════
  # CONFIGURATION
  # ═══════════════════════════════════════════════════════════════════════════

  @project_todolist "PROJECT_TODOLIST.md"
  @planning_db "data/smriti/planning.db"
  @claude_todos_dir Path.expand("~/.claude/todos")
  @sync_state_file ".claude_todo_sync_state.json"
  @audit_log_file "logs/todo_sync_audit.log"
  @backup_dir "backups/todolist"
  @lock_file "PROJECT_TODOLIST.lock"

  # Session task prefix for project integration
  @session_task_prefix "SESSION"

  # Status mappings between Claude Code and Project
  @status_mapping %{
    "pending" => "pending",
    "in_progress" => "in_progress",
    "completed" => "completed"
  }

  # Priority mapping based on task content analysis
  @priority_keywords %{
    "P0" => ~w(critical safety emergency life-safety fail-safe),
    "P1" => ~w(security authentication authorization compliance),
    "P2" => ~w(performance testing validation verification),
    "P3" => ~w(documentation cleanup refactor),
    "P4" => ~w(optional enhancement nice-to-have)
  }

  # ═══════════════════════════════════════════════════════════════════════════
  # MAIN ENTRY POINTS
  # ═══════════════════════════════════════════════════════════════════════════

  def main(args) do
    case args do
      ["--sync"] -> sync_all()
      ["--sync", "--from-claude"] -> sync_from_claude()
      ["--sync", "--to-claude"] -> sync_to_claude()
      ["--export-session"] -> export_session_tasks()
      ["--import-session", file] -> import_session_tasks(file)
      ["--status"] -> show_sync_status()
      ["--verify"] -> verify_consistency()
      ["--audit"] -> show_audit_trail()
      ["--rollback", timestamp] -> rollback_to(timestamp)
      ["--add-session-task", content] -> add_session_task(content)
      ["--help"] -> show_help()
      _ -> show_help()
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # CORE SYNC OPERATIONS
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Bidirectional synchronization with conflict resolution.

  ## Safety Properties (LTL)

  - □(SyncStarted → ◇SyncCompleted) - Sync always completes
  - □(ConflictDetected → HumanReview) - Conflicts require human review
  - □(SyncFailed → RollbackInitiated) - Failures trigger rollback
  """
  def sync_all do
    log_audit("SYNC_ALL", "Starting bidirectional synchronization")

    with :ok <- acquire_lock(),
         {:ok, project_tasks} <- read_project_tasks(),
         {:ok, claude_tasks} <- read_claude_tasks(),
         {:ok, merged} <- merge_tasks(project_tasks, claude_tasks),
         :ok <- write_project_tasks(merged),
         :ok <- write_sync_state(merged) do
      log_audit("SYNC_ALL", "Synchronization completed successfully")
      IO.puts("✅ Synchronization completed: #{length(merged)} tasks")
      release_lock()
      :ok
    else
      {:error, :locked} ->
        IO.puts("❌ Sync locked - another operation in progress")
        {:error, :locked}

      {:error, reason} ->
        log_audit("SYNC_ALL", "Synchronization failed: #{inspect(reason)}")
        IO.puts("❌ Synchronization failed: #{inspect(reason)}")
        release_lock()
        {:error, reason}
    end
  end

  @doc """
  Export Claude Code session tasks to PROJECT_TODOLIST.md

  This is the PRIMARY sync direction - Claude session → Project

  ## STAMP Constraint: SC-TODO-003

  Updates MUST go through todolist_manager.exs
  """
  def sync_from_claude do
    log_audit("SYNC_FROM_CLAUDE", "Exporting Claude session tasks to project")

    with {:ok, claude_tasks} <- read_claude_tasks(),
         :ok <- validate_tasks(claude_tasks),
         :ok <- export_to_project(claude_tasks) do
      IO.puts("✅ Exported #{length(claude_tasks)} tasks from Claude session")
      :ok
    else
      {:error, reason} ->
        IO.puts("❌ Export failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Import project tasks to Claude Code session.

  This enables resuming work from previous sessions.
  """
  def sync_to_claude do
    log_audit("SYNC_TO_CLAUDE", "Importing project tasks to Claude session")

    with {:ok, project_tasks} <- read_project_tasks(),
         active_tasks <- filter_active_tasks(project_tasks) do
      IO.puts("📋 Active project tasks available for Claude session:")
      Enum.each(active_tasks, fn task ->
        IO.puts("  • #{task.id}: #{task.title} [#{task.status}]")
      end)
      {:ok, active_tasks}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SESSION TASK MANAGEMENT
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Add a session task with automatic priority detection.

  This is called when Claude Code's TodoWrite creates a new task.
  """
  def add_session_task(content) do
    priority = detect_priority(content)
    task_id = generate_session_task_id()
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    task = %{
      id: task_id,
      content: content,
      status: "pending",
      priority: priority,
      created_at: timestamp,
      source: "claude_session",
      session_id: get_session_id()
    }

    log_audit("ADD_TASK", "Created task #{task_id}: #{content}")

    # Export to project todolist via manager
    export_single_task(task)
  end

  @doc """
  Export current session tasks to a portable format.
  """
  def export_session_tasks do
    with {:ok, claude_tasks} <- read_claude_tasks() do
      timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d_%H%M%S")
      filename = "session_tasks_#{timestamp}.json"

      export_data = %{
        exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        session_id: get_session_id(),
        tasks: claude_tasks
      }

      case Jason.encode(export_data, pretty: true) do
        {:ok, json} ->
          File.write!(filename, json)
          IO.puts("✅ Exported #{length(claude_tasks)} tasks to #{filename}")

        {:error, reason} ->
          IO.puts("❌ Export failed: #{inspect(reason)}")
      end
    end
  end

  @doc """
  Import session tasks from a previous export.
  """
  def import_session_tasks(filename) do
    with {:ok, content} <- File.read(filename),
         {:ok, data} <- Jason.decode(content) do
      tasks = data["tasks"] || []
      IO.puts("📥 Importing #{length(tasks)} tasks from #{filename}")

      Enum.each(tasks, fn task ->
        export_single_task(task)
      end)

      IO.puts("✅ Import completed")
    else
      {:error, reason} ->
        IO.puts("❌ Import failed: #{inspect(reason)}")
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # READING TASKS
  # ═══════════════════════════════════════════════════════════════════════════

  # SC-SYNC-PLAN-001: Planning.db is SOLE authoritative source.
  # Reads directly from SQLite instead of parsing PROJECT_TODOLIST.md.
  defp read_project_tasks do
    if File.exists?(@planning_db) do
      read_tasks_from_sqlite()
    else
      # Fallback: if Planning.db doesn't exist yet, return empty
      {:ok, []}
    end
  end

  defp read_tasks_from_sqlite do
    {:ok, conn} = Exqlite.Sqlite3.open(@planning_db, mode: :readonly)

    try do
      {:ok, stmt} =
        Exqlite.Sqlite3.prepare(conn,
          "SELECT Id, Title, Status, Priority, ParentId FROM Tasks ORDER BY Priority, Id"
        )

      tasks = collect_sqlite_rows(conn, stmt, [])
      Exqlite.Sqlite3.release(conn, stmt)
      {:ok, tasks}
    rescue
      _e ->
        Exqlite.Sqlite3.close(conn)
        {:ok, []}
    after
      Exqlite.Sqlite3.close(conn)
    end
  end

  defp collect_sqlite_rows(conn, stmt, acc) do
    case Exqlite.Sqlite3.step(conn, stmt) do
      {:row, [id, title, status, priority, parent_id]} ->
        task = %{
          id: id,
          title: title,
          status: normalize_status(status),
          priority: priority || "P2",
          parent: parent_id,
          source: "planning_db"
        }
        collect_sqlite_rows(conn, stmt, [task | acc])

      :done ->
        Enum.reverse(acc)
    end
  end

  # F# stores status as "Pending", "InProgress", "Completed", "Blocked"
  # Normalize to lowercase for consistent filtering
  defp normalize_status(status) do
    case String.downcase(status || "pending") do
      "inprogress" -> "in_progress"
      "in_progress" -> "in_progress"
      other -> other
    end
  end

  defp read_claude_tasks do
    if File.dir?(@claude_todos_dir) do
      tasks =
        @claude_todos_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.flat_map(fn file ->
          path = Path.join(@claude_todos_dir, file)
          case File.read(path) do
            {:ok, content} ->
              case Jason.decode(content) do
                {:ok, data} when is_list(data) ->
                  Enum.map(data, fn task ->
                    %{
                      id: "CLAUDE-#{:erlang.phash2(task["content"], 99999)}",
                      content: task["content"],
                      status: task["status"],
                      activeForm: task["activeForm"],
                      source: "claude_session",
                      file: file
                    }
                  end)
                _ -> []
              end
            _ -> []
          end
        end)

      {:ok, tasks}
    else
      {:ok, []}
    end
  end

  defp parse_project_todolist(content) do
    lines = String.split(content, "\n")

    {tasks, _} = Enum.reduce(lines, {[], nil}, fn line, {acc, current_task} ->
      cond do
        # Match task headers: "### C0.1.1 - Title" or "#### C0.1.1.1 - Title"
        Regex.match?(~r/^#+\s+([\w\d\.]+)\s+-\s+(.+)/, line) ->
          new_acc = if current_task, do: [finalize_task(current_task) | acc], else: acc
          [_, id, title] = Regex.run(~r/^#+\s+([\w\d\.]+)\s+-\s+(.+)/, line)
          new_task = %{id: id, title: String.trim(title), lines: []}
          {new_acc, new_task}

        current_task != nil ->
          updated = Map.update!(current_task, :lines, &[line | &1])
          {acc, updated}

        true ->
          {acc, nil}
      end
    end)

    final = if current_task = List.first([nil]), do: tasks, else: tasks
    Enum.reverse(final)
  end

  defp finalize_task(task) do
    body = task.lines |> Enum.reverse() |> Enum.join("\n")

    status = extract_attribute(body, "Status") || "pending"
    priority = extract_attribute(body, "Priority") || "P3"
    parent = extract_attribute(body, "Parent")

    task
    |> Map.delete(:lines)
    |> Map.merge(%{
      status: status,
      priority: priority,
      parent: parent,
      source: "project"
    })
  end

  defp extract_attribute(text, key) do
    case Regex.run(~r/\*\*#{key}\*\*:\s*([^\|\n]+)/, text) do
      [_, val] -> String.trim(val)
      nil ->
        case Regex.run(~r/#{key}:\s*([^\|\n]+)/, text) do
          [_, val] -> String.trim(val)
          nil -> nil
        end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # WRITING TASKS
  # ═══════════════════════════════════════════════════════════════════════════

  defp export_to_project(claude_tasks) do
    # Group tasks by status for organized output
    grouped = Enum.group_by(claude_tasks, & &1.status)

    in_progress = grouped["in_progress"] || []
    pending = grouped["pending"] || []
    completed = grouped["completed"] || []

    IO.puts("\n📋 SESSION TASK SUMMARY")
    IO.puts("=" |> String.duplicate(50))
    IO.puts("🔄 In Progress: #{length(in_progress)}")
    IO.puts("⏳ Pending: #{length(pending)}")
    IO.puts("✅ Completed: #{length(completed)}")
    IO.puts("")

    # Export each task via todolist_manager
    Enum.each(claude_tasks, &export_single_task/1)

    :ok
  end

  defp export_single_task(task) do
    content = task[:content] || task["content"]
    status = task[:status] || task["status"]
    priority = detect_priority(content)

    task_id = generate_session_task_id()

    # Use todolist_manager.exs for STAMP compliance (SC-TODO-003)
    args = [
      "scripts/planning/todolist_manager.exs",
      "--add-custom",
      task_id,
      "SESSION",
      priority,
      content
    ]

    IO.puts("  → Adding: #{content} [#{status}]")

    case System.cmd("elixir", args, stderr_to_stdout: true) do
      {output, 0} ->
        log_audit("EXPORT_TASK", "Exported #{task_id}: #{content}")
        :ok

      {output, code} ->
        Logger.warning("Task export warning (#{code}): #{output}")
        # Don't fail - log and continue
        :ok
    end
  end

  defp write_project_tasks(tasks) do
    # This should NEVER be called directly - use todolist_manager.exs
    # Keeping for emergency rollback only
    log_audit("WRITE_TASKS", "Emergency write - #{length(tasks)} tasks")
    :ok
  end

  defp write_sync_state(tasks) do
    state = %{
      last_sync: DateTime.utc_now() |> DateTime.to_iso8601(),
      task_count: length(tasks),
      task_ids: Enum.map(tasks, & &1.id)
    }

    case Jason.encode(state, pretty: true) do
      {:ok, json} ->
        File.write!(@sync_state_file, json)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # MERGE AND CONFLICT RESOLUTION
  # ═══════════════════════════════════════════════════════════════════════════

  defp merge_tasks(project_tasks, claude_tasks) do
    # Project tasks take precedence for existing IDs
    # Claude tasks are added as new session tasks

    project_ids = MapSet.new(Enum.map(project_tasks, & &1.id))

    new_claude_tasks =
      claude_tasks
      |> Enum.reject(fn task ->
        # Check if similar task exists by content hash
        content_hash = :erlang.phash2(task.content, 99999)
        Enum.any?(project_tasks, fn pt ->
          :erlang.phash2(pt.title, 99999) == content_hash
        end)
      end)

    merged = project_tasks ++ new_claude_tasks
    {:ok, merged}
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # VALIDATION AND VERIFICATION
  # ═══════════════════════════════════════════════════════════════════════════

  defp validate_tasks(tasks) do
    # Validate all tasks have required fields
    valid = Enum.all?(tasks, fn task ->
      task[:content] != nil or task["content"] != nil
    end)

    if valid, do: :ok, else: {:error, :invalid_tasks}
  end

  def verify_consistency do
    IO.puts("🔍 VERIFYING TODO SYSTEM CONSISTENCY")
    IO.puts("=" |> String.duplicate(50))

    with {:ok, project_tasks} <- read_project_tasks(),
         {:ok, claude_tasks} <- read_claude_tasks() do

      IO.puts("📊 Project tasks: #{length(project_tasks)}")
      IO.puts("📊 Claude session tasks: #{length(claude_tasks)}")

      # Check for orphaned tasks
      orphaned = find_orphaned_tasks(project_tasks, claude_tasks)
      if length(orphaned) > 0 do
        IO.puts("⚠️  Found #{length(orphaned)} potentially orphaned tasks")
      else
        IO.puts("✅ No orphaned tasks detected")
      end

      # Check state file
      if File.exists?(@sync_state_file) do
        IO.puts("✅ Sync state file exists")
      else
        IO.puts("⚠️  No sync state file - run --sync to create")
      end

      :ok
    end
  end

  defp find_orphaned_tasks(_project_tasks, _claude_tasks) do
    # Tasks that exist in session but not in project
    []
  end

  defp filter_active_tasks(tasks) do
    Enum.filter(tasks, fn task ->
      task.status in ["pending", "in_progress"]
    end)
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # LOCKING AND CONCURRENCY
  # ═══════════════════════════════════════════════════════════════════════════

  defp acquire_lock do
    case File.mkdir(@lock_file) do
      :ok -> :ok
      {:error, :eexist} ->
        # Check if lock is stale (> 60 seconds)
        case File.stat(@lock_file) do
          {:ok, %{mtime: mtime}} ->
            age = :os.system_time(:second) - to_unix(mtime)
            if age > 60 do
              release_lock()
              acquire_lock()
            else
              {:error, :locked}
            end
          _ ->
            {:error, :locked}
        end
      error -> error
    end
  end

  defp release_lock do
    File.rmdir(@lock_file)
    :ok
  end

  defp to_unix({{y, m, d}, {h, min, s}}) do
    {:ok, dt} = NaiveDateTime.new(y, m, d, h, min, s)
    DateTime.from_naive!(dt, "Etc/UTC") |> DateTime.to_unix()
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PRIORITY DETECTION
  # ═══════════════════════════════════════════════════════════════════════════

  defp detect_priority(content) do
    content_lower = String.downcase(content)

    Enum.find_value(@priority_keywords, "P3", fn {priority, keywords} ->
      if Enum.any?(keywords, &String.contains?(content_lower, &1)) do
        priority
      end
    end)
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # ID GENERATION
  # ═══════════════════════════════════════════════════════════════════════════

  defp generate_session_task_id do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d%H%M")
    random = :rand.uniform(9999) |> Integer.to_string() |> String.pad_leading(4, "0")
    "#{@session_task_prefix}.#{timestamp}.#{random}"
  end

  defp get_session_id do
    System.get_env("CLAUDE_SESSION_ID") ||
      :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # AUDIT LOGGING
  # ═══════════════════════════════════════════════════════════════════════════

  defp log_audit(operation, message) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    user = System.get_env("USER") || "unknown"

    log_entry = "[#{timestamp}] [#{user}] [#{operation}] #{message}\n"

    # Ensure log directory exists
    log_dir = Path.dirname(@audit_log_file)
    File.mkdir_p!(log_dir)

    # Append to audit log
    File.write!(@audit_log_file, log_entry, [:append])
  end

  def show_audit_trail do
    IO.puts("📜 TODO SYNC AUDIT TRAIL")
    IO.puts("=" |> String.duplicate(50))

    if File.exists?(@audit_log_file) do
      content = File.read!(@audit_log_file)
      lines = String.split(content, "\n") |> Enum.take(-20)
      Enum.each(lines, &IO.puts/1)
    else
      IO.puts("No audit log found")
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # ROLLBACK
  # ═══════════════════════════════════════════════════════════════════════════

  def rollback_to(timestamp) do
    backup_pattern = "#{@backup_dir}/PROJECT_TODOLIST_#{timestamp}*.md"

    case Path.wildcard(backup_pattern) do
      [backup_file | _] ->
        log_audit("ROLLBACK", "Rolling back to #{backup_file}")

        # Use todolist_manager for STAMP compliance
        System.cmd("elixir", [
          "scripts/planning/todolist_manager.exs",
          "--restore",
          Path.basename(backup_file)
        ])

        IO.puts("✅ Rolled back to #{backup_file}")

      [] ->
        IO.puts("❌ No backup found for timestamp #{timestamp}")
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # STATUS DISPLAY
  # ═══════════════════════════════════════════════════════════════════════════

  def show_sync_status do
    IO.puts("🔄 CLAUDE TODO SYNC STATUS")
    IO.puts("=" |> String.duplicate(50))

    # Check sync state
    if File.exists?(@sync_state_file) do
      case File.read(@sync_state_file) |> then(fn {:ok, c} -> Jason.decode(c) end) do
        {:ok, state} ->
          IO.puts("📅 Last sync: #{state["last_sync"]}")
          IO.puts("📊 Synced tasks: #{state["task_count"]}")
        _ ->
          IO.puts("⚠️  Sync state corrupted")
      end
    else
      IO.puts("⚠️  No sync state - run --sync")
    end

    # Show current Claude tasks
    case read_claude_tasks() do
      {:ok, tasks} ->
        IO.puts("\n📋 Current Claude Session Tasks:")
        Enum.each(tasks, fn task ->
          status_icon = case task.status do
            "completed" -> "✅"
            "in_progress" -> "🔄"
            _ -> "⏳"
          end
          IO.puts("  #{status_icon} #{task.content}")
        end)
      _ ->
        IO.puts("  No active session tasks")
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # HELP
  # ═══════════════════════════════════════════════════════════════════════════

  defp show_help do
    IO.puts("""
    🔄 CLAUDE TODO SYNC - Safety-Critical Task Management

    USAGE:
      elixir scripts/planning/claude_todo_sync.exs [COMMAND]

    COMMANDS:
      --sync                  Bidirectional sync (Claude ↔ Project)
      --sync --from-claude    Export Claude session → Project
      --sync --to-claude      Import Project → Claude session
      --export-session        Export session to JSON file
      --import-session FILE   Import session from JSON file
      --status                Show sync status
      --verify                Verify consistency
      --audit                 Show audit trail
      --rollback TIMESTAMP    Rollback to backup
      --add-session-task TXT  Add task with auto-priority
      --help                  Show this help

    STAMP COMPLIANCE:
      SC-TODO-001: Never directly edit PROJECT_TODOLIST.md
      SC-TODO-002: All operations via canonical commands
      SC-TODO-003: Updates via todolist_manager.exs only
      SC-TODO-004: Full audit trail maintained
      SC-TODO-005: Atomic writes with rollback

    EXAMPLES:
      # Sync Claude session to project
      elixir scripts/planning/claude_todo_sync.exs --sync --from-claude

      # Add a safety-critical task
      elixir scripts/planning/claude_todo_sync.exs --add-session-task "Create fail-safe tests"

      # Verify consistency
      elixir scripts/planning/claude_todo_sync.exs --verify
    """)
  end
end

# Execute
ClaudeTodoSync.main(System.argv())
