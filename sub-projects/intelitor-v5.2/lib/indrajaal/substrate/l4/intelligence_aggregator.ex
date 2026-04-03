defmodule Indrajaal.Substrate.L4.IntelligenceAggregator do
  @moduledoc """
  ## Design Intent
  L4 GenServer collecting intelligence from multiple heterogeneous sources and
  computing a weighted consensus signal for the Indrajaal VSM fractal mesh.
  Maintains an ETS-backed source registry so sources can be registered/deregistered
  at runtime without restarting the aggregator.

  Intelligence model:
    - Each registered source has: id, weight (0.0–1.0), last_report timestamp, report_count
    - Intelligence items arrive via `ingest/2` with a confidence score (0.0–1.0)
    - Weighted consensus is computed as: Σ(confidence_i × weight_i) / Σ(weight_i)
    - Consensus is classified: :high (≥ 0.7), :medium (≥ 0.4), :low (< 0.4)
    - Results broadcast to "prajna:intelligence" PubSub topic every 15 s

  ETS layout:
    @ets_sources  — {source_id :: String.t(), source_meta :: map()}
    @ets_reports  — {report_id :: String.t(), report :: map()}

  ## STAMP Constraints
  - SC-VER-041: OODA cycle < 100ms — consensus computation is O(n sources)
  - SC-MON-003: Domain metrics per domain — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (Task 93, L4) |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_sources :intelligence_aggregator_sources
  @ets_reports :intelligence_aggregator_reports
  @pubsub_topic "prajna:intelligence"
  @zenoh_topic "indrajaal/substrate/l4/intelligence/consensus"
  @checkpoint "CP-L4-INTEL-AGGR-01"

  # Aggregation tick ms
  @aggregate_ms 15_000

  # Maximum reports to retain in ETS per aggregation window
  @max_reports 500

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type consensus_level :: :high | :medium | :low

  @type source :: %{
          id: String.t(),
          name: String.t(),
          weight: float(),
          report_count: non_neg_integer(),
          last_report_at: integer() | nil
        }

  @type report :: %{
          id: String.t(),
          source_id: String.t(),
          confidence: float(),
          payload: map(),
          ingested_at: integer()
        }

  @type consensus :: %{
          score: float(),
          level: consensus_level(),
          source_count: non_neg_integer(),
          report_count: non_neg_integer(),
          computed_at: String.t()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Register an intelligence source.

  - `id`     — unique source identifier
  - `name`   — human-readable name
  - `weight` — contribution weight 0.0..1.0
  """
  @spec register_source(String.t(), String.t(), float()) :: :ok | {:error, term()}
  def register_source(id, name, weight)
      when is_binary(id) and is_binary(name) and is_float(weight) do
    if weight >= 0.0 and weight <= 1.0 do
      GenServer.call(@name, {:register_source, id, name, weight})
    else
      {:error, :weight_out_of_range}
    end
  end

  @doc """
  Ingest an intelligence report from a registered source.

  - `source_id`  — id of the registered source
  - `confidence` — confidence score 0.0..1.0
  - `payload`    — arbitrary metadata map
  """
  @spec ingest(String.t(), float(), map()) :: {:ok, String.t()} | {:error, term()}
  def ingest(source_id, confidence, payload \\ %{})
      when is_binary(source_id) and is_float(confidence) and is_map(payload) do
    if confidence >= 0.0 and confidence <= 1.0 do
      GenServer.call(@name, {:ingest, source_id, confidence, payload})
    else
      {:error, :confidence_out_of_range}
    end
  end

  @doc """
  Compute and return the current weighted consensus immediately.
  """
  @spec compute_consensus() :: consensus()
  def compute_consensus do
    GenServer.call(@name, :compute_consensus)
  end

  @doc """
  List all registered sources.
  """
  @spec list_sources() :: [source()]
  def list_sources do
    GenServer.call(@name, :list_sources)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_sources, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@ets_reports, [:set, :public, :named_table, read_concurrency: true])

    interval_ms = Keyword.get(opts, :aggregate_interval_ms, @aggregate_ms)
    schedule_aggregate(interval_ms)

    state = %{
      aggregate_count: 0,
      total_ingested: 0,
      aggregate_interval_ms: interval_ms,
      started_at: DateTime.utc_now()
    }

    Logger.warning("[INTEL_AGGR] Started — checkpoint=#{@checkpoint}")

    {:ok, state}
  end

  @impl true
  def handle_call({:register_source, id, name, weight}, _from, state) do
    source = %{
      id: id,
      name: name,
      weight: weight,
      report_count: 0,
      last_report_at: nil
    }

    :ets.insert(@ets_sources, {id, source})

    Logger.debug("[INTEL_AGGR] Source registered id=#{id} name=#{name} weight=#{weight}")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:ingest, source_id, confidence, payload}, _from, state) do
    case :ets.lookup(@ets_sources, source_id) do
      [{^source_id, source}] ->
        report_id = generate_id()
        now = System.monotonic_time(:millisecond)

        report = %{
          id: report_id,
          source_id: source_id,
          confidence: confidence,
          payload: payload,
          ingested_at: now
        }

        :ets.insert(@ets_reports, {report_id, report})

        # Update source metadata
        updated_source = %{
          source
          | report_count: source.report_count + 1,
            last_report_at: now
        }

        :ets.insert(@ets_sources, {source_id, updated_source})

        prune_old_reports()

        new_state = %{state | total_ingested: state.total_ingested + 1}

        Logger.debug(
          "[INTEL_AGGR] Report ingested id=#{report_id} " <>
            "source=#{source_id} confidence=#{confidence}"
        )

        {:reply, {:ok, report_id}, new_state}

      [] ->
        {:reply, {:error, :unknown_source}, state}
    end
  end

  @impl true
  def handle_call(:compute_consensus, _from, state) do
    consensus = do_compute_consensus()
    {:reply, consensus, state}
  end

  @impl true
  def handle_call(:list_sources, _from, state) do
    sources =
      :ets.tab2list(@ets_sources)
      |> Enum.map(fn {_id, s} -> s end)

    {:reply, sources, state}
  end

  @impl true
  def handle_info(:aggregate_tick, state) do
    consensus = do_compute_consensus()
    new_state = %{state | aggregate_count: state.aggregate_count + 1}

    broadcast_consensus(consensus, new_state.aggregate_count)
    emit_telemetry(consensus, new_state.aggregate_count)

    Logger.debug(
      "[INTEL_AGGR] Aggregate #{new_state.aggregate_count} — " <>
        "score=#{consensus.score} level=#{consensus.level} " <>
        "sources=#{consensus.source_count}"
    )

    schedule_aggregate(state.aggregate_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[INTEL_AGGR] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp do_compute_consensus do
    sources = :ets.tab2list(@ets_sources) |> Enum.map(fn {_id, s} -> s end)
    reports = :ets.tab2list(@ets_reports) |> Enum.map(fn {_id, r} -> r end)

    source_map = Map.new(sources, &{&1.id, &1})

    # Weighted sum: Σ(confidence_i × weight_i) per source (take latest report per source)
    latest_by_source =
      reports
      |> Enum.group_by(& &1.source_id)
      |> Enum.map(fn {source_id, source_reports} ->
        latest = Enum.max_by(source_reports, & &1.ingested_at, fn -> nil end)
        {source_id, latest}
      end)

    {weighted_sum, total_weight} =
      Enum.reduce(latest_by_source, {0.0, 0.0}, fn {source_id, report}, {ws, tw} ->
        case Map.get(source_map, source_id) do
          nil ->
            {ws, tw}

          source ->
            {ws + report.confidence * source.weight, tw + source.weight}
        end
      end)

    score =
      if total_weight > 0.0 do
        Float.round(weighted_sum / total_weight, 4)
      else
        0.0
      end

    level =
      cond do
        score >= 0.7 -> :high
        score >= 0.4 -> :medium
        true -> :low
      end

    %{
      score: score,
      level: level,
      source_count: length(sources),
      report_count: length(reports),
      computed_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp prune_old_reports do
    reports = :ets.tab2list(@ets_reports)

    if length(reports) > @max_reports do
      reports
      |> Enum.sort_by(fn {_id, r} -> r.ingested_at end)
      |> Enum.take(length(reports) - @max_reports)
      |> Enum.each(fn {id, _} -> :ets.delete(@ets_reports, id) end)
    end
  end

  defp schedule_aggregate(interval_ms) do
    Process.send_after(self(), :aggregate_tick, interval_ms)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp broadcast_consensus(consensus, count) do
    payload = Map.put(consensus, :aggregate_count, count)

    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:consensus_updated, payload}
      )
    rescue
      _ -> :ok
    end

    publish_zenoh(payload)
  end

  defp publish_zenoh(payload) do
    data =
      Map.merge(payload, %{
        checkpoint: @checkpoint,
        topic: @zenoh_topic,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(@zenoh_topic, data)
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(consensus, count) do
    try do
      :telemetry.execute(
        [:indrajaal, :substrate, :l4, :intelligence_aggregator, :aggregate],
        %{score: consensus.score, source_count: consensus.source_count, aggregate_count: count},
        %{checkpoint: @checkpoint, level: consensus.level, constraint: "SC-MON-003"}
      )
    rescue
      _ -> :ok
    end
  end
end
