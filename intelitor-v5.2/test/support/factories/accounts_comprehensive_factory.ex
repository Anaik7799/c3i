defmodule Indrajaal.AccountsComprehensiveFactory do
  @moduledoc """
  Comprehensive factory definitions for Accounts domain with bulk data generation.
  Implements realistic user, session, and team patterns for enterprise testing.

  Provides factory functions for:
  - Users with various roles and states
  - Sessions with different device types and locations
  - Teams with members and hierarchies
  - Bulk creation utilities for load testing
  """

  import Indrajaal.Factory

  @doc """
  Bulk creates users for a given tenant.

  ## Examples

      users = bulk_create_users(tenant, 10)
      users = bulk_create_users(tenant, 50, role: :admin)
  """
  @spec bulk_create_users(map(), integer(), keyword()) :: [map()]
  def bulk_create_users(tenant, count, opts \\ []) do
    Enum.map(1..count, fn i ->
      attrs = %{
        tenant_id: tenant.id,
        email: "user#{i}_#{System.unique_integer([:positive])}@example.com",
        username: "user#{i}_#{System.unique_integer([:positive])}",
        full_name: "Test User #{i}",
        status: Keyword.get(opts, :status, :active)
      }

      attrs =
        if Keyword.has_key?(opts, :role) do
          Map.put(attrs, :role, opts[:role])
        else
          attrs
        end

      insert(:user, attrs)
    end)
  end

  @doc """
  Bulk creates sessions for a list of users.

  ## Examples

      sessions = bulk_create_sessions(users, 50)
      sessions = bulk_create_sessions(users, 100, device_type: "mobile")
  """
  @spec bulk_create_sessions([map()], integer(), keyword()) :: [map()]
  def bulk_create_sessions(users, count, opts \\ []) do
    device_types = ["desktop", "mobile", "tablet", "api"]

    Enum.map(1..count, fn i ->
      user = Enum.random(users)

      attrs = %{
        user_id: user.id,
        tenant_id: user.tenant_id,
        device_type: Keyword.get(opts, :device_type, Enum.random(device_types)),
        ip_address: "192.168.#{rem(i, 256)}.#{rem(i * 7, 256)}",
        user_agent: "Mozilla/5.0 Test Browser #{i}",
        active: Keyword.get(opts, :active, true)
      }

      insert(:session, attrs)
    end)
  end

  @doc """
  Bulk creates teams for a given tenant.

  ## Examples

      teams = bulk_create_teams(tenant, 5)
  """
  @spec bulk_create_teams(map(), integer(), keyword()) :: [map()]
  def bulk_create_teams(tenant, count, opts \\ []) do
    Enum.map(1..count, fn i ->
      attrs = %{
        tenant_id: tenant.id,
        name: "Team #{i}",
        description: "Test team #{i}",
        active: Keyword.get(opts, :active, true)
      }

      insert(:team, attrs)
    end)
  end

  @doc """
  Bulk creates team memberships.

  ## Examples

      memberships = bulk_create_team_memberships(users, teams)
  """
  @spec bulk_create_team_memberships([map()], [map()], keyword()) :: [map()]
  def bulk_create_team_memberships(users, teams, opts \\ []) do
    roles = [:member, :lead, :admin]

    Enum.flat_map(users, fn user ->
      # Each user belongs to 1-3 teams
      team_count = :rand.uniform(min(3, length(teams)))
      selected_teams = Enum.take_random(teams, team_count)

      Enum.map(selected_teams, fn team ->
        attrs = %{
          user: user,
          team: team,
          role: Keyword.get(opts, :role, Enum.random(roles))
        }

        insert(:team_membership, attrs)
      end)
    end)
  end

  @doc """
  Creates a user with specific attributes for testing edge cases.
  """
  @spec create_user_with_state(map(), atom(), keyword()) :: map()
  def create_user_with_state(tenant, state, opts \\ []) do
    base_attrs = %{
      tenant_id: tenant.id,
      email: "#{state}_user_#{System.unique_integer([:positive])}@example.com",
      username: "#{state}_user_#{System.unique_integer([:positive])}"
    }

    state_attrs =
      case state do
        :active -> %{status: :active, active: true}
        :inactive -> %{status: :inactive, active: false}
        :suspended -> %{status: :suspended, active: false}
        :pending -> %{status: :pending, active: false}
        :locked -> %{status: :locked, active: false, locked_at: DateTime.utc_now()}
        _ -> %{status: :active, active: true}
      end

    attrs = Map.merge(base_attrs, state_attrs)
    attrs = Map.merge(attrs, Map.new(opts))

    insert(:user, attrs)
  end

  @doc """
  Creates a session with specific characteristics for testing.
  """
  @spec create_session_with_characteristics(map(), keyword()) :: map()
  def create_session_with_characteristics(user, characteristics) do
    base_attrs = %{
      user_id: user.id,
      tenant_id: user.tenant_id
    }

    attrs =
      Enum.reduce(characteristics, base_attrs, fn
        {:expired, true}, acc ->
          Map.put(acc, :expires_at, DateTime.add(DateTime.utc_now(), -3600, :second))

        {:device_type, type}, acc ->
          Map.put(acc, :device_type, type)

        {:ip_address, ip}, acc ->
          Map.put(acc, :ip_address, ip)

        {:active, active}, acc ->
          Map.put(acc, :active, active)

        {:location, location}, acc ->
          Map.put(acc, :location, location)

        {key, value}, acc ->
          Map.put(acc, key, value)
      end)

    insert(:session, attrs)
  end
end
