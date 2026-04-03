# Comprehensive Docs to Zettel Converter Guide

## Overview

This guide describes the complete setup and operation of the AI-powered documentation-to-Zettelkasten converter for the Z-KMS (Zettelkasten Knowledge Management System).

The converter uses Claude via OpenRouter to intelligently analyze markdown documentation and extract structured Zettelkasten entries with:
- Clear, meaningful titles
- AI-generated summaries
- Relevant tags
- Level classification (atomic/molecular/organism/ecosystem)
- Entropy calculation based on document age

---

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Docs Folder   │────▶│  Conversion      │────▶│   Z-KMS API     │
│   (Markdown)    │     │  Script          │     │   (Giraffe F#)  │
└─────────────────┘     └────────┬─────────┘     └────────┬────────┘
                                 │                        │
                        ┌────────▼─────────┐     ┌────────▼────────┐
                        │   OpenRouter     │     │    SQLite DB    │
                        │   Claude API     │     │    (smriti.db)    │
                        └──────────────────┘     └─────────────────┘
```

---

## Prerequisites

### 1. Required Software

```bash
# Elixir (via devenv)
devenv shell
elixir --version  # >= 1.19.0

# OpenRouter API Key
export OPENROUTER_API_KEY="sk-or-v1-xxx..."
```

### 2. Database Setup

The Z-KMS database must exist with the correct schema.

**Location**: `/home/an/dev/ver/intelitor-v5.2/data/kms/smriti.db`

**Schema**:
```sql
-- Main holons table
CREATE TABLE IF NOT EXISTS holons (
    holon_uuid TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tags TEXT,
    entropy REAL DEFAULT 0.0,
    level TEXT DEFAULT 'atomic',
    decay_rate TEXT DEFAULT 'medium',
    inserted_at TEXT,
    updated_at TEXT,
    verified_at TEXT,
    content_hash TEXT,
    cluster TEXT
);

-- Edges/links table
CREATE TABLE IF NOT EXISTS holon_edges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    link_type TEXT DEFAULT 'wiki',
    weight REAL DEFAULT 1.0,
    created_at TEXT,
    FOREIGN KEY (source_id) REFERENCES holons(holon_uuid),
    FOREIGN KEY (target_id) REFERENCES holons(holon_uuid)
);

-- Full-text search
CREATE VIRTUAL TABLE IF NOT EXISTS holons_fts USING fts5(
    title,
    content,
    tags,
    content='holons',
    content_rowid='rowid'
);

-- FTS triggers
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_holons_cluster ON holons(cluster);
CREATE INDEX IF NOT EXISTS idx_holons_level ON holons(level);
CREATE INDEX IF NOT EXISTS idx_holons_entropy ON holons(entropy);
CREATE INDEX IF NOT EXISTS idx_edges_source ON holon_edges(source_id);
CREATE INDEX IF NOT EXISTS idx_edges_target ON holon_edges(target_id);
```

### 3. Z-KMS Containers

Ensure the Z-KMS containers are running:

```bash
# Start Z-KMS containers
cd lib/cepaf/artifacts
podman-compose -f podman-compose-smriti.yml up -d

# Verify running
podman ps | grep smriti

# Access points
# API: http://localhost:5001/api
# Client: http://localhost:3001
```

---

## Conversion Script

### Location

`scripts/smriti/ai_docs_to_zettels.exs`

### Key Features

1. **AI-Powered Extraction**: Uses Claude to analyze documents and extract structured metadata
2. **Batch Processing**: Handles multiple documents with configurable limits
3. **Truncation**: Large files (>15KB) are truncated to fit API context limits
4. **Entropy Calculation**: Automatic entropy based on file modification age
5. **Cluster Assignment**: Based on folder structure
6. **Deterministic UUIDs**: Same file always generates same UUID

### Configuration

```elixir
# Docs root directory
@docs_root "/home/an/dev/ver/intelitor-v5.2/docs"

# Database path
@db_path "/home/an/dev/ver/intelitor-v5.2/data/kms/smriti.db"

# OpenRouter endpoint
@openrouter_url "https://openrouter.ai/api/v1/chat/completions"

# Claude model
@model "anthropic/claude-3.5-sonnet"

# Cluster mapping from folders
@cluster_map %{
  "architecture" => "Architecture",
  "domain-docs" => "Domains",
  "guides" => "Guides",
  "kms" => "KMS",
  "formal_specs" => "Formal",
  "safety" => "Safety",
  "compliance" => "Compliance",
  "cockpit" => "Cockpit",
  "prajna" => "Prajna",
  "testing" => "Testing",
  "verification" => "Verification"
}
```

---

## Usage

### Test Mode (2 files)

```bash
# Test with 2 files first to verify everything works
OPENROUTER_API_KEY="sk-or-v1-xxx" elixir scripts/smriti/ai_docs_to_zettels.exs --test
```

### Full Batch Mode (up to 50 files)

```bash
# Process up to 50 documents
OPENROUTER_API_KEY="sk-or-v1-xxx" elixir scripts/smriti/ai_docs_to_zettels.exs
```

### Expected Output

```
=== AI-Powered Docs to Zettels Converter ===

Mode: TEST (2 files)
API Key: sk-or-v1-8...382b

Connected to database: /home/an/dev/ver/intelitor-v5.2/data/kms/smriti.db

Found 2 documents to convert

--- Processing: example-doc.md ---
  File size: 5199 bytes
  Calling Claude via OpenRouter...
  AI extraction successful
  Inserted: Example Document Title

=== Conversion Complete ===
Successful: 2
Failed: 0
```

---

## Claude Prompt Template

The script sends the following prompt to Claude for each document:

```
You are converting a documentation file into a Zettelkasten entry.
Analyze the following markdown document and extract structured information.

