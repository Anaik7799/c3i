defmodule Indrajaal.Core.Holon.Registry do
  @moduledoc """
  Holon Registry - Discovery and Lookup for v20.0.0

  Provides holon discovery and registration:
  1. Register holons by ID and layer
  2. Lookup holons by ID, layer, or parent
  3. Track holon lifecycle (start, stop, restart)
  4. Provide parent-child relationship queries

  ## STAMP Constraints
  - SC-REG-001: Registration MUST be idempotent
  - SC-REG-002: Lookup MUST complete within 10ms
  - SC-REG-003: Registry MUST survive holon failures
  - SC-REG-004: Orphan holons MUST be detected

  ## Implementation
  Uses ETS for fast in-memory lookups with process registry backing.
  """

  use GenServer
  require Logger

  alias Indrajaal.Core.Holon

  @table_name :holon_registry
  @by_layer_table :holon_registry_by_layer
  @by_parent_table :holon_registry_by_parent

  @type registration :: %{
          id: Holon.holon_id(),
          pid: pid(),
          layer: Holon.layer(),
          parent: Holon.holon_id() | nil,
          registered_at: DateTime.t()
        }

  # Client API

  @doc """
  Starts the registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a holon in the registry.
  """
  @spec register(Holon.holon_id(), pid(), Holon.layer(), Holon.holon_id() | nil) ::
          :ok | {:error, :already_registered}
  def register(holon_id, pid, layer, parent \\ nil) do
    GenServer.call(__MODULE__, {:register, holon_id, pid, layer, parent})
  end

  @doc """
  Unregisters a holon from the registry.
  """
  @spec unregister(Holon.holon_id()) :: :ok
  def unregister(holon_id) do
    GenServer.call(__MODULE__, {:unregister, holon_id})
  end

  @doc """
  Looks up a holon by ID.
  """
  @spec lookup(Holon.holon_id()) :: {:ok, registration()} | {:error, :not_found}
  def lookup(holon_id) do
    case :ets.lookup(@table_name, holon_id) do
      [{^holon_id, registration}] -> {:ok, registration}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Returns the pid of a holon by ID.
  """
  @spec whereis(Holon.holon_id()) :: pid() | nil
  def whereis(holon_id) do
    case lookup(holon_id) do
      {:ok, %{pid: pid}} -> pid
      {:error, :not_found} -> nil
    end
  end

  @doc """
  Lists all holons at a specific layer.
  """
  @spec list_by_layer(Holon.layer()) :: [registration()]
  def list_by_layer(layer) do
    case :ets.lookup(@by_layer_table, layer) do
      [{^layer, holon_ids}] ->
        holon_ids
        |> Enum.map(&lookup/1)
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, reg} -> reg end)

      [] ->
        []
    end
  end

  @doc """
  Lists all children of a parent holon.
  """
  @spec list_children(Holon.holon_id()) :: [registration()]
  def list_children(parent_id) do
    case :ets.lookup(@by_parent_table, parent_id) do
      [{^parent_id, child_ids}] ->
        child_ids
        |> Enum.map(&lookup/1)
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, reg} -> reg end)

      [] ->
        []
    end
  end

  @doc """
  Returns the count of registered holons.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table_name, :size)
  end

  @doc """
  Returns the count of holons at a specific layer.
  """
  @spec count_by_layer(Holon.layer()) :: non_neg_integer()
  def count_by_layer(layer) do
    length(list_by_layer(layer))
  end

  @doc """
  Returns all registered holon IDs.
  """
  @spec all_ids() :: [Holon.holon_id()]
  def all_ids do
    :ets.select(@table_name, [{{:"$1", :_}, [], [:"$1"]}])
  end

  @doc """
  Returns orphan holons (holons with non-existent parents).
  """
  @spec find_orphans() :: [Holon.holon_id()]
  def find_orphans do
    all_ids()
    |> Enum.filter(fn id ->
      case lookup(id) do
        {:ok, %{parent: nil}} -> false
        {:ok, %{parent: parent_id}} -> whereis(parent_id) == nil
        _ -> false
      end
    end)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS tables
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@by_layer_table, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@by_parent_table, [:named_table, :set, :public, read_concurrency: true])

    Logger.info("[HolonRegistry] Started")
    {:ok, %{monitors: %{}}}
  end

  @impl true
  def handle_call({:register, holon_id, pid, layer, parent}, _from, state) do
    case :ets.lookup(@table_name, holon_id) do
      [] ->
        registration = %{
          id: holon_id,
          pid: pid,
          layer: layer,
          parent: parent,
          registered_at: DateTime.utc_now()
        }

        # Insert into main table
        :ets.insert(@table_name, {holon_id, registration})

        # Update layer index
        update_layer_index(layer, holon_id, :add)

        # Update parent index
        if parent do
          update_parent_index(parent, holon_id, :add)
        end

        # Monitor the process
        ref = Process.monitor(pid)
        new_monitors = Map.put(state.monitors, ref, holon_id)

        Logger.debug("Registered holon #{holon_id} at layer #{layer}")
        {:reply, :ok, %{state | monitors: new_monitors}}

      _ ->
        {:reply, {:error, :already_registered}, state}
    end
  end

  @impl true
  def handle_call({:unregister, holon_id}, _from, state) do
    case :ets.lookup(@table_name, holon_id) do
      [{^holon_id, %{layer: layer, parent: parent}}] ->
        # Remove from main table
        :ets.delete(@table_name, holon_id)

        # Update layer index
        update_layer_index(layer, holon_id, :remove)

        # Update parent index
        if parent do
          update_parent_index(parent, holon_id, :remove)
        end

        Logger.debug("Unregistered holon #{holon_id}")
        {:reply, :ok, state}

      [] ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case Map.pop(state.monitors, ref) do
      {nil, monitors} ->
        {:noreply, %{state | monitors: monitors}}

      {holon_id, monitors} ->
        # Auto-unregister on process death
        case :ets.lookup(@table_name, holon_id) do
          [{^holon_id, %{layer: layer, parent: parent}}] ->
            :ets.delete(@table_name, holon_id)
            update_layer_index(layer, holon_id, :remove)

            if parent do
              update_parent_index(parent, holon_id, :remove)
            end

            Logger.warning("Holon #{holon_id} died, auto-unregistered")

          [] ->
            :ok
        end

        {:noreply, %{state | monitors: monitors}}
    end
  end

  # Private helpers

  defp update_layer_index(layer, holon_id, :add) do
    case :ets.lookup(@by_layer_table, layer) do
      [{^layer, ids}] ->
        :ets.insert(@by_layer_table, {layer, [holon_id | ids]})

      [] ->
        :ets.insert(@by_layer_table, {layer, [holon_id]})
    end
  end

  defp update_layer_index(layer, holon_id, :remove) do
    case :ets.lookup(@by_layer_table, layer) do
      [{^layer, ids}] ->
        :ets.insert(@by_layer_table, {layer, List.delete(ids, holon_id)})

      [] ->
        :ok
    end
  end

  defp update_parent_index(parent_id, child_id, :add) do
    case :ets.lookup(@by_parent_table, parent_id) do
      [{^parent_id, ids}] ->
        :ets.insert(@by_parent_table, {parent_id, [child_id | ids]})

      [] ->
        :ets.insert(@by_parent_table, {parent_id, [child_id]})
    end
  end

  defp update_parent_index(parent_id, child_id, :remove) do
    case :ets.lookup(@by_parent_table, parent_id) do
      [{^parent_id, ids}] ->
        :ets.insert(@by_parent_table, {parent_id, List.delete(ids, child_id)})

      [] ->
        :ok
    end
  end
end
