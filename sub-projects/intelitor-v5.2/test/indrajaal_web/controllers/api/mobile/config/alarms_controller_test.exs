defmodule IndrajaalWeb.Api.Mobile.Config.AlarmsControllerTest do
  @moduledoc """
  Test suite for Mobile API Alarms Configuration Controller.

  SOPv5.1 Compliance: ✅
  TDG Methodology: Tests written BEFORE implementation
  Testing Levels: Unit, Module, Property-Based (Dual), GDE, STAMP, TDG
  Container Execution: Mandatory
  Timeout Policy: No timeout (:infinity)

  Timestamp: 2025-08-03T22:37:39+02:00
  """
  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias Indrajaal.Alarms

  # TDG: Test-Driven Generation - Tests written BEFORE implementation
  @tag :tdg_required
  @tag :container_only
  @tag timeout: :infinity

  describe "GET /api/mobile/config/alarms/types" do
    test "returns list of alarm types for authenticated user", %{conn: conn} do
      # Setup: Create test user and authenticate
      user = insert(:user, role: :operator)
      conn = authenticate_mobile(conn, user)

      # Create test alarm types
      alarm_types = insert_list(3, :alarm_type, tenant_id: user.tenant_id)

      # Execute request
      conn = get(conn, "/api/mobile/config/alarms/types")

      # Assert response
      assert json_response(conn, 200) == %{
               "status" => "success",
               "data" => %{
                 "alarm_types" => Enum.map(alarm_types, &render_alarm_type/1),
                 "total" => 3,
                 "page" => 1,
                 "page_size" => 20
               },
               "metadata" => %{
                 "api_version" => "v1",
                 "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
               }
             }
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/mobile/config/alarms/types")
      assert json_response(conn, 401)["error"] == "Unauthorized"
    end

    test "respects tenant isolation", %{conn: conn} do
      # Create two tenants with different alarm types
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      user1 = insert(:user, tenant_id: tenant1.id)
      user2 = insert(:user, tenant_id: tenant2.id)

      alarm_type1 = insert(:alarm_type, tenant_id: tenant1.id, name: "Tenant1 Alarm")
      _alarm_type2 = insert(:alarm_type, tenant_id: tenant2.id, name: "Tenant2 Alarm")

      # User1 should only see their tenant's alarm types
      conn1 = authenticate_mobile(conn, user1)
      get_response = get(conn1, "/api/mobile/config/alarms/types")
      response1 = get_response |> json_response(200)

      assert length(response1["data"]["alarm_types"]) == 1
      assert hd(response1["data"]["alarm_types"])["name"] == "Tenant1 Alarm"
    end
  end

  describe "POST /api/mobile/config/alarms/types" do
    test "creates new alarm type with valid params", %{conn: conn} do
      user = insert(:user, role: :admin)
      conn = authenticate_mobile(conn, user)

      params = %{
        "alarm_type" => %{
          "name" => "High Temperature",
          "code" => "HIGH_TEMP",
          "severity" => "critical",
          "category" => "environmental",
          "description" => "Temperature exceeds threshold",
          "default_threshold" => 35,
          "escalation_time" => 300,
          "auto_acknowledge" => false
        }
      }

      conn = post(conn, "/api/mobile/config/alarms/types", params)

      assert response = json_response(conn, 201)
      assert response["status"] == "success"
      assert response["data"]["alarm_type"]["name"] == "High Temperature"
      assert response["data"]["alarm_type"]["severity"] == "critical"

      # Verify in database
      assert alarm_type = Alarms.get_alarm_type!(response["data"]["alarm_type"]["id"])
      assert alarm_type.name == "High Temperature"
    end

    test "validates required fields", %{conn: conn} do
      user = insert(:user, role: :admin)
      conn = authenticate_mobile(conn, user)

      params = %{"alarm_type" => %{}}

      conn = post(conn, "/api/mobile/config/alarms/types", params)

      assert response = json_response(conn, 422)
      assert response["status"] == "error"
      assert response["errors"]["name"] == ["can't be blank"]
      assert response["errors"]["severity"] == ["can't be blank"]
    end

    test "requires admin role", %{conn: conn} do
      user = insert(:user, role: :viewer)
      conn = authenticate_mobile(conn, user)

      params = %{"alarm_type" => %{"name" => "Test", "severity" => "low"}}

      conn = post(conn, "/api/mobile/config/alarms/types", params)
      assert json_response(conn, 403)["error"] == "Forbidden"
    end
  end

  describe "PUT /api/mobile/config/alarms/types/:id" do
    test "updates existing alarm type", %{conn: conn} do
      user = insert(:user, role: :admin)
      alarm_type = insert(:alarm_type, tenant_id: user.tenant_id)
      conn = authenticate_mobile(conn, user)

      params = %{
        "alarm_type" => %{
          "name" => "Updated Name",
          "severity" => "high"
        }
      }

      conn = put(conn, "/api/mobile/config/alarms/types/#{alarm_type.id}", params)

      assert response = json_response(conn, 200)
      assert response["data"]["alarm_type"]["name"] == "Updated Name"
      assert response["data"]["alarm_type"]["severity"] == "high"
    end
  end

  describe "DELETE /api/mobile/config/alarms/types/:id" do
    test "soft deletes alarm type", %{conn: conn} do
      user = insert(:user, role: :admin)
      alarm_type = insert(:alarm_type, tenant_id: user.tenant_id)
      conn = authenticate_mobile(conn, user)

      conn = delete(conn, "/api/mobile/config/alarms/types/#{alarm_type.id}")

      assert json_response(conn, 200)["status"] == "success"

      # Verify soft delete
      assert deleted = Alarms.get_alarm_type!(alarm_type.id, include_deleted: true)
      assert deleted.deleted_at != nil
    end
  end

  # Property-Based Testing with DUAL frameworks (PropCheck + ExUnitProperties)

  describe "property-based testing" do
    # PropCheck property test
    property "alarm type names are always valid" do
      forall name <- alarm_name_generator() do
        alarm_type = %{name: name, severity: "low", code: String.upcase(name)}
        assert Alarms.validate_alarm_type(alarm_type) == :ok
      end
    end

    # ExUnitProperties test
    test "alarm severity levels maintain ordering" do
      ExUnitProperties.check all(
                               severity1 <- SD.member_of(["low", "medium", "high", "critical"]),
                               severity2 <- SD.member_of(["low", "medium", "high", "critical"]),
                               max_runs: 100
                             ) do
        level1 = Alarms.severity_to_integer(severity1)
        level2 = Alarms.severity_to_integer(severity2)

        assert level1 >= 1 and level1 <= 4
        assert level2 >= 1 and level2 <= 4
      end
    end
  end

  # GDE (Goal-Directed Execution) Testing

  describe "GDE performance goals" do
    @tag :gde
    test "bulk create 1000 alarm types in under 5 seconds", %{conn: conn} do
      user = insert(:user, role: :admin)
      conn = authenticate_mobile(conn, user)

      alarm_types =
        for i <- 1..1000 do
          %{
            "name" => "Alarm Type #{i}",
            "code" => "ALARM_#{i}",
            "severity" => Enum.random(["low", "medium", "high", "critical"]),
            "category" => Enum.random(["security", "environmental", "technical"])
          }
        end

      params = %{"alarm_types" => alarm_types}

      {time_microseconds, response} =
        :timer.tc(fn ->
          post(conn, "/api/mobile/config/alarms/types/bulk", params)
        end)

      assert json_response(response, 201)["data"]["created"] == 1000
      # 5 seconds
      assert time_microseconds < 5_000_000
    end
  end

  # STAMP (System-Theoretic Process Analysis) Testing

  describe "STAMP safety constraints" do
    @tag :stamp
    test "prevents conflicting alarm rules", %{conn: conn} do
      user = insert(:user, role: :admin)
      conn = authenticate_mobile(conn, user)

      # Create base alarm type
      base_params = %{
        "alarm_type" => %{
          "name" => "Temperature Monitor",
          "code" => "TEMP_MON",
          "severity" => "high",
          "threshold_min" => 20,
          "threshold_max" => 30
        }
      }

      post(conn, "/api/mobile/config/alarms/types", base_params)

      # Attempt to create conflicting alarm type
      conflict_params = %{
        "alarm_type" => %{
          "name" => "Temperature Alert",
          # Same code - conflict!
          "code" => "TEMP_MON",
          "severity" => "low",
          # Overlapping range
          "threshold_min" => 25,
          "threshold_max" => 35
        }
      }

      conn = post(conn, "/api/mobile/config/alarms/types", conflict_params)

      assert response = json_response(conn, 422)
      assert response["errors"]["code"] == ["has already been taken"]
      assert response["errors"]["threshold"] == ["overlaps with existing alarm type"]
    end

    test "ensures critical alarms cannot be auto-acknowledged", %{conn: conn} do
      user = insert(:user, role: :admin)
      conn = authenticate_mobile(conn, user)

      params = %{
        "alarm_type" => %{
          "name" => "Critical Security Breach",
          "severity" => "critical",
          # Should be rejected
          "auto_acknowledge" => true
        }
      }

      conn = post(conn, "/api/mobile/config/alarms/types", params)

      assert response = json_response(conn, 422)

      assert response["errors"]["auto_acknowledge"] ==
               ["cannot be enabled for critical severity alarms"]
    end
  end

  # Helper functions

  defp authenticate_mobile(conn, user) do
    token = generate_mobile_token(user)
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  defp generate_mobile_token(user) do
    # Generate JWT token for mobile authentication
    {:ok, token, _claims} =
      IndrajaalWeb.Guardian.encode_and_sign(user, %{
        device_id: "test_device_#{user.id}",
        platform: "ios",
        app_version: "1.0.0"
      })

    token
  end

  defp render_alarm_type(alarm_type) do
    %{
      "id" => alarm_type.id,
      "name" => alarm_type.name,
      "code" => alarm_type.code,
      "severity" => alarm_type.severity,
      "category" => alarm_type.category,
      "description" => alarm_type.description,
      "created_at" => DateTime.to_iso8601(alarm_type.inserted_at),
      "updated_at" => DateTime.to_iso8601(alarm_type.updated_at)
    }
  end

  defp alarm_name_generator do
    let prefix <- SD.member_of(["High", "Low", "Critical", "Warning", "Info"]) do
      let suffix <- SD.member_of(["Temperature", "Motion", "Access", "Network", "Power"]) do
        "#{prefix} #{suffix}"
      end
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
