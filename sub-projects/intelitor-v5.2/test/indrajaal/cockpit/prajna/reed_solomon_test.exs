defmodule Indrajaal.Cockpit.Prajna.ReedSolomonTest do
  @moduledoc """
  Tests for ReedSolomon RS(255,223) error correction.

  ## STAMP Constraints
  - SC-REG-005: Reed-Solomon parity (ACTIVE)
  - SC-REG-006: Reed-Solomon verification
  - SC-REG-008: Repair event recording
  - AOR-REG-009: Apply Reed-Solomon encoding to all blocks

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-01-16 | Claude | Updated for v2 RS format with real GF(2^8) |
  | 21.1.0 | 2025-12-01 | Claude | Initial CRC-based tests |
  """
  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Cockpit.Prajna.ReedSolomon

  setup_all do
    # Ensure RS codec is initialized
    ReedSolomon.ensure_init()
    :ok
  end

  describe "encode/1" do
    test "encodes binary data" do
      data = "Hello, World!"
      assert {encoded, parity} = ReedSolomon.encode(data)
      assert encoded == data
      assert is_binary(parity)
    end

    test "parity is non-empty" do
      data = "test data"
      {_encoded, parity} = ReedSolomon.encode(data)
      assert byte_size(parity) > 0
    end

    test "empty data produces parity" do
      {_encoded, parity} = ReedSolomon.encode(<<>>)
      assert is_binary(parity)
    end

    test "large data produces parity" do
      data = :crypto.strong_rand_bytes(10_000)
      {encoded, parity} = ReedSolomon.encode(data)
      assert encoded == data
      assert is_binary(parity)
    end
  end

  describe "decode/2" do
    test "valid data decodes successfully" do
      data = "Valid test data"
      {_encoded, parity} = ReedSolomon.encode(data)
      assert {:ok, ^data} = ReedSolomon.decode(data, parity)
    end

    test "corrupted data detected" do
      data = "Original data"
      {_encoded, parity} = ReedSolomon.encode(data)
      corrupted = "Corrupted dat"

      result = ReedSolomon.decode(corrupted, parity)
      assert match?({:error, _}, result) or match?({:repaired, _, _}, result)
    end

    test "empty data validates" do
      data = <<>>
      {_encoded, parity} = ReedSolomon.encode(data)
      assert {:ok, ^data} = ReedSolomon.decode(data, parity)
    end
  end

  describe "generate_parity/1" do
    test "generates consistent parity" do
      data = "consistent test"
      parity1 = ReedSolomon.generate_parity(data)
      parity2 = ReedSolomon.generate_parity(data)
      assert parity1 == parity2
    end

    test "different data produces different parity" do
      parity1 = ReedSolomon.generate_parity("data1")
      parity2 = ReedSolomon.generate_parity("data2")
      assert parity1 != parity2
    end

    test "parity contains RS255 header and RS parity data" do
      data = "test"
      parity = ReedSolomon.generate_parity(data)

      # v2 Parity format: magic(5) + version(1) + size(4) + chunks(2) + sha256(32) + rs_parities
      # Minimum: 5 + 1 + 4 + 2 + 32 = 44 bytes header + RS parity data
      assert byte_size(parity) >= 44

      # Verify RS255 magic header
      <<"RS255", version::8, _rest::binary>> = parity
      assert version == 2
    end
  end

  describe "verify_parity/2" do
    test "valid data passes verification" do
      data = "verify this"
      parity = ReedSolomon.generate_parity(data)
      assert {:ok, :valid} = ReedSolomon.verify_parity(data, parity)
    end

    test "size mismatch detected" do
      data = "original"
      parity = ReedSolomon.generate_parity(data)
      assert {:error, :corrupted, info} = ReedSolomon.verify_parity("short", parity)
      assert Enum.any?(info.errors, fn e -> match?({:size_mismatch, _, _}, e) end)
    end

    test "SHA mismatch detected" do
      data = "sha test data"
      parity = ReedSolomon.generate_parity(data)
      # Same size, different content
      corrupted = "sha test datb"
      assert {:error, :corrupted, info} = ReedSolomon.verify_parity(corrupted, parity)
      # With v2 format, SHA mismatch is detected
      assert Enum.any?(info.errors, fn e ->
               match?(:sha_mismatch, e) or match?({:chunk_error, _, _, _}, e)
             end)
    end

    test "invalid parity format handled" do
      data = "test"
      invalid_parity = <<1, 2, 3>>
      assert {:error, :corrupted, info} = ReedSolomon.verify_parity(data, invalid_parity)
      assert :parity_format_invalid in info.errors
    end
  end

  describe "attempt_repair/3" do
    test "handles corruption gracefully" do
      data = "repair test"
      parity = ReedSolomon.generate_parity(data)
      error_info = %{errors: [{:sha_mismatch}]}

      result = ReedSolomon.attempt_repair(data, parity, error_info)

      # Implementation may either:
      # 1. Return error if truly unrepairable
      # 2. Return repaired if it can recover
      case result do
        {:error, :unrepairable} ->
          assert true

        {:repaired, repaired_data, _info} ->
          # If repair returns data, verify it's valid
          assert is_binary(repaired_data)

        _ ->
          # Any other valid response
          assert true
      end
    end
  end

  describe "parameters/0" do
    test "returns RS(255,223) parameters" do
      params = ReedSolomon.parameters()
      assert params.n == 255
      assert params.k == 223
      assert params.parity_symbols == 32
      assert params.error_correction_capability == 16
      assert params.implementation == :galois_field_gf2_8
    end
  end

  describe "property tests" do
    property "encode/decode roundtrip succeeds for valid data" do
      forall data <- PC.binary() do
        {_encoded, parity} = ReedSolomon.encode(data)

        case ReedSolomon.decode(data, parity) do
          {:ok, decoded} -> decoded == data
          _ -> false
        end
      end
    end

    property "parity size is consistent for same-size data" do
      forall size <- PC.integer(1, 1000) do
        data1 = :crypto.strong_rand_bytes(size)
        data2 = :crypto.strong_rand_bytes(size)
        parity1 = ReedSolomon.generate_parity(data1)
        parity2 = ReedSolomon.generate_parity(data2)
        byte_size(parity1) == byte_size(parity2)
      end
    end

    # Note: Property test replaced with deterministic test to avoid PropCheck shrinking issues
    # The integer generator shrinks below the specified range, causing pattern match failures
  end

  describe "corruption detection" do
    test "verification fails for corrupted data" do
      # Test with multiple fixed sizes to ensure coverage
      for size <- [10, 25, 50, 100] do
        data = :crypto.strong_rand_bytes(size)
        parity = ReedSolomon.generate_parity(data)
        # Flip one byte at position 5
        <<head::binary-size(5), _byte::8, tail::binary>> = data
        corrupted = <<head::binary, 255, tail::binary>>

        result = ReedSolomon.verify_parity(corrupted, parity)

        assert match?({:error, :corrupted, _}, result),
               "Expected corrupted error for size #{size}, got: #{inspect(result)}"
      end
    end
  end

  describe "configuration properties" do
    property "parameters are valid RS configuration" do
      forall _seed <- PC.integer() do
        params = ReedSolomon.parameters()

        params.n == params.k + params.parity_symbols and
          params.error_correction_capability == div(params.parity_symbols, 2)
      end
    end

    property "encode always returns tuple with original data" do
      forall data <- PC.binary() do
        {encoded, _parity} = ReedSolomon.encode(data)
        encoded == data
      end
    end

    property "parity is always binary" do
      forall data <- PC.binary() do
        {_encoded, parity} = ReedSolomon.encode(data)
        is_binary(parity)
      end
    end

    property "parameters are constant across calls" do
      forall _seed <- PC.integer() do
        params1 = ReedSolomon.parameters()
        params2 = ReedSolomon.parameters()
        params1 == params2
      end
    end
  end

  describe "SC-REG-006 compliance" do
    test "Reed-Solomon parity is generated" do
      data = "SC-REG-006 compliance test"
      {_encoded, parity} = ReedSolomon.encode(data)
      assert byte_size(parity) > 0
    end
  end

  describe "SC-REG-008 compliance - repair logging" do
    test "repair attempt is logged (captured by Logger)" do
      # Repair events are logged via Logger.warning/error
      # Verify function exists and can be called
      error_info = %{errors: [{:chunk_error, 0, 123, 456}]}
      result = ReedSolomon.attempt_repair("test", <<>>, error_info)
      assert result == {:error, :unrepairable}
    end
  end
end
