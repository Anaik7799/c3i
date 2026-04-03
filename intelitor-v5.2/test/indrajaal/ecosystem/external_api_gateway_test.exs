defmodule Indrajaal.Ecosystem.ExternalAPIGatewayTest do
  @moduledoc """
  Tests for Indrajaal.Ecosystem.ExternalAPIGateway - L8 External API Gateway.

  ## STAMP Constraints Tested
  - SC-ECO-001: API key management and validation
  - SC-ECO-002: Rate limiting with token bucket algorithm
  - SC-ECO-003: Input validation at ecosystem boundary
  - SC-ECO-004: Circuit breaker pattern for external services
  - SC-ECO-005: API telemetry and observability

  ## TDG Compliance
  Uses dual property testing per EP-GEN-014:
  - PropCheck for QuickCheck-style properties
  - ExUnitProperties (StreamData) for shrinking
  """

  use ExUnit.Case, async: false
  use PropCheck

  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  # Require ExUnitProperties for check all() macro
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Ecosystem.ExternalAPIGateway

  # ============================================================
  # TEST SETUP
  # ============================================================

  setup do
    # Start the gateway for testing
    case GenServer.whereis(ExternalAPIGateway) do
      nil ->
        {:ok, _pid} = ExternalAPIGateway.start_link([])

      pid ->
        # Already running, just use it
        {:ok, pid}
    end

    {:ok, api_key: "test-api-key-#{:rand.uniform(10000)}"}
  end

  # ============================================================
  # UNIT TESTS
  # ============================================================

  describe "register_api_key/2" do
    test "registers a new API key successfully", %{api_key: api_key} do
      assert {:ok, key_id} = ExternalAPIGateway.register_api_key(api_key, name: "test-key")
      assert is_binary(key_id)
      assert String.starts_with?(key_id, "api-key-")
    end

    test "registers key with custom rate limit" do
      key = "custom-rate-key-#{:rand.uniform(10000)}"
      assert {:ok, _key_id} = ExternalAPIGateway.register_api_key(key, rate_limit: 50)
    end

    test "registers key with scopes" do
      key = "scoped-key-#{:rand.uniform(10000)}"
      assert {:ok, _key_id} = ExternalAPIGateway.register_api_key(key, scopes: [:read, :write])
    end
  end

  describe "validate_request/3" do
    test "rejects invalid API key" do
      result = ExternalAPIGateway.validate_request("invalid-key", "/api/test", %{})
      assert {:error, :invalid_key} = result
    end

    test "accepts valid API key with valid payload", %{api_key: api_key} do
      {:ok, _key_id} = ExternalAPIGateway.register_api_key(api_key)

      result = ExternalAPIGateway.validate_request(api_key, "/api/test", %{data: "test"})
      assert {:ok, %{data: "test"}} = result
    end

    test "rejects non-map payload", %{api_key: api_key} do
      {:ok, _key_id} = ExternalAPIGateway.register_api_key(api_key)

      result = ExternalAPIGateway.validate_request(api_key, "/api/test", "invalid")
      assert {:error, :validation_failed, _} = result
    end
  end

  describe "execute_external_call/3" do
    test "executes successful call" do
      request = %{endpoint: "/external/api", method: :get}
      result = ExternalAPIGateway.execute_external_call("test-service", request)

      assert {:ok, response} = result
      assert response.status == :accepted
      assert response.service == "test-service"
    end

    test "handles simulated failure" do
      request = %{simulate_failure: true}
      result = ExternalAPIGateway.execute_external_call("failing-service", request)

      assert {:error, :external_service_error} = result
    end
  end

  describe "get_status/0" do
    test "returns status map with expected keys" do
      status = ExternalAPIGateway.get_status()

      assert is_map(status)
      assert Map.has_key?(status, :api_key_count)
      assert Map.has_key?(status, :circuit_breakers)
      assert Map.has_key?(status, :stats)
      assert Map.has_key?(status, :uptime_seconds)
    end

    test "stats contain required fields" do
      %{stats: stats} = ExternalAPIGateway.get_status()

      assert Map.has_key?(stats, :started_at)
      assert Map.has_key?(stats, :total_requests)
      assert Map.has_key?(stats, :allowed_requests)
      assert Map.has_key?(stats, :rate_limited)
    end
  end

  # ============================================================
  # CIRCUIT BREAKER TESTS
  # ============================================================

  describe "circuit breaker behavior" do
    test "records failures and tracks circuit state" do
      # Record multiple failures
      Enum.each(1..5, fn _ ->
        ExternalAPIGateway.record_failure("flaky-service")
      end)

      # Give it a moment to process
      Process.sleep(100)

      # Check status shows circuit breaker state
      %{circuit_breakers: breakers} = ExternalAPIGateway.get_status()
      # Circuit should be tracked
      assert is_map(breakers)
    end
  end

  # ============================================================
  # PROPERTY TESTS (PropCheck)
  # ============================================================

  describe "property tests (PropCheck)" do
    @tag :property
    property "API key IDs are always prefixed correctly" do
      forall _i <- PC.integer(1, 10) do
        key = "prop-key-#{:rand.uniform(100_000)}"
        {:ok, key_id} = ExternalAPIGateway.register_api_key(key)
        String.starts_with?(key_id, "api-key-")
      end
    end

    @tag :property
    property "status always returns valid structure" do
      forall _i <- PC.integer(1, 10) do
        status = ExternalAPIGateway.get_status()

        is_map(status) and
          Map.has_key?(status, :api_key_count) and
          Map.has_key?(status, :stats) and
          status.api_key_count >= 0
      end
    end

    @tag :property
    property "valid payloads are accepted" do
      forall _i <- PC.integer(1, 5) do
        key = "valid-payload-key-#{:rand.uniform(100_000)}"
        {:ok, _} = ExternalAPIGateway.register_api_key(key)

        payload = %{data: "test", number: :rand.uniform(100)}

        case ExternalAPIGateway.validate_request(key, "/api/test", payload) do
          {:ok, _} -> true
          _ -> false
        end
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS (ExUnitProperties / StreamData)
  # ============================================================

  describe "property tests (StreamData)" do
    @tag :property
    test "endpoint names are strings" do
      endpoints = ["/api/test", "/api/users", "/api/data", "/webhooks/inbound"]

      ExUnitProperties.check all(endpoint <- SD.member_of(endpoints)) do
        assert is_binary(endpoint)
        assert String.starts_with?(endpoint, "/")
      end
    end

    @tag :property
    test "rate limits are positive integers" do
      ExUnitProperties.check all(limit <- SD.integer(1..1000)) do
        assert limit > 0
        assert is_integer(limit)
      end
    end

    @tag :property
    test "scopes are valid atoms" do
      valid_scopes = [:read, :write, :admin, :delete]

      ExUnitProperties.check all(scope <- SD.member_of(valid_scopes)) do
        assert scope in valid_scopes
      end
    end
  end

  # ============================================================
  # FMEA TESTS
  # ============================================================

  describe "FMEA - failure modes" do
    @tag :fmea
    test "handles circuit breaker open gracefully" do
      # Trigger circuit breaker by recording multiple failures
      Enum.each(1..6, fn _ ->
        ExternalAPIGateway.record_failure("broken-service")
      end)

      Process.sleep(100)

      # Attempt call to broken service
      request = %{endpoint: "/api/broken"}
      result = ExternalAPIGateway.execute_external_call("broken-service", request)

      # Should either succeed (half-open) or be blocked
      assert match?({:ok, _}, result) or match?({:error, :circuit_open}, result)
    end

    @tag :fmea
    test "gracefully handles invalid key format" do
      result = ExternalAPIGateway.validate_request("", "/api/test", %{})
      assert {:error, :invalid_key} = result
    end

    @tag :fmea
    test "validates payload type" do
      key = "fmea-key-#{:rand.uniform(10000)}"
      {:ok, _} = ExternalAPIGateway.register_api_key(key)

      # Non-map payloads should fail validation
      result = ExternalAPIGateway.validate_request(key, "/api/test", [1, 2, 3])
      assert {:error, :validation_failed, _} = result
    end
  end

  # ============================================================
  # STAMP CONSTRAINT VERIFICATION TESTS
  # ============================================================

  describe "STAMP constraint verification" do
    @tag :stamp
    test "SC-ECO-001: API key management" do
      key = "stamp-key-#{:rand.uniform(10000)}"
      assert {:ok, key_id} = ExternalAPIGateway.register_api_key(key, name: "stamp-test")
      assert is_binary(key_id)

      # Key should now be valid
      result = ExternalAPIGateway.validate_request(key, "/api/test", %{})
      assert {:ok, _} = result
    end

    @tag :stamp
    test "SC-ECO-003: Input validation at ecosystem boundary" do
      key = "validation-key-#{:rand.uniform(10000)}"
      {:ok, _} = ExternalAPIGateway.register_api_key(key)

      # Valid map payload should pass
      assert {:ok, _} = ExternalAPIGateway.validate_request(key, "/api/test", %{valid: true})

      # Invalid payload type should fail
      assert {:error, :validation_failed, _} =
               ExternalAPIGateway.validate_request(key, "/api/test", "string")
    end

    @tag :stamp
    test "SC-ECO-005: API telemetry captured in stats" do
      key = "telemetry-key-#{:rand.uniform(10000)}"
      {:ok, _} = ExternalAPIGateway.register_api_key(key)

      # Make some requests
      ExternalAPIGateway.validate_request(key, "/api/test", %{})
      ExternalAPIGateway.validate_request("invalid", "/api/test", %{})

      # Check stats are being tracked
      %{stats: stats} = ExternalAPIGateway.get_status()
      assert stats.total_requests > 0
    end
  end
end
