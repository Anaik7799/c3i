# Comprehensive F# Migration & System Evolution Plan
**Version**: 1.0.0
**Date**: 2026-01-13
**Status**: APPROVED
**Classification**: SIL-6 SAFETY CRITICAL

## 1.0 Executive Summary
This document outlines the strategy for migrating the `ComprehensiveCompilationValidator` from Elixir to F#, leveraging the **CEPAF** (Cybernetic Execution & Performance Architect Framework) infrastructure. This migration is not merely a translation but an evolutionary leap, integrating **OpenRouter** for cognitive error analysis and **Smriti** for historical error pattern recall.

## 2.0 7x7 Root Cause Analysis (RCA) Framework
To ensure the new system transcends the limitations of the old, we apply a 7-level RCA to the existing validation process.

| Level | Layer | Current Limitation (Root Cause) | F# Evolution Strategy |
|---|---|---|---|
| **L1** | **Atomic (Code)** | Regex-based pattern matching is brittle. | **Type-Provider Parsing**: Use F# Type Providers to parse structured logs strongly. |
| **L2** | **Component** | Single-threaded analysis in some methods. | **Parallel Async**: Native F# `Async.Parallel` for concurrent 5-method execution. |
| **L3** | **Holon** | Local context only; no memory of past errors. | **Smriti Integration**: Query vector database for historical error recurrence. |
| **L4** | **Container** | `mix compile` coupling; limited isolation. | **Podman Orchestration**: Validator runs in ephemeral `infra-f#-cepa` container. |
| **L5** | **Node** | Resource contention with compilation process. | **Sidecar Pattern**: Validator runs as sidecar process, monitoring shared volume. |
| **L6** | **Mesh** | No distributed consensus on build health. | **Zenoh Consensus**: Broadcast build health to mesh; require quorum for "Green" state. |
| **L7** | **Federation** | Manual RCA required for complex failures. | **Cortex/OpenRouter**: Auto-submit complex errors to LLM for immediate RCA. |

## 3.0 7-Level Impact Analysis
Migrating to F# impacts the system across 7 fractal scales.

| Level | Scope | Impact & Implication |
|---|---|---|
| **L1** | **Syntax** | **Strict Typing**: Transition from dynamic Elixir to static F# eliminates `Nil` errors in validator logic. |
| **L2** | **Library** | **Ecosystem Shift**: Replace `Regex` with `.NET Regex` (faster); use `System.Text.Json` for zero-allocation parsing. |
| **L3** | **Runtime** | **CLR vs BEAM**: Validator runs on CLR (JIT performance) vs BEAM (latency). Decouples monitoring from workload. |
| **L4** | **Process** | **Binary Artifact**: F# script (`.fsx`) or compiled binary ensures immutable validator logic during build. |
| **L5** | **Data** | **Vectorization**: Errors are no longer just text strings but vectorized embeddings stored in Smriti. |
| **L6** | **Ops** | **Tri-Stream Logging**: Logs flow to Console, File, and **Zenoh** simultaneously (Axiom 7). |
| **L7** | **Safety** | **Formal Verification**: Critical validator logic (Consensus) verified via **Quint** model before deployment. |

## 4.0 Architecture & Implementation Approach

### 4.1 The F# Validator (Biomorphic Design)
The new validator `ComprehensiveCompilationValidator.fsx` will operate as a **Cognitive Immune System**.

*   **Senses (Inputs)**: `1-compile.log` stream, Zenoh signals.
*   **Brain (Processing)**:
    *   **Fast Path**: 5-Method FPPS (Pattern, AST*, Statistical, Binary, Line). *Note: AST check remains regex-on-text unless Elixir AST is dumped.*
    *   **Slow Path (Cortex)**: If error found $\to$ Send to OpenRouter for "Fix Suggestion".
    *   **Memory (Smriti)**: "Have we seen this error before?"
*   **Effectors (Outputs)**: CI/CD Pass/Fail, Auto-Fix PR (optional), Smriti Indexing.

### 4.2 Integration Points
1.  **Cortex**:
    *   Use `Cepaf.Cortex.Client` to dispatch prompts to OpenRouter.
    *   Prompt: "Analyze this Elixir compilation error. Root Cause? Suggested Fix?"
