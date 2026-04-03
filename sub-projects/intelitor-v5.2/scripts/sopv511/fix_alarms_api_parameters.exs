#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule AlarmsApiParameterFixer do
  @moduledoc """
  Fix remaining parameter scope errors in lib/indrajaal/alarms/api.ex
  """

  def main(args \\ []) do
    IO.puts("🔧 Fixing remaining parameter scope errors in alarms/api.ex")

    file_path = "lib/indrajaal/alarms/api.ex"

    case File.read(file_path) do
      {:ok, content} ->
        fixed_content = fix_parameter_errors(content)

        case File.write(file_path, fixed_content) do
          :ok ->
            IO.puts("✅ Successfully fixed parameter scope errors in #{file_path}")
          {:error, reason} ->
            IO.puts("❌ Failed to write file: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ Failed to read file: #{reason}")
    end
  end

  defp fix_parameter_errors(content) do
    content
    # Fix functions with _opts \\ [] pattern that reference __opts
    |> String.replace(~r/def (\w+)\(([^)]*), _opts \\\\ \[\]\) do/, "def \\1(\\2, __opts \\\\ []) do")
    # Fix functions with _params \\ [] pattern that reference __params
    |> String.replace(~r/def (\w+)\(_params, ([^)]*)\) do/, "def \\1(__params, \\2) do")
    # Fix any remaining _opts patterns that are used
    |> String.replace(~r/def (\w+)\(([^)]*), _opts\) do/, "def \\1(\\2, __opts) do")
    # Fix any remaining _params patterns that are used
    |> String.replace(~r/def (\w+)\(_params, ([^)]*)\) do/, "def \\1(__params, \\2) do")
  end
end

# Execute if run directly
AlarmsApiParameterFixer.main()