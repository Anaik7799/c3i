defmodule Indrajaal.SMRITI.Federation.ProvenanceTest do
  @moduledoc """
  TDG test suite for SMRITI.Federation.Provenance.

  ## STAMP Safety Integration
  - SC-AI-001: AI agents persist context via SMRITI
  - SC-SEC-047: Cryptographic signing required

  ## TPS 5-Level RCA Context
  - L1 Symptom: Tampered holons accepted into mesh
  - L5 Root Cause: Missing signature verification
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.SMRITI.Federation.Provenance

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(Provenance)
    end

    test "sign/1 is exported" do
      assert function_exported?(Provenance, :sign, 1)
    end

    test "verify/2 is exported" do
      assert function_exported?(Provenance, :verify, 2)
    end

    test "trusted_source?/1 is exported" do
      assert function_exported?(Provenance, :trusted_source?, 1)
    end
  end

  describe "sign/1" do
    test "returns a hex string for binary payload" do
      signature = Provenance.sign("test payload")
      assert is_binary(signature)
      assert String.match?(signature, ~r/^[0-9a-f]+$/)
    end

    test "same payload produces same signature (deterministic)" do
      payload = "consistent payload"
      sig1 = Provenance.sign(payload)
      sig2 = Provenance.sign(payload)
      assert sig1 == sig2
    end

    test "different payloads produce different signatures" do
      sig1 = Provenance.sign("payload_a")
      sig2 = Provenance.sign("payload_b")
      refute sig1 == sig2
    end

    test "signature is 64 hex chars (SHA-256 HMAC)" do
      sig = Provenance.sign("test")
      assert String.length(sig) == 64
    end
  end

  describe "verify/2" do
    test "valid signature returns ok" do
      payload = "authentic holon data"
      signature = Provenance.sign(payload)
      assert {:ok, :valid} = Provenance.verify(payload, signature)
    end

    test "tampered payload returns error with invalid_signature" do
      payload = "original payload"
      signature = Provenance.sign(payload)
      assert {:error, :invalid_signature} = Provenance.verify("tampered payload", signature)
    end

    test "wrong signature returns error" do
      payload = "test payload"
      assert {:error, :invalid_signature} = Provenance.verify(payload, "deadbeef")
    end

    test "empty signature returns error" do
      result =
        try do
          Provenance.verify("payload", "")
        rescue
          _ -> {:error, :invalid_signature}
        end

      assert match?({:error, _}, result)
    end
  end

  describe "trusted_source?/1" do
    test "non-unknown sources are trusted" do
      assert Provenance.trusted_source?("node_42") == true
      assert Provenance.trusted_source?("federation_peer_1") == true
    end

    test "unknown source is not trusted" do
      assert Provenance.trusted_source?("unknown") == false
    end

    test "returns boolean" do
      result = Provenance.trusted_source?("any_source")
      assert is_boolean(result)
    end
  end
end
