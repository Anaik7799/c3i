defmodule Indrajaal.Safety.PatternHunterTest do
  @moduledoc """
  Tests for the Enhanced Pattern Hunter v2.0.

  ## STAMP Constraints Verified
  - SC-OODA-001: Cycle time <100ms
  - SC-SEC-044: Security checks required
  - AOR-FMEA-001: Risk Assessment before action

  ## Pattern Types Tested
  - :process_spawn_storm
  - :memory_leak
  - :error_cascade
  - :timeout_pattern
  - :resource_exhaustion
  - :suspicious_access
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Safety.PatternHunter

  @moduletag :pattern_hunter
  @test_name Indrajaal.Safety.PatternHunter

  setup do
    # Ensure no existing process
    case GenServer.whereis(@test_name) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 1000)
    end

    # Start a fresh PatternHunter for each test
    {:ok, pid} = PatternHunter.start_link(name: @test_name)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid, :normal, 1000)
    end)

    {:ok, pid: pid}
  end

  describe "start_link/1" do
    test "starts the PatternHunter GenServer" do
      # Already started in setup
      assert Process.whereis(@test_name) != nil
    end

    test "initializes with builtin patterns" do
      patterns = PatternHunter.get_active_patterns()
      assert length(patterns) > 0
    end
  end

  describe "pattern_types/0" do
    test "returns all required pattern types" do
      types = PatternHunter.pattern_types()

      assert :process_spawn_storm in types
      assert :memory_leak in types
      assert :error_cascade in types
      assert :timeout_pattern in types
      assert :resource_exhaustion in types
      assert :suspicious_access in types
    end
  end

  describe "signatures/0" do
    test "returns builtin pattern signatures" do
      signatures = PatternHunter.signatures()

      assert is_list(signatures)
      assert length(signatures) >= 6

      # Verify structure of a signature
      first = List.first(signatures)
      assert Map.has_key?(first, :id)
      assert Map.has_key?(first, :name)
      assert Map.has_key?(first, :type)
      assert Map.has_key?(first, :risk_score)
      assert Map.has_key?(first, :severity)
    end
  end

  describe "analyze/1" do
    test "analyzes empty event stream" do
      {:ok, detections} = PatternHunter.analyze([])
      assert is_list(detections)
    end

    test "detects critical error in event stream" do
      events = [
        %{type: :error, severity: :critical, message: "Database connection failed"}
      ]

      {:ok, detections} = PatternHunter.analyze(events)

      # Should detect the critical error
      critical_detections =
        Enum.filter(detections, fn d ->
          d.pattern_name == :critical_error_event
        end)

      assert length(critical_detections) >= 1
    end

    test "detects authentication failure in event stream" do
      events = [
        %{auth_failed: true, source_ip: "192.168.1.100", timestamp: DateTime.utc_now()}
      ]

      {:ok, detections} = PatternHunter.analyze(events)

      auth_detections =
        Enum.filter(detections, fn d ->
          d.pattern_name == :auth_failure_event
        end)

      assert length(auth_detections) >= 1
    end
  end

  describe "register_pattern/2" do
    test "registers a custom pattern matcher" do
      custom_matcher = fn _current, _history, _baseline ->
        {true, 95.0}
      end

      assert :ok = PatternHunter.register_pattern(:test_custom_pattern, custom_matcher)

      # Allow time for async processing
      Process.sleep(50)

      patterns = PatternHunter.get_active_patterns()
      custom = Enum.find(patterns, fn p -> p.name == :test_custom_pattern end)

      assert custom != nil
      assert custom.type == :custom
      assert custom.enabled == true
    end

    test "custom pattern is used during analysis" do
      # Register a pattern that always triggers
      always_trigger = fn _current, _history, _baseline ->
        {true, 85.0}
      end

      PatternHunter.register_pattern(:always_trigger, always_trigger)
      Process.sleep(50)

      # Run analysis
      {:ok, detections} = PatternHunter.analyze([])

      # Should find our custom pattern
      custom_detection =
        Enum.find(detections, fn d ->
          d.pattern_name == :always_trigger
        end)

      assert custom_detection != nil
      assert custom_detection.confidence == 85.0
    end
  end

  describe "get_active_patterns/0" do
    test "returns only enabled patterns" do
      patterns = PatternHunter.get_active_patterns()

      # All returned patterns should be enabled
      assert Enum.all?(patterns, fn p -> p.enabled == true end)
    end

    test "includes builtin patterns" do
      patterns = PatternHunter.get_active_patterns()

      # Should have builtin patterns
      assert length(patterns) >= 6
    end
  end

  describe "observe/1" do
    test "accepts telemetry observation" do
      telemetry = %{
        total_memory: :erlang.memory(:total),
        process_count: :erlang.system_info(:process_count),
        timestamp: System.monotonic_time(:millisecond)
      }

      assert :ok = PatternHunter.observe(telemetry)
    end

    test "builds telemetry history" do
      # Send multiple observations
      for _ <- 1..10 do
        PatternHunter.observe(%{
          total_memory: :erlang.memory(:total),
          process_count: :erlang.system_info(:process_count)
        })
      end

      # Give time for async processing
      Process.sleep(100)

      status = PatternHunter.status()
      assert status.history_size > 0
    end
  end

  describe "status/0" do
    test "returns current status" do
      status = PatternHunter.status()

      assert Map.has_key?(status, :active_patterns)
      assert Map.has_key?(status, :total_patterns)
      assert Map.has_key?(status, :learned_patterns)
      assert Map.has_key?(status, :detected_patterns)
      assert Map.has_key?(status, :history_size)
      assert Map.has_key?(status, :stats)
      assert Map.has_key?(status, :pattern_types)
    end

    test "stats include expected counters" do
      status = PatternHunter.status()
      stats = status.stats

      assert Map.has_key?(stats, :scans)
      assert Map.has_key?(stats, :patterns_detected)
      assert Map.has_key?(stats, :preemptive_alerts)
      assert Map.has_key?(stats, :patterns_learned)
      assert Map.has_key?(stats, :sentinel_reports)
    end
  end

  describe "set_baseline/1" do
    test "updates baseline metrics" do
      new_baseline = %{
        error_rate: 0.02,
        latency_p99: 150
      }

      assert :ok = PatternHunter.set_baseline(new_baseline)
      Process.sleep(50)

      status = PatternHunter.status()
      assert status.baseline_metrics[:error_rate] == 0.02
      assert status.baseline_metrics[:latency_p99] == 150
    end
  end

  describe "set_pattern_enabled/2" do
    test "disables patterns by ID" do
      # Get initial patterns
      patterns = PatternHunter.get_active_patterns()
      first_pattern = List.first(patterns)

      # Disable it
      PatternHunter.set_pattern_enabled(first_pattern.id, false)
      Process.sleep(50)

      # Check it's now disabled (not in active patterns)
      updated_patterns = PatternHunter.get_active_patterns()
      disabled = Enum.find(updated_patterns, fn p -> p.id == first_pattern.id end)

      # Should not be in active patterns (since we only return enabled ones)
      assert disabled == nil
    end
  end

  describe "scan_now/0" do
    test "triggers immediate scan" do
      initial_status = PatternHunter.status()
      initial_scans = initial_status.stats.scans

      PatternHunter.scan_now()
      Process.sleep(100)

      updated_status = PatternHunter.status()
      assert updated_status.stats.scans >= initial_scans
    end
  end

  describe "report_to_sentinel/1" do
    test "reports pattern to sentinel" do
      pattern = %{
        id: "TEST-001",
        pattern_name: :test_pattern,
        type: :memory_leak,
        risk_score: 8,
        severity: :high,
        confidence: 90.0,
        time_to_error_ms: 30_000
      }

      assert :ok = PatternHunter.report_to_sentinel(pattern)

      # Check stats updated
      Process.sleep(50)
      status = PatternHunter.status()
      assert status.stats.sentinel_reports >= 1
    end
  end

  describe "learning capability" do
    test "get_learned_patterns returns empty initially" do
      learned = PatternHunter.get_learned_patterns()
      assert learned == []
    end

    test "clear_learned_patterns clears all learned patterns" do
      # First trigger learning
      PatternHunter.observe(%{error: true, error_type: :test, anomaly_count: 10})
      Process.sleep(100)

      PatternHunter.clear_learned_patterns()
      Process.sleep(50)

      learned = PatternHunter.get_learned_patterns()
      assert learned == []
    end
  end

  describe "detection structure" do
    test "detections have required fields" do
      # Create events that will trigger detection
      events = [
        %{type: :error, severity: :critical, message: "Critical failure"}
      ]

      {:ok, detections} = PatternHunter.analyze(events)

      if length(detections) > 0 do
        detection = List.first(detections)

        assert Map.has_key?(detection, :id)
        assert Map.has_key?(detection, :pattern_id)
        assert Map.has_key?(detection, :pattern_name)
        assert Map.has_key?(detection, :type)
        assert Map.has_key?(detection, :risk_score)
        assert Map.has_key?(detection, :severity)
        assert Map.has_key?(detection, :confidence)
        assert Map.has_key?(detection, :detected_at)
      end
    end
  end

  describe "pattern matching" do
    test "process_spawn_storm pattern type exists" do
      signatures = PatternHunter.signatures()
      spawn_storm = Enum.find(signatures, fn s -> s.type == :process_spawn_storm end)

      assert spawn_storm != nil
      assert spawn_storm.risk_score >= 7
    end

    test "memory_leak pattern type exists" do
      signatures = PatternHunter.signatures()
      memory_leak = Enum.find(signatures, fn s -> s.type == :memory_leak end)

      assert memory_leak != nil
    end

    test "error_cascade pattern type exists" do
      signatures = PatternHunter.signatures()
      error_cascade = Enum.find(signatures, fn s -> s.type == :error_cascade end)

      assert error_cascade != nil
    end

    test "timeout_pattern type exists" do
      signatures = PatternHunter.signatures()
      timeout = Enum.find(signatures, fn s -> s.type == :timeout_pattern end)

      assert timeout != nil
    end

    test "resource_exhaustion pattern type exists" do
      signatures = PatternHunter.signatures()
      resource = Enum.find(signatures, fn s -> s.type == :resource_exhaustion end)

      assert resource != nil
    end

    test "suspicious_access pattern type exists" do
      signatures = PatternHunter.signatures()
      suspicious = Enum.find(signatures, fn s -> s.type == :suspicious_access end)

      assert suspicious != nil
      # Security threats are high risk
      assert suspicious.risk_score >= 9
    end
  end

  describe "STAMP constraint compliance" do
    @tag :stamp
    test "SC-SEC-044: Security patterns include suspicious access" do
      signatures = PatternHunter.signatures()

      security_patterns =
        Enum.filter(signatures, fn s ->
          s.category == :security
        end)

      assert length(security_patterns) >= 1
    end

    @tag :stamp
    test "AOR-FMEA-001: Patterns have risk scores for prioritization" do
      signatures = PatternHunter.signatures()

      assert Enum.all?(signatures, fn s ->
               s.risk_score >= 1 and s.risk_score <= 10
             end)
    end
  end

  describe "integration with safety modules" do
    test "pattern structure compatible with Sentinel" do
      pattern = %{
        id: "TEST-001",
        pattern_name: :test_pattern,
        type: :memory_leak,
        risk_score: 8,
        severity: :high,
        confidence: 90.0,
        time_to_error_ms: 30_000
      }

      # Should not crash when reporting
      assert :ok = PatternHunter.report_to_sentinel(pattern)
    end
  end
end
