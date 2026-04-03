defmodule Indrajaal.Substrate.L0.ChemicalGradient do
  @moduledoc """
  ## Design Intent
  L0 substrate chemical gradient — pure functional module modelling a
  concentration gradient used for chemical signaling between substrate
  components.  Inspired by morphogen gradients in developmental biology
  where a diffusing molecule establishes positional information.

  Gradient model:
    - `source_concentration` — emitter level [0.0, 1.0]
    - `decay_rate`           — concentration lost per unit distance (default 0.1)
    - `noise_floor`          — minimum detectable signal (default 0.01)
    - Concentration at distance d = source × exp(-decay_rate × d), clamped
      to [noise_floor, 1.0]
    - `diffuse/2` steps the gradient forward by applying decay to the source
    - `sense/2`   returns the signal strength at a given distance

  All functions are pure — the struct is explicit state. No GenServer, no ETS.

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
          source_concentration: float(),
          decay_rate: float(),
          noise_floor: float(),
          diffusion_steps: non_neg_integer(),
          peak_concentration: float()
        }

  defstruct source_concentration: 1.0,
            decay_rate: 0.1,
            noise_floor: 0.01,
            diffusion_steps: 0,
            peak_concentration: 1.0

  @doc """
  Create a new chemical gradient struct.

  Options:
    - `:source_concentration` (float in [0.0, 1.0], default 1.0)
    - `:decay_rate`           (positive float, default 0.1)
    - `:noise_floor`          (float in (0.0, 0.5], default 0.01)
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    src = Keyword.get(opts, :source_concentration, 1.0)
    decay = Keyword.get(opts, :decay_rate, 0.1)
    noise = Keyword.get(opts, :noise_floor, 0.01)

    cond do
      not is_float(src) or src < 0.0 or src > 1.0 ->
        {:error, "source_concentration must be a float in [0.0, 1.0]"}

      not is_float(decay) or decay <= 0.0 ->
        {:error, "decay_rate must be a positive float"}

      not is_float(noise) or noise <= 0.0 or noise >= 0.5 ->
        {:error, "noise_floor must be a float in (0.0, 0.5)"}

      true ->
        {:ok,
         %__MODULE__{
           source_concentration: src,
           decay_rate: decay,
           noise_floor: noise,
           peak_concentration: src
         }}
    end
  end

  @doc """
  Compute the signal strength at `distance` units from the source.

  Returns a float in `[noise_floor, 1.0]`.
  """
  @spec sense(t(), float()) :: float()
  def sense(%__MODULE__{} = g, distance) when is_float(distance) and distance >= 0.0 do
    raw = g.source_concentration * :math.exp(-g.decay_rate * distance)
    max(g.noise_floor, min(1.0, raw))
  end

  @doc """
  Step the gradient forward by one diffusion tick, reducing source concentration
  by one `decay_rate` fraction.

  Returns `{:ok, updated_gradient}`.
  """
  @spec diffuse(t()) :: {:ok, t()}
  def diffuse(%__MODULE__{} = g) do
    new_src = max(g.noise_floor, g.source_concentration * (1.0 - g.decay_rate))

    {:ok, %{g | source_concentration: new_src, diffusion_steps: g.diffusion_steps + 1}}
  end

  @doc """
  Replenish the source to `level` (clamped to [0.0, 1.0]).
  Returns `{:ok, updated_gradient}`.
  """
  @spec replenish(t(), float()) :: {:ok, t()} | {:error, String.t()}
  def replenish(%__MODULE__{} = g, level) when is_float(level) do
    if level < 0.0 or level > 1.0 do
      {:error, "level must be in [0.0, 1.0]"}
    else
      {:ok, %{g | source_concentration: level}}
    end
  end

  @doc "Return a summary map of the gradient's current state."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = g) do
    %{
      source_concentration: Float.round(g.source_concentration, 4),
      decay_rate: g.decay_rate,
      noise_floor: g.noise_floor,
      diffusion_steps: g.diffusion_steps,
      peak_concentration: Float.round(g.peak_concentration, 4),
      is_detectable: g.source_concentration > g.noise_floor
    }
  end
end
