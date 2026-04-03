@prajna @l5_bdd @commands @safety
Feature: Command Execution
  As an operator of the Prajna C3I cockpit
  I want to select targets, arm, confirm, and fire commands safely
  So that I can execute control operations with the required Arm & Fire safety protocol

  # STAMP: SC-SAFETY-001, SC-SAFETY-003, SC-SAFETY-004, SC-PHICS-001 to SC-PHICS-008
  # STAMP: SC-SIL4-006, SC-HMI-010, SC-SIL4-001
  # AOR: AOR-VER-009, AOR-XHOLON-014
  # Layer: L2 (Module), L3 (Domain), L4 (System)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/prajna/commands"
    And I am authenticated as "operator" with command execution rights
    And Guardian service is active

  # ----------------------------------------------------------
  # Target Selection
  # ----------------------------------------------------------

  @critical @sc_phics_007 @smoke
  Scenario: Command panel shows available targets and commands
    When the command execution page loads
    Then I should see a target selector panel on the left
    And targets should include:
      | Target Category  |
      | Nodes            |
      | Services         |
      | FLAME Pools      |
      | Containers       |
    And a command catalog should be visible on the right
    And no command should be executable until a target is selected
    And no command should be executable until Arm is activated

  @high @sc_phics_007
  Scenario Outline: Select a target type and see relevant commands
    Given I am on the command execution page
    When I select target category "<category>"
    Then I should see commands relevant to "<category>"
    And the command list should filter to show only applicable operations

    Examples:
      | category   |
      | Nodes      |
      | Services   |
      | FLAME Pools|
      | Containers |

  @high @sc_phics_007
  Scenario: Select a specific node target from the list
    Given I have selected the "Nodes" target category
    When I click on node "indrajaal@worker-1" in the target list
    Then the node should be highlighted as selected
    And its current status should be shown in the target info panel
    And the available commands for that node should update

  @high @sc_phics_007
  Scenario: Select multiple targets for bulk command
    Given I have selected the "Services" target category
    When I check the checkboxes for "sentinel", "guardian", and "smriti"
    Then all three services should be highlighted in the target list
    And the command panel header should say "3 targets selected"
    And only commands applicable to ALL selected targets should be shown

  # ----------------------------------------------------------
  # Arm & Fire Protocol — Standard Commands
  # ----------------------------------------------------------

  @critical @sc_safety_001 @arm_and_fire
  Scenario: Standard command requires Arm before Fire
    Given I have selected target "indrajaal@worker-1" and command "Restart Service"
    When I click "Arm Command"
    Then the Arm button should change to "Armed" with amber background
    And a 30-second countdown timer should start
    And a "Fire Command" button should appear
    And a "Disarm" button should appear
    And the command details should be locked in the armed state panel
    And a Zenoh event "command_armed" should be published

  @critical @sc_safety_001 @arm_and_fire
  Scenario: Fire standard command after arming
    Given I have armed "Restart Service" on "indrajaal@worker-1"
    When I click "Fire Command"
    Then a final confirmation dialog should appear with:
      | Field           | Value                      |
      | Command         | Restart Service            |
      | Target          | indrajaal@worker-1         |
      | Initiated by    | operator                   |
      | Timestamp       | (current UTC timestamp)    |
    When I click "Confirm Execute"
    Then the command should be dispatched to the target
    And the execution should be logged to the Immutable Register (SC-PHICS-001)
    And a Zenoh event "command_executed" should be published
    And the result should appear in the execution history feed

  @critical @sc_safety_001
  Scenario: Arm auto-expires after 30 seconds without firing
    Given I have armed "Restart Service"
    When 30 seconds elapse without firing
    Then the Armed state should expire
    And the arm button should revert to "Arm Command"
    And a "Command arm expired" message should flash
    And the Zenoh event "command_arm_expired" should be published

  # ----------------------------------------------------------
  # Critical Commands — Additional Confirmation Code
  # ----------------------------------------------------------

  @critical @sc_safety_001 @sc_sil4_006 @arm_and_fire
  Scenario: Critical command requires confirmation code entry
    Given I have selected command "Force Kill Node" (critical classification) on "indrajaal@seed-1"
    When I click "Arm Command"
    Then the arm should succeed and show Armed state
    When I click "Fire Command"
    Then the confirmation dialog should include an extra field: "Enter confirmation code"
    And a system-generated code should be displayed in a separate notification
    When I enter the correct confirmation code
    Then the "Confirm Execute" button should become active
    When I click "Confirm Execute"
    Then Guardian 2oo3 approval should be requested (SC-SIL4-006)
    And the command should only execute after Guardian quorum is met

  @critical @sc_safety_001 @arm_and_fire
  Scenario: Wrong confirmation code blocks critical command
    Given I have armed a critical command and the Fire dialog is open
    When I enter an incorrect confirmation code
    Then the "Confirm Execute" button should remain disabled
    And an error message "Incorrect confirmation code" should appear
    And the code input should be cleared for retry
    And after 3 failed attempts the dialog should close and arm should reset

  @high @sc_phics_004
  Scenario: Command blocked for insufficient role
    Given I am authenticated with role "viewer" (read-only)
    When I navigate to "/prajna/commands"
    Then all Arm buttons should be disabled
    And a banner should say "Command execution requires Operator role or higher"
    And all interactive command controls should be non-functional

  # ----------------------------------------------------------
  # Execution History
  # ----------------------------------------------------------

  @high @sc_phics_001 @history
  Scenario: Execution history shows all recent commands
    Given several commands have been executed in the last hour
    When I view the "Execution History" section
    Then I should see an audit feed with entries for each command
    And each entry should show:
      | Field         |
      | Command name  |
      | Target        |
      | Initiated by  |
      | Timestamp     |
      | Result status |
      | Immutable Register block ID |

  @high @sc_phics_001 @history
  Scenario: Failed command shows error detail in history
    Given a command execution failed due to target unreachable
    When I view the execution history
    Then the failed entry should be highlighted in red
    And I should be able to expand it to see the error message and stack trace
    And a "Retry" button should be available for retrying with the same parameters

  # ----------------------------------------------------------
  # Latency Monitoring (SC-PHICS-005, SC-PHICS-006)
  # ----------------------------------------------------------

  @high @sc_phics_005 @sc_phics_006
  Scenario: Command execution latency is tracked and alerted
    Given I execute a "Ping Node" command on "indrajaal@worker-1"
    When the command completes
    Then the execution latency should be recorded and shown in the history entry
    When execution latency exceeds 50ms
    Then an alert badge should appear on the history entry
    And a Zenoh event "command_latency_violation" should be published to "indrajaal/metrics/latency"

  # ----------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------

  @medium @sc_phics_002
  Scenario: Target becomes unreachable between Arm and Fire
    Given I have armed "Restart Service" on "indrajaal@worker-2"
    When "indrajaal@worker-2" goes offline before I click Fire
    Then the Fire button should disable
    And a warning should appear: "Target indrajaal@worker-2 is no longer reachable"
    And the arm should auto-reset

  @medium @sc_safety_004
  Scenario: Disarm cancels an active arm without executing
    Given I have armed a "Restart Service" command
    When I click "Disarm"
    Then the command arm should be cancelled
    And the page should return to unarmed state
    And a Zenoh event "command_disarmed" should be published
    And no command should be executed
