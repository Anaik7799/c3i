# Mathematical Verification Instructions for System Analysis & Test Case Generation

**Document Control**

| Field | Value |
|-------|-------|
| Document ID | MATH-VER-001 |
| Version | 1.0.0 |
| Status | ACTIVE |
| Created | 2025-12-27 |
| Author | Cybernetic Architect |
| Classification | Verification Standard |

---

## 1. Purpose

This document provides key instructions for applying mathematical verification techniques to:
- System behavior analysis
- Use case scenario validation
- Test case generation
- Formal correctness proofs

---

## 2. Mathematical Verification Framework Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MATHEMATICAL VERIFICATION LAYERS                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Layer 1: SPECIFICATION (What the system SHOULD do)                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • Mathematica: Formal notation, type definitions, invariants        │   │
│  │ • First-Order Logic: ∀, ∃, ⟹, ⟺                                     │   │
│  │ • Temporal Logic: □ (always), ◇ (eventually), ○ (next)              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Layer 2: MODEL CHECKING (Does the design SATISFY the spec?)               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • Quint: State machine models, invariant checking                   │   │
│  │ • Alloy: Relational logic, counter-example search                   │   │
│  │ • TLA+: Temporal property verification                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Layer 3: PROOF (Is the implementation CORRECT?)                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • Agda: Dependent types, constructive proofs                        │   │
│  │ • Coq: Formal verification, certified code                          │   │
│  │ • Isabelle/HOL: Higher-order logic proofs                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Layer 4: RUNTIME VERIFICATION (Does the execution CONFORM?)               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • SHACL: Attribute shape validation                                 │   │
│  │ • GraphBLAS: Matrix-based graph verification                        │   │
│  │ • Property Testing: PropCheck/StreamData                            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Key Instructions for System Analysis

### 3.1 Identify System Invariants

**Instruction:** Express properties that MUST hold at ALL times.

```mathematica
(* Invariant Template *)
Invariant[name_String, condition_] :=
  Assert[□(condition), "Invariant " <> name <> " violated"]

(* Examples *)
inv_no_negative_balance := ∀ account ∈ Accounts: balance(account) ≥ 0
inv_unique_ids := ∀ a, b ∈ Entities: a ≠ b ⟹ id(a) ≠ id(b)
inv_quorum := |active_nodes| ≥ ⌊n/2⌋ + 1
```

**Test Case Generation:**
```elixir
# For each invariant, generate:
# 1. Positive test: Verify invariant holds under normal conditions
# 2. Boundary test: Verify invariant at edge cases
# 3. Violation test: Verify system rejects states that violate invariant

describe "inv_no_negative_balance" do
  test "balance remains non-negative after withdrawal" do
    account = create_account(balance: 100)
    assert {:ok, _} = withdraw(account, 50)
    assert get_balance(account) >= 0
  end

  test "rejects withdrawal exceeding balance" do
    account = create_account(balance: 100)
    assert {:error, :insufficient_funds} = withdraw(account, 150)
  end
end
```

### 3.2 Define State Transitions

**Instruction:** Model system as state machine with explicit transitions.

```quint
// State Machine Template
module SystemStateMachine {
  type State = Idle | Processing | Completed | Failed
  type Event = Start | Process | Complete | Fail | Reset

  var current_state: State

  // Transition function
  action transition(event: Event): bool = {
    match (current_state, event) {
      (Idle, Start) => current_state' = Processing
      (Processing, Complete) => current_state' = Completed
      (Processing, Fail) => current_state' = Failed
      (Failed, Reset) => current_state' = Idle
      (Completed, Reset) => current_state' = Idle
      _ => false  // Invalid transition
    }
  }

  // Safety: Never skip Processing
  val inv_no_skip = not(current_state == Idle and current_state' == Completed)

  // Liveness: Eventually complete or fail
  temporal prop_eventually_terminal =
    □(current_state == Processing ⟹ ◇(current_state == Completed or current_state == Failed))
}
```

