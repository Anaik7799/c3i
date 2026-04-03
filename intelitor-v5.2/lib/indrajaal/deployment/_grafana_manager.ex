defmodule Indrajaal.Deployment.GrafanaManager do
  @moduledoc """
  Grafana dashboard configuration registry.

  WHAT: Registers and retrieves Grafana dashboard panel configurations.
  WHY: Centralises dashboard definitions so agents can discover and render observability panels.
  CONSTRAINTS: SC-OBS-069, SC-OBS-071
  """

  @table :deployment_grafana_manager

  @spec register_dashboard(String.t(), [map()]) :: :ok
  def register_dashboard(name, panels) when is_binary(name) and is_list(panels) do
    ensure_table()

    entry = %{
      name: name,
      panels: panels,
      panel_count: length(panels),
      registered_at: DateTime.utc_now()
    }

    :ets.insert(@table, {name, entry})
    :ok
  end

  @spec get_dashboard(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_dashboard(name) do
    ensure_table()

    case :ets.lookup(@table, name) do
      [{^name, dashboard}] -> {:ok, dashboard}
      [] -> {:error, :not_found}
    end
  end

  @spec list_dashboards() :: [map()]
  def list_dashboards do
    ensure_table()
    :ets.tab2list(@table) |> Enum.map(fn {_k, v} -> v end)
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end
end
