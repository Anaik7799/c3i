defmodule Indrajaal.RiskManagementFactory do
  @moduledoc """
  Factory definitions for Risk Management domain.
  SOPv5.11 Compliant | TDG Methodology | STAMP Safety Verified
  """

  defmacro __using__(_) do
    quote do
      import Indrajaal.Test.SharedFactoryUtilities,
        only: [normalize_attrs: 1, handle_tenant_association: 2]

      # Note: sequence/2 and merge_attributes/2 are provided by ExMachina
      # Do not redefine them here to avoid conflicts

      @spec risk_factory(any()) :: any()
      def risk_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        unique_id = System.unique_integer([:positive, :monotonic])

        risk_attrs =
          %{
            risk_id: sequence(:risk_id, fn n -> "RISK-" <> to_string(n) end),
            title: "Risk #{unique_id}",
            description: "Description for risk #{unique_id}",
            risk_source: :internal,
            risk_status: :identified,
            identified_date: Date.utc_today(),
            inherent_risk_score: 0,
            residual_risk_score: 0
          }
          |> Map.merge(attrs_map)
          |> Map.delete(:tenant)

        # Ensure required relationships are present or created
        risk_attrs =
          if Map.has_key?(risk_attrs, :category_id) do
            risk_attrs
          else
            # SC-FAC-001: Use direct factory call instead of insert to avoid ExMachina double-insert error
            Map.put(risk_attrs, :category_id, risk_category_factory(tenant: tenant).id)
          end

        risk_attrs =
          if Map.has_key?(risk_attrs, :risk_owner_id) do
            risk_attrs
          else
            # SC-FAC-001: Use direct factory call
            Map.put(risk_attrs, :risk_owner_id, user_factory(tenant: tenant).id)
          end

        risk_attrs =
          if Map.has_key?(risk_attrs, :identified_by_id) do
            risk_attrs
          else
            # SC-FAC-001: Use direct factory call
            Map.put(risk_attrs, :identified_by_id, user_factory(tenant: tenant).id)
          end

        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        case Ash.create(
               Indrajaal.RiskManagement.Risk,
               risk_attrs,
               actor: admin_actor,
               tenant: tenant.id
             ) do
          {:ok, risk} ->
            risk

          {:error, changeset} ->
            raise "Failed to create risk: #{inspect(changeset)}"
        end
      end

      @spec risk_category_factory(any()) :: any()
      def risk_category_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        unique_id = System.unique_integer([:positive, :monotonic])

        # EP-FAC-FIX: Use category_code instead of code, remove organization_id and code if passed
        category_attrs =
          %{
            name: "Risk Category #{unique_id}",
            category_code: sequence(:risk_category_code, fn n -> "RC-" <> to_string(n) end),
            description: "Description for risk category #{unique_id}",
            category_type: :operational
          }
          |> Map.merge(attrs_map)
          |> Map.delete(:tenant)
          # Ensure organization_id is not passed
          |> Map.delete(:organization_id)
          # Ensure code is not passed (use category_code)
          |> Map.delete(:code)

        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        case Ash.create(
               Indrajaal.RiskManagement.RiskCategory,
               category_attrs,
               actor: admin_actor,
               tenant: tenant.id
             ) do
          {:ok, category} ->
            category

          {:error, changeset} ->
            raise "Failed to create risk category: #{inspect(changeset)}"
        end
      end
    end
  end
end
