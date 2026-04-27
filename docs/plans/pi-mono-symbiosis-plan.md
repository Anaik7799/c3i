# Pi-Mono x C3I Full Symbiosis Plan
# पाई-मोनो × सी3आई पूर्ण सहजीवन योजना

**Version**: 1.0.0
**Date**: 2026-04-19
**Status**: APPROVED — Integration Roadmap
**ZK**: [zk-42230e7bb1049f52] cold-start anti-pattern avoided via ZK institutional memory

---

## 1. Code Analysis Summary

### Pi-Mono (v0.67.68) — TypeScript AI Agent Toolkit

| Package | Files | LOC | Purpose |
|---------|-------|-----|---------|
| **pi-ai** | 44 | 27,384 | Multi-provider LLM abstraction (OpenAI, Anthropic, Google, Gemini, Bedrock, Mistral, etc.) |
| **pi-agent-core** | 5 | 1,879 | Agent runtime: tool calling, state management, event system |
| **pi-coding-agent** | 129 | 43,046 | Interactive CLI agent: tools, sessions, extensions, skills, slash commands |
| **pi-tui** | 25 | 10,907 | Terminal UI: differential rendering, components, editor, autocomplete |
| **pi-web-ui** | 71 | 14,629 | Web components: ChatPanel, dialogs, storage, tools |
| **pi-mom** | 16 | 4,046 | Slack bot: message delegation to coding agent |
| **pi-pods** | 9 | 1,773 | vLLM GPU pod management CLI |
| **TOTAL** | **594** | **172,149** | — |

### C3I System — Gleam/Rust Cybernetic Mesh

| Subsystem | Files | LOC | Language |
|-----------|-------|-----|---------|
| Gleam UI/API/TUI | 283+ | ~42,000+ | Gleam |
| Rust Cortex Daemon | 31 | 9,104 | Rust |
| Gleam Tests | 70+ | 18,000+ | Gleam |
| Total | 380+ | ~70,000+ | Mixed |

### Key Architectural Parallels

| Concept | Pi-Mono | C3I | Integration Point |
|---------|---------|-----|------------------|
| **Agent Runtime** | `Agent` class (agent.ts, 543 LOC) | `cortex.gleam` + `cortex.rs` (1,567 LOC) | Bidirectional agent bridge |
| **Tool System** | `AgentTool<T>` interface, 14 tools | 73 MCP tools via c3i_nif | Tool registry federation |
| **LLM Providers** | 15 providers (pi-ai) | 6-tier hedged inference (cortex.rs) | Unified provider pool |
| **TUI** | pi-tui (differential rendering) | Gleam TUI (ANSI + split-screen) | Shared terminal substrate |
| **Web UI** | Web components (ChatPanel) | Lustre SSR (31 pages) | Complementary — pi for chat, Lustre for dashboards |
| **Events** | `AgentEvent` (12 types) | AG-UI (32 event types) | Event protocol bridge |
| **Skills** | Markdown skill files with frontmatter | `.claude/commands/` (50 skills) | Unified skill registry |
| **Extensions** | Extension API (60+ event types) | Hooks (settings.json) | Hook ↔ Extension bridge |
| **Session Mgmt** | JSONL sessions, forking, branching | Smriti.db SQLite, conversation history | Shared session store |
| **Slash Commands** | 19 built-in commands | 50+ custom commands | Command namespace federation |
| **Model Registry** | Generated models (1000+ entries) | Model resolver in cortex.rs | Shared model catalog |
| **Config** | `~/.pi/` directory | `.claude/` + `devenv.nix` | Config hierarchy merge |

---

## 2. Functional Equivalence Map

### Pi Tools ↔ C3I MCP Tools

