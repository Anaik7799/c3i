# Foundation Assessment: STAMP/TDG/GDE

**Assessment Type:** Comprehensive knowledge and practical application test
**Duration:** 90 minutes
**Passing Score:** 80% (32/40 points)
**Prerequisites:** Completion of Modules 1-3
**Format:** Mixed question types with practical scenarios

---

## 📋 Assessment Overview

This assessment validates your understanding of STAMP safety principles, TDG quality methodology, and GDE goal management. You'll demonstrate both theoretical knowledge and practical application through realistic scenarios.

**Assessment Sections:**
1. **STAMP Fundamentals** (12 points - 30%)
2. **TDG Methodology** (12 points - 30%)
3. **GDE Implementation** (12 points - 30%)
4. **Integration Scenarios** (4 points - 10%)

**Question Types:**
- Multiple choice (knowledge verification)
- Short answer (concept explanation)
- Practical scenarios (application)
- Code analysis (technical implementation)

---

## 📚 Section 1: STAMP Fundamentals (12 points)

### Question 1.1: Core Concepts (2 points)
**Multiple Choice**: What is the primary difference between traditional safety approaches and STAMP?

A) STAMP focuses on hardware reliability while traditional approaches focus on software
B) STAMP analyzes component interactions while traditional approaches focus on component failures
C) STAMP is used for security while traditional approaches are used for safety
D) STAMP requires more documentation than traditional approaches

**Correct Answer:** B
**Explanation:** STAMP shifts focus from individual component failures to system-level interactions and control structures.

### Question 1.2: Control Structures (3 points)
**Short Answer**: Explain the difference between a controller and a controlled process in STAMP terminology. Provide an example of each from a web application context.

**Sample Answer:**
- **Controller**: A component that issues control actions and receives feedback. Example: Authentication service that grants/denies access
- **Controlled Process**: A component that receives and responds to control actions. Example: Database access layer that enforces permissions
- **Key Difference**: Controllers make decisions and issue commands; controlled processes execute those commands

**Scoring Rubric:**
- 3 points: Clear definitions with accurate examples
- 2 points: Mostly correct with minor gaps
- 1 point: Basic understanding shown
- 0 points: Incorrect or missing

### Question 1.3: Safety Constraints (2 points)
**Multiple Choice**: Which of the following is the best example of a safety constraint for a payment processing system?

A) The system should process payments quickly
B) The user interface should be intuitive
C) Only authenticated transactions with valid payment methods shall be processed
D) The system should support multiple currencies

**Correct Answer:** C
**Explanation:** Safety constraints specify what the system must/must not do to prevent hazards. Option C directly prevents financial harm.

### Question 1.4: UCA Identification (3 points)
**Practical Scenario**: Consider a file upload system with the control action "ValidateFile". Identify one UCA (Unsafe Control Action) for each of the four categories:

**Scenario Context**: Web application allows users to upload profile images. The ValidateFile control action checks file type, size, and content.

**Your Task**: Complete the UCA analysis:

1. **Not Providing**: ValidateFile not provided when _______________
2. **Providing**: ValidateFile provided when _______________
3. **Wrong Timing**: ValidateFile provided too late when _______________
4. **Stopped Too Soon**: ValidateFile stopped before _______________

**Sample Answers:**
1. **Not Providing**: ValidateFile not provided when user uploads executable file, allowing malware to enter system
2. **Providing**: ValidateFile provided when system is under high load, causing legitimate uploads to be incorrectly rejected
3. **Wrong Timing**: ValidateFile provided too late after file is already stored, allowing temporary exposure of malicious content
4. **Stopped Too Soon**: ValidateFile stopped before scanning for embedded malware, missing sophisticated threats

**Scoring:** 0.75 points per category, partial credit for reasonable answers

### Question 1.5: STPA Application (2 points)
**Multiple Choice**: When should STPA analysis be performed in the development lifecycle?

A) Only after a safety incident occurs
B) During the design phase, before implementation begins
C) After code is written but before deployment
D) Only when required by regulatory compliance

**Correct Answer:** B
**Explanation:** STPA is most effective as a proactive design tool, identifying safety requirements before implementation.

---

## 🧪 Section 2: TDG Methodology (12 points)

### Question 2.1: TDG Principles (2 points)
**Multiple Choice**: What is the fundamental principle of Test-Driven Generation (TDG)?

A) Generate code first, then write tests to validate it
B) Write comprehensive tests before any AI code generation
C) Use automated testing tools instead of manual testing
D) Generate tests automatically from AI-generated code

**Correct Answer:** B
**Explanation:** TDG requires tests to be written BEFORE any AI code generation to ensure quality and completeness.

### Question 2.2: Dual Testing Strategy (3 points)
**Code Analysis**: Examine this test code and identify issues with the TDG approach:

```elixir
# AI generated this function first:
def calculate_discount(amount, code) do
  case code do
    "SAVE10" -> amount * 0.9
    "SAVE20" -> amount * 0.8
    _ -> amount
  end
end

# Tests written after generation:
defmodule DiscountTest do
  use ExUnit.Case

  test "applies 10% discount" do
    assert calculate_discount(100, "SAVE10") == 90
  end

  test "applies 20% discount" do
    assert calculate_discount(100, "SAVE20") == 90
  end
end
```

