defmodule IndrajaalWeb.ConnCase do
  @moduledoc """
  Test case for Phoenix controller and integration tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import IndrajaalWeb.ConnCase
      import Indrajaal.Factory

      # Verified routes for ~p sigil
      use IndrajaalWeb, :verified_routes

      alias IndrajaalWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint IndrajaalWeb.Endpoint
    end
  end

  setup tags do
    pid =
      Ecto.Adapters.SQL.Sandbox.start_owner!(Indrajaal.Repo,
        shared: not tags[:async]
      )

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    conn = Phoenix.ConnTest.build_conn()

    # Add authentication if needed
    conn =
      if tags[:authenticated] do
        user = Indrajaal.Factory.insert(:user)
        authenticate_conn(conn, user)
      else
        conn
      end

    {:ok, conn: conn}
  end

  @doc """
  Authenticates a connection with a user
  """
  @spec authenticate_conn(any(), any()) :: any()
  def authenticate_conn(conn, _user) do
    # Placeholder for auth token
    token = Ecto.UUID.generate()

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
  end

  @doc """
  Creates and authenticates a user with specific permissions
  """
  @spec auth_conn_with_permissions(any(), any()) :: any()
  def auth_conn_with_permissions(conn, permissions) do
    user = Indrajaal.Factory.insert(:user)
    role = Indrajaal.Factory.insert(:role, permissions: permissions)
    Indrajaal.Factory.insert(:role_assignment, user: user, role: role)

    authenticate_conn(conn, user)
  end
end
