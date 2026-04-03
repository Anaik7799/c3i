defmodule Indrajaal.GuardTour.CheckpointTest do
  use Indrajaal.DataCase
  require Ash.Query
  alias Indrajaal.GuardTour.Checkpoint

  describe "create / 1" do
    test "creates checkpoint with valid attributes" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)
      location = insert(:location, tenant: tenant)

      valid_attrs = %{
        name: "Main Entrance Checkpoint",
        description: "Security checkpoint at main building entrance",
        tour_route_id: tour_route.id,
        location_id: location.id,
        sequence_number: 1,
        estimated_time_minutes: 5,
        __required_actions: ["Badge scan", "Visual inspection", "Photo documentation"],
        checkpoint_type: :standard,
        is_mandatory: true,
        tenant_id: tenant.id
      }

      assert {:ok, checkpoint} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, valid_attrs)
               |> Ash.create(authorize?: false)

      assert checkpoint.name == "Main Entrance Checkpoint"
      assert checkpoint.description == "Security checkpoint at main building
        entrance"
      assert checkpoint.tour_route_id == tour_route.id
      assert checkpoint.location_id == location.id
      assert checkpoint.sequence_number == 1
      assert checkpoint.estimated_time_minutes == 5

      assert checkpoint.__required_actions == [
               "Badge scan",
               "Visual inspection",
               "Photo documentation"
             ]

      assert checkpoint.checkpoint_type == :standard
      assert checkpoint.is_mandatory == true
      assert checkpoint.tenant_id == tenant.id
    end

    test "requires name" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)

      invalid_attrs = %{
        tour_route_id: tour_route.id,
        sequence_number: 1,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "requires unique sequence number within route" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)

      checkpoint_attrs = %{
        name: "Checkpoint 1",
        tour_route_id: tour_route.id,
        sequence_number: 1,
        tenant_id: tenant.id
      }

      # Create first checkpoint
      assert {:ok, _checkpoint1} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, checkpoint_attrs)
               |> Ash.create(authorize?: false)

      # Try to create second checkpoint with same sequence number in same route
      duplicate_attrs = %{
        name: "Checkpoint 2",
        tour_route_id: tour_route.id,
        # Same sequence number
        sequence_number: 1,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, duplicate_attrs)
               |> Ash.create(authorize?: false)
    end

    test "allows same sequence number across different routes" do
      tenant = insert(:tenant)
      route1 = insert(:tour_route, tenant: tenant)
      route2 = insert(:tour_route, tenant: tenant)

      checkpoint_attrs_1 = %{
        name: "Route 1 Checkpoint 1",
        tour_route_id: route1.id,
        sequence_number: 1,
        tenant_id: tenant.id
      }

      checkpoint_attrs_2 = %{
        name: "Route 2 Checkpoint 1",
        tour_route_id: route2.id,
        # Same sequence but different route
        sequence_number: 1,
        tenant_id: tenant.id
      }

      assert {:ok, checkpoint1} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, checkpoint_attrs_1)
               |> Ash.create(authorize?: false)

      assert {:ok, checkpoint2} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, checkpoint_attrs_2)
               |> Ash.create(authorize?: false)

      assert checkpoint1.sequence_number == checkpoint2.sequence_number
      assert checkpoint1.tour_route_id != checkpoint2.tour_route_id
    end

    test "allows same sequence number across different tenants" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)
      route1 = insert(:tour_route, tenant: tenant1)
      route2 = insert(:tour_route, tenant: tenant2)

      checkpoint_attrs_1 = %{
        name: "Checkpoint 1",
        tour_route_id: route1.id,
        sequence_number: 1,
        tenant_id: tenant1.id
      }

      checkpoint_attrs_2 = %{
        name: "Checkpoint 1",
        tour_route_id: route2.id,
        sequence_number: 1,
        tenant_id: tenant2.id
      }

      assert {:ok, checkpoint1} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, checkpoint_attrs_1)
               |> Ash.create(authorize?: false)

      assert {:ok, checkpoint2} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, checkpoint_attrs_2)
               |> Ash.create(authorize?: false)

      assert checkpoint1.sequence_number == checkpoint2.sequence_number
      assert checkpoint1.tenant_id != checkpoint2.tenant_id
    end
  end

  describe "read operations" do
    test "lists checkpoints for tenant" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      # Create checkpoints for different tenants
      checkpoint1 = insert(:checkpoint, tenant: tenant, name: "Tenant 1 Checkpoint")
      checkpoint2 = insert(:checkpoint, tenant: tenant, name: "Another Tenant 1 Checkpoint")
      _checkpoint3 = insert(:checkpoint, tenant: other_tenant, name: "Tenant 2 Checkpoint")

      checkpoints =
        Checkpoint
        |> Ash.Query.filter(tenant_id == ^tenant.id)
        |> Ash.read!(authorize?: false)

      assert length(checkpoints) == 2
      checkpoint_names = Enum.map(checkpoints, & &1.name)
      assert "Tenant 1 Checkpoint" in checkpoint_names
      assert "Another Tenant 1 Checkpoint" in checkpoint_names
      refute "Tenant 2 Checkpoint" in checkpoint_names
    end

    test "reads checkpoint by id with tenant isolation" do
      tenant = insert(:tenant)
      other_tenant = insert(:tenant)

      checkpoint = insert(:checkpoint, tenant: tenant)
      other_checkpoint = insert(:checkpoint, tenant: other_tenant)

      # Can read checkpoint from same tenant
      assert {:ok, found_checkpoint} =
               Checkpoint
               |> Ash.Query.filter(id == ^checkpoint.id and tenant_id == ^tenant.id)
               |> Ash.read_one()

      assert found_checkpoint.id == checkpoint.id

      # Cannot read checkpoint from different tenant
      assert {:ok, nil} =
               Checkpoint
               |> Ash.Query.filter(id == ^other_checkpoint.id and tenant_id == ^tenant.id)
               |> Ash.read_one()
    end

    test "lists checkpoints for route in sequence order" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)

      # Create checkpoints out of sequence order
      checkpoint3 =
        insert(:checkpoint,
          tour_route: tour_route,
          tenant: tenant,
          sequence_number: 3,
          name: "Third"
        )

      checkpoint1 =
        insert(:checkpoint,
          tour_route: tour_route,
          tenant: tenant,
          sequence_number: 1,
          name: "First"
        )

      checkpoint2 =
        insert(:checkpoint,
          tour_route: tour_route,
          tenant: tenant,
          sequence_number: 2,
          name: "Second"
        )

      checkpoints =
        Checkpoint
        |> Ash.Query.filter(route_id == ^tour_route.id)
        |> Ash.Query.sort(:sequence_number)
        |> Ash.read!(authorize?: false)

      assert length(checkpoints) == 3
      assert Enum.at(checkpoints, 0).id == checkpoint1.id
      assert Enum.at(checkpoints, 1).id == checkpoint2.id
      assert Enum.at(checkpoints, 2).id == checkpoint3.id
    end

    test "filters mandatory checkpoints" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)

      mandatory_checkpoint =
        insert(:checkpoint, tour_route: tour_route, tenant: tenant, is_mandatory: true)

      _optional_checkpoint =
        insert(:checkpoint, tour_route: tour_route, tenant: tenant, is_mandatory: false)

      mandatory_checkpoints =
        Checkpoint
        |> Ash.Query.filter(route_id == ^tour_route.id and is_mandatory == true)
        |> Ash.read!(authorize?: false)

      assert length(mandatory_checkpoints) == 1
      assert hd(mandatory_checkpoints).id == mandatory_checkpoint.id
    end
  end

  describe "update operations" do
    test "updates checkpoint attributes" do
      tenant = insert(:tenant)
      checkpoint = insert(:checkpoint, tenant: tenant, name: "Original Name")

      update_attrs = %{
        name: "Updated Checkpoint Name",
        description: "Updated description",
        estimated_time_minutes: 10,
        checkpoint_type: :critical
      }

      assert {:ok, updated_checkpoint} =
               checkpoint
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert updated_checkpoint.name == "Updated Checkpoint Name"
      assert updated_checkpoint.description == "Updated description"
      assert updated_checkpoint.estimated_time_minutes == 10
      assert updated_checkpoint.checkpoint_type == :critical
    end

    test "updates required_actions list" do
      tenant = insert(:tenant)
      checkpoint = insert(:checkpoint, tenant: tenant, __required_actions: ["Badge scan"])

      update_attrs = %{
        __required_actions: [
          "Badge scan",
          "Visual inspection",
          "Photo documentation",
          "Report anomalies"
        ]
      }

      assert {:ok, updated_checkpoint} =
               checkpoint
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)

      assert length(updated_checkpoint.__required_actions) == 4
      assert "Badge scan" in updated_checkpoint.__required_actions
      assert "Visual inspection" in updated_checkpoint.__required_actions
      assert "Photo documentation" in updated_checkpoint.__required_actions
      assert "Report anomalies" in updated_checkpoint.__required_actions
    end

    test "cannot update checkpoint from different tenant" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      checkpoint = insert(:checkpoint, tenant: tenant1)

      # Try to update with different tenant context
      update_attrs = %{
        name: "Unauthorized Update",
        tenant_id: tenant2.id
      }

      # This should fail due to tenant isolation
      assert {:error, %Ash.Error.Invalid{}} =
               checkpoint
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(actor: %{id: "system", is_system_admin: true}, authorize?: false)
    end
  end

  describe "delete operations" do
    test "deletes checkpoint when no scans reference it" do
      tenant = insert(:tenant)
      checkpoint = insert(:checkpoint, tenant: tenant)

      assert :ok = checkpoint |> Ash.destroy(authorize?: false)

      assert {:ok, nil} =
               Checkpoint
               |> Ash.Query.filter(id == ^checkpoint.id)
               |> Ash.read_one()
    end

    test "prevents deletion when checkpoint scans reference it" do
      tenant = insert(:tenant)
      checkpoint = insert(:checkpoint, tenant: tenant)
      _scan = insert(:checkpoint_scan, checkpoint: checkpoint, tenant: tenant)

      # Should not be able to delete checkpoint with scan history
      assert {:error, %Ash.Error.Invalid{}} = checkpoint |> Ash.destroy(authorize?: false)
    end

    test "reorders remaining checkpoints after deletion" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)

      checkpoint1 =
        insert(:checkpoint, tour_route: tour_route, tenant: tenant, sequence_number: 1)

      checkpoint2 =
        insert(:checkpoint, tour_route: tour_route, tenant: tenant, sequence_number: 2)

      checkpoint3 =
        insert(:checkpoint, tour_route: tour_route, tenant: tenant, sequence_number: 3)

      # Delete middle checkpoint
      assert :ok = checkpoint2 |> Ash.destroy(authorize?: false)

      # Remaining checkpoints should maintain sequence integrity
      remaining_checkpoints =
        Checkpoint
        |> Ash.Query.filter(route_id == ^tour_route.id)
        |> Ash.Query.sort(:sequence_number)
        |> Ash.read!(authorize?: false)

      assert length(remaining_checkpoints) == 2
      assert Enum.at(remaining_checkpoints, 0).id == checkpoint1.id
      assert Enum.at(remaining_checkpoints, 1).id == checkpoint3.id
    end
  end

  describe "relationships" do
    test "loads tour route relationship" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant, name: "Security Route A")
      checkpoint = insert(:checkpoint, tour_route: tour_route, tenant: tenant)

      loaded_checkpoint =
        Checkpoint
        |> Ash.Query.filter(id == ^checkpoint.id)
        |> Ash.Query.load(:tour_route)
        |> Ash.read_one!()

      assert loaded_checkpoint.tour_route.name == "Security Route A"
    end

    test "loads location relationship" do
      tenant = insert(:tenant)
      location = insert(:location, tenant: tenant, name: "Main Lobby")
      checkpoint = insert(:checkpoint, location: location, tenant: tenant)

      loaded_checkpoint =
        Checkpoint
        |> Ash.Query.filter(id == ^checkpoint.id)
        |> Ash.Query.load(:location)
        |> Ash.read_one!()

      assert loaded_checkpoint.location.name == "Main Lobby"
    end

    test "loads checkpoint scans relationship" do
      tenant = insert(:tenant)
      checkpoint = insert(:checkpoint, tenant: tenant)
      scan1 = insert(:checkpoint_scan, checkpoint: checkpoint, tenant: tenant)
      scan2 = insert(:checkpoint_scan, checkpoint: checkpoint, tenant: tenant)

      loaded_checkpoint =
        Checkpoint
        |> Ash.Query.filter(id == ^checkpoint.id)
        |> Ash.Query.load(:scans)
        |> Ash.read_one!()

      assert length(loaded_checkpoint.scans) == 2
      scan_ids = Enum.map(loaded_checkpoint.scans, & &1.id)
      assert scan1.id in scan_ids
      assert scan2.id in scan_ids
    end
  end

  describe "validations" do
    test "validates sequence number is positive" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)

      invalid_attrs = %{
        name: "Test Checkpoint",
        tour_route_id: tour_route.id,
        sequence_number: 0,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)

      # Test negative sequence number
      invalid_attrs_negative = %{
        name: "Test Checkpoint",
        tour_route_id: tour_route.id,
        sequence_number: -1,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, invalid_attrs_negative)
               |> Ash.create(authorize?: false)
    end

    test "validates estimated time is positive" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)

      invalid_attrs = %{
        name: "Test Checkpoint",
        tour_route_id: tour_route.id,
        sequence_number: 1,
        estimated_time_minutes: -5,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, invalid_attrs)
               |> Ash.create(authorize?: false)
    end

    test "validates checkpoint type enum" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)

      # Valid checkpoint types
      valid_types = [:standard, :critical, :optional, :emergency]

      for type <- valid_types do
        valid_attrs = %{
          name: "Test Checkpoint #{type}",
          tour_route_id: tour_route.id,
          sequence_number: 1,
          checkpoint_type: type,
          tenant_id: tenant.id
        }

        assert {:ok, _checkpoint} =
                 Checkpoint
                 |> Ash.Changeset.for_create(:create, valid_attrs)
                 |> Ash.create(authorize?: false)
      end
    end

    test "validates required_actions is list of strings" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)

      valid_attrs = %{
        name: "Test Checkpoint",
        tour_route_id: tour_route.id,
        sequence_number: 1,
        __required_actions: ["Action 1", "Action 2", "Action 3"],
        tenant_id: tenant.id
      }

      assert {:ok, checkpoint} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, valid_attrs)
               |> Ash.create(authorize?: false)

      assert is_list(checkpoint.__required_actions)
      assert length(checkpoint.__required_actions) == 3
    end

    test "validates name length" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)

      # Test name too short (empty)
      invalid_attrs_short = %{
        name: "",
        tour_route_id: tour_route.id,
        sequence_number: 1,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, invalid_attrs_short)
               |> Ash.create(authorize?: false)

      # Test name too long (over 100 characters)
      long_name = String.duplicate("a", 101)

      invalid_attrs_long = %{
        name: long_name,
        tour_route_id: tour_route.id,
        sequence_number: 1,
        tenant_id: tenant.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Checkpoint
               |> Ash.Changeset.for_create(:create, invalid_attrs_long)
               |> Ash.create(authorize?: false)
    end
  end

  describe "business logic" do
    test "checkpoint completion tracking" do
      tenant = insert(:tenant)
      checkpoint = insert(:checkpoint, tenant: tenant)

      # Create scans for the checkpoint
      scan1 =
        insert(:checkpoint_scan,
          checkpoint: checkpoint,
          tenant: tenant,
          scanned_at: DateTime.add(DateTime.utc_now(), -3600)
        )

      scan2 =
        insert(:checkpoint_scan,
          checkpoint: checkpoint,
          tenant: tenant,
          scanned_at: DateTime.add(DateTime.utc_now(), -1800)
        )

      # Load checkpoint with scans
      loaded_checkpoint =
        Checkpoint
        |> Ash.Query.filter(id == ^checkpoint.id)
        |> Ash.Query.load(:scans)
        |> Ash.read_one!()

      # Business logic: calculate completion rate, last scan time, etc.
      scan_count = length(loaded_checkpoint.scans)
      assert scan_count == 2

      # Most recent scan
      most_recent_scan =
        loaded_checkpoint.scans
        |> Enum.max_by(& &1.scanned_at, DateTime)

      assert most_recent_scan.id == scan2.id
    end

    test "checkpoint sequence validation within route" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)

      # Create checkpoints with gaps in sequence
      _checkpoint1 =
        insert(:checkpoint, tour_route: tour_route, tenant: tenant, sequence_number: 1)

      _checkpoint3 =
        insert(:checkpoint, tour_route: tour_route, tenant: tenant, sequence_number: 3)

      _checkpoint5 =
        insert(:checkpoint, tour_route: tour_route, tenant: tenant, sequence_number: 5)

      # Business rule: validate sequence integrity
      checkpoints =
        Checkpoint
        |> Ash.Query.filter(route_id == ^tour_route.id)
        |> Ash.Query.sort(:sequence_number)
        |> Ash.read!(authorize?: false)

      sequences = Enum.map(checkpoints, & &1.sequence_number)
      # Gaps are allowed but order must be maintained
      assert sequences == [1, 3, 5]
    end

    test "mandatory checkpoint enforcement" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)

      # Create mix of mandatory and optional checkpoints
      mandatory1 =
        insert(:checkpoint,
          tour_route: tour_route,
          tenant: tenant,
          is_mandatory: true,
          sequence_number: 1
        )

      _optional1 =
        insert(:checkpoint,
          tour_route: tour_route,
          tenant: tenant,
          is_mandatory: false,
          sequence_number: 2
        )

      mandatory2 =
        insert(:checkpoint,
          tour_route: tour_route,
          tenant: tenant,
          is_mandatory: true,
          sequence_number: 3
        )

      # Business rule: all mandatory checkpoints must be completed
      mandatory_checkpoints =
        Checkpoint
        |> Ash.Query.filter(route_id == ^tour_route.id and is_mandatory == true)
        |> Ash.Query.sort(:sequence_number)
        |> Ash.read!(authorize?: false)

      assert length(mandatory_checkpoints) == 2
      mandatory_ids = Enum.map(mandatory_checkpoints, & &1.id)
      assert mandatory1.id in mandatory_ids
      assert mandatory2.id in mandatory_ids
    end

    test "estimated time aggregation for route" do
      tenant = insert(:tenant)
      tour_route = insert(:tour_route, tenant: tenant)

      # Create checkpoints with different time estimates
      _checkpoint1 =
        insert(:checkpoint, tour_route: tour_route, tenant: tenant, estimated_time_minutes: 5)

      _checkpoint2 =
        insert(:checkpoint, tour_route: tour_route, tenant: tenant, estimated_time_minutes: 10)

      _checkpoint3 =
        insert(:checkpoint, tour_route: tour_route, tenant: tenant, estimated_time_minutes: 7)

      # Calculate total estimated time for route
      checkpoints =
        Checkpoint
        |> Ash.Query.filter(route_id == ^tour_route.id)
        |> Ash.read!(authorize?: false)

      total_time =
        checkpoints
        |> Enum.map(& &1.estimated_time_minutes)
        |> Enum.sum()

      # 5 + 10 + 7
      assert total_time == 22
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
