defmodule Indrajaal.Observability.HealthCheck do
  @moduledoc """
  Provides health check logic for the Indrajaal system.
  Implements standard liveness and readiness checks.
  """

  require Logger

  @doc """
  Returns true if the application is alive.
  Simple check to see if the BEAM is running.
  """
  def liveness do
    true
  end

  @doc """
  Returns true if the application is ready to traffic.
  Checks database connection and critical services.
  """
  def readiness do
    with :ok <- check_database(),
         :ok <- check_redis(),
         :ok <- check_zenoh() do
      true
    else
      {:error, reason} ->
        Logger.error("Readiness check failed: #{inspect(reason)}")
        false
    end
  end

  defp check_database do
    case Ecto.Adapters.SQL.query(Indrajaal.Repo, "SELECT 1", []) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {:database, reason}}
    end
  rescue
    reason -> {:error, {:database, reason}}
  end

  defp check_redis do
    case Redix.command(:redix, ["PING"]) do
      {:ok, "PONG"} -> :ok
      {:error, reason} -> {:error, {:redis, reason}}
    end
  rescue
    reason -> {:error, {:redis, reason}}
  end

  defp check_zenoh do
    if Process.whereis(Indrajaal.Observability.ZenohSession) do
      :ok
    else
      {:error, :zenoh_not_running}
    end
  end
end
