@crash-recovery @resilience @sil6 @phase6
Feature: Crash Recovery and Fault Tolerance
  As a safety-critical system
  I want automatic recovery from various failure scenarios
  So that the system maintains high availability and data integrity

  Background:
    Given full swarm is running and healthy
    And the Digital Twin is synchronized with actual state
    And 7-Level RCA is available for failure analysis

  # ==========================================================================
  # SC-CRASH-001: Application container crash recovery
  # ==========================================================================
  @critical @app-crash
  Scenario: System recovers from primary app container crash
    Given indrajaal-ex-app-1 is the primary application node
    And it is handling active requests
    When indrajaal-ex-app-1 crashes with exit code 137 (OOM)
    Then the following recovery sequence should occur
      | Step | Action                              | Timeout |
      | 1    | Detect crash via health check       | 10s     |
      | 2    | Trigger 7-Level RCA                 | 5s      |
      | 3    | Capture crash diagnostics           | 15s     |
      | 4    | Restart container                   | 30s     |
      | 5    | Verify health                       | 20s     |
      | 6    | Resume traffic                      | 5s      |
    And requests should failover to indrajaal-ex-app-2 during recovery
    And the RCA report should identify "Out of Memory" as root cause
    And total recovery time should be less than 90 seconds

  # ==========================================================================
  # SC-CRASH-002: Database container crash recovery
  # ==========================================================================
  @critical @db-crash
  Scenario: System recovers from database container crash
    Given indrajaal-db-prod is running with active connections
    And WAL (Write-Ahead Logging) is enabled
    When indrajaal-db-prod crashes unexpectedly
    Then all application containers should detect DB unavailability
    And circuit breakers should open to prevent cascade failures
    And the database container should restart automatically
    And WAL recovery should restore last committed transactions
    And application containers should reconnect within 60 seconds
    And no data loss should occur for committed transactions

  # ==========================================================================
  # SC-CRASH-003: Zenoh router crash with quorum maintenance
  # ==========================================================================
  @quorum @zenoh-crash
  Scenario: System maintains quorum during Zenoh router crash
    Given all 3 Zenoh routers are healthy
    And 2oo3 quorum is achieved
    When zenoh-router-1 crashes unexpectedly
    Then 2oo3 quorum should still be maintained with 2 routers
    And the crashed router should restart automatically
    And the router should rejoin the mesh within 30 seconds
    And quorum should be restored to 3oo3
    And no message loss should occur during the disruption

  # ==========================================================================
  # SC-CRASH-004: Cascading failure prevention
  # ==========================================================================
  @critical @cascade-prevention
  Scenario: System prevents cascading failures
    Given all containers are healthy
    And circuit breakers are armed
    When indrajaal-obs-prod becomes unresponsive (not crashed)
    Then dependent services should detect the degradation
    And circuit breakers should trip after 3 failed health checks
    And the following isolation should occur
      | Service               | Action                  |
      | Telemetry publishing  | Queue locally           |
      | Metrics collection    | Graceful degradation    |
      | Log shipping          | Buffer to disk          |
    And the system should continue operating in degraded mode
    And an alert should be raised for operator attention

  # ==========================================================================
  # SC-CRASH-005: Network partition handling
  # ==========================================================================
  @network @partition
  Scenario: System handles network partition gracefully
    Given full swarm is running across the mesh network
    When a network partition isolates Wave 5 containers
    Then Wave 1-4 containers should continue operating
    And Wave 5 containers should enter isolated mode
    And Zenoh routers should detect the partition
    And the Digital Twin should reflect the partition state
    And automatic recovery should occur when network heals

  # ==========================================================================
  # SC-CRASH-006: Cognitive plane (Cortex) crash recovery
  # ==========================================================================
  @cortex @cognitive
  Scenario: System recovers from cognitive plane crash
    Given indrajaal-cortex is running and processing AI requests
    When indrajaal-cortex crashes unexpectedly
    Then the cepaf-bridge should detect the disconnection
    And AI-assisted features should gracefully degrade
    And core system functionality should remain available
    And the Cortex container should restart automatically
    And AI features should resume within 60 seconds

  # ==========================================================================
  # SC-CRASH-007: Multiple simultaneous failures
  # ==========================================================================
  @critical @multi-failure
  Scenario: System handles multiple simultaneous failures
    Given full swarm is running and healthy
    When the following failures occur simultaneously
      | Container          | Failure Type    |
      | zenoh-router-3     | Crash           |
      | indrajaal-ex-app-3 | OOM             |
      | ml-runner-2        | Unresponsive    |
    Then the system should prioritize recovery by priority
      | Priority | Container          | Action          |
      | P0       | zenoh-router-3     | Restart first   |
      | P1       | indrajaal-ex-app-3 | Restart second  |
      | P2       | ml-runner-2        | Restart third   |
    And 2oo3 Zenoh quorum should be maintained throughout
    And all containers should recover within 120 seconds

  # ==========================================================================
  # SC-CRASH-008: State recovery from checkpoint
  # ==========================================================================
  @checkpoint @state-recovery
  Scenario: System recovers state from checkpoint after catastrophic failure
    Given a state checkpoint was taken 5 minutes ago
    And the checkpoint includes all 7 state locations
      | State Location | Captured |
      | FileSystem     | Yes      |
      | KMS            | Yes      |
      | Container      | Yes      |
      | Volume         | Yes      |
      | Zenoh          | Yes      |
      | DuckDB         | Yes      |
      | Environment    | Yes      |
    When a catastrophic failure requires full system restart
    Then I execute "sa-checkpoint-restore --phase full"
    And all containers should be restored to checkpoint state
    And the Digital Twin should be synchronized
    And state integrity should be verified via FPPS 5-method consensus
    And the system should be operational within 180 seconds
