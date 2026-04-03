# Z-KMS Feature Specifications

## Overview

This document provides detailed feature specifications for Z-KMS based on comprehensive analysis of leading Zettelkasten systems. Each feature includes user stories, acceptance criteria, API contracts, and implementation notes.

> **[Updated Sprint 51: real implementation]** The ingestion-to-storage pipeline is now partially implemented:
> - `Indrajaal.SMRITI.Mesh.VectorStore` provides wired semantic search, similarity computation, and embedding storage
> - `Indrajaal.KMS.AI` provides real AI classification and embedding generation via OpenRouter
> - `Indrajaal.SMRITI.Senses.IngestionPipeline` connects extraction to VectorStore storage
> - CRUD operations, graph queries, and AI features described below are backed by real implementations (not TODOs)

---

## 1. Core Zettel Management

### Feature: F-CORE-001 - Zettel CRUD Operations

#### User Stories

```gherkin
Feature: Zettel Creation and Management
  As a knowledge worker
  I want to create, edit, and organize atomic notes
  So that I can build a connected knowledge base

  Scenario: Create new Zettel
    Given I am on the Z-KMS home page
    When I click "New Zettel" or press Cmd+N
    Then a new Zettel editor opens
    And the Zettel has a unique UUID assigned
    And focus is on the title field

  Scenario: Auto-save Zettel
    Given I am editing a Zettel
    When I stop typing for 3 seconds
    Then the Zettel is automatically saved
    And a "Saved" indicator appears
    And the updated_at timestamp is updated

  Scenario: Delete Zettel with links
    Given a Zettel exists with 3 incoming links
    When I delete the Zettel
    Then a confirmation dialog shows link count
    And all edges are removed from the database
    And the FTS index is updated
```

#### API Contract

```yaml
# POST /api/zettels
Request:
  Content-Type: application/json
  Body:
    title: string (required, max 200 chars)
    content: string (required, markdown)
    tags: string[] (optional)
    level: enum [atomic, molecular, organism, ecosystem] (optional, default: atomic)
    decay_rate: enum [slow, medium, fast] (optional, default: medium)
    cluster: string (optional)

Response:
  201 Created:
    id: uuid
    title: string
    content: string
    tags: string[]
    entropy: float (0.0)
    level: string
    decay_rate: string
    cluster: string
    content_hash: string (SHA-256 first 16 chars)
    inserted_at: ISO8601
    updated_at: ISO8601

  400 Bad Request:
    error: string
    details: object

# GET /api/zettels/:id
Response:
  200 OK: Zettel object
  404 Not Found: { error: "Zettel not found" }

# PUT /api/zettels/:id
Request: Same as POST
Response:
  200 OK: Updated Zettel object
  404 Not Found: { error: "Zettel not found" }

# DELETE /api/zettels/:id
Response:
  204 No Content
  404 Not Found: { error: "Zettel not found" }
```

#### Database Schema

```sql
-- Zettel fields
holon_uuid      TEXT PRIMARY KEY      -- Deterministic UUID
title           TEXT NOT NULL         -- Max 200 chars
content         TEXT NOT NULL         -- Markdown content
tags            TEXT                  -- Comma-separated
entropy         REAL DEFAULT 0.0      -- 0.0 (fresh) to 1.0 (rotting)
level           TEXT DEFAULT 'atomic' -- atomic|molecular|organism|ecosystem
decay_rate      TEXT DEFAULT 'medium' -- slow|medium|fast
cluster         TEXT                  -- Topic cluster
content_hash    TEXT                  -- SHA-256 prefix
inserted_at     TEXT NOT NULL         -- ISO8601
updated_at      TEXT NOT NULL         -- ISO8601
verified_at     TEXT                  -- Last verification
```

---

### Feature: F-CORE-002 - Bi-Directional Linking

#### User Stories

