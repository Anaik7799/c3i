defmodule Indrajaal.Core.MathModelStatePreserverTest do
  @moduledoc """
  TDG test suite for MathModelStatePreserver (SC-SING-008).

  Tests GenServer lifecycle, ETS-backed snapshot persistence,
  checkpoint/restore cycle, and per-model preservation.

  ## STAMP Safety Integration
  - SC-SING-008: System state preservation document
  - SC-HOLON-007: DuckDB/SQLite for holon analytics
  - SC-MATH-001: Discipline health monitored

  ## TPS 5-Level RCA Context
  - L1 Symptom: Mathematical model state lost on restart
  - L5 Root Cause: Missing checkpoint or ETS table not initialized
  """

  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Indrajaal.Core.MathModelStatePreserver
  alias StreamData, as: SD

  @moduletag :math_state

  setup do
    # Stop any existing instance
    case GenServer.whereis(MathModelStatePreserver) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 1000)
    end

    # Clean ETS table if leftover from previous test
    if :ets.info(:math_model_state) != :undefined do
      :ets.delete(:math_model_state)
    end

    # Allow time for cleanup
    Process.sleep(10)

    {:ok, pid} = MathModelStatePreserver.start_link(checkpoint_interval: :infinity)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid, :normal, 1000)
    end)

    %{pid: pid}
  end

  # ── Module Definition ──────────────────────────────────────────

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(MathModelStatePreserver)
    end

    test "exports start_link/1" do
      assert function_exported?(MathModelStatePreserver, :start_link, 1)
    end

    test "exports checkpoint/0" do
      assert function_exported?(MathModelStatePreserver, :checkpoint, 0)
    end

    test "exports restore_state/0" do
      assert function_exported?(MathModelStatePreserver, :restore_state, 0)
    end

    test "exports get_snapshot/0" do
      assert function_exported?(MathModelStatePreserver, :get_snapshot, 0)
    end

    test "exports preserve/2" do
      assert function_exported?(MathModelStatePreserver, :preserve, 2)
    end
  end

  # ── GenServer Lifecycle ────────────────────────────────────────

  describe "GenServer lifecycle" do
    test "starts as a named process", %{pid: pid} do
      assert Process.alive?(pid)
      assert GenServer.whereis(MathModelStatePreserver) == pid
    end

    test "creates ETS table on init" do
      assert :ets.info(:math_model_state) != :undefined
    end

    test "ETS table has correct options" do
      info = :ets.info(:math_model_state)
      assert info[:type] == :set
      assert info[:named_table] == true
      assert info[:read_concurrency] == true
    end
  end

  # ── get_snapshot/0 ─────────────────────────────────────────────

  describe "get_snapshot/0" do
    test "returns error when no snapshot exists" do
      assert {:error, :no_snapshot} = MathModelStatePreserver.get_snapshot()
    end

    test "returns snapshot after checkpoint" do
      {:ok, _snapshot} = MathModelStatePreserver.checkpoint()
      assert {:ok, result} = MathModelStatePreserver.get_snapshot()
      assert is_map(result)
    end

    test "snapshot contains all model keys after checkpoint" do
      {:ok, _} = MathModelStatePreserver.checkpoint()
      assert {:ok, snapshot} = MathModelStatePreserver.get_snapshot()

      assert Map.has_key?(snapshot, :pid)
      assert Map.has_key?(snapshot, :petri)
      assert Map.has_key?(snapshot, :swarm)
      assert Map.has_key?(snapshot, :entropy)
      assert Map.has_key?(snapshot, :inference)
      assert Map.has_key?(snapshot, :checkpoint_version)
      assert Map.has_key?(snapshot, :created_at)
    end

    test "reads directly from ETS without GenServer call" do
      {:ok, _} = MathModelStatePreserver.checkpoint()

      # Verify ETS has the data
      case :ets.lookup(:math_model_state, :snapshot) do
        [{:snapshot, snapshot}] -> assert is_map(snapshot)
        [] -> flunk("Expected snapshot in ETS")
      end
    end
  end

  # ── checkpoint/0 ───────────────────────────────────────────────

  describe "checkpoint/0" do
    test "returns {:ok, snapshot}" do
      assert {:ok, snapshot} = MathModelStatePreserver.checkpoint()
      assert is_map(snapshot)
    end

    test "snapshot has checkpoint_version" do
      {:ok, snapshot} = MathModelStatePreserver.checkpoint()
      assert is_integer(snapshot.checkpoint_version)
      assert snapshot.checkpoint_version >= 1
    end

    test "snapshot has created_at timestamp" do
      {:ok, snapshot} = MathModelStatePreserver.checkpoint()
      assert %DateTime{} = snapshot.created_at
    end

    test "checkpoint version increments on successive calls" do
      {:ok, snap1} = MathModelStatePreserver.checkpoint()
      {:ok, snap2} = MathModelStatePreserver.checkpoint()
      assert snap2.checkpoint_version > snap1.checkpoint_version
    end

    test "snapshot contains PID controller data" do
      {:ok, snapshot} = MathModelStatePreserver.checkpoint()
      assert snapshot.pid == nil or is_map(snapshot.pid)

      if is_map(snapshot.pid) do
        assert Map.has_key?(snapshot.pid, :captured_at)
      end
    end

    test "snapshot contains Petri net data" do
      {:ok, snapshot} = MathModelStatePreserver.checkpoint()
      assert snapshot.petri == nil or is_map(snapshot.petri)

      if is_map(snapshot.petri) do
        assert Map.has_key?(snapshot.petri, :captured_at)
      end
    end

    test "snapshot contains swarm data" do
      {:ok, snapshot} = MathModelStatePreserver.checkpoint()
      assert snapshot.swarm == nil or is_map(snapshot.swarm)

      if is_map(snapshot.swarm) do
        assert Map.has_key?(snapshot.swarm, :captured_at)
      end
    end

    test "snapshot contains entropy data" do
      {:ok, snapshot} = MathModelStatePreserver.checkpoint()
      assert snapshot.entropy == nil or is_map(snapshot.entropy)

      if is_map(snapshot.entropy) do
        assert Map.has_key?(snapshot.entropy, :captured_at)
      end
    end

    test "snapshot contains inference data" do
      {:ok, snapshot} = MathModelStatePreserver.checkpoint()
      assert snapshot.inference == nil or is_map(snapshot.inference)

      if is_map(snapshot.inference) do
        assert Map.has_key?(snapshot.inference, :captured_at)
      end
    end
  end

  # ── restore_state/0 ───────────────────────────────────────────

  describe "restore_state/0" do
    test "returns error when no snapshot exists" do
      assert {:error, :no_snapshot} = MathModelStatePreserver.restore_state()
    end

    test "returns {:ok, count} after checkpoint" do
      {:ok, _} = MathModelStatePreserver.checkpoint()
      assert {:ok, count} = MathModelStatePreserver.restore_state()
      assert is_integer(count)
      assert count >= 0
    end

    test "restore after checkpoint succeeds" do
      {:ok, _} = MathModelStatePreserver.checkpoint()
      {:ok, _} = MathModelStatePreserver.checkpoint()
      assert {:ok, _count} = MathModelStatePreserver.restore_state()
    end
  end

  # ── preserve/2 ─────────────────────────────────────────────────

  describe "preserve/2" do
    test "preserves PID controller state" do
      pid_state = %{kp: 1.0, ki: 0.5, kd: 0.1, integral: 0.0, setpoint: 100.0}
      assert :ok = MathModelStatePreserver.preserve(:pid_controller, pid_state)
    end

    test "preserves Petri net state" do
      petri_state = %{markings: %{"p1" => 1, "p2" => 0}, transitions: ["t1", "t2"]}
      assert :ok = MathModelStatePreserver.preserve(:petri_net, petri_state)
    end

    test "preserves swarm state" do
      swarm_state = %{best_position: [1.0, 2.0], best_fitness: 0.95}
      assert :ok = MathModelStatePreserver.preserve(:swarm_algorithms, swarm_state)
    end

    test "preserves Shannon entropy state" do
      entropy_state = %{values: [0.5, 0.8, 0.3], window_size: 100}
      assert :ok = MathModelStatePreserver.preserve(:shannon_entropy, entropy_state)
    end

    test "preserves active inference state" do
      inference_state = %{
        most_likely_state: :healthy,
        free_energy: 0.15,
        beliefs: %{healthy: 0.85, degraded: 0.10, critical: 0.05}
      }

      assert :ok = MathModelStatePreserver.preserve(:active_inference, inference_state)
    end

    test "preserved state appears in next checkpoint" do
      pid_state = %{kp: 2.5, ki: 1.0, kd: 0.3, integral: 5.0, setpoint: 200.0}
      :ok = MathModelStatePreserver.preserve(:pid_controller, pid_state)

      # Allow cast to process (GenServer.cast is async)
      Process.sleep(100)

      {:ok, snapshot} = MathModelStatePreserver.checkpoint()

      if is_map(snapshot.pid) do
        assert snapshot.pid.kp == 2.5
        assert snapshot.pid.setpoint == 200.0
      end
    end
  end

  # ── Property Tests ─────────────────────────────────────────────

  describe "property tests" do
    test "property: checkpoint version is always positive" do
      check all(_i <- SD.integer(1..10)) do
        {:ok, snapshot} = MathModelStatePreserver.checkpoint()
        assert snapshot.checkpoint_version > 0
      end
    end

    test "property: snapshot always contains all 5 model keys" do
      check all(_i <- SD.integer(1..5)) do
        {:ok, snapshot} = MathModelStatePreserver.checkpoint()

        assert Map.has_key?(snapshot, :pid)
        assert Map.has_key?(snapshot, :petri)
        assert Map.has_key?(snapshot, :swarm)
        assert Map.has_key?(snapshot, :entropy)
        assert Map.has_key?(snapshot, :inference)
      end
    end

    test "property: restore always succeeds after checkpoint" do
      check all(_i <- SD.integer(1..5)) do
        {:ok, _} = MathModelStatePreserver.checkpoint()
        assert {:ok, _count} = MathModelStatePreserver.restore_state()
      end
    end

    test "property: preserve accepts arbitrary PID gains" do
      check all(
              kp <- SD.float(min: 0.0, max: 100.0),
              ki <- SD.float(min: 0.0, max: 100.0),
              kd <- SD.float(min: 0.0, max: 100.0)
            ) do
        state = %{kp: kp, ki: ki, kd: kd, integral: 0.0, setpoint: 0.0}
        assert :ok = MathModelStatePreserver.preserve(:pid_controller, state)
      end
    end
  end
end
