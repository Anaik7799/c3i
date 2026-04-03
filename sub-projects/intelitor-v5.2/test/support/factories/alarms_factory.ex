import Indrajaal.Test.SharedFactoryUtilities

defmodule Indrajaal.AlarmsFactory do
  @moduledoc """
  Factory definitions for Alarms domain.
  Created as part of HYPERSPEED Wave 1 factory infrastructure.
  SOPv5.11 Compliant | TDG Methodology | STAMP Safety Verified
  """

  defmacro __using__(_) do
    quote do
      @spec alarm_event_factory(any()) :: any()
      def alarm_event_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Create site/device if not provided
        # Note: Call factory function directly, not insert/2, because Ash factories
        # return already-persisted records and ExMachina insert would try to re-insert
        site = Map.get(attrs_map, :site) || site_factory(%{tenant: tenant})
        device = Map.get(attrs_map, :device) || device_factory(%{tenant: tenant, site: site})

        # Build attrs with only accepted inputs for :create action
        unique_id = System.unique_integer([:positive, :monotonic])

        alarm_attrs =
          %{
            event_code: "EVT#{String.pad_leading(to_string(unique_id), 4, "0")}",
            event_type: :intrusion,
            severity: :medium,
            priority: 5,
            description: "Test alarm event #{unique_id}",
            site_id: site.id,
            device_id: device.id
          }
          |> merge_attributes(attrs_map)
          # Remove keys that are not accepted by the create action
          |> Map.delete(:tenant)
          |> Map.delete(:tenant_id)
          |> Map.delete(:site)
          |> Map.delete(:device)
          |> Map.delete(:status)
          |> Map.delete(:type)
          |> Map.delete(:timestamp)
          |> Map.delete(:state)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, alarm} =
          Ash.create(
            Indrajaal.Alarms.AlarmEvent,
            alarm_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        alarm
      end

      # Alias for backwards compatibility - many tests use :alarm instead of :alarm_event
      @spec alarm_factory(any()) :: any()
      def alarm_factory(attrs \\ %{}) do
        alarm_event_factory(attrs)
      end

      # Incident factory - creates incident-like alarm events for workflow testing
      @spec incident_factory(any()) :: any()
      def incident_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Map incident-specific attrs to alarm_event format
        incident_type = Map.get(attrs_map, :type, "security_breach")
        incident_status = Map.get(attrs_map, :status, :active)

        event_type =
          case incident_type do
            "security_breach" -> :intrusion
            "equipment_failure" -> :trouble
            "false_alarm" -> :intrusion
            "maintenance" -> :supervisory
            _ -> :intrusion
          end

        state =
          case incident_status do
            :active -> :triggered
            :open -> :triggered
            :investigating -> :investigating
            :resolved -> :resolved
            :closed -> :resolved
            _ -> :triggered
          end

        alarm_attrs =
          %{
            event_type: event_type,
            state: state,
            severity: Map.get(attrs_map, :priority, :medium),
            description: Map.get(attrs_map, :title, "Test incident"),
            metadata: %{
              incident_type: incident_type,
              original_status: incident_status
            }
          }
          |> Map.merge(Map.drop(attrs_map, [:type, :status, :title, :priority, :tenant]))

        alarm_event_factory(Map.put(alarm_attrs, :tenant, tenant))
      end
    end
  end
end
