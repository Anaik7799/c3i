@swarm @15-containers @3oo4-quorum @sil6 @phase6
Feature: Full Swarm Boot Sequence
  As a system operator
  I want to boot the full 15-container swarm mesh
  So that I have a production-ready SIL-6 biomorphic system

  Background:
    Given the system meets the following prerequisites
      | Requirement        | Value                    |
      | Podman version     | >= 5.4.1                 |
      | Available memory   | >= 32GB                  |
      | Available CPU      | >= 16 cores              |
      | Network available  | indrajaal-mesh           |
    And no Indrajaal containers are currently running

  # ==========================================================================
  # SC-SWARM-001: Full swarm boot with all 15 containers
  # ==========================================================================
  @critical @happy-path
  Scenario: Full swarm boots successfully with all 15 containers
    When I execute "sa-swarm-up"
    Then the following containers should be running
      | Container            | Wave | Priority |
      | indrajaal-db-prod    | 1    | P0       |
      | indrajaal-obs-prod   | 2    | P1       |
      | zenoh-router-1       | 2    | P0       |
      | zenoh-router-2       | 2    | P0       |
      | zenoh-router-3       | 2    | P0       |
      | cepaf-bridge         | 3    | P1       |
      | indrajaal-cortex     | 3    | P1       |
      | indrajaal-ex-app-1   | 4    | P0       |
      | indrajaal-ex-app-2   | 5    | P1       |
      | indrajaal-ex-app-3   | 5    | P1       |
      | indrajaal-chaya      | 5    | P1       |
      | ml-runner-1          | 5    | P2       |
      | ml-runner-2          | 5    | P2       |
    And 15 containers should be running in total
    And Zenoh 3oo4 quorum should be achieved
    And all biomorphic subsystems should report healthy
    And the boot time should be less than 120 seconds

  # ==========================================================================
  # SC-SWARM-002: Wave-based boot ordering
  # ==========================================================================
  @critical @dag
  Scenario: Containers boot in correct wave order following DAG
    When I execute "sa-swarm-up" with verbosity "verbose"
    Then Wave 1 should complete before Wave 2 starts
    And Wave 2 should complete before Wave 3 starts
    And Wave 3 should complete before Wave 4 starts
    And Wave 4 should complete before Wave 5 starts
    And the dependency graph should have no cycles
    And the critical path duration should be logged

  # ==========================================================================
  # SC-SWARM-003: 2oo3 Zenoh quorum verification
  # ==========================================================================
  @critical @quorum
  Scenario: Zenoh 2oo3 quorum is verified after router boot
    Given Wave 1 (Foundation) has completed successfully
    When Wave 2 (Observability + Zenoh) completes
    Then at least 2 of 3 Zenoh routers should be healthy
    And the system should report "Quorum Achieved: 2oo3"
    And each Zenoh router should be publishing to "indrajaal/mesh/health"

  # ==========================================================================
  # SC-SWARM-004: Single Zenoh router failure tolerance
  # ==========================================================================
  @resilience @quorum
  Scenario: Swarm handles single Zenoh router failure
    Given full swarm is running with 3 Zenoh routers
    When zenoh-router-3 stops unexpectedly
    Then 2oo3 quorum should still be achieved
    And the system should remain operational
    And an alert should be raised for "DEGRADED: Zenoh quorum at 2/3"
    And the Digital Twin state should reflect the degraded router

  # ==========================================================================
  # SC-SWARM-005: Dual Zenoh router failure detection
  # ==========================================================================
  @critical @quorum @failure
  Scenario: Swarm detects loss of quorum with 2 router failures
    Given full swarm is running with 3 Zenoh routers
    When zenoh-router-2 stops unexpectedly
    And zenoh-router-3 stops unexpectedly
    Then 2oo3 quorum should NOT be achieved
    And the system should report "CRITICAL: Quorum Lost"
    And 7-Level RCA should be triggered automatically
    And the RCA report should identify "Multiple Zenoh router failures"

  # ==========================================================================
  # SC-SWARM-006: Boot rollback on critical failure
  # ==========================================================================
  @critical @rollback
  Scenario: Boot sequence rolls back on critical container failure
    Given Wave 1 has completed successfully
    And Wave 2 is in progress
    When indrajaal-obs-prod fails to start with error "Port 4317 in use"
    Then the boot sequence should initiate rollback
    And all Wave 2 containers should be stopped
    And Wave 1 containers should remain running
    And 7-Level RCA should execute with the failure message

  # ==========================================================================
  # SC-SWARM-007: Graceful shutdown with checkpointing
  # ==========================================================================
  @shutdown @checkpoint
  Scenario: Graceful swarm shutdown preserves state
    Given full swarm is running and healthy
    When I execute "sa-swarm-down"
    Then containers should stop in reverse wave order
    And state checkpoints should be saved for each container
    And the Digital Twin state should be persisted
    And all 15 containers should be stopped within 60 seconds

  # ==========================================================================
  # SC-SWARM-008: Metrics export after boot
  # ==========================================================================
  @metrics @observability
  Scenario: Boot metrics are captured and exportable
    Given full swarm has booted successfully
    When I execute "sa-swarm-up -- metrics"
    Then a metrics JSON file should exist at "./data/tmp/swarm-boot-metrics.json"
    And the metrics should include
      | Metric                  | Type     |
      | TotalDurationMs         | integer  |
      | PhaseDurations          | map      |
      | ContainerStartTimes     | map      |
      | HealthCheckLatencies    | map      |
      | QuorumAchievedAt        | datetime |
      | TestsRun                | integer  |
      | TestsPassed             | integer  |
