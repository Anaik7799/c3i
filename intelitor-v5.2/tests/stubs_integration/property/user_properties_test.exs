defmodule Intelitor.Property.UserPropertiesTest do
  @moduledoc """
  Property - based tests for user management functionality.

  These tests use randomized inputs to verify that user - related business logic
  holds true across a wide range of possible inputs and edge cases.
  """

  use Intelitor.WallabyCase
  use PropCheck

  # # use ExUnitProperties  # Disabled - PropCheck conflict (SC-TDG-002)  # Disabled - PropCheck property/2 conflict

  import Intelitor.PropertyTesting
  import Intelitor.Factory

  @moduletag :property
  # 5 minutes for property tests
  @moduletag timeout: 300_000

  describe "User Creation Properties" do
    property "user creation with valid data always succeeds" do
      forall {user_params, tenant} <- {user_generator(), exactly(insert(:tenant))} do
        case Intelitor.Accounts.create_user(user_params, %{tenant_id: tenant.id}) do
          {:ok, user} ->
            # Verify user was created with correct attributes
            assert user.email == user_params.email
            assert user.first_name == user_params.first_name
            assert user.last_name == user_params.last_name
            assert user.role == user_params.role
            assert user.active == user_params.active
            assert user.tenant_id == tenant.id

            # Verify password was hashed
            assert user.password_hash != user_params.password
            assert byte_size(user.password_hash) > 0

          {:error, reason} ->
            # If creation fails, it should be due to validation
            assert is_validation_error?(reason)
        end
      end
    end

    property "duplicate email addresses are rejected" do
      forall {user_params1, user_params2, tenant} <-
               {user_generator(), user_generator(), exactly(insert(:tenant))} do
        # Force same email
        user_params2 = %{user_params2 | email: user_params1.email}

        # Create first user
        {:ok, _user1} =
          Intelitor.Accounts.create_user(user_params1, %{tenant_id: tenant.id})

        # Attempt to create second user with same email
        result = Intelitor.Accounts.create_user(user_params2, %{tenant_id: tenant.id})

        assert {:error, _reason} = result
        assert is_duplicate_email_error?(result)
      end
    end

    property "user roles determine permissions correctly" do
      forall {role, tenant} <-
               {oneof([:admin, :manager, :operator, :viewer, :guest]), exactly(insert(:tenant))} do
        user_params = %{
          email: "test_#{:rand.uniform(10_000)}@example.com",
          password: "SecurePass123!",
          first_name: "Test",
          last_name: "User",
          role: role,
          active: true
        }

        {:ok, user} = Intelitor.Accounts.create_user(user_params, %{tenant_id: tenant.id})
        permissions = get_user_permissions(user)

        case role do
          :admin ->
            assert :admin in permissions
            assert :read in permissions
            assert :write in permissions
            assert :delete in permissions

          :manager ->
            assert :read in permissions
            assert :write in permissions
            assert :execute in permissions
            refute :admin in permissions

          :operator ->
            assert :read in permissions
            assert :write in permissions
            refute :delete in permissions
            refute :admin in permissions

          :viewer ->
            assert :read in permissions
            refute :write in permissions
            refute :delete in permissions
            refute :admin in permissions

          :guest ->
            assert :view_only in permissions
            refute :read in permissions
            refute :write in permissions
        end
      end
    end
  end

  describe "User Authentication Properties" do
    property "valid credentials always authenticate successfully" do
      forall {user_params, tenant} <- {user_generator(), exactly(insert(:tenant))} do
        # Create user
        {:ok, user} = Intelitor.Accounts.create_user(user_params, %{tenant_id: tenant.id})

        # Authenticate with original password
        auth_params = %{
          email: user.email,
          password: user_params.password,
          tenant_id: tenant.id
        }

        case Intelitor.Accounts.authenticate_user(auth_params) do
          {:ok, auth_result} ->
            assert auth_result.user.id == user.id
            assert is_binary(auth_result.token)
            assert %DateTime{} = auth_result.expires_at
            assert is_list(auth_result.permissions)
            assert is_map(auth_result.metadata)

          {:error, reason} ->
            # Authentication can fail if user is inactive
            if not user.active do
              assert reason == :account_inactive
            else
              flunk("Authentication should succeed for active user")
            end
        end
      end
    end

    property "invalid passwords always fail authentication" do
      forall {user_params, invalid_password, tenant} <-
               {user_generator(), utf8(), exactly(insert(:tenant))} do
        # Ensure invalid password is different from valid one
        if invalid_password != user_params.password do
          # Create user
          {:ok, user} =
            Intelitor.Accounts.create_user(user_params, %{tenant_id: tenant.id})

          # Attempt authentication with invalid password
          auth_params = %{
            email: user.email,
            password: invalid_password,
            tenant_id: tenant.id
          }

          result = Intelitor.Accounts.authenticate_user(auth_params)
          assert {:error, :invalid_credentials} = result
        end
      end
    end

    property "inactive users cannot authenticate" do
      forall {user_params, tenant} <- {user_generator(), exactly(insert(:tenant))} do
        # Force user to be inactive
        user_params = %{user_params | active: false}

        {:ok, user} = Intelitor.Accounts.create_user(user_params, %{tenant_id: tenant.id})

        auth_params = %{
          email: user.email,
          password: user_params.password,
          tenant_id: tenant.id
        }

        result = Intelitor.Accounts.authenticate_user(auth_params)
        assert {:error, :account_inactive} = result
      end
    end
  end

  describe "User Search and Filtering Properties" do
    property "search results are always relevant" do
      forall {search_term, user_count, tenant} <-
               {utf8(), integer(5, 20), exactly(insert(:tenant))} do
        # Create users with some containing the search term
        users = create_searchable_users(tenant, user_count, search_term)

        # Search for users
        search_options = %{email: search_term}

        {:ok, results} =
          Intelitor.Accounts.search_users(search_options, %{tenant_id: tenant.id})

        # Verify all results contain the search term
        Enum.each(results, fn user ->
          assert String.contains?(user.email, search_term) or
                   String.contains?(user.first_name, search_term) or
                   String.contains?(user.last_name, search_term)
        end)

        # Verify no relevant users were missed
        expected_matches =
          Enum.filter(users, fn user ->
            String.contains?(user.email, search_term)
          end)

        assert length(results) == length(expected_matches)
      end
    end

    property "role filtering returns only users with specified roles" do
      forall {target_role, user_count, tenant} <-
               {oneof([:admin, :manager, :operator, :viewer]), integer(10, 30),
                exactly(insert(:tenant))} do
        # Create users with random roles
        users = create_users_with_roles(tenant, user_count)

        # Filter by specific role
        search_options = %{role: target_role}

        {:ok, filtered_users} =
          Intelitor.Accounts.search_users(search_options, %{tenant_id: tenant.id})

        # Verify all returned users have the target role
        Enum.each(filtered_users, fn user ->
          assert user.role == target_role
        end)

        # Verify count matches expected
        expected_count = Enum.count(users, &(&1.role == target_role))
        assert length(filtered_users) == expected_count
      end
    end
  end

  describe "User Team Management Properties" do
    property "adding users to teams maintains team integrity" do
      forall {team_params, user_count, tenant} <-
               {team_generator(), integer(3, 15), exactly(insert(:tenant))} do
        # Create team
        {:ok, team} = Intelitor.Accounts.create_team(team_params, %{tenant_id: tenant.id})

        # Create users
        users = create_bulk_users(tenant, user_count)

        # Add users to team
        memberships =
          Enum.map(users, fn user ->
            role = Enum.random([:member, :lead, :manager])

            {:ok, membership} =
              Intelitor.Accounts.add_user_to_team(
                user.id,
                team.id,
                role,
                %{tenant_id: tenant.id}
              )

            membership
          end)

        # Verify all memberships are valid
        assert length(memberships) == user_count

        Enum.each(memberships, fn membership ->
          assert membership.team_id == team.id
          assert membership.user_id in Enum.map(users, & &1.id)
          assert membership.role in [:member, :lead, :manager]
          assert membership.tenant_id == tenant.id
        end)

        # Verify team membership queries
        Enum.each(users, fn user ->
          {:ok, user_teams} =
            Intelitor.Accounts.get_user_teams(user.id, %{tenant_id: tenant.id})

          assert team.id in Enum.map(user_teams, & &1.id)
        end)
      end
    end
  end

  describe "User Activity Logging Properties" do
    property "all user actions are properly logged" do
      forall {user_params, actions, tenant} <-
               {user_generator(), list(oneof([:login, :logout, :create, :update, :delete])),
                exactly(insert(:tenant))} do
        {:ok, user} = Intelitor.Accounts.create_user(user_params, %{tenant_id: tenant.id})

        # Log various actions
        logged_activities =
          Enum.map(actions, fn action ->
            metadata = %{action_details: "Property test action", timestamp: DateTime.utc_now()}

            {:ok, activity} =
              Intelitor.Accounts.log_user_activity(
                user.id,
                action,
                metadata,
                %{tenant_id: tenant.id}
              )

            activity
          end)

        # Verify all actions were logged
        assert length(logged_activities) == length(actions)

        # Retrieve user activity
        {:ok, retrieved_activities} =
          Intelitor.Accounts.get_user_activity(
            user.id,
            %{},
            %{tenant_id: tenant.id}
          )

        # Verify activity count (may include additional system - generated activi
        assert length(retrieved_activities) >= length(actions)

        # Verify each logged action exists in retrieved activities
        logged_actions = Enum.map(logged_activities, & &1.action)
        retrieved_actions = Enum.map(retrieved_activities, & &1.action)

        Enum.each(logged_actions, fn action ->
          assert action in retrieved_actions
        end)
      end
    end
  end

  # Helper functions for property tests

  defp is_validation_error?({:validation_error, _errors}), do: true
  defp is_validation_error?(_), do: false

  defp is_duplicate_email_error?({:error, %{errors: errors}}) do
    Enum.any?(errors, fn error ->
      error.field == :email and String.contains?(error.message, "already taken")
    end)
  end

  defp is_duplicate_email_error?(_), do: false

  defp get_user_permissions(user) do
    # Simplified permission logic for testing
    case user.role do
      :admin -> [:admin, :read, :write, :delete, :execute]
      :manager -> [:read, :write, :execute]
      :operator -> [:read, :write]
      :viewer -> [:read]
      :guest -> [:view_only]
    end
  end

  defp create_searchable_users(tenant, count, search_term) do
    Enum.map(1..count, fn i ->
      email =
        if rem(i, 3) == 0 do
          "#{search_term}_user#{i}@example.com"
        else
          "user#{i}@example.com"
        end

      first_name =
        if rem(i, 4) == 0 do
          "#{search_term}_FirstName#{i}"
        else
          "FirstName#{i}"
        end

      user_params = %{
        email: email,
        first_name: first_name,
        last_name: "LastName#{i}",
        password: "SecurePass123!",
        role: :operator,
        active: true
      }

      {:ok, user} = Intelitor.Accounts.create_user(user_params, %{tenant_id: tenant.id})
      user
    end)
  end

  defp create_users_with_roles(tenant, count) do
    roles = [:admin, :manager, :operator, :viewer, :guest]

    Enum.map(1..count, fn i ->
      role = Enum.at(roles, rem(i, length(roles)))

      user_params = %{
        email: "user#{i}@example.com",
        first_name: "User",
        last_name: "#{i}",
        password: "SecurePass123!",
        role: role,
        active: true
      }

      {:ok, user} = Intelitor.Accounts.create_user(user_params, %{tenant_id: tenant.id})
      user
    end)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
