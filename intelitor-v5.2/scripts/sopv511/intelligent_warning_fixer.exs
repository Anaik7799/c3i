#!/usr/bin/env elixir

defmodule IntelligentWarningFixer do
  @moduledoc """
  AEE SOPv5.11 Intelligent Warning Fixer
  Fixes unused variable warnings while preserving used variables
  """

  def run do
    IO.puts("\n🤖 AEE SOPv5.11 Intelligent Warning Fixer")
    IO.puts("=" <> String.duplicate("=", 79))
    
    # Parse the compilation log to understand warnings
    warnings = parse_warnings()
    IO.puts("📊 Found #{length(warnings)} warnings to analyze")
    
    # Group warnings by file
    grouped = Enum.group_by(warnings, & &1.file)
    
    # Fix each file
    for {file, file_warnings} <- grouped do
      fix_file(file, file_warnings)
    end
    
    IO.puts("\n✅ Intelligent warning fixes complete!")
  end
  
  defp parse_warnings do
    case File.read("7-compile-warnings.log") do
      {:ok, content} ->
        # Parse warnings with their context
        warning_regex = ~r/warning: (.+?)\n.*?│\n.*?│(.+?)│\n.*?│.*?(~+)\n.*?│\n.*?└─ (.+?):(\d+):(\d+)/m
        
        Regex.scan(warning_regex, content)
        |> Enum.map(fn [_, message, code_line, _, file, line, _col] ->
          %{
            message: message,
            code: String.trim(code_line),
            file: file,
            line: String.to_integer(line)
          }
        end)
      _ ->
        []
    end
  end
  
  defp fix_file(file, warnings) do
    if File.exists?(file) do
      IO.puts("\n📝 Analyzing #{file}")
      content = File.read!(file)
      lines = String.split(content, "\n")
      
      # Analyze each warning
      fixes = warnings
      |> Enum.map(&analyze_warning(&1, lines))
      |> Enum.filter(& &1)
      
      if Enum.empty?(fixes) do
        IO.puts("  ✓ No actionable fixes needed")
      else
        # Apply fixes
        fixed_lines = apply_fixes(lines, fixes)
        fixed_content = Enum.join(fixed_lines, "\n")
        
        File.write!(file, fixed_content)
        IO.puts("  ✅ Applied #{length(fixes)} intelligent fixes")
      end
    end
  end
  
  defp analyze_warning(warning, lines) do
    line_idx = warning.line - 1
    
    cond do
      # Case 1: variable is unused - safe to prefix with underscore
      String.contains?(warning.message, "variable") && 
      String.contains?(warning.message, "is unused") &&
      String.contains?(warning.message, "prefix it with an underscore") ->
        
        # Extract variable name
        case Regex.run(~r/variable "([^"]+)"/, warning.message) do
          [_, var_name] ->
            # Check if it's truly unused in the function body
            if is_truly_unused?(var_name, lines, line_idx) do
              %{type: :add_underscore, line: warning.line, var: var_name}
            else
              nil
            end
          _ -> nil
        end
        
      # Case 2: underscored variable is used - remove underscore
      String.contains?(warning.message, "underscored variable") && 
      String.contains?(warning.message, "is used after being set") ->
        
        # Extract variable name
        case Regex.run(~r/variable "([^"]+)"/, warning.message) do
          [_, var_name] ->
            %{type: :remove_underscore, line: warning.line, var: var_name}
          _ -> nil
        end
        
      true ->
        nil
    end
  end
  
  defp is_truly_unused?(var_name, lines, def_line_idx) do
    # Find the function body (everything after the def line until the next def/defp or end)
    function_body = extract_function_body(lines, def_line_idx)
    
    # Check if the variable is referenced in the function body
    # (excluding the definition line itself)
    !Enum.any?(function_body, fn line ->
      # Look for uses of the variable (not as a parameter definition)
      String.contains?(line, var_name) &&
      !String.match?(line, ~r/def(p)?\s+\w+.*#{Regex.escape(var_name)}/)
    end)
  end
  
  defp extract_function_body(lines, start_idx) do
    # Get lines from the function definition onwards
    lines
    |> Enum.drop(start_idx + 1)
    |> Enum.take_while(fn line ->
      # Stop at the next function or module end
      !String.match?(line, ~r/^\s*(def(p)?|end)\s/)
    end)
  end
  
  defp apply_fixes(lines, fixes) do
    # Sort fixes by line number (descending) to avoid index shifts
    sorted_fixes = Enum.sort_by(fixes, & &1.line, :desc)
    
    Enum.reduce(sorted_fixes, lines, fn fix, acc ->
      line_idx = fix.line - 1
      line = Enum.at(acc, line_idx)
      
      fixed_line = case fix.type do
        :add_underscore ->
          # Add underscore to unused variable
          String.replace(line, ~r/\b#{Regex.escape(fix.var)}\b/, "_#{fix.var}")
          
        :remove_underscore ->
          # Remove underscore from used variable
          String.replace(line, "_#{fix.var}", fix.var)
      end
      
      List.replace_at(acc, line_idx, fixed_line)
    end)
  end
end

# Run the fixer
IntelligentWarningFixer.run()
