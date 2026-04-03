defmodule Indrajaal.Substrate.L7.NicheFinder do
  @moduledoc """
  ## Design Intent
  L7 substrate Niche Finder — pure functional ecological niche identification
  for the Indrajaal biomorphic ecosystem layer.

  Models Hutchinson's n-dimensional hypervolume niche theory: a holon's niche
  is the region of resource-space it can occupy without competition forcing
  it out. Each resource axis has a range [min, max] that the holon can exploit.

  Niche computation:
    - The ecosystem defines a set of resource axes, each with a total capacity.
    - A holon declares its preferred range [lo, hi] on each axis.
    - Niche breadth = mean of normalised (hi − lo) widths across all axes.
    - Niche overlap between two holons = mean overlap fraction per axis.
    - Niche uniqueness = 1 − max(overlap with any registered competitor).

  Uniqueness tiers:
    :dominant   (≥ 0.80) — near-exclusive niche, low competition
    :shared     (≥ 0.50) — partial niche overlap
    :contested  (≥ 0.20) — high competition
    :evicted    (< 0.20) — niche largely occupied by competitors

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — niche finder observes, never allocates
  - SC-ECO-006: Resource governance — niche claims cannot exceed axis capacity
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type uniqueness_tier :: :dominant | :shared | :contested | :evicted

  @type axis :: %{name: String.t(), capacity: float()}

  @type niche_claim :: %{
          holon_id: String.t(),
          ranges: %{String.t() => {float(), float()}},
          breadth: float(),
          registered_at: integer()
        }

  @type niche_result :: %{
          holon_id: String.t(),
          breadth: float(),
          uniqueness: float(),
          uniqueness_tier: uniqueness_tier(),
          max_overlap_with: String.t() | nil
        }

  @type t :: %__MODULE__{
          axes: %{String.t() => axis()},
          claims: %{String.t() => niche_claim()},
          analysis_count: non_neg_integer(),
          created_at: integer()
        }

  defstruct axes: %{},
            claims: %{},
            analysis_count: 0,
            created_at: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    axes_input = Keyword.get(opts, :axes, [])

    cond do
      not is_list(axes_input) ->
        {:error, "axes must be a list of {name, capacity} tuples"}

      true ->
        axes =
          Map.new(axes_input, fn {name, cap} ->
            {to_string(name), %{name: to_string(name), capacity: max(0.0, cap * 1.0)}}
          end)

        state = %__MODULE__{
          axes: axes,
          claims: %{},
          analysis_count: 0,
          created_at: System.monotonic_time(:second)
        }

        {:ok, state}
    end
  end

  @doc """
  Register a holon's niche claim. `ranges` maps axis name to `{lo, hi}` floats
  where `0.0 ≤ lo < hi ≤ axis.capacity`.
  Returns `{:ok, updated_finder}` or `{:error, reason}`.
  """
  @spec register(t(), String.t(), %{String.t() => {float(), float()}}) ::
          {:ok, t()} | {:error, String.t()}
  def register(%__MODULE__{} = nf, holon_id, ranges)
      when is_binary(holon_id) and is_map(ranges) do
    unknown = Map.keys(ranges) |> Enum.reject(&Map.has_key?(nf.axes, &1))

    cond do
      unknown != [] ->
        {:error, "unknown axes: #{inspect(unknown)}"}

      true ->
        breadth = compute_breadth(nf.axes, ranges)

        claim = %{
          holon_id: holon_id,
          ranges: ranges,
          breadth: breadth,
          registered_at: System.monotonic_time(:second)
        }

        {:ok, %{nf | claims: Map.put(nf.claims, holon_id, claim)}}
    end
  end

  @doc """
  Analyse the niche of `holon_id` against all registered competitors.
  Returns `{:ok, updated_finder, niche_result}` or `{:error, :not_found}`.
  """
  @spec analyse(t(), String.t()) :: {:ok, t(), niche_result()} | {:error, :not_found}
  def analyse(%__MODULE__{} = nf, holon_id) when is_binary(holon_id) do
    case Map.get(nf.claims, holon_id) do
      nil ->
        {:error, :not_found}

      claim ->
        {uniqueness, max_overlap_with} =
          nf.claims
          |> Map.delete(holon_id)
          |> Map.values()
          |> Enum.reduce({1.0, nil}, fn competitor, {min_uniq, rival} ->
            overlap = axis_overlap(nf.axes, claim.ranges, competitor.ranges)
            uniq = 1.0 - overlap

            if uniq < min_uniq do
              {uniq, competitor.holon_id}
            else
              {min_uniq, rival}
            end
          end)

        result = %{
          holon_id: holon_id,
          breadth: claim.breadth,
          uniqueness: Float.round(uniqueness, 4),
          uniqueness_tier: tier(uniqueness),
          max_overlap_with: max_overlap_with
        }

        updated = %{nf | analysis_count: nf.analysis_count + 1}
        {:ok, updated, result}
    end
  end

  @doc """
  Return a summary of niche finder state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = nf) do
    %{
      axis_count: map_size(nf.axes),
      registered_holons: map_size(nf.claims),
      analysis_count: nf.analysis_count,
      axes: Map.keys(nf.axes)
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec compute_breadth(%{String.t() => axis()}, %{String.t() => {float(), float()}}) :: float()
  defp compute_breadth(_axes, ranges) when map_size(ranges) == 0, do: 0.0

  defp compute_breadth(axes, ranges) do
    widths =
      Enum.map(ranges, fn {name, {lo, hi}} ->
        cap = get_in(axes, [name, :capacity]) || 1.0
        if cap > 0.0, do: (hi - lo) / cap, else: 0.0
      end)

    Float.round(Enum.sum(widths) / length(widths), 4)
  end

  @spec axis_overlap(
          %{String.t() => axis()},
          %{String.t() => {float(), float()}},
          %{String.t() => {float(), float()}}
        ) :: float()
  defp axis_overlap(_axes, ranges_a, ranges_b) do
    common_axes =
      MapSet.intersection(MapSet.new(Map.keys(ranges_a)), MapSet.new(Map.keys(ranges_b)))

    if MapSet.size(common_axes) == 0 do
      0.0
    else
      overlaps =
        Enum.map(common_axes, fn axis ->
          {lo_a, hi_a} = Map.get(ranges_a, axis, {0.0, 0.0})
          {lo_b, hi_b} = Map.get(ranges_b, axis, {0.0, 0.0})
          overlap_lo = max(lo_a, lo_b)
          overlap_hi = min(hi_a, hi_b)
          span_lo = min(lo_a, lo_b)
          span_hi = max(hi_a, hi_b)
          span = span_hi - span_lo
          if span > 0.0, do: max(0.0, overlap_hi - overlap_lo) / span, else: 0.0
        end)

      Float.round(Enum.sum(overlaps) / length(overlaps), 4)
    end
  end

  @spec tier(float()) :: uniqueness_tier()
  defp tier(u) when u >= 0.80, do: :dominant
  defp tier(u) when u >= 0.50, do: :shared
  defp tier(u) when u >= 0.20, do: :contested
  defp tier(_u), do: :evicted
end