```gherkin
Feature: Bi-Directional Links
  As a knowledge worker
  I want links between Zettels to work both ways
  So that I can navigate my knowledge graph easily

  Scenario: Create wiki-style link
    Given I am editing Zettel A
    When I type "[["
    Then an autocomplete popup appears
    And I can search existing Zettels
    When I select Zettel B
    Then "[[Zettel B]]" is inserted
    And an edge is created from A to B
    And a backlink appears in Zettel B

  Scenario: Link to non-existent Zettel
    Given I am editing a Zettel
    When I type "[[New Concept]]"
    And "New Concept" doesn't exist
    Then the link is shown as unresolved (red)
    And clicking the link offers to create "New Concept"

  Scenario: View backlinks
    Given Zettel B has 5 incoming links
    When I open Zettel B
    Then a backlinks panel shows 5 linked Zettels
    And each backlink shows context snippet
```

#### API Contract

```yaml
# GET /api/zettels/:id/backlinks
Response:
  200 OK:
    backlinks:
      - source_id: uuid
        source_title: string
        link_type: wiki|semantic|code|backlink
        weight: float
        context: string (snippet around link)
        created_at: ISO8601

# POST /api/edges
Request:
  source_id: uuid (required)
  target_id: uuid (required)
  link_type: enum [wiki, semantic, code] (optional, default: wiki)
  weight: float (optional, default: 1.0)

Response:
  201 Created:
    id: integer
    source_id: uuid
    target_id: uuid
    link_type: string
    weight: float
    created_at: ISO8601
```

#### Link Parsing Algorithm

```elixir
# Extract wiki-style links from content
def extract_links(content) do
  # Match [[Link Title]] or [[Link Title|Display Text]]
  ~r/\[\[([^\]|]+)(?:\|[^\]]+)?\]\]/
  |> Regex.scan(content)
  |> Enum.map(fn [_, title] -> title end)
  |> Enum.uniq()
end

# Resolve links to Zettel IDs
def resolve_links(titles) do
  titles
  |> Enum.map(fn title ->
    case find_zettel_by_title(title) do
      nil -> {:unresolved, title}
      zettel -> {:resolved, zettel.id}
    end
  end)
end
```

---

### Feature: F-CORE-003 - Full-Text Search

#### User Stories

```gherkin
Feature: Full-Text Search
  As a knowledge worker
  I want to search across all my Zettels
  So that I can find relevant information quickly

  Scenario: Basic keyword search
    Given 100 Zettels exist
    When I search for "functional programming"
    Then results are ranked by relevance
    And matching terms are highlighted
    And search completes in < 100ms

  Scenario: Boolean operators
    Given Zettels about Elixir and Rust exist
    When I search for "pattern matching AND Elixir"
    Then only Elixir Zettels are returned
    When I search for "pattern matching NOT Elixir"
    Then only non-Elixir Zettels are returned

  Scenario: Filter by metadata
    Given Zettels with different clusters exist
    When I search for "architecture" filtered by cluster "Design"
    Then only Design cluster results appear
```

#### API Contract

```yaml
# GET /api/search?q=query&cluster=X&level=Y&entropy_max=0.5&limit=20&offset=0
Response:
  200 OK:
    - zettel:
        id: uuid
        title: string
        content: string (truncated)
        tags: string[]
        entropy: float
        cluster: string
      score: float (FTS5 rank)
      highlights:
        - field: title|content|tags
          snippet: string (with <mark> tags)
      match_type: title|content|tags|all
```

#### FTS5 Query Examples

```sql
-- Basic search
SELECT z.*,
       highlight(holons_fts, 0, '<mark>', '</mark>') as title_hl,
       highlight(holons_fts, 1, '<mark>', '</mark>') as content_hl,
       rank
FROM holons_fts
JOIN holons z ON holons_fts.rowid = z.rowid
WHERE holons_fts MATCH 'functional programming'
ORDER BY rank
LIMIT 20;

-- Boolean AND
WHERE holons_fts MATCH 'pattern AND matching AND elixir'

-- Boolean OR
WHERE holons_fts MATCH 'elixir OR rust'

-- Boolean NOT
WHERE holons_fts MATCH 'pattern matching NOT elixir'

-- Phrase search
WHERE holons_fts MATCH '"pattern matching"'

-- Prefix search
WHERE holons_fts MATCH 'func*'
```

