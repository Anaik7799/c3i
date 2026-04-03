# BDD Integration Architecture - 5-Order Impact Analysis

**Version**: 2.0.0
**Date**: 2026-01-03 (Updated: 2026-03-19)
**STAMP**: SC-BDD-001 to SC-BDD-025
**Status**: SPECIFICATION (Synced with v21.3.0-SIL6, Sprint 51)

---

## 1. Executive Overview

This document specifies the integration of seven BDD tools into the Indrajaal v21.3.0-SIL6 ecosystem, with comprehensive 5-order impact analysis across the complete SDLC lifecycle.

> **Updated 2026-03-19**: Synced with v21.3.0-SIL6 after Sprints 47-51. Current codebase: 1,508 Elixir files, 923 F# modules, 1,005 test files, 102 devenv commands, 15-container SIL-6 mesh.

### 1.1 Integrated Tools

| Tool | Role | Language Support | Integration Point |
|------|------|------------------|-------------------|
| **Cucumber** | Primary BDD Engine | Elixir/Ruby | Feature Files |
| **SpecFlow** | .NET/F# BDD | F#/C# | CEPAF Cockpit |
| **JBehave** | Java BDD | JVM (Clojure interop) | External Services |
| **Concordion** | Acceptance Testing | Java/Markdown | Documentation |
| **FitNesse** | Wiki-Based BDD | Java | Requirements Wiki |
| **TestLeft** | UI Object Spy | Multi-platform | Puppeteer Bridge |
| **Flatlogic** | AI-Generated Apps | JavaScript | Code Generation |

### 1.2 Verification Layer Stack

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        L7: MATHEMATICAL PROOFS                          │
│                    (Agda, Mathematica, Quint, Coq)                     │
├─────────────────────────────────────────────────────────────────────────┤
│                        L6: GRAPH-BASED ANALYSIS                         │
│              (CFG, DFG, Call Graph, Dependency Graph)                   │
├─────────────────────────────────────────────────────────────────────────┤
│                        L5: FMEA RISK ANALYSIS                           │
│                    (RPN Calculation, Hazard Trees)                      │
├─────────────────────────────────────────────────────────────────────────┤
│                        L4: TDG PROPERTY TESTING                         │
│              (PropCheck, ExUnitProperties, FsCheck)                     │
├─────────────────────────────────────────────────────────────────────────┤
│                        L3: BDD ACCEPTANCE TESTS                         │
│         (Cucumber, SpecFlow, JBehave, Concordion, FitNesse)            │
├─────────────────────────────────────────────────────────────────────────┤
│                        L2: INTEGRATION TESTS                            │
│                    (Wallaby, Puppeteer, TestLeft)                       │
├─────────────────────────────────────────────────────────────────────────┤
│                        L1: UNIT TESTS                                   │
│                    (ExUnit, Expecto, xUnit)                             │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. SDLC Phase Integration

### 2.1 Phase 1: SPECIFICATION

#### 2.1.1 Tools Applied
- **FitNesse**: Wiki-based requirements capture
- **Concordion**: Executable specifications in Markdown
- **Flatlogic**: AI-assisted requirement extraction

#### 2.1.2 Artifacts Produced
```
docs/specs/
├── requirements/
│   ├── FitNesse/                    # Wiki pages
│   │   ├── PrajnaCockpit.wiki
│   │   ├── GuardianIntegration.wiki
│   │   └── SentinelBridge.wiki
│   ├── concordion/                  # Markdown specs
│   │   ├── prajna-commands.md
│   │   ├── alarm-processing.md
│   │   └── access-control.md
│   └── ai-generated/                # Flatlogic output
│       └── domain-models.json
├── formal/
│   ├── agda/                        # Type-level proofs
│   │   ├── GuardianInvariants.agda
│   │   └── RegisterIntegrity.agda
│   ├── quint/                       # Temporal specs
│   │   ├── prajna_state.qnt
│   │   └── ooda_cycle.qnt
│   └── mathematica/                 # Mathematical models
│       ├── HealthPropagation.nb
│       └── ThreatDetection.nb
└── graphs/
    ├── dependency_graph.dot
    ├── call_graph.dot
    └── state_machine.dot
```

#### 2.1.3 5-Order Impact Analysis (Specification)

