#!/usr/bin/env elixir

defmodule MobileApi.ContextWarningFixer do
  @moduledoc """
  Fixes compilation warnings in generated __contexts.

  Agent: Helper-1 (Compilation Management)
  Timestamp: 2025-08-03T23:15:00+02:00
  """

  @__contexts [
    "lib/indrajaal/access_control.ex",
    "lib/indrajaal/accounts.ex",
    "lib/indrajaal/analytics.ex",
    "lib/indrajaal/authorization.ex",
    "lib/indrajaal/communication.ex",
    "lib/indrajaal/compliance.ex",
    "lib/indrajaal/devices.ex",
    "lib/indrajaal/environmental.ex",
    "lib/indrajaal/fleet_management.ex",
    "lib/indrajaal/guard_tours.ex",
    "lib/indrajaal/integration.ex",
    "lib/indrajaal/intelligence.ex",
    "lib/indrajaal/maintenance.ex",
    "lib/indrajaal/shifts.ex",
    "lib/indrajaal/sites.ex",
    "lib/indrajaal/training.ex",
    "lib/indrajaal/video.ex",
    "lib/indrajaal/visitor_management.ex"
  ]

  @spec fix_all() :: any()
  def fix_all do
    IO.puts("🔧 Fixing __context compilation warnings...")

    # Remove unused User alias from __contexts
    Enum.each(@__contexts, fn file ->
      if File.exists?(file) do
        fix_unused_alias(file)
      end
    end)

    # Fix unused variables in authorization.ex
    fix_authorization_warnings()

    IO.puts("✅ Context warnings fixed!")
  end

  @spec fix_unused_alias(term()) :: term()
  defp fix_unused_alias(file) do
    IO.puts("  Fixing #{file}...")

    case File.read(file) do
      {:ok, content} ->
        # Comment out unused alias
        fixed_content = String.replace(
          content,
          "alias Indrajaal.Accounts.User",
          "# alias Indrajaal.Accounts.User # Commented out - unused"
        )

        File.write!(file, fixed_content)

      {:error, _} ->
        IO.puts("    ⚠️  Could not read file")
    end
  end

  @spec fix_authorization_warnings() :: any()
  defp fix_authorization_warnings do
    IO.puts("  Fixing authorization.ex...")

    file = "lib/indrajaal/authorization.ex"

    case File.read(file) do
      {:ok, content} ->
        # Fix unused variables
        fixed_content =
          content
          |> String.replace(
            "def can?(__user, action, resource) do",
            "def can?(__user, action, _resource) do"
          )
          |> String.replace(
            "def filter_by_access(query, user) do",
            "def filter_by_access(query, __user) do"
          )

        File.write!(file, fixed_content)

      {:error, _} ->
        IO.puts("    ⚠️  Could not read file")
    end
  end
end

# Execute
MobileApi.ContextWarningFixer.fix_all()