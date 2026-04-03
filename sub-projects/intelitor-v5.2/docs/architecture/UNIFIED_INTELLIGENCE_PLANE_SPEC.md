# Indrajaal Unified Intelligence Plane (UIP) Specification

**Version**: 1.0.0  
**Compliance**: SIL-6 Biomorphic (Systemic Governance)  
**Status**: OPERATIONAL  
**Architecture**: Bicameral (Formal Logic + Runtime Streams)

## 1. Ecosystem Overview (Level 1)
The UIP is a 7-layered semantic substrate that enables absolute operational control over the Indrajaal mesh. It bridges the gap between static source code (Genome) and runtime behavior (Phenome) using formal proofs and active probes.

| Layer | Domain | Primary Tool | Cybernetic Function |
| :--- | :--- | :--- | :--- |
| **L7: Logic** | Formal Synthesis | `formal-oracle` | Quint state machine verification. |
| **L6: Proof** | Pure Logic | `proof-oracle` | Agda invariant proofs. |
| **L5: Math** | Symbolic Engine | `math-oracle` | SLA precision and control theory. |
| **L4: Genotype**| Infrastructure | `yaml-intelligence`| Genotype schema validation. |
| **L3: Substrate**| Deterministic Env | `env-sentinel` | Nix/Devenv substrate audit. |
| **L2: Genome** | Declarative App | `ash-oracle` | Ash Framework resource analysis. |
| **L1: Proteome**| Runtime Debug | `zenoh-probe` | Live neural heartbeat monitoring. |

## 2. Component Design & Configuration (Level 2)
### 2.1 Tool Configuration (MCP Substrate)
All tools are registered via `.mcp.json`. 
- **Tool-Path**: `.agents/bin/` (Local isolation)
- **Environment**: Nix-shell (Deterministic context)
- **Communication**: JSON-RPC (MCP) and Stdin/Stdout (FSI/IEx)

### 2.2 Symbolic Math Bridge
- **Design**: Mathematica Surrogate (SymPy in Python).
- **Function**: Solves the "Jitter Constraint Equation" to ensure mesh waves never exceed 10s.

## 3. Implementation Logic (Level 3)
### 3.1 The F# Semantic Oracle
The oracle uses `fsautocomplete --lsp` to perform:
1. **Type-Probe**: Injects code into a virtual `.fs` file and checks for `FS0001` or `FS0039`.
2. **Refactor-Check**: Validates that a proposed fix doesn't break external dependencies.

### 3.2 The Elixir AST Oracle
Uses `Code.string_to_quoted/1` to verify:
1. **Syntactic Purity**: Catching macro-expansion errors before compilation.
2. **Semantic warnings**: Catching unused variables or "never match" patterns.

## 4. Usage & OODA Cycles (Level 4)
### 4.1 The Standard Audit Cycle
1. **Observe**: Run `security-sentry` and `env-sentinel`.
2. **Orient**: Map findings to the `dependency-oracle` graph.
3. **Decide**: Use `formal-oracle` to verify the logic of the fix.
4. **Act**: Use `fsharp-intelligence` or `elixir-intelligence` to apply code.

## 5. Testing & Reliability (Level 5)
### 5.1 Intelligence Verification
Every tool has a `self_check` function:
- **Agda**: `agda --safe` (Ensures no postulates are used).
- **Python**: `pytest` (Verifies symbolic math accuracy).
- **Zenoh**: Heartbeat echo test.

---

## 6. Safety & Governance Rules

### 6.1 STAMP Constraints (Systemic Safety)
- **SC-UIP-001**: The Agent SHALL NOT execute F# code that fails the `fsharp-intelligence` semantic probe.
- **SC-UIP-002**: The Agent SHALL NOT commit YAML configurations that violate `yaml-intelligence` SIL6 registry rules.
- **SC-UIP-003**: Any "Wave Failure" MUST trigger a `formal-oracle` RCA.

### 6.2 FMEA (Failure Mode Effects Analysis)
| Failure Mode | Impact | Mitigation |
| :--- | :--- | :--- |
| **Oracle Hallucination** | Incorrect fix applied. | Mandatory `mix compile` gate (Axiom 1). |
| **LSP Crash** | Loss of semantic awareness. | Fallback to `grep/ripgrep` (Secondary sensors). |
| **Math Divergence** | SLA Violation (>10s). | Adaptive Jitter increase in `math-oracle`. |

### 6.3 TDG Rules (Test-Driven Generation)
- **TDG-UIP-001**: Every generated F# module MUST have a corresponding Agda proof skeleton.
- **TDG-UIP-002**: Every generated Elixir resource MUST be verified by `ash-oracle`.

### 6.4 AOR Rules (Agent Operating Rules)
- **AOR-UIP-001**: Agent MUST run `security-sentry` before any PR creation.
- **AOR-UIP-002**: Agent MUST refresh the `dependency-oracle` graph after significant architectural changes.
- **AOR-UIP-003**: Agent MUST use `zenoh-probe` to verify heartbeat *during* Live Mesh Startup.
