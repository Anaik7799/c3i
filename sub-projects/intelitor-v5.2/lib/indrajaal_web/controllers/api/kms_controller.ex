defmodule IndrajaalWeb.Api.KmsController do
  @moduledoc """
  REST API Controller for the Fractal Holonic Knowledge Management System.

  WHAT: RESTful endpoints for KMS holon CRUD, search, and analytics.
  WHY: Enable web/mobile/F# clients to access KMS via HTTP.
  CONSTRAINTS: SC-KMS-001, SC-KMS-002, SC-KMS-004 (OODA <100ms)

  ## Endpoints

  | Method | Path | Description |
  |--------|------|-------------|
  | GET | /api/kms/holons | List holons (with filters) |
  | GET | /api/kms/holons/:id | Get single holon |
  | POST | /api/kms/holons | Create holon |
  | PUT | /api/kms/holons/:id | Update holon |
  | DELETE | /api/kms/holons/:id | Delete holon |
  | GET | /api/kms/holons/:id/children | Get children |
  | GET | /api/kms/holons/:id/descendants | Get all descendants |
  | GET | /api/kms/search | Full-text search |
  | GET | /api/kms/health | Health report (analytics) |
  | GET | /api/kms/entropy | Entropy report (stale holons) |
  | GET | /api/kms/stats | Event statistics |
  | POST | /api/kms/edges | Create relationship |
  | POST | /api/kms/oracle | Ask the KMS Oracle |
  """

  use IndrajaalWeb, :controller

  alias Indrajaal.KMS

  # ...

  @doc """
  Ask the KMS Oracle a question (RAG).
  POST /api/kms/oracle
  """
  def oracle(conn, %{"query" => query} = params) do
    opts =
      [
        model: Map.get(params, "model"),
        limit: parse_int(Map.get(params, "limit"), 10)
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    case KMS.ask_oracle(query, opts) do
      {:ok, response} ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "success",
          data: %{
            query: query,
            response: response
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  action_fallback IndrajaalWeb.FallbackController

  # ============================================================================
  # CRUD Operations
  # ============================================================================

  @doc """
  List holons with optional filtering.

  GET /api/kms/holons

  ## Query Parameters
  - `type` - Filter by type (knowledge, process, agent, artifact, index)
  - `limit` - Max results (default: 100)
  - `offset` - Pagination offset (default: 0)
  """
  def index(conn, params) do
    opts = parse_list_params(params)

    case KMS.list_holons(opts) do
      {:ok, holons} ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "success",
          data: Enum.map(holons, &serialize_holon/1),
          meta: %{
            count: length(holons),
            limit: opts[:limit],
            offset: opts[:offset]
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  @doc """
  Get a single holon by ID.

  GET /api/kms/holons/:id
  """
  def show(conn, %{"id" => id}) do
    case KMS.get_holon(id) do
      {:ok, holon} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "success", data: serialize_holon(holon)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Holon not found"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  @doc """
  Create a new holon.

  POST /api/kms/holons

  ## Request Body
  ```json
  {
    "type": "knowledge",
    "name": "My Knowledge",
    "payload": {"content": "..."},
    "parent_id": null,
    "genome": {},
    "membrane": {}
  }
  ```
  """
  def create(conn, %{"holon" => holon_params}) do
    attrs = %{
      type: parse_type(holon_params["type"]),
      name: holon_params["name"],
      payload: holon_params["payload"] || %{},
      parent_id: holon_params["parent_id"],
      genome: holon_params["genome"] || %{},
      membrane: holon_params["membrane"] || %{}
    }

    case KMS.create_holon(attrs) do
      {:ok, holon} ->
        conn
        |> put_status(:created)
        |> json(%{status: "success", data: serialize_holon(holon)})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  # Also support flat params (no "holon" wrapper)
  def create(conn, params) when is_map(params) and not is_map_key(params, "holon") do
    create(conn, %{"holon" => params})
  end

  @doc """
  Update an existing holon.

  PUT /api/kms/holons/:id

  ## Request Body
  ```json
  {
    "payload": {"content": "updated..."},
    "vital_signs": {"health": 0.9, "stress": 0.1, "energy": 0.8}
  }
  ```
  """
  def update(conn, %{"id" => id} = params) do
    attrs =
      params
      |> Map.delete("id")
      |> Map.get("holon", params)
      |> parse_update_attrs()

    case KMS.update_holon(id, attrs) do
      {:ok, holon} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "success", data: serialize_holon(holon)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Holon not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  @doc """
  Delete a holon.

  DELETE /api/kms/holons/:id
  """
  def delete(conn, %{"id" => id}) do
    case KMS.delete_holon(id) do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{status: "success", message: "Holon deleted"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Holon not found"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  # ============================================================================
  # Relationships
  # ============================================================================

  @doc """
  Get children of a holon.

  GET /api/kms/holons/:id/children
  """
  def children(conn, %{"id" => id}) do
    case KMS.get_children(id) do
      {:ok, children} ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "success",
          data: Enum.map(children, &serialize_holon/1),
          meta: %{parent_id: id, count: length(children)}
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  @doc """
  Get all descendants of a holon (recursive).

  GET /api/kms/holons/:id/descendants
  """
  def descendants(conn, %{"id" => id}) do
    case KMS.get_descendants(id) do
      {:ok, descendants} ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "success",
          data: Enum.map(descendants, &serialize_holon/1),
          meta: %{root_id: id, count: length(descendants)}
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  @doc """
  Create a relationship between two holons.

  POST /api/kms/edges

  ## Request Body
  ```json
  {
    "source_id": "hln_xxx",
    "target_id": "hln_yyy",
    "relation": "contains",
    "weight": 1.0,
    "metadata": {}
  }
  ```
  """
  def create_edge(conn, params) do
    source_id = params["source_id"]
    target_id = params["target_id"]
    relation = String.to_atom(params["relation"] || "references")
    weight = params["weight"] || 1.0
    metadata = params["metadata"] || %{}

    case KMS.create_edge(source_id, target_id, relation, weight: weight, metadata: metadata) do
      :ok ->
        conn
        |> put_status(:created)
        |> json(%{
          status: "success",
          message: "Edge created",
          data: %{source_id: source_id, target_id: target_id, relation: relation}
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  # ============================================================================
  # Search
  # ============================================================================

  @doc """
  Full-text search across holons.

  GET /api/kms/search?q=query&limit=20
  """
  def search(conn, params) do
    query = params["q"] || params["query"] || ""
    limit = parse_int(params["limit"], 20)

    if String.trim(query) == "" do
      conn
      |> put_status(:bad_request)
      |> json(%{status: "error", message: "Query parameter 'q' is required"})
    else
      case KMS.search(query, limit: limit) do
        {:ok, results} ->
          conn
          |> put_status(:ok)
          |> json(%{
            status: "success",
            data: Enum.map(results, &serialize_holon/1),
            meta: %{query: query, count: length(results)}
          })

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{status: "error", message: inspect(reason)})
      end
    end
  end

  # ============================================================================
  # Analytics
  # ============================================================================

  @doc """
  Get health report aggregating vital signs.

  GET /api/kms/health
  """
  def health(conn, _params) do
    case KMS.health_report() do
      {:ok, report} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "success", data: report})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  @doc """
  Get entropy report (stale/degraded holons).

  GET /api/kms/entropy?threshold=0.5
  """
  def entropy(conn, params) do
    threshold = parse_float(params["threshold"], 0.5)

    case KMS.entropy_report(threshold) do
      {:ok, report} ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "success",
          data: report,
          meta: %{threshold: threshold, count: length(report)}
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  @doc """
  Get event statistics over time.

  GET /api/kms/stats?days=30
  """
  def stats(conn, params) do
    days = parse_int(params["days"], 30)

    case KMS.event_stats(days: days) do
      {:ok, stats} ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "success",
          data: stats,
          meta: %{days: days}
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp parse_list_params(params) do
    [
      type: parse_type(params["type"]),
      limit: parse_int(params["limit"], 100),
      offset: parse_int(params["offset"], 0)
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp parse_type(nil), do: nil
  defp parse_type(type) when is_atom(type), do: type

  defp parse_type(type) when is_binary(type) do
    case type do
      "knowledge" -> :knowledge
      "process" -> :process
      "agent" -> :agent
      "artifact" -> :artifact
      "index" -> :index
      _ -> nil
    end
  end

  defp parse_int(nil, default), do: default
  defp parse_int(val, _default) when is_integer(val), do: val

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_float(nil, default), do: default
  defp parse_float(val, _default) when is_float(val), do: val
  defp parse_float(val, _default) when is_integer(val), do: val / 1

  defp parse_float(val, default) when is_binary(val) do
    case Float.parse(val) do
      {float, _} -> float
      :error -> default
    end
  end

  defp parse_update_attrs(params) do
    %{}
    |> maybe_put(:name, params["name"])
    |> maybe_put(:payload, params["payload"])
    |> maybe_put(:vital_signs, params["vital_signs"])
    |> maybe_put(:genome, params["genome"])
    |> maybe_put(:membrane, params["membrane"])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp serialize_holon(holon) when is_map(holon) do
    %{
      id: holon[:id] || holon["id"],
      fqun: holon[:fqun] || holon["fqun"],
      type: holon[:type] || holon["type"],
      name: holon[:name] || holon["name"],
      parent_id: holon[:parent_id] || holon["parent_id"],
      genome: parse_json_field(holon[:genome] || holon["genome"]),
      vital_signs: parse_json_field(holon[:vital_signs] || holon["vital_signs"]),
      membrane: parse_json_field(holon[:membrane] || holon["membrane"]),
      payload: parse_json_field(holon[:payload] || holon["payload"]),
      hlc_physical: holon[:hlc_physical] || holon["hlc_physical"],
      hlc_logical: holon[:hlc_logical] || holon["hlc_logical"],
      created_at: holon[:created_at] || holon["created_at"],
      updated_at: holon[:updated_at] || holon["updated_at"]
    }
  end

  defp parse_json_field(nil), do: %{}
  defp parse_json_field(value) when is_map(value), do: value

  defp parse_json_field(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{}
    end
  end
end
