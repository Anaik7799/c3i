//! scripts_nif — Rust NIFs for the scripts-gleam subproject.
//!
//! STAMP: SC-SCRIPT-GLEAM-001, SC-NIF-001..005, SC-ZENOH-001
//!
//! Functional surfaces:
//!   * Utilities:  now_nanos, uuid_v7, sha256_hex
//!   * Smriti:     smriti_get_pref, smriti_set_pref, smriti_get_task
//!   * Zenoh:      zenoh_open_session, zenoh_put, zenoh_get, zenoh_session_info
//!   * Fractal:    fractal_span_emit  (emits OTel-shaped span + Zenoh publish)
//!   * Gemini:     gemini_generate     (HTTP POST generateContent)
//!   * OpenRouter: openrouter_generate (HTTP POST chat/completions)
//!   * Ollama:     ollama_generate     (HTTP POST /api/generate)
//!   * MCP:        mcp_invoke_moz      (MCP-over-Zenoh request/response)
//!   * Metrics:    metrics_counter_inc, metrics_histogram_observe, metrics_snapshot
//!
//! All NIFs are synchronous wrappers around a shared tokio runtime so BEAM
//! scheduler impact is bounded (SC-NIF-001); long-running Zenoh work happens
//! on tokio's own worker threads.

use once_cell::sync::OnceCell;
use parking_lot::Mutex;
use rustler::{Atom, Env, Error, NifResult, Term};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tokio::runtime::Runtime;

// ─── fastembed (pure-Rust ONNX embeddings) ─────────────────────────────────
use fastembed::{EmbeddingModel, InitOptions, TextEmbedding};

fn fastembed_model() -> Result<&'static Mutex<TextEmbedding>, String> {
    static CELL: OnceCell<Mutex<TextEmbedding>> = OnceCell::new();
    if let Some(m) = CELL.get() {
        return Ok(m);
    }
    let opts = InitOptions::new(EmbeddingModel::NomicEmbedTextV15);
    let model = TextEmbedding::try_new(opts)
        .map_err(|e| format!("fastembed init: {}", e))?;
    let _ = CELL.set(Mutex::new(model));
    Ok(CELL.get().expect("just set"))
}

/// Encode a `Vec<f32>` as little-endian 4-byte chunks (the existing schema).
fn encode_f32_blob(v: &[f32]) -> Vec<u8> {
    let mut out = Vec::with_capacity(v.len() * 4);
    for f in v {
        out.extend_from_slice(&f.to_le_bytes());
    }
    out
}