| Order | Impact | Time Scale | Mitigation |
|-------|--------|------------|------------|
| **1st** | Requirements captured in executable format | Immediate | Review gate |
| **2nd** | Stakeholders align on behavior expectations | Hours | Approval workflow |
| **3rd** | Design constraints emerge from specs | Days | Architecture review |
| **4th** | Implementation complexity estimated accurately | Weeks | Sprint planning |
| **5th** | Maintenance burden reduced by living docs | Months | Auto-sync with code |

---

### 2.2 Phase 2: DESIGN

#### 2.2.1 Tools Applied
- **JBehave**: Story-driven design
- **Cucumber**: Feature-driven design
- **Graph Analysis**: Dependency mapping

#### 2.2.2 Design Artifacts
```gherkin
# Feature: Guardian-Approved Command Execution
# File: features/design/guardian_command.feature

@design @guardian @P0
Feature: Guardian Pre-Approval Architecture
  As a system architect
  I want all Prajna commands to require Guardian approval
  So that constitutional invariants are never violated

  Background:
    Given the Guardian module is operational
    And constitutional invariants Ψ₀-Ψ₅ are loaded

  @design-decision
  Scenario: Command Flow Architecture
    Given a command originates from Prajna Cockpit
    When the command reaches the execution layer
    Then it MUST pass through Guardian.validate/2
    And Guardian MUST check Ψ₄ (Founder Alignment)
    And Guardian MUST return {:ok, approved} or {:veto, reason, fallback}
    And the decision MUST be logged to ImmutableRegister

  @design-constraint
  Scenario: Latency Budget Allocation
    Given the total command latency budget is 100ms (SC-BIO-001)
    Then Guardian validation MUST complete in < 20ms
    And ImmutableRegister write MUST complete in < 10ms
    And Network round-trip MUST complete in < 50ms
    And Remaining 20ms for execution overhead
```

#### 2.2.3 Graph-Based Design Analysis

```python
# Design dependency graph analysis
design_graph = {
    "PrajnaCockpit": ["Guardian", "SmartMetrics", "AiCopilot"],
    "Guardian": ["Constitution", "ImmutableRegister", "Sentinel"],
    "SmartMetrics": ["SentinelBridge", "ZenohPublisher"],
    "AiCopilot": ["AiCopilotFounder", "OpenRouter"],
    "ImmutableRegister": ["DuckDB", "Ed25519", "SHA3"],
    "Sentinel": ["PatternHunter", "Antibody", "Mara"]
}

# Critical path: PrajnaCockpit → Guardian → Constitution
# Latency: 20ms + 5ms = 25ms (within budget)
```

#### 2.2.4 5-Order Impact Analysis (Design)

| Order | Impact | Time Scale | Mitigation |
|-------|--------|------------|------------|
| **1st** | Component interfaces defined | Immediate | API contracts |
| **2nd** | Module boundaries crystallize | Hours | Boundary tests |
| **3rd** | Data flow patterns emerge | Days | Sequence diagrams |
| **4th** | Performance bottlenecks identified | Weeks | Load testing |
| **5th** | Technical debt accumulation predicted | Months | Refactoring budget |

---

### 2.3 Phase 3: ARCHITECTURE

#### 2.3.1 Tools Applied
- **Quint**: Temporal logic verification
- **Agda**: Type-level architecture proofs
- **Mathematica**: Performance modeling

#### 2.3.2 Architectural Verification

```quint
// File: docs/formal_specs/prajna_architecture.qnt
// STAMP: SC-ARCH-001

module PrajnaArchitecture {
  // Type definitions
  type CommandResult = Ok(string) | Veto(string, Fallback) | Pending(ProposalId)
  type ConstitutionalCheck = { passed: bool, violations: Set[string] }

  // State variables
  var guardianState: GuardianState
  var registerState: RegisterState
  var sentinelState: SentinelState

  // Invariant: Guardian MUST be consulted for all mutations
  invariant GuardianMandatory =
    forall cmd in executedCommands:
      cmd.guardianApproved == true

  // Invariant: Constitution MUST never be violated
  invariant ConstitutionalIntegrity =
    forall check in constitutionalChecks:
      check.passed == true implies check.violations.isEmpty()

  // Temporal: Eventually all pending proposals resolve
  temporal EventualResolution =
    forall p in pendingProposals:
      eventually (p.status == Approved or p.status == Rejected)

  // Safety: No command executes without proof token
  invariant ProofTokenRequired =
    forall cmd in executedCommands:
      cmd.proofToken != null and cmd.proofToken.valid == true
}
```

