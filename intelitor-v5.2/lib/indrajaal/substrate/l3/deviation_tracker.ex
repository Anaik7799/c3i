defmodule Indrajaal.Substrate.L3.DeviationTracker do
  @moduledoc """
  ## Design Intent
  L3 substrate deviation tracker — pure functional standard deviation monitor
  for detecting anomalous variance in operational metrics.

  Biological metaphor: Homeostatic set-point regulation. The body maintains
  physiological variables (temperature, pH, blood glucose) within narrow
  bands. When variance from the set-point exceeds a tolerance, corrective
  mechanisms activate. This module tracks running variance and flags
  deviations that exceed configurable sigma thresholds.

  Algorithm (Welford online algorithm):
    - `observe/2` updates running mean, variance, and sample count.
    - Population variance is maintained as the running M2 accumulator.
    - Standard deviation = sqrt(M2 / count) for count >= 2, else 0.0.
    - `deviation_ratio/1` = stddev / mean (coefficient of variation), or 0.0.
    - `alert_level/1` returns :normal | :warning | :critical based on
      sigma multiples relative to the running mean.

  ## STAMP Constraints
  - SC-S3-001: Cybernetic VSM S3 control — ENFORCED
  - SC-S3-002: VSM S3 audit and accountability — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type alert_level :: :normal | :warning | :critical

  @type t :: %__MODULE__{
          count: non_neg_integer(),
          mean: float(),
          m2: float(),
          warning_sigma: float(),
          critical_sigma: float(),
          min_samples: non_neg_integer(),
          last_value: float() | nil,
          alert_count: non_neg_integer()
        }

  defstruct count: 0,
            mean: 0.0,
            m2: 0.0,
            warning_sigma: 2.0,
            critical_sigma: 3.0,
            min_samples: 5,
            last_value: nil,
            alert_count: 0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new DeviationTracker.

  Options:
    - `:warning_sigma`  (float, default 2.0) — stddev multiplier for :warning
    - `:critical_sigma` (float, default 3.0) — stddev multiplier for :critical
    - `:min_samples`    (integer >= 2, default 5) — minimum samples before alerting

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    warning_sigma = Keyword.get(opts, :warning_sigma, 2.0)
    critical_sigma = Keyword.get(opts, :critical_sigma, 3.0)
    min_samples = Keyword.get(opts, :min_samples, 5)

    cond do
      not is_float(warning_sigma) or warning_sigma <= 0.0 ->
        {:error, "warning_sigma must be a positive float"}

      not is_float(critical_sigma) or critical_sigma <= warning_sigma ->
        {:error, "critical_sigma must be > warning_sigma"}

      not is_integer(min_samples) or min_samples < 2 ->
        {:error, "min_samples must be an integer >= 2"}

      true ->
        {:ok,
         %__MODULE__{
           warning_sigma: warning_sigma,
           critical_sigma: critical_sigma,
           min_samples: min_samples
         }}
    end
  end

  @doc """
  Observe a new value, updating running statistics via Welford's algorithm.

  Returns `{:ok, updated}`.
  """
  @spec observe(t(), float()) :: {:ok, t()}
  def observe(%__MODULE__{} = tracker, value) when is_number(value) do
    fvalue = value * 1.0
    new_count = tracker.count + 1
    delta = fvalue - tracker.mean
    new_mean = tracker.mean + delta / new_count
    delta2 = fvalue - new_mean
    new_m2 = tracker.m2 + delta * delta2
    level = compute_alert_level(tracker, fvalue)
    new_alerts = if level != :normal, do: tracker.alert_count + 1, else: tracker.alert_count

    updated = %{
      tracker
      | count: new_count,
        mean: new_mean,
        m2: new_m2,
        last_value: fvalue,
        alert_count: new_alerts
    }

    {:ok, updated}
  end

  def observe(%__MODULE__{} = tracker, _value), do: {:ok, tracker}

  @doc """
  Returns the current standard deviation (population), or 0.0 if count < 2.
  """
  @spec std_dev(t()) :: float()
  def std_dev(%__MODULE__{count: c}) when c < 2, do: 0.0

  def std_dev(%__MODULE__{m2: m2, count: count}) do
    :math.sqrt(m2 / count)
  end

  @doc """
  Returns the coefficient of variation (stddev / mean), or 0.0 if mean == 0.
  """
  @spec deviation_ratio(t()) :: float()
  def deviation_ratio(%__MODULE__{} = tracker) do
    sd = std_dev(tracker)

    if tracker.mean == 0.0 do
      0.0
    else
      abs(sd / tracker.mean)
    end
  end

  @doc """
  Returns :normal, :warning, or :critical based on sigma thresholds.

  Requires at least `min_samples` observations; returns :normal otherwise.
  """
  @spec alert_level(t()) :: alert_level()
  def alert_level(%__MODULE__{} = tracker) do
    if tracker.last_value == nil or tracker.count < tracker.min_samples do
      :normal
    else
      compute_alert_level(tracker, tracker.last_value)
    end
  end

  @doc """
  Returns a summary status map.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = tracker) do
    %{
      count: tracker.count,
      mean: tracker.mean,
      std_dev: std_dev(tracker),
      deviation_ratio: deviation_ratio(tracker),
      alert_level: alert_level(tracker),
      warning_sigma: tracker.warning_sigma,
      critical_sigma: tracker.critical_sigma,
      min_samples: tracker.min_samples,
      alert_count: tracker.alert_count,
      last_value: tracker.last_value
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec compute_alert_level(t(), float()) :: alert_level()
  defp compute_alert_level(%__MODULE__{count: c} = tracker, value) when c >= 2 do
    sd = std_dev(tracker)

    if sd == 0.0 do
      :normal
    else
      sigma_distance = abs(value - tracker.mean) / sd

      cond do
        sigma_distance >= tracker.critical_sigma -> :critical
        sigma_distance >= tracker.warning_sigma -> :warning
        true -> :normal
      end
    end
  end

  defp compute_alert_level(_tracker, _value), do: :normal
end
