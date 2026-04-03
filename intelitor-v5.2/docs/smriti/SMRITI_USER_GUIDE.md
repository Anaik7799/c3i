# SMRITI User Guide

**Zettelkasten Knowledge Management System**
**Version**: 21.3.0-SIL6
**Last Updated**: 2026-01-11
**Framework**: SIL-6 Biomorphic Fractal Mesh
**Compliance**: IEC 61508 SIL-6, ISO 27001

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Quick Start](#2-quick-start)
3. [Understanding Zettelkasten](#3-understanding-zettelkasten)
4. [Using the CLI](#4-using-the-cli)
5. [Using Emacs Integration](#5-using-emacs-integration)
6. [Managing Knowledge](#6-managing-knowledge)
7. [Working with Entropy](#7-working-with-entropy)
8. [AI-Powered Features](#8-ai-powered-features)
9. [Best Practices](#9-best-practices)
10. [FAQ](#10-faq)

---

## 1. Introduction

### 1.1 What is SMRITI?

SMRITI (Zettelkasten Knowledge Management System) is a smart knowledge base that:

- **Organizes** your documents into interconnected knowledge units called "Zettels"
- **Tracks** the freshness of your knowledge with an entropy system
- **Links** related concepts automatically and manually
- **Searches** using full-text search and semantic similarity
- **Extracts** metadata using AI (optional)

### 1.2 Key Concepts

| Concept | Description |
|---------|-------------|
| **Zettel** | A single unit of knowledge (from German: "slip of paper") |
| **Holon** | A self-contained whole that's also part of a larger system |
| **Entropy** | Measure of knowledge staleness (0 = fresh, 1 = rotting) |
| **Cluster** | A logical grouping of related Zettels |
| **Link** | A connection between two Zettels |
| **Backlink** | An automatic reverse link |

### 1.3 The Fractal Hierarchy

Zettels are organized in a fractal hierarchy:

```
L1: Atomic       - Single note, function, or concept
                   Example: "What is a Holon?"

L2: Molecular    - Cluster of related notes
                   Example: "Holon Architecture Overview"

L3: Organism     - Complete topic or domain
                   Example: "Indrajaal System Architecture"

L4: Ecosystem    - System-wide documentation
                   Example: "Complete Platform Guide"
```

---

## 2. Quick Start

### 2.1 Prerequisites

- .NET 10.0 SDK installed
- Terminal/command line access
- (Optional) Emacs 29.1+ for editor integration
- (Optional) OpenRouter API key for AI features

### 2.2 First Steps

**1. Check System Status**

```bash
cd /path/to/intelitor-v5.2
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx status
```

Output:
```
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
======================================================================
```

**2. Ingest Your First Documents**

```bash
# Ingest up to 10 markdown files from docs/architecture
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx ingest docs/architecture --max 10 --cluster architecture
```

**3. Search Your Knowledge Base**

```bash
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx search "holon" --limit 5
```

---

## 3. Understanding Zettelkasten

### 3.1 The Philosophy

The Zettelkasten method was developed by sociologist Niklas Luhmann, who used it to write over 70 books and 400 articles. The key principles are:

1. **Atomicity** - Each note contains one idea
2. **Linking** - Ideas connect to form a network
3. **Emergence** - New insights arise from connections
4. **Personal** - Use your own words and understanding

### 3.2 SMRITI Enhancements

SMRITI adds modern features to the classic method:

| Classic | SMRITI Enhancement |
|---------|------------------|
| Index cards | SQLite database with FTS5 |
| Manual numbering | UUID identifiers |
| Physical links | Typed links (wiki, semantic, code) |
| Paper decay | Digital entropy tracking |
| Manual search | Full-text + semantic search |

### 3.3 The Knowledge Graph

Your Zettels form a knowledge graph:

```
     ┌────────┐
     │ Holon  │
     │Overview│
     └───┬────┘
         │ wiki link
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────┐
│ SQLite │ │ DuckDB │
│ State  │ │ History│
└────┬───┘ └───┬────┘
     │ semantic │
     └────┬─────┘
          ▼
     ┌────────┐
     │Analytics│
     └─────────┘
```

---

## 4. Using the CLI

### 4.1 Command Overview

```bash
# General format
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx <command> [options]
```

### 4.2 Commands Reference

#### Status

View the current state of your knowledge base:

```bash
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx status
```

Shows:
- Total number of Zettels (holons)
- Orphan count (Zettels with no links)
- Stale count (Zettels with high entropy)
- AI availability
- Cluster breakdown with entropy

#### Ingest

Import documents into the knowledge base:

```bash
# Basic ingestion
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx ingest <path>

# With options
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx ingest docs/guides --max 20 --cluster guides
```

Options:
- `--max <N>` - Maximum files to ingest (default: 10)
- `--cluster <name>` - Cluster name (default: "docs")

What happens during ingestion:
1. Markdown files are discovered recursively
2. Content is extracted and hashed (SHA-256)
3. Duplicates are skipped based on hash
4. AI extracts title, summary, tags (if available)
5. Zettel is created with calculated entropy
6. Links to existing Zettels are detected

#### Search

Find Zettels by keyword:

```bash
# Basic search
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx search "authentication"

# With limit
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx search "security policy" --limit 10
```

Output shows:
- Zettel ID (first 8 characters)
- Title
- Entropy score

#### Orphans

Find Zettels that have no links:

```bash
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx orphans
```

Orphans indicate:
- New, unconnected knowledge
- Topics that need integration
- Potential candidates for linking

#### Stale

Find Zettels with high entropy (knowledge decay):

```bash
# Default threshold (0.6)
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx stale

# Custom threshold
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx stale --threshold 0.5
```

#### Entropy

Recalculate entropy for all Zettels:

```bash
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx entropy
```

Run this periodically to update staleness scores.

### 4.3 Using via SIL-6 Biomorphic Mesh

If using the full mesh system:

```bash
# Via mesh CLI
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- smriti status
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- smriti ingest docs 10 docs
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- smriti search "holon" 5
```

---

## 5. Using Emacs Integration

### 5.1 Setup

Add to your Emacs configuration (`~/.emacs.d/init.el`):

```elisp
;; Add SMRITI to load path
(add-to-list 'load-path "/path/to/intelitor-v5.2/lib/cepaf/emacs")

;; Load SMRITI mode
(require 'smriti-mode)

;; Set up global key bindings
(smriti-setup-keybindings)

;; Optional: Set project root
(setq smriti-project-root "/path/to/intelitor-v5.2")
```

### 5.2 Dashboard

Open the dashboard with `C-c z d` or `M-x smriti-dashboard`:

```
╔════════════════════════════════════════════════════════════╗
║          SMRITI - Zettelkasten Knowledge Management          ║
╠════════════════════════════════════════════════════════════╣
║  Keys: g=refresh s=search i=ingest o=orphans t=stale q=quit║
╚════════════════════════════════════════════════════════════╝
```

Dashboard keys:
- `g` - Refresh dashboard
- `s` - Search
- `i` - Ingest directory
- `o` - Show orphans
- `t` - Show stale Zettels
- `e` - Recalculate entropy
- `q` - Quit

### 5.3 Key Bindings

| Key | Command | Description |
|-----|---------|-------------|
| `C-c z d` | Dashboard | Open interactive dashboard |
| `C-c z s` | Search | Search Zettels by keyword |
| `C-c z i` | Ingest | Ingest directory into SMRITI |
| `C-c z o` | Orphans | Show unlinked Zettels |
| `C-c z t` | Stale | Show high-entropy Zettels |
| `C-c z e` | Entropy | Recalculate all entropy |
| `C-c z z` | Menu | Open transient menu (if available) |

### 5.4 Ingest Current Buffer

When editing a markdown file, ingest its directory:

```elisp
M-x smriti-ingest-buffer
```

This ingests all `.md` files in the current file's directory.

### 5.5 Org-Mode Links

SMRITI supports Org-mode links:

```org
* My Project Notes

See [[smriti:abc12345-1234-5678-90ab-cdef12345678][Holon Architecture]] for details.
```

Clicking the link opens a search for that Zettel ID.

### 5.6 Transient Menu

If you have `transient.el` installed, use `C-c z z` for a visual menu:

```
┌─────────────────────────────────────┐
│ SMRITI Commands                       │
├─────────────────────────────────────┤
│ d Dashboard    s Search             │
│ i Ingest       b Ingest Buffer Dir  │
├─────────────────────────────────────┤
│ Analysis                            │
├─────────────────────────────────────┤
│ o Orphans      t Stale              │
│ e Recalculate Entropy               │
├─────────────────────────────────────┤
│ Info                                │
├─────────────────────────────────────┤
│ ? Status                            │
└─────────────────────────────────────┘
```

---

## 6. Managing Knowledge

### 6.1 Ingestion Workflow

**Step 1: Prepare Documents**

Organize markdown files by topic:
```
docs/
├── architecture/
│   ├── holon-overview.md
│   ├── immutable-register.md
│   └── constitutional-invariants.md
├── guides/
│   ├── quick-start.md
│   └── deployment.md
└── api/
    ├── rest-endpoints.md
    └── websocket-protocol.md
```

**Step 2: Ingest by Cluster**

```bash
# Ingest architecture docs
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx ingest docs/architecture --max 50 --cluster architecture

# Ingest guides
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx ingest docs/guides --max 50 --cluster guides

# Ingest API docs
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx ingest docs/api --max 50 --cluster api
```

**Step 3: Review Results**

```bash
# Check status
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx status

# Find any orphans
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx orphans
```

### 6.2 Link Types

SMRITI supports four link types:

| Type | Description | Created By |
|------|-------------|------------|
| **WikiLink** | Explicit `[[target]]` reference | Manual or AI |
| **SemanticSimilar** | Vector similarity match | AI analysis |
| **CodeReference** | Import or function reference | Code analysis |
| **Backlink** | Reverse of WikiLink | Automatic |

### 6.3 Clusters

Clusters group related Zettels:

- **docs** - General documentation
- **architecture** - System design
- **api** - API reference
- **guides** - User guides
- **tutorials** - Step-by-step tutorials
- **reference** - Technical reference

Best practices:
- Use consistent cluster names
- Limit to 5-10 clusters
- Review cluster entropy regularly

### 6.4 Finding and Linking

**Search for related Zettels:**
```bash
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx search "authentication security"
```

**Review orphans for linking opportunities:**
```bash
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx orphans
```

---

## 7. Working with Entropy

### 7.1 Understanding Entropy

Entropy measures how "stale" knowledge becomes over time:

| Entropy Range | Label | Color | Meaning |
|--------------|-------|-------|---------|
| 0.0 - 0.2 | Fresh | Green | Recently verified |
| 0.2 - 0.4 | Good | Lime | Still relevant |
| 0.4 - 0.6 | Aging | Yellow | Review recommended |
| 0.6 - 0.8 | Stale | Orange | Needs update |
| 0.8 - 1.0 | Rotting | Red | Likely outdated |

### 7.2 Decay Rates

Different content types decay at different rates:

| Decay Rate | Type | Half-Life |
|------------|------|-----------|
| **Fast** | API docs, configs | Days |
| **Medium** | Design docs | Weeks |
| **Slow** | Architecture | Months |

### 7.3 Verification

Verifying a Zettel reduces its entropy:

- **Verified < 30 days**: 50% entropy reduction
- **Verified older**: 20% entropy reduction
- **Never verified**: Full entropy

### 7.4 Maintenance Workflow

**Weekly:**
1. Check for stale Zettels:
   ```bash
   dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx stale --threshold 0.6
   ```

2. Review and update stale content

3. Recalculate entropy:
   ```bash
   dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx entropy
   ```

**Monthly:**
1. Review orphan Zettels:
   ```bash
   dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx orphans
   ```

2. Create links or remove obsolete Zettels

3. Review cluster distribution in status

---

## 8. AI-Powered Features

### 8.1 Setting Up AI

1. Create an account at [OpenRouter](https://openrouter.ai)
2. Get your API key
3. Set the environment variable:

```bash
# Linux/Mac
export OPENROUTER_API_KEY="sk-or-v1-your-key-here"

# Windows
set OPENROUTER_API_KEY=sk-or-v1-your-key-here
```

4. Verify AI is available:
```bash
dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx status
# Should show: AI Available: true
```

### 8.2 AI Extraction

When AI is enabled, ingestion extracts:

- **Title**: Clear, descriptive title (max 80 chars)
- **Summary**: 2-sentence overview
- **Tags**: Up to 5 relevant keywords
- **Level**: Holon classification (atomic/molecular/organism)
- **Key Concepts**: 3-5 main ideas
- **Related Topics**: 2-3 related areas

### 8.3 Without AI

When AI is not available, SMRITI uses fallback extraction:

- **Title**: From first `# Heading` or filename
- **Level**: Based on content length
- **Tags**: Empty (can be added manually)
- **Summary**: Empty

### 8.4 Cost Considerations

SMRITI uses Claude 3 Haiku by default, which is cost-effective:

| Model | Cost per 1M tokens |
|-------|-------------------|
| Claude 3 Haiku | $0.25 input, $1.25 output |
| Claude 3 Sonnet | $3 input, $15 output |
| Claude 3 Opus | $15 input, $75 output |

For a 1000-document ingestion:
- Average: ~500 tokens per document
- Total: ~500,000 tokens
- Cost: ~$0.75

---

## 9. Best Practices

### 9.1 Document Structure

Write markdown files with clear structure:

```markdown
# Clear Title

## Overview
Brief introduction to the topic.

## Key Concepts
- Concept 1
- Concept 2

## Details
Detailed explanation...

## Related
- [[link-to-related-topic]]
- See also: Other Topic

## Tags
#tag1 #tag2 #tag3
```

### 9.2 Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Files | kebab-case | `holon-architecture.md` |
| Clusters | lowercase | `architecture`, `guides` |
| Tags | lowercase, singular | `holon`, `security`, `api` |

### 9.3 Linking Strategy

**Do:**
- Link to prerequisites ("See X before reading this")
- Link to related concepts ("This is similar to Y")
- Link to implementations ("Implemented in Z")

**Don't:**
- Create circular links without purpose
- Over-link (1-5 links per Zettel is ideal)
- Link to unrelated content

### 9.4 Entropy Management

**Keep entropy low by:**
- Verifying content after updates
- Reviewing stale content weekly
- Deleting obsolete Zettels
- Setting appropriate decay rates

### 9.5 Cluster Organization

```
Recommended Clusters:

architecture/     # System design, principles
├── holon/       # Holon-specific architecture
├── mesh/        # Mesh networking
└── safety/      # Safety constraints

api/              # API documentation
├── rest/        # REST endpoints
├── graphql/     # GraphQL schema
└── websocket/   # WebSocket protocol

guides/           # User guides
├── getting-started/
├── deployment/
└── troubleshooting/

reference/        # Technical reference
├── config/      # Configuration
├── cli/         # CLI reference
└── schemas/     # Data schemas
```

---

## 10. FAQ

### General

**Q: How many Zettels can SMRITI handle?**
A: SQLite can easily handle millions of rows. Performance optimizations are included for 10,000+ Zettels.

**Q: Can I use SMRITI without AI?**
A: Yes! AI is optional. Without it, you'll use fallback extraction (title from heading, level from size).

**Q: Where is my data stored?**
A: In `data/holons/smriti.db` (SQLite database). This single file contains all your Zettels.

### Ingestion

**Q: What file types are supported?**
A: Currently, only Markdown (`.md`) files are supported.

**Q: How does deduplication work?**
A: Content is hashed with SHA-256. If the hash already exists, the file is skipped.

**Q: Why are some files skipped?**
A: Files are skipped if:
- They've been ingested before (same hash)
- They're empty
- They can't be read

### Search

**Q: How does search work?**
A: SMRITI uses SQLite FTS5 (Full-Text Search) with:
- Porter stemming (searching "run" finds "running")
- Phrase matching ("exact phrase")
- Boolean operators (AND, OR, NOT)

**Q: Can I search by tag?**
A: Yes, tags are included in the FTS index. Search for `#tagname`.

### Entropy

**Q: Why does entropy increase?**
A: Entropy increases automatically based on:
- Time since last modification
- Time since last verification
- Decay rate classification

**Q: How do I verify a Zettel?**
A: Currently, verification happens when content is updated. Future versions will support explicit verification.

### Emacs

**Q: Do I need Emacs to use SMRITI?**
A: No, the CLI works standalone. Emacs integration is optional.

**Q: What Emacs version is required?**
A: Emacs 29.1 or later (for lexical binding and modern features).

---

## Appendix A: Keyboard Quick Reference

### CLI Commands
```
status                  Show dashboard
ingest <path>          Import documents
search <query>         Find Zettels
orphans                Show unlinked
stale                  Show high-entropy
entropy                Recalculate
```

### Emacs Keys
```
C-c z d    Dashboard
C-c z s    Search
C-c z i    Ingest
C-c z o    Orphans
C-c z t    Stale
C-c z e    Entropy
C-c z z    Menu
```

### Dashboard Keys
```
g    Refresh
s    Search
i    Ingest
o    Orphans
t    Stale
e    Entropy
q    Quit
```

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| **Backlink** | Automatic reverse link when A links to B |
| **Cluster** | Logical grouping of related Zettels |
| **Entropy** | Measure of knowledge staleness (0-1) |
| **FTS5** | SQLite Full-Text Search extension |
| **Holon** | Self-contained whole that's part of a larger system |
| **Level** | Fractal hierarchy (Atomic→Molecular→Organism→Ecosystem) |
| **Link** | Connection between two Zettels |
| **Orphan** | Zettel with no incoming or outgoing links |
| **Stale** | Zettel with high entropy (>0.6) |
| **Zettel** | Single unit of knowledge (German: "slip of paper") |
| **Zettelkasten** | Slip-box method of knowledge management |

---

## Related Documents

- [SMRITI Developer Guide](SMRITI_DEVELOPER_GUIDE.md)
- [User Operations Guide](../USER_OPERATIONS_GUIDE.md)
- [SMRITI 8-Level Fractal Evolution Plan](SMRITI_8LEVEL_FRACTAL_EVOLUTION_PLAN.md)
- [SMRITI Intelligence Substrate Analysis](SMRITI_INTELLIGENCE_SUBSTRATE_ANALYSIS.md)

---

*User Guide for SMRITI v21.3.0-SIL6 | Indrajaal Project | 2026-01-11*
