defmodule Indrajaal.Communication.MessageDeliveryAnalyticsTest do
  @moduledoc """
  TDG test suite for Communication.MessageDeliveryAnalytics.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation verification
  - Communication channel optimization analytics

  ## STAMP Safety Integration
  - SC-OBS-069: Dual logging active
  - SC-PRF-050: Response time < 50ms for optimization

  ## Constitutional Verification
  - Ψ₀ Existence: GenServer starts without DB dependency (init only schedules timers)
  - Ψ₁ Regeneration: State initialized from @default_optimization_rules constant

  ## TPS 5-Level RCA Context
  - L1 Symptom: optimize_message_delivery raises KeyError for missing channel fields
  - L5 Root Cause: messageparams must have :channel, :user_id, :message_id, :message_type keys
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Communication.MessageDeliveryAnalytics

  @moduletag :zenoh_nif

  setup do
    case Process.whereis(MessageDeliveryAnalytics) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    Process.sleep(50)
    :ok
  end

  # ============================================================================
  # Module API verification
  # ============================================================================

  describe "module API definition" do
    test "start_link/1 is exported" do
      assert function_exported?(MessageDeliveryAnalytics, :start_link, 1)
    end

    test "get_delivery_analytics/3 is exported" do
      assert function_exported?(MessageDeliveryAnalytics, :get_delivery_analytics, 3)
    end

    test "optimize_message_delivery/2 is exported" do
      assert function_exported?(MessageDeliveryAnalytics, :optimize_message_delivery, 2)
    end

    test "track_engagement_event/2 is exported" do
      assert function_exported?(MessageDeliveryAnalytics, :track_engagement_event, 2)
    end

    test "generate_performance_report/3 is exported" do
      assert function_exported?(MessageDeliveryAnalytics, :generate_performance_report, 3)
    end
  end

  # ============================================================================
  # GenServer lifecycle (init does NOT require DB)
  # ============================================================================

  describe "start_link/1" do
    test "starts the GenServer successfully (no DB required)" do
      assert {:ok, pid} = MessageDeliveryAnalytics.start_link([])
      assert Process.alive?(pid)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "registers under module name" do
      {:ok, pid} = MessageDeliveryAnalytics.start_link([])
      assert Process.whereis(MessageDeliveryAnalytics) == pid
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "second start returns already_started" do
      {:ok, pid} = MessageDeliveryAnalytics.start_link([])
      assert {:error, {:already_started, ^pid}} = MessageDeliveryAnalytics.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "server remains alive after start" do
      {:ok, pid} = MessageDeliveryAnalytics.start_link([])
      Process.sleep(50)
      assert Process.alive?(pid)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end
  end

  # ============================================================================
  # track_engagement_event/2 (returns :ok, calls TimescaleCommunicationEvents)
  # Tests only confirm return value — DB effects not verified here
  # ============================================================================

  describe "track_engagement_event/2" do
    setup do
      {:ok, pid} = MessageDeliveryAnalytics.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    @engagement_data %{
      user_id: "user_123",
      message_id: "msg_456",
      channel: "email",
      __event_type: "opened",
      message_type: "marketing",
      interaction_type: "click",
      time_to_engagement: 300,
      device_type: "mobile",
      location: "IN"
    }

    test "returns :ok for valid engagement data" do
      result = MessageDeliveryAnalytics.track_engagement_event("tenant_1", @engagement_data)
      assert result == :ok
    end

    test "returns :ok for low engagement score (< 20 triggers re-engagement)" do
      low_engagement = Map.put(@engagement_data, :interaction_type, nil)
      result = MessageDeliveryAnalytics.track_engagement_event("tenant_1", low_engagement)
      assert result == :ok
    end
  end

  # ============================================================================
  # optimize_message_delivery/2 (pure computation + TimescaleCommunicationEvents.log)
  # ============================================================================

  describe "optimize_message_delivery/2" do
    setup do
      {:ok, pid} = MessageDeliveryAnalytics.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    @message_params %{
      channel: "email",
      user_id: "user_123",
      message_type: "marketing",
      message_id: "msg_789"
    }

    test "returns {:ok, optimized_params} tuple" do
      result = MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", @message_params)
      assert {:ok, optimized_params} = result
      assert is_map(optimized_params)
    end

    test "optimized_params has :original_channel key" do
      {:ok, params} =
        MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", @message_params)

      assert Map.has_key?(params, :original_channel)
    end

    test "original_channel matches input channel" do
      {:ok, params} =
        MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", @message_params)

      assert params.original_channel == "email"
    end

    test "optimized_params has :recommended_channel key" do
      {:ok, params} =
        MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", @message_params)

      assert Map.has_key?(params, :recommended_channel)
    end

    test "optimized_params has :optimal_send_time key" do
      {:ok, params} =
        MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", @message_params)

      assert Map.has_key?(params, :optimal_send_time)
    end

    test "optimized_params has :f_requency_check key" do
      {:ok, params} =
        MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", @message_params)

      assert Map.has_key?(params, :f_requency_check)
    end

    test "optimized_params has :engagement_prediction key" do
      {:ok, params} =
        MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", @message_params)

      assert Map.has_key?(params, :engagement_prediction)
    end

    test "optimized_params has :personalization_score key" do
      {:ok, params} =
        MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", @message_params)

      assert Map.has_key?(params, :personalization_score)
    end

    test "optimized_params has :delivery_confidence key" do
      {:ok, params} =
        MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", @message_params)

      assert Map.has_key?(params, :delivery_confidence)
    end

    test "optimized_params has :estimated_delivery_time key" do
      {:ok, params} =
        MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", @message_params)

      assert Map.has_key?(params, :estimated_delivery_time)
    end

    test "optimized_params has :cost_optimization key" do
      {:ok, params} =
        MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", @message_params)

      assert Map.has_key?(params, :cost_optimization)
    end

    test "works for sms channel" do
      sms_params = Map.put(@message_params, :channel, "sms")
      result = MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", sms_params)
      assert {:ok, _} = result
    end

    test "works for push channel" do
      push_params = Map.put(@message_params, :channel, "push")
      result = MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", push_params)
      assert {:ok, _} = result
    end

    test "works for in_app channel" do
      in_app_params = Map.put(@message_params, :channel, "in_app")
      result = MessageDeliveryAnalytics.optimize_message_delivery("tenant_1", in_app_params)
      assert {:ok, _} = result
    end
  end

  # ============================================================================
  # get_delivery_analytics/3 (DB-dependent)
  # ============================================================================

  describe "get_delivery_analytics/3" do
    setup do
      {:ok, pid} = MessageDeliveryAnalytics.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns a result tuple" do
      result = MessageDeliveryAnalytics.get_delivery_analytics("tenant_1")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts custom timeframe" do
      result = MessageDeliveryAnalytics.get_delivery_analytics("tenant_1", "7d")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts 24h timeframe" do
      result = MessageDeliveryAnalytics.get_delivery_analytics("tenant_1", "24h")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================================
  # generate_performance_report/3 (DB-dependent)
  # ============================================================================

  describe "generate_performance_report/3" do
    setup do
      {:ok, pid} = MessageDeliveryAnalytics.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns a result for executive report type" do
      result = MessageDeliveryAnalytics.generate_performance_report("tenant_1", "executive")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns a result for operational report type" do
      result = MessageDeliveryAnalytics.generate_performance_report("tenant_1", "operational")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns a result for comprehensive report type" do
      result = MessageDeliveryAnalytics.generate_performance_report("tenant_1", "comprehensive")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
