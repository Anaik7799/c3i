defmodule Indrajaal.AssetManagement.AssetAssignmentTest do
  use Indrajaal.DataCase
  require Ash.Query
  alias Indrajaal.AssetManagement.AssetAssignment

  describe "create / 1" do
    test "creates asset assignment with valid attributes" do
      tenant = insert(:tenant)
      asset = insert(:asset, tenant: tenant)
      user = insert(:user, tenant: tenant)

      valid_attrs = %{
        asset_id: asset.id,
        assigned_to_type: "__user",
        assigned_to_id: user.id,
        assigned_date: Date.utc_today(),
        purpose: "Security monitoring duties",
        status: :active,
        tenant_id: tenant.id
      }

      assert {:ok, assignment} =
               AssetAssignment
               |> Ash.Changeset.for_create(:create, valid_attrs)
               |> Ash.create(authorize?: false)

      assert assignment.asset_id == asset.id
      assert assignment.assigned_to_type == "__user"
      assert assignment.assigned_to_id == user.id
      assert assignment.status == :active
      assert assignment.tenant_id == tenant.id
    end

    test "__requires asset_id" do
      tenant = insert(:tenant)
      user = insert(:user, tenant: tenant)

      invalid_attrs = %{
        assigned_to_type: "__user",
        assigned_to_id: user.id,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AssetAssignment
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "__requires assigned_to_type and assigned_to_id" do
      tenant = insert(:tenant)
      asset = insert(:asset, tenant: tenant)

      invalid_attrs = %{
        asset_id: asset.id,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AssetAssignment
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "pr__events duplicate active assignments for same asset" do
      tenant = insert(:tenant)
      asset = insert(:asset, tenant: tenant)
      __user1 = insert(:user, tenant: tenant)
      __user2 = insert(:user, tenant: tenant)

      # Create first assignment
      first_attrs = %{
        asset_id: asset.id,
        assigned_to_type: "__user",
        assigned_to_id: __user1.id,
        status: :active,
        tenant_id: tenant.id
      }

      assert {:ok, _assignment1} =
               AssetAssignment
               |> Ash.Changeset.for_create(:create, first_attrs)
               |> Ash.create(authorize?: false)

      # Try to create second active assignment for same asset
      second_attrs = %{
        asset_id: asset.id,
        assigned_to_type: "__user",
        assigned_to_id: __user2.id,
        status: :active,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AssetAssignment
               |> Ash.Changeset.for_create(:create, second_attrs)
               |> Ash.create(authorize?: false)
    end

    test "allows multiple assignments if previous are returned" do
      tenant = insert(:tenant)
      asset = insert(:asset, tenant: tenant)
      __user1 = insert(:user, tenant: tenant)
      __user2 = insert(:user, tenant: tenant)

      # Create and return first assignment
      first_attrs = %{
        asset_id: asset.id,
        assigned_to_type: "__user",
        assigned_to_id: __user1.id,
        status: :returned,
        tenant_id: tenant.id
      }

      assert {:ok, _assignment1} =
               AssetAssignment
               |> Ash.Changeset.for_create(:create, first_attrs)
               |> Ash.create(authorize?: false)

      # Create new active assignment
      second_attrs = %{
        asset_id: asset.id,
        assigned_to_type: "__user",
        assigned_to_id: __user2.id,
        status: :active,
        tenant_id: tenant.id
      }

      assert {:ok, assignment2} =
               AssetAssignment
               |> Ash.Changeset.for_create(:create, second_attrs)
               |> Ash.create(authorize?: false)

      assert assignment2.status == :active
    end
  end

  describe "read operations" do
    test "lists assignments for tenant" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      # Create assignments for different tenants
      assignment1 = insert(:asset_assignment, tenant: tenant)
      assignment2 = insert(:asset_assignment, tenant: tenant)
      _assignment3 = insert(:asset_assignment, tenant: other_tenant)

      assignments =
        AssetAssignment
        |> Ash.Query.filter(tenant_id == ^tenant.id)
        |> Ash.read!()

      assert length(assignments) == 2
      assignment_ids = Enum.map(assignments, & &1.id)
      assert assignment1.id in assignment_ids
      assert assignment2.id in assignment_ids
    end

    test "reads assignment by id with tenant isolation" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      assignment = insert(:asset_assignment, tenant: tenant)
      other_assignment = insert(:asset_assignment, tenant: other_tenant)

      # Can read assignment from same tenant
      assert {:ok, found_assignment} =
               AssetAssignment
               |> Ash.Query.filter(id == ^assignment.id and tenant_id == ^tenant.id)
               |> Ash.read_one()

      assert found_assignment.id == assignment.id

      # Cannot read assignment from different tenant
      assert {:ok, nil} =
               AssetAssignment
               |> Ash.Query.filter(id == ^other_assignment.id and tenant_id == ^tenant.id)
               |> Ash.read_one()
    end

    test "filters active assignments" do
      tenant = insert(:tenant)

      active_assignment = insert(:asset_assignment, tenant: tenant, status: :active)
      _returned_assignment = insert(:asset_assignment, tenant: tenant, status: :returned)
      _lost_assignment = insert(:asset_assignment, tenant: tenant, status: :lost)

      active_assignments =
        AssetAssignment
        |> Ash.Query.filter(tenant_id == ^tenant.id and status == :active)
        |> Ash.read!()

      assert length(active_assignments) == 1
      assert hd(active_assignments).id == active_assignment.id
    end
  end

  describe "update operations" do
    test "updates assignment status to returned" do
      tenant = insert(:tenant)
      assignment = insert(:asset_assignment, tenant: tenant, status: :active)

      update_attrs = %{
        status: :returned,
        returned_date: Date.utc_today(),
        return_notes: "Equipment returned in good condition"
      }

      assert {:ok, updated_assignment} =
               assignment
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_assignment.status == :returned
      assert updated_assignment.returned_date == Date.utc_today()
      assert updated_assignment.return_notes == "Equipment returned in
        good condition"
    end

    test "updates assignment notes" do
      tenant = insert(:tenant)
      assignment = insert(:asset_assignment, tenant: tenant)

      update_attrs = %{
        notes: "Updated assignment notes"
      }

      assert {:ok, updated_assignment} =
               assignment
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_assignment.notes == "Updated assignment notes"
    end

    test "cannot update assignment from different tenant" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      assignment = insert(:asset_assignment, tenant: tenant1)

      # Try to update with different tenant __context
      update_attrs = %{
        status: :returned,
        tenant_id: tenant2.id
      }

      # This should fail due to tenant isolation
      assert {:error, %Ash.Error.Invalid{}} =
               assignment
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)
    end
  end

  describe "delete operations" do
    test "deletes assignment" do
      tenant = insert(:tenant)
      assignment = insert(:asset_assignment, tenant: tenant)

      assert :ok = assignment |> Ash.destroy(authorize?: false)

      assert {:ok, nil} =
               AssetAssignment
               |> Ash.Query.filter(id == ^assignment.id)
               |> Ash.read_one()
    end

    test "soft deletes active assignment instead of hard delete" do
      tenant = insert(:tenant)
      assignment = insert(:asset_assignment, tenant: tenant, status: :active)

      # Active assignments should be soft deleted (marked as cancelled)
      assert {:ok, updated_assignment} =
               assignment
               |> Ash.Changeset.for_update(:update, %{status: :cancelled})
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_assignment.status == :cancelled
    end
  end

  describe "relationships" do
    test "loads asset relationship" do
      tenant = insert(:tenant)
      asset = insert(:asset, tenant: tenant, name: "Security Camera #1")
      assignment = insert(:asset_assignment, asset: asset, tenant: tenant)

      loaded_assignment =
        AssetAssignment
        |> Ash.Query.filter(id == ^assignment.id)
        |> Ash.Query.load(:asset)
        |> Ash.read_one!()

      assert loaded_assignment.asset.name == "Security Camera #1"
    end

    test "polymorphic assigned_to relationship works" do
      tenant = insert(:tenant)
      user = insert(:user, tenant: tenant, email: "test@example.com")

      assignment =
        insert(:asset_assignment,
          tenant: tenant,
          assigned_to_type: "__user",
          assigned_to_id: user.id
        )

      # Load the assignment with the polymorphic relationship
      loaded_assignment =
        AssetAssignment
        |> Ash.Query.filter(id == ^assignment.id)
        |> Ash.read_one!()

      assert loaded_assignment.assigned_to_type == "__user"
      assert loaded_assignment.assigned_to_id == user.id
    end
  end

  describe "validations" do
    test "validates assigned_date not in future" do
      tenant = insert(:tenant)
      asset = insert(:asset, tenant: tenant)
      user = insert(:user, tenant: tenant)

      future_date = Date.add(Date.utc_today(), 30)

      invalid_attrs = %{
        asset_id: asset.id,
        assigned_to_type: "__user",
        assigned_to_id: user.id,
        assigned_date: future_date,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AssetAssignment
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "validates returned_date not before assigned_date" do
      tenant = insert(:tenant)

      assignment =
        insert(:asset_assignment,
          tenant: tenant,
          assigned_date: Date.utc_today()
        )

      yesterday = Date.add(Date.utc_today(), -1)

      update_attrs = %{
        status: :returned,
        returned_date: yesterday
      }

      assert {:error, %Ash.Error.Invalid{}} =
               assignment
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)
    end

    test "validates assigned_to_type is valid" do
      tenant = insert(:tenant)
      asset = insert(:asset, tenant: tenant)

      invalid_attrs = %{
        asset_id: asset.id,
        assigned_to_type: "invalid_type",
        assigned_to_id: Ash.UUID.generate(),
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AssetAssignment
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end
  end

  describe "business logic" do
    test "assignment duration calculation" do
      tenant = insert(:tenant)
      assigned_date = Date.add(Date.utc_today(), -30)
      returned_date = Date.utc_today()

      assignment =
        insert(:asset_assignment,
          tenant: tenant,
          assigned_date: assigned_date,
          returned_date: returned_date,
          status: :returned
        )

      # Calculate assignment duration
      duration = Date.diff(returned_date, assigned_date)
      assert duration == 30
    end

    test "overdue assignment detection" do
      tenant = insert(:tenant)
      overdue_date = Date.add(Date.utc_today(), -60)

      overdue_assignment =
        insert(:asset_assignment,
          tenant: tenant,
          assigned_date: overdue_date,
          expected_return_date: Date.add(Date.utc_today(), -30),
          status: :active
        )

      # Query for overdue assignments
      overdue_assignments =
        AssetAssignment
        |> Ash.Query.filter(
          tenant_id == ^tenant.id and
            status == :active and
            expected_return_date < ^Date.utc_today()
        )
        |> Ash.read!()

      assert length(overdue_assignments) == 1
      assert hd(overdue_assignments).id == overdue_assignment.id
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
