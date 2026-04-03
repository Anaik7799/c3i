# STAMP: SC-BOOT-001 to SC-BOOT-010, SC-CONFIG-001 to SC-CONFIG-003
# AOR: AOR-MESH-001 to AOR-MESH-010, AOR-FUNC-001 to AOR-FUNC-008
# Methodology: Jidoka (自働化) + TPS + OODA Fast Loops
# Architecture: SIL-6 Biomorphic Fractal Mesh

@critical @startup @SC-BOOT-001 @jidoka
Feature: SIL-6 Biomorphic Mesh Startup Sequence
  As a system operator
  I want a deterministic, robust startup sequence
  So that the mesh achieves homeostasis reliably

  Background:
    Given the F# CEPAF environment is available
    And the centralized configuration is loaded from MeshConfig.fs
    And no containers are currently running

  # ============================================================================
  # S0_PREFLIGHT Stage - Environment Validation
  # ============================================================================

  @preflight @SC-BOOT-001 @gate-1
  Scenario: S0_PREFLIGHT - Environment verification passes
    Given I am in stage "S0_PREFLIGHT"
    When I verify the environment prerequisites
    Then the following checks should pass:
      | Check                    | Command                  | Expected        |
      | .NET SDK version         | dotnet --version         | >= 10.0.0       |
      | Podman availability      | podman --version         | >= 5.4.1        |
      | Port 4000 available      | ss -tlnp :4000           | not in use      |
      | Port 5433 available      | ss -tlnp :5433           | not in use      |
      | Port 7447 available      | ss -tlnp :7447           | not in use      |
      | Disk space              | df -h /                   | > 10GB free     |
    And the state vector should be "[1,_,_,_,_,_]"
    And the environment verification log should be written

  @preflight @SC-BOOT-001 @jidoka @negative
  Scenario: S0_PREFLIGHT - Jidoka halt on port conflict
    Given I am in stage "S0_PREFLIGHT"
    And port 5433 is already in use by another process
    When I attempt to verify the environment prerequisites
    Then the startup should HALT immediately per Jidoka principle
    And an error should be logged: "Port 5433 conflict - cannot proceed"
    And the state vector should remain "[0,_,_,_,_,_]"
    And the remediation suggestion should be "Kill process on port 5433 or change config"

  @preflight @SC-CONFIG-001 @centralized-config
  Scenario: S0_PREFLIGHT - Centralized configuration validation
    Given I am in stage "S0_PREFLIGHT"
    When I load the centralized configuration
    Then all port numbers should come from NetworkConfig.Ports
    And all IP addresses should come from NetworkConfig.IpAddresses
    And all hostnames should come from NetworkConfig.Hostnames
    And all timeouts should come from TimeoutConfig
    And no magic values should exist in boot code

  # ============================================================================
  # S1_INFRASTRUCTURE Stage - Database + Observability
  # ============================================================================

  @infrastructure @SC-BOOT-002 @gate-2
  Scenario: S1_INFRASTRUCTURE - Database container starts successfully
    Given I am in stage "S1_INFRASTRUCTURE"
    And stage "S0_PREFLIGHT" has completed with state vector "[1,_,_,_,_,_]"
    When I start the database container "indrajaal-db-prod"
    Then the container should be running within 30 seconds
    And PostgreSQL should accept connections on port 5433
    And the container IP should be "172.28.0.5" per MeshConfig.fs
    And the state vector should transition to "[1,1,_,_,_,_]"

  @infrastructure @SC-BOOT-002 @migrations @gate-3
  Scenario: S1_INFRASTRUCTURE - Database migrations verified
    Given I am in stage "S1_INFRASTRUCTURE"
    And the database container "indrajaal-db-prod" is running
    When I verify database migrations
    Then the following tables should exist:
      | Table Name    | Purpose                    |
      | oban_jobs     | Background job queue       |
      | oban_peers    | Distributed coordination   |
      | oban_beats    | Health heartbeat           |
      | users         | User accounts              |
      | audit_logs    | Immutable audit trail      |
    And the migration gate should pass
    And the state vector should include migrations valid

  @infrastructure @SC-BOOT-002 @jidoka @negative
  Scenario: S1_INFRASTRUCTURE - Jidoka halt on missing migrations
    Given I am in stage "S1_INFRASTRUCTURE"
    And the database container is running
    But the "oban_peers" table does not exist
    When I verify database migrations
    Then the startup should HALT immediately per Jidoka principle
    And the error should indicate "Missing Oban tables - run mix ecto.migrate"
    And no further containers should start
    And the state vector should remain "[1,0,_,_,_,_]"

  @infrastructure @SC-BOOT-002 @observability
  Scenario: S1_INFRASTRUCTURE - Observability stack starts
    Given I am in stage "S1_INFRASTRUCTURE"
    And database migrations have been verified
    When I start the observability container "indrajaal-obs-prod"
    Then the following services should be available:
      | Service     | Port  | Health Endpoint          |
      | OTEL        | 4317  | gRPC health check        |
      | Prometheus  | 9090  | /-/healthy               |
      | Grafana     | 3000  | /api/health              |
      | Loki        | 3100  | /ready                   |
    And the state vector should transition to "[1,1,1,_,_,_]"

  # ============================================================================
  # S2_ZENOH_MESH Stage - Control Plane Formation
  # ============================================================================

  @zenoh @SC-BOOT-003 @quorum @gate-4
  Scenario: S2_ZENOH_MESH - Zenoh router quorum achieved
    Given I am in stage "S2_ZENOH_MESH"
    And state vector is "[1,1,1,_,_,_]"
    When I start the Zenoh router cluster
    Then 3 Zenoh routers should start:
      | Router          | Port  | IP           |
      | zenoh-router-1  | 7447  | 172.28.0.20  |
      | zenoh-router-2  | 7448  | 172.28.0.21  |
      | zenoh-router-3  | 7449  | 172.28.0.22  |
    And quorum should be achieved with 2oo3 voting
    And the mathematical quorum formula should be Q = floor(3/2) + 1 = 2
    And the state vector should transition to "[1,1,1,1,_,_]"

  @zenoh @SC-SIL4-006 @2oo3-voting
  Scenario: S2_ZENOH_MESH - 2oo3 voting verification
    Given the Zenoh router cluster is running
    When I verify the voting configuration
    Then the system should use 2-out-of-3 (2oo3) voting
    And any 2 routers should be sufficient for consensus
    And single router failure should not impact operations
    And the quorum status should be "Achieved"

  @zenoh @SC-BOOT-003 @jidoka @negative
  Scenario: S2_ZENOH_MESH - Jidoka halt on quorum failure
    Given I am in stage "S2_ZENOH_MESH"
    And only 1 Zenoh router is running
    When I attempt to verify quorum
    Then the startup should HALT immediately per Jidoka principle
    And the error should indicate "Quorum not achieved: 1/3 routers (need 2)"
    And the Apoptosis protocol should be prepared for rollback
    And the state vector should remain "[1,1,1,0,_,_]"

  # ============================================================================
  # S3_APP_SEED Stage - Application Bootstrap
  # ============================================================================

  @app @SC-BOOT-004 @phoenix @gate-5
  Scenario: S3_APP_SEED - Phoenix application starts
    Given I am in stage "S3_APP_SEED"
    And state vector is "[1,1,1,1,_,_]"
    When I start the application container "indrajaal-ex-app-1"
    Then Phoenix should start on port 4000
    And the health endpoint should return 200 OK at "/health"
    And the following Elixir supervisors should be running:
      | Supervisor                        | Children |
      | Indrajaal.Application             | 10+      |
      | Indrajaal.Cockpit.PrajnaSupervisor| 20       |
      | Oban                              | 5+       |
    And the state vector should transition to "[1,1,1,1,1,_]"

  @app @SC-BOOT-004 @oban @critical
  Scenario: S3_APP_SEED - Oban GenServer starts successfully
    Given the application container is starting
    When Oban initializes
    Then the Oban.Registry should be available
    And the oban_peers table should be accessible
    And no "oban_peers table undefined" error should occur
    And background jobs should be processable

  @app @SC-BOOT-004 @jidoka @negative
  Scenario: S3_APP_SEED - Jidoka halt on Oban failure
    Given I am in stage "S3_APP_SEED"
    And database migrations were NOT run
    When the application container attempts to start
    Then Oban should fail with "oban_peers table undefined"
    And the startup should HALT immediately per Jidoka principle
    And the container should enter restart loop
    And the 7-Level RCA should identify:
      | Level | Finding                                    |
      | L1    | App container enters restart loop          |
      | L2    | Oban GenServer crashes                     |
      | L3    | Database migrations not verified           |
      | L4    | MeshStartup.fs lacks migration gate        |
      | L5    | No state vector check before S3            |
      | L6    | Missing pre/post condition contracts       |
      | L7    | No formal startup specification            |

  # ============================================================================
  # S4_HOMEOSTASIS Stage - Health Verification
  # ============================================================================

  @homeostasis @SC-BOOT-005 @fpps @gate-6
  Scenario: S4_HOMEOSTASIS - FPPS 5-point consensus achieved
    Given I am in stage "S4_HOMEOSTASIS"
    And state vector is "[1,1,1,1,1,_]"
    When I run FPPS 5-point consensus validation
    Then all 5 validators should pass:
      | Validator   | Method              | Weight | Result |
      | V1          | Pattern Matching    | 1.0    | PASS   |
      | V2          | AST Analysis        | 1.0    | PASS   |
      | V3          | Statistical         | 1.0    | PASS   |
      | V4          | Binary Check        | 1.0    | PASS   |
      | V5          | Line-by-Line        | 1.0    | PASS   |
    And consensus should be achieved with 5/5 passing
    And the state vector should transition to "[1,1,1,1,1,1]"

  @homeostasis @SC-BOOT-005 @fpps @threshold
  Scenario: S4_HOMEOSTASIS - FPPS passes with 3/5 majority
    Given I am in stage "S4_HOMEOSTASIS"
    When I run FPPS 5-point consensus validation
    And 3 validators pass and 2 validators fail
    Then consensus should still be achieved (3 >= 3 majority)
    And a warning should be logged about partial validation
    And the state vector should transition to "[1,1,1,1,1,1]"

  @homeostasis @SC-BOOT-005 @jidoka @negative
  Scenario: S4_HOMEOSTASIS - Jidoka halt on FPPS failure
    Given I am in stage "S4_HOMEOSTASIS"
    When I run FPPS 5-point consensus validation
    And only 2 validators pass
    Then the startup should HALT immediately per Jidoka principle
    And the error should indicate "FPPS failed: 2/5 validators passed (need 3)"
    And full 7-Level RCA should be triggered
    And manual intervention should be required
    And the state vector should remain "[1,1,1,1,1,0]"

  @homeostasis @SC-BOOT-006 @full-system
  Scenario: S4_HOMEOSTASIS - Full system health verification
    Given I am in stage "S4_HOMEOSTASIS"
    And state vector is "[1,1,1,1,1,1]"
    When I verify full system health
    Then all 15 containers should be healthy:
      | Container              | Status  | Ports              |
      | indrajaal-db-prod      | healthy | 5433               |
      | indrajaal-obs-prod     | healthy | 4317,9090,3000,3100|
      | indrajaal-ex-app-1     | healthy | 4000,4001          |
      | zenoh-router-1         | healthy | 7447               |
      | zenoh-router-2         | healthy | 7448               |
      | zenoh-router-3         | healthy | 7449               |
      | cepaf-bridge           | healthy | 9876               |
      | indrajaal-cortex       | healthy | 9877               |
      | indrajaal-chaya        | healthy | 4002               |
      | ml-runner-1            | healthy | -                  |
      | ml-runner-2            | healthy | -                  |
    And the system should be ready for production traffic

  # ============================================================================
  # Transactional Rollback Scenarios
  # ============================================================================

  @rollback @SC-BOOT-004 @apoptosis
  Scenario: Transactional rollback on S2 failure
    Given I am in stage "S2_ZENOH_MESH"
    And S0_PREFLIGHT and S1_INFRASTRUCTURE have completed
    When the Zenoh mesh fails to form quorum
    Then the Apoptosis 6-phase protocol should trigger:
      | Phase | Action                              |
      | 1     | Signal intent to terminate          |
      | 2     | Drain active connections            |
      | 3     | Checkpoint state to DuckDB          |
      | 4     | Stop containers in reverse order    |
      | 5     | Verify clean shutdown               |
      | 6     | Archive checkpoint for recovery     |
    And all S1 containers should be stopped
    And the system should be in a clean state
    And state vector should be "[1,_,_,_,_,_]" (pre-S1)

  @rollback @SC-BOOT-004 @checkpoint
  Scenario: Checkpoint state before risky operations
    Given I am about to start stage "S3_APP_SEED"
    When I create a pre-S3 checkpoint
    Then the checkpoint should capture:
      | State Location     | Captured |
      | FileSystem         | Yes      |
      | KMS                | Yes      |
      | Container State    | Yes      |
      | Volume Data        | Yes      |
      | Zenoh Mesh State   | Yes      |
      | DuckDB History     | Yes      |
      | Environment Vars   | Yes      |
    And the checkpoint should be restorable
    And the checkpoint ID should be logged

  # ============================================================================
  # Mathematical Verification
  # ============================================================================

  @math @SC-BOOT-008 @kahn @dag
  Scenario: Startup DAG is acyclic (Kahn's algorithm verification)
    Given the startup dependency graph
    When I apply Kahn's topological sort algorithm
    Then the algorithm should complete successfully
    And no cycles should be detected
    And the sorted order should be:
      | Wave | Containers                              |
      | W1   | indrajaal-db-prod                       |
      | W2   | indrajaal-obs-prod, zenoh-router-*      |
      | W3   | cepaf-bridge, indrajaal-cortex          |
      | W4   | indrajaal-ex-app-1                      |
      | W5   | indrajaal-chaya, ml-runner-*            |
    And containers in the same wave should start in parallel

  @math @SC-SIL4-011 @quorum
  Scenario: Quorum formula verification
    Given N = 3 Zenoh routers
    When I calculate the quorum requirement
    Then Q = floor(N/2) + 1 = floor(3/2) + 1 = 2
    And 2 healthy routers should be sufficient for consensus
    And Byzantine fault tolerance should be f = floor((N-1)/3) = 0

  @math @state-vector @invariant
  Scenario: State vector validity predicate
    Given a state vector S(t)
    When I evaluate the validity predicate
    Then ValidStartup(t) should be true if and only if:
      | Component  | Value | Description           |
      | Compile    | 1     | F# build succeeded    |
      | Migrations | 1     | DB migrations applied |
      | Containers | 1     | Infrastructure up     |
      | Zenoh      | 1     | Mesh formed           |
      | Health     | 1     | App healthy           |
      | Quorum     | 1     | Cluster consensus     |
    And the product of all components should equal 1

  # ============================================================================
  # Boot Time Performance
  # ============================================================================

  @performance @SC-BOOT-005 @timing
  Scenario: Boot time meets target (<120s, target 60s)
    Given a clean environment
    When I execute the full 5-stage boot sequence
    Then the total boot time should be less than 120 seconds
    And the target boot time of 60 seconds should be achievable
    And stage timings should be:
      | Stage              | Max Time | Target |
      | S0_PREFLIGHT       | 5s       | 3s     |
      | S1_INFRASTRUCTURE  | 30s      | 15s    |
      | S2_ZENOH_MESH      | 20s      | 10s    |
      | S3_APP_SEED        | 45s      | 25s    |
      | S4_HOMEOSTASIS     | 20s      | 7s     |

  @performance @SC-BOOT-009 @parallel
  Scenario: Parallel wave execution optimization
    Given the startup DAG with 5 waves
    When containers in the same wave start
    Then they should start in parallel (not sequential)
    And wave W2 should start all 4 containers concurrently
    And the total time should be the MAX of individual times, not SUM
