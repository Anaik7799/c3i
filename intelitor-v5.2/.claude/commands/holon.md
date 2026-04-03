---
description: Holon state sovereignty — SQLite/DuckDB state, regeneration, replication, Ash resource validation
allowed-tools: mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__zenoh_query, Read, Grep, Glob
argument-hint: [state|health|verify|replicate|regenerate]
---

# Holon State Sovereignty (SC-HOLON-001 to SC-HOLON-020)

Validate and manage holon state sovereignty: SQLite real-time state, DuckDB evolution history, Ash resource patterns.

## Usage
```
/holon state            # Inspect holon SQLite/DuckDB state files
/holon health           # Verify holon integrity (checksums, WAL mode)
/holon verify           # Full sovereignty verification (SC-HOLON-009)
/holon replicate        # Check replication status and version vectors
/holon regenerate       # Verify regeneration from SQLite/DuckDB alone
```

## State Architecture (Ω₇)
| Store | Purpose | Mode | STAMP |
|-------|---------|------|-------|
| SQLite | Real-time holon state | WAL | SC-HOLON-001, SC-DBLOCAL-004 |
| DuckDB | Evolution history | Append-only | SC-HOLON-002 |
| PostgreSQL | Business data ONLY | Standard | SC-HOLON-006 |
| Redis/Kafka | Ephemeral replicas | Non-authoritative | SC-HOLON-013 |

## Verification Steps
1. Check Sentinel health: `sentinel(action: "health")`
2. Query holon state: `zenoh_query(action: "get", key: "indrajaal/holon/state")`
3. Verify SQLite files exist in `data/holons/{holon_id}/`
4. Validate SHA-256 checksums (SC-HOLON-017)
5. Check WAL mode: `PRAGMA journal_mode` = WAL (SC-DBLOCAL-004)
6. Verify connection pool size <= 5 (SC-DBLOCAL-003)
7. Check DuckDB append-only integrity (SC-HOLON-019)
8. Validate manifest.json exists (SC-DBNAME-010)

## Ash Resource Patterns (SC-ASH)
| Pattern | Constraint | Enforcement |
|---------|------------|-------------|
| `force_change_attribute` in `before_action` | SC-ASH-001 | Code review |
| `require_atomic? false` for fn changes | SC-ASH-004 | Static analysis |
| `BaseResource` usage | SC-DB-001 | Compile check |
| `uuid_primary_key :id` | SC-DB-005 | Schema validation |
| `create_if_not_exists` for indexes | SC-DB-012 | Migration check |

## Mathematical Foundation

**State Sovereignty Predicate**:

$$\text{Sovereign}(h) \iff \text{Regenerable}(h, \text{SQLite} \cup \text{DuckDB}) \wedge \text{Isolated}(h)$$

**Version Vector Conflict Resolution**:

$$V_a \| V_b \iff \exists i,j : V_a[i] > V_b[i] \wedge V_b[j] > V_a[j]$$

Concurrent writes detected when version vectors are incomparable ($\|$).

**State Integrity** (SHA-256 chain):

$$I(h) = \forall b_i : H(b_i) = \text{SHA256}(content_i \| H(b_{i-1}))$$

**Portability** (single file copy):

$$\text{Portable}(h) \iff |deps(h) \setminus \{sqlite, duckdb\}| = 0$$

**Information-Theoretic Minimum** (SC-HOLON-018):

$$S_{min} = H(X) = -\sum_{i} p_i \log_2 p_i \text{ bits}$$

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-HOLON-001 | Real-time state in SQLite (WAL) |
| SC-HOLON-002 | Evolution history in DuckDB (append-only) |
| SC-HOLON-006 | PostgreSQL for business data ONLY |
| SC-HOLON-009 | SQLite/DuckDB is ONLY authoritative source |
| SC-HOLON-010 | Regenerable from SQLite/DuckDB alone |
| SC-HOLON-017 | SHA-256 checksum for every file |
| SC-ASH-001 | force_change_attribute in before_action |
| SC-DB-001 | Use BaseResource |
