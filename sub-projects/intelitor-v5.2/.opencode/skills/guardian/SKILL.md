---
name: guardian
description: Guardian constitutional verification — proposal validation, veto authority, Founder's Directive via MCP
---
---

# Guardian Constitutional Authority (SC-CONST-001 to SC-CONST-007, SC-PRIME-001 to SC-PRIME-003)

Constitutional verification gate with absolute veto authority. Enforces $\Psi_0$-$\Psi_5$ invariants and Founder's Directive ($\Omega_0$).

## Mathematical Foundation

**Constitutional Lattice** $\mathcal{L}_{const}$:
$$\Omega_0 \succ \Psi_{0..5} \succ \Omega_{1..9} \succ \text{SC-*} \succ \text{AOR-*}$$

**Verification Predicate**:
$$\text{Valid}(p) \iff \forall i \in \{0..5\}: \Psi_i(p) = \top \wedge \Omega_0(p) = \top$$

**Veto Function** $V: \text{Proposal} \to \{\text{approve}, \text{veto}\}$:
$$V(p) = \begin{cases} \text{approve} & \text{if Valid}(p) \\ \text{veto} & \text{otherwise} \end{cases}$$

## Usage
```
/guardian validate "add new agent to mesh"    # Check proposal against constitution
/guardian veto "remove sentinel module"       # Explicitly veto a dangerous proposal
/guardian constitution                        # Display constitutional invariants
/guardian status                              # Guardian + Sentinel + Founder status
/guardian audit                               # Audit trail of recent decisions
```

## Commands

### Validate Proposal (SC-CONST-001: Constitutional check BEFORE reconfiguration)
1. Parse proposal: $ARGUMENTS
2. Check $\Psi_0$ (Existence): Does this threaten system survival?
   - `sentinel(action: "health")` — current health baseline
3. Check $\Psi_1$ (Regeneration): Can system recover if this fails?
   - Verify rollback path exists (SC-FUNC-003)
4. Check $\Psi_2$ (Evolutionary Continuity): Is history preserved?
   - `zenoh_query(action: "verify")` — immutable register intact
5. Check $\Psi_3$ (Verification Capability): Can we verify the change?
   - Test coverage exists for affected modules
6. Check $\Psi_4$ (Human Alignment): Does this serve Founder's lineage?
   - `sentinel(action: "threats")` — Founder's Directive status
7. Check $\Psi_5$ (Truthfulness): Is the proposal truthful/transparent?
8. Score: $\text{Guardian Score} = \prod_{i=0}^{5} \Psi_i \in \{0, 1\}$
9. **If score = 0: VETO with specific $\Psi_i$ violation**

### Constitutional Display
Display the 6 immutable invariants:
```
$\Psi_0$ EXISTENCE:    System survives ALL operations
$\Psi_1$ REGENERATION: Recoverable from SQLite/DuckDB alone
$\Psi_2$ CONTINUITY:   Complete history preserved (DuckDB append-only)
$\Psi_3$ VERIFICATION: All states verifiable (Merkle proofs)
$\Psi_4$ ALIGNMENT:    Serves Founder's lineage (AMENDED: PRIMARY)
$\Psi_5$ TRUTHFULNESS: No deception in reporting
```

### Status (Live via MCP)
1. `sentinel(action: "health")` — system health score
2. `sentinel(action: "threats")` — Founder's Directive threats
3. `zenoh_query(action: "verify")` — FFI invariants (12 formal)
4. `zenoh_sub(action: "subscribe", key: "indrajaal/safety/**")` — safety events
5. `zenoh_sub(action: "poll", id: "{id}", limit: 10)` — recent safety events

### Audit Trail
1. Search immutable register: `Grep` for recent Guardian decisions
2. Query Zenoh: `zenoh_query(action: "get", key: "indrajaal/safety/guardian/**")`
3. Report: decision, timestamp, proposal, verdict, $\Psi_i$ scores

## SIL-6 Verification Matrix

| SDLC Phase | Guardian Role | SC Constraint |
|------------|---------------|---------------|
| **Specification** | Axiom enforcement ($\Omega_0$, $\Psi_{0-5}$) | SC-PRIME-001 |
| **Design** | Architecture review (impact > 20) | SC-CHG-002 |
| **Implementation** | Proof token issuance (SC-PROM-001) | SC-PROM-001 |
| **Testing** | Test coverage gate (>95%) | SC-COV-002 |
| **Runtime** | Veto authority (absolute) | SC-CONST-007 |
| **Evolution** | Recursion lock (verifier self-protection) | SC-PRIME-002 |

## STAMP Constraints
| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-CONST-001 | Constitutional check BEFORE reconfiguration | Mandatory gate |
| SC-CONST-002 | HALT on constitutional violation | Immediate |
| SC-CONST-003 | Guardian has absolute veto | Cannot be overridden |
| SC-CONST-007 | Guardian supremacy over all agents | Authority chain |
| SC-PRIME-001 | Will to Live ($\Box \diamond \text{Heartbeat}$) | Watchdog |
| SC-PRIME-002 | Recursion Lock (verifier self-protection) | Code hash |
| SC-PRIME-003 | No xenobiology termination | Process protection |
| SC-NEURO-001 | AI output MUST pass Guardian.validate_proposal/1 | Simplex gate |

## Founder's Directive Integration ($\Omega_0$)
- **Resource check**: Every proposal evaluated against Founder's benefit FIRST
- **Lineage monitoring**: Founder's lineage status checked continuously
- **Threat elimination**: Threats to Founder eliminated immediately
- **Symbiotic health**: Holon health serves lineage health