#### 2.3.3 Agda Type-Level Proofs

```agda
-- File: docs/formal_specs/GuardianProofs.agda
-- Proves Guardian cannot be bypassed

module GuardianProofs where

open import Data.Bool
open import Data.Product
open import Relation.Binary.PropositionalEquality

-- Guardian approval is a prerequisite for execution
record GuardianApproval : Set where
  field
    proposalId : String
    approved   : Bool
    timestamp  : Nat

-- Command execution requires Guardian approval
data ExecutionResult : Set where
  Executed : GuardianApproval → ExecutionResult
  Blocked  : String → ExecutionResult

-- Theorem: No execution without approval
noBypass : ∀ (cmd : Command) →
           (¬ (hasApproval cmd)) →
           ExecutionResult cmd ≡ Blocked "Guardian approval required"
noBypass cmd noApproval = refl

-- Theorem: Approved commands preserve constitution
preservesConstitution : ∀ (cmd : Command) (approval : GuardianApproval) →
                        (GuardianApproval.approved approval ≡ true) →
                        ConstitutionValid (execute cmd)
preservesConstitution cmd approval isApproved = constitutionPreserved
```

#### 2.3.4 5-Order Impact Analysis (Architecture)

| Order | Impact | Time Scale | Mitigation |
|-------|--------|------------|------------|
| **1st** | Layered architecture enforced | Immediate | Layer violation tests |
| **2nd** | Cross-cutting concerns identified | Hours | Aspect-oriented design |
| **3rd** | Scalability patterns selected | Days | Load simulation |
| **4th** | Failure modes catalogued | Weeks | FMEA analysis |
| **5th** | Evolution pathways defined | Months | Migration guides |

---

### 2.4 Phase 4: IMPLEMENTATION

#### 2.4.1 Tools Applied
- **Cucumber/Wallaby**: Elixir BDD
- **SpecFlow**: F# BDD for CEPAF
- **TestLeft**: UI automation
- **PropCheck/FsCheck**: Property testing

#### 2.4.2 Implementation BDD

```gherkin
# File: test/features/implementation/guardian_integration.feature
# STAMP: SC-IMP-001

@implementation @guardian
Feature: Guardian Integration Implementation

  Background:
    Given the Guardian GenServer is started
    And the Constitution module is loaded
    And the ImmutableRegister is initialized

  @unit @TDG
  Scenario: Submit proposal to Guardian
    Given a valid command proposal:
      | field         | value                        |
      | command_type  | prajna_command               |
      | target_module | SmartMetrics                 |
      | payload       | {"action": "refresh"}        |
      | justification | Routine dashboard refresh    |
    When I call Guardian.submit_proposal/1
    Then the result should be {:ok, proposal_id}
    And the proposal should be recorded in state
    And telemetry event [:guardian, :proposal, :submitted] should fire

  @property @PropCheck
  Scenario: Property - All proposals get unique IDs
    Given I generate 1000 random proposals using PropCheck
    When I submit all proposals
    Then all proposal IDs should be unique
    And no ID collisions should occur

  @property @FsCheck
  Scenario: Property - Veto reasons are never empty
    Given I generate proposals that will be vetoed
    When Guardian vetos with {:veto, reason, fallback}
    Then reason should never be empty string
    And fallback should be a valid action
```

#### 2.4.3 SpecFlow for F# CEPAF

```fsharp
// File: lib/cepaf/test/Cepaf.Tests/Features/Integration.feature.fs
// STAMP: SC-IMP-002

namespace Cepaf.Tests.Features

open TickSpec
open Expecto

module IntegrationSteps =

    let [<Given>] ``the Integration controller is initialized`` () =
        let config = Integration.defaultIntegrationConfig
        let state = Integration.create config
        state

    let [<When>] ``I connect to the Elixir backend`` (state: IntegrationState) =
        async {
            return! Integration.connect state
        } |> Async.RunSynchronously

    let [<Then>] ``the connection should succeed`` (result: Result<IntegrationState, string>) =
        match result with
        | Ok state ->
            Expect.isTrue state.IsConnected "Should be connected"
        | Error msg ->
            failwithf "Connection failed: %s" msg

    let [<Then>] ``health score should be above (\d+)`` (threshold: int) (state: IntegrationState) =
        match Integration.getHealth state with
        | Some metrics ->
            Expect.isGreaterThan metrics.HealthScore (float threshold) "Health below threshold"
        | None ->
            failwith "No health metrics available"
```

