defmodule Indrajaal.Cybernetic.Inference.Belief do
  @moduledoc """
  Belief State Management - Probabilistic Beliefs for v20.0.0

  Manages the agent's beliefs about the world state:
  - Probability distributions over hidden states
  - Belief updating via Bayesian inference
  - Entropy calculations
  - Information gain estimation

  ## Mathematical Foundation

  Beliefs are represented as probability distributions q(s) where:
  - s ∈ S is the set of possible hidden states
  - Σ q(s) = 1 (normalization)
  - q(s) ≥ 0 ∀s (non-negativity)

  ## Belief Update (Bayesian)

  q(s|o) ∝ p(o|s) * q(s)

  Where:
  - q(s|o) = Posterior belief after observation
  - p(o|s) = Likelihood of observation given state
  - q(s) = Prior belief

  ## STAMP Constraints
  - SC-BEL-001: Beliefs MUST sum to 1 (normalized)
  - SC-BEL-002: Beliefs MUST be non-negative
  - SC-BEL-003: Belief update MUST be numerically stable
  - SC-BEL-004: Entropy MUST be bounded [0, log(|S|)]
  """

  @type t :: %__MODULE__{
          states: map(),
          prior: map(),
          confidence: float(),
          last_update: DateTime.t() | nil
        }

  defstruct states: %{},
            prior: %{},
            confidence: 0.5,
            last_update: nil

  @type observation :: map()
  @type state_name :: atom()
  @type probability :: float()

  # Minimum probability to prevent log(0)
  @epsilon 1.0e-10

  @doc """
  Creates a new belief state with uniform prior.
  """
  @spec new(Keyword.t()) :: t()
  def new(opts \\ []) do
    initial_states = Keyword.get(opts, :states, default_states())

    # Uniform prior
    n = map_size(initial_states)
    uniform_prob = if n > 0, do: 1.0 / n, else: 1.0

    normalized =
      Enum.into(initial_states, %{}, fn {state, _} ->
        {state, uniform_prob}
      end)

    %__MODULE__{
      states: normalized,
      prior: normalized,
      confidence: 0.5,
      last_update: nil
    }
  end

  @doc """
  Updates beliefs based on an observation using Bayesian inference.
  """
  @spec update(t(), observation(), float()) :: t()
  def update(beliefs, observation, surprise) do
    learning_rate = Indrajaal.Cybernetic.Inference.Surprise.learning_rate(surprise)

    # Calculate likelihoods for each state
    likelihoods = calculate_likelihoods(beliefs.states, observation)

    # Bayesian update: posterior ∝ likelihood × prior
    unnormalized =
      Enum.into(beliefs.states, %{}, fn {state, prior_prob} ->
        likelihood = Map.get(likelihoods, state, @epsilon)
        # Blend prior with posterior based on learning rate
        new_prob = (1 - learning_rate) * prior_prob + learning_rate * likelihood
        {state, max(@epsilon, new_prob)}
      end)

    # Normalize
    normalized = normalize(unnormalized)

    # Update confidence based on entropy
    entropy = calculate_entropy(normalized)
    max_entropy = :math.log(map_size(normalized))
    new_confidence = if max_entropy > 0, do: 1.0 - entropy / max_entropy, else: 1.0

    %{
      beliefs
      | states: normalized,
        prior: beliefs.states,
        confidence: new_confidence,
        last_update: DateTime.utc_now()
    }
  end

  @doc """
  Returns the probability of an observation given current beliefs.
  """
  @spec probability(t(), observation()) :: probability()
  def probability(beliefs, observation) do
    # P(o) = Σ_s P(o|s) × P(s)
    beliefs.states
    |> Enum.reduce(0.0, fn {state, prob}, acc ->
      likelihood = likelihood(state, observation)
      acc + likelihood * prob
    end)
    |> max(@epsilon)
  end

  @doc """
  Returns the log probability of an observation.
  """
  @spec log_likelihood(t(), observation()) :: float()
  def log_likelihood(beliefs, observation) do
    prob = probability(beliefs, observation)
    :math.log(max(prob, @epsilon))
  end

  @doc """
  Calculates the entropy of the belief distribution.

  H(q) = -Σ q(s) × log q(s)
  """
  @spec entropy(t()) :: float()
  def entropy(beliefs) do
    calculate_entropy(beliefs.states)
  end

  @doc """
  Estimates the information gain from a predicted observation.

  I(o) = H(q) - E[H(q|o)]
  """
  @spec information_gain(t(), map()) :: float()
  def information_gain(beliefs, predicted_obs) do
    current_entropy = entropy(beliefs)

    # Expected entropy after observation
    expected_post_entropy =
      predicted_obs
      |> Enum.reduce(0.0, fn {obs, prob}, acc ->
        # Simulate belief update
        updated = update(beliefs, obs, 1.0)
        acc + prob * entropy(updated)
      end)

    max(0.0, current_entropy - expected_post_entropy)
  end

  @doc """
  Returns the most likely state.
  """
  @spec most_likely(t()) :: {state_name(), probability()}
  def most_likely(beliefs) do
    Enum.max_by(beliefs.states, fn {_, prob} -> prob end, fn -> {:unknown, 0.0} end)
  end

  @doc """
  Returns states with probability above threshold.
  """
  @spec likely_states(t(), probability()) :: [{state_name(), probability()}]
  def likely_states(beliefs, threshold \\ 0.1) do
    beliefs.states
    |> Enum.filter(fn {_, prob} -> prob >= threshold end)
    |> Enum.sort_by(fn {_, prob} -> prob end, :desc)
  end

  @doc """
  Merges two belief states (e.g., from different sources).
  """
  @spec merge(t(), t(), float()) :: t()
  def merge(beliefs1, beliefs2, weight1 \\ 0.5) do
    weight2 = 1.0 - weight1

    merged =
      Enum.into(beliefs1.states, %{}, fn {state, prob1} ->
        prob2 = Map.get(beliefs2.states, state, @epsilon)
        {state, weight1 * prob1 + weight2 * prob2}
      end)

    %{beliefs1 | states: normalize(merged), last_update: DateTime.utc_now()}
  end

  @doc """
  Resets beliefs to prior distribution.
  """
  @spec reset_to_prior(t()) :: t()
  def reset_to_prior(beliefs) do
    %{beliefs | states: beliefs.prior, confidence: 0.5, last_update: nil}
  end

  @doc """
  Returns a summary of the belief state.
  """
  @spec summary(t()) :: map()
  def summary(beliefs) do
    {best_state, best_prob} = most_likely(beliefs)

    %{
      most_likely: best_state,
      probability: best_prob,
      confidence: beliefs.confidence,
      entropy: entropy(beliefs),
      num_states: map_size(beliefs.states),
      last_update: beliefs.last_update
    }
  end

  # Private helpers

  defp default_states do
    %{
      normal: 0.5,
      degraded: 0.25,
      critical: 0.15,
      failed: 0.1
    }
  end

  defp calculate_likelihoods(states, observation) do
    Enum.into(states, %{}, fn {state, _} ->
      {state, likelihood(state, observation)}
    end)
  end

  defp likelihood(state, observation) do
    # Simplified likelihood model
    obs_state = Map.get(observation, :state, :unknown)

    if obs_state == state do
      0.8
    else
      0.2 / max(1, map_size(observation))
    end
  end

  defp normalize(distribution) do
    total = Enum.reduce(distribution, 0.0, fn {_, prob}, acc -> acc + prob end)

    if total > 0 do
      Enum.into(distribution, %{}, fn {state, prob} ->
        {state, prob / total}
      end)
    else
      distribution
    end
  end

  defp calculate_entropy(distribution) do
    distribution
    |> Enum.reduce(0.0, fn {_, prob}, acc ->
      if prob > @epsilon do
        acc - prob * :math.log(prob)
      else
        acc
      end
    end)
  end
end
