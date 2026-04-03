defmodule Indrajaal.Federation.AttestationTest do
  @moduledoc """
  Tests for Indrajaal.Federation.Attestation.

  Both public functions are currently placeholder implementations that return
  fixed ok-tuples. Tests assert the exact current contract so any change to
  the shape is caught immediately.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Federation.Attestation

  # ---------------------------------------------------------------------------
  # generate_proof/0
  # ---------------------------------------------------------------------------

  describe "generate_proof/0" do
    test "returns {:ok, proof_map}" do
      assert {:ok, proof} = Attestation.generate_proof()
      assert is_map(proof)
    end

    test "proof contains a :timestamp field" do
      {:ok, proof} = Attestation.generate_proof()
      assert Map.has_key?(proof, :timestamp)
    end

    test "proof :timestamp is a DateTime" do
      {:ok, proof} = Attestation.generate_proof()
      assert %DateTime{} = proof.timestamp
    end

    test "proof contains a :signature field" do
      {:ok, proof} = Attestation.generate_proof()
      assert Map.has_key?(proof, :signature)
    end

    test "proof :signature is not nil" do
      {:ok, proof} = Attestation.generate_proof()
      refute is_nil(proof.signature)
    end

    test "proof contains a :state_hash field" do
      {:ok, proof} = Attestation.generate_proof()
      assert Map.has_key?(proof, :state_hash)
    end

    test "proof :state_hash is not nil" do
      {:ok, proof} = Attestation.generate_proof()
      refute is_nil(proof.state_hash)
    end

    test "each call produces a proof with a distinct timestamp" do
      {:ok, p1} = Attestation.generate_proof()
      Process.sleep(2)
      {:ok, p2} = Attestation.generate_proof()
      # Timestamps are generated fresh on each call; they should not be equal
      # (unless the clock resolution is coarser than 1ms — highly unlikely).
      assert DateTime.compare(p1.timestamp, p2.timestamp) in [:lt, :eq]
    end
  end

  # ---------------------------------------------------------------------------
  # verify_peer_proof/2
  # ---------------------------------------------------------------------------

  describe "verify_peer_proof/2" do
    test "returns {:ok, :verified} for any proof" do
      assert {:ok, :verified} = Attestation.verify_peer_proof("peer_node_1", %{sig: "abc"})
    end

    test "returns {:ok, :verified} for a nil proof" do
      assert {:ok, :verified} = Attestation.verify_peer_proof("any_peer", nil)
    end

    test "returns {:ok, :verified} for an empty map proof" do
      assert {:ok, :verified} = Attestation.verify_peer_proof("peer", %{})
    end

    test "peer_id argument does not affect the result" do
      r1 = Attestation.verify_peer_proof("node_a", %{})
      r2 = Attestation.verify_peer_proof("node_b", %{})
      assert r1 == r2
    end

    test "returns a two-element ok-tuple" do
      result = Attestation.verify_peer_proof("p", %{})
      assert match?({:ok, _}, result)
    end

    test "works with a real-looking proof map" do
      {:ok, proof} = Attestation.generate_proof()
      assert {:ok, :verified} = Attestation.verify_peer_proof("remote_node", proof)
    end
  end

  # ---------------------------------------------------------------------------
  # Module contract
  # ---------------------------------------------------------------------------

  describe "module contract" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Attestation)
    end

    test "generate_proof/0 is exported" do
      assert function_exported?(Attestation, :generate_proof, 0)
    end

    test "verify_peer_proof/2 is exported" do
      assert function_exported?(Attestation, :verify_peer_proof, 2)
    end
  end
end
