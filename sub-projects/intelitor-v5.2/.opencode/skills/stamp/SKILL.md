---
name: stamp
description: allowed-tools: Read, Grep, Glob, mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__zenoh_query
---
---

# STAMP Safety Constraint Validator (641+ Constraints, 55+ Families)

Validate code against STAMP safety constraints with optional live Zenoh/Sentinel verification.

## Constraint Families (55+):
- **SC-VAL-***: Validation (Patient Mode, consensus)
- **SC-CNT-***: Container (NixOS/Podman, rootless)
- **SC-AGT-***: Agent (efficiency, deadlocks, authority)
- **SC-CMP-***: Compilation (0 warnings, all files)
- **SC-SEC-***: Security (Sobelow, encryption)
- **SC-PRF-***: Performance (<50ms response)
- **SC-EMR-***: Emergency (stop <5s, rollback)
- **SC-OBS-***: Observability (dual log, OTEL)
- **SC-HOLON-***: Holon state sovereignty (SQLite/DuckDB)
- **SC-REG-***: Immutable register (append-only, SHA3)
- **SC-CONST-***: Constitutional governance
- **SC-IMMUNE-***: Digital Immune System
- **SC-SIL6-***: Biomorphic mesh safety
- **SC-ZENOH-***: Zenoh telemetry mandatory
- **SC-ZTEST-***: Zenoh test messaging
- **SC-MESH-***: F# mesh orchestration
- **SC-SYNC-PLAN-***: Planning↔Chaya sync
- **SC-TODO-***: Todolist access control
- **SC-CHG-***: Change management
- **SC-AI-***: Intelligence amplification
- **SC-MATH-***: Mathematical disciplines
- **SC-NET-***: .NET 10.0 framework
- **SC-FFI-***: F# Zenoh FFI
- **SC-DBNAME-***: UHI database naming
- **SC-DBLOCAL-***: Local DB access
- **SC-DBCROSS-***: Cross-holon DB access

## Validation Steps:
1. Read the target file: $ARGUMENTS
2. Extract all constraint references (SC-*, AOR-*)
3. Check compliance with each constraint from CLAUDE.md §5.0
4. For live constraints, verify via MCP:
   - Sentinel health: `sentinel(action: "health")` for SC-IMMUNE-*
   - Zenoh metrics: `zenoh_query(action: "metrics")` for SC-ZENOH-*
   - FFI invariants: `zenoh_query(action: "verify")` for SC-FFI-*
5. Report violations with severity (CRITICAL/HIGH/MEDIUM/LOW)
6. Suggest remediation per constraint documentation
7. Map to fractal layer (L0-L7)

## Mathematical Foundation

**Constraint Satisfaction** (formal predicate):

$$\text{Compliant}(M) \iff \forall c \in \text{SC}(M) : \text{Satisfied}(c, M) = \top$$

where $\text{SC}(M)$ is the set of all constraints applicable to module $M$.

**Coverage Metric**:

$$C_{stamp} = \frac{|\{c \in \mathcal{C} : \text{Verified}(c)\}|}{|\mathcal{C}|}, \quad |\mathcal{C}| = 641+$$

**Constraint Density** (per module):

$$\rho(M) = \frac{|\text{SC}(M)|}{|\text{LOC}(M)|}$$

Higher density = more safety-critical code. Typical: $\rho > 0.05$ for safety modules.

**Violation Severity Score**:

$$V_{score} = \sum_{i} S_i \times P_i, \quad S \in \{1, 2, 4, 8, \infty\}, \quad P \in \{L, M, H, C, \infty\}$$

## Severity Hierarchy:
- **INFINITE**: Ψ₀-Ψ₅ constitutional, Founder's Directive
- **CRITICAL**: System safety (SC-SIL6, SC-IMMUNE, SC-EMR)
- **HIGH**: Operational integrity (SC-HOLON, SC-REG, SC-ZENOH)
- **MEDIUM**: Quality gates (SC-CMP, SC-SEC, SC-OBS)
- **LOW**: Best practices (SC-DOC, SC-BATCH)

## STAMP Constraint Families (55+, 641+ constraints)
| Family | Count | Severity | Skill Coverage |
|--------|-------|----------|---------------|
| SC-SIL6-* | 15+ | CRITICAL | `/sil6`, `/mesh` |
| SC-HOLON-* | 20+ | HIGH | `/holon` |
| SC-SYNC-PLAN-* | 20 | CRITICAL | `/plan` |
| SC-REG-* | 12+ | HIGH | `/registry` |
| SC-UCR-* | 15 | HIGH | `/checkpoint`, `/registry` |
| SC-ZTEST-* | 20 | HIGH | `/zenoh`, `/test` |
| SC-IMMUNE-* | 10+ | CRITICAL | `/sentinel`, `/immune` |
| SC-BIO-EXT-* | 9 | CRITICAL | `/robustness`, `/immune` |
| SC-CONST-* | 7+ | INFINITE | `/guardian` |
| SC-PROM-* | 7 | CRITICAL | `/prometheus` |
| SC-PRIME-* | 3 | INFINITE | `/guardian`, `/prometheus` |
| SC-TODO-* | 9 | CRITICAL | `/plan` |
| SC-DBNAME-* | 10+ | HIGH | `/database` |
| SC-CHG-* | 10 | HIGH | `/impact`, `/review` |
| SC-SEC-* | 4+ | HIGH | `/kms`, `/oracle` |
| SC-FRAC-* | 6 | HIGH | `/federation` |
| SC-MATH-* | 8 | MEDIUM | `/sil6` |
| SC-NET-* | 2 | CRITICAL | `/cepaf-test`, `/compile` |
| SC-FFI-* | 2 | HIGH | `/zenoh`, `/cepaf-test` |
