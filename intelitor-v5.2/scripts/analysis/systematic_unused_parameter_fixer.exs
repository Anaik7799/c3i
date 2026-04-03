#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SystematicUnusedParameterFixer do
  @moduledoc """
  SOPv5.11 Emergency Response: Systematic Unused Parameter Elimination

  Agent Assignment:
  - Executive_Director: Emergency intervention authorization
  - Domain_Supervisor_01_Sites: Access control parameter fixes
  - Domain_Supervisor_02_Accounts: Account management parameter fixes
  - Domain_Supervisor_03_Alarms: Alarm processing parameter fixes
  - Domain_Supervisor_04_Analytics: Analytics engine parameter fixes

  Mission: Eliminate ALL unused variable warnings using TPS Jidoka methodology
  """

  def main(args) do
    IO.puts("🚨 SOPv5.11 EMERGENCY RESPONSE: SYSTEMATIC PARAMETER ELIMINATION")
    IO.puts("Executive Director: INITIATING JIDOKA EMERGENCY INTERVENTION")
    IO.puts("Target: 4,718 unused parameter warnings")

    case args do
      ["--emergency"] -> execute_emergency_response()
      ["--emergency", "--batch-size", size] -> execute_emergency_response(String.to_integer(size))
      ["--analyze"] -> analyze_parameter_patterns()
      ["--validate"] -> validate_parameter_fixes()
      ["--preview"] -> preview_fixes()
      _ -> show_usage()
    end
  end

  def execute_emergency_response(batch_size \\ 100) do
    IO.puts("\n🔧 JIDOKA EMERGENCY RESPONSE INITIATED")
    IO.puts("Batch Size: #{batch_size} files per checkpoint")

    # Phase 1: Create emergency checkpoint
    create_emergency_checkpoint()

    # Phase 2: Get all Elixir files
    files = Path.wildcard("lib/**/*.ex")
    IO.puts("📁 Total files to process: #{length(files)}")

    # Phase 3: Process in batches with git checkpoints
    files
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index(1)
    |> Enum.each(fn {batch, batch_num} ->
      process_batch(batch, batch_num, length(files))
    end)

    IO.puts("\n✅ EMERGENCY RESPONSE COMPLETE")
    IO.puts("🎯 Running final compilation validation...")

    # Final validation
    validate_compilation_success()
  end

  defp create_emergency_checkpoint do
    IO.puts("\n📋 Creating emergency checkpoint...")
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")

    {__result, __} = System.cmd("git", ["add", "-A"])
    {_result2, _} = System.cmd("git", ["commit", "-m", "🚨 EMERGENCY CHECKPOINT: Pre-systematic-parameter-fix #{timestamp}"])

    IO.puts("✅ Emergency checkpoint created: #{timestamp}")
  end

  defp process_batch(files, batch_num, _total_files) do
    IO.puts("\n🔄 Processing Batch #{batch_num} (#{length(files)} files)")

    fixes_applied =
      Enum.reduce(files, 0, fn file, acc ->
        case apply_parameter_fixes(file) do
          {:ok, fix_count} when fix_count > 0 ->
            IO.puts("  ✅ #{file}: #{fix_count} parameters fixed")
            acc + fix_count
          {:ok, 0} ->
            # No fixes needed
            acc
          {:error, reason} ->
            IO.puts("  ❌ #{file}: Error - #{reason}")
            acc
        end
      end)

    # Create batch checkpoint
    _timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    {__, __} = System.cmd("git", ["add", "-A"])
    {__, __} = System.cmd("git", ["commit", "-m", "📦 Batch #{batch_num}: #{fixes_applied} parameter fixes applied"])

    IO.puts("📦 Batch #{batch_num} complete: #{fixes_applied} fixes applied")

    # Validate compilation after each batch
    validate_batch_compilation(batch_num)
  end

  defp apply_parameter_fixes(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        {_fixed_content, _fix_count} = apply_comprehensive_parameter_fixes(content)

        if fixed_content != content do
          case File.write(file_path, fixed_content) do
            :ok -> {:ok, fix_count}
            {:error, reason} -> {:error, reason}
          end
        else
          {:ok, 0}
        end

      {:error, reason} -> {:error, reason}
    end
  end

  defp apply_comprehensive_parameter_fixes(content) do
    fixes = [
      # Fix 1: Unused '__state' parameter (most common pattern)
      {~r/defp\s+([a-zA-Z_][a-zA-Z0-9_]*)\(([^)]*),\s*__state\)/, "defp \\1(\\2, _state)"},
      {~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\(([^)]*),\s*__state\)/, "def \\1(\\2, _state)"},

      # Fix 2: Unused '__params' parameter
      {~r/defp\s+([a-zA-Z_][a-zA-Z0-9_]*)\(([^)]*),\s*__params\)/, "defp \\1(\\2, _params)"},
      {~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\(([^)]*),\s*__params\)/, "def \\1(\\2, _params)"},

      # Fix 3: Unused '__opts' parameter
      {~r/defp\s+([a-zA-Z_][a-zA-Z0-9_]*)\(([^)]*),\s*__opts\)/, "defp \\1(\\2, _opts)"},
      {~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\(([^)]*),\s*__opts\)/, "def \\1(\\2, _opts)"},

      # Fix 4: Unused '__context' parameter
      {~r/defp\s+([a-zA-Z_][a-zA-Z0-9_]*)\(([^)]*),\s*__context\)/, "defp \\1(\\2, _context)"},
      {~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\(([^)]*),\s*__context\)/, "def \\1(\\2, _context)"},

      # Fix 5: Unused single parameter functions
      {~r/defp\s+([a-zA-Z_][a-zA-Z0-9_]*)\((__state|__params|__opts|__context)\)/, "defp \\1(_\\2)"},
      {~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\((__state|__params|__opts|__context)\)/, "def \\1(_\\2)"},

      # Fix 6: Common unused parameters in middle positions
      {~r/defp\s+([a-zA-Z_][a-zA-Z0-9_]*)\(([^,]+),\s*(__state|__params|__opts|__context),\s*([^)]+)\)/,
       "defp \\1(\\2, _\\3, \\4)"},
      {~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\(([^,]+),\s*(__state|__params|__opts|__context),\s*([^)]+)\)/,
       "def \\1(\\2, _\\3, \\4)"}
    ]

    {final_content, total_fixes} =
      Enum.reduce(fixes, {content, 0}, fn {pattern, replacement}, {current_content, fix_count} ->
        new_content = Regex.replace(pattern, current_content, replacement, global: true)
        fixes_in_this_pass = count_differences(current_content, new_content)
        {new_content, fix_count + fixes_in_this_pass}
      end)

    {final_content, total_fixes}
  end

  defp count_differences(original, modified) do
    original_lines = String.split(original, "\n")
    modified_lines = String.split(modified, "\n")

    Enum.zip(original_lines, modified_lines)
    |> Enum.count(fn {orig, mod} -> orig != mod end)
  end

  defp validate_batch_compilation(batch_num) do
    IO.puts("🔍 Validating batch #{batch_num} compilation...")

    case System.cmd("mix", ["compile"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Batch #{batch_num}: Compilation successful")
        :ok
      {output, _} ->
        IO.puts("⚠️  Batch #{batch_num}: Compilation warnings/errors detected")

        # Quick analysis of remaining issues
        warning_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "warning:"))
        error_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "error:"))

        IO.puts("   Remaining warnings: #{warning_count}")
        IO.puts("   Remaining errors: #{error_count}")

        if error_count > 0 do
          IO.puts("❌ CRITICAL: Compilation errors detected - Emergency intervention __required")
          :error
        else
          :warning
        end
    end
  end

  defp validate_compilation_success do
    IO.puts("\n🔍 FINAL COMPILATION VALIDATION")

    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("🏆 SUCCESS: Zero-warning compilation achieved!")
        IO.puts("✅ Emergency response mission accomplished")
        :success
      {output, _} ->
        IO.puts("❌ CRITICAL: Compilation still failing")

        # Save failure analysis
        timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
        failure_log = "./__data/tmp/emergency_response_failure_#{timestamp}.log"
        File.write!(failure_log, output)

        IO.puts("📋 Failure analysis saved: #{failure_log}")
        IO.puts("🚨 ESCALATION REQUIRED: Manual intervention needed")

        :failure
    end
  end

  def analyze_parameter_patterns do
    IO.puts("\n🔍 ANALYZING UNUSED PARAMETER PATTERNS")

    files = Path.wildcard("lib/**/*.ex")
    patterns = %{
      "__state" => 0,
      "__params" => 0,
      "__opts" => 0,
      "__context" => 0,
      "other" => 0
    }

    _total_patterns = Enum.reduce(files, _patterns, fn file, acc ->
      case File.read(file) do
        {:ok, content} ->
          analyze_file_patterns(content, acc)
        {:error, _} ->
          acc
      end
    end)

    IO.puts("📊 UNUSED PARAMETER PATTERN ANALYSIS:")
    Enum.each(total_patterns, fn {pattern, count} ->
      IO.puts("  #{pattern}: #{count} occurrences")
    end)

    total_count = Map.values(total_patterns) |> Enum.sum()
    IO.puts("📋 Total unused parameter patterns: #{total_count}")
  end

  defp analyze_file_patterns(content, patterns) do
    lines = String.split(content, "\n")

    Enum.reduce(lines, patterns, fn line, acc ->
      cond do
        String.contains?(line, "variable \"__state\" is unused") ->
          Map.update!(acc, "__state", &(&1 + 1))
        String.contains?(line, "variable \"__params\" is unused") ->
          Map.update!(acc, "__params", &(&1 + 1))
        String.contains?(line, "variable \"__opts\" is unused") ->
          Map.update!(acc, "__opts", &(&1 + 1))
        String.contains?(line, "variable \"__context\" is unused") ->
          Map.update!(acc, "__context", &(&1 + 1))
        String.contains?(line, "is unused") ->
          Map.update!(acc, "other", &(&1 + 1))
        true ->
          acc
      end
    end)
  end

  def preview_fixes do
    IO.puts("\n👁️  PREVIEWING PARAMETER FIXES (First 10 files)")

    files = Path.wildcard("lib/**/*.ex") |> Enum.take(10)

    Enum.each(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          {_fixed_content, _fix_count} = apply_comprehensive_parameter_fixes(content)

          if fix_count > 0 do
            IO.puts("📁 #{file}: #{fix_count} parameters would be fixed")

            # Show first few differences
            original_lines = String.split(content, "\n")
            fixed_lines = String.split(fixed_content, "\n")

            Enum.zip(original_lines, fixed_lines)
            |> Enum.with_index()
            |> Enum.filter(fn {{orig, fixed}, _idx} -> orig != fixed end)
            |> Enum.take(3)
            |> Enum.each(fn {{orig, fixed}, idx} ->
              IO.puts("  Line #{idx + 1}:")
              IO.puts("    - #{String.trim(orig)}")
              IO.puts("    + #{String.trim(fixed)}")
            end)
          end

        {:error, _} -> :ok
      end
    end)
  end

  def validate_parameter_fixes do
    IO.puts("\n🔍 VALIDATING CURRENT PARAMETER STATUS")

    # Run compilation and analyze results
    case System.cmd("mix", ["compile"], stderr_to_stdout: true) do
      {output, exit_code} ->
        lines = String.split(output, "\n")

        unused_warnings = Enum.filter(lines, &String.contains?(&1, "is unused"))
        error_lines = Enum.filter(lines, &String.contains?(&1, "error:"))

        IO.puts("📊 Current Status:")
        IO.puts("  Unused parameter warnings: #{length(unused_warnings)}")
        IO.puts("  Compilation errors: #{length(error_lines)}")
        IO.puts("  Exit code: #{exit_code}")

        if length(unused_warnings) > 0 do
          IO.puts("\n📋 Sample unused parameter warnings:")
          unused_warnings |> Enum.take(5) |> Enum.each(fn warning ->
            IO.puts("  • #{String.trim(warning)}")
          end)
        end

        if exit_code == 0 do
          IO.puts("✅ Compilation successful")
        else
          IO.puts("❌ Compilation failed")
        end
    end
  end

  def show_usage do
    IO.puts("""
    🚨 SOPv5.11 Emergency Response: Systematic Parameter Elimination

    Usage:
      elixir systematic_unused_parameter_fixer.exs --emergency                # Execute emergency response
      elixir systematic_unused_parameter_fixer.exs --emergency --batch-size 50  # Custom batch size
      elixir systematic_unused_parameter_fixer.exs --analyze                 # Analyze patterns
      elixir systematic_unused_parameter_fixer.exs --preview                 # Preview fixes
      elixir systematic_unused_parameter_fixer.exs --validate                # Validate current status

    Agent Assignment:
      Executive_Director: Emergency intervention authorization
      Domain_Supervisor_01: Access control parameter fixes
      Domain_Supervisor_02: Account management parameter fixes
      Domain_Supervisor_03: Alarm processing parameter fixes
      Domain_Supervisor_04: Analytics engine parameter fixes

    Mission: Complete elimination of ALL unused parameter warnings
    """)
  end
end

# Execute the emergency response
SystematicUnusedParameterFixer.main(System.argv())