/// Decode a little-endian f32 BLOB back to a `Vec<f32>`.
fn decode_f32_blob(bytes: &[u8]) -> Vec<f32> {
    bytes
        .chunks_exact(4)
        .map(|c| f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
        .collect()
}

/// Cosine similarity between two equal-length vectors.
fn cosine(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() || a.is_empty() {
        return 0.0;
    }
    let mut dot = 0.0f32;
    let mut na = 0.0f32;
    let mut nb = 0.0f32;
    for i in 0..a.len() {
        dot += a[i] * b[i];
        na += a[i] * a[i];
        nb += b[i] * b[i];
    }
    let denom = na.sqrt() * nb.sqrt();
    if denom == 0.0 {
        0.0
    } else {
        dot / denom
    }
}

/// Single-input embed. Returns `(:ok, json_array)` where json_array is the
/// 768-element float list serialised as JSON so gleam can store it verbatim.
#[rustler::nif(schedule = "DirtyCpu")]
fn fastembed_embed_one(text: String) -> NifResult<(Atom, String)> {
    let model = match fastembed_model() {
        Ok(m) => m,
        Err(e) => return Ok((atoms::error(), e)),
    };
    let m = model.lock();
    let out = match m.embed(vec![text], None) {
        Ok(v) => v,
        Err(e) => return Ok((atoms::error(), format!("embed: {}", e))),
    };
    match out.into_iter().next() {
        Some(vec) => Ok((atoms::ok(), serde_json::to_string(&vec).unwrap_or_default())),
        None => Ok((atoms::error(), "empty embed".to_string())),
    }
}

/// Embed-and-write: embed the given text with fastembed, encode as little-endian
/// f32 BLOB, and upsert into holon_embeddings for `holon_id`. Returns
/// `(:ok, bytes_written)`.
#[rustler::nif(schedule = "DirtyIo")]
fn fastembed_embed_and_store(
    db_path: String,
    holon_id: String,
    text: String,
) -> NifResult<(Atom, String)> {
    let model = match fastembed_model() {
        Ok(m) => m,
        Err(e) => return Ok((atoms::error(), e)),
    };
    let vec = {
        let m = model.lock();
        match m.embed(vec![text], None) {
            Ok(mut v) => match v.pop() {
                Some(v) => v,
                None => return Ok((atoms::error(), "empty embed".to_string())),
            },
            Err(e) => return Ok((atoms::error(), format!("embed: {}", e))),
        }
    };
    let blob = encode_f32_blob(&vec);
    let handle = match open_db(&db_path) {
        Ok(h) => h,
        Err(e) => return Ok((atoms::error(), e)),
    };
    let conn = handle.lock();
    let rows = match conn.execute(
        "INSERT OR REPLACE INTO holon_embeddings (holon_id, embedding, model, dims) VALUES (?1, ?2, ?3, ?4)",
        rusqlite::params![holon_id, blob, "nomic-embed-text-v1.5", 768i64],
    ) {
        Ok(n) => n,
        Err(e) => return Ok((atoms::error(), format!("sql: {}", e))),
    };
    Ok((atoms::ok(), format!("rows={} bytes={}", rows, blob.len())))
}

/// Rerank: given a query text and a list of candidate (holon_id, embedding_blob) pairs,
/// return JSON array of `{holon_id, score}` sorted descending.
/// The candidate list is encoded as JSON: `[{"id":"zk-...","emb":"<hex>"}, ...]`
/// where hex is the BLOB encoded as lowercase hex chars.
#[rustler::nif(schedule = "DirtyCpu")]
fn fastembed_rerank_query(
    db_path: String,
    query_text: String,
    candidate_uuids_json: String,
) -> NifResult<(Atom, String)> {
    // 1. Embed query.
    let query_vec = {
        let model = match fastembed_model() {
            Ok(m) => m,
            Err(e) => return Ok((atoms::error(), e)),
        };
        let m = model.lock();
        match m.embed(vec![query_text], None) {
            Ok(mut v) => match v.pop() {
                Some(v) => v,
                None => return Ok((atoms::error(), "empty query embed".to_string())),
            },
            Err(e) => return Ok((atoms::error(), format!("embed: {}", e))),
        }
    };

    // 2. Parse candidate UUIDs.
    let uuids: Vec<String> = match serde_json::from_str(&candidate_uuids_json) {
        Ok(v) => v,
        Err(e) => return Ok((atoms::error(), format!("json: {}", e))),
    };

    // 3. Fetch embeddings by BLOB from DB.
    let handle = match open_db(&db_path) {
        Ok(h) => h,
        Err(e) => return Ok((atoms::error(), e)),
    };
    let conn = handle.lock();
    let mut scores: Vec<(String, f32)> = Vec::with_capacity(uuids.len());
    for uuid in &uuids {
        if let Ok(blob) = conn.query_row::<Vec<u8>, _, _>(
            "SELECT embedding FROM holon_embeddings WHERE holon_id = ?1",
            [uuid],
            |r| r.get(0),
        ) {
            let doc = decode_f32_blob(&blob);
            // Guard: embed model may differ; skip length mismatch.
            if doc.len() == query_vec.len() {
                let s = cosine(&query_vec, &doc);
                scores.push((uuid.clone(), s));
            }
        }
    }
    scores.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
    let json = serde_json::to_string(
        &scores
            .into_iter()
            .map(|(id, s)| serde_json::json!({"id": id, "score": s}))
            .collect::<Vec<_>>(),
    )
    .unwrap_or_default();
    Ok((atoms::ok(), json))
}

/// Batch embed — much faster per-doc when N > ~8.
/// Input: a JSON-encoded array of strings `["text1","text2",...]`.
/// Output: `(:ok, json)` where json is a JSON array of float arrays.
#[rustler::nif(schedule = "DirtyCpu")]
fn fastembed_embed_batch(texts_json: String) -> NifResult<(Atom, String)> {
    let texts: Vec<String> = match serde_json::from_str(&texts_json) {
        Ok(v) => v,
        Err(e) => return Ok((atoms::error(), format!("json parse: {}", e))),
    };
    let model = match fastembed_model() {
        Ok(m) => m,
        Err(e) => return Ok((atoms::error(), e)),
    };
    let m = model.lock();
    let out = match m.embed(texts, None) {
        Ok(v) => v,
        Err(e) => return Ok((atoms::error(), format!("embed: {}", e))),
    };
    match serde_json::to_string(&out) {
        Ok(s) => Ok((atoms::ok(), s)),
        Err(e) => Ok((atoms::error(), format!("ser: {}", e))),
    }
}

/// Health probe for the embed subsystem.
#[rustler::nif]
fn fastembed_info() -> NifResult<(Atom, String)> {
    let initialised = fastembed_model().is_ok();
    let json = serde_json::json!({
        "model": "nomic-embed-text-v1.5",
        "dims": 768,
        "backend": "fastembed-rs + ort",
        "initialised": initialised,
    });
    Ok((atoms::ok(), json.to_string()))
}
use uuid::Uuid;
use zenoh::qos::{CongestionControl, Priority};
use zenoh::Session;

mod atoms {
    rustler::atoms! { ok, error, nil }
}

// ─── Shared runtime + Zenoh session ──────────────────────────────────────────

fn runtime() -> &'static Runtime {
    static RT: OnceCell<Runtime> = OnceCell::new();
    RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(4)
            .enable_all()
            .thread_name("scripts-nif-tokio")
            .build()
            .expect("tokio runtime init")
    })
}

fn session_cell() -> &'static Mutex<Option<Arc<Session>>> {
    static CELL: OnceCell<Mutex<Option<Arc<Session>>>> = OnceCell::new();
    CELL.get_or_init(|| Mutex::new(None))
}

async fn ensure_session() -> Result<Arc<Session>, String> {
    let cell = session_cell();
    {
        let guard = cell.lock();
        if let Some(s) = guard.clone() {
            return Ok(s);
        }
    }
    let cfg = zenoh::Config::default();
    let session = zenoh::open(cfg)
        .await
        .map_err(|e| format!("zenoh open: {}", e))?;
    let arc = Arc::new(session);
    *cell.lock() = Some(arc.clone());
    Ok(arc)
}

