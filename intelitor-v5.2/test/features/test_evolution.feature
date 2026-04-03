# Feature: Biomorphic Test Evolution
# STAMP: SC-TEST-EVO-001 to SC-TEST-EVO-007
# AOR: AOR-TEST-EVO-001 to AOR-TEST-EVO-008

@test_evolution @biomorphic @ooda
Feature: Biomorphic Test Evolution with OpenRouter AI
  As a test architect
  I want tests to evolve autonomously using AI
  So that test coverage improves continuously without manual intervention

  Background:
    Given the test evolution server is running
    And OpenRouter API is available with free models
    And the TrainingGym is recording episodes

  # Level 1: TDG - Property Tests
  @level1 @tdg @property_tests
  Scenario: Generate property tests for a module
    Given I have a module at "lib/indrajaal/accounts/user.ex"
    When I request TDG test generation
    Then property tests should be generated using "meta-llama/llama-3.1-8b-instruct:free"
    And the tests should include PropCheck generators
    And the tests should include ExUnitProperties checks
    And the fitness score should be recorded

  @level1 @tdg @dual_property
  Scenario: Ensure dual property testing compliance
    Given I have generated TDG tests
    When the tests are compiled
    Then they should use "alias PropCheck.BasicTypes, as: PC"
    And they should use "alias StreamData, as: SD"
    And SC-PROP-023 should be satisfied

  # Level 2: FMEA - Failure Mode Analysis
  @level2 @fmea @failure_analysis
  Scenario: Generate FMEA tests for critical paths
    Given I have a safety-critical module at "lib/indrajaal/safety/sentinel.ex"
    When I request FMEA test generation
    Then failure mode tests should be generated using "qwen/qwen-2-7b-instruct:free"
    And RPN calculations should be included
    And tests for RPN > 100 should have documented mitigations
    And the tests should be tagged with "@fmea"

  @level2 @fmea @rpn_threshold
  Scenario: Flag high RPN failure modes
    Given an FMEA analysis identifies a failure mode with RPN 120
    When the tests are generated
    Then a mitigation plan should be documented
    And the test should assert mitigation effectiveness
    And Guardian should be notified of high-risk paths

  # Level 3: Formal - Type Proofs
  @level3 @formal @type_safety
  Scenario: Generate Dialyzer specs for module
    Given I have a module needing type safety verification
    When I request formal verification test generation
    Then @spec annotations should be generated
    And Quint temporal models should be created
    And the formal proofs should be placed in "docs/formal_specs/"

  @level3 @formal @temporal_logic
  Scenario: Generate temporal property verification
    Given I have a state machine module
    When I request LTL/CTL verification
    Then temporal logic properties should be specified
    And reachability proofs should be generated
    And safety invariants should be verified

  # Level 4: Graph - Path Coverage
  @level4 @graph @path_analysis
  Scenario: Generate control flow tests
    Given I have a complex function with multiple branches
    When I request graph-based test generation
    Then all control flow paths should be identified
    And edge coverage tests should be generated using "google/gemma-2-9b-it:free"
    And cyclomatic complexity should be calculated

  @level4 @graph @fsm_coverage
  Scenario: Generate FSM state coverage tests
    Given I have a finite state machine implementation
    When I request FSM coverage analysis
    Then all states should be reachable
    And all transitions should be tested
    And invalid transitions should be rejected

  # Level 5: BDD - Integration
  @level5 @bdd @integration
  Scenario: Generate Gherkin feature files
    Given I have a user-facing feature
    When I request BDD test generation
    Then Gherkin feature files should be generated using "mistralai/mistral-7b-instruct:free"
    And step definitions should be created
    And Puppeteer integration should be included for UI tests

  @level5 @bdd @puppeteer
  Scenario: Generate Puppeteer tests for LiveView page
    Given I have a LiveView page at "/cockpit/test-evolution"
    When I request Puppeteer test generation
    Then browser automation tests should be generated
    And screenshots should be captured on failure
    And the tests should verify all interactive elements

  # OODA Cycle
  @ooda @evolution
  Scenario: Complete OODA cycle for test evolution
    Given the test evolution server is active
    When 30 seconds elapse
    Then an OODA cycle should complete
    And the OBSERVE phase should gather file change metrics
    And the ORIENT phase should analyze coverage gaps
    And the DECIDE phase should select regeneration targets
    And the ACT phase should generate new tests
    And cycle metrics should be published to Zenoh

  @ooda @fitness_threshold
  Scenario: Trigger regeneration on low fitness
    Given a test has fitness score 0.45
    When the OODA cycle evaluates fitness
    Then the test should be flagged for regeneration
    And a new test should be generated using AI
    And the fitness improvement should be tracked

  # Genome Evolution
  @genome @mutation
  Scenario: Evolve genome through mutation
    Given the current genome has mutation_rate 0.1
    When evolution is triggered
    Then tests should be mutated based on mutation_rate
    And high-fitness tests should be preserved
    And diversity floor of 0.3 should be maintained

  @genome @selection
  Scenario: Apply selection pressure to tests
    Given I have 100 tests with varying fitness scores
    When selection is applied with pressure 0.7
    Then the top 70% of tests should be retained
    And the bottom 30% should be candidates for replacement
    And elite tests (top 10%) should be guaranteed preservation

  # OpenRouter Integration
  @openrouter @free_models
  Scenario: Use only free AI models
    Given OpenRouter is configured
    When any AI-powered generation is requested
    Then only ":free" suffix models should be used
    And costs should be zero
    And AOR-OPENROUTER-001 should be satisfied

  @openrouter @rate_limiting
  Scenario: Handle rate limiting gracefully
    Given OpenRouter returns a 429 rate limit error
    When the next request is attempted
    Then exponential backoff should be applied
    And the base delay should be 2 seconds
    And the maximum delay should be 60 seconds
    And the error should be recorded in TrainingGym

  @openrouter @fallback
  Scenario: Fallback to mock on API unavailable
    Given OpenRouter API is unavailable
    When test generation is requested
    Then the mock provider should be used
    And development should continue unblocked
    And AOR-OPENROUTER-005 should be satisfied

  # TrainingGym Integration
  @training @learning
  Scenario: Record generation episodes for learning
    Given a test is generated by AI
    When the generation completes
    Then an episode should be recorded in TrainingGym
    And the episode should include success/failure status
    And fitness delta should be calculated
    And token usage should be logged

  @training @improvement
  Scenario: Improve over time through learning
    Given 1000 test generation episodes are recorded
    When the learning analysis is performed
    Then model effectiveness should be evaluated
    And prompt improvements should be suggested
    And generation success rate should trend upward

  # Integration with Prajna Cockpit
  @prajna @dashboard
  Scenario: Display test evolution in Prajna dashboard
    Given the Prajna TestCockpit is open
    When test evolution is active
    Then fitness metrics should be displayed
    And OODA cycle status should be visible
    And 5-level coverage should be shown
    And genome parameters should be adjustable

  @prajna @real_time
  Scenario: Real-time updates in dashboard
    Given the TestCockpit LiveView is connected
    When a new test is generated
    Then the dashboard should update within 5 seconds
    And the recent tests list should show the new test
    And coverage percentages should refresh
