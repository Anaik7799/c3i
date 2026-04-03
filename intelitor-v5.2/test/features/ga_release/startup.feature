# BDD Feature: Startup Scenarios
# GA Release v21.2.1-SIL6 - Runtime Command Verification
# STAMP: SC-CMD-001 to SC-CMD-005, SC-START-*

@ga-release @startup @critical
Feature: System Startup Commands
  As an operator
  I want to start the Indrajaal system reliably
  So that the security platform is operational

  Background:
    Given the development environment is initialized via "devenv shell"
    And Podman 5.4+ is available
    And .NET 10.0 SDK is installed

  # SC-START-001: Cold Start
  @sc-cmd-010 @containers
  Scenario: Cold start with standalone stack
    Given no containers are running
    When I execute "sa-up"
    Then 3 containers should be created
      | Container | Service | Port |
      | indrajaal-db-prod | PostgreSQL | 5433 |
      | indrajaal-obs-prod | Observability | 3000,9090 |
      | indrajaal-ex-app-1 | Phoenix | 4000 |
    And all containers should have status "running"
    And health endpoint should return HTTP 200 within 30 seconds

  # SC-START-002: Sequential Component Start
  @sc-cmd-015 @sc-cmd-016 @sc-cmd-017
  Scenario: Sequential component startup
    Given no containers are running
    When I execute "sa-db"
    Then PostgreSQL should be available on port 5433
    When I execute "sa-obs"
    Then Grafana should be available on port 3000
    And Prometheus should be available on port 9090
    When I execute "sa-app"
    Then Phoenix should be available on port 4000

  # SC-START-003: Development Mode Start
  @sc-cmd-001 @development
  Scenario: Start Phoenix in development mode
    Given the database is running on port 5433
    And the application is compiled
    When I execute "app"
    Then Phoenix server should start on port 4000
    And I should see "Access IndrajaalWeb.Endpoint at http://localhost:4000"

  # SC-START-004: Full Development Start
  @sc-cmd-002 @development
  Scenario: Full development environment start
    Given Podman is available
    When I execute "app-start"
    Then all development containers should start
    And Phoenix server should start on port 4000
    And the startup script should complete without errors

  # SC-START-005: Interactive Mode Start
  @sc-cmd-003 @interactive
  Scenario: Start Phoenix with IEx console
    Given the database is running
    And the application is compiled
    When I execute "app-iex"
    Then IEx prompt should be available
    And Phoenix server should be running
    And I should be able to execute "Indrajaal.Cockpit.Prajna.DarkCockpit.get_state()"

  # SC-OPS-001: Clean Shutdown
  @sc-cmd-011 @shutdown
  Scenario: Clean stack shutdown
    Given the standalone stack is running
    When I execute "sa-down"
    Then all containers should stop gracefully
    And no orphan processes should remain
    And data volumes should be preserved

  # SC-OPS-002: Full Cleanup
  @sc-cmd-012 @cleanup
  Scenario: Full stack cleanup with volume removal
    Given the standalone stack is running
    When I execute "sa-clean"
    Then all containers should stop
    And all volumes should be removed
    And the environment should be pristine

  # SC-OPS-003: Status Check
  @sc-cmd-013 @monitoring
  Scenario: Check container status
    Given some containers may or may not be running
    When I execute "sa-status"
    Then I should see the status of all defined containers
    And the output should include container names and states

  # SC-OPS-004: Log Streaming
  @sc-cmd-014 @monitoring
  Scenario: Stream container logs
    Given the standalone stack is running
    When I execute "sa-logs indrajaal-ex-app-1"
    Then I should see streaming logs from the app container
    And the logs should include Phoenix startup messages
