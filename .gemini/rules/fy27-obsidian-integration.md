# FY27 Obsidian Integration Protocol (SC-FY27-OBS)

## Mandate
**The FY27-Plan folder IS the Obsidian vault. All markdown files created by Gemini are simultaneously Obsidian notes and ZK-importable documents. One folder, three consumers: Obsidian (visual), FY27-ZK (search), C3I-ZK (engineering context).**

## Architecture
```
FY27-Plan/ (= Obsidian Vault)
  .obsidian/              -- Obsidian config (app.json, plugins, themes)
  HOME.md                 -- Map of Content (Obsidian landing page)
  templates/              -- Obsidian templates (daily log, meeting, decision, account plan)
  activities/             -- Daily logs, meetings, decisions (Obsidian daily notes)
  Analysis/               -- Business cases, rate cards, funnel models
  Presentation/           -- Strategy decks
  refs/                   -- OEM data, contacts, trackers
  zettelkasten/           -- ZK database + Rust binary (excluded from Obsidian indexing)
  exports/                -- CSV exports
```

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-FY27-OBS-001 | ALL markdown files MUST be valid Obsidian notes (YAML frontmatter optional, wikilinks OK) | HIGH |
| SC-FY27-OBS-002 | Templates MUST be used for meetings, decisions, and account plans | MEDIUM |
| SC-FY27-OBS-003 | Tags MUST use #hashtag format for Obsidian compatibility | MEDIUM |
| SC-FY27-OBS-004 | Internal links MUST use [[wikilink]] format where possible | MEDIUM |
| SC-FY27-OBS-005 | ZK import MUST run after any markdown file creation/edit | HIGH |
| SC-FY27-OBS-006 | .obsidian/ folder MUST NOT be imported to ZK | LOW |
| SC-FY27-OBS-007 | HOME.md MUST be kept current as Map of Content | MEDIUM |

## Three-Consumer Model
Every markdown file in FY27-Plan/ serves three purposes simultaneously:
1. **Obsidian**: Visual note-taking, graph view, backlinks, search
2. **FY27-ZK**: Full-text search via SQLite FTS5 (fy27-zettelkasten import)
3. **C3I-ZK**: Engineering context via sa-plan-daemon knowledge-ingest

## Sync Flow
```
User edits in Obsidian -> saves .md file -> gdrive FUSE syncs
Gemini edits via Write tool -> .md file on disk -> Obsidian auto-reloads
Either -> run $ZK import .. -> FY27-ZK updated
Either -> run knowledge_ingest MCP -> C3I-ZK updated
```

## Daily Notes Integration
Obsidian daily notes create files in activities/ with format YYYY-MM-DD-activity-log.md -- same format as /fy27-log command output. Both Gemini and Obsidian write to the same files.
