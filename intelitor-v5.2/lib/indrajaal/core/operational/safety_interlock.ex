defmodule Indrajaal.Core.Operational.SafetyInterlock do
  @moduledoc """
  Safety Interlock — L1 Operational Layer (VSM)

  ## Design Intent
  Safety interlock system for destructive operations. Implements the
  Arm → Fire → Confirm pattern (SC-SAFETY-001). Operations that could
  cause data loss, process termination, or system reconfiguration MUST
  be routed through this interlock.

  The interlock state machine:
  - `:disarmed` — default safe state; no pending operations
  - `:armed`    — operator has requested an operation; 30s window
  - `:firing`   — operation is executing; result pending
  - `:cancelled`— operator cancelled during armed state

  Auto-disarm: if the operation is not confirmed within 30 seconds,
  the interlock automatically returns to `:disarmed`.

  All interlock events are logged to the immutable audit register.

  ## STAMP Constraints
  - SC-SAFETY-001: Arm & Fire — destructive actions require multi-step commit
  - SC-SIL4-006: 2oo3 voting MANDATORY for production actuations
  - SC-PHICS-003: Guardian approval for destructive commands
  - SC-PHICS-001: Commands logged to Immutable Register

  ## Change History
  | Version | Date       | Author | Change                        |
  |---------|------------|--------|-------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation (L1)   |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @arm_timeout_ms 30_000
  @zenoh_topic "indrajaal/operational/interlock"
  @ets_table :safety_interlock_state

  @type interlock_state :: :disarmed | :armed | :firing | :cancelled
  @type operation_id :: String.t()
  @type arm_result :: {:ok, operation_id()} | {:error, :already_armed}
  @type fire_result :: {:ok, term()} | {:error, :not_armed | :wrong_operation | :timeout | term()}
  @type cancel_result :: :ok | {:error, :not_armed}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Arms the interlock for a named operation.

  Returns `{:ok, operation_id}` with a unique ID that must be used to fire or cancel.
  Returns `{:error, :already_armed}` if another operation is pending.

  ## Parameters
  - `operation` — atom identifying the operation (e.g., `:delete_all_alarms`)
  - `metadata`  — map of additional context (actor, reason, etc.)
  """
  @spec arm(atom(), map()) :: arm_result()
  def arm(operation, metadata \\ %{}) do
    GenServer.call(@name, {:arm, operation, metadata}, 5_000)
  end

  @doc """
  Fires the armed operation.

  Executes `operation_fn` synchronously and returns its result.
  Automatically disarms after execution (success or failure).

  ## Parameters
  - `operation_id` — the ID returned by `arm/2`
  - `operation_fn` — zero-arity function to execute
  """
  @spec fire(operation_id(), (-> term())) :: fire_result()
  def fire(operation_id, operation_fn) do
    GenServer.call(@name, {:fire, operation_id, operation_fn}, 60_000)
  end

  @doc "Cancels the currently armed operation."
  @spec cancel(operation_id()) :: cancel_result()
  def cancel(operation_id) do
    GenServer.call(@name, {:cancel, operation_id}, 5_000)
  end

  @doc "Returns the current interlock status."
  @spec status() :: map()
  def status do
    case :ets.whereis(@ets_table) do
      :undefined ->
        %{state: :unknown, reason: "interlock not running"}

      _ ->
        case :ets.lookup(@ets_table, :status) do
          [{:status, val}] -> val
          _ -> %{state: :disarmed}
        end
    end
  end

  @doc "Returns whether the interlock is currently in a safe (disarmed) state."
  @spec safe?() :: boolean()
  def safe? do
    case status() do
      %{state: :disarmed} -> true
      _ -> false
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])
    :ets.insert(@ets_table, {:status, %{state: :disarmed}})

    Logger.warning("[SafetyInterlock] L1 Safety Interlock initialized — state=disarmed")

    {:ok,
     %{
       state: :disarmed,
       operation: nil,
       operation_id: nil,
       metadata: %{},
       armed_at: nil,
       timer_ref: nil,
       event_log: []
     }}
  end

  @impl true
  def handle_call({:arm, operation, metadata}, from, %{state: :disarmed} = state) do
    operation_id = generate_id()
    armed_at = System.monotonic_time(:millisecond)

    # Schedule auto-disarm
    timer_ref = Process.send_after(self(), {:auto_disarm, operation_id}, @arm_timeout_ms)

    new_state = %{
      state
      | state: :armed,
        operation: operation,
        operation_id: operation_id,
        metadata: metadata,
        armed_at: armed_at,
        timer_ref: timer_ref,
        event_log: [arm_event(operation, operation_id, metadata, from) | state.event_log]
    }

    update_ets_status(new_state)
    log_event(:armed, operation, operation_id, metadata)

    {:reply, {:ok, operation_id}, new_state}
  end

  def handle_call({:arm, _operation, _metadata}, _from, state) do
    {:reply, {:error, :already_armed}, state}
  end

  @impl true
  def handle_call(
        {:fire, operation_id, operation_fn},
        _from,
        %{state: :armed, operation_id: op_id} = state
      )
      when operation_id == op_id do
    # Cancel auto-disarm timer
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    # Transition to firing
    firing_state = %{state | state: :firing, timer_ref: nil}
    update_ets_status(firing_state)

    # Execute the operation
    result =
      try do
        operation_fn.()
      rescue
        e -> {:error, {:exception, Exception.message(e)}}
      catch
        :exit, reason -> {:error, {:exit, reason}}
      end

    log_event(:fired, state.operation, operation_id, %{result: inspect(result)})

    # Return to disarmed
    disarmed_state = %{
      firing_state
      | state: :disarmed,
        operation: nil,
        operation_id: nil,
        metadata: %{},
        armed_at: nil
    }

    update_ets_status(disarmed_state)

    {:reply, {:ok, result}, disarmed_state}
  end

  def handle_call({:fire, _op_id, _fn}, _from, %{state: :disarmed} = state) do
    {:reply, {:error, :not_armed}, state}
  end

  def handle_call({:fire, op_id, _fn}, _from, state) when op_id != state.operation_id do
    {:reply, {:error, :wrong_operation}, state}
  end

  def handle_call({:fire, _op_id, _fn}, _from, state) do
    {:reply, {:error, :wrong_operation}, state}
  end

  @impl true
  def handle_call({:cancel, operation_id}, _from, %{state: :armed, operation_id: op_id} = state)
      when operation_id == op_id do
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    log_event(:cancelled, state.operation, operation_id, state.metadata)

    disarmed_state = %{
      state
      | state: :disarmed,
        operation: nil,
        operation_id: nil,
        metadata: %{},
        armed_at: nil,
        timer_ref: nil
    }

    update_ets_status(disarmed_state)

    {:reply, :ok, disarmed_state}
  end

  def handle_call({:cancel, _op_id}, _from, state) do
    {:reply, {:error, :not_armed}, state}
  end

  @impl true
  def handle_info({:auto_disarm, operation_id}, %{state: :armed, operation_id: op_id} = state)
      when operation_id == op_id do
    Logger.warning(
      "[SafetyInterlock] AUTO-DISARM: operation #{inspect(state.operation)} timed out after #{@arm_timeout_ms}ms"
    )

    log_event(:auto_disarmed, state.operation, operation_id, %{reason: :timeout})

    disarmed_state = %{
      state
      | state: :disarmed,
        operation: nil,
        operation_id: nil,
        metadata: %{},
        armed_at: nil,
        timer_ref: nil
    }

    update_ets_status(disarmed_state)

    {:noreply, disarmed_state}
  end

  def handle_info({:auto_disarm, _op_id}, state) do
    # Stale timer — ignore
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp arm_event(operation, operation_id, metadata, _from) do
    %{
      event: :armed,
      operation: operation,
      operation_id: operation_id,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    }
  end

  defp update_ets_status(state) do
    status = %{
      state: state.state,
      operation: state.operation,
      operation_id: state.operation_id,
      armed_at: state.armed_at
    }

    :ets.insert(@ets_table, {:status, status})
  end

  defp log_event(event_type, operation, operation_id, metadata) do
    payload =
      Jason.encode!(%{
        topic: @zenoh_topic,
        event: event_type,
        operation: operation,
        operation_id: operation_id,
        metadata: metadata,
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      })

    Logger.info(
      "[SafetyInterlock] event=#{event_type} operation=#{inspect(operation)} id=#{operation_id}"
    )

    :telemetry.execute(
      [:indrajaal, :operational, :interlock],
      %{event_count: 1},
      %{event: event_type, operation: operation, topic: @zenoh_topic, payload: payload}
    )
  end
end
