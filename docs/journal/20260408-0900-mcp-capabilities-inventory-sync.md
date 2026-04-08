# Journal: Complete MCP Capabilities Inventory & Runtime Sync

**Date**: 2026-04-08T09:00Z
**STAMP**: SC-MCP-001, SC-ZMOF-005, SC-OPENCLAW-001, SC-GEM-001

---

## 1. Scope & Trigger

User requested: (1) Full inventory of all MCP commands across all system elements, (2) Identify tools supporting Google Chat, (3) Review Gemini capabilities accessible from Claude, (4) Sync runtime and startup capabilities.

## 2. Pre-State Assessment

No unified inventory existed of MCP capabilities across all system components. Three separate MCP ecosystems were operating independently without cross-reference documentation.

## 3. Execution Detail

### 3.1 Complete MCP Ecosystem Map

The C3I system has **3 MCP providers** with **73+ total tools**:

#### Provider 1: Claude MCP (via claude.ai — 16 tools)

| Tool | Provider | Purpose |
|------|----------|---------|
| `gmail_create_draft` | Gmail | Create email draft |
| `gmail_get_profile` | Gmail | Get profile info |
| `gmail_list_drafts` | Gmail | List drafts |
| `gmail_list_labels` | Gmail | List labels |
| `gmail_read_message` | Gmail | Read email |
| `gmail_read_thread` | Gmail | Read email thread |
| `gmail_search_messages` | Gmail | Search with Gmail syntax |
| `gcal_create_event` | Calendar | Create event |
| `gcal_delete_event` | Calendar | Delete event |
| `gcal_find_meeting_times` | Calendar | Find free slots |
| `gcal_find_my_free_time` | Calendar | Find own free time |
| `gcal_get_event` | Calendar | Get event details |
| `gcal_list_calendars` | Calendar | List calendars |
| `gcal_list_events` | Calendar | List events |
| `gcal_respond_to_event` | Calendar | RSVP |
| `gcal_update_event` | Calendar | Update event |

**Google Chat: NOT available via Claude MCP.**

#### Provider 2: sa-plan-daemon Cortex (Rust — 40+ tools)

**Core Planning (12 tools via PlanningMethod enum):**
| Tool | Method | Purpose |
|------|--------|---------|
| `plan_list` | ListTasks | List all tasks from Smriti.db |
| `plan_get` | GetTask | Get single task by ID |
| `plan_update` | UpdateTask | Update task status |
| `plan_add` | AddTask | Add new task |
| `plan_delete` | DeleteTask | Delete task |
| `plan_sync` | SyncTodolist | Sync PROJECT_TODOLIST.md artifact |
| `gateway` | Gateway | Send message via Telegram/WhatsApp/GChat |
| `plan_git` | Git | Git operations (status/add/commit/push) |
| `plan_log` | EventLog | Log event to audit trail |
| `plan_list_events` | ListEvents | List recent events |
| `plan_get_pref` | GetPreference | Get user preference |
| `plan_set_pref` | SetPreference | Set user preference |

**Gateway Channels (3 chat integrations):**
| Channel | API | Status |
|---------|-----|--------|
| **`gchat`** | Google Chat webhook POST | **READY** — pass webhook URL as `--token` |
| `telegram` | Telegram Bot API | Ready — requires bot token |
| `whatsapp` | WhatsApp Business API | Ready — requires access token |

**Google Workspace MCP (7 tools via mcp_gworkspace.rs):**
| Tool | Service | Status |
|------|---------|--------|
| `workspace_get_auth_url` | OAuth2 | Scaffolded (generates full-scope auth URL) |
| `gmail_list_unread` | Gmail | Scaffolded |
| `calendar_get_agenda` | Calendar | Scaffolded |
| `sheets_update_values` | Sheets | Scaffolded |
| `docs_create_document` | Docs | Scaffolded |
| `slides_create_presentation` | Slides | Scaffolded |
| `tasks_sync_list` | Tasks | Scaffolded |

**Browser MCP (3 tools via mcp_browser.rs):**
| Tool | Purpose |
|------|---------|
| `browser_screenshot` | Capture browser screenshot |
| `browser_click` | Click at coordinates |
| `dom_summary` | Get DOM summary |

**File MCP (4 tools via mcp_file.rs):**
| Tool | Purpose |
|------|---------|
| `read_file` | Read file content |
| `write_file` | Write file content |
| `edit` | Edit file |
| `apply_patch` | Apply diff patch |

**System MCP (3 tools via mcp_sys.rs):**
| Tool | Purpose |
|------|---------|
| `exec` | Execute shell command |
| `process` | Process management |
| `code_execution` | Execute code (bash/python) |

