# 9x9 Comprehensive Test Plan

## Version: 21.3.0-SIL6
## Date: 2026-01-11
## Status: ACTIVE

---

## 1. Executive Summary

This document defines the comprehensive 9x9 test matrix covering all features of the Indrajaal system. The matrix spans:

- **9 Test Types**: Unit, Property, Integration, Contract, E2E, Performance, Security, Chaos, BDD
- **9 Feature Domains**: SMRITI Semantic, Bridge, Elmish Client, API Routes, CRM Core, CRM Sales, CRM Automation, CRM Analytics, Cross-Domain

Total test coverage target: **100% critical paths, 95% overall**

---

## 2. Test Matrix Overview

```
                 ┌──────────────────────────────────────────────────────────────────┐
                 │                    9x9 TEST MATRIX                               │
                 ├────────┬────────┬────────┬────────┬────────┬────────┬────────┬────────┬────────┤
                 │  WS1   │  WS2   │  WS3   │  WS4   │  WS5   │  WS6   │  WS7   │  WS8   │  WS9   │
                 │ SMRITI   │ Bridge │ Client │  API   │  CRM   │ Sales  │ Auto   │Analyt  │ Cross  │
    ┌────────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
    │ L1 Unit    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │
    ├────────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
    │ L2 Property│   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │
    ├────────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
    │ L3 Integ   │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │
    ├────────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
    │ L4 Contract│   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │
    ├────────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
    │ L5 E2E     │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │
    ├────────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
    │ L6 Perf    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │
    ├────────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
    │ L7 Security│   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │
    ├────────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
    │ L8 Chaos   │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │
    ├────────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
    │ L9 BDD     │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │   ✓    │
    └────────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┘
```

---

## 3. Test Type Definitions

