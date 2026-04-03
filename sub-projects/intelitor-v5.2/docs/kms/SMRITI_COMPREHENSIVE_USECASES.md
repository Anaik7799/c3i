# Z-KMS Comprehensive Use Cases

## Overview

This document defines comprehensive use cases for Z-KMS (Zettelkasten Knowledge Management System) based on analysis of leading Zettelkasten systems: Obsidian, Logseq, Roam Research, AFFiNE, Zettlr, Heptabase, and Mem.ai.

---

## 1. Core Knowledge Management

### UC-CORE-001: Create Atomic Zettel
**Actor**: User
**Priority**: P0 (Critical)
**Description**: Create a single, atomic note containing one idea

**Preconditions**:
- User is authenticated
- Z-KMS is running

**Main Flow**:
1. User clicks "New Zettel" or uses keyboard shortcut (Cmd/Ctrl+N)
2. System creates new Zettel with unique UUID
3. User enters title and markdown content
4. System auto-saves every 3 seconds
5. System calculates entropy (freshness score)
6. System assigns level (atomic/molecular/organism/ecosystem)

**Postconditions**:
- Zettel persisted to SQLite
- FTS index updated
- Graph node created

**Acceptance Criteria**:
- [ ] Zettel creation < 100ms
- [ ] Auto-save reliable
- [ ] Entropy calculated correctly based on age

---

### UC-CORE-002: Bi-Directional Linking
**Actor**: User
**Priority**: P0 (Critical)
**Description**: Create links between Zettels that work in both directions

**Preconditions**:
- At least 2 Zettels exist

**Main Flow**:
1. User types `[[` to trigger link autocomplete
2. System shows searchable list of existing Zettels
3. User selects target Zettel
4. System creates forward link (`wiki` type)
5. System automatically creates backlink in target Zettel

**Alternative Flow**:
- User creates link to non-existent Zettel
- System offers to create new Zettel with that title

**Postconditions**:
- Edge created in holon_edges table
- Backlink visible in target Zettel
- Graph updated with new edge

**Acceptance Criteria**:
- [ ] Link autocomplete < 50ms
- [ ] Backlinks automatically maintained
- [ ] Broken links detected and highlighted

---

### UC-CORE-003: Tag Management
**Actor**: User
**Priority**: P1 (High)
**Description**: Organize Zettels using hierarchical tags

**Main Flow**:
1. User adds tags using `#tag` syntax in content
2. System extracts and indexes tags
3. User can browse by tag hierarchy (e.g., `#project/indrajaal/kms`)
4. System shows tag cloud with frequency

**Features from Competitors**:
- **Obsidian**: Nested tags with `/`
- **Logseq**: Tags as page references
- **Roam**: Auto-complete tags

**Acceptance Criteria**:
- [ ] Hierarchical tags supported (3+ levels)
- [ ] Tag search < 20ms
- [ ] Tag rename propagates to all Zettels

---

### UC-CORE-004: Full-Text Search with Highlights
**Actor**: User
**Priority**: P0 (Critical)
**Description**: Search across all Zettel content with highlighted matches

**Preconditions**:
- FTS5 index populated

**Main Flow**:
1. User enters search query in search bar
2. System queries FTS5 virtual table
3. Results ranked by relevance score
4. Matching terms highlighted in snippets
5. User can filter by cluster, level, entropy

**Features from Competitors**:
- **Obsidian**: Boolean operators, regex support
- **Heptabase**: Semantic search with AI
- **Mem.ai**: Natural language queries

**Acceptance Criteria**:
- [ ] Search < 100ms for 10K+ Zettels
- [ ] Highlights accurate
- [ ] Filters work correctly

---

## 2. Graph Visualization

### UC-GRAPH-001: Interactive Knowledge Graph
**Actor**: User
**Priority**: P0 (Critical)
**Description**: Visualize Zettel network as interactive graph

**Preconditions**:
- Cytoscape.js loaded
- Graph data available from API

**Main Flow**:
1. User navigates to Graph View
2. System loads nodes (Zettels) and edges (links)
3. User can zoom, pan, drag nodes
4. Clicking node opens Zettel preview
5. Graph layout auto-arranges using force-directed algorithm

**Features from Competitors**:
- **Obsidian**: Local graph (neighbors only), global graph
- **Heptabase**: Cards on infinite canvas
- **Roam**: Page-centric graph

**Visual Encoding**:
| Property | Visual Encoding |
|----------|-----------------|
| Entropy 0.0-0.3 | Green (fresh) |
| Entropy 0.3-0.6 | Yellow (aging) |
| Entropy 0.6-1.0 | Red (rotting) |
| Level atomic | Small node |
| Level ecosystem | Large node |
| Cluster | Node color group |

