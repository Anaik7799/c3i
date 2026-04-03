defmodule Indrajaal.ComplianceFactory do
  @moduledoc """
  Factory definitions for Compliance domain.

  ## STAMP Compliance
  - SC-FAC-001: Ash.Changeset pattern (not ExMachina)
  - SC-FAC-002: Factory for EVERY resource
  - SC-FAC-003: Create parents first
  """

  defmacro __using__(_) do
    quote do
      alias Indrajaal.Compliance.Framework

      def framework_factory(attrs \\ []) do
        attrs = Enum.into(attrs, %{})

        # Handle tenant and organization - create if not provided
        {tenant, attrs} =
          if Map.has_key?(attrs, :tenant) do
            Map.pop(attrs, :tenant)
          else
            {insert(:tenant), attrs}
          end

        {_organization, attrs} =
          if Map.has_key?(attrs, :organization) do
            Map.pop(attrs, :organization)
          else
            {insert(:organization, tenant: tenant), attrs}
          end

        seq = System.unique_integer([:positive])

        # Only include attributes accepted by the :create action
        # status, total_requirements etc are auto-set by action changes
        default_attrs = %{
          framework_code: "FRM-#{seq}",
          framework_name: attrs[:name] || "Compliance Framework #{seq}",
          description: "Test framework for compliance testing",
          version: attrs[:version] || "1.0",
          framework_type: :regulatory,
          category: :security
        }

        # Merge only valid create action attributes
        # Drop attributes not accepted by :create action
        valid_attrs =
          default_attrs
          |> Map.merge(attrs)
          |> Map.drop([
            :name,
            :status,
            :total_requirements,
            :mandatory_requirements,
            :optional_requirements,
            :implementation_status,
            :compliance_percentage
          ])

        # Get tenant_id - Ash requires ID, not struct
        tenant_id = if is_struct(tenant), do: tenant.id, else: tenant

        Framework
        |> Ash.Changeset.for_create(:create, valid_attrs, tenant: tenant_id)
        |> Ash.create!(tenant: tenant_id)
      end
    end
  end
end
