//! # Build Oracle — SIL-6 Ignition Daemon
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L4-System (Build Intelligence Bridge) |
//! | Element   | F# BuildHistory.db Reader |
//!
//! ## Data Bridge Architecture
//! ```
//! F# BuildHistory.fs ──writes──→ build-history.db (WAL) ──reads──→ Rust build_oracle.rs
//! ```
//!
//! ## Design Contract
//! This module is READ-ONLY with respect to the SQLite database. The F# PanopticIgnition
//! system owns all writes. Rust opens with `SQLITE_OPEN_READ_ONLY` to enforce this at
//! the OS level, preventing accidental mutations from the Rust side.
//!
//! ## Graceful Degradation
//! On first boot, `build-history.db` does not yet exist. Every public function handles
//! the absent-DB case by returning `None` or safe defaults so callers never hard-fail
//! solely because of missing oracle data.
//!
//! ## STAMP: SC-IGNITE-005, SC-XHOLON-001, SC-XHOLON-030
//!
//! - SC-IGNITE-005: BuildHistory MUST persist build timing to SQLite with WAL mode and
//!   EMA estimation (alpha=0.3).
//! - SC-XHOLON-001: Isolated database files per holon (read-only access enforced here).
//! - SC-XHOLON-030: No data loss on crash (WAL mode — verified by `check_db_health`).

use crate::errors::IgnitionError;
use crate::types::{
    AdaptiveTimeout, BuildEmaRecord, TimeoutSource, BOOT_TIMEOUT_MS, BUILD_HISTORY_DB_PATH,
    EMA_ALPHA, EMA_TIMEOUT_MULTIPLIER, MAX_ADAPTIVE_TIMEOUT_MS, MIN_ADAPTIVE_TIMEOUT_MS,
};
use log::{debug, info, warn};
use rusqlite::{Connection, OpenFlags};
use std::collections::HashMap;
use std::path::Path;

// ═══════════════════════════════════════════════════════════════════════════════
// ADDITIONAL TYPES (module-internal + public aggregates)
// ═══════════════════════════════════════════════════════════════════════════════

/// Raw build record from the `build_history` table.
///
/// Mirrors `BuildRecord` in F# `BuildHistory.fs`. Used for TUI display
/// and trend analysis (e.g., recent failure rates).
#[derive(Debug, Clone)]
pub struct BuildRecord {
    /// Container this build was for (e.g., `"indrajaal-ex-app-1"`).
    pub container_name: String,
    /// Action type: `"build"`, `"pull"`, `"shared"`, `"skip"`, `"boot"`.
    pub action: String,
    /// Whether the build succeeded.
    pub success: bool,
    /// Observed build duration in milliseconds.
    pub duration_ms: i64,
    /// ISO-8601 timestamp string as stored by F# (`DateTime.UtcNow.ToString("o")`).
    pub timestamp: String,
    /// Error message, if any (NULL in SQLite becomes `None` here).
    pub error: Option<String>,
}

/// Aggregate build statistics across all containers and actions.
#[derive(Debug, Clone)]
pub struct BuildStats {
    /// Total number of rows in `build_history`.
    pub total_builds: i64,
    /// Rows where `success = 1`.
    pub successful_builds: i64,
    /// Rows where `success = 0`.
    pub failed_builds: i64,
    /// Mean `duration_ms` across all successful rows. `0.0` when no data.
    pub avg_duration_ms: f64,
    /// Number of distinct containers in `build_ema` (have at least one EMA record).
    pub containers_with_ema: u32,
}

