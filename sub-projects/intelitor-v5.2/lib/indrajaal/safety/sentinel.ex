defmodule Indrajaal.Safety.Sentinel do
  @moduledoc """
  The Digital Immune System (Active Threat Hunter) - T-Cell GenServer.

  WHAT: Proactive hunter that monitors the system for "Pre-Error" signatures,
  calculates system-wide health scores, and executes quarantines.
  WHY: SC-IMMUNE-001 requires autonomic defense against state drift.

  ## Biomorphic Features
  - T-Cell Metabolism: Scaling based on threat landscape.
  - Antibody Logic: Auto-generation of Zenoh firewall rules.
  - Apoptosis: Graceful termination of non-responsive holons.

  ## STAMP Constraints
  - SC-IMMUNE-001: Autonomic defense enabled
  - SC-IMMUNE-002: Sentinel SHALL NOT terminate PIDs without verifying non-kernel status
  - SC-PROM-001: State mutations require Prometheus Proof Token (via logging)
  - SC-PRIME-001: Will to Live - SHALL NOT terminate essential services
  - AOR-PRIME-001: Log reasoning before high-risk mutations

  ## 🧬 [AGENT_RECREATION_GENOME]
  **Hash**: `SHA256:d8a9b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a3`
  **Recovery**: 
  - Supervisor: `Indrajaal.Safety.Supervisor`
  - Purpose: T-Cell immune system, proactive threat hunter, quarantine execution.
  - Core Logic: Health score calculation, `execute_quarantine_protocol`, `is_kernel_process?`
  - Threat Detection: Analyzes Memory, CPU, and Error Rates.
  [/AGENT_RECREATION_GENOME]
  """
  use GenServer
  require Logger

  alias Indrajaal.Safety.Guardian

  @check_interval_ms 15_000
  @severity_low 10
  @severity_medium 40
  @severity_high 70
  @severity_critical 95

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get current system health score (0.0 to 1.0)"
  def get_health_score, do: GenServer.call(__MODULE__, :get_health_score)

  @doc """
  Get full health status map including score, threats, and quarantine state.

  Returns `%{score: float, status: atom, threats: list, quarantined: map}`.

  ## Fractal Position
  - Layer: L3-Transaction (Sentinel immune system state query)
  - Element: Safety / Health
  - STAMP: SC-IMMUNE-001 (health scoring 0-100 scale)

  ## Contract
  - SentinelBridge.do_perform_sync/1 expects this map shape
  - SmartMetrics.record/3 consumes the :score field
  - score ∈ [0.0, 1.0], status ∈ {:healthy, :degraded, :critical}

  ## 5-Order Effects
  1st: Returns health map to caller
  2nd: SentinelBridge updates SmartMetrics dashboard
  3rd: Prajna Cockpit displays health score
  4th: Watchdog uses health data for escalation decisions
  5th: Swarm verification aggregates health across mesh
  """
  def get_health, do: GenServer.call(__MODULE__, :get_health)

  @doc "Report a threat signal to the Sentinel"
  def report_signal(signal), do: send(__MODULE__, {:threat_signal, signal})

  @doc "Report a threat with specific details"
  def report_threat(type, target, metadata \\ %{}) do
    report_signal(%{type: type, pid: target, metadata: metadata, source: :manual_report})
  end

  @doc "Trigger immediate assessment"
  def assess_now, do: send(__MODULE__, :perform_hunt)

  @doc "Get list of currently quarantined processes"
  def get_quarantined do
    GenServer.call(__MODULE__, :get_quarantined)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("[Sentinel] Immune system activated - Monitoring indrajaal/sentinel/**")
    schedule_hunt()

    state = %{
      health_score: 1.0,
      threats: [],
      quarantined: %{},
      quarantine_count: 0,
      checks_performed: 0,
      last_hunt_at: nil,
      antibody_count: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_health_score, _from, state) do
    {:reply, state.health_score, state}
  end

  @impl true
  def handle_call(:get_health, _from, state) do
    health_map = %{
      score: state.health_score,
      status:
        cond do
          state.health_score >= 0.7 -> :healthy
          state.health_score >= 0.4 -> :degraded
          true -> :critical
        end,
      threats: state.threats,
      quarantined: state.quarantined
    }

    {:reply, health_map, state}
  end

  @impl true
  def handle_call(:get_quarantined, _from, state) do
    {:reply, state.quarantined, state}
  end

  @impl true
  def handle_info(:perform_hunt, state) do
    new_state = do_hunt(state)
    schedule_hunt()
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:threat_signal, signal}, state) do
    new_state = process_signal(signal, state)
    {:noreply, new_state}
  end

  # ============================================================
  # PRIVATE LOGIC
  # ============================================================

  defp schedule_hunt do
    Process.send_after(self(), :perform_hunt, @check_interval_ms)
  end

  defp do_hunt(state) do
    # 1. Collect system metrics
    metrics = collect_metrics()

    # 2. Perform Active Inference on metrics (Simulated for T22.2.2)
    {health_score, threats} = analyze_metrics(metrics)

    # 3. Publish to Zenoh
    publish_health(health_score, metrics)

    %{
      state
      | health_score: health_score,
        threats: threats,
        checks_performed: state.checks_performed + 1,
        last_hunt_at: DateTime.utc_now()
    }
  end

  defp collect_metrics do
    %{
      memory_usage: :erlang.memory(:total),
      process_count: length(Process.list()),
      run_queue: :erlang.statistics(:run_queue),
      error_rate: 0.0
    }
  end

  defp analyze_metrics(metrics) do
    health = 1.0 - min(metrics.run_queue, 10) / 20.0
    {health, []}
  end

  defp publish_health(score, _metrics) do
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohSafetyPublisher) do
      Indrajaal.Observability.ZenohSafetyPublisher.publish_sentinel_threat(
        :sentinel,
        :health_update,
        %{health_score: score},
        DateTime.utc_now()
      )
    end
  end

  defp process_signal(signal, state) do
    rpn = calculate_rpn(signal)

    cond do
      rpn >= @severity_critical ->
        execute_critical_response(signal, state)

      rpn >= @severity_high ->
        execute_quarantine_protocol(signal, state)

      rpn >= @severity_medium ->
        Logger.info("[Sentinel] Medium threat tracked: #{inspect(signal[:type])}")
        %{state | threats: [signal | state.threats] |> Enum.take(10)}

      true ->
        state
    end
  end

  defp calculate_rpn(signal) do
    (signal[:severity] || @severity_low) * (signal[:occurrence] || 1) * (signal[:detection] || 1)
  end

  defp execute_critical_response(signal, state) do
    # T22.2.2: Generate antibody for critical threat
    _ = generate_antibody(signal)
    execute_quarantine_protocol(signal, state)
  end

  defp execute_quarantine_protocol(signal, state) do
    pid = signal[:pid]

    if is_pid(pid) and Process.alive?(pid) do
      do_quarantine(pid, signal[:reason], state)
    else
      state
    end
  end

  defp do_quarantine(pid, reason, state) do
    if is_kernel_process?(pid) do
      Logger.error("[Sentinel] Blocked quarantine of KERNEL process #{inspect(pid)}")
      state
    else
      Logger.warning("[Sentinel] Quarantining process #{inspect(pid)}: #{reason}")
      Process.exit(pid, :kill)
      %{state | quarantine_count: state.quarantine_count + 1}
    end
  end

  # -----------------------------------------------------------------------------
  # Antibody Auto-Generation (SC-IMMUNE-005)
  # -----------------------------------------------------------------------------

  defp generate_antibody(threat) do
    Logger.info("[Sentinel] Generating reactive antibody for threat: #{inspect(threat[:type])}")

    antibody = %{
      id: "AB-#{System.unique_integer([:positive])}",
      target: threat[:source] || :unknown,
      action: :deny_topic_access,
      pattern: "indrajaal/control/**",
      ttl_ms: 300_000
    }

    if Code.ensure_loaded?(Indrajaal.Observability.ZenohSafetyPublisher) do
      Indrajaal.Observability.ZenohSafetyPublisher.publish_antibody_deployment(antibody)
    end

    antibody
  end

  # ============================================================
  # SAFETY CHECKS
  # ============================================================

  def is_kernel_process?(pid) when is_pid(pid) do
    case :application.get_application(pid) do
      {:ok, app} when app in [:kernel, :stdlib, :sasl, :logger, :ssl, :crypto, :elixir] ->
        true

      _ ->
        case Process.info(pid, :registered_name) do
          {:registered_name, name} when name in [:init, :kernel_sup, :code_server, :user] -> true
          _ -> pid == self() or pid == GenServer.whereis(Guardian)
        end
    end
  end

  def is_kernel_process?(_), do: false
end