| Pi Tool | Description | C3I Equivalent | Status |
|---------|-------------|----------------|--------|
| `read` | Read file contents | `mcp__c3i__file_context` | EXISTS |
| `bash` | Execute shell commands | Bash via cortex intent | EXISTS |
| `edit` | Edit file with diffs | Gleam file operations | EXISTS |
| `write` | Write file contents | Gleam file operations | EXISTS |
| `grep` | Search file contents | `mcp__c3i__knowledge_search` (broader) | PARTIAL |
| `find` | Find files by pattern | Glob via cortex | EXISTS |
| `ls` | List directory | File context MCP | EXISTS |

### Pi Features ↔ C3I Features

| Pi Feature | C3I Equivalent | Gap? |
|-----------|----------------|------|
| Multi-provider LLM (15) | 6-tier hedged inference | Pi has MORE providers; C3I has hedging/fallback |
| Context compaction | Context management (200K budget) | Similar approach |
| Session branching/forking | Conversation history (50-msg window) | Pi MORE sophisticated sessions |
| Extension system (60+ hooks) | Claude hooks (5 hooks) | Pi MUCH richer extension system |
| Skill system | Claude commands (50 skills) | EQUIVALENT |
| TUI diff rendering | ANSI TUI + split screen | Pi MORE sophisticated terminal rendering |
| Web components | Lustre SSR + WebSocket | COMPLEMENTARY — different approaches |
| Slash commands (19) | Slash commands (50+) | C3I has MORE commands |
| HTML export | — | Pi UNIQUE |
| Slack bot (MOM) | Telegram/GChat gateway | COMPLEMENTARY — different platforms |
| vLLM pod management | Ollama + Podman orchestration | COMPLEMENTARY |
| OAuth providers | OIDC/FerrisKey | COMPLEMENTARY |

---

## 3. Biomorphic Integration Matrix

### Mapping Pi to the 7 Biological Subsystems

| Subsystem | C3I Current | Pi Addition | Symbiosis |
|-----------|-------------|-------------|-----------|
| **Nervous (L1)** | WebSocket 1s push, auto-build hook | Pi TUI differential rendering (<16ms) | Pi's diff rendering replaces ANSI raw writes |
| **Immune (L0)** | Wiring guard, type system, fitness function | Pi `beforeToolCall` / `afterToolCall` hooks | Pi hooks become immune checkpoints |
| **Circulatory (L6)** | Zenoh pub/sub mesh | Pi event stream (`AgentEvent` 12 types) | Pi events published to Zenoh topics |
| **Skeletal (L2)** | Gleam types (domain.gleam) | Pi TypeBox schemas (`TSchema`) | Type bridge: Gleam ADTs ↔ Pi TypeBox |
| **Digestive (L3)** | NIF pipeline, parser → renderer | Pi `transformContext`, `convertToLlm` | Context transform shared pipeline |
| **Reproductive (L7)** | Autopoiesis (templates → pages → patterns) | Pi session publishing to HuggingFace | Session data becomes training data |
| **Endocrine (L5)** | OODA loop, 52 GRL rules, RETE-UL | Pi steering messages, follow-up queue | Pi steering = OODA Orient phase injection |

### Fractal Layer Integration (L0-L7)

| Layer | C3I Component | Pi Component | Integration |
|-------|--------------|--------------|-------------|
| **L0 Constitutional** | Guardian, emergency stop, Psi invariants | `beforeToolCall` blocking | Pi tool gates enforce L0 invariants |
| **L1 Atomic/Debug** | Debug trace, event monitor | Pi `onPayload`, `onResponse` callbacks | Wire Pi callbacks to OTel spans |
| **L2 Component** | A2UI catalog (233 components) | Pi web components (ChatPanel, etc.) | A2UI renders Pi components in Lustre |
| **L3 Transaction** | Planning, task CRUD, Smriti.db | Pi session manager, JSONL persistence | Shared SQLite backend |
| **L4 System** | Podman orchestration, container lifecycle | Pi pods (vLLM management) | Unified container orchestration |
| **L5 Cognitive** | OODA cortex, rule engine, 6-tier inference | Pi agent loop, multi-provider LLM | Pi becomes inference frontend for cortex |
| **L6 Ecosystem** | Zenoh mesh, agent collaboration | Pi extension runner, event bus | Extension events bridged to Zenoh |
| **L7 Federation** | Gateway (Telegram/GChat), federation | Pi MOM (Slack bot), session sharing | Multi-platform gateway unification |