**Test Case Generation:**
```elixir
# Generate tests for each valid transition
describe "state transitions" do
  for {from, event, to} <- valid_transitions() do
    test "#{from} + #{event} -> #{to}" do
      state = set_state(from)
      assert {:ok, new_state} = apply_event(state, event)
      assert new_state == to
    end
  end

  # Generate tests for invalid transitions
  for {from, event} <- invalid_transitions() do
    test "#{from} + #{event} -> error" do
      state = set_state(from)
      assert {:error, :invalid_transition} = apply_event(state, event)
    end
  end
end
```

### 3.3 Express Pre/Post Conditions

**Instruction:** Define contracts for every operation.

```mathematica
(* Operation Contract Template *)
Operation[name_, precondition_, postcondition_, body_] := Module[{result},
  Assert[precondition, "Precondition failed for " <> name];
  result = body;
  Assert[postcondition[result], "Postcondition failed for " <> name];
  result
]

(* Example: Transfer operation *)
Transfer[from_, to_, amount_] := Operation[
  "Transfer",
  (* Precondition *)
  balance[from] >= amount ∧ amount > 0 ∧ from ≠ to,
  (* Postcondition *)
  Function[{result},
    balance'[from] == balance[from] - amount ∧
    balance'[to] == balance[to] + amount ∧
    total_money' == total_money  (* Conservation *)
  ],
  (* Body *)
  {
    balance[from] -= amount,
    balance[to] += amount
  }
]
```

**Test Case Generation:**
```elixir
describe "transfer operation" do
  # Test precondition satisfaction
  test "succeeds when preconditions met" do
    from = create_account(balance: 100)
    to = create_account(balance: 50)

    assert {:ok, _} = transfer(from, to, 30)
  end

  # Test precondition violations
  test "fails when insufficient balance" do
    from = create_account(balance: 10)
    to = create_account(balance: 50)

    assert {:error, :precondition_failed} = transfer(from, to, 30)
  end

  # Test postcondition (conservation law)
  test "total money is conserved" do
    from = create_account(balance: 100)
    to = create_account(balance: 50)
    total_before = get_balance(from) + get_balance(to)

    {:ok, _} = transfer(from, to, 30)

    total_after = get_balance(from) + get_balance(to)
    assert total_before == total_after
  end
end
```

---

## 4. Key Instructions for Use Case Scenario Analysis

### 4.1 Scenario Decomposition

**Instruction:** Break scenarios into atomic steps with mathematical properties.

```mathematica
(* Scenario Structure *)
Scenario[name_String, steps_List, properties_List] := Module[{},
  (* Steps are ordered sequence of actions *)
  steps = {
    Step[1, "Initialize", precond, action, postcond],
    Step[2, "Process", precond, action, postcond],
    Step[3, "Finalize", precond, action, postcond]
  };

  (* Properties span multiple steps *)
  properties = {
    Safety["No data loss", □(data_count' >= data_count)],
    Liveness["Eventually completes", ◇(status == :completed)],
    Fairness["All requests processed", □◇(queue_empty)]
  }
]
```

**Test Matrix Generation:**
```elixir
# Generate test matrix from scenario
def generate_scenario_tests(scenario) do
  for step <- scenario.steps do
    [
      # Happy path
      {:test, "#{step.name} succeeds", step.precond, step.action, step.postcond},
      # Failure injection
      {:test, "#{step.name} handles failure", step.precond, inject_failure(step.action), step.error_postcond},
      # Timeout
      {:test, "#{step.name} handles timeout", step.precond, add_delay(step.action), step.timeout_postcond}
    ]
  end
  |> List.flatten()
end
```

### 4.2 Property-Based Scenario Generation

**Instruction:** Use generators to explore scenario space.

```elixir
# Define generators for scenario components
defmodule ScenarioGenerators do
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  # Generate valid user actions
  def user_action do
    PC.oneof([
      {:login, PC.binary()},
      {:view, PC.binary()},
      {:edit, PC.binary(), PC.binary()},
      {:delete, PC.binary()},
      {:logout}
    ])
  end

  # Generate action sequences
  def action_sequence do
    PC.list(user_action())
  end

  # Generate scenarios with constraints
  def valid_scenario do
    PC.such_that(
      action_sequence(),
      fn actions ->
        starts_with_login?(actions) and
        ends_with_logout?(actions) and
        no_action_after_logout?(actions)
      end
    )
  end
end

# Property-based scenario test
property "all valid scenarios maintain session invariant" do
  forall scenario <- valid_scenario() do
    {:ok, final_state} = execute_scenario(scenario)
    session_invariant_holds?(final_state)
  end
end
```

