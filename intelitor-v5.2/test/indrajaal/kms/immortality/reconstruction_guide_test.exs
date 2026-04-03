defmodule Indrajaal.KMS.Immortality.ReconstructionGuideTest do
  @moduledoc """
  Tests for Indrajaal.KMS.Immortality.ReconstructionGuide.

  Public API: generate/1 — returns String.t() directly (not {:ok, _}).

  STAMP Constraints:
  - SC-SMRITI-071: Self-documenting reconstruction guide
  - SC-HOLON-016: Format stability for future reconstruction
  - SC-HOLON-010: Regenerable from exported state alone
  """
  use ExUnit.Case, async: true

  alias Indrajaal.KMS.Immortality.ReconstructionGuide

  # Use a temp dir path that does not exist so generate/1 hits the
  # graceful "no_database" / "no_file" fallback paths without touching
  # real state.
  @nonexistent_db "/tmp/indrajaal_test_nonexistent_#{:os.getpid()}.db"

  describe "generate/1 — return type" do
    test "returns a binary string" do
      result = ReconstructionGuide.generate(db_path: @nonexistent_db)
      assert is_binary(result)
    end

    test "returns a non-empty string" do
      result = ReconstructionGuide.generate(db_path: @nonexistent_db)
      assert byte_size(result) > 0
    end
  end

  describe "generate/1 — required content (SC-SMRITI-071)" do
    setup do
      guide = ReconstructionGuide.generate(db_path: @nonexistent_db)
      {:ok, guide: guide}
    end

    test "contains SMRITI title", %{guide: guide} do
      assert String.contains?(guide, "SMRITI")
    end

    test "contains schema version", %{guide: guide} do
      assert String.contains?(guide, "Schema Version")
    end

    test "contains a Generated timestamp line", %{guide: guide} do
      assert String.contains?(guide, "Generated")
    end

    test "contains prerequisites section", %{guide: guide} do
      assert String.contains?(guide, "Prerequisites")
    end

    test "contains database statistics section (SC-SMRITI-071)", %{guide: guide} do
      assert String.contains?(guide, "Database Statistics")
    end

    test "contains database schema section (SC-SMRITI-072)", %{guide: guide} do
      assert String.contains?(guide, "Database Schema")
    end

    test "contains reconstruction procedure section (SC-HOLON-010)", %{guide: guide} do
      assert String.contains?(guide, "Reconstruction Procedure")
    end

    test "contains verification checksums section (SC-HOLON-016)", %{guide: guide} do
      assert String.contains?(guide, "Verification Checksums")
    end

    test "contains format reference section", %{guide: guide} do
      assert String.contains?(guide, "Format Reference")
    end

    test "contains SQL CREATE TABLE for holons (SC-SMRITI-072)", %{guide: guide} do
      assert String.contains?(guide, "CREATE TABLE holons")
    end

    test "contains SQL CREATE TABLE for evolution_events", %{guide: guide} do
      assert String.contains?(guide, "CREATE TABLE evolution_events")
    end
  end

  describe "generate/1 — fallback behaviour with missing db" do
    test "holon count is 0 when db does not exist" do
      guide = ReconstructionGuide.generate(db_path: @nonexistent_db)
      assert String.contains?(guide, "Holons**: 0")
    end

    test "integrity status is 'no_database' when db does not exist" do
      guide = ReconstructionGuide.generate(db_path: @nonexistent_db)
      assert String.contains?(guide, "no_database")
    end

    test "db_checksum is 'no_file' when db does not exist" do
      guide = ReconstructionGuide.generate(db_path: @nonexistent_db)
      assert String.contains?(guide, "no_file")
    end

    test "default schema sql is embedded as fallback" do
      guide = ReconstructionGuide.generate(db_path: @nonexistent_db)
      assert String.contains?(guide, "holons_fts")
    end
  end

  describe "generate/0 — default opts" do
    test "calling with no args does not raise" do
      # Uses Application.get_env path; might fail to open db but must not raise
      result = ReconstructionGuide.generate()
      assert is_binary(result)
    end

    test "result is the same type as with explicit opts" do
      with_opts = ReconstructionGuide.generate(db_path: @nonexistent_db)
      no_opts = ReconstructionGuide.generate()
      assert is_binary(with_opts)
      assert is_binary(no_opts)
    end
  end

  describe "generate/1 — idempotent structure" do
    test "calling generate twice yields strings with same section headers" do
      sections = [
        "Prerequisites",
        "Database Statistics",
        "Database Schema",
        "Reconstruction Procedure",
        "Verification Checksums",
        "Format Reference"
      ]

      guide1 = ReconstructionGuide.generate(db_path: @nonexistent_db)
      guide2 = ReconstructionGuide.generate(db_path: @nonexistent_db)

      for section <- sections do
        assert String.contains?(guide1, section), "Missing section in guide1: #{section}"
        assert String.contains?(guide2, section), "Missing section in guide2: #{section}"
      end
    end
  end
end
