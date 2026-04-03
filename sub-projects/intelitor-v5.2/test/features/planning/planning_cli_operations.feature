@planning @cli @operations @functional
Feature: F# Planning CLI Operations
  As a user of the Planning System
  I need to manage tasks through the F# Planning CLI
  So that I can add, update, list, and delete tasks safely and efficiently

  Background:
    Given the F# Planning CLI is available at "lib/cepaf/src/Cepaf/Cepaf.fsproj"
    And the SQLite database is initialized at "data/holons/planning/tasks.db"
    And the DuckDB history store is initialized at "data/holons/planning/history.duckdb"
    And the Planning Runtime is healthy
    And the Guardian safety kernel is active

  # ============================================================================
  # ADD TASK SCENARIOS
  # ============================================================================

  @smoke @add_task
  Scenario: Add a simple task with default priority
    Given I am authenticated as "human-user-001"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan add "Implement user authentication"
      """
    Then the command should exit with code 0
    And the output should contain "Task added successfully"
    And a new task should exist in SQLite with title "Implement user authentication"
    And the task priority should be "P2" (default)
    And the task status should be "TODO"
    And PROJECT_TODOLIST.md should be regenerated
    And the operation should be logged to DuckDB history

  @smoke @add_task
  Scenario: Add a task with explicit priority
    Given I am authenticated as "human-user-002"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan add "Fix critical security bug" --priority P0
      """
    Then the command should exit with code 0
    And the output should contain "Task added successfully"
    And the task priority should be "P0"
    And the task should appear at the top of P0 section in PROJECT_TODOLIST.md

  @add_task @validation
  Scenario: Add task with empty title (Rejected)
    Given I am authenticated as "human-user-003"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan add "" --priority P1
      """
    Then the command should exit with code 1
    And the output should contain "Error: Task title cannot be empty"
    And no task should be added to SQLite
    And PROJECT_TODOLIST.md should NOT be regenerated

  @add_task @validation
  Scenario: Add task with invalid priority (Rejected)
    Given I am authenticated as "human-user-004"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan add "New feature" --priority P5
      """
    Then the command should exit with code 1
    And the output should contain "Error: Invalid priority. Valid values: P0, P1, P2, P3"
    And no task should be added to SQLite

  @add_task @hierarchy
  Scenario: Add task with hierarchical numbering
    Given existing tasks in section "1.0 Development & Implementation"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan add "New dev task" --section "1.0"
      """
    Then the command should exit with code 0
    And the task should be assigned the next available number in section "1.0"
    And the task number should follow the pattern "1.X"

  @add_task @metadata
  Scenario: Add task with full metadata
    Given I am authenticated as "human-user-005"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan add "Comprehensive task" --priority P1 --section "2.0" --tags "testing,critical" --assignee "team-qa"
      """
    Then the command should exit with code 0
    And the task should have:
      | field      | value              |
      | priority   | P1                 |
      | section    | 2.0                |
      | tags       | testing,critical   |
      | assignee   | team-qa            |
      | created_by | human-user-005     |
      | status     | TODO               |

  @add_task @concurrency
  Scenario: Concurrent task additions (Serialized)
    Given I am authenticated as "human-user-006"
    When I execute 10 concurrent F# CLI commands to add tasks
    Then all 10 commands should succeed
    And exactly 10 tasks should be added to SQLite
    And no tasks should be lost or duplicated
    And each task should have a unique ID
    And PROJECT_TODOLIST.md should reflect all 10 tasks

  # ============================================================================
  # UPDATE TASK SCENARIOS
  # ============================================================================

  @smoke @update_task
  Scenario: Update task status to IN_PROGRESS
    Given a task exists with id "task-001" and status "TODO"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan update task-001 --status IN_PROGRESS
      """
    Then the command should exit with code 0
    And the output should contain "Task updated successfully"
    And the task status should be "IN_PROGRESS" in SQLite
    And PROJECT_TODOLIST.md should show the updated status
    And the update should be logged to DuckDB history

  @smoke @update_task
  Scenario: Update task status to COMPLETED
    Given a task exists with id "task-002" and status "IN_PROGRESS"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan update task-002 --status COMPLETED
      """
    Then the command should exit with code 0
    And the task status should be "COMPLETED" in SQLite
    And the task should have a completion timestamp
    And PROJECT_TODOLIST.md should move the task to completed section

  @update_task @priority
  Scenario: Update task priority
    Given a task exists with id "task-003" and priority "P2"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan update task-003 --priority P0
      """
    Then the command should exit with code 0
    And the task priority should be "P0" in SQLite
    And the task should be moved to P0 section in PROJECT_TODOLIST.md
    And a priority change event should be logged to DuckDB

  @update_task @validation
  Scenario: Update non-existent task (Rejected)
    Given no task exists with id "task-999"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan update task-999 --status COMPLETED
      """
    Then the command should exit with code 1
    And the output should contain "Error: Task not found: task-999"
    And no changes should be made to SQLite

  @update_task @validation
  Scenario: Update task with invalid status (Rejected)
    Given a task exists with id "task-004"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan update task-004 --status INVALID_STATUS
      """
    Then the command should exit with code 1
    And the output should contain "Error: Invalid status. Valid values: TODO, IN_PROGRESS, COMPLETED, BLOCKED, CANCELLED"
    And no changes should be made to SQLite

  @update_task @multiple_fields
  Scenario: Update multiple task fields simultaneously
    Given a task exists with id "task-005"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan update task-005 --status IN_PROGRESS --priority P1 --assignee "dev-team" --tags "urgent,bugfix"
      """
    Then the command should exit with code 0
    And all specified fields should be updated in SQLite
    And PROJECT_TODOLIST.md should reflect all changes
    And a single update event should be logged to DuckDB with all field changes

  @update_task @immutability
  Scenario: Attempt to update task ID (Rejected)
    Given a task exists with id "task-006"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan update task-006 --id "new-task-id"
      """
    Then the command should exit with code 1
    And the output should contain "Error: Task ID cannot be changed"
    And the task ID should remain "task-006" in SQLite

  # ============================================================================
  # LIST TASKS SCENARIOS
  # ============================================================================

  @smoke @list_tasks
  Scenario: List all tasks
    Given 5 tasks exist in various states
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan list
      """
    Then the command should exit with code 0
    And the output should contain all 5 tasks
    And tasks should be grouped by status
    And tasks should be sorted by priority within each status

  @list_tasks @filter
  Scenario: List tasks by status
    Given 10 tasks exist with various statuses
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan list --status TODO
      """
    Then the command should exit with code 0
    And the output should contain only tasks with status "TODO"
    And the count should match the number of TODO tasks in SQLite

  @list_tasks @filter
  Scenario: List tasks by priority
    Given 15 tasks exist with various priorities
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan list --priority P0
      """
    Then the command should exit with code 0
    And the output should contain only tasks with priority "P0"
    And tasks should be sorted by creation date descending

  @list_tasks @filter
  Scenario: List tasks by assignee
    Given 8 tasks exist assigned to different team members
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan list --assignee "dev-team"
      """
    Then the command should exit with code 0
    And the output should contain only tasks assigned to "dev-team"

  @list_tasks @format
  Scenario: List tasks in JSON format
    Given 5 tasks exist
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan list --format json
      """
    Then the command should exit with code 0
    And the output should be valid JSON
    And the JSON should contain an array of task objects
    And each task object should have all required fields

  @list_tasks @format
  Scenario: List tasks in table format
    Given 5 tasks exist
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan list --format table
      """
    Then the command should exit with code 0
    And the output should be a formatted table
    And the table should have headers: ID, Title, Status, Priority, Assignee

  @list_tasks @pagination
  Scenario: List tasks with pagination
    Given 50 tasks exist
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan list --page 2 --page-size 10
      """
    Then the command should exit with code 0
    And the output should contain 10 tasks
    And the output should indicate page 2 of 5
    And the tasks should be from offset 10-19

  @list_tasks @empty
  Scenario: List tasks when none exist
    Given no tasks exist in SQLite
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan list
      """
    Then the command should exit with code 0
    And the output should contain "No tasks found"

  # ============================================================================
  # DELETE TASK SCENARIOS
  # ============================================================================

  @delete_task @safety
  Scenario: Delete task with confirmation
    Given a task exists with id "task-007"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan delete task-007 --confirm
      """
    Then the command should exit with code 0
    And the output should contain "Task deleted successfully"
    And the task should be marked as deleted in SQLite (soft delete)
    And the task should NOT be permanently removed
    And PROJECT_TODOLIST.md should be regenerated without the task

  @delete_task @safety
  Scenario: Delete task without confirmation (Rejected)
    Given a task exists with id "task-008"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan delete task-008
      """
    Then the command should exit with code 1
    And the output should contain "Error: Deletion requires --confirm flag"
    And the task should still exist in SQLite

  @delete_task @archive
  Scenario: Delete task archives to DuckDB
    Given a task exists with id "task-009" with full history
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan delete task-009 --confirm
      """
    Then the command should exit with code 0
    And the task should be soft-deleted in SQLite
    And the full task history should be archived to DuckDB
    And the deletion event should be logged with timestamp and actor

  @delete_task @validation
  Scenario: Delete non-existent task (Rejected)
    Given no task exists with id "task-999"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan delete task-999 --confirm
      """
    Then the command should exit with code 1
    And the output should contain "Error: Task not found: task-999"

  @delete_task @recovery
  Scenario: Recover deleted task
    Given a task with id "task-010" was previously deleted
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan recover task-010
      """
    Then the command should exit with code 0
    And the output should contain "Task recovered successfully"
    And the task should be restored in SQLite with original data
    And PROJECT_TODOLIST.md should include the recovered task

  # ============================================================================
  # PRIORITY MANAGEMENT SCENARIOS
  # ============================================================================

  @priority @reorder
  Scenario: Reorder tasks within priority level
    Given 5 tasks exist with priority "P1"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan reorder P1 --task task-003 --position 1
      """
    Then the command should exit with code 0
    And task "task-003" should be at position 1 in P1 section
    And other tasks should be shifted accordingly
    And PROJECT_TODOLIST.md should reflect the new order

  @priority @bulk_update
  Scenario: Bulk update task priorities
    Given 10 tasks exist with priority "P2"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan bulk-update --status TODO --priority P1
      """
    Then the command should exit with code 0
    And all TODO tasks should have priority "P1"
    And a bulk update event should be logged to DuckDB
    And PROJECT_TODOLIST.md should reflect all priority changes

  @priority @statistics
  Scenario: Show priority distribution statistics
    Given 30 tasks exist across all priority levels
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan stats --by priority
      """
    Then the command should exit with code 0
    And the output should show task counts for each priority:
      | priority | count |
      | P0       | 5     |
      | P1       | 10    |
      | P2       | 12    |
      | P3       | 3     |

  @priority @auto_escalate
  Scenario: Auto-escalate overdue tasks
    Given 5 tasks are overdue by more than 7 days with priority "P2"
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan auto-escalate --days 7
      """
    Then the command should exit with code 0
    And the 5 overdue tasks should be escalated to priority "P1"
    And an escalation event should be logged for each task
    And PROJECT_TODOLIST.md should reflect the priority changes

  # ============================================================================
  # ERROR HANDLING AND EDGE CASES
  # ============================================================================

  @error_handling @database
  Scenario: CLI handles SQLite database locked error
    Given SQLite database is locked by another process
    When I execute any F# CLI command
    Then the command should retry up to 3 times with exponential backoff
    And if still locked, exit with code 2
    And the output should contain "Error: Database locked. Please try again."

  @error_handling @network
  Scenario: CLI handles network failure to Guardian service
    Given the Guardian service is unreachable
    When I execute a F# CLI command that requires Guardian approval
    Then the command should retry with exponential backoff
    And if Guardian remains unreachable, exit with code 3
    And the output should contain "Error: Safety validation service unavailable"

  @edge_case @unicode
  Scenario: Handle task titles with Unicode characters
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan add "Implement 日本語 support 🚀" --priority P1
      """
    Then the command should exit with code 0
    And the task title should be stored correctly in SQLite
    And PROJECT_TODOLIST.md should display Unicode characters correctly

  @edge_case @long_title
  Scenario: Handle task titles exceeding maximum length
    Given a task title with 1000 characters
    When I execute the F# CLI command to add the task
    Then the command should exit with code 1
    And the output should contain "Error: Task title exceeds maximum length of 500 characters"

  @edge_case @special_characters
  Scenario: Handle task titles with special shell characters
    When I execute the F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan add "Fix issue with $VAR && echo 'test'" --priority P1
      """
    Then the command should exit with code 0
    And the task title should be stored exactly as provided
    And no shell command injection should occur

  # ============================================================================
  # REGRESSION TESTS
  # ============================================================================

  @regression @sc_plan_001
  Scenario Outline: SC-PLAN-001 Compliance - F# CLI is Authoritative
    Given a task with id "<task_id>" exists
    When I execute F# CLI command "<command>"
    Then the command should "<result>"
    And PROJECT_TODOLIST.md should be "<todolist_action>"

    Examples:
      | task_id  | command                                      | result  | todolist_action |
      | task-101 | plan update task-101 --status COMPLETED     | succeed | regenerated     |
      | task-102 | plan delete task-102 --confirm              | succeed | regenerated     |
      | task-103 | plan update task-103 --priority P0          | succeed | regenerated     |
      | task-999 | plan update task-999 --status COMPLETED     | fail    | unchanged       |

  @regression @aor_plan_002
  Scenario Outline: AOR-PLAN-002 Compliance - Sync with PROJECT_TODOLIST.md
    Given F# Planning CLI performs operation "<operation>"
    When the operation completes successfully
    Then PROJECT_TODOLIST.md should be synchronized within "<max_delay>"

    Examples:
      | operation  | max_delay |
      | add        | 1s        |
      | update     | 1s        |
      | delete     | 1s        |
      | bulk_update| 2s        |
      | recover    | 1s        |
