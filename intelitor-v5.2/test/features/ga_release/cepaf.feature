# BDD Feature: CEPAF F# Cockpit Scenarios
# GA Release v21.2.1-SIL6 - Runtime Command Verification
# STAMP: SC-CMD-025, SC-CMD-026, SC-NET-*, SC-FSHARP-*

@ga-release @cepaf @fsharp @critical
Feature: CEPAF F# Cockpit Commands
  As an operator
  I want reliable F# cockpit commands
  So that I can manage the Prajna C3I Cockpit

  Background:
    Given the development environment is initialized via "devenv shell"
    And .NET 10.0 SDK is installed
    And the F# projects are in "lib/cepaf/"

  # SC-FSHARP-001: Build F# Projects
  @sc-cmd-026 @build @sc-net-001
  Scenario: Build CEPAF F# projects
    Given the CEPAF solution exists at "lib/cepaf/Cepaf.sln"
    When I execute "cepaf-build"
    Then all F# projects should compile successfully
    And the target framework should be net10.0
    And no build errors should occur

  # SC-FSHARP-002: Deploy Cockpit
  @sc-cmd-025 @deploy
  Scenario: Deploy F# Cockpit
    Given the F# projects are built
    When I execute "cockpitf deploy"
    Then the cockpit should be deployed
    And the deployment should complete without errors
    And the cockpit should be accessible

  # SC-FSHARP-003: Check Cockpit Status
  @sc-cmd-025 @status
  Scenario: Check F# Cockpit status
    Given the cockpit may or may not be deployed
    When I execute "cockpitf status"
    Then I should see the current cockpit status
    And the output should indicate deployment state
    And health information should be displayed

  # SC-FSHARP-004: Run F# Tests
  @sc-cmd-025 @testing
  Scenario: Run F# Cockpit tests
    Given the F# projects are built
    When I execute "cockpitf test"
    Then all F# tests should execute
    And the test summary should be displayed
    And 0 test failures should be reported

  # SC-FSHARP-005: Cleanup Cockpit
  @sc-cmd-025 @cleanup
  Scenario: Cleanup F# Cockpit resources
    Given the cockpit is deployed
    When I execute "cockpitf cleanup"
    Then cockpit resources should be cleaned up
    And no orphan processes should remain
    And the cleanup should complete gracefully

  # Runtime Test Execution
  @sc-cmd-018 @runtime-tests
  Scenario: Execute comprehensive runtime tests
    Given the standalone stack is running
    And the F# runtime scripts exist
    When I execute "sa-test"
    Then the ComprehensiveRuntimeTests.fsx script should execute
    And the test mode should be "swarm"
    And all runtime tests should pass

  # UX Evaluation
  @sc-cmd-019 @ux
  Scenario: Execute UX/UI evaluation
    Given the standalone stack is running
    And the Prajna cockpit is accessible
    When I execute "sa-ux"
    Then the CockpitUXEvaluator.fsx script should execute
    And a UX evaluation report should be generated
    And accessibility checks should pass

  # Test Orchestration
  @sc-cmd-020 @orchestration
  Scenario: Execute test orchestrator
    Given the standalone stack is running
    When I execute "sa-orchestrate swarm"
    Then the RuntimeTestOrchestrator.fsx should execute
    And the mode should be "swarm"
    And orchestrated tests should complete
    And a summary report should be generated

  # FMEA: .NET SDK Not Found
  @fmea @recovery
  Scenario: Handle missing .NET SDK
    Given .NET SDK is not in PATH
    When I execute "cepaf-build"
    Then the command should fail with clear error message
    And the error should indicate ".NET SDK not found"
    And remediation steps should be suggested
