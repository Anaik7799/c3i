defmodule Indrajaal.Cortex.SelfHealing do
  @moduledoc """
  Reflex Agent for Automatic Remediation (System Immune System).
  Monitors health signals and triggers circuit breakers or restarts.

  STAMP: SC-BIO-EXT-004 (Antibody Synthesis), SC-BIO-EXT-011 (Mara integration)
  """
  use GenServer
  require Logger

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Reports a component failure or chaos strike.
  """
  def report_failure(component) do
    GenServer.cast(__MODULE__, {:failure, component})
  end

  @doc """
  Actuates a specific healing action based on the action type.

  Supported actions:
  - `{:restart_process, pid}` - Kills the process and relies on supervisor restart
  - `{:clear_cache, table_name}` - Deletes all entries from the named ETS table
  - `{:reconnect, service}` - Logs reconnect attempt and emits telemetry
  - `{:scale_up, service}` - Logs scale-up request and emits telemetry

  Returns `{:ok, action_taken}` or `{:error, reason}`.
  """
  @spec actuate_healing(tuple()) :: {:ok, term()} | {:error, term()}
  def actuate_healing({:restart_process, pid}) when is_pid(pid) do
    if Process.alive?(pid) do
      Logger.warning("SelfHealing: restarting process", pid: inspect(pid))

      :telemetry.execute(
        [:cortex, :self_healing, :process_restart],
        %{},
        %{pid: inspect(pid)}
      )

      Process.exit(pid, :kill)
      {:ok, {:restarted, pid}}
    else
      Logger.debug("SelfHealing: process already dead, supervisor will handle restart",
        pid: inspect(pid)
      )

      {:ok, {:already_dead, pid}}
    end
  end

  def actuate_healing({:clear_cache, table_name}) when is_atom(table_name) do
    case :ets.whereis(table_name) do
      :undefined ->
        Logger.warning("SelfHealing: ETS table not found for cache clear", table: table_name)
        {:error, {:table_not_found, table_name}}

      _ref ->
        :ets.delete_all_objects(table_name)

        Logger.info("SelfHealing: cache cleared", table: table_name)

        :telemetry.execute(
          [:cortex, :self_healing, :cache_cleared],
          %{},
          %{table: table_name}
        )

        {:ok, {:cache_cleared, table_name}}
    end
  end

  def actuate_healing({:reconnect, service}) do
    Logger.info("SelfHealing: triggering reconnect", service: inspect(service))

    :telemetry.execute(
      [:cortex, :self_healing, :reconnect_triggered],
      %{},
      %{service: inspect(service)}
    )

    {:ok, {:reconnect_triggered, service}}
  end

  def actuate_healing({:scale_up, service}) do
    Logger.info("SelfHealing: requesting scale-up", service: inspect(service))

    :telemetry.execute(
      [:cortex, :self_healing, :scale_up_requested],
      %{},
      %{service: inspect(service)}
    )

    {:ok, {:scale_up_requested, service}}
  end

  def actuate_healing(unknown_action) do
    Logger.error("SelfHealing: unknown healing action", action: inspect(unknown_action))
    {:error, {:unknown_action, unknown_action}}
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("🛡️ Cortex: Self-Healing Reflexes Active")
    # Initialize with history tracking for antibody synthesis
    {:ok, %{health_score: 100, failure_history: %{}, antibodies: MapSet.new()}}
  end

  @impl true
  def handle_cast({:failure, component}, state) do
    Logger.warning("🛡️ Cortex: Detected failure in #{component}. Assessing remediation...")

    # 1. Update failure history
    now = System.system_time(:second)
    history = Map.get(state.failure_history, component, [])
    # Keep only failures from last 5 minutes
    new_history = [now | history] |> Enum.filter(&(&1 > now - 300))

    # 2. Check for Antibody Synthesis threshold (e.g., 3 failures in 5 min)
    {new_state, synthesized?} =
      if length(new_history) >= 3 and not MapSet.member?(state.antibodies, component) do
        synthesize_antibody(component, state)
      else
        {state, false}
      end

    # 3. Trigger immediate remediation (e.g., restart or isolation)
    # Placeholder for actuation
    if not synthesized? do
      Logger.info("🛡️ Cortex: Triggering reflex remediation for #{component}")
    end

    updated_history = Map.put(state.failure_history, component, new_history)
    {:noreply, %{new_state | failure_history: updated_history}}
  end

  # ============================================================
  # PRIVATE - ANTIBODY LOGIC
  # ============================================================

  defp synthesize_antibody(component, state) do
    Logger.info(
      "🧬 [Cortex] ANTIBODY SYNTHESIZED: Blocking recurring failure pattern for #{component}"
    )

    # 1. Register antibody in state
    new_antibodies = MapSet.put(state.antibodies, component)

    # 2. Broadcast to mesh (Zenoh)
    # This tells other nodes and the F# Cortex to block attacks on this component
    stream_event(:antibody_synthesized, %{target: component, timestamp: DateTime.utc_now()})

    {%{state | antibodies: new_antibodies}, true}
  end

  defp stream_event(type, payload) do
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohNeuralStream) do
      Indrajaal.Observability.ZenohNeuralStream.stream_state(:self_healing, type, payload)
    end
  rescue
    _ -> :ok
  end
end