**Identify three TDG violations in this code:**

**Sample Answer:**
1. **Code generated before tests**: The function was implemented before tests were written, violating TDG's test-first principle
2. **Incomplete test coverage**: Missing tests for invalid codes, edge cases (negative amounts, invalid inputs)
3. **Missing property-based tests**: No PropCheck or ExUnitProperties tests to validate mathematical properties
4. **Bug in test**: Second test expects 90 instead of 80, indicating tests weren't driving implementation

**Scoring:** 1 point per violation identified (3 points total)

### Question 2.3: Property-Based Testing (3 points)
**Practical Application**: Write a property-based test for a function `reverse_list/1` that reverses a list. Use either PropCheck or ExUnitProperties syntax.

**Your Task**: Complete this test:

```elixir
defmodule ListReverseTest do
  use ExUnit.Case
  use PropCheck  # or use ExUnitProperties

  property "reversing twice returns original list" do
    # Your property test here
  end
end
```

**Sample Answer:**
```elixir
property "reversing twice returns original list" do
  forall list <- list(integer()) do
    original = list
    reversed_twice = list |> reverse_list() |> reverse_list()
    original == reversed_twice
  end
end
```

**Scoring Rubric:**
- 3 points: Correct property test with appropriate generator
- 2 points: Mostly correct with minor syntax issues
- 1 point: Understands concept but implementation flawed
- 0 points: Incorrect or missing

### Question 2.4: TDG Compliance (2 points)
**Multiple Choice**: Which Git hook best enforces TDG compliance?

A) post-commit hook that runs tests after code is committed
B) pre-push hook that validates code quality before pushing
C) pre-commit hook that blocks commits of untested code
D) post-merge hook that runs tests after merging branches

**Correct Answer:** C
**Explanation:** Pre-commit hooks prevent untested code from entering the repository, enforcing TDG at the earliest point.

### Question 2.5: AI Integration (2 points)
**Short Answer**: How should AI prompts be structured to support TDG methodology? Provide an example prompt for implementing a user authentication function.

**Sample Answer:**
AI prompts should include existing tests and specific requirements. Structure should be:
1. Context: What needs to be implemented
2. Tests: Existing test code that must pass
3. Requirements: Specific behavior expectations
4. Constraints: Error handling, performance requirements

**Example Prompt:**
"Generate the `authenticate_user/2` function that passes these existing tests: [include test code]. The function must validate email/password pairs, return {:ok, user} for valid credentials or {:error, :invalid_credentials} for invalid ones, and handle rate limiting."

**Scoring:** 2 points for complete answer including example, 1 point for partial understanding

---

## 🎯 Section 3: GDE Implementation (12 points)

### Question 3.1: SMART Goals (3 points)
**Practical Application**: Convert this vague objective into a proper SMART goal:

**Vague Objective**: "Improve application performance"

**Your SMART Goal**: Complete the template:
- **Specific**: _________________
- **Measurable**: _________________
- **Achievable**: _________________
- **Relevant**: _________________
- **Time-bound**: _________________

**Sample Answer:**
- **Specific**: Reduce 95th percentile API response time for user endpoints
- **Measurable**: From current 250ms to target 100ms
- **Achievable**: Based on infrastructure improvements and code optimization
- **Relevant**: Improves user experience and reduces churn
- **Time-bound**: Achieve by September 1, 2025

**Scoring:** 0.6 points per SMART criterion correctly addressed

### Question 3.2: GDE Architecture (3 points)
**System Design**: Design the telemetry events needed to track this goal: "Maintain test coverage above 95%"

**Your Task**: Define the telemetry events, measurements, and metadata needed.

```elixir
def track_coverage_goal do
  :telemetry.execute(
    [_your_event_name_],
    %{_your_measurements_},
    %{_your_metadata_}
  )
end
```

**Sample Answer:**
```elixir
def track_coverage_goal(current_coverage) do
  :telemetry.execute(
    [:gde, :goal, :test_coverage],
    %{current_coverage: current_coverage, target_coverage: 95.0},
    %{
      goal_name: "test_coverage_95_percent",
      measurement_time: DateTime.utc_now(),
      project: "indrajaal",
      trend: calculate_trend(current_coverage)
    }
  )
end
```

**Scoring:** 1 point each for appropriate event name, measurements, and metadata

### Question 3.3: Automated Interventions (3 points)
**Code Implementation**: Implement an intervention function for this scenario:

**Scenario**: API response time goal is "< 100ms" but current measurement is 250ms.

```elixir
defmodule Indrajaal.GDE.ResponseTimeInterventions do
  def handle_goal_at_risk(goal, current_measurement) do
    # Your intervention logic here
  end
end
```

**Sample Answer:**
```elixir
def handle_goal_at_risk(%{target: 100} = goal, %{value: current_time})
    when current_time > 200 do
  [
    {:scale_infrastructure, %{factor: 2}},
    {:enable_caching, %{ttl: 300}},
    {:alert_team, %{priority: :high, message: "API response time degraded"}},
    {:create_incident, %{title: "Performance degradation detected"}}
  ]
end
```

