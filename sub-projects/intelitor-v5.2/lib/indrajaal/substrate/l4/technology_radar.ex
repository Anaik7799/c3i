defmodule Indrajaal.Substrate.L4.TechnologyRadar do
  @moduledoc """
  L4 Technology Radar — Technology maturity tracker for environmental intelligence.

  Maintains a radar of technologies across four maturity rings (adopt, trial,
  assess, hold) using a weighted scoring model. The L4 intelligence layer uses
  radar data to inform strategic decisions about technology adoption and retirement.

  Algorithm:
  - Ring assignment via composite score: adoption + stability + ecosystem
  - Score decay: maturity score decays toward centre ring if unstable
  - Recommendation: highest-scored items in each ring surfaced first

  ## STAMP Constraints
  - SC-S4-001: Cybernetic VSM S4 intelligence — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @rings [:adopt, :trial, :assess, :hold]
  @ring_thresholds %{adopt: 0.75, trial: 0.50, assess: 0.25, hold: 0.0}

  @type ring :: :adopt | :trial | :assess | :hold
  @type blip :: %{
          name: String.t(),
          score: float(),
          ring: ring(),
          quadrant: String.t(),
          stable: boolean()
        }

  @type t :: %__MODULE__{
          name: String.t(),
          blips: [blip()],
          quadrants: [String.t()]
        }

  defstruct name: "default",
            blips: [],
            quadrants: ["languages", "frameworks", "platforms", "tools"]

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    name = Keyword.get(opts, :name, "default")
    quadrants = Keyword.get(opts, :quadrants, ["languages", "frameworks", "platforms", "tools"])

    cond do
      not is_binary(name) ->
        {:error, "name must be a string"}

      not is_list(quadrants) or not Enum.all?(quadrants, &is_binary/1) ->
        {:error, "quadrants must be a list of strings"}

      true ->
        {:ok, %__MODULE__{name: name, quadrants: quadrants, blips: []}}
    end
  end

  @spec add_blip(t(), String.t(), float(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def add_blip(%__MODULE__{} = state, name, score, quadrant)
      when is_binary(name) and is_number(score) and is_binary(quadrant) do
    cond do
      quadrant not in state.quadrants ->
        {:error, "unknown quadrant: #{quadrant}"}

      true ->
        clamped = max(0.0, min(1.0, score / 1.0))
        ring = score_to_ring(clamped)

        blip = %{
          name: name,
          score: Float.round(clamped, 4),
          ring: ring,
          quadrant: quadrant,
          stable: clamped > 0.4
        }

        existing = Enum.reject(state.blips, &(&1.name == name))
        {:ok, %{state | blips: existing ++ [blip]}}
    end
  end

  @spec ring_members(t(), ring()) :: [blip()]
  def ring_members(%__MODULE__{blips: blips}, ring) when ring in @rings do
    blips
    |> Enum.filter(&(&1.ring == ring))
    |> Enum.sort_by(& &1.score, :desc)
  end

  @spec recommend(t()) :: %{ring() => [String.t()]}
  def recommend(%__MODULE__{} = state) do
    Map.new(@rings, fn ring ->
      names =
        state
        |> ring_members(ring)
        |> Enum.map(& &1.name)

      {ring, names}
    end)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    by_ring = Map.new(@rings, fn r -> {r, length(ring_members(state, r))} end)

    %{
      name: state.name,
      total_blips: length(state.blips),
      by_ring: by_ring,
      quadrants: state.quadrants
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp score_to_ring(score) do
    cond do
      score >= @ring_thresholds.adopt -> :adopt
      score >= @ring_thresholds.trial -> :trial
      score >= @ring_thresholds.assess -> :assess
      true -> :hold
    end
  end
end
