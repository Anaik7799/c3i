# MCP Server 5-Level Implementation Plan

**Date**: 2026-01-01T14:30:00+01:00
**Session**: Claude Code Implementation Planning
**Status**: PLANNING COMPLETE
**Reference**: docs/plans/20260101-mcp-server-5level-plan.md

---

## Context

Following Microsoft's announcement of Claude-ready secure MCP integration with Azure API Management, this journal documents the comprehensive 5-level plan for implementing an MCP server within the Indrajaal ecosystem.

**Source**: https://developer.microsoft.com/blog/claude-ready-secure-mcp-apim

## Architecture Decision

```
┌─────────────────────────────────────────────────────────────────┐
│                    MCP SERVER ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────┤
│  L5: Operations    │ Monitoring, Scaling, Incident Response     │
│  L4: Security      │ OAuth, Tokens, Audit, Compliance           │
│  L3: Integrations  │ Microsoft 365, Graph API, SharePoint       │
│  L2: Protocol      │ MCP Core, Tools, Resources, Prompts        │
│  L1: Foundation    │ Infrastructure, Runtime, Configuration     │
└─────────────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### 1. Dual Runtime (Elixir + F#)
- **Elixir**: Core MCP server, session management, Guardian integration
- **F#**: CEPAF bridge, Prajna cockpit integration, type-safe protocol handling

### 2. Security Model
- Azure API Management as OAuth 2.0 gateway
- Microsoft Entra ID for identity
- Guardian approval for dangerous operations
- Immutable Register for audit trail

### 3. Microsoft Services Integration
- Graph API for M365 services
- 15+ tools across Email, Calendar, Files, Teams, Planner
- Composite orchestrations for complex workflows

## Level Summary

### Level 1: Foundation (35 tasks)
- Elixir MCP Server GenServer
- F# MCP implementation
- Transport layer (stdio, HTTP/SSE, WebSocket)
- Configuration management
- Container deployment

### Level 2: Protocol (42 tasks)
- JSON-RPC 2.0 implementation
- MCP lifecycle methods
- Tool framework with DSL
- Resource subsystem
- Prompt subsystem

### Level 3: Microsoft Integration (48 tasks)
- Graph API client
- Email tools (search, send, reply, move, delete)
- Calendar tools (events, scheduling, availability)
- Files tools (OneDrive, SharePoint)
- Teams tools (channels, messages, chats)
- Planner/To-Do tools
- Azure management tools
- Composite orchestrations

### Level 4: Security (38 tasks)
- OAuth 2.0 flows (authorization code, client credentials, OBO)
- Token management
- MCP session security
- Permission model
- Guardian integration
- Audit logging
- Data protection & DLP
- Rate limiting

### Level 5: Operations (32 tasks)
- Telemetry (OTEL, Prometheus)
- Logging (Loki)
- Horizontal scaling
- High availability
- Alerting
- Runbooks
- Test suites (unit, integration, property, load)

## STAMP Constraints Added

| ID | Constraint | Severity |
|----|------------|----------|
| SC-MCP-001 | All tool executions require valid session token | CRITICAL |
| SC-MCP-002 | Microsoft API calls must respect rate limits | HIGH |
| SC-MCP-003 | Audit log every tool invocation | HIGH |
| SC-MCP-004 | PII must be detected and masked in logs | HIGH |
| SC-MCP-005 | Guardian approval for destructive operations | CRITICAL |
| SC-MCP-006 | Token refresh must be atomic | HIGH |
| SC-MCP-007 | Session timeout max 1 hour | MEDIUM |
| SC-MCP-008 | Transport must use TLS 1.3 | CRITICAL |
| SC-MCP-009 | Batch requests max 20 operations | MEDIUM |
| SC-MCP-010 | Response timeout max 30 seconds | MEDIUM |

## Files to Create (Total: 52)

### Core MCP (19 files)
```
lib/indrajaal/mcp/
├── server.ex
├── transport.ex
├── session.ex
├── supervisor.ex
├── config.ex
├── jsonrpc.ex
├── codec.ex
├── dispatcher.ex
├── tool.ex
├── tool_registry.ex
├── tool_executor.ex
├── tool_dsl.ex
├── resource.ex
├── resource_registry.ex
├── prompt.ex
├── prompt_registry.ex
├── telemetry.ex
├── metrics.ex
└── logging.ex
```

### Microsoft Integration (13 files)
```
lib/indrajaal/mcp/microsoft/
├── graph_client.ex
├── graph_auth.ex
├── graph_batch.ex
└── tools/
    ├── email.ex
    ├── calendar.ex
    ├── files.ex
    ├── sharepoint.ex
    ├── teams.ex
    ├── planner.ex
    ├── todo.ex
    ├── azure.ex
    ├── azure_monitor.ex
    └── composite.ex
```

### Security (10 files)
```
lib/indrajaal/mcp/auth/
├── oauth.ex
├── token_cache.ex
├── entra_id.ex
├── session_token.ex
├── request_validator.ex
├── permissions.ex
└── policy.ex

lib/indrajaal/mcp/audit/
├── logger.ex
├── retention.ex
└── query.ex
```

### F# CEPAF (4 files)
```
lib/cepaf/src/Cepaf/Mcp/
├── Server.fs
├── Protocol.fs
├── Transport.fs
└── Bridge.fs
```

## Alignment

- **Founder's Directive**: MCP enables AI-powered resource acquisition
- **Guardian**: All tool executions subject to Guardian approval
- **Immutable Register**: Complete audit trail of all operations
- **Sentinel**: Health monitoring for MCP server
- **Prajna**: F# bridge enables cockpit integration

## Next Steps

1. Founder approval for plan
2. Phase 1 implementation (L1 Foundation)
3. TDG test creation before implementation
4. Guardian integration design review

---

**Journal Entry Complete**
**KPI**: 195 tasks across 5 levels, 52 new files, 10 STAMP constraints
