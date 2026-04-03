# Daily Workflow Checklist: STAMP/TDG/GDE

**Purpose:** Ensure consistent application of STAMP, TDG, and GDE methodologies in daily development work
**Frequency:** Daily use recommended
**Duration:** 5-15 minutes depending on scope of work

---

## 🌅 Morning Routine (5 minutes)

### Goal Status Check
- [ ] **Check GDE Dashboard**: Review progress on active goals
  ```bash
  mix gde.status --my-goals
  ```
- [ ] **Identify At-Risk Goals**: Note any goals showing red/yellow status
- [ ] **Review Interventions**: Check if any automated interventions occurred overnight
- [ ] **Plan Goal-Aligned Work**: Prioritize tasks that advance critical goals

### Safety Awareness Update
- [ ] **Review Recent Incidents**: Check for any safety-related incidents or alerts
- [ ] **Safety Constraint Awareness**: Refresh understanding of active safety constraints for today's work
- [ ] **STAMP Alert Review**: Check for any new STAMP analysis recommendations

### TDG Compliance Check
- [ ] **Validate Current Branch**: Ensure all existing code has proper test coverage
  ```bash
  mix tdg.validate --my-changes
  ```
- [ ] **Review Test Debt**: Check for any untested code that needs attention
- [ ] **Plan Test-First Work**: Identify features requiring TDG implementation

---

## 🚀 Pre-Feature Development (10 minutes)

### Feature Planning Phase
- [ ] **Understand Requirements**: Clear comprehension of what needs to be built
- [ ] **Identify Stakeholders**: Who will be affected by this feature?
- [ ] **Business Impact Assessment**: How does this feature align with business goals?

### STAMP Analysis (if applicable)
**Trigger Conditions** (perform STAMP analysis if ANY apply):
- [ ] Feature involves user authentication or authorization
- [ ] Feature handles financial transactions or sensitive data
- [ ] Feature affects system availability or performance
- [ ] Feature integrates with external systems
- [ ] Feature modifies critical business logic
- [ ] Regulatory or compliance implications exist

**If STAMP Analysis Required:**
- [ ] **Define Safety Constraints**: What must the system do/not do to be safe?
  ```markdown
  Safety Constraints:
  - SC1: [Constraint 1]
  - SC2: [Constraint 2]
  - SC3: [Constraint 3]
  ```
- [ ] **Quick UCA Check**: Identify obvious unsafe control actions
- [ ] **Document Safety Requirements**: Convert constraints into testable requirements

### TDG Test Planning
- [ ] **Identify Test Scenarios**: What behaviors need validation?
  - [ ] Happy path scenarios
  - [ ] Error conditions
  - [ ] Edge cases
  - [ ] Security scenarios (if applicable)
  - [ ] Performance requirements (if applicable)

- [ ] **Plan Property Tests**: What mathematical properties should hold?
- [ ] **Design Integration Tests**: How will this interact with other components?

### GDE Goal Alignment
- [ ] **Connect to Existing Goals**: How does this feature advance current goals?
- [ ] **Define Feature Goals**: What specific, measurable outcomes should this feature achieve?
  ```elixir
  @feature_goal %{
    name: "_____________",
    metric: "_____________",
    target: "_____________",
    deadline: "_____________"
  }
  ```
- [ ] **Plan Measurement**: How will you track success?

---

## 💻 During Development (ongoing)

### TDG Implementation Workflow

**Step 1: Test Creation (ALWAYS FIRST)**
- [ ] **Write Unit Tests**: Test individual function behavior
  ```elixir
  test "function_name with valid input" do
    # Test implementation
  end

  test "function_name with invalid input" do
    # Error handling test
  end
  ```

- [ ] **Write Property Tests**: Use both PropCheck and ExUnitProperties
  ```elixir
  property "property description" do
    forall input <- generator() do
      # Property validation
    end
  end
  ```

- [ ] **Write Integration Tests**: Test component interactions
- [ ] **Validate Test Quality**: Ensure tests are comprehensive and meaningful

**Step 2: TDG Validation**
- [ ] **Pre-Generation Check**: Confirm tests exist and are comprehensive
  ```bash
  mix tdg.validate --pre-generation
  ```
- [ ] **Test Coverage Target**: Aim for 100% coverage of new code

**Step 3: Implementation**
- [ ] **AI-Assisted Implementation**: Use AI tools with test context
  ```
  AI Prompt Template:
  "Generate implementation for [function_name] that passes these tests:
  [include test code]
  Requirements: [specific requirements]
  Safety constraints: [if applicable]"
  ```
- [ ] **Manual Implementation**: Write code that passes all tests
- [ ] **Iterative Refinement**: Improve implementation while maintaining test compliance

**Step 4: Post-Implementation Validation**
- [ ] **Run All Tests**: Ensure all tests pass
  ```bash
  mix test
  ```
- [ ] **TDG Compliance Check**: Validate methodology compliance
  ```bash
  mix tdg.validate --post-generation
  ```
- [ ] **Coverage Verification**: Confirm coverage targets met
  ```bash
  mix test --cover
  ```

### Safety Integration
- [ ] **Safety Constraint Implementation**: Ensure safety requirements are coded correctly
- [ ] **Safety Test Validation**: Verify safety constraints are properly tested
- [ ] **Error Handling**: Implement proper error handling for safety-critical paths

### Progress Tracking
- [ ] **Update Goal Progress**: Log progress toward feature and business goals
  ```bash
  mix gde.track --goal goal_name --progress current_value
  ```
