defmodule Indrajaal.MCP.Foundation.Supervisor do
  @moduledoc """
  MCP Foundation Supervisor

  WHAT: Supervises all MCP foundation services
  WHY: Ensures fault tolerance and automatic restart of MCP components
  CONSTRAINTS: SC-MCP-060 (supervision tree), SC-MCP-061 (restart strategy)

  ## Supervised Children
  - Registry: Tool registration and discovery
  - Auth: Authentication and rate limiting
  - Server: Main MCP request handler

  ## STAMP Constraints
  - SC-MCP-060: All MCP services MUST be supervised
  - SC-MCP-061: Restart strategy MUST be one_for_one
  - SC-MCP-062: Max restarts MUST be limited to 3 per 5 seconds
  """

  use Supervisor

  @doc """
  Starts the MCP Foundation Supervisor.
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    transport = Keyword.get(opts, :transport, :stdio)
    port = Keyword.get(opts, :port, 9999)

    children = [
      # Registry must start first
      {Indrajaal.MCP.Foundation.Registry, []},

      # Auth service
      {Indrajaal.MCP.Foundation.Auth, []},

      # Main server (depends on Registry and Auth)
      {Indrajaal.MCP.Foundation.Server, transport: transport, port: port}
    ]

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 3, max_seconds: 5)
  end

  @doc """
  Returns child specifications for embedding in application supervisor.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent
    }
  end
end
