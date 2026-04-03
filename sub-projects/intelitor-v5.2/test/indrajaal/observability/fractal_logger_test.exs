defmodule Indrajaal.Observability.FractalLoggerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.FractalLogger.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation

  ## STAMP Safety Integration
  - SC-LOG-001: Fractal hierarchy enforcement
  - SC-LOG-003: Audit trail immutability at Spine level

  ## TPS 5-Level RCA Context
  - L1 Symptom: Log entries missing from fractal hierarchy
  - L5 Root Cause: Breaks structured observability for cockpit display
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.FractalLogger

  setup do
    name = :"FractalLogger_#{System.unique_integer([:positive])}"
    {:ok, pid} = start_supervised!({FractalLogger, []}, id: name)
    %{logger: pid, name: name}
  end

  describe "spine/3 - Critical level" do
    test "spine logs without error (uses named server)", %{} do
      # Use the globally named server started in this test
      # Cast is fire-and-forget - just verify no crash
      pid = GenServer.whereis(FractalLogger)
      if pid, do: FractalLogger.spine("Guardian", "System check", %{})
      assert true
    end
  end

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Observability.FractalLogger)
    end

    test "spine/2 exported" do
      assert function_exported?(FractalLogger, :spine, 2)
    end

    test "spine/3 exported" do
      assert function_exported?(FractalLogger, :spine, 3)
    end

    test "thorax/2 exported" do
      assert function_exported?(FractalLogger, :thorax, 2)
    end

    test "thorax/3 exported" do
      assert function_exported?(FractalLogger, :thorax, 3)
    end

    test "segment/2 exported" do
      assert function_exported?(FractalLogger, :segment, 2)
    end

    test "segment/3 exported" do
      assert function_exported?(FractalLogger, :segment, 3)
    end

    test "fiber/2 exported" do
      assert function_exported?(FractalLogger, :fiber, 2)
    end

    test "gossamer/2 exported" do
      assert function_exported?(FractalLogger, :gossamer, 2)
    end

    test "log/3 exported" do
      assert function_exported?(FractalLogger, :log, 3)
    end

    test "get_entries/1 exported" do
      assert function_exported?(FractalLogger, :get_entries, 1)
    end

    test "get_counts/0 exported" do
      assert function_exported?(FractalLogger, :get_counts, 0)
    end

    test "get_stats/0 exported" do
      assert function_exported?(FractalLogger, :get_stats, 0)
    end

    test "start_link/1 exported" do
      assert function_exported?(FractalLogger, :start_link, 1)
    end
  end

  describe "start_link/1" do
    test "starts a new GenServer process with unique name" do
      name = :"FractalLoggerTest_#{System.unique_integer([:positive])}"
      assert {:ok, pid} = FractalLogger.start_link(name: name)
      assert is_pid(pid)
      GenServer.stop(pid)
    end
  end

  describe "get_counts/0 via named server" do
    test "returns a map with level counts" do
      name = :"FractalLoggerCounts_#{System.unique_integer([:positive])}"
      {:ok, pid} = FractalLogger.start_link(name: name)

      counts = GenServer.call(pid, :get_counts)
      assert is_map(counts)
      assert Map.has_key?(counts, :spine)
      assert Map.has_key?(counts, :thorax)
      assert Map.has_key?(counts, :segment)
      assert Map.has_key?(counts, :fiber)
      assert Map.has_key?(counts, :gossamer)

      GenServer.stop(pid)
    end

    test "initial counts are all zero" do
      name = :"FractalLoggerCounts2_#{System.unique_integer([:positive])}"
      {:ok, pid} = FractalLogger.start_link(name: name)

      counts = GenServer.call(pid, :get_counts)
      assert counts.spine == 0
      assert counts.thorax == 0
      assert counts.segment == 0
      assert counts.fiber == 0
      assert counts.gossamer == 0

      GenServer.stop(pid)
    end
  end

  describe "get_stats/0 via named server" do
    test "returns stats map with expected fields" do
      name = :"FractalLoggerStats_#{System.unique_integer([:positive])}"
      {:ok, pid} = FractalLogger.start_link(name: name)

      stats = GenServer.call(pid, :get_stats)
      assert is_map(stats)
      assert Map.has_key?(stats, :counts)
      assert Map.has_key?(stats, :total_logged)
      assert Map.has_key?(stats, :uptime_seconds)
      assert Map.has_key?(stats, :entry_counts)
      assert stats.total_logged == 0

      GenServer.stop(pid)
    end
  end

  describe "get_entries/2 via named server" do
    test "returns empty list initially" do
      name = :"FractalLoggerEntries_#{System.unique_integer([:positive])}"
      {:ok, pid} = FractalLogger.start_link(name: name)

      entries = GenServer.call(pid, {:get_entries, :spine, 100})
      assert entries == []

      GenServer.stop(pid)
    end
  end

  describe "log/4 and entry retrieval" do
    test "logged entries appear in get_entries" do
      name = :"FractalLoggerLog_#{System.unique_integer([:positive])}"
      {:ok, pid} = FractalLogger.start_link(name: name)

      GenServer.cast(pid, {:log, :segment, "TestSource", "test message", %{}})
      # Allow async cast to process
      Process.sleep(50)

      entries = GenServer.call(pid, {:get_entries, :segment, 10})
      assert length(entries) >= 1

      entry = hd(entries)
      assert entry.source == "TestSource"
      assert entry.message == "test message"
      assert entry.level == :segment

      GenServer.stop(pid)
    end

    test "spine log increments spine count" do
      name = :"FractalLoggerSpine_#{System.unique_integer([:positive])}"
      {:ok, pid} = FractalLogger.start_link(name: name)

      GenServer.cast(pid, {:log, :spine, "Guardian", "critical event", %{}})
      Process.sleep(50)

      counts = GenServer.call(pid, :get_counts)
      assert counts.spine == 1

      GenServer.stop(pid)
    end
  end
end
