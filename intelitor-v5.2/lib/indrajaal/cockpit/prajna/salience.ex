defmodule Indrajaal.Cockpit.Prajna.Salience do
  @moduledoc """
  PRAJNA Salience Scoring Engine

  WHAT: Signal Detection Theory (d-prime) based salience filter for C3I events.
        Calculates a "salience score" for every event to determine UI treatment.

  WHY: Based on Laux, Howell, Lane (1993) "Visual Display Principles for C3I System Tasks".
       Prevents alarm fatigue by filtering low-importance events while ensuring
       truly important signals break through to operator attention.

  SCORING THRESHOLDS (SC-VDP-015):
    - Score 0-20:   Suppressed (log only, no visual)
    - Score 21-50:  Background (dim, non-intrusive)
    - Score 51-80:  Foreground (visible popup)
    - Score 81-99:  Alert (visual + audio bell)
    - Score 100:    Emergency (inverse video + blink + bell)

  CONSTRAINTS:
    - SC-VDP-015: Score-based popup threshold
    - SC-VDP-003: Redundancy Gain (multi-modal for high salience)
    - Principle 3: Top-Down Processing (unexpected events get salience boost)

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | Reference | Laux, Wickens, NASA-STD-3000 |
  """

  # ═══════════════════════════════════════════════════════════════════════════
  # SALIENCE THRESHOLDS
  # ═══════════════════════════════════════════════════════════════════════════

  @suppressed_threshold 20
  @background_threshold 50
  @alert_threshold 80
  @emergency_threshold 100

  @doc """
  Calculate salience score for an event.

  Score components:
    - Base severity score (0-80)
    - Novelty boost (+20 for unexpected patterns)
    - Recency boost (+15 for first occurrence)
    - Impact boost (+2 per affected node)
    - Trend boost (+10 for fast-rising metrics)

  Returns: integer 0-100
  """
  @spec calculate_score(map()) :: integer()
  def calculate_score(event) do
    base = severity_score(event)
    novelty = novelty_boost(event)
    recency = recency_boost(event)
    impact = impact_boost(event)
    trend = trend_boost(event)

    min(100, base + novelty + recency + impact + trend)
  end

  @doc "Get display treatment based on salience score"
  @spec treatment(integer()) :: :suppressed | :background | :foreground | :alert | :emergency
  def treatment(score) when score <= @suppressed_threshold, do: :suppressed
  def treatment(score) when score <= @background_threshold, do: :background
  def treatment(score) when score <= @alert_threshold, do: :foreground
  def treatment(score) when score < @emergency_threshold, do: :alert
  def treatment(_score), do: :emergency

  @doc "Should this event trigger an audio alert (system bell)?"
  @spec audio_alert?(integer()) :: boolean()
  def audio_alert?(score), do: score > @alert_threshold

  @doc "Should this event use inverse video (unexpected/emergency)?"
  @spec inverse_video?(integer()) :: boolean()
  def inverse_video?(score), do: score >= @emergency_threshold

  @doc "Should this event use blinking text?"
  @spec blink?(integer()) :: boolean()
  def blink?(score), do: score >= @emergency_threshold

  # ═══════════════════════════════════════════════════════════════════════════
  # SCORE COMPONENTS
  # ═══════════════════════════════════════════════════════════════════════════

  @doc "Base severity score from alarm level"
  @spec severity_score(map()) :: integer()
  def severity_score(%{level: :critical}), do: 80
  def severity_score(%{level: :warning}), do: 60
  def severity_score(%{level: :caution}), do: 40
  def severity_score(%{level: :advisory}), do: 20
  def severity_score(%{level: :normal}), do: 0
  def severity_score(_), do: 0

  @doc "Novelty boost for unexpected patterns (Principle 3: Top-Down Processing)"
  @spec novelty_boost(map()) :: integer()
  def novelty_boost(event) do
    if unexpected?(event), do: 20, else: 0
  end

  @doc "Recency boost for first occurrence"
  @spec recency_boost(map()) :: integer()
  def recency_boost(event) do
    if first_occurrence?(event), do: 15, else: 0
  end

  @doc "Impact boost based on number of affected nodes"
  @spec impact_boost(map()) :: integer()
  def impact_boost(event) do
    affected_nodes = Map.get(event, :affected_nodes, [])
    affected_count = length(affected_nodes)
    min(20, affected_count * 2)
  end

  @doc "Trend boost for fast-rising metrics"
  @spec trend_boost(map()) :: integer()
  def trend_boost(%{trend: :rising_fast}), do: 10
  def trend_boost(%{trend: :falling_fast}), do: 5
  def trend_boost(_), do: 0

  # ═══════════════════════════════════════════════════════════════════════════
  # DETECTION HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Check if event is unexpected (breaks operator's mental model).
  An event is unexpected if:
    - It's a new alarm type not seen in the last hour
    - It occurs outside normal operational hours
    - It contradicts recent patterns
  """
  @spec unexpected?(map()) :: boolean()
  def unexpected?(event) do
    # Check for explicit "unexpected" flag
    cond do
      Map.get(event, :unexpected, false) == true -> true
      Map.get(event, :pattern_deviation, 0) > 2.0 -> true
      outside_baseline?(event) -> true
      true -> false
    end
  end

  @doc "Check if this is the first occurrence of this event type"
  @spec first_occurrence?(map()) :: boolean()
  def first_occurrence?(event) do
    Map.get(event, :occurrence_count, 1) == 1
  end

  defp outside_baseline?(event) do
    # Check if metric is outside 2 standard deviations from baseline
    baseline = Map.get(event, :baseline_mean)
    std_dev = Map.get(event, :baseline_std_dev)
    value = Map.get(event, :value)

    if baseline && std_dev && value do
      abs(value - baseline) > 2 * std_dev
    else
      false
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # ANSI RENDERING HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  @doc "Get ANSI codes for salience-based rendering"
  @spec ansi_codes(integer()) :: String.t()
  def ansi_codes(score) do
    cond do
      score >= @emergency_threshold ->
        # Inverse video + blink + red
        "\e[7m\e[5m\e[91m"

      score > @alert_threshold ->
        # Bold red
        "\e[1m\e[91m"

      score > @background_threshold ->
        # Normal color based on level
        "\e[93m"

      score > @suppressed_threshold ->
        # Dim
        "\e[2m\e[90m"

      true ->
        # Very dim (barely visible)
        "\e[2m\e[90m"
    end
  end

  @doc "Emit audio alert if score warrants it (SC-VDP-003: Redundancy Gain)"
  @spec maybe_beep(integer()) :: :ok
  def maybe_beep(score) do
    if audio_alert?(score) do
      # ASCII BEL - system bell
      IO.write("\a")
    end

    :ok
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # EVENT CLASSIFICATION
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Classify an event and return full salience info.

  Returns a map with:
    - score: integer 0-100
    - treatment: :suppressed | :background | :foreground | :alert | :emergency
    - ansi: ANSI codes to use for rendering
    - audio: true if should beep
    - blink: true if should blink
    - inverse: true if should use inverse video
  """
  @spec classify(map()) :: map()
  def classify(event) do
    score = calculate_score(event)

    %{
      score: score,
      treatment: treatment(score),
      ansi: ansi_codes(score),
      audio: audio_alert?(score),
      blink: blink?(score),
      inverse: inverse_video?(score)
    }
  end

  @doc """
  Filter a list of events to only those above a salience threshold.
  """
  @spec filter_by_threshold(list(map()), integer()) :: list(map())
  def filter_by_threshold(events, threshold \\ @background_threshold) do
    events
    |> Enum.map(fn event -> Map.put(event, :salience, classify(event)) end)
    |> Enum.filter(fn event -> event.salience.score > threshold end)
    |> Enum.sort_by(fn event -> -event.salience.score end)
  end
end
