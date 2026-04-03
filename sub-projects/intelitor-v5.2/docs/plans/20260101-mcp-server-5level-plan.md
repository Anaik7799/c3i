# MCP Server 5-Level Implementation Plan

**Version**: 1.0.0 | **Date**: 2026-01-01 | **Status**: PLANNING
**Alignment**: SOPv5.11 + STAMP + Founder's Covenant

```
    ╔═══════════════════════════════════════════════════════════════╗
    ║                    MCP SERVER ARCHITECTURE                     ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║  L5: Operations    │ Monitoring, Scaling, Incident Response   ║
    ║  L4: Security      │ OAuth, Tokens, Audit, Compliance         ║
    ║  L3: Integrations  │ Microsoft 365, Graph API, SharePoint     ║
    ║  L2: Protocol      │ MCP Core, Tools, Resources, Prompts      ║
    ║  L1: Foundation    │ Infrastructure, Runtime, Configuration   ║
    ╚═══════════════════════════════════════════════════════════════╝
```

---

## Level 1: Foundation Infrastructure

### 1.1 Runtime Environment

#### 1.1.1 Elixir MCP Server Core
```
Task: 1.1.1.0 - Create MCP Server GenServer Foundation
├── 1.1.1.1 - Create lib/indrajaal/mcp/server.ex
│   ├── 1.1.1.1.1 - Implement GenServer with supervision
│   ├── 1.1.1.1.2 - Define MCP protocol state structure
│   ├── 1.1.1.1.3 - Implement JSON-RPC 2.0 message handling
│   └── 1.1.1.1.4 - Add telemetry instrumentation
├── 1.1.1.2 - Create lib/indrajaal/mcp/transport.ex
│   ├── 1.1.1.2.1 - Implement stdio transport (local)
│   ├── 1.1.1.2.2 - Implement HTTP/SSE transport (remote)
│   ├── 1.1.1.2.3 - Implement WebSocket transport (real-time)
│   └── 1.1.1.2.4 - Add transport abstraction layer
├── 1.1.1.3 - Create lib/indrajaal/mcp/session.ex
│   ├── 1.1.1.3.1 - Session lifecycle management
│   ├── 1.1.1.3.2 - Session state persistence
│   ├── 1.1.1.3.3 - Multi-session support
│   └── 1.1.1.3.4 - Session timeout handling
└── 1.1.1.4 - Create lib/indrajaal/mcp/supervisor.ex
    ├── 1.1.1.4.1 - Define supervision tree
    ├── 1.1.1.4.2 - Configure restart strategies
    ├── 1.1.1.4.3 - Add dynamic child management
    └── 1.1.1.4.4 - Integrate with Indrajaal.Application
```

#### 1.1.2 F# MCP Server (CEPAF)
```
Task: 1.1.2.0 - Create F# MCP Server Implementation
├── 1.1.2.1 - Create lib/cepaf/src/Cepaf/Mcp/Server.fs
│   ├── 1.1.2.1.1 - Define MCP types with discriminated unions
│   ├── 1.1.2.1.2 - Implement async message processor
│   ├── 1.1.2.1.3 - Add railway-oriented error handling
│   └── 1.1.2.1.4 - Create MailboxProcessor for concurrency
├── 1.1.2.2 - Create lib/cepaf/src/Cepaf/Mcp/Protocol.fs
│   ├── 1.1.2.2.1 - JSON-RPC 2.0 codec (System.Text.Json)
│   ├── 1.1.2.2.2 - MCP message type definitions
│   ├── 1.1.2.2.3 - Request/Response correlation
│   └── 1.1.2.2.4 - Notification handling
├── 1.1.2.3 - Create lib/cepaf/src/Cepaf/Mcp/Transport.fs
│   ├── 1.1.2.3.1 - Stdio transport with StreamReader/Writer
│   ├── 1.1.2.3.2 - HTTP transport with HttpClient
│   ├── 1.1.2.3.3 - SSE client for streaming
│   └── 1.1.2.3.4 - WebSocket with ClientWebSocket
└── 1.1.2.4 - Create lib/cepaf/src/Cepaf/Mcp/Bridge.fs
    ├── 1.1.2.4.1 - Elixir ↔ F# bridge via Port
    ├── 1.1.2.4.2 - Message serialization (ETF/JSON)
    ├── 1.1.2.4.3 - Bidirectional communication
    └── 1.1.2.4.4 - Health monitoring
```

#### 1.1.3 Configuration Management
```
Task: 1.1.3.0 - MCP Configuration System
├── 1.1.3.1 - Create config/mcp.exs
│   ├── 1.1.3.1.1 - Server binding configuration
│   ├── 1.1.3.1.2 - Transport selection
│   ├── 1.1.3.1.3 - Authentication providers
│   └── 1.1.3.1.4 - Tool registration paths
├── 1.1.3.2 - Create lib/indrajaal/mcp/config.ex
│   ├── 1.1.3.2.1 - Runtime configuration loader
│   ├── 1.1.3.2.2 - Environment variable mapping
│   ├── 1.1.3.2.3 - Secret management integration
│   └── 1.1.3.2.4 - Hot-reload support
└── 1.1.3.3 - Create .mcp/server.json (MCP manifest)
    ├── 1.1.3.3.1 - Server metadata
    ├── 1.1.3.3.2 - Capability declarations
    ├── 1.1.3.3.3 - Tool catalog reference
    └── 1.1.3.3.4 - Authentication requirements
```

