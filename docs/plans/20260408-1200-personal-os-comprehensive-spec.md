# Specification: Indrajaal Personal OS (Fractal Brain-Stem Architecture)

**Version**: 1.0.0-BETA
**Classification**: OPERATIONAL SPECIFICATION
**Topology**: L0-L7 Fractal Mesh
**Primary Transport**: Zenoh MoZ (MCP-over-Zenoh)

## 1.0 Architectural Approach: The Brain-Stem Model

The Indrajaal Personal OS is designed as a distributed cybernetic organism. It separates high-level cognitive reasoning (Gleam) from low-level system execution (Rust) using a high-speed asynchronous nervous system (Zenoh).

### 1.1 Sensory Thalamus (L7 - Gateway)
- **Role**: Input Ingestion & Edge Filtering.
- **Components**: Bi-directional bridges for Telegram, WhatsApp, and System Cron.
- **Logic**: Converts raw external stimuli into standardized 'Intent Requests.'

### 1.2 Prefrontal Cortex (L5 - Cognitive)
- **Role**: Goal Decomposition & Orchestration.
- **Pattern**: ReAct (Reason-Act-Observe) Loop.
- **Logic**: Receives an Intent, queries Smriti for context, plans a sequence of MCP tool calls, and executes them via the Motor Strip.

### 1.3 Motor Strip (L4 - System)
- **Role**: Authoritative Physical Execution.
- **Components**: Rust 'ignition_daemon' and 'sa-plan-daemon'.
- **Logic**: Manages Podman UDS sandboxes, Git operations, and Database mutations. Every action is a standardized MCP tool.

### 1.4 Hippocampus (L4 - Knowledge/Smriti)
- **Role**: Persistent Memory & Spatial Awareness.
- **Technology**: SQLite (Relational) + DuckDB/pgvector (Semantic).
- **Logic**: Every agent turn is logged as an episodic memory. Semantic RAG allows the Cortex to 'remember' past user preferences.

---

## 2.0 System Specifications

### 2.1 Communication Protocol: MoZ (MCP-over-Zenoh)
Standardizing on JSON-RPC 2.0 for all tool interaction.
- **Topic Pattern**: 'indrajaal/{layer}/{domain}/mcp/{req|res}/{id}'
- **Standard Methods**:
    - 'initialize': Expose tool definitions and capabilities.
    - 'call_tool': Execute a specific action (e.g., 'git_push', 'email_summarize').
    - 'subscribe': Real-time telemetry feed of task progress.

### 2.2 Memory Schema (Smriti Graph)
- **Nodes**: '(Task | Entity | Decision | CodeContext)'
- **Edges**: '(depends_on | relates_to | reason_for | created_by)'
- **Vector Index**: 1536-dim embeddings for all text-heavy interactions.

### 2.3 Safety Constraints (SIL-6 Compliance)
- **SC-CU-001**: No arbitrary code execution on host. All scripts run in Podman.
- **SC-GATE-001**: P0 mutations require explicit human approval via the Gateway.
- **SC-LOG-001**: All autonomous actions MUST be recorded in the episodic hash-chained log.

---

## 3.0 Full Feature Coverage (The 200 Mapping)

| Category | Mapping to Indrajaal Component |
| :--- | :--- |
| **Gateway** | L7 Gleam Gateway Actors (Telegram/Signal/WhatsApp) |
| **Cognitive** | L5 OODA Supervisor + ReAct Engine |
| **Memory** | L4 Smriti + DuckDB Vector Extensions |
| **Computer Use** | L4 Rust 'ignition_daemon' (Podman UDS) |
| **Proactive** | L5 Heartbeat Cron Service |
| **Development** | L5 Git-Gate Manager + L4 Rust 'sa-plan-daemon' |
| **Security** | L0 Guardian Kernel + TLA+ Verification Gates |

---

## 4.0 Fractal Implementation Plan (Wave 1-5)

### Wave 1: Sensory & Motor Initiation (P0)
*Focus: Mobile control and host-protected execution.*
- **Task 1.1**: Bi-directional Telegram Intent Router.
- **Task 1.2**: Rust 'mcp_sandbox' (Podman UDS implementation).
- **Task 1.3**: Rust 'mcp_git' (Automated branch/push logic).

### Wave 2: Cognitive Reasoning (P0)
*Focus: Autonomous planning and error recovery.*
- **Task 2.1**: Gleam ReAct Loop implementation.
- **Task 2.2**: Multi-step task decomposition engine.

### Wave 3: Episodic Awareness (P1)
*Focus: Long-term memory and RAG.*
- **Task 3.1**: Smriti EventLog & Vector Sync.
- **Task 3.2**: Context-aware prompt injection.

### Wave 4: Operational Automation (Usability)
*Focus: Daily executive workflows.*
- **Task 4.1**: GWorkspace MCP (Email/Calendar triage).
- **Task 4.2**: Morning Briefing automation.

### Wave 5: Advanced Perception & Visual Reasoning (Usability)
*Focus: Agentic browser interaction.*
- **Task 5.1**: Playwright Visual Crawler MCP.
- **Task 5.2**: Bounding Box UI reasoning.

---

## 5.0 Success Criteria
- Agent independently manages Abhi's technical and business operations with < 1% error rate.
- 100% of actions are traceable to a Smriti ID.
- Zero manual desync of guidance artifacts.
