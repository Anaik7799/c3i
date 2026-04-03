defmodule Indrajaal.MCP.Foundation.Protocol do
  @moduledoc """
  MCP Protocol Implementation - JSON-RPC 2.0 Handler

  WHAT: JSON-RPC 2.0 protocol implementation for Model Context Protocol
  WHY: Provides standardized communication for AI tool integration
  CONSTRAINTS: SC-MCP-001 (JSON-RPC 2.0), SC-MCP-002 (version compliance)

  ## Protocol Version
  Implements MCP 2025-11-25 specification with extensions for:
  - Guardian safety approval workflow
  - PROMETHEUS proof token verification
  - Immutable Register audit logging

  ## STAMP Constraints
  - SC-MCP-001: All requests MUST be valid JSON-RPC 2.0
  - SC-MCP-002: All responses MUST include MCP version header
  - SC-MCP-003: Rate limiting MUST be enforced per client
  - SC-MCP-004: Guardian approval REQUIRED for write operations
  """

  @mcp_version "2025-11-25"
  @jsonrpc_version "2.0"

  # Standard JSON-RPC 2.0 error codes
  @error_codes %{
    parse_error: -32700,
    invalid_request: -32600,
    method_not_found: -32601,
    invalid_params: -32602,
    internal_error: -32603,
    # MCP-specific error codes (custom range -33xxx)
    guardian_veto: -33001,
    rate_limit_exceeded: -33002,
    proof_token_required: -33003,
    immutable_register_fail: -33004,
    sentinel_blocked: -33005,
    constitutional_violation: -33006
  }

  # Request types
  @type request_id :: String.t() | integer() | nil
  @type method :: String.t()
  @type params :: map() | list() | nil

  @type request :: %{
          jsonrpc: String.t(),
          id: request_id(),
          method: method(),
          params: params()
        }

  @type response :: %{
          jsonrpc: String.t(),
          id: request_id(),
          result: term()
        }

  @type error_response :: %{
          jsonrpc: String.t(),
          id: request_id(),
          error: %{
            code: integer(),
            message: String.t(),
            data: term()
          }
        }

  @doc """
  Returns the MCP protocol version.
  """
  @spec version() :: String.t()
  def version, do: @mcp_version

  @doc """
  Returns the JSON-RPC version.
  """
  @spec jsonrpc_version() :: String.t()
  def jsonrpc_version, do: @jsonrpc_version

  @doc """
  Returns all error codes.
  """
  @spec error_codes() :: map()
  def error_codes, do: @error_codes

  @doc """
  Parses a raw JSON request into a structured request map.

  ## Examples

      iex> Protocol.parse_request(~s({"jsonrpc":"2.0","id":1,"method":"tools/list"}))
      {:ok, %{jsonrpc: "2.0", id: 1, method: "tools/list", params: nil}}

  """
  @spec parse_request(String.t()) :: {:ok, request()} | {:error, error_response()}
  def parse_request(raw_json) when is_binary(raw_json) do
    case Jason.decode(raw_json) do
      {:ok, decoded} ->
        validate_request(decoded)

      {:error, _reason} ->
        {:error, error_response(nil, :parse_error, "Parse error")}
    end
  end

  @doc """
  Validates a decoded JSON request against JSON-RPC 2.0 spec.
  """
  @spec validate_request(map()) :: {:ok, request()} | {:error, error_response()}
  def validate_request(decoded) when is_map(decoded) do
    with :ok <- validate_jsonrpc_version(decoded),
         :ok <- validate_method(decoded),
         {:ok, id} <- extract_id(decoded),
         {:ok, params} <- extract_params(decoded) do
      {:ok,
       %{
         jsonrpc: @jsonrpc_version,
         id: id,
         method: decoded["method"],
         params: params
       }}
    else
      {:error, reason} ->
        id = Map.get(decoded, "id")
        {:error, error_response(id, :invalid_request, reason)}
    end
  end

  @doc """
  Creates a success response.

  ## Examples

      iex> Protocol.success_response(1, %{tools: []})
      %{jsonrpc: "2.0", id: 1, result: %{tools: []}}

  """
  @spec success_response(request_id(), term()) :: response()
  def success_response(id, result) do
    %{
      jsonrpc: @jsonrpc_version,
      id: id,
      result: result
    }
  end

  @doc """
  Creates an error response.

  ## Examples

      iex> Protocol.error_response(1, :method_not_found, "Unknown method")
      %{jsonrpc: "2.0", id: 1, error: %{code: -32601, message: "Unknown method", data: nil}}

  """
  @spec error_response(request_id(), atom(), String.t(), term()) :: error_response()
  def error_response(id, error_code, message, data \\ nil) do
    code = Map.get(@error_codes, error_code, @error_codes.internal_error)

    %{
      jsonrpc: @jsonrpc_version,
      id: id,
      error: %{
        code: code,
        message: message,
        data: data
      }
    }
  end

  @doc """
  Encodes a response to JSON string.
  """
  @spec encode_response(response() | error_response()) :: String.t()
  def encode_response(response) do
    response
    |> add_mcp_headers()
    |> Jason.encode!()
  end

  @doc """
  Creates an MCP initialize response.
  """
  @spec initialize_response(request_id(), map()) :: response()
  def initialize_response(id, server_info) do
    success_response(id, %{
      protocolVersion: @mcp_version,
      capabilities: %{
        tools: %{listChanged: true},
        resources: %{subscribe: true, listChanged: true},
        prompts: %{listChanged: true},
        logging: %{}
      },
      serverInfo: server_info
    })
  end

  @doc """
  Creates a tools/list response.
  """
  @spec tools_list_response(request_id(), list(map())) :: response()
  def tools_list_response(id, tools) do
    success_response(id, %{tools: tools})
  end

  @doc """
  Creates a tools/call response.
  """
  @spec tools_call_response(request_id(), term(), boolean()) :: response()
  def tools_call_response(id, result, is_error \\ false) do
    content =
      cond do
        is_binary(result) ->
          [%{type: "text", text: result}]

        is_map(result) ->
          [%{type: "text", text: Jason.encode!(result)}]

        true ->
          [%{type: "text", text: inspect(result)}]
      end

    success_response(id, %{
      content: content,
      isError: is_error
    })
  end

  # Private functions

  defp validate_jsonrpc_version(%{"jsonrpc" => "2.0"}), do: :ok
  defp validate_jsonrpc_version(_), do: {:error, "Invalid JSON-RPC version, must be 2.0"}

  defp validate_method(%{"method" => method}) when is_binary(method) and byte_size(method) > 0,
    do: :ok

  defp validate_method(_), do: {:error, "Method must be a non-empty string"}

  defp extract_id(%{"id" => id}) when is_binary(id) or is_integer(id), do: {:ok, id}
  defp extract_id(%{"id" => nil}), do: {:ok, nil}
  defp extract_id(%{}), do: {:ok, nil}
  defp extract_id(_), do: {:error, "Invalid id"}

  defp extract_params(%{"params" => params}) when is_map(params) or is_list(params),
    do: {:ok, params}

  defp extract_params(%{"params" => nil}), do: {:ok, nil}
  defp extract_params(%{}), do: {:ok, nil}
  defp extract_params(_), do: {:error, "Invalid params"}

  defp add_mcp_headers(response) do
    Map.put(response, :_mcp_version, @mcp_version)
  end
end