---

## 2. Graph Visualization

### Feature: F-GRAPH-001 - Interactive Knowledge Graph

#### User Stories

```gherkin
Feature: Knowledge Graph Visualization
  As a knowledge worker
  I want to visualize my Zettels as an interactive graph
  So that I can understand connections and discover patterns

  Scenario: Load and display graph
    Given 500 Zettels with 1000 links exist
    When I navigate to Graph View
    Then nodes appear with force-directed layout
    And edges show connections
    And rendering completes in < 500ms

  Scenario: Navigate graph
    Given the graph is displayed
    When I scroll to zoom in/out
    And I drag to pan
    And I drag a node
    Then the graph responds smoothly at 60fps

  Scenario: Select node and view details
    Given the graph is displayed
    When I click on a node
    Then the node is highlighted
    And a sidebar shows Zettel preview
    And connected nodes are highlighted
```

#### Cytoscape.js Configuration

```javascript
// Graph style configuration
const graphStyle = [
  {
    selector: 'node',
    style: {
      'label': 'data(label)',
      'width': 'mapData(size, 1, 4, 20, 60)',
      'height': 'mapData(size, 1, 4, 20, 60)',
      'background-color': 'data(color)',
      'border-width': 2,
      'border-color': '#333',
      'font-size': 12,
      'text-wrap': 'ellipsis',
      'text-max-width': 100
    }
  },
  {
    selector: 'node:selected',
    style: {
      'border-width': 4,
      'border-color': '#0066cc',
      'background-color': '#e6f0ff'
    }
  },
  {
    selector: 'edge',
    style: {
      'width': 'mapData(weight, 0, 1, 1, 5)',
      'line-color': '#999',
      'target-arrow-color': '#999',
      'target-arrow-shape': 'triangle',
      'curve-style': 'bezier'
    }
  },
  {
    selector: 'edge.semantic',
    style: {
      'line-style': 'dashed',
      'line-color': '#9966ff'
    }
  }
];

// Layout configuration
const layoutConfig = {
  name: 'cose',
  animate: true,
  animationDuration: 500,
  nodeRepulsion: 8000,
  idealEdgeLength: 100,
  edgeElasticity: 100,
  nestingFactor: 5,
  gravity: 80,
  numIter: 1000,
  padding: 30
};

// Entropy to color mapping
function entropyToColor(entropy) {
  if (entropy < 0.3) return '#22c55e';  // Green (fresh)
  if (entropy < 0.5) return '#84cc16';  // Lime
  if (entropy < 0.7) return '#eab308';  // Yellow (aging)
  if (entropy < 0.85) return '#f97316'; // Orange (stale)
  return '#ef4444';                      // Red (rotting)
}

// Level to size mapping
function levelToSize(level) {
  switch (level) {
    case 'atomic': return 1;
    case 'molecular': return 2;
    case 'organism': return 3;
    case 'ecosystem': return 4;
    default: return 1;
  }
}
```

#### API Contract

```yaml
# GET /api/graph?cluster=X&min_links=2&max_entropy=0.8
Response:
  200 OK:
    nodes:
      - id: uuid
        label: string (title truncated)
        entropy: float
        level: string
        cluster: string
        size: integer (based on level)
        color: string (hex, based on entropy)
        link_count: integer
    edges:
      - id: string
        source: uuid
        target: uuid
        link_type: wiki|semantic|code|backlink
        weight: float
    metadata:
      total_nodes: integer
      total_edges: integer
      clusters: string[]
      entropy_distribution:
        fresh: integer
        aging: integer
        rotting: integer
```

