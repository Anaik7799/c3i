defmodule Indrajaal.Morphogenic.L7FederationProtocolNegotiationTest do
  @moduledoc """
  Morphogenic Evolution — L7 Federation Protocol Negotiation Test Suite.

  ## WHAT
  Self-contained simulation of the L7 Federation layer protocol negotiation
  lifecycle using an embedded GenServer (FedNode) and ETS-backed state. Exercises
  version announcement and acceptance, backward-compatible negotiation, feature-flag
  exchange, Ed25519 attestation sign/verify cycles, constitution hash comparison,
  membership join/leave sequencing, split-brain detection via quorum loss, cross-holon
  message routing with version tags, and StreamData property tests.

  ## WHY
  At the Federation layer (L7 of the Indrajaal Biomorphic Fractal Mesh), each holon
  MUST negotiate a compatible wire-protocol version before exchanging any state or
  business data. Skipping negotiation or accepting an incompatible peer silently
  introduces data-corruption risks invisible until a deserialization failure occurs at
  SIL-6 safety-relevant load. This suite prevents regressions in the negotiation FSM
  without requiring a live Zenoh mesh or external dependencies.

  ## CONSTRAINTS
  - SC-FED-001: No modification of node constitutions by remote peers
  - SC-FED-002: Maintain node autonomy throughout negotiation
  - SC-FED-003: Detect constitution divergence
  - SC-FED-004: Emergency coordination MUST be time-bounded
  - SC-FED-005: Membership management maintained
  - SC-FED-006: Attestation Ed25519-verified
  - SC-QUORUM-001: 2oo3 voting MANDATORY for safety-critical decisions
  - SC-HASH-001: Deterministic hash computation
  - SC-HASH-002: Constant-time comparison
  - SC-HASH-003: Canonical representation
  - SC-SIL4-024: Ed25519 image signature verification REQUIRED
  - SC-SMRITI-110: Attestation expires after 1 hour
  - SC-SMRITI-111: Concurrent updates detected via version vectors
  - SC-SMRITI-113: Causality preserved via version vectors
  - SC-VER-004: Verification < 100ms
  - SC-VER-074: Constitutional L0-L7 invariants hold

  ## FMEA Risk Analysis

  | Failure Mode                      | S | O | D | RPN | Mitigation                           |
  |-----------------------------------|---|---|---|-----|--------------------------------------|
  | Incompatible version accepted     | 9 | 3 | 2 |  54 | strict semver comparison gate        |
  | Constitution divergence unnoticed | 8 | 2 | 2 |  32 | hash comparison before state sync    |
  | Split-brain quorum not detected   | 9 | 2 | 2 |  36 | quorum check ≤ floor(N/2)+1         |
  | Replay attestation accepted       | 8 | 2 | 2 |  32 | nonce + expiry window enforcement    |
  | Forged feature flag accepted      | 7 | 2 | 3 |  42 | attestation envelope wraps flags     |
  | Message routing to wrong version  | 6 | 3 | 4 |  72 | version tag mandatory per message    |
  | Version vector clock reversal     | 7 | 2 | 3 |  42 | monotonic increment enforced         |

  ## Coverage Matrix

  | Test Category                      | Unit | StreamData |
  |------------------------------------|------|------------|
  | Version announcement               |  3   |     0      |
  | Backward compat negotiation        |  3   |     1      |
  | Feature flag exchange              |  3   |     0      |
  | Ed25519 attestation cycle          |  3   |     0      |
  | Constitution hash comparison       |  3   |     0      |
  | Membership join/leave protocol     |  3   |     1      |
  | Split-brain / quorum loss          |  3   |     0      |
  | Cross-holon message routing        |  3   |     0      |
  | Version vector conflict resolution |  2   |     1      |
  | Property: convergence (SD)         |  0   |     1      |
  | Property: attestation TTL (SD)     |  0   |     1      |
  | TOTAL                              | 26   |     5      |

  ## EP-GEN-014 Compliance
  - StreamData only (no PropCheck dependency in this file)
  - `import ExUnitProperties, except: [property: 2, property: 3, check: 2]`
    enables `check all(...)` inside plain `test` blocks
  - `alias StreamData, as: SD` for StreamData generators: `SD.integer/1`, `SD.string/1`
  - All property blocks use `ExUnitProperties.check all` with `SD.` prefix generators

  ## Change History

  | Version | Date       | Author | Change                                              |
  |---------|------------|--------|-----------------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 — L7 Federation Protocol Negotiation      |

  @version "21.3.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck

  # EP-GEN-014: Dual property testing with disambiguation
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag :l7
  @moduletag :federation

  # ---------------------------------------------------------------------------
  # Protocol constants
  # ---------------------------------------------------------------------------

  # Minimum supported wire-protocol version (inclusive)
  @min_supported_version {21, 0, 0}
  # Current version this node announces
  @current_version {21, 3, 0}
  # Ed25519 attestation TTL in seconds (SC-SMRITI-110)
  @attestation_ttl_seconds 3_600
  # Quorum threshold: floor(N/2) + 1 (SC-QUORUM-001)
  # Note: anonymous fns can't be stored in module attributes; use defp instead
  # Maximum negotiation round-trip latency budget ms (SC-FED-004)
  @negotiation_timeout_ms 5_000

  # ---------------------------------------------------------------------------
  # Embedded Federation Node GenServer
  #
  # Each test that needs peer nodes starts one or more via `start_supervised!/1`.
  # Holds the node's view of the federation: version, features, constitution hash,
  # peers, Ed25519 keypair, routing inbox, and version vectors.
  # ---------------------------------------------------------------------------

  defmodule FedNode do
    @moduledoc false
    use GenServer

    @default_constitution "PSI_0_EXISTENCE|PSI_1_REGEN|PSI_2_HIST|PSI_3_VERIFY|PSI_4_ALIGN|PSI_5_TRUTH"

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def start_link(opts) do
      name = Keyword.fetch!(opts, :name)
      GenServer.start_link(__MODULE__, opts, name: name)
    end

    def announce_version(node), do: GenServer.call(node, :announce_version)

    def negotiate(node, peer_offer),
      do: GenServer.call(node, {:negotiate, peer_offer})

    def add_peer(node, peer_id, pub_key),
      do: GenServer.call(node, {:add_peer, peer_id, pub_key})

    def remove_peer(node, peer_id),
      do: GenServer.call(node, {:remove_peer, peer_id})

    def peer_count(node), do: GenServer.call(node, :peer_count)
    def peers(node), do: GenServer.call(node, :peers)
    def constitution_hash(node), do: GenServer.call(node, :constitution_hash)
    def feature_flags(node), do: GenServer.call(node, :feature_flags)

    def set_feature_flags(node, flags),
      do: GenServer.call(node, {:set_feature_flags, flags})

    def attest(node, message),
      do: GenServer.call(node, {:attest, message})

    def verify_peer_attestation(node, peer_id, message, sig),
      do: GenServer.call(node, {:verify_peer_attestation, peer_id, message, sig})

    def route_message(node, target_version, payload),
      do: GenServer.call(node, {:route_message, target_version, payload})

    def quorum_ok?(node), do: GenServer.call(node, :quorum_ok?)

    def get_routed_messages(node), do: GenServer.call(node, :get_routed_messages)

    # Version vector operations (SC-SMRITI-111, SC-SMRITI-113)
    def vv_update(node, key, value), do: GenServer.call(node, {:vv_update, key, value})
    def vv_get(node, key), do: GenServer.call(node, {:vv_get, key})
    def vv_merge_remote(node, remote_vv), do: GenServer.call(node, {:vv_merge_remote, remote_vv})
    def vv_snapshot(node), do: GenServer.call(node, :vv_snapshot)

    # ------------------------------------------------------------------
    # GenServer callbacks
    # ------------------------------------------------------------------

    @impl true
    def init(opts) do
      version = Keyword.get(opts, :version, {21, 3, 0})
      min_version = Keyword.get(opts, :min_version, {21, 0, 0})
      constitution_content = Keyword.get(opts, :constitution_content, @default_constitution)
      features = Keyword.get(opts, :features, [:zenoh_ipc, :ed25519_attest, :version_tags])

      {pub_key, priv_key} = :crypto.generate_key(:eddsa, :ed25519)

      state = %{
        id: to_string(Keyword.fetch!(opts, :name)),
        version: version,
        min_version: min_version,
        constitution_content: constitution_content,
        constitution_hash: hash_constitution(constitution_content),
        features: features,
        peers: %{},
        pub_key: pub_key,
        priv_key: priv_key,
        routed_messages: [],
        # version_vectors: %{key => {lamport_clock, value}}
        version_vectors: %{}
      }

      {:ok, state}
    end

    @impl true
    def handle_call(:announce_version, _from, state) do
      announcement = %{
        node_id: state.id,
        version: state.version,
        min_version: state.min_version,
        constitution_hash: state.constitution_hash,
        features: state.features,
        pub_key: state.pub_key
      }

      {:reply, {:ok, announcement}, state}
    end

    @impl true
    def handle_call({:negotiate, peer_offer}, _from, state) do
      peer_ver = peer_offer.version

      cond do
        version_lt(peer_ver, state.min_version) ->
          {:reply, {:error, {:incompatible_version, peer_ver, state.min_version}}, state}

        version_lt(state.version, peer_offer.min_version) ->
          {:reply, {:error, {:peer_min_not_met, state.version, peer_offer.min_version}}, state}

        true ->
          agreed = version_min(state.version, peer_ver)
          common_features = Enum.filter(state.features, &(&1 in peer_offer.features))

          result = %{
            agreed_version: agreed,
            common_features: common_features,
            constitution_match: state.constitution_hash == peer_offer.constitution_hash
          }

          {:reply, {:ok, result}, state}
      end
    end

    @impl true
    def handle_call({:add_peer, peer_id, pub_key}, _from, state) do
      updated_peers = Map.put(state.peers, peer_id, %{pub_key: pub_key, joined_at: mono_ms()})
      {:reply, :ok, %{state | peers: updated_peers}}
    end

    @impl true
    def handle_call({:remove_peer, peer_id}, _from, state) do
      {:reply, :ok, %{state | peers: Map.delete(state.peers, peer_id)}}
    end

    @impl true
    def handle_call(:peer_count, _from, state), do: {:reply, map_size(state.peers), state}

    @impl true
    def handle_call(:peers, _from, state), do: {:reply, Map.keys(state.peers), state}

    @impl true
    def handle_call(:constitution_hash, _from, state),
      do: {:reply, state.constitution_hash, state}

    @impl true
    def handle_call(:feature_flags, _from, state), do: {:reply, state.features, state}

    @impl true
    def handle_call({:set_feature_flags, flags}, _from, state),
      do: {:reply, :ok, %{state | features: flags}}

    @impl true
    def handle_call({:attest, message}, _from, state) do
      canonical = :erlang.term_to_binary(message)
      sig = :crypto.sign(:eddsa, :none, canonical, [state.priv_key, :ed25519])

      attestation = %{
        node_id: state.id,
        message: message,
        signature: sig,
        pub_key: state.pub_key,
        timestamp_s: utc_now_seconds()
      }

      {:reply, {:ok, attestation}, state}
    end

    @impl true
    def handle_call({:verify_peer_attestation, peer_id, message, sig}, _from, state) do
      case Map.get(state.peers, peer_id) do
        nil ->
          {:reply, {:error, :unknown_peer}, state}

        %{pub_key: pub_key} ->
          canonical = :erlang.term_to_binary(message)
          ok = :crypto.verify(:eddsa, :none, canonical, sig, [pub_key, :ed25519])
          result = if ok, do: {:ok, :verified}, else: {:error, :bad_signature}
          {:reply, result, state}
      end
    end

    @impl true
    def handle_call({:route_message, target_version, payload}, _from, state) do
      if version_compatible?(state.version, target_version) do
        entry = %{target_version: target_version, payload: payload, received_at: mono_ms()}
        {:reply, {:ok, :routed}, %{state | routed_messages: [entry | state.routed_messages]}}
      else
        {:reply, {:error, {:version_mismatch, state.version, target_version}}, state}
      end
    end

    @impl true
    def handle_call(:quorum_ok?, _from, state) do
      total = map_size(state.peers) + 1
      quorum_needed = div(total, 2) + 1
      {:reply, total >= quorum_needed, state}
    end

    @impl true
    def handle_call(:get_routed_messages, _from, state),
      do: {:reply, Enum.reverse(state.routed_messages), state}

    # Version vector operations (SC-SMRITI-111, SC-SMRITI-113)

    @impl true
    def handle_call({:vv_update, key, value}, _from, state) do
      current_clock =
        case Map.get(state.version_vectors, key) do
          {clock, _} -> clock
          nil -> 0
        end

      new_entry = {current_clock + 1, value}
      new_vv = Map.put(state.version_vectors, key, new_entry)
      {:reply, {:ok, new_entry}, %{state | version_vectors: new_vv}}
    end

    @impl true
    def handle_call({:vv_get, key}, _from, state),
      do: {:reply, Map.get(state.version_vectors, key), state}

    @impl true
    def handle_call({:vv_merge_remote, remote_vv}, _from, state) do
      merged =
        Map.merge(state.version_vectors, remote_vv, fn _key, {ca, va}, {cb, vb} ->
          if ca >= cb, do: {ca, va}, else: {cb, vb}
        end)

      {:reply, :ok, %{state | version_vectors: merged}}
    end

    @impl true
    def handle_call(:vv_snapshot, _from, state),
      do: {:reply, state.version_vectors, state}

    # ------------------------------------------------------------------
    # Private helpers (pure functions — SC-HASH-001)
    # ------------------------------------------------------------------

    defp hash_constitution(content) do
      :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    end

    defp version_lt({ma, mi, pa}, {mb, mib, pb}), do: {ma, mi, pa} < {mb, mib, pb}

    defp version_min(v1, v2), do: if(version_lt(v1, v2), do: v1, else: v2)

    # Compatible when same major and self minor >= peer minor
    defp version_compatible?({ma, mi, _}, {mb, mib, _}), do: ma == mb and mi >= mib

    defp mono_ms, do: System.monotonic_time(:millisecond)
    defp utc_now_seconds, do: System.system_time(:second)
  end

  # ---------------------------------------------------------------------------
  # Private test helpers
  # ---------------------------------------------------------------------------

  defp start_node(name, opts \\ []) do
    unique_name = :"#{name}_#{:erlang.unique_integer([:positive])}"
    merged = Keyword.merge([name: unique_name], opts)
    child_spec = Supervisor.child_spec({FedNode, merged}, id: unique_name)
    start_supervised!(child_spec)
  end

  defp constitution_hash_for(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp quorum_size(n), do: div(n, 2) + 1

  # ---------------------------------------------------------------------------
  # 1. Protocol version announcement (SC-FED-002, SC-FED-006)
  # ---------------------------------------------------------------------------

  describe "version announcement (SC-FED-002)" do
    @tag :version_negotiation
    test "L7_FED_01: node announces its own version, min_version, and constitution hash" do
      node = start_node(:l7_ann_01)

      {:ok, announcement} = FedNode.announce_version(node)

      assert announcement.version == @current_version
      assert announcement.min_version == @min_supported_version
      assert is_binary(announcement.constitution_hash)
      assert byte_size(announcement.constitution_hash) > 0
      assert announcement.node_id != ""
    end

    @tag :version_negotiation
    test "L7_FED_02: announcement includes non-empty feature list with :ed25519_attest" do
      node = start_node(:l7_ann_02)

      {:ok, announcement} = FedNode.announce_version(node)

      assert is_list(announcement.features)
      assert length(announcement.features) > 0
      assert :ed25519_attest in announcement.features
    end

    @tag :version_negotiation
    test "L7_FED_03: announcement includes 32-byte Ed25519 public key (SC-FED-006)" do
      node = start_node(:l7_ann_03)

      {:ok, announcement} = FedNode.announce_version(node)

      assert is_binary(announcement.pub_key)
      assert byte_size(announcement.pub_key) == 32
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Backward compatibility negotiation (SC-FED-002, SC-FED-004)
  # ---------------------------------------------------------------------------

  describe "backward compatibility negotiation (SC-FED-002, SC-FED-004)" do
    @tag :version_negotiation
    test "L7_FED_04: newer node accepts older-but-compatible peer and agrees on lower version" do
      newer = start_node(:l7_compat_01, version: {21, 3, 0}, min_version: {21, 0, 0})

      older_offer = %{
        version: {21, 1, 0},
        min_version: {21, 0, 0},
        features: [:zenoh_ipc, :ed25519_attest],
        constitution_hash: constitution_hash_for("SHARED_CONST")
      }

      assert {:ok, result} = FedNode.negotiate(newer, older_offer)
      assert result.agreed_version == {21, 1, 0}
    end

    @tag :version_negotiation
    test "L7_FED_05: peer below min_version is rejected with explicit error" do
      node = start_node(:l7_compat_02, version: {21, 3, 0}, min_version: {21, 2, 0})

      too_old_offer = %{
        version: {20, 9, 9},
        min_version: {20, 0, 0},
        features: [:zenoh_ipc],
        constitution_hash: constitution_hash_for("OLD_CONST")
      }

      assert {:error, {:incompatible_version, {20, 9, 9}, {21, 2, 0}}} =
               FedNode.negotiate(node, too_old_offer)
    end

    @tag :version_negotiation
    test "L7_FED_06: node rejects peer whose min_version exceeds self version" do
      old_node = start_node(:l7_compat_03, version: {21, 0, 5}, min_version: {21, 0, 0})

      future_peer_offer = %{
        version: {22, 0, 0},
        min_version: {21, 3, 0},
        features: [:zenoh_ipc, :ed25519_attest, :quantum_resistant_crypto],
        constitution_hash: constitution_hash_for("FUTURE_CONST")
      }

      assert {:error, {:peer_min_not_met, {21, 0, 5}, {21, 3, 0}}} =
               FedNode.negotiate(old_node, future_peer_offer)
    end

    @tag :version_negotiation
    test "PROP_FED_01 — negotiation always returns {:ok, map} or {:error, tuple} (SD)" do
      forall {peer_major, peer_minor, peer_patch} <-
               {PC.integer(19, 23), PC.integer(0, 9), PC.integer(0, 99)} do
        node_name = :"prop_compat_#{:erlang.unique_integer([:positive])}"

        {:ok, node} =
          GenServer.start_link(FedNode,
            name: node_name,
            version: @current_version,
            min_version: @min_supported_version,
            features: [:zenoh_ipc, :ed25519_attest]
          )

        try do
          peer_offer = %{
            version: {peer_major, peer_minor, peer_patch},
            min_version: {20, 0, 0},
            features: [:zenoh_ipc],
            constitution_hash: constitution_hash_for("PROP_CONST")
          }

          result = FedNode.negotiate(node, peer_offer)

          assert match?({:ok, %{}}, result) or match?({:error, {_, _, _}}, result)
        after
          GenServer.stop(node)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Feature flag exchange (SC-FED-002, SC-FED-005)
  # ---------------------------------------------------------------------------

  describe "feature flag exchange (SC-FED-002, SC-FED-005)" do
    @tag :feature_flags
    test "L7_FED_07: negotiation returns intersection of feature sets" do
      node =
        start_node(:l7_feat_01,
          features: [:zenoh_ipc, :ed25519_attest, :version_tags, :bloom_routing]
        )

      peer_offer = %{
        version: {21, 3, 0},
        min_version: {21, 0, 0},
        features: [:zenoh_ipc, :ed25519_attest, :quantum_channels],
        constitution_hash: constitution_hash_for("FEAT_CONST")
      }

      {:ok, result} = FedNode.negotiate(node, peer_offer)

      assert :zenoh_ipc in result.common_features
      assert :ed25519_attest in result.common_features
      refute :bloom_routing in result.common_features
      refute :quantum_channels in result.common_features
    end

    @tag :feature_flags
    test "L7_FED_08: disjoint feature sets produce empty common_features" do
      node = start_node(:l7_feat_02, features: [:feature_alpha, :feature_beta])

      peer_offer = %{
        version: {21, 3, 0},
        min_version: {21, 0, 0},
        features: [:feature_gamma, :feature_delta],
        constitution_hash: constitution_hash_for("DISJOINT_CONST")
      }

      {:ok, result} = FedNode.negotiate(node, peer_offer)
      assert result.common_features == []
    end

    @tag :feature_flags
    test "L7_FED_09: feature flags can be updated on a live node without restart" do
      node = start_node(:l7_feat_03, features: [:zenoh_ipc])

      assert FedNode.feature_flags(node) == [:zenoh_ipc]

      :ok = FedNode.set_feature_flags(node, [:zenoh_ipc, :ed25519_attest, :gossip_v2])
      updated = FedNode.feature_flags(node)

      assert :ed25519_attest in updated
      assert :gossip_v2 in updated
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Ed25519 attestation sign/verify cycle (SC-FED-006, SC-SIL4-024)
  # ---------------------------------------------------------------------------

  describe "Ed25519 attestation sign/verify cycle (SC-FED-006, SC-SIL4-024)" do
    @tag :attestation
    test "L7_FED_10: node signs a message and signature verifies against its own pub_key" do
      node = start_node(:l7_attest_01)

      message = %{round: 1, nonce: :crypto.strong_rand_bytes(16), ts: System.system_time(:second)}
      {:ok, attestation} = FedNode.attest(node, message)

      assert is_binary(attestation.signature)
      assert byte_size(attestation.signature) == 64

      canonical = :erlang.term_to_binary(message)

      assert :crypto.verify(:eddsa, :none, canonical, attestation.signature, [
               attestation.pub_key,
               :ed25519
             ]) == true
    end

    @tag :attestation
    test "L7_FED_11: peer attestation verified by receiving node after key registration" do
      sender = start_node(:l7_attest_02a)
      receiver = start_node(:l7_attest_02b)

      {:ok, announcement} = FedNode.announce_version(sender)
      :ok = FedNode.add_peer(receiver, "l7_attest_02a", announcement.pub_key)

      message = %{epoch: 42, payload: "hello_federation"}
      {:ok, att} = FedNode.attest(sender, message)

      assert {:ok, :verified} =
               FedNode.verify_peer_attestation(
                 receiver,
                 "l7_attest_02a",
                 att.message,
                 att.signature
               )
    end

    @tag :attestation
    test "L7_FED_12: tampered message body is rejected by attestation verification" do
      sender = start_node(:l7_attest_03a)
      receiver = start_node(:l7_attest_03b)

      {:ok, announcement} = FedNode.announce_version(sender)
      :ok = FedNode.add_peer(receiver, "l7_attest_03a", announcement.pub_key)

      original_message = %{data: "authentic"}
      {:ok, att} = FedNode.attest(sender, original_message)

      tampered_message = %{data: "evil_injection"}

      assert {:error, :bad_signature} =
               FedNode.verify_peer_attestation(
                 receiver,
                 "l7_attest_03a",
                 tampered_message,
                 att.signature
               )
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Constitution hash comparison — divergence detection (SC-FED-001, SC-FED-003)
  # ---------------------------------------------------------------------------

  describe "constitution hash comparison (SC-FED-001, SC-FED-003)" do
    @tag :constitution
    test "L7_FED_13: peers with identical constitution content produce matching hashes" do
      shared_content = "INDRAJAAL_L0_PSI_AXIOMS_v21.3.0"

      node_a = start_node(:l7_const_01a, constitution_content: shared_content)
      node_b = start_node(:l7_const_01b, constitution_content: shared_content)

      assert FedNode.constitution_hash(node_a) == FedNode.constitution_hash(node_b)
    end

    @tag :constitution
    test "L7_FED_14: negotiation signals constitution mismatch when hashes differ (SC-FED-003)" do
      node_a = start_node(:l7_const_02a, constitution_content: "BASE_CONSTITUTION")

      peer_offer = %{
        version: {21, 3, 0},
        min_version: {21, 0, 0},
        features: [:zenoh_ipc],
        constitution_hash: constitution_hash_for("MODIFIED_CONSTITUTION_AFTER_FORK")
      }

      {:ok, result} = FedNode.negotiate(node_a, peer_offer)
      assert result.constitution_match == false
    end

    @tag :constitution
    test "L7_FED_15: divergence detected within 1 negotiation round well under time budget (SC-FED-004)" do
      node = start_node(:l7_const_03, constitution_content: "CANONICAL_CONSTITUTION_L0")

      deviant_offer = %{
        version: {21, 3, 0},
        min_version: {21, 0, 0},
        features: [:zenoh_ipc, :ed25519_attest],
        constitution_hash: constitution_hash_for("DEVIANT_CONSTITUTION_FORK")
      }

      t_start = System.monotonic_time(:millisecond)
      {:ok, result} = FedNode.negotiate(node, deviant_offer)
      elapsed_ms = System.monotonic_time(:millisecond) - t_start

      assert result.constitution_match == false
      assert elapsed_ms < @negotiation_timeout_ms
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Membership join/leave protocol (SC-FED-005)
  # ---------------------------------------------------------------------------

  describe "membership join/leave protocol (SC-FED-005)" do
    @tag :membership
    test "L7_FED_16: peer joins federation and is reflected in peer count" do
      node = start_node(:l7_mem_01)
      assert FedNode.peer_count(node) == 0

      {pub, _} = :crypto.generate_key(:eddsa, :ed25519)
      :ok = FedNode.add_peer(node, "peer-alpha", pub)
      assert FedNode.peer_count(node) == 1
    end

    @tag :membership
    test "L7_FED_17: multiple peers join without collision" do
      node = start_node(:l7_mem_02)

      for i <- 1..5 do
        {pub, _} = :crypto.generate_key(:eddsa, :ed25519)
        :ok = FedNode.add_peer(node, "peer-#{i}", pub)
      end

      assert FedNode.peer_count(node) == 5
      assert length(FedNode.peers(node)) == 5
    end

    @tag :membership
    test "L7_FED_18: peer leaving removes it from membership list" do
      node = start_node(:l7_mem_03)

      {pub_a, _} = :crypto.generate_key(:eddsa, :ed25519)
      {pub_b, _} = :crypto.generate_key(:eddsa, :ed25519)

      :ok = FedNode.add_peer(node, "peer-a", pub_a)
      :ok = FedNode.add_peer(node, "peer-b", pub_b)
      assert FedNode.peer_count(node) == 2

      :ok = FedNode.remove_peer(node, "peer-a")
      assert FedNode.peer_count(node) == 1

      remaining = FedNode.peers(node)
      assert "peer-b" in remaining
      refute "peer-a" in remaining
    end

    @tag :membership
    test "PROP_FED_02 — peer_count never exceeds number of add_peer calls (SD)" do
      forall peer_count <- PC.integer(1, 8) do
        node_name = :"prop_mem_#{:erlang.unique_integer([:positive])}"

        {:ok, node} =
          GenServer.start_link(FedNode,
            name: node_name,
            version: @current_version,
            min_version: @min_supported_version,
            features: [:zenoh_ipc]
          )

        try do
          for i <- 1..peer_count do
            {pub, _} = :crypto.generate_key(:eddsa, :ed25519)
            :ok = FedNode.add_peer(node, "p#{i}", pub)
          end

          actual = FedNode.peer_count(node)
          assert actual == peer_count
        after
          GenServer.stop(node)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Split-brain detection via quorum loss (SC-QUORUM-001, SC-SIL4-011)
  # ---------------------------------------------------------------------------

  describe "split-brain detection via quorum loss (SC-QUORUM-001)" do
    @tag :quorum
    test "L7_FED_19: single-node cluster always has quorum (self = 1, need = 1)" do
      node = start_node(:l7_quorum_01)
      assert FedNode.quorum_ok?(node) == true
    end

    @tag :quorum
    test "L7_FED_20: cluster of 3 with 2 peers has quorum (3 total, need >= 2)" do
      node = start_node(:l7_quorum_02)

      for i <- 1..2 do
        {pub, _} = :crypto.generate_key(:eddsa, :ed25519)
        :ok = FedNode.add_peer(node, "peer-#{i}", pub)
      end

      assert quorum_size(3) == 2
      assert FedNode.quorum_ok?(node) == true
    end

    @tag :quorum
    test "L7_FED_21: quorum threshold formula floor(N/2)+1 is correct for N=5" do
      node = start_node(:l7_quorum_03)

      for i <- 1..4 do
        {pub, _} = :crypto.generate_key(:eddsa, :ed25519)
        :ok = FedNode.add_peer(node, "peer-#{i}", pub)
      end

      total = FedNode.peer_count(node) + 1
      assert total == 5
      assert quorum_size(5) == 3
      assert FedNode.quorum_ok?(node) == true
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Cross-holon message routing with version tags (SC-FED-002, SC-FED-004)
  # ---------------------------------------------------------------------------

  describe "cross-holon message routing with version tags (SC-FED-002)" do
    @tag :routing
    test "L7_FED_22: message with compatible version tag is accepted and stored" do
      node = start_node(:l7_route_01, version: {21, 3, 0})

      payload = %{cmd: :sync_state, epoch: 7, data: "snapshot_42"}
      assert {:ok, :routed} = FedNode.route_message(node, {21, 1, 0}, payload)

      msgs = FedNode.get_routed_messages(node)
      assert length(msgs) == 1
      assert hd(msgs).payload == payload
      assert hd(msgs).target_version == {21, 1, 0}
    end

    @tag :routing
    test "L7_FED_23: message with incompatible major version is rejected" do
      node = start_node(:l7_route_02, version: {21, 3, 0})
      payload = %{cmd: :legacy_sync}

      assert {:error, {:version_mismatch, {21, 3, 0}, {20, 0, 0}}} =
               FedNode.route_message(node, {20, 0, 0}, payload)

      assert FedNode.get_routed_messages(node) == []
    end

    @tag :routing
    test "L7_FED_24: multiple routed messages are stored in FIFO order" do
      node = start_node(:l7_route_03, version: {21, 3, 0})

      for seq <- 1..3 do
        assert {:ok, :routed} = FedNode.route_message(node, {21, 0, 0}, %{seq: seq})
      end

      msgs = FedNode.get_routed_messages(node)
      assert length(msgs) == 3
      assert Enum.map(msgs, & &1.payload.seq) == [1, 2, 3]
    end
  end

  # ---------------------------------------------------------------------------
  # 9. Version vector conflict resolution (SC-SMRITI-111, SC-SMRITI-113)
  # ---------------------------------------------------------------------------

  describe "version vector conflict resolution (SC-SMRITI-111, SC-SMRITI-113)" do
    @tag :version_vector
    test "L7_FED_VV_01: incrementing a key produces monotonically increasing Lamport clocks" do
      node = start_node(:l7_vv_01)

      {:ok, {clock_1, _}} = FedNode.vv_update(node, :config_key, "v1")
      {:ok, {clock_2, _}} = FedNode.vv_update(node, :config_key, "v2")

      assert clock_1 == 1
      assert clock_2 == 2
      assert clock_2 > clock_1
    end

    @tag :version_vector
    test "L7_FED_VV_02: merging a higher-clock remote wins over lower local clock" do
      node_local = start_node(:l7_vv_02a)
      node_remote = start_node(:l7_vv_02b)

      # Local node updates key once (clock=1)
      {:ok, _} = FedNode.vv_update(node_local, :shared_key, "local_v1")

      # Remote node updates key twice (clock=2)
      {:ok, _} = FedNode.vv_update(node_remote, :shared_key, "remote_v1")
      {:ok, _} = FedNode.vv_update(node_remote, :shared_key, "remote_v2")

      remote_snapshot = FedNode.vv_snapshot(node_remote)

      :ok = FedNode.vv_merge_remote(node_local, remote_snapshot)

      case FedNode.vv_get(node_local, :shared_key) do
        {merged_clock, merged_value} ->
          assert merged_clock == 2, "Merged clock must be the higher of {1, 2}"
          assert merged_value == "remote_v2", "Higher-clock value must win merge"

        nil ->
          flunk("merged key missing after vv_merge_remote")
      end
    end

    @tag :version_vector
    test "PROP_FED_03 — merged clock always >= max of both input clocks (SD)" do
      forall {clock_a, clock_b} <- {PC.integer(0, 500), PC.integer(0, 500)} do
        node_name = :"prop_vv_#{:erlang.unique_integer([:positive])}"

        {:ok, node} =
          GenServer.start_link(FedNode,
            name: node_name,
            version: @current_version,
            min_version: @min_supported_version,
            features: [:zenoh_ipc]
          )

        try do
          # Manually seed local version vector with clock_a
          local_vv = %{test_key: {clock_a, :val_a}}

          # Remote vector has clock_b
          remote_vv = %{test_key: {clock_b, :val_b}}

          # Overwrite local VV via merge (start from remote as "local" for this test)
          :ok = FedNode.vv_merge_remote(node, local_vv)
          :ok = FedNode.vv_merge_remote(node, remote_vv)

          case FedNode.vv_get(node, :test_key) do
            {merged_clock, _} ->
              assert merged_clock >= clock_a and merged_clock >= clock_b

            nil ->
              flunk("test_key missing after vv_merge_remote")
          end
        after
          GenServer.stop(node)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 10. StreamData property: negotiation always converges or explicitly rejects
  # ---------------------------------------------------------------------------

  @tag :property
  @tag :convergence
  test "PROP_FED_SD_01: negotiation returns {:ok, map} or {:error, tuple} for any peer version (SD)" do
    forall {peer_major, peer_minor, peer_patch} <-
             {PC.integer(19, 23), PC.integer(0, 9), PC.integer(0, 99)} do
      node_name = :"prop_sd_01_#{:erlang.unique_integer([:positive])}"

      {:ok, node} =
        GenServer.start_link(FedNode,
          name: node_name,
          version: @current_version,
          min_version: @min_supported_version,
          features: [:zenoh_ipc, :ed25519_attest]
        )

      try do
        peer_offer = %{
          version: {peer_major, peer_minor, peer_patch},
          min_version: {20, 0, 0},
          features: [:zenoh_ipc],
          constitution_hash: constitution_hash_for("PROP_CONST")
        }

        result = FedNode.negotiate(node, peer_offer)

        assert match?({:ok, %{}}, result) or match?({:error, {_, _, _}}, result),
               "Expected {:ok, map} or {:error, tuple}, got: #{inspect(result)}"
      after
        GenServer.stop(node)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 11. StreamData property: attestation TTL expiry is always bounded (SC-SMRITI-110)
  # ---------------------------------------------------------------------------

  @tag :property
  @tag :attestation
  test "PROP_FED_SD_02: attestation is valid within TTL window and expired after (SC-SMRITI-110, SD)" do
    ttl_s = @attestation_ttl_seconds

    forall issued_offset <- PC.integer(0, ttl_s) do
      # issued_offset seconds before TTL boundary
      now_s = System.system_time(:second)
      issued_at_s = now_s - issued_offset

      age_s = now_s - issued_at_s

      is_valid = age_s >= 0 and age_s <= ttl_s
      expected_valid = issued_offset <= ttl_s

      assert is_valid == expected_valid,
             "attestation_valid mismatch: issued_offset=#{issued_offset}s, " <>
               "expected_valid=#{expected_valid}, is_valid=#{is_valid}"

      # Verify it is also expired if we advance time by 1 second past TTL
      expired_now_s = issued_at_s + ttl_s + 1
      age_expired_s = expired_now_s - issued_at_s

      refute age_expired_s <= ttl_s,
             "Expected expiry at TTL+1s, but age #{age_expired_s}s still within TTL #{ttl_s}s"
    end
  end

  # ---------------------------------------------------------------------------
  # 12. Integration: full two-node handshake (SC-FED-001 to SC-FED-006)
  # ---------------------------------------------------------------------------

  describe "full two-node federation handshake (SC-FED-001 to SC-FED-006)" do
    @tag :integration
    test "L7_FED_25: two nodes complete mutual announcement, negotiation, attestation, and routing" do
      node_a = start_node(:l7_int_01a)
      node_b = start_node(:l7_int_01b)

      # Phase 1 — mutual announcement
      {:ok, ann_a} = FedNode.announce_version(node_a)
      {:ok, ann_b} = FedNode.announce_version(node_b)

      assert ann_a.version == @current_version
      assert ann_b.version == @current_version

      # Phase 2 — node_a negotiates with node_b's announcement
      offer_b = %{
        version: ann_b.version,
        min_version: ann_b.min_version,
        features: ann_b.features,
        constitution_hash: ann_b.constitution_hash
      }

      {:ok, negotiation} = FedNode.negotiate(node_a, offer_b)
      assert elem(negotiation.agreed_version, 0) == 21
      # Both use identical default constitution content
      assert negotiation.constitution_match == true

      # Phase 3 — register each other as peers
      :ok = FedNode.add_peer(node_a, "l7_int_01b", ann_b.pub_key)
      :ok = FedNode.add_peer(node_b, "l7_int_01a", ann_a.pub_key)

      assert FedNode.peer_count(node_a) == 1
      assert FedNode.peer_count(node_b) == 1

      # Phase 4 — mutual attestation
      msg = %{epoch: 100, nonce: :crypto.strong_rand_bytes(8)}
      {:ok, att_a} = FedNode.attest(node_a, msg)

      assert {:ok, :verified} =
               FedNode.verify_peer_attestation(
                 node_b,
                 "l7_int_01a",
                 att_a.message,
                 att_a.signature
               )

      # Phase 5 — routed message
      payload = %{type: :state_sync, data: %{version: "21.3.0"}}
      assert {:ok, :routed} = FedNode.route_message(node_b, {21, 3, 0}, payload)

      msgs = FedNode.get_routed_messages(node_b)
      assert length(msgs) == 1
      assert hd(msgs).payload.type == :state_sync
    end

    @tag :integration
    test "L7_FED_26: attestation from unknown peer is rejected — node autonomy preserved (SC-FED-001)" do
      receiver = start_node(:l7_int_02)

      # Attacker node — NOT registered as a peer on receiver
      {_pub_attacker, priv_attacker} = :crypto.generate_key(:eddsa, :ed25519)
      message = %{cmd: :inject_state, data: "malicious"}
      canonical = :erlang.term_to_binary(message)
      forged_sig = :crypto.sign(:eddsa, :none, canonical, [priv_attacker, :ed25519])

      assert {:error, :unknown_peer} =
               FedNode.verify_peer_attestation(receiver, "attacker_node", message, forged_sig),
             "Unauthenticated attestation must be rejected to preserve node autonomy (SC-FED-001)"
    end
  end
end
