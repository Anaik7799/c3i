#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule UnderscoreUsedVarsFixer do
  def run do
    IO.puts("🔧 Fixing Underscored Variables Used After Being Set")
    IO.puts(String.duplicate("=", 60))

    warnings = extract_warnings()
    IO.puts("\nFound #{length(warnings)} underscored variable warnings\n")

    warnings
    |> Enum.group_by(& &1.file)
    |> Enum.each(fn {file, file_warnings} ->
      fix_file(file, file_warnings)
    end)

    IO.puts("\n✅ Complete!")
  end

  defp extract_warnings do
    File.read!("8-compile.log")
    |> String.split("\n")
    |> Enum.chunk_every(10, 1, :discard)
    |> Enum.filter(fn chunk ->
      Enum.any?(chunk, &String.contains?(&1, "underscored variable"))
    end)
    |> Enum.map(&parse_warning/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_warning(chunk) do
    warning_line = Enum.find(chunk, &String.contains?(&1, "underscored variable"))
    
    # Extract variable name from warning like: "the underscored variable "_attrs" is used"
    var_name = case Regex.run(~r/"(_\w+)"/, warning_line) do
      [_, name] -> name
      _ -> nil
    end

    # Find file path line
    file_line = Enum.find(chunk, &String.contains?(&1, ".ex:"))
    
    case {file_line, var_name} do
      {nil, _} -> nil
      {_, nil} -> nil
      {file_line, var_name} ->
        case Regex.run(~r/lib\/[^:]+\.ex/, file_line) do
          [file] ->
            # Get line number from chunk
            line = case Regex.run(~r/:(\d+):/, file_line) do
              [_, num] -> String.to_integer(num)
              _ -> 0
            end
            
            %{file: file, line: line, var_name: var_name}
          _ -> nil
        end
    end
  end

  defp fix_file(file, warnings) do
    IO.puts("📝 #{file}")
    
    content = File.read!(file)
    
    # Group by variable name
    vars_to_fix = warnings
    |> Enum.map(& &1.var_name)
    |> Enum.uniq()
    
    # For each variable, remove the leading underscore
    fixed_content = Enum.reduce(vars_to_fix, content, fn var_name, acc ->
      # Remove leading underscore: _attrs -> attrs
      new_name = String.slice(var_name, 1..-1//1)
      
      # Replace the underscored version with non-underscored
      # Only in parameter declarations and initial usage
      String.replace(acc, ~r/\b#{Regex.escape(var_name)}\b/, new_name)
    end)
    
    if fixed_content != content do
      File.write!(file, fixed_content)
      IO.puts("   ✓ Fixed #{length(vars_to_fix)} variables: #{Enum.join(vars_to_fix, ", ")}")
    end
  end
end

UnderscoreUsedVarsFixer.run()
