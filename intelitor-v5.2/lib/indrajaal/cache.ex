defmodule Indrajaal.Cache do
  @moduledoc """

  Multi-tier caching infrastructure for Indrajaal Mobile API.

  Provides a unified interface for:
  - Application
  - level caching (Cachex)
  - Distributed caching (Redis)
  - Query result caching-Cache warming and invalidation

  Performance targets:
  - Cache operations: < 1ms
  - Hit rate: > 90%
  - Memory efficient

  Agent: Helper-3 optimizes caching
  SOPv5.1 Compliance: ✅
  """

  use GenServer
  require Logger

  alias Indrajaal.Cache.{KeyGenerator, Warmer}

  @default_ttl :timer.minutes(5)
  @max_cache_size 100_000

  # Cache names
  @session_cache :indrajaal_sessions
  @entity_cache :indrajaal_entities
  @query_cache :indrajaal_queries
  @api_cache :indrajaal_api_responses

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Get value from cache with automatic tier fallback.

  Lookup order:
  1. Application cache (Cachex)
  2. Distributed cache (Redis)
  3. Source function (if provided)
  """
  @spec get(atom(), any(), keyword()) :: {:ok, any()} | {:error, any()}
  def get(cache, key, opts \\ []) do
    with {:error, :not_found} <- get_local(cache, key),
         {:error, :not_found} <- get_distributed(cache, key),
         source_fn when is_function(source_fn) <- Keyword.get(opts, :source) do
      # Cache miss-fetch from source
      case source_fn.() do
        {:ok, value} ->
          ttl = Keyword.get(opts, :ttl, @default_ttl)
          put(cache, key, value, ttl: ttl)
          {:ok, value}

        error ->
          error
      end
    else
      {:ok, value} -> {:ok, value}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Put value into cache tiers based on configuration.
  """
  @spec put(atom(), any(), any(), keyword()) :: :ok
  def put(cache, key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)

    # Always put in local cache
    put_local(cache, key, value, ttl)

    # Put in distributed cache if configured
    if Keyword.get(opts, :distributed, true) do
      put_distributed(cache, key, value, ttl)
    end

    :ok
  end

  @doc """
  Delete value from all cache tiers.
  """
  @spec delete(atom(), any()) :: :ok
  def delete(cache, key) do
    delete_local(cache, key)
    delete_distributed(cache, key)
    :ok
  end

  @doc """
  Clear entire cache or by pattern.
  """
  @spec clear(atom(), keyword()) :: :ok
  def clear(cache, opts \\ []) do
    case Keyword.get(opts, :pattern) do
      nil ->
        Cachex.clear(cache)
        clear_distributed(cache)

      pattern ->
        clear_by_pattern(cache, pattern)
    end

    :ok
  end

  @doc """
  Get cache statistics.
  """
  @spec stats(atom()) :: map()
  def stats(cache) do
    stats_result = Cachex.stats(cache)
    local_stats = elem(stats_result, 1)
    distributed_stats = get_distributed_stats(cache)

    size_result = Cachex.size(cache)

    %{
      local: %{
        hits: local_stats[:hits] || 0,
        misses: local_stats[:misses] || 0,
        writes: local_stats[:writes] || 0,
        evictions: local_stats[:evictions] || 0,
        size: elem(size_result, 1)
      },
      distributed: distributed_stats,
      hit_rate: calculate_hit_rate(local_stats)
    }
  end

  # ============================================================================
  # Cache-specific convenience functions
  # ============================================================================

  @doc """
  Cache user session data.
  """
  @spec cache_session(term(), term(), term()) :: term()
  def cache_session(user_id, session_data, ttl \\ :timer.hours(1)) do
    key = KeyGenerator.session_key(user_id)
    put(@session_cache, key, session_data, ttl: ttl)
  end

  @doc """
  Get cached session data.
  """
  @spec get_session(any()) :: any()
  def get_session(user_id) do
    key = KeyGenerator.session_key(user_id)
    get(@session_cache, key)
  end

  @doc """
  Cache entity (device, alarm, site, etc).
  """
  @spec cache_entity(term(), term(), term(), term()) :: term()
  def cache_entity(type, id, entity, ttl \\ :timer.minutes(10)) do
    key = KeyGenerator.entity_key(type, id)
    put(@entity_cache, key, entity, ttl: ttl)
  end

  @doc """
  Get cached entity.
  """
  @spec get_entity(term(), term(), term()) :: term()
  def get_entity(type, id, source_fn \\ nil) do
    key = KeyGenerator.entity_key(type, id)
    get(@entity_cache, key, source: source_fn)
  end

  @doc """
  Cache query results.
  """
  @spec cache_query(term(), term(), term()) :: term()
  def cache_query(query_hash, results, ttl \\ :timer.minutes(5)) do
    key = KeyGenerator.query_key(query_hash)
    put(@query_cache, key, results, ttl: ttl)
  end

  @doc """
  Get cached query results.
  """
  @spec get_query(any()) :: any()
  def get_query(query_hash) do
    key = KeyGenerator.query_key(query_hash)
    get(@query_cache, key)
  end

  @doc """
  Cache API response.
  """
  @spec cache_api_response(term(), term(), term(), term()) :: term()
  def cache_api_response(endpoint, params, response, ttl \\ :timer.minutes(1)) do
    key = KeyGenerator.api_key(endpoint, params)
    put(@api_cache, key, response, ttl: ttl)
  end

  @doc """
  Get cached API response.
  """
  @spec get_api_response(any(), any()) :: any()
  def get_api_response(endpoint, params) do
    key = KeyGenerator.api_key(endpoint, params)
    get(@api_cache, key)
  end

  @doc """
  Invalidate related caches when entity changes.
  """
  @spec invalidate_entity(any(), any()) :: any()
  def invalidate_entity(type, id) do
    # Clear specific entity
    entity_key = KeyGenerator.entity_key(type, id)
    delete(@entity_cache, entity_key)

    # Clear related queries
    pattern = "query:*#{type}*#{id}*"
    clear(@query_cache, pattern: pattern)

    # Clear related API responses
    pattern = "api:*/#{type}s/#{id}*"
    clear(@api_cache, pattern: pattern)

    Logger.debug("Invalidated caches for #{type} #{id}")
  end

  # ============================================================================
  # GenServer Implementation
  # ============================================================================

  @spec start_link(any()) :: any()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  @spec init(any()) :: any()
  def init(_opts) do
    # Initialize cache stores
    caches = [
      {@session_cache, [limit: 50_000, ttl: :timer.hours(1)]},
      {@entity_cache, [limit: @max_cache_size, ttl: :timer.minutes(10)]},
      {@query_cache, [limit: 10_000, ttl: :timer.minutes(5)]},
      {@api_cache, [limit: 20_000, ttl: :timer.minutes(1)]}
    ]

    Enum.each(caches, fn {name, opts} ->
      Cachex.start_link(name, opts)
    end)

    # Start cache warmer
    Warmer.start_link()

    # Schedule stats reporting
    schedule_stats_report()

    {:ok, %{}}
  end

  @impl true
  @spec handle_info(any(), any()) :: any()
  def handle_info(:log_stats, state) do
    # Log cache statistics
    Enum.each([@session_cache, @entity_cache, @query_cache, @api_cache], fn cache ->
      stats = stats(cache)
      Logger.info("Cache #{cache} stats: #{inspect(stats)}")

      # Emit telemetry metrics
      :telemetry.execute(
        [:indrajaal, :cache, :stats],
        %{
          hit_rate: stats.hit_rate,
          size: stats.local.size,
          hits: stats.local.hits,
          misses: stats.local.misses
        },
        %{cache: cache}
      )
    end)

    schedule_stats_report()
    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  @spec get_local(term(), term()) :: term()
  defp get_local(cache, key) do
    case Cachex.get(cache, key) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, value} -> {:ok, value}
      _ -> {:error, :not_found}
    end
  end

  @spec get_distributed(term(), term()) :: term()
  defp get_distributed(cache, key) do
    # Redis implementation
    case Redix.command(:redix, ["GET", "#{cache}:#{key}"]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, value} -> {:ok, :erlang.binary_to_term(value)}
      _ -> {:error, :not_found}
    end
  end

  defp put_local(cache, key, value, ttl) do
    Cachex.put(cache, key, value, ttl: ttl)
  end

  defp put_distributed(cache, key, value, ttl) do
    ttl_seconds = div(ttl, 1000)
    value_binary = :erlang.term_to_binary(value)

    Redix.command(
      :redix,
      ["SETEX", "#{cache}:#{key}", ttl_seconds, value_binary]
    )
  end

  @spec delete_local(term(), term()) :: term()
  defp delete_local(cache, key) do
    Cachex.del(cache, key)
  end

  @spec delete_distributed(term(), term()) :: term()
  defp delete_distributed(cache, key) do
    Redix.command(:redix, ["DEL", "#{cache}:#{key}"])
  end

  @spec clear_distributed(term()) :: term()
  defp clear_distributed(cache) do
    # Clear all keys with cache prefix
    case Redix.command(:redix, ["KEYS", "#{cache}:*"]) do
      {:ok, keys} when keys != [] ->
        Redix.command(:redix, ["DEL" | keys])

      _ ->
        :ok
    end
  end

  @spec clear_by_pattern(term(), term()) :: term()
  defp clear_by_pattern(cache, pattern) do
    # Clear local cache by pattern
    cache_stream = Cachex.stream(cache)

    cache_stream
    |> Stream.filter(fn {key, _} -> match_pattern?(key, pattern) end)
    |> Stream.each(fn {key, _} -> Cachex.del(cache, key) end)
    |> Stream.run()

    # Clear distributed cache by pattern
    redis_pattern = "#{cache}:#{pattern}"

    case Redix.command(:redix, ["KEYS", redis_pattern]) do
      {:ok, keys} when keys != [] ->
        Redix.command(:redix, ["DEL" | keys])

      _ ->
        :ok
    end
  end

  @spec match_pattern?(term(), term()) :: term()
  defp match_pattern?(key, pattern) do
    # Convert glob pattern to regex
    regex_pattern =
      pattern
      |> String.replace("*", ".*")
      |> String.replace("?", ".")
      |> Regex.compile!()

    Regex.match?(regex_pattern, to_string(key))
  end

  @spec get_distributed_stats(term()) :: term()
  defp get_distributed_stats(cache) do
    case Redix.command(:redix, ["INFO", "stats"]) do
      {:ok, info} ->
        # Parse Redis INFO stats
        %{
          connected: true,
          keys: count_redis_keys(cache),
          memory: parse_redis_memory(info)
        }

      _ ->
        %{connected: false, keys: 0, memory: 0}
    end
  end

  @spec count_redis_keys(term()) :: term()
  defp count_redis_keys(cache) do
    case Redix.command(:redix, ["KEYS", "#{cache}:*"]) do
      {:ok, keys} -> length(keys)
      _ -> 0
    end
  end

  @spec parse_redis_memory(term()) :: term()
  defp parse_redis_memory(info) do
    # Extract used_memory from Redis INFO
    case Regex.run(~r/used_memory:(\d+)/, info) do
      [_, memory] -> String.to_integer(memory)
      _ -> 0
    end
  end

  @spec calculate_hit_rate(term()) :: term()
  defp calculate_hit_rate(stats) do
    hits = stats[:hits] || 0
    misses = stats[:misses] || 0
    total = hits + misses

    if total > 0 do
      Float.round(hits / total * 100, 2)
    else
      0.0
    end
  end

  @spec schedule_stats_report() :: any()
  defp schedule_stats_report do
    Process.send_after(self(), :report_stats, :timer.minutes(5))
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
