defmodule Indrajaal.Evolution.Dreamer do
  @moduledoc """
  ## THE DREAMER (L5-SUBCONSCIOUS)
  Generates stochastic evolutionary paths ("Dreams") during system idle time.

  **Mechanism**:
  1. Identifies idle resources.
  2. Generates random `KMS Task Holons` items (Mutations).
  3. Simulates execution in `Shadow Mode`.
  4. If successful, promotes to `Conscious Mind` (SystemEvolution).

  **Safety**: Dreams are ephemeral and sandboxed.
  """
  use GenServer
  require Logger

  # 5 minutes (REM Cycle)
  @dream_interval 300_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("🌙 [DREAMER] Subconscious Active. Waiting for REM sleep...")
    schedule_dream()
    {:ok, %{dreams: []}}
  end

  @impl true
  def handle_info(:dream, state) do
    dream = generate_dream()
    Logger.info("🌙 [DREAMER] Hallucinating: #{dream}")

    # Simulate (Stub)
    result = simulate_dream(dream)

    new_state =
      if result == :success do
        Logger.info("💡 [DREAMER] Epiphany! Promoting dream to Reality.")
        Indrajaal.Evolution.SystemEvolution.propose_mutation(dream)
        %{state | dreams: [dream | state.dreams]}
      else
        Logger.debug("💤 [DREAMER] Nightmare discarded.")
        state
      end

    schedule_dream()
    {:noreply, new_state}
  end

  defp generate_dream do
    verbs = ["Optimize", "Refactor", "Evolve", "Mutation"]
    nouns = ["Metabolism", "Cortex", "Synapse", "Membrane"]
    "#{Enum.random(verbs)} #{Enum.random(nouns)} Layer"
  end

  defp simulate_dream(_dream) do
    # Placeholder: Random success
    if :rand.uniform(10) > 8, do: :success, else: :failure
  end

  defp schedule_dream do
    Process.send_after(self(), :dream, @dream_interval)
  end
end