#### 2.4.4 TDG Property Testing Integration

```elixir
# File: test/indrajaal/cockpit/prajna/guardian_tdg_test.exs
# STAMP: SC-TDG-001, SC-PROP-023

defmodule Indrajaal.Cockpit.Prajna.GuardianTDGTest do
  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # TDG-001: Proposal ID uniqueness
  property "all proposal IDs are unique" do
    forall proposals <- PC.list(proposal_generator()) do
      ids = Enum.map(proposals, & &1.id)
      length(ids) == length(Enum.uniq(ids))
    end
  end

  # TDG-002: Veto reasons non-empty
  property "veto reasons are never empty", [:verbose] do
    forall proposal <- vetoed_proposal_generator() do
      case Guardian.validate(proposal) do
        {:veto, reason, _fallback} ->
          String.length(reason) > 0
        _ ->
          true  # Not vetoed, skip
      end
    end
  end

  # TDG-003: Constitutional invariants preserved
  property "constitution preserved after any command" do
    forall cmd <- command_generator() do
      initial_state = Constitution.snapshot()
      {:ok, _} = Guardian.execute(cmd)
      final_state = Constitution.snapshot()
      Constitution.invariants_preserved?(initial_state, final_state)
    end
  end

  # Generators
  defp proposal_generator do
    let {cmd_type, target, payload} <- {
      PC.oneof([:prajna_command, :system_command, :query]),
      PC.oneof([:SmartMetrics, :AiCopilot, :SentinelBridge]),
      PC.map()
    } do
      %{
        id: UUID.uuid4(),
        command_type: cmd_type,
        target_module: target,
        payload: payload,
        timestamp: DateTime.utc_now()
      }
    end
  end
end
```

#### 2.4.5 5-Order Impact Analysis (Implementation)

| Order | Impact | Time Scale | Mitigation |
|-------|--------|------------|------------|
| **1st** | Code matches BDD specifications | Immediate | CI/CD gates |
| **2nd** | Refactoring guided by failing specs | Hours | Red-green-refactor |
| **3rd** | Edge cases discovered via properties | Days | Property coverage |
| **4th** | Performance regressions caught | Weeks | Benchmark suite |
| **5th** | API stability maintained | Months | Contract testing |

---

### 2.5 Phase 5: TESTING

#### 2.5.1 Multi-Layer Test Strategy

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     TESTING VERIFICATION PYRAMID                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                          ▲ Mathematical Proofs                          │
│                         ╱ ╲  (Agda, Coq)                               │
│                        ╱   ╲  10 proofs                                │
│                       ╱─────╲                                          │
│                      ╱ Quint  ╲                                         │
│                     ╱ Temporal ╲ 50 specs                              │
│                    ╱───────────╲                                       │
│                   ╱  FMEA/RPN   ╲                                      │
│                  ╱  Risk Models  ╲ 100 analyses                        │
│                 ╱─────────────────╲                                    │
│                ╱  Graph Analysis   ╲                                   │
│               ╱  CFG/DFG/Call Graph ╲ 200 paths                        │
│              ╱───────────────────────╲                                 │
│             ╱    BDD Feature Tests    ╲                                │
│            ╱  Cucumber/SpecFlow/JBehave╲ 500 scenarios                 │
│           ╱───────────────────────────────╲                            │
│          ╱      Property-Based Tests       ╲                           │
│         ╱    PropCheck/FsCheck/Hypothesis   ╲ 1000 properties          │
│        ╱─────────────────────────────────────╲                         │
│       ╱          Integration Tests            ╲                        │
│      ╱     Wallaby/Puppeteer/TestLeft          ╲ 2000 tests           │
│     ╱───────────────────────────────────────────╲                      │
│    ╱              Unit Tests                     ╲                     │
│   ╱        ExUnit/Expecto/xUnit                   ╲ 5000 tests        │
│  ╱─────────────────────────────────────────────────╲                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 2.5.2 FMEA Integration with BDD

