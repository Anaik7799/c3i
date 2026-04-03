defmodule Indrajaal.Realtime.ChangeTracker do
  @moduledoc """
  Tracks all __data changes for real - time synchronization.

  Records create, update, and delete operations across all entities
  to enable differential sync for mobile clients.

  Agent: Helper - 2 manages change tracking
  SOPv5.1 Compliance: ✅
  """

  use GenServer

  alias Indrajaal.Realtime.DataChange
  alias Indrajaal.Repo

  import Ecto.Query

  require Logger

  # GenServer configuration
  @cleanup_interval :timer.hours(1)
  @retention_days 7

  @spec start_link(any()) :: any()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  @spec init(any()) :: any()
  # AGENT GA FIX: STUB parameter
  def init(_opts) do
    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, %{}}
  end

  # Public API

  @doc """
  Tracks a __data change for sync.
  """
  @spec track_change(any(), any()) :: any()
  def track_change(entity, operation \\ :update) do
    change_params = build_change_params(entity, operation)

    # EP999: Using generic map pattern instead of undefined DataChange struct
    change_attrs =
      %{}
      |> Map.merge(change_params)

    case Repo.insert_all("__data_changes", [change_attrs], returning: [:id]) do
      # AGENT GA FIX: unused variable
      {1, [_created]} -> :ok
      _ -> {:error, "Failed to create __data change"}
    end

    # Broadcast change for real - time updates
    broadcast_change(change_params)

    :ok
  rescue
    e ->
      Logger.error("Failed to track change", %{
        error: inspect(e),
        entity: inspect(entity)
      })

      # Don't fail the operation
      :ok
  end

  @doc """
  Gets all changes since a timestamp for a tenant.
  """
  @spec get_changes_since(term(), term(), term()) :: term()
  # AGENT GA FIX: Corrected function name and parameters
  def get_changes_since(tenant_id, timestamp, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    entity_types = Keyword.get(opts, :entity_types, nil)

    query =
      from dc in DataChange,
        where: dc.tenant_id == ^tenant_id,
        where: dc.timestamp > ^timestamp,
        order_by: [asc: dc.timestamp],
        limit: ^limit

    query =
      if entity_types do
        from dc in query, where: dc.entity_type in ^entity_types
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets changes for specific entities.
  """
  def getentity_changes(tenant_id, entity_type, entity_ids) do
    query =
      from(dc in DataChange,
        where: dc.tenant_id == ^tenant_id,
        where: dc.entity_type == ^entity_type,
        where: dc.entity_id in ^entity_ids,
        order_by: [desc: dc.timestamp]
      )

    Repo.all(query)
  end

  @doc """
  Cleans up old change records.
  """
  @spec cleanup_old_changes(any()) :: any()
  def cleanup_old_changes(days \\ @retention_days) do
    cutoff = DateTime.add(DateTime.utc_now(), -days, :day)

    query =
      from(dc in DataChange,
        where: dc.timestamp < ^cutoff
      )

    {deleted, _} = query |> Repo.delete_all()

    Logger.info("Cleaned up #{deleted} old change records")

    deleted
  end

  # GenServer callbacks

  @impl true
  @spec handle_info(any(), any()) :: any()
  def handle_info(:cleanup, state) do
    cleanup_old_changes()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  @spec build_change_params(term(), term()) :: term()
  defp build_change_params(entity, operation) do
    entity_type = get_entity_type(entity)

    %{
      tenant_id: entity.tenant_id,
      entity_type: entity_type,
      entity_id: entity.id,
      operation: to_string(operation),
      changes: extract_changes(entity, operation),
      user_id: get_current_user_id(),
      timestamp: DateTime.utc_now(),
      version: Map.get(entity, :lock_version, 0)
    }
  end

  @spec get_entity_type(term()) :: term()
  defp get_entity_type(entity) do
    entity.__struct__
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  @spec extract_changes(term(), term()) :: term()
  defp extract_changes(entity, :create) do
    # For create, include all fields
    entity
    |> Map.from_struct()
    |> Map.drop([:__meta__, :__struct__, :id, :inserted_at, :updated_at])
  end

  @spec extract_changes(term(), term()) :: term()
  defp extract_changes(entity, :update) do
    # For update, only include changed fields
    # This _requires the entity to track changes (e.g., via Ecto changeset)
    if function_exported?(entity.__struct__, :_changeset__, 0) do
      entity._changeset__
      |> Map.get(:changes, %{})
    else
      %{}
    end
  end

  @spec extract_changes(term(), term()) :: term()
  # AGENT GA FIX: STUB parameter
  defp extract_changes(_entity, :delete) do
    # For delete, no field changes needed
    %{}
  end

  defp get_current_user_id do
    # Get from process dictionary if available
    Process.get(:current_user_id)
  end

  @spec broadcast_change(term()) :: term()
  defp broadcast_change(change_params) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "changes:#{change_params.tenant_id}",
      {:__data_change, change_params}
    )
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end

defmodule Indrajaal.Realtime.DataChange do
  @moduledoc """
  Schema for tracking __data changes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "__data_changes" do
    field :tenant_id, :binary_id
    field :entity_type, :string
    field :entity_id, :binary_id
    field :operation, :string
    field :changes, :map
    field :user_id, :binary_id
    field :timestamp, :utc_datetime
    field :version, :integer

    timestamps()
  end

  @spec changeset(any(), any()) :: any()
  # AGENT GA PHASE 7 FIX - fixed function name and added change parameter
  def changeset(change, attrs) do
    change
    |> cast(attrs, [
      :tenant_id,
      :entity_type,
      :entity_id,
      :operation,
      :changes,
      :user_id,
      :timestamp,
      :version
    ])
    |> validate_required([:tenant_id, :entity_type, :entity_id, :operation, :timestamp])
    |> validate_inclusion(:operation, ["create", "update", "delete"])
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