fn err<T>(e: impl Into<String>) -> NifResult<T> {
    Err(Error::Term(Box::new(e.into())))
}

// ─── Utility NIFs ────────────────────────────────────────────────────────────

#[rustler::nif]
fn now_nanos() -> i64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos() as i64)
        .unwrap_or(0)
}

#[rustler::nif]
fn uuid_v7() -> String {
    Uuid::now_v7().to_string()
}

#[rustler::nif]
fn sha256_hex(input: String) -> String {
    let mut h = Sha256::new();
    h.update(input.as_bytes());
    format!("{:x}", h.finalize())
}

// ─── Smriti (SQLite) NIFs ────────────────────────────────────────────────────
//
// These open the Smriti/planning DB read/write for scripts. The DB schema is
// the same one used by sa-plan; we intentionally use a bundled rusqlite so
// there is ZERO coupling to cepaf_gleam's esqlite NIF.

/// Cache of open Smriti connections keyed by absolute DB path.
/// Addresses SC-SCRIPT-GLEAM-001 scalability dimension #18 (Smriti at scale):
/// WAL journal, NORMAL sync, reused connections.
fn smriti_pool() -> &'static Mutex<HashMap<String, Arc<Mutex<Connection>>>> {
    static CELL: OnceCell<Mutex<HashMap<String, Arc<Mutex<Connection>>>>> = OnceCell::new();
    CELL.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Open (or reuse) a pooled Smriti connection with WAL + NORMAL sync.
fn open_db(path: &str) -> Result<Arc<Mutex<Connection>>, String> {
    {
        let pool = smriti_pool().lock();
        if let Some(c) = pool.get(path) {
            return Ok(c.clone());
        }
    }
    let conn = Connection::open(path).map_err(|e| format!("sqlite open {}: {}", path, e))?;
    // Performance + durability tuning for concurrent scripts; idempotent.
    let _ = conn.execute_batch(
        "PRAGMA journal_mode=WAL;\n\
         PRAGMA synchronous=NORMAL;\n\
         PRAGMA busy_timeout=5000;",
    );
    let handle = Arc::new(Mutex::new(conn));
    smriti_pool().lock().insert(path.to_string(), handle.clone());
    Ok(handle)
}

/// Returns `(ok, value)` where empty string means "not found" so the gleam
/// FFI layer does not need to carry an `Option` across the NIF boundary.
///
/// Schema matches the authoritative `UserPreferences` table maintained by
/// sa-plan (PascalCase column names).
#[rustler::nif]
fn smriti_get_pref(db_path: String, key: String) -> NifResult<(Atom, String)> {
    let handle = open_db(&db_path).map_err(|e| Error::Term(Box::new(e)))?;
    let conn = handle.lock();
    let row = conn
        .query_row(
            "SELECT Value FROM UserPreferences WHERE Key = ?1",
            rusqlite::params![key],
            |r| r.get::<_, String>(0),
        )
        .unwrap_or_default();
    Ok((atoms::ok(), row))
}

#[rustler::nif]
fn smriti_set_pref(
    db_path: String,
    category: String,
    key: String,
    value: String,
) -> NifResult<(Atom, String)> {
    let handle = open_db(&db_path).map_err(|e| Error::Term(Box::new(e)))?;
    let conn = handle.lock();
    let now = chrono::Utc::now().to_rfc3339();
    conn.execute(
        "INSERT OR REPLACE INTO UserPreferences (Key, Value, Category, UpdatedAt) VALUES (?1, ?2, ?3, ?4)",
        rusqlite::params![key, value, category, now],
    )
    .map_err(|e| Error::Term(Box::new(format!("upsert: {}", e))))?;
    Ok((atoms::ok(), format!("set {}.{} = {}", category, key, value)))
}

#[rustler::nif]
fn smriti_get_task(db_path: String, id: String) -> NifResult<(Atom, String)> {
    let handle = open_db(&db_path).map_err(|e| Error::Term(Box::new(e)))?;
    let conn = handle.lock();
    let row = conn
        .query_row(
            "SELECT json_object(
                'id', Id, 'title', Title, 'status', Status,
                'priority', Priority, 'parent_id', ParentId,
                'owner', Owner, 'created', Created
             ) FROM Tasks WHERE Id = ?1",
            rusqlite::params![id],
            |r| r.get::<_, String>(0),
        )
        .unwrap_or_default();
    Ok((atoms::ok(), row))
}

/// JSON snapshot of the Smriti connection pool (diagnostic).
#[rustler::nif]
fn smriti_pool_stats() -> NifResult<(Atom, String)> {
    let pool = smriti_pool().lock();
    let keys: Vec<&String> = pool.keys().collect();
    let json = serde_json::json!({ "open_connections": keys.len(), "paths": keys });
    Ok((atoms::ok(), json.to_string()))
}

// ─── Generic SQL NIFs (battle-hardened) ──────────────────────────────────────
//
// Exposed for SC-PASS8-IMPL-001 KMS operations. Every call:
//   * reuses the pooled WAL+NORMAL connection
//   * retries on `SQLITE_BUSY` / `SQLITE_LOCKED` up to 5 times with expo backoff
//   * serialises bind parameters as `Vec<String>` from gleam (simple + safe)
//   * returns rows as compact JSON (array of arrays); callers parse as needed
//   * wraps every error in `(:err, reason_string)` — never panics the BEAM

