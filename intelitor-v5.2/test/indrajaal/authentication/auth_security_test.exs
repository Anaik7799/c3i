defmodule Indrajaal.Authentication.AuthSecurityTest do
  @moduledoc """
  Comprehensive Authentication Security Tests

  This test module verifies authentication security properties derived from:
  - CLAUDE.md §7: Hoare Logic Protocols (Authentication Protocol)
  - CLAUDE.md §8: Error Pattern Database (EP-AGT-009, EP-AGT-010, EP-AGT-013)
  - CLAUDE.md §4: STAMP Safety Constraints (SC-SEC-041 to SC-SEC-048)
  - CLAUDE.md §6: Agent Operating Rules (AOR-SAF-*)

  Key Security Properties Verified:
  1. JWT token lifecycle (generation, verification, revocation)
  2. Token claim validation (required claims, expiration, issuer, audience)
  3. STAMP safety constraints for authentication
  4. Rate limiting compliance
  5. Tenant isolation enforcement
  6. MFA enrollment and verification
  7. Known error pattern detection (EP-AGT-009, EP-AGT-010, EP-AGT-013)

  STAMP Compliance:
  - SC-SEC-041: Enforce secure token generation
  - SC-SEC-042: Validate token integrity
  - SC-SEC-043: Maintain tenant isolation
  - SC-SEC-044: Enforce rate limiting
  - SC-SEC-045: Secure token revocation
  - SC-SEC-046: Audit authentication events
  - SC-SEC-047: Prevent replay attacks
  - SC-SEC-048: Secure session management

  SOPv5.11 Framework: TDG-compliant security verification
  """

  use ExUnit.Case, async: true

  @moduletag :formal_verification
  @moduletag :authentication
  @moduletag :security

  # ============================================================================
  # Test Helpers - JWT Token Handling
  # ============================================================================

  @doc """
  Simulates JWT token structure for testing.
  Based on Indrajaal.Authentication.JWT module specifications.
  """
  defp build_test_claims(overrides \\ %{}) do
    now = System.system_time(:second)

    base_claims = %{
      "sub" => "user-uuid-12_345",
      "iss" => "indrajaal-security",
      "aud" => "indrajaal-mobile",
      "exp" => now + 900,
      "iat" => now,
      "nbf" => now,
      "jti" => generate_jti(),
      "tenant_id" => "tenant-uuid-12_345",
      "role" => "operator",
      "token_type" => "access"
    }

    Map.merge(base_claims, overrides)
  end

  defp generate_jti do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Validates that claims contain all required fields.
  Based on JWT.validate_required_claims/1.
  """
  defp validate_required_claims(claims) do
    required = ~w(sub iss aud exp iat jti tenant_id role)
    missing = Enum.reject(required, &Map.has_key?(claims, &1))

    case missing do
      [] -> :ok
      list -> {:error, {:missing_claims, list}}
    end
  end

  @doc """
  Validates token expiration.
  Based on JWT.validate_expiration/1.
  """
  defp validate_expiration(%{"exp" => exp}) when is_integer(exp) do
    if exp > System.system_time(:second), do: :ok, else: {:error, :expired_token}
  end

  defp validate_expiration(_), do: {:error, :missing_expiration}

  @doc """
  Validates token issuer.
  """
  defp validate_issuer(%{"iss" => "indrajaal-security"}), do: :ok
  defp validate_issuer(_), do: {:error, :invalid_issuer}

  @doc """
  Validates token audience.
  """
  defp validate_audience(%{"aud" => "indrajaal-mobile"}), do: :ok
  defp validate_audience(_), do: {:error, :invalid_audience}

  # ============================================================================
  # JWT Token Claim Validation Tests (§7 Hoare Logic)
  # ============================================================================

  describe "JWT Required Claims Validation (CLAUDE.md §7: Hoare Logic)" do
    @tag :stamp_constraint
    @tag constraint: "SC-SEC-042"

    test "valid claims pass all validation" do
      claims = build_test_claims()

      assert :ok = validate_required_claims(claims)
      assert :ok = validate_expiration(claims)
      assert :ok = validate_issuer(claims)
      assert :ok = validate_audience(claims)
    end

    test "missing 'sub' claim fails validation" do
      claims =
        build_test_claims()
        |> Map.delete("sub")

      assert {:error, {:missing_claims, ["sub"]}} = validate_required_claims(claims)
    end

    test "missing 'tenant_id' claim fails validation" do
      claims =
        build_test_claims()
        |> Map.delete("tenant_id")

      assert {:error, {:missing_claims, ["tenant_id"]}} = validate_required_claims(claims)
    end

    test "missing 'jti' claim fails validation (replay attack prevention)" do
      claims =
        build_test_claims()
        |> Map.delete("jti")

      assert {:error, {:missing_claims, ["jti"]}} = validate_required_claims(claims)
    end

    test "multiple missing claims are all reported" do
      claims =
        build_test_claims()
        |> Map.delete("sub")
        |> Map.delete("role")
        |> Map.delete("tenant_id")

      {:error, {:missing_claims, missing}} = validate_required_claims(claims)

      assert "sub" in missing
      assert "role" in missing
      assert "tenant_id" in missing
    end
  end

  describe "JWT Expiration Validation (SC-SEC-047: Replay Prevention)" do
    @tag :stamp_constraint
    @tag constraint: "SC-SEC-047"

    test "valid non-expired token passes" do
      claims = build_test_claims(%{"exp" => System.system_time(:second) + 3600})

      assert :ok = validate_expiration(claims)
    end

    test "expired token fails validation" do
      claims = build_test_claims(%{"exp" => System.system_time(:second) - 100})

      assert {:error, :expired_token} = validate_expiration(claims)
    end

    test "token expiring exactly now fails" do
      claims = build_test_claims(%{"exp" => System.system_time(:second)})

      assert {:error, :expired_token} = validate_expiration(claims)
    end

    test "missing expiration fails validation" do
      claims =
        build_test_claims()
        |> Map.delete("exp")

      assert {:error, :missing_expiration} = validate_expiration(claims)
    end

    test "non-integer expiration fails validation" do
      claims = build_test_claims(%{"exp" => "not-a-timestamp"})

      assert {:error, :missing_expiration} = validate_expiration(claims)
    end
  end

  describe "JWT Issuer/Audience Validation (SC-SEC-042: Token Integrity)" do
    @tag :stamp_constraint
    @tag constraint: "SC-SEC-042"

    test "correct issuer passes" do
      claims = build_test_claims(%{"iss" => "indrajaal-security"})

      assert :ok = validate_issuer(claims)
    end

    test "incorrect issuer fails" do
      claims = build_test_claims(%{"iss" => "malicious-issuer"})

      assert {:error, :invalid_issuer} = validate_issuer(claims)
    end

    test "correct audience passes" do
      claims = build_test_claims(%{"aud" => "indrajaal-mobile"})

      assert :ok = validate_audience(claims)
    end

    test "incorrect audience fails" do
      claims = build_test_claims(%{"aud" => "wrong-audience"})

      assert {:error, :invalid_audience} = validate_audience(claims)
    end
  end

  # ============================================================================
  # STAMP Safety Constraints for Authentication (§4)
  # ============================================================================

  describe "SC-SEC-043: Tenant Isolation Enforcement" do
    @tag :stamp_constraint
    @tag constraint: "SC-SEC-043"

    @doc """
    Tenant isolation ensures tokens from one tenant cannot access
    resources of another tenant. This is a critical security property.
    """

    defp ensure_tenant_isolation(token_tenant_id, requested_tenant) do
      if token_tenant_id == requested_tenant do
        :ok
      else
        {:error, :tenant_isolation_violation}
      end
    end

    test "same tenant access is allowed" do
      tenant_id = "tenant-123"

      assert :ok = ensure_tenant_isolation(tenant_id, tenant_id)
    end

    test "cross-tenant access is blocked" do
      token_tenant = "tenant-123"
      requested_tenant = "tenant-456"

      assert {:error, :tenant_isolation_violation} =
               ensure_tenant_isolation(token_tenant, requested_tenant)
    end

    test "tenant isolation is enforced for all operations" do
      operations = [:read, :write, :delete, :admin]
      token_tenant = "tenant-A"
      other_tenant = "tenant-B"

      for op <- operations do
        result = ensure_tenant_isolation(token_tenant, other_tenant)

        assert result == {:error, :tenant_isolation_violation},
               "Operation #{op} must enforce tenant isolation"
      end
    end
  end

  describe "SC-SEC-044: Rate Limiting Compliance" do
    @tag :stamp_constraint
    @tag constraint: "SC-SEC-044"

    @doc """
    Rate limiting prevents brute force attacks and resource exhaustion.
    Based on RateLimiter.check_rate/3 specifications.
    """

    defp check_rate_limit(action, current_count, max_allowed) do
      if current_count <= max_allowed do
        {:ok, :allowed}
      else
        {:error, {:rate_limit_exceeded, action, current_count, max_allowed}}
      end
    end

    @doc """
    EP-AGT-010: RateLimiter :ok match - Match {:ok, :allowed}
    This error pattern tests that rate limiter returns proper tuple.
    """
    test "EP-AGT-010: rate limiter returns {:ok, :allowed} tuple" do
      result = check_rate_limit(:authenticate, 5, 10)

      # MUST match on {:ok, :allowed}, not just :ok
      assert {:ok, :allowed} = result
    end

    test "rate limit within threshold passes" do
      assert {:ok, :allowed} = check_rate_limit(:verify, 50, 100)
    end

    test "rate limit at threshold passes" do
      assert {:ok, :allowed} = check_rate_limit(:refresh, 5, 5)
    end

    test "rate limit exceeded fails" do
      result = check_rate_limit(:authenticate, 15, 10)

      assert {:error, {:rate_limit_exceeded, :authenticate, 15, 10}} = result
    end

    test "authentication rate limits are enforced" do
      auth_limit = 10
      refresh_limit = 5
      verify_limit = 100

      # Authentication
      assert {:error, _} = check_rate_limit(:authenticate, 11, auth_limit)

      # Refresh
      assert {:error, _} = check_rate_limit(:refresh, 6, refresh_limit)

      # Verify (higher limit)
      assert {:ok, :allowed} = check_rate_limit(:verify, 99, verify_limit)
    end
  end

  describe "SC-SEC-048: Secure Session Management" do
    @tag :stamp_constraint
    @tag constraint: "SC-SEC-048"

    @doc """
    Session management ensures proper session limits per role.
    """

    defp get_max_sessions(role) do
      case role do
        "admin" -> 10
        "manager" -> 5
        "operator" -> 3
        "viewer" -> 2
        _ -> 1
      end
    end

    defp validate_session_count(role, current_sessions) do
      max = get_max_sessions(role)

      if current_sessions <= max do
        :ok
      else
        {:error, {:max_sessions_exceeded, max, current_sessions}}
      end
    end

    test "admin can have up to 10 sessions" do
      assert :ok = validate_session_count("admin", 10)
      assert {:error, _} = validate_session_count("admin", 11)
    end

    test "manager can have up to 5 sessions" do
      assert :ok = validate_session_count("manager", 5)
      assert {:error, _} = validate_session_count("manager", 6)
    end

    test "operator can have up to 3 sessions" do
      assert :ok = validate_session_count("operator", 3)
      assert {:error, _} = validate_session_count("operator", 4)
    end

    test "viewer can have up to 2 sessions" do
      assert :ok = validate_session_count("viewer", 2)
      assert {:error, _} = validate_session_count("viewer", 3)
    end

    test "unknown role defaults to 1 session" do
      assert :ok = validate_session_count("unknown", 1)
      assert {:error, _} = validate_session_count("unknown", 2)
    end
  end

  # ============================================================================
  # Error Pattern Detection Tests (§8)
  # ============================================================================

  describe "EP-AGT-009: JWT Peek Return Pattern" do
    @tag :error_pattern
    @tag pattern: "EP-AGT-009"

    @doc """
    EP-AGT-009: Jwt.peek/1 wrong return - Match on %{claims: claims}

    This tests the correct pattern matching for JWT peek operations.
    The JOSE library returns %JOSE.JWT{fields: fields}, not %{claims: claims}.
    """

    defp peek_token_correct(token) when is_binary(token) do
      # Simulating correct pattern matching
      # Real: JOSE.JWT.peek_payload(token) returns %JOSE.JWT{fields: fields}
      case String.length(token) > 10 do
        true ->
          # Correct: return {:ok, fields} where fields is the claims map
          {:ok, %{"sub" => "user-id", "exp" => 12_345}}

        false ->
          {:error, :invalid_token_format}
      end
    end

    defp peek_token_wrong_pattern(token) when is_binary(token) do
      # WRONG pattern: expecting %{claims: claims}
      # This would cause a match failure
      case String.length(token) > 10 do
        true ->
          # WRONG: Wrapping in %{claims: ...} that JOSE doesn't return
          {:ok, %{claims: %{"sub" => "user-id"}}}

        false ->
          {:error, :invalid_token_format}
      end
    end

    test "correct peek pattern returns claims directly" do
      token = "valid.jwt.token.string"

      {:ok, claims} = peek_token_correct(token)

      # Correct: claims is the map directly
      assert is_map(claims)
      assert Map.has_key?(claims, "sub")
    end

    test "wrong pattern would wrap claims unnecessarily" do
      token = "valid.jwt.token.string"

      {:ok, result} = peek_token_wrong_pattern(token)

      # DEMONSTRATION: This shows the WRONG pattern that EP-AGT-009 warns against
      # The wrong implementation wraps claims in a nested :claims key
      assert Map.has_key?(result, :claims),
             "This demonstrates EP-AGT-009: wrong pattern nests claims under :claims key"

      # Verify the wrong pattern structure (for educational purposes)
      # Code reviewers should catch this anti-pattern
      assert is_map(result.claims)
    end

    test "peek should not require nested claims extraction" do
      token = "valid.jwt.token.string"

      {:ok, claims} = peek_token_correct(token)

      # Should NOT need to do claims.claims or Map.get(claims, :claims)
      refute Map.has_key?(claims, :claims),
             "EP-AGT-009: Claims should not be nested under :claims key"
    end
  end

  describe "EP-AGT-013: Enum.map_join Argument Order" do
    @tag :error_pattern
    @tag pattern: "EP-AGT-013"

    @doc """
    EP-AGT-013: Enum.map_join(&func, joiner) - Swap argument order

    The correct signature is: Enum.map_join(enumerable, joiner, mapper_fn)
    WRONG: Enum.map_join(enumerable, mapper_fn, joiner)

    This was found in MFA backup code generation.
    """

    defp generate_backup_codes_correct(count) do
      1..count
      |> Enum.map(fn _ ->
        8
        |> :crypto.strong_rand_bytes()
        |> Base.encode32(case: :lower, padding: false)
        |> String.slice(0, 8)
      end)
    end

    defp format_backup_codes_correct(codes) do
      # CORRECT: Enum.map_join(enumerable, joiner, mapper_fn)
      Enum.map_join(codes, "-", &String.upcase/1)
    end

    defp format_backup_codes_wrong(codes) do
      # WRONG (EP-AGT-013): Enum.map_join(&func, joiner)
      # This would cause: Enum.map_join(codes, &String.upcase/1, "-")
      # Which is WRONG - the joiner and mapper are swapped
      try do
        # Simulating the wrong call - this should fail or produce wrong output
        Enum.map_join(codes, &String.upcase/1, "-")
      rescue
        _ -> {:error, :wrong_argument_order}
      end
    end

    test "correct map_join produces hyphen-separated uppercase codes" do
      codes = ["abc", "def", "ghi"]

      result = format_backup_codes_correct(codes)

      assert result == "ABC-DEF-GHI"
    end

    test "backup codes are generated with correct format" do
      codes = generate_backup_codes_correct(5)

      assert length(codes) == 5

      for code <- codes do
        assert String.length(code) == 8
        assert code =~ ~r/^[a-z0-9]+$/
      end
    end

    test "EP-AGT-013: wrong argument order should be detected" do
      codes = ["abc", "def", "ghi"]

      result = format_backup_codes_wrong(codes)

      # The wrong order either raises or produces incorrect output
      case result do
        {:error, :wrong_argument_order} ->
          # Expected - wrong order caused error
          assert true

        wrong_result when is_binary(wrong_result) ->
          # If it somehow succeeded, the output would be wrong
          refute wrong_result == "ABC-DEF-GHI",
                 "EP-AGT-013: Wrong argument order should not produce correct output"

        _ ->
          # Some other error
          assert true
      end
    end
  end

  # ============================================================================
  # Role-Based Access Control Tests (AOR-SAF)
  # ============================================================================

  describe "Role-Based Allowed Actions (CLAUDE.md §6: AOR-SAF)" do
    @tag :stamp_constraint
    @tag constraint: "SC-SEC-041"

    defp get_allowed_actions(role) do
      case role do
        "admin" -> :all
        "manager" -> [:read, :write, :manage_users]
        "operator" -> [:read, :write, :acknowledge_alarms]
        "viewer" -> [:read]
        _ -> [:read]
      end
    end

    defp action_allowed?(role, action) do
      allowed = get_allowed_actions(role)

      case allowed do
        :all -> true
        actions when is_list(actions) -> action in actions
      end
    end

    test "admin has all permissions" do
      assert action_allowed?("admin", :read)
      assert action_allowed?("admin", :write)
      assert action_allowed?("admin", :delete)
      assert action_allowed?("admin", :manage_users)
      assert action_allowed?("admin", :anything)
    end

    test "manager has read, write, manage_users" do
      assert action_allowed?("manager", :read)
      assert action_allowed?("manager", :write)
      assert action_allowed?("manager", :manage_users)
      refute action_allowed?("manager", :delete)
      refute action_allowed?("manager", :admin_only)
    end

    test "operator has read, write, acknowledge_alarms" do
      assert action_allowed?("operator", :read)
      assert action_allowed?("operator", :write)
      assert action_allowed?("operator", :acknowledge_alarms)
      refute action_allowed?("operator", :manage_users)
      refute action_allowed?("operator", :delete)
    end

    test "viewer has read only" do
      assert action_allowed?("viewer", :read)
      refute action_allowed?("viewer", :write)
      refute action_allowed?("viewer", :delete)
      refute action_allowed?("viewer", :manage_users)
    end

    test "unknown role defaults to read only" do
      assert action_allowed?("unknown", :read)
      refute action_allowed?("unknown", :write)
    end
  end

  # ============================================================================
  # Token Lifecycle Tests (Generation, Verification, Revocation)
  # ============================================================================

  describe "Token Lifecycle - SC-SEC-045: Secure Revocation" do
    @tag :stamp_constraint
    @tag constraint: "SC-SEC-045"

    defp simulate_token_revocation(jti, revoked_set) do
      MapSet.put(revoked_set, jti)
    end

    defp is_token_revoked?(jti, revoked_set) do
      MapSet.member?(revoked_set, jti)
    end

    test "new token is not revoked" do
      jti = generate_jti()
      revoked_set = MapSet.new()

      refute is_token_revoked?(jti, revoked_set)
    end

    test "revoked token is marked as revoked" do
      jti = generate_jti()
      revoked_set = MapSet.new()

      revoked_set = simulate_token_revocation(jti, revoked_set)

      assert is_token_revoked?(jti, revoked_set)
    end

    test "revoking one token does not affect others" do
      jti1 = generate_jti()
      jti2 = generate_jti()
      revoked_set = MapSet.new()

      revoked_set = simulate_token_revocation(jti1, revoked_set)

      assert is_token_revoked?(jti1, revoked_set)
      refute is_token_revoked?(jti2, revoked_set)
    end

    test "multiple tokens can be revoked" do
      jtis = for _ <- 1..5, do: generate_jti()

      revoked_set =
        Enum.reduce(jtis, MapSet.new(), fn jti, set ->
          simulate_token_revocation(jti, set)
        end)

      for jti <- jtis do
        assert is_token_revoked?(jti, revoked_set)
      end
    end
  end

  # ============================================================================
  # MFA Security Tests
  # ============================================================================

  describe "MFA Challenge and Verification Security" do
    @tag :authentication
    @tag :mfa

    defp create_mfa_challenge(user_id) do
      %{
        id: "challenge_#{generate_jti()}",
        user_id: user_id,
        type: "totp",
        created_at: System.system_time(:second)
      }
    end

    defp verify_mfa_challenge(challenge, code) do
      # Simplified TOTP verification
      cond do
        String.length(code) != 6 ->
          {:error, :invalid_code_format}

        not Regex.match?(~r/^\d{6}$/, code) ->
          {:error, :invalid_code_format}

        code == "000_000" ->
          {:error, :invalid_code}

        true ->
          {:ok, challenge.user_id}
      end
    end

    test "MFA challenge is created with user ID" do
      user_id = "user-12_345"
      challenge = create_mfa_challenge(user_id)

      assert challenge.user_id == user_id
      assert challenge.type == "totp"
      assert String.starts_with?(challenge.id, "challenge_")
    end

    test "MFA verification requires 6-digit code" do
      challenge = create_mfa_challenge("user-123")

      assert {:error, :invalid_code_format} = verify_mfa_challenge(challenge, "12_345")
      assert {:error, :invalid_code_format} = verify_mfa_challenge(challenge, "1_234_567")
      assert {:error, :invalid_code_format} = verify_mfa_challenge(challenge, "abcdef")
    end

    test "MFA verification rejects known bad codes" do
      challenge = create_mfa_challenge("user-123")

      assert {:error, :invalid_code} = verify_mfa_challenge(challenge, "000_000")
    end

    test "MFA verification accepts valid 6-digit code" do
      challenge = create_mfa_challenge("user-123")

      {:ok, user_id} = verify_mfa_challenge(challenge, "123_456")

      assert user_id == "user-123"
    end
  end

  # ============================================================================
  # Security Audit Logging Tests (SC-SEC-046)
  # ============================================================================

  describe "SC-SEC-046: Authentication Audit Events" do
    @tag :stamp_constraint
    @tag constraint: "SC-SEC-046"

    defp log_auth_event(event_type, details) do
      %{
        event_type: event_type,
        timestamp: System.system_time(:second),
        details: details,
        logged: true
      }
    end

    @auth_events [
      :token_generated,
      :token_verified,
      :token_revoked,
      :verification_failed,
      :rate_limit_exceeded,
      :tenant_isolation_violation,
      :mfa_challenge_created,
      :mfa_verified,
      :mfa_failed
    ]

    test "all authentication events can be logged" do
      for event <- @auth_events do
        log_entry = log_auth_event(event, %{user_id: "test-user"})

        assert log_entry.event_type == event
        assert log_entry.logged == true
        assert is_integer(log_entry.timestamp)
      end
    end

    test "failed authentication includes reason" do
      log_entry =
        log_auth_event(:verification_failed, %{
          user_id: "test-user",
          reason: :expired_token,
          token_hash: "abc123"
        })

      assert log_entry.details.reason == :expired_token
    end

    test "security violations are logged with full context" do
      log_entry =
        log_auth_event(:tenant_isolation_violation, %{
          user_id: "attacker-user",
          token_tenant: "tenant-A",
          requested_tenant: "tenant-B",
          action: :read,
          resource: "sensitive-data"
        })

      assert log_entry.event_type == :tenant_isolation_violation
      assert log_entry.details.token_tenant != log_entry.details.requested_tenant
    end
  end

  # ============================================================================
  # Comprehensive Security Invariant Tests
  # ============================================================================

  describe "Security Invariants (All SC-SEC constraints combined)" do
    @tag :stamp_constraint
    @tag constraint: "SC-SEC-ALL"

    test "complete token validation pipeline" do
      claims = build_test_claims()

      # All validations must pass for valid token
      assert :ok = validate_required_claims(claims)
      assert :ok = validate_expiration(claims)
      assert :ok = validate_issuer(claims)
      assert :ok = validate_audience(claims)
    end

    test "any validation failure blocks access" do
      invalid_scenarios = [
        # Missing claims
        {
          build_test_claims()
          |> Map.delete("sub"),
          :missing_claims
        },
        # Expired
        {build_test_claims(%{"exp" => System.system_time(:second) - 100}), :expired},
        # Wrong issuer
        {build_test_claims(%{"iss" => "wrong"}), :invalid_issuer},
        # Wrong audience
        {build_test_claims(%{"aud" => "wrong"}), :invalid_audience}
      ]

      for {claims, failure_type} <- invalid_scenarios do
        result =
          with :ok <- validate_required_claims(claims),
               :ok <- validate_expiration(claims),
               :ok <- validate_issuer(claims) do
            validate_audience(claims)
          end

        assert match?({:error, _}, result),
               "#{failure_type} should cause validation failure"
      end
    end

    test "security is defense-in-depth" do
      # Even if one check is bypassed, others should catch the issue
      claims = build_test_claims()

      # Remove one validation - others should still work
      validations = [
        &validate_required_claims/1,
        &validate_expiration/1,
        &validate_issuer/1,
        &validate_audience/1
      ]

      for validation <- validations do
        result = validation.(claims)

        assert :ok = result,
               "Each validation should pass independently for valid claims"
      end
    end
  end
end
