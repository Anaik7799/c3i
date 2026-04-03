@ha_mesh @sil6 @load_balancing
Feature: High Availability Load Balancing
  As a system operator
  I want requests distributed across 3 app nodes
  So that no single node becomes a bottleneck

  Background:
    Given the HA mesh is running with 12 containers
    And all 3 app nodes are healthy
    And HAProxy is configured for round-robin

  @P0 @availability
  Scenario: Even load distribution under normal conditions
    When 1000 requests are sent to the load balancer
    Then app-1 should receive approximately 333 requests
    And app-2 should receive approximately 333 requests
    And app-3 should receive approximately 333 requests
    And the distribution variance should be less than 5%
    And all requests should complete within 100ms p99

  @P0 @failover
  Scenario: Automatic failover on node failure
    Given app-2 becomes unhealthy
    When HAProxy performs health check
    Then app-2 should be removed from the pool within 30 seconds
    And subsequent requests should be distributed only to app-1 and app-3
    And no requests should fail during failover
    And an alert should be generated

  @P0 @recovery
  Scenario: Automatic recovery when node heals
    Given app-2 was previously unhealthy
    When app-2 health checks pass 3 consecutive times
    Then app-2 should be added back to the pool
    And requests should be distributed across all 3 nodes
    And metrics should show recovery event

  @P1 @graceful_degradation
  Scenario: Graceful degradation with 2 nodes down
    Given app-2 is down
    And app-3 is down
    When requests are sent to the load balancer
    Then all requests should be routed to app-1
    And app-1 should handle increased load
    And response times should remain under 500ms

  @P0 @split_brain_prevention
  Scenario: Split brain prevention during network partition
    Given a network partition occurs between app-1 and app-2,app-3
    When HAProxy detects the partition
    Then only one partition should accept writes
    And the other partition should return 503
    And no data inconsistency should occur

  @P1 @health_check_accuracy
  Scenario: Health check accurately reflects node state
    Given app-1 is processing requests normally
    When the health check runs every 10 seconds
    Then app-1 should consistently report healthy
    And no false positives should occur
    And health metrics should be published to observability

  @P2 @load_shedding
  Scenario: Load shedding under extreme pressure
    Given all 3 nodes are at 90% capacity
    When an additional burst of 10000 requests arrives
    Then HAProxy should apply backpressure
    And queued requests should timeout gracefully
    And the system should not crash
