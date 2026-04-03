Feature: SMRITI API Routes (WS4)
  As a client application or MCP tool
  I want to interact with the SMRITI API
  So that I can manage zettels, explore the knowledge graph, and search content

  Background:
    Given the Indrajaal application is running on port 4000
    And the database has the following zettels:
      | id | title | content | tags | created_at | updated_at |
      | z001 | Functional Programming | FP emphasizes immutability | ["elixir", "fp"] | 2026-01-01T10:00:00Z | 2026-01-01T10:00:00Z |
      | z002 | Pattern Matching | Powerful feature in Elixir | ["elixir"] | 2026-01-02T11:00:00Z | 2026-01-05T15:00:00Z |
      | z003 | BEAM VM | Erlang runtime | ["erlang", "vm"] | 2026-01-03T12:00:00Z | 2026-01-03T12:00:00Z |
      | z004 | OTP Design Patterns | GenServer, Supervisor | ["otp", "erlang"] | 2026-01-04T13:00:00Z | 2025-12-01T09:00:00Z |
    And the following connections exist:
      | from_id | to_id | connection_type |
      | z002 | z001 | references |
      | z003 | z001 | relates_to |
      | z004 | z003 | extends |

  # ========================================================================
  # Scenario 1: GET /api/zettels - List all zettels with pagination
  # ========================================================================
  Scenario: List all zettels with default pagination
    When I send a GET request to "/api/zettels"
    Then the response status code should be 200
    And the response should have the following JSON structure:
      """
      {
        "zettels": [
          {
            "id": "z004",
            "title": "OTP Design Patterns",
            "content": "GenServer, Supervisor",
            "tags": ["otp", "erlang"],
            "created_at": "2026-01-04T13:00:00Z",
            "updated_at": "2025-12-01T09:00:00Z",
            "backlink_count": 0,
            "forward_link_count": 1
          }
        ],
        "pagination": {
          "page": 1,
          "page_size": 20,
          "total_count": 4,
          "total_pages": 1
        }
      }
      """
    And the "zettels" array should have 4 items
    And each zettel should have the required fields: "id, title, content, tags, created_at, updated_at"

  Scenario: List zettels with custom pagination
    When I send a GET request to "/api/zettels?page=1&page_size=2"
    Then the response status code should be 200
    And the "pagination.page" should be 1
    And the "pagination.page_size" should be 2
    And the "pagination.total_count" should be 4
    And the "pagination.total_pages" should be 2
    And the "zettels" array should have 2 items

  Scenario: List zettels with sorting
    When I send a GET request to "/api/zettels?sort_by=updated_at&sort_order=asc"
    Then the response status code should be 200
    And the first zettel in "zettels" should have "id" equal to "z004"
    And the last zettel in "zettels" should have "id" equal to "z002"

  Scenario: List zettels with tag filter
    When I send a GET request to "/api/zettels?tags=elixir"
    Then the response status code should be 200
    And the "zettels" array should have 2 items
    And all zettels should have "elixir" in their "tags" array

  Scenario: List zettels with invalid page number
    When I send a GET request to "/api/zettels?page=-1"
    Then the response status code should be 400
    And the response should contain:
      """
      {
        "error": "Invalid pagination parameters",
        "details": {
          "page": "must be a positive integer"
        }
      }
      """

  # ========================================================================
  # Scenario 2: GET /api/zettels/{id} - Get single zettel
  # ========================================================================
  Scenario: Get a specific zettel by ID
    When I send a GET request to "/api/zettels/z001"
    Then the response status code should be 200
    And the response should have the following JSON structure:
      """
      {
        "id": "z001",
        "title": "Functional Programming",
        "content": "FP emphasizes immutability",
        "tags": ["elixir", "fp"],
        "created_at": "2026-01-01T10:00:00Z",
        "updated_at": "2026-01-01T10:00:00Z",
        "backlinks": [
          {"id": "z002", "title": "Pattern Matching", "connection_type": "references"},
          {"id": "z003", "title": "BEAM VM", "connection_type": "relates_to"}
        ],
        "forward_links": [],
        "metadata": {
          "word_count": 3,
          "read_time_minutes": 1,
          "last_accessed": null
        }
      }
      """
    And the "backlinks" array should have 2 items

  Scenario: Get a zettel with forward links
    When I send a GET request to "/api/zettels/z002"
    Then the response status code should be 200
    And the "forward_links" array should have 1 item
    And the first item in "forward_links" should have "id" equal to "z001"

  Scenario: Get non-existent zettel
    When I send a GET request to "/api/zettels/z999"
    Then the response status code should be 404
    And the response should contain:
      """
      {
        "error": "Zettel not found",
        "zettel_id": "z999"
      }
      """

  Scenario: Get zettel with malformed ID
    When I send a GET request to "/api/zettels/<script>alert(1)</script>"
    Then the response status code should be 400
    And the response should contain:
      """
      {
        "error": "Invalid zettel ID format",
        "details": "Zettel ID must match pattern: ^z[0-9]{3,}$"
      }
      """

  # ========================================================================
  # Scenario 3: GET /api/zettels/{id}/backlinks - Get backlinks
  # ========================================================================
  Scenario: Get backlinks for a zettel
    When I send a GET request to "/api/zettels/z001/backlinks"
    Then the response status code should be 200
    And the response should have the following JSON structure:
      """
      {
        "zettel_id": "z001",
        "backlinks": [
          {
            "id": "z002",
            "title": "Pattern Matching",
            "connection_type": "references",
            "created_at": "2026-01-02T11:00:00Z"
          },
          {
            "id": "z003",
            "title": "BEAM VM",
            "connection_type": "relates_to",
            "created_at": "2026-01-03T12:00:00Z"
          }
        ],
        "count": 2
      }
      """
    And the "backlinks" array should have 2 items

  Scenario: Get backlinks for zettel with no backlinks
    When I send a GET request to "/api/zettels/z004/backlinks"
    Then the response status code should be 200
    And the "backlinks" array should be empty
    And the "count" should be 0

  Scenario: Get backlinks with connection type filter
    When I send a GET request to "/api/zettels/z001/backlinks?type=references"
    Then the response status code should be 200
    And the "backlinks" array should have 1 item
    And all backlinks should have "connection_type" equal to "references"

  # ========================================================================
  # Scenario 4: GET /api/graph - Full graph data for Cytoscape
  # ========================================================================
  Scenario: Get full knowledge graph
    When I send a GET request to "/api/graph"
    Then the response status code should be 200
    And the response should have the following JSON structure:
      """
      {
        "nodes": [
          {
            "data": {
              "id": "z001",
              "label": "Functional Programming",
              "tags": ["elixir", "fp"],
              "backlink_count": 2,
              "forward_link_count": 0,
              "centrality": 0.75
            }
          }
        ],
        "edges": [
          {
            "data": {
              "id": "e_z002_z001",
              "source": "z002",
              "target": "z001",
              "label": "references",
              "weight": 1.0
            }
          }
        ],
        "metadata": {
          "node_count": 4,
          "edge_count": 3,
          "density": 0.5,
          "avg_degree": 1.5
        }
      }
      """
    And the "nodes" array should have 4 items
    And the "edges" array should have 3 items

  Scenario: Get graph with cluster information
    When I send a GET request to "/api/graph?include_clusters=true"
    Then the response status code should be 200
    And the response should include "clusters" array
    And each cluster should have fields: "id, name, node_ids, color"

  Scenario: Get graph with layout coordinates
    When I send a GET request to "/api/graph?layout=force_directed"
    Then the response status code should be 200
    And each node in "nodes" should have "position" with "x" and "y" coordinates

  # ========================================================================
  # Scenario 5: GET /api/graph/cluster/{name} - Cluster subgraph
  # ========================================================================
  Scenario: Get cluster subgraph by name
    Given the graph has a cluster named "Elixir Ecosystem"
    When I send a GET request to "/api/graph/cluster/Elixir Ecosystem"
    Then the response status code should be 200
    And the response should have the following JSON structure:
      """
      {
        "cluster": {
          "id": "cluster_001",
          "name": "Elixir Ecosystem",
          "color": "#4B5563",
          "node_count": 2
        },
        "nodes": [
          {"data": {"id": "z001", "label": "Functional Programming"}},
          {"data": {"id": "z002", "label": "Pattern Matching"}}
        ],
        "edges": [
          {"data": {"id": "e_z002_z001", "source": "z002", "target": "z001"}}
        ],
        "metadata": {
          "density": 0.5,
          "avg_clustering_coefficient": 0.33
        }
      }
      """

  Scenario: Get cluster that doesn't exist
    When I send a GET request to "/api/graph/cluster/NonExistent"
    Then the response status code should be 404
    And the response should contain:
      """
      {
        "error": "Cluster not found",
        "cluster_name": "NonExistent"
      }
      """

  Scenario: Get empty cluster
    Given the graph has an empty cluster named "Empty Cluster"
    When I send a GET request to "/api/graph/cluster/Empty Cluster"
    Then the response status code should be 200
    And the "nodes" array should be empty
    And the "edges" array should be empty
    And the "cluster.node_count" should be 0

  # ========================================================================
  # Scenario 6: GET /api/search?q=... - Full-text search
  # ========================================================================
  Scenario: Search zettels by keyword
    When I send a GET request to "/api/search?q=Elixir"
    Then the response status code should be 200
    And the response should have the following JSON structure:
      """
      {
        "query": "Elixir",
        "results": [
          {
            "id": "z002",
            "title": "Pattern Matching",
            "content": "Powerful feature in Elixir",
            "score": 0.95,
            "highlights": [
              "Powerful feature in <mark>Elixir</mark>"
            ]
          }
        ],
        "count": 2,
        "search_time_ms": 15
      }
      """
    And the "results" array should have 2 items
    And each result should have "score" greater than 0

  Scenario: Search with multiple keywords
    When I send a GET request to "/api/search?q=Elixir+pattern"
    Then the response status code should be 200
    And the "results" array should not be empty
    And the first result should have the highest "score"

  Scenario: Search with filters
    When I send a GET request to "/api/search?q=programming&tags=fp&created_after=2025-12-31"
    Then the response status code should be 200
    And all results should have "fp" in their "tags" array
    And all results should have "created_at" after "2025-12-31"

  Scenario: Search with no results
    When I send a GET request to "/api/search?q=quantum_computing"
    Then the response status code should be 200
    And the "results" array should be empty
    And the "count" should be 0

  Scenario: Search with empty query
    When I send a GET request to "/api/search?q="
    Then the response status code should be 400
    And the response should contain:
      """
      {
        "error": "Query parameter 'q' is required and cannot be empty"
      }
      """

  # ========================================================================
  # Scenario 7: POST /api/search/vector - Vector similarity search
  # ========================================================================
  Scenario: Vector similarity search by embedding
    When I send a POST request to "/api/search/vector" with JSON:
      """
      {
        "embedding": [0.1, 0.2, 0.3, ..., 0.768],
        "top_k": 5,
        "threshold": 0.7
      }
      """
    Then the response status code should be 200
    And the response should have the following JSON structure:
      """
      {
        "results": [
          {
            "id": "z001",
            "title": "Functional Programming",
            "similarity": 0.92,
            "distance": 0.08
          }
        ],
        "count": 5,
        "search_time_ms": 8
      }
      """
    And the "results" array should have at most 5 items
    And all results should have "similarity" >= 0.7
    And the results should be sorted by "similarity" in descending order

  Scenario: Vector search by zettel ID
    When I send a POST request to "/api/search/vector" with JSON:
      """
      {
        "zettel_id": "z001",
        "top_k": 3
      }
      """
    Then the response status code should be 200
    And the "results" array should not include zettel "z001" (self)
    And the "results" array should have at most 3 items

  Scenario: Vector search with invalid embedding dimension
    When I send a POST request to "/api/search/vector" with JSON:
      """
      {
        "embedding": [0.1, 0.2],
        "top_k": 5
      }
      """
    Then the response status code should be 400
    And the response should contain:
      """
      {
        "error": "Invalid embedding dimension",
        "expected": 768,
        "received": 2
      }
      """

  Scenario: Vector search with missing required fields
    When I send a POST request to "/api/search/vector" with JSON:
      """
      {
        "top_k": 5
      }
      """
    Then the response status code should be 400
    And the response should contain:
      """
      {
        "error": "Either 'embedding' or 'zettel_id' is required"
      }
      """

  # ========================================================================
  # Scenario 8: GET /api/metrics/entropy - Top rotting zettels
  # ========================================================================
  Scenario: Get top rotting zettels (high entropy)
    When I send a GET request to "/api/metrics/entropy"
    Then the response status code should be 200
    And the response should have the following JSON structure:
      """
      {
        "zettels": [
          {
            "id": "z004",
            "title": "OTP Design Patterns",
            "entropy_score": 0.85,
            "days_since_update": 41,
            "backlink_count": 0,
            "forward_link_count": 1,
            "isolation_risk": "high"
          }
        ],
        "count": 4,
        "threshold": 0.5
      }
      """
    And the "zettels" array should be sorted by "entropy_score" in descending order
    And all zettels should have "entropy_score" > 0.5

  Scenario: Get rotting zettels with custom threshold
    When I send a GET request to "/api/metrics/entropy?threshold=0.8&limit=10"
    Then the response status code should be 200
    And all zettels should have "entropy_score" >= 0.8
    And the "zettels" array should have at most 10 items

  Scenario: Get rotting zettels with zero entropy (recently updated)
    When I send a GET request to "/api/metrics/entropy?threshold=0.0&limit=100"
    Then the response status code should be 200
    And the response should include all 4 zettels

  Scenario: Get entropy metrics with invalid threshold
    When I send a GET request to "/api/metrics/entropy?threshold=1.5"
    Then the response status code should be 400
    And the response should contain:
      """
      {
        "error": "Threshold must be between 0.0 and 1.0",
        "received": 1.5
      }
      """

  # ========================================================================
  # Scenario 9: MCP endpoints (/mcp/read_zettel, /mcp/search)
  # ========================================================================
  Scenario: MCP - Read zettel tool
    When I send a POST request to "/api/mcp/tools/read_zettel" with JSON:
      """
      {
        "arguments": {
          "zettel_id": "z001"
        }
      }
      """
    Then the response status code should be 200
    And the response should have the following JSON structure:
      """
      {
        "content": [
          {
            "type": "text",
            "text": "# Functional Programming\n\nFP emphasizes immutability\n\n**Tags**: elixir, fp\n**Created**: 2026-01-01T10:00:00Z\n**Updated**: 2026-01-01T10:00:00Z"
          }
        ]
      }
      """

  Scenario: MCP - Search zettels tool
    When I send a POST request to "/api/mcp/tools/search_zettels" with JSON:
      """
      {
        "arguments": {
          "query": "pattern matching",
          "max_results": 5
        }
      }
      """
    Then the response status code should be 200
    And the response should have the following JSON structure:
      """
      {
        "content": [
          {
            "type": "text",
            "text": "Found 1 zettel(s):\n\n1. **Pattern Matching** (z002)\n   Powerful feature in Elixir\n   Score: 0.95"
          }
        ]
      }
      """

  Scenario: MCP - Create zettel tool
    When I send a POST request to "/api/mcp/tools/create_zettel" with JSON:
      """
      {
        "arguments": {
          "title": "New Zettel",
          "content": "This is a new zettel",
          "tags": ["test", "mcp"]
        }
      }
      """
    Then the response status code should be 201
    And the response should contain:
      """
      {
        "content": [
          {
            "type": "text",
            "text": "Zettel created successfully with ID: z005"
          }
        ]
      }
      """

  Scenario: MCP - Update zettel tool
    When I send a POST request to "/api/mcp/tools/update_zettel" with JSON:
      """
      {
        "arguments": {
          "zettel_id": "z001",
          "title": "Functional Programming Updated",
          "content": "Updated content"
        }
      }
      """
    Then the response status code should be 200
    And the response should contain "Zettel z001 updated successfully"

  Scenario: MCP - Delete zettel tool
    When I send a POST request to "/api/mcp/tools/delete_zettel" with JSON:
      """
      {
        "arguments": {
          "zettel_id": "z004"
        }
      }
      """
    Then the response status code should be 200
    And the response should contain "Zettel z004 deleted successfully"

  Scenario: MCP - Link zettels tool
    When I send a POST request to "/api/mcp/tools/link_zettels" with JSON:
      """
      {
        "arguments": {
          "from_id": "z001",
          "to_id": "z004",
          "connection_type": "extends"
        }
      }
      """
    Then the response status code should be 201
    And the response should contain "Link created from z001 to z004"

  Scenario: MCP - Get graph tool
    When I send a POST request to "/api/mcp/tools/get_graph" with JSON:
      """
      {
        "arguments": {
          "include_clusters": true
        }
      }
      """
    Then the response status code should be 200
    And the response should include graph data with nodes and edges

  Scenario: MCP - Invalid tool name
    When I send a POST request to "/api/mcp/tools/invalid_tool" with JSON:
      """
      {
        "arguments": {}
      }
      """
    Then the response status code should be 404
    And the response should contain:
      """
      {
        "error": "Tool not found",
        "available_tools": [
          "read_zettel",
          "search_zettels",
          "create_zettel",
          "update_zettel",
          "delete_zettel",
          "link_zettels",
          "get_graph"
        ]
      }
      """

  Scenario: MCP - Missing required arguments
    When I send a POST request to "/api/mcp/tools/read_zettel" with JSON:
      """
      {
        "arguments": {}
      }
      """
    Then the response status code should be 400
    And the response should contain:
      """
      {
        "error": "Missing required argument: zettel_id"
      }
      """

  # ========================================================================
  # Security & Performance Tests
  # ========================================================================
  Scenario: Rate limiting on search endpoint
    Given I have made 100 search requests in the last minute
    When I send a GET request to "/api/search?q=test"
    Then the response status code should be 429
    And the response should contain:
      """
      {
        "error": "Rate limit exceeded",
        "retry_after_seconds": 60
      }
      """

  Scenario: SQL injection prevention
    When I send a GET request to "/api/zettels?tags='; DROP TABLE zettels; --"
    Then the response status code should be 400
    And the database should still have all 4 zettels

  Scenario: XSS prevention in search
    When I send a GET request to "/api/search?q=<script>alert('xss')</script>"
    Then the response status code should be 200
    And the response should not contain unescaped script tags
    And the "highlights" should have HTML entities escaped

  Scenario: Large result set pagination
    Given the database has 1000 zettels
    When I send a GET request to "/api/zettels?page_size=1000"
    Then the response status code should be 400
    And the response should contain:
      """
      {
        "error": "Page size exceeds maximum allowed value of 100"
      }
      """

  Scenario: Concurrent requests handling
    When I send 10 concurrent GET requests to "/api/graph"
    Then all responses should have status code 200
    And all responses should return identical graph data
    And the average response time should be less than 500ms

  # ========================================================================
  # STAMP Compliance Verification
  # ========================================================================
  @stamp
  Scenario: Verify SC-API-001 compliance - Response time < 50ms
    When I send a GET request to "/api/zettels/z001"
    Then the response should be received within 50 milliseconds
    And the response header "X-Response-Time" should be present

  @stamp
  Scenario: Verify SC-PRAJNA-004 compliance - Sentinel sync
    When I send a GET request to "/api/metrics/entropy"
    Then the system should sync with Sentinel within 30 seconds
    And the Immutable Register should log the query

  @stamp
  Scenario: Verify SC-ZENOH-001 compliance - Telemetry publishing
    When I send a POST request to "/api/mcp/tools/create_zettel"
    Then a Zenoh telemetry event should be published to "indrajaal/smriti/create"
    And the event should include zettel metadata

  @stamp
  Scenario: Verify SC-CHG-010 compliance - Change logging
    When I send a POST request to "/api/mcp/tools/update_zettel"
    Then the change should be logged to the Immutable Register
    And the log entry should include change ID, timestamp, and author
