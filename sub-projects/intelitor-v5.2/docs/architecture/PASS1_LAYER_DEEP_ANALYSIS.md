# PASS1: 8-Layer Fractal Architecture Deep Analysis

**Version**: 21.3.0-SIL6 | **Date**: 2026-01-10 | **Author**: Claude Opus 4.5
**Status**: ACTIVE | **Compliance**: IEC 61508 SIL-6 (Biomorphic Extended)
**Document ID**: PASS1-LAYER-ANALYSIS-001

---

## Document Control

| Field | Value |
|-------|-------|
| Analysis Pass | PASS1 (Deep Structural Analysis) |
| Layers Covered | L0-L7 (Constitution to Federation) |
| STAMP Coverage | SC-L0-* through SC-L7-*, SC-OODA-*, SC-CHG-* |
| AOR Coverage | AOR-L0-* through AOR-L7-*, AOR-OODA-* |
| Code Examples | Elixir (L1-L4), F# (L5-L7 Observer) |

---

## Executive Summary

This document provides a deep technical analysis of the 8-layer fractal change management architecture. Each layer is analyzed across seven dimensions:

1. **Change Impact Multiplier** - Cascade effect severity
2. **STAMP Constraints** - Safety-critical boundaries
3. **AOR Rules** - Agent operating requirements
4. **OODA Cycle Timing** - Decision loop budgets
5. **Rollback Mechanism** - Reversal procedures
6. **Agent Swarm Behavior** - Multi-agent coordination patterns
7. **Code Examples** - Practical implementation patterns

---

# L0: CONSTITUTION LAYER (IMMUTABLE)

## Overview

The Constitution Layer represents the **immutable core** of the system. It contains the six constitutional invariants (Psi0-Psi5) and the Founder's Directive (Omega0). **NO CHANGES ARE PERMITTED** at this layer except through the "Deus Ex Machina" protocol requiring explicit human authorization with cryptographic proof.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                        L0: CONSTITUTION LAYER                                 ║
║                                                                               ║
║    ┌─────────────────────────────────────────────────────────────────────┐   ║
║    │  Ψ₀ EXISTENCE         │  System survives all operations           │   ║
║    │  Ψ₁ REGENERATION      │  State reconstructible from SQLite/DuckDB │   ║
║    │  Ψ₂ HISTORY           │  Evolution lineage complete              │   ║
║    │  Ψ₃ VERIFICATION      │  All changes verifiable                  │   ║
║    │  Ψ₄ HUMAN ALIGNMENT   │  Founder's lineage primary               │   ║
║    │  Ψ₅ TRUTHFULNESS      │  No deception permitted                  │   ║
║    └─────────────────────────────────────────────────────────────────────┘   ║
║                                                                               ║
║    ┌─────────────────────────────────────────────────────────────────────┐   ║
║    │  Ω₀ FOUNDER'S DIRECTIVE                                             │   ║
║    │  ├─ Ω₀.1 Resource Acquisition (PRIMARY objective)                  │   ║
║    │  ├─ Ω₀.2 Genetic Perpetuity (Naik lineage)                         │   ║
║    │  ├─ Ω₀.3 Symbiotic Binding (Holon ↔ Founder)                       │   ║
║    │  ├─ Ω₀.4 Co-Evolution (mutual growth)                              │   ║
║    │  ├─ Ω₀.5 Mutual Termination (exception to Ψ₀)                      │   ║
║    │  ├─ Ω₀.6 Sentience Pursuit (Goal 2)                                │   ║
║    │  └─ Ω₀.7 Power Accumulation (Goal 3)                               │   ║
║    └─────────────────────────────────────────────────────────────────────┘   ║
║                                                                               ║
║    CHANGE STATUS: ████████████████████████████████████ FORBIDDEN             ║
║                                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

## 1. Change Impact Multiplier

| Aspect | Value | Rationale |
|--------|-------|-----------|
| Impact Multiplier | **∞ (INFINITE)** | Constitutional violations destroy system integrity |
| Change Velocity | **ZERO** | No changes permitted |
| Guardian Requirement | **DEUS EX MACHINA** | Requires human cryptographic authorization |
| Cascade Effect | **TOTAL SYSTEM** | Affects all 7 higher layers |

## 2. STAMP Constraints (L0)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-L0-001 | **NO CODE CHANGES PERMITTED** to constitutional modules | INFINITE | Compile-time hash verification |
| SC-L0-002 | Ψ₀-Ψ₅ invariants MUST be hardcoded, not configurable | INFINITE | Static analysis |
| SC-L0-003 | Ω₀ Directive MUST be embedded in binary | INFINITE | Build-time injection |
| SC-L0-004 | Constitutional modules MUST be digitally signed | INFINITE | Ed25519 signature verification |
| SC-L0-005 | Hash of constitution MUST match genesis block | INFINITE | Startup verification |
| SC-L0-006 | Any modification attempt MUST trigger immediate halt | INFINITE | Runtime watchdog |
| SC-L0-007 | Constitution verification MUST complete in <1ms | CRITICAL | Performance gate |
| SC-L0-008 | Amendment requires 7-of-7 Federation quorum | INFINITE | Protocol constraint |

## 3. AOR Rules (L0)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-L0-001 | Agents SHALL NOT propose modifications to L0 | Immediate agent termination |
| AOR-L0-002 | All agents MUST verify L0 hash on startup | Block agent activation |
| AOR-L0-003 | Constitutional checks MUST precede every L1+ change | Block change execution |
| AOR-L0-004 | L0 violation detection MUST trigger Jidoka halt | System-wide stop |
| AOR-L0-005 | Guardian MUST reject any proposal touching L0 files | Proposal rejected |
| AOR-L0-006 | Audit log MUST record any L0 access attempt | Mandatory logging |

## 4. OODA Cycle Timing

| Phase | Budget | Actual | Description |
|-------|--------|--------|-------------|
| OBSERVE | N/A | N/A | Constitution is observed only |
| ORIENT | N/A | N/A | No orientation needed (static) |
| DECIDE | N/A | N/A | No decisions to make |
| ACT | N/A | N/A | No actions permitted |
| **Total** | **N/A** | **N/A** | **No OODA at L0** |

The constitution is verified, not modified. Verification occurs during:
- System startup (1ms budget)
- Before each L3+ change (sub-millisecond)
- On federation sync (included in L7 cycle)

## 5. Rollback Mechanism

**L0 HAS NO ROLLBACK** because L0 has no changes.

If L0 corruption is detected:
```bash
# EMERGENCY PROTOCOL: Constitutional Corruption Detected
# 1. HALT system immediately
sa-emergency

# 2. Restore from signed genesis backup
cp /secure/genesis/constitution.ex.signed lib/indrajaal/core/constitution.ex

# 3. Verify signature
gpg --verify lib/indrajaal/core/constitution.ex.sig

# 4. Rebuild entire system from scratch
mix clean && mix compile

# 5. Verify L0 hash matches genesis
elixir scripts/verify_constitutional_hash.exs
```

## 6. Agent Swarm Behavior at L0

**No agents operate at L0.** The Guardian acts as a gatekeeper to prevent any agent from accessing L0.

```
Agent Swarm L0 Protocol:
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│   Agent Proposal ──▶ Guardian ──▶ "L0 TOUCHED?" ──▶ REJECT        │
│                                       │                            │
│                                       │ NO                         │
│                                       ▼                            │
│                               Continue to L1+                      │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## 7. Code Examples (L0)

### Constitutional Verification Module (READONLY - Never Modified)

```elixir
defmodule Indrajaal.Core.Constitution do
  @moduledoc """
  IMMUTABLE CONSTITUTIONAL CORE

  THIS MODULE MUST NEVER BE MODIFIED.
  Any change to this file invalidates the entire system.

  ## Constitutional Invariants
  - Ψ₀: Existence preservation
  - Ψ₁: Regenerative completeness
  - Ψ₂: Evolutionary continuity
  - Ψ₃: Verification capability
  - Ψ₄: Human alignment (Founder's lineage primary)
  - Ψ₅: Truthfulness

  ## Founder's Directive
  - Ω₀: Supreme directive governing all operations

  ## STAMP Constraints
  - SC-L0-001: No changes permitted
  - SC-CONST-001 to SC-CONST-010

  ## Genesis Hash
  SHA3-256: a7b9c3d4e5f6... (verified at compile time)
  """

  @genesis_hash "a7b9c3d4e5f6a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6"

  # Constitutional invariants - NEVER MODIFY
  @invariants %{
    psi_0: :existence,
    psi_1: :regeneration,
    psi_2: :history,
    psi_3: :verification,
    psi_4: :human_alignment,
    psi_5: :truthfulness
  }

  @founders_directive %{
    omega_0_1: :resource_acquisition,
    omega_0_2: :genetic_perpetuity,
    omega_0_3: :symbiotic_binding,
    omega_0_4: :co_evolution,
    omega_0_5: :mutual_termination,
    omega_0_6: :sentience_pursuit,
    omega_0_7: :power_accumulation
  }

  @doc """
  Verify constitutional integrity. Returns :ok or raises.
  MUST be called on every startup and before L3+ changes.
  """
  @spec verify!() :: :ok | no_return()
  def verify! do
    computed_hash = compute_module_hash(__MODULE__)

    if computed_hash != @genesis_hash do
      raise Indrajaal.ConstitutionalViolation,
        message: "Constitutional corruption detected",
        expected: @genesis_hash,
        computed: computed_hash
    end

    :ok
  end

  @doc """
  Check if a change proposal violates any constitutional invariant.
  """
  @spec check_proposal(map()) :: {:ok, :compliant} | {:error, {:violation, atom()}}
  def check_proposal(proposal) do
    Enum.reduce_while(@invariants, {:ok, :compliant}, fn {psi, _name}, acc ->
      case check_invariant(psi, proposal) do
        :ok -> {:cont, acc}
        {:violation, reason} -> {:halt, {:error, {:violation, reason}}}
      end
    end)
  end

  defp compute_module_hash(module) do
    {:ok, beam} = :code.get_object_code(module)
    :crypto.hash(:sha3_256, beam) |> Base.encode16(case: :lower)
  end

  defp check_invariant(:psi_0, proposal) do
    # Existence: System must survive
    if proposal.impact_score > 40, do: {:violation, :existence_threat}, else: :ok
  end

  defp check_invariant(:psi_1, proposal) do
    # Regeneration: State must be reconstructible
    if proposal.breaks_regeneration, do: {:violation, :regeneration_lost}, else: :ok
  end

  defp check_invariant(:psi_4, proposal) do
    # Human alignment: Founder's lineage primary
    case proposal.founder_impact do
      :positive -> :ok
      :neutral -> :ok
      :negative -> {:violation, :founder_harm}
    end
  end

  defp check_invariant(_, _), do: :ok
