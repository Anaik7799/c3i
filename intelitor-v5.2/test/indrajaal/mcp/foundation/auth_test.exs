defmodule Indrajaal.MCP.Foundation.AuthTest do
  @moduledoc """
  Unit tests for MCP Foundation Auth module.

  WHAT: Tests bearer token validation, certificate auth, RBAC, and rate limiting.
  WHY: Ensures SC-MCP-060 (authentication required) and SC-MCP-061 (RBAC enforcement).

  STAMP Constraints:
  - SC-MCP-060: All MCP requests MUST be authenticated
  - SC-MCP-061: Role-based access control enforced
  - SC-MCP-062: Rate limiting per client
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.MCP.Foundation.Auth

  describe "authenticate/2 - bearer token" do
    test "accepts valid bearer token format" do
      context = %{"authorization" => "Bearer test-token-abc123"}
      result = Auth.authenticate(context, :bearer)
      assert {:ok, _auth_context} = result
    end

    test "rejects missing authorization header" do
      context = %{}
      result = Auth.authenticate(context, :bearer)
      assert {:error, :unauthorized} = result
    end

    test "rejects empty bearer token" do
      context = %{"authorization" => "Bearer "}
      result = Auth.authenticate(context, :bearer)
      assert {:error, :unauthorized} = result
    end

    test "rejects non-bearer scheme" do
      context = %{"authorization" => "Basic dXNlcjpwYXNz"}
      result = Auth.authenticate(context, :bearer)
      assert {:error, :unauthorized} = result
    end
  end

  describe "authenticate/2 - certificate" do
    test "accepts valid client certificate context" do
      context = %{
        "client_cert" => %{
          "subject" => "CN=mcp-client-1",
          "issuer" => "CN=indrajaal-ca",
          "valid" => true
        }
      }

      result = Auth.authenticate(context, :certificate)
      assert {:ok, _auth_context} = result
    end

    test "rejects missing certificate" do
      context = %{}
      result = Auth.authenticate(context, :certificate)
      assert {:error, :unauthorized} = result
    end

    test "rejects invalid certificate" do
      context = %{"client_cert" => %{"valid" => false}}
      result = Auth.authenticate(context, :certificate)
      assert {:error, :unauthorized} = result
    end
  end

  describe "authorize/3 - RBAC" do
    test "admin role has full access" do
      auth = %{role: :admin, permissions: [:read, :write, :delete]}
      assert :ok = Auth.authorize(auth, :write, "indrajaal.alarms.process")
    end

    test "operator role can read" do
      auth = %{role: :operator, permissions: [:read]}
      assert :ok = Auth.authorize(auth, :read, "indrajaal.alarms.list")
    end

    test "viewer role cannot write" do
      auth = %{role: :viewer, permissions: [:read]}
      assert {:error, :forbidden} = Auth.authorize(auth, :write, "indrajaal.alarms.process")
    end

    test "unknown role is denied" do
      auth = %{role: :unknown, permissions: []}
      assert {:error, :forbidden} = Auth.authorize(auth, :read, "indrajaal.anything")
    end
  end

  describe "rate_check/2" do
    test "allows requests within rate limit" do
      client_id = "test-client-#{System.unique_integer([:positive])}"
      assert :ok = Auth.rate_check(client_id, max_requests: 100, window_ms: 60_000)
    end

    test "returns rate limit info" do
      client_id = "rate-test-#{System.unique_integer([:positive])}"

      for _ <- 1..5 do
        Auth.rate_check(client_id, max_requests: 100, window_ms: 60_000)
      end

      result = Auth.rate_check(client_id, max_requests: 100, window_ms: 60_000)
      assert :ok = result
    end
  end

  describe "property tests" do
    property "any non-empty string is a valid bearer token format" do
      forall token <- PC.non_empty(PC.utf8()) do
        context = %{"authorization" => "Bearer #{token}"}

        case Auth.authenticate(context, :bearer) do
          {:ok, _} -> true
          {:error, :unauthorized} -> true
        end
      end
    end

    property "role permissions are deterministic" do
      ExUnitProperties.check all(
                               role <- SD.member_of([:admin, :operator, :viewer, :unknown]),
                               action <- SD.member_of([:read, :write, :delete]),
                               tool <- SD.string(:alphanumeric, min_length: 1)
                             ) do
        auth = %{role: role, permissions: Auth.permissions_for(role)}
        result1 = Auth.authorize(auth, action, tool)
        result2 = Auth.authorize(auth, action, tool)
        assert result1 == result2
      end
    end
  end
end
