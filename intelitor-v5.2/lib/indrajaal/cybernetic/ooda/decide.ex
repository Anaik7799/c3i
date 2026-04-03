defmodule Indrajaal.Cybernetic.OODA.Decide do
  @moduledoc """
  OODA Decide Phase - Free Energy Minimizing Decision for v20.0.0

  Implements the Decide phase of the OODA loop with:
  - Integration with Active Inference for action selection
  - Multi-criteria decision analysis
  - Risk-aware decision making
  - Decision explanation and audit

  ## Decision Model

  D* = argmin_a G(a, Θ) subject to C(a) ≤ threshold

  Where:
  - D* = Optimal decision
  - G(a, Θ) = Expected free energy given orientation Θ
  - C(a) = Risk/cost of action a

  ## Decision Types
  - **Reactive**: Immediate response to threats
  - **Proactive**: Anticipatory actions
  - **Adaptive**: Learning-based decisions
  - **Deferred**: Wait for more information

  ## STAMP Constraints
  - SC-ACT-001: Action selection MUST complete within 5ms
  - SC-ACT-002: All available actions MUST be evaluated
  - SC-ACT-004: No action MUST be allowed when uncertain
  - SC-OODA-002: Quality gates enforced 80% min
  """

  require Logger

  alias Indrajaal.Cybernetic.OODA.Orient
  alias Indrajaal.Cybernetic.Inference.ActionSelection
  alias Indrajaal.Cybernetic.Inference.Belief

  @type decision :: %{
          action: atom(),
          type: :reactive | :proactive | :adaptive | :deferred,
          confidence: float(),
          rationale: map(),
          alternatives: [map()],
          constraints: [atom()]
        }

  @type decide_state :: %{
          beliefs: Belief.t(),
          model: map(),
          decision_history: [decision()],
          quality_threshold: float()
        }

  # Quality gate threshold (SC-OODA-002)
  @quality_threshold 0.80

  # Uncertainty threshold for deferral (SC-ACT-004)
  @uncertainty_threshold 0.3

  @doc """
  Creates a new decision state.
  """
  @spec new(Keyword.t()) :: decide_state()
  def new(opts \\ []) do
    %{
      beliefs: Keyword.get(opts, :beliefs, Belief.new()),
      model: Keyword.get(opts, :model, default_model()),
      decision_history: [],
      quality_threshold: Keyword.get(opts, :quality_threshold, @quality_threshold)
    }
  end

  @doc """
  Makes a decision based on orientation.
  """
  @spec decide(Orient.orientation(), decide_state()) :: {decision(), decide_state()}
  def decide(orientation, state) do
    # Update beliefs based on orientation
    updated_beliefs = update_beliefs_from_orientation(state.beliefs, orientation)

    # Check if we have enough confidence to decide (SC-ACT-004)
    if orientation.confidence < @uncertainty_threshold do
      decision = defer_decision(orientation)
      {decision, state}
    else
      # Evaluate all actions using Active Inference (SC-ACT-002)
      evaluated = ActionSelection.evaluate_actions(updated_beliefs, state.model)

      # Select best action considering constraints
      {action, efe} = select_constrained_action(evaluated, orientation)

      # Determine decision type
      decision_type = classify_decision_type(action, orientation)

      # Build rationale
      rationale = build_rationale(action, efe, orientation, evaluated)

      # Get alternatives
      alternatives = build_alternatives(evaluated, action)

      decision = %{
        action: action,
        type: decision_type,
        confidence: orientation.confidence,
        rationale: rationale,
        alternatives: alternatives,
        constraints: active_constraints(orientation)
      }

      # Check quality gate (SC-OODA-002)
      final_decision =
        if meets_quality_gate?(decision, state.quality_threshold) do
          decision
        else
          Logger.warning("Decision failed quality gate, deferring")
          defer_decision(orientation)
        end

      # Update history
      new_history = [final_decision | Enum.take(state.decision_history, 99)]

      new_state = %{
        state
        | beliefs: updated_beliefs,
          decision_history: new_history
      }

      {final_decision, new_state}
    end
  end

  @doc """
  Creates a deferred decision (wait for more info).
  """
  @spec defer_decision(Orient.orientation()) :: decision()
  def defer_decision(orientation) do
    %{
      action: :observe,
      type: :deferred,
      confidence: orientation.confidence,
      rationale: %{
        reason: :insufficient_confidence,
        threshold: @uncertainty_threshold,
        actual: orientation.confidence
      },
      alternatives: [],
      constraints: [:uncertainty]
    }
  end

  @doc """
  Evaluates a potential action before commitment.
  """
  @spec evaluate(atom(), Orient.orientation(), decide_state()) :: map()
  def evaluate(action, orientation, state) do
    updated_beliefs = update_beliefs_from_orientation(state.beliefs, orientation)
    efe = ActionSelection.expected_free_energy(updated_beliefs, action, state.model)
    is_safe = ActionSelection.safe?(action, updated_beliefs, state.model)

    %{
      action: action,
      expected_free_energy: efe,
      safe: is_safe,
      compatible_with_situation: compatible?(action, orientation.situation)
    }
  end

  @doc """
  Returns the decision mode based on orientation.
  """
  @spec determine_mode(Orient.orientation()) :: ActionSelection.selection_mode()
  def determine_mode(orientation) do
    cond do
      orientation.confidence < 0.3 -> :epistemic
      length(orientation.threats) > 0 -> :pragmatic
      true -> :balanced
    end
  end

  @doc """
  Explains the decision rationale.
  """
  @spec explain(decision()) :: String.t()
  def explain(decision) do
    """
    Decision: #{decision.action} (#{decision.type})
    Confidence: #{Float.round(decision.confidence * 100, 1)}%
    Reason: #{inspect(decision.rationale.reason)}
    Alternatives considered: #{length(decision.alternatives)}
    Active constraints: #{Enum.join(decision.constraints, ", ")}
    """
  end

  @doc """
  Returns decision statistics.
  """
  @spec stats(decide_state()) :: map()
  def stats(state) do
    history = state.decision_history

    if Enum.empty?(history) do
      %{total: 0, by_type: %{}, by_action: %{}, avg_confidence: 0.0}
    else
      by_type = Enum.frequencies_by(history, & &1.type)
      by_action = Enum.frequencies_by(history, & &1.action)
      avg_confidence = Enum.sum(Enum.map(history, & &1.confidence)) / length(history)

      %{
        total: length(history),
        by_type: by_type,
        by_action: by_action,
        avg_confidence: avg_confidence
      }
    end
  end

  @doc """
  Returns decision summary.
  """
  @spec summary(decision()) :: map()
  def summary(decision) do
    %{
      action: decision.action,
      type: decision.type,
      confidence: decision.confidence,
      num_alternatives: length(decision.alternatives),
      num_constraints: length(decision.constraints)
    }
  end

  # Private helpers

  defp default_model do
    %{
      actions: [:observe, :maintain, :repair, :escalate, :noop],
      preferences: %{
        normal: 0.0,
        degraded: 1.0,
        critical: 5.0,
        failed: 10.0
      },
      transitions: default_transitions()
    }
  end

  defp default_transitions do
    %{
      observe: %{
        normal: %{normal: 0.95, degraded: 0.05, critical: 0.0, failed: 0.0},
        degraded: %{normal: 0.1, degraded: 0.8, critical: 0.1, failed: 0.0},
        critical: %{normal: 0.0, degraded: 0.2, critical: 0.7, failed: 0.1},
        failed: %{normal: 0.0, degraded: 0.0, critical: 0.1, failed: 0.9}
      },
      maintain: %{
        normal: %{normal: 0.98, degraded: 0.02, critical: 0.0, failed: 0.0},
        degraded: %{normal: 0.3, degraded: 0.65, critical: 0.05, failed: 0.0},
        critical: %{normal: 0.1, degraded: 0.4, critical: 0.45, failed: 0.05},
        failed: %{normal: 0.0, degraded: 0.1, critical: 0.3, failed: 0.6}
      },
      repair: %{
        normal: %{normal: 0.99, degraded: 0.01, critical: 0.0, failed: 0.0},
        degraded: %{normal: 0.6, degraded: 0.35, critical: 0.05, failed: 0.0},
        critical: %{normal: 0.3, degraded: 0.5, critical: 0.15, failed: 0.05},
        failed: %{normal: 0.1, degraded: 0.3, critical: 0.4, failed: 0.2}
      },
      escalate: %{
        normal: %{normal: 0.9, degraded: 0.1, critical: 0.0, failed: 0.0},
        degraded: %{normal: 0.4, degraded: 0.5, critical: 0.1, failed: 0.0},
        critical: %{normal: 0.2, degraded: 0.5, critical: 0.25, failed: 0.05},
        failed: %{normal: 0.05, degraded: 0.25, critical: 0.5, failed: 0.2}
      },
      noop: %{
        normal: %{normal: 0.9, degraded: 0.1, critical: 0.0, failed: 0.0},
        degraded: %{normal: 0.05, degraded: 0.7, critical: 0.2, failed: 0.05},
        critical: %{normal: 0.0, degraded: 0.1, critical: 0.6, failed: 0.3},
        failed: %{normal: 0.0, degraded: 0.0, critical: 0.05, failed: 0.95}
      }
    }
  end

  defp update_beliefs_from_orientation(beliefs, orientation) do
    # Map orientation situation to belief state
    situation_to_state = %{
      normal: :normal,
      degraded: :degraded,
      critical: :critical,
      uncertain: :degraded
    }

    obs_state = Map.get(situation_to_state, orientation.situation, :normal)
    observation = %{state: obs_state}
    surprise = 1.0 - orientation.confidence

    Belief.update(beliefs, observation, surprise)
  end

  defp select_constrained_action(evaluated, orientation) do
    # Filter out unsafe actions for critical situations
    constrained =
      if orientation.situation == :critical do
        Enum.filter(evaluated, fn {action, _} ->
          action in [:repair, :escalate, :observe]
        end)
      else
        evaluated
      end

    # Return best action from constrained set
    List.first(constrained, {:noop, 0.0})
  end

  defp classify_decision_type(action, orientation) do
    cond do
      action in [:repair, :escalate] and length(orientation.threats) > 0 ->
        :reactive

      action == :maintain and orientation.situation == :normal ->
        :proactive

      action == :observe ->
        :adaptive

      true ->
        :adaptive
    end
  end

  defp build_rationale(action, efe, orientation, evaluated) do
    %{
      reason: :free_energy_minimization,
      selected_action: action,
      expected_free_energy: efe,
      situation: orientation.situation,
      threats_considered: length(orientation.threats),
      actions_evaluated: length(evaluated)
    }
  end

  defp build_alternatives(evaluated, selected) do
    evaluated
    |> Enum.reject(fn {action, _} -> action == selected end)
    |> Enum.take(3)
    |> Enum.map(fn {action, efe} ->
      %{action: action, expected_free_energy: efe}
    end)
  end

  defp active_constraints(orientation) do
    constraints = []

    constraints =
      if orientation.confidence < 0.5 do
        [:low_confidence | constraints]
      else
        constraints
      end

    constraints =
      if length(orientation.threats) > 0 do
        [:active_threats | constraints]
      else
        constraints
      end

    constraints
  end

  defp meets_quality_gate?(decision, threshold) do
    decision.confidence >= threshold or decision.type == :deferred
  end

  defp compatible?(action, situation) do
    case {action, situation} do
      {:noop, :critical} -> false
      {:repair, :normal} -> false
      _ -> true
    end
  end
end