---

### Feature: F-GRAPH-002 - Local Graph (Ego Network)

#### User Stories

```gherkin
Feature: Local Graph View
  As a knowledge worker
  I want to see the immediate neighborhood of a Zettel
  So that I can understand its context and connections

  Scenario: View 1-hop neighborhood
    Given Zettel A has 10 direct connections
    When I select "Show Local Graph" for Zettel A
    Then Zettel A is centered
    And all 10 connected Zettels are shown
    And edges are clearly visible

  Scenario: Expand to 2-hop
    Given the local graph is displayed
    When I increase depth to 2
    Then 2nd-degree connections appear
    And they are visually distinguished (lighter color)
```

#### API Contract

```yaml
# GET /api/graph/local/:id?depth=2
Response:
  200 OK:
    center_node: uuid
    depth: integer
    nodes:
      - id: uuid
        label: string
        distance: integer (0 = center, 1 = 1-hop, etc.)
        ...
    edges: [...]
```

---

## 3. AI-Powered Features

### Feature: F-AI-001 - Semantic Search

#### User Stories

```gherkin
Feature: Semantic Search
  As a knowledge worker
  I want to search by meaning, not just keywords
  So that I can find conceptually related Zettels

  Scenario: Find related content by meaning
    Given I have Zettels about "machine learning"
    When I search "how computers learn from data"
    Then Zettels about machine learning appear
    Even if they don't contain "computers" or "data"

  Scenario: Fallback to FTS on vector unavailable
    Given vector embeddings are not generated
    When I perform semantic search
    Then the system falls back to FTS
    And a notice indicates "keyword search mode"
```

#### API Contract

```yaml
# POST /api/search/vector
Request:
  query: string (natural language)
  limit: integer (default: 10)
  min_score: float (default: 0.7)
  include_fts_fallback: boolean (default: true)

Response:
  200 OK:
    mode: vector|fts_fallback
    results:
      - zettel: ZettelObject
        score: float (cosine similarity)
        key_concepts: string[] (why it matched)
```

#### Implementation Notes

```elixir
# Vector embedding via OpenRouter (Claude)
def generate_embedding(text) do
  # Use Claude to generate semantic representation
  # Store in separate embeddings table
  # Use cosine similarity for search
end

# Semantic search with fallback
def semantic_search(query, opts \\ []) do
  case get_query_embedding(query) do
    {:ok, embedding} ->
      results = vector_similarity_search(embedding, opts)
      {:ok, :vector, results}

    {:error, _} ->
      # Fallback to FTS
      results = fts_search(query, opts)
      {:ok, :fts_fallback, results}
  end
end
```

---

### Feature: F-AI-002 - Auto-Linking Suggestions

#### User Stories

```gherkin
Feature: AI-Powered Link Suggestions
  As a knowledge worker
  I want the system to suggest relevant links
  So that I can discover connections I might have missed

  Scenario: Receive link suggestions
    Given I have 100 Zettels
    And some are semantically related but not linked
    When the system runs link analysis
    Then I receive suggestions like:
      "Zettel A seems related to Zettel B (85% similarity)"
    And I can accept or dismiss each suggestion

  Scenario: Bulk accept suggestions
    Given I have 20 pending link suggestions
    When I review and select 15 good ones
    And click "Accept Selected"
    Then 15 semantic edges are created
    And the graph is updated
```

#### API Contract

```yaml
# GET /api/suggestions/links?limit=20
Response:
  200 OK:
    suggestions:
      - source_id: uuid
        source_title: string
        target_id: uuid
        target_title: string
        similarity: float
        reason: string (e.g., "shared concepts: X, Y, Z")
        suggested_at: ISO8601

# POST /api/suggestions/links/accept
Request:
  suggestions:
    - source_id: uuid
      target_id: uuid

Response:
  201 Created:
    accepted: integer
    edges_created: integer
```

---

## 4. Entropy & Freshness