```gherkin
# File: test/features/fmea/guardian_fmea.feature
# STAMP: SC-FMEA-001

@fmea @safety
Feature: Guardian FMEA Analysis
  As a safety engineer
  I want failure modes analyzed
  So that critical paths have mitigations

  @fmea-critical @RPN-72
  Scenario: FM-GRD-001 Guardian Process Crash
    Given failure mode "Guardian GenServer crash"
    And severity is 8 (system cannot process commands)
    And occurrence is 3 (rare with OTP supervision)
    And detection is 3 (immediate via telemetry)
    Then RPN should be 72
    And mitigation should be "OTP Supervisor restart_permanent"
    And fallback should be "Queue commands for 5s, retry"
    And test coverage should verify restart < 100ms

  @fmea-high @RPN-48
  Scenario: FM-GRD-002 Guardian Timeout
    Given failure mode "Guardian.validate/2 exceeds 20ms"
    And severity is 6 (command delayed)
    And occurrence is 4 (possible under load)
    And detection is 2 (telemetry histogram)
    Then RPN should be 48
    And mitigation should be "Circuit breaker with cached decisions"
    And test coverage should include load testing at 1000 req/s

  @fmea-medium @RPN-24
  Scenario: FM-GRD-003 Invalid Proposal Format
    Given failure mode "Malformed proposal struct"
    And severity is 4 (single command fails)
    And occurrence is 3 (input validation)
    And detection is 2 (compile-time checks)
    Then RPN should be 24
    And mitigation should be "Ecto changeset validation"
```

#### 2.5.3 Graph-Based Path Analysis

```elixir
# File: test/support/graph_analysis.ex
# STAMP: SC-GRAPH-001

defmodule Indrajaal.Test.GraphAnalysis do
  @moduledoc """
  Graph-based test path analysis for comprehensive coverage.

  Integrates with BDD via @graph tags in feature files.
  """

  @doc """
  Analyze control flow graph for a module.
  Returns paths that require BDD coverage.
  """
  def analyze_cfg(module) do
    {:ok, ast} = Code.string_to_quoted(File.read!(source_path(module)))

    cfg = build_cfg(ast)
    paths = enumerate_paths(cfg)
    critical_paths = filter_critical(paths)

    %{
      total_paths: length(paths),
      critical_paths: length(critical_paths),
      coverage_required: Enum.map(critical_paths, &path_to_scenario/1)
    }
  end

  @doc """
  Generate BDD scenarios from critical paths.
  """
  def generate_bdd_scenarios(module) do
    %{coverage_required: paths} = analyze_cfg(module)

    Enum.map(paths, fn path ->
      """
      @graph @auto-generated
      Scenario: Path coverage for #{path.name}
        Given the system is in state "#{path.initial_state}"
        When #{path.trigger_event}
        Then the system should transition to "#{path.final_state}"
        And path "#{path.id}" should be covered
      """
    end)
    |> Enum.join("\n\n")
  end

  @doc """
  Verify all graph paths have BDD coverage.
  """
  def verify_coverage(feature_file, module) do
    {:ok, features} = parse_feature(feature_file)
    %{critical_paths: paths} = analyze_cfg(module)

    covered = Enum.filter(paths, fn path ->
      Enum.any?(features.scenarios, fn scenario ->
        scenario.tags |> Enum.member?("@path-#{path.id}")
      end)
    end)

    %{
      total_paths: length(paths),
      covered_paths: length(covered),
      missing: paths -- covered,
      coverage_percent: length(covered) / length(paths) * 100
    }
  end
end
```

#### 2.5.4 5-Order Impact Analysis (Testing)

| Order | Impact | Time Scale | Mitigation |
|-------|--------|------------|------------|
| **1st** | Defects caught before merge | Immediate | PR gates |
| **2nd** | Regression suite expands | Hours | Auto-generated tests |
| **3rd** | Test maintenance burden | Days | Living documentation |
| **4th** | Flaky tests identified | Weeks | Stability metrics |
| **5th** | Test suite evolution | Months | Coverage trending |

---

### 2.6 Phase 6: USAGE (Operations)

#### 2.6.1 Tools Applied
- **FitNesse**: Acceptance criteria validation
- **Concordion**: User documentation generation
- **TestLeft**: Production smoke tests

#### 2.6.2 Operational BDD

