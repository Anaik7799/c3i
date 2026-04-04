# Indrajaal Agent Instructions

This project uses OpenCode with Claude Code-compatible rules. All agent instructions are defined in `CLAUDE.md`.

## Loading Agent Instructions

**CRITICAL**: When you start an OpenCode session, you MUST:

1. **Read CLAUDE.md first** - Contains all system axioms, constraints, and operational rules
2. **Reference `.claude/rules/`** for domain-specific constraints (safety, testing, etc.)
3. **Use agents** from `.opencode/agents/` or `.claude/agents/`
4. **Use skills** from `.opencode/skills/` or `.claude/commands/`

## Quick Reference

### Available Agents (invoke with @mention)
- `@code-reviewer` - Reviews code for quality and Indrajaal conventions
- `@fmea-analyzer` - Performs Failure Mode and Effects Analysis
- `@safety-validator` - Validates STAMP constraints and safety requirements
- `@sil6-validator` - Validates SIL-6 compliance
- `@constitutional-verifier` - Verifies Constitutional AI alignment
- `@holon-analyzer` - Analyzes biomorphic architecture
- `@test-generator` - Generates tests (TDG-compliant)
- `@wallaby-coverage-engineer` - Generates Wallaby E2E tests
- `@impact-analyzer` - Analyzes cascade impacts
- `@cpu-governor-supervisor` - Manages CPU governor
- `@coverage-audit-agent` - Audits test coverage
- `@immune-chaos-agent` - Chaos engineering for immune system
- `@code-evolution` - Manages morphogenic evolution
- `@fractal-architect` - Designs fractal architecture
- `@zenoh-mesh-analyzer` - Analyzes Zenoh mesh
- `@observability-analyzer` - Analyzes OTEL/Prometheus/Grafana
- `@robustness-analyzer` - Analyzes system robustness
- `@cepaf-bridge-analyzer` - Analyzes F#-Elixir bridge
- `@hyperscaler-analyzer` - Analyzes multi-cloud deployment
- `@master-supervisor` - Orchestrates supervisor agents
- `@build-supervisor` - Manages build pipeline
- `@operate-supervisor` - Manages operations
- `@deploy-supervisor` - Manages deployments
- `@design-supervisor` - Manages design reviews
- `@safety-validator` - Validates safety constraints
- `@code-debugger` - Debugs issues
- `@script-finder` - Finds and analyzes scripts
- `@prajna-operator` - Operates Prajna TUI

### Available Skills (use with skill tool)

**From .claude/commands (37 skills):**
- `@skill(compile)` - SIL-6 compilation with Zenoh telemetry
- `@skill(cpu-governor)` - CPU governor management
- `@skill(test)` - Test execution
- `@skill(quality)` - Quality checks (credo, format, etc.)
- `@skill(fmea)` - FMEA analysis workflow
- `@skill(sentinel)` - Sentinel health verification
- `@skill(zenoh)` - Zenoh mesh operations
- `@skill(swarm-verify)` - Swarm verification
- `@skill(wallaby-coverage)` - Wallaby E2E coverage
- `@skill(plan)` - F# Planning CLI
- `@skill(journal)` - Journal protocol
- `@skill(rca)` - Root cause analysis
- `@skill(immune)` - Immune system operations
- `@skill(guardian)` - Guardian command approval
- `@skill(database)` - Database operations
- `@skill(holon)` - Holon management
- `@skill(cepaf-test)` - F# CEPAF testing
- `@skill(checkpoint)` - Checkpoint management
- `@skill(datadog)` - Datadog integration
- `@skill(evolution)` - Evolution protocol
- `@skill(federation)` - Federation management
- `@skill(formal-verify)` - Formal verification
- `@skill(hyperscaler)` - Multi-cloud operations
- `@skill(kms)` - Knowledge management
- `@skill(mesh)` - Mesh operations
- `@skill(oracle)` - Oracle operations
- `@skill(prajna)` - Prajna TUI
- `@skill(prometheus)` - Prometheus integration
- `@skill(registry)` - Registry operations
- `@skill(review)` - Code review workflow
- `@skill(robustness)` - Robustness testing
- `@skill(sa)` - System architecture commands
- `@skill(scripts)` - Script management
- `@skill(sil4)` - SIL-4 validation
- `@skill(sil6)` - SIL-6 validation
- `@skill(stamp)` - STAMP analysis
- `@skill(impact)` - Impact analysis

**From .gemini/skills (4 additional skills):**
- `@skill(journal-protocol)` - Mandatory 13-section journal protocol
- `@skill(multilayer-swarm)` - Full parallelization swarm mode
- `@skill(system-engineering-sop)` - Safe-State design & hardening
- `@skill(mesh-resurrection)` - Autonomous fractal RCA for mesh failures

## System Architecture

### Quad-Stack UI
- **Phoenix LiveView**: Web Portal & Admin
- **Bolero WebUI**: F# / WASM High-Assurance C3I
- **Avalonia GUI**: F# / .NET 10 Desktop
- **Prajna TUI**: Emergency Terminal

### Essential Commands
- `./sa-up` - Boot mesh (16 Containers)
- `./sa-down` - Graceful shutdown + checkpoint
- `./sa-status` - Health matrix (16 Nodes)
- `./sa-plan` - Task management (F# CLI)
- `./sa-verify` - 2oo3 voting verification

## Critical Constraints

### Zero-Defect Invariant (Ω₃)
```
Valid State ⇔ Σ(Errors + Warnings + TestFails + FormatFails + CredoFails + SecFails) = 0
```

### Holon State Sovereignty (Ω₇)
- Authoritative state: SQLite ∪ DuckDB ONLY
- PostgreSQL: business data ONLY
- No PostgreSQL for holon state

### Immutable Register (Ω₈)
- All mutations via cryptographically-signed append-only blocks
- Ed25519 signatures
- Reed-Solomon parity

### Patient Mode (Ω₁)
```
NO_TIMEOUT=true
PATIENT_MODE=enabled
INFINITE_PATIENCE=true
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"
mix compile --jobs 16
```

## Compliance

- **IEC 61508 SIL-6** (Biomorphic Extended)
- **ISO 27001**
- **GDPR**
- **EN 50131**
- **DO-178C DAL-A**

## For Detailed Rules

Read the following files based on your task:
- `@rules/safety-critical.md` - Safety constraints
- `@rules/fractal-coverage-gold-standard.md` - Testing requirements
- `@rules/biomorphic-mode.md` - Biomorphic architecture
- `@rules/swarm-verification.md` - Swarm operations
- `@rules/immune-system.md` - Immune system
- `@rules/journal-protocol.md` - Journaling
- `@rules/test-evolution.md` - Test evolution
- `@rules/zenoh-telemetry-mandatory.md` - Telemetry

Use lazy loading - read files only when needed for the specific task.
