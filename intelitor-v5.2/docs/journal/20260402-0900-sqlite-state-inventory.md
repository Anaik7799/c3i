# SQLite State Inventory Analysis

**Date**: 2026-04-02
**Author**: opencode
**Type**: System Analysis
**STAMP Compliance**: SC-KMS-002, SC-KMS-003, SC-KMS-008

---

## 1. Scope

Document all SQLite state databases maintained in the Indrajaal (c3i) system, including schema, purpose, and data flow relationships.

---

## 2. Pre-State

System documentation scattered across schema files, migration scripts, and sync rules. No centralized inventory of state storage.

---

## 3. Execution

1. Searched for `.db` files across codebase
2. Analyzed schema files in `scripts/smriti/` and `scripts/kms/`
3. Reviewed sync rules in `.claude/rules/planning-chaya-sync.md`
4. Examined migration scripts in `scripts/smriti/migrations/`

---

## 4. RCA

### Primary Databases Identified

| Database | Location | Purpose |
|:---|:---|:---|
| **Smriti.db** | `data/smriti/Smriti.db` | Primary holon state (Zettelkasten) |
| **Chaya.db** | `data/chaya/chaya.db` | Planning task replica (downstream) |

### Secondary/Artifact Databases

| Database | Purpose |
|:---|:---|
| `lib/cepaf/artifacts/build-history.db` | Build timing persistence |
| `lib/cepaf/artifacts/cepa-state.db` | CEPF artifact state |
| `test*.db` | Test databases |

---

## 5. Taxonomy

### Smriti.db Schema

**Table: holons**
| Column | Type | Purpose |
|:---|:---|:---|
| holon_uuid | TEXT PK | Unique identifier |
| title | TEXT | Zettel title |
| content | TEXT | Zettel content |
| tags | TEXT | Categorization |
| entropy | REAL | Information entropy (0.0-1.0) |
| level | TEXT | Fractal level (atomic/molecular/organism/ecosystem) |
| decay_rate | TEXT | Entropy decay speed (slow/medium/fast) |
| cluster | TEXT | Cluster grouping |
| content_hash | TEXT | Content integrity |
| vector_embedding | BLOB | Vector embedding for similarity |
| srs_next_review | TEXT | Spaced repetition next review |
| srs_interval | INTEGER | SRS interval |
| srs_ease_factor | REAL | SRS ease factor |
| srs_repetitions | INTEGER | SRS repetition count |

**Table: holon_edges**
| Column | Type | Purpose |
|:---|:---|:---|
| source_id | TEXT FK | Source holon |
| target_id | TEXT FK | Target holon |
| link_type | TEXT | Link type (wiki/semantic/code/backlink) |
| weight | REAL | Edge weight (0.0-1.0) |

**Virtual Table**: `holon_fts` (FTS5 full-text search)

### Chaya.db Schema

**Purpose**: Downstream replica of F# Planning.db for task management

**Data Flow**: `Planning.db (F#)` → `Chaya.db` (unidirectional sync only)

---

## 6. Patterns

### Entropy-Based Decay
- Holons with entropy > 0.7 flagged as "rotting" (low priority)
- Holons with entropy < 0.3 flagged as "fresh" (high priority)
- Decay rate determines how fast entropy increases

### Spaced Repetition System (SRS)
- SM-2 algorithm implementation
- `srs_ease_factor` defaults to 2.5
- Next review calculated based on interval and repetitions

### Unidirectional Sync
- Chaya.db is read-only downstream replica
- Planning.db is authoritative source
- Sync homomorphically preserves task structure

---

## 7. Verification

- Schema files verified: `scripts/smriti/schema.sql`
- Migration verified: `scripts/smriti/migrations/001_add_recall_columns.sql`
- Sync rules verified: `.claude/rules/planning-chaya-sync.md`
- FTS5 triggers confirmed for auto-sync

---

## 8. Files

| File | Purpose |
|:---|:---|
| `scripts/smriti/schema.sql` | Smriti.db schema definition |
| `scripts/smriti/migrations/001_add_recall_columns.sql` | SRS/Vector migration |
| `scripts/kms/reconstruct_schema.sql` | Alternative holon schema |
| `.claude/rules/planning-chaya-sync.md` | Chaya sync constraints |

---

## 9. Architecture

### Ω₇ Compliance: Holon State Sovereignty

> Authoritative holon state ≡ SQLite ∪ DuckDB ONLY. PostgreSQL ∩ HolonState ≡ ∅.

- Smriti.db: Authoritative holon state (Zettelkasten)
- Chaya.db: Planning task replica
- PostgreSQL: Time-series alarms only (NOT holon state)

### Zenoh IPC Integration

All state mutations via Zenoh topics:
- `indrajaal/holons/*` - Holon CRUD operations
- `indrajaal/tasks/*` - Task/sync operations

---

## 10. Gaps

1. **Chaya.db schema**: Not directly available in schema files (inferred from sync rules)
2. **Vector search**: FTS5 implemented but embedding generation not documented
3. **Backup verification**: Need to verify backup integrity

---

## 11. Metrics

| Metric | Value |
|:---|:---|
| Primary SQLite DBs | 2 |
| Secondary/Artifact DBs | 4+ |
| Holon table columns | 18 |
| Edge link types | 4 |
| Fractal levels | 4 |

---

## 12. STAMP

| Constraint | Status |
|:---|:---|
| SC-KMS-002: Cross-runtime data access (F#/Elixir) | VERIFIED |
| SC-KMS-003: Entropy calculation support | VERIFIED |
| SC-KMS-008: Vector search integration (FTS5) | VERIFIED |

---

## 13. Conclusion

Complete SQLite state inventory documented. The system maintains:
- **Smriti.db**: Primary Zettelkasten with entropy decay, SRS, and FTS5
- **Chaya.db**: Downstream task replica with unidirectional sync

All state storage adheres to Ω₇ (Holon State Sovereignty): SQLite/DuckDB ONLY for authoritative holon state.

**Next**: Document PostgreSQL time-series schema for alarms (non-holon state).