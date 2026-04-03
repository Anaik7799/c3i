defmodule Indrajaal.Strategy.OODALoop do
  @moduledoc """
  The Tactical Engine. Implements the OODA Loop (Observe-Orient-Decide-Act)
  as a persistent process.

  Concept: Military "Mission Command".
  """
  use GenServer
  require Logger

  # 1 second tactical loop
  @interval 1000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    Logger.info("🪖 OODA Loop: ONLINE. Scanning Sector.")
    schedule_loop()
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    # 1. OBSERVE (Sensors)
    # 2. ORIENT (Context)
    # 3. DECIDE (Intent)
    # 4. ACT (Fire)

    _cycle =
      state
      |> observe()
      |> orient()
      |> decide()
      |> act()

    schedule_loop()
    {:noreply, state}
  end

  # Placeholder for sensor gathering
  defp observe(state), do: state
  # Placeholder for context analysis
  defp orient(state), do: state
  # Placeholder for decision logic
  defp decide(_state), do: :hold

  defp act(:hold) do
    # Logger.debug("🪖 OODA: Holding Position.")
    :ok
  end

  defp schedule_loop do
    Process.send_after(self(), :tick, @interval)
  end
end
