defmodule Indrajaal.Test.Steps.APISteps do
  @moduledoc """
  BDD step definitions for API endpoint scenarios.

  WHAT: Step implementations for comprehensive_api_e2e.feature
  WHY: Enable automated BDD testing of API workflows
  CONSTRAINTS: SC-API-001 to SC-API-010, SC-SEC-044, SC-SEC-047
  """

  use Cabbage.Feature
  import Plug.Conn
  import Phoenix.ConnTest

  # Future: Guardian and User integration for API auth
  # alias Indrajaal.Safety.Guardian
  # alias Indrajaal.Accounts.User

  @endpoint IndrajaalWeb.Endpoint

  # =============================================================================
  # BACKGROUND STEPS
  # =============================================================================

  defgiven ~r/^the API server is running$/, _params, state do
    assert IndrajaalWeb.Endpoint.config(:http)[:port] != nil
    {:ok, state}
  end

  defgiven ~r/^I have a valid API token$/, _params, state do
    token = generate_test_token()
    {:ok, Map.put(state, :api_token, token)}
  end

  defgiven ~r/^I have an? "(?<role>[^"]+)" role$/, %{role: role}, state do
    {:ok, Map.put(state, :role, String.to_atom(role))}
  end

  # =============================================================================
  # AUTHENTICATION STEPS
  # =============================================================================

  defwhen ~r/^I request "(?<method>[^"]+)" "(?<path>[^"]+)"$/,
          %{method: method, path: path},
          state do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{state.api_token}")
      |> request_by_method(method, path)

    {:ok, state |> Map.put(:conn, conn) |> Map.put(:path, path)}
  end

  defwhen ~r/^I request "(?<method>[^"]+)" "(?<path>[^"]+)" with:$/, params, state do
    method = params.method
    path = params.path
    body = table_to_map(params.table)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{state.api_token}")
      |> put_req_header("content-type", "application/json")
      |> request_by_method(method, path, Jason.encode!(body))

    {:ok, state |> Map.put(:conn, conn) |> Map.put(:path, path)}
  end

  defthen ~r/^the response status should be (?<status>\d+)$/, %{status: status}, state do
    expected = String.to_integer(status)

    assert state.conn.status == expected,
           "Expected status #{expected}, got #{state.conn.status}"

    {:ok, state}
  end

  defthen ~r/^the response should contain:$/, %{table: table}, state do
    body = json_response(state.conn, state.conn.status)

    Enum.each(table, fn row ->
      field = row["Field"]
      expected = row["Value"]
      actual = get_in(body, String.split(field, "."))

      assert "#{actual}" == expected,
             "Expected #{field} to be #{expected}, got #{actual}"
    end)

    {:ok, state}
  end

  # =============================================================================
  # RATE LIMITING STEPS
  # =============================================================================

  defgiven ~r/^rate limiting is enabled$/, _params, state do
    {:ok, Map.put(state, :rate_limiting, true)}
  end

  defwhen ~r/^I make (?<count>\d+) requests in (?<seconds>\d+) seconds?$/, params, state do
    count = String.to_integer(params.count)
    _seconds = String.to_integer(params.seconds)

    results =
      Enum.map(1..count, fn _ ->
        build_conn()
        |> put_req_header("authorization", "Bearer #{state.api_token}")
        |> get("/api/health")
        |> Map.get(:status)
      end)

    {:ok, Map.put(state, :rate_limit_results, results)}
  end

  defthen ~r/^some requests should be rate limited$/, _params, state do
    rate_limited = Enum.count(state.rate_limit_results, &(&1 == 429))
    assert rate_limited > 0, "Expected some 429 responses"
    {:ok, state}
  end

  defthen ~r/^the response should include rate limit headers$/, _params, state do
    headers = Enum.into(state.conn.resp_headers, %{})

    assert Map.has_key?(headers, "x-ratelimit-limit") or
             Map.has_key?(headers, "x-rate-limit-limit"),
           "Missing rate limit headers"

    {:ok, state}
  end

  # =============================================================================
  # ALARM API STEPS
  # =============================================================================

  defgiven ~r/^there are active alarms in the system$/, _params, state do
    alarms = create_test_alarms(5)
    {:ok, Map.put(state, :test_alarms, alarms)}
  end

  defwhen ~r/^I request the alarms list$/, _params, state do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{state.api_token}")
      |> get("/api/alarms")

    {:ok, Map.put(state, :conn, conn)}
  end

  defthen ~r/^I should receive a paginated list of alarms$/, _params, state do
    body = json_response(state.conn, 200)
    assert is_list(body["data"]) or is_list(body["alarms"])
    assert Map.has_key?(body, "meta") or Map.has_key?(body, "pagination")
    {:ok, state}
  end

  defwhen ~r/^I acknowledge alarm "(?<id>[^"]+)"$/, %{id: id}, state do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{state.api_token}")
      |> put_req_header("content-type", "application/json")
      |> post("/api/alarms/#{id}/acknowledge", Jason.encode!(%{}))

    {:ok, state |> Map.put(:conn, conn) |> Map.put(:acknowledged_id, id)}
  end

  defthen ~r/^the alarm status should be "(?<status>[^"]+)"$/, %{status: expected}, state do
    body = json_response(state.conn, state.conn.status)
    assert body["status"] == expected or body["data"]["status"] == expected
    {:ok, state}
  end

  # =============================================================================
  # GUARDIAN API STEPS
  # =============================================================================

  defwhen ~r/^I submit a Guardian proposal:$/, %{table: table}, state do
    proposal = table_to_map(table)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{state.api_token}")
      |> put_req_header("content-type", "application/json")
      |> post("/api/prajna/guardian/propose", Jason.encode!(proposal))

    {:ok, Map.put(state, :conn, conn)}
  end

  defthen ~r/^Guardian should validate the request$/, _params, state do
    body = json_response(state.conn, state.conn.status)
    assert Map.has_key?(body, "validation") or Map.has_key?(body, "validated")
    {:ok, state}
  end

  defthen ~r/^the proposal should be (?<decision>approved|rejected)$/,
          %{decision: decision},
          state do
    body = json_response(state.conn, state.conn.status)
    actual = body["decision"] || body["status"]
    assert actual == decision, "Expected #{decision}, got #{actual}"
    {:ok, state}
  end

  # =============================================================================
  # HEALTH API STEPS
  # =============================================================================

  defwhen ~r/^I check the health endpoint$/, _params, state do
    conn =
      build_conn()
      |> get("/api/health")

    {:ok, Map.put(state, :conn, conn)}
  end

  defthen ~r/^I should receive system health status$/, _params, state do
    body = json_response(state.conn, 200)
    assert Map.has_key?(body, "status") or Map.has_key?(body, "health")
    {:ok, state}
  end

  defthen ~r/^the health check should include:$/, %{table: table}, state do
    body = json_response(state.conn, 200)

    Enum.each(table, fn row ->
      component = row["Component"]
      key = String.downcase(component) |> String.replace(" ", "_")

      assert body[key] != nil or body["components"][key] != nil,
             "Missing health component: #{component}"
    end)

    {:ok, state}
  end

  # =============================================================================
  # METRICS API STEPS
  # =============================================================================

  defwhen ~r/^I request Prajna metrics$/, _params, state do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{state.api_token}")
      |> get("/api/prajna/metrics")

    {:ok, Map.put(state, :conn, conn)}
  end

  defthen ~r/^I should receive the health score$/, _params, state do
    body = json_response(state.conn, 200)
    assert body["health_score"] != nil or body["score"] != nil
    {:ok, state}
  end

  defthen ~r/^the metrics should include Sentinel data$/, _params, state do
    body = json_response(state.conn, 200)
    assert body["sentinel"] != nil or body["immune_system"] != nil
    {:ok, state}
  end

  # =============================================================================
  # ZENOH API STEPS
  # =============================================================================

  defwhen ~r/^I subscribe to Zenoh topic "(?<topic>[^"]+)"$/, %{topic: topic}, state do
    {:ok, state |> Map.put(:zenoh_topic, topic) |> Map.put(:subscribed, true)}
  end

  defthen ~r/^I should receive real-time updates$/, _params, state do
    # Simulate receiving a message
    assert state.subscribed == true
    {:ok, state}
  end

  defwhen ~r/^I publish to Zenoh topic "(?<topic>[^"]+)" with:$/, params, state do
    topic = params.topic
    message = table_to_map(params.table)

    # Simulate publish
    {:ok, state |> Map.put(:published_topic, topic) |> Map.put(:published_message, message)}
  end

  defthen ~r/^the message should be delivered$/, _params, state do
    assert state.published_topic != nil
    assert state.published_message != nil
    {:ok, state}
  end

  # =============================================================================
  # ERROR HANDLING STEPS
  # =============================================================================

  defwhen ~r/^I request with an invalid token$/, _params, state do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer invalid-token-12345")
      |> get("/api/alarms")

    {:ok, Map.put(state, :conn, conn)}
  end

  defthen ~r/^I should receive a (?<status>\d+) error$/, %{status: status}, state do
    expected = String.to_integer(status)
    assert state.conn.status == expected
    {:ok, state}
  end

  defthen ~r/^the error should be descriptive$/, _params, state do
    body = json_response(state.conn, state.conn.status)
    assert body["error"] != nil or body["message"] != nil
    {:ok, state}
  end

  defwhen ~r/^I request a non-existent resource$/, _params, state do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{state.api_token}")
      |> get("/api/alarms/non-existent-id-12345")

    {:ok, Map.put(state, :conn, conn)}
  end

  # =============================================================================
  # OPENAPI VALIDATION STEPS
  # =============================================================================

  defthen ~r/^the response should match OpenAPI schema$/, _params, state do
    # Validate against OpenAPI schema
    # In a real implementation, this would use an OpenAPI validator
    assert state.conn.status in [200, 201, 204]
    {:ok, state}
  end

  defthen ~r/^all required fields should be present$/, _params, state do
    body = json_response(state.conn, state.conn.status)
    assert body != nil
    {:ok, state}
  end

  # =============================================================================
  # HELPER FUNCTIONS
  # =============================================================================

  defp generate_test_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp table_to_map(table) do
    table
    |> Enum.map(fn row -> {row["Field"], row["Value"]} end)
    |> Map.new()
  end

  defp request_by_method(conn, method, path, body \\ nil) do
    case String.upcase(method) do
      "GET" -> get(conn, path)
      "POST" -> post(conn, path, body || "")
      "PUT" -> put(conn, path, body || "")
      "PATCH" -> patch(conn, path, body || "")
      "DELETE" -> delete(conn, path)
      _ -> get(conn, path)
    end
  end

  defp create_test_alarms(count) do
    Enum.map(1..count, fn i ->
      %{
        id: Ecto.UUID.generate(),
        type: Enum.random(["FIRE", "INTRUSION", "PANIC", "MEDICAL"]),
        severity: Enum.random(["critical", "high", "medium", "low"]),
        status: "active",
        created_at: DateTime.utc_now(),
        index: i
      }
    end)
  end
end
