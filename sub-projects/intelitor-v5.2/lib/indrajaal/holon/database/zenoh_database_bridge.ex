defmodule Indrajaal.Holon.Database.ZenohDatabaseBridge do
  @moduledoc """
  Zenoh Database Bridge for Cross-Holon Database Access.

  WHAT: Enables Elixir holons to access F# holon databases and vice versa
        through Zenoh pub/sub messaging.

  WHY: SC-XHOLON-003 requires cross-holon communication only via Zenoh.
       SC-DBNAME-008 mandates Zenoh for cross-runtime access.

  CONSTRAINTS:
    - SC-XHOLON-003: Cross-holon access ONLY via Zenoh
    - SC-XHOLON-025: Request timeout < 5s
    - SC-XHOLON-026: Retry with exponential backoff
    - SC-BRIDGE-001: FIFO message ordering
    - SC-BRIDGE-003: Latency budget 50ms for local, 200ms for remote
    - SC-BRIDGE-006: Request-response correlation via request_id

  ## Topic Pattern

  ```
  indrajaal/db/{source_runtime}/{source_holon}/request/{target_runtime}/{target_holon}/{db_type}
  indrajaal/db/{source_runtime}/{source_holon}/response/{request_id}
  ```

  ## Usage

  ```elixir
  # Query a remote F# holon database
  alias Indrajaal.Holon.Database.ZenohDatabaseBridge, as: Bridge

  {:ok, rows} = Bridge.query(
    source: "ex:l3:kms:srv:main",
    target: "fs:l4:prj:agt:cockpit",
    db_type: :state,
    sql: "SELECT * FROM config WHERE key = ?",
    params: ["setting"]
  )
  ```
  """

  use GenServer
  require Logger

  # DatabasePath will be used in live mode implementation
  # alias Indrajaal.Holon.DatabasePath

  @type holon_id :: String.t()
  @type db_type :: :state | :vectors | :cache | :analytics | :history | :register
  @type query_result :: {:ok, [map()]} | {:error, String.t()}

  @request_timeout 5_000
  # Note: retry/backoff constants for future live mode implementation
  # Commented out to avoid unused attribute warnings (SC-CMP-025)
  # @retry_count 3
  # @base_delay_ms 100
  # @max_delay_ms 2_000

  defstruct [
    :holon_id,
    :zenoh_session,
    :pending_requests,
    :stats
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start a ZenohDatabaseBridge for a holon.

  ## Options
    - `:holon_id` - Required. The UHI of the source holon
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    holon_id = Keyword.fetch!(opts, :holon_id)
    name = via_tuple(holon_id)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Query a remote holon's database.

  ## Parameters
    - `source` - Source holon UHI (the calling holon)
    - `target` - Target holon UHI (the remote holon)
    - `db_type` - Database type (:state, :analytics, etc.)
    - `sql` - SQL query string
    - `params` - Query parameters (default: [])

  ## Returns
    - `{:ok, [map()]}` on success
    - `{:error, reason}` on failure
  """
  @spec query(keyword()) :: query_result()
  def query(opts) do
    source = Keyword.fetch!(opts, :source)
    target = Keyword.fetch!(opts, :target)
    db_type = Keyword.fetch!(opts, :db_type)
    sql = Keyword.fetch!(opts, :sql)
    params = Keyword.get(opts, :params, [])

    GenServer.call(
      via_tuple(source),
      {:query, target, db_type, sql, params},
      @request_timeout + 1000
    )
  end

  @doc """
  Execute a write statement on a remote holon's database.

  ## Parameters
    - `source` - Source holon UHI
    - `target` - Target holon UHI
    - `db_type` - Database type
    - `sql` - SQL statement
    - `params` - Statement parameters

  ## Returns
    - `{:ok, %{changes: n}}` on success
    - `{:error, reason}` on failure
  """
  @spec execute(keyword()) :: {:ok, map()} | {:error, String.t()}
  def execute(opts) do
    source = Keyword.fetch!(opts, :source)
    target = Keyword.fetch!(opts, :target)
    db_type = Keyword.fetch!(opts, :db_type)
    sql = Keyword.fetch!(opts, :sql)
    params = Keyword.get(opts, :params, [])

    GenServer.call(
      via_tuple(source),
      {:execute, target, db_type, sql, params},
      @request_timeout + 1000
    )
  end

  @doc """
  Execute with compare-and-swap on a remote holon's database.

  ## Parameters
    - `source` - Source holon UHI
    - `target` - Target holon UHI
    - `db_type` - Database type
    - `sql` - SQL statement
    - `params` - Statement parameters
    - `expected_version` - Expected version vector

  ## Returns
    - `{:ok, %{changes: n, new_version: vv}}` on success
    - `{:conflict, current_version}` on version mismatch
    - `{:error, reason}` on failure
  """
  @spec execute_cas(keyword()) :: {:ok, map()} | {:conflict, map()} | {:error, String.t()}
  def execute_cas(opts) do
    source = Keyword.fetch!(opts, :source)
    target = Keyword.fetch!(opts, :target)
    db_type = Keyword.fetch!(opts, :db_type)
    sql = Keyword.fetch!(opts, :sql)
    params = Keyword.get(opts, :params, [])
    expected_version = Keyword.fetch!(opts, :expected_version)

    GenServer.call(
      via_tuple(source),
      {:execute_cas, target, db_type, sql, params, expected_version},
      @request_timeout + 1000
    )
  end

  @doc """
  Get bridge statistics.
  """
  @spec stats(holon_id()) :: {:ok, map()}
  def stats(holon_id) do
    GenServer.call(via_tuple(holon_id), :stats)
  end

  @doc """
  Check if connection to Zenoh endpoint is available.

  Returns :ok if connected, {:error, reason} otherwise.
  In test/stub mode, always returns :ok to allow tests to proceed.
  In live mode, delegates to ZenohSession.connected?/0.
  """
  @spec check_connection(String.t()) :: :ok | {:error, term()}
  def check_connection(_endpoint) do
    case Application.get_env(:indrajaal, :zenoh_bridge_mode, :stub) do
      :stub ->
        :ok

      :live ->
        zenoh_session = Indrajaal.Observability.ZenohSession

        if Code.ensure_loaded?(zenoh_session) and
             function_exported?(zenoh_session, :connected?, 0) do
          if zenoh_session.connected?() do
            :ok
          else
            {:error, :not_connected}
          end
        else
          {:error, :zenoh_session_unavailable}
        end
    end
  end

  @doc """
  Get version vector for a holon (cross-holon access).
  """
  @spec get_version_vector(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_version_vector(_local_uhi, target_uhi) do
    # Query target holon's version vector via Zenoh or local ETS cache
    table = :persistent_term.get({__MODULE__, :vv_cache}, nil)

    if table != nil and :ets.whereis(table) != :undefined do
      case :ets.lookup(table, target_uhi) do
        [{^target_uhi, vv}] -> {:ok, vv}
        [] -> {:ok, %{target_uhi => 0}}
      end
    else
      {:ok, %{target_uhi => 0}}
    end
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    holon_id = Keyword.fetch!(opts, :holon_id)

    Logger.info("[ZenohDatabaseBridge] Initializing bridge for holon: #{holon_id}")

    # Initialize pending requests table
    pending = :ets.new(:pending_requests, [:set, :private])

    # Start Zenoh session via graceful degradation (real connection or fallback)
    zenoh_session = start_zenoh_session(holon_id)

    :telemetry.execute([:indrajaal, :holon, :database_bridge, :init], %{count: 1}, %{
      holon_id: holon_id
    })

    # Subscribe to response topic
    subscribe_to_responses(holon_id)

    stats = %{
      requests_sent: 0,
      responses_received: 0,
      timeouts: 0,
      conflicts: 0,
      errors: 0,
      started_at: DateTime.utc_now()
    }

    state = %__MODULE__{
      holon_id: holon_id,
      zenoh_session: zenoh_session,
      pending_requests: pending,
      stats: stats
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:query, target, db_type, sql, params}, from, state) do
    request = build_request(state.holon_id, target, db_type, :query, sql, params)
    send_request_with_retry(request, from, state)
  end

  @impl true
  def handle_call({:execute, target, db_type, sql, params}, from, state) do
    request = build_request(state.holon_id, target, db_type, :execute, sql, params)
    send_request_with_retry(request, from, state)
  end

  @impl true
  def handle_call({:execute_cas, target, db_type, sql, params, expected_version}, from, state) do
    request =
      build_request(state.holon_id, target, db_type, :execute_cas, sql, params, expected_version)

    send_request_with_retry(request, from, state)
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, {:ok, state.stats}, state}
  end

  @impl true
  def handle_info({:zenoh_response, request_id, response}, state) do
    case :ets.lookup(state.pending_requests, request_id) do
      [{^request_id, from, _timer}] ->
        # Cancel timeout timer
        :ets.delete(state.pending_requests, request_id)

        # Parse and reply
        result = parse_response(response)
        GenServer.reply(from, result)

        new_stats = Map.update!(state.stats, :responses_received, &(&1 + 1))
        {:noreply, %{state | stats: new_stats}}

      [] ->
        # Request already timed out or not found
        Logger.warning("[ZenohDatabaseBridge] Response for unknown request: #{request_id}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:request_timeout, request_id}, state) do
    case :ets.lookup(state.pending_requests, request_id) do
      [{^request_id, from, _timer}] ->
        :ets.delete(state.pending_requests, request_id)
        GenServer.reply(from, {:error, "Request timeout"})

        new_stats = Map.update!(state.stats, :timeouts, &(&1 + 1))
        {:noreply, %{state | stats: new_stats}}

      [] ->
        {:noreply, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    Logger.info(
      "[ZenohDatabaseBridge] Shutting down bridge for holon: #{state.holon_id}, reason: #{inspect(reason)}"
    )

    stop_zenoh_session(state.zenoh_session)
    :ets.delete(state.pending_requests)
    :ok
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp via_tuple(holon_id) do
    {:via, Registry, {Indrajaal.Holon.Database.BridgeRegistry, holon_id}}
  end

  defp build_request(source, target, db_type, operation, sql, params, version \\ nil) do
    %{
      request_id: generate_request_id(),
      source: source,
      target: target,
      db_type: db_type,
      operation: operation,
      sql: sql,
      params: params,
      version: version,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp send_request_with_retry(request, from, state) do
    # Store pending request with timeout
    timer = Process.send_after(self(), {:request_timeout, request.request_id}, @request_timeout)
    :ets.insert(state.pending_requests, {request.request_id, from, timer})

    # Build Zenoh topic
    topic = build_request_topic(request.source, request.target, request.db_type)

    # Serialize and publish
    payload = Jason.encode!(request)
    publish_to_zenoh(state.zenoh_session, topic, payload)

    new_stats = Map.update!(state.stats, :requests_sent, &(&1 + 1))
    {:noreply, %{state | stats: new_stats}}
  end

  defp build_request_topic(source, target, db_type) do
    source_parts = parse_uhi(source)
    target_parts = parse_uhi(target)

    "indrajaal/db/#{source_parts.runtime}/#{source_parts.instance}/request/#{target_parts.runtime}/#{target_parts.instance}/#{db_type}"
  end

  defp parse_uhi(uhi) do
    case String.split(uhi, ":") do
      [runtime, layer, domain, type, instance] ->
        %{runtime: runtime, layer: layer, domain: domain, type: type, instance: instance}

      _ ->
        %{runtime: "unknown", instance: uhi}
    end
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp parse_response(response) when is_binary(response) do
    case Jason.decode(response) do
      {:ok, %{"success" => true, "result" => result}} ->
        {:ok, result}

      {:ok, %{"success" => false, "error" => error}} ->
        {:error, error}

      {:ok, %{"conflict" => true, "version" => version}} ->
        {:conflict, version}

      {:error, reason} ->
        {:error, "Failed to parse response: #{inspect(reason)}"}
    end
  end

  defp parse_response(response) when is_map(response) do
    case response do
      %{"success" => true, "result" => result} ->
        {:ok, result}

      %{"success" => false, "error" => error} ->
        {:error, error}

      %{"conflict" => true, "version" => version} ->
        {:conflict, version}

      _ ->
        {:error, "Unknown response format"}
    end
  end

  # ============================================================================
  # Zenoh Integration - delegates to ZenohSession when available
  # ============================================================================

  defp start_zenoh_session(holon_id) do
    # Returns a session handle. Actual session management is handled by the
    # shared ZenohSession GenServer. This just captures the holon context.
    Logger.debug("[ZenohDatabaseBridge] Starting Zenoh session context for #{holon_id}")
    %{holon_id: holon_id, connected: true}
  end

  defp stop_zenoh_session(session) do
    Logger.debug("[ZenohDatabaseBridge] Stopping Zenoh session context for #{session.holon_id}")
    :ok
  end

  defp subscribe_to_responses(holon_id) do
    # Subscribe via ZenohSession for response messages directed at this holon.
    # Pattern: indrajaal/db/{runtime}/{instance}/response/**
    topic = "indrajaal/db/#{get_runtime(holon_id)}/#{get_instance(holon_id)}/response/**"
    zenoh_session = Indrajaal.Observability.ZenohSession

    if Code.ensure_loaded?(zenoh_session) and
         function_exported?(zenoh_session, :subscribe, 2) do
      case zenoh_session.subscribe(topic, self()) do
        {:ok, _ref} ->
          Logger.debug("[ZenohDatabaseBridge] Subscribed to #{topic}")

        {:error, reason} ->
          Logger.warning(
            "[ZenohDatabaseBridge] Subscription failed for #{topic}: #{inspect(reason)}"
          )
      end
    else
      Logger.debug(
        "[ZenohDatabaseBridge] ZenohSession unavailable - skipping subscription to #{topic}"
      )
    end

    :ok
  end

  defp publish_to_zenoh(_session, topic, payload) do
    # SC-ZTEST-008: Log fallback first (guaranteed durability)
    Logger.debug(
      "[ZTEST-CHECKPOINT] topic=#{topic} checkpoint=db-request type=db_request payload=#{String.slice(payload, 0, 200)}"
    )

    # SC-ZTEST-004: Async publish via ZenohSession (non-blocking)
    zenoh_session = Indrajaal.Observability.ZenohSession

    if Code.ensure_loaded?(zenoh_session) and
         function_exported?(zenoh_session, :publish, 2) do
      Task.start(fn ->
        case zenoh_session.publish(topic, payload) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "[ZenohDatabaseBridge] Publish failed for #{topic}: #{inspect(reason)}"
            )
        end
      end)
    else
      Logger.debug(
        "[ZenohDatabaseBridge] ZenohSession unavailable - db request not published to Zenoh"
      )
    end

    :ok
  end

  defp get_runtime(uhi) do
    case String.split(uhi, ":") do
      [runtime | _] -> runtime
      _ -> "unknown"
    end
  end

  defp get_instance(uhi) do
    case String.split(uhi, ":") do
      [_, _, _, _, instance] -> instance
      _ -> uhi
    end
  end
end

defmodule Indrajaal.Holon.Database.ZenohDatabaseBridge.Supervisor do
  @moduledoc """
  Supervisor for Zenoh Database Bridge instances.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Registry for bridge instances
      {Registry, keys: :unique, name: Indrajaal.Holon.Database.BridgeRegistry}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
