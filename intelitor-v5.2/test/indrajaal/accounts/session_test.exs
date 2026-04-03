defmodule Indrajaal.Accounts.SessionTest do
  use Indrajaal.DataCase
  import Indrajaal.AccountsComprehensiveFactory
  alias Indrajaal.Accounts
  alias Indrajaal.Accounts.Session

  describe "session creation" do
    setup do
      tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      {:ok, tenant: tenant, user: user}
    end

    test "creates session with valid attributes",
         %{tenant: tenant, user: user} do
      attrs = %{
        user_id: user.id,
        tenant_id: tenant.id,
        ip_address: "192.168.1.100",
        user_agent: "Mozilla / 5.0 Test Browser"
      }

      assert {:ok, session} = Accounts.create_session(attrs)
      assert session.user_id == user.id
      assert session.tenant_id == tenant.id
      assert session.ip_address == "192.168.1.100"
      assert session.user_agent == "Mozilla / 5.0 Test Browser"
      assert session.token != nil
      assert session.active == true
      assert session.expires_at != nil
    end

    test "validates required fields", %{tenant: tenant} do
      assert {:error, error} = Accounts.create_session(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "user_id: is required"
    end

    test "generates unique token", %{tenant: tenant, user: user} do
      attrs = %{
        user_id: user.id,
        tenant_id: tenant.id
      }

      {:ok, session1} = Accounts.create_session(attrs)
      {:ok, session2} = Accounts.create_session(attrs)

      assert session1.token != session2.token
    end

    test "sets default expiration", %{tenant: tenant, user: user} do
      attrs = %{
        user_id: user.id,
        tenant_id: tenant.id
      }

      {:ok, session} = Accounts.create_session(attrs)

      # Default should be 8 hours from now
      expected_expiry = DateTime.add(DateTime.utc_now(), 8 * 3600, :second)
      diff = DateTime.diff(session.expires_at, expected_expiry)

      # Allow 60 seconds difference for test execution time
      assert abs(diff) < 60
    end

    test "creates session with custom expiration",
         %{tenant: tenant, user: user} do
      custom_expiry = DateTime.add(DateTime.utc_now(), 24 * 3600, :second)

      attrs = %{
        user_id: user.id,
        tenant_id: tenant.id,
        expires_at: custom_expiry
      }

      {:ok, session} = Accounts.create_session(attrs)
      assert DateTime.compare(session.expires_at, custom_expiry) == :eq
    end

    test "creates session with metadata", %{tenant: tenant, user: user} do
      metadata = %{
        "device_id" => "device123",
        "app_version" => "1.2.3",
        "platform" => "iOS"
      }

      attrs = %{
        user_id: user.id,
        tenant_id: tenant.id,
        metadata: metadata
      }

      {:ok, session} = Accounts.create_session(attrs)
      assert session.metadata["device_id"] == "device123"
      assert session.metadata["platform"] == "iOS"
    end

    test "creates session with location data", %{tenant: tenant, user: user} do
      attrs = %{
        user_id: user.id,
        tenant_id: tenant.id,
        ip_address: "8.8.8.8",
        location: %{
          "city" => "Mountain View",
          "country" => "US",
          "lat" => 37.4223,
          "lon" => -122.084
        }
      }

      {:ok, session} = Accounts.create_session(attrs)
      assert session.location["city"] == "Mountain View"
    end

    test "tracks device type", %{tenant: tenant, user: user} do
      device_types = ["desktop", "mobile", "tablet", "api"]

      for device_type <- device_types do
        attrs = %{
          user_id: user.id,
          tenant_id: tenant.id,
          device_type: device_type
        }

        assert {:ok, session} = Accounts.create_session(attrs)
        assert session.device_type == device_type
      end
    end
  end

  describe "session queries" do
    setup do
      tenant = insert(:tenant)
      users = bulk_create_users(tenant, 10)
      sessions = bulk_create_sessions(users, 50)
      {:ok, tenant: tenant, users: users, sessions: sessions}
    end

    test "lists all sessions for tenant",
         %{tenant: tenant, sessions: sessions} do
      result = Accounts.list_sessions!(tenant_id: tenant.id)
      assert length(result) >= length(sessions)
      assert Enum.all?(result, &(&1.tenant_id == tenant.id))
    end

    test "lists sessions for specific user", %{users: users} do
      user = List.first(users)

      user_sessions =
        Accounts.list_sessions!(
          tenant_id: user.tenant_id,
          filter: [user_id: user.id]
        )

      assert Enum.all?(user_sessions, &(&1.user_id == user.id))
    end

    test "filters active sessions", %{tenant: tenant} do
      # Create expired session
      user = insert(:user, tenant_id: tenant.id)

      insert(:session,
        user_id: user.id,
        tenant_id: tenant.id,
        active: false
      )

      active_sessions =
        Accounts.list_sessions!(
          tenant_id: tenant.id,
          filter: [active: true]
        )

      assert Enum.all?(active_sessions, &(&1.active == true))
    end

    test "filters expired sessions", %{tenant: tenant} do
      # Create expired session
      user = insert(:user, tenant_id: tenant.id)

      insert(:session,
        user_id: user.id,
        tenant_id: tenant.id,
        expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      )

      now = DateTime.utc_now()

      expired_sessions =
        Accounts.list_sessions!(
          tenant_id: tenant.id,
          filter: [expires_at: {:lt, now}]
        )

      assert length(expired_sessions) > 0
    end

    test "filters by device type", %{tenant: tenant} do
      # Create mobile session
      user = insert(:user, tenant_id: tenant.id)

      mobile_session =
        insert(:session,
          user_id: user.id,
          tenant_id: tenant.id,
          device_type: "mobile"
        )

      mobile_sessions =
        Accounts.list_sessions!(
          tenant_id: tenant.id,
          filter: [device_type: "mobile"]
        )

      assert Enum.any?(mobile_sessions, &(&1.id == mobile_session.id))
    end

    test "filters by IP address", %{tenant: tenant} do
      user = insert(:user, tenant_id: tenant.id)

      session =
        insert(:session,
          user_id: user.id,
          tenant_id: tenant.id,
          ip_address: "10.0.0.1"
        )

      ip_sessions =
        Accounts.list_sessions!(
          tenant_id: tenant.id,
          filter: [ip_address: "10.0.0.1"]
        )

      assert Enum.any?(ip_sessions, &(&1.id == session.id))
    end

    test "sorts by last activity", %{tenant: tenant} do
      sessions =
        Accounts.list_sessions!(
          tenant_id: tenant.id,
          sort: [last_activity: :desc]
        )

      activities =
        sessions
        |> Enum.map(& &1.last_activity)
        # Remove nils
        |> Enum.filter(& &1)

      assert activities == Enum.sort(activities, {:desc, DateTime})
    end

    test "paginates results", %{tenant: tenant} do
      page1 =
        Accounts.list_sessions!(
          tenant_id: tenant.id,
          page: [limit: 20, offset: 0]
        )

      page2 =
        Accounts.list_sessions!(
          tenant_id: tenant.id,
          page: [limit: 20, offset: 20]
        )

      assert length(page1) == 20
      # We created 50+ sessions
      assert length(page2) >= 10

      # No overlap
      page1_ids = MapSet.new(page1, & &1.id)
      page2_ids = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(page1_ids, page2_ids)
    end
  end

  describe "session validation" do
    setup do
      tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      session = insert(:session, user_id: user.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, user: user, session: session}
    end

    test "validates active session", %{session: session} do
      assert {:ok, validated} = Accounts.validate_session(session.token)
      assert validated.id == session.id
      assert validated.active == true
    end

    test "fails validation for inactive session", %{session: session} do
      {:ok, _} = Accounts.update_session(session, %{active: false})

      assert {:error, :invalid_session} = Accounts.validate_session(session.token)
    end

    test "fails validation for expired session", %{session: session} do
      {:ok, _} =
        Accounts.update_session(session, %{
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        })

      assert {:error, :session_expired} = Accounts.validate_session(session.token)
    end

    test "fails validation for non - existent token" do
      assert {:error, :invalid_session} = Accounts.validate_session("invalid-token")
    end

    test "updates last activity on validation", %{session: session} do
      old_activity = session.last_activity

      # Wait a bit to ensure time difference
      :timer.sleep(100)

      {:ok, validated} = Accounts.validate_session(session.token)

      assert DateTime.compare(
               validated.last_activity,
               old_activity || session.inserted_at
             ) == :gt
    end
  end

  describe "session updates" do
    setup do
      tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      session = insert(:session, user_id: user.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, user: user, session: session}
    end

    test "extends session expiration", %{session: session} do
      new_expiry = DateTime.add(DateTime.utc_now(), 24 * 3600, :second)

      assert {:ok, updated} =
               Accounts.update_session(session, %{
                 expires_at: new_expiry
               })

      assert DateTime.compare(updated.expires_at, new_expiry) == :eq
    end

    test "updates session metadata", %{session: session} do
      metadata = %{
        "last_page" => "/dashboard",
        "actions_count" => 42
      }

      assert {:ok, updated} =
               Accounts.update_session(session, %{
                 metadata: metadata
               })

      assert updated.metadata["last_page"] == "/dashboard"
      assert updated.metadata["actions_count"] == 42
    end

    test "terminates session", %{session: session} do
      assert {:ok, terminated} = Accounts.terminate_session(session, "user_logout")

      assert terminated.active == false
      assert terminated.terminated_at != nil
      assert terminated.terminated_reason == "user_logout"
    end

    test "prevents updates to terminated session", %{session: session} do
      {:ok, terminated} = Accounts.terminate_session(session, "user_logout")

      assert {:error, error} =
               Accounts.update_session(terminated, %{
                 expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
               })

      assert Exception.message(error) =~ "cannot update terminated session"
    end
  end

  describe "session cleanup" do
    setup do
      tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      {:ok, tenant: tenant, user: user}
    end

    test "removes expired sessions", %{tenant: tenant, user: user} do
      # Create expired sessions
      _expired_sessions =
        Enum.map(1..5, fn i ->
          insert(:session,
            user_id: user.id,
            tenant_id: tenant.id,
            expires_at: DateTime.add(DateTime.utc_now(), -(i * 3600), :second)
          )
        end)

      # Create active session
      active =
        insert(:session,
          user_id: user.id,
          tenant_id: tenant.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        )

      assert {:ok, count} = Accounts.cleanup_expired_sessions(tenant_id: tenant.id)
      assert count == 5

      # Verify active session remains
      assert Accounts.get_session!(active.id)
    end

    test "terminates inactive sessions", %{tenant: tenant, user: user} do
      # Create sessions with old activity
      # 2 hours ago
      old_activity = DateTime.add(DateTime.utc_now(), -7200, :second)

      inactive_sessions =
        Enum.map(1..3, fn _ ->
          insert(:session,
            user_id: user.id,
            tenant_id: tenant.id,
            last_activity: old_activity
          )
        end)

      # Terminate sessions inactive for more than 1 hour
      assert {:ok, count} =
               Accounts.terminate_inactive_sessions(
                 tenant_id: tenant.id,
                 inactive_minutes: 60
               )

      assert count == 3

      # Verify sessions are terminated
      for session <- inactive_sessions do
        updated = Accounts.get_session!(session.id)
        assert updated.active == false
        assert updated.terminated_reason == "inactivity"
      end
    end
  end

  describe "concurrent sessions" do
    setup do
      tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      {:ok, tenant: tenant, user: user}
    end

    test "limits concurrent sessions per user", %{user: user} do
      # Create max sessions (assuming limit is 5)
      sessions =
        Enum.map(1..5, fn _ ->
          {:ok, session} =
            Accounts.create_session(%{
              user_id: user.id,
              tenant_id: user.tenant_id
            })

          session
        end)

      # Creating 6th session should terminate oldest
      attrs = %{
        user_id: user.id,
        tenant_id: user.tenant_id
      }

      assert {:ok, _new_session} = Accounts.create_session(attrs)

      # Check oldest session is terminated
      oldest = List.first(sessions)
      terminated = Accounts.get_session!(oldest.id)
      assert terminated.active == false
      assert terminated.terminated_reason == "max_sessions_exceeded"
    end

    test "counts active sessions per user", %{user: user} do
      # Create multiple sessions
      Enum.each(1..3, fn _ ->
        Accounts.create_session(%{
          user_id: user.id,
          tenant_id: user.tenant_id
        })
      end)

      count = Accounts.count_active_sessions(user_id: user.id)
      assert count == 3
    end

    test "terminates all user sessions", %{user: user} do
      # Create multiple sessions
      sessions =
        Enum.map(1..5, fn _ ->
          {:ok, session} =
            Accounts.create_session(%{
              user_id: user.id,
              tenant_id: user.tenant_id
            })

          session
        end)

      assert {:ok, count} =
               Accounts.terminate_all_user_sessions(
                 user_id: user.id,
                 reason: "password_changed"
               )

      assert count == 5

      # Verify all terminated
      for session <- sessions do
        terminated = Accounts.get_session!(session.id)
        assert terminated.active == false
        assert terminated.terminated_reason == "password_changed"
      end
    end
  end

  describe "session analytics" do
    setup do
      tenant = insert(:tenant)
      users = bulk_create_users(tenant, 20)
      sessions = bulk_create_sessions(users, 100)
      {:ok, tenant: tenant, users: users, sessions: sessions}
    end

    test "tracks session duration", %{tenant: tenant} do
      # Create session with known duration
      user = insert(:user, tenant_id: tenant.id)

      session =
        insert(:session,
          user_id: user.id,
          tenant_id: tenant.id,
          created_at: DateTime.add(DateTime.utc_now(), -3600, :second),
          terminated_at: DateTime.utc_now()
        )

      duration = Accounts.calculate_session_duration(session)
      # 1 hour in seconds
      assert duration == 3600
    end

    test "calculates average session duration", %{tenant: tenant} do
      stats = Accounts.session_statistics(tenant_id: tenant.id)

      assert Map.has_key?(stats, :average_duration_seconds)
      assert stats.average_duration_seconds > 0
    end

    test "tracks sessions by device type", %{tenant: tenant} do
      stats = Accounts.session_device_distribution(tenant_id: tenant.id)

      assert Map.has_key?(stats, "desktop")
      assert Map.has_key?(stats, "mobile")
      assert Map.has_key?(stats, "tablet")

      total = Enum.sum(Map.values(stats))
      assert total > 0
    end

    test "identifies concurrent session patterns", %{users: users} do
      user = List.first(users)

      # Create overlapping sessions
      now = DateTime.utc_now()

      _session1 =
        insert(:session,
          user_id: user.id,
          tenant_id: user.tenant_id,
          created_at: DateTime.add(now, -7200, :second),
          terminated_at: DateTime.add(now, -3600, :second)
        )

      _session2 =
        insert(:session,
          user_id: user.id,
          tenant_id: user.tenant_id,
          created_at: DateTime.add(now, -6000, :second),
          terminated_at: DateTime.add(now, -2000, :second)
        )

      concurrent = Accounts.find_concurrent_sessions(user_id: user.id)
      assert length(concurrent) >= 2
    end
  end

  describe "session security" do
    setup do
      tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      {:ok, tenant: tenant, user: user}
    end

    test "detects suspicious login locations", %{user: user} do
      # Create session from usual location
      _usual_session =
        insert(:session,
          user_id: user.id,
          tenant_id: user.tenant_id,
          ip_address: "192.168.1.100",
          location: %{"city" => "New York", "country" => "US"}
        )

      # Create session from unusual location
      suspicious_attrs = %{
        user_id: user.id,
        tenant_id: user.tenant_id,
        # Tor exit node
        ip_address: "185.220.100.100",
        location: %{"city" => "Unknown", "country" => "XX"}
      }

      {:ok, suspicious_session} = Accounts.create_session(suspicious_attrs)

      # Should flag as suspicious
      assert suspicious_session.metadata["risk_score"] > 50
    end

    test "tracks session fingerprint", %{user: user} do
      attrs = %{
        user_id: user.id,
        tenant_id: user.tenant_id,
        user_agent: "Mozilla / 5.0 Test",
        metadata: %{
          "screen_resolution" => "1920x1080",
          "timezone" => "America / New_York",
          "language" => "en - US"
        }
      }

      {:ok, session} = Accounts.create_session(attrs)
      assert session.device_fingerprint != nil
    end

    test "validates session IP consistency", %{user: user} do
      session =
        insert(:session,
          user_id: user.id,
          tenant_id: user.tenant_id,
          ip_address: "192.168.1.100"
        )

      # Validate from same IP - should succeed
      assert {:ok, _} =
               Accounts.validate_session(
                 session.token,
                 ip_address: "192.168.1.100"
               )

      # Validate from different IP - should flag
      assert {:ok, validated} =
               Accounts.validate_session(
                 session.token,
                 ip_address: "10.0.0.1"
               )

      assert validated.metadata["ip_changed"] == true
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
