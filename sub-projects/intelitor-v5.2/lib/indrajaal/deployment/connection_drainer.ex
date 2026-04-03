defmodule Indrajaal.Deployment.ConnectionDrainer do
  @moduledoc """
  SIL-4 Compliant Connection Draining for Graceful Shutdown

  WHAT: Manages graceful connection draining before container shutdown.

  WHY: SIL-4 requires no abrupt termination of active connections.
  This module implements the "lameduck" pattern where a container
  signals its intent to shut down and waits for connections to drain.

  CONSTRAINTS:
  - SC-SIL4-007: Dying gasp mandatory before shutdown
  - SC-SIL4-008: Drain timeout 30s (configurable)
  - SC-EMR-057: Stop < 5s for emergency
  - SC-CLU-007: Graceful shutdown sequence

  TECHNIQUES:
  | Technique | Source | Purpose |
  |-----------|--------|---------|
  | Lameduck State | Google SRE | Signal intent to terminate |
  | Connection Polling | Linux ss | Count active connections |
  | Exponential Backoff | Industry | Efficient polling |
  | Pre-shutdown Hook | Kubernetes | Clean termination |

  AOR:
  - AOR-SIL4-001: Always drain before shutdown
  - AOR-SIL4-002: Never exceed drain timeout
  """

  use GenServer
  require Logger

  # =============================================================================
  # Constants (SC-SIL4-008: 30 second drain timeout)
  # =============================================================================

  @default_drain_timeout_ms 30_000
  @poll_interval_initial_ms 100
  @poll_interval_max_ms 2_000
  @emergency_drain_timeout_ms 5_000

  # =============================================================================
  # Types
  # =============================================================================

  @type container_id :: String.t()
  @type connection_count :: non_neg_integer()
  @type drain_state :: :normal | :lameduck | :draining | :drained | :force_stopped

  @type drain_config :: %{
          timeout_ms: pos_integer(),
          poll_interval_ms: pos_integer(),
          max_connections_threshold: non_neg_integer()
        }

  @type drain_result :: %{
          container_id: container_id(),
          initial_connections: connection_count(),
          final_connections: connection_count(),
          drain_duration_ms: non_neg_integer(),
          state: drain_state(),
          success: boolean()
        }

  # =============================================================================
  # State
  # =============================================================================

  defmodule State do
    @moduledoc false
    defstruct [
      :container_id,
      :drain_state,
      :start_time,
      :initial_connections,
      :current_connections,
      :config,
      :drain_ref,
      :callbacks
    ]
  end

  # =============================================================================
  # Public API
  # =============================================================================

  @doc """
  Starts the ConnectionDrainer for a specific container.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    container_id = Keyword.get(opts, :container_id, "indrajaal-app")
    name = via_tuple(container_id)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Initiates graceful drain for a container.
  Returns when drain is complete or timeout is reached.
  """
  @spec drain(container_id(), keyword()) :: {:ok, drain_result()} | {:error, term()}
  def drain(container_id, opts \\ []) do
    timeout = Keyword.get(opts, :timeout_ms, @default_drain_timeout_ms)

    case GenServer.whereis(via_tuple(container_id)) do
      nil ->
        # Start ad-hoc drainer if not running
        {:ok, pid} = start_link(container_id: container_id)
        result = GenServer.call(pid, {:drain, opts}, timeout + 5_000)
        GenServer.stop(pid)
        result

      pid ->
        GenServer.call(pid, {:drain, opts}, timeout + 5_000)
    end
  end

  @doc """
  Initiates emergency drain with minimal timeout (SC-EMR-057: < 5s).
  """
  @spec emergency_drain(container_id()) :: {:ok, drain_result()} | {:error, term()}
  def emergency_drain(container_id) do
    drain(container_id, timeout_ms: @emergency_drain_timeout_ms, force: true)
  end

  @doc """
  Sets container to lameduck state (accepting no new connections).
  """
  @spec enter_lameduck(container_id()) :: :ok | {:error, term()}
  def enter_lameduck(container_id) do
    case GenServer.whereis(via_tuple(container_id)) do
      nil -> {:error, :not_running}
      pid -> GenServer.call(pid, :enter_lameduck)
    end
  end

  @doc """
  Gets current drain state and connection count.
  """
  @spec get_status(container_id()) :: {:ok, map()} | {:error, :not_running}
  def get_status(container_id) do
    case GenServer.whereis(via_tuple(container_id)) do
      nil -> {:error, :not_running}
      pid -> GenServer.call(pid, :get_status)
    end
  end

  @doc """
  Counts active TCP connections for a container.
  Uses `ss -tn` for Linux socket statistics.
  """
  @spec count_connections(container_id()) :: {:ok, connection_count()} | {:error, term()}
  def count_connections(container_id) do
    # Get container IP address
    case get_container_ip(container_id) do
      {:ok, ip} -> count_connections_for_ip(ip)
      error -> error
    end
  end

  @doc """
  Registers a callback to be invoked when drain starts.
  """
  @spec on_drain_start(container_id(), (-> any())) :: :ok | {:error, term()}
  def on_drain_start(container_id, callback) when is_function(callback, 0) do
    case GenServer.whereis(via_tuple(container_id)) do
      nil -> {:error, :not_running}
      pid -> GenServer.cast(pid, {:register_callback, :drain_start, callback})
    end
  end

  @doc """
  Registers a callback to be invoked when drain completes.
  """
  @spec on_drain_complete(container_id(), (drain_result() -> any())) :: :ok | {:error, term()}
  def on_drain_complete(container_id, callback) when is_function(callback, 1) do
    case GenServer.whereis(via_tuple(container_id)) do
      nil -> {:error, :not_running}
      pid -> GenServer.cast(pid, {:register_callback, :drain_complete, callback})
    end
  end

  # =============================================================================
  # GenServer Callbacks
  # =============================================================================

  @impl true
  def init(opts) do
    container_id = Keyword.get(opts, :container_id, "indrajaal-app")

    config = %{
      timeout_ms: Keyword.get(opts, :timeout_ms, @default_drain_timeout_ms),
      poll_interval_ms: Keyword.get(opts, :poll_interval_ms, @poll_interval_initial_ms),
      max_connections_threshold: Keyword.get(opts, :max_connections_threshold, 0)
    }

    state = %State{
      container_id: container_id,
      drain_state: :normal,
      start_time: nil,
      initial_connections: 0,
      current_connections: 0,
      config: config,
      drain_ref: nil,
      callbacks: %{drain_start: [], drain_complete: []}
    }

    Logger.info("[ConnectionDrainer] Started for container #{container_id}")

    {:ok, state}
  end

  @impl true
  def handle_call({:drain, opts}, from, state) do
    timeout = Keyword.get(opts, :timeout_ms, state.config.timeout_ms)
    force = Keyword.get(opts, :force, false)

    # Get initial connection count
    initial_count =
      case count_connections(state.container_id) do
        {:ok, count} -> count
        {:error, _} -> 0
      end

    # If already at threshold, drain immediately
    if initial_count <= state.config.max_connections_threshold do
      result = %{
        container_id: state.container_id,
        initial_connections: initial_count,
        final_connections: initial_count,
        drain_duration_ms: 0,
        state: :drained,
        success: true
      }

      {:reply, {:ok, result}, %{state | drain_state: :drained}}
    else
      # Start drain process
      invoke_callbacks(state.callbacks.drain_start)

      emit_telemetry(:drain_start, %{
        container: state.container_id,
        initial_connections: initial_count
      })

      # Set up drain timeout
      drain_ref = Process.send_after(self(), {:drain_timeout, from}, timeout)

      new_state = %{
        state
        | drain_state: :draining,
          start_time: System.monotonic_time(:millisecond),
          initial_connections: initial_count,
          current_connections: initial_count,
          drain_ref: drain_ref
      }

      # Start polling
      send(self(), {:poll_connections, from, @poll_interval_initial_ms, force})

      {:noreply, new_state}
    end
  end

  @impl true
  def handle_call(:enter_lameduck, _from, state) do
    Logger.info("[ConnectionDrainer] Container #{state.container_id} entering lameduck state")

    emit_telemetry(:enter_lameduck, %{container: state.container_id})

    # Send SIGUSR1 equivalent via podman to signal lameduck state
    notify_lameduck(state.container_id)

    {:reply, :ok, %{state | drain_state: :lameduck}}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      container_id: state.container_id,
      drain_state: state.drain_state,
      current_connections: state.current_connections,
      config: state.config
    }

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_cast({:register_callback, type, callback}, state) do
    callbacks = Map.update(state.callbacks, type, [callback], &[callback | &1])
    {:noreply, %{state | callbacks: callbacks}}
  end

  @impl true
  def handle_info({:poll_connections, from, interval, force}, state) do
    case count_connections(state.container_id) do
      {:ok, count} ->
        new_state = %{state | current_connections: count}

        emit_telemetry(:poll_connections, %{
          container: state.container_id,
          connections: count
        })

        if count <= state.config.max_connections_threshold do
          # Drain complete
          complete_drain(new_state, from, :drained)
        else
          # Continue polling with exponential backoff
          new_interval = min(interval * 2, @poll_interval_max_ms)
          Process.send_after(self(), {:poll_connections, from, new_interval, force}, interval)
          {:noreply, new_state}
        end

      {:error, reason} ->
        Logger.warning("[ConnectionDrainer] Failed to count connections: #{inspect(reason)}")

        if force do
          # Force complete on error
          complete_drain(state, from, :force_stopped)
        else
          # Retry
          Process.send_after(self(), {:poll_connections, from, interval, force}, interval)
          {:noreply, state}
        end
    end
  end

  @impl true
  def handle_info({:drain_timeout, from}, state) do
    Logger.warning(
      "[ConnectionDrainer] Drain timeout for #{state.container_id}, " <>
        "#{state.current_connections} connections remaining"
    )

    complete_drain(state, from, :force_stopped)
  end

  # =============================================================================
  # Private: Drain Completion
  # =============================================================================

  defp complete_drain(state, from, final_state) do
    # Cancel timeout if exists
    if state.drain_ref do
      Process.cancel_timer(state.drain_ref)
    end

    duration =
      if state.start_time do
        System.monotonic_time(:millisecond) - state.start_time
      else
        0
      end

    result = %{
      container_id: state.container_id,
      initial_connections: state.initial_connections,
      final_connections: state.current_connections,
      drain_duration_ms: duration,
      state: final_state,
      success: final_state == :drained
    }

    emit_telemetry(:drain_complete, %{
      container: state.container_id,
      initial_connections: result.initial_connections,
      final_connections: result.final_connections,
      duration_ms: duration,
      success: result.success
    })

    invoke_callbacks(state.callbacks.drain_complete, [result])

    GenServer.reply(from, {:ok, result})

    {:noreply, %{state | drain_state: final_state, drain_ref: nil}}
  end

  # =============================================================================
  # Private: Connection Counting
  # =============================================================================

  defp get_container_ip(container_id) do
    case System.cmd(
           "podman",
           [
             "inspect",
             "--format",
             "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}",
             container_id
           ],
           stderr_to_stdout: true
         ) do
      {ip, 0} when ip != "" ->
        {:ok, String.trim(ip)}

      {"", 0} ->
        # Try host network
        {:ok, "127.0.0.1"}

      {error, _} ->
        {:error, {:container_inspect_failed, error}}
    end
  end

  defp count_connections_for_ip(ip) do
    # Use ss (socket statistics) to count ESTABLISHED connections
    # ss -tn state established dst :4000 or dst :4001
    case System.cmd("ss", ["-tn", "state", "established"], stderr_to_stdout: true) do
      {output, 0} ->
        count =
          output
          |> String.split("\n")
          |> Enum.count(fn line ->
            String.contains?(line, ip) or
              (ip == "127.0.0.1" and
                 (String.contains?(line, ":4000") or String.contains?(line, ":4001")))
          end)

        {:ok, count}

      {error, _} ->
        {:error, {:ss_failed, error}}
    end
  end

  # =============================================================================
  # Private: Lameduck Notification
  # =============================================================================

  defp notify_lameduck(container_id) do
    # Send SIGUSR1 to container's PID 1 to signal lameduck
    # This is the Kubernetes-style pre-stop hook pattern
    case System.cmd(
           "podman",
           ["exec", container_id, "kill", "-USR1", "1"],
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        Logger.info("[ConnectionDrainer] Sent SIGUSR1 to #{container_id}")
        :ok

      {error, _} ->
        Logger.warning("[ConnectionDrainer] Failed to send SIGUSR1 to #{container_id}: #{error}")

        :ok
    end
  end

  # =============================================================================
  # Private: Callbacks
  # =============================================================================

  defp invoke_callbacks(callbacks) do
    Enum.each(callbacks, fn callback ->
      try do
        callback.()
      rescue
        e -> Logger.warning("[ConnectionDrainer] Callback failed: #{inspect(e)}")
      end
    end)
  end

  defp invoke_callbacks(callbacks, args) do
    Enum.each(callbacks, fn callback ->
      try do
        apply(callback, args)
      rescue
        e -> Logger.warning("[ConnectionDrainer] Callback failed: #{inspect(e)}")
      end
    end)
  end

  # =============================================================================
  # Private: Registry
  # =============================================================================

  defp via_tuple(container_id) do
    {:via, Registry, {Indrajaal.Deployment.DrainerRegistry, container_id}}
  end

  # =============================================================================
  # Private: Telemetry
  # =============================================================================

  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:indrajaal, :deployment, :connection_drainer, event],
      measurements,
      %{timestamp: DateTime.utc_now()}
    )
  end
end