fn is_busy_err(e: &rusqlite::Error) -> bool {
    use rusqlite::ErrorCode;
    match e {
        rusqlite::Error::SqliteFailure(f, _) => {
            f.code == ErrorCode::DatabaseBusy || f.code == ErrorCode::DatabaseLocked
        }
        _ => false,
    }
}

fn with_retry<T, F>(mut op: F) -> Result<T, String>
where
    F: FnMut() -> Result<T, rusqlite::Error>,
{
    let mut delay_ms = 10u64;
    for attempt in 0..5u32 {
        match op() {
            Ok(v) => return Ok(v),
            Err(e) if is_busy_err(&e) => {
                std::thread::sleep(std::time::Duration::from_millis(delay_ms));
                delay_ms = (delay_ms * 2).min(500);
                if attempt == 4 {
                    return Err(format!("sqlite busy after 5 retries: {}", e));
                }
            }
            Err(e) => return Err(format!("sqlite error: {}", e)),
        }
    }
    Err("sqlite retries exhausted".to_string())
}

fn row_to_json(row: &rusqlite::Row<'_>, col_count: usize) -> Result<serde_json::Value, rusqlite::Error> {
    let mut arr = Vec::with_capacity(col_count);
    for i in 0..col_count {
        let v: rusqlite::types::Value = row.get::<usize, rusqlite::types::Value>(i)?;
        arr.push(match v {
            rusqlite::types::Value::Null => serde_json::Value::Null,
            rusqlite::types::Value::Integer(n) => serde_json::json!(n),
            rusqlite::types::Value::Real(f) => serde_json::json!(f),
            rusqlite::types::Value::Text(s) => serde_json::Value::String(s),
            rusqlite::types::Value::Blob(b) => serde_json::json!(base64_encode(&b)),
        });
    }
    Ok(serde_json::Value::Array(arr))
}

fn base64_encode(bytes: &[u8]) -> String {
    // Minimal base64 to avoid pulling another crate; blobs only (rare in KMS reads).
    const TABLE: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = Vec::with_capacity(bytes.len() * 4 / 3 + 4);
    let mut i = 0;
    while i + 3 <= bytes.len() {
        let b0 = bytes[i] as usize;
        let b1 = bytes[i + 1] as usize;
        let b2 = bytes[i + 2] as usize;
        out.push(TABLE[(b0 >> 2) & 0x3f]);
        out.push(TABLE[((b0 << 4) | (b1 >> 4)) & 0x3f]);
        out.push(TABLE[((b1 << 2) | (b2 >> 6)) & 0x3f]);
        out.push(TABLE[b2 & 0x3f]);
        i += 3;
    }
    let rem = bytes.len() - i;
    if rem == 1 {
        let b0 = bytes[i] as usize;
        out.push(TABLE[(b0 >> 2) & 0x3f]);
        out.push(TABLE[(b0 << 4) & 0x3f]);
        out.push(b'=');
        out.push(b'=');
    } else if rem == 2 {
        let b0 = bytes[i] as usize;
        let b1 = bytes[i + 1] as usize;
        out.push(TABLE[(b0 >> 2) & 0x3f]);
        out.push(TABLE[((b0 << 4) | (b1 >> 4)) & 0x3f]);
        out.push(TABLE[(b1 << 2) & 0x3f]);
        out.push(b'=');
    }
    String::from_utf8(out).unwrap_or_default()
}

fn bind_params<'a>(
    stmt: &'a mut rusqlite::Statement,
    params: &'a [String],
) -> Result<(), rusqlite::Error> {
    for (idx, v) in params.iter().enumerate() {
        stmt.raw_bind_parameter(idx + 1, v)?;
    }
    Ok(())
}

/// Generic SELECT/PRAGMA executor with retry + positional params.
/// Returns `(:ok, json)` where json is `{"columns": [...], "rows": [[...],...]}`.
#[rustler::nif(schedule = "DirtyIo")]
fn smriti_query(
    db_path: String,
    sql: String,
    params: Vec<String>,
) -> NifResult<(Atom, String)> {
    let handle = open_db(&db_path).map_err(|e| Error::Term(Box::new(e)))?;
    let conn = handle.lock();
    let res = with_retry(|| -> Result<String, rusqlite::Error> {
        let mut stmt = conn.prepare(&sql)?;
        let col_names: Vec<String> = stmt
            .column_names()
            .iter()
            .map(|s| (*s).to_string())
            .collect();
        let col_count = col_names.len();
        bind_params(&mut stmt, &params)?;
        let mut rows = stmt.raw_query();
        let mut out = Vec::new();
        while let Some(row) = rows.next()? {
            out.push(row_to_json(row, col_count)?);
        }
        let json = serde_json::json!({ "columns": col_names, "rows": out });
        Ok(json.to_string())
    });
    match res {
        Ok(json) => Ok((atoms::ok(), json)),
        Err(e) => Ok((atoms::error(), e)),
    }
}

/// Generic INSERT/UPDATE/DELETE/DDL executor with retry + positional params.
/// Returns `(:ok, rows_affected_as_string)`.
#[rustler::nif(schedule = "DirtyIo")]
fn smriti_exec(
    db_path: String,
    sql: String,
    params: Vec<String>,
) -> NifResult<(Atom, String)> {
    let handle = open_db(&db_path).map_err(|e| Error::Term(Box::new(e)))?;
    let conn = handle.lock();
    let res = with_retry(|| -> Result<usize, rusqlite::Error> {
        let mut stmt = conn.prepare(&sql)?;
        let mut ps: Vec<&dyn rusqlite::ToSql> = Vec::with_capacity(params.len());
        for p in &params {
            ps.push(p);
        }
        stmt.execute(rusqlite::params_from_iter(params.iter()))
    });
    match res {
        Ok(n) => Ok((atoms::ok(), n.to_string())),
        Err(e) => Ok((atoms::error(), e)),
    }
}

