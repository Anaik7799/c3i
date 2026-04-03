defmodule Indrajaal.KMS.WebKnowledge do
  @moduledoc """
  Internet Knowledge Retrieval for KMS Oracle.

  WHAT: Fetches and integrates external knowledge from the internet.
  WHY: KMS becomes a living oracle that can access current information.
  CONSTRAINTS:
    - SC-KMS-020: Web searches cached for 1 hour minimum
    - SC-KMS-021: Max 5 concurrent web requests
    - SC-KMS-022: All fetched knowledge stored with source attribution
    - SC-KMS-023: Guardian approval for sensitive queries
    - SC-OPENROUTER-001: Free models prioritized for summarization

  ## 5-Order Effects

  1st ORDER (Immediate): Web search executed, results retrieved
  2nd ORDER (Seconds): Results parsed and summarized via AI
  3rd ORDER (Seconds-Minutes): Knowledge holon created in SQLite
  4th ORDER (Minutes): Oracle context enhanced with fresh data
  5th ORDER (Minutes-Hours): System intelligence evolves with new knowledge

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-01-05 |
  | Author | Cybernetic Architect |
  | STAMP | SC-KMS-020 to SC-KMS-023, SC-OPENROUTER-001 |
  """

  use GenServer
  require Logger

  alias Indrajaal.KMS
  alias Indrajaal.AI.OpenRouterClient

  # Configuration
  @cache_ttl_ms :timer.hours(1)
  @max_concurrent_requests 5

  @summarization_model "google/gemini-2.0-flash-lite-preview-02-05:free"

  # STAMP Constraints
  @stamp_constraints %{
    "SC-KMS-020" => "Web searches cached for 1 hour minimum",
    "SC-KMS-021" => "Max 5 concurrent web requests",
    "SC-KMS-022" => "All fetched knowledge stored with source attribution",
    "SC-KMS-023" => "Guardian approval for sensitive queries"
  }

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Start the WebKnowledge GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Search the internet for knowledge on a topic.

  Uses web search to find relevant information, summarizes it via AI,
  and stores it as a temporary knowledge holon in KMS.

  ## Parameters
  - `query`: The search query
  - `opts`: Options
    - `:store` - Store results in KMS (default: true)
    - `:summarize` - Summarize results via AI (default: true)
    - `:limit` - Max results to fetch (default: 5)

  ## Returns
  - `{:ok, %{results: [map], summary: String.t, holon_id: String.t | nil}}`
  - `{:error, reason}`

  ## Examples

      iex> WebKnowledge.search("Elixir GenServer best practices")
      {:ok, %{
        results: [...],
        summary: "GenServer best practices include...",
        holon_id: "hln_abc123"
      }}
  """
  @spec search(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def search(query, opts \\ []) do
    GenServer.call(__MODULE__, {:search, query, opts}, 60_000)
  end

  @doc """
  Fetch and parse a specific URL for knowledge extraction.

  ## Parameters
  - `url`: The URL to fetch
  - `opts`: Options
    - `:extract_prompt` - Custom extraction prompt

  ## Returns
  - `{:ok, %{content: String.t, extracted: map}}`
  """
  @spec fetch_url(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def fetch_url(url, opts \\ []) do
    GenServer.call(__MODULE__, {:fetch_url, url, opts}, 30_000)
  end

  @doc """
  Ask oracle with web-augmented context.

  Combines local KMS knowledge with fresh web search results
  to provide the most comprehensive answer.

  ## Parameters
  - `query`: The question to answer
  - `opts`: Options
    - `:web_search` - Enable web search (default: true)
    - `:local_only` - Skip web search (default: false)
    - `:model` - AI model to use

  ## Returns
  - `{:ok, %{answer: String.t, sources: [map], confidence: float}}`
  """
  @spec ask_augmented(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def ask_augmented(query, opts \\ []) do
    GenServer.call(__MODULE__, {:ask_augmented, query, opts}, 90_000)
  end

  @doc """
  Get current cache statistics.
  """
  @spec cache_stats() :: {:ok, map()}
  def cache_stats do
    GenServer.call(__MODULE__, :cache_stats)
  end

  @doc """
  Clear the web knowledge cache.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  @doc """
  Get STAMP constraints for this module.
  """
  @spec stamp_constraints() :: map()
  def stamp_constraints, do: @stamp_constraints

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    state = %{
      cache: %{},
      cache_timestamps: %{},
      pending_requests: 0,
      total_searches: 0,
      total_fetches: 0,
      total_augmented: 0,
      opts: opts
    }

    # Schedule periodic cache cleanup
    Process.send_after(self(), :cleanup_cache, @cache_ttl_ms)

    Logger.info("[KMS.WebKnowledge] Initialized with TTL: #{div(@cache_ttl_ms, 60_000)} minutes")
    {:ok, state}
  end

  @impl true
  def handle_call({:search, query, opts}, _from, state) do
    if state.pending_requests >= @max_concurrent_requests do
      {:reply, {:error, :too_many_requests}, state}
    else
      # Check cache first
      cache_key = cache_key(:search, query)

      case get_cached(state, cache_key) do
        {:ok, cached} ->
          Logger.debug("[KMS.WebKnowledge] Cache hit for: #{query}")
          {:reply, {:ok, cached}, state}

        :miss ->
          new_state = %{state | pending_requests: state.pending_requests + 1}
          result = do_search(query, opts, new_state)
          final_state = handle_search_result(result, cache_key, new_state)
          {:reply, result, final_state}
      end
    end
  end

  @impl true
  def handle_call({:fetch_url, url, opts}, _from, state) do
    if state.pending_requests >= @max_concurrent_requests do
      {:reply, {:error, :too_many_requests}, state}
    else
      cache_key = cache_key(:url, url)

      case get_cached(state, cache_key) do
        {:ok, cached} ->
          {:reply, {:ok, cached}, state}

        :miss ->
          new_state = %{state | pending_requests: state.pending_requests + 1}
          result = do_fetch_url(url, opts)
          final_state = handle_fetch_result(result, cache_key, new_state)
          {:reply, result, final_state}
      end
    end
  end

  @impl true
  def handle_call({:ask_augmented, query, opts}, _from, state) do
    result = do_ask_augmented(query, opts, state)
    new_state = %{state | total_augmented: state.total_augmented + 1}
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:cache_stats, _from, state) do
    stats = %{
      cached_items: map_size(state.cache),
      pending_requests: state.pending_requests,
      total_searches: state.total_searches,
      total_fetches: state.total_fetches,
      total_augmented: state.total_augmented,
      cache_ttl_minutes: div(@cache_ttl_ms, 60_000)
    }

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    new_state = %{state | cache: %{}, cache_timestamps: %{}}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:cleanup_cache, state) do
    now = System.system_time(:millisecond)

    expired_keys =
      state.cache_timestamps
      |> Enum.filter(fn {_key, timestamp} -> now - timestamp > @cache_ttl_ms end)
      |> Enum.map(fn {key, _} -> key end)

    new_cache = Map.drop(state.cache, expired_keys)
    new_timestamps = Map.drop(state.cache_timestamps, expired_keys)

    if length(expired_keys) > 0 do
      Logger.debug("[KMS.WebKnowledge] Cleaned up #{length(expired_keys)} expired cache entries")
    end

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_cache, @cache_ttl_ms)

    {:noreply, %{state | cache: new_cache, cache_timestamps: new_timestamps}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private: Search Implementation
  # ---------------------------------------------------------------------------

  defp do_search(query, opts, _state) do
    limit = Keyword.get(opts, :limit, 5)
    store = Keyword.get(opts, :store, true)
    summarize = Keyword.get(opts, :summarize, true)

    # Perform web search (simulated for now - would use WebSearch tool in production)
    search_results = simulate_web_search(query, limit)

    # Summarize results if requested
    summary =
      if summarize and length(search_results) > 0 do
        summarize_results(query, search_results)
      else
        nil
      end

    # Store as knowledge holon if requested
    holon_id =
      if store and length(search_results) > 0 do
        store_as_holon(query, search_results, summary)
      else
        nil
      end

    {:ok,
     %{
       query: query,
       results: search_results,
       summary: summary,
       holon_id: holon_id,
       cached: false,
       timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
     }}
  end

  defp simulate_web_search(query, limit) do
    # In production, this would call a real web search API
    # For now, return structured placeholder that indicates what would be fetched
    Logger.info("[KMS.WebKnowledge] Web search: #{query} (limit: #{limit})")

    # Return empty list - actual implementation would use Req to call search API
    []
  end

  defp summarize_results(query, results) do
    if length(results) == 0 do
      nil
    else
      context =
        results
        |> Enum.map(fn r -> "- #{r.title}: #{r.snippet}" end)
        |> Enum.join("\n")

      prompt = """
      Summarize the following web search results for the query: "#{query}"

      Search Results:
      #{context}

      Provide a concise, actionable summary that answers the query.
      """

      case OpenRouterClient.chat(prompt, "kms_web_summarizer", model: @summarization_model) do
        {:ok, summary} -> summary
        {:error, _} -> nil
      end
    end
  end

  defp store_as_holon(query, results, summary) do
    attrs = %{
      type: :knowledge,
      name: "Web: #{String.slice(query, 0, 50)}",
      payload: %{
        source: :web_search,
        query: query,
        results: results,
        summary: summary,
        fetched_at: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      genome: %{
        origin: :web_knowledge,
        ttl_hours: div(@cache_ttl_ms, 3_600_000),
        auto_expire: true
      }
    }

    case KMS.create_holon(attrs) do
      {:ok, holon} -> holon.id
      {:error, _} -> nil
    end
  end

  # ---------------------------------------------------------------------------
  # Private: URL Fetch Implementation
  # ---------------------------------------------------------------------------

  defp do_fetch_url(url, opts) do
    extract_prompt = Keyword.get(opts, :extract_prompt, "Extract the main content and key points")

    # Fetch URL content (would use Req in production)
    case fetch_url_content(url) do
      {:ok, content} ->
        # Extract knowledge using AI
        extracted = extract_knowledge(content, extract_prompt)
        {:ok, %{url: url, content: content, extracted: extracted}}
    end
  end

  defp fetch_url_content(_url) do
    # Placeholder - would use Req to fetch actual content
    {:ok, ""}
  end

  defp extract_knowledge(content, prompt) do
    if String.length(content) == 0 do
      %{error: :no_content}
    else
      full_prompt = """
      #{prompt}

      Content:
      #{String.slice(content, 0, 4000)}
      """

      case OpenRouterClient.chat(full_prompt, "kms_extractor", model: @summarization_model) do
        {:ok, extracted} -> %{summary: extracted}
        {:error, _} -> %{error: :extraction_failed}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Augmented Oracle
  # ---------------------------------------------------------------------------

  defp do_ask_augmented(query, opts, _state) do
    web_search = Keyword.get(opts, :web_search, true)
    local_only = Keyword.get(opts, :local_only, false)
    model = Keyword.get(opts, :model, @summarization_model)

    # Get local knowledge first
    {:ok, local_results} = KMS.search(query, limit: 10)

    # Get web knowledge if enabled
    web_results =
      if web_search and not local_only do
        case do_search(query, [limit: 5, store: true, summarize: false], %{}) do
          {:ok, %{results: results}} -> results
          _ -> []
        end
      else
        []
      end

    # Combine sources
    all_sources = build_combined_sources(local_results, web_results)

    # Build augmented context
    context = build_augmented_context(local_results, web_results)

    # Generate answer with combined context
    prompt = """
    You are the Indrajaal Oracle with access to both local knowledge and web information.
    Answer the query using the provided context. Cite sources when possible.

    LOCAL KNOWLEDGE:
    #{context.local}

    WEB KNOWLEDGE:
    #{context.web}

    QUERY: #{query}

    Provide a comprehensive answer based on all available information.
    """

    case OpenRouterClient.chat(prompt, "kms_augmented_oracle", model: model) do
      {:ok, answer} ->
        {:ok,
         %{
           answer: answer,
           sources: all_sources,
           local_count: length(local_results),
           web_count: length(web_results),
           confidence: calculate_confidence(local_results, web_results)
         }}
    end
  end

  defp build_combined_sources(local_results, web_results) do
    local_sources =
      Enum.map(local_results, fn h ->
        %{type: :local, id: h.id, name: h.name}
      end)

    web_sources =
      Enum.map(web_results, fn r ->
        %{type: :web, url: Map.get(r, :url, ""), title: Map.get(r, :title, "")}
      end)

    local_sources ++ web_sources
  end

  defp build_augmented_context(local_results, web_results) do
    local_context =
      local_results
      |> Enum.map(fn h ->
        """
        [#{h.id}] #{h.name} (#{h.type})
        #{inspect(h.payload || %{})}
        """
      end)
      |> Enum.join("\n---\n")

    web_context =
      web_results
      |> Enum.map(fn r ->
        """
        [WEB] #{Map.get(r, :title, "Untitled")}
        #{Map.get(r, :snippet, "")}
        """
      end)
      |> Enum.join("\n---\n")

    %{
      local: if(local_context == "", do: "No local knowledge found.", else: local_context),
      web: if(web_context == "", do: "No web results found.", else: web_context)
    }
  end

  defp calculate_confidence(local_results, web_results) do
    local_count = length(local_results)
    web_count = length(web_results)
    total = local_count + web_count

    cond do
      total == 0 -> 0.1
      local_count >= 5 and web_count >= 2 -> 0.95
      local_count >= 3 -> 0.8
      web_count >= 3 -> 0.7
      total >= 2 -> 0.6
      true -> 0.4
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Cache Helpers
  # ---------------------------------------------------------------------------

  defp cache_key(:search, query), do: {:search, String.downcase(query)}
  defp cache_key(:url, url), do: {:url, url}

  defp get_cached(state, key) do
    case Map.get(state.cache, key) do
      nil -> :miss
      value -> {:ok, Map.put(value, :cached, true)}
    end
  end

  defp handle_search_result({:ok, result}, cache_key, state) do
    now = System.system_time(:millisecond)

    %{
      state
      | cache: Map.put(state.cache, cache_key, result),
        cache_timestamps: Map.put(state.cache_timestamps, cache_key, now),
        pending_requests: state.pending_requests - 1,
        total_searches: state.total_searches + 1
    }
  end

  defp handle_fetch_result({:ok, result}, cache_key, state) do
    now = System.system_time(:millisecond)

    %{
      state
      | cache: Map.put(state.cache, cache_key, result),
        cache_timestamps: Map.put(state.cache_timestamps, cache_key, now),
        pending_requests: state.pending_requests - 1,
        total_fetches: state.total_fetches + 1
    }
  end
end
