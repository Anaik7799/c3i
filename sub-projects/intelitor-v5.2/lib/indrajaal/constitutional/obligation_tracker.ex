defmodule Indrajaal.Constitutional.ObligationTracker do
  @moduledoc """
  Obligation Tracker — L0 Constitutional Layer

  ## Design Intent
  GenServer that tracks mandatory constitutional obligations and their compliance status.
  Constitutional obligations are duties the system MUST fulfill to remain in valid state.
  Examples: heartbeat publication, checkpoint creation, sovereignty verification.

  Each obligation has:
  - A unique name atom
  - A deadline interval (maximum allowed time between fulfillments)
  - The last time it was fulfilled
  - A compliance status (:compliant | :overdue | :violated)

  On every check cycle the tracker computes compliance status for all registered
  obligations and emits a compliance report. Violations trigger PubSub alerts
  and are stored in violation history.

  ## Human-Specified Intent
  <!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
  <!-- Last modified by: [Pending Human Author] on [TBD] -->

  ### Functional Intent
  [What this module MUST do from the human operator's perspective]

  ### UX Requirements
  [How the module MUST feel and behave for the operator]

  ### Safety Requirements
  [Non-negotiable safety behaviors]

  ### Override Instructions
  [Any instructions that override agent-generated behavior]
  <!-- END HUMAN-ONLY -->

  ## STAMP Constraints
  - SC-CONST-003: Constitutional obligations MUST be tracked and enforced
  - SC-SAFETY-009: Ψ₀ (Existence) validated for all operations
  - SC-SAFETY-018: Pre-execution validation completes all checks
  - SC-SAFETY-020: Auto-halt at threat threshold
  - SC-DMS-001: Heartbeat interval MUST be monitored

  ## Change History
  | Version | Date       | Author | Change                           |
  |---------|------------|--------|----------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation (L0)      |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @ets_table :constitutional_obligations
  @pubsub_topic "constitutional:obligations"
  @zenoh_topic "indrajaal/constitutional/obligations"
  @check_interval_ms 10_000

  # Obligations are :compliant when last_fulfilled_at is within the deadline.
  # They are :overdue when 1x–2x deadline has elapsed without fulfillment.
  # They are :violated when > 2x deadline has elapsed.
  @overdue_multiplier 1
  @violated_multiplier 2

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type obligation_name :: atom()
  @type actor :: String.t()
  @type compliance_status :: :compliant | :overdue | :violated

  @type obligation :: %{
          name: obligation_name(),
          description: String.t(),
          registered_by: actor(),
          registered_at: DateTime.t(),
          deadline_ms: non_neg_integer(),
          last_fulfilled_at: DateTime.t() | nil,
          status: compliance_status()
        }

  @type violation_record :: %{
          obligation_name: obligation_name(),
          detected_at: DateTime.t(),
          elapsed_ms: non_neg_integer(),
          deadline_ms: non_neg_integer()
        }

  @type state :: %{
          check_count: non_neg_integer(),
          violation_count: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Registers a new constitutional obligation.

  - `name` — unique atom identifying the obligation
  - `description` — human-readable description
  - `deadline_ms` — maximum milliseconds between fulfillments before becoming :overdue
  - `opts` — `:registered_by` (default: "system")

  Returns `{:ok, obligation()}` or `{:error, reason}`.
  """
  @spec register_obligation(obligation_name(), String.t(), non_neg_integer(), keyword()) ::
          {:ok, obligation()} | {:error, term()}
  def register_obligation(name, description, deadline_ms, opts \\ []) do
    GenServer.call(@name, {:register_obligation, name, description, deadline_ms, opts}, 10_000)
  end

  @doc """
  Records that an obligation has been fulfilled.

  Returns `{:ok, :fulfilled}` or `{:error, :not_found}`.
  """
  @spec check_compliance(obligation_name()) ::
          {:ok, :fulfilled} | {:error, term()}
  def check_compliance(name) do
    GenServer.call(@name, {:fulfill_obligation, name}, 10_000)
  end

  @doc """
  Returns the current compliance report for all registered obligations.
  """
  @spec compliance_report() :: map()
  def compliance_report do
    GenServer.call(@name, :compliance_report, 10_000)
  end

  @doc """
  Returns the violation history as a list of violation records.
  """
  @spec violation_history() :: list(violation_record())
  def violation_history do
    case :ets.whereis(@ets_table) do
      :undefined ->
        []

      _ ->
        case :ets.lookup(@ets_table, :__violation_history__) do
          [{:__violation_history__, history}] -> history
          _ -> []
        end
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])
    :ets.insert(@ets_table, {:__violation_history__, []})

    schedule_check()

    Logger.warning(
      "[ObligationTracker] L0 Obligation Tracker started — " <>
        "check_interval=#{@check_interval_ms}ms"
    )

    initial_state = %{
      check_count: 0,
      violation_count: 0
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_call({:register_obligation, name, description, deadline_ms, opts}, _from, state) do
    registered_by = Keyword.get(opts, :registered_by, "system")

    obligation = %{
      name: name,
      description: description,
      registered_by: registered_by,
      registered_at: DateTime.utc_now(),
      deadline_ms: deadline_ms,
      last_fulfilled_at: nil,
      status: :compliant
    }

    :ets.insert(@ets_table, {name, obligation})

    Logger.info(
      "[ObligationTracker] Obligation registered name=#{name} " <>
        "deadline=#{deadline_ms}ms by=#{registered_by}"
    )

    emit_telemetry(:registered, obligation, state)
    broadcast_pubsub({:obligation_registered, obligation})

    {:reply, {:ok, obligation}, state}
  end

  @impl true
  def handle_call({:fulfill_obligation, name}, _from, state) do
    case :ets.lookup(@ets_table, name) do
      [] ->
        {:reply, {:error, :not_found}, state}

      [{^name, obligation}] ->
        fulfilled = %{
          obligation
          | last_fulfilled_at: DateTime.utc_now(),
            status: :compliant
        }

        :ets.insert(@ets_table, {name, fulfilled})

        Logger.debug("[ObligationTracker] Obligation fulfilled name=#{name}")

        emit_telemetry(:fulfilled, fulfilled, state)
        broadcast_pubsub({:obligation_fulfilled, name})

        {:reply, {:ok, :fulfilled}, state}
    end
  end

  @impl true
  def handle_call(:compliance_report, _from, state) do
    obligations = list_all_obligations()
    now = DateTime.utc_now()

    statuses =
      Enum.map(obligations, fn ob ->
        {status, elapsed_ms} = compute_status(ob, now)
        {ob.name, %{status: status, elapsed_ms: elapsed_ms, deadline_ms: ob.deadline_ms}}
      end)
      |> Map.new()

    compliant_count = statuses |> Map.values() |> Enum.count(&(&1.status == :compliant))
    overdue_count = statuses |> Map.values() |> Enum.count(&(&1.status == :overdue))
    violated_count = statuses |> Map.values() |> Enum.count(&(&1.status == :violated))

    report = %{
      timestamp: now,
      total: map_size(statuses),
      compliant: compliant_count,
      overdue: overdue_count,
      violated: violated_count,
      all_compliant: overdue_count == 0 and violated_count == 0,
      statuses: statuses
    }

    {:reply, report, state}
  end

  @impl true
  def handle_info(:check_obligations, state) do
    new_violations = run_compliance_check()
    schedule_check()

    new_state = %{
      state
      | check_count: state.check_count + 1,
        violation_count: state.violation_count + length(new_violations)
    }

    {:noreply, new_state}
  end

  # ---------------------------------------------------------------------------
  # Private — compliance check
  # ---------------------------------------------------------------------------

  @spec run_compliance_check() :: list(violation_record())
  defp run_compliance_check do
    obligations = list_all_obligations()
    now = DateTime.utc_now()

    new_violations =
      Enum.flat_map(obligations, fn ob ->
        {status, elapsed_ms} = compute_status(ob, now)

        if ob.status != status do
          updated = %{ob | status: status}
          :ets.insert(@ets_table, {ob.name, updated})

          if status in [:overdue, :violated] do
            violation = %{
              obligation_name: ob.name,
              detected_at: now,
              elapsed_ms: elapsed_ms,
              deadline_ms: ob.deadline_ms
            }

            append_violation(violation)

            Logger.warning(
              "[ObligationTracker] Obligation #{status} name=#{ob.name} " <>
                "elapsed=#{elapsed_ms}ms deadline=#{ob.deadline_ms}ms"
            )

            broadcast_pubsub({:obligation_violation, violation})
            [violation]
          else
            []
          end
        else
          []
        end
      end)

    if length(new_violations) > 0 do
      emit_batch_telemetry(new_violations)
    end

    new_violations
  end

  @spec compute_status(obligation(), DateTime.t()) :: {compliance_status(), non_neg_integer()}
  defp compute_status(
         %{last_fulfilled_at: nil, registered_at: registered_at, deadline_ms: deadline_ms},
         now
       ) do
    elapsed_ms = DateTime.diff(now, registered_at, :millisecond)
    status = classify_elapsed(elapsed_ms, deadline_ms)
    {status, elapsed_ms}
  end

  defp compute_status(%{last_fulfilled_at: last, deadline_ms: deadline_ms}, now) do
    elapsed_ms = DateTime.diff(now, last, :millisecond)
    status = classify_elapsed(elapsed_ms, deadline_ms)
    {status, elapsed_ms}
  end

  @spec classify_elapsed(non_neg_integer(), non_neg_integer()) :: compliance_status()
  defp classify_elapsed(elapsed_ms, deadline_ms) do
    cond do
      elapsed_ms > deadline_ms * @violated_multiplier -> :violated
      elapsed_ms > deadline_ms * @overdue_multiplier -> :overdue
      true -> :compliant
    end
  end

  @spec list_all_obligations() :: list(obligation())
  defp list_all_obligations do
    case :ets.whereis(@ets_table) do
      :undefined ->
        []

      _ ->
        @ets_table
        |> :ets.tab2list()
        |> Enum.filter(fn {key, _val} -> is_atom(key) and key != :__violation_history__ end)
        |> Enum.map(fn {_key, val} -> val end)
    end
  end

  @spec append_violation(violation_record()) :: :ok
  defp append_violation(violation) do
    current =
      case :ets.lookup(@ets_table, :__violation_history__) do
        [{:__violation_history__, history}] -> history
        _ -> []
      end

    :ets.insert(@ets_table, {:__violation_history__, [violation | current]})
    :ok
  end

  defp schedule_check do
    Process.send_after(self(), :check_obligations, @check_interval_ms)
  end

  @spec emit_telemetry(atom(), obligation(), state()) :: :ok
  defp emit_telemetry(event, obligation, state) do
    try do
      :telemetry.execute(
        [:indrajaal, :constitutional, :obligation, event],
        %{
          check_count: state.check_count,
          violation_count: state.violation_count
        },
        %{
          topic: @zenoh_topic,
          obligation_name: obligation.name,
          deadline_ms: obligation.deadline_ms,
          status: obligation.status
        }
      )
    rescue
      err ->
        Logger.warning("[ObligationTracker] telemetry emit failed: #{inspect(err)}")
    end

    :ok
  end

  @spec emit_batch_telemetry(list(violation_record())) :: :ok
  defp emit_batch_telemetry(violations) do
    try do
      :telemetry.execute(
        [:indrajaal, :constitutional, :obligation, :violations_detected],
        %{violation_count: length(violations)},
        %{topic: @zenoh_topic}
      )
    rescue
      err ->
        Logger.warning("[ObligationTracker] batch telemetry emit failed: #{inspect(err)}")
    end

    :ok
  end

  @spec broadcast_pubsub(term()) :: :ok
  defp broadcast_pubsub(message) do
    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, message)
    rescue
      err ->
        Logger.warning("[ObligationTracker] PubSub broadcast failed: #{inspect(err)}")
    end

    :ok
  end
end
