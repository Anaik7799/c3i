defmodule Indrajaal.Dispatch.VehicleTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Dispatch.Vehicle.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation hardening
  - FPPS Validation: Vehicle lifecycle actions verified across all state transitions

  ## STAMP Safety Integration
  - SC-COV-001: Critical vehicle state machine path coverage (RPN 80+)
  - SC-COV-006: TDG compliance mandatory
  - SC-HOLON-001: Vehicle state written to PostgreSQL via Ash (business data)

  ## Constitutional Verification
  - Psi0 Existence: Vehicle records persist across status transitions
  - Psi1 Regeneration: Vehicle state fully reconstructible from Ash resource
  - Psi3 Verification: Odometer and utilization invariants verifiable

  ## Founder's Directive Alignment
  - Omega0.1: Accurate vehicle tracking enables rapid security response

  ## TPS 5-Level RCA Context
  - L1 Symptom: Vehicles showing stale status or invalid odometer readings
  - L5 Root Cause: Missing validation boundary for status state machine and odometer monotonicity

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude | Sprint 54 W3 test generation |

  ## Notes
  - No dispatch vehicle factory exists — creates via Ash.create directly.
  - Requires tenant creation; uses system_admin actor (authorize?: false bypasses policies).
  - assign_to_team validates status in [:available, :out_of_service].
  - assign_to_officer validates status in [:available, :assigned].
  - activate validates active? == false; deactivate validates active? == true.
  - update_odometer validates new_reading >= current (monotonicity).
  - report_defect with :critical severity sets operational_status to :non_operational.
  - resolve_defect uses defect_index (0-based) into defects list.
  - track_assignment increments total_assignments by 1 and adds runtime_hours.
  """

  use Indrajaal.DataCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Dispatch.Vehicle

  @moduletag :zenoh_nif

  @system_admin %{id: "system", is_system_admin: true}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp unique_call_sign, do: "V-#{System.unique_integer([:positive])}"
  defp unique_plate, do: "PLT#{System.unique_integer([:positive])}"

  defp create_vehicle(attrs \\ %{}) do
    tenant = random_tenant()

    base = %{
      call_sign: unique_call_sign(),
      license_plate: unique_plate(),
      make: "Toyota",
      model: "Land Cruiser",
      year: 2022,
      vehicle_type: :patrol_car,
      max_occupancy: 2,
      odometer_km: 0.0,
      total_assignments: 0,
      total_distance_km: 0.0,
      total_runtime_hours: 0.0,
      active?: true,
      tenant_id: tenant.id
    }

    attrs_with_tenant = Map.put_new(attrs, :tenant_id, tenant.id)
    merged = Map.merge(base, attrs_with_tenant)

    {:ok, vehicle} =
      Ash.create(Vehicle, merged, action: :create, authorize?: false, actor: @system_admin)

    vehicle
  end

  # ---------------------------------------------------------------------------
  # create action
  # ---------------------------------------------------------------------------

  describe "create action" do
    test "creates a vehicle with default status :available" do
      vehicle = create_vehicle()
      assert vehicle.status == :available
    end

    test "creates vehicle with default operational_status :operational" do
      vehicle = create_vehicle()
      assert vehicle.operational_status == :operational
    end

    test "creates vehicle with default vehicle_type :patrol_car" do
      vehicle = create_vehicle()
      assert vehicle.vehicle_type == :patrol_car
    end

    test "creates vehicle with default active? true" do
      vehicle = create_vehicle()
      assert vehicle.active? == true
    end

    test "creates vehicle with default odometer_km 0.0" do
      vehicle = create_vehicle()
      assert vehicle.odometer_km == 0.0
    end

    test "creates vehicle with default max_occupancy 2" do
      vehicle = create_vehicle()
      assert vehicle.max_occupancy == 2
    end

    test "creates vehicle with default total_assignments 0" do
      vehicle = create_vehicle()
      assert vehicle.total_assignments == 0
    end

    test "creates vehicle with default defects []" do
      vehicle = create_vehicle()
      assert vehicle.defects == []
    end

    test "creates vehicle with default maintenance_alerts []" do
      vehicle = create_vehicle()
      assert vehicle.maintenance_alerts == []
    end

    test "creates vehicle with custom vehicle_type :suv" do
      vehicle = create_vehicle(%{vehicle_type: :suv})
      assert vehicle.vehicle_type == :suv
    end

    test "creates vehicle with custom vehicle_type :motorcycle" do
      vehicle = create_vehicle(%{vehicle_type: :motorcycle})
      assert vehicle.vehicle_type == :motorcycle
    end

    test "creates vehicle with custom vehicle_type :emergency_response" do
      vehicle = create_vehicle(%{vehicle_type: :emergency_response})
      assert vehicle.vehicle_type == :emergency_response
    end

    test "stores id and required fields" do
      vehicle = create_vehicle()
      assert vehicle.id
      assert vehicle.call_sign
      assert vehicle.license_plate
      assert vehicle.make == "Toyota"
      assert vehicle.model == "Land Cruiser"
      assert vehicle.year == 2022
    end

    test "rejects year below 1990" do
      tenant = random_tenant()

      result =
        Ash.create(
          Vehicle,
          %{
            call_sign: unique_call_sign(),
            license_plate: unique_plate(),
            make: "Ford",
            model: "Explorer",
            year: 1985,
            tenant_id: tenant.id
          },
          action: :create,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end

    test "rejects max_occupancy above 12" do
      tenant = random_tenant()

      result =
        Ash.create(
          Vehicle,
          %{
            call_sign: unique_call_sign(),
            license_plate: unique_plate(),
            make: "Bus",
            model: "Large",
            year: 2020,
            max_occupancy: 50,
            tenant_id: tenant.id
          },
          action: :create,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # update_status action
  # ---------------------------------------------------------------------------

  describe "update_status action" do
    test "transitions status to :in_use" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{status: :in_use},
          action: :update_status,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.status == :in_use
    end

    test "transitions status to :en_route" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{status: :en_route},
          action: :update_status,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.status == :en_route
    end

    test "transitions status to :out_of_service" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{status: :out_of_service},
          action: :update_status,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.status == :out_of_service
    end

    test "transitions status to :maintenance" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{status: :maintenance},
          action: :update_status,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.status == :maintenance
    end

    test "update_status also accepts operational_status" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{status: :in_use, operational_status: :limited},
          action: :update_status,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.operational_status == :limited
    end
  end

  # ---------------------------------------------------------------------------
  # update_location action
  # ---------------------------------------------------------------------------

  describe "update_location action" do
    test "stores latitude, longitude in current_location map" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{latitude: 19.076, longitude: 72.877},
          action: :update_location,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.current_location["latitude"] == 19.076
      assert updated.current_location["longitude"] == 72.877
    end

    test "stores heading and speed in current_location" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{latitude: 28.6139, longitude: 77.209, heading: 90.0, speed_kmh: 60.0},
          action: :update_location,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.current_location["heading"] == 90.0
      assert updated.current_location["speed"] == 60.0
    end

    test "sets last_location_update to a datetime" do
      vehicle = create_vehicle()
      before_update = DateTime.utc_now()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{latitude: 12.9716, longitude: 77.5946},
          action: :update_location,
          authorize?: false,
          actor: @system_admin
        )

      assert not is_nil(updated.last_location_update)
      assert DateTime.compare(updated.last_location_update, before_update) != :lt
    end

    test "rejects latitude outside -90..90" do
      vehicle = create_vehicle()

      result =
        Ash.update(
          vehicle,
          %{latitude: 95.0, longitude: 77.0},
          action: :update_location,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end

    test "rejects longitude outside -180..180" do
      vehicle = create_vehicle()

      result =
        Ash.update(
          vehicle,
          %{latitude: 19.0, longitude: 200.0},
          action: :update_location,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # update_odometer action
  # ---------------------------------------------------------------------------

  describe "update_odometer action" do
    test "increases odometer_km to new reading" do
      vehicle = create_vehicle(%{odometer_km: 1000.0})

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{new_reading_km: 1500.0},
          action: :update_odometer,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.odometer_km == 1500.0
    end

    test "increments total_distance_km by distance traveled" do
      vehicle = create_vehicle(%{odometer_km: 1000.0, total_distance_km: 500.0})

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{new_reading_km: 1200.0},
          action: :update_odometer,
          authorize?: false,
          actor: @system_admin
        )

      # traveled 200km more, total_distance was 500 → now 700
      assert updated.total_distance_km == 700.0
    end

    test "returns error when new reading is less than current odometer" do
      vehicle = create_vehicle(%{odometer_km: 5000.0})

      result =
        Ash.update(
          vehicle,
          %{new_reading_km: 4000.0},
          action: :update_odometer,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end

    test "same reading as current is accepted (no movement)" do
      vehicle = create_vehicle(%{odometer_km: 1000.0})

      result =
        Ash.update(
          vehicle,
          %{new_reading_km: 1000.0},
          action: :update_odometer,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:ok, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # update_fuel_level action
  # ---------------------------------------------------------------------------

  describe "update_fuel_level action" do
    test "sets fuel_level_percent to given value" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{fuel_level_percent: 75},
          action: :update_fuel_level,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.fuel_level_percent == 75
    end

    test "accepts fuel_level_percent = 0 (empty tank)" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{fuel_level_percent: 0},
          action: :update_fuel_level,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.fuel_level_percent == 0
    end

    test "accepts fuel_level_percent = 100 (full tank)" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{fuel_level_percent: 100},
          action: :update_fuel_level,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.fuel_level_percent == 100
    end

    test "rejects fuel_level_percent above 100" do
      vehicle = create_vehicle()

      result =
        Ash.update(
          vehicle,
          %{fuel_level_percent: 110},
          action: :update_fuel_level,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # schedule_maintenance action
  # ---------------------------------------------------------------------------

  describe "schedule_maintenance action" do
    test "adds alert to maintenance_alerts list" do
      vehicle = create_vehicle()
      scheduled_date = Date.add(Date.utc_today(), 7)

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{maintenance_type: "Oil Change", scheduled_date: scheduled_date},
          action: :schedule_maintenance,
          authorize?: false,
          actor: @system_admin
        )

      assert length(updated.maintenance_alerts) == 1
      assert Enum.any?(updated.maintenance_alerts, &String.contains?(&1, "Oil Change"))
    end

    test "does not duplicate an alert already in list" do
      vehicle = create_vehicle()
      scheduled_date = Date.add(Date.utc_today(), 7)

      {:ok, first} =
        Ash.update(
          vehicle,
          %{maintenance_type: "Oil Change", scheduled_date: scheduled_date},
          action: :schedule_maintenance,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, second} =
        Ash.update(
          first,
          %{maintenance_type: "Oil Change", scheduled_date: scheduled_date},
          action: :schedule_maintenance,
          authorize?: false,
          actor: @system_admin
        )

      # Should not add a duplicate
      assert length(second.maintenance_alerts) == 1
    end

    test "accumulates multiple different maintenance alerts" do
      vehicle = create_vehicle()

      {:ok, v1} =
        Ash.update(
          vehicle,
          %{maintenance_type: "Oil Change", scheduled_date: Date.add(Date.utc_today(), 7)},
          action: :schedule_maintenance,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, v2} =
        Ash.update(
          v1,
          %{maintenance_type: "Tire Rotation", scheduled_date: Date.add(Date.utc_today(), 14)},
          action: :schedule_maintenance,
          authorize?: false,
          actor: @system_admin
        )

      assert length(v2.maintenance_alerts) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # complete_maintenance action
  # ---------------------------------------------------------------------------

  describe "complete_maintenance action" do
    test "removes matching maintenance alerts" do
      vehicle = create_vehicle()
      scheduled_date = Date.add(Date.utc_today(), 7)

      {:ok, scheduled} =
        Ash.update(
          vehicle,
          %{maintenance_type: "Oil Change", scheduled_date: scheduled_date},
          action: :schedule_maintenance,
          authorize?: false,
          actor: @system_admin
        )

      assert length(scheduled.maintenance_alerts) == 1

      {:ok, completed} =
        Ash.update(
          scheduled,
          %{maintenance_type: "Oil Change"},
          action: :complete_maintenance,
          authorize?: false,
          actor: @system_admin
        )

      refute Enum.any?(completed.maintenance_alerts, &String.contains?(&1, "Oil Change"))
    end

    test "updates last_maintenance_date to today" do
      vehicle = create_vehicle()

      {:ok, completed} =
        Ash.update(
          vehicle,
          %{maintenance_type: "Inspection"},
          action: :complete_maintenance,
          authorize?: false,
          actor: @system_admin
        )

      assert completed.last_maintenance_date == Date.utc_today()
    end
  end

  # ---------------------------------------------------------------------------
  # report_defect action
  # ---------------------------------------------------------------------------

  describe "report_defect action" do
    test "adds a defect entry to defects list" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{defect_description: "Cracked windshield", severity: :minor},
          action: :report_defect,
          authorize?: false,
          actor: @system_admin
        )

      assert length(updated.defects) == 1
      defect = hd(updated.defects)
      assert defect["description"] == "Cracked windshield"
      assert defect["status"] == "open"
    end

    test "critical defect sets operational_status to :non_operational" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{defect_description: "Brake failure", severity: :critical},
          action: :report_defect,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.operational_status == :non_operational
    end

    test "minor defect does not change operational_status" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{defect_description: "Scratched bumper", severity: :minor},
          action: :report_defect,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.operational_status == :operational
    end

    test "major defect does not change operational_status" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{defect_description: "Engine leak", severity: :major},
          action: :report_defect,
          authorize?: false,
          actor: @system_admin
        )

      # major does not trigger non_operational, only critical does
      assert updated.operational_status == :operational
    end

    test "multiple defects accumulate in list" do
      vehicle = create_vehicle()

      {:ok, v1} =
        Ash.update(
          vehicle,
          %{defect_description: "Defect A", severity: :minor},
          action: :report_defect,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, v2} =
        Ash.update(
          v1,
          %{defect_description: "Defect B", severity: :major},
          action: :report_defect,
          authorize?: false,
          actor: @system_admin
        )

      assert length(v2.defects) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # resolve_defect action
  # ---------------------------------------------------------------------------

  describe "resolve_defect action" do
    test "marks defect at index as resolved" do
      vehicle = create_vehicle()

      {:ok, with_defect} =
        Ash.update(
          vehicle,
          %{defect_description: "Flat tire", severity: :major},
          action: :report_defect,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, resolved} =
        Ash.update(
          with_defect,
          %{defect_index: 0},
          action: :resolve_defect,
          authorize?: false,
          actor: @system_admin
        )

      defect = hd(resolved.defects)
      assert defect["status"] == "resolved"
      assert Map.has_key?(defect, "resolved_at")
    end

    test "out-of-bounds defect_index leaves defects unchanged" do
      vehicle = create_vehicle()

      {:ok, with_defect} =
        Ash.update(
          vehicle,
          %{defect_description: "Minor scratch", severity: :minor},
          action: :report_defect,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, unchanged} =
        Ash.update(
          with_defect,
          %{defect_index: 99},
          action: :resolve_defect,
          authorize?: false,
          actor: @system_admin
        )

      # defects unchanged when index out of bounds
      assert hd(unchanged.defects)["status"] == "open"
    end
  end

  # ---------------------------------------------------------------------------
  # track_assignment action
  # ---------------------------------------------------------------------------

  describe "track_assignment action" do
    test "increments total_assignments by 1" do
      vehicle = create_vehicle()
      initial = vehicle.total_assignments

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{runtime_hours: 2.5},
          action: :track_assignment,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.total_assignments == initial + 1
    end

    test "adds runtime_hours to total_runtime_hours" do
      vehicle = create_vehicle(%{total_runtime_hours: 10.0})

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{runtime_hours: 3.0},
          action: :track_assignment,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.total_runtime_hours == 13.0
    end

    test "multiple track_assignment calls accumulate correctly" do
      vehicle = create_vehicle()

      {:ok, v1} =
        Ash.update(vehicle, %{runtime_hours: 2.0},
          action: :track_assignment,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, v2} =
        Ash.update(v1, %{runtime_hours: 3.0},
          action: :track_assignment,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, v3} =
        Ash.update(v2, %{runtime_hours: 1.5},
          action: :track_assignment,
          authorize?: false,
          actor: @system_admin
        )

      assert v3.total_assignments == 3
      assert v3.total_runtime_hours == 6.5
    end
  end

  # ---------------------------------------------------------------------------
  # activate / deactivate actions
  # ---------------------------------------------------------------------------

  describe "activate and deactivate actions" do
    test "deactivate sets active? to false" do
      vehicle = create_vehicle(%{active?: true})

      {:ok, deactivated} =
        Ash.update(vehicle, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      assert deactivated.active? == false
    end

    test "activate sets active? to true" do
      vehicle = create_vehicle(%{active?: false})

      # Need to create with active?: false directly
      tenant = random_tenant()

      {:ok, inactive} =
        Ash.create(
          Vehicle,
          %{
            call_sign: unique_call_sign(),
            license_plate: unique_plate(),
            make: "Honda",
            model: "CR-V",
            year: 2021,
            active?: false,
            tenant_id: tenant.id
          },
          action: :create,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, activated} =
        Ash.update(inactive, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert activated.active? == true
    end

    test "deactivate returns error when already inactive" do
      tenant = random_tenant()

      {:ok, inactive} =
        Ash.create(
          Vehicle,
          %{
            call_sign: unique_call_sign(),
            license_plate: unique_plate(),
            make: "Mitsubishi",
            model: "Pajero",
            year: 2020,
            active?: false,
            tenant_id: tenant.id
          },
          action: :create,
          authorize?: false,
          actor: @system_admin
        )

      result =
        Ash.update(inactive, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      assert match?({:error, _}, result)
    end

    test "activate returns error when already active" do
      vehicle = create_vehicle(%{active?: true})

      result =
        Ash.update(vehicle, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # remove_assignment action
  # ---------------------------------------------------------------------------

  describe "remove_assignment action" do
    test "clears team_id, assigned_officer_id and sets status to :available" do
      vehicle = create_vehicle()

      # Manually set a team_id via update
      {:ok, with_team_id} =
        Ash.update(
          vehicle,
          %{team_id: Ash.UUID.generate()},
          action: :update,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, cleared} =
        Ash.update(
          with_team_id,
          %{},
          action: :remove_assignment,
          authorize?: false,
          actor: @system_admin
        )

      assert is_nil(cleared.team_id)
      assert is_nil(cleared.assigned_officer_id)
      assert cleared.status == :available
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 invariants
  # ---------------------------------------------------------------------------

  describe "SIL-6 Safety Invariants (SC-COV-001)" do
    test "vehicle with critical defect cannot be operational" do
      vehicle = create_vehicle()

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{defect_description: "Engine failure", severity: :critical},
          action: :report_defect,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.operational_status == :non_operational
    end

    test "odometer is monotonically non-decreasing (Psi3 verification)" do
      vehicle = create_vehicle(%{odometer_km: 1000.0})

      {:ok, v1} =
        Ash.update(vehicle, %{new_reading_km: 1100.0},
          action: :update_odometer,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, v2} =
        Ash.update(v1, %{new_reading_km: 1250.0},
          action: :update_odometer,
          authorize?: false,
          actor: @system_admin
        )

      assert v2.odometer_km >= v1.odometer_km
      assert v1.odometer_km >= vehicle.odometer_km
    end

    test "total_assignments is monotonically non-decreasing" do
      vehicle = create_vehicle()

      {:ok, v1} =
        Ash.update(vehicle, %{runtime_hours: 1.0},
          action: :track_assignment,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, v2} =
        Ash.update(v1, %{runtime_hours: 2.0},
          action: :track_assignment,
          authorize?: false,
          actor: @system_admin
        )

      assert v2.total_assignments >= v1.total_assignments
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests (EP-GEN-014 compliant)
  # ---------------------------------------------------------------------------

  test "created vehicle always has status :available and active? true by default" do
    forall _x <- PC.boolean() do
      vehicle = create_vehicle()
      vehicle.status == :available && vehicle.active? == true
    end
  end

  test "odometer reading can only increase — never decrease" do
    forall {start_km, add_km} <- {PC.float(0.0, 5000.0), PC.float(0.1, 500.0)} do
      vehicle = create_vehicle(%{odometer_km: start_km})
      new_reading = start_km + add_km

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{new_reading_km: new_reading},
          action: :update_odometer,
          authorize?: false,
          actor: @system_admin
        )

      updated.odometer_km >= vehicle.odometer_km
    end
  end

  test "fuel_level_percent within 0..100 always accepted" do
    forall level <- PC.integer(0, 100) do
      vehicle = create_vehicle()

      result =
        Ash.update(
          vehicle,
          %{fuel_level_percent: level},
          action: :update_fuel_level,
          authorize?: false,
          actor: @system_admin
        )

      match?({:ok, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties tests (EP-GEN-014 compliant)
  # ---------------------------------------------------------------------------

  test "track_assignment always increments total_assignments by 1" do
    ExUnitProperties.check all(runtime_hours <- SD.float(min: 0.0)) do
      vehicle = create_vehicle()
      initial = vehicle.total_assignments

      {:ok, updated} =
        Ash.update(
          vehicle,
          %{runtime_hours: runtime_hours},
          action: :track_assignment,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.total_assignments == initial + 1
    end
  end

  test "update_status accepts any valid status atom" do
    ExUnitProperties.check all(
                             new_status <-
                               SD.member_of([
                                 :available,
                                 :assigned,
                                 :in_use,
                                 :en_route,
                                 :on_scene,
                                 :out_of_service,
                                 :maintenance,
                                 :fueling,
                                 :cleaning
                               ])
                           ) do
      vehicle = create_vehicle()

      result =
        Ash.update(
          vehicle,
          %{status: new_status},
          action: :update_status,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:ok, _}, result)
    end
  end
end
