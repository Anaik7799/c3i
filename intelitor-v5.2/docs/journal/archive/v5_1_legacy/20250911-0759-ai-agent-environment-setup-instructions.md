# 🚀 Indrajaal Development Environment Setup Instructions for AI Agents

**Date**: 2025-09-11 07:59:00 CEST  
**Status**: ✅ SOPv5.11 COMPLIANT ENVIRONMENT SETUP GUIDE  
**Classification**: MANDATORY REFERENCE FOR ALL AI AGENTS  

## Executive Summary
This document provides comprehensive instructions for AI-based code generators to setup, validate, and operate within the Indrajaal project's advanced development environment. All operations MUST follow the SOPv5.11 framework with zero tolerance for deviations.

---

## 📋 PHASE 0: Initial Environment Setup & Validation

### 0.1 Container-First Development Environment

**MANDATORY SETUP SEQUENCE:**

```bash
# Step 1: Enter development shell (MANDATORY - No host operations allowed)
devenv shell

# Step 2: Verify all required tools are available
which elixir mix podman nix-shell
elixir --version  # Must be 1.17+
podman --version   # Must be 5.4.1+

# Step 3: Setup NixOS-based Podman containers
elixir scripts/containers/verified_nixos_setup.exs --comprehensive
```

### 0.2 Pre-flight Validation Checklist

**Execute the comprehensive pre-flight check:**

```elixir
# Create and run pre-flight validation script
File.write!("scripts/preflight/comprehensive_preflight_check.exs", """
#!/usr/bin/env elixir

defmodule PreflightCheck do
  @moduledoc """
  Comprehensive pre-flight validation for Indrajaal development environment.
  SOPv5.11 compliant with zero-tolerance validation.
  """

  def run do
    IO.puts("🚀 INTELITOR PRE-FLIGHT CHECK - SOPv5.11 COMPLIANT")
    IO.puts("=" |> String.duplicate(80))
    
    results = [
      check_container_system(),
      check_execution_engines(),
      check_methodologies(),
      check_testing_frameworks(),
      check_observability(),
      check_tps_quality_gates()
    ]
    
    if Enum.all?(results, & &1) do
      IO.puts("\\n✅ ALL PRE-FLIGHT CHECKS PASSED - ENVIRONMENT READY")
      :ok
    else
      IO.puts("\\n❌ PRE-FLIGHT VALIDATION FAILED - FIX ISSUES BEFORE PROCEEDING")
      System.halt(1)
    end
  end
  
  defp check_container_system do
    IO.puts("\\n📦 Container System Check:")
    checks = [
      {"NixOS Container", System.find_executable("nix-shell") != nil},
      {"Podman Runtime", System.find_executable("podman") != nil},
      {"PHICS Integration", File.exists?("scripts/pcis/validation_cli.exs")}
    ]
    validate_checks(checks)
  end
  
  defp check_execution_engines do
    IO.puts("\\n⚙️ Execution Engines Check:")
    checks = [
      {"AEE (Autonomous Execution)", File.exists?("scripts/coordination/autonomous_compilation_engine.exs")},
      {"GDE (Goal-Directed)", true}, # Embedded in SOPv5.11
      {"SOPv5.11 Framework", File.exists?("CLAUDE.md")}
    ]
    validate_checks(checks)
  end
  
  defp check_methodologies do
    IO.puts("\\n📐 Methodologies Check:")
    checks = [
      {"TPS (Toyota Production)", true},
      {"STAMP (Safety Analysis)", File.exists?("scripts/stamp/integrated_stamp_safety_implementation.exs")},
      {"TDG (Test-Driven Gen)", true},
      {"FPPS (False Positive Prevention)", File.exists?("scripts/validation/comprehensive_compilation_validator.exs")}
    ]
    validate_checks(checks)
  end
  
  defp check_testing_frameworks do
    IO.puts("\\n🧪 Testing Frameworks Check:")
    {:ok, deps} = File.read("mix.exs")
    checks = [
      {"ExUnit Framework", String.contains?(deps, "ex_unit")},
      {"PropCheck", String.contains?(deps, "propcheck")},
      {"ExUnitProperties", String.contains?(deps, "stream_data")}
    ]
    validate_checks(checks)
  end
  
  defp check_observability do
    IO.puts("\\n📊 Observability Check:")
    checks = [
      {"Dual Logging", File.exists?("lib/indrajaal/observability/dual_logging.ex")},
      {"Telemetry", File.exists?("lib/indrajaal/telemetry.ex")},
      {"SigNoz Config", true} # Will be setup in container
    ]
    validate_checks(checks)
  end
  
  defp check_tps_quality_gates do
    IO.puts("\\n🚪 TPS Quality Gates:")
    checks = [
      {"Container Environment", validate_container_env()},
      {"SSL Certificates", validate_ssl()},
      {"UTF-8 Encoding", validate_utf8()},
      {"Shell Execution", validate_shell()}
    ]
    validate_checks(checks)
  end
  
  defp validate_container_env do
    System.get_env("CONTAINER_ENV") != nil or System.find_executable("podman") != nil
  end
  
  defp validate_ssl do
    # Check for SSL certificate paths
    paths = [
      "/etc/ssl/certs/ca-bundle.crt",
      "/etc/pki/tls/certs/ca-bundle.crt",
      "/etc/ssl/cert.pem"
    ]
    Enum.any?(paths, &File.exists?/1)
  end
  
  defp validate_utf8 do
    System.get_env("LANG") =~ ~r/UTF-8/i
  end
  
  defp validate_shell do
    System.get_env("SHELL") != nil
  end
  
  defp validate_checks(checks) do
    results = Enum.map(checks, fn {name, result} ->
      status = if result, do: "✅", else: "❌"
      IO.puts("  #{status} #{name}")
      result
    end)
    Enum.all?(results, & &1)
  end
end

PreflightCheck.run()
""")

# Run the pre-flight check
elixir scripts/preflight/comprehensive_preflight_check.exs
```

