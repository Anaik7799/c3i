#!/usr/bin/env elixir

defmodule VisitorTestLineFixer do
  @moduledoc """
  Targeted script to fix line length violations in visitor_test.exs
  """

  @spec run() :: any()
  def run do
    file_path =
      "/home/an/dev/elixir/ash/intelitor/test/intelitor/visitor_management/visitor_test.exs"

    content = File.read!(file_path)

    fixed_content =
      content
      |> fix_long_assert_lines()
      |> fix_long_test_descriptions()
      |> fix_long_function_calls()

    File.write!(file_path, fixed_content)

    IO.puts("✅ Fixed line length violations in visitor_test.exs")
  end

  @spec fix_long_assert_lines(term()) :: term()
  defp fix_long_assert_lines(content) do
    content
    # Fix long assert lines with register_visitor calls
    |> String.replace(
      ~r/(\s+)assert \{:error, changeset\} = Visitor\.register_visitor\(([^,]+), actor: actor\)/,
      "\\1assert {:error, changeset} =\\n\\1         Visitor.register_visitor(\\2, actor: actor)"
    )
    |> String.replace(
      ~r/(\s+)assert \{:ok, ([^}]+)\} = Visitor\.register_visitor\(([^,]+), actor: actor\)/,
      "\\1assert {:ok, \\2} =\\n\\1         Visitor.register_visitor(\\3, actor: actor)"
    )
    # Fix long assert lines with error checks
    |> String.replace(
      ~r/(\s+)assert "([^"]+)" in errors_on\(changeset\)\.([a-zA-Z_]+)/,
      "\\1assert \"\\2\" in\\n\\1         errors_on(changeset).\\3"
    )
  end

  @spec fix_long_test_descriptions(term()) :: term()
  defp fix_long_test_descriptions(content) do
    content
    # Break long test descriptions
    |> String.replace(
      ~r/test "([^"]{50,})", %\{/,
      fn match ->
        [_, desc] = Regex.run(~r/test "([^"]+)", %\{/, match)

        if String.length(desc) > 50 do
          words = String.split(desc, " ")
          mid = div(length(words), 2)
          {first_half, second_half} = Enum.split(words, mid)
          first_line = Enum.join(first_half, " ")
          second_line = Enum.join(second_half, " ")
          "test \"#{first_line} \" <>\\n           \"#{second_line}\", %{"
        else
          match
        end
      end
    )
  end

  @spec fix_long_function_calls(term()) :: term()
  defp fix_long_function_calls(content) do
    content
    # Fix long function calls with multiple parameters
    |> String.replace(
      ~r/(\s+)([a-zA-Z_]+\.[a-zA-Z_]+)\(([^)]{60,})\)/,
      fn match ->
        [_, indent, func_call, params] =
          Regex.run(~r/(\s+)([a-zA-Z_]+\.[a-zA-Z_]+)\(([^)]+)\)/, match)

        if String.contains?(params, ",") and String.length(params) > 60 do
          param_list = String.split(params, ",")
          formatted_params = Enum.map_join(param_list, ",\\n#{indent}  ", &String
          "#{indent}#{func_call}(\\n#{indent}  #{formatted_params}\\n#{indent})"
        else
          match
        end
      end
    )
  end
end

VisitorTestLineFixer.run()
