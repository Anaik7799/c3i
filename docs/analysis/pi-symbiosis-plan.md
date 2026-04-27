# Pi Symbiosis Plan (Fractal Complete)

## Parity Matrix (Claude → Pi)
- Agents (.claude/agents/**) → .pi/skills/<agent>/SKILL.md (decision guides)
- Commands (.claude/commands/**) → Pi extension commands + .pi/prompts/*.md
- Rules (.claude/rules/**) → always-on: .pi/SYSTEM.md; scoped: skill-local context
- Settings (.claude/settings*.json) → .pi/settings.json (models/transport/telemetry)
- Migration plan (.claude/plans/MIGRATION_PLAN.md) → tracked via sa-plan-daemon (no manual edits)
- Context (AGENTS.md, CLAUDE.md) → auto-loaded; augmented by .pi/SYSTEM.md
- Tests → pi_integration_test.gleam + Gleam suite; npm run build (pi-mono)
- Journal/ZK → docs/analysis/pi-symbiosis-journal.md, ingest to ZK after updates

### Parity entries (seed)
- master-supervisor → .pi/skills/master-supervisor/SKILL.md | Layers: L0–L7 | Control: Guardian, circuit breakers, Zenoh | Data: Smriti sessions, AG-UI events | Tests: pi_integration + coverage audit.
- design-supervisor → .pi/skills/design-supervisor/SKILL.md | Layers: L0–L7 mapping | Control: ZMOF namespaces | Data: TypeBox↔ADT, AG-UI/A2UI.
- build-supervisor → .pi/skills/build-supervisor/SKILL.md | Layers: L2–L5 | Control: Guardian, circuit breakers | Data: Smriti, AG-UI/A2UI validation | Tests: npm/gleam/split-screen.
- deploy-supervisor → .pi/skills/deploy-supervisor/SKILL.md | Layers: L4–L7 | Control: Guardian, circuit breakers | Data: Smriti | Tests: pi_integration + coverage audit + Wallaby if needed.
- fractal-architect → .pi/skills/fractal-architect/SKILL.md | Layers: all | Control: namespace and holon checks | Data: AG-UI/A2UI enforcement | Tests: wiring_guard if Msg/Model changes.
- operate-supervisor → .pi/skills/operate-supervisor/SKILL.md | Layers: L4–L7 | Control: breaker health, Zenoh flow | Data: Smriti runtime.
- coverage-audit-agent → .pi/skills/coverage-audit-agent/SKILL.md | Layers: test/meta | Control: math gates | Data: coverage counts, AG-UI/A2UI.

## Fractal Mapping (L0–L7)
- L0 Constitutional: Guardian gate for destructive tools; spans `indrajaal/l0/const/**`; wiring guard alignment.
- L1 Atomic: Tool IO tracing (before/after) → OTel spans with payload fingerprints.
- L2 Component: TypeBox↔ADT validation; AG-UI schema enforcement; A2UI allowlist check.
- L3 Transaction: Smriti session adapter (branching/compaction preserved); MoZ correlation IDs; transactional ack.
- L4 System: Circuit breakers for LLM calls; pod routing (pi-pods) alignment; health reporting; split-screen hooks.
- L5 Cognitive: OODA steering hooks; model resolver sync with C3I; skill selection aligned to swarm roles; reasoning spans.
- L6 Ecosystem: Extension bus mirrored to Zenoh; skill registry sync; mesh topology awareness.
- L7 Federation: MOM/Slack/Telegram bridges; version vectors; gateway subscription to critical spans.

## Control/Data Path Integration
- Zenoh/OTel: Pi event bus → Zenoh (AG-UI 32 + spans); MoZ subscribe for MCP; ZMOF taxonomy.
- Guardian gate: policy table + HITL approval; log to Zenoh/Smriti.
- Circuit breakers: C3I breaker config; hedged where supported.
- Smriti sessions: primary; JSONL fallback for local; preserve branching/compaction metadata.
- Model registry sync: periodic reconciliation with C3I resolver.
- MCP tool parity: register C3I MCP tools; enforce wiring guard updates.
- AG-UI/A2UI compliance: schema + allowlist enforced.
- Split-screen/TUI: Pi TUI attachable; pi-web-ui embed safe in Lustre SSR.

## Workstreams (parallelizable)
- A) Context/constraints: .pi/SYSTEM.md, .pi/settings.json
- B) Docs: parity matrix + fractal map (this file); journal entry + ZK ingest
- C) Extension: .pi/extensions/c3i-bridge.ts (commands, Zenoh pub/sub, Guardian gate stub, Smriti hook, model sync stub, MCP registry stub, breaker stub)
- D) Skills/Prompts: port core agents to .pi/skills; high-use commands to .pi/prompts; add checklists
- E) Data path: Smriti adapter; Zenoh wiring; AG-UI/A2UI validation; circuit breakers; TypeBox↔ADT bridge
- F) UI: embed pi-web-ui in Lustre SSR (flagged); split-screen TUI hook; AG-UI flow validation
- G) Verification: pi_integration_test coverage; npm run build (pi-mono); gleam build/test; split-screen cycle; Wallaby if LV touched; coverage audit; ZK ingest after updates

## Implementation Backlog (must-complete)
- Zenoh client: node-zenoh integration; ZMOF topics; correlation IDs; AG-UI schema enforcement.
- Guardian gate: HITL approval path; Zenoh + Smriti audit logs; policy table.
- Smriti session adapter: primary persistence; JSONL fallback; status reporting.
- Model registry sync: pull from C3I resolver; update scoped models.
- MCP registry sync: register tools; enforce wiring_guard alignment.
- Circuit breakers: wrap LLM calls; hedged when available.
- Type validation: TypeBox↔Gleam ADT; A2UI allowlist enforcement; AG-UI payload validation.
- UI embedding: pi-web-ui SSR flag; split-screen TUI attach command; namespace isolation.

## Risks / Watchpoints
- Stubs must be replaced before relying on production paths.
- Guardian bypass risk if not wired; destructive tools must be gated.
- Smriti adapter absence could leave sessions in JSONL only; not compliant.
- AG-UI/A2UI validation gaps could allow nonconformant payloads.
- Circuit breaker omission could expose LLM calls to failure cascades.

## Test Plan
- npm run build (sub-projects/pi-mono)
- gleam build && gleam test
- gleam test -- --module pi_integration
- ./scripts/run-split-screen-tests.sh
- WALLABY_ENABLED=true ... mix test --only wallaby (if LV affected)
- Coverage audit (math gates)

## Deliverables
- .pi/SYSTEM.md, .pi/settings.json
- .pi/extensions/c3i-bridge.ts (with Zenoh, Guardian, Smriti, model sync, MCP registry stubs)
- .pi/skills/*, .pi/prompts/*
- Smriti session adapter; TypeBox↔ADT validation layer; circuit breaker wiring
- pi-web-ui embed flag + split-screen TUI launcher
- Updated pi_integration_test.gleam; coverage audit report; journal + ZK ingest
