defmodule Indrajaal.AI.Evolution.TrainingGym do
  @moduledoc """
  Training gym for continuous improvement of AI routing.

  ## Purpose

  The TrainingGym records AI operation outcomes and uses them to
  improve model selection and routing decisions over time.

  ## Episode Types

  - `:success` - Request completed successfully
  - `:failure` - Request failed
  - `:near_miss` - Almost failed, recovered gracefully
  - `:shadow_diverge` - Shadow model produced different output
  - `:shadow_agree` - Shadow model agreed with primary
  - `:veto_override` - Guardian veto was overridden
  - `:budget_limit` - Hit budget constraints

  ## Learning Feedback Loop

  1. Record episodes during operation
  2. Aggregate patterns hourly
  3. Update model scoring weights
  4. Publish learnings to Zenoh for distributed consumption

  ## STAMP Constraints

  - SC-AI-104: TrainingGym records all episodes
  - SC-AI-107: Learning cycles < 1 hour
  - SC-AI-108: Zenoh publishes learnings

  ## Usage

      TrainingGym.record_episode(%{
        type: :success,
        primary_model: "anthropic/claude-3.5-sonnet",
        request_intent: :synthesize
      })

      score = TrainingGym.get_model_score("anthropic/claude-3.5-sonnet")
  """

  use GenServer

  alias Indrajaal.AI.Simplex.TelemetryFlow

  require Logger

  @learning_cycle_interval :timer.hours(1)
  @max_episodes 10_000

  defstruct episodes: [],
            model_scores: %{},
            intent_success_rates: %{},
            action_values: %{},
            goal_performance: %{1 => 0.5, 2 => 0.5, 3 => 0.5},
            last_learning_cycle: nil,
            total_episodes_recorded: 0

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Start the TrainingGym GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record an episode from an AI operation.

  ## Episode Structure

      %{
        type: :success | :failure | :shadow_diverge | ...,
        primary_model: "model-id",
        shadow_model: "model-id" | nil,
        request_intent: :analyze | :synthesize | ...,
        divergence_score: 0.0..1.0,
        error_type: atom() | nil,
        timestamp: DateTime.t()
      }
  """
  @spec record_episode(map()) :: :ok
  def record_episode(episode) do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.cast(__MODULE__, {:record, episode})
    end
  end

  @doc """
  Get the current score for a model.

  Scores are between 0.0 (poor) and 1.0 (excellent).
  """
  @spec get_model_score(String.t()) :: float()
  def get_model_score(model) do
    case GenServer.whereis(__MODULE__) do
      # Default to neutral
      nil -> 1.0
      _pid -> GenServer.call(__MODULE__, {:get_score, model})
    end
  end

  @doc """
  Get success rate for an intent.
  """
  @spec get_intent_success_rate(atom()) :: float()
  def get_intent_success_rate(intent) do
    case GenServer.whereis(__MODULE__) do
      nil -> 1.0
      _pid -> GenServer.call(__MODULE__, {:get_intent_rate, intent})
    end
  end

  @doc """
  Manually trigger a learning cycle.
  """
  @spec trigger_learning_cycle() :: :ok
  def trigger_learning_cycle do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.cast(__MODULE__, :learn)
    end
  end

  @doc """
  Get current statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    case GenServer.whereis(__MODULE__) do
      nil -> %{}
      _pid -> GenServer.call(__MODULE__, :get_stats)
    end
  end

  @doc """
  Get recent episodes from the training history.
  Used by test step definitions.
  """
  @spec get_recent_episodes(non_neg_integer()) :: list(map())
  def get_recent_episodes(count) when is_integer(count) and count > 0 do
    case GenServer.whereis(__MODULE__) do
      nil -> []
      _pid -> GenServer.call(__MODULE__, {:get_recent_episodes, count})
    end
  end

  # ===========================================================================
  # RL Feedback Integration (AOR-CAE-003)
  # ===========================================================================

  @doc """
  Record OODA action outcome for reinforcement learning.

  This integrates with FastOODA to provide feedback on decisions.
  AOR-CAE-003: All CAE actions MUST record outcomes to TrainingGym.

  ## Parameters
  - action: The action that was taken
  - outcome: :success | :failure | :partial
  - reward: Numeric reward signal (-1.0 to 1.0)
  - context: Additional context about the decision

  ## Example

      TrainingGym.record_ooda_outcome(
        :adjust_parameters,
        :success,
        0.8,
        %{cycle: 42, confidence: 0.95}
      )
  """
  @spec record_ooda_outcome(atom(), atom(), float(), map()) :: :ok
  def record_ooda_outcome(action, outcome, reward, context \\ %{}) do
    episode = %{
      type: :ooda_feedback,
      action: action,
      outcome: outcome,
      reward: reward,
      context: context,
      timestamp: DateTime.utc_now()
    }

    record_episode(episode)
  end

  @doc """
  Get the Q-value estimate for an action in current state.

  Returns a score from 0.0 to 1.0 indicating expected reward.
  Higher values mean the action has historically performed well.
  """
  @spec get_action_value(atom()) :: float()
  def get_action_value(action) do
    case GenServer.whereis(__MODULE__) do
      # Neutral default
      nil -> 0.5
      _pid -> GenServer.call(__MODULE__, {:get_action_value, action})
    end
  end

  @doc """
  Get recommended action from learned policy.

  Given a list of possible actions, returns the one with highest
  expected value based on historical outcomes.
  """
  @spec recommend_action(list(atom())) :: {atom(), float()}
  def recommend_action(possible_actions) when is_list(possible_actions) do
    case GenServer.whereis(__MODULE__) do
      nil ->
        # Default to first action with neutral score
        {List.first(possible_actions, :default), 0.5}

      _pid ->
        GenServer.call(__MODULE__, {:recommend_action, possible_actions})
    end
  end

  @doc """
  Record goal-aligned outcome for FounderDirective integration.

  This connects training to the three supreme goals:
  - Goal 1: Symbiotic Survival (weight 0.5)
  - Goal 2: Sentience (weight 0.3)
  - Goal 3: Power (weight 0.2)
  """
  @spec record_goal_outcome(1 | 2 | 3, atom(), float(), map()) :: :ok
  def record_goal_outcome(goal_number, outcome, magnitude, context \\ %{})
      when goal_number in [1, 2, 3] do
    weight =
      case goal_number do
        1 -> 0.5
        2 -> 0.3
        3 -> 0.2
      end

    episode = %{
      type: :goal_feedback,
      goal: goal_number,
      goal_weight: weight,
      outcome: outcome,
      magnitude: magnitude,
      weighted_reward: magnitude * weight,
      context: context,
      timestamp: DateTime.utc_now()
    }

    record_episode(episode)
  end

  # ---------------------------------------------------------------------------
  # Server Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    # Schedule periodic learning cycles
    Process.send_after(self(), :periodic_learn, @learning_cycle_interval)

    {:ok, %__MODULE__{last_learning_cycle: DateTime.utc_now()}}
  end

  @impl true
  def handle_cast({:record, episode}, state) do
    # Add timestamp if not present
    episode = Map.put_new(episode, :timestamp, DateTime.utc_now())

    # Keep only the most recent episodes
    new_episodes = [episode | state.episodes] |> Enum.take(@max_episodes)

    # Update running scores based on episode type
    new_scores = update_model_scores(state.model_scores, episode)
    new_rates = update_success_rates(state.intent_success_rates, episode)
    new_action_values = update_action_values(state.action_values, episode)
    new_goal_perf = update_goal_performance(state.goal_performance, episode)

    new_state = %{
      state
      | episodes: new_episodes,
        model_scores: new_scores,
        intent_success_rates: new_rates,
        action_values: new_action_values,
        goal_performance: new_goal_perf,
        total_episodes_recorded: state.total_episodes_recorded + 1
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:learn, state) do
    learnings = analyze_episodes(state.episodes)
    publish_learnings(learnings)

    new_state = %{
      state
      | last_learning_cycle: DateTime.utc_now(),
        # Clear after learning
        episodes: []
    }

    Logger.info("[TrainingGym] Learning cycle complete: #{inspect(learnings, pretty: true)}")

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_score, model}, _from, state) do
    score = Map.get(state.model_scores, model, 1.0)
    {:reply, score, state}
  end

  @impl true
  def handle_call({:get_intent_rate, intent}, _from, state) do
    rate = Map.get(state.intent_success_rates, intent, 1.0)
    {:reply, rate, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      total_episodes: state.total_episodes_recorded,
      pending_episodes: length(state.episodes),
      model_scores: state.model_scores,
      intent_success_rates: state.intent_success_rates,
      action_values: state.action_values,
      goal_performance: state.goal_performance,
      last_learning_cycle: state.last_learning_cycle
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:get_recent_episodes, count}, _from, state) do
    recent = Enum.take(state.episodes, count)
    {:reply, recent, state}
  end

  @impl true
  def handle_call({:get_action_value, action}, _from, state) do
    value = Map.get(state.action_values, action, 0.5)
    {:reply, value, state}
  end

  @impl true
  def handle_call({:recommend_action, possible_actions}, _from, state) do
    # Find action with highest value
    best =
      Enum.map(possible_actions, fn action ->
        value = Map.get(state.action_values, action, 0.5)
        {action, value}
      end)
      |> Enum.max_by(fn {_action, value} -> value end, fn -> {:default, 0.5} end)

    {:reply, best, state}
  end

  @impl true
  def handle_info(:periodic_learn, state) do
    handle_cast(:learn, state)
    Process.send_after(self(), :periodic_learn, @learning_cycle_interval)
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private Functions
  # ---------------------------------------------------------------------------

  defp update_model_scores(scores, %{type: :success, primary_model: model})
       when is_binary(model) do
    # Increase score on success (exponential moving average)
    Map.update(scores, model, 1.0, &min(1.0, &1 * 0.99 + 0.01))
  end

  defp update_model_scores(scores, %{type: :shadow_agree, primary_model: model})
       when is_binary(model) do
    # Slight increase on shadow agreement
    Map.update(scores, model, 1.0, &min(1.0, &1 * 0.995 + 0.005))
  end

  defp update_model_scores(scores, %{type: :failure, primary_model: model})
       when is_binary(model) do
    # Decrease score on failure
    Map.update(scores, model, 0.5, &max(0.0, &1 * 0.95 - 0.02))
  end

  defp update_model_scores(scores, %{type: :shadow_diverge, primary_model: model})
       when is_binary(model) do
    # Slight decrease on divergence (not necessarily wrong, but worth noting)
    Map.update(scores, model, 0.8, &max(0.0, &1 * 0.99 - 0.005))
  end

  defp update_model_scores(scores, _), do: scores

  defp update_success_rates(rates, %{type: :success, request_intent: intent})
       when not is_nil(intent) do
    Map.update(rates, intent, 1.0, &min(1.0, &1 * 0.99 + 0.01))
  end

  defp update_success_rates(rates, %{type: :failure, request_intent: intent})
       when not is_nil(intent) do
    Map.update(rates, intent, 0.5, &max(0.0, &1 * 0.95 - 0.02))
  end

  defp update_success_rates(rates, _), do: rates

  # RL Action Value Updates (Q-learning style)
  @learning_rate 0.1

  defp update_action_values(values, %{type: :ooda_feedback, action: action, reward: reward})
       when is_atom(action) and is_number(reward) do
    # Q-learning update: Q(a) = Q(a) + α * (reward - Q(a))
    current = Map.get(values, action, 0.5)
    new_value = current + @learning_rate * (normalize_reward(reward) - current)
    Map.put(values, action, clamp(new_value, 0.0, 1.0))
  end

  defp update_action_values(values, _), do: values

  defp normalize_reward(reward) when reward >= 0, do: 0.5 + reward * 0.5
  defp normalize_reward(reward), do: 0.5 + reward * 0.5

  defp clamp(value, min_val, max_val), do: max(min_val, min(max_val, value))

  # Goal Performance Updates
  defp update_goal_performance(perf, %{type: :goal_feedback, goal: goal, weighted_reward: reward})
       when goal in [1, 2, 3] and is_number(reward) do
    current = Map.get(perf, goal, 0.5)
    new_value = current * 0.95 + reward * 0.05
    Map.put(perf, goal, clamp(new_value, 0.0, 1.0))
  end

  defp update_goal_performance(perf, _), do: perf

  defp analyze_episodes(episodes) do
    %{
      total_episodes: length(episodes),
      success_rate: calculate_rate(episodes, :success),
      failure_rate: calculate_rate(episodes, :failure),
      divergence_rate: calculate_divergence_rate(episodes),
      top_models: top_models(episodes, 5),
      struggling_intents: struggling_intents(episodes, 3),
      average_divergence: average_divergence(episodes)
    }
  end

  defp calculate_rate(episodes, type) do
    if length(episodes) > 0 do
      count = Enum.count(episodes, &(&1.type == type))
      Float.round(count / length(episodes), 4)
    else
      0.0
    end
  end

  defp calculate_divergence_rate(episodes) do
    shadow_episodes = Enum.filter(episodes, &(&1.type in [:shadow_diverge, :shadow_agree]))

    if length(shadow_episodes) > 0 do
      divergences = Enum.count(shadow_episodes, &(&1.type == :shadow_diverge))
      Float.round(divergences / length(shadow_episodes), 4)
    else
      0.0
    end
  end

  defp top_models(episodes, limit) do
    episodes
    |> Enum.filter(&(&1.type == :success and is_binary(&1[:primary_model])))
    |> Enum.frequencies_by(& &1[:primary_model])
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(limit)
    |> Enum.map(&elem(&1, 0))
  end

  defp struggling_intents(episodes, limit) do
    episodes
    |> Enum.filter(&(&1.type == :failure and not is_nil(&1[:request_intent])))
    |> Enum.frequencies_by(& &1[:request_intent])
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(limit)
    |> Enum.map(&elem(&1, 0))
  end

  defp average_divergence(episodes) do
    divergence_episodes = Enum.filter(episodes, &is_number(&1[:divergence_score]))

    if length(divergence_episodes) > 0 do
      sum = Enum.sum(Enum.map(divergence_episodes, & &1[:divergence_score]))
      Float.round(sum / length(divergence_episodes), 4)
    else
      0.0
    end
  end

  defp publish_learnings(learnings) do
    # Publish to Zenoh via evolution publisher using dynamic call
    try do
      publisher = Indrajaal.Observability.ZenohEvolutionPublisher

      episode = %{
        type: :training_gym_cycle,
        learnings: learnings,
        timestamp: DateTime.utc_now()
      }

      if Code.ensure_loaded?(publisher) and
           function_exported?(publisher, :publish_training_episode, 1) do
        publisher.publish_training_episode(episode)
      end
    rescue
      _ -> :ok
    end

    # Also emit via telemetry
    TelemetryFlow.emit_ai_event(
      [:training_gym, :learning_cycle],
      %{
        episodes_analyzed: learnings.total_episodes,
        success_rate: learnings.success_rate
      },
      %{
        timestamp: DateTime.utc_now()
      }
    )
  end
end
