defmodule Indrajaal.Substrate.L1.Sarcomere do
  @moduledoc """
  ## Design Intent
  L1 substrate sarcomere — pure functional contractile unit.  Inspired by the
  sarcomere, the fundamental repeat unit of striated muscle: myosin thick
  filaments walk along actin thin filaments in a power-stroke cycle, shortening
  the sarcomere and producing force.

  Sarcomere model:
    - `length`           — current length in normalised units [min_length, rest_length]
    - `rest_length`      — unactivated length (default 1.0)
    - `min_length`       — maximum contraction (default 0.5)
    - `activation`       — Ca²⁺-driven activation level [0.0, 1.0]
    - `force`            — instantaneous isometric force output [0.0, 1.0]
    - `contract/2`       — apply activation; shorten sarcomere; compute force
    - `relax/1`          — remove activation; return toward rest length
    - Length-tension relationship: force peaks at rest_length, falls off linearly

  Force = activation × length_factor, where:
    length_factor = 1.0 - |length - rest_length| / rest_length

  All functions are pure. No GenServer, no ETS.

  ## STAMP Constraints
  - SC-S1-001: Cybernetic VSM S1 operations — ENFORCED
  - SC-S1-003: S1 operational response — ENFORCED
  - SC-S1-004: S1 resource management — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type t :: %__MODULE__{
          length: float(),
          rest_length: float(),
          min_length: float(),
          activation: float(),
          force: float(),
          contraction_rate: float(),
          relaxation_rate: float(),
          cycle_count: non_neg_integer()
        }

  defstruct length: 1.0,
            rest_length: 1.0,
            min_length: 0.5,
            activation: 0.0,
            force: 0.0,
            contraction_rate: 0.1,
            relaxation_rate: 0.05,
            cycle_count: 0

  @doc """
  Create a new sarcomere struct.

  Options:
    - `:rest_length`      (positive float, default 1.0)
    - `:min_length`       (positive float < rest_length, default 0.5)
    - `:contraction_rate` (positive float, default 0.1)
    - `:relaxation_rate`  (positive float, default 0.05)
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    rest = Keyword.get(opts, :rest_length, 1.0)
    min_l = Keyword.get(opts, :min_length, 0.5)
    cont_r = Keyword.get(opts, :contraction_rate, 0.1)
    relax_r = Keyword.get(opts, :relaxation_rate, 0.05)

    cond do
      not is_float(rest) or rest <= 0.0 ->
        {:error, "rest_length must be a positive float"}

      not is_float(min_l) or min_l <= 0.0 or min_l >= rest ->
        {:error, "min_length must be in (0.0, rest_length)"}

      not is_float(cont_r) or cont_r <= 0.0 ->
        {:error, "contraction_rate must be a positive float"}

      not is_float(relax_r) or relax_r <= 0.0 ->
        {:error, "relaxation_rate must be a positive float"}

      true ->
        {:ok,
         %__MODULE__{
           rest_length: rest,
           length: rest,
           min_length: min_l,
           contraction_rate: cont_r,
           relaxation_rate: relax_r
         }}
    end
  end

  @doc """
  Apply `activation` level [0.0, 1.0] to the sarcomere.

  Shortens the sarcomere and computes isometric force.
  Returns `{:ok, force, updated_sarcomere}`.
  """
  @spec contract(t(), float()) :: {:ok, float(), t()} | {:error, String.t()}
  def contract(%__MODULE__{} = s, activation) when is_float(activation) do
    if activation < 0.0 or activation > 1.0 do
      {:error, "activation must be in [0.0, 1.0]"}
    else
      shortening = activation * s.contraction_rate
      new_length = max(s.min_length, s.length - shortening)
      force = compute_force(activation, new_length, s.rest_length)

      updated = %{
        s
        | activation: activation,
          length: new_length,
          force: force,
          cycle_count: s.cycle_count + 1
      }

      {:ok, force, updated}
    end
  end

  @doc """
  Remove activation; sarcomere returns toward rest length passively.
  Returns `{:ok, updated_sarcomere}`.
  """
  @spec relax(t()) :: {:ok, t()}
  def relax(%__MODULE__{} = s) do
    new_length = min(s.rest_length, s.length + s.relaxation_rate)

    {:ok, %{s | activation: 0.0, length: new_length, force: 0.0}}
  end

  @doc "Return a summary map of the sarcomere's current state."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = s) do
    contraction_pct = (s.rest_length - s.length) / (s.rest_length - s.min_length)

    %{
      length: Float.round(s.length, 4),
      rest_length: s.rest_length,
      min_length: s.min_length,
      activation: Float.round(s.activation, 4),
      force: Float.round(s.force, 4),
      contraction_pct: Float.round(max(0.0, contraction_pct), 4),
      cycle_count: s.cycle_count,
      is_contracting: s.activation > 0.0
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec compute_force(float(), float(), float()) :: float()
  defp compute_force(activation, length, rest_length) do
    length_factor = 1.0 - abs(length - rest_length) / rest_length
    max(0.0, min(1.0, activation * length_factor))
  end
end
