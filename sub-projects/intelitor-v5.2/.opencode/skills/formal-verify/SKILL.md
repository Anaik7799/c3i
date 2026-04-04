---
name: formal-verify
description: Formal verification — Agda proofs, Quint models, graph properties, dependent types
---
---

# Formal Verification Suite (SC-BDD-011, SC-BDD-012, SC-9x9-001)

Multi-paradigm formal verification: dependent types (Agda), temporal logic (Quint), graph theory.

## Mathematical Foundation

**Proof Category** $\mathcal{P}$:
$$\text{Obj}(\mathcal{P}) = \{\text{Agda}_{dependent}, \text{Quint}_{temporal}, \text{Graph}_{structural}\}$$

**Curry-Howard Correspondence**:
$$\text{Proof} \cong \text{Program}, \quad \text{Proposition} \cong \text{Type}$$

**Temporal Operators** (Quint/TLA+):
$$\Box P \text{ (always P)}, \quad \diamond P \text{ (eventually P)}, \quad P \mathcal{U} Q \text{ (P until Q)}$$

**Graph Safety Predicate**:
$$\text{Safe}(G) \iff \text{Acyclic}(G) \wedge \text{Connected}(G) \wedge \text{Bounded}(\text{Degree}(G))$$

## Usage
```
/formal-verify agda GraphProperties                     # Type-check Agda proofs
/formal-verify quint lib/indrajaal/safety/sentinel.ex   # Model check state machine
/formal-verify graph lib/indrajaal/mesh/                # Graph property verification
/formal-verify all                                       # Full formal verification suite
```

## Commands

### Agda Proofs (SC-BDD-012: Must type-check)
1. Locate proofs: `Glob` for `formal_specs/**/*.agda`
2. Type-check:
   ```bash
   agda --safe formal_specs/proofs/GraphProperties.agda
   agda --safe formal_specs/proofs/AcyclicityProofs.agda
   ```
3. Extract witnesses for runtime use
4. Report: proposition, proof status, dependencies

### Quint Models (SC-BDD-011: Must pass model check)
1. Locate specs: `Glob` for `formal_specs/**/*.qnt`
2. Model check:
   ```bash
   quint verify formal_specs/quint/SentinelStateMachine.qnt
   ```
3. Generate counter-examples for failures
4. Map violations to STAMP constraints

### Graph Verification
1. Extract module dependency graph
2. Verify properties:
   - **Acyclicity**: Kahn topological sort ($|TopSort(G)| = |V|$)
   - **Connectivity**: BFS from root covers all nodes
   - **Bounded degree**: $\max(\text{deg}(v)) \leq k$ (complexity cap)
   - **Centrality**: Brandes betweenness (identify bottlenecks)
3. Correlate with FFI: `zenoh_query(action: "verify")` — 12 runtime invariants

### Full Suite
1. Run all Agda proofs (2 real + stubs)
2. Run all Quint models (109 specs)
3. Run graph analysis (CFG + DFG + call graph)
4. Generate unified report:
   ```
   FORMAL VERIFICATION REPORT
   ├── Agda:  2/2 proofs type-check
   ├── Quint: 109/109 models pass
   ├── Graph: Acyclic ✓, Connected ✓, Bounded ✓
   └── FFI:   12/12 invariants hold
   ```

## Proof Inventory
| Proof | Type | Status | Constraint |
|-------|------|--------|-----------|
| GraphProperties.agda | Dependent types | VERIFIED | SC-BDD-012 |
| AcyclicityProofs.agda | Structural induction | VERIFIED | SC-PROM-004 |
| 109 Quint models | Temporal logic | VERIFIED | SC-BDD-011 |
| 12 FFI invariants | Runtime assertions | VERIFIED | SC-FFI-001 |

## SIL-6 Formal Methods Matrix

| Level | Method | Coverage |
|-------|--------|----------|
| L7 (Proofs) | Agda dependent types | Critical paths |
| L6 (Graph) | CFG/DFG analysis | 80%+ |
| L5 (FMEA) | RPN scoring | All safety modules |
| L4 (Property) | PropCheck/FsCheck | Dual testing |
| L3 (BDD) | Cucumber/SpecFlow | Acceptance |
| L2 (Integration) | Wallaby + Chrome | UI E2E flows |
| L1 (Unit) | ExUnit/Expecto | 95%+ |
