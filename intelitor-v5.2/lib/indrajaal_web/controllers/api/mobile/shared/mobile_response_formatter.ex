defmodule IndrajaalWeb.Api.Mobile.Shared.MobileResponseFormatter do
  @moduledoc """
  Consolidated response formatting functions for mobile API controllers.

  This module eliminates hundreds of duplicate response formatting patterns
  by providing standardized mobile API response structures.

  SOPv5.1 Compliance: ✅
  Agent: Helper - 2 provides response formatting coordination
  TPS Methodology: Standardized response patterns for quality assurance
  """

  import Plug.Conn

  @doc """
  Formats successful mobile API responses with consistent structure.
  """
  @spec success_response(Plug.Conn.t(), any(), map()) :: Plug.Conn.t()
  def success_response(conn, data, opts \\ %{}) do
    conn
    |> put_status(Map.get(opts, :status, :ok))
    |> Phoenix.Controller.json(%{
      success: true,
      data: data,
      message: Map.get(opts, :message, "Operation completed successfully"),
      metadata: Map.get(opts, :metadata, %{})
    })
  end

  @doc """
  Formats error responses with consistent structure.
  """
  @spec error_response(Plug.Conn.t(), atom(), String.t(), map()) :: Plug.Conn.t()
  def error_response(conn, error_type, message, opts \\ %{}) do
    conn
    |> put_status(Map.get(opts, :status, :bad_request))
    |> Phoenix.Controller.json(%{
      success: false,
      error: %{
        type: error_type,
        message: message,
        details: Map.get(opts, :details, %{})
      },
      metadata: Map.get(opts, :metadata, %{})
    })
  end

  @doc """
  Formats bulk operation responses with success/failure statistics.
  """
  @spec bulk_operation_response(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def bulk_operation_response(conn, result) do
    data = %{
      success_count: Map.get(result, :success_count, 0),
      failed_count: Map.get(result, :failed_count, 0),
      total_count: Map.get(result, :total_count, 0),
      success_rate: calculate_success_rate(result),
      errors: format_bulk_errors(Map.get(result, :errors, []))
    }

    status = if Map.get(result, :error_count, 0) == 0, do: :created, else: :multi_status

    success_response(conn, data, %{
      status: status,
      message: "Bulk operation completed",
      metadata: %{
        operation_type: Map.get(result, :operation_type, "bulk"),
        batch_size: Map.get(result, :batch_size, 0)
      }
    })
  end

  @doc """
  Formats security validation error responses.
  """
  @spec security_error_response(Plug.Conn.t(), atom(), String.t()) :: Plug.Conn.t()
  def security_error_response(conn, violation_type, message) do
    status =
      case violation_type do
        :unauthorized -> :unauthorized
        :forbidden -> :forbidden
        :security_violation -> :bad_request
        :stamp_violation -> :unprocessable_entity
        _ -> :bad_request
      end

    error_response(conn, violation_type, message, %{
      status: status,
      details: %{
        security_check_failed: true,
        violation_type: violation_type,
        remediation: "Review __request parameters and permissions"
      }
    })
  end

  @doc """
  Formats validation error responses with field - specific errors.
  """
  @spec validation_error_response(Plug.Conn.t(), map() | list()) :: Plug.Conn.t()
  def validation_error_response(conn, errors) when is_list(errors) do
    formatted_errors = Enum.map(errors, &format_validation_error/1)

    error_response(conn, :validation_failed, "Request validation failed", %{
      status: :unprocessable_entity,
      details: %{
        field_errors: formatted_errors,
        error_count: length(formatted_errors)
      }
    })
  end

  @spec validation_error_response(Plug.Conn.t(), term()) :: term()
  def validation_error_response(conn, errors) when is_map(errors) do
    formatted_errors =
      errors
      |> Enum.map(fn {field, messages} ->
        %{field: field, messages: List.wrap(messages)}
      end)

    validation_error_response(conn, formatted_errors)
  end

  @doc """
  Formats health check responses for mobile API monitoring.
  """
  @spec health_response(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def health_response(conn, health_data) do
    status = if Map.get(health_data, :healthy, true), do: :ok, else: :service_unavailable

    data = %{
      status: if(Map.get(health_data, :healthy, true), do: "healthy", else: "unhealthy"),
      checks: Map.get(health_data, :checks, %{}),
      version: Map.get(health_data, :version, "unknown"),
      uptime_seconds: Map.get(health_data, :uptime_seconds, 0)
    }

    success_response(conn, data, %{
      status: status,
      message: "Health check completed"
    })
  end

  # Private helper functions

  defp calculate_success_rate(%{success_count: success, total_count: total}) when total > 0 do
    Float.round(success / total * 100, 2)
  end

  defp calculate_success_rate(_), do: 0.0

  defp format_bulk_errors(errors) when is_list(errors) do
    Enum.map(errors, fn error ->
      %{
        index: Map.get(error, :index),
        id: Map.get(error, :id),
        message: Map.get(error, :message, "Unknown error"),
        field: Map.get(error, :field),
        code: Map.get(error, :code, :unknown_error)
      }
    end)
  end

  defp format_bulk_errors(_), do: []

  defp format_validation_error(%{field: field, message: message}) do
    %{field: field, messages: [message]}
  end

  defp format_validation_error({field, messages}) do
    %{field: field, messages: List.wrap(messages)}
  end

  defp format_validation_error(error) when is_map(error) do
    %{
      field: Map.get(error, :field, :unknown),
      messages: [Map.get(error, :message, "Invalid value")]
    }
  end

  defp format_validation_error(error), do: %{field: :unknown, messages: [inspect(error)]}
end
