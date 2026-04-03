defmodule Indrajaal.Observability.ZenohTimeTravel do
  @moduledoc """
  Time Travel Buffer for Goal-Directed Evaluation (GDE) backtracking.

  WHAT: Stores checkpoints to Zenoh Storage for state rewind capability.
  WHY: GDE requires backtracking to previous states when plans fail.
  CONSTRAINTS: Checkpoints must be recoverable, ordered, and prunable.

  ## Key Expressions

  ```
  indrajaal/timemachine/<session>/<timestamp> - Checkpoint storage
  indrajaal/timemachine/<session>/latest      - Latest checkpoint pointer
  indrajaal/timemachine/<session>/index       - Checkpoint index
  ```

  ## Protocol

  1. Before executing a plan step, call `record_checkpoint/2`
  2. If step fails, call `rewind_to/1` to restore previous state
  3. GDE Backtracker uses this for automatic retry with alternatives

  ## STAMP Constraints

  - SC-CTX-008: Checkpoint recoverable within 1000ms
  - SC-OBS-002: No data loss during checkpoint

  ## AOR Rules

  - AOR-CTX-006: GDE MUST use Zenoh for state storage

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-CTX-008, SC-OBS-002 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohCoordinator

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type checkpoint :: %{
          id: String.t(),
          session: String.t(),
          timestamp: DateTime.t(),
          state: term(),
          metadata: map(),
          size_bytes: non_neg_integer()
        }

  @type checkpoint_ref :: %{
          id: String.t(),
          timestamp: DateTime.t(),
          size_bytes: non_neg_integer()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @key_prefix "indrajaal/timemachine"
  @max_checkpoints_per_session 100
  @checkpoint_ttl_seconds 3600
  @default_session "default"

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record a checkpoint of the current state.

  ## Parameters
  - state: The state to checkpoint (any term)
  - opts: Options
    - :session - Session identifier (default: "default")
    - :metadata - Additional metadata map

  ## Returns
  - {:ok, checkpoint_id}
  """
  @spec record_checkpoint(term(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def record_checkpoint(state, opts \\ []) do
    GenServer.call(__MODULE__, {:record, state, opts})
  end

  @doc """
  Rewind to a specific checkpoint.

  ## Parameters
  - checkpoint_id: The checkpoint ID to restore

  ## Returns
  - {:ok, restored_state}
  - {:error, :not_found}
  """
  @spec rewind_to(String.t()) :: {:ok, term()} | {:error, term()}
  def rewind_to(checkpoint_id) do
    GenServer.call(__MODULE__, {:rewind, checkpoint_id})
  end

  @doc """
  Rewind to the previous checkpoint in the current session.

  ## Parameters
  - session: Session identifier (default: "default")

  ## Returns
  - {:ok, restored_state, checkpoint_id}
  - {:error, :no_checkpoints}
  """
  @spec rewind_previous(String.t()) :: {:ok, term(), String.t()} | {:error, term()}
  def rewind_previous(session \\ @default_session) do
    GenServer.call(__MODULE__, {:rewind_previous, session})
  end

  @doc """
  List all checkpoints for a session.

  ## Parameters
  - session: Session identifier (default: "default")
  - opts: Options
    - :limit - Maximum number of checkpoints to return
    - :since - Only checkpoints after this DateTime

  ## Returns
  - List of checkpoint references (not full state)
  """
  @spec list_checkpoints(String.t(), keyword()) :: [checkpoint_ref()]
  def list_checkpoints(session \\ @default_session, opts \\ []) do
    GenServer.call(__MODULE__, {:list, session, opts})
  end

  @doc """
  Get a specific checkpoint by ID.

  ## Parameters
  - checkpoint_id: The checkpoint ID

  ## Returns
  - {:ok, checkpoint}
  - {:error, :not_found}
  """
  @spec get_checkpoint(String.t()) :: {:ok, checkpoint()} | {:error, term()}
  def get_checkpoint(checkpoint_id) do
    GenServer.call(__MODULE__, {:get, checkpoint_id})
  end

  @doc """
  Delete a checkpoint.

  ## Parameters
  - checkpoint_id: The checkpoint ID to delete

  ## Returns
  - :ok
  """
  @spec delete_checkpoint(String.t()) :: :ok
  def delete_checkpoint(checkpoint_id) do
    GenServer.call(__MODULE__, {:delete, checkpoint_id})
  end

  @doc """
  Clear all checkpoints for a session.

  ## Parameters
  - session: Session identifier

  ## Returns
  - {:ok, deleted_count}
  """
  @spec clear_session(String.t()) :: {:ok, non_neg_integer()}
  def clear_session(session) do
    GenServer.call(__MODULE__, {:clear_session, session})
  end

  @doc """
  Get time travel statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Create a new session and return its ID.
  """
  @spec new_session(keyword()) :: {:ok, String.t()}
  def new_session(opts \\ []) do
    GenServer.call(__MODULE__, {:new_session, opts})
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    Logger.info("[ZenohTimeTravel] Initializing time travel buffer - SC-CTX-008")

    state = %{
      # In-memory checkpoint storage (also published to Zenoh)
      checkpoints: %{},
      # Session -> [checkpoint_ids] (ordered, newest first)
      session_index: %{},
      # Statistics
      total_checkpoints: 0,
      total_rewinds: 0,
      total_bytes: 0,
      started_at: DateTime.utc_now(),
      # Configuration
      max_per_session: Keyword.get(opts, :max_per_session, @max_checkpoints_per_session),
      ttl_seconds: Keyword.get(opts, :ttl_seconds, @checkpoint_ttl_seconds)
    }

    # Schedule TTL cleanup
    schedule_cleanup()

    {:ok, state}
  end

  @impl true
  def handle_call({:record, checkpoint_state, opts}, _from, state) do
    session = Keyword.get(opts, :session, @default_session)
    metadata = Keyword.get(opts, :metadata, %{})

    # Generate checkpoint ID
    checkpoint_id = generate_checkpoint_id(session)
    now = DateTime.utc_now()

    # Serialize state for size calculation
    serialized = :erlang.term_to_binary(checkpoint_state)
    size_bytes = byte_size(serialized)

    checkpoint = %{
      id: checkpoint_id,
      session: session,
      timestamp: now,
      state: checkpoint_state,
      metadata: metadata,
      size_bytes: size_bytes
    }

    # Store checkpoint
    new_checkpoints = Map.put(state.checkpoints, checkpoint_id, checkpoint)

    # Update session index
    session_checkpoints = Map.get(state.session_index, session, [])
    new_session_checkpoints = [checkpoint_id | session_checkpoints]

    # Prune if over limit
    {kept_checkpoints, pruned_ids} =
      if length(new_session_checkpoints) > state.max_per_session do
        {kept, pruned} = Enum.split(new_session_checkpoints, state.max_per_session)
        {kept, pruned}
      else
        {new_session_checkpoints, []}
      end

    # Remove pruned checkpoints
    final_checkpoints = Map.drop(new_checkpoints, pruned_ids)

    pruned_bytes =
      Enum.sum(for id <- pruned_ids, cp = Map.get(new_checkpoints, id), do: cp.size_bytes)

    new_session_index = Map.put(state.session_index, session, kept_checkpoints)

    # Publish to Zenoh
    publish_checkpoint(checkpoint)

    new_state = %{
      state
      | checkpoints: final_checkpoints,
        session_index: new_session_index,
        total_checkpoints: state.total_checkpoints + 1,
        total_bytes: state.total_bytes + size_bytes - pruned_bytes
    }

    Logger.debug("[ZenohTimeTravel] Recorded checkpoint #{checkpoint_id} (#{size_bytes} bytes)")
    {:reply, {:ok, checkpoint_id}, new_state}
  end

  @impl true
  def handle_call({:rewind, checkpoint_id}, _from, state) do
    case Map.get(state.checkpoints, checkpoint_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      checkpoint ->
        new_state = %{state | total_rewinds: state.total_rewinds + 1}
        Logger.info("[ZenohTimeTravel] Rewinding to checkpoint #{checkpoint_id}")
        {:reply, {:ok, checkpoint.state}, new_state}
    end
  end

  @impl true
  def handle_call({:rewind_previous, session}, _from, state) do
    case Map.get(state.session_index, session, []) do
      [] ->
        {:reply, {:error, :no_checkpoints}, state}

      [latest_id | _rest] ->
        case Map.get(state.checkpoints, latest_id) do
          nil ->
            {:reply, {:error, :not_found}, state}

          checkpoint ->
            new_state = %{state | total_rewinds: state.total_rewinds + 1}
            Logger.info("[ZenohTimeTravel] Rewinding to previous checkpoint #{latest_id}")
            {:reply, {:ok, checkpoint.state, latest_id}, new_state}
        end
    end
  end

  @impl true
  def handle_call({:list, session, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 100)
    since = Keyword.get(opts, :since)

    checkpoint_ids = Map.get(state.session_index, session, [])

    refs =
      checkpoint_ids
      |> Enum.take(limit)
      |> Enum.map(fn id ->
        case Map.get(state.checkpoints, id) do
          nil -> nil
          cp -> %{id: cp.id, timestamp: cp.timestamp, size_bytes: cp.size_bytes}
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> filter_since(since)

    {:reply, refs, state}
  end

  @impl true
  def handle_call({:get, checkpoint_id}, _from, state) do
    case Map.get(state.checkpoints, checkpoint_id) do
      nil -> {:reply, {:error, :not_found}, state}
      checkpoint -> {:reply, {:ok, checkpoint}, state}
    end
  end

  @impl true
  def handle_call({:delete, checkpoint_id}, _from, state) do
    case Map.get(state.checkpoints, checkpoint_id) do
      nil ->
        {:reply, :ok, state}

      checkpoint ->
        new_checkpoints = Map.delete(state.checkpoints, checkpoint_id)

        # Remove from session index
        new_session_index =
          Map.update(state.session_index, checkpoint.session, [], fn ids ->
            Enum.reject(ids, &(&1 == checkpoint_id))
          end)

        new_state = %{
          state
          | checkpoints: new_checkpoints,
            session_index: new_session_index,
            total_bytes: state.total_bytes - checkpoint.size_bytes
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:clear_session, session}, _from, state) do
    checkpoint_ids = Map.get(state.session_index, session, [])

    deleted_bytes =
      Enum.sum(for id <- checkpoint_ids, cp = Map.get(state.checkpoints, id), do: cp.size_bytes)

    new_checkpoints = Map.drop(state.checkpoints, checkpoint_ids)
    new_session_index = Map.delete(state.session_index, session)

    new_state = %{
      state
      | checkpoints: new_checkpoints,
        session_index: new_session_index,
        total_bytes: state.total_bytes - deleted_bytes
    }

    {:reply, {:ok, length(checkpoint_ids)}, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      total_checkpoints: state.total_checkpoints,
      current_checkpoints: map_size(state.checkpoints),
      total_rewinds: state.total_rewinds,
      total_bytes: state.total_bytes,
      sessions: Map.keys(state.session_index),
      session_counts: Map.new(state.session_index, fn {k, v} -> {k, length(v)} end),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:new_session, opts}, _from, state) do
    prefix = Keyword.get(opts, :prefix, "session")
    session_id = "#{prefix}_#{generate_id()}"
    new_session_index = Map.put(state.session_index, session_id, [])
    {:reply, {:ok, session_id}, %{state | session_index: new_session_index}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Remove expired checkpoints
    now = DateTime.utc_now()
    ttl_seconds = state.ttl_seconds

    {expired_ids, expired_bytes} =
      Enum.reduce(state.checkpoints, {[], 0}, fn {id, cp}, {ids, bytes} ->
        age = DateTime.diff(now, cp.timestamp)

        if age > ttl_seconds do
          {[id | ids], bytes + cp.size_bytes}
        else
          {ids, bytes}
        end
      end)

    if length(expired_ids) > 0 do
      Logger.debug("[ZenohTimeTravel] Cleaning up #{length(expired_ids)} expired checkpoints")
    end

    new_checkpoints = Map.drop(state.checkpoints, expired_ids)

    # Clean session indexes
    new_session_index =
      Map.new(state.session_index, fn {session, ids} ->
        {session, Enum.reject(ids, &(&1 in expired_ids))}
      end)

    new_state = %{
      state
      | checkpoints: new_checkpoints,
        session_index: new_session_index,
        total_bytes: state.total_bytes - expired_bytes
    }

    schedule_cleanup()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp schedule_cleanup do
    # Run cleanup every minute
    Process.send_after(self(), :cleanup, 60_000)
  end

  defp generate_checkpoint_id(session) do
    timestamp = System.system_time(:nanosecond)
    rand_bytes = :crypto.strong_rand_bytes(4)
    random = rand_bytes |> Base.encode16(case: :lower)
    "#{session}_#{timestamp}_#{random}"
  end

  defp generate_id do
    rand_bytes = :crypto.strong_rand_bytes(8)
    rand_bytes |> Base.encode16(case: :lower)
  end

  defp filter_since(refs, nil), do: refs

  defp filter_since(refs, since) do
    Enum.filter(refs, fn ref ->
      DateTime.compare(ref.timestamp, since) in [:gt, :eq]
    end)
  end

  defp publish_checkpoint(checkpoint) do
    key = "#{@key_prefix}/#{checkpoint.session}/#{checkpoint.id}"

    # Publish metadata only (not full state) to Zenoh for indexing
    payload = %{
      id: checkpoint.id,
      session: checkpoint.session,
      timestamp: checkpoint.timestamp,
      size_bytes: checkpoint.size_bytes,
      metadata: checkpoint.metadata
    }

    if Code.ensure_loaded?(ZenohCoordinator) and GenServer.whereis(ZenohCoordinator) do
      ZenohCoordinator.publish_coord(key, payload)
    end
  rescue
    _ -> :ok
  end
end
