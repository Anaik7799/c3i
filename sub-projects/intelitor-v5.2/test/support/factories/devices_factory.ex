import Indrajaal.Test.SharedFactoryUtilities

defmodule Indrajaal.DevicesFactory do
  @moduledoc """
  Factory definitions for Devices domain.
  Created as part of HYPERSPEED Wave 1 factory infrastructure.
  SOPv5.11 Compliant | TDG Methodology | STAMP Safety Verified
  """

  defmacro __using__(_) do
    quote do
      @spec device_factory(any()) :: any()
      def device_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Extract device_type_id from device_type struct if present, or create one
        {device_type_id, attrs_map} =
          cond do
            Map.has_key?(attrs_map, :device_type_id) ->
              {attrs_map[:device_type_id], Map.delete(attrs_map, :device_type_id)}

            is_map(attrs_map[:device_type]) and Map.has_key?(attrs_map[:device_type], :id) ->
              {attrs_map[:device_type].id, Map.delete(attrs_map, :device_type)}

            true ->
              # Create a device_type if not provided
              dt = device_type_factory(%{tenant: tenant})
              {dt.id, attrs_map}
          end

        # Handle site_id similarly
        {site_id, attrs_map} =
          cond do
            Map.has_key?(attrs_map, :site_id) ->
              {attrs_map[:site_id], Map.delete(attrs_map, :site_id)}

            is_map(attrs_map[:site]) and Map.has_key?(attrs_map[:site], :id) ->
              {attrs_map[:site].id, Map.delete(attrs_map, :site)}

            true ->
              # Create a site if not provided
              s = site_factory(%{tenant: tenant})
              {s.id, attrs_map}
          end

        device_attrs =
          %{
            name: sequence(:device_name, fn n -> "Device #{n}" end),
            description: "Test Device",
            serial_number: sequence(:serial, fn n -> "SN-#{n}" end),
            ip_address: "192.168.1.100",
            mac_address: "AA:BB:CC:DD:EE:FF",
            status: "offline",
            active: true,
            metadata: %{},
            tenant_id: tenant.id,
            device_type_id: device_type_id,
            site_id: site_id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:site)
          |> Map.delete(:device_type)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, device} =
          Ash.create(
            Indrajaal.Devices.Device,
            device_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        device
      end

      @spec device_type_factory(any()) :: any()
      def device_type_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        device_type_attrs =
          %{
            name: sequence(:device_type_name, &"Device Type #{&1}"),
            code: sequence(:device_type_code, &"TYPE#{&1}"),
            category: :sensor,
            capabilities: ["detection"],
            manufacturer: "Generic",
            model: "Gen-1",
            tenant_id: tenant.id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:description)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, device_type} =
          Ash.create(
            Indrajaal.Devices.DeviceType,
            device_type_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        device_type
      end

      unquote(devices_factory_part_2())
    end
  end

  defp devices_factory_part_2 do
    quote do
      @spec sensor_factory(any()) :: any()
      def sensor_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Handle device dependency - sensor requires a parent device
        device =
          case Map.pop(attrs_map, :device) do
            {nil, _} ->
              case Map.get(attrs_map, :device_id) do
                nil -> insert(:device, tenant_id: tenant.id)
                _device_id -> nil
              end

            {device, _} ->
              device
          end

        sensor_attrs =
          %{
            sensor_type: :motion,
            detection_method: :pir,
            sensitivity: 50,
            detection_range_m: 10.0,
            detection_angle_deg: 90,
            mounting_height_m: 2.5,
            current_state: :normal,
            armed?: false,
            bypass?: false,
            tamper?: false,
            low_battery?: false,
            supervised?: true,
            response_time_ms: 500,
            debounce_time_ms: 1000,
            alarm_delay_sec: 0,
            zone_number: sequence(:sensor_zone_number, fn n -> n end),
            zone_type: :instant,
            chime_enabled?: true,
            led_enabled?: true,
            pet_immune?: false,
            environmental_compensation?: false,
            trigger_count: 0,
            false_alarm_count: 0,
            calibration_data: %{},
            metadata: %{},
            tenant_id: tenant.id,
            device_id: if(device, do: device.id, else: attrs_map[:device_id])
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:device)
          |> Map.delete(:site)
          |> Map.delete(:zone)
          |> Map.delete(:type)
          |> Map.delete(:name)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, sensor} =
          Ash.create(
            Indrajaal.Devices.Sensor,
            sensor_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        sensor
      end

      # panel_factory creates alarm panel devices
      @spec panel_factory(any()) :: any()
      def panel_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Handle device dependency - panel requires a parent device
        device =
          case Map.pop(attrs_map, :device) do
            {nil, _} ->
              case Map.get(attrs_map, :device_id) do
                nil -> insert(:device, tenant_id: tenant.id)
                _device_id -> nil
              end

            {device, _} ->
              device
          end

        # Extract site_id from site struct or attrs
        site_id =
          case Map.get(attrs_map, :site_id) do
            nil ->
              case Map.get(attrs_map, :site) do
                %{id: id} -> id
                _ -> nil
              end

            id ->
              id
          end

        panel_attrs =
          %{
            device_id: if(device, do: device.id, else: attrs_map[:device_id]),
            panel_type: :intrusion,
            manufacturer: "Generic",
            model: "Test Panel",
            connection_type: :ethernet,
            account_number:
              sequence(:panel_account, fn n ->
                "ACCT#{String.pad_leading(to_string(n), 6, "0")}"
              end),
            sia_level: 3,
            max_zones: 32,
            max_users: 50,
            max_outputs: 4,
            max_partitions: 1,
            features: %{},
            panel_status: :offline,
            tenant_id: tenant.id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:device)
          |> Map.delete(:site)
          |> Map.delete(:site_id)
          |> then(fn attrs ->
            if site_id, do: Map.put(attrs, :site_id, site_id), else: attrs
          end)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, panel} =
          Ash.create(
            Indrajaal.Devices.Panel,
            panel_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        panel
      end
    end
  end
end

# Agent: Worker-2 (Devices Domain Agent)
# SOPv5.11 Compliance: Devices domain factory definitions
# Domain: Devices/Testing
# Responsibilities: Device, device_type, sensor factory generation
# Multi-Agent Architecture: Integrated with factory infrastructure
# Cybernetic Feedback: Active feedback loops for test data quality
