# Five-Level Test Coverage Framework

**Version**: 1.0.0 | **Date**: 2026-01-03 | **Status**: ACTIVE
**STAMP Compliance**: SC-COV-001 to SC-COV-006, SC-TDG-001 to SC-TDG-010

## Overview

The Five-Level Test Coverage Framework provides comprehensive verification through mathematically rigorous testing at five distinct levels:

1. **Level 1: TDG (Test-Driven Generation)** - Foundation
2. **Level 2: FMEA (Failure Mode Effects Analysis)** - Risk
3. **Level 3: Formal Specification (AGDA/Quint/Mathematica)** - Proofs
4. **Level 4: Graph-Based Path Analysis** - Coverage
5. **Level 5: BDD Integration (Cucumber/SpecFlow)** - Acceptance
6. **Level 6: E2E Browser Testing (Wallaby + Chrome via NixOS)** - LiveView Verification

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│              Level 6: E2E Browser (Wallaby + Chrome)                │
│    Wallaby ── FeatureCase ── PageObjects ── ChromeDriver           │
├─────────────────────────────────────────────────────────────────────┤
│                    Level 5: BDD Integration                         │
│    Cucumber ── SpecFlow ── JBehave ── Concordion ── Gherkin        │
├─────────────────────────────────────────────────────────────────────┤
│                Level 4: Graph-Based Path Analysis                   │
│         Control Flow ── Data Flow ── Call Graph ── FSM             │
├─────────────────────────────────────────────────────────────────────┤
│           Level 3: Formal Specification & Proofs                    │
│              AGDA ── Quint ── Mathematica ── TLA+                  │
├─────────────────────────────────────────────────────────────────────┤
│            Level 2: FMEA Risk Analysis                              │
│      Failure Modes ── RPN Scores ── Mitigations ── HAZOP           │
├─────────────────────────────────────────────────────────────────────┤
│              Level 1: TDG Foundation                                │
│     Unit Tests ── Property Tests ── Integration Tests               │
└─────────────────────────────────────────────────────────────────────┘
```

## Level 1: TDG (Test-Driven Generation)

### Description
Tests MUST exist and FAIL before code generation. Dual property testing with PropCheck and ExUnitProperties.

### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-TDG-001 | Tests MUST exist before code | CRITICAL |
| SC-TDG-002 | Tests MUST fail before implementation | CRITICAL |
| SC-TDG-003 | Dual property tests mandatory | HIGH |
| SC-TDG-004 | Coverage >= 95% | HIGH |

### Implementation

```elixir
# Required test header (EP-GEN-014 compliant)
defmodule MyModuleTest do
  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # Unit test with assertion
  describe "function_name/1" do
    test "returns expected result" do
      result = MyModule.function_name(:input)
      assert result == :expected
    end
  end

  # Property test with PropCheck
  property "propcheck: always returns valid result" do
    forall x <- PC.integer() do
      result = MyModule.function_name(x)
      is_valid?(result)
    end
  end

  # Property test with ExUnitProperties
  property "streamdata: handles all integers" do
    check all(x <- SD.integer()) do
      result = MyModule.function_name(x)
      assert is_valid?(result)
    end
  end
end
```

### Metrics
- **Unit Test Coverage**: >= 95%
- **Property Test Coverage**: >= 80%
- **Integration Test Coverage**: >= 70%

---

## Level 2: FMEA (Failure Mode Effects Analysis)

### Description
Systematic analysis of failure modes with Risk Priority Numbers (RPN) and mitigations.

### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-FMEA-001 | All critical paths analyzed | CRITICAL |
| SC-FMEA-002 | RPN > 100 requires mitigation | HIGH |
| SC-FMEA-003 | HAZOP for safety-critical | CRITICAL |
| SC-FMEA-004 | Quarterly review required | MEDIUM |

### FMEA Template

| ID | Failure Mode | Severity (1-10) | Occurrence (1-10) | Detection (1-10) | RPN | Mitigation |
|----|--------------|-----------------|-------------------|------------------|-----|------------|
| FM-001 | Guardian timeout | 8 | 3 | 2 | 48 | Circuit breaker |
| FM-002 | Chain corruption | 10 | 1 | 3 | 30 | Reed-Solomon EC |
| FM-003 | Sentinel unavailable | 7 | 2 | 2 | 28 | Fallback mode |
| FM-004 | API rate limit | 5 | 4 | 1 | 20 | Backoff + scaling |

### RPN Calculation
```
RPN = Severity × Occurrence × Detection

