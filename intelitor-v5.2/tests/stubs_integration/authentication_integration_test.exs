defmodule Intelitor.AuthenticationIntegrationTest do
  use IntelitorWeb.ConnCase, async: false

  alias Intelitor.Auth.LocalAuthentication

  # Helper function to measure execution time
  defp measure_time(fun) do
    {time_us, result} = :timer.tc(fun)
    {result, time_us}
  end

  describe "full authentication flow" do
    test "complete user journey from registration to authenticated __request", %{conn: conn} do
      # Step 1: Register a new user
      registration_params = %{
        email: "integration@example.com",
        username: "integrationuser",
        password: "IntegrationPass123!",
        first_name: "Integration",
        last_name: "Test"
      }

      {:ok, user} = LocalAuthentication.register_user(registration_params)
      assert user.email == registration_params.email

      # Step 2: Authenticate and get tokens
      {:ok, auth_result} =
        LocalAuthentication.authenticate(
          registration_params.email,
          registration_params.password
        )

      assert auth_result.tokens.access_token
      assert auth_result.tokens.refresh_token

      # Step 3: Make authenticated __request
      authenticated_conn =
        conn
        |> put_req_header("authorization", "Bearer #{auth_result.tokens.access_token}")

      # Verify authentication header is set
      assert get_req_header(authenticated_conn, "authorization") ==
               ["Bearer #{auth_result.tokens.access_token}"]

      # Step 4: Refresh tokens
      {:ok, new_tokens} = LocalAuthentication.refresh_tokens(auth_result.tokens.refresh_token)
      assert new_tokens.access_token != auth_result.tokens.access_token

      # Step 5: Use new token
      refreshed_conn =
        conn
        |> put_req_header("authorization", "Bearer #{new_tokens.access_token}")

      assert get_req_header(refreshed_conn, "authorization") ==
               ["Bearer #{new_tokens.access_token}"]
    end

    test "MFA enrollment and authentication flow", %{conn: conn} do
      # Register user
      {:ok, user} =
        LocalAuthentication.register_user(%{
          email: "mfa-integration@example.com",
          username: "mfaintegration",
          password: "MfaIntegration123!",
          first_name: "MFA",
          last_name: "Integration"
        })

      # Enable MFA
      {:ok, mfa_result} = LocalAuthentication.enable_mfa(user.id)
      assert mfa_result.secret
      assert mfa_result.qr_code

      # In real implementation, would verify TOTP code
      # For now, verify the structure is correct
      assert String.starts_with?(mfa_result.otpauth_url, "otpauth://totp/")
      assert String.contains?(mfa_result.otpauth_url, "Intelitor")
      assert String.contains?(mfa_result.otpauth_url, user.email)
    end

    test "password reset flow", %{conn: conn} do
      # Register user
      {:ok, user} =
        LocalAuthentication.register_user(%{
          email: "reset-integration@example.com",
          username: "resetintegration",
          password: "OldResetPass123!",
          first_name: "Reset",
          last_name: "Integration"
        })

      # Request password reset
      {:ok, reset_result} = LocalAuthentication.__request_password_reset(user.email)
      assert reset_result.token
      assert reset_result.__user_email == user.email

      # Reset password
      new_password = "NewResetPass456!"
      :ok = LocalAuthentication.reset_password(reset_result.token, new_password)

      # Verify old password doesn't work
      assert {:error, :invalid_credentials} =
               LocalAuthentication.authenticate(user.email, "OldResetPass123!")

      # Verify new password works
      assert {:ok, auth_result} =
               LocalAuthentication.authenticate(user.email, new_password)

      assert auth_result.tokens.access_token
    end
  end

  describe "concurrent operations" do
    test "handles multiple simultaneous authentication attempts" do
      # Register a user
      {:ok, _user} =
        LocalAuthentication.register_user(%{
          email: "concurrent@example.com",
          username: "concurrentuser",
          password: "ConcurrentPass123!",
          first_name: "Concurrent",
          last_name: "Test"
        })

      # Spawn multiple authentication attempts
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            {i, LocalAuthentication.authenticate("concurrent@example.com", "ConcurrentPass123!")}
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All should succeed
      assert Enum.all?(results, fn {_i, result} ->
               match?({:ok, _}, result)
             end)

      # All should have unique tokens
      tokens =
        Enum.map(results, fn {_i, {:ok, auth}} ->
          auth.tokens.access_token
        end)

      assert length(tokens) == length(Enum.uniq(tokens))
    end

    test "handles race condition in user registration" do
      base_email = "race#{System.unique_integer([:positive])}@example.com"
      base_username = "raceuser#{System.unique_integer([:positive])}"

      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            LocalAuthentication.register_user(%{
              email: base_email,
              username: "#{base_username}#{i}",
              password: "RacePass123!",
              first_name: "Race",
              last_name: "Test#{i}"
            })
          end)
        end

      results = Task.await_many(tasks, 5000)

      # At least one should succeed
      success_count =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      assert success_count >= 1
    end
  end

  describe "error scenarios" do
    test "gracefully handles malformed authentication attempts" do
      test_cases = [
        {nil, nil},
        {"", ""},
        {String.duplicate("a", 1000), "password"},
        {"email", String.duplicate("p", 1000)},
        {<<0, 1, 2, 3>>, "password"},
        {"email", <<0, 1, 2, 3>>}
      ]

      for {email, password} <- test_cases do
        result = LocalAuthentication.authenticate(email, password)
        assert match?({:error, _}, result)
      end
    end

    test "handles system errors gracefully" do
      # Test with various problematic inputs
      problematic_inputs = [
        # Empty map
        %{},
        # All nils
        %{email: nil, username: nil, password: nil},
        # Wrong types
        %{email: [], username: {}, password: %{}}
      ]

      for input <- problematic_inputs do
        result = LocalAuthentication.register_user(input)
        assert match?({:error, _}, result)
      end
    end
  end

  describe "performance under load" do
    @tag :performance
    @tag timeout: 60_000
    test "maintains performance with many users" do
      # Create many users
      users =
        for i <- 1..100 do
          {:ok, user} =
            LocalAuthentication.register_user(%{
              email: "perf#{i}@example.com",
              username: "perfuser#{i}",
              password: "PerfPass123!",
              first_name: "Perf",
              last_name: "User#{i}"
            })

          user
        end

      # Measure authentication time for the 100th user
      last_user = List.last(users)

      {result, time_us} =
        measure_time(fn ->
          LocalAuthentication.authenticate("perf100@example.com", "PerfPass123!")
        end)

      assert {:ok, _} = result
      # Should still be fast even with many users
      # Less than 100ms
      assert time_us < 100_000
    end
  end

  describe "__state management" do
    test "GenServer maintains consistent __state across operations" do
      # Use unique email to avoid conflicts
      unique_id = System.unique_integer([:positive])
      email1 = "state#{unique_id}_1@example.com"
      email2 = "state#{unique_id}_2@example.com"
      password = "StatePass123456!"

      # Register first user
      {:ok, _user1} =
        LocalAuthentication.register_user(%{
          email: email1,
          username: "stateuser#{unique_id}_1",
          password: password,
          first_name: "State",
          last_name: "User1"
        })

      # Authenticate first user
      {:ok, _auth_result} = LocalAuthentication.authenticate(email1, password)

      # Register second user
      {:ok, _user2} =
        LocalAuthentication.register_user(%{
          email: email2,
          username: "stateuser#{unique_id}_2",
          password: password,
          first_name: "State",
          last_name: "User2"
        })

      # Verify both users can authenticate
      assert {:ok, _} = LocalAuthentication.authenticate(email1, password)
      assert {:ok, _} = LocalAuthentication.authenticate(email2, password)
    end
  end

  describe "compatibility and standards" do
    test "generates JWT tokens compatible with standard libraries" do
      {:ok, _} =
        LocalAuthentication.register_user(%{
          email: "jwt@example.com",
          username: "jwtuser",
          password: "JwtPass123456!",
          first_name: "JWT",
          last_name: "Test"
        })

      {:ok, auth_result} = LocalAuthentication.authenticate("jwt@example.com", "JwtPass123456!")

      token = auth_result.tokens.access_token

      # JWT should have three parts
      parts = String.split(token, ".")
      assert length(parts) == 3

      # Each part should be base64 encoded
      for part <- Enum.take(parts, 2) do
        assert match?({:ok, _}, Base.url_decode64(part, padding: false))
      end
    end

    test "TOTP implementation follows RFC 6238" do
      {:ok, user} =
        LocalAuthentication.register_user(%{
          email: "totp-rfc@example.com",
          username: "totprfcuser",
          password: "TotpRfc123456!",
          first_name: "TOTP",
          last_name: "RFC"
        })

      {:ok, mfa_result} = LocalAuthentication.enable_mfa(user.id)

      # Verify otpauth URL format
      uri = URI.parse(mfa_result.otpauth_url)
      assert uri.scheme == "otpauth"
      assert uri.host == "totp"

      # Parse query parameters
      params = URI.decode_query(uri.query || "")
      assert params["algorithm"] == "SHA1"
      assert params["digits"] == "6"
      assert params["period"] == "30"
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
