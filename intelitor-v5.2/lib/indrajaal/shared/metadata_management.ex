defmodule Indrajaal.Shared.MetadataManagement do
  @moduledoc """
  Shared utilities for managing metadata across multiple domains.

  This module extracts common metadata functionality used by:
  - Multiple domains that manage metadata fields
  - Resources with inspection data,
    readings, logs, and other structured metadata
  - Status tracking, communication logs, and audit trails

  Following Toyota TPS principles to eliminate duplicate code waste.
  """

  alias Ash.Changeset

  @doc """
  Creates a metadata update change function for Ash changesets.

  ## Parameters
    - `metadata_field` - The metadata field name (default: :metadata)
    - `key` - The key in metadata to update
    - `value_source` - How to get the value (:argument, :attribute, :static)
    - `value_identifier` - The argument / attribute name or static value

  ## Returns
  Function that can be used in Ash `change` declarations.

  ## Example
      change Indrajaal.Shared.MetadataManagement.create_metadata_update(:metadata,
        "last_update", :argument, :timestamp)
  """
  @spec createmetadata_update(atom(), String.t(), atom(), any()) :: (Changeset.t(), map() ->
                                                                       Changeset.t())
  def createmetadata_update(
        metadata_field,
        key,
        value_source,
        value_identifier
      ) do
    fn changeset, context ->
      metadata = Changeset.get_attribute(changeset, metadata_field) || %{}

      value =
        case value_source do
          :argument -> Changeset.get_argument(changeset, value_identifier)
          :attribute -> Changeset.get_attribute(changeset, value_identifier)
          :static -> value_identifier
          :timestamp -> DateTime.utc_now()
          :actor -> get_actor_id(context)
        end

      updated_metadata = Map.put(metadata, key, value)
      Changeset.change_attribute(changeset, metadata_field, updated_metadata)
    end
  end

  @doc """
  Creates a metadata list append change function.

  ## Parameters
    - `metadata_field` - The metadata field name (default: :metadata)
    - `list_key` - The key in metadata for the list
    - `entry_data` - Map of entry data sources
    - `max_entries` - Maximum entries to keep (default: 1000)

  ## Returns
  Function that appends new entries to a metadata list.

  ## Example
      change Indrajaal.Shared.MetadataManagement.create_metadata_list_append(
        :metadata,

        "readings",

        %{
          "value" => {:argument,
      :reading_value},
          "timestamp" => :timestamp,
          "operator" => :actor
        }
      )
  """
  @spec createmetadata_list_append(atom(), String.t(), map(), integer()) :: (Changeset.t(),
                                                                             map() ->
                                                                               Changeset.t())
  def createmetadata_list_append(
        metadata_field,
        list_key,
        entry_data,
        max_entries \\ 1000
      ) do
    fn changeset, context ->
      metadata = get_current_metadata(changeset, metadata_field)
      current_list = Map.get(metadata, list_key, [])

      new_entry = build_metadata_entry(entry_data, changeset, context)
      updated_list = append_and_trim_list(new_entry, current_list, max_entries)
      updated_metadata = Map.put(metadata, list_key, updated_list)

      Changeset.force_change_attribute(changeset, metadata_field, updated_metadata)
    end
  end

  @doc """
  Creates an inspection data change function.

  ## Parameters
    - `metadata_field` - The metadata field name (default: :metadata)
    - `inspection_key` - The key for inspection data (default: "inspection_data")

  ## Returns
  Function that adds inspection results to metadata.
  """
  @spec createinspection_change(atom(), String.t()) :: (Changeset.t(), map() -> Changeset.t())
  def createinspection_change(
        metadata_field,
        inspection_key \\ "inspectiondata"
      ) do
    fn changeset, context ->
      passed? = Changeset.get_argument(changeset, :passed?)
      inspector = Changeset.get_argument(changeset, :inspector)

      inspection_data = %{
        "inspector" => inspector,
        "inspected_at" => DateTime.utc_now(),
        "passed" => passed?,
        "inspected_by" => get_actor_id(context)
      }

      metadata = Changeset.get_attribute(changeset, metadata_field) || %{}

      # Add to inspection history
      inspection_history = Map.get(metadata, "inspection_history", [])
      updated_history = [inspection_data | inspection_history]

      updated_metadata =
        metadata
        |> Map.put(inspection_key, inspection_data)
        |> Map.put("inspection_history", updated_history)

      Changeset.force_change_attribute(changeset, metadata_field, updated_metadata)
    end
  end

  @doc """
  Creates a communication log change function.

  ## Parameters
    - `metadata_field` - The metadata field name (default: :metadata)
    - `log_key` - The key for communication log (default: "communication_log")

  ## Returns
  Function that adds communication entries to metadata.
  """
  @spec createcommunication_log_change(atom(), String.t()) :: (Changeset.t(), map() ->
                                                                 Changeset.t())
  def createcommunication_log_change(
        metadata_field,
        log_key \\ "communicationlog"
      ) do
    fn changeset, context ->
      message = Changeset.get_argument(changeset, :message)

      communication_type =
        Changeset.get_argument(
          changeset,
          :communication_type
        )

      new_entry = %{
        "message" => message,
        "type" => communication_type,
        "timestamp" => DateTime.utc_now(),
        "sender" => get_actor_id(context)
      }

      metadata = Changeset.get_attribute(changeset, metadata_field) || %{}
      log = Map.get(metadata, log_key, [])

      updated_metadata = Map.put(metadata, log_key, [new_entry | log])
      Changeset.force_change_attribute(changeset, metadata_field, updated_metadata)
    end
  end

  @doc """
  Retrieves a specific metadata value by key path.

  ## Parameters
    - `metadata` - The metadata map
    - `key_path` - String key or list of keys for nested access
    - `default` - Default value if key not found

  ## Returns
  The value at the key path or default.

  ## Example
      value = get_metadata_value(resource.metadata, "inspectiondata.passed", false)
      nested = get_metadata_value(resource.metadata,
        ["status_history", 0, "status"], nil)
  """
  @spec get_metadata_value(map() | nil, String.t() | list(), any()) :: any()
  def get_metadata_value(metadata, key_path, default \\ nil)
  @spec get_metadata_value(term(), term(), term()) :: term()
  # def get_metadata_value(nil, key_path, default), do: default
  # Claude Agent: EP-076 - Unreachable function clause commented
  @spec get_metadata_value(term(), term(), term()) :: term()
  def get_metadata_value(metadata, key_path, default)
      when is_binary(key_path) do
    keys = String.split(key_path, ".")
    get_nested_value(metadata, keys, default)
  end

  @spec get_metadata_value(term(), term(), term()) :: term()
  def get_metadata_value(metadata, key_path, default) when is_list(key_path) do
    get_nested_value(metadata, key_path, default)
  end

  @doc """
  Sets a metadata value by key path.

  ## Parameters
    - `metadata` - The metadata map
    - `key_path` - String key or list of keys for nested access
    - `value` - Value to set

  ## Returns
  Updated metadata map.
  """
  @spec set_metadata_value(map(), String.t() | list(), any()) :: map()
  def set_metadata_value(metadata, key_path, value) when is_binary(key_path) do
    keys = String.split(key_path, ".")
    set_nested_value(metadata, keys, value)
  end

  @spec set_metadata_value(term(), term(), term()) :: term()
  def set_metadata_value(metadata, key_path, value) when is_list(key_path) do
    set_nested_value(metadata, key_path, value)
  end

  @doc """
  Filters metadata list by criteria.

  ## Parameters
    - `metadata` - The metadata map
    - `list_key` - Key for the list in metadata
    - `filter_fn` - Function to filter list items

  ## Returns
  Filtered list of metadata entries.
  """
  @spec filter_metadata_list(map(), String.t(), (any() -> boolean())) :: list()
  def filter_metadata_list(metadata, list_key, filter_fn) do
    metadata
    |> Map.get(list_key, [])
    |> Enum.filter(filter_fn)
  end

  @doc """
  Gets the latest entry from a metadata list.

  ## Parameters
    - `metadata` - The metadata map
    - `list_key` - Key for the list in metadata

  ## Returns
    - `{:ok, entry}` if list has entries
    - `{:error, :empty}` if list is empty
  """
  @spec get_latest_metadata_entry(
          map(),
          String.t()
        ) :: {:ok, any()} | {:error, :empty}
  @spec get_latest_metadata_entry(term(), term()) :: term()
  def get_latest_metadata_entry(metadata, list_key) do
    case Map.get(metadata, list_key, []) do
      [latest | _] -> {:ok, latest}
      [] -> {:error, :empty}
    end
  end

  @doc """
  Validates metadata structure against a schema.

  ## Parameters
    - `metadata` - The metadata to validate
    - `schema` - Map defining _required keys and their types

  ## Returns
    - `{:ok, metadata}` if valid
    - `{:error, violations}` if invalid
  """
  @spec validate_metadata_schema(
          map(),
          map()
        ) :: {:ok, map()} | {:error, list()}
  @spec validate_metadata_schema(term(), term()) :: term()
  def validate_metadata_schema(metadata, schema) do
    violations =
      Enum.reduce(
        schema,
        [],
        fn {key, expected_type}, acc ->
          case Map.get(
                 metadata,
                 key
               ) do
            nil ->
              [{:missing_key, key} | acc]

            value ->
              if validate_type(value, expected_type) do
                acc
              else
                [{:invalid_type, key, expected_type, typeof(value)} | acc]
              end
          end
        end
      )

    case violations do
      [] -> {:ok, metadata}
      violations -> {:error, violations}
    end
  end

  @doc """
  Merges metadata maps with conflict resolution.

  ## Parameters
    - `base_metadata` - Base metadata map
    - `new_metadata` - New metadata to merge
    - `strategy` - Merge strategy (:replace, :append_lists, :keep_latest)

  ## Returns
  Merged metadata map.
  """
  @spec merge_metadata(map(), map(), atom()) :: map()
  def merge_metadata(base_metadata, new_metadata, strategy \\ :replace) do
    case strategy do
      :replace ->
        merge_replace_strategy(base_metadata, new_metadata)

      :append_lists ->
        merge_append_lists_strategy(base_metadata, new_metadata)

      :keep_latest ->
        merge_keep_latest_strategy(base_metadata, new_metadata)
    end
  end

  # Merge strategy helper functions
  defp merge_replace_strategy(base_metadata, new_metadata) do
    Map.merge(base_metadata, new_metadata)
  end

  defp merge_append_lists_strategy(base_metadata, new_metadata) do
    Map.merge(
      base_metadata,
      new_metadata,
      fn _key, v1, v2 ->
        case {v1, v2} do
          {list1, list2} when is_list(list1) and is_list(list2) -> list1 ++ list2
          {_, v2} -> v2
        end
      end
    )
  end

  defp merge_keep_latest_strategy(base_metadata, new_metadata) do
    Map.merge(
      base_metadata,
      new_metadata,
      fn key, v1, v2 ->
        if timestamp_field?(key) and is_binary(v1) and is_binary(v2) do
          choose_latest_timestamp(v1, v2)
        else
          v2
        end
      end
    )
  end

  defp timestamp_field?(key), do: String.ends_with?(key, "at")

  defp choose_latest_timestamp(v1, v2) do
    case {DateTime.from_iso8601(v1), DateTime.from_iso8601(v2)} do
      {{:ok, dt1, _}, {:ok, dt2, _}} ->
        if DateTime.compare(dt1, dt2) == :gt, do: v1, else: v2

      _ ->
        v2
    end
  end

  # Private helper functions

  defp get_actor_id(%{actor: %{id: id}}), do: id
  defp get_actor_id(%{actor: actor}) when is_map(actor), do: Map.get(actor, :id)
  defp get_actor_id(_), do: nil

  defp get_nested_value(map, [], _default), do: map

  defp get_nested_value(map, [key | rest], default) when is_map(map) do
    case Map.get(map, key) do
      nil -> default
      value -> get_nested_value(value, rest, default)
    end
  end

  defp get_nested_value(_value, _keys, default), do: default

  defp set_nested_value(map, [key], value) do
    Map.put(map, key, value)
  end

  defp set_nested_value(map, [key | rest], value) do
    nested_map = Map.get(map, key, %{})
    updated_nested = set_nested_value(nested_map, rest, value)
    Map.put(map, key, updated_nested)
  end

  defp validate_type(value, :string), do: is_binary(value)
  defp validate_type(value, :integer), do: is_integer(value)
  defp validate_type(value, :float), do: is_float(value)
  defp validate_type(value, :boolean), do: is_boolean(value)
  defp validate_type(value, :map), do: is_map(value)
  defp validate_type(value, :list), do: is_list(value)
  defp validate_type(_value, _type), do: true

  defp typeof(value) when is_binary(value), do: :string
  defp typeof(value) when is_integer(value), do: :integer
  defp typeof(value) when is_float(value), do: :float
  defp typeof(value) when is_boolean(value), do: :boolean
  defp typeof(value) when is_map(value), do: :map
  defp typeof(value) when is_list(value), do: :list
  defp typeof(_value), do: :unknown

  # Helper functions for metadata list append functionality
  defp get_current_metadata(changeset, metadata_field) do
    Changeset.get_attribute(changeset, metadata_field) || %{}
  end

  defp build_metadata_entry(entry_data, changeset, context) do
    Enum.reduce(
      entry_data,
      %{},
      fn {key, source}, acc ->
        value =
          extract_value_from_source(
            source,
            changeset,
            context
          )

        Map.put(acc, key, value)
      end
    )
  end

  defp extract_value_from_source(source, changeset, context) do
    case source do
      {:argument, arg} -> Changeset.get_argument(changeset, arg)
      {:attribute, attr} -> Changeset.get_attribute(changeset, attr)
      {:static, val} -> val
      :timestamp -> DateTime.utc_now()
      :actor -> get_actor_id(context)
      val when is_binary(val) or is_number(val) -> val
    end
  end

  defp append_and_trim_list(new_entry, current_list, max_entries) do
    [new_entry | current_list]
    |> Enum.take(max_entries)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
