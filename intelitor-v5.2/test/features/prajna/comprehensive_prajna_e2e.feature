@prajna @e2e @comprehensive @P0
Feature: Comprehensive Prajna C3I End-to-End Workflows
  As a system operator
  I need complete end-to-end workflows in Prajna
  So that I can manage the full system lifecycle through the cockpit

  Background:
    Given Phoenix is running on port 4000
    And I am authenticated as an "operator"
    And WebSocket connection is established
    And Zenoh mesh telemetry is active

  # =============================================================================
  # MAIN DASHBOARD E2E FLOWS
  # =============================================================================

  @dashboard @health @P0 @SC-PRAJNA-004
  Scenario: E2E-DASH-001 - Complete health dashboard workflow
    When I navigate to "/prajna"
    Then the page should load within 2 seconds
    And the health score should be displayed (0.0-1.0)
    And the following panels should be visible:
      | Panel           | Purpose                    |
      | Health Score    | Overall system health      |
      | Active Threats  | Current security threats   |
      | Agent Status    | 50-agent swarm status      |
      | Zenoh Mesh      | Pub/sub connectivity       |
      | Recent Alerts   | Latest alarm notifications |
    When I click on the health score panel
    Then I should see detailed health breakdown
    And Sentinel health factors should be displayed

  @dashboard @navigation @P0
  Scenario: E2E-DASH-002 - Navigation to all Prajna pages
    Given I am on the Prajna dashboard
    Then the following navigation links should work:
      | Link           | URL                      | Page Title        |
      | Dashboard      | /prajna                  | Command Cockpit   |
      | Alarms         | /prajna/alarms           | Alarm Management  |
      | Access Control | /prajna/access_control   | Access Control    |
      | Analytics      | /prajna/analytics        | Analytics         |
      | Compliance     | /prajna/compliance       | Compliance        |
      | Devices        | /prajna/devices          | Device Management |
      | Video          | /prajna/video            | Video Surveillance|
      | AI Copilot     | /prajna/copilot          | AI Copilot        |
      | Diagnostics    | /prajna/diagnostics      | Diagnostics       |
      | Knowledge      | /prajna/knowledge        | Knowledge Base    |
      | Settings       | /prajna/settings         | Settings          |
      | Topology       | /prajna/topology         | System Topology   |
      | Observability  | /prajna/observability    | Observability     |
      | Test Cockpit   | /prajna/test_cockpit     | Test Cockpit      |

  @dashboard @realtime @P0 @SC-BRIDGE-005
  Scenario: E2E-DASH-003 - Real-time Zenoh telemetry updates
    Given I am on the Prajna dashboard
    And Zenoh is publishing to "prajna/kpi/health"
    When a health update is published
    Then the dashboard should update within 1 second
    And no page refresh should be required
    And the WebSocket connection should remain stable

  # =============================================================================
  # ALARM MANAGEMENT E2E FLOWS
  # =============================================================================

  @alarms @lifecycle @P0
  Scenario: E2E-ALM-001 - Complete alarm lifecycle workflow
    Given I am on the Prajna alarms page
    When a new alarm is received:
      | Field       | Value                |
      | Type        | Intrusion            |
      | Severity    | Critical             |
      | Site        | Site-Alpha-001       |
      | Zone        | Zone-A               |
      | Timestamp   | 2026-01-10T10:30:00Z |
    Then the alarm should appear in the active alarms list
    And an audio alert should play (if enabled)
    And the alarm count badge should increment
    When I click on the alarm
    Then the alarm detail panel should open
    And I should see:
      | Field        | Value              |
      | Subscriber   | John Doe           |
      | Contact      | +1-555-0123        |
      | Response     | Armed Response     |
      | History      | Previous incidents |
    When I click "Acknowledge"
    Then the alarm status should change to "Acknowledged"
    And the acknowledgment time should be logged
    When I add a resolution note "False alarm - verified by phone"
    And I click "Resolve"
    Then the alarm should move to resolved list
    And the resolution should be logged in audit trail

  @alarms @storm @P0 @SC-IMMUNE-007
  Scenario: E2E-ALM-002 - Alarm storm detection and handling
    Given I am on the Prajna alarms page
    When 50+ alarms arrive within 60 seconds
    Then alarm storm mode should activate
    And the following UI changes should occur:
      | Change           | Description                   |
      | Grouping         | Alarms grouped by source      |
      | Priority Sort    | Critical alarms first         |
      | Audio            | Single consolidated alert     |
      | Performance      | List virtualization active    |
    And the storm indicator should show "STORM ACTIVE"
    When the alarm rate drops below 10/minute for 5 minutes
    Then alarm storm mode should deactivate

  @alarms @filtering @P1
  Scenario: E2E-ALM-003 - Alarm filtering and search
    Given I am on the Prajna alarms page
    And there are 100+ alarms in the system
    When I filter by severity "Critical"
    Then only critical alarms should be displayed
    When I additionally filter by type "Fire"
    Then only critical fire alarms should be displayed
    When I search for "Site-Alpha"
    Then only alarms from Site-Alpha should be displayed
    When I click "Clear Filters"
    Then all alarms should be displayed again

  @alarms @export @P1
  Scenario: E2E-ALM-004 - Alarm export functionality
    Given I am on the Prajna alarms page
    And I have selected multiple alarms
    When I click "Export"
    Then export format options should appear:
      | Format | Description           |
      | CSV    | Spreadsheet format    |
      | PDF    | Printable report      |
      | JSON   | API-compatible format |
    When I select "CSV" and confirm
    Then the download should start
    And the CSV should contain all selected alarm data

  # =============================================================================
  # ACCESS CONTROL E2E FLOWS
  # =============================================================================

  @access @permissions @P0
  Scenario: E2E-ACC-001 - Permission audit workflow
    Given I am on the Access Control page
    When I view the permission matrix
    Then I should see all roles and their permissions:
      | Role           | Alarms | Devices | Users | Config |
      | Administrator  | Full   | Full    | Full  | Full   |
      | Operator       | R/W    | Read    | None  | None   |
      | Viewer         | Read   | Read    | None  | None   |
    When I click on "Operator" role
    Then I should see detailed permissions
    And I should see users assigned to this role

  @access @audit @P0 @SC-SEC-047
  Scenario: E2E-ACC-002 - Access audit trail
    Given I am on the Access Control page
    When I click on "Audit Trail"
    Then I should see recent access events:
      | Column     | Description            |
      | Timestamp  | Event time             |
      | User       | Who performed action   |
      | Action     | What was done          |
      | Resource   | What was accessed      |
      | Result     | Success/Failure        |
    When I filter by "Failed" results
    Then only failed access attempts should be shown
    And I should be able to export the audit log

  # =============================================================================
  # ANALYTICS E2E FLOWS
  # =============================================================================

  @analytics @reports @P0
  Scenario: E2E-ANA-001 - Report generation workflow
    Given I am on the Analytics page
    When I click "Generate Report"
    Then the report wizard should open
    When I configure the report:
      | Field        | Value               |
      | Report Type  | Monthly Summary     |
      | Date Range   | Last 30 days        |
      | Sites        | All                 |
      | Metrics      | Alarms, Response    |
    And I click "Generate"
    Then the report should be generated within 30 seconds
    And I should see:
      | Section          | Content                |
      | Summary          | Key statistics         |
      | Trends           | Charts and graphs      |
      | SLA Compliance   | Response time metrics  |
      | Recommendations  | AI-powered suggestions |

  @analytics @metrics @P1
  Scenario: E2E-ANA-002 - Real-time metrics dashboard
    Given I am on the Analytics page
    When I view the metrics dashboard
    Then I should see real-time metrics:
      | Metric           | Update Frequency |
      | Alarm Rate       | 10s              |
      | Response Time    | 30s              |
      | Resolution Rate  | 60s              |
      | SLA Compliance   | 60s              |
    And the charts should update without page refresh

  # =============================================================================
  # COMPLIANCE E2E FLOWS
  # =============================================================================

  @compliance @audit @P0
  Scenario: E2E-CMP-001 - Compliance dashboard workflow
    Given I am on the Compliance page
    Then I should see compliance status for:
      | Standard   | Status    | Score  |
      | EN 50518   | Compliant | 98%    |
      | ISO 27001  | Compliant | 95%    |
      | GDPR       | Compliant | 100%   |
      | SIL-6      | Compliant | 99%    |
    When I click on "EN 50518"
    Then I should see detailed compliance checklist
    And non-compliant items should be highlighted

  @compliance @evidence @P1
  Scenario: E2E-CMP-002 - Evidence collection workflow
    Given I am on the Compliance page
    When I initiate evidence collection for "ISO 27001"
    Then the system should gather:
      | Evidence Type    | Source              |
      | Access Logs      | Database            |
      | Config Snapshots | Git repository      |
      | Audit Trail      | Immutable Register  |
      | Test Results     | CI/CD pipeline      |
    And the evidence package should be downloadable

  # =============================================================================
  # DEVICE MANAGEMENT E2E FLOWS
  # =============================================================================

  @devices @health @P0
  Scenario: E2E-DEV-001 - Device health monitoring workflow
    Given I am on the Devices page
    Then I should see the device health matrix
    When I filter by status "Offline"
    Then only offline devices should be displayed
    When I click on an offline device
    Then I should see:
      | Information      | Description             |
      | Last Seen        | Time of last contact    |
      | Diagnostics      | Error messages          |
      | History          | Recent status changes   |
      | Actions          | Reboot, Ping, Replace   |

  @devices @provisioning @P1
  Scenario: E2E-DEV-002 - Device provisioning workflow
    Given I am on the Devices page
    When I click "Add Device"
    Then the provisioning wizard should open
    When I enter device details:
      | Field        | Value               |
      | Type         | Panel               |
      | Model        | Galaxy G3           |
      | Serial       | GAL-001-2026        |
      | Site         | Site-Beta-002       |
    And I click "Provision"
    Then the device should be provisioned
    And it should appear in the device list
    And a welcome message should be sent to the device

  # =============================================================================
  # VIDEO SURVEILLANCE E2E FLOWS
  # =============================================================================

  @video @streams @P0
  Scenario: E2E-VID-001 - Video stream management workflow
    Given I am on the Video page
    Then I should see available camera streams
    When I click on a camera stream
    Then the live video should start playing
    And I should see stream controls:
      | Control     | Function           |
      | Play/Pause  | Toggle playback    |
      | PTZ         | Pan/Tilt/Zoom      |
      | Record      | Start recording    |
      | Snapshot    | Capture image      |
      | Full Screen | Expand view        |

  @video @playback @P1
  Scenario: E2E-VID-002 - Video playback workflow
    Given I am on the Video page
    When I select "Recorded Videos"
    And I filter by date "2026-01-09"
    Then recorded videos for that date should be listed
    When I click on a recording
    Then the playback should start
    And I should be able to seek, speed up, and download

  # =============================================================================
  # AI COPILOT E2E FLOWS
  # =============================================================================

  @copilot @chat @P0 @SC-PRAJNA-002
  Scenario: E2E-COP-001 - AI Copilot interaction workflow
    Given I am on the AI Copilot page
    And the copilot is connected to Guardian
    When I type "What is the current system health?"
    And I press Enter
    Then the copilot should respond within 5 seconds
    And the response should include:
      | Content        | Source              |
      | Health score   | Sentinel metrics    |
      | Threat count   | PatternHunter       |
      | Agent status   | Swarm telemetry     |
    And the response should align with Founder's Directive

  @copilot @recommendations @P0
  Scenario: E2E-COP-002 - AI recommendation workflow
    Given I am on the AI Copilot page
    And there are unresolved alarms
    When I ask "How should I prioritize current alarms?"
    Then the copilot should provide:
      | Recommendation     | Reason                    |
      | Prioritized list   | Based on severity/impact  |
      | Action suggestions | SOP-based recommendations |
      | Risk assessment    | Cascade effect analysis   |
    When I click "Apply Suggestion"
    Then the alarm list should be reordered

  @copilot @context @P1
  Scenario: E2E-COP-003 - Context-aware assistance
    Given I am on the Alarms page
    And I have selected an alarm
    When I click "Ask Copilot"
    Then the copilot panel should open
    And the context should include the selected alarm
    When I ask "What's the history of this site?"
    Then the response should include site-specific data

  # =============================================================================
  # GUARDIAN INTEGRATION E2E FLOWS
  # =============================================================================

  @guardian @approval @P0 @SC-PRAJNA-001
  Scenario: E2E-GUA-001 - Guardian approval workflow
    Given I am on the Prajna dashboard
    When I attempt a privileged operation:
      | Operation   | Type               |
      | Shutdown    | System halt        |
      | Reconfig    | Constitutional     |
      | Evolution   | Code mutation      |
    Then Guardian approval should be required
    And the approval request should show:
      | Field        | Content              |
      | Action       | What will happen     |
      | Impact       | 5-order effects      |
      | Risk         | FMEA assessment      |
      | Rollback     | Recovery option      |
    When Guardian approves
    Then the operation should proceed
    And the decision should be logged

  @guardian @veto @P0 @SC-CONST-007
  Scenario: E2E-GUA-002 - Guardian veto workflow
    Given I am on the Prajna dashboard
    When I attempt an operation violating constitutional invariants
    Then Guardian should automatically veto
    And the veto reason should be displayed:
      | Violation     | Ψ₀-Ψ₅ invariant check |
      | Explanation   | Why it was blocked    |
      | Alternative   | Safe alternatives     |
    And the veto should be logged to Immutable Register

  # =============================================================================
  # SENTINEL INTEGRATION E2E FLOWS
  # =============================================================================

  @sentinel @health @P0 @SC-IMMUNE-001
  Scenario: E2E-SEN-001 - Sentinel health integration
    Given I am on the Prajna dashboard
    When Sentinel detects a health degradation
    Then the dashboard should reflect:
      | Indicator     | Change               |
      | Health Score  | Decrease             |
      | Alert Badge   | New alert            |
      | Color Coding  | Yellow/Red           |
    And hovering over health should show factors:
      | Factor           | Weight |
      | Memory pressure  | 30%    |
      | CPU utilization  | 20%    |
      | Error rate       | 25%    |
      | Process anomalies| 15%    |
      | Quarantine status| 10%    |

  @sentinel @threats @P0 @SC-IMMUNE-004
  Scenario: E2E-SEN-002 - Threat detection integration
    Given I am on the Prajna dashboard
    And PatternHunter detects a memory leak pattern
    Then a threat alert should appear
    And the alert should include:
      | Field          | Content                |
      | Threat Type    | Memory Leak            |
      | Severity       | High                   |
      | Time to Error  | Estimated 2 hours      |
      | Affected       | Process list           |
      | Recommendation | Remediation steps      |
    When I click "Apply Recommendation"
    Then the remediation should be executed
    And the threat status should update

  # =============================================================================
  # WEBSOCKET & REAL-TIME E2E FLOWS
  # =============================================================================

  @websocket @connection @P0
  Scenario: E2E-WS-001 - WebSocket connection management
    Given I am on the Prajna dashboard
    Then the WebSocket status indicator should show "Connected"
    When the WebSocket connection is lost
    Then the indicator should show "Disconnected"
    And a reconnection attempt should start
    And stale data should be marked with warning
    When the connection is restored
    Then the indicator should show "Connected"
    And data should refresh automatically

  @websocket @reliability @P0 @SC-BRIDGE-001
  Scenario: E2E-WS-002 - WebSocket reliability under load
    Given I am on the Prajna dashboard
    And 100+ events/second are being published
    Then the UI should remain responsive
    And message buffering should prevent data loss
    And older messages should be processed FIFO
    And latency should remain under 50ms (SC-PRF-050)

  # =============================================================================
  # MULTI-USER E2E FLOWS
  # =============================================================================

  @multiuser @collaboration @P1
  Scenario: E2E-MU-001 - Multi-user collaboration
    Given operator "Alice" is on the Alarms page
    And operator "Bob" is on the Alarms page
    When Alice acknowledges an alarm
    Then Bob should see the acknowledgment immediately
    And the alarm should show "Acknowledged by Alice"
    When Bob tries to acknowledge the same alarm
    Then a warning should show "Already acknowledged"

  @multiuser @locking @P1
  Scenario: E2E-MU-002 - Resource locking
    Given operator "Alice" is editing device settings
    When operator "Bob" tries to edit the same device
    Then Bob should see "Device locked by Alice"
    And Bob should see an estimated wait time
    When Alice saves and exits
    Then Bob should be notified the lock is released

  # =============================================================================
  # PERFORMANCE E2E FLOWS
  # =============================================================================

  @performance @load @P0 @SC-PRF-050
  Scenario: E2E-PERF-001 - Page load performance
    Given I measure page load times
    Then all Prajna pages should load within:
      | Page        | Max Load Time |
      | Dashboard   | 2 seconds     |
      | Alarms      | 2 seconds     |
      | Analytics   | 3 seconds     |
      | Video       | 3 seconds     |
      | All Others  | 2 seconds     |

  @performance @scrolling @P1
  Scenario: E2E-PERF-002 - Virtual scrolling performance
    Given I am on the Alarms page
    And there are 10,000+ alarms
    When I scroll through the list
    Then scrolling should be smooth (60 FPS)
    And memory usage should remain stable
    And only visible items should be rendered

  # =============================================================================
  # ERROR HANDLING E2E FLOWS
  # =============================================================================

  @errors @graceful @P0
  Scenario: E2E-ERR-001 - Graceful error handling
    Given I am on the Prajna dashboard
    When an API request fails
    Then a user-friendly error message should appear
    And the error should not crash the page
    And retry options should be available
    And the error should be logged to observability

  @errors @recovery @P0
  Scenario: E2E-ERR-002 - Auto-recovery from errors
    Given I am on the Prajna dashboard
    When a transient error occurs
    Then the system should auto-retry with backoff:
      | Attempt | Delay    |
      | 1       | 1 second |
      | 2       | 2 seconds|
      | 3       | 4 seconds|
    And if all retries fail, show manual recovery option

  # =============================================================================
  # ACCESSIBILITY E2E FLOWS
  # =============================================================================

  @accessibility @keyboard @P1
  Scenario: E2E-A11Y-001 - Keyboard navigation
    Given I am on the Prajna dashboard
    Then all interactive elements should be reachable via Tab
    And focus indicators should be visible
    And Escape should close modals
    And Enter should activate focused elements

  @accessibility @screen-reader @P1
  Scenario: E2E-A11Y-002 - Screen reader support
    Given I am using a screen reader
    When I navigate the Prajna dashboard
    Then all elements should have ARIA labels
    And live regions should announce updates
    And forms should have proper labels
    And errors should be announced

  # =============================================================================
  # MOBILE RESPONSIVENESS E2E FLOWS
  # =============================================================================

  @mobile @responsive @P1
  Scenario: E2E-MOB-001 - Mobile viewport support
    Given I am viewing Prajna on a mobile device (375px width)
    Then the navigation should collapse to hamburger menu
    And tables should be scrollable horizontally
    And touch targets should be at least 44x44 pixels
    And the dashboard should remain usable

  @mobile @touch @P1
  Scenario: E2E-MOB-002 - Touch interactions
    Given I am using Prajna on a tablet
    Then swipe gestures should work for navigation
    And pinch-to-zoom should work for charts
    And long-press should show context menus
    And pull-to-refresh should reload data
