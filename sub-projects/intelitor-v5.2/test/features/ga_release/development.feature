# BDD Feature: Development Workflow Scenarios
# GA Release v21.2.1-SIL6 - Runtime Command Verification
# STAMP: SC-CMD-004 to SC-CMD-009, SC-DEV-*

@ga-release @development @quality
Feature: Development Workflow Commands
  As a developer
  I want reliable compilation and quality tools
  So that I can develop with confidence

  Background:
    Given the development environment is initialized via "devenv shell"
    And dependencies are installed via "mix deps.get"

  # SC-DEV-001: Standard Compilation
  @sc-cmd-004 @compilation @patient-mode
  Scenario: Compile with Patient Mode
    Given the codebase has Elixir source files
    When I execute "compile"
    Then the compilation should use Patient Mode environment variables
      | Variable | Value |
      | NO_TIMEOUT | true |
      | PATIENT_MODE | enabled |
    And compilation output should be logged to "./data/tmp/1-compile.log"
    And compilation should complete with 0 errors

  # SC-DEV-002: Strict Compilation
  @sc-cmd-005 @compilation @strict
  Scenario: Compile with warnings as errors
    Given the codebase is clean
    When I execute "compile-strict"
    Then compilation should fail if any warnings exist
    And the command should use "--warnings-as-errors" flag
    And 0 warnings should be reported for GA release

  # SC-DEV-003: Basic Quality Check
  @sc-cmd-006 @quality @credo
  Scenario: Run basic quality checks
    Given the code is compiled
    When I execute "quality"
    Then "mix format --check-formatted" should pass
    And "mix credo --strict" should pass
    And the combined result should indicate "Quality OK"

  # SC-DEV-004: Full Quality Pipeline
  @sc-cmd-007 @quality @dialyzer @sobelow
  Scenario: Run full quality pipeline
    Given the code is compiled
    And the Dialyzer PLT is built
    When I execute "quality-full"
    Then format check should pass
    And Credo analysis should pass
    And Dialyzer type analysis should pass
    And Sobelow security scan should pass
    And I should see "All quality gates passed"

  # SC-DEV-005: Test Execution
  @sc-cmd-008 @testing @nif
  Scenario: Run test suite with Zenoh NIF
    Given the test database exists
    And the code is compiled
    When I execute "test"
    Then tests should run with SKIP_ZENOH_NIF=0
    And the MIX_ENV should be "test"
    And all tests should pass with 0 failures

  # SC-DEV-006: Coverage Report
  @sc-cmd-009 @testing @coverage
  Scenario: Run tests with coverage report
    Given the test database exists
    When I execute "test-cover"
    Then a coverage report should be generated
    And coverage should be at least 95%
    And the report should be saved to "cover/excoveralls.html"

  # TDG-CMD-001: Compilation Idempotency
  @tdg @property
  Scenario: Compilation is idempotent
    Given the code is compiled once
    When I execute "compile" again
    Then the output should indicate "Compiling 0 files"
    And no recompilation should occur unless source changes

  # TDG-CMD-002: Quality Determinism
  @tdg @property
  Scenario: Quality checks are deterministic
    Given the codebase state is unchanged
    When I execute "quality" multiple times
    Then the results should be identical each time
    And no flaky failures should occur
