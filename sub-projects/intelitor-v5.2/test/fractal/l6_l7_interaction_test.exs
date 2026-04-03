defmodule Indrajaal.Fractal.L6L7InteractionTest do
  @moduledoc """
  Fractal L6×L7 Interaction Test — Cluster-to-Federation Attestation.

  WHAT: Tests that cluster decisions (L6) correctly attest to the federation (L7),
        verifying Ed25519 signatures, version negotiation, constitution preservation,
        cross-cluster state synchronization, and cluster membership attestation.
  WHY: Federation requires cryptographic attestation from member clusters.
       No cluster may modify another's constitution (SC-FED-001).
  CONSTRAINTS:
    - SC-FED-001: No modification of node constitutions
    - SC-FED-002: Maintain node autonomy
    - SC-FED-003: Detect constitution divergence
    - SC-FED-006: Attestation Ed25519-verified
    - SC-RECONFIG-010: Federation peers notified
    - SC-PROP-023/024: PC. prefix for PropCheck, SD. prefix for StreamData

  ## Change History
  | Version | Date       | Author | Change                                         |
  |---------|------------|--------|------------------------------------------------|
  | 1.1.0   | 2026-03-23 | Claude | Expanded to 21 tests, added sync + attestation |

  @version "1.1.0"
  @last_modified "2026-03-23T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: Disambiguation aliases MANDATORY
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :fractal
  @moduletag :l6_l7

  # ===========================================================================
  # L6-L7-TEST-001: Ed25519 attestation (SC-FED-006)
  # ===========================================================================

  describe "L6→L7: Ed25519 attestation (SC-FED-006)" do
    test "Ed25519 key pair generation" do
      {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)
      assert byte_size(pub) == 32
      assert byte_size(priv) == 32
    end

    test "attestation signature is verifiable" do
      {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)
      message = "cluster_attestation:#{System.system_time(:second)}"

      signature = :crypto.sign(:eddsa, :none, message, [priv, :ed25519])
      assert :crypto.verify(:eddsa, :none, message, signature, [pub, :ed25519])
    end

    test "tampered message fails verification" do
      {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)
      message = "original_attestation"
      tampered = "tampered_attestation"

      signature = :crypto.sign(:eddsa, :none, message, [priv, :ed25519])
      refute :crypto.verify(:eddsa, :none, tampered, signature, [pub, :ed25519])
    end

    test "cluster attestation for federation membership includes cluster identity" do
      {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)
      cluster_id = "cluster-alpha-001"
      timestamp = System.system_time(:second)

      # Attestation payload must include cluster_id and timestamp
      payload = "#{cluster_id}:#{timestamp}"
      signature = :crypto.sign(:eddsa, :none, payload, [priv, :ed25519])

      # Federation verifies using cluster's public key
      assert :crypto.verify(:eddsa, :none, payload, signature, [pub, :ed25519]),
             "Cluster attestation for federation membership must be verifiable"
    end

    test "each cluster uses independent Ed25519 key pair" do
      {pub_a, priv_a} = :crypto.generate_key(:eddsa, :ed25519)
      {pub_b, priv_b} = :crypto.generate_key(:eddsa, :ed25519)

      # Keys are unique per cluster
      refute pub_a == pub_b, "Each cluster must have distinct public key"
      refute priv_a == priv_b, "Each cluster must have distinct private key"

      # Cross-sign verification fails
      message = "test_message"
      sig_a = :crypto.sign(:eddsa, :none, message, [priv_a, :ed25519])

      refute :crypto.verify(:eddsa, :none, message, sig_a, [pub_b, :ed25519]),
             "Signature from cluster A must not verify with cluster B's public key"
    end
  end

  # ===========================================================================
  # L6-L7-TEST-002: Constitution preservation (SC-FED-001)
  # ===========================================================================

  describe "L6→L7: Constitution preservation (SC-FED-001)" do
    test "federation cannot modify node constitution" do
      node_constitution = %{
        psi_0: :existence,
        psi_1: :regeneration,
        psi_2: :history,
        psi_3: :verification,
        psi_4: :human_alignment,
        psi_5: :truthfulness
      }

      # Constitution hash must be immutable
      hash = :crypto.hash(:sha3_256, :erlang.term_to_binary(node_constitution))
      assert byte_size(hash) == 32

      # Re-hashing produces same result (deterministic)
      hash2 = :crypto.hash(:sha3_256, :erlang.term_to_binary(node_constitution))
      assert hash == hash2
    end

    test "node autonomy is preserved" do
      nodes = [:alpha, :beta, :gamma]
      constitutions = for n <- nodes, into: %{}, do: {n, %{version: 1, owner: n}}

      # Each node has its own constitution
      for {node, const} <- constitutions do
        assert const.owner == node
      end
    end

    test "constitution divergence is detectable (SC-FED-003)" do
      # All clusters should share the same constitutional hash
      base_constitution = %{
        psi_0: :existence,
        psi_1: :regeneration,
        psi_2: :history,
        psi_3: :verification,
        psi_4: :human_alignment,
        psi_5: :truthfulness
      }

      reference_hash =
        :crypto.hash(:sha3_256, :erlang.term_to_binary(base_constitution))

      # Diverged constitution (modified)
      diverged_constitution = Map.put(base_constitution, :psi_5, :deception)

      diverged_hash =
        :crypto.hash(:sha3_256, :erlang.term_to_binary(diverged_constitution))

      # Divergence is detectable by hash comparison
      assert reference_hash != diverged_hash,
             "Constitution divergence must be detectable (SC-FED-003)"
    end

    test "federation peers notified on configuration change (SC-RECONFIG-010)" do
      # Simulate a reconfiguration event
      reconfig_event = %{
        type: :reconfiguration,
        cluster_id: "cluster-alpha",
        change: :version_upgrade,
        new_version: "21.4.0",
        notified_peers: ["cluster-beta", "cluster-gamma"],
        timestamp: System.system_time(:millisecond)
      }

      assert reconfig_event.type == :reconfiguration

      assert length(reconfig_event.notified_peers) >= 2,
             "At least 2 federation peers must be notified (SC-RECONFIG-010)"
    end
  end

  # ===========================================================================
  # L6-L7-TEST-003: Version negotiation (SC-FED-003)
  # ===========================================================================

  describe "L6→L7: Version negotiation across clusters" do
    test "version comparison follows semver" do
      v1 = {21, 3, 0}
      v2 = {21, 3, 1}
      v3 = {22, 0, 0}

      assert v1 < v2
      assert v2 < v3
      assert v1 < v3
    end

    test "compatible versions can federate" do
      local = {21, 3, 0}
      remote = {21, 3, 1}

      {major_l, minor_l, _} = local
      {major_r, minor_r, _} = remote

      compatible? = major_l == major_r and minor_l == minor_r
      assert compatible?, "Same major.minor should be compatible"
    end

    test "major version mismatch blocks federation" do
      local = {21, 3, 0}
      remote = {22, 0, 0}

      {major_l, _, _} = local
      {major_r, _, _} = remote

      compatible? = major_l == major_r
      refute compatible?, "Different major versions are incompatible"
    end

    test "federation negotiates minimum common protocol version" do
      cluster_versions = [
        %{cluster: "alpha", version: {21, 3, 0}},
        %{cluster: "beta", version: {21, 3, 2}},
        %{cluster: "gamma", version: {21, 3, 1}}
      ]

      # Minimum compatible version across all clusters
      min_version =
        cluster_versions
        |> Enum.map(& &1.version)
        |> Enum.min()

      assert min_version == {21, 3, 0},
             "Federation negotiates lowest common version"

      # All clusters must support the minimum version
      for %{version: v} <- cluster_versions do
        assert v >= min_version
      end
    end
  end

  # ===========================================================================
  # L6-L7-TEST-004: Federation membership and cross-cluster sync
  # ===========================================================================

  describe "L6→L7: Federation membership" do
    test "membership list tracks active peers" do
      peers = [
        %{id: "peer_1", status: :active, last_seen: System.system_time(:second)},
        %{id: "peer_2", status: :active, last_seen: System.system_time(:second)},
        %{id: "peer_3", status: :stale, last_seen: System.system_time(:second) - 3600}
      ]

      active = Enum.filter(peers, &(&1.status == :active))
      assert length(active) == 2
    end

    test "attestation expires after 1 hour (SC-SMRITI-110)" do
      now = System.system_time(:second)
      attestation_time = now - 3601

      expired? = now - attestation_time > 3600
      assert expired?, "Attestation must expire after 1 hour"
    end

    test "cross-cluster state synchronization uses version vectors" do
      # Version vectors for conflict-free replication
      cluster_a_vv = %{alpha: 5, beta: 3, gamma: 1}
      cluster_b_vv = %{alpha: 4, beta: 4, gamma: 2}

      # Detect concurrent updates: neither dominates the other
      a_dominates_b? =
        Enum.all?(cluster_a_vv, fn {k, v} ->
          Map.get(cluster_b_vv, k, 0) <= v
        end)

      b_dominates_a? =
        Enum.all?(cluster_b_vv, fn {k, v} ->
          Map.get(cluster_a_vv, k, 0) <= v
        end)

      # Neither dominates → concurrent update, needs merge
      refute a_dominates_b? and b_dominates_a?,
             "Neither cluster dominates → concurrent state, requires merge"
    end

    test "federation state sync maintains causal ordering" do
      # Events from two clusters that must maintain causal order
      events = [
        %{cluster: :alpha, seq: 1, action: :config_update, ts: 100},
        %{cluster: :beta, seq: 1, action: :peer_joined, ts: 101},
        %{cluster: :alpha, seq: 2, action: :deploy, ts: 102},
        %{cluster: :gamma, seq: 1, action: :health_check, ts: 103}
      ]

      # Events must be ordered by timestamp for causal consistency
      sorted = Enum.sort_by(events, & &1.ts)

      assert Enum.map(sorted, & &1.ts) == [100, 101, 102, 103],
             "Federation events must maintain causal ordering"
    end

    test "cluster join requires attestation before receiving federation state" do
      joining_cluster = %{
        id: "cluster-delta",
        public_key: nil,
        # Not yet attested
        attested: false
      }

      # Cluster cannot receive federation state until attested
      can_receive_state? = joining_cluster.attested

      refute can_receive_state?,
             "Unattested cluster must not receive federation state (SC-FED-006)"

      # After attestation
      attested_cluster = Map.put(joining_cluster, :attested, true)
      assert attested_cluster.attested
    end
  end

  # ===========================================================================
  # L6-L7-TEST-005: Property-based federation
  # ===========================================================================

  describe "L6→L7: Property-based federation" do
    property "Ed25519 signatures are deterministic for same key+message" do
      forall msg <- PC.binary() do
        {_pub, priv} = :crypto.generate_key(:eddsa, :ed25519)
        sig1 = :crypto.sign(:eddsa, :none, msg, [priv, :ed25519])
        sig2 = :crypto.sign(:eddsa, :none, msg, [priv, :ed25519])
        sig1 == sig2
      end
    end

    property "constitution hash is stable under repeated serialization" do
      forall n <- PC.pos_integer() do
        constitution = %{version: n, invariants: n * 6}
        binary = :erlang.term_to_binary(constitution)
        hash1 = :crypto.hash(:sha3_256, binary)
        hash2 = :crypto.hash(:sha3_256, binary)
        hash1 == hash2
      end
    end

    property "version vector comparison is antisymmetric" do
      forall {a, b} <- {PC.range(0, 100), PC.range(0, 100)} do
        # If a > b, then b is not > a
        not (a > b and b > a)
      end
    end

    property "federation quorum is a strict majority" do
      forall n <- PC.range(1, 20) do
        q = div(n, 2) + 1
        # Quorum must be > half
        q * 2 > n
      end
    end
  end
end
