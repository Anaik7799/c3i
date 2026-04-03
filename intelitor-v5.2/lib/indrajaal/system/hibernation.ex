defmodule Indrajaal.System.Hibernation do
  @moduledoc """
  ## METABOLIC HIBERNATION (L4-OPERATIONAL)
  Conserves energy by scaling down non-essential organs during abundance.

  **Mechanism**:
  - Monitors `EnergyGovernor`.
  - If `:abundance` persists for 10m -> Enter Deep Sleep.
  - Scales secondary containers to 0.
  """
  use GenServer
  require Logger

  @drowsy_timeout 600_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("🐻 [HIBERNATION] Winter is coming. Monitoring energy levels.")
    {:ok, %{state: :active, timer: nil}}
  end

  @impl true
  def handle_info({:energy_update, :abundance}, %{state: :active} = state) do
    timer = Process.send_after(self(), :enter_hibernation, @drowsy_timeout)
    Logger.info("🐻 [HIBERNATION] Abundance detected. Feeling drowsy...")
    {:noreply, %{state | state: :drowsy, timer: timer}}
  end

  @impl true
  def handle_info({:energy_update, _}, %{state: :drowsy, timer: timer} = state) do
    Process.cancel_timer(timer)
    Logger.info("🐻 [HIBERNATION] Activity detected. Waking up!")
    {:noreply, %{state | state: :active, timer: nil}}
  end

  @impl true
  def handle_info(:enter_hibernation, state) do
    Logger.warning("🐻 [HIBERNATION] Entering Deep Sleep. Scaling down...")
    # In real impl: Indrajaal.Integration.CepafClient.scale_down("secondary")
    {:noreply, %{state | state: :hibernating, timer: nil}}
  end

  # Catch-all for other states
  def handle_info(_, state), do: {:noreply, state}
end
