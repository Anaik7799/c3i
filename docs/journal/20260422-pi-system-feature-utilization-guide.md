https://vm-1.tail55d152.ts.net:8443/task-id/116446490148048164/20260422-pi-system-feature-utilization-guide.md

# Pi System Feature Utilization Guide
## Complete Instructions for Pi-Mono to Use ALL C3I Features

**Date**: 2026-04-22
**Version**: v22.10.1-PI-SYMBIOSIS
**ZK Recall**: [zk-f7d3ae0471edbda5] Pi↔C3I tool federation bridge, [zk-b2bd1b4e91a0556b] Pi integration guide
**Total Bridge Code**: 3,716 LOC across 7 Gleam modules

---

## 1. Architecture Overview

Pi-mono (TypeScript, 106K LOC, 7 packages) communicates with C3I (Gleam/Rust, 214K LOC) through a Zenoh mesh backplane. The bridge layer consists of 7 Gleam modules that define types, events, tools, sessions, providers, and Zenoh topics.

```
Pi-Mono (Node.js)                    C3I (BEAM + Rust)
┌─────────────────┐                  ┌─────────────────────────────────────┐
│ pi-ai            │  Zenoh PubSub   │ Gleam Bridge Layer (3,716 LOC)      │
│ pi-coding-agent  │ ◄══════════════►│ ├── pi_agent.gleam    (925 LOC)     │
│ pi-tui           │  Topics:        │ ├── pi_tools.gleam    (723 LOC)     │
│ pi-web-ui        │  indrajaal/pi/* │ ├── pi_zenoh.gleam    (537 LOC)     │
│ pi-mom           │                 │ ├── pi_session.gleam  (533 LOC)     │
│ pi-pods          │                 │ ├── pi_claude_code.gleam (476 LOC)  │
│                  │                 │ ├── pi_provider.gleam (306 LOC)     │
│                  │                 │ └── pi_subscriber.gleam (216 LOC)   │
│                  │                 │                                     │
│                  │  HTTP API       │ Rust sa-plan-daemon (24K LOC)       │
│                  │ ◄──────────────►│ ├── 62 HTTP routes (port 8443)      │
│                  │                 │ ├── RAG pipeline (rag.rs)           │
│                  │                 │ ├── 6-tier inference cascade        │
│                  │                 │ └── Semantic cache (24h TTL)        │
└─────────────────┘                  └─────────────────────────────────────┘
```

---

## 2. Zenoh Topics — The Communication Contract

Pi communicates with C3I exclusively via Zenoh topics. These are the topics Pi should publish to and subscribe to:

### 2.1 Topics Pi PUBLISHES To

| Topic | Purpose | Payload |
|-------|---------|---------|
| `indrajaal/pi/events` | Pi lifecycle events (session start/end, tool calls) | PiEvent JSON |
| `indrajaal/pi/tools` | Tool call requests from Pi agent | ToolCall JSON |
| `indrajaal/pi/sessions` | Session state changes | PiSessionState JSON |
| `indrajaal/pi/health` | Pi agent health status | PiAgentState JSON |
| `indrajaal/pi/inference` | Inference tier usage | Tier + latency JSON |
| `indrajaal/pi/session/sync/{session_id}` | Session persistence to Smriti.db | Session JSON |

### 2.2 Topics Pi SUBSCRIBES To

| Topic | Purpose | Response |
|-------|---------|----------|
| `indrajaal/c3i/commands/**` | Commands from C3I to Pi (restart, config, etc.) | Command JSON |
| `indrajaal/l0/const/emergency` | Emergency stop signals | Action JSON |
| `indrajaal/l5/cog/escalate` | Escalation requests from RETE-UL | Level + reason JSON |
| `indrajaal/l4/system/restart` | Container restart commands | Container + reason JSON |

### 2.3 TypeScript Implementation

