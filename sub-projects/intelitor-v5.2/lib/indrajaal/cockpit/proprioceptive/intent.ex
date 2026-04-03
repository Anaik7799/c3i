defmodule Indrajaal.Cockpit.Proprioceptive.Intent do
  @moduledoc """
  Intent Recognition - User Action Prediction for v20.0.0

  Implements intent recognition from user interactions:
  - Gesture recognition
  - Command prediction
  - Context-aware suggestions
  - Behavioral patterns

  ## Intent Model

  Intent = f(Actions, Context, History)

  Where:
  - Actions = recent user inputs
  - Context = current system state
  - History = past interaction patterns

  ## Recognition Methods
  - **Pattern Matching**: Known action sequences
  - **Statistical**: Frequency-based prediction
  - **Temporal**: Time-based patterns
  - **Contextual**: State-dependent predictions

  ## STAMP Constraints
  - SC-INT-001: Intent recognition < 50ms
  - SC-INT-002: False positive rate < 5%
  - SC-INT-003: Suggestions MUST be reversible
  - SC-INT-004: User autonomy MUST be preserved
  """

  use GenServer
  require Logger

  @type action :: atom()
  @type intent :: atom()
  @type confidence :: float()

  @type action_record :: %{
          action: action(),
          timestamp: DateTime.t(),
          context: map(),
          metadata: map()
        }

  @type intent_prediction :: %{
          intent: intent(),
          confidence: confidence(),
          suggested_actions: [action()],
          reasoning: String.t()
        }

  @type state :: %{
          action_history: [action_record()],
          patterns: map(),
          predictions: [intent_prediction()],
          config: map()
        }

  # Max action history
  @max_history 100

  # Confidence threshold for suggestions
  @confidence_threshold 0.7

  # Recognition timeout (ms)
  @recognition_timeout 50

  # Common action sequences (patterns)
  @known_patterns %{
    deploy: [[:build, :test, :deploy], [:compile, :verify, :release]],
    debug: [[:log, :inspect, :trace], [:breakpoint, :step, :examine]],
    monitor: [[:status, :metrics, :alerts], [:health, :performance, :logs]],
    config: [[:settings, :update, :apply], [:modify, :validate, :save]],
    recover: [[:backup, :restore, :verify], [:rollback, :check, :confirm]]
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records a user action.
  """
  @spec record_action(action(), map()) :: :ok
  def record_action(action, context \\ %{}) do
    GenServer.cast(__MODULE__, {:record_action, action, context})
  end

  @doc """
  Gets current intent predictions.
  """
  @spec predict() :: [intent_prediction()]
  def predict do
    GenServer.call(__MODULE__, :predict, @recognition_timeout)
  end

  @doc """
  Gets suggestions for next action.
  """
  @spec suggest_next() :: [action()]
  def suggest_next do
    GenServer.call(__MODULE__, :suggest_next)
  end

  @doc """
  Gets likely intent based on recent actions.
  """
  @spec likely_intent() :: {:ok, intent(), confidence()} | {:error, :uncertain}
  def likely_intent do
    GenServer.call(__MODULE__, :likely_intent)
  end

  @doc """
  Learns from a completed intent (feedback).
  """
  @spec learn(intent(), boolean()) :: :ok
  def learn(intent, was_correct) do
    GenServer.cast(__MODULE__, {:learn, intent, was_correct})
  end

  @doc """
  Gets action history.
  """
  @spec history(non_neg_integer()) :: [action_record()]
  def history(limit \\ 10) do
    GenServer.call(__MODULE__, {:history, limit})
  end

  @doc """
  Clears action history.
  """
  @spec clear_history() :: :ok
  def clear_history do
    GenServer.cast(__MODULE__, :clear_history)
  end

  @doc """
  Gets intent statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      action_history: [],
      patterns: @known_patterns,
      learned_patterns: %{},
      predictions: [],
      stats: %{
        actions_recorded: 0,
        predictions_made: 0,
        correct_predictions: 0,
        false_positives: 0
      },
      config: %{
        max_history: Keyword.get(opts, :max_history, @max_history),
        confidence_threshold: Keyword.get(opts, :confidence_threshold, @confidence_threshold),
        learning_enabled: Keyword.get(opts, :learning_enabled, true)
      }
    }

    Logger.info("🎯 Intent recognition service started")

    {:ok, state}
  end

  @impl true
  def handle_cast({:record_action, action, context}, state) do
    record = %{
      action: action,
      timestamp: DateTime.utc_now(),
      context: context,
      metadata: %{}
    }

    new_history =
      [record | state.action_history]
      |> Enum.take(state.config.max_history)

    # Trigger prediction update
    new_predictions = update_predictions(new_history, state)

    new_stats = %{state.stats | actions_recorded: state.stats.actions_recorded + 1}

    {:noreply,
     %{
       state
       | action_history: new_history,
         predictions: new_predictions,
         stats: new_stats
     }}
  end

  @impl true
  def handle_cast({:learn, intent, was_correct}, state) do
    if state.config.learning_enabled do
      # Update learned patterns
      recent_actions = get_recent_actions(state.action_history, 5)

      new_learned =
        if was_correct and length(recent_actions) >= 3 do
          existing = Map.get(state.learned_patterns, intent, [])
          updated = [recent_actions | existing] |> Enum.take(10)
          Map.put(state.learned_patterns, intent, updated)
        else
          state.learned_patterns
        end

      # Update stats
      new_stats =
        if was_correct do
          %{state.stats | correct_predictions: state.stats.correct_predictions + 1}
        else
          %{state.stats | false_positives: state.stats.false_positives + 1}
        end

      {:noreply, %{state | learned_patterns: new_learned, stats: new_stats}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:clear_history, state) do
    {:noreply, %{state | action_history: [], predictions: []}}
  end

  @impl true
  def handle_call(:predict, _from, state) do
    new_stats = %{state.stats | predictions_made: state.stats.predictions_made + 1}
    {:reply, state.predictions, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call(:suggest_next, _from, state) do
    suggestions =
      state.predictions
      |> Enum.filter(fn p -> p.confidence >= state.config.confidence_threshold end)
      |> Enum.flat_map(& &1.suggested_actions)
      |> Enum.uniq()
      |> Enum.take(5)

    {:reply, suggestions, state}
  end

  @impl true
  def handle_call(:likely_intent, _from, state) do
    case Enum.max_by(state.predictions, & &1.confidence, fn -> nil end) do
      nil ->
        {:reply, {:error, :uncertain}, state}

      prediction when prediction.confidence >= state.config.confidence_threshold ->
        {:reply, {:ok, prediction.intent, prediction.confidence}, state}

      _ ->
        {:reply, {:error, :uncertain}, state}
    end
  end

  @impl true
  def handle_call({:history, limit}, _from, state) do
    history = Enum.take(state.action_history, limit)
    {:reply, history, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    accuracy =
      if state.stats.predictions_made > 0 do
        state.stats.correct_predictions / state.stats.predictions_made
      else
        0.0
      end

    fpr =
      if state.stats.predictions_made > 0 do
        state.stats.false_positives / state.stats.predictions_made
      else
        0.0
      end

    stats =
      Map.merge(state.stats, %{
        accuracy: Float.round(accuracy, 3),
        false_positive_rate: Float.round(fpr, 3),
        history_size: length(state.action_history),
        active_predictions: length(state.predictions),
        learned_patterns: map_size(state.learned_patterns)
      })

    {:reply, stats, state}
  end

  # Private helpers

  defp get_recent_actions(history, count) do
    history
    |> Enum.take(count)
    |> Enum.map(& &1.action)
    |> Enum.reverse()
  end

  defp update_predictions(history, state) do
    recent_actions = get_recent_actions(history, 5)

    # Check known patterns
    known_matches = match_patterns(recent_actions, state.patterns)

    # Check learned patterns
    learned_matches = match_patterns(recent_actions, state.learned_patterns)

    # Statistical prediction based on frequency
    statistical = statistical_prediction(history)

    # Temporal prediction based on time patterns
    temporal = temporal_prediction(history)

    # Combine and rank predictions
    all_predictions =
      (known_matches ++ learned_matches ++ [statistical, temporal])
      |> Enum.filter(& &1)
      |> Enum.sort_by(& &1.confidence, :desc)
      |> Enum.take(5)

    all_predictions
  end

  defp match_patterns(recent_actions, patterns) do
    Enum.flat_map(patterns, fn {intent, sequences} ->
      matches =
        Enum.map(sequences, fn seq ->
          match_score = calculate_match_score(recent_actions, seq)

          if match_score > 0.3 do
            next_action = predict_next_in_sequence(recent_actions, seq)

            %{
              intent: intent,
              confidence: match_score,
              suggested_actions: [next_action] |> Enum.filter(& &1),
              reasoning: "Matches #{intent} pattern"
            }
          else
            nil
          end
        end)

      Enum.filter(matches, & &1)
    end)
  end

  defp calculate_match_score(recent, pattern) do
    if recent == [] or pattern == [] do
      0.0
    else
      # Calculate overlap
      pattern_set = MapSet.new(pattern)
      recent_set = MapSet.new(recent)

      intersection = MapSet.intersection(pattern_set, recent_set)
      union = MapSet.union(pattern_set, recent_set)

      if MapSet.size(union) > 0 do
        MapSet.size(intersection) / MapSet.size(union)
      else
        0.0
      end
    end
  end

  defp predict_next_in_sequence(recent, pattern) do
    # Find where we are in the pattern
    last_action = List.first(recent)

    case Enum.find_index(pattern, &(&1 == last_action)) do
      nil -> nil
      idx when idx < length(pattern) - 1 -> Enum.at(pattern, idx + 1)
      _ -> nil
    end
  end

  defp statistical_prediction(history) do
    if length(history) < 5 do
      nil
    else
      # Calculate action frequencies
      frequencies =
        history
        |> Enum.map(& &1.action)
        |> Enum.frequencies()

      # Find most common action
      {most_common, count} = Enum.max_by(frequencies, fn {_, c} -> c end, fn -> {nil, 0} end)

      if most_common && count > 2 do
        %{
          intent: :repeat,
          confidence: min(count / length(history), 0.8),
          suggested_actions: [most_common],
          reasoning: "Frequently used action"
        }
      else
        nil
      end
    end
  end

  defp temporal_prediction(history) do
    if length(history) < 3 do
      nil
    else
      # Check for time-based patterns (e.g., same action at similar times)
      now = DateTime.utc_now()
      current_hour = now.hour

      # Find actions done at similar times
      similar_time_actions =
        history
        |> Enum.filter(fn record ->
          abs(record.timestamp.hour - current_hour) <= 1
        end)
        |> Enum.map(& &1.action)
        |> Enum.frequencies()

      if map_size(similar_time_actions) > 0 do
        {action, count} = Enum.max_by(similar_time_actions, fn {_, c} -> c end)

        if count >= 2 do
          %{
            intent: :scheduled,
            confidence: min(count / 5, 0.6),
            suggested_actions: [action],
            reasoning: "Typically done at this time"
          }
        else
          nil
        end
      else
        nil
      end
    end
  end
end
