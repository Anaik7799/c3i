defmodule Indrajaal.KMS.FederationTest do
  @moduledoc """
  Tests for Indrajaal.KMS.Federation.

  Covers pure functions: build_merkle_root/1, merkle_root_from/1, verify_proof/3.
  Also covers GenServer lifecycle via start_supervised.

  STAMP: SC-SIL6-015 (immutable audit), SC-FRAC-004 (federation attestation)
  Mathematical: build_merkle_root/1 uses SHA-256 leaf hashing
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Federation

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Federation)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(Federation, :start_link, 1)
      assert function_exported?(Federation, :init, 1)
    end
  end

  describe "public API surface" do
    test "exports negotiate_federation/2" do
      assert function_exported?(Federation, :negotiate_federation, 2)
    end

    test "exports generate_merkle_root/0" do
      assert function_exported?(Federation, :generate_merkle_root, 0)
    end

    test "exports merkle_root_from/1" do
      assert function_exported?(Federation, :merkle_root_from, 1)
    end

    test "exports verify_proof/3" do
      assert function_exported?(Federation, :verify_proof, 3)
    end

    test "exports get_state/0" do
      assert function_exported?(Federation, :get_state, 0)
    end

    test "exports attest/2" do
      assert function_exported?(Federation, :attest, 2)
    end

    test "exports build_merkle_root/1 (doc false public)" do
      assert function_exported?(Federation, :build_merkle_root, 1)
    end
  end

  describe "build_merkle_root/1 — pure Merkle construction" do
    test "returns a binary hash for a non-empty list" do
      entries = ["leaf_a", "leaf_b", "leaf_c"]
      root = Federation.build_merkle_root(entries)
      assert is_binary(root)
      assert byte_size(root) > 0
    end

    test "same entries produce the same root (deterministic)" do
      entries = ["deterministic_leaf"]
      assert Federation.build_merkle_root(entries) == Federation.build_merkle_root(entries)
    end

    test "different entries produce different roots (collision resistance)" do
      assert Federation.build_merkle_root(["alpha"]) !=
               Federation.build_merkle_root(["beta"])
    end

    test "single entry returns its SHA-256 hash" do
      root = Federation.build_merkle_root(["solo"])
      assert is_binary(root)
      assert byte_size(root) == 32
    end

    test "empty list returns a binary (SHA-256 of empty string)" do
      result = Federation.build_merkle_root([])
      assert is_binary(result)
      assert byte_size(result) == 32
    end

    test "two entries produce a 32-byte root" do
      root = Federation.build_merkle_root(["leaf1", "leaf2"])
      assert byte_size(root) == 32
    end

    test "three entries (odd) produce a 32-byte root (last leaf duplicated)" do
      root = Federation.build_merkle_root(["a", "b", "c"])
      assert byte_size(root) == 32
    end

    test "four entries produce a 32-byte root" do
      root = Federation.build_merkle_root(["a", "b", "c", "d"])
      assert byte_size(root) == 32
    end

    test "order of leaves affects the root" do
      root_ab = Federation.build_merkle_root(["a", "b"])
      root_ba = Federation.build_merkle_root(["b", "a"])
      assert root_ab != root_ba
    end

    test "accepts map leaves (term_to_binary path)" do
      entries = [%{id: "h1", content: "text"}, %{id: "h2", content: "more"}]
      root = Federation.build_merkle_root(entries)
      assert is_binary(root)
      assert byte_size(root) == 32
    end
  end

  describe "merkle_root_from/1 — public alias of build_merkle_root" do
    test "returns a binary for non-empty list" do
      root = Federation.merkle_root_from(["leaf"])
      assert is_binary(root)
    end

    test "returns same result as build_merkle_root for same input" do
      leaves = ["x", "y", "z"]

      assert Federation.merkle_root_from(leaves) ==
               Federation.build_merkle_root(leaves)
    end

    test "returns 32-byte binary for empty list" do
      root = Federation.merkle_root_from([])
      assert byte_size(root) == 32
    end

    test "is deterministic across calls" do
      leaves = ["stable"]
      assert Federation.merkle_root_from(leaves) == Federation.merkle_root_from(leaves)
    end
  end

  describe "verify_proof/3 — Merkle proof verification" do
    test "returns true for an empty proof with correct root (single leaf)" do
      leaf = "solo"
      root = Federation.build_merkle_root([leaf])
      # With a single leaf the root IS hash_leaf(leaf), proof is []
      assert Federation.verify_proof(leaf, [], root) == true
    end

    test "returns false for empty proof with wrong root" do
      leaf = "solo"
      wrong_root = :crypto.hash(:sha256, "something_else")
      assert Federation.verify_proof(leaf, [], wrong_root) == false
    end

    test "returns false when proof list is empty but root does not match" do
      leaf = "leaf_x"
      bad_root = <<0::256>>
      assert Federation.verify_proof(leaf, [], bad_root) == false
    end

    test "verify_proof/3 returns a boolean" do
      leaf = "test"
      root = Federation.build_merkle_root([leaf])
      result = Federation.verify_proof(leaf, [], root)
      assert is_boolean(result)
    end
  end

  describe "start_link/1 GenServer contract" do
    test "starts GenServer with empty opts" do
      {:ok, pid} = start_supervised({Federation, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "initial state is a map with expected keys" do
      {:ok, pid} = start_supervised({Federation, []})
      state = :sys.get_state(pid)
      assert is_map(state)
      assert Map.has_key?(state, :peers)
      assert Map.has_key?(state, :attestations)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = Federation.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
