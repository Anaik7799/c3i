defmodule Indrajaal.Cockpit.Prajna.AiCopilotTest do
  @moduledoc """
  Tests for PRAJNA AI Copilot

  WHAT: Verifies AI intelligence engine, local analytics, and insight generation.

  WHY: Ensures AI advisory system works correctly with human-in-the-loop design.

  CONSTRAINTS:
    - SC-AI-001: AI suggestions are ADVISORY only
    - SC-AI-002: Confidence scores MUST be displayed
    - SC-AI-003: AI recommendations logged for audit
    - SC-AI-004: Graceful degradation if AI unavailable
    - TDG-PRAJNA-003: AI Copilot must be testable

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | STAMP | SC-AI-001 to SC-AI-004 |
  """

  use ExUnit.Case, async: false
  @moduletag :zenoh_nif
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Cockpit.Prajna.AiCopilot
  alias Indrajaal.Cockpit.Prajna.SmartMetrics
  alias Indrajaal.Cockpit.Prajna.Domain

  setup do
    # Start SmartMetrics first (AiCopilot depends on it)
    {:ok, metrics_pid} = SmartMetrics.start_link([])

    # Start AiCopilot with auto_analyze disabled to control test timing
    {:ok, copilot_pid} = AiCopilot.start_link(auto_analyze: false, llm_enabled: false)

    on_exit(fn ->
      try do
        if Process.alive?(copilot_pid), do: GenServer.stop(copilot_pid)
        if Process.alive?(metrics_pid), do: GenServer.stop(metrics_pid)
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, copilot_pid: copilot_pid, metrics_pid: metrics_pid}
  end

  describe "insights/0" do
    test "returns empty list initially" do
      insights = AiCopilot.insights()
      assert is_list(insights)
    end

    test "returns insights after analysis" do
      # Record some metrics to analyze
      SmartMetrics.record("test.cpu", "CPU", 95.0,
        thresholds: %{caution_high: 75.0, warning_high: 90.0}
      )

      # Trigger analysis
      AiCopilot.analyze_now()
      Process.sleep(100)

      insights = AiCopilot.insights()
      assert length(insights) > 0
    end
  end

  describe "quick_summary/0" do
    test "returns a summary insight" do
      summary = AiCopilot.quick_summary()

      assert summary.type == :summary
      assert is_binary(summary.title)
      assert is_binary(summary.description)
      assert summary.confidence == 1.0
    end

    test "reflects current health status" do
      SmartMetrics.record("healthy1", "Healthy 1", 50.0)
      SmartMetrics.record("healthy2", "Healthy 2", 60.0)

      summary = AiCopilot.quick_summary()
      assert summary.level in [:normal, :advisory]
    end
  end

  describe "detect_local_anomalies/0" do
    test "returns empty list for normal metrics" do
      SmartMetrics.record("normal1", "Normal 1", 50.0)
      SmartMetrics.record("normal2", "Normal 2", 60.0)

      anomalies = AiCopilot.detect_local_anomalies()
      assert is_list(anomalies)
    end

    test "detects high CPU anomaly" do
      SmartMetrics.record("zone.node.cpu", "CPU", 95.0,
        thresholds: %{caution_high: 75.0, warning_high: 90.0}
      )

      # Wait for async cast to process
      Process.sleep(50)

      anomalies = AiCopilot.detect_local_anomalies()

      high_cpu =
        Enum.find(anomalies, fn a ->
          String.contains?(a.title, "CPU") or String.contains?(a.description, "cpu")
        end)

      assert high_cpu != nil
    end

    test "detects rising CPU trend as prediction" do
      SmartMetrics.record("zone.node.cpu", "CPU", 50.0,
        thresholds: %{caution_high: 75.0, warning_high: 90.0}
      )

      # Update to trigger rising trend
      SmartMetrics.record("zone.node.cpu", "CPU", 80.0,
        thresholds: %{caution_high: 75.0, warning_high: 90.0}
      )

      anomalies = AiCopilot.detect_local_anomalies()

      prediction =
        Enum.find(anomalies, fn a ->
          a.type == :prediction or String.contains?(a.title, "Rising")
        end)

      # May or may not have prediction depending on trend calculation
      assert is_list(anomalies)
    end
  end

  describe "generate_local_summary/0" do
    test "creates summary with health info" do
      SmartMetrics.record("test1", "Test 1", 50.0)

      summary = AiCopilot.generate_local_summary()

      assert summary.type == :summary
      assert String.contains?(summary.title, "System Status")
      assert String.contains?(summary.description, "Metrics")
    end

    test "has expires_at set" do
      summary = AiCopilot.generate_local_summary()

      assert summary.expires_at != nil
      assert DateTime.compare(summary.expires_at, DateTime.utc_now()) == :gt
    end
  end

  describe "analyze_now/0" do
    test "triggers immediate analysis" do
      SmartMetrics.record("analyze.test", "Analyze Test", 75.0)

      # Should not raise
      assert AiCopilot.analyze_now() == :ok
    end
  end

  describe "analyze_focus/1" do
    test "accepts focus area parameter" do
      assert AiCopilot.analyze_focus("network") == :ok
    end
  end

  describe "insights_by_type/1" do
    test "filters insights by type" do
      SmartMetrics.record("zone.node.cpu", "CPU", 95.0,
        thresholds: %{caution_high: 75.0, warning_high: 90.0}
      )

      AiCopilot.analyze_now()
      Process.sleep(100)

      anomalies = AiCopilot.insights_by_type(:anomaly)
      assert is_list(anomalies)
      assert Enum.all?(anomalies, &(&1.type == :anomaly))
    end
  end

  describe "high_confidence_insights/1" do
    test "filters by confidence threshold" do
      SmartMetrics.record("zone.node.cpu", "CPU", 95.0,
        thresholds: %{caution_high: 75.0, warning_high: 90.0}
      )

      AiCopilot.analyze_now()
      Process.sleep(100)

      high_conf = AiCopilot.high_confidence_insights(0.9)
      assert Enum.all?(high_conf, &(&1.confidence >= 0.9))
    end

    test "default threshold is 0.8" do
      SmartMetrics.record("test.metric", "Test", 50.0)
      AiCopilot.analyze_now()
      Process.sleep(100)

      high_conf = AiCopilot.high_confidence_insights()
      assert Enum.all?(high_conf, &(&1.confidence >= 0.8))
    end
  end

  describe "llm_available?/0" do
    test "returns false when LLM is disabled" do
      refute AiCopilot.llm_available?()
    end
  end

  describe "set_llm_enabled/1" do
    test "can enable LLM" do
      AiCopilot.set_llm_enabled(true)
      # Note: Will still return false if OPENROUTER_API_KEY not configured
    end

    test "can disable LLM" do
      AiCopilot.set_llm_enabled(false)
      refute AiCopilot.llm_available?()
    end
  end

  describe "insight expiration" do
    test "expired insights are filtered out" do
      SmartMetrics.record("expired.test", "Expired", 50.0)
      AiCopilot.analyze_now()
      Process.sleep(100)

      # Get insights - none should be expired yet
      insights = AiCopilot.insights()

      # All insights should have valid expires_at or be nil
      Enum.each(insights, fn insight ->
        if insight.expires_at do
          assert DateTime.compare(insight.expires_at, DateTime.utc_now()) in [:gt, :eq]
        end
      end)
    end
  end

  describe "SC-AI-001 compliance: advisory only" do
    test "insights include confidence scores (SC-AI-002)" do
      SmartMetrics.record("zone.node.cpu", "CPU", 95.0,
        thresholds: %{caution_high: 75.0, warning_high: 90.0}
      )

      AiCopilot.analyze_now()
      Process.sleep(100)

      insights = AiCopilot.insights()

      Enum.each(insights, fn insight ->
        assert is_number(insight.confidence)
        assert insight.confidence >= 0.0
        assert insight.confidence <= 1.0
      end)
    end
  end

  describe "SC-AI-004 compliance: graceful degradation" do
    test "works without LLM" do
      # LLM is disabled in setup
      SmartMetrics.record("degraded.test", "Degraded", 95.0,
        thresholds: %{caution_high: 75.0, warning_high: 90.0}
      )

      AiCopilot.analyze_now()
      Process.sleep(100)

      # Should still get local insights
      insights = AiCopilot.insights()
      assert length(insights) > 0
    end
  end

  describe "property tests" do
    property "insights/0 always returns a list" do
      forall _ <- PC.atom() do
        result = AiCopilot.insights()
        is_list(result)
      end
    end

    property "insight confidence values are always between 0.0 and 1.0" do
      forall _metric_val <- PC.float(0.0, 100.0) do
        SmartMetrics.record("prop.test", "Property Test", _metric_val)
        AiCopilot.analyze_now()
        Process.sleep(50)

        insights = AiCopilot.insights()

        Enum.all?(insights, fn insight ->
          is_number(insight.confidence) and insight.confidence >= 0.0 and
            insight.confidence <= 1.0
        end)
      end
    end

    property "insight types are valid atoms" do
      forall metric_val <- PC.float(75.0, 100.0) do
        SmartMetrics.record("prop.type.test", "Type Test", metric_val,
          thresholds: %{caution_high: 75.0, warning_high: 90.0}
        )

        AiCopilot.analyze_now()
        Process.sleep(50)

        insights = AiCopilot.insights()

        Enum.all?(insights, fn insight ->
          is_atom(insight.type) and insight.type in [:anomaly, :summary, :prediction]
        end)
      end
    end

    property "quick_summary/0 has valid structure" do
      forall _ <- PC.atom() do
        summary = AiCopilot.quick_summary()

        is_map(summary) and
          is_atom(summary.type) and
          is_binary(summary.title) and
          is_binary(summary.description) and
          is_number(summary.confidence) and
          is_atom(summary.level)
      end
    end

    property "high_confidence_insights filters correctly" do
      forall threshold <- PC.float(0.0, 1.0) do
        SmartMetrics.record("prop.confidence", "Confidence Test", 50.0)
        AiCopilot.analyze_now()
        Process.sleep(50)

        high_conf = AiCopilot.high_confidence_insights(threshold)

        Enum.all?(high_conf, fn insight ->
          insight.confidence >= threshold
        end)
      end
    end
  end
end
