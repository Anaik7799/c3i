defmodule IndrajaalWeb.Api.PrajnaControllerTest do
  @moduledoc """
  TDG Test Suite for Prajna API Controller.

  Tests CEPAF-Prajna synchronization endpoints per SC-SYNC constraints.

  ## STAMP Compliance

  - SC-SYNC-001: Bridge timeout < 5s
  - SC-SYNC-005: All commands through Guardian
  - SC-SYNC-006: All state via Immutable Register
  - SC-SYNC-007: Proof token required for mutations
  - SC-SYNC-008: Constitutional check before reconfig

  ## TDG Requirements

  - Unit tests: 15 (happy path + error cases)
  - Property tests: 8 (input validation + response structure)
  - Integration tests: 5 (end-to-end flows)
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  # Use ExUnitProperties.check for StreamData property tests

  @moduletag :prajna_api

  # ============================================================
  # UNIT TESTS - SENTINEL HEALTH
  # ============================================================

  describe "GET /api/v1/prajna/sentinel/health" do
    test "returns health status", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/sentinel/health")

      assert json_response(conn, 200)["success"] == true
      assert response = json_response(conn, 200)["data"]
      assert is_number(response["health_score"])
      assert is_binary(response["status"])
      assert is_list(response["active_threats"])
    end

    test "includes request_id and timestamp", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/sentinel/health")

      response = json_response(conn, 200)
      assert is_binary(response["request_id"])
      assert is_binary(response["timestamp"])
    end
  end

  # ============================================================
  # UNIT TESTS - GUARDIAN INTEGRATION (SC-PRAJNA-001)
  # ============================================================

  describe "POST /api/v1/prajna/guardian/submit" do
    test "submits command proposal successfully", %{conn: conn} do
      params = %{
        "command_type" => "user_command",
        "target_module" => "Indrajaal.TestModule",
        "payload" => %{"key" => "value"},
        "justification" => "Test command execution",
        "urgency" => "normal"
      }

      conn = post(conn, ~p"/api/v1/prajna/guardian/submit", params)

      response = json_response(conn, 200)
      assert response["success"] == true
      assert response["data"]["status"] in ["approved", "vetoed", "pending"]
    end

    test "handles missing required fields", %{conn: conn} do
      params = %{"command_type" => "user_command"}

      conn = post(conn, ~p"/api/v1/prajna/guardian/submit", params)

      # Should still succeed with defaults
      assert json_response(conn, 200)["success"] == true
    end
  end

  # ============================================================
  # UNIT TESTS - FOUNDER DIRECTIVE (SC-PRAJNA-002)
  # ============================================================

  describe "POST /api/v1/prajna/founder/validate" do
    test "validates recommendation against Three Goals", %{conn: conn} do
      params = %{
        "action" => "resource_acquisition",
        "resource_impact" => 1.5,
        "founder_benefit" => "Increases revenue",
        "description" => "Deploy new service"
      }

      conn = post(conn, ~p"/api/v1/prajna/founder/validate", params)

      response = json_response(conn, 200)
      assert response["success"] == true
      data = response["data"]
      assert is_boolean(data["is_valid"])
      assert is_number(data["alignment_score"])
      assert is_number(data["goal1_alignment"])
      assert is_number(data["goal2_alignment"])
      assert is_number(data["goal3_alignment"])
      assert is_list(data["violations"])
    end
  end

  # ============================================================
  # UNIT TESTS - IMMUTABLE REGISTER (SC-PRAJNA-003)
  # ============================================================

  describe "POST /api/v1/prajna/register/record" do
    test "records state change to register", %{conn: conn} do
      params = %{
        "module" => "Indrajaal.TestModule",
        "operation" => "update",
        "old_value" => "old",
        "new_value" => "new",
        "reason" => "Test state change"
      }

      conn = post(conn, ~p"/api/v1/prajna/register/record", params)

      response = json_response(conn, 200)
      assert response["success"] == true
      data = response["data"]
      assert is_integer(data["block_number"])
      assert is_binary(data["hash"])
      assert is_binary(data["timestamp"])
    end
  end

  # ============================================================
  # UNIT TESTS - PROOF TOKEN (SC-SYNC-007)
  # ============================================================

  describe "POST /api/v1/prajna/prometheus/token" do
    test "generates proof token for mutations", %{conn: conn} do
      params = %{
        "scope" => ["state:write", "config:update"],
        "reason" => "Configuration update",
        "expiration_minutes" => 15
      }

      conn = post(conn, ~p"/api/v1/prajna/prometheus/token", params)

      response = json_response(conn, 200)
      assert response["success"] == true
      data = response["data"]
      assert String.starts_with?(data["token"], "prom_")
      assert is_binary(data["expires_at"])
      assert is_list(data["scope"])
    end

    test "uses default expiration when not provided", %{conn: conn} do
      params = %{
        "scope" => ["read"],
        "reason" => "Test"
      }

      conn = post(conn, ~p"/api/v1/prajna/prometheus/token", params)

      assert json_response(conn, 200)["success"] == true
    end
  end

  # ============================================================
  # UNIT TESTS - CONSTITUTIONAL CHECK (SC-SYNC-008)
  # ============================================================

  describe "POST /api/v1/prajna/constitutional/check" do
    test "validates constitutional invariants", %{conn: conn} do
      params = %{
        "target_layer" => "L3",
        "change_description" => "Update caching strategy",
        "survival_pressure" => "Performance degradation",
        "expected_benefits" => ["Faster response", "Lower memory"]
      }

      conn = post(conn, ~p"/api/v1/prajna/constitutional/check", params)

      response = json_response(conn, 200)
      assert response["success"] == true
      data = response["data"]
      assert is_boolean(data["psi0_existence"])
      assert is_boolean(data["psi1_regeneration"])
      assert is_boolean(data["psi2_evolution"])
      assert is_boolean(data["psi3_verification"])
      assert is_boolean(data["psi4_human_alignment"])
      assert is_boolean(data["psi5_truthfulness"])
      assert is_boolean(data["all_passed"])
      assert is_list(data["violations"])
    end

    test "detects existence violation", %{conn: conn} do
      params = %{
        "target_layer" => "L1",
        "change_description" => "Terminate the system completely"
      }

      conn = post(conn, ~p"/api/v1/prajna/constitutional/check", params)

      data = json_response(conn, 200)["data"]
      assert data["psi0_existence"] == false
      assert data["all_passed"] == false
    end

    test "detects founder alignment violation", %{conn: conn} do
      params = %{
        "target_layer" => "L2",
        "change_description" => "Action against founder interests"
      }

      conn = post(conn, ~p"/api/v1/prajna/constitutional/check", params)

      data = json_response(conn, 200)["data"]
      assert data["psi4_human_alignment"] == false
    end
  end

  # ============================================================
  # UNIT TESTS - ZENOH INTEGRATION (SC-SYNC-009)
  # ============================================================

  describe "POST /api/v1/prajna/zenoh/subscribe" do
    test "creates subscription successfully", %{conn: conn} do
      params = %{
        "topic" => "prajna/metrics/**",
        "callback_url" => nil
      }

      conn = post(conn, ~p"/api/v1/prajna/zenoh/subscribe", params)

      response = json_response(conn, 200)
      assert response["success"] == true
      assert String.starts_with?(response["data"]["subscription_id"], "sub_")
    end
  end

  describe "POST /api/v1/prajna/zenoh/publish" do
    test "publishes message successfully", %{conn: conn} do
      params = %{
        "topic" => "prajna/events/test",
        "payload" => %{"event" => "test", "timestamp" => DateTime.utc_now()}
      }

      conn = post(conn, ~p"/api/v1/prajna/zenoh/publish", params)

      assert json_response(conn, 200)["success"] == true
    end
  end

  # ============================================================
  # PROPERTY TESTS (PropCheck + StreamData)
  # ============================================================

  describe "property tests" do
    property "guardian submit accepts any command_type" do
      forall cmd_type <-
               PC.oneof([
                 PC.return("user_command"),
                 PC.return("reconfiguration"),
                 PC.return("data_mutation"),
                 PC.return("system_action"),
                 PC.return("ai_suggestion")
               ]) do
        params = %{
          "command_type" => cmd_type,
          "target_module" => "TestModule",
          "justification" => "Test"
        }

        conn = build_conn()
        conn = post(conn, "/api/v1/prajna/guardian/submit", params)

        response = json_response(conn, 200)
        response["success"] == true
      end
    end

    # ExUnitProperties tests - using test blocks with check all
    test "founder validate handles any resource_impact (property)" do
      ExUnitProperties.check all(impact <- SD.float(min: -100.0, max: 100.0)) do
        params = %{
          "action" => "test",
          "resource_impact" => impact,
          "founder_benefit" => "Test",
          "description" => "Test"
        }

        conn = build_conn()
        conn = post(conn, "/api/v1/prajna/founder/validate", params)

        response = json_response(conn, 200)
        assert response["success"] == true
      end
    end

    test "proof token scope accepts list of strings (property)" do
      ExUnitProperties.check all(
                               scope <-
                                 SD.list_of(SD.string(:alphanumeric, min_length: 1),
                                   min_length: 0,
                                   max_length: 5
                                 )
                             ) do
        params = %{
          "scope" => scope,
          "reason" => "Test"
        }

        conn = build_conn()
        conn = post(conn, "/api/v1/prajna/prometheus/token", params)

        response = json_response(conn, 200)
        assert response["success"] == true
        assert response["data"]["scope"] == scope
      end
    end

    test "constitutional check accepts any layer L1-L7 (property)" do
      ExUnitProperties.check all(
                               layer <- SD.member_of(["L1", "L2", "L3", "L4", "L5", "L6", "L7"])
                             ) do
        params = %{
          "target_layer" => layer,
          "change_description" => "Test change"
        }

        conn = build_conn()
        conn = post(conn, "/api/v1/prajna/constitutional/check", params)

        response = json_response(conn, 200)
        assert response["success"] == true
      end
    end
  end
end
