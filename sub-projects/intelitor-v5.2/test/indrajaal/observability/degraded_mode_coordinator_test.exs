defmodule Indrajaal.Observability.DegradedModeCoordinatorTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.DegradedModeCoordinator.

  ## STAMP Safety Integration
  - SC-OBS-DT-004: Retry policies MUST include silence periods
  - SC-OBS-DT-006: Graceful degradation for missing infrastructure

  ## TPS 5-Level RCA Context
  - L1 Symptom: Retry storms when infrastructure unavailable
  - L5 Root Cause: Missing exponential backoff and silence periods
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.DegradedModeCoordinator

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(DegradedModeCoordinator)
    end

    test "start_link/1 exported" do
      assert function_exported?(DegradedModeCoordinator, :start_link, 1)
    end

    test "available?/1 exported" do
      assert function_exported?(DegradedModeCoordinator, :available?, 1)
    end

    test "report_unavailable/2 exported" do
      assert function_exported?(DegradedModeCoordinator, :report_unavailable, 2)
    end

    test "report_available/1 exported" do
      assert function_exported?(DegradedModeCoordinator, :report_available, 1)
    end

    test "should_retry?/1 exported" do
      assert function_exported?(DegradedModeCoordinator, :should_retry?, 1)
    end

    test "record_retry/1 exported" do
      assert function_exported?(DegradedModeCoordinator, :record_retry, 1)
    end

    test "get_backoff/1 exported" do
      assert function_exported?(DegradedModeCoordinator, :get_backoff, 1)
    end

    test "in_silence?/1 exported" do
      assert function_exported?(DegradedModeCoordinator, :in_silence?, 1)
    end

    test "degraded_services/0 exported" do
      assert function_exported?(DegradedModeCoordinator, :degraded_services, 0)
    end

    test "status/0 exported" do
      assert function_exported?(DegradedModeCoordinator, :status, 0)
    end

    test "reset/1 exported" do
      assert function_exported?(DegradedModeCoordinator, :reset, 1)
    end

    test "subscribe/1 exported" do
      assert function_exported?(DegradedModeCoordinator, :subscribe, 1)
    end
  end

  describe "start_link/1" do
    test "starts without error" do
      name = :"DMCTest_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DegradedModeCoordinator, [], name: name)
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "initializes component states" do
      name = :"DMCInit_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DegradedModeCoordinator, [], name: name)

      state = :sys.get_state(pid)
      assert Map.has_key?(state.components, :zenoh_router)
      assert Map.has_key?(state.components, :libcluster)
      assert Map.has_key?(state.components, :container_stack)
      assert Map.has_key?(state.components, :otel_collector)
      assert Map.has_key?(state.components, :database)

      GenServer.stop(pid)
    end

    test "all components start as available" do
      name = :"DMCAvail_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DegradedModeCoordinator, [], name: name)

      state = :sys.get_state(pid)

      for {_comp, comp_state} <- state.components do
        assert comp_state.available == true
      end

      GenServer.stop(pid)
    end
  end

  describe "available?/1 fallback behavior" do
    test "returns boolean when coordinator not running" do
      result = DegradedModeCoordinator.available?(:zenoh_router)
      assert is_boolean(result)
    end
  end

  describe "should_retry?/1 fallback behavior" do
    test "returns false when coordinator not running (safe default)" do
      result = DegradedModeCoordinator.should_retry?(:zenoh_router)
      assert result == false
    end
  end

  describe "get_backoff/1 fallback behavior" do
    test "returns integer when coordinator not running (max backoff fallback)" do
      result = DegradedModeCoordinator.get_backoff(:zenoh_router)
      assert is_integer(result)
      assert result > 0
    end
  end

  describe "in_silence?/1 fallback behavior" do
    test "returns true when coordinator not running (safe silence default)" do
      result = DegradedModeCoordinator.in_silence?(:zenoh_router)
      assert result == true
    end
  end

  describe "degraded_services/0 fallback behavior" do
    test "returns empty list when coordinator not running" do
      result = DegradedModeCoordinator.degraded_services()
      assert result == []
    end
  end

  describe "status/0 fallback behavior" do
    test "returns map when coordinator not running" do
      result = DegradedModeCoordinator.status()
      assert is_map(result)
    end

    test "fallback status has components key" do
      result = DegradedModeCoordinator.status()
      assert Map.has_key?(result, :components)
    end
  end

  describe "component management via GenServer" do
    test "report_unavailable changes component status" do
      name = :"DMCReport_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DegradedModeCoordinator, [], name: name)

      GenServer.cast(pid, {:unavailable, :zenoh_router, :connection_refused})
      Process.sleep(30)

      state = :sys.get_state(pid)
      comp_state = Map.get(state.components, :zenoh_router)
      assert comp_state.available == false

      GenServer.stop(pid)
    end

    test "report_available restores component status" do
      name = :"DMCRestore_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DegradedModeCoordinator, [], name: name)

      GenServer.cast(pid, {:unavailable, :zenoh_router, :reason})
      Process.sleep(20)
      GenServer.cast(pid, {:available, :zenoh_router})
      Process.sleep(20)

      state = :sys.get_state(pid)
      comp_state = Map.get(state.components, :zenoh_router)
      assert comp_state.available == true

      GenServer.stop(pid)
    end

    test "process stays alive after operations" do
      name = :"DMCAlive_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DegradedModeCoordinator, [], name: name)

      GenServer.cast(pid, {:unavailable, :database, :timeout})
      GenServer.cast(pid, {:record_retry, :database})
      Process.sleep(30)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
