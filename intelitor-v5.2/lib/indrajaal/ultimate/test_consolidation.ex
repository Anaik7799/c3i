defmodule Indrajaal.Ultimate.TestConsolidation do
  @moduledoc """
  Ultimate Test Consolidation - Phase V
  Eliminates ALL test - related duplications.
  """

  # Module-level imports for helper functions defined in this module
  import ExUnit.Assertions
  import Phoenix.ConnTest, except: [dispatch: 5]
  import Plug.Conn

  @doc """
  Called when a module uses this consolidation module.
  Imports common test utilities and assertions.
  """
  defmacro __using__(_opts) do
    quote do
      import ExUnit.Assertions
      import Phoenix.ConnTest, except: [dispatch: 5]
      import Plug.Conn
      import Indrajaal.Ultimate.TestConsolidation
    end
  end

  @doc """
  Universal test setup pattern
  """
  defmacro universal_test_setup(_opts \\ []) do
    quote do
      setup do
        # Common setup for all tests
        tenant = insert(:tenant)
        user = insert(:user, tenant_id: tenant.id)
        conn = build_conn() |> assign(:current_user, user) |> assign(:current_tenant, tenant)

        on_exit(fn -> :ok end)

        {:ok, conn: conn, user: user, tenant: tenant}
      end
    end
  end

  @doc """
  Universal assertion helper
  """
  @spec assert_response(Plug.Conn.t(), term(), list()) :: term()
  def assert_response(conn, status, checks \\ []) do
    assert conn.status == status

    Enum.each(checks, fn
      {:json, expected} -> assert json_response(conn, status) == expected
      {:contains, text} -> assert conn.resp_body =~ text
      {:header, {name, value}} -> assert get_resp_header(conn, name) == [value]
    end)

    conn
  end

  @doc """
  Universal async test helper
  """
  @spec async_test(function(), keyword()) :: term()
  def async_test(testfn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    task = Task.async(testfn)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> flunk("Test timed out after #{timeout}ms")
    end
  end

  # EP201: Removed unused function cleanup_test_data/0
  # defp cleanup_test_data do
  #   # Common cleanup logic
  #   :ok
  # end
end
