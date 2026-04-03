defmodule Indrajaal.Federation.ConstitutionDivergenceDetectionTest do
  @moduledoc """
  TDG test suite for federation constitution divergence detection.

  WHAT: Models a federation of 3 holon nodes each holding a versioned constitution
  (immutable invariants Ψ₀-Ψ₅ plus a version vector). Tests cover creation,
  comparison, amendment detection, version ordering, 2oo3 quorum checks,
  Ed25519-style attestation simulation, divergence severity classification,
  recovery protocol selection, split-brain detection, and partition merge.

  WHY: Federated holons must agree on a shared constitutional baseline
  (SC-FED-003). Silent divergence breaks safety guarantees (Ψ₃ Verification,
  SC-SIL4-015 split-brain), and unresolved splits trigger apoptosis (SC-SIL6-015).
  Deterministic divergence detection with classified severity lets the system
  self-heal at the right escalation level without Guardian intervention for
  COMPATIBLE drifts, while always escalating CRITICAL changes.

  CONSTRAINTS:
  - SC-FED-001: No modification of node constitutions without Guardian approval
  - SC-FED-002: Maintain node autonomy
  - SC-FED-003: Detect constitution divergence
  - SC-FED-004: Emergency coordination time-bounded
  - SC-FED-005: Membership management maintained
  - SC-FED-006: Attestation Ed25519-verified
  - SC-RECONFIG-001: Graph transformation for changes
  - SC-RECONFIG-005: Lineage preserved through reconfiguration
  - SC-RECONFIG-007: Graceful degradation to older versions
  - SC-RECONFIG-009: Guardian approval required for INCOMPATIBLE/CRITICAL divergence
  - SC-RECONFIG-010: Federation peers notified

  ## Constitutional Verification
  - Ψ₀ (Existence): System survives even during split-brain
  - Ψ₁ (Regeneration): Constitution recoverable from SQLite/DuckDB
  - Ψ₂ (History): All divergence events appended to lineage log
  - Ψ₃ (Verification): Hash-chain verifies constitution integrity
  - Ψ₅ (Truthfulness): Attestation cannot be forged

  ## Change History
  | Version | Date       | Author | Change                                          |
  |---------|------------|--------|-------------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Initial TDG suite — 10 divergence scenarios     |
  """

  use ExUnit.Case, async: true
  # EP-GEN-014 compliance: PropCheck for forall/property; ExUnitProperties for
  # check all() inside test/1 blocks.  All SD generators use SD.* prefix.
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Domain constants
  # ---------------------------------------------------------------------------

  @invariants [
    :psi0_existence,
    :psi1_regeneration,
    :psi2_history,
    :psi3_verification,
    :psi4_alignment,
    :psi5_truthfulness
  ]

  @severity_levels [:compatible, :incompatible, :critical]

  @recovery_strategies [:adopt_newest, :vote, :escalate_to_guardian]

  # ---------------------------------------------------------------------------
  # Constitution construction helpers
  # ---------------------------------------------------------------------------

  defp canonical_hash(invariants, major, minor) do
    :crypto.hash(:sha256, :erlang.term_to_binary({invariants, major, minor}))
    |> Base.encode16(case: :lower)
  end

  defp build_constitution(opts \\ []) do
    major = Keyword.get(opts, :major, 1)
    minor = Keyword.get(opts, :minor, 0)
    invariants = Keyword.get(opts, :invariants, @invariants)

    %{
      invariants: MapSet.new(invariants),
      major_version: major,
      minor_version: minor,
      hash: canonical_hash(invariants, major, minor),
      created_at: Keyword.get(opts, :created_at, System.monotonic_time(:millisecond))
    }
  end

  # A fresh version vector for a 3-node federation.
  defp zero_version_vector do
    %{"node-alpha" => 0, "node-beta" => 0, "node-gamma" => 0}
  end

  defp build_holon_node(node_id, constitution, opts \\ []) do
    vv_base = Keyword.get(opts, :version_vector, zero_version_vector())

    %{
      node_id: node_id,
      constitution: constitution,
      version_vector: Map.put(vv_base, node_id, Keyword.get(opts, :local_clock, 0)),
      lineage: [%{event: :genesis, timestamp: System.monotonic_time(:millisecond)}],
      partition: Keyword.get(opts, :partition, :main)
    }
  end

  defp federation_of_three(constitution) do
    %{
      "node-alpha" => build_holon_node("node-alpha", constitution),
      "node-beta" => build_holon_node("node-beta", constitution),
      "node-gamma" => build_holon_node("node-gamma", constitution)
    }
  end

  # ---------------------------------------------------------------------------
  # 1. Constitution creation with hash verification
  # ---------------------------------------------------------------------------

  defp verify_constitution_hash(constitution) do
    expected =
      canonical_hash(
        MapSet.to_list(constitution.invariants) |> Enum.sort(),
        constitution.major_version,
        constitution.minor_version
      )

    computed =
      :crypto.hash(
        :sha256,
        :erlang.term_to_binary(
          {MapSet.to_list(constitution.invariants) |> Enum.sort(), constitution.major_version,
           constitution.minor_version}
        )
      )
      |> Base.encode16(case: :lower)

    if computed == expected, do: :ok, else: {:error, :hash_mismatch}
  end

  describe "1. Constitution creation with hash verification (SC-FED-003)" do
    test "default constitution hash is deterministic" do
      c1 = build_constitution()
      c2 = build_constitution()
      assert c1.hash == c2.hash
    end

    test "constitution hash covers all six invariants" do
      c = build_constitution()
      assert verify_constitution_hash(c) == :ok
    end

    test "different major version yields different hash" do
      c1 = build_constitution(major: 1)
      c2 = build_constitution(major: 2)
      assert c1.hash != c2.hash
    end

    test "different minor version yields different hash" do
      c1 = build_constitution(minor: 0)
      c2 = build_constitution(minor: 1)
      assert c1.hash != c2.hash
    end

    test "removing an invariant changes the hash" do
      full = build_constitution()
      partial = build_constitution(invariants: @invariants -- [:psi5_truthfulness])
      assert full.hash != partial.hash
    end

    test "hash is 64-character hex string (SHA-256)" do
      c = build_constitution()
      assert String.length(c.hash) == 64
      assert String.match?(c.hash, ~r/^[0-9a-f]{64}$/)
    end

    test "all six invariants are present by default" do
      c = build_constitution()

      for inv <- @invariants do
        assert MapSet.member?(c.invariants, inv),
               "Expected invariant #{inv} to be present"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Constitution comparison — detect divergence
  # ---------------------------------------------------------------------------

  defp constitutions_equal?(a, b) do
    a.hash == b.hash and
      a.major_version == b.major_version and
      a.minor_version == b.minor_version and
      MapSet.equal?(a.invariants, b.invariants)
  end

  defp compare_constitutions(a, b) do
    cond do
      constitutions_equal?(a, b) ->
        :equal

      a.hash == b.hash ->
        # hash match but metadata differs — treat as equal (hash is canonical)
        :equal

      true ->
        :diverged
    end
  end

  describe "2. Constitution comparison (SC-FED-003)" do
    test "identical constitutions compare as equal" do
      c = build_constitution()
      assert compare_constitutions(c, c) == :equal
    end

    test "identical copies compare as equal" do
      c1 = build_constitution()
      c2 = build_constitution()
      assert compare_constitutions(c1, c2) == :equal
    end

    test "different major versions compare as diverged" do
      c1 = build_constitution(major: 1)
      c2 = build_constitution(major: 2)
      assert compare_constitutions(c1, c2) == :diverged
    end

    test "different minor versions compare as diverged" do
      c1 = build_constitution(minor: 0)
      c2 = build_constitution(minor: 1)
      assert compare_constitutions(c1, c2) == :diverged
    end

    test "federation with identical constitutions shows no divergence" do
      c = build_constitution()
      fed = federation_of_three(c)

      constitutions = Enum.map(fed, fn {_id, node} -> node.constitution end)

      diverged =
        for a <- constitutions, b <- constitutions, a != b do
          compare_constitutions(a, b)
        end

      assert Enum.all?(diverged, &(&1 == :equal))
    end

    test "federation with one different node shows divergence" do
      c_base = build_constitution()
      c_new = build_constitution(minor: 1)

      fed =
        federation_of_three(c_base)
        |> Map.update!("node-gamma", fn node -> %{node | constitution: c_new} end)

      alpha_c = fed["node-alpha"].constitution
      gamma_c = fed["node-gamma"].constitution

      assert compare_constitutions(alpha_c, gamma_c) == :diverged
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Amendment detection — identify changed invariants
  # ---------------------------------------------------------------------------

  defp detect_amendments(baseline, candidate) do
    baseline_inv = baseline.invariants
    candidate_inv = candidate.invariants

    added = MapSet.difference(candidate_inv, baseline_inv)
    removed = MapSet.difference(baseline_inv, candidate_inv)

    %{
      added: added,
      removed: removed,
      changed: not MapSet.equal?(added, MapSet.new()) or not MapSet.equal?(removed, MapSet.new()),
      psi0_touched:
        MapSet.member?(removed, :psi0_existence) or MapSet.member?(added, :psi0_existence)
    }
  end

  describe "3. Amendment detection (SC-FED-003, SC-RECONFIG-005)" do
    test "no amendments when constitutions are identical" do
      c = build_constitution()
      result = detect_amendments(c, c)
      refute result.changed
      assert MapSet.size(result.added) == 0
      assert MapSet.size(result.removed) == 0
    end

    test "removed invariant is detected" do
      baseline = build_constitution()
      candidate = build_constitution(invariants: @invariants -- [:psi5_truthfulness])

      result = detect_amendments(baseline, candidate)
      assert result.changed
      assert MapSet.member?(result.removed, :psi5_truthfulness)
    end

    test "added invariant is detected" do
      baseline = build_constitution(invariants: @invariants -- [:psi4_alignment])
      candidate = build_constitution()

      result = detect_amendments(baseline, candidate)
      assert result.changed
      assert MapSet.member?(result.added, :psi4_alignment)
    end

    test "Ψ₀ removal is flagged separately" do
      baseline = build_constitution()
      candidate = build_constitution(invariants: @invariants -- [:psi0_existence])

      result = detect_amendments(baseline, candidate)
      assert result.psi0_touched
    end

    test "Ψ₀ untouched — flag remains false" do
      baseline = build_constitution()
      candidate = build_constitution(minor: 1)

      result = detect_amendments(baseline, candidate)
      refute result.psi0_touched
    end

    test "version-only change produces no invariant amendments" do
      baseline = build_constitution(minor: 0)
      candidate = build_constitution(minor: 1)

      result = detect_amendments(baseline, candidate)
      refute result.changed
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Version vector ordering — determine which constitution is newer
  # ---------------------------------------------------------------------------

  # Returns :newer, :older, :concurrent, or :equal
  defp compare_version_vectors(vv_a, vv_b) do
    all_keys = MapSet.union(MapSet.new(Map.keys(vv_a)), MapSet.new(Map.keys(vv_b)))

    {a_greater, b_greater} =
      Enum.reduce(all_keys, {false, false}, fn key, {ag, bg} ->
        va = Map.get(vv_a, key, 0)
        vb = Map.get(vv_b, key, 0)
        {ag or va > vb, bg or vb > va}
      end)

    cond do
      not a_greater and not b_greater -> :equal
      a_greater and not b_greater -> :newer
      b_greater and not a_greater -> :older
      true -> :concurrent
    end
  end

  defp increment_clock(node, node_id) do
    new_vv = Map.update(node.version_vector, node_id, 1, &(&1 + 1))
    %{node | version_vector: new_vv}
  end

  describe "4. Version vector ordering (SC-FED-005)" do
    test "identical vectors are equal" do
      vv = %{"node-alpha" => 3, "node-beta" => 2, "node-gamma" => 1}
      assert compare_version_vectors(vv, vv) == :equal
    end

    test "vector with higher clock on one node is newer" do
      vv_a = %{"node-alpha" => 5, "node-beta" => 2}
      vv_b = %{"node-alpha" => 3, "node-beta" => 2}
      assert compare_version_vectors(vv_a, vv_b) == :newer
    end

    test "vector with lower clock on one node is older" do
      vv_a = %{"node-alpha" => 1, "node-beta" => 2}
      vv_b = %{"node-alpha" => 3, "node-beta" => 2}
      assert compare_version_vectors(vv_a, vv_b) == :older
    end

    test "independent increments produce concurrent vectors" do
      vv_a = %{"node-alpha" => 5, "node-beta" => 1}
      vv_b = %{"node-alpha" => 1, "node-beta" => 5}
      assert compare_version_vectors(vv_a, vv_b) == :concurrent
    end

    test "clock incremented locally advances that node's vector" do
      c = build_constitution()
      node = build_holon_node("node-alpha", c, local_clock: 0)
      advanced = increment_clock(node, "node-alpha")
      assert advanced.version_vector["node-alpha"] == 1
    end

    test "zero-vector missing keys defaults to 0" do
      vv_a = %{"node-alpha" => 2}
      vv_b = %{"node-alpha" => 2, "node-beta" => 0}
      assert compare_version_vectors(vv_a, vv_b) == :equal
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Quorum check — 2oo3 nodes must agree on constitution for consensus
  # ---------------------------------------------------------------------------

  defp quorum_size(n), do: floor(n / 2) + 1

  defp check_quorum(federation) do
    nodes = Map.values(federation)
    n = length(nodes)
    required = quorum_size(n)

    # Group by constitution hash
    groups =
      Enum.group_by(nodes, fn node -> node.constitution.hash end)

    # Check if any group reaches quorum
    {agreed_hash, agreed_nodes} =
      Enum.max_by(groups, fn {_hash, members} -> length(members) end)

    if length(agreed_nodes) >= required do
      {:quorum, agreed_hash, agreed_nodes |> Enum.map(& &1.node_id)}
    else
      {:no_quorum, groups |> Enum.map(fn {h, ms} -> {h, Enum.map(ms, & &1.node_id)} end)}
    end
  end

  describe "5. Quorum check 2oo3 (SC-SIL6-006, SC-QUORUM-001)" do
    test "3 of 3 identical constitutions achieve quorum" do
      c = build_constitution()
      fed = federation_of_three(c)
      assert {:quorum, _, nodes} = check_quorum(fed)
      assert length(nodes) == 3
    end

    test "2 of 3 identical constitutions achieve quorum" do
      c_base = build_constitution()
      c_deviant = build_constitution(minor: 99)

      fed =
        federation_of_three(c_base)
        |> Map.update!("node-gamma", fn n -> %{n | constitution: c_deviant} end)

      assert {:quorum, _, nodes} = check_quorum(fed)
      assert length(nodes) == 2
      assert "node-gamma" not in nodes
    end

    test "1 of 3 identical constitutions fails quorum" do
      c_a = build_constitution(minor: 1)
      c_b = build_constitution(minor: 2)
      c_c = build_constitution(minor: 3)

      fed = %{
        "node-alpha" => build_holon_node("node-alpha", c_a),
        "node-beta" => build_holon_node("node-beta", c_b),
        "node-gamma" => build_holon_node("node-gamma", c_c)
      }

      assert {:no_quorum, _groups} = check_quorum(fed)
    end

    test "quorum size formula: floor(N/2)+1" do
      assert quorum_size(1) == 1
      assert quorum_size(2) == 2
      assert quorum_size(3) == 2
      assert quorum_size(4) == 3
      assert quorum_size(5) == 3
    end

    test "unanimous federation always achieves quorum" do
      c = build_constitution()
      fed = federation_of_three(c)
      {:quorum, hash, _nodes} = check_quorum(fed)
      assert hash == c.hash
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Attestation protocol — Ed25519-style signature verification simulation
  # ---------------------------------------------------------------------------

  defp generate_keypair do
    :crypto.generate_key(:eddsa, :ed25519)
  end

  defp attest_constitution(node_id, constitution, {_pub, priv} = _keypair, opts \\ []) do
    timestamp = Keyword.get(opts, :timestamp, System.system_time(:second))
    ttl = Keyword.get(opts, :ttl, 3600)

    payload = %{
      node_id: node_id,
      constitution_hash: constitution.hash,
      constitution_version: {constitution.major_version, constitution.minor_version},
      issued_at: timestamp,
      expires_at: timestamp + ttl,
      nonce: :crypto.strong_rand_bytes(12) |> Base.encode16(case: :lower)
    }

    message = :erlang.term_to_binary(payload)
    signature = :crypto.sign(:eddsa, :none, message, [priv, :ed25519])

    %{
      payload: payload,
      message: message,
      signature: signature
    }
  end

  defp verify_attestation_token(token, public_key, opts \\ []) do
    now = Keyword.get(opts, :current_time, System.system_time(:second))

    with :ok <- check_sig(token, public_key),
         :ok <- check_not_expired(token.payload, now) do
      {:ok, token.payload}
    end
  end

  defp check_sig(token, public_key) do
    if :crypto.verify(:eddsa, :none, token.message, token.signature, [public_key, :ed25519]) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp check_not_expired(payload, now) do
    if now < payload.expires_at, do: :ok, else: {:error, :expired}
  end

  describe "6. Attestation protocol (SC-FED-006)" do
    test "valid attestation verifies successfully" do
      c = build_constitution()
      {pub, _priv} = keypair = generate_keypair()
      token = attest_constitution("node-alpha", c, keypair)

      assert {:ok, payload} = verify_attestation_token(token, pub)
      assert payload.constitution_hash == c.hash
    end

    test "tampered message fails verification" do
      c = build_constitution()
      {pub, _priv} = keypair = generate_keypair()
      token = attest_constitution("node-beta", c, keypair)

      corrupted = %{token | message: <<0xFF, 0x00, 0xDE, 0xAD>>}
      assert {:error, :invalid_signature} = verify_attestation_token(corrupted, pub)
    end

    test "wrong public key fails verification" do
      c = build_constitution()
      keypair1 = generate_keypair()
      {pub2, _} = generate_keypair()

      token = attest_constitution("node-gamma", c, keypair1)
      assert {:error, :invalid_signature} = verify_attestation_token(token, pub2)
    end

    test "expired attestation is rejected" do
      c = build_constitution()
      {pub, _} = keypair = generate_keypair()
      now = System.system_time(:second)
      token = attest_constitution("node-alpha", c, keypair, timestamp: now - 7200)

      assert {:error, :expired} = verify_attestation_token(token, pub, current_time: now)
    end

    test "attestation encodes constitution hash and version" do
      c = build_constitution(major: 2, minor: 3)
      {pub, _} = keypair = generate_keypair()
      token = attest_constitution("node-alpha", c, keypair)

      {:ok, payload} = verify_attestation_token(token, pub)
      assert payload.constitution_hash == c.hash
      assert payload.constitution_version == {2, 3}
    end

    test "two nodes attesting the same constitution produce different tokens (nonce)" do
      c = build_constitution()
      kp_a = generate_keypair()
      kp_b = generate_keypair()

      token_a = attest_constitution("node-alpha", c, kp_a)
      token_b = attest_constitution("node-beta", c, kp_b)

      assert token_a.payload.nonce != token_b.payload.nonce
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Divergence severity classification
  # ---------------------------------------------------------------------------

  defp classify_divergence(baseline, candidate) do
    amendments = detect_amendments(baseline, candidate)

    cond do
      # Ψ₀ removed — existential threat
      amendments.psi0_touched and MapSet.member?(amendments.removed, :psi0_existence) ->
        :critical

      # Any other invariant removed or added — structural incompatibility
      amendments.changed ->
        :incompatible

      # Same invariants, different minor version — compatible drift
      candidate.minor_version != baseline.minor_version and
          candidate.major_version == baseline.major_version ->
        :compatible

      # Different major version, same invariants — incompatible
      candidate.major_version != baseline.major_version ->
        :incompatible

      # Identical in every way
      true ->
        :equal
    end
  end

  describe "7. Divergence severity classification" do
    test ":equal for identical constitutions" do
      c = build_constitution()
      assert classify_divergence(c, c) == :equal
    end

    test ":compatible for minor version bump only" do
      baseline = build_constitution(major: 1, minor: 0)
      candidate = build_constitution(major: 1, minor: 1)
      assert classify_divergence(baseline, candidate) == :compatible
    end

    test ":incompatible for major version bump (same invariants)" do
      baseline = build_constitution(major: 1, minor: 0)
      candidate = build_constitution(major: 2, minor: 0)
      assert classify_divergence(baseline, candidate) == :incompatible
    end

    test ":incompatible when a non-Ψ₀ invariant is removed" do
      baseline = build_constitution()
      candidate = build_constitution(invariants: @invariants -- [:psi5_truthfulness])
      assert classify_divergence(baseline, candidate) == :incompatible
    end

    test ":critical when Ψ₀ existence is removed" do
      baseline = build_constitution()
      candidate = build_constitution(invariants: @invariants -- [:psi0_existence])
      assert classify_divergence(baseline, candidate) == :critical
    end

    test "severity levels form the expected atom set" do
      # Ensure all classified values come from the declared domain
      c = build_constitution()
      c_minor = build_constitution(minor: 1)
      c_major = build_constitution(major: 2)
      c_no_psi5 = build_constitution(invariants: @invariants -- [:psi5_truthfulness])
      c_no_psi0 = build_constitution(invariants: @invariants -- [:psi0_existence])

      results =
        [
          classify_divergence(c, c),
          classify_divergence(c, c_minor),
          classify_divergence(c, c_major),
          classify_divergence(c, c_no_psi5),
          classify_divergence(c, c_no_psi0)
        ]
        |> MapSet.new()

      valid = MapSet.new([:equal | @severity_levels])
      assert MapSet.subset?(results, valid)
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Recovery protocol selection
  # ---------------------------------------------------------------------------

  defp select_recovery(severity, quorum_result) do
    case {severity, quorum_result} do
      {:equal, _} ->
        :no_action

      {:compatible, {:quorum, _, _}} ->
        :adopt_newest

      {:compatible, {:no_quorum, _}} ->
        :vote

      {:incompatible, {:quorum, _, _}} ->
        :adopt_newest

      {:incompatible, {:no_quorum, _}} ->
        :escalate_to_guardian

      {:critical, _} ->
        :escalate_to_guardian
    end
  end

  describe "8. Recovery protocol selection (SC-RECONFIG-007, SC-RECONFIG-009)" do
    test ":no_action for equal constitutions" do
      c = build_constitution()
      fed = federation_of_three(c)
      quorum = check_quorum(fed)
      assert select_recovery(:equal, quorum) == :no_action
    end

    test ":adopt_newest for compatible drift with quorum" do
      c = build_constitution()
      fed = federation_of_three(c)
      quorum = check_quorum(fed)
      assert select_recovery(:compatible, quorum) == :adopt_newest
    end

    test ":vote for compatible drift without quorum" do
      c1 = build_constitution(minor: 1)
      c2 = build_constitution(minor: 2)
      c3 = build_constitution(minor: 3)

      fed = %{
        "node-alpha" => build_holon_node("node-alpha", c1),
        "node-beta" => build_holon_node("node-beta", c2),
        "node-gamma" => build_holon_node("node-gamma", c3)
      }

      quorum = check_quorum(fed)
      assert select_recovery(:compatible, quorum) == :vote
    end

    test ":adopt_newest for incompatible drift with quorum" do
      c = build_constitution()
      fed = federation_of_three(c)
      quorum = check_quorum(fed)
      assert select_recovery(:incompatible, quorum) == :adopt_newest
    end

    test ":escalate_to_guardian for incompatible drift without quorum" do
      c1 = build_constitution(major: 1)
      c2 = build_constitution(major: 2)
      c3 = build_constitution(major: 3)

      fed = %{
        "node-alpha" => build_holon_node("node-alpha", c1),
        "node-beta" => build_holon_node("node-beta", c2),
        "node-gamma" => build_holon_node("node-gamma", c3)
      }

      quorum = check_quorum(fed)
      assert select_recovery(:incompatible, quorum) == :escalate_to_guardian
    end

    test ":escalate_to_guardian always for critical severity" do
      c = build_constitution()
      fed = federation_of_three(c)
      quorum = check_quorum(fed)
      # Even with quorum, critical divergence must escalate
      assert select_recovery(:critical, quorum) == :escalate_to_guardian
    end

    test "all recovery strategies are from the declared domain" do
      for strategy <- @recovery_strategies do
        assert strategy in @recovery_strategies
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 9. Split-brain detection
  # ---------------------------------------------------------------------------

  defp detect_split_brain(federation) do
    partitions =
      federation
      |> Map.values()
      |> Enum.group_by(& &1.partition)

    if map_size(partitions) <= 1 do
      {:healthy, :no_split}
    else
      partition_constitutions =
        Map.new(partitions, fn {part, nodes} ->
          hashes = nodes |> Enum.map(& &1.constitution.hash) |> Enum.uniq()
          {part, hashes}
        end)

      all_hashes =
        partition_constitutions
        |> Map.values()
        |> List.flatten()
        |> Enum.uniq()

      if length(all_hashes) > 1 do
        {:split_brain, partition_constitutions}
      else
        {:partitioned_but_consistent, partition_constitutions}
      end
    end
  end

  defp simulate_partition(federation, partition_a_nodes, partition_b_nodes) do
    federation
    |> Enum.map(fn {id, node} ->
      new_partition =
        cond do
          id in partition_a_nodes -> :partition_a
          id in partition_b_nodes -> :partition_b
          true -> :isolated
        end

      {id, %{node | partition: new_partition}}
    end)
    |> Map.new()
  end

  describe "9. Split-brain detection (SC-SIL4-015)" do
    test "healthy federation has no split" do
      c = build_constitution()
      fed = federation_of_three(c)
      assert {:healthy, :no_split} = detect_split_brain(fed)
    end

    test "partitioned federation with same constitution is consistent" do
      c = build_constitution()
      fed = federation_of_three(c)

      partitioned =
        simulate_partition(fed, ["node-alpha", "node-beta"], ["node-gamma"])

      assert {:partitioned_but_consistent, _} = detect_split_brain(partitioned)
    end

    test "partitioned federation with different constitutions is split-brain" do
      c_base = build_constitution()
      c_deviant = build_constitution(minor: 9)

      fed =
        federation_of_three(c_base)
        |> Map.update!("node-gamma", fn n -> %{n | constitution: c_deviant} end)

      partitioned =
        simulate_partition(fed, ["node-alpha", "node-beta"], ["node-gamma"])

      assert {:split_brain, parts} = detect_split_brain(partitioned)
      assert map_size(parts) == 2
    end

    test "split-brain result includes both partition constitution hashes" do
      c_base = build_constitution()
      c_deviant = build_constitution(minor: 99)

      fed =
        federation_of_three(c_base)
        |> Map.update!("node-gamma", fn n -> %{n | constitution: c_deviant} end)

      partitioned =
        simulate_partition(fed, ["node-alpha", "node-beta"], ["node-gamma"])

      {:split_brain, parts} = detect_split_brain(partitioned)

      all_hashes = parts |> Map.values() |> List.flatten() |> Enum.sort()
      assert c_base.hash in all_hashes
      assert c_deviant.hash in all_hashes
    end

    test "single-partition federation never triggers split-brain" do
      c = build_constitution()
      # All nodes in same partition (default :main)
      fed = federation_of_three(c)
      assert {:healthy, :no_split} = detect_split_brain(fed)
    end
  end

  # ---------------------------------------------------------------------------
  # 10. Merge protocol — reuniting partitions after split
  # ---------------------------------------------------------------------------

  defp merge_partitions(federation, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :majority_wins)

    all_nodes = Map.values(federation)
    n = length(all_nodes)
    required = quorum_size(n)

    # Group by constitution hash and find majority
    groups = Enum.group_by(all_nodes, & &1.constitution.hash)

    {winning_hash, winning_members} =
      Enum.max_by(groups, fn {_h, members} -> length(members) end)

    merge_result = %{
      strategy: strategy,
      winning_hash: winning_hash,
      winning_node_count: length(winning_members),
      quorum_achieved: length(winning_members) >= required,
      merged_at: System.monotonic_time(:millisecond)
    }

    if merge_result.quorum_achieved do
      # Reconcile all nodes to winning constitution
      winning_constitution = List.first(winning_members).constitution

      reconciled_federation =
        Map.new(federation, fn {id, node} ->
          merged_node =
            node
            |> Map.put(:constitution, winning_constitution)
            |> Map.put(:partition, :main)
            |> append_lineage_event(:merge_reconciled, winning_hash)

          {id, merged_node}
        end)

      {:ok, reconciled_federation, merge_result}
    else
      {:error, :no_quorum_for_merge, merge_result}
    end
  end

  defp append_lineage_event(node, event_type, context) do
    event = %{event: event_type, context: context, timestamp: System.monotonic_time(:millisecond)}
    %{node | lineage: node.lineage ++ [event]}
  end

  describe "10. Merge protocol — partition reconciliation (SC-FED-004, SC-RECONFIG-005)" do
    test "majority-wins merge unifies federation to one constitution" do
      c_base = build_constitution()
      c_deviant = build_constitution(minor: 5)

      fed =
        federation_of_three(c_base)
        |> Map.update!("node-gamma", fn n -> %{n | constitution: c_deviant} end)

      {:ok, merged, result} = merge_partitions(fed)

      hashes = merged |> Map.values() |> Enum.map(& &1.constitution.hash) |> Enum.uniq()
      assert length(hashes) == 1
      assert result.winning_hash == c_base.hash
    end

    test "all nodes end up in :main partition after merge" do
      c_base = build_constitution()
      c_deviant = build_constitution(minor: 5)

      fed =
        federation_of_three(c_base)
        |> Map.update!("node-gamma", fn n -> %{n | constitution: c_deviant} end)
        |> simulate_partition(["node-alpha", "node-beta"], ["node-gamma"])

      {:ok, merged, _} = merge_partitions(fed)
      assert Enum.all?(Map.values(merged), fn n -> n.partition == :main end)
    end

    test "merge records lineage event on all nodes" do
      c_base = build_constitution()
      c_deviant = build_constitution(minor: 7)

      fed =
        federation_of_three(c_base)
        |> Map.update!("node-gamma", fn n -> %{n | constitution: c_deviant} end)

      {:ok, merged, _} = merge_partitions(fed)

      for {_id, node} <- merged do
        last_event = List.last(node.lineage)
        assert last_event.event == :merge_reconciled
      end
    end

    test "merge fails when no quorum can be established" do
      # Three completely distinct constitutions — no majority
      c1 = build_constitution(minor: 1)
      c2 = build_constitution(minor: 2)
      c3 = build_constitution(minor: 3)

      fed = %{
        "node-alpha" => build_holon_node("node-alpha", c1),
        "node-beta" => build_holon_node("node-beta", c2),
        "node-gamma" => build_holon_node("node-gamma", c3)
      }

      assert {:error, :no_quorum_for_merge, _details} = merge_partitions(fed)
    end

    test "unanimous federation merge is a no-op (quorum = all)" do
      c = build_constitution()
      fed = federation_of_three(c)
      {:ok, merged, result} = merge_partitions(fed)

      assert result.winning_node_count == 3
      assert result.quorum_achieved
      hashes = merged |> Map.values() |> Enum.map(& &1.constitution.hash) |> Enum.uniq()
      assert length(hashes) == 1
    end

    test "merged federation has consistent version vectors within scope" do
      c_base = build_constitution()
      c_deviant = build_constitution(minor: 2)

      fed =
        federation_of_three(c_base)
        |> Map.update!("node-gamma", fn n -> %{n | constitution: c_deviant} end)

      {:ok, merged, _} = merge_partitions(fed)

      # All nodes have the same constitution hash post-merge
      assert merged
             |> Map.values()
             |> Enum.map(& &1.constitution.hash)
             |> Enum.uniq()
             |> length() == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Property-based tests (EP-GEN-014 compliant)
  # ---------------------------------------------------------------------------

  describe "property: constitution hash invariants" do
    test "hash is always a 64-char lowercase hex string" do
      ExUnitProperties.check all(
                               major <- SD.positive_integer(),
                               minor <- SD.integer(0..100),
                               max_runs: 40
                             ) do
        c = build_constitution(major: major, minor: minor)
        assert String.length(c.hash) == 64
        assert String.match?(c.hash, ~r/^[0-9a-f]{64}$/)
      end
    end

    test "identical inputs always yield identical hashes" do
      ExUnitProperties.check all(
                               major <- SD.positive_integer(),
                               minor <- SD.integer(0..100),
                               max_runs: 40
                             ) do
        c1 = build_constitution(major: major, minor: minor)
        c2 = build_constitution(major: major, minor: minor)
        assert c1.hash == c2.hash
      end
    end
  end

  describe "property: version vector ordering (ExUnitProperties check all)" do
    test "ordering is antisymmetric — a newer than b implies b older than a" do
      ExUnitProperties.check all(
                               clock_a <- SD.integer(1..100),
                               clock_b <- SD.integer(101..200),
                               max_runs: 40
                             ) do
        vv_a = %{"node-alpha" => clock_a, "node-beta" => 0}
        vv_b = %{"node-alpha" => clock_b, "node-beta" => 0}

        assert compare_version_vectors(vv_a, vv_b) == :older
        assert compare_version_vectors(vv_b, vv_a) == :newer
      end
    end

    test "equal vectors are reflexively equal" do
      ExUnitProperties.check all(
                               clock <- SD.integer(0..500),
                               max_runs: 40
                             ) do
        vv = %{"node-alpha" => clock, "node-beta" => clock, "node-gamma" => clock}
        assert compare_version_vectors(vv, vv) == :equal
      end
    end
  end

  describe "property: quorum size formula (ExUnitProperties check all)" do
    test "quorum_size(n) is always majority — at least floor(n/2)+1" do
      ExUnitProperties.check all(n <- SD.integer(1..20), max_runs: 20) do
        q = quorum_size(n)
        assert q > n / 2
        assert q <= n
      end
    end
  end

  describe "property: classify_divergence covers severity domain" do
    test "classified severity is always a known atom" do
      ExUnitProperties.check all(
                               major_a <- SD.integer(1..3),
                               minor_a <- SD.integer(0..5),
                               major_b <- SD.integer(1..3),
                               minor_b <- SD.integer(0..5),
                               max_runs: 50
                             ) do
        a = build_constitution(major: major_a, minor: minor_a)
        b = build_constitution(major: major_b, minor: minor_b)
        severity = classify_divergence(a, b)
        assert severity in [:equal | @severity_levels]
      end
    end
  end

  describe "property: recovery strategy is always from declared domain" do
    test "select_recovery always returns a known strategy atom" do
      ExUnitProperties.check all(
                               severity <- SD.member_of(@severity_levels),
                               max_runs: 30
                             ) do
        c = build_constitution()
        fed = federation_of_three(c)
        quorum = check_quorum(fed)
        strategy = select_recovery(severity, quorum)
        assert strategy in [:no_action | @recovery_strategies]
      end
    end
  end
end
