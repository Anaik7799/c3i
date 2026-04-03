defmodule Indrajaal.GuardTour.CheckpointScanTest do
  @moduledoc """
  TDG-compliant comprehensive test suite for Indrajaal.GuardTour.CheckpointScan.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation hardening
  - FPPS Validation: record_scan action and scan_method/scan_status validation verified

  ## STAMP Safety Integration
  - SC-COV-001: CheckpointScan creation critical path coverage
  - SC-COV-006: TDG compliance mandatory
  - SC-HOLON-001: State written to PostgreSQL via Ash (business data)

  ## Constitutional Verification
  - Psi0 Existence: Scan records persist after record_scan
  - Psi1 Regeneration: Scan state reconstructible from Ash resource
  - Psi3 Verification: scan_status always :successful after record_scan

  ## Founder's Directive Alignment
  - Omega0.1: Accurate checkpoint scanning provides audit trail for security compliance

  ## TPS 5-Level RCA Context
  - L1 Symptom: Checkpoint scans with missing guard or execution references
  - L5 Root Cause: Missing required field validation in record_scan action

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude | Sprint 54 comprehensive test generation |
  """

  use Indrajaal.DataCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.GuardTour.CheckpointScan
  alias Indrajaal.GuardTour.Checkpoint
  alias Indrajaal.GuardTour.TourExecution
  alias Indrajaal.GuardTour.TourRoute

  @moduletag :zenoh_nif

  @system_admin %{id: "system", is_system_admin: true}

  @valid_scan_methods [:nfc, :qr_code, :biometric, :manual, :gps]

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp random_uuid, do: Ash.UUID.generate()

  defp create_route(tenant_id) do
    {:ok, route} =
      Ash.create(
        TourRoute,
        %{
          name: "Route #{System.unique_integer([:positive])}",
          description: "Test patrol route",
          route_type: :regular,
          estimated_duration: 60,
          checkpoint_order: [],
          is_active: true,
          priority_level: :medium,
          tenant_id: tenant_id
        },
        authorize?: false,
        actor: @system_admin,
        tenant: tenant_id
      )

    route
  end

  defp create_checkpoint(tenant_id) do
    {:ok, checkpoint} =
      Ash.create(
        Checkpoint,
        %{
          name: "CP #{System.unique_integer([:positive])}",
          location_description: "Test location",
          checkpoint_type: :nfc,
          identifier_code: "NFC-#{System.unique_integer([:positive])}",
          is_mandatory: true,
          max_scan_time: 30,
          tenant_id: tenant_id
        },
        authorize?: false,
        actor: @system_admin,
        tenant: tenant_id
      )

    checkpoint
  end

  defp create_execution(tenant_id, route_id) do
    {:ok, execution} =
      Ash.create(
        TourExecution,
        %{
          scheduled_start: DateTime.utc_now(),
          route_id: route_id,
          tenant_id: tenant_id
        },
        authorize?: false,
        actor: @system_admin,
        tenant: tenant_id
      )

    execution
  end

  defp create_scan(attrs \\ %{}) do
    tenant = random_tenant()
    route = create_route(tenant.id)
    execution = create_execution(tenant.id, route.id)
    checkpoint = create_checkpoint(tenant.id)
    guard_id = random_uuid()

    {:ok, scan} =
      Ash.create(
        CheckpointScan,
        Map.merge(
          %{
            checkpoint_id: checkpoint.id,
            execution_id: execution.id,
            guard_id: guard_id,
            scan_method: :nfc,
            tenant_id: tenant.id
          },
          attrs
        ),
        action: :record_scan,
        authorize?: false,
        actor: @system_admin,
        tenant: tenant.id
      )

    {scan, tenant}
  end

  # ---------------------------------------------------------------------------
  # Module existence
  # ---------------------------------------------------------------------------

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(CheckpointScan)
    end

    test "domain is GuardTour" do
      assert Ash.Resource.Info.domain(CheckpointScan) == Indrajaal.GuardTour
    end
  end

  # ---------------------------------------------------------------------------
  # Ash resource introspection
  # ---------------------------------------------------------------------------

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(CheckpointScan)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has record_scan action" do
      actions = Ash.Resource.Info.actions(CheckpointScan)
      action_names = Enum.map(actions, & &1.name)
      assert :record_scan in action_names
    end

    test "record_scan is a create action" do
      actions = Ash.Resource.Info.actions(CheckpointScan)
      action = Enum.find(actions, &(&1.name == :record_scan))
      assert action.type == :create
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(CheckpointScan)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :scanned_at in attr_names
      assert :scan_method in attr_names
      assert :scan_status in attr_names
      assert :latitude in attr_names
      assert :longitude in attr_names
      assert :notes in attr_names
      assert :scan_duration in attr_names
      assert :device_info in attr_names
    end

    test "resource has expected relationships" do
      rels = Ash.Resource.Info.relationships(CheckpointScan)
      rel_names = Enum.map(rels, & &1.name)
      assert :execution in rel_names
      assert :checkpoint in rel_names
      assert :guard in rel_names
    end
  end

  # ---------------------------------------------------------------------------
  # record_scan create action
  # ---------------------------------------------------------------------------

  describe "record_scan/1" do
    test "creates scan with scan_status :successful" do
      {scan, _tenant} = create_scan()
      assert scan.scan_status == :successful
    end

    test "creates scan with scanned_at set" do
      {scan, _tenant} = create_scan()
      assert %DateTime{} = scan.scanned_at
    end

    test "creates scan with provided scan_method :nfc" do
      {scan, _tenant} = create_scan(%{scan_method: :nfc})
      assert scan.scan_method == :nfc
    end

    test "creates scan with provided scan_method :qr_code" do
      {scan, _tenant} = create_scan(%{scan_method: :qr_code})
      assert scan.scan_method == :qr_code
    end

    test "creates scan with provided scan_method :biometric" do
      {scan, _tenant} = create_scan(%{scan_method: :biometric})
      assert scan.scan_method == :biometric
    end

    test "creates scan with provided scan_method :manual" do
      {scan, _tenant} = create_scan(%{scan_method: :manual})
      assert scan.scan_method == :manual
    end

    test "creates scan with provided scan_method :gps" do
      {scan, _tenant} = create_scan(%{scan_method: :gps})
      assert scan.scan_method == :gps
    end

    test "creates scan with default device_info as empty map" do
      {scan, _tenant} = create_scan()
      assert scan.device_info == %{}
    end

    test "record_scan requires checkpoint_id" do
      tenant = random_tenant()
      route = create_route(tenant.id)
      execution = create_execution(tenant.id, route.id)
      guard_id = random_uuid()

      result =
        Ash.create(
          CheckpointScan,
          %{
            execution_id: execution.id,
            guard_id: guard_id,
            scan_method: :nfc,
            tenant_id: tenant.id
          },
          action: :record_scan,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert {:error, _} = result
    end

    test "record_scan requires execution_id" do
      tenant = random_tenant()
      checkpoint = create_checkpoint(tenant.id)
      guard_id = random_uuid()

      result =
        Ash.create(
          CheckpointScan,
          %{
            checkpoint_id: checkpoint.id,
            guard_id: guard_id,
            scan_method: :nfc,
            tenant_id: tenant.id
          },
          action: :record_scan,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert {:error, _} = result
    end

    test "record_scan requires guard_id" do
      tenant = random_tenant()
      route = create_route(tenant.id)
      execution = create_execution(tenant.id, route.id)
      checkpoint = create_checkpoint(tenant.id)

      result =
        Ash.create(
          CheckpointScan,
          %{
            checkpoint_id: checkpoint.id,
            execution_id: execution.id,
            scan_method: :nfc,
            tenant_id: tenant.id
          },
          action: :record_scan,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert {:error, _} = result
    end

    test "record_scan requires scan_method" do
      tenant = random_tenant()
      route = create_route(tenant.id)
      execution = create_execution(tenant.id, route.id)
      checkpoint = create_checkpoint(tenant.id)
      guard_id = random_uuid()

      result =
        Ash.create(
          CheckpointScan,
          %{
            checkpoint_id: checkpoint.id,
            execution_id: execution.id,
            guard_id: guard_id,
            tenant_id: tenant.id
          },
          action: :record_scan,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert {:error, _} = result
    end

    test "accepts optional latitude and longitude" do
      tenant = random_tenant()
      route = create_route(tenant.id)
      execution = create_execution(tenant.id, route.id)
      checkpoint = create_checkpoint(tenant.id)
      guard_id = random_uuid()

      {:ok, scan} =
        Ash.create(
          CheckpointScan,
          %{
            checkpoint_id: checkpoint.id,
            execution_id: execution.id,
            guard_id: guard_id,
            scan_method: :gps,
            latitude: Decimal.new("40.7128"),
            longitude: Decimal.new("-74.0060"),
            tenant_id: tenant.id
          },
          action: :record_scan,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert Decimal.equal?(scan.latitude, Decimal.new("40.7128"))
      assert Decimal.equal?(scan.longitude, Decimal.new("-74.0060"))
    end

    test "scan is persisted with an id" do
      {scan, _tenant} = create_scan()
      assert is_binary(scan.id)
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi3)" do
    test "Psi0 existence: scan persists after record_scan" do
      {scan, tenant} = create_scan()

      fetched =
        Ash.get!(CheckpointScan, scan.id,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert fetched.id == scan.id
    end

    test "Psi1 regeneration: scan fully reconstructible by id" do
      {scan, tenant} = create_scan()

      reconstructed =
        Ash.get!(CheckpointScan, scan.id,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert reconstructed.scan_status == :successful
      assert reconstructed.checkpoint_id == scan.checkpoint_id
      assert reconstructed.execution_id == scan.execution_id
    end

    test "Psi3 verification: scan_status is always :successful after record_scan (SIL-6)" do
      {scan, _tenant} = create_scan()
      assert scan.scan_status == :successful
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests (EP-GEN-014: PC. prefix)
  # ---------------------------------------------------------------------------

  test "record_scan always produces scan_status :successful" do
    forall _x <- PC.integer() do
      {scan, _tenant} = create_scan()
      scan.scan_status == :successful
    end
  end

  test "all valid scan methods accepted by record_scan" do
    forall method <- PC.elements(@valid_scan_methods) do
      {scan, _tenant} = create_scan(%{scan_method: method})
      scan.scan_method == method
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties (EP-GEN-014: SD. prefix)
  # ---------------------------------------------------------------------------

  test "record_scan always sets scanned_at" do
    ExUnitProperties.check all(
                             _x <- SD.integer(),
                             max_runs: 3
                           ) do
      {scan, _tenant} = create_scan()
      assert %DateTime{} = scan.scanned_at
    end
  end
end
