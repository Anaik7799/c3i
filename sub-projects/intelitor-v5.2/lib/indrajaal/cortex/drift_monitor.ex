defmodule Indrajaal.Cortex.DriftMonitor do
  @moduledoc """
  Autonomic Drift Control — KL Divergence Monitoring (Layer C4).

  ## WHAT
  Measures Kullback-Leibler (KL) Divergence between the system's current
  behavioral distribution and the baseline homeostatic distribution every
  30 seconds. When drift exceeds the threshold, morphogenic evolution is
  throttled or halted to prevent runaway adaptation.

  ## WHY
  Uncontrolled evolution can push the system away from its validated operating
  envelope. KL Divergence provides an information-theoretic measure of how far
  the current state has drifted from the known-good baseline. This implements
  predictive homeostasis — detecting drift BEFORE it causes failures.

  ## CONSTRAINTS
  - SC-DRIFT-001: System SHALL measure KL Divergence every 30 seconds
  - SC-DRIFT-002: Morphogenic evolution SHALL be throttled if D_KL >= 0.05
  - AOR-EVO-006: Mutation agents MUST check drift status before actuation

  ## Mathematical Foundation
  D_KL(P || Q) = sum_x P(x) * log(P(x) / Q(x))

  Where:
  - P = current behavioral distribution (observed metrics)
  - Q = baseline homeostatic distribution (calibrated reference)
  - D_KL = 0 means distributions are identical (no drift)
  - D_KL >= 0.05 triggers evolution throttling

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-03-24 |
  | Author | Cybernetic Architect |
  | STAMP | SC-DRIFT-001, SC-DRIFT-002 |
  """

  use GenServer
  require Logger

  @check_interval_ms 30_000
  @drift_threshold 0.05
  @history_max 100

  # ── Public API ──────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the current drift status.

  ## Returns
  - `{:ok, %{kl_divergence: float, drifting: boolean, throttled: boolean}}`
  """
  @spec drift_status() :: {:ok, map()}
  def drift_status do
    GenServer.call(__MODULE__, :drift_status)
  end

  @doc """
  Checks whether evolution should proceed. Returns `:ok` if drift is
  within bounds, `{:error, :evolution_throttled}` if D_KL >= threshold.

  Mutation agents MUST call this before actuation (AOR-EVO-006).
  """
  @spec check_evolution_clearance() :: :ok | {:error, :evolution_throttled}
  def check_evolution_clearance do
    GenServer.call(__MODULE__, :check_evolution_clearance)
  end

  @doc """
  Updates the baseline distribution. Call after a validated stable state
  is reached (e.g., after successful shadow testing).
  """
  @spec calibrate_baseline(map()) :: :ok
  def calibrate_baseline(new_baseline) when is_map(new_baseline) do
    GenServer.cast(__MODULE__, {:calibrate_baseline, new_baseline})
  end

  @doc """
  Returns the KL Divergence history for trend analysis.
  """
  @spec drift_history() :: {:ok, list(map())}
  def drift_history do
    GenServer.call(__MODULE__, :drift_history)
  end

  # ── GenServer Callbacks ─────────────────────────────────────────────

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :check_interval_ms, @check_interval_ms)
    threshold = Keyword.get(opts, :drift_threshold, @drift_threshold)

    state = %{
      baseline: default_baseline(),
      current: %{},
      kl_divergence: 0.0,
      throttled: false,
      check_interval_ms: interval,
      drift_threshold: threshold,
      history: [],
      last_check: nil,
      check_count: 0
    }

    schedule_check(interval)

    :telemetry.execute(
      [:indrajaal, :cortex, :drift_monitor, :started],
      %{threshold: threshold, interval_ms: interval},
      %{}
    )

    Logger.info("[DriftMonitor] Started — interval=#{interval}ms, threshold=#{threshold}")
    {:ok, state}
  end

  @impl true
  def handle_call(:drift_status, _from, state) do
    status = %{
      kl_divergence: state.kl_divergence,
      drifting: state.kl_divergence >= state.drift_threshold,
      throttled: state.throttled,
      last_check: state.last_check,
      check_count: state.check_count
    }

    {:reply, {:ok, status}, state}
  end

  def handle_call(:check_evolution_clearance, _from, state) do
    if state.throttled do
      {:reply, {:error, :evolution_throttled}, state}
    else
      {:reply, :ok, state}
    end
  end

  def handle_call(:drift_history, _from, state) do
    {:reply, {:ok, Enum.reverse(state.history)}, state}
  end

  @impl true
  def handle_cast({:calibrate_baseline, new_baseline}, state) do
    Logger.info("[DriftMonitor] Baseline recalibrated with #{map_size(new_baseline)} dimensions")

    :telemetry.execute(
      [:indrajaal, :cortex, :drift_monitor, :baseline_calibrated],
      %{dimensions: map_size(new_baseline)},
      %{}
    )

    {:noreply, %{state | baseline: new_baseline, kl_divergence: 0.0, throttled: false}}
  end

  @impl true
  def handle_info(:check_drift, state) do
    current = collect_current_distribution()
    kl_div = compute_kl_divergence(state.baseline, current)
    was_throttled = state.throttled
    now_throttled = kl_div >= state.drift_threshold
    now = DateTime.utc_now()

    history_entry = %{
      kl_divergence: kl_div,
      throttled: now_throttled,
      timestamp: now
    }

    history =
      [history_entry | state.history]
      |> Enum.take(@history_max)

    # Emit telemetry
    :telemetry.execute(
      [:indrajaal, :cortex, :drift_monitor, :measurement],
      %{kl_divergence: kl_div, throttled: now_throttled},
      %{check_count: state.check_count + 1}
    )

    # Publish to Zenoh if available
    publish_drift_metrics(kl_div, now_throttled, state.check_count + 1)

    # Log state transitions
    cond do
      not was_throttled and now_throttled ->
        Logger.warning(
          "[DriftMonitor] DRIFT DETECTED — D_KL=#{Float.round(kl_div, 6)} >= #{state.drift_threshold}. Evolution THROTTLED."
        )

        :telemetry.execute(
          [:indrajaal, :cortex, :drift_monitor, :throttle_activated],
          %{kl_divergence: kl_div},
          %{}
        )

      was_throttled and not now_throttled ->
        Logger.info(
          "[DriftMonitor] Drift resolved — D_KL=#{Float.round(kl_div, 6)} < #{state.drift_threshold}. Evolution RESUMED."
        )

        :telemetry.execute(
          [:indrajaal, :cortex, :drift_monitor, :throttle_deactivated],
          %{kl_divergence: kl_div},
          %{}
        )

      true ->
        :ok
    end

    schedule_check(state.check_interval_ms)

    {:noreply,
     %{
       state
       | current: current,
         kl_divergence: kl_div,
         throttled: now_throttled,
         history: history,
         last_check: now,
         check_count: state.check_count + 1
     }}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ── KL Divergence Computation ───────────────────────────────────────

  @doc false
  def compute_kl_divergence(baseline, current) when is_map(baseline) and is_map(current) do
    # Get the union of all dimension keys
    all_keys = MapSet.union(MapSet.new(Map.keys(baseline)), MapSet.new(Map.keys(current)))

    if MapSet.size(all_keys) == 0 do
      0.0
    else
      # Compute D_KL(P || Q) where P = current, Q = baseline
      # Using smoothed distributions to avoid log(0)
      epsilon = 1.0e-10

      Enum.reduce(all_keys, 0.0, fn key, acc ->
        p = Map.get(current, key, epsilon)
        q = Map.get(baseline, key, epsilon)

        # Clamp to avoid numerical issues
        p = max(p, epsilon)
        q = max(q, epsilon)

        acc + p * :math.log(p / q)
      end)
      |> max(0.0)
    end
  end

  # ── System Metric Collection ────────────────────────────────────────

  defp collect_current_distribution do
    memory = :erlang.memory()
    total_mem = memory[:total] || 1
    process_mem = memory[:processes] || 0
    ets_mem = memory[:ets] || 0
    binary_mem = memory[:binary] || 0

    scheduler_count = :erlang.system_info(:schedulers_online)
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)

    %{
      memory_pressure: process_mem / max(total_mem, 1),
      ets_pressure: ets_mem / max(total_mem, 1),
      binary_pressure: binary_mem / max(total_mem, 1),
      process_saturation: process_count / max(process_limit, 1),
      scheduler_density: process_count / max(scheduler_count, 1) / 1000.0
    }
  end

  defp default_baseline do
    # Conservative baseline representing healthy system state
    %{
      memory_pressure: 0.15,
      ets_pressure: 0.05,
      binary_pressure: 0.03,
      process_saturation: 0.01,
      scheduler_density: 0.05
    }
  end

  # ── Zenoh Publishing ────────────────────────────────────────────────

  defp publish_drift_metrics(kl_divergence, throttled, check_count) do
    try do
      if Code.ensure_loaded?(Indrajaal.Observability.ZenohNeuralStream) do
        Indrajaal.Observability.ZenohNeuralStream.stream_state(
          :drift_monitor,
          :measurement,
          %{
            kl_divergence: kl_divergence,
            throttled: throttled,
            check_count: check_count,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        )
      end
    rescue
      _ -> :ok
    end
  end

  # ── Scheduling ──────────────────────────────────────────────────────

  defp schedule_check(interval_ms) do
    Process.send_after(self(), :check_drift, interval_ms)
  end
end
