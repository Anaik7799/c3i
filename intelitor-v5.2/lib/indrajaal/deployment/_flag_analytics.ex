defmodule Indrajaal.Deployment.FlagAnalytics do
  @moduledoc """
  Feature flag evaluation counter analytics.

  WHAT: Records true/false evaluation counts per flag using :counters for lock-free ops.
  WHY: Provides usage telemetry for feature flags without database overhead.
  CONSTRAINTS: SC-PRF-050, SC-OBS-069
  """

  @table :deployment_flag_analytics

  @spec record_evaluation(String.t(), boolean()) :: :ok
  def record_evaluation(flag_name, result) when is_binary(flag_name) and is_boolean(result) do
    ensure_table()
    ref = get_or_create_ref(flag_name)
    idx = if result, do: 1, else: 2
    :counters.add(ref, idx, 1)
    :ok
  end

  @spec get_stats(String.t()) :: map()
  def get_stats(flag_name) when is_binary(flag_name) do
    ensure_table()

    case :ets.lookup(@table, flag_name) do
      [{^flag_name, ref}] ->
        true_count = :counters.get(ref, 1)
        false_count = :counters.get(ref, 2)
        total = true_count + false_count
        rate = if total > 0, do: Float.round(true_count / total, 4), else: 0.0

        %{
          flag: flag_name,
          true_count: true_count,
          false_count: false_count,
          total: total,
          true_rate: rate
        }

      [] ->
        %{flag: flag_name, true_count: 0, false_count: 0, total: 0, true_rate: 0.0}
    end
  end

  @spec reset() :: :ok
  def reset do
    ensure_table()
    :ets.delete_all_objects(@table)
    :ok
  end

  defp get_or_create_ref(flag_name) do
    case :ets.lookup(@table, flag_name) do
      [{^flag_name, ref}] ->
        ref

      [] ->
        ref = :counters.new(2, [:atomics])
        :ets.insert_new(@table, {flag_name, ref})

        case :ets.lookup(@table, flag_name) do
          [{^flag_name, existing}] -> existing
          [] -> ref
        end
    end
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end
end
