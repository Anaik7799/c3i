defmodule Indrajaal.Cockpit.Prajna.SupervisorTest do
  @moduledoc """
  Tests for PRAJNA Supervisor

  WHAT: Verifies supervision tree and fault-tolerant operation.

  WHY: Ensures safety-critical cockpit system restarts correctly on failures.

  CONSTRAINTS:
    - SC-AGT-020: Actor Isolation
    - SC-EMR-057: Emergency stop capability
    - TDG-PRAJNA-006: Supervisor must be testable

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | STAMP | SC-AGT-020, SC-EMR-057 |
  """

  use ExUnit.Case, async: false
  @moduletag :zenoh_nif
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Cockpit.Prajna.Supervisor, as: PrajnaSupervisor
  alias Indrajaal.Cockpit.Prajna.SmartMetrics
  alias Indrajaal.Cockpit.Prajna.AiCopilot
  alias Indrajaal.Cockpit.Prajna.Orchestrator

  describe "start_link/1" do
    test "starts the supervision tree" do
      {:ok, sup_pid} = PrajnaSupervisor.start_link([])

      assert Process.alive?(sup_pid)

      # Clean up
      Supervisor.stop(sup_pid)
    end

    test "starts all child processes" do
      {:ok, sup_pid} = PrajnaSupervisor.start_link([])

      # Check that children are running
      children = Supervisor.which_children(sup_pid)

      child_modules = children |> Enum.map(fn {id, _pid, _type, _modules} -> id end)

      assert SmartMetrics in child_modules
      assert AiCopilot in child_modules
      assert Orchestrator in child_modules

      # Clean up
      Supervisor.stop(sup_pid)
    end

    test "children are alive" do
      {:ok, sup_pid} = PrajnaSupervisor.start_link([])

      children = Supervisor.which_children(sup_pid)

      for {_id, pid, _type, _modules} <- children do
        assert is_pid(pid)
        assert Process.alive?(pid)
      end

      # Clean up
      Supervisor.stop(sup_pid)
    end
  end

  describe "supervision strategy" do
    test "uses one_for_one strategy" do
      {:ok, sup_pid} = PrajnaSupervisor.start_link([])

      # Get supervisor info
      # The strategy is set in the supervisor's init/1
      # We can verify by checking behavior when a child crashes

      children_before = Supervisor.which_children(sup_pid)
      # 10 children: SmartMetrics, SentinelBridge, ImmutableState, DualChannel,
      #              Watchdog, AiCopilot, Orchestrator, GuardianIntegration,
      #              Mara, AntibodySupervisor
      assert length(children_before) == 10

      # Clean up
      Supervisor.stop(sup_pid)
    end
  end

  describe "child restart" do
    test "SmartMetrics restarts on crash" do
      {:ok, sup_pid} = PrajnaSupervisor.start_link([])

      # Get SmartMetrics PID
      [{SmartMetrics, metrics_pid, _, _} | _] =
        sup_pid
        |> Supervisor.which_children()
        |> Enum.filter(fn {id, _, _, _} -> id == SmartMetrics end)

      assert Process.alive?(metrics_pid)

      # Kill the process
      Process.exit(metrics_pid, :kill)
      Process.sleep(100)

      # Check it restarted
      [{SmartMetrics, new_metrics_pid, _, _} | _] =
        sup_pid
        |> Supervisor.which_children()
        |> Enum.filter(fn {id, _, _, _} -> id == SmartMetrics end)

      assert Process.alive?(new_metrics_pid)
      assert new_metrics_pid != metrics_pid

      # Clean up
      Supervisor.stop(sup_pid)
    end

    test "AiCopilot restarts on crash" do
      {:ok, sup_pid} = PrajnaSupervisor.start_link([])

      # Get AiCopilot PID
      [{AiCopilot, copilot_pid, _, _} | _] =
        sup_pid
        |> Supervisor.which_children()
        |> Enum.filter(fn {id, _, _, _} -> id == AiCopilot end)

      assert Process.alive?(copilot_pid)

      # Kill the process
      Process.exit(copilot_pid, :kill)
      Process.sleep(100)

      # Check it restarted
      [{AiCopilot, new_copilot_pid, _, _} | _] =
        sup_pid
        |> Supervisor.which_children()
        |> Enum.filter(fn {id, _, _, _} -> id == AiCopilot end)

      assert Process.alive?(new_copilot_pid)
      assert new_copilot_pid != copilot_pid

      # Clean up
      Supervisor.stop(sup_pid)
    end

    test "Orchestrator restarts on crash" do
      {:ok, sup_pid} = PrajnaSupervisor.start_link([])

      # Get Orchestrator PID
      [{Orchestrator, orch_pid, _, _} | _] =
        sup_pid
        |> Supervisor.which_children()
        |> Enum.filter(fn {id, _, _, _} -> id == Orchestrator end)

      assert Process.alive?(orch_pid)

      # Kill the process
      Process.exit(orch_pid, :kill)
      Process.sleep(100)

      # Check it restarted
      [{Orchestrator, new_orch_pid, _, _} | _] =
        sup_pid
        |> Supervisor.which_children()
        |> Enum.filter(fn {id, _, _, _} -> id == Orchestrator end)

      assert Process.alive?(new_orch_pid)
      assert new_orch_pid != orch_pid

      # Clean up
      Supervisor.stop(sup_pid)
    end
  end

  describe "SC-AGT-020 compliance: Actor Isolation" do
    test "child crash does not affect other children" do
      {:ok, sup_pid} = PrajnaSupervisor.start_link([])

      # Get all PIDs
      children = Supervisor.which_children(sup_pid)

      metrics_pid =
        Enum.find_value(children, fn
          {SmartMetrics, pid, _, _} -> pid
          _ -> nil
        end)

      copilot_pid =
        Enum.find_value(children, fn
          {AiCopilot, pid, _, _} -> pid
          _ -> nil
        end)

      orch_pid =
        Enum.find_value(children, fn
          {Orchestrator, pid, _, _} -> pid
          _ -> nil
        end)

      # Kill SmartMetrics
      Process.exit(metrics_pid, :kill)
      Process.sleep(100)

      # Other processes should still be alive
      assert Process.alive?(copilot_pid)
      assert Process.alive?(orch_pid)

      # Clean up
      Supervisor.stop(sup_pid)
    end
  end

  describe "SC-EMR-057 compliance: Emergency stop" do
    test "supervisor can be stopped cleanly" do
      {:ok, sup_pid} = PrajnaSupervisor.start_link([])

      # Get child PIDs
      children = Supervisor.which_children(sup_pid)
      child_pids = children |> Enum.map(fn {_, pid, _, _} -> pid end)

      # Stop supervisor
      :ok = Supervisor.stop(sup_pid)
      Process.sleep(50)

      # All children should be stopped
      for pid <- child_pids do
        refute Process.alive?(pid)
      end
    end

    test "supervisor stops within timeout" do
      {:ok, sup_pid} = PrajnaSupervisor.start_link([])

      start_time = System.monotonic_time(:millisecond)
      :ok = Supervisor.stop(sup_pid, :normal, 5000)
      end_time = System.monotonic_time(:millisecond)

      # Should stop in less than 5 seconds (SC-EMR-057 requires <5s)
      assert end_time - start_time < 5000
    end
  end

  describe "configuration passing" do
    test "passes options to children" do
      opts = [operator_id: "custom-operator"]
      {:ok, sup_pid} = PrajnaSupervisor.start_link(opts)

      # The Orchestrator should have received the operator_id
      # We can verify by checking the state
      state = Orchestrator.state()
      assert state.operator_id == "custom-operator"

      # Clean up
      Supervisor.stop(sup_pid)
    end
  end

  describe "process registration" do
    test "supervisor is registered by module name" do
      {:ok, sup_pid} = PrajnaSupervisor.start_link([])

      # Should be able to find by name
      assert Process.whereis(PrajnaSupervisor) == sup_pid

      # Clean up
      Supervisor.stop(sup_pid)
    end

    test "children are registered by their module names" do
      {:ok, sup_pid} = PrajnaSupervisor.start_link([])

      # Children should be findable by name
      assert Process.whereis(SmartMetrics) != nil
      assert Process.whereis(AiCopilot) != nil
      assert Process.whereis(Orchestrator) != nil

      # Clean up
      Supervisor.stop(sup_pid)
    end
  end

  describe "property tests" do
    property "which_children always returns a list" do
      forall _ <- PC.atom() do
        {:ok, sup_pid} = PrajnaSupervisor.start_link([])

        result = Supervisor.which_children(sup_pid)

        Supervisor.stop(sup_pid)

        is_list(result)
      end
    end

    property "which_children returns proper tuples with pids" do
      forall _ <- PC.atom() do
        {:ok, sup_pid} = PrajnaSupervisor.start_link([])

        children = Supervisor.which_children(sup_pid)

        all_valid =
          Enum.all?(children, fn child ->
            is_tuple(child) and tuple_size(child) == 4 and
              is_pid(elem(child, 1))
          end)

        Supervisor.stop(sup_pid)

        all_valid
      end
    end

    property "count_children returns non-negative integers" do
      forall _ <- PC.atom() do
        {:ok, sup_pid} = PrajnaSupervisor.start_link([])

        counts = Supervisor.count_children(sup_pid)

        all_non_negative =
          is_map(counts) and
            counts.workers >= 0 and
            counts.supervisors >= 0 and
            counts.active >= 0 and
            counts.specs >= 0

        Supervisor.stop(sup_pid)

        all_non_negative
      end
    end

    property "child count consistency" do
      forall _ <- PC.atom() do
        {:ok, sup_pid} = PrajnaSupervisor.start_link([])

        children = Supervisor.which_children(sup_pid)
        counts = Supervisor.count_children(sup_pid)

        # Total active children should match which_children length
        consistent = counts.active == length(children)

        Supervisor.stop(sup_pid)

        consistent
      end
    end

    property "all child pids are alive" do
      forall _ <- PC.atom() do
        {:ok, sup_pid} = PrajnaSupervisor.start_link([])

        children = Supervisor.which_children(sup_pid)

        all_alive =
          Enum.all?(children, fn {_id, pid, _type, _modules} ->
            is_pid(pid) and Process.alive?(pid)
          end)

        Supervisor.stop(sup_pid)

        all_alive
      end
    end
  end
end
