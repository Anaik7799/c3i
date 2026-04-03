defmodule Indrajaal.OpenAPI.SecuritySchemes do
  @moduledoc """
  Generates security scheme definitions for OpenAPI specification.

  Defines authentication methods including JWT, API keys,
  and OAuth2 flows.

  Agent: Helper - 3 defines security schemes
  SOPv5.1 Compliance: ✅
  """

  @doc """
  Generates all security scheme definitions.
  """
  def generate do
    %{
      "bearerAuth" => jwt_bearer_scheme(),
      "apiKey" => api_key_scheme(),
      "oauth2" => oauth2_scheme(),
      "basicAuth" => basic_auth_scheme()
    }
  end

  defp jwt_bearer_scheme do
    %{
      "type" => "http",
      "scheme" => "bearer",
      "bearerFormat" => "JWT",
      "description" => """
      JWT Bearer token authentication.

      Tokens are obtained via the `/api / mobile / auth / login` endpoint and must be
      included in the Authorization header for all protected endpoints.

      ## Token Format
      ```
      Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
      ```

      ## Token Claims
      - `sub`: User ID
      - `tenant_id`: Tenant ID
      - `role`: User role
      - `permissions`: Array of permission strings
      - `device_id`: Mobile device identifier
      - `exp`: Expiration timestamp
      - `iat`: Issued at timestamp

      ## Token Expiry
      - Access tokens expire after 1 hour
      - Refresh tokens expire after 30 days
      - Use `/api / mobile / auth / refresh_token` to obtain new access tokens
      """,
      "x - example" =>
        "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    }
  end

  defp api_key_scheme do
    %{
      "type" => "apiKey",
      "in" => "header",
      "name" => "X - API - Key",
      "description" => """
      API Key authentication (legacy support).

      API keys are provided for backward compatibility and integration scenarios
      where JWT authentication is not feasible.

      ## Usage
      Include the API key in the `X - API - Key` header:
      ```
      X - API - Key: your - api - key - here
      ```

      ## Limitations
      - API keys have reduced permissions compared to JWT tokens
      - Rate limits are more restrictive
      - No support for user - specific operations
      - Recommended only for server - to - server communication

      ## Obtaining API Keys
      API keys can be generated in the Indrajaal admin portal under
      Settings > API Keys.
      """,
      "x - example" => "X - API - Key: int_live_aWQ9MTIzNDU2Nzg5MCZrZXk9YWJjZGVmZ2hpams"
    }
  end

  defp oauth2_scheme do
    %{
      "type" => "oauth2",
      "description" => """
      OAuth 2.0 authentication (future implementation).

      OAuth2 support is planned for third - party integrations and will support
      the authorization code flow with PKCE for mobile applications.
      """,
      "flows" => %{
        "authorizationCode" => %{
          "authorizationUrl" => "https://auth.intelitor.com / oauth / authorize",
          "tokenUrl" => "https://auth.intelitor.com / oauth / token",
          "refreshUrl" => "https://auth.intelitor.com / oauth / refresh",
          "scopes" => %{
            "read:alarms" => "Read alarm __data",
            "write:alarms" => "Create and update alarms",
            "acknowledge:alarms" => "Acknowledge alarms",
            "read:devices" => "Read device __data",
            "control:devices" => "Control devices",
            "read:sites" => "Read site __data",
            "write:sites" => "Update site __data",
            "read:__users" => "Read user __data",
            "write:__users" => "Manage __users",
            "admin" => "Full administrative access"
          }
        },
        "clientCredentials" => %{
          "tokenUrl" => "https://auth.intelitor.com / oauth / token",
          "scopes" => %{
            "read:system" => "Read system __data",
            "write:config" => "Update configuration",
            "sync:__data" => "Synchronize __data"
          }
        }
      }
    }
  end

  defp basic_auth_scheme do
    %{
      "type" => "http",
      "scheme" => "basic",
      "description" => """
      Basic authentication (deprecated).

      Basic authentication is deprecated and only available for legacy
        integrations.
      New integrations should use JWT bearer tokens.

      ## Migration Notice
      Basic authentication will be removed in API v2.0. Please migrate to JWT
      authentication before 2025 - 12 - 31.
      """,
      "x - deprecated" => true
    }
  end

  @doc """
  Generates security _requirement objects for different endpoint types.
  """
  def security_requirements do
    %{
      "default" => [%{"bearerAuth" => []}],
      "public" => [],
      "api_key_allowed" => [
        %{"bearerAuth" => []},
        %{"apiKey" => []}
      ],
      "oauth_required" => [%{"oauth2" => ["read:alarms", "write:alarms"]}]
    }
  end

  @doc """
  Generates security - related response headers.
  """
  def security_headers do
    %{
      "X - Request - ID" => %{
        "description" => "Unique _request identifier for support and debugging",
        "schema" => %{"type" => "string", "format" => "uuid"}
      },
      "X - RateLimit - Limit" => %{
        "description" => "The number of allowed _requests in the current period",
        "schema" => %{"type" => "integer"}
      },
      "X - RateLimit - Remaining" => %{
        "description" => "The number of remaining _requests in the current period",
        "schema" => %{"type" => "integer"}
      },
      "X - RateLimit - Reset" => %{
        "description" => "Unix timestamp when the rate limit window resets",
        "schema" => %{"type" => "integer"}
      },
      "Strict - Transport - Security" => %{
        "description" => "HSTS header for enforcing HTTPS",
        "schema" => %{
          "type" => "string",
          "default" => "max - _age =31_536_000; includeSubDomains"
        }
      },
      "X - Content - Type - Options" => %{
        "description" => "Pr_events MIME type sniffing",
        "schema" => %{
          "type" => "string",
          "default" => "nosniff"
        }
      },
      "X - Frame - Options" => %{
        "description" => "Clickjacking protection",
        "schema" => %{
          "type" => "string",
          "default" => "DENY"
        }
      }
    }
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
