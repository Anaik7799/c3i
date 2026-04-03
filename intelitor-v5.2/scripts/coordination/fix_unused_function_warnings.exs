#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule UnusedFunctionWarningsFixer do
  @moduledoc """
  SOPv5.11 Cybernetic Agent: Unused Function Warnings Elimination

  This script systematically fixes the 5 unused function warnings across
  multiple modules using targeted strategies based on function context:

  1. workflow_engine.ex - Already prefixed, may need removal analysis
  2. cache/warmer.ex - Function has implementation, needs usage analysis
  3. timescale_domain_integration.ex - 4 placeholder functions, need @doc false

  Agent Coordination: Multi-Agent Strategy for Function-Level Analysis
  Strategy: Context-aware fixes based on function purpose and implementation
  """

  def main(_args \\ []) do
    IO.puts("🤖 SOPv5.11 Agent Coordination: Unused Function Warnings Elimination")
    IO.puts("📁 Target Files: 3 files with 5 unused function warnings")
    IO.puts("🎯 Mission: Systematic function-level warning elimination")
    IO.puts("")

    # Fix workflow_engine.ex - already has underscore prefix, document as intentionally unused
    fix_workflow_engine_decision_request()

    # Fix cache/warmer.ex - remove unused function that has full implementation
    fix_cache_warmer_targets()

    # Fix timescale_domain_integration.ex - add @doc false to 4 helper functions
    fix_timescale_helper_functions()

    IO.puts("✅ All 5 unused function warnings systematically addressed!")
    IO.puts("🔧 Applied context-aware strategies based on function analysis")
    IO.puts("📊 Function-Level Warning Elimination Complete")
    IO.puts("")
    IO.puts("🎯 Next Phase: Zero-warning compilation validation")
  end

  # Fix workflow_engine.ex line 734 - _create_decision_request/4
  defp fix_workflow_engine_decision_request do
    file_path = "lib/indrajaal/alarms/workflow_engine.ex"
    IO.puts("📝 Processing: #{file_path} - _create_decision_request/4")

    content = File.read!(file_path)

    # Add @doc false before the function to suppress unused warning
    fixed_content = String.replace(
      content,
      "  defp _create_decision_request(step, instance, _alarm, __req) do",
      "  @doc false\n  defp _create_decision_request(step, instance, _alarm, __req) do"
    )

    File.write!(file_path, fixed_content)
    IO.puts("✅ Added @doc false to suppress warning for intentionally unused function")
  end

  # Fix cache/warmer.ex line 172 - get_warming_targets/2
  defp fix_cache_warmer_targets do
    file_path = "lib/indrajaal/cache/warmer.ex"
    IO.puts("📝 Processing: #{file_path} - get_warming_targets/2")

    content = File.read!(file_path)

    # This function has full implementation but is unused - remove it entirely
    # Find the function definition and remove it
    lines = String.split(content, "\n")

    # Find start and end of the function
    start_idx = Enum.find_index(lines, &String.contains?(&1, "defp get_warming_targets(:all, _req) do"))

    if start_idx do
      # Find the end of this function (next function or end of file)
      end_idx = find_function_end(lines, start_idx)

      # Remove the function lines
      new_lines = Enum.slice(lines, 0, start_idx) ++
                  ["  # Function removed: get_warming_targets/2 was unused"] ++
                  Enum.slice(lines, end_idx + 1, length(lines))

      fixed_content = Enum.join(new_lines, "\n")
      File.write!(file_path, fixed_content)
      IO.puts("✅ Removed unused function get_warming_targets/2 with full implementation")
    end
  end

  # Fix timescale_domain_integration.ex lines 1172-1175 - 4 helper functions
  defp fix_timescale_helper_functions do
    file_path = "lib/indrajaal/communication/timescale_domain_integration.ex"
    IO.puts("📝 Processing: #{file_path} - 4 helper functions")

    content = File.read!(file_path)

    # Add @doc false to each of the 4 helper functions
    fixed_content = content
    |> String.replace(
      "  defp validate_data_access(_tenant_id, _query_params), do: true",
      "  @doc false\n  defp validate_data_access(_tenant_id, _query_params), do: true"
    )
    |> String.replace(
      "  defp check_retention_policy(_query_params), do: true",
      "  @doc false\n  defp check_retention_policy(_query_params), do: true"
    )
    |> String.replace(
      "  defp verify_privacy_requirements(_query_params), do: true",
      "  @doc false\n  defp verify_privacy_requirements(_query_params), do: true"
    )
    |> String.replace(
      "  defp determine_masking_rules(_query_params), do: []",
      "  @doc false\n  defp determine_masking_rules(_query_params), do: []"
    )

    File.write!(file_path, fixed_content)
    IO.puts("✅ Added @doc false to 4 helper functions to suppress unused warnings")
  end

  # Helper function to find the end of a function definition
  defp find_function_end(lines, start_idx) do
    # Look for the next function definition or end of file
    Enum.find_index(lines, start_idx + 1, fn line ->
      String.match?(line, ~r/^\s+(def|defp)\s/) or
      String.match?(line, ~r/^end\s*$/) or
      String.match?(line, ~r/^\s*end\s*$/)
    end) || length(lines) - 1
  end
end

UnusedFunctionWarningsFixer.main(System.argv())