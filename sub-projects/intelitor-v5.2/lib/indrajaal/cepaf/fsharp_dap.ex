defmodule Indrajaal.Cepaf.FsharpDap do
  @moduledoc """
  F# Debug Adapter Protocol (DAP) wrapper — Elixir side.

  Provides pure functions for constructing, parsing, and validating DAP
  protocol messages exchanged with the F# language server / debug adapter.
  This module does NOT start any process or open any socket; it is a pure
  message-formatting layer intended to be used by a transport GenServer.

  ## DAP Message Structure

  Every DAP message is a JSON object with a `seq` integer, `type` field
  (request | response | event), and a `command`/`event` string plus body.

  ## STAMP Constraints
  - SC-MCP-001: MCP tool dispatch must be validated — ENFORCED
  - SC-DEBUG-001: Debug telemetry bus requires message validation — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type seq :: pos_integer()
  @type dap_type :: :request | :response | :event
  @type dap_message :: %{
          seq: seq(),
          type: dap_type(),
          command: String.t() | nil,
          event: String.t() | nil,
          body: map() | nil,
          success: boolean() | nil,
          request_seq: seq() | nil
        }

  @doc """
  Build a DAP initialize request message.
  """
  @spec initialize_request(seq(), map()) :: dap_message()
  def initialize_request(seq, capabilities \\ %{}) when is_integer(seq) and seq > 0 do
    %{
      seq: seq,
      type: :request,
      command: "initialize",
      event: nil,
      body: Map.merge(default_client_capabilities(), capabilities),
      success: nil,
      request_seq: nil
    }
  end

  @doc """
  Build a DAP launch request for an F# project.
  """
  @spec launch_request(seq(), String.t(), keyword()) :: dap_message()
  def launch_request(seq, project_path, opts \\ [])
      when is_integer(seq) and seq > 0 and is_binary(project_path) do
    %{
      seq: seq,
      type: :request,
      command: "launch",
      event: nil,
      body: %{
        program: project_path,
        noDebug: Keyword.get(opts, :no_debug, false),
        stopAtEntry: Keyword.get(opts, :stop_at_entry, false),
        console: Keyword.get(opts, :console, "integratedTerminal")
      },
      success: nil,
      request_seq: nil
    }
  end

  @doc """
  Build a DAP set-breakpoint request.
  """
  @spec set_breakpoints_request(seq(), String.t(), [pos_integer()]) :: dap_message()
  def set_breakpoints_request(seq, source_path, lines)
      when is_integer(seq) and seq > 0 and is_binary(source_path) and is_list(lines) do
    breakpoints = Enum.map(lines, &%{line: &1})

    %{
      seq: seq,
      type: :request,
      command: "setBreakpoints",
      event: nil,
      body: %{
        source: %{path: source_path},
        breakpoints: breakpoints
      },
      success: nil,
      request_seq: nil
    }
  end

  @doc """
  Build a DAP disconnect request.
  """
  @spec disconnect_request(seq(), boolean()) :: dap_message()
  def disconnect_request(seq, terminate_debuggee \\ false) when is_integer(seq) and seq > 0 do
    %{
      seq: seq,
      type: :request,
      command: "disconnect",
      event: nil,
      body: %{terminateDebuggee: terminate_debuggee},
      success: nil,
      request_seq: nil
    }
  end

  @doc """
  Parse a raw DAP response map into a typed dap_message. Returns {:ok, msg} or {:error, reason}.
  """
  @spec parse_response(map()) :: {:ok, dap_message()} | {:error, String.t()}
  def parse_response(%{"seq" => seq, "type" => type_str} = raw)
      when is_integer(seq) and is_binary(type_str) do
    case parse_type(type_str) do
      {:ok, type} ->
        msg = %{
          seq: seq,
          type: type,
          command: Map.get(raw, "command"),
          event: Map.get(raw, "event"),
          body: Map.get(raw, "body"),
          success: Map.get(raw, "success"),
          request_seq: Map.get(raw, "request_seq")
        }

        {:ok, msg}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse_response(raw) do
    {:error, "invalid DAP message: missing seq or type, got: #{inspect(Map.keys(raw))}"}
  end

  @doc """
  Serialize a dap_message to a plain map suitable for JSON encoding.
  """
  @spec serialize(dap_message()) :: map()
  def serialize(%{seq: seq, type: type} = msg) when is_integer(seq) do
    base = %{
      "seq" => seq,
      "type" => Atom.to_string(type)
    }

    base
    |> maybe_put("command", msg.command)
    |> maybe_put("event", msg.event)
    |> maybe_put("body", msg.body)
    |> maybe_put("success", msg.success)
    |> maybe_put("request_seq", msg.request_seq)
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  @spec parse_type(String.t()) :: {:ok, dap_type()} | {:error, String.t()}
  defp parse_type("request"), do: {:ok, :request}
  defp parse_type("response"), do: {:ok, :response}
  defp parse_type("event"), do: {:ok, :event}
  defp parse_type(other), do: {:error, "unknown DAP type: #{inspect(other)}"}

  @spec default_client_capabilities() :: map()
  defp default_client_capabilities do
    %{
      clientID: "indrajaal",
      clientName: "Indrajaal Prajna",
      adapterID: "fsharp",
      locale: "en-US",
      linesStartAt1: true,
      columnsStartAt1: true,
      supportsVariableType: true,
      supportsEvaluateForHovers: true,
      supportsProgressReporting: true
    }
  end

  @spec maybe_put(map(), String.t(), term()) :: map()
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