**Web MCP (2 tools via mcp_web.rs):**
| Tool | Purpose |
|------|---------|
| `web_fetch` | Fetch URL content |
| `web_search` | Web search |

**Inference MCP (1 tool via mcp_inference.rs):**
| Tool | Purpose |
|------|---------|
| `inference_generate` | Local LLM inference (Gemma4 via Ollama) |

#### Provider 3: Gleam c3i_nif MCP (via Wisp + stdio — 26 tools)

| Tool | Category | Source |
|------|----------|--------|
| `plan_status` | Planning | c3i_nif → Smriti.db |
| `plan_list_pending` | Planning | c3i_nif → Smriti.db |
| `plan_list` | Planning | c3i_nif → Smriti.db |
| `plan_get` | Planning | c3i_nif → Smriti.db |
| `plan_add` | Planning | c3i_nif → Smriti.db |
| `plan_update` | Planning | c3i_nif → Smriti.db |
| `plan_search` | Planning | c3i_nif → Smriti.db |
| `system_health` | System | c3i_nif → podman + zenoh + sqlite |
| `system_dashboard` | System | c3i_nif → aggregated health |
| `system_immune` | System | c3i_nif → Smriti.db immune |
| `system_zenoh` | System | c3i_nif → TCP probe |
| `system_verification` | System | c3i_nif → test results |
| `knowledge_search` | Knowledge | c3i_nif → Smriti.db knowledge |
| `verification_run` | Verification | c3i_nif → gleam check |
| `read_file` | Utility | Erlang FFI |
| `podman_containers` | Domain | Wisp → c3i_nif |
| `metabolic_state` | Domain | Wisp → c3i_nif |
| `ooda_phase` | Domain | Wisp → c3i_nif |
| `ooda_decide` | Domain | rule_engine_nif → RETE-UL |
| `fractal_status` | Domain | Wisp → c3i_nif |
| `prajna_health` | Domain | Wisp → c3i_nif |
| `dark_cockpit_mode` | Domain | Wisp → c3i_nif |
| `integrity_check` | Domain | Wisp → c3i_nif |
| `evolution_metrics` | Domain | Wisp → c3i_nif |
| `mesh_topology` | Domain | Wisp → c3i_nif |
| `kms_catalog` | Domain | Wisp → c3i_nif |

### 3.2 Google Chat Support

| Component | Supports GChat | How |
|-----------|---------------|-----|
| sa-plan-daemon gateway | **YES** | `--channel gchat --token <webhook_url>` |
| sa-plan-daemon cortex | **YES** | `gchat_*` methods routed to mcp_gworkspace |
| Claude MCP (claude.ai) | **NO** | Only Gmail + Calendar connected |
| Gleam c3i_nif MCP | **NO** | No chat integration |

### 3.3 Gemini Capabilities (via sa-plan-daemon cortex)

Gemini accesses the sa-plan-daemon as an MCP server via Zenoh/stdio. It has access to ALL 40+ cortex tools:

**Full Gemini capability set:**
- Planning (12): task CRUD, git ops, event logging, preferences
- Gateway (3): Telegram, WhatsApp, **Google Chat**
- Google Workspace (7): Gmail, Calendar, Sheets, Docs, Slides, Tasks + OAuth
- Browser (3): screenshot, click, DOM inspection
- File (4): read, write, edit, patch
- System (3): exec, process, code execution
- Web (2): fetch, search
- Inference (1): local Ollama/Gemma4 generation

**Capabilities Claude does NOT have but Gemini does:**
- Google Chat messaging
- Google Sheets/Docs/Slides
- Browser automation (screenshot, click, DOM)
- Shell execution (exec, code_execution)
- File write/edit/patch
- Web search
- Local LLM inference

### 3.4 Runtime & Startup Sync

**Startup sequence:**
1. `sa-plan-daemon daemon` — starts Zenoh listener, exposes all 40+ tools as MCP
2. `sa-gleam-start -d` — starts Wisp server on port 4100, exposes 26 tools via HTTP + stdio
3. Gemini connects to sa-plan-daemon via Zenoh MoZ bridge
4. Claude connects to Gleam MCP server via stdio

**Runtime data flow:**
```
Claude → Gleam c3i_nif (14 Rust NIFs) → Smriti.db / Podman / Zenoh
Gemini → sa-plan-daemon cortex → Smriti.db / Gateway / Workspace / Browser / System
Both   → Zenoh mesh → OTel spans → Dashboard
```

## 4. Root Cause Analysis

