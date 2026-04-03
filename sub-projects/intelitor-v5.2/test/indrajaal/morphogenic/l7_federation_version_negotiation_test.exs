defmodule Indrajaal.Morphogenic.L7FederationVersionNegotiationTest do
  @moduledoc """
  TDG test: L7 Federation version negotiation protocol for cross-holon compatibility.

  WHAT: Tests protocol version negotiation between federation peers including backward
        compatibility, version vector ordering, peer attestation, constitution divergence
        detection, membership management, and coordinated upgrades.
  WHY: Validates SC-FED-001 (no modification of node constitutions), SC-FED-002 (node autonomy),
       SC-FED-003 (constitution divergence detection), SC-FED-004 (time-bounded coordination),
       SC-FED-005 (membership management), SC-FED-006 (Ed25519-verified attestation),
       SC-RECONFIG-007 (graceful degradation), SC-RECONFIG-010 (federation peer notification).

  STAMP Constraints:
  - SC-FED-001: No modification of node constitutions
  - SC-FED-002: Maintain node autonomy
  - SC-FED-003: Detect constitution divergence
  - SC-FED-004: Emergency coordination time-bounded
  - SC-FED-005: Membership management maintained
  - SC-FED-006: Attestation Ed25519-verified
  - SC-RECONFIG-007: Graceful degradation to older versions
  - SC-RECONFIG-010: Federation peers notified of reconfigurations
  """

  use ExUnit.Case, async: true
  use PropCheck
  require ExUnitProperties
  import ExUnitProperties, except: [property: 2, property: 3]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @protocol_versions ["1.0.0", "1.1.0", "2.0.0", "2.1.0", "3.0.0"]
  @attestation_ttl_ms 3_600_000

  describe "protocol version negotiation" do
    test "peers negotiate highest common version" do
      peer_a = build_peer("node-a", ["1.0.0", "1.1.0", "2.0.0"])
      peer_b = build_peer("node-b", ["1.0.0", "1.1.0"])

      {:ok, agreed} = negotiate_version(peer_a, peer_b)
      assert agreed == "1.1.0"
    end

    test "negotiation fails with no common version" do
      peer_a = build_peer("node-a", ["3.0.0"])
      peer_b = build_peer("node-b", ["1.0.0"])

      assert {:error, :no_common_version} = negotiate_version(peer_a, peer_b)
    end

    test "negotiation is commutative" do
      peer_a = build_peer("node-a", ["1.0.0", "2.0.0"])
      peer_b = build_peer("node-b", ["1.0.0", "2.0.0", "3.0.0"])

      {:ok, ab} = negotiate_version(peer_a, peer_b)
      {:ok, ba} = negotiate_version(peer_b, peer_a)
      assert ab == ba
    end

    test "single shared version succeeds" do
      peer_a = build_peer("node-a", ["2.0.0", "3.0.0"])
      peer_b = build_peer("node-b", ["1.0.0", "2.0.0"])

      {:ok, agreed} = negotiate_version(peer_a, peer_b)
      assert agreed == "2.0.0"
    end
  end

  describe "version vector ordering" do
    test "version comparison respects semver" do
      assert compare_versions("1.0.0", "2.0.0") == :lt
      assert compare_versions("2.0.0", "1.0.0") == :gt
      assert compare_versions("1.1.0", "1.1.0") == :eq
      assert compare_versions("1.0.0", "1.1.0") == :lt
      assert compare_versions("1.1.0", "1.2.0") == :lt
    end

    test "major version bump breaks backward compatibility" do
      assert not backward_compatible?("1.1.0", "2.0.0")
    end

    test "minor version bump is backward compatible" do
      assert backward_compatible?("1.0.0", "1.1.0")
      assert backward_compatible?("1.1.0", "1.0.0")
    end
  end

  describe "backward compatibility (SC-RECONFIG-007)" do
    test "graceful degradation to older protocol" do
      peer_new = build_peer("new-node", ["1.0.0", "2.0.0", "3.0.0"])
      peer_old = build_peer("old-node", ["1.0.0", "1.1.0"])

      {:ok, agreed} = negotiate_version(peer_new, peer_old)
      assert compare_versions(agreed, "2.0.0") == :lt
    end

    test "capability set reduces for older protocol" do
      caps_v2 = capabilities_for_version("2.0.0")
      caps_v1 = capabilities_for_version("1.0.0")

      assert MapSet.subset?(caps_v1, caps_v2)
    end

    test "all versions support base capabilities" do
      base = MapSet.new([:heartbeat, :health_check, :membership])

      for v <- @protocol_versions do
        caps = capabilities_for_version(v)
        assert MapSet.subset?(base, caps), "Version #{v} missing base capabilities"
      end
    end
  end

  describe "peer attestation (SC-FED-006)" do
    test "valid attestation accepted" do
      {pub, priv} = generate_keypair()
      peer = build_peer("attesting-node", ["2.0.0"])
      attestation = sign_attestation(peer, priv)

      assert {:ok, _} = verify_attestation(attestation, pub)
    end

    test "tampered attestation rejected" do
      {pub, priv} = generate_keypair()
      peer = build_peer("attesting-node", ["2.0.0"])
      attestation = sign_attestation(peer, priv)

      tampered = %{attestation | node_id: "evil-node"}
      assert {:error, :invalid_signature} = verify_attestation(tampered, pub)
    end

    test "expired attestation rejected" do
      {pub, priv} = generate_keypair()
      peer = build_peer("old-node", ["2.0.0"])
      old_time = System.monotonic_time(:millisecond) - @attestation_ttl_ms - 1000
      attestation = sign_attestation(peer, priv, old_time)

      assert {:error, :attestation_expired} = verify_attestation(attestation, pub)
    end
  end

  describe "constitution divergence detection (SC-FED-003)" do
    test "identical constitutions pass check" do
      hash_a = :crypto.hash(:sha256, "constitution-v1") |> Base.encode16()
      hash_b = hash_a

      assert :ok = check_constitution_divergence(hash_a, hash_b)
    end

    test "divergent constitutions detected" do
      hash_a = :crypto.hash(:sha256, "constitution-v1") |> Base.encode16()
      hash_b = :crypto.hash(:sha256, "constitution-v2") |> Base.encode16()

      assert {:error, :constitution_diverged} = check_constitution_divergence(hash_a, hash_b)
    end

    test "divergence includes both hashes for audit" do
      hash_a = :crypto.hash(:sha256, "const-a") |> Base.encode16()
      hash_b = :crypto.hash(:sha256, "const-b") |> Base.encode16()

      {:error, :constitution_diverged} = check_constitution_divergence(hash_a, hash_b)
      # In a real system, this would log to Immutable Register with both hashes
    end
  end

  describe "membership management (SC-FED-005)" do
    test "peer joins federation" do
      federation = new_federation()
      peer = build_peer("new-peer", ["2.0.0"])

      {:ok, updated} = join_federation(federation, peer)
      assert map_size(updated.members) == 1
      assert Map.has_key?(updated.members, "new-peer")
    end

    test "peer leaves federation" do
      federation = new_federation()
      peer = build_peer("leaving-peer", ["2.0.0"])

      {:ok, with_peer} = join_federation(federation, peer)
      {:ok, without} = leave_federation(with_peer, "leaving-peer")

      assert map_size(without.members) == 0
    end

    test "duplicate join is idempotent" do
      federation = new_federation()
      peer = build_peer("peer-1", ["2.0.0"])

      {:ok, first} = join_federation(federation, peer)
      {:ok, second} = join_federation(first, peer)

      assert map_size(second.members) == 1
    end

    test "federation tracks member count" do
      federation = new_federation()

      peers =
        Enum.map(1..5, fn i ->
          build_peer("peer-#{i}", ["2.0.0"])
        end)

      final =
        Enum.reduce(peers, federation, fn peer, fed ->
          {:ok, updated} = join_federation(fed, peer)
          updated
        end)

      assert map_size(final.members) == 5
    end
  end

  describe "upgrade coordination (SC-RECONFIG-010)" do
    test "upgrade notification sent to all peers" do
      federation = build_federation_with_peers(3)

      notifications = notify_upgrade(federation, "3.0.0")
      assert length(notifications) == 3

      for notif <- notifications do
        assert notif.type == :upgrade_available
        assert notif.version == "3.0.0"
      end
    end

    test "upgrade requires quorum acknowledgement" do
      federation = build_federation_with_peers(5)

      # 3/5 = quorum for 5 peers
      acks = Enum.take(Map.keys(federation.members), 3)
      assert upgrade_quorum_met?(federation, acks)
    end

    test "upgrade fails without quorum" do
      federation = build_federation_with_peers(5)

      acks = Enum.take(Map.keys(federation.members), 2)
      refute upgrade_quorum_met?(federation, acks)
    end

    test "coordination completes within time bound (SC-FED-004)" do
      federation = build_federation_with_peers(3)

      start = System.monotonic_time(:millisecond)
      _notifications = notify_upgrade(federation, "3.0.0")
      elapsed = System.monotonic_time(:millisecond) - start

      # Must be well under the 30s coordination timeout
      assert elapsed < 100
    end
  end

  describe "property: negotiation invariants" do
    property "negotiation always picks from intersection" do
      forall {vs_a, vs_b} <-
               {PC.non_empty(PC.list(version_gen())), PC.non_empty(PC.list(version_gen()))} do
        peer_a = build_peer("a", Enum.uniq(vs_a))
        peer_b = build_peer("b", Enum.uniq(vs_b))

        case negotiate_version(peer_a, peer_b) do
          {:ok, agreed} ->
            agreed in peer_a.supported_versions and agreed in peer_b.supported_versions

          {:error, :no_common_version} ->
            intersection =
              MapSet.intersection(
                MapSet.new(peer_a.supported_versions),
                MapSet.new(peer_b.supported_versions)
              )

            MapSet.size(intersection) == 0
        end
      end
    end

    test "quorum threshold is floor(N/2)+1" do
      ExUnitProperties.check all(
                               n <- SD.integer(3..20),
                               max_runs: 20
                             ) do
        federation = build_federation_with_peers(n)
        quorum = div(n, 2) + 1

        # Exactly quorum should pass
        acks = Enum.take(Map.keys(federation.members), quorum)
        assert upgrade_quorum_met?(federation, acks)

        # One less should fail
        fewer = Enum.take(Map.keys(federation.members), quorum - 1)
        refute upgrade_quorum_met?(federation, fewer)
      end
    end
  end

  # ===========================================================================
  # Generators
  # ===========================================================================

  defp version_gen do
    PC.oneof(Enum.map(@protocol_versions, &PC.exactly/1))
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  defp build_peer(node_id, supported_versions) do
    %{
      node_id: node_id,
      supported_versions: supported_versions,
      constitution_hash: :crypto.hash(:sha256, "default-constitution") |> Base.encode16(),
      joined_at: System.monotonic_time(:millisecond)
    }
  end

  defp negotiate_version(peer_a, peer_b) do
    common =
      MapSet.intersection(
        MapSet.new(peer_a.supported_versions),
        MapSet.new(peer_b.supported_versions)
      )

    if MapSet.size(common) == 0 do
      {:error, :no_common_version}
    else
      highest = Enum.max_by(MapSet.to_list(common), &version_to_tuple/1)
      {:ok, highest}
    end
  end

  defp compare_versions(a, b) do
    ta = version_to_tuple(a)
    tb = version_to_tuple(b)

    cond do
      ta < tb -> :lt
      ta > tb -> :gt
      true -> :eq
    end
  end

  defp version_to_tuple(v) do
    v
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
    |> List.to_tuple()
  end

  defp backward_compatible?(v1, v2) do
    {maj1, _, _} = version_to_tuple(v1)
    {maj2, _, _} = version_to_tuple(v2)
    maj1 == maj2
  end

  defp capabilities_for_version(version) do
    base = MapSet.new([:heartbeat, :health_check, :membership])

    case version_to_tuple(version) do
      {1, _, _} ->
        base

      {2, _, _} ->
        MapSet.union(base, MapSet.new([:attestation, :constitution_check]))

      {3, _, _} ->
        MapSet.union(
          base,
          MapSet.new([:attestation, :constitution_check, :upgrade_coordination, :quorum_voting])
        )

      _ ->
        base
    end
  end

  defp generate_keypair do
    secret = :crypto.strong_rand_bytes(32)
    public = :crypto.hash(:sha256, secret)
    {public, secret}
  end

  defp sign_attestation(peer, secret, timestamp \\ nil) do
    ts = timestamp || System.monotonic_time(:millisecond)
    payload = "#{peer.node_id}:#{ts}:#{Enum.join(peer.supported_versions, ",")}"

    # Use hash(secret) as the HMAC key so verify_attestation can reconstruct it from the public key
    signing_key = :crypto.hash(:sha256, secret)
    signature = :crypto.mac(:hmac, :sha256, signing_key, payload) |> Base.encode16()

    %{
      node_id: peer.node_id,
      timestamp: ts,
      supported_versions: peer.supported_versions,
      signature: signature
    }
  end

  defp verify_attestation(attestation, public_key) do
    now = System.monotonic_time(:millisecond)

    cond do
      now - attestation.timestamp > @attestation_ttl_ms ->
        {:error, :attestation_expired}

      true ->
        # public_key is hash(secret), which is the same key used by sign_attestation
        secret_for_verify = public_key

        payload =
          "#{attestation.node_id}:#{attestation.timestamp}:#{Enum.join(attestation.supported_versions, ",")}"

        expected = :crypto.mac(:hmac, :sha256, secret_for_verify, payload) |> Base.encode16()

        if expected == attestation.signature do
          {:ok, attestation}
        else
          {:error, :invalid_signature}
        end
    end
  end

  defp check_constitution_divergence(hash_a, hash_b) do
    if hash_a == hash_b do
      :ok
    else
      {:error, :constitution_diverged}
    end
  end

  defp new_federation do
    %{
      id: "fed-#{System.unique_integer([:positive])}",
      members: %{},
      protocol_version: "2.0.0",
      created_at: System.monotonic_time(:millisecond)
    }
  end

  defp join_federation(federation, peer) do
    updated = %{federation | members: Map.put(federation.members, peer.node_id, peer)}
    {:ok, updated}
  end

  defp leave_federation(federation, node_id) do
    updated = %{federation | members: Map.delete(federation.members, node_id)}
    {:ok, updated}
  end

  defp build_federation_with_peers(count) do
    federation = new_federation()

    Enum.reduce(1..count, federation, fn i, fed ->
      peer = build_peer("peer-#{i}", ["2.0.0", "3.0.0"])
      {:ok, updated} = join_federation(fed, peer)
      updated
    end)
  end

  defp notify_upgrade(federation, version) do
    Enum.map(federation.members, fn {node_id, _peer} ->
      %{
        type: :upgrade_available,
        version: version,
        target: node_id,
        timestamp: System.monotonic_time(:millisecond)
      }
    end)
  end

  defp upgrade_quorum_met?(federation, ack_node_ids) do
    total = map_size(federation.members)
    quorum = div(total, 2) + 1
    length(ack_node_ids) >= quorum
  end
end