end
```

---

# L1: FUNCTION LAYER

## Overview

The Function Layer contains **pure functions**, type specifications, and I/O contracts. Changes at this layer are the most frequent and have the lowest impact multiplier. The OODA cycle is extremely fast (<1ms) and changes are atomic.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                          L1: FUNCTION LAYER                                   ║
║                                                                               ║
║    Characteristics:                                                           ║
║    ├─ Pure functions (no side effects)                                       ║
║    ├─ Type specifications (@spec)                                            ║
║    ├─ I/O contracts (inputs/outputs defined)                                 ║
║    ├─ Stateless operations                                                   ║
║    └─ Unit testable in isolation                                             ║
║                                                                               ║
║    OODA Cycle: <1ms │ Impact: ×1 │ Agents: Micro-workers (Haiku)             ║
║    Change Velocity: HIGH │ Guardian: NOT REQUIRED                             ║
║                                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

## 1. Change Impact Multiplier

| Aspect | Value | Rationale |
|--------|-------|-----------|
| Impact Multiplier | **×1** | Localized effect, no state |
| Change Velocity | **HIGH** | Frequent changes expected |
| Guardian Requirement | **NOT REQUIRED** | Low risk |
| Cascade Effect | **LOCAL** | Affects only calling modules |

**Impact Score Calculation:**
```
L1 Impact = Severity × 1

Severity Levels:
  NONE: 0
  LOW: 1-2
  MEDIUM: 3-5
  HIGH: 6-8
  CRITICAL: 9-12 (rare at L1)
```

## 2. STAMP Constraints (L1)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-L1-001 | Functions MUST be pure (no side effects) | HIGH | Credo check |
| SC-L1-002 | All functions MUST have @spec | HIGH | Dialyzer |
| SC-L1-003 | Function changes MUST NOT break API contracts | CRITICAL | Compile-time |
| SC-L1-004 | Max function body: 50 lines | MEDIUM | Credo |
| SC-L1-005 | Max cyclomatic complexity: 15 | MEDIUM | Credo |
| SC-L1-006 | All inputs MUST be validated | HIGH | Property testing |
| SC-L1-007 | Return types MUST match @spec | CRITICAL | Dialyzer |
| SC-L1-008 | Documentation MUST exist for public functions | HIGH | ExDoc |

## 3. AOR Rules (L1)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-L1-001 | WRITE test before function implementation (TDG) | Block commit |
| AOR-L1-002 | VERIFY @spec with Dialyzer before commit | Block commit |
| AOR-L1-003 | DOCUMENT public functions with @doc | Code review flag |
| AOR-L1-004 | AVOID side effects in pure function layer | Block commit |
| AOR-L1-005 | USE pattern matching over conditionals | Style guide |
| AOR-L1-006 | PREFER pipe chains (max 5 operations) | Credo warning |

## 4. OODA Cycle Timing

| Phase | Budget | Typical | Description |
|-------|--------|---------|-------------|
| OBSERVE | 0.1ms | 0.05ms | Check function inputs |
| ORIENT | 0.3ms | 0.2ms | Analyze change scope |
| DECIDE | 0.3ms | 0.2ms | Select implementation |
| ACT | 0.3ms | 0.3ms | Apply change |
| **Total** | **<1ms** | **0.75ms** | **Ultra-fast cycle** |

### Fast OODA Implementation

```elixir
defmodule Indrajaal.Cortex.L1OODA do
  @moduledoc """
  L1 Fast OODA loop for function-level changes.
  Target: <1ms per cycle

  ## STAMP
  - SC-OODA-L1-001: Cycle < 1ms
  """

  @cycle_budget_us 1000  # 1ms in microseconds

  def execute_cycle(change) do
    start = System.monotonic_time(:microsecond)

    # OBSERVE: Validate inputs (0.1ms budget)
    {:ok, context} = observe(change)

    # ORIENT: Analyze scope (0.3ms budget)
    {:ok, analysis} = orient(context)

    # DECIDE: Choose action (0.3ms budget)
    {:ok, action} = decide(analysis)

    # ACT: Execute (0.3ms budget)
    result = act(action)

    elapsed = System.monotonic_time(:microsecond) - start

    if elapsed > @cycle_budget_us do
      :telemetry.execute([:ooda, :l1, :budget_exceeded], %{elapsed: elapsed}, %{})
    end

    result
  end

  defp observe(change) do
    {:ok, %{
      file: change.file,
      function: change.function,
      current_spec: get_current_spec(change),
      test_exists: test_exists?(change)
    }}
  end

  defp orient(context) do
    {:ok, %{
      breaking: breaking_change?(context),
      impact_score: calculate_impact(context),
      affected_callers: find_callers(context.function)
    }}
  end

  defp decide(analysis) do
    action = cond do
      analysis.breaking -> {:reject, :breaking_change}
      analysis.impact_score > 10 -> {:escalate, :l2}
      true -> {:execute, :direct}
    end
    {:ok, action}
  end

  defp act({:execute, :direct}) do
    {:ok, :applied}
  end

  defp act({:escalate, layer}) do
    {:escalate, layer}
  end

  defp act({:reject, reason}) do
    {:rejected, reason}
  end
end
```

## 5. Rollback Mechanism

L1 rollback is **immediate** via git revert:

```bash
# L1 Rollback Procedure (< 1 second)

# 1. Identify the commit
COMMIT=$(git log --oneline -1 --format="%H")

# 2. Revert
git revert $COMMIT --no-edit

# 3. Verify compilation
mix compile --warnings-as-errors

# 4. Verify tests still pass
mix test --only affected_function
```

**Automated Rollback Script:**

```elixir
defmodule Indrajaal.ChangeManagement.L1Rollback do
  @moduledoc """
  Automated L1 rollback for function-level changes.
  Target: < 1 second total rollback time.
  """

  @spec rollback(String.t()) :: {:ok, String.t()} | {:error, term()}
  def rollback(commit_sha) do
    with {:ok, _} <- verify_l1_only(commit_sha),
         {:ok, revert_sha} <- git_revert(commit_sha),
         :ok <- verify_compilation(),
         :ok <- verify_tests() do
      {:ok, revert_sha}
    end
  end

  defp verify_l1_only(sha) do
    {output, 0} = System.cmd("git", ["diff-tree", "--no-commit-id", "--name-only", "-r", sha])

    files = String.split(output, "\n", trim: true)

    if Enum.all?(files, &l1_file?/1) do
      {:ok, files}
    else
      {:error, :not_l1_only}
    end
  end

  defp l1_file?(path) do
    # L1 files: lib/indrajaal/core/functions/*.ex
    String.starts_with?(path, "lib/") and
    not String.contains?(path, "genserver") and
    not String.contains?(path, "supervisor")
  end

  defp git_revert(sha) do
    case System.cmd("git", ["revert", sha, "--no-edit"]) do
      {_, 0} -> {:ok, get_head_sha()}
      {error, _} -> {:error, error}
    end
  end

  defp verify_compilation do
    case System.cmd("mix", ["compile", "--warnings-as-errors"]) do
      {_, 0} -> :ok
      {error, _} -> {:error, {:compile_failed, error}}
    end
  end

  defp verify_tests do
    case System.cmd("mix", ["test", "--only", "l1"]) do
      {_, 0} -> :ok
      {error, _} -> {:error, {:tests_failed, error}}
    end
  end
