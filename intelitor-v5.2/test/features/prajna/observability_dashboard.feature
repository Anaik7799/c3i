@prajna @l5_bdd @observability
Feature: Observability Dashboard
  As an operator of the Prajna C3I cockpit
  I want to view live metrics, switch observability tabs, and explore distributed traces
  So that I can diagnose system health and performance with full telemetry visibility

  # STAMP: SC-HMI-010, SC-HMI-011, SC-DEBUG-001 to SC-DEBUG-010, SC-VDP-001 to SC-VDP-010
  # AOR: AOR-VER-019, AOR-VER-035
  # Layer: L3 (Domain), L4 (System)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/prajna/observability"
    And the observability LiveView is connected via WebSocket
    And OpenTelemetry traces are flowing (SC-VER-035)

  # ----------------------------------------------------------
  # Tab Switching
  # ----------------------------------------------------------

  @critical @sc_vdp_001 @smoke
  Scenario: Observability page loads with Metrics tab active by default
    When the observability dashboard loads
    Then the "Metrics" tab should be active and highlighted
    And metric cards should be visible for:
      | Metric Name              |
      | CPU Utilization          |
      | Memory Usage             |
      | OODA Cycle Latency       |
      | Zenoh Message Rate       |
      | Request Throughput       |
      | Error Rate               |
    And each card should show a current value and a sparkline graph
    And the page should load within 2000ms

  @high @sc_vdp_002
  Scenario Outline: Switch between observability tabs
    Given I am on the observability dashboard
    When I click the "<tab_name>" tab
    Then the "<tab_name>" content panel should become visible
    And the "<tab_name>" tab should be highlighted as active
    And all other tabs should be inactive
    And the URL should update to include the tab anchor "#<tab_anchor>"

    Examples:
      | tab_name  | tab_anchor |
      | Metrics   | metrics    |
      | Traces    | traces     |
      | Logs      | logs       |
      | SigNoz    | signoz     |

  # ----------------------------------------------------------
  # Metric Card Refresh
  # ----------------------------------------------------------

  @critical @sc_vdp_003
  Scenario: Metric cards refresh with live Zenoh telemetry
    Given the "Metrics" tab is active
    And the current CPU utilization metric value is captured as "V0"
    When 10 seconds elapse
    Then the CPU utilization card value should update
    And if utilization changed by more than 5%, the card border should pulse
    And the "Last updated" indicator on each card should advance
    And the sparkline should append the new data point

  @critical @sc_vdp_004 @sc_hmi_010
  Scenario: Metric card color changes with threshold breach
    Given the "Metrics" tab is active
    When the CPU utilization rises above 80%
    Then the CPU utilization card background should transition to amber
    When it rises above 95%
    Then the background should transition to red
    And a warning badge should appear on the card
    And a Zenoh event should be published to "indrajaal/metrics/threshold_breach"

  @high @sc_vdp_005
  Scenario: Metric card click opens detail drill-down
    Given the "Metrics" tab is active
    When I click on the "OODA Cycle Latency" metric card
    Then a detail panel should slide in from the right
    And it should show a full time-series chart for the last hour
    And I should see min, max, and p99 statistics
    And I should be able to set a custom time range on the chart

  # ----------------------------------------------------------
  # Trace Exploration
  # ----------------------------------------------------------

  @high @sc_debug_001 @traces
  Scenario: Traces tab shows recent distributed traces
    Given I click the "Traces" tab
    When the trace list renders
    Then I should see a list of recent traces with:
      | Column       |
      | Trace ID     |
      | Service Name |
      | Operation    |
      | Duration     |
      | Status       |
      | Timestamp    |
    And traces should be sorted by timestamp descending
    And error traces should be highlighted in red

  @high @sc_debug_002 @traces
  Scenario: Filter traces by service name
    Given I am on the "Traces" tab
    When I type "indrajaal-sentinel" in the service filter
    Then only traces from "indrajaal-sentinel" should appear
    And the trace count should update

  @high @sc_debug_003 @traces
  Scenario: Expand a trace to show span waterfall
    Given there is a trace with id "TRACE-001" visible
    When I click on trace "TRACE-001"
    Then a span waterfall diagram should appear below
    And each span should show service name, duration bar, and status
    And clicking a span should show its attributes and events
    And the total trace duration should be shown at the top

  # ----------------------------------------------------------
  # SigNoz Integration
  # ----------------------------------------------------------

  @high @sc_debug_004 @signoz
  Scenario: SigNoz tab embeds the SigNoz dashboard
    Given I click the "SigNoz" tab
    When the SigNoz panel renders
    Then an embedded iframe or SigNoz link should be visible
    And the SigNoz service health indicator should show "Connected"
    And a "Open in SigNoz" button should be available for full-screen view

  @medium @sc_debug_005 @signoz
  Scenario: SigNoz unavailable shows degraded state gracefully
    Given the SigNoz service is unreachable
    When I click the "SigNoz" tab
    Then a "SigNoz Unavailable" message should appear
    And a retry button should be visible
    And the tab indicator should show a warning icon
    And other observability tabs should remain fully functional

  # ----------------------------------------------------------
  # Log Viewer
  # ----------------------------------------------------------

  @high @sc_debug_006 @logs
  Scenario: Log viewer shows structured log stream
    Given I click the "Logs" tab
    When the log panel renders
    Then I should see a live-scrolling log stream
    And each log entry should show level, timestamp, message, and node
    And log levels should have color coding:
      | Level   | Color  |
      | error   | Red    |
      | warning | Amber  |
      | info    | White  |
      | debug   | Gray   |

  @high @sc_debug_007 @logs
  Scenario: Pause and resume log stream
    Given I am viewing the live log stream
    When I click the "Pause" button
    Then the log stream should freeze
    And I should be able to scroll through historical entries
    When I click "Resume"
    Then the stream should resume from the latest entry
    And entries missed during pause should be retrievable via time filter

  # ----------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------

  @medium @sc_vdp_006
  Scenario: Observability dashboard recovers from WebSocket disconnect
    Given the observability dashboard is active
    When the WebSocket connection drops
    Then a "Reconnecting..." banner should appear
    And metric cards should show stale data with a "Stale" indicator
    When the WebSocket reconnects within 30 seconds
    Then the "Reconnecting..." banner should disappear
    And all metric cards should resume live updates
