defmodule Indrajaal.Biomorphic.EndocrineSignaler do
  @moduledoc """
  ## Design Intent
  Slow-loop hormone-like signaling system for the Indrajaal biomorphic mesh.
  Signals propagate system-wide parameter adjustments with configurable decay,
  receptor binding, and amplitude. Mimics endocrine feedback: signals persist
  for a duration (half-life) and are absorbed by registered receptors.

  Signal types and their system semantics:
    :growth      — Increase resource allocation, expand capacity
    :stress      — Trigger defensive throttling and circuit-breaker arming
    :recovery    — Restore normal operating parameters after stress
    :hibernation — Enter low-power maintenance mode (off-peak windows)

  Signal lifecycle:
    1. Emitter calls `emit_signal/3` with type, amplitude (0.0–1.0), metadata
    2. Signal stored in ETS with timestamp + half-life (default 30 s)
    3. Decay tick (every 5 s) applies exponential decay: A(t) = A₀·e^(-λt)
    4. Receptors polled: handlers called when bound signal exceeds threshold
    5. Expired signals (amplitude < 0.01) are pruned automatically
    6. PubSub "biomorphic:endocrine" broadcasts level changes

  ## STAMP Constraints
  - SC-BIO-001: OODA cycle < 100ms — decay tick stays within budget
  - SC-HOM-002: Homeostatic controller must receive signals — ENFORCED via receptors
  - SC-FUNC-001: System must compile at all times — ENFORCED
  - SC-CPU-GOV-001: CPU utilization limit respected — decay is O(n) with n signals

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_signals :endocrine_signals
  @ets_receptors :endocrine_receptors
  @pubsub_topic "biomorphic:endocrine"
  @zenoh_topic "indrajaal/biomorphic/endocrine/status"
  @checkpoint "CP-BIO-ENDOCRINE-01"

  # Decay tick interval in ms
  @decay_tick_ms 5_000

  # Default signal half-life in seconds
  @default_half_life_s 30.0

  # Pruning threshold — signals below this amplitude are removed
  @prune_threshold 0.01

  # Valid signal types
  @valid_signal_types [:growth, :stress, :recovery, :hibernation]

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type signal_type :: :growth | :stress | :recovery | :hibernation

  @type signal :: %{
          id: String.t(),
          type: signal_type(),
          amplitude: float(),
          half_life_s: float(),
          emitted_at: integer(),
          metadata: map()
        }

  @type receptor :: %{
          id: String.t(),
          signal_type: signal_type(),
          threshold: float(),
          handler: (signal_type(), float(), map() -> :ok)
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Emit a hormone-like signal into the system.

  - `type`      — signal type (:growth, :stress, :recovery, :hibernation)
  - `amplitude` — signal strength 0.0..1.0
  - `metadata`  — arbitrary context map
  """
  @spec emit_signal(signal_type(), float(), map()) :: {:ok, String.t()} | {:error, term()}
  def emit_signal(type, amplitude, metadata \\ %{})
      when type in @valid_signal_types and is_float(amplitude) and is_map(metadata) do
    if amplitude >= 0.0 and amplitude <= 1.0 do
      GenServer.call(@name, {:emit_signal, type, amplitude, metadata})
    else
      {:error, :amplitude_out_of_range}
    end
  end

  @doc """
  Register a receptor that binds to a specific signal type.

  - `id`          — unique receptor identifier
  - `signal_type` — which signal type to bind
  - `opts`        — keyword options: threshold (float), handler (fn)
  """
  @spec register_receptor(String.t(), signal_type(), keyword()) :: :ok | {:error, term()}
  def register_receptor(id, signal_type, opts \\ [])
      when is_binary(id) and signal_type in @valid_signal_types do
    GenServer.call(@name, {:register_receptor, id, signal_type, opts})
  end

  @doc """
  Returns current signal amplitude levels for all active signal types.
  """
  @spec current_levels() :: %{signal_type() => float()}
  def current_levels do
    GenServer.call(@name, :current_levels)
  end

  @doc """
  Trigger an immediate decay cycle (also reaps expired signals).
  Returns the count of pruned signals.
  """
  @spec signal_decay() :: non_neg_integer()
  def signal_decay do
    GenServer.call(@name, :signal_decay)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_signals, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@ets_receptors, [:set, :public, :named_table, read_concurrency: true])

    half_life = Keyword.get(opts, :half_life_s, @default_half_life_s)
    schedule_decay()

    state = %{
      half_life_s: half_life,
      total_emitted: 0,
      total_pruned: 0,
      decay_cycles: 0,
      started_at: DateTime.utc_now()
    }

    Logger.warning(
      "[ENDOCRINE] EndocrineSignaler started — half_life=#{half_life}s " <>
        "checkpoint=#{@checkpoint}"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:emit_signal, type, amplitude, metadata}, _from, state) do
    id = generate_id()
    now = System.monotonic_time(:millisecond)

    signal = %{
      id: id,
      type: type,
      amplitude: amplitude,
      half_life_s: state.half_life_s,
      emitted_at: now,
      metadata: metadata
    }

    :ets.insert(@ets_signals, {id, signal})

    new_state = %{state | total_emitted: state.total_emitted + 1}

    broadcast_emission(signal)
    emit_telemetry(:emit, type, amplitude, new_state.total_emitted)

    Logger.debug("[ENDOCRINE] Signal emitted id=#{id} type=#{type} amplitude=#{amplitude}")

    {:reply, {:ok, id}, new_state}
  end

  @impl true
  def handle_call({:register_receptor, id, signal_type, opts}, _from, state) do
    threshold = Keyword.get(opts, :threshold, 0.1)
    handler = Keyword.get(opts, :handler, fn _t, _a, _m -> :ok end)

    receptor = %{
      id: id,
      signal_type: signal_type,
      threshold: threshold,
      handler: handler
    }

    :ets.insert(@ets_receptors, {id, receptor})

    Logger.debug(
      "[ENDOCRINE] Receptor registered id=#{id} signal_type=#{signal_type} " <>
        "threshold=#{threshold}"
    )

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:current_levels, _from, state) do
    levels = compute_levels()
    {:reply, levels, state}
  end

  @impl true
  def handle_call(:signal_decay, _from, state) do
    {pruned, new_state} = run_decay_cycle(state)
    {:reply, pruned, new_state}
  end

  @impl true
  def handle_info(:decay_tick, state) do
    {_pruned, new_state} = run_decay_cycle(state)
    schedule_decay()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[ENDOCRINE] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private — decay logic
  # ---------------------------------------------------------------------------

  defp run_decay_cycle(state) do
    now_ms = System.monotonic_time(:millisecond)
    all_signals = :ets.tab2list(@ets_signals)

    {pruned, updated} =
      Enum.reduce(all_signals, {0, []}, fn {id, signal}, {prune_count, upd} ->
        elapsed_s = (now_ms - signal.emitted_at) / 1_000.0
        lambda = :math.log(2) / signal.half_life_s
        new_amplitude = signal.amplitude * :math.exp(-lambda * elapsed_s)

        if new_amplitude < @prune_threshold do
          :ets.delete(@ets_signals, id)
          {prune_count + 1, upd}
        else
          :ets.insert(@ets_signals, {id, %{signal | amplitude: new_amplitude}})
          {prune_count, [{id, %{signal | amplitude: new_amplitude}} | upd]}
        end
      end)

    levels = compute_levels()
    notify_receptors(updated, levels)
    broadcast_levels(levels)
    emit_telemetry(:decay, :none, 0.0, pruned)

    new_state = %{
      state
      | total_pruned: state.total_pruned + pruned,
        decay_cycles: state.decay_cycles + 1
    }

    {pruned, new_state}
  end

  defp compute_levels do
    all_signals = :ets.tab2list(@ets_signals)

    Enum.reduce(@valid_signal_types, %{}, fn type, acc ->
      total =
        all_signals
        |> Enum.filter(fn {_id, s} -> s.type == type end)
        |> Enum.reduce(0.0, fn {_id, s}, sum -> sum + s.amplitude end)

      Map.put(acc, type, Float.round(total, 4))
    end)
  end

  defp notify_receptors(updated_signals, levels) do
    all_receptors = :ets.tab2list(@ets_receptors)

    Enum.each(all_receptors, fn {_id, receptor} ->
      level = Map.get(levels, receptor.signal_type, 0.0)

      if level >= receptor.threshold do
        matching =
          updated_signals
          |> Enum.filter(fn {_id, s} -> s.type == receptor.signal_type end)
          |> Enum.map(fn {_id, s} -> s.metadata end)
          |> List.first(%{})

        try do
          receptor.handler.(receptor.signal_type, level, matching)
        rescue
          e ->
            Logger.warning(
              "[ENDOCRINE] Receptor handler failed id=#{receptor.id} error=#{inspect(e)}"
            )
        end
      end
    end)
  end

  defp schedule_decay do
    Process.send_after(self(), :decay_tick, @decay_tick_ms)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp broadcast_emission(signal) do
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:signal_emitted, signal.type, signal.amplitude, signal.id}
      )
    rescue
      _ -> :ok
    end
  end

  defp broadcast_levels(levels) do
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:levels_updated, levels}
      )
    rescue
      _ -> :ok
    end

    publish_zenoh(levels)
  end

  defp publish_zenoh(levels) do
    data = %{
      checkpoint: @checkpoint,
      topic: @zenoh_topic,
      growth: Map.get(levels, :growth, 0.0),
      stress: Map.get(levels, :stress, 0.0),
      recovery: Map.get(levels, :recovery, 0.0),
      hibernation: Map.get(levels, :hibernation, 0.0),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(@zenoh_topic, data)
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(event, signal_type, amplitude, count) do
    try do
      :telemetry.execute(
        [:indrajaal, :biomorphic, :endocrine, event],
        %{amplitude: amplitude, count: count},
        %{signal_type: signal_type, constraint: "SC-BIO-001"}
      )
    rescue
      _ -> :ok
    end
  end
end
