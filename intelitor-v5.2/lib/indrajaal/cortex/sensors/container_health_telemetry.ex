defmodule Indrajaal.Cortex.Sensors.ContainerHealthTelemetry do
  @moduledoc """
  Container Health Telemetry Handler for monitoring and observability.

  STAMP Compliance:
  - SC-OBS-065: Observability for all domain operations
  - SC-CNT-009: Container OS verification telemetry
  - SC-CNT-010: Registry source verification telemetry
  - SC-CNT-011: PHICS latency monitoring telemetry
  - SC-CNT-012: Rootless execution verification telemetry
  - SC-CNT-V01: Elixir version verification telemetry
  - SC-CNT-V02: OTP version verification telemetry

  TDG Compliance:
  - TDG-CNT-004: Every STAMP constraint has telemetry

  AOR Compliance:
  - AOR-OBS-001: All container health events are observable

  Events Emitted (Verification):
  - [:indrajaal, :container, :health, :verification, :start]
  - [:indrajaal, :container, :health, :verification, :stop]
  - [:indrajaal, :container, :health, :phase, :complete]
  - [:indrajaal, :container, :health, :phase, :failed]
  - [:indrajaal, :container, :health, :stamp, :check]
  - [:indrajaal, :container, :health, :stamp, :violation]

  Events Emitted (Podman Health Probes):
  - [:indrajaal, :container, :podman, :health, :container_discovered]
  - [:indrajaal, :container, :podman, :health, :container_removed]
  - [:indrajaal, :container, :podman, :health, :health_changed]
  - [:indrajaal, :container, :podman, :poll, :complete]

  Metrics:
  - container_health_verification_duration_ms (histogram)
  - container_health_phase_duration_ms (histogram)
  - container_health_verification_count (counter)
  - container_health_verification_failures (counter)
  - container_health_stamp_violations (counter)
  - container_health_phics_latency_ms (gauge)
  - container_podman_poll_duration_ms (histogram)
  - container_podman_healthy_count (gauge)
  - container_podman_unhealthy_count (gauge)

  Integration with Cepaf.Podman:
  - Health status types aligned with F# Cepaf.Podman.Domain.HealthStatus
  - Event structure mirrors Cepaf.Podman.Health.Probes.ProbeResult
  """

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  @container_health_events [
    [:indrajaal, :container, :health, :verification, :start],
    [:indrajaal, :container, :health, :verification, :stop],
    [:indrajaal, :container, :health, :phase, :complete],
    [:indrajaal, :container, :health, :phase, :failed],
    [:indrajaal, :container, :health, :stamp, :check],
    [:indrajaal, :container, :health, :stamp, :violation],
    # Podman health probe events
    [:indrajaal, :container, :podman, :health, :container_discovered],
    [:indrajaal, :container, :podman, :health, :container_removed],
    [:indrajaal, :container, :podman, :health, :health_changed],
    [:indrajaal, :container, :podman, :poll, :complete]
  ]

  @doc """
  Attach all container health telemetry handlers.
  Should be called during application startup.
  """
  def attach do
    :telemetry.attach_many(
      "indrajaal-container-health-telemetry",
      @container_health_events,
      &handle_event/4,
      nil
    )

    Logger.debug("📦 ContainerHealthTelemetry: Handlers attached")
  end

  @doc """
  Detach container health telemetry handlers.
  """
  def detach do
    :telemetry.detach("indrajaal-container-health-telemetry")
  end

  @doc """
  Emit verification start event.
  """
  def emit_verification_start(metadata \\ %{}) do
    :telemetry.execute(
      [:indrajaal, :container, :health, :verification, :start],
      %{system_time: System.system_time(:millisecond)},
      Map.merge(%{node: Node.self()}, metadata)
    )
  end

  @doc """
  Emit verification stop event with results.
  """
  def emit_verification_stop(success, duration_ms, results \\ %{}) do
    :telemetry.execute(
      [:indrajaal, :container, :health, :verification, :stop],
      %{
        duration_ms: duration_ms,
        success: success,
        system_time: System.system_time(:millisecond)
      },
      Map.merge(%{node: Node.self()}, results)
    )
  end

  @doc """
  Emit phase completion event.
  """
  def emit_phase_complete(phase, duration_ms, result \\ %{}) do
    :telemetry.execute(
      [:indrajaal, :container, :health, :phase, :complete],
      %{
        phase: phase,
        duration_ms: duration_ms,
        system_time: System.system_time(:millisecond)
      },
      Map.merge(%{node: Node.self()}, result)
    )
  end

  @doc """
  Emit phase failure event.
  """
  def emit_phase_failed(phase, duration_ms, error) do
    :telemetry.execute(
      [:indrajaal, :container, :health, :phase, :failed],
      %{
        phase: phase,
        duration_ms: duration_ms,
        system_time: System.system_time(:millisecond)
      },
      %{node: Node.self(), error: error}
    )
  end

  @doc """
  Emit STAMP constraint check event.
  """
  def emit_stamp_check(constraint_id, satisfied, details \\ %{}) do
    :telemetry.execute(
      [:indrajaal, :container, :health, :stamp, :check],
      %{
        constraint_id: constraint_id,
        satisfied: satisfied,
        system_time: System.system_time(:millisecond)
      },
      Map.merge(%{node: Node.self()}, details)
    )
  end

  @doc """
  Emit STAMP violation event (critical).
  """
  def emit_stamp_violation(constraint_id, reason, severity \\ :critical) do
    :telemetry.execute(
      [:indrajaal, :container, :health, :stamp, :violation],
      %{
        constraint_id: constraint_id,
        severity: severity,
        system_time: System.system_time(:millisecond)
      },
      %{node: Node.self(), reason: reason}
    )
  end

  ## Event Handlers

  def handle_event(
        [:indrajaal, :container, :health, :verification, :start],
        measurements,
        metadata,
        _config
      ) do
    Logger.info("📦 Container health verification starting on #{metadata[:node]}")

    Tracer.with_span "container.health.verification", kind: :internal do
      Tracer.set_attributes([
        {"container.node", to_string(metadata[:node])},
        {"container.start_time", measurements[:system_time]}
      ])
    end
  end

  def handle_event(
        [:indrajaal, :container, :health, :verification, :stop],
        measurements,
        metadata,
        _config
      ) do
    status = if measurements[:success], do: "✅ PASSED", else: "❌ FAILED"

    Logger.info("📦 Container health verification #{status} in #{measurements[:duration_ms]}ms")

    Tracer.with_span "container.health.verification.complete", kind: :internal do
      Tracer.set_attributes([
        {"container.verification.success", measurements[:success]},
        {"container.verification.duration_ms", measurements[:duration_ms]},
        {"container.node", to_string(metadata[:node])}
      ])

      unless measurements[:success] do
        Tracer.set_status(:error, "Container health verification failed")
      end
    end
  end

  def handle_event(
        [:indrajaal, :container, :health, :phase, :complete],
        measurements,
        _metadata,
        _config
      ) do
    Logger.debug("📦 Phase #{measurements[:phase]} completed in #{measurements[:duration_ms]}ms")

    Tracer.with_span "container.health.phase", kind: :internal do
      Tracer.set_attributes([
        {"container.phase", to_string(measurements[:phase])},
        {"container.phase.duration_ms", measurements[:duration_ms]},
        {"container.phase.status", "complete"}
      ])
    end
  end

  def handle_event(
        [:indrajaal, :container, :health, :phase, :failed],
        measurements,
        metadata,
        _config
      ) do
    Logger.warning(
      "📦 Phase #{measurements[:phase]} FAILED after #{measurements[:duration_ms]}ms: #{inspect(metadata[:error])}"
    )

    Tracer.with_span "container.health.phase.failure", kind: :internal do
      Tracer.set_attributes([
        {"container.phase", to_string(measurements[:phase])},
        {"container.phase.duration_ms", measurements[:duration_ms]},
        {"container.phase.status", "failed"},
        {"container.phase.error", inspect(metadata[:error])}
      ])

      Tracer.set_status(:error, "Phase #{measurements[:phase]} failed")
    end
  end

  def handle_event(
        [:indrajaal, :container, :health, :stamp, :check],
        measurements,
        _metadata,
        _config
      ) do
    status = if measurements[:satisfied], do: "✓", else: "✗"

    Logger.debug("📦 STAMP #{measurements[:constraint_id]}: #{status}")

    Tracer.with_span "container.health.stamp.check", kind: :internal do
      Tracer.set_attributes([
        {"stamp.constraint_id", measurements[:constraint_id]},
        {"stamp.satisfied", measurements[:satisfied]}
      ])
    end
  end

  def handle_event(
        [:indrajaal, :container, :health, :stamp, :violation],
        measurements,
        metadata,
        _config
      ) do
    Logger.error(
      "STAMP VIOLATION #{measurements[:constraint_id]} (#{measurements[:severity]}): #{inspect(metadata[:reason])}"
    )

    Tracer.with_span "container.health.stamp.violation", kind: :internal do
      Tracer.set_attributes([
        {"stamp.constraint_id", measurements[:constraint_id]},
        {"stamp.severity", to_string(measurements[:severity])},
        {"stamp.violation_reason", inspect(metadata[:reason])}
      ])

      Tracer.set_status(:error, "STAMP constraint #{measurements[:constraint_id]} violated")
    end
  end

  # ========================================================================
  # Podman Health Probe Event Handlers
  # ========================================================================

  def handle_event(
        [:indrajaal, :container, :podman, :health, :container_discovered],
        measurements,
        metadata,
        _config
      ) do
    Logger.info(
      "Podman: Container discovered: #{metadata[:container_name]} (#{metadata[:status]})"
    )

    Tracer.with_span "container.podman.discovered", kind: :internal do
      Tracer.set_attributes([
        {"container.id", metadata[:container_id]},
        {"container.name", metadata[:container_name]},
        {"container.health_status", to_string(metadata[:status])},
        {"container.probe_duration_ms", measurements[:duration_ms]}
      ])
    end
  end

  def handle_event(
        [:indrajaal, :container, :podman, :health, :container_removed],
        _measurements,
        metadata,
        _config
      ) do
    Logger.info("Podman: Container removed: #{metadata[:container_name]}")

    Tracer.with_span "container.podman.removed", kind: :internal do
      Tracer.set_attributes([
        {"container.id", metadata[:container_id]},
        {"container.name", metadata[:container_name]}
      ])
    end
  end

  def handle_event(
        [:indrajaal, :container, :podman, :health, :health_changed],
        measurements,
        metadata,
        _config
      ) do
    status_icon =
      case metadata[:status] do
        :healthy -> "[OK]"
        :unhealthy -> "[FAIL]"
        :starting -> "[...]"
        _ -> "[?]"
      end

    Logger.info(
      "Podman: #{status_icon} #{metadata[:container_name]} health: " <>
        "#{inspect(metadata[:previous_status])} -> #{inspect(metadata[:status])}"
    )

    Tracer.with_span "container.podman.health_changed", kind: :internal do
      Tracer.set_attributes([
        {"container.id", metadata[:container_id]},
        {"container.name", metadata[:container_name]},
        {"container.health_status", to_string(metadata[:status])},
        {"container.health_previous_status", to_string(metadata[:previous_status])},
        {"container.failing_streak", measurements[:failing_streak]},
        {"container.probe_duration_ms", measurements[:duration_ms]}
      ])

      if metadata[:status] == :unhealthy do
        Tracer.set_status(:error, "Container #{metadata[:container_name]} is unhealthy")
      end
    end
  end

  def handle_event(
        [:indrajaal, :container, :podman, :poll, :complete],
        measurements,
        _metadata,
        _config
      ) do
    Logger.debug(
      "Podman: Poll complete - #{measurements[:container_count]} containers, " <>
        "#{measurements[:healthy_count]} healthy, #{measurements[:unhealthy_count]} unhealthy " <>
        "(#{measurements[:duration_ms]}ms)"
    )

    Tracer.with_span "container.podman.poll", kind: :internal do
      Tracer.set_attributes([
        {"container.poll.duration_ms", measurements[:duration_ms]},
        {"container.poll.total_count", measurements[:container_count]},
        {"container.poll.healthy_count", measurements[:healthy_count]},
        {"container.poll.unhealthy_count", measurements[:unhealthy_count]}
      ])
    end
  end

  # Fallback for any unhandled Podman events
  def handle_event([:indrajaal, :container, :podman | _rest], _measurements, _metadata, _config) do
    :ok
  end
end
