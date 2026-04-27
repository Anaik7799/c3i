# Pi-Mono Runtime User Guide

## Overview

Pi-mono is a multi-provider AI coding agent integrated into C3I as a symbiotic subsystem. It provides access to 15 LLM providers, 14 native tools, rich TUI, web components, and an extension system — all managed from the Gleam/BEAM mesh.

## Quick Start

### 1. Verify Installation
```bash
cd /home/an/dev/ver/c3i
node sub-projects/pi-mono/packages/coding-agent/dist/cli.js --help
```

### 2. One-Shot Prompt (fastest way to use Pi)
```bash
source sub-projects/pi-mono/load-env.sh

# Google Gemini (free, fast)
node sub-projects/pi-mono/packages/coding-agent/dist/cli.js \
  --provider google --model gemini-2.5-flash \
  --print "Summarize this project in 3 bullet points"

# Ollama (local, offline, private)
node sub-projects/pi-mono/packages/coding-agent/dist/cli.js \
  --provider ollama --model gemma3 \
  --print "Explain what Gleam is"
```

### 3. Interactive TUI Mode
```bash
source sub-projects/pi-mono/load-env.sh
node sub-projects/pi-mono/packages/coding-agent/dist/cli.js \
  --provider google --model gemini-2.5-flash
# Opens an interactive terminal UI with rich rendering
```

### 4. RPC Mode (for C3I integration)
```bash
source sub-projects/pi-mono/load-env.sh
node sub-projects/pi-mono/packages/coding-agent/dist/cli.js \
  --provider google --model gemini-2.5-flash \
  --mode rpc
# JSON commands on stdin, JSON events on stdout
```

## Providers

Pi supports 15 LLM providers. Each requires an API key set as an environment variable (loaded by `load-env.sh` from `~/.zshrc`).

| Provider | Env Variable | Models | Cost |
|----------|-------------|--------|------|
| **google** | `GOOGLE_API_KEY` | gemini-2.5-flash, gemini-2.5-pro | Free tier |
| **anthropic** | `ANTHROPIC_API_KEY` | claude-sonnet-4, claude-opus-4 | Paid |
| **openai** | `OPENAI_API_KEY` | gpt-4o, o3, o4-mini | Paid |
| **ollama** | (local, no key) | gemma3, llama3, qwen2 | Free (local) |
| **openrouter** | `OPENROUTER_API_KEY` | Any model via proxy | Variable |
| **bedrock** | AWS credentials | Claude, Titan | AWS pricing |
| **mistralai** | `MISTRAL_API_KEY` | mistral-large | Paid |
| **groq** | `GROQ_API_KEY` | llama3-70b | Free tier |
| **deepseek** | `DEEPSEEK_API_KEY` | deepseek-chat | Cheap |
| **xai** | `XAI_API_KEY` | grok-3 | Paid |
| **cerebras** | `CEREBRAS_API_KEY` | llama3-70b | Fast |
| **qwen** | `QWEN_API_KEY` | qwen2-72b | Varies |
| **sambanova** | `SAMBANOVA_API_KEY` | Various | Varies |
| **fireworks** | `FIREWORKS_API_KEY` | Various | Varies |
| **together** | `TOGETHER_API_KEY` | Various | Varies |

### Recommended Presets

| Use Case | Command |
|----------|---------|
| **Fast interactive** | `--provider google --model gemini-2.5-flash` |
| **Deep analysis** | `--provider google --model gemini-2.5-pro` |
| **Offline/private** | `--provider ollama --model gemma3` |
| **Code generation** | `--provider anthropic --model claude-sonnet-4-20250514` |
| **Cost-free** | `--provider groq --model llama-3.3-70b-versatile` |

## RPC Protocol

### Command Format
JSON objects sent one per line on stdin:
```json
{"type": "prompt", "id": "req_1", "message": "Hello"}
{"type": "get_state", "id": "req_2"}
{"type": "set_model", "id": "req_3", "provider": "ollama", "modelId": "gemma3"}
{"type": "abort", "id": "req_4"}
{"type": "compact", "id": "req_5"}
{"type": "bash", "id": "req_6", "command": "echo hello"}
{"type": "new_session", "id": "req_7"}
{"type": "get_available_models", "id": "req_8"}
{"type": "get_session_stats", "id": "req_9"}
{"type": "get_messages", "id": "req_10"}
{"type": "get_commands", "id": "req_11"}
```

