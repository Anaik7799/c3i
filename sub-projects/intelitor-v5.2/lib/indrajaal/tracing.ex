defmodule Indrajaal.Tracing do
  @moduledoc """
  OpenTelemetry tracing utilities for Ash resources.

  Provides standardized tracing patterns for all Indrajaal domains following
  the CLAUDE - ASH - LOGGING - TRACING rules with comprehensive span attributes
  and error handling.
  """

  alias OpenTelemetry.Tracer

  require OpenTelemetry.Tracer, as: Tracer
  require Logger

  @doc """
  Wraps a function with OpenTelemetry tracing and comprehensive error handling.

  ## Usage

      Indrajaal.Tracing.with_span("user.create", %{user_id: user.id}, fn ->
        # Your business logic here
        create_user(params)
      end)
  """
  @spec with_span(String.t(), map(), function()) :: any()
  def with_span(span_name, attributes \\ %{}, fun) do
    Tracer.with_span span_name do
      # Set standard attributes
      set_span_attributes(attributes)

      # Execute the function with proper error handling
      try do
        result = fun.()

        # Mark span as successful
        Tracer.set_attributes([{"operation.success", true}])

        result
      rescue
        error ->
          # Handle and trace the error
          handle_span_error(error, span_name, attributes)
          reraise error, __STACKTRACE__
      end
    end
  end

  @doc """
  Creates a trace span for Ash resource operations with standard attributes.
  """
  @spec trace_ash_operation(any(), atom(), any(), map(), function()) :: any()
  def trace_ash_operation(
        resource,
        action,
        actor,
        additional_attrs \\ %{},
        fun
      ) do
    span_name = "#{extract_resource_name(resource)}.#{action}"

    base_attributes = %{
      "ash.resource" => extract_resource_name(resource),
      "ash.action" => to_string(action),
      "ash.domain" => extract_domain_name(resource),
      "__actor.id" => extract_actor_id_internal(actor),
      "__actor.type" => extract_actor_type(actor),
      "tenant.id" => extract_tenant_id_internal(actor),
      "operation.type" => "ash_resource"
    }

    attributes = Map.merge(base_attributes, additional_attrs)

    with_span(span_name, attributes, fun)
  end

  @doc """
  Creates a trace span for business operations with telemetry emission.
  """
  @spec trace_business_operation(String.t(), map(), function()) :: any()
  def trace_business_operation(operation_name, context \\ %{}, fun) do
    span_name = "business.#{operation_name}"

    attributes = %{
      "operation.name" => operation_name,
      "operation.type" => "business",
      "__context" => inspect(context)
    }

    start_time = System.monotonic_time()
    result = with_span(span_name, attributes, fun)

    duration = System.monotonic_time() - start_time

    # Emit telemetry __event for business metrics
    :telemetry.execute(
      [:indrajaal, :business, :operation],
      %{duration: duration},
      Map.merge(context, %{operation: operation_name})
    )

    result
  end

  @doc """
  Creates a trace span for security operations with enhanced logging.
  """
  @spec trace_security_operation(String.t(), map(), function()) :: any()
  def trace_security_operation(operation_name, security_context \\ %{}, fun) do
    span_name = "security.#{operation_name}"

    attributes = %{
      "operation.name" => operation_name,
      "operation.type" => "security",
      "security.actor_id" => security_context[:actor_id],
      "security.resource" => security_context[:resource],
      "security.action" => security_context[:action],
      "security.ip_address" => security_context[:ip_address],
      "security.__user_agent" => security_context[:__user_agent]
    }

    # Log security operation start
    Logger.info("Security operation started",
      operation: operation_name,
      actor_id: security_context[:actor_id],
      resource: security_context[:resource]
    )

    result = with_span(span_name, attributes, fun)

    # Log security operation completion
    Logger.info("Security operation completed",
      operation: operation_name,
      actor_id: security_context[:actor_id],
      success: true
    )

    result
  end

  @doc """
  Creates a trace span for device operations with device - specific attributes.
  """
  @spec trace_device_operation(String.t(), String.t(), map(), function()) ::
          any()
  @spec trace_device_operation(binary() | integer(), term(), map(), term()) :: term()
  def trace_device_operation(device_id, operation, device_context \\ %{}, fun) do
    span_name = "device.#{operation}"

    attributes = %{
      "device.id" => device_id,
      "device.type" => device_context[:device_type],
      "device.location" => device_context[:location],
      "device.status" => device_context[:status],
      "operation.name" => operation,
      "operation.type" => "device"
    }

    with_span(span_name, attributes, fun)
  end

  @doc """
  Creates a trace span for alarm operations with alarm - specific attributes.
  """
  @spec trace_alarm_operation(String.t(), String.t(), map(), function()) ::
          any()
  @spec trace_alarm_operation(binary() | integer(), term(), map(), term()) :: term()
  def trace_alarm_operation(alarm_id, operation, alarm_context \\ %{}, fun) do
    span_name = "alarm.#{operation}"

    attributes = %{
      "alarm.id" => alarm_id,
      "alarm.type" => alarm_context[:incident_type],
      "alarm.priority" => alarm_context[:priority],
      "alarm.source" => alarm_context[:source],
      "operation.name" => operation,
      "operation.type" => "alarm"
    }

    with_span(span_name, attributes, fun)
  end

  @doc """
  Creates a trace span for video operations with video - specific attributes.
  """
  @spec trace_video_operation(String.t(), String.t(), map(), function()) ::
          any()
  @spec trace_video_operation(binary() | integer(), term(), binary() | integer(), term()) ::
          term()
  def trace_video_operation(camera_id, operation, video_context \\ %{}, fun) do
    span_name = "video.#{operation}"

    attributes = %{
      "video.camera_id" => camera_id,
      "video.stream_type" => video_context[:stream_type],
      "video.resolution" => video_context[:resolution],
      "video.codec" => video_context[:codec],
      "operation.name" => operation,
      "operation.type" => "video"
    }

    with_span(span_name, attributes, fun)
  end

  @doc """
  Creates a trace span for external API calls with retry logic.
  """
  @spec trace_external_call(String.t(), String.t(), map(), function()) ::
          any()
  @spec trace_external_call(binary(), term(), map(), term()) :: term()
  def trace_external_call(service_name, endpoint, request_context \\ %{}, fun) do
    span_name = "external.#{service_name}"

    attributes = %{
      "external.service" => service_name,
      "external.endpoint" => endpoint,
      "external.method" => request_context[:method] || "GET",
      "external.timeout" => request_context[:timeout],
      "operation.type" => "external_api"
    }

    with_span(span_name, attributes, fun)
  end

  # Private helper functions

  @spec set_span_attributes(map()) :: :ok
  defp set_span_attributes(attributes) when is_map(attributes) do
    # Convert all values to strings and filter out nil values
    string_attributes =
      attributes
      |> Enum.filter(fn {_k, v} -> not is_nil(v) end)
      |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)

    Tracer.set_attributes(string_attributes)
  end

  @spec handle_span_error(Exception.t(), String.t(), map()) :: :ok
  defp handle_span_error(error, span_name, attributes) do
    # Set error attributes on span
    Tracer.set_attributes([
      {"error.occurred", true},
      {"error.type", error.__struct__ |> to_string()},
      {"error.message", Exception.message(error)},
      {"operation.success", false}
    ])

    # Log error with context
    Logger.error("Traced operation failed",
      span_name: span_name,
      error_type: error.__struct__,
      error_message: Exception.message(error),
      attributes: attributes
    )

    # Emit error telemetry
    Indrajaal.Errors.emit_error_telemetry(error, %{
      span_name: span_name,
      attributes: attributes
    })
  end

  # Made public for use in resource helpers
  @spec extract_resource_name(atom() | struct()) :: String.t()
  def extract_resource_name(resource) when is_atom(resource) do
    resource
    |> to_string()
    |> String.split(".")
    |> List.last()
    |> Macro.underscore()
  end

  @spec extract_resource_name(any()) :: any()
  def extract_resource_name(%{__struct__: module}) do
    extract_resource_name(module)
  end

  @spec extract_resource_name(any()) :: any()
  def extract_resource_name(%{resource: resource}) when is_atom(resource) do
    extract_resource_name(resource)
  end

  @spec extract_resource_name(any()) :: any()
  # def extract_resource_name(resource), do: to_string(resource)
  # Claude Agent: EP-076 - Unreachable function clause commented
  @spec extract_domain_name(any()) :: String.t()
  defp extract_domain_name(resource) when is_atom(resource) do
    parts = String.split(to_string(resource), ".")

    case parts do
      ["Elixir", "Indrajaal", domain | _] -> Macro.underscore(domain)
      _ -> "unknown"
    end
  end

  @spec extract_domain_name(term()) :: term()
  defp extract_domain_name(_), do: "unknown"

  @spec extract_actor_type(any()) :: String.t()
  defp extract_actor_type(%{__struct__: struct}) do
    extract_resource_name(struct)
  end

  @spec extract_actor_type(term()) :: term()
  defp extract_actor_type(_), do: "unknown"

  # @doc """
  # Extract tenant ID from actor for public use in resources.
  # """
  # @spec extract_tenant_id(any()) :: String.t() | nil
  # def extract_tenant_id(actor), do: extract_tenant_id_internal(actor)
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Extract actor ID from actor for public use in resources.
  """
  @spec extract_actor_id(any()) :: String.t() | nil
  def extract_actor_id(actor), do: extract_actor_id_internal(actor)

  @doc """
  Extract tenant ID from actor for public use in resources.
  """
  @spec extract_tenant_id(any()) :: String.t() | nil
  def extract_tenant_id(actor), do: extract_tenant_id_internal(actor)

  @spec extract_tenant_id_internal(any()) :: String.t() | nil
  defp extract_tenant_id_internal(%{tenant_id: tenant_id}), do: tenant_id
  defp extract_tenant_id_internal(_), do: nil

  @spec extract_actor_id_internal(any()) :: String.t() | nil
  defp extract_actor_id_internal(%{id: id}), do: id
  defp extract_actor_id_internal(_), do: nil
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
