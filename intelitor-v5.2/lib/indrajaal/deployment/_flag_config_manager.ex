defmodule Indrajaal.Deployment.FlagConfigManager do
  @moduledoc """
  Feature flag configuration CRUD backed by ETS.

  WHAT: Create, read, update, delete, and list feature flag configuration maps.
  WHY: Provides an in-process feature flag store that survives without a database.
  CONSTRAINTS: SC-FUNC-001, SC-PRF-050
  """

  @table :deployment_flag_config_manager

  @spec create(String.t(), map()) :: :ok | {:error, :already_exists}
  def create(name, config) when is_binary(name) and is_map(config) do
    ensure_table()

    entry =
      Map.merge(config, %{
        name: name,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      })

    case :ets.insert_new(@table, {name, entry}) do
      true -> :ok
      false -> {:error, :already_exists}
    end
  end

  @spec get(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get(name) do
    ensure_table()

    case :ets.lookup(@table, name) do
      [{^name, config}] -> {:ok, config}
      [] -> {:error, :not_found}
    end
  end

  @spec update(String.t(), map()) :: :ok | {:error, :not_found}
  def update(name, changes) when is_map(changes) do
    ensure_table()

    case :ets.lookup(@table, name) do
      [{^name, existing}] ->
        updated = Map.merge(existing, changes) |> Map.put(:updated_at, DateTime.utc_now())
        :ets.insert(@table, {name, updated})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  @spec delete(String.t()) :: :ok
  def delete(name) do
    ensure_table()
    :ets.delete(@table, name)
    :ok
  end

  @spec list() :: [map()]
  def list do
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
