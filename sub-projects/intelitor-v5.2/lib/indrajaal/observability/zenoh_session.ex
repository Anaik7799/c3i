defmodule Indrajaal.Observability.ZenohSession do
  @moduledoc """
  GenServer managing Zenoh session lifecycle via Rust NIF.

  ## WHAT
  Maintains a persistent Zenoh session with automatic reconnection,
  health monitoring, and graceful shutdown. Provides the central
  pub/sub interface for all Zenoh communications.

  ## WHY
  - Native protocol provides <1ms latency (SC-ZENOH-INT-001)
  - Session pooling reduces connection overhead
  - Centralized error handling and telemetry
  - Single session per node for resource efficiency

  ## CONSTRAINTS
  - SC-ZENOH-SES-001: Single session per node
  - SC-ZENOH-SES-002: Auto-reconnect within 5s
  - SC-ZENOH-SES-003: Graceful shutdown with drain

  ## Usage
  ```elixir
  # Start session (usually via supervisor)
  {:ok, _pid} = ZenohSession.start_link()

  # Publish message
  :ok = ZenohSession.publish("indrajaal/fractal/l3/alarms", payload)

  # Get session status
  %{status: :connected} = ZenohSession.status()
  ```
  """

  use GenServer
  require Logger

  alias Indrajaal.Native.Zenoh, as: ZenohNIF
  alias Indrajaal.Observability.DirectedTelescopeController
  alias Indrajaal.Observability.DegradedModeCoordinator

  # Configuration defaults
  @reconnect_delay_ms 1_000
  @max_reconnect_attempts 5
  @health_check_interval_ms 10_000
  # Load-shedding threshold: drop :normal messages when queue exceeds this
  @mailbox_high_watermark 100
  # Slow-retry interval after entering :failed state (60s)
  @slow_retry_interval_ms 60_000

  # State structure
  defstruct [
    :session_ref,
    :config,
    :status,
    :subscribers,
    :stats,
    :reconnect_count,
    :last_error
  ]

  @type status :: :disconnected | :connecting | :connected | :reconnecting | :failed
  @type t :: %__MODULE__{
          session_ref: reference() | nil,
          config: map(),
          status: status(),
          subscribers: map(),
          stats: map(),
          reconnect_count: non_neg_integer(),
          last_error: String.t() | nil
        }

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc """
  Start the ZenohSession GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Publish a message to a Zenoh key (synchronous).

  ## Parameters
  - `pid` - Optional PID or registered name (defaults to __MODULE__)
  - `key` - Zenoh key expression (e.g., "indrajaal/fractal/l3/alarms")
  - `payload` - Binary payload to publish

  ## Returns
  - `:ok` - Published successfully
  - `{:error, reason}` - Publication failed
  """
  @spec publish(term(), String.t(), binary()) :: :ok | {:error, term()}
  def publish(pid_or_key, key_or_payload, payload_or_nil \\ nil) do
    {pid, key, payload} =
      if is_pid(pid_or_key) or (is_atom(pid_or_key) and is_binary(key_or_payload)) do
        {pid_or_key, key_or_payload, payload_or_nil}
      else
        {__MODULE__, pid_or_key, key_or_payload}
      end

    GenServer.call(pid, {:publish, key, payload})
  end

  @doc """
  Publish a message asynchronously (fire-and-forget via GenServer.cast).

  Use for telemetry, metrics, and non-critical state publications where
  the caller should never block. Addresses FM-ZUIP-001 (RPN 140).

  ## Parameters
  - `key` - Zenoh key expression
  - `payload` - Binary payload to publish
  - `priority` - Message priority (:critical | :high | :normal), default :normal

  ## Returns
  - `:ok` - Always returns :ok (fire-and-forget)
  """
  @spec publish_async(String.t(), binary(), atom()) :: :ok
  def publish_async(key, payload, priority \\ :normal) do
    GenServer.cast(__MODULE__, {:publish_async, key, payload, priority})
  end

  @doc """
  Publish an emergency message bypassing GenServer entirely.

  Directly calls the NIF (or stub) without going through the GenServer
  mailbox. For safety-critical paths where <5s SLA must be met.
  Addresses FM-ZUIP-002 (RPN 189).

  Always writes log fallback first per SC-ZTEST-008 dual-write pattern.

  ## Parameters
  - `key` - Zenoh key expression
  - `payload` - Binary payload to publish

  ## Returns
  - `:ok` - Published (or logged as fallback)
  - `{:error, reason}` - NIF call failed (but log fallback succeeded)
  """
  @spec publish_emergency(String.t(), binary()) :: :ok | {:error, term()}
  def publish_emergency(key, payload) do
    # SC-ZTEST-008: Log fallback FIRST (guaranteed durability)
    Logger.critical("[ZTEST-CHECKPOINT] topic=#{key} type=emergency payload=#{payload}")

    # Bypass GenServer — get session_ref from ETS or direct NIF call
    try do
      case get_session_ref_direct() do
        {:ok, session_ref} ->
          safe_publish_direct(session_ref, key, payload)

        {:error, _reason} ->
          # Already logged via fallback above
          :ok
      end
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

  @doc """
  Publish a batch of messages efficiently.

  ## Parameters
  - `pid` - Optional PID or registered name
  - `messages` - List of `%{key: String.t(), payload: binary()}`

  ## Returns
  - `{:ok, count}` - Number of messages published
  """
  @spec publish_batch(term(), [map()]) :: {:ok, non_neg_integer()} | {:error, term()}
  def publish_batch(pid_or_messages, messages_or_nil \\ nil) do
    {pid, messages} =
      if is_pid(pid_or_messages) or (is_atom(pid_or_messages) and is_list(messages_or_nil)) do
        {pid_or_messages, messages_or_nil}
      else
        {__MODULE__, pid_or_messages}
      end

    GenServer.call(pid, {:publish_batch, messages})
  end

  @doc """
  Subscribe to a key expression.

  ## Parameters
  - `pid` - Optional PID or registered name
  - `key_expr` - Key expression pattern (e.g., "indrajaal/control/**")
  - `callback_pid` - PID to receive messages

  ## Returns
  - `{:ok, subscriber_ref}` - Subscription created
  """
  @spec subscribe(term(), String.t(), pid()) :: {:ok, reference()} | {:error, term()}
  def subscribe(pid_or_key, key_or_cb \\ nil, cb_or_nil \\ nil) do
    {pid, key_expr, callback_pid} =
      if is_pid(pid_or_key) or (is_atom(pid_or_key) and is_binary(key_or_cb)) do
        {pid_or_key, key_or_cb, cb_or_nil || self()}
      else
        {__MODULE__, pid_or_key, key_or_cb || self()}
      end

    GenServer.call(pid, {:subscribe, key_expr, callback_pid})
  end

  @doc """
  Unsubscribe from a key expression.
  """
  @spec unsubscribe(term(), reference()) :: :ok | {:error, term()}
  def unsubscribe(pid_or_ref, ref_or_nil \\ nil) do
    {pid, ref} =
      if is_pid(pid_or_ref) or (is_atom(pid_or_ref) and is_reference(ref_or_nil)) do
        {pid_or_ref, ref_or_nil}
      else
        {__MODULE__, pid_or_ref}
      end

    GenServer.call(pid, {:unsubscribe, ref})
  end

  @doc """
  Poll for received messages from a subscription (non-blocking).
  """
  @spec poll_messages(term(), reference(), non_neg_integer()) ::
          {:ok, list(map())} | {:error, term()}
  def poll_messages(pid_or_ref, ref_or_max \\ nil, max_or_nil \\ nil) do
    {pid, ref, max} =
      if is_pid(pid_or_ref) or (is_atom(pid_or_ref) and is_reference(ref_or_max)) do
        {pid_or_ref, ref_or_max, max_or_nil || 100}
      else
        {__MODULE__, pid_or_ref, ref_or_max || 100}
      end

    GenServer.call(pid, {:poll_messages, ref, max})
  end

  @doc """
  Query Zenoh storage for matching entries.
  """
  @spec get(term(), String.t(), non_neg_integer()) :: {:ok, list(map())} | {:error, term()}
  def get(pid_or_key, key_or_timeout \\ nil, timeout_or_nil \\ nil) do
    {pid, key_expr, timeout_ms} =
      if is_pid(pid_or_key) or (is_atom(pid_or_key) and is_binary(key_or_timeout)) do
        {pid_or_key, key_or_timeout, timeout_or_nil || 10_000}
      else
        {__MODULE__, pid_or_key, key_or_timeout || 10_000}
      end

    GenServer.call(pid, {:get, key_expr, timeout_ms}, timeout_ms + 1000)
  end

  @doc """
  Get the latest KPI metrics for a specific node.
  Used by Sentinel for biomorphic health assessments.
  """
  @spec get_latest_kpi(String.t()) :: {:ok, map()} | {:error, any()}
  def get_latest_kpi(node_id) do
    key = "indrajaal/metrics/ooda/#{node_id}"

    case get(key, 500) do
      {:ok, [%{value: payload} | _]} ->
        try do
          {:ok, Jason.decode!(payload)}
        rescue
          _ -> {:error, :invalid_payload}
        end

      {:ok, []} ->
        {:error, :no_data}

      error ->
        error
    end
  end

  @doc """
  Check if the session is currently connected.
  """
  @spec connected?(term()) :: boolean()
  def connected?(pid \\ __MODULE__) do
    case status(pid) do
      %{status: :connected} -> true
      _ -> false
    end
  end

  @doc """
  Get session connection status.
  """
  @spec status(term()) :: map()
  def status(pid \\ __MODULE__) do
    GenServer.call(pid, :status)
  end

  @doc """
  Get session statistics.
  """
  @spec stats(term()) :: map()
  def stats(pid \\ __MODULE__) do
    GenServer.call(pid, :stats)
  end

  @doc """
  Force reconnection to Zenoh router.
  """
  @spec reconnect(term()) :: :ok | {:error, term()}
  def reconnect(pid \\ __MODULE__) do
    GenServer.call(pid, :reconnect)
  end

  @doc """
  Get the current Zenoh session reference.

  Used by ZenohBridge for cross-holon database operations.

  ## Returns
  - `{:ok, session_ref}` if currently connected
  - `{:error, :not_connected}` if disconnected, reconnecting, or failed
  """
  @spec get_session(term()) :: {:ok, reference()} | {:error, :not_connected}
  def get_session(pid \\ __MODULE__) do
    GenServer.call(pid, :get_session)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    config = build_config(opts)

    state = %__MODULE__{
      session_ref: nil,
      config: config,
      status: :disconnected,
      subscribers: %{},
      stats: initial_stats(),
      reconnect_count: 0,
      last_error: nil
    }

    # Create ETS cache for emergency direct access (FM-ZUIP-002)
    try do
      :ets.new(:zenoh_session_cache, [:named_table, :public, :set])
    rescue
      ArgumentError -> :ok
    end

    # Attempt initial connection
    send(self(), :connect)

    Logger.info("[ZenohSession] Initialized - SC-ZENOH-SES-001")
    {:ok, state}
  end

  @impl true
  def handle_call({:publish, key, payload}, _from, %{status: :connected} = state) do
    case safe_publish(state.session_ref, key, payload) do
      :ok ->
        new_stats = update_stats(state.stats, :publish)
        {:reply, :ok, %{state | stats: new_stats}}

      {:error, reason} = error ->
        Logger.warning("[ZenohSession] Publish failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  def handle_call({:publish, _key, _payload}, _from, state) do
    {:reply, {:error, :not_connected}, state}
  end

  @impl true
  def handle_call({:publish_batch, messages}, _from, %{status: :connected} = state) do
    case safe_publish_batch(state.session_ref, messages) do
      {:ok, count} = result ->
        new_stats = update_stats(state.stats, :publish, count)
        {:reply, result, %{state | stats: new_stats}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:publish_batch, _messages}, _from, state) do
    {:reply, {:error, :not_connected}, state}
  end

  @impl true
  def handle_call({:subscribe, key_expr, callback_pid}, _from, %{status: :connected} = state) do
    case safe_subscribe(state.session_ref, key_expr, callback_pid) do
      {:ok, subscriber_ref} ->
        new_subscribers =
          Map.put(state.subscribers, subscriber_ref, %{
            key_expr: key_expr,
            callback_pid: callback_pid,
            created_at: DateTime.utc_now()
          })

        {:reply, {:ok, subscriber_ref}, %{state | subscribers: new_subscribers}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:subscribe, _key_expr, _callback_pid}, _from, state) do
    {:reply, {:error, :not_connected}, state}
  end

  @impl true
  def handle_call({:unsubscribe, subscriber_ref}, _from, state) do
    case safe_unsubscribe(subscriber_ref) do
      :ok ->
        new_subscribers = Map.delete(state.subscribers, subscriber_ref)
        {:reply, :ok, %{state | subscribers: new_subscribers}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(
        {:poll_messages, subscriber_ref, max_messages},
        _from,
        %{status: :connected} = state
      ) do
    result = safe_poll_messages(subscriber_ref, max_messages)
    {:reply, result, state}
  end

  def handle_call({:poll_messages, _subscriber_ref, _max_messages}, _from, state) do
    {:reply, {:error, :not_connected}, state}
  end

  @impl true
  def handle_call({:get, key_expr, timeout_ms}, _from, %{status: :connected} = state) do
    result = safe_get(state.session_ref, key_expr, timeout_ms)
    {:reply, result, state}
  end

  def handle_call({:get, _key_expr, _timeout_ms}, _from, state) do
    {:reply, {:error, :not_connected}, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status_map = %{
      status: state.status,
      reconnect_count: state.reconnect_count,
      subscribers_count: map_size(state.subscribers),
      last_error: state.last_error,
      config: %{
        endpoints: state.config.connect,
        mode: state.config.mode
      }
    }

    {:reply, status_map, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_call(:reconnect, _from, state) do
    send(self(), :connect)
    {:reply, :ok, %{state | status: :reconnecting}}
  end

  @impl true
  def handle_call(:get_session, _from, %{status: :connected, session_ref: ref} = state)
      when not is_nil(ref) do
    {:reply, {:ok, ref}, state}
  end

  def handle_call(:get_session, _from, state) do
    {:reply, {:error, :not_connected}, state}
  end

  # ============================================================
  # ASYNC PUBLISH (Fire-and-forget via cast)
  # ============================================================

  @impl true
  def handle_cast({:publish_async, key, payload, priority}, %{status: :connected} = state) do
    # Priority-based load shedding (FM-ZUIP-001, RC-ZUIP-001)
    if priority == :normal and mailbox_overloaded?() do
      Logger.debug("[ZenohSession] Load shedding: dropping normal-priority message for #{key}")
      {:noreply, state}
    else
      case safe_publish(state.session_ref, key, payload) do
        :ok ->
          new_stats = update_stats(state.stats, :publish)
          {:noreply, %{state | stats: new_stats}}

        {:error, reason} ->
          Logger.debug("[ZenohSession] Async publish failed: #{inspect(reason)}")
          {:noreply, state}
      end
    end
  end

  def handle_cast({:publish_async, _key, _payload, _priority}, state) do
    # Not connected — silently drop (log fallback already written by caller)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:emergency_stop, reason, start_time}, state) do
    Logger.critical("[ZenohSession] Emergency stop cast received: #{reason}")
    elapsed = System.monotonic_time(:millisecond) - start_time
    Logger.critical("[ZenohSession] Emergency stop latency: #{elapsed}ms")
    {:noreply, state}
  end

  @impl true
  def handle_info(:connect, state) do
    case do_connect(state.config) do
      {:ok, session_ref} ->
        Logger.info("[ZenohSession] Connected to Zenoh router")
        schedule_health_check()

        # Cache session_ref in ETS for emergency direct access (FM-ZUIP-002)
        cache_session_ref(session_ref)

        # Emit telemetry
        :telemetry.execute(
          [:zenoh, :session, :connected],
          %{count: 1},
          %{endpoints: state.config.connect}
        )

        {:noreply,
         %{
           state
           | session_ref: session_ref,
             status: :connected,
             reconnect_count: 0,
             last_error: nil
         }}

      {:error, reason} ->
        Logger.warning("[ZenohSession] Connection failed: #{inspect(reason)}")
        clear_session_ref_cache()
        schedule_reconnect(state)
        {:noreply, %{state | status: :reconnecting, last_error: inspect(reason)}}
    end
  end

  @impl true
  def handle_info(:reconnect, state) do
    # Check if reconnection is enabled in current context (SC-OBS-DT-006)
    zenoh_enabled = zenoh_reconnect_enabled?()

    cond do
      # Zenoh reconnect disabled in current context (e.g., unit tests)
      not zenoh_enabled ->
        Logger.debug(
          "[ZenohSession] Reconnect disabled in current context - entering silent mode"
        )

        report_degraded(:zenoh_disabled_by_context)
        {:noreply, %{state | status: :failed}}

      # Check if we should retry (respects silence periods from DegradedModeCoordinator)
      not should_retry_zenoh?() ->
        # In silence period - don't log, just reschedule
        schedule_reconnect(state)
        {:noreply, state}

      # Normal reconnection attempt
      state.reconnect_count < @max_reconnect_attempts ->
        record_retry()
        send(self(), :connect)
        {:noreply, %{state | reconnect_count: state.reconnect_count + 1}}

      # Max attempts reached - enter slow-retry mode (RC-ZUIP-006)
      true ->
        Logger.warning("[ZenohSession] Max reconnect attempts reached - entering slow-retry mode")
        report_degraded(:max_attempts_exceeded)

        :telemetry.execute(
          [:zenoh, :session, :failed],
          %{count: 1},
          %{attempts: state.reconnect_count}
        )

        # Schedule slow retry instead of giving up forever
        Process.send_after(self(), :slow_retry, @slow_retry_interval_ms)

        {:noreply, %{state | status: :failed}}
    end
  end

  @impl true
  def handle_info(:health_check, %{status: :connected} = state) do
    # Verify session is still healthy
    case safe_session_status(state.session_ref) do
      {:ok, _status} ->
        schedule_health_check()
        {:noreply, state}

      {:error, reason} ->
        Logger.warning("[ZenohSession] Health check failed: #{inspect(reason)}")
        send(self(), :connect)
        {:noreply, %{state | status: :reconnecting, last_error: inspect(reason)}}
    end
  end

  def handle_info(:health_check, state) do
    # Not connected, skip health check
    {:noreply, state}
  end

  @impl true
  def handle_info(:slow_retry, %{status: :failed} = state) do
    Logger.info(
      "[ZenohSession] Slow retry: attempting reconnection after #{@slow_retry_interval_ms}ms"
    )

    send(self(), :connect)
    {:noreply, %{state | reconnect_count: 0, status: :reconnecting}}
  end

  def handle_info(:slow_retry, state) do
    # Already reconnected or in another state — ignore
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("[ZenohSession] Terminating: #{inspect(reason)}")

    # Clear ETS cache before shutdown
    clear_session_ref_cache()

    if state.session_ref do
      safe_close(state.session_ref)
    end

    :ok
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp build_config(opts) do
    app_config = Application.get_env(:indrajaal, __MODULE__, [])

    %{
      connect: Keyword.get(opts, :connect, Keyword.get(app_config, :connect, ["tcp/zenoh:7447"])),
      mode: Keyword.get(opts, :mode, Keyword.get(app_config, :mode, "client")),
      multicast_scouting: Keyword.get(opts, :multicast_scouting, true)
    }
  end

  defp do_connect(config) do
    # Check if NIF is available
    if Code.ensure_loaded?(ZenohNIF) do
      ZenohNIF.open_session(config)
    else
      # Fallback for when NIF is not compiled
      Logger.warning("[ZenohSession] Zenoh NIF not available, using stub mode")
      {:ok, make_ref()}
    end
  end

  defp safe_publish(session_ref, key, payload) do
    if Code.ensure_loaded?(ZenohNIF) do
      ZenohNIF.publish(session_ref, key, payload)
    else
      # Stub mode - log and succeed
      Logger.debug("[ZenohSession] STUB publish: #{key} (#{byte_size(payload)} bytes)")
      :ok
    end
  rescue
    error -> {:error, error}
  end

  defp safe_publish_batch(session_ref, messages) do
    if Code.ensure_loaded?(ZenohNIF) do
      ZenohNIF.publish_batch(session_ref, messages)
    else
      # Stub mode
      count = length(messages)
      Logger.debug("[ZenohSession] STUB publish_batch: #{count} messages")
      {:ok, count}
    end
  rescue
    error -> {:error, error}
  end

  defp safe_subscribe(session_ref, key_expr, callback_pid) do
    if Code.ensure_loaded?(ZenohNIF) do
      ZenohNIF.subscribe(session_ref, key_expr, callback_pid)
    else
      # Stub mode
      Logger.debug("[ZenohSession] STUB subscribe: #{key_expr}")
      {:ok, make_ref()}
    end
  rescue
    error -> {:error, error}
  end

  defp safe_unsubscribe(subscriber_ref) do
    if Code.ensure_loaded?(ZenohNIF) do
      ZenohNIF.unsubscribe(subscriber_ref)
    else
      :ok
    end
  rescue
    _ -> :ok
  end

  defp safe_poll_messages(subscriber_ref, max_messages) do
    if Code.ensure_loaded?(ZenohNIF) do
      ZenohNIF.poll_messages(subscriber_ref, max_messages)
    else
      {:ok, []}
    end
  rescue
    _ -> {:ok, []}
  end

  defp safe_get(session_ref, key_expr, timeout_ms) do
    if Code.ensure_loaded?(ZenohNIF) do
      ZenohNIF.get_timeout(session_ref, key_expr, timeout_ms)
    else
      {:ok, []}
    end
  rescue
    error -> {:error, error}
  end

  defp safe_session_status(session_ref) do
    if Code.ensure_loaded?(ZenohNIF) do
      case ZenohNIF.session_status(session_ref) do
        # Handle NIF returning map directly (SC-ZENOH-NIF-001)
        %{connected: true} = status -> {:ok, status}
        %{connected: false} = status -> {:error, {:disconnected, status}}
        {:ok, _} = result -> result
        {:error, _} = result -> result
        other -> {:ok, other}
      end
    else
      {:ok, %{connected: true}}
    end
  rescue
    error -> {:error, error}
  end

  defp safe_close(session_ref) do
    if Code.ensure_loaded?(ZenohNIF) do
      ZenohNIF.close_session(session_ref)
    else
      :ok
    end
  rescue
    _ -> :ok
  end

  defp schedule_reconnect(state) do
    # Exponential backoff
    delay = (@reconnect_delay_ms * :math.pow(2, min(state.reconnect_count, 5))) |> round()
    Process.send_after(self(), :reconnect, delay)
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval_ms)
  end

  # ============================================================
  # LOAD SHEDDING (Priority-based, FM-ZUIP-001)
  # ============================================================

  defp mailbox_overloaded? do
    case Process.info(self(), :message_queue_len) do
      {:message_queue_len, len} -> len > @mailbox_high_watermark
      _ -> false
    end
  end

  # ============================================================
  # EMERGENCY DIRECT ACCESS (Bypasses GenServer)
  # ============================================================

  # Get session ref without going through GenServer.call
  # Uses ETS table for lock-free read access
  defp get_session_ref_direct do
    try do
      case :ets.lookup(:zenoh_session_cache, :session_ref) do
        [{:session_ref, ref}] when not is_nil(ref) -> {:ok, ref}
        _ -> {:error, :no_cached_session}
      end
    rescue
      ArgumentError -> {:error, :no_ets_table}
    end
  end

  # Publish directly to NIF without GenServer mediation
  defp safe_publish_direct(session_ref, key, payload) do
    if Code.ensure_loaded?(ZenohNIF) do
      ZenohNIF.publish(session_ref, key, payload)
    else
      Logger.debug("[ZenohSession] STUB emergency publish: #{key}")
      :ok
    end
  rescue
    _ -> :ok
  end

  # Cache session_ref in ETS for emergency direct access
  defp cache_session_ref(session_ref) do
    try do
      :ets.insert(:zenoh_session_cache, {:session_ref, session_ref})
    rescue
      ArgumentError ->
        # Table doesn't exist yet — create it
        :ets.new(:zenoh_session_cache, [:named_table, :public, :set])
        :ets.insert(:zenoh_session_cache, {:session_ref, session_ref})
    end
  end

  # Clear cached session_ref
  defp clear_session_ref_cache do
    try do
      :ets.delete(:zenoh_session_cache, :session_ref)
    rescue
      ArgumentError -> :ok
    end
  end

  defp initial_stats do
    %{
      messages_published: 0,
      messages_received: 0,
      publish_errors: 0,
      started_at: DateTime.utc_now()
    }
  end

  defp update_stats(stats, :publish, count \\ 1) do
    %{stats | messages_published: stats.messages_published + count}
  end

  # ============================================================
  # Context-Aware Helpers (SC-OBS-DT-006)
  # ============================================================

  # Check if Zenoh reconnect is enabled in current context
  defp zenoh_reconnect_enabled? do
    try do
      DirectedTelescopeController.service_enabled?(:zenoh_reconnect)
    rescue
      _ -> true
    catch
      :exit, _ -> true
    end
  end

  # Check if we should retry (respects DegradedModeCoordinator silence periods)
  defp should_retry_zenoh? do
    try do
      DegradedModeCoordinator.should_retry?(:zenoh_router)
    rescue
      _ -> true
    catch
      :exit, _ -> true
    end
  end

  # Record a retry attempt with DegradedModeCoordinator
  defp record_retry do
    try do
      DegradedModeCoordinator.record_retry(:zenoh_router)
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
  end

  # Report degraded status to DegradedModeCoordinator
  defp report_degraded(reason) do
    try do
      DegradedModeCoordinator.report_unavailable(:zenoh_router, reason)
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
  end
end
