defmodule Indrajaal.Substrate.L7.ConsciousnessBridge do
  @moduledoc """
  ## Design Intent
  L7 Consciousness Bridge — GenServer that interfaces between system-level awareness
  and human operators. Maintains an awareness level, attention focus, and narrative log
  so that the system can communicate its internal state to operators in human-intelligible
  terms.

  Awareness model:
    - awareness_level (0.0–1.0): how much the system "knows" about its own state
      - 0.0–0.3 : :dormant   — minimal self-knowledge
      - 0.3–0.6 : :alert     — basic situational awareness
      - 0.6–0.85: :aware     — good self-model, active attention
      - 0.85–1.0: :conscious — full self-model, rich narrative

  Attention focus is a domain atom that the system is currently prioritising.
  Narrative log is a bounded (200 entries) append-only list of human-readable events.

  Heartbeat (every 60 s) recalculates awareness from system signals and publishes
  to the "prajna:consciousness" PubSub topic and Zenoh.

  Human interface returns a structured map suitable for LiveView rendering.

  ## STAMP Constraints
  - SC-SMRITI-063: Federation protocol — consciousness bridges cross-holon awareness
  - SC-HMI-010: Color-rich feedback — awareness level drives cockpit colour
  - SC-HMI-011: 8x8 matrix coverage — consciousness is one of the 8 awareness layers
  - SC-FUNC-001: System must compile at all times

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L7 morphogenesis) |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "prajna:consciousness"
  @zenoh_topic "indrajaal/substrate/l7/consciousness/state"
  @checkpoint "CP-L7-CONSCIOUSNESS-01"

  # Max narrative log size
  @max_narrative 200

  # Heartbeat interval ms
  @heartbeat_ms 60_000

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type awareness_category :: :dormant | :alert | :aware | :conscious

  @type narrative_entry :: %{
          id: String.t(),
          text: String.t(),
          domain: atom(),
          awareness_at: float(),
          timestamp: integer()
        }

  @type human_interface_data :: %{
          awareness_level: float(),
          awareness_category: awareness_category(),
          attention_focus: atom(),
          narrative_count: non_neg_integer(),
          recent_narrative: [narrative_entry()],
          color_hint: String.t(),
          heartbeat_count: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Return the current awareness level as a float in [0.0, 1.0].
  """
  @spec awareness() :: float()
  def awareness do
    GenServer.call(@name, :awareness)
  end

  @doc """
  Set the attention focus to a specific domain atom.
  e.g. `focus(:federation)`, `focus(:alarms)`, `focus(:math_disciplines)`
  """
  @spec focus(atom()) :: :ok
  def focus(domain) when is_atom(domain) do
    GenServer.call(@name, {:focus, domain})
  end

  @doc """
  Append a narrative entry with a human-readable description.
  `domain` is the source subsystem atom.
  """
  @spec narrate(String.t(), atom()) :: {:ok, String.t()}
  def narrate(text, domain \\ :system)
      when is_binary(text) and is_atom(domain) do
    GenServer.call(@name, {:narrate, text, domain})
  end

  @doc """
  Return a structured map suitable for LiveView rendering.
  Includes awareness level, category, attention focus, recent narrative, and colour hint.
  """
  @spec human_interface() :: human_interface_data()
  def human_interface do
    GenServer.call(@name, :human_interface)
  end

  @doc """
  Inject a new awareness signal (0.0–1.0) that updates the awareness level via EMA.
  Used by monitoring subsystems to report current system health to consciousness.
  """
  @spec update_awareness(float()) :: :ok
  def update_awareness(signal) when is_float(signal) do
    GenServer.cast(@name, {:update_awareness, signal})
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    interval_ms = Keyword.get(opts, :heartbeat_interval_ms, @heartbeat_ms)
    schedule_heartbeat(interval_ms)

    state = %{
      awareness_level: 0.5,
      attention_focus: :system,
      narrative: [],
      heartbeat_count: 0,
      heartbeat_interval_ms: interval_ms,
      started_at: DateTime.utc_now()
    }

    Logger.warning("[CONSCIOUSNESS_BRIDGE] Started — checkpoint=#{@checkpoint}")
    {:ok, state}
  end

  @impl true
  def handle_call(:awareness, _from, state) do
    {:reply, state.awareness_level, state}
  end

  @impl true
  def handle_call({:focus, domain}, _from, state) do
    Logger.info("[CONSCIOUSNESS_BRIDGE] Attention shifted to domain=#{domain}")
    {:reply, :ok, %{state | attention_focus: domain}}
  end

  @impl true
  def handle_call({:narrate, text, domain}, _from, state) do
    now = System.monotonic_time(:second)
    id = :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)

    entry = %{
      id: id,
      text: text,
      domain: domain,
      awareness_at: state.awareness_level,
      timestamp: now
    }

    narrative = [entry | Enum.take(state.narrative, @max_narrative - 1)]

    Logger.debug("[CONSCIOUSNESS_BRIDGE] Narrated id=#{id} domain=#{domain}")

    # Broadcast narrative event
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:narrative, entry}
      )
    rescue
      _ -> :ok
    end

    {:reply, {:ok, id}, %{state | narrative: narrative}}
  end

  @impl true
  def handle_call(:human_interface, _from, state) do
    category = awareness_category(state.awareness_level)
    color = color_hint(category)

    recent = Enum.take(state.narrative, 10)

    data = %{
      awareness_level: state.awareness_level,
      awareness_category: category,
      attention_focus: state.attention_focus,
      narrative_count: length(state.narrative),
      recent_narrative: recent,
      color_hint: color,
      heartbeat_count: state.heartbeat_count
    }

    {:reply, data, state}
  end

  @impl true
  def handle_cast({:update_awareness, signal}, state) do
    signal_clamped = max(0.0, min(1.0, signal))
    # EMA update: α = 0.3
    new_level = 0.3 * signal_clamped + 0.7 * state.awareness_level
    new_level = Float.round(new_level, 4)

    {:noreply, %{state | awareness_level: new_level}}
  end

  @impl true
  def handle_info(:heartbeat_tick, state) do
    new_state = %{state | heartbeat_count: state.heartbeat_count + 1}

    category = awareness_category(state.awareness_level)

    payload = %{
      awareness_level: state.awareness_level,
      awareness_category: category,
      attention_focus: state.attention_focus,
      heartbeat_count: new_state.heartbeat_count
    }

    broadcast_state(payload)

    Logger.debug(
      "[CONSCIOUSNESS_BRIDGE] Heartbeat #{new_state.heartbeat_count} — awareness=#{state.awareness_level} category=#{category}"
    )

    schedule_heartbeat(state.heartbeat_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[CONSCIOUSNESS_BRIDGE] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec awareness_category(float()) :: awareness_category()
  defp awareness_category(level) do
    cond do
      level >= 0.85 -> :conscious
      level >= 0.6 -> :aware
      level >= 0.3 -> :alert
      true -> :dormant
    end
  end

  @spec color_hint(awareness_category()) :: String.t()
  defp color_hint(:conscious), do: "#00ff88"
  defp color_hint(:aware), do: "#44aaff"
  defp color_hint(:alert), do: "#ffcc00"
  defp color_hint(:dormant), do: "#666666"

  defp schedule_heartbeat(interval_ms) do
    Process.send_after(self(), :heartbeat_tick, interval_ms)
  end

  defp broadcast_state(payload) do
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:consciousness_state, payload}
      )
    rescue
      _ -> :ok
    end

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(
        @zenoh_topic,
        Map.merge(payload, %{
          checkpoint: @checkpoint,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
      )
    rescue
      _ -> :ok
    end
  end
end
