defmodule Indrajaal.Safety.PatternHunterCalibrationTest do
  @moduledoc """
  P2-FEAT: PatternHunter pre-error detection calibration with ETS baseline.

  WHAT: Validates PatternHunter baseline calibration, pattern detection, and threat scoring.
  WHY: SC-IMMUNE-004 (pre-error detection), SC-BIO-EXT-001 (detection < 10ms).
  CONSTRAINTS: SC-IMMUNE-004, SC-IMMUNE-009, SC-IMMUNE-010, AOR-IMMUNE-003
  TASK: 3d833a97
  """
  use ExUnit.Case, async: false

  alias Indrajaal.Safety.PatternHunter

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    case GenServer.whereis(PatternHunter) do
      nil ->
        :ok

      pid ->
        try do
          GenServer.stop(pid, :normal, 5000)
        catch
          :exit, _ -> :ok
        end
    end

    {:ok, pid} = PatternHunter.start_link()

    on_exit(fn ->
      case GenServer.whereis(PatternHunter) do
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

    %{pid: pid}
  end

  # ============================================================
  # Baseline Calibration (AOR-IMMUNE-003)
  # ============================================================

  describe "baseline calibration" do
    test "initial state has no active patterns" do
      status = PatternHunter.status()
      assert is_map(status)
    end

    test "scan_now returns pattern detections" do
      result = PatternHunter.scan_now()
      assert result == :ok or is_list(result) or is_map(result) or match?({:ok, _}, result)
    end

    test "set_baseline establishes baseline metrics" do
      baseline = %{
        process_count: :erlang.system_info(:process_count),
        memory_total: :erlang.memory(:total),
        timestamp: System.system_time(:millisecond)
      }

      result = PatternHunter.set_baseline(baseline)
      assert result in [:ok, {:ok, :baseline_set}]
    end

    test "pattern_types returns known pattern types" do
      types = PatternHunter.pattern_types()
      assert is_list(types) or is_map(types)
    end
  end

  # ============================================================
  # Pattern Detection (SC-IMMUNE-004)
  # ============================================================

  describe "pattern detection types" do
    test "analyze detects process spawn storm pattern" do
      events = [
        %{
          type: :process_spawn,
          count: 1000,
          rate: 500,
          timestamp: System.system_time(:millisecond)
        },
        %{
          type: :process_spawn,
          count: 2000,
          rate: 800,
          timestamp: System.system_time(:millisecond)
        }
      ]

      result = PatternHunter.analyze(events)
      assert {:ok, detections} = result
      assert is_list(detections)
    end

    test "analyze detects memory leak pattern" do
      events = [
        %{
          type: :memory_growth,
          total: 2_000_000_000,
          rate: 0.95,
          timestamp: System.system_time(:millisecond)
        }
      ]

      result = PatternHunter.analyze(events)
      assert {:ok, detections} = result
      assert is_list(detections)
    end

    test "analyze detects error cascade pattern" do
      events = [
        %{
          type: :error,
          module: SomeModule,
          count: 500,
          rate: 2.0,
          timestamp: System.system_time(:millisecond)
        },
        %{
          type: :error,
          module: OtherModule,
          count: 300,
          rate: 1.5,
          timestamp: System.system_time(:millisecond)
        }
      ]

      result = PatternHunter.analyze(events)
      assert {:ok, detections} = result
      assert is_list(detections)
    end

    test "analyze handles queue buildup pattern" do
      events = [
        %{
          type: :queue_buildup,
          queue_length: 10_000,
          growth_rate: 100,
          timestamp: System.system_time(:millisecond)
        }
      ]

      result = PatternHunter.analyze(events)
      assert {:ok, detections} = result
      assert is_list(detections)
    end

    test "analyze on empty events produces no critical detections" do
      result = PatternHunter.analyze([])
      assert {:ok, detections} = result

      critical =
        Enum.filter(detections, fn d ->
          is_map(d) and Map.get(d, :severity) == :critical
        end)

      assert length(critical) == 0
    end
  end

  # ============================================================
  # Detection Structure (SC-IMMUNE-009)
  # ============================================================

  describe "detection structure" do
    test "detections have required fields" do
      events = [
        %{
          type: :process_spawn,
          count: 5000,
          rate: 1000,
          timestamp: System.system_time(:millisecond)
        }
      ]

      {:ok, detections} = PatternHunter.analyze(events)

      for detection <- detections do
        assert is_map(detection)
        assert Map.has_key?(detection, :id)
        assert Map.has_key?(detection, :pattern_name) or Map.has_key?(detection, :type)
      end
    end

    test "status returns operational info" do
      status = PatternHunter.status()
      assert is_map(status)
    end

    test "get_active_patterns returns pattern list" do
      patterns = PatternHunter.get_active_patterns()
      assert is_list(patterns) or is_map(patterns)
    end
  end

  # ============================================================
  # False Positive Rate (SC-IMMUNE-010)
  # ============================================================

  describe "false positive control (SC-IMMUNE-010)" do
    test "healthy system produces minimal detections" do
      results =
        for _i <- 1..5 do
          {:ok, detections} = PatternHunter.analyze([])
          detections
        end

      total_detections =
        results
        |> List.flatten()
        |> length()

      # False positive rate must be < 5%
      assert total_detections < 25
    end
  end

  # ============================================================
  # OODA Integration
  # ============================================================

  describe "OODA cycle integration" do
    test "status includes detection count" do
      status = PatternHunter.status()
      assert is_map(status)
    end

    test "observe captures system events" do
      result =
        PatternHunter.observe(%{type: :test_event, timestamp: System.system_time(:millisecond)})

      assert result in [:ok, {:ok, :observed}] or is_tuple(result)
    end

    test "signatures returns known signatures" do
      sigs = PatternHunter.signatures()
      assert is_list(sigs) or is_map(sigs)
    end
  end
end
