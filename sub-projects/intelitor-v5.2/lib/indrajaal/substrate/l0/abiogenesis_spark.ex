defmodule Indrajaal.Substrate.L0.AbiogenesisSpark do
  @moduledoc """
  ## Design Intent
  L0 substrate abiogenesis spark — pure functional module modelling the
  emergence trigger that converts inert substrate energy into a self-sustaining
  process.  Inspired by the Miller-Urey experiment: random energetic events
  in a rich chemical environment occasionally produce self-replicating molecules.

  Spark model:
    - `energy_level`     — accumulated energy [0.0, 1.0]
    - `complexity`       — molecular complexity index [0.0, 1.0]
    - `threshold`        — minimum energy×complexity product to ignite (default 0.6)
    - `ignition_count`   — number of successful emergence events observed
    - `charge/2`         — accumulate energy; returns {:ok, state} or {:ignited, state}
    - `catalyse/2`       — boost complexity by a catalyst factor
    - `quench/1`         — reset energy to zero (failed conditions)

  Ignition condition: `energy_level × complexity >= threshold`

  All functions are pure. No GenServer, no ETS.

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L0 — ENFORCED
  - SC-SAFETY-009: Ψ₀ (Existence) validated for all operations — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type t :: %__MODULE__{
          energy_level: float(),
          complexity: float(),
          threshold: float(),
          ignition_count: non_neg_integer(),
          last_event: :idle | :charged | :catalysed | :ignited | :quenched
        }

  defstruct energy_level: 0.0,
            complexity: 0.1,
            threshold: 0.6,
            ignition_count: 0,
            last_event: :idle

  @doc """
  Create a new abiogenesis spark struct.

  Options:
    - `:energy_level` (float in [0.0, 1.0], default 0.0)
    - `:complexity`   (float in (0.0, 1.0], default 0.1)
    - `:threshold`    (float in (0.0, 1.0], default 0.6)
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    energy = Keyword.get(opts, :energy_level, 0.0)
    complexity = Keyword.get(opts, :complexity, 0.1)
    threshold = Keyword.get(opts, :threshold, 0.6)

    cond do
      not is_float(energy) or energy < 0.0 or energy > 1.0 ->
        {:error, "energy_level must be a float in [0.0, 1.0]"}

      not is_float(complexity) or complexity <= 0.0 or complexity > 1.0 ->
        {:error, "complexity must be a float in (0.0, 1.0]"}

      not is_float(threshold) or threshold <= 0.0 or threshold > 1.0 ->
        {:error, "threshold must be a float in (0.0, 1.0]"}

      true ->
        {:ok, %__MODULE__{energy_level: energy, complexity: complexity, threshold: threshold}}
    end
  end

  @doc """
  Charge the spark by `delta` energy (clamped to [0.0, 1.0]).

  Returns `{:ignited, updated}` if the ignition condition is met,
  otherwise `{:ok, updated}`.
  """
  @spec charge(t(), float()) :: {:ok, t()} | {:ignited, t()} | {:error, String.t()}
  def charge(%__MODULE__{} = spark, delta) when is_float(delta) do
    if delta < 0.0 do
      {:error, "delta must be >= 0.0"}
    else
      new_energy = min(1.0, spark.energy_level + delta)
      updated = %{spark | energy_level: new_energy, last_event: :charged}

      if new_energy * spark.complexity >= spark.threshold do
        {:ignited, %{updated | ignition_count: spark.ignition_count + 1, last_event: :ignited}}
      else
        {:ok, updated}
      end
    end
  end

  @doc """
  Apply a catalytic boost to complexity by `factor` (multiplicative, clamped to [0.0, 1.0]).
  Returns `{:ok, updated}`.
  """
  @spec catalyse(t(), float()) :: {:ok, t()} | {:error, String.t()}
  def catalyse(%__MODULE__{} = spark, factor) when is_float(factor) do
    cond do
      factor < 1.0 ->
        {:error, "catalyst factor must be >= 1.0"}

      true ->
        new_complexity = min(1.0, spark.complexity * factor)
        {:ok, %{spark | complexity: new_complexity, last_event: :catalysed}}
    end
  end

  @doc """
  Reset energy to zero (environmental conditions collapse).
  Returns `{:ok, updated}`.
  """
  @spec quench(t()) :: {:ok, t()}
  def quench(%__MODULE__{} = spark) do
    {:ok, %{spark | energy_level: 0.0, last_event: :quenched}}
  end

  @doc "Return a summary map of the spark's current state."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = spark) do
    product = Float.round(spark.energy_level * spark.complexity, 4)

    %{
      energy_level: Float.round(spark.energy_level, 4),
      complexity: Float.round(spark.complexity, 4),
      threshold: spark.threshold,
      ignition_count: spark.ignition_count,
      last_event: spark.last_event,
      ignition_potential: product,
      ready_to_ignite: product >= spark.threshold
    }
  end
end