- [ ] **Document Decisions**: Record important technical decisions and trade-offs

---

## 🔍 Pre-Commit Validation (5 minutes)

### Code Quality Verification
- [ ] **Format Code**: Ensure consistent formatting
  ```bash
  mix format
  ```
- [ ] **Lint Check**: Run static analysis
  ```bash
  mix credo --strict
  ```
- [ ] **Type Check**: Validate types with Dialyzer
  ```bash
  mix dialyzer
  ```

### TDG Compliance Final Check
- [ ] **Test Suite**: All tests pass
- [ ] **Coverage**: Coverage targets met
- [ ] **TDG Validation**: Final compliance check
  ```bash
  mix tdg.validate --comprehensive
  ```

### Safety Validation
- [ ] **Safety Tests**: All safety-related tests pass
- [ ] **Security Scan**: Run security analysis if applicable
  ```bash
  mix sobelow
  ```

### Goal Alignment Check
- [ ] **Goal Progress**: Verify work advances stated goals
- [ ] **Measurement Update**: Update relevant metrics

---

## 🌙 End-of-Day Reflection (5 minutes)

### Progress Review
- [ ] **Goals Assessment**: Review progress on daily and long-term goals
- [ ] **Blockers Identification**: Note any obstacles encountered
- [ ] **Success Celebration**: Acknowledge completed objectives

### Learning Integration
- [ ] **Document Insights**: Record important discoveries or learnings
- [ ] **Process Improvements**: Note ways to improve tomorrow's workflow
- [ ] **Knowledge Sharing**: Plan to share learnings with team

### Tomorrow's Preparation
- [ ] **Plan Next Steps**: Outline tomorrow's priorities
- [ ] **Goal Alignment**: Ensure tomorrow's work advances key objectives
- [ ] **Resource Preparation**: Identify needed resources or information

---

## 🚨 Emergency Situations

### Production Issues
**If safety-related production issue occurs:**
- [ ] **Immediate Response**: Follow incident response procedures
- [ ] **CAST Investigation**: Plan systematic CAST analysis
- [ ] **Safety Review**: Review affected safety constraints
- [ ] **TDG Validation**: Ensure fixes follow TDG methodology
- [ ] **Goal Impact**: Assess impact on reliability/safety goals

### TDG Violations Detected
**If untested code is discovered:**
- [ ] **Stop Development**: Pause feature work immediately
- [ ] **Assess Impact**: Determine scope of violation
- [ ] **Create Tests**: Write comprehensive tests for untested code
- [ ] **Validate Implementation**: Ensure code passes all tests
- [ ] **Process Review**: Identify how violation occurred

### Goal Risk Alerts
**If goals show high risk status:**
- [ ] **Assess Situation**: Understand root causes of goal risk
- [ ] **Plan Interventions**: Identify corrective actions
- [ ] **Resource Allocation**: Adjust priorities if needed
- [ ] **Stakeholder Communication**: Inform relevant parties

---

## 📋 Weekly Review Additions

### Process Effectiveness (weekly)
- [ ] **Workflow Assessment**: How well did the daily workflow serve you?
- [ ] **Tool Effectiveness**: Are the STAMP/TDG/GDE tools helping?
- [ ] **Training Needs**: Identify areas for skill development
- [ ] **Process Improvements**: Suggest workflow enhancements

### Methodology Deepening (weekly)
- [ ] **STAMP Practice**: Complete additional STPA analysis if applicable
- [ ] **TDG Skill Building**: Practice advanced property-based testing
- [ ] **GDE Optimization**: Review and refine goal-setting approaches
- [ ] **Integration Mastery**: Look for better ways to combine methodologies

---

## 🎯 Success Indicators

**Daily Workflow is Successful When:**
- [ ] All code has comprehensive tests (TDG compliance)
- [ ] Safety constraints are identified and implemented (STAMP integration)
- [ ] Progress toward goals is measurable and positive (GDE effectiveness)
- [ ] Development velocity is maintained or improved
- [ ] Quality indicators trend positively
- [ ] Team confidence in system safety and reliability increases

**Red Flags (Address Immediately):**
- [ ] Untested code in commits
- [ ] Safety constraints being ignored or bypassed
- [ ] Goals consistently showing no progress
- [ ] Increasing technical debt
- [ ] Rising incident rates
- [ ] Team stress about system reliability

---

## 🛠️ Tools and Commands Quick Reference

```bash
# TDG Commands
mix tdg.validate --pre-generation    # Before any AI code generation
mix tdg.validate --post-generation   # After implementing features
mix tdg.validate --comprehensive     # Full project TDG audit
mix test --cover                      # Test with coverage analysis

# GDE Commands
mix gde.status --my-goals            # Check personal goal progress
mix gde.track --goal name --value X  # Update goal progress
mix gde.dashboard                    # Open goals dashboard

# STAMP Commands
mix stamp.validate --my-changes      # Check safety compliance
mix stamp.stpa --domain domain_name  # Start STPA analysis
mix stamp.cast --incident inc_id     # Begin CAST investigation

# Quality Commands
mix format                           # Format code
mix credo --strict                   # Lint analysis
mix dialyzer                        # Type checking
mix sobelow                         # Security analysis
```

---

**💡 Pro Tip**: Print this checklist and keep it visible during development. With practice, these steps become second nature and significantly improve your development quality and effectiveness.

**Questions?** Join #daily-workflow in Slack or contact methodology-support@indrajaal.dev