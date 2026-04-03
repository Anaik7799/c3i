defmodule Intelitor.Alarms.ProcessingEngine do
  @moduledoc """
  High-performance alarm processing engine that handles event ingestion,
  severity evaluation, correlation analysis, and workflow triggering.
  """

  use GenServer
  require Logger

  alias Intelitor.Alarms.Api
  alias Intelitor.Alarms.{CorrelationEngine, SeverityEngine, NotificationOrchestrator}
  alias Intelitor.Alarms.{WorkflowEngine, StormDetection}

  @process_timeout 5_000

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process an alarm event from a device.
  """
  def process_alarm(device_event) do
    GenServer.call(__MODULE__, {:process_alarm, device_event}, @process_timeout)
  end

  @doc """
  Process a SIA DC-09 protocol event.
  """
  def handle_sia_event(binary_data) do
    GenServer.call(__MODULE__, {:handle_sia_event, binary_data}, @process_timeout)
  end

  @doc """
  Process an API-based alarm event.
  """
  def handle_api_event(params, tenant_id) do
    GenServer.call(__MODULE__, {:handle_api_event, params, tenant_id}, @process_timeout)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Subscribe to telemetry events for monitoring
    :telemetry.attach(
      "alarm-processing-metrics",
      [:intelitor, :alarm, :processed],
      &handle_telemetry_event/4,
      nil
    )

    {:ok, %{processed_count: 0, last_storm_check: DateTime.utc_now()}}
  end

  @impl true
  def handle_call({:process_alarm, device_event}, _from, state) do
    start_time = System.monotonic_time()

    result =
      with {:ok, alarm} <- create_alarm_event(device_event),
           {:ok, alarm} <- SeverityEngine.evaluate(alarm),
           {:ok, alarm} <- CorrelationEngine.analyze(alarm),
           :ok <- check_storm_conditions(alarm.tenant_id, state),
           :ok <- NotificationOrchestrator.notify_for_alarm(alarm),
           :ok <- WorkflowEngine.trigger_for_alarm(alarm) do
        # Record processing metrics
        duration = System.monotonic_time() - start_time
        record_processing_metrics(alarm, duration)

        {:ok, alarm}
      end

    new_state = %{state | processed_count: state.processed_count + 1}
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:handle_sia_event, binary_data}, _from, state) do
    result =
      with {:ok, parsed} <- parse_sia_event(binary_data),
           # Stub device lookup until Devices domain integration
           {:ok, device} <- get_device_by_account_number(parsed.account_number, state),
           # Future: {:ok, device} <- Devices.get_device_by_account_number(parsed.account_number),
           {:ok, normalized} <- normalize_sia_event(parsed, device) do
        device_event = %{
          tenant_id: device.tenant_id,
          source_device_id: device.id,
          event_code: normalized.event_code,
          event_type: map_sia_to_incident_type(normalized.event_code),
          location_id: device.location_id,
          raw_data: binary_data,
          metadata: %{
            protocol: "SIA-DC09",
            account: parsed.account_number,
            zone: parsed.zone,
            partition: parsed.partition
          }
        }

        handle_call({:process_alarm, device_event}, nil, state)
      end

    case result do
      {:reply, response, new_state} -> {:reply, response, new_state}
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:handle_api_event, params, tenant_id}, _from, state) do
    result =
      with {:ok, device} <- validate_and_get_device(params.device_id, tenant_id),
           {:ok, incident_type} <- get_incident_type(params.event_type) do
        device_event = %{
          tenant_id: tenant_id,
          source_device_id: device.id,
          event_code: params.event_code,
          event_type: incident_type.category,
          severity: params.severity || incident_type.default_severity,
          location_id: device.location_id,
          description: params.description,
          metadata:
            Map.merge(params.metadata || %{}, %{
              api_version: "v1",
              source_ip: params.source_ip
            })
        }

        handle_call({:process_alarm, device_event}, nil, state)
      end

    case result do
      {:reply, response, new_state} -> {:reply, response, new_state}
      error -> {:reply, error, state}
    end
  end

  # Private Functions

  defp create_alarm_event(device_event) do
    attrs = %{
      tenant_id: device_event.tenant_id,
      event_code: device_event.event_code || generate_event_code(device_event),
      event_type: device_event.event_type,
      severity: device_event[:severity] || :high,
      priority: device_event[:priority] || calculate_initial_priority(device_event),
      site_id: get_site_from_location(device_event[:location_id]),
      zone_id: get_zone_from_location(device_event[:location_id]),
      device_id: device_event.source_device_id,
      description: device_event[:description] || generate_description(device_event),
      metadata: device_event[:metadata] || %{},
      raw_data: device_event[:raw_data] || %{},
      triggered_at: DateTime.utc_now()
    }

    # Use the Ash API to create the alarm
    Api.create_alarm_event(attrs, actor: %{tenant_id: device_event.tenant_id})
  end

  defp generate_event_code(device_event) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix() |> to_string() |> String.slice(-6..-1)
    type_prefix = device_event.event_type |> to_string() |> String.slice(0..2) |> String.upcase()
    "#{type_prefix}#{timestamp}"
  end

  defp calculate_initial_priority(device_event) do
    case device_event.event_type do
      type when type in [:panic, :duress, :holdup] -> 10
      type when type in [:fire, :medical] -> 9
      type when type in [:intrusion] -> 8
      type when type in [:tamper] -> 7
      _ -> 5
    end
  end

  defp generate_description(device_event) do
    "#{String.capitalize(to_string(device_event.event_type))} alarm from device #{device_event.source_device_id}"
  end

  defp check_storm_conditions(tenant_id, state) do
    # Check every 30 seconds for alarm storms
    if DateTime.diff(DateTime.utc_now(), state.last_storm_check) > 30 do
      StormDetection.detect_storm(tenant_id)
    end

    :ok
  end

  defp record_processing_metrics(alarm, duration) do
    :telemetry.execute(
      [:intelitor, :alarm, :processed],
      %{
        duration: duration,
        count: 1
      },
      %{
        tenant_id: alarm.tenant_id,
        severity: alarm.severity,
        event_type: alarm.event_type,
        correlated: alarm.correlated_events != []
      }
    )
  end

  defp handle_telemetry_event(_event_name, measurements, metadata, _config) do
    Logger.debug("Alarm processed",
      duration_ms: System.convert_time_unit(measurements.duration, :native, :millisecond),
      severity: metadata.severity,
      event_type: metadata.event_type
    )
  end

  # SIA Protocol Parsing (simplified for example)
  defp parse_sia_event(_binary_data) do
    # This would be a full SIA DC-09 parser implementation
    # For now, returning a mock parsed result
    {:ok,
     %{
       account_number: "1234",
       event_code: "BA",
       zone: "001",
       partition: "01"
     }}
  end

  defp normalize_sia_event(parsed, _device) do
    {:ok,
     %{
       event_code: parsed.event_code,
       zone: parsed.zone,
       partition: parsed.partition
     }}
  end

  defp map_sia_to_incident_type(sia_code) do
    # SIA code mapping
    case sia_code do
      "BA" -> :intrusion
      "PA" -> :panic
      "FA" -> :fire
      "MA" -> :medical
      "HA" -> :holdup
      _ -> :supervisory
    end
  end

  defp validate_and_get_device(device_id, tenant_id) do
    Logger.debug("Validating device #{device_id} for tenant #{tenant_id}")

    # Stub implementation until Devices domain integration
    # Future implementation:
    # case Devices.get_device(device_id, actor: %{tenant_id: tenant_id}) do
    #   {:ok, device} -> validate_device_status(device)
    #   error -> error
    # end

    # Mock device for now
    device = %{
      id: device_id,
      tenant_id: tenant_id,
      status: :online,
      location_id: Ecto.UUID.generate()
    }

    case device.status do
      :online ->
        {:ok, device}

      status ->
        Logger.warning("Device #{device_id} is not online: #{status}")
        {:error, :device_offline}
    end
  end

  defp get_incident_type(event_type) do
    # This would fetch from the IncidentType resource
    {:ok, %{category: event_type, default_severity: :high}}
  end

  defp get_site_from_location(_location_id) do
    # This would resolve the site from location hierarchy
    # For now, returning a placeholder
    Ecto.UUID.generate()
  end

  defp get_zone_from_location(_location_id) do
    # This would resolve the zone from location
    # For now, returning a placeholder
    Ecto.UUID.generate()
  end

  defp get_device_by_account_number(account_number, _state) do
    Logger.debug("Looking up device by account number: #{account_number}")

    # Stub implementation until Devices domain integration
    # Future implementation:
    # case Devices.get_device_by_account_number(account_number) do
    #   {:ok, device} -> {:ok, device}
    #   {:error, :not_found} -> {:error, :device_not_found}
    #   error -> error
    # end

    # Mock device for SIA processing
    device = %{
      id: Ecto.UUID.generate(),
      tenant_id: Ecto.UUID.generate(),
      account_number: account_number,
      location_id: Ecto.UUID.generate(),
      status: :online
    }

    {:ok, device}
  end

  @doc "Get queue size for monitoring"
  def get_queue_size(_queue_type) do
    # Return placeholder queue size
    42
  end

  @doc "Configure batch size for optimization"
  def configure_batch_size(_queue_type, _batch_size) do
    :ok
  end

  @doc "Configure processing interval for optimization"
  def configure_processing_interval(_queue_type, _interval) do
    :ok
  end

  @doc "Configure parallel workers for optimization"
  def configure_parallel_workers(_queue_type, _worker_count) do
    :ok
  end
end