/// Execute a batch of DDL/DML separated by semicolons.  Atomic: either the
/// whole batch commits or nothing does (transaction-wrapped).
#[rustler::nif(schedule = "DirtyIo")]
fn smriti_exec_batch(db_path: String, sql_batch: String) -> NifResult<(Atom, String)> {
    let handle = open_db(&db_path).map_err(|e| Error::Term(Box::new(e)))?;
    let mut conn = handle.lock();
    let res = with_retry(|| -> Result<usize, rusqlite::Error> {
        let tx = conn.transaction()?;
        tx.execute_batch(&sql_batch)?;
        tx.commit()?;
        Ok(0)
    });
    match res {
        Ok(_) => Ok((atoms::ok(), "batch committed".to_string())),
        Err(e) => Ok((atoms::error(), e)),
    }
}

/// Health probe — returns JSON with pool size, path, wal+busy pragmas.
#[rustler::nif]
fn smriti_health(db_path: String) -> NifResult<(Atom, String)> {
    let handle = match open_db(&db_path) {
        Ok(h) => h,
        Err(e) => return Ok((atoms::error(), e)),
    };
    let conn = handle.lock();
    let journal: String = conn
        .query_row("PRAGMA journal_mode", [], |r| r.get(0))
        .unwrap_or_default();
    let busy: i64 = conn
        .query_row("PRAGMA busy_timeout", [], |r| r.get(0))
        .unwrap_or(0);
    let sync: i64 = conn
        .query_row("PRAGMA synchronous", [], |r| r.get(0))
        .unwrap_or(0);
    let wal_pages: i64 = conn
        .query_row("PRAGMA wal_checkpoint(PASSIVE)", [], |r| r.get::<usize, i64>(0))
        .unwrap_or(-1);
    let json = serde_json::json!({
        "path": db_path,
        "journal_mode": journal,
        "busy_timeout_ms": busy,
        "synchronous": sync,
        "wal_checkpoint_pages": wal_pages,
    });
    Ok((atoms::ok(), json.to_string()))
}

// ─── Zenoh NIFs ──────────────────────────────────────────────────────────────

