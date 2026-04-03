defmodule Indrajaal.Observability.Domains.AlarmsInstrumentationTest do
  @moduledoc """
  Tests for AlarmsInstrumentation module.
  Tests focus on instrumentation setup and telemetry handler configuration.
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Observability.Domains.AlarmsInstrumentation
  import Indrajaal.STAMPTestHelpers
  import ExUnit.CaptureLog
  require Logger

  @moduletag :observability_domain

  setup do
    # Detach any existing handlers before test
    handlers = :telemetry.list_handlers([])

    handlers
    |> Enum.each(fn handler ->
      handler_id_str =
        case handler.id do
          id when is_binary(id) -> id
          id when is_atom(id) -> Atom.to_string(id)
          _ -> inspect(handler.id)
        end

      if String.contains?(handler_id_str, "alarms") do
        :telemetry.detach(handler.id)
      end
    end)

    :ok
  end

  describe "setup/0" do
    test "returns :ok after attaching all handlers" do
      result = AlarmsInstrumentation.setup()

      assert result == :ok
    end

    test "attaches handlers successfully" do
      assert :ok = AlarmsInstrumentation.setup()
    end

    test "can be called multiple times safely" do
      assert :ok = AlarmsInstrumentation.setup()
      assert :ok = AlarmsInstrumentation.setup()
    end
  end

  describe "telemetry event handlers" do
    test "handles create event without raising" do
      AlarmsInstrumentation.setup()

      # Emit create event
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :alarms, :create, :start],
          %{system_time: System.system_time()},
          %{resource_type: :alarm_event, alarm_type: "intrusion"}
        )
      end)
    end

    test "handles update event without raising" do
      AlarmsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :alarms, :update, :stop],
          %{duration: 1000},
          %{resource_type: :alarm_event, success: true, state_change: "acknowledged"}
        )
      end)
    end

    test "handles read event without raising" do
      AlarmsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :alarms, :read, :stop],
          %{duration: 500},
          %{resource_type: :alarm_event, count: 10}
        )
      end)
    end

    test "handles lifecycle acknowledged event" do
      AlarmsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :alarms, :lifecycle, :acknowledged],
          %{timestamp: System.monotonic_time()},
          %{alarm_id: "alarm123", acknowledged_by: "user456"}
        )
      end)
    end

    test "handles lifecycle resolved event" do
      AlarmsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :alarms, :lifecycle, :resolved],
          %{resolution_time_ms: 30_000},
          %{alarm_id: "alarm123", resolved_by: "user456", resolution_notes: "False alarm"}
        )
      end)
    end

    test "handles lifecycle escalated event" do
      AlarmsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :alarms, :lifecycle, :escalated],
          %{escalation_time_ms: 5000},
          %{alarm_id: "alarm123", escalated_to: "supervisor789", reason: "no_response"}
        )
      end)
    end
  end

  describe "alarm type handling" do
    test "handles intrusion alarm events" do
      AlarmsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :alarms, :create, :stop],
          %{duration: 100},
          %{alarm_type: "intrusion_detected", priority: "critical", zone: "Zone A"}
        )
      end)
    end

    test "handles fire alarm events" do
      AlarmsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :alarms, :create, :stop],
          %{duration: 80},
          %{alarm_type: "fire_detected", priority: "emergency", zone: "Floor 2"}
        )
      end)
    end

    test "handles system fault events" do
      AlarmsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :alarms, :create, :stop],
          %{duration: 50},
          %{alarm_type: "system_fault", priority: "high", component: "Sensor 5"}
        )
      end)
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: handler attachment does not block" do
      {time, result} =
        :timer.tc(fn ->
          AlarmsInstrumentation.setup()
        end)

      assert result == :ok
      # Should complete within 100ms
      assert time < 100_000
    end

    test "SC2: handles invalid measurements gracefully" do
      AlarmsInstrumentation.setup()

      # Should not raise with invalid measurements
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :alarms, :create, :stop],
          %{},
          %{}
        )
      end)
    end

    test "SC3: handles missing metadata gracefully" do
      AlarmsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :alarms, :read, :start],
          %{system_time: System.system_time()},
          %{}
        )
      end)
    end

    test "SC4: processes critical alarms without delay" do
      AlarmsInstrumentation.setup()

      {time, _} =
        :timer.tc(fn ->
          :telemetry.execute(
            [:indrajaal, :alarms, :create, :start],
            %{system_time: System.system_time()},
            %{priority: "critical", alarm_type: "intrusion_detected"}
          )
        end)

      # Critical alarm processing should be < 10ms
      assert time < 10_000
    end
  end
end
