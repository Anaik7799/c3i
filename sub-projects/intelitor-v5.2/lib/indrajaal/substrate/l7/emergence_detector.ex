defmodule Indrajaal.Substrate.L7.EmergenceDetector do
  @moduledoc """
  ## Design Intent
  L7 substrate Emergence Detector — pure functional emergent behavior detection
  for the Indrajaal biomorphic ecosystem layer.

  Models complex-systems emergence theory: a collective behavior is considered
  emergent when it cannot be predicted from the properties of individual agents
  alone. This detector uses two complementary heuristics:

    1. Variance spike: the standard deviation of a metric stream crosses a
       configurable `spike_threshold` relative to its rolling mean.
    2. Phase transition: the ratio of metric value to rolling mean crosses
       `phase_threshold`, signalling a discontinuous jump (bifurcation).

  Each observation is pushed into a bounded circular window. When either
  heuristic fires, an `emergence_event` is appended to the event log.

  Window size and thresholds are configurable at construction time.

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — detector is read-only, never actuates
  - SC-ECO-003: Ecosystem monitoring — emergence events logged for analysis
  - SC-VER-044: 5-Order effects logged — emergence triggers cascade review
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @default_window 20
  @default_spike_threshold 2.0
  @default_phase_threshold 1.8

  @type emergence_event :: %{
          metric: String.t(),
          value: float(),
          mean: float(),
          std_dev: float(),
          trigger: :variance_spike | :phase_transition,
          detected_at: integer()
        }

  @type t :: %__MODULE__{
          window_size: pos_integer(),
          spike_threshold: float(),
          phase_threshold: float(),
          observations: %{String.t() => [float()]},
          events: [emergence_event()],
          observation_count: non_neg_integer(),
          created_at: integer()
        }

  defstruct window_size: @default_window,
            spike_threshold: @default_spike_threshold,
            phase_threshold: @default_phase_threshold,
            observations: %{},
            events: [],
            observation_count: 0,
            created_at: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    window = Keyword.get(opts, :window_size, @default_window)
    spike = Keyword.get(opts, :spike_threshold, @default_spike_threshold)
    phase = Keyword.get(opts, :phase_threshold, @default_phase_threshold)

    cond do
      not is_integer(window) or window < 2 ->
        {:error, "window_size must be an integer >= 2"}

      not is_float(spike) or spike < 1.0 ->
        {:error, "spike_threshold must be a float >= 1.0"}

      not is_float(phase) or phase < 1.0 ->
        {:error, "phase_threshold must be a float >= 1.0"}

      true ->
        state = %__MODULE__{
          window_size: window,
          spike_threshold: spike,
          phase_threshold: phase,
          observations: %{},
          events: [],
          observation_count: 0,
          created_at: System.monotonic_time(:second)
        }

        {:ok, state}
    end
  end

  @doc """
  Push a new observation for a named metric. Runs both emergence heuristics.
  Returns `{:ok, updated_detector, emerged?}` where `emerged?` is `true` if
  an emergence event was recorded for this observation.
  """
  @spec observe(t(), String.t(), float()) :: {:ok, t(), boolean()}
  def observe(%__MODULE__{} = det, metric, value) when is_binary(metric) and is_float(value) do
    window = Enum.take([value | Map.get(det.observations, metric, [])], det.window_size)
    updated_obs = Map.put(det.observations, metric, window)

    {emerged, new_events} =
      if length(window) >= 3 do
        check_emergence(metric, value, window, det)
      else
        {false, []}
      end

    updated = %{
      det
      | observations: updated_obs,
        events: (new_events ++ det.events) |> Enum.take(500),
        observation_count: det.observation_count + 1
    }

    {:ok, updated, emerged}
  end

  @doc """
  Return recent emergence events (most recent first), limited to `n`.
  """
  @spec recent_events(t(), pos_integer()) :: [emergence_event()]
  def recent_events(%__MODULE__{} = det, n) when is_integer(n) and n > 0 do
    Enum.take(det.events, n)
  end

  @doc """
  Return a summary of detector state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = det) do
    %{
      tracked_metrics: map_size(det.observations),
      total_observations: det.observation_count,
      total_events: length(det.events),
      window_size: det.window_size,
      spike_threshold: det.spike_threshold,
      phase_threshold: det.phase_threshold
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec check_emergence(String.t(), float(), [float()], t()) ::
          {boolean(), [emergence_event()]}
  defp check_emergence(metric, value, window, det) do
    mean = Enum.sum(window) / length(window)

    variance =
      Enum.reduce(window, 0.0, fn x, acc -> acc + (x - mean) * (x - mean) end) / length(window)

    std_dev = :math.sqrt(variance)

    spike_fired = std_dev > 0.0 and std_dev / max(mean, 0.0001) > det.spike_threshold
    phase_fired = mean > 0.0 and value / mean > det.phase_threshold

    events =
      cond do
        spike_fired ->
          [make_event(metric, value, mean, std_dev, :variance_spike)]

        phase_fired ->
          [make_event(metric, value, mean, std_dev, :phase_transition)]

        true ->
          []
      end

    {events != [], events}
  end

  @spec make_event(String.t(), float(), float(), float(), atom()) :: emergence_event()
  defp make_event(metric, value, mean, std_dev, trigger) do
    %{
      metric: metric,
      value: Float.round(value, 4),
      mean: Float.round(mean, 4),
      std_dev: Float.round(std_dev, 4),
      trigger: trigger,
      detected_at: System.monotonic_time(:millisecond)
    }
  end
end