### 1.2 Container Deployment

#### 1.2.1 Podman Configuration
```
Task: 1.2.1.0 - MCP Server Container Setup
├── 1.2.1.1 - Create containers/mcp-server/Containerfile
│   ├── 1.2.1.1.1 - Multi-stage build (Elixir release)
│   ├── 1.2.1.1.2 - Runtime dependencies
│   ├── 1.2.1.1.3 - Security hardening
│   └── 1.2.1.1.4 - Health check endpoint
├── 1.2.1.2 - Create podman-compose-mcp.yml
│   ├── 1.2.1.2.1 - MCP server service
│   ├── 1.2.1.2.2 - Network configuration
│   ├── 1.2.1.2.3 - Volume mounts
│   └── 1.2.1.2.4 - Resource limits
└── 1.2.1.3 - Integration with existing stack
    ├── 1.2.1.3.1 - Connect to indrajaal-app network
    ├── 1.2.1.3.2 - Share observability stack
    ├── 1.2.1.3.3 - Database connectivity (if needed)
    └── 1.2.1.3.4 - Zenoh mesh integration
```

---

## Level 2: MCP Protocol Implementation

### 2.1 Core Protocol

#### 2.1.1 JSON-RPC 2.0 Layer
```
Task: 2.1.1.0 - JSON-RPC Implementation
├── 2.1.1.1 - Create lib/indrajaal/mcp/jsonrpc.ex
│   ├── 2.1.1.1.1 - Request struct definition
│   │   defstruct [:jsonrpc, :id, :method, :params]
│   ├── 2.1.1.1.2 - Response struct definition
│   │   defstruct [:jsonrpc, :id, :result, :error]
│   ├── 2.1.1.1.3 - Notification struct (no id)
│   ├── 2.1.1.1.4 - Batch request support
│   └── 2.1.1.1.5 - Error code definitions (-32700 to -32600)
├── 2.1.1.2 - Create lib/indrajaal/mcp/codec.ex
│   ├── 2.1.1.2.1 - JSON encoding with Jason
│   ├── 2.1.1.2.2 - JSON decoding with validation
│   ├── 2.1.1.2.3 - Binary message framing
│   └── 2.1.1.2.4 - Stream parsing for SSE
└── 2.1.1.3 - Create lib/indrajaal/mcp/dispatcher.ex
    ├── 2.1.1.3.1 - Method routing
    ├── 2.1.1.3.2 - Handler registration
    ├── 2.1.1.3.3 - Timeout management
    └── 2.1.1.3.4 - Error propagation
```

#### 2.1.2 MCP Lifecycle Methods
```
Task: 2.1.2.0 - MCP Lifecycle Implementation
├── 2.1.2.1 - Initialize handshake
│   ├── 2.1.2.1.1 - Handle "initialize" request
│   │   - Protocol version negotiation
│   │   - Client capabilities exchange
│   │   - Server capabilities declaration
│   ├── 2.1.2.1.2 - Handle "initialized" notification
│   └── 2.1.2.1.3 - Capability matrix validation
├── 2.1.2.2 - Ping/Pong keepalive
│   ├── 2.1.2.2.1 - Handle "ping" request
│   ├── 2.1.2.2.2 - Automatic ping scheduling
│   └── 2.1.2.2.3 - Connection health tracking
└── 2.1.2.3 - Shutdown sequence
    ├── 2.1.2.3.1 - Handle "shutdown" request
    ├── 2.1.2.3.2 - Graceful resource cleanup
    └── 2.1.2.3.3 - Handle "exit" notification
```

### 2.2 Tools Subsystem

#### 2.2.1 Tool Definition Framework
```
Task: 2.2.1.0 - Tool Framework Implementation
├── 2.2.1.1 - Create lib/indrajaal/mcp/tool.ex
│   ├── 2.2.1.1.1 - Tool behaviour definition
│   │   @callback name() :: String.t()
│   │   @callback description() :: String.t()
│   │   @callback input_schema() :: map()
│   │   @callback execute(params, context) :: {:ok, result} | {:error, reason}
│   ├── 2.2.1.1.2 - Tool metadata struct
│   ├── 2.2.1.1.3 - JSON Schema validation
│   └── 2.2.1.1.4 - Execution context management
├── 2.2.1.2 - Create lib/indrajaal/mcp/tool_registry.ex
│   ├── 2.2.1.2.1 - Tool registration (compile-time)
│   ├── 2.2.1.2.2 - Dynamic tool loading
│   ├── 2.2.1.2.3 - Tool discovery ("tools/list")
│   └── 2.2.1.2.4 - Tool capability caching
└── 2.2.1.3 - Create lib/indrajaal/mcp/tool_executor.ex
    ├── 2.2.1.3.1 - Handle "tools/call" request
    ├── 2.2.1.3.2 - Parameter validation
    ├── 2.2.1.3.3 - Execution sandboxing
    ├── 2.2.1.3.4 - Result formatting
    └── 2.2.1.3.5 - Progress reporting (notifications)
```

