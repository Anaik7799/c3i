defmodule Indrajaal.Substrate.L0.ReplicationFork do
  @moduledoc """
  ## Design Intent
  L0 substrate replication fork — pure functional module modelling a
  self-copying mechanism.  Inspired by the DNA replication fork where a
  helicase unwinds the double helix and polymerase synthesises complementary
  strands, allowing exact duplication of genetic information.

  Replication model:
    - `template_length`  — total units to be copied (integer >= 1)
    - `position`         — current fork position [0, template_length]
    - `fidelity`         — copy accuracy [0.0, 1.0] (probability of correct copy per unit)
    - `speed`            — units advanced per `advance/2` call (default 1)
    - `error_count`      — accumulated copy errors
    - `advance/2`        — move fork forward by `steps`, accumulate errors probabilistically
    - `is_complete?/1`   — true when position >= template_length

  Error model: each unit has `(1.0 - fidelity)` probability of mutation.
  Expected errors for n steps = n × (1 - fidelity).

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
          template_length: pos_integer(),
          position: non_neg_integer(),
          fidelity: float(),
          speed: pos_integer(),
          error_count: non_neg_integer(),
          cycle_count: non_neg_integer()
        }

  defstruct template_length: 100,
            position: 0,
            fidelity: 0.999,
            speed: 1,
            error_count: 0,
            cycle_count: 0

  @doc """
  Create a new replication fork struct.

  Options:
    - `:template_length` (positive integer, default 100)
    - `:fidelity`        (float in (0.0, 1.0], default 0.999)
    - `:speed`           (positive integer, default 1)
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    len = Keyword.get(opts, :template_length, 100)
    fidelity = Keyword.get(opts, :fidelity, 0.999)
    speed = Keyword.get(opts, :speed, 1)

    cond do
      not is_integer(len) or len < 1 ->
        {:error, "template_length must be a positive integer"}

      not is_float(fidelity) or fidelity <= 0.0 or fidelity > 1.0 ->
        {:error, "fidelity must be a float in (0.0, 1.0]"}

      not is_integer(speed) or speed < 1 ->
        {:error, "speed must be a positive integer"}

      true ->
        {:ok, %__MODULE__{template_length: len, fidelity: fidelity, speed: speed}}
    end
  end

  @doc """
  Advance the replication fork by `steps` units (default: fork's `speed`).

  Each step has a `(1 - fidelity)` chance of producing a copy error.
  Expected errors are computed deterministically as `steps × (1 - fidelity)`.

  Returns `{:ok, errors_this_advance, updated_fork}` or
          `{:complete, errors_this_advance, updated_fork}` when fully replicated.
  """
  @spec advance(t(), pos_integer()) ::
          {:ok, non_neg_integer(), t()} | {:complete, non_neg_integer(), t()}
  def advance(fork, steps \\ 1)

  def advance(%__MODULE__{} = fork, steps) when is_integer(steps) and steps >= 1 do
    remaining = fork.template_length - fork.position
    actual_steps = min(steps, remaining)
    new_position = fork.position + actual_steps

    # Deterministic expected error count (avoids non-determinism in pure fn)
    error_rate = 1.0 - fork.fidelity
    new_errors = round(actual_steps * error_rate)

    updated = %{
      fork
      | position: new_position,
        error_count: fork.error_count + new_errors
    }

    if new_position >= fork.template_length do
      {:complete, new_errors, %{updated | cycle_count: fork.cycle_count + 1}}
    else
      {:ok, new_errors, updated}
    end
  end

  @doc """
  Reset the fork to position 0 for a new replication cycle.
  Returns `{:ok, updated_fork}`.
  """
  @spec reset(t()) :: {:ok, t()}
  def reset(%__MODULE__{} = fork) do
    {:ok, %{fork | position: 0}}
  end

  @doc "Returns true when the fork has reached the end of the template."
  @spec complete?(t()) :: boolean()
  def complete?(%__MODULE__{} = fork), do: fork.position >= fork.template_length

  @doc "Return a summary map of the fork's current state."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = fork) do
    progress = if fork.template_length > 0, do: fork.position / fork.template_length, else: 0.0

    %{
      template_length: fork.template_length,
      position: fork.position,
      progress: Float.round(progress, 4),
      fidelity: fork.fidelity,
      speed: fork.speed,
      error_count: fork.error_count,
      cycle_count: fork.cycle_count,
      is_complete: complete?(fork)
    }
  end
end
