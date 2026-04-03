# Module 2: TDG Quality Framework

**Duration:** 4 hours
**Prerequisites:** Module 1 completion, Test-driven development familiarity
**Learning Objectives:** Master Test-Driven Generation for AI-assisted development

---

## 📚 Learning Objectives

By the end of this module, you will be able to:

1. **Apply TDG Methodology**: Write tests before generating any AI-assisted code
2. **Implement Dual Testing**: Use both PropCheck and ExUnitProperties effectively
3. **Ensure AI Compliance**: Validate that all AI-generated code has comprehensive tests
4. **Integrate TDG Workflows**: Seamlessly incorporate TDG into daily development
5. **Measure Quality Impact**: Track and improve code quality through TDG metrics

## 🎯 Module Overview

### Session 1: TDG Fundamentals (60 minutes)

#### The TDG Revolution

**Traditional AI Development Problems:**
```
AI generates code → Developer uses it → Tests written later (maybe)
❌ Untested AI code in production
❌ Hidden bugs and edge cases
❌ Low confidence in AI-generated solutions
❌ Technical debt accumulation
```

**TDG Solution:**
```
Requirements → Tests written first → AI generates code → Tests validate
✅ 100% tested AI code
✅ Comprehensive edge case coverage
✅ High confidence in solutions
✅ Maintainable, quality codebase
```

#### Core TDG Principles

**1. Tests-First Mandate**
```
NEVER generate code without existing tests
Tests define the contract that AI must fulfill
AI generation becomes implementation of test specifications
```

**2. Comprehensive Coverage**
```
Unit tests: Individual function behavior
Integration tests: Component interactions
Property tests: Mathematical invariants
Edge case tests: Boundary conditions
```

**3. Dual Testing Strategy**
```elixir
# Use BOTH testing frameworks for maximum coverage
use PropCheck          # Advanced property testing with shrinking
use ExUnitProperties   # StreamData-based property testing

# PropCheck: Complex property validation
property "user emails are normalized" do
  forall email <- email_generator() do
    {:ok, user} = create_user(%{email: email})
    user.email == String.downcase(String.trim(email))
  end
end

# ExUnitProperties: Stream-based testing
property "users can be retrieved by email" do
  check all email <- valid_email() do
    user = insert(:user, email: email)
    found_user = get_user_by_email(email)
    assert found_user.id == user.id
  end
end
```

#### TDG Workflow Steps

**Step 1: Requirement Analysis**
```
1. Understand what needs to be built
2. Identify key behaviors and constraints
3. Define success criteria
4. Plan test scenarios
```

**Step 2: Test Specification**
```elixir
# Write comprehensive tests FIRST
defmodule Indrajaal.Payments.ProcessorTest do
  use Indrajaal.DataCase
  use PropCheck
  use ExUnitProperties

  describe "process_payment/2" do
    test "succeeds with valid payment data" do
      payment_data = %{
        amount: 1000,
        currency: "USD",
        payment_method: "card",
        customer_id: "cust_123"
      }

      assert {:ok, transaction} = Processor.process_payment(payment_data)
      assert transaction.status == :completed
      assert transaction.amount == 1000
    end

    test "fails with insufficient funds" do
      payment_data = %{
        amount: 10000,
        currency: "USD",
        payment_method: "card",
        customer_id: "cust_poor"
      }

      assert {:error, :insufficient_funds} = Processor.process_payment(payment_data)
    end
  end
end
```

**Step 3: AI Code Generation**
```
Prompt AI with test context:
"Generate Indrajaal.Payments.Processor.process_payment/2 function
that passes these tests: [include test code]"
```

**Step 4: Validation & Iteration**
```bash
# Verify all tests pass
mix test test/payments/processor_test.exs

# Check TDG compliance
mix tdg.validate --post-generation

# Measure coverage
mix test --cover
```

#### 🎮 **Exercise 2.1: TDG Workflow Practice** (20 minutes)

**Scenario**: Create a user validation function

**Your Task**: Follow TDG methodology to define requirements and write tests for `validate_user_input/1`

**Requirements**:
- Accept user input map with email, password, name
- Validate email format (must contain @ and valid domain)
- Ensure password length (8+ characters, 1 number, 1 uppercase)
- Name must be present and 2+ characters

**Template**:
```elixir
defmodule Indrajaal.Users.ValidatorTest do
  use ExUnit.Case

  describe "validate_user_input/1" do
    # Write your tests here - NO IMPLEMENTATION YET!
  end
end
```

### Session 2: Property-Based Testing Mastery (75 minutes)

#### Understanding Property-Based Testing

