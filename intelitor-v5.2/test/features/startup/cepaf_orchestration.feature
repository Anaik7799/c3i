@cepaf @fsharp @orchestration @sil6 @phase6
Feature: CEPAF F# Orchestration
  As a system operator
  I want CEPAF F# infrastructure to orchestrate the mesh
  So that I have reliable, type-safe container management

  Background:
    Given the .NET 10.0 SDK is available
    And CEPAF projects are built successfully
    And the F# orchestration scripts are accessible

  # ==========================================================================
  # SC-CEPAF-001: F# Project Build Verification
  # ==========================================================================
  @build @critical
  Scenario: All CEPAF F# projects build successfully
    When I execute "dotnet build lib/cepaf/src/Cepaf/Cepaf.fsproj"
    Then the build should succeed with 0 errors
    And the following projects should be compiled
      | Project           | Target Framework |
      | Cepaf             | net10.0          |
      | Cepaf.Config      | net10.0          |
      | Cepaf.Podman      | net10.0          |
      | Cepaf.Cockpit     | net10.0          |
      | Cepaf.Planning    | net10.0          |
      | Cepaf.Smriti      | net8.0           |
    And build warnings should be minimal (< 10)

  # ==========================================================================
  # SC-CEPAF-002: Mesh Core Types Availability
  # ==========================================================================
  @types @core
  Scenario: Mesh Core types are properly defined
    Given the Cepaf.Mesh.Core module is loaded
    Then the following types should be available
      | Type              | Members                                    |
      | BootPhase         | Preflight, Foundation, Mesh, Cognitive, etc |
      | FractalLayer      | L0 through L7                              |
      | QuorumStatus      | Achieved, NotAchieved, InsufficientNodes   |
      | VerbosityLevel    | Minimal, Standard, Verbose, Debug          |
      | TestEvidence      | Timestamp, TestId, StackTrace, etc         |
      | BootMetrics       | TotalDurationMs, PhaseDurations, etc       |
    And the MeshUtils module should provide utility functions

  # ==========================================================================
  # SC-CEPAF-003: SIL6 Mesh Orchestrator Execution
  # ==========================================================================
  @orchestrator @sil6
  Scenario: SIL6MeshOrchestrator.fsx boots the mesh correctly
    When I execute "dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx -- boot"
    Then the orchestrator should complete all 5 stages
      | Stage           | Description                    |
      | S0_PREFLIGHT    | Environment validation         |
      | S1_INFRASTRUCTURE | DB + Observability boot       |
      | S2_ZENOH_MESH   | Zenoh router mesh formation    |
      | S3_APP_SEED     | Application container boot     |
      | S4_HOMEOSTASIS  | Health verification            |
    And each stage should be logged with timestamps
    And the Digital Twin should be updated after each stage

  # ==========================================================================
  # SC-CEPAF-004: Enhanced Swarm Orchestrator with Verbosity
  # ==========================================================================
  @orchestrator @swarm @verbosity
  Scenario: EnhancedSwarmOrchestrator supports verbosity levels
    When I execute "dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx -- --help"
    Then the help output should show verbosity options
      | Option             | Description                    |
      | --verbosity <lvl>  | Set output verbosity           |
      | -v, --verbose      | Verbose output                 |
      | -q, --quiet        | Minimal output (CI/CD)         |
      | -d, --debug        | Debug output with full state   |
    And the "metrics" command should be available

  @orchestrator @swarm @minimal
  Scenario: EnhancedSwarmOrchestrator minimal verbosity for CI/CD
    When I execute "dotnet fsi EnhancedSwarmOrchestrator.fsx -- -q dag"
    Then output should only show [OK] and [FAIL] markers
    And detailed timestamps should be suppressed
    And the log file should still contain full details

  # ==========================================================================
  # SC-CEPAF-005: Mathematical Foundations Integration
  # ==========================================================================
  @math @cpm @dag
  Scenario: Mathematical optimization modules are functional
    Given the MathematicalStartupOptimization module is loaded
    When I execute critical path analysis on the 15-container DAG
    Then the topological sort should complete without cycles
    And the critical path should be identified
    And RCPSP resource constraints should be validated
    And the DFA state machine should accept valid transitions

  # ==========================================================================
  # SC-CEPAF-006: Podman Integration
  # ==========================================================================
  @podman @container
  Scenario: CEPAF Podman module manages containers correctly
    Given the Cepaf.Podman module is loaded
    When I request container status for "indrajaal-db-prod"
    Then the module should return accurate container state
    And the following operations should be available
      | Operation     | Description                    |
      | start         | Start a container              |
      | stop          | Stop a container gracefully    |
      | restart       | Restart a container            |
      | inspect       | Get container details          |
      | logs          | Stream container logs          |
      | health        | Check container health         |

  # ==========================================================================
  # SC-CEPAF-007: Digital Twin State Management
  # ==========================================================================
  @digital-twin @state
  Scenario: Digital Twin accurately reflects mesh state
    Given the full swarm is running
    When I query the Digital Twin state
    Then it should contain state for all 15 containers
    And each container state should include
      | Field           | Type        |
      | Name            | string      |
      | Status          | HolonState  |
      | Health          | string      |
      | Uptime          | TimeSpan    |
      | FractalLayer    | L0-L7       |
    And the QuorumStatus should be accurate
    And the BiomorphicHealth should be populated

  # ==========================================================================
  # SC-CEPAF-008: 7-Level RCA Execution
  # ==========================================================================
  @rca @failure-analysis
  Scenario: 7-Level RCA provides comprehensive failure analysis
    Given a container failure has occurred
    When I execute "dotnet fsi EnhancedSwarmOrchestrator.fsx -- rca 'Container crashed'"
    Then the RCA should analyze all 7 levels
      | Level | Focus                          |
      | L1    | What happened?                 |
      | L2    | Why did it happen?             |
      | L3    | Root cause identification      |
      | L4    | Contributing factors           |
      | L5    | Prevention recommendations     |
      | L6    | System improvements            |
      | L7    | Constitutional alignment       |
    And recommendations should be generated
    And the RCA report should be persisted
