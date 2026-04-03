defmodule Indrajaal.Cortex.Evolution.TrainingGym do
  @moduledoc """
  Training GYM - Data Capture for Reinforcement Learning.

  WHAT: Captures "Near Miss" (Guardian Veto) and "Success" events for RL training.
  WHY: SC-TRAIN-001 requires systematic capture of training episodes.
  CONSTRAINTS: Must not impact production performance. Async logging only.

  ## Architecture

  The Training GYM operates as a passive observer that:
  1. Subscribes to Guardian events (vetoes, validations)
  2. Captures Shadow Mode execution results
  3. Logs to Zenoh for downstream ML training pipelines
  4. Maintains episode buffers for batch processing

  ## Episode Types

  - **NEAR_MISS**: Guardian vetoed an action (negative reward signal)
  - **SUCCESS**: Action passed validation (positive reward signal)
  - **SHADOW_DIVERGE**: Shadow model diverged from production
  - **SHADOW_AGREE**: Shadow model agreed with production

  ## STAMP Compliance

  - SC-TRAIN-001: Async capture only (no blocking)
  - SC-TRAIN-002: Episode buffer < 10,000 entries
  - SC-TRAIN-003: Automatic batch flush every 60s
  - SC-TRAIN-004: Data anonymization for PII

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-TRAIN-001 to SC-TRAIN-004 |
  """

  use GenServer

  require Logger

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Observability.ZenohEvolutionPublisher

  # ============================================================
  # TYPES
  # ============================================================

  @type episode_type :: :near_miss | :success | :shadow_diverge | :shadow_agree

  @type episode :: %{
          id: String.t(),
          type: episode_type(),
          timestamp: DateTime.t(),
          context: map(),
          state_before: map(),
          action: map(),
          result: map(),
          reward: float(),
          metadata: map()
        }

  @type gym_state :: %{
          episodes: list(episode()),
          episode_count: non_neg_integer(),
          near_miss_count: non_neg_integer(),
          success_count: non_neg_integer(),
          last_flush: DateTime.t() | nil,
          flush_timer: reference() | nil,
          subscribers: list(pid())
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @max_buffer_size 10_000
  @flush_interval_ms 60_000
  @reward_near_miss -1.0
  @reward_success 1.0
  @reward_shadow_diverge -0.5
  @reward_shadow_agree 0.5

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Start the Training GYM GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record a Guardian veto (near-miss).
  """
  @spec record_near_miss(map(), map(), map()) :: :ok
  def record_near_miss(state_before, action, veto_reason) do
    GenServer.cast(__MODULE__, {:record, :near_miss, state_before, action, veto_reason})
  end

  @doc """
  Record a successful action.
  """
  @spec record_success(map(), map(), map()) :: :ok
  def record_success(state_before, action, result) do
    GenServer.cast(__MODULE__, {:record, :success, state_before, action, result})
  end

  @doc """
  Record shadow model divergence.
  """
  @spec record_shadow_diverge(String.t(), map(), map(), map()) :: :ok
  def record_shadow_diverge(model_id, context, production_action, shadow_action) do
    GenServer.cast(
      __MODULE__,
      {:record_shadow, :diverge, model_id, context, production_action, shadow_action}
    )
  end

  @doc """
  Record shadow model agreement.
  """
  @spec record_shadow_agree(String.t(), map(), map()) :: :ok
  def record_shadow_agree(model_id, context, action) do
    GenServer.cast(__MODULE__, {:record_shadow, :agree, model_id, context, action, action})
  end

  @doc """
  Get current GYM statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Get buffered episodes (for training).
  """
  @spec get_episodes(non_neg_integer()) :: list(episode())
  def get_episodes(limit \\ 100) do
    GenServer.call(__MODULE__, {:get_episodes, limit})
  end

  @doc """
  Force flush episodes to storage.
  """
  @spec flush() :: {:ok, non_neg_integer()} | {:error, term()}
  def flush do
    GenServer.call(__MODULE__, :flush)
  end

  @doc """
  Subscribe to episode events.
  """
  @spec subscribe() :: :ok
  def subscribe do
    GenServer.cast(__MODULE__, {:subscribe, self()})
  end

  @doc """
  Unsubscribe from episode events.
  """
  @spec unsubscribe() :: :ok
  def unsubscribe do
    GenServer.cast(__MODULE__, {:unsubscribe, self()})
  end

  @doc """
  Export episodes for ML training.
  """
  @spec export_training_data(keyword()) :: {:ok, list(map())} | {:error, term()}
  def export_training_data(opts \\ []) do
    GenServer.call(__MODULE__, {:export, opts})
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    state = %{
      episodes: [],
      episode_count: 0,
      near_miss_count: 0,
      success_count: 0,
      shadow_diverge_count: 0,
      shadow_agree_count: 0,
      last_flush: nil,
      flush_timer: schedule_flush(),
      subscribers: []
    }

    Logger.info("[TrainingGym] Started - Buffer size: #{@max_buffer_size}")

    {:ok, state}
  end

  @impl true
  def handle_cast({:record, type, state_before, action, result}, state) do
    episode = build_episode(type, state_before, action, result)
    new_state = add_episode(state, episode)
    notify_subscribers(new_state.subscribers, episode)
    {:noreply, maybe_auto_flush(new_state)}
  end

  def handle_cast(
        {:record_shadow, diverge_or_agree, model_id, context, prod_action, shadow_action},
        state
      ) do
    type = if diverge_or_agree == :diverge, do: :shadow_diverge, else: :shadow_agree

    episode = build_shadow_episode(type, model_id, context, prod_action, shadow_action)
    new_state = add_episode(state, episode)
    notify_subscribers(new_state.subscribers, episode)
    {:noreply, maybe_auto_flush(new_state)}
  end

  def handle_cast({:subscribe, pid}, state) do
    {:noreply, %{state | subscribers: [pid | state.subscribers]}}
  end

  def handle_cast({:unsubscribe, pid}, state) do
    {:noreply, %{state | subscribers: List.delete(state.subscribers, pid)}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      episode_count: state.episode_count,
      near_miss_count: state.near_miss_count,
      success_count: state.success_count,
      shadow_diverge_count: state.shadow_diverge_count,
      shadow_agree_count: state.shadow_agree_count,
      buffer_size: length(state.episodes),
      buffer_utilization: Float.round(length(state.episodes) / @max_buffer_size * 100, 2),
      last_flush: state.last_flush,
      reward_balance: calculate_reward_balance(state)
    }

    {:reply, stats, state}
  end

  def handle_call({:get_episodes, limit}, _from, state) do
    episodes = Enum.take(state.episodes, limit)
    {:reply, episodes, state}
  end

  def handle_call(:flush, _from, state) do
    {:ok, count, new_state} = do_flush(state)
    {:reply, {:ok, count}, new_state}
  end

  def handle_call({:export, opts}, _from, state) do
    training_data = prepare_training_data(state.episodes, opts)
    {:reply, {:ok, training_data}, state}
  end

  @impl true
  def handle_info(:flush_timer, state) do
    {:ok, count, new_state} = do_flush(state)
    Logger.debug("[TrainingGym] Auto-flushed #{count} episodes")
    {:noreply, %{new_state | flush_timer: schedule_flush()}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | subscribers: List.delete(state.subscribers, pid)}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp build_episode(type, state_before, action, result) do
    %{
      id: generate_episode_id(),
      type: type,
      timestamp: DateTime.utc_now(),
      context: extract_context(),
      state_before: anonymize_pii(state_before),
      action: anonymize_pii(action),
      result: anonymize_pii(result),
      reward: reward_for_type(type),
      metadata: %{
        guardian_running: guardian_running?(),
        node: node()
      }
    }
  end

  defp build_shadow_episode(type, model_id, context, prod_action, shadow_action) do
    %{
      id: generate_episode_id(),
      type: type,
      timestamp: DateTime.utc_now(),
      context: anonymize_pii(context),
      state_before: %{model_id: model_id},
      action: %{
        production: anonymize_pii(prod_action),
        shadow: anonymize_pii(shadow_action)
      },
      result: %{
        diverged: type == :shadow_diverge,
        similarity: calculate_similarity(prod_action, shadow_action)
      },
      reward: reward_for_type(type),
      metadata: %{
        model_id: model_id,
        node: node()
      }
    }
  end

  defp add_episode(state, episode) do
    type_count_key =
      case episode.type do
        :near_miss -> :near_miss_count
        :success -> :success_count
        :shadow_diverge -> :shadow_diverge_count
        :shadow_agree -> :shadow_agree_count
      end

    # SC-ZENOH-EVO-001: Publish episode to Zenoh
    publish_to_zenoh(episode)

    %{
      state
      | episodes: [episode | state.episodes],
        episode_count: state.episode_count + 1
    }
    |> Map.update!(type_count_key, &(&1 + 1))
  end

  defp maybe_auto_flush(state) do
    if length(state.episodes) >= @max_buffer_size do
      {:ok, _count, new_state} = do_flush(state)
      new_state
    else
      state
    end
  end

  defp do_flush(state) do
    count = length(state.episodes)

    if count > 0 do
      # Log to Zenoh (async, non-blocking)
      spawn(fn -> persist_episodes(state.episodes) end)

      new_state = %{
        state
        | episodes: [],
          last_flush: DateTime.utc_now()
      }

      {:ok, count, new_state}
    else
      {:ok, 0, state}
    end
  end

  defp persist_episodes(episodes) do
    # Would write to Zenoh neural stream
    # For now, log to file as fallback
    log_path = "./data/training_gym/episodes_#{:os.system_time(:second)}.json"

    case File.mkdir_p(Path.dirname(log_path)) do
      :ok ->
        data = Jason.encode!(Enum.map(episodes, &episode_to_json/1), pretty: true)
        File.write!(log_path, data)
        Logger.debug("[TrainingGym] Persisted #{length(episodes)} episodes to #{log_path}")

      {:error, reason} ->
        Logger.warning("[TrainingGym] Failed to create directory: #{inspect(reason)}")
    end
  rescue
    error ->
      Logger.warning("[TrainingGym] Persist error: #{inspect(error)}")
  end

  defp episode_to_json(episode) do
    %{
      id: episode.id,
      type: Atom.to_string(episode.type),
      timestamp: DateTime.to_iso8601(episode.timestamp),
      context: episode.context,
      state_before: episode.state_before,
      action: episode.action,
      result: episode.result,
      reward: episode.reward,
      metadata: episode.metadata
    }
  end

  defp prepare_training_data(episodes, opts) do
    type_filter = Keyword.get(opts, :type, :all)
    min_reward = Keyword.get(opts, :min_reward, nil)

    episodes
    |> Enum.filter(fn ep ->
      type_match = type_filter == :all or ep.type == type_filter
      reward_match = is_nil(min_reward) or ep.reward >= min_reward
      type_match and reward_match
    end)
    |> Enum.map(&format_for_training/1)
  end

  defp format_for_training(episode) do
    %{
      observation: episode.state_before,
      action: episode.action,
      reward: episode.reward,
      done: episode.type in [:near_miss, :success],
      info: %{
        episode_id: episode.id,
        type: episode.type,
        timestamp: episode.timestamp
      }
    }
  end

  defp reward_for_type(:near_miss), do: @reward_near_miss
  defp reward_for_type(:success), do: @reward_success
  defp reward_for_type(:shadow_diverge), do: @reward_shadow_diverge
  defp reward_for_type(:shadow_agree), do: @reward_shadow_agree

  defp calculate_reward_balance(state) do
    positive =
      state.success_count * @reward_success + state.shadow_agree_count * @reward_shadow_agree

    negative =
      state.near_miss_count * @reward_near_miss +
        state.shadow_diverge_count * @reward_shadow_diverge

    positive + negative
  end

  defp schedule_flush do
    Process.send_after(self(), :flush_timer, @flush_interval_ms)
  end

  defp generate_episode_id do
    "ep_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  defp extract_context do
    %{
      memory_mb: div(:erlang.memory(:total), 1_048_576),
      process_count: :erlang.system_info(:process_count),
      run_queue: :erlang.statistics(:run_queue)
    }
  end

  defp guardian_running? do
    case GenServer.whereis(Guardian) do
      nil -> false
      _pid -> true
    end
  end

  # Anonymize PII fields - skip structs (DateTime, etc.) which are maps but not enumerable
  defp anonymize_pii(data) when is_struct(data), do: data

  defp anonymize_pii(data) when is_map(data) do
    data
    |> Map.drop([:password, :token, :secret, :api_key, :credit_card])
    |> Enum.map(fn
      {:email, _} -> {:email, "[REDACTED]"}
      {:phone, _} -> {:phone, "[REDACTED]"}
      {:ssn, _} -> {:ssn, "[REDACTED]"}
      {k, v} when is_map(v) and not is_struct(v) -> {k, anonymize_pii(v)}
      pair -> pair
    end)
    |> Enum.into(%{})
  end

  defp anonymize_pii(data), do: data

  defp calculate_similarity(action1, action2) when is_map(action1) and is_map(action2) do
    keys1 = MapSet.new(Map.keys(action1))
    keys2 = MapSet.new(Map.keys(action2))
    common_keys = MapSet.intersection(keys1, keys2)

    if MapSet.size(common_keys) == 0 do
      0.0
    else
      matching =
        Enum.count(common_keys, fn k ->
          Map.get(action1, k) == Map.get(action2, k)
        end)

      matching / MapSet.size(common_keys)
    end
  end

  defp calculate_similarity(a, a), do: 1.0
  defp calculate_similarity(_, _), do: 0.0

  defp notify_subscribers(subscribers, episode) do
    Enum.each(subscribers, fn pid ->
      send(pid, {:training_gym_episode, episode})
    end)
  end

  # ============================================================
  # ZENOH INTEGRATION (SC-ZENOH-EVO-001)
  # ============================================================

  defp publish_to_zenoh(episode) do
    # Async publish to Zenoh via ZenohEvolutionPublisher
    if Code.ensure_loaded?(ZenohEvolutionPublisher) and
         GenServer.whereis(ZenohEvolutionPublisher) do
      ZenohEvolutionPublisher.publish_training_episode(episode)
    end
  rescue
    _ -> :ok
  end
end
