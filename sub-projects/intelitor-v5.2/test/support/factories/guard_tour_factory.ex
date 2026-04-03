import Indrajaal.Test.SharedFactoryUtilities

defmodule Indrajaal.GuardTourFactory do
  @moduledoc """
  Factory definitions for GuardTour domain.
  Aligned with Ash domain APIs per SOPv5.1 Task 8.4.1.
  """

  defmacro __using__(_) do
    quote do
      # AGENT NOTE: checkpoint_factory uses Ash.create for Checkpoint resource
      @spec checkpoint_factory(any()) :: any()
      def checkpoint_factory(attrs \\ %{}) do
        # Normalize attrs to map (handles both keyword list and map input)
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        checkpoint_attrs =
          %{
            name: sequence(:checkpoint_name, &"Checkpoint #{&1}"),
            location_description: "Test checkpoint location",
            checkpoint_type: :nfc,
            identifier_code: sequence(:identifier_code, &"NFC-#{&1}"),
            latitude: Decimal.new("40.7128"),
            longitude: Decimal.new("-74.0060"),
            is_mandatory: true,
            max_scan_time: 30,
            instructions: "Scan checkpoint and verify area"
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)

        # Use Ash.create directly with Checkpoint resource
        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        case Ash.create(
               Indrajaal.GuardTour.Checkpoint,
               checkpoint_attrs,
               actor: admin_actor,
               tenant: tenant.id
             ) do
          {:ok, checkpoint} ->
            checkpoint

          {:error, changeset} ->
            raise "Failed to create checkpoint: #{inspect(changeset)}"
        end
      end

      # AGENT NOTE: tour_route_factory uses Ash.create for TourRoute resource
      @spec tour_route_factory(any()) :: any()
      def tour_route_factory(attrs \\ %{}) do
        # Normalize attrs to map (handles both keyword list and map input)
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        route_attrs =
          %{
            name: sequence(:route_name, &"Route #{&1}"),
            description: "Test security patrol route",
            route_type: :regular,
            estimated_duration: 60,
            checkpoint_order: [],
            is_active: true,
            priority_level: :medium
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)

        # Use Ash.create directly with TourRoute resource
        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        case Ash.create(
               Indrajaal.GuardTour.TourRoute,
               route_attrs,
               actor: admin_actor,
               tenant: tenant.id
             ) do
          {:ok, route} ->
            route

          {:error, changeset} ->
            raise "Failed to create tour route: #{inspect(changeset)}"
        end
      end
    end
  end
end
