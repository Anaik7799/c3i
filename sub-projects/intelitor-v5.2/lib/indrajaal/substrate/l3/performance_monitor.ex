defmodule Indrajaal.Substrate.L3.PerformanceMonitor do
  @moduledoc """
  L3 Performance Monitor — KPI tracking with EMA smoothing across subsystems.

  GenServer that collects numeric performance metrics from any subsystem and
  maintains Exponential Moving Average (EMA) smoothed values.  On each
  `record/3` call the raw value is stored and the EMA is updated.  Metrics
  are published to Phoenix.PubSub topic "prajna:performance" and via
  `:telemetry` events.

  ## EMA Formula
    EMA(t) = α × raw + (1 − α) × EMA(t−1)
    α = 2 / (window + 1)   — default window = 10 samples

  ## Degradation Detection
  A subsystem metric is considered *degraded* when its latest EMA falls
  below its configured threshold.  `degraded?/0` returns true when any
  registered metric is in degraded state.

  ## STAMP Constraints
  - SC-S3-001: S3 operational management constraints — ENFORCED
  - SC-S3-002: EMA smoothing mandatory for KPI tracking — ENFORCED
  - SC-S3-003: Degradation detection — ENFORCED
  - SC-S3-004: PubSub broadcast on each record — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "prajna:performance"
  @default_ema_window 10
  @default_threshold 0.0

  @type metric_key :: atom()
  @type subsystem_id :: atom() | binary()

  @type metric_entry :: %{
          subsystem: subsystem_id(),
          key: metric_key(),
          raw: float(),
          ema: float(),
          alpha: float(),
          threshold: float(),
          sample_count: non_neg_integer(),
          last_updated: DateTime.t()
        }

  @type metrics_map :: %{{subsystem_id(), metric_key()} => metric_entry()}

  @type t :: %{
          metrics: metrics_map(),
          ema_window: pos_integer()
        }

  # ── Client API ──────────────────────────────────────────────────────

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Record a metric value `raw` for `subsystem` / `key`.
  Optional `opts`: [threshold: float, ema_window: pos_integer].
  Returns :ok.
  """
  @spec record(subsystem_id(), metric_key(), float(), keyword()) :: :ok
  def record(subsystem, key, raw, opts \\ [])
      when is_number(raw) do
    GenServer.cast(@name, {:record, subsystem, key, raw / 1, opts})
  end

  @doc """
  Returns the latest metric entry for `subsystem` / `key`, or
  `{:error, :not_found}`.
  """
  @spec metric(subsystem_id(), metric_key()) ::
          {:ok, metric_entry()} | {:error, :not_found}
  def metric(subsystem, key) do
    GenServer.call(@name, {:metric, subsystem, key})
  end

  @doc "Returns all tracked metrics as a map keyed by `{subsystem, key}`."
  @spec all_metrics() :: metrics_map()
  def all_metrics do
    GenServer.call(@name, :all_metrics)
  end

  @doc "Returns true when any metric has an EMA below its configured threshold."
  @spec degraded?() :: boolean()
  def degraded? do
    GenServer.call(@name, :degraded?)
  end

  # ── GenServer Callbacks ──────────────────────────────────────────────

  @impl true
  def init(opts) do
    ema_window = Keyword.get(opts, :ema_window, @default_ema_window)
    state = %{metrics: %{}, ema_window: ema_window}
    Logger.info("[PERFORMANCE_MONITOR] started — ema_window=#{ema_window}")
    {:ok, state}
  end

  @impl true
  def handle_cast({:record, subsystem, key, raw, opts}, state) do
    k = {subsystem, key}
    existing = Map.get(state.metrics, k)

    window = Keyword.get(opts, :ema_window, state.ema_window)
    alpha = 2.0 / (window + 1)

    threshold =
      Keyword.get(
        opts,
        :threshold,
        if(existing, do: existing.threshold, else: @default_threshold)
      )

    entry =
      if existing do
        new_ema = alpha * raw + (1.0 - alpha) * existing.ema

        %{
          existing
          | raw: raw,
            ema: new_ema,
            sample_count: existing.sample_count + 1,
            last_updated: DateTime.utc_now()
        }
      else
        %{
          subsystem: subsystem,
          key: key,
          raw: raw,
          ema: raw,
          alpha: alpha,
          threshold: threshold,
          sample_count: 1,
          last_updated: DateTime.utc_now()
        }
      end

    new_metrics = Map.put(state.metrics, k, entry)
    new_state = %{state | metrics: new_metrics}

    broadcast(entry)

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:metric, subsystem, key}, _from, state) do
    case Map.get(state.metrics, {subsystem, key}) do
      nil -> {:reply, {:error, :not_found}, state}
      entry -> {:reply, {:ok, entry}, state}
    end
  end

  @impl true
  def handle_call(:all_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl true
  def handle_call(:degraded?, _from, state) do
    degraded =
      Enum.any?(state.metrics, fn {_k, entry} ->
        entry.threshold > 0.0 and entry.ema < entry.threshold
      end)

    {:reply, degraded, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ── Private ──────────────────────────────────────────────────────────

  @spec broadcast(metric_entry()) :: :ok
  defp broadcast(entry) do
    payload = %{
      subsystem: entry.subsystem,
      key: entry.key,
      raw: entry.raw,
      ema: entry.ema,
      sample_count: entry.sample_count,
      timestamp: entry.last_updated
    }

    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:performance_metric, payload}
      )
    rescue
      _ -> :ok
    end

    :telemetry.execute(
      [:substrate, :l3, :performance_monitor, :record],
      %{raw: entry.raw, ema: entry.ema},
      %{subsystem: entry.subsystem, key: entry.key}
    )

    :ok
  rescue
    _ -> :ok
  end
end
