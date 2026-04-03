Feature: Catalog Management
  As a Catalog Librarian
  I want to maintain the integrity of the software catalog
  So that the organization has a trusted source of truth

  Scenario: Register a component from GitHub
    Given I have a valid URL "https://github.com/org/repo/blob/main/catalog-info.yaml"
    When I run the command "sa-catalog register https://github.com/org/repo/blob/main/catalog-info.yaml"
    Then the system should analyze the YAML
    And the system should register the entity "component:default/my-service"
    And the CLI output should contain "Successfully registered"

  Scenario: Validate invalid YAML during registration
    Given I have a local file "bad-catalog.yaml" with invalid syntax
    When I run the command "sa-catalog validate bad-catalog.yaml"
    Then the CLI exit code should be 1
    And the CLI output should contain "Validation Error"
    And the CLI output should contain "Missing required field 'owner'"

  Scenario: Unregister an entity
    Given the entity "component:default/legacy-service" exists
    When I run the command "sa-catalog delete component:default/legacy-service"
    Then the entity "component:default/legacy-service" should be removed from the index
    But the source code should remain untouched

  Scenario: Force refresh an entity
    Given the entity "component:default/my-service" has stale data
    When I run the command "sa-catalog refresh component:default/my-service"
    Then the system should re-fetch the YAML from GitHub
    And the entity "component:default/my-service" should be updated with the latest SHA