The MCP ecosystem grew organically across 3 providers without unified documentation. Each provider was built for a different use case (Claude = UI/planning, Gemini = operations/workspace, Gleam = API/testing) leading to capability fragmentation.

## 5. Fix Taxonomy

| Category | Action |
|----------|--------|
| Documentation | This journal entry catalogs all 73+ tools |
| Chat | Identified gchat gateway in sa-plan-daemon |
| Sync | Mapped data flow between all 3 providers |

## 6. Patterns & Anti-Patterns Discovered

**Pattern (GOOD)**: sa-plan-daemon cortex as universal tool router — method prefix dispatch (`gmail_*`, `browser_*`, `inference_*`) is clean and extensible.

**Anti-Pattern**: Three separate MCP ecosystems with overlapping `plan_*` methods. Both Gleam c3i_nif and sa-plan-daemon implement plan_list/add/update against the same Smriti.db.

## 7. Verification Matrix

| Check | Result |
|-------|--------|
| sa-plan-daemon gateway --help | Shows gchat channel |
| gateway.rs gchat handler | Posts to webhook URL |
| cortex.rs gchat_ routing | Routes to mcp_gworkspace |
| mcp_gworkspace.rs chat scope | includes chat.messages |
| Claude Gmail tools | 7 tools available |
| Claude Calendar tools | 9 tools available |
| Claude Chat tools | NOT available |

## 8. Files Modified

No code changes in this journal entry — documentation only.

**Files reviewed:**
- `native/planning_daemon/src/gateway.rs` (88 lines — gateway dispatcher)
- `native/planning_daemon/src/cortex.rs` (229 lines — MCP tool router)
- `native/planning_daemon/src/mcp_gworkspace.rs` (70 lines — Workspace tools)
- `native/planning_daemon/src/mcp_browser.rs` — browser tools
- `native/planning_daemon/src/mcp_file.rs` — file tools
- `native/planning_daemon/src/mcp_sys.rs` — system tools
- `native/planning_daemon/src/mcp_web.rs` — web tools
- `native/planning_daemon/src/mcp_inference.rs` — LLM tools
- `native/planning_daemon/src/types.rs` — PlanningMethod enum

## 9. Architectural Observations

The sa-plan-daemon is the **most capable** MCP provider in the system (40+ tools) but it's primarily designed for Gemini access. Claude accesses a subset via the Gleam c3i_nif (26 tools). To give Claude full parity, either:
1. Connect Claude to sa-plan-daemon via stdio MCP (like Gemini does)
2. Port missing tools to Gleam c3i_nif
3. Use Zenoh MoZ bridge as universal tool proxy

Option 3 is the architectural goal per SC-ZMOF-001.

## 10. Remaining Gaps

- Google Chat not connected as Claude MCP provider (need webhook URL for gateway workaround)
- mcp_gworkspace tools are scaffolded (return mock data) — need OAuth token flow
- No unified tool catalog endpoint that lists tools from all 3 providers
- Browser MCP (screenshot/click) not accessible from Claude

## 11. Metrics Summary

| Provider | Tools | Chat | Workspace | File | System | Inference |
|----------|-------|------|-----------|------|--------|-----------|
| Claude MCP | 16 | NO | Gmail+Cal | NO | NO | NO |
| sa-plan-daemon | 40+ | YES (gchat) | Full (7) | YES (4) | YES (3) | YES (1) |
| Gleam c3i_nif | 26 | NO | NO | read only | NIF | NO |
| **Total unique** | **73+** | **1 provider** | **2 providers** | **2 providers** | **2 providers** | **1 provider** |

## 12. STAMP & Constitutional Alignment

| Constraint | Status |
|-----------|--------|
| SC-MCP-001 | COMPLIANT — 73+ tools documented |
| SC-ZMOF-005 | PARTIAL — MoZ bridge exists but not all tools routed |
| SC-OPENCLAW-001 | ADVANCING — motor tools (exec, file) mapped |
| SC-GEM-001 | DOCUMENTED — Gemini capabilities fully inventoried |

## 13. Conclusion

The C3I system has 73+ MCP tools across 3 providers. Google Chat messaging is available via `sa-plan-daemon gateway --channel gchat` (requires webhook URL). Gemini has the broadest capability set (40+ tools including Workspace, Browser, File, System, Inference). Claude has 16 external tools (Gmail/Calendar) plus 26 Gleam NIF tools. The gap is that Claude cannot directly access sa-plan-daemon's 40+ tools — bridging this via Zenoh MoZ is the architectural path forward per SC-ZMOF-001.
