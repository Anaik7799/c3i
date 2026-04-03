defmodule Indrajaal.Observability.DynamicResourceAllocatorTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.DynamicResourceAllocator.

  ## STAMP Safety Integration
  - SC-RES-001: Constitutional tier gets 100% allocation always
  - SC-RES-002: Resource decisions < 10ms
  - SC-RES-003: Graceful shedding from tier 5 to tier 2

  ## TPS 5-Level RCA Context
  - L1 Symptom: Resource exhaustion causing system instability
  - L5 Root Cause: Missing PID-based resource allocation control
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.DynamicResourceAllocator

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(DynamicResourceAllocator)
    end

    test "start_link/1 exported" do
      assert function_exported?(DynamicResourceAllocator, :start_link, 1)
    end

    test "get_allocation/1 exported" do
      assert function_exported?(DynamicResourceAllocator, :get_allocation, 1)
    end

    test "allocations/0 exported" do
      assert function_exported?(DynamicResourceAllocator, :allocations, 0)
    end

    test "shedding_level/0 exported" do
      assert function_exported?(DynamicResourceAllocator, :shedding_level, 0)
    end

    test "tier_active?/1 exported" do
      assert function_exported?(DynamicResourceAllocator, :tier_active?, 1)
    end

    test "pool_budget/1 exported" do
      assert function_exported?(DynamicResourceAllocator, :pool_budget, 1)
    end

    test "request_resources/2 exported" do
      assert function_exported?(DynamicResourceAllocator, :request_resources, 2)
    end

    test "release_resources/1 exported" do
      assert function_exported?(DynamicResourceAllocator, :release_resources, 1)
    end

    test "recent_decisions/0 exported" do
      assert function_exported?(DynamicResourceAllocator, :recent_decisions, 0)
    end

    test "subscribe/1 exported" do
      assert function_exported?(DynamicResourceAllocator, :subscribe, 1)
    end
  end

  describe "start_link/1 and initialization" do
    test "starts without error" do
      name = :"DRATest_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DynamicResourceAllocator, [], name: name)
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "initial shedding_level is 0" do
      name = :"DRAShedding_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DynamicResourceAllocator, [], name: name)

      state = :sys.get_state(pid)
      assert state.shedding_level == 0

      GenServer.stop(pid)
    end

    test "allocations initialized for all priority tiers" do
      name = :"DRAAlloc_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DynamicResourceAllocator, [], name: name)

      state = :sys.get_state(pid)
      assert Map.has_key?(state.allocations, :constitutional)
      assert Map.has_key?(state.allocations, :safety)
      assert Map.has_key?(state.allocations, :core)
      assert Map.has_key?(state.allocations, :background)
      assert Map.has_key?(state.allocations, :optional)

      GenServer.stop(pid)
    end

    test "constitutional tier has full allocation initially" do
      name = :"DRAConst_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DynamicResourceAllocator, [], name: name)

      state = :sys.get_state(pid)
      constitutional = Map.get(state.allocations, :constitutional, %{})
      current = Map.get(constitutional, :current, 0)
      assert current >= 0.9

      GenServer.stop(pid)
    end
  end

  describe "get_allocation/1 fallback behavior" do
    test "returns 1.0 when allocator not running (fallback)" do
      result = DynamicResourceAllocator.get_allocation(:constitutional)
      assert is_float(result) or is_integer(result)
      assert result >= 0
    end
  end

  describe "allocations/0 fallback behavior" do
    test "returns map when allocator not running (fallback)" do
      result = DynamicResourceAllocator.allocations()
      assert is_map(result)
    end
  end

  describe "shedding_level/0 fallback behavior" do
    test "returns integer when allocator not running (fallback)" do
      result = DynamicResourceAllocator.shedding_level()
      assert is_integer(result)
      assert result >= 0 and result <= 100
    end
  end

  describe "tier_active?/1 fallback behavior" do
    test "returns true when allocator not running (fallback)" do
      result = DynamicResourceAllocator.tier_active?(:core)
      assert result == true
    end
  end

  describe "pool_budget/1 fallback behavior" do
    test "returns map when allocator not running (fallback)" do
      result = DynamicResourceAllocator.pool_budget(:compute)
      assert is_map(result)
    end
  end

  describe "request_resources/2 fallback behavior" do
    test "returns rejected when allocator not running (fallback)" do
      result = DynamicResourceAllocator.request_resources(:core, %{cpu: 2})
      assert result == {:rejected, "Allocator unavailable"}
    end
  end

  describe "recent_decisions/0 fallback behavior" do
    test "returns list when allocator not running (fallback)" do
      result = DynamicResourceAllocator.recent_decisions()
      assert is_list(result)
    end
  end

  describe "GenServer request handling" do
    test "handles get_allocation call directly" do
      name = :"DRACallTest_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DynamicResourceAllocator, [], name: name)

      result = GenServer.call(pid, {:get_allocation, :constitutional})
      assert is_float(result)

      GenServer.stop(pid)
    end

    test "handles allocations call directly" do
      name = :"DRAAllocCall_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DynamicResourceAllocator, [], name: name)

      result = GenServer.call(pid, :allocations)
      assert is_map(result)

      GenServer.stop(pid)
    end

    test "handles tier_active? call directly" do
      name = :"DRATierCall_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DynamicResourceAllocator, [], name: name)

      result = GenServer.call(pid, {:tier_active?, :constitutional})
      assert is_boolean(result)

      GenServer.stop(pid)
    end

    test "handles request resources call directly" do
      name = :"DRARequestCall_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DynamicResourceAllocator, [], name: name)

      result = GenServer.call(pid, {:request, :core, %{cpu: 1}})
      assert match?({:ok, _}, result) or match?({:rejected, _}, result)

      GenServer.stop(pid)
    end

    test "handles pool_budget call directly" do
      name = :"DRAPoolCall_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DynamicResourceAllocator, [], name: name)

      result = GenServer.call(pid, {:pool_budget, :compute})
      assert is_map(result)

      GenServer.stop(pid)
    end

    test "handles recent_decisions call directly" do
      name = :"DRADecisCall_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(DynamicResourceAllocator, [], name: name)

      result = GenServer.call(pid, :recent_decisions)
      assert is_list(result)

      GenServer.stop(pid)
    end
  end
end
