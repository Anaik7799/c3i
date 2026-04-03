# SMRITI Developer Guide

**Zettelkasten Knowledge Management System**
**Version**: 21.3.0-SIL6
**Last Updated**: 2026-01-11
**Framework**: SIL-6 Biomorphic Fractal Mesh
**Compliance**: IEC 61508 SIL-6, ISO 27001
**STAMP Compliance**: SC-SMRITI-001 to SC-SMRITI-010, SC-AI-001

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Module Reference](#2-module-reference)
3. [Data Model](#3-data-model)
4. [API Reference](#4-api-reference)
5. [AI Integration](#5-ai-integration)
6. [SIL-6 Biomorphic Mesh Integration](#6-sil-4-mesh-integration)
7. [Emacs Integration](#7-emacs-integration)
8. [STAMP Constraints](#8-stamp-constraints)
9. [Extension Guide](#9-extension-guide)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Architecture Overview

### 1.1 System Design

SMRITI implements a fractal knowledge management system based on Zettelkasten principles, integrated into the Indrajaal biomorphic mesh architecture.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SMRITI Architecture                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐         │
│  │   Emacs      │    │  SIL6Mesh    │    │   Web UI     │         │
│  │  smriti-mode   │    │    CLI       │    │  (Fable)     │         │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘         │
│         │                   │                   │                  │
│         └───────────────────┼───────────────────┘                  │
│                             │                                      │
│                    ┌────────▼────────┐                             │
│                    │    SmritiCortex   │ ◀── Orchestration Layer     │
│                    └────────┬────────┘                             │
│                             │                                      │
│      ┌──────────────────────┼──────────────────────┐               │
│      │                      │                      │               │
│ ┌────▼────┐          ┌──────▼──────┐        ┌─────▼─────┐         │
│ │ Docs    │          │   SMRITI      │        │ OpenRouter │         │
│ │Ingestor │          │ Lifecycle   │        │  Client    │         │
│ └────┬────┘          └──────┬──────┘        └─────┬─────┘         │
│      │                      │                     │                │
│      └──────────────────────┼─────────────────────┘                │
│                             │                                      │
│                    ┌────────▼────────┐                             │
│                    │  SQLite + FTS5  │ ◀── Persistent Storage      │
│                    │    (Dapper)     │                             │
│                    └─────────────────┘                             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Responsibilities

| Component | File | Purpose |
|-----------|------|---------|
| **Shared Types** | `Cepaf.Smriti.Shared/Types.fs` | Core domain types (Zettel, Links, Graph) |
| **Lifecycle** | `Cepaf.Smriti.Api/Data/SmritiLifecycle.fs` | CRUD operations, search, entropy |
| **Ingestor** | `Cepaf.Smriti.Api/Data/DocsIngestor.fs` | Document ingestion pipeline |
| **AI Client** | `Cepaf.Smriti.Api/AI/OpenRouterClient.fs` | Claude/OpenRouter integration |
| **Cortex** | `Cepaf.Smriti.Api/Cortex/SmritiCortex.fs` | Unified API facade |
| **Mesh CLI** | `Cepaf/Mesh/SIL6MeshCLI.fs` | SIL-6 Biomorphic mesh command integration |
| **Emacs Mode** | `lib/cepaf/emacs/smriti-mode.el` | Emacs integration package |

### 1.3 Technology Stack

- **Language**: F# 10.0 (.NET 10.0)
- **Database**: SQLite 3.x with FTS5 (Full-Text Search)
- **ORM**: Dapper (micro-ORM)
- **AI**: OpenRouter API (Claude 3 Haiku)
- **Hashing**: SHA-256 for content deduplication
- **Mesh**: Zenoh pub/sub for telemetry

---

## 2. Module Reference

### 2.1 Cepaf.Smriti.Shared.Types

Core domain types shared across all SMRITI components.

#### Enumerations

```fsharp
/// Link type between Zettels
type LinkType =
    | WikiLink = 0       // Explicit [[target]] link
    | SemanticSimilar = 1 // Vector similarity match
    | CodeReference = 2   // Code import reference
    | Backlink = 3       // Automatic reverse link

/// Holon level in fractal hierarchy
type HolonLevel =
    | Atomic = 0      // L1: Single note
    | Molecular = 1   // L2: Related cluster
    | Organism = 2    // L3: Topic/domain
    | Ecosystem = 3   // L4: System-wide

/// Decay rate classification
type DecayRate =
    | Fast = 0    // API docs (days)
    | Medium = 1  // Design docs (weeks)
    | Slow = 2    // Architecture (months)
```

#### Core Types

```fsharp
/// Atomic unit of knowledge
type Zettel = {
    Id: Guid
    Title: string
    Content: string
    Tags: string list
    Backlinks: Guid list
    Entropy: float          // 0.0 = fresh, 1.0 = rotting
    Level: HolonLevel
    DecayRate: DecayRate
    CreatedAt: DateTime
    ModifiedAt: DateTime
    VerifiedAt: DateTime option
    ContentHash: string
}

/// Graph edge
type ZettelLink = {
    Source: Guid
    Target: Guid
    LinkType: LinkType
    Weight: float
    CreatedAt: DateTime
}
```

#### Utility Modules

```fsharp
module Zettel =
    val create : title:string -> content:string -> tags:string list -> Zettel
    val isFresh : Zettel -> bool   // entropy < 0.3
    val isRotting : Zettel -> bool // entropy >= 0.6

module Entropy =
    val toColor : float -> string      // Tailwind CSS color
    val toLabel : float -> string      // "Fresh"/"Aging"/"Rotting"
    val calculate : DateTime -> DateTime option -> DecayRate -> float
```

### 2.2 SmritiLifecycle

Complete CRUD operations and lifecycle management.

#### Configuration

```fsharp
type SmritiConfig = {
    DbPath: string        // SQLite database path
    DefaultCluster: string
}

val defaultConfig : unit -> SmritiConfig
```

#### Operations

```fsharp
/// Create a new Zettel
val create :
    config:SmritiConfig ->
    title:string ->
    content:string ->
    tags:string list ->
    level:HolonLevel ->
    cluster:string option ->
    SmritiResult<Guid>

/// Get Zettel by ID
val get : config:SmritiConfig -> id:Guid -> SmritiResult<Zettel>

/// Update Zettel
val update : config:SmritiConfig -> id:Guid -> req:UpdateRequest -> SmritiResult<unit>

/// Delete Zettel
val delete : config:SmritiConfig -> id:Guid -> cascade:bool -> SmritiResult<unit>

/// List with pagination
val list :
    config:SmritiConfig ->
    page:int ->
    pageSize:int ->
    cluster:string option ->
    level:HolonLevel option ->
    SmritiResult<Zettel list * int>

/// Full-text search
val search : config:SmritiConfig -> query:string -> limit:int -> SmritiResult<Zettel list>

/// Create link between Zettels
val createLink : config:SmritiConfig -> req:LinkRequest -> SmritiResult<unit>

/// Find orphan Zettels (no links)
val findOrphans : config:SmritiConfig -> SmritiResult<Zettel list>

/// Find stale Zettels (high entropy)
val findStale : config:SmritiConfig -> threshold:float -> SmritiResult<Zettel list>

/// Get cluster statistics
val getClusterStats : config:SmritiConfig -> SmritiResult<Map<string, int * float>>

/// Recalculate entropy for all Zettels
val recalculateEntropy : config:SmritiConfig -> SmritiResult<int>
```

### 2.3 DocsIngestor

Document ingestion with AI-powered metadata extraction.

#### Configuration

```fsharp
type IngestorConfig = {
    SmritiConfig: SmritiConfig
    DefaultCluster: string
    DefaultLevel: HolonLevel
    UseAI: bool
}

val defaultConfig : unit -> IngestorConfig
```

#### Operations

```fsharp
/// Ingest a single file
val ingestFile : config:IngestorConfig -> filePath:string -> Async<IngestResult>

/// Ingest multiple files
val ingestFiles : config:IngestorConfig -> filePaths:string list -> Async<IngestResult list>

/// Print ingestion summary
val printSummary : results:IngestResult list -> unit
```

#### Result Types

```fsharp
type IngestResult =
    | Success of id:Guid * title:string * aiUsed:bool
    | Skipped of path:string * reason:string
    | Error of path:string * message:string
```

### 2.4 OpenRouterClient

AI-powered metadata extraction using Claude.

#### Configuration

```fsharp
type OpenRouterConfig = {
    ApiKey: string          // From OPENROUTER_API_KEY env var
    BaseUrl: string         // https://openrouter.ai/api/v1
    Model: string           // anthropic/claude-3-haiku
    MaxTokens: int          // 1024
    Temperature: float      // 0.3
    TimeoutSeconds: int     // 30
}
```

#### Operations

```fsharp
/// Check if API is available
val isAvailable : config:OpenRouterConfig -> bool

/// Extract metadata using AI
val extractWithAI :
    config:OpenRouterConfig ->
    content:string ->
    filePath:string ->
    Async<Result<ExtractedZettel * bool, string>>

/// Fallback extraction using regex
val extractFallback : content:string -> filePath:string -> ExtractedZettel
```

### 2.5 SmritiCortex

Unified orchestration layer for all SMRITI operations.

#### Configuration

```fsharp
type CortexConfig = {
    SmritiConfig: SmritiLifecycle.SmritiConfig
    IngestorConfig: DocsIngestor.IngestorConfig
    EnableAI: bool
    EnableTelemetry: bool
    DocsBasePath: string
}
```

#### Operations

```fsharp
/// Get system status
val getStatus : config:CortexConfig -> CortexResult<CortexStatus>

/// Print dashboard
val printDashboard : status:CortexStatus -> unit

/// Ingest directory
val ingestDirectory :
    config:CortexConfig ->
    path:string ->
    maxFiles:int ->
    cluster:string ->
    Async<CortexResult<BatchResult>>

/// Execute SMRITI command
val executeCommand : config:CortexConfig -> cmd:SmritiCommand -> Async<unit>
```

#### Command Types

```fsharp
type SmritiCommand =
    | Status
    | Ingest of path:string * maxFiles:int * cluster:string
    | Search of query:string * limit:int
    | Get of id:Guid
    | Create of title:string * content:string * cluster:string
    | Link of source:Guid * target:Guid * linkType:string
    | Delete of id:Guid
    | Orphans
    | Stale of threshold:float
    | Entropy
```

---

## 3. Data Model

### 3.1 Database Schema

SMRITI uses SQLite with the following schema:

```sql
-- Core Zettel table
CREATE TABLE IF NOT EXISTS zettels (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tags TEXT NOT NULL,           -- JSON array
    entropy REAL DEFAULT 0.0,
    level TEXT NOT NULL,
    decay_rate TEXT NOT NULL,
    cluster TEXT,
    content_hash TEXT NOT NULL,
    created_at TEXT NOT NULL,
    modified_at TEXT NOT NULL,
    verified_at TEXT
);

-- Full-text search virtual table
CREATE VIRTUAL TABLE IF NOT EXISTS zettels_fts USING fts5(
    title, content, tags,
    content='zettels',
    content_rowid='rowid'
);

-- Trigger to keep FTS in sync
CREATE TRIGGER zettels_ai AFTER INSERT ON zettels BEGIN
    INSERT INTO zettels_fts(rowid, title, content, tags)
    VALUES (new.rowid, new.title, new.content, new.tags);
END;

-- Links between Zettels
CREATE TABLE IF NOT EXISTS zettel_links (
    source_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    link_type TEXT NOT NULL,
    weight REAL DEFAULT 1.0,
    created_at TEXT NOT NULL,
    PRIMARY KEY (source_id, target_id, link_type),
    FOREIGN KEY (source_id) REFERENCES zettels(id) ON DELETE CASCADE,
    FOREIGN KEY (target_id) REFERENCES zettels(id) ON DELETE CASCADE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_zettels_cluster ON zettels(cluster);
CREATE INDEX IF NOT EXISTS idx_zettels_entropy ON zettels(entropy DESC);
CREATE INDEX IF NOT EXISTS idx_zettels_hash ON zettels(content_hash);
CREATE INDEX IF NOT EXISTS idx_links_target ON zettel_links(target_id);
```

### 3.2 Entropy Model

Entropy represents knowledge staleness on a scale of 0.0 (fresh) to 1.0 (rotting):

```
Entropy = age_days × decay_multiplier × verification_bonus

Where:
  decay_multiplier:
    Fast   = 0.05 (API docs)
    Medium = 0.01 (design docs)
    Slow   = 0.001 (architecture)

  verification_bonus:
    Verified < 30 days = 0.5
    Verified older     = 0.8
    Never verified     = 1.0
```

### 3.3 Content Hashing

SHA-256 is used for content deduplication:

```fsharp
let computeHash (content: string) : string =
    use sha256 = System.Security.Cryptography.SHA256.Create()
    let bytes = System.Text.Encoding.UTF8.GetBytes(content)
    let hash = sha256.ComputeHash(bytes)
    BitConverter.ToString(hash).Replace("-", "").ToLower()
```

---

## 4. API Reference

### 4.1 REST API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/smriti/status` | System status |
| GET | `/api/smriti/zettels` | List Zettels (paginated) |
| GET | `/api/smriti/zettels/{id}` | Get Zettel by ID |
| POST | `/api/smriti/zettels` | Create Zettel |
| PUT | `/api/smriti/zettels/{id}` | Update Zettel |
| DELETE | `/api/smriti/zettels/{id}` | Delete Zettel |
| GET | `/api/smriti/search?q={query}` | Full-text search |
| POST | `/api/smriti/links` | Create link |
| GET | `/api/smriti/graph` | Get graph data |
| GET | `/api/smriti/orphans` | Find orphans |
| GET | `/api/smriti/stale?threshold={0.6}` | Find stale Zettels |
| POST | `/api/smriti/ingest` | Ingest directory |
| POST | `/api/smriti/entropy/recalculate` | Recalculate entropy |

### 4.2 CLI Interface

The `SmritiIngestorCLI.fsx` script provides command-line access:

```bash
# Show status
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx status

# Ingest documents
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx ingest docs/architecture --max 10 --cluster docs

# Search
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx search "holon architecture" --limit 5

# Find orphans
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx orphans

# Find stale
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx stale --threshold 0.6

# Recalculate entropy
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx entropy
```

---

## 5. AI Integration

### 5.1 OpenRouter Setup

1. Get an API key from [OpenRouter](https://openrouter.ai)
2. Set environment variable:

```bash
export OPENROUTER_API_KEY="sk-or-v1-..."
```

### 5.2 Model Selection

SMRITI uses Claude 3 Haiku by default (per SC-OPENROUTER-001):

```fsharp
let config = {
    defaultConfig() with
        Model = "anthropic/claude-3-haiku"  // Fast, cost-effective
}
```

Available models:
- `anthropic/claude-3-haiku` (default, free tier)
- `anthropic/claude-3-sonnet`
- `anthropic/claude-3-opus`

### 5.3 Extraction Prompt

The AI extracts metadata using this prompt:

```
You are a knowledge management expert. Analyze this document and extract:
1. A clear title (max 80 chars)
2. A 2-sentence summary
3. Up to 5 relevant tags
4. The holon level (atomic/molecular/organism)
5. Key concepts (3-5)
6. Related topics (2-3)

Respond with ONLY valid JSON:
{"title": "...", "summary": "...", "tags": [...], "level": "...",
 "key_concepts": [...], "related_topics": [...]}
```

### 5.4 Fallback Behavior

When AI is unavailable (per SC-OPENROUTER-003):

1. Title extracted from first `# Heading` or filename
2. Level inferred from content length:
   - `< 3KB` → Atomic
   - `3-10KB` → Molecular
   - `> 10KB` → Organism
3. Tags and summary remain empty

---

## 6. SIL-6 Biomorphic Mesh Integration

### 6.1 Mesh CLI Commands

SMRITI is integrated into the SIL-6 Biomorphic mesh via `SIL6MeshCLI.fs`:

```bash
# Via mesh CLI
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- smriti status
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- smriti ingest docs 10 docs
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- smriti search "holon" 5
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- smriti orphans
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- smriti stale 0.6
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- smriti entropy
```

### 6.2 5-Order Effects

All SMRITI operations log 5-order effects per SC-COG-002:

| Order | Description |
|-------|-------------|
| 1st | Direct database operation (insert/update/delete) |
| 2nd | Index updates, FTS sync |
| 3rd | Link recalculation, backlink updates |
| 4th | Entropy recalculation, cluster stats |
| 5th | Graph regeneration, dashboard update |

### 6.3 Telemetry

SMRITI publishes to Zenoh topics:

- `indrajaal/smriti/status` - System status
- `indrajaal/smriti/ingest` - Ingestion events
- `indrajaal/smriti/search` - Search queries
- `indrajaal/smriti/entropy` - Entropy updates

---

## 7. Emacs Integration

### 7.1 Installation

1. Add to your Emacs config:

```elisp
(add-to-list 'load-path "/path/to/intelitor-v5.2/lib/cepaf/emacs")
(require 'smriti-mode)
(smriti-setup-keybindings)
```

2. Set project root (optional):

```elisp
(setq smriti-project-root "/path/to/intelitor-v5.2")
```

### 7.2 Key Bindings

| Key | Command | Description |
|-----|---------|-------------|
| `C-c z d` | `smriti-dashboard` | Open dashboard |
| `C-c z s` | `smriti-search` | Search Zettels |
| `C-c z i` | `smriti-ingest` | Ingest directory |
| `C-c z o` | `smriti-orphans` | Show orphans |
| `C-c z t` | `smriti-stale` | Show stale Zettels |
| `C-c z e` | `smriti-entropy` | Recalculate entropy |
| `C-c z z` | `smriti-menu` | Transient menu (if available) |

### 7.3 Dashboard Mode

The dashboard provides an interactive view:

```
╔════════════════════════════════════════════════════════════╗
║          SMRITI - Zettelkasten Knowledge Management          ║
╠════════════════════════════════════════════════════════════╣
║  Keys: g=refresh s=search i=ingest o=orphans t=stale q=quit║
╚════════════════════════════════════════════════════════════╝

======================================================================
              SMRITI CORTEX DASHBOARD
======================================================================
  Total Holons:    48
  Orphans:         3          (no links)
  Stale:           5          (entropy > 0.6)
  AI Available:    true
----------------------------------------------------------------------
  CLUSTERS
----------------------------------------------------------------------
  docs            38 holons [####################] entropy: 0.25
  architecture    10 holons [##########          ] entropy: 0.15
======================================================================
```

### 7.4 Org-Mode Integration

SMRITI links work in Org-mode:

```org
* Project Notes
See [[smriti:abc12345-...][Holon Architecture]] for details.
```

---

## 8. STAMP Constraints

### 8.1 Core Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SMRITI-001 | SQLite is authoritative holon state | CRITICAL |
| SC-SMRITI-002 | All operations via SMRITI CLI/API | CRITICAL |
| SC-SMRITI-003 | AI extraction is optional (OpenRouter) | MEDIUM |
| SC-SMRITI-004 | Content hash for deduplication | HIGH |
| SC-SMRITI-005 | Entropy range 0.0-1.0 | HIGH |
| SC-SMRITI-006 | FTS5 for full-text search | HIGH |
| SC-SMRITI-007 | Backlinks automatically maintained | HIGH |
| SC-SMRITI-008 | Cascade delete for links | MEDIUM |
| SC-SMRITI-009 | 5-order effects logging | HIGH |
| SC-SMRITI-010 | Telemetry to Zenoh | MEDIUM |

### 8.2 OpenRouter Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-OPENROUTER-001 | Free models MUST be prioritized | HIGH |
| SC-OPENROUTER-002 | Rate limiting with exponential backoff | HIGH |
| SC-OPENROUTER-003 | Fallback to mock on API unavailable | CRITICAL |

### 8.3 Holon Constraints

| ID | Constraint |
|----|------------|
| SC-HOLON-001 | ALL holon core state MUST use SQLite/DuckDB |
| SC-HOLON-006 | Holon state files in `data/holons/` |
| SC-HOLON-009 | Portability via single file copy |
| SC-HOLON-011 | SQLite/DuckDB is AUTHORITATIVE |

---

## 9. Extension Guide

### 9.1 Adding New Link Types

1. Update `Types.fs`:

```fsharp
type LinkType =
    | WikiLink = 0
    | SemanticSimilar = 1
    | CodeReference = 2
    | Backlink = 3
    | Citation = 4        // New type
```

2. Update database schema:

```sql
-- No schema change needed (link_type is TEXT)
```

3. Update CLI handling in `SmritiCortex.fs`:

```fsharp
| "citation" -> LinkType.Citation
```

### 9.2 Adding Custom Extractors

1. Create extractor module:

```fsharp
module CustomExtractor

let extract (content: string) : ExtractedZettel option =
    // Custom extraction logic
    None
```

2. Register in `DocsIngestor.fs`:

```fsharp
let extractors = [
    CustomExtractor.extract
    OpenRouterClient.extractWithAI config
    OpenRouterClient.extractFallback
]
```

### 9.3 Custom Decay Rates

1. Add to `Types.fs`:

```fsharp
type DecayRate =
    | Fast = 0
    | Medium = 1
    | Slow = 2
    | Glacial = 3    // New: Permanent docs
```

2. Update entropy calculation:

```fsharp
| DecayRate.Glacial -> 0.0001  // Decades
```

---

## 10. Troubleshooting

### 10.1 Common Issues

**Database locked error**
```
SQLite Error: database is locked
```
Solution: Ensure only one process accesses the database. Use WAL mode:
```sql
PRAGMA journal_mode=WAL;
```

**AI extraction timeout**
```
OpenRouter request timed out
```
Solution: Increase timeout or use fallback:
```fsharp
{ config with TimeoutSeconds = 60 }
```

**FTS not returning results**
Solution: Rebuild FTS index:
```sql
INSERT INTO zettels_fts(zettels_fts) VALUES('rebuild');
```

### 10.2 Debug Logging

Enable verbose logging:

```fsharp
let config = {
    defaultConfig() with
        EnableTelemetry = true
}
```

### 10.3 Database Recovery

If database is corrupted:

```bash
# Backup
cp data/holons/smriti.db data/holons/smriti.db.bak

# Check integrity
sqlite3 data/holons/smriti.db "PRAGMA integrity_check;"

# Recover
sqlite3 data/holons/smriti.db ".recover" | sqlite3 data/holons/smriti_recovered.db
```

### 10.4 Performance Tuning

For large databases (>10,000 Zettels):

```sql
-- Increase cache
PRAGMA cache_size = -64000;  -- 64MB

-- Enable memory-mapped I/O
PRAGMA mmap_size = 268435456;  -- 256MB

-- Optimize for reads
PRAGMA synchronous = NORMAL;
```

---

## Appendix A: Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENROUTER_API_KEY` | (none) | OpenRouter API key |
| `SMRITI_DB_PATH` | `data/holons/smriti.db` | Database path |
| `SMRITI_DEFAULT_CLUSTER` | `docs` | Default cluster |
| `SMRITI_AI_TIMEOUT` | `30` | AI request timeout (seconds) |

## Appendix B: File Locations

```
lib/cepaf/
├── src/
│   ├── Cepaf.Smriti.Shared/
│   │   └── Types.fs              # Core types
│   ├── Cepaf.Smriti.Api/
│   │   ├── Data/
│   │   │   ├── SmritiLifecycle.fs  # CRUD operations
│   │   │   └── DocsIngestor.fs   # Ingestion
│   │   ├── AI/
│   │   │   └── OpenRouterClient.fs # AI integration
│   │   └── Cortex/
│   │       └── SmritiCortex.fs     # Orchestration
│   └── Cepaf/Mesh/
│       └── SIL6MeshCLI.fs        # Mesh integration
├── scripts/
│   └── SmritiIngestorCLI.fsx       # CLI script
├── emacs/
│   └── smriti-mode.el              # Emacs package
└── artifacts/
    └── (deployment configs)

data/holons/
└── smriti.db                       # SQLite database
```

---

## Related Documents

- [SMRITI User Guide](SMRITI_USER_GUIDE.md)
- [User Operations Guide](../USER_OPERATIONS_GUIDE.md)
- [SMRITI AI Quality Comparison](SMRITI_AI_QUALITY_COMPARISON.md)
- [SMRITI 8-Level Fractal Evolution Plan](SMRITI_8LEVEL_FRACTAL_EVOLUTION_PLAN.md)

## AOR Rules (SMRITI)

| ID | Rule |
|----|------|
| AOR-AI-001 | PERSIST memory/context to SMRITI for continuity across sessions |
| AOR-SMRITI-001 | Always compute content hash before insert |
| AOR-SMRITI-002 | Update FTS index atomically with holon |

---

*Document generated by SMRITI v21.3.0-SIL6 | Indrajaal Project | 2026-01-11*
