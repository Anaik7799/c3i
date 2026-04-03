# STAMP: SC-BOOT-011, SC-BOOT-012, SC-RCA-001, SC-RCA-002
# AOR: AOR-RCA-001, AOR-TPS-001
# TPS: Jidoka (自働化) + 5-Why Methodology

@critical @rca @seven-level @SC-BOOT-011 @SC-BOOT-012
Feature: Seven-Level Root Cause Analysis
  As a system operator
  I want comprehensive 7-level RCA on startup failures
  So that I can fix issues at the true root cause level

  Background:
    Given the 7-Level RCA Matrix is defined as:
      | Level | Name         | Scope        | Question                            |
      | L1    | Symptom      | Observable   | What failed?                        |
      | L2    | Local        | Immediate    | Why here?                           |
      | L3    | Logic        | Code         | Why this code?                      |
      | L4    | Module       | Component    | Why this module?                    |
      | L5    | System       | Cross-module | Why systemic?                       |
      | L6    | Design       | Pattern      | Why this design?                    |
      | L7    | Architecture | Structural   | Why architecture?                   |
    And the TPS 5-Why methodology is active

  # ============================================================================
  # L1 Symptom Level Analysis
  # ============================================================================

  @L1 @symptom @observable
  Scenario: Identify symptom level for container restart loop
    Given the app container is in a restart loop
    When I execute 7-level RCA
    Then L1 finding should be "App container enters restart loop"
    And L1 question should be "What failed? What is the observable error?"
    And L1 evidence should include container status logs

  @L1 @symptom @observable
  Scenario: Identify symptom level for health check failure
    Given the health endpoint returns HTTP 503
    When I execute 7-level RCA
    Then L1 finding should identify the observable failure
    And L1 should NOT attempt to determine causation

  # ============================================================================
  # L2 Local Context Analysis
  # ============================================================================

  @L2 @local @immediate-context
  Scenario: Identify local context for Oban table error
    Given the error log contains "oban_peers table undefined"
    When I execute 7-level RCA
    Then L2 finding should be "Oban GenServer crashes: 'oban_peers table undefined'"
    And L2 question should be "Why here? What is the immediate context?"
    And L2 should identify the specific GenServer

  @L2 @local @immediate-context
  Scenario: Identify local context for port conflict
    Given the error log contains "bind: address already in use"
    And port 4000 is in use by another process
    When I execute 7-level RCA
    Then L2 finding should be "Port already in use by another process"
    And L2 should identify the conflicting port

  # ============================================================================
  # L3 Logic Level Analysis
  # ============================================================================

  @L3 @logic @code-path
  Scenario: Identify logic path for missing migrations
    Given the error is related to missing database tables
    When I trace the code path via 7-level RCA
    Then L3 finding should be "Database migrations not verified before app start"
    And L3 question should be "Why this code? What logic path led here?"
    And L3 should reference the startup sequence

  @L3 @logic @code-path
  Scenario: Identify logic path for disabled NIF
    Given SKIP_ZENOH_NIF is set to "1"
    And tests are skipping Zenoh functionality
    When I execute 7-level RCA
    Then L3 finding should be "NIF disabled to work around compilation"
    And L3 should identify SKIP_ZENOH_NIF=1 as the logic decision

  # ============================================================================
  # L4 Module Level Analysis
  # ============================================================================

  @L4 @module @component
  Scenario: Identify module issue for missing migration gate
    Given the startup sequence lacks migration verification
    When I analyze at module level via 7-level RCA
    Then L4 finding should be "MeshStartup.fs has no migration verification gate"
    And L4 question should be "Why this module? What module design issue?"
    And L4 should suggest adding verifyMigrations gate

  @L4 @module @component
  Scenario: Identify module issue for health check timeout
    Given health checks are failing with timeout
    And the app is still compiling during health checks
    When I execute 7-level RCA
    Then L4 finding should be "HealthCheckTimeoutMs too short for compilation"
    And L4 should suggest increasing timeout to 300000ms

  # ============================================================================
  # L5 System Level Analysis
  # ============================================================================

  @L5 @system @cross-module
  Scenario: Identify systemic issue for state vector gap
    Given stage transitions occur without state verification
    When I analyze at system level via 7-level RCA
    Then L5 finding should be "No state vector check before proceeding to next stage"
    And L5 question should be "Why systemic? What cross-module integration issue?"
    And L5 should reference SC-BOOT-001

  @L5 @system @cross-module
  Scenario: Identify systemic issue for quorum failure
    Given only 1 of 3 Zenoh routers is healthy
    And the cluster formation times out
    When I execute 7-level RCA
    Then L5 finding should be "No 2oo3 voting enforcement in boot"
    And L5 should recommend requiring 2oo3 quorum before S3

  # ============================================================================
  # L6 Design Level Analysis
  # ============================================================================

  @L6 @design @pattern
  Scenario: Identify design pattern issue for missing contracts
    Given the startup sequence lacks formal pre/post conditions
    When I analyze at design level via 7-level RCA
    Then L6 finding should be "Startup lacks formal pre-condition/post-condition contracts"
    And L6 question should be "Why this design? What design pattern issue?"
    And L6 should suggest Design by Contract pattern

  @L6 @design @pattern
  Scenario: Identify design pattern issue for clean slate assumption
    Given port scouring is not performed before container start
    When I execute 7-level RCA
    Then L6 finding should be "Boot assumes clean slate without verification"
    And L6 should recommend defensive startup pattern

  # ============================================================================
  # L7 Architecture Level Analysis
  # ============================================================================

  @L7 @architecture @specification
  Scenario: Identify architectural root cause for specification gap
    Given all lower levels (L1-L6) have been analyzed
    When I complete the full 7-level RCA chain
    Then L7 finding should be "No mathematical startup specification to conform against"
    And L7 question should be "Why architecture? What specification gap?"
    And the root cause level should be L7_Architecture

  @L7 @architecture @specification
  Scenario Outline: Map known issues to root cause levels
    Given the error pattern "<pattern>" is detected
    When I execute 7-level RCA
    Then the root cause level should be "<root_level>"
    And the recommended fix should be "<fix>"

    Examples:
      | pattern        | root_level      | fix                                          |
      | oban_peers     | L7_Architecture | Add migration gate (SC-BOOT-002)             |
      | port conflict  | L6_Design       | Run port scouring in S0_PREFLIGHT stage      |
      | quorum         | L5_System       | Require 2oo3 quorum before S3_APP_SEED       |
      | health timeout | L4_Module       | Increase appHealthMaxWait to 300000ms        |
      | zenoh nif      | L3_Logic        | Set SKIP_ZENOH_NIF=0 in all environments     |

  # ============================================================================
  # Full 7-Level RCA Chain
  # ============================================================================

  @full-chain @5-why @tps
  Scenario: Execute complete 7-level RCA chain for Oban failure
    Given the app container is in restart loop with Oban error
    When I execute full 7-level RCA with 5-Why methodology
    Then I should receive findings for all 7 levels:
      | Level | Finding                                                   |
      | L1    | App container enters restart loop                         |
      | L2    | Oban GenServer crashes: 'oban_peers table undefined'      |
      | L3    | Database migrations not verified before app start         |
      | L4    | MeshStartup.fs has no migration verification gate         |
      | L5    | No state vector check before proceeding to next stage     |
      | L6    | Startup lacks formal pre-condition/post-condition contracts |
      | L7    | No mathematical startup specification to conform against  |
    And the root cause should be identified at L7
    And the prevention strategy should be "Implement state vector verification (SC-BOOT-001)"

  @full-chain @report
  Scenario: Generate RCA report with all metadata
    Given I have completed a 7-level RCA analysis
    When I generate the RCA report
    Then the report should include:
      | Field              | Present |
      | IssueId            | yes     |
      | Issue              | yes     |
      | Findings           | yes     |
      | RootCauseLevel     | yes     |
      | RootCauseSummary   | yes     |
      | RecommendedFix     | yes     |
      | PreventionStrategy | yes     |
      | ReportTimestamp    | yes     |
      | AnalysisDurationMs | yes     |
    And the report should be printable with ANSI colors

  # ============================================================================
  # Jidoka Integration
  # ============================================================================

  @jidoka @stop-fix-prevent @tps
  Scenario: Jidoka principle triggers immediate stop on defect
    Given a startup defect is detected at L3 level
    When the Jidoka principle is invoked
    Then the startup sequence should STOP immediately
    And the 7-level RCA should be executed automatically
    And the fix should be applied at the root cause level
    And the defect should be prevented from recurring

  @jidoka @kaizen @continuous-improvement
  Scenario: RCA findings feed into Kaizen improvement
    Given a 7-level RCA has identified root cause at L5
    When the analysis is complete
    Then the finding should be added to known issues database
    And future occurrences should be recognized immediately
    And prevention measures should be applied proactively

  # ============================================================================
  # Performance Requirements
  # ============================================================================

  @performance @latency
  Scenario: RCA analysis completes within timeout
    Given a complex startup failure with multiple symptoms
    When I execute 7-level RCA
    Then the analysis should complete within 5000ms
    And the AnalysisDurationMs should be recorded
    And slow analysis should trigger optimization

  @performance @caching
  Scenario: Known issue patterns are matched quickly
    Given the error matches a known pattern "oban_peers"
    When I execute 7-level RCA
    Then the analysis should complete within 100ms
    And the cached findings should be returned
    And no AI inference should be required