### Feature: F-ENTROPY-001 - Entropy Dashboard

#### User Stories

```gherkin
Feature: Knowledge Freshness Dashboard
  As a knowledge worker
  I want to see which Zettels need review
  So that I can maintain fresh, accurate knowledge

  Scenario: View entropy distribution
    Given I have 500 Zettels
    When I open the Entropy Dashboard
    Then I see:
      - Pie chart: Fresh (30%), Aging (45%), Rotting (25%)
      - List of top 20 "rotting" Zettels
      - Entropy trend over time (improving/declining)

  Scenario: Reset entropy on update
    Given a Zettel has entropy 0.8 (rotting)
    When I edit and save the Zettel
    Then entropy resets to 0.1 (fresh)
    And verified_at is updated
```

#### API Contract

```yaml
# GET /api/metrics/entropy
Response:
  200 OK:
    total_zettels: integer
    average_entropy: float
    fresh_count: integer (entropy < 0.3)
    aging_count: integer (0.3 <= entropy < 0.7)
    rotting_count: integer (entropy >= 0.7)
    by_cluster:
      - cluster: string
        count: integer
        avg_entropy: float
    top_rotting:
      - id: uuid
        title: string
        entropy: float
        days_since_update: integer
    trend:
      - date: ISO8601
        avg_entropy: float
```

#### Entropy Calculation

```elixir
# Entropy increases with age
# decay_rate affects speed: slow=0.01/day, medium=0.02/day, fast=0.05/day
def calculate_entropy(zettel) do
  days_since_update = DateTime.diff(DateTime.utc_now(), zettel.updated_at, :day)

  rate = case zettel.decay_rate do
    "slow" -> 0.01
    "medium" -> 0.02
    "fast" -> 0.05
  end

  base_entropy = min(1.0, days_since_update * rate)

  # Boost entropy if no backlinks (orphan)
  backlink_count = count_backlinks(zettel.id)
  orphan_penalty = if backlink_count == 0, do: 0.1, else: 0.0

  min(1.0, base_entropy + orphan_penalty)
end

# Entropy thresholds
@fresh_threshold 0.3
@aging_threshold 0.7
@rotting_threshold 0.7

def entropy_label(entropy) do
  cond do
    entropy < @fresh_threshold -> :fresh
    entropy < @rotting_threshold -> :aging
    true -> :rotting
  end
end
```

---

## 5. Import/Export

### Feature: F-IMPORT-001 - Obsidian Vault Import

#### User Stories

```gherkin
Feature: Import Obsidian Vault
  As a knowledge worker migrating from Obsidian
  I want to import my existing vault
  So that I can use Z-KMS without losing my data

  Scenario: Import vault with links
    Given I have an Obsidian vault with 500 notes
    When I select the vault folder and click Import
    Then all notes are created as Zettels
    And [[wikilinks]] are converted to edges
    And YAML frontmatter becomes metadata
    And import completes in < 30 seconds

  Scenario: Handle attachments
    Given my vault has images and PDFs
    When I import the vault
    Then attachments are uploaded
    And links to attachments are preserved
```

#### API Contract

```yaml
# POST /api/import/obsidian
Request:
  Content-Type: multipart/form-data
  folder: directory (uploaded as zip)
  options:
    preserve_frontmatter: boolean (default: true)
    create_clusters: boolean (default: true, from folder names)
    import_attachments: boolean (default: true)

Response:
  202 Accepted:
    job_id: uuid
    status_url: /api/import/status/:job_id

# GET /api/import/status/:job_id
Response:
  200 OK:
    status: pending|processing|completed|failed
    progress:
      total_files: integer
      processed: integer
      created: integer
      failed: integer
      errors: string[]
```

#### Import Processing

