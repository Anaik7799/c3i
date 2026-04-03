defmodule Indrajaal.Cockpit.SafetyMonitorTest do
  @moduledoc """
  Tests for the Safety Monitor Kino integration.

  WHAT: Validates safety monitoring and visualization helpers.
  WHY: SC-HITL-002 requires continuous safety visibility.
  CONSTRAINTS: Must verify all visualization data is correct.
  """
  use ExUnit.Case, async: false

  alias Indrajaal.Cockpit.SafetyMonitor
  alias Indrajaal.Safety.{Guardian, DeadMansSwitch}

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Start Guardian
    case GenServer.whereis(Guardian) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    {:ok, _} = Guardian.start_link()

    on_exit(fn ->
      case GenServer.whereis(Guardian) do
        nil ->
          :ok

        pid ->
          try do
            GenServer.stop(pid, :normal, 5000)
          catch
            :exit, _ -> :ok
          end
      end
    end)

    :ok
  end

  # ============================================================
  # VEGALITE SPEC TESTS
  # ============================================================

  describe "envelope_vegalite_spec/0" do
    test "returns valid VegaLite specification" do
      spec = SafetyMonitor.envelope_vegalite_spec()

      assert is_map(spec)
      assert spec["$schema"] =~ "vega-lite"
      assert Map.has_key?(spec, "title")
      assert Map.has_key?(spec, "layer")
    end

    test "includes resource data" do
      spec = SafetyMonitor.envelope_vegalite_spec()

      [layer1 | _] = spec["layer"]
      values = layer1["data"]["values"]

      assert Enum.any?(values, &(&1["resource"] == "FLAME Nodes"))
      assert Enum.any?(values, &(&1["resource"] == "RAM (GB)"))
      assert Enum.any?(values, &(&1["resource"] == "CPU %"))
    end
  end

  # ============================================================
  # GUARDIAN STATUS TESTS
  # ============================================================

  describe "guardian_status_data/0" do
    test "returns guardian status" do
      data = SafetyMonitor.guardian_status_data()

      assert is_map(data)
      assert data.status == :running
      assert is_integer(data.validations)
      assert is_integer(data.violations)
      assert is_binary(data.uptime)
    end

    test "health indicator is calculated" do
      data = SafetyMonitor.guardian_status_data()

      assert data.health_indicator in [:healthy, :info, :warning, :critical]
    end
  end

  # ============================================================
  # DMS HEARTBEAT TESTS
  # ============================================================

  describe "dms_heartbeat_data/0" do
    test "returns DMS status" do
      data = SafetyMonitor.dms_heartbeat_data()

      assert is_map(data)
      assert is_atom(data.state)
      assert is_binary(data.state_display)
      assert is_integer(data.heartbeats)
      assert is_integer(data.missed)
      assert is_integer(data.failsafes)
    end

    test "health level is calculated" do
      data = SafetyMonitor.dms_heartbeat_data()

      assert data.health in [:healthy, :warning, :critical, :info, :unknown]
    end
  end

  # ============================================================
  # SAFETY SCORE TESTS
  # ============================================================

  describe "safety_score/0" do
    test "returns integer score 0-100" do
      score = SafetyMonitor.safety_score()

      assert is_integer(score)
      assert score >= 0
      assert score <= 100
    end

    test "healthy system has high score" do
      # With Guardian running and no violations, score should be good
      score = SafetyMonitor.safety_score()

      # Guardian running = 30 points, DMS disabled = 20 points, envelope healthy = 40 points
      # Total should be at least 70
      assert score >= 70
    end
  end

  # ============================================================
  # SAFETY ALERTS TESTS
  # ============================================================

  describe "safety_alerts/0" do
    test "returns list of alerts" do
      alerts = SafetyMonitor.safety_alerts()

      assert is_list(alerts)
    end

    test "no critical alerts when system healthy" do
      alerts = SafetyMonitor.safety_alerts()

      critical_count = Enum.count(alerts, &(&1.level == :critical))

      # With Guardian running and DMS not in failsafe, no critical alerts
      assert critical_count == 0
    end
  end

  # ============================================================
  # SAFETY TIMELINE TESTS
  # ============================================================

  describe "safety_timeline/1" do
    test "returns list of events" do
      events = SafetyMonitor.safety_timeline(5)

      assert is_list(events)
    end

    test "respects limit parameter" do
      events = SafetyMonitor.safety_timeline(3)

      assert length(events) <= 3
    end
  end
end
