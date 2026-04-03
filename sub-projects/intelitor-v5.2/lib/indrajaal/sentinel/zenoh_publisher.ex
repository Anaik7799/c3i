defmodule Indrajaal.Sentinel.ZenohPublisher do
  @moduledoc """
  Periodically publishes Sentinel health assessments to Zenoh.

  ## WHAT
  GenServer that fires every 30 seconds, calls `Sentinel.assess_now/0`,
  encodes the result as JSON and publishes it to `indrajaal/health/sentinel`
  via `ZenohSession.publish/2`.  Falls back to the Zenoh REST API
  (`http://{ZENOH_ROUTER_HOST}:8000`) if the NIF session is unavailable.

  ## WHY
  Real-time Sentinel health visibility across the mesh (SC-IMMUNE-001,
  SC-ZENOH-007).  The 10-second initial warmup delay avoids publishing
  before the system finishes booting.

  ## CONSTRAINTS
  - SC-IMMUNE-001: Sentinel health published continuously
  - SC-ZENOH-007: Zenoh health included in /health endpoint
  - SC-SIL4-001: 30-second heartbeat cadence
  """

  use GenServer
  require Logger

  # 30 seconds
  @interval 30_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    # SC-IMMUNE-001: 10s initial warmup delay then continuous assessment
    Process.send_after(self(), :publish, 10_000)
    {:ok, state}
  end

  def handle_info(:publish, state) do
    # Perform autonomous assessment including OpenRouter cognitive check
    assessment = Indrajaal.Sentinel.assess_now()
    json = Jason.encode!(assessment)

    # Publish to Zenoh Data Plane
    case Indrajaal.Observability.ZenohSession.publish("indrajaal/health/sentinel", json) do
      :ok ->
        :ok

      _ ->
        # Fallback to REST API for host-to-container parity
        zenoh_host = System.get_env("ZENOH_ROUTER_HOST", "localhost")
        url = ~c"http://#{zenoh_host}:8000/indrajaal/health/sentinel"
        :httpc.request(:put, {url, [], ~c"application/json", json}, [{:timeout, 5000}], [])
    end

    # Repeat every 30 seconds (SC-SIL4-001)
    Process.send_after(self(), :publish, @interval)
    {:noreply, state}
  end
end
