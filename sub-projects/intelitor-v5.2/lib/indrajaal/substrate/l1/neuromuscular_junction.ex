defmodule Indrajaal.Substrate.L1.NeuromuscularJunction do
  @moduledoc """
  ## Design Intent
  L1 substrate neuromuscular junction — pure functional signal-to-action
  interface.  Inspired by the neuromuscular junction (NMJ) where motor
  neurons release acetylcholine (ACh) into the synaptic cleft, binding
  nicotinic receptors on the muscle end-plate and triggering contraction.

  NMJ model:
    - `vesicle_count`    — ACh vesicles available for release [0, max_vesicles]
    - `receptor_occupancy` — fraction of receptors bound [0.0, 1.0]
    - `end_plate_potential` — summed receptor signal [0.0, 1.0]
    - `threshold`        — EPP level required to trigger action potential (default 0.6)
    - `release/2`        — release N vesicles; raises EPP proportionally
    - `reuptake/1`       — clear synaptic cleft; vesicles regenerated partially
    - `fire?/1`          — true when EPP >= threshold
    - `replenish/2`      — add vesicles (synthesis)

  All functions are pure. No GenServer, no ETS.

  ## STAMP Constraints
  - SC-S1-001: Cybernetic VSM S1 operations — ENFORCED
  - SC-S1-003: S1 operational response — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type t :: %__MODULE__{
          vesicle_count: non_neg_integer(),
          max_vesicles: pos_integer(),
          receptor_occupancy: float(),
          end_plate_potential: float(),
          threshold: float(),
          release_count: non_neg_integer(),
          fire_count: non_neg_integer()
        }

  defstruct vesicle_count: 50,
            max_vesicles: 100,
            receptor_occupancy: 0.0,
            end_plate_potential: 0.0,
            threshold: 0.6,
            release_count: 0,
            fire_count: 0

  @doc """
  Create a new neuromuscular junction struct.

  Options:
    - `:max_vesicles`    (positive integer, default 100)
    - `:threshold`       (float in (0.0, 1.0], default 0.6)
    - `:vesicle_count`   (non-negative integer <= max_vesicles, default 50)
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    max_v = Keyword.get(opts, :max_vesicles, 100)
    thresh = Keyword.get(opts, :threshold, 0.6)
    init_v = Keyword.get(opts, :vesicle_count, 50)

    cond do
      not is_integer(max_v) or max_v < 1 ->
        {:error, "max_vesicles must be a positive integer"}

      not is_float(thresh) or thresh <= 0.0 or thresh > 1.0 ->
        {:error, "threshold must be a float in (0.0, 1.0]"}

      not is_integer(init_v) or init_v < 0 or init_v > max_v ->
        {:error, "vesicle_count must be in [0, max_vesicles]"}

      true ->
        {:ok,
         %__MODULE__{
           max_vesicles: max_v,
           vesicle_count: init_v,
           threshold: thresh
         }}
    end
  end

  @doc """
  Release `n` vesicles into the synaptic cleft (default 1).

  Raises end-plate potential proportionally to vesicles released.
  Returns `{:fired, updated}` if EPP >= threshold, otherwise `{:ok, updated}`.
  Returns `{:error, :depleted}` if vesicle_count < n.
  """
  @spec release(t(), pos_integer()) ::
          {:ok, t()} | {:fired, t()} | {:error, :depleted}
  def release(junction, n \\ 1)

  def release(%__MODULE__{} = jct, n) when is_integer(n) and n >= 1 do
    if jct.vesicle_count < n do
      {:error, :depleted}
    else
      increment = n / jct.max_vesicles
      new_epp = min(1.0, jct.end_plate_potential + increment)
      new_occ = min(1.0, jct.receptor_occupancy + increment * 0.8)

      updated = %{
        jct
        | vesicle_count: jct.vesicle_count - n,
          end_plate_potential: new_epp,
          receptor_occupancy: new_occ,
          release_count: jct.release_count + 1
      }

      if new_epp >= jct.threshold do
        {:fired, %{updated | fire_count: jct.fire_count + 1}}
      else
        {:ok, updated}
      end
    end
  end

  @doc """
  Clear the synaptic cleft: EPP and occupancy reset; partial vesicle recycling.
  Returns `{:ok, updated_junction}`.
  """
  @spec reuptake(t()) :: {:ok, t()}
  def reuptake(%__MODULE__{} = jct) do
    recycled = round(jct.max_vesicles * 0.1)
    new_count = min(jct.max_vesicles, jct.vesicle_count + recycled)

    {:ok, %{jct | end_plate_potential: 0.0, receptor_occupancy: 0.0, vesicle_count: new_count}}
  end

  @doc """
  Add `n` vesicles (de-novo synthesis). Capped at max_vesicles.
  Returns `{:ok, updated_junction}`.
  """
  @spec replenish(t(), pos_integer()) :: {:ok, t()}
  def replenish(%__MODULE__{} = jct, n) when is_integer(n) and n >= 1 do
    new_count = min(jct.max_vesicles, jct.vesicle_count + n)
    {:ok, %{jct | vesicle_count: new_count}}
  end

  @doc "Returns true when end_plate_potential >= threshold."
  @spec fire?(t()) :: boolean()
  def fire?(%__MODULE__{} = jct), do: jct.end_plate_potential >= jct.threshold

  @doc "Return a summary map of the junction's current state."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = jct) do
    %{
      vesicle_count: jct.vesicle_count,
      max_vesicles: jct.max_vesicles,
      vesicle_fraction: Float.round(jct.vesicle_count / jct.max_vesicles, 4),
      receptor_occupancy: Float.round(jct.receptor_occupancy, 4),
      end_plate_potential: Float.round(jct.end_plate_potential, 4),
      threshold: jct.threshold,
      release_count: jct.release_count,
      fire_count: jct.fire_count,
      is_firing: fire?(jct)
    }
  end
end
