# STAMP: SC-BOOT-001 to SC-BOOT-010, SC-FUNC-001 to SC-FUNC-008
# AOR: AOR-TPS-001 to AOR-TPS-003, AOR-FUNC-001 to AOR-FUNC-008
# Methodology: Jidoka (自働化) - Autonomation with Human Touch
# TPS: Toyota Production System Quality Gates

@critical @jidoka @tps @quality-gates
Feature: Jidoka Quality Gates (7 Gates)
  As a quality engineer
  I want Jidoka autonomation quality gates
  So that defects are caught immediately and fixed before continuing

  Background:
    Given the Jidoka principle is: "Stop, Fix, Prevent"
    And the TPS principles are active:
      | Principle   | Japanese | Application                           |
      | Jidoka      | 自働化   | Stop immediately on defect            |
      | Heijunka    | 平準化   | Level workload across boot waves      |
      | Kaizen      | 改善     | Continuous improvement via OODA       |
      | Genchi Genbutsu | 現地現物 | Go see - investigate actual code   |
      | Poka-yoke   | ポカヨケ | Error-proofing via type safety        |

  # ============================================================================
  # GATE 1: Environment Verification
  # ============================================================================

  @gate-1 @environment @SC-BOOT-001
  Scenario: GATE 1 - Environment verification passes
    Given I am at GATE 1: ENVIRONMENT VERIFICATION
    When I run environment checks
    Then the following prerequisites should be verified:
      | Check            | Command               | Expected     |
      | .NET SDK         | dotnet --version      | >= 10.0.0    |
      | Podman           | podman --version      | >= 5.4.1     |
      | Available ports  | ss -tlnp              | 4000,5433,7447 free |
      | Disk space       | df -h /               | >= 10GB      |
      | Memory           | free -g               | >= 8GB       |
    And the state vector should be "[1,_,_,_,_,_]"
    And GATE 1 should be marked PASSED

  @gate-1 @environment @jidoka @SC-BOOT-001 @negative
  Scenario: GATE 1 - Jidoka STOP on environment failure
    Given I am at GATE 1: ENVIRONMENT VERIFICATION
    And .NET SDK version is 9.0.0 (below required 10.0.0)
    When I run environment checks
    Then GATE 1 should FAIL
    And the Jidoka response should be:
      | Step    | Action                                    |
      | STOP    | Immediately halt startup sequence         |
      | SIGNAL  | Alert: ".NET SDK 10.0+ required"          |
      | FIX     | Run: nix develop or install .NET 10       |
      | PREVENT | Add SDK version check to CI/CD            |
    And no further gates should be attempted
    And the fail action should be "STOP - Fix environment"

  @gate-1 @poka-yoke @type-safety
  Scenario: GATE 1 - Poka-yoke error proofing
    Given I am at GATE 1: ENVIRONMENT VERIFICATION
    When I verify type safety measures
    Then the F# type system should enforce:
      | Type           | Constraint                    |
      | Port           | 1-65535 range enforced        |
      | IPAddress      | Valid IPv4 format             |
      | Timeout        | Positive integer milliseconds |
      | StateComponent | Discriminated union (Valid/Invalid) |
    And invalid configurations should not compile

  # ============================================================================
  # GATE 2: F# Build Verification
  # ============================================================================

  @gate-2 @fsharp-build @SC-CMP-025
  Scenario: GATE 2 - F# build verification passes
    Given I am at GATE 2: F# BUILD VERIFICATION
    And GATE 1 has passed
    When I run "dotnet build lib/cepaf/Cepaf.sln"
    Then the build should complete with:
      | Metric   | Expected |
      | Errors   | 0        |
      | Warnings | 0        |
    And the state vector should update compile component to Valid
    And GATE 2 should be marked PASSED

  @gate-2 @fsharp-build @jidoka @SC-CMP-025 @negative
  Scenario: GATE 2 - Jidoka STOP on F# build failure
    Given I am at GATE 2: F# BUILD VERIFICATION
    And MeshConfig.fs has a syntax error
    When I run "dotnet build lib/cepaf/Cepaf.sln"
    Then GATE 2 should FAIL
    And the Jidoka response should be:
      | Step    | Action                                    |
      | STOP    | Immediately halt startup sequence         |
      | SIGNAL  | Alert: "F# build failed with N errors"    |
      | FIX     | Show error locations with line numbers    |
      | PREVENT | Add pre-commit build check                |
    And the fail action should be "STOP - Fix compile errors"
    And the 5-Why RCA should be initiated

  @gate-2 @fsharp-build @warnings @SC-CMP-025
  Scenario: GATE 2 - Treat warnings as errors
    Given I am at GATE 2: F# BUILD VERIFICATION
    And MeshConfig.fs has 5 warnings
    When I run "dotnet build lib/cepaf/Cepaf.sln"
    Then GATE 2 should WARN (not fail) per current policy
    But the warning count should be logged
    And a Kaizen item should be created: "Eliminate 5 F# warnings"

  # ============================================================================
  # GATE 3: Migration Verification (NEW - Root Cause Fix)
  # ============================================================================

  @gate-3 @migrations @SC-BOOT-002 @critical
  Scenario: GATE 3 - Migration verification passes
    Given I am at GATE 3: MIGRATION VERIFICATION
    And GATE 2 has passed
    And the database container is running
    When I verify database migrations
    Then the following Oban tables should exist:
      | Table       | Purpose                    |
      | oban_jobs   | Background job storage     |
      | oban_peers  | Distributed coordination   |
      | oban_beats  | Health heartbeat           |
    And the following application tables should exist:
      | Table       | Purpose                    |
      | users       | User accounts              |
      | audit_logs  | Immutable audit trail      |
      | holons      | Holon state storage        |
    And the state vector should update migrations component to Valid
    And GATE 3 should be marked PASSED

  @gate-3 @migrations @jidoka @SC-BOOT-002 @negative @critical
  Scenario: GATE 3 - Jidoka STOP on missing Oban tables
    Given I am at GATE 3: MIGRATION VERIFICATION
    And the database is running
    But the "oban_peers" table does not exist
    When I verify database migrations
    Then GATE 3 should FAIL
    And the Jidoka response should be:
      | Step    | Action                                    |
      | STOP    | Immediately halt startup sequence         |
      | SIGNAL  | Alert: "Missing Oban tables"              |
      | FIX     | Run: mix ecto.migrate                     |
      | PREVENT | Add migration check before app start      |
    And the fail action should be "STOP - Run mix ecto.migrate"
    And NO further containers should start
    And this is the ROOT CAUSE of the restart loop issue

  @gate-3 @migrations @genchi-genbutsu
  Scenario: GATE 3 - Genchi Genbutsu investigation
    Given I am at GATE 3: MIGRATION VERIFICATION
    And GATE 3 has failed
    When I apply Genchi Genbutsu (go see)
    Then I should investigate the actual database state:
      """
      psql -h localhost -p 5433 -U postgres -d indrajaal_dev -c "
        SELECT table_name FROM information_schema.tables
        WHERE table_name LIKE 'oban%';
      "
      """
    And I should see the exact missing tables
    And the fix should be verified before proceeding

  # ============================================================================
  # GATE 4: Infrastructure Verification
  # ============================================================================

  @gate-4 @infrastructure @SC-BOOT-003
  Scenario: GATE 4 - Infrastructure verification passes
    Given I am at GATE 4: INFRASTRUCTURE VERIFICATION
    And GATES 1-3 have passed
    When I verify infrastructure containers
    Then the following containers should be healthy:
      | Container           | Port  | Health Check         |
      | indrajaal-db-prod   | 5433  | pg_isready           |
      | indrajaal-obs-prod  | 4317  | OTEL receiver ready  |
    And the state vector should be "[1,1,1,_,_,_]"
    And GATE 4 should be marked PASSED

  @gate-4 @infrastructure @jidoka @SC-BOOT-003 @negative
  Scenario: GATE 4 - Jidoka STOP on container health failure
    Given I am at GATE 4: INFRASTRUCTURE VERIFICATION
    And the database container is unhealthy
    When I verify infrastructure containers
    Then GATE 4 should FAIL
    And the Jidoka response should be:
      | Step    | Action                                    |
      | STOP    | Immediately halt startup sequence         |
      | SIGNAL  | Alert: "Container unhealthy: indrajaal-db-prod" |
      | FIX     | Check container logs: podman logs         |
      | PREVENT | Add health check timeout and retry        |
    And the fail action should be "STOP - Debug containers"

  # ============================================================================
  # GATE 5: Zenoh Quorum Verification
  # ============================================================================

  @gate-5 @zenoh @quorum @SC-SIL4-006
  Scenario: GATE 5 - Zenoh quorum verification passes
    Given I am at GATE 5: ZENOH QUORUM VERIFICATION
    And GATES 1-4 have passed
    When I verify Zenoh router quorum
    Then 3 Zenoh routers should be running
    And at least 2 should be healthy (2oo3 voting)
    And the quorum status should be "Achieved"
    And the state vector should be "[1,1,1,1,_,_]"
    And GATE 5 should be marked PASSED

  @gate-5 @zenoh @quorum @jidoka @SC-SIL4-006 @negative
  Scenario: GATE 5 - Jidoka STOP on quorum failure
    Given I am at GATE 5: ZENOH QUORUM VERIFICATION
    And only 1 Zenoh router is healthy
    When I verify Zenoh router quorum
    Then GATE 5 should FAIL
    And the Jidoka response should be:
      | Step    | Action                                    |
      | STOP    | Immediately halt startup sequence         |
      | SIGNAL  | Alert: "Quorum not achieved: 1/3 (need 2)"|
      | FIX     | Restart failed Zenoh routers              |
      | PREVENT | Add router health monitoring              |
    And the fail action should be "STOP - Fix Zenoh mesh"

  # ============================================================================
  # GATE 6: Application Health Verification
  # ============================================================================

  @gate-6 @application @health @SC-BOOT-004
  Scenario: GATE 6 - Application health verification passes
    Given I am at GATE 6: APPLICATION HEALTH VERIFICATION
    And GATES 1-5 have passed
    When I verify application health
    Then Phoenix should respond 200 OK on /health
    And Oban should be running without errors
    And all Elixir supervisors should be alive
    And the state vector should be "[1,1,1,1,1,_]"
    And GATE 6 should be marked PASSED

  @gate-6 @application @oban @jidoka @SC-BOOT-004 @negative
  Scenario: GATE 6 - Jidoka STOP on Oban crash
    Given I am at GATE 6: APPLICATION HEALTH VERIFICATION
    And Oban crashes with "oban_peers table undefined"
    When I verify application health
    Then GATE 6 should FAIL
    And the Jidoka response should be:
      | Step    | Action                                    |
      | STOP    | Immediately halt startup sequence         |
      | SIGNAL  | Alert: "Oban crashed: missing tables"     |
      | FIX     | GATE 3 should have caught this            |
      | PREVENT | Enforce GATE 3 migration check            |
    And the 7-Level RCA should identify GATE 3 bypass as root cause

  # ============================================================================
  # GATE 7: Homeostasis Verification (FPPS)
  # ============================================================================

  @gate-7 @homeostasis @fpps @SC-BOOT-005
  Scenario: GATE 7 - Homeostasis verification passes
    Given I am at GATE 7: HOMEOSTASIS VERIFICATION
    And GATES 1-6 have passed
    When I run FPPS 5-point consensus
    Then all 5 validators should return results:
      | Validator      | Method           | Result |
      | V1             | Pattern Matching | PASS   |
      | V2             | AST Analysis     | PASS   |
      | V3             | Statistical      | PASS   |
      | V4             | Binary Check     | PASS   |
      | V5             | Line-by-Line     | PASS   |
    And consensus should be achieved (5/5 >= 3 majority)
    And the state vector should be "[1,1,1,1,1,1]"
    And GATE 7 should be marked PASSED
    And the system should be FULLY OPERATIONAL

  @gate-7 @homeostasis @fpps @jidoka @SC-BOOT-005 @negative
  Scenario: GATE 7 - Jidoka STOP on FPPS failure
    Given I am at GATE 7: HOMEOSTASIS VERIFICATION
    And only 2/5 FPPS validators pass
    When I run FPPS 5-point consensus
    Then GATE 7 should FAIL
    And the Jidoka response should be:
      | Step    | Action                                    |
      | STOP    | Immediately halt startup sequence         |
      | SIGNAL  | Alert: "FPPS failed: 2/5 (need 3)"        |
      | FIX     | Full RCA required                         |
      | PREVENT | Manual intervention mandatory             |
    And the fail action should be "STOP - Full RCA"
    And the state vector should remain "[1,1,1,1,1,0]"

  # ============================================================================
  # Gate Flow Enforcement
  # ============================================================================

  @gate-flow @sequential @SC-BOOT-001
  Scenario: Gates must execute in sequence
    Given I am executing the startup sequence
    Then gates must execute in order:
      | Gate | Name                       | Prerequisite |
      | G1   | Environment Verification   | None         |
      | G2   | F# Build Verification      | G1           |
      | G3   | Migration Verification     | G2           |
      | G4   | Infrastructure Verification| G3           |
      | G5   | Zenoh Quorum Verification  | G4           |
      | G6   | Application Health         | G5           |
      | G7   | Homeostasis Verification   | G6           |
    And skipping a gate should not be allowed
    And each gate must pass before the next begins

  @gate-flow @bypass-prevention @SC-BOOT-001
  Scenario: Gate bypass is prevented
    Given I am at GATE 4
    And GATE 3 has failed
    When I attempt to proceed to GATE 4
    Then the attempt should be blocked
    And the error should be: "Cannot proceed - GATE 3 (Migration) failed"
    And the Jidoka principle should enforce this

  # ============================================================================
  # Kaizen Continuous Improvement
  # ============================================================================

  @kaizen @ooda @improvement
  Scenario: Kaizen improvement from gate failures
    Given a gate has failed
    When the failure is analyzed
    Then a Kaizen improvement item should be created:
      | Field       | Value                               |
      | Source      | Gate failure analysis               |
      | Issue       | Specific failure description        |
      | Root Cause  | 5-Why analysis result               |
      | Countermeasure | Proposed fix                     |
      | Verification | How to verify fix                  |
    And the item should be logged to the planning system
    And the OODA cycle should incorporate the learning

  @kaizen @heijunka @load-leveling
  Scenario: Heijunka load leveling across boot waves
    Given the startup DAG has 5 waves
    When I apply Heijunka principles
    Then containers should be distributed across waves to balance load:
      | Wave | Container Count | Max Parallel |
      | W1   | 1               | 1            |
      | W2   | 4               | 4            |
      | W3   | 2               | 2            |
      | W4   | 1               | 1            |
      | W5   | 3               | 3            |
    And no single wave should be overloaded
    And total boot time should be minimized

  # ============================================================================
  # FMEA Risk Analysis for Gates
  # ============================================================================

  @fmea @risk-analysis @SC-BOOT-010
  Scenario: FMEA risk analysis for all gates
    Given I perform FMEA analysis on the 7 gates
    Then the following failure modes should be documented:
      | Gate | Failure Mode              | Severity | Occurrence | Detection | RPN | Mitigation |
      | G1   | SDK not installed         | 8        | 3          | 9         | 216 | CI check   |
      | G2   | F# syntax error           | 7        | 4          | 9         | 252 | Pre-commit |
      | G3   | Missing migrations        | 9        | 5          | 6         | 270 | Gate 3 NEW |
      | G4   | Container unhealthy       | 8        | 4          | 7         | 224 | Health check|
      | G5   | Quorum not achieved       | 9        | 3          | 7         | 189 | 2oo3 voting|
      | G6   | Oban crash                | 9        | 5          | 5         | 225 | Gate 3     |
      | G7   | FPPS disagree             | 7        | 2          | 8         | 112 | 5-point    |
    And RPN > 200 should trigger priority mitigation

  # ============================================================================
  # TDG Property Tests for Gates
  # ============================================================================

  @tdg @property-test @SC-TDG-001
  Scenario: TDG property tests for gate execution
    Given I have property generators for gates
    Then the following properties should hold:
      | Property                        | Generator              | Invariant              |
      | Gate order preserved            | gate_sequence_gen      | strictly increasing    |
      | State vector monotonic          | state_vector_gen       | bits only set, not unset|
      | Failure halts sequence          | failure_injection_gen  | no subsequent gates run|
      | Retry is idempotent             | retry_count_gen        | same result on retry   |
    And all property tests should pass with 100 samples
