# Holon Database Naming System Specification
## Version 21.3.0-SIL6 | 2026-01-17

---

## Executive Summary

This specification defines a **scalable, unified naming system** for all holon-specific databases across the Indrajaal biomorphic mesh. The system ensures clear mapping between holons, their databases, and enables seamless cross-holon communication via Zenoh pub/sub.

**STAMP Constraints**: SC-DBNAME-001 to SC-DBNAME-020
**Status**: SPECIFICATION COMPLETE
**Scope**: All Elixir holons, F# holons, and cross-holon interoperability

---

## 1.0 Naming System Architecture

### 1.1 Universal Holon Identifier (UHI)

Every holon in the system receives a **Universal Holon Identifier (UHI)** following this format:

```
UHI Format: {runtime}:{layer}:{domain}:{type}:{instance}

Components:
├── runtime   : ex | fs | zig | rs    (Elixir, F#, Zig, Rust)
├── layer     : l0-l7                 (Fractal layer)
├── domain    : 3-letter domain code  (kms, prj, grd, snt, etc.)
├── type      : holon type code       (srv, agt, reg, etc.)
└── instance  : unique instance id    (ULID or node-specific)

Examples:
  ex:l3:kms:srv:01JCZX0Y1234567890AB  # Elixir L3 KMS Service
  fs:l4:prj:agt:prajna-cockpit-001    # F# L4 Prajna Agent
  ex:l5:grd:reg:guardian-main         # Elixir L5 Guardian Register
```

### 1.2 Database Path Template

Database files follow a deterministic path based on the UHI:

```
Path Template:
data/holons/{runtime}/{layer}/{domain}/{instance}/
├── state.sqlite       # OLTP real-time state (SQLite WAL)
├── history.duckdb     # OLAP append-only history (DuckDB)
├── vectors.sqlite     # Semantic embeddings (SQLite)
├── keypair.bin        # Ed25519 keypair (binary)
└── manifest.json      # Holon metadata & schema version

Full Path Example:
data/holons/ex/l3/kms/01JCZX0Y1234567890AB/
├── state.sqlite
├── history.duckdb
├── vectors.sqlite
├── keypair.bin
└── manifest.json
```

### 1.3 Naming Hierarchy