```typescript
// In pi-coding-agent/src/zenoh/bridge.ts
import { Session } from 'zenoh-ts';  // or use HTTP proxy

const TOPICS = {
  // Publish
  events:    'indrajaal/pi/events',
  tools:     'indrajaal/pi/tools',
  sessions:  'indrajaal/pi/sessions',
  health:    'indrajaal/pi/health',
  inference: 'indrajaal/pi/inference',
  
  // Subscribe
  commands:  'indrajaal/c3i/commands/**',
  emergency: 'indrajaal/l0/const/emergency',
  escalate:  'indrajaal/l5/cog/escalate',
} as const;

// If Zenoh client not available, use HTTP proxy:
async function publishViaHttp(topic: string, payload: object): Promise<void> {
  await fetch('https://vm-1.tail55d152.ts.net:8443/api/v1/zenoh/publish', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ key: topic, value: JSON.stringify(payload) }),
  });
}
```

---

## 3. Feature-by-Feature Integration Guide

### 3.1 Tool Federation (pi_tools.gleam — 723 LOC)

The system defines **93 federated tools**: 6 Claude + 14 Pi + 73 C3I MCP.

**What Pi should do:**

```typescript
// 1. Register Pi's 14 tools on startup
const PI_TOOLS = [
  { name: 'read', source: 'pi', layer: 'L1', guardian: 'none' },
  { name: 'write', source: 'pi', layer: 'L1', guardian: 'warn' },
  { name: 'edit', source: 'pi', layer: 'L1', guardian: 'warn' },
  { name: 'bash', source: 'pi', layer: 'L4', guardian: 'approve' },
  { name: 'search', source: 'pi', layer: 'L1', guardian: 'none' },
  { name: 'glob', source: 'pi', layer: 'L1', guardian: 'none' },
  { name: 'agent', source: 'pi', layer: 'L5', guardian: 'warn' },
  { name: 'web_search', source: 'pi', layer: 'L6', guardian: 'none' },
  { name: 'web_fetch', source: 'pi', layer: 'L6', guardian: 'none' },
  { name: 'notebook', source: 'pi', layer: 'L3', guardian: 'none' },
  { name: 'lsp', source: 'pi', layer: 'L2', guardian: 'none' },
  { name: 'diff', source: 'pi', layer: 'L1', guardian: 'none' },
  { name: 'patch', source: 'pi', layer: 'L1', guardian: 'warn' },
  { name: 'mcp_invoke', source: 'pi', layer: 'L5', guardian: 'approve' },
];

// 2. Check guardian policy before executing L0/L4 tools
// Gleam side: pi_tools.check_gate(tool, pi_tools.production_guardian_policy())
// Pi side:
function checkGuardian(toolName: string, layer: string): boolean {
  if (layer === 'L0') return false;  // Always blocked — requires human
  if (layer === 'L4') return true;   // Allowed with logging
  return true;
}

// 3. Call C3I MCP tools via HTTP
async function callC3iTool(toolName: string, args: object): Promise<any> {
  const response = await fetch('https://vm-1.tail55d152.ts.net:8443/api/v1/mcp/invoke', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ tool: toolName, arguments: args }),
  });
  return response.json();
}

// Available C3I tools Pi can call:
// Planning: plan_status, plan_list, plan_add, plan_update, plan_search, plan_get, plan_list_pending
// System: system_health, system_dashboard, system_immune, system_zenoh, system_verification
// Knowledge: knowledge_search, verification_run
// Graph: graph/scc, graph/pagerank, graph/bfs, graph/toposort
// Rules: rules/evaluate
// LLM: llm/complete
```

### 3.2 Event Bridge (pi_agent.gleam — 925 LOC, pi_claude_code.gleam — 476 LOC)

29 Pi events map bidirectionally to 32 AG-UI events.

**What Pi should do:**

