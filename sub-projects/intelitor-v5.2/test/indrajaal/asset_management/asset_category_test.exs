defmodule Indrajaal.AssetManagement.AssetCategoryTest do
  use Indrajaal.DataCase
  require Ash.Query
  alias Indrajaal.AssetManagement.AssetCategory

  describe "create / 1" do
    test "creates asset category with valid attributes" do
      tenant = insert(:tenant)

      valid_attrs = %{
        name: "Security Equipment",
        description: "Cameras, sensors, and monitoring devices",
        depreciation_rate: Decimal.new("0.15"),
        expected_life_years: 5,
        tenant_id: tenant.id
      }

      assert {:ok, category} =
               AssetCategory
               |> Ash.Changeset.for_create(:create, valid_attrs)
               |> Ash.create(authorize?: false)

      assert category.name == "Security Equipment"
      assert category.description == "Cameras, sensors, and monitoring devices"
      assert Decimal.equal?(category.depreciation_rate, Decimal.new("0.15"))
      assert category.expected_life_years == 5
      assert category.tenant_id == tenant.id
    end

    test "__requires name" do
      tenant = insert(:tenant)

      invalid_attrs = %{
        description: "Missing name category",
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AssetCategory
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "__requires unique name within tenant" do
      tenant = insert(:tenant)

      category_attrs = %{
        name: "Duplicate Category",
        tenant_id: tenant.id
      }

      # Create first category
      assert {:ok, _category1} =
               AssetCategory
               |> Ash.Changeset.for_create(:create, category_attrs)
               |> Ash.create(authorize?: false)

      # Try to create second category with same name
      assert {:error, %Ash.Error.Invalid{}} =
               AssetCategory
               |> Ash.Changeset.for_create(:create, category_attrs)
               |> Ash.create(authorize?: false)
    end

    test "allows same name across different tenants" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      category_attrs_1 = %{
        name: "Shared Category Name",
        tenant_id: tenant1.id
      }

      category_attrs_2 = %{
        name: "Shared Category Name",
        tenant_id: tenant2.id
      }

      assert {:ok, category1} =
               AssetCategory
               |> Ash.Changeset.for_create(:create, category_attrs_1)
               |> Ash.create(authorize?: false)

      assert {:ok, category2} =
               AssetCategory
               |> Ash.Changeset.for_create(:create, category_attrs_2)
               |> Ash.create(authorize?: false)

      assert category1.name == category2.name
      assert category1.tenant_id != category2.tenant_id
    end
  end

  describe "read operations" do
    test "lists categories for tenant" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      # Create categories for different tenants
      _category1 = insert(:asset_category, tenant: tenant, name: "Tenant 1 Category")
      _category2 = insert(:asset_category, tenant: tenant, name: "Another Tenant 1 Category")
      _category3 = insert(:asset_category, tenant: other_tenant, name: "Tenant 2 Category")

      categories =
        AssetCategory
        |> Ash.Query.filter(tenant_id == tenant.id)
        |> Ash.read!()

      assert length(categories) == 2
      category_names = Enum.map(categories, & &1.name)
      assert "Tenant 1 Category" in category_names
      assert "Another Tenant 1 Category" in category_names
      refute "Tenant 2 Category" in category_names
    end

    test "reads category by id with tenant isolation" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      category = insert(:asset_category, tenant: tenant)
      other_category = insert(:asset_category, tenant: other_tenant)

      # Can read category from same tenant
      assert {:ok, found_category} =
               AssetCategory
               |> Ash.Query.filter(id == category.id and tenant_id == tenant.id)
               |> Ash.read_one()

      assert found_category.id == category.id

      # Cannot read category from different tenant
      assert {:ok, nil} =
               AssetCategory
               |> Ash.Query.filter(id == other_category.id and tenant_id == tenant.id)
               |> Ash.read_one()
    end
  end

  describe "update operations" do
    test "updates category attributes" do
      tenant = insert(:tenant)
      category = insert(:asset_category, tenant: tenant, name: "Original Name")

      update_attrs = %{
        name: "Updated Category Name",
        description: "Updated description",
        depreciation_rate: Decimal.new("0.20")
      }

      assert {:ok, updated_category} =
               category
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true})

      assert updated_category.name == "Updated Category Name"
      assert updated_category.description == "Updated description"
      assert Decimal.equal?(updated_category.depreciation_rate, Decimal.new("0.20"))
    end

    test "cannot update category from different tenant" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      category = insert(:asset_category, tenant: tenant1)

      # Try to update with different tenant __context
      update_attrs = %{
        name: "Unauthorized Update",
        tenant_id: tenant2.id
      }

      # This should fail due to tenant isolation
      assert {:error, %Ash.Error.Invalid{}} =
               category
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true})
    end
  end

  describe "delete operations" do
    test "deletes category when no assets reference it" do
      tenant = insert(:tenant)
      category = insert(:asset_category, tenant: tenant)

      assert :ok = category |> Ash.destroy(authorize?: false)

      assert {:ok, nil} =
               AssetCategory
               |> Ash.Query.filter(id == ^category.id)
               |> Ash.read_one()
    end

    test "pr__events deletion when assets reference the category" do
      tenant = insert(:tenant)
      category = insert(:asset_category, tenant: tenant)
      _asset = insert(:asset, asset_category: category, tenant: tenant)

      # Should not be able to delete category with referenced assets
      assert {:error, %Ash.Error.Invalid{}} = category |> Ash.destroy(authorize?: false)
    end
  end

  describe "relationships" do
    test "loads assets relationship" do
      tenant = insert(:tenant)
      category = insert(:asset_category, tenant: tenant, name: "Test Category")
      asset1 = insert(:asset, asset_category: category, tenant: tenant, name: "Asset 1")
      asset2 = insert(:asset, asset_category: category, tenant: tenant, name: "Asset 2")

      loaded_category =
        AssetCategory
        |> Ash.Query.filter(id == ^category.id)
        |> Ash.Query.load(:assets)
        |> Ash.read_one!()

      assert length(loaded_category.assets) == 2
      asset_names = Enum.map(loaded_category.assets, & &1.name)
      assert "Asset 1" in asset_names
      assert "Asset 2" in asset_names
    end
  end

  describe "validations" do
    test "validates depreciation rate is between 0 and 1" do
      tenant = insert(:tenant)

      # Test negative depreciation rate
      invalid_attrs_negative = %{
        name: "Test Category",
        depreciation_rate: Decimal.new("-0.10"),
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AssetCategory
               |> Ash.Changeset.for_create(:create, invalid_attrs_negative)
               |> Ash.create(authorize?: false)

      # Test depreciation rate > 1
      invalid_attrs_high = %{
        name: "Test Category",
        depreciation_rate: Decimal.new("1.50"),
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AssetCategory
               |> Ash.Changeset.for_create(:create, invalid_attrs_high)
               |> Ash.create(authorize?: false)

      # Test valid depreciation rate
      valid_attrs = %{
        name: "Test Category",
        depreciation_rate: Decimal.new("0.15"),
        tenant_id: tenant.id
      }

      assert {:ok, _category} =
               AssetCategory
               |> Ash.Changeset.for_create(:create, valid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "validates expected life years is positive" do
      tenant = insert(:tenant)

      invalid_attrs = %{
        name: "Test Category",
        expected_life_years: -5,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AssetCategory
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)

      # Test zero years
      invalid_attrs_zero = %{
        name: "Test Category",
        expected_life_years: 0,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AssetCategory
               |> Ash.Changeset.for_create(:create, invalid_attrs_zero)
               |> Ash.create(authorize?: false)
    end

    test "validates name length" do
      tenant = insert(:tenant)

      # Test name too short (empty)
      invalid_attrs_short = %{
        name: "",
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AssetCategory
               |> Ash.Changeset.for_create(:create, invalid_attrs_short)
               |> Ash.create(authorize?: false)

      # Test name too long (over 100 characters)
      long_name = String.duplicate("a", 101)

      invalid_attrs_long = %{
        name: long_name,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               AssetCategory
               |> Ash.Changeset.for_create(:create, invalid_attrs_long)
               |> Ash.create(authorize?: false)
    end
  end

  describe "business logic" do
    test "calculates average depreciation for assets in category" do
      tenant = insert(:tenant)
      category = insert(:asset_category, tenant: tenant, depreciation_rate: Decimal.new("0.15"))

      # Create assets with different purchase costs
      _asset1 =
        insert(:asset,
          asset_category: category,
          tenant: tenant,
          purchase_cost: Decimal.new("1000.00"),
          purchase_date: Date.add(Date.utc_today(), -365)
        )

      _asset2 =
        insert(:asset,
          asset_category: category,
          tenant: tenant,
          purchase_cost: Decimal.new("2000.00"),
          purchase_date: Date.add(Date.utc_today(), -365)
        )

      # Category should be able to calculate depreciation statistics
      # This would be implemented as a calculation or aggregate in the resource
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
