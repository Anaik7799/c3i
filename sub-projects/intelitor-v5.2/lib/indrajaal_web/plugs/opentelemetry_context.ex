defmodule IndrajaalWeb.Plugs.OpenTelemetryContext do
  @moduledoc """
  Plug to integrate OpenTelemetry tracing with Phoenix requests.

  This plug:
  - Extracts trace context from incoming requests
  - Creates spans for HTTP requests
  - Enriches logger metadata with trace information
  - Ensures tenant context is preserved (STAMP SC2)
  """

  import Plug.Conn
  require Logger
  require OpenTelemetry.Tracer

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    # Extract tenant context early
    tenant_id = get_tenant_id(conn)

    # Start root span for the request
    attributes = %{
      "http.method" => conn.method,
      "http.target" => conn.request_path,
      "http.host" => conn.host,
      "http.scheme" => conn.scheme |> to_string(),
      "http.user_agent" => get_user_agent(conn),
      "http.client_ip" => get_client_ip(conn),
      "tenant.id" => tenant_id,
      "phoenix.controller" => nil,
      "phoenix.action" => nil,
      "phoenix.format" => nil
    }

    OpenTelemetry.Tracer.with_span "HTTP #{conn.method} #{conn.request_path}",
                                   %{
                                     attributes: attributes,
                                     kind: :server
                                   } do
      # Enrich logger metadata
      Indrajaal.Observability.TelemetryEnhancement.enrich_logger_metadata()
      # Logger metadata configured globally

      # Register before_send callback to complete the span
      conn
      |> put_private(:otel_span_ctx, :otel_tracer.current_span_ctx())
      |> register_before_send(&complete_span/1)
    end
  end

  @spec complete_span(Plug.Conn.t()) :: Plug.Conn.t()
  defp complete_span(conn) do
    ctx = conn.private[:otel_span_ctx]

    if ctx && ctx != :undefined do
      # Update span with response information
      content_type_header = get_resp_header(conn, "content-type")

      attributes = %{
        "http.status_code" => conn.status,
        "http.response_content_type" => List.first(content_type_header)
      }

      # Add controller/action info if available
      attributes =
        if conn.private[:phoenix_controller] do
          Map.merge(attributes, %{
            "phoenix.controller" => conn.private.phoenix_controller |> inspect(),
            "phoenix.action" => conn.private.phoenix_action |> to_string(),
            "phoenix.format" => conn.private.phoenix_format || "html"
          })
        else
          attributes
        end

      if Code.ensure_loaded?(OpenTelemetry) do
        OpenTelemetry.Tracer.set_attributes(format_otel_attributes(attributes))
      end

      # Set span status based on HTTP status
      status =
        case conn.status do
          status when status >= 500 -> :error
          status when status >= 400 -> :error
          _ -> :ok
        end

      if status == :error do
        if Code.ensure_loaded?(OpenTelemetry) do
          OpenTelemetry.Tracer.set_status(status)
        end
      end

      # Record custom metrics (only if start time was recorded)
      req_start_time = conn.private[:req_start_time]

      if req_start_time do
        :telemetry.execute(
          [:indrajaal, :http, :request],
          %{duration: System.monotonic_time() - req_start_time},
          %{
            method: conn.method,
            path: conn.request_path,
            status: conn.status,
            tenant_id: get_tenant_id(conn)
          }
        )
      end
    end

    conn
  end

  @spec get_tenant_id(Plug.Conn.t()) :: String.t()
  defp get_tenant_id(conn) do
    # Try multiple sources for tenant ID
    tenant_header = get_req_header(conn, "x-tenant-id")

    conn.assigns[:tenant_id] ||
      tenant_header |> List.first() ||
      conn.params["tenant_id"] ||
      "default"
  end

  @spec get_user_agent(Plug.Conn.t()) :: String.t()
  defp get_user_agent(conn) do
    user_agent_header = get_req_header(conn, "user-agent")
    user_agent_header |> List.first() || "unknown"
  end

  @spec get_client_ip(Plug.Conn.t()) :: String.t()
  defp get_client_ip(conn) do
    # Handle X-Forwarded-For and similar headers
    forwarded_header = get_req_header(conn, "x-forwarded-for")
    forwarded_for = forwarded_header |> List.first()

    if forwarded_for do
      # Take the first IP from the list
      forwarded_for
      |> String.split(",")
      |> List.first()
      |> String.trim()
    else
      # Fall back to remote_ip
      conn.remote_ip
      |> :inet.ntoa()
      |> to_string()
    end
  end

  @spec format_otel_attributes(list() | map()) :: list()
  defp format_otel_attributes(attributes) when is_list(attributes) do
    attributes
    |> Enum.filter(fn {_k, v} -> v != nil end)
    |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  defp format_otel_attributes(attributes) when is_map(attributes) do
    attributes
    |> Map.to_list()
    |> format_otel_attributes()
  end

  defp format_otel_attributes(attributes), do: attributes
end