---

## 4. Artifact Synchronization Audit

### Current C3I .claude Ecosystem

| Category | Count | Details |
|----------|-------|---------|
| **Rules** | 85 files | 43 active, 42 deprecated (superseded) |
| **Agents** | 36 definitions | 25 engineering + 6 sales + 5 operations |
| **Commands/Skills** | 50 skills | 22 engineering + 28 sales |
| **Hooks** | 5 types | SessionStart, UserPromptSubmit, PostToolUse, PreToolUse, Stop |
| **Memory** | 25+ files | User, feedback, project, reference types |
| **Settings** | 1 file | MCP servers, hooks, permissions |

### Pi-Mono Configuration Surface

| Category | Count | Details |
|----------|-------|---------|
| **AGENTS.md** | 1 file | Development rules for AI agents |
| **Extensions** | 60+ hook types | Rich lifecycle event system |
| **Skills** | Markdown with frontmatter | Discovery from `~/.pi/skills/` and project `.pi/skills/` |
| **Slash Commands** | 19 built-in | settings, model, export, import, share, etc. |
| **Prompt Templates** | Discovery-based | From `~/.pi/prompts/` and project `.pi/prompts/` |
| **Themes** | JSON themes | Customizable TUI rendering |
| **Config** | `~/.pi/settings.json` | Keybindings, extensions, providers |

### Synchronization Plan

| Pi Artifact | C3I Target | Action |
|-------------|-----------|--------|
| `AGENTS.md` | `.claude/rules/pi-integration.md` | Import Pi's code quality rules as a C3I rule |
| Pi extensions API | `.claude/settings.json` hooks | Map Pi's 60+ event types to C3I's 5 hook types |
| Pi skills system | `.claude/commands/` | Make C3I commands loadable as Pi skills |
| Pi prompt templates | Already compatible | Pi and Claude use same markdown+frontmatter format |
| Pi slash commands | C3I skills | Import Pi's 19 commands as C3I skills |
| Pi themes | TUI view | Import Pi theme JSON into Gleam TUI renderer |
| Pi keybindings | Claude keybindings | Merge keybinding systems |

---

## 5. Integration Architecture

### Phase 1: Bridge Layer (Week 1-2)

```
┌────────────────────────────────────────────────────────┐
│                    C3I MESH (Zenoh)                      │
│  indrajaal/pi/events/**   ← Pi agent events             │
│  indrajaal/pi/tools/**    ← Pi tool results              │
│  indrajaal/pi/sessions/** ← Pi session state             │
├────────────────────────────────────────────────────────┤
│              PI-C3I BRIDGE (Gleam + TypeScript)          │
│                                                          │
│  bridge/pi_agent.gleam    ← Gleam wrapper for Pi agent   │
│  bridge/pi_provider.ts    ← C3I as Pi LLM provider      │
│  bridge/pi_tools.ts       ← C3I MCP tools as Pi tools   │
│  bridge/zenoh_events.ts   ← Pi events → Zenoh publisher  │
├────────────────────────────────────────────────────────┤
│              PI-MONO (Node.js / Bun)                     │
│  packages/coding-agent    ← Interactive agent            │
│  packages/ai              ← LLM providers                │
│  packages/tui             ← Terminal UI                  │
│  packages/web-ui          ← Web components               │
└────────────────────────────────────────────────────────┘
```

### Phase 2: Provider Unification (Week 3-4)

Pi-ai supports 15 LLM providers. C3I cortex has 6-tier hedged inference. Merge:

1. **Pi as inference frontend**: Pi-ai handles provider negotiation, streaming, retries
2. **C3I cortex as orchestrator**: Hedged parallel inference, circuit breakers, semantic cache
3. **Shared model registry**: Pi's generated models.ts merged with C3I's model resolver

```typescript
// pi-c3i-provider.ts — Register C3I as a Pi provider
registerProvider("c3i-cortex", {
  stream: async (model, context, options) => {
    // Route through C3I's 6-tier hedged inference
    // Publish OTel span to indrajaal/otel/spans/pi/inference
    return streamViaCortex(model, context, options);
  }
});
```

### Phase 3: Tool Federation (Week 5-6)

Make C3I's 73 MCP tools available as Pi tools and vice versa:

```typescript
// c3i-tools-for-pi.ts
function createC3iToolsForPi(): AgentTool[] {
  return [
    { name: "c3i_knowledge_search", label: "Search C3I Zettelkasten",
      execute: (id, params) => mcpCall("knowledge_search", params) },
    { name: "c3i_plan_status", label: "Check plan status",
      execute: (id, params) => mcpCall("plan_status", params) },
    { name: "c3i_gleam_build", label: "Build Gleam project",
      execute: (id, params) => mcpCall("gleam_build", params) },
    // ... all 73 tools
  ];
}
```

```gleam
// pi_tools.gleam — Pi tools available in C3I
pub fn pi_session_export(session_id: String) -> Result(String, Error) {
  // Call Pi's session export via RPC
  pi_rpc("export", [#("session", session_id)])
}
```

### Phase 4: UI Symbiosis (Week 7-8)

1. **Pi ChatPanel in Lustre**: Embed Pi's web components in C3I's Lustre pages
2. **Pi TUI in C3I split-screen**: Pi's differential renderer for the chat pane
3. **Shared WebSocket**: Pi's RPC mode connects to C3I's Mist WebSocket

### Phase 5: Zenoh Mesh Integration (Week 9-10)

1. **Pi agent events → Zenoh**: Every Pi `AgentEvent` published to `indrajaal/pi/events/{type}`
2. **Zenoh → Pi extensions**: C3I Zenoh events trigger Pi extension hooks
3. **Shared telemetry**: Pi's usage/timing data flows through OTel-over-Zenoh

---

## 6. STAMP Constraints for Integration

| ID | Constraint | Severity |
|----|------------|----------|
| SC-PI-001 | Pi agent MUST publish events to Zenoh (SC-ZMOF-001 compliance) | CRITICAL |
| SC-PI-002 | Pi tools MUST be gated by C3I Guardian for L0 operations | CRITICAL |
| SC-PI-003 | Pi sessions MUST be stored in Smriti.db (not just JSONL files) | HIGH |
| SC-PI-004 | Pi LLM calls MUST go through C3I's circuit breaker infrastructure | HIGH |
| SC-PI-005 | Pi extensions MUST NOT bypass C3I's safety kernel | CRITICAL |
| SC-PI-006 | Pi's web-ui components MUST work within Lustre SSR pages | HIGH |
| SC-PI-007 | Pi TUI diff rendering MUST integrate with C3I split-screen | MEDIUM |
| SC-PI-008 | Pi model registry MUST sync with C3I's model resolver | HIGH |
| SC-PI-009 | Pi skills MUST be discoverable by C3I's skill system | MEDIUM |
| SC-PI-010 | Pi PII handling MUST comply with C3I's SC-SEC-003 (PII scrubbing) | CRITICAL |

---

## 7. Build & Install Protocol

### Completed Steps
- [x] Clone: `sub-projects/pi-mono/` (depth 1)
- [x] Install: `npm install` (532 packages, 0 vulnerabilities)
- [x] Platform fix: `npm install @typescript/native-preview-linux-x64`
- [x] Build: `npm run build` (all 7 packages compiled)
- [x] Verify: `pi --version` → 0.67.68