**Acceptance Criteria**:
- [ ] Graph renders < 500ms for 1000 nodes
- [ ] Smooth zoom/pan (60fps)
- [ ] Node click opens preview < 100ms

---

### UC-GRAPH-002: Cluster Visualization
**Actor**: User
**Priority**: P1 (High)
**Description**: View Zettels grouped by cluster/topic

**Main Flow**:
1. User selects "Cluster View" mode
2. System groups nodes by cluster attribute
3. Clusters displayed as bounded regions
4. User can expand/collapse clusters
5. Inter-cluster links shown as weighted edges

**Features from Competitors**:
- **Heptabase**: Nested whiteboards
- **AFFiNE**: Workspace organization

**Acceptance Criteria**:
- [ ] Clusters clearly distinguishable
- [ ] Expand/collapse smooth
- [ ] Cluster statistics visible

---

### UC-GRAPH-003: Local Graph (Ego Network)
**Actor**: User
**Priority**: P1 (High)
**Description**: View immediate neighbors of selected Zettel

**Main Flow**:
1. User selects a Zettel
2. User clicks "Show Local Graph"
3. System displays 1-hop and optionally 2-hop neighbors
4. Central node highlighted
5. User can adjust depth (1-3 hops)

**Acceptance Criteria**:
- [ ] Local graph < 100ms
- [ ] Depth configurable
- [ ] Path to any neighbor visible

---

## 3. AI-Powered Features

### UC-AI-001: Semantic Search
**Actor**: User
**Priority**: P1 (High)
**Description**: Find Zettels by meaning, not just keywords

**Preconditions**:
- Vector embeddings generated for Zettels
- Vector search index available

**Main Flow**:
1. User enters natural language query
2. System generates embedding for query
3. System finds nearest neighbors by cosine similarity
4. Results ranked by semantic relevance
5. Shows why results match (key concepts)

**Features from Competitors**:
- **Mem.ai**: "Smart Search" with AI understanding
- **Heptabase**: AI-powered research assistant
- **AFFiNE**: Built-in AI partner

**Acceptance Criteria**:
- [ ] Semantic search < 500ms
- [ ] Quality of matches verified by user feedback
- [ ] Fallback to FTS if vectors unavailable

---

### UC-AI-002: Auto-Linking Suggestions
**Actor**: System
**Priority**: P2 (Medium)
**Description**: Suggest links between related Zettels

**Main Flow**:
1. System periodically analyzes Zettel content
2. Identifies semantically similar Zettels not yet linked
3. Presents suggestions to user
4. User accepts/rejects suggestions
5. Accepted suggestions create semantic links

**Acceptance Criteria**:
- [ ] Suggestions relevant (>70% acceptance rate)
- [ ] Non-intrusive notification
- [ ] Bulk accept/reject

---

### UC-AI-003: AI-Powered Summarization
**Actor**: User
**Priority**: P2 (Medium)
**Description**: Generate summaries of Zettels or clusters

**Main Flow**:
1. User selects Zettel(s) or cluster
2. User requests summary
3. System sends content to Claude via OpenRouter
4. AI generates concise summary
5. Summary can be saved as new Zettel

**Acceptance Criteria**:
- [ ] Summary < 5 seconds
- [ ] Captures key concepts
- [ ] Preserves technical accuracy

---

### UC-AI-004: Smart Tag Suggestions
**Actor**: System
**Priority**: P2 (Medium)
**Description**: Suggest relevant tags based on content

**Main Flow**:
1. User creates/edits Zettel
2. System analyzes content on save
3. System suggests relevant tags
4. User accepts/rejects/modifies

**Acceptance Criteria**:
- [ ] Suggestions contextually relevant
- [ ] Uses existing tag vocabulary
- [ ] Learns from user feedback

---

## 4. Academic/Research Workflows

### UC-ACAD-001: Citation Management (Zettlr-style)
**Actor**: Researcher
**Priority**: P2 (Medium)
**Description**: Integrate with citation managers

**Preconditions**:
- BibTeX/CSL-JSON library available

**Main Flow**:
1. User imports bibliography (Zotero export, BibTeX)
2. User types `[@citekey]` to insert citation
3. System shows autocomplete from bibliography
4. Citations rendered in specified style (APA, MLA, Chicago, etc.)
5. Bibliography generated at export

