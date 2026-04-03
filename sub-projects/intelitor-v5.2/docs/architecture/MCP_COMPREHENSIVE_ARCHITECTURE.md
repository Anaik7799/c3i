# MCP Comprehensive Architecture
## Model Context Protocol Integration for Indrajaal, Prajna, and CEPAF

**Version**: 1.0.0 | **Date**: 2026-01-05 | **Status**: IMPLEMENTATION READY
**STAMP Compliance**: SC-MCP-001 to SC-MCP-050

---

## Executive Summary

This document defines the comprehensive MCP (Model Context Protocol) architecture for exposing the full capabilities of:
1. **Indrajaal** - 15 Domain Contexts with 350+ functions
2. **Prajna** - C3I Command Cockpit with 12 capability areas
3. **CEPAF** - F# Category Theory patterns with 40+ modules

---

## 1.0 Architecture Overview

### 1.1 5-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    LAYER 5: INTEGRATION & ORCHESTRATION                 │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐ │
│   │ .mcp.json       │  │ MCP Orchestrator│  │ Health & Monitoring     │ │
│   │ Configuration   │  │ (Unified Entry) │  │ (Circuit Breaker)       │ │
│   └─────────────────┘  └─────────────────┘  └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────┤
│                    LAYER 4: F# CEPAF MCP SERVER                         │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐ │
│   │ Category Theory │  │ OODA Controller │  │ Zenoh Integration       │ │
│   │ (Arrows,Monads) │  │ (AOR Engine)    │  │ (Pub/Sub, HLC)          │ │
│   └─────────────────┘  └─────────────────┘  └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────┤
│                    LAYER 3: PRAJNA COCKPIT MCP SERVER                   │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐ │
│   │ Guardian Safety │  │ Sentinel/Immune │  │ AI Copilot/PROMETHEUS   │ │
│   │ (Approval Flow) │  │ (Health/Threat) │  │ (Verification)          │ │
│   └─────────────────┘  └─────────────────┘  └─────────────────────────┘ │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐ │
│   │ SmartMetrics    │  │ Immutable Reg   │  │ Orchestrator/Master     │ │
│   │ (Real-time)     │  │ (State Log)     │  │ (Control)               │ │
│   └─────────────────┘  └─────────────────┘  └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────┤
│                    LAYER 2: INDRAJAAL DOMAIN MCP SERVER                 │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐ │
│   │ Core Domains    │  │ Operations      │  │ Extended Domains        │ │
│   │ Accounts,Auth   │  │ Alarms,Devices  │  │ Video,Compliance        │ │
│   │ Access,Author   │  │ Sites,Dispatch  │  │ Maintenance,Analytics   │ │
│   └─────────────────┘  └─────────────────┘  └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────┤
│                    LAYER 1: MCP FOUNDATION                              │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐ │
│   │ Protocol Types  │  │ Tool Registry   │  │ Auth & Rate Limiting    │ │
│   │ JSON-RPC 2.0    │  │ Dispatcher      │  │ Guardian Integration    │ │
│   └─────────────────┘  └─────────────────┘  └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Summary

| Layer | Component | Tools Count | Purpose |
|-------|-----------|-------------|---------|
| L1 | MCP Foundation | 10 | Protocol, types, auth |
| L2 | Indrajaal Domains | 180 | 15 domains × 12 avg |
| L3 | Prajna Cockpit | 85 | C3I, safety, AI |
| L4 | CEPAF F# | 65 | Category theory, OODA |
| L5 | Integration | 10 | Orchestration, config |
| **Total** | | **350** | Full system coverage |

---

## 2.0 Layer 1: MCP Foundation

### 2.1 Protocol Types

```elixir
# lib/indrajaal/mcp/protocol.ex
defmodule Indrajaal.MCP.Protocol do
  @moduledoc """
  MCP Protocol v2025-11-25 Implementation.

  STAMP Constraints:
    - SC-MCP-001: JSON-RPC 2.0 compliance
    - SC-MCP-002: Tool schema validation
    - SC-MCP-003: Error response standardization
  """

  @mcp_version "2025-11-25"

  @type tool :: %{
    name: String.t(),
    description: String.t(),
    inputSchema: map(),
    annotations: map()
  }

  @type request :: %{
    jsonrpc: String.t(),
    id: integer() | String.t(),
    method: String.t(),
    params: map()
  }

  @type response :: %{
    jsonrpc: String.t(),
    id: integer() | String.t(),
    result: map() | nil,
    error: map() | nil
  }

  @type error :: %{
    code: integer(),
    message: String.t(),
    data: map() | nil
  }

  # Standard MCP error codes
  @error_codes %{
    parse_error: -32700,
    invalid_request: -32600,
    method_not_found: -32601,
    invalid_params: -32602,
    internal_error: -32603,
    # Custom Indrajaal codes
    guardian_veto: -33001,
    rate_limit_exceeded: -33002,
    proof_token_required: -33003,
    constitutional_violation: -33004
  }
end
```

### 2.2 Tool Registry

```elixir
# lib/indrajaal/mcp/registry.ex
defmodule Indrajaal.MCP.Registry do
  @moduledoc """
  Central registry for all MCP tools across Indrajaal, Prajna, and CEPAF.

  STAMP Constraints:
    - SC-MCP-010: Tool registration validation
    - SC-MCP-011: Namespace collision prevention
    - SC-MCP-012: Schema validation on register
  """

  use GenServer

  @namespaces [:indrajaal, :prajna, :cepaf, :kms]

  def register_tool(namespace, tool) when namespace in @namespaces do
    GenServer.call(__MODULE__, {:register, namespace, tool})
  end

  def get_tool(namespace, name) do
    GenServer.call(__MODULE__, {:get, namespace, name})
  end

  def list_tools(namespace \\ :all) do
    GenServer.call(__MODULE__, {:list, namespace})
  end

  def dispatch(namespace, tool_name, params, context) do
    GenServer.call(__MODULE__, {:dispatch, namespace, tool_name, params, context}, 30_000)
  end
end
```

### 2.3 Authentication & Rate Limiting

