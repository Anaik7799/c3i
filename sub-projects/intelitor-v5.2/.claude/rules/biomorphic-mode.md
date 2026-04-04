# Biomorphic Cybernetic Execution Mode (Default)

## Activation
This mode is DEFAULT for all sessions. Biomorphic execution with 25 agents, 2-layer supervision.

## STAMP/AOR Reference
> SC-BIO-001 to SC-BIO-008, AOR-BIO-001 to AOR-BIO-010 — defined in CLAUDE.md §5.0, §9.0
> Key thresholds: OODA step < 100ms (cycle < 30ms), compact at 75%, API scaling at 70%, dashboard 30s

## Agent Architecture (25 Agents, 2 Layers)

### Layer 1: Executive Supervisor (1 Agent)
- **EXEC-001**: Master orchestrator with veto authority
- Monitors all L2 supervisors
- Triggers /compact at 75% context

### Layer 2: Domain Supervisors (4 Agents)
- **SUP-CONTEXT**: Context Monitor Agent (75% threshold, auto-compact)
- **SUP-DOMAIN**: Domain Integration Supervisor
- **SUP-TEST**: Test Coverage Supervisor
- **SUP-QUALITY**: Quality Gate Supervisor

### Layer 3: Worker Agents (20 Agents)
- **WRK-COMPILE-{1-3}**: Compilation workers (parallel)
- **WRK-TEST-{1-5}**: Test execution workers (parallel)
- **WRK-CREDO-{1-2}**: Code quality workers
- **WRK-FIX-{1-5}**: Bug fix workers (parallel)
- **WRK-DOC-{1-2}**: Documentation workers
- **WRK-EXPLORE-{1-3}**: Codebase exploration workers

## Context Management Protocol (CRITICAL)

```
Session Budget: 200K tokens
├─ Reserved for core work: 160K (80%)
├─ Reserved for compaction: 20K (10%)
└─ Safety buffer: 20K (10%)

Checkpoint 1: At 75K (37%) → Log status
Checkpoint 2: At 150K (75%) → TRIGGER /compact
Checkpoint 3: At 180K (90%) → Enter minimal mode
```

## Automatic Execution Pattern

When user requests a task:

```elixir
# 1. Deploy Context Monitor Agent (always first)
Task(subagent_type: "Explore", model: "haiku", run_in_background: true)

# 2. Deploy Domain Supervisors (parallel)
Task(subagent_type: "Explore", model: "haiku", run_in_background: true) # x4

# 3. Deploy Worker Agents (as needed, max 20)
Task(subagent_type: "general-purpose", model: "haiku", run_in_background: true) # xN

# 4. Monitor with 30s OODA loop
TaskOutput(block: false) # Check status

# 5. Auto-compact at 75% threshold
/compact --summary
```

## Quality Gates (Mandatory)

Before marking any task complete:
1. `NO_TIMEOUT=true PATIENT_MODE=enabled SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16" mix compile --jobs 16` - 0 errors, 0 warnings
2. `mix format --check-formatted` - pass
3. `mix credo --strict` - 0 issues
4. `SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true NO_TIMEOUT=true PATIENT_MODE=enabled ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16" MIX_ENV=test mix test` - 0 failures
5. All STAMP constraints verified

## Haiku Model Preference

Per AOR-API-005:
- Worker agents: Use `model: "haiku"` (cost efficiency)
- Supervisor agents: Use `model: "sonnet"` (judgment required)
- Executive agent: Use `model: "opus"` (complex decisions)

## Context Consumption Limits

Per CMA-001 analysis:
- **Document generation**: Max 10KB before chunking
- **Test batching**: Max 5 files per compile
- **File reads**: Max 10 parallel reads
- **Planning docs**: Max 3 per domain

## Telemetry Dashboard (30s refresh)

```
╔═════════════════════════════════════════════════════════════╗
║  BIOMORPHIC SWARM STATUS                      [30s refresh] ║
╠═════════════════════════════════════════════════════════════╣
║  Context: ████████░░░░░░░░░░░░ 40% (80K/200K)              ║
║  API:     ██████░░░░░░░░░░░░░░ 30% (1.2K/4K RPM)          ║
║  Agents:  ████████████████████ 20/25 active                ║
║  Tasks:   ████████████░░░░░░░░ 60% (12/20 complete)       ║
║  Quality: ████████████████░░░░ 80% (gate passing)          ║
╚═════════════════════════════════════════════════════════════╝
```
