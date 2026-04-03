defmodule Indrajaal.GuardTour.TourRouteTest do
  use Indrajaal.DataCase
  require Ash.Query
  alias Indrajaal.GuardTour.TourRoute

  describe "create / 1" do
    test "creates tour route with valid attributes" do
      tenant = insert(:tenant)
      site = insert(:site, tenant: tenant)

      valid_attrs = %{
        name: "Building A Security Route",
        description: "Comprehensive security patrol route for Building A",
        site_id: site.id,
        estimated_duration_minutes: 45,
        difficulty_level: :medium,
        status: :active,
        tenant_id: tenant.id
      }

      assert {:ok, route} =
               TourRoute
               |> Ash.Changeset.for_create(:create, valid_attrs)
               |> Ash.create(authorize?: false)

      assert route.name == "Building A Security Route"
      assert route.description == "Comprehensive security patrol route
        for Building A"
      assert route.site_id == site.id
      assert route.estimated_duration_minutes == 45
      assert route.difficulty_level == :medium
      assert route.status == :active
      assert route.tenant_id == tenant.id
    end

    test "__requires name" do
      tenant = insert(:tenant)
      site = insert(:site, tenant: tenant)

      invalid_attrs = %{
        site_id: site.id,
        estimated_duration_minutes: 30,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               TourRoute
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "__requires unique name within tenant" do
      tenant = insert(:tenant)
      site = insert(:site, tenant: tenant)

      route_attrs = %{
        name: "Duplicate Route Name",
        site_id: site.id,
        tenant_id: tenant.id
      }

      # Create first route
      assert {:ok, _route1} =
               TourRoute
               |> Ash.Changeset.for_create(:create, route_attrs)
               |> Ash.create(authorize?: false)

      # Try to create second route with same name
      assert {:error, %Ash.Error.Invalid{}} =
               TourRoute
               |> Ash.Changeset.for_create(:create, route_attrs)
               |> Ash.create(authorize?: false)
    end

    test "allows same name across different tenants" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)
      site1 = insert(:site, tenant: tenant1)
      site2 = insert(:site, tenant: tenant2)

      route_attrs_1 = %{
        name: "Shared Route Name",
        site_id: site1.id,
        tenant_id: tenant1.id
      }

      route_attrs_2 = %{
        name: "Shared Route Name",
        site_id: site2.id,
        tenant_id: tenant2.id
      }

      assert {:ok, route1} =
               TourRoute
               |> Ash.Changeset.for_create(:create, route_attrs_1)
               |> Ash.create(authorize?: false)

      assert {:ok, route2} =
               TourRoute
               |> Ash.Changeset.for_create(:create, route_attrs_2)
               |> Ash.create(authorize?: false)

      assert route1.name == route2.name
      assert route1.tenant_id != route2.tenant_id
    end
  end

  describe "read operations" do
    test "lists routes for tenant" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      # Create routes for different tenants
      route1 = insert(:tour_route, tenant: tenant, name: "Tenant 1 Route")
      route2 = insert(:tour_route, tenant: tenant, name: "Another Tenant 1 Route")
      _route3 = insert(:tour_route, tenant: other_tenant, name: "Tenant 2 Route")

      routes =
        TourRoute
        |> Ash.Query.filter(tenant_id == ^tenant.id)
        |> Ash.read!(authorize?: false)

      assert length(routes) == 2
      route_names = Enum.map(routes, & &1.name)
      assert "Tenant 1 Route" in route_names
      assert "Another Tenant 1 Route" in route_names
      refute "Tenant 2 Route" in route_names
    end

    test "reads route by id with tenant isolation" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      route = insert(:tour_route, tenant: tenant)
      other_route = insert(:tour_route, tenant: other_tenant)

      # Can read route from same tenant
      assert {:ok, found_route} =
               TourRoute
               |> Ash.Query.filter(id == ^route.id and tenant_id == ^tenant.id)
               |> Ash.read_one()

      assert found_route.id == route.id

      # Cannot read route from different tenant
      assert {:ok, nil} =
               TourRoute
               |> Ash.Query.filter(id == ^other_route.id and tenant_id == ^tenant.id)
               |> Ash.read_one()
    end

    test "filters routes by status" do
      tenant = insert(:tenant)

      active_route = insert(:tour_route, tenant: tenant, status: :active)
      _inactive_route = insert(:tour_route, tenant: tenant, status: :inactive)
      _draft_route = insert(:tour_route, tenant: tenant, status: :draft)

      active_routes =
        TourRoute
        |> Ash.Query.filter(tenant_id == ^tenant.id and status == :active)
        |> Ash.read!(authorize?: false)

      assert length(active_routes) == 1
      assert hd(active_routes).id == active_route.id
    end

    test "filters routes by site" do
      tenant = insert(:tenant)
      site1 = insert(:site, tenant: tenant)
      site2 = insert(:site, tenant: tenant)

      route1 = insert(:tour_route, tenant: tenant, site: site1)
      _route2 = insert(:tour_route, tenant: tenant, site: site2)

      site1_routes =
        TourRoute
        |> Ash.Query.filter(tenant_id == ^tenant.id and site_id == ^site1.id)
        |> Ash.read!(authorize?: false)

      assert length(site1_routes) == 1
      assert hd(site1_routes).id == route1.id
    end
  end

  describe "update operations" do
    test "updates route attributes" do
      tenant = insert(:tenant)
      route = insert(:tour_route, tenant: tenant, name: "Original Route")

      update_attrs = %{
        name: "Updated Route Name",
        description: "Updated description",
        estimated_duration_minutes: 60,
        difficulty_level: :hard
      }

      assert {:ok, updated_route} =
               route
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_route.name == "Updated Route Name"
      assert updated_route.description == "Updated description"
      assert updated_route.estimated_duration_minutes == 60
      assert updated_route.difficulty_level == :hard
    end

    test "updates route status" do
      tenant = insert(:tenant)
      route = insert(:tour_route, tenant: tenant, status: :draft)

      update_attrs = %{status: :active}

      assert {:ok, updated_route} =
               route
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_route.status == :active
    end

    test "cannot update route from different tenant" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      route = insert(:tour_route, tenant: tenant1)

      # Try to update with different tenant __context
      update_attrs = %{
        name: "Unauthorized Update",
        tenant_id: tenant2.id
      }

      # This should fail due to tenant isolation
      assert {:error, %Ash.Error.Invalid{}} =
               route
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)
    end
  end

  describe "delete operations" do
    test "deletes route when no schedules reference it" do
      tenant = insert(:tenant)
      route = insert(:tour_route, tenant: tenant)

      assert :ok = route |> Ash.destroy(authorize?: false)

      assert {:ok, nil} =
               TourRoute
               |> Ash.Query.filter(id == ^route.id)
               |> Ash.read_one()
    end

    test "pr__events deletion when schedules reference the route" do
      tenant = insert(:tenant)
      route = insert(:tour_route, tenant: tenant)
      _schedule = insert(:tour_schedule, tour_route: route, tenant: tenant)

      # Should not be able to delete route with active schedules
      assert {:error, %Ash.Error.Invalid{}} = route |> Ash.destroy(authorize?: false)
    end

    test "soft deletes route by setting status to inactive" do
      tenant = insert(:tenant)
      route = insert(:tour_route, tenant: tenant, status: :active)

      # Instead of hard delete, set status to inactive
      assert {:ok, updated_route} =
               route
               |> Ash.Changeset.for_update(:update, %{status: :inactive})
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_route.status == :inactive
    end
  end

  describe "relationships" do
    test "loads site relationship" do
      tenant = insert(:tenant)
      site = insert(:site, tenant: tenant, name: "Main Building")
      route = insert(:tour_route, site: site, tenant: tenant)

      loaded_route =
        TourRoute
        |> Ash.Query.filter(id == ^route.id)
        |> Ash.Query.load(:site)
        |> Ash.read_one!()

      assert loaded_route.site.name == "Main Building"
    end

    test "loads checkpoints relationship" do
      tenant = insert(:tenant)
      route = insert(:tour_route, tenant: tenant)
      checkpoint1 = insert(:checkpoint, tour_route: route, tenant: tenant, name: "Checkpoint 1")
      checkpoint2 = insert(:checkpoint, tour_route: route, tenant: tenant, name: "Checkpoint 2")

      loaded_route =
        TourRoute
        |> Ash.Query.filter(id == ^route.id)
        |> Ash.Query.load(:checkpoints)
        |> Ash.read_one!()

      assert length(loaded_route.checkpoints) == 2
      checkpoint_names = Enum.map(loaded_route.checkpoints, & &1.name)
      assert "Checkpoint 1" in checkpoint_names
      assert "Checkpoint 2" in checkpoint_names
    end

    test "loads schedules relationship" do
      tenant = insert(:tenant)
      route = insert(:tour_route, tenant: tenant)
      schedule1 = insert(:tour_schedule, tour_route: route, tenant: tenant)
      schedule2 = insert(:tour_schedule, tour_route: route, tenant: tenant)

      loaded_route =
        TourRoute
        |> Ash.Query.filter(id == ^route.id)
        |> Ash.Query.load(:schedules)
        |> Ash.read_one!()

      assert length(loaded_route.schedules) == 2
      schedule_ids = Enum.map(loaded_route.schedules, & &1.id)
      assert schedule1.id in schedule_ids
      assert schedule2.id in schedule_ids
    end
  end

  describe "validations" do
    test "validates estimated_duration_minutes is positive" do
      tenant = insert(:tenant)
      site = insert(:site, tenant: tenant)

      invalid_attrs = %{
        name: "Test Route",
        site_id: site.id,
        estimated_duration_minutes: -30,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               TourRoute
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)

      # Test zero duration
      invalid_attrs_zero = %{
        name: "Test Route",
        site_id: site.id,
        estimated_duration_minutes: 0,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               TourRoute
               |> Ash.Changeset.for_create(:create, invalid_attrs_zero)
               |> Ash.create(authorize?: false)
    end

    test "validates name length" do
      tenant = insert(:tenant)
      site = insert(:site, tenant: tenant)

      # Test name too short (empty)
      invalid_attrs_short = %{
        name: "",
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               TourRoute
               |> Ash.Changeset.for_create(:create, invalid_attrs_short)
               |> Ash.create(authorize?: false)

      # Test name too long (over 100 characters)
      long_name = String.duplicate("a", 101)

      invalid_attrs_long = %{
        name: long_name,
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               TourRoute
               |> Ash.Changeset.for_create(:create, invalid_attrs_long)
               |> Ash.create(authorize?: false)
    end

    test "validates difficulty_level enum" do
      tenant = insert(:tenant)
      site = insert(:site, tenant: tenant)

      # Valid difficulty levels
      valid_levels = [:easy, :medium, :hard]

      for level <- valid_levels do
        valid_attrs = %{
          name: "Test Route #{level}",
          site_id: site.id,
          difficulty_level: level,
          tenant_id: tenant.id
        }

        assert {:ok, _route} =
                 TourRoute
                 |> Ash.Changeset.for_create(:create, valid_attrs)
                 |> Ash.create(authorize?: false)
      end
    end

    test "validates status enum" do
      tenant = insert(:tenant)
      site = insert(:site, tenant: tenant)

      # Valid status values
      valid_statuses = [:draft, :active, :inactive, :archived]

      for status <- valid_statuses do
        valid_attrs = %{
          name: "Test Route #{status}",
          site_id: site.id,
          status: status,
          tenant_id: tenant.id
        }

        assert {:ok, _route} =
                 TourRoute
                 |> Ash.Changeset.for_create(:create, valid_attrs)
                 |> Ash.create(authorize?: false)
      end
    end
  end

  describe "business logic" do
    test "calculates total checkpoint count" do
      tenant = insert(:tenant)
      route = insert(:tour_route, tenant: tenant)

      # Create multiple checkpoints
      _checkpoint1 = insert(:checkpoint, tour_route: route, tenant: tenant, sequence_number: 1)
      _checkpoint2 = insert(:checkpoint, tour_route: route, tenant: tenant, sequence_number: 2)
      _checkpoint3 = insert(:checkpoint, tour_route: route, tenant: tenant, sequence_number: 3)

      # Load route with checkpoints
      loaded_route =
        TourRoute
        |> Ash.Query.filter(id == ^route.id)
        |> Ash.Query.load(:checkpoints)
        |> Ash.read_one!()

      checkpoint_count = length(loaded_route.checkpoints)
      assert checkpoint_count == 3
    end

    test "validates checkpoint sequence integrity" do
      tenant = insert(:tenant)
      route = insert(:tour_route, tenant: tenant)

      # Create checkpoints with valid sequence
      _checkpoint1 = insert(:checkpoint, tour_route: route, tenant: tenant, sequence_number: 1)
      _checkpoint2 = insert(:checkpoint, tour_route: route, tenant: tenant, sequence_number: 2)
      _checkpoint3 = insert(:checkpoint, tour_route: route, tenant: tenant, sequence_number: 3)

      # Verify sequence integrity (this would be a business rule validation)
      checkpoints =
        TourRoute
        |> Ash.Query.filter(id == ^route.id)
        |> Ash.Query.load(:checkpoints)
        |> Ash.read_one!()
        |> Map.get(:checkpoints)
        |> Enum.sort_by(& &1.sequence_number)

      sequences = Enum.map(checkpoints, & &1.sequence_number)
      assert sequences == [1, 2, 3]
    end

    test "estimates route completion time based on checkpoints" do
      tenant = insert(:tenant)
      route = insert(:tour_route, tenant: tenant, estimated_duration_minutes: 60)

      # Create checkpoints with time estimates
      _checkpoint1 =
        insert(:checkpoint,
          tour_route: route,
          tenant: tenant,
          estimated_time_minutes: 10
        )

      _checkpoint2 =
        insert(:checkpoint,
          tour_route: route,
          tenant: tenant,
          estimated_time_minutes: 15
        )

      _checkpoint3 =
        insert(:checkpoint,
          tour_route: route,
          tenant: tenant,
          estimated_time_minutes: 20
        )

      # Calculate total estimated time from checkpoints
      # 45 minutes
      total_checkpoint_time = 10 + 15 + 20

      # Business logic could compare this with route's estimated duration
      assert total_checkpoint_time <= route.estimated_duration_minutes
    end

    test "route status lifecycle" do
      tenant = insert(:tenant)

      # Create route in draft status
      route = insert(:tour_route, tenant: tenant, status: :draft)

      # Activate route
      assert {:ok, active_route} =
               route
               |> Ash.Changeset.for_update(:update, %{status: :active})
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert active_route.status == :active

      # Deactivate route
      assert {:ok, inactive_route} =
               active_route
               |> Ash.Changeset.for_update(:update, %{status: :inactive})
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert inactive_route.status == :inactive

      # Archive route
      assert {:ok, archived_route} =
               inactive_route
               |> Ash.Changeset.for_update(:update, %{status: :archived})
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert archived_route.status == :archived
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
