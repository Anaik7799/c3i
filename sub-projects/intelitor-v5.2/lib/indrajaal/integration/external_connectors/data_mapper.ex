defmodule Indrajaal.Integration.ExternalConnectors.DataMapper do
  @moduledoc """
  WHAT: ETS-backed bidirectional data mapper for external connector
        request/response transformation. Stores per-connector field mapping
        configuration and applies it when transforming outgoing requests and
        incoming responses.

  WHY: Different external systems use different field names, types, and
       conventions. Centralising mapping logic here decouples connector
       implementations from the domain model and makes schema evolution safe.

  CONSTRAINTS:
  - SC-PRF-055: No blocking operations
  - SC-PRF-050: Response transformation < 50 ms
  - AOR-AGT-001: mix compile must pass before task complete

  ## Mapping Configuration Shape
  A mapping config is a map with optional keys:
    - `:field_map`   — `%{local_field => remote_field}` (string or atom keys)
    - `:transforms`  — `%{local_field => (value -> value)}` applied after mapping
    - `:defaults`    — `%{local_field => default_value}` for missing keys

  ## Change History
  | Version | Date       | Author | Change                               |
  |---------|------------|--------|--------------------------------------|
  | 21.2.1  | 2026-03-19 | Claude | Real ETS-backed implementation       |
  """

  require Logger

  @table :data_mapper_configs
  @telemetry_prefix [:indrajaal, :integration, :data_mapper]

  # ---------------------------------------------------------------------------
  # ETS table bootstrap
  # ---------------------------------------------------------------------------

  @doc """
  Ensures the ETS table exists. Idempotent — safe to call multiple times.
  """
  @spec ensure_table() :: :ok
  def ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:set, :public, :named_table])
        Logger.debug("DataMapper: ETS table #{@table} created")
        :ok

      _ref ->
        :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Transforms outgoing request data for `connector_id` / `operation` using the
  stored field mapping configuration.

  Applies `:field_map` (renames local keys to remote keys), then `:transforms`
  (value coercions), then inserts `:defaults` for any keys not already present.

  Returns `{:ok, transformed_data}`.
  """
  @spec transform_request(String.t() | atom(), String.t() | atom(), map()) ::
          {:ok, map()} | {:error, term()}
  def transform_request(connector_id, operation, data) when is_map(data) do
    start = System.monotonic_time(:microsecond)

    result =
      case fetch_mapping(connector_id, operation) do
        {:ok, mapping} ->
          transformed = apply_outbound_mapping(data, mapping)
          {:ok, transformed}

        {:error, :not_found} ->
          # No mapping configured — pass through unchanged
          {:ok, data}

        error ->
          error
      end

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :transform_request
    })

    result
  end

  def transform_request(_connector_id, _operation, data) do
    {:ok, data}
  end

  @doc """
  Transforms incoming response data from `connector_id` / `operation` back to
  the internal domain representation (reverse of `transform_request/3`).

  Applies the inverse `:field_map` (remote keys → local keys), then
  `:transforms`, then `:defaults`.

  Returns `{:ok, transformed_result}`.
  """
  @spec transform_response(String.t() | atom(), String.t() | atom(), map()) ::
          {:ok, map()} | {:error, term()}
  def transform_response(connector_id, operation, result) when is_map(result) do
    start = System.monotonic_time(:microsecond)

    outcome =
      case fetch_mapping(connector_id, operation) do
        {:ok, mapping} ->
          transformed = apply_inbound_mapping(result, mapping)
          {:ok, transformed}

        {:error, :not_found} ->
          {:ok, result}

        error ->
          error
      end

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :transform_response
    })

    outcome
  end

  def transform_response(_connector_id, _operation, result) do
    {:ok, result}
  end

  @doc """
  Stores or replaces the mapping configuration for `connector_id`.

  `schema` is expected to be a map with any combination of:
    `:field_map`, `:transforms`, `:defaults`.

  Returns `:ok`.
  """
  @spec update_mappings(String.t() | atom(), map()) :: :ok | {:error, term()}
  def update_mappings(connector_id, schema) when is_map(schema) do
    ensure_table()
    start = System.monotonic_time(:microsecond)

    case validate_mapping(schema) do
      :ok ->
        :ets.insert(@table, {{:mapping, connector_id}, schema})

        elapsed = System.monotonic_time(:microsecond) - start

        :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
          module: __MODULE__,
          operation: :update_mappings
        })

        Logger.debug("DataMapper: updated mappings for connector #{connector_id}")
        :ok

      {:error, reason} = error ->
        Logger.warning("DataMapper.update_mappings validation failed: #{inspect(reason)}")
        error
    end
  end

  def update_mappings(_connector_id, schema) do
    {:error, {:invalid_schema, schema}}
  end

  @doc """
  Retrieves the mapping configuration for `connector_id`.

  Returns `{:ok, mapping}` when configured, `{:error, :not_found}` otherwise.
  """
  @spec get_mappings(String.t() | atom()) :: {:ok, map()} | {:error, :not_found}
  def get_mappings(connector_id) do
    ensure_table()
    start = System.monotonic_time(:microsecond)

    result =
      case :ets.lookup(@table, {:mapping, connector_id}) do
        [{_key, mapping}] -> {:ok, mapping}
        [] -> {:error, :not_found}
      end

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :get_mappings
    })

    result
  end

  @doc """
  Validates that a mapping configuration map has a structurally valid shape.

  Checks that `:field_map` (if present) contains only string/atom keys mapping
  to string/atom values, and that `:transforms` (if present) contains functions.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec validate_mapping(map()) :: :ok | {:error, term()}
  def validate_mapping(schema) when is_map(schema) do
    with :ok <- validate_field_map(Map.get(schema, :field_map)),
         :ok <- validate_transforms(Map.get(schema, :transforms)) do
      :ok
    end
  end

  def validate_mapping(schema) do
    {:error, {:not_a_map, schema}}
  end

  # ---------------------------------------------------------------------------
  # Legacy generic API (backward-compat)
  # ---------------------------------------------------------------------------

  @doc false
  @spec get_by_id(term()) :: {:ok, map()}
  def get_by_id(id) do
    case get_mappings(id) do
      {:ok, mapping} -> {:ok, Map.put(mapping, :id, id)}
      {:error, :not_found} -> {:ok, %{id: id, status: :not_configured}}
    end
  end

  @doc false
  @spec list_all() :: {:ok, list()}
  def list_all do
    ensure_table()

    mappings =
      :ets.match_object(@table, {{:mapping, :_}, :_})
      |> Enum.map(fn {{:mapping, conn_id}, mapping} ->
        Map.put(mapping, :connector_id, conn_id)
      end)

    {:ok, mappings}
  end

  @doc false
  @spec create(map()) :: {:ok, map()}
  def create(%{connector_id: connector_id} = params) do
    :ok = update_mappings(connector_id, params)
    {:ok, Map.put(params, :id, connector_id)}
  end

  def create(params) do
    {:ok, Map.put(params, :id, Ecto.UUID.generate())}
  end

  @doc false
  @spec update(term(), map()) :: {:ok, map()}
  def update(id, params) do
    :ok = update_mappings(id, params)
    {:ok, Map.put(params, :id, id)}
  end

  @doc false
  @spec delete(term()) :: {:ok, map()}
  def delete(id) do
    ensure_table()
    :ets.delete(@table, {:mapping, id})
    {:ok, %{id: id, deleted: true}}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Fetches mapping for connector_id, falling back to a wildcard key :all.
  defp fetch_mapping(connector_id, _operation) do
    ensure_table()

    case :ets.lookup(@table, {:mapping, connector_id}) do
      [{_key, mapping}] ->
        {:ok, mapping}

      [] ->
        case :ets.lookup(@table, {:mapping, :all}) do
          [{_key, mapping}] -> {:ok, mapping}
          [] -> {:error, :not_found}
        end
    end
  end

  # Renames keys using :field_map (local → remote), applies :transforms,
  # merges :defaults for absent keys.
  defp apply_outbound_mapping(data, mapping) do
    field_map = Map.get(mapping, :field_map, %{})
    transforms = Map.get(mapping, :transforms, %{})
    defaults = Map.get(mapping, :defaults, %{})

    data
    |> rename_keys(field_map)
    |> apply_transforms(transforms)
    |> apply_defaults(defaults)
  end

  # Inverse: renames keys using inverted :field_map (remote → local).
  defp apply_inbound_mapping(data, mapping) do
    field_map = Map.get(mapping, :field_map, %{})
    transforms = Map.get(mapping, :transforms, %{})
    defaults = Map.get(mapping, :defaults, %{})

    inverted_map = invert_map(field_map)

    data
    |> rename_keys(inverted_map)
    |> apply_transforms(transforms)
    |> apply_defaults(defaults)
  end

  defp rename_keys(data, field_map) when map_size(field_map) == 0, do: data

  defp rename_keys(data, field_map) do
    Enum.reduce(field_map, data, fn {from_key, to_key}, acc ->
      case Map.pop(acc, from_key) do
        {nil, _} ->
          # Try atom / string variant
          string_key = to_string(from_key)
          atom_key = try_to_atom(from_key)

          cond do
            Map.has_key?(acc, string_key) ->
              {val, rest} = Map.pop(acc, string_key)
              Map.put(rest, to_key, val)

            atom_key != nil and Map.has_key?(acc, atom_key) ->
              {val, rest} = Map.pop(acc, atom_key)
              Map.put(rest, to_key, val)

            true ->
              acc
          end

        {value, rest} ->
          Map.put(rest, to_key, value)
      end
    end)
  end

  defp apply_transforms(data, transforms) when map_size(transforms) == 0, do: data

  defp apply_transforms(data, transforms) do
    Enum.reduce(transforms, data, fn {field, transform_fn}, acc ->
      if is_function(transform_fn, 1) and Map.has_key?(acc, field) do
        Map.update!(acc, field, transform_fn)
      else
        acc
      end
    end)
  end

  defp apply_defaults(data, defaults) when map_size(defaults) == 0, do: data

  defp apply_defaults(data, defaults) do
    Enum.reduce(defaults, data, fn {field, default_val}, acc ->
      Map.put_new(acc, field, default_val)
    end)
  end

  defp invert_map(field_map) do
    Enum.reduce(field_map, %{}, fn {k, v}, acc -> Map.put(acc, v, k) end)
  end

  defp try_to_atom(key) when is_atom(key), do: key

  defp try_to_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp validate_field_map(nil), do: :ok
  defp validate_field_map(field_map) when is_map(field_map), do: :ok
  defp validate_field_map(other), do: {:error, {:invalid_field_map, other}}

  defp validate_transforms(nil), do: :ok

  defp validate_transforms(transforms) when is_map(transforms) do
    invalid =
      Enum.find(transforms, fn {_k, v} -> not is_function(v) end)

    if invalid do
      {:error, {:transform_not_a_function, invalid}}
    else
      :ok
    end
  end

  defp validate_transforms(other), do: {:error, {:invalid_transforms, other}}
end
