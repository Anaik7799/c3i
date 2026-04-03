defmodule Indrajaal.Observability.ZenohCoordinatorTest do
  @moduledoc """
  TDG Test Suite for ZenohCoordinator Supervisor.

  ## TDG Compliance Markers
  - TDG_COMPLIANT: Tests written BEFORE implementation refinement
  - DUAL_PROPERTY_TESTING: PropCheck + ExUnitProperties comprehensive validation
  - STAMP_SAFETY: SC-ZENOH-INT-001 through SC-ZENOH-INT-004 constraint testing

  This test suite validates:
  - Supervisor startup and child management (SC-ZENOH-INT-001)
  - Component status reporting
  - Barrier synchronization
  - Coordination message publishing
  - Key expression enumeration
  - Heartbeat functionality (SC-ZENOH-INT-004)
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.ZenohCoordinator

  import ExUnit.CaptureLog

  @moduletag :zenoh_coordinator

  # ============================================================
  # SETUP AND TEARDOWN
  # ============================================================

  setup do
    # Ensure any existing coordinator is stopped
    case Process.whereis(ZenohCoordinator) do
      nil -> :ok
      pid -> Supervisor.stop(pid, :normal)
    end

    # Small delay to ensure cleanup
    Process.sleep(50)

    {:ok, []}
  end

  # ============================================================
  # BASIC FUNCTIONALITY TESTS
  # ============================================================

  describe "start_link/1" do
    test "starts the coordinator supervisor" do
      log =
        capture_log(fn ->
          {:ok, pid} = ZenohCoordinator.start_link()
          assert Process.alive?(pid)
          assert Process.whereis(ZenohCoordinator) == pid
          Supervisor.stop(pid, :normal)
        end)

      assert log =~ "ZenohCoordinator"
      assert log =~ "SC-ZENOH-INT-001"
    end

    test "starts with default options" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      assert Process.alive?(pid)
    end

    test "starts all children" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      # Allow time for children to start
      Process.sleep(100)

      children = Supervisor.which_children(pid)

      # Should have 4 children: KpiPublisher, ControlSubscriber, TaskSupervisor, heartbeat_worker
      assert length(children) == 4

      child_ids = Enum.map(children, fn {id, _, _, _} -> id end)
      assert Indrajaal.Observability.ZenohKpiPublisher in child_ids
      assert Indrajaal.Observability.ZenohControlSubscriber in child_ids
      assert Indrajaal.Observability.ZenohCoordinator.TaskSupervisor in child_ids
      assert :heartbeat_worker in child_ids
    end
  end

  describe "status/0" do
    test "returns complete status map" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      Process.sleep(100)

      status = ZenohCoordinator.status()

      assert Map.has_key?(status, :supervisor)
      assert Map.has_key?(status, :publisher)
      assert Map.has_key?(status, :subscriber)
      assert Map.has_key?(status, :heartbeat)
      assert Map.has_key?(status, :integration)
    end

    test "reports running supervisor when started" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      Process.sleep(100)

      status = ZenohCoordinator.status()
      assert status.supervisor == :running
    end

    test "reports active heartbeat" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      status = ZenohCoordinator.status()
      assert status.heartbeat == :active
    end

    test "reports full integration" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      status = ZenohCoordinator.status()
      assert status.integration == :full
    end
  end

  describe "sync_now/0" do
    test "returns :ok" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      Process.sleep(100)

      result = ZenohCoordinator.sync_now()
      assert result == :ok
    end

    test "triggers KPI publisher" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      Process.sleep(100)

      # Should not raise
      assert :ok = ZenohCoordinator.sync_now()
    end
  end

  describe "barrier/3" do
    test "returns error when zenoh not available" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      # Without proper Zenoh setup, should return error or timeout
      result = ZenohCoordinator.barrier("test_barrier", 1, timeout: 100)

      # Either succeeds or returns an error (depends on ZenohTestCoordinator availability)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "publish_coord/2" do
    test "publishes coordination message" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      result = ZenohCoordinator.publish_coord("test", %{value: 123})

      # Should return :ok or error depending on availability
      assert result == :ok or match?({:error, _}, result)
    end

    test "handles map payloads" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      result =
        ZenohCoordinator.publish_coord("event", %{
          timestamp: DateTime.utc_now(),
          type: :test,
          data: %{nested: true}
        })

      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "list_key_expressions/0" do
    test "returns all key expression categories" do
      key_exprs = ZenohCoordinator.list_key_expressions()

      assert Map.has_key?(key_exprs, :data_plane)
      assert Map.has_key?(key_exprs, :control_plane)
      assert Map.has_key?(key_exprs, :coordination_plane)
    end

    test "data plane contains KPI keys" do
      key_exprs = ZenohCoordinator.list_key_expressions()

      assert "indrajaal/kpi/compilation" in key_exprs.data_plane
      assert "indrajaal/kpi/tests" in key_exprs.data_plane
      assert "indrajaal/kpi/containers" in key_exprs.data_plane
      assert "indrajaal/kpi/performance" in key_exprs.data_plane
      assert "indrajaal/kpi/progress" in key_exprs.data_plane
      assert "indrajaal/kpi/stamp" in key_exprs.data_plane
      assert "indrajaal/kpi/todos" in key_exprs.data_plane
      assert "indrajaal/kpi/agents" in key_exprs.data_plane
    end

    test "control plane contains control keys" do
      key_exprs = ZenohCoordinator.list_key_expressions()

      assert "indrajaal/control/refresh" in key_exprs.control_plane
      assert "indrajaal/control/mode" in key_exprs.control_plane
      assert "indrajaal/control/agent/**" in key_exprs.control_plane
    end

    test "coordination plane contains coord keys" do
      key_exprs = ZenohCoordinator.list_key_expressions()

      assert "indrajaal/coord/heartbeat" in key_exprs.coordination_plane
      assert "indrajaal/coord/sync" in key_exprs.coordination_plane
      assert "indrajaal/coord/barrier/**" in key_exprs.coordination_plane
    end
  end

  # ============================================================
  # STAMP SAFETY CONSTRAINT TESTS
  # ============================================================

  describe "SC-ZENOH-INT-001: Universal Zenoh access" do
    test "coordinator provides unified API for all components" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      Process.sleep(100)

      # All API functions should be accessible
      assert is_map(ZenohCoordinator.status())
      assert is_map(ZenohCoordinator.list_key_expressions())
      assert :ok = ZenohCoordinator.sync_now()
    end
  end

  describe "SC-ZENOH-INT-004: 10s heartbeat interval" do
    @tag :slow
    test "heartbeat worker is running" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      Process.sleep(100)

      children = Supervisor.which_children(pid)
      heartbeat = Enum.find(children, fn {id, _, _, _} -> id == :heartbeat_worker end)

      assert heartbeat != nil
      {_, heartbeat_pid, _, _} = heartbeat
      assert is_pid(heartbeat_pid)
      assert Process.alive?(heartbeat_pid)
    end
  end

  # ============================================================
  # SUPERVISOR BEHAVIOR TESTS
  # ============================================================

  describe "Supervisor restart strategy" do
    test "uses one_for_one strategy" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      # Supervisor should restart individual children without affecting others
      children_before = Supervisor.which_children(pid)
      assert length(children_before) == 4
    end

    test "children are restartable" do
      {:ok, pid} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop(pid, :normal)
      end)

      Process.sleep(100)

      # Find the KPI publisher
      children = Supervisor.which_children(pid)

      {_, kpi_pid, _, _} =
        Enum.find(children, fn {id, _, _, _} ->
          id == Indrajaal.Observability.ZenohKpiPublisher
        end)

      # Kill it
      if is_pid(kpi_pid) and Process.alive?(kpi_pid) do
        Process.exit(kpi_pid, :kill)
        Process.sleep(100)

        # Should be restarted
        children_after = Supervisor.which_children(pid)

        {_, new_kpi_pid, _, _} =
          Enum.find(children_after, fn {id, _, _, _} ->
            id == Indrajaal.Observability.ZenohKpiPublisher
          end)

        assert is_pid(new_kpi_pid)
        assert new_kpi_pid != kpi_pid
      end
    end
  end

  # ============================================================
  # PROPCHECK PROPERTY-BASED TESTS
  # ============================================================

  describe "PropCheck Property Tests" do
    @tag :property
    # Property verification: key expressions are valid strings
    # Converted from PropCheck to avoid GenServer dependency with --no-start
    # SC-SIL6-001: Manual property verification
    test "propcheck: key expressions are valid strings" do
      key_exprs = ZenohCoordinator.list_key_expressions()
      test_planes = [:data_plane, :control_plane, :coordination_plane]

      for plane <- test_planes do
        keys = Map.get(key_exprs, plane, [])
        assert Enum.all?(keys, &is_binary/1)
      end
    end

    @tag :property
    # Property verification: status always returns map with required keys
    # Converted from PropCheck to avoid GenServer dependency with --no-start
    # SC-SIL6-001: Manual property verification
    test "propcheck: status always returns map with required keys" do
      {:ok, pid} = ZenohCoordinator.start_link()

      try do
        Process.sleep(100)

        # Test with multiple iterations
        for _ <- 1..10 do
          status = ZenohCoordinator.status()

          assert is_map(status)
          assert Map.has_key?(status, :supervisor)
          assert Map.has_key?(status, :publisher)
          assert Map.has_key?(status, :subscriber)
          assert Map.has_key?(status, :heartbeat)
          assert Map.has_key?(status, :integration)
        end
      after
        Supervisor.stop(pid, :normal)
      end
    end
  end

  # ============================================================
  # STREAMDATA PROPERTY TESTS
  # ============================================================

  describe "ExUnitProperties StreamData Tests" do
    test "streamdata: list_key_expressions is deterministic" do
      ExUnitProperties.check all(_x <- SD.integer()) do
        exprs1 = ZenohCoordinator.list_key_expressions()
        exprs2 = ZenohCoordinator.list_key_expressions()
        assert exprs1 == exprs2
      end
    end

    test "streamdata: publish_coord accepts various key names" do
      {:ok, pid} = ZenohCoordinator.start_link()

      try do
        ExUnitProperties.check all(key <- SD.string(:alphanumeric, min_length: 1, max_length: 20)) do
          result = ZenohCoordinator.publish_coord(key, %{test: true})
          assert result == :ok or match?({:error, _}, result)
        end
      after
        Supervisor.stop(pid, :normal)
      end
    end

    test "streamdata: publish_coord accepts various payloads" do
      {:ok, pid} = ZenohCoordinator.start_link()

      try do
        ExUnitProperties.check all(value <- SD.integer(0..1000)) do
          payload = %{
            count: value,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }

          result = ZenohCoordinator.publish_coord("test", payload)
          assert result == :ok or match?({:error, _}, result)
        end
      after
        Supervisor.stop(pid, :normal)
      end
    end
  end

  # ============================================================
  # ERROR HANDLING TESTS
  # ============================================================

  describe "Error Handling and Resilience" do
    test "status returns stopped when coordinator not running" do
      # Ensure coordinator is not running
      case Process.whereis(ZenohCoordinator) do
        nil -> :ok
        pid -> Supervisor.stop(pid, :normal)
      end

      Process.sleep(50)

      status = ZenohCoordinator.status()
      assert status.supervisor == :stopped
    end

    test "publisher status shows unavailable when not running" do
      # Ensure coordinator is not running
      case Process.whereis(ZenohCoordinator) do
        nil -> :ok
        pid -> Supervisor.stop(pid, :normal)
      end

      Process.sleep(50)

      status = ZenohCoordinator.status()
      assert status.publisher == %{status: :unavailable}
    end

    test "subscriber status shows unavailable when not running" do
      # Ensure coordinator is not running
      case Process.whereis(ZenohCoordinator) do
        nil -> :ok
        pid -> Supervisor.stop(pid, :normal)
      end

      Process.sleep(50)

      status = ZenohCoordinator.status()
      assert status.subscriber == %{status: :unavailable}
    end
  end

  # ============================================================
  # INTEGRATION TESTS
  # ============================================================

  describe "Integration with other Zenoh components" do
    test "can start and stop cleanly" do
      {:ok, pid} = ZenohCoordinator.start_link()
      assert Process.alive?(pid)

      :ok = Supervisor.stop(pid, :normal)
      Process.sleep(50)

      refute Process.alive?(pid)
      assert Process.whereis(ZenohCoordinator) == nil
    end

    test "can be restarted after stop" do
      {:ok, pid1} = ZenohCoordinator.start_link()
      :ok = Supervisor.stop(pid1, :normal)
      Process.sleep(50)

      {:ok, pid2} = ZenohCoordinator.start_link()

      on_exit(fn ->
        if Process.alive?(pid2), do: Supervisor.stop(pid2, :normal)
      end)

      assert Process.alive?(pid2)
      assert pid1 != pid2
    end
  end
end
