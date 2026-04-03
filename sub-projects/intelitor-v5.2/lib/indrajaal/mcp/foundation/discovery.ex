defmodule Indrajaal.MCP.Foundation.Discovery do
  @moduledoc """
  MCP Tool Discovery — Lists all available MCP tools

  WHAT: Provides tool discovery for MCP clients to enumerate available tools,
        their schemas, namespaces, and required permissions.
  WHY: MCP clients need to discover available tools at runtime (SC-MCP-071).
  CONSTRAINTS: SC-MCP-071, SC-MCP-050

  ## Discovery Capabilities
  - List all registered tools with full schemas
  - Filter by namespace (indrajaal, prajna, cepaf, kms)
  - Search by keyword in name or description
  - Count tools by namespace
  - Full discovery response for MCP tools/list endpoint

  ## STAMP Constraints
  - SC-MCP-071: Tool discovery MUST list all available tools
  - SC-MCP-050: Tool schemas MUST be fully described in discovery

  ## Change History
  | Version | Date       | Author          | Change                 |
  |---------|------------|-----------------|------------------------|
  | 21.3.0  | 2026-03-23 | Claude Opus 4.6 | Initial implementation |
  """

  alias Indrajaal.MCP.Foundation.Registry

  @server_version "21.3.0"

  @doc """
  List all registered tools with their schemas.

  Returns all tools sorted by name (delegated to Registry).
  """
  @spec list_tools() :: list(map())
  def list_tools do
    Registry.list()
  end

  @doc """
  List tools filtered by namespace string.

  Filters by matching tools whose name begins with `namespace <> "."`.
  Returns an empty list if the namespace is unknown.

  ## Examples

      iex> Discovery.list_tools_by_namespace("prajna")
      [%{name: "prajna.guardian.propose", ...}, ...]

  """
  @spec list_tools_by_namespace(String.t()) :: list(map())
  def list_tools_by_namespace(namespace) when is_binary(namespace) do
    prefix = namespace <> "."

    Registry.list()
    |> Enum.filter(fn tool ->
      String.starts_with?(tool.name, prefix)
    end)
  end

  @doc """
  Get tool count by namespace.

  Returns a map of namespace atom to count integer.

  ## Examples

      iex> Discovery.tool_counts()
      %{indrajaal: 5, prajna: 3, cepaf: 2, kms: 1}

  """
  @spec tool_counts() :: map()
  def tool_counts do
    Registry.count_by_namespace()
  end

  @doc """
  Search tools by keyword in name or description.

  Case-insensitive substring match across both `name` and `description` fields.

  ## Examples

      iex> Discovery.search_tools("alarm")
      [%{name: "indrajaal.alarms.list", ...}, ...]

  """
  @spec search_tools(String.t()) :: list(map())
  def search_tools(query) when is_binary(query) do
    query_lower = String.downcase(query)

    Registry.list()
    |> Enum.filter(fn tool ->
      String.contains?(String.downcase(tool.name), query_lower) ||
        String.contains?(String.downcase(tool.description || ""), query_lower)
    end)
  end

  @doc """
  Get full discovery response for MCP tools/list endpoint.

  Returns a map containing tools list, total count, namespace breakdown,
  server version, and generation timestamp.

  ## Examples

      iex> Discovery.discovery_response()
      %{tools: [...], total: 344, namespaces: %{indrajaal: 180, ...}, ...}

  """
  @spec discovery_response() :: map()
  def discovery_response do
    tools = list_tools()

    %{
      tools: tools,
      total: length(tools),
      namespaces: tool_counts(),
      server_version: @server_version,
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
end
