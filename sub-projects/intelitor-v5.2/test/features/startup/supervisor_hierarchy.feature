# STAMP: SC-SUP-001, SC-SUP-002, SC-SUP-003, SC-OODA-001, SC-BOOT-009
# AOR: AOR-MESH-001, AOR-MESH-007, AOR-BIO-001, AOR-BIO-002

@critical @supervisor @hierarchy @SC-SUP-001 @SC-SUP-002
Feature: Three-Level Supervisor Hierarchy
  As a system architect
  I want a 3-level supervisor hierarchy
  So that boot orchestration is properly managed with OODA loops

  Background:
    Given the supervisor hierarchy is defined as:
      | Level | Name       | Count | Responsibility                    |
      | L1    | Executive  | 1     | Master OODA orchestrator          |
      | L2    | Domain     | 4     | Stage supervisors                 |
      | L3    | Worker     | 12    | Container workers                 |
    And the total supervisor count is 17

  # ============================================================================
  # Hierarchy Structure
  # ============================================================================

  @structure @L1 @executive
  Scenario: L1 Executive supervisor creation
    When I build the supervisor hierarchy
    Then there should be exactly 1 Executive supervisor
    And the Executive ID should be "EXEC-001"
    And the Executive should have L1_Executive level
    And the Executive should have 4 children (domain supervisors)
    And the Executive should have no parent

  @structure @L2 @domain
  Scenario: L2 Domain supervisors creation
    When I build the supervisor hierarchy
    Then there should be exactly 4 Domain supervisors:
      | ID         | Stage              | Worker Count |
      | SUP-INFRA  | S1_INFRASTRUCTURE  | 2            |
      | SUP-ZENOH  | S2_ZENOH_MESH      | 3            |
      | SUP-APP    | S3_APP_SEED        | 3            |
      | SUP-VERIFY | S4_HOMEOSTASIS     | 4            |
    And each Domain supervisor should have parent "EXEC-001"
    And each Domain supervisor should have L2_Domain level

  @structure @L3 @worker
  Scenario: L3 Worker supervisors creation
    When I build the supervisor hierarchy
    Then there should be exactly 12 Worker supervisors:
      | ID             | Parent     | Specialization |
      | WRK-01-DB      | SUP-INFRA  | Database boot  |
      | WRK-02-OBS     | SUP-INFRA  | Observability  |
      | WRK-03-ZENOH1  | SUP-ZENOH  | Zenoh router 1 |
      | WRK-04-ZENOH2  | SUP-ZENOH  | Zenoh router 2 |
      | WRK-05-ZENOH3  | SUP-ZENOH  | Zenoh router 3 |
      | WRK-06-APP1    | SUP-APP    | App instance 1 |
      | WRK-07-APP2    | SUP-APP    | App instance 2 |
      | WRK-08-HEALTH  | SUP-APP    | Health check   |
      | WRK-09-QUORUM  | SUP-VERIFY | Quorum verify  |
      | WRK-10-PATTERN | SUP-VERIFY | Pattern match  |
      | WRK-11-AST     | SUP-VERIFY | AST validation |
      | WRK-12-E2E     | SUP-VERIFY | E2E testing    |
    And each Worker should have L3_Worker level
    And no Worker should have children

  @structure @tree @visualization
  Scenario: Supervisor tree visualization
    Given the supervisor hierarchy is built
    When I print the hierarchy
    Then I should see a formatted tree with:
      | Section              | Content                          |
      | L1 EXECUTIVE         | EXEC-001 with OODA state         |
      | L2 DOMAIN SUPERVISORS| 4 supervisors with stages        |
      | L3 WORKERS           | 12 workers with parents          |
      | Summary              | Total, Active, Idle, Failed counts|

  # ============================================================================
  # OODA Loop Integration
  # ============================================================================

  @ooda @cycle @SC-OODA-001
  Scenario: OODA loop configuration
    Given the OODA loop timings are:
      | Phase   | Duration |
      | Observe | 5000ms   |
      | Orient  | 5000ms   |
      | Decide  | 5000ms   |
      | Act     | 15000ms  |
    When I calculate the total cycle time
    Then the total should be 30000ms
    And this should match AnimationConfig.OodaLoop.totalCycleMs

  @ooda @observe @phase
  Scenario: OODA Observe phase execution
    Given the supervisor tree is active
    And the state vector is "[1,1,1,0,0,0]"
    When I run the Observe phase
    Then observations should include:
      | Key             | Type       |
      | stateVector     | StateVector|
      | supervisorCount | int        |
      | activeCount     | int        |
      | failedCount     | int        |
      | timestamp       | DateTime   |

  @ooda @orient @phase
  Scenario: OODA Orient phase execution
    Given observations show:
      | Key         | Value           |
      | stateVector | [1,1,1,0,0,0]   |
      | failedCount | 2               |
    When I run the Orient phase
    Then orientations should include:
      | Analysis                      |
      | ALERT: 2 supervisors failed   |
      | Zenoh mesh not formed         |
      | App health check failed       |
      | Quorum not achieved           |

  @ooda @decide @phase
  Scenario: OODA Decide phase execution
    Given orientations include:
      | Analysis              |
      | 2 supervisors failed  |
      | Zenoh mesh not formed |
    When I run the Decide phase
    Then decisions should include:
      | Decision                   |
      | RestartFailedSupervisors   |
      | AlertOperator              |
      | RetryHealthCheck           |
      | ExtendTimeout              |

  @ooda @act @phase
  Scenario: OODA Act phase execution
    Given decisions include:
      | Decision                   |
      | RestartFailedSupervisors   |
      | RetryHealthCheck           |
    When I run the Act phase
    Then actions should be logged with timestamps
    And each action should reference the original decision

  @ooda @cycle-count
  Scenario: OODA cycle counter increments
    Given the OODA state has CycleCount = 5
    When I advance from Act to Observe phase
    Then the CycleCount should be 6
    And the phase should reset to Observe
    And previous observations should be cleared

  @ooda @phase-expiry
  Scenario: OODA phase timeout detection
    Given the current phase is Observe
    And the phase started 6000ms ago
    When I check if the phase has expired
    Then isOODAPhaseExpired should return true
    And the system should advance to the next phase

  # ============================================================================
  # Supervisor Status Management
  # ============================================================================

  @status @idle
  Scenario: Initial supervisor status
    When I build the supervisor hierarchy
    Then all supervisors should have status Idle
    And no supervisor should have status Failed

  @status @active
  Scenario: Update supervisor to Active status
    Given the supervisor hierarchy is built
    When I update supervisor "SUP-INFRA" to Active status
    Then supervisor "SUP-INFRA" should have status Active
    And the LastHeartbeat should be updated
    And countByStatus Active should return 1

  @status @failed
  Scenario: Update supervisor to Failed status
    Given the supervisor hierarchy is built
    When I update supervisor "WRK-03-ZENOH1" to Failed "Connection refused"
    Then supervisor "WRK-03-ZENOH1" should have status Failed
    And the failure reason should be "Connection refused"
    And countByStatus (Failed "") should return 1

  @status @heartbeat
  Scenario: Supervisor heartbeat updates
    Given supervisor "EXEC-001" was last seen 60 seconds ago
    When I send a heartbeat for "EXEC-001"
    Then the LastHeartbeat should be updated to now
    And the supervisor should be considered alive

  # ============================================================================
  # Executive Veto Authority
  # ============================================================================

  @veto @SC-SUP-002
  Scenario: Executive has veto authority
    Given the Executive supervisor is active
    And a stage transition is proposed
    When the Executive issues a Veto command
    Then the stage transition should be blocked
    And the veto should be logged
    And all domain supervisors should be notified

  @veto @SC-SUP-002
  Scenario: Executive approves stage transition
    Given the Executive supervisor is active
    And the state vector meets requirements
    When the Executive issues an Approve command
    Then the stage transition should proceed
    And the approval should be logged
    And domain supervisors should begin execution

  # ============================================================================
  # Worker Assignment
  # ============================================================================

  @assignment @task
  Scenario: Assign task to worker
    Given supervisor "SUP-INFRA" is active
    When I assign task "StartDatabase" to "WRK-01-DB"
    Then worker "WRK-01-DB" should have status Active
    And the task assignment should be logged

  @assignment @parallel @SC-BOOT-009
  Scenario: Workers within same wave run in parallel
    Given domain supervisor "SUP-INFRA" has workers:
      | Worker     | Task            |
      | WRK-01-DB  | StartDatabase   |
      | WRK-02-OBS | StartObs        |
    When I start the wave
    Then both workers should be Active simultaneously
    And execution should be parallelized

  # ============================================================================
  # Supervisor Lookup
  # ============================================================================

  @lookup @find
  Scenario Outline: Find supervisor by ID
    Given the supervisor hierarchy is built
    When I search for supervisor "<id>"
    Then I should find a supervisor with level "<level>"

    Examples:
      | id             | level        |
      | EXEC-001       | L1_Executive |
      | SUP-INFRA      | L2_Domain    |
      | SUP-ZENOH      | L2_Domain    |
      | SUP-APP        | L2_Domain    |
      | SUP-VERIFY     | L2_Domain    |
      | WRK-01-DB      | L3_Worker    |
      | WRK-12-E2E     | L3_Worker    |

  @lookup @not-found
  Scenario: Search for non-existent supervisor
    Given the supervisor hierarchy is built
    When I search for supervisor "INVALID-001"
    Then the result should be None

  # ============================================================================
  # Metrics and Telemetry
  # ============================================================================

  @metrics @count
  Scenario: Total supervisor count
    Given the supervisor hierarchy is built
    When I count total supervisors
    Then the count should be 17 (1 + 4 + 12)

  @metrics @by-status
  Scenario: Count supervisors by status
    Given the supervisor hierarchy is built
    And I set status:
      | Supervisor     | Status |
      | EXEC-001       | Active |
      | SUP-INFRA      | Active |
      | WRK-01-DB      | Active |
      | WRK-03-ZENOH1  | Failed |
    When I count by status
    Then countByStatus Active should return 3
    Then countByStatus Idle should return 13
    Then countByStatus (Failed "") should return 1

  @telemetry @ooda-status
  Scenario: Print OODA status
    Given the OODA state is:
      | Field          | Value   |
      | Phase          | Orient  |
      | CycleCount     | 3       |
      | Observations   | 5       |
      | Orientations   | 3       |
      | Decisions      | 2       |
      | Actions        | 0       |
    When I print the OODA status
    Then I should see a progress bar
    And I should see cycle count 3
    And I should see current phase Orient
