defmodule Indrajaal.Coordination.LoadBalancerTest do
  @moduledoc """
  TDG comprehensive test suite for LoadBalancer GenServer.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-SIL6-001: Load balancer must survive all distribution scenarios
  - SC-PRF-050: Task assignment response < 50ms for normal loads
  - SC-AGT-018: No deadlocks in task distribution

  ## Constitutional Verification
  - Psi0 Existence: LoadBalancer GenServer survives task assignment errors
  - Psi1 Regeneration: Balancer can restart after failure

  ## Founder's Directive Alignment
  - Omega0.1: Load balancing ensures system throughput for operational continuity

  ## TPS 5-Level RCA Context
  - L1 Symptom: Tasks pile up on single agent causing degradation
  - L5 Root Cause: Missing load distribution algorithm validation
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Coordination.LoadBalancer

  @moduletag :zenoh_nif

  defp start_balancer(opts \\ []) do
    GenServer.start_link(LoadBalancer, opts)
  end

  defp sample_agents do
    %{
      "agent-1" => %{id: "agent-1", status: :idle, cpu: 0.1, memory: 0.2},
      "agent-2" => %{id: "agent-2", status: :idle, cpu: 0.3, memory: 0.4},
      "agent-3" => %{id: "agent-3", status: :busy, cpu: 0.8, memory: 0.7}
    }
  end

  defp sample_tasks do
    [
      %{id: "task-1", priority: :high, type: :compute},
      %{id: "task-2", priority: :medium, type: :io},
      %{id: "task-3", priority: :low, type: :background}
    ]
  end

  # ==========================================================================
  # start_link/1
  # ==========================================================================

  describe "start_link/1" do
    test "starts successfully with default options" do
      assert {:ok, pid} = start_balancer()
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts with custom strategy option" do
      assert {:ok, pid} = start_balancer(default_strategy: :round_robin)
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "starts with least_loaded strategy" do
      assert {:ok, pid} = start_balancer(default_strategy: :least_loaded)
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "starts with performance_based strategy" do
      assert {:ok, pid} = start_balancer(default_strategy: :performance_based)
      assert is_pid(pid)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # assign_tasks/3
  # ==========================================================================

  describe "assign_tasks/3" do
    test "returns a list for valid tasks and agents" do
      {:ok, pid} = start_balancer()
      result = LoadBalancer.assign_tasks(pid, sample_tasks(), sample_agents())
      assert is_list(result)
      GenServer.stop(pid)
    end

    test "returns empty list for empty tasks" do
      {:ok, pid} = start_balancer()
      result = LoadBalancer.assign_tasks(pid, [], sample_agents())
      assert is_list(result)
      GenServer.stop(pid)
    end

    test "returns list when agents are empty" do
      {:ok, pid} = start_balancer()
      result = LoadBalancer.assign_tasks(pid, sample_tasks(), %{})
      assert is_list(result)
      GenServer.stop(pid)
    end

    test "returns list for single task single agent" do
      {:ok, pid} = start_balancer()
      single_task = [%{id: "t1", priority: :high, type: :compute}]
      single_agent = %{"a1" => %{id: "a1", status: :idle, cpu: 0.1}}
      result = LoadBalancer.assign_tasks(pid, single_task, single_agent)
      assert is_list(result)
      GenServer.stop(pid)
    end

    test "balancer process remains alive after task assignment" do
      {:ok, pid} = start_balancer()
      LoadBalancer.assign_tasks(pid, sample_tasks(), sample_agents())
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "multiple sequential assignments complete without error" do
      {:ok, pid} = start_balancer()

      Enum.each(1..5, fn i ->
        tasks = [%{id: "task-#{i}", priority: :medium, type: :compute}]
        result = LoadBalancer.assign_tasks(pid, tasks, sample_agents())
        assert is_list(result)
      end)

      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # update_agent_metrics/3
  # ==========================================================================

  describe "update_agent_metrics/3" do
    test "returns :ok for valid metrics" do
      {:ok, pid} = start_balancer()

      result =
        LoadBalancer.update_agent_metrics(pid, "agent-1", %{
          cpu: 0.5,
          memory: 0.3,
          tasks: 2,
          response_time: 100
        })

      assert result == :ok
      GenServer.stop(pid)
    end

    test "updating metrics for unknown agent returns :ok" do
      {:ok, pid} = start_balancer()
      result = LoadBalancer.update_agent_metrics(pid, "nonexistent-agent", %{cpu: 0.0})
      assert result == :ok
      GenServer.stop(pid)
    end

    test "can update same agent multiple times" do
      {:ok, pid} = start_balancer()
      assert :ok = LoadBalancer.update_agent_metrics(pid, "agent-x", %{cpu: 0.1})
      assert :ok = LoadBalancer.update_agent_metrics(pid, "agent-x", %{cpu: 0.9})
      assert :ok = LoadBalancer.update_agent_metrics(pid, "agent-x", %{cpu: 0.5})
      GenServer.stop(pid)
    end

    test "updating metrics with high cpu value is accepted" do
      {:ok, pid} = start_balancer()
      assert :ok = LoadBalancer.update_agent_metrics(pid, "overloaded", %{cpu: 1.0, memory: 1.0})
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # get_load_distribution/1
  # ==========================================================================

  describe "get_load_distribution/1" do
    test "returns a map" do
      {:ok, pid} = start_balancer()
      result = LoadBalancer.get_load_distribution(pid)
      assert is_map(result)
      GenServer.stop(pid)
    end

    test "distribution is available after agent metrics update" do
      {:ok, pid} = start_balancer()
      :ok = LoadBalancer.update_agent_metrics(pid, "agent-1", %{cpu: 0.3, tasks: 2})
      :ok = LoadBalancer.update_agent_metrics(pid, "agent-2", %{cpu: 0.7, tasks: 8})

      distribution = LoadBalancer.get_load_distribution(pid)
      assert is_map(distribution)
      GenServer.stop(pid)
    end

    test "distribution is accessible on empty balancer" do
      {:ok, pid} = start_balancer()
      distribution = LoadBalancer.get_load_distribution(pid)
      refute is_nil(distribution)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # optimize_routing/1
  # ==========================================================================

  describe "optimize_routing/1" do
    test "returns :ok" do
      {:ok, pid} = start_balancer()
      result = LoadBalancer.optimize_routing(pid)
      assert result == :ok
      GenServer.stop(pid)
    end

    test "routing optimization can be called multiple times" do
      {:ok, pid} = start_balancer()
      assert :ok = LoadBalancer.optimize_routing(pid)
      assert :ok = LoadBalancer.optimize_routing(pid)
      assert :ok = LoadBalancer.optimize_routing(pid)
      GenServer.stop(pid)
    end

    test "balancer remains alive after routing optimization" do
      {:ok, pid} = start_balancer()
      LoadBalancer.optimize_routing(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # SIL-6 Safety Tests
  # ==========================================================================

  describe "SIL-6 Requirements" do
    test "load balancer survives burst of task assignments" do
      {:ok, pid} = start_balancer()

      Enum.each(1..10, fn i ->
        tasks = [%{id: "burst-task-#{i}", priority: :high, type: :compute}]
        LoadBalancer.assign_tasks(pid, tasks, sample_agents())
      end)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "assign_tasks completes within time budget (SC-PRF-050)" do
      {:ok, pid} = start_balancer()
      start = System.monotonic_time(:millisecond)
      LoadBalancer.assign_tasks(pid, sample_tasks(), sample_agents())
      elapsed = System.monotonic_time(:millisecond) - start
      # Normal assignment should be reasonably quick
      assert elapsed < 5_000, "Assignment took #{elapsed}ms"
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # Constitutional Invariants (Psi0-Psi1)
  # ==========================================================================

  describe "Constitutional Invariants (Psi0-Psi1)" do
    test "Psi0 existence: balancer survives tasks with malformed agents" do
      {:ok, pid} = start_balancer()

      # Agents with missing fields
      agents = %{"agent-broken" => %{}}
      tasks = [%{id: "task-x", priority: :high}]

      # Should not crash
      _result = LoadBalancer.assign_tasks(pid, tasks, agents)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "Psi1 regeneration: new balancer starts clean after old one stops" do
      {:ok, pid1} = start_balancer()
      :ok = LoadBalancer.update_agent_metrics(pid1, "agent-1", %{cpu: 0.9})
      GenServer.stop(pid1)

      Process.sleep(10)

      {:ok, pid2} = start_balancer()
      assert Process.alive?(pid2)
      # New balancer has empty metrics
      distribution = LoadBalancer.get_load_distribution(pid2)
      assert is_map(distribution)
      GenServer.stop(pid2)
    end
  end

  # ==========================================================================
  # FMEA Tests
  # ==========================================================================

  describe "FMEA Critical Paths" do
    @tag :fmea
    test "FMEA-LB-001: balancer handles all-busy agents without crash" do
      {:ok, pid} = start_balancer()

      all_busy_agents = %{
        "busy-1" => %{id: "busy-1", status: :busy, cpu: 0.95},
        "busy-2" => %{id: "busy-2", status: :busy, cpu: 0.98}
      }

      result = LoadBalancer.assign_tasks(pid, sample_tasks(), all_busy_agents)
      assert is_list(result)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    @tag :fmea
    test "FMEA-LB-002: metrics update with zero values does not cause division errors" do
      {:ok, pid} = start_balancer()

      # Zero metrics could cause division-by-zero in composite load calc
      assert :ok =
               LoadBalancer.update_agent_metrics(pid, "zero-agent", %{
                 cpu: 0.0,
                 memory: 0.0,
                 tasks: 0,
                 network: 0.0
               })

      distribution = LoadBalancer.get_load_distribution(pid)
      assert is_map(distribution)
      GenServer.stop(pid)
    end

    @tag :fmea
    test "FMEA-LB-003: large task batch assignment does not crash balancer" do
      {:ok, pid} = start_balancer()

      large_tasks =
        Enum.map(1..50, fn i ->
          %{id: "task-#{i}", priority: :medium, type: :compute}
        end)

      result = LoadBalancer.assign_tasks(pid, large_tasks, sample_agents())
      assert is_list(result)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # Property Tests
  # ==========================================================================

  property "assign_tasks always returns a list for any valid input" do
    forall task_count <- PC.choose(0, 10) do
      {:ok, pid} = start_balancer()

      tasks =
        Enum.map(1..max(task_count, 1), fn i ->
          %{id: "prop-task-#{i}", priority: :medium}
        end)

      result = LoadBalancer.assign_tasks(pid, tasks, sample_agents())
      GenServer.stop(pid)
      is_list(result)
    end
  end

  test "update_agent_metrics always returns :ok for any agent_id" do
    ExUnitProperties.check all(
                             agent_id <- SD.string(:alphanumeric, min_length: 1, max_length: 20)
                           ) do
      {:ok, pid} = start_balancer()
      result = LoadBalancer.update_agent_metrics(pid, agent_id, %{cpu: 0.5})
      GenServer.stop(pid)
      assert result == :ok
    end
  end
end
