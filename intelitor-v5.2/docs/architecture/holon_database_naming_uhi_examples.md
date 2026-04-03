# HOLON_DATABASE_NAMING_SYSTEM UHI Path Examples

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-XHOLON-001, SC-DIST-001, SC-FQUN-001

## Overview

The Universal Holon Identifier (UHI) provides a hierarchical path system for addressing
holons, their databases, and their Zenoh topics. This document provides 10 concrete
examples covering all holon types and access patterns.

## UHI Path Format

```
indrajaal://<federation>/<cluster>/<holon-type>/<holon-id>[/<resource>]
```

## Example 1: Local Development App Holon

```
FQUN:     indrajaal://local/dev/app/seed-01
DB Path:  data/holons/seed-01/state.db
DuckDB:   data/holons/seed-01/analytics.duckdb
Zenoh:    indrajaal/local/dev/app/seed-01/**
Health:   indrajaal/local/dev/app/seed-01/health
Container: indrajaal-ex-app-1
```

## Example 2: Production Database Holon

```
FQUN:     indrajaal://naik-primary/prod-eu-west-1/db/primary
DB Path:  data/holons/primary/state.db
DuckDB:   data/holons/primary/analytics.duckdb
Zenoh:    indrajaal/naik-primary/prod-eu-west-1/db/primary/**
Container: indrajaal-db-prod
Note:     PostgreSQL for business data, SQLite for holon metadata
```

## Example 3: Observability Holon

```
FQUN:     indrajaal://local/dev/obs/central
DB Path:  data/holons/central/analytics.duckdb (analytics only)
Zenoh:    indrajaal/local/dev/obs/central/**
Metrics:  indrajaal/local/dev/obs/central/metrics
Container: indrajaal-obs-prod
Services: OTEL (4317), Prometheus (9090), Grafana (3000), Loki (3100)
```

## Example 4: Sentinel Security Holon

```
FQUN:     indrajaal://local/dev/sentinel/mcp-01
DB Path:  data/holons/mcp-01/state.db
Zenoh:    indrajaal/local/dev/sentinel/mcp-01/**
Threats:  indrajaal/sentinel/threats
Binary:   lib/cepaf/src/Cepaf.Sentinel.MCP/bin/Release/net10.0/cepaf-sentinel-mcp
MCP:      5 tools (zenoh_session, zenoh_pub, zenoh_sub, zenoh_query, sentinel)
```

## Example 5: Planning Holon

```
FQUN:     indrajaal://local/dev/plan/sprint-mgr
DB Path:  data/smriti/planning.db
Zenoh:    indrajaal/planning/events
CLI:      sa-plan list | sa-plan add | sa-plan update
Binary:   bin/Cepaf.Planning.CLI
Note:     Planning data accessed ONLY via sa-plan CLI (SC-TODO-001)
```

## Example 6: SMRITI Knowledge Holon

```
FQUN:     indrajaal://local/dev/smriti/knowledge-01
DB Path:  data/holons/knowledge-01/knowledge.db
DuckDB:   data/holons/knowledge-01/analytics.duckdb
Zenoh:    indrajaal/smriti/knowledge
FTS:      FTS5 index in knowledge.db (SC-SMRITI-131)
Vectors:  Embedding store for semantic search (SC-SMRITI-132)
```

## Example 7: Federation Gateway Holon

```
FQUN:     indrajaal://naik-primary/prod-eu-west-1/fed/gateway-01
DB Path:  data/holons/gateway-01/state.db
DuckDB:   data/holons/gateway-01/analytics.duckdb
Zenoh:    indrajaal/federation/attestation
Auth:     Ed25519 attestation (SC-FED-006), expires 1hr (SC-SMRITI-110)
Peers:    Discovered via DNS SRV records
```

## Example 8: Cross-Holon Query (via Zenoh)

```
Source:   indrajaal://local/dev/app/seed-01
Target:   indrajaal://naik-staging/stg-01/app/seed-02
Access:   Via Zenoh ONLY (SC-XHOLON-003)

Zenoh GET: indrajaal/naik-staging/stg-01/app/seed-02/state
Response:  JSON with version vector + state snapshot
Timeout:   < 5s (SC-XHOLON-025)
OCC:       Version vector checked before write (SC-XHOLON-006)
```

## Example 9: Staging Cluster Holon

```
FQUN:     indrajaal://naik-staging/stg-01/app/seed-01
DB Path:  data/holons/seed-01/state.db   (on staging host)
Zenoh:    indrajaal/naik-staging/stg-01/app/seed-01/**
Network:  indrajaal-mesh (staging network)
Note:     Identical structure to production, different federation prefix
```

## Example 10: Mathematical Discipline Monitoring Holon

```
FQUN:     indrajaal://local/dev/app/seed-01  (embedded in app)
Zenoh:    indrajaal/math/health              (CP-MATH-01)
Payload:  { "disciplines": 17, "production": 17, "rpn_max": 50,
            "h_math": 0.96, "interactions": 18 }
Source:   lib/cepaf/src/Cepaf/Mesh/MathematicalSystemMonitor.fs
Interval: Published on health check (every 30s)
```

## Path Resolution Rules

| Rule | Description | Constraint |
|------|-------------|-----------|
| Isolation | Each holon-id maps to exactly one directory | SC-XHOLON-001 |
| No direct access | Cross-holon reads go through Zenoh | SC-XHOLON-003 |
| WAL mandatory | All SQLite files use WAL journal mode | SC-XHOLON-030 |
| Append-only | DuckDB analytics trail is immutable | SC-XHOLON-035 |
| Version vectors | Every write increments version monotonically | SC-XHOLON-007 |
| Recovery | Holon fully reconstructable from DB files alone | AOR-XHOLON-027 |

## Directory Structure Template

```
data/holons/<holon-id>/
  +-- state.db          # Primary holon state (SQLite, WAL mode)
  +-- state.db-wal      # Write-ahead log
  +-- state.db-shm      # Shared memory
  +-- analytics.duckdb  # Audit trail + analytics (append-only)
  +-- knowledge.db      # SMRITI knowledge (if applicable)
  +-- planning.db       # Task data (if planning holon)
  +-- backups/          # Checkpoint snapshots
      +-- checkpoint-<timestamp>.db
```

## Related Documents

- docs/architecture/HOLON_DATABASE_NAMING_SYSTEM.md
- docs/architecture/UNIVERSAL_HOLON_IDENTIFIER_SYSTEM_V2.md
- docs/architecture/FQUN_SPECIFICATION.md
- docs/architecture/CROSS_HOLON_DATABASE_ACCESS_ARCHITECTURE.md
- docs/architecture/holon_database_naming_quick_ref.md
