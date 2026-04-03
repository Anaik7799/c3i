@smoke-tests @comprehensive @sil6 @phase6
Feature: Comprehensive Smoke Tests
  As a system operator
  I want to run comprehensive smoke tests across all 7 categories
  So that I can verify system health after deployment

  Background:
    Given full swarm is running and healthy
    And all 100+ smoke tests are available
    And test results are captured for evidence collection

  # ==========================================================================
  # CATEGORY 1: API Endpoints (10 tests)
  # ==========================================================================
  @api @category-1
  Scenario: API endpoint smoke tests pass
    When I run smoke tests for category "API Endpoints"
    Then all 10 API endpoint tests should pass
    And the following endpoints should return 200 OK
      | Endpoint                  | Method | Expected Status |
      | /                         | GET    | 200             |
      | /health                   | GET    | 200             |
      | /api/health               | GET    | 200             |
      | /prajna                   | GET    | 200             |
      | /prajna/copilot           | GET    | 200             |
      | /api/prajna/metrics       | GET    | 200             |
    And response times should be under 100ms for health endpoints
    And response times should be under 500ms for dashboard endpoints

  @api @critical
  Scenario: Critical API endpoints are highly available
    Given the Phoenix application is load-balanced across app containers
    When I send 100 requests to "/api/health" in parallel
    Then at least 99% of requests should succeed
    And p99 latency should be under 200ms
    And no requests should timeout

  # ==========================================================================
  # CATEGORY 2: Database Consistency (8 tests)
  # ==========================================================================
  @database @category-2
  Scenario: Database consistency tests pass
    When I run smoke tests for category "Database Consistency"
    Then all 8 database consistency tests should pass
    And the following checks should succeed
      | Check                           | Expected Result |
      | Connection pool active          | Yes             |
      | Read replica sync               | < 100ms lag     |
      | Transaction isolation           | SERIALIZABLE    |
      | Index health                    | No unused       |
      | Schema version                  | Current         |
    And no database locks should be stale
    And TimescaleDB hypertables should be healthy

  @database @critical
  Scenario: Database handles concurrent writes correctly
    Given the database is accepting connections
    When 50 concurrent write transactions are executed
    Then all transactions should complete successfully
    And no deadlocks should occur
    And data integrity should be maintained

  # ==========================================================================
  # CATEGORY 3: Cross-Node Communication (8 tests)
  # ==========================================================================
  @cross-node @category-3
  Scenario: Cross-node communication tests pass
    When I run smoke tests for category "Cross-Node Communication"
    Then all 8 cross-node tests should pass
    And the following communication paths should be verified
      | Source               | Destination          | Protocol |
      | indrajaal-ex-app-1   | indrajaal-db-prod    | TCP      |
      | indrajaal-ex-app-1   | zenoh-router-1       | Zenoh    |
      | cepaf-bridge         | indrajaal-cortex     | HTTP     |
      | indrajaal-obs-prod   | All containers       | OTEL     |
    And Zenoh pub/sub should work across all nodes
    And message latency should be under 50ms within the mesh

  @cross-node @zenoh
  Scenario: Zenoh mesh handles message burst correctly
    Given all Zenoh routers are healthy
    When I publish 1000 messages to "indrajaal/test/burst"
    Then all subscribers should receive all messages
    And message order should be preserved
    And no messages should be dropped

  # ==========================================================================
  # CATEGORY 4: Performance Baseline (8 tests)
  # ==========================================================================
  @performance @category-4
  Scenario: Performance baseline tests pass
    When I run smoke tests for category "Performance Baseline"
    Then all 8 performance tests should pass
    And the following metrics should meet baselines
      | Metric                    | Baseline      |
      | Phoenix response time     | < 50ms p95    |
      | DB query time             | < 10ms p95    |
      | Zenoh publish latency     | < 5ms p95     |
      | Memory usage per app      | < 2GB         |
      | CPU usage at idle         | < 5%          |
    And no memory leaks should be detected
    And garbage collection should be healthy

  @performance @load
  Scenario: System handles expected load gracefully
    Given the system is at idle baseline
    When I apply a load of 100 concurrent users for 60 seconds
    Then response time p99 should stay under 500ms
    And error rate should stay under 0.1%
    And CPU usage should stay under 70%
    And memory should not grow unbounded

  # ==========================================================================
  # CATEGORY 5: Security Validation (6 tests)
  # ==========================================================================
  @security @category-5
  Scenario: Security validation tests pass
    When I run smoke tests for category "Security Validation"
    Then all 6 security tests should pass
    And the following security checks should succeed
      | Check                         | Status   |
      | TLS enforced on all endpoints | Pass     |
      | Authentication required       | Pass     |
      | Security headers present      | Pass     |
      | No exposed secrets            | Pass     |
      | Container isolation           | Pass     |
      | Sobelow scan clean            | Pass     |

  # ==========================================================================
  # CATEGORY 6: Resilience (8 tests)
  # ==========================================================================
  @resilience @category-6
  Scenario: Resilience tests pass
    When I run smoke tests for category "Resilience"
    Then all 8 resilience tests should pass
    And the following resilience checks should succeed
      | Check                           | Expected Result |
      | Circuit breaker armed           | Yes             |
      | Retry policies configured       | Yes             |
      | Timeout policies configured     | Yes             |
      | Graceful degradation working    | Yes             |
      | Health checks responsive        | Yes             |
    And the system should recover from transient failures

  @resilience @chaos
  Scenario: System survives chaos engineering tests
    Given the system is running and healthy
    When I introduce 10% random network latency
    Then the system should remain operational
    And error rate should stay under 1%
    And no cascading failures should occur

  # ==========================================================================
  # CATEGORY 7: Integration (8 tests)
  # ==========================================================================
  @integration @category-7
  Scenario: Integration tests pass
    When I run smoke tests for category "Integration"
    Then all 8 integration tests should pass
    And the following integrations should be verified
      | Integration               | Status    |
      | Phoenix to PostgreSQL     | Connected |
      | OTEL to Observability     | Exporting |
      | Zenoh mesh connected      | 2oo3+     |
      | Cortex bridge active      | Connected |
      | Digital Twin synchronized | Yes       |
      | Immutable Register        | Healthy   |

  @integration @end-to-end
  Scenario: End-to-end user journey completes successfully
    Given a test user is authenticated
    When the user performs the following actions
      | Action                           | Expected Result |
      | Navigate to Prajna dashboard     | Page loads      |
      | View system health               | Score displayed |
      | Check Sentinel threats           | List rendered   |
      | Execute Guardian-approved action | Action succeeds |
    Then all actions should complete within 5 seconds
    And all pages should render without errors
    And telemetry should capture the journey

  # ==========================================================================
  # SUMMARY: All Categories Combined
  # ==========================================================================
  @comprehensive @all-categories
  Scenario: All 100+ smoke tests pass
    When I execute "sa-smoke-all" to run all smoke tests
    Then the total test count should be at least 100
    And the test summary should show
      | Category                  | Tests | Pass Rate |
      | API Endpoints             | 10    | 100%      |
      | Database Consistency      | 8     | 100%      |
      | Cross-Node Communication  | 8     | 100%      |
      | Performance Baseline      | 8     | 100%      |
      | Security Validation       | 6     | 100%      |
      | Resilience                | 8     | 100%      |
      | Integration               | 8     | 100%      |
    And P0 critical tests should all pass
    And the overall pass rate should be at least 95%
    And test results should be exported to JSON for evidence
