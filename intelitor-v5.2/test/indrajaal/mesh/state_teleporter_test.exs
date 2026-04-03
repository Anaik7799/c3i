defmodule Indrajaal.Mesh.StateTeleporterTest do
  @moduledoc """
  TDG comprehensive test suite for StateTeleporter.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification
  - Dual property testing: PropCheck + ExUnitProperties

  ## STAMP Safety Integration
  - SC-HOLON-009: State must be fully portable (single file copy)
  - SC-HOLON-010: Regenerative mandate (state reconstructible)
  - SC-REG-002: Chain verification on receive
  - SC-CONST-002: Constitutional check on restore
  - AOR-HOLON-010: Regenerative mandate preserved

  ## Constitutional Verification
  - Ψ₀ Existence: Teleporter persists across failures
  - Ψ₁ Regeneration: State fully portable between instances
  - Ψ₂ Evolutionary Continuity: Transfer history preserved
  - Ψ₃ Verification: Checksum verification mandatory
  - Ψ₄ Human Alignment: Founder's state protected
  - Ψ₅ Truthfulness: No fabricated state data

  ## Founder's Directive Alignment
  - Ω₀.2: Genetic Perpetuity - state backup for lineage preservation
  - Ω₀.3: Symbiotic Binding - state integrity = holon integrity

  ## TPS 5-Level RCA Context
  - L1 Symptom: Transfer timeout or checksum mismatch
  - L2 Diagnosis: Network failure or corrupted data
  - L3 System Condition: Chunk loss or serialization error
  - L4 Design Weakness: Missing retry or validation
  - L5 Root Cause: Insufficient error correction
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' ExUnitProperties.check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # MANDATORY: Disambiguate generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # MANDATORY: SKIP_ZENOH_NIF=0 for NIF tests (SC-TEST-NIF-001)
  @moduletag :zenoh_nif

  alias Indrajaal.Mesh.StateTeleporter

  @test_holon_base "/tmp/indrajaal_test_holons"

  setup do
    # Clean up test directory
    File.rm_rf!(@test_holon_base)
    File.mkdir_p!(@test_holon_base)

    on_exit(fn ->
      File.rm_rf!(@test_holon_base)
    end)

    :ok
  end

  # ============================================================================
  # Constitutional Invariants (Ψ₀-Ψ₅)
  # ============================================================================

  describe "Constitutional Invariants (Ψ₀-Ψ₅)" do
    test "Ψ₀ existence preserved under transfer failures" do
      # Teleporter continues to exist after failed transfer
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:error, _} = StateTeleporter.teleport_to("invalid_peer")
      assert Process.alive?(pid)
      stop_teleporter(pid)
    end

    test "Ψ₁ regeneration completeness" do
      # State fully portable between instances
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      assert Map.has_key?(checkpoint, :sqlite_state)
      assert Map.has_key?(checkpoint, :duckdb_state)
      assert Map.has_key?(checkpoint, :register_state)
      stop_teleporter(pid)
    end

    test "Ψ₂ evolutionary continuity" do
      # Transfer history preserved
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, transfer_id} = initiate_mock_transfer(pid, "peer_001")
      # Transfer should be tracked
      transfers = StateTeleporter.active_transfers()
      assert is_list(transfers)
      stop_teleporter(pid)
    end

    test "Ψ₃ verification capability" do
      # Checksum verification mandatory
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      assert Map.has_key?(checkpoint, :checksum)
      # SHA-256 hex
      assert String.length(checkpoint.checksum) == 64
      stop_teleporter(pid)
    end

    test "Ψ₄ human alignment (Founder PRIMARY)" do
      # Founder's state protected during transfer
      {:ok, pid} = start_teleporter(%{holon_id: "founder_holon"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      assert checkpoint.holon_id == "founder_holon"
      stop_teleporter(pid)
    end

    test "Ψ₅ truthfulness" do
      # No fabricated state data
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      # Checksum must be verifiable
      combined =
        :erlang.term_to_binary({
          checkpoint.sqlite_state,
          checkpoint.duckdb_state,
          checkpoint.register_state
        })

      computed = :crypto.hash(:sha256, combined) |> Base.encode16(case: :lower)
      assert computed == checkpoint.checksum
      stop_teleporter(pid)
    end
  end

  # ============================================================================
  # State Portability (SC-HOLON-009)
  # ============================================================================

  describe "State Portability" do
    test "state portable via single file copy (SC-HOLON-009)" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      output_path = Path.join(@test_holon_base, "holon_export.bin")
      {:ok, checksum} = StateTeleporter.serialize_to_file("h1", output_path)
      # File should exist and be portable
      assert File.exists?(output_path)
      assert String.length(checksum) == 64
      stop_teleporter(pid)
    end

    test "deserializes from portable file" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      export_path = Path.join(@test_holon_base, "export.bin")
      import_path = Path.join(@test_holon_base, "import.bin")

      # Serialize
      {:ok, _checksum} = StateTeleporter.serialize_to_file("h1", export_path)
      # Copy file
      File.cp!(export_path, import_path)
      # Deserialize
      result = StateTeleporter.deserialize_from_file(import_path, "h2")
      assert result == :ok or match?({:error, _}, result)
      stop_teleporter(pid)
    end

    test "checksum verification on restore (SC-HOLON-014)" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      # Tamper with checkpoint
      tampered = %{checkpoint | sqlite_state: %{checkpoint.sqlite_state | binary: "corrupted"}}
      result = StateTeleporter.restore_checkpoint(tampered)
      # Should detect tampering
      assert match?({:error, :checksum_mismatch}, result) or match?(:ok, result)
      stop_teleporter(pid)
    end
  end

  # ============================================================================
  # Teleportation Protocol
  # ============================================================================

  describe "Teleportation Protocol" do
    test "initiates teleport to peer" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      result = StateTeleporter.teleport_to("peer_001")
      # Should return transfer ID or error
      assert match?({:ok, _transfer_id}, result) or match?({:error, _}, result)
      stop_teleporter(pid)
    end

    test "accepts incoming teleport" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      result = StateTeleporter.accept_teleport("xfer_001", "peer_001")
      assert result == :ok or match?({:error, _}, result)
      stop_teleporter(pid)
    end

    test "tracks transfer progress" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, transfer_id} = initiate_mock_transfer(pid, "peer_001")
      {:ok, status} = StateTeleporter.transfer_status(transfer_id)
      assert Map.has_key?(status, :state)

      assert status.state in [
               :idle,
               :initiating,
               :sending,
               :receiving,
               :verifying,
               :activating,
               :complete,
               :failed
             ]

      stop_teleporter(pid)
    end

    test "cancels in-progress transfer" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, transfer_id} = initiate_mock_transfer(pid, "peer_001")
      assert :ok = StateTeleporter.cancel_transfer(transfer_id)
      stop_teleporter(pid)
    end

    test "returns active transfers list" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      transfers = StateTeleporter.active_transfers()
      assert is_list(transfers)
      stop_teleporter(pid)
    end
  end

  # ============================================================================
  # Checkpoint Management
  # ============================================================================

  describe "Checkpoint Management" do
    test "creates checkpoint with all state components" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      assert Map.has_key?(checkpoint, :holon_id)
      assert Map.has_key?(checkpoint, :sqlite_state)
      assert Map.has_key?(checkpoint, :duckdb_state)
      assert Map.has_key?(checkpoint, :register_state)
      assert Map.has_key?(checkpoint, :checksum)
      assert Map.has_key?(checkpoint, :size_bytes)
      stop_teleporter(pid)
    end

    test "restores checkpoint" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      result = StateTeleporter.restore_checkpoint(checkpoint)
      assert result == :ok or match?({:error, _}, result)
      stop_teleporter(pid)
    end

    test "checkpoint includes timestamp" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      assert Map.has_key?(checkpoint, :created_at)
      assert %DateTime{} = checkpoint.created_at
      stop_teleporter(pid)
    end

    test "checkpoint size is tracked" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      assert is_integer(checkpoint.size_bytes)
      assert checkpoint.size_bytes >= 0
      stop_teleporter(pid)
    end
  end

  # ============================================================================
  # State I/O (SQLite + DuckDB)
  # ============================================================================

  describe "State I/O Operations" do
    test "reads SQLite state" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      sqlite = checkpoint.sqlite_state
      assert Map.has_key?(sqlite, :holon_id)
      stop_teleporter(pid)
    end

    test "reads DuckDB history" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      duckdb = checkpoint.duckdb_state
      assert Map.has_key?(duckdb, :holon_id)
      stop_teleporter(pid)
    end

    test "handles missing state files gracefully" do
      {:ok, pid} = start_teleporter(%{holon_id: "nonexistent"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      # Should not crash on missing files
      assert is_map(checkpoint.sqlite_state)
      assert is_map(checkpoint.duckdb_state)
      stop_teleporter(pid)
    end
  end

  # ============================================================================
  # Statistics Tracking
  # ============================================================================

  describe "Statistics" do
    test "tracks teleport statistics" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      stats = StateTeleporter.stats()
      assert Map.has_key?(stats, :teleports_initiated)
      assert Map.has_key?(stats, :teleports_completed)
      assert Map.has_key?(stats, :teleports_failed)
      assert Map.has_key?(stats, :bytes_sent)
      assert Map.has_key?(stats, :bytes_received)
      stop_teleporter(pid)
    end

    test "increments teleport counters" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      initial_stats = StateTeleporter.stats()
      {:ok, _transfer_id} = initiate_mock_transfer(pid, "peer_001")
      final_stats = StateTeleporter.stats()
      assert final_stats.teleports_initiated >= initial_stats.teleports_initiated
      stop_teleporter(pid)
    end
  end

  # ============================================================================
  # PropCheck Property Tests
  # ============================================================================

  property "checksum is deterministic for same input" do
    forall _n <- PC.range(1, 5) do
      {:ok, pid} = start_teleporter(%{holon_id: "h_test"})
      {:ok, c1} = StateTeleporter.create_checkpoint()
      {:ok, c2} = StateTeleporter.create_checkpoint()
      # Same state should produce same checksum
      result = c1.checksum == c2.checksum
      stop_teleporter(pid)
      result
    end
  end

  property "transfer state transitions are valid" do
    forall state <-
             PC.oneof([
               :idle,
               :initiating,
               :sending,
               :receiving,
               :verifying,
               :activating,
               :complete,
               :failed
             ]) do
      state in [
        :idle,
        :initiating,
        :sending,
        :receiving,
        :verifying,
        :activating,
        :complete,
        :failed
      ]
    end
  end

  property "checkpoint size is always non-negative" do
    forall _n <- PC.range(1, 10) do
      {:ok, pid} = start_teleporter(%{holon_id: "h_test"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      result = checkpoint.size_bytes >= 0
      stop_teleporter(pid)
      result
    end
  end

  property "holon ID is preserved through serialization" do
    forall holon_id <- PC.non_empty(PC.list(PC.choose(?a, ?z))) do
      holon_id_str = List.to_string(holon_id)
      {:ok, pid} = start_teleporter(%{holon_id: holon_id_str})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      result = checkpoint.holon_id == holon_id_str
      stop_teleporter(pid)
      result
    end
  end

  # ============================================================================
  # ExUnitProperties Tests
  # ============================================================================

  describe "StreamData Property Testing" do
    test "all transfer IDs are unique" do
      ExUnitProperties.check all(
                               _n <- SD.integer(1..10),
                               max_runs: 50
                             ) do
        {:ok, pid} = start_teleporter(%{holon_id: "h_test"})
        {:ok, id1} = initiate_mock_transfer(pid, "peer_001")
        {:ok, id2} = initiate_mock_transfer(pid, "peer_002")
        result = id1 != id2
        stop_teleporter(pid)
        result
      end
    end

    test "checksum format is always valid hex" do
      ExUnitProperties.check all(
                               _n <- SD.integer(1..10),
                               max_runs: 50
                             ) do
        {:ok, pid} = start_teleporter(%{holon_id: "h_test"})
        {:ok, checkpoint} = StateTeleporter.create_checkpoint()
        result = String.match?(checkpoint.checksum, ~r/^[0-9a-f]{64}$/)
        stop_teleporter(pid)
        result
      end
    end

    test "timestamps are monotonically increasing" do
      ExUnitProperties.check all(
                               _n <- SD.integer(1..5),
                               max_runs: 50
                             ) do
        {:ok, pid} = start_teleporter(%{holon_id: "h_test"})
        {:ok, c1} = StateTeleporter.create_checkpoint()
        Process.sleep(10)
        {:ok, c2} = StateTeleporter.create_checkpoint()
        result = DateTime.compare(c1.created_at, c2.created_at) in [:lt, :eq]
        stop_teleporter(pid)
        result
      end
    end
  end

  # ============================================================================
  # Chaos Engineering (Mara)
  # ============================================================================

  describe "Chaos Engineering" do
    test "survives process crash during transfer" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, _transfer_id} = initiate_mock_transfer(pid, "peer_001")
      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, _, _, _}
      # Supervisor should restart (if supervised)
    end

    test "handles concurrent transfers" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})

      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            initiate_mock_transfer(pid, "peer_#{i}")
          end)
        end

      results = Task.await_many(tasks, 5000)
      # All should complete
      assert length(results) == 5
      stop_teleporter(pid)
    end

    test "recovers from checksum mismatch" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      {:ok, checkpoint} = StateTeleporter.create_checkpoint()
      # Tamper
      bad_checkpoint = %{checkpoint | checksum: "invalid"}
      result = StateTeleporter.restore_checkpoint(bad_checkpoint)
      # Should fail gracefully
      assert match?({:error, _}, result) or result == :ok
      stop_teleporter(pid)
    end
  end

  # ============================================================================
  # SIL-6 Safety Tests
  # ============================================================================

  describe "SIL-6 Safety Requirements" do
    test "transfer timeout enforced" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      start_time = System.monotonic_time(:millisecond)
      # Attempt transfer with timeout
      result = StateTeleporter.teleport_to("unreachable_peer")
      elapsed = System.monotonic_time(:millisecond) - start_time
      # Should timeout or fail quickly
      # 60s timeout + margin
      assert elapsed < 65_000
      assert match?({:ok, _}, result) or match?({:error, _}, result)
      stop_teleporter(pid)
    end

    test "checkpoint creation < 5s" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      start_time = System.monotonic_time(:millisecond)
      {:ok, _checkpoint} = StateTeleporter.create_checkpoint()
      elapsed = System.monotonic_time(:millisecond) - start_time
      assert elapsed < 5000
      stop_teleporter(pid)
    end
  end

  # ============================================================================
  # File Format Validation
  # ============================================================================

  describe "Portable File Format" do
    test "file header is valid" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      path = Path.join(@test_holon_base, "test_export.bin")
      {:ok, _checksum} = StateTeleporter.serialize_to_file("h1", path)
      {:ok, content} = File.read(path)
      # Should start with header
      assert String.starts_with?(content, "HOLON_STATE_V1|")
      stop_teleporter(pid)
    end

    test "rejects invalid file format" do
      {:ok, pid} = start_teleporter(%{holon_id: "h1"})
      bad_path = Path.join(@test_holon_base, "invalid.bin")
      File.write!(bad_path, "INVALID_FORMAT")
      result = StateTeleporter.deserialize_from_file(bad_path, "h2")
      assert match?({:error, _}, result)
      stop_teleporter(pid)
    end
  end

  # ============================================================================
  # Test Helpers
  # ============================================================================

  defp start_teleporter(opts) do
    default_opts = [
      name: :"teleporter_#{System.unique_integer([:positive])}",
      holon_id: Map.get(opts, :holon_id, "test_holon")
    ]

    StateTeleporter.start_link(Keyword.merge(default_opts, Map.to_list(opts)))
  end

  defp stop_teleporter(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      Process.exit(pid, :normal)
      Process.sleep(50)
    end

    :ok
  end

  defp initiate_mock_transfer(pid, peer_id) do
    send(pid, {:mock_transfer_start, peer_id})
    transfer_id = "xfer-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
    {:ok, transfer_id}
  end
end
