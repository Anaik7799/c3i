@planning @access_control @security @critical
Feature: Planning System Access Control Enforcement (SC-TODO-001)
  As the Planning System Safety Kernel
  I need to enforce strict access control to PROJECT_TODOLIST.md
  So that only authorized entities can access planning data through approved channels

  Background:
    Given the Planning System is running
    And the Safety Kernel is initialized
    And the Access Control Matrix is loaded
    And PROJECT_TODOLIST.md exists at "/home/an/dev/ver/intelitor-v5.2/PROJECT_TODOLIST.md"
    And the F# Planning CLI is available

  # ============================================================================
  # HUMAN ACCESS SCENARIOS (Allowed with Restrictions)
  # ============================================================================

  @smoke @human_access
  Scenario: Human reads PROJECT_TODOLIST.md via file system (ALLOWED)
    Given a user with role "Human"
    And authentication token is valid
    When the user attempts to read "PROJECT_TODOLIST.md" via file system
    Then the operation should be "ALLOWED"
    And the access should be logged to audit trail
    And the log entry should include timestamp, user_id, action "read", target "PROJECT_TODOLIST.md"

  @smoke @human_access
  Scenario: Human writes to PROJECT_TODOLIST.md via file system (DENIED)
    Given a user with role "Human"
    And authentication token is valid
    When the user attempts to write to "PROJECT_TODOLIST.md" via file system
    Then the operation should be "DENIED"
    And the error message should be "PROJECT_TODOLIST.md is read-only. Use F# Planning CLI for modifications."
    And a security violation should be logged
    And the Circuit Breaker should increment violation counter

  @human_access @cli
  Scenario: Human uses F# Planning CLI to add task (ALLOWED)
    Given a user with role "Human"
    And authentication token is valid
    When the user executes F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan add "New Feature" --priority P1
      """
    Then the operation should be "ALLOWED"
    And the task should be added to SQLite state store
    And PROJECT_TODOLIST.md should be regenerated automatically
    And the access should be logged with method "F# CLI"

  @human_access @edge_case
  Scenario: Human attempts symbolic link to PROJECT_TODOLIST.md (DENIED)
    Given a user with role "Human"
    When the user creates a symbolic link "my_tasks.md" pointing to "PROJECT_TODOLIST.md"
    And the user attempts to write to "my_tasks.md"
    Then the operation should be "DENIED"
    And the Safety Kernel should detect the symlink
    And an alert should be sent to Security Sentry

  @human_access @edge_case
  Scenario: Human attempts hard link to PROJECT_TODOLIST.md (DENIED)
    Given a user with role "Human"
    When the user creates a hard link "tasks_copy.md" to "PROJECT_TODOLIST.md"
    And the user attempts to modify "tasks_copy.md"
    Then the operation should be "DENIED"
    And the Safety Kernel should detect the hard link via inode comparison
    And a security violation should be logged

  # ============================================================================
  # AI AGENT ACCESS SCENARIOS (Blocked for Direct Access)
  # ============================================================================

  @smoke @agent_access @critical
  Scenario: AI Agent attempts to read PROJECT_TODOLIST.md (BLOCKED)
    Given an entity with role "AI_Agent"
    And agent_id is "code-generator-001"
    When the agent attempts action "read_file" on "PROJECT_TODOLIST.md"
    Then the operation should be "BLOCKED"
    And the error message should contain "SC-TODO-001 VIOLATION"
    And the error message should contain "Use F# Runtime Interfaces"
    And a critical security alert should be triggered
    And the Circuit Breaker should increment violation counter

  @smoke @agent_access @critical
  Scenario: AI Agent attempts to write PROJECT_TODOLIST.md (BLOCKED)
    Given an entity with role "AI_Agent"
    And agent_id is "task-manager-agent"
    When the agent attempts action "write_file" on "PROJECT_TODOLIST.md"
    Then the operation should be "BLOCKED"
    And the error message should contain "SC-TODO-001 VIOLATION"
    And the error message should contain "STRICTLY FORBIDDEN"
    And a critical security alert should be triggered
    And the Circuit Breaker should increment violation counter by 2

  @agent_access @critical
  Scenario: AI Agent attempts shell command to read todolist (BLOCKED)
    Given an entity with role "AI_Agent"
    And agent_id is "shell-executor-002"
    When the agent attempts shell command "cat PROJECT_TODOLIST.md"
    Then the operation should be "BLOCKED"
    And the Safety Kernel should intercept the shell command
    And the error message should contain "SC-TODO-001 VIOLATION"
    And a critical security alert should be triggered

  @agent_access @critical
  Scenario: AI Agent attempts shell command to modify todolist (BLOCKED)
    Given an entity with role "AI_Agent"
    And agent_id is "batch-updater-003"
    When the agent attempts shell command "echo '- Task' >> PROJECT_TODOLIST.md"
    Then the operation should be "BLOCKED"
    And the Safety Kernel should intercept the shell command
    And the error message should contain "SC-TODO-001 VIOLATION"
    And a critical security alert should be triggered

  @agent_access @critical
  Scenario: AI Agent attempts sed command on todolist (BLOCKED)
    Given an entity with role "AI_Agent"
    And agent_id is "sed-editor-004"
    When the agent attempts shell command:
      """
      sed -i 's/TODO/DONE/g' PROJECT_TODOLIST.md
      """
    Then the operation should be "BLOCKED"
    And the Safety Kernel should intercept the shell command
    And the error message should contain "SC-TODO-001 VIOLATION"
    And a critical security alert should be triggered

  @agent_access @authorized
  Scenario: AI Agent uses F# CLI to query tasks (ALLOWED)
    Given an entity with role "AI_Agent"
    And agent_id is "cli-wrapper-005"
    And the agent has F# CLI execution permission
    When the agent executes F# CLI command:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan list
      """
    Then the operation should be "ALLOWED"
    And the agent should receive JSON output from CLI stdout
    And the agent should NOT receive file contents
    And the access should be logged with method "F# CLI (Agent)"

  @agent_access @api
  Scenario: AI Agent uses F# API to add task (ALLOWED)
    Given an entity with role "AI_Agent"
    And agent_id is "code-gen-006"
    And the agent has F# API access permission
    When the agent calls F# API method:
      """
      Cepaf.Smriti.Planning.Planner.addTask "New Feature" Priority.High
      """
    Then the operation should be "ALLOWED"
    And the task should be added to SQLite state store
    And PROJECT_TODOLIST.md should be regenerated by F# runtime
    And the access should be logged with method "F# API (Agent)"

  # ============================================================================
  # SYSTEM ACCESS SCENARIOS
  # ============================================================================

  @system_access
  Scenario: F# Planning Runtime regenerates PROJECT_TODOLIST.md (ALLOWED)
    Given an entity with role "System"
    And component_id is "FSharp.Planning.Runtime"
    When the component regenerates "PROJECT_TODOLIST.md"
    Then the operation should be "ALLOWED"
    And the file should be marked as "generated artifact"
    And a generation timestamp should be added to file header
    And the access should be logged with method "System Regeneration"

  @system_access
  Scenario: Backup Service reads PROJECT_TODOLIST.md (ALLOWED)
    Given an entity with role "System"
    And component_id is "Backup.Service"
    When the component attempts to read "PROJECT_TODOLIST.md"
    Then the operation should be "ALLOWED"
    And the access should be logged with method "System Backup"

  @system_access @denied
  Scenario: Unauthorized System Component modifies PROJECT_TODOLIST.md (DENIED)
    Given an entity with role "System"
    And component_id is "Unknown.Component"
    When the component attempts to write to "PROJECT_TODOLIST.md"
    Then the operation should be "DENIED"
    And a security violation should be logged
    And the component_id should be flagged for review

  # ============================================================================
  # UNKNOWN ENTITY SCENARIOS
  # ============================================================================

  @unknown_entity @critical
  Scenario: Unknown entity attempts to read PROJECT_TODOLIST.md (BLOCKED)
    Given an entity with no role assigned
    And entity_id is "unknown-process-007"
    When the entity attempts action "read_file" on "PROJECT_TODOLIST.md"
    Then the operation should be "BLOCKED"
    And the error message should be "Access denied: Entity not authenticated"
    And a critical security alert should be triggered

  @unknown_entity @critical
  Scenario: Unknown entity attempts to write PROJECT_TODOLIST.md (BLOCKED)
    Given an entity with no role assigned
    And entity_id is "malicious-script-008"
    When the entity attempts action "write_file" on "PROJECT_TODOLIST.md"
    Then the operation should be "BLOCKED"
    And the error message should be "Access denied: Entity not authenticated"
    And a critical security alert should be triggered
    And the entity should be added to threat watchlist

  # ============================================================================
  # EDGE CASES AND BOUNDARY CONDITIONS
  # ============================================================================

  @edge_case @race_condition
  Scenario: Concurrent access by Human and Agent (Enforced Separately)
    Given a user with role "Human" and user_id "human-001"
    And an entity with role "AI_Agent" and agent_id "agent-002"
    When both attempt to read "PROJECT_TODOLIST.md" simultaneously
    Then the Human operation should be "ALLOWED"
    And the Agent operation should be "BLOCKED"
    And both operations should be logged atomically
    And no race condition should occur in audit trail

  @edge_case @file_permissions
  Scenario: PROJECT_TODOLIST.md file permissions changed (Detected)
    Given PROJECT_TODOLIST.md has permissions "0644"
    When the file permissions are changed to "0666"
    Then the Safety Kernel should detect the permission change
    And an alert should be triggered
    And the permissions should be automatically reverted to "0644"

  @edge_case @file_missing
  Scenario: PROJECT_TODOLIST.md is deleted (Regenerated)
    Given PROJECT_TODOLIST.md exists
    When the file is deleted by an authorized system process
    Then the Safety Kernel should detect the deletion
    And the F# Planning Runtime should regenerate the file from SQLite state
    And a warning should be logged

  @edge_case @file_corrupted
  Scenario: PROJECT_TODOLIST.md is corrupted (Regenerated)
    Given PROJECT_TODOLIST.md exists
    When the file contents become corrupted
    Then the Safety Kernel should detect the corruption via checksum
    And the F# Planning Runtime should regenerate the file from SQLite state
    And a warning should be logged

  @edge_case @symlink_attack
  Scenario: Attacker replaces PROJECT_TODOLIST.md with symlink (Blocked)
    Given PROJECT_TODOLIST.md is a regular file
    When an attacker replaces it with a symlink to "/etc/passwd"
    Then the Safety Kernel should detect the file type change
    And all access attempts should be blocked
    And a critical security alert should be triggered
    And the symlink should be removed and file regenerated

  @edge_case @process_injection
  Scenario: Process injection attempts to bypass access control (Blocked)
    Given an AI Agent with agent_id "injector-009"
    When the agent attempts to inject code into F# Planning Runtime
    Then the Safety Kernel should detect the injection attempt
    And the operation should be "BLOCKED"
    And a critical security alert should be triggered
    And the Circuit Breaker should activate immediately

  @boundary @large_todolist
  Scenario: PROJECT_TODOLIST.md exceeds size limit (Handled)
    Given PROJECT_TODOLIST.md size is 10MB
    When an entity attempts to read the file
    Then the Safety Kernel should enforce size limits
    And reading should be rate-limited
    And a warning should be logged

  @boundary @rapid_access
  Scenario: Rapid repeated access attempts (Rate Limited)
    Given an AI Agent with agent_id "spammer-010"
    When the agent makes 100 read attempts in 1 second
    Then the Safety Kernel should detect the rapid access pattern
    And rate limiting should be enforced
    And the Circuit Breaker should activate
    And the agent should be temporarily blocked

  # ============================================================================
  # AUDIT AND COMPLIANCE SCENARIOS
  # ============================================================================

  @audit @compliance
  Scenario: Audit trail contains all required fields
    Given multiple access attempts have been made
    When the audit trail is retrieved
    Then each entry should contain:
      | field           | type      | required |
      | timestamp       | DateTime  | true     |
      | entity_id       | String    | true     |
      | entity_role     | String    | true     |
      | action          | String    | true     |
      | target          | String    | true     |
      | result          | String    | true     |
      | method          | String    | true     |
      | violation_count | Integer   | false    |

  @audit @compliance
  Scenario: Access Control Matrix is immutable
    Given the Access Control Matrix is loaded
    When an attempt is made to modify the matrix at runtime
    Then the operation should be "BLOCKED"
    And an alert should be triggered
    And the matrix should remain unchanged

  @regression @sc_todo_001
  Scenario Outline: SC-TODO-001 Enforcement for Various File Operations
    Given an entity with role "<role>"
    And entity_id is "<entity_id>"
    When the entity attempts action "<action>" on "PROJECT_TODOLIST.md"
    Then the operation should be "<result>"
    And the access should be logged

    Examples:
      | role      | entity_id      | action          | result  |
      | Human     | human-001      | read_file       | ALLOWED |
      | Human     | human-002      | write_file      | DENIED  |
      | AI_Agent  | agent-001      | read_file       | BLOCKED |
      | AI_Agent  | agent-002      | write_file      | BLOCKED |
      | AI_Agent  | agent-003      | shell_command   | BLOCKED |
      | System    | fsharp.runtime | write_file      | ALLOWED |
      | System    | unknown.sys    | write_file      | DENIED  |
      | Unknown   | unknown-001    | read_file       | BLOCKED |

  @regression @authorized_methods
  Scenario Outline: Authorized Access Methods (AOR-TODO-002)
    Given an entity with role "<role>"
    When the entity uses access method "<method>"
    Then the operation should be "<result>"

    Examples:
      | role      | method                 | result  |
      | Human     | F# CLI                 | ALLOWED |
      | AI_Agent  | F# CLI                 | ALLOWED |
      | AI_Agent  | F# API                 | ALLOWED |
      | Human     | Direct file read       | ALLOWED |
      | Human     | Direct file write      | DENIED  |
      | AI_Agent  | Direct file read       | BLOCKED |
      | AI_Agent  | Direct file write      | BLOCKED |
      | AI_Agent  | Shell cat command      | BLOCKED |
      | AI_Agent  | Shell sed command      | BLOCKED |
