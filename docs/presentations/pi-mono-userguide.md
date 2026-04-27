# Pi-Mono x C3I Integration User Guide

**HTML Version**: [https://vm-1.tail55d152.ts.net:8090/pi-mono-userguide.html](https://vm-1.tail55d152.ts.net:8090/pi-mono-userguide.html)

---

## 1. Overview

Pi-mono is an open-source AI agent toolkit (172K LOC TypeScript) now integrated as a C3I sub-project. It provides 15 LLM providers, a production-grade TUI, web chat components, and a rich extension system.

**Combined platform**: 242K LOC, 87 tools, 44 events, 15 providers, SIL-6 safety.

---

## 2. Quick Start

### Build Pi
```bash
cd /home/an/dev/ver/c3i/sub-projects/pi-mono
npm install
npm run build
```

### Run Pi CLI
```bash
cd /home/an/dev/ver/c3i/sub-projects/pi-mono
node packages/coding-agent/dist/cli.js --help
# Or via the wrapper:
./pi-test.sh
```

### Run Pi with a Specific Provider
```bash
# Google (default)
pi --provider google --model gemini-2.5-flash

# Anthropic
pi --provider anthropic --model claude-sonnet-4-6

# OpenAI
pi --provider openai --model gpt-5.2

# Local Ollama
pi --provider openai --model gemma3 --api-key ollama --base-url http://localhost:11434/v1
```

---

## 3. Key Features

### 3.1 Multi-Provider LLM
Pi supports 15+ providers out of the box:
- Anthropic, OpenAI, Google, Google Vertex, Amazon Bedrock
- Mistral, Azure OpenAI, Groq, Cerebras, xAI
- OpenRouter, GitHub Copilot, HuggingFace, Minimax

### 3.2 Tools (14 Built-In)
- `read` — Read file contents
- `bash` — Execute shell commands
- `edit` — Edit files with diffs
- `write` — Write file contents
- `grep` — Search file contents
- `find` — Find files by pattern
- `ls` — List directory contents

### 3.3 Skills
Skills are markdown files with frontmatter placed in `.pi/skills/` directories:
```markdown
---
name: my-skill
description: Does something useful
---
Instructions for the agent...
```

### 3.4 Extensions
Extensions hook into Pi's lifecycle events (60+ types):
- `session_start` / `session_shutdown`
- `before_tool_call` / `after_tool_call`
- `message_start` / `message_end`
- `turn_start` / `turn_end`

### 3.5 Session Management
- Sessions auto-saved as JSONL
- Branch and fork sessions
- Export to HTML
- Import/resume previous sessions
- Context compaction when window fills

### 3.6 Slash Commands
Type `/` to see available commands:
- `/model` — Switch LLM model
- `/compact` — Compact context window
- `/export` — Export session to HTML
- `/fork` — Fork session at a previous point
- `/tree` — Navigate session branches

---

## 4. C3I Integration Points

### 4.1 Zenoh Mesh
Pi events will be published to Zenoh topics:
```
indrajaal/pi/events/{event_type}
indrajaal/pi/tools/{tool_name}
indrajaal/pi/sessions/{session_id}
```

### 4.2 MCP Tool Federation
C3I's 73 MCP tools are available as Pi tools when the bridge is active:
```bash
# Pi can call C3I tools
pi> Search the Zettelkasten for "ARM account plan"
# This calls c3i_knowledge_search via the bridge
```

### 4.3 Safety Kernel
Pi operations on L0 Constitutional layer require Guardian approval:
- Emergency stop commands
- Safety invariant modifications
- Constitutional changes

### 4.4 Smriti.db Persistence
Pi sessions are backed by C3I's SQLite database, ensuring:
- ACID transactions
- Full-text search via FTS5
- Conversation history
- Zettelkasten integration

---

## 5. Architecture

```
User Input
    │
    ├──▶ Pi TUI (differential rendering)
    │       │
    │       ▼
    │   Pi Agent Loop
    │       │
    │       ├──▶ Pi-AI (15 providers)
    │       │       │
    │       │       ▼
    │       │   C3I Cortex (hedged inference)
    │       │       │
    │       │       ▼
    │       │   LLM Response
    │       │
    │       ├──▶ Pi Tools (14) + C3I MCP (73) = 87 federated
    │       │
    │       └──▶ Zenoh Events (published to mesh)
    │
    └──▶ C3I Dashboard (Lustre SSR, 31 pages)
            │
            └──▶ Pi ChatPanel (embedded web component)
```

---

## 6. STAMP Constraints (SC-PI)

| ID | What It Means |
|----|--------------|
| SC-PI-001 | All Pi events go to Zenoh — no silent operations |
| SC-PI-002 | Dangerous tools need Guardian approval |
| SC-PI-003 | Sessions stored in database, not flat files |
| SC-PI-004 | LLM calls go through circuit breakers |
| SC-PI-005 | Cannot bypass safety kernel |
| SC-PI-006 | Web components work in Lustre pages |
| SC-PI-007 | TUI integrates with split-screen |
| SC-PI-008 | Model list stays synchronized |
| SC-PI-009 | Pi skills discoverable by C3I |
| SC-PI-010 | Personal data is scrubbed |

---

## 7. Troubleshooting

| Problem | Solution |
|---------|----------|
| `tsgo` build fails | Run `npm install @typescript/native-preview-linux-x64` |
| Pi can't find providers | Set API keys: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY` |
| Session not persisting | Check Smriti.db bridge is running |
| TUI garbled | Try `TERM=xterm-256color` or fallback to raw ANSI |
| Zenoh events not publishing | Verify Zenoh router on TCP 7447 |
| Tool federation fails | Check c3i-bridge.ts is loaded as extension |

---

## 8. File Locations

| Item | Path |
|------|------|
| Pi source | `sub-projects/pi-mono/` |
| Pi CLI | `sub-projects/pi-mono/packages/coding-agent/dist/cli.js` |
| Pi config | `~/.pi/settings.json` |
| Pi skills | `~/.pi/skills/` or `.pi/skills/` |
| Pi extensions | `~/.pi/extensions/` |
| Integration rule | `.claude/rules/pi-integration.md` |
| Symbiosis plan | `docs/plans/pi-mono-symbiosis-plan.md` |
| Analysis slides | `docs/presentations/pi-mono-analysis.html` |
| This guide (HTML) | `docs/presentations/pi-mono-userguide.html` |
| Journal | `docs/journal/20260419-pi-mono-symbiosis-analysis.md` |