### 4.3 Equivalence Class Partitioning

**Instruction:** Identify input classes with equivalent behavior.

```mathematica
(* Equivalence Class Definition *)
EquivalenceClass[name_String, predicate_, representative_] := {
  name -> name,
  predicate -> predicate,
  representative -> representative,
  boundary_values -> FindBoundaries[predicate]
}

(* Example: Age input classes *)
AgeClasses = {
  EquivalenceClass["Invalid Negative", age < 0, -1],
  EquivalenceClass["Minor", 0 <= age < 18, 10],
  EquivalenceClass["Adult", 18 <= age < 65, 30],
  EquivalenceClass["Senior", age >= 65, 70],
  EquivalenceClass["Invalid Too Large", age > 150, 200]
}

(* Boundary values *)
BoundaryValues[AgeClasses] = {-1, 0, 17, 18, 64, 65, 150, 151}
```

**Test Case Generation:**
```elixir
describe "age validation" do
  # Representative from each class
  @valid_minor 10
  @valid_adult 30
  @valid_senior 70
  @invalid_negative -1
  @invalid_large 200

  # Boundary values
  @boundaries [-1, 0, 17, 18, 64, 65, 150, 151]

  test "accepts valid minor age" do
    assert {:ok, :minor} = classify_age(@valid_minor)
  end

  test "accepts valid adult age" do
    assert {:ok, :adult} = classify_age(@valid_adult)
  end

  # Boundary tests
  for boundary <- @boundaries do
    test "handles boundary value #{boundary}" do
      result = classify_age(unquote(boundary))
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
```

---

## 5. Key Instructions for Test Case Creation

### 5.1 Derive Tests from Invariants

**Instruction:** Each invariant generates multiple test cases.

```mathematica
(* Invariant to Test Case Mapping *)
InvariantTestCases[inv_] := {
  (* 1. Establishment: Invariant holds initially *)
  TestCase["establishment",
    Setup -> Initialize[],
    Assert -> inv
  ],

  (* 2. Preservation: Invariant maintained after valid operations *)
  TestCase["preservation",
    Setup -> Initialize[] >> ValidOperation[],
    Assert -> inv
  ],

  (* 3. Violation Detection: System rejects invariant-violating operations *)
  TestCase["violation_detection",
    Setup -> Initialize[],
    Action -> ViolatingOperation[],
    Assert -> OperationRejected[] ∧ inv
  ],

  (* 4. Recovery: Invariant restored after recovery *)
  TestCase["recovery",
    Setup -> CorruptedState[],
    Action -> Recover[],
    Assert -> inv
  ]
}
```

### 5.2 Generate Tests from State Machine

**Instruction:** Cover all states, transitions, and paths.

```quint
// State coverage requirements
module TestCoverage {
  // All states must be reachable
  val state_coverage = forall s in States:
    exists path in Paths: reaches(path, s)

  // All transitions must be exercised
  val transition_coverage = forall t in Transitions:
    exists test in Tests: exercises(test, t)

  // All paths up to length N must be tested
  val path_coverage(n: int) = forall p in PathsOfLength(n):
    exists test in Tests: follows(test, p)
}
```

**Test Generation Algorithm:**
```elixir
defmodule StateMachineTestGenerator do
  @doc """
  Generates test cases from state machine definition.
  """
  def generate(state_machine) do
    states = state_machine.states
    transitions = state_machine.transitions

    # 1. State coverage tests
    state_tests = for state <- states do
      path = find_path_to_state(state_machine, state)
      {:test, "reach_#{state}", path}
    end

    # 2. Transition coverage tests
    transition_tests = for {from, event, to} <- transitions do
      {:test, "#{from}_#{event}_#{to}", [
        {:setup, reach_state(from)},
        {:action, trigger_event(event)},
        {:assert, in_state(to)}
      ]}
    end

    # 3. Invalid transition tests
    invalid_tests = for {from, event} <- invalid_transitions(state_machine) do
      {:test, "invalid_#{from}_#{event}", [
        {:setup, reach_state(from)},
        {:action, trigger_event(event)},
        {:assert, error_returned() and still_in_state(from)}
      ]}
    end

    state_tests ++ transition_tests ++ invalid_tests
  end
end
```