```
┌─────────────────────────────────────────────────────────────────────┐
│                    HOLON DATABASE NAMING HIERARCHY                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Level 1: Runtime Partition                                         │
│  ├── ex/     (Elixir holons - BEAM runtime)                        │
│  ├── fs/     (F# holons - .NET runtime)                            │
│  ├── zig/    (Zig holons - native binary)                          │
│  └── rs/     (Rust holons - native binary)                         │
│                                                                      │
│  Level 2: Fractal Layer                                             │
│  ├── l0/     (Runtime - OS/VM level)                               │
│  ├── l1/     (Function - single operation)                         │
│  ├── l2/     (Component - module level)                            │
│  ├── l3/     (Holon - autonomous agent)                            │
│  ├── l4/     (Container - isolation unit)                          │
│  ├── l5/     (Node - machine level)                                │
│  ├── l6/     (Cluster - consensus group)                           │
│  └── l7/     (Federation - global mesh)                            │
│                                                                      │
│  Level 3: Domain                                                     │
│  ├── kms/    (Knowledge Management System)                         │
│  ├── prj/    (Prajna C3I Cockpit)                                  │
│  ├── grd/    (Guardian Safety Kernel)                              │
│  ├── snt/    (Sentinel Health Monitor)                             │
│  ├── imm/    (Immutable Register)                                  │
│  ├── zen/    (Zenoh Communication)                                 │
│  ├── bio/    (Biomorphic Systems)                                  │
│  ├── pln/    (Planning System)                                     │
│  ├── tst/    (Test Infrastructure)                                 │
│  └── obs/    (Observability)                                       │
│                                                                      │
│  Level 4: Type                                                       │
│  ├── srv/    (Service)                                             │
│  ├── agt/    (Agent)                                               │
│  ├── reg/    (Register/Registry)                                   │
│  ├── str/    (Store)                                               │
│  ├── brg/    (Bridge)                                              │
│  ├── pub/    (Publisher)                                           │
│  ├── sub/    (Subscriber)                                          │
│  └── wrk/    (Worker)                                              │
│                                                                      │
│  Level 5: Instance                                                   │
│  ├── ULID (26-char) for dynamic instances                          │
│  ├── Named (kebab-case) for singleton instances                    │
│  └── Node-qualified ({name}@{node}) for distributed                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2.0 Domain Codes (Complete Registry)

### 2.1 Core Domains

| Code | Domain | Description | Primary Runtime |
|------|--------|-------------|-----------------|
| `kms` | Knowledge Management | SMRITI holons, knowledge graph | Elixir + F# |
| `prj` | Prajna | C3I Cockpit, command & control | Elixir + F# |
| `grd` | Guardian | Safety kernel, approval flows | Elixir |
| `snt` | Sentinel | Health monitoring, threat detection | Elixir |
| `imm` | Immutable | Append-only registers, hash chains | Elixir |
| `fnd` | Founder | Ω₀ Founder's Directive persistence | Elixir |

### 2.2 Infrastructure Domains

| Code | Domain | Description | Primary Runtime |
|------|--------|-------------|-----------------|
| `zen` | Zenoh | Pub/sub communication | Elixir + F# |
| `brg` | Bridge | Cross-runtime bridges | F# |
| `obs` | Observability | Metrics, traces, logs | Elixir + F# |
| `msh` | Mesh | SIL-6 mesh coordination | F# |

### 2.3 Application Domains

| Code | Domain | Description | Primary Runtime |
|------|--------|-------------|-----------------|
| `pln` | Planning | Task management, OODA | F# |
| `bio` | Biomorphic | Self-healing, immune system | Elixir |
| `evo` | Evolution | Genetic algorithms, fitness | Elixir |
| `ctx` | Cortex | AI cognitive layer | F# |

### 2.4 Development Domains

| Code | Domain | Description | Primary Runtime |
|------|--------|-------------|-----------------|
| `tst` | Test | Test infrastructure | Elixir + F# |
| `dev` | Developer | Dev knowledge capture | Elixir |
| `sre` | SRE | Operational excellence | Elixir |
| `prd` | Product | Product lifecycle | Elixir |

---

## 3.0 Database File Naming Convention

### 3.1 Standard Database Files

Each holon directory contains standardized database files:

| File | Format | Purpose | Access Pattern |
|------|--------|---------|----------------|
| `state.sqlite` | SQLite WAL | Real-time OLTP state | High-frequency R/W |
| `history.duckdb` | DuckDB | Append-only OLAP history | Append + Analytics |
| `vectors.sqlite` | SQLite | Semantic embeddings | Read-heavy |
| `keypair.bin` | Binary | Ed25519 keys | Read-only after init |
| `manifest.json` | JSON | Metadata, schema version | Read + rare update |

### 3.2 Special Files

| File | Purpose | Location |
|------|---------|----------|
| `register.duckdb` | Immutable hash chain | `{domain}/imm/` only |
| `federation.duckdb` | Cross-holon attestation | `l6/` and `l7/` only |
| `analytics.duckdb` | Domain-wide analytics | `{domain}/` root |

### 3.3 Archive Files

| Pattern | Format | Purpose |
|---------|--------|---------|
| `archive/{YYYY}/{MM}/{DD}/*.parquet` | Parquet | Cold storage |
| `snapshots/{timestamp}.tar.zst` | Compressed tar | Point-in-time backup |

---

## 4.0 Fully Qualified Database Name (FQDN)

### 4.1 FQDN Format

```
FQDN = {UHI}:{database_type}

Database Types:
├── state    → state.sqlite
├── history  → history.duckdb
├── vectors  → vectors.sqlite
├── register → register.duckdb
└── analytics → analytics.duckdb

Examples:
  ex:l3:kms:srv:main:state      → data/holons/ex/l3/kms/main/state.sqlite
  fs:l4:prj:agt:cockpit:history → data/holons/fs/l4/prj/cockpit/history.duckdb
  ex:l5:grd:reg:guardian:register → data/holons/ex/l5/grd/guardian/register.duckdb
```

### 4.2 FQDN Resolution

```elixir
# Elixir Resolution
defmodule Indrajaal.Holon.DatabasePath do
  @base_path "data/holons"

  def resolve(fqdn) when is_binary(fqdn) do
    [uhi, db_type] = String.split(fqdn, ":")
    [runtime, layer, domain, type, instance] = String.split(uhi, ":")

    file_name = case db_type do
      "state" -> "state.sqlite"
      "history" -> "history.duckdb"
      "vectors" -> "vectors.sqlite"
      "register" -> "register.duckdb"
      "analytics" -> "analytics.duckdb"
    end

    Path.join([@base_path, runtime, layer, domain, instance, file_name])
  end
end

# F# Resolution
module Cepaf.Holon.DatabasePath

let basePath = "data/holons"

let resolve (fqdn: string) =
    let parts = fqdn.Split(':')
    let [| runtime; layer; domain; htype; instance; dbType |] = parts
    let fileName =
        match dbType with
        | "state" -> "state.sqlite"
        | "history" -> "history.duckdb"
        | "vectors" -> "vectors.sqlite"
        | "register" -> "register.duckdb"
        | "analytics" -> "analytics.duckdb"
        | _ -> failwith $"Unknown db type: {dbType}"
    Path.Combine(basePath, runtime, layer, domain, instance, fileName)
```

---

## 5.0 Cross-Holon Database Access

### 5.1 Access Matrix

| Access Type | Same Runtime | Different Runtime | Method |
|-------------|--------------|-------------------|--------|
| LOCAL state read | Direct | Via Zenoh | Native library |
| LOCAL state write | Direct | Via Zenoh | Native library |
| REMOTE state read | Via Zenoh | Via Zenoh | Zenoh pub/sub |
| REMOTE state write | Via Zenoh | Via Zenoh | Zenoh pub/sub |
| Analytics query | Direct | Via Zenoh | DuckDB |

### 5.2 Zenoh Topic Mapping

```
Zenoh Topic Template:
indrajaal/db/{runtime}/{layer}/{domain}/{instance}/{operation}

Operations:
├── query      → SELECT operations
├── execute    → INSERT/UPDATE/DELETE
├── subscribe  → Change notifications
└── analytics  → DuckDB queries

Examples:
  indrajaal/db/ex/l3/kms/main/query
  indrajaal/db/fs/l4/prj/cockpit/execute
  indrajaal/db/ex/l5/grd/guardian/subscribe
```

### 5.3 Cross-Runtime Bridge

```
┌──────────────────────────────────────────────────────────────────┐
│                CROSS-RUNTIME DATABASE ACCESS                      │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Elixir Holon                         F# Holon                   │
│  ┌─────────────────┐                  ┌─────────────────┐        │
│  │ KMS.Service     │                  │ Cepaf.Database  │        │
│  │                 │                  │                 │        │
│  │ LOCAL ACCESS:   │                  │ LOCAL ACCESS:   │        │
│  │ Exqlite/Duckdbex│                  │ Microsoft.Data  │        │
│  │ (Direct)        │                  │ /DuckDB.NET     │        │
│  └────────┬────────┘                  └────────┬────────┘        │
│           │                                    │                  │
│           │ CROSS-HOLON ACCESS                │                  │
│           │                                    │                  │
│           ▼                                    ▼                  │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │                    ZENOH PUB/SUB                         │     │
│  │                                                          │     │
│  │  Topic: indrajaal/db/{uhi}/request                      │     │
│  │  Topic: indrajaal/db/{uhi}/response                     │     │
│  │                                                          │     │
│  └─────────────────────────────────────────────────────────┘     │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 6.0 Migration from Legacy Paths

### 6.1 Legacy Path Mapping

| Legacy Path | New Path | Migration Status |
|-------------|----------|------------------|
| `data/kms/{node}/holons.db` | `data/holons/ex/l3/kms/{node}/state.sqlite` | PLANNED |
| `data/kms/{node}/analytics.duckdb` | `data/holons/ex/l3/kms/{node}/history.duckdb` | PLANNED |
| `data/holons/founder_directive/state.sqlite` | `data/holons/ex/l5/fnd/founder/state.sqlite` | PLANNED |
| `data/holons/founder_directive/history.duckdb` | `data/holons/ex/l5/fnd/founder/history.duckdb` | PLANNED |
| `data/holons/prajna_register.duckdb` | `data/holons/ex/l5/prj/main/register.duckdb` | PLANNED |
| `data/smriti/planning.db` | `data/holons/fs/l4/pln/main/state.sqlite` | PLANNED |
| `lib/cepaf/artifacts/cepa-state.db` | `data/holons/fs/l2/brg/cepaf/state.sqlite` | PLANNED |

### 6.2 Migration Script

```elixir
# Migration will be handled by:
# scripts/holon/migrate_database_paths.exs
```

---

## 7.0 STAMP Constraints

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-DBNAME-001 | All holon databases MUST follow UHI naming | CRITICAL | Path validation |
| SC-DBNAME-002 | FQDN resolution MUST be deterministic | CRITICAL | Unit tests |
| SC-DBNAME-003 | Runtime prefix MUST match actual runtime | HIGH | Compile-time check |
| SC-DBNAME-004 | Layer MUST match holon fractal position | HIGH | Registration check |
| SC-DBNAME-005 | Domain code MUST be registered | HIGH | Registry lookup |
| SC-DBNAME-006 | Instance ID MUST be unique within domain | CRITICAL | Collision check |
| SC-DBNAME-007 | Database files MUST use standard names | HIGH | File validation |
| SC-DBNAME-008 | Cross-runtime access MUST use Zenoh | CRITICAL | Access check |
| SC-DBNAME-009 | LOCAL access MUST be direct (no Zenoh) | HIGH | Performance check |
| SC-DBNAME-010 | Manifest MUST exist for every holon | HIGH | Startup validation |

---

## 8.0 AOR Rules

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-DBNAME-001 | Use `DatabasePath.resolve/1` for all path resolution | Code review |
| AOR-DBNAME-002 | Register new domains in HOLON_DATABASE_NAMING_SYSTEM.md | PR check |
| AOR-DBNAME-003 | Create manifest.json when initializing holon | Init hook |
| AOR-DBNAME-004 | Never hardcode database paths | Grep check |
| AOR-DBNAME-005 | Use FQDN in all cross-holon references | API check |
| AOR-DBNAME-006 | Migrate legacy paths before v22.0.0 | Deprecation warnings |

---

## 9.0 Manifest Schema

### 9.1 manifest.json Structure

```json
{
  "$schema": "https://indrajaal.dev/schemas/holon-manifest-v1.json",
  "version": "1.0.0",
  "uhi": "ex:l3:kms:srv:main",
  "fqun": "kms/l3/knowledge/default/main@indrajaal",
  "created_at": "2026-01-17T10:00:00Z",
  "updated_at": "2026-01-17T10:00:00Z",
  "runtime": {
    "type": "elixir",
    "version": "1.19.0",
    "otp": "28"
  },
  "databases": {
    "state": {
      "type": "sqlite",
      "version": "3.47.0",
      "wal_mode": true,
      "schema_version": 3
    },
    "history": {
      "type": "duckdb",
      "version": "1.2.0",
      "schema_version": 2
    }
  },
  "capabilities": ["read", "write", "replicate"],
  "parent_uhi": null,
  "children_uhi": [],
  "zenoh_topics": {
    "publish": ["indrajaal/db/ex/l3/kms/main/state"],
    "subscribe": ["indrajaal/coord/heartbeat"]
  },
  "checksum": "sha256:abc123..."
}
```

---

## 10.0 Complete Holon Registry

### 10.1 Elixir Holons (ex:*)

| UHI | Description | Databases |
|-----|-------------|-----------|
| `ex:l3:kms:srv:main` | Main KMS service | state, history, vectors |
| `ex:l3:kms:str:smriti` | SMRITI knowledge store | state, history |
| `ex:l5:fnd:reg:founder` | Founder Directive register | state, history, register |
| `ex:l5:prj:srv:prajna` | Prajna cockpit service | state, history, register |
| `ex:l5:grd:reg:guardian` | Guardian safety kernel | state, register |
| `ex:l5:snt:srv:sentinel` | Sentinel health monitor | state, history |
| `ex:l3:bio:srv:immune` | Digital immune system | state, history |
| `ex:l3:evo:srv:evolution` | Test evolution engine | state, history |
| `ex:l2:obs:pub:telemetry` | Telemetry publisher | state |
| `ex:l4:zen:brg:database` | Zenoh database proxy | state |

### 10.2 F# Holons (fs:*)

| UHI | Description | Databases |
|-----|-------------|-----------|
| `fs:l4:prj:agt:cockpit` | Prajna F# cockpit agent | state, history |
| `fs:l4:pln:srv:planning` | Planning system service | state, history |
| `fs:l3:kms:str:catalog` | KMS catalog store | state, history |
| `fs:l2:brg:srv:cepaf` | CEPAF bridge service | state |
| `fs:l4:ctx:srv:cortex` | Cortex AI service | state, vectors |
| `fs:l3:obs:srv:observer` | Observability service | state, history |

---

## 11.0 Implementation Checklist

### Phase 1: Specification (CURRENT)
- [x] Define naming system
- [x] Create domain registry
- [x] Document FQDN format
- [x] Specify migration paths

### Phase 2: Core Implementation
- [ ] Implement Elixir `DatabasePath` module
- [ ] Implement F# `DatabasePath` module
- [ ] Create manifest generator
- [ ] Add validation hooks

### Phase 3: Migration
- [ ] Create migration script
- [ ] Test migration paths
- [ ] Update all hardcoded paths
- [ ] Deprecate legacy paths

### Phase 4: Verification
- [ ] Unit tests for path resolution
- [ ] Integration tests for cross-holon access
- [ ] Performance benchmarks
- [ ] STAMP constraint verification

---

## 12.0 Related Documents

- `HOLON_FOUNDERS_DIRECTIVE.md` - Supreme covenant
- `HOLON_IMMORTAL_ARCHITECTURE.md` - Species-scale survival
- `HOLON_IMMUTABLE_REGISTER.md` - Blockchain-type state
- `ZENOH_CROSS_HOLON_DATABASE_SPECIFICATION.md` - Cross-holon access
- `HOLON_FORMAL_SPECIFICATION.md` - Mathematical foundations

---

**Document Control**
- Author: Claude Opus 4.5
- Date: 2026-01-17
- Version: 1.0.0
- STAMP: SC-DBNAME-001 to SC-DBNAME-010
- Status: SPECIFICATION COMPLETE
