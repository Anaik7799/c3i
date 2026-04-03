defmodule Indrajaal.Substrate.L5.StrategicHorizon do
  @moduledoc """
  L5 Strategic Horizon — Long-term planning horizon tracker for the identity layer.

  Models the temporal planning horizon of the holon across three planning bands:
  - Tactical  (0–90 days):  immediate adaptation, resource allocation
  - Operational (91–365 days): capability development, partnership building
  - Strategic   (1–5 years):  structural change, identity evolution

  Each horizon band holds a set of named milestones with target dates,
  completion state, and strategic weight. The module computes a horizon
  health score as the weighted completion ratio.

  ## STAMP Constraints
  - SC-S5-001: Cybernetic VSM S5 policy — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type band :: :tactical | :operational | :strategic

  @type milestone :: %{
          id: String.t(),
          name: String.t(),
          band: band(),
          target_days: pos_integer(),
          weight: float(),
          completed: boolean()
        }

  @type t :: %__MODULE__{
          milestones: [milestone()],
          label: String.t()
        }

  defstruct milestones: [],
            label: "default"

  @valid_bands [:tactical, :operational, :strategic]
  @band_weights %{tactical: 1.0, operational: 1.5, strategic: 2.0}

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    label = Keyword.get(opts, :label, "default")

    cond do
      not is_binary(label) ->
        {:error, "label must be a string"}

      true ->
        {:ok, %__MODULE__{label: label}}
    end
  end

  @spec add_milestone(t(), String.t(), band(), pos_integer(), float()) ::
          {:ok, t()} | {:error, String.t()}
  def add_milestone(%__MODULE__{} = state, name, band, target_days, weight)
      when is_binary(name) do
    cond do
      band not in @valid_bands ->
        {:error, "band must be one of #{inspect(@valid_bands)}"}

      not is_integer(target_days) or target_days < 1 ->
        {:error, "target_days must be a positive integer"}

      not is_number(weight) ->
        {:error, "weight must be numeric"}

      true ->
        milestone = %{
          id: generate_id(),
          name: name,
          band: band,
          target_days: target_days,
          weight: clamp(weight),
          completed: false
        }

        {:ok, %{state | milestones: state.milestones ++ [milestone]}}
    end
  end

  @spec complete_milestone(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def complete_milestone(%__MODULE__{} = state, id) when is_binary(id) do
    case Enum.find(state.milestones, fn m -> m.id == id end) do
      nil ->
        {:error, "milestone #{id} not found"}

      _found ->
        updated =
          Enum.map(state.milestones, fn m ->
            if m.id == id, do: %{m | completed: true}, else: m
          end)

        {:ok, %{state | milestones: updated}}
    end
  end

  @spec horizon_health(t()) :: float()
  def horizon_health(%__MODULE__{milestones: []}), do: 1.0

  def horizon_health(%__MODULE__{milestones: milestones}) do
    total_weight =
      Enum.reduce(milestones, 0.0, fn m, acc ->
        acc + m.weight * Map.get(@band_weights, m.band, 1.0)
      end)

    completed_weight =
      milestones
      |> Enum.filter(& &1.completed)
      |> Enum.reduce(0.0, fn m, acc ->
        acc + m.weight * Map.get(@band_weights, m.band, 1.0)
      end)

    if total_weight == 0.0, do: 1.0, else: Float.round(completed_weight / total_weight, 4)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    by_band =
      Enum.group_by(state.milestones, & &1.band)
      |> Map.new(fn {k, v} ->
        {k, %{total: length(v), completed: Enum.count(v, & &1.completed)}}
      end)

    %{
      label: state.label,
      total_milestones: length(state.milestones),
      completed: Enum.count(state.milestones, & &1.completed),
      horizon_health: horizon_health(state),
      bands: by_band
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp clamp(v) when is_number(v), do: Float.round(min(1.0, max(0.0, v / 1.0)), 4)
  defp clamp(_), do: 0.5

  defp generate_id do
    :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
  end
end