**Traditional Example-Based Testing:**
```elixir
test "list reversal" do
  assert reverse([1, 2, 3]) == [3, 2, 1]
  assert reverse([]) == []
  assert reverse([42]) == [42]
  # Limited to specific examples
end
```

**Property-Based Testing:**
```elixir
property "reversing twice returns original" do
  forall list <- list(integer()) do
    list == list |> reverse() |> reverse()
  end
end
# Tests infinite examples with automatic generation
```

#### PropCheck vs ExUnitProperties

**PropCheck Features:**
```elixir
use PropCheck

# Advanced shrinking - finds minimal failing cases
property "complex user validation" do
  forall user <- user_generator() do
    case validate_user(user) do
      {:ok, _} -> is_valid_user_data(user)
      {:error, _} -> not is_valid_user_data(user)
    end
  end
end

# Custom generators with complex logic
def user_generator do
  let {name, email, age} <- {utf8(), email_gen(), choose(13, 120)} do
    %User{name: name, email: email, age: age}
  end
end
```

**ExUnitProperties Features:**
```elixir
use ExUnitProperties

# StreamData integration
property "user creation is consistent" do
  check all name <- string(:alphanumeric, min_length: 2),
            email <- email_generator(),
            max_runs: 1000 do
    {:ok, user} = create_user(%{name: name, email: email})
    assert user.name == name
    assert String.contains?(user.email, "@")
  end
end
```

#### Advanced Property Patterns

**1. Roundtrip Properties**
```elixir
property "JSON encoding/decoding roundtrip" do
  forall user <- user_generator() do
    user == user |> Jason.encode!() |> Jason.decode!() |> to_user_struct()
  end
end
```

**2. Invariant Properties**
```elixir
property "sorting preserves list length" do
  check all list <- list_of(integer()) do
    sorted = Enum.sort(list)
    assert length(sorted) == length(list)
  end
end
```

**3. Model-Based Properties**
```elixir
property "payment processing matches model" do
  forall commands <- commands(__MODULE__) do
    {history, state, result} = run_commands(__MODULE__, commands)
    (result == :ok) implies valid_final_state(state)
  end
end
```

#### 🎮 **Exercise 2.2: Property-Based Test Design** (25 minutes)

**Scenario**: Shopping cart functionality

**Your Task**: Write property-based tests for shopping cart operations

**Functions to Test**:
- `add_item(cart, item, quantity)`
- `remove_item(cart, item_id)`
- `calculate_total(cart)`
- `apply_discount(cart, discount_code)`

**Property Ideas**:
```elixir
# Example structure - complete these properties
property "adding then removing item returns original cart" do
  forall {cart, item, quantity} <- {cart_gen(), item_gen(), pos_integer()} do
    # Your property logic here
  end
end

property "cart total is sum of item totals" do
  # Your property here
end

property "discount never increases total" do
  # Your property here
end
```

### Session 3: TDG Integration Patterns (60 minutes)

#### Git Integration

**Pre-commit Hooks**
```bash
#!/bin/sh
# .git/hooks/pre-commit

echo "🧪 TDG Compliance Check..."

# Check for untested code
if mix tdg.validate --pre-commit; then
  echo "✅ TDG compliance verified"
else
  echo "❌ TDG compliance failed - commit blocked"
  echo "Run 'mix tdg.validate --help' for guidance"
  exit 1
fi
```

**TDG Validation Commands**
```bash
# Pre-generation validation
mix tdg.validate --pre-generation
# ✅ Validates tests exist before AI generation
# ✅ Checks test quality and coverage
# ✅ Ensures proper test structure

# Post-generation validation
mix tdg.validate --post-generation
# ✅ Confirms all tests pass
# ✅ Validates coverage targets met
# ✅ Checks no untested code introduced

# Comprehensive audit
mix tdg.audit --comprehensive
# ✅ Full codebase TDG compliance check
# ✅ Identifies areas needing improvement
# ✅ Generates compliance report
```

#### CI/CD Integration

**GitHub Actions Workflow**
```yaml
name: TDG Compliance Check

on: [push, pull_request]

jobs:
  tdg_validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: 1.18

      - name: TDG Pre-validation
        run: mix tdg.validate --ci

      - name: Run Tests
        run: mix test --cover

      - name: TDG Post-validation
        run: mix tdg.validate --coverage-check

      - name: Generate TDG Report
        run: mix tdg.report --format json

      - name: Upload Coverage
        uses: codecov/codecov-action@v1
```

#### Development Workflow Integration

**VS Code Integration**
```json
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "TDG: Validate Current File",
      "type": "shell",
      "command": "mix",
      "args": ["tdg.validate", "--file", "${file}"],
      "group": "test",
      "presentation": {
        "echo": true,
        "reveal": "always"
      }
    },
    {
      "label": "TDG: Generate Test Template",
      "type": "shell",
      "command": "mix",
      "args": ["tdg.template", "--file", "${file}"],
      "group": "test"
    }
  ]
}
```

