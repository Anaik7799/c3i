//! Knowledge NIFs — search Smriti.db knowledge tables.
//!
//! STAMP: SC-IKE-001, SC-NIF-001

use crate::db::{execute_with_backoff, open_db};
use rusqlite::params;
use rustler::NifResult;
use serde::Serialize;

#[derive(Debug, Serialize)]
struct KnowledgeResult {
    query: String,
    results: Vec<KnowledgeEntry>,
    total: usize,
}

#[derive(Debug, Serialize)]
struct KnowledgeEntry {
    id: String,
    title: String,
    content: String,
    source: String,
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn knowledge_search(query: String) -> NifResult<String> {
    if let Ok(conn) = open_db() {
        // Check if knowledge table exists
        let has_table: bool = execute_with_backoff(|| {
            conn.query_row(
                "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='knowledge'",
                [],
                |row| row.get::<_, i64>(0),
            )
        })
        .map(|c| c > 0)
        .unwrap_or(false);

        if has_table {
            let pattern = format!("%{}%", query);
            let results: Result<Vec<KnowledgeEntry>, String> = execute_with_backoff(|| {
                let mut stmt = conn.prepare(
                    "SELECT Id, Title, Content, Source FROM knowledge \
                     WHERE Title LIKE ?1 OR Content LIKE ?1 \
                     ORDER BY Title ASC LIMIT 50",
                )?;
                let rows = stmt.query_map(params![pattern], |row| {
                    Ok(KnowledgeEntry {
                        id: row.get(0)?,
                        title: row.get(1)?,
                        content: row.get(2)?,
                        source: row.get(3)?,
                    })
                })?;
                let mut entries = Vec::new();
                for r in rows {
                    entries.push(r?);
                }
                Ok(entries)
            });

            if let Ok(entries) = results {
                let total = entries.len();
                let data = KnowledgeResult {
                    query,
                    results: entries,
                    total,
                };
                return Ok(serde_json::to_string(&data).unwrap_or_else(|_| "{}".into()));
            }
        }
    }

    // Fallback: return empty results
    let data = KnowledgeResult {
        query,
        results: Vec::new(),
        total: 0,
    };
    Ok(serde_json::to_string(&data).unwrap_or_else(|_| "{}".into()))
}
