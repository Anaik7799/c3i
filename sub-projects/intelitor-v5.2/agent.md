# AI Agent Code Generation Guide for Indrajaal Project

## Overview
This guide provides essential rules and methodologies for AI agents (opencode, grok, etc.) to generate code that adheres to the Indrajaal Security Monitoring System's enterprise-grade standards. The project follows SOPv5.11 cybernetic framework with TPS + STAMP + TDG + PHICS + GDE methodologies.

## Core Methodologies

### 1. SOPv5.11 Cybernetic Framework
- **7-Phase Deployment**: Environment → Container → Agent → PHICS → Compilation → Monitoring → Security
- **50-Agent Architecture**: 1 Executive Director + 10 Domain Supervisors + 15 Functional Supervisors + 24 Workers
- **Goal-Oriented Execution**: All actions aligned with strategic objectives
- **Patient Mode**: Use `NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS="+S 16"`

### 2. TPS (Toyota Production System)
- **Jidoka**: Stop-and-fix at first warning/error
- **5-Level RCA**: Symptom → Surface Cause → System Behavior → Config Gap → Design Analysis
- **Continuous Improvement**: Kaizen methodology for quality enhancement
- **Respect for People**: Human oversight with AI coordination

### 3. STAMP (Systems-Theoretic Accident Model)
- **Proactive Analysis**: STPA for new features
- **Reactive Analysis**: CAST for incidents
- **8 Safety Constraints**: SC-001 through SC-008
- **Hazard Identification**: Unsafe Control Actions (UCAs)

### 4. TDG (Test-Driven Generation)
- **Tests First**: Write comprehensive tests BEFORE code generation
- **AI Generation**: Generate code to satisfy existing tests
- **Validation**: Ensure all tests pass with generated code
- **Refactor**: Improve code quality while maintaining test coverage

### 5. PHICS v2.1 (Phoenix Hot-Reloading Integration)
- **Bidirectional Sync**: <50ms latency between host and container
- **Container-Native**: All development within Podman containers
- **Hot-Reloading**: Seamless code updates without container restart

## Code Generation Rules

### Compilation Standards
```bash
# MANDATORY: Patient Mode Compilation
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS="+S 16" mix compile --verbose 2>&1 | tee -a compilation.log

# FORBIDDEN: Direct compilation without patient mode
mix compile --warnings-as-errors  # VIOLATION
```

### Zero-Warning Policy
- **MANDATORY**: All code must compile without warnings
- **Validation**: Run `mix format` and `mix credo --strict` immediately after generation
- **Fix Issues**: Address any format or credo violations before finalizing code
- **Audit Trail**: Log all quality checks in Claude activity logs

### Ash Framework Best Practices
```elixir
# ✅ CORRECT: UPDATE action with function-based changes
update :custom_action do
  require_atomic? false  # MANDATORY for function-based changes

  change fn changeset, _context ->
    # Function-based logic here
    changeset |> Ash.Changeset.change_attribute(:field, value)
  end
end

# ❌ FORBIDDEN: UPDATE action without require_atomic? false
update :simple_action do
  accept [:field1, :field2]  # No require_atomic? needed for simple updates
end
```

### Container Policies
- **Podman Only**: Use `podman` exclusively, never `docker`
- **Localhost Registry**: All images from `localhost/` registry
- **PHICS Integration**: Enable hot-reloading for development containers
- **Rootless Execution**: All containers run as unprivileged user

### Script Language Policy
- **Primary**: Elixir (.exs files) for all project-specific scripts
- **Secondary**: Python (.py files) for data processing
- **Forbidden**: Bash, JavaScript, Ruby, Perl, PowerShell

### Timestamp Management
- **Local Time Only**: Use current system local time (CEST/CET)
- **Format**: "YYYY-MM-DD HH:MM:SS CEST"
- **Never UTC**: DateTime.utc_now() is forbidden
- **Validation**: Run timestamp validation scripts before commits

## Testing Standards

### Coverage Requirements
- **Unit Tests**: 100% coverage for functional modules
- **Integration Tests**: 85% coverage for intermodule interactions
- **Property Tests**: Dual PropCheck + ExUnitProperties
- **TDG Compliance**: Tests written BEFORE code generation

### Test Structure
```elixir
defmodule MyModuleTest do
  use ExUnit.Case, async: true
  use PropCheck          # Advanced property testing
  use ExUnitProperties   # StreamData-based testing

  # Unit tests
  test "function behaves correctly" do
    # Test implementation
  end

  # Property tests
  property "function handles all edge cases" do
    forall input <- term() do
      result = MyModule.function(input)
      # Property assertions
    end
  end
end
```

## Quality Assurance

### Code Quality Validation
```bash
# MANDATORY: Format and validate code
mix format path/to/file.ex
mix credo --strict path/to/file.ex

# Fix any issues identified
# Re-run validation until clean
```

### Hierarchical Numbering
- **Format**: 1.0, 1.1, 1.1.1, 1.1.1.1
- **Categories**: 1.0 Development, 2.0 Testing, 3.0 Documentation, etc.
- **Status Rollup**: Parent status reflects children status
- **Validation**: Use hierarchical numbering validator scripts

