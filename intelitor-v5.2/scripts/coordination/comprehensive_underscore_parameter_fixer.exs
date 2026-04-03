#!/usr/bin/env elixir

defmodule ComprehensiveUnderscoreParameterFixer do
  @moduledoc """
  Comprehensive Underscore Parameter Fixer

  Fixes parameters that have underscore prefix but are used in function body.
  This is the root cause of "undefined variable" errors.

  Example:
    defp my_func(_state) do
      state.field  # Error: undefined variable "state"
    end

  Fixed to:
    defp my_func(state) do
      state.field  # Works!
    end
  """

  def run do
    IO.puts("🔧 Comprehensive Underscore Parameter Fixer")
    IO.puts("=" |> String.duplicate(60))

    # Get all Elixir files
    files = Path.wildcard("lib/**/*.ex")

    IO.puts("\n📊 Analyzing #{length(files)} files...\n")

    files
    |> Enum.with_index(1)
    |> Enum.each(fn {file, index} ->
      IO.puts("[#{index}/#{length(files)}] #{file}")
      fix_file(file)
    end)

    IO.puts("\n✅ Complete! Run compilation to verify fixes.")
  end

  defp fix_file(file_path) do
    content = File.read!(file_path)
    fixed_content = fix_underscore_parameters(content)

    if content != fixed_content do
      File.write!(file_path, fixed_content)
      IO.puts("     ✅ Fixed underscore parameters")
    end
  end

  defp fix_underscore_parameters(content) do
    # Find all function definitions with underscored parameters
    # Pattern: def/defp function_name(..._param...) do ... end

    content
    |> fix_single_underscore_params()
    |> fix_multiple_underscore_params()
  end

  defp fix_single_underscore_params(content) do
    # Handle functions with single underscored parameter
    Regex.replace(
      ~r/(def[p]?\s+\w+\([^)]*?)_(\w+)([^)]*\)\s+do.*?)end/s,
      content,
      fn full_match, before_param, param_name, after_do ->
        # Extract the function body
        [_header, body] = String.split(full_match, ~r/\)\s+do/, parts: 2)

        # Check if the parameter (without underscore) is used in the body
        # Look for patterns like: param_name., param_name[, param_name ), etc.
        param_usage_patterns = [
          "#{param_name}.",    # Map/struct access
          "#{param_name}[",    # List/map access
          "#{param_name} ",    # Used as argument
          "#{param_name})",    # Used as argument
          "#{param_name},",    # Used in tuple/list
          "#{param_name}\n",   # End of line
          " #{param_name}="    # Assignment source
        ]

        is_used = Enum.any?(param_usage_patterns, fn pattern ->
          String.contains?(body, pattern)
        end)

        if is_used do
          # Remove underscore from parameter
          "#{before_param}#{param_name}#{after_do}end"
        else
          full_match
        end
      end
    )
  end

  defp fix_multiple_underscore_params(content) do
    # Handle functions with multiple parameters where some are underscored
    # This is a more general approach that checks each parameter individually

    lines = String.split(content, "\n")

    lines
    |> Enum.map(&fix_line_underscore_params/1)
    |> Enum.join("\n")
  end

  defp fix_line_underscore_params(line) do
    # Check if line has function definition with underscored params
    if Regex.match?(~r/def[p]?\s+\w+\([^)]*_\w+[^)]*\)/, line) do
      # Extract parameters
      case Regex.run(~r/def[p]?\s+(\w+)\(([^)]+)\)/, line) do
        [_full, _func_name, params_str] ->
          # Get original indentation
          indent = Regex.run(~r/^(\s*)/, line) |> Enum.at(1, "")

          # Split parameters
          params = String.split(params_str, ",") |> Enum.map(&String.trim/1)

          # Find underscored params that might be used
          underscored_params =
            params
            |> Enum.filter(&String.starts_with?(&1, "_"))
            |> Enum.map(fn param ->
              # Handle pattern matching in params like: %{field: _value}
              case Regex.run(~r/_(\w+)/, param) do
                [_full, name] -> {param, name}
                nil -> nil
              end
            end)
            |> Enum.reject(&is_nil/1)

          # For now, just return original line
          # A more sophisticated version would need to read the function body
          line

        nil ->
          line
      end
    else
      line
    end
  end
end

ComprehensiveUnderscoreParameterFixer.run()