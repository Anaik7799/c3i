defmodule Indrajaal.Observability.ZenohCoordinator do
  @moduledoc """
  Zenoh Coordinator Supervisor for full system integration.

  WHAT: Supervises all Zenoh components (Publisher, Subscriber, Bridges).
  WHY: SC-ZENOH-INT-001 requires coordinated Zenoh access for all components.
  CONSTRAINTS: Start order, graceful degradation, heartbeat coordination.

  ## Supervised Children
  1. ZenohKpiPublisher - Data plane publisher
  2. ZenohControlSubscriber - Control plane subscriber
  3. ZenohTelemetrySubscriber - F# telemetry subscriber
  4. GitZenohSubscriber - Git Intelligence event subscriber
  5. HeartbeatWorker - Coordination plane heartbeat

  ## STAMP Constraints
  - SC-ZENOH-INT-001: Universal Zenoh access
  - SC-ZENOH-INT-004: 10s heartbeat interval

  ## AOR Rules
  - AOR-ZENOH-INT-001: Startup order (Coordinator → Data → Control → Coord)
  """

  use Supervisor
  require Logger

  @heartbeat_interval_ms 10_000
  @coord_prefix "indrajaal/coord"

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    # Derive suffix from name if not provided (SC-ZENOH-INT-001)
    name = Keyword.get(opts, :name, __MODULE__)
    suffix = Keyword.get(opts, :suffix) || suffix_from_name(name)

    # In test mode, we might want to share a coordinator
    coordinator = Keyword.get(opts, :coordinator)

    children = [
      # Core Session - Native NIF connection (SC-ZENOH-SES-001)
      {Indrajaal.Observability.ZenohSession,
       [name: name_with_suffix(Indrajaal.Observability.ZenohSession, suffix)]},

      # Fractal Logging Plane - Real-time log streaming to F# cockpit
      {Indrajaal.Observability.ZenohFractalPublisher,
       [
         name: name_with_suffix(Indrajaal.Observability.ZenohFractalPublisher, suffix),
         coordinator: coordinator
       ]},

      # Data Plane - KPI Publisher
      {Indrajaal.Observability.ZenohKpiPublisher,
       [
         name: name_with_suffix(Indrajaal.Observability.ZenohKpiPublisher, suffix),
         coordinator: coordinator
       ]},

      # Control Plane - Control Subscriber
      {Indrajaal.Observability.ZenohControlSubscriber,
       [
         name: name_with_suffix(Indrajaal.Observability.ZenohControlSubscriber, suffix),
         coordinator: coordinator
       ]},

      # Telemetry Plane - F# Telemetry Subscriber (SC-TEL-SUB-001)
      {Indrajaal.Observability.ZenohTelemetrySubscriber,
       [
         name: name_with_suffix(Indrajaal.Observability.ZenohTelemetrySubscriber, suffix),
         coordinator: coordinator
       ]},

      # Git Intelligence Plane - Git event subscriber (SC-BRIDGE-003)
      {Indrajaal.Observability.GitIntegration.GitZenohSubscriber,
       [
         name: name_with_suffix(Indrajaal.Observability.GitIntegration.GitZenohSubscriber, suffix)
       ]},

      # Evolution Plane - Evolution Publisher (SC-ZENOH-EVO-001)
      {Indrajaal.Observability.ZenohEvolutionPublisher,
       [
         name: name_with_suffix(Indrajaal.Observability.ZenohEvolutionPublisher, suffix),
         coordinator: coordinator
       ]},

      # Coordination Plane - Heartbeat Worker
      {Task.Supervisor,
       name: name_with_suffix(Indrajaal.Observability.ZenohCoordinator.TaskSupervisor, suffix)},
      %{
        id: :heartbeat_worker,
        start: {Task, :start_link, [fn -> heartbeat_loop(suffix, coordinator) end]},
        restart: :permanent
      }
    ]

    # SC-ZENOH-008: Conditional DatabaseProxy startup with NIF detection
    # If Zenoh NIF is available, start DatabaseProxy; otherwise log warning and skip
    database_proxy_child =
      if Code.ensure_loaded?(Indrajaal.Native.Zenoh) and
           Code.ensure_loaded?(Indrajaal.Zenoh.DatabaseProxy) do
        Logger.info("[ZenohCoordinator] Starting DatabaseProxy - Zenoh NIF available")

        [
          {Indrajaal.Zenoh.DatabaseProxy,
           [name: name_with_suffix(Indrajaal.Zenoh.DatabaseProxy, suffix)]}
        ]
      else
        Logger.warning(
          "[ZenohCoordinator] DatabaseProxy skipped - Zenoh NIF unavailable or module not loaded"
        )

        []
      end

    children = children ++ database_proxy_child

    Logger.info("[ZenohCoordinator] Starting Zenoh subsystem with NIF session - SC-ZENOH-INT-001")

    # rest_for_one: When ZenohSession (first child) crashes, all downstream
    # publishers restart too, getting fresh session refs (FM-ZUIP-004, RPN 144).
    # max_restarts: 5 in 60s prevents rapid NIF crash loops.
    Supervisor.init(children,
      strategy: :rest_for_one,
      max_restarts: 5,
      max_seconds: 60
    )
  end

  # --- Private Helper ---
  defp name_with_suffix(module, ""), do: module
  defp name_with_suffix(module, suffix), do: Module.concat([module, suffix])

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc "Get overall Zenoh subsystem status"
  def status(name \\ __MODULE__) do
    %{
      supervisor: supervisor_status(name),
      publisher: publisher_status(name),
      subscriber: subscriber_status(name),
      heartbeat: :active,
      integration: :full
    }
  end

  @doc "Get comprehensive status for all Zenoh components"
  def get_status(name \\ __MODULE__), do: status(name)

  @doc "Check if the Zenoh subsystem is healthy"
  def healthy?(name \\ __MODULE__) do
    supervisor_status(name) == :running and
      Indrajaal.Observability.ZenohSession.connected?(
        name_with_suffix(Indrajaal.Observability.ZenohSession, suffix_from_name(name))
      )
  end

  @doc "Get status of supervised children"
  def children_status(name \\ __MODULE__) do
    case Process.whereis(name) do
      nil -> []
      pid -> Supervisor.which_children(pid)
    end
  end

  @doc "Force synchronization of all components"
  def sync_now(name \\ __MODULE__) do
    suffix = suffix_from_name(name)

    Indrajaal.Observability.ZenohKpiPublisher.publish_now(
      name_with_suffix(Indrajaal.Observability.ZenohKpiPublisher, suffix)
    )

    publish_coord("sync", %{triggered_at: DateTime.utc_now()}, name: name)
    :ok
  end

  @doc "Barrier synchronization for multi-agent operations"
  def barrier(barrier_name, count, opts \\ []) do
    # Handle legacy timeout integer as opts (SC-OODA-005)
    timeout =
      cond do
        is_integer(opts) -> opts
        is_list(opts) -> Keyword.get(opts, :timeout, 30_000)
        true -> 30_000
      end

    name = if is_list(opts), do: Keyword.get(opts, :name, __MODULE__), else: __MODULE__

    with_zenoh_coordinator(name, fn coordinator ->
      # Dynamic call to avoid compile-time warnings for test-only module
      zenoh_test_module().barrier(coordinator, barrier_name, count, timeout: timeout)
    end)
  end

  @doc "Publish a message to a Zenoh key"
  def publish(key, payload) do
    binary_payload = Jason.encode!(payload)
    Indrajaal.Observability.ZenohSession.publish(key, binary_payload)
  end

  @doc "Publish coordination message"
  def publish_coord(key, payload, opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    result =
      with_zenoh_coordinator(name, fn coordinator ->
        zenoh_test_module().publish(coordinator, "#{@coord_prefix}/#{key}", payload)
        :ok
      end)

    case result do
      :ok -> :ok
      {:error, _} = err -> err
    end
  end

  # Helper to extract suffix from a Module name like Indrajaal.Observability.ZenohCoordinator.T123 or .SDID123
  defp suffix_from_name(name) do
    name_str = to_string(name)
    base_str = to_string(__MODULE__)

    if String.starts_with?(name_str, base_str <> ".") do
      String.replace(name_str, base_str <> ".", "")
    else
      ""
    end
  end

  @doc "Subscribe to coordination messages via ZenohSession"
  @spec subscribe_coord(String.t(), fun()) :: :ok | {:error, term()}
  def subscribe_coord(key_expression, callback)
      when is_binary(key_expression) and is_function(callback) do
    Logger.debug("[ZenohCoordinator] Subscribing to #{key_expression}")

    zenoh_session = Indrajaal.Observability.ZenohSession

    if Code.ensure_loaded?(zenoh_session) and
         function_exported?(zenoh_session, :subscribe, 2) do
      # Spawn a receiver process that invokes the callback for each message
      receiver_pid =
        spawn(fn ->
          receive do
            {:zenoh_message, msg} ->
              try do
                callback.(msg)
              rescue
                e ->
                  Logger.warning(
                    "[ZenohCoordinator] Callback error for #{key_expression}: #{inspect(e)}"
                  )
              end
          end
        end)

      case zenoh_session.subscribe(key_expression, receiver_pid) do
        {:ok, _ref} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "[ZenohCoordinator] Subscribe failed for #{key_expression}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    else
      Logger.debug(
        "[ZenohCoordinator] ZenohSession unavailable - subscription deferred for #{key_expression}"
      )

      :ok
    end
  end

  @doc "Get list of all Zenoh key expressions in use"
  def list_key_expressions do
    %{
      # SC-ZENOH-INT-001: Fractal logging key expressions (ALL LEVELS)
      fractal_plane: [
        "indrajaal/fractal/l1/**",
        "indrajaal/fractal/l2/**",
        "indrajaal/fractal/l3/**",
        "indrajaal/fractal/l4/**",
        "indrajaal/fractal/l5/**"
      ],
      # Telemetry key expressions
      telemetry_plane: [
        "indrajaal/telemetry/elixir/**",
        "indrajaal/telemetry/fsharp/**"
      ],
      data_plane: [
        "indrajaal/kpi/compilation",
        "indrajaal/kpi/tests",
        "indrajaal/kpi/containers",
        "indrajaal/kpi/performance",
        "indrajaal/kpi/progress",
        "indrajaal/kpi/stamp",
        "indrajaal/kpi/todos",
        "indrajaal/kpi/agents"
      ],
      control_plane: [
        "indrajaal/control/refresh",
        "indrajaal/control/mode",
        "indrajaal/control/agent/**",
        "indrajaal/control/fractal/boost",
        "indrajaal/control/fractal/suppress",
        "indrajaal/control/compile",
        "indrajaal/control/test",
        "indrajaal/control/emergency"
      ],
      coordination_plane: [
        "indrajaal/coord/heartbeat",
        "indrajaal/coord/sync",
        "indrajaal/coord/barrier/**"
      ],
      # SC-ZENOH-EVO-001: Evolution key expressions
      evolution_plane: [
        "indrajaal/evolution/shadow/*/execution",
        "indrajaal/evolution/shadow/*/comparison",
        "indrajaal/evolution/shadow/*/promotion",
        "indrajaal/evolution/gym/episode/*",
        "indrajaal/evolution/gym/stats",
        "indrajaal/evolution/guardian/validations",
        "indrajaal/evolution/openrouter/calls",
        "indrajaal/evolution/stats"
      ]
    }
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  # Runtime module reference to avoid compile-time warnings for test-only module
  defp zenoh_test_module, do: Module.concat([Indrajaal, Test, ZenohTestCoordinator])

  defp with_zenoh_coordinator(name, fun) do
    # Try to find coordinator from local KpiPublisher
    suffix = suffix_from_name(name)
    pub_name = name_with_suffix(Indrajaal.Observability.ZenohKpiPublisher, suffix)

    coordinator =
      try do
        stats = Indrajaal.Observability.ZenohKpiPublisher.get_stats(pub_name)
        stats.coordinator
      rescue
        _ -> nil
      end

    if coordinator && Process.alive?(coordinator) do
      fun.(coordinator)
    else
      # Fallback to starting a temporary one if needed (less ideal)
      module = zenoh_test_module()

      if Code.ensure_loaded?(module) do
        {:ok, temp_coord} = module.start_link([])

        try do
          fun.(temp_coord)
        after
          safe_stop(temp_coord)
        end
      else
        {:error, :zenoh_not_available}
      end
    end
  end

  defp safe_stop(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      GenServer.stop(pid, :normal, 500)
    end
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp safe_stop(_), do: :ok

  defp supervisor_status(name) do
    case Process.whereis(name) do
      nil ->
        :stopped

      pid ->
        case Supervisor.count_children(pid) do
          counts when is_map(counts) -> :running
          _ -> :degraded
        end
    end
  end

  defp publisher_status(name) do
    suffix = suffix_from_name(name)
    pub_name = name_with_suffix(Indrajaal.Observability.ZenohKpiPublisher, suffix)

    try do
      Indrajaal.Observability.ZenohKpiPublisher.get_stats(pub_name)
    rescue
      _ -> %{status: :unavailable}
    end
  end

  defp subscriber_status(name) do
    suffix = suffix_from_name(name)
    sub_name = name_with_suffix(Indrajaal.Observability.ZenohControlSubscriber, suffix)

    try do
      Indrajaal.Observability.ZenohControlSubscriber.get_stats(sub_name)
    rescue
      _ -> %{status: :unavailable}
    end
  end

  defp heartbeat_loop(suffix, coordinator) do
    # SC-ZENOH-INT-004: 10s heartbeat interval
    receive do
    after
      @heartbeat_interval_ms ->
        publish_heartbeat(suffix, coordinator)
        heartbeat_loop(suffix, coordinator)
    end
  end

  defp publish_heartbeat(suffix, _coordinator) do
    wall_clock = :erlang.statistics(:wall_clock)
    wall_time = wall_clock |> elem(0)
    uptime_ms = wall_time |> div(1000)

    payload = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      status: :alive,
      node: node(),
      uptime: uptime_ms,
      suffix: suffix
    }

    name = name_with_suffix(__MODULE__, suffix)
    publish_coord("heartbeat", payload, name: name)

    # Also write to file for dashboard
    File.write!("data/tmp/zenoh_heartbeat_#{suffix}.json", Jason.encode!(payload))
  rescue
    _ -> :ok
  end
end