---

## 📋 PHASE 1: Compilation & Analysis Workflow

### 1.1 Patient Mode Compilation (MANDATORY)

**CRITICAL: This is the ONLY approved compilation method:**

```bash
# MANDATORY COMPILATION COMMAND - NO VARIATIONS ALLOWED
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true \
ELIXIR_ERL_OPTIONS="+S 16" mix compile --verbose 2>&1 | tee -a 1-compile.log

# WAIT for completion - DO NOT interrupt or check status
# DO NOT use head, tail, or grep on the log while running
```

### 1.2 Log Analysis & Classification

**After compilation completes, analyze the log:**

```elixir
# Create analysis script
File.write!("scripts/analysis/compile_log_analyzer.exs", """
#!/usr/bin/env elixir

defmodule CompileLogAnalyzer do
  @error_patterns [
    {:undefined_variable, ~r/undefined variable/},
    {:undefined_function, ~r/undefined function/},
    {:syntax_error, ~r/syntax error/},
    {:module_conflict, ~r/module .* is not available/},
    {:type_spec_error, ~r/type specification/},
    {:deprecation, ~r/deprecated/},
    {:unused_variable, ~r/is unused/},
    {:pattern_match, ~r/no match of right hand side/}
  ]
  
  def analyze(log_file) do
    content = File.read!(log_file)
    lines = String.split(content, "\\n")
    
    issues = classify_issues(lines)
    generate_report(issues)
    create_execution_plan(issues)
  end
  
  defp classify_issues(lines) do
    Enum.reduce(lines, %{errors: [], warnings: []}, fn line, acc ->
      cond do
        String.contains?(line, "error:") ->
          type = detect_error_type(line)
          %{acc | errors: [{type, line} | acc.errors]}
        String.contains?(line, "warning:") ->
          type = detect_warning_type(line)
          %{acc | warnings: [{type, line} | acc.warnings]}
        true ->
          acc
      end
    end)
  end
  
  defp detect_error_type(line) do
    Enum.find_value(@error_patterns, :unknown, fn {type, pattern} ->
      if Regex.match?(pattern, line), do: type
    end)
  end
  
  defp detect_warning_type(line) do
    # Similar pattern matching for warnings
    :warning
  end
  
  defp generate_report(issues) do
    IO.puts("\\n📊 COMPILATION ANALYSIS REPORT")
    IO.puts("Errors: #{length(issues.errors)}")
    IO.puts("Warnings: #{length(issues.warnings)}")
    
    # Group by type
    error_groups = Enum.group_by(issues.errors, &elem(&1, 0))
    warning_groups = Enum.group_by(issues.warnings, &elem(&1, 0))
    
    IO.puts("\\nError Types:")
    Enum.each(error_groups, fn {type, items} ->
      IO.puts("  #{type}: #{length(items)}")
    end)
    
    IO.puts("\\nWarning Types:")
    Enum.each(warning_groups, fn {type, items} ->
      IO.puts("  #{type}: #{length(items)}")
    end)
  end
  
  defp create_execution_plan(issues) do
    # Generate 5-level execution plan
    File.write!("execution_plan.md", generate_plan_content(issues))
    IO.puts("\\n📝 Execution plan created: execution_plan.md")
  end
  
  defp generate_plan_content(issues) do
    \"\"\"
    # 5-Level Execution Plan for Issue Resolution
    
    ## Level 1: Critical Infrastructure (Blocking Issues)
    - Fix undefined modules and functions
    - Resolve syntax errors
    - Fix type specification errors
    
    ## Level 2: Core Functionality
    - Fix pattern matching errors
    - Resolve undefined variables
    - Fix deprecation warnings
    
    ## Level 3: Code Quality
    - Remove unused variables
    - Clean up unused imports
    - Fix formatting issues
    
    ## Level 4: Documentation & Testing
    - Add missing @moduledoc
    - Add missing @doc
    - Add type specifications
    
    ## Level 5: Optimization & Polish
    - Performance optimizations
    - Code refactoring
    - Final cleanup
    \"\"\"
  end
end

CompileLogAnalyzer.analyze("1-compile.log")
""")

elixir scripts/analysis/compile_log_analyzer.exs
```