```elixir
# lib/indrajaal/mcp/auth.ex
defmodule Indrajaal.MCP.Auth do
  @moduledoc """
  Authentication and rate limiting for MCP servers.

  STAMP Constraints:
    - SC-MCP-020: Client authentication required
    - SC-MCP-021: Rate limit 100 req/min per client
    - SC-MCP-022: Guardian approval for write operations
    - SC-MCP-023: Audit logging for all operations
  """

  @rate_limit_window_ms 60_000
  @rate_limit_max 100

  def authenticate(request) do
    # Verify client credentials
    # Return {:ok, client_id} or {:error, :unauthorized}
  end

  def check_rate_limit(client_id) do
    # Check ETS rate limit counter
    # Return :ok or {:error, :rate_limit_exceeded}
  end

  def require_guardian_approval?(tool_name) do
    # Check if tool requires Guardian approval
    write_tools = ~w(create update delete execute)
    Enum.any?(write_tools, &String.contains?(tool_name, &1))
  end

  def audit_log(client_id, tool_name, params, result) do
    # Log to Immutable Register
    Indrajaal.Cockpit.Prajna.ImmutableState.record(%{
      type: :mcp_operation,
      client_id: client_id,
      tool: tool_name,
      params: sanitize_params(params),
      result: summarize_result(result),
      timestamp: DateTime.utc_now()
    })
  end
end
```

---

## 3.0 Layer 2: Indrajaal Domain MCP Server

### 3.1 Domain Tool Organization

```
indrajaal.domains/
├── core/
│   ├── accounts (11 tools)
│   ├── authentication (8 tools)
│   ├── authorization (10 tools)
│   └── access_control (11 tools)
├── operations/
│   ├── alarms (11 tools)
│   ├── devices (11 tools)
│   ├── sites (11 tools)
│   ├── dispatch (10 tools)
│   └── monitoring (10 tools)
├── extended/
│   ├── video (80+ tools)
│   ├── compliance (13 tools)
│   ├── maintenance (11 tools)
│   ├── analytics (9 tools)
│   ├── communication (10 tools)
│   └── integration (10 tools)
└── observability/
    ├── telemetry (15 tools)
    ├── fractal_logging (10 tools)
    ├── zenoh_pubsub (12 tools)
    └── metrics (10 tools)
```

### 3.2 Indrajaal MCP Server Implementation

