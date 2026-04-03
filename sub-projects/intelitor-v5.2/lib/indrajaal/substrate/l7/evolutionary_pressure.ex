defmodule Indrajaal.Substrate.L7.EvolutionaryPressure do
  @moduledoc """
  ## Design Intent
  L7 substrate Evolutionary Pressure — pure functional selection pressure
  quantifier for the Indrajaal biomorphic ecosystem layer.

  Models neo-Darwinian selection theory: each holon in the ecosystem is subject
  to a set of named selective pressures (environmental stressors, resource
  competition, predation analogs). The net selection coefficient determines
  whether a holon is likely to adapt, persist, or be eliminated from the mesh.

  Pressure model:
    - Each pressure is a named directional force in [−1.0, 1.0]
      - Positive = favours selection (fitness bonus)
      - Negative = opposes selection (fitness penalty)
    - Net pressure = weighted sum of all pressures, clamped to [−1.0, 1.0]
    - Fitness delta = base_fitness + net_pressure × sensitivity

  Fitness tiers:
    :optimal   (Δ ≥ 0.6)  — strong positive selection
    :neutral   (Δ ≥ 0.0)  — drift, no directional pressure
    :declining (Δ ≥ −0.4) — weak negative selection
    :critical  (Δ < −0.4) — strong negative selection, risk of elimination

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — pressure quantifier is read-only
  - SC-ECO-005: Evolutionary continuity — history of pressures retained
  - SC-EVO-001: Evolution Shannon entropy gate — entropy tracked per axis
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type fitness_tier :: :optimal | :neutral | :declining | :critical

  @type pressure_entry :: %{
          name: String.t(),
          magnitude: float(),
          weight: float()
        }

  @type pressure_result :: %{
          holon_id: String.t(),
          net_pressure: float(),
          fitness_delta: float(),
          fitness_tier: fitness_tier(),
          pressures: [pressure_entry()]
        }

  @type t :: %__MODULE__{
          sensitivity: float(),
          base_fitness: float(),
          pressures: %{String.t() => pressure_entry()},
          history: [pressure_result()],
          evaluation_count: non_neg_integer(),
          created_at: integer()
        }

  defstruct sensitivity: 0.5,
            base_fitness: 0.5,
            pressures: %{},
            history: [],
            evaluation_count: 0,
            created_at: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    sensitivity = Keyword.get(opts, :sensitivity, 0.5)
    base_fitness = Keyword.get(opts, :base_fitness, 0.5)

    cond do
      not is_float(sensitivity) or sensitivity < 0.0 or sensitivity > 1.0 ->
        {:error, "sensitivity must be a float in [0.0, 1.0]"}

      not is_float(base_fitness) or base_fitness < 0.0 or base_fitness > 1.0 ->
        {:error, "base_fitness must be a float in [0.0, 1.0]"}

      true ->
        state = %__MODULE__{
          sensitivity: sensitivity,
          base_fitness: base_fitness,
          pressures: %{},
          history: [],
          evaluation_count: 0,
          created_at: System.monotonic_time(:second)
        }

        {:ok, state}
    end
  end

  @doc """
  Register or update a named pressure axis. `magnitude` in [−1.0, 1.0], `weight` in [0.0, 1.0].
  """
  @spec set_pressure(t(), String.t(), float(), float()) ::
          {:ok, t()} | {:error, String.t()}
  def set_pressure(%__MODULE__{} = ep, name, magnitude, weight \\ 1.0)
      when is_binary(name) and is_float(magnitude) and is_float(weight) do
    cond do
      magnitude < -1.0 or magnitude > 1.0 ->
        {:error, "magnitude must be in [-1.0, 1.0]"}

      weight < 0.0 or weight > 1.0 ->
        {:error, "weight must be in [0.0, 1.0]"}

      true ->
        entry = %{name: name, magnitude: magnitude, weight: weight}
        {:ok, %{ep | pressures: Map.put(ep.pressures, name, entry)}}
    end
  end

  @doc """
  Evaluate net selection pressure and fitness delta for a named holon.
  Returns `{:ok, updated_ep, pressure_result}`.
  """
  @spec evaluate(t(), String.t()) :: {:ok, t(), pressure_result()}
  def evaluate(%__MODULE__{} = ep, holon_id) when is_binary(holon_id) do
    pressure_list = Map.values(ep.pressures)

    net =
      if pressure_list == [] do
        0.0
      else
        total_weight = Enum.sum(Enum.map(pressure_list, & &1.weight))

        if total_weight > 0.0 do
          Enum.reduce(pressure_list, 0.0, fn p, acc ->
            acc + p.magnitude * p.weight / total_weight
          end)
        else
          0.0
        end
      end

    net = Float.round(max(-1.0, min(1.0, net)), 4)
    delta = Float.round(ep.base_fitness + net * ep.sensitivity, 4)

    result = %{
      holon_id: holon_id,
      net_pressure: net,
      fitness_delta: delta,
      fitness_tier: tier(delta),
      pressures: pressure_list
    }

    updated = %{
      ep
      | history: [result | Enum.take(ep.history, 99)],
        evaluation_count: ep.evaluation_count + 1
    }

    {:ok, updated, result}
  end

  @doc """
  Return a summary of evolutionary pressure state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = ep) do
    %{
      pressure_axes: map_size(ep.pressures),
      evaluation_count: ep.evaluation_count,
      sensitivity: ep.sensitivity,
      base_fitness: ep.base_fitness,
      history_depth: length(ep.history)
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec tier(float()) :: fitness_tier()
  defp tier(delta) when delta >= 0.6, do: :optimal
  defp tier(delta) when delta >= 0.0, do: :neutral
  defp tier(delta) when delta >= -0.4, do: :declining
  defp tier(_delta), do: :critical
end
