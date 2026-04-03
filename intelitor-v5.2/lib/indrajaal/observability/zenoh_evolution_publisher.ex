defmodule Indrajaal.Observability.ZenohEvolutionPublisher do
  @moduledoc """
  Zenoh Publisher for Evolution Components (ShadowMode, TrainingGym).

  WHAT: Bridges Evolution subsystem events to Zenoh neural streams.
  WHY: SC-ZENOH-EVO-001 requires real-time visibility into AI model evolution.
  CONSTRAINTS: Async publishing, no blocking on production path.

  ## Key Expressions

  ```
  indrajaal/evolution/shadow/<shadow_id>/execution  - Shadow model executions
  indrajaal/evolution/shadow/<shadow_id>/comparison - Production comparisons
  indrajaal/evolution/shadow/<shadow_id>/promotion  - Promotion events
  indrajaal/evolution/gym/episode/<type>           - Training episodes
  indrajaal/evolution/gym/stats                    - GYM statistics
  indrajaal/evolution/guardian/validation          - Guardian validations
  indrajaal/evolution/openrouter/call              - OpenRouter API calls
  ```

  ## STAMP Constraints

  - SC-ZENOH-EVO-001: All evolution events published to Zenoh
  - SC-ZENOH-EVO-002: Latency < 100ms (non-blocking)
  - SC-ZENOH-EVO-003: Episode buffering for batch efficiency

  ## Integration Points

  - TrainingGym: Subscribes to episode events
  - ShadowMode: Hooks into execution/comparison/promotion
  - Guardian: Captures validation decisions
  - OpenRouter: Tracks AI API calls

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-ZENOH-EVO-001 to SC-ZENOH-EVO-003 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Cortex.Evolution.{ShadowMode, TrainingGym}
  alias Indrajaal.Observability.ZenohNeuralStream

  # ============================================================
  # CONSTANTS
  # ============================================================

  @evolution_prefix "indrajaal/evolution"
  @publish_interval_ms 5_000
  @episode_buffer_size 50
  @shadow_key_prefix "#{@evolution_prefix}/shadow"
  @gym_key_prefix "#{@evolution_prefix}/gym"
  @guardian_key_prefix "#{@evolution_prefix}/guardian"
  @openrouter_key_prefix "#{@evolution_prefix}/openrouter"

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Publish a shadow model execution event.
  """
  @spec publish_shadow_execution(term(), String.t(), map()) :: :ok
  def publish_shadow_execution(pid \\ __MODULE__, shadow_id, execution_result) do
    GenServer.cast(pid, {:shadow_execution, shadow_id, execution_result})
  end

  @doc """
  Publish a shadow model comparison with production.
  """
  @spec publish_shadow_comparison(term(), String.t(), map()) :: :ok
  def publish_shadow_comparison(pid \\ __MODULE__, shadow_id, comparison_result) do
    GenServer.cast(pid, {:shadow_comparison, shadow_id, comparison_result})
  end

  @doc """
  Publish a shadow model promotion event.
  """
  @spec publish_shadow_promotion(term(), String.t(), map()) :: :ok
  def publish_shadow_promotion(pid \\ __MODULE__, shadow_id, promotion_result) do
    GenServer.cast(pid, {:shadow_promotion, shadow_id, promotion_result})
  end

  @doc """
  Publish a training episode to Zenoh.
  """
  @spec publish_training_episode(term(), map()) :: :ok
  def publish_training_episode(pid \\ __MODULE__, episode) do
    GenServer.cast(pid, {:training_episode, episode})
  end

  @doc """
  Publish a Guardian validation event.
  """
  @spec publish_guardian_validation(term(), map(), atom(), map()) :: :ok
  def publish_guardian_validation(pid \\ __MODULE__, proposal, result, details) do
    GenServer.cast(pid, {:guardian_validation, proposal, result, details})
  end

  @doc """
  Publish an OpenRouter API call event.
  """
  @spec publish_openrouter_call(term(), String.t(), integer(), integer(), boolean()) :: :ok
  def publish_openrouter_call(pid \\ __MODULE__, model, tokens, latency_ms, success) do
    GenServer.cast(pid, {:openrouter_call, model, tokens, latency_ms, success})
  end

  @doc """
  Get current publisher statistics.
  """
  @spec stats(term()) :: map()
  def stats(pid \\ __MODULE__), do: GenServer.call(pid, :stats)

  @doc """
  Force immediate publish of all buffered events.
  """
  @spec flush(term()) :: :ok
  def flush(pid \\ __MODULE__), do: GenServer.call(pid, :flush)

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    Logger.info("[ZenohEvolutionPublisher] Starting - SC-ZENOH-EVO-001 active")
    coordinator = Keyword.get(opts, :coordinator)

    state = %{
      # Configuration
      publish_interval_ms: Keyword.get(opts, :publish_interval_ms, @publish_interval_ms),
      episode_buffer_size: Keyword.get(opts, :episode_buffer_size, @episode_buffer_size),
      coordinator: coordinator,

      # Buffers
      episode_buffer: [],
      shadow_events_buffer: [],
      guardian_events_buffer: [],
      openrouter_events_buffer: [],

      # Statistics
      shadow_executions_published: 0,
      shadow_comparisons_published: 0,
      shadow_promotions_published: 0,
      episodes_published: 0,
      guardian_validations_published: 0,
      openrouter_calls_published: 0,
      publish_count: 0,
      last_publish: nil,
      started_at: DateTime.utc_now()
    }

    # Subscribe to TrainingGym events if available
    subscribe_to_training_gym()

    # Schedule periodic publish
    schedule_publish(state.publish_interval_ms)

    {:ok, state}
  end

  @impl true
  def handle_cast({:shadow_execution, shadow_id, result}, state) do
    event = %{
      type: :execution,
      shadow_id: shadow_id,
      result: result,
      timestamp: DateTime.utc_now()
    }

    # Publish immediately (shadow events are important)
    publish_to_zenoh("#{@shadow_key_prefix}/#{shadow_id}/execution", event, state)

    new_state = %{state | shadow_executions_published: state.shadow_executions_published + 1}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:shadow_comparison, shadow_id, result}, state) do
    event = %{
      type: :comparison,
      shadow_id: shadow_id,
      result: result,
      timestamp: DateTime.utc_now()
    }

    publish_to_zenoh("#{@shadow_key_prefix}/#{shadow_id}/comparison", event, state)

    new_state = %{state | shadow_comparisons_published: state.shadow_comparisons_published + 1}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:shadow_promotion, shadow_id, result}, state) do
    event = %{
      type: :promotion,
      shadow_id: shadow_id,
      result: result,
      timestamp: DateTime.utc_now()
    }

    # Promotion events are critical - publish and log
    publish_to_zenoh("#{@shadow_key_prefix}/#{shadow_id}/promotion", event, state)
    Logger.info("[ZenohEvolutionPublisher] Shadow promotion: #{shadow_id} - #{inspect(result)}")

    new_state = %{state | shadow_promotions_published: state.shadow_promotions_published + 1}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:training_episode, episode}, state) do
    # Buffer episodes for batch publishing
    new_buffer = [episode | state.episode_buffer]

    new_state =
      if length(new_buffer) >= state.episode_buffer_size do
        flush_episode_buffer(%{state | episode_buffer: new_buffer})
      else
        %{state | episode_buffer: new_buffer}
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:guardian_validation, proposal, result, details}, state) do
    event = %{
      proposal: sanitize_proposal(proposal),
      result: result,
      details: details,
      timestamp: DateTime.utc_now()
    }

    # Buffer guardian events
    new_buffer = [event | state.guardian_events_buffer]

    new_state =
      if length(new_buffer) >= 10 do
        flush_guardian_buffer(%{state | guardian_events_buffer: new_buffer})
      else
        %{state | guardian_events_buffer: new_buffer}
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:openrouter_call, model, tokens, latency_ms, success}, state) do
    event = %{
      model: model,
      tokens: tokens,
      latency_ms: latency_ms,
      success: success,
      timestamp: DateTime.utc_now()
    }

    # Buffer OpenRouter events
    new_buffer = [event | state.openrouter_events_buffer]

    new_state =
      if length(new_buffer) >= 5 do
        flush_openrouter_buffer(%{state | openrouter_events_buffer: new_buffer})
      else
        %{state | openrouter_events_buffer: new_buffer}
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      shadow_executions_published: state.shadow_executions_published,
      shadow_comparisons_published: state.shadow_comparisons_published,
      shadow_promotions_published: state.shadow_promotions_published,
      episodes_published: state.episodes_published,
      guardian_validations_published: state.guardian_validations_published,
      openrouter_calls_published: state.openrouter_calls_published,
      publish_count: state.publish_count,
      last_publish: state.last_publish,
      episode_buffer_size: length(state.episode_buffer),
      guardian_buffer_size: length(state.guardian_events_buffer),
      openrouter_buffer_size: length(state.openrouter_events_buffer),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    new_state =
      state
      |> flush_episode_buffer()
      |> flush_guardian_buffer()
      |> flush_openrouter_buffer()
      |> publish_aggregated_stats()

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:publish, state) do
    new_state =
      state
      |> flush_episode_buffer()
      |> flush_guardian_buffer()
      |> flush_openrouter_buffer()
      |> publish_aggregated_stats()

    schedule_publish(state.publish_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:training_gym_episode, episode}, state) do
    # Handle events from TrainingGym subscription
    new_buffer = [episode | state.episode_buffer]

    new_state =
      if length(new_buffer) >= state.episode_buffer_size do
        flush_episode_buffer(%{state | episode_buffer: new_buffer})
      else
        %{state | episode_buffer: new_buffer}
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp subscribe_to_training_gym do
    # Subscribe to TrainingGym events if available
    case GenServer.whereis(TrainingGym) do
      nil ->
        Logger.debug("[ZenohEvolutionPublisher] TrainingGym not running, skipping subscription")

      _pid ->
        TrainingGym.subscribe()
        Logger.info("[ZenohEvolutionPublisher] Subscribed to TrainingGym events")
    end
  rescue
    _ -> :ok
  end

  defp schedule_publish(interval_ms) do
    Process.send_after(self(), :publish, interval_ms)
  end

  defp flush_episode_buffer(%{episode_buffer: []} = state), do: state

  defp flush_episode_buffer(state) do
    # Group episodes by type
    grouped =
      state.episode_buffer
      |> Enum.reverse()
      |> Enum.group_by(fn ep -> ep[:type] || :unknown end)

    # Publish each group
    Enum.each(grouped, fn {type, episodes} ->
      payload = %{
        type: type,
        count: length(episodes),
        episodes: Enum.map(episodes, &sanitize_episode/1),
        batch_timestamp: DateTime.utc_now()
      }

      publish_to_zenoh("#{@gym_key_prefix}/episode/#{type}", payload, state)
    end)

    count = length(state.episode_buffer)

    %{
      state
      | episode_buffer: [],
        episodes_published: state.episodes_published + count
    }
  end

  defp flush_guardian_buffer(%{guardian_events_buffer: []} = state), do: state

  defp flush_guardian_buffer(state) do
    payload = %{
      count: length(state.guardian_events_buffer),
      events: Enum.reverse(state.guardian_events_buffer),
      batch_timestamp: DateTime.utc_now()
    }

    publish_to_zenoh("#{@guardian_key_prefix}/validations", payload, state)

    count = length(state.guardian_events_buffer)

    %{
      state
      | guardian_events_buffer: [],
        guardian_validations_published: state.guardian_validations_published + count
    }
  end

  defp flush_openrouter_buffer(%{openrouter_events_buffer: []} = state), do: state

  defp flush_openrouter_buffer(state) do
    events = Enum.reverse(state.openrouter_events_buffer)

    # Calculate aggregates
    total_tokens = Enum.reduce(events, 0, fn e, acc -> acc + (e.tokens || 0) end)
    avg_latency = calculate_avg_latency(events)
    success_rate = calculate_success_rate(events)

    payload = %{
      count: length(events),
      total_tokens: total_tokens,
      avg_latency_ms: avg_latency,
      success_rate: success_rate,
      events: events,
      batch_timestamp: DateTime.utc_now()
    }

    publish_to_zenoh("#{@openrouter_key_prefix}/calls", payload, state)

    count = length(state.openrouter_events_buffer)

    %{
      state
      | openrouter_events_buffer: [],
        openrouter_calls_published: state.openrouter_calls_published + count
    }
  end

  defp publish_aggregated_stats(state) do
    # Collect stats from ShadowMode and TrainingGym if available
    shadow_stats = collect_shadow_stats()
    gym_stats = collect_gym_stats()

    payload = %{
      shadow_mode: shadow_stats,
      training_gym: gym_stats,
      publisher: %{
        shadow_executions: state.shadow_executions_published,
        shadow_comparisons: state.shadow_comparisons_published,
        shadow_promotions: state.shadow_promotions_published,
        episodes: state.episodes_published,
        guardian_validations: state.guardian_validations_published,
        openrouter_calls: state.openrouter_calls_published
      },
      timestamp: DateTime.utc_now()
    }

    publish_to_zenoh("#{@evolution_prefix}/stats", payload, state)

    %{
      state
      | publish_count: state.publish_count + 1,
        last_publish: DateTime.utc_now()
    }
  end

  defp collect_shadow_stats do
    case GenServer.whereis(ShadowMode) do
      nil -> %{available: false}
      _pid -> Map.put(ShadowMode.stats(), :available, true)
    end
  rescue
    _ -> %{available: false, error: :collection_failed}
  end

  defp collect_gym_stats do
    case GenServer.whereis(TrainingGym) do
      nil -> %{available: false}
      _pid -> Map.put(TrainingGym.stats(), :available, true)
    end
  rescue
    _ -> %{available: false, error: :collection_failed}
  end

  defp sanitize_episode(episode) do
    # Remove potentially large or sensitive data
    episode
    |> Map.take([:id, :type, :timestamp, :reward, :metadata])
    |> Map.update(:metadata, %{}, fn m -> Map.take(m, [:model_id, :node]) end)
  end

  defp sanitize_proposal(proposal) when is_map(proposal) do
    # Remove sensitive data from proposals
    proposal
    |> Map.drop([:password, :token, :secret, :api_key])
    |> Map.take([:action, :target, :source])
  end

  defp sanitize_proposal(proposal), do: proposal

  defp calculate_avg_latency([]), do: 0.0

  defp calculate_avg_latency(events) do
    sum = Enum.reduce(events, 0, fn e, acc -> acc + (e.latency_ms || 0) end)
    Float.round(sum / length(events), 2)
  end

  defp calculate_success_rate([]), do: 100.0

  defp calculate_success_rate(events) do
    successes = Enum.count(events, fn e -> e.success end)
    Float.round(successes / length(events) * 100, 2)
  end

  defp publish_to_zenoh(key, payload, state) do
    if state.coordinator do
      zenoh_test_module().publish(state.coordinator, key, payload)
    else
      # Use ZenohNeuralStream if available
      if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
        # Stream as state update
        ZenohNeuralStream.stream_state(:evolution, String.to_atom(key), payload)
      else
        # Fallback: Log at debug level
        Logger.debug("[ZenohEvolutionPublisher] Would publish to #{key}")
      end
    end
  rescue
    e ->
      Logger.warning("[ZenohEvolutionPublisher] Publish failed: #{inspect(e)}")
  end

  # Runtime module reference to avoid compile-time warnings for test-only module
  defp zenoh_test_module, do: Module.concat([Indrajaal, Test, ZenohTestCoordinator])
end
