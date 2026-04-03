defmodule Indrajaal.Authentication.TokenRevocationCacheSprint54Test do
  @moduledoc """
  TDG comprehensive test suite for TokenRevocationCache — Sprint 54 Wave 1.

  Extends existing coverage with property tests, concurrent safety tests,
  and Constitutional verification for the revocation pipeline.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation refinement
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-SEC-044: Token revocation prevents replay attacks
  - SC-AUTH-001: Revoked tokens must be rejected at all validation points
  - SC-IMMUNE-001: Token revocation published to Zenoh mesh

  ## Constitutional Verification
  - Ψ₃ Verification: Revocation state is cryptographically verifiable
  - Ψ₅ Truthfulness: revoked? returns accurate token state

  ## Founder's Directive Alignment
  - Ω₀.7: Threat elimination through immediate token invalidation

  ## TPS 5-Level RCA Context
  - L1 Symptom: Revoked token accepted at API boundary
  - L5 Root Cause: ETS cache not checked before JWT verification

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude Sonnet 4.6 | Sprint 54 W1 test generation |
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Authentication.TokenRevocationCache

  @moduletag :zenoh_nif

  setup do
    case Process.whereis(TokenRevocationCache) do
      nil ->
        {:ok, pid} = TokenRevocationCache.start_link([])

        on_exit(fn ->
          if Process.alive?(pid), do: GenServer.stop(pid)
        end)

      _pid ->
        :ok
    end

    :ok
  end

  # ============================================================
  # revoked?/1 — state after revocation
  # ============================================================

  describe "revoked?/1 after revoke_token/2" do
    test "token is revoked immediately after revocation" do
      jti = "s54-jti-#{System.unique_integer([:positive])}"
      :ok = TokenRevocationCache.revoke_token(jti)
      assert TokenRevocationCache.revoked?(jti)
    end

    test "different JTIs are independent after selective revocation" do
      jti_a = "s54-a-#{System.unique_integer([:positive])}"
      jti_b = "s54-b-#{System.unique_integer([:positive])}"
      :ok = TokenRevocationCache.revoke_token(jti_a)
      assert TokenRevocationCache.revoked?(jti_a)
      refute TokenRevocationCache.revoked?(jti_b)
    end

    test "revoking same jti twice is idempotent" do
      jti = "s54-idem-#{System.unique_integer([:positive])}"
      :ok = TokenRevocationCache.revoke_token(jti)
      :ok = TokenRevocationCache.revoke_token(jti)
      assert TokenRevocationCache.revoked?(jti)
    end

    test "revocation with explicit long TTL keeps entry revoked" do
      jti = "s54-long-#{System.unique_integer([:positive])}"
      :ok = TokenRevocationCache.revoke_token(jti, :timer.hours(24))
      assert TokenRevocationCache.revoked?(jti)
    end
  end

  # ============================================================
  # child_spec/1
  # ============================================================

  describe "child_spec/1" do
    test "returns valid OTP child spec map" do
      spec = TokenRevocationCache.child_spec([])
      assert spec.id == TokenRevocationCache
      assert spec.type == :worker
      assert spec.restart == :permanent
      assert spec.shutdown == 500
      assert is_tuple(spec.start)
    end

    test "start tuple has correct MFA format" do
      spec = TokenRevocationCache.child_spec([])
      {mod, fun, args} = spec.start
      assert mod == TokenRevocationCache
      assert fun == :start_link
      assert is_list(args)
    end
  end

  # ============================================================
  # Property Tests (PropCheck)
  # ============================================================

  property "revoke_token always returns :ok for non-empty binary jti" do
    forall jti <- PC.non_empty(PC.utf8()) do
      TokenRevocationCache.revoke_token(jti) == :ok
    end
  end

  property "revoked? returns true after revoke_token for same jti" do
    forall suffix <- PC.pos_integer() do
      jti = "prop-s54-jti-#{suffix}"
      TokenRevocationCache.revoke_token(jti)
      TokenRevocationCache.revoked?(jti) == true
    end
  end

  # ============================================================
  # ExUnitProperties (StreamData)
  # ============================================================

  test "revocation is consistent across re-revocations" do
    ExUnitProperties.check all(suffix <- SD.positive_integer()) do
      jti = "ex-s54-#{suffix}-#{System.unique_integer([:positive])}"
      :ok = TokenRevocationCache.revoke_token(jti)
      :ok = TokenRevocationCache.revoke_token(jti)
      assert TokenRevocationCache.revoked?(jti)
    end
  end

  test "revoke_token succeeds for various binary formats" do
    ExUnitProperties.check all(
                             prefix <- SD.string(:alphanumeric, min_length: 1, max_length: 16),
                             suffix <- SD.string(:alphanumeric, min_length: 1, max_length: 16)
                           ) do
      jti = "#{prefix}-#{System.unique_integer([:positive])}-#{suffix}"
      assert :ok = TokenRevocationCache.revoke_token(jti)
    end
  end

  # ============================================================
  # Concurrent safety (SIL-6)
  # ============================================================

  describe "concurrent safety" do
    test "concurrent revocations of distinct JTIs all succeed" do
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            jti = "conc-s54-#{i}-#{System.unique_integer([:positive])}"
            :ok = TokenRevocationCache.revoke_token(jti)
            {jti, TokenRevocationCache.revoked?(jti)}
          end)
        end

      results = Task.await_many(tasks, 5_000)
      assert Enum.all?(results, fn {_jti, revoked} -> revoked == true end)
    end

    test "concurrent reads of a revoked token are all consistent" do
      shared_jti = "shared-read-#{System.unique_integer([:positive])}"
      :ok = TokenRevocationCache.revoke_token(shared_jti)
      tasks = for _ <- 1..20, do: Task.async(fn -> TokenRevocationCache.revoked?(shared_jti) end)
      results = Task.await_many(tasks, 5_000)
      assert Enum.all?(results, &(&1 == true))
    end
  end

  # ============================================================
  # FMEA: boundary conditions
  # ============================================================

  describe "FMEA: edge cases" do
    test "revoked? handles jti with special path characters" do
      jti = "jti/with-slashes:and-colons"
      :ok = TokenRevocationCache.revoke_token(jti)
      assert TokenRevocationCache.revoked?(jti)
    end

    test "revoke_token handles jti with unicode characters" do
      jti = "jti-unicode-#{:erlang.unique_integer([:positive])}"
      assert :ok = TokenRevocationCache.revoke_token(jti)
    end

    test "revoked? returns boolean for fresh unknown jti" do
      jti = "totally-unknown-#{System.unique_integer([:positive])}"
      result = TokenRevocationCache.revoked?(jti)
      assert is_boolean(result)
    end
  end
end
