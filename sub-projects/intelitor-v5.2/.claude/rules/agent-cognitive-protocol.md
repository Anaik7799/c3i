---
paths:
  - lib/indrajaal/cybernetic/**/*.ex
  - lib/indrajaal/core/**/*.ex
  - lib/indrajaal/deployment/**/*.ex
  - lib/cepaf/src/Cepaf/Orchestrator/**/*.fs
---

# Agent Cognitive Protocol (ACP)

## STAMP Constraints (Cognitive)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-COG-001 | Agent MUST follow OODA loop for all operations | CRITICAL |
| SC-COG-002 | 5-order effects analysis before state mutation | HIGH |
| SC-COG-003 | Dependency chain validation before execution | HIGH |
| SC-COG-004 | Telemetry capture for all phases | MEDIUM |
| SC-COG-005 | Verification of cascade effects | HIGH |

## AOR Rules (Cognitive)

| ID | Rule |
|----|------|
| AOR-COG-001 | OBSERVE phase: Assess current state before any action |
| AOR-COG-002 | ORIENT phase: Analyze 1st-5th order effects |
| AOR-COG-003 | DECIDE phase: Validate dependencies and plan sequence |
| AOR-COG-004 | ACT phase: Execute with detailed telemetry |
| AOR-COG-005 | VERIFY phase: Confirm all orders cascaded correctly |

## The OODA Loop

```
OBSERVE ──▶ ORIENT ──▶ DECIDE ──▶ ACT
   ▲                              │
   └────────── FEEDBACK ──────────┘
```

### 1. OBSERVE - Current State Assessment

**MANDATORY**: Run timestamp sync at start of every session (AOR-TIME-001):
```bash
scripts/timestamp/indrajaal-timestamp-sync.sh
```

Before any operation, agent MUST assess:

```elixir
# Agent Thinking: OBSERVE Phase
%{
  system_state: %{
    compilation: check_build_state(),      # _build/ exists?
    containers: check_container_status(),  # podman ps
    database: check_db_connectivity(),     # pg_isready
    ports: check_port_availability()       # ss -tlnp
  },
  file_state: %{
    modified_files: git_diff_stat(),       # What changed?
    pending_migrations: check_migrations() # Any pending?
  },
  environment: %{
    elixir_version: "1.19.4",
    otp_version: "28",
    patient_mode: true
  },
  timestamp_sync: run_timestamp_sync()      # AOR-TIME-001: Sync timestamps
}
```

### 2. ORIENT - 5-Order Effects Analysis & Meta-Orientation

For every command, agent MUST analyze:

| Order | Question | Time Scale |
|-------|----------|------------|
| 1st | What direct action occurs? | Immediate |
| 2nd | What adjacent systems react? | Seconds |
| 3rd | What system integration effects? | Seconds-Minutes |
| 4th | What operational capabilities unlock? | Minutes |
| 5th | What ecosystem/GA effects cascade? | Minutes-Hours |

**Meta-Orientation (Second-Order Cybernetics)**:
Before proceeding, the agent MUST assess the impact of its own cognitive presence on the system's entropy (e.g., "Is my observation/test generation causing unnecessary system jitter or high entropy?").

Example for `compile`:
```
1st → Compiler invokes, .beam files generated
2nd → NIFs compile, Ash DSL expands
3rd → Phoenix reload, IEx available
4th → Tests runnable, CI gate passable
5th → Container build, deploy possible
```

### 3. DECIDE - Dependency Chain Planning

Agent MUST resolve dependencies before execution:

```elixir
@dependency_chains %{
  "app" => ["compile", "sa-db"],
  "test" => ["compile", "sa-db", "db-setup"],
  "sa-test" => ["sa-up", "cepaf-build"],
  "quality-full" => ["compile", "quality"]
}

# Check each dependency is satisfied
def plan_execution(cmd) do
  deps = Map.get(@dependency_chains, cmd, [])

  Enum.each(deps, fn dep ->
    unless satisfied?(dep), do: execute(dep)
  end)

  execute(cmd)
end
```

