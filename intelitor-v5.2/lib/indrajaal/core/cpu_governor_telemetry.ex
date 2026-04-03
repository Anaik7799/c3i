defmodule Indrajaal.Core.CpuGovernorTelemetry do
  @moduledoc """
  Telemetry handler for CPU Governor events.

  Attaches to `:telemetry` events emitted by `Indrajaal.Core.CpuGovernor`
  and converts them to OpenTelemetry metrics for the OTEL pipeline.

  **Events handled**:
  - `[:indrajaal, :cpu_governor, :check]` — periodic CPU check (every 2s)

  **OTEL Metrics produced**:
  - `indrajaal.cpu_governor.cpu_pct` (gauge)
  - `indrajaal.cpu_governor.ewma_cpu` (gauge)
  - `indrajaal.cpu_governor.schedulers` (gauge)
  - `indrajaal.cpu_governor.entropy` (gauge)
  - `indrajaal.cpu_governor.pid_output` (gauge)

  **Compliance**: SC-CPU-GOV-001, SC-OBS-069, SC-TEL-001
  """

  require Logger

  @handler_id "cpu-governor-telemetry"

  @doc "Attach telemetry handlers for OTEL integration."
  @spec attach_handlers() :: :ok
  def attach_handlers do
    events = [
      [:indrajaal, :cpu_governor, :check]
    ]

    :telemetry.attach_many(
      @handler_id,
      events,
      &handle_event/4,
      nil
    )

    :ok
  end

  @doc "Detach telemetry handlers."
  @spec detach_handlers() :: :ok | {:error, :not_found}
  def detach_handlers do
    :telemetry.detach(@handler_id)
  end

  @doc false
  def handle_event([:indrajaal, :cpu_governor, :check], measurements, metadata, _config) do
    # Forward to OpenTelemetry if available
    if Code.ensure_loaded?(OpenTelemetry.Tracer) do
      try do
        require OpenTelemetry.Tracer

        OpenTelemetry.Tracer.with_span "cpu_governor.check" do
          OpenTelemetry.Tracer.set_attributes([
            {"cpu.percent", measurements.cpu_pct},
            {"cpu.ewma", measurements.ewma_cpu},
            {"cpu.schedulers", measurements.schedulers},
            {"cpu.jobs", measurements.jobs},
            {"cpu.entropy", measurements.entropy},
            {"cpu.pid_output", measurements.pid_output},
            {"cpu.mode", Atom.to_string(metadata.mode)},
            {"cpu.over_limit", metadata.over_limit},
            {"stamp.constraint", metadata.constraint}
          ])
        end
      rescue
        _ -> :ok
      end
    end

    # Log at L2-FIBER level for detailed operations (24-hour retention)
    if measurements.cpu_pct > 80 do
      Logger.warning(
        "[CpuGovernorTelemetry] High CPU: #{measurements.cpu_pct}% " <>
          "(mode=#{metadata.mode}, sched=#{measurements.schedulers}) [SC-CPU-GOV-004]",
        domain: [:cpu_governor],
        cpu_pct: measurements.cpu_pct,
        mode: metadata.mode,
        schedulers: measurements.schedulers
      )
    end
  end
end
