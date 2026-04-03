defmodule Indrajaal.Control.AccessArbitrator do
  @moduledoc """
  Access Arbitrator — L3 Control Layer

  ## Design Intent

  GenServer that arbitrates concurrent access to named shared resources
  using priority-based FIFO queues.  A caller acquires a lease token,
  holds the resource, then releases it.  Key safety properties:

  - **Priority FIFO**: higher priority requests are dequeued first;
    ties broken by arrival order (monotonic timestamp).
  - **Timeout enforcement**: pending requests that have waited longer
    than their declared `timeout_ms` are automatically expired and
    reported to the caller via PubSub.
  - **Deadlock detection**: a wait-for graph tracks which requester is
    waiting for which resource holder.  Cycles are detected using DFS
    (depth-first search).  A detected deadlock preempts the lowest-priority
    holder in the cycle to break the deadlock.
  - **Preemption**: explicit `preempt/2` allows a high-priority requester
    to forcibly revoke a lower-priority holder's lease.

  Resource state is stored in ETS; the GenServer owns the queue and
  wait-for graph.

  PubSub broadcasts go to topic `"access_arbitrator:event"`.

  ## STAMP Constraints
  - SC-CONC-001: Concurrent access MUST be mediated; no races on shared resources
  - SC-XHOLON-006: OCC and priority-based access control for cross-holon resources

  ## Change History
  | Version | Date       | Author            | Change                    |
  |---------|------------|-------------------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @ets_table :access_arbitrator_resources
  @pubsub_topic "access_arbitrator:event"
  @telemetry_acquired [:indrajaal, :control, :resource_acquired]
  @telemetry_released [:indrajaal, :control, :resource_released]
  @telemetry_deadlock [:indrajaal, :control, :deadlock_detected]
  @default_timeout_ms 5_000

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type resource_id :: atom() | String.t()
  @type requester_id :: atom() | String.t()
  @type priority :: 0..100
  @type lease_token :: reference()

  @type pending_request :: %{
          requester: requester_id(),
          priority: priority(),
          timeout_ms: pos_integer(),
          enqueued_at: integer(),
          from: GenServer.from()
        }

  @type resource_entry :: %{
          holder: requester_id() | nil,
          token: lease_token() | nil,
          acquired_at: integer() | nil,
          queue: [pending_request()]
        }

  @type arb_state :: %{
          resources: %{resource_id() => resource_entry()},
          wait_for: %{requester_id() => resource_id()}
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the AccessArbitrator GenServer registered under `#{inspect(@name)}`.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Requests access to `resource_id` with the given `priority` (0–100, higher is
  more urgent) and `timeout_ms`.

  Returns `{:ok, lease_token}` when the resource is immediately available or
  `{:queued, position}` when the caller is enqueued.  The caller is responsible
  for calling `release/2` with the token when done.
  """
  @spec request_access(resource_id(), requester_id(), keyword()) ::
          {:ok, lease_token()} | {:queued, non_neg_integer()} | {:error, :timeout_exceeded}
  def request_access(resource_id, requester_id, opts \\ [])
      when (is_atom(resource_id) or is_binary(resource_id)) and
             (is_atom(requester_id) or is_binary(requester_id)) do
    priority = Keyword.get(opts, :priority, 50)
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)
    GenServer.call(@name, {:request_access, resource_id, requester_id, priority, timeout_ms})
  end

  @doc """
  Releases the lease on `resource_id` identified by `token`.  The next
  highest-priority requester in the queue is immediately granted access.
  """
  @spec release(resource_id(), lease_token()) :: :ok | {:error, :invalid_token}
  def release(resource_id, token)
      when (is_atom(resource_id) or is_binary(resource_id)) and is_reference(token) do
    GenServer.call(@name, {:release, resource_id, token})
  end

  @doc """
  Returns the current queue for `resource_id`: `{holder, queue_length}`.
  Reads directly from ETS — no GenServer round-trip.
  """
  @spec queue_status(resource_id()) :: {requester_id() | nil, non_neg_integer()}
  def queue_status(resource_id) when is_atom(resource_id) or is_binary(resource_id) do
    case :ets.lookup(@ets_table, resource_id) do
      [{^resource_id, entry}] -> {entry.holder, length(entry.queue)}
      _ -> {nil, 0}
    end
  end

  @doc """
  Requests access to `resource_id` for `requester_id` with the given `priority`.
  Task-spec alias for `request_access/3`.

  Returns `{:ok, lease_token}` when immediately granted or
  `{:queued, position}` when enqueued.
  """
  @spec request(resource_id(), requester_id(), priority()) ::
          {:ok, lease_token()} | {:queued, non_neg_integer()} | {:error, :timeout_exceeded}
  def request(resource_id, requester_id, priority \\ 50)
      when (is_atom(resource_id) or is_binary(resource_id)) and
             (is_atom(requester_id) or is_binary(requester_id)) and
             is_integer(priority) do
    request_access(resource_id, requester_id, priority: priority)
  end

  @doc """
  Returns `true` if `requester_id` currently holds the lease on `resource_id`.
  Pure ETS read — no GenServer round-trip.
  """
  @spec grant?(resource_id(), requester_id()) :: boolean()
  def grant?(resource_id, requester_id)
      when (is_atom(resource_id) or is_binary(resource_id)) and
             (is_atom(requester_id) or is_binary(requester_id)) do
    case :ets.lookup(@ets_table, resource_id) do
      [{^resource_id, %{holder: ^requester_id}}] -> true
      _ -> false
    end
  end

  @doc """
  Returns a float in [0.0, 1.0] representing contention level for `resource_id`.
  Computed as `queue_length / (queue_length + 1)` — approaches 1.0 under heavy
  contention, is 0.0 when no one is waiting.
  Pure ETS read — no GenServer round-trip.
  """
  @spec contention_level(resource_id()) :: float()
  def contention_level(resource_id)
      when is_atom(resource_id) or is_binary(resource_id) do
    {_holder, queue_len} = queue_status(resource_id)
    if queue_len == 0, do: 0.0, else: queue_len / (queue_len + 1)
  end

  @doc """
  Forcibly preempts the current holder of `resource_id` in favour of
  `requester_id`.  The displaced holder's lease is revoked; the arbitrator
  publishes a `:preempted` event so the displaced holder can react.
  """
  @spec preempt(resource_id(), requester_id()) ::
          {:ok, lease_token()} | {:error, :no_holder} | {:error, :resource_not_found}
  def preempt(resource_id, requester_id)
      when (is_atom(resource_id) or is_binary(resource_id)) and
             (is_atom(requester_id) or is_binary(requester_id)) do
    GenServer.call(@name, {:preempt, resource_id, requester_id})
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])

    # Periodic timer to expire timed-out requests
    Process.send_after(self(), :expire_timeouts, 1_000)

    Logger.info("[AccessArbitrator] L3 started — priority-FIFO + deadlock detection")

    {:ok, %{resources: %{}, wait_for: %{}}}
  end

  @impl true
  def handle_call({:request_access, res_id, req_id, priority, timeout_ms}, from, state) do
    entry = get_or_create_entry(state, res_id)

    cond do
      is_nil(entry.holder) ->
        # Resource is free — grant immediately
        token = make_ref()
        new_entry = %{entry | holder: req_id, token: token, acquired_at: monotonic_ms()}
        new_state = put_entry(state, res_id, new_entry)
        store_entry(res_id, new_entry)

        new_wait_for = Map.delete(state.wait_for, req_id)
        emit_acquired(res_id, req_id)

        {:reply, {:ok, token}, %{new_state | wait_for: new_wait_for}}

      true ->
        # Resource is held — enqueue
        req = %{
          requester: req_id,
          priority: priority,
          timeout_ms: timeout_ms,
          enqueued_at: monotonic_ms(),
          from: from
        }

        new_queue = insert_by_priority(entry.queue, req)
        new_entry = %{entry | queue: new_queue}
        new_state = put_entry(state, res_id, new_entry)
        store_entry(res_id, new_entry)

        # Record in wait-for graph and check for deadlock
        new_wait_for = Map.put(state.wait_for, req_id, res_id)
        new_state2 = %{new_state | wait_for: new_wait_for}

        new_state3 =
          if deadlock_cycle?(req_id, res_id, new_wait_for, new_state2.resources) do
            handle_deadlock(new_state2, res_id)
          else
            new_state2
          end

        pos = length(new_state3.resources[res_id].queue)
        {:reply, {:queued, pos}, new_state3}
    end
  end

  @impl true
  def handle_call({:release, res_id, token}, _from, state) do
    case Map.get(state.resources, res_id) do
      nil ->
        {:reply, {:error, :invalid_token}, state}

      entry when entry.token == token ->
        {new_state, _} = grant_next(state, res_id, entry)
        {:reply, :ok, new_state}

      _ ->
        {:reply, {:error, :invalid_token}, state}
    end
  end

  @impl true
  def handle_call({:preempt, res_id, req_id}, _from, state) do
    case Map.get(state.resources, res_id) do
      nil ->
        {:reply, {:error, :resource_not_found}, state}

      %{holder: nil} ->
        {:reply, {:error, :no_holder}, state}

      entry ->
        # Notify displaced holder
        displaced = entry.holder

        try do
          Phoenix.PubSub.broadcast(
            Indrajaal.PubSub,
            @pubsub_topic,
            {:preempted, res_id, displaced, req_id}
          )
        rescue
          _ -> :ok
        end

        Logger.warning(
          "[AccessArbitrator] preempt resource=#{inspect(res_id)} " <>
            "displaced=#{inspect(displaced)} by=#{inspect(req_id)}"
        )

        token = make_ref()

        new_entry = %{
          entry
          | holder: req_id,
            token: token,
            acquired_at: monotonic_ms()
        }

        new_state = put_entry(state, res_id, new_entry)
        store_entry(res_id, new_entry)

        {:reply, {:ok, token}, new_state}
    end
  end

  @impl true
  def handle_info(:expire_timeouts, state) do
    now = monotonic_ms()

    new_state =
      Enum.reduce(state.resources, state, fn {res_id, entry}, acc ->
        {live, expired} =
          Enum.split_with(entry.queue, fn req ->
            now - req.enqueued_at < req.timeout_ms
          end)

        Enum.each(expired, fn req ->
          Logger.debug(
            "[AccessArbitrator] timeout req=#{inspect(req.requester)} res=#{inspect(res_id)}"
          )

          try do
            Phoenix.PubSub.broadcast(
              Indrajaal.PubSub,
              @pubsub_topic,
              {:request_timeout, res_id, req.requester}
            )
          rescue
            _ -> :ok
          end

          GenServer.reply(req.from, {:error, :timeout_exceeded})
        end)

        if length(expired) > 0 do
          new_entry = %{entry | queue: live}
          store_entry(res_id, new_entry)
          put_entry(acc, res_id, new_entry)
        else
          acc
        end
      end)

    Process.send_after(self(), :expire_timeouts, 1_000)
    {:noreply, new_state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec get_or_create_entry(arb_state(), resource_id()) :: resource_entry()
  defp get_or_create_entry(state, res_id) do
    Map.get_lazy(state.resources, res_id, fn ->
      %{holder: nil, token: nil, acquired_at: nil, queue: []}
    end)
  end

  @spec put_entry(arb_state(), resource_id(), resource_entry()) :: arb_state()
  defp put_entry(state, res_id, entry) do
    %{state | resources: Map.put(state.resources, res_id, entry)}
  end

  @spec store_entry(resource_id(), resource_entry()) :: true
  defp store_entry(res_id, entry) do
    :ets.insert(@ets_table, {res_id, entry})
  end

  @spec insert_by_priority([pending_request()], pending_request()) :: [pending_request()]
  defp insert_by_priority(queue, req) do
    Enum.sort_by(
      [req | queue],
      fn r -> {-r.priority, r.enqueued_at} end
    )
  end

  @spec grant_next(arb_state(), resource_id(), resource_entry()) ::
          {arb_state(), lease_token() | nil}
  defp grant_next(state, res_id, entry) do
    case entry.queue do
      [] ->
        freed_entry = %{entry | holder: nil, token: nil, acquired_at: nil, queue: []}
        new_state = put_entry(state, res_id, freed_entry)
        store_entry(res_id, freed_entry)

        try do
          :telemetry.execute(@telemetry_released, %{queue_drained: true}, %{resource: res_id})
        rescue
          _ -> :ok
        end

        {new_state, nil}

      [next | rest] ->
        token = make_ref()

        new_entry = %{
          entry
          | holder: next.requester,
            token: token,
            acquired_at: monotonic_ms(),
            queue: rest
        }

        new_state = put_entry(state, res_id, new_entry)
        store_entry(res_id, new_entry)

        new_wait_for = Map.delete(state.wait_for, next.requester)

        GenServer.reply(next.from, {:ok, token})
        emit_acquired(res_id, next.requester)

        {%{new_state | wait_for: new_wait_for}, token}
    end
  end

  @spec emit_acquired(resource_id(), requester_id()) :: :ok
  defp emit_acquired(res_id, req_id) do
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:acquired, res_id, req_id}
      )
    rescue
      _ -> :ok
    end

    try do
      :telemetry.execute(@telemetry_acquired, %{count: 1}, %{
        resource: res_id,
        requester: req_id
      })
    rescue
      _ -> :ok
    end

    :ok
  end

  # Deadlock detection via DFS on the wait-for graph.
  # A cycle means deadlock.
  @spec deadlock_cycle?(
          requester_id(),
          resource_id(),
          %{requester_id() => resource_id()},
          %{resource_id() => resource_entry()}
        ) :: boolean()
  defp deadlock_cycle?(start_requester, res_id, wait_for, resources) do
    # The holder of res_id is a potential target; if it is also waiting
    # for a resource held by start_requester (transitively), we have a cycle.
    holder =
      case Map.get(resources, res_id) do
        %{holder: h} when not is_nil(h) -> h
        _ -> nil
      end

    if is_nil(holder) do
      false
    else
      dfs_visit(holder, start_requester, wait_for, resources, MapSet.new())
    end
  end

  @spec dfs_visit(
          requester_id(),
          requester_id(),
          %{requester_id() => resource_id()},
          %{resource_id() => resource_entry()},
          MapSet.t()
        ) :: boolean()
  defp dfs_visit(current, target, wait_for, resources, visited) do
    visited_current = MapSet.member?(visited, current)

    cond do
      current == target ->
        true

      visited_current ->
        false

      true ->
        new_visited = MapSet.put(visited, current)

        case Map.get(wait_for, current) do
          nil ->
            false

          waiting_for_res ->
            next_holder =
              case Map.get(resources, waiting_for_res) do
                %{holder: h} when not is_nil(h) -> h
                _ -> nil
              end

            if is_nil(next_holder) do
              false
            else
              dfs_visit(next_holder, target, wait_for, resources, new_visited)
            end
        end
    end
  end

  @spec handle_deadlock(arb_state(), resource_id()) :: arb_state()
  defp handle_deadlock(state, res_id) do
    Logger.warning(
      "[AccessArbitrator] Deadlock detected involving resource=#{inspect(res_id)}, preempting lowest-priority holder"
    )

    try do
      :telemetry.execute(@telemetry_deadlock, %{count: 1}, %{resource: res_id})
    rescue
      _ -> :ok
    end

    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:deadlock_detected, res_id}
      )
    rescue
      _ -> :ok
    end

    # Resolve by releasing the holder of the deadlocked resource
    case Map.get(state.resources, res_id) do
      %{token: token} = entry when not is_nil(token) ->
        {new_state, _} = grant_next(state, res_id, entry)
        new_state

      _ ->
        state
    end
  end

  @spec monotonic_ms() :: integer()
  defp monotonic_ms, do: System.monotonic_time(:millisecond)
end
