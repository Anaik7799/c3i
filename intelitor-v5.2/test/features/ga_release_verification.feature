# GA Release v21.3.0-SIL6 - Total Singularity BDD Verification Suite
# Framework: Wallaby + Puppeteer + Expecto + ExUnit
# STAMP: SC-SIL6-001, SC-MESH-001, SC-SING-001, SC-JID-001
# Compliance: SIL-6 Biomorphic Singularity

@ga_release @critical @singularity
Feature: Total F#-Native Singularity Verification
  As a Cybernetic Architect
  I want the full 15-node SIL-6 swarm and HMI interfaces verified
  So that GA release meets 100% biomorphic and mathematical coverage

  Background:
    Given devenv shell is active
    And F# Kernel is built and type-consistent
    And Tailscale FQDN resolution is reified
    And Zenoh FFI control plane is operational

  # ============================================
  # BIOMORPHIC INFRASTRUCTURE (L4-L6)
  # ============================================

  @infrastructure @swarm @priority_p0
  Scenario: sa-mesh ignite - Full SIL-6 Ignition
    Given no containers are running with prefix "indrajaal"
    When I execute "dotnet fsi sa-mesh.fsx ignite"
    Then 15 containers should start within 30 seconds
    And all 15 nodes should report "healthy" state
    And Zenoh FFI session should establish successfully
    And biomorphic listener should enter persistent state

  @infrastructure @mesh @priority_p0
  Scenario: sa-mesh evolution - Mathematical Synchronization
    Given SIL-6 mesh is in homeostasis
    When I execute "dotnet fsi sa-mesh.fsx evolution 2"
    Then Run 1 (Deterministic) should pass mathematical DAG proofs
    And Run 2 (Random) should pass Information Theory resilience checks
    And Shannon Entropy H should be calculated
    And KL-Divergence should be within safety threshold (< 0.05 bits)
    And biomorphic DNA should be committed to Git

  # ============================================
  # HMI & OBSERVABILITY (L7)
  # ============================================

  @hmi @webui @priority_p0
  Scenario: Prajna WebUI - Singularity Dashboard
    Given F# WebUI is running on port 5000
    When I navigate to "http://prajna.indrajaal.tailscale:4001/singularity"
    Then page should load fractal coverage matrix
    And active test vectors should be visible
    And entropy gauge should display real-time values
    And Andon status should show "CLEAR"

  @hmi @tui @priority_p1
  Scenario: CEPAF TUI - Directed Telescope
    Given sa-mesh listener is active
    When I execute "sa-mesh monitor"
    And I press "[S]" key
    Then Singularity View should render successfully
    And 100% coverage indicators should be displayed
    And mathematical proof status should be visible

  # ============================================
  # JIDOKA & SAFETY GATES (L1-L3)
  # ============================================

  @safety @jidoka @priority_p0
  Scenario: Jidoka Gate - Autonomous Halt
    Given a fractal layer defect is injected (e.g. stop a mandatory node)
    When the Jidoka Controller performs a Fractal TPS Audit
    Then Jidoka Halt should trigger immediately
    And Andon signal should broadcast to "indrajaal/jidoka/andon"
    And evolution cycle should block

  @safety @math @priority_p0
  Scenario: Mathematical Proofs - Code Gen & Runtime
    Given a code generation event is triggered
    When the F# Mathematical Correctness module executes
    Then structural AST hash should be verified
    And Quorum Invariant (floor(N/2)+1) should be proven
    And result should be published to Zenoh logic plane

  # ============================================
  # CONTINUOUS FEEDBACK (OODA)
  # ============================================

  @ooda @evolution @priority_p1
  Scenario: OODA Feedback Loop - Autonomous Correction
    Given ooda_feedback_loop.exs is active
    When swarm health or coverage density drops
    Then biomorphic signals should be issued automatically
    And system should self-heal or re-explore state space
    And all actions should be logged to the audit trail
