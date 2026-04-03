defmodule Indrajaal.MCP.Foundation.Server do
  @moduledoc """
  MCP Server - Main GenServer for Model Context Protocol

  WHAT: Primary MCP server handling stdio/SSE/HTTP transport with dual-mode
        auto-detection for localhost vs remote operation.
  WHY: Provides AI tool integration for Claude and other LLM clients
  CONSTRAINTS: SC-MCP-050 (server availability), SC-MCP-051 (graceful shutdown)

  ## Transport Modes (SC-MCP-075, SC-MCP-076)
  - **stdio**: Standard I/O for local CLI integration (default)
  - **sse**: Server-Sent Events for remote HTTP clients
  - **http**: HTTP/REST for web integration
  - **websocket**: WebSocket for real-time streaming

  ## Dual Mode Auto-Detection (SC-MCP-076)
  Transport mode is auto-detected at startup:
  - `MCP_SSE_PORT` env var set → SSE mode
  - `MCP_REMOTE=true` env var → SSE mode
  - `--transport sse` option → SSE mode
  - Otherwise → stdio mode (localhost default)

  ## STAMP Constraints
  - SC-MCP-050: Server MUST maintain 99.9% availability
  - SC-MCP-051: Server MUST handle graceful shutdown
  - SC-MCP-052: Server MUST respect backpressure
  - SC-MCP-053: Server MUST log all requests/responses
  - SC-MCP-075: Dual mode MUST be transparent to tool handlers
  - SC-MCP-076: Auto-detect MUST prefer stdio for local connections
  """

  use GenServer
  require Logger

  alias Indrajaal.MCP.Foundation.{Protocol, Dispatcher, Registry, Auth, SSETransport}

  @default_transport :stdio

  # Client API

  @doc """
  Starts the MCP server.

  ## Options
  - `:transport` - Transport mode (:stdio, :http, :websocket)
  - `:port` - Port for HTTP/WebSocket transport (default: 9999)
  - `:name` - GenServer name (default: __MODULE__)
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Handles an incoming MCP request.
  """
  @spec handle_request(String.t(), map()) :: String.t()
  def handle_request(raw_request, context \\ %{}) do
    GenServer.call(__MODULE__, {:handle_request, raw_request, context})
  end

  @doc """
  Handles a parsed MCP request.
  """
  @spec handle_parsed_request(map(), map()) :: {:ok, term()} | {:error, term()}
  def handle_parsed_request(request, context \\ %{}) do
    GenServer.call(__MODULE__, {:handle_parsed_request, request, context})
  end

  @doc """
  Gets server status.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Stops the server gracefully.
  """
  @spec stop() :: :ok
  def stop do
    GenServer.stop(__MODULE__, :normal)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Auto-detect transport mode (SC-MCP-076)
    explicit_transport = Keyword.get(opts, :transport, @default_transport)
    transport = resolve_transport(explicit_transport)
    port = Keyword.get(opts, :port, 9999)

    Logger.info("Starting MCP server with transport: #{transport}")

    # Start child services
    ensure_services_started()

    # Initialize telemetry
    attach_telemetry()

    state = %{
      transport: transport,
      port: port,
      started_at: DateTime.utc_now(),
      request_count: 0,
      error_count: 0
    }

    # Start transport-specific listener
    case transport do
      :stdio ->
        # For stdio, we'll be called directly via handle_request/2
        Logger.info("MCP server in stdio mode (localhost)")

      :sse ->
        # Start SSE transport server for remote clients (SC-MCP-070)
        sse_port = resolve_sse_port(opts)

        case SSETransport.start_link(port: sse_port) do
          {:ok, _pid} ->
            Logger.info("MCP SSE transport started on port #{sse_port}")

          {:error, {:already_started, _pid}} ->
            Logger.info("MCP SSE transport already running on port #{sse_port}")

          {:error, reason} ->
            Logger.warning(
              "MCP SSE transport failed to start: #{inspect(reason)}, falling back to stdio"
            )
        end

      :http ->
        Logger.info("HTTP transport would start on port #{port}")

      :websocket ->
        Logger.info("WebSocket transport would start on port #{port}")
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:handle_request, raw_request, context}, _from, state) do
    response = Dispatcher.dispatch_raw(raw_request, context)
    new_state = update_stats(state, response)
    {:reply, response, new_state}
  end

  @impl true
  def handle_call({:handle_parsed_request, request, context}, _from, state) do
    result = Dispatcher.dispatch(request, context)

    new_state =
      case result do
        {:ok, _} ->
          %{state | request_count: state.request_count + 1}

        {:error, _} ->
          %{state | request_count: state.request_count + 1, error_count: state.error_count + 1}
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      transport: state.transport,
      port: state.port,
      started_at: state.started_at,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
      request_count: state.request_count,
      error_count: state.error_count,
      error_rate: calculate_error_rate(state),
      tool_count: Registry.count(),
      tools_by_namespace: Registry.count_by_namespace(),
      mcp_version: Protocol.version()
    }

    {:reply, status, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("MCP server stopping: #{inspect(reason)}")
    detach_telemetry()
    log_shutdown_stats(state)
    :ok
  end

  # Private functions

  defp ensure_services_started do
    # Ensure Registry is started
    case Registry.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # Ensure Auth is started
    case Auth.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # Register default tools
    register_default_tools()
  end

  defp register_default_tools do
    # Register some basic tools for testing
    tools = [
      Indrajaal.MCP.Foundation.Types.new_tool_schema(
        "indrajaal.system.health",
        "Get system health status",
        %{type: "object", properties: %{}, required: []}
      ),
      Indrajaal.MCP.Foundation.Types.new_tool_schema(
        "indrajaal.system.version",
        "Get system version information",
        %{type: "object", properties: %{}, required: []}
      ),
      Indrajaal.MCP.Foundation.Types.new_tool_schema(
        "prajna.guardian.status",
        "Get Guardian safety kernel status",
        %{type: "object", properties: %{}, required: []}
      ),
      Indrajaal.MCP.Foundation.Types.new_tool_schema(
        "prajna.sentinel.health",
        "Get Sentinel health monitor status",
        %{type: "object", properties: %{}, required: []}
      )
    ]

    Registry.register_all(tools)
  end

  defp attach_telemetry do
    :telemetry.attach_many(
      "mcp-server-telemetry",
      [
        [:mcp, :dispatch],
        [:mcp, :error],
        [:mcp, :rate_limit]
      ],
      &handle_telemetry_event/4,
      nil
    )
  end

  defp detach_telemetry do
    :telemetry.detach("mcp-server-telemetry")
  end

  defp handle_telemetry_event([:mcp, :dispatch], measurements, metadata, _config) do
    Logger.debug("MCP telemetry: dispatch count=#{measurements.count} method=#{metadata.method}")
  end

  defp handle_telemetry_event([:mcp, :error], measurements, metadata, _config) do
    Logger.warning("MCP telemetry: error count=#{measurements.count} reason=#{metadata.reason}")
  end

  defp handle_telemetry_event([:mcp, :rate_limit], measurements, metadata, _config) do
    Logger.warning(
      "MCP telemetry: rate_limit count=#{measurements.count} client=#{metadata.client_id}"
    )
  end

  defp update_stats(state, response) do
    decoded = Jason.decode!(response)

    if Map.has_key?(decoded, "error") do
      %{state | request_count: state.request_count + 1, error_count: state.error_count + 1}
    else
      %{state | request_count: state.request_count + 1}
    end
  end

  defp calculate_error_rate(%{request_count: 0}), do: 0.0

  defp calculate_error_rate(%{request_count: total, error_count: errors}) do
    Float.round(errors / total * 100, 2)
  end

  defp log_shutdown_stats(state) do
    Logger.info("""
    MCP Server Shutdown Stats:
    - Uptime: #{DateTime.diff(DateTime.utc_now(), state.started_at)} seconds
    - Total requests: #{state.request_count}
    - Total errors: #{state.error_count}
    - Error rate: #{calculate_error_rate(state)}%
    """)
  end

  # Auto-detect transport mode (SC-MCP-076)
  # SSE if env vars indicate remote mode, stdio otherwise
  defp resolve_transport(:stdio) do
    SSETransport.detect_transport_mode()
  end

  defp resolve_transport(explicit), do: explicit

  defp resolve_sse_port(opts) do
    case Keyword.get(opts, :sse_port) do
      nil ->
        case System.get_env("MCP_SSE_PORT") do
          nil -> 9998
          port_str -> String.to_integer(port_str)
        end

      port ->
        port
    end
  end
end
