# L3 Component Level BDD Tests - CLI Interface
# STAMP: SC-PLAN-001 to SC-PLAN-015
# Coverage: 70 scenarios for CLI command interface

@l3_component @cli @interface
Feature: Planning System CLI Interface
  As a user or agent
  I need a comprehensive CLI interface
  So that I can manage tasks efficiently from the command line

  Background:
    Given the Planning CLI is available
    And the SQLite database is initialized
    And the user is authenticated

  # ==========================================================================
  # sa-plan status Command
  # ==========================================================================

  @sa_plan @status
  Scenario: Display project status summary
    Given 10 tasks exist with various statuses
    When I run "sa-plan status"
    Then the output should show:
      | metric          | format    |
      | Total Tasks     | number    |
      | Pending         | number    |
      | In Progress     | number    |
      | Completed       | number    |
      | Blocked         | number    |
      | Completion Rate | percentage|

  @sa_plan @status_verbose
  Scenario: Display verbose status with breakdown
    Given 10 tasks exist across 3 categories
    When I run "sa-plan status --verbose"
    Then the output should include category breakdown
    And the output should include priority distribution
    And the output should include assignee workload

  @sa_plan @status_json
  Scenario: Output status in JSON format
    Given tasks exist in the repository
    When I run "sa-plan status --format json"
    Then the output should be valid JSON
    And the JSON should contain all status metrics

  # ==========================================================================
  # sa-plan list Command
  # ==========================================================================

  @sa_plan @list
  Scenario: List all tasks
    Given 20 tasks exist in the repository
    When I run "sa-plan list"
    Then all 20 tasks should be displayed
    And tasks should be formatted with ID, title, status, priority

  @sa_plan @list_filter_status
  Scenario Outline: List tasks filtered by status
    Given tasks exist with status "pending", "in_progress", "completed"
    When I run "sa-plan list --status <status>"
    Then only tasks with status "<status>" should be shown

    Examples:
      | status      |
      | pending     |
      | in_progress |
      | completed   |
      | blocked     |

  @sa_plan @list_filter_priority
  Scenario: List tasks filtered by priority
    Given tasks exist with priorities P0 through P3
    When I run "sa-plan list --priority P0"
    Then only P0 priority tasks should be shown

  @sa_plan @list_filter_assignee
  Scenario: List tasks filtered by assignee
    Given tasks assigned to different agents
    When I run "sa-plan list --assignee claude"
    Then only tasks assigned to "claude" should be shown

  @sa_plan @list_tree
  Scenario: List tasks in tree format
    Given hierarchical tasks exist (parent-child relationships)
    When I run "sa-plan list --tree"
    Then tasks should be displayed in tree structure
    And child tasks should be indented under parents

  @sa_plan @list_limit
  Scenario: Limit number of tasks displayed
    Given 100 tasks exist
    When I run "sa-plan list --limit 10"
    Then only 10 tasks should be displayed

  @sa_plan @list_sort
  Scenario Outline: Sort task list
    Given tasks exist with various properties
    When I run "sa-plan list --sort <field>"
    Then tasks should be sorted by <field>

    Examples:
      | field      |
      | id         |
      | priority   |
      | status     |
      | created_at |
      | updated_at |

  # ==========================================================================
  # sa-plan add Command
  # ==========================================================================

  @sa_plan @add
  Scenario: Add new task with minimal parameters
    When I run "sa-plan add 'Implement new feature'"
    Then a new task should be created
    And the task should have status "pending"
    And the task should have default priority "P2"
    And the task ID should be auto-generated

  @sa_plan @add_with_priority
  Scenario Outline: Add task with specific priority
    When I run "sa-plan add 'Task with priority' --priority <priority>"
    Then the task should be created with priority "<priority>"

    Examples:
      | priority |
      | P0       |
      | P1       |
      | P2       |
      | P3       |

  @sa_plan @add_with_id
  Scenario: Add task with specific ID
    When I run "sa-plan add 'Specific ID task' --id 99.1"
    Then the task should be created with ID "99.1"

  @sa_plan @add_with_parent
  Scenario: Add subtask under parent
    Given task "1.0" exists
    When I run "sa-plan add 'Subtask' --parent 1.0"
    Then a subtask should be created under "1.0"
    And the subtask ID should be "1.1" or next available

  @sa_plan @add_with_assignee
  Scenario: Add task with assignee
    When I run "sa-plan add 'Assigned task' --assignee claude"
    Then the task should be assigned to "claude"

  @sa_plan @add_with_tags
  Scenario: Add task with tags
    When I run "sa-plan add 'Tagged task' --tags dev,urgent,backend"
    Then the task should have tags "dev", "urgent", "backend"

  @sa_plan @add_with_due_date
  Scenario: Add task with due date
    When I run "sa-plan add 'Deadline task' --due 2026-01-31"
    Then the task should have due date "2026-01-31"

  @sa_plan @add_batch
  Scenario: Add multiple tasks from file
    Given a file "tasks.txt" with 5 task definitions
    When I run "sa-plan add --from-file tasks.txt"
    Then 5 tasks should be created
    And each task should be validated

  # ==========================================================================
  # sa-plan update Command
  # ==========================================================================

  @sa_plan @update_status
  Scenario Outline: Update task status
    Given task "1.0" exists with status "pending"
    When I run "sa-plan update 1.0 --status <new_status>"
    Then task "1.0" should have status "<new_status>"

    Examples:
      | new_status  |
      | in_progress |
      | completed   |
      | blocked     |

  @sa_plan @update_priority
  Scenario: Update task priority
    Given task "1.0" exists with priority "P2"
    When I run "sa-plan update 1.0 --priority P0"
    Then task "1.0" should have priority "P0"

  @sa_plan @update_title
  Scenario: Update task title
    Given task "1.0" exists with title "Old title"
    When I run "sa-plan update 1.0 --title 'New title'"
    Then task "1.0" should have title "New title"

  @sa_plan @update_assignee
  Scenario: Update task assignee
    Given task "1.0" is assigned to "claude"
    When I run "sa-plan update 1.0 --assignee gemini"
    Then task "1.0" should be assigned to "gemini"

  @sa_plan @update_multiple
  Scenario: Update multiple fields at once
    Given task "1.0" exists
    When I run "sa-plan update 1.0 --status in_progress --priority P0 --assignee grok"
    Then task "1.0" should have status "in_progress"
    And task "1.0" should have priority "P0"
    And task "1.0" should be assigned to "grok"

  @sa_plan @update_complete
  Scenario: Quick complete task
    Given task "1.0" exists with status "pending"
    When I run "sa-plan complete 1.0"
    Then task "1.0" should have status "completed"

  @sa_plan @update_start
  Scenario: Quick start task
    Given task "1.0" exists with status "pending"
    When I run "sa-plan start 1.0"
    Then task "1.0" should have status "in_progress"

  @sa_plan @update_block
  Scenario: Block task with reason
    Given task "1.0" exists with status "in_progress"
    When I run "sa-plan block 1.0 --reason 'Waiting for API'"
    Then task "1.0" should have status "blocked"
    And task "1.0" should have block reason "Waiting for API"

  # ==========================================================================
  # sa-plan delete Command
  # ==========================================================================

  @sa_plan @delete
  Scenario: Delete single task
    Given task "99.0" exists
    When I run "sa-plan delete 99.0"
    Then task "99.0" should be removed
    And a confirmation message should be shown

  @sa_plan @delete_with_confirm
  Scenario: Delete with confirmation prompt
    Given task "1.0" exists
    When I run "sa-plan delete 1.0" without --force
    Then a confirmation prompt should appear
    And deletion should only proceed on confirmation

  @sa_plan @delete_cascade
  Scenario: Delete task with subtasks
    Given task "1.0" exists with subtasks "1.1", "1.2", "1.3"
    When I run "sa-plan delete 1.0 --cascade"
    Then task "1.0" should be removed
    And subtasks "1.1", "1.2", "1.3" should also be removed

  # ==========================================================================
  # sa-plan search Command
  # ==========================================================================

  @sa_plan @search
  Scenario: Search tasks by keyword
    Given tasks exist with titles containing "Zenoh"
    When I run "sa-plan search 'Zenoh'"
    Then tasks matching "Zenoh" should be displayed

  @sa_plan @search_regex
  Scenario: Search with regex pattern
    Given tasks exist with various titles
    When I run "sa-plan search --regex 'SC-TODO-0[0-9]+'"
    Then tasks matching the regex should be displayed

  @sa_plan @search_combined
  Scenario: Combined search with filters
    When I run "sa-plan search 'feature' --status pending --priority P1"
    Then only pending P1 tasks matching "feature" should be shown

  # ==========================================================================
  # sa-plan sync Command
  # ==========================================================================

  @sa_plan @sync
  Scenario: Sync tasks to PROJECT_TODOLIST.md
    Given tasks have been modified in SQLite
    When I run "sa-plan sync"
    Then PROJECT_TODOLIST.md should be regenerated
    And changes should be reflected in the markdown

  @sa_plan @sync_dry_run
  Scenario: Preview sync changes
    Given tasks have been modified
    When I run "sa-plan sync --dry-run"
    Then changes should be displayed
    But PROJECT_TODOLIST.md should not be modified

  @sa_plan @sync_backup
  Scenario: Create backup before sync
    Given PROJECT_TODOLIST.md exists
    When I run "sa-plan sync --backup"
    Then a backup file should be created
    And then the sync should proceed

  # ==========================================================================
  # sa-plan import/export Commands
  # ==========================================================================

  @sa_plan @export_json
  Scenario: Export tasks to JSON
    Given tasks exist in the repository
    When I run "sa-plan export --format json --output tasks.json"
    Then tasks.json should be created
    And it should contain all tasks in valid JSON

  @sa_plan @export_csv
  Scenario: Export tasks to CSV
    Given tasks exist in the repository
    When I run "sa-plan export --format csv --output tasks.csv"
    Then tasks.csv should be created with proper headers

  @sa_plan @import_json
  Scenario: Import tasks from JSON
    Given a valid tasks.json file exists
    When I run "sa-plan import --format json --input tasks.json"
    Then tasks should be imported to the repository
    And duplicate IDs should be handled appropriately

  # ==========================================================================
  # Chaya TUI Commands
  # ==========================================================================

  @chaya @status
  Scenario: Display Chaya TUI status
    When I run "chaya status"
    Then the Chaya status should be displayed
    And it should show health metrics
    And it should show active OODA cycle state

  @chaya @ooda
  Scenario: Trigger OODA cycle
    When I run "chaya ooda"
    Then an OODA cycle should execute
    And the cycle should complete within 100ms
    And the result should be displayed

  @chaya @mesh
  Scenario: Display mesh topology
    Given mesh nodes are active
    When I run "chaya mesh"
    Then the mesh topology should be displayed
    And it should show task distribution across nodes

  @chaya @tasks
  Scenario: List tasks in Chaya format
    Given tasks exist
    When I run "chaya tasks"
    Then tasks should be displayed in TUI format
    And interactive navigation should be available

  # ==========================================================================
  # Error Handling
  # ==========================================================================

  @error_handling @invalid_command
  Scenario: Handle unknown command
    When I run "sa-plan unknown-command"
    Then an error message should be displayed
    And help text should be suggested

  @error_handling @missing_argument
  Scenario: Handle missing required argument
    When I run "sa-plan add" without task title
    Then an error should indicate missing title
    And usage help should be shown

  @error_handling @invalid_id
  Scenario: Handle non-existent task ID
    When I run "sa-plan update 999.999 --status completed"
    Then an error should indicate task not found

  @error_handling @invalid_status
  Scenario: Handle invalid status value
    When I run "sa-plan update 1.0 --status invalid_status"
    Then an error should list valid status values

  # ==========================================================================
  # Help and Documentation
  # ==========================================================================

  @help @general
  Scenario: Display general help
    When I run "sa-plan --help"
    Then help text should be displayed
    And all available commands should be listed
    And usage examples should be shown

  @help @command_specific
  Scenario Outline: Display command-specific help
    When I run "sa-plan <command> --help"
    Then detailed help for "<command>" should be shown
    And all options should be documented

    Examples:
      | command |
      | add     |
      | update  |
      | list    |
      | delete  |
      | sync    |
      | search  |

  @version
  Scenario: Display version information
    When I run "sa-plan --version"
    Then the version should be displayed
    And it should match the system version
