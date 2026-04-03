Feature: Admin Governance
  As a Platform Engineer
  I want to govern the platform usage
  So that I can ensure compliance and security

  Scenario: Audit group membership
    Given the group "group:default/team-alpha" exists
    When I run the command "sa-iam show-group group:default/team-alpha"
    Then the CLI output should list members "alice", "bob"
    And the parent group should be "group:default/engineering"

  Scenario: Verify installed plugins
    When I run the command "sa-plugins list"
    Then the CLI output should contain "catalog"
    And the CLI output should contain "scaffolder"
    And the CLI output should contain "techdocs"
    And the CLI output should contain "kubernetes"

  Scenario: Register new template
    Given I have a template definition at "https://github.com/org/templates/go-service.yaml"
    When I run the command "sa-catalog register https://github.com/org/templates/go-service.yaml"
    Then the entity "template:default/go-service" should be available in the scaffolder
