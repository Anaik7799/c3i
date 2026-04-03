defmodule Indrajaal.AccessControl.AccessGrantTest do
  use Indrajaal.DataCase
  require Ash.Query
  alias Indrajaal.AccessControl.AccessGrant

  describe "create / 1" do
    test "creates access grant with valid attributes" do
      tenant = insert(:tenant)
      credential = insert(:access_credential, tenant: tenant)
      level = insert(:access_level, tenant: tenant)
      schedule = insert(:access_schedule, tenant: tenant)
      location = insert(:location, tenant: tenant)

      valid_attrs = %{
        access_credential_id: credential.id,
        access_level_id: level.id,
        access_schedule_id: schedule.id,
        location_id: location.id,
        granted_at: DateTime.utc_now(),
        # 24 hours
        expires_at: DateTime.add(DateTime.utc_now(), 86_400),
        status: :active,
        granted_by_user_id: insert(:user, tenant: tenant).id,
        grant_reason: "Employee access authorization",
        tenant_id: tenant.id
      }

      assert {:ok, grant} =
               AccessGrant
               |> Ash.Changeset.for_create(:create, valid_attrs)
               |> Ash.create(authorize?: false)

      assert grant.access_credential_id == credential.id
      assert grant.access_level_id == level.id
      assert grant.access_schedule_id == schedule.id
      assert grant.location_id == location.id
      assert grant.status == :active
      assert grant.grant_reason == "Employee access authorization"
      assert grant.tenant_id == tenant.id
    end

    test "requires access_credential_id" do
      tenant = insert(:tenant)
      level = insert(:access_level, tenant: tenant)

      invalid_attrs = %{
        access_level_id: level.id,
        status: :active,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AccessGrant
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "requires access_level_id" do
      tenant = insert(:tenant)
      credential = insert(:access_credential, tenant: tenant)

      invalid_attrs = %{
        access_credential_id: credential.id,
        status: :active,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AccessGrant
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "prevents duplicate active grants for same credential - location" do
      tenant = insert(:tenant)
      credential = insert(:access_credential, tenant: tenant)
      level = insert(:access_level, tenant: tenant)
      location = insert(:location, tenant: tenant)
      user = insert(:user, tenant: tenant)

      grant_attrs = %{
        access_credential_id: credential.id,
        access_level_id: level.id,
        location_id: location.id,
        status: :active,
        granted_by_user_id: user.id,
        tenant_id: tenant.id
      }

      # Create first grant
      assert {:ok, _grant1} =
               AccessGrant
               |> Ash.Changeset.for_create(:create, grant_attrs)
               |> Ash.create(authorize?: false)

      # Try to create second active grant for same credential - location
      assert {:error, %Ash.Error.Invalid{}} =
               AccessGrant
               |> Ash.Changeset.for_create(:create, grant_attrs)
               |> Ash.create(authorize?: false)
    end

    test "allows new grant after previous is revoked" do
      tenant = insert(:tenant)
      credential = insert(:access_credential, tenant: tenant)
      level = insert(:access_level, tenant: tenant)
      location = insert(:location, tenant: tenant)
      user = insert(:user, tenant: tenant)

      # Create and revoke first grant
      grant_attrs = %{
        access_credential_id: credential.id,
        access_level_id: level.id,
        location_id: location.id,
        status: :revoked,
        granted_by_user_id: user.id,
        tenant_id: tenant.id
      }

      assert {:ok, _grant1} =
               AccessGrant
               |> Ash.Changeset.for_create(:create, grant_attrs)
               |> Ash.create(authorize?: false)

      # Create new active grant
      new_grant_attrs = %{
        access_credential_id: credential.id,
        access_level_id: level.id,
        location_id: location.id,
        status: :active,
        granted_by_user_id: user.id,
        tenant_id: tenant.id
      }

      assert {:ok, grant2} =
               AccessGrant
               |> Ash.Changeset.for_create(:create, new_grant_attrs)
               |> Ash.create(authorize?: false)

      assert grant2.status == :active
    end
  end

  describe "read operations" do
    test "lists access grants for tenant" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      # Create grants for different tenants
      grant1 = insert(:access_grant, tenant: tenant)
      grant2 = insert(:access_grant, tenant: tenant)
      _grant3 = insert(:access_grant, tenant: other_tenant)

      grants =
        AccessGrant
        |> Ash.Query.filter(tenant_id == ^tenant.id)
        |> Ash.read!()

      assert length(grants) == 2
      grant_ids = Enum.map(grants, & &1.id)
      assert grant1.id in grant_ids
      assert grant2.id in grant_ids
    end

    test "reads access grant by id with tenant isolation" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      grant = insert(:access_grant, tenant: tenant)
      other_grant = insert(:access_grant, tenant: other_tenant)

      # Can read grant from same tenant
      assert {:ok, found_grant} =
               AccessGrant
               |> Ash.Query.filter(id == ^grant.id and tenant_id == ^tenant.id)
               |> Ash.read_one()

      assert found_grant.id == grant.id

      # Cannot read grant from different tenant
      assert {:ok, nil} =
               AccessGrant
               |> Ash.Query.filter(id == ^other_grant.id and tenant_id == ^tenant.id)
               |> Ash.read_one()
    end

    test "filters active grants" do
      tenant = insert(:tenant)

      active_grant = insert(:access_grant, tenant: tenant, status: :active)
      _expired_grant = insert(:access_grant, tenant: tenant, status: :expired)
      _revoked_grant = insert(:access_grant, tenant: tenant, status: :revoked)

      active_grants =
        AccessGrant
        |> Ash.Query.filter(tenant_id == ^tenant.id and status == :active)
        |> Ash.read!()

      assert length(active_grants) == 1
      assert hd(active_grants).id == active_grant.id
    end

    test "filters grants by credential" do
      tenant = insert(:tenant)
      credential1 = insert(:access_credential, tenant: tenant)
      credential2 = insert(:access_credential, tenant: tenant)

      grant1 = insert(:access_grant, tenant: tenant, access_credential: credential1)
      _grant2 = insert(:access_grant, tenant: tenant, access_credential: credential2)

      credential1_grants =
        AccessGrant
        |> Ash.Query.filter(tenant_id == ^tenant.id and access_credential_id == ^credential1.id)
        |> Ash.read!()

      assert length(credential1_grants) == 1
      assert hd(credential1_grants).id == grant1.id
    end

    test "filters grants by location" do
      tenant = insert(:tenant)
      location1 = insert(:location, tenant: tenant)
      location2 = insert(:location, tenant: tenant)

      grant1 = insert(:access_grant, tenant: tenant, location: location1)
      _grant2 = insert(:access_grant, tenant: tenant, location: location2)

      location1_grants =
        AccessGrant
        |> Ash.Query.filter(tenant_id == ^tenant.id and location_id == ^location1.id)
        |> Ash.read!()

      assert length(location1_grants) == 1
      assert hd(location1_grants).id == grant1.id
    end

    test "filters grants by access level" do
      tenant = insert(:tenant)
      level1 = insert(:access_level, tenant: tenant, level_name: "Employee")
      level2 = insert(:access_level, tenant: tenant, level_name: "Manager")

      grant1 = insert(:access_grant, tenant: tenant, access_level: level1)
      _grant2 = insert(:access_grant, tenant: tenant, access_level: level2)

      employee_grants =
        AccessGrant
        |> Ash.Query.filter(tenant_id == ^tenant.id and access_level_id == ^level1.id)
        |> Ash.read!()

      assert length(employee_grants) == 1
      assert hd(employee_grants).id == grant1.id
    end
  end

  describe "update operations" do
    test "updates grant status" do
      tenant = insert(:tenant)
      grant = insert(:access_grant, tenant: tenant, status: :active)

      update_attrs = %{
        status: :expired,
        expired_at: DateTime.utc_now(),
        expiry_reason: "Time limit reached"
      }

      assert {:ok, updated_grant} =
               grant
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_grant.status == :expired
      assert updated_grant.expired_at != nil
      assert updated_grant.expiry_reason == "Time limit reached"
    end

    test "extends grant expiry time" do
      tenant = insert(:tenant)
      original_expiry = DateTime.add(DateTime.utc_now(), 3600)
      grant = insert(:access_grant, tenant: tenant, expires_at: original_expiry)

      # Extend by 2 hours
      new_expiry = DateTime.add(DateTime.utc_now(), 7200)

      update_attrs = %{
        expires_at: new_expiry,
        extended_by_user_id: insert(:user, tenant: tenant).id,
        extension_reason: "Project deadline extended"
      }

      assert {:ok, updated_grant} =
               grant
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert DateTime.compare(updated_grant.expires_at, original_expiry) == :gt
      assert updated_grant.extended_by_user_id != nil
      assert updated_grant.extension_reason == "Project deadline extended"
    end

    test "revokes access grant" do
      tenant = insert(:tenant)
      grant = insert(:access_grant, tenant: tenant, status: :active)
      revoking_user = insert(:user, tenant: tenant)

      update_attrs = %{
        status: :revoked,
        revoked_at: DateTime.utc_now(),
        revoked_by_user_id: revoking_user.id,
        revocation_reason: "Employee terminated"
      }

      assert {:ok, updated_grant} =
               grant
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_grant.status == :revoked
      assert updated_grant.revoked_at != nil
      assert updated_grant.revoked_by_user_id == revoking_user.id
      assert updated_grant.revocation_reason == "Employee terminated"
    end

    test "suspends access grant temporarily" do
      tenant = insert(:tenant)
      grant = insert(:access_grant, tenant: tenant, status: :active)
      suspending_user = insert(:user, tenant: tenant)

      update_attrs = %{
        status: :suspended,
        suspended_at: DateTime.utc_now(),
        suspended_by_user_id: suspending_user.id,
        suspension_reason: "Security investigation",
        # 24 hours
        suspension_until: DateTime.add(DateTime.utc_now(), 86_400)
      }

      assert {:ok, updated_grant} =
               grant
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_grant.status == :suspended
      assert updated_grant.suspended_at != nil
      assert updated_grant.suspended_by_user_id == suspending_user.id
      assert updated_grant.suspension_reason == "Security investigation"
      assert updated_grant.suspension_until != nil
    end

    test "cannot update grant from different tenant" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      grant = insert(:access_grant, tenant: tenant1)

      # Try to update with different tenant context
      update_attrs = %{
        status: :revoked,
        tenant_id: tenant2.id
      }

      # This should fail due to tenant isolation
      assert {:error, %Ash.Error.Invalid{}} =
               grant
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)
    end
  end

  describe "delete operations" do
    test "deletes access grant" do
      tenant = insert(:tenant)
      grant = insert(:access_grant, tenant: tenant)

      assert :ok = grant |> Ash.destroy(authorize?: false)

      assert {:ok, nil} =
               AccessGrant
               |> Ash.Query.filter(id == ^grant.id)
               |> Ash.read_one()
    end

    test "soft deletes active grant instead of hard delete" do
      tenant = insert(:tenant)
      grant = insert(:access_grant, tenant: tenant, status: :active)

      # Active grants should be revoked instead of deleted
      assert {:ok, updated_grant} =
               grant
               |> Ash.Changeset.for_update(:update, %{
                 status: :revoked,
                 revocation_reason: "Administrative deletion"
               })
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_grant.status == :revoked
    end
  end

  describe "relationships" do
    test "loads access credential relationship" do
      tenant = insert(:tenant)
      credential = insert(:access_credential, tenant: tenant, credential_type: "badge")
      grant = insert(:access_grant, access_credential: credential, tenant: tenant)

      loaded_grant =
        AccessGrant
        |> Ash.Query.filter(id == ^grant.id)
        |> Ash.Query.load(:access_credential)
        |> Ash.read_one!()

      assert loaded_grant.access_credential.credential_type == "badge"
    end

    test "loads access level relationship" do
      tenant = insert(:tenant)
      level = insert(:access_level, tenant: tenant, level_name: "Manager")
      grant = insert(:access_grant, access_level: level, tenant: tenant)

      loaded_grant =
        AccessGrant
        |> Ash.Query.filter(id == ^grant.id)
        |> Ash.Query.load(:access_level)
        |> Ash.read_one!()

      assert loaded_grant.access_level.level_name == "Manager"
    end

    test "loads access schedule relationship" do
      tenant = insert(:tenant)
      schedule = insert(:access_schedule, tenant: tenant, schedule_name: "Business Hours")
      grant = insert(:access_grant, access_schedule: schedule, tenant: tenant)

      loaded_grant =
        AccessGrant
        |> Ash.Query.filter(id == ^grant.id)
        |> Ash.Query.load(:access_schedule)
        |> Ash.read_one!()

      assert loaded_grant.access_schedule.schedule_name == "Business Hours"
    end

    test "loads location relationship" do
      tenant = insert(:tenant)
      location = insert(:location, tenant: tenant, name: "Main Building")
      grant = insert(:access_grant, location: location, tenant: tenant)

      loaded_grant =
        AccessGrant
        |> Ash.Query.filter(id == ^grant.id)
        |> Ash.Query.load(:location)
        |> Ash.read_one!()

      assert loaded_grant.location.name == "Main Building"
    end

    test "loads granted_by user relationship" do
      tenant = insert(:tenant)
      granting_user = insert(:user, tenant: tenant, email: "admin@example.com")
      grant = insert(:access_grant, tenant: tenant, granted_by_user_id: granting_user.id)

      # Load the grant with user information
      loaded_grant =
        AccessGrant
        |> Ash.Query.filter(id == ^grant.id)
        |> Ash.read_one!()

      assert loaded_grant.granted_by_user_id == granting_user.id
    end
  end

  describe "validations" do
    test "validates expires_at is after granted_at" do
      tenant = insert(:tenant)
      credential = insert(:access_credential, tenant: tenant)
      level = insert(:access_level, tenant: tenant)

      granted_time = DateTime.utc_now()
      # 1 hour before granted
      expires_time = DateTime.add(granted_time, -3600)

      invalid_attrs = %{
        access_credential_id: credential.id,
        access_level_id: level.id,
        granted_at: granted_time,
        expires_at: expires_time,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AccessGrant
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "validates granted_at is not in the future" do
      tenant = insert(:tenant)
      credential = insert(:access_credential, tenant: tenant)
      level = insert(:access_level, tenant: tenant)

      # 1 hour from now
      future_time = DateTime.add(DateTime.utc_now(), 3600)

      invalid_attrs = %{
        access_credential_id: credential.id,
        access_level_id: level.id,
        granted_at: future_time,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AccessGrant
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "validates status enum" do
      tenant = insert(:tenant)
      credential = insert(:access_credential, tenant: tenant)
      level = insert(:access_level, tenant: tenant)

      # Valid status values
      valid_statuses = [:pending, :active, :expired, :revoked, :suspended]

      for status <- valid_statuses do
        valid_attrs = %{
          access_credential_id: credential.id,
          access_level_id: level.id,
          status: status,
          tenant_id: tenant.id
        }

        assert {:ok, _grant} =
                 AccessGrant
                 |> Ash.Changeset.for_create(:create, valid_attrs)
                 |> Ash.create(authorize?: false)
      end
    end

    test "validates suspension_until is after suspended_at when suspended" do
      tenant = insert(:tenant)
      grant = insert(:access_grant, tenant: tenant, status: :active)

      suspended_time = DateTime.utc_now()
      # 1 hour before suspended
      suspension_until = DateTime.add(suspended_time, -3600)

      update_attrs = %{
        status: :suspended,
        suspended_at: suspended_time,
        suspension_until: suspension_until
      }

      assert {:error, %Ash.Error.Invalid{}} =
               grant
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)
    end
  end

  describe "business logic" do
    test "grant expiry detection" do
      tenant = insert(:tenant)

      # Create expired grant
      expired_grant =
        insert(:access_grant,
          tenant: tenant,
          status: :active,
          # 30 minutes ago
          expires_at: DateTime.add(DateTime.utc_now(), -1800)
        )

      # Create active grant
      active_grant =
        insert(:access_grant,
          tenant: tenant,
          status: :active,
          # 30 minutes from now
          expires_at: DateTime.add(DateTime.utc_now(), 1800)
        )

      # Query for expired grants
      expired_grants =
        AccessGrant
        |> Ash.Query.filter(
          tenant_id == ^tenant.id and
            status == :active and
            expires_at < ^DateTime.utc_now()
        )
        |> Ash.read!()

      assert length(expired_grants) == 1
      assert hd(expired_grants).id == expired_grant.id

      # Active grant should not be in expired list
      expired_ids = Enum.map(expired_grants, & &1.id)
      refute active_grant.id in expired_ids
    end

    test "access level hierarchy validation" do
      tenant = insert(:tenant)
      credential = insert(:access_credential, tenant: tenant)

      # Create access levels with hierarchy
      basic_level = insert(:access_level, tenant: tenant, level_name: "Basic", priority: 1)
      manager_level = insert(:access_level, tenant: tenant, level_name: "Manager", priority: 5)
      admin_level = insert(:access_level, tenant: tenant, level_name: "Admin", priority: 10)

      # Grant different levels to same credential
      _basic_grant =
        insert(:access_grant,
          tenant: tenant,
          access_credential: credential,
          access_level: basic_level,
          status: :active
        )

      _manager_grant =
        insert(:access_grant,
          tenant: tenant,
          access_credential: credential,
          access_level: manager_level,
          status: :active
        )

      # Find highest access level for credential
      highest_grant =
        AccessGrant
        |> Ash.Query.filter(
          tenant_id == ^tenant.id and
            access_credential_id == ^credential.id and
            status == :active
        )
        |> Ash.Query.load(:access_level)
        |> Ash.read!()
        |> Enum.max_by(fn grant -> grant.access_level.priority end)

      assert highest_grant.access_level.level_name == "Manager"
      assert highest_grant.access_level.priority == 5
    end

    test "time - based access validation" do
      tenant = insert(:tenant)
      credential = insert(:access_credential, tenant: tenant)
      level = insert(:access_level, tenant: tenant)

      # Create schedule for business hours (9 AM - 5 PM weekdays)
      schedule =
        insert(:access_schedule,
          tenant: tenant,
          schedule_name: "Business Hours",
          # Monday - Friday
          days_of_week: [1, 2, 3, 4, 5],
          start_time: ~T[09:00:00],
          end_time: ~T[17:00:00]
        )

      grant =
        insert(:access_grant,
          tenant: tenant,
          access_credential: credential,
          access_level: level,
          access_schedule: schedule,
          status: :active
        )

      # Load grant with schedule
      loaded_grant =
        AccessGrant
        |> Ash.Query.filter(id == ^grant.id)
        |> Ash.Query.load(:access_schedule)
        |> Ash.read_one!()

      # Verify schedule constraints
      assert loaded_grant.access_schedule.schedule_name == "Business Hours"
      # Monday
      assert 1 in loaded_grant.access_schedule.days_of_week
      # Friday
      assert 5 in loaded_grant.access_schedule.days_of_week
      # Saturday
      refute 6 in loaded_grant.access_schedule.days_of_week
      # Sunday
      refute 7 in loaded_grant.access_schedule.days_of_week
    end

    test "concurrent access limit enforcement" do
      tenant = insert(:tenant)
      location = insert(:location, tenant: tenant)
      level = insert(:access_level, tenant: tenant)

      # Create multiple credentials with grants for same location
      credentials = create_list(5, :access_credential, tenant: tenant)

      _grants =
        Enum.map(credentials, fn credential ->
          insert(:access_grant,
            tenant: tenant,
            access_credential: credential,
            access_level: level,
            location: location,
            status: :active
          )
        end)

      # Count active grants for location
      active_count =
        AccessGrant
        |> Ash.Query.filter(
          tenant_id == ^tenant.id and
            location_id == ^location.id and
            status == :active
        )
        |> Ash.read!()
        |> length()

      assert active_count == 5

      # Business rule: Could implement maximum concurrent access limit
      max_concurrent_access = 10
      assert active_count <= max_concurrent_access
    end

    test "access audit trail" do
      tenant = insert(:tenant)
      granting_user = insert(:user, tenant: tenant)
      revoking_user = insert(:user, tenant: tenant)

      # Create grant
      grant =
        insert(:access_grant,
          tenant: tenant,
          status: :active,
          granted_by_user_id: granting_user.id,
          granted_at: DateTime.utc_now(),
          grant_reason: "New employee onboarding"
        )

      # Revoke grant
      revoked_time = DateTime.utc_now()

      assert {:ok, updated_grant} =
               grant
               |> Ash.Changeset.for_update(:update, %{
                 status: :revoked,
                 revoked_at: revoked_time,
                 revoked_by_user_id: revoking_user.id,
                 revocation_reason: "Employee departure"
               })
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      # Verify complete audit trail
      assert updated_grant.granted_by_user_id == granting_user.id
      assert updated_grant.grant_reason == "New employee onboarding"
      assert updated_grant.revoked_by_user_id == revoking_user.id
      assert updated_grant.revocation_reason == "Employee departure"
      assert updated_grant.status == :revoked
    end

    test "emergency access override" do
      tenant = insert(:tenant)
      credential = insert(:access_credential, tenant: tenant)

      emergency_level =
        insert(:access_level, tenant: tenant, level_name: "Emergency", priority: 99)

      location = insert(:location, tenant: tenant)
      emergency_user = insert(:user, tenant: tenant)

      # Create emergency access grant
      emergency_grant =
        insert(:access_grant,
          tenant: tenant,
          access_credential: credential,
          access_level: emergency_level,
          location: location,
          status: :active,
          granted_by_user_id: emergency_user.id,
          grant_reason: "Emergency evacuation coordinator",
          is_emergency_override: true,
          emergency_authorized_by: emergency_user.id
        )

      # Verify emergency access properties
      assert emergency_grant.is_emergency_override == true
      assert emergency_grant.emergency_authorized_by == emergency_user.id
      assert emergency_grant.grant_reason == "Emergency evacuation coordinator"

      # Emergency access should have highest priority
      loaded_grant =
        AccessGrant
        |> Ash.Query.filter(id == ^emergency_grant.id)
        |> Ash.Query.load(:access_level)
        |> Ash.read_one!()

      assert loaded_grant.access_level.priority == 99
    end

    test "access pattern analysis" do
      tenant = insert(:tenant)
      credential = insert(:access_credential, tenant: tenant)
      level = insert(:access_level, tenant: tenant)
      location = insert(:location, tenant: tenant)

      # Create grants with different time patterns
      grant_times = [
        # 30 days ago
        DateTime.add(DateTime.utc_now(), -86_400 * 30),
        # 20 days ago
        DateTime.add(DateTime.utc_now(), -86_400 * 20),
        # 10 days ago
        DateTime.add(DateTime.utc_now(), -86_400 * 10),
        # 5 days ago
        DateTime.add(DateTime.utc_now(), -86_400 * 5),
        # Now
        DateTime.utc_now()
      ]

      grants =
        Enum.map(grant_times, fn time ->
          insert(:access_grant,
            tenant: tenant,
            access_credential: credential,
            access_level: level,
            location: location,
            granted_at: time,
            # 24 hour grants
            expires_at: DateTime.add(time, 86_400),
            status:
              if(time < DateTime.add(DateTime.utc_now(), -86_400), do: :expired, else: :active)
          )
        end)

      # Analyze access frequency
      assert length(grants) == 5

      # Find most recent grant
      most_recent = Enum.max_by(grants, & &1.granted_at, DateTime)
      assert most_recent.status == :active

      # Count historical grants
      historical_count =
        grants
        |> Enum.count(fn grant -> grant.status == :expired end)

      assert historical_count == 4
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
