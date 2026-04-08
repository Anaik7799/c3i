# Specification: OpenClaw Tools & Skills Integration for Indrajaal Personal OS

**Created**: 20260408-1600 CEST
**Status**: DRAFT / AUTHORITATIVE
**Framework**: SOPv5.11 + SIL-6 Biomorphic Mesh
**Compliance**: SC-MCP-001, SC-COG-001, SC-ZMOF-001

## 1. Executive Summary
This document formalizes the integration of the **OpenClaw Tools, Skills, and Plugins** ecosystem into the Indrajaal Personal OS. By mapping OpenClaw capabilities to our Fractal Brain-Stem architecture, we endow the Gleam Cortex with a comprehensive suite of motor skills (shell execution, file manipulation, web browsing) and dynamic cognitive guidance (SKILL.md injection).

## 2. Capability Analysis & Design Approach

### A. OpenClaw Tools (Motor Actions)
Tools are atomic, invokable functions. In our system, they will be implemented as Rust handlers in `sa-plan-daemon` and exposed over Zenoh (MoZ Protocol).

| Tool Category | OpenClaw Tool | Indrajaal Mapping (Rust MCP Endpoint) | Implementation Approach |
| :--- | :--- | :--- | :--- |
| **Runtime** | `exec`, `process` | `mcp_sys::handle_exec` | Sandboxed `std::process::Command` within `intelitor-app`. |
| **Runtime** | `code_execution` | `mcp_sys::handle_python` | Execute via ephemeral Podman cell to prevent host contamination. |
| **Web** | `browser` | `mcp_browser::handle_browser` | Expand existing Playwright MCP tool (Task 5.1). |
| **Web** | `web_fetch`, `web_search` | `mcp_web::handle_fetch` | Rust `reqwest` + `scraper` crate for semantic extraction. |
| **File IO** | `read`, `write`, `edit` | `mcp_file::handle_fs` | Rust `std::fs` with strict chroot directory jails. |
| **File IO** | `apply_patch` | `mcp_file::handle_patch` | Multi-hunk diff application utilizing `diffy` crate. |
| **Media** | `image_generate`, `tts` | `mcp_media::handle_gen` | Route to dedicated `intelitor-mojo` cell or external API. |
| **Orchestrator**| `subagents`, `status`| `mcp_orch::handle_swarm` | Queries to `Smriti.db` and Gleam `ExecutiveSupervisor`. |

### B. OpenClaw Skills (Cognitive Context)
Skills are Markdown files (`SKILL.md`) that provide step-by-step guidance.
*   **Design**: The Gleam `Cortex` actor will dynamically read `.agents/skills/{skill_name}/SKILL.md` during the **Orient** phase of the OODA loop.
*   **Implementation**: A new Gleam module `cepaf_gleam/agents/skill_loader.gleam` will inject skill text into the LLM system prompt.

### C. OpenClaw Plugins (Substrate Extensions)
Plugins bundle Tools and Skills.
*   **Design**: Plugins map to isolated **Podman Containers** or **Rust NIFs** dynamically loaded into the mesh.

## 3. Fractal Component Mapping

| Fractal Layer | Component | Responsibility | SIL-6 Safety Mapping |
| :--- | :--- | :--- | :--- |
| **L7 (Federation)** | Telegram/GChat | Accepts human request to use a Skill. | AOR-COM-002 |
| **L6 (Ecosystem)** | Skill Registry | Maintains list of available `.agents/skills/`. | SC-DAT-040 |
| **L5 (Cognitive)** | Gleam Cortex | Loads SKILL.md into LLM context, decides Tool. | SC-COG-001 |
| **L4 (Motor)** | Rust `sa-plan` | Executes the Tool request securely. | SC-SEC-041 |
| **L3 (Transaction)**| `Smriti.db` | Logs the tool execution and result. | SC-DAT-034 |
| **L2 (Health)** | OODA Supervisor | Monitors tool execution latency. | SC-PRF-050 |
| **L1 (Transport)** | Zenoh MoZ | Carries tool intent & result JSON-RPC. | SC-ZMOF-001 |
| **L0 (Substrate)** | Podman | Sandboxes dangerous tools (`code_execution`). | SC-CNT-009 |

## 4. Test Infrastructure (SIL-6 Compliance)
To ensure these powerful tools do not compromise the system, we implement a 4-tier test strategy:

1.  **Unit Tests (Rust)**: Test `mcp_sys` and `mcp_file` with mock file systems to verify chroot jailing.
2.  **Property Tests (Gleam)**: Use `PropCheck` to verify the `SkillLoader` parses all edge cases of markdown.
3.  **Integration Tests (MoZ)**: Dispatch Zenoh intents for every tool and verify expected JSON-RPC responses.
4.  **Cehacking Simulation (Gemma 4)**: Provide the LLM with a complex skill and measure its accuracy in selecting the correct tools in the correct sequence.

## 5. Security & Usage Constraints
*   **SC-OPENCLAW-001**: `code_execution` and `exec` MUST run within a dedicated, ephemeral Podman sandbox. Host execution is FORBIDDEN.
*   **SC-OPENCLAW-002**: File operations (`read`/`write`/`edit`) MUST be constrained to the `$WORKSPACE_ROOT` via canonical path resolution to prevent directory traversal.
*   **SC-OPENCLAW-003**: Skill injections MUST be prefixed with `[SYSTEM SKILL DIRECTIVE]` to prevent prompt injection attacks from external data.
