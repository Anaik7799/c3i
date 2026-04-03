defmodule Indrajaal.Substrate.L1.ActinFilament do
  @moduledoc """
  ## Design Intent
  L1 substrate actin filament — pure functional structural scaffold module.
  Inspired by F-actin (filamentous actin) which forms the cytoskeletal backbone
  of cells, providing mechanical support, anchoring points for motor proteins,
  and dynamic remodelling under load.

  Filament model:
    - `length`           — current filament length in normalised units [0.0, 10.0]
    - `tension`          — mechanical load applied [0.0, 1.0]
    - `polymerisation_rate` — growth per `polymerise/2` call (default 0.2)
    - `depolymerisation_rate` — shrinkage per `depolymerise/1` call (default 0.1)
    - `crosslink_count`  — number of bound motor-protein attachment points
    - `polymerise/2`     — extend filament by actin monomers
    - `depolymerise/1`   — retract filament (treadmilling)
    - `apply_tension/2`  — set mechanical load; returns {:buckling, _} if > max_tension
    - `crosslink/2`      — attach motor protein at position along filament

  All functions are pure. No GenServer, no ETS.

  ## STAMP Constraints
  - SC-S1-001: Cybernetic VSM S1 operations — ENFORCED
  - SC-S1-002: S1 sensory input processing — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type t :: %__MODULE__{
          length: float(),
          tension: float(),
          max_tension: float(),
          polymerisation_rate: float(),
          depolymerisation_rate: float(),
          crosslink_count: non_neg_integer(),
          buckle_count: non_neg_integer()
        }

  defstruct length: 1.0,
            tension: 0.0,
            max_tension: 0.8,
            polymerisation_rate: 0.2,
            depolymerisation_rate: 0.1,
            crosslink_count: 0,
            buckle_count: 0

  @max_length 10.0

  @doc """
  Create a new actin filament struct.

  Options:
    - `:length`                (float in (0.0, 10.0], default 1.0)
    - `:max_tension`           (float in (0.0, 1.0], default 0.8)
    - `:polymerisation_rate`   (positive float, default 0.2)
    - `:depolymerisation_rate` (positive float, default 0.1)
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    len = Keyword.get(opts, :length, 1.0)
    max_t = Keyword.get(opts, :max_tension, 0.8)
    poly_r = Keyword.get(opts, :polymerisation_rate, 0.2)
    depoly_r = Keyword.get(opts, :depolymerisation_rate, 0.1)

    cond do
      not is_float(len) or len <= 0.0 or len > @max_length ->
        {:error, "length must be in (0.0, #{@max_length}]"}

      not is_float(max_t) or max_t <= 0.0 or max_t > 1.0 ->
        {:error, "max_tension must be in (0.0, 1.0]"}

      not is_float(poly_r) or poly_r <= 0.0 ->
        {:error, "polymerisation_rate must be a positive float"}

      not is_float(depoly_r) or depoly_r <= 0.0 ->
        {:error, "depolymerisation_rate must be a positive float"}

      true ->
        {:ok,
         %__MODULE__{
           length: len,
           max_tension: max_t,
           polymerisation_rate: poly_r,
           depolymerisation_rate: depoly_r
         }}
    end
  end

  @doc """
  Extend the filament by `units` monomers (default: polymerisation_rate).
  Returns `{:ok, updated_filament}`.
  """
  @spec polymerise(t(), float()) :: {:ok, t()}
  def polymerise(filament, units \\ 0.0)

  def polymerise(%__MODULE__{} = fil, units) when units == 0.0 do
    new_len = min(@max_length, fil.length + fil.polymerisation_rate)
    {:ok, %{fil | length: new_len}}
  end

  def polymerise(%__MODULE__{} = fil, units) when is_float(units) and units > 0.0 do
    new_len = min(@max_length, fil.length + units)
    {:ok, %{fil | length: new_len}}
  end

  @doc """
  Retract the filament by one depolymerisation_rate step.
  Filament will not shrink below 0.01 (minimum stub).
  Returns `{:ok, updated_filament}`.
  """
  @spec depolymerise(t()) :: {:ok, t()}
  def depolymerise(%__MODULE__{} = fil) do
    new_len = max(0.01, fil.length - fil.depolymerisation_rate)
    {:ok, %{fil | length: new_len}}
  end

  @doc """
  Apply mechanical tension `t` to the filament.
  Returns `{:ok, updated}` or `{:buckling, updated}` if tension > max_tension.
  """
  @spec apply_tension(t(), float()) :: {:ok, t()} | {:buckling, t()} | {:error, String.t()}
  def apply_tension(%__MODULE__{} = fil, tension) when is_float(tension) do
    if tension < 0.0 or tension > 1.0 do
      {:error, "tension must be in [0.0, 1.0]"}
    else
      updated = %{fil | tension: tension}

      if tension > fil.max_tension do
        {:buckling, %{updated | buckle_count: fil.buckle_count + 1}}
      else
        {:ok, updated}
      end
    end
  end

  @doc """
  Add a crosslink (motor protein attachment point).
  Returns `{:ok, updated_filament}`.
  """
  @spec crosslink(t()) :: {:ok, t()}
  def crosslink(%__MODULE__{} = fil) do
    {:ok, %{fil | crosslink_count: fil.crosslink_count + 1}}
  end

  @doc "Return a summary map of the filament's current state."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = fil) do
    %{
      length: Float.round(fil.length, 4),
      tension: Float.round(fil.tension, 4),
      max_tension: fil.max_tension,
      polymerisation_rate: fil.polymerisation_rate,
      depolymerisation_rate: fil.depolymerisation_rate,
      crosslink_count: fil.crosslink_count,
      buckle_count: fil.buckle_count,
      is_under_stress: fil.tension > fil.max_tension * 0.8
    }
  end
end
