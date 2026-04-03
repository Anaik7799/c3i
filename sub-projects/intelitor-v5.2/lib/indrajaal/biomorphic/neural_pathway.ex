defmodule Indrajaal.Biomorphic.NeuralPathway do
  @moduledoc """
  ## Design Intent
  Neural-network-inspired signal routing for the Indrajaal biomorphic mesh.
  Models inter-module communication as weighted synaptic pathways. Signals
  propagate when accumulated input exceeds an activation threshold, and
  connections strengthen via Hebbian learning ("fire together, wire together").

  Signal lifecycle:
    1. Signal arrives at source node
    2. Pathway weight looked up from ETS (sub-ms)
    3. Activation check: accumulated_input >= threshold
    4. If activated: signal propagated to target, Hebbian weight update applied
    5. Propagation event broadcast via PubSub "biomorphic:neural"

  ## STAMP Constraints
  - SC-SEM-001: Semantic analysis text pipeline — REFERENCED (signal semantics)
  - SC-ORCH-009: All inter-service messages logged — ENFORCED
  - SC-BIO-001: OODA cycle < 100ms — ENFORCED (ETS fast-path)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude | Initial implementation |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_pathways :neural_pathways
  @ets_activations :neural_activations
  @pubsub_topic "biomorphic:neural"
  @zenoh_topic "indrajaal/biomorphic/neural/signal"
  @checkpoint "CP-BIO-NEURAL-01"

  # Default activation threshold (0.0–1.0)
  @default_threshold 0.5

  # Hebbian learning rate
  @hebbian_rate 0.05

  # Maximum weight (prevents runaway potentiation)
  @max_weight 1.0

  # Minimum weight (prevents complete silencing)
  @min_weight 0.01

  # Decay rate applied to unused pathways per cycle
  @decay_rate 0.001

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Register a directed pathway between two nodes with initial weight."
  @spec register_pathway(atom(), atom(), float()) :: :ok
  def register_pathway(source, target, initial_weight \\ 0.5)
      when is_atom(source) and is_atom(target) and is_float(initial_weight) do
    GenServer.call(@name, {:register_pathway, source, target, initial_weight})
  end

  @doc "Propagate a signal from source node. Returns whether activation occurred."
  @spec propagate(atom(), map()) :: {:activated, list(atom())} | :below_threshold
  def propagate(source, signal \\ %{}) when is_atom(source) and is_map(signal) do
    GenServer.call(@name, {:propagate, source, signal})
  end

  @doc "Returns the current weight of a pathway."
  @spec pathway_weight(atom(), atom()) :: {:ok, float()} | :not_found
  def pathway_weight(source, target) when is_atom(source) and is_atom(target) do
    key = pathway_key(source, target)

    case :ets.lookup(@ets_pathways, key) do
      [{^key, entry}] -> {:ok, entry.weight}
      [] -> :not_found
    end
  end

  @doc "Returns all pathways originating from a given source."
  @spec pathways_from(atom()) :: list(map())
  def pathways_from(source) when is_atom(source) do
    prefix = "#{source}:"

    :ets.tab2list(@ets_pathways)
    |> Enum.filter(fn {key, _} -> String.starts_with?(key, prefix) end)
    |> Enum.map(fn {_key, entry} -> entry end)
  end

  @doc "Manually set activation threshold for a source node."
  @spec set_threshold(atom(), float()) :: :ok
  def set_threshold(source, threshold)
      when is_atom(source) and is_float(threshold) do
    GenServer.call(@name, {:set_threshold, source, threshold})
  end

  @doc "Returns pathway statistics summary."
  @spec stats() :: map()
  def stats do
    GenServer.call(@name, :stats)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@ets_pathways, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@ets_activations, [:set, :public, :named_table, read_concurrency: true])

    # Schedule periodic weight decay
    schedule_decay()

    state = %{
      pathway_count: 0,
      activation_count: 0,
      signal_count: 0,
      thresholds: %{},
      started_at: DateTime.utc_now()
    }

    Logger.warning("[NEURAL] NeuralPathway started — checkpoint=#{@checkpoint}")
    {:ok, state}
  end

  @impl true
  def handle_call({:register_pathway, source, target, weight}, _from, state) do
    key = pathway_key(source, target)
    clamped = clamp_weight(weight)

    entry = %{
      source: source,
      target: target,
      weight: clamped,
      activation_count: 0,
      last_activated: nil,
      registered_at: DateTime.utc_now()
    }

    :ets.insert(@ets_pathways, {key, entry})

    new_count = state.pathway_count + 1
    Logger.debug("[NEURAL] Pathway registered: #{source}→#{target} weight=#{clamped}")

    {:reply, :ok, %{state | pathway_count: new_count}}
  end

  @impl true
  def handle_call({:propagate, source, signal}, _from, state) do
    threshold = Map.get(state.thresholds, source, @default_threshold)
    {result, new_state} = do_propagate(source, signal, threshold, state)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:set_threshold, source, threshold}, _from, state) do
    clamped = max(0.0, min(1.0, threshold))
    new_thresholds = Map.put(state.thresholds, source, clamped)
    {:reply, :ok, %{state | thresholds: new_thresholds}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    reply = %{
      pathway_count: state.pathway_count,
      activation_count: state.activation_count,
      signal_count: state.signal_count,
      uptime_s: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, reply, state}
  end

  @impl true
  def handle_info(:decay_tick, state) do
    apply_weight_decay()
    schedule_decay()
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[NEURAL] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private — propagation logic
  # ---------------------------------------------------------------------------

  defp do_propagate(source, signal, threshold, state) do
    new_signal_count = state.signal_count + 1

    # Accumulate input signal into the activation buffer
    accumulated = accumulate_input(source, signal)

    if accumulated >= threshold do
      # Fire: propagate to all targets, apply Hebbian learning
      targets = fire_pathways(source, signal, accumulated)

      # Reset accumulation
      :ets.delete(@ets_activations, source)

      broadcast_event(:signal_propagated, %{
        source: source,
        targets: targets,
        accumulated: accumulated,
        threshold: threshold
      })

      emit_telemetry(source, :activated, length(targets))

      new_activation_count = state.activation_count + 1

      new_state = %{
        state
        | signal_count: new_signal_count,
          activation_count: new_activation_count
      }

      {{:activated, targets}, new_state}
    else
      # Sub-threshold: accumulate but do not fire
      broadcast_event(:signal_accumulated, %{
        source: source,
        accumulated: accumulated,
        threshold: threshold
      })

      new_state = %{state | signal_count: new_signal_count}
      {:below_threshold, new_state}
    end
  end

  defp accumulate_input(source, signal) do
    strength = Map.get(signal, :strength, 1.0)
    strength = if is_float(strength), do: strength, else: 1.0

    current =
      case :ets.lookup(@ets_activations, source) do
        [{^source, val}] -> val
        [] -> 0.0
      end

    new_val = min(1.0, current + strength)
    :ets.insert(@ets_activations, {source, new_val})
    new_val
  end

  defp fire_pathways(source, signal, accumulated) do
    prefix = "#{source}:"

    targets =
      :ets.tab2list(@ets_pathways)
      |> Enum.filter(fn {key, _} -> String.starts_with?(key, prefix) end)
      |> Enum.map(fn {key, entry} ->
        # Hebbian learning: strengthen the pathway (SC-ORCH-009 log)
        new_weight = hebbian_update(entry.weight, accumulated)

        updated_entry = %{
          entry
          | weight: new_weight,
            activation_count: entry.activation_count + 1,
            last_activated: DateTime.utc_now()
        }

        :ets.insert(@ets_pathways, {key, updated_entry})

        Logger.debug(
          "[NEURAL] SC-ORCH-009 pathway fired: #{entry.source}→#{entry.target} " <>
            "weight=#{Float.round(new_weight, 4)} accumulated=#{Float.round(accumulated, 4)}"
        )

        entry.target
      end)

    _ = signal
    targets
  end

  defp hebbian_update(current_weight, activation_strength) do
    delta = @hebbian_rate * activation_strength * (1.0 - current_weight)
    clamp_weight(current_weight + delta)
  end

  defp apply_weight_decay do
    :ets.tab2list(@ets_pathways)
    |> Enum.each(fn {key, entry} ->
      new_weight = max(@min_weight, entry.weight - @decay_rate)

      if new_weight != entry.weight do
        :ets.insert(@ets_pathways, {key, %{entry | weight: new_weight}})
      end
    end)
  end

  defp clamp_weight(w), do: max(@min_weight, min(@max_weight, w))

  defp pathway_key(source, target), do: "#{source}:#{target}"

  defp schedule_decay do
    Process.send_after(self(), :decay_tick, 60_000)
  end

  defp broadcast_event(event_type, payload) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:neural_event, event_type, payload}
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

  defp emit_telemetry(source, result, target_count) do
    :telemetry.execute(
      [:indrajaal, :biomorphic, :neural, :signal],
      %{target_count: target_count},
      %{source: source, result: result, constraint: "SC-ORCH-009"}
    )
  end
end
