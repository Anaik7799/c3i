@prajna @l5_bdd @knowledge @smriti
Feature: Knowledge Explorer
  As an operator of the Prajna C3I cockpit
  I want to explore holon knowledge, search documentation, create ADRs, and view the tech radar
  So that I can access and contribute to the system's knowledge base

  # STAMP: SC-SMRITI-072, SC-SMRITI-078, SC-SMRITI-082, SC-SMRITI-083
  # STAMP: SC-SMRITI-130, SC-SMRITI-131, SC-SMRITI-132, SC-SMRITI-133
  # STAMP: SC-HMI-010, SC-IKE-001
  # AOR: AOR-VER-039, AOR-XHOLON-039
  # Layer: L3 (Domain), L6 (Federation)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/prajna/knowledge"
    And the knowledge explorer LiveView is connected via WebSocket
    And Smriti knowledge base is accessible

  # ----------------------------------------------------------
  # Holon Selection
  # ----------------------------------------------------------

  @critical @sc_smriti_072 @smoke
  Scenario: Knowledge explorer loads with holon selector
    When the knowledge explorer page loads
    Then I should see a holon selector dropdown at the top
    And the current local holon should be pre-selected
    And a knowledge summary panel should show:
      | Metric               |
      | Total documents      |
      | Last ingestion date  |
      | Vector index status  |
      | FTS5 index status    |
      | Total ADRs           |
    And the page should load within 3000ms

  @high @sc_smriti_100 @holon_selection
  Scenario: Select a remote federated holon
    Given there are 3 federated holons available
    When I open the holon selector and choose "remote-holon-alpha"
    Then the knowledge panel should reload with remote holon's data
    And a "Remote Holon" badge should appear indicating cross-holon access
    And the data should be fetched via Zenoh cross-holon protocol (SC-XHOLON-003)
    And the query should complete within 5 seconds (SC-XHOLON-025)

  @medium @sc_smriti_100
  Scenario: Remote holon unavailable shows graceful fallback
    Given remote holon "remote-holon-beta" is offline
    When I select "remote-holon-beta" from the holon dropdown
    Then a "Holon Unavailable" message should appear
    And the panel should revert to showing local holon data
    And a retry button should be available

  # ----------------------------------------------------------
  # View Modes
  # ----------------------------------------------------------

  @high @sc_smriti_083 @view_modes
  Scenario Outline: Switch between knowledge view modes
    Given I am on the knowledge explorer
    When I click the "<mode>" view mode button
    Then the content area should render in "<mode>" format

    Examples:
      | mode        |
      | Documents   |
      | Graph       |
      | Timeline    |
      | Radar       |

  @high @sc_smriti_082 @view_modes
  Scenario: Graph view renders holon knowledge graph
    Given I am on the "Graph" view mode
    When the knowledge graph renders
    Then I should see nodes for documents, ADRs, and components
    And edges should represent references and dependencies
    And I should be able to drag nodes to explore the graph
    And clicking a node should show a preview panel with the document summary

  @high @sc_smriti_083 @view_modes
  Scenario: Documents view shows Obsidian-style markdown documents
    Given I am on the "Documents" view mode
    Then I should see a list of documents with:
      | Column       |
      | Title        |
      | Category     |
      | Last updated |
      | Tags         |
    And documents should be rendered with CommonMark-valid formatting (SC-SMRITI-078)
    And YAML frontmatter fields should be visible in the document header (SC-SMRITI-083)

  # ----------------------------------------------------------
  # Search
  # ----------------------------------------------------------

  @critical @sc_smriti_131 @search
  Scenario: Full-text search returns results within 500ms
    Given I am on the knowledge explorer
    When I type "Guardian approval protocol" in the search box
    Then search results should appear within 500ms (SC-SMRITI-133)
    And results should be ranked by relevance
    And matching keywords should be highlighted in each result excerpt
    And the search should use the FTS5 index (SC-SMRITI-131)

  @critical @sc_smriti_132 @search
  Scenario: Semantic search finds conceptually related documents
    Given I click the "Semantic" search toggle
    When I search for "system safety checks before deployment"
    Then results should include documents about health checks, quality gates, and CI/CD
    Even if they do not contain the exact search phrase
    And each result should show a semantic similarity score
    And the search should use vector embeddings (SC-SMRITI-132)

  @high @sc_smriti_131 @search
  Scenario Outline: Filter search results by category
    Given I have performed a search for "Zenoh"
    When I apply the "<category>" filter
    Then only documents in the "<category>" category should appear

    Examples:
      | category        |
      | Architecture    |
      | ADR             |
      | Journal         |
      | Specification   |
      | Safety          |

  @medium @sc_smriti_133 @search
  Scenario: Search with no results shows helpful empty state
    Given I search for "xylophone banana quantum foxtrot"
    Then the results panel should show "No documents found"
    And suggested related terms should appear below
    And an option to search all federated holons should be offered

  # ----------------------------------------------------------
  # ADR Creation
  # ----------------------------------------------------------

  @critical @sc_smriti_140 @adr
  Scenario: Create a new Architecture Decision Record
    Given I am on the knowledge explorer
    When I click "New ADR"
    Then the ADR creation form should appear with fields:
      | Field          | Required |
      | Title          | Yes      |
      | Status         | Yes      |
      | Context        | Yes      |
      | Decision       | Yes      |
      | Consequences   | Yes      |
      | STAMP refs     | No       |
      | Related ADRs   | No       |
    When I fill in all required fields and click "Create ADR"
    Then the ADR should be saved to Smriti SQLite store
    And it should appear in the document list with status "Proposed"
    And an evolution event should be recorded (SC-SMRITI-140)
    And a Zenoh event "knowledge_adr_created" should be published

  @high @sc_smriti_141 @adr
  Scenario: ADR lineage chain is maintained on update
    Given ADR "ADR-042" exists with status "Accepted"
    When I open ADR-042 and change its status to "Superseded"
    And I link it to new ADR "ADR-043" as the superseding decision
    Then ADR-042 should show "Superseded by ADR-043"
    And ADR-043 should show "Supersedes ADR-042"
    And the lineage chain should be unbroken in Smriti (SC-SMRITI-141)

  @high @sc_smriti_083 @adr
  Scenario: ADR renders with YAML frontmatter in documents view
    Given ADR "ADR-039" has YAML frontmatter with status, date, and deciders
    When I view ADR-039 in document mode
    Then the YAML frontmatter should be rendered as a structured header table
    And the markdown body should be rendered below in CommonMark format
    And tags from the frontmatter should appear as clickable filter chips

  # ----------------------------------------------------------
  # Tech Radar
  # ----------------------------------------------------------

  @high @sc_smriti_072 @radar
  Scenario: Tech radar view shows technology quadrants
    Given I click the "Radar" view mode
    When the tech radar renders
    Then I should see 4 quadrants:
      | Quadrant          |
      | Languages & Frameworks |
      | Tools             |
      | Platforms         |
      | Techniques        |
    And each quadrant should have 4 rings: Adopt, Trial, Assess, Hold
    And technologies should be plotted as dots on the radar

  @high @sc_smriti_072 @radar
  Scenario: Click a tech radar entry to see detail
    Given the tech radar is rendered
    When I click on a technology dot (e.g., "Zenoh")
    Then a detail card should appear showing:
      | Field        |
      | Technology   |
      | Ring         |
      | Quadrant     |
      | Description  |
      | Related ADRs |
      | Last reviewed|
    And related ADRs should be clickable to navigate to the ADR

  # ----------------------------------------------------------
  # Export
  # ----------------------------------------------------------

  @high @sc_smriti_072 @export
  Scenario Outline: Export knowledge base in different formats
    Given I am on the knowledge explorer
    When I click "Export" and select format "<format>"
    Then a file download should begin
    And the exported file should be valid "<format>" format (SC-SMRITI-072)

    Examples:
      | format   |
      | JSON     |
      | Markdown |
      | SQLite   |

  # ----------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------

  @medium @sc_ike_002 @entropy
  Scenario: Entropy gate blocks ingestion of low-quality documents
    Given a document with information entropy score below 0.2 is submitted
    When the ingestion pipeline evaluates it (SC-IKE-002)
    Then the ingestion should be blocked with reason "Entropy below threshold"
    And the operator should see a warning in the knowledge explorer ingestion log
    And the document should not appear in search results

  @medium @sc_smriti_130 @federation
  Scenario: Cross-holon knowledge query includes integrity proof
    Given I am querying a remote federated holon's knowledge base
    When the query results return
    Then each result should include an integrity proof hash (SC-SMRITI-130)
    And the proof should be verifiable against the Smriti hash chain
    And results that fail integrity verification should be flagged with a warning icon
