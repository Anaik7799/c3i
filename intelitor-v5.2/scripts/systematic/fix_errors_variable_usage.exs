#!/usr/bin/env elixir

defmodule ErrorsVariableFixer do
  @moduledoc """
  Fix files where errors variable was renamed to _errors but is still used
  """

  @spec main() :: any()
  def main do
    IO.puts("🔧 Fixing errors variable usage in files that still reference it")

    files_using_errors = [
      "lib/indrajaal/compliance.ex",
      "lib/indrajaal/training.ex",
      "lib/indrajaal/communication.ex",
      "lib/indrajaal/intelligence.ex",
      "lib/indrajaal/shifts.ex",
      "lib/indrajaal/visitor_management.ex",
      "lib/indrajaal/accounts.ex",
      "lib/indrajaal/sites.ex",
      "lib/indrajaal/video.ex",
      "lib/indrajaal/maintenance.ex",
      "lib/indrajaal/devices.ex",
      "lib/indrajaal/config_management.ex"
    ]

    Enum.each(files_using_errors, fn file_path ->
      if File.exists?(file_path) do
        content = File.read!(file_path)

        # Only fix files that have both _errors = and errors: errors usage
        if String.contains?(content, "_errors =") and String.contains?(content, "errors: errors") do
          updated_content = String.replace(content, "    _errors =", "    errors =")
          File.write!(file_path, updated_content)
          IO.puts("✅ Fixed #{file_path}")
        end
      end
    end)
  end
end

ErrorsVariableFixer.main()
