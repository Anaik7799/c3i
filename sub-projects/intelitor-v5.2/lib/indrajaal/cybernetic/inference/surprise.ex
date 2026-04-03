defmodule Indrajaal.Cybernetic.Inference.Surprise do
  @moduledoc """
  Surprise Metrics - Information-Theoretic Surprise for v20.0.0

  Implements surprise calculations for active inference:
  - Bayesian surprise (KL divergence between prior and posterior)
  - Shannon surprise (negative log probability)
  - Expected surprise (for action evaluation)

  ## Mathematical Foundation

  Surprise S = -log p(o | m)

  Where:
  - o = Observation
  - m = Model (generative model)
  - p(o|m) = Probability of observation given model

  ## Interpretations
  - High surprise → Unexpected observation → Update beliefs strongly
  - Low surprise → Expected observation → Maintain current beliefs
  - Moderate surprise → Learning opportunity → Balanced update

  ## STAMP Constraints
  - SC-SUR-001: Surprise MUST be non-negative
  - SC-SUR-002: Surprise calculation MUST be < 1ms
  - SC-SUR-003: Infinite surprise MUST be capped
  - SC-SUR-004: Surprise MUST trigger belief update when > threshold
  """

  alias Indrajaal.Cybernetic.Inference.Belief

  @type observation :: map()
  @type surprise_value :: float()

  # Maximum surprise to prevent numerical issues
  @max_surprise 100.0

  # Threshold for "significant" surprise
  @surprise_threshold 2.0

  @doc """
  Calculates Shannon surprise for an observation.

  S = -log p(o | beliefs)
  """
  @spec calculate(observation(), Belief.t()) :: surprise_value()
  def calculate(observation, beliefs) do
    probability = Belief.probability(beliefs, observation)

    surprise =
      if probability > 0 do
        -:math.log(probability)
      else
        @max_surprise
      end

    # Cap at maximum (SC-SUR-003)
    min(surprise, @max_surprise)
  end

  @doc """
  Calculates Bayesian surprise (KL divergence).

  D_KL(posterior || prior) = Σ posterior(s) * log(posterior(s) / prior(s))
  """
  @spec bayesian(Belief.t(), Belief.t()) :: surprise_value()
  def bayesian(posterior, prior) do
    # Simplified KL divergence calculation
    posterior_entropy = Belief.entropy(posterior)
    prior_entropy = Belief.entropy(prior)

    abs(posterior_entropy - prior_entropy)
  end

  @doc """
  Calculates expected surprise for a predicted observation distribution.
  """
  @spec expected(map(), Belief.t()) :: surprise_value()
  def expected(predicted_distribution, beliefs) do
    # E[S] = -Σ p(o) * log p(o | beliefs)
    predicted_distribution
    |> Enum.reduce(0.0, fn {obs, prob}, acc ->
      obs_surprise = calculate(obs, beliefs)
      acc + prob * obs_surprise
    end)
  end

  @doc """
  Determines if surprise is significant enough to warrant belief update.
  """
  @spec significant?(surprise_value()) :: boolean()
  def significant?(surprise) do
    surprise > @surprise_threshold
  end

  @doc """
  Calculates the learning rate based on surprise.

  Higher surprise → Higher learning rate → Faster belief update
  """
  @spec learning_rate(surprise_value()) :: float()
  def learning_rate(surprise) do
    # Sigmoid-like function: maps surprise to [0.01, 1.0]
    base_rate = 0.01
    max_rate = 1.0
    sensitivity = 0.5

    rate = base_rate + (max_rate - base_rate) * (1 - :math.exp(-sensitivity * surprise))
    min(max_rate, max(base_rate, rate))
  end

  @doc """
  Categorizes surprise level.
  """
  @spec categorize(surprise_value()) :: :low | :moderate | :high | :extreme
  def categorize(surprise) do
    cond do
      surprise < 1.0 -> :low
      surprise < 3.0 -> :moderate
      surprise < 10.0 -> :high
      true -> :extreme
    end
  end

  @doc """
  Calculates the surprise derivative (rate of change).
  """
  @spec derivative([surprise_value()]) :: float()
  def derivative([]), do: 0.0
  def derivative([_]), do: 0.0

  def derivative([current, previous | _]) do
    current - previous
  end

  @doc """
  Checks if surprise is increasing (potential anomaly).
  """
  @spec increasing?([surprise_value()]) :: boolean()
  def increasing?(history) do
    derivative(history) > 0.5
  end

  @doc """
  Normalizes surprise to [0, 1] range.
  """
  @spec normalize(surprise_value()) :: float()
  def normalize(surprise) do
    1.0 - :math.exp(-surprise / @max_surprise * 5)
  end

  @doc """
  Returns the surprise threshold.
  """
  @spec threshold() :: float()
  def threshold, do: @surprise_threshold

  @doc """
  Returns summary statistics for a surprise history.
  """
  @spec summary([surprise_value()]) :: map()
  def summary([]), do: %{count: 0, mean: 0.0, max: 0.0, min: 0.0, trend: :stable}

  def summary(history) do
    %{
      count: length(history),
      mean: Enum.sum(history) / length(history),
      max: Enum.max(history),
      min: Enum.min(history),
      trend: if(increasing?(history), do: :increasing, else: :stable)
    }
  end
end
