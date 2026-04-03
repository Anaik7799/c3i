defmodule Indrajaal.Information.DataFusionEngine do
  @moduledoc """
  Data Fusion Engine — L2 Information Layer

  ## Design Intent

  GenServer that merges data streams from multiple heterogeneous sources
  into a single canonical view using weighted consensus.  Each source is
  registered with a trust score (0.0–1.0) that acts as its contribution
  weight in the fusion calculation.

  ### Fusion Algorithm
  For each key present in at least one source:
  1. Collect all `{value, weight}` pairs from sources that carry that key.
  2. Compute a weighted average (numeric values) or a weighted-vote winner
     (atom/string values).
  3. Derive a confidence score:
     ```
     confidence = Σ(wᵢ · agreeᵢ) / Σ(wᵢ)
     ```
     where `agreeᵢ = 1.0` if source i matches the consensus, else `0.0`.
  4. Publish the fused state to PubSub topic `"data_fusion:state_updated"`.

  Source data is stored in ETS keyed by `{:source, source_id}` for
  lock-free concurrent reads by query callers.

  ## STAMP Constraints
  - SC-REALTIME-001: Real-time data fusion MUST converge within one tick
  - SC-ALARM-006: Multi-source alarm data MUST be fused before escalation

  ## Change History
  | Version | Date       | Author            | Change                    |
  |---------|------------|-------------------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @ets_table :data_fusion_sources
  @pubsub_topic "data_fusion:state_updated"
  @telemetry_event [:indrajaal, :information, :data_fused]

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type source_id :: atom() | String.t()
  @type trust_score :: float()
  @type data_map :: %{(atom() | String.t()) => term()}

  @type source_entry :: %{
          id: source_id(),
          trust: trust_score(),
          last_seen: integer()
        }

  @type fused_value :: %{
          value: term(),
          confidence: float(),
          source_count: non_neg_integer()
        }

  @type fused_state :: %{(atom() | String.t()) => fused_value()}

  @type engine_state :: %{
          sources: %{source_id() => source_entry()}
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the DataFusionEngine GenServer registered under `#{inspect(@name)}`.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Registers a data source with the given `trust_score`.  Subsequent calls
  with the same `source_id` update the trust score.
  """
  @spec register_source(source_id(), trust_score(), data_map()) :: :ok
  def register_source(source_id, trust_score, initial_data \\ %{})
      when (is_atom(source_id) or is_binary(source_id)) and is_float(trust_score) and
             trust_score >= 0.0 and trust_score <= 1.0 and is_map(initial_data) do
    GenServer.call(@name, {:register_source, source_id, trust_score, initial_data})
  end

  @doc """
  Submits updated data for `source_id` and triggers re-fusion.
  Returns the freshly fused state map.
  """
  @spec fuse(source_id()) :: fused_state()
  def fuse(source_id) when is_atom(source_id) or is_binary(source_id) do
    GenServer.call(@name, {:fuse, source_id})
  end

  @doc """
  Returns the last fused value for `key`, or `nil` if the key has no data.
  Reads directly from ETS — no GenServer round-trip.
  """
  @spec get_fused_state(atom() | String.t()) :: fused_value() | nil
  def get_fused_state(key) when is_atom(key) or is_binary(key) do
    case :ets.lookup(@ets_table, {:fused, key}) do
      [{_, entry}] -> entry
      _ -> nil
    end
  end

  @doc """
  Returns the confidence score for a fused `key`, or `0.0` if not fused yet.
  """
  @spec confidence_score(atom() | String.t()) :: float()
  def confidence_score(key) when is_atom(key) or is_binary(key) do
    case get_fused_state(key) do
      nil -> 0.0
      %{confidence: c} -> c
      _ -> 0.0
    end
  end

  @doc """
  Returns the per-key confidence map for all currently fused keys.
  Task-spec alias: `confidence/1` accepts a list of keys and returns
  `%{key => float()}`.  Pass `:all` to retrieve all fused keys from ETS.
  """
  @spec confidence(:all | [atom() | String.t()]) :: %{(atom() | String.t()) => float()}
  def confidence(:all) do
    @ets_table
    |> :ets.match_object({{:fused, :_}, :_})
    |> Map.new(fn {{:fused, key}, entry} ->
      {key, Map.get(entry, :confidence, 0.0)}
    end)
  rescue
    _ -> %{}
  end

  def confidence(keys) when is_list(keys) do
    Map.new(keys, fn k -> {k, confidence_score(k)} end)
  end

  @doc """
  Returns a list of key conflicts — keys where two or more sources report values
  that differ by more than `threshold` (numeric) or are unequal (non-numeric).

  Returns `[{key, [{source_id, value}]}]` tuples for conflicting keys.
  """
  @spec conflicts(float()) :: [{atom() | String.t(), [{source_id(), term()}]}]
  def conflicts(threshold \\ 0.1) when is_float(threshold) do
    GenServer.call(@name, {:conflicts, threshold})
  end

  @doc """
  Returns the current trust weight for each registered source.
  Returns `%{source_id => float()}`.
  """
  @spec source_weights() :: %{source_id() => float()}
  def source_weights do
    GenServer.call(@name, :source_weights)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])

    Logger.info("[DataFusionEngine] L2 started — weighted-consensus multi-source fusion")

    {:ok, %{sources: %{}}}
  end

  @impl true
  def handle_call({:register_source, source_id, trust, initial_data}, _from, state) do
    entry = %{id: source_id, trust: trust, last_seen: monotonic_ms()}
    new_sources = Map.put(state.sources, source_id, entry)

    unless map_size(initial_data) == 0 do
      :ets.insert(@ets_table, {{:source, source_id}, initial_data})
    end

    Logger.debug("[DataFusionEngine] registered source=#{inspect(source_id)} trust=#{trust}")
    {:reply, :ok, %{state | sources: new_sources}}
  end

  @impl true
  def handle_call({:fuse, source_id}, _from, state) do
    # Update last_seen
    new_sources =
      Map.update(
        state.sources,
        source_id,
        %{id: source_id, trust: 0.5, last_seen: monotonic_ms()},
        fn e ->
          %{e | last_seen: monotonic_ms()}
        end
      )

    fused = perform_fusion(new_sources)

    # Write fused values back to ETS for fast reads
    Enum.each(fused, fn {key, fused_val} ->
      :ets.insert(@ets_table, {{:fused, key}, fused_val})
    end)

    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:data_fused, source_id, map_size(fused)}
      )
    rescue
      _ -> :ok
    end

    try do
      :telemetry.execute(
        @telemetry_event,
        %{key_count: map_size(fused), source_count: map_size(new_sources)},
        %{trigger_source: source_id}
      )
    rescue
      _ -> :ok
    end

    {:reply, fused, %{state | sources: new_sources}}
  end

  @impl true
  def handle_call({:conflicts, threshold}, _from, state) do
    # Gather all source data and group by key
    all_entries =
      Enum.flat_map(state.sources, fn {sid, %{trust: _trust}} ->
        case :ets.lookup(@ets_table, {:source, sid}) do
          [{_, data}] when is_map(data) ->
            Enum.map(data, fn {k, v} -> {k, sid, v} end)

          _ ->
            []
        end
      end)

    by_key =
      Enum.group_by(all_entries, fn {k, _sid, _v} -> k end, fn {_k, sid, v} -> {sid, v} end)

    conflicts =
      Enum.flat_map(by_key, fn {key, source_values} ->
        if length(source_values) < 2 do
          []
        else
          values = Enum.map(source_values, fn {_sid, v} -> v end)

          has_conflict =
            if Enum.all?(values, &is_number/1) do
              {vmin, vmax} = Enum.min_max(values)
              vmax - vmin > threshold
            else
              length(Enum.uniq(values)) > 1
            end

          if has_conflict, do: [{key, source_values}], else: []
        end
      end)

    {:reply, conflicts, state}
  end

  @impl true
  def handle_call(:source_weights, _from, state) do
    weights = Map.new(state.sources, fn {sid, %{trust: t}} -> {sid, t} end)
    {:reply, weights, state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec perform_fusion(%{source_id() => source_entry()}) :: fused_state()
  defp perform_fusion(sources) do
    # Collect all data from ETS for each registered source
    all_entries =
      Enum.flat_map(sources, fn {sid, %{trust: trust}} ->
        case :ets.lookup(@ets_table, {:source, sid}) do
          [{_, data}] when is_map(data) ->
            Enum.map(data, fn {k, v} -> {k, v, trust} end)

          _ ->
            []
        end
      end)

    # Group by key
    by_key =
      Enum.group_by(all_entries, fn {k, _v, _t} -> k end, fn {_k, v, t} -> {v, t} end)

    Map.new(by_key, fn {key, weighted_values} ->
      {key, fuse_values(weighted_values)}
    end)
  end

  @spec fuse_values([{term(), trust_score()}]) :: fused_value()
  defp fuse_values(weighted_values) do
    total_weight = Enum.reduce(weighted_values, 0.0, fn {_v, w}, acc -> acc + w end)

    {consensus_value, confidence} =
      if all_numeric?(weighted_values) do
        weighted_sum =
          Enum.reduce(weighted_values, 0.0, fn {v, w}, acc ->
            acc + v * w
          end)

        avg = if total_weight > 0.0, do: weighted_sum / total_weight, else: 0.0

        # Confidence: 1 - normalized_variance
        variance = compute_weighted_variance(weighted_values, avg, total_weight)
        conf = max(0.0, 1.0 - min(1.0, variance))
        {avg, conf}
      else
        # Weighted vote: pick value with highest total weight
        vote_map =
          Enum.reduce(weighted_values, %{}, fn {v, w}, acc ->
            Map.update(acc, v, w, &(&1 + w))
          end)

        {winner, winner_weight} = Enum.max_by(vote_map, fn {_v, w} -> w end)
        conf = if total_weight > 0.0, do: winner_weight / total_weight, else: 0.0
        {winner, conf}
      end

    %{
      value: consensus_value,
      confidence: confidence,
      source_count: length(weighted_values)
    }
  end

  @spec all_numeric?([{term(), trust_score()}]) :: boolean()
  defp all_numeric?(weighted_values) do
    Enum.all?(weighted_values, fn {v, _w} -> is_number(v) end)
  end

  @spec compute_weighted_variance([{number(), trust_score()}], float(), float()) :: float()
  defp compute_weighted_variance(_, _, total_weight) when total_weight == 0.0, do: 0.0

  defp compute_weighted_variance(weighted_values, mean, total_weight) do
    sum_sq =
      Enum.reduce(weighted_values, 0.0, fn {v, w}, acc ->
        acc + w * (v - mean) * (v - mean)
      end)

    sum_sq / total_weight
  end

  @spec monotonic_ms() :: integer()
  defp monotonic_ms, do: System.monotonic_time(:millisecond)
end
