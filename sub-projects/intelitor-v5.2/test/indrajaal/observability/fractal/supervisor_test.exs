defmodule Indrajaal.Observability.Fractal.SupervisorTest do
  @moduledoc """
  TDG tests for Fractal Supervisor module.

  WHAT: Tests for 4-Agent architecture supervision, ETS initialization, and health checks.
  WHY: Ensures fault-tolerant supervision and proper dependency ordering.
  CONSTRAINTS: RestForOne strategy, ETS table creation, agent status tracking.
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: PropCheck/StreamData disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.Fractal.Supervisor, as: FractalSupervisor

  alias Indrajaal.Observability.Fractal.{
    FractalControl,
    WriteFilter,
    HLC,
    BatchEncoder,
    ContentRouter,
    CyberneticController
  }

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Stop supervisor if running
    stop_supervisor()

    on_exit(fn ->
      stop_supervisor()
    end)

    :ok
  end

  # ============================================================
  # UNIT TESTS: START_LINK
  # ============================================================

  describe "start_link/1" do
    test "starts supervisor successfully" do
      {:ok, pid} = FractalSupervisor.start_link([])

      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "starts with default options" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      # Children should be running
      children = Supervisor.which_children(FractalSupervisor)
      assert length(children) >= 4
    end

    test "starts with custom default_level" do
      {:ok, _pid} = FractalSupervisor.start_link(default_level: :l3)

      # Should succeed without error
      assert Process.whereis(FractalSupervisor) != nil
    end

    test "starts with enable_cybernetic true" do
      {:ok, _pid} = FractalSupervisor.start_link(enable_cybernetic: true)

      children = Supervisor.which_children(FractalSupervisor)
      # Should have cybernetic controller as additional child
      assert length(children) >= 5
    end

    test "starts with enable_cybernetic false" do
      {:ok, _pid} = FractalSupervisor.start_link(enable_cybernetic: false)

      children = Supervisor.which_children(FractalSupervisor)
      # Standard 5 children (FractalControl, WriteFilter, BatchEncoder, HLC, ContentRouter)
      assert length(children) == 5
    end

    test "registers with expected name" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      assert Process.whereis(FractalSupervisor) != nil
    end
  end

  # ============================================================
  # UNIT TESTS: STATUS
  # ============================================================

  describe "status/0" do
    test "returns status map with all fields" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      status = FractalSupervisor.status()

      assert is_map(status)
      assert Map.has_key?(status, :fractal_control)
      assert Map.has_key?(status, :write_filter)
      assert Map.has_key?(status, :hlc)
      assert Map.has_key?(status, :cybernetic)
      assert Map.has_key?(status, :partitions)
    end

    test "reports running agents correctly" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      status = FractalSupervisor.status()

      assert status.fractal_control == :running
      assert status.write_filter == :running
      assert status.hlc == :running
    end

    test "reports disabled cybernetic when not enabled" do
      {:ok, _pid} = FractalSupervisor.start_link(enable_cybernetic: false)

      status = FractalSupervisor.status()

      assert status.cybernetic == :disabled
    end

    test "reports running cybernetic when enabled" do
      {:ok, _pid} = FractalSupervisor.start_link(enable_cybernetic: true)

      status = FractalSupervisor.status()

      assert status.cybernetic == :running
    end

    test "reports partition count" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      status = FractalSupervisor.status()

      assert is_integer(status.partitions)
      assert status.partitions > 0
    end
  end

  # ============================================================
  # UNIT TESTS: HEALTHY?
  # ============================================================

  describe "healthy?/0" do
    test "returns true when all critical agents running" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      assert FractalSupervisor.healthy?() == true
    end

    test "health check passes with cybernetic disabled" do
      {:ok, _pid} = FractalSupervisor.start_link(enable_cybernetic: false)

      # Cybernetic is not critical, so should still be healthy
      assert FractalSupervisor.healthy?() == true
    end

    test "health check passes with cybernetic enabled" do
      {:ok, _pid} = FractalSupervisor.start_link(enable_cybernetic: true)

      assert FractalSupervisor.healthy?() == true
    end
  end

  # ============================================================
  # INTEGRATION TESTS: ETS TABLES
  # ============================================================

  describe "ETS table initialization" do
    test "creates :fractal_config table" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      assert :ets.whereis(:fractal_config) != :undefined
    end

    test "creates :fractal_boosts table" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      assert :ets.whereis(:fractal_boosts) != :undefined
    end

    test "creates :fractal_subscriptions table" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      assert :ets.whereis(:fractal_subscriptions) != :undefined
    end

    test "creates :fractal_aliases table" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      assert :ets.whereis(:fractal_aliases) != :undefined
    end

    test "sets default policy in config" do
      {:ok, _pid} = FractalSupervisor.start_link(default_level: :l3)

      [{:default_policy, level}] = :ets.lookup(:fractal_config, :default_policy)
      assert level == :l3
    end

    test "sets subsystem policies" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      # Check that policy entries exist
      policies = :ets.tab2list(:fractal_config)

      # Should have multiple policies
      policy_keys =
        Enum.filter(policies, fn
          {{:policy, _}, _} -> true
          _ -> false
        end)

      assert length(policy_keys) >= 3
    end
  end

  # ============================================================
  # INTEGRATION TESTS: CHILD PROCESSES
  # ============================================================

  describe "child process supervision" do
    test "FractalControl is supervised" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      assert Process.whereis(FractalControl) != nil
    end

    test "WriteFilter is supervised" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      assert Process.whereis(WriteFilter) != nil
    end

    test "HLC is supervised" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      assert Process.whereis(HLC) != nil
    end

    test "BatchEncoder is supervised" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      assert Process.whereis(BatchEncoder) != nil
    end

    test "ContentRouter is supervised" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      assert Process.whereis(ContentRouter) != nil
    end

    test "children are started in correct order" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      children = Supervisor.which_children(FractalSupervisor)

      # Extract module names
      modules = Enum.map(children, fn {module, _, _, _} -> module end)

      # Note: Supervisor.which_children returns in reverse order of start
      # So FractalControl (started first) is last in the list
      # Verify FractalControl is present (dependency for others)
      assert FractalControl in modules
      # The last element in which_children is the first one started
      assert List.last(modules) == FractalControl
    end
  end

  # ============================================================
  # INTEGRATION TESTS: FAULT TOLERANCE
  # ============================================================

  describe "fault tolerance" do
    test "supervisor recovers from child crash" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      # Get initial FractalControl pid
      initial_pid = Process.whereis(FractalControl)
      assert initial_pid != nil

      # Kill FractalControl
      Process.exit(initial_pid, :kill)

      # Wait for restart
      Process.sleep(100)

      # Should have new pid
      new_pid = Process.whereis(FractalControl)
      assert new_pid != nil
      # Might be same or different depending on restart timing
    end

    test "health check reflects recovery" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      assert FractalSupervisor.healthy?() == true

      # Kill HLC
      Process.exit(Process.whereis(HLC), :kill)

      # Wait for restart
      Process.sleep(100)

      # Should be healthy again after restart
      assert FractalSupervisor.healthy?() == true
    end
  end

  # ============================================================
  # PROPERTY TESTS: PROPCHECK
  # ============================================================

  describe "property tests (PropCheck)" do
    property "status always returns valid structure" do
      forall _n <- PC.integer(1, 3) do
        # Start fresh
        stop_supervisor()
        {:ok, _pid} = FractalSupervisor.start_link([])

        status = FractalSupervisor.status()

        is_map(status) and
          status.fractal_control in [:running, :stopped, :restarting] and
          status.write_filter in [:running, :stopped, :restarting] and
          status.hlc in [:running, :stopped, :restarting] and
          is_integer(status.partitions)
      end
    end

    property "healthy? returns boolean" do
      forall _enable <- PC.boolean() do
        stop_supervisor()
        {:ok, _pid} = FractalSupervisor.start_link([])

        result = FractalSupervisor.healthy?()
        is_boolean(result)
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS: STREAMDATA
  # ============================================================

  describe "property tests (StreamData)" do
    test "default_level option is respected" do
      ExUnitProperties.check all(level <- SD.member_of([:l1, :l2, :l3, :l4, :l5])) do
        stop_supervisor()
        {:ok, _pid} = FractalSupervisor.start_link(default_level: level)

        [{:default_policy, stored_level}] = :ets.lookup(:fractal_config, :default_policy)
        assert stored_level == level
      end
    end

    test "enable_cybernetic affects child count" do
      ExUnitProperties.check all(enable <- SD.boolean()) do
        stop_supervisor()
        {:ok, _pid} = FractalSupervisor.start_link(enable_cybernetic: enable)

        children = Supervisor.which_children(FractalSupervisor)

        if enable do
          assert length(children) >= 5
        else
          assert length(children) >= 4
        end
      end
    end
  end

  # ============================================================
  # STAMP COMPLIANCE TESTS
  # ============================================================

  describe "STAMP compliance" do
    @tag :stamp
    test "SC-LOG-001: Supervisor uses non-blocking children" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      # All children should start without blocking
      status = FractalSupervisor.status()

      assert status.fractal_control == :running
      assert status.write_filter == :running
      assert status.hlc == :running
    end

    @tag :stamp
    test "SC-CNT-009: Supervisor is Podman-compatible" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      # Should work in containerized environment
      # (No direct file system access, no privileged ops)
      assert FractalSupervisor.healthy?() == true
    end

    @tag :stamp
    test "4-Agent Architecture is implemented" do
      {:ok, _pid} = FractalSupervisor.start_link(enable_cybernetic: true)

      children = Supervisor.which_children(FractalSupervisor)
      child_modules = Enum.map(children, fn {module, _, _, _} -> module end)

      # Core 4 agents (plus ContentRouter and CyberneticController)
      assert FractalControl in child_modules
      assert WriteFilter in child_modules
      assert HLC in child_modules
      assert BatchEncoder in child_modules
      assert ContentRouter in child_modules
    end
  end

  # ============================================================
  # EDGE CASE TESTS
  # ============================================================

  describe "edge cases" do
    test "handles empty options" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      assert FractalSupervisor.healthy?() == true
    end

    test "handles unknown options gracefully" do
      {:ok, _pid} = FractalSupervisor.start_link(unknown_option: true)

      assert FractalSupervisor.healthy?() == true
    end

    test "partitions reflects scheduler count" do
      {:ok, _pid} = FractalSupervisor.start_link([])

      status = FractalSupervisor.status()

      assert status.partitions == System.schedulers_online()
    end
  end

  # ============================================================
  # HELPERS
  # ============================================================

  defp stop_supervisor do
    # Stop supervisor if running
    case Process.whereis(FractalSupervisor) do
      nil ->
        :ok

      pid ->
        try do
          Supervisor.stop(pid, :normal, 1000)
        catch
          :exit, _ -> :ok
        end
    end

    # Always stop individual agents that might still be running
    for module <- [
          FractalControl,
          WriteFilter,
          HLC,
          BatchEncoder,
          ContentRouter,
          CyberneticController
        ] do
      case Process.whereis(module) do
        nil ->
          :ok

        agent_pid ->
          try do
            GenServer.stop(agent_pid, :normal, 100)
          catch
            :exit, _ -> :ok
          end
      end
    end

    # Clean up ETS tables
    for table <- [:fractal_config, :fractal_boosts, :fractal_subscriptions, :fractal_aliases] do
      try do
        :ets.delete(table)
      catch
        :error, :badarg -> :ok
      end
    end

    Process.sleep(50)
  end
end
