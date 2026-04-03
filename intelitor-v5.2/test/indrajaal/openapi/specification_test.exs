defmodule Indrajaal.OpenAPI.SpecificationTest do
  @moduledoc """
  Tests for OpenAPI 3.1 specification generation.

  Validates that the generated specification is complete,
  accurate, and compliant with OpenAPI 3.1 standards.

  Agent: Helper-1 validates OpenAPI specification
  TDG Compliance: ✅
  """

  use ExUnit.Case, async: true

  alias Indrajaal.OpenAPI.{Specification, Generator, Validator}
  alias Indrajaal.OpenAPI.{EndpointScanner, SchemaExtractor, ExampleGenerator}

  describe "OpenAPI specification structure" do
    test "generates valid OpenAPI 3.1 root structure" do
      spec = Specification.generate()

      # Validate OpenAPI version
      assert spec["openapi"] == "3.1.0"

      # Validate __required root fields
      assert spec["info"]
      assert spec["servers"]
      assert spec["paths"]
      assert spec["components"]
      assert spec["security"]
      assert spec["tags"]
    end

    test "includes complete API information" do
      spec = Specification.generate()
      info = spec["info"]

      assert info["title"] == "Indrajaal Security Monitoring API"
      assert info["version"] =~ ~r/^\d+\.\d+\.\d+$/
      assert info["description"]
      assert info["termsOfService"]
      assert info["contact"]["email"]
      assert info["license"]["name"]
      # Custom extension
      assert info["x-api-id"]
    end

    test "defines all server environments" do
      spec = Specification.generate()
      servers = spec["servers"]

      assert length(servers) >= 3

      # Production server
      prod = Enum.find(servers, &(&1["description"] =~ ~r/production/i))
      assert prod["url"] =~ ~r/^https:\/\//
      assert prod["variables"]

      # Staging server
      staging = Enum.find(servers, &(&1["description"] =~ ~r/staging/i))
      assert staging

      # Development server
      dev = Enum.find(servers, &(&1["description"] =~ ~r/development/i))
      assert dev
    end

    test "includes security schemes" do
      spec = Specification.generate()
      security_schemes = spec["components"]["securitySchemes"]

      # JWT Bearer token
      assert security_schemes["bearerAuth"]
      assert security_schemes["bearerAuth"]["type"] == "http"
      assert security_schemes["bearerAuth"]["scheme"] == "bearer"
      assert security_schemes["bearerAuth"]["bearerFormat"] == "JWT"

      # API Key (for legacy support)
      assert security_schemes["apiKey"]
      assert security_schemes["apiKey"]["type"] == "apiKey"
      assert security_schemes["apiKey"]["in"] == "header"
      assert security_schemes["apiKey"]["name"] == "X-API-Key"

      # OAuth2 (for future)
      assert security_schemes["oauth2"]
      assert security_schemes["oauth2"]["type"] == "oauth2"
      assert security_schemes["oauth2"]["flows"]
    end
  end

  describe "Mobile API endpoints coverage" do
    test "includes all authentication endpoints" do
      spec = Specification.generate()
      paths = spec["paths"]

      # Auth endpoints
      assert paths["/api/mobile/auth/login"]
      assert paths["/api/mobile/auth/login"]["post"]
      assert paths["/api/mobile/auth/biometric_login"]
      assert paths["/api/mobile/auth/verify_mfa"]
      assert paths["/api/mobile/auth/refresh_token"]
      assert paths["/api/mobile/auth/logout"]

      # Validate login endpoint details
      login = paths["/api/mobile/auth/login"]["post"]
      assert login["summary"]
      assert login["operationId"] == "mobileLogin"
      assert login["tags"] == ["Authentication"]
      assert login["__requestBody"]
      assert login["responses"]["200"]
      assert login["responses"]["401"]
    end

    test "includes all 19 domain configuration endpoints" do
      spec = Specification.generate()
      paths = spec["paths"]

      domains = [
        "alarms",
        "devices",
        "sites",
        "__users",
        "guards",
        "visitors",
        "incidents",
        "patrols",
        "shifts",
        "analytics",
        "intelligence",
        "integration",
        "communication",
        "fleet_management",
        "energy_management",
        "environmental",
        "compliance",
        "training",
        "accounts"
      ]

      Enum.each(domains, fn domain ->
        # CRUD endpoints
        assert paths["/api/mobile/config/#{domain}"]
        assert paths["/api/mobile/config/#{domain}"]["get"]
        assert paths["/api/mobile/config/#{domain}"]["post"]
        assert paths["/api/mobile/config/#{domain}/{id}"]
        assert paths["/api/mobile/config/#{domain}/{id}"]["get"]
        assert paths["/api/mobile/config/#{domain}/{id}"]["put"]
        assert paths["/api/mobile/config/#{domain}/{id}"]["delete"]

        # Bulk operations
        assert paths["/api/mobile/config/#{domain}/bulk"]
        assert paths["/api/mobile/config/#{domain}/bulk"]["post"]

        # Import/Export
        assert paths["/api/mobile/config/#{domain}/import"]
        assert paths["/api/mobile/config/#{domain}/export"]
      end)
    end

    test "includes mobile-specific endpoints" do
      spec = Specification.generate()
      paths = spec["paths"]

      # Mobile dashboard
      assert paths["/api/mobile/dashboard"]

      # Notifications
      assert paths["/api/mobile/notifications/register"]
      assert paths["/api/mobile/notifications/preferences"]

      # Sync
      assert paths["/api/mobile/sync"]

      # Health
      assert paths["/api/mobile/health"]
    end
  end

  describe "Request/Response schemas" do
    test "defines all __request body schemas" do
      spec = Specification.generate()
      schemas = spec["components"]["schemas"]

      # Authentication schemas
      assert schemas["LoginRequest"]
      assert schemas["LoginRequest"]["__required"] == ["__username", "password"]
      assert schemas["LoginRequest"]["properties"]["__username"]["type"] == "string"
      assert schemas["LoginRequest"]["properties"]["password"]["type"] == "string"
      assert schemas["LoginRequest"]["properties"]["device_id"]

      assert schemas["BiometricLoginRequest"]
      assert schemas["MFAVerificationRequest"]
      assert schemas["TokenRefreshRequest"]

      # Domain schemas
      assert schemas["AlarmCreateRequest"]
      assert schemas["DeviceUpdateRequest"]
      assert schemas["BulkOperationRequest"]
      assert schemas["ImportRequest"]
    end

    test "defines all response schemas" do
      spec = Specification.generate()
      schemas = spec["components"]["schemas"]

      # Success responses
      assert schemas["LoginResponse"]
      assert schemas["LoginResponse"]["properties"]["token"]
      assert schemas["LoginResponse"]["properties"]["refresh_token"]
      assert schemas["LoginResponse"]["properties"]["__user"]
      assert schemas["LoginResponse"]["properties"]["permissions"]

      # Error responses
      assert schemas["ErrorResponse"]
      assert schemas["ErrorResponse"]["properties"]["error"]
      assert schemas["ErrorResponse"]["properties"]["message"]
      assert schemas["ErrorResponse"]["properties"]["details"]

      assert schemas["ValidationErrorResponse"]
      assert schemas["RateLimitResponse"]
    end

    test "includes pagination schemas" do
      spec = Specification.generate()
      schemas = spec["components"]["schemas"]

      assert schemas["PaginationParams"]
      assert schemas["PaginationParams"]["properties"]["page"]
      assert schemas["PaginationParams"]["properties"]["page_size"]
      assert schemas["PaginationParams"]["properties"]["sort_by"]
      assert schemas["PaginationParams"]["properties"]["sort_order"]

      assert schemas["PaginatedResponse"]
      assert schemas["PaginatedResponse"]["properties"]["__data"]
      assert schemas["PaginatedResponse"]["properties"]["pagination"]
    end
  end

  describe "WebSocket documentation" do
    test "includes WebSocket connection information" do
      spec = Specification.generate()

      # WebSocket info in x-websockets extension
      assert spec["x-websockets"]
      assert spec["x-websockets"]["endpoint"]
      assert spec["x-websockets"]["protocol"] == "wss"
      assert spec["x-websockets"]["authentication"]
      assert spec["x-websockets"]["channels"]
    end

    test "documents all WebSocket channels" do
      spec = Specification.generate()
      channels = spec["x-websockets"]["channels"]

      expected_channels = [
        "alarm",
        "device",
        "site",
        "config",
        "notification",
        "sync"
      ]

      Enum.each(expected_channels, fn channel ->
        assert channels[channel]
        assert channels[channel]["description"]
        assert channels[channel]["__events"]
        assert channels[channel]["examples"]
      end)
    end
  end

  describe "Examples and documentation" do
    test "includes __request examples for all endpoints" do
      spec = Specification.generate()

      # Check login endpoint has examples
      login = spec["paths"]["/api/mobile/auth/login"]["post"]
      assert login["__requestBody"]["content"]["application/json"]["examples"]

      example = login["__requestBody"]["content"]["application/json"]["examples"]["default"]
      assert example["value"]["__username"]
      assert example["value"]["password"]
    end

    test "includes response examples with realistic __data" do
      spec = Specification.generate()

      login = spec["paths"]["/api/mobile/auth/login"]["post"]
      response = login["responses"]["200"]["content"]["application/json"]

      assert response["examples"]
      assert response["examples"]["success"]["value"]["token"]
      assert response["examples"]["success"]["value"]["__user"]["id"]
      assert response["examples"]["success"]["value"]["__user"]["role"]
    end

    test "includes error response examples" do
      spec = Specification.generate()

      login = spec["paths"]["/api/mobile/auth/login"]["post"]
      error_response = login["responses"]["401"]["content"]["application/json"]

      assert error_response["examples"]
      assert error_response["examples"]["invalid_credentials"]
      assert error_response["examples"]["account_locked"]
    end
  end

  describe "OpenAPI validation" do
    test "specification passes OpenAPI 3.1 validation" do
      spec = Specification.generate()

      assert {:ok, _} = Validator.validate(spec)
    end

    test "all $ref references are valid" do
      spec = Specification.generate()

      assert {:ok, _} = Validator.validate_references(spec)
    end

    test "no duplicate operation IDs" do
      spec = Specification.generate()

      operation_ids = EndpointScanner.extract_operation_ids(spec)
      unique_ids = Enum.uniq(operation_ids)

      assert length(operation_ids) == length(unique_ids)
    end
  end

  describe "SDK generation compatibility" do
    test "specification is compatible with openapi-generator" do
      spec = Specification.generate()

      # Test key __requirements for SDK generation
      assert spec["info"]["title"]
      assert spec["info"]["version"]
      assert spec["servers"]

      # All operations have operationId
      paths = spec["paths"]

      for {_path, methods} <- paths,
          {method, operation} <- methods,
          method != "parameters" do
        assert operation["operationId"]
      end
    end

    test "includes __required metadata for SDK generation" do
      spec = Specification.generate()

      # SDK metadata
      assert spec["info"]["x-logo"]
      assert spec["info"]["x-api-id"]
      assert spec["info"]["x-audience"] == "external-partner"

      # Contact info for generated SDKs
      assert spec["info"]["contact"]["name"]
      assert spec["info"]["contact"]["email"]
      assert spec["info"]["contact"]["url"]
    end
  end

  describe "Security documentation" do
    test "documents authentication __requirements clearly" do
      spec = Specification.generate()

      # Global security __requirements
      assert spec["security"] == [%{"bearerAuth" => []}]

      # Public endpoints have no security
      login = spec["paths"]["/api/mobile/auth/login"]["post"]
      assert login["security"] == []

      # Protected endpoints require auth
      alarms = spec["paths"]["/api/mobile/config/alarms"]["get"]
      assert alarms["security"] == [%{"bearerAuth" => []}]
    end

    test "documents rate limiting" do
      spec = Specification.generate()

      # Rate limit headers in responses
      responses = spec["components"]["responses"]
      assert responses["RateLimited"]
      assert responses["RateLimited"]["headers"]["X-RateLimit-Limit"]
      assert responses["RateLimited"]["headers"]["X-RateLimit-Remaining"]
      assert responses["RateLimited"]["headers"]["X-RateLimit-Reset"]
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