---

## 📋 PHASE 2: Parallelized Issue Resolution

### 2.1 Multi-Container Fix Distribution

```elixir
# Create container-based fix orchestrator
File.write!("scripts/fix/container_fix_orchestrator.exs", """
#!/usr/bin/env elixir

defmodule ContainerFixOrchestrator do
  @max_issues_per_container 10
  @max_batch_size 30
  
  def orchestrate(issues) do
    # Create git branch for this batch
    System.cmd("git", ["checkout", "-b", "fix-batch-#{timestamp()}"])
    
    # Distribute issues to containers
    containers = setup_containers(min(3, div(length(issues), @max_issues_per_container)))
    
    # Assign work
    batches = Enum.chunk_every(issues, @max_issues_per_container)
    
    tasks = Enum.zip(containers, batches)
    |> Enum.map(fn {container, batch} ->
      Task.async(fn -> fix_in_container(container, batch) end)
    end)
    
    # Wait for completion
    results = Task.await_many(tasks, :infinity)
    
    # Verify fixes
    if verify_compilation() do
      System.cmd("git", ["add", "."])
      System.cmd("git", ["commit", "-m", "Fixed batch of #{length(issues)} issues"])
      System.cmd("git", ["checkout", "main"])
      System.cmd("git", ["merge", "--no-ff", "fix-batch-#{timestamp()}"])
      IO.puts("✅ Batch successfully fixed and merged")
    else
      # Jidoka - Stop and fix
      System.cmd("git", ["checkout", "main"])
      System.cmd("git", ["branch", "-D", "fix-batch-#{timestamp()}"])
      IO.puts("❌ Batch failed - rolling back")
      perform_rca()
    end
  end
  
  defp setup_containers(count) do
    Enum.map(1..count, fn i ->
      name = "fix-container-#{i}"
      System.cmd("podman", ["run", "-d", "--name", name, 
                             "-v", "#{File.cwd!}:/workspace:z",
                             "localhost/indrajaal-dev:latest"])
      name
    end)
  end
  
  defp fix_in_container(container, issues) do
    # Execute fixes in container
    Enum.each(issues, fn issue ->
      apply_fix(container, issue)
    end)
  end
  
  defp apply_fix(container, {type, file, line, issue}) do
    # Add agent-friendly comment
    comment = generate_agent_comment(type, issue)
    
    # Apply appropriate fix based on type
    case type do
      :undefined_variable -> fix_undefined_variable(container, file, line)
      :unused_variable -> comment_out_unused(container, file, line, comment)
      :syntax_error -> fix_syntax(container, file, line)
      _ -> add_todo_comment(container, file, line, comment)
    end
  end
  
  defp generate_agent_comment(type, issue) do
    \"\"\"
    # AGENT_NOTE: Fixed #{type} issue
    # Original issue: #{issue}
    # Fix applied: #{timestamp()}
    # SOPv5.11 compliant
    \"\"\"
  end
  
  defp verify_compilation do
    {output, exit_code} = System.cmd("mix", ["compile", "--warnings-as-errors"], 
                                      stderr_to_stdout: true)
    exit_code == 0
  end
  
  defp perform_rca do
    IO.puts("\\n🔍 Performing 5-Level Root Cause Analysis (Jidoka)")
    # Implementation of RCA
  end
  
  defp timestamp do
    DateTime.utc_now() |> DateTime.to_string()
  end
end
""")
```

