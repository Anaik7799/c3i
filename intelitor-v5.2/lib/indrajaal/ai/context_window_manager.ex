defmodule Indrajaal.AI.ContextWindowManager do
  @moduledoc """
  Context Window Manager for AI Sessions.

  WHAT: Tracks context window token usage across AI sessions and triggers
  compaction when thresholds are exceeded.

  WHY: Required by SC-BIO-004 (auto-compact at 75% context) and SC-AI-007
  (context window usage trigger at 75%). Prevents context overflow and
  ensures optimal token utilization.

  CONSTRAINTS:
  - SC-BIO-004: Auto-compact at 75% context usage
  - SC-AI-007: Context window usage MUST trigger /compact at 75%
  - SC-PROM-003: Dashboard refresh every 30s with context metrics
  - AOR-PROM-003: Agents MUST auto-compact memory/context at 80% usage

  ## Architecture

  The Context Window Manager tracks:
  - Per-session token usage (input + output tokens)
  - Session-level context accumulation
  - Context window capacity monitoring
  - Compaction event triggering

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Updated | 2026-01-21 |
  | Author | Claude Opus 4.5 |
  | STAMP | SC-BIO-004, SC-AI-007, SC-PROM-003 |
  """

  use GenServer

  require Logger

  alias Indrajaal.Observability.FractalLogger

  # Default context window sizes by model
  @default_context_window 200_000
  @model_context_windows %{
    "anthropic/claude-3.5-sonnet" => 200_000,
    "anthropic/claude-3-opus" => 200_000,
    "anthropic/claude-3-haiku" => 200_000,
    "openai/gpt-4-turbo" => 128_000,
    "google/gemini-pro" => 1_000_000,
    "meta-llama/llama-3.1-8b-instruct:free" => 4_000
  }

  # Thresholds (per SC-BIO-004)
  @compact_threshold_percent 0.75
  @warning_threshold_percent 0.90
  @minimal_mode_threshold_percent 0.95

  # Checkpoints for monitoring (per agent-cognitive-protocol.md)
  @checkpoint_1_percent 0.37
  # Reserved for future checkpoint implementation (SC-CMP-025 compliance)
  # @checkpoint_2_percent 0.75
  # @checkpoint_3_percent 0.90

  defstruct [
    # Session tracking
    :sessions,
    :active_session_id,
    # Global context state
    :global_context_window,
    :global_tokens_used,
    # Alerts
    :compact_alert_sent,
    :warning_alert_sent,
    :minimal_mode_alert_sent,
    # Telemetry
    :total_compactions,
    :total_sessions,
    :started_at
  ]

  @type session_state :: %{
          session_id: String.t(),
          model: String.t(),
          context_window: non_neg_integer(),
          tokens_used: non_neg_integer(),
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          message_count: non_neg_integer(),
          started_at: DateTime.t(),
          last_activity: DateTime.t(),
          compact_count: non_neg_integer()
        }

  @type t :: %__MODULE__{
          sessions: %{String.t() => session_state()},
          active_session_id: String.t() | nil,
          global_context_window: non_neg_integer(),
          global_tokens_used: non_neg_integer(),
          compact_alert_sent: boolean(),
          warning_alert_sent: boolean(),
          minimal_mode_alert_sent: boolean(),
          total_compactions: non_neg_integer(),
          total_sessions: non_neg_integer(),
          started_at: DateTime.t()
        }

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Start the ContextWindowManager GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start a new AI session with context tracking.

  ## Parameters
    - session_id: Unique session identifier
    - model: The AI model being used (determines context window size)

  ## Returns
    - {:ok, session_state} on success
  """
  @spec start_session(String.t(), String.t()) :: {:ok, session_state()}
  def start_session(session_id, model \\ "anthropic/claude-3.5-sonnet") do
    GenServer.call(__MODULE__, {:start_session, session_id, model})
  end

  @doc """
  Record token usage for a session.

  ## Parameters
    - session_id: The session identifier
    - input_tokens: Number of input tokens consumed
    - output_tokens: Number of output tokens generated

  ## Returns
    - {:ok, :normal} - Usage recorded, within limits
    - {:ok, :checkpoint_1} - At 37% checkpoint
    - {:ok, :checkpoint_2} - At 75% checkpoint, compaction recommended
    - {:ok, :checkpoint_3} - At 90% checkpoint, minimal mode recommended
    - {:compact_required, usage_percent} - Compaction required
    - {:error, reason} - Session not found or error
  """
  @spec record_usage(String.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, atom()} | {:compact_required, float()} | {:error, atom()}
  def record_usage(session_id, input_tokens, output_tokens) do
    GenServer.call(__MODULE__, {:record_usage, session_id, input_tokens, output_tokens})
  end

  @doc """
  Get the current context usage percentage for a session.
  """
  @spec get_usage_percent(String.t()) :: {:ok, float()} | {:error, :not_found}
  def get_usage_percent(session_id) do
    GenServer.call(__MODULE__, {:get_usage_percent, session_id})
  end

  @doc """
  Get the context state for a specific session.
  """
  @spec get_session_state(String.t()) :: {:ok, session_state()} | {:error, :not_found}
  def get_session_state(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  @doc """
  Record a compaction event for a session.
  This resets the token count while preserving session history.
  """
  @spec record_compaction(String.t(), non_neg_integer()) :: :ok | {:error, :not_found}
  def record_compaction(session_id, tokens_after_compaction \\ 0) do
    GenServer.call(__MODULE__, {:record_compaction, session_id, tokens_after_compaction})
  end

  @doc """
  End an AI session.
  """
  @spec end_session(String.t()) :: :ok
  def end_session(session_id) do
    GenServer.cast(__MODULE__, {:end_session, session_id})
  end

  @doc """
  Get complete context manager statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Check if compaction is needed for a session.
  """
  @spec needs_compaction?(String.t()) :: boolean()
  def needs_compaction?(session_id) do
    case get_usage_percent(session_id) do
      {:ok, percent} -> percent >= @compact_threshold_percent
      {:error, _} -> false
    end
  end

  @doc """
  Get context window size for a model.
  """
  @spec get_context_window(String.t()) :: non_neg_integer()
  def get_context_window(model) do
    Map.get(@model_context_windows, model, @default_context_window)
  end

  @doc """
  Get recommended action based on current usage.
  """
  @spec get_recommended_action(String.t()) ::
          {:continue, float()} | {:compact, float()} | {:minimal_mode, float()} | {:error, atom()}
  def get_recommended_action(session_id) do
    case get_usage_percent(session_id) do
      {:ok, percent} when percent >= @minimal_mode_threshold_percent ->
        {:minimal_mode, percent}

      {:ok, percent} when percent >= @compact_threshold_percent ->
        {:compact, percent}

      {:ok, percent} ->
        {:continue, percent}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Server Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    global_context = Keyword.get(opts, :global_context_window, @default_context_window)

    FractalLogger.spine(:info, "ContextWindowManager starting", %{
      global_context_window: global_context,
      compact_threshold: @compact_threshold_percent
    })

    state = %__MODULE__{
      sessions: %{},
      active_session_id: nil,
      global_context_window: global_context,
      global_tokens_used: 0,
      compact_alert_sent: false,
      warning_alert_sent: false,
      minimal_mode_alert_sent: false,
      total_compactions: 0,
      total_sessions: 0,
      started_at: DateTime.utc_now()
    }

    # Schedule periodic telemetry emission
    schedule_telemetry()

    {:ok, state}
  end

  @impl true
  def handle_call({:start_session, session_id, model}, _from, state) do
    context_window = get_context_window(model)
    now = DateTime.utc_now()

    session = %{
      session_id: session_id,
      model: model,
      context_window: context_window,
      tokens_used: 0,
      input_tokens: 0,
      output_tokens: 0,
      message_count: 0,
      started_at: now,
      last_activity: now,
      compact_count: 0
    }

    new_sessions = Map.put(state.sessions, session_id, session)

    Logger.info(
      "[ContextWindowManager] Started session #{session_id} (model: #{model}, context: #{context_window})"
    )

    new_state = %{
      state
      | sessions: new_sessions,
        active_session_id: session_id,
        total_sessions: state.total_sessions + 1
    }

    emit_session_event(:session_started, session)

    {:reply, {:ok, session}, new_state}
  end

  @impl true
  def handle_call({:record_usage, session_id, input_tokens, output_tokens}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        total_new_tokens = input_tokens + output_tokens
        new_tokens_used = session.tokens_used + total_new_tokens

        updated_session = %{
          session
          | tokens_used: new_tokens_used,
            input_tokens: session.input_tokens + input_tokens,
            output_tokens: session.output_tokens + output_tokens,
            message_count: session.message_count + 1,
            last_activity: DateTime.utc_now()
        }

        usage_percent = new_tokens_used / session.context_window
        new_sessions = Map.put(state.sessions, session_id, updated_session)
        new_global_used = state.global_tokens_used + total_new_tokens

        new_state = %{
          state
          | sessions: new_sessions,
            global_tokens_used: new_global_used
        }

        # Check thresholds and emit telemetry
        {result, final_state} = check_thresholds_and_respond(new_state, session_id, usage_percent)

        emit_usage_event(updated_session, usage_percent)

        {:reply, result, final_state}
    end
  end

  @impl true
  def handle_call({:get_usage_percent, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      session ->
        percent = session.tokens_used / session.context_window
        {:reply, {:ok, percent}, state}
    end
  end

  @impl true
  def handle_call({:get_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil -> {:reply, {:error, :not_found}, state}
      session -> {:reply, {:ok, session}, state}
    end
  end

  @impl true
  def handle_call({:record_compaction, session_id, tokens_after}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      session ->
        tokens_freed = session.tokens_used - tokens_after

        updated_session = %{
          session
          | tokens_used: tokens_after,
            compact_count: session.compact_count + 1,
            last_activity: DateTime.utc_now()
        }

        new_sessions = Map.put(state.sessions, session_id, updated_session)

        Logger.info(
          "[ContextWindowManager] Compaction recorded for #{session_id} " <>
            "(freed: #{tokens_freed}, now: #{tokens_after})"
        )

        new_state = %{
          state
          | sessions: new_sessions,
            global_tokens_used: max(0, state.global_tokens_used - tokens_freed),
            total_compactions: state.total_compactions + 1,
            compact_alert_sent: false,
            warning_alert_sent: false,
            minimal_mode_alert_sent: false
        }

        emit_compaction_event(updated_session, tokens_freed)

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      # Global stats
      global_context_window: state.global_context_window,
      global_tokens_used: state.global_tokens_used,
      global_usage_percent: state.global_tokens_used / state.global_context_window,
      total_compactions: state.total_compactions,
      total_sessions: state.total_sessions,
      active_sessions: map_size(state.sessions),
      started_at: state.started_at,

      # Session details
      sessions:
        Enum.map(state.sessions, fn {id, session} ->
          %{
            session_id: id,
            model: session.model,
            tokens_used: session.tokens_used,
            context_window: session.context_window,
            usage_percent: Float.round(session.tokens_used / session.context_window * 100, 2),
            message_count: session.message_count,
            compact_count: session.compact_count,
            last_activity: session.last_activity
          }
        end),

      # Thresholds
      compact_threshold_percent: @compact_threshold_percent * 100,
      warning_threshold_percent: @warning_threshold_percent * 100
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:end_session, session_id}, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:noreply, state}

      session ->
        Logger.info(
          "[ContextWindowManager] Ended session #{session_id} " <>
            "(tokens: #{session.tokens_used}, messages: #{session.message_count}, compactions: #{session.compact_count})"
        )

        emit_session_event(:session_ended, session)

        new_sessions = Map.delete(state.sessions, session_id)
        new_global_used = max(0, state.global_tokens_used - session.tokens_used)

        new_state = %{
          state
          | sessions: new_sessions,
            global_tokens_used: new_global_used,
            active_session_id:
              if(state.active_session_id == session_id, do: nil, else: state.active_session_id)
        }

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:emit_telemetry, state) do
    emit_manager_telemetry(state)
    schedule_telemetry()
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private Functions
  # ---------------------------------------------------------------------------

  defp check_thresholds_and_respond(state, session_id, usage_percent) do
    cond do
      usage_percent >= @minimal_mode_threshold_percent ->
        unless state.minimal_mode_alert_sent do
          Logger.warning(
            "[ContextWindowManager] Session #{session_id} at #{Float.round(usage_percent * 100, 1)}% " <>
              "- MINIMAL MODE REQUIRED"
          )

          emit_threshold_alert(:minimal_mode, session_id, usage_percent)
        end

        {
          {:compact_required, usage_percent},
          %{state | minimal_mode_alert_sent: true}
        }

      usage_percent >= @warning_threshold_percent ->
        unless state.warning_alert_sent do
          Logger.warning(
            "[ContextWindowManager] Session #{session_id} at #{Float.round(usage_percent * 100, 1)}% " <>
              "- WARNING: Approaching limit"
          )

          emit_threshold_alert(:warning, session_id, usage_percent)
        end

        {
          {:ok, :checkpoint_3},
          %{state | warning_alert_sent: true}
        }

      usage_percent >= @compact_threshold_percent ->
        unless state.compact_alert_sent do
          Logger.info(
            "[ContextWindowManager] Session #{session_id} at #{Float.round(usage_percent * 100, 1)}% " <>
              "- Compaction recommended (SC-BIO-004)"
          )

          emit_threshold_alert(:compact_recommended, session_id, usage_percent)
        end

        {
          {:ok, :checkpoint_2},
          %{state | compact_alert_sent: true}
        }

      usage_percent >= @checkpoint_1_percent ->
        {{:ok, :checkpoint_1}, state}

      true ->
        {{:ok, :normal}, state}
    end
  end

  defp schedule_telemetry do
    # Emit telemetry every 30 seconds (per SC-PROM-003)
    Process.send_after(self(), :emit_telemetry, :timer.seconds(30))
  end

  # ---------------------------------------------------------------------------
  # Telemetry Events
  # ---------------------------------------------------------------------------

  defp emit_session_event(event_type, session) do
    :telemetry.execute(
      [:indrajaal, :context_window, :session],
      %{
        tokens_used: session.tokens_used,
        context_window: session.context_window,
        message_count: session.message_count,
        compact_count: session.compact_count
      },
      %{
        event: event_type,
        session_id: session.session_id,
        model: session.model
      }
    )
  end

  defp emit_usage_event(session, usage_percent) do
    :telemetry.execute(
      [:indrajaal, :context_window, :usage],
      %{
        tokens_used: session.tokens_used,
        usage_percent: usage_percent,
        input_tokens: session.input_tokens,
        output_tokens: session.output_tokens
      },
      %{
        session_id: session.session_id,
        model: session.model
      }
    )
  end

  defp emit_compaction_event(session, tokens_freed) do
    :telemetry.execute(
      [:indrajaal, :context_window, :compaction],
      %{
        tokens_freed: tokens_freed,
        tokens_remaining: session.tokens_used,
        compact_count: session.compact_count
      },
      %{
        session_id: session.session_id,
        model: session.model
      }
    )
  end

  defp emit_threshold_alert(alert_type, session_id, usage_percent) do
    :telemetry.execute(
      [:indrajaal, :context_window, :threshold_alert],
      %{
        usage_percent: usage_percent
      },
      %{
        alert_type: alert_type,
        session_id: session_id
      }
    )
  end

  defp emit_manager_telemetry(state) do
    :telemetry.execute(
      [:indrajaal, :context_window, :manager],
      %{
        global_tokens_used: state.global_tokens_used,
        global_usage_percent: state.global_tokens_used / state.global_context_window,
        active_sessions: map_size(state.sessions),
        total_compactions: state.total_compactions,
        total_sessions: state.total_sessions
      },
      %{}
    )
  end
end
