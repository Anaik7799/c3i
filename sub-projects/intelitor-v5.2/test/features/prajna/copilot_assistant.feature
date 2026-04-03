@prajna @l5_bdd @copilot_assistant
Feature: AI Copilot Assistant
  As an operator using the Prajna C3I cockpit
  I want to interact with the AI copilot to get system insights, run diagnostics, and plan actions
  So that I can operate the biomorphic mesh more effectively with AI-augmented decision support

  # STAMP: SC-ACE-001, SC-MCP-001, SC-SAFETY-001, SC-HMI-010, SC-HMI-011, SC-HITL-001
  # AOR: AOR-CTX-001, AOR-VER-001, AOR-MCP-001
  # Layer: L3 (Domain), L4 (System), L7 (Ecosystem)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/cockpit/ai-copilot"
    And the copilot LiveView is connected via WebSocket
    And the AI model backend is available

  # ----------------------------------------------------------
  # Happy Path: Chat Interface Display
  # ----------------------------------------------------------

  @critical @sc_ace_001 @smoke
  Scenario: Copilot chat interface renders with session context
    Given I open the AI copilot page for the first time
    When the copilot page loads
    Then I should see the conversation input field
    And I should see a welcome message from the copilot
    And I should see suggested quick-action prompts
    And the current system health summary should be displayed in the context panel
    And the page should load within 2000ms

  @critical @sc_ace_001
  Scenario: Send a natural language query and receive a response
    Given I am on the copilot page with an active session
    When I type "What is the current mesh health?" in the input field
    And I press Enter to submit the query
    Then a loading indicator should appear while the AI processes the request
    And the copilot should respond with a mesh health summary
    And the response should include relevant metric values
    And the conversation history should show both the query and the response

  # ----------------------------------------------------------
  # Query Types
  # ----------------------------------------------------------

  @high @sc_mcp_001
  Scenario: Copilot retrieves live Zenoh telemetry on request
    Given I am on the copilot page
    When I ask "Show me the latest Zenoh telemetry for app node 1"
    Then the copilot should query Zenoh topic "indrajaal/health/indrajaal-ex-app-1"
    And the response should include real-time telemetry data
    And the data should be formatted in a readable table within the chat

  @high @sc_ace_001
  Scenario: Copilot generates a diagnostic action plan
    Given the system has a degraded node "indrajaal-ex-app-2"
    When I ask the copilot "Why is app node 2 degraded and what should I do?"
    Then the copilot should perform a 5-Why root cause analysis
    And the response should include a numbered remediation action plan
    And each action step should reference the relevant STAMP constraint
    And the plan should include an estimated recovery time

  @high
  Scenario Outline: Copilot answers domain-specific operator questions
    Given I am on the copilot page
    When I ask "<question>"
    Then the response should mention "<expected_keyword>"
    And the response should arrive within 30 seconds

    Examples:
      | question                                 | expected_keyword |
      | How many active alarms are there?        | alarm            |
      | What containers are currently running?   | container        |
      | Show me the Guardian proposal queue      | proposal         |
      | What is the current quorum status?       | quorum           |

  # ----------------------------------------------------------
  # Actions and Tool Use
  # ----------------------------------------------------------

  @critical @sc_safety_001 @sc_hitl_001
  Scenario: Copilot proposes a Guardian-gated action requiring operator confirmation
    Given I ask the copilot "Restart the degraded app node 2"
    When the copilot formulates a restart action plan
    Then the copilot should present an action confirmation card
    And the card should clearly state the action and its consequences
    And the card should show the STAMP constraints that apply
    And a "Confirm" and "Cancel" button should be visible
    When I click "Confirm"
    Then the action should be submitted as a Guardian proposal
    And the copilot should confirm "Restart proposal submitted to Guardian"

  @high @sc_safety_001
  Scenario: Copilot refuses to execute destructive actions without explicit confirmation
    Given I ask the copilot "Delete all alarm history"
    When the copilot evaluates the request
    Then the copilot should present a warning about the irreversibility
    And the copilot should NOT execute the action automatically
    And the copilot should ask for explicit confirmation with a typed confirmation phrase

  # ----------------------------------------------------------
  # Context and Memory
  # ----------------------------------------------------------

  @high @sc_ace_001
  Scenario: Copilot maintains conversation context across multi-turn dialogue
    Given I have an active copilot session
    When I ask "Show me alarm ALM-001"
    And the copilot provides details about ALM-001
    And I then ask "Acknowledge it"
    Then the copilot should correctly infer I mean alarm "ALM-001"
    And the copilot should initiate the acknowledgement workflow for ALM-001

  @medium
  Scenario: Copilot session context includes current Zenoh mesh state
    Given I am starting a new copilot session
    When I ask "Give me a system overview"
    Then the response should include current container health statuses
    And the response should include active alarm count
    And the response should include Zenoh mesh connectivity status

  # ----------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------

  @medium
  Scenario: Copilot handles ambiguous queries with clarifying questions
    Given I am on the copilot page
    When I type "Fix it" and submit the query
    Then the copilot should respond with a clarifying question
    And the copilot should NOT take any action autonomously
    And at least 2 clarification options should be suggested

  @medium
  Scenario: Copilot gracefully handles AI backend timeout
    Given the AI backend is temporarily slow to respond
    When I submit a query and the backend exceeds 30 seconds
    Then a timeout message should appear in the conversation
    And the input field should remain active for a retry
    And no crash or error should occur in the LiveView

  @high @sc_hmi_010
  Scenario: Copilot response sentiment is reflected with chromatic UI feedback
    Given I have submitted a query about system health
    When the copilot responds with a "critical issue detected" assessment
    Then the response card border should render in red
    And when the copilot reports "all systems nominal"
    Then the response card border should render in green
