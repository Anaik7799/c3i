defmodule Indrajaal.Cybernetic.Inference.Prediction do
  @moduledoc """
  Predictive Processing - Future State Prediction for v20.0.0

  Implements predictive processing for active inference:
  - Generates predictions from beliefs and models
  - Evaluates prediction accuracy
  - Updates models based on prediction errors

  ## Mathematical Foundation

  Prediction: p(o_t+1 | s_t, a_t, m)

  Where:
  - o_t+1 = Future observation
  - s_t = Current state belief
  - a_t = Action taken
  - m = Generative model

  ## Prediction Types
  - **State prediction**: Expected future states
  - **Observation prediction**: Expected future observations
  - **Outcome prediction**: Expected action outcomes

  ## STAMP Constraints
  - SC-PRED-001: Predictions MUST include uncertainty estimates
  - SC-PRED-002: Prediction horizon MUST be bounded
  - SC-PRED-003: Prediction errors MUST be tracked
  - SC-PRED-004: Model updates MUST be gradual
  """

  alias Indrajaal.Cybernetic.Inference.Belief

  @type prediction :: %{
          state: atom(),
          probability: float(),
          confidence: float(),
          horizon: non_neg_integer()
        }

  @type prediction_error :: %{
          predicted: term(),
          actual: term(),
          error: float()
        }

  # Maximum prediction horizon (steps into future)
  @max_horizon 10

  @doc """
  Generates a prediction for future observations given beliefs and action.
  """
  @spec predict(Belief.t(), atom(), map()) :: map()
  def predict(beliefs, action, model) do
    # Get transition probabilities for action
    transitions = get_transitions(model, action)

    # Calculate expected future state distribution
    mapped_states =
      Enum.into(beliefs.states, %{}, fn {current_state, current_prob} ->
        # Get transition probability for this state
        trans_probs = Map.get(transitions, current_state, default_transition())

        # Expected future states from this current state
        Enum.map(trans_probs, fn {future_state, trans_prob} ->
          {future_state, current_prob * trans_prob}
        end)
      end)

    future_states =
      mapped_states
      |> Enum.flat_map(& &1)
      |> Enum.group_by(fn {state, _} -> state end, fn {_, prob} -> prob end)
      |> Enum.into(%{}, fn {state, probs} -> {state, Enum.sum(probs)} end)

    # Normalize
    normalize_distribution(future_states)
  end

  @doc """
  Generates predictions for multiple steps into the future.
  """
  @spec predict_trajectory(Belief.t(), [atom()], map(), non_neg_integer()) :: [map()]
  def predict_trajectory(beliefs, actions, model, horizon \\ 5) do
    horizon = min(horizon, @max_horizon)

    {predictions, _final_beliefs} =
      Enum.reduce(
        Enum.take(actions ++ List.duplicate(:noop, horizon), horizon),
        {[], beliefs},
        fn action, {preds, current_beliefs} ->
          pred = predict(current_beliefs, action, model)
          # Convert prediction to beliefs for next step
          next_beliefs = prediction_to_beliefs(pred, current_beliefs)
          {[pred | preds], next_beliefs}
        end
      )

    Enum.reverse(predictions)
  end

  @doc """
  Calculates prediction error between predicted and actual observation.
  """
  @spec error(map(), map()) :: prediction_error()
  def error(predicted, actual) do
    # KL divergence between predicted and actual distributions
    kl_div =
      Enum.reduce(predicted, 0.0, fn {state, pred_prob}, acc ->
        # Handle zero probabilities to avoid ArithmeticError in log
        p = if pred_prob <= 0, do: 1.0e-10, else: pred_prob
        q = Map.get(actual, state, 1.0e-10)

        # Ensure q is not 0 to avoid division by zero
        q = if q <= 0, do: 1.0e-10, else: q

        try do
          acc + p * :math.log(p / q)
        rescue
          e ->
            Indrajaal.Observability.FractalLogger.spine(
              "Prediction",
              "KL Divergence Arithmetic Error",
              %{
                error: inspect(e),
                p: p,
                q: q,
                acc: acc,
                state: state
              }
            )

            acc
        end
      end)

    %{
      predicted: predicted,
      actual: actual,
      error: kl_div
    }
  end

  @doc """
  Evaluates prediction accuracy over time.
  """
  @spec accuracy([prediction_error()]) :: float()
  def accuracy([]), do: 1.0

  def accuracy(errors) do
    total_error = Enum.sum(Enum.map(errors, & &1.error))
    # Convert to accuracy (inverse of error, bounded to [0, 1])
    1.0 / (1.0 + total_error / length(errors))
  end

  @doc """
  Updates the generative model based on prediction errors.
  """
  @spec update_model(map(), [prediction_error()], float()) :: map()
  def update_model(model, errors, learning_rate \\ 0.1) do
    # Simplified model update - would use proper gradient descent in production
    avg_error =
      if Enum.empty?(errors),
        do: 0.0,
        else: Enum.sum(Enum.map(errors, & &1.error)) / length(errors)

    # Adjust model confidence based on error
    model_confidence = Map.get(model, :confidence, 1.0)
    new_confidence = model_confidence * (1.0 - learning_rate * avg_error)

    Map.put(model, :confidence, max(0.1, min(1.0, new_confidence)))
  end

  @doc """
  Returns the most likely predicted state.
  """
  @spec most_likely(map()) :: {atom(), float()}
  def most_likely(prediction) do
    Enum.max_by(prediction, fn {_, prob} -> prob end, fn -> {:unknown, 0.0} end)
  end

  @doc """
  Calculates the entropy of a prediction distribution.
  """
  @spec entropy(map()) :: float()
  def entropy(prediction) do
    prediction
    |> Enum.reduce(0.0, fn {_, prob}, acc ->
      if prob > 0 do
        acc - prob * :math.log(prob)
      else
        acc
      end
    end)
  end

  @doc """
  Returns the prediction uncertainty (based on entropy).
  """
  @spec uncertainty(map()) :: float()
  def uncertainty(prediction) do
    ent = entropy(prediction)
    max_ent = :math.log(max(1, map_size(prediction)))
    if max_ent > 0, do: ent / max_ent, else: 0.0
  end

  @doc """
  Checks if prediction is confident enough.
  """
  @spec confident?(map(), float()) :: boolean()
  def confident?(prediction, threshold \\ 0.6) do
    {_, best_prob} = most_likely(prediction)
    best_prob >= threshold
  end

  # Private helpers

  defp get_transitions(model, action) do
    transitions_map = Map.get(model, :transitions, %{})
    Map.get(transitions_map, action, default_transitions())
  end

  defp default_transitions do
    %{
      normal: %{normal: 0.9, degraded: 0.1, critical: 0.0, failed: 0.0},
      degraded: %{normal: 0.2, degraded: 0.6, critical: 0.2, failed: 0.0},
      critical: %{normal: 0.0, degraded: 0.3, critical: 0.5, failed: 0.2},
      failed: %{normal: 0.0, degraded: 0.0, critical: 0.2, failed: 0.8}
    }
  end

  defp default_transition do
    %{normal: 0.5, degraded: 0.3, critical: 0.15, failed: 0.05}
  end

  defp normalize_distribution(dist) do
    total = Enum.sum(Map.values(dist))

    if total > 0 do
      Enum.into(dist, %{}, fn {k, v} -> {k, v / total} end)
    else
      dist
    end
  end

  defp prediction_to_beliefs(prediction, original_beliefs) do
    %{original_beliefs | states: prediction}
  end
end
