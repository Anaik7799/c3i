defmodule IndrajaalWeb.Api.Mobile.Shared.ErrorHelpers do
  @moduledoc """
  Shared error handling utilities for Mobile API controllers.

  Provides consistent error formatting, translation, and response handling
  across all mobile API endpoints with enterprise-grade error management.
  """

  import Plug.Conn
  require Logger

  @doc """
  Translates changeset errors into a structured format for API responses.

  Returns a map with field names as keys and error messages as values,
  suitable for JSON API responses and mobile application consumption.
  """
  @spec translate_errors(Ecto.Changeset.t()) :: %{String.t() => [String.t()]}
  def translate_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  @doc """
  Formats error responses with error codes, messages,
  and optional meta_data for mobile client error handling.
  """
  @spec format_error_response(Plug.Conn.t(), atom(), String.t(), map()) :: Plug.Conn.t()
  def format_error_response(conn, error_type, message, meta_data \\ %{}) do
    error_response = %{
      error: %{
        type: error_type,
        message: message,
        id: generate_error_id(),
        meta_data: meta_data
      }
    }

    conn
    |> put_status(:bad_request)
    |> Phoenix.Controller.json(error_response)
  end

  @doc """
  Converts Ecto changeset errors into mobile-friendly format with
  field-specific error messages and validation constraints.
  """
  @spec handle_validation_errors(Plug.Conn.t(), Ecto.Changeset.t()) :: Plug.Conn.t()
  def handle_validation_errors(conn, changeset) do
    errors = translate_errors(changeset)
    format_error_response(conn, :validation_error, "Validation failed", %{field_errors: errors})
  end

  @doc """
  Handles authentication errors with appropriate security messaging
  that doesn't reveal information about authentication mechanisms or user existence.
  """
  @spec handle_auth_error(Plug.Conn.t(), atom()) :: Plug.Conn.t()
  def handle_auth_error(conn, auth_error_type) do
    {message, meta_data} = get_auth_error_details(auth_error_type)

    format_error_response(conn, :authentication_error, message, meta_data)
  end

  @doc """
  Handles authorization errors with appropriate access control messaging.

  Returns authorization error responses with proper HTTP status codes
  and user-friendly messages for insufficient permissions.
  """
  @spec handle_authorization_error(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def handle_authorization_error(conn, resource \\ "resource") do
    message = "You do not have permission to access this #{resource}"

    format_error_response(conn, :authorization_error, message, %{
      __required_permission: "access_#{resource}",
      resource: resource
    })
  end

  @doc """
  Handles not found errors with consistent 404 responses.

  Provides standardized not found responses for missing resources
  with optional resource type information.
  """
  @spec handle_not_found_error(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def handle_not_found_error(conn, resource_type \\ "resource") do
    message = "The __requested #{resource_type} was not found"

    format_error_response(conn, :not_found, message, %{
      resource_type: resource_type
    })
  end

  @doc """
  Handles rate limiting errors with retry information.

  Returns rate limit exceeded responses with retry-after information
  and current rate limit status for client retry logic.
  """
  @spec handle_rate_limit_error(Plug.Conn.t(), integer()) :: Plug.Conn.t()
  def handle_rate_limit_error(conn, retry_after_seconds) do
    message = "Rate limit exceeded. Please try again later"

    conn = put_resp_header(conn, "retry-after", to_string(retry_after_seconds))

    format_error_response(conn, :rate_limit_exceeded, message, %{
      retry_after_seconds: retry_after_seconds,
      current_time: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Handles internal server errors with safe error messaging.

  Returns generic internal server error responses without exposing
  sensitive system information while logging detailed errors for debugging.
  """
  @spec handle_internal_error(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def handle_internal_error(conn, error_detail \\ nil) do
    error_id = generate_error_id()

    # Log detailed error for debugging
    Logger.error("Internal server error",
      error_id: error_id,
      error_detail: error_detail,
      __request_path: conn.__request_path,
      __request_method: conn.method
    )

    message = "An internal server error occurred"

    format_error_response(conn, :internal_server_error, message, %{
      error_id: error_id,
      support_message: "Please contact support with error ID: #{error_id}"
    })
  end

  # Private helper functions

  @spec get_auth_error_details(atom()) :: {String.t(), map()}
  defp get_auth_error_details(auth_error_type) do
    case auth_error_type do
      :invalid_credentials ->
        {"Invalid credentials provided", %{hint: "Check your __username and password"}}

      :token_expired ->
        {"Authentication token has expired", %{hint: "Please log in again"}}

      :token_invalid ->
        {"Authentication token is invalid", %{hint: "Please log in again"}}

      :account_disabled ->
        {"Account has been disabled", %{hint: "Contact administrator"}}

      :account_locked ->
        {"Account has been locked", %{hint: "Contact administrator or try again later"}}

      :missing_token ->
        {"Authentication token is __required",
         %{hint: "Please provide a valid authentication token"}}

      _ ->
        {"Authentication failed", %{hint: "Please check your credentials and try again"}}
    end
  end

  @spec generate_error_id() :: String.t()
  defp generate_error_id do
    random_bytes = :crypto.strong_rand_bytes(8)
    random_bytes |> Base.encode16(case: :lower)
  end

  # Helper function to translate individual error messages
  defp translate_error({msg, opts}) do
    # If error message has options, we can interpolate them
    if count = opts[:count] do
      Gettext.dngettext(IndrajaalWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(IndrajaalWeb.Gettext, "errors", msg, opts)
    end
  end

  defp translate_error(msg) do
    Gettext.dgettext(IndrajaalWeb.Gettext, "errors", msg)
  end
end
