@prajna @l5_bdd @guardian_management
Feature: Guardian Management
  As a system operator with Guardian authority
  I want to review, approve, and veto proposals from agents and operators
  So that safety-critical mutations are controlled through the constitutional approval chain

  # STAMP: SC-SAFETY-001, SC-GUARD-001, SC-GUARD-002, SC-GDE-001, SC-SIL4-006, SC-HMI-011
  # AOR: AOR-CTX-001, AOR-VER-001, AOR-VER-033
  # Layer: L0 (Constitution), L3 (Domain), L4 (System)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/cockpit/guardian"
    And the Guardian LiveView is connected via WebSocket
    And Guardian service is active

  # ----------------------------------------------------------
  # Happy Path: Proposal Queue Display
  # ----------------------------------------------------------

  @critical @sc_guard_001 @smoke
  Scenario: Guardian dashboard renders pending proposal queue
    Given there are pending proposals awaiting Guardian review
    When the Guardian dashboard loads
    Then I should see the proposal queue table
    And each proposal should display submitter, type, timestamp, and risk score
    And proposals should be ordered by risk score descending
    And the total pending count should be visible in the header
    And the page should load within 2000ms

  @critical @sc_guard_001
  Scenario: Proposal queue updates in real-time via Zenoh subscription
    Given I am viewing the Guardian dashboard
    And there are 2 pending proposals
    When a new proposal arrives via Zenoh topic "indrajaal/control/guardian/proposals"
    Then the new proposal should appear in the queue without page reload
    And the pending count should increment to 3
    And the new proposal should be highlighted as "New" for 5 seconds

  # ----------------------------------------------------------
  # Proposal Review
  # ----------------------------------------------------------

  @critical @sc_guard_001 @sc_safety_001
  Scenario: View full proposal detail before approval decision
    Given there is a proposal "PROP-001" of type "code_evolution"
    When I click "Review" on proposal "PROP-001"
    Then the proposal detail panel should expand
    And I should see the full proposed change diff
    And I should see the STAMP constraint compliance report
    And I should see the 4-layer impact analysis (L1-CODE, L2-DOMAIN, L3-SYSTEM, L4-ECOSYSTEM)
    And I should see the mutation safety score as a percentage
    And I should see the submitting agent identity

  @high @sc_guard_002
  Scenario Outline: Proposals are classified by risk tier
    Given there is a proposal with impact score "<score>"
    When I view the proposal in the Guardian queue
    Then the proposal should display risk tier "<tier>"
    And the tier badge should use color "<color>"

    Examples:
      | score | tier     | color  |
      | 5     | LOW      | teal   |
      | 15    | MEDIUM   | amber  |
      | 25    | HIGH     | orange |
      | 35    | CRITICAL | red    |

  # ----------------------------------------------------------
  # Approval Actions
  # ----------------------------------------------------------

  @critical @sc_guard_001 @sc_gde_001
  Scenario: Approve a code evolution proposal
    Given there is a pending proposal "PROP-EVL-001" of type "code_evolution"
    And the proposal has a mutation safety score above 0.85
    When I click "Approve" on proposal "PROP-EVL-001"
    Then an approval confirmation dialog should appear
    And I should see the proposal summary in the dialog
    When I confirm the approval
    Then the proposal status should change to "approved"
    And a Zenoh event "guardian_proposal_approved" should be published
    And the approval should be logged to the Immutable Register with actor identity
    And the agent that submitted the proposal should receive the approval notification

  @critical @sc_sil4_006
  Scenario: Approve a production actuation with 2oo3 voting requirement
    Given there is a pending proposal "PROP-ACT-001" of type "production_actuation"
    When I click "Approve" on proposal "PROP-ACT-001"
    Then I should see that 2-of-3 Guardian votes are required
    And the current approval count should show "1 of 3 required"
    And the proposal should remain in "pending_quorum" state until quorum is reached

  # ----------------------------------------------------------
  # Veto Actions
  # ----------------------------------------------------------

  @critical @sc_guard_001 @sc_gde_001
  Scenario: Veto a proposal with a mandatory reason
    Given there is a pending proposal "PROP-VET-001" with high risk
    When I click "Veto" on proposal "PROP-VET-001"
    Then a veto dialog should appear requiring a veto reason
    And the submit button should be disabled until a reason is entered
    When I enter veto reason "Violates SC-SAFETY-001 - unsafe state transition"
    And I confirm the veto
    Then the proposal status should change to "vetoed"
    And the veto reason should be visible in the proposal history
    And a Zenoh event "guardian_proposal_vetoed" should be published
    And the submitting agent should receive a veto notification with the reason

  @high
  Scenario: Guardian proposes a fallback alternative on veto
    Given there is a proposal "PROP-FBK-001" that has been vetoed
    When I click "Suggest Fallback" on the vetoed proposal
    Then a fallback proposal form should appear pre-populated with context
    And I should be able to modify the proposed change
    When I submit the fallback proposal
    Then a new proposal "PROP-FBK-001-ALT" should appear in the queue
    And the original proposal "PROP-FBK-001" should be linked as the parent

  # ----------------------------------------------------------
  # Proposal History
  # ----------------------------------------------------------

  @high
  Scenario: View full Guardian decision audit trail
    Given there are approved, vetoed, and pending proposals in history
    When I click the "History" tab on the Guardian dashboard
    Then I should see all past decisions with timestamps and actor identities
    And I should be able to filter history by decision type (approved, vetoed)
    And each history entry should link to the Immutable Register block

  # ----------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------

  @medium
  Scenario: Empty proposal queue shows all-clear state
    Given there are no pending Guardian proposals
    When I view the Guardian dashboard
    Then I should see "No pending proposals" message
    And a green "All Clear" indicator should be visible
    And no table rows should be present in the queue

  @medium
  Scenario: Proposal with expired TTL is automatically removed
    Given there is a proposal "PROP-EXP-001" that exceeded its approval TTL
    When the Guardian dashboard renders
    Then proposal "PROP-EXP-001" should show status "expired"
    And an expiry warning should be visible on the proposal row
    And a Zenoh event "guardian_proposal_expired" should have been published
