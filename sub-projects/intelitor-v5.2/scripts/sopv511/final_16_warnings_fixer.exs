#!/usr/bin/env elixir

defmodule SOPv511.Final16WarningsFixer do
  @moduledoc """
  SOPv5.11 Final 16 Warnings Fixer
  
  ACHIEVEMENT: 99.8% warning reduction (9,079 → 16)
  TARGET: Fix the final 16 warnings to achieve ZERO warnings
  
  Final warnings to fix:
  - 11 unused variables (need underscore prefix)
  - 3 underscored variables that are used (remove underscore)
  - 2 other pattern warnings
  """
  
  def fix_final_warnings do
    IO.puts """
    ╔════════════════════════════════════════════════════════════════════════╗
    ║   SOPv5.11 FINAL 16 WARNINGS ELIMINATION                              ║
    ╠════════════════════════════════════════════════════════════════════════╣
    ║   🏆 ACHIEVEMENT: 99.8% reduction (9,079 → 16)                         ║
    ║   🎯 FINAL TARGET: Achieve ZERO warnings                               ║
    ║   📊 Remaining: 16 warnings (11 unused, 3 underscore misuse, 2 other)  ║
    ╚════════════════════════════════════════════════════════════════════════╝
    """
    
    # Create git checkpoint
    IO.puts "\n📸 Creating final checkpoint before last fixes..."
    System.cmd("git", ["add", "-A"])
    System.cmd("git", ["commit", "-m", "🎯 Final checkpoint: 16 warnings remaining"])
    
    # Find files with warnings by analyzing compilation output
    IO.puts "\n🔍 Analyzing final 16 warnings..."
    {_output, __} = System.cmd("mix", ["compile", "--force"], 
      stderr_to_stdout: true,
      env: [{"ELIXIR_ERL_OPTIONS", "+S 16"}]
    )
    
    warnings = parse_warnings(output)
    
    IO.puts "📊 Found warnings in #{length(warnings)} locations"
    
    # Group warnings by file
    warnings_by_file = Enum.group_by(warnings, & &1.file)
    
    # Fix each file
    Enum.each(warnings_by_file, fn {file, file_warnings} ->
      IO.puts "\n🔧 Fixing #{length(file_warnings)} warnings in #{Path.basename(file)}..."
      fix_warnings_in_file(file, file_warnings)
    end)
    
    # Validate fixes
    IO.puts "\n🧪 Validating fixes..."
    {_final_output, __} = System.cmd("mix", ["compile", "--force"], 
      stderr_to_stdout: true,
      env: [{"ELIXIR_ERL_OPTIONS", "+S 16"}]
    )
    
    final_warning_count = length(Regex.scan(~r/warning:/, final_output))
    
    if final_warning_count == 0 do
      IO.puts """
      
      ╔════════════════════════════════════════════════════════════════════════╗
      ║   🏆 SUCCESS! ZERO WARNINGS ACHIEVED!                                  ║
      ╠════════════════════════════════════════════════════════════════════════╣
      ║   📊 Journey: 9,079 → 2,107 → 16 → 0 warnings                         ║
      ║   ⚡ Reduction: 100% - Complete elimination!                           ║
      ║   🎯 SOPv5.11: Mission accomplished with excellence                    ║
      ╚════════════════════════════════════════════════════════════════════════╝
      """
      
      # Commit success
      System.cmd("git", ["add", "-A"])
      System.cmd("git", ["commit", "-m", "🏆 ZERO WARNINGS ACHIEVED! Complete elimination of all 9,079 warnings"])
    else
      IO.puts """
      
      ⚠️  Still #{final_warning_count} warnings remaining. Details:
      """
      
      # Show remaining warnings
      final_output
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, "warning:"))
      |> Enum.each(&IO.puts/1)
    end
  end
  
  defp parse_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "warning:"))
    |> Enum.map(&parse_warning_line/1)
    |> Enum.reject(&is_nil/1)
  end
  
  defp parse_warning_line(line) do
    cond do
      String.contains?(line, "variable") && String.contains?(line, "is unused") ->
        case Regex.run(~r/(.+?):(\d+):\d+: warning: variable "_(.+?)" is unused/, line) do
          [_, file, line_num, var] ->
            %{
              file: file,
              line: String.to_integer(line_num),
              type: :unused_variable,
              variable: var
            }
          _ -> nil
        end
        
      String.contains?(line, "underscored variable") && String.contains?(line, "is used") ->
        case Regex.run(~r/(.+?):(\d+):\d+: warning: the underscored variable "(.+?)" is used/, line) do
          [_, file, line_num, var] ->
            %{
              file: file,
              line: String.to_integer(line_num),
              type: :underscored_misuse,
              variable: var
            }
          _ -> nil
        end
        
      true -> nil
    end
  end
  
  defp fix_warnings_in_file(file_path, warnings) do
    if File.exists?(file_path) do
      content = File.read!(file_path)
      lines = String.split(content, "\n")
      
      # Apply fixes to each warning
      _new_lines = Enum.reduce(warnings, _lines, fn warning, acc_lines ->
        fix_specific_warning(acc_lines, warning)
      end)
      
      new_content = Enum.join(new_lines, "\n")
      
      if content != new_content do
        File.write!(file_path, new_content)
        IO.puts "   ✅ Fixed #{length(warnings)} warnings"
      end
    end
  end
  
  defp fix_specific_warning(lines, %{line: line_num, type: :unused_variable, variable: var}) do
    # Get the line (0-indexed)
    idx = line_num - 1
    
    if idx >= 0 and idx < length(lines) do
      line = Enum.at(lines, idx)
      
      # Add underscore to unused variable
      new_line = String.replace(line, ~r/\b#{Regex.escape(var)}\b/, "_#{var}")
      
      List.replace_at(lines, idx, new_line)
    else
      lines
    end
  end
  
  defp fix_specific_warning(lines, %{line: line_num, type: :underscored_misuse, variable: var}) do
    # Get the line (0-indexed)
    idx = line_num - 1
    
    if idx >= 0 and idx < length(lines) do
      line = Enum.at(lines, idx)
      
      # Remove underscore from used variable
      clean_var = String.replace_prefix(var, "_", "")
      new_line = String.replace(line, var, clean_var)
      
      List.replace_at(lines, idx, new_line)
    else
      lines
    end
  end
end

# Execute final warning fixes
SOPv511.Final16WarningsFixer.fix_final_warnings()