### Dual Logging
- **Terminal Output**: All logs appear in developer console
- **SigNoz Output**: All logs simultaneously appear in SigNoz
- **Identical Content**: Both backends receive identical data
- **Validation**: Check both backends for every log operation

## Development Workflow

### Daily Workflow
1. **Morning Check**: Validate environment and container status
2. **Task Planning**: ALWAYS use F# Planning CLI (`sa-plan`) for all tasks. Elixir `mix todo` is FORBIDDEN. MUST use hierarchical numbering for all tasks ALWAYS. MUST NEVER be deleted and overwritten.
3. **Code Generation**: Follow TDG methodology (tests first)
4. **Quality Validation**: Format, credo, and compilation checks
5. **Container Testing**: Validate in Podman containers with PHICS
6. **Documentation**: Update journal with timestamp format. ALL journal entries MUST follow the 13-section template (SC-SYNC-DOC-003).
7. **Backup**: Create timestamped backups before major changes

### Emergency Protocols
- **Compilation Failure**: Apply TPS 5-Level RCA
- **Container Issues**: Use STAMP safety constraints
- **Quality Violations**: Immediate halt and systematic fix
- **Timestamp Drift**: Correct to current local time
- **False Positives**: Use multi-method consensus validation

## Integration Points

### Mix Tasks
```bash
# Compilation (MANDATORY patient mode)
mix claude compilation --compile --strategy smart

# Testing (comprehensive coverage)
mix test --comprehensive --coverage

# Quality validation
mix format --check-formatted
mix credo --strict
```

### Container Commands
```bash
# Container management (Podman only)
podman run -d --name indrajaal-app localhost/indrajaal-app:nixos-devenv
podman exec -it indrajaal-app bash

# PHICS hot-reloading
export PHICS_ENABLED=true
export PHICS_WATCH_ENABLED=true
```

### Validation Scripts
```bash
# Timestamp validation
elixir scripts/maintenance/simple_timestamp_validator.exs --audit

# Container compliance
elixir scripts/validation/container_policy_validator.exs --comprehensive

# Compilation validation
elixir scripts/validation/comprehensive_compilation_validator.exs --save-report
```

## Compliance Checklist

### Pre-Generation Checklist
- [ ] Environment validated (NixOS, Podman, PHICS)
- [ ] Tests written first (TDG compliance)
- [ ] Safety constraints reviewed (STAMP)
- [ ] Container policies confirmed (localhost registry)
- [ ] Timestamp format verified (local time)

### Post-Generation Checklist
- [ ] Code formatted (`mix format`)
- [ ] Credo validation passed (`mix credo --strict`)
- [ ] Compilation successful (patient mode)
- [ ] Tests passing (95%+ coverage)
- [ ] Container validation (Podman + PHICS)
- [ ] Documentation updated (journal with timestamps)
- [ ] Backup created (timestamped)

### Quality Gates
- [ ] Zero warnings compilation
- [ ] 95%+ test coverage
- [ ] STAMP safety compliance
- [ ] TDG methodology adherence
- [ ] TPS continuous improvement
- [ ] PHICS hot-reloading validation

## Emergency Response

### Compilation Issues
1. **HALT**: Stop all development activities
2. **ANALYZE**: Apply TPS 5-Level RCA
3. **FIX**: Systematic error resolution
4. **VALIDATE**: Patient mode compilation
5. **RESUME**: Continue with validated code

### Container Failures
1. **DIAGNOSE**: Check STAMP safety constraints
2. **RECOVER**: Use verified setup scripts
3. **VALIDATE**: PHICS integration confirmed
4. **DOCUMENT**: Update incident logs
5. **PREVENT**: Enhance monitoring

### Quality Violations
1. **STOP**: Immediate halt on violations
2. **ASSESS**: Determine scope and impact
3. **CORRECT**: Apply systematic fixes
4. **VERIFY**: Re-run all quality gates
5. **IMPROVE**: Update prevention measures

## Success Metrics

### Code Quality
- **Format Compliance**: 100%
- **Credo Score**: 95%+
- **Warning Count**: 0
- **Test Coverage**: 95%+

### System Performance
- **Compilation Time**: <45 minutes (patient mode)
- **Container Startup**: <30 seconds
- **PHICS Latency**: <50ms
- **Test Execution**: <10 minutes

### Methodology Compliance
- **TDG Adherence**: 100%
- **STAMP Safety**: 100%
- **TPS RCA**: Applied to all issues
- **SOPv5.11 Goals**: 95%+ achievement

## Reference Documentation

- **CLAUDE.md**: Complete project standards and methodologies
- **docs/journal/**: Daily progress and issue resolution
- **scripts/**: Automation and validation tools
- **test/**: Comprehensive test suites
- **lib/**: Source code with Ash domain implementations

---

**MANDATORY**: This guide must be consulted before any code generation. All AI agents must achieve 100% compliance with these standards to ensure enterprise-grade quality and system reliability.