#### 2.2.2 Tool DSL Macro
```
Task: 2.2.2.0 - Tool Definition DSL
├── 2.2.2.1 - Create lib/indrajaal/mcp/tool_dsl.ex
│   defmacro deftool(name, opts, do: block)
│   ├── 2.2.2.1.1 - Compile-time schema generation
│   ├── 2.2.2.1.2 - Automatic registration
│   ├── 2.2.2.1.3 - Documentation extraction
│   └── 2.2.2.1.4 - Type inference from specs
└── 2.2.2.2 - Example tool definition:
    defmodule MyTools do
      use Indrajaal.MCP.ToolDSL

      deftool :search_emails,
        description: "Search emails by query",
        params: [
          query: [type: :string, required: true],
          limit: [type: :integer, default: 10]
        ] do
        # Implementation
      end
    end
```

### 2.3 Resources Subsystem

#### 2.3.1 Resource Framework
```
Task: 2.3.1.0 - Resource Implementation
├── 2.3.1.1 - Create lib/indrajaal/mcp/resource.ex
│   ├── 2.3.1.1.1 - Resource behaviour definition
│   │   @callback uri() :: String.t()
│   │   @callback name() :: String.t()
│   │   @callback mime_type() :: String.t()
│   │   @callback read(context) :: {:ok, content} | {:error, reason}
│   ├── 2.3.1.1.2 - Resource template support
│   └── 2.3.1.1.3 - Resource subscription (changes)
├── 2.3.1.2 - Create lib/indrajaal/mcp/resource_registry.ex
│   ├── 2.3.1.2.1 - Handle "resources/list"
│   ├── 2.3.1.2.2 - Handle "resources/read"
│   ├── 2.3.1.2.3 - Handle "resources/templates/list"
│   └── 2.3.1.2.4 - Handle "resources/subscribe"
└── 2.3.1.3 - Built-in resource types
    ├── 2.3.1.3.1 - File resource (file://)
    ├── 2.3.1.3.2 - Database resource (db://)
    ├── 2.3.1.3.3 - API resource (api://)
    └── 2.3.1.3.4 - Memory resource (mem://)
```

### 2.4 Prompts Subsystem

#### 2.4.1 Prompt Framework
```
Task: 2.4.1.0 - Prompt Implementation
├── 2.4.1.1 - Create lib/indrajaal/mcp/prompt.ex
│   ├── 2.4.1.1.1 - Prompt behaviour definition
│   │   @callback name() :: String.t()
│   │   @callback description() :: String.t()
│   │   @callback arguments() :: [argument_def()]
│   │   @callback get_messages(args) :: [message()]
│   ├── 2.4.1.1.2 - Prompt template engine (EEx)
│   └── 2.4.1.1.3 - Argument validation
├── 2.4.1.2 - Create lib/indrajaal/mcp/prompt_registry.ex
│   ├── 2.4.1.2.1 - Handle "prompts/list"
│   └── 2.4.1.2.2 - Handle "prompts/get"
└── 2.4.1.3 - Built-in prompts
    ├── 2.4.1.3.1 - System analysis prompt
    ├── 2.4.1.3.2 - Code review prompt
    └── 2.4.1.3.3 - Incident response prompt
```

---

## Level 3: Microsoft Service Integrations

### 3.1 Microsoft Graph API

#### 3.1.1 Graph Client
```
Task: 3.1.1.0 - Microsoft Graph Client Implementation
├── 3.1.1.1 - Create lib/indrajaal/mcp/microsoft/graph_client.ex
│   ├── 3.1.1.1.1 - HTTP client with Req
│   ├── 3.1.1.1.2 - Base URL configuration
│   ├── 3.1.1.1.3 - Request builder pattern
│   ├── 3.1.1.1.4 - Response parsing
│   └── 3.1.1.1.5 - Error handling (Graph error codes)
├── 3.1.1.2 - Create lib/indrajaal/mcp/microsoft/graph_auth.ex
│   ├── 3.1.1.2.1 - OAuth 2.0 token acquisition
│   ├── 3.1.1.2.2 - Token caching (ETS)
│   ├── 3.1.1.2.3 - Token refresh logic
│   ├── 3.1.1.2.4 - Scope management
│   └── 3.1.1.2.5 - On-behalf-of flow (delegated)
└── 3.1.1.3 - Create lib/indrajaal/mcp/microsoft/graph_batch.ex
    ├── 3.1.1.3.1 - Batch request builder
    ├── 3.1.1.3.2 - Dependency ordering
    └── 3.1.1.3.3 - Batch response handling
```