#[rustler::nif(schedule = "DirtyIo")]
fn zenoh_open_session() -> NifResult<(Atom, String)> {
    let rt = runtime();
    match rt.block_on(ensure_session()) {
        Ok(_) => Ok((atoms::ok(), "zenoh session open".to_string())),
        Err(e) => err(e),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn zenoh_put(key: String, payload: String) -> NifResult<(Atom, String)> {
    let rt = runtime();
    let res = rt.block_on(async move {
        let s = ensure_session().await?;
        s.put(&key, payload.clone())
            .await
            .map_err(|e| format!("zenoh put: {}", e))?;
        Ok::<_, String>(format!("put ok key={} bytes={}", key, payload.len()))
    });
    match res {
        Ok(msg) => Ok((atoms::ok(), msg)),
        Err(e) => err(e),
    }
}

/// Priority tiers (lower number = higher priority):
///   0 RealTime
///   1 InteractiveHigh
///   2 InteractiveLow
///   3 DataHigh
///   4 Data (default)
///   5 DataLow
///   6 Background
///
/// Congestion control:
///   "block"  - wait for capacity (default, lossless)
///   "drop"   - drop when congested (low-latency, lossy)
#[rustler::nif(schedule = "DirtyIo")]
fn zenoh_put_prio(
    key: String,
    payload: String,
    priority: u8,
    congestion: String,
) -> NifResult<(Atom, String)> {
    let rt = runtime();
    let prio = match priority {
        0 => Priority::RealTime,
        1 => Priority::InteractiveHigh,
        2 => Priority::InteractiveLow,
        3 => Priority::DataHigh,
        4 => Priority::Data,
        5 => Priority::DataLow,
        _ => Priority::Background,
    };
    let cc = match congestion.as_str() {
        "drop" => CongestionControl::Drop,
        _ => CongestionControl::Block,
    };
    let res = rt.block_on(async move {
        let s = ensure_session().await?;
        s.put(&key, payload.clone())
            .priority(prio)
            .congestion_control(cc)
            .await
            .map_err(|e| format!("zenoh put_prio: {}", e))?;
        Ok::<_, String>(format!("put_prio ok key={} bytes={}", key, payload.len()))
    });
    match res {
        Ok(msg) => Ok((atoms::ok(), msg)),
        Err(e) => err(e),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn zenoh_get(selector: String, timeout_ms: u64) -> NifResult<(Atom, Vec<String>)> {
    let rt = runtime();
    let res: Result<Vec<String>, String> = rt.block_on(async move {
        let s = ensure_session().await?;
        let replies = s
            .get(&selector)
            .await
            .map_err(|e| format!("zenoh get: {}", e))?;
        let mut out = Vec::new();
        let deadline = tokio::time::Instant::now() + Duration::from_millis(timeout_ms);
        loop {
            let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
            if remaining.is_zero() {
                break;
            }
            match tokio::time::timeout(remaining, replies.recv_async()).await {
                Ok(Ok(reply)) => {
                    match reply.result() {
                        Ok(sample) => {
                            let payload_str: String = match sample.payload().try_to_string() {
                                Ok(s) => s.to_string(),
                                Err(_) => format!("<{} bytes>", sample.payload().len()),
                            };
                            out.push(format!("{}|{}", sample.key_expr(), payload_str));
                        }
                        Err(e) => out.push(format!("!err|{}", e)),
                    }
                }
                Ok(Err(_)) | Err(_) => break,
            }
        }
        Ok(out)
    });
    match res {
        Ok(v) => Ok((atoms::ok(), v)),
        Err(e) => err(e),
    }
}

#[rustler::nif]
fn zenoh_session_info() -> NifResult<(Atom, String)> {
    let present = session_cell().lock().is_some();
    Ok((atoms::ok(), format!("{{\"session_open\":{}}}", present)))
}

// ─── Fractal span emitter ────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
struct FractalSpan {
    trace_id: String,
    span_id: String,
    layer: String, // "L0".."L7"
    name: String,
    start_unix_ns: i64,
    end_unix_ns: i64,
    status: String,
    attrs: serde_json::Value,
}

/// Emit a fractal observability span. Publishes to Zenoh topic
/// `indrajaal/<layer>/scripts/<name>` and returns the JSON line.
#[rustler::nif(schedule = "DirtyIo")]
fn fractal_span_emit(
    layer: String,
    name: String,
    start_ns: i64,
    end_ns: i64,
    status: String,
    attrs_json: String,
) -> NifResult<(Atom, String)> {
    let attrs: serde_json::Value =
        serde_json::from_str(&attrs_json).unwrap_or(serde_json::json!({}));
    let span = FractalSpan {
        trace_id: Uuid::now_v7().to_string(),
        span_id: Uuid::now_v7().to_string(),
        layer: layer.clone(),
        name: name.clone(),
        start_unix_ns: start_ns,
        end_unix_ns: end_ns,
        status,
        attrs,
    };
    let line = serde_json::to_string(&span).map_err(|e| Error::Term(Box::new(e.to_string())))?;

    // Best-effort Zenoh publish.
    let rt = runtime();
    let key = format!(
        "indrajaal/{}/scripts/{}",
        span.layer.to_lowercase(),
        span.name
    );
    let payload = line.clone();
    let _ = rt.block_on(async move {
        match ensure_session().await {
            Ok(s) => s.put(&key, payload).await.map_err(|e| e.to_string()),
            Err(e) => Err(e),
        }
    });

    Ok((atoms::ok(), line))
}

// ─── Gemini NIF ──────────────────────────────────────────────────────────────

#[derive(Serialize)]
struct GeminiRequest {
    contents: Vec<GeminiContent>,
}

#[derive(Serialize)]
struct GeminiContent {
    parts: Vec<GeminiPart>,
    role: String,
}

#[derive(Serialize)]
struct GeminiPart {
    text: String,
}

#[derive(Deserialize)]
struct GeminiResponse {
    #[serde(default)]
    candidates: Vec<GeminiCandidate>,
}

#[derive(Deserialize)]
struct GeminiCandidate {
    #[serde(default)]
    content: Option<GeminiContentResp>,
}

#[derive(Deserialize)]
struct GeminiContentResp {
    #[serde(default)]
    parts: Vec<GeminiPartResp>,
}

#[derive(Deserialize)]
struct GeminiPartResp {
    #[serde(default)]
    text: String,
}

#[rustler::nif(schedule = "DirtyIo")]
fn gemini_generate(
    model: String,
    api_key: String,
    prompt: String,
    timeout_ms: u64,
) -> NifResult<(Atom, String)> {
    let url = format!(
        "https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent?key={}",
        model, api_key
    );
    let body = GeminiRequest {
        contents: vec![GeminiContent {
            role: "user".into(),
            parts: vec![GeminiPart { text: prompt }],
        }],
    };

    let res: Result<String, String> = (|| {
        let client = reqwest::blocking::Client::builder()
            .timeout(Duration::from_millis(timeout_ms))
            .build()
            .map_err(|e| format!("client: {}", e))?;
        let resp = client
            .post(&url)
            .json(&body)
            .send()
            .map_err(|e| format!("send: {}", e))?;
        let status = resp.status().as_u16();
        let text = resp.text().unwrap_or_default();
        if status >= 400 {
            return Err(format!("http {} body={}", status, text));
        }
        let parsed: GeminiResponse =
            serde_json::from_str(&text).map_err(|e| format!("parse: {} body={}", e, text))?;
        let reply = parsed
            .candidates
            .into_iter()
            .next()
            .and_then(|c| c.content)
            .and_then(|c| c.parts.into_iter().next())
            .map(|p| p.text)
            .unwrap_or_default();
        Ok(reply)
    })();

    match res {
        Ok(t) => Ok((atoms::ok(), t)),
        Err(e) => err(e),
    }
}

// ─── Metrics (SC-SCRIPT-MET-001) ────────────────────────────────────────────
//
// Prometheus-style counter and histogram primitives. Backed by parking_lot
// maps so multiple scripts can share a single BEAM node without contention,
// and each update is best-effort published to Zenoh under
//   indrajaal/metrics/scripts/<metric>/<label>
// for downstream observability consumers.

fn metrics_counter_cell() -> &'static Mutex<HashMap<String, i64>> {
    static CELL: OnceCell<Mutex<HashMap<String, i64>>> = OnceCell::new();
    CELL.get_or_init(|| Mutex::new(HashMap::new()))
}

fn metrics_histo_cell() -> &'static Mutex<HashMap<String, Vec<f64>>> {
    static CELL: OnceCell<Mutex<HashMap<String, Vec<f64>>>> = OnceCell::new();
    CELL.get_or_init(|| Mutex::new(HashMap::new()))
}

fn mkey(metric: &str, label: &str) -> String {
    format!("{}|{}", metric, label)
}

fn publish_metric(metric: &str, label: &str, payload: String) {
    let rt = runtime();
    let key = format!("indrajaal/metrics/scripts/{}/{}", metric, label);
    let _ = rt.block_on(async move {
        if let Ok(s) = ensure_session().await {
            let _ = s.put(&key, payload).await;
        }
    });
}

#[rustler::nif(schedule = "DirtyCpu")]
fn metrics_counter_inc(metric: String, label: String, by: i64) -> NifResult<(Atom, i64)> {
    let k = mkey(&metric, &label);
    let new = {
        let mut m = metrics_counter_cell().lock();
        let v = m.entry(k.clone()).or_insert(0);
        *v += by;
        *v
    };
    publish_metric(
        &metric,
        &label,
        format!("{{\"kind\":\"counter\",\"value\":{}}}", new),
    );
    Ok((atoms::ok(), new))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn metrics_histogram_observe(
    metric: String,
    label: String,
    value: f64,
) -> NifResult<(Atom, i64)> {
    let k = mkey(&metric, &label);
    let count = {
        let mut m = metrics_histo_cell().lock();
        let bucket = m.entry(k.clone()).or_insert_with(Vec::new);
        bucket.push(value);
        bucket.len() as i64
    };
    publish_metric(
        &metric,
        &label,
        format!(
            "{{\"kind\":\"histogram\",\"observation\":{}}}",
            value
        ),
    );
    Ok((atoms::ok(), count))
}

/// Return a JSON snapshot `{"counters":{...},"histograms":{metric:[values]}}`.
#[rustler::nif]
fn metrics_snapshot() -> NifResult<(Atom, String)> {
    let counters: HashMap<String, i64> = metrics_counter_cell().lock().clone();
    let histos: HashMap<String, Vec<f64>> = metrics_histo_cell().lock().clone();
    let v = serde_json::json!({
        "counters": counters,
        "histograms": histos,
    });
    Ok((atoms::ok(), v.to_string()))
}

// ─── OpenRouter NIF ────────────────────────────────────────────────────────────────────────

#[derive(Serialize)]
struct OpenRouterReq<'a> {
    model: &'a str,
    messages: Vec<OrMsg<'a>>,
}

#[derive(Serialize)]
struct OrMsg<'a> {
    role: &'a str,
    content: &'a str,
}

#[derive(Deserialize)]
struct OrResp {
    #[serde(default)]
    choices: Vec<OrChoice>,
}

#[derive(Deserialize)]
struct OrChoice {
    #[serde(default)]
    message: Option<OrMessage>,
}

#[derive(Deserialize)]
struct OrMessage {
    #[serde(default)]
    content: String,
}

#[rustler::nif(schedule = "DirtyIo")]
fn openrouter_generate(
    api_key: String,
    model: String,
    prompt: String,
    timeout_ms: u64,
) -> NifResult<(Atom, String)> {
    let body = OpenRouterReq {
        model: &model,
        messages: vec![OrMsg { role: "user", content: &prompt }],
    };
    let res: Result<String, String> = (|| {
        let client = reqwest::blocking::Client::builder()
            .timeout(Duration::from_millis(timeout_ms))
            .build()
            .map_err(|e| format!("client: {}", e))?;
        let resp = client
            .post("https://openrouter.ai/api/v1/chat/completions")
            .header("Authorization", format!("Bearer {}", api_key))
            .header("HTTP-Referer", "https://vm-1.tail55d152.ts.net")
            .header("X-Title", "scripts-gleam")
            .json(&body)
            .send()
            .map_err(|e| format!("send: {}", e))?;
        let status = resp.status().as_u16();
        let text = resp.text().unwrap_or_default();
        if status >= 400 {
            return Err(format!("http {} body={}", status, text));
        }
        let parsed: OrResp =
            serde_json::from_str(&text).map_err(|e| format!("parse: {} body={}", e, text))?;
        let reply = parsed
            .choices
            .into_iter()
            .next()
            .and_then(|c| c.message)
            .map(|m| m.content)
            .unwrap_or_default();
        Ok(reply)
    })();
    match res {
        Ok(t) => Ok((atoms::ok(), t)),
        Err(e) => err(e),
    }
}

// ─── Ollama NIF (local model server at http://127.0.0.1:11434) ───────────────────

#[derive(Serialize)]
struct OllamaReq<'a> {
    model: &'a str,
    prompt: &'a str,
    stream: bool,
}

