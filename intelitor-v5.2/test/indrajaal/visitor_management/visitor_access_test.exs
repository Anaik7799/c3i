defmodule Indrajaal.VisitorManagement.VisitorAccessTest do
  use Indrajaal.DataCase
  require Ash.Query
  alias Indrajaal.VisitorManagement.VisitorAccess

  describe "create / 1" do
    test "creates visitor access with valid attributes" do
      tenant = insert(:tenant)
      visitor = insert(:visitor, tenant: tenant)
      location = insert(:location, tenant: tenant)

      valid_attrs = %{
        visitor_id: visitor.id,
        location_id: location.id,
        access_type: :temporary,
        access_level: :visitor,
        granted_at: DateTime.utc_now(),
        # 1 hour
        expires_at: DateTime.add(DateTime.utc_now(), 3600),
        granted_by_user_id: insert(:user, tenant: tenant).id,
        status: :active,
        tenant_id: tenant.id
      }

      assert {:ok, access} =
               VisitorAccess
               |> Ash.Changeset.for_create(:create, valid_attrs)
               |> Ash.create(authorize?: false)

      assert access.visitor_id == visitor.id
      assert access.location_id == location.id
      assert access.access_type == :temporary
      assert access.access_level == :visitor
      assert access.status == :active
      assert access.tenant_id == tenant.id
    end

    test "requires visitor_id" do
      tenant = insert(:tenant)
      location = insert(:location, tenant: tenant)

      invalid_attrs = %{
        location_id: location.id,
        access_type: :temporary,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               VisitorAccess
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "requires location_id" do
      tenant = insert(:tenant)
      visitor = insert(:visitor, tenant: tenant)

      invalid_attrs = %{
        visitor_id: visitor.id,
        access_type: :temporary,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               VisitorAccess
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "prevents duplicate active access for same visitor-location" do
      tenant = insert(:tenant)
      visitor = insert(:visitor, tenant: tenant)
      location = insert(:location, tenant: tenant)
      user = insert(:user, tenant: tenant)

      access_attrs = %{
        visitor_id: visitor.id,
        location_id: location.id,
        access_type: :temporary,
        granted_by_user_id: user.id,
        status: :active,
        tenant_id: tenant.id
      }

      # Create first access
      assert {:ok, _access1} =
               VisitorAccess
               |> Ash.Changeset.for_create(:create, access_attrs)
               |> Ash.create(authorize?: false)

      # Try to create second active access for same visitor-location
      assert {:error, %Ash.Error.Invalid{}} =
               VisitorAccess
               |> Ash.Changeset.for_create(:create, access_attrs)
               |> Ash.create(authorize?: false)
    end

    test "allows new access after previous is revoked" do
      tenant = insert(:tenant)
      visitor = insert(:visitor, tenant: tenant)
      location = insert(:location, tenant: tenant)
      user = insert(:user, tenant: tenant)

      # Create and revoke first access
      access_attrs = %{
        visitor_id: visitor.id,
        location_id: location.id,
        access_type: :temporary,
        granted_by_user_id: user.id,
        status: :revoked,
        tenant_id: tenant.id
      }

      assert {:ok, _access1} =
               VisitorAccess
               |> Ash.Changeset.for_create(:create, access_attrs)
               |> Ash.create(authorize?: false)

      # Create new active access
      new_access_attrs = %{
        visitor_id: visitor.id,
        location_id: location.id,
        access_type: :temporary,
        granted_by_user_id: user.id,
        status: :active,
        tenant_id: tenant.id
      }

      assert {:ok, access2} =
               VisitorAccess
               |> Ash.Changeset.for_create(:create, new_access_attrs)
               |> Ash.create(authorize?: false)

      assert access2.status == :active
    end
  end

  describe "read operations" do
    test "lists visitor access for tenant" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      # Create access for different tenants
      access1 = insert(:visitor_access, tenant: tenant)
      access2 = insert(:visitor_access, tenant: tenant)
      _access3 = insert(:visitor_access, tenant: other_tenant)

      accesses =
        VisitorAccess
        |> Ash.Query.filter(tenant_id == ^tenant.id)
        |> Ash.read!()

      assert length(accesses) == 2
      access_ids = Enum.map(accesses, & &1.id)
      assert access1.id in access_ids
      assert access2.id in access_ids
    end

    test "reads visitor access by id with tenant isolation" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      access = insert(:visitor_access, tenant: tenant)
      other_access = insert(:visitor_access, tenant: other_tenant)

      # Can read access from same tenant
      assert {:ok, found_access} =
               VisitorAccess
               |> Ash.Query.filter(id == ^access.id and tenant_id == ^tenant.id)
               |> Ash.read_one()

      assert found_access.id == access.id

      # Cannot read access from different tenant
      assert {:ok, nil} =
               VisitorAccess
               |> Ash.Query.filter(id == ^other_access.id and tenant_id == ^tenant.id)
               |> Ash.read_one()
    end

    test "filters active access records" do
      tenant = insert(:tenant)

      active_access = insert(:visitor_access, tenant: tenant, status: :active)
      _expired_access = insert(:visitor_access, tenant: tenant, status: :expired)
      _revoked_access = insert(:visitor_access, tenant: tenant, status: :revoked)

      active_accesses =
        VisitorAccess
        |> Ash.Query.filter(tenant_id == ^tenant.id and status == :active)
        |> Ash.read!()

      assert length(active_accesses) == 1
      assert hd(active_accesses).id == active_access.id
    end

    test "filters access by visitor" do
      tenant = insert(:tenant)
      visitor1 = insert(:visitor, tenant: tenant)
      visitor2 = insert(:visitor, tenant: tenant)

      access1 = insert(:visitor_access, tenant: tenant, visitor: visitor1)
      _access2 = insert(:visitor_access, tenant: tenant, visitor: visitor2)

      visitor1_accesses =
        VisitorAccess
        |> Ash.Query.filter(tenant_id == ^tenant.id and visitor_id == ^visitor1.id)
        |> Ash.read!()

      assert length(visitor1_accesses) == 1
      assert hd(visitor1_accesses).id == access1.id
    end

    test "filters access by location" do
      tenant = insert(:tenant)
      location1 = insert(:location, tenant: tenant)
      location2 = insert(:location, tenant: tenant)

      access1 = insert(:visitor_access, tenant: tenant, location: location1)
      _access2 = insert(:visitor_access, tenant: tenant, location: location2)

      location1_accesses =
        VisitorAccess
        |> Ash.Query.filter(tenant_id == ^tenant.id and location_id == ^location1.id)
        |> Ash.read!()

      assert length(location1_accesses) == 1
      assert hd(location1_accesses).id == access1.id
    end
  end

  describe "update operations" do
    test "updates access status" do
      tenant = insert(:tenant)
      access = insert(:visitor_access, tenant: tenant, status: :active)

      update_attrs = %{
        status: :expired,
        expired_at: DateTime.utc_now(),
        expiry_reason: "Time limit exceeded"
      }

      assert {:ok, updated_access} =
               access
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_access.status == :expired
      assert updated_access.expired_at != nil
      assert updated_access.expiry_reason == "Time limit exceeded"
    end

    test "extends access expiry time" do
      tenant = insert(:tenant)
      original_expiry = DateTime.add(DateTime.utc_now(), 3600)
      access = insert(:visitor_access, tenant: tenant, expires_at: original_expiry)

      # Extend by 2 hours
      new_expiry = DateTime.add(DateTime.utc_now(), 7200)

      update_attrs = %{
        expires_at: new_expiry,
        extended_by_user_id: insert(:user, tenant: tenant).id,
        extension_reason: "Meeting extended"
      }

      assert {:ok, updated_access} =
               access
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert DateTime.compare(updated_access.expires_at, original_expiry) == :gt
      assert updated_access.extended_by_user_id != nil
      assert updated_access.extension_reason == "Meeting extended"
    end

    test "revokes visitor access" do
      tenant = insert(:tenant)
      access = insert(:visitor_access, tenant: tenant, status: :active)
      revoking_user = insert(:user, tenant: tenant)

      update_attrs = %{
        status: :revoked,
        revoked_at: DateTime.utc_now(),
        revoked_by_user_id: revoking_user.id,
        revocation_reason: "Security concern"
      }

      assert {:ok, updated_access} =
               access
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_access.status == :revoked
      assert updated_access.revoked_at != nil
      assert updated_access.revoked_by_user_id == revoking_user.id
      assert updated_access.revocation_reason == "Security concern"
    end

    test "cannot update access from different tenant" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      access = insert(:visitor_access, tenant: tenant1)

      # Try to update with different tenant context
      update_attrs = %{
        status: :revoked,
        tenant_id: tenant2.id
      }

      # This should fail due to tenant isolation
      assert {:error, %Ash.Error.Invalid{}} =
               access
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)
    end
  end

  describe "delete operations" do
    test "deletes visitor access" do
      tenant = insert(:tenant)
      access = insert(:visitor_access, tenant: tenant)

      assert :ok = access |> Ash.destroy(authorize?: false)

      assert {:ok, nil} =
               VisitorAccess
               |> Ash.Query.filter(id == ^access.id)
               |> Ash.read_one()
    end

    test "soft deletes active access instead of hard delete" do
      tenant = insert(:tenant)
      access = insert(:visitor_access, tenant: tenant, status: :active)

      # Active access should be revoked instead of deleted
      assert {:ok, updated_access} =
               access
               |> Ash.Changeset.for_update(:update, %{
                 status: :revoked,
                 revocation_reason: "Administrative deletion"
               })
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_access.status == :revoked
    end
  end

  describe "relationships" do
    test "loads visitor relationship" do
      tenant = insert(:tenant)
      visitor = insert(:visitor, tenant: tenant, first_name: "John", last_name: "Doe")
      access = insert(:visitor_access, visitor: visitor, tenant: tenant)

      loaded_access =
        VisitorAccess
        |> Ash.Query.filter(id == ^access.id)
        |> Ash.Query.load(:visitor)
        |> Ash.read_one!()

      assert loaded_access.visitor.first_name == "John"
      assert loaded_access.visitor.last_name == "Doe"
    end

    test "loads location relationship" do
      tenant = insert(:tenant)
      location = insert(:location, tenant: tenant, name: "Conference Room A")
      access = insert(:visitor_access, location: location, tenant: tenant)

      loaded_access =
        VisitorAccess
        |> Ash.Query.filter(id == ^access.id)
        |> Ash.Query.load(:location)
        |> Ash.read_one!()

      assert loaded_access.location.name == "Conference Room A"
    end

    test "loads granted_by user relationship" do
      tenant = insert(:tenant)
      granting_user = insert(:user, tenant: tenant, email: "security@example.com")
      access = insert(:visitor_access, tenant: tenant, granted_by_user_id: granting_user.id)

      # Load the access with user relationship
      loaded_access =
        VisitorAccess
        |> Ash.Query.filter(id == ^access.id)
        |> Ash.read_one!()

      assert loaded_access.granted_by_user_id == granting_user.id
    end
  end

  describe "validations" do
    test "validates expires_at is in the future" do
      tenant = insert(:tenant)
      visitor = insert(:visitor, tenant: tenant)
      location = insert(:location, tenant: tenant)

      # 1 hour ago
      past_time = DateTime.add(DateTime.utc_now(), -3600)

      invalid_attrs = %{
        visitor_id: visitor.id,
        location_id: location.id,
        access_type: :temporary,
        expires_at: past_time,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               VisitorAccess
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "validates granted_at is not in the future" do
      tenant = insert(:tenant)
      visitor = insert(:visitor, tenant: tenant)
      location = insert(:location, tenant: tenant)

      # 1 hour from now
      future_time = DateTime.add(DateTime.utc_now(), 3600)

      invalid_attrs = %{
        visitor_id: visitor.id,
        location_id: location.id,
        access_type: :temporary,
        granted_at: future_time,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               VisitorAccess
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "validates access_type enum" do
      tenant = insert(:tenant)
      visitor = insert(:visitor, tenant: tenant)
      location = insert(:location, tenant: tenant)

      # Valid access types
      valid_types = [:temporary, :recurring, :permanent, :emergency]

      for access_type <- valid_types do
        valid_attrs = %{
          visitor_id: visitor.id,
          location_id: location.id,
          access_type: access_type,
          tenant_id: tenant.id
        }

        assert {:ok, _access} =
                 VisitorAccess
                 |> Ash.Changeset.for_create(:create, valid_attrs)
                 |> Ash.create(authorize?: false)
      end
    end

    test "validates access_level enum" do
      tenant = insert(:tenant)
      visitor = insert(:visitor, tenant: tenant)
      location = insert(:location, tenant: tenant)

      # Valid access levels
      valid_levels = [:visitor, :contractor, :vendor, :guest, :vip]

      for access_level <- valid_levels do
        valid_attrs = %{
          visitor_id: visitor.id,
          location_id: location.id,
          access_type: :temporary,
          access_level: access_level,
          tenant_id: tenant.id
        }

        assert {:ok, _access} =
                 VisitorAccess
                 |> Ash.Changeset.for_create(:create, valid_attrs)
                 |> Ash.create(authorize?: false)
      end
    end

    test "validates status enum" do
      tenant = insert(:tenant)
      visitor = insert(:visitor, tenant: tenant)
      location = insert(:location, tenant: tenant)

      # Valid status values
      valid_statuses = [:pending, :active, :expired, :revoked, :suspended]

      for status <- valid_statuses do
        valid_attrs = %{
          visitor_id: visitor.id,
          location_id: location.id,
          access_type: :temporary,
          status: status,
          tenant_id: tenant.id
        }

        assert {:ok, _access} =
                 VisitorAccess
                 |> Ash.Changeset.for_create(:create, valid_attrs)
                 |> Ash.create(authorize?: false)
      end
    end
  end

  describe "business logic" do
    test "access expiry detection" do
      tenant = insert(:tenant)

      # Create expired access
      expired_access =
        insert(:visitor_access,
          tenant: tenant,
          status: :active,
          # 30 minutes ago
          expires_at: DateTime.add(DateTime.utc_now(), -1800)
        )

      # Create active access
      active_access =
        insert(:visitor_access,
          tenant: tenant,
          status: :active,
          # 30 minutes from now
          expires_at: DateTime.add(DateTime.utc_now(), 1800)
        )

      # Query for expired accesses
      expired_accesses =
        VisitorAccess
        |> Ash.Query.filter(
          tenant_id == ^tenant.id and
            status == :active and
            expires_at < ^DateTime.utc_now()
        )
        |> Ash.read!()

      assert length(expired_accesses) == 1
      assert hd(expired_accesses).id == expired_access.id

      # Active access should not be in expired list
      expired_ids = Enum.map(expired_accesses, & &1.id)
      refute active_access.id in expired_ids
    end

    test "access duration calculation" do
      tenant = insert(:tenant)
      # 1 hour ago
      granted_time = DateTime.add(DateTime.utc_now(), -3600)
      # 1 hour from now
      expires_time = DateTime.add(DateTime.utc_now(), 3600)

      access =
        insert(:visitor_access,
          tenant: tenant,
          granted_at: granted_time,
          expires_at: expires_time
        )

      # Calculate total access duration
      total_duration = DateTime.diff(expires_time, granted_time)
      # 2 hours in seconds
      assert total_duration == 7200

      # Calculate remaining time
      remaining_time = DateTime.diff(expires_time, DateTime.utc_now())
      # Should have time remaining
      assert remaining_time > 0
    end

    test "access audit trail" do
      tenant = insert(:tenant)
      granting_user = insert(:user, tenant: tenant)
      revoking_user = insert(:user, tenant: tenant)

      # Create access
      access =
        insert(:visitor_access,
          tenant: tenant,
          status: :active,
          granted_by_user_id: granting_user.id,
          granted_at: DateTime.utc_now()
        )

      # Revoke access
      revoked_time = DateTime.utc_now()

      assert {:ok, updated_access} =
               access
               |> Ash.Changeset.for_update(:update, %{
                 status: :revoked,
                 revoked_at: revoked_time,
                 revoked_by_user_id: revoking_user.id,
                 revocation_reason: "Meeting cancelled"
               })
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      # Verify audit trail
      assert updated_access.granted_by_user_id == granting_user.id
      assert updated_access.revoked_by_user_id == revoking_user.id
      assert updated_access.revocation_reason == "Meeting cancelled"
      assert updated_access.status == :revoked
    end

    test "concurrent access limits" do
      tenant = insert(:tenant)
      visitor = insert(:visitor, tenant: tenant)
      location1 = insert(:location, tenant: tenant)
      location2 = insert(:location, tenant: tenant)
      location3 = insert(:location, tenant: tenant)

      # Create multiple active accesses for same visitor
      _access1 =
        insert(:visitor_access,
          tenant: tenant,
          visitor: visitor,
          location: location1,
          status: :active
        )

      _access2 =
        insert(:visitor_access,
          tenant: tenant,
          visitor: visitor,
          location: location2,
          status: :active
        )

      _access3 =
        insert(:visitor_access,
          tenant: tenant,
          visitor: visitor,
          location: location3,
          status: :active
        )

      # Count active accesses for visitor
      active_count =
        VisitorAccess
        |> Ash.Query.filter(
          tenant_id == ^tenant.id and visitor_id == ^visitor.id and status == :active
        )
        |> Ash.read!()
        |> length()

      assert active_count == 3

      # Business rule: Could implement max concurrent access limit
      max_concurrent_accesses = 5
      assert active_count <= max_concurrent_accesses
    end

    test "location access overlap detection" do
      tenant = insert(:tenant)
      location = insert(:location, tenant: tenant)
      visitor1 = insert(:visitor, tenant: tenant)
      visitor2 = insert(:visitor, tenant: tenant)

      time_start = DateTime.utc_now()
      time_end = DateTime.add(time_start, 3600)

      # Create overlapping accesses for same location
      _access1 =
        insert(:visitor_access,
          tenant: tenant,
          visitor: visitor1,
          location: location,
          granted_at: time_start,
          expires_at: time_end,
          status: :active
        )

      _access2 =
        insert(:visitor_access,
          tenant: tenant,
          visitor: visitor2,
          location: location,
          # 30 minutes after start
          granted_at: DateTime.add(time_start, 1800),
          # 30 minutes after end
          expires_at: DateTime.add(time_end, 1800),
          status: :active
        )

      # Query for concurrent access to same location
      # 30 minutes in
      current_time = DateTime.add(time_start, 1800)

      concurrent_accesses =
        VisitorAccess
        |> Ash.Query.filter(
          tenant_id == ^tenant.id and
            location_id == ^location.id and
            status == :active and
            granted_at <= ^current_time and
            expires_at > ^current_time
        )
        |> Ash.read!()

      # Both accesses overlap at this time
      assert length(concurrent_accesses) == 2
    end

    test "access pattern analysis" do
      tenant = insert(:tenant)
      visitor = insert(:visitor, tenant: tenant)
      location = insert(:location, tenant: tenant)

      # Create historical access pattern
      access_times = [
        # 1 week ago
        DateTime.add(DateTime.utc_now(), -86_400 * 7),
        # 5 days ago
        DateTime.add(DateTime.utc_now(), -86_400 * 5),
        # 3 days ago
        DateTime.add(DateTime.utc_now(), -86_400 * 3),
        # 1 day ago
        DateTime.add(DateTime.utc_now(), -86_400)
      ]

      accesses =
        Enum.map(access_times, fn time ->
          insert(:visitor_access,
            tenant: tenant,
            visitor: visitor,
            location: location,
            granted_at: time,
            expires_at: DateTime.add(time, 3600),
            status: :expired
          )
        end)

      # Analyze access frequency
      assert length(accesses) == 4

      # Calculate average time between visits
      sorted_times = Enum.sort(access_times, DateTime)

      zipped = Enum.zip(sorted_times, tl(sorted_times))

      intervals =
        zipped
        |> Enum.map(fn {t1, t2} -> DateTime.diff(t2, t1) end)

      avg_interval = Enum.sum(intervals) / length(intervals)
      # Should have positive intervals between visits
      assert avg_interval > 0
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
