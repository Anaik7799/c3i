# Elixir Web UI - Comprehensive BDD Feature Suite
# STAMP: SC-CTRL-001 to SC-CTRL-007, SC-MON-001 to SC-MON-006
# AOR: AOR-CTRL-001 to AOR-CTRL-005, AOR-MON-001 to AOR-MON-005
# Author: Cybernetic Architect
# Date: 2026-01-10
# Purpose: 100% end-to-end coverage of Elixir based WebUI and Phoenix LiveView pages

@elixir @liveview @phoenix @sil6
Feature: Elixir Web UI - Phoenix LiveView System Interface
  As a security system operator
  I want a responsive Elixir-based web interface
  So that I can manage the 30-domain security platform with full situational awareness

  Background:
    Given the Phoenix application is running
    And the database is connected and healthy
    And all 50 agents are operational
    And the observability stack is active
    And I am authenticated with valid credentials

  # =============================================================================
  # DOMAIN DASHBOARDS - ALL 30 DOMAINS
  # =============================================================================

  @P0 @domains @overview @puppeteer
  Scenario: All 30 domain dashboards accessible
    Given I am on the main system dashboard
    Then I should be able to navigate to all 30 domain dashboards:
      | Domain        | Path                     | Modules |
      | Access        | /domains/access_control  | 15      |
      | Accounts      | /domains/accounts        | 12      |
      | Alarms        | /domains/alarms          | 45      |
      | Analytics     | /domains/analytics       | 22      |
      | Auth          | /domains/authentication  | 18      |
      | Authz         | /domains/authorization   | 14      |
      | Billing       | /domains/billing         | 25      |
      | Cluster       | /domains/cluster         | 30      |
      | Cockpit       | /domains/cockpit         | 38      |
      | Comm          | /domains/communication   | 20      |
      | Compliance    | /domains/compliance      | 28      |
      | Coordination  | /domains/coordination    | 16      |
      | Cortex        | /domains/cortex          | 35      |
      | Cybernetic    | /domains/cybernetic      | 42      |
      | Devices       | /domains/devices         | 50      |
      | Dispatch      | /domains/dispatch        | 32      |
      | Distributed   | /domains/distributed     | 24      |
      | FLAME         | /domains/flame           | 8       |
      | Identity      | /domains/identity        | 20      |
      | Integration   | /domains/integration     | 55      |
      | Knowledge     | /domains/knowledge       | 15      |
      | Maintenance   | /domains/maintenance     | 18      |
      | Mesh          | /domains/mesh            | 25      |
      | Observability | /domains/observability   | 30      |
      | Policy        | /domains/policy          | 22      |
      | Safety        | /domains/safety          | 40      |
      | Security      | /domains/security        | 35      |
      | Sites         | /domains/sites           | 28      |
      | Validation    | /domains/validation      | 25      |
      | Video         | /domains/video           | 38      |

  @P0 @domains @health_card
  Scenario: Domain health cards display correct status
    Given I am on a domain dashboard
    When viewing the domain health card
    Then I should see:
      | Metric          | Type        |
      | Module Count    | Integer     |
      | Error Count     | Integer     |
      | Warning Count   | Integer     |
      | Test Coverage   | Percentage  |
      | Status          | Enum        |
    And status color should reflect health:
      | Status  | Color   |
      | Healthy | Green   |
      | Degraded| Yellow  |
      | Failed  | Red     |

  # =============================================================================
  # ACCOUNTS DOMAIN - USER MANAGEMENT
  # =============================================================================

  @P0 @accounts @list @puppeteer
  Scenario: Accounts page lists all users
    Given I navigate to "/domains/accounts"
    When the page loads
    Then I should see the user list table with columns:
      | Column   | Type     |
      | ID       | UUID     |
      | Email    | String   |
      | Name     | String   |
      | Role     | Enum     |
      | Status   | Enum     |
      | Created  | DateTime |
    And pagination should be available
    And Puppeteer screenshot "elixir_accounts_list.png" should be captured

  @P1 @accounts @create @form
  Scenario: Create new user account
    Given I am on the accounts page
    When I click "Create User"
    And I fill in the form:
      | Field           | Value              |
      | Email           | test@example.com   |
      | Name            | Test User          |
      | Role            | operator           |
    And I click "Save"
    Then the user should be created
    And I should see success notification
    And audit log should record the action

  @P1 @accounts @rbac @permissions
  Scenario: RBAC permission enforcement
    Given I am logged in as "viewer" role
    When I try to access admin-only features
    Then I should see "Access Denied" message
    And the action should be blocked
    And security event should be logged

  # =============================================================================
  # ALARMS DOMAIN - ALARM PROCESSING
  # =============================================================================

  @P0 @alarms @processing @puppeteer
  Scenario: Alarm processing workflow display
    Given I navigate to "/domains/alarms"
    When the page loads
    Then I should see alarm processing stages:
      | Stage       | Description           |
      | Receive     | Alarm ingestion       |
      | Parse       | Format validation     |
      | Classify    | Severity assignment   |
      | Correlate   | Storm detection       |
      | Route       | Dispatch assignment   |
      | Resolve     | Completion            |
    And Puppeteer screenshot "elixir_alarms_workflow.png" should be captured

  @P0 @alarms @realtime @websocket
  Scenario: Real-time alarm updates via LiveView
    Given I am on the alarms dashboard
    And a WebSocket connection is established
    When a new alarm arrives in the system
    Then the alarm should appear in the list within 1 second
    And no page refresh should be required
    And alarm count should update

  @P1 @alarms @correlation
  Scenario: Alarm correlation engine visualization
    Given I am on the alarms dashboard
    When alarm storm is detected
    Then I should see:
      | Element           | Description            |
      | Correlation Graph | Related alarms linked  |
      | Root Cause        | Identified source      |
      | Impact Radius     | Affected systems       |
      | Timeline          | Event sequence         |

  # =============================================================================
  # DEVICES DOMAIN - DEVICE MANAGEMENT
  # =============================================================================

  @P0 @devices @inventory @puppeteer
  Scenario: Device inventory management
    Given I navigate to "/domains/devices"
    When the page loads
    Then I should see device inventory with:
      | View Mode    | Description        |
      | Table        | List view          |
      | Grid         | Card view          |
      | Map          | Geographic layout  |
      | Tree         | Hierarchical       |
    And device count should be displayed
    And Puppeteer screenshot "elixir_devices_inventory.png" should be captured

  @P0 @devices @heartbeat
  Scenario: Device heartbeat monitoring
    Given I am on the devices dashboard
    When viewing device status panel
    Then I should see heartbeat information:
      | Metric          | Type      |
      | Last Seen       | DateTime  |
      | Heartbeat Rate  | Integer   |
      | Missed Beats    | Integer   |
      | Status          | Enum      |
    And offline devices should be highlighted

  @P1 @devices @provisioning
  Scenario: Device provisioning workflow
    Given I click "Add Device"
    When I complete the provisioning wizard:
      | Step     | Action                |
      | 1        | Select device type    |
      | 2        | Configure connection  |
      | 3        | Set parameters        |
      | 4        | Test connectivity     |
      | 5        | Activate device       |
    Then the device should be provisioned
    And it should appear in the inventory

  # =============================================================================
  # SITES DOMAIN - SITE MANAGEMENT
  # =============================================================================

  @P0 @sites @hierarchy @puppeteer
  Scenario: Site hierarchy tree display
    Given I navigate to "/domains/sites"
    When the page loads
    Then I should see site hierarchy tree with:
      | Level      | Description      |
      | Region     | Geographic area  |
      | Zone       | Sub-region       |
      | Building   | Physical address |
      | Floor      | Building level   |
      | Room       | Specific area    |
    And Puppeteer screenshot "elixir_sites_hierarchy.png" should be captured

  @P1 @sites @mapping
  Scenario: Site-device mapping
    Given I select a site from the tree
    When viewing the site details
    Then I should see:
      | Panel            | Content            |
      | Devices          | Assigned devices   |
      | Alarms           | Active alarms      |
      | Subscribers      | Emergency contacts |
      | Compliance       | Certifications     |

  # =============================================================================
  # DISPATCH DOMAIN - RESPONSE COORDINATION
  # =============================================================================

  @P0 @dispatch @queue @puppeteer
  Scenario: Dispatch queue management
    Given I navigate to "/domains/dispatch"
    When the page loads
    Then I should see dispatch queues:
      | Queue     | Priority | SLA    |
      | Fire      | P0       | 30s    |
      | Medical   | P0       | 30s    |
      | Intrusion | P1       | 60s    |
      | Panic     | P1       | 60s    |
      | Technical | P2       | 300s   |
    And Puppeteer screenshot "elixir_dispatch_queues.png" should be captured

  @P0 @dispatch @routing
  Scenario: Dispatch routing rules
    Given I am on the dispatch dashboard
    When I view routing configuration
    Then I should see rules for:
      | Factor      | Description          |
      | Priority    | Alarm severity       |
      | Proximity   | Nearest responder    |
      | Skills      | Required competency  |
      | Availability| On-duty status       |
      | Load        | Current assignments  |

  @P1 @dispatch @tracking
  Scenario: Response tracking timeline
    Given a dispatch is active
    When I view the dispatch details
    Then I should see timeline events:
      | Event            | Timestamp |
      | Alarm Received   | T+0       |
      | Dispatch Created | T+5s      |
      | Acknowledged     | T+30s     |
      | Arrived          | T+10m     |
      | Resolved         | T+45m     |

  # =============================================================================
  # ANALYTICS DOMAIN - REPORTING
  # =============================================================================

  @P0 @analytics @dashboard @puppeteer
  Scenario: Analytics dashboard with KPIs
    Given I navigate to "/domains/analytics"
    When the page loads
    Then I should see KPI widgets for:
      | KPI                  | Type       |
      | Mean Time To Respond | Duration   |
      | False Alarm Rate     | Percentage |
      | Uptime               | Percentage |
      | Alarm Volume         | Count      |
      | Response Success     | Percentage |
    And Puppeteer screenshot "elixir_analytics_kpis.png" should be captured

  @P1 @analytics @reports @generation
  Scenario: Report generation
    Given I am on the analytics dashboard
    When I click "Generate Report"
    And I configure:
      | Option      | Value         |
      | Template    | Monthly Ops   |
      | Date Range  | Last 30 days  |
      | Format      | PDF           |
    Then report generation should start
    And progress should be displayed
    And download should be available when complete

  @P1 @analytics @trends @charts
  Scenario: Trend analysis charts
    Given I am on the analytics dashboard
    When I view trend analysis
    Then I should see interactive charts:
      | Chart Type    | Data               |
      | Line          | Alarm volume trend |
      | Bar           | Response times     |
      | Pie           | Alarm categories   |
      | Heatmap       | Hourly patterns    |

  # =============================================================================
  # COMPLIANCE DOMAIN - AUDIT & CERTIFICATION
  # =============================================================================

  @P0 @compliance @audit @puppeteer
  Scenario: Compliance audit trail
    Given I navigate to "/domains/compliance"
    When the page loads
    Then I should see audit trail with:
      | Column      | Type      |
      | Timestamp   | DateTime  |
      | Actor       | User      |
      | Action      | Enum      |
      | Resource    | String    |
      | Result      | Enum      |
      | IP Address  | String    |
    And Puppeteer screenshot "elixir_compliance_audit.png" should be captured

  @P0 @compliance @standards
  Scenario: Compliance standard tracking
    Given I am on the compliance dashboard
    When I view standards section
    Then I should see compliance status for:
      | Standard   | Status    |
      | IEC 61508  | Compliant |
      | ISO 27001  | Compliant |
      | EN 50131   | Compliant |
      | EN 50518   | Compliant |
      | GDPR       | Compliant |

  @P1 @compliance @evidence
  Scenario: Evidence collection management
    Given I am on the compliance dashboard
    When I click "Evidence Collection"
    Then I should see evidence items with:
      | Field          | Description        |
      | Evidence ID    | UUID               |
      | Category       | Standard section   |
      | Collected      | DateTime           |
      | Verified       | Boolean            |
      | Expiry         | DateTime           |

  # =============================================================================
  # OBSERVABILITY DOMAIN - MONITORING
  # =============================================================================

  @P0 @observability @metrics @puppeteer
  Scenario: Observability metrics dashboard
    Given I navigate to "/domains/observability"
    When the page loads
    Then I should see:
      | Panel          | Content              |
      | OTEL Traces    | Distributed tracing  |
      | Prometheus     | Metrics graphs       |
      | Loki           | Log aggregation      |
      | Zenoh          | Mesh telemetry       |
    And Puppeteer screenshot "elixir_observability.png" should be captured

  @P0 @observability @logs
  Scenario: Log viewer with search
    Given I am on the observability dashboard
    When I click "Logs"
    Then I should see log viewer with:
      | Feature       | Description        |
      | Search        | Full-text search   |
      | Filter        | Level, source      |
      | Time Range    | Date picker        |
      | Live Tail     | Real-time stream   |

  @P1 @observability @traces
  Scenario: Distributed trace visualization
    Given I am on the observability dashboard
    When I view a trace
    Then I should see:
      | Element      | Description          |
      | Span Tree    | Hierarchical view    |
      | Timeline     | Duration waterfall   |
      | Tags         | Span metadata        |
      | Logs         | Span events          |

  # =============================================================================
  # CLUSTER DOMAIN - DISTRIBUTED SYSTEM
  # =============================================================================

  @P0 @cluster @nodes @puppeteer
  Scenario: Cluster node status
    Given I navigate to "/domains/cluster"
    When the page loads
    Then I should see cluster nodes:
      | Node         | Status  | Role    |
      | app-1        | Up      | Primary |
      | app-2        | Up      | Replica |
      | app-3        | Up      | Replica |
    And Puppeteer screenshot "elixir_cluster_nodes.png" should be captured

  @P0 @cluster @consensus
  Scenario: Consensus status display
    Given I am on the cluster dashboard
    When I view consensus panel
    Then I should see:
      | Metric         | Value      |
      | Quorum Status  | Met        |
      | Leader Node    | app-1      |
      | Term           | Integer    |
      | Last Heartbeat | DateTime   |

  @P1 @cluster @rebalance
  Scenario: Cluster rebalance operation
    Given I am on the cluster dashboard
    When I click "Rebalance"
    Then rebalance wizard should appear
    And I should see:
      | Phase       | Status     |
      | Analyze     | Complete   |
      | Plan        | In Progress|
      | Execute     | Pending    |
      | Verify      | Pending    |

  # =============================================================================
  # SAFETY DOMAIN - SAFETY CRITICAL
  # =============================================================================

  @P0 @safety @constraints @puppeteer
  Scenario: Safety constraints dashboard
    Given I navigate to "/domains/safety"
    When the page loads
    Then I should see STAMP constraints:
      | Category    | Count |
      | SC-SIL6     | 15    |
      | SC-HOLON    | 20    |
      | SC-REG      | 15    |
      | SC-CONST    | 10    |
      | SC-BIO      | 8     |
    And constraint violations should be highlighted
    And Puppeteer screenshot "elixir_safety_constraints.png" should be captured

  @P0 @safety @fmea
  Scenario: FMEA dashboard display
    Given I am on the safety dashboard
    When I view FMEA analysis
    Then I should see failure modes with:
      | Column      | Type      |
      | Failure Mode| String    |
      | Severity    | 1-10      |
      | Occurrence  | 1-10      |
      | Detection   | 1-10      |
      | RPN         | Calculated|
      | Mitigation  | String    |
    And RPN > 100 should be highlighted red

  @P1 @safety @hazard_log
  Scenario: Hazard log management
    Given I am on the safety dashboard
    When I click "Hazard Log"
    Then I should see hazard entries with:
      | Field          | Description         |
      | Hazard ID      | Unique identifier   |
      | Description    | Hazard details      |
      | Risk Level     | Severity assessment |
      | Controls       | Mitigation measures |
      | Status         | Open/Mitigated      |

  # =============================================================================
  # INTEGRATION DOMAIN - EXTERNAL SYSTEMS
  # =============================================================================

  @P0 @integration @connectors @puppeteer
  Scenario: Integration connectors status
    Given I navigate to "/domains/integration"
    When the page loads
    Then I should see connector status for:
      | Connector     | Protocol | Status  |
      | SIA DC-09     | UDP/TCP  | Active  |
      | OSDP          | RS-485   | Active  |
      | ONVIF         | HTTP     | Active  |
      | BACnet        | UDP      | Active  |
      | Modbus        | TCP      | Active  |
    And Puppeteer screenshot "elixir_integrations.png" should be captured

  @P1 @integration @health
  Scenario: Integration health monitoring
    Given I am on the integration dashboard
    When viewing connector health
    Then I should see for each connector:
      | Metric          | Type      |
      | Messages/sec    | Rate      |
      | Error Rate      | Percentage|
      | Last Message    | DateTime  |
      | Queue Depth     | Integer   |

  # =============================================================================
  # LIVEVIEW INTERACTIONS - REAL-TIME
  # =============================================================================

  @P0 @liveview @push @realtime
  Scenario: LiveView server-push updates
    Given I am on any dashboard
    And a WebSocket connection is established
    When server-side data changes
    Then the UI should update within 100ms
    And no full page reload should occur
    And transition should be smooth

  @P0 @liveview @forms @validation
  Scenario: LiveView form with live validation
    Given I am filling out a form
    When I enter invalid data in a field
    Then validation error should appear immediately
    And the field should be highlighted
    And submit button should remain disabled

  @P1 @liveview @uploads
  Scenario: LiveView file uploads
    Given I am on a page with file upload
    When I select a file to upload
    Then upload progress should be displayed
    And upload should use chunked transfer
    And cancellation should be possible

  # =============================================================================
  # AUTHENTICATION & AUTHORIZATION
  # =============================================================================

  @P0 @auth @login @puppeteer
  Scenario: Login page functionality
    Given I navigate to "/login"
    When the page loads
    Then I should see:
      | Element        | Type      |
      | Email Field    | Input     |
      | Password Field | Password  |
      | Login Button   | Button    |
      | Forgot Link    | Link      |
    And Puppeteer screenshot "elixir_login.png" should be captured

  @P0 @auth @session
  Scenario: Session management
    Given I am logged in
    When my session expires
    Then I should be redirected to login
    And return URL should be preserved
    And session timeout should be configurable

  @P1 @auth @mfa
  Scenario: Multi-factor authentication
    Given I have MFA enabled
    When I login with correct credentials
    Then I should be prompted for MFA code
    And providing correct code should complete login
    And incorrect code should fail

  # =============================================================================
  # ERROR HANDLING
  # =============================================================================

  @P0 @error @500 @puppeteer
  Scenario: Server error handling
    Given the server encounters an error
    When the error page is displayed
    Then I should see a user-friendly error message
    And error details should be logged
    And a "Return Home" link should be available
    And Puppeteer screenshot "elixir_error_500.png" should be captured

  @P0 @error @404
  Scenario: Not found error handling
    Given I navigate to a non-existent page
    When the 404 page is displayed
    Then I should see "Page Not Found" message
    And navigation should remain available

  @P1 @error @timeout
  Scenario: Request timeout handling
    Given a request takes too long
    When the timeout threshold is reached
    Then I should see a timeout message
    And retry option should be available
    And the action should be logged
