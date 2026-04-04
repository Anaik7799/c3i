---
name: oracle
description: Multi-oracle verification — formal (Quint), mathematical (symbolic), security, semantic probes
---
---

# Multi-Oracle Verification (SC-UIP, Bicameral Verification Cycle)

Unified Intelligence Plane oracles for 4-gate verification: Semantic, Formal, Security, Math.

## Mathematical Foundation

**Oracle Category** $\mathcal{O}$:
$$\text{Obj}(\mathcal{O}) = \{\text{Semantic}, \text{Formal}, \text{Security}, \text{Math}\}$$
$$\text{Verdict}: \mathcal{O} \times \text{Target} \to \{\top, \bot, \text{?}\}$$

**BVC Conjunction** (all 4 must agree for safety-critical):
$$\text{BVC}(t) = \bigwedge_{o \in \mathcal{O}} \text{Verdict}(o, t)$$

**Oracle Composition** (Kleisli category):
$$\text{Semantic} \circ \text{Formal}: \text{AST} \to \text{StateModel} \to \text{ProofObligation}$$

## Usage
```
/oracle formal lib/indrajaal/safety/sentinel.ex       # Quint state machine verification
/oracle math "PID controller stability"                # Symbolic math analysis
/oracle security lib/indrajaal/accounts/               # Vulnerability audit
/oracle semantic lib/cepaf/src/Cepaf/Mesh/DigitalTwin.fs  # AST semantic probe
/oracle all lib/indrajaal/prometheus/verifier.ex       # Full BVC (all 4 oracles)
```

## Oracle Commands

### Formal Oracle (Quint State Machine)
```bash
# Verify state machine model
dotnet fsi scripts/agents/fsharp_oracle.fsx $TARGET
```
- Checks temporal properties: liveness, safety, fairness
- Verifies state transitions are well-defined
- Generates counter-examples for violations
- Maps to STAMP constraints

### Math Oracle (Symbolic Computation)
```bash
python3 scripts/agents/math_oracle.py $TARGET
```
- Control theory: PID stability (Ziegler-Nichols, Routh-Hurwitz)
- Information theory: Shannon entropy, mutual information
- Category theory: functor laws, natural transformation
- Timing analysis: WCET, jitter bounds

### Security Oracle (SIL-4 Audit)
```bash
mix run scripts/agents/security_sentry.exs -- --audit $TARGET
```
- OWASP Top 10 scanning
- Dependency vulnerability check
- Sobelow integration
- Credential detection
- Maps to SC-SEC-* constraints

### Semantic Oracle (AST Analysis)
```bash
# F# semantic probe
dotnet fsi scripts/agents/fsharp_oracle.fsx $TARGET
# Elixir semantic probe
mix run scripts/agents/elixir_oracle.exs $TARGET
```
- Type inference verification
- Function complexity metrics (cyclomatic, cognitive)
- Dead code detection
- Pattern exhaustiveness

### Full BVC (All 4 Oracles)
1. **Semantic**: Probe target AST → extract state model
2. **Formal**: Verify state model against Quint spec
3. **Security**: Audit for vulnerabilities
4. **Math**: Verify SLA calculations
5. Cross-correlate with live data:
   - `sentinel(action: "health")` — runtime health context
   - `zenoh_query(action: "verify")` — FFI invariants
6. Generate unified BVC report:
   ```
   BVC REPORT: [target]
   ├── Semantic:  PASS/FAIL (complexity: X, dead code: Y)
   ├── Formal:    PASS/FAIL (states: X, transitions: Y)
   ├── Security:  PASS/FAIL (vulns: X, severity: Y)
   ├── Math:      PASS/FAIL (stability: X, bounds: Y)
   └── VERDICT:   APPROVED / REJECTED ($\Psi_i$ violation)
   ```

## SIL-6 Verification Coverage

| Oracle | SDLC Phases | SC Constraints |
|--------|-------------|---------------|
| Semantic | Design, Impl | SC-DOC-001, SC-CMP-025 |
| Formal | Spec, Design | SC-PROM-004, SC-BDD-011, SC-BDD-012 |
| Security | Impl, Test | SC-SEC-044, SC-SEC-047 |
| Math | Design, Runtime | SC-MATH-001 to SC-MATH-008 |

## Oracle Server Mapping
| Oracle | MCP Server | Status |
|--------|-----------|--------|
| Formal | formal-oracle | Registered (Quint CLI) |
| Math | math-oracle | Registered (Python) |
| Security | security-sentry | Registered (Elixir) |
| Semantic (F#) | fsharp-intelligence | Registered (dotnet fsi) |
| Semantic (Ex) | elixir-intelligence | Registered (Elixir) |
| Categorical | categorical-linter | Registered (F# fsi) |
