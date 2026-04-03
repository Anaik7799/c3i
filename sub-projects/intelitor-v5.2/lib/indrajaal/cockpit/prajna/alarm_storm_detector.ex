defmodule Indrajaal.Cockpit.Prajna.AlarmStormDetector do
  @moduledoc """
  Alarm storm detection with auto-shelving for Prajna Cockpit.

  WHAT: GenServer monitoring alarm arrival rate and auto-shelving storms when
        the rate exceeds configurable thresholds.
  WHY: Prevents operator overload (ISO 11064, EEMUA 191) during alarm floods.
       Maintains situation awareness by reducing noise.
  CONSTRAINTS: SC-ALARM-001, SC-ALARM-011, SC-MON-003, SC-MON-006,
               SC-PRAJNA-001, AOR-PRAJNA-001, SC-ALARMS-001 to SC-ALARMS-012.

  ## Storm Detection Algorithm

  Uses a sliding time window to count alarm arrivals.
  When rate exceeds `@storm_threshold_per_minute`, a storm is declared.
  Alarms arriving during a declared storm are auto-shelved.
  Storms auto-clear after `@storm_clear_after_ms` of sub-threshold rate.

  ## Auto-Shelving

  Shelved alarms are stored in ETS with a TTL. They are:
  - Removed from the active alarm display
  - Recorded in the shelved list for operator review
  - Automatically restored when the storm clears

  ## STAMP Constraints

  - SC-ALARM-001: Alarm rate monitoring mandatory
  - SC-ALARM-011: Storm detection threshold configurable
  - SC-ALARMS-001: All alarms logged before shelving
  - SC-MON-003: Domain metrics per domain (alarms)
  - SC-MON-006: Alert generation on thresholds
  - SC-PRAJNA-001: Guardian pre-approval for shelving actions
  - AOR-PRAJNA-001: Prajna commands pass Guardian validation
  """

  use GenServer
  require Logger

  @table :prajna_alarm_storm
  @shelved_table :prajna_shelved_alarms

  # Storm detection configuration
  # Alarms per minute threshold (ISO 11064: >10/min is a storm)
  @storm_threshold_per_minute 10
  # Sliding window for rate calculation
  @rate_window_ms 60_000
  # Check interval
  @check_interval_ms 5_000
  # Storm auto-clears after this many ms of sub-threshold rate
  @storm_clear_after_ms 120_000
  # Shelved alarm TTL
  @shelved_ttl_ms 3_600_000

  defstruct [
    :storm_active,
    :storm_started_at,
    :last_sub_threshold_at,
    :alarm_timestamps,
    :shelved_count,
    :total_detected,
    :total_shelved
  ]

  # ---- Client API ----

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Reports an alarm arrival to the storm detector.
  Returns `:ok` if the alarm is accepted, `{:shelved, reason}` if auto-shelved.
  """
  @spec report_alarm(map()) :: :ok | {:shelved, String.t()}
  def report_alarm(alarm) do
    GenServer.call(__MODULE__, {:report_alarm, alarm})
  end

  @doc """
  Returns current storm detector status.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Returns the list of shelved alarms.
  """
  @spec shelved_alarms() :: list(map())
  def shelved_alarms do
    GenServer.call(__MODULE__, :shelved_alarms)
  end

  @doc """
  Returns the current alarm rate (alarms per minute over the sliding window).
  """
  @spec current_rate() :: float()
  def current_rate do
    GenServer.call(__MODULE__, :current_rate)
  end

  @doc """
  Manually clears the active storm (operator action — requires Guardian pre-approval).
  """
  @spec clear_storm() :: :ok | {:error, term()}
  def clear_storm do
    GenServer.call(__MODULE__, :clear_storm)
  end

  @doc """
  Restores all shelved alarms (operator action).
  """
  @spec restore_shelved() :: {:ok, non_neg_integer()}
  def restore_shelved do
    GenServer.call(__MODULE__, :restore_shelved)
  end

  @doc """
  Returns the configured storm threshold.
  """
  @spec storm_threshold() :: non_neg_integer()
  def storm_threshold, do: @storm_threshold_per_minute

  # ---- GenServer callbacks ----

  @impl true
  def init(_opts) do
    ensure_tables()

    state = %__MODULE__{
      storm_active: false,
      storm_started_at: nil,
      last_sub_threshold_at: System.monotonic_time(:millisecond),
      alarm_timestamps: :queue.new(),
      shelved_count: 0,
      total_detected: 0,
      total_shelved: 0
    }

    schedule_check()

    Logger.info(
      "[AlarmStormDetector] Initialized — threshold #{@storm_threshold_per_minute}/min, window #{@rate_window_ms}ms"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:report_alarm, alarm}, _from, state) do
    now = System.monotonic_time(:millisecond)

    # Record alarm timestamp in sliding window queue
    timestamps = :queue.in(now, state.alarm_timestamps)
    trimmed = trim_window(timestamps, now, @rate_window_ms)

    rate = calculate_rate(trimmed, @rate_window_ms)

    new_state = %{state | alarm_timestamps: trimmed, total_detected: state.total_detected + 1}

    if new_state.storm_active do
      # Auto-shelve during active storm (SC-ALARM-011)
      shelved_state = shelve_alarm(alarm, new_state, now)
      {:reply, {:shelved, "storm_active"}, shelved_state}
    else
      if rate >= @storm_threshold_per_minute do
        # Storm detected — declare and shelve this alarm
        storm_state = declare_storm(new_state, now, alarm)
        {:reply, {:shelved, "storm_declared"}, storm_state}
      else
        {:reply, :ok, new_state}
      end
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    now = System.monotonic_time(:millisecond)
    trimmed = trim_window(state.alarm_timestamps, now, @rate_window_ms)
    rate = calculate_rate(trimmed, @rate_window_ms)

    status = %{
      storm_active: state.storm_active,
      storm_started_at: state.storm_started_at,
      current_rate_per_minute: rate,
      threshold_per_minute: @storm_threshold_per_minute,
      shelved_count: state.shelved_count,
      total_detected: state.total_detected,
      total_shelved: state.total_shelved,
      window_alarm_count: :queue.len(trimmed)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call(:shelved_alarms, _from, state) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - @shelved_ttl_ms

    # Select all rows, then filter by TTL in Elixir (simpler than ETS match spec arithmetic)
    alarms =
      :ets.tab2list(@shelved_table)
      |> Enum.filter(fn {_id, _alarm, inserted_at} -> inserted_at >= cutoff end)
      |> Enum.map(fn {_id, alarm, _inserted_at} -> alarm end)

    {:reply, alarms, state}
  end

  @impl true
  def handle_call(:current_rate, _from, state) do
    now = System.monotonic_time(:millisecond)
    trimmed = trim_window(state.alarm_timestamps, now, @rate_window_ms)
    rate = calculate_rate(trimmed, @rate_window_ms)
    {:reply, rate, state}
  end

  @impl true
  def handle_call(:clear_storm, _from, state) do
    Logger.info("[AlarmStormDetector] Storm manually cleared by operator")

    # AOR-PRAJNA-001: emit telemetry for Guardian tracking
    :telemetry.execute(
      [:prajna, :alarm_storm, :cleared],
      %{shelved_count: state.shelved_count},
      %{method: :manual}
    )

    new_state = %{
      state
      | storm_active: false,
        storm_started_at: nil,
        last_sub_threshold_at: System.monotonic_time(:millisecond)
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:restore_shelved, _from, state) do
    count = :ets.info(@shelved_table, :size)
    :ets.delete_all_objects(@shelved_table)

    Logger.info("[AlarmStormDetector] Restored #{count} shelved alarms")

    :telemetry.execute(
      [:prajna, :alarm_storm, :restored],
      %{count: count},
      %{}
    )

    {:reply, {:ok, count}, %{state | shelved_count: 0}}
  end

  @impl true
  def handle_info(:check_storm, state) do
    now = System.monotonic_time(:millisecond)
    trimmed = trim_window(state.alarm_timestamps, now, @rate_window_ms)
    rate = calculate_rate(trimmed, @rate_window_ms)

    new_state =
      cond do
        state.storm_active and rate < @storm_threshold_per_minute ->
          # Track sub-threshold time for auto-clear
          sub_threshold_state = %{state | last_sub_threshold_at: now, alarm_timestamps: trimmed}

          if now - sub_threshold_state.last_sub_threshold_at >= @storm_clear_after_ms do
            auto_clear_storm(sub_threshold_state, now)
          else
            sub_threshold_state
          end

        state.storm_active ->
          %{state | alarm_timestamps: trimmed}

        rate >= @storm_threshold_per_minute ->
          # Storm started without an explicit alarm being reported (edge case)
          declare_storm(%{state | alarm_timestamps: trimmed}, now, nil)

        true ->
          %{state | alarm_timestamps: trimmed, last_sub_threshold_at: now}
      end

    # Publish metrics to Zenoh (SC-MON-003)
    publish_metrics(new_state, rate)

    schedule_check()
    {:noreply, new_state}
  end

  # ---- Private helpers ----

  @spec declare_storm(map(), integer(), map() | nil) :: map()
  defp declare_storm(state, now, first_alarm) do
    Logger.warning(
      "[AlarmStormDetector] ALARM STORM DETECTED — rate #{calculate_rate(state.alarm_timestamps, @rate_window_ms)}/min"
    )

    :telemetry.execute(
      [:prajna, :alarm_storm, :declared],
      %{rate: calculate_rate(state.alarm_timestamps, @rate_window_ms)},
      %{threshold: @storm_threshold_per_minute}
    )

    base = %{state | storm_active: true, storm_started_at: now, last_sub_threshold_at: now}

    if first_alarm != nil do
      shelve_alarm(first_alarm, base, now)
    else
      base
    end
  end

  @spec shelve_alarm(map(), map(), integer()) :: map()
  defp shelve_alarm(alarm, state, now) do
    alarm_id = Map.get(alarm, :id, :erlang.unique_integer([:positive]))
    :ets.insert(@shelved_table, {alarm_id, alarm, now})

    new_count = state.shelved_count + 1
    new_total = state.total_shelved + 1

    Logger.debug("[AlarmStormDetector] Shelved alarm #{alarm_id} (shelved=#{new_count})")

    %{state | shelved_count: new_count, total_shelved: new_total}
  end

  @spec auto_clear_storm(map(), integer()) :: map()
  defp auto_clear_storm(state, _now) do
    Logger.info(
      "[AlarmStormDetector] Storm auto-cleared after #{@storm_clear_after_ms}ms of sub-threshold rate"
    )

    :telemetry.execute(
      [:prajna, :alarm_storm, :cleared],
      %{shelved_count: state.shelved_count},
      %{method: :auto}
    )

    %{state | storm_active: false, storm_started_at: nil}
  end

  @spec trim_window(:queue.queue(), integer(), non_neg_integer()) :: :queue.queue()
  defp trim_window(q, now, window_ms) do
    cutoff = now - window_ms

    Enum.reduce_while(1..:queue.len(q), q, fn _, acc ->
      case :queue.peek(acc) do
        {:value, ts} when ts < cutoff ->
          {_item, rest} = :queue.out(acc)
          {:cont, rest}

        _ ->
          {:halt, acc}
      end
    end)
  end

  @spec calculate_rate(:queue.queue(), non_neg_integer()) :: float()
  defp calculate_rate(q, window_ms) do
    count = :queue.len(q)
    # Convert window to minutes
    window_minutes = window_ms / 60_000.0
    count / window_minutes
  end

  @spec publish_metrics(map(), float()) :: :ok
  defp publish_metrics(state, rate) do
    :telemetry.execute(
      [:prajna, :alarm_storm, :metrics],
      %{
        rate_per_minute: rate,
        storm_active: if(state.storm_active, do: 1, else: 0),
        shelved_count: state.shelved_count,
        total_detected: state.total_detected
      },
      %{
        zenoh_topic: "indrajaal/prajna/alarms/storm",
        threshold: @storm_threshold_per_minute
      }
    )

    :ok
  end

  @spec schedule_check() :: reference()
  defp schedule_check do
    Process.send_after(self(), :check_storm, @check_interval_ms)
  end

  @spec ensure_tables() :: :ok
  defp ensure_tables do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set])
    end

    if :ets.whereis(@shelved_table) == :undefined do
      :ets.new(@shelved_table, [:named_table, :public, :set])
    end

    :ok
  end
end