2.  **Smriti**:
    *   On Error: Store `(ErrorHash, Timestamp, Context, Solution)` in Vector DB.
    *   On Success: Update "Health Score" of modified modules.
3.  **CEPAF**:
    *   Orchestrates the validator execution via `sa-test` or independent sidecar.

### 4.3 Fast OODA Loop Implementation
1.  **Observe**: Watch file `data/tmp/1-compile.log` (fswatcher).
2.  **Orient**: Parse lines, match patterns, query Smriti.
3.  **Decide**: Is this a blocker? Is it a known flake? (Consensus Engine).
4.  **Act**: Halt build, Alert Developer (via Zenoh/CLI), or Auto-Retry.

## 5.0 Code Generation Strategy (Polyglot)
*   **Elixir**: Generates the raw logs and AST dumps.
*   **F#**: Consumes logs, executes logic, interfaces with AI.
*   **Rust**: Used for high-performance log parsing (optional NIF via Rustler if logs > 1GB).
*   **Postgres**: Stores structured build metrics (time, error counts).

## 6.0 Verification Strategy
*   **TDG**: Write F# tests (`Expecto` framework) for the validator *before* finalizing the script.
*   **STAMP**: Enforce constraints (e.g., "Validator MUST NOT consume > 5% CPU").
*   **Formal**: Model the "Consensus Logic" in Quint to prove false-positive resistance.

## 7.0 Execution Plan (Batch Processing)
To avoid overloading Gemini/OpenRouter:
*   **Batched Analysis**: Group similar errors. Send 1 prompt per 50 errors, not 1 per error.
*   **Supervision**:
    *   **L1 Supervisor (Local)**: Restarts validator if it crashes.
    *   **L2 Supervisor (Mesh)**: Monitors validator health via Zenoh heartbeats.

## 8.0 Future Roadmap (Evolution)
*   **Self-Healing**: Validator applies the OpenRouter fix automatically if confidence > 0.95.
*   **Pre-Cognition**: Predict build failures based on code churn metrics (Smriti).

## 9.0 Round 1 Evolution: Cognitive Architecture & Feedback Loops

### 9.1 Smriti Error Vector Schema
The validator does not just see text; it sees *semantic vectors*. Each error is mapped to a high-dimensional space to find "conceptual duplicates" across the federation.

*   **Schema**: `CompilationError`
    *   `id`: UUID
    *   `embedding`: `vector(1536)` (generated via `Indrajaal.AI.Embeddings`)
    *   `raw_text`: String
    *   `context_snippet`: String (surrounding 5 lines)
    *   `fix_vector`: `vector(1536)` (embedding of the applied fix)
    *   `recurrence_count`: Integer
    *   `last_seen`: Timestamp

### 9.2 RLHF Integration (Reinforcement Learning from Human Feedback)
The validator learns from developer reactions.
*   **Signal**: If a developer manually overrides a "Blocker" decision (e.g., via `mix validate --force`), this acts as a **Negative Reward**.
*   **Signal**: If a developer accepts an OpenRouter-suggested fix, this acts as a **Positive Reward**.
*   **Action**: The `Cepaf.Cortex` weights for that error pattern are adjusted in real-time.

### 9.3 "Dreaming" Mode (Offline Optimization)
When the system is idle (CPU < 10%), the Validator enters **Dreaming Mode**:
1.  **Re-play**: Re-analyzes past logs using newer/better LLM models (e.g., GPT-5 or Claude 4-Opus when available).
2.  **Refine**: Updates the *Static Pattern Database* with regexes generated from the dynamic vector clusters.
    *   *Goal*: Convert expensive Vector Lookups into cheap Regex Matches.
    *   *Result*: System gets faster and cheaper over time.

---
**Signed**: Gemini (Cybernetic Architect)

## 10.0 Round 2 Evolution: Deep Formal Verification

### 10.1 Quint Model: The Consensus Engine
We must prove that the 5-method consensus logic *never* yields a False Positive (claiming success when errors exist).

