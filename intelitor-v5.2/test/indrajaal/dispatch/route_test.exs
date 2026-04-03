defmodule Indrajaal.Dispatch.RouteTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Dispatch.Route.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation hardening
  - FPPS Validation: Route lifecycle verified across planned→active→completed/cancelled

  ## STAMP Safety Integration
  - SC-COV-001: Critical route navigation state machine path coverage
  - SC-COV-006: TDG compliance mandatory
  - SC-HOLON-001: Route state written to PostgreSQL via Ash (business data)

  ## Constitutional Verification
  - Psi0 Existence: Route records persist across status transitions
  - Psi1 Regeneration: Route state fully reconstructible from Ash resource

  ## Founder's Directive Alignment
  - Omega0.1: Accurate route tracking ensures rapid and efficient security response

  ## TPS 5-Level RCA Context
  - L1 Symptom: Routes stuck in :planned state or showing stale progress
  - L5 Root Cause: Missing validation boundary for route status state machine

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude | Sprint 54 W3 test generation |

  ## Notes
  - Route create action requires origin_lat, origin_lng, dest_lat, dest_lng as arguments
    (not attributes) — coordinate map is populated in a before_action change function.
  - start_navigation validates status == :planned.
  - update_progress validates status == :active.
  - complete_route validates status == :active.
  - cancel_route validates status in [:planned, :active].
  - recalculate_route: increments route_recalculations counter but returns original changeset
    (not the intermediate _changeset) for new_distance / new_duration — this is a stub behavior.
  - report_deviation sets status to :deviated, planned_route? to false.
  - add_traffic_incident prepends to traffic_incidents list.
  - No dispatch route factory exists — creates via Ash.create directly.
  """

  use Indrajaal.DataCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Dispatch.Route

  @moduletag :zenoh_nif

  @system_admin %{id: "system", is_system_admin: true}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_route(attrs \\ %{}) do
    tenant = random_tenant()

    base = %{
      origin_address: "Security HQ, Mumbai",
      destination_address: "Incident Site, Bandra",
      origin_lat: 19.076,
      origin_lng: 72.877,
      dest_lat: 19.054,
      dest_lng: 72.841,
      total_distance_km: 5.2,
      estimated_duration_minutes: 15,
      route_type: :fastest,
      tenant_id: tenant.id
    }

    attrs_with_tenant = Map.put_new(attrs, :tenant_id, tenant.id)
    merged = Map.merge(base, attrs_with_tenant)

    {:ok, route} =
      Ash.create(Route, merged, action: :create, authorize?: false, actor: @system_admin)

    route
  end

  defp start_route(route) do
    {:ok, started} =
      Ash.update(route, %{}, action: :start_navigation, authorize?: false, actor: @system_admin)

    started
  end

  # ---------------------------------------------------------------------------
  # create action
  # ---------------------------------------------------------------------------

  describe "create action" do
    test "creates a route with default status :planned" do
      route = create_route()
      assert route.status == :planned
    end

    test "creates route with default route_type :fastest" do
      route = create_route()
      assert route.route_type == :fastest
    end

    test "creates route with default current_progress_percent 0" do
      route = create_route()
      assert route.current_progress_percent == 0
    end

    test "creates route with default planned_route? true" do
      route = create_route()
      assert route.planned_route? == true
    end

    test "creates route with default emergency_route? false" do
      route = create_route()
      assert route.emergency_route? == false
    end

    test "creates route with default route_recalculations 0" do
      route = create_route()
      assert route.route_recalculations == 0
    end

    test "populates origin_coordinates from origin_lat/origin_lng arguments" do
      route = create_route(%{origin_lat: 28.6139, origin_lng: 77.209})
      assert route.origin_coordinates["latitude"] == 28.6139
      assert route.origin_coordinates["longitude"] == 77.209
    end

    test "populates destination_coordinates from dest_lat/dest_lng arguments" do
      route = create_route(%{dest_lat: 12.9716, dest_lng: 77.5946})
      assert route.destination_coordinates["latitude"] == 12.9716
      assert route.destination_coordinates["longitude"] == 77.5946
    end

    test "creates route with custom route_type :emergency" do
      route = create_route(%{route_type: :emergency})
      assert route.route_type == :emergency
    end

    test "creates route with emergency_route? true" do
      route = create_route(%{emergency_route?: true, use_emergency_lanes?: true})
      assert route.emergency_route? == true
      assert route.use_emergency_lanes? == true
    end

    test "stores origin and destination addresses" do
      route = create_route()
      assert route.origin_address == "Security HQ, Mumbai"
      assert route.destination_address == "Incident Site, Bandra"
    end

    test "rejects origin_lat out of -90..90 range" do
      tenant = random_tenant()

      result =
        Ash.create(
          Route,
          %{
            origin_address: "A",
            destination_address: "B",
            origin_lat: 95.0,
            origin_lng: 72.877,
            dest_lat: 19.054,
            dest_lng: 72.841,
            total_distance_km: 5.0,
            estimated_duration_minutes: 10,
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
  # start_navigation action
  # ---------------------------------------------------------------------------

  describe "start_navigation action" do
    test "transitions status from :planned to :active" do
      route = create_route()
      assert route.status == :planned

      {:ok, started} =
        Ash.update(route, %{}, action: :start_navigation, authorize?: false, actor: @system_admin)

      assert started.status == :active
    end

    test "sets started_at to current datetime" do
      route = create_route()
      before_start = DateTime.utc_now()

      {:ok, started} =
        Ash.update(route, %{}, action: :start_navigation, authorize?: false, actor: @system_admin)

      assert not is_nil(started.started_at)
      assert DateTime.compare(started.started_at, before_start) != :lt
    end

    test "sets current_progress_percent to 0" do
      route = create_route()

      {:ok, started} =
        Ash.update(route, %{}, action: :start_navigation, authorize?: false, actor: @system_admin)

      assert started.current_progress_percent == 0
    end

    test "returns error when starting an already-active route" do
      route = create_route()

      {:ok, started} =
        Ash.update(route, %{}, action: :start_navigation, authorize?: false, actor: @system_admin)

      result =
        Ash.update(started, %{},
          action: :start_navigation,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # update_progress action
  # ---------------------------------------------------------------------------

  describe "update_progress action" do
    test "updates current_progress_percent on active route" do
      route = create_route() |> start_route()

      {:ok, updated} =
        Ash.update(
          route,
          %{latitude: 19.065, longitude: 72.855, progress_percent: 50},
          action: :update_progress,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.current_progress_percent == 50
    end

    test "stores current location map on progress update" do
      route = create_route() |> start_route()

      {:ok, updated} =
        Ash.update(
          route,
          %{latitude: 19.065, longitude: 72.855, progress_percent: 30},
          action: :update_progress,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.current_location["latitude"] == 19.065
      assert updated.current_location["longitude"] == 72.855
    end

    test "sets last_update on progress update" do
      route = create_route() |> start_route()
      before_update = DateTime.utc_now()

      {:ok, updated} =
        Ash.update(
          route,
          %{latitude: 19.060, longitude: 72.850, progress_percent: 25},
          action: :update_progress,
          authorize?: false,
          actor: @system_admin
        )

      assert not is_nil(updated.last_update)
      assert DateTime.compare(updated.last_update, before_update) != :lt
    end

    test "returns error when updating progress on a planned route" do
      route = create_route()

      result =
        Ash.update(
          route,
          %{latitude: 19.065, longitude: 72.855, progress_percent: 50},
          action: :update_progress,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end

    test "rejects progress_percent > 100" do
      route = create_route() |> start_route()

      result =
        Ash.update(
          route,
          %{latitude: 19.065, longitude: 72.855, progress_percent: 110},
          action: :update_progress,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # complete_route action
  # ---------------------------------------------------------------------------

  describe "complete_route action" do
    test "transitions status from :active to :completed" do
      route = create_route() |> start_route()

      {:ok, completed} =
        Ash.update(route, %{}, action: :complete_route, authorize?: false, actor: @system_admin)

      assert completed.status == :completed
    end

    test "sets current_progress_percent to 100 on completion" do
      route = create_route() |> start_route()

      {:ok, completed} =
        Ash.update(route, %{}, action: :complete_route, authorize?: false, actor: @system_admin)

      assert completed.current_progress_percent == 100
    end

    test "sets completed_at to a datetime" do
      route = create_route() |> start_route()
      before_complete = DateTime.utc_now()

      {:ok, completed} =
        Ash.update(route, %{}, action: :complete_route, authorize?: false, actor: @system_admin)

      assert not is_nil(completed.completed_at)
      assert DateTime.compare(completed.completed_at, before_complete) != :lt
    end

    test "returns error when completing a planned route" do
      route = create_route()

      result =
        Ash.update(route, %{}, action: :complete_route, authorize?: false, actor: @system_admin)

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # cancel_route action
  # ---------------------------------------------------------------------------

  describe "cancel_route action" do
    test "cancels a planned route" do
      route = create_route()

      {:ok, cancelled} =
        Ash.update(
          route,
          %{reason: "Incident resolved before dispatch"},
          action: :cancel_route,
          authorize?: false,
          actor: @system_admin
        )

      assert cancelled.status == :cancelled
    end

    test "cancels an active route" do
      route = create_route() |> start_route()

      {:ok, cancelled} =
        Ash.update(
          route,
          %{reason: "Route blocked, unit recalled"},
          action: :cancel_route,
          authorize?: false,
          actor: @system_admin
        )

      assert cancelled.status == :cancelled
    end

    test "stores cancellation reason in notes" do
      route = create_route()

      {:ok, cancelled} =
        Ash.update(
          route,
          %{reason: "Duplicate dispatch"},
          action: :cancel_route,
          authorize?: false,
          actor: @system_admin
        )

      assert cancelled.notes == "Duplicate dispatch"
    end

    test "returns error when cancelling a completed route" do
      route = create_route() |> start_route()

      {:ok, completed} =
        Ash.update(route, %{}, action: :complete_route, authorize?: false, actor: @system_admin)

      result =
        Ash.update(
          completed,
          %{reason: "too late"},
          action: :cancel_route,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # report_deviation action
  # ---------------------------------------------------------------------------

  describe "report_deviation action" do
    test "sets status to :deviated and planned_route? to false" do
      route = create_route()

      {:ok, deviated} =
        Ash.update(
          route,
          %{deviation_reason: "Road closure at N.S. Patkar Marg"},
          action: :report_deviation,
          authorize?: false,
          actor: @system_admin
        )

      assert deviated.status == :deviated
      assert deviated.planned_route? == false
    end
  end

  # ---------------------------------------------------------------------------
  # add_traffic_incident action
  # ---------------------------------------------------------------------------

  describe "add_traffic_incident action" do
    test "adds incident to traffic_incidents list" do
      route = create_route()

      {:ok, updated} =
        Ash.update(
          route,
          %{
            incident_type: "Accident",
            incident_location: "Western Express Highway KM 14",
            severity: :major
          },
          action: :add_traffic_incident,
          authorize?: false,
          actor: @system_admin
        )

      assert length(updated.traffic_incidents) == 1
      incident = hd(updated.traffic_incidents)
      assert incident["type"] == "Accident"
      assert incident["location"] == "Western Express Highway KM 14"
    end

    test "accumulates multiple traffic incidents" do
      route = create_route()

      {:ok, r1} =
        Ash.update(
          route,
          %{incident_type: "Accident", incident_location: "Site A", severity: :minor},
          action: :add_traffic_incident,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, r2} =
        Ash.update(
          r1,
          %{incident_type: "Construction", incident_location: "Site B", severity: :moderate},
          action: :add_traffic_incident,
          authorize?: false,
          actor: @system_admin
        )

      assert length(r2.traffic_incidents) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Invariants
  # ---------------------------------------------------------------------------

  describe "SIL-6 Route Safety Invariants (SC-COV-001)" do
    test "completed_at is always after started_at (Psi3 temporal invariant)" do
      route = create_route()
      started = start_route(route)

      {:ok, completed} =
        Ash.update(started, %{}, action: :complete_route, authorize?: false, actor: @system_admin)

      assert not is_nil(completed.started_at)
      assert not is_nil(completed.completed_at)
      assert DateTime.compare(completed.completed_at, completed.started_at) != :lt
    end

    test "progress_percent is always 0..100 after update_progress" do
      route = create_route() |> start_route()

      {:ok, updated} =
        Ash.update(
          route,
          %{latitude: 19.060, longitude: 72.850, progress_percent: 75},
          action: :update_progress,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.current_progress_percent >= 0
      assert updated.current_progress_percent <= 100
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests (EP-GEN-014 compliant)
  # ---------------------------------------------------------------------------

  test "created route always has status :planned and route_recalculations 0" do
    forall _x <- PC.boolean() do
      route = create_route()
      route.status == :planned && route.route_recalculations == 0
    end
  end

  test "any valid route_type is accepted on create" do
    forall route_type <-
             PC.oneof([
               PC.exactly(:fastest),
               PC.exactly(:shortest),
               PC.exactly(:avoid_traffic),
               PC.exactly(:emergency),
               PC.exactly(:custom)
             ]) do
      result =
        Ash.create(
          Route,
          %{
            origin_address: "HQ",
            destination_address: "Site",
            origin_lat: 19.0,
            origin_lng: 72.8,
            dest_lat: 18.9,
            dest_lng: 72.9,
            total_distance_km: 10.0,
            estimated_duration_minutes: 20,
            route_type: route_type,
            tenant_id: random_tenant().id
          },
          action: :create,
          authorize?: false,
          actor: @system_admin
        )

      match?({:ok, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties tests (EP-GEN-014 compliant)
  # ---------------------------------------------------------------------------

  test "cancel_route always succeeds for :planned routes with any non-empty reason" do
    ExUnitProperties.check all(reason <- SD.string(:printable, min_length: 1, max_length: 200)) do
      route = create_route()

      result =
        Ash.update(
          route,
          %{reason: reason},
          action: :cancel_route,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:ok, _}, result)
    end
  end

  test "update_progress with valid percent always succeeds on active route" do
    ExUnitProperties.check all(progress_percent <- SD.integer(0..100)) do
      route = create_route() |> start_route()

      result =
        Ash.update(
          route,
          %{latitude: 19.0, longitude: 72.8, progress_percent: progress_percent},
          action: :update_progress,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:ok, _}, result)
    end
  end
end