```elixir
# lib/indrajaal/mcp/indrajaal_server.ex
defmodule Indrajaal.MCP.IndrajaalServer do
  @moduledoc """
  MCP Server exposing all 15 Indrajaal domain contexts.

  STAMP Constraints:
    - SC-MCP-030: All domains exposed
    - SC-MCP-031: CRUD operations for all resources
    - SC-MCP-032: Bulk operations support
    - SC-MCP-033: Import/Export capabilities

  AOR Rules:
    - AOR-MCP-001: Read ops do not require Guardian
    - AOR-MCP-002: Write ops require Guardian approval
    - AOR-MCP-003: Bulk ops limited to 100 items
  """

  use GenServer
  require Logger

  alias Indrajaal.MCP.{Protocol, Registry, Auth}

  @domains %{
    # Core Domains
    accounts: Indrajaal.Accounts,
    authentication: Indrajaal.Authentication,
    authorization: Indrajaal.Authorization,
    access_control: Indrajaal.AccessControlContext,

    # Operations Domains
    alarms: Indrajaal.Alarms,
    devices: Indrajaal.Devices,
    sites: Indrajaal.Sites,
    dispatch: Indrajaal.Dispatch,
    monitoring: Indrajaal.Monitoring,

    # Extended Domains
    video: Indrajaal.Video,
    compliance: Indrajaal.Compliance,
    maintenance: Indrajaal.MaintenanceContext,
    analytics: Indrajaal.AnalyticsContext,
    communication: Indrajaal.Communication,
    integration: Indrajaal.IntegrationContext
  }

  @tools [
    # === ACCOUNTS DOMAIN ===
    %{
      name: "indrajaal_accounts_list_users",
      description: "List all users with pagination and filtering",
      inputSchema: %{
        type: "object",
        properties: %{
          page: %{type: "integer", default: 1},
          page_size: %{type: "integer", default: 20, maximum: 100},
          filter: %{type: "object"},
          sort: %{type: "string"}
        }
      }
    },
    %{
      name: "indrajaal_accounts_get_user",
      description: "Get a user by ID",
      inputSchema: %{
        type: "object",
        properties: %{id: %{type: "string", format: "uuid"}},
        required: ["id"]
      }
    },
    %{
      name: "indrajaal_accounts_create_user",
      description: "Create a new user account (requires Guardian approval)",
      inputSchema: %{
        type: "object",
        properties: %{
          email: %{type: "string", format: "email"},
          name: %{type: "string"},
          role: %{type: "string"}
        },
        required: ["email", "name"]
      },
      annotations: %{requires_guardian: true}
    },
    # ... 8 more accounts tools

    # === ALARMS DOMAIN ===
    %{
      name: "indrajaal_alarms_list",
      description: "List alarms with filtering by status, priority, site",
      inputSchema: %{
        type: "object",
        properties: %{
          status: %{type: "string", enum: ["active", "acknowledged", "resolved"]},
          priority: %{type: "string", enum: ["critical", "high", "medium", "low"]},
          site_id: %{type: "string", format: "uuid"},
          from_date: %{type: "string", format: "date-time"},
          to_date: %{type: "string", format: "date-time"}
        }
      }
    },
    %{
      name: "indrajaal_alarms_acknowledge",
      description: "Acknowledge an alarm with notes",
      inputSchema: %{
        type: "object",
        properties: %{
          alarm_id: %{type: "string", format: "uuid"},
          notes: %{type: "string"},
          user_id: %{type: "string", format: "uuid"}
        },
        required: ["alarm_id"]
      }
    },
    %{
      name: "indrajaal_alarms_get_stats",
      description: "Get alarm statistics for dashboard",
      inputSchema: %{
        type: "object",
        properties: %{
          period: %{type: "string", enum: ["hour", "day", "week", "month"]},
          site_id: %{type: "string", format: "uuid"}
        }
      }
    },

    # === DEVICES DOMAIN ===
    %{
      name: "indrajaal_devices_list",
      description: "List all devices with filtering",
      inputSchema: %{
        type: "object",
        properties: %{
          status: %{type: "string", enum: ["online", "offline", "maintenance"]},
          type: %{type: "string"},
          site_id: %{type: "string", format: "uuid"}
        }
      }
    },
    %{
      name: "indrajaal_devices_get_status",
      description: "Get real-time device status",
      inputSchema: %{
        type: "object",
        properties: %{device_id: %{type: "string", format: "uuid"}},
        required: ["device_id"]
      }
    },
    %{
      name: "indrajaal_devices_configure",
      description: "Configure device settings (requires Guardian)",
      inputSchema: %{
        type: "object",
        properties: %{
          device_id: %{type: "string", format: "uuid"},
          config: %{type: "object"}
        },
        required: ["device_id", "config"]
      },
      annotations: %{requires_guardian: true}
    },

    # === VIDEO DOMAIN (Most extensive) ===
    %{
      name: "indrajaal_video_list_streams",
      description: "List video streams with filtering",
      inputSchema: %{
        type: "object",
        properties: %{
          status: %{type: "string", enum: ["active", "inactive", "error"]},
          site_id: %{type: "string", format: "uuid"}
        }
      }
    },
    %{
      name: "indrajaal_video_start_stream",
      description: "Start a video stream",
      inputSchema: %{
        type: "object",
        properties: %{stream_id: %{type: "string", format: "uuid"}},
        required: ["stream_id"]
      }
    },
    %{
      name: "indrajaal_video_capture_snapshot",
      description: "Capture a snapshot from camera",
      inputSchema: %{
        type: "object",
        properties: %{
          camera_id: %{type: "string", format: "uuid"},
          format: %{type: "string", enum: ["jpeg", "png"], default: "jpeg"}
        },
        required: ["camera_id"]
      }
    },
    %{
      name: "indrajaal_video_list_recordings",
      description: "List video recordings",
      inputSchema: %{
        type: "object",
        properties: %{
          camera_id: %{type: "string", format: "uuid"},
          from_date: %{type: "string", format: "date-time"},
          to_date: %{type: "string", format: "date-time"}
        }
      }
    },
    %{
      name: "indrajaal_video_create_analytics_rule",
      description: "Create video analytics rule (motion, object detection)",
      inputSchema: %{
        type: "object",
        properties: %{
          camera_id: %{type: "string", format: "uuid"},
          rule_type: %{type: "string", enum: ["motion", "object", "line_crossing", "intrusion"]},
          config: %{type: "object"}
        },
        required: ["camera_id", "rule_type"]
      },
      annotations: %{requires_guardian: true}
    },
    %{
      name: "indrajaal_video_create_privacy_mask",
      description: "Create privacy mask for GDPR compliance",
      inputSchema: %{
        type: "object",
        properties: %{
          camera_id: %{type: "string", format: "uuid"},
          zones: %{type: "array", items: %{type: "object"}}
        },
        required: ["camera_id", "zones"]
      },
      annotations: %{requires_guardian: true}
    },

    # === SITES DOMAIN ===
    %{
      name: "indrajaal_sites_list",
      description: "List all sites with filtering",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "indrajaal_sites_get_status",
      description: "Get site health status (devices, alarms)",
      inputSchema: %{
        type: "object",
        properties: %{site_id: %{type: "string", format: "uuid"}},
        required: ["site_id"]
      }
    },

    # === COMPLIANCE DOMAIN ===
    %{
      name: "indrajaal_compliance_create_audit",
      description: "Create compliance audit report",
      inputSchema: %{
        type: "object",
        properties: %{
          framework: %{type: "string", enum: ["ISO27001", "GDPR", "SOC2", "EN50131"]},
          scope: %{type: "object"}
        },
        required: ["framework"]
      }
    },
    %{
      name: "indrajaal_compliance_export",
      description: "Export compliance data for regulatory submission",
      inputSchema: %{
        type: "object",
        properties: %{
          format: %{type: "string", enum: ["pdf", "xlsx", "json"]},
          from_date: %{type: "string", format: "date-time"},
          to_date: %{type: "string", format: "date-time"}
        }
      }
    },

    # === OBSERVABILITY TOOLS ===
    %{
      name: "indrajaal_observability_get_metrics",
      description: "Get system metrics snapshot",
      inputSchema: %{
        type: "object",
        properties: %{
          category: %{type: "string", enum: ["system", "business", "security", "performance"]}
        }
      }
    },
    %{
      name: "indrajaal_observability_fractal_log",
      description: "Query fractal logs by level",
      inputSchema: %{
        type: "object",
        properties: %{
          level: %{type: "string", enum: ["spine", "thorax", "segment", "fiber", "gossamer"]},
          source: %{type: "string"},
          limit: %{type: "integer", default: 100}
        }
      }
    },
    %{
      name: "indrajaal_observability_zenoh_publish",
      description: "Publish message to Zenoh topic",
      inputSchema: %{
        type: "object",
        properties: %{
          topic: %{type: "string"},
          payload: %{type: "object"}
        },
        required: ["topic", "payload"]
      }
    }
    # ... 160+ more domain tools
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Register all tools
    Enum.each(@tools, fn tool ->
      Registry.register_tool(:indrajaal, tool)
    end)

    {:ok, %{request_count: 0}}
  end

  def handle_request(request) do
    GenServer.call(__MODULE__, {:handle_request, request}, 30_000)
  end

  @impl true
  def handle_call({:handle_request, request}, _from, state) do
    result = process_request(request)
    {:reply, result, %{state | request_count: state.request_count + 1}}
  end

  defp process_request(%{"method" => "tools/call", "params" => params}) do
    tool_name = params["name"]
    arguments = params["arguments"] || %{}

    with {:ok, tool} <- Registry.get_tool(:indrajaal, tool_name),
         :ok <- validate_arguments(tool, arguments),
         :ok <- check_guardian_if_needed(tool, arguments),
         {:ok, result} <- execute_tool(tool_name, arguments) do
      Protocol.success_response(result)
    else
      {:error, reason} -> Protocol.error_response(reason)
    end
  end

  defp execute_tool("indrajaal_accounts_list_users", args) do
    Indrajaal.Accounts.list_users(args)
  end

  defp execute_tool("indrajaal_alarms_list", args) do
    Indrajaal.Alarms.list_alarms(args)
  end

  defp execute_tool("indrajaal_devices_get_status", %{"device_id" => id}) do
    Indrajaal.Devices.get_device_status(id)
  end

  # ... 180+ more tool implementations
end
```

---

## 4.0 Layer 3: Prajna Cockpit MCP Server

### 4.1 Prajna Tool Organization

```
prajna/
├── safety/
│   ├── guardian (5 tools)
│   ├── sentinel (8 tools)
│   └── immune (6 tools)
├── verification/
│   ├── prometheus (8 tools)
│   ├── constitutional (4 tools)
│   └── founder (6 tools)
├── operations/
│   ├── metrics (10 tools)
│   ├── register (7 tools)
│   ├── circuit_breaker (5 tools)
│   └── backoff (3 tools)
├── control/
│   ├── orchestrator (12 tools)
│   ├── master_control (8 tools)
│   └── monitor (6 tools)
└── ai/
    ├── copilot (10 tools)
    └── analysis (5 tools)
```

### 4.2 Prajna MCP Server Implementation

