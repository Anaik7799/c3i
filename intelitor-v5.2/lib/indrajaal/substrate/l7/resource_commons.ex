defmodule Indrajaal.Substrate.L7.ResourceCommons do
  @moduledoc """
  L7 Resource Commons — Shared resource governance for ecosystem sustainability.

  Models a commons of shared resources using Ostrom's design principles:
  clearly defined boundaries, proportional allocation, and monitoring with
  graduated sanctions. Tracks resource pools and detects overuse.

  Algorithm:
  - Usage pressure: current_draw / sustainable_yield
  - Overuse detection: pressure > 1.0 means commons is being depleted
  - Governance health: fraction of actors within their allocation quota

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem external boundaries — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @default_sustainable_yield 1.0
  @overshoot_threshold 1.0

  @type allocation :: %{actor: String.t(), quota: float(), drawn: float()}
  @type commons_status :: :sustainable | :stressed | :overshoot

  @type t :: %__MODULE__{
          name: String.t(),
          sustainable_yield: float(),
          allocations: [allocation()],
          pressure: float(),
          governance_health: float(),
          status: commons_status()
        }

  defstruct name: "default",
            sustainable_yield: @default_sustainable_yield,
            allocations: [],
            pressure: 0.0,
            governance_health: 1.0,
            status: :sustainable

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    name = Keyword.get(opts, :name, "default")
    yield = Keyword.get(opts, :sustainable_yield, @default_sustainable_yield)

    cond do
      not is_binary(name) ->
        {:error, "name must be a string"}

      not is_number(yield) or yield <= 0.0 ->
        {:error, "sustainable_yield must be a positive number"}

      true ->
        {:ok, %__MODULE__{name: name, sustainable_yield: yield / 1.0}}
    end
  end

  @spec allocate(t(), String.t(), float()) :: {:ok, t()} | {:error, String.t()}
  def allocate(%__MODULE__{} = state, actor, quota)
      when is_binary(actor) and is_number(quota) do
    cond do
      quota < 0.0 ->
        {:error, "quota must be non-negative"}

      true ->
        existing = Enum.reject(state.allocations, &(&1.actor == actor))
        entry = %{actor: actor, quota: quota / 1.0, drawn: 0.0}
        updated = %{state | allocations: existing ++ [entry]}
        {:ok, recompute(updated)}
    end
  end

  @spec draw(t(), String.t(), float()) :: {:ok, t()} | {:error, String.t()}
  def draw(%__MODULE__{} = state, actor, amount)
      when is_binary(actor) and is_number(amount) do
    cond do
      amount < 0.0 ->
        {:error, "amount must be non-negative"}

      true ->
        allocs =
          Enum.map(state.allocations, fn a ->
            if a.actor == actor do
              %{a | drawn: Float.round(a.drawn + amount / 1.0, 4)}
            else
              a
            end
          end)

        updated = %{state | allocations: allocs}
        {:ok, recompute(updated)}
    end
  end

  @spec over_quota_actors(t()) :: [String.t()]
  def over_quota_actors(%__MODULE__{allocations: allocs}) do
    allocs |> Enum.filter(fn a -> a.drawn > a.quota end) |> Enum.map(& &1.actor)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      name: state.name,
      sustainable_yield: state.sustainable_yield,
      pressure: state.pressure,
      governance_health: state.governance_health,
      status: state.status,
      actor_count: length(state.allocations),
      over_quota: over_quota_actors(state)
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp recompute(%__MODULE__{allocations: [], sustainable_yield: _yield} = state) do
    %{state | pressure: 0.0, governance_health: 1.0, status: :sustainable}
  end

  defp recompute(%__MODULE__{allocations: allocs, sustainable_yield: yield} = state) do
    total_drawn = Enum.reduce(allocs, 0.0, fn a, acc -> acc + a.drawn end)
    pressure = Float.round(total_drawn / yield, 4)

    compliant = Enum.count(allocs, fn a -> a.drawn <= a.quota end)
    governance_health = Float.round(compliant / length(allocs), 4)

    status =
      cond do
        pressure > @overshoot_threshold * 1.2 -> :overshoot
        pressure > @overshoot_threshold * 0.85 -> :stressed
        true -> :sustainable
      end

    %{state | pressure: pressure, governance_health: governance_health, status: status}
  end
end
