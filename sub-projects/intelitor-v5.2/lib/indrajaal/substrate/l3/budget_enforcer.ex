defmodule Indrajaal.Substrate.L3.BudgetEnforcer do
  @moduledoc """
  ## Design Intent
  L3 substrate budget enforcer — pure functional module that enforces budget
  constraints across named resource categories.

  Biological metaphor: Liver glycogen budget — the liver allocates stored
  glucose to different organs under strict quotas. If a organ's demand
  exceeds its allocated quota, excess is refused. Total budget is the
  aggregate of all quotas.

  Algorithm:
    - Each category has an allocated `quota` (hard upper bound).
    - `spend/3` deducts an amount from a category's remaining balance.
    - Spending is refused if: amount > remaining balance, or amount > quota.
    - `reset/1` restores all balances to their full quotas.
    - `utilization/1` computes per-category % utilization.
    - Total budget = sum of all quotas; total spent = sum of all debits.

  ## STAMP Constraints
  - SC-S3-001: Cybernetic VSM S3 control — ENFORCED
  - SC-S3-002: VSM S3 audit and accountability — ENFORCED
  - SC-S3-003: VSM S3 resource management — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type category :: String.t()

  @type budget_entry :: %{
          quota: float(),
          remaining: float(),
          spent: float(),
          reject_count: non_neg_integer()
        }

  @type t :: %__MODULE__{
          categories: %{category() => budget_entry()},
          cycle: non_neg_integer(),
          total_rejects: non_neg_integer()
        }

  defstruct categories: %{},
            cycle: 0,
            total_rejects: 0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new BudgetEnforcer with optional initial categories.

  Options:
    - `:categories` — map of `%{name => quota_float}` (default `%{}`)

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    raw = Keyword.get(opts, :categories, %{})

    cond do
      not is_map(raw) ->
        {:error, "categories must be a map"}

      not all_quotas_valid?(raw) ->
        {:error, "all category quotas must be positive floats"}

      true ->
        cats = Map.new(raw, fn {k, quota} -> {k, make_entry(quota)} end)
        {:ok, %__MODULE__{categories: cats}}
    end
  end

  @doc """
  Register or replace a budget category with the given quota.

  Returns `{:ok, updated}` or `{:error, reason}`.
  """
  @spec register(t(), category(), float()) :: {:ok, t()} | {:error, String.t()}
  def register(%__MODULE__{} = state, name, quota)
      when is_binary(name) and is_float(quota) and quota > 0.0 do
    updated_cats = Map.put(state.categories, name, make_entry(quota))
    {:ok, %{state | categories: updated_cats}}
  end

  def register(%__MODULE__{}, _name, _quota),
    do: {:error, "name must be a non-empty string and quota must be a positive float"}

  @doc """
  Attempt to spend `amount` from category `name`.

  Returns:
    - `{:ok, remaining, updated}` — spend approved
    - `{:error, :unknown_category}` — category not registered
    - `{:error, :insufficient_budget}` — amount exceeds remaining balance

  Amount is clamped to `>= 0.0` before evaluation.
  """
  @spec spend(t(), category(), float()) ::
          {:ok, float(), t()} | {:error, :unknown_category | :insufficient_budget, t()}
  def spend(%__MODULE__{} = state, name, amount)
      when is_binary(name) and is_float(amount) do
    clamped = max(0.0, amount)

    case Map.get(state.categories, name) do
      nil ->
        {:error, :unknown_category, state}

      entry ->
        if clamped > entry.remaining do
          new_entry = %{entry | reject_count: entry.reject_count + 1}

          updated = %{
            state
            | categories: Map.put(state.categories, name, new_entry),
              total_rejects: state.total_rejects + 1
          }

          {:error, :insufficient_budget, updated}
        else
          new_entry = %{
            entry
            | remaining: entry.remaining - clamped,
              spent: entry.spent + clamped
          }

          updated = %{state | categories: Map.put(state.categories, name, new_entry)}
          {:ok, new_entry.remaining, updated}
        end
    end
  end

  def spend(%__MODULE__{} = state, _name, _amount), do: {:error, :unknown_category, state}

  @doc """
  Reset all category balances to their full quotas and increment the cycle counter.

  Returns `{:ok, updated}`.
  """
  @spec reset(t()) :: {:ok, t()}
  def reset(%__MODULE__{} = state) do
    reset_cats = Map.new(state.categories, fn {k, e} -> {k, make_entry(e.quota)} end)
    {:ok, %{state | categories: reset_cats, cycle: state.cycle + 1}}
  end

  @doc """
  Returns per-category utilization as a map of `%{name => pct_float}`.

  `pct` is in [0.0, 1.0] where 1.0 = fully spent.
  """
  @spec utilization(t()) :: %{category() => float()}
  def utilization(%__MODULE__{} = state) do
    Map.new(state.categories, fn {k, e} ->
      pct = if e.quota > 0.0, do: e.spent / e.quota, else: 0.0
      {k, Float.round(clamp(pct, 0.0, 1.0), 4)}
    end)
  end

  @doc """
  Returns a summary status map.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    total_quota = state.categories |> Map.values() |> Enum.map(& &1.quota) |> Enum.sum()
    total_spent = state.categories |> Map.values() |> Enum.map(& &1.spent) |> Enum.sum()

    %{
      category_count: map_size(state.categories),
      total_quota: total_quota,
      total_spent: total_spent,
      total_rejects: state.total_rejects,
      cycle: state.cycle,
      utilization: utilization(state)
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec make_entry(float()) :: budget_entry()
  defp make_entry(quota) do
    %{quota: quota, remaining: quota, spent: 0.0, reject_count: 0}
  end

  @spec all_quotas_valid?(map()) :: boolean()
  defp all_quotas_valid?(raw) do
    Enum.all?(raw, fn
      {_k, v} when is_float(v) -> v > 0.0
      _ -> false
    end)
  end

  @spec clamp(float(), float(), float()) :: float()
  defp clamp(v, lo, hi), do: max(lo, min(hi, v))
end
