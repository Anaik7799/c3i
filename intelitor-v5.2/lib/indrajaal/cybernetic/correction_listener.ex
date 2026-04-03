defmodule Indrajaal.Cybernetic.CorrectionListener do
  @moduledoc """
  L2/L6 Bridge: Listens for Cortex corrections via Zenoh and broadcasts to PubSub.
  Part of the "Cognitive Reflex".

  ## Architecture
  Zenoh -> [CorrectionListener] -> Phoenix.PubSub -> TopologyLive

  ## STAMP
  - SC-REFLEX-001: Corrections must be validated by Guardian before broadcast.
  """
  use GenServer
  require Logger
  alias Indrajaal.Observability.ZenohControlSubscriber
  alias Indrajaal.Safety.Guardian

  @correction_topic "indrajaal/cortex/correction"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("🧠 CorrectionListener: Bridging Cortex to Consciousness...")

    # Register self as handler for correction topics
    # In a real Zenoh setup, we'd subscribe. Here we hook into the existing subscriber logic.
    # We will assume ZenohControlSubscriber can route to us or we poll/listen.
    # For this implementation, we will register a handler with ZenohControlSubscriber.

    ZenohControlSubscriber.register_handler(
      @correction_topic,
      fn key, payload -> handle_correction(key, payload) end
    )

    {:ok, %{}}
  end

  def handle_correction(_key, payload) do
    Logger.info("⚡ Correction Signal Received: #{inspect(payload)}")

    # L2 Safety Check (The Reflex Arc)
    case Guardian.validate_proposal(%{action: :apply_correction, payload: payload}) do
      {:ok, _} ->
        broadcast_correction(payload)
        :ok

      {:veto, reason, _} ->
        Logger.warning("🛡️ Correction VETOED by Guardian: #{inspect(reason)}")
        :vetoed
    end
  end

  defp broadcast_correction(payload) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "topology:updates",
      {:correction_applied, payload}
    )
  end
end