#### 3.1.2 Email Tools (Outlook)
```
Task: 3.1.2.0 - Outlook Email Tools
├── 3.1.2.1 - Create lib/indrajaal/mcp/microsoft/tools/email.ex
│   ├── 3.1.2.1.1 - Tool: search_emails
│   │   - Query: KQL syntax support
│   │   - Filters: sender, date, folder
│   │   - Pagination: $top, $skip
│   ├── 3.1.2.1.2 - Tool: get_email
│   │   - Retrieve single email by ID
│   │   - Include attachments option
│   ├── 3.1.2.1.3 - Tool: send_email
│   │   - Recipients: to, cc, bcc
│   │   - Attachments support
│   │   - Save to sent items
│   ├── 3.1.2.1.4 - Tool: reply_email
│   │   - Reply vs Reply All
│   │   - Thread tracking
│   ├── 3.1.2.1.5 - Tool: move_email
│   │   - Move to folder
│   │   - Archive action
│   └── 3.1.2.1.6 - Tool: delete_email
        - Soft delete (trash)
        - Hard delete (permanent)
```

#### 3.1.3 Calendar Tools
```
Task: 3.1.3.0 - Calendar Tools
├── 3.1.3.1 - Create lib/indrajaal/mcp/microsoft/tools/calendar.ex
│   ├── 3.1.3.1.1 - Tool: get_calendar_events
│   │   - Date range filtering
│   │   - Calendar selection
│   │   - Recurring event expansion
│   ├── 3.1.3.1.2 - Tool: create_event
│   │   - Basic event creation
│   │   - Attendees management
│   │   - Recurrence patterns
│   │   - Online meeting (Teams link)
│   ├── 3.1.3.1.3 - Tool: update_event
│   │   - Partial updates
│   │   - Series vs occurrence
│   ├── 3.1.3.1.4 - Tool: delete_event
│   ├── 3.1.3.1.5 - Tool: find_meeting_times
│   │   - Availability lookup
│   │   - Suggested times
│   └── 3.1.3.1.6 - Tool: respond_to_event
        - Accept/Decline/Tentative
```

#### 3.1.4 OneDrive/SharePoint Tools
```
Task: 3.1.4.0 - Files & SharePoint Tools
├── 3.1.4.1 - Create lib/indrajaal/mcp/microsoft/tools/files.ex
│   ├── 3.1.4.1.1 - Tool: search_files
│   │   - OneDrive search
│   │   - SharePoint search
│   │   - Content search (text in docs)
│   ├── 3.1.4.1.2 - Tool: get_file_content
│   │   - Download file
│   │   - Stream large files
│   │   - Convert formats (PDF preview)
│   ├── 3.1.4.1.3 - Tool: upload_file
│   │   - Simple upload (<4MB)
│   │   - Resumable upload (large)
│   │   - Conflict handling
│   ├── 3.1.4.1.4 - Tool: list_folder
│   │   - Directory listing
│   │   - Recursive option
│   └── 3.1.4.1.5 - Tool: share_file
        - Create sharing link
        - Set permissions
├── 3.1.4.2 - Create lib/indrajaal/mcp/microsoft/tools/sharepoint.ex
│   ├── 3.1.4.2.1 - Tool: list_sites
│   ├── 3.1.4.2.2 - Tool: get_site_pages
│   ├── 3.1.4.2.3 - Tool: search_sharepoint
│   └── 3.1.4.2.4 - Tool: get_list_items
```

#### 3.1.5 Teams Tools
```
Task: 3.1.5.0 - Microsoft Teams Tools
├── 3.1.5.1 - Create lib/indrajaal/mcp/microsoft/tools/teams.ex
│   ├── 3.1.5.1.1 - Tool: list_teams
│   │   - User's teams
│   │   - Team details
│   ├── 3.1.5.1.2 - Tool: list_channels
│   │   - Standard channels
│   │   - Private channels
│   ├── 3.1.5.1.3 - Tool: get_channel_messages
│   │   - Recent messages
│   │   - Thread replies
│   ├── 3.1.5.1.4 - Tool: post_message
│   │   - Channel message
│   │   - Reply to thread
│   │   - Mentions (@user)
│   │   - Rich content (cards)
│   ├── 3.1.5.1.5 - Tool: get_chat_messages
│   │   - 1:1 chats
│   │   - Group chats
│   └── 3.1.5.1.6 - Tool: send_chat_message
```

#### 3.1.6 Planner/Tasks Tools
```
Task: 3.1.6.0 - Planner & To-Do Tools
├── 3.1.6.1 - Create lib/indrajaal/mcp/microsoft/tools/planner.ex
│   ├── 3.1.6.1.1 - Tool: list_plans
│   ├── 3.1.6.1.2 - Tool: get_plan_tasks
│   ├── 3.1.6.1.3 - Tool: create_task
│   │   - Title, description
│   │   - Assignments
│   │   - Due date, priority
│   │   - Checklist items
│   ├── 3.1.6.1.4 - Tool: update_task
│   └── 3.1.6.1.5 - Tool: complete_task
├── 3.1.6.2 - Create lib/indrajaal/mcp/microsoft/tools/todo.ex
│   ├── 3.1.6.2.1 - Tool: list_task_lists
│   ├── 3.1.6.2.2 - Tool: get_tasks
│   ├── 3.1.6.2.3 - Tool: create_todo_task
│   └── 3.1.6.2.4 - Tool: complete_todo_task
```

### 3.2 Azure Services Integration

