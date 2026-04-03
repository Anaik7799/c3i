# L2 Integration Level BDD Tests - Parser Integration
# STAMP: SC-PLAN-001 to SC-PLAN-010
# Coverage: 55 scenarios for parser and repository integration

@l2_integration @parser @repository
Feature: Planning System Parser and Repository Integration
  As the Planning System
  I need to parse markdown and persist to SQLite
  So that tasks are correctly stored and synchronized

  Background:
    Given the SQLite database is initialized at "data/planning/tasks.db"
    And the MarkdownParser module is loaded
    And the Repository module is loaded

  # ==========================================================================
  # Markdown Parsing Integration
  # ==========================================================================

  @markdown_parsing @task_extraction
  Scenario: Parse task from markdown line
    Given markdown line "- [ ] 1.1 Implement feature X [P1] @claude #dev"
    When the line is parsed by MarkdownParser
    Then a Task should be extracted with:
      | field       | value              |
      | id          | 1.1                |
      | title       | Implement feature X |
      | status      | pending            |
      | priority    | P1                 |
      | assignee    | claude             |
      | tag         | dev                |

  @markdown_parsing @status_variants
  Scenario Outline: Parse different task status markers
    Given markdown line "<markdown>"
    When the line is parsed
    Then the task status should be "<status>"

    Examples:
      | markdown                           | status      |
      | - [ ] 1.0 Pending task             | pending     |
      | - [x] 1.0 Completed task           | completed   |
      | - [~] 1.0 In progress task         | in_progress |
      | - [-] 1.0 Blocked task             | blocked     |
      | - [!] 1.0 Critical task            | critical    |

  @markdown_parsing @priority_levels
  Scenario Outline: Parse priority levels
    Given markdown line "- [ ] 1.0 Task [<priority>]"
    When the line is parsed
    Then the task priority should be "<priority>"

    Examples:
      | priority |
      | P0       |
      | P1       |
      | P2       |
      | P3       |

  @markdown_parsing @hierarchical_ids
  Scenario Outline: Parse hierarchical task IDs
    Given markdown line "- [ ] <id> Task title"
    When the line is parsed
    Then the task ID should be "<id>"
    And the parent ID should be "<parent>"
    And the depth should be <depth>

    Examples:
      | id          | parent    | depth |
      | 1.0         |           | 1     |
      | 1.1         | 1.0       | 2     |
      | 1.1.1       | 1.1       | 3     |
      | 1.1.1.1     | 1.1.1     | 4     |
      | 1.1.1.1.1   | 1.1.1.1   | 5     |

  @markdown_parsing @metadata_extraction
  Scenario: Extract all metadata from complex task line
    Given markdown line "- [~] 42.3.2.1 Build Zenoh mesh [P0] @gemini #infrastructure #critical due:2026-01-20"
    When the line is parsed
    Then the extracted task should have:
      | field       | value                |
      | id          | 42.3.2.1             |
      | title       | Build Zenoh mesh     |
      | status      | in_progress          |
      | priority    | P0                   |
      | assignee    | gemini               |
      | tags        | infrastructure,critical |
      | due_date    | 2026-01-20           |

  # ==========================================================================
  # Repository CRUD Operations
  # ==========================================================================

  @repository @create
  Scenario: Create new task in repository
    Given no task exists with ID "99.1"
    When I create a task with:
      | field    | value          |
      | id       | 99.1           |
      | title    | New test task  |
      | status   | pending        |
      | priority | P2             |
    Then the task should be persisted in SQLite
    And I should be able to read task "99.1"
    And the task title should be "New test task"

  @repository @read
  Scenario: Read existing task from repository
    Given task "1.0" exists with title "Test task"
    When I read task "1.0" from repository
    Then the task should be returned
    And the task title should be "Test task"

  @repository @update
  Scenario: Update task status in repository
    Given task "1.0" exists with status "pending"
    When I update task "1.0" with status "completed"
    Then the update should succeed
    And reading task "1.0" should show status "completed"

  @repository @delete
  Scenario: Delete task from repository
    Given task "99.9" exists
    When I delete task "99.9"
    Then the task should be removed from SQLite
    And reading task "99.9" should return not found

  @repository @list
  Scenario: List all tasks from repository
    Given 10 tasks exist in the repository
    When I list all tasks
    Then I should receive 10 tasks
    And tasks should be ordered by ID

  @repository @filter_by_status
  Scenario Outline: Filter tasks by status
    Given tasks exist with various statuses
    When I filter tasks by status "<status>"
    Then only tasks with status "<status>" should be returned

    Examples:
      | status      |
      | pending     |
      | in_progress |
      | completed   |
      | blocked     |

  @repository @filter_by_priority
  Scenario: Filter tasks by priority
    Given tasks exist with priorities P0, P1, P2, P3
    When I filter tasks by priority "P0"
    Then only P0 priority tasks should be returned

  @repository @filter_by_assignee
  Scenario: Filter tasks by assignee
    Given tasks assigned to "claude", "gemini", "grok"
    When I filter tasks by assignee "claude"
    Then only tasks assigned to "claude" should be returned

  # ==========================================================================
  # SQLite Persistence
  # ==========================================================================

  @sqlite @schema
  Scenario: Verify SQLite schema is correct
    When I inspect the tasks table schema
    Then it should have columns:
      | column     | type    | nullable |
      | id         | TEXT    | false    |
      | title      | TEXT    | false    |
      | status     | TEXT    | false    |
      | priority   | TEXT    | true     |
      | assignee   | TEXT    | true     |
      | parent_id  | TEXT    | true     |
      | created_at | TEXT    | false    |
      | updated_at | TEXT    | false    |

  @sqlite @wal_mode
  Scenario: Verify SQLite WAL mode is enabled
    When I check SQLite journal mode
    Then it should be "wal"

  @sqlite @transactions
  Scenario: Verify transactional integrity
    Given task "1.0" exists with status "pending"
    When I start a transaction
    And I update task "1.0" to status "completed"
    And the transaction is rolled back
    Then task "1.0" should still have status "pending"

  @sqlite @concurrent_access
  Scenario: Handle concurrent read/write access
    Given task "1.0" exists
    When 5 concurrent reads are performed on task "1.0"
    And 1 concurrent write updates task "1.0"
    Then all operations should complete without error
    And the final state should be consistent

  # ==========================================================================
  # Markdown Generation
  # ==========================================================================

  @markdown_generation @single_task
  Scenario: Generate markdown from single task
    Given a task with ID "1.0", title "Test task", status "pending", priority "P1"
    When the task is converted to markdown
    Then the output should be "- [ ] 1.0 Test task [P1]"

  @markdown_generation @full_document
  Scenario: Generate full PROJECT_TODOLIST.md from repository
    Given 5 tasks exist in the repository
    When I generate the full markdown document
    Then the document should have a header section
    And the document should contain all 5 tasks
    And tasks should be grouped by category
    And the document should be valid markdown

  @markdown_generation @round_trip
  Scenario: Round-trip markdown parsing and generation
    Given markdown content with 10 tasks
    When the content is parsed into tasks
    And the tasks are regenerated to markdown
    Then the output should be semantically equivalent to input
    And all task metadata should be preserved

  # ==========================================================================
  # DuckDB Analytics Integration
  # ==========================================================================

  @duckdb @history
  Scenario: Record task history in DuckDB
    Given task "1.0" is created
    When task "1.0" is updated 3 times
    Then DuckDB should have 4 history entries for task "1.0"
    And entries should be ordered by timestamp

  @duckdb @analytics
  Scenario: Query task analytics from DuckDB
    Given 100 tasks with various statuses and completion dates
    When I query completion rate for the last 7 days
    Then I should receive a daily completion count
    And the query should complete within 100ms

  # ==========================================================================
  # Sync Protocol
  # ==========================================================================

  @sync @sqlite_to_markdown
  Scenario: Sync SQLite changes to PROJECT_TODOLIST.md
    Given task "1.0" status is updated in SQLite to "completed"
    When the sync process runs
    Then PROJECT_TODOLIST.md should reflect status "completed"
    And the sync should be atomic

  @sync @conflict_resolution
  Scenario: Handle sync conflicts with last-write-wins
    Given task "1.0" has different states in SQLite and markdown
    When sync conflict is detected
    Then SQLite state should be authoritative
    And markdown should be regenerated from SQLite

  # ==========================================================================
  # Error Handling
  # ==========================================================================

  @error_handling @malformed_markdown
  Scenario: Handle malformed markdown gracefully
    Given markdown line "- [invalid Task without proper format"
    When the line is parsed
    Then parsing should fail gracefully
    And an error should be logged
    And the parser should continue with next line

  @error_handling @database_error
  Scenario: Handle database connection failure
    Given the database file is locked
    When a write operation is attempted
    Then a clear error should be returned
    And the operation should be retryable

  @error_handling @duplicate_id
  Scenario: Reject duplicate task IDs
    Given task "1.0" already exists
    When I try to create another task with ID "1.0"
    Then the operation should fail with duplicate ID error
    And the existing task should remain unchanged
