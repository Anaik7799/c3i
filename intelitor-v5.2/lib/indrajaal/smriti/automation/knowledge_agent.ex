defmodule Indrajaal.Smriti.Automation.KnowledgeAgent do
  @moduledoc """
  L3 Agent: Self-aware knowledge domain with OODA loop.

  Observes cluster health, orients on evolutionary pressures,
  decides actions, and acts to maintain homeostasis.

  ## STAMP Constraints
  - SC-SMRITI-031: Agent OODA cycle < 30 seconds
  - SC-SMRITI-032: Health metrics MUST be tracked
  - SC-SMRITI-033: Evolution suggestions MUST be logged

  ## 5-Order Effects
  1st: Health metrics observed
  2nd: Trends analyzed
  3rd: Actions decided
  4th: Evolution executed
  5th: Knowledge genome improves
  """

  use GenServer
  require Logger

  @ooda_cycle_interval :timer.seconds(30)

  defstruct [
    :cluster,
    :history,
    :actions_taken,
    :last_cycle
  ]

  def start_link(cluster, opts \\ []) do
    GenServer.start_link(__MODULE__, [cluster | opts], name: via_tuple(cluster))
  end

  @spec observe(String.t()) :: {:ok, map()}
  def observe(cluster) do
    GenServer.call(via_tuple(cluster), :observe)
  end

  @spec trigger_evolution(String.t()) :: {:ok, list()}
  def trigger_evolution(cluster) do
    GenServer.call(via_tuple(cluster), :evolve)
  end

  # GenServer Implementation

  @impl true
  def init([cluster | _opts]) do
    schedule_ooda_cycle()

    {:ok,
     %__MODULE__{
       cluster: cluster,
       history: [],
       actions_taken: [],
       last_cycle: nil
     }}
  end

  @impl true
  def handle_call(:observe, _from, state) do
    {:ok, metrics} = do_observe(state.cluster)
    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_call(:evolve, _from, state) do
    {:ok, actions} = execute_evolution(state)
    {:reply, {:ok, actions}, state}
  end

  @impl true
  def handle_info(:ooda_cycle, state) do
    start_time = System.monotonic_time(:millisecond)

    # OBSERVE
    {:ok, metrics} = do_observe(state.cluster)

    # ORIENT
    analysis = orient(metrics, state.history)

    # DECIDE
    actions = decide(analysis)

    # ACT
    results = act(actions)

    elapsed = System.monotonic_time(:millisecond) - start_time

    # Verify OODA < 30s constraint
    if elapsed > 30_000 do
      Logger.warning("[KnowledgeAgent] OODA cycle exceeded 30s: #{elapsed}ms")
    end

    # Emit telemetry
    emit_ooda_telemetry(state.cluster, metrics, actions, elapsed)

    schedule_ooda_cycle()

    {:noreply,
     %{
       state
       | history: [metrics | Enum.take(state.history, 99)],
         actions_taken: results ++ state.actions_taken,
         last_cycle: DateTime.utc_now()
     }}
  end

  # OODA Implementation

  defp do_observe(_cluster) do
    # Placeholder for actual health query
    # In full impl, this calls SmritiIntegration.get_metrics()
    {:ok, %{health_score: 95.0, avg_entropy: 0.2, orphan_ratio: 0.1}}
  end

  defp orient(metrics, history) do
    %{
      current: metrics,
      trend: calculate_trend(history),
      anomalies: detect_anomalies(metrics, history),
      pressures: identify_evolutionary_pressures(metrics)
    }
  end

  defp decide(%{pressures: pressures} = _analysis) do
    Enum.flat_map(pressures, fn pressure ->
      case pressure do
        {:high_entropy, _} -> [:trigger_knowledge_refresh, :send_entropy_alert]
        {:orphan_ratio, _} -> [:suggest_connections, :identify_integration_targets]
        {:stale_cluster, _} -> [:schedule_content_review, :flag_for_archival]
        _ -> [:maintain_homeostasis]
      end
    end)
  end

  defp act(actions) do
    Enum.map(actions, fn action ->
      result = execute_action(action)
      Logger.info("[KnowledgeAgent] Action #{action}: #{inspect(result)}")
      {action, result}
    end)
  end

  defp execute_action(:trigger_knowledge_refresh) do
    {:ok, :refreshed}
  end

  defp execute_action(:suggest_connections) do
    {:ok, :suggestions_generated}
  end

  defp execute_action(:maintain_homeostasis) do
    {:ok, :stable}
  end

  defp execute_action(_), do: {:ok, :noop}

  defp calculate_trend([]), do: :stable
  defp calculate_trend([_]), do: :stable

  defp calculate_trend([latest, previous | _]) do
    cond do
      latest.health_score > previous.health_score -> :improving
      latest.health_score < previous.health_score -> :degrading
      true -> :stable
    end
  end

  defp detect_anomalies(_metrics, _history), do: []

  defp identify_evolutionary_pressures(metrics) do
    pressures = []

    pressures =
      if metrics.avg_entropy > 0.7 do
        [{:high_entropy, metrics.avg_entropy} | pressures]
      else
        pressures
      end

    pressures =
      if metrics.orphan_ratio > 0.3 do
        [{:orphan_ratio, metrics.orphan_ratio} | pressures]
      else
        pressures
      end

    pressures
  end

  defp emit_ooda_telemetry(cluster, metrics, actions, elapsed) do
    :telemetry.execute(
      [:smriti, :agent, :ooda_cycle],
      %{duration_ms: elapsed, action_count: length(actions)},
      %{cluster: cluster, health_score: metrics.health_score}
    )
  end

  defp schedule_ooda_cycle do
    Process.send_after(self(), :ooda_cycle, @ooda_cycle_interval)
  end

  defp via_tuple(cluster) do
    {:via, Registry, {Indrajaal.Smriti.AgentRegistry, {:knowledge_agent, cluster}}}
  end

  defp execute_evolution(_state), do: {:ok, []}
end
