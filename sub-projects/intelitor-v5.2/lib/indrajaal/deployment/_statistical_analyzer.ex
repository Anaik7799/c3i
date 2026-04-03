defmodule Indrajaal.Deployment.StatisticalAnalyzer do
  @moduledoc """
  A/B test statistical analysis with online mean and standard deviation.

  WHAT: Accumulates samples per (experiment, variant) and computes descriptive stats on demand.
  WHY: Provides lightweight experiment analysis without an external stats service.
  CONSTRAINTS: SC-PRF-050
  """

  @table :deployment_statistical_analyzer

  @spec add_sample(String.t(), String.t(), number()) :: :ok
  def add_sample(experiment, variant, value) when is_number(value) do
    ensure_table()
    key = {experiment, variant}

    state =
      case :ets.lookup(@table, key) do
        [{^key, s}] -> s
        [] -> %{count: 0, mean: 0.0, m2: 0.0}
      end

    count = state.count + 1
    delta = value - state.mean
    mean = state.mean + delta / count
    delta2 = value - mean
    m2 = state.m2 + delta * delta2

    :ets.insert(@table, {key, %{count: count, mean: mean, m2: m2}})
    :ok
  end

  @spec compute_stats(String.t()) :: map()
  def compute_stats(experiment) do
    ensure_table()

    variants =
      :ets.tab2list(@table)
      |> Enum.filter(fn {{exp, _variant}, _} -> exp == experiment end)
      |> Enum.map(fn {{_exp, variant}, state} ->
        stddev =
          if state.count > 1,
            do: Float.round(:math.sqrt(state.m2 / (state.count - 1)), 6),
            else: 0.0

        {variant, %{count: state.count, mean: Float.round(state.mean, 6), stddev: stddev}}
      end)
      |> Map.new()

    %{experiment: experiment, variants: variants}
  end

  @spec clear(String.t()) :: :ok
  def clear(experiment) do
    ensure_table()

    :ets.tab2list(@table)
    |> Enum.filter(fn {{exp, _}, _} -> exp == experiment end)
    |> Enum.each(fn {key, _} -> :ets.delete(@table, key) end)

    :ok
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end
end