Where:
- Severity: Impact of failure (1=minor, 10=catastrophic)
- Occurrence: Likelihood of failure (1=rare, 10=certain)
- Detection: Ability to detect before impact (1=certain, 10=impossible)
```

### FMEA Test Template

```elixir
defmodule MyModule.FMEATest do
  use ExUnit.Case, async: false

  @tag :fmea
  describe "FM-001: Guardian timeout" do
    test "system recovers from Guardian timeout" do
      # Simulate timeout
      {:error, :timeout} = GuardianIntegration.submit_proposal(slow_guardian())

      # Verify circuit breaker activated
      assert CircuitBreaker.state() == :open

      # Verify system still operational
      assert System.alive?()
    end
  end
end
```

---

## Level 3: Formal Specification & Proofs

### Description
Mathematical proofs using dependent types (AGDA), temporal logic (Quint), and symbolic computation (Mathematica).

### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-FORMAL-001 | Core invariants proven | CRITICAL |
| SC-FORMAL-002 | Type safety proven | HIGH |
| SC-FORMAL-003 | Temporal properties verified | HIGH |
| SC-FORMAL-004 | Symbolic proofs documented | MEDIUM |

### 3.1 AGDA - Dependent Type Proofs

```agda
-- Guardian invariant: No bypass possible
module Guardian.Invariants where

open import Data.Bool
open import Data.Maybe
open import Relation.Binary.PropositionalEquality

-- Type for proposals
record Proposal : Set where
  field
    id : ℕ
    action : Action
    validated : Bool

-- Guardian validation function
validate : Proposal → Decision
validate p with Guardian.check p
... | approved = Approved
... | vetoed r = Vetoed r

-- Proof: All executed proposals are validated
executed-implies-validated : ∀ (p : Proposal) →
  Executed p → validated p ≡ true
executed-implies-validated p exec =
  begin
    validated p
  ≡⟨ exec-requires-validation exec ⟩
    true
  ∎
```

### 3.2 Quint - Temporal Logic Models

```quint
// Immutable Register - Temporal Properties
module ImmutableRegister {
  var blocks: List[Block]
  var chainValid: bool

  // Invariant: Chain always valid
  invariant chainIntegrity = chainValid == true

  // Temporal: Eventually all blocks verified
  temporal eventually_verified =
    always(submit(block) implies eventually(verified(block)))

  // Temporal: No block ever deleted
  temporal append_only =
    always(block in blocks implies always(block in blocks))

  // Action: Submit new block
  action submit(block: Block): bool = {
    val prevHash = if (blocks.isEmpty) GENESIS_HASH else blocks.last.hash
    val newBlock = block.copy(prevHash = prevHash)
    blocks' = blocks.append(newBlock)
    chainValid' = verifyChain(blocks')
    true
  }
}
```

### 3.3 Mathematica - Symbolic Verification

```mathematica
(* Guardian State Machine Verification *)

(* Define states *)
guardianStates = {Idle, Validating, Approved, Vetoed, Timeout};

(* Define transition matrix *)
transitionMatrix = {
  {Idle -> Validating, "submit"},
  {Validating -> Approved, "approve"},
  {Validating -> Vetoed, "veto"},
  {Validating -> Timeout, "timeout"},
  {Approved -> Idle, "complete"},
  {Vetoed -> Idle, "complete"},
  {Timeout -> Idle, "recover"}
};

