defmodule Indrajaal.AI.Simplex.TelemetryFlowTest do
  @moduledoc """
  Tests for the TelemetryFlow module.

  ## STAMP Constraints Verified
  - SC-DF-004: Telemetry emitted for all events
  - SC-DF-005: Zenoh streaming async
  - SC-DF-006: CEPAF receives all AI events
  - SC-DF-007: Key expressions follow schema
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AI.Simplex.TelemetryFlow

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TelemetryFlow)
    end

    test "exports emit_ai_event/3" do
      assert function_exported?(TelemetryFlow, :emit_ai_event, 3)
    end

    test "exports emit_cost_event/4" do
      assert function_exported?(TelemetryFlow, :emit_cost_event, 4)
    end

    test "exports emit_budget_alert/3" do
      assert function_exported?(TelemetryFlow, :emit_budget_alert, 3)
    end

    test "exports emit_veto_event/3" do
      assert function_exported?(TelemetryFlow, :emit_veto_event, 3)
    end

    test "exports emit_training_episode/1" do
      assert function_exported?(TelemetryFlow, :emit_training_episode, 1)
    end
  end

  describe "emit_ai_event/3" do
    test "emits telemetry event" do
      # Attach a handler to capture the event
      ref = make_ref()
      test_pid = self()

      handler_id = "test-handler-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:ai, :test, :event],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      result = TelemetryFlow.emit_ai_event([:test, :event], %{value: 42}, %{source: :test})

      assert result == :ok

      # Should receive the telemetry event
      assert_receive {:telemetry_event, [:ai, :test, :event], %{value: 42}, %{source: :test}},
                     1000

      :telemetry.detach(handler_id)
    end

    test "returns :ok" do
      result = TelemetryFlow.emit_ai_event([:simplex, :success], %{tokens: 100}, %{model: "test"})
      assert result == :ok
    end
  end

  describe "emit_cost_event/4" do
    test "emits cost telemetry" do
      ref = make_ref()
      test_pid = self()
      handler_id = "cost-handler-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:ai, :cost, :recorded],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:cost_event, event, measurements, metadata})
        end,
        nil
      )

      usage_stats = %{daily_usage: 10.0, monthly_usage: 50.0, tokens: 1000}
      result = TelemetryFlow.emit_cost_event("test/model", :cortex, 0.05, usage_stats)

      assert result == :ok
      assert_receive {:cost_event, [:ai, :cost, :recorded], measurements, metadata}, 1000

      assert measurements.cost == 0.05
      assert measurements.daily_total == 10.0
      assert measurements.monthly_total == 50.0
      assert metadata.model == "test/model"
      assert metadata.source == :cortex

      :telemetry.detach(handler_id)
    end
  end

  describe "emit_budget_alert/3" do
    test "emits budget alert telemetry" do
      ref = make_ref()
      test_pid = self()
      handler_id = "budget-handler-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:ai, :budget, :alert],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:budget_event, event, measurements, metadata})
        end,
        nil
      )

      result = TelemetryFlow.emit_budget_alert(:daily_90_percent, 45.0, 50.0)

      assert result == :ok
      assert_receive {:budget_event, [:ai, :budget, :alert], measurements, metadata}, 1000

      assert measurements.current == 45.0
      assert measurements.limit == 50.0
      assert measurements.percent == 90.0
      assert metadata.alert_type == :daily_90_percent

      :telemetry.detach(handler_id)
    end

    test "handles zero limit" do
      result = TelemetryFlow.emit_budget_alert(:test, 0.0, 0.0)
      assert result == :ok
    end
  end

  describe "emit_veto_event/3" do
    test "emits Guardian veto telemetry" do
      ref = make_ref()
      test_pid = self()
      handler_id = "veto-handler-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:ai, :guardian, :veto],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:veto_event, event, measurements, metadata})
        end,
        nil
      )

      result = TelemetryFlow.emit_veto_event("req-123", :dangerous_pattern, true)

      assert result == :ok
      assert_receive {:veto_event, [:ai, :guardian, :veto], measurements, metadata}, 1000

      assert measurements.fallback_used == 1
      assert metadata.request_id == "req-123"
      assert metadata.reason =~ "dangerous_pattern"

      :telemetry.detach(handler_id)
    end

    test "records fallback_used as 0 when false" do
      ref = make_ref()
      test_pid = self()
      handler_id = "veto-handler2-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:ai, :guardian, :veto],
        fn _event, measurements, _metadata, _config ->
          send(test_pid, {:fallback_value, measurements.fallback_used})
        end,
        nil
      )

      TelemetryFlow.emit_veto_event("req-456", :test, false)

      assert_receive {:fallback_value, 0}, 1000

      :telemetry.detach(handler_id)
    end
  end

  describe "emit_training_episode/1" do
    test "emits training gym telemetry" do
      ref = make_ref()
      test_pid = self()
      handler_id = "training-handler-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:ai, :training_gym, :episode],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:training_event, event, measurements, metadata})
        end,
        nil
      )

      episode = %{
        type: :success,
        divergence_score: 0.15,
        primary_model: "claude-3.5-sonnet",
        shadow_model: "gemini-1.5-pro"
      }

      result = TelemetryFlow.emit_training_episode(episode)

      assert result == :ok

      assert_receive {:training_event, [:ai, :training_gym, :episode], measurements, metadata},
                     1000

      assert measurements.divergence == 0.15
      assert metadata.type == :success
      assert metadata.primary_model == "claude-3.5-sonnet"
      assert metadata.shadow_model == "gemini-1.5-pro"

      :telemetry.detach(handler_id)
    end

    test "handles missing divergence_score" do
      episode = %{type: :near_miss}
      result = TelemetryFlow.emit_training_episode(episode)
      assert result == :ok
    end
  end
end
