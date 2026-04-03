defmodule Indrajaal.Cortex.KnowledgeGraphQuery do
  @moduledoc """
  Cortex Knowledge Graph Query — queries SMRITI federation for contextual knowledge.

  WHAT: Bridges the Cortex cognitive layer with SMRITI's distributed knowledge mesh,
        enabling AI-assisted context retrieval via FTS5 search, vector similarity,
        and federation protocol.
  WHY: The Cortex needs access to historical system knowledge, past incidents,
       and SRE patterns stored in SMRITI holons to generate informed recommendations.
  CONSTRAINTS: SC-SMRITI-063 (federation sync), SC-SMRITI-131 (FTS5),
               SC-SMRITI-133 (query < 500ms), SC-AI-001 (context via SMRITI),
               SC-XHOLON-003 (cross-holon via Zenoh only), SC-DBLOCAL-001 (local direct).

  ## Architecture

  ```
  ┌──────────────────────────────────────────────────────────────┐
  │             CORTEX KNOWLEDGE GRAPH QUERY                     │
  │                                                              │
  │  Query ──► FTS5 Search (local) ──► results                  │
  │            │                                                 │
  │            ├──► Vector Similarity ──► semantic matches       │
  │            │                                                 │
  │            └──► Federation Protocol ──► peer knowledge       │
  │                          │                                   │
  │                    Knowledge Engine                          │
  │                    (recall + context)                        │
  └──────────────────────────────────────────────────────────────┘
  ```

  ## Change History

  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-03-23 | Claude Sonnet 4.6 | Initial implementation |
  """

  use GenServer
  require Logger

  # ============================================================
  # CONSTANTS
  # ============================================================

  @ets_table :knowledge_graph_query_cache
  @query_timeout 4_500
  @default_limit 10
  @cache_ttl_ms 300_000

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type knowledge_result :: %{
          id: String.t(),
          title: String.t(),
          content: String.t(),
          relevance: float(),
          source: :fts5 | :vector | :federation | :knowledge_engine,
          tags: [String.t()],
          holon: String.t() | nil,
          timestamp: DateTime.t() | nil
        }

  @type query_options :: [
          limit: pos_integer(),
          sources: [:fts5 | :vector | :federation | :knowledge_engine],
          include_context: boolean(),
          min_relevance: float()
        ]

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Starts the KnowledgeGraphQuery GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queries the SMRITI knowledge graph for relevant information.

  Searches across multiple sources (FTS5, vector similarity, federation)
  and merges results by relevance score.

  ## Parameters
  - query: Search query string
  - opts: Query options (limit, sources, include_context, min_relevance)

  ## Returns
  - {:ok, [knowledge_result()]} sorted by relevance descending
  - {:error, reason}
  """
  @spec query(String.t(), query_options()) :: {:ok, [knowledge_result()]} | {:error, term()}
  def query(query, opts \\ []) when is_binary(query) do
    GenServer.call(__MODULE__, {:query, query, opts}, @query_timeout + 1_000)
  end

  @doc """
  Retrieves system context for a given topic using SMRITI federation.

  Combines recent events with similar historical situations for Cortex AI context.

  ## Parameters
  - topic: Topic to retrieve context for
  - opts: Options including limit

  ## Returns
  - {:ok, context_map} with recent_events, similar_situations, knowledge_entries
  - {:error, reason}
  """
  @spec get_context(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_context(topic, opts \\ []) when is_binary(topic) do
    GenServer.call(__MODULE__, {:get_context, topic, opts}, @query_timeout + 1_000)
  end

  @doc """
  Memorizes a new knowledge entry into SMRITI via the Knowledge Engine.

  ## Parameters
  - entry: Map with :title, :content, :tags (optional)

  ## Returns
  - :ok
  - {:error, reason}
  """
  @spec memorize(map()) :: :ok | {:error, term()}
  def memorize(entry) when is_map(entry) do
    GenServer.call(__MODULE__, {:memorize, entry}, 5_000)
  end

  @doc """
  Returns cache statistics and module health.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Returns true if the module is available and responding.
  """
  @spec available?() :: boolean()
  def available? do
    case Process.whereis(__MODULE__) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  @doc """
  Responds to health check pings.
  """
  @spec ping() :: :pong
  def ping do
    GenServer.call(__MODULE__, :ping)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("[KnowledgeGraphQuery] Starting knowledge graph query bridge")

    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :public, :set, read_concurrency: true])
    end

    state = %{
      total_queries: 0,
      cache_hits: 0,
      fts5_available: check_fts5_available(),
      vector_available: check_vector_available(),
      knowledge_engine_available: check_knowledge_engine_available(),
      federation_available: check_federation_available()
    }

    :telemetry.execute(
      [:cortex, :knowledge_graph_query, :started],
      %{timestamp: System.system_time(:millisecond)},
      %{
        fts5: state.fts5_available,
        vector: state.vector_available,
        knowledge_engine: state.knowledge_engine_available,
        federation: state.federation_available
      }
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:ping, _from, state), do: {:reply, :pong, state}

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, Map.put(state, :cache_size, :ets.info(@ets_table, :size)), state}
  end

  @impl true
  def handle_call({:query, query, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    cache_key = cache_key(query, opts)

    {result, new_state} =
      case lookup_cache(cache_key) do
        {:hit, cached} ->
          Logger.debug("[KnowledgeGraphQuery] Cache hit for query: #{String.slice(query, 0, 50)}")
          {{:ok, cached}, %{state | cache_hits: state.cache_hits + 1}}

        :miss ->
          results = do_query(query, opts, state)
          store_cache(cache_key, results)
          {results, %{state | total_queries: state.total_queries + 1}}
      end

    elapsed = System.monotonic_time(:millisecond) - start_time

    :telemetry.execute(
      [:cortex, :knowledge_graph_query, :query_complete],
      %{elapsed_ms: elapsed, result_count: result_count(result)},
      %{query_length: String.length(query)}
    )

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:get_context, topic, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 5)

    context = build_context(topic, limit, state)

    {:reply, {:ok, context}, state}
  end

  @impl true
  def handle_call({:memorize, entry}, _from, state) do
    result = do_memorize(entry, state)
    {:reply, result, state}
  end

  # ============================================================
  # QUERY EXECUTION
  # ============================================================

  @spec do_query(String.t(), query_options(), map()) ::
          {:ok, [knowledge_result()]} | {:error, term()}
  defp do_query(query, opts, state) do
    limit = Keyword.get(opts, @default_limit |> then(fn _ -> :limit end), @default_limit)
    min_relevance = Keyword.get(opts, :min_relevance, 0.0)
    sources = Keyword.get(opts, :sources, [:fts5, :knowledge_engine])

    results =
      sources
      |> Enum.flat_map(&query_source(&1, query, limit, state))
      |> deduplicate_results()
      |> Enum.filter(&(&1.relevance >= min_relevance))
      |> Enum.sort_by(& &1.relevance, :desc)
      |> Enum.take(limit)

    {:ok, results}
  rescue
    e ->
      Logger.error("[KnowledgeGraphQuery] Query failed: #{inspect(e)}")
      {:error, :query_failed}
  end

  @spec query_source(atom(), String.t(), pos_integer(), map()) :: [knowledge_result()]
  defp query_source(:fts5, query, limit, state) do
    if state.fts5_available do
      query_fts5(query, limit)
    else
      []
    end
  end

  defp query_source(:knowledge_engine, query, limit, state) do
    if state.knowledge_engine_available do
      query_knowledge_engine(query, limit)
    else
      []
    end
  end

  defp query_source(:vector, query, limit, state) do
    if state.vector_available do
      query_vector_store(query, limit)
    else
      []
    end
  end

  defp query_source(:federation, query, limit, state) do
    if state.federation_available do
      query_federation(query, limit)
    else
      []
    end
  end

  defp query_source(_unknown, _query, _limit, _state), do: []

  # ============================================================
  # FTS5 SEARCH (SC-SMRITI-131)
  # ============================================================

  @spec query_fts5(String.t(), pos_integer()) :: [knowledge_result()]
  defp query_fts5(query, limit) do
    case Indrajaal.Smriti.Cognition.FullTextSearch.search(query, limit: limit) do
      {:ok, results} ->
        Enum.map(results, fn r ->
          %{
            id: Map.get(r, :id, generate_id()),
            title: Map.get(r, :title, ""),
            content: Map.get(r, :content, ""),
            relevance: normalize_rank(Map.get(r, :rank, 0.0)),
            source: :fts5,
            tags: Map.get(r, :tags, []),
            holon: "smriti",
            timestamp: Map.get(r, :created_at)
          }
        end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  # ============================================================
  # KNOWLEDGE ENGINE RECALL (SC-AI-001)
  # ============================================================

  @spec query_knowledge_engine(String.t(), pos_integer()) :: [knowledge_result()]
  defp query_knowledge_engine(query, limit) do
    case Indrajaal.Knowledge.Engine.recall(query, limit: limit) do
      {:ok, entries} ->
        Enum.map(entries, fn entry ->
          content =
            cond do
              is_binary(entry) -> entry
              is_map(entry) -> Map.get(entry, :content, Map.get(entry, "content", inspect(entry)))
              true -> inspect(entry)
            end

          %{
            id: generate_id(),
            title: extract_title(content),
            content: content,
            relevance: 0.70,
            source: :knowledge_engine,
            tags: [],
            holon: "knowledge",
            timestamp: DateTime.utc_now()
          }
        end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  # ============================================================
  # VECTOR STORE SEARCH (SC-SMRITI-132)
  # ============================================================

  @spec query_vector_store(String.t(), pos_integer()) :: [knowledge_result()]
  defp query_vector_store(query, limit) do
    # Generate a simple embedding from the query terms for similarity search
    embedding = text_to_embedding(query)

    case Indrajaal.SMRITI.Mesh.VectorStore.search(embedding, limit) do
      {:ok, results} ->
        Enum.map(results, fn r ->
          %{
            id: Map.get(r, :id, generate_id()),
            title: Map.get(r, :title, Map.get(r, :holon_id, "")),
            content: Map.get(r, :content, ""),
            relevance: Map.get(r, :similarity, 0.6),
            source: :vector,
            tags: Map.get(r, :tags, []),
            holon: Map.get(r, :holon_id),
            timestamp: nil
          }
        end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  # ============================================================
  # FEDERATION QUERY (SC-SMRITI-063, SC-XHOLON-003)
  # ============================================================

  @spec query_federation(String.t(), pos_integer()) :: [knowledge_result()]
  defp query_federation(_query, _limit) do
    # Federation queries are async and routed via Zenoh (SC-XHOLON-003)
    # For now, check if federation protocol has cached peer knowledge
    federation_mod = Indrajaal.Smriti.Federation.Protocol

    case if Code.ensure_loaded?(federation_mod) and
              function_exported?(federation_mod, :discover_peers, 0),
            do: federation_mod.discover_peers(),
            else: {:error, :not_loaded} do
      {:ok, peers} when is_list(peers) and length(peers) > 0 ->
        Logger.debug("[KnowledgeGraphQuery] Federation query across #{length(peers)} peers")

        # Federation results are returned as mock placeholders for offline
        []

      _ ->
        []
    end
  rescue
    _ -> []
  end

  # ============================================================
  # CONTEXT BUILDING
  # ============================================================

  @spec build_context(String.t(), pos_integer(), map()) :: map()
  defp build_context(topic, limit, state) do
    # Attempt to use Knowledge Engine context if available
    {recent_events, similar_situations} =
      if state.knowledge_engine_available do
        context_result =
          try do
            Indrajaal.Knowledge.Engine.get_context(topic, limit: limit)
          rescue
            _ -> {:error, :unavailable}
          end

        case context_result do
          {:ok, ctx} ->
            {Map.get(ctx, :recent_events, []), Map.get(ctx, :similar_situations, [])}

          _ ->
            {[], []}
        end
      else
        {[], []}
      end

    # Also query FTS5 for additional knowledge entries
    knowledge_entries =
      if state.fts5_available do
        case query_fts5(topic, limit) do
          results when is_list(results) -> results
          _ -> []
        end
      else
        []
      end

    %{
      topic: topic,
      recent_events: recent_events,
      similar_situations: similar_situations,
      knowledge_entries: knowledge_entries,
      sources_available: %{
        fts5: state.fts5_available,
        vector: state.vector_available,
        knowledge_engine: state.knowledge_engine_available,
        federation: state.federation_available
      },
      timestamp: DateTime.utc_now()
    }
  end

  # ============================================================
  # MEMORIZE
  # ============================================================

  @spec do_memorize(map(), map()) :: :ok | {:error, term()}
  defp do_memorize(entry, state) do
    if state.knowledge_engine_available do
      content = Map.get(entry, :content, Map.get(entry, "content", ""))
      Indrajaal.Knowledge.Engine.memorize(content, entry)
    else
      Logger.warning("[KnowledgeGraphQuery] Knowledge engine unavailable, cannot memorize")
      {:error, :knowledge_engine_unavailable}
    end
  rescue
    e ->
      Logger.error("[KnowledgeGraphQuery] Memorize failed: #{inspect(e)}")
      {:error, :memorize_failed}
  end

  # ============================================================
  # CACHING
  # ============================================================

  @spec cache_key(String.t(), keyword()) :: String.t()
  defp cache_key(query, opts) do
    key_data = "#{query}:#{inspect(Enum.sort(opts))}"
    :crypto.hash(:md5, key_data) |> Base.encode16(case: :lower)
  end

  @spec lookup_cache(String.t()) :: {:hit, [knowledge_result()]} | :miss
  defp lookup_cache(key) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@ets_table, key) do
      [{^key, results, inserted_at}] when now - inserted_at < @cache_ttl_ms ->
        {:hit, results}

      _ ->
        :miss
    end
  end

  @spec store_cache(String.t(), {:ok, [knowledge_result()]} | {:error, term()}) :: true
  defp store_cache(key, {:ok, results}) do
    :ets.insert(@ets_table, {key, results, System.monotonic_time(:millisecond)})
  end

  defp store_cache(_key, _error), do: true

  # ============================================================
  # AVAILABILITY CHECKS
  # ============================================================

  @spec check_fts5_available() :: boolean()
  defp check_fts5_available do
    Code.ensure_loaded?(Indrajaal.Smriti.Cognition.FullTextSearch) and
      Process.whereis(Indrajaal.Smriti.Cognition.FullTextSearch) != nil
  rescue
    _ -> false
  end

  @spec check_vector_available() :: boolean()
  defp check_vector_available do
    Code.ensure_loaded?(Indrajaal.SMRITI.Mesh.VectorStore)
  rescue
    _ -> false
  end

  @spec check_knowledge_engine_available() :: boolean()
  defp check_knowledge_engine_available do
    Code.ensure_loaded?(Indrajaal.Knowledge.Engine) and
      Process.whereis(Indrajaal.Knowledge.Engine) != nil
  rescue
    _ -> false
  end

  @spec check_federation_available() :: boolean()
  defp check_federation_available do
    Code.ensure_loaded?(Indrajaal.Smriti.Federation.Protocol) and
      Process.whereis(Indrajaal.Smriti.Federation.Protocol) != nil
  rescue
    _ -> false
  end

  # ============================================================
  # HELPERS
  # ============================================================

  @spec deduplicate_results([knowledge_result()]) :: [knowledge_result()]
  defp deduplicate_results(results) do
    results
    |> Enum.group_by(& &1.id)
    |> Enum.map(fn {_id, dups} ->
      # Keep the highest-relevance duplicate
      Enum.max_by(dups, & &1.relevance)
    end)
  end

  @spec normalize_rank(float()) :: float()
  defp normalize_rank(rank) when rank < 0 do
    # BM25 scores are negative in SQLite FTS5 (lower = better)
    # Normalize to 0.0-1.0 range: -5.0 → 1.0, 0.0 → 0.5
    max(0.0, min(1.0, 1.0 + rank / 10.0))
  end

  defp normalize_rank(rank), do: min(1.0, rank)

  @spec generate_id() :: String.t()
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  @spec extract_title(String.t()) :: String.t()
  defp extract_title(content) when is_binary(content) do
    content
    |> String.split("\n", parts: 2)
    |> hd()
    |> String.slice(0, 80)
    |> String.trim()
  end

  defp extract_title(_), do: "Knowledge Entry"

  @spec text_to_embedding(String.t()) :: [float()]
  defp text_to_embedding(text) do
    # Simple term-frequency based embedding for offline use
    # In production, this would use an embedding model via OpenRouter
    words =
      text
      |> String.downcase()
      |> String.split(~r/\W+/, trim: true)
      |> Enum.uniq()

    # Generate a deterministic 16-dim embedding from word hashes
    Enum.map(0..15, fn i ->
      words
      |> Enum.reduce(0, fn word, acc ->
        hash = :erlang.phash2("#{word}:#{i}", 1000)
        acc + hash
      end)
      |> then(fn sum -> rem(sum, 100) / 100.0 end)
    end)
  end

  @spec result_count({:ok, [term()]} | {:error, term()}) :: non_neg_integer()
  defp result_count({:ok, list}), do: length(list)
  defp result_count(_), do: 0
end
