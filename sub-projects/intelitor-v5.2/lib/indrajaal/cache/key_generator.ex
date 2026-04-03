defmodule Indrajaal.Cache.KeyGenerator do
  @moduledoc """
  Generates consistent cache keys for different cache types.

  Key format conventions:
  - Session: "session:{user_id}"
  - Entity: "entity:{type}:{id}:{tenant_id}"
  - Query: "query:{hash}"
  - API: "api:{endpoint}:{params_hash}"

  Agent: Helper - 3 manages cache keys
  SOPv5.1 Compliance: ✅
  """

  @doc """
  Generate session cache key.
  """
  @spec session_key(any()) :: any()
  def session_key(user_id) do
    "session:#{user_id}"
  end

  @doc """
  Generate entity cache key with tenant isolation.
  """
  @spec entity_key(term(), term(), term()) :: term()
  def entity_key(type, id, tenant_id \\ nil) do
    if tenant_id do
      "entity:#{type}:#{id}:#{tenant_id}"
    else
      "entity:#{type}:#{id}"
    end
  end

  @doc """
  Generate query cache key from query parameters.
  """
  @spec query_key(any()) :: any()
  def query_key(query_params) when is_map(query_params) do
    hash =
      query_params
      |> Jason.encode!()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
      |> String.slice(0, 16)

    "query:#{hash}"
  end

  @spec query_key(any()) :: any()
  def query_key(query_string) when is_binary(query_string) do
    hash_binary = :crypto.hash(:sha256, query_string)

    hash =
      hash_binary
      |> Base.encode16(case: :lower)
      |> String.slice(0, 16)

    "query:#{hash}"
  end

  @doc """
  Generate API response cache key.
  """
  @spec api_key(any(), any()) :: any()
  def api_key(endpoint, params \\ %{}) do
    params_hash =
      params
      |> Enum.sort()
      |> Jason.encode!()
      |> then(&:crypto.hash(:md5, &1))
      |> Base.encode16(case: :lower)
      |> String.slice(0, 8)

    "api:#{endpoint}:#{params_hash}"
  end

  @doc """
  Generate batch operation cache key.
  """
  @spec batch_key(any(), any()) :: any()
  def batch_key(operation, ids) when is_list(ids) do
    ids_hash =
      ids
      |> Enum.sort()
      |> Enum.join(",")
      |> then(&:crypto.hash(:md5, &1))
      |> Base.encode16(case: :lower)
      |> String.slice(0, 8)

    "batch:#{operation}:#{ids_hash}"
  end

  @doc """
  Generate WebSocket channel state key.
  """
  @spec channel_key(any(), any()) :: any()
  def channel_key(channel, topic) do
    "channel:#{channel}:#{topic}"
  end

  @doc """
  Generate rate limit key.
  """
  @spec rate_limit_key(any(), any()) :: any()
  def rate_limit_key(identifier, window) do
    "rate_limit:#{identifier}:#{window}"
  end

  @doc """
  Parse cache key to extract components.
  """
  @spec parse_key(any()) :: any()
  def parse_key(key) do
    case String.split(key, ":", parts: 3) do
      ["session", user_id] ->
        {:session, user_id}

      ["entity", type, rest] ->
        case String.split(rest, ":") do
          [id, tenant_id] -> {:entity, type, id, tenant_id}
          [id] -> {:entity, type, id, nil}
        end

      ["query", hash] ->
        {:query, hash}

      ["api", endpoint, params_hash] ->
        {:api, endpoint, params_hash}

      _ ->
        {:unknown, key}
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