```gherkin
# File: test/features/operations/production_smoke.feature
# STAMP: SC-OPS-001

@operations @smoke @production
Feature: Production Smoke Tests
  As an operations engineer
  I want quick validation of production health
  So that deployments are verified

  Background:
    Given production environment is accessible
    And monitoring is active

  @smoke @P0 @latency-30s
  Scenario: Health endpoint responds
    When I GET "https://indrajaal.prod/api/health"
    Then response status should be 200
    And response time should be < 500ms
    And response should contain:
      | field        | expected       |
      | status       | ok             |
      | guardian     | operational    |
      | sentinel     | active         |

  @smoke @P0 @latency-60s
  Scenario: Prajna Cockpit loads
    When I navigate to "https://indrajaal.prod/prajna"
    Then page should load within 2 seconds
    And WebSocket connection should establish
    And dashboard should show health score > 80

  @smoke @P1 @latency-120s
  Scenario: Command execution works
    Given I am authenticated as operator
    When I execute a test command via Prajna
    Then Guardian should approve within 1 second
    And command should execute within 2 seconds
    And result should be logged to ImmutableRegister
```

#### 2.6.3 Living Documentation Generation

```elixir
# File: lib/mix/tasks/docs.living.ex
# STAMP: SC-DOC-001

defmodule Mix.Tasks.Docs.Living do
  @moduledoc """
  Generates living documentation from BDD features.

  Integrates Concordion-style specs with test results.
  """
  use Mix.Task

  def run(_args) do
    features = Path.wildcard("test/features/**/*.feature")
    test_results = load_test_results()

    docs = Enum.map(features, fn feature ->
      %{
        name: Path.basename(feature, ".feature"),
        content: File.read!(feature),
        scenarios: parse_scenarios(feature),
        results: Map.get(test_results, feature, %{}),
        last_run: get_last_run(feature)
      }
    end)

    generate_html(docs, "docs/living/")
    generate_json(docs, "docs/living/api/")

    IO.puts("Generated living documentation for #{length(docs)} features")
  end
end
```

#### 2.6.4 5-Order Impact Analysis (Usage)

| Order | Impact | Time Scale | Mitigation |
|-------|--------|------------|------------|
| **1st** | User validates functionality | Immediate | Acceptance tests |
| **2nd** | Support tickets categorized | Hours | Error taxonomy |
| **3rd** | Usage patterns emerge | Days | Analytics integration |
| **4th** | Feature adoption measured | Weeks | A/B testing |
| **5th** | Product roadmap informed | Months | User feedback loop |

---

### 2.7 Phase 7: MONITORING

#### 2.7.1 Tools Applied
- **Cucumber**: Alert verification tests
- **JBehave**: SLA compliance stories
- **Graph Analysis**: Anomaly detection

#### 2.7.2 Monitoring BDD

```gherkin
# File: test/features/monitoring/sla_compliance.feature
# STAMP: SC-MON-001

@monitoring @sla @continuous
Feature: SLA Compliance Monitoring
  As an SRE
  I want automated SLA verification
  So that breaches are detected immediately

  Background:
    Given Prometheus is scraping metrics
    And Grafana dashboards are configured
    And alert rules are active

  @sla @availability
  Scenario: 99.9% Availability SLA
    Given the SLA target is 99.9% monthly availability
    When I query Prometheus for uptime metrics
    Then availability should be >= 99.9%
    And if breached, PagerDuty alert should fire
    And incident should be created in ServiceNow

  @sla @latency
  Scenario: P99 Latency SLA
    Given the SLA target is P99 < 200ms
    When I query Prometheus histogram for http_request_duration_seconds
    Then P99 latency should be < 200ms
    And trend should not show degradation
    And anomaly score should be < 3 sigma

  @sla @error-rate
  Scenario: Error Rate SLA
    Given the SLA target is < 0.1% error rate
    When I calculate error_count / total_requests
    Then error rate should be < 0.001
    And new error types should trigger investigation
```

#### 2.7.3 Anomaly Detection Integration

