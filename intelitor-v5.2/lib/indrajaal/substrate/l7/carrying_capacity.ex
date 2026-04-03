defmodule Indrajaal.Substrate.L7.CarryingCapacity do
  @moduledoc """
  ## Design Intent
  L7 substrate carrying capacity — pure functional module that models
  environmental limits for a population within an ecosystem.

  Biological metaphor: logistic growth model (Verhulst equation) — a
  population K (carrying capacity) represents the maximum load an
  environment can sustainably support. Beyond K, resource depletion
  accelerates collapse. Stress index rises sharply as load approaches K.

  Algorithm:
    - Carrying capacity K per resource dimension.
    - Load ratio = current_load / K, clamped to [0.0, ∞).
    - Stress index = load_ratio² (accelerating penalty near saturation).
    - Overshoot = max(0, load_ratio - 1.0) × 100 expressed as percent.
    - Sustainability score = max(0, 1.0 − stress_index) across all dimensions.
    - `project/3` computes load ratio at future time given growth rate r
      using logistic formula: P(t) = K / (1 + (K/P0 - 1) × e^(-r×t)).

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — ENFORCED
  - SC-ECO-002: Ecosystem integration — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type dimension :: %{
          capacity: float(),
          description: String.t()
        }

  @type load_assessment :: %{
          dimension: String.t(),
          current_load: float(),
          capacity: float(),
          load_ratio: float(),
          stress_index: float(),
          overshoot_pct: float(),
          sustainable: boolean()
        }

  @type t :: %__MODULE__{
          dimensions: %{String.t() => dimension()},
          assessment_count: non_neg_integer()
        }

  defstruct dimensions: %{},
            assessment_count: 0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new CarryingCapacity model.

  Options:
    - `:dimensions` — `%{name => %{capacity: float, description: string}}`
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    dims = Keyword.get(opts, :dimensions, %{})

    cond do
      not is_map(dims) ->
        {:error, "dimensions must be a map"}

      not all_dims_valid?(dims) ->
        {:error, "each dimension requires capacity > 0 and a string description"}

      true ->
        {:ok, %__MODULE__{dimensions: dims}}
    end
  end

  @doc "Register or update a resource dimension."
  @spec add_dimension(t(), String.t(), float(), String.t()) ::
          {:ok, t()} | {:error, String.t()}
  def add_dimension(%__MODULE__{} = state, name, capacity, description)
      when is_binary(name) and is_binary(description) do
    cond do
      capacity <= 0.0 ->
        {:error, "capacity must be > 0"}

      true ->
        dim = %{capacity: capacity, description: description}
        {:ok, %{state | dimensions: Map.put(state.dimensions, name, dim)}}
    end
  end

  def add_dimension(%__MODULE__{}, _name, _cap, _desc),
    do: {:error, "name and description must be strings"}

  @doc """
  Assess current load against carrying capacities.

  `loads` maps dimension names to current load values (≥ 0.0).
  Returns a list of `load_assessment` maps and updated state.
  """
  @spec assess(t(), %{String.t() => float()}) :: {[load_assessment()], t()}
  def assess(%__MODULE__{} = state, loads) when is_map(loads) do
    assessments =
      Enum.map(state.dimensions, fn {name, dim} ->
        current = max(0.0, Map.get(loads, name, 0.0))
        ratio = current / dim.capacity
        stress = min(4.0, ratio * ratio)
        overshoot = max(0.0, (ratio - 1.0) * 100.0)

        %{
          dimension: name,
          current_load: Float.round(current, 4),
          capacity: dim.capacity,
          load_ratio: Float.round(ratio, 4),
          stress_index: Float.round(stress, 4),
          overshoot_pct: Float.round(overshoot, 2),
          sustainable: ratio <= 1.0
        }
      end)

    new_state = %{state | assessment_count: state.assessment_count + 1}
    {assessments, new_state}
  end

  @doc """
  Project population load at time `t` using logistic growth.

  - `initial_load` — current population/load.
  - `growth_rate` — intrinsic rate of increase r (per time unit).
  - `t` — time units ahead to project.
  - `dimension` — name of the dimension to use for K.

  Returns `{:ok, projected_load}` or `{:error, reason}`.
  """
  @spec project(t(), String.t(), float(), float(), float()) ::
          {:ok, float()} | {:error, String.t()}
  def project(%__MODULE__{} = state, dimension, initial_load, growth_rate, t)
      when is_float(initial_load) and is_float(growth_rate) and is_float(t) do
    case Map.get(state.dimensions, dimension) do
      nil ->
        {:error, "dimension #{dimension} not found"}

      %{capacity: k} ->
        p0 = max(0.0, initial_load)

        projected =
          if p0 == 0.0 do
            0.0
          else
            # Logistic: P(t) = K / (1 + ((K - P0) / P0) * exp(-r*t))
            ratio = (k - p0) / p0
            k / (1.0 + ratio * :math.exp(-growth_rate * t))
          end

        {:ok, Float.round(projected, 4)}
    end
  end

  @doc "Returns a summary status map."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      dimension_count: map_size(state.dimensions),
      assessment_count: state.assessment_count,
      dimensions: Map.keys(state.dimensions)
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec all_dims_valid?(map()) :: boolean()
  defp all_dims_valid?(dims) do
    Enum.all?(dims, fn
      {_k, %{capacity: c, description: d}} when is_float(c) and is_binary(d) ->
        c > 0.0

      _ ->
        false
    end)
  end
end
