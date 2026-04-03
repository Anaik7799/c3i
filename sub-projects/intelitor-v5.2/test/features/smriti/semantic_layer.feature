# SMRITI Semantic Layer - RDF/SPARQL/Vector Search Integration
# Comprehensive BDD Test Suite - 9 Core Scenarios
# SC-BDD-001, SC-BDD-003 Compliance

@smriti @semantic-layer @rdf @sparql @sil4
Feature: SMRITI Semantic Layer - Knowledge Graph & Inference
  As a knowledge engineer
  I want to query, infer, and search semantic knowledge graphs
  So that I can extract meaningful insights from interconnected data

  Background:
    Given the SMRITI semantic database exists at "data/kms/semantic.db"
    And the RDF triple store is initialized
    And the vector embedding model is loaded
    And SPARQL query engine is ready

  # ============================================================================
  # SCENARIO 1: Triple Ingestion and Storage
  # ============================================================================

  @scenario-1 @triple-ingestion @unit
  Scenario: RDF triples are ingested and stored correctly
    Given I have the following RDF triples in Turtle format:
      """
      @prefix ex: <http://example.org/> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

      ex:Alarm rdf:type rdfs:Class .
      ex:FireAlarm rdf:type rdfs:Class .
      ex:FireAlarm rdfs:subClassOf ex:Alarm .
      ex:alarm001 rdf:type ex:FireAlarm .
      ex:alarm001 ex:severity "HIGH" .
      ex:alarm001 ex:timestamp "2026-01-11T10:00:00Z" .
      """
    When I ingest the triples into the semantic layer
    Then the triple store should contain 6 triples
    And the triple count by predicate should be:
      | predicate      | count |
      | rdf:type       | 3     |
      | rdfs:subClassOf| 1     |
      | ex:severity    | 1     |
      | ex:timestamp   | 1     |
    And querying for subject "ex:alarm001" should return 3 triples
    And the storage backend should use SQLite for persistence

  @scenario-1 @triple-validation @unit
  Scenario: Invalid RDF triples are rejected during ingestion
    Given I have the following invalid RDF triples:
      """
      @prefix ex: <http://example.org/> .

      ex:InvalidTriple ex:missingObject .
      ex:Subject1 "InvalidPredicate" ex:Object1 .
      """
    When I attempt to ingest the invalid triples
    Then the ingestion should fail with error "Invalid RDF syntax"
    And the triple store should contain 0 new triples
    And an error log should be recorded

  # ============================================================================
  # SCENARIO 2: SPARQL Query Execution
  # ============================================================================

  @scenario-2 @sparql @integration
  Scenario: SPARQL SELECT query returns correct results
    Given the triple store contains the following data:
      | subject    | predicate    | object        |
      | ex:alarm001| rdf:type     | ex:FireAlarm  |
      | ex:alarm001| ex:severity  | "HIGH"        |
      | ex:alarm002| rdf:type     | ex:FireAlarm  |
      | ex:alarm002| ex:severity  | "MEDIUM"      |
      | ex:alarm003| rdf:type     | ex:WaterAlarm |
      | ex:alarm003| ex:severity  | "HIGH"        |
    When I execute the SPARQL SELECT query:
      """
      PREFIX ex: <http://example.org/>
      SELECT ?alarm ?severity
      WHERE {
        ?alarm rdf:type ex:FireAlarm .
        ?alarm ex:severity ?severity .
        FILTER (?severity = "HIGH")
      }
      """
    Then the result set should contain:
      | alarm       | severity |
      | ex:alarm001 | "HIGH"   |
    And the result count should be 1
    And the query execution time should be less than 100 milliseconds

  @scenario-2 @sparql @construct
  Scenario: SPARQL CONSTRUCT query generates new triples
    Given the triple store contains alarm classification data
    When I execute the SPARQL CONSTRUCT query:
      """
      PREFIX ex: <http://example.org/>
      CONSTRUCT {
        ?alarm ex:priority "CRITICAL" .
      }
      WHERE {
        ?alarm ex:severity "HIGH" .
        ?alarm rdf:type ex:FireAlarm .
      }
      """
    Then new triples should be generated for high-severity fire alarms
    And the constructed triples should have predicate "ex:priority"
    And the object should be "CRITICAL"

  @scenario-2 @sparql @ask
  Scenario: SPARQL ASK query returns boolean result
    Given the triple store contains security alarm data
    When I execute the SPARQL ASK query:
      """
      PREFIX ex: <http://example.org/>
      ASK {
        ?alarm rdf:type ex:SecurityAlarm .
        ?alarm ex:severity "HIGH" .
      }
      """
    Then the query should return true if high-severity security alarms exist
    And the query should return false if no matches are found

  # ============================================================================
  # SCENARIO 3: RDFS Inference (subClassOf, rdf:type)
  # ============================================================================

  @scenario-3 @inference @rdfs
  Scenario: RDFS subClassOf inference derives implicit types
    Given the triple store contains the following class hierarchy:
      | subject       | predicate       | object     |
      | ex:FireAlarm  | rdfs:subClassOf | ex:Alarm   |
      | ex:Alarm      | rdfs:subClassOf | ex:Event   |
      | ex:alarm001   | rdf:type        | ex:FireAlarm |
    When I enable RDFS inference
    And I query for all types of "ex:alarm001"
    Then the results should include:
      | type          |
      | ex:FireAlarm  |
      | ex:Alarm      |
      | ex:Event      |
    And the inference should be transitive through the class hierarchy

  @scenario-3 @inference @domain-range
  Scenario: RDFS domain/range inference validates property usage
    Given the triple store contains property definitions:
      | subject      | predicate   | object        |
      | ex:hasSensor | rdfs:domain | ex:Device     |
      | ex:hasSensor | rdfs:range  | ex:Sensor     |
      | ex:device001 | ex:hasSensor| ex:sensor001  |
    When I enable RDFS inference
    Then "ex:device001" should be inferred to have type "ex:Device"
    And "ex:sensor001" should be inferred to have type "ex:Sensor"

  @scenario-3 @inference @materialization
  Scenario: Inferred triples can be materialized to storage
    Given the triple store contains 100 base triples
    And RDFS inference is enabled
    When I materialize all inferred triples
    Then the triple store should contain base + inferred triples
    And materialized triples should be marked with "inferred:true" metadata
    And queries should return both base and inferred triples by default

  # ============================================================================
  # SCENARIO 4: Vector Search for Similar Content
  # ============================================================================

  @scenario-4 @vector-search @similarity
  Scenario: Vector embeddings enable semantic similarity search
    Given the following zettels exist with content:
      | id      | title                    | content                                      |
      | zettel1 | Fire Alarm Configuration | Configure fire detection sensors in zones    |
      | zettel2 | Smoke Detector Setup     | Install smoke detectors in residential areas |
      | zettel3 | Database Migration       | Migrate PostgreSQL to TimescaleDB            |
      | zettel4 | Fire Safety Protocol     | Emergency response for fire incidents        |
    And vector embeddings are computed for all zettels
    When I search for similar content to "fire alarm systems"
    Then the results should be ordered by cosine similarity
    And "Fire Alarm Configuration" should rank higher than "Database Migration"
    And the top 3 results should all be fire-related
    And the similarity scores should be between 0.0 and 1.0

  @scenario-4 @vector-search @hybrid
  Scenario: Hybrid search combines vector similarity and keyword matching
    Given zettels with both embeddings and FTS5 index
    When I execute a hybrid search for "alarm configuration" with weights:
      | method       | weight |
      | vector       | 0.6    |
      | keyword_bm25 | 0.4    |
    Then results should be ranked by weighted score
    And exact keyword matches should boost ranking
    And semantically similar content should also rank high
    And the final ranking should combine both signals

  @scenario-4 @vector-search @clustering
  Scenario: Vector clustering groups similar zettels
    Given 50 zettels about diverse topics
    And vector embeddings for all zettels
    When I perform k-means clustering with k=5
    Then zettels should be grouped into 5 clusters
    And each cluster should have topically coherent zettels
    And cluster centroids should represent cluster semantics
    And intra-cluster similarity should be > 0.7

  # ============================================================================
  # SCENARIO 5: Zettel Processing with Entity Extraction
  # ============================================================================

  @scenario-5 @entity-extraction @nlp
  Scenario: Named entities are extracted from zettel content
    Given a zettel with content:
      """
      # Access Control Incident Report

      On January 11, 2026, at 10:30 AM, user John Smith attempted to access
      the server room using badge #12345. The system denied access due to
      insufficient privileges. The incident was logged by the SecureAccess
      system at facility Building-A, floor 3.
      """
    When I process the zettel for entity extraction
    Then the following entities should be extracted:
      | entity_type | entity_value         | confidence |
      | DATE        | January 11, 2026     | 0.95       |
      | TIME        | 10:30 AM             | 0.92       |
      | PERSON      | John Smith           | 0.88       |
      | IDENTIFIER  | #12345               | 0.85       |
      | SYSTEM      | SecureAccess         | 0.80       |
      | LOCATION    | Building-A, floor 3  | 0.87       |
    And entities should be linked to RDF triples
    And entity confidence scores should be >= 0.75

  @scenario-5 @entity-linking @disambiguation
  Scenario: Extracted entities are linked to knowledge graph
    Given a zettel mentioning "John Smith" and "Building-A"
    And the knowledge graph contains:
      | subject          | predicate   | object         |
      | ex:person_001    | rdfs:label  | "John Smith"   |
      | ex:building_a    | rdfs:label  | "Building-A"   |
    When I perform entity linking
    Then "John Smith" should be linked to "ex:person_001"
    And "Building-A" should be linked to "ex:building_a"
    And new triples should be created:
      | subject     | predicate      | object        |
      | ex:zettel_1 | ex:mentions    | ex:person_001 |
      | ex:zettel_1 | ex:refersTo    | ex:building_a |

  @scenario-5 @entity-extraction @batch
  Scenario: Batch entity extraction processes multiple zettels efficiently
    Given 100 zettels requiring entity extraction
    When I trigger batch entity extraction
    Then all 100 zettels should be processed
    And entities should be extracted in parallel batches of 10
    And the total processing time should be < 30 seconds
    And extraction statistics should be reported

  # ============================================================================
  # SCENARIO 6: Full-Text Search Integration
  # ============================================================================

  @scenario-6 @fts @integration
  Scenario: FTS5 search is integrated with RDF triple results
    Given the following data exists:
      | data_type | content                                  |
      | zettel    | Fire alarm troubleshooting guide        |
      | triple    | ex:doc001 rdfs:label "Fire Alarm Manual" |
      | triple    | ex:doc001 ex:topic "fire safety"        |
    When I execute a combined FTS + SPARQL search for "fire alarm"
    Then FTS5 should match the zettel content
    And SPARQL should match the RDF labels
    And results should be unified in a single result set
    And duplicates should be eliminated

  @scenario-6 @fts @ranking
  Scenario: BM25 ranking is combined with SPARQL result ordering
    Given zettels with varying keyword densities
    And RDF triples with relevance scores
    When I search for "alarm configuration"
    Then results should be ranked by combined score:
      | component      | weight |
      | BM25           | 0.5    |
      | SPARQL_score   | 0.3    |
      | vector_sim     | 0.2    |
    And the top result should have the highest combined score

  # ============================================================================
  # SCENARIO 7: Virtual Graph Querying (SQL Sources)
  # ============================================================================

  @scenario-7 @virtual-graph @sql
  Scenario: PostgreSQL tables are exposed as virtual RDF graphs
    Given a PostgreSQL table "devices" with schema:
      | column_name | type    |
      | id          | integer |
      | name        | varchar |
      | zone_id     | integer |
      | status      | varchar |
    And a virtual graph mapping:
      """
      ex:device_{id} rdf:type ex:Device .
      ex:device_{id} rdfs:label "{name}" .
      ex:device_{id} ex:inZone ex:zone_{zone_id} .
      ex:device_{id} ex:status "{status}" .
      """
    When I execute a SPARQL query against the virtual graph:
      """
      PREFIX ex: <http://example.org/>
      SELECT ?device ?name
      WHERE {
        ?device rdf:type ex:Device .
        ?device rdfs:label ?name .
        ?device ex:status "ACTIVE" .
      }
      """
    Then the query should execute against PostgreSQL
    And results should include all active devices
    And no data should be duplicated to RDF store

  @scenario-7 @virtual-graph @federation
  Scenario: Federated SPARQL queries combine virtual and native graphs
    Given a native RDF graph with alarm ontology
    And a virtual graph from PostgreSQL device table
    When I execute a federated SPARQL query:
      """
      PREFIX ex: <http://example.org/>
      SELECT ?alarm ?device
      WHERE {
        # From native RDF graph
        ?alarm rdf:type ex:FireAlarm .
        ?alarm ex:triggeredBy ?device .

        # From virtual graph (PostgreSQL)
        ?device rdf:type ex:Device .
        ?device ex:status "ACTIVE" .
      }
      """
    Then results should combine data from both sources
    And the join should happen at the SPARQL level
    And query performance should be < 200 milliseconds

  # ============================================================================
  # SCENARIO 8: Statistics and Metrics Reporting
  # ============================================================================

  @scenario-8 @metrics @statistics
  Scenario: Semantic layer reports comprehensive statistics
    Given a populated semantic database
    When I request semantic layer statistics
    Then the report should include:
      | metric                  | value_type | example   |
      | total_triples           | integer    | 10500     |
      | total_subjects          | integer    | 2340      |
      | total_predicates        | integer    | 87        |
      | total_classes           | integer    | 45        |
      | total_properties        | integer    | 42        |
      | total_zettels           | integer    | 856       |
      | total_entities_extracted| integer    | 3420      |
      | avg_embedding_dimension | integer    | 384       |
      | inference_enabled       | boolean    | true      |
      | last_inference_run      | timestamp  | ISO8601   |
    And statistics should be queryable via API

  @scenario-8 @metrics @usage
  Scenario: Query performance metrics are tracked
    Given the semantic layer is operational
    When I execute 100 SPARQL queries
    Then performance metrics should be recorded:
      | metric           | aggregation |
      | query_count      | count       |
      | avg_latency_ms   | average     |
      | p50_latency_ms   | percentile  |
      | p95_latency_ms   | percentile  |
      | p99_latency_ms   | percentile  |
      | total_triples_scanned | sum     |
    And metrics should be published to Zenoh topic "indrajaal/smriti/metrics"

  @scenario-8 @metrics @telemetry
  Scenario: Real-time telemetry streams semantic layer health
    Given the semantic layer is integrated with observability stack
    When operations occur (ingestion, query, inference)
    Then telemetry events should be emitted:
      | event_type       | attributes                        |
      | triple.ingested  | count, source, timestamp          |
      | query.executed   | type, latency, result_count       |
      | inference.run    | duration, triples_inferred        |
      | vector.searched  | query, top_k, similarity_threshold|
    And events should be captured by OTEL collector
    And Grafana dashboards should visualize metrics

  # ============================================================================
  # SCENARIO 9: End-to-End Pipeline (ingest → infer → query → search)
  # ============================================================================

  @scenario-9 @e2e @pipeline
  Scenario: Complete semantic processing pipeline
    Given an empty semantic database

    # Step 1: Ingest RDF triples
    When I ingest the following RDF triples:
      """
      @prefix ex: <http://example.org/>
      @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>

      ex:SecurityAlarm rdfs:subClassOf ex:Alarm .
      ex:alarm101 rdf:type ex:SecurityAlarm .
      ex:alarm101 ex:severity "HIGH" .
      ex:alarm101 ex:location "Building-A" .
      """
    Then the triple store should contain 4 triples

    # Step 2: Ingest zettel with related content
    When I ingest a zettel with title "Security Incident Report" and content:
      """
      High-severity security alarm triggered in Building-A at 10:00 AM.
      Badge reader malfunction detected. Response team dispatched.
      """
    Then vector embeddings should be computed for the zettel
    And FTS5 index should be updated

    # Step 3: Extract entities from zettel
    When I run entity extraction on the zettel
    Then entities should be extracted:
      | entity_type | value       |
      | LOCATION    | Building-A  |
      | TIME        | 10:00 AM    |
    And entities should be linked to RDF graph

    # Step 4: Run RDFS inference
    When I trigger RDFS inference
    Then "ex:alarm101" should be inferred to have type "ex:Alarm"
    And inferred triples should be materialized

    # Step 5: Execute SPARQL query
    When I execute SPARQL query:
      """
      SELECT ?alarm ?severity ?location
      WHERE {
        ?alarm rdf:type ex:Alarm .
        ?alarm ex:severity ?severity .
        ?alarm ex:location ?location .
      }
      """
    Then the result should include "ex:alarm101"

    # Step 6: Vector search for related content
    When I search for similar content to "security alarm Building-A"
    Then "Security Incident Report" zettel should rank in top 3

    # Step 7: Hybrid search combining all signals
    When I execute hybrid search for "high severity security alarm":
      | method       | enabled |
      | SPARQL       | true    |
      | FTS5         | true    |
      | vector       | true    |
    Then results should combine all three search methods
    And the top result should be highly relevant
    And the pipeline should complete in < 5 seconds

  # ============================================================================
  # FMEA SCENARIOS (Failure Mode Analysis)
  # ============================================================================

  @fmea @failure-mode
  Scenario Outline: SPARQL query failure handling (RPN <rpn>)
    Given the SPARQL engine is operational
    When I execute a malformed SPARQL query "<query>"
    Then the system should return error "<error_type>"
    And no partial results should be returned
    And the error should be logged with severity "<severity>"
    And the system should remain stable

    Examples:
      | query                        | error_type      | severity | rpn |
      | SELECT * WHERE               | syntax_error    | MEDIUM   | 48  |
      | SELECT ?x ?y ?z FROM         | syntax_error    | MEDIUM   | 48  |
      | CONSTRUCT { ?s ?p } WHERE {} | incomplete      | LOW      | 36  |
      | ASK WHERE { ?s ?p ?o ?extra }| syntax_error    | MEDIUM   | 48  |

  @fmea @failure-mode
  Scenario: Vector search degradation when model unavailable (RPN 64)
    Given the vector embedding model is unavailable
    When I attempt vector search
    Then the system should fall back to FTS5 only
    And a warning should be logged
    And search results should still be returned
    And model unavailability should trigger alert

  @fmea @failure-mode
  Scenario: Triple store corruption detection and recovery (RPN 80)
    Given the triple store detects corruption
    When I attempt to query the corrupted store
    Then the system should enter read-only mode
    And a critical alert should be raised
    And automatic backup restoration should be attempted
    And if restoration fails, manual intervention should be required

  # ============================================================================
  # PROPERTY-BASED SCENARIOS (PropCheck)
  # ============================================================================

  @property @propcheck
  Scenario: SPARQL query results are consistent (Property)
    Given any valid SPARQL SELECT query
    When I execute the query multiple times
    Then all executions should return identical results
    And result ordering should be deterministic

  @property @propcheck
  Scenario: Vector similarity is symmetric (Property)
    Given any two zettels A and B
    When I compute similarity(A, B) and similarity(B, A)
    Then both values should be identical
    And similarity should be in range [0.0, 1.0]

  @property @propcheck
  Scenario: Entity extraction is deterministic (Property)
    Given any zettel content
    When I run entity extraction multiple times
    Then extracted entities should be identical
    And confidence scores should be reproducible

  # ============================================================================
  # 5-ORDER EFFECTS SCENARIOS
  # ============================================================================

  @5-order-effects
  Scenario: Triple ingestion 5-order effects
    When I ingest RDF triples
    Then 1st order: triples are stored in SQLite
    And 2nd order: SPARQL index is updated
    And 3rd order: inference engine can access new data
    And 4th order: virtual graph queries can join with new triples
    And 5th order: knowledge graph topology evolves, enabling new insights

  @5-order-effects
  Scenario: SPARQL query 5-order effects
    When I execute a SPARQL query
    Then 1st order: query is parsed and validated
    And 2nd order: query plan is generated
    And 3rd order: triple store is accessed
    And 4th order: results are formatted and returned
    And 5th order: query patterns inform index optimization

  @5-order-effects
  Scenario: Vector search 5-order effects
    When I perform vector similarity search
    Then 1st order: query text is embedded
    And 2nd order: cosine similarity is computed for all zettels
    And 3rd order: results are ranked by similarity
    And 4th order: user discovers related content
    And 5th order: knowledge connections are strengthened through usage patterns

  # ============================================================================
  # CONSTITUTIONAL INVARIANTS
  # ============================================================================

  @constitutional @invariant
  Scenario: Semantic layer state sovereignty (SC-HOLON-001)
    Then all semantic data MUST be stored in SQLite
    And no semantic state should exist in PostgreSQL
    And regeneration should require only "data/kms/" directory

  @constitutional @invariant
  Scenario: Immutable register for semantic mutations (SC-REG-001)
    Given a triple ingestion or deletion request
    Then the mutation MUST go through append-only register
    And the hash chain MUST remain unbroken
    And all changes MUST be auditable

  @constitutional @invariant
  Scenario: Truthfulness in semantic knowledge (PSI-5)
    Given semantic triples represent factual knowledge
    Then source provenance MUST be tracked for all triples
    And inference steps MUST be traceable
    And no silent modification of facts is permitted
    And confidence scores MUST be preserved