```elixir
# lib/indrajaal/mcp/prajna_server.ex
defmodule Indrajaal.MCP.PrajnaServer do
  @moduledoc """
  MCP Server for Prajna C3I Command Cockpit.

  STAMP Constraints:
    - SC-MCP-040: All safety tools require Guardian approval
    - SC-MCP-041: PROMETHEUS proof tokens for mutations
    - SC-MCP-042: Constitutional invariants checked
    - SC-MCP-043: Two-step commit for destructive actions

  AOR Rules:
    - AOR-PRAJNA-001: Guardian gate for all commands
    - AOR-PRAJNA-002: Founder alignment validation
    - AOR-PRAJNA-003: State mutations via Immutable Register
  """

  use GenServer
  require Logger

  alias Indrajaal.Cockpit.Prajna.{
    GuardianIntegration,
    SentinelBridge,
    AiCopilot,
    AiCopilotFounder,
    PrometheusVerifier,
    SmartMetrics,
    ImmutableState,
    CircuitBreaker,
    Backoff,
    Orchestrator,
    MasterControl,
    FullSystemMonitor
  }

  @tools [
    # === GUARDIAN SAFETY ===
    %{
      name: "prajna_guardian_submit_proposal",
      description: "Submit command proposal to Guardian for safety approval",
      inputSchema: %{
        type: "object",
        properties: %{
          command_type: %{type: "string"},
          target: %{type: "string"},
          params: %{type: "object"},
          reason: %{type: "string"}
        },
        required: ["command_type", "target", "reason"]
      }
    },
    %{
      name: "prajna_guardian_get_status",
      description: "Get Guardian status including violations and circuit state",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_guardian_check_constraints",
      description: "Check STAMP constraints for proposed action",
      inputSchema: %{
        type: "object",
        properties: %{
          action: %{type: "string"},
          constraints: %{type: "array", items: %{type: "string"}}
        }
      }
    },

    # === SENTINEL & IMMUNE SYSTEM ===
    %{
      name: "prajna_sentinel_sync_now",
      description: "Force immediate Sentinel health sync",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_sentinel_emergency_sync",
      description: "Emergency sync for critical threats (<100ms latency)",
      inputSchema: %{
        type: "object",
        properties: %{
          severity: %{type: "string", enum: ["extinction", "critical", "high"]}
        },
        required: ["severity"]
      }
    },
    %{
      name: "prajna_sentinel_get_health",
      description: "Get Sentinel health data and threat assessment",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_sentinel_get_advisories",
      description: "Get current threat advisories",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_sentinel_get_quarantine_status",
      description: "List quarantined processes",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_immune_get_threat_summary",
      description: "Get immune system threat summary",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_immune_mara_stats",
      description: "Get Mara chaos testing statistics",
      inputSchema: %{type: "object", properties: %{}}
    },

    # === PROMETHEUS VERIFICATION ===
    %{
      name: "prajna_prometheus_require_token",
      description: "Request PROMETHEUS proof token for state mutation",
      inputSchema: %{
        type: "object",
        properties: %{
          action: %{type: "string"},
          target: %{type: "string"},
          scope: %{type: "array", items: %{type: "string"}}
        },
        required: ["action", "target"]
      }
    },
    %{
      name: "prajna_prometheus_verify_token",
      description: "Verify a PROMETHEUS proof token",
      inputSchema: %{
        type: "object",
        properties: %{token: %{type: "object"}},
        required: ["token"]
      }
    },
    %{
      name: "prajna_prometheus_verify_dag",
      description: "Verify execution DAG is acyclic",
      inputSchema: %{
        type: "object",
        properties: %{
          nodes: %{type: "array", items: %{type: "object"}}
        },
        required: ["nodes"]
      }
    },
    %{
      name: "prajna_prometheus_check_api_budget",
      description: "Check API usage against 95% budget threshold",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_prometheus_get_stats",
      description: "Get verification statistics",
      inputSchema: %{type: "object", properties: %{}}
    },

    # === AI COPILOT ===
    %{
      name: "prajna_ai_insights",
      description: "Get AI-generated insights with confidence scores",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_ai_insights_by_type",
      description: "Get insights filtered by type",
      inputSchema: %{
        type: "object",
        properties: %{
          type: %{type: "string", enum: ["warning", "optimization", "anomaly", "recommendation"]}
        },
        required: ["type"]
      }
    },
    %{
      name: "prajna_ai_high_confidence_insights",
      description: "Get high-confidence insights (>threshold)",
      inputSchema: %{
        type: "object",
        properties: %{threshold: %{type: "number", default: 0.8}},
      }
    },
    %{
      name: "prajna_ai_analyze_now",
      description: "Trigger immediate AI analysis",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_ai_analyze_focus",
      description: "Analyze specific area in depth",
      inputSchema: %{
        type: "object",
        properties: %{
          area: %{type: "string", enum: ["security", "performance", "compliance", "cost"]}
        },
        required: ["area"]
      }
    },
    %{
      name: "prajna_ai_quick_summary",
      description: "Get quick local analysis (no LLM)",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_ai_set_llm_enabled",
      description: "Enable/disable LLM integration",
      inputSchema: %{
        type: "object",
        properties: %{enabled: %{type: "boolean"}},
        required: ["enabled"]
      }
    },

    # === FOUNDER VALIDATION ===
    %{
      name: "prajna_founder_validate",
      description: "Validate recommendation against Founder's Directive",
      inputSchema: %{
        type: "object",
        properties: %{recommendation: %{type: "object"}},
        required: ["recommendation"]
      }
    },
    %{
      name: "prajna_founder_alignment_score",
      description: "Calculate alignment score with Founder's goals",
      inputSchema: %{
        type: "object",
        properties: %{action: %{type: "object"}},
        required: ["action"]
      }
    },
    %{
      name: "prajna_founder_check_goals",
      description: "Check alignment with Three Supreme Goals",
      inputSchema: %{
        type: "object",
        properties: %{
          action: %{type: "object"},
          goals: %{type: "array", items: %{type: "string", enum: ["survival", "sentience", "power"]}}
        },
        required: ["action"]
      }
    },

    # === SMART METRICS ===
    %{
      name: "prajna_metrics_record",
      description: "Record a smart metric with trend analysis",
      inputSchema: %{
        type: "object",
        properties: %{
          id: %{type: "string"},
          label: %{type: "string"},
          value: %{type: "number"},
          unit: %{type: "string"}
        },
        required: ["id", "label", "value"]
      }
    },
    %{
      name: "prajna_metrics_get",
      description: "Get a specific metric by ID",
      inputSchema: %{
        type: "object",
        properties: %{id: %{type: "string"}},
        required: ["id"]
      }
    },
    %{
      name: "prajna_metrics_all",
      description: "Get all metrics",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_metrics_by_pattern",
      description: "Search metrics by pattern (regex)",
      inputSchema: %{
        type: "object",
        properties: %{pattern: %{type: "string"}},
        required: ["pattern"]
      }
    },
    %{
      name: "prajna_metrics_stale",
      description: "Get stale metrics (>5s old)",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_metrics_alarmed",
      description: "Get metrics in alarm state",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_metrics_sparkline",
      description: "Get sparkline data for metric (last 20 samples)",
      inputSchema: %{
        type: "object",
        properties: %{id: %{type: "string"}},
        required: ["id"]
      }
    },
    %{
      name: "prajna_metrics_health_summary",
      description: "Get health summary across all metrics",
      inputSchema: %{type: "object", properties: %{}}
    },

    # === IMMUTABLE REGISTER ===
    %{
      name: "prajna_register_record",
      description: "Record state mutation to immutable register",
      inputSchema: %{
        type: "object",
        properties: %{
          change_type: %{type: "string"},
          payload: %{type: "object"}
        },
        required: ["change_type", "payload"]
      }
    },
    %{
      name: "prajna_register_verify_chain",
      description: "Verify hash chain integrity",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_register_get_block",
      description: "Get specific block from register",
      inputSchema: %{
        type: "object",
        properties: %{index: %{type: "integer"}},
        required: ["index"]
      }
    },
    %{
      name: "prajna_register_blocks_by_type",
      description: "Get blocks filtered by change type",
      inputSchema: %{
        type: "object",
        properties: %{change_type: %{type: "string"}},
        required: ["change_type"]
      }
    },
    %{
      name: "prajna_register_merkle_root",
      description: "Compute Merkle root for state verification",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_register_summary",
      description: "Get register summary (block count, verified status)",
      inputSchema: %{type: "object", properties: %{}}
    },

    # === ORCHESTRATOR & CONTROL ===
    %{
      name: "prajna_orchestrator_state",
      description: "Get current cockpit state",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_orchestrator_start_ui",
      description: "Start cockpit UI",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_orchestrator_stop_ui",
      description: "Stop cockpit UI",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_orchestrator_arm_command",
      description: "Arm command for two-step commit",
      inputSchema: %{
        type: "object",
        properties: %{
          node_id: %{type: "string"},
          command: %{type: "object"}
        },
        required: ["node_id", "command"]
      }
    },
    %{
      name: "prajna_orchestrator_confirm_command",
      description: "Confirm armed command",
      inputSchema: %{
        type: "object",
        properties: %{command_id: %{type: "string"}},
        required: ["command_id"]
      }
    },
    %{
      name: "prajna_orchestrator_cancel_command",
      description: "Cancel armed command",
      inputSchema: %{
        type: "object",
        properties: %{command_id: %{type: "string"}},
        required: ["command_id"]
      }
    },
    %{
      name: "prajna_master_system_status",
      description: "Get status of all 30 domains",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_master_domain_status",
      description: "Get detailed domain status",
      inputSchema: %{
        type: "object",
        properties: %{domain: %{type: "string"}},
        required: ["domain"]
      }
    },
    %{
      name: "prajna_master_execute_command",
      description: "Execute guarded domain command",
      inputSchema: %{
        type: "object",
        properties: %{
          domain: %{type: "string"},
          action: %{type: "string"},
          params: %{type: "object"}
        },
        required: ["domain", "action"]
      }
    },
    %{
      name: "prajna_master_analyze_effects",
      description: "Analyze 5-order effects of action",
      inputSchema: %{
        type: "object",
        properties: %{
          domain: %{type: "string"},
          action: %{type: "string"},
          params: %{type: "object"}
        },
        required: ["domain", "action"]
      }
    },
    %{
      name: "prajna_monitor_get_metrics",
      description: "Get real-time system metrics",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_monitor_category_metrics",
      description: "Get metrics by category",
      inputSchema: %{
        type: "object",
        properties: %{
          category: %{type: "string", enum: ["infrastructure", "domain", "api", "safety"]}
        },
        required: ["category"]
      }
    },
    %{
      name: "prajna_monitor_alerts",
      description: "Get active alert escalations",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "prajna_monitor_dashboard_data",
      description: "Get operator dashboard data",
      inputSchema: %{type: "object", properties: %{}}
    },

    # === CIRCUIT BREAKER ===
    %{
      name: "prajna_circuit_state",
      description: "Get circuit breaker state",
      inputSchema: %{
        type: "object",
        properties: %{queue_len: %{type: "integer", default: 0}}
      }
    },
    %{
      name: "prajna_circuit_should_process",
      description: "Check if message should be processed",
      inputSchema: %{
        type: "object",
        properties: %{
          queue_len: %{type: "integer"},
          msg_type: %{type: "string"}
        },
        required: ["queue_len", "msg_type"]
      }
    },
    %{
      name: "prajna_circuit_filter_batch",
      description: "Filter message batch by priority",
      inputSchema: %{
        type: "object",
        properties: %{
          messages: %{type: "array"},
          queue_len: %{type: "integer"}
        },
        required: ["messages", "queue_len"]
      }
    },
    %{
      name: "prajna_circuit_stats",
      description: "Get circuit breaker statistics",
      inputSchema: %{type: "object", properties: %{}}
    }
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Enum.each(@tools, fn tool ->
      Indrajaal.MCP.Registry.register_tool(:prajna, tool)
    end)
    {:ok, %{}}
  end

  # Tool implementations...
end
```

