#!/usr/bin/env elixir

defmodule DomainSyntaxFixer do
  @moduledoc """
  SOPv5.1 TPS Jidoka: Fix systematic syntax errors in domain files

  Agent: Helper-3 (Systematic Error Resolver)
  Pattern: EP502-Syntax error mass resolution
  """

  def main do
    IO.puts("🔧 SOPv5.1 TPS Jidoka: Fixing domain syntax errors")

    # Fix unused errors variables
    fix_unused_errors_variables()

    # Fix malformed ErrorHelpers calls
    fix_errorhelpers_syntax_errors()

    IO.puts("✅ Domain syntax error fixes completed")
  end

  defp fix_unused_errors_variables do
    IO.puts("📝 Fixing unused errors variables")

    files_with_errors = [
      "lib/indrajaal/fleet_management.ex",
      "lib/indrajaal/guard_tours.ex",
      "lib/indrajaal/integration.ex",
      "lib/indrajaal/intelligence.ex",
      "lib/indrajaal/shifts.ex",
      "lib/indrajaal/visitor_management.ex",
      "lib/indrajaal/sites.ex",
      "lib/indrajaal/video.ex",
      "lib/indrajaal/maintenance.ex",
      "lib/indrajaal/config_management.ex"
    ]

    Enum.each(files_with_errors, fn file_path ->
      if File.exists?(file_path) do
        content = File.read!(file_path)
        updated_content = String.replace(content, "    errors =", "    _errors =")
        File.write!(file_path, updated_content)
        IO.puts("✅ Fixed unused errors in #{file_path}")
      end
    end)
  end

  defp fix_errorhelpers_syntax_errors do
    IO.puts("📝 Fixing ErrorHelpers syntax errors")

    files_with_syntax_errors = [
      "lib/indrajaal/integration.ex",
      "lib/indrajaal/guard_tours.ex"
    ]

    Enum.each(files_with_syntax_errors, fn file_path ->
      if File.exists?(file_path) do
        content = File.read!(file_path)

        # Fix the malformed ErrorHelpers.analyze_validation_errors call
        updated_content =
          content
          |> String.replace(
            ~r/ErrorHelpers\.analyze_validation_errors\(changeset,
            "ErrorHelpers.analyze_validation_errors(changeset,
          )

        File.write!(file_path, updated_content)
        IO.puts("✅ Fixed ErrorHelpers syntax in #{file_path}")
      end
    end)
  end
end

# Run the fixes
DomainSyntaxFixer.main()
