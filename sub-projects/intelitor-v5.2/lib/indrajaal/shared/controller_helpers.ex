defmodule Indrajaal.Shared.ControllerHelpers do
  @moduledoc """
  Controller helpers eliminating ~100 duplicate violations.
  """

  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn, only: [put_status: 2]

  @spec render_json_response(Plug.Conn.t(), any(), atom()) :: Plug.Conn.t()
  def render_json_response(conn, data, status \\ :ok) do
    conn
    |> put_status(status)
    |> json(data)
  end
end
