//! Persistent KV Storage NIF for Sutra Matrix Server.
//! Uses sled (pure Rust embedded DB) for tuwunel-parity persistence.
//! Sled provides: ACID transactions, zero-copy reads, ~500ns reads, crash-safe.
//!
//! Column families simulated via sled Trees (same concept as RocksDB CFs).
//! API matches RocksDB semantics for transparent migration.

use sled::Db;
use std::sync::OnceLock;

static DATABASE: OnceLock<Db> = OnceLock::new();

/// Open the database at the given path.
#[rustler::nif(schedule = "DirtyCpu")]
fn db_open(path: String) -> Result<String, String> {
    if DATABASE.get().is_some() {
        return Ok("already_open".into());
    }
    match sled::open(&path) {
        Ok(db) => { let _ = DATABASE.set(db); Ok("ok".into()) }
        Err(e) => Err(format!("sled open failed: {e}")),
    }
}

/// Put a key-value pair in a tree (column family).
#[rustler::nif(schedule = "DirtyCpu")]
fn db_put(cf_name: String, key: String, value: String) -> Result<String, String> {
    let db = DATABASE.get().ok_or("db not open")?;
    let tree = db.open_tree(cf_name.as_bytes()).map_err(|e| format!("{e}"))?;
    tree.insert(key.as_bytes(), value.as_bytes()).map_err(|e| format!("{e}"))?;
    Ok("ok".into())
}

/// Get a value by key from a tree.
#[rustler::nif(schedule = "DirtyCpu")]
fn db_get(cf_name: String, key: String) -> Result<String, String> {
    let db = DATABASE.get().ok_or("db not open")?;
    let tree = db.open_tree(cf_name.as_bytes()).map_err(|e| format!("{e}"))?;
    match tree.get(key.as_bytes()) {
        Ok(Some(val)) => String::from_utf8(val.to_vec()).map_err(|e| format!("{e}")),
        Ok(None) => Err("not_found".into()),
        Err(e) => Err(format!("{e}")),
    }
}

/// Delete a key from a tree.
#[rustler::nif(schedule = "DirtyCpu")]
fn db_delete(cf_name: String, key: String) -> Result<String, String> {
    let db = DATABASE.get().ok_or("db not open")?;
    let tree = db.open_tree(cf_name.as_bytes()).map_err(|e| format!("{e}"))?;
    tree.remove(key.as_bytes()).map_err(|e| format!("{e}"))?;
    Ok("ok".into())
}

/// Scan keys with a prefix. Returns up to limit (key, value) pairs.
#[rustler::nif(schedule = "DirtyCpu")]
fn db_scan(cf_name: String, prefix: String, limit: usize) -> Result<Vec<(String, String)>, String> {
    let db = DATABASE.get().ok_or("db not open")?;
    let tree = db.open_tree(cf_name.as_bytes()).map_err(|e| format!("{e}"))?;
    let mut results = Vec::new();
    for item in tree.scan_prefix(prefix.as_bytes()) {
        if results.len() >= limit { break; }
        match item {
            Ok((k, v)) => {
                results.push((
                    String::from_utf8_lossy(&k).into_owned(),
                    String::from_utf8_lossy(&v).into_owned(),
                ));
            }
            Err(_) => break,
        }
    }
    Ok(results)
}

/// Check if the database is open.
#[rustler::nif]
fn db_is_open() -> bool {
    DATABASE.get().is_some()
}

/// Flush all pending writes to disk.
#[rustler::nif(schedule = "DirtyCpu")]
fn db_flush() -> Result<String, String> {
    let db = DATABASE.get().ok_or("db not open")?;
    db.flush().map_err(|e| format!("{e}"))?;
    Ok("ok".into())
}

/// Get database size in bytes.
#[rustler::nif]
fn db_size_on_disk() -> Result<u64, String> {
    let db = DATABASE.get().ok_or("db not open")?;
    db.size_on_disk().map_err(|e| format!("{e}"))
}

rustler::init!("rocksdb_ffi");