```elixir
defmodule SmritiImporter do
  def import_obsidian_vault(folder_path, opts) do
    folder_path
    |> list_markdown_files()
    |> Enum.map(&parse_obsidian_file/1)
    |> Enum.map(&create_zettel_from_obsidian/1)
    |> Enum.map(&extract_and_create_edges/1)
  end

  defp parse_obsidian_file(path) do
    content = File.read!(path)

    {frontmatter, body} = extract_frontmatter(content)
    links = extract_wikilinks(body)

    %{
      path: path,
      title: frontmatter["title"] || Path.basename(path, ".md"),
      content: body,
      tags: frontmatter["tags"] || [],
      links: links,
      cluster: folder_to_cluster(path)
    }
  end

  defp extract_wikilinks(content) do
    ~r/\[\[([^\]|]+)(?:\|[^\]]+)?\]\]/
    |> Regex.scan(content)
    |> Enum.map(fn [_, target] -> target end)
  end
end
```

---

## 6. MCP Integration for AI Agents

### Feature: F-MCP-001 - Model Context Protocol

#### User Stories

```gherkin
Feature: MCP Endpoints for AI Agents
  As an AI agent (Claude, Gemini)
  I want to access Z-KMS via MCP
  So that I can provide knowledge-enhanced responses

  Scenario: Read Zettel context
    Given an AI agent needs knowledge about "STAMP constraints"
    When it calls /mcp/read_zettel with topic
    Then it receives relevant Zettel content
    And backlink context for understanding connections

  Scenario: Search for context
    Given an AI agent needs to answer a question
    When it calls /mcp/search with the question
    Then it receives top 10 relevant Zettels
    And can use them as context for response
```

#### API Contract (MCP Compliant)

```yaml
# GET /mcp/read_zettel/:id
Response:
  200 OK:
    content: string (full markdown)
    metadata:
      title: string
      tags: string[]
      entropy: float
      level: string
      cluster: string
    context:
      backlinks:
        - title: string
          snippet: string
      related:
        - title: string
          score: float

# GET /mcp/search?q=query&limit=10
Response:
  200 OK:
    results:
      - title: string
        content: string (truncated to 500 chars)
        score: float
        tags: string[]
```

---

## Implementation Priority

### Phase 1 (MVP) - Core Functionality
- [ ] F-CORE-001: Zettel CRUD
- [ ] F-CORE-002: Bi-Directional Linking
- [ ] F-CORE-003: Full-Text Search
- [ ] F-GRAPH-001: Interactive Graph
- [ ] F-ENTROPY-001: Entropy Dashboard

### Phase 2 - Enhanced Features
- [ ] F-GRAPH-002: Local Graph
- [ ] F-AI-001: Semantic Search
- [ ] F-IMPORT-001: Obsidian Import
- [ ] F-MCP-001: MCP Integration

### Phase 3 - AI Features
- [ ] F-AI-002: Auto-Linking
- [ ] F-AI-003: Summarization
- [ ] F-AI-004: Tag Suggestions

### Phase 4 - Collaboration
- [ ] Canvas/Whiteboard
- [ ] Citation Management
- [ ] Spaced Repetition
- [ ] Mobile Access

---

## STAMP Constraints (Features)

| ID | Constraint | Features |
|----|------------|----------|
| SC-FEAT-001 | CRUD operations < 100ms | F-CORE-001 |
| SC-FEAT-002 | Search < 500ms | F-CORE-003, F-AI-001 |
| SC-FEAT-003 | Graph render < 500ms for 1K nodes | F-GRAPH-001 |
| SC-FEAT-004 | Import 10K files < 5 min | F-IMPORT-001 |
| SC-FEAT-005 | Entropy calculation accurate | F-ENTROPY-001 |
| SC-FEAT-006 | MCP response < 200ms | F-MCP-001 |

---

## Related Documents

- `docs/kms/SMRITI_COMPREHENSIVE_USECASES.md` - Use Cases
- `scripts/smriti/schema.sql` - Database Schema
- `lib/cepaf/src/Cepaf.Smriti.Api/Routes.fs` - API Routes
