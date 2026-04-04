---
name: database
description: allowed-tools: mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__zenoh_query, Read, Grep, Glob, Bash(psql:*)
---
---

# Database Operations (SC-DB, SC-DBNAME, SC-DBLOCAL, SC-DBCROSS, SC-MIG)

Unified database management: PostgreSQL business data, holon SQLite/DuckDB state, UHI naming, cross-holon access.

## Usage
```
/database setup         # Setup database (create + migrate)
/database migrate       # Run pending migrations
/database verify        # Verify schema integrity and naming
/database naming        # Check UHI naming compliance
/database cross-holon   # Validate cross-holon access patterns
/database health        # Database health + connection pool status
```

## Database Topology
| Database | Engine | Purpose | Access Pattern |
|----------|--------|---------|----------------|
| Business data | PostgreSQL 17 + TimescaleDB | Transactions, queries | Direct (port 5433) |
| Holon state | SQLite (WAL mode) | Real-time state per holon | Local direct (SC-DBLOCAL-001) |
| Holon history | DuckDB (append-only) | Evolution, analytics | Local direct (SC-DBLOCAL-001) |
| Cross-holon | Zenoh topics | Inter-holon queries | `indrajaal/db/{uhi}/{op}` (SC-DBCROSS-001) |

## UHI Naming System (SC-DBNAME-001 to SC-DBNAME-010)
Fully Qualified Universal Holon Identifier:
```
{runtime}.{layer}.{domain}.{instance}:{db_type}
```

| Component | Values | Constraint |
|-----------|--------|------------|
| Runtime | `elixir`, `fsharp`, `rust` | SC-DBNAME-003 |
| Layer | `l0`-`l7` | SC-DBNAME-004 |
| Domain | Registered codes (10+) | SC-DBNAME-005 |
| Instance | Unique within domain | SC-DBNAME-006 |
| db_type | `sqlite`, `duckdb` | SC-DBNAME-007 |

## Verification Steps
1. Check Sentinel health: `sentinel(action: "health")`
2. Query DB status: `zenoh_query(action: "get", key: "indrajaal/db/health")`
3. Verify PostgreSQL connection: `psql -h localhost -p 5433 -U indrajaal -c "SELECT 1"`
4. Check SQLite WAL mode for all holon DBs
5. Verify UHI naming compliance (DatabasePath.resolve/1)
6. Check migration status: pending migrations count
7. Validate cross-holon access uses Zenoh (SC-DBCROSS-001)
8. Verify connection pool <= 5 per DB (SC-DBLOCAL-003)

## Migration Safety (SC-MIG)
| Step | Action | Constraint |
|------|--------|------------|
| 1 | Declare migrations in test | SC-MIG-001 |
| 2 | Preflight verification | SC-MIG-002 |
| 3 | Run migration | `mix ecto.migrate` |
| 4 | Verify schema | `mix ecto.dump` |
| 5 | Rollback test | `mix ecto.rollback --step 1` |

## Cross-Holon Access (SC-DBCROSS)
```
Local Holon A                      Remote Holon B
┌──────────┐    Zenoh Topic         ┌──────────┐
│ SQLite   │───────────────────────▶│ SQLite   │
│ (direct) │  indrajaal/db/{uhi}/   │ (direct) │
└──────────┘  query|mutate          └──────────┘
   < 1ms        < 100ms                < 1ms
   Local        Cross-Holon            Local
```

## Mathematical Foundation

**Transaction Isolation** (ACID):

$$\text{Serializable}(T_1, T_2) \iff \text{conflict\_free}(T_1, T_2) \vee \text{ordered}(T_1, T_2)$$

**Access Latency Bounds**:

$$L_{local} < 1\text{ms} \quad (SC\text{-}DBLOCAL\text{-}002)$$
$$L_{cross} < 100\text{ms} \quad (SC\text{-}DBCROSS\text{-}004)$$

**Version Vector Convergence** (conflict resolution):

$$V_{merged}[i] = \max(V_a[i], V_b[i]) \quad \forall i \in \text{nodes}$$

**Connection Pool Efficiency**:

$$U_{pool} = \frac{\text{active\_connections}}{\text{pool\_size}} \leq 1.0, \quad \text{pool\_size} \leq 5$$

**Migration Safety** (reversibility):

$$\forall m \in \text{Migrations}: \exists m^{-1} : m^{-1}(m(S)) = S$$

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-DB-001 | Use BaseResource |
| SC-DB-005 | uuid_primary_key :id |
| SC-DB-012 | create_if_not_exists for indexes |
| SC-DBNAME-001 | UHI naming for all holon DBs |
| SC-DBLOCAL-001 | Local access MUST be direct |
| SC-DBLOCAL-004 | WAL mode for SQLite |
| SC-DBCROSS-001 | Cross-holon via Zenoh ONLY |
| SC-MIG-001 | Tests declare migrations |
