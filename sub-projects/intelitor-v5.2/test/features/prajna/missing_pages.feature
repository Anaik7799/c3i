@prajna @missing-pages @P0
Feature: Missing Prajna C3I Pages
  As a system operator
  I need complete coverage of all Prajna pages
  So that I can manage the full system through the cockpit

  Background:
    Given Phoenix is running on port 4000
    And I am authenticated as an "administrator"
    And WebSocket connection is established

  # =============================================================================
  # DIAGNOSTICS PAGE (/prajna/diagnostics)
  # =============================================================================

  @diagnostics @P0 @gap-closure
  Scenario: DIAG-001 - Diagnostics page loads successfully
    When I navigate to "/prajna/diagnostics"
    Then the page should load within 2 seconds
    And I should see the "System Diagnostics" header
    And the diagnostic panels should be visible

  @diagnostics @P0 @system-health
  Scenario: DIAG-002 - System health diagnostics display
    Given I am on the diagnostics page
    Then I should see the following diagnostic categories:
      | Category          | Status | Description                    |
      | BEAM Runtime      | Active | Erlang VM health               |
      | Database          | Active | PostgreSQL connection          |
      | Zenoh Mesh        | Active | Pub/sub connectivity           |
      | File System       | Active | Disk space and I/O             |
      | Memory            | Active | Heap and process memory        |
      | Scheduler         | Active | CPU scheduler utilization      |

  @diagnostics @P0 @error-analysis
  Scenario: DIAG-003 - Error log analysis
    Given I am on the diagnostics page
    When I click on the "Error Analysis" tab
    Then I should see recent errors grouped by:
      | Grouping   | Description           |
      | Module     | By source module      |
      | Severity   | Critical/Warning/Info |
      | Time       | Last 24h / 7d / 30d   |
      | Frequency  | Most common           |

  @diagnostics @P1 @trace-analysis
  Scenario: DIAG-004 - Distributed trace analysis
    Given I am on the diagnostics page
    When I click on the "Traces" tab
    And I search for trace ID "abc123"
    Then the trace waterfall should be displayed
    And I should see span timing breakdown
    And I should see service dependencies

  @diagnostics @P1 @performance
  Scenario: DIAG-005 - Performance profiling
    Given I am on the diagnostics page
    When I click on the "Performance" tab
    Then I should see:
      | Metric            | Current | Threshold |
      | Response Time p95 | <500ms  | 500ms     |
      | Memory Usage      | <85%    | 85%       |
      | CPU Usage         | <80%    | 80%       |
      | DB Connections    | <90%    | 90%       |

  @diagnostics @P1 @recommendations
  Scenario: DIAG-006 - AI-powered diagnostic recommendations
    Given I am on the diagnostics page
    And there are performance issues detected
    When I click on "Get AI Recommendations"
    Then the AI copilot should analyze the diagnostics
    And I should see actionable recommendations
    And each recommendation should have an "Apply" button

  # =============================================================================
  # KNOWLEDGE BASE PAGE (/prajna/knowledge)
  # =============================================================================

  @knowledge @P0 @gap-closure
  Scenario: KB-001 - Knowledge base page loads successfully
    When I navigate to "/prajna/knowledge"
    Then the page should load within 2 seconds
    And I should see the "Knowledge Base" header
    And the search bar should be visible

  @knowledge @P0 @search
  Scenario: KB-002 - Search knowledge base
    Given I am on the knowledge base page
    When I enter "alarm handling" in the search bar
    And I press Enter
    Then search results should appear within 1 second
    And results should be grouped by category:
      | Category   | Description            |
      | Product    | Product documentation  |
      | SRE        | Runbooks and guides    |
      | Developer  | API and code docs      |

  @knowledge @P1 @categories
  Scenario: KB-003 - Browse knowledge categories
    Given I am on the knowledge base page
    When I click on the "Product" category
    Then I should see product documentation articles
    And articles should show:
      | Field        | Description              |
      | Title        | Article title            |
      | Summary      | Brief description        |
      | Last Updated | Modification date        |
      | Author       | Creator name             |
      | Tags         | Categorization tags      |

  @knowledge @P1 @article-view
  Scenario: KB-004 - View knowledge article
    Given I am on the knowledge base page
    And I have search results displayed
    When I click on an article title
    Then the full article should be displayed
    And the table of contents should be visible
    And related articles should be suggested

  @knowledge @P1 @tagging
  Scenario: KB-005 - Filter by tags
    Given I am on the knowledge base page
    When I click on the tag "alarms"
    Then only articles with the "alarms" tag should be shown
    And the active filter should be displayed
    And I can clear the filter by clicking "X"

  @knowledge @P2 @feedback
  Scenario: KB-006 - Article feedback
    Given I am viewing a knowledge article
    When I click "Was this helpful? Yes/No"
    And I select "No"
    Then a feedback form should appear
    And I can submit improvement suggestions

  # =============================================================================
  # SETTINGS PAGE (/prajna/settings)
  # =============================================================================

  @settings @P0 @gap-closure
  Scenario: SET-001 - Settings page loads successfully
    When I navigate to "/prajna/settings"
    Then the page should load within 2 seconds
    And I should see the "Settings" header
    And settings categories should be visible

  @settings @P0 @categories
  Scenario: SET-002 - Settings categories display
    Given I am on the settings page
    Then I should see the following setting categories:
      | Category       | Description                  |
      | General        | General system settings      |
      | Notifications  | Alert and notification prefs |
      | Theme          | UI theme customization       |
      | Security       | Security and access settings |
      | Integrations   | External service configs     |
      | Advanced       | Advanced system options      |

  @settings @P1 @theme
  Scenario: SET-003 - Theme customization
    Given I am on the settings page
    When I click on "Theme"
    Then I should see theme options:
      | Theme        | Description           |
      | Aerospace    | Dark cockpit (default)|
      | Light        | Light theme           |
      | High Contrast| Accessibility theme   |
    And selecting a theme should apply immediately

  @settings @P1 @notifications
  Scenario: SET-004 - Notification preferences
    Given I am on the settings page
    When I click on "Notifications"
    Then I should be able to configure:
      | Setting           | Options              |
      | Email Alerts      | On/Off               |
      | Sound Alerts      | On/Off               |
      | Critical Only     | On/Off               |
      | Quiet Hours       | Time range           |

  @settings @P1 @security
  Scenario: SET-005 - Security settings
    Given I am on the settings page
    When I click on "Security"
    Then I should see security options:
      | Setting            | Description              |
      | Change Password    | Update password          |
      | Two-Factor Auth    | Enable/disable 2FA       |
      | Session Timeout    | Auto-logout time         |
      | Active Sessions    | View/terminate sessions  |

  @settings @P2 @export
  Scenario: SET-006 - Export settings
    Given I am on the settings page
    When I click on "Export Settings"
    Then settings should be exported as JSON
    And the download should start automatically

  # =============================================================================
  # SHUTDOWN PAGE (/prajna/shutdown)
  # =============================================================================

  @shutdown @P0 @gap-closure
  Scenario: SHUT-001 - Shutdown page loads successfully
    When I navigate to "/prajna/shutdown"
    Then the page should load within 2 seconds
    And I should see the "System Shutdown" header
    And warning messages should be visible

  @shutdown @P0 @graceful
  Scenario: SHUT-002 - Initiate graceful shutdown
    Given I am on the shutdown page
    And I have "shutdown" permission
    When I click "Initiate Graceful Shutdown"
    Then a confirmation modal should appear
    And I should need to type "CONFIRM SHUTDOWN"
    And the 6-phase Apoptosis protocol should start

  @shutdown @P0 @apoptosis @SC-SIL4-015
  Scenario: SHUT-003 - Monitor Apoptosis phases
    Given a graceful shutdown has been initiated
    Then I should see the 6 Apoptosis phases:
      | Phase         | Status      | Description              |
      | Initiated     | In Progress | Shutdown signal sent     |
      | Notifying     | Pending     | Alerting dependent nodes |
      | Draining      | Pending     | Completing active tasks  |
      | Checkpointing | Pending     | Saving state to UCR      |
      | Terminating   | Pending     | Stopping processes       |
      | Terminated    | Pending     | Shutdown complete        |

  @shutdown @P0 @emergency @SC-EMR-057
  Scenario: SHUT-004 - Emergency stop option
    Given I am on the shutdown page
    When I click "Emergency Stop"
    Then a high-visibility warning should appear
    And I should need to confirm with Guardian approval
    And the system should halt within 5 seconds

  @shutdown @P1 @cancel
  Scenario: SHUT-005 - Cancel shutdown
    Given a graceful shutdown is in progress
    And the phase is "Notifying" or earlier
    When I click "Cancel Shutdown"
    Then the shutdown should be aborted
    And the system should return to operational state

  # =============================================================================
  # TEST COCKPIT PAGE (/prajna/test_cockpit)
  # =============================================================================

  @test-cockpit @P0 @gap-closure
  Scenario: TEST-001 - Test cockpit page loads successfully
    When I navigate to "/prajna/test_cockpit"
    Then the page should load within 2 seconds
    And I should see the "Test Cockpit" header
    And test execution controls should be visible

  @test-cockpit @P0 @run-tests
  Scenario: TEST-002 - Run test suite
    Given I am on the test cockpit page
    When I click "Run All Tests"
    Then test execution should start
    And I should see real-time progress
    And results should stream as tests complete

  @test-cockpit @P1 @filter
  Scenario: TEST-003 - Filter tests by category
    Given I am on the test cockpit page
    When I select filter "Property Tests Only"
    Then only property tests should be shown
    And the test count should update

  @test-cockpit @P1 @results
  Scenario: TEST-004 - View test results
    Given tests have completed
    When I view the results
    Then I should see:
      | Metric      | Value    |
      | Total       | 1000     |
      | Passed      | 985      |
      | Failed      | 10       |
      | Skipped     | 5        |
      | Coverage    | 92%      |

  @test-cockpit @P2 @history
  Scenario: TEST-005 - Test history comparison
    Given I am on the test cockpit page
    When I click "Compare with Previous"
    Then I should see test result trends
    And regressions should be highlighted in red
    And improvements should be highlighted in green

  # =============================================================================
  # TOPOLOGY PAGE (/prajna/topology)
  # =============================================================================

  @topology @P0 @gap-closure
  Scenario: TOPO-001 - Topology page loads successfully
    When I navigate to "/prajna/topology"
    Then the page should load within 2 seconds
    And I should see the "System Topology" header
    And the topology graph should be rendered

  @topology @P0 @graph
  Scenario: TOPO-002 - View system topology graph
    Given I am on the topology page
    Then I should see nodes for:
      | Node Type   | Count | Description          |
      | Database    | 1     | PostgreSQL           |
      | Application | 1-3   | Phoenix instances    |
      | Observability| 1    | OTEL/Grafana stack   |
      | Zenoh Router| 1-3   | Mesh routers         |
    And edges should show connections between nodes

  @topology @P1 @interactive
  Scenario: TOPO-003 - Interactive topology navigation
    Given I am on the topology page
    When I click on a node
    Then node details should appear in a side panel
    And I should see node health metrics
    And I should be able to zoom and pan the graph

  @topology @P1 @health
  Scenario: TOPO-004 - Topology health visualization
    Given I am on the topology page
    Then healthy nodes should have green borders
    And unhealthy nodes should have red borders
    And degraded nodes should have yellow borders
    And the legend should explain the color coding

  @topology @P2 @export
  Scenario: TOPO-005 - Export topology diagram
    Given I am on the topology page
    When I click "Export"
    Then I should be able to export as PNG or SVG
    And the exported image should include all nodes

  # =============================================================================
  # OBSERVABILITY PAGE (/prajna/observability)
  # =============================================================================

  @observability @P0 @gap-closure
  Scenario: OBS-001 - Observability page loads successfully
    When I navigate to "/prajna/observability"
    Then the page should load within 2 seconds
    And I should see the "Observability" header
    And metric dashboards should be visible

  @observability @P0 @metrics
  Scenario: OBS-002 - View system metrics
    Given I am on the observability page
    Then I should see the following metric panels:
      | Panel           | Metrics                    |
      | Request Rate    | RPS, success rate          |
      | Latency         | p50, p95, p99              |
      | Error Rate      | 4xx, 5xx percentages       |
      | Resource Usage  | CPU, Memory, Disk          |

  @observability @P1 @traces
  Scenario: OBS-003 - View distributed traces
    Given I am on the observability page
    When I click on the "Traces" tab
    Then I should see recent traces
    And I can filter by service or duration
    And clicking a trace shows the waterfall view

  @observability @P1 @logs
  Scenario: OBS-004 - View aggregated logs
    Given I am on the observability page
    When I click on the "Logs" tab
    Then I should see log entries
    And logs should be searchable
    And I can filter by level (error, warn, info, debug)

  @observability @P2 @custom-dashboard
  Scenario: OBS-005 - Create custom dashboard
    Given I am on the observability page
    When I click "Create Dashboard"
    Then I should be able to add widgets
    And I can arrange widgets by drag-and-drop
    And the dashboard should be saved for future use