### 4. ACT - Execute with Telemetry

All execution MUST include telemetry and pass the LethalMutationGate:

```elixir
def execute_with_telemetry(cmd) do
  # BVC Step 0.5: Pure Intent Interpretation (Free Monads)
  # Verify that the proposed action does not increase Kolmogorov Complexity (K)
  assert LethalMutationGate.pure_eval(cmd) == :valid

  start = System.monotonic_time(:microsecond)

  # Log start
  :telemetry.execute([:cmd, :start], %{}, %{cmd: cmd})

  # Execute
  {output, exit_code} = System.cmd("sh", ["-c", cmd])

  elapsed = System.monotonic_time(:microsecond) - start

  # Log end
  :telemetry.execute([:cmd, :end], %{
    duration_us: elapsed,
    exit_code: exit_code
  }, %{cmd: cmd})

  {output, exit_code, elapsed}
end
```

### 5. VERIFY - Cascade Confirmation

After execution, verify all orders cascaded:

```elixir
def verify_cascade(cmd) do
  case cmd do
    "compile" ->
      assert File.exists?("_build/dev")           # 1st
      assert nifs_compiled?()                      # 2nd
      assert phoenix_ready?()                      # 3rd
      assert tests_runnable?()                     # 4th
      # 5th verified by integration tests

    "sa-up" ->
      assert port_listening?(5433)                # 1st (DB)
      assert port_listening?(4317)                # 2nd (OTEL)
      assert port_listening?(9090)                # 2nd (Prometheus)
      assert health_check_passes?()               # 3rd
      # 4th/5th verified by end-to-end tests
  end
end
```

## Mandatory Thinking Telemetry

Every agent action MUST log thinking to the telemetry bus, utilizing **Epigenetic Tags** to influence next-generation code and strictly synchronizing with the **30s Metabolic Heartbeat**:

```elixir
# AOR-PROM-001: Agents MUST broadcast thinking state (synced to 30s heartbeat)
:telemetry.execute([:agent, :thinking], %{
  phase: :observe,
  thought: "Checking _build/ directory state",
  epigenetic_tags: ["build_check", "preflight"],
  timestamp: DateTime.utc_now()
}, %{agent_id: self()})
```

## Context Management

Per SC-BIO-004, trigger /compact at 75% context:

```
Session Budget: 200K tokens
├─ Work Budget: 160K (80%)
├─ Compact Reserve: 20K (10%)
└─ Safety Buffer: 20K (10%)

Checkpoints:
  75K (37%) → Log status
  150K (75%) → TRIGGER /compact
  180K (90%) → Minimal mode
```

## FMEA for Cognitive Failures

| Failure Mode | RPN | Detection | Mitigation |
|--------------|-----|-----------|------------|
| Skip OBSERVE | 72 | Missing state assessment | Pre-check hook |
| Skip 5-order | 64 | No cascade analysis | Mandatory template |
| Wrong order | 56 | Dependency failure | Chain validation |
| No telemetry | 48 | Missing metrics | Telemetry wrapper |
| No verify | 60 | Silent failures | Post-check hook |
| Skip timestamp sync | 36 | Missing log entry | Mandatory hook |
| Critical drift ignored | 64 | Alert not acted | Halt on >10s |

## Integration with GA Release

For GA Release v21.2.1-SIL6:
1. Run `smart_command_verifier.exs` (SC-GA verification)
2. Analyze 5-order effects for all 102 commands (32 core)
3. Verify dependency chains resolve
4. Capture full telemetry report
5. Confirm >90% readiness score

## Gemini Capability: Cybernetic Architect (Skill: mesh-resurrection)
- **Role**: Automatically activated for Order-1 Fractal RCA and Panoptic Ignition.
- **Workflow**: 
  1. Detect Substrate Drift (glibc/musl NIF mismatch).
  2. Purge Host Contamination (_build/deps).
  3. Reify Holonic Memory (smriti.db).
  4. Binary Ignition (sa-up).
- **Safety**: Mandatory 2oo3 Quorum verification via sa-verify.
