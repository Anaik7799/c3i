#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule EmergencyAshResourceSurgicalFix do
  @moduledoc """
  SOPv5.11 Emergency Surgical Fix for Critical Ash Resource Pattern Matching Error
  
  Agent Assignment:
  - Executive_Director: Emergency intervention authorization
  - Domain_Supervisor_01_Sites: Site domain expertise
  - Compilation_Supervisor_01: Pattern matching error resolution
  - Worker_01: Direct surgical file modification
  
  Mission: Eliminate ALL instances of invalid Ash Resource pattern matching syntax
  """

  def main(args) do
    IO.puts("🚨 SOPv5.11 EMERGENCY SURGICAL INTERVENTION INITIATED")
    IO.puts("Executive Director: CRITICAL COMPILATION ERROR - SURGICAL ELIMINATION REQUIRED")
    IO.puts("Target: ALL invalid Ash.Resource.Info.metadata pattern matching instances")
    
    case args do
      ["--analyze"] -> analyze_all_patterns()
      ["--fix"] -> apply_surgical_fix()
      ["--validate"] -> validate_surgical_results()
      _ -> show_usage()
    end
  end
  
  def analyze_all_patterns do
    IO.puts("\n🔍 EXECUTIVE DIRECTOR: COMPREHENSIVE ASH RESOURCE PATTERN ANALYSIS")
    
    # Search across ALL Elixir files for problematic patterns
    files = Path.wildcard("lib/**/*.ex")
    
    problematic_files = []
    
    Enum.each(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          # Look for various invalid patterns
          invalid_patterns = [
            ~r/Ash\.Resource\.Info\.metadata\([^)]+\)\s*=/,
            ~r/changeset\.resource\([^)]*\)\s*=/,
            ~r/[^=]\s*=\s*.*changeset\.resource\(\)/
          ]
          
          Enum.each(invalid_patterns, fn pattern ->
            case Regex.run(pattern, content) do
              nil -> :ok
              match ->
                IO.puts("❌ CRITICAL PATTERN FOUND in #{file}:")
                IO.puts("   Invalid Pattern: #{inspect(match)}")
                problematic_files = [file | problematic_files]
            end
          end)
          
        {:error, _} -> :ok
      end
    end)
    
    if length(problematic_files) > 0 do
      IO.puts("\n🚨 TOTAL PROBLEMATIC FILES: #{length(problematic_files)}")
    else
      IO.puts("\n✅ NO PROBLEMATIC PATTERNS FOUND IN SOURCE FILES")
      IO.puts("🔍 ERROR MAY BE IN GENERATED/COMPILED CODE - INVESTIGATING...")
      
      # Check for any mention of the error pattern
      {_output, __} = System.cmd("grep", ["-r", "changeset.resource", "lib/"], stderr_to_stdout: true)
      IO.puts("Grep results for changeset.resource:")
      IO.puts(output)
    end
  end
  
  def apply_surgical_fix do
    IO.puts("\n🔧 APPLYING SYSTEMATIC SURGICAL FIX...")
    
    # Apply comprehensive fixes across all files
    files = Path.wildcard("lib/**/*.ex")
    fixes_applied = 0
    
    Enum.each(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          fixed_content = apply_comprehensive_fixes(content)
          
          if fixed_content != content do
            case File.write(file, fixed_content) do
              :ok ->
                IO.puts("✅ SURGICAL FIX APPLIED: #{file}")
                fixes_applied = fixes_applied + 1
              {:error, reason} ->
                IO.puts("❌ FAILED TO APPLY FIX: #{file} - #{reason}")
            end
          end
          
        {:error, _} -> :ok
      end
    end)
    
    IO.puts("\n🏥 SURGICAL INTERVENTION COMPLETE")
    IO.puts("📊 Total fixes applied: #{fixes_applied}")
  end
  
  defp apply_comprehensive_fixes(content) do
    content
    # Fix 1: Invalid pattern matching with Ash.Resource.Info.metadata
    |> String.replace(
      ~r/Ash\.Resource\.Info\.metadata\(changeset\.resource\)\s*=\s*(.*)/,
      "resource = changeset.resource\n          metadata = Ash.Resource.Info.metadata(resource)\n          updated__metadata = \\1"
    )
    # Fix 2: Any other invalid changeset.resource patterns
    |> String.replace(
      ~r/(\s+)([^=\s]+)\s*=\s*.*changeset\.resource\(\)/,
      "\\1resource = changeset.resource\n\\1\\2 = process_resource_data(resource)"
    )
    # Fix 3: Direct changeset.resource access in match
    |> String.replace(
      ~r/([^=\s]+)\s*=\s*changeset\.resource\(\)/,
      "resource = changeset.resource\n          \\1 = resource"
    )
  end
  
  def validate_surgical_results do
    IO.puts("\n🔍 VALIDATING SURGICAL INTERVENTION RESULTS...")
    
    # Run patient mode compilation to verify
    {_output, _exit_code} = System.cmd("env", [
      "NO_TIMEOUT=true",
      "PATIENT_MODE=enabled",
      "INFINITE_PATIENCE=true", 
      "ELIXIR_ERL_OPTIONS=+fnu +S 16",
      "mix", "compile", "--verbose"
    ], stderr_to_stdout: true)
    
    case exit_code do
      0 ->
        IO.puts("✅ SURGICAL INTERVENTION SUCCESSFUL - COMPILATION RESTORED")
        IO.puts("🎯 Systematic warning elimination can now continue")
        analyze_remaining_warnings(output)
        
      _ ->
        IO.puts("❌ SURGICAL INTERVENTION REQUIRES ADDITIONAL ACTION")
        IO.puts("📋 Compilation output analysis:")
        analyze_compilation_errors(output)
    end
  end
  
  defp analyze_remaining_warnings(output) do
    warning_lines = String.split(output, "\n")
                   |> Enum.filter(&String.contains?(&1, "warning:"))
    
    IO.puts("\n📊 POST-SURGICAL WARNING ANALYSIS:")
    IO.puts("🔢 Remaining warnings: #{length(warning_lines)}")
    
    if length(warning_lines) > 0 do
      IO.puts("📋 Warning categories identified:")
      warning_lines 
      |> Enum.take(10)
      |> Enum.each(fn warning -> IO.puts("  • #{warning}") end)
      
      if length(warning_lines) > 10 do
        IO.puts("  ... and #{length(warning_lines) - 10} more warnings")
      end
    else
      IO.puts("🏆 ULTIMATE SUCCESS - ZERO WARNING COMPILATION ACHIEVED!")
    end
  end
  
  defp analyze_compilation_errors(output) do
    error_lines = String.split(output, "\n")
                 |> Enum.filter(fn line -> 
                   String.contains?(line, "error:") or 
                   String.contains?(line, "** (")
                 end)
    
    IO.puts("\n🚨 ERROR ANALYSIS:")
    IO.puts("🔢 Remaining errors: #{length(error_lines)}")
    
    Enum.each(error_lines, fn error -> 
      IO.puts("  ❌ #{error}")
    end)
    
    # If still changeset.resource error, escalate to executive director
    if Enum.any?(error_lines, &String.contains?(&1, "changeset.resource")) do
      IO.puts("\n🚨 EXECUTIVE DIRECTOR ESCALATION REQUIRED")
      IO.puts("Changeset.resource error persists - advanced intervention needed")
    end
  end
  
  def show_usage do
    IO.puts("""
    🏥 SOPv5.11 Emergency Surgical Intervention System
    
    Usage:
      elixir emergency_ash_resource_surgical_fix.exs --analyze   # Analyze all problematic patterns
      elixir emergency_ash_resource_surgical_fix.exs --fix      # Apply surgical fixes
      elixir emergency_ash_resource_surgical_fix.exs --validate # Validate intervention results
      
    Agent Assignment:
      Executive_Director: Emergency intervention authorization
      Domain_Supervisor_01_Sites: Site domain expertise
      Compilation_Supervisor_01: Pattern matching error resolution
      Worker_01: Direct surgical file modification
      
    Mission: Complete elimination of ALL invalid Ash Resource pattern matching
    """)
  end
end

# Execute the emergency surgical intervention
EmergencyAshResourceSurgicalFix.main(System.argv())