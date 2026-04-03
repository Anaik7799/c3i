@prajna @l5_bdd @prometheus_verification
Feature: PROMETHEUS Verification Dashboard
  As a system architect or safety engineer using the Prajna C3I cockpit
  I want to run and review PROMETHEUS formal verification proofs and FPPS consensus checks
  So that I can confirm constitutional invariants, safety properties, and system correctness

  # STAMP: SC-VER-001, SC-VER-074, SC-VER-075, SC-SIL4-023, SC-CONSENSUS-001, SC-HMI-011
  # AOR: AOR-VER-001 to AOR-VER-040, AOR-CTX-001
  # Layer: L0 (Constitution), L3 (Domain), L5 (Cluster)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/cockpit/prometheus"
    And the PROMETHEUS LiveView is connected via WebSocket
    And the verification engine is available

  # ----------------------------------------------------------
  # Happy Path: Verification Dashboard Display
  # ----------------------------------------------------------

  @critical @sc_ver_001 @smoke
  Scenario: PROMETHEUS dashboard renders all verification categories
    Given the PROMETHEUS verification engine is running
    When the verification page loads
    Then I should see the constitutional invariants panel
    And I should see the FPPS consensus status panel
    And I should see the Agda proof verification results
    And I should see the Quint temporal model status
    And the overall verification health indicator should be visible
    And the page should load within 2000ms

  @critical @sc_ver_001
  Scenario: All constitutional invariants show passing state
    Given the system is in a known-good constitutional state
    When I view the constitutional invariants panel
    Then Ψ₀ (Existence) should show "VERIFIED" with a green badge
    And Ψ₁ (Regeneration) should show "VERIFIED" with a green badge
    And Ψ₂ (Evolutionary Continuity) should show "VERIFIED" with a green badge
    And Ψ₃ (Verification Capability) should show "VERIFIED" with a green badge
    And Ψ₄ (Human Alignment) should show "VERIFIED" with a green badge
    And the overall constitutional health should display as "CONSTITUTIONAL"

  # ----------------------------------------------------------
  # FPPS Consensus
  # ----------------------------------------------------------

  @critical @sc_sil4_023
  Scenario: FPPS 3-of-5 consensus check executes and reports result
    Given there are 5 verification methods configured
    When I click "Run FPPS Consensus Check"
    Then a progress indicator should appear while consensus is computed
    And the result should show how many of 5 methods agree
    And if 3 or more agree, the status should show "CONSENSUS REACHED"
    And if fewer than 3 agree, the status should show "CONSENSUS FAILED"
    And each method's individual result should be displayed in the detail panel

  @high @sc_consensus_001
  Scenario: 2-of-3 voting result for safety-critical property
    Given the constitutional kernel has evaluated a safety-critical invariant
    When I view the 2oo3 voting panel for that invariant
    Then I should see the vote from each of the 3 constitutional chambers
    And the majority vote should determine the final result
    And each chamber's rationale should be expandable
    And the final decision should be logged to the Immutable Register

  # ----------------------------------------------------------
  # Agda Proof Verification
  # ----------------------------------------------------------

  @high @sc_ver_074
  Scenario: Agda proofs for graph properties load and show pass status
    Given Agda proofs have been compiled for the system
    When I view the formal proofs panel
    Then the GraphProperties.agda proof should show "Compiled" status
    And the AcyclicityProofs.agda proof should show "Compiled" status
    And each proof file should show its last verified timestamp
    And the total type-checked proof lines count should be visible

  @high
  Scenario: Failed Agda proof triggers constitutional alert
    Given an Agda proof has a type-checking failure in its latest run
    When I view the formal proofs panel
    Then the failed proof should show "Type Error" status with a red badge
    And a "Constitutional Alert" notification should appear in the panel header
    And the error should include the file name and failing proposition
    And a Zenoh event "constitutional_proof_failed" should have been published

  # ----------------------------------------------------------
  # Quint Temporal Model Checking
  # ----------------------------------------------------------

  @high @sc_ver_001
  Scenario: Quint guardian state machine model runs and passes
    Given the Quint model for the guardian state machine exists
    When I click "Run Quint Verification" for the guardian model
    Then the Quint model checker should execute
    And the result should show all temporal properties as satisfied
    And invariant violations should be listed as empty
    And the execution trace count should be visible

  @medium
  Scenario: Quint model counterexample is displayed on property violation
    Given a Quint model has a property that is not satisfied
    When I run verification for that model
    Then the result should show "Counterexample Found"
    And the counterexample trace steps should be enumerated
    And each step should show the state transition that led to the violation
    And an "Export Counterexample" button should be available

  # ----------------------------------------------------------
  # Verification History and Trends
  # ----------------------------------------------------------

  @medium
  Scenario: Verification history shows pass/fail trend over time
    Given the system has a history of multiple verification runs
    When I click the "History" tab in the verification dashboard
    Then I should see a time-series chart of verification pass rates
    And I should be able to filter by verification category
    And each historical run should show its overall pass/fail status
    And trend lines should indicate whether verification health is improving

  @high @sc_hmi_011
  Scenario: Constitutional layer L0-L7 compliance matrix is fully populated
    Given the system has completed a full constitutional verification
    When I view the constitutional layer matrix
    Then all 8 fractal layers (L0-L7) should have an entry in the matrix
    And each layer should show its compliance status with a color badge
    And non-compliant layers should be highlighted with a red badge and issue count
    And I should be able to drill into each layer's constraint details

  # ----------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------

  @medium
  Scenario: Verification engine offline shows safe degraded state
    Given the PROMETHEUS verification engine is temporarily unavailable
    When I navigate to the verification page
    Then a "Verification Engine Offline" notice should appear
    And the last known verification results should still be displayed with a stale badge
    And the stale badge should show how long ago the results were computed
    And no crash or error should occur in the LiveView

  @medium
  Scenario: Re-run all verifications button triggers full suite execution
    Given I am viewing the PROMETHEUS dashboard
    When I click "Re-run All Verifications"
    Then a confirmation dialog should appear listing all verification types to run
    When I confirm the re-run
    Then a progress panel should show each verification running sequentially
    And completed verifications should show green checkmarks as they finish
    And the overall status should update when all verifications complete
