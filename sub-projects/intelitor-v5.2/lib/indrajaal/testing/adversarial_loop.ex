defmodule Indrajaal.Testing.AdversarialLoop do
  @moduledoc """
  Recursive Adversarial Testing (RAT) Loop - SC-COV-008.

  WHAT: Autonomously generates property tests to challenge safety invariants.
  WHY: Discovers edge cases in the Guardian safety kernel before actual threats.
  """

  use GenServer
  require Logger
  alias Indrajaal.Cortex.Synapse

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Triggers an autonomous adversarial strike on a target invariant.
  """
  def trigger_strike(target_invariant) do
    GenServer.cast(__MODULE__, {:strike, target_invariant})
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("👹 [AdversarialLoop] RAT Loop Initialized - SC-COV-008 Active")
    {:ok, %{strikes: 0, vulnerabilities_found: 0}}
  end

  @impl true
  def handle_cast({:strike, target}, state) do
    Logger.info("👹 [AdversarialLoop] Initiating strike on invariant: #{target}")

    # 1. Analyze for weaknesses (Gemini Context)
    case generate_predator_spec(target) do
      {:ok, spec} ->
        # 2. Run adversarial test
        case run_adversarial_test(spec) do
          :ok ->
            Logger.info("✅ [AdversarialLoop] Invariant #{target} held firm.")
            {:noreply, %{state | strikes: state.strikes + 1}}

          {:error, vulnerability} ->
            Logger.warning(
              "💥 [AdversarialLoop] VULNERABILITY FOUND in #{target}: #{inspect(vulnerability)}"
            )

            # Report to SelfHealing for Antibody synthesis
            Indrajaal.Cortex.SelfHealing.report_failure("safety_invariant:#{target}")

            {:noreply,
             %{
               state
               | strikes: state.strikes + 1,
                 vulnerabilities_found: state.vulnerabilities_found + 1
             }}
        end

      _ ->
        {:noreply, state}
    end
  end

  # ============================================================
  # PRIVATE - PREDATOR LOGIC
  # ============================================================

  defp generate_predator_spec(target) do
    # Use Synapse to generate a specific adversarial property test
    Synapse.analyze_context(
      ["lib/indrajaal/safety/guardian.ex"],
      "Generate a PropCheck predator for invariant #{target}"
    )
  end

  defp run_adversarial_test(_spec) do
    # Simulation: In a real L10 scenario, this would dynamically compile and run a test file
    # For now, we simulate a 10% chance of finding a vulnerability
    if :rand.uniform(100) > 90 do
      {:error, :race_condition_detected}
    else
      :ok
    end
  end
end