#### 3.2.1 Azure Resource Management
```
Task: 3.2.1.0 - Azure Management Tools
├── 3.2.1.1 - Create lib/indrajaal/mcp/microsoft/tools/azure.ex
│   ├── 3.2.1.1.1 - Tool: list_subscriptions
│   ├── 3.2.1.1.2 - Tool: list_resource_groups
│   ├── 3.2.1.1.3 - Tool: list_resources
│   ├── 3.2.1.1.4 - Tool: get_resource_health
│   └── 3.2.1.1.5 - Tool: get_cost_summary
├── 3.2.1.2 - Create lib/indrajaal/mcp/microsoft/tools/azure_monitor.ex
│   ├── 3.2.1.2.1 - Tool: query_logs
│   │   - KQL query support
│   │   - Log Analytics workspace
│   ├── 3.2.1.2.2 - Tool: get_metrics
│   │   - Resource metrics
│   │   - Time range
│   └── 3.2.1.2.3 - Tool: list_alerts
```

### 3.3 Composite Tools (Orchestrated)

#### 3.3.1 Multi-Service Orchestrations
```
Task: 3.3.1.0 - Composite Tool Implementation
├── 3.3.1.1 - Create lib/indrajaal/mcp/microsoft/tools/composite.ex
│   ├── 3.3.1.1.1 - Tool: executive_briefing
│   │   - Aggregates: emails, calendar, tasks, mentions
│   │   - Returns structured summary
│   ├── 3.3.1.1.2 - Tool: schedule_meeting_with_prep
│   │   - Find available time
│   │   - Create event
│   │   - Attach relevant documents
│   │   - Send agenda
│   ├── 3.3.1.1.3 - Tool: project_status_report
│   │   - Planner tasks status
│   │   - Recent team activity
│   │   - Document updates
│   ├── 3.3.1.1.4 - Tool: inbox_triage
│   │   - Categorize emails
│   │   - Suggest actions
│   │   - Create follow-up tasks
│   └── 3.3.1.1.5 - Tool: knowledge_search
        - Search emails + files + SharePoint
        - Unified results ranking
```

---

## Level 4: Security & Governance

### 4.1 Authentication

#### 4.1.1 OAuth 2.0 Implementation
```
Task: 4.1.1.0 - OAuth 2.0 Security Layer
├── 4.1.1.1 - Create lib/indrajaal/mcp/auth/oauth.ex
│   ├── 4.1.1.1.1 - Authorization code flow
│   │   - PKCE support (code_verifier/challenge)
│   │   - State parameter validation
│   │   - Redirect URI handling
│   ├── 4.1.1.1.2 - Client credentials flow
│   │   - App-only authentication
│   │   - Certificate auth option
│   ├── 4.1.1.1.3 - On-behalf-of flow
│   │   - User delegation
│   │   - Scope assertion
│   └── 4.1.1.1.4 - Device code flow
        - Browserless auth
├── 4.1.1.2 - Create lib/indrajaal/mcp/auth/token_cache.ex
│   ├── 4.1.1.2.1 - ETS-based token storage
│   ├── 4.1.1.2.2 - Token expiry tracking
│   ├── 4.1.1.2.3 - Automatic refresh
│   └── 4.1.1.2.4 - Multi-user token isolation
└── 4.1.1.3 - Create lib/indrajaal/mcp/auth/entra_id.ex
    ├── 4.1.1.3.1 - Microsoft Entra ID integration
    ├── 4.1.1.3.2 - OIDC discovery
    ├── 4.1.1.3.3 - JWT validation
    └── 4.1.1.3.4 - Claims extraction
```

#### 4.1.2 MCP Session Security
```
Task: 4.1.2.0 - MCP Session Security
├── 4.1.2.1 - Create lib/indrajaal/mcp/auth/session_token.ex
│   ├── 4.1.2.1.1 - Session token generation
│   │   - Cryptographically secure
│   │   - Time-bound validity
│   ├── 4.1.2.1.2 - Token binding to user
│   ├── 4.1.2.1.3 - Token rotation
│   └── 4.1.2.1.4 - Revocation support
├── 4.1.2.2 - Create lib/indrajaal/mcp/auth/request_validator.ex
│   ├── 4.1.2.2.1 - Authorization header parsing
│   ├── 4.1.2.2.2 - Token validation
│   ├── 4.1.2.2.3 - Scope verification
│   └── 4.1.2.2.4 - Rate limit checking
```

### 4.2 Authorization

#### 4.2.1 Permission Model
```
Task: 4.2.1.0 - Permission & Access Control
├── 4.2.1.1 - Create lib/indrajaal/mcp/auth/permissions.ex
│   ├── 4.2.1.1.1 - Permission definitions
│   │   - mcp:tools:read
│   │   - mcp:tools:execute
│   │   - mcp:resources:read
│   │   - mcp:resources:write
│   │   - microsoft:mail:read
│   │   - microsoft:mail:send
│   │   - microsoft:calendar:readwrite
│   │   - microsoft:files:readwrite
│   ├── 4.2.1.1.2 - Permission inheritance
│   └── 4.2.1.1.3 - Admin vs User scopes
├── 4.2.1.2 - Create lib/indrajaal/mcp/auth/policy.ex
│   ├── 4.2.1.2.1 - Tool access policies
│   ├── 4.2.1.2.2 - Resource access policies
│   ├── 4.2.1.2.3 - Time-based restrictions
│   └── 4.2.1.2.4 - IP-based restrictions
└── 4.2.1.3 - Guardian Integration
    ├── 4.2.1.3.1 - Wire to Indrajaal.Safety.Guardian
    ├── 4.2.1.3.2 - Tool execution proposals
    ├── 4.2.1.3.3 - Veto on dangerous operations
    └── 4.2.1.3.4 - Audit trail logging
```

