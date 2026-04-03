defmodule Indrajaal.MCP.Cepaf.Handler do
  @moduledoc """
  MCP Handler for CEPAF (F# Cortex).

  WHAT: Bridges Elixir logic to F# orchestration via Stdio Port.
  WHY: Enables access to high-performance graph algorithms and Podman control.
  CONSTRAINTS: SC-MCP-050 (F# interop).
  """

  use GenServer
  require Logger
  # alias Indrajaal.MCP.Foundation.Types

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def handle(action, args, _context) do
    GenServer.call(__MODULE__, {:call_tool, action, args}, 30_000)
  end

  def list_tools do
    GenServer.call(__MODULE__, :list_tools, 10_000)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Assuming compiled artifact exists
    cmd = "dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- --mcp"
    port = Port.open({:spawn, cmd}, [:binary, :line, :exit_status])
    {:ok, %{port: port, requests: %{}}}
  end

  @impl true
  def handle_call({:call_tool, action, args}, from, state) do
    id = make_ref() |> inspect()

    req = %{
      jsonrpc: "2.0",
      id: id,
      method: "tools/call",
      params: %{name: "cepaf.#{action}", arguments: args}
    }

    Port.command(state.port, Jason.encode!(req) <> "\n")

    # Store caller to reply later
    requests = Map.put(state.requests, id, from)
    {:noreply, %{state | requests: requests}}
  end

  @impl true
  def handle_call(:list_tools, from, state) do
    id = make_ref() |> inspect()

    req = %{
      jsonrpc: "2.0",
      id: id,
      method: "tools/list",
      params: %{}
    }

    Port.command(state.port, Jason.encode!(req) <> "\n")
    requests = Map.put(state.requests, id, from)
    {:noreply, %{state | requests: requests}}
  end

  @impl true
  def handle_info({_port, {:data, {:eol, line}}}, state) do
    case Jason.decode(line) do
      {:ok, %{"id" => id, "result" => result}} ->
        {from, requests} = Map.pop(state.requests, id)

        if from do
          GenServer.reply(from, {:ok, result})
        end

        {:noreply, %{state | requests: requests}}

      _ ->
        Logger.warning("[CEPAF] Invalid JSON from F#: #{line}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({_port, {:exit_status, status}}, state) do
    Logger.error("[CEPAF] F# process exited with status: #{status}")
    {:stop, :port_exit, state}
  end
end
