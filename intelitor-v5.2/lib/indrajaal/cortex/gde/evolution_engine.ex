defmodule Indrajaal.Cortex.GDE.EvolutionEngine do
  @moduledoc """
  Autonomic Evolution Engine (GDE v2.0) - Recursive Self-Improvement logic.

  WHAT: Monitors system entropy, drift, and performance to autonomously define goals.
  WHY: SC-SING-001 mandates recursive self-improvement for Singularity (L10).
  """

  use GenServer
  require Logger

  alias Indrajaal.Cortex.GDE.Controller, as: GDE
  alias Indrajaal.Safety.Sentinel

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type engine_state :: %{
          entropy_threshold: float(),
          scan_interval: integer(),
          active_evolution: boolean(),
          last_scan_at: DateTime.t(),
          metrics: map()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @default_entropy_threshold 0.2
  @default_scan_interval 100

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Triggers an immediate autonomic entropy scan.
  """
  def scan_now do
    GenServer.cast(__MODULE__, :scan_entropy)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    Logger.info("[GDE.EvolutionEngine] Initializing GDE v2.0 Autonomic Loop")

    state = %{
      entropy_threshold: Keyword.get(opts, :entropy_threshold, @default_entropy_threshold),
      scan_interval: Keyword.get(opts, :scan_interval, @default_scan_interval),
      active_evolution: true,
      last_scan_at: DateTime.utc_now(),
      metrics: %{scans: 0, goals_generated: 0}
    }

    schedule_scan(state.scan_interval)

    {:ok, state}
  end

  @impl true
  def handle_cast(:scan_entropy, state) do
    new_state = perform_autonomic_scan(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:scan_tick, state) do
    new_state = perform_autonomic_scan(state)
    schedule_scan(state.scan_interval)
    {:noreply, new_state}
  end

  # ============================================================
  # EVOLUTION LOGIC
  # ============================================================

  defp perform_autonomic_scan(state) do
    Logger.info("[GDE.EvolutionEngine] Initiating Omega-Cycle (System-wide entropy scan)")

    # 1. Gather Telemetry (Observe)
    # 1a. Coarse-grained Sentinel Health
    health = Sentinel.get_health()

    # 1b. Fine-grained Holon Entropy from IKE (Knowledge Engine)
    rotting_holons =
      case Indrajaal.KMS.Service.get_rotting_holons(5) do
        {:ok, holons} -> holons
        _ -> []
      end

    # 2. Identify Evolution Opportunities (Orient)
    sentinel_opportunities = identify_evolution_opportunities(health, state.entropy_threshold)

    # 3. Merge and prioritize (Decide)
    # Prioritize IKE-detected rotting holons as they represent structural decay
    ike_opportunities =
      Enum.map(rotting_holons, fn holon ->
        %{
          target: holon.holon_id,
          entropy: holon.entropy,
          # Rotting holons get a penalty score to trigger urgency
          score: 0.5,
          reason: "Structural decay (Drift: #{holon.drift})"
        }
      end)

    all_opportunities = ike_opportunities ++ sentinel_opportunities

    # 4. Generate Goals (Act)
    new_goals_count =
      Enum.count(all_opportunities, fn opportunity ->
        case generate_autonomic_goal(opportunity) do
          {:ok, goal_id} ->
            GDE.activate_goal(goal_id)

            # SC-SING-003: If it's a high-priority rotting holon, trigger immediate refactor reflex
            if opportunity.score <= 0.5 do
              Task.start(fn ->
                Indrajaal.Cortex.GDE.OmegaRefactor.refactor_holon(opportunity.target)
              end)
            end

            true

          _ ->
            false
        end
      end)

    # SC-SING-004: If we evolved, reify a new Ark Seed
    if new_goals_count > 0 do
      Task.start(fn -> Indrajaal.Ark.Seeder.seed_now() end)
    end

    # 5. Update State
    %{
      state
      | last_scan_at: DateTime.utc_now(),
        metrics: %{
          scans: state.metrics.scans + 1,
          goals_generated: state.metrics.goals_generated + new_goals_count
        }
    }
  end

  defp identify_evolution_opportunities(health, _threshold)
       when not is_map(health) or is_struct(health) do
    # Sentinel may return a scalar (e.g. 1.0) or struct when no component-level data is available
    []
  end

  defp identify_evolution_opportunities(health, threshold) do
    # Logic to find components where drift or performance warrants evolution
    # This filters components from Sentinel health reports
    # Guard: only process map-valued entries (skip DateTime/atom/other non-map metrics)
    health
    |> Enum.filter(fn {_component, metrics} ->
      is_map(metrics) and not is_struct(metrics) and
        ((metrics[:entropy] || 0.0) > threshold or (metrics[:score] || 1.0) < 0.8)
    end)
    |> Enum.map(fn {component, metrics} ->
      %{
        target: component,
        entropy: metrics[:entropy] || 0.0,
        score: metrics[:score] || 1.0,
        reason: metrics[:reason] || "High entropy detected"
      }
    end)
  end

  defp generate_autonomic_goal(opportunity) do
    type = determine_goal_type(opportunity)

    description =
      "Autonomic Evolution: Reduce entropy in #{opportunity.target} (Current: #{opportunity.entropy})"

    Logger.info("[GDE.EvolutionEngine] Generating autonomic goal for #{opportunity.target}")

    GDE.define_goal(type, description,
      priority: :high,
      metadata: %{autonomic: true, source: :evolution_engine, opportunity: opportunity}
    )
  end

  defp determine_goal_type(%{target: :compilation}), do: :compilation_success
  defp determine_goal_type(%{target: :tests}), do: :test_pass
  defp determine_goal_type(%{target: :performance}), do: :performance_target
  defp determine_goal_type(_), do: :custom

  defp schedule_scan(interval) do
    Process.send_after(self(), :scan_tick, interval)
  end
end
