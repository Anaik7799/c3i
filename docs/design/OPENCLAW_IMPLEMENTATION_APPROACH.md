# Design & Implementation Approach: OpenClaw Ecosystem

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: IMPLEMENTATION STRATEGY

## 1. Overview
This document details the strategy for implementing the OpenClaw Tools and Skills ecosystem within the Indrajaal Personal OS, ensuring alignment with the SIL-6 Biomorphic Mesh constraints.

## 2. Implementation Strategy

### 2.1 Motor Strip Reification (Rust)
The `sa-plan-daemon` acts as the authoritative Motor Strip. We will extend it with specific MCP handlers for each tool category.

*   **`mcp_sys.rs` (Runtime Tools)**:
    *   `exec`/`process`: Implement using `std::process::Command`. To satisfy SC-OPENCLAW-001, commands will be wrapped in a `podman run` call to execute within a short-lived container (e.g., `localhost/intelitor-sandbox`).
    *   `code_execution`: Similar to `exec`, but specifically mounts the code payload into a Python-equipped sandbox container.
*   **`mcp_file.rs` (File IO Tools)**:
    *   `read`/`write`/`edit`/`apply_patch`: Implement using standard Rust filesystem operations (`std::fs`).
    *   **Security Injection**: Implement a canonical path resolution function that verifies the target path starts with the `$WORKSPACE_ROOT`. Any attempt at directory traversal (`../`) must return an `IgnitionError::SecurityViolation`.
*   **`mcp_web.rs` (Web Tools)**:
    *   `web_fetch`/`web_search`: Implement using `reqwest` for HTTP and a crate like `scraper` for DOM parsing to extract meaningful content.
*   **`mcp_media.rs` (Media Generation)**:
    *   `image_generate`/`tts`: Route these requests via HTTP to the `intelitor-mojo` cell where specialized models reside.

### 2.2 Cognitive Plane Enhancement (Gleam)
The Gleam layer needs to dynamically load and inject skills into the reasoning loop.

*   **`cepaf_gleam/agents/skill_loader.gleam`**:
    *   An OTP actor responsible for watching the `.agents/skills/` directory.
    *   Exposes a `GetSkill(name: String)` message.
    *   Parses `SKILL.md` files.
*   **Prompt Injection**:
    *   In the `Cortex` Orient phase, the system will identify if the user intent matches a known skill (via keyword matching or a lightweight embedding search).
    *   If a skill matches, the `SkillLoader` retrieves the content, prefixes it with `[SYSTEM SKILL DIRECTIVE]`, and prepends it to the LLM prompt.
    *   The `Cortex` will then query the active LLM provider (OpenRouter or Gemma4) via `query_llm_advisor`.

### 2.3 Configuration and Authorization
The configuration of which tools are allowed for which provider must be dynamically managed.

*   **`Smriti.db` Configuration Table**:
    *   Store Tool Profiles (e.g., `profile_coding: ["read", "write", "code_execution"]`).
    *   Store Deny Lists (e.g., `deny_gemma4: ["exec"]` - perhaps we don't trust local models with direct shell access yet).
*   **Rust Verification Hook**:
    *   Before executing any MCP request in `cortex.rs`, verify the requested tool against the active Allow/Deny list stored in the database.

## 3. Staged Rollout Plan
1.  **Phase 1**: File IO (`mcp_file.rs`) and Web Fetch (`mcp_web.rs`). These are read-only or low-risk operations.
2.  **Phase 2**: Skill Loader Actor in Gleam. Verify that the LLM context correctly absorbs `SKILL.md` directives.
3.  **Phase 3**: Sandboxed Runtime Execution (`mcp_sys.rs`). High complexity due to Podman integration and timeout handling.
4.  **Phase 4**: Orchestration and Media tools.
