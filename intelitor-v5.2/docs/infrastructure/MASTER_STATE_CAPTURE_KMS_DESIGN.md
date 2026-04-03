# Master State Capture & Recovery System with KMS Integration

**Version**: 1.0.0 | **STAMP**: SC-MASTER-001 | **Date**: 2026-01-09
**Architecture**: SIL-6 Biomorphic Fractal Mesh | **Compliance**: IEC 61508 SIL-6

---

## Executive Summary

This document defines a comprehensive state capture and recovery system designed for **AI-evolvable systems** - systems that can be continuously evolved by generative AI agents like Claude. The design integrates with the Knowledge Management System (KMS) to provide rich contextual information for both human operators and AI agents during recovery scenarios.

### Design Goals

1. **Complete State Checkpoint**: Capture ALL stateful artifacts across 7 fractal levels
2. **AI-Agent Recovery Notes**: Machine-readable annotations for autonomous recovery
3. **Human-Readable Documentation**: Clear recovery procedures for operators
4. **Fault-Tolerant Architecture**: HA patterns supporting continuous AI evolution
5. **KMS Integration**: Unified knowledge access for 17+ user group categories

---

## 1. HA/Fault-Tolerant Design Patterns for AI-Evolvable Systems

### 1.1 Core Principles

| Principle | Description | Implementation |
|-----------|-------------|----------------|
| **Immutable State** | All state changes are append-only | Holon Immutable Register |
| **Self-Describing Artifacts** | Every artifact contains its own schema | Embedded JSON metadata |
| **Deterministic Recovery** | Same inputs always produce same state | Merkle DAG verification |
| **Graceful Degradation** | Partial recovery better than total failure | Wave-based startup |
| **AI Comprehensibility** | State format parseable by AI agents | Structured annotations |

### 1.2 HA Architecture Layers

```
┌─────────────────────────────────────────────────────────────────────────┐
│  L7: FEDERATION LAYER (Cross-Cluster HA)                                │
│  ├─ Merkle-chained trust between holons                                 │
│  ├─ Cat-H Functor state synchronization                                 │
│  └─ Version negotiation protocol                                        │
├─────────────────────────────────────────────────────────────────────────┤
│  L6: CLUSTER LAYER (Multi-Node HA)                                      │
│  ├─ 2oo3 voting for critical decisions                                  │
│  ├─ Quorum = floor(N/2) + 1                                             │
│  └─ FPPS 5-method consensus                                             │
├─────────────────────────────────────────────────────────────────────────┤
│  L5: NODE LAYER (Single-Node HA)                                        │
│  ├─ Supervisor tree restart strategies                                  │
│  ├─ Circuit breakers per service                                        │
│  └─ Bulkhead isolation                                                  │
├─────────────────────────────────────────────────────────────────────────┤
│  L4: CONTAINER LAYER (Process HA)                                       │
│  ├─ Health checks every 10s                                             │
│  ├─ Auto-restart on failure                                             │
│  └─ Resource limits enforcement                                         │
├─────────────────────────────────────────────────────────────────────────┤
│  L3: HOLON LAYER (Logical HA)                                           │
│  ├─ SQLite WAL mode journaling                                          │
│  ├─ DuckDB append-only history                                          │
│  └─ Reed-Solomon error correction RS(255,223)                           │
├─────────────────────────────────────────────────────────────────────────┤
│  L2: COMPONENT LAYER (Module HA)                                        │
│  ├─ GenServer state recovery                                            │
│  ├─ ETS table persistence                                               │
│  └─ Process registry failover                                           │
├─────────────────────────────────────────────────────────────────────────┤
│  L1: FUNCTION LAYER (Code HA)                                           │
│  ├─ Idempotent operations                                               │
│  ├─ Transaction rollback capability                                     │
│  └─ Error boundary isolation                                            │
├─────────────────────────────────────────────────────────────────────────┤
│  L0: RUNTIME LAYER (Foundation HA)                                      │
│  ├─ BEAM VM fault tolerance                                             │
│  ├─ Hot code loading                                                    │
│  └─ Distribution protocol                                               │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.3 AI Evolution Safety Patterns

| Pattern | Purpose | STAMP Constraint |
|---------|---------|------------------|
| **Shadow Testing** | Test AI-generated changes before activation | SC-GDE-002 |
| **Guardian Approval** | Human-in-the-loop for critical changes | SC-GDE-001 |
| **Rollback Window** | 24-hour rollback capability | SC-REG-014 |
| **Proposal Threshold** | AI proposals need ≥0.85 confidence | SC-GDE-004 |
| **Immutable Audit Trail** | All AI actions logged permanently | SC-REG-001 |

### 1.4 Five Recovery Strategies (Priority Order)

```
Strategy 1: Reed-Solomon Error Correction
├─ Automatic bit-level repair
├─ No external resources needed
└─ RTO: <1 second

