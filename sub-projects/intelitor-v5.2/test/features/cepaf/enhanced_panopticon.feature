@cepaf @tui @panopticon @enhanced @P0
Feature: Enhanced F# Panopticon TUI Cockpit
  As a system operator
  I need comprehensive TUI cockpit controls
  So that I can manage the SIL-6 mesh from terminal interface

  Background:
    Given the F# runtime is installed
    And the Panopticon TUI is launched
    And the mesh is in operational state
    And I have operator credentials

  # =============================================================================
  # MESH BOOT SEQUENCE (5-Stage Protocol)
  # =============================================================================

  @mesh @boot @P0 @SC-SIL4-001
  Scenario: TUI-BOOT-001 - Complete 5-stage mesh boot sequence
    Given the mesh is in offline state
    When I execute the "boot" command in TUI
    Then I should see the Preflight stage start
    And the Preflight checks should complete within 30 seconds
    And I should see the Ignition stage start
    And all containers should reach "created" state
    And I should see the Lens stage start
    And instrumentation should be active
    And I should see the Convergence stage start
    And the quorum should be established
    And I should see the Ready stage complete
    And the mesh status should show "OPERATIONAL"

  @mesh @boot @P0 @SC-SIL4-001
  Scenario: TUI-BOOT-002 - Preflight validation failures
    Given the mesh is in offline state
    And the database container is missing
    When I execute the "boot" command in TUI
    Then the Preflight stage should fail
    And I should see error "Container indrajaal-db-prod not found"
    And the boot sequence should abort
    And the mesh status should remain "OFFLINE"

  @mesh @boot @P0 @SC-SIL4-001
  Scenario: TUI-BOOT-003 - Convergence timeout handling
    Given the mesh is in Lens stage
    And one node is unreachable
    When the Convergence stage starts
    Then I should see convergence attempts
    And after 60 seconds timeout I should see "Convergence failed"
    And the mesh should enter "DEGRADED" state
    And I should see recovery options

  @mesh @boot @P0 @SC-SIL4-001
  Scenario: TUI-BOOT-004 - Boot with HA mode enabled
    Given HA mode is configured with 3 app instances
    When I execute the "boot --ha" command in TUI
    Then I should see 3 app containers starting
    And Zenoh quorum should require 2/3 nodes
    And load balancing should be active
    And the mesh status should show "HA-OPERATIONAL"

  # =============================================================================
  # 5 LENS LAYERS VISUALIZATION
  # =============================================================================

  @lens @visualization @P0 @SC-HMI-003
  Scenario: TUI-LENS-001 - Display all 5 lens layers
    Given the mesh is operational
    When I press "L" to open Lens view
    Then I should see 5 lens layers:
      | Layer | Name        | Focus                    |
      | L5    | EVOLUTIONARY | System adaptation         |
      | L4    | COGNITIVE    | Decision making          |
      | L3    | ORGAN        | Subsystem health         |
      | L2    | TISSUE       | Module interactions      |
      | L1    | CELLULAR     | Individual processes     |

  @lens @drill-down @P0 @SC-HMI-003
  Scenario: TUI-LENS-002 - Drill down from Evolutionary to Cellular
    Given I am viewing the EVOLUTIONARY lens layer
    When I select a subsystem and press "Enter"
    Then I should navigate to the COGNITIVE layer
    And when I drill down again I should reach ORGAN
    And further drilling should show TISSUE
    And final drill-down should show CELLULAR details
    And breadcrumb should show "L5 > L4 > L3 > L2 > L1"

  @lens @filter @P1 @SC-HMI-003
  Scenario: TUI-LENS-003 - Filter lens view by health status
    Given I am viewing the ORGAN lens layer
    When I press "F" to open filter menu
    And I select "Unhealthy Only"
    Then only components with health < 0.8 should be visible
    And healthy components should be hidden
    And the filter indicator should show "FILTERED: Unhealthy"

  @lens @metrics @P1 @SC-HMI-003
  Scenario: TUI-LENS-004 - Real-time metrics in lens view
    Given I am viewing the CELLULAR lens layer
    Then each process should show:
      | Metric       | Unit    |
      | CPU          | %       |
      | Memory       | MB      |
      | Message Queue| count   |
      | Reductions   | /sec    |
    And metrics should update every 5 seconds

  @lens @health @P0 @SC-HMI-001
  Scenario: TUI-LENS-005 - Health indicators response time
    Given I am viewing any lens layer
    When a component health changes
    Then the visual indicator should update within 1 second
    And the health score should be color-coded:
      | Score Range | Color   |
      | 0.8-1.0     | Green   |
      | 0.5-0.79    | Yellow  |
      | 0.0-0.49    | Red     |

  # =============================================================================
  # 2oo3 VOTING SYSTEM
  # =============================================================================

  @voting @2oo3 @P0 @SC-SIL4-006
  Scenario: TUI-VOTE-001 - Display 2oo3 voting panel
    Given the mesh is operational in production mode
    When I press "V" to open voting panel
    Then I should see the 2oo3 voting display:
      | Node     | Type    | Status  | Last Vote |
      | PRIMARY  | Live    | HEALTHY | <5s ago   |
      | SHADOW   | Mirror  | HEALTHY | <5s ago   |
      | MODEL    | Formal  | VALID   | <5s ago   |
    And the consensus status should show "UNANIMOUS"

  @voting @consensus @P0 @SC-SIL4-006
  Scenario: TUI-VOTE-002 - Majority consensus with one dissent
    Given the 2oo3 voting panel is open
    And PRIMARY and SHADOW agree on state
    But MODEL shows different formal verification
    Then the consensus status should show "MAJORITY (2/3)"
    And a warning should be displayed
    And the dissenting node should be highlighted

  @voting @byzantine @P0 @SC-SIL4-006
  Scenario: TUI-VOTE-003 - Byzantine fault detection
    Given the 2oo3 voting panel is open
    And PRIMARY shows inconsistent state
    When SHADOW and MODEL agree on different state
    Then a Byzantine fault should be detected
    And PRIMARY should be marked as "SUSPECT"
    And automatic failover should initiate

  @voting @failover @P0 @SC-SIL4-006
  Scenario: TUI-VOTE-004 - Automatic failover on node failure
    Given the 2oo3 voting panel is open
    When PRIMARY node fails
    Then SHADOW should be promoted to PRIMARY
    And the old PRIMARY should be marked "OFFLINE"
    And a new SHADOW should be provisioned
    And voting should continue with 2 nodes temporarily

  # =============================================================================
  # DARK COCKPIT INTERFACE
  # =============================================================================

  @dark-cockpit @theme @P1 @SC-HMI-004
  Scenario: TUI-DARK-001 - Aerospace dark cockpit theme
    Given the TUI is launched
    Then the background should be dark (#1a1a2e or similar)
    And text should use high contrast colors
    And critical alerts should use red (#ff4444)
    And warnings should use amber (#ffaa00)
    And normal status should use green (#44ff44)

  @dark-cockpit @fatigue @P1 @SC-HMI-004
  Scenario: TUI-DARK-002 - Fatigue mitigation features
    Given the operator has been active for 2 hours
    Then a subtle break reminder should appear
    And the screen should not have high-frequency flashing
    And ambient lighting should be consistent
    And text should maintain minimum 4.5:1 contrast ratio

  @dark-cockpit @alarm @P0 @SC-HMI-002
  Scenario: TUI-DARK-003 - Critical alarm flash rate
    Given a critical alarm is triggered
    When the alarm indicator flashes
    Then the flash rate should be between 10-20 Hz
    And the flash should be visible in peripheral vision
    And the alarm should have audio accompaniment option

  # =============================================================================
  # MESH CLI COMMANDS
  # =============================================================================

  @cli @commands @P0 @SC-EMR-057
  Scenario: TUI-CLI-001 - Emergency stop command
    Given the mesh is operational
    When I execute the "emergency-stop" command
    Then the mesh should halt within 5 seconds
    And all containers should be stopped
    And the final state should be checkpointed
    And the mesh status should show "EMERGENCY HALTED"

  @cli @commands @P0 @SC-SIL4-002
  Scenario: TUI-CLI-002 - Graceful shutdown with checkpointing
    Given the mesh is operational
    When I execute the "shutdown" command
    Then the Apoptosis protocol should start
    And state should be checkpointed to UCR
    And containers should drain connections
    And final shutdown should complete gracefully

  @cli @commands @P1
  Scenario: TUI-CLI-003 - Health check command
    Given the mesh is operational
    When I execute the "health" command
    Then FPPS 5-method consensus should run
    And each validator should report:
      | Validator   | Method           |
      | Pattern     | Podman status    |
      | AST         | Health.Status    |
      | Statistical | Exit codes       |
      | Binary      | Running state    |
      | LineByLine  | Log analysis     |
    And the overall health score should be displayed

  @cli @commands @P1
  Scenario: TUI-CLI-004 - Status command output
    Given the mesh is operational
    When I execute the "status" command
    Then I should see container status for all 3 services
    And I should see Zenoh mesh connectivity
    And I should see resource utilization
    And I should see active alarms count

  @cli @commands @P1
  Scenario: TUI-CLI-005 - Logs streaming command
    Given the mesh is operational
    When I execute the "logs -f indrajaal-ex-app-1" command
    Then logs should stream in real-time
    And logs should be color-coded by level
    And pressing "q" should stop streaming

  # =============================================================================
  # KEYBOARD NAVIGATION
  # =============================================================================

  @keyboard @navigation @P1 @accessibility
  Scenario: TUI-KEY-001 - Main navigation keys
    Given the TUI is displayed
    Then the following keys should work:
      | Key | Action                    |
      | L   | Open Lens view            |
      | V   | Open Voting panel         |
      | H   | Open Health dashboard     |
      | A   | Open Alarms view          |
      | S   | Open Status view          |
      | M   | Open Mesh topology        |
      | ?   | Show help                 |
      | q   | Quit/Back                 |
      | Esc | Close current panel       |

  @keyboard @focus @P1 @accessibility
  Scenario: TUI-KEY-002 - Tab navigation between panels
    Given multiple panels are visible
    When I press Tab
    Then focus should move to the next panel
    And the focused panel should have visible border
    And pressing Shift+Tab should move focus backwards

  @keyboard @shortcuts @P1
  Scenario: TUI-KEY-003 - Command shortcuts
    Given the TUI is displayed
    Then the following shortcuts should work:
      | Shortcut | Command              |
      | Ctrl+B   | Boot mesh            |
      | Ctrl+S   | Shutdown mesh        |
      | Ctrl+E   | Emergency stop       |
      | Ctrl+R   | Refresh display      |
      | Ctrl+H   | Health check         |

  # =============================================================================
  # ERROR HANDLING AND RECOVERY
  # =============================================================================

  @error @recovery @P0
  Scenario: TUI-ERR-001 - Connection lost to mesh
    Given the TUI is connected to the mesh
    When the mesh connection is lost
    Then the status should change to "DISCONNECTED"
    And automatic reconnection should attempt every 5 seconds
    And manual reconnect should be available via "R" key
    And data should be marked as "STALE" during disconnection

  @error @recovery @P0
  Scenario: TUI-ERR-002 - Container crash recovery
    Given the TUI shows all containers healthy
    When a container crashes
    Then the container status should update within 10 seconds
    And a recovery prompt should appear
    And selecting "Restart" should restart the container
    And the lens view should update to reflect the crash

  @error @recovery @P1
  Scenario: TUI-ERR-003 - Zenoh mesh partition
    Given the mesh has 3 nodes
    When network partition occurs
    Then the partition should be detected
    And the isolated node should be marked
    And voting should continue with available nodes
    And partition healing should be monitored

  @error @recovery @P1
  Scenario: TUI-ERR-004 - Invalid command handling
    Given the TUI command prompt is active
    When I enter an invalid command "xyz123"
    Then an error message should appear
    And suggestions for similar commands should be shown
    And command history should include the failed attempt

  # =============================================================================
  # SPECTRE.CONSOLE INTEGRATION
  # =============================================================================

  @spectre @rendering @P2
  Scenario: TUI-SPEC-001 - Table rendering
    Given data tables are displayed
    Then tables should use Spectre.Console formatting
    And columns should be properly aligned
    And borders should use Unicode box-drawing characters
    And long text should be properly truncated

  @spectre @progress @P2
  Scenario: TUI-SPEC-002 - Progress bar display
    Given a long-running operation is in progress
    Then a progress bar should be displayed
    And the progress should update smoothly
    And estimated time remaining should be shown
    And the operation can be cancelled with Ctrl+C

  @spectre @tree @P2
  Scenario: TUI-SPEC-003 - Tree view rendering
    Given hierarchical data is displayed
    Then the tree should use Spectre.Console tree rendering
    And nodes should be collapsible/expandable
    And indentation should be consistent
    And icons should indicate node type
