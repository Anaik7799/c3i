# STAMP/TDG/GDE Developer Guide

## Overview

This guide provides comprehensive instructions for developers working with the STAMP/TDG/GDE enhancement framework. It covers daily workflows, best practices, and integration patterns.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Daily Development Workflow](#daily-development-workflow)
3. [STAMP Safety Integration](#stamp-safety-integration)
4. [TDG Test-Driven Generation](#tdg-test-driven-generation)
5. [GDE Goal Management](#gde-goal-management)
6. [Integration Patterns](#integration-patterns)
7. [Troubleshooting](#troubleshooting)

## Getting Started

### Prerequisites

- Elixir 1.19+
- Phoenix LiveView knowledge
- Understanding of property-based testing
- Familiarity with safety analysis concepts

### Initial Setup

```bash
# Enable all features for development
mix feature.enable stamp_enabled
mix feature.enable tdg_enabled
mix feature.enable gde_enabled

# Run initial validation
mix health.check --stamp --tdg --gde
```

## Daily Development Workflow

### Morning Routine

```bash
# Check goal progress
mix gde.progress --my-goals

# Validate current STAMP compliance
mix stamp.validate --my-changes

# Check TDG coverage
mix tdg.coverage --watch
```

### Before Coding

```bash
# Ensure TDG compliance
mix tdg.validate --pre-generation

# Check safety constraints for your domain
mix stamp.stpa --domain your_domain --check
```

### During Development

#### 1. Test-First Development (TDG)

Always write tests before implementation:

```elixir
# Write property-based tests first
defmodule MyFeatureTest do
  use ExUnit.Case, async: true
  use PropCheck
  use ExUnitProperties

  # PropCheck test
  test "propcheck: feature handles all inputs" do
    PropCheck.property "property description" do
      forall input <- generator() do
        result = MyFeature.process(input)
        is_valid_result(result)
      end
    end
  end

  # ExUnitProperties test
  test "exunitproperties: consistent behavior" do
    ExUnitProperties.check all input <- valid_input(),
                               max_runs: 100 do
      result = MyFeature.process(input)
      assert valid_output?(result)
    end
  end
end
```

#### 2. Safety Analysis (STAMP)

Perform STPA analysis for critical features:

```bash
# Initialize STPA analysis
mix stamp.stpa --feature user_authentication --init

# Generate safety requirements
mix stamp.stpa --feature user_authentication --generate-requirements
```

#### 3. Goal Tracking (GDE)

Define and track development goals:

```bash
# Define a new goal
mix gde.define --name "reduce_response_time" \
               --target "< 50ms" \
               --deadline "2025-09-01"

# Track progress
mix gde.track --name "reduce_response_time" --value 65
```

### End of Day

```bash
# Validate all changes
mix tdg.validate --post-generation
mix stamp.validate --comprehensive

# Update goal progress
mix gde.track --my-goals

# Generate compliance report
mix compliance.report --today
```

## STAMP Safety Integration

### Writing Safety-Critical Code

1. **Identify Safety Constraints**

```elixir
defmodule PaymentProcessor do
  @safety_constraints [
    "SC1: No payment can exceed account balance",
    "SC2: All transactions must be logged",
    "SC3: Failed payments must trigger alerts"
  ]

  def process_payment(account, amount) do
    # Implementation with safety checks
  end
end
```

2. **Implement UCAs Mitigation**

```elixir
def authorize_user(user_id, required_role) do
  # UCA: Providing access when user lacks permission
  case get_user_permissions(user_id) do
    {:ok, permissions} when required_role in permissions ->
      {:ok, :authorized}
    _ ->
      # Log security event
      :telemetry.execute([:stamp, :violation, :detected], %{}, %{
        severity: :high,
        constraint: "SC-AUTH-001",
        user_id: user_id
      })
      {:error, :unauthorized}
  end
end
```

### CAST Investigation

When incidents occur:

```bash
# Start CAST investigation
mix stamp.cast --incident INC-12345

# Emergency investigation
mix stamp.cast --emergency --incident INC-99999
```

## TDG Test-Driven Generation

### Core Principles

1. **Tests First**: Always write tests before implementation
2. **Dual Strategy**: Use both PropCheck and ExUnitProperties
3. **Coverage**: Maintain 98%+ test coverage
4. **AI Code**: All AI-generated code must have tests

### Property-Based Testing Patterns

#### Pattern 1: Roundtrip Properties

```elixir
test "encode/decode roundtrip" do
  PropCheck.property "data survives encode/decode" do
    forall data <- my_data_generator() do
      data == data |> encode() |> decode()
    end
  end
end
```

#### Pattern 2: Invariant Properties

```elixir
test "list sorting preserves length" do
  ExUnitProperties.check all list <- list_of(integer()) do
    sorted = Enum.sort(list)
    assert length(sorted) == length(list)
  end
end
```

#### Pattern 3: Model-Based Testing

```elixir
test "stateful property" do
  PropCheck.property "state machine behaves correctly" do
    forall commands <- commands(__MODULE__) do
      {history, state, result} = run_commands(__MODULE__, commands)
      result == :ok
    end
  end
end
```

### Git Hooks for TDG

Install pre-commit hooks:

```bash
mix tdg.enforce --git-hooks install
```

The hook will prevent commits of untested code.

## GDE Goal Management

### Goal Definition Best Practices

1. **SMART Goals**: Specific, Measurable, Achievable, Relevant, Time-bound

```bash
mix gde.define --name "api_performance" \
               --target "95th percentile < 100ms" \
               --baseline 250 \
               --deadline "2025-10-01" \
               --priority high
```

2. **Hierarchical Goals**

```bash
# Parent goal
mix gde.define --name "system_performance" --target "overall improvement"

# Child goals
mix gde.define --name "api_latency" --parent "system_performance"
mix gde.define --name "db_queries" --parent "system_performance"
```

### Automated Interventions

Configure interventions for at-risk goals:

```elixir
defmodule MyInterventions do
  def handle_goal_at_risk(%{name: "api_performance", progress: progress})
      when progress < 50 do
    [
      {:scale_resources, %{instances: 2}},
      {:enable_caching, %{ttl: 300}},
      {:alert_team, %{urgency: :high}}
    ]
  end
end
```

### Progress Tracking

Integrate with your metrics:

```elixir
def track_api_performance do
  current_latency = get_current_latency()

  :telemetry.execute(
    [:gde, :progress, :tracked],
    %{current_value: current_latency},
    %{goal: "api_performance", unit: "ms"}
  )
end
```

## Integration Patterns

### Unified Validation

```bash
# Run all three systems together
mix stamp.tdg.gde validate

# Generate unified report
mix compliance.report --format pdf
```

### LiveView Integration

```elixir
defmodule MyLive do
  use MyAppWeb, :live_view
  use Indrajaal.FeatureFlags.LiveView

  def mount(_params, _session, socket) do
    socket = assign(socket, :metrics, get_dashboard_metrics())
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <%= if feature_enabled?(@socket, :stamp_enabled) do %>
      <.stamp_compliance_widget compliance={@metrics.stamp} />
    <% end %>

    <%= if feature_enabled?(@socket, :gde_enabled) do %>
      <.goal_progress_widget goals={@metrics.goals} />
    <% end %>
    """
  end
end
```

### Testing Integration

```elixir
defmodule IntegratedTest do
  test "STAMP informs TDG test generation" do
    # Run STPA analysis
    stpa_result = perform_stpa_analysis(:payment)

    # Generate tests from safety constraints
    tests = generate_tests_from_stpa(stpa_result)

    # Validate all UCAs have corresponding tests
    assert all_ucas_tested?(stpa_result, tests)
  end
end
```

## Advanced Configuration

### Feature Flag Strategies

```elixir
# Percentage rollout
FeatureFlags.set_rollout_percentage(25)

# Team-based rollout
FeatureFlags.add_team_to_rollout("backend_team")

# User-based rollout
FeatureFlags.enabled_for?(:stamp_enabled, %{user_id: user.id})
```

### Custom Telemetry

```elixir
def emit_custom_metric do
  :telemetry.execute(
    [:my_app, :custom, :metric],
    %{value: 42},
    %{category: :performance}
  )
end
```

## Performance Considerations

### Monitoring Impact

```bash
# Benchmark performance impact
mix benchmark

# Compare with baseline
mix benchmark.compare --threshold 5.0
```

### Optimization Tips

1. **Lazy Loading**: Load safety analysis data only when needed
2. **Caching**: Cache STPA results for stable domains
3. **Async Processing**: Use background jobs for heavy analysis
4. **Sampling**: Use statistical sampling for large datasets

## Best Practices Summary

### DO
- ✅ Write tests before implementation (TDG)
- ✅ Perform STPA for critical features (STAMP)
- ✅ Set measurable goals (GDE)
- ✅ Use feature flags for gradual rollout
- ✅ Monitor performance impact
- ✅ Document safety constraints

### DON'T
- ❌ Generate code without tests
- ❌ Skip safety analysis for security features
- ❌ Set vague or unmeasurable goals
- ❌ Enable all features at once in production
- ❌ Ignore performance regressions
- ❌ Bypass safety constraints

## Next Steps

1. Set up your development environment
2. Choose a small feature to practice with
3. Follow the daily workflow
4. Gradually adopt more advanced patterns
5. Share learnings with your team

For more information, see the [Mix Tasks Reference](mix_tasks_reference.md) and [Troubleshooting Guide](troubleshooting_guide.md).