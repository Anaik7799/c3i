# Web UI Cockpit - Comprehensive BDD Feature Suite
# STAMP: SC-PRAJNA-001 to SC-PRAJNA-007, SC-PRF-050, SC-BIO-005
# AOR: AOR-PRAJNA-001 to AOR-PRAJNA-005, AOR-COV-006
# Author: Cybernetic Architect
# Date: 2026-01-10
# Purpose: 100% end-to-end coverage of Web UI based cockpit with Puppeteer

@web @cockpit @puppeteer @sil6
Feature: Web UI Cockpit - Phoenix LiveView C3I Interface
  As a security operations administrator
  I want a web-based cockpit with real-time updates
  So that I can monitor and control the security platform from any browser

  Background:
    Given the Phoenix server is running on port 4000
    And Puppeteer is connected to the browser
    And I am authenticated as "admin" with role "operator"
    And WebSocket channels are established
    And Guardian service is operational
    And Zenoh mesh connectivity is confirmed

  # =============================================================================
  # MAIN DASHBOARD - ENTRY POINT
  # =============================================================================

  @P0 @dashboard @smoke @puppeteer
  Scenario: Web cockpit main dashboard loads successfully
    Given I navigate to "http://localhost:4000/prajna"
    When the page fully loads
    Then I should see the "PRAJNA C3I COCKPIT" header
    And I should see the system health indicator widget
    And I should see the 30 domain status cards
    And I should see the threat advisory panel
    And the page load time should be < 3000ms
    And Puppeteer screenshot "web_cockpit_dashboard.png" should be captured

  @P0 @dashboard @metrics @puppeteer
  Scenario: Dashboard displays real-time system metrics
    Given I am on the main dashboard
    When the metrics widget loads
    Then I should see:
      | Metric           | Type       | Update Rate |
      | CPU Usage        | Percentage | 30s         |
      | Memory Usage     | Percentage | 30s         |
      | Network I/O      | MB/s       | 30s         |
      | Active Sessions  | Count      | Real-time   |
      | Error Rate       | Percentage | 30s         |
    And metrics should update via LiveView push

  @P0 @dashboard @navigation @puppeteer
  Scenario: Navigation menu contains all pages
    Given I am on the main dashboard
    When I click the navigation menu
    Then I should see links to all 22 pages:
      | Page             | Path                       |
      | Dashboard        | /prajna                    |
      | Alarms           | /prajna/alarms             |
      | Devices          | /prajna/devices            |
      | Access Control   | /prajna/access_control     |
      | Video            | /prajna/video              |
      | Analytics        | /prajna/analytics          |
      | Compliance       | /prajna/compliance         |
      | Cluster          | /prajna/cluster            |
      | AI Copilot       | /prajna/copilot            |
      | Containers       | /prajna/containers         |
      | Guardian         | /prajna/guardian           |
      | Sentinel         | /prajna/sentinel           |
      | Register         | /prajna/register           |
      | Commands         | /prajna/commands           |
      | Diagnostics      | /prajna/diagnostics        |
      | Observability    | /prajna/observability      |
      | Mesh             | /prajna/mesh               |
      | Settings         | /prajna/settings           |
      | Startup          | /prajna/startup            |
      | Shutdown         | /prajna/shutdown           |
      | Knowledge Dev    | /prajna/knowledge/developer|
      | Knowledge SRE    | /prajna/knowledge/sre      |

  @P0 @dashboard @health @SC-PRAJNA-004
  Scenario: Health score reflects actual system state
    Given I am on the main dashboard
    When I observe the health score widget
    Then the health score should be between 0 and 100
    And the score color should follow:
      | Score Range | Color  |
      | 80-100      | Green  |
      | 60-79       | Yellow |
      | 40-59       | Orange |
      | 0-39        | Red    |
    And clicking the score should show breakdown details

  @P0 @dashboard @websocket @SC-PRF-050
  Scenario: WebSocket connection maintains < 50ms latency
    Given I am on the main dashboard
    When I measure WebSocket latency
    Then the connection should be on "prajna:dashboard" topic
    And latency should be < 50ms
    And connection should be over wss:// in production
    And reconnection should be automatic on disconnect

  # =============================================================================
  # ALARM MANAGEMENT PAGE
  # =============================================================================

  @P0 @alarms @listing @puppeteer
  Scenario: Alarms page displays active alarm list
    Given I navigate to "http://localhost:4000/prajna/alarms"
    When the page loads
    Then I should see the "Active Alarms" table with columns:
      | Column     | Type       |
      | ID         | String     |
      | Severity   | Enum       |
      | Zone       | String     |
      | Timestamp  | DateTime   |
      | Status     | Enum       |
      | Actions    | Buttons    |
    And alarms should be sortable by each column
    And Puppeteer screenshot "web_alarms_list.png" should be captured

  @P0 @alarms @acknowledge @guardian @SC-PRAJNA-001
  Scenario: Acknowledging alarm requires Guardian approval
    Given I am on the alarms page
    And there is an active alarm "ALM-TEST-001"
    When I click "Acknowledge" for alarm "ALM-TEST-001"
    Then a Guardian approval request should be created
    And I should see "Awaiting Guardian approval" status
    And when Guardian approves:
      | Field       | Value         |
      | Status      | Acknowledged  |
      | Operator    | Current user  |
      | Timestamp   | Current time  |
    And the action should be logged to audit trail

  @P0 @alarms @storm @detection @puppeteer
  Scenario: Alarm storm detection and visualization
    Given I am on the alarms page
    When alarm rate exceeds 100 alarms per minute
    Then the storm detection banner should appear
    And the banner should show:
      | Field             | Value         |
      | Storm Status      | ACTIVE        |
      | Alarm Rate        | >100/min      |
      | Correlation       | In Progress   |
    And related alarms should be grouped
    And Puppeteer screenshot "web_alarm_storm.png" should be captured

  @P1 @alarms @filter @puppeteer
  Scenario: Filter alarms by multiple criteria
    Given I am on the alarms page
    When I apply filters:
      | Filter    | Value         |
      | Severity  | Critical      |
      | Zone      | Zone A        |
      | Status    | Active        |
    Then only matching alarms should be displayed
    And filter chips should show active filters
    And "Clear Filters" button should appear

  @P1 @alarms @export
  Scenario: Export alarms to various formats
    Given I am on the alarms page
    When I click the "Export" button
    Then I should see export options:
      | Format | Extension |
      | CSV    | .csv      |
      | JSON   | .json     |
      | PDF    | .pdf      |
    And exported file should contain all visible alarms

  # =============================================================================
  # DEVICE MANAGEMENT PAGE
  # =============================================================================

  @P0 @devices @inventory @puppeteer
  Scenario: Devices page displays device inventory grid
    Given I navigate to "http://localhost:4000/prajna/devices"
    When the page loads
    Then I should see device cards in a grid layout
    And each card should show:
      | Field       | Description           |
      | Device ID   | Unique identifier     |
      | Type        | Camera/Panel/Sensor   |
      | Status      | Online/Offline/Fault  |
      | Last Seen   | Heartbeat timestamp   |
      | Health      | Color indicator       |
    And Puppeteer screenshot "web_devices_grid.png" should be captured

  @P0 @devices @health_matrix @puppeteer
  Scenario: Device health matrix heatmap display
    Given I am on the devices page
    When I click the "Health Matrix" tab
    Then I should see a heatmap visualization
    And colors should represent:
      | Color   | Status    |
      | #22c55e | Healthy   |
      | #eab308 | Degraded  |
      | #ef4444 | Critical  |
      | #6b7280 | Offline   |
    And clicking a cell should open device details

  @P1 @devices @detail @modal
  Scenario: Device detail modal shows complete information
    Given I am on the devices page
    When I click on device "DEV-001"
    Then a modal should open with tabs:
      | Tab        | Content                |
      | Overview   | Basic device info      |
      | History    | Connectivity timeline  |
      | Config     | Configuration params   |
      | Logs       | Recent event logs      |
    And modal should have "Close" button

  @P1 @devices @commands
  Scenario: Send command to device
    Given I am viewing device "DEV-001" details
    When I click "Send Command"
    And I select command "Restart"
    And I confirm the action
    Then the command should be queued
    And command status should update in real-time
    And result should be displayed when complete

  # =============================================================================
  # VIDEO MONITORING PAGE
  # =============================================================================

  @P0 @video @streams @puppeteer
  Scenario: Video page displays stream grid
    Given I navigate to "http://localhost:4000/prajna/video"
    When the page loads
    Then I should see the video stream grid
    And each stream tile should show:
      | Element      | Description        |
      | Preview      | Live or "No Signal"|
      | Camera Name  | Overlay text       |
      | Health       | Status indicator   |
      | PTZ Controls | Pan/Tilt/Zoom      |
    And Puppeteer screenshot "web_video_grid.png" should be captured

  @P1 @video @wall @layout
  Scenario: Video wall configurable layouts
    Given I am on the video page
    When I select layout options
    Then I should see preset layouts:
      | Layout | Grid     |
      | 1x1    | Single   |
      | 2x2    | 4 tiles  |
      | 3x3    | 9 tiles  |
      | 4x4    | 16 tiles |
      | Custom | Variable |

  @P1 @video @detection @events
  Scenario: AI detection events displayed
    Given I am viewing a video stream
    When an AI detection event occurs
    Then I should see:
      | Element          | Description          |
      | Bounding Box     | Highlighted region   |
      | Label            | Detection type       |
      | Confidence       | Percentage score     |
      | Timestamp        | Event time           |

  # =============================================================================
  # AI COPILOT PAGE
  # =============================================================================

  @P0 @copilot @interface @puppeteer @SC-PRAJNA-002
  Scenario: AI Copilot chat interface
    Given I navigate to "http://localhost:4000/prajna/copilot"
    When the page loads
    Then I should see:
      | Element              | Description              |
      | Chat History         | Previous messages        |
      | Input Field          | Message composition      |
      | Send Button          | Submit message           |
      | Context Panel        | System state summary     |
      | Founder Status       | Directive alignment      |
    And Puppeteer screenshot "web_copilot_interface.png" should be captured

  @P0 @copilot @founder_directive @validation @SC-PRAJNA-002
  Scenario: Copilot recommendations align with Founder's Directive
    Given I am on the AI Copilot page
    When I ask for a recommendation
    Then the response should be validated against:
      | Goal                 | Priority  | Requirement |
      | Symbiotic Survival   | PRIMARY   | MUST pass   |
      | Sentience Pursuit    | SECONDARY | SHOULD pass |
      | Power Accumulation   | TERTIARY  | MAY pass    |
    And validation result should be displayed
    And failed validation should block recommendation

  @P1 @copilot @chat @interaction
  Scenario: Chat interaction with response streaming
    Given I am on the AI Copilot page
    When I type "What is the current system health?"
    And I click "Send"
    Then a thinking indicator should appear
    And the response should stream character by character
    And the response should complete within 10 seconds
    And the response should include relevant metrics

  @P1 @copilot @suggestions
  Scenario: Contextual suggestions panel
    Given I am on the AI Copilot page
    When I view the suggestions panel
    Then I should see context-aware suggestions:
      | Category         | Example                    |
      | System Status    | "How is system health?"    |
      | Alarms           | "Show critical alarms"     |
      | Performance      | "Analyze slow queries"     |
      | Troubleshooting  | "Why is device offline?"   |

  # =============================================================================
  # GUARDIAN DASHBOARD PAGE
  # =============================================================================

  @P0 @guardian @dashboard @puppeteer @SC-PRAJNA-001
  Scenario: Guardian dashboard displays approval metrics
    Given I navigate to "http://localhost:4000/prajna/guardian"
    When the page loads
    Then I should see:
      | Widget           | Content                  |
      | Approval Rate    | Percentage over time     |
      | Veto Count       | Total vetoes             |
      | Pending Queue    | Active proposals         |
      | Circuit State    | Open/Closed/HalfOpen     |
    And Puppeteer screenshot "web_guardian_dashboard.png" should be captured

  @P0 @guardian @proposals @list
  Scenario: View pending proposals
    Given I am on the Guardian dashboard
    When I view the proposals section
    Then each proposal should show:
      | Field        | Description         |
      | Proposal ID  | UUID                |
      | Type         | Command category    |
      | Requestor    | User or system      |
      | Created      | Timestamp           |
      | Status       | Pending/Approved/Vetoed |

  @P1 @guardian @history @audit
  Scenario: Guardian decision history
    Given I am on the Guardian dashboard
    When I click the "History" tab
    Then I should see historical decisions with:
      | Field         | Description        |
      | Decision ID   | UUID               |
      | Type          | Approved/Vetoed    |
      | Timestamp     | When decided       |
      | Reason        | Veto reason if any |
      | Actor         | Who decided        |

  # =============================================================================
  # SENTINEL HEALTH PAGE
  # =============================================================================

  @P0 @sentinel @health @puppeteer @SC-PRAJNA-004
  Scenario: Sentinel dashboard displays immune system status
    Given I navigate to "http://localhost:4000/prajna/sentinel"
    When the page loads
    Then I should see:
      | Widget             | Description              |
      | Health Score       | Overall system health    |
      | Pattern Taxonomy   | Threat categories        |
      | Threat Timeline    | Severity over time       |
      | Quarantine Status  | Isolated components      |
    And Puppeteer screenshot "web_sentinel_health.png" should be captured

  @P0 @sentinel @threats @classification
  Scenario: Active threats classified by severity
    Given I am on the Sentinel dashboard
    When I view active threats
    Then threats should be categorized:
      | Category      | Priority    |
      | Lineage       | CRITICAL    |
      | Existential   | CRITICAL    |
      | Financial     | HIGH        |
      | Reputational  | MEDIUM      |
      | Operational   | LOW         |
    And each threat should show RPN score

  @P1 @sentinel @quarantine @management
  Scenario: View and manage quarantine
    Given I am on the Sentinel dashboard
    When I view the quarantine section
    Then I should see quarantined components with:
      | Field          | Description         |
      | Component      | Module/Process name |
      | Reason         | Why quarantined     |
      | Quarantined At | Timestamp           |
      | Actions        | Release/Delete      |

  # =============================================================================
  # IMMUTABLE REGISTER PAGE
  # =============================================================================

  @P0 @register @chain @puppeteer @SC-PRAJNA-003
  Scenario: Register page displays blockchain
    Given I navigate to "http://localhost:4000/prajna/register"
    When the page loads
    Then I should see the block chain visualization
    And each block should display:
      | Field        | Type        |
      | Block Hash   | SHA3-256    |
      | Prev Hash    | SHA3-256    |
      | Signature    | Ed25519     |
      | Timestamp    | DateTime    |
      | Content      | JSON        |
    And Puppeteer screenshot "web_register_chain.png" should be captured

  @P0 @register @verify @integrity @SC-REG-002
  Scenario: Verify chain integrity
    Given I am on the Register page
    When I click "Verify Chain Integrity"
    Then verification should run and show:
      | Check          | Expected    |
      | Hash Chain     | Valid       |
      | Signatures     | All Valid   |
      | Block Count    | N blocks    |
      | Genesis Block  | Present     |
    And result should be logged

  @P1 @register @explorer
  Scenario: Block explorer functionality
    Given I am on the Register page
    When I click on a block
    Then block details should expand showing:
      | Field          | Description        |
      | Full Hash      | Complete hash      |
      | Prev Full Hash | Complete prev hash |
      | Content        | Formatted JSON     |
      | Signature      | Verification status|

  # =============================================================================
  # CONTAINERS PAGE
  # =============================================================================

  @P0 @containers @status @puppeteer
  Scenario: Containers page shows all container status
    Given I navigate to "http://localhost:4000/prajna/containers"
    When the page loads
    Then I should see container cards for all 12 HA containers:
      | Container           | Expected Status |
      | indrajaal-haproxy   | healthy         |
      | indrajaal-ex-app-1  | healthy         |
      | indrajaal-ex-app-2  | healthy         |
      | indrajaal-ex-app-3  | healthy         |
      | indrajaal-db-ha     | healthy         |
      | indrajaal-obs-ha    | healthy         |
      | zenoh-ha-1          | healthy         |
      | zenoh-ha-2          | healthy         |
      | zenoh-ha-3          | healthy         |
      | zenoh-ha-proxy      | healthy         |
      | cepaf-bridge-ha     | healthy         |
      | indrajaal-cortex-ha | healthy         |
    And Puppeteer screenshot "web_containers_status.png" should be captured

  @P1 @containers @restart @two_step @SC-PRAJNA-007
  Scenario: Container restart requires two-step confirmation
    Given I am on the containers page
    When I click "Restart" on container "indrajaal-ex-app-1"
    Then a confirmation dialog should appear
    And I should see countdown timer (30 seconds)
    And confirming should require Guardian approval
    And the container should restart on approval

  @P1 @containers @logs @streaming
  Scenario: Container log streaming
    Given I am on the containers page
    When I click "Logs" for container "indrajaal-ex-app-1"
    Then a log viewer should open
    And logs should stream in real-time
    And I should be able to filter by level
    And I should be able to search within logs

  # =============================================================================
  # CLUSTER PAGE - MESH TOPOLOGY
  # =============================================================================

  @P0 @cluster @topology @puppeteer
  Scenario: Cluster page displays mesh topology
    Given I navigate to "http://localhost:4000/prajna/cluster"
    When the page loads
    Then I should see a topology graph showing:
      | Element        | Description           |
      | Nodes          | All cluster members   |
      | Connections    | Links between nodes   |
      | Status         | Color-coded health    |
      | Leader         | Highlighted node      |
    And Puppeteer screenshot "web_cluster_topology.png" should be captured

  @P0 @cluster @quorum @status
  Scenario: Quorum status display
    Given I am on the cluster page
    When I view the quorum panel
    Then I should see:
      | Metric         | Description         |
      | Total Nodes    | Count of nodes      |
      | Healthy Nodes  | Healthy count       |
      | Quorum Required| floor(N/2) + 1      |
      | Quorum Status  | Met/Unmet           |
      | Split Brain    | Detected/Clear      |

  # =============================================================================
  # SETTINGS PAGE
  # =============================================================================

  @P0 @settings @config @puppeteer
  Scenario: Settings page displays configuration
    Given I navigate to "http://localhost:4000/prajna/settings"
    When the page loads
    Then I should see settings sections:
      | Section        | Description          |
      | General        | Basic configuration  |
      | Security       | Auth settings        |
      | Notifications  | Alert preferences    |
      | Integrations   | External systems     |
      | Display        | UI preferences       |
    And Puppeteer screenshot "web_settings.png" should be captured

  @P1 @settings @save @constitutional @SC-PRAJNA-006
  Scenario: Settings changes require constitutional check
    Given I am on the settings page
    When I modify a setting
    And I click "Save"
    Then the change should be validated against:
      | Check                   | Required  |
      | Guardian Approval       | Yes       |
      | Constitutional Check    | Yes       |
      | Invariant Verification  | Yes       |
    And approved changes should persist
    And audit record should be created

  # =============================================================================
  # SHUTDOWN PAGE - TWO-STEP COMMIT
  # =============================================================================

  @P0 @shutdown @initiate @puppeteer @SC-PRAJNA-007
  Scenario: Shutdown requires two-step confirmation
    Given I navigate to "http://localhost:4000/prajna/shutdown"
    When I click "Initiate Shutdown"
    Then I should see:
      | Element              | Description          |
      | Warning Banner       | Destructive action   |
      | Confirmation Token   | Unique code          |
      | Timer                | 30 second countdown  |
      | Confirm Button       | Disabled initially   |
    And Puppeteer screenshot "web_shutdown_confirm.png" should be captured

  @P0 @shutdown @confirm @guardian
  Scenario: Confirm shutdown with Guardian approval
    Given I have initiated shutdown
    And the confirmation token is valid
    When I enter the confirmation token
    And I click "Confirm Shutdown"
    Then Guardian should be requested for approval
    And on approval, shutdown should proceed with:
      | Phase        | Status     |
      | Notification | Complete   |
      | Draining     | In Progress|
      | Checkpoint   | Complete   |
      | Termination  | Complete   |

  # =============================================================================
  # ERROR HANDLING - GRACEFUL DEGRADATION
  # =============================================================================

  @P0 @error @disconnection @puppeteer @SC-BIO-007
  Scenario: Graceful handling of WebSocket disconnect
    Given I am on any cockpit page
    When the WebSocket connection is lost
    Then I should see "Connection Lost" indicator
    And cached data should remain visible
    And automatic reconnection should attempt
    And controls should be disabled until reconnect
    And Puppeteer screenshot "web_disconnected.png" should be captured

  @P0 @error @recovery
  Scenario: Automatic recovery after reconnection
    Given the WebSocket was disconnected
    When the connection is restored
    Then the "Connection Lost" indicator should disappear
    And data should refresh automatically
    And controls should be re-enabled
    And no user action should be required

  @P1 @error @validation
  Scenario: Form validation errors displayed inline
    Given I am filling out a form
    When I enter invalid data
    Then validation errors should appear inline
    And the submit button should be disabled
    And error messages should be clear and actionable

  # =============================================================================
  # ACCESSIBILITY - WCAG COMPLIANCE
  # =============================================================================

  @P1 @accessibility @aria @puppeteer
  Scenario: ARIA labels for interactive elements
    Given I am on any cockpit page
    When Puppeteer audits accessibility
    Then all interactive elements should have ARIA labels
    And all images should have alt text
    And focus order should be logical

  @P1 @accessibility @contrast
  Scenario: Color contrast meets WCAG standards
    Given I am on any cockpit page
    When checking color contrast
    Then text should meet WCAG 2.1 AA standards
    And contrast ratio should be at least 4.5:1
    And error states should be distinguishable by more than color

  @P1 @accessibility @keyboard
  Scenario: Full keyboard navigation
    Given I am on any cockpit page
    When using only keyboard
    Then all interactive elements should be reachable via Tab
    And focus should be visually indicated
    And Escape should close modals
    And Enter should activate buttons

  # =============================================================================
  # PERFORMANCE - PAGE LOAD AND INTERACTION
  # =============================================================================

  @P0 @performance @load @puppeteer @SC-PRF-050
  Scenario: Page load performance metrics
    Given I navigate to any cockpit page
    When the page fully loads
    Then performance metrics should meet:
      | Metric                      | Target   |
      | First Contentful Paint      | < 1500ms |
      | Time to Interactive         | < 3000ms |
      | Largest Contentful Paint    | < 2500ms |
      | Cumulative Layout Shift     | < 0.1    |

  @P1 @performance @memory
  Scenario: Memory usage bounded during interaction
    Given I am on the dashboard
    When I interact with the page for 5 minutes
    Then browser memory should not exceed 150MB
    And no memory leaks should be detected
    And Puppeteer should report heap statistics

  @P0 @performance @refresh @SC-BIO-005
  Scenario: Dashboard refresh every 30 seconds
    Given I am on the dashboard
    When 30 seconds elapse
    Then metrics should refresh via LiveView push
    And no full page reload should occur
    And timestamp should update

  # =============================================================================
  # RESPONSIVE DESIGN - MULTI-DEVICE
  # =============================================================================

  @P2 @responsive @desktop @puppeteer
  Scenario: Desktop layout (1920x1080)
    Given I set viewport to 1920x1080
    When I load the dashboard
    Then I should see full desktop layout
    And sidebar should be visible
    And all widgets should be displayed
    And Puppeteer screenshot "web_desktop_layout.png" should be captured

  @P2 @responsive @tablet @puppeteer
  Scenario: Tablet layout (768x1024)
    Given I set viewport to 768x1024
    When I load the dashboard
    Then I should see tablet-optimized layout
    And sidebar should collapse to hamburger menu
    And widgets should reflow to fit

  @P2 @responsive @mobile @puppeteer
  Scenario: Mobile layout (375x667)
    Given I set viewport to 375x667
    When I load the dashboard
    Then I should see mobile-optimized layout
    And navigation should be bottom tabs
    And content should be single column
