Feature: Developer Workflow
  As a Product Developer
  I want a frictionless inner loop
  So that I can focus on writing code, not configuration

  Scenario: Scaffold a new service
    Given the template "react-ssr-template" exists
    When I run the command "sa-scaffold run react-ssr-template --params '{\"name\":\"new-app\",\"owner\":\"team-a\"}'"
    Then the system should generate a new repository "new-app"
    And the repository should contain "catalog-info.yaml"
    And the system should register "component:default/new-app"

  Scenario: Search documentation content
    Given the documentation for "auth-service" is indexed
    When I run the command "sa-docs search 'JWT token'"
    Then the CLI output should list "auth-service/docs/authentication.md"
    And the match score should be > 0.8

  Scenario: View API definition
    Given the API "auth-api" exists
    When I run the command "sa-api show api:default/auth-api"
    Then the CLI output should contain "openapi: 3.0.0"
    And the CLI output should contain "/login"

  Scenario: Traverse dependency graph
    Given "component:default/frontend" depends on "component:default/backend"
    When I run the command "sa-catalog graph component:default/frontend --depth 1"
    Then the CLI output should show a link to "component:default/backend"
    And the relationship should be "dependsOn"