### 4.3 Audit & Compliance

#### 4.3.1 Audit Logging
```
Task: 4.3.1.0 - Comprehensive Audit System
├── 4.3.1.1 - Create lib/indrajaal/mcp/audit/logger.ex
│   ├── 4.3.1.1.1 - Structured audit events
│   │   - Timestamp (ISO 8601)
│   │   - User identity
│   │   - Tool/Resource accessed
│   │   - Parameters (sanitized)
│   │   - Result status
│   │   - Duration
│   ├── 4.3.1.1.2 - Immutable Register integration
│   │   - Sign audit blocks
│   │   - Hash chain continuity
│   └── 4.3.1.1.3 - Real-time streaming
├── 4.3.1.2 - Create lib/indrajaal/mcp/audit/retention.ex
│   ├── 4.3.1.2.1 - Retention policies
│   ├── 4.3.1.2.2 - Archival to DuckDB
│   └── 4.3.1.2.3 - Compliance holds
└── 4.3.1.3 - Create lib/indrajaal/mcp/audit/query.ex
    ├── 4.3.1.3.1 - Audit search API
    ├── 4.3.1.3.2 - User activity reports
    └── 4.3.1.3.3 - Anomaly detection
```

#### 4.3.2 Data Protection
```
Task: 4.3.2.0 - Data Protection Implementation
├── 4.3.2.1 - Create lib/indrajaal/mcp/security/data_protection.ex
│   ├── 4.3.2.1.1 - PII detection
│   ├── 4.3.2.1.2 - Data masking
│   ├── 4.3.2.1.3 - Encryption at rest
│   └── 4.3.2.1.4 - Encryption in transit (TLS 1.3)
├── 4.3.2.2 - Create lib/indrajaal/mcp/security/dlp.ex
│   ├── 4.3.2.2.1 - Sensitive content detection
│   ├── 4.3.2.2.2 - Block/warn on violations
│   └── 4.3.2.2.3 - DLP policy configuration
```

### 4.4 Rate Limiting & Throttling

#### 4.4.1 API Budget Management
```
Task: 4.4.1.0 - Rate Limiting System
├── 4.4.1.1 - Create lib/indrajaal/mcp/rate_limit/limiter.ex
│   ├── 4.4.1.1.1 - Token bucket algorithm
│   ├── 4.4.1.1.2 - Per-user limits
│   ├── 4.4.1.1.3 - Per-tool limits
│   ├── 4.4.1.1.4 - Global limits
│   └── 4.4.1.1.5 - Microsoft Graph API budget tracking
├── 4.4.1.2 - Create lib/indrajaal/mcp/rate_limit/backoff.ex
│   ├── 4.4.1.2.1 - Exponential backoff
│   ├── 4.4.1.2.2 - Jitter implementation
│   ├── 4.4.1.2.3 - Retry-After header respect
│   └── 4.4.1.2.4 - Circuit breaker integration
└── 4.4.1.3 - Create lib/indrajaal/mcp/rate_limit/quota.ex
    ├── 4.4.1.3.1 - Daily/monthly quotas
    ├── 4.4.1.3.2 - Quota alerts
    └── 4.4.1.3.3 - Quota enforcement
```

---

## Level 5: Production Operations

### 5.1 Observability

#### 5.1.1 Telemetry Integration
```
Task: 5.1.1.0 - Comprehensive Observability
├── 5.1.1.1 - Create lib/indrajaal/mcp/telemetry.ex
│   ├── 5.1.1.1.1 - Telemetry event definitions
│   │   - [:mcp, :request, :start]
│   │   - [:mcp, :request, :stop]
│   │   - [:mcp, :request, :exception]
│   │   - [:mcp, :tool, :call]
│   │   - [:mcp, :auth, :token_refresh]
│   ├── 5.1.1.1.2 - Metrics aggregation
│   │   - Request count
│   │   - Latency histogram
│   │   - Error rate
│   │   - Tool usage distribution
│   └── 5.1.1.1.3 - OpenTelemetry integration
        - Trace propagation
        - Span attributes
├── 5.1.1.2 - Create lib/indrajaal/mcp/metrics.ex
│   ├── 5.1.1.2.1 - Prometheus metrics export
│   ├── 5.1.1.2.2 - Custom gauge definitions
│   └── 5.1.1.2.3 - Dashboard queries (PromQL)
└── 5.1.1.3 - Grafana Dashboard
    ├── 5.1.1.3.1 - MCP Server health dashboard
    ├── 5.1.1.3.2 - Tool usage analytics
    ├── 5.1.1.3.3 - Auth metrics
    └── 5.1.1.3.4 - Microsoft API quota tracking
```

