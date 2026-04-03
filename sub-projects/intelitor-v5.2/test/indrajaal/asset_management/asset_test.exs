defmodule Indrajaal.AssetManagement.AssetTest do
  use Indrajaal.DataCase
  require Ash.Query
  alias Indrajaal.AssetManagement.Asset

  describe "create / 1" do
    test "creates asset with valid attributes" do
      tenant = insert(:tenant)
      category = insert(:asset_category, tenant: tenant)
      location = insert(:asset_location, tenant: tenant)

      valid_attrs = %{
        name: "Security Camera #001",
        serial_number: "SC - 2024 - 001",
        asset_category_id: category.id,
        asset_location_id: location.id,
        purchase_date: ~D[2024-01-15],
        purchase_cost: Decimal.new("2500.00"),
        status: :active,
        tenant_id: tenant.id
      }

      assert {:ok, asset} =
               Asset
               |> Ash.Changeset.for_create(:create, valid_attrs)
               |> Ash.create(authorize?: false)

      assert asset.name == "Security Camera #001"
      assert asset.serial_number == "SC - 2024 - 001"
      assert asset.status == :active
      assert asset.tenant_id == tenant.id
    end

    test "__requires name" do
      tenant = insert(:tenant)

      invalid_attrs = %{
        serial_number: "SC - 2024 - 001",
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Asset
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "__requires unique serial number within tenant" do
      tenant = insert(:tenant)
      category = insert(:asset_category, tenant: tenant)

      asset_attrs = %{
        name: "Asset 1",
        serial_number: "DUPLICATE - 001",
        asset_category_id: category.id,
        tenant_id: tenant.id
      }

      # Create first asset
      assert {:ok, _asset1} =
               Asset
               |> Ash.Changeset.for_create(:create, asset_attrs)
               |> Ash.create(authorize?: false)

      # Try to create second asset with same serial number
      duplicate_attrs = %{
        name: "Asset 2",
        serial_number: "DUPLICATE - 001",
        asset_category_id: category.id,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Asset
               |> Ash.Changeset.for_create(:create, duplicate_attrs)
               |> Ash.create(authorize?: false)
    end

    test "allows same serial number across different tenants" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)
      category1 = insert(:asset_category, tenant: tenant1)
      category2 = insert(:asset_category, tenant: tenant2)

      asset_attrs_1 = %{
        name: "Asset 1",
        serial_number: "SHARED - 001",
        asset_category_id: category1.id,
        tenant_id: tenant1.id
      }

      asset_attrs_2 = %{
        name: "Asset 2",
        serial_number: "SHARED - 001",
        asset_category_id: category2.id,
        tenant_id: tenant2.id
      }

      assert {:ok, asset1} =
               Asset
               |> Ash.Changeset.for_create(:create, asset_attrs_1)
               |> Ash.create(authorize?: false)

      assert {:ok, asset2} =
               Asset
               |> Ash.Changeset.for_create(:create, asset_attrs_2)
               |> Ash.create(authorize?: false)

      assert asset1.serial_number == asset2.serial_number
      assert asset1.tenant_id != asset2.tenant_id
    end
  end

  describe "read operations" do
    test "lists assets for tenant" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      # Create assets for different tenants
      asset1 = insert(:asset, tenant: tenant, name: "Tenant 1 Asset")
      asset2 = insert(:asset, tenant: tenant, name: "Another Tenant 1 Asset")
      _asset3 = insert(:asset, tenant: other_tenant, name: "Tenant 2 Asset")

      assets =
        Asset
        |> Ash.Query.filter(tenant_id == ^tenant.id)
        |> Ash.read!()

      assert length(assets) == 2
      asset_names = Enum.map(assets, & &1.name)
      assert "Tenant 1 Asset" in asset_names
      assert "Another Tenant 1 Asset" in asset_names
      refute "Tenant 2 Asset" in asset_names
    end

    test "reads asset by id with tenant isolation" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      asset = insert(:asset, tenant: tenant)
      other_asset = insert(:asset, tenant: other_tenant)

      # Can read asset from same tenant
      assert {:ok, found_asset} =
               Asset
               |> Ash.Query.filter(id == ^asset.id and tenant_id == ^tenant.id)
               |> Ash.read_one()

      assert found_asset.id == asset.id

      # Cannot read asset from different tenant
      assert {:ok, nil} =
               Asset
               |> Ash.Query.filter(id == ^other_asset.id and tenant_id == ^tenant.id)
               |> Ash.read_one()
    end
  end

  describe "update operations" do
    test "updates asset attributes" do
      tenant = insert(:tenant)
      asset = insert(:asset, tenant: tenant, name: "Original Name")

      update_attrs = %{
        name: "Updated Name",
        status: :maintenance
      }

      assert {:ok, updated_asset} =
               asset
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_asset.name == "Updated Name"
      assert updated_asset.status == :maintenance
    end

    test "cannot update asset from different tenant" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      asset = insert(:asset, tenant: tenant1)

      # Try to update with different tenant __context
      update_attrs = %{
        name: "Unauthorized Update",
        tenant_id: tenant2.id
      }

      # This should fail due to tenant isolation
      assert {:error, %Ash.Error.Invalid{}} =
               asset
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)
    end
  end

  describe "delete operations" do
    test "deletes asset" do
      tenant = insert(:tenant)
      asset = insert(:asset, tenant: tenant)

      assert :ok = asset |> Ash.destroy(authorize?: false)

      assert {:ok, nil} =
               Asset
               |> Ash.Query.filter(id == ^asset.id)
               |> Ash.read_one()
    end

    test "maintains referential integrity with assignments" do
      tenant = insert(:tenant)
      asset = insert(:asset, tenant: tenant)
      _assignment = insert(:asset_assignment, asset: asset, tenant: tenant)

      # Should not be able to delete asset with active assignments
      assert {:error, %Ash.Error.Invalid{}} = asset |> Ash.destroy(authorize?: false)
    end
  end

  describe "status transitions" do
    test "active to maintenance transition" do
      tenant = insert(:tenant)
      asset = insert(:asset, tenant: tenant, status: :active)

      assert {:ok, updated_asset} =
               asset
               |> Ash.Changeset.for_update(:update, %{status: :maintenance})
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_asset.status == :maintenance
    end

    test "retired to active transition should fail" do
      tenant = insert(:tenant)
      asset = insert(:asset, tenant: tenant, status: :retired)

      assert {:error, %Ash.Error.Invalid{}} =
               asset
               |> Ash.Changeset.for_update(:update, %{status: :active})
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)
    end
  end

  describe "relationships" do
    test "loads category relationship" do
      tenant = insert(:tenant)
      category = insert(:asset_category, tenant: tenant, name: "Security Equipment")
      asset = insert(:asset, tenant: tenant, asset_category: category)

      loaded_asset =
        Asset
        |> Ash.Query.filter(id == ^asset.id)
        |> Ash.Query.load(:asset_category)
        |> Ash.read_one!()

      assert loaded_asset.asset_category.name == "Security Equipment"
    end

    test "loads assignments relationship" do
      tenant = insert(:tenant)
      asset = insert(:asset, tenant: tenant)
      assignment = insert(:asset_assignment, asset: asset, tenant: tenant)

      loaded_asset =
        Asset
        |> Ash.Query.filter(id == ^asset.id)
        |> Ash.Query.load(:assignments)
        |> Ash.read_one!()

      assert length(loaded_asset.assignments) == 1
      assert hd(loaded_asset.assignments).id == assignment.id
    end
  end

  describe "validations" do
    test "validates purchase cost is positive" do
      tenant = insert(:tenant)
      category = insert(:asset_category, tenant: tenant)

      invalid_attrs = %{
        name: "Test Asset",
        asset_category_id: category.id,
        purchase_cost: Decimal.new("-100.00"),
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Asset
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "validates purchase date not in future" do
      tenant = insert(:tenant)
      category = insert(:asset_category, tenant: tenant)

      future_date = Date.add(Date.utc_today(), 30)

      invalid_attrs = %{
        name: "Test Asset",
        asset_category_id: category.id,
        purchase_date: future_date,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Asset
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
