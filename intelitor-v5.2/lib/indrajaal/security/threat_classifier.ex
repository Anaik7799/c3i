defmodule Indrajaal.Security.ThreatClassifier do
  @moduledoc """
  Threat Classifier — L1 Operational Layer (Security Subsystem)

  ## Design Intent
  Classifies security threats based on multiple signals including source,
  pattern, frequency, and severity. Uses a weighted scoring model to
  produce a composite threat level.

  Integrates with the Digital Immune System (Sentinel, PatternHunter,
  SymbioticDefense) to provide input for automated response decisions.

  ## STAMP Constraints
  - SC-IMMUNE-001: Health scoring with quarantine protocol
  - SC-IMMUNE-002: Circuit breaker at error rate > 10%
  - SC-THR-001: Threat assessment mandatory
  - SC-SAFETY-020: Auto-halt at threat threshold

  ## Change History
  | Version | Date       | Author | Change                    |
  |---------|------------|--------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @table :threat_classifications
  @pubsub_topic "security:threats"
  @escalation_threshold 0.8
  @max_recent 200

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type threat_level :: :none | :low | :medium | :high | :critical
  @type threat_source :: :network | :authentication | :authorization | :data | :system | :unknown

  @type threat :: %{
          id: String.t(),
          source: threat_source(),
          level: threat_level(),
          score: float(),
          description: String.t(),
          indicators: [String.t()],
          timestamp: non_neg_integer(),
          acknowledged: boolean()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Classify a potential threat from indicators."
  @spec classify(threat_source(), [String.t()], String.t()) :: threat()
  def classify(source, indicators, description \\ "") do
    GenServer.call(@name, {:classify, source, indicators, description})
  end

  @doc "Acknowledge a threat (mark as reviewed)."
  @spec acknowledge(String.t()) :: :ok | {:error, :not_found}
  def acknowledge(threat_id) do
    GenServer.call(@name, {:acknowledge, threat_id})
  end

  @doc "Get recent threats, optionally filtered by level."
  @spec recent_threats(threat_level() | nil) :: [threat()]
  def recent_threats(level \\ nil) do
    GenServer.call(@name, {:recent, level})
  end

  @doc "Get current threat posture (aggregate assessment)."
  @spec posture() :: map()
  def posture do
    GenServer.call(@name, :posture)
  end

  @doc "Get threat statistics."
  @spec stats() :: map()
  def stats do
    GenServer.call(@name, :stats)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :ordered_set, read_concurrency: true])

    state = %{
      total_classified: 0,
      level_counts: %{none: 0, low: 0, medium: 0, high: 0, critical: 0},
      escalation_count: 0
    }

    Logger.info(
      "[ThreatClassifier] Started — escalation_threshold=#{@escalation_threshold} [SC-IMMUNE-001]"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:classify, source, indicators, description}, _from, state) do
    score = compute_threat_score(source, indicators)
    level = score_to_level(score)
    now = System.system_time(:millisecond)

    threat = %{
      id: generate_threat_id(now),
      source: source,
      level: level,
      score: Float.round(score, 4),
      description: description,
      indicators: indicators,
      timestamp: now,
      acknowledged: false
    }

    # Store in ETS (ordered by timestamp)
    :ets.insert(@table, {now, threat})
    prune_old_entries()

    # Update counters
    level_counts = Map.update(state.level_counts, level, 1, &(&1 + 1))

    escalation_count =
      if score >= @escalation_threshold,
        do: state.escalation_count + 1,
        else: state.escalation_count

    state2 = %{
      state
      | total_classified: state.total_classified + 1,
        level_counts: level_counts,
        escalation_count: escalation_count
    }

    # Broadcast and emit telemetry
    if level in [:high, :critical] do
      broadcast_threat(threat)

      Logger.warning(
        "[ThreatClassifier] #{level} threat from #{source}: score=#{Float.round(score, 3)} [SC-IMMUNE-001]"
      )
    end

    emit_telemetry(threat)

    {:reply, threat, state2}
  end

  @impl true
  def handle_call({:acknowledge, threat_id}, _from, state) do
    result =
      :ets.tab2list(@table)
      |> Enum.find(fn {_ts, t} -> t.id == threat_id end)

    case result do
      {ts, threat} ->
        updated = %{threat | acknowledged: true}
        :ets.insert(@table, {ts, updated})
        {:reply, :ok, state}

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:recent, nil}, _from, state) do
    threats =
      :ets.tab2list(@table)
      |> Enum.map(fn {_ts, t} -> t end)
      |> Enum.sort_by(& &1.timestamp, :desc)
      |> Enum.take(50)

    {:reply, threats, state}
  end

  @impl true
  def handle_call({:recent, level}, _from, state) do
    threats =
      :ets.tab2list(@table)
      |> Enum.filter(fn {_ts, t} -> t.level == level end)
      |> Enum.map(fn {_ts, t} -> t end)
      |> Enum.sort_by(& &1.timestamp, :desc)
      |> Enum.take(50)

    {:reply, threats, state}
  end

  @impl true
  def handle_call(:posture, _from, state) do
    recent =
      :ets.tab2list(@table)
      |> Enum.map(fn {_ts, t} -> t end)
      |> Enum.filter(&(System.system_time(:millisecond) - &1.timestamp < 300_000))

    avg_score =
      if recent == [] do
        0.0
      else
        Enum.sum(Enum.map(recent, & &1.score)) / length(recent)
      end

    max_level =
      case Enum.max_by(recent, &level_to_number(&1.level), fn -> %{level: :none} end) do
        %{level: l} -> l
        _ -> :none
      end

    unacknowledged = Enum.count(recent, &(not &1.acknowledged))

    {:reply,
     %{
       posture_level: max_level,
       avg_score: Float.round(avg_score, 4),
       active_threats: length(recent),
       unacknowledged: unacknowledged,
       escalation_count: state.escalation_count
     }, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply,
     %{
       total_classified: state.total_classified,
       level_counts: state.level_counts,
       escalation_count: state.escalation_count,
       active_entries: :ets.info(@table, :size)
     }, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp compute_threat_score(source, indicators) do
    source_weight = source_weight(source)
    indicator_count = length(indicators)

    # Base score from source type
    base = source_weight * 0.4

    # Indicator density contributes to score
    indicator_score = min(indicator_count / 5.0, 1.0) * 0.4

    # Pattern matching on known high-risk indicators
    pattern_score = check_high_risk_patterns(indicators) * 0.2

    min(base + indicator_score + pattern_score, 1.0)
  end

  defp source_weight(:authentication), do: 0.9
  defp source_weight(:authorization), do: 0.85
  defp source_weight(:system), do: 0.8
  defp source_weight(:data), do: 0.7
  defp source_weight(:network), do: 0.6
  defp source_weight(:unknown), do: 0.5

  defp check_high_risk_patterns(indicators) do
    high_risk_patterns = [
      "brute_force",
      "privilege_escalation",
      "injection",
      "exfiltration",
      "unauthorized_access",
      "constitution_violation",
      "guardian_bypass"
    ]

    matches =
      Enum.count(indicators, fn ind ->
        Enum.any?(high_risk_patterns, &String.contains?(String.downcase(ind), &1))
      end)

    min(matches / 3.0, 1.0)
  end

  defp score_to_level(score) when score >= 0.8, do: :critical
  defp score_to_level(score) when score >= 0.6, do: :high
  defp score_to_level(score) when score >= 0.4, do: :medium
  defp score_to_level(score) when score >= 0.2, do: :low
  defp score_to_level(_), do: :none

  defp level_to_number(:critical), do: 4
  defp level_to_number(:high), do: 3
  defp level_to_number(:medium), do: 2
  defp level_to_number(:low), do: 1
  defp level_to_number(:none), do: 0

  defp generate_threat_id(timestamp) do
    "THR-#{timestamp}-#{:rand.uniform(9999)}"
  end

  defp prune_old_entries do
    size = :ets.info(@table, :size)

    if size > @max_recent do
      keys = :ets.tab2list(@table) |> Enum.map(fn {ts, _} -> ts end) |> Enum.sort()
      to_delete = Enum.take(keys, size - @max_recent)
      Enum.each(to_delete, &:ets.delete(@table, &1))
    end
  rescue
    _ -> :ok
  end

  defp broadcast_threat(threat) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:threat_detected, threat}
    )
  rescue
    _ -> :ok
  end

  defp emit_telemetry(threat) do
    :telemetry.execute(
      [:indrajaal, :security, :threat, :classified],
      %{score: threat.score},
      %{source: threat.source, level: threat.level}
    )
  rescue
    _ -> :ok
  end
end