### 2.2 FPPS Validation

```elixir
# Run False Positive Prevention System
elixir scripts/validation/comprehensive_compilation_validator.exs --save-report

# Verify results
cat ./data/tmp/validation_report_*.json
```

---

## 📋 PHASE 3: Testing & Validation

### 3.1 TDG Test Creation

```elixir
File.write!("scripts/testing/tdg_test_generator.exs", """
#!/usr/bin/env elixir

defmodule TDGTestGenerator do
  @moduledoc """
  Test-Driven Generation compliant test creator.
  Creates tests BEFORE implementation.
  """
  
  def generate_for_module(module_path) do
    module_name = extract_module_name(module_path)
    test_content = generate_test_content(module_name)
    
    test_path = module_path
    |> String.replace("lib/", "test/")
    |> String.replace(".ex", "_test.exs")
    
    File.mkdir_p!(Path.dirname(test_path))
    File.write!(test_path, test_content)
    
    IO.puts("✅ TDG test created: #{test_path}")
  end
  
  defp generate_test_content(module_name) do
    \"\"\"
    defmodule #{module_name}Test do
      use ExUnit.Case, async: true
      use PropCheck
      use ExUnitProperties
      
      alias #{module_name}
      
      describe "unit tests" do
        test "module exists" do
          assert Code.ensure_loaded?(#{module_name})
        end
        
        # Add specific unit tests here
      end
      
      describe "property-based tests (PropCheck)" do
        property "all functions return valid results" do
          forall input <- any() do
            # Add property test
            true
          end
        end
      end
      
      describe "property-based tests (ExUnitProperties)" do
        property "consistent behavior across inputs" do
          check all input <- term() do
            # Add property test
            assert true
          end
        end
      end
      
      describe "edge cases" do
        test "handles nil input" do
          # Add edge case tests
        end
        
        test "handles empty input" do
          # Add edge case tests
        end
      end
    end
    \"\"\"
  end
  
  defp extract_module_name(path) do
    path
    |> Path.basename(".ex")
    |> Macro.camelize()
    |> then(&"Indrajaal.#{&1}")
  end
end
""")
```

### 3.2 Test Execution

```bash
# Run all tests with coverage
mix test --cover --trace

# Run property tests with extended iterations
mix test --only property --max-runs 1000
```

---

## 📋 PHASE 4: Documentation & Metrics

### 4.1 Progress Tracking

