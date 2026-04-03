@prajna @comprehensive @e2e @sil6
Feature: Prajna C3I Command Cockpit - Comprehensive End-to-End Coverage
  As an ARC operator using the Prajna C3I Command Center
  I need comprehensive control over all 26 LiveView pages
  So that I can manage the SIL-6 Biomorphic Fractal Mesh effectively

  STAMP Constraints:
    - SC-PRAJNA-001: All commands through Guardian pre-approval
    - SC-PRAJNA-002: Founder's Directive validation mandatory
    - SC-PRAJNA-003: State changes via Immutable Register
    - SC-PRAJNA-004: Sentinel health integration required
    - SC-PRAJNA-005: PROMETHEUS proof-token for mutations
    - SC-PRAJNA-006: Constitutional invariants checked
    - SC-PRAJNA-007: Two-step commit for destructive actions
    - SC-HMI-001: Status indicators visible within 1 second
    - SC-HMI-002: Critical alarms use 10-20 Hz flash rate
    - SC-HMI-003: Situational awareness maintained
    - SC-HMI-004: Fatigue mitigation through task rotation

  AOR Rules:
    - AOR-PRAJNA-001: Guardian Gate mandatory
    - AOR-PRAJNA-002: AI recommendations aligned to Founder's Directive
    - AOR-PRAJNA-003: State mutations logged to Immutable Register
    - AOR-PRAJNA-004: Sentinel sync every 30 seconds
    - AOR-PRAJNA-005: Two-step commit for destructive actions

  Background:
    Given Phoenix server is running on port 4000
    And I am authenticated as "operator" role
    And the HA mesh is deployed with 12 containers
    And Zenoh quorum is established with 3 routers
    And the WebSocket connection is established
    And Guardian is active and accepting proposals

  # ===========================================================================
  # SECTION 1: MAIN DASHBOARD & NAVIGATION (Prajna Index)
  # ===========================================================================

  @P0 @dashboard @navigation
  Scenario: Prajna Main Dashboard - Full Page Load
    When I navigate to "/prajna"
    Then I should see the main C3I dashboard
    And I should see the health score display showing percentage
    And I should see the threat level indicator
    And I should see the active agent count
    And I should see the navigation menu with all 26 pages
    And the page should load within 2000 milliseconds

  @P0 @dashboard @health
  Scenario: Main Dashboard - Real-Time Health Updates
    Given I am on the Prajna main dashboard
    When the system health changes from 95% to 87%
    Then I should see the health score update to 87%
    And the health indicator color should change to "warning"
    And a notification should appear for health degradation
    And the change should be logged to Immutable Register

  @P1 @dashboard @navigation
  Scenario: Navigation Menu - All Pages Accessible
    Given I am on the Prajna main dashboard
    Then I should see navigation links for:
      | Page                | URL                        |
      | Access Control      | /prajna/access_control     |
      | Alarms              | /prajna/alarms             |
      | Analytics           | /prajna/analytics          |
      | Cluster             | /prajna/cluster            |
      | Commands            | /prajna/commands           |
      | Compliance          | /prajna/compliance         |
      | Containers          | /prajna/containers         |
      | Copilot             | /prajna/copilot            |
      | Devices             | /prajna/devices            |
      | Diagnostics         | /prajna/diagnostics        |
      | Guardian            | /prajna/guardian_dashboard |
      | Knowledge           | /prajna/knowledge          |
      | Mesh                | /prajna/mesh               |
      | Observability       | /prajna/observability      |
      | Prometheus          | /prajna/prometheus         |
      | Register            | /prajna/register           |
      | Sentinel            | /prajna/sentinel_dashboard |
      | Settings            | /prajna/settings           |
      | Shutdown            | /prajna/shutdown           |
      | Startup             | /prajna/startup            |
      | Test Cockpit        | /prajna/test_cockpit       |
      | Topology            | /prajna/topology           |
      | Video               | /prajna/video              |

  # ===========================================================================
  # SECTION 2: ACCESS CONTROL PAGE
  # ===========================================================================

  @P0 @access_control @security
  Scenario: Access Control Page - Permission Audit Display
    When I navigate to "/prajna/access_control"
    Then I should see the permission audit panel
    And I should see the list of active sessions
    And I should see the role hierarchy display
    And I should see RBAC policy configuration

  @P0 @access_control @roles
  Scenario: Role Management - View All Roles
    Given I am on the Access Control page
    Then I should see the following roles:
      | Role        | Level | Permissions                    |
      | admin       | 10    | All permissions                |
      | operator    | 8     | Operations, monitoring, alarms |
      | supervisor  | 6     | View, acknowledge              |
      | viewer      | 4     | Read-only access               |
      | guest       | 2     | Limited dashboard view         |

  @P1 @access_control @sessions
  Scenario: Active Sessions - Monitor and Terminate
    Given I am on the Access Control page
    When I click on "Active Sessions" tab
    Then I should see a list of all active user sessions
    And each session should show:
      | Field          | Example Value              |
      | User           | operator@example.com       |
      | IP Address     | 192.168.1.100              |
      | Login Time     | 2026-01-10 08:00:00 UTC    |
      | Last Activity  | 2026-01-10 08:45:00 UTC    |
      | Session Token  | ses_xxxx...xxxx            |

  @P1 @access_control @audit
  Scenario: Permission Change Audit Trail
    Given I am on the Access Control page
    When I click on "Audit Trail" tab
    Then I should see a chronological log of permission changes
    And each entry should be signed with Ed25519
    And I should be able to filter by date range
    And I should be able to export the audit log

  # ===========================================================================
  # SECTION 3: ALARMS PAGE
  # ===========================================================================

  @P0 @alarms @critical
  Scenario: Alarms Page - Active Alarm Display
    When I navigate to "/prajna/alarms"
    Then I should see the active alarms panel
    And alarms should be sorted by severity (Critical > High > Medium > Low)
    And critical alarms should flash at 10-20 Hz (SC-HMI-002)
    And I should see alarm count by severity

  @P0 @alarms @lifecycle
  Scenario: Alarm Lifecycle - Receive and Acknowledge
    Given I am on the Alarms page
    When a new critical alarm "FIRE_ZONE_A" is received
    Then I should see the alarm appear in the active list
    And I should hear an audible alert
    And the alarm should show status "PENDING"
    When I click "Acknowledge" on the alarm
    Then the alarm status should change to "ACKNOWLEDGED"
    And the acknowledgment should be logged to Immutable Register
    And Guardian should be notified of the action

  @P0 @alarms @classification
  Scenario: Alarm Classification - SIA DC-09 Codes
    Given I am on the Alarms page
    Then I should see alarms classified by SIA codes:
      | SIA Code | Description         | Priority |
      | BA       | Burglar Alarm       | HIGH     |
      | FA       | Fire Alarm          | CRITICAL |
      | PA       | Panic Alarm         | CRITICAL |
      | HA       | Hold-up Alarm       | CRITICAL |
      | MA       | Medical Alert       | CRITICAL |
      | TA       | Technical Alarm     | MEDIUM   |
      | CA       | Communication Alarm | HIGH     |

  @P1 @alarms @storm
  Scenario: Alarm Storm Detection - Automatic Grouping
    Given I am on the Alarms page
    When more than 50 alarms arrive within 60 seconds
    Then the system should detect an alarm storm
    And alarms should be automatically grouped by source
    And a storm indicator should appear on the dashboard
    And the operator should be prompted for bulk acknowledgment

  @P1 @alarms @dispatch
  Scenario: Alarm Response - Dispatch Integration
    Given I am on the Alarms page
    And I have acknowledged alarm "INTRUSION_SECTOR_B"
    When I click "Dispatch Response"
    Then I should see the dispatch dialog
    And I should be able to select responders from the list
    And I should be able to add response notes
    When I confirm the dispatch
    Then the alarm status should change to "DISPATCHED"
    And the dispatch should be logged to Immutable Register

  @P1 @alarms @history
  Scenario: Alarm History - View Past Alarms
    Given I am on the Alarms page
    When I click on "History" tab
    Then I should see historical alarms with filters:
      | Filter       | Options                           |
      | Date Range   | Last 24h, 7d, 30d, Custom         |
      | Severity     | Critical, High, Medium, Low, All  |
      | Status       | Resolved, Acknowledged, Pending   |
      | SIA Code     | BA, FA, PA, HA, MA, TA, CA, All   |
    And I should be able to export history to CSV

  # ===========================================================================
  # SECTION 4: ANALYTICS PAGE
  # ===========================================================================

  @P0 @analytics @reports
  Scenario: Analytics Page - Dashboard Display
    When I navigate to "/prajna/analytics"
    Then I should see the analytics dashboard
    And I should see the following widgets:
      | Widget              | Content                    |
      | Alarm Trends        | 7-day trend chart          |
      | Response Times      | Average/P95/P99 metrics    |
      | SLA Compliance      | Percentage gauge           |
      | Operator Metrics    | Performance breakdown      |
      | System Health       | Uptime and availability    |

  @P1 @analytics @sla
  Scenario: SLA Compliance - EN 50518 Monitoring
    Given I am on the Analytics page
    When I view the SLA Compliance section
    Then I should see compliance metrics for:
      | Standard    | Requirement              | Status    |
      | EN 50518    | Alarm response < 60s     | COMPLIANT |
      | EN 50518    | Acknowledgment < 180s    | COMPLIANT |
      | EN 50518    | Resolution tracking      | COMPLIANT |
      | ISO 27001   | Audit trail retention    | COMPLIANT |
    And non-compliant items should be highlighted in red

  @P1 @analytics @reports
  Scenario: Report Generation - Automated Reports
    Given I am on the Analytics page
    When I click "Generate Report"
    Then I should see report configuration options:
      | Option        | Values                          |
      | Report Type   | Daily, Weekly, Monthly, Custom  |
      | Format        | PDF, Excel, CSV                 |
      | Recipients    | Email distribution list         |
      | Schedule      | Immediate, Scheduled            |
    When I generate a Daily PDF report
    Then the report should be created and available for download

  # ===========================================================================
  # SECTION 5: CLUSTER PAGE
  # ===========================================================================

  @P0 @cluster @status
  Scenario: Cluster Page - Node Status Display
    When I navigate to "/prajna/cluster"
    Then I should see the cluster topology
    And I should see all cluster nodes:
      | Node        | Type     | Status  |
      | app-node-1  | Primary  | HEALTHY |
      | app-node-2  | Replica  | HEALTHY |
      | app-node-3  | Replica  | HEALTHY |
    And I should see the current leader node indicated

  @P0 @cluster @failover
  Scenario: Cluster Failover - Automatic Leader Election
    Given I am on the Cluster page
    When the primary node "app-node-1" goes offline
    Then I should see the node status change to "OFFLINE"
    And I should see leader election in progress
    And a new leader should be elected within 5 seconds
    And the cluster should show "DEGRADED" status
    And all operations should continue on remaining nodes

  @P1 @cluster @scaling
  Scenario: Cluster Scaling - Add/Remove Nodes
    Given I am on the Cluster page with admin permissions
    When I click "Scale Cluster"
    Then I should see scaling options:
      | Action        | Description                     |
      | Add Node      | Add new replica node            |
      | Remove Node   | Gracefully remove a node        |
      | Rebalance     | Redistribute workload           |
    And scaling operations require Guardian approval

  # ===========================================================================
  # SECTION 6: COMMANDS PAGE
  # ===========================================================================

  @P0 @commands @guardian
  Scenario: Commands Page - Guardian-Approved Execution
    When I navigate to "/prajna/commands"
    Then I should see the command console
    And I should see the list of available commands
    And all commands should require Guardian pre-approval (SC-PRAJNA-001)

  @P0 @commands @execution
  Scenario: Command Execution - Two-Step Commit
    Given I am on the Commands page
    When I select command "restart-service" with target "app-node-1"
    Then I should see the command preview
    And I should see the 5-order effects analysis
    When I click "Request Approval"
    Then Guardian should receive the proposal
    When Guardian approves the command
    Then I should see "Approved" status
    When I click "Execute"
    Then the command should be executed
    And the execution should be logged to Immutable Register

  @P1 @commands @dangerous
  Scenario: Dangerous Commands - Enhanced Confirmation
    Given I am on the Commands page
    When I select a dangerous command "shutdown-mesh"
    Then I should see a warning banner
    And I should be required to type the confirmation phrase
    And the command should require two-step commit (SC-PRAJNA-007)
    And Guardian approval timeout should be extended to 5 minutes

  # ===========================================================================
  # SECTION 7: COMPLIANCE PAGE
  # ===========================================================================

  @P0 @compliance @audit
  Scenario: Compliance Page - Audit Dashboard
    When I navigate to "/prajna/compliance"
    Then I should see the compliance dashboard
    And I should see audit status for:
      | Standard    | Status    | Last Audit     |
      | EN 50518    | COMPLIANT | 2026-01-09     |
      | ISO 27001   | COMPLIANT | 2026-01-05     |
      | GDPR        | COMPLIANT | 2026-01-08     |
      | IEC 61508   | COMPLIANT | 2026-01-07     |

  @P1 @compliance @evidence
  Scenario: Compliance Evidence - Document Repository
    Given I am on the Compliance page
    When I click on "Evidence Repository"
    Then I should see a list of compliance evidence documents
    And each document should have:
      | Field             | Description                    |
      | Document ID       | Unique identifier              |
      | Title             | Document name                  |
      | Standard          | Related compliance standard    |
      | Upload Date       | When uploaded                  |
      | Verified By       | Auditor signature              |
      | Hash              | SHA-256 integrity hash         |

  @P1 @compliance @gaps
  Scenario: Compliance Gap Analysis
    Given I am on the Compliance page
    When I click "Run Gap Analysis"
    Then the system should analyze all compliance requirements
    And I should see a gap report with:
      | Gap Type    | Count | Severity |
      | Critical    | 0     | RED      |
      | Major       | 2     | ORANGE   |
      | Minor       | 5     | YELLOW   |
      | Observation | 12    | BLUE     |

  # ===========================================================================
  # SECTION 8: CONTAINERS PAGE
  # ===========================================================================

  @P0 @containers @status
  Scenario: Containers Page - Container Status Display
    When I navigate to "/prajna/containers"
    Then I should see all 12 containers:
      | Container            | Image                    | Status  | Ports       |
      | haproxy              | haproxy:3.1              | HEALTHY | 80, 443     |
      | indrajaal-app-1      | indrajaal-app:latest     | HEALTHY | 4001        |
      | indrajaal-app-2      | indrajaal-app:latest     | HEALTHY | 4002        |
      | indrajaal-app-3      | indrajaal-app:latest     | HEALTHY | 4003        |
      | indrajaal-db-prod    | postgres:17              | HEALTHY | 5433        |
      | indrajaal-obs-prod   | grafana/otel:latest      | HEALTHY | 4317        |
      | zenoh-router-1       | eclipse/zenoh:latest     | HEALTHY | 7447        |
      | zenoh-router-2       | eclipse/zenoh:latest     | HEALTHY | 7448        |
      | zenoh-router-3       | eclipse/zenoh:latest     | HEALTHY | 7449        |
      | redis                | redis:7                  | HEALTHY | 6379        |
      | loki                 | grafana/loki:latest      | HEALTHY | 3100        |
      | prometheus           | prom/prometheus:latest   | HEALTHY | 9090        |

  @P0 @containers @health
  Scenario: Container Health - Real-Time Monitoring
    Given I am on the Containers page
    Then each container should display:
      | Metric       | Description                    |
      | CPU Usage    | Percentage of allocated CPU    |
      | Memory       | Used / Allocated memory        |
      | Network I/O  | Bytes in/out per second        |
      | Disk I/O     | Read/Write operations          |
      | Restarts     | Restart count                  |

  @P1 @containers @lifecycle
  Scenario: Container Lifecycle - Stop and Start
    Given I am on the Containers page
    When I select container "indrajaal-app-1"
    And I click "Stop Container"
    Then I should see a confirmation dialog
    When I confirm the action
    Then Guardian should approve the request
    And the container status should change to "STOPPING"
    And then to "STOPPED"
    When I click "Start Container"
    And Guardian approves
    Then the container should start within 30 seconds
    And status should change to "HEALTHY"

  @P1 @containers @logs
  Scenario: Container Logs - Real-Time Streaming
    Given I am on the Containers page
    When I click "Logs" for container "indrajaal-app-1"
    Then I should see a log viewer panel
    And logs should stream in real-time
    And I should be able to filter by log level:
      | Level   | Color  |
      | DEBUG   | Gray   |
      | INFO    | White  |
      | WARNING | Yellow |
      | ERROR   | Red    |
      | FATAL   | Red BG |

  # ===========================================================================
  # SECTION 9: COPILOT PAGE (AI ASSISTANT)
  # ===========================================================================

  @P0 @copilot @chat
  Scenario: Copilot Page - AI Chat Interface
    When I navigate to "/prajna/copilot"
    Then I should see the AI Copilot chat interface
    And I should see the Founder's Directive alignment indicator
    And I should see the conversation history panel
    And I should see the recommendation sidebar

  @P0 @copilot @recommendations
  Scenario: Copilot Recommendations - Aligned to Founder's Directive
    Given I am on the Copilot page
    When I ask "What should I prioritize right now?"
    Then the Copilot should analyze current system state
    And recommendations should be aligned to Ω₀ (Founder's Directive)
    And each recommendation should show:
      | Field            | Description                     |
      | Priority         | P0/P1/P2                        |
      | Action           | Suggested action                |
      | Rationale        | Why this aligns with Ω₀         |
      | Risk Score       | Potential risk assessment       |
      | Expected Outcome | Anticipated result              |

  @P1 @copilot @alarm_assist
  Scenario: Copilot - Alarm Handling Assistance
    Given I am on the Copilot page
    And there is an active alarm "INTRUSION_ZONE_C"
    When I ask "Help me handle the intrusion alarm"
    Then the Copilot should provide:
      | Step | Action                           |
      | 1    | Verify alarm authenticity        |
      | 2    | Check subscriber contact info    |
      | 3    | Attempt verification call        |
      | 4    | Dispatch response if confirmed   |
      | 5    | Document resolution              |

  @P1 @copilot @training
  Scenario: Copilot - Operator Training Mode
    Given I am on the Copilot page
    When I click "Enter Training Mode"
    Then I should see simulated scenarios
    And my responses should be scored
    And the Copilot should provide feedback
    And training progress should be tracked

  # ===========================================================================
  # SECTION 10: DEVICES PAGE
  # ===========================================================================

  @P0 @devices @inventory
  Scenario: Devices Page - Device Inventory Display
    When I navigate to "/prajna/devices"
    Then I should see the device inventory dashboard
    And I should see device counts by type:
      | Type           | Count | Healthy | Warning | Offline |
      | Panels         | 150   | 145     | 3       | 2       |
      | Sensors        | 500   | 485     | 10      | 5       |
      | Cameras        | 200   | 195     | 3       | 2       |
      | Access Points  | 50    | 48      | 1       | 1       |

  @P0 @devices @health
  Scenario: Device Health Matrix - Real-Time Status
    Given I am on the Devices page
    Then I should see a health matrix showing:
      | Status    | Indicator | Meaning                   |
      | ONLINE    | Green     | Device responding         |
      | WARNING   | Yellow    | Device degraded           |
      | OFFLINE   | Red       | Device not responding     |
      | UNKNOWN   | Gray      | Status unknown            |

  @P1 @devices @details
  Scenario: Device Details - Individual Device View
    Given I am on the Devices page
    When I click on device "PANEL-001"
    Then I should see device details:
      | Field              | Value                     |
      | Device ID          | PANEL-001                 |
      | Type               | Alarm Panel               |
      | Manufacturer       | Honeywell                 |
      | Model              | Vista-128BPT              |
      | Firmware           | 4.3.2                     |
      | Last Communication | 2026-01-10 08:55:00 UTC   |
      | Signal Strength    | -45 dBm                   |
      | Battery Level      | 85%                       |

  @P1 @devices @commands
  Scenario: Device Commands - Remote Operations
    Given I am on the Devices page
    And I have selected device "PANEL-001"
    When I click "Send Command"
    Then I should see available commands:
      | Command        | Description                    |
      | Test           | Request panel test signal      |
      | Reset          | Reset panel to default state   |
      | Arm            | Arm the panel                  |
      | Disarm         | Disarm the panel               |
      | Firmware Update| Initiate firmware update       |
    And all commands require Guardian approval

  # ===========================================================================
  # SECTION 11: DIAGNOSTICS PAGE
  # ===========================================================================

  @P0 @diagnostics @system
  Scenario: Diagnostics Page - System Health Overview
    When I navigate to "/prajna/diagnostics"
    Then I should see the diagnostics dashboard
    And I should see system health checks:
      | Component       | Status  | Details                    |
      | Database        | HEALTHY | PostgreSQL 17, latency 2ms |
      | Zenoh Mesh      | HEALTHY | 3/3 routers connected      |
      | OTEL Collector  | HEALTHY | Traces flowing             |
      | Redis Cache     | HEALTHY | Memory 45% used            |
      | NIF Bridge      | HEALTHY | Zenoh NIF loaded           |

  @P0 @diagnostics @connectivity
  Scenario: Connectivity Tests - Network Diagnostics
    Given I am on the Diagnostics page
    When I click "Run Connectivity Tests"
    Then the system should test:
      | Test                    | Target                  | Expected |
      | Database Connection     | indrajaal-db-prod:5433  | < 10ms   |
      | Zenoh Mesh Latency      | zenoh-router-1:7447     | < 5ms    |
      | External API            | api.external.com        | < 100ms  |
      | DNS Resolution          | google.com              | < 50ms   |
    And results should be displayed in real-time

  @P1 @diagnostics @logs
  Scenario: Log Analysis - Automated Pattern Detection
    Given I am on the Diagnostics page
    When I click "Analyze Logs"
    Then the system should scan recent logs
    And identify patterns:
      | Pattern Type    | Count | Severity |
      | Error Spikes    | 3     | HIGH     |
      | Slow Queries    | 15    | MEDIUM   |
      | Memory Pressure | 2     | MEDIUM   |
      | Connection Drops| 5     | LOW      |

  # ===========================================================================
  # SECTION 12: GUARDIAN DASHBOARD PAGE
  # ===========================================================================

  @P0 @guardian @dashboard
  Scenario: Guardian Dashboard - Proposal Queue Display
    When I navigate to "/prajna/guardian_dashboard"
    Then I should see the Guardian approval queue
    And I should see pending proposals with:
      | Field          | Description                    |
      | Proposal ID    | Unique identifier              |
      | Requested By   | User who requested             |
      | Action         | What action is proposed        |
      | Target         | Affected system component      |
      | Risk Level     | LOW/MEDIUM/HIGH/CRITICAL       |
      | Submitted      | Timestamp                      |
      | Expires        | When proposal expires          |

  @P0 @guardian @approval
  Scenario: Guardian Approval - Approve a Proposal
    Given I am on the Guardian Dashboard
    And there is a pending proposal "PROP-001"
    When I click "View Details" on the proposal
    Then I should see:
      | Section              | Content                        |
      | Action Description   | Restart container app-node-1   |
      | 5-Order Effects      | Impact analysis                |
      | Rollback Plan        | Recovery procedure             |
      | Constitutional Check | Ψ₀-Ψ₅ compliance status        |
    When I click "Approve"
    Then the proposal status should change to "APPROVED"
    And the approval should be logged to Immutable Register

  @P0 @guardian @veto
  Scenario: Guardian Veto - Reject a Proposal
    Given I am on the Guardian Dashboard
    And there is a pending proposal "PROP-002"
    When I click "View Details" on the proposal
    And I see the proposal violates SC-CONST-005 (Founder's Directive)
    When I click "Veto" with reason "Violates Founder's Directive"
    Then the proposal status should change to "VETOED"
    And the requestor should be notified
    And the veto should be logged to Immutable Register

  @P1 @guardian @constitutional
  Scenario: Constitutional Invariant Verification
    Given I am on the Guardian Dashboard
    When I view any proposal
    Then I should see constitutional compliance status:
      | Invariant | Name              | Status    |
      | Ψ₀        | Existence         | COMPLIANT |
      | Ψ₁        | Regeneration      | COMPLIANT |
      | Ψ₂        | History           | COMPLIANT |
      | Ψ₃        | Verification      | COMPLIANT |
      | Ψ₄        | Human Alignment   | COMPLIANT |
      | Ψ₅        | Truthfulness      | COMPLIANT |

  # ===========================================================================
  # SECTION 13: KNOWLEDGE PAGE
  # ===========================================================================

  @P0 @knowledge @base
  Scenario: Knowledge Page - Knowledge Base Dashboard
    When I navigate to "/prajna/knowledge"
    Then I should see the knowledge base dashboard
    And I should see knowledge categories:
      | Category      | Articles | Last Updated      |
      | Product       | 150      | 2026-01-09        |
      | SRE           | 85       | 2026-01-08        |
      | Developer     | 200      | 2026-01-10        |
      | Operations    | 120      | 2026-01-07        |

  @P1 @knowledge @product
  Scenario: Product Knowledge - Articles Display
    Given I am on the Knowledge page
    When I click on "Product" category
    Then I should be navigated to "/prajna/knowledge/product"
    And I should see product-related articles
    And I should be able to search articles
    And I should be able to filter by tags

  @P1 @knowledge @sre
  Scenario: SRE Knowledge - Runbooks Display
    Given I am on the Knowledge page
    When I click on "SRE" category
    Then I should be navigated to "/prajna/knowledge/sre"
    And I should see SRE runbooks:
      | Runbook                  | Type       | Last Run    |
      | Incident Response        | Procedure  | 2026-01-09  |
      | Failover Procedure       | Procedure  | 2026-01-05  |
      | Performance Tuning       | Guide      | 2026-01-03  |
      | Capacity Planning        | Analysis   | 2026-01-01  |

  @P1 @knowledge @developer
  Scenario: Developer Knowledge - API Documentation
    Given I am on the Knowledge page
    When I click on "Developer" category
    Then I should be navigated to "/prajna/knowledge/developer"
    And I should see API documentation
    And I should see code examples
    And I should see integration guides

  # ===========================================================================
  # SECTION 14: MESH PAGE
  # ===========================================================================

  @P0 @mesh @status
  Scenario: Mesh Page - Zenoh Mesh Status Display
    When I navigate to "/prajna/mesh"
    Then I should see the Zenoh mesh topology
    And I should see mesh nodes:
      | Node           | Role      | Status  | Latency |
      | zenoh-router-1 | Router    | HEALTHY | 2ms     |
      | zenoh-router-2 | Router    | HEALTHY | 3ms     |
      | zenoh-router-3 | Router    | HEALTHY | 2ms     |
    And I should see mesh connections graph

  @P0 @mesh @quorum
  Scenario: Mesh Quorum - Consensus Status
    Given I am on the Mesh page
    Then I should see quorum status:
      | Metric         | Value  | Threshold |
      | Active Nodes   | 3      | >= 2      |
      | Quorum         | 2      | N/2 + 1   |
      | Consensus      | ACTIVE | ACTIVE    |
      | Leader         | router-1| Elected  |

  @P1 @mesh @pubsub
  Scenario: Mesh Pub/Sub - Topic Monitoring
    Given I am on the Mesh page
    When I click "Pub/Sub Monitor"
    Then I should see active topics:
      | Topic                    | Publishers | Subscribers | Rate    |
      | prajna/kpi/health        | 3          | 5           | 10/s    |
      | prajna/alerts/**         | 10         | 20          | 5/s     |
      | prajna/metrics/**        | 50         | 10          | 100/s   |
      | indrajaal/test/evolution | 1          | 3           | 1/s     |

  @P1 @mesh @failover
  Scenario: Mesh Failover - Router Failure Recovery
    Given I am on the Mesh page
    When router "zenoh-router-1" goes offline
    Then I should see the router status change to "OFFLINE"
    And remaining routers should maintain quorum
    And traffic should automatically reroute
    And I should see a mesh reconfiguration event

  # ===========================================================================
  # SECTION 15: OBSERVABILITY PAGE
  # ===========================================================================

  @P0 @observability @dashboard
  Scenario: Observability Page - Metrics Dashboard
    When I navigate to "/prajna/observability"
    Then I should see the observability dashboard
    And I should see integration status for:
      | Component    | Status  | Endpoint               |
      | OTEL         | ACTIVE  | localhost:4317         |
      | Prometheus   | ACTIVE  | localhost:9090         |
      | Grafana      | ACTIVE  | localhost:3000         |
      | Loki         | ACTIVE  | localhost:3100         |

  @P0 @observability @traces
  Scenario: Distributed Traces - Trace Viewer
    Given I am on the Observability page
    When I click "Traces"
    Then I should see recent traces
    And I should be able to filter by:
      | Filter       | Options                     |
      | Service      | app, db, zenoh              |
      | Duration     | > 100ms, > 500ms, > 1s      |
      | Status       | OK, ERROR                   |
      | Time Range   | Last 1h, 6h, 24h, Custom    |

  @P1 @observability @metrics
  Scenario: Metrics Explorer - Custom Queries
    Given I am on the Observability page
    When I click "Metrics Explorer"
    Then I should be able to query Prometheus metrics
    And I should see predefined dashboards:
      | Dashboard        | Metrics                     |
      | System Health    | CPU, Memory, Disk, Network  |
      | Application      | Requests, Latency, Errors   |
      | Database         | Queries, Connections, Locks |
      | Zenoh            | Messages, Latency, Nodes    |

  @P1 @observability @logs
  Scenario: Log Aggregation - Loki Integration
    Given I am on the Observability page
    When I click "Logs"
    Then I should see aggregated logs from all services
    And I should be able to use LogQL queries
    And I should see log labels:
      | Label       | Values                      |
      | service     | app, db, zenoh, obs         |
      | level       | debug, info, warn, error    |
      | container   | app-1, app-2, app-3, etc    |

  # ===========================================================================
  # SECTION 16: PROMETHEUS PAGE
  # ===========================================================================

  @P0 @prometheus @verification
  Scenario: Prometheus Page - Proof Token Display
    When I navigate to "/prajna/prometheus"
    Then I should see the PROMETHEUS verification dashboard
    And I should see recent proof tokens:
      | Token ID     | Action           | Status   | Timestamp          |
      | PROM-001     | restart-service  | VERIFIED | 2026-01-10 08:00   |
      | PROM-002     | scale-cluster    | VERIFIED | 2026-01-10 07:45   |
      | PROM-003     | update-config    | PENDING  | 2026-01-10 08:55   |

  @P0 @prometheus @constraints
  Scenario: Prometheus Constraints - Safety Verification
    Given I am on the Prometheus page
    Then I should see constraint status:
      | Constraint    | Description                   | Status    |
      | SC-PROM-001   | Proof token required          | ENFORCED  |
      | SC-PROM-002   | API safety redline < 95%      | COMPLIANT |
      | SC-PROM-003   | Dashboard liveness            | ACTIVE    |
      | SC-PROM-004   | Graph acyclicity              | VERIFIED  |

  @P1 @prometheus @audit
  Scenario: Prometheus Audit - Verification History
    Given I am on the Prometheus page
    When I click "Audit Trail"
    Then I should see all verification events
    And each event should be cryptographically signed
    And I should be able to verify signatures

  # ===========================================================================
  # SECTION 17: REGISTER PAGE (IMMUTABLE REGISTER)
  # ===========================================================================

  @P0 @register @blockchain
  Scenario: Register Page - Blockchain Display
    When I navigate to "/prajna/register"
    Then I should see the Immutable Register dashboard
    And I should see the latest blocks:
      | Block   | Hash (first 8)   | Timestamp          | Type          |
      | 12345   | 0xAF42B3C1       | 2026-01-10 08:55   | STATE_CHANGE  |
      | 12344   | 0x1B2C3D4E       | 2026-01-10 08:50   | APPROVAL      |
      | 12343   | 0x5E6F7A8B       | 2026-01-10 08:45   | EVOLUTION     |

  @P0 @register @integrity
  Scenario: Register Integrity - Chain Verification
    Given I am on the Register page
    When I click "Verify Chain"
    Then the system should verify all block hashes
    And I should see verification result:
      | Metric              | Value     |
      | Total Blocks        | 12345     |
      | Verified            | 12345     |
      | Chain Integrity     | VERIFIED  |
      | Merkle Root         | 0x...     |
      | Last Verified       | Now       |

  @P1 @register @blocks
  Scenario: Register Block Details - View Block Content
    Given I am on the Register page
    When I click on block "12345"
    Then I should see block details:
      | Field           | Value                        |
      | Block Number    | 12345                        |
      | Previous Hash   | 0x1B2C3D4E...                |
      | Current Hash    | 0xAF42B3C1...                |
      | Merkle Root     | 0x9A8B7C6D...                |
      | Timestamp       | 2026-01-10T08:55:00Z         |
      | Type            | STATE_CHANGE                 |
      | Signature       | Ed25519 signature            |
      | Content         | JSON payload                 |

  @P1 @register @search
  Scenario: Register Search - Find Specific Events
    Given I am on the Register page
    When I enter search query "restart-service"
    Then I should see matching blocks
    And I should be able to filter by:
      | Filter     | Options                          |
      | Type       | STATE_CHANGE, APPROVAL, EVOLUTION|
      | Date       | Date range picker                |
      | Actor      | User or system identifier        |

  # ===========================================================================
  # SECTION 18: SENTINEL DASHBOARD PAGE
  # ===========================================================================

  @P0 @sentinel @health
  Scenario: Sentinel Dashboard - System Health Display
    When I navigate to "/prajna/sentinel_dashboard"
    Then I should see the Sentinel health dashboard
    And I should see health metrics:
      | Metric             | Value   | Status  |
      | Overall Health     | 97%     | HEALTHY |
      | CPU Utilization    | 45%     | NORMAL  |
      | Memory Pressure    | 60%     | NORMAL  |
      | Disk I/O           | 25%     | NORMAL  |
      | Network Latency    | 5ms     | NORMAL  |

  @P0 @sentinel @threats
  Scenario: Sentinel Threats - Active Threat Display
    Given I am on the Sentinel Dashboard
    When I view the threats panel
    Then I should see active threats with:
      | Field           | Description                    |
      | Threat ID       | Unique identifier              |
      | Classification  | Threat type                    |
      | Severity        | CRITICAL/HIGH/MEDIUM/LOW       |
      | Source          | Origin of threat               |
      | Detected At     | Timestamp                      |
      | Status          | ACTIVE/MITIGATED/RESOLVED      |

  @P1 @sentinel @immune
  Scenario: Digital Immune System - PatternHunter Status
    Given I am on the Sentinel Dashboard
    When I click "Immune System"
    Then I should see immune system status:
      | Component        | Status  | Last Action              |
      | PatternHunter    | ACTIVE  | Scanning (10ms ago)      |
      | SymbioticDefense | ACTIVE  | No threats detected      |
      | Mara             | STANDBY | Chaos test scheduled     |
      | Antibody         | ACTIVE  | 5 antibodies generated   |

  @P1 @sentinel @alerts
  Scenario: Sentinel Alerts - Threshold Configuration
    Given I am on the Sentinel Dashboard
    When I click "Alert Configuration"
    Then I should see alert thresholds:
      | Metric          | Warning | Critical | Current |
      | CPU Usage       | 70%     | 90%      | 45%     |
      | Memory Usage    | 75%     | 85%      | 60%     |
      | Error Rate      | 1%      | 5%       | 0.1%    |
      | Response Time   | 100ms   | 500ms    | 15ms    |

  # ===========================================================================
  # SECTION 19: SETTINGS PAGE
  # ===========================================================================

  @P0 @settings @config
  Scenario: Settings Page - Configuration Display
    When I navigate to "/prajna/settings"
    Then I should see the settings dashboard
    And I should see configuration categories:
      | Category          | Items                          |
      | General           | Language, Timezone, Theme      |
      | Notifications     | Email, SMS, Push, Webhooks     |
      | Security          | 2FA, Session Timeout, IP Rules |
      | Display           | Dashboard Layout, Refresh Rate |
      | Integration       | API Keys, Webhooks, LDAP       |

  @P1 @settings @user
  Scenario: User Settings - Profile Configuration
    Given I am on the Settings page
    When I click "User Profile"
    Then I should see my profile settings:
      | Setting           | Value                          |
      | Email             | operator@example.com           |
      | Name              | Operator Name                  |
      | Role              | operator                       |
      | 2FA               | Enabled                        |
      | Timezone          | UTC                            |
      | Theme             | Dark                           |

  @P1 @settings @notifications
  Scenario: Notification Settings - Channel Configuration
    Given I am on the Settings page
    When I click "Notifications"
    Then I should see notification channels:
      | Channel   | Status  | Configuration         |
      | Email     | ACTIVE  | operator@example.com  |
      | SMS       | ACTIVE  | +1-555-0100           |
      | Push      | ACTIVE  | Browser enabled       |
      | Slack     | ACTIVE  | #alerts channel       |
      | Webhook   | ACTIVE  | https://webhook.url   |

  # ===========================================================================
  # SECTION 20: SHUTDOWN PAGE
  # ===========================================================================

  @P0 @shutdown @apoptosis
  Scenario: Shutdown Page - Apoptosis Protocol Display
    When I navigate to "/prajna/shutdown"
    Then I should see the Apoptosis Protocol dashboard
    And I should see the 6-phase shutdown sequence:
      | Phase        | Status    | Duration |
      | Initiated    | READY     | 0s       |
      | Notifying    | PENDING   | 5s       |
      | Draining     | PENDING   | 30s      |
      | Checkpointing| PENDING   | 60s      |
      | Terminating  | PENDING   | 10s      |
      | Terminated   | PENDING   | 0s       |

  @P0 @shutdown @controlled
  Scenario: Controlled Shutdown - Execute Apoptosis
    Given I am on the Shutdown page
    When I click "Initiate Controlled Shutdown"
    Then I should see a confirmation dialog
    And I should be required to provide shutdown reason
    When I confirm with reason "Scheduled maintenance"
    Then Guardian should receive the shutdown proposal
    When Guardian approves
    Then the Apoptosis protocol should begin
    And I should see each phase transition in real-time

  @P1 @shutdown @emergency
  Scenario: Emergency Stop - Force Shutdown
    Given I am on the Shutdown page
    When I click "Emergency Stop"
    Then I should see emergency stop warning
    And I should be required to type "EMERGENCY STOP"
    When I confirm with the phrase
    Then the system should stop within 5 seconds (SC-EMR-057)
    And the emergency stop should be logged

  # ===========================================================================
  # SECTION 21: STARTUP PAGE
  # ===========================================================================

  @P0 @startup @boot
  Scenario: Startup Page - Boot Sequence Display
    When I navigate to "/prajna/startup"
    Then I should see the boot sequence dashboard
    And I should see the 5-stage boot process:
      | Stage        | Status    | Duration |
      | Preflight    | COMPLETE  | 5s       |
      | Ignition     | COMPLETE  | 10s      |
      | Lens         | COMPLETE  | 15s      |
      | Convergence  | COMPLETE  | 20s      |
      | Ready        | ACTIVE    | 0s       |

  @P0 @startup @initiate
  Scenario: Initiate Startup - Begin Boot Sequence
    Given I am on the Startup page
    And the system is in STOPPED state
    When I click "Initiate Startup"
    Then Guardian should approve the startup
    And the boot sequence should begin
    And I should see each stage progress in real-time:
      | Stage        | Actions                              |
      | Preflight    | Verify dependencies, check ports     |
      | Ignition     | Start containers, establish networks |
      | Lens         | Configure instrumentation            |
      | Convergence  | Achieve Zenoh quorum                 |
      | Ready        | OODA loop active, accepting requests |

  @P1 @startup @diagnostics
  Scenario: Startup Diagnostics - Pre-Boot Checks
    Given I am on the Startup page
    When I click "Run Pre-Boot Diagnostics"
    Then the system should check:
      | Check              | Status  | Details                |
      | Port Availability  | PASS    | 4000, 5433, 4317 free  |
      | Disk Space         | PASS    | 50GB available         |
      | Memory Available   | PASS    | 16GB available         |
      | Dependencies       | PASS    | All containers present |
      | Configuration      | PASS    | Config files valid     |

  # ===========================================================================
  # SECTION 22: TEST COCKPIT PAGE
  # ===========================================================================

  @P0 @test_cockpit @status
  Scenario: Test Cockpit Page - Test Suite Display
    When I navigate to "/prajna/test_cockpit"
    Then I should see the test cockpit dashboard
    And I should see test suite status:
      | Suite              | Tests | Passed | Failed | Skipped |
      | Unit Tests         | 5000  | 4998   | 2      | 0       |
      | Integration Tests  | 2000  | 1995   | 5      | 0       |
      | Property Tests     | 1000  | 1000   | 0      | 0       |
      | E2E Tests          | 500   | 495    | 5      | 0       |

  @P0 @test_cockpit @run
  Scenario: Run Tests - Execute Test Suite
    Given I am on the Test Cockpit page
    When I click "Run All Tests"
    Then I should see test execution progress
    And I should see real-time results streaming
    And I should see coverage metrics updating
    And the final result should include:
      | Metric        | Value  |
      | Total Tests   | 8500   |
      | Pass Rate     | 99.8%  |
      | Coverage      | 95.5%  |
      | Duration      | 5m 32s |

  @P1 @test_cockpit @coverage
  Scenario: Coverage Report - View Code Coverage
    Given I am on the Test Cockpit page
    When I click "Coverage Report"
    Then I should see coverage breakdown by module
    And I should see coverage by domain:
      | Domain         | Coverage |
      | Access         | 98%      |
      | Alarms         | 95%      |
      | Analytics      | 92%      |
      | Compliance     | 97%      |
      | Devices        | 94%      |

  # ===========================================================================
  # SECTION 23: TOPOLOGY PAGE
  # ===========================================================================

  @P0 @topology @graph
  Scenario: Topology Page - System Topology Display
    When I navigate to "/prajna/topology"
    Then I should see the system topology graph
    And I should see nodes for:
      | Node Type     | Count | Visualization        |
      | App Nodes     | 3     | Blue circles         |
      | DB Nodes      | 1     | Green rectangle      |
      | Zenoh Routers | 3     | Orange diamonds      |
      | Load Balancer | 1     | Purple hexagon       |
    And I should see connections between nodes

  @P0 @topology @interactive
  Scenario: Interactive Topology - Node Selection
    Given I am on the Topology page
    When I click on a node "app-node-1"
    Then I should see node details panel
    And I should see:
      | Field          | Value                      |
      | Node ID        | app-node-1                 |
      | Type           | Application                |
      | IP Address     | 10.0.0.11                  |
      | Status         | HEALTHY                    |
      | Connections    | 5 incoming, 3 outgoing     |
      | CPU            | 35%                        |
      | Memory         | 2.5GB / 4GB                |

  @P1 @topology @layout
  Scenario: Topology Layout - View Options
    Given I am on the Topology page
    Then I should be able to change layout:
      | Layout         | Description                 |
      | Hierarchical   | Tiered tree structure       |
      | Force-Directed | Physics-based positioning   |
      | Circular       | Nodes in a circle           |
      | Grid           | Organized grid layout       |
    And I should be able to zoom and pan the graph

  # ===========================================================================
  # SECTION 24: VIDEO PAGE
  # ===========================================================================

  @P0 @video @streams
  Scenario: Video Page - Stream Dashboard Display
    When I navigate to "/prajna/video"
    Then I should see the video surveillance dashboard
    And I should see stream status:
      | Stream         | Status  | Resolution | FPS  |
      | CAM-001        | ACTIVE  | 1080p      | 30   |
      | CAM-002        | ACTIVE  | 1080p      | 30   |
      | CAM-003        | OFFLINE | -          | -    |
      | CAM-004        | ACTIVE  | 720p       | 25   |

  @P0 @video @health
  Scenario: Stream Health - Real-Time Monitoring
    Given I am on the Video page
    Then I should see stream health metrics:
      | Metric           | CAM-001 | CAM-002 | CAM-003 |
      | Bitrate          | 8 Mbps  | 8 Mbps  | -       |
      | Packet Loss      | 0.1%    | 0.2%    | -       |
      | Latency          | 150ms   | 200ms   | -       |
      | Recording        | Yes     | Yes     | No      |

  @P1 @video @playback
  Scenario: Video Playback - Historical Review
    Given I am on the Video page
    When I click "Playback" for CAM-001
    Then I should see the playback controls
    And I should be able to:
      | Action          | Description                 |
      | Seek            | Jump to specific time       |
      | Speed           | 0.5x, 1x, 2x, 4x playback   |
      | Export          | Download video clip         |
      | Snapshot        | Capture still image         |

  @P1 @video @grid
  Scenario: Video Grid - Multi-Camera View
    Given I am on the Video page
    When I click "Grid View"
    Then I should see multiple camera feeds:
      | Layout   | Cameras |
      | 2x2      | 4       |
      | 3x3      | 9       |
      | 4x4      | 16      |
    And I should be able to click any camera for full-screen

  # ===========================================================================
  # SECTION 25: CROSS-CUTTING CONCERNS
  # ===========================================================================

  @P0 @websocket @connectivity
  Scenario: WebSocket - Connection Resilience
    Given I am on any Prajna page
    When the WebSocket connection is lost
    Then I should see a connection status indicator change to "Disconnected"
    And the system should attempt automatic reconnection
    And when reconnected, the page should refresh data

  @P0 @accessibility @keyboard
  Scenario: Keyboard Navigation - All Pages
    Given I am on any Prajna page
    Then I should be able to navigate using Tab key
    And I should be able to activate buttons with Enter/Space
    And I should see visible focus indicators
    And shortcuts should be available:
      | Shortcut | Action                    |
      | Alt+H    | Go to Home/Dashboard      |
      | Alt+A    | Go to Alarms              |
      | Alt+C    | Go to Commands            |
      | Alt+S    | Go to Settings            |

  @P1 @performance @loading
  Scenario: Page Load Performance - All Pages
    When I navigate to any Prajna page
    Then the page should fully render within 2000 milliseconds
    And the First Contentful Paint should be under 1500 milliseconds
    And the Time to Interactive should be under 3000 milliseconds

  @P1 @responsive @mobile
  Scenario: Responsive Design - Mobile View
    Given I am using a mobile device with width 375px
    When I navigate to any Prajna page
    Then the page should be usable on mobile
    And the navigation should collapse to a hamburger menu
    And touch targets should be at least 44x44 pixels

  # ===========================================================================
  # SECTION 26: INTEGRATION SCENARIOS
  # ===========================================================================

  @P0 @integration @full_flow
  Scenario: Full Alarm Flow - End to End
    Given I am on the Prajna main dashboard
    When a critical alarm "FIRE_ZONE_B" is received
    Then the alarm should appear on the Alarms page
    And the health score should decrease
    And Sentinel should detect the threat
    When I navigate to "/prajna/alarms"
    And I acknowledge the alarm
    And I dispatch a response
    Then the alarm status should be "DISPATCHED"
    And the action should be in Immutable Register
    When the responder resolves the alarm
    Then the alarm should move to history
    And the health score should recover

  @P0 @integration @guardian_flow
  Scenario: Guardian Approval Flow - End to End
    Given I am on the Commands page
    When I request command "restart-service" for "app-node-1"
    Then a proposal should appear on Guardian Dashboard
    When I navigate to "/prajna/guardian_dashboard"
    And I approve the proposal
    Then the command should be executable
    When I execute the command
    Then the service should restart
    And the execution should be in Immutable Register

  @P1 @integration @mesh_flow
  Scenario: Mesh Operations Flow - End to End
    Given I am on the Mesh page
    When I initiate a mesh reconfiguration
    Then Guardian should receive the proposal
    When approved, the reconfiguration should execute
    And all Zenoh routers should update
    And quorum should be maintained
    And the change should be in Immutable Register
