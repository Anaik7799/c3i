# Cross-Domain Integration Feature
# Feature: Cross-Domain Integration
# Purpose: Verify that data and workflows flow correctly across domain boundaries
# Domains: CRM, SMRITI, Analytics, Automation, GUI
#
# STAMP Compliance:
#   - SC-BDD-001: All user stories have BDD scenarios
#   - SC-BDD-003: Gherkin syntax used
#   - SC-HOLON-001: State in SQLite/DuckDB
#   - SC-ZENOH-001: Zenoh telemetry mandatory
#
# AOR Compliance:
#   - AOR-BDD-001: Feature file written before implementation
#   - AOR-HOLON-010: Fully regenerable from SQLite/DuckDB
#   - AOR-ZENOH-007: Publish node health every 10 seconds

@cross_domain @integration @sil6
Feature: Cross-Domain Integration
  As a system architect
  I want to verify that all domains work together seamlessly
  So that the system provides unified functionality across boundaries

  Background:
    Given the Indrajaal system is running in fractal cluster mode
    And all 3 containers are healthy:
      | Container            | Status  | Ports      |
      | indrajaal-db-prod    | healthy | 5433       |
      | indrajaal-obs-prod   | healthy | 4317, 9090 |
      | indrajaal-ex-app-1   | healthy | 4000       |
    And Zenoh telemetry is active on all nodes
    And the following tenants exist:
      | Tenant ID                            | Name           | Status |
      | 550e8400-e29b-41d4-a716-446655440001 | Acme Corp      | active |
      | 550e8400-e29b-41d4-a716-446655440002 | TechStart Inc  | active |
    And I am authenticated as user "admin@acme.com" with tenant "550e8400-e29b-41d4-a716-446655440001"

  # ===========================================================================
  # SCENARIO 1: End-to-End Lead Journey (Full Sales Cycle)
  # ===========================================================================

  @e2e @sales_cycle @critical
  Scenario: Complete lead-to-close sales journey across CRM domains
    # STAGE 1: Lead Creation from Marketing Campaign
    Given a marketing campaign exists:
      | Campaign ID                          | Name              | Status | Budget |
      | 650e8400-e29b-41d4-a716-446655440001 | Summer Promo 2026 | active | 50000  |
    When I create a lead from the campaign:
      | Field       | Value                    |
      | first_name  | Jane                     |
      | last_name   | Prospect                 |
      | email       | jane.prospect@example.com |
      | company     | Prospect Industries       |
      | source      | Web Form                 |
      | campaign_id | 650e8400-e29b-41d4-a716-446655440001 |
    Then the lead should be created with status "new"
    And a Zenoh event should be published to "indrajaal/crm/leads/created"
    And the campaign should track the lead association

    # STAGE 2: Lead Scoring and Assignment
    When the lead scoring engine runs
    Then the lead should be scored based on:
      | Factor            | Weight | Score |
      | company_size      | 0.3    | 8     |
      | engagement_level  | 0.4    | 7     |
      | budget_authority  | 0.3    | 6     |
    And the final lead score should be 7.1
    And the lead should be auto-assigned to sales rep "john.sales@acme.com"
    And a notification should be sent via Zenoh to "indrajaal/notifications/sales/john.sales@acme.com"

    # STAGE 3: Lead Conversion to Opportunity
    When the sales rep qualifies the lead with notes:
      """
      Qualified via phone call. Budget confirmed: $100K.
      Decision timeline: Q2 2026.
      Next step: Send proposal.
      """
    And the sales rep converts the lead to opportunity
    Then an opportunity should be created with:
      | Field          | Value                        |
      | name           | Prospect Industries - Q2 2026 |
      | stage          | qualification                |
      | amount         | 100000                       |
      | close_date     | 2026-06-30                   |
      | probability    | 25                           |
    And an account should be created for "Prospect Industries"
    And a contact should be created for "Jane Prospect"
    And the original lead status should be "converted"
    And Zenoh events should be published:
      | Topic                                  | Event Type            |
      | indrajaal/crm/opportunities/created    | opportunity_created   |
      | indrajaal/crm/accounts/created         | account_created       |
      | indrajaal/crm/contacts/created         | contact_created       |
      | indrajaal/crm/leads/converted          | lead_converted        |

    # STAGE 4: Quote and Order Creation
    When the sales rep creates a quote with line items:
      | Product SKU | Quantity | Unit Price | Discount |
      | PROD-001    | 10       | 5000       | 10%      |
      | PROD-002    | 5        | 8000       | 5%       |
    Then the quote should be created with:
      | Field       | Value    |
      | subtotal    | 83000    |
      | discount    | 7000     |
      | tax         | 7980     |
      | total       | 83980    |
      | status      | draft    |

    When the quote is approved by manager "manager@acme.com"
    Then the quote status should be "approved"
    And a Zenoh event should be published to "indrajaal/crm/quotes/approved"

    When the quote is accepted by the customer
    Then an order should be auto-created from the quote
    And the order status should be "pending_fulfillment"
    And the opportunity stage should advance to "proposal"

    # STAGE 5: Close Won
    When the order is fulfilled
    And the sales rep marks the opportunity as "closed_won"
    Then the opportunity should be closed with:
      | Field           | Value      |
      | stage           | closed_won |
      | close_date      | today      |
      | actual_revenue  | 83980      |
    And the account lifetime value should be updated
    And analytics events should be published:
      | Metric                  | Value  | Topic                              |
      | revenue_closed          | 83980  | indrajaal/analytics/revenue        |
      | deal_velocity_days      | 45     | indrajaal/analytics/sales_velocity |
      | conversion_rate_percent | 100    | indrajaal/analytics/conversion     |
    And a success notification should be sent to the sales team
    And the customer success team should be notified for onboarding

  # ===========================================================================
  # SCENARIO 2: SMRITI + CRM Integration (Knowledge Management)
  # ===========================================================================

  @smriti @crm @knowledge_management
  Scenario: Link knowledge base articles to CRM records with AI recommendations
    # Setup: Create knowledge base structure
    Given the following zettels exist in the SMRITI:
      | Zettel ID                            | Title                    | Content                           | Tags         |
      | 750e8400-e29b-41d4-a716-446655440001 | Product Comparison       | Feature matrix for PROD-001/002   | product      |
      | 750e8400-e29b-41d4-a716-446655440002 | Common Objections        | Handling price objections         | sales        |
      | 750e8400-e29b-41d4-a716-446655440003 | Implementation Timeline  | Standard deployment: 6-8 weeks    | implementation |
      | 750e8400-e29b-41d4-a716-446655440004 | Case Study: TechCorp     | Success story with similar customer | case_study   |
    And an opportunity exists:
      | Field         | Value                 |
      | opportunity_id| 850e8400-e29b-41d4-a716-446655440001 |
      | name          | BigCo Enterprise Deal |
      | stage         | qualification         |
      | amount        | 250000                |

    # Knowledge Base Search from CRM
    When the sales rep searches the knowledge base from the CRM opportunity view
    And the search query is "product comparison enterprise"
    Then the SMRITI should return relevant zettels:
      | Zettel ID                            | Title                | Relevance Score |
      | 750e8400-e29b-41d4-a716-446655440001 | Product Comparison   | 0.95            |
      | 750e8400-e29b-41d4-a716-446655440004 | Case Study: TechCorp | 0.82            |
    And the search results should be displayed in the CRM interface

    # Link Zettel to Opportunity
    When the sales rep links zettel "750e8400-e29b-41d4-a716-446655440001" to the opportunity
    Then a bidirectional link should be created:
      | Source Type  | Source ID                            | Target Type | Target ID                            | Link Type |
      | opportunity  | 850e8400-e29b-41d4-a716-446655440001 | zettel      | 750e8400-e29b-41d4-a716-446655440001 | reference |
    And the zettel should appear in the opportunity's "Related Knowledge" section
    And the opportunity should appear in the zettel's backlinks
    And a Zenoh event should be published to "indrajaal/smriti/links/created"

    # AI Recommendations from Knowledge Graph
    When the AI copilot analyzes the opportunity
    Then it should recommend relevant zettels based on:
      | Factor              | Weight |
      | semantic_similarity | 0.4    |
      | tag_overlap         | 0.3    |
      | historical_success  | 0.3    |
    And the recommendations should include:
      | Zettel ID                            | Reason                                  | Confidence |
      | 750e8400-e29b-41d4-a716-446655440002 | Common objections for pricing tier      | 0.88       |
      | 750e8400-e29b-41d4-a716-446655440003 | Timeline questions typical for stage    | 0.75       |
    And the recommendations should be displayed in the Prajna AI Copilot panel
    And the sales rep can click to view or link recommended zettels

    # Knowledge Graph Traversal
    When the sales rep views the zettel graph from the CRM
    Then the SMRITI graph should display:
      | Node Type    | Node ID                              | Connected To                          |
      | opportunity  | 850e8400-e29b-41d4-a716-446655440001 | zettel:750e8400-...0001               |
      | zettel       | 750e8400-e29b-41d4-a716-446655440001 | zettel:750e8400-...0002 (related)     |
      | zettel       | 750e8400-e29b-41d4-a716-446655440002 | zettel:750e8400-...0003 (cites)       |
    And the graph should be interactive with zoom/pan/filter
    And clicking a zettel node should open it in a modal view

  # ===========================================================================
  # SCENARIO 3: Analytics Across Domains (Unified Observability)
  # ===========================================================================

  @analytics @observability @zenoh
  Scenario: Unified analytics dashboard aggregates data from multiple domains
    # Setup: Generate activity across domains
    Given the following CRM activities occurred today:
      | Activity Type | Count | Domain      |
      | leads_created | 15    | crm_leads   |
      | opps_created  | 8     | crm_opps    |
      | opps_closed   | 3     | crm_opps    |
    And the following SMRITI activities occurred today:
      | Activity Type   | Count | Domain |
      | zettels_created | 25    | smriti |
      | zettels_linked  | 40    | smriti |
      | searches_run    | 120   | smriti |
    And the following system activities occurred today:
      | Activity Type    | Count | Domain     |
      | api_requests     | 5000  | system     |
      | zenoh_messages   | 15000 | telemetry  |
      | errors_logged    | 12    | monitoring |

    # Dashboard Data Aggregation
    When I access the unified analytics dashboard at "/prajna/analytics"
    Then the dashboard should pull data from multiple domains:
      | Domain     | Data Source        | Query Type       |
      | CRM        | PostgreSQL (Ash)   | SQL aggregation  |
      | SMRITI       | DuckDB             | Columnar scan    |
      | System     | SQLite + Zenoh     | Mixed query      |
      | Telemetry  | Prometheus + OTEL  | Time-series      |
    And the data collection latency should be < 500ms per domain
    And the total dashboard load time should be < 2 seconds

    # KPI Calculation Across Domains
    Then the dashboard should display cross-domain KPIs:
      | KPI Name                 | Value | Calculation                                |
      | Lead-to-Opp Conversion   | 53%   | (opps_created / leads_created) * 100       |
      | Knowledge Utilization    | 3.2   | zettels_linked / opps_created              |
      | System Health Score      | 98.5  | 100 - (errors_logged / api_requests * 100) |
      | Zenoh Message Throughput | 250   | zenoh_messages / 60 (per second)           |

    # Zenoh Telemetry from All Sources
    And the following Zenoh topics should have active publishers:
      | Topic                              | Publisher Count | Message Rate (msg/s) |
      | indrajaal/crm/*/metrics            | 3               | 10                   |
      | indrajaal/smriti/*/metrics           | 2               | 5                    |
      | indrajaal/analytics/kpi            | 1               | 1                    |
      | indrajaal/health/*/node            | 3               | 0.1                  |
    And all telemetry should be collected in Prometheus
    And OTEL traces should link CRM → SMRITI → Analytics operations

    # Unified Health Monitoring
    When I view the system health panel
    Then it should show fractal layer health for all domains:
      | Domain | L1:Function | L2:Component | L3:Holon | L4:Container | L5:Node | L6:Cluster | L7:Federation |
      | CRM    | ✓ 100%      | ✓ 100%       | ✓ 98%    | ✓ 100%       | ✓ 100%  | ✓ 100%     | ✓ 100%        |
      | SMRITI   | ✓ 100%      | ✓ 100%       | ✓ 100%   | ✓ 100%       | ✓ 100%  | ✓ 100%     | ✓ 100%        |
      | Analytics | ✓ 100%   | ✓ 100%       | ✓ 97%    | ✓ 100%       | ✓ 100%  | ✓ 100%     | ✓ 100%        |
    And any layer below 95% should trigger a warning alert
    And FPPS 5-method consensus should validate health status

    # Real-Time Updates
    When a new CRM opportunity is created
    Then the analytics dashboard should update within 5 seconds
    And the "Opportunities Created Today" KPI should increment
    And a Zenoh event should be received by the dashboard subscriber
    And the update should be reflected without page refresh (Phoenix LiveView)

  # ===========================================================================
  # SCENARIO 4: Automation Chain (Workflow Orchestration)
  # ===========================================================================

  @automation @workflow @orchestration
  Scenario: Lead creation triggers workflow that creates activities and updates analytics
    # Workflow Definition
    Given the following automation workflow exists:
      | Workflow Name           | Lead Nurture Automation      |
      | Trigger Event           | lead_created                 |
      | Status                  | active                       |
      | Execution Mode          | async                        |
    And the workflow has the following steps:
      | Step | Action                  | Target Domain | Delay  | Condition           |
      | 1    | Send welcome email      | Comms         | 0s     | always              |
      | 2    | Create follow-up task   | CRM           | 5min   | lead.source = 'Web' |
      | 3    | Score lead              | CRM           | 10min  | always              |
      | 4    | Notify sales if hot     | CRM           | 11min  | lead.score >= 7     |
      | 5    | Update analytics        | Analytics     | 12min  | always              |

    # Lead Creation (Trigger)
    When I create a new lead:
      | Field      | Value                  |
      | first_name | Sarah                  |
      | last_name  | WebVisitor             |
      | email      | sarah.visitor@demo.com |
      | source     | Web                    |
      | status     | new                    |
    Then a Zenoh event should be published to "indrajaal/crm/leads/created"
    And the automation engine should receive the event within 1 second

    # Step 1: Welcome Email (Immediate)
    Then within 5 seconds:
      | Action                               | Expected Result                    |
      | Welcome email queued                 | Email in outbox with template_id   |
      | Email contains personalization       | "Hi Sarah" in email body           |
      | Email tracking link added            | UTM parameters present             |
      | Communication record created         | Record in CRM with type="email"    |
    And a Zenoh event should be published to "indrajaal/comms/emails/sent"

    # Step 2: Follow-up Task (After 5 minutes - simulated)
    When I advance workflow time by 5 minutes
    Then a follow-up task should be created:
      | Field         | Value                              |
      | subject       | Follow up with Sarah WebVisitor    |
      | due_date      | tomorrow                           |
      | assigned_to   | sales_team_queue                   |
      | priority      | medium                             |
      | related_to    | lead:sarah.visitor@demo.com        |
    And the task should be visible in the sales team's task queue
    And a Zenoh notification should be sent to "indrajaal/tasks/created"

    # Step 3: Lead Scoring (After 10 minutes - simulated)
    When I advance workflow time by 10 minutes
    Then the lead scoring engine should execute
    And the lead score should be calculated as 6.5
    And the lead record should be updated with:
      | Field           | Value |
      | score           | 6.5   |
      | scoring_date    | now   |
      | scoring_version | v2.0  |
    And a Zenoh event should be published to "indrajaal/crm/leads/scored"

    # Step 4: Conditional Notification (After 11 minutes - simulated)
    When I advance workflow time by 11 minutes
    Then the condition "lead.score >= 7" should be evaluated to false
    And NO notification should be sent to sales
    But if I manually update the lead score to 8.0
    And I trigger workflow re-evaluation
    Then a notification should be sent to "indrajaal/notifications/sales/hot_lead"

    # Step 5: Analytics Update (After 12 minutes - simulated)
    When I advance workflow time by 12 minutes
    Then the analytics engine should receive an update event
    And the following metrics should be incremented:
      | Metric                        | Increment |
      | leads_with_automated_workflow | 1         |
      | welcome_emails_sent           | 1         |
      | tasks_auto_created            | 1         |
      | leads_scored_by_automation    | 1         |
    And the workflow execution should be logged to DuckDB for historical analysis

    # Workflow Completion
    Then the workflow execution record should show:
      | Field              | Value     |
      | status             | completed |
      | steps_executed     | 5         |
      | steps_skipped      | 1         |
      | total_duration_sec | 720       |
      | errors             | 0         |
    And all state changes should be recorded in the Immutable Register

  # ===========================================================================
  # SCENARIO 5: GUI Integration (Real-Time UI Updates)
  # ===========================================================================

  @gui @real_time @phoenix_liveview
  Scenario: Prajna cockpit displays CRM data with real-time Zenoh updates
    # Initial Dashboard State
    Given I am viewing the Prajna cockpit at "/prajna"
    When the page loads
    Then the cockpit should display the following panels:
      | Panel Name        | Data Source            | Update Frequency |
      | System Health     | Sentinel + Zenoh       | 10s              |
      | CRM Summary       | PostgreSQL + Zenoh     | 30s              |
      | SMRITI Activity     | DuckDB + Zenoh         | 30s              |
      | Active Threats    | Sentinel + Zenoh       | 5s               |
      | Smart Metrics     | Guardian + Analytics   | 60s              |
    And all panels should be connected to Phoenix LiveView
    And Zenoh subscribers should be active for real-time updates

    # CRM Summary Panel
    Then the CRM Summary panel should show:
      | Metric                    | Value | Source                     |
      | Open Opportunities        | 24    | PostgreSQL query           |
      | Total Pipeline Value      | $1.2M | Sum of opportunity amounts |
      | Hot Leads (Score >= 8)    | 7     | PostgreSQL where clause    |
      | Tasks Due Today           | 15    | Date filter                |
    And the data should be pulled via Ash API
    And the query should complete in < 200ms

    # SMRITI Graph Embedded in CRM
    When I click on an opportunity "BigCo Enterprise Deal"
    Then the opportunity detail view should open
    And it should include an embedded SMRITI knowledge graph panel
    And the graph should display:
      | Node Type    | Node Label               | Connected To      |
      | Opportunity  | BigCo Enterprise Deal    | 3 zettels         |
      | Zettel       | Product Comparison       | 2 related zettels |
      | Zettel       | Case Study: TechCorp     | 1 related zettel  |
    And the graph should be interactive with D3.js visualization
    And clicking a zettel node should open the zettel in a slide-over panel

    # Real-Time Updates via Zenoh
    When a new opportunity is created in another session:
      | Field      | Value                   |
      | name       | New Corp Deal           |
      | amount     | 150000                  |
      | stage      | prospecting             |
    Then within 5 seconds:
      | UI Element                        | Expected Change                          |
      | CRM Summary - Open Opportunities  | Increment from 24 to 25                  |
      | CRM Summary - Pipeline Value      | Increase from $1.2M to $1.35M            |
      | Opportunity List (if visible)     | New row appears with "New Corp Deal"     |
    And NO page refresh should be required
    And the update should arrive via Zenoh topic "indrajaal/crm/opportunities/created"
    And Phoenix LiveView should handle the event and push update to browser

    # Health Score Updates
    When the system health degrades from 98% to 85%
    Then within 10 seconds:
      | UI Element             | Expected Change                          |
      | Health Score Badge     | Color changes from green to yellow       |
      | Health Score Value     | Updates from 98% to 85%                  |
      | Threat Panel           | New threat appears with RPN score        |
      | Alert Toast            | Warning notification appears             |
    And the health data should come from Zenoh topic "indrajaal/health/system"
    And Sentinel should publish the degradation event

    # AI Copilot Recommendations
    When I open the AI Copilot panel at "/prajna/copilot"
    Then the copilot should display recommendations:
      | Recommendation Type       | Source Data            | Count |
      | High-value at-risk deals  | CRM + Analytics        | 2     |
      | Unanswered customer emails| Comms + AI analysis    | 5     |
      | Knowledge gaps            | SMRITI graph analysis    | 3     |
    And each recommendation should be clickable to navigate to the relevant record
    And the recommendations should update in real-time as new data arrives

    # Multi-Domain Search
    When I use the global search bar to search for "enterprise"
    Then the search results should include items from multiple domains:
      | Domain    | Result Type  | Count | Example                          |
      | CRM       | Opportunity  | 3     | "BigCo Enterprise Deal"          |
      | CRM       | Account      | 2     | "Enterprise Solutions Inc"       |
      | SMRITI      | Zettel       | 5     | "Enterprise Architecture Guide"  |
      | Analytics | Dashboard    | 1     | "Enterprise KPIs"                |
    And the search should be federated across all data sources
    And results should be ranked by relevance using AI
    And clicking a result should navigate to the appropriate domain view

  # ===========================================================================
  # SCENARIO 6: Multi-Tenant Data Isolation
  # ===========================================================================

  @multi_tenant @security @data_isolation
  Scenario: Cross-domain operations respect tenant boundaries
    Given I am authenticated as user "alice@acme.com" with tenant "550e8400-e29b-41d4-a716-446655440001"
    And the following data exists for tenant "550e8400-e29b-41d4-a716-446655440001":
      | Domain | Resource Type | Count |
      | CRM    | Opportunities | 10    |
      | SMRITI   | Zettels       | 50    |
    And the following data exists for tenant "550e8400-e29b-41d4-a716-446655440002" (different tenant):
      | Domain | Resource Type | Count |
      | CRM    | Opportunities | 15    |
      | SMRITI   | Zettels       | 75    |

    # Cross-Domain Query with Tenant Filter
    When I query the analytics dashboard for "all opportunities"
    Then the query should include tenant filter for "550e8400-e29b-41d4-a716-446655440001"
    And the result should contain 10 opportunities
    And NO opportunities from tenant "550e8400-e29b-41d4-a716-446655440002" should be returned

    # SMRITI Search with Tenant Isolation
    When I search the SMRITI for "product"
    Then the search should be scoped to tenant "550e8400-e29b-41d4-a716-446655440001"
    And results should include only zettels from my tenant
    And I should NOT be able to see or link to zettels from other tenants

    # Workflow Execution with Tenant Context
    When a workflow is triggered by a lead creation
    Then all workflow steps should execute in the context of tenant "550e8400-e29b-41d4-a716-446655440001"
    And created tasks should be assigned to users within the same tenant
    And analytics updates should be tenant-isolated
    And Zenoh events should include tenant_id in metadata

  # ===========================================================================
  # SCENARIO 7: Error Handling Across Domain Boundaries
  # ===========================================================================

  @error_handling @resilience @circuit_breaker
  Scenario: System gracefully handles failures in cross-domain operations
    Given an opportunity exists with ID "950e8400-e29b-41d4-a716-446655440001"

    # SMRITI Service Down
    When the SMRITI service becomes unavailable
    And I view the opportunity detail page
    Then the CRM data should still be displayed
    But the embedded knowledge graph should show:
      | Message              | "Knowledge graph temporarily unavailable" |
      | Fallback Action      | "Retry" button                            |
      | Circuit Breaker State| OPEN                                      |
    And the page should not crash or hang
    And an error should be logged to Zenoh topic "indrajaal/errors/smriti_unavailable"

    # Analytics Service Degraded
    When the analytics service responds slowly (> 5 seconds)
    And I load the Prajna dashboard
    Then the dashboard should use cached data for the slow panel
    And a "Stale Data" indicator should be shown
    And the other panels should load normally
    And a timeout event should be published to Zenoh

    # Database Connection Lost During Workflow
    When a workflow is executing
    And the database connection is lost during step 3 of 5
    Then the workflow should pause execution
    And the current state should be checkpointed to SQLite
    When the database connection is restored
    Then the workflow should automatically resume from step 3
    And no steps should be duplicated or skipped
    And the Immutable Register should log the interruption and recovery

  # ===========================================================================
  # SCENARIO 8: Performance Under Load
  # ===========================================================================

  @performance @load_testing @scalability
  Scenario: System maintains cross-domain performance under high load
    Given the system is under load with:
      | Metric                  | Value    |
      | Concurrent users        | 100      |
      | Requests per second     | 500      |
      | Zenoh messages per sec  | 2000     |
      | Active workflows        | 50       |

    # Dashboard Load Time
    When I load the Prajna cockpit
    Then the page should load within 2 seconds
    And the initial data from all domains should be displayed
    And subsequent real-time updates should have < 1s latency

    # Cross-Domain Query Performance
    When I run an analytics query that joins CRM + SMRITI + System data
    Then the query should complete within 1 second
    And the query plan should show:
      | Step | Operation                  | Data Source | Duration |
      | 1    | Fetch CRM data             | PostgreSQL  | < 200ms  |
      | 2    | Fetch SMRITI data            | DuckDB      | < 150ms  |
      | 3    | Fetch System metrics       | Prometheus  | < 100ms  |
      | 4    | Join and aggregate         | Elixir      | < 50ms   |

    # Zenoh Throughput
    Then the Zenoh mesh should maintain:
      | Metric                     | Target    | Actual   |
      | Message delivery latency   | < 10ms    | < 10ms   |
      | Messages per second        | 2000      | 2000     |
      | Subscriber lag             | < 100ms   | < 100ms  |

    # Resource Utilization
    And the container resource usage should remain below:
      | Container            | CPU  | Memory |
      | indrajaal-ex-app-1   | 70%  | 2GB    |
      | indrajaal-db-prod    | 60%  | 1GB    |
      | indrajaal-obs-prod   | 50%  | 1.5GB  |

  # ===========================================================================
  # SCENARIO 9: Audit Trail Across Domains
  # ===========================================================================

  @audit @compliance @immutable_register
  Scenario: All cross-domain operations are logged to Immutable Register
    # Operation Sequence
    When I perform the following operations:
      | Step | Operation                      | Domain      |
      | 1    | Create lead                    | CRM         |
      | 2    | Link zettel to lead            | CRM + SMRITI  |
      | 3    | Score lead via automation      | CRM         |
      | 4    | Convert lead to opportunity    | CRM         |
      | 5    | View analytics dashboard       | Analytics   |

    # Immutable Register Verification
    Then the Immutable Register should contain blocks for each operation:
      | Block | Operation Hash                                                    | Prev Hash | Actor           | Timestamp       |
      | N     | SHA3(create_lead:...)                                            | ...       | alice@acme.com  | 2026-01-11T...  |
      | N+1   | SHA3(link_zettel:...)                                            | ...       | alice@acme.com  | 2026-01-11T...  |
      | N+2   | SHA3(score_lead:...)                                             | ...       | system:workflow | 2026-01-11T...  |
      | N+3   | SHA3(convert_lead:...)                                           | ...       | alice@acme.com  | 2026-01-11T...  |
      | N+4   | SHA3(view_dashboard:...)                                         | ...       | alice@acme.com  | 2026-01-11T...  |

    # Hash Chain Integrity
    And the hash chain should be unbroken
    And each block should be Ed25519 signed
    And I should be able to verify the signature of any block
    And the chain integrity should be verified on startup per SC-REG-002

    # Cross-Domain Audit Query
    When I query the audit trail for "all operations related to lead ID X"
    Then the results should include operations from multiple domains:
      | Domain    | Operation         | Timestamp       | Actor           |
      | CRM       | lead_created      | 2026-01-11T...  | alice@acme.com  |
      | CRM+SMRITI  | zettel_linked     | 2026-01-11T...  | alice@acme.com  |
      | CRM       | lead_scored       | 2026-01-11T...  | system:workflow |
      | CRM       | lead_converted    | 2026-01-11T...  | alice@acme.com  |
    And the timeline should be chronologically ordered
    And I should be able to replay the operation sequence

    # Compliance Report
    When I generate a compliance report for "operations in the last 30 days"
    Then the report should include:
      | Section               | Data Source            | Verification Method  |
      | Total Operations      | Immutable Register     | Block count          |
      | Domain Breakdown      | Block metadata         | Group by domain      |
      | User Activity         | Actor field            | Group by actor       |
      | Integrity Status      | Hash chain             | FPPS 5-method        |
    And the report should be exportable as PDF with digital signature
    And the report itself should be logged to the Immutable Register

# ===========================================================================
# ADDITIONAL SCENARIOS (Optional for Extended Coverage)
# ===========================================================================

  @federation @cross_holon @future
  Scenario Outline: Cross-holon data federation
    # This scenario covers future federation capabilities
    Given multiple holon instances are federated:
      | Holon ID   | Region    | Status |
      | holon-us   | US-East   | active |
      | holon-eu   | EU-West   | active |
    When data is created in <source_holon>
    Then it should be replicated to <target_holon> via Zenoh federation
    And version vectors should ensure conflict-free replication
    And the operation should be logged in both holons' Immutable Registers

    Examples:
      | source_holon | target_holon |
      | holon-us     | holon-eu     |
      | holon-eu     | holon-us     |

# ===========================================================================
# TAGS REFERENCE
# ===========================================================================
# @cross_domain      - All scenarios in this file
# @integration       - Integration testing scenarios
# @sil6              - SIL-6 safety-critical scenarios
# @e2e               - End-to-end user journeys
# @sales_cycle       - Sales process scenarios
# @critical          - Critical path scenarios
# @smriti              - Knowledge management integration
# @crm               - CRM domain
# @knowledge_management - Knowledge management features
# @analytics         - Analytics and reporting
# @observability     - Monitoring and telemetry
# @zenoh             - Zenoh messaging scenarios
# @automation        - Workflow automation
# @workflow          - Workflow engine
# @orchestration     - Cross-domain orchestration
# @gui               - User interface scenarios
# @real_time         - Real-time updates
# @phoenix_liveview  - Phoenix LiveView features
# @multi_tenant      - Multi-tenancy scenarios
# @security          - Security features
# @data_isolation    - Tenant data isolation
# @error_handling    - Error handling and resilience
# @resilience        - System resilience
# @circuit_breaker   - Circuit breaker pattern
# @performance       - Performance testing
# @load_testing      - Load and stress testing
# @scalability       - Scalability scenarios
# @audit             - Audit trail scenarios
# @compliance        - Compliance and regulatory
# @immutable_register - Immutable state register
# @federation        - Cross-holon federation
# @cross_holon       - Multi-holon scenarios
# @future            - Future capability scenarios

# ===========================================================================
# RELATED DOCUMENTS
# ===========================================================================
# - CLAUDE.md §5.0 STAMP Constraints
# - CLAUDE.md §14.0 BDD Test/Demo Integration
# - docs/architecture/BDD_INTEGRATION_ARCHITECTURE.md
# - test/features/ga_release_verification.feature
# - .claude/rules/functional-invariant.md
