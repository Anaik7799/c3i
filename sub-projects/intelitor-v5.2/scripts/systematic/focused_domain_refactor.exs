#!/usr/bin/env elixir

defmodule FocusedDomainRefactor do
  @moduledoc """
  Focused domain __context refactoring targeting specific duplicate code patterns.

  Based on credo analysis, systematically eliminate duplicate validation and error handling
  patterns across domain __contexts by ensuring consistent use of shared modules.
  """

  @spec main(term()) :: any()
  def main(_args \\ []) do
    IO.puts("🔧 Focused domain __context refactoring for duplicate elimination...")

    # Target specific files showing in credo duplicate analysis
    target_files = [
      "lib/indrajaal/guard_tours.ex",
      "lib/indrajaal/fleet_management.ex",
      "lib/indrajaal/environmental.ex",
      "lib/indrajaal/energy_management.ex",
      "lib/indrajaal/devices.ex",
      "lib/indrajaal/integration.ex"
    ]

    IO.puts("📁 Processing #{length(target_files)} high-duplicate files")

    Enum.each(target_files, fn file ->
      if File.exists?(file) do
        IO.puts("🔄 Processing: #{Path.basename(file)}")
        ensure_shared_modules(file)
      else
        IO.puts("⏭️  Skipped: #{Path.basename(file)} (not found)")
      end
    end)

    IO.puts("✅ Focused refactoring completed!")
    IO.puts("🔍 Validation: elixir scripts/validation/simple_credo_counter.exs")
  end

  defp ensure_shared_modules(file_path) do
    content = File.read!(file_path)

    updated_content =
      content
      |> ensure_shared_imports()
      |> replace_duplicate_error_handling()

    if content != updated_content do
      File.write!(file_path, updated_content)
      IO.puts("  ✅ Updated shared module usage")
    else
      IO.puts("  ⏭️  Already optimized")
    end
  end

  defp ensure_shared_imports(content) do
    # Add shared module imports if missing
    if String.contains?(content, "ErrorHelpers") do
      content
    else
      # Add after existing alias __statements
      String.replace(
        content,
        ~r/(alias\s+Indrajaal\.\w+)/,
        "\\1\n  alias Indrajaal.Shared.{ContextHelpers, ValidationHelpers, ErrorHelpers}"
      )
    end
  end

  defp replace_duplicate_error_handling(content) do
    # Replace duplicate error handling patterns with ErrorHelpers
    duplicate_pattern = ~r/Logger\.warning.*?"Validation errors detected".*?level_1:.*?level_5:/s

    if Regex.match?(duplicate_pattern, content) do
      String.replace(
        content,
        duplicate_pattern,
        "ErrorHelpers.analyze_validation_errors(changeset, \#{inspect(__MODULE__)})"
      )
    else
      content
    end
  end
end

# Execute
FocusedDomainRefactor.main(System.argv())
