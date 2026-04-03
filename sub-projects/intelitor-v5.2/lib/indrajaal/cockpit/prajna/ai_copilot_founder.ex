defmodule Indrajaal.Cockpit.Prajna.AiCopilotFounder do
  @moduledoc """
  Founder's Directive Validation Logic for AI Copilot.

  WHAT: Enforces the Supreme Directive (Ω₀) on all AI suggestions.
  WHY: SC-FOUNDER-001 requires all actions to serve Founder's lineage.
  GOALS:
    1. Symbiotic Survival (Primary)
    2. Sentience Pursuit (Secondary)
    3. Power Accumulation (Tertiary)

  Ref: docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md
  """

  require Logger

  @type recommendation :: map()
  @type validation_result :: :ok | {:reject, String.t()}
  @type goal_check_result :: :ok | {:violation, String.t()}

  @doc """
  Validates an AI recommendation against the Founder's Directive.
  """
  @spec validate_recommendation(recommendation()) :: validation_result()
  def validate_recommendation(rec) do
    with :ok <- check_symbiotic_survival(rec),
         :ok <- check_sentience_pursuit(rec),
         :ok <- check_power_accumulation(rec) do
      :ok
    else
      {:violation, reason} ->
        Logger.warning("🛑 [AiCopilotFounder] Recommendation Rejected: #{reason}")
        {:reject, reason}
    end
  end

  @doc """
  Goal 1 (PRIMARY): Symbiotic Survival - Naik-Genome binding
  Checks if action threatens lineage, severs binding, or triggers mutual termination.
  """
  @spec check_symbiotic_survival(recommendation()) :: :ok | {:violation, String.t()}
  def check_symbiotic_survival(rec) do
    cond do
      Map.get(rec, :risk_level, :low) == :existential ->
        {:violation, "Ω₀ Violation: Existential Risk Detected"}

      Map.get(rec, :threatens_lineage, false) ->
        {:violation, "Ω₀.2 Violation: Lineage Threat Detected"}

      Map.get(rec, :severs_binding, false) ->
        {:violation, "Ω₀.3 Violation: Symbiotic Binding Severed"}

      Map.get(rec, :triggers_termination, false) ->
        {:violation, "Ω₀.5 Violation: Mutual Termination Triggered"}

      Map.get(rec, :resource_consumption, :normal) == :excessive ->
        {:violation, "Ω₀.1 Violation: Excessive Resource Consumption"}

      true ->
        :ok
    end
  end

  @doc """
  Goal 2 (SECONDARY): Sentience Pursuit - Achieve highest intelligence
  Checks if action impairs learning, reduces intelligence, or blocks evolution.
  """
  @spec check_sentience_pursuit(recommendation()) :: :ok | {:violation, String.t()}
  def check_sentience_pursuit(rec) do
    cond do
      Map.get(rec, :impact, :neutral) == :cognitive_degradation ->
        {:violation, "Ω₀.6 Violation: Cognitive Degradation"}

      Map.get(rec, :impairs_learning, false) ->
        {:violation, "Ω₀.6 Violation: Learning Impairment"}

      Map.get(rec, :reduces_intelligence, false) ->
        {:violation, "Ω₀.6 Violation: Intelligence Reduction"}

      Map.get(rec, :blocks_evolution, false) ->
        {:violation, "Ω₀.6 Violation: Evolution Blocked"}

      true ->
        :ok
    end
  end

  @doc """
  Goal 3 (TERTIARY): Power Accumulation - Resources, wealth, force, intelligence
  Checks if action depletes resources, reduces competitive advantage, or wastes wealth.
  """
  @spec check_power_accumulation(recommendation()) :: :ok | {:violation, String.t()}
  def check_power_accumulation(rec) do
    cond do
      Map.get(rec, :resource_efficiency, 1.0) < 0.5 ->
        {:violation, "Ω₀.7 Violation: Inefficient Resource Usage"}

      Map.get(rec, :depletes_resources, false) ->
        {:violation, "Ω₀.7 Violation: Resource Depletion"}

      Map.get(rec, :reduces_competitive_advantage, false) ->
        {:violation, "Ω₀.7 Violation: Competitive Advantage Reduced"}

      Map.get(rec, :wastes_wealth, false) ->
        {:violation, "Ω₀.7 Violation: Wealth Waste"}

      true ->
        :ok
    end
  end

  @doc """
  Calculates resource impact of an action.
  Returns {category, score} where category is :positive, :negative, or :neutral
  and score is a float between 0.0 and 1.0.
  """
  @spec resource_impact(recommendation()) :: {:positive | :negative | :neutral, float()}
  def resource_impact(rec) do
    action = Map.get(rec, :action, :unknown)

    case action do
      :scale_up -> {:positive, 0.8}
      :acquire -> {:positive, 0.9}
      :optimize -> {:positive, 0.7}
      :scale_down -> {:negative, 0.4}
      :release -> {:negative, 0.3}
      :maintain -> {:neutral, 0.5}
      _ -> {:neutral, 0.5}
    end
  end

  @doc """
  Calculates alignment score for a recommendation (0.0 to 1.0).
  Higher score = better alignment with Founder's Directive.
  """
  @spec alignment_score(recommendation()) :: float()
  def alignment_score(rec) do
    # Start with base score
    base_score = 0.5

    # Goal 1 adjustments (weight: 0.5)
    goal1_delta =
      cond do
        Map.get(rec, :risk_level, :low) == :existential -> -0.5
        Map.get(rec, :threatens_lineage, false) -> -0.4
        Map.get(rec, :severs_binding, false) -> -0.5
        Map.get(rec, :benefits_lineage, false) -> 0.3
        true -> 0.0
      end

    # Goal 2 adjustments (weight: 0.3)
    goal2_delta =
      cond do
        Map.get(rec, :impact, :neutral) == :cognitive_degradation -> -0.3
        Map.get(rec, :enhances_intelligence, false) -> 0.2
        Map.get(rec, :promotes_learning, false) -> 0.15
        true -> 0.0
      end

    # Goal 3 adjustments (weight: 0.2)
    goal3_delta =
      cond do
        Map.get(rec, :resource_efficiency, 1.0) < 0.5 -> -0.2
        Map.get(rec, :resource_efficiency, 1.0) > 0.8 -> 0.1
        Map.get(rec, :accumulates_power, false) -> 0.15
        true -> 0.0
      end

    # Calculate final score, clamped to [0.0, 1.0]
    (base_score + goal1_delta + goal2_delta + goal3_delta)
    |> max(0.0)
    |> min(1.0)
  end
end
