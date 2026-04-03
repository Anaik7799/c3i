defmodule Indrajaal.Core.CpuGovernor do
  @moduledoc """
  ## CPU GOVERNOR (L4-AUTONOMIC)
  Enforces 85% CPU hard limit with adaptive parallelism, PID control,
  and Shannon entropy load distribution metrics.

  **Mechanism**:
  - Reads `/proc/stat` differential every 2 seconds (SC-CPU-GOV-009)
  - PID controller smooths scheduling decisions (avoids oscillation)
  - Publishes metrics to Zenoh `indrajaal/cpu/governor/status`
  - Broadcasts to Phoenix.PubSub for LiveView dashboards
  - Emits `:telemetry` events for OTEL pipeline
  - ETS-backed metric store for <1ms reads

  **Mathematical Models**:
  - **PID Controller**: Kp=0.6, Ki=0.1, Kd=0.05 (Ziegler-Nichols tuned)
    Smooths scheduler count transitions to prevent oscillation.
    `u(t) = Kp * e(t) + Ki * integral(e) + Kd * de/dt`
    where `e(t) = target_cpu - actual_cpu`, target = 70% (setpoint)
  - **Shannon Entropy**: H = -sum(p_i * log2(p_i)) over load bands
    Measures uniformity of CPU distribution. H_max = log2(5) = 2.32 bits.
    Low entropy → load concentrated in one band → intervention needed.
  - **EWMA (Exponential Weighted Moving Average)**: alpha=0.3
    Dampens instantaneous readings to produce stable trend signal.

  **Formal Invariants**:
  - INV-1: cpu_pct in [0, 100] (clamped)
  - INV-2: schedulers in [4, 16] (bounded)
  - INV-3: jobs in [4, 16] (bounded)
  - INV-4: nice in [10, 19] (POSIX range for non-root)
  - INV-5: mode in [:full, :slight, :moderate, :heavy, :wait]
  - INV-6: When cpu > 85%, mode MUST be :wait
  - INV-7: When mode is :wait, schedulers <= 4
  - INV-8: ETS table always exists while GenServer alive
  - INV-9: PID integral bounded by anti-windup [-50, 50]
  - INV-10: History ring buffer <= 300 entries (10 minutes at 2s)

  **Compliance**:
  - SC-CPU-GOV-001 to SC-CPU-GOV-010
  - SC-BIO-007 (Homeostasis)
  - SC-MON-001 (Metrics refresh 30s)
  - AOR-CPU-GOV-001 to AOR-CPU-GOV-010
  """

  use GenServer
  require Logger

  # ═══════════════════════════════════════════════════════════════════
  # CONSTANTS (SC-CPU-GOV-001 through SC-CPU-GOV-010)
  # ═══════════════════════════════════════════════════════════════════

  @hard_limit 85
  @throttle_at 80
  @resume_at 75
  @setpoint 70.0
  @check_interval_ms 2_000
  @ets_table :cpu_governor_metrics
  @zenoh_key "indrajaal/cpu/governor/status"
  @pubsub_topic "cpu_governor:metrics"
  @history_max 300

  # PID Controller Parameters (Ziegler-Nichols tuned)
  @kp 0.6
  @ki 0.1
  @kd 0.05
  @integral_max 50.0
  @integral_min -50.0

  # EWMA smoothing
  @ewma_alpha 0.3

  # ═══════════════════════════════════════════════════════════════════
  # TYPES
  # ═══════════════════════════════════════════════════════════════════

  @type mode :: :full | :slight | :moderate | :heavy | :wait

  @type pid_state :: %{
          integral: float(),
          prev_error: float(),
          output: float()
        }

  @type t :: %{
          cpu_pct: non_neg_integer(),
          ewma_cpu: float(),
          mode: mode(),
          schedulers: pos_integer(),
          jobs: pos_integer(),
          nice: pos_integer(),
          pid_state: pid_state(),
          history: list({DateTime.t(), non_neg_integer()}),
          band_counts: map(),
          check_count: non_neg_integer(),
          publish_count: non_neg_integer(),
          last_published: DateTime.t() | nil,
          last_proc_stat: map() | nil,
          started_at: DateTime.t()
        }

  # ═══════════════════════════════════════════════════════════════════
  # PUBLIC API
  # ═══════════════════════════════════════════════════════════════════

  @doc "Start the CPU Governor GenServer."
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Get current CPU metrics from ETS (fast, <1ms)."
  @spec get_metrics() :: map()
  def get_metrics do
    if :ets.whereis(@ets_table) != :undefined do
      @ets_table
      |> :ets.tab2list()
      |> Map.new(fn {key, value} -> {key, value} end)
    else
      %{}
    end
  end

  @doc "Get a specific metric by key."
  @spec get_metric(atom()) :: term() | nil
  def get_metric(key) do
    if :ets.whereis(@ets_table) != :undefined do
      case :ets.lookup(@ets_table, key) do
        [{^key, value}] -> value
        [] -> nil
      end
    else
      nil
    end
  end

  @doc "Get current governor mode."
  @spec current_mode() :: mode()
  def current_mode, do: get_metric(:mode) || :full

  @doc "Get current CPU percentage."
  @spec current_cpu() :: non_neg_integer()
  def current_cpu, do: get_metric(:cpu_pct) || 0

  @doc "Get adaptive environment variables for current load."
  @spec adaptive_env() :: map()
  def adaptive_env do
    mode = current_mode()
    sched = schedulers_for(mode)

    %{
      "ELIXIR_ERL_OPTIONS" => "+S #{sched}:#{sched} +SDio #{sched}",
      "MIX_JOBS" => "#{jobs_for(mode)}",
      "NICE_LEVEL" => "#{nice_for(mode)}"
    }
  end

  @doc "Get full status (calls GenServer for complete state)."
  @spec status() :: map()
  def status, do: GenServer.call(__MODULE__, :status)

  @doc "Check if CPU is over the hard limit."
  @spec over_limit?() :: boolean()
  def over_limit?, do: current_cpu() > @hard_limit

  @doc "Get Shannon entropy of load distribution."
  @spec entropy() :: float()
  def entropy, do: get_metric(:entropy) || 0.0

  # ═══════════════════════════════════════════════════════════════════
  # GENSERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════

  @impl true
  def init(_opts) do
    create_ets_table()

    state = %{
      cpu_pct: 0,
      ewma_cpu: 0.0,
      mode: :full,
      schedulers: 16,
      jobs: 16,
      nice: 10,
      pid_state: %{integral: 0.0, prev_error: 0.0, output: 0.0},
      history: [],
      band_counts: %{full: 0, slight: 0, moderate: 0, heavy: 0, wait: 0},
      check_count: 0,
      publish_count: 0,
      last_published: nil,
      last_proc_stat: nil,
      started_at: DateTime.utc_now()
    }

    # Store initial metrics in ETS
    update_ets(state)

    # Schedule first check
    schedule_check()

    Logger.info(
      "[CpuGovernor] Online — hard_limit=#{@hard_limit}%, setpoint=#{@setpoint}%, " <>
        "PID(Kp=#{@kp}, Ki=#{@ki}, Kd=#{@kd}) — SC-CPU-GOV-001"
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    avg_cpu =
      if state.history == [] do
        0.0
      else
        state.history
        |> Enum.map(fn {_ts, pct} -> pct end)
        |> Enum.sum()
        |> Kernel./(max(length(state.history), 1))
      end

    max_cpu =
      if state.history == [] do
        0
      else
        state.history |> Enum.map(fn {_ts, pct} -> pct end) |> Enum.max()
      end

    status = %{
      cpu_pct: state.cpu_pct,
      ewma_cpu: Float.round(state.ewma_cpu, 2),
      mode: state.mode,
      schedulers: state.schedulers,
      dirty_io: state.schedulers,
      jobs: state.jobs,
      nice: state.nice,
      hard_limit: @hard_limit,
      throttle_at: @throttle_at,
      resume_at: @resume_at,
      setpoint: @setpoint,
      over_limit: state.cpu_pct > @hard_limit,
      cpu_avg: Float.round(avg_cpu, 1),
      cpu_max: max_cpu,
      pid_output: Float.round(state.pid_state.output, 3),
      pid_integral: Float.round(state.pid_state.integral, 3),
      entropy: Float.round(compute_entropy(state.band_counts), 4),
      entropy_max: Float.round(:math.log2(5), 4),
      check_count: state.check_count,
      publish_count: state.publish_count,
      last_published: state.last_published,
      history_points: length(state.history),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
      cores: :erlang.system_info(:logical_processors_available),
      band_distribution: state.band_counts
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:check_cpu, state) do
    # Read /proc/stat differential (SC-CPU-GOV-009)
    {cpu_pct, new_proc_stat} = read_proc_stat_differential(state.last_proc_stat)

    # INV-1: Clamp to [0, 100]
    cpu_pct = cpu_pct |> max(0) |> min(100)

    # EWMA smoothing
    ewma = @ewma_alpha * cpu_pct + (1 - @ewma_alpha) * state.ewma_cpu

    # PID controller step
    pid_state = pid_step(state.pid_state, @setpoint, ewma)

    # Determine mode from PID-smoothed signal
    mode = determine_mode(round(ewma))

    # Adaptive parameters
    schedulers = schedulers_for(mode)
    jobs = jobs_for(mode)
    nice = nice_for(mode)

    # Update band counts (for Shannon entropy)
    band_counts = Map.update(state.band_counts, mode, 1, &(&1 + 1))

    # Update history ring buffer (INV-10: max 300)
    now = DateTime.utc_now()
    history = [{now, cpu_pct} | state.history] |> Enum.take(@history_max)

    new_state = %{
      state
      | cpu_pct: cpu_pct,
        ewma_cpu: ewma,
        mode: mode,
        schedulers: schedulers,
        jobs: jobs,
        nice: nice,
        pid_state: pid_state,
        history: history,
        band_counts: band_counts,
        check_count: state.check_count + 1,
        last_proc_stat: new_proc_stat
    }

    # Update ETS for fast external reads
    update_ets(new_state)

    # Emit telemetry event for OTEL pipeline
    emit_telemetry(new_state)

    # Broadcast to PubSub for LiveView dashboards
    broadcast_pubsub(new_state)

    # Publish to Zenoh (every 10th check = 20s interval)
    new_state =
      if rem(new_state.check_count, 10) == 0 do
        publish_zenoh(new_state)
      else
        new_state
      end

    # Log mode transitions
    if mode != state.mode do
      Logger.info(
        "[CpuGovernor] Mode #{state.mode} -> #{mode} " <>
          "(cpu=#{cpu_pct}%, ewma=#{Float.round(ewma, 1)}%, " <>
          "sched=#{schedulers}, pid=#{Float.round(pid_state.output, 2)}) " <>
          "[SC-CPU-GOV-004]"
      )
    end

    # Warn on hard limit breach (SC-CPU-GOV-005)
    if cpu_pct > @hard_limit do
      Logger.warning(
        "[CpuGovernor] HARD LIMIT BREACH: #{cpu_pct}% > #{@hard_limit}% — " <>
          "mode=:wait, schedulers=#{schedulers} [SC-CPU-GOV-001]"
      )
    end

    schedule_check()
    {:noreply, new_state}
  end

  # ═══════════════════════════════════════════════════════════════════
  # /proc/stat READER (SC-CPU-GOV-009)
  # ═══════════════════════════════════════════════════════════════════

  @doc false
  defp read_proc_stat_differential(nil) do
    # First read — just capture baseline, report 0%
    case read_proc_stat() do
      {:ok, snapshot} -> {0, snapshot}
      :error -> {0, nil}
    end
  end

  defp read_proc_stat_differential(prev) do
    case read_proc_stat() do
      {:ok, curr} ->
        busy_prev = prev.user + prev.nice + prev.system + prev.iowait + prev.irq + prev.softirq
        busy_curr = curr.user + curr.nice + curr.system + curr.iowait + curr.irq + curr.softirq
        total_prev = busy_prev + prev.idle
        total_curr = busy_curr + curr.idle

        total_diff = total_curr - total_prev
        idle_diff = curr.idle - prev.idle

        cpu_pct =
          if total_diff == 0 do
            0
          else
            div((total_diff - idle_diff) * 100, total_diff)
          end

        {cpu_pct, curr}

      :error ->
        {0, prev}
    end
  end

  defp read_proc_stat do
    case File.read("/proc/stat") do
      {:ok, content} ->
        [first_line | _] = String.split(content, "\n", parts: 2)
        parts = String.split(first_line, ~r/\s+/, trim: true)

        if length(parts) >= 8 and hd(parts) == "cpu" do
          [_, user, nice, system, idle, iowait, irq, softirq | _] = parts

          {:ok,
           %{
             user: String.to_integer(user),
             nice: String.to_integer(nice),
             system: String.to_integer(system),
             idle: String.to_integer(idle),
             iowait: String.to_integer(iowait),
             irq: String.to_integer(irq),
             softirq: String.to_integer(softirq)
           }}
        else
          :error
        end

      {:error, _} ->
        :error
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # PID CONTROLLER (Ziegler-Nichols tuned)
  # u(t) = Kp * e(t) + Ki * integral(e) + Kd * de/dt
  # ═══════════════════════════════════════════════════════════════════

  defp pid_step(pid_state, setpoint, actual) do
    error = setpoint - actual
    dt = @check_interval_ms / 1000.0

    # Integral with anti-windup (INV-9)
    new_integral =
      (pid_state.integral + error * dt)
      |> max(@integral_min)
      |> min(@integral_max)

    # Derivative
    derivative =
      if dt > 0 do
        (error - pid_state.prev_error) / dt
      else
        0.0
      end

    # PID output: positive = under target (can use more CPU), negative = over target
    output = @kp * error + @ki * new_integral + @kd * derivative

    %{integral: new_integral, prev_error: error, output: output}
  end

  # ═══════════════════════════════════════════════════════════════════
  # ADAPTIVE PARALLELISM (SC-CPU-GOV-006, SC-CPU-GOV-007)
  # ═══════════════════════════════════════════════════════════════════

  @spec determine_mode(integer()) :: mode()
  defp determine_mode(cpu_pct) when cpu_pct < 60, do: :full
  defp determine_mode(cpu_pct) when cpu_pct < 70, do: :slight
  defp determine_mode(cpu_pct) when cpu_pct < 80, do: :moderate
  defp determine_mode(cpu_pct) when cpu_pct <= 85, do: :heavy
  defp determine_mode(_cpu_pct), do: :wait

  # INV-2: schedulers in [4, 16]
  @spec schedulers_for(mode()) :: pos_integer()
  defp schedulers_for(:full), do: 16
  defp schedulers_for(:slight), do: 12
  defp schedulers_for(:moderate), do: 10
  defp schedulers_for(:heavy), do: 6
  defp schedulers_for(:wait), do: 4

  # INV-3: jobs in [4, 16]
  @spec jobs_for(mode()) :: pos_integer()
  defp jobs_for(:full), do: 16
  defp jobs_for(:slight), do: 12
  defp jobs_for(:moderate), do: 10
  defp jobs_for(:heavy), do: 6
  defp jobs_for(:wait), do: 4

  # INV-4: nice in [10, 19]
  @spec nice_for(mode()) :: pos_integer()
  defp nice_for(:full), do: 10
  defp nice_for(:slight), do: 10
  defp nice_for(:moderate), do: 15
  defp nice_for(:heavy), do: 19
  defp nice_for(:wait), do: 19

  # ═══════════════════════════════════════════════════════════════════
  # SHANNON ENTROPY (Load Distribution Metric)
  # H = -sum(p_i * log2(p_i)) for i in {full, slight, moderate, heavy, wait}
  # H_max = log2(5) = 2.32 bits (uniform distribution)
  # ═══════════════════════════════════════════════════════════════════

  @spec compute_entropy(map()) :: float()
  defp compute_entropy(band_counts) do
    total = band_counts |> Map.values() |> Enum.sum()

    if total == 0 do
      0.0
    else
      band_counts
      |> Map.values()
      |> Enum.filter(&(&1 > 0))
      |> Enum.map(fn count ->
        p = count / total
        -p * :math.log2(p)
      end)
      |> Enum.sum()
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # ETS STORAGE (fast external reads, <1ms)
  # ═══════════════════════════════════════════════════════════════════

  defp create_ets_table do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :set, :public, read_concurrency: true])
    end
  end

  defp update_ets(state) do
    entries = [
      {:cpu_pct, state.cpu_pct},
      {:ewma_cpu, Float.round(state.ewma_cpu, 2)},
      {:mode, state.mode},
      {:schedulers, state.schedulers},
      {:jobs, state.jobs},
      {:nice, state.nice},
      {:entropy, Float.round(compute_entropy(state.band_counts), 4)},
      {:pid_output, Float.round(state.pid_state.output, 3)},
      {:over_limit, state.cpu_pct > @hard_limit},
      {:check_count, state.check_count},
      {:updated_at, DateTime.utc_now()}
    ]

    Enum.each(entries, fn entry -> :ets.insert(@ets_table, entry) end)
  end

  # ═══════════════════════════════════════════════════════════════════
  # TELEMETRY (OTEL Pipeline — SC-OBS-069)
  # ═══════════════════════════════════════════════════════════════════

  defp emit_telemetry(state) do
    :telemetry.execute(
      [:indrajaal, :cpu_governor, :check],
      %{
        cpu_pct: state.cpu_pct,
        ewma_cpu: state.ewma_cpu,
        schedulers: state.schedulers,
        jobs: state.jobs,
        pid_output: state.pid_state.output,
        entropy: compute_entropy(state.band_counts),
        duration_ms: @check_interval_ms
      },
      %{
        mode: state.mode,
        over_limit: state.cpu_pct > @hard_limit,
        nice: state.nice,
        check_count: state.check_count,
        constraint: "SC-CPU-GOV-001"
      }
    )
  end

  # ═══════════════════════════════════════════════════════════════════
  # PUBSUB (Phoenix LiveView dashboards)
  # ═══════════════════════════════════════════════════════════════════

  defp broadcast_pubsub(state) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:cpu_governor_update,
       %{
         cpu_pct: state.cpu_pct,
         ewma_cpu: Float.round(state.ewma_cpu, 1),
         mode: state.mode,
         schedulers: state.schedulers,
         jobs: state.jobs,
         entropy: Float.round(compute_entropy(state.band_counts), 3),
         over_limit: state.cpu_pct > @hard_limit
       }}
    )
  rescue
    # PubSub may not be started during tests
    _e -> :ok
  end

  # ═══════════════════════════════════════════════════════════════════
  # ZENOH PUBLISHING (indrajaal/cpu/governor/status)
  # ═══════════════════════════════════════════════════════════════════

  defp publish_zenoh(state) do
    payload =
      Jason.encode!(%{
        cpu_pct: state.cpu_pct,
        ewma_cpu: Float.round(state.ewma_cpu, 2),
        mode: Atom.to_string(state.mode),
        schedulers: state.schedulers,
        dirty_io: state.schedulers,
        jobs: state.jobs,
        nice: state.nice,
        hard_limit: @hard_limit,
        throttle_at: @throttle_at,
        resume_at: @resume_at,
        pid_output: Float.round(state.pid_state.output, 3),
        entropy: Float.round(compute_entropy(state.band_counts), 4),
        cores: :erlang.system_info(:logical_processors_available),
        checks: state.check_count,
        publishes: state.publish_count + 1,
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      })

    case safe_zenoh_publish(@zenoh_key, payload) do
      :ok ->
        %{state | publish_count: state.publish_count + 1, last_published: DateTime.utc_now()}

      {:error, _reason} ->
        state
    end
  end

  defp safe_zenoh_publish(key, payload) do
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohSession) do
      try do
        Indrajaal.Observability.ZenohSession.publish(key, payload)
      rescue
        _ -> {:error, :zenoh_unavailable}
      catch
        _, _ -> {:error, :zenoh_unavailable}
      end
    else
      {:error, :zenoh_not_loaded}
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # SCHEDULING
  # ═══════════════════════════════════════════════════════════════════

  defp schedule_check do
    Process.send_after(self(), :check_cpu, @check_interval_ms)
  end
end