#### 5.1.2 Logging
```
Task: 5.1.2.0 - Structured Logging
├── 5.1.2.1 - Create lib/indrajaal/mcp/logging.ex
│   ├── 5.1.2.1.1 - JSON structured logs
│   ├── 5.1.2.1.2 - Request correlation IDs
│   ├── 5.1.2.1.3 - Log levels configuration
│   └── 5.1.2.1.4 - Sensitive data redaction
├── 5.1.2.2 - Loki integration
│   ├── 5.1.2.2.1 - Log shipping
│   ├── 5.1.2.2.2 - Label extraction
│   └── 5.1.2.2.3 - LogQL queries
```

### 5.2 Scaling & High Availability

#### 5.2.1 Horizontal Scaling
```
Task: 5.2.1.0 - Scalability Implementation
├── 5.2.1.1 - Create lib/indrajaal/mcp/cluster.ex
│   ├── 5.2.1.1.1 - libcluster integration
│   ├── 5.2.1.1.2 - Session distribution (Horde)
│   ├── 5.2.1.1.3 - Load balancing strategy
│   └── 5.2.1.1.4 - Node health checking
├── 5.2.1.2 - Kubernetes/Podman deployment
│   ├── 5.2.1.2.1 - Horizontal Pod Autoscaler
│   ├── 5.2.1.2.2 - Pod disruption budget
│   └── 5.2.1.2.3 - Rolling updates
└── 5.2.1.3 - State management
    ├── 5.2.1.3.1 - Stateless server design
    ├── 5.2.1.3.2 - External session store (Redis)
    └── 5.2.1.3.3 - Token cache distribution
```

#### 5.2.2 High Availability
```
Task: 5.2.2.0 - HA Configuration
├── 5.2.2.1 - Multi-region deployment
│   ├── 5.2.2.1.1 - Active-active setup
│   ├── 5.2.2.1.2 - Geographic routing
│   └── 5.2.2.1.3 - Data replication
├── 5.2.2.2 - Failover mechanisms
│   ├── 5.2.2.2.1 - Health probes
│   ├── 5.2.2.2.2 - Automatic failover
│   └── 5.2.2.2.3 - Manual override
```

### 5.3 Incident Response

#### 5.3.1 Alerting
```
Task: 5.3.1.0 - Alert Configuration
├── 5.3.1.1 - Create alerting rules
│   ├── 5.3.1.1.1 - Error rate > 5% (critical)
│   ├── 5.3.1.1.2 - Latency p99 > 2s (warning)
│   ├── 5.3.1.1.3 - Auth failures spike (critical)
│   ├── 5.3.1.1.4 - Microsoft API quota > 80% (warning)
│   └── 5.3.1.1.5 - Connection pool exhaustion (critical)
├── 5.3.1.2 - Alert routing
│   ├── 5.3.1.2.1 - PagerDuty integration
│   ├── 5.3.1.2.2 - Slack notifications
│   └── 5.3.1.2.3 - Email escalation
```

#### 5.3.2 Runbooks
```
Task: 5.3.2.0 - Operational Runbooks
├── 5.3.2.1 - Create docs/runbooks/mcp/
│   ├── 5.3.2.1.1 - High error rate runbook
│   ├── 5.3.2.1.2 - Auth failure runbook
│   ├── 5.3.2.1.3 - Microsoft API throttling runbook
│   ├── 5.3.2.1.4 - Server restart procedure
│   └── 5.3.2.1.5 - Emergency shutdown procedure
```

### 5.4 Testing & Quality

#### 5.4.1 Test Suites
```
Task: 5.4.1.0 - Comprehensive Test Coverage
├── 5.4.1.1 - Unit tests
│   ├── 5.4.1.1.1 - Protocol parsing tests
│   ├── 5.4.1.1.2 - Tool execution tests
│   ├── 5.4.1.1.3 - Auth flow tests
│   └── 5.4.1.1.4 - Rate limiting tests
├── 5.4.1.2 - Integration tests
│   ├── 5.4.1.2.1 - Microsoft Graph mock server
│   ├── 5.4.1.2.2 - End-to-end tool calls
│   └── 5.4.1.2.3 - Auth flow integration
├── 5.4.1.3 - Property tests (TDG compliance)
│   ├── 5.4.1.3.1 - JSON-RPC codec properties
│   ├── 5.4.1.3.2 - Token validation properties
│   └── 5.4.1.3.3 - Rate limit properties
└── 5.4.1.4 - Load tests
    ├── 5.4.1.4.1 - Concurrent session handling
    ├── 5.4.1.4.2 - Tool execution throughput
    └── 5.4.1.4.3 - Auth token refresh under load
```

---

## Implementation Schedule