**Features from Competitors**:
- **Zettlr**: 9000+ citation styles, Zotero/JabRef integration
- **Obsidian**: Citations plugin

**Acceptance Criteria**:
- [ ] Import BibTeX, CSL-JSON
- [ ] 10+ common citation styles
- [ ] Pandoc export for academic papers

---

### UC-ACAD-002: PDF Annotation Integration
**Actor**: Researcher
**Priority**: P2 (Medium)
**Description**: Link Zettels to PDF annotations

**Main Flow**:
1. User annotates PDF in external tool
2. User imports highlights/annotations
3. System creates Zettels from annotations
4. Links maintained to source PDF + page number
5. User can jump to PDF location

**Features from Competitors**:
- **Heptabase**: Readwise integration
- **Obsidian**: PDF annotator plugin
- **Zettlr**: PDF preview and annotation

**Acceptance Criteria**:
- [ ] Import from Readwise, Zotero
- [ ] Deep links to PDF pages
- [ ] Highlight text preserved

---

### UC-ACAD-003: Literature Review Workflow
**Actor**: Researcher
**Priority**: P2 (Medium)
**Description**: Structured workflow for literature review

**Main Flow**:
1. User creates "Literature Review" cluster
2. Imports papers as source Zettels
3. Creates concept Zettels linked to sources
4. Builds argument structure with links
5. Exports as structured outline

**Acceptance Criteria**:
- [ ] Source tracking maintained
- [ ] Argument chains visible in graph
- [ ] Export to Word/LaTeX

---

## 5. Visual Organization

### UC-VIS-001: Canvas/Whiteboard View (Obsidian Canvas-style)
**Actor**: User
**Priority**: P1 (High)
**Description**: Arrange Zettels freely on infinite canvas

**Preconditions**:
- Canvas component available

**Main Flow**:
1. User creates new Canvas
2. Drags Zettels onto canvas
3. Arranges spatially by topic/relationship
4. Draws connections between items
5. Adds text annotations, shapes
6. Canvas saved with positions

**Features from Competitors**:
- **Obsidian**: Canvas with cards, media, links
- **Heptabase**: Nested whiteboards
- **AFFiNE**: Merged docs/whiteboards

**Acceptance Criteria**:
- [ ] Infinite pan/zoom
- [ ] Drag and drop smooth
- [ ] Embedded Zettel previews
- [ ] Drawing tools available

---

### UC-VIS-002: Mind Map Generation
**Actor**: User
**Priority**: P2 (Medium)
**Description**: Auto-generate mind map from Zettel links

**Main Flow**:
1. User selects root Zettel
2. Requests "Generate Mind Map"
3. System traverses links hierarchically
4. Displays as expandable tree
5. User can rearrange nodes

**Acceptance Criteria**:
- [ ] Handles cycles gracefully
- [ ] Depth configurable
- [ ] Export as image/SVG

---

### UC-VIS-003: Timeline View
**Actor**: User
**Priority**: P3 (Low)
**Description**: View Zettels on temporal axis

**Main Flow**:
1. User switches to Timeline View
2. Zettels arranged by created_at/updated_at
3. User can filter by date range
4. Entropy decay visible over time

**Acceptance Criteria**:
- [ ] Smooth scrolling timeline
- [ ] Zoom by day/week/month/year
- [ ] Entropy history visible

---

## 6. Spaced Repetition & Learning

### UC-LEARN-001: Flashcard Generation
**Actor**: User
**Priority**: P2 (Medium)
**Description**: Create flashcards from Zettels

**Main Flow**:
1. User marks Zettel for review
2. System generates Q&A flashcards
3. User reviews cards with spaced repetition algorithm
4. System tracks recall success
5. Reviews reduce entropy

**Features from Competitors**:
- **Obsidian**: Spaced Repetition plugin
- **Logseq**: Built-in flashcards
- **Roam**: SR integration

**Acceptance Criteria**:
- [ ] SM-2 or similar algorithm
- [ ] Card generation automatic or manual
- [ ] Entropy decreased on successful review

---

### UC-LEARN-002: Daily Review Queue
**Actor**: User
**Priority**: P2 (Medium)
**Description**: Review aging/rotting Zettels

**Main Flow**:
1. User opens Daily Review
2. System presents high-entropy Zettels
3. User reviews and updates content
4. Entropy reset on update
5. Links refreshed

**Acceptance Criteria**:
- [ ] Prioritized by entropy
- [ ] Quick update workflow
- [ ] Streak tracking

---

## 7. Import/Export & Integration

### UC-INT-001: Markdown Import (Obsidian Vault)
**Actor**: User
**Priority**: P1 (High)
**Description**: Import existing Obsidian vault

