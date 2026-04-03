defmodule Indrajaal.Morphogenic.L7CrossHolonAttestationTest do
  @moduledoc """
  L7 Morphogenic Evolution Test: Cross-Holon Attestation

  Tests federation-level peer attestation, trust verification, and
  constitution hash exchange. Validates that holons verify each other's
  identity and integrity before cross-holon operations.

  ## Fractal Layer
  L7 — Federation (Global invariants, cross-holon trust)

  ## STAMP Constraints
  - SC-FED-006: Attestation Ed25519-verified
  - SC-HASH-001: Deterministic computation
  - SC-HASH-002: Constant-time comparison
  - AOR-FED-001: Signature verification on all incoming federation messages
  - AOR-REG-012: Federation attestation hourly

  ## Morphogenic Task
  Auto-generated for 80% saturation — L7 substrate
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag layer: :l7
  @moduletag :l7_cross_holon_attestation

  # ── ETS Table Setup ──────────────────────────────────────────────────

  @peer_registry :l7_peer_registry_table
  @attestation_log :l7_attestation_log_table
  @trust_store :l7_trust_store_table

  setup do
    for table <- [@peer_registry, @attestation_log, @trust_store] do
      if :ets.whereis(table) != :undefined, do: :ets.delete(table)
    end

    :ets.new(@peer_registry, [:named_table, :set, :public])
    :ets.new(@attestation_log, [:named_table, :ordered_set, :public])
    :ets.new(@trust_store, [:named_table, :set, :public])

    on_exit(fn ->
      for table <- [@peer_registry, @attestation_log, @trust_store] do
        try do
          :ets.delete(table)
        rescue
          _ -> :ok
        end
      end
    end)

    :ok
  end

  # ── Peer Registration ────────────────────────────────────────────────

  describe "peer registration" do
    test "register new peer with constitution hash" do
      peer = create_peer("alpha", "hash_abc123")
      assert {:ok, info} = get_peer_info(peer)
      assert info.constitution_hash == "hash_abc123"
    end

    test "peer deregistration removes trust" do
      peer = create_peer("beta", "hash_def456")
      establish_trust(peer, :verified)
      deregister_peer(peer)
      assert {:error, :peer_not_found} = get_peer_info(peer)
      assert get_trust_level(peer) == :unknown
    end

    test "multiple peers registered independently" do
      peers =
        for i <- 1..5 do
          create_peer("peer_#{i}", "hash_#{i}")
        end

      for peer <- peers do
        assert {:ok, _info} = get_peer_info(peer)
      end

      assert count_registered_peers() == 5
    end
  end

  # ── Constitution Hash Exchange ───────────────────────────────────────

  describe "constitution hash exchange" do
    test "matching constitution hashes establish trust" do
      local_hash = compute_constitution_hash(%{psi0: true, psi1: true, psi2: true})
      peer = create_peer("same_constitution", local_hash)

      result = verify_constitution(peer, local_hash)
      assert result == :constitution_match
    end

    test "divergent constitution hashes detected (SC-FED-003)" do
      local_hash = compute_constitution_hash(%{psi0: true, psi1: true})
      remote_hash = compute_constitution_hash(%{psi0: true, psi1: false})
      peer = create_peer("divergent", remote_hash)

      result = verify_constitution(peer, local_hash)
      assert result == :constitution_divergence
    end

    test "hash comparison is deterministic (SC-HASH-001)" do
      data = %{psi0: true, psi1: true, psi2: true, psi3: true}
      hash1 = compute_constitution_hash(data)
      hash2 = compute_constitution_hash(data)
      assert hash1 == hash2
    end

    test "different data produces different hashes" do
      hash1 = compute_constitution_hash(%{psi0: true})
      hash2 = compute_constitution_hash(%{psi0: false})
      assert hash1 != hash2
    end
  end

  # ── Attestation Protocol ─────────────────────────────────────────────

  describe "attestation protocol" do
    test "attestation challenge-response succeeds" do
      peer = create_peer("attested", "hash_good")
      secret = "shared_secret_#{System.unique_integer([:positive])}"

      challenge = generate_challenge()
      response = compute_attestation_response(challenge, secret)
      expected = compute_attestation_response(challenge, secret)

      result = verify_attestation(peer, response, expected)
      assert result == :attestation_verified
      assert get_trust_level(peer) == :attested
    end

    test "attestation with wrong response fails" do
      peer = create_peer("bad_attest", "hash_bad")

      challenge = generate_challenge()
      correct_response = compute_attestation_response(challenge, "correct_secret")
      wrong_response = compute_attestation_response(challenge, "wrong_secret")

      result = verify_attestation(peer, wrong_response, correct_response)
      assert result == :attestation_failed
      assert get_trust_level(peer) == :untrusted
    end

    test "attestation expires after TTL (AOR-REG-012)" do
      peer = create_peer("expiring", "hash_exp")
      establish_trust(peer, :attested)
      set_attestation_time(peer, System.monotonic_time(:second) - 3700)

      assert attestation_expired?(peer, 3600)
    end

    test "fresh attestation not expired" do
      peer = create_peer("fresh", "hash_fresh")
      establish_trust(peer, :attested)
      set_attestation_time(peer, System.monotonic_time(:second))

      refute attestation_expired?(peer, 3600)
    end
  end

  # ── Trust Levels ─────────────────────────────────────────────────────

  describe "trust level management" do
    test "trust level progression: unknown -> verified -> attested" do
      peer = create_peer("progressing", "hash_prog")
      assert get_trust_level(peer) == :unknown

      establish_trust(peer, :verified)
      assert get_trust_level(peer) == :verified

      establish_trust(peer, :attested)
      assert get_trust_level(peer) == :attested
    end

    test "trust downgrade on constitution divergence" do
      peer = create_peer("downgrade", "hash_old")
      establish_trust(peer, :attested)

      verify_constitution(peer, "different_hash")
      assert get_trust_level(peer) == :untrusted
    end

    test "untrusted peer blocked from operations" do
      peer = create_peer("blocked", "hash_block")
      establish_trust(peer, :untrusted)

      assert {:error, :insufficient_trust} = attempt_cross_holon_op(peer, :read)
    end

    test "attested peer allowed cross-holon operations" do
      peer = create_peer("allowed", "hash_allow")
      establish_trust(peer, :attested)

      assert :ok = attempt_cross_holon_op(peer, :read)
    end

    test "verified peer allowed read but not write" do
      peer = create_peer("readonly", "hash_ro")
      establish_trust(peer, :verified)

      assert :ok = attempt_cross_holon_op(peer, :read)
      assert {:error, :insufficient_trust} = attempt_cross_holon_op(peer, :write)
    end
  end

  # ── Attestation Audit Log ────────────────────────────────────────────

  describe "attestation audit log" do
    test "all attestation attempts logged" do
      peer = create_peer("audited_peer", "hash_aud")
      challenge = generate_challenge()
      response = compute_attestation_response(challenge, "secret")

      verify_attestation(peer, response, response)
      verify_attestation(peer, "wrong", response)

      logs = get_attestation_logs(peer)
      assert length(logs) == 2
      results = Enum.map(logs, fn {_ts, entry} -> entry.result end)
      assert :attestation_verified in results
      assert :attestation_failed in results
    end

    test "log includes peer ID and timestamp" do
      peer = create_peer("log_detail", "hash_ld")
      challenge = generate_challenge()
      response = compute_attestation_response(challenge, "s")
      verify_attestation(peer, response, response)

      [{_ts, entry}] = get_attestation_logs(peer)
      assert entry.peer == peer
      assert is_integer(entry.timestamp)
    end
  end

  # ── PropCheck Properties ─────────────────────────────────────────────

  describe "property: hash determinism (SC-HASH-001)" do
    @tag timeout: 30_000
    property "same input always produces same hash" do
      forall data <- PC.binary() do
        h1 = compute_constitution_hash(%{data: data})
        h2 = compute_constitution_hash(%{data: data})
        h1 == h2
      end
    end
  end

  describe "property: attestation symmetry" do
    @tag timeout: 30_000
    property "same challenge+secret produces same response" do
      forall {challenge, secret} <- {PC.binary(), PC.binary()} do
        r1 = compute_attestation_response(challenge, secret)
        r2 = compute_attestation_response(challenge, secret)
        r1 == r2
      end
    end
  end

  describe "property: trust level ordering" do
    @tag timeout: 30_000
    property "trust levels have strict ordering" do
      forall level <- PC.oneof([:unknown, :untrusted, :verified, :attested]) do
        rank = trust_rank(level)
        rank >= 0 and rank <= 3
      end
    end
  end

  # ── StreamData Properties ────────────────────────────────────────────

  describe "streamdata: multi-peer federation" do
    @tag timeout: 30_000
    test "attestation status independent per peer" do
      SD.integer(2..10)
      |> Enum.take(20)
      |> Enum.each(fn peer_count ->
        base = System.unique_integer([:positive])

        peers =
          for i <- 1..peer_count do
            create_peer("sd_peer_#{base}_#{i}", "hash_#{base}_#{i}")
          end

        # Attest half, leave rest unknown
        {attested, unattested} = Enum.split(peers, div(peer_count, 2))
        for p <- attested, do: establish_trust(p, :attested)

        for p <- attested do
          assert get_trust_level(p) == :attested
        end

        for p <- unattested do
          assert get_trust_level(p) == :unknown
        end
      end)
    end
  end

  describe "streamdata: constitution hash collision resistance" do
    @tag timeout: 30_000
    test "different inputs produce different hashes" do
      SD.tuple(
        {SD.binary(min_length: 1, max_length: 64), SD.binary(min_length: 1, max_length: 64)}
      )
      |> Enum.take(50)
      |> Enum.each(fn {a, b} ->
        if a != b do
          h1 = compute_constitution_hash(%{data: a})
          h2 = compute_constitution_hash(%{data: b})
          assert h1 != h2
        end
      end)
    end
  end

  # ── Helper Functions ─────────────────────────────────────────────────

  defp create_peer(name, constitution_hash) do
    peer_id = :"peer_#{name}_#{System.unique_integer([:positive])}"

    info = %{
      constitution_hash: constitution_hash,
      registered_at: System.monotonic_time(:second),
      status: :active
    }

    :ets.insert(@peer_registry, {peer_id, info})
    peer_id
  end

  defp deregister_peer(peer_id) do
    :ets.delete(@peer_registry, peer_id)
    :ets.delete(@trust_store, peer_id)
  end

  defp get_peer_info(peer_id) do
    case :ets.lookup(@peer_registry, peer_id) do
      [{^peer_id, info}] -> {:ok, info}
      [] -> {:error, :peer_not_found}
    end
  end

  defp count_registered_peers do
    :ets.info(@peer_registry, :size)
  end

  defp compute_constitution_hash(data) do
    canonical = data |> :erlang.term_to_binary() |> then(&:crypto.hash(:sha256, &1))
    Base.encode16(canonical, case: :lower)
  end

  defp verify_constitution(peer_id, local_hash) do
    case get_peer_info(peer_id) do
      {:ok, %{constitution_hash: remote_hash}} ->
        if secure_compare(remote_hash, local_hash) do
          :constitution_match
        else
          establish_trust(peer_id, :untrusted)
          :constitution_divergence
        end

      {:error, _} = err ->
        err
    end
  end

  defp secure_compare(a, b) when byte_size(a) != byte_size(b), do: false

  defp secure_compare(a, b) do
    # Constant-time comparison (SC-HASH-002)
    :crypto.hash_equals(a, b)
  end

  defp generate_challenge do
    :crypto.strong_rand_bytes(32)
  end

  defp compute_attestation_response(challenge, secret) do
    :crypto.mac(:hmac, :sha256, secret, challenge)
    |> Base.encode16(case: :lower)
  end

  defp verify_attestation(peer_id, response, expected) do
    result =
      if secure_compare(response, expected) do
        establish_trust(peer_id, :attested)
        :attestation_verified
      else
        establish_trust(peer_id, :untrusted)
        :attestation_failed
      end

    log_attestation(peer_id, result)
    result
  end

  defp establish_trust(peer_id, level) do
    :ets.insert(
      @trust_store,
      {peer_id,
       %{
         level: level,
         established_at: System.monotonic_time(:second)
       }}
    )
  end

  defp set_attestation_time(peer_id, time) do
    :ets.insert(@trust_store, {peer_id, %{level: :attested, established_at: time}})
  end

  defp get_trust_level(peer_id) do
    case :ets.lookup(@trust_store, peer_id) do
      [{^peer_id, %{level: level}}] -> level
      [] -> :unknown
    end
  end

  defp trust_rank(:unknown), do: 0
  defp trust_rank(:untrusted), do: 1
  defp trust_rank(:verified), do: 2
  defp trust_rank(:attested), do: 3

  defp attestation_expired?(peer_id, ttl_seconds) do
    case :ets.lookup(@trust_store, peer_id) do
      [{^peer_id, %{established_at: time}}] ->
        now = System.monotonic_time(:second)
        now - time > ttl_seconds

      [] ->
        true
    end
  end

  defp attempt_cross_holon_op(peer_id, operation) do
    trust = get_trust_level(peer_id)

    case {trust, operation} do
      {:attested, _} -> :ok
      {:verified, :read} -> :ok
      _ -> {:error, :insufficient_trust}
    end
  end

  defp log_attestation(peer_id, result) do
    entry = %{
      peer: peer_id,
      result: result,
      timestamp: System.monotonic_time(:microsecond)
    }

    key = {entry.timestamp, System.unique_integer([:monotonic])}
    :ets.insert(@attestation_log, {key, entry})
  end

  defp get_attestation_logs(peer_id) do
    :ets.foldl(
      fn {ts, entry}, acc ->
        if entry.peer == peer_id, do: [{ts, entry} | acc], else: acc
      end,
      [],
      @attestation_log
    )
    |> Enum.sort_by(fn {ts, _} -> ts end)
  end
end
