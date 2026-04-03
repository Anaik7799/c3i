#!/usr/bin/env elixir

defmodule UnusedAliasCleanup do
  @moduledoc """
  SOPv5.1 TPS-compliant cleanup of unused aliases in domain __contexts.

  Agent: Helper-3 (Systematic Pattern Fixer)
  Pattern: EP501 - Unused alias cleanup
  """

  @spec main() :: any()
  def main do
    IO.puts("🔧 SOPv5.1 TPS Jidoka: Cleaning unused aliases")
    IO.puts("🎯 Applying systematic unused alias resolution")

    # Domain files with unused aliases
    files_to_fix = [
      "lib/indrajaal/access_control.ex",
      "lib/indrajaal/accounts.ex",
      "lib/indrajaal/analytics.ex",
      "lib/indrajaal/communication.ex",
      "lib/indrajaal/compliance.ex",
      "lib/indrajaal/devices.ex"
    ]

    Enum.each(files_to_fix, &fix_unused_aliases/1)

    IO.puts("✅ Unused alias cleanup completed")

    # Also clean up unused functions in accounts.ex
    cleanup_unused_functions()
  end

  defp fix_unused_aliases(file_path) do
    IO.puts("📝 Processing: #{file_path}")

    content = File.read!(file_path)

    # Fix unused aliases by removing unused imports
    updated_content =
      content
      |> fix_access_control_aliases()
      |> fix_accounts_aliases()
      |> fix_analytics_aliases()
      |> fix_communication_aliases()
      |> fix_compliance_aliases()
      |> fix_devices_aliases()

    File.write!(file_path, updated_content)
    IO.puts("✅ Fixed unused aliases in #{file_path}")
  end

  defp fix_access_control_aliases(content) do
    if String.contains?(content, "lib/indrajaal/access_control.ex") do
      # Only keep ContextHelpers since it's the only one being used
      String.replace(
        content,
        "alias Indrajaal.Shared.{ContextHelpers, ValidationHelpers, ErrorHelpers}",
        "alias Indrajaal.Shared.ContextHelpers"
      )
    else
      content
    end
  end

  defp fix_accounts_aliases(content) do
    if String.contains?(content, "lib/indrajaal/accounts.ex") do
      # Only keep ContextHelpers since it's the only one being used
      String.replace(
        content,
        "alias Indrajaal.Shared.{ContextHelpers, ValidationHelpers, ErrorHelpers}",
        "alias Indrajaal.Shared.ContextHelpers"
      )
    else
      content
    end
  end

  defp fix_analytics_aliases(content) do
    if String.contains?(content, "lib/indrajaal/analytics.ex") do
      # Only keep ContextHelpers since it's the only one being used
      String.replace(
        content,
        "alias Indrajaal.Shared.{ContextHelpers, ValidationHelpers, ErrorHelpers}",
        "alias Indrajaal.Shared.ContextHelpers"
      )
    else
      content
    end
  end

  defp fix_communication_aliases(content) do
    if String.contains?(content, "lib/indrajaal/communication.ex") do
      # Remove all unused aliases
      String.replace(
        content,
        "alias Indrajaal.Shared.{ContextHelpers, ValidationHelpers, ErrorHelpers}",
        "# Shared aliases removed - not used in this module"
      )
    else
      content
    end
  end

  defp fix_compliance_aliases(content) do
    if String.contains?(content, "lib/indrajaal/compliance.ex") do
      # Remove all unused aliases
      String.replace(
        content,
        "alias Indrajaal.Shared.{ContextHelpers, ValidationHelpers, ErrorHelpers}",
        "# Shared aliases removed - not used in this module"
      )
    else
      content
    end
  end

  defp fix_devices_aliases(content) do
    if String.contains?(content, "lib/indrajaal/devices.ex") do
      # Remove all unused aliases
      String.replace(
        content,
        "alias Indrajaal.Shared.{ContextHelpers, ValidationHelpers, ErrorHelpers}",
        "# Shared aliases removed - not used in this module"
      )
    else
      content
    end
  end

  defp cleanup_unused_functions do
    IO.puts("🔧 Cleaning unused functions in accounts.ex")

    accounts_file = "lib/indrajaal/accounts.ex"
    content = File.read!(accounts_file)

    # Remove unused private functions
    updated_content =
      content
      |> String.replace(~r/\s+defp validate_query_params.*?end/s, "")
      |> String.replace(~r/\s+defp apply_search.*?end/s, "")
      |> String.replace(~r/\s+defp apply_filters.*?end/s, "")
      |> String.replace(~r/\s+defp apply_filter.*?end/s, "")

    File.write!(accounts_file, updated_content)
    IO.puts("✅ Cleaned unused functions in accounts.ex")
  end
end

# Run the cleanup
UnusedAliasCleanup.main()
