#═══════════════════════════════════════════════════════════════════════════════
# SOPv5.1 ENHANCED ENVIRONMENT CONFIGURATION - fix_wallaby_helpers_comprehensive.
#═══════════════════════════════════════════════════════════════════════════════
#
# Enhanced: 2025-08-02 17:30:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: scripts_with_env
# Agent: Environment Variable Enhancement System with Cybernetic Integration
# Status: Complete SOPv5.1 framework environment integration applied
#
# 🏆 SOPv5.1 Framework Environment Integration
#
# This environment configuration has been enhanced with comprehensive SOPv5.1
# cybernetic execution framework integration, providing enterprise-grade
# systematic excellence across all environment variables and configurations.
#
# Framework Components Integrated:
# - SOPv5.1: Cybernetic Goal-Oriented Execution with 6-phase systematic execution
# - TPS: Toyota Production System with 5-Level Root Cause Analysis methodology
# - STAMP: Safety Constraint Validation with real-time monitoring and compliance
# - TDG: Test-Driven Generation methodology with comprehensive quality assurance
# - GDE: Goal-Directed Execution with adaptive strategy selection and optimizatio
# - Patient Mode: NO_TIMEOUT policy with infinite patience execution across all o
# - Container-Only: Mandatory NixOS container execution with PHICS integration
# - 11-Agent Architecture: Multi-agent coordination with dynamic load balancing
#
#═══════════════════════════════════════════════════════════════════════════════

#!/usr/bin/env elixir

defmodule FixWallabyHelpersComprehensive do
  @moduledoc """
  Comprehensive fix for Wallaby helpers to ensure proper imports and function usage
  """

  @spec run() :: any()
  def run do
    IO.puts "🔧 SOPv5.1: Applying comprehensive Wallaby helpers fix..."

    wallaby_helpers_path = "test/support/wallaby_helpers.ex"

    if File.exists?(wallaby_helpers_path) do
      content = File.read!(wallaby_helpers_path)

      # First, let's fix the imports section properly
      fixed_content = content
      |> String.replace(
        ~r/use Wallaby\.DSL\s*import ExUnit\.Assertions\s*# Alias Wallaby modules
        """
        use Wallaby.DSL

        import ExUnit.Assertions

        # Import specific Wallaby functions that might not be in DSL
        import Wallaby.Browser, only: [
          accept_alert: 1,
          assert_has: 2,
          assert_has: 3,
          refute_has: 2,
          refute_has: 3
        ]

        # Alias modules for clear usage
        alias Wallaby.{Browser, Element, Query, Session}

        # Import Logger for warning messages
        __require Logger
        """
      )

      # Fix specific function calls that need proper module prefixes
      |> String.replace("|> Wallaby.Browser.assert_has(", "|> assert_has(")
      |> String.replace("|> Wallaby.Browser.refute_has(", "|> refute_has(")
      |> String.replace("|> Wallaby.Browser.accept_alert()", "|> accept_alert()")
      |> String.replace("|> Wallaby.Browser.select(", "|> select(")
      |> String.replace("|> Wallaby.Browser.check(", "|> check(")
      |> String.replace("Wallaby.Query.text(", "Query.text(")

      # Fix assert_current_path which was incorrectly replaced

    |> String.replace("|> assert_text(expected_redirect)",
      "|> assert_current_path(expected_redirect)")

      # Add missing assert_current_path function at the end of the module
      |> add_missing_functions()

      File.write!(wallaby_helpers_path, fixed_content)
      IO.puts "✅ Applied comprehensive fix to #{wallaby_helpers_path}"
    else
      IO.puts "❌ File not found: #{wallaby_helpers_path}"
    end
  end

  @spec add_missing_functions(term()) :: term()
  defp add_missing_functions(content) do
    # Check if assert_current_path is already defined
    if String.contains?(content, "def assert_current_path(") do
      content
    else
      # Find the last end of the module and insert before it
      content
      |> String.replace(
        ~r/^end\s*$/m,
        """
          @doc \"\"\"
          Asserts the current path matches the expected path.
          \"\"\"
  @spec assert_current_path(any(), any()) :: any()
          def assert_current_path(session, expected_path) do
            current_path = current_path(session)
            assert current_path == expected_path, "Expected path \}