FILE PATH: {relative_path}
CLUSTER: {cluster}

DOCUMENT CONTENT:
---
{content}
---

Please respond with ONLY a valid JSON object (no markdown code blocks, no explanation):
{
  "title": "A clear, concise title (max 100 chars)",
  "summary": "A 2-3 sentence summary of the key concepts",
  "tags": ["tag1", "tag2", "tag3"],
  "key_concepts": ["concept1", "concept2"],
  "related_topics": ["topic1", "topic2"],
  "level": "atomic|molecular|organism|ecosystem",
  "importance": "high|medium|low"
}

Rules:
- title: Extract or create a meaningful title
- summary: Capture the essence of the document
- tags: 3-8 relevant tags (lowercase, no spaces)
- key_concepts: Main ideas or entities discussed
- related_topics: What this connects to conceptually
- level: atomic (<1KB), molecular (1-5KB), organism (5-20KB), ecosystem (>20KB)
- importance: Based on how foundational/critical this document is
```

---

## Zettel Data Model

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `holon_uuid` | TEXT | Deterministic UUID based on file path |
| `title` | TEXT | AI-extracted or file-derived title |
| `content` | TEXT | AI-generated summary |
| `tags` | TEXT | Comma-separated tags |
| `entropy` | REAL | 0.0 (fresh) to 1.0 (rotting) |
| `level` | TEXT | atomic/molecular/organism/ecosystem |
| `decay_rate` | TEXT | slow/medium/fast |
| `cluster` | TEXT | Category based on folder |
| `content_hash` | TEXT | SHA-256 hash (first 16 chars) |
| `inserted_at` | TEXT | ISO 8601 timestamp |
| `updated_at` | TEXT | ISO 8601 timestamp |

### Entropy Calculation

Entropy increases with document age:

| Age | Entropy Range | Label |
|-----|---------------|-------|
| < 7 days | 0.1 - 0.2 | Fresh |
| 7-30 days | 0.2 - 0.5 | Aging |
| 30-90 days | 0.5 - 0.8 | Stale |
| > 90 days | 0.8 - 1.0 | Rotting |

### Level Classification

Based on content size:

| Size | Level |
|------|-------|
| < 1KB | atomic |
| 1-5KB | molecular |
| 5-20KB | organism |
| > 20KB | ecosystem |

---

## API Endpoints

After conversion, verify data via the Z-KMS API:

### List Zettels
```bash
curl http://localhost:5001/api/zettels | jq '.items | length'
```

### Get Graph Data
```bash
curl http://localhost:5001/api/graph | jq '.nodes | length'
```

### Get Entropy Metrics
```bash
curl http://localhost:5001/api/metrics/entropy | jq '.'
```

### Search
```bash
curl "http://localhost:5001/api/search?q=architecture" | jq '.'
```

---

## Troubleshooting

### Error: API Key Not Set

```
ERROR: OPENROUTER_API_KEY environment variable not set
```

**Solution**: Set the environment variable:
```bash
export OPENROUTER_API_KEY="sk-or-v1-xxx"
```

### Error: Database Not Found

```
ERROR: unable to open database file
```

**Solution**: Create the database with schema:
```bash
sqlite3 data/kms/smriti.db < scripts/smriti/schema.sql
```

### Error: JSON Parse Failed

```
ERROR: Failed to parse Claude response as JSON
```

**Cause**: Claude sometimes returns malformed responses. The script logs the first 200 chars of the response for debugging.

**Solution**:
- Retry the specific file
- Check if the document content is causing issues (binary, non-UTF8, etc.)

### Error: Container Not Reachable

```
curl: (7) Failed to connect to localhost port 5001
```

**Solution**:
```bash
cd lib/cepaf/artifacts
podman-compose -f podman-compose-smriti.yml up -d
podman ps | grep smriti
```

---

## Extending the Converter

### Adding New Clusters

Edit the `@cluster_map` in the script:

```elixir
@cluster_map %{
  # Add new mappings
  "new_folder" => "NewCluster",
  ...
}
```

### Changing Priority Folders

Edit the `collect_docs/1` function:

```elixir
defp collect_docs(limit) do
  priority_folders = [
    "architecture",
    "new_folder",  # Add new folders here
    ...
  ]
end
```

### Custom Prompts

Modify the `call_claude/3` function prompt to change extraction behavior.

---

## Integration with Z-KMS Client

The Z-KMS Elmish client at `http://localhost:3001` automatically displays:
- Graph visualization of all Zettels
- Search functionality
- Entropy indicators (color-coded freshness)
- Tag filtering

---

## STAMP Constraints

| ID | Constraint | Status |
|----|------------|--------|
| SC-KMS-001 | Read-only access to holons.db | N/A (separate db) |
| SC-KMS-002 | Cross-runtime (F#/Elixir) data access | COMPLIANT |
| SC-KMS-003 | Entropy calculation matches Gardener.fs | COMPLIANT |
| SC-KMS-004 | MCP endpoints for agent access | PLANNED |
| SC-KMS-005 | Cytoscape.js graph visualization | COMPLIANT |
| SC-KMS-006 | Container isolation (separate services) | COMPLIANT |

---

## Related Files

| File | Purpose |
|------|---------|
| `scripts/smriti/ai_docs_to_zettels.exs` | Main conversion script |
| `data/kms/smriti.db` | Z-KMS SQLite database |
| `lib/cepaf/artifacts/podman-compose-smriti.yml` | Container configuration |
| `lib/cepaf/src/Cepaf.Smriti.Api/` | Giraffe F# API server |
| `lib/cepaf/src/Cepaf.Smriti.Client/` | Elmish SPA client |