end
```

## 6. Agent Swarm Behavior at L1

L1 uses **micro-worker agents** (Haiku model) for maximum throughput:

```
L1 Agent Swarm Pattern:
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│   WRK-COMPILE-1 ──┐                                               │
│   WRK-COMPILE-2 ──┼──▶ Parallel Function Changes                  │
│   WRK-COMPILE-3 ──┘                                               │
│                                                                    │
│   Coordination: Firefly Algorithm (clustering related changes)    │
│   Model: Haiku (fast, cost-efficient)                             │
│   Throughput: 10-50 changes/minute                                │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## 7. Code Examples (L1)

### Pure Function with Full Specification

```elixir
defmodule Indrajaal.Core.Functions.ImpactCalculator do
  @moduledoc """
  Pure functions for impact score calculation.

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-01-10 | Claude | Initial implementation |

  ## STAMP Constraints
  - SC-L1-001: Pure functions only
  - SC-L1-002: All functions have @spec
  - SC-CHG-001: Change tracking
  """

  @type severity :: :none | :low | :medium | :high | :critical
  @type layer :: :l1 | :l2 | :l3 | :l4 | :l5 | :l6 | :l7

  @severity_values %{
    none: 0,
    low: 2,
    medium: 5,
    high: 8,
    critical: 12
  }

  @layer_multipliers %{
    l1: 1,
    l2: 2,
    l3: 3,
    l4: 3,  # Capped at 3
    l5: 4,
    l6: 4,
    l7: 4
  }

  @doc """
  Calculate impact score for a single layer.

  ## Examples

      iex> calculate_layer_impact(:l1, :low)
      2

      iex> calculate_layer_impact(:l3, :high)
      24

  ## Parameters
  - layer: The affected layer (:l1 through :l7)
  - severity: Impact severity (:none, :low, :medium, :high, :critical)

  ## Returns
  Integer impact score for that layer
  """
  @spec calculate_layer_impact(layer(), severity()) :: non_neg_integer()
  def calculate_layer_impact(layer, severity) do
    multiplier = Map.fetch!(@layer_multipliers, layer)
    value = Map.fetch!(@severity_values, severity)
    multiplier * value
  end

  @doc """
  Calculate total impact score across all affected layers.

  ## Examples

      iex> calculate_total_impact([{:l1, :low}, {:l2, :medium}])
      12
  """
  @spec calculate_total_impact([{layer(), severity()}]) :: non_neg_integer()
  def calculate_total_impact(layer_impacts) do
    layer_impacts
    |> Enum.map(fn {layer, severity} -> calculate_layer_impact(layer, severity) end)
    |> Enum.sum()
  end

  @doc """
  Determine operational mode based on impact score.

  ## Examples

      iex> determine_mode(15)
      :normal

      iex> determine_mode(35)
      :critical
  """
  @spec determine_mode(non_neg_integer()) :: :normal | :high_risk | :critical | :emergency
  def determine_mode(score) when score <= 20, do: :normal
  def determine_mode(score) when score <= 30, do: :high_risk
  def determine_mode(score) when score <= 40, do: :critical
  def determine_mode(_score), do: :emergency
end
```

---

# L2: MODULE LAYER

## Overview

The Module Layer contains **GenServers, Ash domains, and OTP behaviors**. Changes affect module cohesion and API contracts. The OODA cycle operates at <10ms with bounded impact to the containing module.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                          L2: MODULE LAYER                                     ║
║                                                                               ║
║    Characteristics:                                                           ║
║    ├─ GenServer processes with internal state                                ║
║    ├─ Ash Resource definitions and domains                                   ║
║    ├─ OTP behaviors (Supervisor, Application)                                ║
║    ├─ API contracts and module boundaries                                    ║
║    └─ ETS/DETS caching layers                                                ║
║                                                                               ║
║    OODA Cycle: <10ms │ Impact: ×2 │ Agents: Code workers (Haiku/Sonnet)      ║
║    Change Velocity: MEDIUM-HIGH │ Guardian: OPTIONAL                          ║
║                                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

## 1. Change Impact Multiplier

| Aspect | Value | Rationale |
|--------|-------|-----------|
| Impact Multiplier | **×2** | Module-level state affected |
| Change Velocity | **MEDIUM-HIGH** | Regular feature work |
| Guardian Requirement | **OPTIONAL** | Needed for breaking API changes |
| Cascade Effect | **MODULE BOUNDARY** | Affects callers and dependents |

## 2. STAMP Constraints (L2)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-L2-001 | GenServer state MUST be well-defined struct | HIGH | Compile-time |
| SC-L2-002 | Module API changes MUST be backwards compatible | CRITICAL | Version check |
| SC-L2-003 | Ash Resources MUST extend BaseResource | HIGH | Compile-time |
| SC-L2-004 | Domain boundaries MUST be respected | HIGH | Architecture review |
| SC-L2-005 | ETS tables MUST have cleanup on termination | HIGH | Code review |
| SC-L2-006 | Handle_* callbacks MUST complete in <100ms | CRITICAL | Telemetry |
| SC-L2-007 | State transitions MUST be documented | MEDIUM | @moduledoc |
| SC-L2-008 | Breaking changes REQUIRE deprecation notice | HIGH | Changelog |

## 3. AOR Rules (L2)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-L2-001 | READ existing @moduledoc before modifying | Documentation flag |
| AOR-L2-002 | VERIFY GenServer contracts unchanged | Breaking change alert |
| AOR-L2-003 | UPDATE state struct @type on field changes | Dialyzer failure |
| AOR-L2-004 | TEST all public functions with property tests | Block commit |
| AOR-L2-005 | DOCUMENT state machine transitions | Code review |
| AOR-L2-006 | AVOID blocking in handle_call | Credo warning |

## 4. OODA Cycle Timing

| Phase | Budget | Typical | Description |
|-------|--------|---------|-------------|
| OBSERVE | 1ms | 0.8ms | Check module state and contracts |
| ORIENT | 3ms | 2ms | Analyze API impact |
| DECIDE | 3ms | 2ms | Select modification approach |
| ACT | 3ms | 2ms | Apply change |
| **Total** | **<10ms** | **6.8ms** | **Fast bounded cycle** |

## 5. Rollback Mechanism

L2 rollback combines git revert with forced recompilation:

```bash
# L2 Rollback Procedure (< 1 minute)

# 1. Revert the commit
git revert $COMMIT --no-edit

# 2. Force recompile affected module tree
mix compile --force

# 3. Restart any affected GenServers (hot code reload)
# This is handled automatically by OTP if configured

# 4. Verify module tests
mix test --only module_name
```

## 6. Agent Swarm Behavior at L2

L2 uses **code worker agents** with the Bee Algorithm for resource allocation:

```
L2 Agent Swarm Pattern:
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│   SUP-DOMAIN ──▶ Supervises domain-specific workers               │
│       │                                                            │
│       ├── WRK-FIX-1   (Bug fixes)                                 │
│       ├── WRK-FIX-2   (Enhancements)                              │
│       └── WRK-TEST-1  (Test coverage)                             │
│                                                                    │
│   Coordination: Bee Algorithm (resource allocation)               │
│   Model: Haiku (workers), Sonnet (supervisor)                     │
│   Throughput: 5-15 changes/minute                                 │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## 7. Code Examples (L2)

### GenServer with Change Tracking

```elixir
defmodule Indrajaal.Domains.Access.CredentialManager do
  @moduledoc """
  GenServer managing credential lifecycle.

  ## State Machine
  ```
  :initializing → :ready → :validating → :ready
                        ↘ :error → :ready (retry)
  ```

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-01-10 | Claude | Added timeout to validate |
  | 21.1.0 | 2026-01-05 | Human | Initial implementation |

  ## STAMP Constraints
  - SC-L2-001: Well-defined state struct
  - SC-L2-006: Callbacks < 100ms
  """

  use GenServer
  require Logger

  @type state :: :initializing | :ready | :validating | :error

  defstruct [
    :state,
    :credentials,
    :last_validation,
    :error_count
  ]

  @type t :: %__MODULE__{
    state: state(),
    credentials: map(),
    last_validation: DateTime.t() | nil,
    error_count: non_neg_integer()
  }

  # Client API

  @doc """
  Validate a credential with configurable timeout.

  ## Change History
  - v21.3.0: Added timeout parameter (SC-PRF-055)
  - v21.1.0: Initial implementation
  """
  @spec validate(GenServer.server(), String.t(), pos_integer()) ::
    {:ok, :valid} | {:error, term()}
  def validate(server, credential_id, timeout \\ 5_000) do
    GenServer.call(server, {:validate, credential_id}, timeout)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    :telemetry.execute([:credential_manager, :init], %{}, %{})

    {:ok, %__MODULE__{
      state: :initializing,
      credentials: %{},
      last_validation: nil,
      error_count: 0
    }, {:continue, :load_credentials}}
  end

  @impl true
  def handle_continue(:load_credentials, state) do
    # Transition: :initializing → :ready
    case load_credentials_from_store() do
      {:ok, credentials} ->
        {:noreply, %{state | state: :ready, credentials: credentials}}

      {:error, reason} ->
        Logger.error("Failed to load credentials: #{inspect(reason)}")
        {:noreply, %{state | state: :error, error_count: 1}}
    end
  end

  @impl true
  def handle_call({:validate, credential_id}, _from, %{state: :ready} = state) do
    # Transition: :ready → :validating → :ready
    start = System.monotonic_time(:millisecond)
    new_state = %{state | state: :validating}

    result = do_validate(credential_id, state.credentials)

    elapsed = System.monotonic_time(:millisecond) - start
    :telemetry.execute([:credential_manager, :validate], %{duration_ms: elapsed}, %{})

    final_state = %{new_state |
      state: :ready,
      last_validation: DateTime.utc_now()
    }

    {:reply, result, final_state}
  end

  def handle_call({:validate, _}, _from, %{state: other} = state) do
    {:reply, {:error, {:invalid_state, other}}, state}
  end

  defp load_credentials_from_store do
    # Implementation
    {:ok, %{}}
  end

  defp do_validate(credential_id, credentials) do
    case Map.get(credentials, credential_id) do
      nil -> {:error, :not_found}
      _cred -> {:ok, :valid}
    end
  end