**Scoring:** 3 points for comprehensive interventions, 2 points for basic interventions, 1 point for partial implementation

### Question 3.4: Progress Tracking (2 points)
**Multiple Choice**: How should goal progress be calculated when the goal is to reduce error rate from 2% to 0.5%?

A) (current_rate / target_rate) * 100
B) ((baseline_rate - current_rate) / (baseline_rate - target_rate)) * 100
C) (target_rate / current_rate) * 100
D) (current_rate - target_rate) / baseline_rate

**Correct Answer:** B
**Explanation:** Progress = (improvement made / total improvement needed) * 100. For reduction goals, this is (baseline - current) / (baseline - target).

### Question 3.5: Dashboard Integration (1 point)
**Multiple Choice**: What Phoenix feature is most appropriate for real-time GDE dashboard updates?

A) GenServer state management
B) PubSub for real-time updates
C) Ecto database polling
D) HTTP API endpoints

**Correct Answer:** B
**Explanation:** PubSub enables real-time dashboard updates when goal metrics change, providing immediate feedback.

---

## 🔗 Section 4: Integration Scenarios (4 points)

### Question 4.1: Unified Workflow (2 points)
**Scenario Integration**: You're implementing a new payment processing feature. Describe how STAMP, TDG, and GDE work together in your development workflow.

**Your Task**: Outline the workflow in 4-6 steps showing how all three methodologies integrate.

**Sample Answer:**
1. **STAMP Analysis**: Perform STPA to identify payment safety constraints (e.g., "fraudulent transactions must not be processed")
2. **Safety Requirements**: Convert STPA findings into testable safety requirements
3. **TDG Test Creation**: Write comprehensive tests including safety constraint validation
4. **AI Implementation**: Generate payment processing code that passes all tests
5. **GDE Goal Setting**: Define measurable goals (fraud detection rate, transaction success rate)
6. **Monitoring Integration**: Use telemetry to track both safety compliance and goal achievement

**Scoring:** 2 points for complete integration, 1 point for partial integration, 0 points for missing methodologies

### Question 4.2: Incident Response (2 points)
**Practical Scenario**: A production incident occurs where legitimate users are being blocked by your rate limiting system. How do the three methodologies guide your response?

**Your Response**: Describe how each methodology contributes to incident analysis and prevention.

**Sample Answer:**
- **STAMP (CAST Analysis)**: Investigate the control structure breakdown - why did the rate limiter make incorrect decisions? What process model flaws or feedback failures contributed?
- **TDG Validation**: Ensure any fixes are thoroughly tested before deployment, including edge cases that caused the original issue
- **GDE Monitoring**: Track system recovery goals (time to resolution, prevention of recurrence) and implement automated interventions to prevent similar incidents

**Scoring:** 2 points for addressing all three methodologies appropriately

---

## 📊 Assessment Scoring

### Point Distribution
- **STAMP Fundamentals**: 12 points (30%)
- **TDG Methodology**: 12 points (30%)
- **GDE Implementation**: 12 points (30%)
- **Integration Scenarios**: 4 points (10%)
- **Total**: 40 points

### Grade Scale
- **90-100% (36-40 points)**: Excellent - Ready for professional track
- **80-89% (32-35 points)**: Proficient - Certification requirements met
- **70-79% (28-31 points)**: Developing - Additional study recommended
- **Below 70% (<28 points)**: Needs improvement - Retake required

### Certification Requirements
- **Minimum Score**: 80% (32/40 points)
- **Practical Scenarios**: Must score at least 70% on practical questions
- **Integration**: Must demonstrate understanding of how methodologies work together

---

## 🔄 Retake Policy

### Retake Eligibility
- Available if initial score < 80%
- Must wait 7 days between attempts
- Maximum 3 attempts per certification period
- Additional study materials provided after each attempt

### Improvement Resources
**Score 70-79%**: Review specific module content, attend office hours
**Score 60-69%**: Complete additional practice exercises, join study group
**Score <60%**: Retake relevant training modules before next attempt

---

## 📝 Assessment Instructions

### Before You Begin
- [ ] Ensure stable internet connection
- [ ] Have 90 minutes uninterrupted time
- [ ] Review all training modules
- [ ] Prepare code editor for practical questions

### During Assessment
- [ ] Read questions carefully
- [ ] Manage time effectively (≈2 minutes per point)
- [ ] Show work for partial credit
- [ ] Use provided code templates

### Technical Requirements
- Modern web browser with JavaScript enabled
- Access to Elixir documentation (permitted)
- Text editor for code questions
- Calculator for GDE progress calculations

### Academic Integrity
- No collaboration during assessment
- No external communication
- Documentation references allowed
- Code must be your own work

---

**Assessment Platform**: indrajaal.dev/assessments
**Technical Support**: assessment-help@indrajaal.dev
**Questions**: Contact your instructor or use office hours

**Ready to demonstrate your STAMP/TDG/GDE mastery? Begin your assessment at the link above.**