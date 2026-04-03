defmodule Indrajaal.Cybernetic.Inference.ActiveInference do
  @moduledoc """
  Active Inference Engine - Free Energy Principle for v20.0.0

  Implements the Free Energy Principle (FEP) for autonomous decision-making:
  - Minimizes variational free energy
  - Balances exploration vs exploitation
  - Updates beliefs based on observations
  - Selects actions to reduce surprise

  ## Free Energy Principle

  F = E_q[log q(s) - log p(o,s)]

  Where:
  - F = Free energy (to minimize)
  - q(s) = Approximate posterior (beliefs about hidden states)
  - p(o,s) = Generative model (joint probability of observations and states)
  - o = Observations
  - s = Hidden states

  ## Key Concepts
  - **Surprise**: -log p(o|m) - Unexpectedness of observations
  - **Entropy**: Uncertainty in beliefs
  - **Expected Free Energy**: Future-oriented decision criterion

  ## STAMP Constraints
  - SC-AI-001: Free energy MUST decrease over time (on average)
  - SC-AI-002: Beliefs MUST be updated within 10ms
  - SC-AI-003: Action selection MUST consider epistemic value
  - SC-AI-004: Model MUST be validated against observations
  - SC-MATH-004: ISOLATED discipline connected to active Sentinel caller

  ## Category Theory
  Active Inference forms a Lens over the belief-observation duality:
  - get : Belief → Observation (prediction)
  - put : Belief × Observation → Belief (update)

  ## Runtime Callers
  - `Indrajaal.Safety.Sentinel.assess_now/0` — enriches health assessments
    with Bayesian posterior beliefs derived from system metric observations.
  """

  require Logger

  alias Indrajaal.Cybernetic.Inference.Belief
  alias Indrajaal.Cybernetic.Inference.Surprise
  alias Indrajaal.Cybernetic.Inference.Prediction
  alias Indrajaal.Cybernetic.Inference.ActionSelection

  @type state :: %{
          beliefs: Belief.t(),
          model: map(),
          free_energy: float(),
          history: [float()],
          iteration: non_neg_integer()
        }

  @type observation :: map()
  @type action :: atom()

  @doc """
  Creates a new active inference agent state.
  """
  @spec new(map()) :: state()
  def new(initial_model \\ %{}) do
    %{
      beliefs: Belief.new(),
      model: initial_model,
      free_energy: 0.0,
      history: [],
      iteration: 0
    }
  end

  @doc """
  Runs a single active inference cycle.

  1. Observe - Get current observations
  2. Infer - Update beliefs based on observations
  3. Predict - Generate predictions from beliefs
  4. Act - Select action to minimize expected free energy
  """
  @spec cycle(state(), observation()) :: {action(), state()}
  def cycle(state, observation) do
    start_time = System.monotonic_time(:millisecond)

    # 1. Calculate surprise from observation
    surprise = Surprise.calculate(observation, state.beliefs)

    # 2. Update beliefs based on observation
    updated_beliefs = Belief.update(state.beliefs, observation, surprise)

    # 3. Calculate new free energy
    new_free_energy = calculate_free_energy(updated_beliefs, observation, state.model)

    # 4. Select action to minimize expected free energy
    action = ActionSelection.select(updated_beliefs, state.model)

    # Update state
    new_state = %{
      state
      | beliefs: updated_beliefs,
        free_energy: new_free_energy,
        history: [new_free_energy | Enum.take(state.history, 99)],
        iteration: state.iteration + 1
    }

    duration = System.monotonic_time(:millisecond) - start_time

    if duration > 10 do
      Logger.warning("Active inference cycle exceeded 10ms (#{duration}ms)")
    end

    # Emit telemetry
    :telemetry.execute(
      [:indrajaal, :inference, :cycle],
      %{duration_ms: duration, free_energy: new_free_energy, surprise: surprise},
      %{iteration: new_state.iteration}
    )

    {action, new_state}
  end

  @doc """
  Calculates the variational free energy.

  F = E_q[log q(s)] - E_q[log p(o,s)]
    = -H[q(s)] + E_q[-log p(o,s)]
    = Negative entropy + Expected energy
  """
  @spec calculate_free_energy(Belief.t(), observation(), map()) :: float()
  def calculate_free_energy(beliefs, observation, model) do
    # Negative entropy (complexity)
    complexity = -Belief.entropy(beliefs)

    # Expected energy (accuracy)
    accuracy = expected_energy(beliefs, observation, model)

    complexity + accuracy
  end

  @doc """
  Calculates the expected free energy for action selection.

  G = E_q[log q(s|π) - log p(o,s|π)]

  This is used to evaluate policies (action sequences).
  """
  @spec expected_free_energy(Belief.t(), action(), map()) :: float()
  def expected_free_energy(beliefs, action, model) do
    # Predict future observations under this action
    predicted_obs = Prediction.predict(beliefs, action, model)

    # Calculate expected surprise
    expected_surprise = Surprise.expected(predicted_obs, beliefs)

    # Calculate epistemic value (information gain)
    epistemic_value = Belief.information_gain(beliefs, predicted_obs)

    # G = expected surprise - epistemic value
    # Lower G means better action
    expected_surprise - epistemic_value
  end

  @doc """
  Checks if free energy is decreasing (convergence).
  """
  @spec converging?(state()) :: boolean()
  def converging?(state) do
    case state.history do
      [current, previous | _] -> current <= previous
      _ -> true
    end
  end

  @doc """
  Returns the average free energy over recent history.
  """
  @spec average_free_energy(state()) :: float()
  def average_free_energy(%{history: []}) do
    0.0
  end

  def average_free_energy(%{history: history}) do
    Enum.sum(history) / length(history)
  end

  @doc """
  Resets the agent to initial state.
  """
  @spec reset(state()) :: state()
  def reset(state) do
    %{state | beliefs: Belief.new(), free_energy: 0.0, history: [], iteration: 0}
  end

  @doc """
  Returns a summary of the current state.
  """
  @spec summary(state()) :: map()
  def summary(state) do
    %{
      iteration: state.iteration,
      free_energy: state.free_energy,
      avg_free_energy: average_free_energy(state),
      converging: converging?(state),
      belief_entropy: Belief.entropy(state.beliefs),
      history_length: length(state.history)
    }
  end

  @doc """
  Infers the system health state from a metrics observation map.

  Convenience entry-point for callers that have a flat metrics map (such as
  `Indrajaal.Safety.Sentinel`) and want a Bayesian posterior over the four
  canonical health states: `:normal`, `:degraded`, `:critical`, `:failed`.

  ## Parameters
  - `metrics` - Map with numeric fields, typically produced by Sentinel's
    `collect_system_metrics/0`.  Recognised keys (all optional):
    - `:memory_usage`  — 0.0..1.0 fraction of system memory
    - `:cpu_usage`     — 0.0..1.0 scheduler utilisation
    - `:error_rate`    — errors per minute
    - `:health_score`  — pre-computed score 0.0..1.0 (highest weight)

  ## Returns
  - `{:ok, result}` where `result` is:
    ```
    %{
      most_likely_state: atom(),
      confidence: float(),
      free_energy: float(),
      beliefs: map(),   # %{normal: p, degraded: p, critical: p, failed: p}
      converging: boolean()
    }
    ```
  - `{:error, :invalid_metrics}` — if `metrics` is not a map

  ## STAMP Compliance
  - SC-MATH-004: Connects ActiveInference from ISOLATED to ACTIVE
  - SC-AI-002: Completes within 10ms on healthy hardware

  ## Examples

      iex> ActiveInference.infer_system_state(%{health_score: 0.95})
      {:ok, %{most_likely_state: :normal, confidence: _, free_energy: _, ...}}

      iex> ActiveInference.infer_system_state(%{health_score: 0.1, error_rate: 200})
      {:ok, %{most_likely_state: :critical, confidence: _, free_energy: _, ...}}

  """
  @spec infer_system_state(map()) ::
          {:ok,
           %{
             most_likely_state: atom(),
             confidence: float(),
             free_energy: float(),
             beliefs: map(),
             converging: boolean()
           }}
          | {:error, :invalid_metrics}
  def infer_system_state(metrics) when is_map(metrics) do
    # Build observation from metrics, normalising to [0,1] range
    health_score = Map.get(metrics, :health_score, nil)
    memory = Map.get(metrics, :memory_usage, 0.0)
    cpu = Map.get(metrics, :cpu_usage, 0.0)
    error_rate = Map.get(metrics, :error_rate, 0.0)

    # Derive a composite health signal when no pre-computed score is available
    derived_health =
      if is_float(health_score) do
        health_score
      else
        # Simple inversion: high resource usage → low health
        resource_pressure = memory * 0.4 + cpu * 0.3 + min(error_rate / 100.0, 1.0) * 0.3
        max(0.0, 1.0 - resource_pressure)
      end

    # Map health signal to the closest canonical state atom for the Belief update
    obs_state =
      cond do
        derived_health >= 0.75 -> :normal
        derived_health >= 0.50 -> :degraded
        derived_health >= 0.25 -> :critical
        true -> :failed
      end

    observation = %{state: obs_state, health: derived_health}

    # Run one inference cycle against a fresh agent
    agent = new()
    {_action, updated_agent} = cycle(agent, observation)

    {best_state, _best_prob} = Belief.most_likely(updated_agent.beliefs)

    result = %{
      most_likely_state: best_state,
      confidence: updated_agent.beliefs.confidence,
      free_energy: updated_agent.free_energy,
      beliefs: updated_agent.beliefs.states,
      converging: converging?(updated_agent)
    }

    {:ok, result}
  end

  def infer_system_state(_non_map), do: {:error, :invalid_metrics}

  # Private helpers

  defp expected_energy(beliefs, observation, _model) do
    # Simplified: negative log likelihood
    -Belief.log_likelihood(beliefs, observation)
  end
end