Strategy 2: Local Replica Recovery
├─ Restore from SQLite/DuckDB copy
├─ Same-node operation
└─ RTO: <30 seconds

Strategy 3: Peer Recovery (L6 Federation)
├─ Request state from peer holon
├─ Merkle proof verification
└─ RTO: <5 minutes

Strategy 4: Checkpoint Rollback
├─ Restore from last known-good state
├─ Some recent state loss acceptable
└─ RTO: <15 minutes

Strategy 5: Genesis Regeneration
├─ Full regeneration from constitutional axioms
├─ Last resort when all else fails
└─ RTO: <1 hour
```

---

## 2. Comprehensive State Capture Architecture

### 2.1 State Categories & Capture Methods

| Category | Location | Capture Method | Verification |
|----------|----------|----------------|--------------|
| **Compose Configs** | `lib/cepaf/artifacts/*.yml` | File copy | SHA-256 hash |
| **Nix Definitions** | `devenv.nix`, `devenv.lock` | File copy | Nix hash |
| **F# Scripts** | `lib/cepaf/scripts/*.fsx` | File copy + compile check | F# syntax valid |
| **KMS State** | `data/kms/` | SQLite + DuckDB backup | Integrity check |
| **Container Images** | Podman registry | `podman save` | Image ID match |
| **OTEL Configs** | `config/otel/` | File copy | YAML parse |
| **Environment** | `.env*` files | Sanitized copy | Key presence |
| **Git State** | `.git/` | `git bundle` | Ref verification |

### 2.2 Capture Manifest Structure

```json
{
  "manifest_version": "2.0.0",
  "capture_timestamp": "2026-01-09T12:00:00Z",
  "system_version": "21.3.0-SIL6",
  "capture_agent": "claude-opus-4.5",

  "ai_recovery_notes": {
    "context": "Stable state after successful quality gate pass",
    "dependencies_verified": true,
    "compilation_status": "0 errors, 0 warnings",
    "test_status": "all passing",
    "recommended_recovery_order": [
      "1. Restore data/kms/ directory",
      "2. Load container images",
      "3. Start containers via sa-up",
      "4. Verify health endpoints",
      "5. Run smoke tests"
    ]
  },

  "human_recovery_notes": {
    "summary": "Full system backup taken after v21.3.0 release",
    "contact": "ops@indrajaal.io",
    "runbook": "docs/runbooks/DISASTER_RECOVERY.md",
    "estimated_rto": "15-30 minutes",
    "estimated_rpo": "0 (point-in-time recovery)"
  },

  "artifacts": [
    {
      "path": "lib/cepaf/artifacts/podman-compose-prod-standalone.yml",
      "type": "compose_config",
      "sha256": "abc123...",
      "size_bytes": 12456,
      "fractal_level": "L4",
      "recovery_priority": "P0",
      "ai_annotation": "Primary container orchestration. Must be restored first."
    }
  ],

  "kms_state": {
    "sqlite_path": "data/kms/holons.db",
    "duckdb_path": "data/kms/analytics.duckdb",
    "holon_count": 47,
    "edge_count": 156,
    "event_count": 2341,
    "integrity_verified": true,
    "merkle_root": "0xabc123..."
  },

  "container_state": {
    "images": [
      {
        "name": "localhost/indrajaal-app-unified:nixos-devenv",
        "id": "sha256:abc...",
        "size": "2.1GB",
        "created": "2026-01-08"
      }
    ],
    "networks": ["indrajaal-mesh-network"],
    "volumes": ["indrajaal-db-data", "indrajaal-obs-data"]
  },

  "verification": {
    "checksums_file": "checksums.sha256",
    "all_verified": true,
    "verification_timestamp": "2026-01-09T12:01:00Z"
  }
}
```

### 2.3 Capture Script Enhancement

```bash
#!/bin/bash
# mesh-state-capture-enhanced.sh
# STAMP: SC-BACKUP-001, SC-MASTER-001

set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups/state-${TIMESTAMP}"
MANIFEST="${BACKUP_DIR}/manifest.json"

# Initialize manifest
init_manifest() {
    cat > "${MANIFEST}" << EOF
{
  "manifest_version": "2.0.0",
  "capture_timestamp": "$(date -Iseconds)",
  "system_version": "$(cat VERSION 2>/dev/null || echo 'unknown')",
  "capture_agent": "${CAPTURE_AGENT:-manual}",
  "ai_recovery_notes": {},
  "human_recovery_notes": {},
  "artifacts": [],
  "verification": {}
}
EOF
}

# Add artifact to manifest with AI annotation
add_artifact() {
    local path=$1
    local type=$2
    local level=$3
    local priority=$4
    local annotation=$5

    local sha256=$(sha256sum "$path" | cut -d' ' -f1)
    local size=$(stat -c%s "$path")

    # Use jq to append to manifest
    jq --arg path "$path" \
       --arg type "$type" \
       --arg sha256 "$sha256" \
       --arg size "$size" \
       --arg level "$level" \
       --arg priority "$priority" \
       --arg annotation "$annotation" \
       '.artifacts += [{
         "path": $path,
         "type": $type,
         "sha256": $sha256,
         "size_bytes": ($size | tonumber),
         "fractal_level": $level,
         "recovery_priority": $priority,
         "ai_annotation": $annotation
       }]' "${MANIFEST}" > "${MANIFEST}.tmp" && mv "${MANIFEST}.tmp" "${MANIFEST}"
}

# Capture with annotations
capture_compose_configs() {
    echo "[1/8] Capturing compose configs..."
    mkdir -p "${BACKUP_DIR}/compose"

    for f in lib/cepaf/artifacts/*.yml; do
        cp "$f" "${BACKUP_DIR}/compose/"
        add_artifact "$f" "compose_config" "L4" "P0" \
            "Container orchestration config. Defines service topology."
    done
}

# ... (additional capture functions)
```

---

## 3. KMS Integration for User Group Categories

### 3.1 KMS Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        KMS SERVICE LAYER                                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │  KMS.Service    │  │ KMS.Integrity   │  │ KMS.Federation  │         │
│  │  (GenServer)    │  │ Monitor         │  │ (L6 Sync)       │         │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘         │
│           │                    │                    │                   │
├───────────┴────────────────────┴────────────────────┴───────────────────┤
│                        STORAGE LAYER                                    │
│  ┌─────────────────────────────┐  ┌─────────────────────────────────┐  │
│  │  SQLite (OLTP)              │  │  DuckDB (OLAP)                  │  │
│  │  ├─ holons                  │  │  ├─ holon_events (partitioned)  │  │
│  │  ├─ holon_edges             │  │  ├─ analytics_cache             │  │
│  │  ├─ holon_events            │  │  └─ evolution_history           │  │
│  │  └─ holons_fts (FTS5)       │  │                                 │  │
│  └─────────────────────────────┘  └─────────────────────────────────┘  │
│                                                                         │
│  STAMP: SC-KMS-001 (SQLite+DuckDB only), SC-KMS-002 (Cross-runtime)    │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Developer Use Cases

#### 3.2.1 Onboarding & Orientation
```elixir
# KMS Query: New developer onboarding
KMS.Service.query(:holons, %{
  type: "architecture_decision",
  tags: ["getting-started", "core-concepts"],
  limit: 20
})

# Returns:
# - System architecture overview
# - Key design decisions and rationale
# - Development environment setup
# - Critical STAMP constraints to understand
```

#### 3.2.2 Code Discovery & Navigation
```elixir
# KMS Query: Find modules related to alarm processing
KMS.Service.search("alarm processing", %{
  types: ["module", "function", "test"],
  include_edges: true
})

# Returns graph of related holons with:
# - Module definitions
# - Function signatures
# - Test coverage
# - Dependencies
```

#### 3.2.3 Debugging & Troubleshooting
```elixir
# KMS Query: Find all error patterns for a module
KMS.Service.query(:holon_events, %{
  holon_type: "error_pattern",
  related_to: "lib/indrajaal/alarms/processor.ex",
  severity: ["CRITICAL", "HIGH"]
})

# Returns:
# - Known error patterns (EP-*)
# - Resolution steps
# - Related STAMP constraints
```

#### 3.2.4 Decision Archaeology
```elixir
# KMS Query: Why was this design decision made?
KMS.Service.get_evolution_history("holon-uuid", %{
  event_types: ["design_decision", "architecture_change"],
  include_rationale: true
})

# Returns timeline of decisions with:
# - Original rationale
# - Alternatives considered
# - Trade-offs documented
```

### 3.3 Operations/SRE Use Cases

#### 3.3.1 Runbook Access
```elixir
# KMS Query: Get runbook for alarm storm handling
KMS.Service.query(:holons, %{
  type: "runbook",
  tags: ["alarm-storm", "incident-response"],
  priority: "P0"
})

# Returns structured runbook with:
# - Step-by-step procedures
# - Escalation contacts
# - Recovery time objectives
# - Related metrics dashboards
```

#### 3.3.2 Configuration Management
```elixir
# KMS Query: All configuration for production environment
KMS.Service.query(:holons, %{
  type: "configuration",
  environment: "production",
  include_sensitive: false  # Exclude secrets
})

# Returns:
# - Environment variables
# - Container configurations
# - Network settings
# - Resource limits
```

#### 3.3.3 Capacity Planning
```elixir
# KMS Analytics Query: Resource usage trends
KMS.Service.analytics(:capacity_trends, %{
  metrics: ["cpu", "memory", "disk", "network"],
  period: "30d",
  granularity: "1h"
})

# Returns from DuckDB:
# - Historical resource usage
# - Growth projections
# - Capacity recommendations
```

### 3.4 Technical Leadership Use Cases

#### 3.4.1 Impact Analysis
```elixir
# KMS Query: 5-order impact of changing authentication module
KMS.Service.analyze_impact("lib/indrajaal/auth/", %{
  depth: 5,
  include_tests: true,
  include_deployments: true
})

# Returns fractal impact chain:
# - 1st order: Direct dependencies
# - 2nd order: Transitive dependencies
# - 3rd order: Integration effects
# - 4th order: Operational effects
# - 5th order: Business effects
```

#### 3.4.2 Standards & Governance
```elixir
# KMS Query: All STAMP constraints for a domain
KMS.Service.query(:holons, %{
  type: "stamp_constraint",
  domain: "authentication",
  severity: ["CRITICAL", "HIGH"]
})

# Returns:
# - Constraint definitions
# - Verification methods
# - Violation consequences
```

### 3.5 Additional User Group Categories

| Category | Primary Use Cases | KMS Query Types |
|----------|-------------------|-----------------|
| **API & Integration** | Endpoint discovery, schema validation | `api_endpoint`, `schema`, `integration` |
| **Testing** | Test coverage gaps, property generators | `test`, `property_test`, `coverage` |
| **Code Review** | Pattern violations, quality metrics | `code_quality`, `pattern`, `metric` |
| **Build & Deployment** | Pipeline status, artifact tracking | `pipeline`, `artifact`, `deployment` |
| **Security** | Vulnerability tracking, audit logs | `vulnerability`, `audit`, `compliance` |
| **Performance** | Bottleneck analysis, optimization | `performance`, `profile`, `benchmark` |
| **Migration** | Legacy system mapping, progress | `migration`, `legacy`, `modernization` |
| **Incident Management** | Root cause, post-mortems | `incident`, `rca`, `postmortem` |
| **Database Operations** | Schema changes, query optimization | `schema`, `migration`, `query` |
| **Network Operations** | Topology, connectivity | `network`, `topology`, `endpoint` |
| **Container Operations** | Image history, orchestration | `container`, `image`, `orchestration` |
| **Automation & Tooling** | Script inventory, workflows | `script`, `automation`, `workflow` |
| **Documentation** | Doc coverage, staleness | `documentation`, `coverage`, `staleness` |
| **Vendor Management** | Dependencies, licenses | `dependency`, `license`, `vendor` |
| **Change Management** | Change history, approvals | `change`, `approval`, `rollback` |
| **Compliance & Audit** | Evidence collection, reports | `compliance`, `evidence`, `report` |

---

## 4. 7-Level Fractal Impact Analysis

### 4.1 Impact Matrix for State Capture

| Level | Artifact Type | Capture Priority | Recovery Impact | RTO |
|-------|---------------|------------------|-----------------|-----|
| L0 | Runtime configs | P0 | System boot | <1min |
| L1 | Function definitions | P1 | Code execution | <5min |
| L2 | Module state | P1 | Component health | <5min |
| L3 | Holon state (SQLite/DuckDB) | P0 | Logical integrity | <10min |
| L4 | Container images | P0 | Service availability | <15min |
| L5 | Node configurations | P1 | Environment stability | <20min |
| L6 | Cluster state | P2 | HA capabilities | <30min |
| L7 | Federation state | P2 | Cross-system sync | <1hr |

### 4.2 Corruption Cascade Analysis

```
L0 Corruption (Runtime) → TOTAL SYSTEM FAILURE
│
├─► L1 Impact: All functions unavailable
├─► L2 Impact: All modules fail to load
├─► L3 Impact: Holons cannot be accessed
├─► L4 Impact: Containers cannot start
├─► L5 Impact: Node becomes unresponsive
├─► L6 Impact: Cluster loses quorum
└─► L7 Impact: Federation isolated

Recovery: Genesis Regeneration (Strategy 5)
RTO: 30-60 minutes
```

---

## 5. Integration with Existing Scripts

### 5.1 Script Enhancement Matrix

| Script | Current Function | Enhancement |
|--------|------------------|-------------|
| `mesh-state-capture.sh` | Basic capture | Add AI annotations, manifest |
| `mesh-recovery.sh` | Basic restore | Add verification, rollback |
| `mesh-verify.sh` | Checksum verify | Add integrity chain |
| `mesh-quick-snapshot.sh` | Fast backup | Add incremental capture |
| `mesh-emergency-recovery.sh` | Emergency restore | Add partial recovery |
| `mesh-image-backup.sh` | Image export | Add manifest integration |
| `mesh-image-recovery.sh` | Image import | Add verification |

### 5.2 New Scripts Required

1. **mesh-kms-sync.sh**: Sync KMS state to backup
2. **mesh-manifest-verify.sh**: Validate manifest integrity
3. **mesh-ai-recovery.sh**: AI-guided recovery with annotations
4. **mesh-partial-restore.sh**: Selective component restoration

---

## 6. STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-MASTER-001 | All state changes captured with manifest | CRITICAL |
| SC-MASTER-002 | AI annotations required for all artifacts | HIGH |
| SC-MASTER-003 | Human notes required for P0 artifacts | HIGH |
| SC-MASTER-004 | KMS state included in all captures | CRITICAL |
| SC-MASTER-005 | Verification chain unbroken | CRITICAL |
| SC-MASTER-006 | Recovery tested monthly | HIGH |
| SC-MASTER-007 | RTO targets documented and tested | HIGH |

## 7. AOR Rules

| ID | Rule |
|----|------|
| AOR-MASTER-001 | Capture state after every successful quality gate |
| AOR-MASTER-002 | Include AI recovery notes in all captures |
| AOR-MASTER-003 | Test recovery from captures quarterly |
| AOR-MASTER-004 | Update KMS with capture metadata |
| AOR-MASTER-005 | Verify checksums before recovery |
| AOR-MASTER-006 | Document RTO for each recovery scenario |

---

## 8. Implementation Roadmap

### Phase 1: Enhanced Capture (Current)
- [x] Design document complete
- [ ] Enhance mesh-state-capture.sh with manifest
- [ ] Add AI annotation templates
- [ ] Integrate KMS state capture

### Phase 2: KMS Integration
- [ ] Create KMS query interfaces for all user groups
- [ ] Build analytics dashboards
- [ ] Implement search across holons

### Phase 3: Recovery Automation
- [ ] Create AI-guided recovery script
- [ ] Implement partial restoration
- [ ] Build verification chain

### Phase 4: Testing & Validation
- [ ] Monthly recovery drills
- [ ] RTO validation tests
- [ ] Documentation updates

---

**Document Control**
| Field | Value |
|-------|-------|
| Author | Claude Opus 4.5 |
| Created | 2026-01-09 |
| STAMP | SC-MASTER-001 to SC-MASTER-007 |
| AOR | AOR-MASTER-001 to AOR-MASTER-006 |
