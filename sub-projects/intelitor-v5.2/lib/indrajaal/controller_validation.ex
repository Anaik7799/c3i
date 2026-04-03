defmodule Indrajaal.ControllerValidation do
  @moduledoc """
  Shared controller validation consolidation functions.
  Eliminates duplication in mobile controller consolidation scripts.
  """

  @spec consolidate_validations(list(), atom()) :: binary()
  def consolidate_validations(controllers, validation_type) do
    validation_function = get_validation_function(validation_type)

    controllers
    |> Enum.map_join("\n", &generate_validation_call(&1, validation_function))
  end

  @spec estimate_validation_impact(list(), atom()) :: map()
  def estimate_validation_impact(controllers, validation_type) do
    total_controllers = length(controllers)
    lines_per_validation = estimate_lines_per_validation(validation_type)

    %{
      controllers_affected: total_controllers,
      estimated_lines_saved: total_controllers * lines_per_validation,
      validation_type: validation_type
    }
  end

  defp get_validation_function(:tenant), do: "validate_tenant_access"
  defp get_validation_function(:auth), do: "validate_authentication"
  defp get_validation_function(:__params), do: "validate__request_params"
  defp get_validation_function(_), do: "validate_request"

  defp generate_validation_call(_controller, function) do
    "    with :ok <- ControllerHelpers.#{function}(conn, opts) do"
  end

  defp estimate_lines_per_validation(:tenant), do: 15
  defp estimate_lines_per_validation(:auth), do: 10
  defp estimate_lines_per_validation(:__params), do: 8
  defp estimate_lines_per_validation(_), do: 5
end
