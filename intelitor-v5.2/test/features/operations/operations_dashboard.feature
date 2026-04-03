# Operations Dashboard - Comprehensive BDD Feature Suite
# STAMP: SC-CTRL-001 to SC-CTRL-007, SC-MON-001 to SC-MON-006
# Author: Cybernetic Architect
# Date: 2026-01-03
# Purpose: Full BDD validation of all 5 Operations LiveView pages with Puppeteer

Feature: Operations Dashboard - Security Monitoring & Dispatch
  As a security operations center operator
  I want comprehensive dashboards for alarms, video, access, and dispatch
  So that I can respond to security incidents effectively

  Background:
    Given the Indrajaal application is running
    And the browser is connected via Puppeteer
    And I am authenticated as "soc-operator" with role "operator"
    And WebSocket channels are connected
    And the database has test data loaded

  # =====================================================
  # ACTIVE ALARMS LIVE VIEW (/operations/alarms)
  # =====================================================

  @critical @SC-CTRL-002 @alarms @puppeteer
  Scenario: Active alarms page displays real-time alarms
    Given I navigate to "/operations/alarms"
    Then the page should load within 2000ms
    And I should see the "Active Alarms" dashboard
    And the alarm table should show columns:
      | Column | Description |
      | ID | Alarm identifier |
      | Time | Received timestamp |
      | Zone | Physical location |
      | Type | Alarm type (Intrusion/Fire/Medical) |
      | Severity | Critical/High/Medium/Low |
      | Status | Active/Acknowledged/Cleared |
      | Actions | Available actions |
    And Puppeteer screenshot "ops_active_alarms.png" should be captured

  @critical @SC-CTRL-002 @alarms @realtime
  Scenario: Alarms update in real-time via WebSocket
    Given I am on the "/operations/alarms" page
    And the initial alarm count is 5
    When a new alarm is received from the backend
    Then the alarm should appear at the top of the table
    And the alarm count should update to 6
    And an audio alert should play (if enabled)
    And no page refresh should be required

  @high @SC-CTRL-002 @alarms @acknowledge
  Scenario: Acknowledge an active alarm
    Given I am on the "/operations/alarms" page
    And there is an active alarm with ID "ALM-2026-001"
    When I click the "Acknowledge" button for that alarm
    Then a confirmation dialog should appear
    And when I confirm the acknowledgement
    Then the alarm status should change to "Acknowledged"
    And the acknowledged_by field should show my username
    And the acknowledged_at timestamp should be set
    And telemetry should emit "alarm_acknowledged" event

  @high @SC-CTRL-002 @alarms @filter
  Scenario: Filter alarms by severity
    Given I am on the "/operations/alarms" page
    And there are alarms of all severity levels
    When I click the "Critical" severity filter
    Then only alarms with severity "Critical" should be shown
    And the URL should update to include "?severity=critical"
    And the filter should be visually highlighted

  @high @SC-CTRL-002 @alarms @filter
  Scenario: Filter alarms by zone
    Given I am on the "/operations/alarms" page
    And there are alarms from multiple zones
    When I select "Zone A" from the zone dropdown
    Then only alarms from "Zone A" should be shown
    And the alarm count should update

  @medium @SC-CTRL-002 @alarms @sort
  Scenario: Sort alarms by column
    Given I am on the "/operations/alarms" page
    When I click the "Time" column header
    Then alarms should be sorted by time (newest first)
    When I click the "Time" column header again
    Then alarms should be sorted by time (oldest first)

  @critical @SC-PRAJNA-005 @alarms @storm
  Scenario: Alarm storm detection and suppression
    Given I am on the "/operations/alarms" page
    When more than 100 alarms arrive within 60 seconds
    Then an "Alarm Storm Detected" banner should appear
    And the storm details should show:
      | Field | Value |
      | Rate | >100/min |
      | Start Time | Timestamp |
      | Zones Affected | List |
    And correlation mode should activate automatically
    And Puppeteer screenshot "ops_alarm_storm.png" should be captured

  # =====================================================
  # ALARM INVESTIGATION LIVE VIEW (/operations/investigation)
  # =====================================================

  @high @SC-CTRL-002 @investigation @puppeteer
  Scenario: Alarm investigation page loads with details
    Given an alarm with ID "ALM-2026-001" exists
    When I navigate to "/operations/investigation/ALM-2026-001"
    Then the page should load within 2000ms
    And I should see the alarm details panel
    And I should see the site information panel
    And I should see the response history panel
    And I should see the related alarms panel
    And Puppeteer screenshot "ops_investigation.png" should be captured

  @high @SC-CTRL-002 @investigation @history
  Scenario: View alarm response history
    Given I am on the investigation page for alarm "ALM-2026-001"
    When I view the response history section
    Then I should see a timeline of events:
      | Event | Time | Actor |
      | Alarm Received | T+0s | System |
      | Auto-acknowledged | T+1s | System |
      | Operator notified | T+2s | System |
      | Operator acknowledged | T+45s | soc-operator |

  @high @SC-CTRL-002 @investigation @escalate
  Scenario: Escalate alarm to supervisor
    Given I am on the investigation page for alarm "ALM-2026-001"
    When I click the "Escalate" button
    And I select supervisor "sup-001"
    And I enter escalation reason "Requires senior review"
    And I click "Confirm Escalation"
    Then the alarm should be marked as escalated
    And the supervisor should receive notification
    And telemetry should emit "alarm_escalated" event

  @medium @SC-CTRL-002 @investigation @notes
  Scenario: Add investigation notes
    Given I am on the investigation page for alarm "ALM-2026-001"
    When I click "Add Note"
    And I enter "False alarm - CCTV shows cat in sensor zone"
    And I click "Save Note"
    Then the note should appear in the investigation log
    And the note should show my username and timestamp

  # =====================================================
  # VIDEO WALL LIVE VIEW (/operations/video)
  # =====================================================

  @critical @SC-CTRL-002 @video @puppeteer
  Scenario: Video wall displays camera grid
    Given I navigate to "/operations/video"
    Then the page should load within 3000ms
    And I should see a video wall grid layout
    And the default layout should be 4x4 (16 cameras)
    And each video tile should show:
      | Element | Description |
      | Camera Name | Identifier label |
      | Status | Live/Offline/Recording |
      | Stream | Video or placeholder |
    And Puppeteer screenshot "ops_video_wall.png" should be captured

  @high @SC-CTRL-002 @video @layout
  Scenario: Change video wall layout
    Given I am on the "/operations/video" page
    When I click the layout selector
    And I select "2x2" layout
    Then the grid should show 4 cameras
    And each video tile should be larger

  @high @SC-CTRL-002 @video @fullscreen
  Scenario: View camera in fullscreen
    Given I am on the "/operations/video" page
    When I double-click on camera "CAM-001"
    Then the camera should enter fullscreen mode
    And controls should be visible (pause, PTZ, record)
    When I press Escape
    Then the camera should exit fullscreen

  @high @SC-CTRL-002 @video @ptz
  Scenario: Control PTZ camera
    Given I am on the "/operations/video" page
    And camera "CAM-PTZ-001" is a PTZ camera
    When I click on the camera tile
    And I click the PTZ controls
    Then I should see directional buttons (Up/Down/Left/Right)
    And zoom controls (+/-)
    When I click "Pan Left"
    Then the camera should pan left
    And telemetry should emit "ptz_command" event

  @medium @SC-CTRL-002 @video @recording
  Scenario: Start manual recording
    Given I am on the "/operations/video" page
    When I right-click on camera "CAM-001"
    And I select "Start Recording"
    Then a recording indicator should appear
    And the recording should be logged to the system

  @high @SC-CTRL-002 @video @alarm-link
  Scenario: Auto-show camera on alarm
    Given I am on the "/operations/video" page
    When an alarm from zone "Zone A" is received
    And "Zone A" has linked camera "CAM-ZONE-A"
    Then camera "CAM-ZONE-A" should automatically enlarge
    Or a popup should show the camera feed

  # =====================================================
  # ACCESS DASHBOARD LIVE VIEW (/operations/access)
  # =====================================================

  @critical @SC-CTRL-002 @access @puppeteer
  Scenario: Access dashboard displays entry/exit events
    Given I navigate to "/operations/access"
    Then the page should load within 2000ms
    And I should see the "Access Control" dashboard
    And I should see recent access events table
    And I should see door status overview
    And I should see cardholder statistics
    And Puppeteer screenshot "ops_access_dashboard.png" should be captured

  @high @SC-CTRL-002 @access @events
  Scenario: View access events in real-time
    Given I am on the "/operations/access" page
    When a new access event occurs (card swipe)
    Then the event should appear at the top of the events list
    And the event should show:
      | Field | Description |
      | Time | Event timestamp |
      | Door | Door name |
      | Cardholder | Person name |
      | Result | Granted/Denied |
      | Photo | Badge photo if available |

  @high @SC-CTRL-002 @access @doors
  Scenario: View door status overview
    Given I am on the "/operations/access" page
    When I view the door status section
    Then I should see all doors with status:
      | Status | Color |
      | Locked | Green |
      | Unlocked | Yellow |
      | Held Open | Red |
      | Offline | Gray |

  @high @SC-CTRL-002 @access @unlock
  Scenario: Remote unlock a door
    Given I am on the "/operations/access" page
    And door "Main Entrance" is locked
    When I click on door "Main Entrance"
    And I click "Remote Unlock"
    And I enter reason "Authorized visitor arrival"
    Then the door should unlock
    And an audit log entry should be created
    And telemetry should emit "door_unlocked" event

  @high @SC-CTRL-002 @access @lockdown
  Scenario: Initiate facility lockdown
    Given I am on the "/operations/access" page
    When I click "Emergency Lockdown"
    Then a confirmation dialog should appear with two-step commit
    When I enter my PIN and confirm
    Then all doors should lock
    And a lockdown banner should appear
    And all operators should be notified
    And Puppeteer screenshot "ops_lockdown.png" should be captured

  @medium @SC-CTRL-002 @access @antipassback
  Scenario: View anti-passback violations
    Given I am on the "/operations/access" page
    When I click the "Violations" tab
    Then I should see anti-passback violations
    And tailgating detections
    And each violation should show cardholder and door

  # =====================================================
  # DISPATCH CONSOLE LIVE VIEW (/operations/dispatch)
  # =====================================================

  @critical @SC-CTRL-002 @dispatch @puppeteer
  Scenario: Dispatch console displays responders
    Given I navigate to "/operations/dispatch"
    Then the page should load within 2000ms
    And I should see the "Dispatch Console"
    And I should see available responders list
    And I should see pending dispatch queue
    And I should see active responses map (if maps enabled)
    And Puppeteer screenshot "ops_dispatch_console.png" should be captured

  @high @SC-CTRL-002 @dispatch @assign
  Scenario: Dispatch responder to alarm
    Given I am on the "/operations/dispatch" page
    And there is an unassigned alarm "ALM-2026-001"
    And responder "Guard-001" is available
    When I drag alarm "ALM-2026-001" to responder "Guard-001"
    Or I click "Assign" and select responder
    Then the alarm should be assigned to "Guard-001"
    And the responder status should change to "Assigned"
    And the responder should receive mobile notification
    And telemetry should emit "responder_dispatched" event

  @high @SC-CTRL-002 @dispatch @status
  Scenario: View responder status in real-time
    Given I am on the "/operations/dispatch" page
    When I view the responders section
    Then I should see responders with status:
      | Status | Meaning |
      | Available | Ready for dispatch |
      | Assigned | En route to alarm |
      | On Scene | At alarm location |
      | Returning | Heading back |
      | Off Duty | Not available |

  @high @SC-CTRL-002 @dispatch @timeline
  Scenario: View response timeline
    Given I am on the "/operations/dispatch" page
    And alarm "ALM-2026-001" has been dispatched
    When I click on the alarm to view details
    Then I should see the response timeline:
      | Event | SLA Target | Actual |
      | Alarm Received | - | T+0s |
      | Dispatch Assigned | 60s | T+30s |
      | Responder En Route | 120s | T+45s |
      | On Scene | 300s | T+240s |
      | Resolution | 600s | T+420s |

  @medium @SC-CTRL-002 @dispatch @gps
  Scenario: Track responder location on map
    Given I am on the "/operations/dispatch" page
    And the map view is enabled
    When responder "Guard-001" is en route
    Then the map should show "Guard-001" location
    And the location should update as they move
    And ETA to alarm should be calculated

  @high @SC-CTRL-002 @dispatch @escalation
  Scenario: Auto-escalate unresponded alarms
    Given I am on the "/operations/dispatch" page
    And alarm "ALM-2026-001" has been pending for 5 minutes
    When the escalation timer expires
    Then the alarm should automatically escalate
    And the supervisor should be notified
    And the alarm should be highlighted in the queue

  # =====================================================
  # CROSS-PAGE INTEGRATION
  # =====================================================

  @critical @integration @navigation
  Scenario: Navigate between operations pages
    Given I am on the "/operations/alarms" page
    When I click the "Video" navigation link
    Then I should be on the "/operations/video" page
    And the navigation should complete within 1000ms
    When I click "Back" or the alarms link
    Then I should return to "/operations/alarms"

  @high @integration @alarm-flow
  Scenario: Complete alarm handling workflow
    Given a new intrusion alarm is received
    When I am on the "/operations/alarms" page
    And I acknowledge the alarm
    And I click "Investigate" on the alarm
    Then I should be on the investigation page
    When I click "View Camera" for the linked zone
    Then the video feed should display
    When I dispatch a responder
    Then I should see the dispatch timeline update
    And when the alarm is resolved
    Then the workflow should complete successfully

  @critical @integration @websocket
  Scenario: WebSocket reconnection on network issue
    Given I am on the "/operations/alarms" page
    When the WebSocket connection drops
    Then a "Connection Lost" indicator should appear
    And reconnection should be attempted automatically
    When the connection is restored
    Then the indicator should disappear
    And any missed alarms should be fetched

  # =====================================================
  # ERROR HANDLING
  # =====================================================

  @high @error @timeout
  Scenario: Handle backend timeout gracefully
    Given I am on the "/operations/alarms" page
    When I try to acknowledge an alarm but the backend times out
    Then an error message should display
    And the alarm status should not change
    And a retry button should be available

  @medium @error @permission
  Scenario: Handle permission denied
    Given I am on the "/operations/dispatch" page
    And I do not have dispatch permissions
    When I try to assign a responder
    Then a "Permission Denied" message should display
    And the action should not complete

  # =====================================================
  # PERFORMANCE
  # =====================================================

  @high @performance @load
  Scenario: Handle high alarm volume
    Given I am on the "/operations/alarms" page
    And there are 500 active alarms
    Then the page should remain responsive
    And scrolling should be smooth
    And pagination or virtualization should be active

  @medium @performance @memory
  Scenario: No memory leaks during extended use
    Given I am on the "/operations/alarms" page
    When I monitor memory usage for 30 minutes
    Then memory should not increase continuously
    And old DOM elements should be cleaned up
