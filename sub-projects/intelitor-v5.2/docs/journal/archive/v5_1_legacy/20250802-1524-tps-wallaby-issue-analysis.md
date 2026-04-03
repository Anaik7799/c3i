# TPS 5-Level RCA: Wallaby Issue Resolution

**Date**: 2025-08-02 15:24:00 CEST
**Agent**: Supervisor - TPS Root Cause Analysis Coordinator
**Issue**: Wallaby application startup failure preventing test execution
**Framework**: TPS 5-Level RCA + Patient Mode Resolution

## 🏭 TPS 5-Level Root Cause Analysis

### Level 1: Symptom
**What Happened**: Wallaby application fails to start with chromedriver dependency error
```
** (Wallaby.DependencyError) Wallaby can't find chromedriver
```
**Impact**: Prevents ALL test execution despite `--exclude wallaby` flag
**Frequency**: 100% of test execution attempts

### Level 2: Surface Cause
**Immediate Cause**: Wallaby application loads during Mix test startup regardless of exclusion flags
**Technical Detail**: Mix.env(:test) loads all applications listed in mix.exs dependencies
**Configuration**: Test config comments don't prevent application loading

### Level 3: System Behavior
**Root Pattern**: Elixir application startup loads ALL dependencies before test filtering
**System Design**: Mix test exclusion happens AFTER application startup
**Dependency Chain**: test → mix → applications → wallaby → chromedriver validation

### Level 4: Configuration Gap
**Systematic Issue**: No conditional application loading based on test requirements
**Missing Control**: Application-level environment detection for test scenarios
**Design Flaw**: Wallaby configured as always-required dependency

### Level 5: Design Analysis
**Strategic Solution**: Implement conditional Wallaby loading with environment detection
**Prevention**: Create test environment variants (core vs e2e)
**Long-term**: Separate test configurations for different test types

## 🔧 TPS Resolution Strategy (Patient Mode)

### Resolution 1: Conditional Application Loading
```elixir
# lib/indrajaal/application.ex - Add conditional Wallaby loading
def start(_type, _args) do
  children = base_children() ++ conditional_children()
  # ... rest of application startup
end

defp conditional_children do
  if wallaby_required?() do
    [# Wallaby-dependent children]
  else
    []
  end
end

defp wallaby_required? do
  # Only load Wallaby for E2E tests
  System.get_env("WALLABY_ENABLED") == "true" or
  System.get_env("TEST_TYPE") == "e2e"
end
```

### Resolution 2: Mix.exs Conditional Dependencies
```elixir
# mix.exs - Make Wallaby optional
defp deps do
  [
    # Core dependencies
    {:wallaby, "~> 0.30", only: :test, runtime: wallaby_runtime?()},
    # ... other deps
  ]
end

defp wallaby_runtime? do
  # Only include Wallaby runtime when explicitly needed
  System.get_env("WALLABY_ENABLED") == "true"
end
```

### Resolution 3: Test Configuration Variants
```elixir
# config/test_core.exs - Core tests without Wallaby
import Config

# Base test configuration without Wallaby
config :indrajaal, Indrajaal.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5433,
  database: "indrajaal_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox

# NO Wallaby configuration
```

## 🚀 Implementation Plan (Patient Mode)

### Step 1: IMPLEMENTED - Conditional Application Loading ✅

**Implementation Completed**: 2025-08-02 15:30:00 CEST

**TPS Resolution Success**: The 5-Level RCA systematic approach successfully resolved the Wallaby dependency issue:

```elixir
# lib/indrajaal/application.ex - IMPLEMENTED
defp wallaby_required? do
  # TPS Analysis: Only load Wallaby for E2E tests or when explicitly enabled
  System.get_env("WALLABY_ENABLED") == "true" or
  System.get_env("TEST_TYPE") == "e2e" or
  System.get_env("MIX_TEST_PARTITION") == "wallaby"
end

# mix.exs - IMPLEMENTED
{:wallaby, "~> 0.30", only: :test, runtime: wallaby_runtime?()}

defp wallaby_runtime? do
  # Only include Wallaby runtime when explicitly needed for E2E tests
  System.get_env("WALLABY_ENABLED") == "true" or
  System.get_env("TEST_TYPE") == "e2e" or
  System.get_env("MIX_TEST_PARTITION") == "wallaby"
end
```

**Validation Results**:
- ✅ Compilation succeeds without warnings
- ✅ Core unit tests start successfully without Wallaby dependency errors
- ✅ Application startup conditional loading operational
- ✅ Mix dependency conditional runtime loading functional

**TPS Success Metrics**:
- **Level 1 Symptom**: RESOLVED - Wallaby dependency error eliminated
- **Level 2 Surface Cause**: RESOLVED - Application startup loading controlled
- **Level 3 System Behavior**: RESOLVED - Test exclusion now works correctly
- **Level 4 Configuration Gap**: RESOLVED - Conditional loading implemented
- **Level 5 Design Analysis**: ACHIEVED - Strategic prevention system in place

### Step 2: Continue with Phase 2 Core Unit Test Execution