```typescript
// 1. Emit events through Zenoh
interface PiEvent {
  kind: string;       // 'tool_call' | 'session_start' | 'session_end' | 'text_message' | ...
  session_id: string;
  timestamp: number;  // Unix epoch ms
  payload: string;    // JSON
}

async function emitPiEvent(event: PiEvent): Promise<void> {
  await publishViaHttp('indrajaal/pi/events', event);
}

// 2. Map Pi events to AG-UI events (the Gleam bridge does this on the C3I side)
// Pi event 'tool_call'     → AG-UI 'ToolCallStart' + 'ToolCallEnd'
// Pi event 'text_message'  → AG-UI 'TextMessageContent'
// Pi event 'session_start' → AG-UI 'RunStarted'
// Pi event 'session_end'   → AG-UI 'RunFinished'
// Pi event 'thinking'      → AG-UI 'ReasoningMessageContent'
// Pi event 'error'         → AG-UI 'RunError'

// 3. Claude Code tool mapping
// Gleam: pi_claude_code.claude_to_pi_tool("Read") → "read"
// Gleam: pi_claude_code.pi_to_claude_tool("bash") → "Bash"
const CLAUDE_TO_PI: Record<string, string> = {
  'Read': 'read', 'Write': 'write', 'Edit': 'edit',
  'Bash': 'bash', 'Grep': 'search', 'Glob': 'glob',
};
```

### 3.3 Session Management (pi_session.gleam — 533 LOC)

Sessions are now persisted to Smriti.db via Zenoh (fixed from NIF stub).

**What Pi should do:**

```typescript
// 1. On session start — publish session state
interface PiSessionState {
  session_id: string;
  message_count: number;
  branch_depth: number;
  model: string;
  provider: string;
  thinking_level: string;
  status: 'active' | 'completed' | 'abandoned' | 'compacted' | 'forked' | 'exported';
  created_at: number;  // Unix epoch
}

async function syncSession(session: PiSessionState): Promise<void> {
  // This publishes to Zenoh, which the Gleam pi_subscriber actor receives
  // and persists to Smriti.db
  await publishViaHttp(
    `indrajaal/pi/session/sync/${session.session_id}`,
    session
  );
}

// 2. Track session lifecycle
async function onSessionStart(sessionId: string, model: string): Promise<void> {
  await publishViaHttp('indrajaal/pi/sessions', {
    kind: 'session_start',
    session_id: sessionId,
    model,
    timestamp: Date.now(),
  });
}

async function onSessionEnd(sessionId: string): Promise<void> {
  await publishViaHttp('indrajaal/pi/sessions', {
    kind: 'session_end',
    session_id: sessionId,
    timestamp: Date.now(),
  });
}
```

### 3.4 Recall/RAG Pipeline

Pi agents should use the RAG system for institutional memory.

**What Pi should do:**

```typescript
// 1. Search Zettelkasten before starting any task
async function zkSearch(query: string): Promise<any> {
  return callC3iTool('knowledge_search', { query, limit: 5 });
  // Alternative: direct HTTP
  // GET https://vm-1.tail55d152.ts.net:8443/api/v1/knowledge?q=query
}

// 2. Search on EVERY prompt (implement as extension hook)
// In pi-coding-agent/src/extensions/zk-recall.ts
export const zkRecallExtension = {
  name: 'zk-recall',
  hooks: {
    beforePromptProcess: async (prompt: string) => {
      const results = await zkSearch(prompt);
      // Inject results as system context
      return { additionalContext: formatAsRAGContext(results) };
    },
    afterSessionEnd: async () => {
      // Trigger ZK ingest for new knowledge
      await fetch('https://vm-1.tail55d152.ts.net:8443/api/v1/mcp/invoke', {
        method: 'POST',
        body: JSON.stringify({ tool: 'knowledge_ingest', arguments: {} }),
      });
    },
  },
};

// 3. Use semantic cache — identical queries within 24h get cached responses
// No special Pi action needed — sa-plan-daemon handles caching automatically
```

### 3.5 Inference Cascade (pi_provider.gleam — 306 LOC)

The system defines a 6-tier hedged inference cascade with circuit breakers.

**What Pi should do:**