(* Verify: All paths lead back to Idle *)
VerifyTermination[transitions_] :=
  AllTrue[FindPath[transitions, #, Idle] =!= {} & /@ guardianStates]

(* Verify: No deadlocks *)
VerifyNoDeadlock[transitions_] :=
  AllTrue[OutDegree[transitions, #] >= 1 & /@ guardianStates]

(* Run verification *)
Assert[VerifyTermination[transitionMatrix], "All states terminate"]
Assert[VerifyNoDeadlock[transitionMatrix], "No deadlocks exist"]
```

---

## Level 4: Graph-Based Path Analysis

### Description
Complete coverage through control flow, data flow, call graph, and state machine analysis.

### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-GRAPH-001 | All paths exercised | HIGH |
| SC-GRAPH-002 | Cyclomatic complexity < 15 | MEDIUM |
| SC-GRAPH-003 | Call depth < 10 | MEDIUM |
| SC-GRAPH-004 | No unreachable code | HIGH |

### 4.1 Control Flow Graph (CFG)

```elixir
# Control flow analysis
defmodule CFGAnalyzer do
  @moduledoc """
  Analyzes control flow paths for complete coverage.
  """

  def analyze_function(module, function, arity) do
    {:ok, ast} = Code.fetch_docs(module)
    cfg = build_cfg(ast, function, arity)

    %{
      nodes: count_nodes(cfg),
      edges: count_edges(cfg),
      cyclomatic_complexity: count_edges(cfg) - count_nodes(cfg) + 2,
      paths: enumerate_paths(cfg),
      unreachable: find_unreachable(cfg)
    }
  end
end
```

### 4.2 Data Flow Analysis

```elixir
# Data flow analysis for variable tracking
defmodule DataFlowAnalyzer do
  def track_variable(module, variable) do
    %{
      definitions: find_definitions(module, variable),
      uses: find_uses(module, variable),
      def_use_chains: build_chains(definitions, uses),
      uninitialized_uses: find_uninitialized(chains)
    }
  end
end
```

### 4.3 Call Graph Analysis

```elixir
# Call graph for dependency tracking
defmodule CallGraphAnalyzer do
  def build_call_graph(modules) do
    modules
    |> Enum.flat_map(&extract_calls/1)
    |> build_graph()
    |> analyze_graph()
  end

  def analyze_graph(graph) do
    %{
      max_depth: calculate_max_depth(graph),
      cycles: find_cycles(graph),
      orphans: find_orphan_functions(graph),
      hotspots: find_hotspots(graph)
    }
  end
end
```

### 4.4 State Machine Coverage

```elixir
# FSM state coverage tracking
defmodule FSMCoverage do
  def verify_state_coverage(fsm_module, test_traces) do
    states = fsm_module.states()
    transitions = fsm_module.transitions()

    covered_states = extract_states_from_traces(test_traces)
    covered_transitions = extract_transitions_from_traces(test_traces)

    %{
      state_coverage: MapSet.intersection(states, covered_states) |> MapSet.size() / MapSet.size(states),
      transition_coverage: MapSet.intersection(transitions, covered_transitions) |> MapSet.size() / MapSet.size(transitions),
      uncovered_states: MapSet.difference(states, covered_states),
      uncovered_transitions: MapSet.difference(transitions, covered_transitions)
    }
  end
end
```

---

## Level 5: BDD Integration

### Description
Behavior-Driven Development with Cucumber/Gherkin syntax, integrated with Puppeteer for UI testing.

### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-BDD-001 | All user journeys covered | HIGH |
| SC-BDD-002 | Feature files for all pages | HIGH |
| SC-BDD-003 | Puppeteer screenshots captured | MEDIUM |
| SC-BDD-004 | Step definitions complete | HIGH |

### 5.1 Gherkin Feature Files

All features follow the Gherkin syntax with:
- `Feature:` - High-level description
- `Background:` - Common setup
- `Scenario:` - Specific test case
- `@tags` - Categorization (critical, high, medium, puppeteer)

### 5.2 Puppeteer Integration

```javascript
// Puppeteer test runner
const puppeteer = require('puppeteer');

class PrajnaTester {
  async setup() {
    this.browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox']
    });
    this.page = await this.browser.newPage();
  }

  async testPage(url, testFn) {
    await this.page.goto(`http://localhost:4000${url}`);
    await this.page.waitForSelector('[data-testid="page-loaded"]');

    // Capture screenshot
    await this.page.screenshot({
      path: `screenshots/${url.replace(/\//g, '_')}.png`,
      fullPage: true
    });

    // Run test
    await testFn(this.page);
  }

  async teardown() {
    await this.browser.close();
  }
}
```

### 5.3 Step Definition Template

```elixir
# Elixir step definitions using Wallaby
defmodule PrajnaSteps do
  use Cabbage.Feature
  import Wallaby.Query

  defgiven ~r/^I navigate to "(?<path>[^"]*)"$/, %{path: path}, state do
    {:ok, session} = Wallaby.start_session()
    session = visit(session, path)
    {:ok, Map.put(state, :session, session)}
  end

  defthen ~r/^the page should load within (?<ms>\d+)ms$/, %{ms: ms}, state do
    start = System.monotonic_time(:millisecond)
    assert_has(state.session, css("[data-testid='page-loaded']"))
    elapsed = System.monotonic_time(:millisecond) - start
    assert elapsed < String.to_integer(ms)
  end

  defthen ~r/^I should see the "(?<text>[^"]*)" header$/, %{text: text}, state do
    assert_has(state.session, css("h1", text: text))
  end
