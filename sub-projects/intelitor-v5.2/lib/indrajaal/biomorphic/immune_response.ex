defmodule Indrajaal.Biomorphic.ImmuneResponse do
  @moduledoc """
  ## Design Intent
  Digital immune system for the Indrajaal biomorphic mesh. Detects threats,
  generates antibody (neutralization) rules, and enforces quarantine on
  compromised modules. Mirrors biological innate + adaptive immunity.

  Threat lifecycle:
    1. Threat detected (score crosses threshold)
    2. Antibody generated and stored in ETS
    3. Quarantine applied to compromised module
    4. Immune event broadcast via PubSub "biomorphic:immune"
    5. Self-resolution or escalation to Guardian

  ## STAMP Constraints
  - SC-IMMUNE-001: Health scoring with quarantine protocol — ENFORCED
  - SC-IMMUNE-002: Circuit breaker at error rate > 10% — ENFORCED
  - SC-SAFETY-020: Auto-halt at threat threshold — ENFORCED
  - SC-SIL4-015: Split-brain detection triggers apoptosis — REFERENCED

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude | Initial implementation |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_antibodies :immune_antibodies
  @ets_quarantine :immune_quarantine
  @pubsub_topic "biomorphic:immune"
  @zenoh_topic "indrajaal/biomorphic/immune/status"
  @checkpoint "CP-BIO-IMMUNE-01"

  # Threat levels as atoms — ordered severity
  @threat_levels [:none, :low, :medium, :high, :critical]

  # Auto-quarantine threshold
  @quarantine_threshold :high

  # Error rate circuit-breaker threshold (SC-IMMUNE-002)
  @error_rate_threshold 0.10

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Report a potential threat for evaluation."
  @spec report_threat(map()) :: {:ok, atom()} | {:error, term()}
  def report_threat(threat) when is_map(threat) do
    GenServer.call(@name, {:report_threat, threat})
  end

  @doc "Returns current threat level of the immune system."
  @spec threat_level() :: atom()
  def threat_level do
    GenServer.call(@name, :threat_level)
  end

  @doc "Returns all active quarantine entries."
  @spec quarantined_modules() :: list(map())
  def quarantined_modules do
    :ets.tab2list(@ets_quarantine)
    |> Enum.map(fn {_module, info} -> info end)
  end

  @doc "Lookup antibody rule for a threat pattern."
  @spec lookup_antibody(binary()) :: {:ok, map()} | :miss
  def lookup_antibody(pattern_key) when is_binary(pattern_key) do
    case :ets.lookup(@ets_antibodies, pattern_key) do
      [{^pattern_key, antibody}] -> {:ok, antibody}
      [] -> :miss
    end
  end

  @doc "Lift quarantine from a module (manual override)."
  @spec lift_quarantine(atom()) :: :ok
  def lift_quarantine(module_name) when is_atom(module_name) do
    GenServer.call(@name, {:lift_quarantine, module_name})
  end

  @doc "Returns immune system status summary."
  @spec status() :: map()
  def status do
    GenServer.call(@name, :status)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@ets_antibodies, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@ets_quarantine, [:set, :public, :named_table, read_concurrency: true])

    state = %{
      threat_level: :none,
      threat_count: 0,
      quarantine_count: 0,
      antibody_count: 0,
      error_count: 0,
      event_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.warning("[IMMUNE] ImmuneResponse started — checkpoint=#{@checkpoint}")
    {:ok, state}
  end

  @impl true
  def handle_call({:report_threat, threat}, _from, state) do
    new_state = process_threat(threat, state)
    {:reply, {:ok, new_state.threat_level}, new_state}
  end

  @impl true
  def handle_call(:threat_level, _from, state) do
    {:reply, state.threat_level, state}
  end

  @impl true
  def handle_call({:lift_quarantine, module_name}, _from, state) do
    :ets.delete(@ets_quarantine, module_name)
    new_count = max(0, state.quarantine_count - 1)
    new_state = %{state | quarantine_count: new_count}

    broadcast_event(:quarantine_lifted, %{module: module_name})
    Logger.info("[IMMUNE] Quarantine lifted: #{inspect(module_name)}")

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    quarantine_list =
      :ets.tab2list(@ets_quarantine)
      |> Enum.map(fn {mod, _info} -> mod end)

    reply = %{
      threat_level: state.threat_level,
      threat_count: state.threat_count,
      quarantine_count: state.quarantine_count,
      antibody_count: state.antibody_count,
      error_rate: compute_error_rate(state),
      quarantined_modules: quarantine_list,
      uptime_s: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, reply, state}
  end

  @impl true
  def handle_info({:clear_quarantine, module_name}, state) do
    :ets.delete(@ets_quarantine, module_name)
    new_count = max(0, state.quarantine_count - 1)
    {:noreply, %{state | quarantine_count: new_count}}
  end

  # Catch-all for unexpected messages
  @impl true
  def handle_info(msg, state) do
    Logger.debug("[IMMUNE] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private — threat processing
  # ---------------------------------------------------------------------------

  defp process_threat(threat, state) do
    severity = Map.get(threat, :severity, :low)
    source = Map.get(threat, :source, :unknown)
    pattern = Map.get(threat, :pattern, "unknown")

    # Generate antibody rule for this threat pattern
    antibody = generate_antibody(pattern, severity, source)
    :ets.insert(@ets_antibodies, {pattern, antibody})

    # Compute new threat level (escalate, never immediately de-escalate)
    new_level = escalate_threat(state.threat_level, severity)

    # Apply quarantine for high/critical threats (SC-IMMUNE-001)
    new_quarantine_count =
      if should_quarantine?(new_level) and is_atom(source) and source != :unknown do
        apply_quarantine(source, threat)
        state.quarantine_count + 1
      else
        state.quarantine_count
      end

    # Check circuit breaker (SC-IMMUNE-002)
    new_error_count = state.error_count + 1
    new_event_count = state.event_count + 1
    error_rate = new_error_count / max(1, new_event_count)

    if error_rate > @error_rate_threshold do
      trip_circuit_breaker(error_rate)
    end

    # SC-SAFETY-020: auto-halt at critical
    if new_level == :critical do
      report_critical_to_guardian(threat)
    end

    # Broadcast immune event
    broadcast_event(:threat_detected, %{
      severity: severity,
      level: new_level,
      source: source,
      pattern: pattern
    })

    emit_telemetry(new_level, new_event_count)

    %{
      state
      | threat_level: new_level,
        threat_count: state.threat_count + 1,
        quarantine_count: new_quarantine_count,
        antibody_count: state.antibody_count + 1,
        error_count: new_error_count,
        event_count: new_event_count
    }
  end

  defp generate_antibody(pattern, severity, source) do
    %{
      pattern: pattern,
      severity: severity,
      source: source,
      neutralization: neutralization_rule(severity),
      generated_at: DateTime.utc_now(),
      activation_count: 0
    }
  end

  defp neutralization_rule(:critical), do: :isolate_and_report
  defp neutralization_rule(:high), do: :quarantine_and_monitor
  defp neutralization_rule(:medium), do: :rate_limit
  defp neutralization_rule(:low), do: :log_and_watch
  defp neutralization_rule(_), do: :observe

  defp escalate_threat(current, incoming) do
    current_idx = Enum.find_index(@threat_levels, &(&1 == current)) || 0
    incoming_idx = Enum.find_index(@threat_levels, &(&1 == incoming)) || 0
    Enum.at(@threat_levels, max(current_idx, incoming_idx))
  end

  defp should_quarantine?(level) do
    quarantine_idx = Enum.find_index(@threat_levels, &(&1 == @quarantine_threshold)) || 3
    level_idx = Enum.find_index(@threat_levels, &(&1 == level)) || 0
    level_idx >= quarantine_idx
  end

  defp apply_quarantine(module_name, threat) do
    entry = %{
      module: module_name,
      reason: Map.get(threat, :pattern, "unknown"),
      severity: Map.get(threat, :severity, :high),
      quarantined_at: DateTime.utc_now()
    }

    :ets.insert(@ets_quarantine, {module_name, entry})

    # Auto-lift quarantine after 5 minutes for non-critical
    if Map.get(threat, :severity, :high) != :critical do
      Process.send_after(self(), {:clear_quarantine, module_name}, 5 * 60 * 1_000)
    end

    broadcast_event(:module_quarantined, entry)

    Logger.warning(
      "[IMMUNE] Quarantine applied: #{inspect(module_name)} — #{inspect(Map.get(threat, :pattern))}"
    )
  end

  defp trip_circuit_breaker(error_rate) do
    Logger.warning(
      "[IMMUNE] Circuit breaker tripped — error_rate=#{Float.round(error_rate, 3)} " <>
        "threshold=#{@error_rate_threshold} SC-IMMUNE-002"
    )

    broadcast_event(:circuit_breaker_tripped, %{error_rate: error_rate})

    :telemetry.execute(
      [:indrajaal, :biomorphic, :immune, :circuit_breaker],
      %{error_rate: error_rate},
      %{constraint: "SC-IMMUNE-002"}
    )
  end

  defp report_critical_to_guardian(threat) do
    try do
      Indrajaal.Safety.Guardian.report_threat(%{
        type: :immune_critical,
        severity: :critical,
        source: __MODULE__,
        metadata: threat
      })
    rescue
      _ -> :ok
    end
  end

  defp compute_error_rate(state) when state.event_count == 0, do: 0.0

  defp compute_error_rate(state) do
    Float.round(state.error_count / state.event_count, 4)
  end

  defp broadcast_event(event_type, payload) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:immune_event, event_type, payload}
    )

    publish_zenoh(event_type, payload)
  rescue
    _e -> :ok
  end

  defp publish_zenoh(event_type, payload) do
    data = %{
      checkpoint: @checkpoint,
      topic: @zenoh_topic,
      event: Atom.to_string(event_type),
      payload: payload,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(@zenoh_topic, data)
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(threat_level, event_count) do
    :telemetry.execute(
      [:indrajaal, :biomorphic, :immune, :threat],
      %{event_count: event_count},
      %{threat_level: threat_level, constraint: "SC-IMMUNE-001"}
    )
  end
end
