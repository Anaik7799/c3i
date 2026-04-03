# Panopticon TUI Comprehensive BDD Feature Suite
# STAMP: SC-HMI-001 to SC-HMI-004, SC-SIL4-001 to SC-SIL4-020, SC-SIL6-001 to SC-SIL6-015
# AOR: AOR-MESH-001 to AOR-MESH-010
# Author: Cybernetic Architect
# Date: 2026-01-10
# Purpose: 100% coverage of Panopticon Directed Telescope TUI with all 5 lens layers

@cepaf @panopticon @tui @sil6 @comprehensive
Feature: Panopticon Directed Telescope - Complete End-to-End Coverage
  As a SIL-6 safety operator
  I want a comprehensive TUI visualization of all system layers
  So that I can monitor the biomorphic mesh with complete situational awareness

  Background:
    Given the F# CEPAF runtime is initialized
    And the Zenoh mesh has quorum (2oo3 minimum)
    And the terminal supports ANSI 256-color mode
    And all 12 HA containers are running
    And the Digital Twin state is synchronized

  # =============================================================================
  # SECTION 1: DIRECTED TELESCOPE LENS LAYERS (L1-L5)
  # =============================================================================

  @P0 @lens @evolutionary @L5
  Scenario: L5 Evolutionary Layer - SRS Compliance Display
    Given I am viewing the Panopticon TUI
    When I focus on the L5 EVOLUTIONARY lens
    Then I should see:
      | Metric               | Expected Format        |
      | SRS Compliance       | Percentage (0-100%)    |
      | Fitness Score        | Decimal (0.0-1.0)      |
      | Generation Count     | Integer                |
      | Mutation Rate        | Percentage             |
      | Selection Pressure   | Decimal                |
    And the compliance indicator should be:
      | Range    | Color  | Status    |
      | 95-100%  | Green  | Nominal   |
      | 80-94%   | Yellow | Warning   |
      | 0-79%    | Red    | Critical  |

  @P0 @lens @evolutionary @L5 @founder
  Scenario: L5 Evolutionary Layer - Founder's Directive Alignment
    Given I am viewing the L5 EVOLUTIONARY lens
    When I check the Founder's Directive panel
    Then I should see the Three Supreme Goals:
      | Goal                   | Priority  | Status    |
      | Symbiotic Survival     | PRIMARY   | Active    |
      | Sentience Pursuit      | SECONDARY | Tracking  |
      | Power Accumulation     | TERTIARY  | Monitoring|
    And the Ω₀ alignment score should be displayed
    And any misalignment should trigger an alert

  @P0 @lens @evolutionary @L5 @lineage
  Scenario: L5 Evolutionary Layer - Lineage Tracking
    Given I am viewing the L5 EVOLUTIONARY lens
    When I expand the lineage panel
    Then I should see:
      | Field              | Description              |
      | Holon ID           | Current holon identifier |
      | Parent Holon       | Ancestor link            |
      | Generation         | Evolutionary depth       |
      | Mutations Applied  | List of changes          |
      | Constitutional     | Ψ₀-Ψ₅ compliance         |
    And the lineage graph should be navigable

  @P0 @lens @cognitive @L4
  Scenario: L4 Cognitive Layer - STPA Hazard Analysis
    Given I am viewing the Panopticon TUI
    When I focus on the L4 COGNITIVE lens
    Then I should see the STPA analysis panels:
      | Panel              | Content                  |
      | Loss Scenarios     | Identified losses        |
      | Hazards            | System-level hazards     |
      | UCAs               | Unsafe Control Actions   |
      | Safety Constraints | Derived constraints      |
    And each hazard should show:
      | Field     | Type        |
      | ID        | HAZ-XXX     |
      | Severity  | 1-10        |
      | Status    | Active/Mitigated |

  @P0 @lens @cognitive @L4 @feedback
  Scenario: L4 Cognitive Layer - Feedback Loop Monitoring
    Given I am viewing the L4 COGNITIVE lens
    When I check the feedback loop panel
    Then I should see active feedback loops:
      | Loop               | Latency    | Status    |
      | Sensor → Decision  | < 10ms     | Active    |
      | Decision → Action  | < 20ms     | Active    |
      | Action → Verify    | < 50ms     | Active    |
      | Verify → Adapt     | < 100ms    | Active    |
    And any delay > threshold should be highlighted

  @P0 @lens @organ @L3
  Scenario: L3 Organ Layer - Istio Service Mesh
    Given I am viewing the Panopticon TUI
    When I focus on the L3 ORGAN lens
    Then I should see Istio mirroring status:
      | Metric              | Expected         |
      | Mirror Percentage   | 100%             |
      | Shadow Traffic      | Active           |
      | Payload Comparison  | Enabled          |
      | Divergence Count    | 0 (nominal)      |
    And traffic distribution should show:
      | Destination | Percentage |
      | Primary     | ~50%       |
      | Shadow      | ~50%       |

  @P0 @lens @organ @L3 @canary
  Scenario: L3 Organ Layer - Canary Deployment Status
    Given I am viewing the L3 ORGAN lens
    When I check canary deployment panel
    Then I should see:
      | Field            | Description            |
      | Canary Version   | Version being tested   |
      | Traffic %        | Percentage to canary   |
      | Error Rate       | Canary error rate      |
      | Latency Delta    | vs baseline            |
      | Rollback Status  | Ready/Triggered        |

  @P0 @lens @tissue @L2
  Scenario: L2 Tissue Layer - Podman Container Isolation
    Given I am viewing the Panopticon TUI
    When I focus on the L2 TISSUE lens
    Then I should see container status for all 12 containers:
      | Container           | CPU    | Memory | Network | Status  |
      | indrajaal-haproxy   | < 10%  | < 512M | Active  | Healthy |
      | indrajaal-ex-app-1  | < 80%  | < 2G   | Active  | Healthy |
      | indrajaal-ex-app-2  | < 80%  | < 2G   | Active  | Healthy |
      | indrajaal-ex-app-3  | < 80%  | < 2G   | Active  | Healthy |
      | indrajaal-db-ha     | < 50%  | < 4G   | Active  | Healthy |
      | indrajaal-obs-ha    | < 30%  | < 2G   | Active  | Healthy |
      | zenoh-ha-1          | < 20%  | < 1G   | Active  | Healthy |
      | zenoh-ha-2          | < 20%  | < 1G   | Active  | Healthy |
      | zenoh-ha-3          | < 20%  | < 1G   | Active  | Healthy |
      | zenoh-ha-proxy      | < 10%  | < 512M | Active  | Healthy |
      | cepaf-bridge-ha     | < 30%  | < 1G   | Active  | Healthy |
      | indrajaal-cortex-ha | < 50%  | < 2G   | Active  | Healthy |

  @P0 @lens @tissue @L2 @isolation
  Scenario: L2 Tissue Layer - Security Isolation Verification
    Given I am viewing the L2 TISSUE lens
    When I check the isolation panel
    Then I should verify:
      | Isolation Type     | Status    |
      | Namespace          | Isolated  |
      | Network            | Isolated  |
      | Filesystem         | Isolated  |
      | Process            | Isolated  |
      | IPC                | Isolated  |
      | User               | Isolated  |
    And any isolation breach should trigger immediate alert

  @P0 @lens @cellular @L1
  Scenario: L1 Cellular Layer - BEAM VM Status
    Given I am viewing the Panopticon TUI
    When I focus on the L1 CELLULAR lens
    Then I should see BEAM VM metrics:
      | Metric              | Threshold    | Status    |
      | Process Count       | < 100,000    | Normal    |
      | Port Count          | < 1,000      | Normal    |
      | Atom Count          | < 1,000,000  | Normal    |
      | Binary Memory       | < 500MB      | Normal    |
      | ETS Tables          | < 1,000      | Normal    |
      | Schedulers Online   | 16/16        | Full      |
      | Run Queue           | < 100        | Normal    |

  @P0 @lens @cellular @L1 @memory
  Scenario: L1 Cellular Layer - Memory Safety Proof
    Given I am viewing the L1 CELLULAR lens
    When I check the memory panel
    Then I should see memory proof results:
      | Check               | Status    |
      | Heap Fragmentation  | < 5%      |
      | Binary Leak Check   | Pass      |
      | Large Heap Procs    | 0         |
      | GC Pressure         | Normal    |
      | Off-Heap Allocation | Bounded   |
    And any memory anomaly should be highlighted

  # =============================================================================
  # SECTION 2: 2oo3 VOTING SYSTEM
  # =============================================================================

  @P0 @voting @2oo3 @consensus
  Scenario: 2oo3 Voting Panel - All Nodes Agree
    Given I am viewing the Panopticon voting panel
    When all three nodes return the same payload
    Then the voting result should show:
      | Node    | Payload | Latency | Verdict |
      | PRIMARY | 0xAF42  | 2ms     | MATCH   |
      | SHADOW  | 0xAF42  | 3ms     | MATCH   |
      | MODEL   | 0xAF42  | 1ms     | MATCH   |
    And the consensus status should be "UNANIMOUS"
    And the decision should be "ACCEPT"

  @P0 @voting @2oo3 @majority
  Scenario: 2oo3 Voting Panel - Primary Node Disagrees
    Given I am viewing the Panopticon voting panel
    When PRIMARY returns different payload than SHADOW and MODEL
    Then the voting result should show:
      | Node    | Payload | Latency | Verdict  |
      | PRIMARY | 0xBF43  | 2ms     | MISMATCH |
      | SHADOW  | 0xAF42  | 3ms     | MATCH    |
      | MODEL   | 0xAF42  | 1ms     | MATCH    |
    And the consensus status should be "MAJORITY (2oo3)"
    And the decision should be "ACCEPT 0xAF42"
    And PRIMARY should be flagged for investigation

  @P0 @voting @2oo3 @byzantine
  Scenario: 2oo3 Voting Panel - Byzantine Fault Detection
    Given I am viewing the Panopticon voting panel
    When all three nodes return different payloads
    Then the voting result should show:
      | Node    | Payload | Latency | Verdict  |
      | PRIMARY | 0xAF42  | 2ms     | MISMATCH |
      | SHADOW  | 0xBF43  | 3ms     | MISMATCH |
      | MODEL   | 0xCF44  | 1ms     | MISMATCH |
    And the consensus status should be "BYZANTINE FAULT"
    And the decision should be "HALT - INVESTIGATE"
    And an emergency alert should be raised

  @P0 @voting @2oo3 @failover
  Scenario: 2oo3 Voting Panel - Node Offline
    Given I am viewing the Panopticon voting panel
    When SHADOW node is offline
    Then the voting result should show:
      | Node    | Payload | Latency | Verdict  |
      | PRIMARY | 0xAF42  | 2ms     | MATCH    |
      | SHADOW  | N/A     | TIMEOUT | OFFLINE  |
      | MODEL   | 0xAF42  | 1ms     | MATCH    |
    And the consensus status should be "DEGRADED (2oo2)"
    And the decision should be "ACCEPT (FAIL-SAFE)"
    And a warning should be displayed

  @P0 @voting @latency
  Scenario: 2oo3 Voting Panel - Latency Warning
    Given I am viewing the Panopticon voting panel
    When SHADOW node has high latency (> 50ms)
    Then the voting result should show:
      | Node    | Payload | Latency | Verdict |
      | PRIMARY | 0xAF42  | 2ms     | MATCH   |
      | SHADOW  | 0xAF42  | 85ms    | SLOW    |
      | MODEL   | 0xAF42  | 1ms     | MATCH   |
    And SHADOW should have amber warning indicator
    And "NETWORK LATENCY WARNING" should be displayed

  # =============================================================================
  # SECTION 3: DARK COCKPIT UI COMPLIANCE
  # =============================================================================

  @P0 @dark_cockpit @colors @SC-HMI-001
  Scenario: Dark Cockpit - Normal State Appearance
    Given I am viewing the Dark Cockpit UI
    When all systems are in normal state
    Then the color palette should follow:
      | Element Type    | Color       | ANSI Code |
      | Normal Status   | Dark Gray   | \e[90m    |
      | Background      | Black       | default   |
      | Headers         | Dim Blue    | \e[34m    |
      | Borders         | Dark Gray   | \e[90m    |
    And the cognitive load should be minimal

  @P0 @dark_cockpit @deviation @SC-HMI-001
  Scenario: Dark Cockpit - Deviation Highlighting
    Given I am viewing the Dark Cockpit UI
    When a system deviation occurs
    Then the deviation should be highlighted:
      | Severity  | Color        | ANSI Code | Animation |
      | Advisory  | Cyan         | \e[36m    | None      |
      | Caution   | Amber/Yellow | \e[33m    | None      |
      | Warning   | Red          | \e[31m    | None      |
      | Critical  | Red          | \e[31;5m  | Blink     |
    And normal items should remain dim

  @P0 @dark_cockpit @trends @SC-HMI-002
  Scenario: Dark Cockpit - Trend Vector Display
    Given I am viewing a metric in Dark Cockpit
    When the metric has historical data
    Then trend arrows should indicate direction:
      | Trend      | Symbol | Color  |
      | Rising     | ↑      | Cyan   |
      | Rising Fast| ↑↑     | Yellow |
      | Stable     | →      | Gray   |
      | Falling    | ↓      | Cyan   |
      | Falling Fast| ↓↓    | Yellow |
    And trends should be based on last 5 samples

  @P0 @dark_cockpit @staleness @SC-HMI-003
  Scenario: Dark Cockpit - Staleness Visual Decay
    Given I am viewing a metric in Dark Cockpit
    When the metric data is older than 30 seconds
    Then the display should indicate staleness:
      | Age        | Appearance       |
      | 0-30s      | Normal color     |
      | 30-60s     | Dimmed + ◐       |
      | 60-120s    | Gray + [STALE]   |
      | > 120s     | Red + [FROZEN]   |
    And stale data should be clearly distinguishable

  @P0 @dark_cockpit @two_step @SC-HMI-004
  Scenario: Dark Cockpit - Two-Step Commit UI
    Given I am executing a critical command
    When I initiate the command
    Then the two-step process should display:
      | Step | State    | Symbol | Action Required    |
      | 1    | Idle     | ○      | Press to arm       |
      | 2    | Armed    | ◎      | Press to confirm   |
      | 3    | Execute  | ●      | In progress        |
      | 4    | Complete | ✓      | Acknowledged       |
    And a 30-second timeout should be enforced
    And Escape should cancel at any point

  @P1 @dark_cockpit @sparklines
  Scenario: Dark Cockpit - Sparkline Mini Charts
    Given I am viewing time-series data
    When the sparkline renders
    Then it should use Unicode block characters:
      | Value Range | Character |
      | 0-12.5%     | ▁         |
      | 12.5-25%    | ▂         |
      | 25-37.5%    | ▃         |
      | 37.5-50%    | ▄         |
      | 50-62.5%    | ▅         |
      | 62.5-75%    | ▆         |
      | 75-87.5%    | ▇         |
      | 87.5-100%   | █         |
    And the sparkline should show last 10 values

  @P1 @dark_cockpit @bars
  Scenario: Dark Cockpit - Progress Bar Display
    Given I am viewing a capacity metric
    When the progress bar renders
    Then it should display proportionally:
      | Fill %  | Bar Appearance           |
      | 100%    | ██████████████████████████|
      | 75%     | ████████████████████░░░░░░|
      | 50%     | █████████████░░░░░░░░░░░░░|
      | 25%     | ██████░░░░░░░░░░░░░░░░░░░░|
      | 0%      | ░░░░░░░░░░░░░░░░░░░░░░░░░░|
    And numeric percentage should accompany bar

  # =============================================================================
  # SECTION 4: MESH CLI COMMANDS
  # =============================================================================

  @P0 @mesh_cli @boot @SC-SIL4-001
  Scenario: Mesh CLI - Boot Sequence (5 Stages)
    Given I execute "dotnet run -- boot"
    Then the boot sequence should complete 5 stages:
      | Stage | Name        | Duration | Verification                |
      | 1     | Preflight   | < 30s    | Dependencies checked        |
      | 2     | Ignition    | < 60s    | Containers started          |
      | 3     | Lens        | < 30s    | Instrumentation active      |
      | 4     | Convergence | < 120s   | Quorum achieved             |
      | 5     | Ready       | < 30s    | OODA loop active            |
    And total boot time should be < 5 minutes
    And final status should be "MESH OPERATIONAL"

  @P0 @mesh_cli @status
  Scenario: Mesh CLI - Status Command
    Given the mesh is running
    When I execute "dotnet run -- status"
    Then I should see status for all components:
      | Component    | Fields                           |
      | Containers   | Name, Status, Ports, Health      |
      | Zenoh Mesh   | Routers, Quorum, Latency         |
      | Database     | Connections, Replication, Size   |
      | HAProxy      | Backends, Active, Distribution   |
      | CEPAF Bridge | Connected, Messages/sec          |
    And unhealthy components should be highlighted

  @P0 @mesh_cli @health @SC-SIL4-005
  Scenario: Mesh CLI - Health Command (FPPS Consensus)
    Given the mesh is running
    When I execute "dotnet run -- health"
    Then FPPS 5-method validation should execute:
      | Method     | Description              | Result  |
      | Pattern    | Regex pattern matching   | Pass    |
      | AST        | Abstract syntax tree     | Pass    |
      | Statistical| Statistical analysis     | Pass    |
      | Binary     | Binary comparison        | Pass    |
      | LineByLine | Line-by-line validation  | Pass    |
    And consensus should require all 5 to agree
    And disagreement should show which method failed

  @P0 @mesh_cli @shutdown @SC-SIL4-002
  Scenario: Mesh CLI - Graceful Shutdown
    Given the mesh is running
    When I execute "dotnet run -- shutdown"
    Then the apoptosis protocol should run:
      | Phase | Name          | Max Duration | Actions                |
      | 1     | Initiated     | 1s           | Set flag, log          |
      | 2     | Notifying     | 5s           | Peer notification      |
      | 3     | Draining      | 30s          | Drain connections      |
      | 4     | Checkpointing | 10s          | Persist state          |
      | 5     | Terminating   | 5s           | Stop processes         |
      | 6     | Terminated    | 1s           | Confirm complete       |
    And state should be checkpointed before termination

  @P0 @mesh_cli @emergency @SC-EMR-057
  Scenario: Mesh CLI - Emergency Stop (< 5 seconds)
    Given the mesh is running
    And a critical failure is detected
    When I execute "dotnet run -- emergency"
    Then all containers should stop within 5 seconds
    And no graceful shutdown should occur
    And emergency state should be logged
    And recovery instructions should be displayed

  @P0 @mesh_cli @verify @SC-SIL4-006
  Scenario: Mesh CLI - 2oo3 Voting Verification
    Given the mesh is running
    When I execute "dotnet run -- verify"
    Then all voting scenarios should be tested:
      | Test | Scenario                    | Expected    |
      | 1    | All nodes agree             | PASS        |
      | 2    | Primary disagrees           | PASS (2oo3) |
      | 3    | Shadow disagrees            | PASS (2oo3) |
      | 4    | Model disagrees             | PASS (2oo3) |
      | 5    | Two nodes disagree          | FAIL        |
      | 6    | All nodes disagree          | BYZANTINE   |
      | 7    | Single node offline         | DEGRADED    |
      | 8    | Two nodes offline           | NO QUORUM   |
    And verification report should be generated

  @P0 @mesh_cli @checkpoint @SC-UCR-001
  Scenario: Mesh CLI - Checkpoint Creation
    Given the mesh is running
    When I execute "dotnet run -- checkpoint --full"
    Then the 4-phase checkpoint should complete:
      | Phase | Content                      | Duration |
      | 1     | Files, KMS, Git              | < 30s    |
      | 2     | Container state (CRIU)       | < 60s    |
      | 3     | Distributed snapshot         | < 30s    |
      | 4     | Verification (46 tests)      | < 60s    |
    And manifest with SHA-256 hashes should be created
    And checkpoint archive should be created

  @P1 @mesh_cli @restore
  Scenario: Mesh CLI - Checkpoint Restore
    Given a valid checkpoint exists
    And the mesh is stopped
    When I execute "dotnet run -- restore --checkpoint <id>"
    Then restoration should proceed:
      | Step | Action                      | Duration |
      | 1    | Verify checkpoint integrity | < 10s    |
      | 2    | Restore file state          | < 30s    |
      | 3    | Restore container state     | < 60s    |
      | 4    | Verify constitutional       | < 10s    |
      | 5    | Resume operations           | < 30s    |
    And system should return to checkpointed state

  @P2 @mesh_cli @clean @SC-SIL4-003
  Scenario: Mesh CLI - Clean (Preserve KMS)
    Given the mesh is stopped
    When I execute "dotnet run -- clean"
    Then cleanup should occur:
      | Action                      | Result     |
      | Remove containers           | Removed    |
      | Remove volumes              | Removed    |
      | Remove networks             | Removed    |
      | Preserve data/kms/          | PRESERVED  |
      | Preserve data/holons/       | PRESERVED  |
    And KMS state should remain intact

  @P2 @mesh_cli @scour
  Scenario: Mesh CLI - Nuclear Clean (Scour)
    Given the mesh is stopped
    And I confirm the destructive action
    When I execute "dotnet run -- scour --confirm"
    Then everything should be removed:
      | Component                   | Result     |
      | Containers                  | Removed    |
      | Volumes                     | Removed    |
      | Networks                    | Removed    |
      | KMS state                   | REMOVED    |
      | Holon state                 | REMOVED    |
      | Build artifacts             | REMOVED    |
    And system should be in pristine state

  # =============================================================================
  # SECTION 5: KEYBOARD NAVIGATION
  # =============================================================================

  @P1 @keyboard @global
  Scenario: Global Keyboard Shortcuts
    Given I am viewing the TUI
    Then these global shortcuts should work:
      | Key   | Action              | Context    |
      | q     | Quit application    | Global     |
      | Q     | Quit application    | Global     |
      | h     | Show help           | Global     |
      | ?     | Show help           | Global     |
      | r     | Refresh display     | Global     |
      | /     | Open search         | Global     |
      | Esc   | Cancel/Close        | Any        |
      | Ctrl-C| Emergency exit      | Global     |

  @P1 @keyboard @navigation
  Scenario: Panel Navigation Shortcuts
    Given I am viewing the TUI
    Then these navigation shortcuts should work:
      | Key   | Action              |
      | Tab   | Next panel          |
      | S-Tab | Previous panel      |
      | 1-5   | Focus lens layer    |
      | v     | Focus voting panel  |
      | s     | Focus status bar    |
      | ↑     | Scroll up           |
      | ↓     | Scroll down         |
      | PgUp  | Page up             |
      | PgDn  | Page down           |

  @P1 @keyboard @commands
  Scenario: Command Mode Shortcuts
    Given I am in command mode
    Then these shortcuts should work:
      | Key    | Action              |
      | c      | Inject chaos        |
      | C      | Inject chaos        |
      | b      | Boot mesh           |
      | x      | Shutdown mesh       |
      | e      | Emergency stop      |
      | k      | Checkpoint          |
      | t      | Run tests           |

  # =============================================================================
  # SECTION 6: ERROR HANDLING & RESILIENCE
  # =============================================================================

  @P0 @error @graceful
  Scenario: Graceful Degradation on Partial Failure
    Given the TUI is displaying mesh status
    When one container becomes unhealthy
    Then the TUI should:
      | Action                              |
      | Highlight the unhealthy container   |
      | Continue showing other containers   |
      | Display degraded status indicator   |
      | Show time since last healthy state  |
    And the TUI should not crash

  @P0 @error @zenoh_loss
  Scenario: Handle Zenoh Mesh Disconnection
    Given the TUI is connected to Zenoh
    When Zenoh connectivity is lost
    Then the TUI should:
      | Action                              |
      | Show "MESH DISCONNECTED" banner     |
      | Display last known state with stale |
      | Attempt automatic reconnection      |
      | Show reconnection countdown         |
    And automatic recovery should occur when mesh is restored

  @P1 @error @terminal_resize
  Scenario: Handle Terminal Resize
    Given the TUI is running
    When the terminal is resized
    Then the TUI should:
      | Action                              |
      | Detect SIGWINCH signal              |
      | Recalculate layout                  |
      | Redraw all panels                   |
      | Preserve current state              |
    And no display corruption should occur

  @P1 @error @memory
  Scenario: Memory Bounds During Extended Operation
    Given the TUI has been running for 24 hours
    When measuring memory usage
    Then memory should remain bounded:
      | Metric               | Threshold |
      | Heap Size            | < 100MB   |
      | Growth Rate          | < 1MB/hr  |
      | GC Frequency         | Normal    |
    And no memory leaks should be detected

  # =============================================================================
  # SECTION 7: TERMINAL COMPATIBILITY
  # =============================================================================

  @P2 @terminal @compatibility
  Scenario: Support Standard Terminal Emulators
    Given different terminal emulators
    Then the TUI should work correctly in:
      | Terminal    | ANSI Support | Unicode Support |
      | xterm       | Full         | Full            |
      | gnome-term  | Full         | Full            |
      | konsole     | Full         | Full            |
      | VSCode      | Full         | Full            |
      | tmux        | Full         | Full            |
      | screen      | Partial      | Full            |
      | Windows Term| Full         | Full            |

  @P2 @terminal @dimensions
  Scenario: Minimum Terminal Dimensions
    Given various terminal sizes
    Then the TUI should handle:
      | Width | Height | Result      |
      | 80    | 24     | Minimum OK  |
      | 120   | 40     | Optimal     |
      | 200   | 60     | Extended    |
      | 60    | 20     | Too small   |
    And below minimum should show warning

  @P2 @terminal @color_modes
  Scenario: Color Mode Support
    Given different color capabilities
    Then the TUI should adapt:
      | Mode          | Colors | Fallback        |
      | True Color    | 16M    | Full palette    |
      | 256 Color     | 256    | Mapped palette  |
      | 16 Color      | 16     | Basic colors    |
      | No Color      | 0      | ASCII only      |
