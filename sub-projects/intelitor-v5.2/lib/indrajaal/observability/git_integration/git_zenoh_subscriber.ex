defmodule Indrajaal.Observability.GitIntegration.GitZenohSubscriber do
  @moduledoc """
  Zenoh subscriber for Git Intelligence events from F# CEPAF.

  ## WHAT
  Subscribes to 14 `indrajaal/git/*` Zenoh topics published by the F#
  GitIntelligence subsystem and bridges them into the Elixir ecosystem
  via ETS caching and Phoenix.PubSub broadcasting.

  ## WHY
  - Enables Prajna cockpit to display Git Health Score (GHS) in real-time
  - Enables Sentinel to escalate git anti-pattern threats (SC-IMMUNE-001)
  - Enables SMRITI to record git evolution events (SC-SMRITI-142)
  - Closes the L2-L6 mesh loop: F# MCP -> Zenoh -> Elixir -> LiveView

  ## CONSTRAINTS
  - SC-BRIDGE-001: Message buffer FIFO
  - SC-BRIDGE-003: Latency budget 50ms
  - SC-ZTEST-008: Log fallback when Zenoh unavailable
  - SC-BIO-EXT-001: PatternHunter pre-error detection < 10ms

  ## Subscribed Topics (14)
  - indrajaal/git/commit         - SHA, message, type, scopes, GHS
  - indrajaal/git/health         - GHS, ICP adoption, scope compliance
  - indrajaal/git/validate       - Message validity, issues
  - indrajaal/git/suggest        - AI-suggested messages
  - indrajaal/git/homeostasis    - PID state, mode, guidance
  - indrajaal/git/federation     - Peer GHS exchange
  - indrajaal/git/constitutional - Invariant check results
  - indrajaal/git/multiverse     - Fork/promote/prune
  - indrajaal/git/biomorphic     - Overall health assessment
  - indrajaal/git/threat         - Pattern detection, immunity
  - indrajaal/git/homeostatic    - PID output, integral, error
  - indrajaal/git/neural         - AI recommendations
  - indrajaal/git/vital          - Health/stress/energy indices
  - indrajaal/git/alignment      - Founder's Directive alignment

  ## Integration Points
  - PubSub topic: "git_intelligence" (all events)
  - PubSub topic: "git_intelligence:health" (GHS updates only)
  - PubSub topic: "git_intelligence:threat" (threat escalation)
  - ETS table: :git_intelligence (read_concurrency for LiveView)
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohSession

  # Zenoh key expression for all 14 git intelligence topics
  @key_expr "indrajaal/git/**"
  @poll_interval_ms 100
  @ets_table :git_intelligence

  # PubSub topics
  @pubsub_all "git_intelligence"
  @pubsub_health "git_intelligence:health"
  @pubsub_threat "git_intelligence:threat"

  # Threat escalation threshold
  @threat_escalation_levels ["high", "critical", "emergency"]

  defstruct [
    :subscriber_ref,
    :enabled,
    :stats,
    :last_message_at,
    :last_ghs,
    :threat_count
  ]

  @type t :: %__MODULE__{
          subscriber_ref: reference() | nil,
          enabled: boolean(),
          stats: map(),
          last_message_at: DateTime.t() | nil,
          last_ghs: float() | nil,
          threat_count: non_neg_integer()
        }

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc "Start the Git Intelligence Zenoh subscriber."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Get current Git Health Score (GHS)."
  @spec get_ghs() :: float() | nil
  def get_ghs do
    get_cached(:ghs)
  end

  @doc "Get latest git intelligence metrics from ETS cache."
  @spec get_metrics() :: map()
  def get_metrics do
    if :ets.whereis(@ets_table) != :undefined do
      @ets_table
      |> :ets.tab2list()
      |> Map.new(fn {key, value} -> {key, value} end)
    else
      %{}
    end
  end

  @doc "Get a specific cached value by key."
  @spec get_cached(atom()) :: term() | nil
  def get_cached(key) do
    if :ets.whereis(@ets_table) != :undefined do
      case :ets.lookup(@ets_table, key) do
        [{^key, value}] -> value
        [] -> nil
      end
    else
      nil
    end
  end

  @doc "Get subscriber statistics."
  @spec get_stats(term()) :: map()
  def get_stats(pid \\ __MODULE__), do: GenServer.call(pid, :get_stats)

  @doc "Enable or disable the subscriber."
  @spec set_enabled(term(), boolean()) :: :ok
  def set_enabled(pid \\ __MODULE__, enabled) do
    GenServer.call(pid, {:set_enabled, enabled})
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    create_ets_table()

    enabled = Keyword.get(opts, :enabled, true)

    state = %__MODULE__{
      subscriber_ref: nil,
      enabled: enabled,
      stats: initial_stats(),
      last_message_at: nil,
      last_ghs: nil,
      threat_count: 0
    }

    if enabled do
      send(self(), :subscribe)
    end

    schedule_poll()

    Logger.info("[GitZenohSubscriber] Started — subscribing to #{@key_expr}")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        last_ghs: state.last_ghs,
        threat_count: state.threat_count,
        last_message_at: state.last_message_at
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:set_enabled, enabled}, _from, state) do
    if enabled and not state.enabled do
      send(self(), :subscribe)
    end

    {:reply, :ok, %{state | enabled: enabled}}
  end

  @impl true
  def handle_info(:subscribe, state) do
    case ZenohSession.subscribe(@key_expr, self()) do
      {:ok, ref} ->
        Logger.info("[GitZenohSubscriber] Subscribed to #{@key_expr}")
        {:noreply, %{state | subscriber_ref: ref}}

      {:error, reason} ->
        Logger.warning(
          "[GitZenohSubscriber] Subscribe failed: #{inspect(reason)}, retrying in 5s"
        )

        Process.send_after(self(), :subscribe, 5_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:poll_messages, %{subscriber_ref: nil} = state) do
    schedule_poll()
    {:noreply, state}
  end

  def handle_info(:poll_messages, %{enabled: false} = state) do
    schedule_poll()
    {:noreply, state}
  end

  def handle_info(:poll_messages, state) do
    new_state =
      case ZenohSession.poll_messages(state.subscriber_ref, 100) do
        {:ok, messages} when messages != [] ->
          process_all_messages(messages, state)

        {:ok, _empty} ->
          state

        {:error, reason} ->
          Logger.debug("[GitZenohSubscriber] Poll error: #{inspect(reason)}")
          state
      end

    schedule_poll()
    {:noreply, new_state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.subscriber_ref do
      ZenohSession.unsubscribe(state.subscriber_ref)
    end

    :ok
  end

  # ============================================================
  # PRIVATE — Message Processing
  # ============================================================

  defp process_all_messages(messages, state) do
    Enum.reduce(messages, state, fn msg, acc ->
      case process_message(msg) do
        {:ok, topic, payload} ->
          acc
          |> update_stats_for(topic)
          |> maybe_update_ghs(topic, payload)
          |> maybe_track_threat(topic, payload)
          |> Map.put(:last_message_at, DateTime.utc_now())

        {:error, _reason} ->
          update_in(acc.stats, [:errors], &((&1 || 0) + 1))
      end
    end)
  end

  defp process_message(msg) do
    try do
      # Extract topic from key expression (e.g., "indrajaal/git/health" -> "health")
      topic = extract_topic(msg.key_expr || msg[:key_expr] || "")
      payload = Jason.decode!(msg.payload || msg[:payload] || "{}")

      # Store in ETS keyed by topic
      cache_event(topic, payload)

      # Broadcast to PubSub for LiveView consumers
      broadcast_event(topic, payload)

      {:ok, topic, payload}
    rescue
      e ->
        Logger.warning("[GitZenohSubscriber] Message error: #{inspect(e)}")
        {:error, e}
    end
  end

  defp extract_topic(key_expr) when is_binary(key_expr) do
    case String.split(key_expr, "/") do
      ["indrajaal", "git", topic | _rest] -> topic
      _ -> "unknown"
    end
  end

  defp extract_topic(_), do: "unknown"

  # ============================================================
  # PRIVATE — ETS Caching
  # ============================================================

  defp cache_event(topic, payload) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    # Store latest event per topic
    :ets.insert(@ets_table, {String.to_atom(topic), payload})
    :ets.insert(@ets_table, {String.to_atom("#{topic}_at"), now})

    # Store derived metrics for quick access
    case topic do
      "health" ->
        if ghs = payload["ghs"] || payload["score"] do
          :ets.insert(@ets_table, {:ghs, ghs})
          :ets.insert(@ets_table, {:ghs_at, now})
        end

        if adoption = payload["icp_adoption"] || payload["adoption"] do
          :ets.insert(@ets_table, {:icp_adoption, adoption})
        end

      "biomorphic" ->
        if health = payload["overall_health"] || payload["health"] do
          :ets.insert(@ets_table, {:biomorphic_health, health})
        end

      "threat" ->
        if level = payload["threat_level"] || payload["level"] do
          :ets.insert(@ets_table, {:threat_level, level})
        end

      "vital" ->
        if signs = payload["vital_signs"] || payload do
          :ets.insert(@ets_table, {:vital_signs, signs})
        end

      "alignment" ->
        if score = payload["alignment_score"] || payload["score"] do
          :ets.insert(@ets_table, {:founder_alignment, score})
        end

      _ ->
        :ok
    end
  end

  # ============================================================
  # PRIVATE — PubSub Broadcasting
  # ============================================================

  defp broadcast_event(topic, payload) do
    event = %{topic: topic, payload: payload, timestamp: DateTime.utc_now()}

    # Broadcast to general git intelligence topic
    Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_all, {:git_intelligence, event})

    # Broadcast to topic-specific channels
    case topic do
      "health" ->
        Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_health, {:git_health, event})

      "threat" ->
        Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_threat, {:git_threat, event})

        # Escalate high threats to Sentinel
        maybe_escalate_threat(payload)

      "biomorphic" ->
        Phoenix.PubSub.broadcast(
          Indrajaal.PubSub,
          @pubsub_health,
          {:git_biomorphic, event}
        )

      _ ->
        :ok
    end
  end

  # ============================================================
  # PRIVATE — Threat Escalation (SC-IMMUNE-001)
  # ============================================================

  defp maybe_escalate_threat(payload) do
    threat_level = payload["threat_level"] || payload["level"] || "low"

    if threat_level in @threat_escalation_levels do
      patterns = payload["patterns"] || payload["detected_patterns"] || []
      immunity = payload["immunity_score"] || payload["immunity"] || 0.0

      Logger.warning(
        "[GitZenohSubscriber] Threat escalation: level=#{threat_level} " <>
          "patterns=#{length(patterns)} immunity=#{immunity}"
      )

      # Publish threat to Sentinel's topic for immune response
      :telemetry.execute(
        [:indrajaal, :git, :threat_escalation],
        %{count: length(patterns), immunity: immunity},
        %{level: threat_level, source: "git_intelligence"}
      )
    end
  end

  # ============================================================
  # PRIVATE — State Updates
  # ============================================================

  defp maybe_update_ghs(state, "health", payload) do
    ghs = payload["ghs"] || payload["score"] || state.last_ghs
    %{state | last_ghs: ghs}
  end

  defp maybe_update_ghs(state, _topic, _payload), do: state

  defp maybe_track_threat(state, "threat", payload) do
    level = payload["threat_level"] || payload["level"] || "low"

    if level in @threat_escalation_levels do
      %{state | threat_count: state.threat_count + 1}
    else
      state
    end
  end

  defp maybe_track_threat(state, _topic, _payload), do: state

  defp update_stats_for(state, topic) do
    topic_key = String.to_atom("topic_#{topic}")

    stats =
      state.stats
      |> Map.update(:total_processed, 1, &(&1 + 1))
      |> Map.update(topic_key, 1, &(&1 + 1))

    %{state | stats: stats}
  end

  # ============================================================
  # PRIVATE — Infrastructure
  # ============================================================

  defp create_ets_table do
    case :ets.whereis(@ets_table) do
      :undefined ->
        :ets.new(@ets_table, [:named_table, :set, :public, read_concurrency: true])

      _ ->
        :ok
    end
  end

  defp schedule_poll do
    Process.send_after(self(), :poll_messages, @poll_interval_ms)
  end

  defp initial_stats do
    %{
      total_processed: 0,
      errors: 0,
      started_at: DateTime.utc_now()
    }
  end
end
