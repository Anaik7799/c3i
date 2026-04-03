@prajna @l5_bdd @alarms
Feature: Alarm Management
  As an operator of the Prajna C3I cockpit
  I want to view, filter, acknowledge, and escalate alarms
  So that I can respond to security and system events with full situational awareness

  # STAMP: SC-ALARM-001 to SC-ALARM-010, SC-HMI-010, SC-HMI-011
  # AOR: AOR-CTX-001, AOR-VER-001
  # Layer: L3 (Domain), L4 (System)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/prajna/alarms"
    And the alarms LiveView is connected via WebSocket
    And Guardian service is active

  # ----------------------------------------------------------
  # Happy Path: Alarm List Display
  # ----------------------------------------------------------

  @critical @sc_alarm_001 @smoke
  Scenario: Alarm list renders with chromatic severity indicators
    Given there are active alarms in the system
    When the alarms page loads
    Then I should see the alarm list table
    And each alarm row should have a severity badge with color:
      | Severity | Color           |
      | critical | Red (#FF0000)   |
      | high     | Orange (#FF6B00)|
      | medium   | Amber (#FFC107) |
      | low      | Teal (#00BCD4)  |
    And the total alarm count should be visible in the header
    And the page should load within 2000ms

  @critical @sc_alarm_002
  Scenario: Alarm list auto-refreshes every 10 seconds
    Given I am viewing the alarms page
    And there are 5 active alarms
    When 10 seconds elapse
    Then the alarm list should refresh automatically
    And new alarms from the last 10 seconds should appear
    And the "Last updated" timestamp should advance
    And the refresh indicator should pulse during update

  # ----------------------------------------------------------
  # Filtering
  # ----------------------------------------------------------

  @high @sc_alarm_003
  Scenario Outline: Filter alarms by severity
    Given there are alarms of mixed severities
    When I select severity filter "<severity>"
    Then only alarms with severity "<severity>" should be displayed
    And the filter badge should show "<severity>" as active
    And the alarm count should update to reflect the filter

    Examples:
      | severity |
      | critical |
      | high     |
      | medium   |
      | low      |

  @high @sc_alarm_004
  Scenario: Filter alarms by time range
    Given there are alarms spanning the last 24 hours
    When I set the time range filter to "Last 1 hour"
    Then only alarms from the past hour should be displayed
    And the time range selector should show "Last 1 hour" as active
    And a timestamp range should appear below the filter

  @high @sc_alarm_005
  Scenario: Search alarms by keyword
    Given there are alarms with various messages
    When I type "authentication" in the alarm search box
    Then only alarms containing "authentication" in their message should appear
    And the matching keyword should be highlighted in the results
    And the count should reflect the filtered set

  # ----------------------------------------------------------
  # Acknowledgement
  # ----------------------------------------------------------

  @critical @sc_alarm_006 @sc_safety_001
  Scenario: Acknowledge a single alarm
    Given there is an unacknowledged alarm with id "ALM-001"
    When I click the "Acknowledge" button on alarm "ALM-001"
    Then a confirmation dialog should appear
    And I should see the alarm ID and severity in the dialog
    When I confirm acknowledgement
    Then the alarm status should change to "acknowledged"
    And the alarm row color should shift to indicate acknowledged state
    And a telemetry event "alarm_acknowledged" should be emitted to Zenoh
    And the action should be logged to the Immutable Register

  @critical @sc_alarm_007
  Scenario: Bulk acknowledge filtered alarms
    Given there are 8 unacknowledged high-severity alarms
    When I apply the "high" severity filter
    And I click "Acknowledge All Filtered"
    Then a bulk confirmation dialog should appear showing "8 alarms"
    When I confirm the bulk acknowledgement
    Then all 8 alarms should transition to "acknowledged"
    And a bulk audit entry should be written to the Immutable Register

  # ----------------------------------------------------------
  # Escalation
  # ----------------------------------------------------------

  @critical @sc_alarm_008 @sc_safety_001
  Scenario: Escalate a critical alarm to Guardian
    Given there is a critical unacknowledged alarm "ALM-CRIT-001"
    When I click "Escalate" on alarm "ALM-CRIT-001"
    Then the escalation form should appear with alarm context pre-filled
    And I should be able to add an escalation note
    When I submit the escalation
    Then Guardian should receive the escalation request
    And the alarm status should change to "escalated"
    And a Zenoh event "alarm_escalated" should be published to "indrajaal/alarms/escalated"
    And the escalation should appear in the Guardian queue

  @high @sc_alarm_009
  Scenario: Escalation is blocked for already-acknowledged alarms
    Given alarm "ALM-002" has status "acknowledged"
    When I attempt to escalate alarm "ALM-002"
    Then the escalation button should be disabled
    And a tooltip should explain "Alarm already acknowledged"

  # ----------------------------------------------------------
  # Storm Detection
  # ----------------------------------------------------------

  @critical @sc_alarm_010 @storm
  Scenario: Alarm storm detection triggers visual warning
    Given the system is receiving alarms at normal rate
    When more than 50 alarms arrive within 60 seconds
    Then a "Storm Alert" banner should appear at the top of the alarm page
    And the banner color should be deep red with pulsing animation
    And the storm rate metric should show "50+ alarms/minute"
    And a Zenoh event "alarm_storm_detected" should be published
    And automatic storm suppression rules should activate

  @high @sc_alarm_011 @storm
  Scenario: Storm subsides and banner clears automatically
    Given an alarm storm banner is currently active
    When the alarm rate drops below 10 per minute for 2 consecutive minutes
    Then the storm banner should automatically dismiss
    And the "Storm resolved" notification should appear for 5 seconds
    And a Zenoh event "alarm_storm_cleared" should be published

  # ----------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------

  @medium @sc_alarm_012
  Scenario: Empty alarm list shows informational state
    Given there are no active alarms
    When I view the alarms page
    Then I should see an "All Clear" message with a green indicator
    And the alarm count should show "0 active alarms"
    And no table rows should be present

  @medium @sc_alarm_013
  Scenario: Alarm with missing source data renders gracefully
    Given there is an alarm with no source_node field
    When the alarm list renders
    Then the alarm should appear with "Unknown source" in the source column
    And no error or crash should occur in the LiveView
