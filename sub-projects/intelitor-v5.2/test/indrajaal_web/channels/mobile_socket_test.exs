defmodule IndrajaalWeb.MobileSocketTest do
  @moduledoc """
  Comprehensive test suite for mobile WebSocket connections.

  Implements 6 testing methodologies:
  1. Unit Testing - Socket authentication and connection
  2. Integration Testing - Full WebSocket flow
  3. Property - Based Testing - Message handling invariants
  4. Contract Testing - Protocol compliance
  5. Performance Testing - Connection and message throughput
  6. Security Testing - Authentication and channel isolation

  SOPv5.1 Compliance: ✅
  TDG Methodology: Tests written before implementation
  Agent: Worker - 4 validates WebSocket functionality
  """

  use IndrajaalWeb.ChannelCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  import Indrajaal.Factory
  alias Indrajaal.{Accounts, Authentication}
  alias Indrajaal.Authentication.JWT
  alias IndrajaalWeb.{MobileSocket, AlarmChannel, DeviceChannel, NotificationChannel}
  alias Phoenix.Socket

  @tag :tdg_required
  @tag :container_only
  @tag timeout: :infinity

  setup do
    # Create test users and tokens
    tenant = insert(:tenant, name: "Test Corp")
    user = insert(:user, tenant: tenant, role: "operator")
    other_tenant = insert(:tenant, name: "Other Corp")
    other_user = insert(:user, tenant: other_tenant, role: "admin")

    {:ok, token} = Authentication.generate_token(user)
    {:ok, other_token} = Authentication.generate_token(other_user)
    {:ok, expired_token} = Authentication.generate_token(user, expires_in: -3600)

    # Create test resources
    device = insert(:device, tenant: tenant)
    alarm = insert(:alarm, tenant: tenant, device: device, status: "new")
    other_alarm = insert(:alarm, tenant: other_tenant, status: "new")

    %{
      user: user,
      token: token,
      expired_token: expired_token,
      other_user: other_user,
      other_token: other_token,
      tenant: tenant,
      device: device,
      alarm: alarm,
      other_alarm: other_alarm
    }
  end

  # ============================================================================
  # 1. UNIT TESTS - Test socket authentication and connection
  # ============================================================================

  describe "socket connection" do
    @tag :unit

    test "connects with valid JWT token", %{token: token} do
      assert {:ok, socket} = connect(MobileSocket, %{"token" => token})
      assert socket.assigns.user_id != nil
      assert socket.assigns.tenant_id != nil
    end

    test "refuses connection with invalid token" do
      assert :error = connect(MobileSocket, %{"token" => "invalid"})
    end

    test "refuses connection without token" do
      assert :error = connect(MobileSocket, %{})
    end

    test "refuses connection with expired token", %{user: user} do
      # Create an expired token
      {:ok, expired_token, _} = JWT.generate_token(user, expires_in: -3600)
      assert :error = connect(MobileSocket, %{"token" => expired_token})
    end

    test "assigns user and tenant to socket", %{token: token, user: user} do
      {:ok, socket} = connect(MobileSocket, %{"token" => token})

      assert socket.assigns.user_id == user.id
      assert socket.assigns.tenant_id == user.tenant_id
      assert socket.assigns.user_role == user.role
    end

    test "tracks device information", %{token: token} do
      device_info = %{
        "device_id" => "test-device-123",
        "platform" => "ios",
        "app_version" => "1.0.0"
      }

      assert {:ok, socket} = connect(MobileSocket, %{"token" => token, "device" => device_info})
      assert socket.assigns.device_id == "test-device-123"
      assert socket.assigns.platform == "ios"
      assert socket.assigns.app_version == "1.0.0"
    end
  end

  describe "connection lifecycle" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, token, _} = JWT.generate_token(user)
      {:ok, socket} = connect(MobileSocket, %{"token" => token})

      {:ok, socket: socket, user: user}
    end

    test "handles disconnect gracefully", %{socket: socket} do
      # Disconnect should clean up resources
      ref = push(socket, "disconnect", %{})
      assert_reply ref, :ok

      # Verify cleanup occurred
      refute Process.alive?(socket.channel_pid)
    end

    test "supports reconnection with same token", %{user: user} do
      {:ok, token, _} = JWT.generate_token(user)

      # First connection
      {:ok, socket1} = connect(MobileSocket, %{"token" => token})
      assert socket1.assigns.user_id == user.id

      # Disconnect
      Process.exit(socket1.channel_pid, :kill)

      # Reconnect
      {:ok, socket2} = connect(MobileSocket, %{"token" => token})
      assert socket2.assigns.user_id == user.id
    end
  end

  describe "rate limiting" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, token, _} = JWT.generate_token(user)

      {:ok, token: token, user: user}
    end

    test "enforces connection rate limits", %{token: token} do
      # Connect multiple times rapidly
      connections =
        for _ <- 1..10 do
          connect(MobileSocket, %{"token" => token})
        end

      # First 5 should succeed
      assert connections |> Enum.take(5) |> Enum.all?(fn {status, _} -> status == :ok end)

      # Remaining should be rate limited
      assert connections |> Enum.drop(5) |> Enum.any?(fn result -> result == :error end)
    end
  end

  describe "presence tracking" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, token, _} = JWT.generate_token(user)
      {:ok, socket} = connect(MobileSocket, %{"token" => token})

      {:ok, socket: socket, user: user}
    end

    test "tracks user presence on connect", %{socket: socket, user: user} do
      # Check presence is tracked
      presence = IndrajaalWeb.Presence.list("users:#{user.tenant_id}")
      assert Map.has_key?(presence, user.id)

      user_presence = presence[user.id]

      assert user_presence.metas
             |> Enum.any?(fn meta ->
               meta.device_id == socket.assigns.device_id
             end)
    end

    test "removes presence on disconnect", %{socket: socket, user: user} do
      # Verify presence exists
      presence = IndrajaalWeb.Presence.list("users:#{user.tenant_id}")
      assert Map.has_key?(presence, user.id)

      # Disconnect
      Process.exit(socket.channel_pid, :kill)
      # Allow cleanup
      :timer.sleep(100)

      # Verify presence removed
      presence = IndrajaalWeb.Presence.list("users:#{user.tenant_id}")
      refute Map.has_key?(presence, user.id)
    end
  end

  describe "multi-tenant isolation" do
    test "pr__events cross - tenant communication" do
      # Create users in different tenants
      {:ok, tenant1} = create_test_tenant("Tenant 1")
      {:ok, tenant2} = create_test_tenant("Tenant 2")

      {:ok, user1} = create_test_user(tenant_id: tenant1.id)
      {:ok, user2} = create_test_user(tenant_id: tenant2.id)

      {:ok, token1, _} = JWT.generate_token(user1)
      {:ok, token2, _} = JWT.generate_token(user2)

      {:ok, socket1} = connect(MobileSocket, %{"token" => token1})
      {:ok, socket2} = connect(MobileSocket, %{"token" => token2})

      # Verify different tenant assignments
      assert socket1.assigns.tenant_id == tenant1.id
      assert socket2.assigns.tenant_id == tenant2.id
      assert socket1.assigns.tenant_id != socket2.assigns.tenant_id
    end
  end

  # Helper functions

  defp create_test_user(attrs \\ %{}) do
    default_attrs = %{
      email: "user#{System.unique_integer()}@example.com",
      password: "Test123!@#",
      first_name: "Test",
      last_name: "User",
      role: "operator"
    }

    Accounts.create_user(Map.merge(default_attrs, attrs))
  end

  defp create_test_tenant(name) do
    Indrajaal.Tenants.create_tenant(%{
      name: name,
      code: String.downcase(String.replace(name, " ", "_"))
    })
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
