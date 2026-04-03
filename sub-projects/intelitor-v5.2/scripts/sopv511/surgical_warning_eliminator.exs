#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SurgicalWarningEliminator do
  @moduledoc """
  SOPv5.11 Surgical Warning Eliminator
  
  Applies systematic surgical precision to eliminate unused variable warnings
  using TPS Jidoka stop-and-fix methodology with 5-Level RCA analysis.
  
  Agent: SOPv5.11 Cybernetic Warning Elimination System
  """

  def main(args) do
    case args do
      ["--execute"] -> execute_surgical_elimination()
      ["--analyze"] -> analyze_warnings()
      _ -> show_help()
    end
  end

  defp show_help do
    IO.puts """
    SOPv5.11 Surgical Warning Eliminator
    
    Usage:
      --execute    Apply systematic surgical warning elimination
      --analyze    Analyze warning patterns for strategic approach
    """
  end

  defp analyze_warnings do
    IO.puts "🔍 SOPv5.11 WARNING PATTERN ANALYSIS"
    IO.puts "======================================"

    # Run compilation to get current warnings
    {output, _exit_code} = System.cmd("mix", ["compile"], stderr_to_stdout: true)

    warnings = extract_warnings(output)
    
    IO.puts "📊 Warning Analysis:"
    IO.puts "  Total Warnings: #{length(warnings)}"
    
    # Analyze patterns
    pattern_analysis = analyze_warning_patterns(warnings)
    
    Enum.each(pattern_analysis, fn {pattern, count} ->
      IO.puts "  #{pattern}: #{count} occurrences"
    end)
    
    # Identify surgical targets
    surgical_targets = identify_surgical_targets(warnings)
    
    IO.puts "\n🎯 Surgical Elimination Targets:"
    Enum.each(surgical_targets, fn {file, count} ->
      IO.puts "  #{file}: #{count} warnings"
    end)
  end

  defp execute_surgical_elimination do
    IO.puts """
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  SOPv5.11 SURGICAL WARNING ELIMINATION                             ║
    ║  🎯 TPS Jidoka: Stop-and-Fix with 5-Level RCA                      ║
    ║  🔧 Surgical Precision: Targeted unused variable elimination       ║
    ╚═════════════════════════════════════════════════════════════════════╝
    """

    # Get current warnings
    IO.puts "📸 Capturing current warning state..."
    {output, _exit_code} = System.cmd("mix", ["compile"], stderr_to_stdout: true)
    warnings = extract_warnings(output)
    
    IO.puts "📊 Current warnings: #{length(warnings)}"
    
    # Apply systematic fixes
    IO.puts "🔧 Applying systematic surgical fixes..."
    
    results = %{
      fixed: 0,
      skipped: 0,
      errors: []
    }
    
    results = apply_unused_state_fixes(warnings, results)
    results = apply_unused_params_fixes(warnings, results)

    # Validation
    IO.puts "🧪 Validating surgical fixes..."
    {validation_output, validation_exit_code} = System.cmd("mix", ["compile"], stderr_to_stdout: true)

    final_warnings = extract_warnings(validation_output)
    
    IO.puts """
    
    ✅ SURGICAL ELIMINATION COMPLETE
    ================================
    📊 Results:
      • Fixed: #{results.fixed} warnings
      • Skipped: #{results.skipped} warnings  
      • Errors: #{length(results.errors)} issues
      • Final warnings: #{length(final_warnings)}
      • Reduction: #{length(warnings) - length(final_warnings)} warnings eliminated
    """
    
    if validation_exit_code == 0 do
      IO.puts "🎉 SUCCESS: Compilation successful with surgical precision!"
    else
      IO.puts "⚠️  Note: Some warnings remain for further analysis"
    end
  end

  defp extract_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "warning:"))
    |> Enum.map(&parse_warning/1)
    |> Enum.filter(& &1)
  end

  defp parse_warning(line) do
    cond do
      line =~ ~r/variable "_(\w+)" is unused/ ->
        [_, var_name] = Regex.run(~r/variable "_(\w+)" is unused/, line)
        %{type: :unused_variable, variable: var_name, line: line}
      
      line =~ ~r/underscored variable "_(\w+)" is used/ ->
        [_, var_name] = Regex.run(~r/underscored variable "_(\w+)" is used/, line)
        %{type: :underscore_misuse, variable: var_name, line: line}
      
      true ->
        %{type: :other, line: line}
    end
  end

  defp analyze_warning_patterns(warnings) do
    warnings
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, warns} -> {type, length(warns)} end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  defp identify_surgical_targets(warnings) do
    warnings
    |> Enum.map(&extract_file_from_warning/1)
    |> Enum.filter(& &1)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(10)
  end

  defp extract_file_from_warning(%{line: line}) do
    case Regex.run(~r/└─ (.+?):\d+:\d+:/, line) do
      [_, file_path] -> file_path
      _ -> nil
    end
  end

  defp apply_unused_state_fixes(warnings, results) do
    state_warnings = Enum.filter(warnings, fn w ->
      w.type == :unused_variable and w.variable == "__state"
    end)

    IO.puts "🎯 Targeting #{length(state_warnings)} unused '__state' parameters..."

    Enum.reduce(state_warnings, results, fn warning, acc ->
      case fix_unused_state(warning) do
        :ok -> 
          %{acc | fixed: acc.fixed + 1}
        :skip -> 
          %{acc | skipped: acc.skipped + 1}
        {:error, reason} -> 
          %{acc | errors: [reason | acc.errors]}
      end
    end)
  end

  defp apply_unused_params_fixes(warnings, results) do
    params_warnings = Enum.filter(warnings, fn w ->
      w.type == :unused_variable and w.variable == "__params"
    end)

    IO.puts "🎯 Targeting #{length(params_warnings)} unused '__params' parameters..."

    Enum.reduce(params_warnings, results, fn warning, acc ->
      case fix_unused_params(warning) do
        :ok -> 
          %{acc | fixed: acc.fixed + 1}
        :skip -> 
          %{acc | skipped: acc.skipped + 1}
        {:error, reason} -> 
          %{acc | errors: [reason | acc.errors]}
      end
    end)
  end

  defp fix_unused_state(%{line: line}) do
    case extract_file_and_line(line) do
      {file_path, line_number} ->
        apply_surgical_state_fix(file_path, line_number)
      _ ->
        {:error, "Could not extract file info from: #{line}"}
    end
  end

  defp fix_unused_params(%{line: line}) do
    case extract_file_and_line(line) do
      {file_path, line_number} ->
        apply_surgical_params_fix(file_path, line_number)
      _ ->
        {:error, "Could not extract file info from: #{line}"}
    end
  end

  defp extract_file_and_line(warning_line) do
    case Regex.run(~r/└─ (.+?):(\d+):\d+:/, warning_line) do
      [_, file_path, line_num] -> 
        {file_path, String.to_integer(line_num)}
      _ -> 
        nil
    end
  end

  defp apply_surgical_state_fix(file_path, line_number) do
    try do
      if File.exists?(file_path) do
        content = File.read!(file_path)
        lines = String.split(content, "\n")
        
        if line_number <= length(lines) do
          target_line = Enum.at(lines, line_number - 1)
          
          # Apply surgical fix: __state -> _state
          if target_line =~ ~r/\b__state\b/ and not (target_line =~ ~r/_state/) do
            fixed_line = String.replace(target_line, ~r/\b__state\b/, "_state")
            
            new_lines = List.replace_at(lines, line_number - 1, fixed_line)
            new_content = Enum.join(new_lines, "\n")
            
            File.write!(file_path, new_content)
            :ok
          else
            :skip
          end
        else
          {:error, "Line number #{line_number} out of range in #{file_path}"}
        end
      else
        {:error, "File not found: #{file_path}"}
      end
    rescue
      e -> {:error, "Error processing #{file_path}: #{inspect(e)}"}
    end
  end

  defp apply_surgical_params_fix(file_path, line_number) do
    try do
      if File.exists?(file_path) do
        content = File.read!(file_path)
        lines = String.split(content, "\n")
        
        if line_number <= length(lines) do
          target_line = Enum.at(lines, line_number - 1)
          
          # Apply surgical fix: __params -> _params
          if target_line =~ ~r/\b__params\b/ and not (target_line =~ ~r/_params/) do
            fixed_line = String.replace(target_line, ~r/\b__params\b/, "_params")
            
            new_lines = List.replace_at(lines, line_number - 1, fixed_line)
            new_content = Enum.join(new_lines, "\n")
            
            File.write!(file_path, new_content)
            :ok
          else
            :skip
          end
        else
          {:error, "Line number #{line_number} out of range in #{file_path}"}
        end
      else
        {:error, "File not found: #{file_path}"}
      end
    rescue
      e -> {:error, "Error processing #{file_path}: #{inspect(e)}"}
    end
  end
end

SurgicalWarningEliminator.main(System.argv())