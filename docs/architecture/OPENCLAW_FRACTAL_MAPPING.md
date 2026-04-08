# Architectural Specification: OpenClaw Fractal Integration

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: SYSTEM ARCHITECTURE
**Compliance**: SC-MCP-001, SC-COG-001, SC-ZMOF-001

## 1. Introduction
This specification defines the deep integration of the OpenClaw toolset, skills, and plugin architecture (as defined at `docs.openclaw.ai/tools`) into the Indrajaal Personal OS. The integration maps OpenClaw capabilities across the 8 fractal layers (L0-L7) of the SIL-6 Biomorphic Mesh.

## 2. Capability Matrix & Fractal Mapping

The OpenClaw ecosystem is divided into Tools (Motor Actions), Skills (Cognitive Guidance), and Plugins (Substrate Extensions).

### 2.1 Tools (Motor Actions) Mapping
Tools are atomic functions exposed via Zenoh MCP (MoZ Protocol).

| OpenClaw Tool | Category | Indrajaal Mapping | Fractal Layer | SIL-6 Safety Constraint |
| :--- | :--- | :--- | :--- | :--- |
| `exec`, `process` | Runtime | `mcp_sys::handle_exec` | L4 (Motor/Rust) | SC-OPENCLAW-001 (Podman Sandbox) |
| `code_execution` | Runtime | `mcp_sys::handle_python` | L0 (Substrate) | SC-OPENCLAW-001 (Ephemeral Cell) |
| `browser` | Web | `mcp_browser::handle_browser` | L4 (Motor/Rust) | SC-OPENCLAW-004 (Network Isolation) |
| `web_fetch`, `web_search` | Web | `mcp_web::handle_fetch` | L4 (Motor/Rust) | SC-OPENCLAW-004 (Domain Allowlist) |
| `read`, `write`, `edit`, `apply_patch` | File IO | `mcp_file::handle_fs` | L4 (Motor/Rust) | SC-OPENCLAW-002 (Chroot Jail to `$WORKSPACE_ROOT`) |
| `message`, `gateway` | Comm | `mcp_gateway::handle_msg` | L7 (Federation) | SC-COM-001 (Token Authority in Rust) |
| `image_*`, `music_*`, `video_*`, `tts` | Media | `mcp_media::handle_gen` | L4 (Motor) $\rightarrow$ L0 | SC-MEDIA-001 (Offload to `intelitor-mojo` or secure API) |
| `subagents`, `agents_list`, `session_*` | Orchestrator | `mcp_orch::handle_swarm` | L5 (Cognitive) | SC-ORCH-001 (State via `Smriti.db`) |

### 2.2 Skills (Cognitive Context) Mapping
Skills (`SKILL.md`) provide step-by-step guidance injected into the LLM context.

| Component | Responsibility | Fractal Layer | SIL-6 Safety Constraint |
| :--- | :--- | :--- | :--- |
| **SkillLoader Actor** | Dynamically reads `.agents/skills/{name}/SKILL.md` | L5 (Cognitive/Gleam) | SC-OPENCLAW-003 (System Prompt Prefixing) |
| **Skill Registry** | Maintains state of active and available skills | L6 (Ecosystem/Rust) | SC-DAT-040 (Audit Logging in `Smriti.db`) |
| **Orient Phase** | Injects skill text into the Cortex reasoning cycle | L5 (Cognitive/Gleam) | SC-COG-001 (Neuromorphic Routing) |

### 2.3 Plugins (Substrate Extensions)
Plugins bundle Tools, Skills, and Media capabilities.

| Plugin Type | Indrajaal Mapping | Fractal Layer | Execution Boundary |
| :--- | :--- | :--- | :--- |
| **Native Plugins** | Rust Modules (`mcp_*.rs`) | L4 (Motor) | Statically compiled into `sa-plan-daemon`. |
| **External Plugins** | Ephemeral Podman Cells | L0 (Substrate) | UDS communication via Zenoh; no host access. |
| **NIF Plugins** | Erlang NIFs (`*.so`) | L1/L2 (Transport/Health) | Loaded into BEAM via `cepaf_gleam_ffi`. |

## 3. Operational & Usage Layers

### 3.1 Authorization & Configuration
OpenClaw configuration mechanisms are mapped to the Indrajaal state database (`Smriti.db`).
*   **Allow/Deny Lists**: Implemented via the Rust daemon's configuration loader. Deny always takes precedence.
*   **Tool Profiles**: Logical groupings (e.g., `group:fs`, `group:web`, `group:media`, `minimal`, `coding`, `messaging`) are resolved by the Cortex before initiating MCP calls.
*   **Provider Restrictions**: (`tools.byProvider`) Enforced by the `query_llm_advisor` function, restricting certain tools based on whether the provider is `openrouter`, `gemma4`, or another active model.

### 3.2 Operational Flow
1.  **User Request**: Human sends a command via Telegram/GChat (L7).
2.  **Cognitive Parsing**: Gleam Cortex (L5) analyzes the request.
3.  **Skill Loading**: If a specific skill is identified, the SkillLoader (L5) retrieves the `SKILL.md` and injects it into the prompt.
4.  **Tool Selection**: The Cortex queries the LLM Advisor (OpenRouter/Gemma4), passing the allowed tool profile.
5.  **Motor Execution**: The LLM selects a tool. The Cortex dispatches an MCP request via Zenoh (L1).
6.  **Substrate Action**: The Rust Planning Daemon (L4) executes the tool (e.g., spawning a sandboxed `code_execution` container at L0).
7.  **Observation**: The result is captured, logged to `Smriti.db` (L3), and returned up the stack.