/// Database health status — returned by `check_db_health`.
#[derive(Debug, Clone)]
pub struct DbHealth {
    /// `true` when the database file was found on disk.
    pub db_exists: bool,
    /// `true` when `PRAGMA journal_mode` returns `"wal"`.
    pub wal_mode: bool,
    /// Row count in `build_history` (`-1` if table missing or query error).
    pub build_history_rows: i64,
    /// Row count in `build_ema` (`-1` if table missing or query error).
    pub ema_rows: i64,
    /// Timestamp of the most-recent `build_history` row, if any.
    pub newest_record: Option<String>,
    /// Timestamp of the oldest `build_history` row, if any.
    pub oldest_record: Option<String>,
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATABASE OPEN
// ═══════════════════════════════════════════════════════════════════════════════

/// Open the BuildHistory SQLite database in read-only mode.
///
/// Returns `Ok(None)` when the database file does not yet exist (first-boot
/// scenario). Callers MUST handle `None` by falling back to default timeouts.
///
/// ## WAL Compatibility
/// Because F# opens the same file with WAL mode and may be writing concurrently,
/// this function uses `SQLITE_OPEN_NO_MUTEX` to avoid cross-process mutex
/// contention. SQLite WAL mode supports concurrent readers and a single writer
/// without blocking.
///
/// ## STAMP: SC-IGNITE-005, SC-XHOLON-001
pub fn open_db() -> Result<Option<Connection>, IgnitionError> {
    let db_path = Path::new(BUILD_HISTORY_DB_PATH);

    if !db_path.exists() {
        info!(
            "[build_oracle] Database not found at '{}' — first-boot, using default timeouts",
            BUILD_HISTORY_DB_PATH
        );
        return Ok(None);
    }

    debug!(
        "[build_oracle] Opening '{}' read-only (WAL, NO_MUTEX)",
        BUILD_HISTORY_DB_PATH
    );

    let flags = OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX;

    let conn = Connection::open_with_flags(db_path, flags)
        .map_err(|e| IgnitionError::SqliteError(format!("open_db: {}", e)))?;

    // Verify WAL mode is active (F# should have set this; log a warning if not).
    let journal_mode: String = conn
        .query_row("PRAGMA journal_mode", [], |row| row.get(0))
        .map_err(|e| IgnitionError::SqliteError(format!("PRAGMA journal_mode: {}", e)))?;

    if journal_mode.to_lowercase() != "wal" {
        warn!(
            "[build_oracle] Expected WAL mode, got '{}' — SC-IGNITE-005 may be violated",
            journal_mode
        );
    } else {
        debug!("[build_oracle] WAL mode confirmed");
    }

    Ok(Some(conn))
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMA READS
// ═══════════════════════════════════════════════════════════════════════════════

/// Read all EMA records from the `build_ema` table.
///
/// Returns an empty `Vec` when the table has no rows. Returns
/// `IgnitionError::SqliteError` only on genuine I/O or schema errors.
pub fn read_all_ema(conn: &Connection) -> Result<Vec<BuildEmaRecord>, IgnitionError> {
    let mut stmt = conn
        .prepare(
            "SELECT container_name, ema_duration_ms, ema_image_size, \
             total_builds, last_success, last_failure \
             FROM build_ema \
             ORDER BY container_name ASC",
        )
        .map_err(|e| IgnitionError::SqliteError(format!("read_all_ema prepare: {}", e)))?;

    let records: Result<Vec<BuildEmaRecord>, _> = stmt
        .query_map([], |row| {
            Ok(BuildEmaRecord {
                container_name: row.get(0)?,
                ema_duration_ms: row.get(1)?,
                ema_image_size: row.get(2)?,
                total_builds: row.get(3)?,
                last_success: row.get(4)?,
                last_failure: row.get(5)?,
            })
        })
        .map_err(|e| IgnitionError::SqliteError(format!("read_all_ema query_map: {}", e)))?
        .collect();

    records.map_err(|e| IgnitionError::SqliteError(format!("read_all_ema row: {}", e)))
}

/// Read the EMA record for a specific container.
///
/// Returns `Ok(None)` when the container has never been built (no row in
/// `build_ema`). Returns `Ok(Some(...))` when EMA data is available.
pub fn read_ema(
    conn: &Connection,
    container: &str,
) -> Result<Option<BuildEmaRecord>, IgnitionError> {
    let result = conn.query_row(
        "SELECT container_name, ema_duration_ms, ema_image_size, \
         total_builds, last_success, last_failure \
         FROM build_ema \
         WHERE container_name = ?1",
        rusqlite::params![container],
        |row| {
            Ok(BuildEmaRecord {
                container_name: row.get(0)?,
                ema_duration_ms: row.get(1)?,
                ema_image_size: row.get(2)?,
                total_builds: row.get(3)?,
                last_success: row.get(4)?,
                last_failure: row.get(5)?,
            })
        },
    );

    match result {
        Ok(record) => {
            debug!(
                "[build_oracle] EMA for '{}': {:.0}ms (n={})",
                container, record.ema_duration_ms, record.total_builds
            );
            Ok(Some(record))
        }
        Err(rusqlite::Error::QueryReturnedNoRows) => {
            debug!("[build_oracle] No EMA data for '{}'", container);
            Ok(None)
        }
        Err(e) => Err(IgnitionError::SqliteError(format!(
            "read_ema '{}': {}",
            container, e
        ))),
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADAPTIVE TIMEOUTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute an adaptive timeout for a single container.
///
/// ## Algorithm
/// ```text
/// if EMA data exists:
///     ema_timeout = clamp(ema_duration_ms * EMA_TIMEOUT_MULTIPLIER, MIN, MAX)
///     source      = BuildOracle
/// else:
///     ema_timeout = base_timeout_ms
///     source      = Default
/// ```
///
/// The 2.5× safety multiplier provides margin for:
/// - Cache misses on cold boot
/// - Registry pull latency variance
/// - Container start jitter
///
/// ## STAMP: SC-IGNITE-005
pub fn adaptive_timeout(
    conn: &Connection,
    container: &str,
    base_timeout_ms: u64,
) -> AdaptiveTimeout {
    match read_ema(conn, container) {
        Ok(Some(ema)) => {
            let raw_ms = ema.ema_duration_ms * EMA_TIMEOUT_MULTIPLIER;
            let clamped_ms = clamp_timeout(raw_ms as u64);

            info!(
                "[build_oracle] '{}': EMA={:.0}ms × {:.1} → {}ms (clamped from {:.0}ms)",
                container, ema.ema_duration_ms, EMA_TIMEOUT_MULTIPLIER, clamped_ms, raw_ms
            );

            AdaptiveTimeout {
                container_name: container.to_string(),
                base_timeout_ms,
                ema_timeout_ms: clamped_ms,
                multiplier: EMA_TIMEOUT_MULTIPLIER,
                source: TimeoutSource::BuildOracle,
            }
        }
        Ok(None) => {
            debug!(
                "[build_oracle] '{}': no EMA — using default {}ms",
                container, base_timeout_ms
            );
            AdaptiveTimeout {
                container_name: container.to_string(),
                base_timeout_ms,
                ema_timeout_ms: base_timeout_ms,
                multiplier: EMA_TIMEOUT_MULTIPLIER,
                source: TimeoutSource::Default,
            }
        }
        Err(e) => {
            warn!(
                "[build_oracle] '{}': EMA read error ({}) — using default {}ms",
                container, e, base_timeout_ms
            );
            AdaptiveTimeout {
                container_name: container.to_string(),
                base_timeout_ms,
                ema_timeout_ms: base_timeout_ms,
                multiplier: EMA_TIMEOUT_MULTIPLIER,
                source: TimeoutSource::Default,
            }
        }
    }
}

/// Compute adaptive timeouts for all 16 SIL-6 genome containers.
///
/// Returns a `HashMap` keyed by container name. Containers without EMA data
/// receive a default timeout of `BOOT_TIMEOUT_MS` (60 000 ms). The caller
/// can look up each container's recommended timeout before launching it.
///
/// ## STAMP: SC-IGNITE-006, SC-IGNITE-008
pub fn all_adaptive_timeouts(conn: &Connection) -> HashMap<String, AdaptiveTimeout> {
    /// All 16 containers in the SIL-6 genome.
    /// Source: panoptic-swarm-ignition.md §2.2, PanopticIgnition.fs sil6Genome.
    const ALL_CONTAINERS: &[&str] = &[
        "indrajaal-db-prod",
        "indrajaal-obs-prod",
        "indrajaal-ex-app-1",
        "cepaf-bridge",
        "indrajaal-cortex",
        "zenoh-router",
        "indrajaal-ollama",
        "indrajaal-mojo",
        "zenoh-router-1",
        "zenoh-router-2",
        "zenoh-router-3",
        "indrajaal-ex-app-2",
        "indrajaal-ex-app-3",
        "indrajaal-chaya",
        "indrajaal-ml-runner-1",
        "indrajaal-ml-runner-2",
    ];

    let mut map = HashMap::with_capacity(ALL_CONTAINERS.len());

    for &name in ALL_CONTAINERS {
        let timeout = adaptive_timeout(conn, name, BOOT_TIMEOUT_MS);
        map.insert(name.to_string(), timeout);
    }

    info!(
        "[build_oracle] Computed adaptive timeouts for {} containers",
        map.len()
    );

    map
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUILD HISTORY READS
// ═══════════════════════════════════════════════════════════════════════════════

/// Retrieve the last `limit` build records for a container, newest-first.
///
/// Used by the TUI to render a sparkline or history table for a container.
/// Returns an empty `Vec` when no records match.
pub fn recent_builds(
    conn: &Connection,
    container: &str,
    limit: u32,
) -> Result<Vec<BuildRecord>, IgnitionError> {
    let mut stmt = conn
        .prepare(
            "SELECT container_name, action, success, duration_ms, timestamp, error \
             FROM build_history \
             WHERE container_name = ?1 \
             ORDER BY id DESC \
             LIMIT ?2",
        )
        .map_err(|e| IgnitionError::SqliteError(format!("recent_builds prepare: {}", e)))?;

    let records: Result<Vec<BuildRecord>, _> = stmt
        .query_map(rusqlite::params![container, limit], |row| {
            let success_int: i64 = row.get(2)?;
            Ok(BuildRecord {
                container_name: row.get(0)?,
                action: row.get(1)?,
                success: success_int != 0,
                duration_ms: row.get(3)?,
                timestamp: row.get(4)?,
                error: row.get(5)?,
            })
        })
        .map_err(|e| IgnitionError::SqliteError(format!("recent_builds query_map: {}", e)))?
        .collect();

    records.map_err(|e| IgnitionError::SqliteError(format!("recent_builds row: {}", e)))
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMA PREDICTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Predict the next build duration for a container given its current EMA.
///
/// This is an identity projection: the EMA *is* already the best single-point
/// estimate for the next observation under an exponential smoothing model with
/// alpha = 0.3.  The function exists as a named entry-point so the TUI can
/// display "expected build time" without duplicating the formula.
///
/// ## Mathematical basis
/// Under EMA smoothing: E[X_{n+1}] = EMA_n
/// i.e., the EMA is an unbiased predictor of the next value in expectation.
///
/// ## STAMP: SC-IGNITE-005 (alpha = 0.3 matches F# BuildHistory.fs)
#[inline]
pub fn predict_next_duration(ema_record: &BuildEmaRecord) -> f64 {
    // Sanity check: EMA should be positive. If somehow it is zero or negative
    // (data corruption), return a safe minimum.
    if ema_record.ema_duration_ms <= 0.0 {
        warn!(
            "[build_oracle] Non-positive EMA ({:.3}) for '{}' — returning minimum",
            ema_record.ema_duration_ms, ema_record.container_name
        );
        return MIN_ADAPTIVE_TIMEOUT_MS as f64 / EMA_TIMEOUT_MULTIPLIER;
    }
    ema_record.ema_duration_ms
}

/// Compute a new EMA given the previous EMA and a new observation.
///
/// Exposed so callers can speculatively estimate what a future EMA would be
/// after a hypothetical build of `observed_duration_ms` without mutating state.
/// (Writes are F#'s responsibility; this is read-only / speculative.)
///
/// Formula: `new_ema = EMA_ALPHA * observed + (1 - EMA_ALPHA) * previous_ema`
#[inline]
pub fn compute_ema(previous_ema: f64, observed_duration_ms: f64) -> f64 {
    EMA_ALPHA * observed_duration_ms + (1.0 - EMA_ALPHA) * previous_ema
}

// ═══════════════════════════════════════════════════════════════════════════════
// AGGREGATE STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute aggregate build statistics across all containers and actions.
///
/// Provides a summary view suitable for the TUI health panel or pre-flight
/// reporting. All queries run against the read-only connection.
pub fn build_statistics(conn: &Connection) -> Result<BuildStats, IgnitionError> {
    // Total builds
    let total_builds: i64 = conn
        .query_row("SELECT COUNT(*) FROM build_history", [], |r| r.get(0))
        .map_err(|e| IgnitionError::SqliteError(format!("build_statistics total: {}", e)))?;

    // Successful builds
    let successful_builds: i64 = conn
        .query_row(
            "SELECT COUNT(*) FROM build_history WHERE success = 1",
            [],
            |r| r.get(0),
        )
        .map_err(|e| IgnitionError::SqliteError(format!("build_statistics success: {}", e)))?;

    // Failed builds (derived — avoids a second COUNT query)
    let failed_builds = total_builds - successful_builds;

    // Average duration for successful builds only
    let avg_duration_ms: f64 = if successful_builds > 0 {
        conn.query_row(
            "SELECT AVG(duration_ms) FROM build_history WHERE success = 1",
            [],
            |r| r.get::<_, Option<f64>>(0),
        )
        .map_err(|e| IgnitionError::SqliteError(format!("build_statistics avg: {}", e)))?
        .unwrap_or(0.0)
    } else {
        0.0
    };

    // Containers with EMA records
    let containers_with_ema: u32 = conn
        .query_row("SELECT COUNT(*) FROM build_ema", [], |r| r.get::<_, i64>(0))
        .map_err(|e| IgnitionError::SqliteError(format!("build_statistics ema_count: {}", e)))?
        as u32;

    let stats = BuildStats {
        total_builds,
        successful_builds,
        failed_builds,
        avg_duration_ms,
        containers_with_ema,
    };

    info!(
        "[build_oracle] Stats: {} total, {} ok, {} fail, avg={:.0}ms, {} containers with EMA",
        stats.total_builds,
        stats.successful_builds,
        stats.failed_builds,
        stats.avg_duration_ms,
        stats.containers_with_ema
    );

    Ok(stats)
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATABASE HEALTH
// ═══════════════════════════════════════════════════════════════════════════════

/// Check database health: WAL mode, table existence, row counts, timestamp range.
///
/// The database is considered healthy when:
/// - It exists on disk (`db_exists = true`)
/// - WAL mode is active (`wal_mode = true`)
/// - `build_history` has at least one row
/// - `build_ema` has at least one row
///
/// A partially healthy database (exists but empty) is normal on first run.
///
/// ## STAMP: SC-XHOLON-030 (WAL mode verified here)
pub fn check_db_health(conn: &Connection) -> Result<DbHealth, IgnitionError> {
    // WAL mode
    let journal_mode: String = conn
        .query_row("PRAGMA journal_mode", [], |r| r.get(0))
        .map_err(|e| IgnitionError::SqliteError(format!("check_db_health journal_mode: {}", e)))?;

    let wal_mode = journal_mode.to_lowercase() == "wal";

    // Row counts — treat missing tables as -1 rather than hard errors
    let build_history_rows = count_rows(conn, "build_history");
    let ema_rows = count_rows(conn, "build_ema");

    // Timestamp range from build_history
    let (newest_record, oldest_record) = if build_history_rows > 0 {
        let newest: Option<String> = conn
            .query_row(
                "SELECT timestamp FROM build_history ORDER BY id DESC LIMIT 1",
                [],
                |r| r.get(0),
            )
            .ok();

        let oldest: Option<String> = conn
            .query_row(
                "SELECT timestamp FROM build_history ORDER BY id ASC LIMIT 1",
                [],
                |r| r.get(0),
            )
            .ok();

        (newest, oldest)
    } else {
        (None, None)
    };

    let health = DbHealth {
        db_exists: true, // If we got here, the file was opened successfully
        wal_mode,
        build_history_rows,
        ema_rows,
        newest_record,
        oldest_record,
    };

    if health.wal_mode && health.build_history_rows >= 0 {
        debug!(
            "[build_oracle] DB healthy: WAL={}, history={} rows, EMA={} rows",
            health.wal_mode, health.build_history_rows, health.ema_rows
        );
    } else {
        warn!(
            "[build_oracle] DB health issue: WAL={}, history={} rows, EMA={} rows",
            health.wal_mode, health.build_history_rows, health.ema_rows
        );
    }

    Ok(health)
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVENIENCE: OPEN + QUERY IN ONE CALL
// ═══════════════════════════════════════════════════════════════════════════════

/// Open the database and return all adaptive timeouts in one call.
///
/// Returns a `HashMap` populated from EMA data when the DB exists, or a
/// `HashMap` populated with default timeouts when the DB is absent.
/// This is the primary entry-point for modules that need timeouts during boot.
///
/// ## Usage
/// ```rust
/// let timeouts = build_oracle::load_timeouts();
/// let t = timeouts.get("indrajaal-ex-app-1").map(|t| t.ema_timeout_ms).unwrap_or(60_000);
/// ```
pub fn load_timeouts() -> HashMap<String, AdaptiveTimeout> {
    match open_db() {
        Ok(Some(conn)) => {
            debug!("[build_oracle] Loaded DB — computing adaptive timeouts");
            all_adaptive_timeouts(&conn)
        }
        Ok(None) => {
            info!("[build_oracle] DB absent — all timeouts use defaults");
            default_all_timeouts()
        }
        Err(e) => {
            warn!(
                "[build_oracle] DB open failed ({}) — all timeouts use defaults",
                e
            );
            default_all_timeouts()
        }
    }
}

/// Return a `DbHealth` report without requiring a pre-opened connection.
///
/// Returns a `DbHealth` with `db_exists = false` when the file is missing.
pub fn check_health() -> DbHealth {
    let db_path = Path::new(BUILD_HISTORY_DB_PATH);
    if !db_path.exists() {
        return DbHealth {
            db_exists: false,
            wal_mode: false,
            build_history_rows: -1,
            ema_rows: -1,
            newest_record: None,
            oldest_record: None,
        };
    }

    match open_db() {
        Ok(Some(conn)) => check_db_health(&conn).unwrap_or_else(|e| {
            warn!("[build_oracle] check_health error: {}", e);
            DbHealth {
                db_exists: true,
                wal_mode: false,
                build_history_rows: -1,
                ema_rows: -1,
                newest_record: None,
                oldest_record: None,
            }
        }),
        _ => DbHealth {
            db_exists: true,
            wal_mode: false,
            build_history_rows: -1,
            ema_rows: -1,
            newest_record: None,
            oldest_record: None,
        },
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMA WRITES (EVO-2)
// ═══════════════════════════════════════════════════════════════════════════════

/// Open the DB for writing EMA updates (EVO-2)
pub fn open_db_rw() -> Result<Connection, IgnitionError> {
    let db_path = Path::new(BUILD_HISTORY_DB_PATH);
    let flags = OpenFlags::SQLITE_OPEN_READ_WRITE
        | OpenFlags::SQLITE_OPEN_CREATE
        | OpenFlags::SQLITE_OPEN_NO_MUTEX;
    let conn = Connection::open_with_flags(db_path, flags)
        .map_err(|e| IgnitionError::SqliteError(format!("open_db_rw: {}", e)))?;
    conn.execute_batch(
        "PRAGMA journal_mode=WAL;
         CREATE TABLE IF NOT EXISTS build_ema (
             container_name TEXT PRIMARY KEY,
             ema_duration_ms REAL NOT NULL,
             ema_image_size REAL NOT NULL,
             total_builds INTEGER NOT NULL,
             last_success TEXT,
             last_failure TEXT
         );
         CREATE TABLE IF NOT EXISTS build_history (
             id INTEGER PRIMARY KEY AUTOINCREMENT,
             container_name TEXT NOT NULL,
             action TEXT NOT NULL,
             success INTEGER NOT NULL,
             duration_ms INTEGER NOT NULL,
             image_size_bytes INTEGER,
             cache_hits INTEGER,
             cache_misses INTEGER,
             step_count INTEGER,
             timestamp TEXT NOT NULL,
             error TEXT
         );",
    )
    .map_err(|e| IgnitionError::SqliteError(format!("init_schema: {}", e)))?;
    Ok(conn)
}

/// Update EMA record (EVO-2)
pub fn update_ema(
    conn: &Connection,
    container: &str,
    duration_ms: f64,
    success: bool,
) -> Result<(), IgnitionError> {
    let current = read_ema(conn, container)?;
    let now = chrono::Utc::now().to_rfc3339();
    let (new_ema, new_total, last_success, last_failure) = match current {
        Some(ema) => {
            let next_ema = compute_ema(ema.ema_duration_ms, duration_ms);
            let ls = if success {
                Some(now.clone())
            } else {
                ema.last_success
            };
            let lf = if !success {
                Some(now)
            } else {
                ema.last_failure
            };
            (next_ema, ema.total_builds + 1, ls, lf)
        }
        None => {
            let ls = if success { Some(now.clone()) } else { None };
            let lf = if !success { Some(now) } else { None };
            (duration_ms, 1, ls, lf)
        }
    };

    conn.execute(
        "INSERT INTO build_ema (container_name, ema_duration_ms, ema_image_size, total_builds, last_success, last_failure)
         VALUES (?1, ?2, 0.0, ?3, ?4, ?5)
         ON CONFLICT(container_name) DO UPDATE SET
         ema_duration_ms=excluded.ema_duration_ms,
         total_builds=excluded.total_builds,
         last_success=excluded.last_success,
         last_failure=excluded.last_failure",
        rusqlite::params![container, new_ema, new_total, last_success, last_failure],
    ).map_err(|e| IgnitionError::SqliteError(format!("update_ema: {}", e)))?;
    Ok(())
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRIVATE HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Clamp a raw computed timeout (ms) into the safe operating range.
///
/// - Floor: `MIN_ADAPTIVE_TIMEOUT_MS` (15 000 ms) — never give less than 15s.
/// - Ceiling: `MAX_ADAPTIVE_TIMEOUT_MS` (600 000 ms) — never wait more than 10 min.
#[inline]
fn clamp_timeout(raw_ms: u64) -> u64 {
    raw_ms
        .max(MIN_ADAPTIVE_TIMEOUT_MS)
        .min(MAX_ADAPTIVE_TIMEOUT_MS)
}

/// Count rows in a table, returning `-1` on error (e.g., table not yet created).
fn count_rows(conn: &Connection, table: &str) -> i64 {
    // Build the query dynamically but the table name comes from a fixed internal
    // constant, never from user input — safe to format here.
    let sql = format!("SELECT COUNT(*) FROM {}", table);
    conn.query_row(&sql, [], |r| r.get::<_, i64>(0))
        .unwrap_or(-1)
}

/// Build a `HashMap` of default timeouts for all 16 genome containers.
///
/// Used as a fallback when the database is unavailable so that callers always
/// receive a complete map regardless of DB state.
fn default_all_timeouts() -> HashMap<String, AdaptiveTimeout> {
    const ALL_CONTAINERS: &[&str] = &[
        "indrajaal-db-prod",
        "indrajaal-obs-prod",
        "indrajaal-ex-app-1",
        "cepaf-bridge",
        "indrajaal-cortex",
        "zenoh-router",
        "indrajaal-ollama",
        "indrajaal-mojo",
        "zenoh-router-1",
        "zenoh-router-2",
        "zenoh-router-3",
        "indrajaal-ex-app-2",
        "indrajaal-ex-app-3",
        "indrajaal-chaya",
        "indrajaal-ml-runner-1",
        "indrajaal-ml-runner-2",
    ];

    ALL_CONTAINERS
        .iter()
        .map(|&name| {
            (
                name.to_string(),
                AdaptiveTimeout {
                    container_name: name.to_string(),
                    base_timeout_ms: BOOT_TIMEOUT_MS,
                    ema_timeout_ms: BOOT_TIMEOUT_MS,
                    multiplier: EMA_TIMEOUT_MULTIPLIER,
                    source: TimeoutSource::Default,
                },
            )
        })
        .collect()
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::Connection;

    // ─── Helpers ─────────────────────────────────────────────────────────────

    /// Create an in-memory SQLite database pre-seeded with the F# schema.
    fn in_memory_db() -> Connection {
        let conn = Connection::open_in_memory().expect("open in-memory DB");

        conn.execute_batch(
            "CREATE TABLE build_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                container_name TEXT NOT NULL,
                action TEXT NOT NULL,
                success INTEGER NOT NULL,
                duration_ms INTEGER NOT NULL,
                image_size_bytes INTEGER,
                cache_hits INTEGER,
                cache_misses INTEGER,
                step_count INTEGER,
                timestamp TEXT NOT NULL,
                error TEXT
            );
            CREATE TABLE build_ema (
                container_name TEXT PRIMARY KEY,
                ema_duration_ms REAL NOT NULL,
                ema_image_size REAL NOT NULL,
                total_builds INTEGER NOT NULL,
                last_success TEXT,
                last_failure TEXT
            );",
        )
        .expect("create schema");

        conn
    }

    /// Seed one EMA record.
    fn seed_ema(conn: &Connection, name: &str, ema_ms: f64, total: i64) {
        conn.execute(
            "INSERT INTO build_ema \
             (container_name, ema_duration_ms, ema_image_size, total_builds, last_success, last_failure) \
             VALUES (?1, ?2, 0.0, ?3, '2026-04-01T00:00:00Z', NULL)",
            rusqlite::params![name, ema_ms, total],
        )
        .expect("seed_ema");
    }

    /// Seed one build_history record.
    fn seed_build(conn: &Connection, name: &str, success: bool, duration_ms: i64) {
        conn.execute(
            "INSERT INTO build_history \
             (container_name, action, success, duration_ms, timestamp) \
             VALUES (?1, 'build', ?2, ?3, '2026-04-01T00:00:00Z')",
            rusqlite::params![name, success as i64, duration_ms],
        )
        .expect("seed_build");
    }

    // ─── clamp_timeout ───────────────────────────────────────────────────────

    #[test]
    fn clamp_below_minimum_returns_minimum() {
        assert_eq!(clamp_timeout(0), MIN_ADAPTIVE_TIMEOUT_MS);
        assert_eq!(clamp_timeout(1_000), MIN_ADAPTIVE_TIMEOUT_MS);
        assert_eq!(clamp_timeout(14_999), MIN_ADAPTIVE_TIMEOUT_MS);
    }

    #[test]
    fn clamp_within_range_passes_through() {
        assert_eq!(clamp_timeout(60_000), 60_000);
        assert_eq!(
            clamp_timeout(MIN_ADAPTIVE_TIMEOUT_MS),
            MIN_ADAPTIVE_TIMEOUT_MS
        );
        assert_eq!(
            clamp_timeout(MAX_ADAPTIVE_TIMEOUT_MS),
            MAX_ADAPTIVE_TIMEOUT_MS
        );
    }

    #[test]
    fn clamp_above_maximum_returns_maximum() {
        assert_eq!(clamp_timeout(700_000), MAX_ADAPTIVE_TIMEOUT_MS);
        assert_eq!(clamp_timeout(u64::MAX), MAX_ADAPTIVE_TIMEOUT_MS);
    }

    // ─── compute_ema ─────────────────────────────────────────────────────────

    #[test]
    fn compute_ema_matches_fsharp_formula() {
        // F# formula: new_ema = alpha * current + (1 - alpha) * old_ema
        // alpha = 0.3
        let result = compute_ema(100.0, 200.0);
        let expected = 0.3 * 200.0 + 0.7 * 100.0; // = 130.0
        assert!(
            (result - expected).abs() < 1e-9,
            "got {result}, expected {expected}"
        );
    }

    #[test]
    fn compute_ema_converges_to_observation_after_many_steps() {
        let mut ema = 1000.0_f64;
        for _ in 0..100 {
            ema = compute_ema(ema, 50.0);
        }
        // After 100 iterations the EMA should be very close to 50
        assert!(ema < 51.0, "EMA did not converge: {ema}");
    }

    // ─── predict_next_duration ───────────────────────────────────────────────

    #[test]
    fn predict_returns_ema_when_positive() {
        let record = BuildEmaRecord {
            container_name: "test".into(),
            ema_duration_ms: 42_000.0,
            ema_image_size: 0.0,
            total_builds: 5,
            last_success: None,
            last_failure: None,
        };
        assert!((predict_next_duration(&record) - 42_000.0).abs() < 1e-6);
    }

    #[test]
    fn predict_returns_safe_minimum_for_zero_ema() {
        let record = BuildEmaRecord {
            container_name: "bad".into(),
            ema_duration_ms: 0.0,
            ema_image_size: 0.0,
            total_builds: 0,
            last_success: None,
            last_failure: None,
        };
        let result = predict_next_duration(&record);
        assert!(result > 0.0, "predict must not return zero for zero EMA");
    }

    // ─── read_ema ────────────────────────────────────────────────────────────

    #[test]
    fn read_ema_returns_none_for_unknown_container() {
        let conn = in_memory_db();
        let result = read_ema(&conn, "nonexistent").expect("query should succeed");
        assert!(result.is_none());
    }

    #[test]
    fn read_ema_returns_record_when_seeded() {
        let conn = in_memory_db();
        seed_ema(&conn, "indrajaal-ex-app-1", 90_000.0, 3);

        let result = read_ema(&conn, "indrajaal-ex-app-1")
            .expect("query ok")
            .expect("record present");

        assert_eq!(result.container_name, "indrajaal-ex-app-1");
        assert!((result.ema_duration_ms - 90_000.0).abs() < 1e-6);
        assert_eq!(result.total_builds, 3);
    }

    // ─── read_all_ema ────────────────────────────────────────────────────────

    #[test]
    fn read_all_ema_empty_table_returns_empty_vec() {
        let conn = in_memory_db();
        let records = read_all_ema(&conn).expect("query ok");
        assert!(records.is_empty());
    }

    #[test]
    fn read_all_ema_returns_all_seeded_records() {
        let conn = in_memory_db();
        seed_ema(&conn, "container-a", 10_000.0, 1);
        seed_ema(&conn, "container-b", 20_000.0, 2);
        seed_ema(&conn, "container-c", 30_000.0, 3);

        let records = read_all_ema(&conn).expect("query ok");
        assert_eq!(records.len(), 3);

        // Verify ordering (ASC by container_name)
        assert_eq!(records[0].container_name, "container-a");
        assert_eq!(records[1].container_name, "container-b");
        assert_eq!(records[2].container_name, "container-c");
    }

    // ─── adaptive_timeout ────────────────────────────────────────────────────

    #[test]
    fn adaptive_timeout_uses_default_when_no_ema() {
        let conn = in_memory_db();
        let t = adaptive_timeout(&conn, "unknown-container", BOOT_TIMEOUT_MS);

        assert_eq!(t.source, TimeoutSource::Default);
        assert_eq!(t.ema_timeout_ms, BOOT_TIMEOUT_MS);
        assert_eq!(t.base_timeout_ms, BOOT_TIMEOUT_MS);
    }

    #[test]
    fn adaptive_timeout_uses_build_oracle_when_ema_present() {
        let conn = in_memory_db();
        // EMA = 40 000 ms → raw = 40 000 × 2.5 = 100 000 ms → clamped = 100 000 ms
        seed_ema(&conn, "indrajaal-db-prod", 40_000.0, 5);

        let t = adaptive_timeout(&conn, "indrajaal-db-prod", BOOT_TIMEOUT_MS);

        assert_eq!(t.source, TimeoutSource::BuildOracle);
        let expected = clamp_timeout((40_000.0 * EMA_TIMEOUT_MULTIPLIER) as u64);
        assert_eq!(t.ema_timeout_ms, expected);
    }

    #[test]
    fn adaptive_timeout_clamps_very_fast_ema() {
        let conn = in_memory_db();
        // EMA = 100 ms → raw = 100 × 2.5 = 250 ms — below MIN (15 000 ms)
        seed_ema(&conn, "zenoh-router", 100.0, 10);

        let t = adaptive_timeout(&conn, "zenoh-router", BOOT_TIMEOUT_MS);

        assert_eq!(t.source, TimeoutSource::BuildOracle);
        assert_eq!(t.ema_timeout_ms, MIN_ADAPTIVE_TIMEOUT_MS);
    }

    #[test]
    fn adaptive_timeout_clamps_very_slow_ema() {
        let conn = in_memory_db();
        // EMA = 300 000 ms → raw = 750 000 ms — above MAX (600 000 ms)
        seed_ema(&conn, "indrajaal-ollama", 300_000.0, 2);

        let t = adaptive_timeout(&conn, "indrajaal-ollama", BOOT_TIMEOUT_MS);

        assert_eq!(t.source, TimeoutSource::BuildOracle);
        assert_eq!(t.ema_timeout_ms, MAX_ADAPTIVE_TIMEOUT_MS);
    }

    // ─── all_adaptive_timeouts ───────────────────────────────────────────────

    #[test]
    fn all_adaptive_timeouts_covers_all_16_containers() {
        let conn = in_memory_db();
        let map = all_adaptive_timeouts(&conn);

        assert_eq!(map.len(), 16, "genome must have exactly 16 entries");

        // Spot-check a few names
        assert!(map.contains_key("zenoh-router"));
        assert!(map.contains_key("indrajaal-ex-app-1"));
        assert!(map.contains_key("indrajaal-ml-runner-2"));
        assert!(map.contains_key("cepaf-bridge"));
    }

    #[test]
    fn all_adaptive_timeouts_mixes_oracle_and_default_sources() {
        let conn = in_memory_db();
        seed_ema(&conn, "indrajaal-ex-app-1", 80_000.0, 4);
        seed_ema(&conn, "indrajaal-db-prod", 30_000.0, 6);

        let map = all_adaptive_timeouts(&conn);

        assert_eq!(map["indrajaal-ex-app-1"].source, TimeoutSource::BuildOracle);
        assert_eq!(map["indrajaal-db-prod"].source, TimeoutSource::BuildOracle);
        assert_eq!(map["zenoh-router"].source, TimeoutSource::Default);
    }

    // ─── recent_builds ───────────────────────────────────────────────────────

    #[test]
    fn recent_builds_returns_empty_for_unknown_container() {
        let conn = in_memory_db();
        let records = recent_builds(&conn, "never-built", 10).expect("query ok");
        assert!(records.is_empty());
    }

    #[test]
    fn recent_builds_returns_up_to_limit() {
        let conn = in_memory_db();
        for i in 0..5 {
            seed_build(&conn, "indrajaal-obs-prod", true, i * 1000);
        }

        let three = recent_builds(&conn, "indrajaal-obs-prod", 3).expect("query ok");
        assert_eq!(three.len(), 3, "should return at most limit rows");

        let all = recent_builds(&conn, "indrajaal-obs-prod", 100).expect("query ok");
        assert_eq!(all.len(), 5, "should return all 5 rows");
    }

    #[test]
    fn recent_builds_parses_success_field_correctly() {
        let conn = in_memory_db();
        seed_build(&conn, "indrajaal-cortex", true, 5_000);
        seed_build(&conn, "indrajaal-cortex", false, 3_000);

        let records = recent_builds(&conn, "indrajaal-cortex", 10).expect("query ok");
        assert_eq!(records.len(), 2);

        // Most recent first (ORDER BY id DESC)
        let has_failure = records.iter().any(|r| !r.success);
        let has_success = records.iter().any(|r| r.success);
        assert!(has_failure && has_success);
    }

    // ─── build_statistics ────────────────────────────────────────────────────

    #[test]
    fn build_statistics_empty_db_returns_zeros() {
        let conn = in_memory_db();
        let stats = build_statistics(&conn).expect("query ok");

        assert_eq!(stats.total_builds, 0);
        assert_eq!(stats.successful_builds, 0);
        assert_eq!(stats.failed_builds, 0);
        assert!((stats.avg_duration_ms - 0.0).abs() < 1e-9);
        assert_eq!(stats.containers_with_ema, 0);
    }

    #[test]
    fn build_statistics_counts_correctly() {
        let conn = in_memory_db();

        seed_build(&conn, "c1", true, 10_000);
        seed_build(&conn, "c1", true, 20_000);
        seed_build(&conn, "c2", false, 5_000);
        seed_ema(&conn, "c1", 15_000.0, 2);

        let stats = build_statistics(&conn).expect("query ok");

        assert_eq!(stats.total_builds, 3);
        assert_eq!(stats.successful_builds, 2);
        assert_eq!(stats.failed_builds, 1);
        // avg of 10_000 and 20_000 = 15_000
        assert!((stats.avg_duration_ms - 15_000.0).abs() < 1.0);
        assert_eq!(stats.containers_with_ema, 1);
    }

    // ─── check_db_health ─────────────────────────────────────────────────────

    #[test]
    fn check_db_health_in_memory_shows_not_wal() {
        // In-memory databases do not use WAL mode
        let conn = in_memory_db();
        let health = check_db_health(&conn).expect("query ok");

        assert!(health.db_exists);
        // In-memory: journal_mode = "memory", not "wal"
        assert!(!health.wal_mode);
        assert_eq!(health.build_history_rows, 0);
        assert_eq!(health.ema_rows, 0);
    }

    #[test]
    fn check_db_health_reflects_row_counts() {
        let conn = in_memory_db();
        seed_build(&conn, "test", true, 1_000);
        seed_ema(&conn, "test", 1_000.0, 1);

        let health = check_db_health(&conn).expect("query ok");

        assert_eq!(health.build_history_rows, 1);
        assert_eq!(health.ema_rows, 1);
        assert!(health.newest_record.is_some());
        assert!(health.oldest_record.is_some());
    }

    // ─── count_rows ──────────────────────────────────────────────────────────

    #[test]
    fn count_rows_returns_minus_one_for_missing_table() {
        let conn = Connection::open_in_memory().unwrap();
        // No tables created — count_rows should return -1
        let result = count_rows(&conn, "nonexistent_table");
        assert_eq!(result, -1);
    }

    // ─── default_all_timeouts ────────────────────────────────────────────────

    #[test]
    fn default_all_timeouts_has_16_entries_all_default_source() {
        let map = default_all_timeouts();
        assert_eq!(map.len(), 16);
        for (_, t) in &map {
            assert_eq!(t.source, TimeoutSource::Default);
            assert_eq!(t.ema_timeout_ms, BOOT_TIMEOUT_MS);
        }
    }

    // ─── load_timeouts (integration-style, no real FS) ───────────────────────

    #[test]
    fn load_timeouts_returns_16_entries_when_db_absent() {
        // BUILD_HISTORY_DB_PATH almost certainly doesn't exist in test env
        // (and even if it does, the fallback path still returns 16 entries).
        let map = load_timeouts();
        assert_eq!(map.len(), 16);
    }
}
