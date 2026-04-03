defmodule Indrajaal.Deployment.TrafficSplitter do
  @moduledoc """
  ETS-backed traffic splitter for canary/stable percentage routing.

  WHAT: Routes requests to :canary or :stable based on configured percentages.
  WHY: Enables safe gradual rollouts with real-time adjustable split ratios.
  CONSTRAINTS: SC-GDE-002 (shadow testing), SC-PRF-050 (latency < 50ms)
  """

  @table :deployment_traffic_splitter

  @spec init() :: :ok
  def init do
    ensure_table()
    :ok
  end

  @spec split(term(), map()) :: :canary | :stable
  def split(request, config) do
    ensure_table()
    feature = Map.get(config, :feature, :default)
    percentage = get_split(feature)
    bucket = :erlang.phash2(request, 100)
    result = if bucket < percentage, do: :canary, else: :stable

    :telemetry.execute(
      [:indrajaal, :deployment, :traffic_split],
      %{bucket: bucket, percentage: percentage},
      %{feature: feature, result: result}
    )

    result
  end

  @spec set_percentage(term(), non_neg_integer()) :: :ok
  def set_percentage(feature, percentage) when percentage in 0..100 do
    ensure_table()
    :ets.insert(@table, {feature, percentage})
    :ok
  end

  @spec get_split(term()) :: non_neg_integer()
  def get_split(feature) do
    ensure_table()

    case :ets.lookup(@table, feature) do
      [{^feature, pct}] -> pct
      [] -> 0
    end
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end
end