#[derive(Deserialize)]
struct OllamaResp {
    #[serde(default)]
    response: String,
}

#[rustler::nif(schedule = "DirtyIo")]
fn ollama_generate(
    endpoint: String,
    model: String,
    prompt: String,
    timeout_ms: u64,
) -> NifResult<(Atom, String)> {
    let url = if endpoint.is_empty() {
        "http://127.0.0.1:11434/api/generate".to_string()
    } else {
        format!("{}/api/generate", endpoint.trim_end_matches('/'))
    };
    let body = OllamaReq { model: &model, prompt: &prompt, stream: false };
    let res: Result<String, String> = (|| {
        let client = reqwest::blocking::Client::builder()
            .timeout(Duration::from_millis(timeout_ms))
            .build()
            .map_err(|e| format!("client: {}", e))?;
        let resp = client
            .post(&url)
            .json(&body)
            .send()
            .map_err(|e| format!("send: {}", e))?;
        let status = resp.status().as_u16();
        let text = resp.text().unwrap_or_default();
        if status >= 400 {
            return Err(format!("http {} body={}", status, text));
        }
        let parsed: OllamaResp =
            serde_json::from_str(&text).map_err(|e| format!("parse: {} body={}", e, text))?;
        Ok(parsed.response)
    })();
    match res {
        Ok(t) => Ok((atoms::ok(), t)),
        Err(e) => err(e),
    }
}

