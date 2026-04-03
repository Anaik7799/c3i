# Holon Database Naming System Quick Reference

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-XHOLON-001, SC-DIST-001

## Overview

Every holon in Indrajaal has a Fully Qualified Universal Name (FQUN) and a Universal
Holon Identifier (UHI) path that determines its database file location, Zenoh topic
namespace, and federation identity. This quick reference covers naming conventions
for all holon types.

## FQUN Format

```
indrajaal://<federation>/<cluster>/<holon-type>/<holon-id>
```

| Component | Format | Example |
|-----------|--------|---------|
| Federation | lowercase alpha | `naik-primary` |
| Cluster | lowercase alpha-num | `prod-eu-west-1` |
| Holon Type | enum (see below) | `app`, `db`, `obs` |
| Holon ID | uuid-v7 or slug | `seed-01`, `a1b2c3d4` |

## Holon Types

| Type | Code | Description | Database |
|------|------|-------------|----------|
| Application | `app` | Elixir runtime node | SQLite + DuckDB |
| Database | `db` | PostgreSQL/SQLite store | SQLite (meta only) |
| Observability | `obs` | OTEL + Grafana + Loki | DuckDB (analytics) |
| Zenoh Router | `zenoh` | Mesh coordinator | None (stateless) |
| Sentinel | `sentinel` | F# MCP security node | SQLite |
| Planning | `plan` | F# task management | SQLite |
| Federation | `fed` | Cross-holon gateway | SQLite + DuckDB |

## Database File Paths

```
data/holons/<holon-id>/
  +-- state.db          # SQLite  - authoritative holon state (SC-HOLON-009)
  +-- state.db-wal      # SQLite  - write-ahead log
  +-- state.db-shm      # SQLite  - shared memory
  +-- analytics.duckdb  # DuckDB  - append-only audit trail
  +-- planning.db       # SQLite  - task/sprint data (planning holons)
  +-- knowledge.db      # SQLite  - SMRITI knowledge store
```

## Naming Rules

| Rule | Constraint | Rationale |
|------|-----------|-----------|
| Isolation | Each holon gets its own directory | SC-XHOLON-001 |
| No sharing | DB files NEVER shared between holons | SC-XHOLON-003 |
| WAL mandatory | All SQLite files use WAL mode | SC-XHOLON-030 |
| Append-only | DuckDB audit trail is immutable | SC-XHOLON-035 |
| Version vectors | Every write increments version | SC-XHOLON-007 |
| Cross-holon | Access ONLY via Zenoh, never direct | SC-XHOLON-003 |

## Zenoh Key Expression Mapping

```
FQUN:  indrajaal://naik-primary/prod-eu-west-1/app/seed-01
Zenoh: indrajaal/naik-primary/prod-eu-west-1/app/seed-01/**

Database path: data/holons/seed-01/state.db
```

| Zenoh Suffix | Maps To |
|-------------|---------|
| `/state` | state.db read/write |
| `/analytics` | analytics.duckdb queries |
| `/health` | Health status JSON |
| `/planning` | planning.db operations |
| `/knowledge` | knowledge.db queries |

## Quick Lookup Table

| Container Name | FQUN | DB Path |
|---------------|------|---------|
| `indrajaal-ex-app-1` | `indrajaal://local/dev/app/seed-01` | `data/holons/seed-01/` |
| `indrajaal-db-prod` | `indrajaal://local/dev/db/primary` | `data/holons/primary/` |
| `indrajaal-obs-prod` | `indrajaal://local/dev/obs/central` | `data/holons/central/` |
| `zenoh-router` | `indrajaal://local/dev/zenoh/router-01` | N/A (stateless) |

## Federation Naming

```
Local:     indrajaal://local/dev/<type>/<id>
Staging:   indrajaal://naik-staging/stg-01/<type>/<id>
Production: indrajaal://naik-primary/prod-eu-west-1/<type>/<id>
```

## Related Documents

- docs/architecture/HOLON_DATABASE_NAMING_SYSTEM.md (full specification)
- docs/architecture/UNIVERSAL_HOLON_IDENTIFIER_SYSTEM_V2.md
- docs/architecture/FQUN_SPECIFICATION.md
- docs/architecture/CROSS_HOLON_DATABASE_ACCESS_ARCHITECTURE.md
