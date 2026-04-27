# Pi-Mono Runtime Activation Protocol (SC-PI-RUNTIME)

## Mandate
**Pi-mono Node.js runtime MUST be activatable from the BEAM mesh. The runtime is managed as a subprocess with circuit breaker protection, health monitoring, and auto-restart.**

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-PI-RUNTIME-001 | Pi process MUST be started via pi_runtime.gleam (not ad-hoc shell) | CRITICAL |
| SC-PI-RUNTIME-002 | Circuit breaker MUST open after 3 consecutive failures | HIGH |
| SC-PI-RUNTIME-003 | Auto-restart MUST NOT exceed 5 restarts per 10-minute window | CRITICAL |
| SC-PI-RUNTIME-004 | Health check MUST run every 10 seconds when process is Running | HIGH |
| SC-PI-RUNTIME-005 | Graceful shutdown MUST send SIGTERM then wait 5s before SIGKILL | HIGH |
| SC-PI-RUNTIME-006 | All lifecycle events MUST publish OTel spans via zenoh_otel | HIGH |
| SC-PI-RUNTIME-007 | RPC commands MUST use JSONL protocol (one JSON object per line) | CRITICAL |
| SC-PI-RUNTIME-008 | Provider/model MUST be configurable (default: google/gemini-2.5-flash) | MEDIUM |

## Architecture
```
Claude Code ─── prompt ──→ Pi RPC (JSONL/stdin) ──→ Node.js process
                                                      │
                    ┌─────────────────────────────────┘
                    │
              Pi Agent Runtime
              ├── 15 LLM Providers (Google, Anthropic, Ollama, OpenRouter, ...)
              ├── Tool execution (read, write, edit, bash, grep, glob, ...)
              ├── Extension system (ZK recall, C3I bridge, session sync)
              ├── Session management (fork, compact, export)
              └── AG-UI event stream ──→ stdout ──→ Gleam subscriber
```

## Files
| File | Purpose | Lines |
|------|---------|-------|
| `bridge/pi_runtime.gleam` | Process lifecycle, circuit breaker, auto-restart | ~400 |
| `bridge/pi_rpc.gleam` | JSONL protocol, command serialization, provider list | ~300 |
| `bridge/pi_claude_code.gleam` | Event mapping, tool federation, bridge state | ~477 |
| `bridge/pi_agent.gleam` | Agent types, session types, inference tiers | ~250 |
| `bridge/pi_tools.gleam` | 93 federated tools (6 Claude + 14 Pi + 73 C3I) | ~180 |
| `bridge/pi_zenoh.gleam` | Zenoh topic publishing for Pi events | ~150 |
| `bridge/pi_provider.gleam` | 6-tier hedged inference cascade | ~120 |
| `actors/pi_subscriber.gleam` | OTP actor for Pi event processing | ~217 |
| `test/pi_runtime_test.gleam` | 42 tests covering lifecycle + RPC protocol | ~350 |

## Usage

### One-Shot Prompt (non-interactive)
```bash
# Via Pi CLI directly
source sub-projects/pi-mono/load-env.sh
node sub-projects/pi-mono/packages/coding-agent/dist/cli.js \
  --provider google --model gemini-2.5-flash \
  --print "Your prompt here"
```

### RPC Mode (persistent daemon)
```bash
# Start Pi in RPC mode (JSONL over stdin/stdout)
source sub-projects/pi-mono/load-env.sh
node sub-projects/pi-mono/packages/coding-agent/dist/cli.js \
  --provider google --model gemini-2.5-flash \
  --mode rpc

# Send commands as JSON lines on stdin:
{"type":"get_state","id":"req_1"}
{"type":"prompt","id":"req_2","message":"Hello from C3I"}
{"type":"get_available_models","id":"req_3"}
```

### From Gleam (programmatic)
```gleam
import cepaf_gleam/bridge/pi_runtime
import cepaf_gleam/bridge/pi_rpc

// Initialize runtime
let rt = pi_runtime.init()
let #(rt, _) = pi_runtime.handle_command(rt, pi_runtime.Start)

// Build RPC command
let cmd = pi_rpc.prompt(1, "Analyze this code")
let json = pi_rpc.serialize_command(cmd)
// Send json to Pi process stdin...

// Check health
let _ = pi_runtime.is_available(rt)
let _ = pi_runtime.dashboard_summary(rt)
```

## Provider Presets
| Preset | Provider | Model | Use Case |
|--------|----------|-------|----------|
| `google_flash_config()` | google | gemini-2.5-flash | Fast, free, interactive |
| `google_pro_config()` | google | gemini-2.5-pro | Deep analysis |
| `ollama_config()` | ollama | gemma3 | Offline, private |
| `anthropic_config()` | anthropic | claude-sonnet-4 | High quality |

## 15 Supported Providers
anthropic, google, openai, ollama, bedrock, mistralai, openrouter, groq, deepseek, xai, cerebras, qwen, sambanova, fireworks, together

## Circuit Breaker State Machine
```
Closed ──(3 failures)──→ Open ──(cooldown 60s)──→ HalfOpen ──(success)──→ Closed
                                                      │
                                                  (failure)
                                                      ↓
                                                    Open
```

## Integration with Existing Pi Constraints
- Extends SC-PI-001..010 (full Pi integration)
- Extends SC-PI-AUTO-001..008 (symbiosis automation)
- Extends SC-ARCH-SPLIT-003 (bridge via NIF/Zenoh/CLI)
- Extends SC-WIRE-001 (wiring guard updated — 111 connections)
