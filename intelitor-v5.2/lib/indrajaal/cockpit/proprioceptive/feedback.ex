defmodule Indrajaal.Cockpit.Proprioceptive.Feedback do
  @moduledoc """
  Feedback System - Multimodal User Feedback for v20.0.0

  Implements comprehensive feedback generation:
  - Visual feedback (colors, animations)
  - Audio feedback (tones, speech)
  - Haptic patterns (for supported devices)
  - Contextual notifications

  ## Feedback Model

  Feedback = Response × Urgency × Modality

  Where:
  - Response type determines content
  - Urgency determines intensity
  - Modality determines channel(s)

  ## Feedback Types
  - **Confirmation**: Action succeeded
  - **Warning**: Potential issue
  - **Error**: Action failed
  - **Progress**: Ongoing operation
  - **Alert**: Requires attention

  ## STAMP Constraints
  - SC-FBK-001: Feedback latency < 100ms
  - SC-FBK-002: Critical feedback MUST be multimodal
  - SC-FBK-003: Feedback MUST be dismissible
  - SC-FBK-004: No feedback spam (rate limited)
  """

  use GenServer
  require Logger

  @type feedback_type :: :confirmation | :warning | :error | :progress | :alert | :info
  @type urgency :: :low | :medium | :high | :critical
  @type modality :: :visual | :audio | :haptic | :notification

  @type feedback :: %{
          id: String.t(),
          type: feedback_type(),
          message: String.t(),
          urgency: urgency(),
          modalities: [modality()],
          timestamp: DateTime.t(),
          duration: non_neg_integer() | :persistent,
          dismissed: boolean(),
          metadata: map()
        }

  @type state :: %{
          active: [feedback()],
          history: [feedback()],
          config: map()
        }

  # Visual patterns (colors, durations)
  @visual_patterns %{
    confirmation: %{color: {0, 200, 0}, animation: :pulse, duration: 2000},
    warning: %{color: {255, 200, 0}, animation: :blink, duration: 5000},
    error: %{color: {255, 50, 50}, animation: :shake, duration: 0},
    progress: %{color: {0, 150, 255}, animation: :spin, duration: 0},
    alert: %{color: {255, 0, 0}, animation: :flash, duration: 0},
    info: %{color: {100, 100, 100}, animation: :fade, duration: 3000}
  }

  # Audio patterns (frequency, duration, pattern)
  @audio_patterns %{
    confirmation: %{frequency: 880, duration: 100, pattern: [1]},
    warning: %{frequency: 440, duration: 200, pattern: [1, 0, 1]},
    error: %{frequency: 220, duration: 300, pattern: [1, 1, 1]},
    alert: %{frequency: 660, duration: 500, pattern: [1, 0, 1, 0, 1]}
  }

  # Haptic patterns (intensity, duration, pattern)
  @haptic_patterns %{
    confirmation: %{intensity: 0.3, duration: 50, pattern: [1]},
    warning: %{intensity: 0.5, duration: 100, pattern: [1, 0, 1]},
    error: %{intensity: 0.8, duration: 150, pattern: [1, 1]},
    alert: %{intensity: 1.0, duration: 200, pattern: [1, 0, 1, 0, 1]}
  }

  # Rate limiting
  @min_interval_ms 500
  @max_active 10

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sends feedback to user.
  """
  @spec send(feedback_type(), String.t(), Keyword.t()) :: {:ok, String.t()} | {:error, term()}
  def send(type, message, opts \\ []) do
    GenServer.call(__MODULE__, {:send, type, message, opts})
  end

  @doc """
  Sends confirmation feedback.
  """
  @spec confirm(String.t()) :: {:ok, String.t()}
  def confirm(message) do
    send(:confirmation, message, urgency: :low)
  end

  @doc """
  Sends warning feedback.
  """
  @spec warn(String.t()) :: {:ok, String.t()}
  def warn(message) do
    send(:warning, message, urgency: :medium)
  end

  @doc """
  Sends error feedback.
  """
  @spec error(String.t()) :: {:ok, String.t()}
  def error(message) do
    send(:error, message, urgency: :high)
  end

  @doc """
  Sends alert feedback.
  """
  @spec alert(String.t()) :: {:ok, String.t()}
  def alert(message) do
    send(:alert, message, urgency: :critical)
  end

  @doc """
  Sends progress feedback.
  """
  @spec progress(String.t(), float()) :: {:ok, String.t()}
  def progress(message, percentage \\ 0.0) do
    send(:progress, message, urgency: :low, metadata: %{progress: percentage})
  end

  @doc """
  Updates progress feedback.
  """
  @spec update_progress(String.t(), float()) :: :ok | {:error, :not_found}
  def update_progress(feedback_id, percentage) do
    GenServer.call(__MODULE__, {:update_progress, feedback_id, percentage})
  end

  @doc """
  Dismisses a feedback.
  """
  @spec dismiss(String.t()) :: :ok | {:error, :not_found}
  def dismiss(feedback_id) do
    GenServer.call(__MODULE__, {:dismiss, feedback_id})
  end

  @doc """
  Dismisses all active feedback.
  """
  @spec dismiss_all() :: :ok
  def dismiss_all do
    GenServer.cast(__MODULE__, :dismiss_all)
  end

  @doc """
  Gets active feedback.
  """
  @spec active() :: [feedback()]
  def active do
    GenServer.call(__MODULE__, :active)
  end

  @doc """
  Gets feedback history.
  """
  @spec history(non_neg_integer()) :: [feedback()]
  def history(limit \\ 50) do
    GenServer.call(__MODULE__, {:history, limit})
  end

  @doc """
  Renders feedback as JSON for web UI.
  """
  @spec render_json() :: map()
  def render_json do
    GenServer.call(__MODULE__, :render_json)
  end

  @doc """
  Gets feedback statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      active: [],
      history: [],
      last_feedback_at: nil,
      stats: %{
        sent: 0,
        dismissed: 0,
        by_type: %{},
        by_urgency: %{}
      },
      config: %{
        enabled_modalities: Keyword.get(opts, :modalities, [:visual, :notification]),
        rate_limit_ms: Keyword.get(opts, :rate_limit_ms, @min_interval_ms),
        max_active: Keyword.get(opts, :max_active, @max_active),
        auto_dismiss: Keyword.get(opts, :auto_dismiss, true)
      }
    }

    Logger.info("📢 Feedback system started")

    {:ok, state}
  end

  @impl true
  def handle_call({:send, type, message, opts}, _from, state) do
    # Rate limiting
    if rate_limited?(state) do
      {:reply, {:error, :rate_limited}, state}
    else
      urgency = Keyword.get(opts, :urgency, default_urgency(type))
      modalities = determine_modalities(type, urgency, state.config)

      feedback = %{
        id: generate_id(),
        type: type,
        message: message,
        urgency: urgency,
        modalities: modalities,
        timestamp: DateTime.utc_now(),
        duration: get_duration(type, opts),
        dismissed: false,
        metadata: Keyword.get(opts, :metadata, %{})
      }

      # Execute feedback on each modality
      execute_feedback(feedback, state.config)

      # Add to active list
      new_active =
        [feedback | state.active]
        |> Enum.take(state.config.max_active)

      # Schedule auto-dismiss if duration > 0
      if is_integer(feedback.duration) and feedback.duration > 0 and state.config.auto_dismiss do
        Process.send_after(self(), {:auto_dismiss, feedback.id}, feedback.duration)
      end

      # Update stats
      new_stats = update_stats(state.stats, feedback)

      {:reply, {:ok, feedback.id},
       %{
         state
         | active: new_active,
           last_feedback_at: DateTime.utc_now(),
           stats: new_stats
       }}
    end
  end

  @impl true
  def handle_call({:update_progress, feedback_id, percentage}, _from, state) do
    case Enum.find_index(state.active, fn f -> f.id == feedback_id end) do
      nil ->
        {:reply, {:error, :not_found}, state}

      idx ->
        feedback = Enum.at(state.active, idx)
        updated = %{feedback | metadata: Map.put(feedback.metadata, :progress, percentage)}
        new_active = List.replace_at(state.active, idx, updated)
        {:reply, :ok, %{state | active: new_active}}
    end
  end

  @impl true
  def handle_call({:dismiss, feedback_id}, _from, state) do
    case Enum.find_index(state.active, fn f -> f.id == feedback_id end) do
      nil ->
        {:reply, {:error, :not_found}, state}

      idx ->
        feedback = Enum.at(state.active, idx)
        dismissed = %{feedback | dismissed: true}
        new_active = List.delete_at(state.active, idx)
        new_history = [dismissed | state.history] |> Enum.take(500)
        new_stats = %{state.stats | dismissed: state.stats.dismissed + 1}

        {:reply, :ok, %{state | active: new_active, history: new_history, stats: new_stats}}
    end
  end

  @impl true
  def handle_call(:active, _from, state) do
    {:reply, state.active, state}
  end

  @impl true
  def handle_call({:history, limit}, _from, state) do
    {:reply, Enum.take(state.history, limit), state}
  end

  @impl true
  def handle_call(:render_json, _from, state) do
    json = %{
      active:
        Enum.map(state.active, fn f ->
          visual = Map.get(@visual_patterns, f.type, %{})

          %{
            id: f.id,
            type: f.type,
            message: f.message,
            urgency: f.urgency,
            color: color_to_css(Map.get(visual, :color, {100, 100, 100})),
            animation: Map.get(visual, :animation, :none),
            timestamp: DateTime.to_iso8601(f.timestamp),
            progress: Map.get(f.metadata, :progress),
            dismissible: f.duration != :persistent
          }
        end),
      summary: %{
        total_active: length(state.active),
        by_urgency: count_by_urgency(state.active)
      }
    }

    {:reply, json, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_cast(:dismiss_all, state) do
    dismissed_feedback = Enum.map(state.active, fn f -> %{f | dismissed: true} end)
    new_history = (dismissed_feedback ++ state.history) |> Enum.take(500)
    {:noreply, %{state | active: [], history: new_history}}
  end

  @impl true
  def handle_info({:auto_dismiss, feedback_id}, state) do
    case Enum.find_index(state.active, fn f -> f.id == feedback_id end) do
      nil ->
        {:noreply, state}

      idx ->
        feedback = Enum.at(state.active, idx)
        dismissed = %{feedback | dismissed: true}
        new_active = List.delete_at(state.active, idx)
        new_history = [dismissed | state.history] |> Enum.take(500)

        {:noreply, %{state | active: new_active, history: new_history}}
    end
  end

  # Private helpers

  defp generate_id do
    random_bytes = :crypto.strong_rand_bytes(4)
    random_bytes |> Base.encode16(case: :lower)
  end

  defp rate_limited?(state) do
    case state.last_feedback_at do
      nil ->
        false

      last ->
        diff = DateTime.diff(DateTime.utc_now(), last, :millisecond)
        diff < state.config.rate_limit_ms
    end
  end

  defp default_urgency(:confirmation), do: :low
  defp default_urgency(:info), do: :low
  defp default_urgency(:progress), do: :low
  defp default_urgency(:warning), do: :medium
  defp default_urgency(:error), do: :high
  defp default_urgency(:alert), do: :critical

  defp determine_modalities(type, urgency, config) do
    enabled = config.enabled_modalities

    base_modalities =
      case {type, urgency} do
        {_, :critical} -> [:visual, :audio, :haptic, :notification]
        {_, :high} -> [:visual, :audio, :notification]
        {:error, _} -> [:visual, :notification]
        {:warning, _} -> [:visual, :notification]
        _ -> [:visual]
      end

    Enum.filter(base_modalities, fn m -> m in enabled end)
  end

  defp get_duration(type, opts) do
    case Keyword.get(opts, :duration) do
      nil ->
        visual = Map.get(@visual_patterns, type, %{})
        Map.get(visual, :duration, 3000)

      :persistent ->
        :persistent

      ms when is_integer(ms) ->
        ms
    end
  end

  defp execute_feedback(feedback, _config) do
    # Log for each modality (in production, would trigger actual feedback)
    Enum.each(feedback.modalities, fn modality ->
      execute_modality(modality, feedback)
    end)
  end

  defp execute_modality(:visual, feedback) do
    visual = Map.get(@visual_patterns, feedback.type, %{})
    Logger.debug("Visual feedback: #{feedback.type} - #{inspect(visual)}")
  end

  defp execute_modality(:audio, feedback) do
    audio = Map.get(@audio_patterns, feedback.type)

    if audio do
      Logger.debug("Audio feedback: #{feedback.type} - #{inspect(audio)}")
    end
  end

  defp execute_modality(:haptic, feedback) do
    haptic = Map.get(@haptic_patterns, feedback.type)

    if haptic do
      Logger.debug("Haptic feedback: #{feedback.type} - #{inspect(haptic)}")
    end
  end

  defp execute_modality(:notification, feedback) do
    Logger.debug("Notification: [#{feedback.urgency}] #{feedback.message}")
  end

  defp update_stats(stats, feedback) do
    by_type = Map.update(stats.by_type, feedback.type, 1, &(&1 + 1))
    by_urgency = Map.update(stats.by_urgency, feedback.urgency, 1, &(&1 + 1))

    %{
      stats
      | sent: stats.sent + 1,
        by_type: by_type,
        by_urgency: by_urgency
    }
  end

  defp count_by_urgency(feedback_list) do
    Enum.reduce(feedback_list, %{}, fn f, acc ->
      Map.update(acc, f.urgency, 1, &(&1 + 1))
    end)
  end

  defp color_to_css({r, g, b}) do
    "rgb(#{r},#{g},#{b})"
  end
end
