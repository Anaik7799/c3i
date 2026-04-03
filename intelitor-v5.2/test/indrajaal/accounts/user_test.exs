defmodule Indrajaal.Accounts.UserTest do
  use Indrajaal.DataCase
  import Indrajaal.AccountsComprehensiveFactory
  alias Indrajaal.Accounts
  alias Indrajaal.Accounts.User

  describe "user creation" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "creates user with valid attributes", %{tenant: tenant} do
      attrs = %{
        email: "test@example.com",
        username: "testuser",
        first_name: "Test",
        last_name: "User",
        password: "SecurePass123!",
        tenant_id: tenant.id
      }

      assert {:ok, user} = Accounts.create_user(attrs)
      assert user.email == "test@example.com"
      assert user.username == "testuser"
      assert user.first_name == "Test"
      assert user.last_name == "User"
      assert user.active == true
      assert user.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      assert {:error, error} = Accounts.create_user(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "email: is required"
      assert error_msg =~ "username: is required"
      assert error_msg =~ "password: is required"
    end

    test "validates email format", %{tenant: tenant} do
      invalid_emails = [
        "invalid",
        "invalid@",
        "@invalid.com",
        "invalid@.com",
        "invalid..email@example.com"
      ]

      for email <- invalid_emails do
        attrs = %{
          email: email,
          username: "testuser",
          password: "SecurePass123!",
          tenant_id: tenant.id
        }

        assert {:error, _} = Accounts.create_user(attrs)
      end
    end

    test "validates email uniqueness within tenant", %{tenant: tenant} do
      attrs = %{
        email: "unique@example.com",
        username: "unique1",
        password: "SecurePass123!",
        tenant_id: tenant.id
      }

      assert {:ok, user1} = Accounts.create_user(attrs)

      # Same email, same tenant - should fail
      attrs2 = Map.put(attrs, :username, "unique2")
      assert {:error, error} = Accounts.create_user(attrs2)
      assert Exception.message(error) =~ "email: has already been taken"
    end

    test "allows same email across different tenants" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      attrs = %{
        email: "shared@example.com",
        username: "user1",
        password: "SecurePass123!",
        tenant_id: tenant1.id
      }

      assert {:ok, user1} = Accounts.create_user(attrs)

      # Same email, different tenant - should succeed
      attrs2 = %{attrs | tenant_id: tenant2.id, username: "user2"}
      assert {:ok, user2} = Accounts.create_user(attrs2)
      assert user2.email == "shared@example.com"
      assert user2.tenant_id == tenant2.id
    end

    test "validates username format", %{tenant: tenant} do
      invalid_usernames = [
        # too short
        "a",
        # too short
        "ab",
        # contains space
        "user name",
        # contains special char
        "user@name",
        # starts with number
        "123user",
        # too long
        String.duplicate("a", 51)
      ]

      for username <- invalid_usernames do
        attrs = %{
          email: "test@example.com",
          username: username,
          password: "SecurePass123!",
          tenant_id: tenant.id
        }

        assert {:error, _} = Accounts.create_user(attrs)
      end
    end

    test "validates password complexity", %{tenant: tenant} do
      weak_passwords = [
        # too short
        "short",
        # no uppercase
        "alllowercase",
        # no lowercase
        "ALLUPPERCASE",
        # no numbers
        "NoNumbers!",
        # no special chars
        "NoSpecial123",
        # all spaces
        "        "
      ]

      for password <- weak_passwords do
        attrs = %{
          email: "test@example.com",
          username: "testuser",
          password: password,
          tenant_id: tenant.id
        }

        assert {:error, _} = Accounts.create_user(attrs)
      end
    end

    test "hashes password on creation", %{tenant: tenant} do
      attrs = %{
        email: "test@example.com",
        username: "testuser",
        password: "SecurePass123!",
        tenant_id: tenant.id
      }

      assert {:ok, user} = Accounts.create_user(attrs)
      assert user.password_hash != nil
      assert user.password_hash != "SecurePass123!"
      # bcrypt hash
      assert String.starts_with?(user.password_hash, "$2b$")
    end

    test "creates user with metadata", %{tenant: tenant} do
      metadata = %{
        "source" => "api",
        "ip_address" => "192.168.1.100",
        "department" => "Security"
      }

      attrs = %{
        email: "test@example.com",
        username: "testuser",
        password: "SecurePass123!",
        tenant_id: tenant.id,
        metadata: metadata
      }

      assert {:ok, user} = Accounts.create_user(attrs)
      assert user.metadata["source"] == "api"
      assert user.metadata["department"] == "Security"
    end

    test "creates user with preferences", %{tenant: tenant} do
      preferences = %{
        "theme" => "dark",
        "notifications" => true,
        "language" => "en",
        "timezone" => "America / New_York"
      }

      attrs = %{
        email: "test@example.com",
        username: "testuser",
        password: "SecurePass123!",
        tenant_id: tenant.id,
        preferences: preferences
      }

      assert {:ok, user} = Accounts.create_user(attrs)
      assert user.preferences["theme"] == "dark"
      assert user.preferences["notifications"] == true
    end

    test "creates service account user", %{tenant: tenant} do
      attrs = %{
        email: "service@system.local",
        username: "service_account",
        password: "SecurePass123!",
        tenant_id: tenant.id,
        is_service_account: true,
        password_expires_at: nil
      }

      assert {:ok, user} = Accounts.create_user(attrs)
      assert user.is_service_account == true
      assert user.password_expires_at == nil
    end
  end

  describe "user updates" do
    setup do
      tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      {:ok, tenant: tenant, user: user}
    end

    test "updates user profile fields", %{user: user} do
      attrs = %{
        first_name: "Updated",
        last_name: "Name",
        phone: "+1 - 555 - 1234"
      }

      assert {:ok, updated} = Accounts.update_user(user, attrs)
      assert updated.first_name == "Updated"
      assert updated.last_name == "Name"
      assert updated.phone == "+1 - 555 - 1234"
    end

    test "updates email with validation", %{user: user} do
      attrs = %{email: "newemail@example.com"}

      assert {:ok, updated} = Accounts.update_user(user, attrs)
      assert updated.email == "newemail@example.com"
      # Should reset confirmation
      assert updated.confirmed_at == nil
    end

    test "prevents email update to existing email",
         %{tenant: tenant, user: user} do
      other_user = insert(:user, tenant_id: tenant.id, email: "taken@example.com")

      attrs = %{email: other_user.email}
      assert {:error, error} = Accounts.update_user(user, attrs)
      assert Exception.message(error) =~ "email: has already been taken"
    end

    test "updates password with hash", %{user: user} do
      old_hash = user.password_hash
      attrs = %{password: "NewSecurePass123!"}

      assert {:ok, updated} = Accounts.update_user(user, attrs)
      assert updated.password_hash != old_hash
      assert updated.password_changed_at != nil
    end

    test "updates user preferences", %{user: user} do
      attrs = %{
        preferences: %{
          "theme" => "dark",
          "notifications" => false
        }
      }

      assert {:ok, updated} = Accounts.update_user(user, attrs)
      assert updated.preferences["theme"] == "dark"
      assert updated.preferences["notifications"] == false
    end

    test "deactivates user", %{user: user} do
      attrs = %{active: false, deactivated_at: DateTime.utc_now()}

      assert {:ok, updated} = Accounts.update_user(user, attrs)
      assert updated.active == false
      assert updated.deactivated_at != nil
    end

    test "locks user account", %{user: user} do
      attrs = %{
        locked_at: DateTime.utc_now(),
        failed_login_attempts: 5
      }

      assert {:ok, updated} = Accounts.update_user(user, attrs)
      assert updated.locked_at != nil
      assert updated.failed_login_attempts == 5
    end

    test "enables MFA", %{user: user} do
      attrs = %{
        mfa_enabled: true,
        mfa_secret: Base.encode32(:crypto.strong_rand_bytes(20))
      }

      assert {:ok, updated} = Accounts.update_user(user, attrs)
      assert updated.mfa_enabled == true
      assert updated.mfa_secret != nil
    end
  end

  describe "user queries" do
    setup do
      tenant = insert(:tenant)
      users = bulk_create_users(tenant, 50)
      {:ok, tenant: tenant, users: users}
    end

    test "lists all users for tenant", %{tenant: tenant, users: users} do
      result = Accounts.list_users!(tenant_id: tenant.id)
      assert length(result) >= length(users)
      assert Enum.all?(result, &(&1.tenant_id == tenant.id))
    end

    test "filters active users", %{tenant: tenant} do
      # Create inactive user
      insert(:user, tenant_id: tenant.id, active: false)

      active_users =
        Accounts.list_users!(
          tenant_id: tenant.id,
          filter: [active: true]
        )

      assert Enum.all?(active_users, &(&1.active == true))
    end

    test "filters by role", %{tenant: tenant} do
      # Create users with specific roles
      admin = insert(:user, tenant_id: tenant.id, role: "admin")
      operator = insert(:user, tenant_id: tenant.id, role: "operator")

      admin_users =
        Accounts.list_users!(
          tenant_id: tenant.id,
          filter: [role: "admin"]
        )

      assert Enum.any?(admin_users, &(&1.id == admin.id))
      refute Enum.any?(admin_users, &(&1.id == operator.id))
    end

    test "searches by email", %{tenant: tenant} do
      user = insert(:user, tenant_id: tenant.id, email: "searchme@example.com")

      results =
        Accounts.list_users!(
          tenant_id: tenant.id,
          filter: [email: {:ilike, "%searchme%"}]
        )

      assert Enum.any?(results, &(&1.id == user.id))
    end

    test "searches by name", %{tenant: tenant} do
      user =
        insert(:user,
          tenant_id: tenant.id,
          first_name: "Unique",
          last_name: "Person"
        )

      # Search by first name
      results =
        Accounts.list_users!(
          tenant_id: tenant.id,
          filter: [first_name: {:ilike, "%Unique%"}]
        )

      assert Enum.any?(results, &(&1.id == user.id))
    end

    test "filters by confirmation status", %{tenant: tenant} do
      # Create unconfirmed user
      unconfirmed =
        insert(:user,
          tenant_id: tenant.id,
          confirmed_at: nil
        )

      # Get confirmed users
      confirmed_users =
        Accounts.list_users!(
          tenant_id: tenant.id,
          filter: [confirmed_at: {:not_eq, nil}]
        )

      refute Enum.any?(confirmed_users, &(&1.id == unconfirmed.id))
    end

    test "filters by locked status", %{tenant: tenant} do
      # Create locked user
      locked =
        insert(:user,
          tenant_id: tenant.id,
          locked_at: DateTime.utc_now()
        )

      # Get unlocked users
      unlocked_users =
        Accounts.list_users!(
          tenant_id: tenant.id,
          filter: [locked_at: nil]
        )

      refute Enum.any?(unlocked_users, &(&1.id == locked.id))
    end

    test "filters by MFA status", %{tenant: tenant} do
      # Create MFA user
      mfa_user =
        insert(:user,
          tenant_id: tenant.id,
          mfa_enabled: true
        )

      mfa_users =
        Accounts.list_users!(
          tenant_id: tenant.id,
          filter: [mfa_enabled: true]
        )

      assert Enum.any?(mfa_users, &(&1.id == mfa_user.id))
    end

    test "filters by service account", %{tenant: tenant} do
      # Create service account
      service =
        insert(:user,
          tenant_id: tenant.id,
          is_service_account: true
        )

      service_accounts =
        Accounts.list_users!(
          tenant_id: tenant.id,
          filter: [is_service_account: true]
        )

      assert Enum.any?(service_accounts, &(&1.id == service.id))
    end

    test "sorts by created date", %{tenant: tenant} do
      users =
        Accounts.list_users!(
          tenant_id: tenant.id,
          sort: [inserted_at: :desc]
        )

      dates = Enum.map(users, & &1.inserted_at)
      assert dates == Enum.sort(dates, {:desc, DateTime})
    end

    test "sorts by name", %{tenant: tenant} do
      users =
        Accounts.list_users!(
          tenant_id: tenant.id,
          sort: [last_name: :asc, first_name: :asc]
        )

      names = Enum.map(users, &{&1.last_name, &1.first_name})
      assert names == Enum.sort(names)
    end

    test "paginates results", %{tenant: tenant} do
      page1 =
        Accounts.list_users!(
          tenant_id: tenant.id,
          page: [limit: 10, offset: 0]
        )

      page2 =
        Accounts.list_users!(
          tenant_id: tenant.id,
          page: [limit: 10, offset: 10]
        )

      assert length(page1) == 10
      assert length(page2) == 10

      # No overlap
      page1_ids = MapSet.new(page1, & &1.id)
      page2_ids = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(page1_ids, page2_ids)
    end
  end

  describe "user authentication" do
    setup do
      tenant = insert(:tenant)

      user =
        insert(:user,
          tenant_id: tenant.id,
          password: "TestPass123!"
        )

      {:ok, tenant: tenant, user: user}
    end

    test "authenticates with valid credentials",
         %{tenant: tenant, user: user} do
      assert {:ok, authenticated} =
               Accounts.authenticate_user(
                 tenant_id: tenant.id,
                 username: user.username,
                 password: "TestPass123!"
               )

      assert authenticated.id == user.id
      assert authenticated.last_login_at != nil
    end

    test "fails with invalid password", %{tenant: tenant, user: user} do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user(
                 tenant_id: tenant.id,
                 username: user.username,
                 password: "WrongPassword"
               )
    end

    test "fails with non - existent user", %{tenant: tenant} do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user(
                 tenant_id: tenant.id,
                 username: "nonexistent",
                 password: "TestPass123!"
               )
    end

    test "fails with inactive user", %{tenant: tenant} do
      inactive =
        insert(:user,
          tenant_id: tenant.id,
          active: false,
          password: "TestPass123!"
        )

      assert {:error, :account_inactive} =
               Accounts.authenticate_user(
                 tenant_id: tenant.id,
                 username: inactive.username,
                 password: "TestPass123!"
               )
    end

    test "fails with locked user", %{tenant: tenant} do
      locked =
        insert(:user,
          tenant_id: tenant.id,
          locked_at: DateTime.utc_now(),
          password: "TestPass123!"
        )

      assert {:error, :account_locked} =
               Accounts.authenticate_user(
                 tenant_id: tenant.id,
                 username: locked.username,
                 password: "TestPass123!"
               )
    end

    test "increments failed login attempts", %{tenant: tenant, user: user} do
      # First failed attempt
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user(
                 tenant_id: tenant.id,
                 username: user.username,
                 password: "WrongPassword"
               )

      updated = Accounts.get_user!(user.id)
      assert updated.failed_login_attempts == 1
    end

    test "locks account after max failed attempts", %{tenant: tenant} do
      user =
        insert(:user,
          tenant_id: tenant.id,
          failed_login_attempts: 4,
          password: "TestPass123!"
        )

      # 5th failed attempt should lock
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user(
                 tenant_id: tenant.id,
                 username: user.username,
                 password: "WrongPassword"
               )

      updated = Accounts.get_user!(user.id)
      assert updated.locked_at != nil
      assert updated.failed_login_attempts == 5
    end

    test "resets failed attempts on success", %{tenant: tenant} do
      user =
        insert(:user,
          tenant_id: tenant.id,
          failed_login_attempts: 3,
          password: "TestPass123!"
        )

      assert {:ok, authenticated} =
               Accounts.authenticate_user(
                 tenant_id: tenant.id,
                 username: user.username,
                 password: "TestPass123!"
               )

      assert authenticated.failed_login_attempts == 0
    end
  end

  describe "user deletion" do
    setup do
      tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      {:ok, tenant: tenant, user: user}
    end

    test "soft deletes user", %{user: user} do
      assert {:ok, deleted} = Accounts.delete_user(user)
      assert deleted.deleted_at != nil
      assert deleted.active == false
    end

    test "maintains user for audit trail", %{user: user} do
      assert {:ok, _deleted} = Accounts.delete_user(user)

      # User still exists in database
      assert Accounts.get_user!(user.id, include_deleted: true)
    end
  end

  describe "password management" do
    setup do
      tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      {:ok, tenant: tenant, user: user}
    end

    test "generates password reset token", %{user: user} do
      assert {:ok, token} = Accounts.generate_password_reset_token(user)
      assert token.user_id == user.id
      assert token.type == "reset_password"
      assert token.expires_at != nil
    end

    test "resets password with valid token", %{user: user} do
      {:ok, token} = Accounts.generate_password_reset_token(user)

      assert {:ok, updated} =
               Accounts.reset_password(
                 token: token.token,
                 password: "NewSecurePass123!"
               )

      assert updated.id == user.id
      assert updated.password_changed_at != nil

      # Token should be used
      used_token = Accounts.get_token!(token.id)
      assert used_token.used_at != nil
    end

    test "fails reset with invalid token" do
      assert {:error, :invalid_token} =
               Accounts.reset_password(
                 token: "invalid-token",
                 password: "NewSecurePass123!"
               )
    end

    test "fails reset with expired token", %{user: user} do
      {:ok, token} = Accounts.generate_password_reset_token(user)

      # Manually expire the token
      expired_token = %{token | expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)}

      assert {:error, :token_expired} =
               Accounts.reset_password(
                 token: expired_token.token,
                 password: "NewSecurePass123!"
               )
    end

    test "enforces password history", %{user: user} do
      # Set password history
      old_passwords = ["OldPass1!", "OldPass2!", "OldPass3!"]

      for password <- old_passwords do
        {:ok, _} = Accounts.update_user(user, %{password: password})
      end

      # Try to reuse old password
      assert {:error, error} = Accounts.update_user(user, %{password: "OldPass1!"})
      assert Exception.message(error) =~ "password was recently used"
    end
  end

  describe "bulk operations" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "bulk creates users", %{tenant: tenant} do
      users = bulk_create_users(tenant, 100)
      assert length(users) == 100

      # Verify diversity
      roles = users |> Enum.map(& &1.role) |> Enum.uniq()
      assert length(roles) >= 4

      # Verify all belong to tenant
      assert Enum.all?(users, &(&1.tenant_id == tenant.id))
    end

    test "bulk deactivates users", %{tenant: tenant} do
      users = bulk_create_users(tenant, 20)
      user_ids = Enum.map(users, & &1.id)

      assert {:ok, count} =
               Accounts.bulk_update_users(
                 filter: [id: {:in, user_ids}],
                 attributes: %{active: false, deactivated_at: DateTime.utc_now()}
               )

      assert count == 20

      # Verify all deactivated
      updated = Accounts.list_users!(filter: [id: {:in, user_ids}])
      assert Enum.all?(updated, &(&1.active == false))
    end

    test "bulk unlocks users", %{tenant: tenant} do
      # Create locked users
      locked_users =
        Enum.map(1..10, fn _i ->
          insert(:user,
            tenant_id: tenant.id,
            locked_at: DateTime.utc_now(),
            failed_login_attempts: 5
          )
        end)

      user_ids = Enum.map(locked_users, & &1.id)

      assert {:ok, count} =
               Accounts.bulk_update_users(
                 filter: [id: {:in, user_ids}],
                 attributes: %{locked_at: nil, failed_login_attempts: 0}
               )

      assert count == 10
    end
  end

  describe "user statistics" do
    setup do
      tenant = insert(:tenant)
      users = bulk_create_users(tenant, 50)
      {:ok, tenant: tenant, users: users}
    end

    test "counts users by status", %{tenant: tenant} do
      # Create users with different statuses
      insert(:user, tenant_id: tenant.id, active: false)
      insert(:user, tenant_id: tenant.id, locked_at: DateTime.utc_now())
      insert(:user, tenant_id: tenant.id, confirmed_at: nil)

      stats = Accounts.user_statistics(tenant_id: tenant.id)

      assert stats.total > 50
      assert stats.active > 0
      assert stats.inactive > 0
      assert stats.locked > 0
      assert stats.unconfirmed > 0
    end

    test "counts users by role", %{tenant: tenant} do
      stats = Accounts.user_role_distribution(tenant_id: tenant.id)

      assert Map.has_key?(stats, "admin")
      assert Map.has_key?(stats, "operator")
      assert Map.has_key?(stats, "viewer")
      assert stats["admin"] + stats["operator"] + stats["viewer"] > 0
    end

    test "tracks login activity", %{tenant: tenant, users: users} do
      # Simulate logins
      users
      |> Enum.take(10)
      |> Enum.each(fn user ->
        Accounts.update_user(user, %{last_login_at: DateTime.utc_now()})
      end)

      stats =
        Accounts.login_activity_stats(
          tenant_id: tenant.id,
          period: :day
        )

      assert stats.active_today >= 10
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
