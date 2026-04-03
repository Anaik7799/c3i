defmodule Indrajaal.Test.ZenohTestCoordinator do
  @moduledoc """
  Zenoh-style pub/sub coordinator for test process communication.

  WHAT: Provides synchronous and asynchronous messaging between test processes
        using Zenoh key expression patterns for topic matching.
  WHY: Enables coordinated multi-process test scenarios without race conditions.
  CONSTRAINTS: Test-only module, not for production use.

  ## Usage

      # Start coordinator (typically in setup)
      {:ok, coordinator} = ZenohTestCoordinator.start_link()

      # Subscribe to patterns
      ZenohTestCoordinator.subscribe(coordinator, "test/process/**/ready")

      # Publish messages (async)
      ZenohTestCoordinator.publish(coordinator, "test/process/worker_1/ready", %{pid: self()})

      # Request-reply (sync)
      {:ok, reply} = ZenohTestCoordinator.request(coordinator, "test/service/status", %{}, timeout: 5000)

      # Wait for specific message pattern (sync)
      {:ok, msg} = ZenohTestCoordinator.await(coordinator, "test/**/complete", timeout: 10_000)
  """

  use GenServer

  alias Indrajaal.Observability.Fractal.KeyExpression

  @default_timeout 5_000

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc """
  Start a new test coordinator.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc """
  Subscribe to a key expression pattern.
  Returns subscription ID for later unsubscribe.
  """
  @spec subscribe(GenServer.server(), String.t(), keyword()) ::
          {:ok, reference()} | {:error, term()}
  def subscribe(coordinator, pattern, opts \\ []) do
    GenServer.call(coordinator, {:subscribe, pattern, self(), opts})
  end

  @doc """
  Unsubscribe from a pattern.
  """
  @spec unsubscribe(GenServer.server(), reference()) :: :ok
  def unsubscribe(coordinator, subscription_ref) do
    GenServer.call(coordinator, {:unsubscribe, subscription_ref})
  end

  @doc """
  Publish a message asynchronously to all matching subscribers.
  """
  @spec publish(GenServer.server(), String.t(), term()) :: :ok
  def publish(coordinator, key, payload) do
    GenServer.cast(coordinator, {:publish, key, payload, self()})
  end

  @doc """
  Publish and wait for acknowledgment from at least one subscriber.
  """
  @spec publish_sync(GenServer.server(), String.t(), term(), keyword()) ::
          :ok | {:error, :no_subscribers} | {:error, :timeout}
  def publish_sync(coordinator, key, payload, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    GenServer.call(coordinator, {:publish_sync, key, payload}, timeout)
  end

  @doc """
  Send a request and wait for a reply (request-reply pattern).
  """
  @spec request(GenServer.server(), String.t(), term(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def request(coordinator, key, payload, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    GenServer.call(coordinator, {:request, key, payload, self()}, timeout)
  end

  @doc """
  Reply to a received request.
  """
  @spec reply(GenServer.server(), reference(), term()) :: :ok
  def reply(coordinator, request_ref, response) do
    GenServer.cast(coordinator, {:reply, request_ref, response})
  end

  @doc """
  Wait for a message matching the pattern.
  """
  @spec await(GenServer.server(), String.t(), keyword()) :: {:ok, term()} | {:error, :timeout}
  def await(coordinator, pattern, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    # Create temporary subscription
    {:ok, sub_ref} = subscribe(coordinator, pattern)

    try do
      receive do
        {:zenoh_message, ^sub_ref, _key, payload} ->
          {:ok, payload}
      after
        timeout ->
          {:error, :timeout}
      end
    after
      unsubscribe(coordinator, sub_ref)
    end
  end

  @doc """
  Await multiple messages until a condition is met.
  """
  @spec await_until(GenServer.server(), String.t(), (list() -> boolean()), keyword()) ::
          {:ok, list()} | {:error, :timeout}
  def await_until(coordinator, pattern, condition_fn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    {:ok, sub_ref} = subscribe(coordinator, pattern)

    try do
      collect_until(sub_ref, condition_fn, [], timeout)
    after
      unsubscribe(coordinator, sub_ref)
    end
  end

  @doc """
  Barrier synchronization - wait for N processes to reach a point.
  """
  @spec barrier(GenServer.server(), String.t(), pos_integer(), keyword()) ::
          :ok | {:error, :timeout}
  def barrier(coordinator, barrier_name, count, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    barrier_key = "test/barrier/#{barrier_name}"

    # Announce arrival at barrier
    publish(coordinator, barrier_key, %{pid: self(), arrived: true})

    # Wait for count arrivals
    result =
      await_until(
        coordinator,
        barrier_key,
        fn msgs -> length(msgs) >= count end,
        timeout: timeout
      )

    case result do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Get coordinator statistics.
  """
  @spec stats(GenServer.server()) :: map()
  def stats(coordinator) do
    GenServer.call(coordinator, :stats)
  end

  # ============================================================
  # MOCK SUPPORT (SC-DBPROXY-001)
  # ============================================================

  @doc """
  Set a mock response for a given key.
  Used for testing Zenoh request/response patterns.
  """
  @spec set_mock(GenServer.server(), String.t(), term()) :: :ok
  def set_mock(coordinator, key, response) do
    GenServer.call(coordinator, {:set_mock, key, response})
  end

  @doc """
  Get a mock response for a given key.
  Returns nil if no mock is set.
  """
  @spec get_mock(GenServer.server(), String.t()) :: term() | nil
  def get_mock(coordinator, key) do
    GenServer.call(coordinator, {:get_mock, key})
  end

  @doc """
  Reset all mocks and captured requests.
  """
  @spec reset(GenServer.server()) :: :ok
  def reset(coordinator) do
    GenServer.call(coordinator, :reset_mocks)
  end

  @doc """
  Start capturing requests for a test ID.
  """
  @spec start_capture(GenServer.server(), term()) :: :ok
  def start_capture(coordinator, test_id) do
    GenServer.call(coordinator, {:start_capture, test_id})
  end

  @doc """
  Stop capturing and return captured request.
  """
  @spec stop_capture(GenServer.server(), term()) :: term() | nil
  def stop_capture(coordinator, test_id) do
    GenServer.call(coordinator, {:stop_capture, test_id})
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    state = %{
      # ref => {pid, compiled_pattern, opts}
      subscriptions: %{},
      # ref => {from, timeout_ref}
      pending_requests: %{},
      message_count: 0,
      subscription_count: 0,
      # Mock support (SC-DBPROXY-001)
      mocks: %{},
      captures: %{},
      captured_requests: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:subscribe, pattern, pid, opts}, _from, state) do
    case KeyExpression.compile(pattern) do
      {:ok, compiled} ->
        ref = make_ref()
        Process.monitor(pid)

        subscriptions = Map.put(state.subscriptions, ref, {pid, compiled, opts})

        new_state = %{
          state
          | subscriptions: subscriptions,
            subscription_count: state.subscription_count + 1
        }

        {:reply, {:ok, ref}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:unsubscribe, ref}, _from, state) do
    subscriptions = Map.delete(state.subscriptions, ref)
    {:reply, :ok, %{state | subscriptions: subscriptions}}
  end

  def handle_call({:publish_sync, key, payload}, _from, state) do
    matching = find_matching_subscribers(state.subscriptions, key)

    if Enum.empty?(matching) do
      {:reply, {:error, :no_subscribers}, state}
    else
      # Send to all matching subscribers
      for {ref, {pid, _compiled, _opts}} <- matching do
        send(pid, {:zenoh_message, ref, key, payload})
      end

      # Reply immediately after sending
      {:reply, :ok, %{state | message_count: state.message_count + 1}}
    end
  end

  def handle_call({:request, key, payload, sender_pid}, from, state) do
    matching = find_matching_subscribers(state.subscriptions, key)

    case matching do
      [] ->
        {:reply, {:error, :no_responders}, state}

      [{_ref, {pid, _compiled, _opts}} | _rest] ->
        # Send request to first matching subscriber
        request_ref = make_ref()
        send(pid, {:zenoh_request, request_ref, key, payload, sender_pid})

        # Store pending request
        pending = Map.put(state.pending_requests, request_ref, from)
        {:noreply, %{state | pending_requests: pending, message_count: state.message_count + 1}}
    end
  end

  def handle_call(:stats, _from, state) do
    stats = %{
      subscriptions: map_size(state.subscriptions),
      pending_requests: map_size(state.pending_requests),
      messages_processed: state.message_count,
      total_subscriptions: state.subscription_count
    }

    {:reply, stats, state}
  end

  # Mock support handlers (SC-DBPROXY-001)
  def handle_call({:set_mock, key, response}, _from, state) do
    mocks = Map.put(state.mocks, key, response)
    {:reply, :ok, %{state | mocks: mocks}}
  end

  def handle_call({:get_mock, key}, _from, state) do
    response = Map.get(state.mocks, key)
    {:reply, response, state}
  end

  def handle_call(:reset_mocks, _from, state) do
    {:reply, :ok, %{state | mocks: %{}, captures: %{}, captured_requests: %{}}}
  end

  def handle_call({:start_capture, test_id}, _from, state) do
    captures = Map.put(state.captures, test_id, true)
    {:reply, :ok, %{state | captures: captures}}
  end

  def handle_call({:stop_capture, test_id}, _from, state) do
    captures = Map.delete(state.captures, test_id)
    {captured, captured_requests} = Map.pop(state.captured_requests, test_id)
    {:reply, captured, %{state | captures: captures, captured_requests: captured_requests}}
  end

  @impl true
  def handle_cast({:publish, key, payload, _sender}, state) do
    matching = find_matching_subscribers(state.subscriptions, key)

    for {ref, {pid, _compiled, _opts}} <- matching do
      send(pid, {:zenoh_message, ref, key, payload})
    end

    {:noreply, %{state | message_count: state.message_count + 1}}
  end

  def handle_cast({:reply, request_ref, response}, state) do
    case Map.pop(state.pending_requests, request_ref) do
      {nil, _} ->
        # Request already timed out or doesn't exist
        {:noreply, state}

      {from, pending} ->
        GenServer.reply(from, {:ok, response})
        {:noreply, %{state | pending_requests: pending}}
    end
  end

  @impl true
  def handle_info({:DOWN, _monitor_ref, :process, pid, _reason}, state) do
    # Remove all subscriptions for dead process
    subscriptions =
      state.subscriptions
      |> Enum.reject(fn {_ref, {sub_pid, _compiled, _opts}} -> sub_pid == pid end)
      |> Map.new()

    {:noreply, %{state | subscriptions: subscriptions}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp find_matching_subscribers(subscriptions, key) do
    Enum.filter(subscriptions, fn {_ref, {_pid, compiled, _opts}} ->
      KeyExpression.matches?(compiled, key)
    end)
  end

  defp collect_until(sub_ref, condition_fn, acc, remaining_timeout) when remaining_timeout > 0 do
    start = System.monotonic_time(:millisecond)

    receive do
      {:zenoh_message, ^sub_ref, _key, payload} ->
        new_acc = [payload | acc]

        if condition_fn.(new_acc) do
          {:ok, Enum.reverse(new_acc)}
        else
          elapsed = System.monotonic_time(:millisecond) - start
          collect_until(sub_ref, condition_fn, new_acc, remaining_timeout - elapsed)
        end
    after
      remaining_timeout ->
        {:error, :timeout}
    end
  end

  defp collect_until(_sub_ref, _condition_fn, _acc, _remaining_timeout) do
    {:error, :timeout}
  end
end
