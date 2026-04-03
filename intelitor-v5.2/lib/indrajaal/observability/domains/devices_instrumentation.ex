defmodule Indrajaal.Observability.Domains.DevicesInstrumentation do
  @moduledoc """
  Domain - specific instrumentation for device telemetry and status tracking.

  Provides comprehensive telemetry for:
  - Device status and health monitoring
  - Connection state and network metrics
  - Device commands and responses
  - Firmware updates and maintenance

  - Performance metrics and resource usage
  """

  use Indrajaal.Observability.InstrumentationBase,
    domain: :devices

  # EP-012: Tracing alias removed (unused)
  alias Indrajaal.Observability.{Telemetry, Logging}

  # Telemetry __events
  @device_status [:devices, :device, :status]
  @device_connected [:devices, :device, :connected]
  @device_disconnected [:devices, :device, :disconnected]
  @device_command [:devices, :command, :sent]
  @device_response [:devices, :response, :received]
  @device_health [:devices, :health, :check]
  @device_firmware [:devices, :firmware, :update]
  @device_metrics [:devices, :metrics, :reported]

  @doc """
  Sets up telemetry handlers for the Devices domain.
  """
  def setup do
    :telemetry.execute(
      [:indrajaal, :observability, :devices, :setup],
      %{timestamp: System.system_time(:millisecond)},
      %{module: __MODULE__}
    )

    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :devices, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :devices}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :devices, :metric],
      %{value: value},
      %{name: name}
    )

    :ok
  end

  def configure(_opts) do
    :ok
  end

  def get_configuration do
    {:ok,
     [
       domain: :devices,
       device_status_events: @device_status,
       device_connected_events: @device_connected,
       device_disconnected_events: @device_disconnected,
       device_command_events: @device_command,
       device_response_events: @device_response,
       device_health_events: @device_health,
       device_firmware_events: @device_firmware,
       device_metrics_events: @device_metrics
     ]}
  end

  def shutdown do
    :ok
  end

  @doc """
  Instruments device status changes with comprehensive telemetry.
  """
  def instrumentstatus_change(device, old_status, new_status, metadata \\ %{}) do
    _start_time = System.monotonic_time()

    span_ctx =
      Tracing.start_span("devices.status_change", %{
        attributes: %{
          "device.id" => device.id,
          "device.type" => device.type,
          "status.from" => old_status,
          "status.to" => new_status,
          "site.id" => device.site_id,
          "tenant.id" => device.tenant_id
        }
      })

    try do
      # Execute telemetry __event
      Telemetry.execute_telemetry(
        @device_status,
        %{
          count: 1,
          status_duration: calculate_status_duration(device, old_status)
        },
        Map.merge(metadata, %{
          device_id: device.id,
          device_type: device.type,
          old_status: old_status,
          new_status: new_status,
          site_id: device.site_id,
          tenant_id: device.tenant_id
        })
      )

      # Log status change
      log_level = determine_log_level(old_status, new_status)

      Logging.log(log_level, "Device status changed", %{
        domain: "devices",
        action: "status_change",
        device_id: device.id,
        device_type: device.type,
        old_status: old_status,
        new_status: new_status,
        metadata: metadata
      })

      # Track device availability
      track_device_availability(device, new_status)

      # Alert on critical status changes
      if critical_status_change?(old_status, new_status) do
        trigger_status_alert(device, old_status, new_status)
      end

      {:ok, device}
    rescue
      error ->
        Tracing.record_error(span_ctx, error)
        {:error, error}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @doc """
  Instruments device connection __events.
  """
  @spec instrument_connection(term(), term() | Plug.Conn.t(), term()) :: term()
  def instrument_connection(a, b, c \\ %{})

  def instrument_connection(event_name, device_id, _metadata) when is_atom(event_name) do
    :telemetry.execute([:devices, :connection], %{timestamp: System.system_time()}, %{
      device_id: device_id,
      event: event_name
    })
  end

  def instrument_connection(device, _conn, metadata) when not is_map_key(metadata, :reason) do
    span_ctx =
      Tracing.start_span("devices.connect", %{
        attributes: %{
          "device.id" => device.id,
          "connection.protocol" => metadata[:protocol],
          "connection.latency_ms" => metadata[:latency]
        }
      })

    try do
      Telemetry.execute_telemetry(
        @device_connected,
        %{
          count: 1,
          connection_time_ms: metadata[:connection_time] || 0,
          latency_ms: metadata[:latency] || 0
        },
        Map.merge(metadata, %{
          device_id: device.id,
          device_type: device.type,
          protocol: metadata[:protocol],
          ip_address: metadata[:ip_address]
        })
      )

      # Update connection metrics
      update_connection_metrics(device, :connected, metadata)

      {:ok, device}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @spec instrument_connection(term(), Plug.Conn.t(), term()) :: term()
  def instrument_connection(device, _conn, metadata) when is_map_key(metadata, :reason) do
    span_ctx =
      Tracing.start_span("devices.disconnect", %{
        attributes: %{
          "device.id" => device.id,
          "disconnect.reason" => metadata[:reason],
          "session.duration_ms" => calculate_session_duration(device)
        }
      })

    try do
      session_duration = calculate_session_duration(device)

      Telemetry.execute_telemetry(
        @device_disconnected,
        %{
          count: 1,
          session_duration_ms: session_duration
        },
        Map.merge(metadata, %{
          device_id: device.id,
          device_type: device.type,
          reason: metadata[:reason],
          session_duration_ms: session_duration
        })
      )

      # Log disconnection with appropriate level
      log_level = if metadata[:reason] in [:normal, :shutdown], do: :info, else: :warning

      Logging.log(log_level, "Device disconnected", %{
        domain: "devices",
        action: "disconnect",
        device_id: device.id,
        reason: metadata[:reason]
      })

      {:ok, device}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @doc """
  Instruments device command execution.
  """
  @spec instrument_command(term(), term(), term()) :: term()
  def instrument_command(device, command, metadata \\ %{}) do
    _start_time = System.monotonic_time()

    span_ctx =
      Tracing.start_span("devices.command", %{
        attributes: %{
          "device.id" => device.id,
          "command.type" => command.type,
          "command.id" => command.id,
          "command.priority" => command.priority
        }
      })

    try do
      Telemetry.execute_telemetry(
        @device_command,
        %{
          count: 1,
          command_size_bytes: byte_size(command.payload || "")
        },
        Map.merge(metadata, %{
          device_id: device.id,
          command_type: command.type,
          command_id: command.id,
          priority: command.priority
        })
      )

      # Start command timeout monitoring
      schedule_command_timeout(command, device)

      {:ok, command}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @doc """
  Instruments device response handling.
  """
  @spec instrument_response(term(), term(), term(), map()) :: term()
  def instrument_response(device, command_id, response, metadata \\ %{}) do
    response_time = metadata[:response_time] || 0

    span_ctx =
      Tracing.start_span("devices.response", %{
        attributes: %{
          "device.id" => device.id,
          "command.id" => command_id,
          "response.status" => response.status,
          "response.time_ms" => response_time
        }
      })

    try do
      Telemetry.execute_telemetry(
        @device_response,
        %{
          count: 1,
          response_time_ms: response_time,
          response_size_bytes: byte_size(response.payload || "")
        },
        Map.merge(metadata, %{
          device_id: device.id,
          command_id: command_id,
          status: response.status,
          response_time_ms: response_time
        })
      )

      # Cancel command timeout
      cancel_command_timeout(command_id)

      # Track command success rate
      track_command_success(device, command_id, response)

      {:ok, response}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @doc """
  Instruments device health checks.
  """
  @spec instrument_health_check(term(), term(), term()) :: term()
  def instrument_health_check(device, health_data, metadata \\ %{}) do
    span_ctx =
      Tracing.start_span("devices.health_check", %{
        attributes: %{
          "device.id" => device.id,
          "health.score" => health_data.score,
          "health.status" => health_data.status
        }
      })

    try do
      Telemetry.execute_telemetry(
        @device_health,
        %{
          health_score: health_data.score,
          cpu_usage: health_data.cpu_usage || 0,
          memory_usage: health_data.memory_usage || 0,
          disk_usage: health_data.disk_usage || 0,
          temperature: health_data.temperature || 0
        },
        Map.merge(metadata, %{
          device_id: device.id,
          health_status: health_data.status,
          check_timestamp: DateTime.utc_now()
        })
      )

      # Alert on health issues
      if health_data.status in [:warning, :critical] do
        trigger_health_alert(device, health_data)
      end

      # Track health trends
      track_health_trends(device, health_data)

      {:ok, health_data}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @doc """
  Instruments firmware update operations.
  """
  @spec instrument_firmware_update(term(), term(), term()) :: term()
  def instrument_firmware_update(device, update_info, metadata \\ %{}) do
    span_ctx =
      Tracing.start_span("devices.firmware_update", %{
        attributes: %{
          "device.id" => device.id,
          "firmware.current" => update_info.current_version,
          "firmware.target" => update_info.target_version,
          "update.size_bytes" => update_info.size_bytes
        }
      })

    try do
      Telemetry.execute_telemetry(
        @device_firmware,
        %{
          count: 1,
          update_size_bytes: update_info.size_bytes,
          version_distance:
            calculate_version_distance(
              update_info.current_version,
              update_info.target_version
            )
        },
        Map.merge(metadata, %{
          device_id: device.id,
          current_version: update_info.current_version,
          target_version: update_info.target_version,
          update_type: update_info.type
        })
      )

      Logging.info("Firmware update initiated", %{
        domain: "devices",
        action: "firmware_update",
        device_id: device.id,
        update_info: update_info
      })

      # Track firmware update progress
      track_firmware_progress(device, update_info)

      {:ok, update_info}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @doc """
  Instruments device metrics reporting.
  """
  @spec instrument_metrics(term(), term(), term()) :: term()
  def instrument_metrics(device, metrics, metadata \\ %{}) do
    Telemetry.execute_telemetry(
      @device_metrics,
      Map.merge(metrics, %{count: 1}),
      Map.merge(metadata, %{
        device_id: device.id,
        device_type: device.type,
        timestamp: DateTime.utc_now()
      })
    )

    # Process specific metric types
    process_performance_metrics(device, metrics)
    process_network_metrics(device, metrics)
    process_sensor_metrics(device, metrics)
  end

  # Private functions

  @spec calculate_status_duration(term(), term()) :: term()
  defp calculate_status_duration(device, status) do
    case device.status_history do
      [%{status: ^status, timestamp: entered_at} | _] ->
        DateTime.diff(DateTime.utc_now(), entered_at, :millisecond)

      _ ->
        0
    end
  end

  @spec determine_log_level(term(), term()) :: term()
  defp determine_log_level(:online, :offline), do: :warning
  defp determine_log_level(:online, :error), do: :error
  defp determine_log_level(:offline, :online), do: :info
  @spec determine_log_level(term(), term()) :: term()
  defp determine_log_level(_, _), do: :info

  defp critical_status_change?(
         :online,
         status
       )
       when status in [:error, :offline],
       do: true

  @spec critical_status_change?(term(), term()) :: term()
  defp critical_status_change?(_, :error), do: true
  defp critical_status_change?(_, _), do: false

  @spec track_device_availability(term(), term()) :: term()
  defp track_device_availability(device, status) do
    availability =
      case status do
        :online -> 1.0
        :offline -> 0.0
        :maintenance -> 0.5
        _ -> 0.0
      end

    Telemetry.execute_telemetry(
      [:devices, :availability],
      %{
        value: availability
      },
      %{
        device_id: device.id,
        device_type: device.type,
        status: status
      }
    )
  end

  defp trigger_status_alert(device, old_status, new_status) do
    alert_metadata = %{
      device_id: device.id,
      device_type: device.type,
      old_status: old_status,
      new_status: new_status,
      site_id: device.site_id,
      alert_type: :device_status_critical
    }

    # Integrate with alarm system
    Telemetry.execute_telemetry([:devices, :alert, :triggered], %{count: 1}, alert_metadata)
  end

  defp update_connection_metrics(device, state, metadata) do
    metrics = %{
      latency_ms: metadata[:latency] || 0,
      packet_loss: metadata[:packet_loss] || 0.0,
      signal_strength: metadata[:signal_strength] || 0
    }

    Telemetry.execute_telemetry([:devices, :connection, :metrics], metrics, %{
      device_id: device.id,
      connection_state: state
    })
  end

  @spec calculate_session_duration(term()) :: term()
  defp calculate_session_duration(device) do
    case device.last_connected_at do
      nil -> 0
      timestamp -> DateTime.diff(DateTime.utc_now(), timestamp, :millisecond)
    end
  end

  @spec schedule_command_timeout(term(), term()) :: term()
  defp schedule_command_timeout(command, device) do
    # Default 30 seconds
    timeout = command[:timeout] || 30_000

    Process.send_after(self(), {:command_timeout, command.id, device.id}, timeout)
  end

  @spec cancel_command_timeout(term()) :: term()
  defp cancel_command_timeout(_commandid) do
    # Cancel timeout timer
    # Implementation depends on timer management strategy
  end

  defp track_command_success(device, command_id, response) do
    success = response.status in [:ok, :success]

    Telemetry.execute_telemetry(
      [:devices, :command, :result],
      %{
        success: if(success, do: 1, else: 0),
        failure: if(success, do: 0, else: 1)
      },
      %{
        device_id: device.id,
        command_id: command_id,
        status: response.status
      }
    )
  end

  @spec trigger_health_alert(term(), term()) :: term()
  defp trigger_health_alert(device, health_data) do
    Logging.warning("Device health issue detected", %{
      domain: "devices",
      action: "health_alert",
      device_id: device.id,
      health_status: health_data.status,
      health_score: health_data.score,
      issues: health_data.issues
    })
  end

  @spec track_health_trends(term(), term()) :: term()
  defp track_health_trends(device, health_data) do
    # Store health metrics for trend analysis
    trend_metrics = %{
      cpu_trend: calculate_trend(device.id, :cpu_usage, health_data.cpu_usage),
      memory_trend: calculate_trend(device.id, :memory_usage, health_data.memory_usage),
      disk_trend: calculate_trend(device.id, :disk_usage, health_data.disk_usage)
    }

    Telemetry.execute_telemetry([:devices, :health, :trends], trend_metrics, %{
      device_id: device.id
    })
  end

  @spec calculate_version_distance(term(), term()) :: term()
  defp calculate_version_distance(current, target) do
    # Simple version distance calculation
    # Could be enhanced with semantic versioning
    if current == target, do: 0, else: 1
  end

  @spec track_firmware_progress(term(), term()) :: term()
  defp track_firmware_progress(device, update_info) do
    # Track firmware update stages
    Telemetry.execute_telemetry(
      [:devices, :firmware, :progress],
      %{
        stage: update_info.stage,
        progress_percent: update_info.progress || 0
      },
      %{
        device_id: device.id,
        update_id: update_info.id
      }
    )
  end

  @spec process_performance_metrics(term(), term()) :: term()
  defp process_performance_metrics(device, metrics) do
    performance_metrics =
      Map.take(metrics, [:cpu_usage, :memory_usage, :disk_usage, :temperature])

    unless Enum.empty?(performance_metrics) do
      Telemetry.execute_telemetry([:devices, :performance], performance_metrics, %{
        device_id: device.id,
        device_type: device.type
      })
    end
  end

  @spec process_network_metrics(term(), term()) :: term()
  defp process_network_metrics(device, metrics) do
    network_metrics =
      Map.take(metrics, [:bandwidth_usage, :packet_loss, :latency, :signal_strength])

    unless Enum.empty?(network_metrics) do
      Telemetry.execute_telemetry([:devices, :network], network_metrics, %{
        device_id: device.id,
        device_type: device.type
      })
    end
  end

  @spec process_sensor_metrics(term(), term()) :: term()
  defp process_sensor_metrics(device, metrics) do
    sensor_metrics =
      Map.drop(metrics, [
        :cpu_usage,
        :memory_usage,
        :disk_usage,
        :temperature,
        :bandwidth_usage,
        :packet_loss,
        :latency,
        :signal_strength
      ])

    unless Enum.empty?(sensor_metrics) do
      Telemetry.execute_telemetry([:devices, :sensors], sensor_metrics, %{
        device_id: device.id,
        device_type: device.type
      })
    end
  end

  defp calculate_trend(_device_id, _metric_type, _current_value) do
    # Implement trend calculation based on historical data
    # This is a placeholder
    0.0
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
