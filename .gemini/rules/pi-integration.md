# Pi-Mono Integration Protocol (SC-PI)
# पाई-मोनो एकीकरण प्रोतोकॉल

## Mandate
**Pi-mono is a symbiotic subsystem of C3I. All Pi operations MUST comply with C3I safety kernel, publish to Zenoh mesh, and use Smriti.db for persistence.**

## Architecture
Pi-mono (TypeScript, 172K LOC, 7 packages) provides:
- Multi-provider LLM abstraction (15 providers)
- Interactive coding agent with rich TUI
- Web components for chat interfaces
- Extension system (60+ event types)
- Session management with branching

**Location**: `sub-projects/pi-mono/`
**Build**: `cd sub-projects/pi-mono && npm install && npm run build`
**Version**: 0.67.68 (lockstep across all packages)

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-PI-001 | Pi agent MUST publish events to Zenoh (SC-ZMOF-001) | CRITICAL |
| SC-PI-002 | Pi tools MUST be gated by Guardian for L0 operations | CRITICAL |
| SC-PI-003 | Pi sessions MUST be stored in Smriti.db | HIGH |
| SC-PI-004 | Pi LLM calls MUST use C3I circuit breaker infrastructure | HIGH |
| SC-PI-005 | Pi extensions MUST NOT bypass safety kernel | CRITICAL |
| SC-PI-006 | Pi web-ui MUST work within Lustre SSR pages | HIGH |
| SC-PI-007 | Pi TUI rendering MUST integrate with split-screen | MEDIUM |
| SC-PI-008 | Pi model registry MUST sync with C3I model resolver | HIGH |
| SC-PI-009 | Pi skills MUST be discoverable by C3I skill system | MEDIUM |
| SC-PI-010 | Pi PII handling MUST comply with SC-SEC-003 | CRITICAL |

## Package Inventory
| Package | LOC | Purpose |
|---------|-----|---------|
| pi-ai | 27,384 | LLM providers (OpenAI, Anthropic, Google, Bedrock, Mistral, etc.) |
| pi-agent-core | 1,879 | Agent runtime, tool calling, event system |
| pi-coding-agent | 43,046 | CLI agent, sessions, extensions, skills |
| pi-tui | 10,907 | Terminal UI, differential rendering |
| pi-web-ui | 14,629 | Web components, ChatPanel |
| pi-mom | 4,046 | Slack bot |
| pi-pods | 1,773 | vLLM GPU pod management |

## Fractal Layer Mapping
| Layer | Pi Component | Integration |
|-------|-------------|-------------|
| L0 | beforeToolCall blocking | Guardian gate enforcement |
| L1 | onPayload/onResponse | OTel span injection |
| L2 | TypeBox schemas | Type bridge to Gleam ADTs |
| L3 | Session manager | Smriti.db backend |
| L4 | Pi pods (vLLM) | Podman orchestration |
| L5 | Agent loop + steering | OODA Orient injection |
| L6 | Extension event bus | Zenoh event publishing |
| L7 | MOM Slack bot | Gateway unification |

## Build Requirements
- Node.js >= 20.0.0
- npm (workspaces)
- `@typescript/native-preview-linux-x64` (platform package for tsgo)

## AOR Rules
| ID | Rule |
|----|------|
| AOR-PI-001 | ALWAYS build Pi before integration testing |
| AOR-PI-002 | NEVER embed Pi in BEAM process (separate Node.js process) |
| AOR-PI-003 | ALWAYS proxy Pi LLM calls through C3I cortex |
| AOR-PI-004 | ALWAYS publish Pi events to Zenoh |
| AOR-PI-005 | NEVER store Pi sessions as JSONL in production (use Smriti.db) |