### Integration Build Steps (TODO)
- [ ] Create `lib/cepaf_gleam/src/cepaf_gleam/bridge/pi_agent.gleam` — Gleam wrapper
- [ ] Create `sub-projects/pi-mono/packages/c3i-bridge/` — TypeScript bridge package
- [ ] Register C3I as Pi provider in `register-builtins.ts`
- [ ] Create Pi extension for Zenoh event publishing
- [ ] Add Pi to `devenv.nix` for Node.js dependency
- [ ] Add Pi build to CI pipeline
- [ ] Create `sa-plan-daemon pi` subcommand for Pi management

---

## 8. Deprecated Rule Cleanup (Sync Audit)

### Rules Marked "Superseded" (should be cleaned)

| File | Superseded By |
|------|--------------|
| biomorphic-mode.md | biomorphic-evolution-protocol.md + operational-architecture.md |
| change-management.md | git-and-workflow.md |
| concurrent-bug-fix-protocol.md | git-and-workflow.md |
| cpu-governor.md | build-and-test.md |
| deletion-safeguard.md | core-protocols.md |
| functional-invariant.md | core-protocols.md |
| git-commit-convention.md | git-and-workflow.md |
| human-intent-protection.md | core-protocols.md |
| mandatory-compile-env.md | build-and-test.md |
| panoptic-swarm-ignition.md | operational-architecture.md |
| swarm-verification.md | operational-architecture.md |
| todolist-access-control.md | todolist-access.md |
| reconciled-p0-safety.md | constraint-registry.md |
| reconciled-p1-core.md | constraint-registry.md |
| reconciled-p2-domain-*.md (5) | constraint-registry.md |
| reconciled-p3-style.md | constraint-registry.md |

**Total deprecated**: 18 files — these are redirect stubs, safe to keep as pointers.

### Active Rules (67 files)

All 67 active rules define the C3I operating protocol. Pi integration will add 1 new rule:
- `.claude/rules/pi-integration.md` — SC-PI-001..010 constraints

---

## 9. Risk Assessment (FMEA)

| Risk | Severity | Occurrence | Detection | RPN | Mitigation |
|------|----------|------------|-----------|-----|------------|
| Pi Node.js crashes BEAM VM | 9 | 2 | 3 | 54 | Run Pi as separate process, not embedded |
| Pi LLM calls bypass circuit breaker | 8 | 4 | 2 | 64 | Proxy all Pi LLM calls through C3I cortex |
| Pi session data diverges from Smriti.db | 7 | 5 | 3 | 105 | Single session store in SQLite |
| Pi extension breaks Zenoh mesh | 6 | 3 | 4 | 72 | Sandbox Pi extensions from Zenoh write |
| Node.js dependency conflicts | 5 | 3 | 2 | 30 | Isolated npm workspace |
| Pi web-ui breaks Lustre SSR | 6 | 4 | 3 | 72 | Iframe isolation for Pi web components |
| API key leakage through Pi | 9 | 2 | 2 | 36 | Use C3I's Smriti encrypted secrets |

---

## 10. Value Proposition

### What Pi Gives C3I

