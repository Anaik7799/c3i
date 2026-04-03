defmodule Indrajaal.Auth.LocalAuthenticationTest do
  use Indrajaal.TestCase, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Auth.LocalAuthentication
  import Indrajaal.Generators

  describe "start_link / 1" do
    test "starts the GenServer successfully" do
      assert {:ok, pid} = LocalAuthentication.start_link([])
      assert Process.alive?(pid)
      Process.exit(pid, :normal)
    end
  end

  describe "register_user / 1" do
    test "successfully registers a user with valid attributes" do
      attrs = %{
        email: "test@example.com",
        username: "testuser",
        password: "ValidPass123!",
        first_name: "Test",
        last_name: "User"
      }

      assert {:ok, registered_user} = LocalAuthentication.register_user(attrs)
      assert registered_user.email == attrs.email
      assert registered_user.username == attrs.username
      refute Map.has_key?(registered_user, :password_hash)
    end

    test "fails with missing required fields" do
      attrs = %{email: "test@example.com"}

      assert {:error, {:missing_fields, missing}} = LocalAuthentication.register_user(attrs)
      assert :username in missing
      assert :password in missing
    end

    test "fails with invalid email format" do
      attrs = %{
        email: "invalid-email",
        username: "testuser",
        password: "ValidPass123!",
        first_name: "Test",
        last_name: "User"
      }

      assert {:error, :invalid_email} = LocalAuthentication.register_user(attrs)
    end

    test "fails with short username" do
      attrs = %{
        email: "test@example.com",
        username: "ab",
        password: "ValidPass123!",
        first_name: "Test",
        last_name: "User"
      }

      assert {:error, :username_too_short} = LocalAuthentication.register_user(attrs)
    end

    test "fails with invalid username format" do
      attrs = %{
        email: "test@example.com",
        username: "test user!",
        password: "ValidPass123!",
        first_name: "Test",
        last_name: "User"
      }

      assert {:error, :invalid_username_format} = LocalAuthentication.register_user(attrs)
    end

    test "fails with short password" do
      attrs = %{
        email: "test@example.com",
        username: "testuser",
        password: "Short1!",
        first_name: "Test",
        last_name: "User"
      }

      assert {:error, {:password_too_short, 12}} = LocalAuthentication.register_user(attrs)
    end

    test "fails with password not meeting complexity requirements" do
      attrs = %{
        email: "test@example.com",
        username: "testuser",
        password: "simplepassword123",
        first_name: "Test",
        last_name: "User"
      }

      assert {:error, :password_complexity_not_met} = LocalAuthentication.register_user(attrs)
    end

    test "accepts any valid email format" do
      ExUnitProperties.check all(email <- email_generator()) do
        attrs = %{
          email: email,
          username: "testuser",
          password: "ValidPass123!",
          first_name: "Test",
          last_name: "User"
        }

        case LocalAuthentication.register_user(attrs) do
          {:ok, _} -> true
          {:error, :invalid_email} -> false
          # Other errors are ok for this test
          _ -> true
        end
      end
    end

    test "accepts any password meeting complexity requirements" do
      ExUnitProperties.check all(password <- password_generator()) do
        attrs = %{
          email: "test@example.com",
          username: "testuser",
          password: password,
          first_name: "Test",
          last_name: "User"
        }

        case LocalAuthentication.register_user(attrs) do
          {:ok, _} -> true
          {:error, :password_complexity_not_met} -> false
          {:error, {:password_too_short, _}} -> String.length(password) < 12
          _ -> true
        end
      end
    end
  end

  describe "authenticate / 2" do
    setup do
      # Register a test user
      attrs = %{
        email: "auth@example.com",
        username: "authuser",
        password: "AuthPass123!",
        first_name: "Auth",
        last_name: "User"
      }

      {:ok, _user} = LocalAuthentication.register_user(attrs)
      {:ok, attrs: attrs}
    end

    test "successfully authenticates with valid credentials", %{attrs: attrs} do
      assert {:ok, result} = LocalAuthentication.authenticate(attrs.email, attrs.password)
      assert result.user.email == attrs.email
      assert result.tokens.access_token
      assert result.tokens.refresh_token
      assert result.tokens.token_type == "Bearer"
      assert result.tokens.expires_in == 900
    end

    test "fails with invalid password", %{attrs: attrs} do
      assert {:error, :invalid_credentials} =
               LocalAuthentication.authenticate(attrs.email, "WrongPass123!")
    end

    test "authenticates with username instead of email", %{attrs: attrs} do
      assert {:ok, result} = LocalAuthentication.authenticate(attrs.username, attrs.password)
      assert result.user.username == attrs.username
    end
  end

  describe "verify_token / 1" do
    setup do
      # Create a user and generate tokens
      attrs = %{
        email: "token@example.com",
        username: "tokenuser",
        password: "TokenPass123!",
        first_name: "Token",
        last_name: "User"
      }

      {:ok, _user} = LocalAuthentication.register_user(attrs)
      {:ok, auth_result} = LocalAuthentication.authenticate(attrs.email, attrs.password)

      {:ok, tokens: auth_result.tokens}
    end

    test "successfully verifies a valid access token", %{tokens: tokens} do
      assert {:ok, verified_user} = LocalAuthentication.verify_token(tokens.access_token)
      assert verified_user.id
    end

    test "fails with invalid token" do
      assert {:error, :invalid_token} = LocalAuthentication.verify_token("invalid.token.here")
    end

    test "fails with malformed token" do
      assert {:error, :invalid_token} = LocalAuthentication.verify_token("not - even - close")
    end
  end

  describe "refresh_tokens / 1" do
    setup do
      attrs = %{
        email: "refresh@example.com",
        username: "refreshuser",
        password: "RefreshPass123!",
        first_name: "Refresh",
        last_name: "User"
      }

      {:ok, _user} = LocalAuthentication.register_user(attrs)
      {:ok, auth_result} = LocalAuthentication.authenticate(attrs.email, attrs.password)

      {:ok, tokens: auth_result.tokens}
    end

    test "successfully refreshes tokens with valid refresh token",
         %{tokens: tokens} do
      assert {:ok, new_tokens} = LocalAuthentication.refresh_tokens(tokens.refresh_token)
      assert new_tokens.access_token != tokens.access_token
      assert new_tokens.refresh_token != tokens.refresh_token
      assert new_tokens.expires_in == 900
    end

    test "fails with access token instead of refresh token",
         %{tokens: tokens} do
      assert {:error, :invalid_token_type} =
               LocalAuthentication.refresh_tokens(tokens.access_token)
    end
  end

  describe "enable_mfa / 1" do
    setup do
      attrs = %{
        email: "mfa@example.com",
        username: "mfauser",
        password: "MfaPass123!",
        first_name: "MFA",
        last_name: "User"
      }

      {:ok, mfa_setup_user} = LocalAuthentication.register_user(attrs)
      {:ok, user: mfa_setup_user}
    end

    test "successfully enables MFA for a user", %{user: mfa_user} do
      assert {:ok, mfa_result} = LocalAuthentication.enable_mfa(mfa_user.id)
      assert mfa_result.secret
      assert mfa_result.qr_code
      assert mfa_result.otpauth_url
      assert String.starts_with?(mfa_result.otpauth_url, "otpauth://totp/")
    end
  end

  describe "verify_mfa / 2" do
    test "returns error when MFA is not enabled" do
      assert {:error, :mfa_not_enabled} = LocalAuthentication.verify_mfa("user-id", "123_456")
    end
  end

  describe "change_password / 3" do
    setup do
      attrs = %{
        email: "changepass@example.com",
        username: "changepassuser",
        password: "OldPass123!",
        first_name: "Change",
        last_name: "Pass"
      }

      {:ok, change_pass_user} = LocalAuthentication.register_user(attrs)
      {:ok, user: change_pass_user, old_password: attrs.password}
    end

    test "successfully changes password with valid current password", %{
      user: change_user,
      old_password: old_password
    } do
      new_password = "NewPass456!"

      assert :ok = LocalAuthentication.change_password(change_user.id, old_password, new_password)

      # Verify can authenticate with new password
      assert {:ok, _} = LocalAuthentication.authenticate(change_user.email, new_password)

      # Verify old password no longer works
      assert {:error, :invalid_credentials} =
               LocalAuthentication.authenticate(change_user.email, old_password)
    end

    test "fails with incorrect current password", %{user: incorrect_user} do
      assert {:error, :invalid_credentials} =
               LocalAuthentication.change_password(
                 incorrect_user.id,
                 "WrongPass123!",
                 "NewPass456!"
               )
    end

    test "fails when new password doesn't meet requirements", %{
      user: req_user,
      old_password: old_password
    } do
      assert {:error, :password_complexity_not_met} =
               LocalAuthentication.change_password(req_user.id, old_password, "simple")
    end
  end

  describe "request_password_reset / 1" do
    setup do
      attrs = %{
        email: "reset@example.com",
        username: "resetuser",
        password: "ResetPass123!",
        first_name: "Reset",
        last_name: "User"
      }

      {:ok, reset_req_user} = LocalAuthentication.register_user(attrs)
      {:ok, user: reset_req_user}
    end

    test "successfully generates reset token for valid email", %{user: reset_req_user} do
      assert {:ok, result} = LocalAuthentication.request_password_reset(reset_req_user.email)
      assert result.token
      assert result.user_email == reset_req_user.email
    end
  end

  describe "reset_password / 2" do
    setup do
      attrs = %{
        email: "resetpass@example.com",
        username: "resetpassuser",
        password: "OldResetPass123!",
        first_name: "Reset",
        last_name: "Password"
      }

      {:ok, reset_pass_user} = LocalAuthentication.register_user(attrs)
      {:ok, reset_result} = LocalAuthentication.request_password_reset(reset_pass_user.email)

      {:ok, user: reset_pass_user, reset_token: reset_result.token}
    end

    test "successfully resets password with valid token",
         %{user: reset_user, reset_token: reset_token} do
      new_password = "NewResetPass456!"

      assert :ok = LocalAuthentication.reset_password(reset_token, new_password)

      # Verify can authenticate with new password
      assert {:ok, _} = LocalAuthentication.authenticate(reset_user.email, new_password)
    end

    test "fails with invalid new password", %{reset_token: reset_token} do
      assert {:error, :password_complexity_not_met} =
               LocalAuthentication.reset_password(reset_token, "simple")
    end
  end

  describe "get_user_permissions / 1" do
    setup do
      attrs = %{
        email: "perms@example.com",
        username: "permsuser",
        password: "PermsPass123!",
        first_name: "Perms",
        last_name: "User"
      }

      {:ok, perms_user} = LocalAuthentication.register_user(attrs)
      {:ok, user: perms_user}
    end

    test "returns empty permissions for user without roles", %{user: perms_user} do
      assert {:ok, permissions} = LocalAuthentication.get_user_permissions(perms_user.id)
      assert permissions == []
    end
  end

  describe "GenServer callbacks" do
    test "handle_call / 3 for :get_signing_key returns the signing key" do
      {:ok, pid} = LocalAuthentication.start_link([])

      assert {:reply, signing_key, _state} =
               GenServer.call(pid, :get_signing_key)

      assert is_binary(signing_key)
      Process.exit(pid, :normal)
    end
  end

  describe "edge cases and error handling" do
    test "handles concurrent registration attempts gracefully" do
      attrs = %{
        email: "concurrent@example.com",
        username: "concurrent",
        password: "ConcurrentPass123!",
        first_name: "Concurrent",
        last_name: "User"
      }

      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            LocalAuthentication.register_user(attrs)
          end)
        end

      results = Task.await_many(tasks)

      # At least one should succeed
      assert Enum.any?(results, fn
               {:ok, _} -> true
               _ -> false
             end)
    end

    test "handles malformed JWT tokens gracefully" do
      malformed_tokens = [
        "",
        ".",
        "..",
        "header.payload",
        "header.payload.signature.extra",
        Base.encode64("not a jwt")
      ]

      for token <- malformed_tokens do
        assert {:error, _} = LocalAuthentication.verify_token(token)
      end
    end
  end

  describe "performance characteristics" do
    @tag :performance
    test "password hashing completes within acceptable time" do
      password = "TestPassword123!"

      {result, time_us} =
        measure_time(fn ->
          LocalAuthentication.register_user(%{
            email: "perf@example.com",
            username: "perfuser",
            password: password,
            first_name: "Perf",
            last_name: "User"
          })
        end)

      assert {:ok, _} = result
      # Password hashing should complete within 500ms
      assert time_us < 500_000
    end

    @tag :performance
    test "token generation is fast" do
      attrs = %{
        email: "tokenperf@example.com",
        username: "tokenperfuser",
        password: "TokenPerf123!",
        first_name: "Token",
        last_name: "Perf"
      }

      {:ok, _} = LocalAuthentication.register_user(attrs)

      {result, time_us} =
        measure_time(fn ->
          LocalAuthentication.authenticate(attrs.email, attrs.password)
        end)

      assert {:ok, _} = result
      # Token generation should be very fast (< 50ms)
      assert time_us < 50_000
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
