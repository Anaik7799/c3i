@prajna @l5_bdd @diagnostics
Feature: Diagnostics Workflow
  As an operator of the Prajna C3I cockpit
  I want to run health checks, take state dumps, and manage logs
  So that I can diagnose system issues and gather forensic evidence

  # STAMP: SC-DEBUG-001 to SC-DEBUG-010, SC-VER-001 to SC-VER-007, SC-HMI-010
  # STAMP: SC-SMRITI-130, SC-SMRITI-133
  # AOR: AOR-VER-001, AOR-VER-006, AOR-VER-016
  # Layer: L2 (Module), L3 (Domain), L4 (System)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/prajna/diagnostics"
    And the diagnostics LiveView is connected via WebSocket

  # ----------------------------------------------------------
  # Tab Switching
  # ----------------------------------------------------------

  @critical @sc_debug_001 @smoke
  Scenario: Diagnostics page loads with Health tab active by default
    When the diagnostics page loads
    Then the "Health" tab should be active
    And I should see health check panels for all critical services:
      | Service        |
      | Sentinel       |
      | Guardian       |
      | Smriti         |
      | Zenoh Router   |
      | Database       |
      | OTEL Collector |
    And each service should show a green/amber/red status dot
    And the overall system health score should be visible
    And the page should load within 2000ms

  @high @sc_debug_002
  Scenario Outline: Switch between diagnostics tabs
    Given I am on the diagnostics page
    When I click the "<tab_name>" tab
    Then the "<tab_name>" content panel should become active
    And its content should render without error

    Examples:
      | tab_name    |
      | Health      |
      | State Dumps |
      | Logs        |
      | Network     |

  # ----------------------------------------------------------
  # Health Checks
  # ----------------------------------------------------------

  @critical @sc_ver_001 @health
  Scenario: Run on-demand full health check
    Given I am on the "Health" tab
    When I click "Run Full Health Check"
    Then a progress spinner should appear
    And health checks should run for all services within 100ms (SC-VER-004)
    And results should populate with green/amber/red indicators
    And the last-run timestamp should update
    And a Zenoh event "health_check_completed" should be published

  @critical @sc_ver_002 @health
  Scenario: Health check failure halts further operations
    Given a health check reveals "Database" is unreachable
    When the health check completes
    Then the "Database" row should show red "FAILED" status
    And a critical alert banner should appear at the top
    And dependent checks (Smriti, State Dumps) should show "Blocked by DB failure"
    And the overall health score should drop below the threshold
    And a Zenoh event "health_check_failed" should be published to "indrajaal/health"

  @high @sc_ver_003 @health
  Scenario: Individual service health check runs in isolation
    Given I am on the "Health" tab
    When I click the "Run" button on the "Sentinel" row
    Then only the Sentinel health check should run
    And the Sentinel status should update
    And other service statuses should remain unchanged

  @high @sc_ver_004 @health
  Scenario Outline: Health indicator shows correct color per status
    Given the "<service>" service has status "<status>"
    When I view the health check panel
    Then the "<service>" indicator should be "<color>"

    Examples:
      | service     | status    | color  |
      | Sentinel    | healthy   | green  |
      | Guardian    | degraded  | amber  |
      | Database    | failed    | red    |
      | Smriti      | unknown   | gray   |
      | Zenoh Router| healthy   | green  |

  # ----------------------------------------------------------
  # State Dumps
  # ----------------------------------------------------------

  @high @sc_debug_003 @state_dumps
  Scenario: Request a state dump for a running process
    Given I click the "State Dumps" tab
    When I select "Sentinel GenServer" from the process dropdown
    And I click "Request State Dump"
    Then the dump should appear in the results panel within 5 seconds
    And the dump should show the current GenServer state as formatted JSON
    And a download button should be available for the dump

  @high @sc_debug_004 @state_dumps
  Scenario: Schedule a periodic state dump
    Given I am on the "State Dumps" tab
    When I configure a periodic dump:
      | Field           | Value              |
      | Process         | Guardian           |
      | Interval        | Every 5 minutes    |
      | Retention       | Last 10 dumps      |
    And I click "Schedule Dump"
    Then the schedule should be saved
    And a "Scheduled" badge should appear on the Guardian row
    And the first dump should trigger within 5 minutes

  @high @sc_debug_005 @state_dumps
  Scenario: Download a state dump as JSON file
    Given a state dump exists for "Smriti"
    When I click "Download" on the dump entry
    Then a JSON file download should begin
    And the filename should include the timestamp and process name
    And the file content should be valid JSON

  # ----------------------------------------------------------
  # Log Management
  # ----------------------------------------------------------

  @critical @sc_debug_006 @logs
  Scenario: Log viewer shows live log stream with filtering
    Given I click the "Logs" tab
    When the log panel renders
    Then I should see a live log stream
    And I should be able to filter by:
      | Filter Type  |
      | Log level    |
      | Node         |
      | Service      |
      | Time range   |
      | Keyword      |

  @high @sc_debug_007 @logs
  Scenario: Export logs to file
    Given I am on the "Logs" tab
    And I have applied a filter for "level: error" and "last 1 hour"
    When I click "Export Logs"
    Then a download prompt should appear
    And the exported file should be in JSONL format
    And the filename should include the filter parameters and timestamp
    And the file should contain only entries matching the active filters

  @high @sc_debug_008 @logs
  Scenario: Log search highlights matching terms
    Given I am on the "Logs" tab
    When I type "guardian veto" in the keyword search
    Then matching log entries should appear
    And "guardian" and "veto" should be highlighted in the results
    And a count of "N matches" should appear below the search box

  @high @sc_debug_009 @logs
  Scenario: Boost log level for a specific service
    Given I am on the "Logs" tab
    When I select "Sentinel" in the service panel
    And I click "Boost to Debug for 5 minutes"
    Then Sentinel should begin emitting debug-level logs
    And a countdown badge "5:00" should appear next to "Sentinel"
    And after 5 minutes the log level should automatically revert
    And a banner "Sentinel debug boost expired" should appear

  # ----------------------------------------------------------
  # Network Diagnostics
  # ----------------------------------------------------------

  @high @sc_debug_010 @network
  Scenario: Network tab shows Zenoh mesh connectivity matrix
    Given I click the "Network" tab
    When the network panel renders
    Then I should see a connectivity matrix showing latency between all node pairs
    And cells with latency above threshold should be amber/red
    And I should be able to ping any node from the matrix
    And a "Topology Graph" view toggle should be available

  @medium @sc_zenoh_004 @network
  Scenario: Run node-to-node ping from diagnostics
    Given I am on the "Network" tab
    When I select source "indrajaal@seed-1" and target "indrajaal@worker-1"
    And I click "Ping"
    Then the latency result should appear within 5 seconds
    And the result should show round-trip time in milliseconds
    And if latency exceeds 50ms, the result should be highlighted amber

  # ----------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------

  @medium @sc_ver_003
  Scenario: Health check page renders partial results on timeout
    Given one service health check takes longer than 5 seconds
    When the health check runs
    Then completed checks should render immediately as they finish
    And the timed-out service should show "Timeout" in amber
    And other services should not be blocked by the slow check

  @medium @sc_debug_004
  Scenario: State dump request on a crashed process returns error gracefully
    Given the "Sentinel" GenServer has crashed
    When I request a state dump for "Sentinel"
    Then an error message should appear: "Process not available"
    And the rest of the diagnostics interface should remain functional
