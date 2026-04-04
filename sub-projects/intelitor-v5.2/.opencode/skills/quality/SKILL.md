---
name: quality
description: SIL-6 quality gate pipeline (format, credo, dialyzer, sobelow) with Zenoh telemetry
---

# Quality Gate Command (SC-QUA-001, $\Omega_3$ Zero-Defect, $\Omega_6$ Mandatory Gates)

SIL-6 quality pipeline with formal gate verification and Zenoh telemetry.

## Mathematical Foundation

**Quality Predicate** $\mathcal{Q}$:
$$\mathcal{Q}(S) \iff \sum(\text{FormatFails} + \text{CredoIssues} + \text{DialyzerErrors} + \text{SobelowVulns}) \equiv 0$$

**Gate Lattice** $\mathcal{G} = (G_1, G_2, G_3, G_4)$:
$$G_1 \preceq G_2 \preceq G_3 \preceq G_4, \quad \text{Pass} = \bigwedge_{i=1}^{4} G_i$$

**Quality Score** $Q: S \to [0, 100]$:
$$Q(S) = 25 \cdot G_1 + 25 \cdot G_2 + 25 \cdot G_3 + 25 \cdot G_4$$

## Pipeline ($\Omega_6$: Feature Complete $\iff$ All Gates Pass)

### Gate 1: Format
```bash
mix format --check-formatted
```

### Gate 2: Credo (Static Analysis)
```bash
mix credo --strict
```

### Gate 3: Dialyzer (Type Checking)
```bash
mix dialyzer
```

### Gate 4: Sobelow (Security)
```bash
mix sobelow --exit
```

## Post-Gate Verification (SIL-6)

1. Report: PASS/FAIL per gate with $Q(S)$ score
2. For failures: actionable fix + SC-* reference
3. **Health check**: `sentinel(action: "health")` — correlate quality with health
4. **Publish**: `zenoh_pub(key: "indrajaal/quality/gate", payload: "{score}")`
5. If $Q(S) < 100$: list remediation priority by FMEA RPN

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-GEM-003 | mix format after generation |
| SC-CREDO-001 | Direct calls (no apply) |
| SC-CREDO-002 | DRY mandate (extract 3+ line duplicates) |
| SC-SEC-044 | Sobelow security check |
| SC-SEC-047 | Encryption mandatory |
| SC-CMP-025 | 0 warnings |
| SC-CMP-026 | All files compiled |
| SC-DOC-001 | moduledoc with WHAT/WHY/CONSTRAINTS |
| SC-DOC-006 | Document DSL blocks |

## SIL-6 SDLC Coverage

| Phase | Gate | Constraint |
|-------|------|-----------|
| **Impl** | Format consistency | SC-GEM-003 |
| **Test** | Static analysis | SC-CREDO-001 |
| **Runtime** | Type safety | SC-PROM-004 |
| **Evolution** | Security scan | SC-SEC-044 |