1. **15 LLM providers** — immediately available (vs C3I's 4 via hedged inference)
2. **Production-grade TUI** — differential rendering, editor component, autocomplete
3. **Rich extension system** — 60+ hook types (vs C3I's 5 hooks)
4. **Session branching** — fork, tree navigation, HTML export
5. **Web chat components** — drop-in ChatPanel for any page
6. **Slack integration** — MOM bot for team workflow
7. **vLLM management** — GPU pod scaling for production inference
8. **172K LOC** of battle-tested agent infrastructure

### What C3I Gives Pi

1. **Zenoh mesh** — distributed pub/sub for multi-agent coordination
2. **73 MCP tools** — planning, knowledge search, system health, container management
3. **SIL-6 safety kernel** — Guardian approval, 2oo3 voting, Psi invariants
4. **2,679 holon Zettelkasten** — institutional memory across sessions
5. **52 GRL rules** — RETE-UL decision engine
6. **16-container orchestration** — biomorphic mesh with self-healing
7. **OTel observability** — full distributed tracing via Zenoh
8. **Fractal architecture** — L0-L7 layers with type-safe Gleam

### Combined Capabilities (Symbiosis)

| Capability | Alone (Pi) | Alone (C3I) | Together |
|-----------|-----------|-------------|----------|
| LLM providers | 15 | 4 | **15 + hedged fallback** |
| Tools | 14 | 73 | **87 federated** |
| Event types | 12 | 32 | **44 unified** |
| Skills | Custom | 50 | **50+ discoverable** |
| TUI quality | Excellent | Good | **Excellent (Pi rendering)** |
| Web UI | Chat-focused | Dashboard-focused | **Full spectrum** |
| Safety | Basic | SIL-6 | **SIL-6 with Pi gates** |
| Persistence | JSONL files | SQLite ACID | **SQLite ACID** |
| Messaging | Slack | Telegram+GChat | **All three** |
| GPU management | vLLM pods | Ollama | **Both local and cloud** |

---

## 11. Implementation Priority (Eisenhower Matrix)

### Urgent + Important (Do First)
1. **Create Pi bridge Gleam module** — enables tool federation
2. **Register C3I as Pi provider** — unified inference
3. **Pi events → Zenoh publisher** — mesh integration

### Important + Not Urgent (Schedule)
4. **Session store unification** — Smriti.db backend for Pi sessions
5. **Pi web components in Lustre** — ChatPanel embedding
6. **Pi TUI in split-screen** — differential rendering

### Urgent + Not Important (Delegate)
7. **Pi slash commands → C3I skills** — mechanical mapping
8. **Theme sync** — Pi themes for C3I TUI
9. **Keybinding merge** — unified shortcuts

### Not Urgent + Not Important (Defer)
10. **Slack bot (MOM) integration** — nice-to-have
11. **vLLM pod management** — future scaling
12. **HuggingFace session sharing** — research value

---

## 12. Constitutional Alignment

### Psi Invariant Compliance

| Invariant | Pi Impact | Mitigation |
|-----------|-----------|------------|
| Psi-0 (Existence) | Pi crash must not kill C3I | Separate process, supervisor restart |
| Psi-1 (Regeneration) | Pi state must be recoverable | SQLite-backed sessions |
| Psi-2 (Reversibility) | Pi actions must be undoable | Session branching + git |
| Psi-3 (Verification) | Pi outputs must be verifiable | OTel spans for all Pi operations |
| Psi-4 (Alignment) | Pi must preserve human intent | SC-HINT sections inviolable by Pi |
| Psi-5 (Truthfulness) | Pi must not fabricate data | SC-TRUTH constraints apply to Pi outputs |
| Omega-0 (Founder) | Pi serves the founder | All Pi tools accessible to operator |

### Ultrathink Focus Area Mapping

| # | Focus Area | Pi Contribution |
|---|-----------|-----------------|
| 4 | Homomorphic Tripartite UI | Pi web components + TUI in Lustre/TUI/API |
| 6 | Embedded SLM Cognitive Kernels | Pi's multi-provider LLM access for edge models |
| 9 | OpenClaw Ecosystem | Pi as an OpenClaw-compatible agent interface |
| 10 | HA Seamless Upgrades | Pi's hot-reload via extension system |

---

## Conclusion

Pi-mono is a **natural symbiont** for C3I. The architectures are complementary, not competing:
- Pi excels at **interactive agent UX** (TUI, chat, sessions, extensions)
- C3I excels at **distributed systems infrastructure** (Zenoh mesh, safety kernel, observability)

The integration follows the biomorphic principle: Pi becomes the **sensory and motor cortex** (L1 response + L5 cognition) while C3I provides the **nervous system backbone** (L6 circulatory + L0 immune).

Total integration surface: **172K LOC Pi + 70K LOC C3I = 242K LOC unified agentic platform**.

---

*Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>*