**Main Flow**:
1. User selects folder to import
2. System scans for .md files
3. Parses YAML frontmatter
4. Extracts [[wikilinks]]
5. Creates Zettels with preserved links
6. Generates edges for links

**Acceptance Criteria**:
- [ ] Frontmatter preserved as metadata
- [ ] Links converted correctly
- [ ] Attachments handled

---

### UC-INT-002: Export to Markdown
**Actor**: User
**Priority**: P1 (High)
**Description**: Export Zettels as markdown files

**Main Flow**:
1. User selects Zettels/clusters to export
2. Chooses export format (Obsidian, Logseq, plain)
3. System generates .md files
4. Includes frontmatter with metadata
5. Links converted to target format

**Acceptance Criteria**:
- [ ] Round-trip compatible
- [ ] Metadata preserved
- [ ] Folder structure options

---

### UC-INT-003: API for External Tools
**Actor**: External System
**Priority**: P1 (High)
**Description**: REST/MCP API for programmatic access

**Endpoints**:
```
GET    /api/zettels          - List all (paginated)
GET    /api/zettels/:id      - Get single Zettel
POST   /api/zettels          - Create Zettel
PUT    /api/zettels/:id      - Update Zettel
DELETE /api/zettels/:id      - Delete Zettel
GET    /api/graph            - Full graph data
GET    /api/search?q=        - Full-text search
POST   /api/search/vector    - Semantic search
GET    /api/metrics/entropy  - Entropy statistics
GET    /mcp/read_zettel      - MCP: Read for AI agents
GET    /mcp/search           - MCP: Search for AI agents
```

**Acceptance Criteria**:
- [ ] OpenAPI spec available
- [ ] Authentication (API key)
- [ ] Rate limiting
- [ ] MCP compatible for Claude

---

### UC-INT-004: Browser Extension (Obsidian Web Clipper-style)
**Actor**: User
**Priority**: P3 (Low)
**Description**: Capture web content as Zettels

**Main Flow**:
1. User browses web page
2. Clicks extension button
3. Selects text/page to capture
4. Extension sends to Z-KMS API
5. New Zettel created with source URL

**Acceptance Criteria**:
- [ ] Chrome/Firefox extension
- [ ] Selective capture
- [ ] Auto-tags from page

---

## 8. Collaboration & Publishing

### UC-COLLAB-001: Shared Workspaces
**Actor**: Team
**Priority**: P3 (Low)
**Description**: Collaborate on shared knowledge base

**Main Flow**:
1. User creates workspace
2. Invites team members
3. Real-time sync of changes
4. Conflict resolution
5. Activity feed

**Features from Competitors**:
- **Obsidian**: Sync + Publish
- **Roam**: Multiplayer
- **AFFiNE**: Collaboration built-in

**Acceptance Criteria**:
- [ ] Real-time sync
- [ ] Conflict handling
- [ ] Permission levels

---

### UC-COLLAB-002: Publish to Web
**Actor**: User
**Priority**: P3 (Low)
**Description**: Publish Zettels as static website

**Main Flow**:
1. User selects Zettels to publish
2. Configures site settings
3. System generates static HTML
4. Deploys to hosting
5. Graph view embedded

**Acceptance Criteria**:
- [ ] Static site generation
- [ ] Interactive graph
- [ ] Custom domain

---

## 9. Entropy & Maintenance

### UC-MAINT-001: Entropy Dashboard
**Actor**: User
**Priority**: P1 (High)
**Description**: Monitor knowledge freshness

**Main Flow**:
1. User views Entropy Dashboard
2. Shows distribution: fresh/aging/rotting
3. Highlights "at risk" Zettels
4. Suggests review priorities
5. Tracks entropy over time

**Metrics**:
- Total Zettels by entropy bucket
- Average entropy by cluster
- Entropy trend (improving/declining)
- Days since last review

**Acceptance Criteria**:
- [ ] Real-time updates
- [ ] Drill-down capability
- [ ] Export reports

---

### UC-MAINT-002: Orphan Detection
**Actor**: User
**Priority**: P2 (Medium)
**Description**: Find unlinked Zettels

**Main Flow**:
1. System identifies Zettels with no incoming/outgoing links
2. Presents orphan list
3. User can link or archive
4. Bulk actions available

**Acceptance Criteria**:
- [ ] Accurate detection
- [ ] Bulk linking
- [ ] Archive option

---

### UC-MAINT-003: Duplicate Detection
**Actor**: System
**Priority**: P2 (Medium)
**Description**: Identify similar/duplicate Zettels