**Daily Development Workflow**
```bash
# Morning routine
mix tdg.status --my-files
# Shows TDG compliance for your recent changes

# Before starting new feature
mix tdg.template --feature user_authentication
# Generates test template structure

# During development
mix tdg.watch
# Continuously validates TDG compliance

# Before commit
mix tdg.validate --comprehensive
# Final compliance check
```

#### 🎮 **Exercise 2.3: Workflow Integration** (20 minutes)

**Task**: Set up TDG workflow for a feature

**Scenario**: Implementing email notification system

**Steps**:
1. Generate test template: `mix tdg.template --feature email_notifications`
2. Write comprehensive tests for:
   - `send_notification(user, message)`
   - `queue_notification(user, message, send_at)`
   - `get_notification_status(notification_id)`
3. Validate pre-generation: `mix tdg.validate --pre-generation`
4. Plan AI prompts for implementation
5. Set up monitoring: `mix tdg.watch`

### Session 4: Advanced TDG Techniques (45 minutes)

#### AI Prompt Engineering for TDG

**Effective Prompts**
```
🎯 GOOD PROMPT:
"Generate the Indrajaal.Email.send_notification/2 function that passes
these existing tests: [paste test code]. The function should handle
email validation, template rendering, and delivery tracking."

❌ BAD PROMPT:
"Create an email function that sends notifications to users."
```

**Prompt Templates**
```
Template 1: Basic Implementation
"Generate [module.function] that passes these tests: [tests]
Requirements: [specific requirements]
Return format: [expected return format]"

Template 2: Complex Logic
"Implement [module.function] following TDD principles.
Tests to pass: [test code]
Edge cases covered: [list edge cases]
Error handling: [error scenarios]
Integration points: [external dependencies]"

Template 3: Performance Critical
"Generate optimized [module.function] implementation.
Performance tests: [performance test code]
Constraints: [memory/time constraints]
Existing tests: [functional test code]"
```

#### TDG Quality Metrics

**Coverage Metrics**
```elixir
defmodule Indrajaal.TDG.Metrics do
  def calculate_tdg_score(module) do
    %{
      test_coverage: get_test_coverage(module),
      property_coverage: get_property_test_coverage(module),
      edge_case_coverage: get_edge_case_coverage(module),
      ai_generation_ratio: get_ai_generated_ratio(module),
      tdg_compliance: calculate_compliance_score(module)
    }
  end

  def compliance_score(metrics) do
    weights = %{
      test_coverage: 0.3,
      property_coverage: 0.2,
      edge_case_coverage: 0.2,
      ai_generation_ratio: 0.15,
      tdg_compliance: 0.15
    }

    Enum.reduce(weights, 0, fn {metric, weight}, acc ->
      acc + (Map.get(metrics, metric, 0) * weight)
    end)
  end
end
```

**Monitoring Dashboard**
```elixir
defmodule IndrajaalWeb.TDGDashboardLive do
  use IndrajaalWeb, :live_view

  def mount(_params, _session, socket) do
    metrics = Indrajaal.TDG.Metrics.get_project_metrics()

    socket = assign(socket,
      overall_score: metrics.overall_tdg_score,
      module_scores: metrics.module_scores,
      trend_data: metrics.trend_data,
      violations: metrics.current_violations
    )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="tdg-dashboard">
      <.score_card score={@overall_score} />
      <.module_breakdown scores={@module_scores} />
      <.trend_chart data={@trend_data} />
      <.violations_list violations={@violations} />
    </div>
    """
  end
end
```

#### Advanced Testing Patterns

**Metamorphic Testing**
```elixir
property "search results maintain relationships" do
  forall {query1, query2} <- {search_query(), search_query()} do
    results1 = search(query1)
    results2 = search(query2)
    combined_results = search("#{query1} #{query2}")

    # Metamorphic relationship: combined search should include
    # results that match both individual searches
    intersection = results1 ++ results2
    assert Enum.all?(intersection, &(&1 in combined_results))
  end
end
```

**Contract Testing**
```elixir
defmodule Indrajaal.Payment.Contract do
  use ExUnit.Case
  use PropCheck

  @payment_contract %{
    preconditions: [
      "amount > 0",
      "currency in accepted_currencies",
      "payment_method is valid"
    ],
    postconditions: [
      "result is {:ok, transaction} or {:error, reason}",
      "if success, transaction.amount == input.amount",
      "if success, transaction.status in [:pending, :completed]"
    ]
  }

  property "payment processing follows contract" do
    forall payment_data <- valid_payment_data() do
      # Verify preconditions
      assert meets_preconditions?(payment_data, @payment_contract)

      # Execute
      result = Payments.process(payment_data)

      # Verify postconditions
      assert meets_postconditions?(result, @payment_contract)
    end
  end
end
```