```
┌─────────────────────────────────────────────────────────────────┐
│                    IMPLEMENTATION PHASES                         │
├─────────────────────────────────────────────────────────────────┤
│ Phase 1: Foundation (L1)                                         │
│   • Elixir MCP Server core                                       │
│   • Transport layer (HTTP/SSE)                                   │
│   • Basic configuration                                          │
├─────────────────────────────────────────────────────────────────┤
│ Phase 2: Protocol (L2)                                           │
│   • JSON-RPC implementation                                      │
│   • Tool framework & DSL                                         │
│   • Resource & Prompt subsystems                                 │
├─────────────────────────────────────────────────────────────────┤
│ Phase 3: Microsoft Integration (L3)                              │
│   • Graph API client                                             │
│   • Core tools (Email, Calendar, Files)                          │
│   • Teams & Planner integration                                  │
│   • Composite orchestrations                                     │
├─────────────────────────────────────────────────────────────────┤
│ Phase 4: Security (L4)                                           │
│   • OAuth 2.0 flows                                              │
│   • Session security                                             │
│   • Authorization & policies                                     │
│   • Audit logging                                                │
├─────────────────────────────────────────────────────────────────┤
│ Phase 5: Operations (L5)                                         │
│   • Telemetry & observability                                    │
│   • Scaling & HA                                                 │
│   • Alerting & runbooks                                          │
│   • Test coverage 100%                                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## STAMP Safety Constraints Summary

| ID | Constraint | Level |
|----|------------|-------|
| SC-MCP-001 | All tool executions require valid session token | L4 |
| SC-MCP-002 | Microsoft API calls must respect rate limits | L3 |
| SC-MCP-003 | Audit log every tool invocation | L4 |
| SC-MCP-004 | PII must be detected and masked in logs | L4 |
| SC-MCP-005 | Guardian approval for destructive operations | L4 |
| SC-MCP-006 | Token refresh must be atomic | L4 |
| SC-MCP-007 | Session timeout max 1 hour | L4 |
| SC-MCP-008 | Transport must use TLS 1.3 | L1 |
| SC-MCP-009 | Batch requests max 20 operations | L2 |
| SC-MCP-010 | Response timeout max 30 seconds | L2 |

---

## Files to Create

```
lib/indrajaal/mcp/
├── server.ex                    # L1.1.1.1
├── transport.ex                 # L1.1.1.2
├── session.ex                   # L1.1.1.3
├── supervisor.ex                # L1.1.1.4
├── config.ex                    # L1.1.3.2
├── jsonrpc.ex                   # L2.1.1.1
├── codec.ex                     # L2.1.1.2
├── dispatcher.ex                # L2.1.1.3
├── tool.ex                      # L2.2.1.1
├── tool_registry.ex             # L2.2.1.2
├── tool_executor.ex             # L2.2.1.3
├── tool_dsl.ex                  # L2.2.2.1
├── resource.ex                  # L2.3.1.1
├── resource_registry.ex         # L2.3.1.2
├── prompt.ex                    # L2.4.1.1
├── prompt_registry.ex           # L2.4.1.2
├── telemetry.ex                 # L5.1.1.1
├── metrics.ex                   # L5.1.1.2
├── logging.ex                   # L5.1.2.1
├── cluster.ex                   # L5.2.1.1
├── microsoft/
│   ├── graph_client.ex          # L3.1.1.1
│   ├── graph_auth.ex            # L3.1.1.2
│   ├── graph_batch.ex           # L3.1.1.3
│   └── tools/
│       ├── email.ex             # L3.1.2.1
│       ├── calendar.ex          # L3.1.3.1
│       ├── files.ex             # L3.1.4.1
│       ├── sharepoint.ex        # L3.1.4.2
│       ├── teams.ex             # L3.1.5.1
│       ├── planner.ex           # L3.1.6.1
│       ├── todo.ex              # L3.1.6.2
│       ├── azure.ex             # L3.2.1.1
│       ├── azure_monitor.ex     # L3.2.1.2
│       └── composite.ex         # L3.3.1.1
├── auth/
│   ├── oauth.ex                 # L4.1.1.1
│   ├── token_cache.ex           # L4.1.1.2
│   ├── entra_id.ex              # L4.1.1.3
│   ├── session_token.ex         # L4.1.2.1
│   ├── request_validator.ex     # L4.1.2.2
│   ├── permissions.ex           # L4.2.1.1
│   └── policy.ex                # L4.2.1.2
├── audit/
│   ├── logger.ex                # L4.3.1.1
│   ├── retention.ex             # L4.3.1.2
│   └── query.ex                 # L4.3.1.3
├── security/
│   ├── data_protection.ex       # L4.3.2.1
│   └── dlp.ex                   # L4.3.2.2
└── rate_limit/
    ├── limiter.ex               # L4.4.1.1
    ├── backoff.ex               # L4.4.1.2
    └── quota.ex                 # L4.4.1.3

lib/cepaf/src/Cepaf/Mcp/
├── Server.fs                    # L1.1.2.1
├── Protocol.fs                  # L1.1.2.2
├── Transport.fs                 # L1.1.2.3
└── Bridge.fs                    # L1.1.2.4

test/indrajaal/mcp/
├── server_test.exs
├── jsonrpc_test.exs
├── tool_test.exs
├── microsoft/
│   └── graph_client_test.exs
└── auth/
    └── oauth_test.exs

docs/runbooks/mcp/
├── high_error_rate.md
├── auth_failure.md
├── api_throttling.md
├── restart_procedure.md
└── emergency_shutdown.md
```

---

**Document Status**: READY FOR REVIEW
**Next Action**: Founder approval to proceed with Phase 1 implementation
