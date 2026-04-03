defmodule Indrajaal.Deployment.EmergencyControls do
  @moduledoc """
  Emergency kill switches and rollback registry for deployment features.

  WHAT: Activates/deactivates kill switches and records rollback markers per feature.
  WHY: Provides instant feature disablement during incidents without a restart.
  CONSTRAINTS: SC-EMR-057 (stop < 5s), SC-GDE-003 (rollback capability), SC-SAFETY-022
  """

  @table :deployment_emergency_controls

  @spec kill_switch(term()) :: :ok
  def kill_switch(feature) do
    ensure_table()

    :ets.insert(
      @table,
      {feature, %{killed: true, killed_at: DateTime.utc_now(), rolled_back: false}}
    )

    :telemetry.execute(
      [:indrajaal, :deployment, :kill_switch],
      %{count: 1},
      %{feature: feature, event: :activated}
    )

    :ok
  end

  @spec is_killed?(term()) :: boolean()
  def is_killed?(feature) do
    ensure_table()

    case :ets.lookup(@table, feature) do
      [{^feature, %{killed: true}}] -> true
      _ -> false
    end
  end

  @spec rollback(term()) :: :ok
  def rollback(feature) do
    ensure_table()

    entry =
      case :ets.lookup(@table, feature) do
        [{^feature, existing}] -> existing
        [] -> %{killed: false, killed_at: nil}
      end

    updated =
      Map.merge(entry, %{killed: false, rolled_back: true, rolled_back_at: DateTime.utc_now()})

    :ets.insert(@table, {feature, updated})

    :telemetry.execute(
      [:indrajaal, :deployment, :kill_switch],
      %{count: 1},
      %{feature: feature, event: :rolled_back}
    )

    :ok
  end

  @spec list_killed() :: [term()]
  def list_killed do
    ensure_table()

    :ets.tab2list(@table)
    |> Enum.filter(fn {_f, state} -> state.killed end)
    |> Enum.map(fn {feature, _} -> feature end)
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end
end