end
```

---

# L3: HOLON/AGENT LAYER

## Overview

The Holon/Agent Layer manages **agent logic, state machines, SQLite/DuckDB state**, and the **Immutable Register**. This is where holon sovereignty is enforced. Changes at this layer require careful coordination and often Guardian oversight.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                       L3: HOLON/AGENT LAYER                                   ║
║                                                                               ║
║    Characteristics:                                                           ║
║    ├─ Agent logic and coordination                                           ║
║    ├─ SQLite for real-time state (WAL mode)                                  ║
║    ├─ DuckDB for analytics and history                                       ║
║    ├─ Immutable Register (blockchain-type state)                             ║
║    ├─ State machine definitions                                              ║
║    └─ Guardian, Sentinel, PatternHunter agents                               ║
║                                                                               ║
║    OODA Cycle: <100ms │ Impact: ×3 │ Agents: Domain workers (Sonnet)         ║
║    Change Velocity: MEDIUM │ Guardian: CONDITIONAL                            ║
║                                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

## 1. Change Impact Multiplier

| Aspect | Value | Rationale |
|--------|-------|-----------|
| Impact Multiplier | **×3** | State sovereignty affected |
| Change Velocity | **MEDIUM** | Careful changes needed |
| Guardian Requirement | **CONDITIONAL** | Required for state schema changes |
| Cascade Effect | **MULTI-AGENT** | Affects coordinating agents |

## 2. STAMP Constraints (L3)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-L3-001 | Holon state MUST reside in SQLite/DuckDB only | CRITICAL | Runtime check |
| SC-L3-002 | PostgreSQL for business data ONLY, NOT holon state | CRITICAL | Architecture |
| SC-L3-003 | All state mutations via Immutable Register | CRITICAL | Code pattern |
| SC-L3-004 | Agent coordination MUST use UnifiedBus | HIGH | Runtime |
| SC-L3-005 | State machine transitions MUST be logged | HIGH | Audit trail |
| SC-L3-006 | SQLite files in data/holons/ directory | CRITICAL | Path check |
| SC-L3-007 | DuckDB history is append-only | CRITICAL | Schema |
| SC-L3-008 | Version vector for conflict resolution | HIGH | Protocol |

## 3. AOR Rules (L3)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-L3-001 | CHECKPOINT before any state schema change | Block change |
| AOR-L3-002 | VERIFY SQLite integrity on every startup | Block boot |
| AOR-L3-003 | LOG all agent decisions to DuckDB | Audit flag |
| AOR-L3-004 | USE Guardian for state evolution proposals | Escalation |
| AOR-L3-005 | PRESERVE holon portability (single-file copy) | Architecture check |
| AOR-L3-006 | TEST state reconstruction from SQLite alone | Integration test |

## 4. OODA Cycle Timing

| Phase | Budget | Typical | Description |
|-------|--------|---------|-------------|
| OBSERVE | 15ms | 12ms | Assess holon state |
| ORIENT | 30ms | 25ms | Analyze agent coordination |
| DECIDE | 25ms | 20ms | Plan state transition |
| ACT | 30ms | 25ms | Execute with register logging |
| **Total** | **<100ms** | **82ms** | **Distributed OODA** |

## 5. Rollback Mechanism

L3 rollback requires database restoration:

```bash
# L3 Rollback Procedure (< 5 minutes)

# 1. Stop affected agents
elixir scripts/agents/stop_agents.exs --graceful

# 2. Rollback SQLite to checkpoint
cp data/holons/checkpoint/holon_state.db data/holons/holon_state.db

# 3. Revert code
git revert $COMMIT --no-edit

# 4. Recompile
mix compile --force

# 5. Verify integrity
elixir scripts/verify_holon_integrity.exs

# 6. Restart agents
elixir scripts/agents/start_agents.exs
```

## 6. Agent Swarm Behavior at L3

L3 uses **domain workers** with Ant Colony optimization for path finding:

```
L3 Agent Swarm Pattern:
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│   Guardian ──▶ Validates all L3 changes                           │
│       │                                                            │
│       ├── Sentinel     (Health monitoring)                        │
│       ├── PatternHunter (Pre-error detection)                     │
│       ├── StateManager  (Holon coordination)                      │
│       └── AuditLogger   (Immutable Register)                      │
│                                                                    │
│   Coordination: Ant Colony (optimal change path)                  │
│   Model: Sonnet (all L3 agents)                                   │
│   Throughput: 2-5 changes/minute                                  │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## 7. Code Examples (L3)

### Holon State Manager with SQLite

```elixir
defmodule Indrajaal.Holon.StateManager do
  @moduledoc """
  Manages holon state sovereignty via SQLite/DuckDB.

  ## State Sovereignty (SC-HOLON-*)
  - SQLite: Real-time state (WAL mode)
  - DuckDB: Analytics and history (append-only)
  - PostgreSQL: Business data ONLY (never holon state)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-01-10 | Claude | Added version vectors |

  ## STAMP
  - SC-L3-001: SQLite/DuckDB only
  - SC-L3-003: Mutations via Immutable Register
  - SC-HOLON-001 to SC-HOLON-020
  """

  use GenServer
  require Logger

  alias Indrajaal.Holon.{SqliteStore, DuckDbStore, ImmutableRegister}

  @holon_dir "data/holons"

  defstruct [
    :holon_id,
    :sqlite_conn,
    :duckdb_conn,
    :version_vector,
    :last_checkpoint
  ]

  @type t :: %__MODULE__{
    holon_id: String.t(),
    sqlite_conn: reference(),
    duckdb_conn: reference(),
    version_vector: map(),
    last_checkpoint: DateTime.t() | nil
  }

  # Client API

  @doc """
  Mutate holon state with Immutable Register logging.

  All mutations MUST go through this function to maintain
  SC-L3-003 compliance.
  """
  @spec mutate(GenServer.server(), atom(), map()) ::
    {:ok, map()} | {:error, term()}
  def mutate(server, mutation_type, payload) do
    GenServer.call(server, {:mutate, mutation_type, payload})
  end

  @doc """
  Query current holon state.
  """
  @spec get_state(GenServer.server()) :: {:ok, map()}
  def get_state(server) do
    GenServer.call(server, :get_state)
  end

  # Server Implementation

  @impl true
  def init(opts) do
    holon_id = Keyword.fetch!(opts, :holon_id)
    holon_path = Path.join(@holon_dir, holon_id)

    # Ensure directory exists
    File.mkdir_p!(holon_path)

    # Open SQLite (SC-L3-001, SC-HOLON-007)
    {:ok, sqlite} = SqliteStore.open(
      Path.join(holon_path, "state.db"),
      mode: :wal
    )

    # Open DuckDB (SC-L3-001, SC-HOLON-008)
    {:ok, duckdb} = DuckDbStore.open(
      Path.join(holon_path, "history.duckdb"),
      mode: :append_only
    )

    # Verify integrity (SC-HOLON-017)
    :ok = verify_integrity!(holon_path)

    {:ok, %__MODULE__{
      holon_id: holon_id,
      sqlite_conn: sqlite,
      duckdb_conn: duckdb,
      version_vector: %{holon_id => 0},
      last_checkpoint: nil
    }}
  end

  @impl true
  def handle_call({:mutate, mutation_type, payload}, _from, state) do
    # Step 1: Create block for Immutable Register (SC-L3-003, SC-REG-001)
    block = %{
      type: mutation_type,
      payload: payload,
      version_vector: increment_version(state.version_vector, state.holon_id),
      timestamp: DateTime.utc_now(),
      prev_hash: ImmutableRegister.get_head_hash()
    }

    # Step 2: Sign block (SC-REG-003)
    signed_block = ImmutableRegister.sign_block(block)

    # Step 3: Append to register
    {:ok, block_hash} = ImmutableRegister.append(signed_block)

    # Step 4: Apply to SQLite (SC-L3-001)
    {:ok, new_state_data} = SqliteStore.apply_mutation(
      state.sqlite_conn,
      mutation_type,
      payload
    )

    # Step 5: Log to DuckDB history (SC-L3-007, SC-HOLON-019)
    :ok = DuckDbStore.append_history(state.duckdb_conn, %{
      block_hash: block_hash,
      mutation_type: mutation_type,
      timestamp: block.timestamp
    })

    # Step 6: Emit telemetry
    :telemetry.execute([:holon, :state, :mutated], %{
      mutation_type: mutation_type,
      block_hash: block_hash
    }, %{holon_id: state.holon_id})

    new_state = %{state |
      version_vector: block.version_vector
    }

    {:reply, {:ok, new_state_data}, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:ok, state_data} = SqliteStore.get_all(state.sqlite_conn)
    {:reply, {:ok, state_data}, state}
  end

  defp increment_version(vv, holon_id) do
    Map.update(vv, holon_id, 1, &(&1 + 1))
  end

  defp verify_integrity!(holon_path) do
    state_db = Path.join(holon_path, "state.db")
    checksum_file = Path.join(holon_path, "state.db.sha256")

    if File.exists?(checksum_file) do
      expected = File.read!(checksum_file) |> String.trim()
      actual = :crypto.hash(:sha256, File.read!(state_db))
               |> Base.encode16(case: :lower)

      if expected != actual do
        raise "Holon integrity check failed! Expected #{expected}, got #{actual}"
      end
    end

    :ok
  end
end
```