### 5.3 Apply Mutation Testing Principles

**Instruction:** Verify tests catch common defects.

```mathematica
(* Mutation Operators *)
MutationOperators = {
  (* Arithmetic *)
  ArithmeticMutation["+", "-"],
  ArithmeticMutation["*", "/"],

  (* Relational *)
  RelationalMutation["<", "<="],
  RelationalMutation[">", ">="],
  RelationalMutation["==", "!="],

  (* Logical *)
  LogicalMutation["∧", "∨"],
  LogicalMutation["¬", "Id"],

  (* Boundary *)
  BoundaryMutation["< n", "< n-1"],
  BoundaryMutation[">= n", "> n"]
}

(* Mutation Score *)
MutationScore = KilledMutants / TotalMutants
TargetScore = 0.95  (* 95% mutation score required *)
```

**Test Strengthening:**
```elixir
# Ensure tests kill common mutations
describe "balance check (mutation-resistant)" do
  # Original: balance >= 0

  # Kills: balance > 0
  test "allows zero balance" do
    assert valid_balance?(0) == true
  end

  # Kills: balance >= 1
  test "allows small positive balance" do
    assert valid_balance?(0.01) == true
  end

  # Kills: balance >= -1
  test "rejects negative balance" do
    assert valid_balance?(-0.01) == false
  end

  # Kills: balance <= 0
  test "allows positive balance" do
    assert valid_balance?(100) == true
  end
end
```

---

## 6. Mathematical Check Templates

### 6.1 Graph Verification Checks

```mathematica
(* Graph Property Checks *)
GraphChecks = {
  (* Connectivity *)
  Connectivity[G_] := ConnectedGraphQ[G],

  (* Acyclicity *)
  Acyclicity[G_] := AcyclicGraphQ[G],

  (* Reachability *)
  Reachability[G_, source_, target_] :=
    MemberQ[VertexOutComponent[G, source], target],

  (* No Forbidden Edges *)
  NoForbiddenEdges[G_, forbidden_] :=
    Intersection[EdgeList[G], forbidden] == {},

  (* Degree Constraints *)
  DegreeConstraint[G_, min_, max_] :=
    AllTrue[VertexDegree[G], min <= # <= max &]
}
```

### 6.2 Algebraic Verification Checks

```mathematica
(* Algebraic Properties *)
AlgebraicChecks = {
  (* Associativity *)
  Associativity[op_, a_, b_, c_] := op[op[a, b], c] == op[a, op[b, c]],

  (* Commutativity *)
  Commutativity[op_, a_, b_] := op[a, b] == op[b, a],

  (* Identity Element *)
  Identity[op_, e_, a_] := op[e, a] == a ∧ op[a, e] == a,

  (* Inverse *)
  Inverse[op_, e_, a_, a_inv_] := op[a, a_inv] == e ∧ op[a_inv, a] == e,

  (* Idempotency *)
  Idempotency[op_, a_] := op[a, a] == a
}
```

### 6.3 Temporal Property Checks

```mathematica
(* LTL Property Templates *)
TemporalChecks = {
  (* Safety: Bad thing never happens *)
  Safety[bad_condition_] := □(¬bad_condition),

  (* Liveness: Good thing eventually happens *)
  Liveness[good_condition_] := ◇(good_condition),

  (* Response: Request leads to response *)
  Response[request_, response_] := □(request ⟹ ◇response),

  (* Precedence: A before B *)
  Precedence[a_, b_] := ¬b Until a,

  (* Fairness: Infinitely often *)
  Fairness[condition_] := □◇(condition)
}
```

### 6.4 Numeric Verification Checks

