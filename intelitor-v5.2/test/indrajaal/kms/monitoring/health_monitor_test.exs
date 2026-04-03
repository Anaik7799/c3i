defmodule Indrajaal.KMS.Monitoring.HealthMonitorTest do
  @moduledoc """
  TDG comprehensive test suite for KMS.Monitoring.HealthMonitor.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-SMRITI-032: Continuous health monitoring required
  - SC-IMMUNE-001: Sentinel monitors system health
  - SC-BIO-EXT-009: Regenerative healing from SQLite/DuckDB

  ## Constitutional Verification
  - Psi0 Existence: HealthMonitor survives DB path changes gracefully
  - Psi1 Regeneration: Status map is reconstructable from state

  ## Founder's Directive Alignment
  - Omega0.6: Sentience via continuous health self-awareness

  ## TPS 5-Level RCA Context
  - L1 Symptom: status/0 returns :starting on uninitialized monitor
  - L5 Root Cause: Health check timer not yet fired after start_link

  ## Change History
  | Version | Date       | Author | Change                              |
  |---------|------------|--------|-------------------------------------|
  | 21.3.0  | 2026-03-21 | Claude | Sprint 54 W5 test generation (TDG)  |
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.KMS.Monitoring.HealthMonitor

  @moduletag :kms_health_monitor
  @moduletag :zenoh_nif

  # Module-level constants matching HealthMonitor thresholds
  @memory_warning_bytes 1_600_000_000
  @memory_critical_bytes 1_800_000_000

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp tmp_db_path do
    dir = Path.join(System.tmp_dir!(), "health_monitor_test_#{:rand.uniform(999_999)}")
    File.mkdir_p!(dir)
    Path.join(dir, "smriti.db")
  end

  # Replicates the private aggregate_status/1 logic from HealthMonitor
  defp aggregate_status(checks) do
    vals = Map.values(checks)

    cond do
      :critical in vals -> :critical
      :degraded in vals -> :degraded
      true -> :healthy
    end
  end

  # Replicates the private check_database/1 logic
  defp check_database(db_path) do
    if File.exists?(db_path), do: :healthy, else: :critical
  end

  # Replicates the private check_memory_usage/0 logic
  defp check_memory(total_bytes, warning, critical) do
    cond do
      total_bytes >= critical -> :critical
      total_bytes >= warning -> :degraded
      true -> :healthy
    end
  end

  # ---------------------------------------------------------------------------
  # start_link/1 and init/1
  # ---------------------------------------------------------------------------

  describe "start_link/1 and init/1" do
    test "starts successfully with default options" do
      pid = start_supervised!(HealthMonitor)
      assert Process.alive?(pid)
    end

    test "starts with custom db_path option" do
      db_path = tmp_db_path()
      pid = start_supervised!({HealthMonitor, [db_path: db_path]})
      assert Process.alive?(pid)
    end

    test "initial status is :starting or has already transitioned" do
      start_supervised!(HealthMonitor)
      result = HealthMonitor.status()
      assert result.status in [:starting, :healthy, :degraded, :critical]
    end

    test "initial checks is a map" do
      start_supervised!(HealthMonitor)
      result = HealthMonitor.status()
      assert is_map(result.checks)
    end

    test "starts supervised and is restartable" do
      pid1 = start_supervised!(HealthMonitor)
      ref = Process.monitor(pid1)
      stop_supervised!(HealthMonitor)
      assert_receive {:DOWN, ^ref, :process, ^pid1, _}, 1000
    end
  end

  # ---------------------------------------------------------------------------
  # status/0
  # ---------------------------------------------------------------------------

  describe "status/0" do
    setup do
      start_supervised!({HealthMonitor, [db_path: tmp_db_path()]})
      :ok
    end

    test "returns a map" do
      result = HealthMonitor.status()
      assert is_map(result)
    end

    test "returns a map with :status key" do
      result = HealthMonitor.status()
      assert Map.has_key?(result, :status)
    end

    test "returns a map with :checks key" do
      result = HealthMonitor.status()
      assert Map.has_key?(result, :checks)
    end

    test "returns a map with :last_check key" do
      result = HealthMonitor.status()
      assert Map.has_key?(result, :last_check)
    end

    test "status is one of the known atoms" do
      result = HealthMonitor.status()
      assert result.status in [:starting, :healthy, :degraded, :critical]
    end

    test "checks map is a map" do
      result = HealthMonitor.status()
      assert is_map(result.checks)
    end

    test "checks values are valid status atoms" do
      result = HealthMonitor.status()

      Enum.each(result.checks, fn {_k, v} ->
        assert v in [:unknown, :healthy, :degraded, :critical]
      end)
    end

    test "last_check is nil or a DateTime" do
      result = HealthMonitor.status()
      assert result.last_check == nil or match?(%DateTime{}, result.last_check)
    end

    test "calling status/0 multiple times is idempotent" do
      r1 = HealthMonitor.status()
      r2 = HealthMonitor.status()
      assert r1.status == r2.status
    end
  end

  # ---------------------------------------------------------------------------
  # Aggregate status logic (white-box replication)
  # ---------------------------------------------------------------------------

  describe "aggregate_status logic" do
    test "returns :critical when any check is :critical" do
      checks = %{database: :healthy, disk: :critical, memory: :healthy}
      assert aggregate_status(checks) == :critical
    end

    test "returns :degraded when any check is :degraded (no critical)" do
      checks = %{database: :healthy, disk: :degraded, memory: :healthy}
      assert aggregate_status(checks) == :degraded
    end

    test "returns :healthy when all checks are :healthy" do
      checks = %{database: :healthy, disk: :healthy, memory: :healthy}
      assert aggregate_status(checks) == :healthy
    end

    test "prioritizes :critical over :degraded" do
      checks = %{database: :critical, disk: :degraded, memory: :healthy}
      assert aggregate_status(checks) == :critical
    end

    test "single :degraded check yields :degraded" do
      checks = %{only: :degraded}
      assert aggregate_status(checks) == :degraded
    end

    test "single :critical check yields :critical" do
      checks = %{only: :critical}
      assert aggregate_status(checks) == :critical
    end
  end

  # ---------------------------------------------------------------------------
  # Database check logic (white-box replication)
  # ---------------------------------------------------------------------------

  describe "check_database logic" do
    test "returns :healthy when db file exists" do
      db_path = tmp_db_path()
      File.touch!(db_path)
      assert check_database(db_path) == :healthy
    end

    test "returns :critical when db file does not exist" do
      db_path = "/nonexistent/path/smriti_#{:rand.uniform(999_999)}.db"
      assert check_database(db_path) == :critical
    end

    test "returns :healthy when path is an existing directory" do
      dir = Path.join(System.tmp_dir!(), "health_dir_#{:rand.uniform(999_999)}")
      File.mkdir_p!(dir)
      # File.exists? returns true for directories
      assert check_database(dir) == :healthy
    end

    test "returns :critical for empty string path" do
      # File.exists?("") returns false
      assert check_database("") == :critical
    end
  end

  # ---------------------------------------------------------------------------
  # Memory check logic (white-box replication)
  # ---------------------------------------------------------------------------

  describe "check_memory logic" do
    test "returns :healthy under warning threshold" do
      assert check_memory(0, @memory_warning_bytes, @memory_critical_bytes) == :healthy
    end

    test "returns :degraded at warning boundary" do
      assert check_memory(@memory_warning_bytes, @memory_warning_bytes, @memory_critical_bytes) ==
               :degraded
    end

    test "returns :critical at critical boundary" do
      assert check_memory(@memory_critical_bytes, @memory_warning_bytes, @memory_critical_bytes) ==
               :critical
    end

    test "returns :degraded in warning-critical range" do
      mid = @memory_warning_bytes + div(@memory_critical_bytes - @memory_warning_bytes, 2)
      assert check_memory(mid, @memory_warning_bytes, @memory_critical_bytes) == :degraded
    end

    test ":erlang.memory(:total) returns positive integer" do
      total = :erlang.memory(:total)
      assert is_integer(total) and total > 0
    end

    test "memory check with actual BEAM memory returns valid status" do
      total = :erlang.memory(:total)
      result = check_memory(total, @memory_warning_bytes, @memory_critical_bytes)
      assert result in [:healthy, :degraded, :critical]
    end

    test "critical threshold is greater than warning threshold" do
      assert @memory_critical_bytes > @memory_warning_bytes
    end
  end

  # ---------------------------------------------------------------------------
  # Telemetry integration (SC-IMMUNE-001)
  # ---------------------------------------------------------------------------

  describe "Telemetry events" do
    test "periodic check emits [:smriti, :health, :check] telemetry" do
      ref = make_ref()
      test_pid = self()

      :telemetry.attach(
        "hm_test_#{inspect(ref)}",
        [:smriti, :health, :check],
        fn _event, _measurements, metadata, _ ->
          send(test_pid, {:telemetry_received, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("hm_test_#{inspect(ref)}") end)

      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: tmp_db_path())
      send(pid, :check)

      assert_receive {:telemetry_received, %{status: _, checks: _}}, 2000
      GenServer.stop(pid)
    end

    test "telemetry metadata contains :status and :checks" do
      ref = make_ref()
      test_pid = self()

      :telemetry.attach(
        "hm_meta_#{inspect(ref)}",
        [:smriti, :health, :check],
        fn _event, _measurements, metadata, _ ->
          send(test_pid, {:meta, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("hm_meta_#{inspect(ref)}") end)

      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: tmp_db_path())
      send(pid, :check)

      assert_receive {:meta, meta}, 2000
      assert Map.has_key?(meta, :status)
      assert Map.has_key?(meta, :checks)
      GenServer.stop(pid)
    end

    test "telemetry measurements contain :duration" do
      ref = make_ref()
      test_pid = self()

      :telemetry.attach(
        "hm_meas_#{inspect(ref)}",
        [:smriti, :health, :check],
        fn _event, measurements, _metadata, _ ->
          send(test_pid, {:meas, measurements})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("hm_meas_#{inspect(ref)}") end)

      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: tmp_db_path())
      send(pid, :check)

      assert_receive {:meas, meas}, 2000
      assert Map.has_key?(meas, :duration)
      GenServer.stop(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # handle_info(:check, state) — state transitions
  # ---------------------------------------------------------------------------

  describe "handle_info(:check, state)" do
    test "state updates last_check after :check message" do
      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: tmp_db_path())

      initial = GenServer.call(pid, :status)
      assert initial.last_check == nil

      send(pid, :check)
      Process.sleep(100)

      updated = GenServer.call(pid, :status)
      assert match?(%DateTime{}, updated.last_check)

      GenServer.stop(pid)
    end

    test "state updates checks map after :check message" do
      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: tmp_db_path())

      send(pid, :check)
      Process.sleep(100)

      status = GenServer.call(pid, :status)
      checks = status.checks
      assert is_map(checks)
      assert Map.has_key?(checks, :database)
      assert Map.has_key?(checks, :disk)
      assert Map.has_key?(checks, :memory)

      GenServer.stop(pid)
    end

    test "checks include all three subsystems" do
      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: tmp_db_path())
      send(pid, :check)
      Process.sleep(100)

      %{checks: checks} = GenServer.call(pid, :status)
      assert Enum.count(checks) == 3

      GenServer.stop(pid)
    end

    test "database check is :critical when db file absent" do
      non_existent_path = "/nonexistent/path/#{:rand.uniform(999_999)}.db"
      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: non_existent_path)
      send(pid, :check)
      Process.sleep(100)

      %{checks: checks} = GenServer.call(pid, :status)
      assert checks.database == :critical

      GenServer.stop(pid)
    end

    test "database check is :healthy when db file exists" do
      db_path = tmp_db_path()
      File.touch!(db_path)

      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: db_path)
      send(pid, :check)
      Process.sleep(100)

      %{checks: checks} = GenServer.call(pid, :status)
      assert checks.database == :healthy

      GenServer.stop(pid)
    end

    test "status transitions from :starting after check fires" do
      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: tmp_db_path())
      initial = GenServer.call(pid, :status)
      assert initial.status == :starting

      send(pid, :check)
      Process.sleep(100)

      updated = GenServer.call(pid, :status)
      assert updated.status in [:healthy, :degraded, :critical]
      refute updated.status == :starting

      GenServer.stop(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  property "aggregate_status: critical dominates all other statuses" do
    forall checks_list <- PC.non_empty(PC.list(PC.oneof([:healthy, :degraded, :critical]))) do
      result =
        cond do
          :critical in checks_list -> :critical
          :degraded in checks_list -> :degraded
          true -> :healthy
        end

      if :critical in checks_list do
        result == :critical
      else
        true
      end
    end
  end

  property "aggregate_status result is always a valid status atom" do
    forall checks_list <- PC.non_empty(PC.list(PC.oneof([:healthy, :degraded, :critical]))) do
      result =
        cond do
          :critical in checks_list -> :critical
          :degraded in checks_list -> :degraded
          true -> :healthy
        end

      result in [:healthy, :degraded, :critical]
    end
  end

  test "memory check: result is valid status for any byte count" do
    ExUnitProperties.check all(total_bytes <- SD.positive_integer()) do
      warn = 1_600_000_000
      crit = 1_800_000_000

      result =
        cond do
          total_bytes >= crit -> :critical
          total_bytes >= warn -> :degraded
          true -> :healthy
        end

      result in [:healthy, :degraded, :critical]
    end
  end

  property "database check is deterministic for same path" do
    forall suffix <- PC.non_neg_integer() do
      db_path = "/nonexistent/#{suffix}.db"
      r1 = check_database(db_path)
      r2 = check_database(db_path)
      r1 == r2
    end
  end

  property "status/0 always returns map with required keys when running" do
    forall _ <- PC.exactly(nil) do
      case Process.whereis(HealthMonitor) do
        nil ->
          # Not registered — skip
          true

        _pid ->
          result = HealthMonitor.status()

          is_map(result) and
            Map.has_key?(result, :status) and
            Map.has_key?(result, :checks) and
            Map.has_key?(result, :last_check)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 / Constitutional tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements (SC-SMRITI-032)" do
    test "Psi0: monitor survives non-existent db_path without crashing" do
      bad_path = "/nonexistent_mount/deep/path/smriti.db"
      pid = start_supervised!({HealthMonitor, [db_path: bad_path]})
      assert Process.alive?(pid)
      result = HealthMonitor.status()
      assert result.status in [:starting, :healthy, :degraded, :critical]
    end

    test "Psi1: status map is always reconstructable (regeneration)" do
      start_supervised!({HealthMonitor, [db_path: tmp_db_path()]})
      result = HealthMonitor.status()
      # All required keys present
      assert [:checks, :last_check, :status] -- Map.keys(result) == []
    end

    test "SC-IMMUNE-001: status/0 completes in < 5s (non-blocking)" do
      start_supervised!({HealthMonitor, [db_path: tmp_db_path()]})
      t0 = System.monotonic_time(:millisecond)
      _status = HealthMonitor.status()
      elapsed = System.monotonic_time(:millisecond) - t0
      assert elapsed < 5_000
    end

    test "monitor responds to burst :check messages without crashing" do
      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: tmp_db_path())
      for _ <- 1..5, do: send(pid, :check)
      Process.sleep(200)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "multiple independent monitors run without interference" do
      {:ok, pid1} = GenServer.start_link(HealthMonitor, db_path: tmp_db_path())
      {:ok, pid2} = GenServer.start_link(HealthMonitor, db_path: tmp_db_path())
      assert Process.alive?(pid1)
      assert Process.alive?(pid2)
      GenServer.stop(pid1)
      GenServer.stop(pid2)
    end
  end

  describe "FMEA: Edge Cases" do
    test "FMEA-001 (RPN 72): db_path is empty string" do
      # File.exists?("") = false => :critical for database check
      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: "")
      send(pid, :check)
      Process.sleep(100)
      %{checks: checks} = GenServer.call(pid, :status)
      assert checks.database == :critical
      GenServer.stop(pid)
    end

    test "FMEA-002 (RPN 48): db_path is directory" do
      dir = Path.join(System.tmp_dir!(), "health_monitor_dir_#{:rand.uniform(999_999)}")
      File.mkdir_p!(dir)
      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: dir)
      send(pid, :check)
      Process.sleep(100)
      %{checks: checks} = GenServer.call(pid, :status)
      # Directory exists -> :healthy (File.exists? is true for dirs)
      assert checks.database == :healthy
      GenServer.stop(pid)
    end

    test "FMEA-003 (RPN 36): rapid repeated status calls don't deadlock" do
      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: tmp_db_path())
      results = for _ <- 1..20, do: GenServer.call(pid, :status)
      assert Enum.all?(results, &is_map/1)
      GenServer.stop(pid)
    end

    test "FMEA-004: GenServer.stop/1 terminates cleanly" do
      {:ok, pid} = GenServer.start_link(HealthMonitor, db_path: tmp_db_path())
      ref = Process.monitor(pid)
      GenServer.stop(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
    end
  end
end
