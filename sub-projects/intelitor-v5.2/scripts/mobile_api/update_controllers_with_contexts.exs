#!/usr/bin/env elixir

defmodule MobileApi.ControllerContextUpdater do
  @moduledoc """
  Updates controllers to use the actual __context modules.

  Agent: Supervisor coordinating controller updates
  Timestamp: 2025-08-03T23:17:00+02:00
  """

  @controller_mappings [
    {"alarms_controller.ex", "Alarms"},
    {"devices_controller.ex", "Devices"},
    {"sites_controller.ex", "Sites"},
    {"video_controller.ex", "Video"},
    {"access_control_controller.ex", "AccessControl"},
    {"visitor_management_controller.ex", "VisitorManagement"},
    {"guard_tours_controller.ex", "GuardTours"},
    {"maintenance_controller.ex", "Maintenance"},
    {"shifts_controller.ex", "Shifts"},
    {"analytics_controller.ex", "Analytics"},
    {"intelligence_controller.ex", "Intelligence"},
    {"integration_controller.ex", "Integration"},
    {"communication_controller.ex", "Communication"},
    {"fleet_management_controller.ex", "FleetManagement"},
    {"energy_management_controller.ex", "EnergyManagement"},
    {"environmental_controller.ex", "Environmental"},
    {"compliance_controller.ex", "Compliance"},
    {"training_controller.ex", "Training"},
    {"accounts_controller.ex", "Accounts"}
  ]

  @spec update_all() :: any()
  def update_all do
    IO.puts("🔄 Updating controllers to use __contexts...")

    Enum.each(@controller_mappings, fn {controller_file, __context_module} ->
      update_controller(controller_file, __context_module)
    end)

    IO.puts("✅ Controller updates complete!")
  end

  @spec update_controller(term(), term()) :: term()
  defp update_controller(controller_file, context_module) do
    file_path = "lib/indrajaal_web/controllers/api/mobile/config/#{controller_fil

    if File.exists?(file_path) do
      IO.puts("  Updating #{controller_file}...")

      case File.read(file_path) do
        {:ok, content} ->
          # Update the function calls to use actual __context
          updated_content =
            content
            |> String.replace(
              ~r/with\s+:ok\s+<-\s+validate_stamp_constraints/,
              "with :ok <- validate_stamp_constraints"
            )
            |> String.replace(
              ~r/\{:ok,\s+alarm_type\}\s+<-\s+Alarms\.create_alarm_type/,
              "{:ok, alarm_type} <- Indrajaal.Alarms.create_alarm_type"
            )
            |> update_context_calls(__context_module)

          File.write!(file_path, updated_content)

        {:error, _} ->
          IO.puts("    ⚠️  Could not read file")
      end
    end
  end

  @spec update_context_calls(term(), term()) :: term()
  defp update_context_calls(content, context_module) do
    # Get the domain name from __context module
    domain = __context_module |> Macro.underscore()

    # Update all __context function calls
    content
    |> String.replace(
      ~r/#{__context_module}\.list_/,
      "Indrajaal.#{__context_module}.list_"
    )
    |> String.replace(
      ~r/#{__context_module}\.get_/,
      "Indrajaal.#{__context_module}.get_"
    )
    |> String.replace(
      ~r/#{__context_module}\.create_/,
      "Indrajaal.#{__context_module}.create_"
    )
    |> String.replace(
      ~r/#{__context_module}\.update_/,
      "Indrajaal.#{__context_module}.update_"
    )
    |> String.replace(
      ~r/#{__context_module}\.delete_/,
      "Indrajaal.#{__context_module}.delete_"
    )
    |> String.replace(
      ~r/#{__context_module}\.bulk_create_/,
      "Indrajaal.#{__context_module}.bulk_create_"
    )
    |> String.replace(
      ~r/#{__context_module}\.import_/,
      "Indrajaal.#{__context_module}.import_"
    )
    |> String.replace(
      ~r/#{__context_module}\.export_/,
      "Indrajaal.#{__context_module}.export_"
    )
  end
end

# Execute
MobileApi.ControllerContextUpdater.update_all()
end
end