end
```

### 5.4 BDD Framework Integration

| Framework | Language | Integration |
|-----------|----------|-------------|
| Cucumber | Elixir (Cabbage) | Native feature parsing |
| SpecFlow | .NET (F#/C#) | CEPAF integration |
| JBehave | Java | External service tests |
| Concordion | HTML | Documentation tests |

---

## Integration Matrix

### Test Type Distribution by Domain

| Domain | L1:TDG | L2:FMEA | L3:Formal | L4:Graph | L5:BDD |
|--------|--------|---------|-----------|----------|--------|
| Prajna | ✓ | ✓ | ✓ | ✓ | ✓ |
| Guardian | ✓ | ✓ | ✓ | ✓ | ✓ |
| Sentinel | ✓ | ✓ | ✓ | ✓ | ✓ |
| Alarms | ✓ | ✓ | ○ | ✓ | ✓ |
| Devices | ✓ | ✓ | ○ | ✓ | ✓ |
| Access | ✓ | ✓ | ✓ | ✓ | ✓ |
| Video | ✓ | ✓ | ○ | ✓ | ✓ |
| Compliance | ✓ | ✓ | ✓ | ✓ | ✓ |
| Cluster | ✓ | ✓ | ✓ | ✓ | ✓ |
| Observability | ✓ | ✓ | ○ | ✓ | ✓ |

**Legend**: ✓ = Required, ○ = Optional

---

## Running the Test Suites

### Level 1: TDG
```bash
# Run all TDG tests with coverage
SKIP_ZENOH_NIF=0 mix test --cover

# Run property tests only
SKIP_ZENOH_NIF=0 mix test --only property

# Generate coverage report
SKIP_ZENOH_NIF=0 mix coveralls.html
```

### Level 2: FMEA
```bash
# Run FMEA tests
SKIP_ZENOH_NIF=0 mix test --only fmea

# Generate FMEA report
mix fmea.report
```

### Level 3: Formal
```bash
# Run Agda proofs
agda --safe docs/formal_specs/*.agda

# Run Quint models
quint run docs/formal_specs/*.qnt

# Run Mathematica verification
wolframscript -file docs/formal_specs/*.m
```

### Level 4: Graph
```bash
# Generate coverage analysis
mix coveralls.detail

# Run graph analysis
mix graph.analyze
```

### Level 5: BDD
```bash
# Run all BDD features
SKIP_ZENOH_NIF=0 mix test.features

# Run Puppeteer tests
npm run test:puppeteer

# Generate BDD report
mix bdd.report
```

### Full Suite
```bash
# Run complete 5-level test suite
./scripts/testing/run_five_level_tests.sh
```

---

## Telemetry & Reporting

### Test Execution Events
```elixir
:telemetry.attach_many("test-metrics", [
  [:test, :level1, :complete],
  [:test, :level2, :complete],
  [:test, :level3, :complete],
  [:test, :level4, :complete],
  [:test, :level5, :complete]
], &TestReporter.handle_event/4, nil)
```

### Coverage Dashboard
- Real-time test execution status
- Per-level coverage metrics
- Failure trend analysis
- RPN heatmap for FMEA

---

## STAMP Constraints Summary

| ID | Level | Constraint | Severity |
|----|-------|------------|----------|
| SC-COV-001 | All | Static coverage 100% | CRITICAL |
| SC-COV-002 | All | Runtime coverage 100% | CRITICAL |
| SC-COV-003 | L3 | Mathematical proofs for core | HIGH |
| SC-COV-004 | L5 | BDD specs for user journeys | HIGH |
| SC-COV-005 | L2 | FMEA for critical paths | HIGH |
| SC-COV-006 | L1 | TDG compliance mandatory | CRITICAL |

---

## AOR Rules Summary

| ID | Rule |
|----|------|
| AOR-COV-001 | All 5 levels MUST pass before release |
| AOR-COV-002 | New features require all 5 levels |
| AOR-COV-003 | Critical bugs require Level 2-5 regression |
| AOR-COV-004 | Formal proofs reviewed quarterly |
| AOR-COV-005 | BDD features for all user-facing changes |
