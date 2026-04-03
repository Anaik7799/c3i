@ha_mesh @sil6 @e2e
Feature: End-to-End HA Mesh Scenarios
  As a system operator
  I want comprehensive end-to-end validation
  So that I can trust the HA mesh in production

  Background:
    Given the SIL-6 HA mesh is deployed with 12 containers
    And all services report healthy status
    And Zenoh 2oo3 quorum is established

  # =============================================================================
  # SCENARIO 1: Complete Request Lifecycle
  # =============================================================================

  @P0 @request_lifecycle
  Scenario: Complete API request through HA stack
    Given a client connects to HAProxy on port 4000
    When the client sends a GET request to /api/health
    Then the request should be routed to one of app-1, app-2, app-3
    And the response should return within 100ms
    And the response should contain JSON with health status
    And telemetry should be sent to observability stack
    And the request should be logged in all 4 outputs (Quadplex)

  @P0 @prajna_cockpit
  Scenario: Prajna C3I Cockpit access in HA mode
    Given a user navigates to http://localhost:4000/prajna
    When the Prajna cockpit loads
    Then metrics should be aggregated from all 3 app nodes
    And the health score should reflect cluster state
    And Sentinel integration should show threat advisories
    And AI Copilot should be available
    And the dashboard should refresh every 30 seconds

  # =============================================================================
  # SCENARIO 2: Node Failure and Recovery
  # =============================================================================

  @P0 @failover_scenario
  Scenario: Complete failover sequence
    Given all 3 app nodes are handling traffic equally
    When app-2 crashes unexpectedly
    Then the following sequence should occur within 60 seconds:
      | Step | Event | Max Time |
      | 1 | HAProxy detects health check failure | 30s |
      | 2 | HAProxy removes app-2 from pool | 1s |
      | 3 | Traffic redistributes to app-1 and app-3 | 1s |
      | 4 | Alert fires to operators | 5s |
      | 5 | Podman restart policy triggers | 10s |
      | 6 | app-2 begins recovery | 30s |
    And no requests should fail during the failover
    And total throughput should remain above 66%

  @P0 @recovery_scenario
  Scenario: Node recovery and rejoin
    Given app-2 was previously crashed
    And app-2 is restarting
    When app-2 passes 3 consecutive health checks
    Then app-2 should rejoin the HAProxy pool
    And load should redistribute across all 3 nodes
    And cluster status should return to healthy
    And metrics should show recovery event

  # =============================================================================
  # SCENARIO 3: Database Consistency
  # =============================================================================

  @P0 @database_consistency
  Scenario: Write consistency across cluster
    Given a write request is sent through HAProxy
    And the request is routed to app-1
    When app-1 commits data to PostgreSQL
    Then the data should be immediately visible from app-2
    And the data should be immediately visible from app-3
    And all nodes should see consistent state
    And TimescaleDB should handle time-series data

  @P1 @connection_pooling
  Scenario: Database connection pool management
    Given each app has its own connection pool
    When 100 concurrent requests arrive
    Then connection pools should handle the load
    And no connection exhaustion should occur
    And pool metrics should be reported to observability

  # =============================================================================
  # SCENARIO 4: Zenoh Message Bus
  # =============================================================================

  @P0 @zenoh_messaging
  Scenario: Real-time message delivery via Zenoh
    Given app-1 publishes to "indrajaal/kpi/health"
    When the message enters the Zenoh mesh
    Then all subscribers should receive the message
    And delivery should complete within 50ms
    And message ordering should be preserved
    And Zenoh quorum should log the event

  @P1 @zenoh_failover
  Scenario: Zenoh router failover
    Given zenoh-1 is the primary router
    When zenoh-1 crashes
    Then messages should route through zenoh-2 or zenoh-3
    And no messages should be lost
    And quorum should remain valid (2oo3)
    And subscribers should reconnect automatically

  # =============================================================================
  # SCENARIO 5: Build Cache Synchronization
  # =============================================================================

  @P0 @build_sync
  Scenario: Clean start with shared build cache
    Given the HA mesh is starting fresh
    And build cache volumes are empty
    When the startup sequence begins
    Then app-1 should compile first (using service_healthy)
    And app-1 health check should pass after compilation
    And app-2 should start only after app-1 is healthy
    And app-3 should start only after app-1 is healthy
    And app-2 and app-3 should skip compilation (cache hit)
    And total startup time should be under 20 minutes

  @P1 @incremental_build
  Scenario: Incremental build on code change
    Given the HA mesh is running with built cache
    When a code change is made to lib/indrajaal/some_module.ex
    And the mesh is restarted
    Then app-1 should perform incremental compilation
    And compilation should complete faster than cold start
    And app-2 and app-3 should see the updated cache

  # =============================================================================
  # SCENARIO 6: Observability Integration
  # =============================================================================

  @P0 @observability
  Scenario: Full observability stack operational
    Given the observability container is healthy
    When requests flow through the HA mesh
    Then OTEL traces should be sent to collector (port 4317)
    And metrics should be scraped by Prometheus (port 9090)
    And logs should be aggregated by Loki (port 3100)
    And Grafana dashboards should display data (port 3000)
    And Zenoh should publish telemetry events

  @P1 @quadplex_logging
  Scenario: Quadplex logging across all outputs
    Given QUADPLEX_LOGGING is enabled
    When a request is processed
    Then logs should appear in console output
    And logs should be written to file (/app/data/logs)
    And logs should be sent to OTEL collector
    And logs should be published to Zenoh mesh

  # =============================================================================
  # SCENARIO 7: CEPAF Integration
  # =============================================================================

  @P1 @cepaf_bridge
  Scenario: CEPAF Bridge F# integration
    Given the cepaf-bridge container is healthy
    And cortex container is healthy
    When a cognitive operation is requested
    Then the request should reach CEPAF bridge on port 9876
    And F# processing should occur
    And response should return to Elixir layer
    And Zenoh should carry the cognitive events

  @P2 @cortex_operations
  Scenario: Cortex AI operations
    Given the cortex container is connected to CEPAF bridge
    When an AI decision is requested
    Then cortex should process the request
    And telemetry should be sent to OTEL
    And results should be published to Zenoh topic "indrajaal/decisions"

  # =============================================================================
  # SCENARIO 8: Security and Compliance
  # =============================================================================

  @P0 @security
  Scenario: Erlang cluster security
    Given RELEASE_COOKIE is set to "ha_mesh_cookie_sil6"
    When a node attempts to join without the correct cookie
    Then the connection should be rejected
    And the cluster should remain isolated
    And a security alert should be logged

  @P1 @secret_management
  Scenario: Secret key base consistency
    Given SECRET_KEY_BASE is the same across all nodes
    When a session is created on app-1
    Then the session should be valid on app-2
    And the session should be valid on app-3
    And no session decryption errors should occur

  # =============================================================================
  # SCENARIO 9: Performance Under Load
  # =============================================================================

  @P1 @load_testing
  Scenario: Performance under sustained load
    Given the HA mesh is healthy
    When 1000 requests per second are sent for 60 seconds
    Then p50 latency should remain under 50ms
    And p99 latency should remain under 200ms
    And error rate should remain under 0.1%
    And no node should become overloaded

  @P2 @burst_handling
  Scenario: Burst traffic handling
    Given the HA mesh is at 30% capacity
    When a burst of 10000 requests arrives in 1 second
    Then the system should apply backpressure
    And some requests may be queued
    And no requests should cause crashes
    And the system should recover to normal within 30 seconds

  # =============================================================================
  # SCENARIO 10: Disaster Recovery
  # =============================================================================

  @P0 @disaster_recovery
  Scenario: Recovery from complete mesh failure
    Given all containers have crashed
    When the mesh is restarted
    Then containers should start in dependency order
    And database should recover from persistent storage
    And holon state should recover from DuckDB
    And Zenoh quorum should re-establish
    And service should be available within 5 minutes

  @P1 @checkpoint_restore
  Scenario: Restore from checkpoint
    Given a checkpoint was created before failure
    When the restore command is executed
    Then all 7 state locations should be restored
    And constitutional invariants should be verified
    And the system should return to the checkpointed state
    And no data should be lost
