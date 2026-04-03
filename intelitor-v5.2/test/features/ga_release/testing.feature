# BDD Feature: Testing Command Scenarios
# GA Release v21.2.1-SIL6 - Runtime Command Verification
# STAMP: SC-CMD-008, SC-CMD-009, SC-TEST-*, SC-COV-*

@ga-release @testing @quality
Feature: Testing Commands
  As a developer
  I want reliable test execution commands
  So that I can verify code quality before release

  Background:
    Given the development environment is initialized via "devenv shell"
    And the code is compiled
    And the test database exists

  # SC-TEST-001: Standard Test Execution
  @sc-cmd-008 @unit-tests @sc-test-005
  Scenario: Run test suite with Zenoh NIF active
    Given the test database is available
    When I execute "test"
    Then the environment variable SKIP_ZENOH_NIF should be "0"
    And MIX_ENV should be "test"
    And PATIENT_MODE should be "enabled"
    And all tests should execute
    And 0 test failures should be reported

  # SC-TEST-002: Test with Coverage
  @sc-cmd-009 @coverage @sc-cov-001
  Scenario: Run tests with coverage reporting
    Given the test suite is ready
    When I execute "test-cover"
    Then all tests should execute with coverage tracking
    And a coverage report should be generated
    And line coverage should be at least 95%
    And branch coverage should be at least 80%

  # SC-TEST-003: Specific Test File
  @targeted-testing
  Scenario: Run specific test file
    Given a specific test file exists
    When I execute "test test/indrajaal/cockpit/prajna/dark_cockpit_test.exs"
    Then only the specified test file should run
    And the test should complete with status

  # SC-TEST-004: Test with Trace
  @debugging
  Scenario: Run tests with trace output
    Given tests need debugging
    When I execute "test --trace"
    Then each test should display execution time
    And detailed trace information should be shown

  # TDG: Test Determinism
  @tdg @property
  Scenario: Tests are deterministic
    Given the test suite passes
    When I run the same tests 3 times
    Then all runs should produce the same results
    And no flaky tests should be detected

  # TDG: Test Isolation
  @tdg @property
  Scenario: Tests are isolated
    Given multiple tests exist
    When tests run in any order
    Then each test should pass independently
    And no test should depend on another test's state

  # Property Testing
  @propcheck @sc-prop-023
  Scenario: PropCheck property tests execute
    Given property tests exist in the codebase
    When I execute tests with PropCheck
    Then generators should use PC. prefix for PropCheck
    And generators should use SD. prefix for StreamData
    And no generator conflicts should occur

  # FMEA: Database Not Ready
  @fmea @recovery
  Scenario: Handle database not ready for tests
    Given the test database is not running
    When I execute "test"
    Then tests should fail with connection error
    And error message should indicate database issue
    When I start the database via "sa-db"
    And I retry "test"
    Then tests should execute successfully
