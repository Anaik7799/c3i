defmodule Indrajaal.Observability.ProgressTrackerTest do
  @moduledoc """
  TDG Property Tests for ProgressTracker - Real-time multi-agent progress tracking.

  Implements Test-Driven Generation (TDG) methodology with dual property testing
  (PropCheck + ExUnitProperties) per SC-PROP-023/024.

  ## TDG Rules Verified

  | Rule ID     | Rule Description                                |
  |-------------|------------------------------------------------|
  | TDG-PTR-001 | Tests MUST be written before implementation    |
  | TDG-PTR-002 | All STAMP constraints have property tests      |
  | TDG-PTR-003 | 95% code coverage on ProgressTracker module    |
  | TDG-PTR-004 | PropCheck + ExUnitProperties dual testing      |

  ## STAMP Constraints Tested

  | Constraint  | Description                                     |
  |-------------|------------------------------------------------|
  | SC-PTR-001  | ETS writes must complete in <1ms               |
  | SC-PTR-002  | Agent status updates are non-blocking          |
  | SC-PTR-003  | KPI values persist across reads                |
  | SC-PTR-004  | Completion percentage is always 0-100          |
  | SC-PTR-005  | Snapshot history maintains chronological order |
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]

  # SC-PROP-024: Disambiguate generators
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias Indrajaal.Observability.ProgressTracker

  # ============================================================
  # SETUP / TEARDOWN
  # ============================================================

  setup do
    # Ensure clean state for each test
    if Process.whereis(ProgressTracker) do
      GenServer.stop(ProgressTracker)
      Process.sleep(10)
    end

    # Start fresh ProgressTracker
    {:ok, _pid} = ProgressTracker.start_link([])

    on_exit(fn ->
      if pid = Process.whereis(ProgressTracker) do
        try do
          GenServer.stop(pid)
        catch
          :exit, _ -> :ok
        end
      end
    end)

    :ok
  end

  # ============================================================
  # BASIC FUNCTIONALITY TESTS
  # ============================================================

  describe "start_link/1" do
    test "starts the GenServer with default options" do
      # Already started in setup
      assert Process.whereis(ProgressTracker) != nil
    end

    test "ETS table is created on startup" do
      # Verify ETS table exists
      assert :ets.whereis(:progress_tracker) != :undefined
    end
  end

  describe "get_progress/0" do
    test "returns initial progress state" do
      progress = ProgressTracker.get_progress()

      assert is_map(progress)
      assert Map.has_key?(progress, :agents)
      assert Map.has_key?(progress, :tasks)
      assert Map.has_key?(progress, :kpis)
      assert Map.has_key?(progress, :phase)
    end
  end

  # ============================================================
  # TDG-PTR-001: AGENT STATUS PROPERTY TESTS
  # ============================================================

  @tag :tdg
  @tag :stamp
  property "TDG-PTR-001: Agent status updates persist correctly (PropCheck)" do
    forall {agent_id, status} <- {PC.binary(), agent_status_gen()} do
      # Skip empty agent IDs
      if byte_size(agent_id) == 0 do
        true
      else
        :ok = ProgressTracker.update_agent_status(agent_id, status)
        progress = ProgressTracker.get_progress()

        case Map.get(progress.agents, agent_id) do
          nil -> false
          agent_data -> agent_data.status == status
        end
      end
    end
  end

  @tag :tdg
  test "TDG-PTR-001: Agent status transitions are valid (StreamData)" do
    ExUnitProperties.check all(
                             agent_id <- SD.string(:alphanumeric, min_length: 1),
                             statuses <-
                               SD.list_of(agent_status_sd_gen(), min_length: 1, max_length: 5)
                           ) do
      # Apply each status sequentially
      for status <- statuses do
        :ok = ProgressTracker.update_agent_status(agent_id, status)
      end

      progress = ProgressTracker.get_progress()
      final_status = List.last(statuses)

      # Final status should match last applied status
      assert progress.agents[agent_id].status == final_status
    end
  end

  # ============================================================
  # SC-PTR-001: ETS WRITE LATENCY PROPERTY TESTS
  # ============================================================

  @tag :tdg
  @tag :stamp
  property "SC-PTR-001: ETS writes complete in <1ms (PropCheck)" do
    forall {agent_id, status} <- {PC.binary(), agent_status_gen()} do
      if byte_size(agent_id) == 0 do
        true
      else
        start_time = System.monotonic_time(:microsecond)
        :ok = ProgressTracker.update_agent_status(agent_id, status)
        elapsed = System.monotonic_time(:microsecond) - start_time

        # Must complete in <1000 microseconds (1ms)
        elapsed < 1000
      end
    end
  end

  @tag :tdg
  @tag :stamp
  test "SC-PTR-001: Bulk ETS writes maintain <1ms latency (StreamData)" do
    ExUnitProperties.check all(
                             updates <-
                               SD.list_of(
                                 SD.tuple({
                                   SD.string(:alphanumeric, min_length: 1),
                                   agent_status_sd_gen()
                                 }),
                                 min_length: 10,
                                 max_length: 50
                               )
                           ) do
      for {agent_id, status} <- updates do
        start_time = System.monotonic_time(:microsecond)
        :ok = ProgressTracker.update_agent_status(agent_id, status)
        elapsed = System.monotonic_time(:microsecond) - start_time

        assert elapsed < 1000, "Write took #{elapsed}us, expected <1000us"
      end
    end
  end

  # ============================================================
  # SC-PTR-003: KPI PERSISTENCE PROPERTY TESTS
  # ============================================================

  @tag :tdg
  @tag :stamp
  property "SC-PTR-003: KPI values persist across reads (PropCheck)" do
    forall {kpi_name, value} <- {PC.binary(), PC.float()} do
      if byte_size(kpi_name) == 0 do
        true
      else
        :ok = ProgressTracker.update_kpi(kpi_name, value)

        # Read multiple times
        kpis1 = ProgressTracker.get_kpis()
        kpis2 = ProgressTracker.get_kpis()
        kpis3 = ProgressTracker.get_kpis()

        # All reads should return same value
        kpis1[kpi_name] == value and
          kpis2[kpi_name] == value and
          kpis3[kpi_name] == value
      end
    end
  end

  @tag :tdg
  test "SC-PTR-003: KPI history maintains chronological order (StreamData)" do
    ExUnitProperties.check all(
                             values <-
                               SD.list_of(SD.float(min: 0.0, max: 100.0),
                                 min_length: 3,
                                 max_length: 10
                               )
                           ) do
      kpi_name = "test_kpi_#{System.unique_integer([:positive])}"

      # Update KPI with multiple values
      for value <- values do
        :ok = ProgressTracker.update_kpi(kpi_name, value)
        # Ensure distinct timestamps
        Process.sleep(1)
      end

      # Verify final value is most recent
      kpis = ProgressTracker.get_kpis()
      assert kpis[kpi_name] == List.last(values)
    end
  end

  # ============================================================
  # SC-PTR-004: COMPLETION PERCENTAGE PROPERTY TESTS
  # ============================================================

  @tag :tdg
  @tag :stamp
  property "SC-PTR-004: Completion percentage is bounded 0-100 (PropCheck)" do
    forall completed <- PC.integer(0, 1000) do
      # Simulate task completion
      total_tasks = 100

      for i <- 1..min(completed, total_tasks) do
        task_id = "task_#{i}"
        ProgressTracker.update_agent_status(task_id, :completed)
      end

      percentage = ProgressTracker.get_completion_percentage()

      # Must be between 0 and 100
      percentage >= 0.0 and percentage <= 100.0
    end
  end

  @tag :tdg
  test "SC-PTR-004: Completion percentage calculates correctly (StreamData)" do
    ExUnitProperties.check all(
                             completed_count <- SD.integer(1..20),
                             failed_count <- SD.integer(1..5),
                             running_count <- SD.integer(1..5)
                           ) do
      # Reset progress for clean calculation - direct ETS clear for reliability
      :ets.delete_all_objects(:progress_tracker)
      unique_prefix = System.unique_integer([:positive])

      total = completed_count + failed_count + running_count

      # Create tasks with different statuses using unique prefix
      for i <- 1..completed_count do
        ProgressTracker.update_agent_status("#{unique_prefix}_completed_#{i}", :completed)
      end

      for i <- 1..failed_count do
        ProgressTracker.update_agent_status("#{unique_prefix}_failed_#{i}", :failed)
      end

      for i <- 1..running_count do
        ProgressTracker.update_agent_status("#{unique_prefix}_running_#{i}", :running)
      end

      # Get progress data to count agents
      progress = ProgressTracker.get_progress()
      agent_count = map_size(progress.agents)

      # Verify the correct number of agents were created
      assert agent_count == total

      percentage = ProgressTracker.get_completion_percentage()

      # Calculate expected percentage
      expected = completed_count / total * 100.0

      # Allow small floating point tolerance
      assert_in_delta percentage, expected, 0.1
    end
  end

  # ============================================================
  # SC-PTR-005: SNAPSHOT HISTORY PROPERTY TESTS
  # ============================================================

  @tag :tdg
  @tag :stamp
  property "SC-PTR-005: Snapshot timestamps are monotonically increasing (PropCheck)" do
    forall count <- PC.integer(2, 20) do
      # Create multiple snapshots
      for _ <- 1..count do
        ProgressTracker.take_snapshot()
        # Ensure distinct timestamps
        Process.sleep(1)
      end

      snapshots = ProgressTracker.get_snapshots()

      # Verify timestamps are ordered
      timestamps = Enum.map(snapshots, & &1.timestamp)

      timestamps
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.all?(fn [t1, t2] ->
        DateTime.compare(t1, t2) in [:lt, :eq]
      end)
    end
  end

  @tag :tdg
  test "SC-PTR-005: Snapshots preserve state at time of capture (StreamData)" do
    ExUnitProperties.check all(kpi_value <- SD.float(min: 0.0, max: 1000.0)) do
      kpi_name = "snapshot_test_#{System.unique_integer([:positive])}"

      # Set KPI value
      :ok = ProgressTracker.update_kpi(kpi_name, kpi_value)

      # Take snapshot
      {:ok, snapshot_id} = ProgressTracker.take_snapshot()

      # Modify KPI after snapshot
      :ok = ProgressTracker.update_kpi(kpi_name, kpi_value * 2)

      # Get snapshot - should have original value
      {:ok, snapshot} = ProgressTracker.get_snapshot(snapshot_id)

      # Snapshot should preserve original value
      assert snapshot.kpis[kpi_name] == kpi_value
    end
  end

  # ============================================================
  # SC-PTR-002: NON-BLOCKING UPDATES PROPERTY TESTS
  # ============================================================

  @tag :tdg
  @tag :stamp
  test "SC-PTR-002: Concurrent updates do not block (StreamData)" do
    ExUnitProperties.check all(
                             updates <-
                               SD.list_of(
                                 SD.tuple({
                                   SD.string(:alphanumeric, min_length: 1),
                                   agent_status_sd_gen()
                                 }),
                                 min_length: 20,
                                 max_length: 100
                               )
                           ) do
      # Spawn concurrent updaters
      tasks =
        Enum.map(updates, fn {agent_id, status} ->
          Task.async(fn ->
            start = System.monotonic_time(:microsecond)
            :ok = ProgressTracker.update_agent_status(agent_id, status)
            System.monotonic_time(:microsecond) - start
          end)
        end)

      # All tasks should complete
      results = Task.await_many(tasks, 5000)

      # All updates should be non-blocking (< 5ms even with contention)
      assert Enum.all?(results, &(&1 < 5000))
    end
  end

  # ============================================================
  # PUBSUB / SUBSCRIPTION TESTS
  # ============================================================

  describe "subscribe/0" do
    test "returns subscription reference" do
      result = ProgressTracker.subscribe()
      assert {:ok, _ref} = result
    end

    test "subscribers receive agent status updates" do
      {:ok, _ref} = ProgressTracker.subscribe()

      # Update agent status
      :ok = ProgressTracker.update_agent_status("test_agent", :running)

      # Should receive notification
      assert_receive {:progress_update, %{type: :agent_status}}, 1000
    end

    test "subscribers receive KPI updates" do
      {:ok, _ref} = ProgressTracker.subscribe()

      # Update KPI
      :ok = ProgressTracker.update_kpi("test_kpi", 42.5)

      # Should receive notification
      assert_receive {:progress_update, %{type: :kpi_update}}, 1000
    end
  end

  # ============================================================
  # PHASE PROGRESSION TESTS
  # ============================================================

  describe "phase progression" do
    test "tracks phase transitions 1 -> 2 -> 3" do
      progress = ProgressTracker.get_progress()
      assert progress.phase == 1

      # Advance to phase 2
      :ok = ProgressTracker.advance_phase()
      progress = ProgressTracker.get_progress()
      assert progress.phase == 2

      # Advance to phase 3
      :ok = ProgressTracker.advance_phase()
      progress = ProgressTracker.get_progress()
      assert progress.phase == 3
    end

    test "phase cannot exceed 3" do
      # Advance multiple times
      for _ <- 1..5 do
        ProgressTracker.advance_phase()
      end

      progress = ProgressTracker.get_progress()
      assert progress.phase == 3
    end
  end

  # ============================================================
  # RESET FUNCTIONALITY TESTS
  # ============================================================

  describe "reset/0" do
    test "clears all tracked data" do
      # Add some data
      ProgressTracker.update_agent_status("agent_1", :running)
      ProgressTracker.update_kpi("kpi_1", 100.0)

      # Verify data exists
      progress = ProgressTracker.get_progress()
      assert map_size(progress.agents) > 0

      # Reset
      :ok = ProgressTracker.reset()

      # Verify data is cleared
      progress = ProgressTracker.get_progress()
      assert map_size(progress.agents) == 0
      assert map_size(progress.kpis) == 0
    end
  end

  # ============================================================
  # GENERATORS
  # ============================================================

  # PropCheck generators (PC. prefix)
  defp agent_status_gen do
    PC.oneof([:pending, :running, :completed, :failed])
  end

  # StreamData generators (SD. prefix)
  defp agent_status_sd_gen do
    SD.member_of([:pending, :running, :completed, :failed])
  end
end
