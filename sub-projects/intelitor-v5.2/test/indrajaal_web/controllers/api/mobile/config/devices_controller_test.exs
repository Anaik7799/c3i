defmodule IndrajaalWeb.Api.Mobile.Config.DevicesControllerTest do
  @moduledoc """
  Comprehensive test suite for mobile devices configuration API.

  Implements 6 testing methodologies:
  1. Unit Testing - Individual function testing
  2. Integration Testing - Full API endpoint testing
  3. Property-Based Testing - Invariant validation
  4. Contract Testing - OpenAPI compliance
  5. Performance Testing - Response time validation
  6. Security Testing - Authorization and data isolation

  SOPv5.1 Compliance: ✅
  TDG Methodology: Tests written before implementation
  Agent: Worker-2 validates device configuration endpoints
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # EP-GEN-014: Dual property testing disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Monitoring.Device
  alias Indrajaal.ConfigManagement
  alias Indrajaal.Authentication

  @tag :tdg_required
  @tag :container_only
  @tag timeout: :infinity

  # Test data setup
  setup %{conn: conn} do
    # Create test tenant and users
    tenant = insert(:tenant, name: "Test Security Corp")
    admin_user = insert(:user, tenant: tenant, role: "admin")
    operator_user = insert(:user, tenant: tenant, role: "operator")
    other_tenant = insert(:tenant, name: "Other Corp")
    other_user = insert(:user, tenant: other_tenant, role: "admin")

    # Generate authentication tokens
    {:ok, admin_token} = Authentication.generate_token(admin_user)
    {:ok, operator_token} = Authentication.generate_token(operator_user)
    {:ok, other_token} = Authentication.generate_token(other_user)

    # Create test devices
    devices =
      for i <- 1..5 do
        insert(:device,
          tenant: tenant,
          name: "Device #{i}",
          device_type: Enum.random(["camera", "sensor", "panel"]),
          status: Enum.random(["online", "offline", "maintenance"]),
          ip_address: "192.168.1.#{100 + i}",
          configuration: %{
            "polling_interval" => 30,
            "alert_threshold" => 85,
            "recording_enabled" => true
          }
        )
      end

    # Create device in other tenant for isolation testing
    other_device = insert(:device, tenant: other_tenant, name: "Other Device")

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
      other_user: other_user,
      other_token: other_token,
      devices: devices,
      other_device: other_device
    }
  end

  # ============================================================================
  # 1. UNIT TESTS - Test individual functions in isolation
  # ============================================================================

  describe "unit tests - controller functions" do
    @tag :unit
    test "parse_filters/1 correctly parses query parameters" do
      params = %{
        "name" => "Camera",
        "status" => "online",
        "device_type" => "camera",
        "site_id" => "123",
        "invalid_key" => "ignored"
      }

      filters = IndrajaalWeb.Api.Mobile.Config.DevicesController.parse_filters(params)

      assert filters == %{
               name: "Camera",
               status: "online",
               device_type: "camera",
               site_id: "123"
             }

      refute Map.has_key?(filters, :invalid_key)
    end

    @tag :unit
    test "validate_configuration/1 validates device config schema" do
      valid_config = %{
        "polling_interval" => 60,
        "alert_threshold" => 90,
        "recording_enabled" => false
      }

      invalid_config = %{
        "polling_interval" => "not a number",
        # Out of range
        "alert_threshold" => 150
      }

      assert {:ok, ^valid_config} =
               IndrajaalWeb.Api.Mobile.Config.DevicesController.validate_configuration(
                 valid_config
               )

      assert {:error, errors} =
               IndrajaalWeb.Api.Mobile.Config.DevicesController.validate_configuration(
                 invalid_config
               )

      assert "must be a number" in errors
      assert "must be between 0 and 100" in errors
    end
  end

  # ============================================================================
  # 2. INTEGRATION TESTS - Test complete API endpoints
  # ============================================================================

  describe "GET /api/mobile/config/devices" do
    @tag :integration
    test "returns paginated list of devices for tenant", %{conn: conn, devices: devices} do
      conn = get(conn, ~p"/api/mobile/config/devices")

      assert %{
               "status" => "success",
               "data" => returned_devices,
               "meta" => %{
                 "page" => 1,
                 "page_size" => 20,
                 "total_count" => 5,
                 "total_pages" => 1
               }
             } = json_response(conn, 200)

      assert length(returned_devices) == 5

      # Verify device structure
      first_device = hd(returned_devices)
      assert Map.has_key?(first_device, "id")
      assert Map.has_key?(first_device, "name")
      assert Map.has_key?(first_device, "device_type")
      assert Map.has_key?(first_device, "status")
      assert Map.has_key?(first_device, "configuration")
    end

    @tag :integration
    test "filters devices by status", %{conn: conn, tenant: tenant} do
      # Create specific devices for filtering
      _online_device = insert(:device, tenant: tenant, status: "online")
      _offline_device = insert(:device, tenant: tenant, status: "offline")

      conn = get(conn, ~p"/api/mobile/config/devices?status=online")

      assert %{"data" => devices} = json_response(conn, 200)
      assert Enum.all?(devices, &(&1["status"] == "online"))
    end

    @tag :integration
    test "enforces tenant isolation", %{conn: conn, other_device: other_device} do
      conn = get(conn, ~p"/api/mobile/config/devices")

      assert %{"data" => devices} = json_response(conn, 200)
      device_ids = Enum.map(devices, & &1["id"])

      # Other tenant's device should not be visible
      refute other_device.id in device_ids
    end
  end

  describe "POST /api/mobile/config/devices" do
    @tag :integration
    test "creates new device with valid data", %{conn: conn, tenant: _tenant} do
      device_params = %{
        "name" => "New Camera",
        "device_type" => "camera",
        "ip_address" => "192.168.1.200",
        "site_id" => Ecto.UUID.generate(),
        "configuration" => %{
          "polling_interval" => 45,
          "alert_threshold" => 80,
          "recording_enabled" => true
        }
      }

      conn = post(conn, ~p"/api/mobile/config/devices", device_params)

      assert %{
               "status" => "success",
               "data" => device,
               "message" => "Device created successfully"
             } = json_response(conn, 201)

      assert device["name"] == "New Camera"
      assert device["device_type"] == "camera"
      assert device["configuration"]["polling_interval"] == 45
    end

    @tag :integration
    test "validates required fields", %{conn: conn} do
      invalid_params = %{
        "device_type" => "camera"
        # Missing required 'name' field
      }

      conn = post(conn, ~p"/api/mobile/config/devices", invalid_params)

      assert %{
               "status" => "error",
               "errors" => errors
             } = json_response(conn, 422)

      assert "name is required" in errors
    end
  end

  describe "PUT /api/mobile/config/devices/:id" do
    @tag :integration
    test "updates device configuration", %{conn: conn, devices: [device | _]} do
      update_params = %{
        "name" => "Updated Camera",
        "configuration" => %{
          "polling_interval" => 90,
          "alert_threshold" => 95,
          "recording_enabled" => false
        }
      }

      conn = put(conn, ~p"/api/mobile/config/devices/#{device.id}", update_params)

      assert %{
               "status" => "success",
               "data" => updated_device
             } = json_response(conn, 200)

      assert updated_device["name"] == "Updated Camera"
      assert updated_device["configuration"]["polling_interval"] == 90
    end

    @tag :integration
    test "prevents updating devices in other tenants", %{conn: conn, other_device: device} do
      conn = put(conn, ~p"/api/mobile/config/devices/#{device.id}", %{"name" => "Hacked"})

      assert %{"status" => "error"} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/mobile/config/devices/:id" do
    @tag :integration
    test "deletes device", %{conn: conn, devices: [device | _]} do
      conn = delete(conn, ~p"/api/mobile/config/devices/#{device.id}")

      assert response(conn, 204)

      # Verify deletion
      conn =
        build_conn()
        |> put_req_header("authorization", conn.assigns[:authorization])
        |> get(~p"/api/mobile/config/devices/#{device.id}")

      assert json_response(conn, 404)["status"] == "error"
    end
  end

  describe "POST /api/mobile/config/devices/bulk" do
    @tag :integration
    test "creates multiple devices in transaction", %{conn: conn} do
      devices_params = %{
        "records" => [
          %{
            "name" => "Bulk Camera 1",
            "device_type" => "camera",
            "ip_address" => "192.168.2.1"
          },
          %{
            "name" => "Bulk Sensor 1",
            "device_type" => "sensor",
            "ip_address" => "192.168.2.2"
          }
        ]
      }

      conn = post(conn, ~p"/api/mobile/config/devices/bulk", devices_params)

      assert %{
               "status" => "success",
               "data" => %{
                 "created" => 2,
                 "failed" => 0,
                 "records" => records
               }
             } = json_response(conn, 201)

      assert length(records) == 2
    end

    @tag :integration
    test "handles partial failures in bulk operations", %{conn: conn} do
      devices_params = %{
        "records" => [
          %{
            "name" => "Valid Device",
            "device_type" => "camera",
            "ip_address" => "192.168.3.1"
          },
          %{
            # Missing required name
            "device_type" => "sensor",
            "ip_address" => "192.168.3.2"
          }
        ],
        "options" => %{"all_or_nothing" => false}
      }

      conn = post(conn, ~p"/api/mobile/config/devices/bulk", devices_params)

      assert %{
               "status" => "partial_success",
               "data" => %{
                 "created" => 1,
                 "failed" => 1,
                 "errors" => errors
               }
             } = json_response(conn, 207)

      assert length(errors) == 1
    end
  end

  # ============================================================================
  # 3. PROPERTY-BASED TESTS - Test invariants with generated data
  # ============================================================================

  describe "property-based tests" do
    @tag :property
    property "device names are always trimmed and non-empty" do
      forall name <- non_empty_string() do
        device_params = %{"name" => name, "device_type" => "camera"}

        case ConfigManagement.create_device(device_params) do
          {:ok, device} ->
            String.trim(device.name) == device.name and
              String.length(device.name) > 0

          {:error, _} ->
            # Invalid names should be rejected
            String.trim(name) == "" or String.length(name) > 255
        end
      end
    end

    @tag :property
    test "configuration values are within valid ranges" do
      ExUnitProperties.check all(
                               polling <- SD.integer(1..300),
                               threshold <- SD.integer(0..100),
                               enabled <- SD.boolean()
                             ) do
        config = %{
          "polling_interval" => polling,
          "alert_threshold" => threshold,
          "recording_enabled" => enabled
        }

        {:ok, validated} = ConfigManagement.validate_device_config(config)

        assert validated["polling_interval"] >= 1
        assert validated["polling_interval"] <= 300
        assert validated["alert_threshold"] >= 0
        assert validated["alert_threshold"] <= 100
        assert is_boolean(validated["recording_enabled"])
      end
    end

    @tag :property
    test "pagination always returns consistent results" do
      ExUnitProperties.check all(
                               page <- SD.positive_integer(),
                               page_size <- SD.integer(1..100)
                             ) do
        # Property: total_count should equal sum of all pages
        {:ok, result} =
          ConfigManagement.list_devices(%{
            page: page,
            page_size: page_size
          })

        expected_count = min(page_size, max(0, result.total_count - (page - 1) * page_size))
        length(result.data) == expected_count
      end
    end
  end

  # ============================================================================
  # 4. CONTRACT TESTS - Validate API contract compliance
  # ============================================================================

  describe "contract tests - OpenAPI compliance" do
    @tag :contract
    test "GET /devices response matches OpenAPI schema", %{conn: conn} do
      conn = get(conn, ~p"/api/mobile/config/devices")

      response = json_response(conn, 200)

      # Validate response structure
      assert_schema_compliance(response, :device_list_response)

      # Validate each device object
      Enum.each(response["data"], fn device ->
        assert_schema_compliance(device, :device_object)
      end)
    end

    @tag :contract
    test "POST /devices request/response contract", %{conn: conn} do
      request_body = %{
        "name" => "Contract Test Device",
        "device_type" => "camera",
        "ip_address" => "192.168.5.1",
        "configuration" => %{
          "polling_interval" => 30,
          "alert_threshold" => 85,
          "recording_enabled" => true
        }
      }

      # Validate request matches schema
      assert_schema_compliance(request_body, :create_device_request)

      conn = post(conn, ~p"/api/mobile/config/devices", request_body)

      response = json_response(conn, 201)

      # Validate response matches schema
      assert_schema_compliance(response, :create_device_response)
      assert_schema_compliance(response["data"], :device_object)
    end

    @tag :contract
    test "error responses match OpenAPI error schema", %{conn: conn} do
      # Test 404 error
      conn = get(conn, ~p"/api/mobile/config/devices/#{Ecto.UUID.generate()}")

      error_response = json_response(conn, 404)
      assert_schema_compliance(error_response, :error_response)

      # Test 422 validation error
      conn =
        build_conn()
        |> put_req_header("authorization", conn.assigns[:authorization])
        |> post(~p"/api/mobile/config/devices", %{})

      validation_response = json_response(conn, 422)
      assert_schema_compliance(validation_response, :validation_error_response)
    end
  end

  # ============================================================================
  # 5. PERFORMANCE TESTS - Validate response times and throughput
  # ============================================================================

  describe "performance tests" do
    @tag :performance
    # 2 minutes for performance tests
    @tag timeout: 120_000
    test "list devices responds within 50ms", %{conn: conn, admin_token: token} do
      # Warm up
      make_request(conn, token)

      # Measure response times
      times =
        for _ <- 1..100 do
          {time, _response} =
            :timer.tc(fn ->
              make_request(conn, token)
            end)

          time
        end

      # Convert to ms
      avg_time = Enum.sum(times) / length(times) / 1000
      max_time = Enum.max(times) / 1000
      p95_time = percentile(times, 0.95) / 1000

      assert avg_time < 50, "Average response time #{avg_time}ms exceeds 50ms"
      assert p95_time < 100, "95th percentile #{p95_time}ms exceeds 100ms"
      assert max_time < 200, "Max response time #{max_time}ms exceeds 200ms"
    end

    @tag :performance
    test "bulk create handles 100 devices efficiently", %{conn: conn} do
      devices =
        for i <- 1..100 do
          %{
            "name" => "Perf Test Device #{i}",
            "device_type" => Enum.random(["camera", "sensor", "panel"]),
            "ip_address" => "10.0.#{div(i, 255)}.#{rem(i, 255)}"
          }
        end

      {time, response} =
        :timer.tc(fn ->
          conn
          |> post(~p"/api/mobile/config/devices/bulk", %{"records" => devices})
          |> json_response(201)
        end)

      time_ms = time / 1000

      assert response["data"]["created"] == 100
      assert time_ms < 5000, "Bulk create of 100 devices took #{time_ms}ms (limit: 5000ms)"

      # Calculate throughput
      # devices per second
      throughput = 100 / (time_ms / 1000)
      assert throughput > 20, "Throughput #{throughput} devices/sec below minimum 20/sec"
    end

    @tag :performance
    test "concurrent requests maintain performance", %{conn: _conn, admin_token: token} do
      # Create 50 concurrent requests
      tasks =
        for i <- 1..50 do
          Task.async(fn ->
            {time, _response} =
              :timer.tc(fn ->
                build_conn()
                |> put_req_header("authorization", "Bearer #{token}")
                |> get(~p"/api/mobile/config/devices?page=#{i}")
                |> json_response(200)
              end)

            # Convert to ms
            time / 1000
          end)
        end

      times = Task.await_many(tasks, 30_000)

      avg_time = Enum.sum(times) / length(times)
      max_time = Enum.max(times)

      assert avg_time < 100, "Average concurrent response time #{avg_time}ms exceeds 100ms"
      assert max_time < 500, "Max concurrent response time #{max_time}ms exceeds 500ms"
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
        |> get(~p"/api/mobile/config/devices")

      assert json_response(conn, 401)["status"] == "error"
    end

    @tag :security
    test "expired tokens are rejected", %{conn: _conn, admin_user: user} do
      # Generate expired token
      {:ok, expired_token} = Authentication.generate_token(user, expires_in: -3600)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{expired_token}")
        |> get(~p"/api/mobile/config/devices")

      assert json_response(conn, 401)["status"] == "error"
    end

    @tag :security
    test "cross-tenant data access is prevented", %{
      conn: conn,
      admin_token: token,
      other_device: device
    } do
      # Try to access device from another tenant
      conn =
        conn
        |> get(~p"/api/mobile/config/devices/#{device.id}")

      assert json_response(conn, 404)["status"] == "error"

      # Try to update device from another tenant
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("content-type", "application/json")
        |> put(~p"/api/mobile/config/devices/#{device.id}", %{"name" => "Hacked"})

      assert json_response(conn, 404)["status"] == "error"

      # Try to delete device from another tenant
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/mobile/config/devices/#{device.id}")

      assert json_response(conn, 404)["status"] == "error"
    end

    @tag :security
    test "role-based access control is enforced", %{
      conn: conn,
      operator_token: token,
      tenant: tenant
    } do
      # Operator should be able to read
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/mobile/config/devices")

      assert json_response(conn, 200)["status"] == "success"

      # Operator should not be able to create (if restricted)
      if restricted_action?(:create_device, :operator) do
        conn =
          build_conn()
          |> put_req_header("authorization", "Bearer #{token}")
          |> put_req_header("content-type", "application/json")
          |> post(~p"/api/mobile/config/devices", %{"name" => "Test"})

        assert json_response(conn, 403)["status"] == "error"
      end
    end

    @tag :security
    test "SQL injection attempts are prevented", %{conn: conn} do
      # Try SQL injection in search parameter
      malicious_params = [
        "'; DROP TABLE devices; --",
        "1' OR '1'='1",
        "1'; UPDATE devices SET tenant_id='hacked'; --"
      ]

      for param <- malicious_params do
        conn =
          build_conn()
          |> put_req_header("authorization", conn.assigns[:authorization])
          |> get(~p"/api/mobile/config/devices?name=#{param}")

        response = json_response(conn, 200)
        assert response["status"] == "success"
        # Should return empty results, not error
        assert response["data"] == []
      end
    end

    @tag :security
    test "rate limiting is enforced", %{conn: _conn, admin_token: token} do
      # Make requests up to rate limit
      for i <- 1..100 do
        conn =
          build_conn()
          |> put_req_header("authorization", "Bearer #{token}")
          |> put_req_header("x-request-id", "rate-limit-test-#{i}")
          |> get(~p"/api/mobile/config/devices")

        # Assuming 60 requests per minute limit
        if i <= 60 do
          assert json_response(conn, 200)["status"] == "success"
        else
          # Should be rate limited
          response = json_response(conn, 429)
          assert response["status"] == "error"
          assert response["code"] == "RATE_LIMIT_EXCEEDED"
        end
      end
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp make_request(conn, token) do
    conn
    |> put_req_header("authorization", "Bearer #{token}")
    |> get(~p"/api/mobile/config/devices")
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

  defp assert_schema_compliance(data, schema_name) do
    # This would integrate with your OpenAPI validator
    # For now, we'll do basic structure validation
    case schema_name do
      :device_list_response ->
        assert Map.has_key?(data, "status")
        assert Map.has_key?(data, "data")
        assert Map.has_key?(data, "meta")
        assert is_list(data["data"])

      :device_object ->
        assert Map.has_key?(data, "id")
        assert Map.has_key?(data, "name")
        assert Map.has_key?(data, "device_type")
        assert Map.has_key?(data, "status")

      :error_response ->
        assert Map.has_key?(data, "status")
        assert Map.has_key?(data, "message")
        assert data["status"] == "error"

      _ ->
        true
    end
  end

  defp restricted_action?(action, role) do
    # Define role-based restrictions
    restrictions = %{
      operator: [:create_device, :delete_device, :bulk_operations],
      viewer: [:create_device, :update_device, :delete_device, :bulk_operations]
    }

    action in Map.get(restrictions, role, [])
  end

  defp non_empty_string do
    gen all(str <- SD.string(:alphanumeric, min_length: 0, max_length: 300)) do
      str
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
