# CEPAF F# TUI Cockpit - Comprehensive BDD Feature Suite
# STAMP: SC-HMI-001 to SC-HMI-004, SC-MESH-001 to SC-MESH-010, SC-SIL6-001
# AOR: AOR-MESH-001 to AOR-MESH-010
# Author: Cybernetic Architect
# Date: 2026-01-10
# Purpose: 100% end-to-end coverage of F# based TUI GUI and Panopticon cockpit

@cepaf @f# @tui @sil6
Feature: CEPAF F# TUI Cockpit - Panopticon Directed Telescope
  As a SIL-6 safety operator
  I want a terminal-based cockpit following Dark Cockpit philosophy
  So that I can monitor and control the fractal mesh with minimal cognitive load

  Background:
    Given the CEPAF F# runtime is initialized
    And the Zenoh mesh is connected
    And the terminal supports ANSI escape codes
    And all 3 app nodes are healthy
    And the 2oo3 voting quorum is established

  # =============================================================================
  # PANOPTICON TUI - DIRECTED TELESCOPE (5 LENS LAYERS)
  # =============================================================================

  @P0 @panopticon @telescope
  Scenario: Panopticon TUI displays all 5 lens layers
    Given I launch the PanopticonTui
    When the TUI renders the initial view
    Then I should see the header "PANOPTICON :: DIRECTED TELESCOPE :: SIL4 PARALLEL CONTROL PLANE"
    And I should see "TELESCOPE LENS ALIGNMENT" section
    And I should see all 5 zoom levels:
      | Level | Name        | Focus                              |
      | L5    | EVOLUTIONARY | SRS compliance, Fitness metrics   |
      | L4    | COGNITIVE    | STPA scanning, Hazard feedback    |
      | L3    | ORGAN        | Istio Mirroring, Payload compare  |
      | L2    | TISSUE       | Podman Isolation, Sensor noise    |
      | L1    | CELLULAR     | BEAM Process Safety, Memory proof |

  @P0 @panopticon @voting
  Scenario: Display 2oo3 voting panel with consensus state
    Given I am viewing the Panopticon TUI
    When I look at the voting section
    Then I should see "SIL4 2oo3 VOTING LOGIC [THE JUDGE]" header
    And I should see voter nodes:
      | Node     | Role    |
      | PRIMARY  | Live    |
      | SHADOW   | Shadow  |
      | MODEL    | Formal  |
    And each node should display:
      | Field   | Type     |
      | Name    | String   |
      | Payload | Hex      |
      | Latency | Integer  |
      | Status  | MATCH/MISMATCH |
    And matching payloads should show green "MATCH"
    And mismatched payloads should show red "MISMATCH"

  @P0 @panopticon @zoom
  Scenario Outline: Zoom level navigation with keyboard
    Given I am viewing the Panopticon TUI
    When I press key "<key>"
    Then the zoom level should change to L<level>
    And the lens details for L<level> should expand
    And other levels should collapse to summary view

    Examples:
      | key | level |
      | 1   | 1     |
      | 2   | 2     |
      | 3   | 3     |
      | 4   | 4     |
      | 5   | 5     |

  @P1 @panopticon @chaos
  Scenario: Inject deterministic chaos vector
    Given I am viewing the Panopticon TUI
    When I press key "C" for chaos injection
    Then I should see "INJECTING MODEL-CHECKED CHAOS VECTOR: BYZANTINE_FAULT_01"
    And the system should enter controlled chaos mode
    And the voting panel should show divergence detection
    And automatic recovery should be triggered

  @P1 @panopticon @ooda
  Scenario: Display OODA cycle status
    Given I am viewing the Panopticon TUI
    When I check the system status line
    Then I should see "SYSTEM STATE: STEADY" or current state
    And I should see "OODA: <50ms" latency indicator
    And I should see "TRANSACTION: ACID" compliance status

  # =============================================================================
  # DARK COCKPIT UI - NASA-STD-3000 & NUREG-0700 COMPLIANCE
  # =============================================================================

  @P0 @dark_cockpit @hmi @SC-HMI-001
  Scenario: Dark Cockpit philosophy - normal state is dim
    Given I launch the DarkCockpitUI
    When all systems are in normal state
    Then the display should use dark gray (ANSI 90) for normal elements
    And only deviations should use bright colors:
      | Severity  | Color        | ANSI Code |
      | Normal    | Dark Gray    | 90        |
      | Advisory  | Cyan         | 36        |
      | Caution   | Amber/Yellow | 33        |
      | Warning   | Red          | 31        |
      | Critical  | Red + Blink  | 31;5      |
    And cognitive load should be minimized

  @P0 @dark_cockpit @trend @SC-HMI-002
  Scenario: Trend vectors displayed for situational awareness
    Given I am viewing the DarkCockpitUI
    When metrics are displayed
    Then each metric should show trend arrow:
      | Icon | Meaning       |
      | ↑    | Rising        |
      | ↑↑   | Rising Fast   |
      | ↓    | Falling       |
      | ↓↓   | Falling Fast  |
      | →    | Stable        |
    And trend arrows should be based on historical comparison

  @P0 @dark_cockpit @staleness @SC-HMI-003
  Scenario: Staleness visual decay for frozen data detection
    Given I am viewing the DarkCockpitUI
    And a metric has timestamp older than 30 seconds
    When the display refreshes
    Then the stale metric should:
      | Property    | Value        |
      | Color       | Gray (90)    |
      | Icon        | ◐ (half)     |
      | Label       | [STALE]      |
    And fresh metrics should show green connected indicator ●

  @P0 @dark_cockpit @two_step @SC-HMI-004
  Scenario: Two-step commit for critical commands
    Given I am viewing the DarkCockpitUI
    And I want to execute a critical command
    When I initiate the command
    Then I should see the command state change to "ARMED" (◎)
    And a confirmation prompt should appear
    And I should see a countdown timer (30 seconds)
    And pressing Enter should confirm execution (●)
    And pressing Escape should cancel (○)

  @P1 @dark_cockpit @progress
  Scenario: Progress bars use analog visualization
    Given I am viewing the DarkCockpitUI
    When displaying capacity or progress metrics
    Then bar charts should use Unicode blocks:
      | Fill Level | Characters        |
      | Full       | █████████████████ |
      | Mid        | ████████▓░░░░░░░░ |
      | Low        | ██░░░░░░░░░░░░░░░ |
      | Empty      | ················· |
    And numeric values should accompany visual bars

  @P1 @dark_cockpit @sparkline
  Scenario: Sparkline mini-charts for trend history
    Given I am viewing the DarkCockpitUI
    When time-series data is displayed
    Then sparklines should show recent history using:
      | Level | Character |
      | 0     | ▁         |
      | 1     | ▂         |
      | 2     | ▃         |
      | 3     | ▄         |
      | 4     | ▅         |
      | 5     | ▆         |
      | 6     | ▇         |
      | 7     | █         |
    And sparkline should represent last 10 values

  # =============================================================================
  # CEPAF SIL4 MESH CLI - UNIFIED ENTRY POINT
  # =============================================================================

  @P0 @mesh_cli @boot
  Scenario: SIL4MeshCLI boot command starts mesh
    Given the mesh containers are stopped
    When I execute "dotnet run -- boot" in CEPAF
    Then the boot sequence should follow 5 stages:
      | Stage | Name         | Description                   |
      | 1     | Preflight    | Dependency verification       |
      | 2     | Ignition     | Container start               |
      | 3     | Lens         | Instrumentation activation    |
      | 4     | Convergence  | Quorum achievement            |
      | 5     | Ready        | OODA loop active              |
    And each stage should display progress
    And the final status should be "MESH OPERATIONAL"

  @P0 @mesh_cli @status
  Scenario: SIL4MeshCLI status shows mesh health
    Given the mesh is running
    When I execute "dotnet run -- status"
    Then I should see container health for:
      | Container          | Port | Expected Status |
      | indrajaal-app-1    | 4000 | healthy         |
      | indrajaal-app-2    | 4000 | healthy         |
      | indrajaal-app-3    | 4000 | healthy         |
      | indrajaal-db-ha    | 5433 | healthy         |
      | indrajaal-haproxy  | 4000 | healthy         |
      | zenoh-ha-1         | 7447 | healthy         |
      | zenoh-ha-2         | 7448 | healthy         |
      | zenoh-ha-3         | 7449 | healthy         |
    And quorum status should be displayed
    And OODA cycle timing should be shown

  @P0 @mesh_cli @health @SC-SIL4-005
  Scenario: Health command uses FPPS 5-method consensus
    Given the mesh is running
    When I execute "dotnet run -- health"
    Then FPPS validation should run with 5 methods:
      | Method      | Description              |
      | Pattern     | Regex pattern matching   |
      | AST         | Abstract syntax tree     |
      | Statistical | Statistical analysis     |
      | Binary      | Binary comparison        |
      | LineByLine  | Line-by-line validation  |
    And all 5 methods must agree for "healthy" status
    And disagreement should trigger "EMERGENCY" state

  @P0 @mesh_cli @shutdown @SC-SIL4-002
  Scenario: Shutdown checkpoints state before termination
    Given the mesh is running
    When I execute "dotnet run -- shutdown"
    Then the apoptosis protocol should initiate with 6 phases:
      | Phase | Name           | Description              |
      | 1     | Initiated      | Shutdown requested       |
      | 2     | Notifying      | Peer notification        |
      | 3     | Draining       | Connection drain         |
      | 4     | Checkpointing  | State persistence        |
      | 5     | Terminating    | Process termination      |
      | 6     | Terminated     | Complete                 |
    And holon state should be checkpointed to SQLite/DuckDB
    And the mesh should stop gracefully

  @P1 @mesh_cli @verify @SC-SIL4-006
  Scenario: Verify command runs 2oo3 voting verification
    Given the mesh is running
    When I execute "dotnet run -- verify"
    Then 2oo3 voting should be tested:
      | Test | Description                |
      | 1    | All nodes agree           |
      | 2    | Primary + Shadow agree    |
      | 3    | Shadow + Model agree      |
      | 4    | Primary + Model agree     |
      | 5    | Single node failure       |
    And majority consensus should be verified
    And verification results should be logged

  @P2 @mesh_cli @clean @SC-SIL4-003
  Scenario: Clean preserves KMS data directory
    Given the mesh is stopped
    When I execute "dotnet run -- clean"
    Then all containers should be removed
    And all volumes should be removed except:
      | Preserved | Path              |
      | KMS State | data/kms/         |
    And the data/kms/ directory should remain intact

  @P2 @mesh_cli @emergency @SC-EMR-057
  Scenario: Emergency stop completes in under 5 seconds
    Given the mesh is running
    When I execute "dotnet run -- emergency"
    Then all containers should stop immediately
    And the stop should complete within 5 seconds
    And no graceful shutdown should occur
    And emergency state should be logged

  # =============================================================================
  # HEALTH COORDINATOR - QUORUM VOTING
  # =============================================================================

  @P0 @health @quorum @SC-SIL4-011
  Scenario: HealthCoordinator calculates quorum correctly
    Given N nodes in the cluster where N >= 3
    When calculating quorum requirement
    Then quorum should equal floor(N/2) + 1
    And examples:
      | N | Quorum |
      | 3 | 2      |
      | 5 | 3      |
      | 7 | 4      |

  @P0 @health @consensus
  Scenario: Health consensus requires all FPPS methods
    Given the HealthCoordinator is running
    When health check is triggered
    Then all 5 FPPS methods should be executed
    And results should be aggregated
    And consensus should be:
      | Agreement | Result    |
      | 5/5       | Healthy   |
      | 4/5       | Degraded  |
      | 3/5       | Warning   |
      | <3/5      | Critical  |

  # =============================================================================
  # PANOPTICON ORCHESTRATOR - BOOT STAGES
  # =============================================================================

  @P0 @orchestrator @preflight
  Scenario: Preflight verification checks dependencies
    Given I start the boot sequence
    When the Preflight stage runs
    Then the following should be verified:
      | Dependency   | Check                    |
      | Podman       | Installed and running    |
      | .NET 10      | SDK available            |
      | Ports        | 4000, 5433, 7447 free    |
      | Volumes      | Can be mounted           |
      | Network      | Podman network exists    |
    And all checks must pass before Ignition

  @P0 @orchestrator @convergence
  Scenario: Convergence waits for quorum achievement
    Given containers are started
    When the Convergence stage runs
    Then the orchestrator should:
      | Step | Action                      |
      | 1    | Poll container health       |
      | 2    | Wait for all healthy        |
      | 3    | Verify Zenoh mesh connected |
      | 4    | Confirm 2oo3 quorum         |
      | 5    | Mark stage complete         |
    And timeout should be 300 seconds maximum

  # =============================================================================
  # APOPTOSIS PROTOCOL - CONTROLLED SHUTDOWN
  # =============================================================================

  @P0 @apoptosis @protocol @SC-SIL4-015
  Scenario: Apoptosis follows 6-phase protocol
    Given the mesh is running
    When shutdown is initiated
    Then the 6 phases should execute in order:
      | Phase | Duration | Actions                    |
      | 1     | < 1s     | Log initiation, set flag   |
      | 2     | < 5s     | Notify peer holons         |
      | 3     | < 30s    | Drain active connections   |
      | 4     | < 10s    | Checkpoint all state       |
      | 5     | < 5s     | Terminate processes        |
      | 6     | < 1s     | Confirm terminated         |
    And total duration should be < 60 seconds

  @P1 @apoptosis @checkpoint
  Scenario: Apoptosis checkpoints to Immutable Register
    Given shutdown is in Checkpointing phase
    When checkpoint runs
    Then the following should be persisted:
      | State Type    | Storage   |
      | Holon State   | SQLite    |
      | Evolution Log | DuckDB    |
      | Block Chain   | Register  |
    And checkpoint should be Ed25519 signed
    And SHA-256 integrity hash should be computed

  # =============================================================================
  # FEDERATION PROTOCOL - CROSS-HOLON COMMUNICATION
  # =============================================================================

  @P1 @federation @version @SC-SIL4-020
  Scenario: Federation version negotiation
    Given two holons want to communicate
    When federation handshake occurs
    Then version negotiation should:
      | Step | Action                       |
      | 1    | Exchange protocol versions   |
      | 2    | Select highest common        |
      | 3    | Agree on cipher suite        |
      | 4    | Establish secure channel     |
    And incompatible versions should fail gracefully

  @P2 @federation @attestation
  Scenario: Hourly integrity attestation
    Given holons are federated
    When the attestation timer fires (hourly)
    Then peer holon integrity should be verified
    And Merkle root should be exchanged
    And chain integrity should be cross-validated

  # =============================================================================
  # DIGITAL TWIN - AUTHORITATIVE STATE
  # =============================================================================

  @P0 @digital_twin @state @SC-MESH-006
  Scenario: DigitalTwin is authoritative mesh state
    Given the mesh is running
    When querying system state
    Then DigitalTwin should be the source of truth
    And all other caches should be derived
    And state queries should read from DigitalTwin

  @P1 @digital_twin @sync
  Scenario: DigitalTwin syncs within 30 seconds
    Given a state change occurs
    When 30 seconds elapse
    Then DigitalTwin should reflect the change
    And sync latency should be < 30 seconds
    And stale data should be detected

  # =============================================================================
  # KEYBOARD NAVIGATION - TUI INTERACTIONS
  # =============================================================================

  @P1 @keyboard @navigation
  Scenario: TUI keyboard shortcuts
    Given I am viewing the TUI
    Then the following shortcuts should work:
      | Key | Action                    |
      | q   | Quit application          |
      | Q   | Quit application          |
      | 1-5 | Select zoom level         |
      | c   | Inject chaos vector       |
      | C   | Inject chaos vector       |
      | h   | Show help                 |
      | r   | Refresh display           |
      | /   | Search                    |
      | Esc | Cancel current operation  |

  @P1 @keyboard @modal
  Scenario: Modal dialog navigation
    Given a confirmation dialog is displayed
    Then the following should work:
      | Key    | Action         |
      | Enter  | Confirm        |
      | y      | Confirm        |
      | Y      | Confirm        |
      | Escape | Cancel         |
      | n      | Cancel         |
      | N      | Cancel         |
      | Tab    | Next field     |

  # =============================================================================
  # ERROR HANDLING - GRACEFUL DEGRADATION
  # =============================================================================

  @P0 @error @degradation
  Scenario: Graceful degradation on partial failure
    Given the mesh has 3 nodes
    When 1 node fails
    Then the TUI should:
      | Action                              |
      | Show warning indicator for node     |
      | Continue operating with 2 nodes     |
      | Display degraded status             |
      | Maintain read operations            |
    And write operations should require quorum

  @P1 @error @recovery
  Scenario: Automatic recovery after failure
    Given a node was previously failed
    When the node recovers
    Then the TUI should:
      | Action                            |
      | Detect node recovery              |
      | Remove warning indicator          |
      | Verify quorum is restored         |
      | Resume full operation             |
    And recovery should be logged

  # =============================================================================
  # ACCESSIBILITY - TERMINAL COMPATIBILITY
  # =============================================================================

  @P2 @accessibility @terminal
  Scenario: Compatible with standard terminals
    Given different terminal emulators
    When running the TUI
    Then it should work with:
      | Terminal     | Features                |
      | xterm        | Full ANSI support       |
      | gnome-term   | Full ANSI support       |
      | konsole      | Full ANSI support       |
      | VSCode       | Full ANSI support       |
      | tmux         | With 256-color support  |
      | screen       | With 256-color support  |

  @P2 @accessibility @width
  Scenario: Responsive to terminal width
    Given the terminal width changes
    When the TUI refreshes
    Then the display should adapt to available width
    And minimum width should be 80 columns
    And optimal width should be 120 columns

  # =============================================================================
  # PERFORMANCE - REFRESH RATES
  # =============================================================================

  @P1 @performance @refresh
  Scenario: TUI refresh rate meets requirements
    Given the TUI is running
    When measuring refresh performance
    Then refresh interval should be configurable:
      | Mode   | Interval |
      | Fast   | 1 second |
      | Normal | 2 seconds |
      | Slow   | 5 seconds |
    And refresh should not cause flickering
    And CPU usage should be < 5%

  @P1 @performance @memory
  Scenario: Memory usage stays bounded
    Given the TUI runs for extended period
    When measuring memory usage
    Then memory should not grow unboundedly
    And memory usage should be < 100MB
    And no memory leaks should occur
