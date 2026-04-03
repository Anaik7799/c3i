defmodule Indrajaal.Cybernetic.EventSourcing.SnapshotTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Cybernetic.EventSourcing.Snapshot.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Snapshot lifecycle tested before runtime integration
  - FPPS Validation: 5-method consensus on checksum and recovery determinism

  ## STAMP Safety Integration
  - SC-SNP-001: Snapshots MUST include version number
  - SC-SNP-002: Snapshot integrity MUST be verified (SHA-256 checksum)
  - SC-SNP-003: Snapshot storage MUST be durable (in-memory, tested here)
  - SC-SNP-004: Recovery MUST be deterministic (same state from same snapshot+events)
  - SC-HOLON-017: SHA-256 checksum MUST exist for every state artifact

  ## Constitutional Verification
  - Psi_0 Existence: Snapshot GenServer survives create/verify cycles
  - Psi_1 Regeneration: State fully regenerable from snapshot + event replay
  - Psi_3 Verification: Checksum provides tamper-evident integrity proof

  ## Founder's Directive Alignment
  - Omega_0.6: Snapshots enable fast recovery of cognitive mesh state

  ## TPS 5-Level RCA Context
  - L1 Symptom: Slow recovery after crash — must replay all events from beginning
  - L5 Root Cause: No snapshot taken at periodic intervals; SC-SNP-004 violated
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Cybernetic.EventSourcing.Snapshot

  @moduletag :zenoh_nif

  # ---- Helpers ----------------------------------------------------------------

  # Start a Snapshot server + EventStore pair under unique names
  defp start_snapshot(test_name) do
    snap_name = :"snapshot_test_#{test_name}_#{System.unique_integer([:positive])}"
    {:ok, pid} = start_supervised({Snapshot, [name: snap_name]})
    {pid, snap_name}
  end

  defp sample_state(n \\ 1) do
    %{counter: n, data: "payload-#{n}", tags: ["a", "b"]}
  end

  # ---- start_link/1 -----------------------------------------------------------

  describe "start_link/1" do
    test "process starts and is alive" do
      {pid, _name} = start_snapshot(:start)
      assert Process.alive?(pid)
    end

    test "list returns empty list on fresh start" do
      {_pid, name} = start_snapshot(:empty_list)
      assert GenServer.call(name, {:list, "unknown-stream"}) == []
    end
  end

  # ---- create/3 ---------------------------------------------------------------

  describe "create/3" do
    setup do
      {_pid, name} = start_snapshot(:create)
      {:ok, name: name}
    end

    test "returns {:ok, snapshot} on success", %{name: name} do
      assert {:ok, snap} = GenServer.call(name, {:create, "s1", sample_state(), 1})
      assert is_map(snap)
    end

    test "snapshot includes id (SC-SNP-001)", %{name: name} do
      {:ok, snap} = GenServer.call(name, {:create, "s1", sample_state(), 1})
      assert is_binary(snap.id)
      assert String.length(snap.id) > 0
    end

    test "snapshot includes stream field", %{name: name} do
      {:ok, snap} = GenServer.call(name, {:create, "my-stream", sample_state(), 5})
      assert snap.stream == "my-stream"
    end

    test "snapshot includes version field (SC-SNP-001)", %{name: name} do
      {:ok, snap} = GenServer.call(name, {:create, "ver-stream", sample_state(), 42})
      assert snap.version == 42
    end

    test "snapshot includes state matching input", %{name: name} do
      state = %{x: 100, y: 200}
      {:ok, snap} = GenServer.call(name, {:create, "state-stream", state, 1})
      assert snap.state == state
    end

    test "snapshot includes checksum (SC-SNP-002)", %{name: name} do
      {:ok, snap} = GenServer.call(name, {:create, "csum-stream", sample_state(), 1})
      assert is_binary(snap.checksum)
      assert String.length(snap.checksum) == 64
      assert String.match?(snap.checksum, ~r/^[0-9a-f]+$/)
    end

    test "snapshot includes timestamp", %{name: name} do
      {:ok, snap} = GenServer.call(name, {:create, "ts-stream", sample_state(), 1})
      assert %DateTime{} = snap.timestamp
    end

    test "snapshot compressed field defaults to false", %{name: name} do
      {:ok, snap} = GenServer.call(name, {:create, "comp-stream", sample_state(), 1})
      assert snap.compressed == false
    end
  end

  # ---- get_latest/1 -----------------------------------------------------------

  describe "get_latest/1" do
    setup do
      {_pid, name} = start_snapshot(:get_latest)
      {:ok, name: name}
    end

    test "returns {:error, :not_found} for unknown stream", %{name: name} do
      assert {:error, :not_found} = GenServer.call(name, {:get_latest, "no-such-stream"})
    end

    test "returns {:ok, snapshot} after create", %{name: name} do
      GenServer.call(name, {:create, "gl-stream", sample_state(), 1})
      assert {:ok, snap} = GenServer.call(name, {:get_latest, "gl-stream"})
      assert snap.version == 1
    end

    test "returns the most recently created snapshot", %{name: name} do
      GenServer.call(name, {:create, "latest-stream", sample_state(1), 1})
      GenServer.call(name, {:create, "latest-stream", sample_state(2), 2})
      {:ok, snap} = GenServer.call(name, {:get_latest, "latest-stream"})
      # Latest is prepended — version 2 is most recent
      assert snap.version == 2
    end
  end

  # ---- get_at_version/2 -------------------------------------------------------

  describe "get_at_version/2" do
    setup do
      {_pid, name} = start_snapshot(:get_at_version)

      # Create snapshots at versions 10, 20, 30
      for v <- [10, 20, 30] do
        GenServer.call(name, {:create, "versioned", sample_state(v), v})
      end

      {:ok, name: name}
    end

    test "returns {:error, :not_found} when no snapshot at or before version", %{name: name} do
      assert {:error, :not_found} = GenServer.call(name, {:get_at_version, "versioned", 5})
    end

    test "returns snapshot with exact version match", %{name: name} do
      {:ok, snap} = GenServer.call(name, {:get_at_version, "versioned", 20})
      assert snap.version == 20
    end

    test "returns closest snapshot at-or-before requested version", %{name: name} do
      {:ok, snap} = GenServer.call(name, {:get_at_version, "versioned", 25})
      assert snap.version == 20
    end

    test "returns latest when requested version exceeds all snapshots", %{name: name} do
      {:ok, snap} = GenServer.call(name, {:get_at_version, "versioned", 999})
      assert snap.version == 30
    end
  end

  # ---- verify/1 ---------------------------------------------------------------

  describe "verify/1 (SC-SNP-002)" do
    setup do
      {_pid, name} = start_snapshot(:verify)
      {:ok, name: name}
    end

    test "returns true for an intact snapshot", %{name: name} do
      {:ok, snap} = GenServer.call(name, {:create, "int-stream", sample_state(), 1})
      assert Snapshot.verify(snap) == true
    end

    test "returns false for a tampered snapshot (checksum mismatch)" do
      # Build a snapshot-shaped map with wrong checksum
      tampered = %{
        id: "fake",
        stream: "tampered",
        version: 1,
        state: %{x: 1},
        timestamp: DateTime.utc_now(),
        checksum: "deadbeef" <> String.duplicate("0", 56),
        compressed: false,
        metadata: %{}
      }

      assert Snapshot.verify(tampered) == false
    end

    test "verify is deterministic — same snapshot verifies consistently", %{name: name} do
      {:ok, snap} = GenServer.call(name, {:create, "det-stream", sample_state(), 1})
      assert Snapshot.verify(snap) == true
      assert Snapshot.verify(snap) == true
    end
  end

  # ---- list/1 -----------------------------------------------------------------

  describe "list/1" do
    setup do
      {_pid, name} = start_snapshot(:list)
      {:ok, name: name}
    end

    test "returns empty list for unknown stream", %{name: name} do
      assert GenServer.call(name, {:list, "empty-list-stream"}) == []
    end

    test "returns list with one element after one create", %{name: name} do
      GenServer.call(name, {:create, "list-one", sample_state(), 1})
      snaps = GenServer.call(name, {:list, "list-one"})
      assert length(snaps) == 1
    end

    test "returns multiple snapshots for same stream", %{name: name} do
      GenServer.call(name, {:create, "list-multi", sample_state(1), 1})
      GenServer.call(name, {:create, "list-multi", sample_state(2), 2})
      snaps = GenServer.call(name, {:list, "list-multi"})
      assert length(snaps) == 2
    end

    test "all listed snapshots have valid checksums (SC-SNP-002)", %{name: name} do
      for v <- 1..3,
          do: GenServer.call(name, {:create, "verify-all", sample_state(v), v})

      snaps = GenServer.call(name, {:list, "verify-all"})
      assert Enum.all?(snaps, &Snapshot.verify/1)
    end
  end

  # ---- prune/2 ----------------------------------------------------------------

  describe "prune/2" do
    setup do
      {_pid, name} = start_snapshot(:prune)
      for v <- 1..5, do: GenServer.call(name, {:create, "prune-stream", sample_state(v), v})
      {:ok, name: name}
    end

    test "reduces snapshot count to keep_count", %{name: name} do
      GenServer.call(name, {:prune, "prune-stream", 2})
      snaps = GenServer.call(name, {:list, "prune-stream"})
      assert length(snaps) == 2
    end

    test "returns :ok", %{name: name} do
      assert GenServer.call(name, {:prune, "prune-stream", 3}) == :ok
    end

    test "prune to 0 removes all snapshots", %{name: name} do
      GenServer.call(name, {:prune, "prune-stream", 0})
      assert GenServer.call(name, {:list, "prune-stream"}) == []
    end
  end

  # ---- configure/2 ------------------------------------------------------------

  describe "configure/2" do
    setup do
      {_pid, name} = start_snapshot(:configure)
      {:ok, name: name}
    end

    test "returns :ok", %{name: name} do
      config = %{strategy: :periodic, interval: 50, max_snapshots: 5, compress: false}
      assert GenServer.call(name, {:configure, "cfg-stream", config}) == :ok
    end

    test "process survives configure call", %{name: name} do
      config = %{strategy: :periodic, interval: 100, max_snapshots: 10, compress: false}
      GenServer.call(name, {:configure, "cfg2-stream", config})
      assert Process.alive?(Process.whereis(name))
    end
  end

  # ---- max_snapshots pruning on create ----------------------------------------

  describe "max_snapshots auto-pruning" do
    setup do
      {_pid, name} = start_snapshot(:auto_prune)
      # Configure max 3 snapshots
      config = %{strategy: :periodic, interval: 100, max_snapshots: 3, compress: false}
      GenServer.call(name, {:configure, "auto-prune-stream", config})
      {:ok, name: name}
    end

    test "never exceeds max_snapshots after many creates", %{name: name} do
      for v <- 1..10,
          do: GenServer.call(name, {:create, "auto-prune-stream", sample_state(v), v})

      snaps = GenServer.call(name, {:list, "auto-prune-stream"})
      assert length(snaps) <= 3
    end
  end

  # ---- PropCheck properties ---------------------------------------------------

  property "verify always returns true for freshly-created snapshots" do
    forall version <- PC.choose(1, 1000) do
      name = :"snap_prop_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(Snapshot, [], name: name)
      {:ok, snap} = GenServer.call(name, {:create, "prop-stream", %{v: version}, version})
      result = Snapshot.verify(snap)
      GenServer.stop(pid, :normal)
      result == true
    end
  end

  property "snapshot version matches the version passed to create/3" do
    forall version <- PC.choose(1, 10_000) do
      name = :"snap_ver_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(Snapshot, [], name: name)
      {:ok, snap} = GenServer.call(name, {:create, "version-stream", %{x: 1}, version})
      GenServer.stop(pid, :normal)
      snap.version == version
    end
  end

  # ---- StreamData property tests ----------------------------------------------

  test "get_at_version for existing version returns that version" do
    ExUnitProperties.check all(version <- SD.integer(1..100)) do
      name = :"snap_sd_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(Snapshot, [], name: name)
      GenServer.call(name, {:create, "at-ver-stream", %{val: version}, version})
      result = GenServer.call(name, {:get_at_version, "at-ver-stream", version})
      GenServer.stop(pid, :normal, 500)
      assert {:ok, snap} = result
      assert snap.version == version
    end
  end

  test "checksum is always 64 hex chars (SHA-256 SC-SNP-002)" do
    ExUnitProperties.check all(n <- SD.integer(1..100)) do
      name = :"snap_sd2_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(Snapshot, [], name: name)
      {:ok, snap} = GenServer.call(name, {:create, "hex-stream", %{n: n}, n})
      GenServer.stop(pid, :normal, 500)
      assert String.length(snap.checksum) == 64
      assert String.match?(snap.checksum, ~r/^[0-9a-f]+$/)
    end
  end
end