### L1 - Unit Tests
- **Purpose**: Test individual functions/modules in isolation
- **Tools**: ExUnit, Expecto (F#)
- **Coverage Target**: 100% for critical paths
- **Pattern**: Arrange-Act-Assert

### L2 - Property Tests
- **Purpose**: Verify invariants across random inputs
- **Tools**: PropCheck + ExUnitProperties (dual), FsCheck (F#)
- **Coverage Target**: All domain constraints
- **Pattern**: Generator → Property → Verification

### L3 - Integration Tests
- **Purpose**: Test component interactions
- **Tools**: ExUnit with database sandbox
- **Coverage Target**: All resource relationships
- **Pattern**: Setup → Execute → Assert → Teardown

### L4 - Contract Tests
- **Purpose**: Verify API contracts between services
- **Tools**: OpenAPI validation, Pact
- **Coverage Target**: All public APIs
- **Pattern**: Consumer → Provider contract verification

### L5 - E2E Tests
- **Purpose**: Test complete user journeys
- **Tools**: Wallaby, Puppeteer
- **Coverage Target**: All critical workflows
- **Pattern**: User scenario simulation

### L6 - Performance Tests
- **Purpose**: Verify latency and throughput requirements
- **Tools**: :timer.tc, Benchee
- **Coverage Target**: SC-PRF-050 (< 50ms response)
- **Pattern**: Load → Measure → Assert

### L7 - Security Tests
- **Purpose**: Verify security controls and isolation
- **Tools**: Sobelow, custom security tests
- **Coverage Target**: OWASP Top 10
- **Pattern**: Attack → Verify → Block

### L8 - Chaos Tests
- **Purpose**: Verify resilience under failure conditions
- **Tools**: Mara chaos engineering
- **Coverage Target**: All failure modes
- **Pattern**: Inject failure → Observe → Recover

### L9 - BDD Tests
- **Purpose**: Validate behavior against business requirements
- **Tools**: Cucumber/Gherkin, White Bread
- **Coverage Target**: All user stories
- **Pattern**: Given-When-Then

---

## 4. Feature Domain Details

### WS1: SMRITI Semantic Layer

**Test Files:**
- `test/property/smriti_properties_test.exs`
- `test/features/smriti/semantic_layer.feature`
- `lib/cepaf/src/Cepaf.Smriti.Tests/SemanticTests/*.fs`

**Key Test Areas:**
- Triple Store (Subject-Predicate-Object)
- Inference Engine
- Query Engine
- Virtual Graph
- Entropy/Decay Calculations
- Vector Search

### WS2: F#/Elixir Bridge

**Test Files:**
- `test/cepaf/bridge_test.exs`
- `test/features/cepaf/bridge.feature`
- `lib/cepaf/src/Cepaf.Smriti.Tests/BridgeTests/*.fs`

**Key Test Areas:**
- Serialization/Deserialization
- Message Ordering (FIFO)
- Sync Conflict Resolution
- Version Vector Consistency
- Latency Requirements

### WS3: Elmish Client

**Test Files:**
- `lib/cepaf/src/Cepaf.Smriti.Client/*.fs`
- `test/features/smriti/client.feature`

**Key Test Areas:**
- MVU Architecture
- Route Navigation
- Graph Rendering (Cytoscape.js)
- Search Functionality
- Entropy Visualization

### WS4: SMRITI API Routes

**Test Files:**
- `test/indrajaal_web/controllers/smriti/*_test.exs`
- `test/features/smriti/api_routes.feature`

**Key Test Areas:**
- REST Endpoints
- MCP Endpoints
- Authentication/Authorization
- Rate Limiting
- Error Handling

### WS5: CRM Core Domain

**Test Files:**
- `test/crm/lead_test.exs`
- `test/crm/account_test.exs`
- `test/crm/contact_test.exs`
- `test/features/crm/core_domain.feature`

**Key Test Areas:**
- Lead CRUD & Lifecycle
- Account Management
- Contact Management
- Data Validation
- Multi-tenancy

### WS6: CRM Sales Process

**Test Files:**
- `test/crm/opportunity_test.exs`
- `test/crm/quote_test.exs`
- `test/crm/order_test.exs`
- `test/features/crm/sales_process.feature`

**Key Test Areas:**
- Opportunity Pipeline
- Quote Creation & Approval
- Order Fulfillment
- Stage Transitions
- Pricing Calculations

### WS7: CRM Automation

**Test Files:**
- `test/crm/automation_test.exs`
- `test/features/crm/automation.feature`

**Key Test Areas:**
- Lead Assignment Rules
- Workflow Rules
- Approval Processes
- Email Templates
- Scheduled Tasks

### WS8: CRM Analytics

**Test Files:**
- `test/crm/analytics_test.exs`
- `test/features/crm/analytics.feature`

**Key Test Areas:**
- Pipeline Metrics
- Forecasting
- Quota Tracking
- Report Generation
- Dashboard KPIs

### WS9: Cross-Domain Integration

**Test Files:**
- `test/integration/cross_domain_test.exs`
- `test/features/integration/cross_domain.feature`

**Key Test Areas:**
- SMRITI → CRM Integration
- Prajna → CRM Integration
- Zenoh Telemetry
- Event Propagation
- Multi-system Workflows

---

## 5. BDD Feature Files

### 5.1 SMRITI Semantic Layer BDD

```gherkin
Feature: SMRITI Semantic Layer
  As a knowledge worker
  I want to manage knowledge graphs
  So that I can discover insights and connections

  Background:
    Given the SMRITI system is running
    And the triple store is initialized

  @unit @semantic
  Scenario: Create a new zettel
    Given I have a valid zettel with title "Knowledge Management"
    When I create the zettel in the store
    Then the zettel should be persisted
    And a unique ID should be assigned
    And the creation timestamp should be set

  @unit @semantic
  Scenario: Add triple to store
    Given I have a subject "zettel_001"
    And I have a predicate "links_to"
    And I have an object "zettel_002"
    When I add the triple to the store
    Then the triple should be queryable
    And the backlink should be created

  @property @semantic
  Scenario Outline: Triple constraints are enforced
    Given I have a triple with <subject>, <predicate>, <object>
    When I validate the triple
    Then the result should be <valid>

    Examples:
      | subject     | predicate   | object      | valid |
      | zettel_001  | links_to    | zettel_002  | true  |
      | ""          | links_to    | zettel_002  | false |
      | zettel_001  | ""          | zettel_002  | false |

  @integration @inference
  Scenario: Transitive closure inference
    Given zettel A links to zettel B
    And zettel B links to zettel C
    When I compute the transitive closure
    Then zettel A should have an indirect link to zettel C

  @e2e @graph
  Scenario: Full knowledge graph navigation
    Given I have a knowledge graph with 100 zettels
    When I navigate from the root zettel
    And I follow 5 links
    Then I should reach a valid destination zettel
    And my navigation path should be recorded

  @performance
  Scenario: Query performance under load
    Given I have 10000 triples in the store
    When I execute a pattern query
    Then the response time should be under 100ms

  @security
  Scenario: Tenant isolation in queries
    Given I am authenticated as tenant "tenant_a"
    And there are zettels for tenant "tenant_b"
    When I query all zettels
    Then I should only see zettels for tenant "tenant_a"

  @chaos
  Scenario: Recovery from database corruption
    Given I have 1000 zettels in the store
    When a database corruption occurs
    Then the system should detect the corruption
    And the system should recover from the last checkpoint
    And no data should be permanently lost
```

### 5.2 CRM Core Domain BDD

```gherkin
Feature: CRM Core Domain
  As a sales representative
  I want to manage leads, accounts, and contacts
  So that I can track and convert prospects

  Background:
    Given I am logged in as a sales user
    And I have access to the CRM module

  @unit @lead
  Scenario: Create new lead
    Given I have lead details:
      | first_name | John           |
      | last_name  | Doe            |
      | company    | Acme Corp      |
      | email      | john@acme.com  |
    When I create the lead
    Then the lead status should be "new"
    And the lead should have a unique ID
    And the created_at timestamp should be set

  @property @lead
  Scenario: Lead scoring is bounded
    Given I have random lead attributes
    When I calculate the lead score
    Then the score should be between 0 and 100

  @integration @conversion
  Scenario: Lead conversion creates related records
    Given I have a qualified lead for "Tech Corp"
    When I convert the lead
    Then an Account "Tech Corp" should be created
    And a Contact should be linked to the account
    And an Opportunity should be created
    And the lead status should be "converted"

  @e2e @lifecycle
  Scenario: Complete lead lifecycle
    Given I receive a new web lead
    When I contact the lead via phone
    And I qualify the lead
    And I convert the lead to opportunity
    Then the lead should progress through all stages
    And all activities should be logged
    And the conversion should be complete

  @performance @bulk
  Scenario: Bulk lead import
    Given I have a CSV with 1000 leads
    When I import the leads
    Then all leads should be created
    And the import should complete in under 30 seconds

  @security @access
  Scenario: Lead access control
    Given user "Alice" owns lead "Lead_001"
    And user "Bob" is not a manager
    When Bob tries to view "Lead_001"
    Then access should be denied
    And an audit log entry should be created

  @chaos @concurrent
  Scenario: Concurrent lead updates
    Given 10 users are updating the same lead
    When they update different fields simultaneously
    Then all updates should be applied correctly
    And no data should be lost
```

### 5.3 CRM Sales Process BDD

```gherkin
Feature: CRM Sales Process
  As a sales manager
  I want to track opportunities through the pipeline
  So that I can forecast revenue accurately

  Background:
    Given the sales pipeline is configured
    And I have active opportunities

  @unit @opportunity
  Scenario: Create opportunity from account
    Given I have an account "Enterprise Inc"
    When I create an opportunity with amount $500,000
    Then the opportunity should be in "prospecting" stage
    And the probability should be 10%
    And the close date should be 90 days ahead

  @property @pipeline
  Scenario: Weighted pipeline calculation
    Given I have multiple opportunities with varying amounts and probabilities
    When I calculate the weighted pipeline
    Then it should equal sum of (amount * probability) for all opportunities

  @integration @quote
  Scenario: Quote creation from opportunity
    Given I have an opportunity in "proposal" stage
    When I create a quote with line items
    Then the quote should be linked to the opportunity
    And the quote total should match line item calculations

  @e2e @sales_cycle
  Scenario: Full sales cycle from lead to order
    Given a new lead "Big Deal Corp" arrives
    When I qualify and convert the lead
    And I progress the opportunity to proposal
    And I create and approve a quote
    And the customer accepts the quote
    And I convert the quote to an order
    Then the order should be in "draft" status
    And the full audit trail should be available

  @performance @forecast
  Scenario: Forecast calculation for 1000 opportunities
    Given I have 1000 active opportunities
    When I calculate the quarterly forecast
    Then the calculation should complete in under 500ms

  @security @approval
  Scenario: Discount approval workflow
    Given I have a quote with 30% discount
    When I submit the quote for approval
    Then it should route to the sales manager
    And without approval the quote cannot be sent

  @chaos @status_race
  Scenario: Concurrent stage updates
    Given an opportunity in "negotiation" stage
    When two users update the stage simultaneously
    Then only one update should succeed
    And the opportunity should have a valid final state
```

### 5.4 CRM Automation BDD

```gherkin
Feature: CRM Automation
  As a sales operations manager
  I want to automate lead assignment and workflows
  So that leads are handled efficiently

  Background:
    Given automation rules are configured
    And assignment queues are set up

  @unit @assignment
  Scenario: Round-robin lead assignment
    Given I have 3 agents: Alice, Bob, Carol
    When 9 leads arrive
    Then each agent should receive 3 leads

  @property @fair_assignment
  Scenario: Assignment is fair across agents
    Given any number of leads and agents
    When leads are assigned round-robin
    Then the max difference between agent counts should be 1

  @integration @workflow
  Scenario: Workflow triggers on status change
    Given a workflow rule: "When lead status = qualified, notify manager"
    When a lead status changes to "qualified"
    Then the manager notification should be sent
    And the workflow execution should be logged

  @e2e @automation_chain
  Scenario: Chained automation rules
    Given a new web lead arrives
    When the lead is created
    Then it should be assigned to the web queue
    And a welcome email should be sent
    And a follow-up task should be created
    And the SLA timer should start

  @performance @rule_execution
  Scenario: Workflow rule execution performance
    Given 100 active workflow rules
    When a record triggers rule evaluation
    Then all applicable rules should execute in under 200ms

  @security @rule_access
  Scenario: Only admins can modify workflow rules
    Given a non-admin user
    When they try to modify a workflow rule
    Then the modification should be rejected
    And a security alert should be logged

  @chaos @concurrent_triggers
  Scenario: Concurrent workflow triggers
    Given a workflow rule that updates a field
    When 50 records trigger the rule simultaneously
    Then all records should be updated correctly
    And no deadlocks should occur
```

### 5.5 CRM Analytics BDD

```gherkin
Feature: CRM Analytics
  As a sales executive
  I want to view pipeline metrics and forecasts
  So that I can make informed decisions

  Background:
    Given I have access to analytics dashboard
    And historical data is available

  @unit @metrics
  Scenario: Pipeline value calculation
    Given opportunities with values: $100K, $200K, $300K
    When I calculate total pipeline value
    Then the result should be $600K

  @property @conversion_rate
  Scenario: Conversion rate is bounded [0, 1]
    Given any set of opportunities across stages
    When I calculate stage conversion rates
    Then all rates should be between 0 and 1

  @integration @forecast
  Scenario: Forecast includes weighted opportunities
    Given opportunities with different probabilities
    When I generate the quarterly forecast
    Then the forecast should use weighted values
    And closed-won should use 100% weight

  @e2e @dashboard
  Scenario: Complete dashboard rendering
    Given I navigate to the analytics dashboard
    When the dashboard loads
    Then I should see pipeline metrics
    And I should see conversion funnel
    And I should see forecast vs actual
    And I should see top opportunities

  @performance @aggregation
  Scenario: Large dataset aggregation
    Given 10000 historical opportunities
    When I generate the annual report
    Then the report should complete in under 2 seconds

  @security @data_access
  Scenario: Analytics respects data access rules
    Given user "Rep1" owns 50 opportunities
    And user "Rep2" owns 50 different opportunities
    When "Rep1" views their analytics
    Then they should only see their own data
    And aggregates should only include their records

  @chaos @concurrent_reports
  Scenario: Concurrent report generation
    Given 10 users request the same report simultaneously
    When reports are generated
    Then all users should receive consistent results
    And server resources should not be exhausted
```

### 5.6 Cross-Domain Integration BDD

```gherkin
Feature: Cross-Domain Integration
  As a system administrator
  I want all domains to work together seamlessly
  So that users have a unified experience

  Background:
    Given all system domains are running
    And Zenoh mesh is connected

  @integration @smriti_crm
  Scenario: SMRITI knowledge enhances CRM context
    Given a CRM opportunity for "AI Project"
    When I view the opportunity
    Then related SMRITI zettels should be suggested
    And knowledge graph links should be displayed

  @integration @prajna_crm
  Scenario: Prajna monitors CRM health
    Given CRM has 1000 active records
    When Prajna runs health assessment
    Then CRM health score should be reported
    And anomalies should be flagged

  @e2e @unified_workflow
  Scenario: Cross-domain workflow execution
    Given a lead converts to opportunity
    When the opportunity is created
    Then SMRITI should index related knowledge
    And Prajna should update metrics
    And Zenoh should broadcast the event

  @performance @event_propagation
  Scenario: Event propagation latency
    Given a CRM event occurs
    When the event propagates through Zenoh
    Then all subscribers should receive it
    And total latency should be under 100ms

  @chaos @domain_failure
  Scenario: System resilience to domain failure
    Given all domains are operational
    When the SMRITI domain becomes unavailable
    Then CRM should continue to function
    And degraded mode should be indicated
    And recovery should be automatic when SMRITI returns
```

---

## 6. Test Execution Commands

### Run All Tests
```bash
devenv shell
SKIP_ZENOH_NIF=0 mix test --cover
```

### Run by Level
```bash
# L1 Unit Tests
mix test --only unit

# L2 Property Tests
mix test --only property

# L3 Integration Tests
mix test --only integration

# L5 E2E Tests
mix test --only e2e

# L6 Performance Tests
mix test --only performance

# L7 Security Tests
mix test --only security

# L8 Chaos Tests
mix test --only chaos
```

### Run by Domain
```bash
# CRM Tests
mix test test/crm/

# SMRITI Tests
mix test test/property/smriti_properties_test.exs

# Property Tests
mix test test/property/
```

### Run F# Tests
```bash
cd lib/cepaf/src
dotnet test
```

---

## 7. STAMP Constraints Coverage

| ID | Constraint | Test Coverage |
|----|------------|---------------|
| SC-COV-001 | 100% critical paths | L1-L9 all domains |
| SC-COV-002 | 95% overall coverage | mix test --cover |
| SC-TDG-001 | TDG compliance | All property tests |
| SC-PROP-023 | PC/SD aliases | All property tests |
| SC-ASH-004 | require_atomic? | CRM resource tests |
| SC-PRF-050 | < 50ms response | L6 performance tests |
| SC-SEC-044 | Security scan | L7 security tests |
| SC-KMS-001 | Read-only holons.db | SMRITI tests |

---

## 8. Test Metrics & KPIs

| Metric | Target | Current |
|--------|--------|---------|
| Total Test Count | 500+ | TBD |
| Code Coverage | 95% | TBD |
| Property Test Coverage | 100% constraints | TBD |
| BDD Scenario Coverage | 100% user stories | TBD |
| Performance Test Pass Rate | 100% | TBD |
| Security Test Pass Rate | 100% | TBD |
| Chaos Test Recovery Rate | 100% | TBD |

---

## 9. Test File Inventory

### Elixir Test Files
```
test/
├── crm/
│   ├── lead_test.exs
│   ├── account_test.exs
│   ├── contact_test.exs
│   ├── opportunity_test.exs
│   ├── quote_test.exs
│   ├── order_test.exs
│   ├── automation_test.exs
│   └── analytics_test.exs
├── property/
│   ├── smriti_properties_test.exs
│   ├── crm_properties_test.exs
│   ├── core_modules_property_test.exs
│   └── api_validation_property_test.exs
├── features/
│   ├── crm/
│   │   ├── core_domain.feature
│   │   ├── sales_process.feature
│   │   ├── automation.feature
│   │   └── analytics.feature
│   ├── smriti/
│   │   ├── semantic_layer.feature
│   │   ├── api_routes.feature
│   │   └── client.feature
│   └── integration/
│       └── cross_domain.feature
└── integration/
    └── cross_domain_test.exs
```

### F# Test Files
```
lib/cepaf/src/
├── Cepaf.Smriti.Tests/
│   ├── SemanticTests/
│   │   ├── TripleStoreTests.fs
│   │   ├── InferenceTests.fs
│   │   └── QueryEngineTests.fs
│   ├── BridgeTests/
│   │   ├── SerializationTests.fs
│   │   └── SyncTests.fs
│   └── IntegrationTests/
│       └── CrossRuntimeTests.fs
└── Cepaf.Tests/
    └── Main.fs
```

---

## 10. Continuous Integration

### CI Pipeline Stages
1. **Compile**: `mix compile --warnings-as-errors`
2. **Format**: `mix format --check-formatted`
3. **Credo**: `mix credo --strict`
4. **L1-L2 Tests**: `mix test --only unit --only property`
5. **L3-L5 Tests**: `mix test --only integration --only e2e`
6. **L6 Performance**: `mix test --only performance`
7. **L7 Security**: `mix sobelow && mix test --only security`
8. **L8 Chaos**: `mix test --only chaos`
9. **Coverage Report**: `mix coveralls.html`

### Quality Gates
- All tests pass: **REQUIRED**
- Coverage >= 95%: **REQUIRED**
- No security issues: **REQUIRED**
- Performance within bounds: **REQUIRED**

---

## 11. Document Control

| Field | Value |
|-------|-------|
| Version | 21.3.0-SIL6 |
| Author | Claude Opus 4.5 |
| Created | 2026-01-11 |
| STAMP | SC-COV-001 to SC-COV-007 |
| Status | ACTIVE |

---

**End of Test Plan**
