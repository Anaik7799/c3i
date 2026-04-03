defmodule Indrajaal.Deployment.AlertManager do
  @moduledoc """
  Deployment alert lifecycle management.

  WHAT: Creates, acknowledges, resolves, and lists deployment alerts backed by ETS.
  WHY: Provides a lightweight alert bus without requiring a running GenServer.
  CONSTRAINTS: SC-OBS-069, SC-EMR-057
  """

  @table :deployment_alert_manager

  @spec create_alert(atom(), String.t()) :: {:ok, String.t()}
  def create_alert(severity, message) when severity in [:info, :warning, :critical] do
    ensure_table()
    alert_id = Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)

    alert = %{
      id: alert_id,
      severity: severity,
      message: message,
      status: :active,
      created_at: DateTime.utc_now(),
      acknowledged_at: nil,
      resolved_at: nil
    }

    :ets.insert(@table, {alert_id, alert})

    :telemetry.execute(
      [:indrajaal, :deployment, :alert],
      %{count: 1},
      %{alert_id: alert_id, severity: severity, event: :created}
    )

    {:ok, alert_id}
  end

  @spec acknowledge(String.t()) :: :ok | {:error, :not_found}
  def acknowledge(alert_id) do
    update_alert(alert_id, :acknowledged, %{
      status: :acknowledged,
      acknowledged_at: DateTime.utc_now()
    })
  end

  @spec resolve(String.t()) :: :ok | {:error, :not_found}
  def resolve(alert_id) do
    update_alert(alert_id, :resolved, %{status: :resolved, resolved_at: DateTime.utc_now()})
  end

  @spec list_active() :: [map()]
  def list_active do
    ensure_table()

    :ets.tab2list(@table)
    |> Enum.filter(fn {_id, alert} -> alert.status == :active end)
    |> Enum.map(fn {_id, alert} -> alert end)
  end

  defp update_alert(alert_id, event, changes) do
    ensure_table()

    case :ets.lookup(@table, alert_id) do
      [{^alert_id, alert}] ->
        updated = Map.merge(alert, changes)
        :ets.insert(@table, {alert_id, updated})

        :telemetry.execute(
          [:indrajaal, :deployment, :alert],
          %{count: 1},
          %{alert_id: alert_id, severity: alert.severity, event: event}
        )

        :ok

      [] ->
        {:error, :not_found}
    end
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end
end
