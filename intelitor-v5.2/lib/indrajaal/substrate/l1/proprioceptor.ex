defmodule Indrajaal.Substrate.L1.Proprioceptor do
  @moduledoc """
  ## Design Intent
  L1 substrate proprioceptor — pure functional position and force sensing
  module. Models biological proprioception: the sense that tells an organism
  where its body parts are and how much force they are exerting, without
  relying on external vision.

  In the substrate layer the proprioceptor maintains a normalised picture of
  internal system state (position in configuration space, load level, deviation
  from set-point) computed from raw metric samples passed in by the caller.
  All functions are pure — metrics are passed in explicitly rather than sampled
  from BEAM internals, making the module deterministic and testable.

  Model:
    - `position` — normalised float [0.0, 1.0] representing current state in
      its operational range (0.0 = minimum, 1.0 = maximum)
    - `load` — normalised float [0.0, 1.0] representing current force/effort
    - `set_point` — target position (default 0.5, midrange)
    - `deviation` — |position - set_point|, recomputed on each `sense/3` call
    - `anomaly_threshold` — deviation above which `anomaly?/1` returns true

  ## STAMP Constraints
  - SC-S1-001: Cybernetic VSM S1 subsystem sensing — ENFORCED
  - SC-VER-041: OODA cycle < 100ms (pure computation, sub-microsecond) — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type t :: %__MODULE__{
          position: float(),
          load: float(),
          set_point: float(),
          deviation: float(),
          anomaly_threshold: float(),
          sense_count: non_neg_integer(),
          anomaly_count: non_neg_integer()
        }

  defstruct position: 0.0,
            load: 0.0,
            set_point: 0.5,
            deviation: 0.5,
            anomaly_threshold: 0.3,
            sense_count: 0,
            anomaly_count: 0

  @default_set_point 0.5
  @default_anomaly_threshold 0.3

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new proprioceptor.

  Options:
    - `:set_point`          (float in [0.0, 1.0], default 0.5)
    - `:anomaly_threshold`  (float in (0.0, 1.0], default 0.3)

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    set_point = Keyword.get(opts, :set_point, @default_set_point)
    threshold = Keyword.get(opts, :anomaly_threshold, @default_anomaly_threshold)

    cond do
      not is_float(set_point) or set_point < 0.0 or set_point > 1.0 ->
        {:error, "set_point must be a float in [0.0, 1.0]"}

      not is_float(threshold) or threshold <= 0.0 or threshold > 1.0 ->
        {:error, "anomaly_threshold must be a float in (0.0, 1.0]"}

      true ->
        sensor = %__MODULE__{
          set_point: set_point,
          anomaly_threshold: threshold,
          deviation: set_point
        }

        {:ok, sensor}
    end
  end

  @doc """
  Update the sensor with a new `position` and `load` sample.

  Both must be floats in [0.0, 1.0]. Recomputes `deviation` and increments
  `anomaly_count` if the new deviation exceeds `anomaly_threshold`.

  Returns `{:ok, updated_sensor}`.
  """
  @spec sense(t(), float(), float()) :: {:ok, t()} | {:error, String.t()}
  def sense(%__MODULE__{} = sensor, position, load)
      when is_float(position) and position >= 0.0 and position <= 1.0 and
             is_float(load) and load >= 0.0 and load <= 1.0 do
    deviation = abs(position - sensor.set_point)
    is_anomaly = deviation > sensor.anomaly_threshold
    new_anomaly_count = if is_anomaly, do: sensor.anomaly_count + 1, else: sensor.anomaly_count

    updated = %{
      sensor
      | position: position,
        load: load,
        deviation: deviation,
        sense_count: sensor.sense_count + 1,
        anomaly_count: new_anomaly_count
    }

    {:ok, updated}
  end

  def sense(%__MODULE__{}, _position, _load),
    do: {:error, "position and load must be floats in [0.0, 1.0]"}

  @doc """
  Update the set-point target while preserving all other state.

  Returns `{:ok, updated_sensor}` or `{:error, reason}`.
  """
  @spec calibrate(t(), float()) :: {:ok, t()} | {:error, String.t()}
  def calibrate(%__MODULE__{} = sensor, new_set_point)
      when is_float(new_set_point) and new_set_point >= 0.0 and new_set_point <= 1.0 do
    deviation = abs(sensor.position - new_set_point)
    {:ok, %{sensor | set_point: new_set_point, deviation: deviation}}
  end

  def calibrate(%__MODULE__{}, _), do: {:error, "set_point must be a float in [0.0, 1.0]"}

  @doc """
  Returns true when current deviation exceeds `anomaly_threshold`.
  """
  @spec anomaly?(t()) :: boolean()
  def anomaly?(%__MODULE__{deviation: d, anomaly_threshold: t}), do: d > t

  @doc """
  Returns a status map summarising the proprioceptor state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = sensor) do
    %{
      position: Float.round(sensor.position, 4),
      load: Float.round(sensor.load, 4),
      set_point: sensor.set_point,
      deviation: Float.round(sensor.deviation, 4),
      anomaly_threshold: sensor.anomaly_threshold,
      is_anomaly: anomaly?(sensor),
      sense_count: sensor.sense_count,
      anomaly_count: sensor.anomaly_count,
      anomaly_rate_pct:
        if sensor.sense_count > 0 do
          Float.round(sensor.anomaly_count / sensor.sense_count * 100.0, 1)
        else
          0.0
        end
    }
  end
end
