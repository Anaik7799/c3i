defmodule Indrajaal.KMS.MCPServer do
  @moduledoc """
  Model Context Protocol (MCP) Server for Knowledge Management System.

  WHAT: Exposes KMS capabilities as MCP tools for Claude and other AI clients.
  WHY: Enables seamless integration with Claude Code, Claude Desktop, and other
       MCP-compatible AI systems for knowledge operations.

  CONSTRAINTS:
    - SC-MCP-001: All tool calls MUST be logged to audit trail
    - SC-MCP-002: Rate limiting: 100 requests/minute per client
    - SC-MCP-003: Guardian approval for write operations
    - SC-MCP-004: FHPS verification for AI-generated content

  MCP Specification: https://modelcontextprotocol.io/specification/2025-11-25

  ## Available Tools

  | Tool | Description | Operation Type |
  |------|-------------|----------------|
  | kms_search | Full-text search across holons | Read |
  | kms_get_holon | Retrieve holon by ID or FQUN | Read |
  | kms_list_holons | List holons with filtering | Read |
  | kms_create_holon | Create new knowledge holon | Write |
  | kms_update_holon | Update existing holon | Write |
  | kms_ask_oracle | Query the AI Oracle | Read |
  | kms_web_search | Search internet knowledge | Read |
  | kms_similarity_search | Vector similarity search | Read |
  | kms_health_report | System health analytics | Read |
  | kms_event_stats | Event statistics | Read |

  ## Usage with Claude Code

  Add to `.claude/settings.json`:
  ```json
  {
    "mcpServers": {
      "indrajaal-kms": {
        "command": "mix",
        "args": ["run", "--no-halt", "-e", "Indrajaal.KMS.MCPServer.start()"],
        "env": {
          "MIX_ENV": "dev"
        }
      }
    }
  }
  ```
  """

  use GenServer
  require Logger

  alias Indrajaal.KMS

  # MCP Protocol version
  @mcp_version "2025-11-25"
  @server_name "indrajaal-kms"
  @server_version "1.0.0"

  # Rate limiting
  @max_requests_per_minute 100
  @rate_window_ms 60_000

  # Tool definitions conforming to MCP specification
  @tools [
    %{
      name: "kms_search",
      description: "Full-text search across all knowledge holons in the KMS.",
      inputSchema: %{
        type: "object",
        properties: %{
          query: %{
            type: "string",
            description: "Search query string"
          },
          limit: %{
            type: "integer",
            description: "Maximum number of results (default: 20)",
            default: 20
          }
        },
        required: ["query"]
      }
    },
    %{
      name: "kms_get_holon",
      description: "Retrieve a specific holon by ID or FQUN (Fully-Qualified Unique Name).",
      inputSchema: %{
        type: "object",
        properties: %{
          id: %{
            type: "string",
            description: "Holon ID (hln_...) or FQUN"
          }
        },
        required: ["id"]
      }
    },
    %{
      name: "kms_list_holons",
      description: "List holons with optional type filtering.",
      inputSchema: %{
        type: "object",
        properties: %{
          type: %{
            type: "string",
            description: "Filter by holon type: knowledge, process, agent, artifact, index",
            enum: ["knowledge", "process", "agent", "artifact", "index"]
          },
          limit: %{
            type: "integer",
            description: "Maximum number of results (default: 50)",
            default: 50
          }
        }
      }
    },
    %{
      name: "kms_create_holon",
      description: "Create a new knowledge holon. Requires Guardian approval.",
      inputSchema: %{
        type: "object",
        properties: %{
          name: %{
            type: "string",
            description: "Human-readable name for the holon"
          },
          type: %{
            type: "string",
            description: "Holon type",
            enum: ["knowledge", "process", "agent", "artifact", "index"],
            default: "knowledge"
          },
          payload: %{
            type: "object",
            description: "Holon payload data (JSON)"
          },
          parent_id: %{
            type: "string",
            description: "Optional parent holon ID for hierarchical organization"
          }
        },
        required: ["name"]
      }
    },
    %{
      name: "kms_update_holon",
      description: "Update an existing holon. Requires Guardian approval.",
      inputSchema: %{
        type: "object",
        properties: %{
          id: %{
            type: "string",
            description: "Holon ID to update"
          },
          payload: %{
            type: "object",
            description: "New payload data (merged with existing)"
          },
          name: %{
            type: "string",
            description: "New name (optional)"
          }
        },
        required: ["id"]
      }
    },
    %{
      name: "kms_ask_oracle",
      description:
        "Ask the KMS Oracle a natural language question. Uses RAG with local knowledge.",
      inputSchema: %{
        type: "object",
        properties: %{
          query: %{
            type: "string",
            description: "Natural language question"
          },
          context: %{
            type: "string",
            description: "Additional context to include"
          }
        },
        required: ["query"]
      }
    },
    %{
      name: "kms_ask_oracle_augmented",
      description:
        "Ask the Oracle with web-augmented context. Combines local KMS with web search.",
      inputSchema: %{
        type: "object",
        properties: %{
          query: %{
            type: "string",
            description: "Natural language question"
          },
          include_web: %{
            type: "boolean",
            description: "Include web search results (default: true)",
            default: true
          }
        },
        required: ["query"]
      }
    },
    %{
      name: "kms_web_search",
      description: "Search the internet for current information. Results are cached.",
      inputSchema: %{
        type: "object",
        properties: %{
          query: %{
            type: "string",
            description: "Search query"
          },
          limit: %{
            type: "integer",
            description: "Maximum results (default: 5)",
            default: 5
          },
          store: %{
            type: "boolean",
            description: "Store results as temporary holons (default: false)",
            default: false
          }
        },
        required: ["query"]
      }
    },
    %{
      name: "kms_similarity_search",
      description: "Find holons similar to a query using vector embeddings.",
      inputSchema: %{
        type: "object",
        properties: %{
          query: %{
            type: "string",
            description: "Text to find similar holons for"
          },
          limit: %{
            type: "integer",
            description: "Maximum results (default: 10)",
            default: 10
          },
          threshold: %{
            type: "number",
            description: "Minimum similarity threshold 0-1 (default: 0.7)",
            default: 0.7
          }
        },
        required: ["query"]
      }
    },
    %{
      name: "kms_health_report",
      description: "Get system health report with vital signs across all holons.",
      inputSchema: %{
        type: "object",
        properties: %{}
      }
    },
    %{
      name: "kms_event_stats",
      description: "Get event statistics over a time period.",
      inputSchema: %{
        type: "object",
        properties: %{
          days: %{
            type: "integer",
            description: "Number of days to analyze (default: 30)",
            default: 30
          }
        }
      }
    },
    %{
      name: "kms_get_children",
      description: "Get all child holons of a parent holon.",
      inputSchema: %{
        type: "object",
        properties: %{
          parent_id: %{
            type: "string",
            description: "Parent holon ID"
          }
        },
        required: ["parent_id"]
      }
    },
    %{
      name: "kms_get_edges",
      description: "Get all relationships (edges) for a holon.",
      inputSchema: %{
        type: "object",
        properties: %{
          holon_id: %{
            type: "string",
            description: "Holon ID to get edges for"
          }
        },
        required: ["holon_id"]
      }
    },
    %{
      name: "kms_create_edge",
      description: "Create a relationship between two holons. Requires Guardian approval.",
      inputSchema: %{
        type: "object",
        properties: %{
          source_id: %{
            type: "string",
            description: "Source holon ID"
          },
          target_id: %{
            type: "string",
            description: "Target holon ID"
          },
          relation: %{
            type: "string",
            description: "Relationship type (e.g., 'references', 'depends_on', 'child_of')"
          },
          weight: %{
            type: "number",
            description: "Relationship weight 0-1 (default: 1.0)",
            default: 1.0
          }
        },
        required: ["source_id", "target_id", "relation"]
      }
    }
  ]

  # Resources (data sources exposed to clients)
  @resources [
    %{
      uri: "kms://holons",
      name: "Knowledge Holons",
      description: "All holons in the Knowledge Management System",
      mimeType: "application/json"
    },
    %{
      uri: "kms://health",
      name: "System Health",
      description: "Current health status of the KMS",
      mimeType: "application/json"
    }
  ]

  # State structure
  defstruct [
    :started_at,
    :request_count,
    :rate_limit_window_start,
    :clients,
    :audit_log
  ]

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Starts the MCP server as a standalone process.
  """
  def start do
    case start_link([]) do
      {:ok, pid} ->
        Logger.info("[MCP] Indrajaal KMS MCP Server started: #{inspect(pid)}")
        run_stdio_loop(pid)

      {:error, reason} ->
        Logger.error("[MCP] Failed to start: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Starts the MCP server under supervision.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Handle an incoming MCP request.
  """
  def handle_request(request) do
    GenServer.call(__MODULE__, {:handle_request, request}, 30_000)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      started_at: DateTime.utc_now(),
      request_count: 0,
      rate_limit_window_start: System.monotonic_time(:millisecond),
      clients: %{},
      audit_log: []
    }

    Logger.info("[MCP] KMS MCP Server initialized (version #{@mcp_version})")
    {:ok, state}
  end

  @impl true
  def handle_call({:handle_request, request}, _from, state) do
    # Rate limiting check
    state = check_rate_limit(state)

    if state.request_count > @max_requests_per_minute do
      response = error_response(-32000, "Rate limit exceeded", request["id"])
      {:reply, response, state}
    else
      {response, state} = process_request(request, state)
      {:reply, response, %{state | request_count: state.request_count + 1}}
    end
  end

  # ============================================================================
  # MCP Protocol Handlers
  # ============================================================================

  defp process_request(%{"method" => "initialize", "id" => id} = request, state) do
    Logger.info("[MCP] Client initializing: #{inspect(request["params"])}")

    response = %{
      jsonrpc: "2.0",
      id: id,
      result: %{
        protocolVersion: @mcp_version,
        serverInfo: %{
          name: @server_name,
          version: @server_version
        },
        capabilities: %{
          tools: %{listChanged: true},
          resources: %{subscribe: true, listChanged: true},
          prompts: %{listChanged: false},
          logging: %{}
        }
      }
    }

    {response, state}
  end

  defp process_request(%{"method" => "tools/list", "id" => id}, state) do
    response = %{
      jsonrpc: "2.0",
      id: id,
      result: %{
        tools: @tools
      }
    }

    {response, state}
  end

  defp process_request(%{"method" => "tools/call", "id" => id, "params" => params}, state) do
    tool_name = params["name"]
    arguments = params["arguments"] || %{}

    Logger.info("[MCP] Tool call: #{tool_name} with #{inspect(arguments)}")

    # Log to audit trail (SC-MCP-001)
    state = log_audit(state, tool_name, arguments)

    result = execute_tool(tool_name, arguments)

    response =
      case result do
        {:ok, content} ->
          %{
            jsonrpc: "2.0",
            id: id,
            result: %{
              content: [
                %{
                  type: "text",
                  text: format_result(content)
                }
              ]
            }
          }

        {:error, reason} ->
          error_response(-32000, "Tool execution failed: #{inspect(reason)}", id)
      end

    {response, state}
  end

  defp process_request(%{"method" => "resources/list", "id" => id}, state) do
    response = %{
      jsonrpc: "2.0",
      id: id,
      result: %{
        resources: @resources
      }
    }

    {response, state}
  end

  defp process_request(%{"method" => "resources/read", "id" => id, "params" => params}, state) do
    uri = params["uri"]

    result = read_resource(uri)

    response =
      case result do
        {:ok, content} ->
          %{
            jsonrpc: "2.0",
            id: id,
            result: %{
              contents: [
                %{
                  uri: uri,
                  mimeType: "application/json",
                  text: Jason.encode!(content)
                }
              ]
            }
          }

        {:error, reason} ->
          error_response(-32000, "Resource read failed: #{inspect(reason)}", id)
      end

    {response, state}
  end

  defp process_request(%{"method" => "ping", "id" => id}, state) do
    response = %{jsonrpc: "2.0", id: id, result: %{}}
    {response, state}
  end

  defp process_request(%{"method" => method, "id" => id}, state) do
    Logger.warning("[MCP] Unknown method: #{method}")
    response = error_response(-32601, "Method not found: #{method}", id)
    {response, state}
  end

  # ============================================================================
  # Tool Execution
  # ============================================================================

  defp execute_tool("kms_search", %{"query" => query} = args) do
    limit = args["limit"] || 20
    KMS.search(query, limit: limit)
  end

  defp execute_tool("kms_get_holon", %{"id" => id}) do
    if String.starts_with?(id, "hln_") do
      KMS.get_holon(id)
    else
      KMS.get_holon_by_fqun(id)
    end
  end

  defp execute_tool("kms_list_holons", args) do
    opts = []
    opts = if args["type"], do: [{:type, String.to_atom(args["type"])} | opts], else: opts
    opts = if args["limit"], do: [{:limit, args["limit"]} | opts], else: opts

    KMS.list_holons(opts)
  end

  defp execute_tool("kms_create_holon", args) do
    # SC-MCP-003: Guardian approval for write operations
    case Indrajaal.Cockpit.Prajna.GuardianIntegration.submit_proposal(args) do
      {:ok, _approval} ->
        attrs = %{
          name: args["name"],
          type: String.to_atom(args["type"] || "knowledge"),
          payload: args["payload"] || %{},
          parent_id: args["parent_id"]
        }

        KMS.create_holon(attrs)

      {:error, reason} ->
        {:error, "Guardian rejected: #{reason}"}
    end
  end

  defp execute_tool("kms_update_holon", %{"id" => id} = args) do
    # SC-MCP-003: Guardian approval for write operations
    case Indrajaal.Cockpit.Prajna.GuardianIntegration.submit_proposal(args) do
      {:ok, _approval} ->
        attrs =
          Map.take(args, ["payload", "name"])
          |> Enum.reject(fn {_, v} -> is_nil(v) end)
          |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

        KMS.update_holon(id, attrs)

      {:error, reason} ->
        {:error, "Guardian rejected: #{reason}"}
    end
  end

  defp execute_tool("kms_ask_oracle", %{"query" => query} = args) do
    opts = if args["context"], do: [context: args["context"]], else: []
    KMS.ask_oracle(query, opts)
  end

  defp execute_tool("kms_ask_oracle_augmented", %{"query" => query}) do
    KMS.ask_oracle_augmented(query)
  end

  defp execute_tool("kms_web_search", %{"query" => query} = args) do
    opts = [
      limit: args["limit"] || 5,
      store: args["store"] || false
    ]

    KMS.web_search(query, opts)
  end

  defp execute_tool("kms_similarity_search", %{"query" => query} = args) do
    # First get embedding for the query
    case get_query_embedding(query) do
      {:ok, embedding} ->
        opts = [
          limit: args["limit"] || 10,
          threshold: args["threshold"] || 0.7
        ]

        KMS.similarity_search(embedding, opts)

      {:error, reason} ->
        {:error, "Failed to generate embedding: #{reason}"}
    end
  end

  defp execute_tool("kms_health_report", _args) do
    KMS.health_report()
  end

  defp execute_tool("kms_event_stats", args) do
    days = args["days"] || 30
    KMS.event_stats(days: days)
  end

  defp execute_tool("kms_get_children", %{"parent_id" => parent_id}) do
    KMS.get_children(parent_id)
  end

  defp execute_tool("kms_get_edges", %{"holon_id" => holon_id}) do
    KMS.get_edges(holon_id)
  end

  defp execute_tool(
         "kms_create_edge",
         %{"source_id" => source, "target_id" => target, "relation" => relation} = args
       ) do
    # SC-MCP-003: Guardian approval for write operations
    case Indrajaal.Cockpit.Prajna.GuardianIntegration.submit_proposal(args) do
      {:ok, _approval} ->
        opts = [weight: args["weight"] || 1.0]
        KMS.create_edge(source, target, String.to_atom(relation), opts)

      {:error, reason} ->
        {:error, "Guardian rejected: #{reason}"}
    end
  end

  defp execute_tool(tool_name, _args) do
    {:error, "Unknown tool: #{tool_name}"}
  end

  # ============================================================================
  # Resource Handlers
  # ============================================================================

  defp read_resource("kms://holons") do
    KMS.list_holons(limit: 100)
  end

  defp read_resource("kms://health") do
    KMS.health_report()
  end

  defp read_resource(uri) do
    {:error, "Unknown resource: #{uri}"}
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp check_rate_limit(state) do
    now = System.monotonic_time(:millisecond)

    if now - state.rate_limit_window_start > @rate_window_ms do
      %{state | request_count: 0, rate_limit_window_start: now}
    else
      state
    end
  end

  defp log_audit(state, tool_name, arguments) do
    entry = %{
      timestamp: DateTime.utc_now(),
      tool: tool_name,
      arguments: arguments
    }

    # Keep last 1000 entries
    audit_log = [entry | Enum.take(state.audit_log, 999)]
    %{state | audit_log: audit_log}
  end

  defp error_response(code, message, id) do
    %{
      jsonrpc: "2.0",
      id: id,
      error: %{
        code: code,
        message: message
      }
    }
  end

  defp format_result(result) when is_map(result) do
    Jason.encode!(result, pretty: true)
  end

  defp format_result(result) when is_list(result) do
    Jason.encode!(result, pretty: true)
  end

  defp format_result(result) when is_binary(result) do
    result
  end

  defp format_result(result) do
    inspect(result)
  end

  defp get_query_embedding(query) do
    # Use KMS.AI for embedding generation
    case Indrajaal.KMS.AI.generate_embedding(query) do
      {:ok, embedding} -> {:ok, embedding}
      error -> error
    end
  rescue
    _ -> {:error, "Embedding service unavailable"}
  end

  # ============================================================================
  # STDIO Transport Layer
  # ============================================================================

  defp run_stdio_loop(pid) do
    # Read JSON-RPC messages from stdin
    case IO.gets("") do
      :eof ->
        Logger.info("[MCP] STDIO closed, shutting down")
        GenServer.stop(pid)

      {:error, reason} ->
        Logger.error("[MCP] STDIO error: #{inspect(reason)}")
        GenServer.stop(pid)

      line when is_binary(line) ->
        line = String.trim(line)

        if line != "" do
          case Jason.decode(line) do
            {:ok, request} ->
              response = handle_request(request)
              IO.puts(Jason.encode!(response))

            {:error, reason} ->
              Logger.warning("[MCP] Invalid JSON: #{inspect(reason)}")
              error = error_response(-32700, "Parse error", nil)
              IO.puts(Jason.encode!(error))
          end
        end

        run_stdio_loop(pid)
    end
  end
end