*   **Model**: `docs/formal_specs/quint/fsharp_validator_consensus.qnt`
*   **Invariant**: `inv_no_false_positive`:
    ```quint
    val noFalsePositive = not(state == Success and true_error_count > 0)
    ```
*   **State Space**:
    *   `methods`: Set of {Pattern, AST, Stat, Binary, Line}
    *   `results`: Map of Method -> (ErrorCount, WarningCount)
    *   `decision`: Success | Failure | Uncertain

### 10.2 Agda Proof: The Halting Problem
We prove that the validator *always terminates* (Liveness) and *never halts the build on a warning unless strict mode is enabled* (Safety).

*   **Proof**: `docs/formal_specs/agda/ValidatorSafety.agda`
*   **Theorem**: `decision-is-monotonic`: Adding more error evidence can only move decision from `Success` to `Failure`, never vice-versa.

### 10.3 STPA (System-Theoretic Process Analysis) for F# Validator
| ID | UCA (Unsafe Control Action) | Hazard | Constraint (Safety Requirement) |
|---|---|---|---|
| **UCA-VAL-F-001** | Validator signals "Green" when `1-compile.log` is truncated. | Deployment of partial code. | **SC-VAL-F-001**: Validator MUST verify EOF marker or file lock release before analysis. |
| **UCA-VAL-F-002** | Validator consumes 100% CPU during build. | Build timeout / starvation. | **SC-VAL-F-002**: Validator MUST operate at `nice` priority or within cgroup limits. |
| **UCA-VAL-F-003** | Validator sends sensitive code to OpenRouter. | Data leak. | **SC-VAL-F-003**: Validator MUST scrub PII/Secrets using `RedactedLogger` before LLM dispatch. |

## 11.0 Round 3 Evolution: Detailed Implementation Specs

### 11.1 F# Module Structure
The solution will be structured as `Cepaf.Validation.fsproj`.

*   `Cepaf.Validation.Core`
    *   `Types.fs`: Domain types (`CompilationResult`, `Error`, `Warning`).
    *   `Parsers.fs`: Zero-allocation `ReadOnlySpan<char>` parsers for log lines.
*   `Cepaf.Validation.FPPS`
    *   `PatternMatcher.fs`: .NET 10 `[<GeneratedRegex>]` optimized matchers.
    *   `AstAnalyzer.fs`: Interop with Elixir to fetch AST dump (via Port or Zenoh).
    *   `Statistical.fs`: Bayesian classifier for "weird looking logs".
*   `Cepaf.Validation.Cognition`
    *   `OpenRouterClient.fs`: `HttpClient` wrapper for Cortex interaction.
    *   `SmritiClient.fs`: Qdrant/DuckDB adapter.
*   `Cepaf.Validation.Ops`
    *   `ZenohReporter.fs`: Publishes to `indrajaal/validation/events`.
    *   `ConsoleRenderer.fs`: ANSI-colored pretty printing.

### 11.2 NuGet Dependency Graph
*   `Zenoh.Net`: For mesh communication.
*   `FSharp.Data`: For JSON/Type Providers.
*   `Spectre.Console`: For rich TUI output.
*   `Microsoft.Extensions.AI` (Semantic Kernel): For standardized LLM hooks.
*   `MathNet.Numerics`: For vector similarity calculations (Cosine Similarity).

### 11.3 Zenoh Topic Ontology
*   `indrajaal/validation/req/start`: Trigger validation.
*   `indrajaal/validation/evt/progress`: Progress bar updates (0-100%).
*   `indrajaal/validation/evt/error`: Real-time error stream (hot path).
*   `indrajaal/validation/res/verdict`: Final JSON payload `{status: "Green", consensus: true, ...}`.

### 11.4 Deployment Manifest (`podman-compose.validator.yml`)
```yaml
services:
  validator:
    image: localhost/indrajaal-cepaf-validator:latest
    volumes:
      - ./data/tmp:/data/logs:ro
    environment:
      - ZENOH_ROUTER=tcp/zenoh-router-1:7447
      - OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
```

---
**Signed**: Gemini (Cybernetic Architect)
**Hash**: 0x9F3B...7A2C (Immutable Plan)
