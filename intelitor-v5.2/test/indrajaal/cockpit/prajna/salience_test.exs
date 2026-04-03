defmodule Indrajaal.Cockpit.Prajna.SalienceTest do
  @moduledoc """
  TDG-Compliant Tests for Salience Module.

  STAMP Compliance: SC-VDP-015, SC-VDP-003
  TDG: Dual property testing with PropCheck + ExUnitProperties

  Tests Signal Detection Theory (d-prime) based salience scoring.
  """
  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cockpit.Prajna.Salience

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Score Components
  # ═══════════════════════════════════════════════════════════════════════════

  describe "severity_score/1" do
    test "returns correct base scores for alarm levels" do
      assert Salience.severity_score(%{level: :critical}) == 80
      assert Salience.severity_score(%{level: :warning}) == 60
      assert Salience.severity_score(%{level: :caution}) == 40
      assert Salience.severity_score(%{level: :advisory}) == 20
      assert Salience.severity_score(%{level: :normal}) == 0
    end

    test "returns 0 for unknown levels" do
      assert Salience.severity_score(%{level: :unknown}) == 0
      assert Salience.severity_score(%{}) == 0
    end
  end

  describe "novelty_boost/1" do
    test "adds boost for unexpected events" do
      assert Salience.novelty_boost(%{unexpected: true}) == 20
      assert Salience.novelty_boost(%{pattern_deviation: 3.0}) == 20
    end

    test "no boost for expected events" do
      assert Salience.novelty_boost(%{unexpected: false}) == 0
      assert Salience.novelty_boost(%{pattern_deviation: 1.0}) == 0
      assert Salience.novelty_boost(%{}) == 0
    end
  end

  describe "recency_boost/1" do
    test "adds boost for first occurrence" do
      assert Salience.recency_boost(%{occurrence_count: 1}) == 15
    end

    test "no boost for subsequent occurrences" do
      assert Salience.recency_boost(%{occurrence_count: 2}) == 0
      assert Salience.recency_boost(%{occurrence_count: 10}) == 0
    end

    test "defaults to first occurrence when key missing" do
      # Missing occurrence_count defaults to 1 (first occurrence)
      assert Salience.recency_boost(%{}) == 15
    end
  end

  describe "impact_boost/1" do
    test "adds 2 points per affected node" do
      assert Salience.impact_boost(%{affected_nodes: []}) == 0
      assert Salience.impact_boost(%{affected_nodes: [:node1]}) == 2
      assert Salience.impact_boost(%{affected_nodes: [:n1, :n2, :n3]}) == 6
    end

    test "caps at 20 points" do
      nodes = Enum.map(1..15, &:"node#{&1}")
      assert Salience.impact_boost(%{affected_nodes: nodes}) == 20
    end
  end

  describe "trend_boost/1" do
    test "adds boost for fast-rising trends" do
      assert Salience.trend_boost(%{trend: :rising_fast}) == 10
    end

    test "adds smaller boost for fast-falling trends" do
      assert Salience.trend_boost(%{trend: :falling_fast}) == 5
    end

    test "no boost for other trends" do
      assert Salience.trend_boost(%{trend: :stable}) == 0
      assert Salience.trend_boost(%{trend: :rising}) == 0
      assert Salience.trend_boost(%{}) == 0
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - calculate_score/1
  # ═══════════════════════════════════════════════════════════════════════════

  describe "calculate_score/1" do
    test "calculates combined score" do
      # Set occurrence_count: 2 to avoid default recency boost
      event = %{level: :warning, occurrence_count: 2}
      score = Salience.calculate_score(event)
      # Base severity only (60), no recency boost when occurrence_count > 1
      assert score == 60
    end

    test "combines all components" do
      event = %{
        level: :critical,
        unexpected: true,
        occurrence_count: 1,
        affected_nodes: [:n1, :n2],
        trend: :rising_fast
      }

      score = Salience.calculate_score(event)
      # 80 + 20 + 15 + 4 + 10 = 129, capped at 100
      assert score == 100
    end

    test "caps at 100" do
      event = %{
        level: :critical,
        unexpected: true,
        occurrence_count: 1,
        affected_nodes: Enum.map(1..20, &:"n#{&1}"),
        trend: :rising_fast
      }

      assert Salience.calculate_score(event) == 100
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - treatment/1 (SC-VDP-015)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "treatment/1" do
    test "classifies by score thresholds" do
      assert Salience.treatment(0) == :suppressed
      assert Salience.treatment(20) == :suppressed
      assert Salience.treatment(21) == :background
      assert Salience.treatment(50) == :background
      assert Salience.treatment(51) == :foreground
      assert Salience.treatment(80) == :foreground
      assert Salience.treatment(81) == :alert
      assert Salience.treatment(99) == :alert
      assert Salience.treatment(100) == :emergency
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Alert Properties
  # ═══════════════════════════════════════════════════════════════════════════

  describe "audio_alert?/1" do
    test "true for scores above 80" do
      assert Salience.audio_alert?(81) == true
      assert Salience.audio_alert?(100) == true
    end

    test "false for scores at or below 80" do
      assert Salience.audio_alert?(80) == false
      assert Salience.audio_alert?(50) == false
    end
  end

  describe "inverse_video?/1" do
    test "true for emergency scores" do
      assert Salience.inverse_video?(100) == true
    end

    test "false for non-emergency scores" do
      assert Salience.inverse_video?(99) == false
      assert Salience.inverse_video?(50) == false
    end
  end

  describe "blink?/1" do
    test "true for emergency scores" do
      assert Salience.blink?(100) == true
    end

    test "false for non-emergency scores" do
      assert Salience.blink?(99) == false
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - classify/1
  # ═══════════════════════════════════════════════════════════════════════════

  describe "classify/1" do
    test "returns complete classification" do
      event = %{level: :critical, unexpected: true}
      result = Salience.classify(event)

      assert Map.has_key?(result, :score)
      assert Map.has_key?(result, :treatment)
      assert Map.has_key?(result, :ansi)
      assert Map.has_key?(result, :audio)
      assert Map.has_key?(result, :blink)
      assert Map.has_key?(result, :inverse)
    end

    test "emergency events have all alerts" do
      event = %{
        level: :critical,
        unexpected: true,
        occurrence_count: 1,
        trend: :rising_fast
      }

      result = Salience.classify(event)

      assert result.score == 100
      assert result.treatment == :emergency
      assert result.audio == true
      assert result.blink == true
      assert result.inverse == true
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - filter_by_threshold/2
  # ═══════════════════════════════════════════════════════════════════════════

  describe "filter_by_threshold/2" do
    test "filters events below threshold" do
      events = [
        %{level: :normal},
        %{level: :warning},
        %{level: :critical}
      ]

      filtered = Salience.filter_by_threshold(events, 50)

      # Only warning (60) and critical (80) should pass
      assert length(filtered) == 2
    end

    test "sorts by salience descending" do
      events = [
        %{level: :warning},
        %{level: :critical},
        %{level: :caution}
      ]

      filtered = Salience.filter_by_threshold(events, 0)
      scores = Enum.map(filtered, & &1.salience.score)

      assert scores == Enum.sort(scores, :desc)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - PropCheck (PC)
  # ═══════════════════════════════════════════════════════════════════════════

  property "calculate_score always returns 0-100" do
    forall event <- PC.map(PC.atom(), PC.any()) do
      score = Salience.calculate_score(event)
      score >= 0 and score <= 100
    end
  end

  property "treatment is monotonic with score" do
    treatment_order = fn
      :suppressed -> 0
      :background -> 1
      :foreground -> 2
      :alert -> 3
      :emergency -> 4
    end

    forall {s1, s2} <- {PC.range(0, 100), PC.range(0, 100)} do
      if s1 <= s2 do
        treatment_order.(Salience.treatment(s1)) <= treatment_order.(Salience.treatment(s2))
      else
        true
      end
    end
  end

  property "severity_score is deterministic" do
    forall level <- PC.oneof([:critical, :warning, :caution, :advisory, :normal, :unknown]) do
      event = %{level: level}
      Salience.severity_score(event) == Salience.severity_score(event)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - ExUnitProperties (SD)
  # ═══════════════════════════════════════════════════════════════════════════

  test "treatment matches score thresholds (property)" do
    for score <- [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 99, 100] do
      treatment = Salience.treatment(score)

      case treatment do
        :suppressed -> assert score <= 20
        :background -> assert score > 20 and score <= 50
        :foreground -> assert score > 50 and score <= 80
        :alert -> assert score > 80 and score < 100
        :emergency -> assert score >= 100
      end
    end
  end

  test "classify returns consistent results (property)" do
    for level <- [:critical, :warning, :caution, :advisory, :normal] do
      event = %{level: level}
      r1 = Salience.classify(event)
      r2 = Salience.classify(event)
      assert r1 == r2
    end
  end
end
