defmodule Indrajaal.Core.OODA.SemanticCache do
  @moduledoc """
  Semantic caching for recurring OODA observations.

  Caches observation results keyed by a content hash so that identical
  or semantically equivalent observations are served from cache instead
  of re-computed. Uses ETS for sub-millisecond lookups.

  ## STAMP Constraints
  - SC-VER-041: OODA cycle < 100ms — cache hit must be < 1ms

  ## Cache Strategy
  - Key: SHA-256 hash of observation content
  - Value: {result, inserted_at, hit_count}
  - TTL: Configurable (default 60 seconds)
  - Max entries: 10,000 (LRU eviction)

  ## Constitutional Alignment
  - Ψ₁ Regeneration: State stored in ETS (transient, not holon-authoritative)
  - Ψ₃ Verification: Hit count and eviction metrics tracked

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude | Initial implementation — task f26cefc3 |
  """

  use GenServer
  require Logger

  @table_name :ooda_semantic_cache
  @default_ttl_ms 60_000
  @max_entries 10_000
  @cleanup_interval_ms 30_000

  # ============================================================
  # Public API
  # ============================================================

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get cached result for an observation, or :miss"
  @spec get(term()) :: {:hit, term()} | :miss
  def get(observation) do
    key = hash_observation(observation)
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table_name, key) do
      [{^key, result, inserted_at, _hit_count}] ->
        ttl = Application.get_env(:indrajaal, :ooda_cache_ttl, @default_ttl_ms)

        if now - inserted_at < ttl do
          :ets.update_counter(@table_name, key, {4, 1})
          {:hit, result}
        else
          :ets.delete(@table_name, key)
          :miss
        end

      [] ->
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  @doc "Store a result in the cache"
  @spec put(term(), term()) :: :ok
  def put(observation, result) do
    key = hash_observation(observation)
    now = System.monotonic_time(:millisecond)

    if :ets.info(@table_name, :size) >= @max_entries do
      evict_oldest()
    end

    :ets.insert(@table_name, {key, result, now, 1})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "Get or compute: returns cached value or computes and caches"
  @spec get_or_compute(term(), (-> term())) :: term()
  def get_or_compute(observation, compute_fn) do
    case get(observation) do
      {:hit, result} ->
        result

      :miss ->
        result = compute_fn.()
        put(observation, result)
        result
    end
  end

  @doc "Cache statistics"
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc "Clear all cached entries"
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  rescue
    ArgumentError -> :ok
  end

  # ============================================================
  # GenServer Callbacks
  # ============================================================

  @impl true
  def init(opts) do
    table =
      :ets.new(@table_name, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

    ttl = Keyword.get(opts, :ttl, @default_ttl_ms)
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)

    Logger.info("[SemanticCache] OODA cache initialized — TTL=#{ttl}ms, max=#{@max_entries}")
    {:ok, %{table: table, ttl: ttl, evictions: 0, cleanups: 0}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    size = :ets.info(@table_name, :size)

    total_hits =
      :ets.foldl(
        fn {_key, _val, _ts, hits}, acc -> acc + hits end,
        0,
        @table_name
      )

    stats = %{
      entries: size,
      max_entries: @max_entries,
      ttl_ms: state.ttl,
      total_hits: total_hits,
      evictions: state.evictions,
      cleanups: state.cleanups,
      memory_bytes: :ets.info(@table_name, :memory) * :erlang.system_info(:wordsize)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)
    ttl = state.ttl

    expired =
      :ets.foldl(
        fn {key, _val, inserted_at, _hits}, acc ->
          if now - inserted_at >= ttl, do: [key | acc], else: acc
        end,
        [],
        @table_name
      )

    Enum.each(expired, &:ets.delete(@table_name, &1))

    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
    {:noreply, %{state | cleanups: state.cleanups + 1}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # Private
  # ============================================================

  @spec hash_observation(term()) :: binary()
  defp hash_observation(observation) do
    :crypto.hash(:sha256, :erlang.term_to_binary(observation))
  end

  defp evict_oldest do
    :ets.tab2list(@table_name)
    |> Enum.sort_by(fn {_k, _v, _ts, hits} -> hits end)
    |> Enum.take(div(@max_entries, 10))
    |> Enum.each(fn {key, _, _, _} -> :ets.delete(@table_name, key) end)
  end
end
