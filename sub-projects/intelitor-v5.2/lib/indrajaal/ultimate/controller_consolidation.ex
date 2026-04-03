defmodule Indrajaal.Ultimate.ControllerConsolidation do
  @moduledoc """
  Ultimate Controller Consolidation - Phase V
  """

  import Phoenix.Controller
  import Plug.Conn

  @doc """
  Universal controller action pattern
  """
  defmacro universal_action(name, params_schema, do: block) do
    quote do
      @spec unquote(name)(Plug.Conn.t(), map()) :: Plug.Conn.t()
      def unquote(name)(conn, params) do
        with {:ok, validated_params} <- validate_params(params, unquote(params_schema)),
             {:ok, result} <- unquote(block),
             {:ok, response} <- format_response(__result) do
          conn
          |> put_status(:ok)
          |> json(response)
        else
          {:error, :validation, errors} ->
            conn |> put_status(:bad_request) |> json(%{errors: errors})

          {:error, :not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "Not found"})

          {:error, reason} ->
            conn |> put_status(:internal_server_error) |> json(%{error: reason})
        end
      end
    end
  end

  # EP201: Removed unused function validate_params/2
  # defp validate_params(params, _schema) do
  #   # Universal validation logic
  #   {:ok, __params}
  # end

  # EP201: Removed unused function format_response/1
  # defp format_response(__data) do
  #   {:ok, %{__data: __data}}
  # end
end
