defmodule Indrajaal.Cybernetic.Inference.Model do
  @moduledoc """
  Generative Model - World Model for Active Inference v20.0.0

  Implements the generative model p(o, s) for active inference:
  - State transition dynamics
  - Observation likelihood
  - Action effects
  - Model learning and adaptation

  ## Generative Model Structure

  p(o, s) = p(o | s) × p(s)

  Where:
  - p(o | s) = Observation model (likelihood)
  - p(s) = State prior (dynamics)

  With actions: p(o, s | a) = p(o | s) × p(s | s', a)

  ## Model Components
  - **A matrix**: Observation model (state → observation)
  - **B matrix**: Transition model (state × action → next state)
  - **C vector**: Preferences (desired observations)
  - **D vector**: Prior beliefs (initial state distribution)

  ## STAMP Constraints
  - SC-MOD-001: Model MUST be validated against data
  - SC-MOD-002: Model updates MUST preserve stability
  - SC-MOD-003: Model MUST support online learning
  - SC-MOD-004: Model complexity MUST be bounded
  """

  @type t :: %__MODULE__{
          observation_model: map(),
          transition_model: map(),
          preferences: map(),
          prior: map(),
          actions: [atom()],
          confidence: float(),
          learning_rate: float(),
          version: non_neg_integer()
        }

  defstruct observation_model: %{},
            transition_model: %{},
            preferences: %{},
            prior: %{},
            actions: [],
            confidence: 1.0,
            learning_rate: 0.1,
            version: 0

  @type state :: atom()
  @type observation :: map()
  @type action :: atom()

  @doc """
  Creates a new generative model with default parameters.
  """
  @spec new(Keyword.t()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      observation_model: Keyword.get(opts, :observation_model, default_observation_model()),
      transition_model: Keyword.get(opts, :transition_model, default_transition_model()),
      preferences: Keyword.get(opts, :preferences, default_preferences()),
      prior: Keyword.get(opts, :prior, default_prior()),
      actions: Keyword.get(opts, :actions, default_actions()),
      confidence: 1.0,
      learning_rate: Keyword.get(opts, :learning_rate, 0.1),
      version: 0
    }
  end

  @doc """
  Returns the observation likelihood p(o | s).
  """
  @spec observation_likelihood(t(), state(), observation()) :: float()
  def observation_likelihood(model, state, observation) do
    state_obs = Map.get(model.observation_model, state, %{})

    # Calculate likelihood based on observation match
    obs_type = Map.get(observation, :type, :unknown)
    Map.get(state_obs, obs_type, 0.1)
  end

  @doc """
  Returns the transition probability p(s' | s, a).
  """
  @spec transition_probability(t(), state(), action(), state()) :: float()
  def transition_probability(model, current_state, action, next_state) do
    action_trans = Map.get(model.transition_model, action, %{})
    state_trans = Map.get(action_trans, current_state, %{})
    Map.get(state_trans, next_state, 0.1)
  end

  @doc """
  Returns the expected next state distribution p(s' | s, a).
  """
  @spec predict_next_state(t(), state(), action()) :: map()
  def predict_next_state(model, current_state, action) do
    action_trans = Map.get(model.transition_model, action, %{})
    Map.get(action_trans, current_state, default_next_state())
  end

  @doc """
  Returns the preference for a state (negative = preferred).
  """
  @spec preference(t(), state()) :: float()
  def preference(model, state) do
    Map.get(model.preferences, state, 0.0)
  end

  @doc """
  Returns the prior probability for a state.
  """
  @spec prior(t(), state()) :: float()
  def prior(model, state) do
    Map.get(model.prior, state, 0.25)
  end

  @doc """
  Updates the model based on observed transition.
  """
  @spec learn(t(), state(), action(), state(), observation()) :: t()
  def learn(model, from_state, action, to_state, _observation) do
    # Update transition model
    new_trans =
      update_transition(model.transition_model, from_state, action, to_state, model.learning_rate)

    %{
      model
      | transition_model: new_trans,
        version: model.version + 1
    }
  end

  @doc """
  Updates model confidence based on prediction accuracy.
  """
  @spec update_confidence(t(), float()) :: t()
  def update_confidence(model, accuracy) do
    # Exponential moving average
    new_confidence = 0.9 * model.confidence + 0.1 * accuracy
    %{model | confidence: new_confidence}
  end

  @doc """
  Validates the model structure.
  """
  @spec valid?(t()) :: boolean()
  def valid?(model) do
    # Check that distributions sum to 1
    transitions_valid =
      Enum.all?(model.transition_model, fn {_action, state_trans} ->
        Enum.all?(state_trans, fn {_from, to_dist} ->
          abs(Enum.sum(Map.values(to_dist)) - 1.0) < 0.01
        end)
      end)

    prior_valid = abs(Enum.sum(Map.values(model.prior)) - 1.0) < 0.01

    transitions_valid and prior_valid
  end

  @doc """
  Normalizes all distributions in the model.
  """
  @spec normalize(t()) :: t()
  def normalize(model) do
    normalized_trans =
      Enum.into(model.transition_model, %{}, fn {action, state_trans} ->
        normalized_state_trans =
          Enum.into(state_trans, %{}, fn {from, to_dist} ->
            {from, normalize_distribution(to_dist)}
          end)

        {action, normalized_state_trans}
      end)

    normalized_prior = normalize_distribution(model.prior)

    %{model | transition_model: normalized_trans, prior: normalized_prior}
  end

  @doc """
  Exports model to map for serialization.
  """
  @spec to_map(t()) :: map()
  def to_map(model) do
    %{
      observation_model: model.observation_model,
      transition_model: model.transition_model,
      preferences: model.preferences,
      prior: model.prior,
      actions: model.actions,
      confidence: model.confidence,
      version: model.version
    }
  end

  @doc """
  Returns model summary for monitoring.
  """
  @spec summary(t()) :: map()
  def summary(model) do
    %{
      version: model.version,
      confidence: model.confidence,
      num_actions: length(model.actions),
      num_states: map_size(model.prior),
      valid: valid?(model)
    }
  end

  # Private helpers

  defp default_observation_model do
    %{
      normal: %{metric_normal: 0.8, metric_warning: 0.15, metric_critical: 0.05},
      degraded: %{metric_normal: 0.2, metric_warning: 0.6, metric_critical: 0.2},
      critical: %{metric_normal: 0.05, metric_warning: 0.25, metric_critical: 0.7},
      failed: %{metric_normal: 0.01, metric_warning: 0.09, metric_critical: 0.9}
    }
  end

  defp default_transition_model do
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

  defp default_preferences do
    %{
      normal: 0.0,
      degraded: 1.0,
      critical: 5.0,
      failed: 10.0
    }
  end

  defp default_prior do
    %{
      normal: 0.7,
      degraded: 0.2,
      critical: 0.08,
      failed: 0.02
    }
  end

  defp default_actions do
    [:observe, :maintain, :repair, :escalate, :noop]
  end

  defp default_next_state do
    %{normal: 0.5, degraded: 0.3, critical: 0.15, failed: 0.05}
  end

  defp update_transition(trans_model, from_state, action, to_state, learning_rate) do
    action_trans = Map.get(trans_model, action, %{})
    state_trans = Map.get(action_trans, from_state, default_next_state())

    # Increase probability for observed transition
    state_trans_map =
      Enum.into(state_trans, %{}, fn {s, prob} ->
        if s == to_state do
          {s, prob + learning_rate * (1.0 - prob)}
        else
          {s, prob * (1.0 - learning_rate)}
        end
      end)

    new_state_trans = normalize_distribution(state_trans_map)

    new_action_trans = Map.put(action_trans, from_state, new_state_trans)
    Map.put(trans_model, action, new_action_trans)
  end

  defp normalize_distribution(dist) do
    total = Enum.sum(Map.values(dist))

    if total > 0 do
      Enum.into(dist, %{}, fn {k, v} -> {k, v / total} end)
    else
      dist
    end
  end
end
