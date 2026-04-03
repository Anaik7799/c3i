# BDD Feature: Operations & Reporting Scenarios
# GA Release v21.2.1-SIL6 - Runtime Command Verification
# STAMP: SC-CMD-027, SC-CMD-028, SC-CMD-029

@ga-release @operations @monitoring
Feature: Operations and Reporting Commands
  As an operator
  I want reliable monitoring and reporting commands
  So that I can track system health and project status

  Background:
    Given the development environment is initialized via "devenv shell"
    And the application is compiled

  # SC-CMD-027: Capability Envelope Dashboard
  @sc-cmd-027 @reporting @capability
  Scenario: Display capability envelope dashboard
    Given the system is operational
    When I execute "envelope"
    Then the capability envelope dashboard should display
    And system capabilities should be listed
    And coverage metrics should be shown
    And the dashboard should render correctly

  # SC-CMD-027: Export Capability as JSON
  @sc-cmd-027 @reporting @json
  Scenario: Export capability envelope as JSON
    Given the system is operational
    When I execute "envelope-json"
    Then capability data should be exported as JSON
    And the JSON should be valid
    And all capability fields should be present

  # SC-CMD-027: Save Capability to Journal
  @sc-cmd-027 @reporting @journal
  Scenario: Save capability envelope to journal
    Given the journal directory exists
    When I execute "envelope-journal"
    Then a journal entry should be created
    And the entry should be timestamped
    And capability metrics should be recorded

  # SC-CMD-028: Project Todo Status
  @sc-cmd-028 @tracking
  Scenario: Display project task status
    Given project tasks are defined
    When I execute "todo"
    Then project tasks should be displayed
    And task priorities should be shown
    And completion status should be indicated

  # SC-CMD-029: Help Command
  @sc-cmd-029 @documentation
  Scenario: Display command help
    When I execute "help"
    Then all available commands should be listed
    And commands should be organized by category
    And descriptions should be provided for each command
    And access points should be displayed

  # Health Endpoint Monitoring
  @monitoring @health
  Scenario: Verify health endpoint
    Given the Phoenix server is running on port 4000
    When I request "GET /health"
    Then the response status should be 200
    And the response should indicate system health
    And component statuses should be included

  # Prajna Cockpit Access
  @monitoring @prajna
  Scenario: Access Prajna C3I Cockpit
    Given the Phoenix server is running
    When I navigate to "http://localhost:4000/prajna"
    Then the Prajna cockpit should load
    And system metrics should be displayed
    And no JavaScript errors should occur

  # AI Copilot Access
  @monitoring @copilot
  Scenario: Access AI Copilot
    Given the Phoenix server is running
    When I navigate to "http://localhost:4000/prajna/copilot"
    Then the AI Copilot interface should load
    And the chat interface should be functional
    And Founder's Directive alignment should be verified

  # Grafana Dashboard Access
  @monitoring @observability
  Scenario: Access Grafana dashboards
    Given the observability stack is running
    When I navigate to "http://localhost:3000"
    And I login with "admin/indrajaal"
    Then Grafana should be accessible
    And Indrajaal dashboards should be available

  # Prometheus Metrics Access
  @monitoring @metrics
  Scenario: Access Prometheus metrics
    Given the observability stack is running
    When I navigate to "http://localhost:9090"
    Then Prometheus should be accessible
    And Indrajaal metrics should be queryable