// ─── MCP-over-Zenoh ───────────────────────────────────────────────────────────────────────────────
//
// Protocol: a client publishes an MCP request JSON to
//   indrajaal/mcp/request/<tool>
// with a `reply_to` key containing a unique reply topic; the Pi (or any MCP
// server) publishes the response to that reply topic. This NIF performs the
// publish + subscribe + await with timeout in one call.

#[derive(Serialize)]
struct McpRequest<'a> {
    id: &'a str,
    tool: &'a str,
    args: serde_json::Value,
    reply_to: &'a str,
    source: &'a str,
}

#[rustler::nif(schedule = "DirtyIo")]
fn mcp_invoke_moz(
    tool: String,
    args_json: String,
    timeout_ms: u64,
) -> NifResult<(Atom, String)> {
    let rt = runtime();
    let request_id = Uuid::now_v7().to_string();
    let reply_topic = format!("indrajaal/mcp/reply/scripts/{}", request_id);

    let res: Result<String, String> = rt.block_on(async move {
        let session = ensure_session().await?;
        let args: serde_json::Value = serde_json::from_str(&args_json)
            .unwrap_or(serde_json::json!({}));
        let req = McpRequest {
            id: &request_id,
            tool: &tool,
            args,
            reply_to: &reply_topic,
            source: "scripts-gleam",
        };
        let body = serde_json::to_string(&req).map_err(|e| e.to_string())?;

        // Subscribe BEFORE publish to avoid missing the reply.
        let subscriber = session
            .declare_subscriber(&reply_topic)
            .await
            .map_err(|e| format!("subscribe: {}", e))?;

        let req_topic = format!("indrajaal/mcp/request/{}", tool);
        session
            .put(&req_topic, body)
            .await
            .map_err(|e| format!("publish: {}", e))?;

        // Await one reply within timeout.
        match tokio::time::timeout(
            Duration::from_millis(timeout_ms),
            subscriber.recv_async(),
        )
        .await
        {
            Ok(Ok(sample)) => {
                let payload: String = match sample.payload().try_to_string() {
                    Ok(s) => s.to_string(),
                    Err(_) => format!("<{} bytes>", sample.payload().len()),
                };
                Ok(payload)
            }
            Ok(Err(e)) => Err(format!("recv: {}", e)),
            Err(_) => Err(format!("mcp timeout after {}ms", timeout_ms)),
        }
    });
    match res {
        Ok(v) => Ok((atoms::ok(), v)),
        Err(e) => err(e),
    }
}

/// Server side of MCP-over-Zenoh: block waiting for a single inbound request
/// on `indrajaal/mcp/request/<tool_pattern>` (Zenoh wildcards allowed).
/// Returns `(ok, body)` on request, `(ok, "")` on timeout (so the gleam
/// caller never sees a NIF exception for the common "nothing arrived" case).
/// Setup errors return `(error_atom, reason)` via the standard term path.
#[rustler::nif(schedule = "DirtyIo")]
fn mcp_serve_one(
    tool_pattern: String,
    timeout_ms: u64,
) -> NifResult<(Atom, String)> {
    let rt = runtime();
    let key_expr = format!("indrajaal/mcp/request/{}", tool_pattern);
    let res: Result<Option<String>, String> = rt.block_on(async move {
        let session = ensure_session().await?;
        let subscriber = session
            .declare_subscriber(&key_expr)
            .await
            .map_err(|e| format!("subscribe: {}", e))?;
        match tokio::time::timeout(
            Duration::from_millis(timeout_ms),
            subscriber.recv_async(),
        )
        .await
        {
            Ok(Ok(sample)) => {
                let payload: String = match sample.payload().try_to_string() {
                    Ok(s) => s.to_string(),
                    Err(_) => format!("<{} bytes>", sample.payload().len()),
                };
                Ok(Some(payload))
            }
            Ok(Err(e)) => Err(format!("recv: {}", e)),
            Err(_) => Ok(None),
        }
    });
    match res {
        Ok(Some(v)) => Ok((atoms::ok(), v)),
        Ok(None) => Ok((atoms::ok(), String::new())),
        Err(e) => err(e),
    }
}

// ─── Init ────────────────────────────────────────────────────────────────────

fn load(_env: Env, _info: Term) -> bool {
    // Eagerly start the tokio runtime so the first real NIF call is fast.
    let _ = runtime();
    true
}

rustler::init!("scripts_nif", load = load);
