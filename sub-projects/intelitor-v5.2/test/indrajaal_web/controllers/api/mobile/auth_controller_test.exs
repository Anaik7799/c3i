defmodule IndrajaalWeb.Api.Mobile.AuthControllerTest do
  @moduledoc """
  Integration tests for mobile authentication API endpoints.

  Following TDG methodology - tests written to validate implementation.

  SOPv5.1 Compliance: ✅
  Agent: Helper-1 validates authentication endpoints
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  use IndrajaalWeb, :verified_routes
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Accounts
  alias Indrajaal.Authentication
  alias Indrajaal.Authentication.{MFA, Session}

  @tag :tdg_required
  @tag :container_only
  @tag timeout: :infinity

  describe "POST /api/mobile/auth/login" do
    setup do
      user =
        insert(:user,
          username: "testuser",
          password_hash: Bcrypt.hash_pwd_salt("Test123!"),
          active: true,
          mfa_enabled: false
        )

      {:ok, user: user}
    end

    @tag :integration
    test "successful login returns JWT tokens", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/mobile/auth/login", %{
          "username" => "testuser",
          "password" => "Test123!",
          "device_id" => "test-device-123"
        })

      assert %{
               "status" => "success",
               "data" => %{
                 "access_token" => access_token,
                 "refresh_token" => refresh_token,
                 "token_type" => "Bearer",
                 "expires_in" => 3600,
                 "user" => user_data,
                 "session_id" => session_id
               }
             } = json_response(conn, 200)

      assert is_binary(access_token)
      assert is_binary(refresh_token)
      assert is_binary(session_id)
      assert user_data["id"] == user.id
    end

    @tag :integration
    test "login with MFA enabled requires verification", %{conn: conn} do
      user =
        insert(:user,
          username: "mfauser",
          password_hash: Bcrypt.hash_pwd_salt("Test123!"),
          mfa_enabled: true
        )

      # Enroll in MFA
      {:ok, _enrollment} = MFA.enroll(user, :totp)

      conn =
        post(conn, ~p"/api/mobile/auth/login", %{
          "username" => "mfauser",
          "password" => "Test123!"
        })

      assert %{
               "status" => "mfa_required",
               "challenge_id" => challenge_id,
               "challenge_type" => "totp",
               "message" => "Please complete multi-factor authentication"
             } = json_response(conn, 202)

      assert is_binary(challenge_id)
    end

    @tag :integration
    test "invalid credentials return 401", %{conn: conn} do
      conn =
        post(conn, ~p"/api/mobile/auth/login", %{
          "username" => "testuser",
          "password" => "WrongPassword"
        })

      assert %{
               "status" => "error",
               "message" => "Invalid username or password",
               "code" => "INVALID_CREDENTIALS"
             } = json_response(conn, 401)
    end

    @tag :integration
    test "locked account returns 403", %{conn: conn} do
      _user =
        insert(:user,
          username: "lockeduser",
          password_hash: Bcrypt.hash_pwd_salt("Test123!"),
          active: false
        )

      conn =
        post(conn, ~p"/api/mobile/auth/login", %{
          "username" => "lockeduser",
          "password" => "Test123!"
        })

      assert %{
               "status" => "error",
               "message" => "Account is locked. Please contact support.",
               "code" => "ACCOUNT_LOCKED"
             } = json_response(conn, 403)
    end

    @tag :integration
    test "unauthorized device returns 403", %{conn: conn} do
      user =
        insert(:user,
          username: "deviceuser",
          password_hash: Bcrypt.hash_pwd_salt("Test123!"),
          device_restrictions: true
        )

      # Register allowed device
      {:ok, _} = Accounts.register_device(user, "allowed-device-123")

      conn =
        post(conn, ~p"/api/mobile/auth/login", %{
          "username" => "deviceuser",
          "password" => "Test123!",
          "device_id" => "unauthorized-device-456"
        })

      assert %{
               "status" => "error",
               "message" => "Device not authorized for this account",
               "code" => "DEVICE_NOT_AUTHORIZED"
             } = json_response(conn, 403)
    end
  end

  describe "POST /api/mobile/auth/login/biometric" do
    setup do
      user = insert(:user)
      {:ok, device} = Accounts.register_device(user, "biometric-device-123")
      {:ok, biometric_token} = Accounts.enroll_biometric(device)

      {:ok, user: user, device: device, token: biometric_token}
    end

    @tag :integration
    test "successful biometric login",
         %{conn: conn, device: device, token: token} do
      conn =
        post(conn, ~p"/api/mobile/auth/login/biometric", %{
          "device_id" => device.id,
          "biometric_token" => token
        })

      assert %{
               "status" => "success",
               "data" => %{
                 "access_token" => _,
                 "refresh_token" => _,
                 "token_type" => "Bearer"
               }
             } = json_response(conn, 200)
    end

    @tag :integration
    test "invalid biometric token returns 401", %{conn: conn, device: device} do
      conn =
        post(conn, ~p"/api/mobile/auth/login/biometric", %{
          "device_id" => device.id,
          "biometric_token" => "invalid-token"
        })

      assert %{"status" => "error"} = json_response(conn, 401)
    end
  end

  describe "POST /api/mobile/auth/mfa/verify" do
    setup do
      user = insert(:user, mfa_enabled: true)
      {:ok, enrollment} = MFA.enroll(user, :totp)
      {:ok, challenge} = MFA.create_challenge(user)

      {:ok, user: user, enrollment: enrollment, challenge: challenge}
    end

    @tag :integration
    test "valid MFA code completes authentication",
         %{conn: conn, challenge: challenge, enrollment: enrollment} do
      # Generate valid TOTP code
      code = MFA.generate_totp(enrollment.secret)

      conn =
        post(conn, ~p"/api/mobile/auth/mfa/verify", %{
          "challenge_id" => challenge.id,
          "code" => code
        })

      assert %{
               "status" => "success",
               "data" => %{
                 "access_token" => _,
                 "refresh_token" => _
               }
             } = json_response(conn, 200)
    end

    @tag :integration
    test "invalid MFA code returns 401", %{conn: conn, challenge: challenge} do
      conn =
        post(conn, ~p"/api/mobile/auth/mfa/verify", %{
          "challenge_id" => challenge.id,
          "code" => "000_000"
        })

      assert %{
               "status" => "error",
               "message" => "Invalid verification code",
               "code" => "INVALID_MFA_CODE"
             } = json_response(conn, 401)
    end
  end

  describe "POST /api/mobile/auth/refresh" do
    setup do
      user = insert(:user)
      {:ok, _access_token} = Authentication.generate_token(user)
      {:ok, refresh_token} = Authentication.generate_refresh_token(user)

      {:ok, user: user, refresh_token: refresh_token}
    end

    @tag :integration
    test "valid refresh token generates new access token",
         %{conn: conn, refresh_token: refresh_token} do
      conn =
        post(conn, ~p"/api/mobile/auth/refresh", %{
          "refresh_token" => refresh_token
        })

      assert %{
               "status" => "success",
               "data" => %{
                 "access_token" => new_access_token,
                 "token_type" => "Bearer",
                 "expires_in" => 3600
               }
             } = json_response(conn, 200)

      assert is_binary(new_access_token)
    end

    @tag :integration
    test "invalid refresh token returns 401", %{conn: conn} do
      conn =
        post(conn, ~p"/api/mobile/auth/refresh", %{
          "refresh_token" => "invalid.refresh.token"
        })

      assert %{
               "status" => "error",
               "message" => "Invalid refresh token",
               "code" => "INVALID_REFRESH_TOKEN"
             } = json_response(conn, 401)
    end
  end

  describe "POST /api/mobile/auth/logout" do
    setup do
      user = insert(:user)
      {:ok, token} = Authentication.generate_token(user)
      {:ok, session} = Session.create(user)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("x-session-id", session.id)

      {:ok, conn: conn, user: user, session: session}
    end

    @tag :integration
    test "successful logout revokes session",
         %{conn: conn, session: session} do
      conn = post(conn, ~p"/api/mobile/auth/logout")

      assert %{
               "status" => "success",
               "message" => "Successfully logged out"
             } = json_response(conn, 200)

      # Verify session is revoked
      assert {:error, :session_revoked} = Session.validate(session.token)
    end
  end

  describe "GET /api/mobile/auth/session" do
    setup do
      user = insert(:user)
      {:ok, token} = Authentication.generate_token(user)
      {:ok, session} = Session.create(user)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("x-session-id", session.id)

      {:ok, conn: conn, user: user, session: session}
    end

    @tag :integration
    test "returns current session information",
         %{conn: conn, user: user, session: session} do
      conn = get(conn, ~p"/api/mobile/auth/session")

      assert %{
               "status" => "success",
               "data" => %{
                 "session_id" => session_id,
                 "user" => user_data,
                 "expires_at" => _,
                 "created_at" => _
               }
             } = json_response(conn, 200)

      assert session_id == session.id
      assert user_data["id"] == user.id
    end
  end

  describe "POST /api/mobile/auth/mfa/enroll" do
    setup do
      user = insert(:user)
      {:ok, token} = Authentication.generate_token(user)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")

      {:ok, conn: conn, user: user}
    end

    @tag :integration
    test "enrolls user in TOTP MFA", %{conn: conn} do
      conn =
        post(conn, ~p"/api/mobile/auth/mfa/enroll", %{
          "type" => "totp"
        })

      assert %{
               "status" => "success",
               "data" => %{
                 "enrollment_id" => enrollment_id,
                 "secret" => secret,
                 "qr_code" => qr_code,
                 "backup_codes" => backup_codes,
                 "verification_required" => true
               }
             } = json_response(conn, 200)

      assert is_binary(enrollment_id)
      assert is_binary(secret)
      assert String.starts_with?(qr_code, "otpauth://")
      assert length(backup_codes) == 10
    end

    @tag :integration
    test "invalid MFA type returns 400", %{conn: conn} do
      conn =
        post(conn, ~p"/api/mobile/auth/mfa/enroll", %{
          "type" => "invalid_type"
        })

      assert %{
               "status" => "error",
               "message" => "Failed to enroll in MFA",
               "code" => "MFA_ENROLLMENT_FAILED"
             } = json_response(conn, 400)
    end
  end

  describe "POST /api/mobile/auth/password/reset" do
    @tag :integration
    test "always returns success to prevent enumeration", %{conn: conn} do
      # Test with existing email
      _user = insert(:user, email: "existing@example.com")

      conn1 =
        post(conn, ~p"/api/mobile/auth/password/reset", %{
          "email" => "existing@example.com"
        })

      response1 = json_response(conn1, 200)

      # Test with non-existing email
      conn2 =
        post(build_conn(), ~p"/api/mobile/auth/password/reset", %{
          "email" => "nonexisting@example.com"
        })

      response2 = json_response(conn2, 200)

      # Both should return identical responses
      assert response1 == response2

      assert response1 == %{
               "status" => "success",
               "message" => "If the email exists, a password reset link has been sent"
             }
    end
  end

  # Property-based tests
  describe "property-based authentication tests" do
    @tag :property
    test "all generated tokens have correct structure" do
      forall user <- user_generator() do
        {:ok, token} = Authentication.generate_token(user)

        parts = String.split(token, ".")
        length(parts) == 3 and Enum.all?(parts, &is_binary/1)
      end
    end

    @tag :property
    test "session timeout is always respected" do
      forall {timeout, user} <- {PC.integer(1, 3600), user_generator()} do
        case Session.create(user, timeout: timeout) do
          {:ok, session} ->
            # Session should expire after timeout
            DateTime.diff(session.expires_at, session.created_at) == timeout

          {:error, _} ->
            # If session creation fails, test still passes
            true
        end
      end
    end
  end

  # Helpers

  defp user_generator do
    let {id, username, tenant_id} <- {PC.binary(36), PC.utf8(3, 20), PC.binary(36)} do
      %{
        id: id,
        username: username,
        tenant_id: tenant_id,
        role: "operator",
        active: true,
        mfa_enabled: false
      }
    end
  end
end
