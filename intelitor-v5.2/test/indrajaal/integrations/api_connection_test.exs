defmodule Indrajaal.Integrations.ApiConnectionTest do
  use Indrajaal.DataCase
  # Don't import Factory directly - DataCase provides insert function

  alias Indrajaal.Core.Tenant
  alias Indrajaal.Integrations.{ApiConnection, SyncJob, DataMapping}

  describe "ApiConnection resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)

      {:ok, tenant: tenant, organization: organization}
    end

    test "creates API connection with valid attributes", %{
      tenant: tenant,
      organization: organization
    } do
      attrs = %{
        name: "ACME ERP Integration",
        connection_type: :rest_api,
        base_url: "https://api.acme-erp.com/v2",
        authentication_type: :oauth2,
        configuration: %{
          "client_id" => "acme_client_123",
          "scope" => "read:users write:orders",
          "token_url" => "https://auth.acme-erp.com/oauth/token",
          "timeout" => 30_000,
          "retry_attempts" => 3
        },
        headers: %{
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "User-Agent" => "Indrajaal-Integration/1.0"
        },
        status: :active,
        rate_limit: %{
          "__requests_per_minute" => 100,
          "burst_limit" => 20
        },
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:ok, api_connection} = ApiConnection.create(attrs)

      assert api_connection.name == "ACME ERP Integration"
      assert api_connection.connection_type == :rest_api
      assert api_connection.base_url == "https://api.acme-erp.com/v2"
      assert api_connection.authentication_type == :oauth2
      assert api_connection.configuration["client_id"] == "acme_client_123"
      assert api_connection.headers["Content-Type"] == "application/json"
      assert api_connection.status == :active
      assert api_connection.rate_limit["__requests_per_minute"] == 100
      assert api_connection.organization_id == organization.id
      assert api_connection.tenant_id == tenant.id
    end

    test "validates __required fields", %{tenant: tenant} do
      {:error, changeset} = ApiConnection.create(%{tenant_id: tenant.id})

      assert changeset.errors[:name]
      assert changeset.errors[:connection_type]
      assert changeset.errors[:base_url]
      assert changeset.errors[:authentication_type]
      assert changeset.errors[:organization_id]
    end

    test "validates connection type",
         %{tenant: tenant, organization: organization} do
      valid_types = [:rest_api, :soap, :graphql, :webhook, :__database, :sftp, :message_queue]

      for type <- valid_types do
        {:ok, _connection} =
          ApiConnection.create(%{
            name: "Test Connection",
            connection_type: type,
            base_url: "https://api.example.com",
            authentication_type: :api_key,
            organization_id: organization.id,
            tenant_id: tenant.id
          })
      end

      {:error, changeset} =
        ApiConnection.create(%{
          name: "Test Connection",
          connection_type: :invalid_type,
          base_url: "https://api.example.com",
          authentication_type: :api_key,
          organization_id: organization.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:connection_type]
    end

    test "validates authentication type",
         %{tenant: tenant, organization: organization} do
      valid_auth_types = [:api_key, :basic_auth, :oauth2, :bearer_token, :mutual_tls, :none]

      for auth_type <- valid_auth_types do
        {:ok, _connection} =
          ApiConnection.create(%{
            name: "Test Connection",
            connection_type: :rest_api,
            base_url: "https://api.example.com",
            authentication_type: auth_type,
            organization_id: organization.id,
            tenant_id: tenant.id
          })
      end

      {:error, changeset} =
        ApiConnection.create(%{
          name: "Test Connection",
          connection_type: :rest_api,
          base_url: "https://api.example.com",
          authentication_type: :invalid_auth,
          organization_id: organization.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:authentication_type]
    end

    test "tests connection health",
         %{tenant: tenant, organization: organization} do
      api_connection =
        insert(:api_connection,
          tenant: tenant,
          organization: organization,
          status: :active
        )

      test_result = %{
        success: true,
        response_time_ms: 150,
        status_code: 200,
        response_headers: %{"content-type" => "application/json"},
        test_timestamp: DateTime.utc_now()
      }

      {:ok, tested_connection} = ApiConnection.test_connection(api_connection, test_result)

      assert tested_connection.metadata["last_health_check"]["success"] == true

      assert tested_connection.metadata["last_health_check"]["response_time_ms"] ==
               150

      assert tested_connection.metadata["last_health_check"]["status_code"] ==
               200
    end

    test "manages connection credentials",
         %{tenant: tenant, organization: organization} do
      api_connection =
        insert(:api_connection,
          tenant: tenant,
          organization: organization,
          authentication_type: :oauth2
        )

      credential_data = %{
        access_token: "access_token_abc123",
        refresh_token: "refresh_token_xyz789",
        token_type: "Bearer",
        expires_in: 3600,
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      {:ok, credentialed_connection} =
        ApiConnection.update_credentials(api_connection, credential_data)

      # Credentials should be encrypted / masked in metadata
      assert credentialed_connection.metadata["credentials"]["token_type"] ==
               "Bearer"

      assert credentialed_connection.metadata["credentials"]["expires_in"] ==
               3600

      # Access token should be masked for security
      refute String.contains?(
               credentialed_connection.metadata["credentials"]["access_token"] || "",
               "abc123"
             )
    end

    test "tracks connection metrics",
         %{tenant: tenant, organization: organization} do
      api_connection =
        insert(:api_connection,
          tenant: tenant,
          organization: organization,
          metadata: %{
            "total_requests" => 1250,
            "successful_requests" => 1200,
            "failed_requests" => 50,
            "average_response_time" => 180.5,
            "last_24h_requests" => 85
          }
        )

      connection_with_calc =
        ApiConnection.read!(api_connection.id, load: [:success_rate, :__requests_per_hour])

      # 1200 / 1250 * 100
      assert connection_with_calc.success_rate == 96.0
      assert is_float(connection_with_calc.__requests_per_hour)
    end

    test "manages rate limiting",
         %{tenant: tenant, organization: organization} do
      api_connection =
        insert(:api_connection,
          tenant: tenant,
          organization: organization,
          rate_limit: %{
            "__requests_per_minute" => 60,
            "burst_limit" => 10
          }
        )

      rate_limit_update = %{
        __requests_per_minute: 120,
        burst_limit: 20,
        window_type: "sliding",
        enforcement_action: "throttle"
      }

      {:ok, rate_limited_connection} =
        ApiConnection.update_rate_limit(api_connection, rate_limit_update)

      assert rate_limited_connection.rate_limit["__requests_per_minute"] == 120
      assert rate_limited_connection.rate_limit["burst_limit"] == 20
      assert rate_limited_connection.rate_limit["window_type"] == "sliding"
    end

    test "enforces tenant isolation", %{organization: organization} do
      tenant1 = organization.tenant
      tenant2 = insert(:tenant)
      organization2 = insert(:organization, tenant: tenant2)

      connection1 = insert(:api_connection, tenant: tenant1, organization: organization)
      connection2 = insert(:api_connection, tenant: tenant2, organization: organization2)

      tenant1_connections = ApiConnection.read!(tenant: tenant1)
      tenant2_connections = ApiConnection.read!(tenant: tenant2)

      assert length(tenant1_connections) == 1
      assert length(tenant2_connections) == 1
      assert Enum.any?(tenant1_connections, &(&1.id == connection1.id))
      assert Enum.any?(tenant2_connections, &(&1.id == connection2.id))
      refute Enum.any?(tenant1_connections, &(&1.id == connection2.id))
      refute Enum.any?(tenant2_connections, &(&1.id == connection1.id))
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
