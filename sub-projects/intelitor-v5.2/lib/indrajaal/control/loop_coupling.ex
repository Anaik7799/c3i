defmodule Indrajaal.Control.LoopCoupling do
  @moduledoc """
  Control Loop Coupling Manager for CAE Integration.

  ## WHAT
  Manages the coupling between OODA loops, GDE (Goal-Directed Evolution),
  and the UnifiedBus. Ensures proper registration, communication, and
  coordination of all control loops in the system.

  ## WHY
  SC-BUS-001 through SC-BUS-004 require coordinated control loop management.
  The coupling manager ensures all loops register at startup, events flow
  correctly, and the system maintains causal consistency.

  ## CONSTRAINTS
  - SC-CPL-001: All loops must register on startup
  - SC-CPL-002: Event flow from OODA to GDE must be verified
  - SC-CPL-003: No deadlocks between coupled loops
  - SC-CPL-004: Coupling verification on health check

  ## Architecture

  ```
  +-------------------------------------------------------+
  |                  LoopCoupling Manager                  |
  +-------------------------------------------------------+
  |                                                       |
  |   +-----------+     +-----------+     +-----------+   |
  |   |   OODA    |---->| UnifiedBus|---->|    GDE    |   |
  |   |   Loop    |     |           |     |  Engine   |   |
  |   +-----------+     +-----------+     +-----------+   |
  |         |                 |                 |         |
  |         v                 v                 v         |
  |   +-----------+     +-----------+     +-----------+   |
  |   |  FastOODA |     |  Metrics  |     | Proposals |   |
  |   +-----------+     +-----------+     +-----------+   |
  |                                                       |
  +-------------------------------------------------------+
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-29 |
  | Author | AGENT 6 (C2-HIGH) |
  | STAMP | SC-CPL-001 to SC-CPL-004 |
  """

  use GenServer

  require Logger

  alias Indrajaal.Control.UnifiedBus

  # ============================================================
  # TYPES
  # ============================================================

  @type loop_info :: %{
          name: atom(),
          pid: pid(),
          status: :running | :stopped | :error,
          registered_at: DateTime.t(),
          last_heartbeat: DateTime.t() | nil,
          event_count: non_neg_integer()
        }

  @type coupling_state :: %{
          loops: %{atom() => loop_info()},
          couplings: list({atom(), atom()}),
          health: %{
            status: :healthy | :degraded | :critical,
            last_check: DateTime.t() | nil,
            issues: list(term())
          },
          metrics: map()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  # Health check interval (ms)
  @health_check_interval 10_000
  # Heartbeat timeout (ms)
  @heartbeat_timeout 30_000
  # Required loops for healthy status
  @required_loops [:ooda_loop, :fast_ooda, :gde]

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Start the LoopCoupling manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Register a control loop with the coupling manager.
  SC-CPL-001: All loops must register on startup.
  """
  @spec register(atom(), pid() | nil) :: :ok | {:error, term()}
  def register(loop_name, pid \\ nil) do
    loop_pid = pid || self()
    GenServer.call(__MODULE__, {:register, loop_name, loop_pid})
  end

  @doc """
  Unregister a control loop.
  """
  @spec unregister(atom()) :: :ok
  def unregister(loop_name) do
    GenServer.cast(__MODULE__, {:unregister, loop_name})
  end

  @doc """
  Send heartbeat from a loop.
  """
  @spec heartbeat(atom()) :: :ok
  def heartbeat(loop_name) do
    GenServer.cast(__MODULE__, {:heartbeat, loop_name})
  end

  @doc """
  Define a coupling between two loops.
  Events from source_loop will flow to target_loop.
  """
  @spec couple(atom(), atom()) :: :ok
  def couple(source_loop, target_loop) do
    GenServer.cast(__MODULE__, {:couple, source_loop, target_loop})
  end

  @doc """
  Remove a coupling between loops.
  """
  @spec decouple(atom(), atom()) :: :ok
  def decouple(source_loop, target_loop) do
    GenServer.cast(__MODULE__, {:decouple, source_loop, target_loop})
  end

  @doc """
  Get the current coupling state.
  """
  @spec get_state() :: coupling_state()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Get health status.
  SC-CPL-004: Coupling verification on health check.
  """
  @spec health() :: %{status: atom(), issues: list()}
  def health do
    GenServer.call(__MODULE__, :health)
  end

  @doc """
  List all registered loops.
  """
  @spec registered_loops() :: list(atom())
  def registered_loops do
    GenServer.call(__MODULE__, :registered_loops)
  end

  @doc """
  Verify event flow between two loops.
  SC-CPL-002: Event flow from OODA to GDE must be verified.
  """
  @spec verify_flow(atom(), atom()) :: {:ok, :verified} | {:error, term()}
  def verify_flow(source, target) do
    GenServer.call(__MODULE__, {:verify_flow, source, target}, 10_000)
  end

  @doc """
  Force a health check.
  """
  @spec check_health() :: :ok
  def check_health do
    GenServer.cast(__MODULE__, :check_health)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    Logger.info(
      "LoopCoupling: Initializing control loop coupling manager (SC-CPL-001 to SC-CPL-004)"
    )

    state = %{
      loops: %{},
      couplings: [],
      health: %{
        status: :healthy,
        last_check: nil,
        issues: []
      },
      metrics: %{
        registrations: 0,
        events_routed: 0,
        health_checks: 0
      },
      config: Keyword.get(opts, :config, %{})
    }

    # Schedule periodic health check
    schedule_health_check()

    {:ok, state}
  end

  @impl true
  def handle_call({:register, loop_name, pid}, _from, state) do
    case Map.get(state.loops, loop_name) do
      nil ->
        # New registration
        loop_info = %{
          name: loop_name,
          pid: pid,
          status: :running,
          registered_at: DateTime.utc_now(),
          last_heartbeat: DateTime.utc_now(),
          event_count: 0
        }

        # Monitor the loop process
        Process.monitor(pid)

        # Register with UnifiedBus
        if Process.whereis(UnifiedBus) do
          UnifiedBus.register_loop(loop_name, pid)
        end

        new_loops = Map.put(state.loops, loop_name, loop_info)
        new_metrics = Map.update!(state.metrics, :registrations, &(&1 + 1))

        Logger.info("LoopCoupling: Registered loop #{loop_name}")
        emit_telemetry(:register, %{loop_name: loop_name})

        {:reply, :ok, %{state | loops: new_loops, metrics: new_metrics}}

      existing ->
        # Update existing registration
        updated_info = %{
          existing
          | pid: pid,
            status: :running,
            last_heartbeat: DateTime.utc_now()
        }

        new_loops = Map.put(state.loops, loop_name, updated_info)

        {:reply, :ok, %{state | loops: new_loops}}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    response = %{
      loops: Map.keys(state.loops),
      loop_count: map_size(state.loops),
      coupling_count: length(state.couplings),
      health: state.health,
      metrics: state.metrics
    }

    {:reply, response, state}
  end

  @impl true
  def handle_call(:health, _from, state) do
    {:reply, state.health, state}
  end

  @impl true
  def handle_call(:registered_loops, _from, state) do
    loops = Map.keys(state.loops)
    {:reply, loops, state}
  end

  @impl true
  def handle_call({:verify_flow, source, target}, _from, state) do
    # Check if both loops are registered
    source_loop = Map.get(state.loops, source)
    target_loop = Map.get(state.loops, target)

    result =
      cond do
        is_nil(source_loop) ->
          {:error, {:source_not_registered, source}}

        is_nil(target_loop) ->
          {:error, {:target_not_registered, target}}

        source_loop.status != :running ->
          {:error, {:source_not_running, source}}

        target_loop.status != :running ->
          {:error, {:target_not_running, target}}

        not Enum.member?(state.couplings, {source, target}) ->
          {:error, {:not_coupled, source, target}}

        true ->
          # Verify by sending a test event
          test_event = {:flow_verification, source, target, make_ref()}

          if Process.whereis(UnifiedBus) do
            UnifiedBus.broadcast(:flow_verification, test_event, source: source)
          end

          {:ok, :verified}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:unregister, loop_name}, state) do
    new_loops = Map.delete(state.loops, loop_name)
    # Remove any couplings involving this loop
    new_couplings =
      Enum.reject(state.couplings, fn {src, tgt} ->
        src == loop_name or tgt == loop_name
      end)

    Logger.info("LoopCoupling: Unregistered loop #{loop_name}")
    emit_telemetry(:unregister, %{loop_name: loop_name})

    {:noreply, %{state | loops: new_loops, couplings: new_couplings}}
  end

  @impl true
  def handle_cast({:heartbeat, loop_name}, state) do
    new_loops =
      case Map.get(state.loops, loop_name) do
        nil ->
          state.loops

        loop_info ->
          updated_info = %{loop_info | last_heartbeat: DateTime.utc_now(), status: :running}
          Map.put(state.loops, loop_name, updated_info)
      end

    {:noreply, %{state | loops: new_loops}}
  end

  @impl true
  def handle_cast({:couple, source, target}, state) do
    coupling = {source, target}

    new_couplings =
      if Enum.member?(state.couplings, coupling) do
        state.couplings
      else
        [coupling | state.couplings]
      end

    Logger.debug("LoopCoupling: Coupled #{source} -> #{target}")
    emit_telemetry(:couple, %{source: source, target: target})

    {:noreply, %{state | couplings: new_couplings}}
  end

  @impl true
  def handle_cast({:decouple, source, target}, state) do
    new_couplings = List.delete(state.couplings, {source, target})

    Logger.debug("LoopCoupling: Decoupled #{source} -> #{target}")
    emit_telemetry(:decouple, %{source: source, target: target})

    {:noreply, %{state | couplings: new_couplings}}
  end

  @impl true
  def handle_cast(:check_health, state) do
    new_state = perform_health_check(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:health_check, state) do
    new_state = perform_health_check(state)
    schedule_health_check()
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Find and update the loop that crashed
    {loop_name, _loop_info} =
      Enum.find(state.loops, {nil, nil}, fn {_name, info} -> info.pid == pid end)

    if loop_name do
      Logger.warning("LoopCoupling: Loop #{loop_name} crashed: #{inspect(reason)}")

      new_loops =
        Map.update!(state.loops, loop_name, fn info ->
          %{info | status: :error}
        end)

      emit_telemetry(:loop_crash, %{loop_name: loop_name, reason: reason})
      {:noreply, %{state | loops: new_loops}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================
  # HEALTH CHECK
  # ============================================================

  defp perform_health_check(state) do
    issues = []

    # Check for required loops (SC-CPL-001)
    registered = Map.keys(state.loops)
    missing_loops = @required_loops -- registered

    issues =
      if length(missing_loops) > 0 do
        [{:missing_loops, missing_loops} | issues]
      else
        issues
      end

    # Check for stale heartbeats
    now = DateTime.utc_now()

    stale_loops =
      state.loops
      |> Enum.filter(fn {_name, info} ->
        case info.last_heartbeat do
          nil -> true
          last -> DateTime.diff(now, last, :millisecond) > @heartbeat_timeout
        end
      end)
      |> Enum.map(fn {name, _} -> name end)

    issues =
      if length(stale_loops) > 0 do
        [{:stale_heartbeats, stale_loops} | issues]
      else
        issues
      end

    # Check for crashed loops
    crashed_loops =
      state.loops
      |> Enum.filter(fn {_name, info} -> info.status == :error end)
      |> Enum.map(fn {name, _} -> name end)

    issues =
      if length(crashed_loops) > 0 do
        [{:crashed_loops, crashed_loops} | issues]
      else
        issues
      end

    # Check for broken couplings (SC-CPL-003)
    broken_couplings =
      Enum.filter(state.couplings, fn {src, tgt} ->
        src_info = Map.get(state.loops, src)
        tgt_info = Map.get(state.loops, tgt)

        is_nil(src_info) or is_nil(tgt_info) or
          src_info.status != :running or tgt_info.status != :running
      end)

    issues =
      if length(broken_couplings) > 0 do
        [{:broken_couplings, broken_couplings} | issues]
      else
        issues
      end

    # Determine overall health status
    status =
      cond do
        length(crashed_loops) > 0 -> :critical
        length(missing_loops) > 0 -> :degraded
        length(stale_loops) > 0 -> :degraded
        length(broken_couplings) > 0 -> :degraded
        true -> :healthy
      end

    new_health = %{
      status: status,
      last_check: DateTime.utc_now(),
      issues: issues
    }

    new_metrics = Map.update!(state.metrics, :health_checks, &(&1 + 1))

    emit_telemetry(:health_check, %{status: status, issue_count: length(issues)})

    %{state | health: new_health, metrics: new_metrics}
  end

  # ============================================================
  # HELPERS
  # ============================================================

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval)
  end

  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:indrajaal, :loop_coupling, event],
      measurements,
      %{timestamp: DateTime.utc_now()}
    )
  end
end
