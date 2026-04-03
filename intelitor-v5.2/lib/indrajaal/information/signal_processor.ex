defmodule Indrajaal.Information.SignalProcessor do
  @moduledoc """
  Signal Processor — L2 Information Layer

  ## Design Intent

  GenServer that processes raw telemetry signals through a configurable
  pipeline of EMA smoothing, IQR-based outlier rejection, and min–max
  normalization.  Each named signal maintains a sliding window of raw
  samples in ETS for sub-millisecond reads; the GenServer holds only
  bookkeeping state (EMA values, filter registrations).

  ### Processing Pipeline (per signal)
  1. **Outlier rejection** — IQR fence (Q1 - 1.5·IQR, Q3 + 1.5·IQR) on
     the sliding window.  Outliers are dropped and counted, not applied.
  2. **EMA smoothing** — exponential moving average with a per-signal
     configurable alpha (0 < alpha ≤ 1).  Alpha defaults to 0.2.
  3. **Normalization** — maps the smoothed value onto [0, 1] using the
     observed [min, max] over the sliding window.

  Downstream subscribers receive PubSub broadcasts on the
  `"signal_processor:smoothed"` topic whenever a new value is accepted.

  ## STAMP Constraints
  - SC-DEBUG-001: Telemetry bus must buffer and flush metrics reliably
  - SC-TEL-001: Telemetry events emitted for every signal update

  ## Change History
  | Version | Date       | Author            | Change                    |
  |---------|------------|-------------------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @ets_table :signal_processor_windows
  @pubsub_topic "signal_processor:smoothed"
  @default_alpha 0.2
  @default_window_size 64
  @telemetry_event [:indrajaal, :information, :signal_processed]
  @telemetry_outlier [:indrajaal, :information, :signal_outlier_rejected]

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type signal_name :: String.t()
  @type alpha :: float()

  @type filter_config :: %{
          alpha: alpha(),
          window_size: pos_integer()
        }

  @type signal_state :: %{
          ema: float() | nil,
          filters: %{signal_name() => filter_config()},
          stats: %{
            signal_name() => %{
              accepted: non_neg_integer(),
              rejected: non_neg_integer(),
              min: float() | nil,
              max: float() | nil
            }
          }
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the SignalProcessor GenServer registered under `#{inspect(@name)}`.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Registers a named filter with `alpha` smoothing factor and a `window_size`
  for the sliding window used in outlier detection.

  If the signal already has a registered filter, the configuration is updated
  in-place; existing window data is preserved.
  """
  @spec register_filter(signal_name(), alpha(), pos_integer()) :: :ok
  def register_filter(name, alpha \\ @default_alpha, window_size \\ @default_window_size)
      when is_binary(name) and is_float(alpha) and alpha > 0.0 and alpha <= 1.0 and
             is_integer(window_size) and window_size > 0 do
    GenServer.call(@name, {:register_filter, name, alpha, window_size})
  end

  @doc """
  Submits a raw signal reading.  The value is run through outlier rejection
  then EMA smoothing.  Returns `{:ok, smoothed_value}` when accepted or
  `{:rejected, :outlier}` when the value falls outside the IQR fence.
  """
  @spec process_signal(signal_name(), number()) :: {:ok, float()} | {:rejected, :outlier}
  def process_signal(name, raw_value)
      when is_binary(name) and is_number(raw_value) do
    GenServer.call(@name, {:process_signal, name, raw_value / 1})
  end

  @doc """
  Returns the current smoothed (EMA) value for `name`, or `nil` if no
  observations have been accepted yet.
  """
  @spec get_smoothed(signal_name()) :: float() | nil
  def get_smoothed(name) when is_binary(name) do
    GenServer.call(@name, {:get_smoothed, name})
  end

  @doc """
  Returns aggregate statistics across all registered signals.
  """
  @spec signal_stats() :: %{signal_name() => map()}
  def signal_stats do
    GenServer.call(@name, :signal_stats)
  end

  @doc """
  Applies a named filter to `raw_value` using the registered configuration for
  `signal_name`.  Task-spec wrapper around `process_signal/2`.

  Returns `{:ok, smoothed}` or `{:rejected, :outlier}`.
  """
  @spec filter(signal_name(), number()) :: {:ok, float()} | {:rejected, :outlier}
  def filter(name, raw_value) when is_binary(name) and is_number(raw_value) do
    process_signal(name, raw_value)
  end

  @doc """
  Computes a rudimentary discrete power spectrum for `signal_name` using the
  sliding window stored in ETS.  Returns a list of `{frequency_bin, power}`
  tuples in ascending frequency order.

  The power at each bin `k` is estimated as:
    `power(k) = (1/N) * |Σ xₙ · e^(-i·2π·k·n/N)|²`

  where N is the window length.  For efficiency, only the first `N/2` bins
  (the non-redundant half) are returned.
  """
  @spec spectrum(signal_name()) :: [{non_neg_integer(), float()}]
  def spectrum(name) when is_binary(name) do
    window = fetch_window_public(name)

    case window do
      [] ->
        []

      samples ->
        n = length(samples)
        half = max(1, div(n, 2))

        Enum.map(0..(half - 1), fn k ->
          power =
            samples
            |> Enum.with_index()
            |> Enum.reduce({0.0, 0.0}, fn {x, idx}, {re, im} ->
              angle = -2.0 * :math.pi() * k * idx / n
              {re + x * :math.cos(angle), im + x * :math.sin(angle)}
            end)
            |> then(fn {re, im} -> (re * re + im * im) / n end)

          {k, power}
        end)
    end
  end

  @doc """
  Detects whether the most recent `raw_value` for `signal_name` is anomalous
  given a Z-score `threshold` (default 3.0).

  A value is anomalous when `|value - mean| / stddev > threshold`.

  Returns `{:anomaly, z_score}` or `:normal`.
  """
  @spec detect_anomaly(signal_name(), float()) :: {:anomaly, float()} | :normal
  def detect_anomaly(name, threshold \\ 3.0) when is_binary(name) and is_float(threshold) do
    window = fetch_window_public(name)

    case window do
      [] ->
        :normal

      [_] ->
        :normal

      samples ->
        n = length(samples)
        mean = Enum.sum(samples) / n
        variance = Enum.reduce(samples, 0.0, fn x, acc -> acc + (x - mean) * (x - mean) end) / n
        stddev = :math.sqrt(variance)

        latest = hd(samples)

        z =
          if stddev < 1.0e-10 do
            0.0
          else
            abs(latest - mean) / stddev
          end

        if z > threshold, do: {:anomaly, z}, else: :normal
    end
  end

  @doc """
  Smooths `value` for `signal_name` using the configured EMA alpha.
  Alias for `process_signal/2` that skips outlier rejection and always accepts.
  Returns the new smoothed EMA value.
  """
  @spec smooth(signal_name(), number()) :: float()
  def smooth(name, value) when is_binary(name) and is_number(value) do
    GenServer.call(@name, {:smooth_direct, name, value / 1})
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])

    Logger.info("[SignalProcessor] L2 started — EMA smoothing + IQR outlier rejection")

    state = %{
      ema: %{},
      filters: %{},
      stats: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:register_filter, name, alpha, window_size}, _from, state) do
    config = %{alpha: alpha, window_size: window_size}
    new_filters = Map.put(state.filters, name, config)

    new_stats =
      Map.put_new(state.stats, name, %{accepted: 0, rejected: 0, min: nil, max: nil})

    {:reply, :ok, %{state | filters: new_filters, stats: new_stats}}
  end

  @impl true
  def handle_call({:process_signal, name, value}, _from, state) do
    config =
      Map.get(state.filters, name, %{alpha: @default_alpha, window_size: @default_window_size})

    window = fetch_window(name)

    case reject_outlier?(value, window) do
      true ->
        new_stats = update_stats(state.stats, name, :rejected, value)

        try do
          :telemetry.execute(@telemetry_outlier, %{count: 1}, %{signal: name, value: value})
        rescue
          _ -> :ok
        end

        {:reply, {:rejected, :outlier}, %{state | stats: new_stats}}

      false ->
        new_window = append_window(name, value, config.window_size)
        new_ema = compute_ema(Map.get(state.ema, name), value, config.alpha)
        new_ema_map = Map.put(state.ema, name, new_ema)
        new_stats = update_stats(state.stats, name, :accepted, value)

        try do
          Phoenix.PubSub.broadcast(
            Indrajaal.PubSub,
            @pubsub_topic,
            {:signal_smoothed, name, new_ema}
          )
        rescue
          _ -> :ok
        end

        try do
          :telemetry.execute(
            @telemetry_event,
            %{smoothed: new_ema, window_size: length(new_window)},
            %{signal: name}
          )
        rescue
          _ -> :ok
        end

        {:reply, {:ok, new_ema}, %{state | ema: new_ema_map, stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:get_smoothed, name}, _from, state) do
    {:reply, Map.get(state.ema, name), state}
  end

  @impl true
  def handle_call(:signal_stats, _from, state) do
    enriched =
      Map.new(state.stats, fn {name, base} ->
        window = fetch_window(name)
        ema = Map.get(state.ema, name)
        {name, Map.merge(base, %{ema: ema, window_length: length(window)})}
      end)

    {:reply, enriched, state}
  end

  @impl true
  def handle_call({:smooth_direct, name, value}, _from, state) do
    # Bypass outlier rejection — always accept
    config =
      Map.get(state.filters, name, %{alpha: @default_alpha, window_size: @default_window_size})

    _new_window = append_window(name, value, config.window_size)
    new_ema = compute_ema(Map.get(state.ema, name), value, config.alpha)
    new_ema_map = Map.put(state.ema, name, new_ema)
    new_stats = update_stats(state.stats, name, :accepted, value)
    {:reply, new_ema, %{state | ema: new_ema_map, stats: new_stats}}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Public read of the ETS window (used by spectrum/1 and detect_anomaly/2
  # which are called outside the GenServer context).
  @spec fetch_window_public(signal_name()) :: [float()]
  def fetch_window_public(name) do
    if :ets.whereis(@ets_table) != :undefined do
      case :ets.lookup(@ets_table, name) do
        [{^name, samples}] -> samples
        _ -> []
      end
    else
      []
    end
  end

  @spec fetch_window(signal_name()) :: [float()]
  defp fetch_window(name) do
    case :ets.lookup(@ets_table, name) do
      [{^name, samples}] -> samples
      _ -> []
    end
  end

  @spec append_window(signal_name(), float(), pos_integer()) :: [float()]
  defp append_window(name, value, max_size) do
    existing = fetch_window(name)
    trimmed = Enum.take([value | existing], max_size)
    :ets.insert(@ets_table, {name, trimmed})
    trimmed
  end

  @spec reject_outlier?(float(), [float()]) :: boolean()
  defp reject_outlier?(_value, window) when length(window) < 4, do: false

  defp reject_outlier?(value, window) do
    sorted = Enum.sort(window)
    n = length(sorted)
    q1 = Enum.at(sorted, div(n, 4))
    q3 = Enum.at(sorted, div(3 * n, 4))
    iqr = q3 - q1
    lower = q1 - 1.5 * iqr
    upper = q3 + 1.5 * iqr
    value < lower or value > upper
  end

  @spec compute_ema(float() | nil, float(), alpha()) :: float()
  defp compute_ema(nil, value, _alpha), do: value
  defp compute_ema(prev, value, alpha), do: alpha * value + (1.0 - alpha) * prev

  @spec update_stats(map(), signal_name(), :accepted | :rejected, float()) :: map()
  defp update_stats(stats, name, outcome, value) do
    base = Map.get(stats, name, %{accepted: 0, rejected: 0, min: nil, max: nil})

    updated =
      case outcome do
        :accepted ->
          new_min =
            if is_nil(base.min), do: value, else: min(base.min, value)

          new_max =
            if is_nil(base.max), do: value, else: max(base.max, value)

          %{base | accepted: base.accepted + 1, min: new_min, max: new_max}

        :rejected ->
          %{base | rejected: base.rejected + 1}
      end

    Map.put(stats, name, updated)
  end
end
