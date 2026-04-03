defmodule Indrajaal.Deployment.PrometheusManager do
  @moduledoc """
  Prometheus metric registration and catalogue.

  WHAT: Registers and tracks Prometheus metric definitions (name, type, description).
  WHY: Centralises metric catalogue so agents can discover registered observability points.
  CONSTRAINTS: SC-OBS-069, SC-OBS-071
  """

  @table :deployment_prometheus_manager

  @spec register_metric(String.t(), atom(), String.t()) :: :ok | {:error, :already_registered}
  def register_metric(name, type, description)
      when is_binary(name) and type in [:counter, :gauge, :histogram, :summary] do
    ensure_table()

    case :ets.lookup(@table, name) do
      [_] ->
        {:error, :already_registered}

      [] ->
        entry = %{
          name: name,
          type: type,
          description: description,
          registered_at: DateTime.utc_now()
        }

        :ets.insert(@table, {name, entry})
        :ok
    end
  end

  @spec list_metrics() :: [map()]
  def list_metrics do
    ensure_table()
    :ets.tab2list(@table) |> Enum.map(fn {_k, v} -> v end)
  end

  @spec get_metric_config(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_metric_config(name) do
    ensure_table()

    case :ets.lookup(@table, name) do
      [{^name, config}] -> {:ok, config}
      [] -> {:error, :not_found}
    end
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end
end