```mathematica
(* Numeric Properties *)
NumericChecks = {
  (* Bounds *)
  InBounds[x_, min_, max_] := min <= x <= max,

  (* Precision *)
  WithinTolerance[actual_, expected_, epsilon_] :=
    Abs[actual - expected] <= epsilon,

  (* Monotonicity *)
  Monotonic[f_, x1_, x2_] := (x1 < x2) ⟹ (f[x1] <= f[x2]),

  (* Conservation *)
  Conserved[before_, after_] := Total[before] == Total[after],

  (* Convergence *)
  Converges[sequence_, limit_, epsilon_] :=
    ∃ n: ∀ m > n: Abs[sequence[m] - limit] < epsilon
}
```

---

## 7. Test Case Generation Checklist

### 7.1 For Each System Component

- [ ] **Invariants identified** and expressed formally
- [ ] **State machine defined** with all states and transitions
- [ ] **Pre/postconditions specified** for each operation
- [ ] **Error conditions enumerated** with expected behavior
- [ ] **Concurrency scenarios** analyzed for race conditions

### 7.2 For Each Test Case

- [ ] **Clear assertion** with mathematical basis
- [ ] **Sufficient setup** to reach test state
- [ ] **Isolation** from other tests
- [ ] **Reproducibility** guaranteed
- [ ] **Failure message** explains what went wrong

### 7.3 Coverage Verification

- [ ] **State coverage**: All states reachable
- [ ] **Transition coverage**: All transitions exercised
- [ ] **Boundary coverage**: All boundary values tested
- [ ] **Equivalence class coverage**: Representative from each class
- [ ] **Mutation score**: ≥ 95% mutants killed

---

## 8. Integration with Indrajaal Framework

### 8.1 STAMP Constraint Verification

```elixir
# Template for STAMP constraint test
defmodule STAMPConstraintTest do
  use ExUnit.Case

  describe "SC-XXX-NNN: Constraint Name" do
    test "constraint holds under normal operation" do
      # Setup
      state = initialize_system()

      # Action
      {:ok, new_state} = perform_operation(state)

      # Verify constraint
      assert constraint_holds?(new_state)
    end

    test "constraint violation is detected and prevented" do
      state = initialize_system()

      # Attempt violating action
      result = attempt_violation(state)

      # Verify rejection
      assert match?({:error, :constraint_violation}, result)
    end
  end
end
```

### 8.2 TDG (Test-Driven Generation) Integration

```elixir
# TDG workflow
# 1. Write failing test based on mathematical spec
# 2. Generate implementation
# 3. Verify test passes
# 4. Verify mathematical properties hold

defmodule TDGWorkflow do
  @spec verify_mathematical_property(atom(), map()) :: :ok | {:error, term()}
  def verify_mathematical_property(property, implementation) do
    case property do
      :invariant -> verify_invariant(implementation)
      :state_machine -> verify_state_machine(implementation)
      :pre_post -> verify_contracts(implementation)
      :temporal -> verify_temporal(implementation)
    end
  end
end
```

---

## 9. Quick Reference Commands

```bash
# Run mathematical verification
mix verify.invariants
mix verify.state_machine
mix verify.temporal

# Generate tests from spec
mix generate.tests --from-spec docs/formal_specs/

# Run property-based tests
mix test --only property

# Check mutation score
mix mutation.test --threshold 0.95

# Verify Quint models
quint verify docs/formal_specs/quint/*.qnt

# Run SHACL validation
mix validate.shapes
```

---

## 10. References

- [Graph Verification Framework](../architecture/GRAPH_VERIFICATION_FRAMEWORK.md)
- [Quint OpenRouter Integration](../formal_specs/quint/openrouter_integration.qnt)
- [Distributed Mathematical Spec](../architecture/DISTRIBUTED_MATHEMATICAL_SPEC.md)
- [OpenRouter Comprehensive Test Plan](./openrouter-comprehensive-test-plan.md)
- [GEMINI.md Section 88.0](../../GEMINI.md) - Graph Verification Framework

---

**Document Status**: ACTIVE
**Last Verified**: 2025-12-27
**Compliance**: SOPv5.11, STAMP, TDG