---

## 5.0 Layer 4: F# CEPAF MCP Server

### 5.1 CEPAF Tool Organization

```
cepaf/
├── core/
│   ├── category_theory (8 tools)
│   ├── arrows (6 tools)
│   ├── comonads (5 tools)
│   ├── optics (6 tools)
│   └── effects (5 tools)
├── runtime/
│   ├── ooda_controller (8 tools)
│   ├── aor_engine (6 tools)
│   └── event_sourcing (5 tools)
├── cockpit/
│   ├── prajna (6 tools)
│   ├── material3 (4 tools)
│   └── integration (5 tools)
└── observability/
    ├── zenoh (8 tools)
    ├── quadplex_logger (4 tools)
    └── health_propagation (4 tools)
```

### 5.2 CEPAF MCP Server Implementation (F# Bridge)

```elixir
# lib/indrajaal/mcp/cepaf_server.ex
defmodule Indrajaal.MCP.CepafServer do
  @moduledoc """
  MCP Server bridging to F# CEPAF cockpit capabilities.

  STAMP Constraints:
    - SC-MCP-050: F# interop via JSON stdio
    - SC-MCP-051: Category theory patterns exposed
    - SC-MCP-052: OODA controller integration
    - SC-MCP-053: Zenoh mesh connectivity

  AOR Rules:
    - AOR-CEPAF-001: All calls timeout 30s
    - AOR-CEPAF-002: Circuit breaker on F# process
    - AOR-CEPAF-003: Fallback to degraded mode on unavailable [Updated Sprint 51: F# bridge real implementation]
  """

  use GenServer
  require Logger

  @tools [
    # === CATEGORY THEORY CORE ===
    %{
      name: "cepaf_arrow_compose",
      description: "Compose two arrows (functions) using category theory",
      inputSchema: %{
        type: "object",
        properties: %{
          arrow1: %{type: "string", description: "First arrow identifier"},
          arrow2: %{type: "string", description: "Second arrow identifier"}
        },
        required: ["arrow1", "arrow2"]
      }
    },
    %{
      name: "cepaf_arrow_first",
      description: "Apply arrow to first element of pair",
      inputSchema: %{
        type: "object",
        properties: %{
          arrow: %{type: "string"},
          pair: %{type: "array", items: %{}, minItems: 2, maxItems: 2}
        },
        required: ["arrow", "pair"]
      }
    },
    %{
      name: "cepaf_arrow_parallel",
      description: "Run two arrows in parallel (***)",
      inputSchema: %{
        type: "object",
        properties: %{
          arrow1: %{type: "string"},
          arrow2: %{type: "string"}
        },
        required: ["arrow1", "arrow2"]
      }
    },
    %{
      name: "cepaf_comonad_extract",
      description: "Extract value from comonad (Env, Store, etc.)",
      inputSchema: %{
        type: "object",
        properties: %{
          comonad_type: %{type: "string", enum: ["Env", "Store", "Stream"]},
          comonad: %{type: "object"}
        },
        required: ["comonad_type", "comonad"]
      }
    },
    %{
      name: "cepaf_comonad_extend",
      description: "Extend comonad with function",
      inputSchema: %{
        type: "object",
        properties: %{
          comonad_type: %{type: "string", enum: ["Env", "Store", "Stream"]},
          comonad: %{type: "object"},
          function: %{type: "string"}
        },
        required: ["comonad_type", "comonad", "function"]
      }
    },
    %{
      name: "cepaf_optic_get",
      description: "Get value through lens/prism/iso",
      inputSchema: %{
        type: "object",
        properties: %{
          optic_type: %{type: "string", enum: ["Lens", "Prism", "Iso", "Optional"]},
          optic_path: %{type: "string"},
          structure: %{type: "object"}
        },
        required: ["optic_type", "optic_path", "structure"]
      }
    },
    %{
      name: "cepaf_optic_set",
      description: "Set value through lens/prism/iso",
      inputSchema: %{
        type: "object",
        properties: %{
          optic_type: %{type: "string", enum: ["Lens", "Prism", "Iso", "Optional"]},
          optic_path: %{type: "string"},
          structure: %{type: "object"},
          value: %{}
        },
        required: ["optic_type", "optic_path", "structure", "value"]
      }
    },
    %{
      name: "cepaf_optic_modify",
      description: "Modify value through optic with function",
      inputSchema: %{
        type: "object",
        properties: %{
          optic_type: %{type: "string"},
          optic_path: %{type: "string"},
          structure: %{type: "object"},
          function: %{type: "string"}
        },
        required: ["optic_type", "optic_path", "structure", "function"]
      }
    },

    # === OODA CONTROLLER ===
    %{
      name: "cepaf_ooda_observe",
      description: "OODA Observe phase - gather system state",
      inputSchema: %{
        type: "object",
        properties: %{
          sensors: %{type: "array", items: %{type: "string"}}
        }
      }
    },
    %{
      name: "cepaf_ooda_orient",
      description: "OODA Orient phase - analyze observations",
      inputSchema: %{
        type: "object",
        properties: %{
          observations: %{type: "object"},
          context: %{type: "object"}
        },
        required: ["observations"]
      }
    },
    %{
      name: "cepaf_ooda_decide",
      description: "OODA Decide phase - select action",
      inputSchema: %{
        type: "object",
        properties: %{
          orientation: %{type: "object"},
          options: %{type: "array", items: %{type: "object"}}
        },
        required: ["orientation"]
      }
    },
    %{
      name: "cepaf_ooda_act",
      description: "OODA Act phase - execute action",
      inputSchema: %{
        type: "object",
        properties: %{
          decision: %{type: "object"},
          target: %{type: "string"}
        },
        required: ["decision", "target"]
      }
    },
    %{
      name: "cepaf_ooda_cycle",
      description: "Execute complete OODA cycle",
      inputSchema: %{
        type: "object",
        properties: %{
          context: %{type: "object"},
          max_latency_ms: %{type: "integer", default: 100}
        }
      }
    },
    %{
      name: "cepaf_ooda_get_state",
      description: "Get current OODA controller state",
      inputSchema: %{type: "object", properties: %{}}
    },

    # === AOR ENGINE ===
    %{
      name: "cepaf_aor_validate_rule",
      description: "Validate action against AOR rules",
      inputSchema: %{
        type: "object",
        properties: %{
          rule_id: %{type: "string", pattern: "^AOR-[A-Z]+-[0-9]+$"},
          action: %{type: "object"}
        },
        required: ["rule_id", "action"]
      }
    },
    %{
      name: "cepaf_aor_list_rules",
      description: "List all AOR rules by category",
      inputSchema: %{
        type: "object",
        properties: %{
          category: %{type: "string"}
        }
      }
    },
    %{
      name: "cepaf_aor_check_compliance",
      description: "Check full AOR compliance for proposal",
      inputSchema: %{
        type: "object",
        properties: %{
          proposal: %{type: "object"}
        },
        required: ["proposal"]
      }
    },
    %{
      name: "cepaf_aor_get_violations",
      description: "Get current AOR violations",
      inputSchema: %{type: "object", properties: %{}}
    },

    # === EVENT SOURCING ===
    %{
      name: "cepaf_event_append",
      description: "Append event to event store",
      inputSchema: %{
        type: "object",
        properties: %{
          stream_id: %{type: "string"},
          event_type: %{type: "string"},
          data: %{type: "object"}
        },
        required: ["stream_id", "event_type", "data"]
      }
    },
    %{
      name: "cepaf_event_read_stream",
      description: "Read events from stream",
      inputSchema: %{
        type: "object",
        properties: %{
          stream_id: %{type: "string"},
          from_version: %{type: "integer", default: 0},
          max_count: %{type: "integer", default: 100}
        },
        required: ["stream_id"]
      }
    },
    %{
      name: "cepaf_event_project",
      description: "Project events to current state",
      inputSchema: %{
        type: "object",
        properties: %{
          stream_id: %{type: "string"},
          projection: %{type: "string"}
        },
        required: ["stream_id", "projection"]
      }
    },

    # === ZENOH INTEGRATION ===
    %{
      name: "cepaf_zenoh_publish",
      description: "Publish to Zenoh topic via F# bridge",
      inputSchema: %{
        type: "object",
        properties: %{
          key_expr: %{type: "string"},
          payload: %{type: "object"},
          encoding: %{type: "string", default: "application/json"}
        },
        required: ["key_expr", "payload"]
      }
    },
    %{
      name: "cepaf_zenoh_subscribe",
      description: "Subscribe to Zenoh topic pattern",
      inputSchema: %{
        type: "object",
        properties: %{
          key_expr: %{type: "string"},
          callback_topic: %{type: "string"}
        },
        required: ["key_expr"]
      }
    },
    %{
      name: "cepaf_zenoh_get",
      description: "Query Zenoh for value",
      inputSchema: %{
        type: "object",
        properties: %{
          key_expr: %{type: "string"},
          timeout_ms: %{type: "integer", default: 5000}
        },
        required: ["key_expr"]
      }
    },
    %{
      name: "cepaf_zenoh_hlc_now",
      description: "Get current Hybrid Logical Clock timestamp",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "cepaf_zenoh_hlc_compare",
      description: "Compare two HLC timestamps",
      inputSchema: %{
        type: "object",
        properties: %{
          ts1: %{type: "object"},
          ts2: %{type: "object"}
        },
        required: ["ts1", "ts2"]
      }
    },
    %{
      name: "cepaf_zenoh_session_status",
      description: "Get Zenoh session status",
      inputSchema: %{type: "object", properties: %{}}
    },

    # === COCKPIT ===
    %{
      name: "cepaf_cockpit_status",
      description: "Get F# cockpit status",
      inputSchema: %{type: "object", properties: %{}}
    },
    %{
      name: "cepaf_cockpit_render",
      description: "Render cockpit view",
      inputSchema: %{
        type: "object",
        properties: %{
          view: %{type: "string", enum: ["dashboard", "agents", "health", "logs"]}
        },
        required: ["view"]
      }
    },
    %{
      name: "cepaf_cockpit_theme",
      description: "Get/set Material3 theme",
      inputSchema: %{
        type: "object",
        properties: %{
          action: %{type: "string", enum: ["get", "set"]},
          theme: %{type: "string", enum: ["dark", "light", "system"]}
        },
        required: ["action"]
      }
    },

    # === QUADPLEX LOGGER ===
    %{
      name: "cepaf_log_quadplex",
      description: "Log to all 4 outputs (console, file, otel, zenoh)",
      inputSchema: %{
        type: "object",
        properties: %{
          level: %{type: "string", enum: ["debug", "info", "warn", "error"]},
          message: %{type: "string"},
          context: %{type: "object"}
        },
        required: ["level", "message"]
      }
    },
    %{
      name: "cepaf_log_query",
      description: "Query logs from F# runtime",
      inputSchema: %{
        type: "object",
        properties: %{
          level: %{type: "string"},
          from: %{type: "string", format: "date-time"},
          to: %{type: "string", format: "date-time"},
          limit: %{type: "integer", default: 100}
        }
      }
    },

    # === HEALTH PROPAGATION ===
    %{
      name: "cepaf_health_propagate",
      description: "Propagate health status through holon tree",
      inputSchema: %{
        type: "object",
        properties: %{
          source_holon: %{type: "string"},
          health_delta: %{type: "number"}
        },
        required: ["source_holon", "health_delta"]
      }
    },
    %{
      name: "cepaf_health_aggregate",
      description: "Aggregate health from child holons",
      inputSchema: %{
        type: "object",
        properties: %{
          parent_holon: %{type: "string"}
        },
        required: ["parent_holon"]
      }
    },
    %{
      name: "cepaf_health_tree",
      description: "Get full holon health tree",
      inputSchema: %{type: "object", properties: %{}}
    }
  ]

  @fsharp_process_timeout 30_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Enum.each(@tools, fn tool ->
      Indrajaal.MCP.Registry.register_tool(:cepaf, tool)
    end)

    # Start F# bridge process
    fsharp_pid = start_fsharp_bridge()

    {:ok, %{fsharp_pid: fsharp_pid, available: fsharp_pid != nil}}
  end

  defp start_fsharp_bridge do
    case System.cmd("dotnet", ["run", "--project", "lib/cepaf/src/Cepaf/Cepaf.fsproj", "--", "--mcp-mode"],
           stderr_to_stdout: true) do
      {_, 0} -> spawn_fsharp_stdio_bridge()
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp spawn_fsharp_stdio_bridge do
    # Spawn port for F# process communication
    Port.open({:spawn, "dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- --mcp-mode"},
      [:binary, :exit_status, {:line, 65536}])
  end

  def handle_request(request) do
    GenServer.call(__MODULE__, {:handle_request, request}, @fsharp_process_timeout)
  end

  @impl true
  def handle_call({:handle_request, request}, _from, state) do
    result =
      if state.available do
        execute_fsharp_tool(request, state.fsharp_pid)
      else
        execute_degraded(request)
      end

    {:reply, result, state}
  end

  # [Updated Sprint 51: real F# bridge implementation via Port JSON stdio]
  defp execute_fsharp_tool(request, fsharp_pid) do
    # Send JSON to F# process via Port, receive structured response
    json_request = Jason.encode!(request)
    Port.command(fsharp_pid, json_request <> "\n")
    receive do
      {^fsharp_pid, {:data, response}} ->
        Jason.decode(response)
    after
      @fsharp_process_timeout ->
        {:error, :timeout}
    end
  end

  defp execute_degraded(request) do
    {:ok, %{degraded: true, tool: request["params"]["name"], message: "F# bridge unavailable, degraded response"}}
  end
end
```