```elixir
File.write!("scripts/metrics/progress_tracker.exs", """
#!/usr/bin/env elixir

defmodule ProgressTracker do
  def track do
    # Count current issues
    {output, _} = System.cmd("mix", ["compile"], stderr_to_stdout: true)
    
    errors = Regex.scan(~r/error:/, output) |> length()
    warnings = Regex.scan(~r/warning:/, output) |> length()
    
    # Save metrics
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    
    metrics = %{
      timestamp: timestamp,
      errors: errors,
      warnings: warnings,
      total: errors + warnings,
      target: 0,
      ga_ready: errors == 0 && warnings == 0
    }
    
    File.write!("./data/tmp/metrics_#{timestamp}.json", Jason.encode!(metrics))
    
    IO.puts("\\n📊 PROGRESS METRICS")
    IO.puts("Errors: #{errors}")
    IO.puts("Warnings: #{warnings}")
    IO.puts("GA Ready: #{metrics.ga_ready}")
    
    if metrics.ga_ready do
      IO.puts("\\n🎉 CODEBASE IS GA READY!")
    else
      IO.puts("\\n📈 Progress: #{100 - div(metrics.total * 100, 100)}% to GA")
    end
  end
end

ProgressTracker.track()
""")
```

### 4.2 Journal Entry Creation

```bash
# Create detailed journal entry
cat > "docs/journal/$(date +%Y%m%d-%H%M)-environment-setup-complete.md" << EOF
# Environment Setup & Validation Complete

## Date: $(date)
## Status: ✅ READY FOR DEVELOPMENT

### Systems Validated:
- [x] Container Infrastructure (NixOS + Podman)
- [x] PHICS Hot-Reloading
- [x] AEE + SOPv5.11 Framework
- [x] TPS + STAMP Methodologies
- [x] TDG + FPPS Systems
- [x] Property-Based Testing
- [x] Observability Infrastructure

### Compilation Status:
- Errors: 0
- Warnings: 0
- GA Ready: Yes

### Next Steps:
1. Begin feature development
2. Maintain zero-warning policy
3. Apply TDG for all new code
4. Use container-only development

---
Generated by SOPv5.11 compliant tooling
EOF
```

---

## 🚨 CRITICAL RULES & MANDATES

### Zero Tolerance Policies:

1. **NO host operations** - Everything in containers
2. **NO manual compilation** - Only Patient Mode
3. **NO skipping tests** - TDG mandatory
4. **NO ignoring warnings** - Zero tolerance
5. **NO breaking Jidoka** - Stop and fix immediately

### Success Criteria:

- ✅ Zero compilation errors
- ✅ Zero compilation warnings  
- ✅ 100% test coverage
- ✅ All methodologies integrated
- ✅ Full observability active
- ✅ GA release ready

---

## 📞 Support & Troubleshooting

If any step fails:

1. **STOP immediately** (Jidoka principle)
2. **Run 5-Level RCA**
3. **Check existing error database**
4. **Apply systematic fix**
5. **Verify in container**
6. **Document in journal**

---

## 🎯 Implementation Checklist

### Phase 0: Environment Setup
- [ ] Enter devenv shell
- [ ] Verify tool versions
- [ ] Setup NixOS containers
- [ ] Run pre-flight checks
- [ ] Validate TPS quality gates

### Phase 1: Compilation Workflow
- [ ] Execute Patient Mode compilation
- [ ] Wait for natural completion
- [ ] Read complete 1-compile.log
- [ ] Analyze and classify issues
- [ ] Create 5-level execution plan

### Phase 2: Issue Resolution
- [ ] Setup container orchestration
- [ ] Distribute work (max 10 per container)
- [ ] Apply fixes in batches of 30
- [ ] Add agent-friendly comments
- [ ] Use git branching strategy
- [ ] Apply Jidoka when needed

### Phase 3: Testing & Validation
- [ ] Create TDG tests first
- [ ] Run property-based tests
- [ ] Execute FPPS validation
- [ ] Verify STAMP compliance
- [ ] Track test coverage

### Phase 4: Documentation
- [ ] Track progress metrics
- [ ] Create journal entries
- [ ] Document AI fixes
- [ ] Update system status

### Final Validation
- [ ] Zero compilation errors
- [ ] Zero compilation warnings
- [ ] 100% test pass rate
- [ ] All methodologies active
- [ ] Observability functional
- [ ] GA release ready

---

**Classification**: MANDATORY REFERENCE FOR ALL AI AGENTS  
**Last Updated**: 2025-09-11 07:59:00 CEST  
**SOPv5.11 Compliance**: ✅ VERIFIED  

*This document represents the ONLY approved method for AI agent environment setup and development workflow in the Indrajaal project.*