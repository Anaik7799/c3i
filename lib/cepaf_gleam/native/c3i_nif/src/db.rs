//! Shared SQLite database helpers for all C3I NIFs.
//!
//! Reused from planning_nif: WAL mode, 5s busy timeout, exponential backoff
//! with jitter for lock contention.
//!
//! STAMP: SC-NIF-001, SC-TODO-001

use rand::Rng;
use rusqlite::Connection;
use std::time::Duration;

/// Resolve Smriti.db path — env var first, then known candidates.
pub fn db_path() -> String {
    if let Ok(p) = std::env::var("PLANNING_DB_PATH") {
        return p;
    }
    if let Ok(p) = std::env::var("SMRITI_DB_PATH") {
        return p;
    }
    let candidates = [
        "sub-projects/c3i/data/smriti/Smriti.db",
        "../../sub-projects/c3i/data/smriti/Smriti.db",
        "/home/an/dev/ver/c3i/sub-projects/c3i/data/smriti/Smriti.db",
    ];
    for c in &candidates {
        if std::path::Path::new(c).exists() {
            return c.to_string();
        }
    }
    candidates[2].to_string()
}

/// Open SQLite with WAL mode and 5s busy timeout.
pub fn open_db() -> Result<Connection, String> {
    let conn =
        Connection::open(&db_path()).map_err(|e| format!("SQLite open error: {}", e))?;
    conn.execute("PRAGMA journal_mode=WAL", []).ok();
    conn.busy_timeout(Duration::from_millis(5000)).ok();
    Ok(conn)
}

/// Retry an operation with exponential backoff on lock contention.
pub fn execute_with_backoff<F, T>(mut op: F) -> Result<T, String>
where
    F: FnMut() -> Result<T, rusqlite::Error>,
{
    let mut attempts = 0u32;
    let max_attempts = 10;
    let mut rng = rand::thread_rng();

    loop {
        match op() {
            Ok(result) => return Ok(result),
            Err(e) => {
                let msg = e.to_string();
                if (msg.contains("database is locked") || msg.contains("database is busy"))
                    && attempts < max_attempts
                {
                    attempts += 1;
                    let backoff = (2u64.pow(attempts) * 10) + rng.gen_range(0..20);
                    std::thread::sleep(Duration::from_millis(backoff));
                } else {
                    return Err(format!("SQLite error: {}", e));
                }
            }
        }
    }
}
