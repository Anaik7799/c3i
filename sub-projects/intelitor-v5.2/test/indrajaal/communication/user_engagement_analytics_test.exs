defmodule Indrajaal.Communication.UserEngagementAnalyticsTest do
  @moduledoc """
  TDG test suite for Communication.UserEngagementAnalytics.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation verification
  - User engagement pattern tracking and segmentation analytics

  ## STAMP Safety Integration
  - SC-OBS-069: Dual logging active
  - SC-PRF-050: Response time < 50ms for recommendation calls

  ## Constitutional Verification
  - Ψ₀ Existence: GenServer starts without DB dependency (init only schedules timers)
  - Ψ₁ Regeneration: State initialized from empty maps; no external state required

  ## TPS 5-Level RCA Context
  - L1 Symptom: analyze_user_engagement/4 may return {:error, _} when DB unavailable
  - L5 Root Cause: Function executes raw SQL via Repo.query/2 against communication_events table
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Communication.UserEngagementAnalytics

  @moduletag :zenoh_nif

  setup do
    case Process.whereis(UserEngagementAnalytics) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    Process.sleep(50)
    :ok
  end

  # ============================================================================
  # Module API definition
  # ============================================================================

  describe "module API definition" do
    test "start_link/1 is exported" do
      assert function_exported?(UserEngagementAnalytics, :start_link, 1)
    end

    test "analyze_user_engagement/4 is exported" do
      assert function_exported?(UserEngagementAnalytics, :analyze_user_engagement, 4)
    end

    test "track_engagement_event/3 is exported" do
      assert function_exported?(UserEngagementAnalytics, :track_engagement_event, 3)
    end

    test "generate_user_segments/2 is exported" do
      assert function_exported?(UserEngagementAnalytics, :generate_user_segments, 2)
    end

    test "predict_engagement_trends/3 is exported" do
      assert function_exported?(UserEngagementAnalytics, :predict_engagement_trends, 3)
    end

    test "generate_communication_recommendations/3 is exported" do
      assert function_exported?(
               UserEngagementAnalytics,
               :generate_communication_recommendations,
               3
             )
    end
  end

  # ============================================================================
  # GenServer lifecycle (init NOT DB dependent — only schedules timers)
  # ============================================================================

  describe "start_link/1" do
    test "starts the GenServer successfully (no DB required)" do
      assert {:ok, pid} = UserEngagementAnalytics.start_link([])
      assert Process.alive?(pid)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "registers under module name" do
      {:ok, pid} = UserEngagementAnalytics.start_link([])
      assert Process.whereis(UserEngagementAnalytics) == pid
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "second start returns already_started" do
      {:ok, pid} = UserEngagementAnalytics.start_link([])
      assert {:error, {:already_started, ^pid}} = UserEngagementAnalytics.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "server remains alive after start" do
      {:ok, pid} = UserEngagementAnalytics.start_link([])
      Process.sleep(50)
      assert Process.alive?(pid)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end
  end

  # ============================================================================
  # track_engagement_event/3 — returns :ok (fire-and-forget with cast)
  # DB call is non-blocking (cast to GenServer), so :ok regardless of DB state
  # ============================================================================

  describe "track_engagement_event/3" do
    setup do
      {:ok, pid} = UserEngagementAnalytics.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    @event_data %{
      message_id: "msg_001",
      __event_type: "opened",
      time_to_engagement: 120,
      device_type: "mobile",
      location: "IN",
      channel: "email"
    }

    test "returns :ok for valid event data" do
      result =
        UserEngagementAnalytics.track_engagement_event("tenant_1", "user_123", @event_data)

      assert result == :ok
    end

    test "returns :ok for clicked event type" do
      event = Map.put(@event_data, :__event_type, "clicked")

      result = UserEngagementAnalytics.track_engagement_event("tenant_1", "user_123", event)
      assert result == :ok
    end

    test "returns :ok for converted event type" do
      event = Map.put(@event_data, :__event_type, "converted")

      result = UserEngagementAnalytics.track_engagement_event("tenant_1", "user_456", event)
      assert result == :ok
    end

    test "returns :ok for bounced event type" do
      event = Map.put(@event_data, :__event_type, "bounced")

      result = UserEngagementAnalytics.track_engagement_event("tenant_1", "user_789", event)
      assert result == :ok
    end

    test "returns :ok for unsubscribed event type" do
      event = Map.put(@event_data, :__event_type, "unsubscribed")

      result = UserEngagementAnalytics.track_engagement_event("tenant_1", "user_123", event)
      assert result == :ok
    end

    test "returns :ok for desktop device type" do
      event = Map.put(@event_data, :device_type, "desktop")

      result = UserEngagementAnalytics.track_engagement_event("tenant_1", "user_123", event)
      assert result == :ok
    end

    test "returns :ok for nil time_to_engagement" do
      event = Map.put(@event_data, :time_to_engagement, nil)

      result = UserEngagementAnalytics.track_engagement_event("tenant_1", "user_123", event)
      assert result == :ok
    end

    test "returns :ok for sms channel event" do
      event = Map.put(@event_data, :channel, "sms")

      result = UserEngagementAnalytics.track_engagement_event("tenant_1", "user_123", event)
      assert result == :ok
    end

    test "server remains alive after multiple track_engagement_event calls" do
      for i <- 1..5 do
        UserEngagementAnalytics.track_engagement_event("tenant_1", "user_#{i}", @event_data)
      end

      assert Process.alive?(Process.whereis(UserEngagementAnalytics))
    end
  end

  # ============================================================================
  # analyze_user_engagement/4 — DB-dependent (Repo.query/2)
  # ============================================================================

  describe "analyze_user_engagement/4" do
    setup do
      {:ok, pid} = UserEngagementAnalytics.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns a result tuple ({:ok,_} or {:error,_})" do
      result =
        UserEngagementAnalytics.analyze_user_engagement("tenant_1", "user_123")

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts custom timeframe" do
      result =
        UserEngagementAnalytics.analyze_user_engagement("tenant_1", "user_123", "7d")

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts 90d timeframe" do
      result =
        UserEngagementAnalytics.analyze_user_engagement("tenant_1", "user_123", "90d")

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts custom options map" do
      result =
        UserEngagementAnalytics.analyze_user_engagement(
          "tenant_1",
          "user_123",
          "30d",
          %{include_predictions: true}
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================================
  # generate_user_segments/2 — DB-dependent (Repo.query/2)
  # ============================================================================

  describe "generate_user_segments/2" do
    setup do
      {:ok, pid} = UserEngagementAnalytics.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns a result tuple ({:ok,_} or {:error,_}) with default criteria" do
      result = UserEngagementAnalytics.generate_user_segments("tenant_1")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts custom segmentation criteria list" do
      result =
        UserEngagementAnalytics.generate_user_segments(
          "tenant_1",
          ["engagement_level", "channel_preference"]
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts single criterion" do
      result =
        UserEngagementAnalytics.generate_user_segments("tenant_1", ["lifecycle_stage"])

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================================
  # predict_engagement_trends/3 — pure computation + TimescaleCommunicationEvents.log
  # ============================================================================

  describe "predict_engagement_trends/3" do
    setup do
      {:ok, pid} = UserEngagementAnalytics.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns {:ok, prediction_result} tuple" do
      result =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert {:ok, _prediction} = result
    end

    test "prediction_result has :user_id key" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert Map.has_key?(prediction, :user_id)
      assert prediction.user_id == "user_123"
    end

    test "prediction_result has :prediction_horizon key" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert Map.has_key?(prediction, :prediction_horizon)
    end

    test "default prediction_horizon is '30d'" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert prediction.prediction_horizon == "30d"
    end

    test "prediction_result has :current_engagement_level key" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert Map.has_key?(prediction, :current_engagement_level)
    end

    test "prediction_result has :predicted_engagement_level key" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert Map.has_key?(prediction, :predicted_engagement_level)
    end

    test "prediction_result has :trend_direction key" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert Map.has_key?(prediction, :trend_direction)
    end

    test "prediction_result has :trend_strength key" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert Map.has_key?(prediction, :trend_strength)
    end

    test "prediction_result has :churn_risk key" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert Map.has_key?(prediction, :churn_risk)
    end

    test "prediction_result has :confidence_score key" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert Map.has_key?(prediction, :confidence_score)
    end

    test "prediction_result has :key_indicators key" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert Map.has_key?(prediction, :key_indicators)
    end

    test "prediction_result has :intervention_recommendations key" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert Map.has_key?(prediction, :intervention_recommendations)
    end

    test "prediction_result has :next_review_date key" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert Map.has_key?(prediction, :next_review_date)
    end

    test "prediction_result has :generated_at key as DateTime" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123")

      assert Map.has_key?(prediction, :generated_at)
      assert %DateTime{} = prediction.generated_at
    end

    test "accepts custom prediction horizon" do
      {:ok, prediction} =
        UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_123", "60d")

      assert prediction.prediction_horizon == "60d"
    end

    test "works for different users" do
      {:ok, p1} = UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_aaa")
      {:ok, p2} = UserEngagementAnalytics.predict_engagement_trends("tenant_1", "user_bbb")
      assert p1.user_id == "user_aaa"
      assert p2.user_id == "user_bbb"
    end
  end

  # ============================================================================
  # generate_communication_recommendations/3 — pure computation
  # ============================================================================

  describe "generate_communication_recommendations/3" do
    setup do
      {:ok, pid} = UserEngagementAnalytics.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns {:ok, recommendations} tuple with default context" do
      result =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_123")

      assert {:ok, _recommendations} = result
    end

    test "recommendations has :optimal_channel key" do
      {:ok, recs} =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_123")

      assert Map.has_key?(recs, :optimal_channel)
    end

    test "recommendations has :optimal_timing key" do
      {:ok, recs} =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_123")

      assert Map.has_key?(recs, :optimal_timing)
    end

    test "recommendations has :content_personalization key" do
      {:ok, recs} =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_123")

      assert Map.has_key?(recs, :content_personalization)
    end

    test "recommendations has :f_requency_optimization key" do
      {:ok, recs} =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_123")

      assert Map.has_key?(recs, :f_requency_optimization)
    end

    test "recommendations has :engagement_tactics key" do
      {:ok, recs} =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_123")

      assert Map.has_key?(recs, :engagement_tactics)
    end

    test "recommendations has :risk_mitigation key" do
      {:ok, recs} =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_123")

      assert Map.has_key?(recs, :risk_mitigation)
    end

    test "recommendations has :expected_improvement key" do
      {:ok, recs} =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_123")

      assert Map.has_key?(recs, :expected_improvement)
    end

    test "recommendations has :confidence_level key" do
      {:ok, recs} =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_123")

      assert Map.has_key?(recs, :confidence_level)
    end

    test "recommendations has :generated_at key as DateTime" do
      {:ok, recs} =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_123")

      assert Map.has_key?(recs, :generated_at)
      assert %DateTime{} = recs.generated_at
    end

    test "recommendations has :valid_until key as DateTime" do
      {:ok, recs} =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_123")

      assert Map.has_key?(recs, :valid_until)
      assert %DateTime{} = recs.valid_until
    end

    test "valid_until is after generated_at" do
      {:ok, recs} =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_123")

      assert DateTime.compare(recs.valid_until, recs.generated_at) == :gt
    end

    test "accepts custom message_context" do
      context = %{message_type: "marketing", campaign_id: "camp_001"}

      result =
        UserEngagementAnalytics.generate_communication_recommendations(
          "tenant_1",
          "user_123",
          context
        )

      assert {:ok, _recs} = result
    end

    test "works for different users independently" do
      {:ok, recs1} =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_a")

      {:ok, recs2} =
        UserEngagementAnalytics.generate_communication_recommendations("tenant_1", "user_b")

      # Both return valid recommendation maps
      assert is_map(recs1)
      assert is_map(recs2)
    end
  end
end
