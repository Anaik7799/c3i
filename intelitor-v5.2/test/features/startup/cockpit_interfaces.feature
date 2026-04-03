@cockpit @interfaces @gui @tui @cli @sil6 @phase6
Feature: Cockpit Interfaces (GUI, TUI, CLI)
  As a system operator
  I want multiple interface options for the Prajna cockpit
  So that I can monitor and control the system in any environment

  Background:
    Given full swarm is running and healthy
    And all cockpit interfaces are available
    And the operator is authenticated

  # ==========================================================================
  # GUI: Desktop Application (Avalonia/Fabulous)
  # ==========================================================================
  @gui @avalonia @desktop
  Scenario: GUI cockpit launches successfully
    Given the desktop environment is available
    When I launch the Prajna GUI cockpit application
    Then the application window should appear within 5 seconds
    And the dashboard should display
      | Panel                | Content                      |
      | System Health        | Overall health score gauge   |
      | Container Status     | 15 container status cards    |
      | Zenoh Mesh           | Topology visualization       |
      | Active Threats       | Sentinel threat list         |
      | Boot Metrics         | Recent boot performance      |
    And the NASA-STD-3000 dark cockpit theme should be applied

  @gui @dashboard
  Scenario: GUI dashboard updates in real-time
    Given the GUI cockpit is running
    When system metrics change
    Then the dashboard should refresh within 1 second
    And gauges should animate smoothly
    And sparkline charts should update incrementally
    And no UI freezes should occur

  @gui @interaction
  Scenario: GUI supports operator interactions
    Given the GUI cockpit is running
    When I navigate to the Guardian approval panel
    And I review a pending proposal
    Then I should be able to approve or reject the proposal
    And the action should be logged to the Immutable Register
    And the UI should reflect the updated state immediately

  # ==========================================================================
  # TUI: Terminal User Interface (ANSI/ASCII)
  # ==========================================================================
  @tui @terminal @fallback
  Scenario: TUI cockpit works in terminal-only environments
    Given no desktop environment is available
    And the terminal supports ANSI escape codes
    When I launch the Prajna TUI cockpit
    Then the terminal interface should render correctly
    And the following panels should be displayed
      | Panel              | Rendering            |
      | Header             | ASCII art banner     |
      | Health Score       | ASCII progress bar   |
      | Container List     | Colored table        |
      | Zenoh Quorum       | 2oo3 indicator       |
      | Threats            | Scrollable list      |
    And the interface should be navigable via keyboard

  @tui @accessibility
  Scenario: TUI works over SSH connection
    Given I am connected to the server via SSH
    And my terminal is 80x24 characters
    When I execute "sa-monitor" to launch the TUI
    Then the interface should adapt to terminal size
    And refresh rate should be optimized for network latency
    And no Unicode rendering issues should occur

  @tui @dark-cockpit
  Scenario: TUI implements dark cockpit philosophy
    Given the TUI cockpit is running
    And all systems are healthy
    Then the display should be predominantly dim/dark
    And only anomalies should use bright colors
      | Condition           | Color         |
      | Normal/Healthy      | Dim green     |
      | Warning             | Yellow        |
      | Critical            | Bright red    |
      | Action required     | Amber flash   |
    And operator attention should be directed to issues

  # ==========================================================================
  # CLI: Command Line Interface
  # ==========================================================================
  @cli @commands
  Scenario: CLI provides comprehensive command coverage
    When I execute "sa-help" or view the devenv commands
    Then the following command categories should be available
      | Category        | Example Commands                    |
      | Mesh Control    | sa-up, sa-down, sa-status           |
      | Swarm Control   | sa-swarm-up, sa-swarm-down          |
      | Health          | sa-health, sa-verify                |
      | Monitoring      | sa-logs, sa-monitor                 |
      | Testing         | sa-test, sa-smoke-all               |
      | Planning        | sa-plan, chaya                      |
      | Checkpoint      | sa-checkpoint, sa-restore           |
      | CEPAF           | cepaf-build, cockpitf               |
    And each command should have --help documentation

  @cli @verbosity
  Scenario: CLI supports verbosity flags across all commands
    Given I am using the CLI interface
    When I execute any sa-* command with verbosity flags
    Then the following flags should be recognized
      | Flag             | Effect                        |
      | --verbosity min  | Minimal output for CI/CD      |
      | --verbosity std  | Standard output (default)     |
      | --verbosity v    | Verbose with details          |
      | --verbosity d    | Debug with full state         |
      | -q               | Shorthand for minimal         |
      | -v               | Shorthand for verbose         |
    And output should adjust accordingly

  @cli @scripting
  Scenario: CLI commands are scriptable and pipeable
    Given I am writing an automation script
    When I execute CLI commands in a pipeline
    Then commands should support standard input/output
    And JSON output should be available with --json flag
    And exit codes should follow conventions
      | Exit Code | Meaning                       |
      | 0         | Success                       |
      | 1         | General error                 |
      | 2         | Invalid arguments             |
      | 3         | Resource not found            |
      | 4         | Permission denied             |
      | 5         | Timeout                       |

  @cli @status
  Scenario: CLI status command provides quick health overview
    When I execute "sa-status"
    Then I should see a summary including
      | Information              | Format                  |
      | Container count          | 14/14 running           |
      | Zenoh quorum             | 3oo3 or 2oo3            |
      | System health            | Percentage score        |
      | Active alerts            | Count and severity      |
      | Uptime                   | Duration since boot     |
    And the output should complete in under 2 seconds

  # ==========================================================================
  # Interface Switching and Integration
  # ==========================================================================
  @integration @switching
  Scenario: Interfaces share consistent state view
    Given the GUI cockpit is running on a desktop
    And the TUI cockpit is running in a terminal
    And CLI commands are being executed
    When I make a change via the GUI (e.g., approve an action)
    Then the TUI should reflect the change within 2 seconds
    And CLI status should show the updated state
    And all interfaces should query the same Digital Twin

  @integration @emergency
  Scenario: TUI serves as emergency fallback interface
    Given the GUI application has crashed
    And network connectivity is limited
    When I launch the TUI cockpit
    Then I should have full operational control
    And emergency stop should be available
    And critical actions should not require GUI
    And all SC-EMR (Emergency) constraints should be satisfiable

  # ==========================================================================
  # Accessibility and Usability
  # ==========================================================================
  @accessibility
  Scenario: Interfaces meet accessibility requirements
    Given an operator with accessibility needs
    When using any cockpit interface
    Then keyboard navigation should be fully supported
    And color should not be the only indicator
    And high-contrast mode should be available
    And screen reader compatibility should be considered (GUI)

  @usability @response-time
  Scenario: All interfaces respond within acceptable latency
    Given any cockpit interface is running
    When the operator performs an action
    Then visual feedback should occur within 100ms
    And action completion should occur within
      | Action Type         | Max Latency |
      | Status refresh      | 500ms       |
      | Container control   | 2s          |
      | Emergency stop      | 5s          |
      | Full boot           | 120s        |
