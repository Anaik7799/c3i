defmodule Indrajaal.Integration.CepafClient do
  @moduledoc """
  High-level facade for Cepaf.Podman operations with caching and telemetry.

  This module provides a clean, idiomatic Elixir API for container operations,
  abstracting the underlying Port-based communication with the F# CLI.

  ## Features

  - **Caching**: Frequently accessed data (container lists, health status) is cached
    with configurable TTL to reduce CLI invocations
  - **Telemetry**: All operations emit telemetry events for observability
  - **Error Handling**: Consistent error handling with detailed error types
  - **Retry Logic**: Automatic retry for transient failures

  ## Architecture

  ```
  CepafClient (Facade)
       |
       +-- CepafPort (GenServer/Port)
       |        |
       |        +-- F# CLI (Cepaf.Podman)
       |                 |
       |                 +-- Podman Unix Socket
       |
       +-- ETS Cache (container_cache)
  ```

  ## STAMP Safety Constraints

  - SC-CNT-009: All operations route through NixOS/Podman
  - SC-OBS-069: Dual logging via telemetry integration
  - SC-PRF-050: Response time < 50ms (cached), < 500ms (uncached)

  ## Usage

      # Get all running containers
      containers = CepafClient.list_running_containers()

      # Get container by name with caching
      {:ok, container} = CepafClient.get_container("indrajaal-db")

      # Check overall system health
      {:ok, summary} = CepafClient.health_summary()

      # Force cache refresh
      CepafClient.invalidate_cache()
  """

  use GenServer
  require Logger

  alias Indrajaal.Integration.CepafPort

  # Cache configuration
  @cache_table :cepaf_container_cache
  @default_cache_ttl :timer.seconds(30)
  @health_cache_ttl :timer.seconds(10)
  @list_cache_ttl :timer.seconds(15)

  # Retry configuration
  @max_retries 3
  @retry_backoff_base 100

  defstruct [
    :cache_table,
    :cache_ttl,
    :last_refresh,
    :refresh_interval
  ]

  @type container :: %{
          id: String.t(),
          name: String.t(),
          image: String.t(),
          status: atom(),
          health: atom() | nil,
          created: DateTime.t() | nil,
          ports: [map()],
          labels: map()
        }

  @type health_summary :: %{
          total: non_neg_integer(),
          healthy: non_neg_integer(),
          unhealthy: non_neg_integer(),
          starting: non_neg_integer(),
          timestamp: DateTime.t()
        }

  @type error_reason ::
          :not_found
          | :timeout
          | :connection_refused
          | :podman_unavailable
          | {:command_failed, integer(), String.t()}
          | {:parse_error, term()}

  # ============================================================================
  # Client API - Container Operations
  # ============================================================================

  @doc """
  Starts the CepafClient GenServer.

  ## Options

  - `:cache_ttl` - Default cache TTL in milliseconds (default: 30_000)
  - `:refresh_interval` - Background refresh interval (default: 60_000)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Lists all containers (running and stopped).

  Results are cached for `@list_cache_ttl` milliseconds.

  ## Options

  - `:force_refresh` - Bypass cache and fetch fresh data
  - `:labels` - Filter by labels

  ## Examples

      {:ok, containers} = CepafClient.list_containers()
      {:ok, containers} = CepafClient.list_containers(force_refresh: true)
  """
  @spec list_containers(keyword()) :: {:ok, [container()]} | {:error, error_reason()}
  def list_containers(opts \\ []) do
    cache_key = {:containers, :all, Keyword.get(opts, :labels, [])}
    force_refresh = Keyword.get(opts, :force_refresh, false)

    with_cache(cache_key, @list_cache_ttl, force_refresh, fn ->
      with_telemetry(:list_containers, %{all: true}, fn ->
        with_retry(fn ->
          CepafPort.list_containers(opts)
        end)
      end)
    end)
  end

  @doc """
  Lists only running containers.

  ## Examples

      {:ok, running} = CepafClient.list_running_containers()
  """
  @spec list_running_containers(keyword()) :: {:ok, [container()]} | {:error, error_reason()}
  def list_running_containers(opts \\ []) do
    cache_key = {:containers, :running, Keyword.get(opts, :labels, [])}
    force_refresh = Keyword.get(opts, :force_refresh, false)

    with_cache(cache_key, @list_cache_ttl, force_refresh, fn ->
      with_telemetry(:list_containers, %{running_only: true}, fn ->
        with_retry(fn ->
          CepafPort.list_containers(Keyword.put(opts, :running_only, true))
        end)
      end)
    end)
  end

  @doc """
  Gets a specific container by ID or name.

  Results are cached for `@default_cache_ttl` milliseconds.

  ## Examples

      {:ok, container} = CepafClient.get_container("indrajaal-db")
      {:error, :not_found} = CepafClient.get_container("nonexistent")
  """
  @spec get_container(String.t(), keyword()) :: {:ok, container()} | {:error, error_reason()}
  def get_container(id_or_name, opts \\ []) do
    cache_key = {:container, id_or_name}
    force_refresh = Keyword.get(opts, :force_refresh, false)

    with_cache(cache_key, @default_cache_ttl, force_refresh, fn ->
      with_telemetry(:get_container, %{id: id_or_name}, fn ->
        with_retry(fn ->
          get_container_from_port(id_or_name, opts)
        end)
      end)
    end)
  end

  defp get_container_from_port(id_or_name, opts) do
    case CepafPort.inspect_container(id_or_name, opts) do
      {:ok, info} -> {:ok, normalize_container(info)}
      {:error, {:command_failed, 125, _}} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Checks if a container exists.

  ## Examples

      true = CepafClient.container_exists?("indrajaal-db")
      false = CepafClient.container_exists?("nonexistent")
  """
  @spec container_exists?(String.t()) :: boolean()
  def container_exists?(id_or_name) do
    case get_container(id_or_name) do
      {:ok, _} -> true
      {:error, :not_found} -> false
      _ -> false
    end
  end

  @doc """
  Checks if a container is running.

  ## Examples

      true = CepafClient.container_running?("indrajaal-db")
  """
  @spec container_running?(String.t()) :: boolean()
  def container_running?(id_or_name) do
    case get_container(id_or_name) do
      {:ok, %{status: :running}} -> true
      _ -> false
    end
  end

  @doc """
  Restarts a container.

  ## Examples

      :ok = CepafClient.restart_container("indrajaal-db")
  """
  @spec restart_container(String.t()) :: :ok | {:error, error_reason()}
  def restart_container(id_or_name) do
    with_telemetry(:restart_container, %{id: id_or_name}, fn ->
      with_retry(fn ->
        case CepafPort.restart_container(id_or_name) do
          :ok ->
            invalidate_container(id_or_name)
            :ok

          error ->
            error
        end
      end)
    end)
  end

  # ============================================================================
  # Client API - Health Operations
  # ============================================================================

  @doc """
  Gets health summary for all containers.

  Results are cached for `@health_cache_ttl` milliseconds.

  ## Examples

      {:ok, summary} = CepafClient.health_summary()
      # => %{total: 5, healthy: 4, unhealthy: 1, ...}
  """
  @spec health_summary(keyword()) :: {:ok, health_summary()} | {:error, error_reason()}
  def health_summary(opts \\ []) do
    cache_key = {:health, :summary}
    force_refresh = Keyword.get(opts, :force_refresh, false)

    with_cache(cache_key, @health_cache_ttl, force_refresh, fn ->
      with_telemetry(:health_summary, %{}, fn ->
        with_retry(fn ->
          CepafPort.check_health(opts)
        end)
      end)
    end)
  end

  @doc """
  Gets health status of a specific container.

  ## Examples

      {:ok, :healthy} = CepafClient.container_health("indrajaal-db")
      {:ok, :unhealthy} = CepafClient.container_health("failing-service")
  """
  @spec container_health(String.t(), keyword()) ::
          {:ok, atom()} | {:error, error_reason()}
  def container_health(id_or_name, opts \\ []) do
    cache_key = {:health, id_or_name}
    force_refresh = Keyword.get(opts, :force_refresh, false)

    with_cache(cache_key, @health_cache_ttl, force_refresh, fn ->
      with_telemetry(:container_health, %{id: id_or_name}, fn ->
        with_retry(fn ->
          CepafPort.container_health(id_or_name, opts)
        end)
      end)
    end)
  end

  @doc """
  Checks if a container is healthy.

  ## Examples

      true = CepafClient.container_healthy?("indrajaal-db")
  """
  @spec container_healthy?(String.t()) :: boolean()
  def container_healthy?(id_or_name) do
    case container_health(id_or_name) do
      {:ok, :healthy} -> true
      _ -> false
    end
  end

  @doc """
  Checks if all expected Indrajaal containers are healthy.

  ## Examples

      true = CepafClient.all_healthy?()
  """
  @spec all_healthy?() :: boolean()
  def all_healthy? do
    case health_summary() do
      {:ok, %{unhealthy: 0, starting: 0}} -> true
      _ -> false
    end
  end

  @doc """
  Gets list of unhealthy containers.

  ## Examples

      {:ok, [%{name: "failing-container", ...}]} = CepafClient.unhealthy_containers()
  """
  @spec unhealthy_containers(keyword()) :: {:ok, [container()]} | {:error, error_reason()}
  def unhealthy_containers(opts \\ []) do
    with_telemetry(:unhealthy_containers, %{}, fn ->
      case list_containers(opts) do
        {:ok, containers} ->
          unhealthy =
            containers
            |> Enum.filter(fn c ->
              c[:health] == :unhealthy or c[:status] == :dead
            end)

          {:ok, unhealthy}

        error ->
          error
      end
    end)
  end

  # ============================================================================
  # Client API - System Operations
  # ============================================================================

  @doc """
  Gets Podman system information.

  ## Examples

      {:ok, info} = CepafClient.system_info()
  """
  @spec system_info(keyword()) :: {:ok, map()} | {:error, error_reason()}
  def system_info(opts \\ []) do
    cache_key = {:system, :info}
    force_refresh = Keyword.get(opts, :force_refresh, false)

    with_cache(cache_key, @default_cache_ttl, force_refresh, fn ->
      with_telemetry(:system_info, %{}, fn ->
        CepafPort.system_info(opts)
      end)
    end)
  end

  @doc """
  Pings the Podman service to verify connectivity.

  ## Examples

      :ok = CepafClient.ping()
  """
  @spec ping() :: :ok | {:error, error_reason()}
  def ping do
    with_telemetry(:ping, %{}, fn ->
      CepafPort.ping()
    end)
  end

  @doc """
  Checks if Podman is available and responsive.

  ## Examples

      true = CepafClient.podman_available?()
  """
  @spec podman_available?() :: boolean()
  def podman_available? do
    ping() == :ok
  end

  # ============================================================================
  # Client API - Logs and Stats
  # ============================================================================

  @doc """
  Gets container logs.

  Logs are NOT cached due to their dynamic nature.

  ## Options

  - `:tail` - Number of lines from end
  - `:since` - Only logs since timestamp
  - `:timestamps` - Include timestamps

  ## Examples

      {:ok, logs} = CepafClient.container_logs("indrajaal-app", tail: 100)
  """
  @spec container_logs(String.t(), keyword()) :: {:ok, String.t()} | {:error, error_reason()}
  def container_logs(id_or_name, opts \\ []) do
    with_telemetry(:container_logs, %{id: id_or_name, tail: Keyword.get(opts, :tail)}, fn ->
      CepafPort.container_logs(id_or_name, opts)
    end)
  end

  @doc """
  Gets container resource usage stats.

  Stats are NOT cached due to their dynamic nature.

  ## Examples

      {:ok, stats} = CepafClient.container_stats("indrajaal-app")
  """
  @spec container_stats(String.t(), keyword()) :: {:ok, map()} | {:error, error_reason()}
  def container_stats(id_or_name, opts \\ []) do
    with_telemetry(:container_stats, %{id: id_or_name}, fn ->
      CepafPort.container_stats(id_or_name, opts)
    end)
  end

  # ============================================================================
  # Client API - Cache Management
  # ============================================================================

  @doc """
  Invalidates the entire cache, forcing fresh data on next request.

  ## Examples

      :ok = CepafClient.invalidate_cache()
  """
  @spec invalidate_cache() :: :ok
  def invalidate_cache do
    GenServer.call(__MODULE__, :invalidate_cache)
  end

  @doc """
  Invalidates cache for a specific container.

  ## Examples

      :ok = CepafClient.invalidate_container("indrajaal-db")
  """
  @spec invalidate_container(String.t()) :: :ok
  def invalidate_container(id_or_name) do
    GenServer.call(__MODULE__, {:invalidate_container, id_or_name})
  end

  @doc """
  Gets cache statistics for monitoring.

  ## Examples

      stats = CepafClient.cache_stats()
      # => %{size: 15, hits: 42, misses: 8, hit_ratio: 0.84}
  """
  @spec cache_stats() :: map()
  def cache_stats do
    GenServer.call(__MODULE__, :cache_stats)
  end

  # ============================================================================
  # Client API - Convenience Functions
  # ============================================================================

  @doc """
  Gets all Indrajaal stack containers (filtered by label).

  ## Examples

      {:ok, containers} = CepafClient.indrajaal_containers()
  """
  @spec indrajaal_containers(keyword()) :: {:ok, [container()]} | {:error, error_reason()}
  def indrajaal_containers(opts \\ []) do
    list_containers(Keyword.put(opts, :labels, ["intelitor=true"]))
  end

  @doc """
  Gets the database container.

  ## Examples

      {:ok, db} = CepafClient.database_container()
  """
  @spec database_container() :: {:ok, container()} | {:error, error_reason()}
  def database_container do
    get_container("indrajaal-db")
  end

  @doc """
  Gets the application container.

  ## Examples

      {:ok, app} = CepafClient.app_container()
  """
  @spec app_container() :: {:ok, container()} | {:error, error_reason()}
  def app_container do
    get_container("indrajaal-app")
  end

  @doc """
  Gets the observability container.

  ## Examples

      {:ok, obs} = CepafClient.observability_container()
  """
  @spec observability_container() :: {:ok, container()} | {:error, error_reason()}
  def observability_container do
    get_container("indrajaal-obs")
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    cache_ttl = Keyword.get(opts, :cache_ttl, @default_cache_ttl)
    refresh_interval = Keyword.get(opts, :refresh_interval, :timer.minutes(1))

    # Create ETS table for caching
    cache_table =
      :ets.new(@cache_table, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])

    # Initialize cache stats counter
    :ets.insert(cache_table, {:stats, %{hits: 0, misses: 0}})

    # Schedule periodic cache refresh
    if refresh_interval > 0 do
      Process.send_after(self(), :refresh_cache, refresh_interval)
    end

    state = %__MODULE__{
      cache_table: cache_table,
      cache_ttl: cache_ttl,
      last_refresh: DateTime.utc_now(),
      refresh_interval: refresh_interval
    }

    Logger.info("CepafClient initialized",
      cache_ttl: cache_ttl,
      refresh_interval: refresh_interval
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:invalidate_cache, _from, state) do
    # Clear all cached data except stats
    :ets.match_delete(@cache_table, {{:"$1", :"$2"}, :"$3", :"$4"})

    Logger.info("CepafClient: Cache invalidated")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:invalidate_container, id_or_name}, _from, state) do
    # Clear cache entries for specific container
    :ets.delete(@cache_table, {:container, id_or_name})
    :ets.delete(@cache_table, {:health, id_or_name})

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:cache_stats, _from, state) do
    stats =
      case :ets.lookup(@cache_table, :stats) do
        [{:stats, s}] -> s
        [] -> %{hits: 0, misses: 0}
      end

    size = :ets.info(@cache_table, :size) - 1
    total = stats.hits + stats.misses

    hit_ratio =
      if total > 0 do
        Float.round(stats.hits / total, 2)
      else
        0.0
      end

    {:reply, Map.merge(stats, %{size: size, hit_ratio: hit_ratio}), state}
  end

  @impl true
  def handle_info(:refresh_cache, state) do
    # Refresh commonly used cache entries
    spawn(fn ->
      list_containers(force_refresh: true)
      health_summary(force_refresh: true)
    end)

    # Schedule next refresh
    Process.send_after(self(), :refresh_cache, state.refresh_interval)

    {:noreply, %{state | last_refresh: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("CepafClient: Unexpected message", message: inspect(msg))
    {:noreply, state}
  end

  # ============================================================================
  # Private Functions - Caching
  # ============================================================================

  defp with_cache(key, ttl, force_refresh, fun) do
    if force_refresh do
      update_cache_stats(:misses)
      result = fun.()
      cache_put(key, result, ttl)
      result
    else
      case cache_get(key) do
        {:ok, value} ->
          update_cache_stats(:hits)
          {:ok, value}

        :miss ->
          update_cache_stats(:misses)
          result = fun.()
          cache_put(key, result, ttl)
          result
      end
    end
  end

  defp cache_get(key) do
    case :ets.lookup(@cache_table, key) do
      [{^key, value, expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          {:ok, value}
        else
          :ets.delete(@cache_table, key)
          :miss
        end

      [] ->
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  defp cache_put(key, {:ok, value}, ttl) do
    expires_at = DateTime.add(DateTime.utc_now(), ttl, :millisecond)
    :ets.insert(@cache_table, {key, value, expires_at})
  rescue
    ArgumentError -> :ok
  end

  defp cache_put(_key, _error, _ttl), do: :ok

  defp update_cache_stats(type) do
    :ets.update_counter(@cache_table, :stats, {2, 1}, {:stats, %{hits: 0, misses: 0}})
  rescue
    ArgumentError ->
      # Table might not exist during tests
      :ok

    _ ->
      # Fallback for any update issues
      case :ets.lookup(@cache_table, :stats) do
        [{:stats, stats}] ->
          new_stats = Map.update(stats, type, 1, &(&1 + 1))
          :ets.insert(@cache_table, {:stats, new_stats})

        [] ->
          base_stats = %{hits: 0, misses: 0}
          :ets.insert(@cache_table, {:stats, Map.put(base_stats, type, 1)})
      end
  end

  # ============================================================================
  # Private Functions - Telemetry
  # ============================================================================

  defp with_telemetry(operation, metadata, fun) do
    start_time = System.monotonic_time()

    :telemetry.execute(
      [:indrajaal, :cepaf_client, operation, :start],
      %{system_time: System.system_time()},
      metadata
    )

    try do
      result = fun.()
      duration = System.monotonic_time() - start_time

      :telemetry.execute(
        [:indrajaal, :cepaf_client, operation, :stop],
        %{duration: duration},
        Map.merge(metadata, %{result: result_type(result)})
      )

      result
    rescue
      exception ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:indrajaal, :cepaf_client, operation, :exception],
          %{duration: duration},
          Map.merge(metadata, %{kind: :error, reason: exception})
        )

        reraise exception, __STACKTRACE__
    end
  end

  defp result_type({:ok, _}), do: :ok
  defp result_type({:error, reason}), do: {:error, reason}
  defp result_type(:ok), do: :ok
  defp result_type(other), do: other

  # ============================================================================
  # Private Functions - Retry Logic
  # ============================================================================

  defp with_retry(fun, attempt \\ 1) do
    case fun.() do
      {:ok, _} = success ->
        success

      {:error, :timeout} when attempt < @max_retries ->
        backoff = (@retry_backoff_base * :math.pow(2, attempt - 1)) |> round()
        Process.sleep(backoff)

        Logger.warning("CepafClient: Retrying after timeout",
          attempt: attempt + 1,
          backoff: backoff
        )

        with_retry(fun, attempt + 1)

      {:error, :connection_refused} when attempt < @max_retries ->
        backoff = (@retry_backoff_base * :math.pow(2, attempt - 1)) |> round()
        Process.sleep(backoff)

        Logger.warning("CepafClient: Retrying after connection refused",
          attempt: attempt + 1,
          backoff: backoff
        )

        with_retry(fun, attempt + 1)

      error ->
        error
    end
  end

  # ============================================================================
  # Private Functions - Data Normalization
  # ============================================================================

  defp normalize_container(data) when is_map(data) do
    %{
      id: data[:id] || data["Id"] || "",
      name: extract_name(data),
      image: data[:image] || data[:image_name] || data["Image"] || "",
      status: data[:status] || data[:state][:status] || :unknown,
      health: extract_health(data),
      created: data[:created] || nil,
      ports: data[:ports] || [],
      labels: data[:labels] || %{}
    }
  end

  defp extract_name(data) do
    cond do
      data[:name] ->
        String.trim_leading(to_string(data[:name]), "/")

      data[:names] && is_list(data[:names]) ->
        first_name = hd(data[:names])
        String.trim_leading(first_name, "/")

      data["Name"] ->
        String.trim_leading(data["Name"], "/")

      true ->
        ""
    end
  end

  defp extract_health(data) do
    cond do
      data[:health] -> data[:health]
      data[:state] && data[:state][:health] -> data[:state][:health]
      data[:state] && data[:state]["Health"] -> parse_health(data[:state]["Health"])
      true -> nil
    end
  end

  defp parse_health(health) when is_map(health) do
    status = health["Status"] || health[:status]
    parse_health(status)
  end

  defp parse_health(status) when is_binary(status) do
    case String.downcase(status) do
      "healthy" -> :healthy
      "unhealthy" -> :unhealthy
      "starting" -> :starting
      "none" -> :no_healthcheck
      _ -> :unknown
    end
  end

  defp parse_health(_), do: nil
end
