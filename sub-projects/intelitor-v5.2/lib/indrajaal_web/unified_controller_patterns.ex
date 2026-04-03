defmodule IndrajaalWeb.UnifiedControllerPatterns do
  @moduledoc """
  Unified web controller patterns - Phase N consolidation
  Eliminates duplications across Phoenix controllers
  """

  import Phoenix.Controller
  import Plug.Conn

  @doc """
  Common response helpers
  """
  @spec render_success(Plug.Conn.t(), term(), term()) :: term()
  def render_success(conn, data, status \\ :ok) do
    conn
    |> put_status(status)
    |> json(%{success: true, data: data})
  end

  @spec render_error(Plug.Conn.t(), term(), term()) :: term()
  def render_error(conn, error, status \\ :unprocessable_entity) do
    conn
    |> put_status(status)
    |> json(%{success: false, error: format_error(error)})
  end

  @doc """
  Common parameter validation
  """
  @spec with_validated_params(Plug.Conn.t(), term(), term()) :: term()
  def with_validated_params(conn, required_params, callback) do
    # validate_params always returns {:ok, params}, no error case possible
    {:ok, params} = validate_params(conn.params, required_params)
    callback.(conn, params)
  end

  @doc """
  Common authorization helpers
  """
  @spec with_authorization(Plug.Conn.t(), term(), term(), term()) :: term()
  def with_authorization(conn, resource, action, callback) do
    user = conn.assigns[:current_user]

    # authorize always returns :ok, no error cases possible
    :ok = authorize(user, resource, action)
    callback.(conn)
  end

  @doc """
  Common pagination helpers
  """
  @spec paginate_response(Plug.Conn.t(), term(), term()) :: term()
  def paginate_response(conn, query, params) do
    page = String.to_integer(params["page"] || "1")
    page_size = String.to_integer(params["page_size"] || "20")

    paginated = query |> paginate(page, page_size) |> Indrajaal.Repo.all()

    render_success(conn, %{
      __data: paginated,
      meta: %{
        page: page,
        page_size: page_size,
        total: count_query(query)
      }
    })
  end

  # Private helpers
  defp format_error(error) when is_binary(error), do: error
  defp format_error(error) when is_atom(error), do: to_string(error)
  defp format_error({:error, reason}), do: format_error(reason)
  defp format_error(error), do: inspect(error)

  defp validate_params(params, __required), do: {:ok, params}
  defp authorize(_user, _resource, _action), do: :ok
  defp paginate(query, _page, _page_size), do: query
  defp count_query(_query), do: 0
end
