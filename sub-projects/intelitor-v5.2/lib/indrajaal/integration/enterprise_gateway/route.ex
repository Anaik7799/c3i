defmodule Indrajaal.Integration.Enterprise.Route do
  @moduledoc """
  WHAT: Ash resource for gateway route configuration plus ETS-backed hot-path
        route matching. Supports path patterns (`:param`, `*` wildcard), HTTP
        method filtering, and middleware chain metadata.

  WHY: The enterprise gateway needs sub-millisecond route resolution for every
       inbound request. Persisted configuration lives in PostgreSQL; the compiled
       route table is cached in ETS and refreshed on configuration change.

  CONSTRAINTS:
  - SC-PRF-055:  No blocking operations in the hot path
  - SC-PRF-050:  Response < 50ms
  - AOR-HOLON-001: Route cache in ETS; policy in PostgreSQL
  - AOR-AGT-001: mix compile must pass before task complete

  ## Change History
  | Version | Date       | Author | Change                                        |
  |---------|------------|--------|-----------------------------------------------|
  | 21.2.1  | 2026-03-23 | Claude | Real route matching with ETS cache            |
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Integration.Enterprise,
    extensions: [AshPostgres, AshJsonApi.Resource]

  require Logger

  @table :gateway_routes_cache
  @telemetry_prefix [:indrajaal, :integration, :route]

  # ---------------------------------------------------------------------------
  # Ash resource — persisted route configuration
  # ---------------------------------------------------------------------------

  postgres do
    table "routes"
    repo Indrajaal.Repo
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
    update_timestamp :updated_at

    attribute :name, :string, allow_nil?: false
    attribute :description, :string
    attribute :active, :boolean, default: true

    # Routing attributes
    attribute :path_pattern, :string, allow_nil?: false
    attribute :methods, {:array, :string}, default: ["GET", "POST", "PUT", "DELETE", "PATCH"]
    attribute :backend_url, :string
    attribute :strip_prefix, :boolean, default: false
    attribute :prefix_to_strip, :string
    attribute :middleware, {:array, :string}, default: []
    attribute :priority, :integer, default: 100
    attribute :rate_limit_id, :uuid
    attribute :timeout_ms, :integer, default: 30_000
    attribute :retry_count, :integer, default: 2
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :description,
        :active,
        :path_pattern,
        :methods,
        :backend_url,
        :strip_prefix,
        :prefix_to_strip,
        :middleware,
        :priority,
        :rate_limit_id,
        :timeout_ms,
        :retry_count
      ]
    end

    update :update do
      accept [
        :name,
        :description,
        :active,
        :path_pattern,
        :methods,
        :backend_url,
        :strip_prefix,
        :prefix_to_strip,
        :middleware,
        :priority,
        :rate_limit_id,
        :timeout_ms,
        :retry_count
      ]
    end
  end

  # ---------------------------------------------------------------------------
  # ETS-backed route matching — hot path API
  # ---------------------------------------------------------------------------

  @doc """
  Ensures the ETS route cache table exists. Idempotent.
  """
  @spec ensure_table() :: :ok
  def ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:ordered_set, :public, :named_table, {:read_concurrency, true}])
        Logger.debug("Route: ETS cache table #{@table} created")
        :ok

      _ref ->
        :ok
    end
  end

  @doc """
  Finds the highest-priority active route matching `path` and `method`.

  Routes are matched in priority order (lower number = higher priority).
  Path patterns support:
  - Exact match: `/api/users`
  - Parameter segments: `/api/users/:id`
  - Wildcard suffix: `/api/v1/*`

  Returns `{:ok, route_map, params}` or `{:error, :not_found}`.
  """
  @spec find_matching_route(String.t(), String.t()) ::
          {:ok, map(), map()} | {:error, :not_found}
  def find_matching_route(path, method) do
    ensure_table()
    start = System.monotonic_time(:microsecond)
    normalized_method = String.upcase(method)

    result =
      @table
      |> :ets.tab2list()
      |> Enum.sort_by(fn {priority, _} -> priority end)
      |> Enum.find_value({:error, :not_found}, fn {_priority, route} ->
        if route.active and method_allowed?(route, normalized_method) do
          case match_path(route.path_pattern, path) do
            {:ok, params} -> {:ok, route, params}
            :no_match -> false
          end
        else
          false
        end
      end)

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :find_matching_route,
      path: path,
      method: normalized_method,
      matched: result != {:error, :not_found}
    })

    result
  end

  @doc """
  Inserts or replaces a route in the ETS cache. Called when routes are loaded
  from the database or updated at runtime.
  """
  @spec cache_route(map()) :: :ok
  def cache_route(route) do
    ensure_table()
    priority = Map.get(route, :priority, 100)
    # Use {priority, id} as key so equal-priority routes don't overwrite each other
    key = {priority, Map.get(route, :id, :erlang.unique_integer())}
    :ets.insert(@table, {key, route})
    :ok
  end

  @doc """
  Removes a route from the ETS cache by id.
  """
  @spec evict_route(String.t()) :: :ok
  def evict_route(route_id) do
    ensure_table()

    @table
    |> :ets.tab2list()
    |> Enum.each(fn {key, route} ->
      if Map.get(route, :id) == route_id do
        :ets.delete(@table, key)
      end
    end)

    :ok
  end

  @doc """
  Rebuilds the entire ETS cache from `routes` list. Replaces all existing entries.
  """
  @spec rebuild_cache(list(map())) :: :ok
  def rebuild_cache(routes) do
    ensure_table()
    :ets.delete_all_objects(@table)

    Enum.each(routes, fn route ->
      cache_route(route)
    end)

    Logger.debug("Route cache rebuilt with #{length(routes)} routes")
    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp method_allowed?(%{methods: methods}, method) when is_list(methods) do
    Enum.member?(methods, method)
  end

  defp method_allowed?(_, _method), do: true

  # Exact match
  defp match_path(pattern, path) when pattern == path, do: {:ok, %{}}

  # Wildcard: pattern ends with /*
  defp match_path(pattern, path) do
    cond do
      String.ends_with?(pattern, "/*") ->
        prefix = String.replace_suffix(pattern, "/*", "")

        if String.starts_with?(path, prefix) do
          rest = String.replace_prefix(path, prefix, "")
          {:ok, %{"wildcard" => String.trim_leading(rest, "/")}}
        else
          :no_match
        end

      String.contains?(pattern, ":") ->
        match_parameterized(pattern, path)

      true ->
        :no_match
    end
  end

  # Matches a parameterized pattern like /api/users/:id/posts/:post_id
  defp match_parameterized(pattern, path) do
    pattern_segments = String.split(pattern, "/", trim: true)
    path_segments = String.split(path, "/", trim: true)

    if length(pattern_segments) != length(path_segments) do
      :no_match
    else
      result =
        Enum.zip(pattern_segments, path_segments)
        |> Enum.reduce_while(%{}, fn {pat_seg, path_seg}, params ->
          if String.starts_with?(pat_seg, ":") do
            param_name = String.replace_prefix(pat_seg, ":", "")
            {:cont, Map.put(params, param_name, path_seg)}
          else
            if pat_seg == path_seg, do: {:cont, params}, else: {:halt, :no_match}
          end
        end)

      case result do
        :no_match -> :no_match
        params -> {:ok, params}
      end
    end
  end
end