```typescript
// 1. Report inference tier usage to C3I for observability
async function reportInferenceTier(
  tier: string,   // 'gemini_direct' | 'openrouter' | 'ollama_gemma4' | 'ollama_gemma3' | 'rete_ul' | 'static'
  latencyMs: number,
  success: boolean,
): Promise<void> {
  await publishViaHttp('indrajaal/pi/inference', {
    tier,
    latency_ms: latencyMs,
    success,
    timestamp: Date.now(),
  });
}

// 2. Use C3I's LLM endpoint for hedged inference
// POST /api/v1/llm/complete
// This uses the full 6-tier cascade with circuit breakers
async function hedgedInference(prompt: string): Promise<string> {
  const response = await fetch('https://vm-1.tail55d152.ts.net:8443/api/v1/llm/complete', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ prompt, max_tokens: 4096 }),
  });
  const data = await response.json();
  return data.response;
}

// 3. Circuit breaker state
// Gleam: pi_provider.check_circuit_breaker(state, now_ms) → BreakerClosed | BreakerOpen
// Pi should implement per-provider circuit breakers:
// 3 failures → 60s cooldown, then half-open probe
```

### 3.6 OTel Observability (zenoh_otel.gleam — 546 LOC)

All Pi operations should emit OpenTelemetry spans via Zenoh.

**What Pi should do:**

```typescript
// 1. Emit OTel spans for Pi operations
async function emitOtelSpan(operation: string, page: string): Promise<void> {
  // Gleam: pi_zenoh.emit_pi_span(operation, page)
  // Pi: publish to OTel topic
  await publishViaHttp(`indrajaal/otel/ops/${page}/${operation}`, {
    trace_id: generateTraceId(),
    span_id: generateSpanId(),
    name: `${page}/${operation}`,
    ooda_phase: 'Act',
    timestamp: Date.now(),
    attributes: {},
  });
}

// 2. Emit spans for key Pi operations:
// - Tool calls: emitOtelSpan('tool_call', 'bridge')
// - Session transitions: emitOtelSpan('session_start', 'bridge')
// - LLM inference: emitOtelSpan('inference', 'bridge')
// - Error events: emitOtelSpan('error', 'bridge')
```

### 3.7 RETE-UL Rule Evaluation (rules/dispatcher.gleam — 101 LOC)

Pi can request rule evaluations for decision-making.

**What Pi should do:**

```typescript
// 1. Evaluate rules via HTTP
async function evaluateRules(domain: string, facts: Record<string, string>): Promise<{
  decision: string;
  reason: string;
}> {
  const response = await fetch('https://vm-1.tail55d152.ts.net:8443/api/v1/rules/evaluate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ domain, facts }),
  });
  return response.json();
}

// 2. Available domains (52 rules across 13 domains):
// 'ooda_decide'      — Emergency/Boot/Restart/Health/LLM/NoAction
// 'preflight'        — Block/Warn/Pass graduated checks
// 'recovery'         — RPN-prioritized recovery playbook
// 'health_consensus' — Per-criticality 2/3/4 of 5 threshold
// 'cascade'          — Apoptosis/Isolate/Monitor by depth
// 'partition'        — FenceMinority/PreserveData/NoAction
// 'launch_tier'      — Halt/Continue/Proceed per criticality
// 'governor'         — FullSpeed/HeavyThrottle/Wait
// 'verify'           — Compliant/Degraded/NonCompliant
// 'build'            — Rebuild P0@72h / Standard@168h / Skip
// 'apoptosis'        — Immediate/Fast2s/Graceful10s/Default5s
// 'rca'              — L1 NIF/L4 Container/L6 Quorum/L7 LLM
// 'hysteresis'       — Aggressive/Conservative/Default

// 3. Example: Should Pi restart a container?
const result = await evaluateRules('recovery', {
  failure_type: 'NifLoadFailed',
  rpn: '180',
  cascade_depth: '1',
});
// result.decision: "RestartContainer"
// result.reason: "NIF failure with RPN 180 — restart recommended"
```

### 3.8 Self-Awareness Metrics (claude_metrics.gleam)

Pi should track its own cognitive performance.

**What Pi should do:**

