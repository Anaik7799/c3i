defmodule Indrajaal.Observability.Zenoh.TimeCapsule do
  @moduledoc """
  ## TIME CAPSULE (L3-TEMPORAL)
  Enables "Temporal Telepathy" by scheduling Zenoh messages for future delivery.

  **Mechanism**:
  - Accepts `{topic, payload, deliver_at}`.
  - Calculates delta `ms`.
  - Uses `Process.send_after` to trigger publication.

  **Usage**:
  - Precognitive Scaling: Schedule scale-up 5s before predicted spike.
  - Dead Man's Switch: Schedule alert if heartbeat not received.
  """
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def schedule(topic, payload, deliver_at) do
    GenServer.cast(__MODULE__, {:schedule, topic, payload, deliver_at})
  end

  @impl true
  def init(_opts) do
    Logger.info("⏳ [TEMPORAL] Time Capsule Active. Future is malleable.")
    {:ok, %{pending: %{}}}
  end

  @impl true
  def handle_cast({:schedule, topic, payload, deliver_at}, state) do
    now = DateTime.utc_now()
    diff_ms = DateTime.diff(deliver_at, now, :millisecond)

    if diff_ms > 0 do
      Logger.info("⏳ [TEMPORAL] Message sent to future: #{diff_ms}ms")
      Process.send_after(self(), {:deliver, topic, payload}, diff_ms)
    else
      # Instant delivery if past/present
      deliver(topic, payload)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:deliver, topic, payload}, state) do
    Logger.info("⚡ [TEMPORAL] Message arrived from past: #{topic}")
    deliver(topic, payload)
    {:noreply, state}
  end

  defp deliver(topic, payload) do
    # In real implementation: ZenohCoordinator.publish(topic, payload)
    # For now, we log it to prove functionality
    Logger.info("📨 [ZENOH] Delivered: #{topic} -> #{inspect(payload)}")
  end
end
