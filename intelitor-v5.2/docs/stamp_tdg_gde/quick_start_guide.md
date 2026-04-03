# STAMP/TDG/GDE Quick Start Guide

**Get up and running with STAMP/TDG/GDE in 30 minutes!**

---

## 🚀 Quick Start for Developers

### 1. Essential Concepts (5 minutes)

**STAMP (Safety)**
- **What**: Systems-Theoretic Accident Model and Processes
- **Why**: Prevent system-level failures before they happen
- **When**: Before implementing any critical feature

**TDG (Quality)**
- **What**: Test-Driven Generation
- **Why**: 100% tested AI-generated code
- **When**: Always write tests BEFORE implementation

**GDE (Goals)**
- **What**: Goal-Directed Execution
- **Why**: Track and achieve measurable objectives
- **When**: For any feature with success metrics

### 2. Your First STPA Analysis (10 minutes)

```elixir
# Before implementing a new authentication feature:

# 1. Define safety constraints
mix stamp.stpa --feature authentication --init

# 2. Identify what could go wrong
# The tool will guide you through:
# - Control structure modeling
# - Unsafe control actions
# - Loss scenarios

# 3. Generate safety requirements
mix stamp.stpa --feature authentication --generate-requirements
```

### 3. Your First TDG Implementation (10 minutes)

```elixir
# Step 1: Write tests FIRST
defmodule MyApp.FeatureTest do
  use ExUnit.Case

  test "user can perform action" do
    # Write your test expectations
    assert {:ok, result} = MyApp.perform_action(params)
    assert result.status == :success
  end
end

# Step 2: Run TDG validation
mix tdg.validate --pre-generation

# Step 3: Generate implementation (with AI assistance)
# Use your AI tool with the test as context

# Step 4: Verify compliance
mix tdg.validate --post-generation
```

### 4. Your First GDE Goal (5 minutes)

```elixir
# Define a measurable goal
mix gde.define \
  --name "reduce_login_time" \
  --target "< 2 seconds" \
  --deadline "2025-09-01"

# Track progress
mix gde.track --name "reduce_login_time" --value 2.5

# View dashboard
mix gde.dashboard
```

## 🎯 Common Workflows

### Starting a New Feature

```bash
# 1. Safety first
mix stamp.stpa --feature my_feature

# 2. Write tests
mix tdg.init --feature my_feature

# 3. Set goals
mix gde.define --feature my_feature

# 4. Implement with confidence!
```

### Investigating an Issue

```bash
# Use CAST for systematic investigation
mix stamp.cast --incident INC-12345

# Follow the guided investigation:
# 1. Timeline reconstruction
# 2. Control structure analysis
# 3. Systemic factors
# 4. Recommendations
```

### Daily Workflow

```bash
# Morning: Check your goals
mix gde.status --my-goals

# Before coding: Ensure TDG compliance
mix tdg.check --my-changes

# After coding: Validate safety
mix stamp.validate --my-changes

# End of day: Update progress
mix gde.update --my-goals
```

## 📊 Monitoring Your Impact

### Personal Dashboard

```bash
# See your STAMP/TDG/GDE metrics
mix my.dashboard

# Shows:
# - Your STPA analyses count
# - Your TDG compliance rate
# - Your goal achievement rate
```

### Team Dashboard

Access the web dashboard at: http://localhost:4000/monitoring/stamp-tdg-gde

## 🆘 Getting Help

### Built-in Help

```bash
mix stamp.help
mix tdg.help
mix gde.help
```

### Interactive Tutorials

```bash
mix learn.stamp  # 30-minute interactive tutorial
mix learn.tdg    # 20-minute hands-on exercise
mix learn.gde    # 15-minute goal setting workshop
```

### Office Hours

- **STAMP Expert**: Tuesdays 2-3pm
- **TDG Champion**: Wednesdays 10-11am
- **GDE Coach**: Thursdays 3-4pm

### Slack Channels

- `#stamp-help` - Safety analysis questions
- `#tdg-support` - Test-driven generation help
- `#gde-goals` - Goal tracking and tips

## 🏃 Quick Wins

Try these to see immediate value:

1. **Safety Check**: Run `mix stamp.check` on your current branch
2. **Coverage Boost**: Run `mix tdg.suggest-tests` for test ideas
3. **Goal Setting**: Define one small goal for today with `mix gde.quick-goal`

## 📈 Success Metrics

After 1 week, you should see:
- ✅ Zero safety violations in your code
- ✅ 100% test coverage for new features
- ✅ Clear progress on your goals

After 1 month, expect:
- 📈 50% fewer bugs in your code
- 📈 30% faster feature delivery
- 📈 Higher confidence in changes

## 🎉 Celebrate Success

When you:
- Complete your first STPA: Badge earned! 🏆
- Achieve 100% TDG compliance: Certificate unlocked! 📜
- Meet your first goal: Recognition in team meeting! 🌟

---

**Remember**: Small steps lead to big improvements. Start with one feature, one test, one goal. You've got this! 💪

**Need more help?** Visit the [full documentation](../index.md) or ask in `#stamp-tdg-gde-help`