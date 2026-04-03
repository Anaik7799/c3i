defmodule Indrajaal.Substrate.L2.BufferPool do
  @moduledoc """
  L2 Buffer Pool — shared message-buffer manager for inter-L1 communication.

  GenServer maintaining a fixed-size pool of logical message buffers.  L1
  operations request a buffer slot via `allocate/1`, use it for inter-module
  handoff, then return it via `release/1`.  The server tracks pool utilisation
  and high-water marks to detect memory pressure.

  ## Allocation Strategy
  - Buffers are identified by an integer handle (0..pool_size-1).
  - A buffer is either :free or {:allocated, owner_pid, size_bytes, monotonic_ts}.
  - `allocate/1` finds the first free buffer; returns `{:error, :pool_exhausted}`
    when all are in use.
  - `release/1` frees the buffer; returns `{:error, :not_allocated}` if already
    free or unknown.

  ## Pressure Metric
  `pressure/0` returns a float ∈ [0.0, 1.0]: allocated / pool_size.

  ## STAMP Constraints
  - SC-S2-001: S2 coordination subsystem constraints — ENFORCED
  - SC-S2-002: Buffer utilisation tracking mandatory — ENFORCED
  - SC-S2-003: High-water mark recording — ENFORCED
  - SC-S2-004: Pressure reporting — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @default_pool_size 32
  @default_buffer_size_bytes 4_096

  @type handle :: non_neg_integer()
  @type buffer_state ::
          :free
          | {:allocated, pid(), pos_integer(), integer()}

  @type pool_map :: %{handle() => buffer_state()}

  @type t :: %{
          pool_size: pos_integer(),
          pool: pool_map(),
          allocated: non_neg_integer(),
          high_water_mark: non_neg_integer(),
          alloc_count: non_neg_integer(),
          release_count: non_neg_integer()
        }

  # ── Client API ──────────────────────────────────────────────────────

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Allocate a buffer of `size_bytes` bytes for the calling process.
  Returns `{:ok, handle}` or `{:error, :pool_exhausted}`.
  """
  @spec allocate(pos_integer()) :: {:ok, handle()} | {:error, :pool_exhausted}
  def allocate(size_bytes \\ @default_buffer_size_bytes)
      when is_integer(size_bytes) and size_bytes > 0 do
    GenServer.call(@name, {:allocate, self(), size_bytes})
  end

  @doc """
  Release a previously allocated buffer by handle.
  Returns `:ok` or `{:error, :not_allocated}`.
  """
  @spec release(handle()) :: :ok | {:error, :not_allocated}
  def release(handle) when is_integer(handle) and handle >= 0 do
    GenServer.call(@name, {:release, handle})
  end

  @doc "Returns pool statistics."
  @spec stats() :: map()
  def stats do
    GenServer.call(@name, :stats)
  end

  @doc "Returns the current pressure as a float ∈ [0.0, 1.0]."
  @spec pressure() :: float()
  def pressure do
    GenServer.call(@name, :pressure)
  end

  # ── GenServer Callbacks ──────────────────────────────────────────────

  @impl true
  def init(opts) do
    pool_size = Keyword.get(opts, :pool_size, @default_pool_size)
    pool = Enum.into(0..(pool_size - 1), %{}, fn i -> {i, :free} end)

    state = %{
      pool_size: pool_size,
      pool: pool,
      allocated: 0,
      high_water_mark: 0,
      alloc_count: 0,
      release_count: 0
    }

    Logger.info("[BUFFER_POOL] started — pool_size=#{pool_size}")
    {:ok, state}
  end

  @impl true
  def handle_call({:allocate, owner_pid, size_bytes}, _from, state) do
    case find_free(state.pool) do
      nil ->
        {:reply, {:error, :pool_exhausted}, state}

      handle ->
        ts = System.monotonic_time(:millisecond)
        pool = Map.put(state.pool, handle, {:allocated, owner_pid, size_bytes, ts})
        new_allocated = state.allocated + 1
        new_hwm = max(state.high_water_mark, new_allocated)

        Process.monitor(owner_pid)

        new_state = %{
          state
          | pool: pool,
            allocated: new_allocated,
            high_water_mark: new_hwm,
            alloc_count: state.alloc_count + 1
        }

        {:reply, {:ok, handle}, new_state}
    end
  end

  @impl true
  def handle_call({:release, handle}, _from, state) do
    case Map.get(state.pool, handle) do
      :free ->
        {:reply, {:error, :not_allocated}, state}

      nil ->
        {:reply, {:error, :not_allocated}, state}

      {:allocated, _pid, _sz, _ts} ->
        pool = Map.put(state.pool, handle, :free)

        new_state = %{
          state
          | pool: pool,
            allocated: max(state.allocated - 1, 0),
            release_count: state.release_count + 1
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      pool_size: state.pool_size,
      allocated: state.allocated,
      free: state.pool_size - state.allocated,
      high_water_mark: state.high_water_mark,
      alloc_count: state.alloc_count,
      release_count: state.release_count,
      pressure: state.allocated / max(state.pool_size, 1)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:pressure, _from, state) do
    p = state.allocated / max(state.pool_size, 1)
    {:reply, p, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Auto-release all buffers owned by the dead process
    pool =
      Enum.into(state.pool, %{}, fn
        {handle, {:allocated, ^pid, _sz, _ts}} -> {handle, :free}
        entry -> entry
      end)

    freed =
      Enum.count(state.pool, fn
        {_h, {:allocated, ^pid, _sz, _ts}} -> true
        _ -> false
      end)

    new_allocated = max(state.allocated - freed, 0)

    if freed > 0 do
      Logger.debug(
        "[BUFFER_POOL] auto-released #{freed} buffers for dead process #{inspect(pid)}"
      )
    end

    {:noreply, %{state | pool: pool, allocated: new_allocated}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ── Private ──────────────────────────────────────────────────────────

  @spec find_free(pool_map()) :: handle() | nil
  defp find_free(pool) do
    Enum.find_value(pool, fn
      {handle, :free} -> handle
      _ -> nil
    end)
  end
end