### Response Format
```json
{"type": "response", "id": "req_1", "command": "prompt", "success": true}
{"type": "response", "id": "req_2", "command": "get_state", "success": true, "data": {...}}
{"type": "response", "id": "req_3", "command": "set_model", "success": false, "error": "Model not found"}
```

### Event Stream
Between responses, agent events stream as JSON on stdout:
```json
{"type": "agent_start", ...}
{"type": "message_start", ...}
{"type": "message_update", "text": "partial response..."}
{"type": "tool_execution_start", "tool": "read", ...}
{"type": "tool_execution_end", ...}
{"type": "message_end", ...}
{"type": "agent_end", ...}
```

## Gleam Integration

### Module Map
```
bridge/pi_runtime.gleam    — Process lifecycle management
bridge/pi_rpc.gleam        — RPC command serialization
bridge/pi_claude_code.gleam — Event mapping (29 Pi ↔ 32 AG-UI)
bridge/pi_agent.gleam      — Agent types and session management
bridge/pi_tools.gleam      — 93 federated tools (6 Claude + 14 Pi + 73 C3I)
bridge/pi_zenoh.gleam      — Zenoh topic publishing
bridge/pi_provider.gleam   — 6-tier hedged inference cascade
actors/pi_subscriber.gleam — OTP actor for event processing
```

### Runtime State Machine
```
Stopped → Starting → Running → ShuttingDown → Stopped
                ↓                    ↑
           [crash]              [graceful]
                ↓
          Starting (auto-restart, max 5x)
                ↓ (>5 restarts)
             Failed → [reset] → Stopped
```

### Circuit Breaker
- **Closed**: Normal operation, requests flow through
- **Open**: 3+ consecutive health check failures, requests rejected for 60s
- **HalfOpen**: Testing recovery, next failure reopens

## C3I Bridge Features

### Tool Federation (93 total)
- **6 Claude Code tools**: Read, Write, Edit, Bash, Grep, Glob
- **14 Pi tools**: read, write, edit, bash, search, glob, agent, web_search, web_fetch, notebook, lsp, diff, patch, mcp_invoke
- **73 C3I MCP tools**: plan_status, system_health, knowledge_search, podman_containers, etc.

### Event Bridge (29 Pi ↔ 32 AG-UI)
Pi events are bidirectionally mapped to C3I's AG-UI 32-event protocol:
- Pi lifecycle → AG-UI Lifecycle
- Pi tool execution → AG-UI Tool
- Pi session → AG-UI State
- Pi LLM context → AG-UI Reasoning

### Zenoh Topics
```
indrajaal/pi/runtime/status    — Process status changes
indrajaal/pi/runtime/health    — Health check results
indrajaal/pi/agent/events      — Agent lifecycle events
indrajaal/pi/tools/calls       — Tool invocations
indrajaal/pi/session/state     — Session state changes
indrajaal/pi/provider/metrics  — Inference metrics
indrajaal/pi/bridge/health     — Bridge health heartbeat
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Pi not starting" | Check `load-env.sh` loads API keys. Verify `node --version` >= 20 |
| "Provider error" | Verify API key is set: `echo $GOOGLE_API_KEY` |
| "Out of usage" | Anthropic key exhausted — switch to `--provider google` |
| "Circuit breaker open" | Too many failures — wait 60s or reset via `handle_command(rt, ResetCircuit)` |
| "Max restarts exceeded" | Process crashing repeatedly — check stderr for root cause |
| "Module not found" | Run `cd sub-projects/pi-mono && npm install && npm run build` |
| "CAPTCHA/rate limit" | Pi hit provider rate limit — wait or switch provider |

## Build Pi from Source
```bash
cd sub-projects/pi-mono
npm install
npm run build
# Binary at packages/coding-agent/dist/cli.js
```

## Tests
```bash
cd lib/cepaf_gleam
# Pi runtime + RPC tests (42 tests)
gleam test -- --module pi_runtime_test

# Pi bridge tests (30 tests)
gleam test -- --module pi_claude_code_test

# Pi integration tests
gleam test -- --module pi_operations_robustness_test

# Full suite (9055+ tests)
gleam test
```