```typescript
// Track these metrics per session:
interface SessionMetrics {
  zk_recalls: number;        // How many ZK searches performed
  zk_citations: number;      // How many holon IDs cited in responses
  zk_anti_patterns: number;  // Anti-patterns detected and avoided
  tool_reads: number;        // File read tool calls
  tool_edits: number;        // File edit tool calls
  tool_bash: number;         // Shell command calls
  tool_agents: number;       // Sub-agent spawns
  tool_agent_success: number;
  tool_agent_failed: number;
  build_success: number;     // Successful builds
  build_failed: number;      // Failed builds
  mcp_calls: number;         // MCP tool invocations
}

// Publish metrics to C3I for dashboard display:
async function publishMetrics(metrics: SessionMetrics): Promise<void> {
  await publishViaHttp('indrajaal/pi/health', {
    kind: 'session_metrics',
    ...metrics,
    timestamp: Date.now(),
  });
}
```

### 3.9 Pi Subscriber Actor — What It Does For Pi

The `pi_subscriber.gleam` (216 LOC) is the C3I-side actor that:
1. Receives Pi events from Zenoh topics
2. Routes them through the bridge modules
3. Emits OTel spans for observability
4. Validates tool federation counts
5. Tracks session lifecycle

**Pi doesn't need to do anything for this** — it runs on the C3I side. But Pi should ensure it publishes to the correct topics (see Section 2.1).

---

## 4. HTTP API Quick Reference

All features are accessible via HTTP if Zenoh is not available:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/status` | GET | Task counts (active/pending/completed) |
| `/api/v1/tasks` | GET/POST | List or create tasks |
| `/api/v1/tasks/{id}` | PUT | Update task status |
| `/api/v1/health` | GET | System health |
| `/api/v1/dashboard` | GET | Full dashboard JSON |
| `/api/v1/search?q=` | GET | Search tasks |
| `/api/v1/knowledge?q=` | GET | Search Zettelkasten |
| `/api/v1/rules/evaluate` | POST | RETE-UL rule evaluation |
| `/api/v1/llm/complete` | POST | 6-tier hedged inference |
| `/api/v1/zenoh/publish` | POST | Publish to Zenoh topic |
| `/api/v1/mcp/invoke` | POST | Invoke MCP tool |
| `/api/v1/graph/scc` | POST | Strongly connected components |
| `/api/v1/graph/pagerank` | POST | PageRank computation |
| `/api/v1/graph/toposort` | POST | Topological sort |
| `/api/v1/system/info` | GET | System info (OS, CPU, memory) |
| `/recall-rag` | GET | Recall/RAG dashboard HTML |
| `/recall-rag-deck` | GET | Recall/RAG slide deck |
| `/health` | GET | Health check (status: ok) |

**Base URL**: `https://vm-1.tail55d152.ts.net:8443`

---

## 5. Implementation Checklist for Pi-Mono

### Phase 1: Zenoh/HTTP Bridge (~100 LOC)
- [ ] Create `packages/pi-coding-agent/src/c3i/bridge.ts`
- [ ] Implement `publishViaHttp(topic, payload)` function
- [ ] Implement `callC3iTool(toolName, args)` function
- [ ] Test connectivity to `https://vm-1.tail55d152.ts.net:8443/health`

### Phase 2: ZK Recall Hooks (~80 LOC)
- [ ] Create `packages/pi-coding-agent/src/extensions/zk-recall.ts`
- [ ] `beforePromptProcess`: search ZK, inject context
- [ ] `afterSessionEnd`: trigger ZK ingest
- [ ] Test: verify ZK results appear in system context

### Phase 3: Session Persistence (~100 LOC)
- [ ] Create `packages/pi-coding-agent/src/c3i/session-sync.ts`
- [ ] `onSessionStart`: publish to `indrajaal/pi/sessions`
- [ ] `onSessionEnd`: publish + sync to `indrajaal/pi/session/sync/{id}`
- [ ] Test: verify session appears in Smriti.db

### Phase 4: Tool Federation (~120 LOC)
- [ ] Create `packages/pi-coding-agent/src/c3i/tools.ts`
- [ ] Register 14 Pi tools with guardian policies
- [ ] Implement `callC3iTool()` for 73 C3I MCP tools
- [ ] Guardian gate check before L0/L4 tool execution
- [ ] Test: invoke `plan_status` tool, verify response

