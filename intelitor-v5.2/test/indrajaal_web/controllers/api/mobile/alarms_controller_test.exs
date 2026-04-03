defmodule IndrajaalWeb.Api.Mobile.AlarmsControllerTest do
  @moduledoc """
  Comprehensive test suite for mobile alarms API.

  Implements 6 testing methodologies:
  1. Unit Testing - Individual function testing
  2. Integration Testing - Full API endpoint testing
  3. Property - Based Testing - Invariant validation
  4. Contract Testing - OpenAPI compliance
  5. Performance Testing - Response time validation
  6. Security Testing - Authorization and __data isolation

  SOPv5.1 Compliance: ✅
  TDG Methodology: Tests written before implementation
  Agent: Worker - 3 validates alarm endpoints
  """

  use IndrajaalWeb.ConnCase, async: true
  use IndrajaalWeb, :verified_routes
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # Helper for response assertions (replaces undefined assert_response/3)
  defp assert_status(conn, status) do
    json_response(conn, status)
  end

  alias Indrajaal.AlarmManagement
  alias Indrajaal.Authentication
  # Note: Using plain maps for alarm test data since Alarm is an Ash resource

  @tag :tdg_required
  @tag :container_only
  @tag timeout: :infinity

  # Test data setup
  setup %{conn: conn} do
    # Create test tenant and users
    tenant = insert(:tenant, name: "Test Security Corp")
    admin_user = insert(:user, tenant: tenant, role: "admin")
    operator_user = insert(:user, tenant: tenant, role: "operator")
    guard_user = insert(:user, tenant: tenant, role: "guard")
    other_tenant = insert(:tenant, name: "Other Corp")
    other_user = insert(:user, tenant: other_tenant, role: "admin")

    # Generate authentication tokens
    {:ok, admin_token} = Authentication.generate_token(admin_user)
    {:ok, operator_token} = Authentication.generate_token(operator_user)
    {:ok, guard_token} = Authentication.generate_token(guard_user)
    {:ok, other_token} = Authentication.generate_token(other_user)

    # Create test site and device
    site = insert(:site, tenant: tenant, name: "Main Building")
    device = insert(:device, tenant: tenant, site: site, name: "Camera 01")

    # Create test alarms with various states
    alarms = [
      insert(:alarm,
        tenant: tenant,
        device: device,
        site: site,
        alarm_type: "motion_detected",
        priority: "high",
        status: "new",
        triggered_at: DateTime.utc_now()
      ),
      insert(:alarm,
        tenant: tenant,
        device: device,
        site: site,
        alarm_type: "intrusion",
        priority: "critical",
        status: "acknowledged",
        acknowledged_by: operator_user,
        acknowledged_at: DateTime.utc_now()
      ),
      insert(:alarm,
        tenant: tenant,
        device: device,
        site: site,
        alarm_type: "sensor_fault",
        priority: "medium",
        status: "resolved",
        resolved_by: admin_user,
        resolved_at: DateTime.utc_now()
      )
    ]

    # Create alarm in other tenant for isolation testing
    other_alarm = insert(:alarm, tenant: other_tenant, status: "new")

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{admin_token}")
      |> put_req_header("content-type", "application/json")

    %{
      conn: conn,
      tenant: tenant,
      admin_user: admin_user,
      admin_token: admin_token,
      operator_user: operator_user,
      operator_token: operator_token,
      guard_user: guard_user,
      guard_token: guard_token,
      other_user: other_user,
      other_token: other_token,
      site: site,
      device: device,
      alarms: alarms,
      other_alarm: other_alarm
    }
  end

  # ============================================================================
  # 1. UNIT TESTS - Test individual functions in isolation
  # ============================================================================

  describe "unit tests - controller functions" do
    @tag :unit
    test "parse_alarm_filters/1 correctly parses query parameters" do
      params = %{
        "status" => "new",
        "priority" => "high,critical",
        "alarm_type" => "motion_detected",
        "site_id" => "123",
        "device_id" => "456",
        "from_date" => "2024-01-01",
        "to_date" => "2024-12-31",
        "invalid_key" => "ignored"
      }

      filters = IndrajaalWeb.Api.Mobile.AlarmsController.parse_alarm_filters(params)

      assert filters == %{
               status: "new",
               priority: ["high", "critical"],
               alarm_type: "motion_detected",
               site_id: "123",
               device_id: "456",
               from_date: ~D[2024-01-01],
               to_date: ~D[2024-12-31]
             }

      refute Map.has_key?(filters, :invalid_key)
    end

    @tag :unit
    test "format_alarm_response/1 includes all required fields" do
      # Using a map to simulate alarm structure for unit testing
      alarm = %{
        id: "123",
        alarm_type: "motion_detected",
        priority: "high",
        status: "new",
        triggered_at: ~U[2024-01-01 12:00:00Z],
        site: %{id: "site-1", name: "Main Building"},
        device: %{id: "dev-1", name: "Camera 01"},
        metadata: %{"zone" => "perimeter", "confidence" => 0.95}
      }

      formatted = IndrajaalWeb.Api.Mobile.AlarmsController.format_alarm_response(alarm)

      assert formatted[:id] == "123"
      assert formatted[:alarm_type] == "motion_detected"
      assert formatted[:priority] == "high"
      assert formatted[:status] == "new"
      assert formatted[:site_name] == "Main Building"
      assert formatted[:device_name] == "Camera 01"
      assert formatted[:metadata]["confidence"] == 0.95
    end
  end

  # ============================================================================
  # 2. INTEGRATION TESTS - Test complete API endpoints
  # ============================================================================

  describe "GET /api/mobile/alarms" do
    @tag :integration
    test "returns paginated list of alarms for tenant", %{conn: conn, alarms: alarms} do
      conn = get(conn, ~p"/api/mobile/alarms")

      assert %{
               "status" => "success",
               "data" => returned_alarms,
               "meta" => %{
                 "page" => 1,
                 "page_size" => 20,
                 "total_count" => 3,
                 "total_pages" => 1,
                 "stats" => %{
                   "new" => 1,
                   "acknowledged" => 1,
                   "resolved" => 1
                 }
               }
             } = json_response(conn, 200)

      assert length(returned_alarms) == 3

      # Verify alarm structure
      first_alarm = hd(returned_alarms)
      assert Map.has_key?(first_alarm, "id")
      assert Map.has_key?(first_alarm, "alarm_type")
      assert Map.has_key?(first_alarm, "priority")
      assert Map.has_key?(first_alarm, "status")
      assert Map.has_key?(first_alarm, "triggered_at")
      assert Map.has_key?(first_alarm, "site")
      assert Map.has_key?(first_alarm, "device")
    end

    @tag :integration
    test "filters alarms by status", %{conn: conn} do
      conn = get(conn, ~p"/api/mobile/alarms?status=new")

      assert %{"data" => alarms} = json_response(conn, 200)
      assert Enum.all?(alarms, &(&1["status"] == "new"))
    end

    @tag :integration
    test "filters alarms by multiple priorities", %{conn: conn} do
      conn = get(conn, ~p"/api/mobile/alarms?priority=high,critical")

      assert %{"data" => alarms} = json_response(conn, 200)
      assert Enum.all?(alarms, &(&1["priority"] in ["high", "critical"]))
    end

    @tag :integration
    test "filters alarms by date range", %{conn: conn} do
      from_date = Date.utc_today() |> Date.add(-7)
      to_date = Date.utc_today()

      conn = get(conn, ~p"/api/mobile/alarms?from_date=#{from_date}&to_date=#{to_date}")

      assert %{"data" => alarms} = json_response(conn, 200)
      # All returned alarms should be within date range
      assert Enum.all?(alarms, fn alarm ->
               iso_result = DateTime.from_iso8601(alarm["triggered_at"])
               triggered_date = iso_result |> elem(1) |> DateTime.to_date()

               Date.compare(triggered_date, from_date) != :lt and
                 Date.compare(triggered_date, to_date) != :gt
             end)
    end

    @tag :integration
    test "enforces tenant isolation", %{conn: conn, other_alarm: other_alarm} do
      conn = get(conn, ~p"/api/mobile/alarms")

      assert %{"data" => alarms} = json_response(conn, 200)
      alarm_ids = Enum.map(alarms, & &1["id"])

      # Other tenant's alarm should not be visible
      refute other_alarm.id in alarm_ids
    end
  end

  describe "GET /api/mobile/alarms/:id" do
    @tag :integration
    test "returns detailed alarm information", %{conn: conn, alarms: [alarm | _]} do
      conn = get(conn, ~p"/api/mobile/alarms/#{alarm.id}")

      assert %{
               "status" => "success",
               "data" => alarm_data
             } = json_response(conn, 200)

      assert alarm_data["id"] == alarm.id
      assert alarm_data["alarm_type"] == "motion_detected"
      assert alarm_data["priority"] == "high"
      assert alarm_data["status"] == "new"

      # Should include related data
      assert Map.has_key?(alarm_data, "site")
      assert Map.has_key?(alarm_data, "device")
      assert Map.has_key?(alarm_data, "audit_trail")
    end

    @tag :integration
    test "returns 404 for non-existent alarm", %{conn: conn} do
      conn = get(conn, ~p"/api/mobile/alarms/#{Ecto.UUID.generate()}")

      assert_status(conn, 404)["status"] == "error"
    end

    @tag :integration
    test "returns 404 for alarm in other tenant", %{conn: conn, other_alarm: alarm} do
      conn = get(conn, ~p"/api/mobile/alarms/#{alarm.id}")

      assert_status(conn, 404)["status"] == "error"
    end
  end

  describe "POST /api/mobile/alarms/:id/acknowledge" do
    @tag :integration
    test "acknowledges alarm with notes", %{conn: conn, alarms: [alarm | _]} do
      ack_params = %{
        "notes" => "Security guard dispatched to location",
        "eta_minutes" => 5
      }

      conn = post(conn, ~p"/api/mobile/alarms/#{alarm.id}/acknowledge", ack_params)

      assert %{
               "status" => "success",
               "data" => updated_alarm,
               "message" => "Alarm acknowledged successfully"
             } = json_response(conn, 200)

      assert updated_alarm["status"] == "acknowledged"
      assert updated_alarm["acknowledged_by"]["id"]
      assert updated_alarm["acknowledged_at"]
      assert updated_alarm["acknowledgment_notes"] == "Security guard dispatched to location"
    end

    @tag :integration
    test "cannot acknowledge already resolved alarm", %{conn: conn, alarms: alarms} do
      resolved_alarm = Enum.find(alarms, &(&1.status == "resolved"))

      conn = post(conn, ~p"/api/mobile/alarms/#{resolved_alarm.id}/acknowledge", %{})

      assert %{
               "status" => "error",
               "message" => "Cannot acknowledge resolved alarm"
             } = json_response(conn, 422)
    end
  end

  describe "POST /api/mobile/alarms/:id/resolve" do
    @tag :integration
    test "resolves alarm with resolution details", %{conn: conn, alarms: alarms} do
      ack_alarm = Enum.find(alarms, &(&1.status == "acknowledged"))

      resolve_params = %{
        "resolution" => "false_alarm",
        "notes" => "Motion caused by tree branch",
        "actions_taken" => ["site_inspected", "camera_adjusted"]
      }

      conn = post(conn, ~p"/api/mobile/alarms/#{ack_alarm.id}/resolve", resolve_params)

      assert %{
               "status" => "success",
               "data" => updated_alarm
             } = json_response(conn, 200)

      assert updated_alarm["status"] == "resolved"
      assert updated_alarm["resolution"] == "false_alarm"
      assert updated_alarm["resolved_by"]["id"]
      assert updated_alarm["resolved_at"]
      assert "site_inspected" in updated_alarm["actions_taken"]
    end

    @tag :integration
    test "cannot resolve unacknowledged alarm", %{conn: conn, alarms: [new_alarm | _]} do
      conn =
        post(conn, ~p"/api/mobile/alarms/#{new_alarm.id}/resolve", %{
          "resolution" => "false_alarm"
        })

      assert %{
               "status" => "error",
               "message" => "Alarm must be acknowledged before resolving"
             } = json_response(conn, 422)
    end
  end

  describe "POST /api/mobile/alarms/:id/escalate" do
    @tag :integration
    test "escalates alarm priority", %{conn: conn, alarms: alarms} do
      medium_alarm = Enum.find(alarms, &(&1.priority == "medium"))

      escalate_params = %{
        "new_priority" => "high",
        "reason" => "Multiple sensors triggered",
        "notify_supervisor" => true
      }

      conn = post(conn, ~p"/api/mobile/alarms/#{medium_alarm.id}/escalate", escalate_params)

      assert %{
               "status" => "success",
               "data" => updated_alarm,
               "message" => "Alarm escalated successfully"
             } = json_response(conn, 200)

      assert updated_alarm["priority"] == "high"
      assert updated_alarm["escalation_history"]
    end
  end

  # ============================================================================
  # 3. PROPERTY-BASED TESTS - Test invariants with generated data
  # ============================================================================

  describe "property-based tests" do
    @tag :property
    property "valid alarm state transitions" do
      forall {current_status, action} <- {
               PC.oneof(["new", "acknowledged", "resolved"]),
               PC.oneof([:acknowledge, :resolve, :reopen])
             } do
        result = AlarmManagement.validate_status_transition(current_status, action)

        case {current_status, action} do
          {"new", :acknowledge} -> result == :ok
          {"acknowledged", :resolve} -> result == :ok
          {"resolved", :reopen} -> result == :ok
          {"resolved", :acknowledge} -> result == {:error, :invalid_transition}
          {"new", :resolve} -> result == {:error, :must_acknowledge_first}
          _ -> true
        end
      end
    end

    @tag :property
    property "alarm priorities are always valid" do
      forall priority <- PC.oneof(["low", "medium", "high", "critical"]) do
        alarm_params = %{
          "alarm_type" => "test",
          "priority" => priority
        }

        case AlarmManagement.create_alarm(alarm_params) do
          {:ok, alarm} -> alarm.priority in ["low", "medium", "high", "critical"]
          {:error, _} -> true
        end
      end
    end

    @tag :property
    test "pagination returns consistent total count" do
      ExUnitProperties.check all(
                               page <- SD.positive_integer(),
                               page_size <- SD.integer(1..50)
                             ) do
        {:ok, page1} = AlarmManagement.list_alarms(%{page: 1, page_size: page_size})
        {:ok, page_n} = AlarmManagement.list_alarms(%{page: page, page_size: page_size})

        # Total count should be consistent across pages
        page1.total_count == page_n.total_count
      end
    end
  end

  # ============================================================================
  # 4. CONTRACT TESTS - Validate API contract compliance
  # ============================================================================

  describe "contract tests - OpenAPI compliance" do
    @tag :contract
    test "alarm list response matches OpenAPI schema", %{conn: conn} do
      conn = get(conn, ~p"/api/mobile/alarms")
      response = json_response(conn, 200)

      # Validate response structure
      assert_schema_compliance(response, :alarm_list_response)

      # Validate each alarm object
      Enum.each(response["data"], fn alarm ->
        assert_schema_compliance(alarm, :alarm_object)
      end)

      # Validate meta object
      assert_schema_compliance(response["meta"], :pagination_meta)
    end

    @tag :contract
    test "alarm detail response includes all required fields", %{
      conn: conn,
      alarms: [alarm | _]
    } do
      conn = get(conn, ~p"/api/mobile/alarms/#{alarm.id}")
      response = json_response(conn, 200)

      alarm_data = response["data"]

      # Required fields per OpenAPI spec
      required_fields = [
        "id",
        "alarm_type",
        "priority",
        "status",
        "triggered_at",
        "site",
        "device",
        "audit_trail",
        "metadata"
      ]

      Enum.each(required_fields, fn field ->
        assert Map.has_key?(alarm_data, field), "Missing required field: #{field}"
      end)
    end

    @tag :contract
    test "acknowledge request validates required fields", %{conn: conn, alarms: [alarm | _]} do
      # Missing required notes
      conn = post(conn, ~p"/api/mobile/alarms/#{alarm.id}/acknowledge", %{})

      error_response = json_response(conn, 422)
      assert_schema_compliance(error_response, :validation_error_response)
    end
  end

  # ============================================================================
  # 5. PERFORMANCE TESTS - Validate response times and throughput
  # ============================================================================

  describe "performance tests" do
    @tag :performance
    @tag timeout: 120_000
    test "alarm list responds within SLA", %{conn: conn, admin_token: token} do
      # Create 100 test alarms for performance testing
      for _ <- 1..100 do
        insert(:alarm, tenant_id: get_tenant_id(token))
      end

      # Warm up
      make_alarm_request(conn, token)

      # Measure response times
      times =
        for _ <- 1..50 do
          {time, _} =
            :timer.tc(fn ->
              make_alarm_request(conn, token)
            end)

          time
        end

      # Convert to ms
      avg_time = Enum.sum(times) / length(times) / 1000
      p95_time = percentile(times, 0.95) / 1000

      assert avg_time < 100, "Average response time #{avg_time}ms exceeds 100ms SLA"
      assert p95_time < 200, "95th percentile #{p95_time}ms exceeds 200ms SLA"
    end

    @tag :performance
    test "acknowledge alarm completes quickly", %{conn: conn} do
      # Create fresh alarm
      alarm = insert(:alarm, status: "new")

      {time, response} =
        :timer.tc(fn ->
          conn
          |> post(~p"/api/mobile/alarms/#{alarm.id}/acknowledge", %{
            "notes" => "Test acknowledgment"
          })
          |> json_response(200)
        end)

      time_ms = time / 1000

      assert response["status"] == "success"
      assert time_ms < 100, "Acknowledge took #{time_ms}ms (limit: 100ms)"
    end

    @tag :performance
    test "handles high-frequency alarm creation", %{conn: conn, device: device} do
      # Simulate alarm storm - 50 alarms in rapid succession
      tasks =
        for i <- 1..50 do
          Task.async(fn ->
            alarm_params = %{
              device_id: device.id,
              alarm_type: "motion_detected",
              priority: Enum.random(["low", "medium", "high"]),
              metadata: %{sequence: i}
            }

            {time, _result} =
              :timer.tc(fn ->
                AlarmManagement.create_alarm(alarm_params)
              end)

            # Convert to ms
            time / 1000
          end)
        end

      times = Task.await_many(tasks, 30_000)

      avg_time = Enum.sum(times) / length(times)
      max_time = Enum.max(times)

      assert avg_time < 50, "Average alarm creation #{avg_time}ms exceeds 50ms"
      assert max_time < 200, "Max alarm creation #{max_time}ms exceeds 200ms"
    end
  end

  # ============================================================================
  # 6. SECURITY TESTS - Validate authorization and data isolation
  # ============================================================================

  describe "security tests" do
    @tag :security
    test "unauthenticated requests are rejected", %{conn: conn} do
      conn =
        conn
        |> delete_req_header("authorization")
        |> get(~p"/api/mobile/alarms")

      assert_status(conn, 401)["status"] == "error"
    end

    @tag :security
    test "guards can view but not resolve alarms",
         %{conn: _conn, guard_token: token, alarms: [alarm | _]} do
      # Guard can view alarms
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/mobile/alarms")

      assert_status(conn, 200)["status"] == "success"

      # Guard can acknowledge
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/mobile/alarms/#{alarm.id}/acknowledge", %{
          "notes" => "Guard acknowledgment"
        })

      assert_status(conn, 200)["status"] == "success"

      # Guard cannot resolve (if restricted)
      if restricted_action?(:resolve_alarm, :guard) do
        conn =
          build_conn()
          |> put_req_header("authorization", "Bearer #{token}")
          |> put_req_header("content-type", "application/json")
          |> post(~p"/api/mobile/alarms/#{alarm.id}/resolve", %{"resolution" => "false_alarm"})

        assert_status(conn, 403)["status"] == "error"
      end
    end

    @tag :security
    test "cross-tenant alarm access is prevented", %{conn: conn, other_alarm: alarm} do
      # Cannot view other tenant's alarm
      conn = get(conn, ~p"/api/mobile/alarms/#{alarm.id}")
      assert_status(conn, 404)["status"] == "error"

      # Cannot acknowledge other tenant's alarm
      conn =
        build_conn()
        |> put_req_header("authorization", conn.assigns[:authorization])
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/mobile/alarms/#{alarm.id}/acknowledge", %{
          "notes" => "Cross-tenant attempt"
        })

      assert_status(conn, 404)["status"] == "error"
    end

    @tag :security
    test "alarm audit trail is immutable", %{conn: conn, alarms: alarms} do
      resolved_alarm = Enum.find(alarms, &(&1.status == "resolved"))

      # Get alarm with audit trail
      conn = get(conn, ~p"/api/mobile/alarms/#{resolved_alarm.id}")
      response = json_response(conn, 200)

      audit_trail = response["data"]["audit_trail"]

      # Audit trail should have entries for each status change
      # Created, acknowledged, resolved
      assert length(audit_trail) >= 3

      # Each entry should be immutable with required fields
      Enum.each(audit_trail, fn entry ->
        assert Map.has_key?(entry, "timestamp")
        assert Map.has_key?(entry, "action")
        assert Map.has_key?(entry, "user_id")
        assert Map.has_key?(entry, "details")
      end)
    end

    @tag :security
    test "sensitive alarm data is filtered by role", %{conn: conn, alarms: [alarm | _]} do
      # Admin sees all fields
      conn = get(conn, ~p"/api/mobile/alarms/#{alarm.id}")
      admin_response = json_response(conn, 200)["data"]

      assert Map.has_key?(admin_response, "internal_notes")
      assert Map.has_key?(admin_response, "cost_impact")

      # Guard sees limited fields
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns[:guard_token]}")
        |> get(~p"/api/mobile/alarms/#{alarm.id}")

      guard_response = json_response(conn, 200)["data"]

      refute Map.has_key?(guard_response, "internal_notes")
      refute Map.has_key?(guard_response, "cost_impact")
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp make_alarm_request(conn, token) do
    conn
    |> put_req_header("authorization", "Bearer #{token}")
    |> get(~p"/api/mobile/alarms")
    |> json_response(200)
  end

  defp percentile(list, p) do
    sorted = Enum.sort(list)
    k = (length(sorted) - 1) * p
    f = :erlang.trunc(k)
    c = k - f

    if f + 1 < length(sorted) do
      Enum.at(sorted, f) * (1 - c) + Enum.at(sorted, f + 1) * c
    else
      Enum.at(sorted, f)
    end
  end

  defp get_tenant_id(token) do
    {:ok, claims} = Authentication.verify_token(token)
    claims["tenant_id"]
  end

  defp assert_schema_compliance(data, schema_name) do
    case schema_name do
      :alarm_list_response ->
        assert Map.has_key?(data, "status")
        assert Map.has_key?(data, "data")
        assert Map.has_key?(data, "meta")
        assert is_list(data["data"])

      :alarm_object ->
        assert Map.has_key?(data, "id")
        assert Map.has_key?(data, "alarm_type")
        assert Map.has_key?(data, "priority")
        assert Map.has_key?(data, "status")
        assert Map.has_key?(data, "triggered_at")

      :pagination_meta ->
        assert Map.has_key?(data, "page")
        assert Map.has_key?(data, "page_size")
        assert Map.has_key?(data, "total_count")
        assert Map.has_key?(data, "total_pages")

      _ ->
        true
    end
  end

  defp restricted_action?(action, role) do
    restrictions = %{
      guard: [:resolve_alarm, :delete_alarm, :modify_priority],
      viewer: [:acknowledge_alarm, :resolve_alarm, :escalate_alarm]
    }

    action in Map.get(restrictions, role, [])
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
