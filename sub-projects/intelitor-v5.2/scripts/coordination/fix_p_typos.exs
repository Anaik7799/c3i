#!/usr/bin/env elixir

defmodule PTypoFixer do
  def run do
    file_path = "/home/an/dev/indrajaal-demo/lib/indrajaal/coordination/agent_manager.ex"
    content = File.read!(file_path)
    lines = String.split(content, "\n")

    # Find all 'p ' typos with their line numbers
    p_typos = lines
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.match?(line, ~r/^  p /) end)
    |> Enum.map(fn {line, line_num} -> {line_num, line} end)

    IO.puts("Found #{length(p_typos)} 'p' typos to fix")

    # For each typo, find its @spec and extract parameters
    fixed_lines = Enum.reduce(p_typos, lines, fn {line_num, _line}, acc_lines ->
      spec_line_num = find_spec_line(acc_lines, line_num)

      if spec_line_num do
        params = extract_params_from_spec(acc_lines, spec_line_num)
        function_name = extract_function_name(Enum.at(acc_lines, line_num - 1))

        IO.puts("Fixing line #{line_num}: #{function_name} with params: #{inspect(params)}")

        new_line = "  defp #{function_name}(#{Enum.join(params, ", ")}) do"
        List.replace_at(acc_lines, line_num - 1, new_line)
      else
        acc_lines
      end
    end)

    File.write!(file_path, Enum.join(fixed_lines, "\n"))
    IO.puts("\n✅ Fixed all 'p' typos!")
  end

  defp find_spec_line(lines, current_line) do
    # Look backwards for @spec
    Enum.find(current_line - 1..max(0, current_line - 5), fn idx ->
      line = Enum.at(lines, idx - 1) || ""
      String.contains?(line, "@spec")
    end)
  end

  defp extract_params_from_spec(lines, spec_line_num) do
    spec_line = Enum.at(lines, spec_line_num - 1) || ""

    # Extract parameter types from @spec
    # Format: @spec function_name(type1, type2, type3) :: return
    case Regex.run(~r/@spec\s+\w+\((.*?)\)/, spec_line) do
      [_, params_str] ->
        params_str
        |> String.split(",")
        |> Enum.with_index()
        |> Enum.map(fn {param_type, idx} ->
          param_type = String.trim(param_type)

          cond do
            String.contains?(param_type, "agent_type") -> "type"
            String.contains?(param_type, "integer") -> if idx == 1, do: "target_count", else: "count"
            String.contains?(param_type, "String.t") -> case idx do
              0 -> "agent_id"
              1 -> "reason"
              _ -> "string_param"
            end
            String.contains?(param_type, "map") -> "config"
            String.contains?(param_type, "%__MODULE__") -> "state"
            String.contains?(param_type, "atom") -> "status"
            true -> "param#{idx}"
          end
        end)

      _ ->
        ["state"]  # Default fallback
    end
  end

  defp extract_function_name(line) do
    case Regex.run(~r/p\s+(\w+)\(/, line) do
      [_, name] -> name
      _ -> "unknown"
    end
  end
end

PTypoFixer.run()