### Phase 5: OTel Spans (~60 LOC)
- [ ] Create `packages/pi-coding-agent/src/c3i/otel.ts`
- [ ] `emitOtelSpan(operation, page)` for tool calls, sessions, inference
- [ ] Test: verify spans appear in Zenoh observer

### Phase 6: Inference Reporting (~50 LOC)
- [ ] Create `packages/pi-coding-agent/src/c3i/inference.ts`
- [ ] Report tier usage to `indrajaal/pi/inference`
- [ ] Circuit breaker per provider (3 failures → 60s cooldown)

### Phase 7: Self-Awareness Metrics (~60 LOC)
- [ ] Create `packages/pi-coding-agent/src/c3i/metrics.ts`
- [ ] Track zk_recalls, zk_citations, tool_*, build_*, mcp_calls
- [ ] Publish to `indrajaal/pi/health` at session end

**Total estimated**: ~570 LOC TypeScript

---

## 6. STAMP Constraints Pi Must Comply With

| ID | Constraint | Pi Action |
|----|------------|-----------|
| SC-PI-001 | Events to Zenoh | Publish to `indrajaal/pi/*` topics |
| SC-PI-002 | Tools gated by Guardian | Check layer before L0/L4 execution |
| SC-PI-003 | Sessions in Smriti.db | Sync via `indrajaal/pi/session/sync/{id}` |
| SC-PI-004 | Circuit breaker infra | 3 failures → 60s cooldown per provider |
| SC-PI-005 | No raw JSONL in production | Use Smriti.db (via Zenoh sync) |
| SC-PI-006 | Web-UI in Lustre SSR | Pi web components served as A2UI JSON |
| SC-PI-008 | Model registry sync | Report model usage to C3I |
| SC-PI-010 | PII compliance | Scrub before ZK ingest |
| SC-ZK-IMP-001 | Cite ZK holons | Include holon IDs in tool outputs |
| SC-GLM-ZEN-001 | OTel spans | Emit for all state changes |

---

## 7. Dashboards Pi Can Access

| Dashboard | URL | Content |
|-----------|-----|---------|
| Main | https://vm-1.tail55d152.ts.net:8443/ | System overview |
| KPI | https://vm-1.tail55d152.ts.net:8443/kpi | Progress metrics |
| Recall/RAG | https://vm-1.tail55d152.ts.net:8443/recall-rag | Memory architecture |
| Pi Symbiosis | https://vm-1.tail55d152.ts.net:8443/pi-symbiosis | Bridge status |
| Agentic Console | https://vm-1.tail55d152.ts.net:8443/agentic | Jobs/workflows |
| Task Pages | https://vm-1.tail55d152.ts.net:8443/task-id/{id} | Per-task analysis |

---

## 8. Testing Verification

After implementing Pi integration:

```bash
# 1. Verify bridge compiles
cd lib/cepaf_gleam && gleam build     # 0 errors

# 2. Verify bridge tests pass
cd lib/cepaf_gleam && gleam test      # 8,979+ passed

# 3. Verify HTTP API accessible
curl -sk https://vm-1.tail55d152.ts.net:8443/health
# {"status":"ok","service":"sa-plan-daemon","version":"22.5.0"}

# 4. Verify ZK search works
curl -sk 'https://vm-1.tail55d152.ts.net:8443/api/v1/knowledge?q=pi+integration'

# 5. Verify Zenoh publish works
curl -sk -X POST https://vm-1.tail55d152.ts.net:8443/api/v1/zenoh/publish \
  -H 'Content-Type: application/json' \
  -d '{"key":"indrajaal/pi/health","value":"{\"status\":\"ok\"}"}'

# 6. Verify rule evaluation works
curl -sk -X POST https://vm-1.tail55d152.ts.net:8443/api/v1/rules/evaluate \
  -H 'Content-Type: application/json' \
  -d '{"domain":"health_consensus","facts":{"healthy_count":"3","total_count":"5","criticality":"high"}}'
```
