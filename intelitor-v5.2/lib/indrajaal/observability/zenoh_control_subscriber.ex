defmodule Indrajaal.Observability.ZenohControlSubscriber do
  @moduledoc """
  Zenoh-based control subscriber for CEPAF command processing.

  WHAT: Subscribes to control commands from CEPAF dashboard via Zenoh.
  WHY: SC-ZENOH-004 requires command acknowledgment and request-reply patterns.
  CONSTRAINTS: Non-blocking, command validation, audit logging.

  ## Control Patterns
  - indrajaal/control/refresh - Force KPI refresh
  - indrajaal/control/agent/* - Agent-specific commands
  - indrajaal/control/mode - Dashboard mode changes
  """

  use GenServer
  require Logger

  @control_prefix "indrajaal/control"

  defstruct [
    :coordinator,
    :subscriptions,
    :command_count,
    :last_command,
    :handlers
  ]

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Starts the ZenohControlSubscriber GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers a handler function for a specific control pattern.

  ## Parameters
  - `pid` - Optional PID or registered name
  - `pattern` - Zenoh key expression pattern
  - `handler_fn` - Function with arity 2: fn(key, payload) -> result
  """
  @spec register_handler(term(), String.t(), (String.t(), term() -> term())) :: :ok
  def register_handler(pid_or_pattern, pattern_or_fn \\ nil, handler_fn_or_nil \\ nil) do
    {pid, pattern, handler_fn} =
      if is_pid(pid_or_pattern) or (is_atom(pid_or_pattern) and is_binary(pattern_or_fn)) do
        {pid_or_pattern, pattern_or_fn, handler_fn_or_nil}
      else
        {__MODULE__, pid_or_pattern, pattern_or_fn}
      end

    GenServer.call(pid, {:register_handler, pattern, handler_fn})
  end

  @doc """
  Unregisters a handler for the given pattern.
  """
  @spec unregister_handler(term(), String.t()) :: :ok
  def unregister_handler(pid_or_pattern, pattern_or_nil \\ nil) do
    {pid, pattern} =
      if is_pid(pid_or_pattern) or (is_atom(pid_or_pattern) and is_binary(pattern_or_nil)) do
        {pid_or_pattern, pattern_or_nil}
      else
        {__MODULE__, pid_or_pattern}
      end

    GenServer.call(pid, {:unregister_handler, pattern})
  end

  @doc """
  Returns statistics about processed commands.
  """
  @spec get_stats(term()) :: map()
  def get_stats(pid \\ __MODULE__), do: GenServer.call(pid, :get_stats)

  @doc """
  Manually triggers processing of a command (useful for testing).
  """
  @spec process_command_sync(term(), String.t(), term()) :: term()
  def process_command_sync(pid_or_key, key_or_payload \\ nil, payload_or_nil \\ nil) do
    {pid, key, payload} =
      if is_pid(pid_or_key) or (is_atom(pid_or_key) and is_binary(key_or_payload)) do
        {pid_or_key, key_or_payload, payload_or_nil}
      else
        {__MODULE__, pid_or_key, key_or_payload}
      end

    GenServer.call(pid, {:process_command_sync, key, payload})
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    # Use provided coordinator or start/find one
    coordinator = Keyword.get(opts, :coordinator) || start_zenoh_coordinator()

    subscriptions =
      if coordinator do
        setup_subscriptions(coordinator)
      else
        []
      end

    state = %__MODULE__{
      coordinator: coordinator,
      subscriptions: subscriptions,
      command_count: 0,
      last_command: nil,
      handlers: %{}
    }

    Logger.info("[ZenohControlSubscriber] Started - SC-ZENOH-004 active")
    {:ok, state}
  end

  @impl true
  def handle_call({:register_handler, pattern, handler_fn}, _from, state) do
    handlers = Map.put(state.handlers, pattern, handler_fn)
    Logger.debug("[ZenohControlSubscriber] Registered handler for: #{pattern}")
    {:reply, :ok, %{state | handlers: handlers}}
  end

  def handle_call({:unregister_handler, pattern}, _from, state) do
    handlers = Map.delete(state.handlers, pattern)
    Logger.debug("[ZenohControlSubscriber] Unregistered handler for: #{pattern}")
    {:reply, :ok, %{state | handlers: handlers}}
  end

  def handle_call(:get_stats, _from, state) do
    stats = %{
      command_count: state.command_count,
      last_command: state.last_command,
      handlers: Map.keys(state.handlers),
      subscriptions_active: length(state.subscriptions)
    }

    {:reply, stats, state}
  end

  def handle_call({:process_command_sync, key, payload}, _from, state) do
    result = do_process_command(key, payload, state.handlers)

    new_state = %{
      state
      | command_count: state.command_count + 1,
        last_command: %{key: key, payload: payload, result: result, at: DateTime.utc_now()}
    }

    {:reply, result, new_state}
  end

  @impl true
  def handle_info({:zenoh_message, _ref, key, payload}, state) do
    Logger.debug("[ZenohControlSubscriber] Received: #{key}")

    # Process command
    result = do_process_command(key, payload, state.handlers)

    # Send acknowledgment if coordinator is available
    if state.coordinator do
      ack_key = "#{key}/ack"

      zenoh_publish(state.coordinator, ack_key, %{
        status: result,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end

    new_state = %{
      state
      | command_count: state.command_count + 1,
        last_command: %{key: key, payload: payload, result: result, at: DateTime.utc_now()}
    }

    {:noreply, new_state}
  end

  def handle_info({:zenoh_request, req_ref, key, payload, _sender}, state) do
    Logger.debug("[ZenohControlSubscriber] Request received: #{key}")
    result = do_process_command(key, payload, state.handlers)

    if state.coordinator do
      zenoh_reply(state.coordinator, req_ref, %{status: result})
    end

    new_state = %{
      state
      | command_count: state.command_count + 1,
        last_command: %{key: key, payload: payload, result: result, at: DateTime.utc_now()}
    }

    {:noreply, new_state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  # Runtime module reference to avoid compile-time warnings for test-only module
  defp zenoh_coordinator_module, do: Module.concat([Indrajaal, Test, ZenohTestCoordinator])

  defp start_zenoh_coordinator do
    module = zenoh_coordinator_module()

    if Code.ensure_loaded?(module) do
      case module.start_link([]) do
        {:ok, pid} -> pid
        _ -> nil
      end
    else
      nil
    end
  end

  defp setup_subscriptions(coordinator) do
    patterns = [
      "#{@control_prefix}/refresh",
      "#{@control_prefix}/agent/**",
      "#{@control_prefix}/mode",
      "#{@control_prefix}/logging"
    ]

    patterns
    |> Enum.map(fn pattern ->
      case zenoh_subscribe(coordinator, pattern) do
        {:ok, ref} ->
          Logger.debug("[ZenohControlSubscriber] Subscribed to: #{pattern}")
          ref

        {:error, reason} ->
          Logger.warning(
            "[ZenohControlSubscriber] Failed to subscribe to #{pattern}: #{inspect(reason)}"
          )

          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp do_process_command(key, payload, handlers) do
    case find_handler(key, handlers) do
      nil -> handle_default(key, payload)
      handler -> safe_execute_handler(handler, key, payload)
    end
  end

  defp safe_execute_handler(handler, key, payload) do
    handler.(key, payload)
  rescue
    e ->
      Logger.error("[ZenohControlSubscriber] Handler error for #{key}: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  end

  defp find_handler(key, handlers) do
    Enum.find_value(handlers, fn {pattern, handler} ->
      if matches_pattern?(key, pattern), do: handler
    end)
  end

  defp matches_pattern?(key, pattern) do
    # Convert Zenoh pattern to regex
    # ** matches any path segments (including /)
    # * matches single path segment (excluding /)
    pattern_regex =
      pattern
      |> Regex.escape()
      |> String.replace("\\*\\*", ".*")
      |> String.replace("\\*", "[^/]*")
      |> then(&"^#{&1}$")
      |> Regex.compile!()

    Regex.match?(pattern_regex, key)
  end

  defp handle_default("indrajaal/control/refresh", _payload) do
    # Trigger KPI refresh if publisher is available
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohKpiPublisher) do
      Indrajaal.Observability.ZenohKpiPublisher.publish_now()
    else
      Logger.debug("[ZenohControlSubscriber] KPI refresh requested (publisher not available)")
    end

    :ok
  end

  defp handle_default("indrajaal/control/mode", %{"mode" => mode}) when is_binary(mode) do
    Logger.info("[ZenohControlSubscriber] Mode change requested: #{mode}")
    :ok
  end

  defp handle_default("indrajaal/control/mode", payload) do
    Logger.warning("[ZenohControlSubscriber] Invalid mode payload: #{inspect(payload)}")
    {:error, :invalid_mode_payload}
  end

  defp handle_default("indrajaal/control/logging", %{"level" => level})
       when level in ["debug", "info", "warn", "error"] do
    Logger.info("[ZenohControlSubscriber] Changing log level to: #{level}")
    Logger.configure(level: String.to_atom(level))
    :ok
  end

  defp handle_default("indrajaal/control/logging", payload) do
    Logger.warning("[ZenohControlSubscriber] Invalid logging payload: #{inspect(payload)}")
    {:error, :invalid_logging_payload}
  end

  defp handle_default(key, _payload) when is_binary(key) do
    if String.starts_with?(key, "#{@control_prefix}/agent/") do
      # Agent commands are allowed but may not have specific handlers yet
      Logger.info("[ZenohControlSubscriber] Agent command received: #{key}")
      :ok
    else
      Logger.warning("[ZenohControlSubscriber] Unknown command: #{key}")
      {:error, :unknown_command}
    end
  end

  # ============================================================
  # ZENOH COORDINATOR WRAPPERS
  # Runtime-safe wrappers that check module availability
  # ============================================================

  defp zenoh_subscribe(coordinator, pattern) do
    module = zenoh_coordinator_module()

    if Code.ensure_loaded?(module) do
      module.subscribe(coordinator, pattern)
    else
      {:error, :module_not_available}
    end
  end

  defp zenoh_publish(coordinator, key, payload) do
    module = zenoh_coordinator_module()

    if Code.ensure_loaded?(module) do
      module.publish(coordinator, key, payload)
    else
      :ok
    end
  end

  defp zenoh_reply(coordinator, req_ref, response) do
    module = zenoh_coordinator_module()

    if Code.ensure_loaded?(module) do
      module.reply(coordinator, req_ref, response)
    else
      :ok
    end
  end
end
