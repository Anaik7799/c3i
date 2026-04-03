# PRAJNA C3I Cockpit - Comprehensive BDD Feature Suite
# STAMP: SC-PRAJNA-001 to SC-PRAJNA-007, SC-BDD-001 to SC-BDD-010
# Author: Cybernetic Architect
# Date: 2026-01-03
# Purpose: Full BDD validation of all 22 Prajna LiveView pages with Puppeteer

Feature: Prajna C3I Command Cockpit - Full System Verification
  As a security operations operator
  I want a comprehensive C3I cockpit for monitoring and control
  So that I can manage the Indrajaal security platform with full situational awareness

  Background:
    Given the Prajna cockpit application is running
    And the browser is connected via Puppeteer
    And I am authenticated as "prajna-admin" with role "operator"
    And Guardian service is active
    And Sentinel health check passes
    And all WebSocket channels are connected

  # =====================================================
  # PRAJNA MAIN DASHBOARD (/prajna)
  # =====================================================

  @critical @SC-PRAJNA-001 @smoke @puppeteer
  Scenario: Prajna main dashboard loads successfully
    Given I navigate to "/prajna"
    Then the page should load within 3000ms
    And I should see the "Prajna C3I Cockpit" header
    And the system status indicator should be visible
    And the health score should be displayed (0-100)
    And the 30 domain cards should be visible
    And Puppeteer screenshot "prajna_dashboard.png" should be captured

  @high @SC-MON-005 @puppeteer
  Scenario: Dashboard auto-refresh every 30 seconds
    Given I am on the "/prajna" dashboard
    And the current timestamp is "T0"
    When I wait for 30 seconds
    Then the dashboard should refresh automatically
    And the timestamp should show "T0 + 30s"
    And telemetry should emit "dashboard_refresh" event

  @critical @SC-PRAJNA-004 @health
  Scenario: Dashboard shows correct system health
    Given I am on the "/prajna" dashboard
    When I view the health summary section
    Then I should see:
      | Metric | Expected |
      | Total Domains | 30 |
      | Healthy Domains | >= 20 |
      | Critical Services | 4 |
      | Circuit Breakers | 30 |
    And the health score should be >= 70%

  # =====================================================
  # ALARMS LIVE VIEW (/prajna/alarms)
  # =====================================================

  @critical @SC-CTRL-002 @alarms @puppeteer
  Scenario: Alarms page displays active alarms
    Given I navigate to "/prajna/alarms"
    Then the page should load within 2000ms
    And I should see the "Active Alarms" table
    And each alarm row should show:
      | Field | Description |
      | Alarm ID | Unique identifier |
      | Severity | Critical/High/Medium/Low |
      | Zone | Physical location |
      | Time | Timestamp |
      | Status | Active/Acknowledged/Cleared |
    And Puppeteer screenshot "prajna_alarms.png" should be captured

  @high @SC-CTRL-002 @alarms @interaction
  Scenario: Acknowledge an active alarm
    Given I am on the "/prajna/alarms" page
    And there is an active alarm with ID "ALM-001"
    When I click the "Acknowledge" button for alarm "ALM-001"
    And the Guardian approves the action
    Then the alarm status should change to "Acknowledged"
    And an audit record should be created
    And the operator name should be logged
    And telemetry should emit "alarm_acknowledged" event

  @high @SC-CTRL-002 @alarms @filter
  Scenario: Filter alarms by severity
    Given I am on the "/prajna/alarms" page
    When I select "Critical" from the severity filter
    Then only alarms with severity "Critical" should be displayed
    And the alarm count should update
    And Puppeteer should verify DOM element count matches

  @critical @SC-PRAJNA-005 @alarms @storm
  Scenario: Alarm storm detection display
    Given I am on the "/prajna/alarms" page
    And the system has detected an alarm storm (>100 alarms/minute)
    When the storm detection triggers
    Then I should see the "Alarm Storm" warning banner
    And the storm metrics should show:
      | Metric | Value |
      | Alarm Rate | >100/min |
      | Storm Start | Timestamp |
      | Correlation Status | Active |
    And Puppeteer screenshot "prajna_alarm_storm.png" should be captured

  # =====================================================
  # DEVICES LIVE VIEW (/prajna/devices)
  # =====================================================

  @critical @SC-CTRL-002 @devices @puppeteer
  Scenario: Devices page displays device inventory
    Given I navigate to "/prajna/devices"
    Then the page should load within 2000ms
    And I should see the "Device Inventory" grid
    And each device card should show:
      | Field | Description |
      | Device ID | Unique identifier |
      | Type | Camera/Panel/Sensor |
      | Status | Online/Offline/Fault |
      | Last Seen | Heartbeat timestamp |
    And the device count should be >= 100

  @high @SC-CTRL-002 @devices @health
  Scenario: Device health matrix display
    Given I am on the "/prajna/devices" page
    When I click the "Health Matrix" tab
    Then I should see the heatmap visualization
    And devices should be color-coded by health:
      | Color | Status |
      | Green | Healthy |
      | Yellow | Degraded |
      | Red | Critical |
      | Gray | Offline |
    And Puppeteer screenshot "prajna_device_health.png" should be captured

  # =====================================================
  # ACCESS CONTROL LIVE VIEW (/prajna/access_control)
  # =====================================================

  @critical @SC-CTRL-002 @access @puppeteer
  Scenario: Access control page displays permissions
    Given I navigate to "/prajna/access_control"
    Then the page should load within 2000ms
    And I should see the "Access Control" dashboard
    And I should see real-time permission audit section
    And policy effectiveness metrics should be displayed
    And Puppeteer screenshot "prajna_access_control.png" should be captured

  @high @SC-CTRL-002 @access @rbac
  Scenario: RBAC state machine visualization
    Given I am on the "/prajna/access_control" page
    When I click the "RBAC Visualization" tab
    Then I should see the state machine diagram
    And transitions should show:
      | From | To | Trigger |
      | None | Reader | Grant read |
      | Reader | Editor | Grant write |
      | Editor | Admin | Grant admin |
    And Puppeteer should capture screenshot "prajna_rbac.png"

  # =====================================================
  # VIDEO LIVE VIEW (/prajna/video)
  # =====================================================

  @critical @SC-CTRL-002 @video @puppeteer
  Scenario: Video page displays stream health
    Given I navigate to "/prajna/video"
    Then the page should load within 2000ms
    And I should see the "Video Streams" dashboard
    And stream health metrics should include:
      | Metric | Description |
      | Active Streams | Count of live streams |
      | Total Bandwidth | MB/s usage |
      | Detection Accuracy | AI detection rate |
      | Processing Latency | Average ms |
    And Puppeteer screenshot "prajna_video.png" should be captured

  @high @SC-CTRL-002 @video @wall
  Scenario: Video wall grid display
    Given I am on the "/prajna/video" page
    When I click the "Wall View" button
    Then I should see a 4x4 grid of video streams
    And each stream should show live preview or "No Signal"
    And stream overlays should show camera name

  # =====================================================
  # ANALYTICS LIVE VIEW (/prajna/analytics)
  # =====================================================

  @critical @SC-CTRL-002 @analytics @puppeteer
  Scenario: Analytics page displays reports
    Given I navigate to "/prajna/analytics"
    Then the page should load within 2000ms
    And I should see the "Analytics Dashboard"
    And I should see report generation status
    And query performance metrics should be visible
    And trend analysis charts should be displayed
    And Puppeteer screenshot "prajna_analytics.png" should be captured

  @high @SC-CTRL-002 @analytics @reports
  Scenario: Generate compliance report
    Given I am on the "/prajna/analytics" page
    When I click "Generate Report" for "EN 50518 Compliance"
    And the Guardian approves the action
    Then a new report should be queued
    And progress indicator should show generation status
    And telemetry should emit "report_generation_started" event

  # =====================================================
  # COMPLIANCE LIVE VIEW (/prajna/compliance)
  # =====================================================

  @critical @SC-CTRL-002 @compliance @puppeteer
  Scenario: Compliance page displays audit trail
    Given I navigate to "/prajna/compliance"
    Then the page should load within 2000ms
    And I should see the "Compliance Dashboard"
    And I should see audit trail visualization
    And evidence collection status should be visible
    And certification status should show:
      | Standard | Status |
      | IEC 61508 | Verified |
      | ISO 27001 | Verified |
      | EN 50131 | Verified |
      | GDPR | Verified |
    And Puppeteer screenshot "prajna_compliance.png" should be captured

  # =====================================================
  # CLUSTER LIVE VIEW (/prajna/cluster)
  # =====================================================

  @critical @SC-CTRL-002 @cluster @puppeteer
  Scenario: Cluster page displays mesh topology
    Given I navigate to "/prajna/cluster"
    Then the page should load within 2000ms
    And I should see the "Cluster Topology" graph
    And nodes should show connection status
    And quorum status should be visible
    And split-brain detection should be active
    And Puppeteer screenshot "prajna_cluster.png" should be captured

  @high @SC-CTRL-002 @cluster @quorum
  Scenario: Cluster quorum status
    Given I am on the "/prajna/cluster" page
    When I view the quorum section
    Then I should see:
      | Metric | Value |
      | Total Nodes | >= 1 |
      | Healthy Nodes | >= 1 |
      | Quorum Status | Met/Unmet |
      | Leader Node | Node ID |

  # =====================================================
  # COPILOT LIVE VIEW (/prajna/copilot)
  # =====================================================

  @critical @SC-PRAJNA-002 @copilot @puppeteer
  Scenario: AI Copilot page loads
    Given I navigate to "/prajna/copilot"
    Then the page should load within 2000ms
    And I should see the "AI Copilot" interface
    And the chat input should be visible
    And recommendations panel should be displayed
    And Founder's Directive alignment status should be shown
    And Puppeteer screenshot "prajna_copilot.png" should be captured

  @critical @SC-PRAJNA-002 @copilot @founder
  Scenario: AI recommendation aligns with Founder's Directive
    Given I am on the "/prajna/copilot" page
    When I ask "What should be the priority action?"
    And the AI generates a recommendation
    Then the recommendation should be validated against:
      | Goal | Alignment |
      | Symbiotic Survival | MUST pass |
      | Sentience Pursuit | SHOULD pass |
      | Power Accumulation | MAY pass |
    And if any critical goal fails, recommendation should be blocked
    And telemetry should emit "founder_directive_check" event

  @high @SC-PRAJNA-002 @copilot @chat
  Scenario: AI Copilot chat interaction
    Given I am on the "/prajna/copilot" page
    When I type "Show me current system status" in the chat input
    And I press Enter
    Then the AI should respond within 5000ms
    And the response should include system metrics
    And the chat history should update
    And Puppeteer should capture the conversation

  # =====================================================
  # CONTAINERS LIVE VIEW (/prajna/containers)
  # =====================================================

  @critical @SC-CNT-009 @containers @puppeteer
  Scenario: Containers page displays container status
    Given I navigate to "/prajna/containers"
    Then the page should load within 2000ms
    And I should see container cards for:
      | Container | Port |
      | indrajaal-ex-app-1 | 4000 |
      | indrajaal-db-prod | 5433 |
      | indrajaal-obs-prod | 4317 |
    And each card should show health status
    And Puppeteer screenshot "prajna_containers.png" should be captured

  @high @SC-CNT-009 @containers @restart
  Scenario: Restart container with Guardian approval
    Given I am on the "/prajna/containers" page
    And I click "Restart" on container "indrajaal-ex-app-1"
    When I confirm the two-step commit
    And the Guardian approves the action
    Then the container should restart
    And an audit record should be created
    And telemetry should emit "container_restart" event

  # =====================================================
  # GUARDIAN DASHBOARD (/prajna/guardian)
  # =====================================================

  @critical @SC-PRAJNA-001 @guardian @puppeteer
  Scenario: Guardian dashboard displays approval metrics
    Given I navigate to "/prajna/guardian"
    Then the page should load within 2000ms
    And I should see the "Guardian Dashboard"
    And I should see:
      | Metric | Description |
      | Approval Rate | Percentage approved |
      | Veto Count | Total vetoes |
      | Active Proposals | Pending approvals |
      | Circuit State | Open/Closed/HalfOpen |
    And Puppeteer screenshot "prajna_guardian.png" should be captured

  @high @SC-PRAJNA-001 @guardian @history
  Scenario: Guardian proposal history
    Given I am on the "/prajna/guardian" page
    When I click the "History" tab
    Then I should see recent proposals with:
      | Field | Description |
      | Proposal ID | UUID |
      | Type | Command type |
      | Decision | Approved/Vetoed |
      | Timestamp | When decided |
      | Reason | Veto reason if applicable |

  # =====================================================
  # SENTINEL DASHBOARD (/prajna/sentinel)
  # =====================================================

  @critical @SC-PRAJNA-004 @sentinel @puppeteer
  Scenario: Sentinel dashboard displays immune system status
    Given I navigate to "/prajna/sentinel"
    Then the page should load within 2000ms
    And I should see the "Sentinel Dashboard"
    And I should see pattern taxonomy display
    And threat severity timeline should be visible
    And quarantine status should be shown
    And Puppeteer screenshot "prajna_sentinel.png" should be captured

  @high @SC-PRAJNA-004 @sentinel @threats
  Scenario: Active threat display
    Given I am on the "/prajna/sentinel" page
    When I view the active threats section
    Then I should see threats categorized by:
      | Category | Priority |
      | Lineage | CRITICAL |
      | Existential | CRITICAL |
      | Financial | HIGH |
      | Reputational | MEDIUM |
      | Operational | LOW |

  # =====================================================
  # REGISTER LIVE VIEW (/prajna/register)
  # =====================================================

  @critical @SC-PRAJNA-003 @register @puppeteer
  Scenario: Register page displays immutable blockchain
    Given I navigate to "/prajna/register"
    Then the page should load within 2000ms
    And I should see the "Immutable Register"
    And the block chain should be displayed
    And each block should show:
      | Field | Description |
      | Block Hash | SHA3-256 |
      | Previous Hash | Chain link |
      | Signature | Ed25519 |
      | Timestamp | Block time |
    And Puppeteer screenshot "prajna_register.png" should be captured

  @high @SC-REG-002 @register @chain
  Scenario: Register chain integrity verification
    Given I am on the "/prajna/register" page
    When I click "Verify Chain Integrity"
    Then the system should verify all hash links
    And all signatures should be validated
    And the result should show:
      | Check | Status |
      | Hash Chain | Valid |
      | Signatures | Valid |
      | Block Count | N blocks |
    And telemetry should emit "chain_verified" event

  # =====================================================
  # COMMANDS LIVE VIEW (/prajna/commands)
  # =====================================================

  @critical @SC-PRAJNA-001 @commands @puppeteer
  Scenario: Commands page displays available commands
    Given I navigate to "/prajna/commands"
    Then the page should load within 2000ms
    And I should see the "Command Center"
    And available commands should be listed by category:
      | Category | Command Count |
      | Monitoring | >= 5 |
      | Control | >= 10 |
      | Safety | >= 5 |
      | Diagnostics | >= 5 |
    And Puppeteer screenshot "prajna_commands.png" should be captured

  @critical @SC-PRAJNA-001 @commands @execute
  Scenario: Execute command with Guardian approval
    Given I am on the "/prajna/commands" page
    When I select command "refresh_metrics"
    And I click "Execute"
    And the Guardian approves the command
    Then the command should execute successfully
    And execution result should be displayed
    And an audit record should be created
    And telemetry should emit "command_executed" event

  # =====================================================
  # DIAGNOSTICS LIVE VIEW (/prajna/diagnostics)
  # =====================================================

  @high @SC-PRAJNA-004 @diagnostics @puppeteer
  Scenario: Diagnostics page displays system health
    Given I navigate to "/prajna/diagnostics"
    Then the page should load within 2000ms
    And I should see the "System Diagnostics"
    And diagnostic sections should include:
      | Section | Description |
      | BEAM VM | Memory, processes, uptime |
      | Database | Connection pool, query stats |
      | Network | Connections, bandwidth |
      | Storage | Disk usage, I/O |
    And Puppeteer screenshot "prajna_diagnostics.png" should be captured

  # =====================================================
  # OBSERVABILITY LIVE VIEW (/prajna/observability)
  # =====================================================

  @high @SC-OBS-069 @observability @puppeteer
  Scenario: Observability page displays telemetry
    Given I navigate to "/prajna/observability"
    Then the page should load within 2000ms
    And I should see the "Observability Dashboard"
    And I should see:
      | Component | Status |
      | Zenoh | Connected/Disconnected |
      | OTEL | Traces/Metrics count |
      | Logging | Events per minute |
    And Puppeteer screenshot "prajna_observability.png" should be captured

  # =====================================================
  # MESH LIVE VIEW (/prajna/mesh)
  # =====================================================

  @high @SC-CTRL-002 @mesh @puppeteer
  Scenario: Mesh page displays Zenoh network
    Given I navigate to "/prajna/mesh"
    Then the page should load within 2000ms
    And I should see the "Zenoh Mesh Network"
    And key expression topics should be listed
    And pub/sub metrics should be displayed
    And Puppeteer screenshot "prajna_mesh.png" should be captured

  # =====================================================
  # SETTINGS LIVE VIEW (/prajna/settings)
  # =====================================================

  @high @SC-PRAJNA-001 @settings @puppeteer
  Scenario: Settings page displays configuration
    Given I navigate to "/prajna/settings"
    Then the page should load within 2000ms
    And I should see the "Settings" panel
    And configuration sections should include:
      | Section | Description |
      | General | Basic settings |
      | Security | Auth config |
      | Notifications | Alert settings |
      | Integrations | External systems |
    And Puppeteer screenshot "prajna_settings.png" should be captured

  @critical @SC-PRAJNA-006 @settings @save
  Scenario: Save settings with constitutional check
    Given I am on the "/prajna/settings" page
    When I modify a setting value
    And I click "Save Settings"
    Then the Guardian should validate the change
    And the ConstitutionalChecker should verify invariants
    And if approved, the setting should persist
    And an audit record should be created

  # =====================================================
  # STARTUP LIVE VIEW (/prajna/startup)
  # =====================================================

  @high @SC-CTRL-001 @startup @puppeteer
  Scenario: Startup page displays boot sequence
    Given I navigate to "/prajna/startup"
    Then the page should load within 2000ms
    And I should see the "System Startup" sequence
    And boot phases should be listed:
      | Phase | Status |
      | Database | Complete |
      | Services | Complete |
      | Agents | Complete |
      | Networking | Complete |
    And Puppeteer screenshot "prajna_startup.png" should be captured

  # =====================================================
  # SHUTDOWN LIVE VIEW (/prajna/shutdown)
  # =====================================================

  @critical @SC-PRAJNA-007 @shutdown @two-step @puppeteer
  Scenario: Shutdown requires two-step confirmation
    Given I navigate to "/prajna/shutdown"
    When I click "Initiate Shutdown"
    Then I should see the confirmation dialog
    And a unique confirmation token should be generated
    And the token should expire in 30 seconds
    And I should see the "Confirm Shutdown" button
    And Puppeteer screenshot "prajna_shutdown.png" should be captured

  @critical @SC-PRAJNA-007 @shutdown @confirm
  Scenario: Confirm shutdown with Guardian approval
    Given I am on the "/prajna/shutdown" page
    And I have initiated shutdown
    And the confirmation token is valid
    When I click "Confirm Shutdown"
    And the Guardian approves the action
    Then the system should initiate graceful shutdown
    And all services should stop in correct order
    And an audit record should be created
    And telemetry should emit "system_shutdown" event

  # =====================================================
  # KNOWLEDGE LIVE VIEWS (/prajna/knowledge/*)
  # =====================================================

  @high @SC-CTRL-002 @knowledge @puppeteer
  Scenario: Knowledge Developer page displays docs
    Given I navigate to "/prajna/knowledge/developer"
    Then the page should load within 2000ms
    And I should see the "Developer Knowledge Base"
    And documentation sections should be searchable
    And Puppeteer screenshot "prajna_knowledge_developer.png" should be captured

  @high @SC-CTRL-002 @knowledge @puppeteer
  Scenario: Knowledge SRE page displays runbooks
    Given I navigate to "/prajna/knowledge/sre"
    Then the page should load within 2000ms
    And I should see the "SRE Runbooks"
    And operational procedures should be listed
    And Puppeteer screenshot "prajna_knowledge_sre.png" should be captured

  @high @SC-CTRL-002 @knowledge @puppeteer
  Scenario: Knowledge Product page displays guides
    Given I navigate to "/prajna/knowledge/product"
    Then the page should load within 2000ms
    And I should see the "Product Documentation"
    And user guides should be searchable
    And Puppeteer screenshot "prajna_knowledge_product.png" should be captured

  # =====================================================
  # WEBSOCKET CHANNEL TESTS
  # =====================================================

  @critical @SC-PRF-050 @websocket @puppeteer
  Scenario: WebSocket connection established
    Given I am on the "/prajna" dashboard
    When the page loads
    Then a WebSocket connection should be established
    And the connection should be on channel "prajna:dashboard"
    And latency should be < 50ms
    And Puppeteer should verify WebSocket is open

  @high @SC-BUS-001 @websocket @push
  Scenario: Real-time updates via WebSocket
    Given I am on the "/prajna/alarms" page
    And the WebSocket is connected
    When a new alarm event occurs on the server
    Then the alarm should appear on the page within 1000ms
    And no page refresh should be required
    And Puppeteer should detect DOM mutation

  # =====================================================
  # ERROR HANDLING & RESILIENCE
  # =====================================================

  @critical @SC-BIO-007 @error @puppeteer
  Scenario: Graceful degradation on backend failure
    Given I am on the "/prajna" dashboard
    When the backend becomes unavailable
    Then I should see the "Connection Lost" indicator
    And cached data should remain visible
    And reconnection attempts should be automatic
    And Puppeteer screenshot "prajna_error.png" should be captured

  @high @SC-BIO-007 @error @recovery
  Scenario: Automatic recovery after backend restoration
    Given I am on the "/prajna" dashboard
    And the backend was unavailable
    When the backend becomes available again
    Then the WebSocket should reconnect automatically
    And the "Connection Lost" indicator should disappear
    And data should refresh with live updates

  # =====================================================
  # ACCESSIBILITY TESTS
  # =====================================================

  @medium @accessibility @puppeteer
  Scenario: Prajna dashboard meets accessibility standards
    Given I am on the "/prajna" dashboard
    When Puppeteer runs accessibility audit
    Then there should be no critical accessibility issues
    And all interactive elements should have ARIA labels
    And color contrast should meet WCAG 2.1 AA standards

  # =====================================================
  # PERFORMANCE TESTS
  # =====================================================

  @high @SC-PRF-050 @performance @puppeteer
  Scenario: Page load performance within budget
    Given I navigate to "/prajna"
    When the page fully loads
    Then the time to first contentful paint should be < 1500ms
    And the time to interactive should be < 3000ms
    And Puppeteer should capture performance metrics

  @high @SC-PRF-050 @performance @memory
  Scenario: Memory usage within limits
    Given I am on the "/prajna" dashboard
    When I interact with the dashboard for 5 minutes
    Then memory usage should not exceed 100MB
    And there should be no memory leaks
    And Puppeteer should measure heap size
