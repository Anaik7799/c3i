// STAMP: SC-SMRITI-001, SC-GLM-CORE-002
// AOR: AOR-SMRITI-001, AOR-GLM-005
// Criticality: Level 2 (HIGH) - Smriti Knowledge Catalog
//
// Catalog management for the Smriti knowledge base with full-text
// search, tag filtering, and CRUD operations over SQLite FTS.

import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// =============================================================================
// Types
// =============================================================================

pub type CatalogEntry {
  CatalogEntry(
    id: String,
    name: String,
    category: String,
    description: String,
    tags: List(String),
    created_at: String,
  )
}

pub type CatalogQuery {
  CatalogQuery(
    category: Option(String),
    tags: List(String),
    search_text: Option(String),
    limit: Int,
  )
}

pub type CatalogResult {
  CatalogResult(
    entries: List(CatalogEntry),
    total_count: Int,
    query_time_ms: Int,
  )
}

// =============================================================================
// FFI Stubs
// =============================================================================

pub fn search(query: CatalogQuery) -> Result(CatalogResult, String) {
  let _ = query
  panic as "NYI: requires SQLite FTS (SC-SMRITI-001)"
}

pub fn ingest(path: String) -> Result(Int, String) {
  let _ = path
  panic as "NYI: requires file I/O (SC-SMRITI-001)"
}

pub fn index_entry(entry: CatalogEntry) -> Result(Nil, String) {
  let _ = entry
  panic as "NYI: requires SQLite (SC-SMRITI-001)"
}

pub fn delete_entry(id: String) -> Result(Nil, String) {
  let _ = id
  panic as "NYI: requires SQLite (SC-SMRITI-001)"
}

// =============================================================================
// Pure Helper Functions
// =============================================================================

pub fn new_entry(
  id: String,
  name: String,
  category: String,
  description: String,
) -> CatalogEntry {
  CatalogEntry(
    id: id,
    name: name,
    category: category,
    description: description,
    tags: [],
    created_at: "",
  )
}

pub fn matches_query(entry: CatalogEntry, query: CatalogQuery) -> Bool {
  let category_match = case query.category {
    None -> True
    Some(cat) -> entry.category == cat
  }

  let tags_match = case query.tags {
    [] -> True
    required_tags ->
      list.all(required_tags, fn(tag) { list.contains(entry.tags, tag) })
  }

  let text_match = case query.search_text {
    None -> True
    Some(text) -> {
      let lower_text = string.lowercase(text)
      string.contains(string.lowercase(entry.name), lower_text)
      || string.contains(string.lowercase(entry.description), lower_text)
    }
  }

  category_match && tags_match && text_match
}

pub fn entry_to_json(e: CatalogEntry) -> json.Json {
  json.object([
    #("id", json.string(e.id)),
    #("name", json.string(e.name)),
    #("category", json.string(e.category)),
    #("description", json.string(e.description)),
    #("tags", json.array(e.tags, json.string)),
    #("created_at", json.string(e.created_at)),
  ])
}

pub fn query_to_json(q: CatalogQuery) -> json.Json {
  json.object([
    #("category", case q.category {
      None -> json.null()
      Some(c) -> json.string(c)
    }),
    #("tags", json.array(q.tags, json.string)),
    #("search_text", case q.search_text {
      None -> json.null()
      Some(t) -> json.string(t)
    }),
    #("limit", json.int(q.limit)),
  ])
}

pub fn result_to_json(r: CatalogResult) -> json.Json {
  json.object([
    #("entries", json.array(r.entries, entry_to_json)),
    #("total_count", json.int(r.total_count)),
    #("query_time_ms", json.int(r.query_time_ms)),
  ])
}
