-- Z-KMS (Zettelkasten Knowledge Management System) Schema
-- SQLite database schema for storing Zettelkasten entries
--
-- Usage:
--   sqlite3 data/kms/smriti.db < scripts/smriti/schema.sql
--
-- STAMP Compliance:
-- - SC-KMS-002: Cross-runtime data access (F#/Elixir)
-- - SC-KMS-003: Entropy calculation support
-- - SC-KMS-008: Vector search integration (FTS5)

-- Main holons/Zettels table
CREATE TABLE IF NOT EXISTS holons (
    holon_uuid TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tags TEXT,
    entropy REAL DEFAULT 0.0 CHECK (entropy >= 0.0 AND entropy <= 1.0),
    level TEXT DEFAULT 'atomic' CHECK (level IN ('atomic', 'molecular', 'organism', 'ecosystem')),
    decay_rate TEXT DEFAULT 'medium' CHECK (decay_rate IN ('slow', 'medium', 'fast')),
    inserted_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    verified_at TEXT,
    content_hash TEXT,
    cluster TEXT
);

-- Edges/links table for graph relationships
CREATE TABLE IF NOT EXISTS holon_edges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    link_type TEXT DEFAULT 'wiki' CHECK (link_type IN ('wiki', 'semantic', 'code', 'backlink')),
    weight REAL DEFAULT 1.0 CHECK (weight >= 0.0 AND weight <= 1.0),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (source_id) REFERENCES holons(holon_uuid) ON DELETE CASCADE,
    FOREIGN KEY (target_id) REFERENCES holons(holon_uuid) ON DELETE CASCADE,
    UNIQUE(source_id, target_id, link_type)
);

-- Full-text search virtual table
CREATE VIRTUAL TABLE IF NOT EXISTS holons_fts USING fts5(
    title,
    content,
    tags,
    content='holons',
    content_rowid='rowid'
);

-- Triggers to keep FTS in sync with main table
CREATE TRIGGER IF NOT EXISTS holons_ai AFTER INSERT ON holons BEGIN
    INSERT INTO holons_fts(rowid, title, content, tags)
    VALUES (new.rowid, new.title, new.content, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS holons_ad AFTER DELETE ON holons BEGIN
    INSERT INTO holons_fts(holons_fts, rowid, title, content, tags)
    VALUES('delete', old.rowid, old.title, old.content, old.tags);
END;

CREATE TRIGGER IF NOT EXISTS holons_au AFTER UPDATE ON holons BEGIN
    INSERT INTO holons_fts(holons_fts, rowid, title, content, tags)
    VALUES('delete', old.rowid, old.title, old.content, old.tags);
    INSERT INTO holons_fts(rowid, title, content, tags)
    VALUES (new.rowid, new.title, new.content, new.tags);
END;

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_holons_cluster ON holons(cluster);
CREATE INDEX IF NOT EXISTS idx_holons_level ON holons(level);
CREATE INDEX IF NOT EXISTS idx_holons_entropy ON holons(entropy);
CREATE INDEX IF NOT EXISTS idx_holons_updated ON holons(updated_at);
CREATE INDEX IF NOT EXISTS idx_edges_source ON holon_edges(source_id);
CREATE INDEX IF NOT EXISTS idx_edges_target ON holon_edges(target_id);
CREATE INDEX IF NOT EXISTS idx_edges_type ON holon_edges(link_type);

-- Views for common queries
CREATE VIEW IF NOT EXISTS v_rotting_zettels AS
SELECT holon_uuid, title, entropy, level, cluster, updated_at
FROM holons
WHERE entropy > 0.7
ORDER BY entropy DESC;

CREATE VIEW IF NOT EXISTS v_fresh_zettels AS
SELECT holon_uuid, title, entropy, level, cluster, updated_at
FROM holons
WHERE entropy < 0.3
ORDER BY updated_at DESC;

CREATE VIEW IF NOT EXISTS v_cluster_stats AS
SELECT
    cluster,
    COUNT(*) as count,
    AVG(entropy) as avg_entropy,
    SUM(CASE WHEN entropy < 0.3 THEN 1 ELSE 0 END) as fresh_count,
    SUM(CASE WHEN entropy >= 0.3 AND entropy < 0.7 THEN 1 ELSE 0 END) as aging_count,
    SUM(CASE WHEN entropy >= 0.7 THEN 1 ELSE 0 END) as rotting_count
FROM holons
GROUP BY cluster
ORDER BY count DESC;

CREATE VIEW IF NOT EXISTS v_graph_edges AS
SELECT
    e.source_id,
    s.title as source_title,
    e.target_id,
    t.title as target_title,
    e.link_type,
    e.weight
FROM holon_edges e
JOIN holons s ON e.source_id = s.holon_uuid
JOIN holons t ON e.target_id = t.holon_uuid;
