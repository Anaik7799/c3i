---
paths: lib/indrajaal/safety/**/*.ex, lib/indrajaal/core/**/*.ex
---

# Safety-Critical Code Rules (v21.2.1-SIL6)

These modules are subject to IEC 61508 SIL-6 compliance (Biomorphic Extended).

## Critical Safety Modules (Immune System)

### Guardian (`lib/indrajaal/safety/guardian.ex`)
- **Role**: Absolute veto authority over all reconfigurations (SC-CONST-007)
- **Rule**: All state mutations require Guardian approval (SC-GDE-001)
- **Pattern**: Shadow testing MANDATORY before activation (SC-GDE-002)

### Sentinel (`lib/indrajaal/safety/sentinel.ex`)
- **Role**: Digital T-Cell immune system for anomaly detection
- **Rule**: Health scoring with quarantine protocol (SC-IMMUNE-001)
- **Pattern**: Circuit breaker at error rate > 10% (SC-IMMUNE-002)
- **Constraints**: SC-IMMUNE-001 to SC-IMMUNE-010

### PatternHunter (`lib/indrajaal/safety/pattern_hunter.ex`)
- **Role**: Memory leak and resource consumption detection
- **Rule**: Continuous pattern analysis with threat scoring
- **Pattern**: Alert on sustained >80% memory for >5 minutes (SC-IMMUNE-003)

### SymbioticDefense (`lib/indrajaal/safety/symbiotic_defense.ex`)
- **Role**: Coordinated multi-module defense response
- **Rule**: Threat-level-based escalation protocol
- **Pattern**: Founder's Directive protection (SC-FOUNDER-007)

## Cross-Cutting Constraint References
> SC-HOLON-001 to SC-HOLON-020, AOR-HOLON-001 to AOR-HOLON-020: Holon state sovereignty — see CLAUDE.md §5.0, §9.0
> SC-REG-001+, AOR-REG-001 to AOR-REG-012: Immutable register append-only blocks — see CLAUDE.md §5.0, §9.0
> SC-DBLOCAL-001 to SC-DBLOCAL-004: Local database access (WAL, pooling, <1ms) — see CLAUDE.md §5.0
> SC-DBCROSS-001 to SC-DBCROSS-004: Cross-holon access via Zenoh only (saga, version vectors) — see CLAUDE.md §5.0
> SC-CONST-001+, AOR-CONST-001 to AOR-CONST-005: Constitutional governance, Guardian supremacy — see CLAUDE.md §5.0, §9.0

## Mandatory Patterns

### Error Handling
- Always return `{:ok, result}` or `{:error, reason}`
- Never use bare `raise` without rescue
- Document all failure modes in @moduledoc
- Record failure events to DuckDB history (SC-HOLON-014)

### State Management
- Holon state MUST use SQLite/DuckDB only (SC-HOLON-001)
- NO PostgreSQL for holon state (SC-HOLON-005)
- All mutations via immutable register (SC-REG-001)
- Hash chain MUST be unbroken (SC-REG-002)

### Logging (5-Level Fractal)
- Use structured logging with Telemetry
- Include STAMP constraint references in log metadata
- Fractal levels:
  - **L5-SPINE**: Strategic/Executive (permanent retention)
  - **L4-THORAX**: Subsystem health (30-day retention)
  - **L3-SEGMENT**: Component activity (7-day retention)
  - **L2-FIBER**: Detailed operations (24-hour retention)
  - **L1-GOSSAMER**: Debug/trace (ephemeral)

### Testing
- 100% branch coverage required
- FMEA analysis for failure modes
- Property tests for all public functions
- Tests MUST run with SKIP_ZENOH_NIF=0 (SC-TEST-NIF-001)


### Color Rich & Interface Profiles (SC-HMI-010)
- **Mandate**: Shift from Dark Cockpit to **Color Rich Mechanism**.
- **Implementation**: Support 4 selectable profiles: Dark Cockpit, Color Rich, Google Compliant, Functionally Clean.
- **Visuals**: Vibrant colors for healthy states; dynamic chromaticism linked to Zenoh telemetry.
- **Audit**: Follow **8x8 Fractal Matrix** (8 Elements x 8 Layers) for all UI verification.
- **Completeness**: 100% path coverage for data/control flows across all matrix cells.
