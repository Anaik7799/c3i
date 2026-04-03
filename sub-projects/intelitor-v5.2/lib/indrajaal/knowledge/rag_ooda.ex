defmodule Indrajaal.Knowledge.RagOoda do
  @moduledoc """
  RAG-Enhanced OODA Loop Integration.

  ## What
  Augments the Fast OODA Loop with Retrieval-Augmented Generation (RAG)
  capabilities, providing context-aware decision making through knowledge
  retrieval from the IKE (Indrajaal Knowledge Engine).

  ## Why
  Standard OODA loops operate with limited context. RAG enhancement enables:
  - Historical pattern matching for better orientation
  - Similar situation retrieval for informed decisions
  - Learning from past outcomes
  - Context injection into AI orientation phase

  ## OODA + RAG Flow
  ```
  OBSERVE ──► [Telemetry] ──► ORIENT ◄── [RAG Context]
                                │              ▲
                                ▼              │
                            DECIDE ────► ACT ──┤
                                │              │
                                └── [Record] ──┘
  ```

  ## Constraints
  - SC-OODA-001: Total cycle time <100ms (RAG lookup <20ms)
  - SC-OODA-006: AI orientation with 20ms timeout
  - AOR-CAE-003: Learning feedback to TrainingGym
  """

  use GenServer
  require Logger

  alias Indrajaal.Knowledge.Engine, as: IKE
  # FastOoda integration happens via enhance_orientation/2 and enhance_decision/2

  @rag_lookup_timeout_ms 20
  @context_cache_ttl_ms 5_000
  @max_context_items 10

  defstruct [
    :name,
    context_cache: %{},
    cache_timestamps: %{},
    stats: %{
      queries: 0,
      cache_hits: 0,
      cache_misses: 0,
      avg_latency_us: 0
    }
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the RAG-OODA integration service.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Retrieve RAG context for an OODA observation.
  Returns within @rag_lookup_timeout_ms or empty context.
  """
  @spec get_context(map()) :: {:ok, map()}
  def get_context(observation) do
    GenServer.call(__MODULE__, {:get_context, observation}, @rag_lookup_timeout_ms + 50)
  catch
    :exit, {:timeout, _} ->
      Logger.warning("[RagOoda] Context lookup timeout - using empty context")
      {:ok, %{items: [], source: :timeout}}
  end

  @doc """
  Record an OODA cycle outcome for learning.
  Non-blocking async operation.
  """
  @spec record_outcome(map()) :: :ok
  def record_outcome(outcome) do
    GenServer.cast(__MODULE__, {:record_outcome, outcome})
  end

  @doc """
  Get RAG-OODA statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Invalidate context cache for a specific key or all.
  """
  @spec invalidate_cache(atom() | :all) :: :ok
  def invalidate_cache(key \\ :all) do
    GenServer.cast(__MODULE__, {:invalidate_cache, key})
  end

  # ============================================================================
  # OODA Integration Points
  # ============================================================================

  @doc """
  Enhanced ORIENT phase with RAG context injection.
  Called by FastOoda during orientation.
  """
  @spec enhance_orientation(map(), map()) :: map()
  def enhance_orientation(observation, base_orientation) do
    case get_context(observation) do
      {:ok, context} when map_size(context) > 0 ->
        Map.merge(base_orientation, %{
          rag_context: context,
          enhanced: true,
          enhancement_timestamp: System.monotonic_time(:microsecond)
        })

      _ ->
        Map.put(base_orientation, :enhanced, false)
    end
  end

  @doc """
  Enhanced DECIDE phase with historical pattern matching.
  """
  @spec enhance_decision(map(), map()) :: map()
  def enhance_decision(orientation, base_decision) do
    # Check for similar past decisions and their outcomes
    similar_outcomes = get_similar_outcomes(orientation)

    weighted_decision =
      if length(similar_outcomes) > 0 do
        # Adjust confidence based on past success rates
        success_rate = calculate_success_rate(similar_outcomes)

        %{
          base_decision
          | confidence: adjust_confidence(base_decision[:confidence] || 0.5, success_rate),
            historical_support: length(similar_outcomes),
            similar_outcomes: Enum.take(similar_outcomes, 3)
        }
      else
        base_decision
      end

    weighted_decision
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    state = %__MODULE__{
      name: Keyword.get(opts, :name, __MODULE__)
    }

    Logger.info("[RagOoda] RAG-Enhanced OODA initialized")

    {:ok, state}
  end

  @impl true
  def handle_call({:get_context, observation}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    # Generate cache key from observation
    cache_key = generate_cache_key(observation)

    # Check cache first
    {context, new_state} =
      case check_cache(state, cache_key) do
        {:hit, cached} ->
          new_stats = %{state.stats | cache_hits: state.stats.cache_hits + 1}
          {cached, %{state | stats: new_stats}}

        :miss ->
          # Perform RAG lookup with timeout
          context = perform_rag_lookup(observation)

          # Update cache and stats
          new_state = update_cache(state, cache_key, context)

          new_stats = %{
            new_state.stats
            | cache_misses: state.stats.cache_misses + 1,
              queries: state.stats.queries + 1
          }

          {context, %{new_state | stats: new_stats}}
      end

    # Update latency stats
    latency = System.monotonic_time(:microsecond) - start_time
    final_stats = update_latency_stats(new_state.stats, latency)

    {:reply, {:ok, context}, %{new_state | stats: final_stats}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_cast({:record_outcome, outcome}, state) do
    # Record to IKE for future retrieval
    spawn(fn ->
      IKE.record_ooda_outcome(
        outcome[:cycle_id],
        outcome[:observation],
        outcome[:decision],
        outcome[:result]
      )
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:invalidate_cache, :all}, state) do
    {:noreply, %{state | context_cache: %{}, cache_timestamps: %{}}}
  end

  @impl true
  def handle_cast({:invalidate_cache, key}, state) do
    new_cache = Map.delete(state.context_cache, key)
    new_timestamps = Map.delete(state.cache_timestamps, key)

    {:noreply, %{state | context_cache: new_cache, cache_timestamps: new_timestamps}}
  end

  # ============================================================================
  # RAG Lookup Implementation
  # ============================================================================

  defp perform_rag_lookup(observation) do
    # Extract key features for retrieval
    query = extract_query_features(observation)

    # Parallel retrieval from multiple sources
    tasks = [
      Task.async(fn -> fetch_similar_observations(query) end),
      Task.async(fn -> fetch_recent_context(query) end),
      Task.async(fn -> fetch_domain_knowledge(query) end)
    ]

    # Await with timeout
    results =
      Task.yield_many(tasks, @rag_lookup_timeout_ms)
      |> Enum.map(fn {task, result} ->
        case result do
          {:ok, value} ->
            value

          nil ->
            Task.shutdown(task, :brutal_kill)
            []
        end
      end)

    [similar, recent, domain] = results

    %{
      similar_observations: similar,
      recent_context: recent,
      domain_knowledge: domain,
      timestamp: DateTime.utc_now(),
      source: :rag_lookup
    }
  end

  defp fetch_similar_observations(query) do
    case IKE.find_similar_situations(query, @max_context_items) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp fetch_recent_context(query) do
    domain = Map.get(query, :domain, :system)

    case IKE.get_recent_events(@max_context_items) do
      {:ok, events} ->
        Enum.filter(events, fn e ->
          Map.get(e, :domain) == domain
        end)

      _ ->
        []
    end
  end

  defp fetch_domain_knowledge(_query) do
    # Would fetch from vectorized knowledge base
    # Placeholder for now
    []
  end

  defp extract_query_features(observation) do
    %{
      domain: Map.get(observation, :domain, :unknown),
      type: Map.get(observation, :type, :unknown),
      severity: Map.get(observation, :severity, :normal),
      keywords: extract_keywords(observation),
      timestamp: Map.get(observation, :timestamp, DateTime.utc_now())
    }
  end

  defp extract_keywords(observation) do
    observation
    |> Map.take([:type, :domain, :action, :event])
    |> Map.values()
    |> Enum.filter(&is_atom/1)
    |> Enum.map(&Atom.to_string/1)
  end

  # ============================================================================
  # Similar Outcome Analysis
  # ============================================================================

  defp get_similar_outcomes(orientation) do
    query = Map.take(orientation, [:domain, :situation_type, :threat_level])

    case IKE.find_similar_situations(query, 10) do
      {:ok, situations} ->
        Enum.filter(situations, fn s -> Map.has_key?(s, :outcome) end)

      _ ->
        []
    end
  end

  defp calculate_success_rate([]), do: 0.0

  defp calculate_success_rate(episodes) do
    successes = Enum.count(episodes, & &1.success)
    successes / length(episodes)
  end

  defp adjust_confidence(base_confidence, success_rate) do
    # Blend base confidence with historical success rate
    # Weight historical evidence based on sample size
    blended = base_confidence * 0.6 + success_rate * 0.4
    Float.round(blended, 3)
  end

  # ============================================================================
  # Cache Management
  # ============================================================================

  defp generate_cache_key(observation) do
    # Create deterministic key from observation features
    key_data = Map.take(observation, [:domain, :type, :agent_id])
    :erlang.phash2(key_data)
  end

  defp check_cache(state, cache_key) do
    case Map.get(state.context_cache, cache_key) do
      nil ->
        :miss

      cached ->
        timestamp = Map.get(state.cache_timestamps, cache_key, 0)
        now = System.monotonic_time(:millisecond)

        if now - timestamp < @context_cache_ttl_ms do
          {:hit, cached}
        else
          :miss
        end
    end
  end

  defp update_cache(state, cache_key, context) do
    now = System.monotonic_time(:millisecond)

    %{
      state
      | context_cache: Map.put(state.context_cache, cache_key, context),
        cache_timestamps: Map.put(state.cache_timestamps, cache_key, now)
    }
  end

  defp update_latency_stats(stats, new_latency) do
    # Exponential moving average
    alpha = 0.1

    new_avg =
      if stats.avg_latency_us == 0 do
        new_latency
      else
        alpha * new_latency + (1 - alpha) * stats.avg_latency_us
      end

    %{stats | avg_latency_us: Float.round(new_avg, 2)}
  end
end