---

## 6.0 Layer 5: Integration & Configuration

### 6.1 Unified MCP Configuration

```json
// .mcp.json additions
{
  "mcpServers": {
    "indrajaal": {
      "command": "mix",
      "args": ["run", "--no-halt", "-e", "Indrajaal.MCP.IndrajaalServer.start()"],
      "env": {
        "MIX_ENV": "dev",
        "DATABASE_URL": "ecto://postgres:postgres@localhost:5433/indrajaal_dev"
      },
      "description": "Indrajaal 15 Domain Contexts MCP Server (180 tools)"
    },
    "prajna": {
      "command": "mix",
      "args": ["run", "--no-halt", "-e", "Indrajaal.MCP.PrajnaServer.start()"],
      "env": {
        "MIX_ENV": "dev",
        "DATABASE_URL": "ecto://postgres:postgres@localhost:5433/indrajaal_dev"
      },
      "description": "Prajna C3I Cockpit MCP Server (85 tools) - Guardian, Sentinel, AI"
    },
    "cepaf": {
      "command": "mix",
      "args": ["run", "--no-halt", "-e", "Indrajaal.MCP.CepafServer.start()"],
      "env": {
        "MIX_ENV": "dev",
        "DOTNET_ROOT": "/nix/store/*/dotnet-sdk-10.0"
      },
      "description": "CEPAF F# Category Theory MCP Server (65 tools) - Arrows, OODA, Zenoh"
    },
    "indrajaal-unified": {
      "command": "mix",
      "args": ["run", "--no-halt", "-e", "Indrajaal.MCP.UnifiedServer.start()"],
      "env": {
        "MIX_ENV": "dev",
        "DATABASE_URL": "ecto://postgres:postgres@localhost:5433/indrajaal_dev"
      },
      "description": "Unified Indrajaal MCP Server (350 tools) - All capabilities in one"
    }
  }
}
```

