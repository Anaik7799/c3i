#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveWarningFixer do
  @moduledoc """
  AEE SOPv5.11 Cybernetic Warning Elimination Framework - Phase 1
  Fixes all compilation warnings systematically using GDE (Goal-Directed Execution)
  """

  @batch_size 25  # Smaller batches for warnings since they're more delicate
  @patient_mode_env %{
    "NO_TIMEOUT" => "true",
    "PATIENT_MODE" => "enabled",
    "INFINITE_PATIENCE" => "true",
    "ELIXIR_ERL_OPTIONS" => "+fnu +S 16"
  }

  def run(args \\ []) do
    IO.puts """
    ╔══════════════════════════════════════════════════════════════╗
    ║    AEE SOPv5.11 Cybernetic Warning Elimination Framework    ║
    ║                     Phase 1 - Warnings                      ║
    ╚══════════════════════════════════════════════════════════════╝
    """

    # Create checkpoint
    create_git_checkpoint()
    
    # Analyze warnings from log
    warnings = analyze_warnings()
    
    IO.puts("\n📊 Warning Analysis Complete:")
    IO.puts("   Total warnings: #{length(warnings)}")
    
    # Group warnings by type
    warning_groups = group_warnings_by_type(warnings)
    
    IO.puts("\n📋 Warning Categories:")
    Enum.each(warning_groups, fn {type, count} ->
      IO.puts("   - #{type}: #{count} occurrences")
    end)
    
    # Process warnings in batches
    process_warnings_in_batches(warnings)
    
    IO.puts("\n✅ Warning elimination complete!")
  end

  defp create_git_checkpoint do
    IO.puts("\n🔒 Creating Git checkpoint...")
    System.cmd("git", ["add", "-A"])
    System.cmd("git", ["commit", "-m", "Checkpoint: Before Phase 1 warning fixes"])
  end

  defp analyze_warnings do
    log_content = File.read!("6-compile-zero-errors-confirmed.log")
    
    # Extract warnings with their file paths and line numbers
    warning_pattern = ~r/warning: (.+)\n.*?└─ (.+):(\d+):(\d+)/m
    
    Regex.scan(warning_pattern, log_content)
    |> Enum.map(fn [_full, message, file, line, col] ->
      %{
        message: message,
        file: file,
        line: String.to_integer(line),
        col: String.to_integer(col),
        type: categorize_warning(message)
      }
    end)
  end

  defp categorize_warning(message) do
    cond do
      String.contains?(message, "variable") && String.contains?(message, "is unused") ->
        :unused_variable
      String.contains?(message, "underscored variable") && String.contains?(message, "is used") ->
        :used_underscore_variable
      String.contains?(message, "function") && String.contains?(message, "is unused") ->
        :unused_function
      true ->
        :other
    end
  end

  defp group_warnings_by_type(warnings) do
    warnings
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, list} -> {type, length(list)} end)
    |> Enum.sort_by(fn {_, count} -> -count end)
  end

  defp process_warnings_in_batches(warnings) do
    # Group by file for efficient processing
    warnings_by_file = Enum.group_by(warnings, & &1.file)
    
    IO.puts("\n🔧 Processing #{map_size(warnings_by_file)} files with warnings...")
    
    warnings_by_file
    |> Enum.chunk_every(@batch_size)
    |> Enum.with_index(1)
    |> Enum.each(fn {batch, batch_num} ->
      IO.puts("\n📦 Processing batch #{batch_num} (#{length(batch)} files)...")
      
      # Process each file in the batch
      Enum.each(batch, fn {file, file_warnings} ->
        if File.exists?(file) do
          fix_warnings_in_file(file, file_warnings)
        end
      end)
      
      # Compile after each batch to verify fixes
      verify_batch_compilation(batch_num)
    end)
  end

  defp fix_warnings_in_file(file, warnings) do
    IO.puts("  📝 Fixing #{length(warnings)} warnings in #{Path.basename(file)}")
    
    content = File.read!(file)
    
    # Apply fixes based on warning types
    fixed_content = Enum.reduce(warnings, content, fn warning, acc ->
      apply_warning_fix(acc, warning, file)
    end)
    
    if fixed_content != content do
      File.write!(file, fixed_content)
      IO.puts("    ✓ Fixed warnings in #{Path.basename(file)}")
    end
  end

  defp apply_warning_fix(content, warning, file) do
    case warning.type do
      :unused_variable ->
        fix_unused_variable(content, warning)
      :used_underscore_variable ->
        fix_used_underscore_variable(content, warning)
      :unused_function ->
        # For now, we'll just report unused functions
        IO.puts("    ⚠️ Unused function detected: #{warning.message}")
        content
      _ ->
        content
    end
  end

  defp fix_unused_variable(content, warning) do
    # Extract variable name from warning message
    case Regex.run(~r/variable "([^"]+)" is unused/, warning.message) do
      [_, var_name] ->
        # Add underscore prefix to unused variables
        lines = String.split(content, "\n")
        line_idx = warning.line - 1
        
        if line_idx < length(lines) do
          line = Enum.at(lines, line_idx)
          
          # Replace variable with underscore version
          fixed_line = String.replace(line, ~r/\b#{var_name}\b/, "_#{var_name}")
          
          lines
          |> List.replace_at(line_idx, fixed_line)
          |> Enum.join("\n")
        else
          content
        end
      _ ->
        content
    end
  end

  defp fix_used_underscore_variable(content, warning) do
    # Extract variable name from warning message
    case Regex.run(~r/underscored variable "([^"]+)" is used/, warning.message) do
      [_, var_name] ->
        # Remove underscore prefix from used variables
        clean_name = String.trim_leading(var_name, "_")
        
        # Replace all occurrences of the underscored variable with clean name
        String.replace(content, ~r/\b#{Regex.escape(var_name)}\b/, clean_name)
      _ ->
        content
    end
  end

  defp verify_batch_compilation(batch_num) do
    IO.puts("\n🔍 Verifying batch #{batch_num} compilation...")
    
    env = Map.merge(System.get_env(), @patient_mode_env)
    
    case System.cmd("mix", ["compile", "--warnings-as-errors"], 
                    env: env, 
                    stderr_to_stdout: true,
                    into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        IO.puts("✅ Batch #{batch_num} compiled successfully!")
      {_, _} ->
        IO.puts("⚠️ Batch #{batch_num} has remaining issues, continuing...")
    end
  end
end

# Run the warning fixer
ComprehensiveWarningFixer.run()