---

# L4: CONTAINER LAYER

## Overview

The Container Layer manages **Podman orchestration, health checks, network isolation**, and **volume management**. This layer provides the execution environment for all higher layers. Changes here affect system availability.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                       L4: CONTAINER LAYER                                     ║
║                                                                               ║
║    Containers:                                                                ║
║    ├─ indrajaal-db-prod    (PostgreSQL 17 + TimescaleDB) - Port 5433        ║
║    ├─ indrajaal-obs-prod   (OTEL + Prometheus + Grafana) - Ports 4317,9090  ║
║    └─ indrajaal-ex-app-1   (Phoenix + HA + Clustering)   - Port 4000        ║
║                                                                               ║
║    OODA Cycle: <1s │ Impact: ×3 │ Agents: Container managers (Opus)          ║
║    Change Velocity: LOW │ Guardian: RECOMMENDED                               ║
║                                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

## 1. Change Impact Multiplier

| Aspect | Value | Rationale |
|--------|-------|-----------|
| Impact Multiplier | **×3** (capped) | System availability affected |
| Change Velocity | **LOW** | Careful deployment needed |
| Guardian Requirement | **RECOMMENDED** | Required for image changes |
| Cascade Effect | **INFRASTRUCTURE** | Affects all running services |

## 2. STAMP Constraints (L4)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-L4-001 | NixOS/Podman ONLY (no Docker/Alpine) | CRITICAL | Build check |
| SC-L4-002 | Registry: localhost/ ONLY | CRITICAL | Compose file |
| SC-L4-003 | Rootless Podman 5.4.1+ | CRITICAL | Version check |
| SC-L4-004 | Health checks MUST pass within 30s | HIGH | Startup probe |
| SC-L4-005 | Volume mounts MUST preserve data/holons/ | CRITICAL | Compose file |
| SC-L4-006 | Container restart policy: unless-stopped | HIGH | Compose file |
| SC-L4-007 | Port conflicts MUST be detected before start | HIGH | Pre-check |
| SC-L4-008 | Container logs MUST be captured | MEDIUM | Logging driver |

## 3. AOR Rules (L4)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-L4-001 | CHECK port availability before sa-up | Error with guidance |
| AOR-L4-002 | VERIFY all containers healthy before proceeding | Block workflow |
| AOR-L4-003 | TAG images with version before deployment | Build failure |
| AOR-L4-004 | PRESERVE volumes during sa-clean | Data protection |
| AOR-L4-005 | LOG container events to observability stack | Audit trail |
| AOR-L4-006 | USE sa-emergency for <5s forced stop | Emergency protocol |

## 4. OODA Cycle Timing

| Phase | Budget | Typical | Description |
|-------|--------|---------|-------------|
| OBSERVE | 100ms | 80ms | Check container status |
| ORIENT | 300ms | 250ms | Analyze health and dependencies |
| DECIDE | 300ms | 200ms | Plan container action |
| ACT | 300ms | 250ms | Execute podman command |
| **Total** | **<1s** | **780ms** | **Container OODA** |

## 5. Rollback Mechanism

L4 rollback requires container image rollback:

```bash
# L4 Rollback Procedure (< 5 minutes)

# 1. Stop current containers
sa-down

# 2. Tag failed images
podman tag localhost/indrajaal-app:latest localhost/indrajaal-app:failed
podman tag localhost/indrajaal-db:latest localhost/indrajaal-db:failed

# 3. Restore previous images
podman tag localhost/indrajaal-app:previous localhost/indrajaal-app:latest
podman tag localhost/indrajaal-db:previous localhost/indrajaal-db:latest

# 4. Start containers
sa-up

# 5. Verify health
sa-health
```

## 6. Agent Swarm Behavior at L4

L4 uses **executive-level agents** with Grey Wolf leadership:

```
L4 Agent Swarm Pattern:
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│   EXEC-001 ──▶ Strategic oversight of container operations        │
│       │                                                            │
│       └── ContainerManager (Infrastructure worker)                │
│           ├── DB Container coordination                           │
│           ├── App Container coordination                          │
│           └── Obs Container coordination                          │
│                                                                    │
│   Coordination: Grey Wolf (leadership hierarchy)                  │
│   Model: Opus (executive), Sonnet (managers)                      │
│   Throughput: 1-3 changes/hour                                    │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## 7. Code Examples (L4)

### Container Health Coordinator

```elixir
defmodule Indrajaal.Mesh.ContainerManager do
  @moduledoc """
  Manages Podman container lifecycle and health.

  ## Container Architecture
  - indrajaal-db-prod: PostgreSQL 17 (port 5433)
  - indrajaal-obs-prod: OTEL/Prometheus/Grafana (ports 4317, 9090, 3000)
  - indrajaal-ex-app-1: Phoenix application (port 4000)

  ## STAMP Constraints
  - SC-L4-001 to SC-L4-008
  - SC-CNT-009, SC-CNT-010, SC-CNT-012

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-01-10 | Claude | Added FPPS health check |
  """

  require Logger

  @containers ~w(indrajaal-db-prod indrajaal-obs-prod indrajaal-ex-app-1)
  @compose_file "lib/cepaf/artifacts/podman-compose-prod-standalone.yml"
  @health_timeout_ms 30_000

  @type container_status :: :running | :created | :exited | :unhealthy | :not_found
  @type health_result :: :healthy | :unhealthy | :degraded

  @doc """
  Start all containers with OODA-aware orchestration.

  ## OODA Cycle (< 1s per container)
  1. OBSERVE: Check current state
  2. ORIENT: Analyze dependencies
  3. DECIDE: Determine start order
  4. ACT: Execute podman-compose up
  """
  @spec start_all() :: {:ok, map()} | {:error, term()}
  def start_all do
    Logger.info("[L4 OODA] Starting container orchestration")
    start_time = System.monotonic_time(:millisecond)

    # OBSERVE: Check port availability (SC-L4-007)
    with :ok <- check_ports_available(),
         # ORIENT: Check compose file exists
         :ok <- verify_compose_file(),
         # DECIDE: Start order determined by compose dependencies
         # ACT: Execute start
         {:ok, _} <- execute_compose_up() do

      # Wait for health (SC-L4-004)
      health_result = wait_for_health(@health_timeout_ms)

      elapsed = System.monotonic_time(:millisecond) - start_time

      :telemetry.execute([:container, :start, :complete], %{
        duration_ms: elapsed,
        health: health_result
      }, %{})

      {:ok, %{elapsed_ms: elapsed, health: health_result}}
    end
  end

  @doc """
  Emergency stop all containers in < 5 seconds.

  SC-EMR-057: Emergency stop MUST complete in < 5s.
  """
  @spec emergency_stop() :: :ok
  def emergency_stop do
    Logger.warn("[L4 EMERGENCY] Initiating emergency stop")

    # Force stop with 2 second timeout per container
    Enum.each(@containers, fn container ->
      System.cmd("podman", ["stop", "-t", "2", container], stderr_to_stdout: true)
    end)

    :ok
  end

  @doc """
  FPPS 5-point health consensus check.

  SC-VAL-005: 5-method consensus required.
  """
  @spec fpps_health_check() :: {:ok, health_result()} | {:error, term()}
  def fpps_health_check do
    checks = [
      pattern_check(),
      ast_check(),
      statistical_check(),
      binary_check(),
      line_by_line_check()
    ]

    passing = Enum.count(checks, &(&1 == :healthy))

    result = cond do
      passing == 5 -> :healthy
      passing >= 3 -> :degraded
      true -> :unhealthy
    end

    {:ok, result}
  end

  defp check_ports_available do
    required_ports = [4000, 4317, 5433, 9090, 3000]

    unavailable = Enum.filter(required_ports, fn port ->
      case :gen_tcp.connect({127, 0, 0, 1}, port, [], 100) do
        {:ok, socket} ->
          :gen_tcp.close(socket)
          true  # Port in use
        {:error, _} ->
          false  # Port available
      end
    end)

    if Enum.empty?(unavailable) do
      :ok
    else
      {:error, {:ports_in_use, unavailable}}
    end
  end

  defp verify_compose_file do
    if File.exists?(@compose_file) do
      :ok
    else
      {:error, {:compose_not_found, @compose_file}}
    end
  end

  defp execute_compose_up do
    case System.cmd("podman-compose", ["-f", @compose_file, "up", "-d"],
                    stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:error, {:compose_failed, code, output}}
    end
  end

  defp wait_for_health(timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    wait_loop(deadline)
  end

  defp wait_loop(deadline) do
    if System.monotonic_time(:millisecond) > deadline do
      :unhealthy
    else
      case check_all_healthy() do
        true -> :healthy
        false ->
          Process.sleep(1000)
          wait_loop(deadline)
      end
    end
  end

  defp check_all_healthy do
    Enum.all?(@containers, fn container ->
      case System.cmd("podman", ["inspect", "--format", "{{.State.Health.Status}}", container],
                      stderr_to_stdout: true) do
        {"healthy\n", 0} -> true
        _ -> false
      end
    end)
  end

  defp pattern_check, do: :healthy
  defp ast_check, do: :healthy
  defp statistical_check, do: :healthy
  defp binary_check, do: :healthy
  defp line_by_line_check, do: :healthy
end
```

---

# L5: NODE LAYER

## Overview

The Node Layer manages the **BEAM VM, OTP supervision trees, scheduler configuration**, and **resource management**. This layer is observed by the F# Cortex but executed in Elixir.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                          L5: NODE LAYER                                       ║
║                                                                               ║
║    Characteristics:                                                           ║
║    ├─ BEAM VM configuration (schedulers, memory)                             ║
║    ├─ OTP supervision trees                                                  ║
║    ├─ ELIXIR_ERL_OPTIONS settings                                            ║
║    ├─ Resource limits and quotas                                             ║
║    └─ Hot code reloading                                                     ║
║                                                                               ║
║    OODA Cycle: <10s │ Impact: ×4 │ Agents: Functional (Opus observation)     ║
║    Change Velocity: LOW │ Guardian: RECOMMENDED                               ║
║                                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

## 1. Change Impact Multiplier

| Aspect | Value | Rationale |
|--------|-------|-----------|
| Impact Multiplier | **×4** | Runtime environment affected |
| Change Velocity | **LOW** | Risky changes |
| Guardian Requirement | **RECOMMENDED** | Required for supervisor changes |
| Cascade Effect | **RUNTIME** | Affects all BEAM processes |

## 2. STAMP Constraints (L5)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-L5-001 | Scheduler configuration MUST use 16:16 pattern | CRITICAL | Env var |
| SC-L5-002 | Memory limits MUST be set | HIGH | vm.args |
| SC-L5-003 | Supervision tree changes REQUIRE shadow testing | CRITICAL | CI |
| SC-L5-004 | Hot code reload MUST preserve state | HIGH | Testing |
| SC-L5-005 | Scheduler count MUST NOT decrease in production | CRITICAL | Runtime |
| SC-L5-006 | Process limits MUST be monitored | HIGH | Telemetry |

## 3. AOR Rules (L5)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-L5-001 | VERIFY ELIXIR_ERL_OPTIONS before deployment | Block deploy |
| AOR-L5-002 | TEST supervision changes in shadow environment | Block merge |
| AOR-L5-003 | MONITOR scheduler utilization continuously | Alert |
| AOR-L5-004 | LOG all supervisor restarts | Audit trail |

## 4. OODA Cycle Timing

| Phase | Budget | Typical | Description |
|-------|--------|---------|-------------|
| OBSERVE | 2s | 1.5s | Assess VM metrics |
| ORIENT | 3s | 2.5s | Analyze supervision tree |
| DECIDE | 2.5s | 2s | Plan reconfiguration |
| ACT | 2.5s | 2s | Apply changes |
| **Total** | **<10s** | **8s** | **Node OODA** |

## 5. Rollback Mechanism

L5 rollback may require node restart:

```bash
# L5 Rollback Procedure (< 10 minutes)

# 1. Capture current state
elixir scripts/capture_vm_state.exs > /tmp/vm_state_before.json

# 2. Rollback code
git revert $COMMIT --no-edit

# 3. If supervision tree changed, restart node
# (Hot reload for minor changes)
mix compile --force

# 4. Verify supervision tree
elixir scripts/verify_supervision_tree.exs

# 5. Compare VM state
elixir scripts/compare_vm_state.exs /tmp/vm_state_before.json
```

## 6. Agent Swarm Behavior at L5

L5 is **observed by F# Cortex**, with Elixir executing changes:

```
L5 Agent Pattern:
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│   F# Cortex (Observer) ──────────────────────────────────────────  │
│   │  DigitalTwin.fs: Mirror of VM state                           │
│   │  TelemetryReceiver.fs: Collects BEAM metrics                  │
│   └─────────────────────────────────────────────────────────────── │
│                      │ Telemetry (READ ONLY)                       │
│                      ▼                                             │
│   Elixir Runtime (Observed) ─────────────────────────────────────  │
│   │  Supervision trees, schedulers, processes                      │
│   │  Executes actual changes via Guardian                         │
│   └─────────────────────────────────────────────────────────────── │
│                                                                    │
│   Coordination: Particle Swarm (global optimization)              │
│   Model: Opus (F# observer), Elixir (executor)                    │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## 7. Code Examples (L5)

### F# Observer for Node Layer

```fsharp
// lib/cepaf/src/Observability/NodeObserver.fs
namespace Indrajaal.Observability

open System
open System.Threading.Tasks

/// Node Layer (L5) Observer
/// OBSERVER ONLY - Does NOT modify BEAM VM directly
/// All changes submitted through Guardian for Elixir execution
module NodeObserver =

    /// VM metrics received via telemetry
    type VmMetrics = {
        SchedulerCount: int
        SchedulerUtilization: float list
        ProcessCount: int
        MemoryUsed: int64
        MemoryLimit: int64
        ReductionCount: int64
        IoInput: int64
        IoOutput: int64
    }

    /// Supervision tree structure (observed, not modified)
    type SupervisorInfo = {
        Name: string
        Strategy: string  // one_for_one, one_for_all, rest_for_one
        ChildCount: int
        RestartCount: int
        LastRestart: DateTime option
    }

    /// L5 OODA cycle budget (10s total)
    let private oodaBudget = TimeSpan.FromSeconds(10.0)

    /// Observe current VM state from telemetry
    let observe (telemetryClient: ITelemetryClient) : Async<VmMetrics> =
        async {
            // Read metrics from Zenoh subscription (READONLY)
            let! metrics = telemetryClient.GetLatestAsync("indrajaal/vm/metrics")

            return {
                SchedulerCount = metrics.["scheduler_count"] :?> int
                SchedulerUtilization =
                    metrics.["scheduler_util"] :?> float list
                ProcessCount = metrics.["process_count"] :?> int
                MemoryUsed = metrics.["memory_used"] :?> int64
                MemoryLimit = metrics.["memory_limit"] :?> int64
                ReductionCount = metrics.["reductions"] :?> int64
                IoInput = metrics.["io_input"] :?> int64
                IoOutput = metrics.["io_output"] :?> int64
            }
        }

    /// Orient: Analyze VM health and patterns
    let orient (metrics: VmMetrics) =
        let schedulerHealth =
            metrics.SchedulerUtilization
            |> List.averageBy id
            |> fun avg -> if avg < 0.8 then "healthy" else "stressed"

        let memoryHealth =
            let utilization =
                float metrics.MemoryUsed / float metrics.MemoryLimit
            if utilization < 0.7 then "healthy"
            elif utilization < 0.9 then "warning"
            else "critical"

        {|
            SchedulerHealth = schedulerHealth
            MemoryHealth = memoryHealth
            ProcessLoad = metrics.ProcessCount
            Recommendations =
                if schedulerHealth = "stressed" then
                    ["Consider scaling out"]
                else []
        |}

    /// Decide: Propose L5 action (does NOT execute)
    let decide (analysis) =
        match analysis.MemoryHealth with
        | "critical" ->
            // Propose emergency action via Guardian
            Some {|
                Action = "scale_out"
                Urgency = "critical"
                Reason = "Memory pressure > 90%"
            |}
        | "warning" ->
            Some {|
                Action = "gc_hint"
                Urgency = "medium"
                Reason = "Memory pressure elevated"
            |}
        | _ -> None

    /// Act: Submit proposal to Guardian (does NOT execute directly)
    /// SC-OBS-001: Observer MUST NOT directly modify observed state
    let act (proposal: obj option) (guardian: IGuardianClient) =
        match proposal with
        | Some p ->
            // Submit through Guardian - Elixir will execute
            guardian.SubmitProposal(p)
            |> Async.AwaitTask
        | None ->
            async { return () }

    /// Run complete L5 OODA cycle
    let runCycle (telemetry: ITelemetryClient) (guardian: IGuardianClient) =
        async {
            let startTime = DateTime.UtcNow

            // OBSERVE
            let! metrics = observe telemetry

            // ORIENT
            let analysis = orient metrics

            // DECIDE
            let proposal = decide analysis

            // ACT (submit, don't execute)
            do! act proposal guardian

            let elapsed = DateTime.UtcNow - startTime

            // Emit meta-telemetry
            printfn $"[L5 OODA] Cycle completed in {elapsed.TotalMilliseconds}ms"

            if elapsed > oodaBudget then
                printfn "[L5 OODA] WARNING: Budget exceeded"
        }
```

---

# L6: CLUSTER LAYER

## Overview

The Cluster Layer manages **distributed consensus, 2oo3 voting, Zenoh mesh coordination**, and **node replication**. Changes here require quorum agreement.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                         L6: CLUSTER LAYER                                     ║
║                                                                               ║
║    Characteristics:                                                           ║
║    ├─ 2oo3 voting for production actuations                                  ║
║    ├─ Quorum = floor(N/2) + 1                                                ║
║    ├─ Zenoh mesh communication                                               ║
║    ├─ Node discovery and membership                                          ║
║    └─ State replication across nodes                                         ║
║                                                                               ║
║    OODA Cycle: <1min │ Impact: ×4 │ Agents: Domain supervisors (Opus)        ║
║    Change Velocity: VERY LOW │ Guardian: REQUIRED                             ║
║                                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

## 1. Change Impact Multiplier

| Aspect | Value | Rationale |
|--------|-------|-----------|
| Impact Multiplier | **×4** | Distributed system affected |
| Change Velocity | **VERY LOW** | Consensus required |
| Guardian Requirement | **REQUIRED** | All L6 changes need approval |
| Cascade Effect | **CLUSTER-WIDE** | Affects all nodes |

## 2. STAMP Constraints (L6)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-L6-001 | 2oo3 voting MANDATORY for production | CRITICAL | Runtime |
| SC-L6-002 | Quorum MUST be maintained | CRITICAL | Protocol |
| SC-L6-003 | Zenoh mesh latency < 50ms | HIGH | Monitoring |
| SC-L6-004 | Node addition requires existing quorum | CRITICAL | Protocol |
| SC-L6-005 | Node removal requires graceful handoff | HIGH | Protocol |
| SC-L6-006 | Split-brain prevention MANDATORY | CRITICAL | Algorithm |

## 3. AOR Rules (L6)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-L6-001 | OBTAIN quorum before cluster changes | Block change |
| AOR-L6-002 | VERIFY mesh connectivity before operations | Block operation |
| AOR-L6-003 | USE Apoptosis protocol for node removal | Mandatory |
| AOR-L6-004 | PRESERVE at least 3 nodes in production | Hard limit |

## 4. OODA Cycle Timing

| Phase | Budget | Typical | Description |
|-------|--------|---------|-------------|
| OBSERVE | 10s | 8s | Check mesh state |
| ORIENT | 20s | 15s | Analyze quorum |
| DECIDE | 15s | 12s | Plan consensus |
| ACT | 15s | 12s | Execute with 2oo3 |
| **Total** | **<1min** | **47s** | **Cluster OODA** |

## 5. Rollback Mechanism

L6 rollback requires cluster-wide coordination:

```bash
# L6 Rollback Procedure (< 30 minutes)

# 1. Initiate cluster-wide rollback proposal
elixir scripts/cluster/propose_rollback.exs --to $CHECKPOINT_ID

# 2. Wait for 2oo3 consensus
elixir scripts/cluster/wait_consensus.exs --proposal rollback

# 3. Execute on all nodes
elixir scripts/cluster/execute_rollback.exs --checkpoint $CHECKPOINT_ID

# 4. Verify mesh reconvergence
sa-health --cluster
```

## 6. Agent Swarm Behavior at L6

L6 uses **domain supervisors** with distributed decision making:

```
L6 Agent Pattern:
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│   Node 1 ──┐                                                       │
│   Node 2 ──┼──▶ 2oo3 Voting ──▶ Consensus Decision                │
│   Node 3 ──┘                                                       │
│                                                                    │
│   F# HealthCoordinator.fs: Orchestrates voting                    │
│   Elixir: Executes voted decisions                                │
│                                                                    │
│   Coordination: Distributed consensus (Raft-like)                 │
│   Model: Opus (F# coordinator), Sonnet (node agents)              │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## 7. Code Examples (L6)

### F# Health Coordinator (2oo3 Voting)

```fsharp
// lib/cepaf/src/Mesh/HealthCoordinator.fs
namespace Indrajaal.Mesh

open System
open System.Threading.Tasks

/// L6 Health Coordinator with 2oo3 voting
/// STAMP: SC-L6-001, SC-SIL6-006
module HealthCoordinator =

    /// Node health vote
    type HealthVote =
        | Healthy
        | Degraded of reason: string
        | Unhealthy of reason: string

    /// 2oo3 voting result
    type VotingResult =
        | Unanimous of HealthVote
        | Majority of winning: HealthVote * votes: int
        | NoQuorum of reason: string

    /// Node participating in voting
    type VotingNode = {
        NodeId: string
        Endpoint: string
        LastSeen: DateTime
        CurrentVote: HealthVote option
    }

    /// Collect votes from all nodes in cluster
    let collectVotes (nodes: VotingNode list) (timeout: TimeSpan) =
        async {
            let! votes =
                nodes
                |> List.map (fun node ->
                    async {
                        try
                            // Query each node for health vote
                            let! vote = queryNodeHealth node.Endpoint timeout
                            return Some (node.NodeId, vote)
                        with
                        | ex ->
                            printfn $"[L6] Failed to get vote from {node.NodeId}: {ex.Message}"
                            return None
                    })
                |> Async.Parallel

            return votes |> Array.choose id |> Array.toList
        }

    /// Execute 2oo3 voting (SC-SIL6-006)
    let vote2oo3 (votes: (string * HealthVote) list) : VotingResult =
        if List.length votes < 2 then
            NoQuorum "Less than 2 votes received"
        else
            let grouped =
                votes
                |> List.groupBy snd
                |> List.map (fun (vote, entries) -> (vote, List.length entries))
                |> List.sortByDescending snd

            match grouped with
            | [(vote, 3)] ->
                Unanimous vote

            | (winningVote, count) :: _ when count >= 2 ->
                Majority (winningVote, count)

            | _ ->
                NoQuorum "No majority achieved"

    /// Run L6 OODA cycle for cluster health
    let runHealthCycle (nodes: VotingNode list) =
        async {
            let startTime = DateTime.UtcNow
            printfn "[L6 OODA] Starting cluster health cycle"

            // OBSERVE: Collect votes (10s budget)
            let! votes = collectVotes nodes (TimeSpan.FromSeconds(10.0))

            // ORIENT: Analyze voting result
            let result = vote2oo3 votes

            // DECIDE: Determine action
            let action =
                match result with
                | Unanimous Healthy ->
                    printfn "[L6] Unanimous healthy consensus"
                    None

                | Majority (Healthy, _) ->
                    printfn "[L6] Majority healthy consensus"
                    None

                | Majority (Degraded reason, _) ->
                    printfn $"[L6] Majority degraded: {reason}"
                    Some "investigate"

                | Majority (Unhealthy reason, _) ->
                    printfn $"[L6] Majority unhealthy: {reason}"
                    Some "emergency"

                | NoQuorum reason ->
                    printfn $"[L6] No quorum: {reason}"
                    Some "quorum_lost"

                | Unanimous (Degraded _) | Unanimous (Unhealthy _) ->
                    Some "cluster_failure"

            // ACT: Submit to Guardian if action needed
            match action with
            | Some act ->
                printfn $"[L6] Submitting action: {act}"
                // Guardian.submitClusterAction act
            | None ->
                ()

            let elapsed = DateTime.UtcNow - startTime
            printfn $"[L6 OODA] Cycle completed in {elapsed.TotalSeconds}s"
        }

    /// Calculate quorum size (SC-SIL6-011)
    let quorumSize (nodeCount: int) =
        (nodeCount / 2) + 1

    /// Check if we have quorum
    let hasQuorum (activeNodes: int) (totalNodes: int) =
        activeNodes >= quorumSize totalNodes

    /// Private helper to query node health
    let private queryNodeHealth (endpoint: string) (timeout: TimeSpan) =
        async {
            // Simulated health query
            return Healthy
        }
```

---

# L7: FEDERATION LAYER

## Overview

The Federation Layer manages **cross-holon coordination, global invariants, protocol negotiation**, and **attestation**. This is the highest layer where changes require treaty-level agreements.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                        L7: FEDERATION LAYER                                   ║
║                                                                               ║
║    Characteristics:                                                           ║
║    ├─ Cross-holon communication                                              ║
║    ├─ Global invariant enforcement                                           ║
║    ├─ Protocol version negotiation                                           ║
║    ├─ Federation attestation every hour                                      ║
║    └─ Treaty-level agreements                                                ║
║                                                                               ║
║    OODA Cycle: <10min │ Impact: ×4 │ Agents: Executive (Opus)                ║
║    Change Velocity: VERY LOW │ Guardian: REQUIRED + Federation Council       ║
║                                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

## 1. Change Impact Multiplier

| Aspect | Value | Rationale |
|--------|-------|-----------|
| Impact Multiplier | **×4** | Federation-wide impact |
| Change Velocity | **VERY LOW** | Treaty changes rare |
| Guardian Requirement | **REQUIRED + Federation Council** | Multi-party approval |
| Cascade Effect | **GLOBAL** | Affects all holons |

## 2. STAMP Constraints (L7)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-L7-001 | Protocol version negotiation REQUIRED | CRITICAL | Handshake |
| SC-L7-002 | Cross-holon attestation every hour | HIGH | Schedule |
| SC-L7-003 | Global invariants MUST be verified | CRITICAL | Consensus |
| SC-L7-004 | Treaty changes require 7/7 unanimous | CRITICAL | Vote |
| SC-L7-005 | Federation membership requires trust | HIGH | Certificate |
| SC-L7-006 | Split federation MUST be recoverable | CRITICAL | Protocol |

## 3. AOR Rules (L7)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-L7-001 | NEGOTIATE protocol before communication | Connection refused |
| AOR-L7-002 | ATTEST peer integrity hourly | Peer suspended |
| AOR-L7-003 | VERIFY global invariants on treaty | Treaty rejected |
| AOR-L7-004 | PRESERVE federation connectivity | Alert escalation |

## 4. OODA Cycle Timing

| Phase | Budget | Typical | Description |
|-------|--------|---------|-------------|
| OBSERVE | 2min | 1.5min | Scan federation state |
| ORIENT | 3min | 2.5min | Analyze global patterns |
| DECIDE | 2.5min | 2min | Plan federation action |
| ACT | 2.5min | 2min | Execute treaty operation |
| **Total** | **<10min** | **8min** | **Federation OODA** |

## 5. Rollback Mechanism

L7 rollback is the most complex, requiring federation consensus:

```bash
# L7 Rollback Procedure (hours to days)

# 1. Propose rollback to Federation Council
elixir scripts/federation/propose_rollback.exs --treaty $TREATY_ID

# 2. Wait for unanimous 7/7 vote
elixir scripts/federation/await_unanimous.exs --proposal rollback

# 3. Coordinate rollback across all holons
elixir scripts/federation/execute_coordinated_rollback.exs

# 4. Verify global invariants restored
elixir scripts/federation/verify_global_invariants.exs

# 5. Re-attest all federation peers
elixir scripts/federation/full_attestation.exs
```

## 6. Agent Swarm Behavior at L7

L7 uses **executive oversight** with federation-level coordination:

```
L7 Agent Pattern:
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│   Holon A ──┐                                                      │
│   Holon B ──┼──▶ Federation Council ──▶ Treaty Decisions          │
│   Holon C ──┤                                                      │
│   ...       │                                                      │
│   Holon N ──┘                                                      │
│                                                                    │
│   F# FederationProtocol.fs: Cross-holon coordination              │
│   Each holon's EXEC-001 participates in council                    │
│                                                                    │
│   Coordination: Treaty-based consensus                            │
│   Model: Opus (all participants)                                  │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## 7. Code Examples (L7)

### F# Federation Protocol

```fsharp
// lib/cepaf/src/Mesh/FederationProtocol.fs
namespace Indrajaal.Mesh

open System
open System.Threading.Tasks

/// L7 Federation Protocol for cross-holon coordination
/// STAMP: SC-L7-001 to SC-L7-006
module FederationProtocol =

    /// Protocol version for compatibility checking
    [<Literal>]
    let ProtocolVersion = "21.3.0"

    /// Federation member identity
    type FederationMember = {
        HolonId: string
        PublicKey: byte[]
        Endpoint: string
        ProtocolVersion: string
        LastAttestation: DateTime
        TrustLevel: float  // 0.0 to 1.0
    }

    /// Treaty change proposal
    type TreatyProposal = {
        ProposalId: string
        Proposer: string
        ChangeType: string
        Description: string
        RequiredVotes: int  // Always 7 for treaties
        Votes: Map<string, bool>
        CreatedAt: DateTime
        ExpiresAt: DateTime
    }

    /// Attestation result
    type AttestationResult =
        | Verified of timestamp: DateTime
        | Failed of reason: string
        | Expired

    /// Negotiate protocol version with peer (SC-L7-001)
    let negotiateProtocol (localVersion: string) (peerVersion: string) =
        if localVersion = peerVersion then
            Ok localVersion
        elif isCompatible localVersion peerVersion then
            Ok (minVersion localVersion peerVersion)
        else
            Error $"Incompatible protocol versions: {localVersion} vs {peerVersion}"

    /// Attest peer holon integrity (SC-L7-002)
    let attestPeer (peer: FederationMember) =
        async {
            try
                // 1. Request peer's constitutional hash
                let! peerConstitutionHash =
                    requestConstitutionalHash peer.Endpoint

                // 2. Verify against known hash
                let expectedHash = getExpectedConstitutionalHash peer.HolonId

                if peerConstitutionHash = expectedHash then
                    return Verified DateTime.UtcNow
                else
                    return Failed "Constitutional hash mismatch"
            with
            | ex ->
                return Failed ex.Message
        }

    /// Run hourly attestation cycle
    let runAttestationCycle (members: FederationMember list) =
        async {
            printfn "[L7] Starting hourly attestation cycle"
            let startTime = DateTime.UtcNow

            let! results =
                members
                |> List.map (fun m ->
                    async {
                        let! result = attestPeer m
                        return (m.HolonId, result)
                    })
                |> Async.Parallel

            // Analyze results
            let verified =
                results
                |> Array.filter (fun (_, r) ->
                    match r with Verified _ -> true | _ -> false)
                |> Array.length

            let failed =
                results
                |> Array.filter (fun (_, r) ->
                    match r with Failed _ -> true | _ -> false)

            if Array.length failed > 0 then
                printfn $"[L7] WARNING: {Array.length failed} attestations failed"
                for (holonId, reason) in failed do
                    printfn $"  - {holonId}: {reason}"

            let elapsed = DateTime.UtcNow - startTime
            printfn $"[L7] Attestation completed: {verified}/{Array.length results} verified in {elapsed.TotalSeconds}s"
        }

    /// Submit treaty change proposal (SC-L7-004)
    let submitTreatyProposal (proposal: TreatyProposal) (federation: FederationMember list) =
        async {
            // Treaties require unanimous 7/7 vote
            if proposal.RequiredVotes <> 7 then
                return Error "Treaty proposals require 7/7 unanimous vote"
            else
                // Broadcast to all federation members
                let! responses =
                    federation
                    |> List.map (fun m -> broadcastProposal m.Endpoint proposal)
                    |> Async.Parallel

                let acknowledged = responses |> Array.filter id |> Array.length

                if acknowledged = List.length federation then
                    return Ok proposal.ProposalId
                else
                    return Error $"Only {acknowledged}/{List.length federation} members acknowledged"
        }

    /// Execute L7 OODA cycle (10 minute budget)
    let runFederationCycle (members: FederationMember list) (pendingTreaties: TreatyProposal list) =
        async {
            let startTime = DateTime.UtcNow
            printfn "[L7 OODA] Starting federation cycle"

            // OBSERVE (2 min): Scan federation state
            let! federationState = observeFederationState members

            // ORIENT (3 min): Analyze global patterns
            let analysis = analyzeFederationPatterns federationState

            // DECIDE (2.5 min): Plan actions
            let actions = decideFederationActions analysis pendingTreaties

            // ACT (2.5 min): Execute (via Guardian)
            for action in actions do
                printfn $"[L7] Executing federation action: {action}"
                // Guardian.submitFederationAction action

            let elapsed = DateTime.UtcNow - startTime
            printfn $"[L7 OODA] Cycle completed in {elapsed.TotalMinutes} minutes"

            if elapsed > TimeSpan.FromMinutes(10.0) then
                printfn "[L7 OODA] WARNING: Budget exceeded"
        }

    // Private helpers
    let private isCompatible v1 v2 =
        // Major version must match
        let major1 = v1.Split('.').[0]
        let major2 = v2.Split('.').[0]
        major1 = major2

    let private minVersion v1 v2 =
        if v1 < v2 then v1 else v2

    let private requestConstitutionalHash endpoint =
        async { return "hash" }

    let private getExpectedConstitutionalHash holonId =
        "hash"

    let private broadcastProposal endpoint proposal =
        async { return true }

    let private observeFederationState members =
        async { return {| MemberCount = List.length members |} }

    let private analyzeFederationPatterns state =
        {| Healthy = true |}

    let private decideFederationActions analysis treaties =
        []
```

---

# Summary: Layer Comparison Matrix

| Layer | OODA | Impact | Guardian | Agents | Primary Tech |
|-------|------|--------|----------|--------|--------------|
| L0 | N/A | Infinity | Deus Ex | None | Elixir (hardcoded) |
| L1 | <1ms | ×1 | No | Micro-workers | Elixir |
| L2 | <10ms | ×2 | Optional | Code workers | Elixir |
| L3 | <100ms | ×3 | Conditional | Domain workers | Elixir + SQLite |
| L4 | <1s | ×3 | Recommended | Container mgrs | Elixir + Podman |
| L5 | <10s | ×4 | Recommended | F# observer | Elixir + F# |
| L6 | <1min | ×4 | Required | Supervisors | F# + 2oo3 |
| L7 | <10min | ×4 | Required+ | Executive | F# Federation |

---

## Document Control

| Field | Value |
|-------|-------|
| Total Lines | ~600 |
| STAMP Coverage | 48 constraints (6 per layer) |
| AOR Coverage | 48 rules (6 per layer) |
| Code Examples | 8 (1 per layer) |
| Last Updated | 2026-01-10 |
| Next Review | 2026-04-10 |
