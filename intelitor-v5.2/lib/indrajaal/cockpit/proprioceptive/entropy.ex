defmodule Indrajaal.Cockpit.Proprioceptive.Entropy do
  @moduledoc """
  Entropy Measurement - System Disorder Quantification for v20.0.0

  Implements entropy metrics for proprioceptive awareness:
  - Information entropy (Shannon)
  - Structural entropy
  - Behavioral entropy
  - Temporal entropy

  ## Entropy Model

  System entropy: H(S) = -Σ p(x) log₂ p(x)

  Where:
  - p(x) = probability of state x
  - Higher entropy = more disorder/uncertainty
  - Lower entropy = more order/predictability

  ## Entropy Types
  - **Information**: Uncertainty in messages
  - **Structural**: Disorder in code/architecture
  - **Behavioral**: Unpredictability in actions
  - **Temporal**: Variability over time

  ## STAMP Constraints
  - SC-ENT-001: Entropy calculation MUST be real-time
  - SC-ENT-002: Historical entropy MUST be tracked
  - SC-ENT-003: Anomaly detection at 2σ deviation
  - SC-ENT-004: Entropy alerts < 100ms latency
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohPublisher

  @type entropy_type :: :information | :structural | :behavioral | :temporal
  @type entropy_value :: float()

  @type entropy_sample :: %{
          type: entropy_type(),
          value: entropy_value(),
          timestamp: DateTime.t(),
          source: String.t(),
          metadata: map()
        }

  @type state :: %{
          current: map(),
          history: map(),
          baselines: map(),
          alerts: [map()],
          config: map()
        }

  # Sample retention (samples per type)
  @max_history 1000

  # Alert threshold (standard deviations)
  @alert_threshold 2.0

  # Calculation interval (ms)
  @calc_interval 1_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records an entropy sample.
  """
  @spec record(entropy_type(), entropy_value(), String.t(), map()) :: :ok
  def record(type, value, source, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:record, type, value, source, metadata})
  end

  @doc """
  Gets current entropy for a type.
  """
  @spec current(entropy_type()) :: {:ok, entropy_value()} | {:error, :no_data}
  def current(type) do
    GenServer.call(__MODULE__, {:current, type})
  end

  @doc """
  Gets entropy history for a type.
  """
  @spec history(entropy_type(), non_neg_integer()) :: [entropy_sample()]
  def history(type, limit \\ 100) do
    GenServer.call(__MODULE__, {:history, type, limit})
  end

  @doc """
  Gets all current entropy values.
  """
  @spec snapshot() :: map()
  def snapshot do
    GenServer.call(__MODULE__, :snapshot)
  end

  @doc """
  Calculates information entropy for a distribution.
  """
  @spec calculate_information_entropy([number()]) :: entropy_value()
  def calculate_information_entropy(values) when length(values) > 0 do
    total = Enum.sum(values)

    if total == 0 do
      0.0
    else
      values
      |> Enum.filter(&(&1 > 0))
      |> Enum.map(fn v ->
        p = v / total
        -p * :math.log2(p)
      end)
      |> Enum.sum()
    end
  end

  def calculate_information_entropy(_), do: 0.0

  @doc """
  Calculates structural entropy from module/function metrics.
  """
  @spec calculate_structural_entropy(map()) :: entropy_value()
  def calculate_structural_entropy(metrics) do
    # Based on cyclomatic complexity distribution
    complexities = Map.get(metrics, :complexities, [1])
    calculate_information_entropy(complexities)
  end

  @doc """
  Calculates behavioral entropy from action frequencies.
  """
  @spec calculate_behavioral_entropy([atom()]) :: entropy_value()
  def calculate_behavioral_entropy(actions) when length(actions) > 0 do
    frequencies =
      actions
      |> Enum.frequencies()
      |> Map.values()

    calculate_information_entropy(frequencies)
  end

  def calculate_behavioral_entropy(_), do: 0.0

  @doc """
  Calculates temporal entropy from time series.
  """
  @spec calculate_temporal_entropy([number()]) :: entropy_value()
  def calculate_temporal_entropy(series) when length(series) >= 2 do
    # Calculate entropy of differences (rate of change)
    diffs =
      series
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> abs(b - a) end)

    if Enum.empty?(diffs) do
      0.0
    else
      # Bin the differences
      max_diff = Enum.max(diffs)
      min_diff = Enum.min(diffs)
      range = max(max_diff - min_diff, 0.001)
      num_bins = min(10, length(diffs))

      bins =
        diffs
        |> Enum.map(fn d -> floor((d - min_diff) / range * (num_bins - 1)) end)
        |> Enum.frequencies()
        |> Map.values()

      calculate_information_entropy(bins)
    end
  end

  def calculate_temporal_entropy(_), do: 0.0

  @doc """
  Gets active alerts.
  """
  @spec alerts() :: [map()]
  def alerts do
    GenServer.call(__MODULE__, :alerts)
  end

  @doc """
  Clears resolved alerts.
  """
  @spec clear_alerts() :: :ok
  def clear_alerts do
    GenServer.cast(__MODULE__, :clear_alerts)
  end

  @doc """
  Gets entropy statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      current: %{},
      history: %{
        information: [],
        structural: [],
        behavioral: [],
        temporal: []
      },
      baselines: %{},
      alerts: [],
      stats: %{
        samples_recorded: 0,
        alerts_triggered: 0,
        last_calculation: nil
      },
      config: %{
        alert_threshold: Keyword.get(opts, :alert_threshold, @alert_threshold),
        max_history: Keyword.get(opts, :max_history, @max_history)
      }
    }

    # Schedule periodic calculations
    Process.send_after(self(), :calculate, @calc_interval)

    Logger.info("📊 Entropy measurement service started")

    {:ok, state}
  end

  @impl true
  def handle_call({:current, type}, _from, state) do
    case Map.get(state.current, type) do
      nil -> {:reply, {:error, :no_data}, state}
      value -> {:reply, {:ok, value}, state}
    end
  end

  @impl true
  def handle_call({:history, type, limit}, _from, state) do
    samples =
      state.history
      |> Map.get(type, [])
      |> Enum.take(limit)

    {:reply, samples, state}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    snapshot = %{
      current: state.current,
      baselines: state.baselines,
      alerts: length(state.alerts),
      timestamp: DateTime.utc_now()
    }

    publish_to_zenoh("indrajaal/entropy/metrics", %{
      checkpoint: "CP-ENTROPY-01",
      current: state.current,
      alert_count: length(state.alerts),
      samples_recorded: state.stats.samples_recorded
    })

    {:reply, snapshot, state}
  end

  @impl true
  def handle_call(:alerts, _from, state) do
    {:reply, state.alerts, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        current_values: map_size(state.current),
        active_alerts: length(state.alerts),
        history_sizes: Enum.into(state.history, %{}, fn {k, v} -> {k, length(v)} end)
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:record, type, value, source, metadata}, state) do
    sample = %{
      type: type,
      value: value,
      timestamp: DateTime.utc_now(),
      source: source,
      metadata: metadata
    }

    # Update current
    new_current = Map.put(state.current, type, value)

    # Update history
    type_history = Map.get(state.history, type, [])

    new_type_history =
      [sample | type_history]
      |> Enum.take(state.config.max_history)

    new_history = Map.put(state.history, type, new_type_history)

    # Check for anomalies
    new_alerts = check_anomaly(type, value, state)
    all_alerts = new_alerts ++ state.alerts

    # Update stats
    new_stats = %{state.stats | samples_recorded: state.stats.samples_recorded + 1}

    {:noreply,
     %{
       state
       | current: new_current,
         history: new_history,
         alerts: all_alerts,
         stats: new_stats
     }}
  end

  @impl true
  def handle_cast(:clear_alerts, state) do
    {:noreply, %{state | alerts: []}}
  end

  @impl true
  def handle_info(:calculate, state) do
    # Calculate aggregate entropy from all sources
    new_baselines = update_baselines(state)

    new_stats = %{state.stats | last_calculation: DateTime.utc_now()}

    # Schedule next calculation
    Process.send_after(self(), :calculate, @calc_interval)

    {:noreply, %{state | baselines: new_baselines, stats: new_stats}}
  end

  # Private helpers

  defp check_anomaly(type, value, state) do
    case Map.get(state.baselines, type) do
      nil ->
        []

      %{mean: mean, std: std} when std > 0 ->
        deviation = abs(value - mean) / std

        if deviation > state.config.alert_threshold do
          [
            %{
              type: :entropy_anomaly,
              entropy_type: type,
              value: value,
              expected: mean,
              deviation: deviation,
              threshold: state.config.alert_threshold,
              timestamp: DateTime.utc_now()
            }
          ]
        else
          []
        end

      _ ->
        []
    end
  end

  defp update_baselines(state) do
    Enum.into(state.history, %{}, fn {type, samples} ->
      if length(samples) >= 10 do
        values = Enum.map(samples, & &1.value)
        mean = Enum.sum(values) / length(values)

        variance =
          values
          |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
          |> Enum.sum()
          |> Kernel./(length(values))

        std = :math.sqrt(variance)

        {type, %{mean: mean, std: std, samples: length(samples)}}
      else
        {type, Map.get(state.baselines, type, %{mean: 0, std: 0, samples: 0})}
      end
    end)
  end

  # SC-ZTEST-008: Dual-write — log fallback first, then best-effort Zenoh publish.
  defp publish_to_zenoh(topic, payload) do
    Logger.info(
      "[ZTEST-CHECKPOINT] checkpoint=#{payload[:checkpoint]} topic=#{topic} " <>
        "timestamp=#{DateTime.utc_now() |> DateTime.to_iso8601()}"
    )

    try do
      ZenohPublisher.publish_async(topic, payload)
    rescue
      _ -> :ok
    end
  end
end