```elixir
# File: lib/indrajaal/observability/anomaly_detector.ex
# STAMP: SC-MON-002

defmodule Indrajaal.Observability.AnomalyDetector do
  @moduledoc """
  Graph-based anomaly detection integrated with BDD alerts.

  Uses dependency graph to identify cascade failures.
  """
  use GenServer

  alias Indrajaal.Observability.{MetricsStore, DependencyGraph}

  @doc """
  Detect anomalies using graph-based analysis.
  """
  def detect_anomalies(metrics) do
    graph = DependencyGraph.current()

    # 1st order: Direct metric anomalies
    direct_anomalies = detect_direct(metrics)

    # 2nd order: Downstream impact
    downstream = Enum.flat_map(direct_anomalies, fn anomaly ->
      DependencyGraph.downstream_nodes(graph, anomaly.node)
    end)

    # 3rd order: Cascade prediction
    cascade_risk = calculate_cascade_risk(graph, direct_anomalies)

    # 4th order: SLA impact prediction
    sla_impact = predict_sla_impact(cascade_risk)

    # 5th order: Business impact
    business_impact = calculate_business_impact(sla_impact)

    %{
      direct: direct_anomalies,
      downstream_at_risk: downstream,
      cascade_probability: cascade_risk,
      sla_impact: sla_impact,
      business_impact: business_impact,
      recommended_actions: generate_runbook_links(direct_anomalies)
    }
  end

  @doc """
  Generate BDD scenario for detected anomaly.
  """
  def to_bdd_scenario(anomaly) do
    """
    @anomaly @auto-generated @#{anomaly.severity}
    Scenario: Detected anomaly in #{anomaly.node}
      Given the system was healthy at #{anomaly.baseline_time}
      And metric "#{anomaly.metric}" was #{anomaly.baseline_value}
      When anomaly detected at #{anomaly.detection_time}
      And current value is #{anomaly.current_value}
      Then deviation is #{anomaly.deviation} sigma
      And downstream nodes at risk: #{Enum.join(anomaly.downstream, ", ")}
      And recommended action: #{anomaly.recommended_action}
    """
  end
end
```

#### 2.7.4 5-Order Impact Analysis (Monitoring)

| Order | Impact | Time Scale | Mitigation |
|-------|--------|------------|------------|
| **1st** | Metrics collected continuously | Milliseconds | Sampling rate |
| **2nd** | Alerts fire on thresholds | Seconds | Alert tuning |
| **3rd** | On-call engineer responds | Minutes | Runbooks |
| **4th** | Incident resolved | Hours | Post-mortems |
| **5th** | System hardening applied | Days/Weeks | Chaos engineering |

---

## 3. STAMP Safety Constraints (BDD Integration)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-BDD-001 | All user stories MUST have BDD scenarios | CRITICAL | CI gate |
| SC-BDD-002 | BDD scenarios MUST be executable | CRITICAL | Test runner |
| SC-BDD-003 | Feature files MUST use Gherkin syntax | HIGH | Linter |
| SC-BDD-004 | Scenarios MUST have unique names | HIGH | Parser |
| SC-BDD-005 | Background MUST be minimal | MEDIUM | Review |
| SC-BDD-006 | Tags MUST follow taxonomy | HIGH | Validator |
| SC-BDD-007 | Property tests MUST use PC/SD aliases | CRITICAL | SC-PROP-023 |
| SC-BDD-008 | FMEA RPN > 50 MUST have mitigation | CRITICAL | Audit |
| SC-BDD-009 | Graph coverage MUST be > 80% | HIGH | Analysis |
| SC-BDD-010 | Living docs MUST be auto-generated | MEDIUM | CI |
| SC-BDD-011 | Quint specs MUST pass model check | CRITICAL | Verifier |
| SC-BDD-012 | Agda proofs MUST type-check | CRITICAL | Compiler |
| SC-BDD-013 | Smoke tests MUST run < 5 minutes | HIGH | Timeout |
| SC-BDD-014 | SLA tests MUST run hourly | HIGH | Scheduler |
| SC-BDD-015 | Anomaly BDD MUST be auto-generated | MEDIUM | Detector |

---

## 4. AOR Rules (BDD Integration)

| ID | Rule |
|----|------|
| AOR-BDD-001 | Write feature file BEFORE implementation code |
| AOR-BDD-002 | Run BDD suite on every PR |
| AOR-BDD-003 | Failed scenarios BLOCK merge |
| AOR-BDD-004 | Property tests accompany all BDD scenarios |
| AOR-BDD-005 | FMEA analysis for critical features |
| AOR-BDD-006 | Graph analysis for complex modules |
| AOR-BDD-007 | Living docs published on merge to main |
| AOR-BDD-008 | Smoke tests run post-deployment |
| AOR-BDD-009 | SLA scenarios in monitoring dashboards |
| AOR-BDD-010 | Anomaly scenarios feed incident response |

---

