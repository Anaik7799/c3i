defmodule Indrajaal.Deployment.RolloutController do
  @moduledoc """
  Gradual feature rollout controller with hash-based user bucketing.

  WHAT: Assigns users deterministically to rollout buckets via phash2 for stable decisions.
  WHY: Enables percentage-based gradual rollout where users consistently see or don't see a feature.
  CONSTRAINTS: SC-GDE-001, SC-GDE-002
  """

  @table :deployment_rollout_controller

  @spec set_rollout(term(), non_neg_integer()) :: :ok
  def set_rollout(feature, percentage) when percentage in 0..100 do
    ensure_table()
    :ets.insert(@table, {feature, percentage})
    :ok
  end

  @spec check_rollout(term(), term()) :: boolean()
  def check_rollout(feature, user_id) do
    ensure_table()
    percentage = get_rollout(feature)
    bucket = :erlang.phash2({feature, user_id}, 100)
    bucket < percentage
  end

  @spec get_rollout(term()) :: non_neg_integer()
  def get_rollout(feature) do
    ensure_table()

    case :ets.lookup(@table, feature) do
      [{^feature, pct}] -> pct
      [] -> 0
    end
  end

  @spec list_rollouts() :: [map()]
  def list_rollouts do
    ensure_table()

    :ets.tab2list(@table)
    |> Enum.map(fn {feature, pct} -> %{feature: feature, percentage: pct} end)
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end
end
