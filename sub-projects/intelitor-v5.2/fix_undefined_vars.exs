#!/usr/bin/env elixir

defmodule UndefinedVariableFixer do
  def fix_file(file_path) do
    content = File.read!(file_path)

    fixed_content =
      content
      # Fix common patterns where parameter is _param but used as param
      |> String.replace(
        ~r/def\s+(\w+)\(([^)]*),\s*_opts\s*\)\s+do\s+\n\s+GenServer\.start_link\(__MODULE__,\s+_opts,/,
        "def \\1(\\2, opts) do\n    GenServer.start_link(__MODULE__, opts,"
      )
      |> String.replace(
        ~r/def\s+(\w+)\([^)]*,\s*_state\)\s+do(.*?)(?=\n\s*def|\nend|\z)/s,
        fn match ->
          String.replace(match, "state", "state")
          |> String.replace("_state)", "state)")
          |> String.replace("_state ", "state ")
        end
      )
      |> String.replace(
        ~r/defp?\s+(\w+)\([^)]*,\s*_context\)\s*,?\s*do:(.*?)(?=\n|$)/,
        fn match ->
          String.replace(match, "_context)", "context)")
          |> String.replace("context,", "context,")
        end
      )
      |> String.replace(~r/defp?\s+(\w+)\(([^)]*),\s*_params\)\s+do/, "defp \\1(\\2, params) do")
      |> String.replace(~r/def\s+(\w+)\(([^)]*),\s*_params\)\s+do/, "def \\1(\\2, params) do")

    if content != fixed_content do
      File.write!(file_path, fixed_content)
      IO.puts("Fixed: #{file_path}")
    end
  end

  def run do
    # Get all .ex files with compilation issues
    files = [
      "lib/indrajaal/stamp/telemetry/event_processor.ex"
    ]

    Enum.each(files, &fix_file/1)
  end
end

UndefinedVariableFixer.run()
