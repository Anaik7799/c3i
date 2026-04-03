defmodule Route do
  @moduledoc """
  Route matching and URL routing for the enterprise security gateway.

  Provides route pattern parsing, path matching with parameter extraction,
  and route lookup against a set of built-in API patterns.

  ## Route Pattern Syntax

  - Static segments: `/api/v1/health`
  - Dynamic segments: `/api/v1/alarms/:id` — captures a single path segment
  - Wildcard segments: `/api/prajna/*rest` — captures the remainder of the path

  ## Built-in Route Patterns

  The gateway recognises these structural patterns without an external registry:

  - `/health` — liveness probe
  - `/api/prajna/*rest` — Prajna cockpit and sub-paths
  - `/api/v1/:domain/:action` — two-segment domain API
  - `/api/v1/:domain/:id/:action` — three-segment domain API with resource id

  ## Examples

      iex> Route.parse_route("/api/v1/alarms/:id")
      {:ok, %{pattern: "/api/v1/alarms/:id", segments: [
        {:static, "api"}, {:static, "v1"}, {:static, "alarms"}, {:dynamic, "id"}
      ], param_names: ["id"], wildcard: nil}}

      iex> Route.find_matching_route(:get, "/api/v1/alarms/42")
      {:ok, %{pattern: "/api/v1/:domain/:id", method: :any,
              params: %{"domain" => "alarms", "id" => "42"}}}

  ## STAMP Compliance
  - SC-PRF-050: Route lookup is O(n) in the number of patterns; n is fixed and small.
  - SC-FUNC-001: Pure functions, no side effects, no external state.
  """

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Parse a route pattern string into a structured map.

  Returns a map containing:
  - `:pattern` — the original pattern string
  - `:segments` — list of `{:static, name}` or `{:dynamic, name}` tuples
  - `:param_names` — ordered list of dynamic parameter names
  - `:wildcard` — name of the wildcard capture, or `nil`

  A wildcard segment (`*name`) must appear last and matches the rest of the path.

  ## Examples

      iex> Route.parse_route("/api/v1/:domain/:action")
      {:ok, %{pattern: "/api/v1/:domain/:action",
              segments: [{:static, "api"}, {:static, "v1"},
                         {:dynamic, "domain"}, {:dynamic, "action"}],
              param_names: ["domain", "action"],
              wildcard: nil}}

      iex> Route.parse_route("/api/prajna/*rest")
      {:ok, %{pattern: "/api/prajna/*rest",
              segments: [{:static, "api"}, {:static, "prajna"}, {:wildcard, "rest"}],
              param_names: [],
              wildcard: "rest"}}
  """
  @spec parse_route(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_route(pattern) when is_binary(pattern) do
    raw_segments =
      pattern
      |> String.trim_leading("/")
      |> String.split("/", trim: true)

    case build_segments(raw_segments, [], []) do
      {:ok, segments, param_names, wildcard} ->
        {:ok,
         %{
           pattern: pattern,
           segments: segments,
           param_names: param_names,
           wildcard: wildcard
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse_route(other) do
    {:error, "parse_route/1 expects a binary, got: #{inspect(other)}"}
  end

  @doc """
  Match a concrete path against a parsed route pattern.

  `parsed_route` must be a map as returned by `parse_route/1`.
  `path` is a raw URL path string.

  Returns `{:ok, %{params: %{...}}}` with extracted parameter values on match,
  or `{:error, :no_match}` when the path does not fit the pattern.

  ## Examples

      iex> {:ok, parsed} = Route.parse_route("/api/v1/alarms/:id")
      iex> Route.match_route(parsed, "/api/v1/alarms/99")
      {:ok, %{params: %{"id" => "99"}}}

      iex> Route.match_route(parsed, "/api/v1/alarms")
      {:error, :no_match}
  """
  @spec match_route(map() | String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def match_route(%{segments: _} = parsed_route, path) when is_binary(path) do
    path_segments =
      path
      |> String.trim_leading("/")
      |> String.split("/", trim: true)

    match_segments(parsed_route.segments, path_segments, %{})
  end

  def match_route(pattern, path) when is_binary(pattern) and is_binary(path) do
    case parse_route(pattern) do
      {:ok, parsed} -> match_route(parsed, path)
      {:error, reason} -> {:error, reason}
    end
  end

  def match_route(_route, _path) do
    {:error, :no_match}
  end

  @doc """
  Find a matching route for the given HTTP method and path.

  Checks the built-in route table in priority order and returns the first match.
  The returned map includes the matched pattern, the effective method constraint,
  and the extracted path parameters.

  ## Parameters
  - `method` — HTTP method atom (`:get`, `:post`, `:put`, `:patch`, `:delete`, `:head`, `:options`) or `nil`
  - `path` — URL path string

  ## Returns
  - `{:ok, route_map}` on match
  - `{:error, :no_matching_route}` (as a `String.t()` to satisfy the spec) when nothing matches
  """
  @spec find_matching_route(atom() | nil, String.t()) :: {:ok, map()} | {:error, String.t()}
  def find_matching_route(method \\ nil, path)

  def find_matching_route(method, path) when is_binary(path) do
    normalised_method = normalise_method(method)

    case do_find(path, normalised_method) do
      {:ok, route} -> {:ok, route}
      {:error, :no_matching_route} -> {:error, "no_matching_route"}
    end
  end

  def find_matching_route(_method, path) do
    {:error, "find_matching_route/2 expects a binary path, got: #{inspect(path)}"}
  end

  @doc """
  Find a matching route with additional matching constraints.

  Accepts the same `method` and `path` arguments as `find_matching_route/2`
  plus a keyword list of optional constraints:

  - `:content_type` — `String.t()` — require a specific Content-Type (informational only)
  - `:tenant_id` — `String.t()` — tenant scope (informational only)

  Constraints are recorded in the returned route map but do not filter the
  route table beyond what the path and method already provide.
  """
  @spec find_matching_route(atom() | nil, String.t(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def find_matching_route(method, path, options)
      when is_binary(path) and is_list(options) do
    case find_matching_route(method, path) do
      {:ok, route} ->
        route_with_opts =
          route
          |> maybe_put(:content_type, Keyword.get(options, :content_type))
          |> maybe_put(:tenant_id, Keyword.get(options, :tenant_id))

        {:ok, route_with_opts}

      error ->
        error
    end
  end

  def find_matching_route(_method, path, _options) do
    {:error, "find_matching_route/3 expects a binary path, got: #{inspect(path)}"}
  end

  # ---------------------------------------------------------------------------
  # Internal: built-in route table
  # ---------------------------------------------------------------------------

  # Routes are checked in the order listed; first match wins.
  # Each entry is {pattern_string, method_constraint} where method_constraint
  # is :any or a specific atom.
  @route_table [
    {"/health", :any},
    {"/api/prajna/*rest", :any},
    {"/api/v1/:domain/:id/:action", :any},
    {"/api/v1/:domain/:action", :any}
  ]

  defp do_find(path, method) do
    Enum.reduce_while(@route_table, {:error, :no_matching_route}, fn {pattern, constraint},
                                                                     _acc ->
      if method_matches?(method, constraint) do
        case parse_route(pattern) do
          {:ok, parsed} ->
            case match_route(parsed, path) do
              {:ok, %{params: params}} ->
                route = %{
                  pattern: pattern,
                  method: constraint,
                  params: params
                }

                {:halt, {:ok, route}}

              {:error, _} ->
                {:cont, {:error, :no_matching_route}}
            end

          {:error, _} ->
            {:cont, {:error, :no_matching_route}}
        end
      else
        {:cont, {:error, :no_matching_route}}
      end
    end)
  end

  defp method_matches?(_method, :any), do: true
  defp method_matches?(method, method), do: true
  defp method_matches?(nil, _constraint), do: true
  defp method_matches?(_method, _constraint), do: false

  # ---------------------------------------------------------------------------
  # Internal: segment building
  # ---------------------------------------------------------------------------

  defp build_segments([], acc_segs, acc_params) do
    {:ok, Enum.reverse(acc_segs), Enum.reverse(acc_params), nil}
  end

  defp build_segments(["*" <> name | rest], acc_segs, acc_params) do
    if rest == [] do
      segments = Enum.reverse([{:wildcard, name} | acc_segs])
      {:ok, segments, Enum.reverse(acc_params), name}
    else
      {:error, "wildcard segment *#{name} must be the last segment in the pattern"}
    end
  end

  defp build_segments([":" <> name | rest], acc_segs, acc_params) do
    build_segments(rest, [{:dynamic, name} | acc_segs], [name | acc_params])
  end

  defp build_segments([segment | rest], acc_segs, acc_params) do
    build_segments(rest, [{:static, segment} | acc_segs], acc_params)
  end

  # ---------------------------------------------------------------------------
  # Internal: segment matching
  # ---------------------------------------------------------------------------

  defp match_segments([], [], params) do
    {:ok, %{params: params}}
  end

  defp match_segments([{:wildcard, name}], path_segs, params) do
    # Consume all remaining path segments into the wildcard capture
    rest = Enum.join(path_segs, "/")
    {:ok, %{params: Map.put(params, name, rest)}}
  end

  defp match_segments([{:static, expected} | pat_rest], [actual | path_rest], params)
       when expected == actual do
    match_segments(pat_rest, path_rest, params)
  end

  defp match_segments([{:dynamic, name} | pat_rest], [value | path_rest], params) do
    match_segments(pat_rest, path_rest, Map.put(params, name, value))
  end

  defp match_segments(_pattern_segs, _path_segs, _params) do
    {:error, :no_match}
  end

  # ---------------------------------------------------------------------------
  # Internal: helpers
  # ---------------------------------------------------------------------------

  defp normalise_method(nil), do: nil
  defp normalise_method(m) when is_atom(m), do: m

  defp normalise_method(m) when is_binary(m) do
    m |> String.downcase() |> String.to_existing_atom()
  rescue
    ArgumentError -> nil
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
