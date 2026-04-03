defmodule Indrajaal.Core.VSM.System3StarAudit do
  @moduledoc """
  VSM System 3* (Three-Star): Sporadic Audit Channel

  ## What
  Implements Beer's System 3* — the audit/monitoring channel that sporadically
  checks System 1 operations against System 3 directives. Unlike the continuous
  control of System 3, S3* performs deep-dive audits on a 30-second cycle.

  ## Why
  - GAP-P2-004: VSM supervision tree requires S3* for complete VSM implementation
  - SC-VSM-001: All 5 systems MUST be supervised
  - SC-S3-003: Anomalies MUST be reported within 10ms

  ## Audit Checks
  1. **Resource Audit**: Compare actual vs budgeted resource usage
  2. **Process Health**: Verify critical processes are alive
  3. **Sentinel Sync**: Cross-reference with immune system health
  4. **Oscillation Check**: Detect coordination instability via System 2

  ## STAMP Constraints
  - SC-S3-001: Budget MUST be enforced atomically
  - SC-S3-003: Anomalies MUST be reported within 10ms
  - SC-VSM-001: All 5 systems supervised
  - SC-MATH-004: VSM discipline CONNECTED

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-03-21 | Claude | Initial implementation (GAP-P2-004) |
  """

  use GenServer

  require Logger

  alias Indrajaal.Core.VSM.System3Control

  @name __MODULE__
  @audit_interval_ms 30_000
  @zenoh_topic "indrajaal/vsm/s3star/audit"
  @checkpoint "CP-VSM-S3STAR-01"

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Returns the most recent audit result."
  @spec last_audit() :: map() | nil
  def last_audit do
    GenServer.call(@name, :last_audit)
  end

  @doc "Forces an immediate audit cycle."
  @spec audit_now() :: :ok
  def audit_now do
    GenServer.cast(@name, :audit_now)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    schedule_audit()

    state = %{
      last_audit: nil,
      audit_count: 0,
      anomaly_count: 0
    }

    # Warning level ensures visibility even with compile_time_purge_matching in test.exs
    Logger.warning("[S3*] System 3-Star Audit started — interval=#{@audit_interval_ms}ms")
    {:ok, state}
  end

  @impl true
  def handle_info(:audit_tick, state) do
    new_state = run_audit(state)
    schedule_audit()
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:last_audit, _from, state) do
    {:reply, state.last_audit, state}
  end

  @impl true
  def handle_cast(:audit_now, state) do
    new_state = run_audit(state)
    {:noreply, new_state}
  end

  # ---------------------------------------------------------------------------
  # Private — audit logic
  # ---------------------------------------------------------------------------

  defp schedule_audit do
    Process.send_after(self(), :audit_tick, @audit_interval_ms)
  end

  defp run_audit(state) do
    start_us = System.monotonic_time(:microsecond)

    # 1. Resource audit — check budget compliance
    resource_audit = audit_resources()

    # 2. Process health — verify critical supervision tree processes
    process_audit = audit_processes()

    # 3. Sentinel sync — cross-reference immune system
    sentinel_audit = audit_sentinel()

    # 4. System 2 oscillation check
    oscillation_audit = audit_oscillation()

    duration_us = System.monotonic_time(:microsecond) - start_us

    anomalies =
      Enum.concat([
        resource_audit.anomalies,
        process_audit.anomalies,
        sentinel_audit.anomalies,
        oscillation_audit.anomalies
      ])

    audit_result = %{
      timestamp: DateTime.utc_now(),
      duration_us: duration_us,
      resource: resource_audit,
      process: process_audit,
      sentinel: sentinel_audit,
      oscillation: oscillation_audit,
      anomaly_count: length(anomalies),
      anomalies: anomalies,
      status: if(anomalies == [], do: :clean, else: :anomalies_found)
    }

    # SC-ZTEST-008: log fallback FIRST (guaranteed durability), then Zenoh
    log_checkpoint(audit_result, duration_us)
    publish_audit(audit_result)
    emit_telemetry(audit_result, state.audit_count + 1)

    # Report anomalies to Guardian if critical
    if Enum.any?(anomalies, fn a -> a.severity == :critical end) do
      report_to_guardian(anomalies)
    end

    new_anomaly_count = state.anomaly_count + length(anomalies)

    %{
      state
      | last_audit: audit_result,
        audit_count: state.audit_count + 1,
        anomaly_count: new_anomaly_count
    }
  end

  defp audit_resources do
    try do
      control_state = System3Control.new()
      {budget_status, _} = System3Control.check_budget(control_state)

      memory_mb = div(:erlang.memory(:total), 1_048_576)
      schedulers = :erlang.system_info(:schedulers_online)
      run_queue = :erlang.statistics(:run_queue)
      cpu_load = min(1.0, run_queue / max(1, schedulers))

      anomalies =
        []
        |> maybe_add(memory_mb > 1_500, %{
          type: :high_memory,
          severity: :critical,
          value: memory_mb,
          threshold: 1_500,
          message: "Memory usage #{memory_mb}MB exceeds 1500MB"
        })
        |> maybe_add(cpu_load > 0.9, %{
          type: :high_cpu,
          severity: :critical,
          value: cpu_load,
          threshold: 0.9,
          message: "CPU load #{Float.round(cpu_load, 2)} exceeds 0.9"
        })

      %{
        status: budget_status,
        memory_mb: memory_mb,
        cpu_load: Float.round(cpu_load, 3),
        anomalies: anomalies
      }
    rescue
      _ -> %{status: :unknown, memory_mb: 0, cpu_load: 0.0, anomalies: []}
    end
  end

  defp audit_processes do
    critical_names = [
      Indrajaal.PubSub,
      Indrajaal.Core.VSM.System2Coordinator
    ]

    missing =
      Enum.filter(critical_names, fn name ->
        Process.whereis(name) == nil
      end)

    anomalies =
      Enum.map(missing, fn name ->
        %{
          type: :process_missing,
          severity: :critical,
          value: name,
          message: "Critical process #{inspect(name)} not found"
        }
      end)

    process_count = length(:erlang.processes())

    %{
      process_count: process_count,
      critical_missing: length(missing),
      anomalies: anomalies
    }
  end

  defp audit_sentinel do
    try do
      case Indrajaal.Safety.Sentinel.get_health() do
        %{status: :critical} = health ->
          %{
            status: :critical,
            health: health,
            anomalies: [
              %{
                type: :sentinel_critical,
                severity: :critical,
                value: health,
                message: "Sentinel reports critical health"
              }
            ]
          }

        health when is_map(health) ->
          %{status: Map.get(health, :status, :unknown), health: health, anomalies: []}

        _ ->
          %{status: :unknown, health: %{}, anomalies: []}
      end
    rescue
      _ -> %{status: :unavailable, health: %{}, anomalies: []}
    end
  end

  defp audit_oscillation do
    try do
      summary = Indrajaal.Core.VSM.System2Coordinator.get_summary()
      oscillating = Map.get(summary, :oscillation_detected, false)
      dampening = Map.get(summary, :dampening_active, false)

      anomalies =
        if oscillating do
          [
            %{
              type: :oscillation_detected,
              severity: :high,
              value: summary,
              message: "System 2 coordination oscillation detected, dampening=#{dampening}"
            }
          ]
        else
          []
        end

      %{oscillating: oscillating, dampening: dampening, anomalies: anomalies}
    rescue
      _ -> %{oscillating: false, dampening: false, anomalies: []}
    catch
      :exit, _ -> %{oscillating: false, dampening: false, anomalies: []}
    end
  end

  defp maybe_add(list, false, _item), do: list
  defp maybe_add(list, true, item), do: [item | list]

  defp publish_audit(result) do
    payload = %{
      checkpoint: @checkpoint,
      topic: @zenoh_topic,
      status: result.status,
      anomaly_count: result.anomaly_count,
      duration_us: result.duration_us,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(@zenoh_topic, payload)
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(result, audit_count) do
    :telemetry.execute(
      [:indrajaal, :vsm, :s3star, :audit],
      %{
        duration_us: result.duration_us,
        anomaly_count: result.anomaly_count
      },
      %{
        audit_count: audit_count,
        status: result.status
      }
    )
  end

  defp log_checkpoint(result, duration_us) do
    # SC-ZTEST-008: CRITICAL safety fallback — must survive compile_time_purge_matching
    # Uses Logger.warning to ensure checkpoint log is never purged in test environment
    Logger.warning(
      "[ZTEST-CHECKPOINT] checkpoint=#{@checkpoint} topic=#{@zenoh_topic} " <>
        "status=#{result.status} anomalies=#{result.anomaly_count} " <>
        "duration_us=#{duration_us} timestamp=#{DateTime.utc_now() |> DateTime.to_iso8601()}"
    )
  end

  defp report_to_guardian(anomalies) do
    try do
      Indrajaal.Safety.Guardian.report_threat(%{
        type: :s3star_audit_critical,
        severity: :critical,
        source: __MODULE__,
        metadata: %{anomaly_count: length(anomalies), anomalies: anomalies}
      })
    rescue
      _ -> :ok
    end
  end
end
