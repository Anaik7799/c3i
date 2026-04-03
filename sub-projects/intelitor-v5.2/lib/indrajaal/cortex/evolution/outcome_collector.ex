defmodule Indrajaal.Cortex.Evolution.OutcomeCollector do
  @moduledoc """
  WHAT: Dedicated outcome recording collector feeding the Cortex TrainingGym.
  WHY: Decouples event ingestion from episode storage, enabling buffering,
       deduplication, and batch-writing of Guardian veto/success outcomes
       for reinforcement learning model improvement.
  CONSTRAINTS: SC-GDE-001 (Guardian validation), SC-GDE-002 (shadow testing mandatory),
               AOR-CAE-003 (record outcomes to TrainingGym),
               AOR-OPENROUTER-004 (audit trail for all AI calls),
               SC-HOLON-014 (record failure events to DuckDB history),
               AOR-REG-007 (record all extension installs/uninstalls).

  ## Architecture

  ```
  Guardian / Synapse / ShadowMode
      │  (emit outcome events)
      ▼
  OutcomeCollector (GenServer)   ◄─── this module (Cortex L3)
      │
      ├─ Buffer (ETS, max 1000 entries)
      ├─ Dedup (content hash, 60s window)
      ├─ Flush (every 5s OR when buffer hits 100)
      └─ TrainingGym (batch-write episodes)
  ```

  ## Outcome Types

  | Type           | Trigger                         | Episode kind    |
  |----------------|---------------------------------|-----------------|
  | :veto          | Guardian rejects proposal       | near_miss       |
  | :approve       | Guardian approves proposal      | success         |
  | :shadow_agree  | Shadow matches production       | shadow_agree    |
  | :shadow_diverge| Shadow diverges from production | shadow_diverge  |
  | :fitness_low   | Fitness below threshold         | near_miss       |
  | :fitness_high  | Fitness above threshold         | success         |
  """

  use GenServer

  require Logger

  alias Indrajaal.Cortex.Evolution.TrainingGym

  @type outcome_type ::
          :veto
          | :approve
          | :shadow_agree
          | :shadow_diverge
          | :fitness_low
          | :fitness_high

  @type outcome_event :: %{
          type: outcome_type(),
          proposal_id: String.t(),
          context: map(),
          fitness: float() | nil,
          timestamp: DateTime.t()
        }

  # ETS table name for buffering
  @buffer_table :outcome_collector_buffer

  # Flush config
  @flush_interval_ms 5_000
  @flush_threshold 100
  @dedup_window_ms 60_000
  @max_buffer_size 1_000

  # ---- Public API ----

  @doc "Starts the OutcomeCollector GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records a Guardian veto outcome.

  ## Parameters
  - `proposal_id` — unique proposal identifier
  - `reason` — atom or string reason for veto
  - `context` — additional metadata map
  """
  @spec record_veto(String.t(), term(), map()) :: :ok
  def record_veto(proposal_id, reason, context \\ %{}) do
    emit(%{
      type: :veto,
      proposal_id: proposal_id,
      context: Map.put(context, :reason, reason),
      fitness: context[:fitness],
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Records a Guardian approval outcome.

  ## Parameters
  - `proposal_id` — unique proposal identifier
  - `fitness` — final fitness score (0.0–1.0)
  - `context` — additional metadata map
  """
  @spec record_approval(String.t(), float(), map()) :: :ok
  def record_approval(proposal_id, fitness, context \\ %{}) do
    emit(%{
      type: :approve,
      proposal_id: proposal_id,
      context: context,
      fitness: fitness,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Records a shadow agreement outcome (shadow matches production).

  ## Parameters
  - `proposal_id` — unique proposal identifier
  - `agreement_rate` — ratio of matching decisions (0.0–1.0)
  - `context` — additional metadata
  """
  @spec record_shadow_agree(String.t(), float(), map()) :: :ok
  def record_shadow_agree(proposal_id, agreement_rate, context \\ %{}) do
    emit(%{
      type: :shadow_agree,
      proposal_id: proposal_id,
      context: Map.put(context, :agreement_rate, agreement_rate),
      fitness: agreement_rate,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Records a shadow divergence outcome (shadow differs from production).

  ## Parameters
  - `proposal_id` — unique proposal identifier
  - `divergence_reason` — string description of divergence
  - `context` — additional metadata
  """
  @spec record_shadow_diverge(String.t(), String.t(), map()) :: :ok
  def record_shadow_diverge(proposal_id, divergence_reason, context \\ %{}) do
    emit(%{
      type: :shadow_diverge,
      proposal_id: proposal_id,
      context: Map.put(context, :divergence_reason, divergence_reason),
      fitness: context[:fitness],
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Records an outcome based on fitness score (auto-classifies high/low).

  ## Parameters
  - `proposal_id` — unique proposal identifier
  - `fitness` — fitness score (0.0–1.0)
  - `context` — additional metadata
  """
  @spec record_fitness(String.t(), float(), map()) :: :ok
  def record_fitness(proposal_id, fitness, context \\ %{}) do
    type = if fitness >= 0.85, do: :fitness_high, else: :fitness_low

    emit(%{
      type: type,
      proposal_id: proposal_id,
      context: context,
      fitness: fitness,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Manually triggers a flush of buffered outcomes to TrainingGym.

  Used in tests and during graceful shutdown.
  """
  @spec flush() :: {:ok, non_neg_integer()}
  def flush do
    GenServer.call(__MODULE__, :flush)
  end

  @doc """
  Returns current buffer statistics.

  ## Returns
  - `%{buffered: non_neg_integer(), total_flushed: non_neg_integer(), ...}`
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ---- GenServer callbacks ----

  @impl true
  def init(opts) do
    ensure_buffer_table()
    flush_interval = Keyword.get(opts, :flush_interval_ms, @flush_interval_ms)
    schedule_flush(flush_interval)

    state = %{
      flush_interval_ms: flush_interval,
      total_flushed: 0,
      flush_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.info("[OutcomeCollector] started flush_interval=#{flush_interval}ms")
    {:ok, state}
  end

  @impl true
  def handle_cast({:emit, event}, state) do
    if not duplicate?(event) do
      buffer_event(event)
    end

    buffered = :ets.info(@buffer_table, :size)

    if buffered >= @flush_threshold do
      {flushed, new_state} = do_flush(state)
      Logger.debug("[OutcomeCollector] threshold flush flushed=#{flushed}")
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:flush, _from, state) do
    {flushed, new_state} = do_flush(state)
    {:reply, {:ok, flushed}, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    buffered = :ets.info(@buffer_table, :size)

    stats_map = %{
      buffered: buffered,
      total_flushed: state.total_flushed,
      flush_count: state.flush_count,
      flush_interval_ms: state.flush_interval_ms,
      started_at: state.started_at
    }

    {:reply, stats_map, state}
  end

  @impl true
  def handle_info(:scheduled_flush, state) do
    {_flushed, new_state} = do_flush(state)
    schedule_flush(state.flush_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("[OutcomeCollector] terminating, flushing remaining buffer")
    do_flush(state)
    :ok
  end

  # ---- Private ----

  @spec emit(outcome_event()) :: :ok
  defp emit(event) do
    GenServer.cast(__MODULE__, {:emit, event})
  end

  @spec ensure_buffer_table() :: :ok
  defp ensure_buffer_table do
    case :ets.whereis(@buffer_table) do
      :undefined ->
        :ets.new(@buffer_table, [:named_table, :public, :set, {:write_concurrency, true}])
        :ok

      _ ->
        :ok
    end
  end

  @spec buffer_event(outcome_event()) :: true
  defp buffer_event(event) do
    # Enforce max buffer size (drop oldest if full)
    if :ets.info(@buffer_table, :size) >= @max_buffer_size do
      # Drop one oldest — take first key
      case :ets.first(@buffer_table) do
        :"$end_of_table" -> :ok
        key -> :ets.delete(@buffer_table, key)
      end
    end

    key = {event.proposal_id, event.type, event.timestamp}
    :ets.insert(@buffer_table, {key, event})
  end

  @spec duplicate?(outcome_event()) :: boolean()
  defp duplicate?(event) do
    now_ms = System.monotonic_time(:millisecond)

    dedup_key = {:dedup, event.proposal_id, event.type}

    case :ets.lookup(@buffer_table, dedup_key) do
      [{^dedup_key, last_ms}] when now_ms - last_ms < @dedup_window_ms ->
        true

      _ ->
        :ets.insert(@buffer_table, {dedup_key, now_ms})
        false
    end
  end

  @spec do_flush(map()) :: {non_neg_integer(), map()}
  defp do_flush(state) do
    events =
      :ets.tab2list(@buffer_table)
      |> Enum.filter(fn
        # Skip dedup marker entries
        {{:dedup, _, _}, _} -> false
        _ -> true
      end)
      |> Enum.map(fn {_key, event} -> event end)

    if events == [] do
      {0, state}
    else
      # Clear buffer entries (keep dedup markers)
      :ets.match_delete(@buffer_table, {{:"$1", :"$2", :"$3"}, :"$4"})

      flushed =
        events
        |> Enum.reduce(0, fn event, acc ->
          case write_to_gym(event) do
            :ok -> acc + 1
            {:error, _} -> acc
          end
        end)

      new_state = %{
        state
        | total_flushed: state.total_flushed + flushed,
          flush_count: state.flush_count + 1
      }

      {max(0, flushed), new_state}
    end
  end

  @spec write_to_gym(outcome_event()) :: :ok | {:error, term()}
  defp write_to_gym(event) do
    # TrainingGym signatures:
    #   record_near_miss(state_before, action, veto_reason)
    #   record_success(state_before, action, result)
    #   record_shadow_agree(model_id, context, action)
    #   record_shadow_diverge(model_id, context, production_action, shadow_action)
    case event.type do
      :veto ->
        reason = Map.get(event.context, :reason, :guardian_veto)
        TrainingGym.record_near_miss(event.context, %{proposal_id: event.proposal_id}, reason)

      :approve ->
        result = %{fitness: event.fitness || 1.0}
        TrainingGym.record_success(event.context, %{proposal_id: event.proposal_id}, result)

      :fitness_low ->
        reason = {:fitness_below_threshold, event.fitness}
        TrainingGym.record_near_miss(event.context, %{proposal_id: event.proposal_id}, reason)

      :fitness_high ->
        result = %{fitness: event.fitness}
        TrainingGym.record_success(event.context, %{proposal_id: event.proposal_id}, result)

      :shadow_agree ->
        agreement = Map.get(event.context, :agreement_rate, event.fitness || 1.0)
        action = %{proposal_id: event.proposal_id, agreement_rate: agreement}
        TrainingGym.record_shadow_agree(event.proposal_id, event.context, action)

      :shadow_diverge ->
        production_action = %{proposal_id: event.proposal_id}
        shadow_action = Map.take(event.context, [:divergence_reason])

        TrainingGym.record_shadow_diverge(
          event.proposal_id,
          event.context,
          production_action,
          shadow_action
        )
    end
  rescue
    e ->
      Logger.warning("[OutcomeCollector] write_to_gym failed: #{inspect(e)}")
      {:error, e}
  end

  @spec schedule_flush(pos_integer()) :: reference()
  defp schedule_flush(interval_ms) do
    Process.send_after(self(), :scheduled_flush, interval_ms)
  end
end
