# Indrajaal Unified Intelligence Plane (UIP) Playbook

**Version**: 1.0.0  
**Classification**: SIL-6 Biomorphic Standard Operating Procedure (SOP)  
**Status**: MANDATORY  

## 1. Way of Working (WoW): Neural Speed
The UIP governs the SIL6 lifecycle via high-velocity feedback loops.

### 1.1 The Hardened Verification Cycle (HVC)
1. **Concurrent Probe**: Execute `fsharp-intelligence`, `elixir-intelligence`, and `security-sentry` in parallel.
2. **Formal Simulation**: If logic changes, verify the delta using `formal-oracle` simulation.
3. **Genotype Guard**: Validate YAML invariants before any container actuation.
4. **Jidoka Gate**: 100% pass required on all probes before any `git commit`.

## 2. Hardening Protocols

### 2.1 The "Zero-Divergence" Rule
- **Rule**: Any Divergence Score > 0.05 blocks the OODA loop.
- **Protocol**: If drift is detected, use `env-sentinel` to recalibrate the substrate before fixing code.

### 2.2 The "Neural Link" Rule
- **Rule**: Agents MUST use `zenoh-probe` to verify heartbeat integrity during runtime testing.
- **Mandate**: No "blind" actuation. Every `podman` command must have an associated Zenoh event.

## 3. Decision-Making Optimization
- **Velocity**: OODA cycles for minor fixes must complete in < 30s.
- **Quality**: Probes must provide the "Why" (RCA) alongside the "What" (Error).
- **Simplicity**: Prefer the solution path with the lowest Kolmogorov Complexity ($\min(\mathcal{K})$).

## 5. Omnipresent Intelligence & Debugging
The UIP is active by default in all developer environments via `.envrc`.

### 5.1 Mandatory Debugging Protocol (MDP)
Before executing `mix run`, `mix test`, or `dotnet run`, the agent MUST:
1. **Pulse Check**: Run `uip_command_center --full` to verify substrate homeostasis.
2. **Context Snapshot**: Log the current `DivergenceScore` to the session audit.
3. **Oracle Consultation**: For any runtime exception, use `claude-oracle` to perform a 5-level RCA before attempting a fix.

### 5.2 Automated Diagnostic Pipeline
- **Observation**: Real-time Zenoh telemetry feeds the `zenoh-probe`.
- **Orientation**: `elixir-intelligence` performs AST-checks on modified files.
- **Decision**: Logic verified against the `.qnt` formal spec.
- **Actuation**: Code committed only after 100% UIP Pass.

## 3. Usage Playbook (Standard Commands)

### 3.1 Daily Health Check
```bash
# Verify environment and security baseline
elixir scripts/agents/env_sentinel.exs --audit
elixir scripts/agents/security_sentry.exs --audit
```

### 3.2 Feature Development
1. **Model**: Create/Update `.qnt` in `docs/formal_specs/`.
2. **Verify**: `quint verify --invariant safety_invariant docs/formal_specs/feature.qnt`.
3. **Probe**: `dotnet fsi scripts/agents/fsharp_oracle.fsx lib/path/to/feature.fs`.
4. **Implement**: Apply code changes.

### 3.3 Incident Response (RCA)
1. **Observe**: `elixir scripts/agents/fractal_log_inspector.exs 1` (L1 Audit).
2. **Inspect**: `mix xref graph --format dot` (Check for circular dependency cascades).
3. **Fix**: Apply BVC cycle.

## 4. Safety Governance (STAMP/FMEA)
- **STAMP-WoW-001**: UIP tools MUST be used for every state mutation.
- **FMEA-WoW-001**: Failure of an Oracle (e.g. LSP crash) must result in a manual audit fallback.
