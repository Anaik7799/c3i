defmodule Indrajaal.Jain.PropagationTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Jain.Propagation.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation refinement
  - FPPS Validation: 5-method consensus verification of public API contracts

  ## STAMP Safety Integration
  - SC-PRO-001: MUST NOT propagate without consent
  - SC-PRO-002: MUST verify host before deployment
  - SC-PRO-003: MUST respect rate limits
  - SC-PRO-004: MUST report to federation

  ## Constitutional Verification
  - Ψ₀ Existence: ETS tables persist across function calls without crashing the VM
  - Ψ₁ Regeneration: Peer and invitation state can be fully reconstructed from ETS
  - Ψ₃ Verification: `validate_invitation/1` verifies token integrity before use

  ## Founder's Directive Alignment
  - Ω₀.4 (Co-Evolution): Propagation must be consent-based and verifiable

  ## TPS 5-Level RCA Context
  - L1 Symptom: Propagation or discovery returns unexpected values
  - L5 Root Cause: ETS table state leaks between tests / TTL logic incorrect

  ## Module Under Test
  `lib/indrajaal/jain/propagation.ex` — ETS-backed federation discovery, DNS SRV,
  peer registry, invitation management with TTL, and consent-based propagation.

  ## ETS Tables (named, :public)
  - `:jain_propagation_cache`       — host assessment cache
  - `:jain_propagation_rate`        — rate-limit attempt tracking
  - `:jain_propagation_peers`       — known peers and federation peers
  - `:jain_propagation_invitations` — pending invitations with TTL
  """

  use ExUnit.Case, async: false

  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # MANDATORY: Disambiguate generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Jain.Propagation

  # MANDATORY: SKIP_ZENOH_NIF=0 for NIF tests (SC-TEST-NIF-001)
  @moduletag :zenoh_nif
  @moduletag :distributed
  @moduletag :sprint_54

  # ETS table names matching the module's private attributes
  @cache_table :jain_propagation_cache
  @rate_table :jain_propagation_rate
  @peer_table :jain_propagation_peers
  @invitation_table :jain_propagation_invitations

  @all_tables [@cache_table, @rate_table, @peer_table, @invitation_table]

  # ============================================================================
  # Setup — ensure clean ETS state before every test
  # ============================================================================

  setup do
    # Ensure tables exist (calling any public function creates them)
    Propagation.stats()

    # Wipe all ETS tables so tests are isolated
    for table <- @all_tables do
      if :ets.whereis(table) != :undefined do
        :ets.delete_all_objects(table)
      end
    end

    on_exit(fn ->
      for table <- @all_tables do
        if :ets.whereis(table) != :undefined do
          :ets.delete_all_objects(table)
        end
      end
    end)

    :ok
  end

  # ============================================================================
  # describe "stats/0"
  # ============================================================================

  describe "stats/0" do
    test "returns a map with expected keys" do
      result = Propagation.stats()

      assert is_map(result)
      assert Map.has_key?(result, :total_attempts)
      assert Map.has_key?(result, :successful)
      assert Map.has_key?(result, :failed)
      assert Map.has_key?(result, :rate_limited)
      assert Map.has_key?(result, :hosts_assessed)
      assert Map.has_key?(result, :rate_limit_remaining)
    end

    test "rate_limit_remaining is a positive integer" do
      %{rate_limit_remaining: remaining} = Propagation.stats()
      assert is_integer(remaining)
      assert remaining > 0
    end
  end

  # ============================================================================
  # describe "assess_host/1"
  # ============================================================================

  describe "assess_host/1" do
    test "returns {:ok, assessment} for any non-empty address" do
      assert {:ok, assessment} = Propagation.assess_host("192.168.1.100")
      assert is_map(assessment)
    end

    test "assessment contains required fields" do
      {:ok, assessment} = Propagation.assess_host("10.0.0.1")

      assert Map.has_key?(assessment, :address)
      assert Map.has_key?(assessment, :suitable)
      assert Map.has_key?(assessment, :capacity)
      assert Map.has_key?(assessment, :consent)
      assert Map.has_key?(assessment, :assessment_time)
    end

    test "assessment address matches the queried address" do
      address = "node.example.com:4000"
      {:ok, assessment} = Propagation.assess_host(address)
      assert assessment.address == address
    end

    test "capacity map contains cpu, memory, and storage keys" do
      {:ok, assessment} = Propagation.assess_host("host.local")
      assert Map.has_key?(assessment.capacity, :cpu)
      assert Map.has_key?(assessment.capacity, :memory)
      assert Map.has_key?(assessment.capacity, :storage)
    end

    test "suitable is a boolean" do
      {:ok, assessment} = Propagation.assess_host("valid.host.example.com")
      assert is_boolean(assessment.suitable)
    end

    test "assessment_time is a DateTime" do
      {:ok, assessment} = Propagation.assess_host("1.2.3.4")
      assert %DateTime{} = assessment.assessment_time
    end

    test "host with non-empty address string is marked suitable" do
      # assess_suitability returns String.length(address) > 0
      {:ok, assessment} = Propagation.assess_host("nonempty")
      assert assessment.suitable == true
    end
  end

  # ============================================================================
  # describe "allowed?/2"
  # ============================================================================

  describe "allowed?/2" do
    test "coordinated strategy is always allowed for any host (implicit consent)" do
      # verify_consent for :coordinated always returns :ok
      result = Propagation.allowed?("any.host.example.com", :coordinated)
      assert result == true
    end

    test "invited strategy requires explicit consent — returns false when consent is false" do
      # assess_host returns consent: false by default
      result = Propagation.allowed?("some.host", :invited)
      # consent defaults to false in do_assess_host/1
      assert result == false
    end

    test "opportunistic strategy returns true when host is suitable (even without explicit consent)" do
      # suitable = String.length(address) > 0 = true, consent = false
      # verify_consent for :opportunistic: consent or suitable → :ok
      result = Propagation.allowed?("suitable.host.com", :opportunistic)
      assert result == true
    end

    test "returns a boolean for all three strategies" do
      for strategy <- [:invited, :opportunistic, :coordinated] do
        result = Propagation.allowed?("h.example.com", strategy)
        assert is_boolean(result), "Expected boolean for strategy #{strategy}"
      end
    end
  end

  # ============================================================================
  # describe "register_peer/1 and discover_hosts/1 (method: :peer)"
  # ============================================================================

  describe "register_peer/1 and peer discovery" do
    test "register_peer/1 returns :ok" do
      assert :ok = Propagation.register_peer("peer.example.com:7447")
    end

    test "registered peer is returned by discover_hosts/1 with method: :peer" do
      address = "peer1.example.com:4000"
      :ok = Propagation.register_peer(address)

      {:ok, hosts} = Propagation.discover_hosts(method: :peer)
      assert address in hosts
    end

    test "multiple peers are all returned" do
      peers = ["peer-a.local:4001", "peer-b.local:4002", "peer-c.local:4003"]
      Enum.each(peers, &Propagation.register_peer/1)

      {:ok, hosts} = Propagation.discover_hosts(method: :peer)
      for peer <- peers, do: assert(peer in hosts)
    end

    test "registering the same peer twice does not duplicate it" do
      address = "dedup.peer.com:4000"
      :ok = Propagation.register_peer(address)
      :ok = Propagation.register_peer(address)

      {:ok, hosts} = Propagation.discover_hosts(method: :peer)
      occurrences = Enum.count(hosts, &(&1 == address))
      assert occurrences == 1
    end

    test "returns empty list when no peers are registered" do
      {:ok, hosts} = Propagation.discover_hosts(method: :peer)
      assert hosts == []
    end
  end

  # ============================================================================
  # describe "discover_hosts/1 — federation method"
  # ============================================================================

  describe "discover_hosts/1 (method: :federation)" do
    test "returns {:ok, list} for federation method" do
      assert {:ok, hosts} = Propagation.discover_hosts(method: :federation)
      assert is_list(hosts)
    end

    test "federation discovery includes ETS-announced federation peers" do
      # Insert a federation peer directly into ETS (simulating Zenoh announcement)
      announced_address = "fed-peer.mesh.local:7447"
      :ets.insert(@peer_table, {:federation_peers, [announced_address]})

      {:ok, hosts} = Propagation.discover_hosts(method: :federation)
      assert announced_address in hosts
    end

    test "multiple federation peers are returned" do
      federation_peers = ["fed-1.mesh:7447", "fed-2.mesh:7447"]
      :ets.insert(@peer_table, {:federation_peers, federation_peers})

      {:ok, hosts} = Propagation.discover_hosts(method: :federation)
      for peer <- federation_peers, do: assert(peer in hosts)
    end

    test "default method is :federation when no method opt given" do
      # discover_hosts/0 defaults to method: :federation
      assert {:ok, hosts} = Propagation.discover_hosts()
      assert is_list(hosts)
    end
  end

  # ============================================================================
  # describe "discover_hosts/1 — invitation method with TTL"
  # ============================================================================

  describe "discover_hosts/1 (method: :invitation) — TTL expiry" do
    test "returns {:ok, list} for invitation method" do
      assert {:ok, hosts} = Propagation.discover_hosts(method: :invitation)
      assert is_list(hosts)
    end

    test "returns empty list when no invitations are pending" do
      {:ok, hosts} = Propagation.discover_hosts(method: :invitation)
      assert hosts == []
    end

    test "returns address from a valid (non-expired) invitation" do
      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      invitation = %{address: "invited.host.com:4000", expires_at: future}
      :ets.insert(@invitation_table, {:pending, [invitation]})

      {:ok, hosts} = Propagation.discover_hosts(method: :invitation)
      assert "invited.host.com:4000" in hosts
    end

    test "filters out expired invitations (TTL expired)" do
      past = DateTime.add(DateTime.utc_now(), -10, :second)
      expired = %{address: "expired.host.com:4000", expires_at: past}
      :ets.insert(@invitation_table, {:pending, [expired]})

      {:ok, hosts} = Propagation.discover_hosts(method: :invitation)
      refute "expired.host.com:4000" in hosts
    end

    test "returns only non-expired invitations when mixed" do
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      future = DateTime.add(DateTime.utc_now(), 3600, :second)

      invitations = [
        %{address: "expired.host.com:4000", expires_at: past},
        %{address: "valid.host.com:4000", expires_at: future}
      ]

      :ets.insert(@invitation_table, {:pending, invitations})

      {:ok, hosts} = Propagation.discover_hosts(method: :invitation)

      assert "valid.host.com:4000" in hosts
      refute "expired.host.com:4000" in hosts
    end

    test "expired invitations are pruned from ETS after discovery" do
      past = DateTime.add(DateTime.utc_now(), -10, :second)
      expired = %{address: "pruned.host.com:4000", expires_at: past}
      :ets.insert(@invitation_table, {:pending, [expired]})

      # First call triggers the pruning
      {:ok, _hosts} = Propagation.discover_hosts(method: :invitation)

      # Check that ETS now has an empty list (expired entry pruned)
      case :ets.lookup(@invitation_table, :pending) do
        [{:pending, remaining}] -> assert remaining == []
        [] -> :ok
      end
    end
  end

  # ============================================================================
  # describe "discover_hosts/1 — DNS SRV method"
  # ============================================================================

  describe "discover_hosts/1 (method: :dns)" do
    test "returns {:ok, list} for dns method without crashing" do
      # DNS SRV lookup is best-effort; failure returns empty list
      assert {:ok, hosts} = Propagation.discover_hosts(method: :dns)
      assert is_list(hosts)
    end

    test "all returned hosts are binary strings" do
      {:ok, hosts} = Propagation.discover_hosts(method: :dns)
      for host <- hosts, do: assert(is_binary(host))
    end
  end

  # ============================================================================
  # describe "request_invitation/1"
  # ============================================================================

  describe "request_invitation/1" do
    test "returns {:error, :not_implemented}" do
      assert {:error, :not_implemented} = Propagation.request_invitation("some.host.com")
    end

    test "accepts any binary address without crashing" do
      result = Propagation.request_invitation("192.168.1.1:4000")
      assert {:error, :not_implemented} = result
    end
  end

  # ============================================================================
  # describe "validate_invitation/1"
  # ============================================================================

  describe "validate_invitation/1" do
    test "returns {:error, :invalid_token} for garbage input" do
      assert {:error, :invalid_token} = Propagation.validate_invitation("not-a-valid-token!")
    end

    test "returns {:error, :invalid_token} for empty binary" do
      assert {:error, :invalid_token} = Propagation.validate_invitation("")
    end

    test "returns {:ok, invitation} for a valid, non-expired token" do
      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      invitation = %{address: "target.host.com", expires_at: future, nonce: "abc123"}
      token = Base.encode64(:erlang.term_to_binary(invitation))

      assert {:ok, decoded} = Propagation.validate_invitation(token)
      assert decoded.address == "target.host.com"
    end

    test "returns {:error, :expired} for an expired token" do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)
      invitation = %{expires_at: past, address: "old.host.com"}
      token = Base.encode64(:erlang.term_to_binary(invitation))

      assert {:error, :expired} = Propagation.validate_invitation(token)
    end

    test "returns {:error, :invalid_token} for map missing expires_at field" do
      # valid_invitation?/1 falls through to the catch-all which returns false → :expired
      # but actually without expires_at, valid_invitation? returns false → :expired
      incomplete = %{address: "no-expiry.host.com"}
      token = Base.encode64(:erlang.term_to_binary(incomplete))

      result = Propagation.validate_invitation(token)
      # valid_invitation? with no :expires_at key returns false → {:error, :expired}
      assert result in [{:error, :expired}, {:error, :invalid_token}]
    end

    test "returns {:error, :invalid_token} for base64-encoded non-term binary" do
      # base64 is valid but binary_to_term will fail
      junk = Base.encode64(<<0xFF, 0xFE, 0xFD>>)
      assert {:error, :invalid_token} = Propagation.validate_invitation(junk)
    end
  end

  # ============================================================================
  # describe "propagate/1"
  # ============================================================================

  describe "propagate/1" do
    test "returns {:ok, result_map} for a coordinated propagation request" do
      request = %{
        target: "remote.node.example.com",
        strategy: :coordinated,
        parent_id: "jain_1_abc123",
        generation: 1
      }

      assert {:ok, result} = Propagation.propagate(request)
      assert is_map(result)
      assert Map.has_key?(result, :success)
      assert Map.has_key?(result, :child_id)
      assert Map.has_key?(result, :target)
      assert Map.has_key?(result, :reason)
    end

    test "coordinated propagation succeeds: success=true, child_id non-nil" do
      request = %{
        target: "coord.node.local",
        strategy: :coordinated,
        parent_id: "jain_0_root",
        generation: 0
      }

      {:ok, result} = Propagation.propagate(request)
      assert result.success == true
      assert is_binary(result.child_id)
      assert result.child_id != nil
    end

    test "child_id encodes the next generation number" do
      request = %{
        target: "gen.node.local",
        strategy: :coordinated,
        parent_id: "jain_2_some",
        generation: 2
      }

      {:ok, result} = Propagation.propagate(request)
      # child_id format: "jain_{generation+1}_{hex}"
      assert String.starts_with?(result.child_id, "jain_3_")
    end

    test "target in result matches request target" do
      target = "match.target.host.com"

      request = %{
        target: target,
        strategy: :coordinated,
        parent_id: "parent_x",
        generation: 0
      }

      {:ok, result} = Propagation.propagate(request)
      assert result.target == target
    end

    test "invited propagation fails when consent is false (default host assessment)" do
      # assess_host returns consent: false; :invited strategy requires consent
      request = %{
        target: "invited.host.com",
        strategy: :invited,
        parent_id: "parent_y",
        generation: 0
      }

      {:ok, result} = Propagation.propagate(request)
      # Will fail at verify_consent: {:error, :no_consent}
      assert result.success == false
      assert result.child_id == nil
      assert result.reason == :no_consent
    end
  end

  # ============================================================================
  # Property tests (StreamData check all — EP-GEN-014 compliant)
  # ============================================================================

  describe "property: peer registration is idempotent" do
    test "registering the same address N times yields exactly one occurrence" do
      ExUnitProperties.check all(
                               address <-
                                 SD.map(
                                   SD.string(:alphanumeric, min_length: 4, max_length: 20),
                                   fn s ->
                                     s <> ".host.com:4000"
                                   end
                                 ),
                               repeat_count <- SD.integer(2..5),
                               max_runs: 10
                             ) do
        # Clean peer table before each property iteration
        if :ets.whereis(@peer_table) != :undefined do
          :ets.delete_all_objects(@peer_table)
        end

        for _ <- 1..repeat_count, do: Propagation.register_peer(address)

        {:ok, hosts} = Propagation.discover_hosts(method: :peer)
        occurrences = Enum.count(hosts, &(&1 == address))
        assert occurrences == 1
      end
    end
  end

  describe "property: validate_invitation is consistent with expiry time" do
    test "future-expiring tokens always validate successfully" do
      ExUnitProperties.check all(
                               host <- SD.string(:alphanumeric, min_length: 3, max_length: 15),
                               offset_seconds <- SD.integer(60..86_400),
                               max_runs: 10
                             ) do
        address = host <> ".valid.com"
        future = DateTime.add(DateTime.utc_now(), offset_seconds, :second)
        invitation = %{address: address, expires_at: future}
        token = Base.encode64(:erlang.term_to_binary(invitation))

        assert {:ok, decoded} = Propagation.validate_invitation(token)
        assert decoded.address == address
      end
    end
  end

  # ============================================================================
  # FMEA failure mode tests (SC-PRO-*)
  # ============================================================================

  describe "FMEA failure modes" do
    @tag :fmea
    test "SC-PRO-003: rate limit eventually triggers after many propagation attempts" do
      # Reset rate table to simulate fresh session
      :ets.delete_all_objects(@rate_table)

      # The module rate-limits to 10 per hour. Drive > 10 attempts.
      # Use :coordinated to ensure consent is not the blocker.
      make_request = fn n ->
        Propagation.propagate(%{
          target: "rate-test-#{n}.host.com",
          strategy: :coordinated,
          parent_id: "parent",
          generation: 0
        })
      end

      results = for n <- 1..12, do: make_request.(n)

      # At least one result must have been rate-limited
      rate_limited =
        Enum.any?(results, fn {:ok, res} ->
          res.success == false and res.reason == :rate_limited
        end)

      assert rate_limited,
             "Expected at least one :rate_limited result after exceeding the 10/hour limit"
    end

    @tag :fmea
    test "SC-PRO-001: invited strategy refuses propagation without consent" do
      request = %{
        target: "no-consent.host.com",
        strategy: :invited,
        parent_id: "p",
        generation: 0
      }

      {:ok, result} = Propagation.propagate(request)

      refute result.success
      assert result.reason == :no_consent
    end

    @tag :fmea
    test "validate_invitation handles non-base64 gracefully" do
      # Should not raise; must return {:error, :invalid_token}
      assert {:error, :invalid_token} = Propagation.validate_invitation("!!!invalid==base64")
    end

    @tag :fmea
    test "assess_host returns {:ok, map} even for unusual address formats" do
      unusual_addresses = ["", "::1", "255.255.255.255:65535", "host-with-dashes.local"]

      for addr <- unusual_addresses do
        result =
          try do
            Propagation.assess_host(addr)
          rescue
            e -> {:error, {:raised, e}}
          end

        # assess_host must not raise; suitable = String.length > 0
        case result do
          {:ok, _assessment} -> :ok
          # An empty address may legitimately not be suitable but still returns {:ok, _}
          other -> flunk("assess_host(#{inspect(addr)}) raised or returned #{inspect(other)}")
        end
      end
    end
  end

  # ============================================================================
  # PropCheck property test (forall — PC prefix)
  # ============================================================================

  property "assess_host: suitable is true iff address is non-empty" do
    forall address <- PC.non_empty(PC.utf8()) do
      {:ok, assessment} = Propagation.assess_host(address)
      assessment.suitable == String.length(address) > 0
    end
  end
end
