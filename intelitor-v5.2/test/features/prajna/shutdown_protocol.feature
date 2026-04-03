@prajna @l5_bdd @shutdown @safety
Feature: Shutdown Protocol
  As an operator of the Prajna C3I cockpit
  I want to initiate, monitor, and abort system shutdown sequences
  So that I can safely bring down the mesh with full state preservation

  # STAMP: SC-SAFETY-001, SC-SAFETY-004, SC-SIL4-013, SC-SIL4-007, SC-HMI-010
  # STAMP: SC-SAFETY-020, SC-VER-045
  # AOR: AOR-VER-009
  # Layer: L3 (Domain), L4 (System)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/prajna/shutdown"
    And the shutdown LiveView is connected via WebSocket
    And Guardian service is active and responsive

  # ----------------------------------------------------------
  # Mode Selection
  # ----------------------------------------------------------

  @critical @sc_sil4_013 @smoke
  Scenario: Shutdown page shows all available modes
    When the shutdown protocol page loads
    Then I should see three shutdown mode options:
      | Mode              | Description                                        |
      | Graceful          | Drain connections, checkpoint state, orderly stop  |
      | Abort             | Halt immediately, preserve last checkpoint         |
      | Force (Emergency) | Unconditional stop, bypass all draining            |
    And the "Graceful" mode should be pre-selected by default
    And the "Force" mode should have a red warning indicator
    And no shutdown button should be active yet (Arm required first)

  @critical @sc_safety_001
  Scenario: Select graceful shutdown mode
    Given the shutdown page is loaded
    When I select the "Graceful" shutdown mode
    Then the "Graceful" option should be highlighted
    And a description panel should appear: "Drains active connections before stopping"
    And the estimated shutdown time should be displayed (e.g., "~30 seconds")
    And the Arm button should be enabled

  @high @sc_safety_001
  Scenario: Select abort shutdown mode
    Given the shutdown page is loaded
    When I select the "Abort" shutdown mode
    Then the "Abort" option should be highlighted with an amber warning
    And a warning message should appear: "Active connections will be terminated"
    And the Arm button should be enabled with an amber border

  @critical @sc_safety_001 @sc_sil4_013
  Scenario: Force shutdown mode requires additional warning acknowledgement
    Given the shutdown page is loaded
    When I select the "Force" shutdown mode
    Then a modal warning should appear: "Force shutdown bypasses state preservation"
    And the modal should require me to type "CONFIRM FORCE" to acknowledge
    When I type "CONFIRM FORCE" in the confirmation box
    Then the modal should close
    And the "Force" option should be highlighted in red
    And an additional "Emergency" warning banner should appear on the page

  # ----------------------------------------------------------
  # Arm & Fire Protocol (SC-SAFETY-001)
  # ----------------------------------------------------------

  @critical @sc_safety_001 @arm_and_fire
  Scenario: Graceful shutdown requires Arm then Fire
    Given I have selected "Graceful" shutdown mode
    When I click "Arm Shutdown"
    Then the Arm button should change to "Armed" state with amber background
    And a countdown timer of 30 seconds should start
    And a "Fire Shutdown" button should become visible and active
    And a "Disarm" button should appear
    And a telemetry event "shutdown_armed" should be published to Zenoh

  @critical @sc_safety_001 @arm_and_fire
  Scenario: Fire initiates graceful shutdown sequence
    Given I have armed a "Graceful" shutdown
    When I click "Fire Shutdown"
    Then Guardian approval should be requested
    And a Guardian approval dialog should appear with shutdown details
    When Guardian approves the shutdown
    Then the shutdown sequence should begin
    And a progress indicator should show the 6 shutdown phases:
      | Phase | Name                    |
      | 1     | Signal handlers installed  |
      | 2     | New requests rejected      |
      | 3     | Active connections drained |
      | 4     | Dying gasp checkpoint      |
      | 5     | Services stopped           |
      | 6     | Process exit               |
    And each phase should turn green as it completes
    And Zenoh should receive "shutdown_phase_complete" for each phase

  @critical @sc_safety_001 @arm_and_fire
  Scenario: Arm times out if Fire is not clicked within 30 seconds
    Given I have armed a "Graceful" shutdown
    When 30 seconds elapse without clicking "Fire"
    Then the system should automatically disarm
    And the Armed state should revert to "Ready to Arm"
    And a "Arm timeout — shutdown cancelled" message should appear
    And a Zenoh event "shutdown_disarmed_timeout" should be published

  # ----------------------------------------------------------
  # Abort
  # ----------------------------------------------------------

  @critical @sc_safety_004 @abort
  Scenario: Abort shutdown during graceful drain phase
    Given a graceful shutdown is in progress at Phase 3 (drain)
    When I click the "Abort Shutdown" button
    Then a confirmation dialog should appear: "Abort will halt draining immediately"
    When I confirm the abort
    Then the shutdown sequence should stop
    And the system should return to "Running" state
    And all halted services should be restarted
    And a Zenoh event "shutdown_aborted" should be published with the abort phase
    And the abort should be logged to the Immutable Register

  @high @sc_safety_004
  Scenario: Abort is unavailable during Force shutdown
    Given a Force shutdown has been fired and confirmed
    When the Force shutdown begins
    Then the "Abort" button should be disabled
    And a label should say "Cannot abort Force shutdown"

  # ----------------------------------------------------------
  # Guardian Veto
  # ----------------------------------------------------------

  @critical @sc_safety_001 @guardian
  Scenario: Guardian vetoes shutdown — operation cancelled
    Given I have armed a "Graceful" shutdown and clicked "Fire"
    When Guardian rejects the shutdown request with reason "Quorum not met"
    Then the shutdown should be cancelled
    And an alert should appear: "Guardian veto: Quorum not met"
    And the system should remain in Running state
    And the Arm state should reset to unarmed
    And the veto reason should be logged to the audit trail

  # ----------------------------------------------------------
  # Dying Gasp Checkpoint (SC-SIL4-007)
  # ----------------------------------------------------------

  @critical @sc_sil4_007 @checkpoint
  Scenario: Dying gasp checkpoint is created before final stop
    Given a graceful shutdown is in progress
    When Phase 4 (Dying gasp checkpoint) begins
    Then a checkpoint should be written to SQLite and DuckDB
    And the checkpoint ID should be displayed in the progress panel
    And the checkpoint should include current holon state, version vectors, and hash
    And Phase 5 should not begin until the checkpoint write is confirmed

  # ----------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------

  @medium @sc_sil4_013
  Scenario: Shutdown page is read-only for non-operator roles
    Given I am authenticated with role "viewer"
    When I navigate to "/prajna/shutdown"
    Then all shutdown controls should be disabled
    And a banner should appear: "Shutdown requires Operator or Administrator role"
    And no Arm or Fire buttons should be interactive

  @medium @sc_safety_020
  Scenario: System under high load shows warning before shutdown
    Given system CPU usage is above 90%
    When I navigate to the shutdown page
    Then a "High Load Warning" should appear: "System is under heavy load"
    And the warning should recommend waiting for load to drop below 50%
    And shutdown should still be possible with additional confirmation
