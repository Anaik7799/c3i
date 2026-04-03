defmodule IndrajaalWeb.MobileControllerTestFramework do
  @moduledoc """
  Mobile Controller Test Framework - Phase T consolidation

  Provides common setup, authentication, and test infrastructure for
  mobile API controller tests. Eliminates duplication across test files.

  Usage:
      use IndrajaalWeb.MobileControllerTestFramework

      setup_mobile_test(YourController)

  This will:
  - Set up ConnCase with async: true
  - Import verified routes, Phoenix.ConnTest, ExUnit.Assertions, and Factory
  - Provide authenticated conn in test context as `authed_conn`
  """

  @doc """
  When used, injects common test infrastructure including setup_mobile_test macro.
  """
  defmacro __using__(_opts) do
    quote do
      use IndrajaalWeb.ConnCase, async: true
      use IndrajaalWeb, :verified_routes
      import Phoenix.ConnTest
      import ExUnit.Assertions
      import Indrajaal.Factory
      import IndrajaalWeb.MobileControllerTestFramework

      @endpoint IndrajaalWeb.Endpoint
    end
  end

  @doc """
  Common mobile controller test setup.

  Creates an authenticated user with admin role and a tenant,
  then sets up authentication headers on the connection.

  Provides in test context:
  - conn: Raw connection (unauthenticated)
  - authed_conn: Connection with auth headers
  - user: The test user
  - tenant: The test tenant
  """
  defmacro setup_mobile_test(_controller_module) do
    quote do
      setup %{conn: conn} do
        # Common mobile authentication setup
        user = insert(:user, role: :admin)
        tenant = insert(:tenant)

        authed_conn =
          conn
          |> put_req_header(
            "authorization",
            "Bearer #{IndrajaalWeb.MobileControllerTestFramework.generate_test_token(user)}"
          )
          |> put_req_header("x-tenant-id", tenant.id)
          |> put_req_header("content-type", "application/json")

        {:ok, conn: conn, authed_conn: authed_conn, user: user, tenant: tenant}
      end
    end
  end

  @doc """
  Generate a test authentication token for a user.
  """
  def generate_test_token(user) do
    case Indrajaal.Authentication.generate_token(user) do
      {:ok, token} -> token
      {:ok, token, _claims} -> token
      _ -> "test-token-#{user.id}"
    end
  end
end
