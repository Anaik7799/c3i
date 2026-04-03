Feature: Catalog Explorer
  As a Developer
  I want to explore the Software Catalog
  So that I can find components, APIs, and their owners

  Scenario: Filter Catalog by Kind
    Given I am on the "Catalog" screen
    And the catalog contains the following entities:
      | kind      | name          | owner    |
      | Component | auth-service  | team-a   |
      | Component | user-service  | team-a   |
      | API       | auth-api      | team-b   |
    When I select "Component" from the "Kind" filter
    Then I should see "auth-service" in the table
    And I should see "user-service" in the table
    But I should NOT see "auth-api" in the table

  Scenario: Search for an Entity
    Given I am on the "Catalog" screen
    When I search for "user"
    Then I should see "user-service" in the table
    And the "Owner" column should show "team-a"

  Scenario: Navigate to Entity Details
    Given I see "auth-service" in the table
    When I click on "auth-service"
    Then I should be navigated to the "EntityPage" for "auth-service"
    And I should see the "Overview" tab selected
