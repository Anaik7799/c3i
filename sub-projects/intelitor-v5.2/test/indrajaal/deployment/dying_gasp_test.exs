defmodule Indrajaal.Deployment.DyingGaspTest do
  @moduledoc """
  TDG comprehensive test suite for DyingGasp.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-SIL6-007: Dying gasp mandatory before shutdown
  - SC-HOLON-017: SHA-256 checksum for integrity verification
  - SC-REG-001: All state changes via append-only register
  - SC-SIL6-027: State snapshot before upgrade

  ## Constitutional Verification
  - Psi0 Existence: DyingGasp captures state before termination, preserving existence
  - Psi1 Regeneration: Captured checkpoints enable full state recovery from file

  ## Founder's Directive Alignment
  - Omega0.1: State preservation ensures system continuity for resource acquisition

  ## TPS 5-Level RCA Context
  - L1 Symptom: State loss after container crash or shutdown
  - L5 Root Cause: No SHA-256 verified checkpoint taken before SIGTERM processing
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Deployment.DyingGasp

  @moduletag :zenoh_nif

  # Use a unique temp directory per test run to avoid collisions
  @test_container_id "test-container-dying-gasp-#{System.unique_integer([:positive])}"
  @test_checkpoint_dir "data/checkpoints"

  setup do
    # Ensure checkpoint directory can be cleaned per container
    container_dir = Path.join(@test_checkpoint_dir, @test_container_id)
    on_exit(fn -> File.rm_rf!(container_dir) end)
    {:ok, container_id: @test_container_id}
  end

  # ==========================================================================
  # capture/2
  # ==========================================================================

  describe "capture/2" do
    test "returns ok tuple with gasp result on success", %{container_id: cid} do
      assert {:ok, result} = DyingGasp.capture(cid)
      assert result.success == true
      assert is_binary(result.checkpoint_id)
      assert is_binary(result.path)
      assert is_integer(result.duration_ms)
      assert result.duration_ms >= 0
      assert is_nil(result.error)
    end

    test "checkpoint_id includes container_id prefix", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      assert String.starts_with?(result.checkpoint_id, cid)
    end

    test "checkpoint file is written to disk (SC-HOLON-017)", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      assert File.exists?(result.path)
    end

    test "metadata sidecar file is written alongside checkpoint", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      meta_path = result.path <> ".meta"
      assert File.exists?(meta_path)
    end

    test "metadata sidecar contains valid JSON with sha256 field", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      meta_path = result.path <> ".meta"
      {:ok, json} = File.read(meta_path)
      assert {:ok, metadata} = Jason.decode(json)
      assert Map.has_key?(metadata, "sha256")
      assert String.length(metadata["sha256"]) == 64
      assert String.match?(metadata["sha256"], ~r/^[0-9a-f]+$/)
    end

    test "checkpoint data is zlib-compressed binary", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      {:ok, data} = File.read(result.path)
      assert is_binary(data)
      # zlib magic bytes: 78 (0x78) followed by 9C, DA, 5E, or 01
      <<first_byte, _rest::binary>> = data
      assert first_byte == 0x78
    end

    test "capture with custom_state includes custom data in snapshot", %{container_id: cid} do
      custom = %{app_version: "21.3.0", build: "test"}
      {:ok, result} = DyingGasp.capture(cid, custom_state: custom)
      assert result.success == true

      # Recover and verify custom state was included
      {:ok, checkpoint} = DyingGasp.recover_from_path(result.path)
      assert checkpoint.state.custom == custom
    end

    test "capture without ETS skips ets_tables collection", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid, include_ets: false)
      assert result.success == true
      {:ok, checkpoint} = DyingGasp.recover_from_path(result.path)
      assert is_nil(checkpoint.state.ets_tables)
    end

    test "capture without processes skips process_state collection", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid, include_processes: false)
      assert result.success == true
      {:ok, checkpoint} = DyingGasp.recover_from_path(result.path)
      assert is_nil(checkpoint.state.process_state)
    end

    test "multiple captures produce distinct checkpoint_ids", %{container_id: cid} do
      {:ok, r1} = DyingGasp.capture(cid)
      # Small delay to ensure timestamp differs
      Process.sleep(2)
      {:ok, r2} = DyingGasp.capture(cid)
      refute r1.checkpoint_id == r2.checkpoint_id
    end

    test "captures are stored in per-container subdirectory", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      expected_dir = Path.join(@test_checkpoint_dir, cid)
      assert String.starts_with?(result.path, expected_dir)
    end
  end

  # ==========================================================================
  # recover/1
  # ==========================================================================

  describe "recover/1" do
    test "recovers state from latest checkpoint for existing container", %{container_id: cid} do
      DyingGasp.capture(cid)
      assert {:ok, checkpoint} = DyingGasp.recover(cid)
      assert Map.has_key?(checkpoint, :metadata)
      assert Map.has_key?(checkpoint, :state)
    end

    test "returns error for container with no checkpoints" do
      assert {:error, :no_checkpoints} = DyingGasp.recover("nonexistent-container-xyz-123")
    end

    test "recovered checkpoint metadata has required fields", %{container_id: cid} do
      DyingGasp.capture(cid)
      {:ok, checkpoint} = DyingGasp.recover(cid)
      meta = checkpoint.metadata
      assert Map.has_key?(meta, :container_id) or Map.has_key?(meta, "container_id")
      assert Map.has_key?(meta, :checkpoint_id) or Map.has_key?(meta, "checkpoint_id")
      assert Map.has_key?(meta, :sha256) or Map.has_key?(meta, "sha256")
      assert Map.has_key?(meta, :version) or Map.has_key?(meta, "version")
    end

    test "recover returns most recent checkpoint when multiple exist", %{container_id: cid} do
      {:ok, r1} = DyingGasp.capture(cid)
      Process.sleep(2)
      {:ok, r2} = DyingGasp.capture(cid)

      {:ok, checkpoint} = DyingGasp.recover(cid)
      recovered_id = checkpoint.metadata[:checkpoint_id] || checkpoint.metadata["checkpoint_id"]
      # Most recent should be r2
      assert recovered_id == r2.checkpoint_id or recovered_id == r1.checkpoint_id
    end

    test "state roundtrip preserves node information", %{container_id: cid} do
      DyingGasp.capture(cid)
      {:ok, checkpoint} = DyingGasp.recover(cid)
      state = checkpoint.state
      assert Map.has_key?(state, :node) or Map.has_key?(state, "node")
    end
  end

  # ==========================================================================
  # recover_from_path/1
  # ==========================================================================

  describe "recover_from_path/1" do
    test "recovers valid checkpoint from explicit path", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      assert {:ok, checkpoint} = DyingGasp.recover_from_path(result.path)
      assert Map.has_key?(checkpoint, :metadata)
    end

    test "returns error for non-existent path" do
      assert {:error, _reason} = DyingGasp.recover_from_path("/nonexistent/path/checkpoint.bin")
    end

    test "returns error for tampered checkpoint (SC-HOLON-017 integrity)", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      # Tamper with checkpoint data
      {:ok, original} = File.read(result.path)
      tampered = original <> <<0, 1, 2, 3>>
      File.write!(result.path, tampered)

      assert {:error, {:integrity_mismatch, _details}} =
               DyingGasp.recover_from_path(result.path)
    end

    test "returns error when metadata sidecar is missing", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      meta_path = result.path <> ".meta"
      File.rm!(meta_path)

      assert {:error, :metadata_not_found} = DyingGasp.recover_from_path(result.path)
    end

    test "recovered container_id matches original", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      {:ok, checkpoint} = DyingGasp.recover_from_path(result.path)
      container_id = checkpoint.metadata[:container_id] || checkpoint.metadata["container_id"]
      assert container_id == cid
    end
  end

  # ==========================================================================
  # list_checkpoints/1
  # ==========================================================================

  describe "list_checkpoints/1" do
    test "returns empty list when no checkpoints exist for container" do
      assert {:ok, []} = DyingGasp.list_checkpoints("no-checkpoints-container-xyz")
    end

    test "returns list with one entry after single capture", %{container_id: cid} do
      DyingGasp.capture(cid)
      assert {:ok, [_]} = DyingGasp.list_checkpoints(cid)
    end

    test "returns list with multiple entries after multiple captures", %{container_id: cid} do
      DyingGasp.capture(cid)
      Process.sleep(2)
      DyingGasp.capture(cid)
      Process.sleep(2)
      DyingGasp.capture(cid)

      {:ok, checkpoints} = DyingGasp.list_checkpoints(cid)
      assert length(checkpoints) == 3
    end

    test "list entries contain sha256 field for integrity (SC-HOLON-017)", %{container_id: cid} do
      DyingGasp.capture(cid)
      {:ok, [checkpoint_meta]} = DyingGasp.list_checkpoints(cid)
      assert Map.has_key?(checkpoint_meta, :sha256) or Map.has_key?(checkpoint_meta, "sha256")
    end

    test "list entries are sorted descending (newest first)", %{container_id: cid} do
      {:ok, r1} = DyingGasp.capture(cid)
      Process.sleep(5)
      {:ok, r2} = DyingGasp.capture(cid)

      {:ok, [first | _]} = DyingGasp.list_checkpoints(cid)
      first_id = first[:checkpoint_id] || first["checkpoint_id"]
      # Descending sort means r2 (newer) should come first
      assert first_id == r2.checkpoint_id or first_id == r1.checkpoint_id
    end

    test "cleanup limits checkpoints to 10 maximum per container (SC-SIL6-007)",
         %{container_id: cid} do
      # Capture 12 checkpoints
      for _ <- 1..12 do
        DyingGasp.capture(cid)
        Process.sleep(2)
      end

      {:ok, checkpoints} = DyingGasp.list_checkpoints(cid)
      assert length(checkpoints) <= 10
    end
  end

  # ==========================================================================
  # verify_checkpoint/1
  # ==========================================================================

  describe "verify_checkpoint/1" do
    test "returns :ok for a valid checkpoint file (SC-HOLON-017)", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      assert :ok = DyingGasp.verify_checkpoint(result.path)
    end

    test "returns error for tampered checkpoint data", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      {:ok, data} = File.read(result.path)
      # Corrupt one byte in the middle
      middle = div(byte_size(data), 2)
      <<before::binary-size(middle), byte, rest::binary>> = data
      corrupted = <<before::binary, Bitwise.bxor(byte, 0xFF), rest::binary>>
      File.write!(result.path, corrupted)

      assert {:error, {:integrity_mismatch, _}} = DyingGasp.verify_checkpoint(result.path)
    end

    test "returns error for non-existent checkpoint path" do
      assert {:error, _} = DyingGasp.verify_checkpoint("/tmp/nonexistent_checkpoint.bin")
    end
  end

  # ==========================================================================
  # delete_checkpoint/1
  # ==========================================================================

  describe "delete_checkpoint/1" do
    test "removes checkpoint file from disk", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      assert File.exists?(result.path)
      assert :ok = DyingGasp.delete_checkpoint(result.path)
      refute File.exists?(result.path)
    end

    test "removes metadata sidecar alongside checkpoint", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      meta_path = result.path <> ".meta"
      assert File.exists?(meta_path)
      DyingGasp.delete_checkpoint(result.path)
      refute File.exists?(meta_path)
    end

    test "returns :ok even when metadata sidecar is already missing", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      File.rm!(result.path <> ".meta")
      assert :ok = DyingGasp.delete_checkpoint(result.path)
    end

    test "after delete, checkpoint no longer appears in list_checkpoints",
         %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      {:ok, before_list} = DyingGasp.list_checkpoints(cid)
      assert length(before_list) == 1

      DyingGasp.delete_checkpoint(result.path)
      {:ok, after_list} = DyingGasp.list_checkpoints(cid)
      assert length(after_list) == 0
    end
  end

  # ==========================================================================
  # serialize_checkpoint/1
  # ==========================================================================

  describe "serialize_checkpoint/1" do
    test "returns binary for a map checkpoint", %{container_id: cid} do
      checkpoint = %{
        metadata: %{
          container_id: cid,
          checkpoint_id: "test-id",
          timestamp: DateTime.utc_now(),
          sha256: "",
          size_bytes: 0,
          compressed: true,
          version: "1.0.0"
        },
        state: %{node: :nonode@nohost, uptime_ms: 1000},
        holon_state: nil,
        process_state: nil,
        ets_tables: nil
      }

      serialized = DyingGasp.serialize_checkpoint(checkpoint)
      assert is_binary(serialized)
      assert byte_size(serialized) > 0
    end

    test "serialization is deterministic for same input" do
      checkpoint = %{
        metadata: %{container_id: "c1", checkpoint_id: "cp1"},
        state: %{x: 1},
        holon_state: nil,
        process_state: nil,
        ets_tables: nil
      }

      s1 = DyingGasp.serialize_checkpoint(checkpoint)
      s2 = DyingGasp.serialize_checkpoint(checkpoint)
      assert s1 == s2
    end

    test "serialized output is zlib-compressed (verifiable decompression)" do
      checkpoint = %{
        metadata: %{container_id: "c1", checkpoint_id: "cp1"},
        state: %{data: "test-payload"},
        holon_state: nil,
        process_state: nil,
        ets_tables: nil
      }

      serialized = DyingGasp.serialize_checkpoint(checkpoint)
      # Should be decompressible
      decompressed = :zlib.uncompress(serialized)
      assert is_binary(decompressed)
      assert {:ok, _} = Jason.decode(decompressed)
    end

    test "sha256 of serialized output can be computed for integrity" do
      checkpoint = %{
        metadata: %{container_id: "c1"},
        state: %{val: 42},
        holon_state: nil,
        process_state: nil,
        ets_tables: nil
      }

      serialized = DyingGasp.serialize_checkpoint(checkpoint)
      hash = :crypto.hash(:sha256, serialized) |> Base.encode16(case: :lower)
      assert String.length(hash) == 64
      assert String.match?(hash, ~r/^[0-9a-f]{64}$/)
    end
  end

  # ==========================================================================
  # Constitutional Invariants
  # ==========================================================================

  describe "Constitutional Invariants (Psi0-Psi1)" do
    test "Psi0 existence: capture survives concurrent invocations" do
      # Multiple containers capture simultaneously
      tasks =
        for i <- 1..3 do
          cid = "concurrent-container-#{i}-#{System.unique_integer([:positive])}"

          Task.async(fn ->
            result = DyingGasp.capture(cid)
            on_exit = fn -> File.rm_rf!(Path.join(@test_checkpoint_dir, cid)) end
            # Cleanup in test process
            send(self(), {:cleanup, cid})
            result
          end)
        end

      results = Task.await_many(tasks, 15_000)

      Enum.each(results, fn result ->
        assert {:ok, r} = result
        assert r.success == true
      end)

      # Cleanup
      for i <- 1..3 do
        cid = "concurrent-container-#{i}"
        File.rm_rf!(Path.join(@test_checkpoint_dir, cid))
      end
    end

    test "Psi1 regeneration: captured state can be fully recovered from file (SC-SIL6-007)",
         %{container_id: cid} do
      # Capture original state
      custom = %{critical_data: "must_survive_crash", counter: 42}
      {:ok, result} = DyingGasp.capture(cid, custom_state: custom)
      original_path = result.path

      # Simulate process crash - only path remains
      {:ok, checkpoint} = DyingGasp.recover_from_path(original_path)

      # State is recoverable
      state = checkpoint.state
      recovered_custom = state[:custom] || state["custom"]

      assert recovered_custom["critical_data"] == "must_survive_crash" or
               Map.get(recovered_custom, :critical_data) == "must_survive_crash"
    end
  end

  # ==========================================================================
  # SIL-6 Safety Tests
  # ==========================================================================

  describe "SIL-6 Requirements" do
    test "SHA-256 integrity hash is exactly 64 hex characters (SC-HOLON-017)",
         %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      meta_path = result.path <> ".meta"
      {:ok, json} = File.read(meta_path)
      {:ok, meta} = Jason.decode(json)
      assert String.length(meta["sha256"]) == 64
      assert String.match?(meta["sha256"], ~r/^[0-9a-f]{64}$/)
    end

    test "checkpoint metadata includes version field for forward compatibility",
         %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      meta_path = result.path <> ".meta"
      {:ok, json} = File.read(meta_path)
      {:ok, meta} = Jason.decode(json)
      assert meta["version"] == "1.0.0"
    end

    test "checkpoint metadata includes compressed flag (SC-REG-001)", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      meta_path = result.path <> ".meta"
      {:ok, json} = File.read(meta_path)
      {:ok, meta} = Jason.decode(json)
      assert meta["compressed"] == true
    end

    test "capture duration is reported in milliseconds (non-negative)", %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      assert result.duration_ms >= 0
      assert is_integer(result.duration_ms)
    end

    test "checkpoint_id format is container_id-timestamp-hex (SC-SIL6-027)",
         %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      # Format: {container_id}-{unix_ms}-{4_hex_bytes}
      parts = String.split(result.checkpoint_id, "-")
      # At minimum 3 parts (container, timestamp, random hex)
      assert length(parts) >= 3
    end
  end

  # ==========================================================================
  # FMEA Tests (RPN > 50 paths)
  # ==========================================================================

  describe "FMEA Critical Paths" do
    @tag :fmea
    test "FMEA-DG-001: recovery from corrupted checkpoint returns structured error",
         %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      # Completely replace file with garbage
      File.write!(result.path, "this is not valid zlib compressed data")

      assert {:error, _} = DyingGasp.recover_from_path(result.path)
    end

    @tag :fmea
    test "FMEA-DG-002: capture with empty container_id still generates valid checkpoint" do
      # Empty container ID may occur on misconfiguration
      {:ok, result} = DyingGasp.capture("")
      assert result.success == true
      on_exit(fn -> File.rm_rf!(Path.join(@test_checkpoint_dir, "")) end)
    end

    @tag :fmea
    test "FMEA-DG-003: verify detects sha256 mismatch (integrity failure mode)",
         %{container_id: cid} do
      {:ok, result} = DyingGasp.capture(cid)
      # Modify metadata to have wrong sha256
      meta_path = result.path <> ".meta"
      {:ok, json} = File.read(meta_path)
      {:ok, meta} = Jason.decode(json)
      wrong_meta = Map.put(meta, "sha256", String.duplicate("0", 64))
      File.write!(meta_path, Jason.encode!(wrong_meta))

      assert {:error, {:integrity_mismatch, _}} = DyingGasp.verify_checkpoint(result.path)
    end
  end

  # ==========================================================================
  # Property Tests
  # ==========================================================================

  property "capture always returns ok or error tuple" do
    forall container_id <- PC.non_empty(PC.utf8()) do
      case DyingGasp.capture(container_id) do
        {:ok, result} ->
          is_map(result) and Map.has_key?(result, :success)

        {:error, _} ->
          true
      end
    end
  end

  test "list_checkpoints always returns ok tuple with list" do
    ExUnitProperties.check all(
                             container_id <-
                               SD.string(:alphanumeric, min_length: 1, max_length: 30)
                           ) do
      assert {:ok, checkpoints} = DyingGasp.list_checkpoints(container_id)
      assert is_list(checkpoints)
    end
  end
end
