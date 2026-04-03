# L1 Unit Level BDD Tests - Access Control
# STAMP: SC-TODO-001 to SC-TODO-008
# AOR: AOR-TODO-001 to AOR-TODO-010
# Coverage: 45 scenarios for access control validation

@l1_unit @access_control @security @critical
Feature: PROJECT_TODOLIST.md Access Control Enforcement
  As a system security enforcer
  I need to prevent direct access to PROJECT_TODOLIST.md
  So that all task management goes through authorized F# interfaces

  Background:
    Given the Planning System is initialized
    And the AccessControl module is loaded
    And the access log is cleared

  # ==========================================================================
  # SC-TODO-001: Agents SHALL NOT read PROJECT_TODOLIST.md directly
  # ==========================================================================

  @sc_todo_001 @block_direct_read
  Scenario Outline: Block agent direct read access
    Given agent "<agent>" is authenticated
    When agent attempts DirectRead on "PROJECT_TODOLIST.md"
    Then the access result should be "Blocked"
    And the violation should be logged with constraint "SC-TODO-001"
    And the log entry should contain "Use sa-plan CLI instead"

    Examples:
      | agent        |
      | claude       |
      | gemini       |
      | grok         |
      | ClaudeAgent  |
      | GeminiAgent  |
      | GrokAgent    |
      | system       |

  @sc_todo_001 @allow_human_read
  Scenario: Allow human direct read access
    Given user "human_operator" is authenticated
    And user is NOT an agent
    When user attempts DirectRead on "PROJECT_TODOLIST.md"
    Then the access result should be "Allowed"
    And no violation should be logged

  # ==========================================================================
  # SC-TODO-002: Agents SHALL NOT write PROJECT_TODOLIST.md directly
  # ==========================================================================

  @sc_todo_002 @block_direct_write
  Scenario Outline: Block agent direct write access
    Given agent "<agent>" is authenticated
    When agent attempts DirectWrite on "PROJECT_TODOLIST.md"
    Then the access result should be "Blocked"
    And the violation should be logged with constraint "SC-TODO-002"

    Examples:
      | agent   |
      | claude  |
      | gemini  |
      | grok    |

  # ==========================================================================
  # SC-TODO-003: Shell command access patterns blocked
  # ==========================================================================

  @sc_todo_003 @shell_cat_blocked
  Scenario Outline: Block shell cat/head/tail commands on todolist
    Given agent "claude" is authenticated
    When agent executes shell command "<command>"
    Then the command should be blocked
    And the violation should be logged with constraint "SC-TODO-003"
    And the log should contain "forbidden pattern"

    Examples:
      | command                             |
      | cat PROJECT_TODOLIST.md             |
      | head PROJECT_TODOLIST.md            |
      | tail PROJECT_TODOLIST.md            |
      | less PROJECT_TODOLIST.md            |
      | more PROJECT_TODOLIST.md            |
      | cat ./PROJECT_TODOLIST.md           |
      | head -n 10 PROJECT_TODOLIST.md      |

  @sc_todo_003 @shell_sed_blocked
  Scenario Outline: Block shell sed/awk commands on todolist
    Given agent "gemini" is authenticated
    When agent executes shell command "<command>"
    Then the command should be blocked
    And the violation should be logged with constraint "SC-TODO-003"

    Examples:
      | command                                   |
      | sed -i 's/foo/bar/' PROJECT_TODOLIST.md   |
      | awk '{print}' PROJECT_TODOLIST.md         |
      | sed 's/pending/done/' PROJECT_TODOLIST.md |

  @sc_todo_003 @shell_grep_blocked
  Scenario Outline: Block shell grep/rg commands on todolist
    Given agent "grok" is authenticated
    When agent executes shell command "<command>"
    Then the command should be blocked
    And the violation should be logged with constraint "SC-TODO-003"

    Examples:
      | command                          |
      | grep "pending" PROJECT_TODOLIST.md |
      | rg "P0" PROJECT_TODOLIST.md        |
      | grep -n "TODO" PROJECT_TODOLIST.md |

  @sc_todo_003 @shell_echo_redirect_blocked
  Scenario Outline: Block shell echo/printf redirect to todolist
    Given agent "claude" is authenticated
    When agent executes shell command "<command>"
    Then the command should be blocked
    And the violation should be logged with constraint "SC-TODO-003"

    Examples:
      | command                                     |
      | echo "new task" >> PROJECT_TODOLIST.md      |
      | printf "task" >> PROJECT_TODOLIST.md        |
      | echo "## Header" >> ./PROJECT_TODOLIST.md   |

  @sc_todo_003 @allow_other_files
  Scenario: Allow shell commands on non-todolist files
    Given agent "claude" is authenticated
    When agent executes shell command "cat README.md"
    Then the command should be allowed
    And no violation should be logged

  # ==========================================================================
  # SC-TODO-004: Authorized methods allowed
  # ==========================================================================

  @sc_todo_004 @fsharp_cli_allowed
  Scenario Outline: Allow F# CLI access to todolist
    Given agent "<agent>" is authenticated
    When agent accesses todolist via method "FSharpCLI"
    Then the access result should be "Allowed"
    And the access should be logged with constraint "SC-TODO-004"

    Examples:
      | agent   |
      | claude  |
      | gemini  |
      | grok    |

  @sc_todo_004 @chaya_cli_allowed
  Scenario: Allow Chaya CLI access to todolist
    Given agent "claude" is authenticated
    When agent accesses todolist via method "ChayaCLI"
    Then the access result should be "Allowed"
    And the access should be logged with constraint "SC-TODO-004"

  @sc_todo_004 @fsharp_api_allowed
  Scenario: Allow F# API access to todolist
    Given agent "gemini" is authenticated
    When agent accesses todolist via method "FSharpAPI"
    Then the access result should be "Allowed"
    And the access should be logged with constraint "SC-TODO-004"

  # ==========================================================================
  # SC-TODO-005: Graph-based access verification
  # ==========================================================================

  @sc_todo_005 @graph_verification
  Scenario: Verify no forbidden paths exist in access control graph
    Given the access control graph is built
    When I verify forbidden paths for all agents
    Then no agent should have a path to DirectMethod -> FileNode
    And all Agent -> DirectMethod edges should have IsAllowed = false
    And all Agent -> AuthorizedMethod edges should have IsAllowed = true

  @sc_todo_005 @graph_structure
  Scenario: Verify access control graph structure
    Given the access control graph is built
    Then the graph should contain agent nodes for all known agents
    And the graph should contain method nodes for all access methods
    And the graph should contain a file node for PROJECT_TODOLIST.md

  # ==========================================================================
  # SC-TODO-006: Real-time detection
  # ==========================================================================

  @sc_todo_006 @realtime_detection
  Scenario: Detect and block access attempts in real-time
    Given agent "claude" is authenticated
    And the access monitor is running
    When agent rapidly attempts 10 DirectRead operations
    Then all 10 attempts should be blocked within 100ms total
    And all 10 violations should be logged

  # ==========================================================================
  # SC-TODO-007: Alert generation
  # ==========================================================================

  @sc_todo_007 @alert_generation
  Scenario: Generate alert on access violation
    Given agent "claude" is authenticated
    And the alert system is subscribed
    When agent attempts DirectRead on "PROJECT_TODOLIST.md"
    Then an alert should be generated
    And the alert should contain the agent ID
    And the alert should contain the violation type
    And the alert should be published to Zenoh topic "indrajaal/security/alerts"

  # ==========================================================================
  # SC-TODO-008: Immutable audit trail
  # ==========================================================================

  @sc_todo_008 @audit_trail
  Scenario: Log access attempts to immutable register
    Given agent "claude" is authenticated
    When agent attempts DirectRead on "PROJECT_TODOLIST.md"
    Then the attempt should be logged to the immutable register
    And the log entry should have a valid timestamp
    And the log entry should be append-only
    And the log entry should include the full access context

  @sc_todo_008 @audit_query
  Scenario: Query violations from audit log
    Given 5 access violations have been logged
    When I query violations from the access log
    Then I should receive exactly 5 violation entries
    And each entry should have result type "Blocked", "Denied", or "Alerted"

  # ==========================================================================
  # Edge Cases and Error Handling
  # ==========================================================================

  @edge_case @path_variations
  Scenario Outline: Block access regardless of path format
    Given agent "claude" is authenticated
    When agent attempts DirectRead on "<path>"
    Then the access result should be "Blocked"

    Examples:
      | path                                  |
      | PROJECT_TODOLIST.md                   |
      | ./PROJECT_TODOLIST.md                 |
      | ../intelitor-v5.2/PROJECT_TODOLIST.md |
      | /home/an/dev/ver/intelitor-v5.2/PROJECT_TODOLIST.md |

  @edge_case @case_insensitive
  Scenario Outline: Block access with case variations
    Given agent "claude" is authenticated
    When agent executes shell command "<command>"
    Then the command should be blocked

    Examples:
      | command                        |
      | CAT PROJECT_TODOLIST.md        |
      | Cat project_todolist.md        |
      | GREP "foo" PROJECT_TODOLIST.MD |

  @edge_case @unknown_method
  Scenario: Deny unknown access methods
    Given agent "claude" is authenticated
    When agent attempts access via unknown method "TeleportAccess"
    Then the access result should be "Denied"
    And the reason should be "Unknown access method"

  @error_handling @invalid_agent
  Scenario: Handle invalid agent ID gracefully
    Given an empty agent ID is provided
    When access decision is requested
    Then the system should handle the empty ID safely
    And the access should be denied or allowed based on non-agent rules
