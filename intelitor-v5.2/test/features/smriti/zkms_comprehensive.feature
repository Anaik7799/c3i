# SMRITI - Zettelkasten Knowledge Management System
# Comprehensive BDD Test Suite - 8-Level Fractal Coverage
# SC-BDD-001 to SC-BDD-012 Compliance

@smriti @fractal @sil4
Feature: SMRITI Zettelkasten Knowledge Management System
  As a knowledge engineer
  I want to manage interconnected knowledge atoms (Zettels)
  So that I can build an emergent intelligence substrate

  Background:
    Given the SMRITI database exists at "data/kms/smriti.db"
    And the SQLite FTS5 index is enabled
    And the holon hierarchy is configured

  # ============================================================================
  # LEVEL 1: FUNCTION (L0 Runtime Primitives)
  # ============================================================================

  @l1-function @unit
  Scenario: SHA-256 content hashing produces consistent results
    Given a document with content "Test content for hashing"
    When I compute the content hash
    Then the hash should be a 64-character hexadecimal string
    And the same content should always produce the same hash

  @l1-function @unit
  Scenario: UUID generation produces valid identifiers
    When I generate a new holon UUID
    Then the UUID should match the pattern "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
    And each generated UUID should be unique

  @l1-function @unit
  Scenario: Entropy calculation follows decay model
    Given a holon created 90 days ago
    When I calculate its entropy
    Then the entropy should be approximately 0.5
    And entropy should be capped at 1.0

  # ============================================================================
  # LEVEL 2: COMPONENT (Module Integration)
  # ============================================================================

  @l2-component @integration
  Scenario: Ingestor extracts metadata from markdown documents
    Given a markdown file "test_doc.md" with content:
      """
      # Test Document Title

      This is the summary of the document.

      ## Section 1
      Content with technical details.
      """
    When I ingest the document into cluster "test_cluster"
    Then a holon should be created with title "Test Document Title"
    And the holon should have entropy based on file age
    And the content hash should be stored for deduplication

  @l2-component @integration
  Scenario: FTS5 search returns relevant results
    Given the following holons exist:
      | title                    | content                          | cluster |
      | Alarm Processing Guide   | How to process security alarms   | alarms  |
      | Device Configuration     | Setting up IoT devices           | devices |
      | Alarm Correlation Engine | Correlating multiple alarms      | alarms  |
    When I search for "alarm"
    Then the results should contain "Alarm Processing Guide"
    And the results should contain "Alarm Correlation Engine"
    And the results should be ordered by BM25 relevance

  @l2-component @integration
  Scenario: Duplicate detection prevents redundant ingestion
    Given a document "original.md" has been ingested
    When I attempt to ingest the same content again
    Then the ingestion should be skipped
    And the skip reason should indicate "duplicate hash"

  # ============================================================================
  # LEVEL 3: HOLON (Agent/Domain Logic)
  # ============================================================================

  @l3-holon @domain
  Scenario: Holon hierarchy classifies by content size
    Given documents of varying sizes:
      | file      | size_bytes |
      | small.md  | 500        |
      | medium.md | 5000       |
      | large.md  | 15000      |
    When I ingest all documents
    Then "small.md" should have level "atomic"
    And "medium.md" should have level "molecular"
    And "large.md" should have level "organism"

  @l3-holon @domain
  Scenario: Orphan detection identifies unlinked holons
    Given the following holons exist without edges:
      | holon_uuid                           | title           |
      | 550e8400-e29b-41d4-a716-446655440001 | Orphan Document |
      | 550e8400-e29b-41d4-a716-446655440002 | Linked Document |
    And an edge exists from "550e8400-e29b-41d4-a716-446655440002" to "550e8400-e29b-41d4-a716-446655440003"
    When I query for orphan holons
    Then the result should contain "Orphan Document"
    And the result should not contain "Linked Document"

  @l3-holon @domain
  Scenario: Stale holon detection based on entropy threshold
    Given holons with the following entropy values:
      | title     | entropy |
      | Fresh     | 0.1     |
      | Moderate  | 0.5     |
      | Stale     | 0.7     |
      | Decayed   | 0.9     |
    When I query for stale holons with threshold 0.6
    Then the results should contain "Stale" and "Decayed"
    And the results should not contain "Fresh" or "Moderate"

  # ============================================================================
  # LEVEL 4: CONTAINER (Service Boundaries)
  # ============================================================================

  @l4-container @service
  Scenario: CLI provides all required commands
    When I invoke the SMRITI CLI with "help"
    Then the output should list command "status"
    And the output should list command "ingest"
    And the output should list command "search"
    And the output should list command "orphans"
    And the output should list command "stale"
    And the output should list command "entropy"

  @l4-container @service
  Scenario: Status command reports cluster statistics
    Given holons exist across multiple clusters
    When I invoke "smritistatus"
    Then the output should show total holon count
    And the output should show orphan count
    And the output should show stale count
    And the output should list each cluster with its holon count

  @l4-container @service
  Scenario: Ingest command supports batch processing
    Given a directory "batch_test/" with 5 markdown files
    When I invoke "smritiingest batch_test --max 3 --cluster batch"
    Then exactly 3 files should be ingested
    And the summary should show "Ingested: 3"

  # ============================================================================
  # LEVEL 5: EVOLUTIONARY (Long-term Adaptation)
  # ============================================================================

  @l5-evolutionary @adaptation
  Scenario: Entropy recalculation updates all holons
    Given holons with outdated entropy values
    When I invoke the entropy recalculation command
    Then all holon entropy values should reflect current age
    And the update count should be reported

  @l5-evolutionary @adaptation
  Scenario: Knowledge graph grows through continuous ingestion
    Given an initial knowledge base of 50 holons
    When I ingest 10 new documents over time
    Then the total holon count should be 60
    And cluster statistics should reflect the growth
    And orphan detection should identify new isolated holons

  @l5-evolutionary @adaptation
  Scenario: AI extraction enhances metadata when available
    Given the OpenRouter API key is configured
    And a document "complex.md" with technical content
    When I ingest the document with AI extraction
    Then the holon title should be AI-generated
    And the holon should have extracted tags
    And the level should be AI-classified

  # ============================================================================
  # LEVEL 6: CLUSTER (Distributed Coordination)
  # ============================================================================

  @l6-cluster @distributed
  Scenario: Cluster-based organization groups related holons
    Given holons ingested into clusters:
      | cluster       | count |
      | architecture  | 10    |
      | testing       | 15    |
      | operations    | 8     |
    When I query the status
    Then each cluster should show its respective count
    And clusters should be alphabetically ordered

  @l6-cluster @distributed
  Scenario: Cross-cluster search finds holons across boundaries
    Given holons about "deployment" exist in multiple clusters
    When I search for "deployment"
    Then results should include holons from "operations"
    And results should include holons from "infrastructure"

  @l6-cluster @distributed
  Scenario: Cluster isolation prevents namespace collision
    Given two holons with identical titles in different clusters:
      | title        | cluster      |
      | README.md    | architecture |
      | README.md    | testing      |
    Then both holons should exist as separate entities
    And each should have a unique holon_uuid

  # ============================================================================
  # LEVEL 7: FEDERATION (Multi-System Integration)
  # ============================================================================

  @l7-federation @integration
  Scenario: SMRITI integrates with Prajna cockpit
    Given the Prajna cockpit is running
    When the cockpit requests knowledge metrics
    Then SMRITI should provide holon count
    And SMRITI should provide cluster distribution
    And SMRITI should provide orphan/stale statistics

  @l7-federation @integration
  Scenario: SMRITI state persistence survives restarts
    Given a populated SMRITI database
    When the system is restarted
    Then all holons should be preserved
    And all cluster assignments should be intact
    And FTS5 indexes should be queryable

  @l7-federation @integration
  Scenario: SMRITI exports knowledge graph to DuckDB analytics
    Given SMRITI contains evolutionary history
    When analytics export is triggered
    Then DuckDB should contain holon evolution timeline
    And cluster growth metrics should be queryable
    And entropy decay trends should be analyzable

  # ============================================================================
  # LEVEL 8: CONSTITUTIONAL (Invariant Verification)
  # ============================================================================

  @l8-constitutional @invariant
  Scenario: Holon state sovereignty constraint (SC-HOLON-001)
    Then all holon state must be stored in SQLite
    And no holon state should exist in PostgreSQL
    And regeneration should require only "data/holons/" directory

  @l8-constitutional @invariant
  Scenario: Immutable register constraint (SC-REG-001)
    Given a state mutation request
    Then the mutation must go through append-only register
    And the hash chain must remain unbroken
    And the block must be signed

  @l8-constitutional @invariant
  Scenario: Founder's Directive alignment (SC-FOUNDER-001)
    Then SMRITI must support lineage knowledge preservation
    And knowledge must be portable for survival
    And the system must be self-documenting

  @l8-constitutional @invariant
  Scenario: Truthfulness constraint (PSI-5)
    Given knowledge is ingested into SMRITI
    Then content hashes must verify integrity
    And no silent modification is permitted
    And source provenance must be tracked

  # ============================================================================
  # FMEA SCENARIOS (Failure Mode Analysis)
  # ============================================================================

  @fmea @failure-mode
  Scenario Outline: Database failure handling (RPN <threshold>)
    Given the database connection may fail
    When I attempt operation "<operation>"
    Then the error should be handled gracefully
    And an appropriate error message should be displayed
    And no data corruption should occur

    Examples:
      | operation | threshold |
      | status    | 50        |
      | ingest    | 72        |
      | search    | 48        |
      | orphans   | 36        |

  @fmea @failure-mode
  Scenario: API failure during AI extraction (RPN 64)
    Given the OpenRouter API is unavailable
    When I ingest a document with AI extraction enabled
    Then fallback extraction should be used
    And the document should still be ingested
    And a warning should indicate AI was unavailable

  @fmea @failure-mode
  Scenario: Disk space exhaustion during ingestion (RPN 80)
    Given disk space is critically low
    When I attempt batch ingestion
    Then the operation should fail safely
    And partial ingestion should be rolled back
    And a critical error should be reported

  # ============================================================================
  # PROPERTY-BASED SCENARIOS (PropCheck/FsCheck)
  # ============================================================================

  @property @propcheck
  Scenario: Hash function is deterministic (Property)
    Given any arbitrary content string
    When I compute the hash multiple times
    Then all hash values should be identical

  @property @propcheck
  Scenario: UUID uniqueness (Property)
    Given I generate 10000 UUIDs
    Then all UUIDs should be unique
    And no collisions should occur

  @property @propcheck
  Scenario: Entropy is bounded (Property)
    Given any holon age in days
    When I calculate entropy
    Then entropy should be >= 0.0
    And entropy should be <= 1.0

  @property @propcheck
  Scenario: Search results are relevant (Property)
    Given any search query with known matches
    When I execute the search
    Then matching holons should appear in results
    And non-matching holons should be excluded

  # ============================================================================
  # 5-ORDER EFFECTS SCENARIOS
  # ============================================================================

  @5-order-effects
  Scenario: Ingest command 5-order effects
    When I ingest a document
    Then 1st order: holon is created in SQLite
    And 2nd order: FTS5 index is updated
    And 3rd order: cluster statistics refresh
    And 4th order: orphan detection may update
    And 5th order: knowledge graph topology evolves

  @5-order-effects
  Scenario: Search command 5-order effects
    When I execute a search query
    Then 1st order: FTS5 query executes
    And 2nd order: results are ranked by BM25
    And 3rd order: result set is formatted
    And 4th order: CLI displays results
    And 5th order: user gains knowledge

  @5-order-effects
  Scenario: Entropy recalculation 5-order effects
    When I recalculate entropy
    Then 1st order: all holons are iterated
    And 2nd order: age-based entropy computed
    And 3rd order: entropy column updated
    And 4th order: stale detection thresholds shift
    And 5th order: maintenance priorities change
