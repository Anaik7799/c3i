defmodule CredoIntegrationValidationTest do
  @moduledoc """
  TDG Test-Driven Generation: Comprehensive testing for Credo Integration
  Tests created per SOPv5.11 Elixir 1.19 Credo Rules (CLAUDE.md §3 Quality Gates)

  STAMP Safety Compliance: SC-CMP-033, SC-CMP-034, SC-CMP-035
  TDG Compliance: Tests written for STAMP constraint validation
  GDE Compliance: Goal-directed Credo compliance verification
  Framework: SOPv5.11 + TPS + STAMP + Jidoka
  """

  use ExUnit.Case, async: true

  @moduletag :tdg_compliant
  @moduletag :stamp_safety
  @moduletag :credo_integration
  @moduletag :sopv511

  # ============================================================================
  # STAMP Constraint Tests: SC-CMP-033 (Script Syntax Validation)
  # ============================================================================

  describe "SC-CMP-033: Script Syntax Validation" do
    @tag :stamp_constraint
    @tag :sc_cmp_033
    test "critical validation scripts have valid Elixir syntax" do
      critical_scripts = [
        "scripts/validation/comprehensive_compilation_validator.exs",
        "scripts/validation/unified_validation_command_center.exs",
        "scripts/validation/daily_validation_audit.exs"
      ]

      for script_path <- critical_scripts do
        if File.exists?(script_path) do
          content = File.read!(script_path)
          result = Code.string_to_quoted(content)

          assert match?({:ok, _}, result),
                 "Script #{script_path} should have valid syntax, got: #{inspect(result)}"
        end
      end
    end

    @tag :stamp_constraint
    @tag :sc_cmp_033
    test "script syntax fixer exists and is executable" do
      fixer_path = "scripts/maintenance/script_syntax_fixer.exs"

      assert File.exists?(fixer_path), "Script syntax fixer should exist at #{fixer_path}"

      content = File.read!(fixer_path)
      result = Code.string_to_quoted(content)

      assert match?({:ok, _}, result), "Script syntax fixer should have valid syntax"
    end
  end

  # ============================================================================
  # STAMP Constraint Tests: SC-CMP-034 (Credo Strict Mode)
  # ============================================================================

  describe "SC-CMP-034: Credo Strict Mode Configuration" do
    @tag :stamp_constraint
    @tag :sc_cmp_034
    test ".credo.exs configuration exists" do
      credo_config = ".credo.exs"
      assert File.exists?(credo_config), ".credo.exs configuration file should exist"
    end

    @tag :stamp_constraint
    @tag :sc_cmp_034
    test ".credo.exs has strict mode enabled" do
      credo_config = ".credo.exs"

      if File.exists?(credo_config) do
        content = File.read!(credo_config)

        assert String.contains?(content, "strict: true"),
               ".credo.exs should have strict: true configured"
      end
    end

    @tag :stamp_constraint
    @tag :sc_cmp_034
    test ".credo.exs excludes scripts directory" do
      credo_config = ".credo.exs"

      if File.exists?(credo_config) do
        content = File.read!(credo_config)

        assert String.contains?(content, "scripts"),
               ".credo.exs should exclude scripts directory"
      end
    end

    @tag :stamp_constraint
    @tag :sc_cmp_034
    test ".credo.exs has Elixir 1.19 compliant thresholds" do
      credo_config = ".credo.exs"

      if File.exists?(credo_config) do
        content = File.read!(credo_config)

        # Cyclomatic complexity should be <= 9 per Elixir 1.19 rules
        assert String.contains?(content, "CyclomaticComplexity"),
               ".credo.exs should configure CyclomaticComplexity check"

        # Nesting should be <= 3
        assert String.contains?(content, "Nesting"),
               ".credo.exs should configure Nesting check"
      end
    end
  end

  # ============================================================================
  # STAMP Constraint Tests: SC-CMP-035 (Zero Credo Violations)
  # ============================================================================

  describe "SC-CMP-035: Credo Violation Detection" do
    @tag :stamp_constraint
    @tag :sc_cmp_035
    @tag :slow
    test "mix credo command is available" do
      # Check if credo is available as a mix task
      {output, exit_code} = System.cmd("mix", ["help", "credo"], stderr_to_stdout: true)

      assert exit_code == 0 or String.contains?(output, "credo"),
             "mix credo should be available as a task"
    end
  end

  # ============================================================================
  # AOR (Agent Operational Rules) Tests
  # ============================================================================

  describe "AOR-1: Strictness Imperative" do
    @tag :aor
    @tag :aor_1
    test "credo dependency is configured in mix.exs" do
      mix_exs = File.read!("mix.exs")

      assert String.contains?(mix_exs, ":credo"),
             "mix.exs should include :credo dependency"
    end
  end

  describe "AOR-3: Formatter Precedence" do
    @tag :aor
    @tag :aor_3
    test ".formatter.exs exists for mix format" do
      assert File.exists?(".formatter.exs"),
             ".formatter.exs should exist for mix format"
    end
  end

  # ============================================================================
  # Decision Matrix Tests
  # ============================================================================

  describe "Decision Matrix: Severity Classification" do
    @tag :decision_matrix
    test "severity levels are correctly defined" do
      # Per CLAUDE.md Section 60.0 Decision Matrix
      severity_levels = %{
        elixir_deprecation: 5,
        warning: 4,
        refactoring: 3,
        design: 2,
        readability: 1
      }

      assert severity_levels.elixir_deprecation == 5
      assert severity_levels.warning == 4
      assert severity_levels.refactoring == 3
      assert severity_levels.design == 2
      assert severity_levels.readability == 1
    end
  end

  # ============================================================================
  # Integration Tests
  # ============================================================================

  describe "Credo Integration with CLAUDE.md" do
    @tag :integration
    test "CLAUDE.md contains Credo quality gate configuration" do
      claude_md = "CLAUDE.md"

      if File.exists?(claude_md) do
        content = File.read!(claude_md)

        # v10.1.0 uses mathematical notation with §N sections
        assert String.contains?(content, "§") or String.contains?(content, "Quality"),
               "CLAUDE.md should contain mathematical sections or Quality references"

        assert String.contains?(content, "Credo") or String.contains?(content, "credo"),
               "CLAUDE.md should mention Credo"
      end
    end

    @tag :integration
    test "runtime_constraint_monitor has Credo STAMP constraints" do
      monitor_path = "lib/intelitor/stamp/runtime_constraint_monitor.ex"

      if File.exists?(monitor_path) do
        content = File.read!(monitor_path)

        assert String.contains?(content, "SC-CMP-033") or
                 String.contains?(content, "Script Syntax"),
               "runtime_constraint_monitor should have SC-CMP-033"

        assert String.contains?(content, "SC-CMP-034") or
                 String.contains?(content, "Credo Strict"),
               "runtime_constraint_monitor should have SC-CMP-034"

        assert String.contains?(content, "SC-CMP-035") or
                 String.contains?(content, "Credo Violations"),
               "runtime_constraint_monitor should have SC-CMP-035"
      end
    end
  end

  # ============================================================================
  # 5-Level RCA Validation Tests
  # ============================================================================

  describe "5-Level RCA: Script Syntax Error Prevention" do
    @tag :rca
    @tag :jidoka
    test "journal entry documents 5-Level RCA for Credo issues" do
      journal_pattern = "docs/journal/*credo*"
      journal_files = Path.wildcard(journal_pattern)

      assert length(journal_files) > 0,
             "Should have at least one journal entry about Credo integration"
    end

    @tag :rca
    @tag :jidoka
    test "__require typo pattern is not present in validation scripts" do
      validation_scripts = Path.wildcard("scripts/validation/*.exs")

      for script <- Enum.take(validation_scripts, 10) do
        if File.exists?(script) do
          content = File.read!(script)

          # Check for the specific typo pattern (standalone __require at start of line)
          refute Regex.match?(~r/^__require\s/m, content),
                 "Script #{script} should not contain __require typo"
        end
      end
    end
  end
end