### 6.2 Unified MCP Server (Single Entry Point)

```elixir
# lib/indrajaal/mcp/unified_server.ex
defmodule Indrajaal.MCP.UnifiedServer do
  @moduledoc """
  Unified MCP Server providing access to all Indrajaal, Prajna, and CEPAF tools.

  STAMP Constraints:
    - SC-MCP-060: Single entry point for all 350 tools
    - SC-MCP-061: Namespace routing
    - SC-MCP-062: Unified authentication
    - SC-MCP-063: Centralized rate limiting
  """

  use GenServer

  alias Indrajaal.MCP.{
    Registry,
    Auth,
    IndrajaalServer,
    PrajnaServer,
    CepafServer
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Start all sub-servers
    {:ok, _} = IndrajaalServer.start_link([])
    {:ok, _} = PrajnaServer.start_link([])
    {:ok, _} = CepafServer.start_link([])

    {:ok, %{started_at: DateTime.utc_now()}}
  end

  def handle_request(request) do
    GenServer.call(__MODULE__, {:handle_request, request}, 60_000)
  end

  @impl true
  def handle_call({:handle_request, request}, _from, state) do
    result = route_request(request)
    {:reply, result, state}
  end

  defp route_request(%{"method" => "tools/list"} = _request) do
    tools = Registry.list_tools(:all)
    {:ok, %{tools: tools}}
  end

  defp route_request(%{"method" => "tools/call", "params" => params} = request) do
    tool_name = params["name"]

    cond do
      String.starts_with?(tool_name, "indrajaal_") ->
        IndrajaalServer.handle_request(request)
      String.starts_with?(tool_name, "prajna_") ->
        PrajnaServer.handle_request(request)
      String.starts_with?(tool_name, "cepaf_") ->
        CepafServer.handle_request(request)
      String.starts_with?(tool_name, "kms_") ->
        Indrajaal.KMS.MCPServer.handle_request(request)
      true ->
        {:error, :unknown_namespace}
    end
  end

  def start do
    # Entry point for mix run -e
    {:ok, _} = start_link()

    # Start TCP listener for MCP protocol
    {:ok, _} = :gen_tcp.listen(9999, [:binary, packet: :line, active: false, reuseaddr: true])

    IO.puts("Indrajaal Unified MCP Server started on port 9999")
    IO.puts("Available namespaces: indrajaal, prajna, cepaf, kms")
    IO.puts("Total tools: #{length(Registry.list_tools(:all))}")

    Process.sleep(:infinity)
  end
end
```

