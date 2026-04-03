defmodule Indrajaal.Observability.StateTracker do
  @moduledoc """
  A persistent, CRDT-like state tracker for the Indrajaal system, powered by CubDB.
  It captures the full history of system inputs, outputs, and errors.
  """
  use GenServer

  @db_path "data/cubdb/system_state"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Ensure data directory exists
    File.mkdir_p!(Path.dirname(@db_path))

    {:ok, db} = CubDB.start_link(@db_path)
    {:ok, %{db: db}}
  end

  # --- Public API ---

  @doc """
  Records a log entry into the persistent store.
  """
  def record_log(level, message, metadata) do
    GenServer.cast(__MODULE__, {:record, level, message, metadata})
  end

  @doc """
  Retrieves the complete history of the system state.
  """
  def get_history do
    GenServer.call(__MODULE__, :get_history)
  end

  # --- Callbacks ---

  @impl true
  def handle_cast({:record, level, message, metadata}, state) do
    # Use a monotonic timestamp as the key to ensure ordering
    key = System.system_time(:microsecond)

    entry = %{
      level: level,
      message: message,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    }

    CubDB.put(state.db, key, entry)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_history, _from, state) do
    # Retrieve all entries
    selected = CubDB.select(state.db)
    entries = selected |> Enum.map(fn {_k, v} -> v end)
    {:reply, entries, state}
  end
end
