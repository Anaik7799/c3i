defmodule Indrajaal.Shared.StatusHistory do
  @moduledoc """
  Shared utilities for managing status history tracking across multiple domains.

  This module extracts common status history functionality used by:
  - Sites.Building (mass: 67)
  - Sites.Area (mass: 67)
  - Sites.Site
  - Sites.Floor
  - Other domains with status tracking

  Following Toyota TPS principles to eliminate duplicate code waste.
  """

  @doc """
  Creates a status history entry change function for Ash changesets.

  ## Parameters
    - `status_field` - The status field name (default: :status)
    - `metadata_field` - The metadata field name (default: :meta_data)
    - `history_key` - The key in metadata for history (default: "status_history")

  ## Returns
  Function that can be used in Ash `change` declarations.

  ## Example
      change Indrajaal.Shared.StatusHistory.create_status_history_change()

      # Or with custom field names
      change Indrajaal.Shared.StatusHistory.create_status_history_change(:state, :details, "state_history")
  """
  def create_status_history_change(
        status_field \\ :status,
        metadata_field \\ :metadata,
        history_key \\ "statushistory"
      ) do
    fn changeset, context ->
      reason = Ash.Changeset.get_argument(changeset, :reason)

      if reason do
        metadata = Ash.Changeset.get_attribute(changeset, metadata_field) || %{}
        status_history = Map.get(metadata, history_key, [])

        entry = %{
          "status" => Ash.Changeset.get_argument(changeset, status_field),
          "reason" => reason,
          "changed_at" => DateTime.utc_now(),
          "changed_by" => get_actor_id(context)
        }

        updated_metadata = Map.put(metadata, history_key, [entry | status_history])
        Ash.Changeset.change_attribute(changeset, metadata_field, updated_metadata)
      else
        changeset
      end
    end
  end

  @doc """
  Creates a standard status update action definition.

  ## Parameters
    - `action_name` - Name of the action (default: :update_status)
    - `status_values` - List of allowed status values
    - `status_field` - The status field name (default: :status)

  ## Returns
  Map with action configuration that can be used in Ash actions.

  ## Example
      update Indrajaal.Shared.StatusHistory.status_update_action(:update_status,
        [:active, :maintenance, :renovation, :closed])
  """
  @spec status_update_action(atom(), list(), atom()) :: map()
  def status_update_action(action_name \\ :update_status, status_values, status_field \\ :status) do
    %{
      name: action_name,
      arguments: [
        {status_field,
         %{
           type: :atom,
           allow_nil?: false,
           constraints: [one_of: status_values]
         }},
        {:reason,
         %{
           type: :string,
           constraints: [max_length: 500]
         }}
      ],
      changes: [
        {:set_attribute, [status_field, {:arg, status_field}]},
        {:change, create_status_history_change(status_field)}
      ]
    }
  end

  @doc """
  Validates status history entry format.

  ## Parameters
    - `entry` - Status history entry to validate

  ## Returns
    - `{:ok, entry}` if valid
    - `{:error, reason}` if invalid
  """
  @spec validate_history_entry(map()) :: {:ok, map()} | {:error, String.t()}
  def validate_history_entry(entry) when is_map(entry) do
    required_fields = ["status", "reason", "changed_at", "changed_by"]

    case Enum.find(required_fields, fn field -> not Map.has_key?(entry, field) end) do
      nil -> {:ok, entry}
      missing_field -> {:error, "Missing required field: #{missing_field}"}
    end
  end

  # @spec validate_history_entry(term()) :: term()
  # def validate_history_entry(_), do: {:error, "Entry must be a map"}
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Gets the most recent status from history.

  ## Parameters
    - `metadata` - The metadata map containing status history
    - `history_key` - The key in metadata for history (default: "status_history")

  ## Returns
    - `{:ok, entry}` if history exists
    - `{:error, :no_history}` if no history found
  """
  @spec get_latest_status(map(), String.t()) :: {:ok, map()} | {:error, atom()}
  def get_latest_status(metadata, history_key \\ "status_history")

  def get_latest_status(metadata, history_key) when is_map(metadata) do
    case Map.get(metadata, history_key, []) do
      [] -> {:error, :no_history}
      [latest | _] -> {:ok, latest}
    end
  end

  # @spec get_latest_status(term(), term()) :: term()
  # def get_latest_status(_, _), do: {:error, :invalid_metadata}
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Gets status history filtered by date range.

  ## Parameters
    - `metadata` - The metadata map containing status history
    - `start_date` - Start of date range (DateTime)
    - `end_date` - End of date range (DateTime)
    - `history_key` - The key in metadata for history (default: "status_history")

  ## Returns
  List of status entries within the date range.
  """
  @spec get_history_by_date_range(map(), DateTime.t(), DateTime.t(), String.t()) :: list()
  def get_history_by_date_range(metadata, start_date, end_date, history_key \\ "status_history")
      when is_map(metadata) do
    metadata
    |> Map.get(history_key, [])
    |> Enum.filter(fn entry ->
      case Map.get(entry, "changed_at") do
        nil ->
          false

        changed_at ->
          case DateTime.from_iso8601(changed_at) do
            {:ok, dt, _} ->
              DateTime.compare(dt, start_date) != :lt and
                DateTime.compare(dt, end_date) != :gt

            _ ->
              false
          end
      end
    end)
  end

  @doc """
  Gets status history for a specific __actor.

  ## Parameters
    - `metadata` - The metadata map containing status history
    - `actor_id` - The actor ID to filter by
    - `history_key` - The key in metadata for history (default: "status_history")

  ## Returns
  List of status entries for the specified __actor.
  """
  @spec get_history_by_actor(map(), any(), String.t()) :: list()
  def get_history_by_actor(metadata, actor_id, history_key \\ "status_history")
      when is_map(metadata) do
    metadata
    |> Map.get(history_key, [])
    |> Enum.filter(fn entry ->
      Map.get(entry, "changed_by") == actor_id
    end)
  end

  @doc """
  Generates a status history summary with statistics.

  ## Parameters
    - `metadata` - The metadata map containing status history
    - `history_key` - The key in metadata for history (default: "status_history")

  ## Returns
  Map with history statistics and summary information.
  """
  @spec generate_history_summary(map(), String.t()) :: map()
  def generate_history_summary(metadata, history_key \\ "status_history")
      when is_map(metadata) do
    history = Map.get(metadata, history_key, [])

    %{
      total_entries: length(history),
      unique_statuses: count_unique_field(history, "status"),
      unique_actors: count_unique_field(history, "changed_by"),
      first_entry: List.last(history),
      latest_entry: List.first(history),
      status_f_requency: get_status_f_requency(history)
    }
  end

  # Helper to count unique field values (SC-CREDO-003 compliance)
  defp count_unique_field(history, field) do
    history
    |> Enum.map(&Map.get(&1, field))
    |> Enum.uniq()
    |> length()
  end

  @doc """
  Cleans up old status history entries beyond a specified limit.

  ## Parameters
    - `metadata` - The metadata map containing status history
    - `limit` - Maximum number of entries to keep (default: 100)
    - `history_key` - The key in metadata for history (default: "status_history")

  ## Returns
  Updated metadata map with trimmed history.
  """
  @spec cleanup_history(map(), integer(), String.t()) :: map()
  def cleanup_history(metadata, limit \\ 100, history_key \\ "status_history")
      when is_map(metadata) and is_integer(limit) and limit > 0 do
    history = Map.get(metadata, history_key, [])
    trimmed_history = Enum.take(history, limit)
    Map.put(metadata, history_key, trimmed_history)
  end

  # Private helper functions

  defp get_actor_id(%{actor: %{id: id}}), do: id
  defp get_actor_id(%{actor: actor}) when is_binary(actor), do: actor
  defp get_actor_id(_), do: "system"

  defp get_status_f_requency(history) do
    history
    |> Enum.map(&Map.get(&1, "status"))
    |> Enum.frequencies()
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
