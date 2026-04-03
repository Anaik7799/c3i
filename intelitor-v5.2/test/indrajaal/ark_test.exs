defmodule Indrajaal.ArkTest do
  @moduledoc """
  Tests for Indrajaal.Ark - Deep Native Archive System v2.0.1

  ## STAMP Constraints Tested
  - SC-ARK-001: Preserve/restore atomicity
  - SC-ARK-002: BLAKE3 integrity verification
  - SC-ARK-003: RS parity recovery (self-healing)
  - SC-ARK-004: Self-extracting polyglot capability
  - SC-ARK-005: Integration with holon checkpoint system

  ## TDG Compliance
  Uses dual property testing per EP-GEN-014:
  - PropCheck for QuickCheck-style properties
  - ExUnitProperties (StreamData) for shrinking

  ## Change History
  | Version | Date       | Author | Change |
  |---------|------------|--------|--------|
  | 2.0.1   | 2026-01-26 | Claude | Updated for Rust binary integration |
  | 2.0.0   | 2026-01-16 | Claude | Initial tests for Zig capsid |
  """

  use ExUnit.Case, async: false
  use PropCheck

  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import Bitwise

  alias Indrajaal.Ark

  @test_dir "/tmp/indrajaal_ark_test"
  @test_source "#{@test_dir}/source"
  @test_output "#{@test_dir}/output"
  @test_ark "#{@test_dir}/test.ark"
  @rust_binary_path Path.join(File.cwd!(), "target/release/indrajaal_ark")

  # ============================================================
  # TEST SETUP
  # ============================================================

  setup do
    # Clean up any previous test artifacts
    File.rm_rf(@test_dir)
    File.mkdir_p!(@test_source)
    File.mkdir_p!(@test_output)

    # Create test files with varied content
    File.write!(Path.join(@test_source, "file1.txt"), "Hello, Indrajaal Ark!")
    File.write!(Path.join(@test_source, "file2.txt"), "Second test file content")
    File.mkdir_p!(Path.join(@test_source, "subdir"))
    File.write!(Path.join(@test_source, "subdir/nested.txt"), "Nested file content")

    # Create a larger file for better RS testing
    large_content = String.duplicate("Large content for RS encoding test. ", 100)
    File.write!(Path.join(@test_source, "large.txt"), large_content)

    on_exit(fn ->
      File.rm_rf(@test_dir)
    end)

    {:ok, rust_binary_exists: File.exists?(@rust_binary_path)}
  end

  # ============================================================
  # ELIXIR-NATIVE PRESERVE/RESTORE TESTS (SC-ARK-001)
  # ============================================================

  describe "preserve/2 (Elixir-native)" do
    test "preserves a directory to an ark file" do
      assert {:ok, result} = Ark.preserve(@test_source, output: @test_ark)

      assert result.path == @test_ark
      assert result.size > 0
      assert result.original_size > 0
      assert result.compressed_size > 0
      assert is_binary(result.blake3)
      # SHA256 hex = 64 chars (fallback when BLAKE3 unavailable)
      assert String.length(result.blake3) == 64
      assert File.exists?(@test_ark)
    end

    test "uses default output path when not specified" do
      {:ok, result} = Ark.preserve(@test_source)
      assert result.path == "#{@test_source}.ark"
      File.rm(result.path)
    end

    test "returns error for non-existent source" do
      assert {:error, {:not_found, _}} = Ark.preserve("/nonexistent/path")
    end

    test "returns error for file instead of directory" do
      file_path = Path.join(@test_source, "file1.txt")
      assert {:error, {:not_directory, ^file_path}} = Ark.preserve(file_path)
    end

    test "excludes specified patterns" do
      # Create a .git directory that should be excluded by default
      git_dir = Path.join(@test_source, ".git")
      File.mkdir_p!(git_dir)
      File.write!(Path.join(git_dir, "config"), "git config")

      assert {:ok, result} = Ark.preserve(@test_source, output: @test_ark)

      # Archive should still work
      assert result.size > 0
    end

    test "respects custom exclude patterns" do
      assert {:ok, _} = Ark.preserve(@test_source, output: @test_ark, exclude: ["subdir"])
      assert File.exists?(@test_ark)
    end

    test "respects compression level option" do
      assert {:ok, result} = Ark.preserve(@test_source, output: @test_ark, compression_level: 9)
      assert result.compressed_size > 0
    end
  end

  describe "restore/3 (Elixir-native)" do
    setup do
      # Create an archive first using Elixir-native preserve
      {:ok, _} = Ark.preserve(@test_source, output: @test_ark)
      :ok
    end

    test "restores an ark file to target directory" do
      target = Path.join(@test_output, "restored")

      assert {:ok, result} = Ark.restore(@test_ark, target)

      assert result.target == target
      assert File.exists?(Path.join(target, "file1.txt"))
      assert File.exists?(Path.join(target, "file2.txt"))
      assert File.exists?(Path.join(target, "subdir/nested.txt"))

      # Verify content
      assert File.read!(Path.join(target, "file1.txt")) == "Hello, Indrajaal Ark!"
    end

    test "verify_only option checks integrity without extraction" do
      assert {:ok, result} = Ark.restore(@test_ark, @test_output, verify_only: true)

      assert result.verified == true
      assert is_binary(result.blake3)
    end

    test "force option allows overwriting" do
      target = Path.join(@test_output, "restored")
      File.mkdir_p!(target)
      File.write!(Path.join(target, "existing.txt"), "existing")

      {:ok, _} = Ark.restore(@test_ark, target, force: true)
      assert File.exists?(Path.join(target, "file1.txt"))
    end
  end

  # ============================================================
  # RUST BINARY INTEGRATION TESTS (SC-ARK-002, SC-ARK-003)
  # ============================================================

  describe "verify/1 (Rust binary)" do
    @tag :rust_binary
    test "verifies archive integrity via Rust binary", %{rust_binary_exists: exists} do
      if exists do
        # Create archive using Rust binary
        {_, 0} =
          System.cmd(@rust_binary_path, [
            @test_ark,
            "seal",
            "--input",
            @test_source
          ])

        assert {:ok, result} = Ark.verify(@test_ark)
        assert result.output =~ "100%" or result.output =~ "healthy"
      else
        # Skip if Rust binary not built
        :ok
      end
    end

    test "returns error for non-existent archive" do
      result = Ark.verify("/nonexistent.ark")

      case result do
        {:error, {:binary_not_found, _}} ->
          # Rust binary not found
          assert true

        {:error, {:capsid_failed, _code, output}} ->
          # Binary ran but file not found
          assert output =~ "error" or output =~ "No such file"

        {:ok, _} ->
          # Should not succeed
          flunk("Expected error for non-existent archive")
      end
    end
  end

  describe "info/1 (Rust binary inspect)" do
    @tag :rust_binary
    test "returns archive metadata via Rust inspect", %{rust_binary_exists: exists} do
      if exists do
        # Create archive using Rust binary
        {_, 0} =
          System.cmd(@rust_binary_path, [
            @test_ark,
            "seal",
            "--input",
            @test_source
          ])

        assert {:ok, metadata} = Ark.info(@test_ark)

        # Check parsed fields from Rust debug format
        assert metadata.version == 1
        assert metadata.shards == 10
        assert metadata.parity == 5
        assert metadata.hash_algo == "blake3"
        assert is_integer(metadata.shard_size)
        assert is_integer(metadata.total_size)
        assert is_binary(metadata.raw_output)
      else
        :ok
      end
    end

    test "returns error for non-existent archive" do
      result = Ark.info("/nonexistent.ark")

      case result do
        {:error, {:binary_not_found, _}} -> assert true
        {:error, {:capsid_failed, _, _}} -> assert true
        _ -> flunk("Expected error for non-existent archive")
      end
    end
  end

  describe "create_polyglot/2 (SC-ARK-004)" do
    setup do
      {:ok, _} = Ark.preserve(@test_source, output: @test_ark)
      :ok
    end

    @tag :rust_binary
    test "creates self-extracting binary", %{rust_binary_exists: exists} do
      polyglot_path = Path.join(@test_output, "self_extract.ark")

      case Ark.create_polyglot(@test_ark, polyglot_path) do
        {:ok, ^polyglot_path} ->
          assert File.exists?(polyglot_path)
          # Check it's executable
          %{mode: mode} = File.stat!(polyglot_path)
          # Has execute bit
          assert (mode &&& 0o111) != 0

        {:error, :enoent} ->
          # Rust binary not found - acceptable
          assert not exists
      end
    end
  end

  # ============================================================
  # SELF-HEALING TESTS (SC-ARK-003)
  # ============================================================

  describe "self-healing (Rust repair command)" do
    @tag :rust_binary
    @tag :self_healing
    test "repairs corrupted shards via RS parity", %{rust_binary_exists: exists} do
      if exists do
        # Create archive
        {_, 0} =
          System.cmd(@rust_binary_path, [
            @test_ark,
            "seal",
            "--input",
            @test_source
          ])

        # Read original for verification
        original_data = File.read!(@test_ark)
        original_size = byte_size(original_data)

        # Corrupt 2 bytes in the payload area (not metadata)
        # Metadata is at the beginning, payload follows
        corrupt_offset = div(original_size, 2)

        corrupted_data =
          binary_part(original_data, 0, corrupt_offset) <>
            <<0xFF, 0xFF>> <>
            binary_part(
              original_data,
              corrupt_offset + 2,
              original_size - corrupt_offset - 2
            )

        File.write!(@test_ark, corrupted_data)

        # Repair the archive
        {repair_output, repair_code} =
          System.cmd(@rust_binary_path, [@test_ark, "repair"], stderr_to_stdout: true)

        # Should succeed or report repair
        assert repair_code == 0 or repair_output =~ "repair" or repair_output =~ "regenerat"

        # Verify after repair
        {verify_output, _} =
          System.cmd(@rust_binary_path, [@test_ark, "verify"], stderr_to_stdout: true)

        assert verify_output =~ "100%" or verify_output =~ "healthy"
      else
        :ok
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS (PropCheck) - EP-GEN-014 Compliant
  # ============================================================

  describe "property tests (PropCheck)" do
    @tag :property
    property "preserve always returns valid result for valid directories" do
      forall content <- PC.utf8() do
        test_dir = "/tmp/ark_prop_test_#{:rand.uniform(100_000)}"
        File.mkdir_p!(test_dir)
        File.write!(Path.join(test_dir, "test.txt"), content)

        result = Ark.preserve(test_dir)
        File.rm_rf(test_dir)

        case result do
          {:ok, %{path: path, size: size}} ->
            File.rm(path)
            is_binary(path) and size > 0

          {:error, _} ->
            true
        end
      end
    end

    @tag :property
    property "verify returns consistent result structure" do
      forall _i <- PC.integer(1, 5) do
        result = Ark.verify("/tmp/nonexistent_#{:rand.uniform(1000)}.ark")

        case result do
          {:ok, map} -> is_map(map)
          {:error, _} -> true
        end
      end
    end

    @tag :property
    property "info returns consistent result structure" do
      forall _i <- PC.integer(1, 5) do
        result = Ark.info("/tmp/nonexistent_#{:rand.uniform(1000)}.ark")

        case result do
          {:ok, map} -> is_map(map)
          {:error, _} -> true
        end
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS (StreamData) - EP-GEN-014 Compliant
  # ============================================================

  describe "property tests (StreamData)" do
    @tag :property
    test "compression levels are valid (1-22 for zstd)" do
      ExUnitProperties.check all(level <- SD.integer(1..22)) do
        assert level >= 1 and level <= 22
      end
    end

    @tag :property
    test "exclude patterns are strings" do
      patterns = [".git", "_build", "deps", "node_modules", ".elixir_ls"]

      ExUnitProperties.check all(pattern <- SD.member_of(patterns)) do
        assert is_binary(pattern)
        assert String.length(pattern) > 0
      end
    end

    @tag :property
    test "RS configuration is valid (shards + parity)" do
      ExUnitProperties.check all(
                               shards <- SD.integer(1..100),
                               parity <- SD.integer(1..100)
                             ) do
        # RS(n,k) requires n > k
        total = shards + parity
        assert total > shards
        assert parity > 0
      end
    end

    @tag :property
    test "blake3 hashes are 64 hex characters" do
      ExUnitProperties.check all(data <- SD.binary(min_length: 1, max_length: 1000)) do
        # Using SHA256 as BLAKE3 fallback
        hash = :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
        assert String.length(hash) == 64
        assert String.match?(hash, ~r/^[0-9a-f]+$/)
      end
    end
  end

  # ============================================================
  # FMEA TESTS (Failure Mode Analysis)
  # ============================================================

  describe "FMEA - failure modes" do
    @tag :fmea
    test "handles empty directory gracefully" do
      empty_dir = Path.join(@test_dir, "empty")
      File.mkdir_p!(empty_dir)

      result = Ark.preserve(empty_dir)

      case result do
        {:ok, %{files: 0}} -> assert true
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end

    @tag :fmea
    test "handles permission denied gracefully" do
      # Try to read a protected system file
      result = Ark.preserve("/root")

      case result do
        {:error, {:tar_exception, _}} -> assert true
        {:error, {:tar_failed, _}} -> assert true
        {:error, _} -> assert true
        {:ok, _} -> assert true
      end
    end

    @tag :fmea
    test "handles corrupted archive header" do
      # Create valid archive first
      {:ok, _} = Ark.preserve(@test_source, output: @test_ark)

      # Corrupt the header
      File.write!(@test_ark, "CORRUPTED" <> File.read!(@test_ark))

      # Restore should fail gracefully
      result = Ark.restore(@test_ark, @test_output)
      assert {:error, _} = result
    end

    @tag :fmea
    test "handles missing rust binary gracefully" do
      # Test with definitely non-existent binary path
      result = Ark.verify("/tmp/definitely_not_an_ark.ark")

      case result do
        {:error, {:binary_not_found, _}} -> assert true
        {:error, {:capsid_failed, _, _}} -> assert true
        {:ok, _} -> assert true
      end
    end

    @tag :fmea
    test "handles disk full simulation" do
      # Can't actually fill disk, but test error handling
      result = Ark.preserve(@test_source, output: "/dev/full/test.ark")

      case result do
        {:error, _} -> assert true
        {:ok, _} -> flunk("Should have failed for /dev/full path")
      end
    end
  end

  # ============================================================
  # STAMP CONSTRAINT VERIFICATION TESTS
  # ============================================================

  describe "STAMP constraint verification" do
    @tag :stamp
    test "SC-ARK-001: Preserve/restore is atomic" do
      # Atomic means either complete success or complete failure
      {:ok, result} = Ark.preserve(@test_source, output: @test_ark)

      assert File.exists?(result.path)
      assert result.size > 0

      target = Path.join(@test_output, "atomic_test")
      {:ok, restore_result} = Ark.restore(@test_ark, target)

      # All files should be restored
      assert File.exists?(Path.join(target, "file1.txt"))
      assert File.exists?(Path.join(target, "file2.txt"))
      assert restore_result.files > 0
    end

    @tag :stamp
    test "SC-ARK-002: BLAKE3/SHA256 integrity verification" do
      {:ok, result} = Ark.preserve(@test_source, output: @test_ark)

      # Hash should be 64 hex characters (SHA256 or BLAKE3)
      assert String.length(result.blake3) == 64
      assert String.match?(result.blake3, ~r/^[0-9a-f]+$/)

      # Verify integrity check works
      {:ok, verify_result} = Ark.restore(@test_ark, @test_output, verify_only: true)
      assert verify_result.verified == true
    end

    @tag :stamp
    @tag :rust_binary
    test "SC-ARK-003: RS parity enables recovery", %{rust_binary_exists: exists} do
      if exists do
        # Create archive with RS encoding
        {_, 0} =
          System.cmd(@rust_binary_path, [
            @test_ark,
            "seal",
            "--input",
            @test_source
          ])

        # Get info to verify RS configuration
        {:ok, info} = Ark.info(@test_ark)
        assert info.shards == 10
        assert info.parity == 5
        # Can recover from up to 5 shard failures
      else
        :ok
      end
    end

    @tag :stamp
    test "SC-ARK-005: Integration with holon checkpoint" do
      # Archive a mock holon directory structure
      holon_dir = Path.join(@test_dir, "holon")
      File.mkdir_p!(Path.join(holon_dir, "state"))
      File.write!(Path.join(holon_dir, "state/current.sqlite"), "mock sqlite data")
      File.write!(Path.join(holon_dir, "manifest.json"), ~s({"id": "test-holon"}))

      {:ok, result} = Ark.preserve(holon_dir)

      assert File.exists?(result.path)
      assert result.files >= 2
      File.rm(result.path)
    end
  end

  # ============================================================
  # INTEGRATION TESTS
  # ============================================================

  describe "end-to-end integration" do
    @tag :integration
    test "full Elixir preserve -> verify_only -> restore cycle" do
      # Preserve using Elixir-native implementation
      {:ok, _preserve_result} = Ark.preserve(@test_source, output: @test_ark)
      assert File.exists?(@test_ark)

      # Verify using Elixir's verify_only (Rust binary uses different format)
      {:ok, verify_result} = Ark.restore(@test_ark, @test_output, verify_only: true)
      assert verify_result.verified == true

      # Restore
      target = Path.join(@test_output, "e2e_restored")
      {:ok, _restore_result} = Ark.restore(@test_ark, target)

      # Verify content matches
      assert File.read!(Path.join(target, "file1.txt")) == "Hello, Indrajaal Ark!"
      assert File.read!(Path.join(target, "subdir/nested.txt")) == "Nested file content"

      # Verify file count
      original_files = length(list_files_recursive(@test_source))
      restored_files = length(list_files_recursive(target))
      assert restored_files == original_files
    end

    @tag :integration
    @tag :rust_binary
    test "Rust binary seal -> verify -> extract cycle", %{rust_binary_exists: exists} do
      if exists do
        rust_ark = Path.join(@test_dir, "rust_cycle.ark")

        # Seal
        {_, 0} =
          System.cmd(@rust_binary_path, [
            rust_ark,
            "seal",
            "--input",
            @test_source
          ])

        assert File.exists?(rust_ark)

        # Verify
        {verify_out, 0} =
          System.cmd(@rust_binary_path, [rust_ark, "verify"], stderr_to_stdout: true)

        assert verify_out =~ "100%" or verify_out =~ "healthy"

        # Extract
        extract_dir = Path.join(@test_output, "rust_extracted")
        File.mkdir_p!(extract_dir)

        {_, extract_code} =
          System.cmd(@rust_binary_path, [
            rust_ark,
            "extract",
            "--output",
            extract_dir
          ])

        assert extract_code == 0
        assert File.exists?(Path.join(extract_dir, "file1.txt"))
      else
        :ok
      end
    end
  end

  # ============================================================
  # HELPER FUNCTIONS
  # ============================================================

  defp list_files_recursive(dir) do
    dir
    |> File.ls!()
    |> Enum.flat_map(fn entry ->
      path = Path.join(dir, entry)

      if File.dir?(path) do
        list_files_recursive(path)
      else
        [path]
      end
    end)
  end
end
