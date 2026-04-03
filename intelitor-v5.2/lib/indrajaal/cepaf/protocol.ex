defmodule Indrajaal.Cepaf.Protocol do
  @moduledoc """
  JSON-RPC 2.0 protocol helpers for Cepaf.Bridge communication.

  This module handles encoding requests and decoding responses
  according to the JSON-RPC 2.0 specification.
  """

  @jsonrpc_version "2.0"

  @doc """
  Encode a JSON-RPC request.

  ## Examples

      iex> Protocol.encode_request("1", "system.ping", %{})
      ~s({"jsonrpc":"2.0","id":"1","method":"system.ping","params":{}})

  """
  def encode_request(id, method, params) do
    %{
      jsonrpc: @jsonrpc_version,
      id: id,
      method: method,
      params: params
    }
    |> Jason.encode!()
  end

  @doc """
  Encode a JSON-RPC notification (no id, no response expected).
  """
  def encode_notification(method, params) do
    %{
      jsonrpc: @jsonrpc_version,
      method: method,
      params: params
    }
    |> Jason.encode!()
  end

  @doc """
  Decode a JSON-RPC response.

  Returns:
    * `{:ok, result}` for success responses
    * `{:error, code, message, data}` for error responses
    * `{:error, :invalid_response}` for malformed responses
  """
  def decode_response(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, response} -> decode_response_map(response)
      {:error, _} -> {:error, :parse_error, "Invalid JSON", nil}
    end
  end

  defp decode_response_map(%{"jsonrpc" => "2.0", "result" => result}) do
    {:ok, result}
  end

  defp decode_response_map(%{"jsonrpc" => "2.0", "error" => error}) do
    code = Map.get(error, "code", -32_603)
    message = Map.get(error, "message", "Unknown error")
    data = Map.get(error, "data")
    {:error, code, message, data}
  end

  defp decode_response_map(_) do
    {:error, :invalid_response, "Invalid JSON-RPC response", nil}
  end

  @doc """
  Convert a JSON-RPC error code to an Elixir atom.
  """
  def error_code_to_atom(code) do
    case code do
      # Standard JSON-RPC errors
      -32_700 -> :parse_error
      -32_600 -> :invalid_request
      -32_601 -> :method_not_found
      -32_602 -> :invalid_params
      -32_603 -> :internal_error
      # Application-specific errors
      -32_001 -> :socket_not_found
      -32_002 -> :connection_refused
      -32_003 -> :connection_timeout
      -32_004 -> :container_not_found
      -32_005 -> :container_exists
      -32_006 -> :image_not_found
      -32_007 -> :health_check_failed
      -32_008 -> :safety_violation
      -32_009 -> :network_not_found
      -32_010 -> :volume_not_found
      _ -> :unknown_error
    end
  end

  @doc """
  Convert an Elixir error atom to a JSON-RPC error code.
  """
  def atom_to_error_code(atom) do
    case atom do
      :parse_error -> -32_700
      :invalid_request -> -32_600
      :method_not_found -> -32_601
      :invalid_params -> -32_602
      :internal_error -> -32_603
      :socket_not_found -> -32_001
      :connection_refused -> -32_002
      :connection_timeout -> -32_003
      :container_not_found -> -32_004
      :container_exists -> -32_005
      :image_not_found -> -32_006
      :health_check_failed -> -32_007
      :safety_violation -> -32_008
      :network_not_found -> -32_009
      :volume_not_found -> -32_010
      _ -> -32_603
    end
  end

  @doc """
  Check if an error is retryable.
  """
  def retryable_error?(code) when is_integer(code) do
    code in [-32_002, -32_003]
  end

  def retryable_error?(atom) when is_atom(atom) do
    atom in [:connection_refused, :connection_timeout]
  end
end
