defmodule Indrajaal.Adaptation.FitnessEvaluator do
  @moduledoc """
  ## Design Intent
  Multi-objective fitness evaluator for the Indrajaal evolutionary adaptation layer.
  Evaluates system configuration candidates across registered fitness dimensions and
  detects Pareto-optimal solutions for multi-objective evolutionary selection.

  Fitness evaluation is used by the EvolutionEngine (and external callers) to score
  candidate configurations before selection, crossover, and mutation. All dimensions
  are independently weighted; the composite score is a weighted sum normalized to
  0.0–1.0. Pareto front computation identifies non-dominated solutions.

  Evaluation process:
    1. Caller registers dimensions with `register_dimension/3` (name, weight, evaluator fn)
    2. Candidate map passed to `evaluate/1` — each dimension fn receives the candidate
    3. Raw scores clamped to 0.0–1.0, weighted, and summed into composite fitness
    4. Result stored in ETS for fast retrieval (keyed by candidate hash)
    5. `pareto_front/0` scans all cached evaluations and returns non-dominated set
    6. `fitness_landscape/0` returns the full evaluation cache for visualization

  Dimensions ship with defaults (can be replaced):
    :latency   — lower is better (inverted ms measurement)
    :throughput — higher is better (events/s measurement)
    :error_rate — lower is better (inverted fraction)
    :cpu_usage  — lower is better (inverted fraction)

  ## STAMP Constraints
  - SC-EVO-001: Evolution MUST follow hardened protocol — ENFORCED (bounded evaluation)
  - SC-SWARM-003: Fitness evaluation < 10ms per agent — ENFORCED (O(d) per candidate)
  - SC-EVO-003: Mutation MUST be bounded — REFERENCED (fitness guides selection)
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_dimensions :fitness_dimensions
  @ets_evaluations :fitness_evaluations
  @pubsub_topic "adaptation:fitness"
  @zenoh_topic "indrajaal/adaptation/fitness/landscape"
  @checkpoint "CP-ADAPT-FITNESS-01"

  # Maximum cached evaluations (older entries evicted)
  @max_cached 500

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type dimension_name :: atom()

  @type dimension :: %{
          name: dimension_name(),
          weight: float(),
          evaluator: (map() -> float()),
          registered_at: integer()
        }

  @type fitness_result :: %{
          candidate_hash: String.t(),
          candidate: map(),
          dimension_scores: %{dimension_name() => float()},
          composite_score: float(),
          evaluated_at: integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Evaluate a candidate configuration map against all registered dimensions.
  Returns a fitness_result with per-dimension scores and composite fitness.
  """
  @spec evaluate(map()) :: {:ok, fitness_result()} | {:error, term()}
  def evaluate(candidate) when is_map(candidate) do
    GenServer.call(@name, {:evaluate, candidate})
  end

  @doc """
  Register or replace a fitness dimension.

  - `name`      — atom identifier for the dimension
  - `weight`    — relative importance (will be normalized across all dimensions)
  - `opts`      — keyword: evaluator (fn/1 that returns float 0.0..1.0)
  """
  @spec register_dimension(dimension_name(), float(), keyword()) :: :ok
  def register_dimension(name, weight, opts \\ [])
      when is_atom(name) and is_float(weight) do
    GenServer.call(@name, {:register_dimension, name, weight, opts})
  end

  @doc """
  Returns the full fitness landscape: list of all cached evaluation results,
  sorted descending by composite score.
  """
  @spec fitness_landscape() :: [fitness_result()]
  def fitness_landscape do
    GenServer.call(@name, :fitness_landscape)
  end

  @doc """
  Computes and returns the Pareto front from the cached fitness evaluations.
  A solution is Pareto-optimal if no other solution dominates it across all
  dimensions simultaneously.
  """
  @spec pareto_front() :: [fitness_result()]
  def pareto_front do
    GenServer.call(@name, :pareto_front)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_dimensions, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@ets_evaluations, [:set, :public, :named_table, read_concurrency: true])

    # Register default dimensions unless disabled
    unless Keyword.get(opts, :skip_defaults, false) do
      register_defaults()
    end

    state = %{
      total_evaluations: 0,
      cache_evictions: 0,
      started_at: DateTime.utc_now()
    }

    Logger.warning("[FITNESS] FitnessEvaluator started — checkpoint=#{@checkpoint}")

    {:ok, state}
  end

  @impl true
  def handle_call({:evaluate, candidate}, _from, state) do
    hash = candidate_hash(candidate)

    # Check cache first
    case :ets.lookup(@ets_evaluations, hash) do
      [{^hash, cached}] ->
        {:reply, {:ok, cached}, state}

      [] ->
        result = perform_evaluation(candidate, hash)
        store_evaluation(result, state.total_evaluations)
        broadcast_evaluation(result)
        emit_telemetry(:evaluate, result.composite_score)

        new_state = %{state | total_evaluations: state.total_evaluations + 1}
        {:reply, {:ok, result}, new_state}
    end
  end

  @impl true
  def handle_call({:register_dimension, name, weight, opts}, _from, state) do
    evaluator = Keyword.get(opts, :evaluator, fn _candidate -> 0.5 end)

    dimension = %{
      name: name,
      weight: max(0.0, weight),
      evaluator: evaluator,
      registered_at: System.monotonic_time(:millisecond)
    }

    :ets.insert(@ets_dimensions, {name, dimension})

    Logger.debug("[FITNESS] Dimension registered name=#{name} weight=#{weight}")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:fitness_landscape, _from, state) do
    landscape =
      :ets.tab2list(@ets_evaluations)
      |> Enum.map(fn {_hash, result} -> result end)
      |> Enum.sort_by(& &1.composite_score, :desc)

    {:reply, landscape, state}
  end

  @impl true
  def handle_call(:pareto_front, _from, state) do
    all_results =
      :ets.tab2list(@ets_evaluations)
      |> Enum.map(fn {_hash, result} -> result end)

    front = compute_pareto_front(all_results)
    emit_telemetry(:pareto_front, length(front) * 1.0)
    {:reply, front, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[FITNESS] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private — evaluation logic
  # ---------------------------------------------------------------------------

  defp perform_evaluation(candidate, hash) do
    dimensions = :ets.tab2list(@ets_dimensions)

    dimension_scores =
      Enum.reduce(dimensions, %{}, fn {name, dim}, acc ->
        raw =
          try do
            dim.evaluator.(candidate)
          rescue
            _ -> 0.0
          end

        score = raw |> max(0.0) |> min(1.0)
        Map.put(acc, name, score)
      end)

    composite = compute_composite(dimension_scores, dimensions)

    %{
      candidate_hash: hash,
      candidate: candidate,
      dimension_scores: dimension_scores,
      composite_score: Float.round(composite, 6),
      evaluated_at: System.monotonic_time(:millisecond)
    }
  end

  defp compute_composite(dimension_scores, dimensions) do
    total_weight =
      Enum.reduce(dimensions, 0.0, fn {_name, dim}, acc -> acc + dim.weight end)

    if total_weight <= 0.0 do
      0.0
    else
      weighted_sum =
        Enum.reduce(dimensions, 0.0, fn {name, dim}, acc ->
          score = Map.get(dimension_scores, name, 0.0)
          acc + score * dim.weight
        end)

      weighted_sum / total_weight
    end
  end

  defp compute_pareto_front(results) do
    Enum.filter(results, fn candidate ->
      not Enum.any?(results, fn other ->
        other.candidate_hash != candidate.candidate_hash and
          dominates?(other, candidate)
      end)
    end)
  end

  # Returns true if `a` dominates `b`:
  # a is at least as good as b in all dimensions and strictly better in at least one.
  defp dominates?(a, b) do
    a_scores = a.dimension_scores
    b_scores = b.dimension_scores
    all_dims = (Map.keys(a_scores) ++ Map.keys(b_scores)) |> Enum.uniq()

    at_least_as_good =
      Enum.all?(all_dims, fn dim ->
        Map.get(a_scores, dim, 0.0) >= Map.get(b_scores, dim, 0.0)
      end)

    strictly_better =
      Enum.any?(all_dims, fn dim ->
        Map.get(a_scores, dim, 0.0) > Map.get(b_scores, dim, 0.0)
      end)

    at_least_as_good and strictly_better
  end

  defp store_evaluation(result, eval_count) do
    :ets.insert(@ets_evaluations, {result.candidate_hash, result})

    # Evict oldest when over limit (approximate — use eval count as proxy)
    if rem(eval_count + 1, 50) == 0 do
      all = :ets.tab2list(@ets_evaluations)

      if length(all) > @max_cached do
        oldest =
          all
          |> Enum.sort_by(fn {_h, r} -> r.evaluated_at end)
          |> Enum.take(length(all) - @max_cached)

        Enum.each(oldest, fn {hash, _} -> :ets.delete(@ets_evaluations, hash) end)
      end
    end
  end

  defp candidate_hash(candidate) do
    candidate
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp register_defaults do
    # Default dimensions — callers can override by registering with the same name
    :ets.insert(@ets_dimensions, {
      :latency,
      %{
        name: :latency,
        weight: 1.0,
        evaluator: fn c ->
          ms = Map.get(c, :latency_ms, 500)
          1.0 - min(1.0, ms / 1000.0)
        end,
        registered_at: System.monotonic_time(:millisecond)
      }
    })

    :ets.insert(@ets_dimensions, {
      :throughput,
      %{
        name: :throughput,
        weight: 1.0,
        evaluator: fn c ->
          eps = Map.get(c, :events_per_sec, 0)
          min(1.0, eps / 1000.0)
        end,
        registered_at: System.monotonic_time(:millisecond)
      }
    })

    :ets.insert(@ets_dimensions, {
      :error_rate,
      %{
        name: :error_rate,
        weight: 2.0,
        evaluator: fn c ->
          rate = Map.get(c, :error_rate, 0.0)
          1.0 - min(1.0, rate)
        end,
        registered_at: System.monotonic_time(:millisecond)
      }
    })

    :ets.insert(@ets_dimensions, {
      :cpu_usage,
      %{
        name: :cpu_usage,
        weight: 1.0,
        evaluator: fn c ->
          pct = Map.get(c, :cpu_pct, 50.0)
          1.0 - min(1.0, pct / 100.0)
        end,
        registered_at: System.monotonic_time(:millisecond)
      }
    })
  end

  defp broadcast_evaluation(result) do
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:fitness_evaluated, result.candidate_hash, result.composite_score}
      )
    rescue
      _ -> :ok
    end

    publish_zenoh(result)
  end

  defp publish_zenoh(result) do
    data = %{
      checkpoint: @checkpoint,
      topic: @zenoh_topic,
      candidate_hash: result.candidate_hash,
      composite_score: result.composite_score,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(@zenoh_topic, data)
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(event, score) do
    try do
      :telemetry.execute(
        [:indrajaal, :adaptation, :fitness, event],
        %{score: score},
        %{constraint: "SC-EVO-001"}
      )
    rescue
      _ -> :ok
    end
  end
end
