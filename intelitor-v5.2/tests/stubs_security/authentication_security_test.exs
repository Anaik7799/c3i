defmodule Intelitor.Security.AuthenticationSecurityTest do
  use Intelitor.DataCase

  alias Intelitor.Accounts.{User, Session}
  alias Intelitor.Accounts.Authentication
  alias Intelitor.Core.{Tenant, AuditLog}

  describe "Authentication Security" do
    setup do
      tenant = insert(:tenant)

      {:ok, tenant: tenant}
    end

    test "prevents password brute force attacks", %{tenant: tenant} do
      user =
        insert(:user,
          tenant: tenant,
          email: "user@test.com",
          password_hash: Bcrypt.hash_pwd_salt("correct_password")
        )

      # Simulate multiple failed login attempts
      for _i <- 1..5 do
        {:error, _} =
          Authentication.authenticate(%{
            email: user.email,
            password: "wrong_password",
            tenant_id: tenant.id
          })
      end

      # Account should be locked after multiple failures
      {:error, result} =
        Authentication.authenticate(%{
          email: user.email,
          # Even correct password should fail
          password: "correct_password",
          tenant_id: tenant.id
        })

      assert result =~ "account is locked"
    end

    test "enforces strong password __requirements", %{tenant: tenant} do
      # Test weak passwords
      weak_passwords = [
        # Too simple
        "123_456",
        # Common word
        "password",
        # Too short, no uppercase
        "abc123",
        # No lowercase or numbers
        "ABCDEFGH",
        # No uppercase or numbers
        "abcdefgh",
        # Too short
        "Abc12",
        # No special characters
        "NoSpecial123"
      ]

      for weak_password <- weak_passwords do
        {:error, changeset} =
          User.create(%{
            email: "test@example.com",
            password: weak_password,
            tenant_id: tenant.id
          })

        assert changeset.errors[:password]
      end

      # Test strong password
      {:ok, _user} =
        User.create(%{
          email: "strong@example.com",
          password: "StrongP@ssw0rd123!",
          name: "Strong User",
          tenant_id: tenant.id
        })
    end

    test "implements secure session management", %{tenant: tenant} do
      user = insert(:user, tenant: tenant)

      # Create session
      {:ok, session} =
        Session.create(%{
          user_id: user.id,
          ip_address: "192.168.1.100",
          __user_agent: "Test Browser",
          tenant_id: tenant.id
        })

      # Session should have secure attributes
      assert session.session_token != nil
      assert String.length(session.session_token) >= 32
      assert session.expires_at != nil
      assert session.active? == true

      # Session should expire after configured time
      {:ok, expired_session} = Session.expire(session)
      assert expired_session.active? == false
      assert expired_session.expired_at != nil
    end

    test "logs all authentication events", %{tenant: tenant} do
      user = insert(:user, tenant: tenant)

      # Successful login should be logged
      {:ok, session} =
        Authentication.authenticate(%{
          email: user.email,
          password: "correct_password",
          tenant_id: tenant.id,
          ip_address: "192.168.1.100"
        })

      # Check audit log
      logs =
        AuditLog.read!(
          tenant: tenant,
          filter: [action: "user.login", resource_id: user.id]
        )

      assert length(logs) > 0
      log = List.first(logs)
      assert log.action == "user.login"
      assert log.resource_type == "User"
      assert log.resource_id == user.id
      assert log.metadata["ip_address"] == "192.168.1.100"

      # Failed login should also be logged
      {:error, _} =
        Authentication.authenticate(%{
          email: user.email,
          password: "wrong_password",
          tenant_id: tenant.id,
          ip_address: "192.168.1.100"
        })

      failed_logs =
        AuditLog.read!(
          tenant: tenant,
          filter: [action: "user.login_failed"]
        )

      assert length(failed_logs) > 0
    end

    test "prevents session fixation attacks", %{tenant: tenant} do
      user = insert(:user, tenant: tenant)

      # Create initial session
      {:ok, session1} =
        Session.create(%{
          user_id: user.id,
          session_token: "fixed_token_123",
          tenant_id: tenant.id
        })

      # Authenticate should create new session token
      {:ok, session2} =
        Authentication.authenticate(%{
          email: user.email,
          password: "correct_password",
          tenant_id: tenant.id
        })

      # New session should have different token
      assert session1.session_token != session2.session_token

      # Old session should be invalidated
      updated_session1 = Session.read!(session1.id)
      assert updated_session1.active? == false
    end

    test "implements secure password reset", %{tenant: tenant} do
      user = insert(:user, tenant: tenant)

      # Request password reset
      {:ok, token} =
        Authentication.__request_password_reset(%{
          email: user.email,
          tenant_id: tenant.id
        })

      # Token should be secure
      assert String.length(token.token) >= 32
      assert token.expires_at != nil
      assert token.used? == false

      # Reset password with token
      new_password = "NewSecureP@ssw0rd!"

      {:ok, _user} =
        Authentication.reset_password(%{
          token: token.token,
          password: new_password,
          tenant_id: tenant.id
        })

      # Token should be marked as used
      used_token = Token.read!(token.id)
      assert used_token.used? == true

      # Old password should no longer work
      {:error, _} =
        Authentication.authenticate(%{
          email: user.email,
          password: "old_password",
          tenant_id: tenant.id
        })

      # New password should work
      {:ok, _session} =
        Authentication.authenticate(%{
          email: user.email,
          password: new_password,
          tenant_id: tenant.id
        })
    end

    test "prevents timing attacks in authentication", %{tenant: tenant} do
      # Create a user
      real_user = insert(:user, tenant: tenant, email: "real@test.com")

      # Time authentication with valid email
      start_time = System.monotonic_time(:microsecond)

      {:error, _} =
        Authentication.authenticate(%{
          email: real_user.email,
          password: "wrong_password",
          tenant_id: tenant.id
        })

      valid_email_time = System.monotonic_time(:microsecond) - start_time

      # Time authentication with invalid email
      start_time = System.monotonic_time(:microsecond)

      {:error, _} =
        Authentication.authenticate(%{
          email: "nonexistent@test.com",
          password: "wrong_password",
          tenant_id: tenant.id
        })

      invalid_email_time = System.monotonic_time(:microsecond) - start_time

      # Times should be similar (within reasonable tolerance)
      # This prevents attackers from determining valid emails based on response
      time_diff = abs(valid_email_time - invalid_email_time)
      # 10ms tolerance
      tolerance = 10_000

      assert time_diff < tolerance
    end

    test "enforces concurrent session limits", %{tenant: tenant} do
      user = insert(:user, tenant: tenant)

      # Create multiple active sessions
      sessions =
        for i <- 1..5 do
          {:ok, session} =
            Session.create(%{
              user_id: user.id,
              ip_address: "192.168.1.#{100 + i}",
              __user_agent: "Browser #{i}",
              tenant_id: tenant.id
            })

          session
        end

      # Attempting to create 6th session should deactivate oldest
      {:ok, new_session} =
        Session.create(%{
          user_id: user.id,
          ip_address: "192.168.1.200",
          __user_agent: "Browser 6",
          tenant_id: tenant.id
        })

      # Check that only 5 sessions are active (max allowed)
      active_sessions =
        Session.read!(
          tenant: tenant,
          filter: [user_id: user.id, active?: true]
        )

      assert length(active_sessions) <= 5
      assert Enum.any?(active_sessions, &(&1.id == new_session.id))
    end

    test "validates IP address restrictions", %{tenant: tenant} do
      # Create user with IP restrictions
      user =
        insert(:user,
          tenant: tenant,
          settings: %{
            "allowed_ips" => ["192.168.1.0 / 24", "10.0.0.0 / 8"]
          }
        )

      # Authentication from allowed IP should succeed
      {:ok, _session} =
        Authentication.authenticate(%{
          email: user.email,
          password: "correct_password",
          tenant_id: tenant.id,
          ip_address: "192.168.1.100"
        })

      # Authentication from blocked IP should fail
      {:error, result} =
        Authentication.authenticate(%{
          email: user.email,
          password: "correct_password",
          tenant_id: tenant.id,
          # Public IP, not in allowed ranges
          ip_address: "203.0.113.1"
        })

      assert result =~ "IP address not allowed"
    end

    test "implements secure two - factor authentication", %{tenant: tenant} do
      user =
        insert(:user,
          tenant: tenant,
          two_factor_enabled?: true,
          two_factor_secret: "base32secret"
        )

      # First factor authentication
      {:ok, partial_session} =
        Authentication.authenticate(%{
          email: user.email,
          password: "correct_password",
          tenant_id: tenant.id
        })

      # Session should require 2FA completion
      assert partial_session.two_factor_pending? == true
      assert partial_session.active? == false

      # Generate valid TOTP code
      valid_code = NimbleTOTP.verification_code(user.two_factor_secret)

      # Complete 2FA
      {:ok, complete_session} =
        Authentication.verify_two_factor(%{
          session_id: partial_session.id,
          code: valid_code,
          tenant_id: tenant.id
        })

      assert complete_session.two_factor_pending? == false
      assert complete_session.active? == true

      # Invalid 2FA code should fail
      {:error, _} =
        Authentication.verify_two_factor(%{
          session_id: partial_session.id,
          # Invalid code
          code: "123_456",
          tenant_id: tenant.id
        })
    end

    test "protects against CSRF attacks", %{tenant: tenant} do
      user = insert(:user, tenant: tenant)

      {:ok, session} =
        Session.create(%{
          user_id: user.id,
          tenant_id: tenant.id
        })

      # Session should include CSRF token
      assert session.csrf_token != nil
      assert String.length(session.csrf_token) >= 32

      # Token should be validated on sensitive operations
      # (This would be implemented in the web layer)
      assert session.csrf_token != session.session_token
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