## 🧪 Hands-On Practice

### Practice Exercise: Complete TDG Implementation (60 minutes)

**Scenario**: API Rate Limiting System

**Requirements**:
- Track API calls per user per time window
- Support multiple rate limit tiers (basic, premium, enterprise)
- Handle burst capacity and rate smoothing
- Provide real-time usage feedback

**Your Deliverable**: Complete TDG implementation including:

1. **Test Specification** (20 minutes)
```elixir
defmodule Indrajaal.RateLimit.LimiterTest do
  use ExUnit.Case
  use PropCheck
  use ExUnitProperties

  # Write comprehensive tests for:
  # - check_rate_limit(user_id, tier)
  # - record_api_call(user_id, timestamp)
  # - get_usage_stats(user_id)
  # - reset_user_limits(user_id)
end
```

2. **Property-Based Tests** (20 minutes)
```elixir
# Properties to implement:
# - Users never exceed their tier limits
# - Usage stats are always accurate
# - Time window calculations are correct
# - Burst capacity works as expected
```

3. **AI Generation Plan** (10 minutes)
- Write detailed prompts for AI implementation
- Define integration points and dependencies
- Plan validation and testing approach

4. **Implementation Validation** (10 minutes)
- Mock AI-generated code
- Run tests to verify approach
- Identify potential improvements

### Group Exercise: TDG Best Practices (30 minutes)

**Scenario Analysis**: Review real-world TDG implementations

**Teams of 3-4 people**:
1. **Team Red**: Analyze payment processing TDG
2. **Team Blue**: Review user authentication TDG
3. **Team Green**: Examine file upload TDG
4. **Team Yellow**: Study notification system TDG

**Deliverables per team**:
- TDG compliance score (1-10)
- Identified strengths and weaknesses
- Recommended improvements
- Test coverage analysis

## 📝 Knowledge Check

### Comprehension Questions

1. **Concept**: What makes TDG different from traditional test-driven development?

2. **Application**: When would you use PropCheck vs ExUnitProperties in a TDG workflow?

3. **Analysis**: How does TDG reduce the risks of AI-generated code?

4. **Synthesis**: Design a TDG workflow for a team transitioning from manual coding to AI assistance.

### Practical Challenges

1. **Code Review**: Identify TDG violations in this code snippet:
```elixir
# AI generated this function:
def calculate_discount(amount, code) do
  case code do
    "SAVE10" -> amount * 0.9
    "SAVE20" -> amount * 0.8
    _ -> amount
  end
end

# Tests were written after:
test "discount calculation" do
  assert calculate_discount(100, "SAVE10") == 90
end
```

2. **Property Design**: Write properties for a cache implementation with TTL support.

3. **Integration**: Design a CI/CD pipeline that enforces TDG compliance.

## 🎯 Key Takeaways

1. **Tests First Always**: Never generate code without existing tests
2. **Dual Testing Strategy**: Use both PropCheck and ExUnitProperties
3. **Comprehensive Coverage**: Include unit, integration, and property tests
4. **Workflow Integration**: Make TDG seamless in daily development
5. **Quality Metrics**: Track and improve TDG compliance over time
6. **AI Prompt Engineering**: Write clear, test-driven prompts
7. **Team Adoption**: Build TDG culture through tools and training

## 📚 Additional Resources

### Required Reading
- [Property-Based Testing Guide](https://propcheck-guide.pdf)
- [TDG Methodology Paper](https://tdg-methodology.pdf)

### Tools and Libraries
- [PropCheck](https://hex.pm/packages/propcheck)
- [ExUnitProperties](https://hex.pm/packages/stream_data)
- [TDG Tools](https://github.com/indrajaal/tdg-tools)

### Practice Resources
- [TDG Kata Collection](https://tdg-katas.dev)
- [Property Testing Examples](https://property-examples.com)

### Next Steps
- **Module 3**: [GDE Goal Systems](gde_systems.md)
- **Workshop**: [TDG Implementation Workshop](../workshops/tdg_implementation_workshop.md)
- **Assessment**: [Professional Competency Test](../assessments/professional_test.md)

---

**Questions or Need Help?**
- Office Hours: Wednesday 10-11am
- Slack: #tdg-support
- Email: tdg-support@indrajaal.dev

**Ready to set and achieve ambitious goals?** Continue to [Module 3: GDE Goal Systems](gde_systems.md)