**Main Flow**:
1. System computes content similarity
2. Flags potential duplicates
3. User reviews and merges or differentiates
4. Links updated on merge

**Acceptance Criteria**:
- [ ] Similarity threshold configurable
- [ ] Merge preserves both histories
- [ ] Links redirected

---

## 10. Mobile & Offline

### UC-MOBILE-001: Mobile Access
**Actor**: User
**Priority**: P2 (Medium)
**Description**: Access Z-KMS from mobile devices

**Main Flow**:
1. User opens mobile app/PWA
2. Syncs with server
3. Views/edits Zettels
4. Offline changes queued
5. Syncs when online

**Features from Competitors**:
- **Obsidian**: Mobile app with Sync
- **Logseq**: Mobile app
- **Mem.ai**: Mobile-first

**Acceptance Criteria**:
- [ ] Responsive web or native app
- [ ] Offline editing
- [ ] Conflict resolution

---

### UC-MOBILE-002: Quick Capture
**Actor**: User
**Priority**: P2 (Medium)
**Description**: Quickly capture thoughts on mobile

**Main Flow**:
1. User opens quick capture widget
2. Enters thought/note
3. System creates inbox Zettel
4. User processes inbox later
5. Promotes to full Zettel with links

**Acceptance Criteria**:
- [ ] < 3 taps to capture
- [ ] Voice input option
- [ ] Inbox processing workflow

---

## Feature Priority Matrix

| Priority | Features | Implementation Phase |
|----------|----------|---------------------|
| **P0 (Critical)** | Create Zettel, Bi-directional Links, Search, Graph View | Phase 1 |
| **P1 (High)** | Tags, Cluster View, Local Graph, Semantic Search, Canvas, Import/Export, API, Entropy Dashboard | Phase 2 |
| **P2 (Medium)** | Auto-linking, AI Summarization, Citations, PDF, Flashcards, Daily Review, Mobile, Orphan/Duplicate Detection | Phase 3 |
| **P3 (Low)** | Timeline, Browser Extension, Collaboration, Publishing | Phase 4 |

---

## Competitive Feature Comparison

| Feature | Obsidian | Logseq | Roam | AFFiNE | Zettlr | Heptabase | Mem.ai | Z-KMS (Target) |
|---------|----------|--------|------|--------|--------|-----------|--------|----------------|
| Bi-directional Links | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Graph View | Yes | Yes | Yes | No | Limited | Yes | No | Yes |
| Canvas/Whiteboard | Yes | Yes | No | Yes | No | Yes | No | Planned |
| Plugin System | 1000+ | Yes | Limited | No | Limited | No | No | Planned |
| AI Features | Plugin | No | No | Yes | No | Yes | Yes | Yes (Claude) |
| Local-first | Yes | Yes | No | Yes | Yes | Yes | No | Yes |
| Open Source | No | Yes | No | Yes | Yes | No | No | Yes |
| Citations | Plugin | No | No | No | Yes | No | No | Planned |
| Spaced Repetition | Plugin | Yes | No | No | No | No | Yes | Planned |
| Semantic Search | No | No | No | No | No | Yes | Yes | Planned |
| Entropy/Decay | No | No | No | No | No | No | No | **Unique** |
| Mobile App | Yes | Yes | Yes | Planned | No | Yes | Yes | Planned |

---

## STAMP Constraints (Use Cases)

| ID | Constraint | Use Cases |
|----|------------|-----------|
| SC-UC-001 | All CRUD operations < 100ms | UC-CORE-* |
| SC-UC-002 | Search returns in < 500ms | UC-CORE-004, UC-AI-001 |
| SC-UC-003 | Graph renders < 500ms for 1K nodes | UC-GRAPH-* |
| SC-UC-004 | AI features respect rate limits | UC-AI-* |
| SC-UC-005 | Import handles 10K+ files | UC-INT-001 |
| SC-UC-006 | Entropy calculation accurate | UC-MAINT-001 |
| SC-UC-007 | Mobile offline sync reliable | UC-MOBILE-* |

---

## Related Documents

- `docs/kms/DOCS_TO_ZETTEL_CONVERTER_GUIDE.md` - AI Converter Guide
- `scripts/smriti/schema.sql` - Database Schema
- `.claude/plans/dreamy-nibbling-mountain.md` - Implementation Plan
- `lib/cepaf/src/Cepaf.Smriti.Api/` - API Implementation
- `lib/cepaf/src/Cepaf.Smriti.Client/` - Client Implementation