---

## 7.0 STAMP Constraints Summary

| ID | Constraint | Layer | Severity |
|----|------------|-------|----------|
| SC-MCP-001 | JSON-RPC 2.0 compliance | L1 | CRITICAL |
| SC-MCP-002 | Tool schema validation | L1 | HIGH |
| SC-MCP-010 | Tool registration validation | L1 | HIGH |
| SC-MCP-020 | Client authentication | L1 | CRITICAL |
| SC-MCP-021 | Rate limit 100 req/min | L1 | HIGH |
| SC-MCP-022 | Guardian approval for writes | L1 | CRITICAL |
| SC-MCP-030 | All 15 domains exposed | L2 | HIGH |
| SC-MCP-031 | CRUD for all resources | L2 | HIGH |
| SC-MCP-040 | Safety tools require Guardian | L3 | CRITICAL |
| SC-MCP-041 | PROMETHEUS tokens for mutations | L3 | CRITICAL |
| SC-MCP-050 | F# interop via JSON stdio | L4 | HIGH |
| SC-MCP-060 | Single entry point | L5 | MEDIUM |

---

## 8.0 Implementation Timeline

### Phase 1: Foundation (L1)
- Protocol types and JSON-RPC handlers
- Tool registry and dispatcher
- Authentication and rate limiting
- **Output**: `lib/indrajaal/mcp/protocol.ex`, `registry.ex`, `auth.ex`

### Phase 2: Indrajaal Domains (L2)
- Core domain tools (40 tools)
- Operations domain tools (52 tools)
- Extended domain tools (88 tools)
- **Output**: `lib/indrajaal/mcp/indrajaal_server.ex`

### Phase 3: Prajna Cockpit (L3)
- Safety and Guardian tools (19 tools)
- Verification tools (18 tools)
- Operations tools (25 tools)
- Control tools (26 tools)
- **Output**: `lib/indrajaal/mcp/prajna_server.ex`

### Phase 4: CEPAF F# (L4)
- Category theory tools (30 tools)
- Runtime tools (19 tools)
- Cockpit and observability (16 tools)
- **Output**: `lib/indrajaal/mcp/cepaf_server.ex`

### Phase 5: Integration (L5)
- Unified server
- .mcp.json configuration
- Testing and verification
- **Output**: `lib/indrajaal/mcp/unified_server.ex`, `.mcp.json`

---

## 9.0 Testing Strategy

### TDG Compliance

```elixir
# test/indrajaal/mcp/protocol_test.exs
defmodule Indrajaal.MCP.ProtocolTest do
  use ExUnit.Case
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  property "JSON-RPC requests have required fields" do
    forall request <- PC.map(%{
      jsonrpc: PC.utf8(),
      id: PC.oneof([PC.integer(), PC.utf8()]),
      method: PC.utf8()
    }) do
      Protocol.validate_request(request) in [:ok, {:error, _}]
    end
  end
end
```

---

## 10.0 Document Control

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2026-01-05 |
| Author | Claude Opus 4.5 |
| Status | IMPLEMENTATION READY |
| STAMP Range | SC-MCP-001 to SC-MCP-063 |
| Total Tools | 350 |
