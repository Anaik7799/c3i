Feature: Scaffolder Creator
  As an Architect
  I want to create new components from templates
  So that I can standardize service creation

  Scenario: Select a Template
    Given I am on the "Create" screen
    And the following templates exist:
      | name          | title             |
      | react-app     | React Website     |
      | go-service    | Go Microservice   |
    When I click on "React Website"
    Then I should see the "Wizard" screen
    And the current step should be "1"

  Scenario: Execute Scaffolding Job
    Given I have filled out the "React Website" form
    When I click "Create"
    Then I should see the "TaskLog" screen
    And I should see "Fetch template" in the logs
    And I should see "Publish to GitHub" in the logs
    When the task completes
    Then I should see a link to the "Catalog"
