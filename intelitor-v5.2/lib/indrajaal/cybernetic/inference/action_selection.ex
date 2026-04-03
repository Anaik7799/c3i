defmodule Indrajaal.Cybernetic.Inference.ActionSelection do
  @moduledoc """
  Action Selection - Expected Free Energy Minimization for v20.0.0

  Implements action selection for active inference:
  - Evaluates actions by expected free energy
  - Balances exploration (epistemic) vs exploitation (pragmatic)
  - Supports action sequences (policies)

  ## Expected Free Energy

  G(π) = E_q[log q(s|π) - log p(o,s|π)]
       = -E_q[log p(o|π)] + E_q[D_KL[q(s|o,π) || q(s|π)]]
       = Risk + Ambiguity

  Where:
  - G(π) = Expected free energy of policy π
  - Risk = Expected cost (pragmatic value)
  - Ambiguity = Expected information gain (epistemic value)

  ## Action Types
  - **Pragmatic**: Minimize expected surprise (exploit)
  - **Epistemic**: Maximize information gain (explore)
  - **Balanced**: Trade-off between both

  ## STAMP Constraints
  - SC-ACT-001: Action selection MUST complete within 5ms
  - SC-ACT-002: All available actions MUST be evaluated
  - SC-ACT-003: Selection MUST consider epistemic value
  - SC-ACT-004: No action MUST be allowed when uncertain
  """

  require Logger

  alias Indrajaal.Cybernetic.Inference.Belief
  alias Indrajaal.Cybernetic.Inference.Prediction

  @type action :: atom()
  @type policy :: [action()]
  @type selection_mode :: :pragmatic | :epistemic | :balanced

  # Default available actions
  @default_actions [:observe, :maintain, :repair, :escalate, :noop]

  # Exploration parameter (higher = more exploration)
  @exploration_factor 0.3

  @doc """
  Selects the best action based on expected free energy.
  """
  @spec select(Belief.t(), map()) :: action()
  def select(beliefs, model) do
    mode = determine_mode(beliefs)
    actions = available_actions(model)

    {best_action, _} =
      actions
      |> Enum.map(fn action ->
        efe = expected_free_energy(beliefs, action, model, mode)
        {action, efe}
      end)
      |> Enum.min_by(fn {_, efe} -> efe end, fn -> {:noop, 0.0} end)

    Logger.debug("Selected action: #{best_action} (mode: #{mode})")
    best_action
  end

  @doc """
  Evaluates all actions and returns ranked list.
  """
  @spec evaluate_actions(Belief.t(), map()) :: [{action(), float()}]
  def evaluate_actions(beliefs, model) do
    mode = determine_mode(beliefs)
    actions = available_actions(model)

    actions
    |> Enum.map(fn action ->
      efe = expected_free_energy(beliefs, action, model, mode)
      {action, efe}
    end)
    |> Enum.sort_by(fn {_, efe} -> efe end)
  end

  @doc """
  Selects the best policy (action sequence).
  """
  @spec select_policy(Belief.t(), map(), non_neg_integer()) :: policy()
  def select_policy(beliefs, model, horizon \\ 3) do
    actions = available_actions(model)

    # Generate candidate policies
    policies = generate_policies(actions, horizon)

    # Evaluate each policy
    {best_policy, _} =
      policies
      |> Enum.map(fn policy ->
        efe = evaluate_policy(beliefs, policy, model)
        {policy, efe}
      end)
      |> Enum.min_by(fn {_, efe} -> efe end, fn -> {[:noop], 0.0} end)

    best_policy
  end

  @doc """
  Calculates expected free energy for an action.
  """
  @spec expected_free_energy(Belief.t(), action(), map(), selection_mode()) :: float()
  def expected_free_energy(beliefs, action, model, mode \\ :balanced) do
    # Predict future state distribution
    predicted = Prediction.predict(beliefs, action, model)

    # Calculate pragmatic value (risk)
    pragmatic = pragmatic_value(predicted, model)

    # Calculate epistemic value (ambiguity)
    epistemic = epistemic_value(beliefs, predicted)

    # Combine based on mode
    case mode do
      :pragmatic -> pragmatic
      :epistemic -> -epistemic
      :balanced -> pragmatic - @exploration_factor * epistemic
    end
  end

  @doc """
  Determines the selection mode based on belief confidence.
  """
  @spec determine_mode(Belief.t()) :: selection_mode()
  def determine_mode(beliefs) do
    cond do
      # Low confidence → explore
      beliefs.confidence < 0.3 -> :epistemic
      # High confidence → exploit
      beliefs.confidence > 0.8 -> :pragmatic
      true -> :balanced
    end
  end

  @doc """
  Calculates the pragmatic value (expected cost/reward).
  """
  @spec pragmatic_value(map(), map()) :: float()
  def pragmatic_value(predicted, model) do
    preferences = Map.get(model, :preferences, default_preferences())

    # Expected cost = Σ P(s) × cost(s)
    Enum.reduce(predicted, 0.0, fn {state, prob}, acc ->
      cost = Map.get(preferences, state, 0.0)
      acc + prob * cost
    end)
  end

  @doc """
  Calculates the epistemic value (expected information gain).
  """
  @spec epistemic_value(Belief.t(), map()) :: float()
  def epistemic_value(beliefs, predicted) do
    # Information gain from observing predicted state
    current_entropy = Belief.entropy(beliefs)
    predicted_entropy = Prediction.entropy(predicted)

    max(0.0, current_entropy - predicted_entropy)
  end

  @doc """
  Evaluates a policy (action sequence).
  """
  @spec evaluate_policy(Belief.t(), policy(), map()) :: float()
  def evaluate_policy(beliefs, policy, model) do
    # Simulate policy execution
    {total_efe, _} =
      Enum.reduce(policy, {0.0, beliefs}, fn action, {efe_acc, current_beliefs} ->
        # Calculate EFE for this step
        efe = expected_free_energy(current_beliefs, action, model)

        # Predict next beliefs
        predicted = Prediction.predict(current_beliefs, action, model)
        next_beliefs = %{current_beliefs | states: predicted}

        {efe_acc + efe, next_beliefs}
      end)

    total_efe
  end

  @doc """
  Returns the available actions from the model.
  """
  @spec available_actions(map()) :: [action()]
  def available_actions(model) do
    Map.get(model, :actions, @default_actions)
  end

  @doc """
  Checks if an action is safe to execute.
  """
  @spec safe?(action(), Belief.t(), map()) :: boolean()
  def safe?(action, beliefs, model) do
    predicted = Prediction.predict(beliefs, action, model)
    failed_prob = Map.get(predicted, :failed, 0.0)

    # Action is safe if probability of failure is low
    failed_prob < 0.1
  end

  @doc """
  Returns action selection summary.
  """
  @spec summary(Belief.t(), map()) :: map()
  def summary(beliefs, model) do
    evaluated = evaluate_actions(beliefs, model)
    {best, best_efe} = List.first(evaluated, {:noop, 0.0})
    mode = determine_mode(beliefs)

    %{
      best_action: best,
      best_efe: best_efe,
      mode: mode,
      confidence: beliefs.confidence,
      actions_evaluated: length(evaluated)
    }
  end

  # Private helpers

  defp default_preferences do
    %{
      # No cost for normal state
      normal: 0.0,
      # Low cost
      degraded: 1.0,
      # Medium cost
      critical: 5.0,
      # High cost
      failed: 10.0
    }
  end

  defp generate_policies(actions, horizon) do
    if horizon <= 1 do
      Enum.map(actions, &[&1])
    else
      # Generate all combinations up to horizon
      # Limit to avoid combinatorial explosion
      actions
      |> Enum.flat_map(fn first_action ->
        sub_policies = Enum.take(generate_policies(actions, horizon - 1), 10)
        Enum.map(sub_policies, fn rest -> [first_action | rest] end)
      end)
      |> Enum.take(100)
    end
  end
end
