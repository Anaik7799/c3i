---
name: vault-track-b-persistence
description: Slice B worker — disk persistence scaffolding for in-memory K/V (Pass-20). Research RustyVault::Core async API + tokio + rusqlite. Produce SqliteBackend wrapper signatures that compile but don't yet swap the HashMap. Per [zk-3346fc607a1ef9e6] no Stub-That-Lies.
tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# Track B — Disk persistence (B)

## Mission (Wave 1, parallel)

Pass-20 wired in-memory K/V via `HashMap<String, Vec<KvEntry>>`. This track scaffolds the disk-persistence layer using `rusqlite` + future `tokio` integration with RustyVault::Core's async API. Wave-1 scope: types, signatures, cargo check clean. NO Tokio runtime in NIF yet (that's a later session — needs ResourceArc refactor).

## Workflow

1. Read `lib/cepaf_gleam/native/rusty_vault_nif/src/lib.rs` (lines 65-170 — VaultHandle + KvEntry + AuditEntry)
2. Read `sub-projects/rusty_vault_vendored/src/storage/` to understand `PhysicalBackend` trait surface
3. Add `rusqlite = "0.31"` to `Cargo.toml`
4. Run `CARGO_TARGET_DIR=/tmp/rvnif-target cargo check --lib` — if it builds, continue
5. Create new file `lib/cepaf_gleam/native/rusty_vault_nif/src/sqlite_backend.rs` containing:
   - `pub struct SqliteKvBackend { conn_path: PathBuf }`
   - `impl SqliteKvBackend { pub fn open(path: &Path) -> Result<Self, ...> { ... } pub fn migrate(&self) -> Result<(), ...> { ... } }`
   - SQL DDL constants: `CREATE TABLE kv_entries (...)`, `CREATE TABLE audit_log (...)`
6. The `open` body opens the rusqlite connection; the `migrate` body runs the DDL — this IS real, not stub. Just don't yet wire it into VaultHandle.
7. Add 3 unit tests in same file: `open_creates_db_file`, `migrate_creates_kv_table`, `migrate_creates_audit_table`
8. Run `CARGO_TARGET_DIR=/tmp/rvnif-target cargo test --lib sqlite_backend`
9. Report per supervisor template

## Hard rules

- `open` and `migrate` are REAL — they create a SQLite file and run DDL
- DO NOT yet swap the in-memory HashMap in VaultHandle (that's a later session — needs RAII coordination)
- DO NOT add Tokio (that's a later session)
- The 3 unit tests MUST pass (the only Stub-That-Lies-safe way to call this real)
