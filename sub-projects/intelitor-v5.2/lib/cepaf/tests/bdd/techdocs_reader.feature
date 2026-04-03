Feature: TechDocs Reader
  As a User
  I want to read documentation within the portal
  So that I don't have to context switch to external sites

  Scenario: Read Component Documentation
    Given I am on the "EntityPage" for "auth-service"
    When I click the "Docs" tab
    Then I should see the "TechDocs" viewer
    And the content should contain "Introduction"
    And the sidebar should show "Getting Started"

  Scenario: Navigate Internal Links
    Given I am reading "Getting Started"
    When I click the link "Configuration"
    Then the viewer should scroll to "Configuration"
