defmodule Indrajaal.Control.AuditController do
  @moduledoc """
  L3 Control Layer — VSM System 3* sporadic audit controller.

  ## Design Intent
  Periodically performs a random-sample audit of subsystem health across the
  L3 control layer.  Each audit cycle selects a random subset of subsystems,
  verifies their health indicators, stores the result in ETS, and keeps the
  last 50 audit records in a rolling FIFO buffer.

  Failed audits (any subsystem reporting unhealthy) trigger a PubSub alert on
  `"control:audit:failed"` so observers can react without polling.

  The audit interval is configurable (default 60 s) and the controller can be
  triggered ad-hoc via `audit_now/0`.

  ## STAMP Constraints
  - SC-AUDIT-001: Audit trail MUST be maintained for all control actions
  - SC-VER-003: All violations MUST be logged and reported
  - SC-AUDIT-002: Audit records MUST be timestamped
  - SC-AUDIT-003: Failed audits MUST be escalated via PubSub
  - SC-AUDIT-004: ETS provides fast read access for dashboard queries

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L3 control layer) |
  """

  use GenServer

  require Logger

  @pubsub Indrajaal.PubSub
  @failed_topic "control:audit:failed"
  @default_interval_ms 60_000
  @max_history 50

  @type subsystem ::
          :budget_allocator
          | :authority_manager
          | :resource_scheduler
          | :unified_bus
          | :loop_coupling

  @type audit_status :: :passed | :failed | :skipped

  @type audit_record :: %{
          id: reference(),
          timestamp: DateTime.t(),
          subsystems_checked: [subsystem()],
          results: %{subsystem() => audit_status()},
          failures: [subsystem()],
          overall: audit_status(),
          duration_us: non_neg_integer()
        }

  @type controller_state :: %{
          table: :ets.tid(),
          history: [audit_record()],
          audit_count: non_neg_integer(),
          failure_count: non_neg_integer(),
          interval_ms: non_neg_integer()
        }

  @subsystems [
    :budget_allocator,
    :authority_manager,
    :resource_scheduler,
    :unified_bus,
    :loop_coupling
  ]

  @subsystem_modules %{
    budget_allocator: Indrajaal.Control.BudgetAllocator,
    authority_manager: Indrajaal.Control.AuthorityManager,
    resource_scheduler: Indrajaal.Control.ResourceScheduler,
    unified_bus: Indrajaal.Control.UnifiedBus,
    loop_coupling: Indrajaal.Control.LoopCoupling
  }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Start the AuditController GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Trigger an immediate audit cycle (returns when the audit finishes).
  """
  @spec audit_now() :: {:ok, audit_record()}
  def audit_now do
    GenServer.call(__MODULE__, :audit_now, 15_000)
  end

  @doc """
  Get the most recent audit record (fast ETS read).

  Returns `nil` if no audit has been performed yet.
  """
  @spec last_audit() :: audit_record() | nil
  def last_audit do
    table = :ets.whereis(:audit_results)

    if table != :undefined do
      case :ets.lookup(table, :latest) do
        [{:latest, record}] -> record
        [] -> nil
      end
    else
      nil
    end
  end

  @doc """
  Return the last `n` audit records from the in-memory history (newest first).
  """
  @spec audit_history(pos_integer()) :: [audit_record()]
  def audit_history(n \\ 10) when is_integer(n) and n > 0 do
    GenServer.call(__MODULE__, {:audit_history, n})
  end

  @doc """
  Return current controller statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    interval_ms = Keyword.get(opts, :interval_ms, @default_interval_ms)

    table =
      :ets.new(:audit_results, [
        :set,
        :named_table,
        :protected,
        read_concurrency: true
      ])

    state = %{
      table: table,
      history: [],
      audit_count: 0,
      failure_count: 0,
      interval_ms: interval_ms
    }

    schedule_audit(interval_ms)

    Logger.info(
      "[AuditController] L3 audit controller started interval=#{interval_ms}ms (SC-AUDIT-001)"
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:audit_now, _from, state) do
    {record, new_state} = run_audit(state)
    {:reply, {:ok, record}, new_state}
  end

  @impl true
  def handle_call({:audit_history, n}, _from, state) do
    history = Enum.take(state.history, n)
    {:reply, history, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      audit_count: state.audit_count,
      failure_count: state.failure_count,
      history_size: length(state.history),
      interval_ms: state.interval_ms,
      last_audit_at:
        case state.history do
          [latest | _] -> latest.timestamp
          [] -> nil
        end
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:audit_tick, state) do
    {_record, new_state} = run_audit(state)
    schedule_audit(state.interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private — audit logic
  # ---------------------------------------------------------------------------

  @spec run_audit(controller_state()) :: {audit_record(), controller_state()}
  defp run_audit(state) do
    start_us = System.monotonic_time(:microsecond)
    audit_id = make_ref()

    # Random sample: pick between 2 and all subsystems each cycle
    sample_count = Enum.random(2..length(@subsystems))
    chosen = @subsystems |> Enum.shuffle() |> Enum.take(sample_count)

    results =
      Enum.reduce(chosen, %{}, fn subsystem, acc ->
        status = check_subsystem(subsystem)
        Map.put(acc, subsystem, status)
      end)

    failures =
      results
      |> Enum.filter(fn {_k, v} -> v == :failed end)
      |> Enum.map(fn {k, _v} -> k end)

    overall = if failures == [], do: :passed, else: :failed

    duration_us = System.monotonic_time(:microsecond) - start_us

    record = %{
      id: audit_id,
      timestamp: DateTime.utc_now(),
      subsystems_checked: chosen,
      results: results,
      failures: failures,
      overall: overall,
      duration_us: duration_us
    }

    # Persist latest to ETS for fast reads
    :ets.insert(state.table, {:latest, record})

    # Broadcast failure alert if any subsystem failed (SC-AUDIT-003)
    if overall == :failed do
      broadcast_failure(record)

      Logger.warning(
        "[AuditController] Audit FAILED failures=#{inspect(failures)} duration_us=#{duration_us}"
      )
    else
      Logger.debug(
        "[AuditController] Audit passed checked=#{length(chosen)} duration_us=#{duration_us}"
      )
    end

    emit_telemetry(record)

    # Update rolling history (keep last @max_history)
    new_history =
      [record | state.history]
      |> Enum.take(@max_history)

    new_failure_count =
      if overall == :failed,
        do: state.failure_count + 1,
        else: state.failure_count

    new_state = %{
      state
      | history: new_history,
        audit_count: state.audit_count + 1,
        failure_count: new_failure_count
    }

    {record, new_state}
  end

  @spec check_subsystem(subsystem()) :: audit_status()
  defp check_subsystem(subsystem) do
    module = Map.fetch!(@subsystem_modules, subsystem)

    pid = Process.whereis(module)

    if pid == nil or not Process.alive?(pid) do
      :skipped
    else
      # A lightweight ping: call metrics/0 or stats/0 with a short timeout
      result =
        try do
          GenServer.call(pid, :metrics, 2_000)
          :passed
        rescue
          _ -> :failed
        catch
          :exit, _ -> :failed
        end

      result
    end
  rescue
    _ -> :skipped
  end

  defp broadcast_failure(record) do
    payload = %{
      audit_id: record.id,
      timestamp: record.timestamp,
      failures: record.failures,
      duration_us: record.duration_us
    }

    try do
      Phoenix.PubSub.broadcast(@pubsub, @failed_topic, {:audit_failed, payload})
    rescue
      _ -> :ok
    end
  end

  defp schedule_audit(interval_ms) do
    Process.send_after(self(), :audit_tick, interval_ms)
  end

  defp emit_telemetry(record) do
    :telemetry.execute(
      [:indrajaal, :control, :audit_controller, :audit],
      %{
        duration_us: record.duration_us,
        failure_count: length(record.failures),
        checked_count: length(record.subsystems_checked)
      },
      %{
        overall: record.overall,
        timestamp: record.timestamp
      }
    )
  end
end
