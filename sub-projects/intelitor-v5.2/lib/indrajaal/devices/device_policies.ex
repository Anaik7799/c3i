defmodule Indrajaal.Devices.DevicePolicies do
  @moduledoc """
  Shared policies for device resources (Panel, Reader, Camera, Sensor).

  Provides common policy patterns used across multiple device resource modules
  to eliminate code duplication and ensure consistent authorization behavior.
  """

  @doc """
  Generates common device policies: admin bypass, read policy, and create/update policy.

  These policies are used by multiple device resources to ensure consistent
  authorization patterns.

  ## Usage in a resource:

      policies do
        Indrajaal.Devices.DevicePolicies.common_policies()
        # Add resource-specific policies here
      end
  """
  defmacro common_policies do
    quote do
      bypass always() do
        authorize_if actor_attribute_equals(:role, "admin")
      end

      policy action(:read) do
        authorize_if actor_attribute_equals(:role, "admin")
        authorize_if actor_attribute_equals(:role, "technician")
        authorize_if actor_attribute_equals(:role, "operator")
        authorize_if actor_attribute_equals(:role, "viewer")
      end

      policy action_type([:create, :update]) do
        authorize_if actor_attribute_equals(:role, "admin")
        authorize_if actor_attribute_equals(:role, "technician")
      end
    end
  end
end