## 5. Integration Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         BDD INTEGRATION ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐    │
│  │   FitNesse   │   │  Concordion  │   │  Flatlogic   │   │    Quint     │    │
│  │  Wiki Specs  │   │  Markdown    │   │  AI Gen      │   │  Temporal    │    │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘   └──────┬───────┘    │
│         │                  │                  │                  │             │
│         ▼                  ▼                  ▼                  ▼             │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                     SPECIFICATION LAYER                                  │  │
│  │                  (docs/specs/, docs/formal_specs/)                       │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                    │                                           │
│                                    ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                       DESIGN LAYER                                       │  │
│  │                    (Feature-Driven Design)                               │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐        │  │
│  │  │  Cucumber  │  │  SpecFlow  │  │  JBehave   │  │   Agda     │        │  │
│  │  │  Elixir    │  │  F#/C#     │  │  Java      │  │  Proofs    │        │  │
│  │  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘        │  │
│  └────────┼───────────────┼───────────────┼───────────────┼────────────────┘  │
│           │               │               │               │                    │
│           ▼               ▼               ▼               ▼                    │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                    IMPLEMENTATION LAYER                                  │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │  │
│  │  │                    TEST EXECUTION ENGINE                         │   │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │   │  │
│  │  │  │ ExUnit   │  │ Expecto  │  │ Wallaby  │  │ TestLeft │        │   │  │
│  │  │  │ +PropChk │  │ +FsCheck │  │+Puppeteer│  │ UI Spy   │        │   │  │
│  │  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘        │   │  │
│  │  │       │             │             │             │               │   │  │
│  │  │       ▼             ▼             ▼             ▼               │   │  │
│  │  │  ┌────────────────────────────────────────────────────────┐    │   │  │
│  │  │  │              UNIFIED TEST RESULTS                      │    │   │  │
│  │  │  │        (JUnit XML, Allure, Custom JSON)               │    │   │  │
│  │  │  └────────────────────────────────────────────────────────┘    │   │  │
│  │  └─────────────────────────────────────────────────────────────────┘   │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                    │                                           │
│                                    ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                      ANALYSIS LAYER                                      │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │  │
│  │  │  FMEA/RPN    │  │ Graph CFG/   │  │ Mathematica  │                   │  │
│  │  │  Analysis    │  │ DFG Analysis │  │  Modeling    │                   │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘                   │  │
│  └─────────┼─────────────────┼─────────────────┼────────────────────────────┘  │
│            │                 │                 │                               │
│            ▼                 ▼                 ▼                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                     OPERATIONS LAYER                                     │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │  │
│  │  │ Living Docs  │  │ Smoke Tests  │  │ SLA Monitor  │                   │  │
│  │  │ Generation   │  │ Production   │  │ Dashboards   │                   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                   │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                    │                                           │
│                                    ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                     MONITORING LAYER                                     │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │  │
│  │  │  Prometheus  │  │   Grafana    │  │   Anomaly    │                   │  │
│  │  │   Metrics    │  │  Dashboards  │  │   Detector   │                   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                   │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Implementation Roadmap

### 6.1 Sprint 40: Foundation (Current)
- [ ] Cucumber integration with Wallaby
- [ ] SpecFlow integration with CEPAF
- [ ] Property test aliases (PC/SD)

### 6.2 Sprint 41: Formal Methods
- [ ] Quint model checking integration
- [ ] Agda proof infrastructure
- [ ] Graph analysis tooling

### 6.3 Sprint 42: FMEA/Risk
- [ ] FMEA BDD integration
- [ ] RPN automation
- [ ] Risk dashboard

### 6.4 Sprint 43: Living Docs
- [ ] Concordion-style generation
- [ ] FitNesse wiki integration
- [ ] Auto-publish pipeline

### 6.5 Sprint 44: Monitoring
- [ ] SLA BDD scenarios
- [ ] Anomaly-to-BDD generator
- [ ] Incident integration

---

## 7. Related Documents

- [GA_7LEVEL_FRACTAL_COMMAND_ANALYSIS.md](../verification/GA_7LEVEL_FRACTAL_COMMAND_ANALYSIS.md)
- [GA_RUNTIME_TEST_PLAN.md](../verification/GA_RUNTIME_TEST_PLAN.md)
- [ga_release_verification.feature](../../test/features/ga_release_verification.feature)
- [CLAUDE.md](../../CLAUDE.md)

---

**Document Control**
- Author: Claude Opus 4.5
- Reviewed: Pending
- Approved: Pending
- Classification: Internal
