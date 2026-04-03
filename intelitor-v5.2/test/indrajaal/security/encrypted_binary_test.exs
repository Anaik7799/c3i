defmodule Indrajaal.Security.EncryptedBinaryTest do
  @moduledoc """
  TDG comprehensive test suite for EncryptedBinary Ash custom type.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation refinement
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-SEC-047: Encryption required for sensitive data fields
  - SC-DB-001: Custom Ash type wraps binary storage

  ## Constitutional Verification
  - Ψ₅ Truthfulness: Type cast must faithfully represent input

  ## Founder's Directive Alignment
  - Ω₀.4: Data integrity for sensitive holon state

  ## TPS 5-Level RCA Context
  - L1 Symptom: Sensitive binary data stored unencrypted
  - L5 Root Cause: Missing type-level encryption guard on Ash resources

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude Sonnet 4.6 | Sprint 54 W1 test generation |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Security.EncryptedBinary

  @moduletag :zenoh_nif

  describe "cast_input/2" do
    test "accepts nil value" do
      assert {:ok, nil} = EncryptedBinary.cast_input(nil, %{})
    end

    test "accepts binary value" do
      assert {:ok, "hello"} = EncryptedBinary.cast_input("hello", %{})
    end

    test "accepts empty binary" do
      assert {:ok, ""} = EncryptedBinary.cast_input("", %{})
    end

    test "accepts binary with arbitrary bytes" do
      binary = :crypto.strong_rand_bytes(32)
      assert {:ok, ^binary} = EncryptedBinary.cast_input(binary, %{})
    end

    test "rejects integer" do
      assert :error = EncryptedBinary.cast_input(42, %{})
    end

    test "rejects atom" do
      assert :error = EncryptedBinary.cast_input(:some_atom, %{})
    end

    test "rejects list" do
      assert :error = EncryptedBinary.cast_input([1, 2, 3], %{})
    end

    test "rejects map" do
      assert :error = EncryptedBinary.cast_input(%{key: "val"}, %{})
    end

    test "rejects float" do
      assert :error = EncryptedBinary.cast_input(3.14, %{})
    end
  end

  describe "cast_stored/2" do
    test "accepts nil from storage" do
      assert {:ok, nil} = EncryptedBinary.cast_stored(nil, %{})
    end

    test "accepts binary from storage" do
      assert {:ok, "stored_value"} = EncryptedBinary.cast_stored("stored_value", %{})
    end

    test "accepts raw bytes from storage" do
      bytes = :crypto.strong_rand_bytes(64)
      assert {:ok, ^bytes} = EncryptedBinary.cast_stored(bytes, %{})
    end

    test "rejects non-binary from storage" do
      assert :error = EncryptedBinary.cast_stored(12_345, %{})
    end

    test "rejects tuple from storage" do
      assert :error = EncryptedBinary.cast_stored({:ok, "val"}, %{})
    end
  end

  describe "dump_to_native/2" do
    test "passes nil through" do
      assert {:ok, nil} = EncryptedBinary.dump_to_native(nil, %{})
    end

    test "passes binary through" do
      assert {:ok, "raw"} = EncryptedBinary.dump_to_native("raw", %{})
    end

    test "passes empty binary through" do
      assert {:ok, ""} = EncryptedBinary.dump_to_native("", %{})
    end

    test "rejects non-binary" do
      assert :error = EncryptedBinary.dump_to_native(999, %{})
    end

    test "rejects boolean" do
      assert :error = EncryptedBinary.dump_to_native(true, %{})
    end
  end

  describe "storage_type/1" do
    test "declares storage as :binary" do
      assert :binary = EncryptedBinary.storage_type(%{})
    end

    test "storage type is independent of constraints" do
      assert :binary = EncryptedBinary.storage_type(nil)
    end
  end

  # ============================================================
  # Property Tests (PropCheck)
  # ============================================================

  property "cast_input accepts all binary values" do
    forall bin <- PC.binary() do
      match?({:ok, _}, EncryptedBinary.cast_input(bin, %{}))
    end
  end

  property "cast_input rejects all non-binary non-nil values" do
    forall val <- PC.integer() do
      EncryptedBinary.cast_input(val, %{}) == :error
    end
  end

  property "cast_stored round-trips binary values" do
    forall bin <- PC.binary() do
      {:ok, result} = EncryptedBinary.cast_stored(bin, %{})
      result == bin
    end
  end

  property "dump_to_native is identity for binaries" do
    forall bin <- PC.binary() do
      {:ok, result} = EncryptedBinary.dump_to_native(bin, %{})
      result == bin
    end
  end

  # ============================================================
  # ExUnitProperties (StreamData)
  # ============================================================

  test "cast_input/cast_stored roundtrip preserves bytes" do
    ExUnitProperties.check all(bin <- SD.binary()) do
      {:ok, stored} = EncryptedBinary.cast_input(bin, %{})
      {:ok, restored} = EncryptedBinary.cast_stored(stored, %{})
      assert restored == bin
    end
  end

  test "nil is always accepted by all three functions" do
    ExUnitProperties.check all(_x <- SD.constant(:unit)) do
      assert {:ok, nil} = EncryptedBinary.cast_input(nil, %{})
      assert {:ok, nil} = EncryptedBinary.cast_stored(nil, %{})
      assert {:ok, nil} = EncryptedBinary.dump_to_native(nil, %{})
    end
  end

  # ============================================================
  # FMEA: edge and boundary cases
  # ============================================================

  describe "FMEA: extreme binary values" do
    test "handles zero-length binary" do
      assert {:ok, ""} = EncryptedBinary.cast_input("", %{})
      assert {:ok, ""} = EncryptedBinary.cast_stored("", %{})
      assert {:ok, ""} = EncryptedBinary.dump_to_native("", %{})
    end

    test "handles large binary (1 MB)" do
      large = :binary.copy(<<0>>, 1_048_576)
      assert {:ok, ^large} = EncryptedBinary.cast_input(large, %{})
    end

    test "handles binary with null bytes" do
      with_nulls = <<0, 0, 0, 0>>
      assert {:ok, ^with_nulls} = EncryptedBinary.cast_input(with_nulls, %{})
    end

    test "handles binary with high bytes" do
      high_bytes = <<255, 254, 253, 252>>
      assert {:ok, ^high_bytes} = EncryptedBinary.cast_input(high_bytes, %{})
    end
  end
end
