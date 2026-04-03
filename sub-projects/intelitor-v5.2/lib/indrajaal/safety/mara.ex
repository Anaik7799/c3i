defmodule Indrajaal.Safety.Mara do
  @moduledoc """
  Mara: The Chaos & Resilience Engine (Red Team).

  WHAT: Proactively tests system resilience by injecting controlled faults.
  WHY: SC-TEST-002 requires continuous verification of self-healing capabilities.

  METAPHOR: In Buddhist cosmology, Mara is the tempter/tester. In the immune system,
  this represents "Training" or "Red Teaming" (e.g., thymic selection).

  CONSTRAINTS:
  - SC-IMMUNE-004: Chaos Injection Safety. MUST NOT run if system health < 0.8.
  - SC-GUARD-001: MUST obtain Guardian permission before any destructive action.

  ## Architecture

  ```
  [Mara] --(Request Permission)--> [Guardian]
     |
     +--(Inject Fault)--> [Target Process]
     |
     +--(Monitor)--> [Recovery Metrics]
  ```
  """

  use GenServer
  require Logger

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Safety.Sentinel

  # ============================================================ 
  # CLIENT API
  # ============================================================ 

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Trigger a specific chaos scenario.
  """
  @spec trigger_chaos(atom()) :: :ok | {:error, term()}
  def trigger_chaos(scenario_type) do
    GenServer.call(__MODULE__, {:trigger, scenario_type})
  end

  # ============================================================ 
  # SERVER CALLBACKS
  # ============================================================ 

  @impl true
  def init(_opts) do
    Logger.info("[Mara] Chaos Engine initializing... (Waiting for command)")
    {:ok, %{active_scenarios: [], history: []}}
  end

  @impl true
  def handle_call({:trigger, scenario}, _from, state) do
    # 1. Safety Check (Sentinel)
    health = Sentinel.get_health()

    if health.score < 0.8 do
      Logger.warning("[Mara] Chaos aborted. System health too low: #{health.score}")
      {:reply, {:error, :system_unstable}, state}
    else
      # 2. Permission Check (Guardian)
      proposal = %{
        action: :inject_chaos,
        type: scenario,
        # Simplified for now
        target: :random_worker,
        risk_level: :medium
      }

      case Guardian.validate_proposal(proposal) do
        {:ok, _validated} ->
          # 3. Execute
          execute_scenario(scenario)
          {:reply, :ok, state}

        {:veto, reason, _fallback} ->
          Logger.warning("[Mara] Guardian vetoed chaos: #{inspect(reason)}")
          {:reply, {:error, :guardian_veto}, state}

        {:error, reason} ->
          Logger.error("[Mara] Guardian error: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  # ============================================================ 
  # SCENARIOS
  # ============================================================ 

  defp execute_scenario(:process_kill) do
    Logger.info("[Mara] Executing :process_kill scenario")
    # In a real system, we'd find a specific worker via Registry
    # For simulation, we log the intent
    :telemetry.execute(
      [:indrajaal, :safety, :mara, :chaos_injected],
      %{timestamp: System.system_time(:millisecond)},
      %{type: :process_kill, target: "simulated_worker"}
    )
  end

  defp execute_scenario(:latency_injection) do
    Logger.info("[Mara] Executing :latency_injection scenario")
    # Simulate network lag
  end

  defp execute_scenario(_) do
    Logger.error("[Mara] Unknown scenario")
  end
end
