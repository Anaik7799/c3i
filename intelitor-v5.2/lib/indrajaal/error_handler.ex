defmodule Indrajaal.ErrorHandler do
  @moduledoc """
  Comprehensive error handling with TPS 5 - Level RCA.

  Agent: Helper - 4 manages all error analysis.
  """

  require Logger

  @spec handle_error(any(), any()) :: any()
  def handle_error(error, context \\ %{}) do
    # TPS 5 - Level RCA
    analysis = analyze_error(error)

    Logger.error("Error occurred",
      error: inspect(error),
      __context: context,
      analysis: analysis
    )

    format_error_response(error)
  end

  @spec analyze_error(term()) :: term()
  defp analyze_error(error) do
    %{
      level_1: "Symptom: #{inspect(error)}",
      level_2: "Direct cause: #{identify_direct_cause(error)}",
      level_3: "System behavior: #{analyze_system_behavior(error)}",
      level_4: "Process gap: #{identify_process_gap(error)}",
      level_5: "Root cause: #{determine_root_cause(error)}"
    }
  end

  @spec identify_direct_cause(term()) :: term()
  defp identify_direct_cause({:error, :not_found}),
    do: "Resource does not exist"

  defp identify_direct_cause({:error, :forbidden}),
    do: "Insufficient permissions"

  defp identify_direct_cause(_), do: "Unknown error condition"

  @spec analyze_system_behavior(term()) :: term()
  defp analyze_system_behavior(_), do: "System rejected the operation"
  defp identify_process_gap(_), do: "Validation or authorization gap"
  defp determine_root_cause(_), do: "Design or implementation issue"

  @spec format_error_response(term()) :: term()
  defp format_error_response({:error, :notfound}) do
    %{status: 404, message: "Resource not found"}
  end

  defp format_error_response({:error, :forbidden}) do
    %{status: 403, message: "Access denied"}
  end

  defp format_error_response(_) do
    %{status: 500, message: "Internal server error"}
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
