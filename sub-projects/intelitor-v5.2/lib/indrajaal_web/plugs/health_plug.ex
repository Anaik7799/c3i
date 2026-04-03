defmodule IndrajaalWeb.Plugs.HealthPlug do
  @moduledoc """
  Exposes health check endpoints for liveness and readiness probes.
  """
  import Plug.Conn

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(%{path_info: path} = conn, _opts) when path in [["health"], ["healthz"]] do
    if Indrajaal.Observability.HealthCheck.liveness() do
      conn |> send_resp(200, "OK") |> halt()
    else
      conn |> send_resp(503, "Service Unavailable") |> halt()
    end
  end

  def call(%{path_info: ["health", "live"]} = conn, _opts) do
    if Indrajaal.Observability.HealthCheck.liveness() do
      conn |> send_resp(200, "OK") |> halt()
    else
      conn |> send_resp(503, "Service Unavailable") |> halt()
    end
  end

  def call(%{path_info: ["health", "ready"]} = conn, _opts) do
    if Indrajaal.Observability.HealthCheck.readiness() do
      conn |> send_resp(200, "OK") |> halt()
    else
      conn |> send_resp(503, "Service Unavailable") |> halt()
    end
  end

  def call(conn, _opts), do: conn
end
